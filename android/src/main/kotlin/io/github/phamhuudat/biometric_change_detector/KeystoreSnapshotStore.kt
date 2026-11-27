package io.github.phamhuudat.biometric_change_detector

import android.app.KeyguardManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.UserNotAuthenticatedException
import java.security.InvalidKeyException
import java.security.KeyStore
import java.security.UnrecoverableKeyException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/** Error reported to Dart as a PlatformException with [code]. */
internal class DetectorError(val code: String, message: String?) : Exception(message)

internal enum class Status(val wire: String) {
  UNCHANGED("unchanged"),
  CHANGED("changed"),
  NOT_ENROLLED("notEnrolled"),
  UNAVAILABLE("unavailable"),
}

/**
 * Stores one Keystore key per keyId. The key requires biometric authentication
 * and is invalidated by the OS when a biometric is enrolled or removed, so
 * initialising a cipher with it tells us whether the enrollment changed. The
 * key itself never encrypts anything.
 *
 * A marker in SharedPreferences remembers which keyIds were enrolled, so a key
 * that disappeared (screen lock removed, OEM wipe) is reported as changed
 * instead of notEnrolled.
 *
 * Not thread-safe: the plugin calls it from a single background thread.
 */
internal class KeystoreSnapshotStore(context: Context) {
  private val appContext = context.applicationContext
  private val prefs: SharedPreferences =
    appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

  fun enroll(keyId: String) {
    val keyguard = appContext.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager?
    if (keyguard != null && !keyguard.isDeviceSecure) {
      throw DetectorError(ERROR_PASSCODE_NOT_SET, "The device has no screen lock")
    }
    val alias = alias(keyId)
    try {
      keyStore().deleteEntry(alias)
      generateKey(alias)
    } catch (e: DetectorError) {
      throw e
    } catch (e: IllegalStateException) {
      // "At least one biometric must be enrolled to create keys requiring user authentication"
      throw DetectorError(ERROR_BIOMETRIC_NOT_ENROLLED, e.message)
    } catch (e: java.security.InvalidAlgorithmParameterException) {
      throw DetectorError(ERROR_BIOMETRIC_NOT_ENROLLED, e.message)
    } catch (e: Exception) {
      throw DetectorError(ERROR_STORAGE, e.message)
    }
    prefs.edit().putLong(keyId, System.currentTimeMillis()).commit()
  }

  fun check(keyId: String): Status {
    val hasMarker = prefs.contains(keyId)
    return try {
      val key = keyStore().getKey(alias(keyId), null) as SecretKey?
        ?: return if (hasMarker) Status.CHANGED else Status.NOT_ENROLLED
      probe(key)
    } catch (e: UnrecoverableKeyException) {
      Status.CHANGED
    } catch (e: Exception) {
      Status.UNAVAILABLE
    }
  }

  fun isEnrolled(keyId: String): Boolean =
    prefs.contains(keyId) || runCatching { keyStore().containsAlias(alias(keyId)) }.getOrDefault(false)

  fun remove(keyId: String) {
    try {
      keyStore().deleteEntry(alias(keyId))
    } catch (e: Exception) {
      throw DetectorError(ERROR_STORAGE, e.message)
    }
    prefs.edit().remove(keyId).commit()
  }

  fun removeAll() {
    try {
      val ks = keyStore()
      ks.aliases().toList().filter { it.startsWith(ALIAS_PREFIX) }.forEach(ks::deleteEntry)
    } catch (e: Exception) {
      throw DetectorError(ERROR_STORAGE, e.message)
    }
    prefs.edit().clear().commit()
  }

  fun migrateLegacy(keyId: String, legacyAlias: String?): Status {
    if (isEnrolled(keyId)) {
      if (legacyAlias != null) runCatching { keyStore().deleteEntry(legacyAlias) }
      return check(keyId)
    }
    if (legacyAlias == null) return Status.NOT_ENROLLED
    return try {
      val ks = keyStore()
      if (!ks.containsAlias(legacyAlias)) return Status.NOT_ENROLLED
      val legacyStatus = try {
        (ks.getKey(legacyAlias, null) as SecretKey?)?.let(::probe) ?: Status.CHANGED
      } catch (e: UnrecoverableKeyException) {
        Status.CHANGED
      }
      when (legacyStatus) {
        Status.UNCHANGED -> {
          try {
            enroll(keyId)
          } catch (e: DetectorError) {
            // Keep the legacy key so the next call can retry.
            return Status.UNCHANGED
          }
          ks.deleteEntry(legacyAlias)
          Status.UNCHANGED
        }
        Status.CHANGED -> {
          ks.deleteEntry(legacyAlias)
          // Marker without a key keeps reporting CHANGED until enroll/remove.
          prefs.edit().putLong(keyId, System.currentTimeMillis()).commit()
          Status.CHANGED
        }
        else -> Status.UNAVAILABLE
      }
    } catch (e: Exception) {
      Status.UNAVAILABLE
    }
  }

  private fun probe(key: SecretKey): Status = try {
    Cipher.getInstance(TRANSFORMATION).init(Cipher.ENCRYPT_MODE, key)
    Status.UNCHANGED
  } catch (e: KeyPermanentlyInvalidatedException) {
    Status.CHANGED
  } catch (e: UserNotAuthenticatedException) {
    // The key is still valid, it only needs authentication to be used.
    Status.UNCHANGED
  } catch (e: InvalidKeyException) {
    Status.UNAVAILABLE
  }

  private fun generateKey(alias: String) {
    val builder = KeyGenParameterSpec.Builder(
      alias,
      KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
    )
      .setBlockModes(KeyProperties.BLOCK_MODE_CBC)
      .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_PKCS7)
      .setUserAuthenticationRequired(true)
      .setInvalidatedByBiometricEnrollment(true)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      builder.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
    }
    KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE).apply {
      init(builder.build())
      generateKey()
    }
  }

  private fun keyStore(): KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

  private fun alias(keyId: String) = ALIAS_PREFIX + keyId

  companion object {
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val ALIAS_PREFIX = "biometric_change_detector."
    private const val PREFS_NAME = "io.github.phamhuudat.biometric_change_detector"

    // Same transformation as did_change_authlocal, so legacy keys can be probed.
    private const val TRANSFORMATION = "AES/CBC/PKCS7Padding"

    const val ERROR_PASSCODE_NOT_SET = "passcodeNotSet"
    const val ERROR_BIOMETRIC_NOT_ENROLLED = "biometricNotEnrolled"
    const val ERROR_STORAGE = "storageError"
  }
}
