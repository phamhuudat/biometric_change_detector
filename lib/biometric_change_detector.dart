/// Detect when the device's enrolled biometrics (fingerprint, Face ID,
/// Touch ID) change.
///
/// ```dart
/// final detector = BiometricChangeDetector.instance;
/// await detector.enroll('login');          // after the user turns on biometric login
/// final status = await detector.check('login');
/// if (status == BiometricChangeStatus.changed) {
///   // Disable biometric login and ask for the password again.
/// }
/// ```
library;

import 'src/biometric_change_detector_platform_interface.dart';
import 'src/biometric_change_status.dart';

export 'src/biometric_change_exception.dart';
export 'src/biometric_change_status.dart';

/// Takes snapshots of the enrolled biometrics and tells you when they change.
///
/// Each snapshot is stored on the device under a `keyId` you choose, so one
/// app can track several features independently (for example `'login'` and
/// `'payment'`).
///
/// * Android: an AES key in the Android Keystore that the OS invalidates when
///   a biometric is enrolled or removed.
/// * iOS: the `LAContext` biometric domain state, stored in the Keychain.
class BiometricChangeDetector {
  BiometricChangeDetector._();

  /// The shared instance.
  static final BiometricChangeDetector instance = BiometricChangeDetector._();

  static const int _maxKeyIdLength = 128;
  static final RegExp _invalidKeyIdChars = RegExp(r'[\s\x00-\x1F\x7F]');

  BiometricChangeDetectorPlatform get _platform =>
      BiometricChangeDetectorPlatform.instance;

  /// Takes (or overwrites) a snapshot of the currently enrolled biometrics
  /// under [keyId].
  ///
  /// Call it when the user turns on biometric authentication, and again after
  /// a [BiometricChangeStatus.changed] result once the user has proven their
  /// identity another way.
  ///
  /// Throws a [BiometricChangeException] when the snapshot cannot be taken,
  /// for example `biometricNotEnrolled` or `passcodeNotSet`
  /// (see [BiometricChangeErrorCode]).
  Future<void> enroll(String keyId) => _platform.enroll(_validate(keyId));

  /// Compares the currently enrolled biometrics with the snapshot under
  /// [keyId].
  ///
  /// Never throws because of the device state; problems are reported as
  /// [BiometricChangeStatus.unavailable].
  Future<BiometricChangeStatus> check(String keyId) =>
      _platform.check(_validate(keyId));

  /// Whether a snapshot exists under [keyId], even if it no longer matches.
  Future<bool> isEnrolled(String keyId) =>
      _platform.isEnrolled(_validate(keyId));

  /// Deletes the snapshot under [keyId]. Does nothing if there is none.
  Future<void> remove(String keyId) => _platform.remove(_validate(keyId));

  /// Deletes every snapshot created by this plugin, for example on logout.
  Future<void> removeAll() => _platform.removeAll();

  /// Adopts a snapshot created by the `did_change_authlocal` plugin, so users
  /// who already turned on biometrics are not reported as changed after you
  /// switch to this package.
  ///
  /// * [androidKeyAlias]: the exact Android Keystore alias the old plugin
  ///   created.
  /// * [iosDomainState]: the base64 token the old plugin returned on iOS and
  ///   your app stored.
  ///
  /// If [keyId] is already enrolled, this is the same as [check]. Otherwise
  /// the legacy snapshot is compared with the current biometrics and, when
  /// possible, moved under [keyId]; the legacy Android key is deleted.
  /// Returns [BiometricChangeStatus.notEnrolled] when there is nothing to
  /// migrate.
  Future<BiometricChangeStatus> migrateLegacy(
    String keyId, {
    String? androidKeyAlias,
    String? iosDomainState,
  }) => _platform.migrateLegacy(
    _validate(keyId),
    androidKeyAlias: _nullIfEmpty(androidKeyAlias),
    iosDomainState: _nullIfEmpty(iosDomainState),
  );

  static String _validate(String keyId) {
    if (keyId.isEmpty ||
        keyId.length > _maxKeyIdLength ||
        _invalidKeyIdChars.hasMatch(keyId)) {
      throw ArgumentError.value(
        keyId,
        'keyId',
        'Must be 1-$_maxKeyIdLength characters without whitespace',
      );
    }
    return keyId;
  }

  static String? _nullIfEmpty(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value.trim();
}
