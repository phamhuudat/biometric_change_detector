import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'biometric_change_detector_platform_interface.dart';
import 'biometric_change_exception.dart';
import 'biometric_change_status.dart';

/// An implementation of [BiometricChangeDetectorPlatform] that talks to the
/// Android and iOS code over a [MethodChannel].
class MethodChannelBiometricChangeDetector
    extends BiometricChangeDetectorPlatform {
  /// The channel used to talk to the native side.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel(
    'biometric_change_detector',
  );

  @override
  Future<void> enroll(String keyId) =>
      _invokeOrThrow<void>('enroll', {'keyId': keyId});

  @override
  Future<BiometricChangeStatus> check(String keyId) =>
      _status('check', {'keyId': keyId});

  @override
  Future<bool> isEnrolled(String keyId) async {
    try {
      return await methodChannel.invokeMethod<bool>('isEnrolled', {
            'keyId': keyId,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> remove(String keyId) =>
      _invokeOrThrow<void>('remove', {'keyId': keyId});

  @override
  Future<void> removeAll() => _invokeOrThrow<void>('removeAll');

  @override
  Future<BiometricChangeStatus> migrateLegacy(
    String keyId, {
    String? androidKeyAlias,
    String? iosDomainState,
  }) => _status('migrateLegacy', {
    'keyId': keyId,
    'androidKeyAlias': androidKeyAlias,
    'iosDomainState': iosDomainState,
  });

  Future<BiometricChangeStatus> _status(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      final value = await methodChannel.invokeMethod<String>(method, arguments);
      return BiometricChangeStatus.fromWire(value);
    } on PlatformException {
      return BiometricChangeStatus.unavailable;
    } on MissingPluginException {
      return BiometricChangeStatus.unavailable;
    }
  }

  Future<T?> _invokeOrThrow<T>(
    String method, [
    Map<String, Object?>? arguments,
  ]) async {
    try {
      return await methodChannel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw BiometricChangeException(e.code, e.message);
    } on MissingPluginException catch (e) {
      throw BiometricChangeException(
        BiometricChangeErrorCode.unsupported,
        e.message,
      );
    }
  }
}
