package io.github.phamhuudat.biometric_change_detector

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** BiometricChangeDetectorPlugin */
class BiometricChangeDetectorPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var store: KeystoreSnapshotStore
  private val mainHandler = Handler(Looper.getMainLooper())

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    store = KeystoreSnapshotStore(binding.applicationContext)
    channel = MethodChannel(binding.binaryMessenger, CHANNEL)
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    val keyId = call.argument<String>("keyId")
    if (call.method != "removeAll" && keyId.isNullOrEmpty()) {
      result.error("invalid_argument", "keyId is required", null)
      return
    }
    executor.execute {
      val reply: () -> Unit = try {
        when (call.method) {
          "enroll" -> store.enroll(keyId!!).let { { result.success(null) } }
          "check" -> store.check(keyId!!).let { { result.success(it.wire) } }
          "isEnrolled" -> store.isEnrolled(keyId!!).let { { result.success(it) } }
          "remove" -> store.remove(keyId!!).let { { result.success(null) } }
          "removeAll" -> store.removeAll().let { { result.success(null) } }
          "migrateLegacy" -> store
            .migrateLegacy(keyId!!, call.argument<String>("androidKeyAlias")?.takeIf { it.isNotEmpty() })
            .let { { result.success(it.wire) } }
          else -> ({ result.notImplemented() })
        }
      } catch (e: DetectorError) {
        { result.error(e.code, e.message, null) }
      } catch (e: Exception) {
        { result.error(KeystoreSnapshotStore.ERROR_STORAGE, e.message, null) }
      }
      mainHandler.post(reply)
    }
  }

  private companion object {
    const val CHANNEL = "biometric_change_detector"

    /** Shared by every engine so Keystore operations never run concurrently. */
    val executor: ExecutorService = Executors.newSingleThreadExecutor { runnable ->
      Thread(runnable, "BiometricChangeDetector").apply { isDaemon = true }
    }
  }
}
