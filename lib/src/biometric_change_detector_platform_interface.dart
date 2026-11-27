import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'biometric_change_status.dart';
import 'method_channel_biometric_change_detector.dart';

/// The interface that platform implementations of `biometric_change_detector`
/// must extend.
///
/// Platform implementations should extend this class rather than implement it,
/// because new methods added here are not considered breaking changes.
abstract class BiometricChangeDetectorPlatform extends PlatformInterface {
  /// Constructs a [BiometricChangeDetectorPlatform].
  BiometricChangeDetectorPlatform() : super(token: _token);

  static final Object _token = Object();

  static BiometricChangeDetectorPlatform _instance =
      MethodChannelBiometricChangeDetector();

  /// The current implementation; [MethodChannelBiometricChangeDetector] by
  /// default.
  static BiometricChangeDetectorPlatform get instance => _instance;

  /// Replaces the implementation, for example with a fake in tests.
  static set instance(BiometricChangeDetectorPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Takes (or overwrites) a snapshot of the enrolled biometrics under [keyId].
  Future<void> enroll(String keyId) =>
      throw UnimplementedError('enroll() has not been implemented.');

  /// Compares the enrolled biometrics with the snapshot under [keyId].
  Future<BiometricChangeStatus> check(String keyId) =>
      throw UnimplementedError('check() has not been implemented.');

  /// Whether a snapshot exists under [keyId].
  Future<bool> isEnrolled(String keyId) =>
      throw UnimplementedError('isEnrolled() has not been implemented.');

  /// Deletes the snapshot under [keyId].
  Future<void> remove(String keyId) =>
      throw UnimplementedError('remove() has not been implemented.');

  /// Deletes every snapshot created by this plugin.
  Future<void> removeAll() =>
      throw UnimplementedError('removeAll() has not been implemented.');

  /// Adopts a snapshot made by the `did_change_authlocal` plugin.
  Future<BiometricChangeStatus> migrateLegacy(
    String keyId, {
    String? androidKeyAlias,
    String? iosDomainState,
  }) => throw UnimplementedError('migrateLegacy() has not been implemented.');
}
