import 'package:biometric_change_detector/biometric_change_detector.dart';
import 'package:biometric_change_detector/biometric_change_detector_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelBiometricChangeDetector();
  final channel = platform.methodChannel;
  final calls = <MethodCall>[];
  Object? Function(MethodCall call) handler = (_) => null;

  setUp(() {
    calls.clear();
    handler = (_) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return handler(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('enroll sends keyId', () async {
    await platform.enroll('login');
    expect(calls.single.method, 'enroll');
    expect(calls.single.arguments, {'keyId': 'login'});
  });

  test('check parses every status', () async {
    for (final status in BiometricChangeStatus.values) {
      handler = (_) => status.name;
      expect(await platform.check('login'), status);
    }
  });

  test('check maps unknown values to unavailable', () async {
    handler = (_) => 'somethingNew';
    expect(await platform.check('login'), BiometricChangeStatus.unavailable);
  });

  test('check maps PlatformException to unavailable', () async {
    handler = (_) => throw PlatformException(code: 'storageError');
    expect(await platform.check('login'), BiometricChangeStatus.unavailable);
  });

  test('isEnrolled returns the native bool and false on error', () async {
    handler = (_) => true;
    expect(await platform.isEnrolled('login'), isTrue);
    handler = (_) => throw PlatformException(code: 'storageError');
    expect(await platform.isEnrolled('login'), isFalse);
  });

  test(
    'enroll converts PlatformException to BiometricChangeException',
    () async {
      handler = (_) => throw PlatformException(
        code: BiometricChangeErrorCode.biometricNotEnrolled,
        message: 'none',
      );
      await expectLater(
        platform.enroll('login'),
        throwsA(
          isA<BiometricChangeException>()
              .having((e) => e.code, 'code', 'biometricNotEnrolled')
              .having((e) => e.message, 'message', 'none'),
        ),
      );
    },
  );

  test('remove and removeAll send the right calls', () async {
    await platform.remove('login');
    await platform.removeAll();
    expect(calls.map((c) => c.method), ['remove', 'removeAll']);
    expect(calls.first.arguments, {'keyId': 'login'});
  });

  test('migrateLegacy sends all arguments, including nulls', () async {
    handler = (_) => 'unchanged';
    final status = await platform.migrateLegacy(
      'login',
      androidKeyAlias: 'oldbiometric_auth',
    );
    expect(status, BiometricChangeStatus.unchanged);
    expect(calls.single.method, 'migrateLegacy');
    expect(calls.single.arguments, {
      'keyId': 'login',
      'androidKeyAlias': 'oldbiometric_auth',
      'iosDomainState': null,
    });
  });

  group('without a native implementation', () {
    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('check returns unavailable', () async {
      expect(await platform.check('login'), BiometricChangeStatus.unavailable);
    });

    test('isEnrolled returns false', () async {
      expect(await platform.isEnrolled('login'), isFalse);
    });

    test('enroll throws unsupported', () async {
      await expectLater(
        platform.enroll('login'),
        throwsA(
          isA<BiometricChangeException>().having(
            (e) => e.code,
            'code',
            BiometricChangeErrorCode.unsupported,
          ),
        ),
      );
    });
  });
}
