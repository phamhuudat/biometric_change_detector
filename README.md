# biometric_change_detector

[![pub package](https://img.shields.io/pub/v/biometric_change_detector.svg)](https://pub.dev/packages/biometric_change_detector)
[![CI](https://github.com/phamhuudat/biometric_change_detector/actions/workflows/ci.yml/badge.svg)](https://github.com/phamhuudat/biometric_change_detector/actions/workflows/ci.yml)

Detect when the biometrics enrolled on the device change: a fingerprint or
face is added or removed, all biometrics are removed, or the screen lock is
turned off.

Use it to protect biometric login. If someone who knows the device passcode
adds their own fingerprint or face, your app should stop accepting biometrics
until the owner signs in again with a password.

- No prompt is shown and no permission is needed.
- Nothing leaves the device. No data is collected.
- One snapshot per `keyId`, so you can track several features or accounts.

## How it works

| Platform | Mechanism |
|---|---|
| Android 7.0+ (API 24) | An AES key in the Android Keystore that requires biometric authentication. The OS permanently invalidates it when the biometric enrollment changes. The key never encrypts anything; it is only checked. |
| iOS 13+ | The `LAContext` biometric domain state (`evaluatedPolicyDomainState`, plus `domainState.biometry.stateHash` on iOS 18+), stored in the Keychain with `ThisDeviceOnly` protection. |

## Requirements

| | Minimum |
|---|---|
| Flutter | 3.44 (Dart 3.12) |
| Android | API 24, Android Gradle Plugin 9 |
| iOS | 13.0 |

Android Gradle Plugin 8 is **not** supported. The plugin uses built-in Kotlin
as described in Flutter's
[migration guide for plugin authors](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors),
and builds whether or not your app sets `android.builtInKotlin=false`.

## Installation

```bash
flutter pub add biometric_change_detector
```

**iOS:** add a Face ID usage description to `ios/Runner/Info.plist` (you need
it anyway to authenticate with `local_auth`):

```xml
<key>NSFaceIDUsageDescription</key>
<string>Used to sign you in with Face ID.</string>
```

**Android:** nothing to configure.

## Usage

```dart
import 'package:biometric_change_detector/biometric_change_detector.dart';

final detector = BiometricChangeDetector.instance;

// 1. After the user turns on biometric login:
try {
  await detector.enroll('login');
} on BiometricChangeException catch (e) {
  // e.code is one of BiometricChangeErrorCode, e.g. biometricNotEnrolled.
}

// 2. Before accepting biometrics:
switch (await detector.check('login')) {
  case BiometricChangeStatus.unchanged:
    // Safe to use biometric login.
    break;
  case BiometricChangeStatus.changed:
    // Turn biometric login off and ask for the password.
    // After the password succeeds, call enroll('login') again.
    break;
  case BiometricChangeStatus.notEnrolled:
    // Biometric login was never set up on this install.
    break;
  case BiometricChangeStatus.unavailable:
    // Unknown right now (no hardware, locked out, ...). Try again later.
    break;
}

// 3. When the user turns biometric login off or logs out:
await detector.remove('login');
```

A `keyId` is 1–128 characters without whitespace. Use one per feature or per
account, for example `'login.$userId'` and `'payment'`.

## API

| Method | Description |
|---|---|
| `enroll(keyId)` | Takes or overwrites a snapshot of the current biometrics. Throws `BiometricChangeException`. |
| `check(keyId)` | Returns a `BiometricChangeStatus`. Never throws because of the device state. |
| `isEnrolled(keyId)` | Whether a snapshot exists, even if it no longer matches. |
| `remove(keyId)` | Deletes one snapshot. Does nothing if there is none. |
| `removeAll()` | Deletes every snapshot created by this plugin. |
| `migrateLegacy(keyId, ...)` | Adopts a snapshot created by `did_change_authlocal`. |

### Error codes (`BiometricChangeException.code`)

| Code | Meaning |
|---|---|
| `biometricNotEnrolled` | No fingerprint or face is enrolled. |
| `passcodeNotSet` | The device has no screen lock / passcode. |
| `biometricLockedOut` | Too many failed attempts (iOS). |
| `biometricNotAvailable` | No hardware, or Face ID permission denied. |
| `storageError` | The Keystore or Keychain failed. |
| `unsupported` | The platform is not supported. |

## Status reference

| Situation | Android | iOS |
|---|---|---|
| No snapshot for this keyId | `notEnrolled` | `notEnrolled` |
| Same biometrics as the snapshot | `unchanged` | `unchanged` |
| A fingerprint or face added or removed | `changed` | `changed` |
| All biometrics removed | `changed` | `changed` |
| Screen lock / passcode removed | `changed` | `changed` |
| Biometrics locked out | `unchanged` | `unavailable` |
| No hardware, Face ID permission denied | `unavailable` | `unavailable` |
| App reinstalled | `notEnrolled` | `notEnrolled` |

`changed` is **sticky**: it is returned until you call `enroll` (accepting the
new biometrics) or `remove`.

## Platform notes

### Android

- Biometric lockout does not affect the result, because the key is checked
  without being used.
- Keys are deleted when the app is uninstalled. If Auto Backup restores the
  app's shared preferences on a new device, `check` returns `changed`. To
  avoid this, exclude
  `sharedpref/io.github.phamhuudat.biometric_change_detector.xml` from backup.
- Some manufacturers may handle key invalidation differently. If you see
  unexpected results on a specific device, please
  [open an issue](https://github.com/phamhuudat/biometric_change_detector/issues).

### iOS

- Keychain items survive uninstalling an app. The plugin detects a fresh
  install (through a flag in `UserDefaults`) and deletes its old snapshots, so
  a reinstalled app always starts with `notEnrolled`. If your app wipes its
  whole `UserDefaults` domain, the next call is treated as a fresh install.
- The plugin ships a privacy manifest declaring its `UserDefaults` use
  (reason `CA92.1`). It collects no data, so your App Store privacy label does
  not change.
- Apple may change the domain state after a major iOS update even when the
  user did not touch their biometrics. You then get `changed`, and the user
  signs in with a password once. This is the safe outcome.
- On the Simulator, use **Features → Face ID → Enrolled**. Turning it off
  and on again simulates a biometric change.

## Migrating from `did_change_authlocal`

`did_change_authlocal` left its snapshot where your app can find it: a Keystore
alias on Android, and a base64 token your app stored on iOS. Pass them to
`migrateLegacy` instead of `check`:

```dart
final status = await detector.migrateLegacy(
  'login',
  androidKeyAlias: legacyAndroidAlias, // the alias the old plugin created
  iosDomainState: legacyIosToken,      // the token you saved from the old plugin
);
```

- If `'login'` is already enrolled, this behaves like `check`.
- If the legacy snapshot still matches the current biometrics, it moves under
  `'login'` and returns `unchanged`. The legacy Android key is deleted.
- If the biometrics changed in the meantime, it returns `changed` until you
  call `enroll`.
- If there is nothing to migrate, it returns `notEnrolled`.

You can call `migrateLegacy` on every check. Once the data has moved, it only
does a normal `check`. After `enroll` succeeds, delete the legacy token your app
stored.

## Example

See [`example/`](example) for an app with buttons for every method.

## Credits

The idea comes from
[did_change_authlocal](https://pub.dev/packages/did_change_authlocal) by Thong
Vo (MIT). This package is a rewrite with a different API.

## License

[MIT](LICENSE)
