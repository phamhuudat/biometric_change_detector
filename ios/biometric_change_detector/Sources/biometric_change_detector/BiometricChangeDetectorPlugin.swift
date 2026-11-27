import Flutter
import Foundation
import LocalAuthentication

public class BiometricChangeDetectorPlugin: NSObject, FlutterPlugin {
  /// Shared by every engine so Keychain operations never run concurrently.
  private static let queue = DispatchQueue(
    label: "io.github.phamhuudat.biometric_change_detector", qos: .userInitiated)
  private static let store = KeychainSnapshotStore()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "biometric_change_detector", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(BiometricChangeDetectorPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let keyId = args?["keyId"] as? String
    if call.method != "removeAll" && (keyId ?? "").isEmpty {
      result(FlutterError(code: "invalid_argument", message: "keyId is required", details: nil))
      return
    }
    Self.queue.async {
      let reply: Any?
      switch call.method {
      case "enroll": reply = Self.enroll(keyId!)
      case "check": reply = Self.check(keyId!).rawValue
      case "isEnrolled": reply = (try? Self.store.read(keyId!)) != nil
      case "remove": reply = Self.storageCall { try Self.store.delete(keyId!) }
      case "removeAll": reply = Self.storageCall { try Self.store.deleteAll() }
      case "migrateLegacy":
        reply = Self.migrateLegacy(keyId!, legacyToken: args?["iosDomainState"] as? String).rawValue
      default: reply = FlutterMethodNotImplemented
      }
      DispatchQueue.main.async { result(reply) }
    }
  }

  // MARK: - Operations

  private enum Status: String {
    case unchanged, changed, notEnrolled, unavailable
  }

  private static func enroll(_ keyId: String) -> Any? {
    switch probe() {
    case .state(let current):
      return storageCall { try store.write(keyId, current) }
    case .noBiometrics:
      return FlutterError(code: "biometricNotEnrolled", message: "No biometrics are enrolled", details: nil)
    case .noPasscode:
      return FlutterError(code: "passcodeNotSet", message: "The device has no passcode", details: nil)
    case .lockedOut:
      return FlutterError(code: "biometricLockedOut", message: "Biometrics are locked out", details: nil)
    case .notAvailable(let message):
      return FlutterError(code: "biometricNotAvailable", message: message, details: nil)
    }
  }

  private static func check(_ keyId: String) -> Status {
    let stored: BiometricSnapshot?
    do { stored = try store.read(keyId) } catch { return .unavailable }
    guard let snapshot = stored else { return .notEnrolled }

    switch probe() {
    case .state(let current):
      guard let same = matches(snapshot, current) else { return .unavailable }
      if !same { return .changed }
      // Backfill the iOS 18+ hash so the check keeps working if the legacy
      // API is removed in a future iOS.
      if snapshot.stateHash == nil, current.stateHash != nil {
        try? store.write(keyId, BiometricSnapshot(legacy: snapshot.legacy, stateHash: current.stateHash))
      }
      return .unchanged
    case .noBiometrics, .noPasscode:
      // Parity with Android, where the key is invalidated in these cases.
      return .changed
    case .lockedOut, .notAvailable:
      return .unavailable
    }
  }

  /// Adopts the base64 `evaluatedPolicyDomainState` stored by did_change_authlocal.
  private static func migrateLegacy(_ keyId: String, legacyToken: String?) -> Status {
    if (try? store.read(keyId)) != nil { return check(keyId) }
    guard let token = legacyToken?.trimmingCharacters(in: .whitespacesAndNewlines),
          !token.isEmpty,
          let legacy = Data(base64Encoded: token) else {
      return .notEnrolled
    }
    switch probe() {
    case .state(let current):
      guard let currentLegacy = current.legacy else { return .unavailable }
      if currentLegacy == legacy {
        try? store.write(keyId, current)
        return .unchanged
      }
      // Store the old state so the result stays `changed` until enroll/remove.
      try? store.write(keyId, BiometricSnapshot(legacy: legacy, stateHash: nil))
      return .changed
    case .noBiometrics, .noPasscode:
      try? store.write(keyId, BiometricSnapshot(legacy: legacy, stateHash: nil))
      return .changed
    case .lockedOut, .notAvailable:
      return .unavailable
    }
  }

  // MARK: - LocalAuthentication

  private enum Probe {
    case state(BiometricSnapshot)
    case noBiometrics
    case noPasscode
    case lockedOut
    case notAvailable(String?)
  }

  /// Reads the current biometric state with a fresh context, because the
  /// state is cached per `LAContext`.
  private static func probe() -> Probe {
    let context = LAContext()
    var error: NSError?
    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
      switch LAError.Code(rawValue: error?.code ?? 0) {
      case .biometryNotEnrolled: return .noBiometrics
      case .passcodeNotSet: return .noPasscode
      case .biometryLockout: return .lockedOut
      default: return .notAvailable(error?.localizedDescription)
      }
    }
    var snapshot = BiometricSnapshot(legacy: legacyDomainState(context), stateHash: nil)
    if #available(iOS 18.0, *) {
      snapshot.stateHash = context.domainState.biometry.stateHash
    }
    if snapshot.legacy == nil && snapshot.stateHash == nil {
      return .notAvailable("The biometric domain state is not available")
    }
    return .state(snapshot)
  }

  /// Deprecated in iOS 18 but still returned; kept because tokens saved by
  /// older plugins (and snapshots taken before iOS 18) use this value.
  private static func legacyDomainState(_ context: LAContext) -> Data? {
    context.evaluatedPolicyDomainState
  }

  /// Compares the source both sides have; prefers the iOS 18+ hash.
  /// Returns nil when there is nothing to compare.
  private static func matches(_ stored: BiometricSnapshot, _ current: BiometricSnapshot) -> Bool? {
    if let storedHash = stored.stateHash, let currentHash = current.stateHash {
      return storedHash == currentHash
    }
    if let storedLegacy = stored.legacy, let currentLegacy = current.legacy {
      return storedLegacy == currentLegacy
    }
    return nil
  }

  private static func storageCall(_ body: () throws -> Void) -> Any? {
    do {
      try body()
      return nil
    } catch {
      return FlutterError(code: "storageError", message: "\(error)", details: nil)
    }
  }
}
