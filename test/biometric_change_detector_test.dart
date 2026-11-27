import 'package:biometric_change_detector/biometric_change_detector.dart';
import 'package:biometric_change_detector/biometric_change_detector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePlatform extends BiometricChangeDetectorPlatform
    with MockPlatformInterfaceMixin {
  final log = <String>[];
  BiometricChangeStatus status = BiometricChangeStatus.unchanged;

  @override
  Future<void> enroll(String keyId) async => log.add('enroll $keyId');

  @override
  Future<BiometricChangeStatus> check(String keyId) async {
    log.add('check $keyId');
    return status;
  }

  @override
  Future<bool> isEnrolled(String keyId) async {
    log.add('isEnrolled $keyId');
    return true;
  }

  @override
  Future<void> remove(String keyId) async => log.add('remove $keyId');

  @override
  Future<void> removeAll() async => log.add('removeAll');

  @override
  Future<BiometricChangeStatus> migrateLegacy(
    String keyId, {
    String? androidKeyAlias,
    String? iosDomainState,
  }) async {
    log.add('migrateLegacy $keyId $androidKeyAlias $iosDomainState');
    return status;
  }
}

void main() {
  final initialPlatform = BiometricChangeDetectorPlatform.instance;
  final detector = BiometricChangeDetector.instance;
  late FakePlatform fake;

  setUp(() {
    fake = FakePlatform();
    BiometricChangeDetectorPlatform.instance = fake;
  });

  test('$MethodChannelBiometricChangeDetector is the default instance', () {
    expect(initialPlatform, isA<MethodChannelBiometricChangeDetector>());
  });

  test('delegates every call to the platform', () async {
    fake.status = BiometricChangeStatus.changed;
    await detector.enroll('login');
    expect(await detector.check('login'), BiometricChangeStatus.changed);
    expect(await detector.isEnrolled('login'), isTrue);
    await detector.remove('login');
    await detector.removeAll();
    expect(fake.log, [
      'enroll login',
      'check login',
      'isEnrolled login',
      'remove login',
      'removeAll',
    ]);
  });

  test('migrateLegacy turns empty legacy values into null', () async {
    await detector.migrateLegacy(
      'login',
      androidKeyAlias: '  ',
      iosDomainState: ' abc= ',
    );
    expect(fake.log.single, 'migrateLegacy login null abc=');
  });

  group('rejects invalid keyIds before reaching the platform', () {
    for (final keyId in ['', 'has space', 'tab\there', 'x' * 129]) {
      test('"${keyId.length > 10 ? '${keyId.substring(0, 10)}…' : keyId}"', () {
        expect(() => detector.check(keyId), throwsArgumentError);
        expect(() => detector.enroll(keyId), throwsArgumentError);
        expect(fake.log, isEmpty);
      });
    }
  });

  test('accepts a 128-character keyId', () async {
    await detector.check('x' * 128);
    expect(fake.log.single, startsWith('check '));
  });
}
