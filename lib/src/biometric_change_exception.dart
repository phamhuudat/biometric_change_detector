/// Error codes carried by [BiometricChangeException.code].
abstract final class BiometricChangeErrorCode {
  /// The platform is not supported (for example web or desktop).
  static const unsupported = 'unsupported';

  /// The device has no screen lock / passcode.
  static const passcodeNotSet = 'passcodeNotSet';

  /// No fingerprint or face is enrolled on the device.
  static const biometricNotEnrolled = 'biometricNotEnrolled';

  /// Biometrics are locked out after too many failed attempts (iOS).
  static const biometricLockedOut = 'biometricLockedOut';

  /// Biometrics are not available: no hardware, or Face ID permission denied.
  static const biometricNotAvailable = 'biometricNotAvailable';

  /// The Android Keystore or iOS Keychain failed.
  static const storageError = 'storageError';
}

/// Thrown when a snapshot cannot be created or deleted, for example when
/// `BiometricChangeDetector.enroll` is called on a device without enrolled
/// biometrics.
class BiometricChangeException implements Exception {
  /// Creates an exception with a machine-readable [code] (see
  /// [BiometricChangeErrorCode]) and an optional [message].
  const BiometricChangeException(this.code, [this.message]);

  /// One of the [BiometricChangeErrorCode] values, or a platform-specific code.
  final String code;

  /// Human-readable detail from the platform, if any.
  final String? message;

  @override
  String toString() =>
      'BiometricChangeException($code${message == null ? '' : ': $message'})';
}
