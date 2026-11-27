# biometric_change_detector example

Demonstrates every method of `biometric_change_detector`.

## Run

```bash
flutter run
```

## Try it

1. Make sure the device has a screen lock and at least one fingerprint or face.
   - Android emulator: Settings → Security → set a PIN, then add a fingerprint
     and touch the sensor with `adb -e emu finger touch 1`.
   - iOS Simulator: Features → Face ID → Enrolled.
2. Tap **Enroll**, then **Check** → `unchanged`.
3. Change the biometrics:
   - Android emulator: add another fingerprint (`adb -e emu finger touch 2`).
   - iOS Simulator: turn Features → Face ID → Enrolled off and on again.
4. Tap **Check** → `changed`. It stays `changed` until you tap **Enroll**
   again or **Remove**.
5. Try several key ids: each one is tracked independently.
   **Remove all** deletes every snapshot.
