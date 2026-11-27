## 0.1.0

* Initial release.
* `enroll`, `check`, `isEnrolled`, `remove`, `removeAll` with per-`keyId` snapshots.
* Android: Android Keystore key invalidation (`AES/CBC/PKCS7Padding`, API 24+).
  Uses built-in Kotlin; requires AGP 9+ and Flutter 3.44+ / Dart 3.12.
* iOS: LocalAuthentication domain state stored in the Keychain, using both
  `evaluatedPolicyDomainState` and the iOS 18+ `domainState.biometry.stateHash`.
* `migrateLegacy` to adopt snapshots created by `did_change_authlocal`.
