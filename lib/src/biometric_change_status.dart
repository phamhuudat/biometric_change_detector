/// Result of comparing the device's current biometric enrollment with the
/// snapshot taken by `BiometricChangeDetector.enroll`.
enum BiometricChangeStatus {
  /// The enrolled biometrics are the same as when the snapshot was taken.
  unchanged,

  /// The enrolled biometrics changed since the snapshot was taken: a
  /// fingerprint or face was added or removed, every biometric was removed,
  /// or the screen lock / passcode was turned off.
  ///
  /// This status is sticky: it is returned until you call
  /// `BiometricChangeDetector.enroll` again (accepting the new set) or
  /// `BiometricChangeDetector.remove`.
  changed,

  /// No snapshot exists for this key: it was never enrolled, it was removed,
  /// or the app was reinstalled.
  notEnrolled,

  /// The state cannot be read right now, for example when there is no
  /// biometric hardware, biometrics are locked out (iOS), Face ID permission
  /// was denied, or the platform is not supported.
  ///
  /// Treat this as "unknown", not as "changed"; try again later.
  unavailable;

  /// Parses the wire value sent by the native side. Unknown values map to
  /// [unavailable].
  static BiometricChangeStatus fromWire(Object? value) => value is String
      ? (values.asNameMap()[value] ?? unavailable)
      : unavailable;
}
