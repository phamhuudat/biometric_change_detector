import Foundation
import Security

/// A biometric snapshot. `legacy` is `LAContext.evaluatedPolicyDomainState`
/// (iOS 9+, deprecated in iOS 18); `stateHash` is
/// `LAContext.domainState.biometry.stateHash` (iOS 18+). Either may be nil.
struct BiometricSnapshot: Codable, Equatable {
  var legacy: Data?
  var stateHash: Data?
}

enum KeychainStoreError: Error {
  /// The device has not been unlocked since boot.
  case locked
  case os(OSStatus)
  case corrupted
}

/// Stores one `BiometricSnapshot` per keyId as a generic password item that
/// never leaves the device (`AfterFirstUnlockThisDeviceOnly`).
///
/// Keychain items survive uninstalling the app, so the first call after a
/// (re)install deletes every item of this plugin. UserDefaults, which is
/// deleted with the app, records that this already happened.
final class KeychainSnapshotStore {
  private static let installedFlagKey = "io.github.phamhuudat.biometric_change_detector.installed"

  private let service: String
  private let defaults: UserDefaults
  private var installChecked = false

  init(bundleIdentifier: String? = Bundle.main.bundleIdentifier, defaults: UserDefaults = .standard) {
    self.service = "\(bundleIdentifier ?? "app").biometric_change_detector"
    self.defaults = defaults
  }

  func read(_ keyId: String) throws -> BiometricSnapshot? {
    try clearIfFreshInstall()
    var query = baseQuery(keyId)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    switch status {
    case errSecSuccess:
      guard let data = item as? Data,
            let snapshot = try? JSONDecoder().decode(BiometricSnapshot.self, from: data) else {
        throw KeychainStoreError.corrupted
      }
      return snapshot
    case errSecItemNotFound:
      return nil
    case errSecInteractionNotAllowed:
      throw KeychainStoreError.locked
    default:
      throw KeychainStoreError.os(status)
    }
  }

  func write(_ keyId: String, _ snapshot: BiometricSnapshot) throws {
    try clearIfFreshInstall()
    let data = try JSONEncoder().encode(snapshot)
    // Delete first so a changed accessibility attribute never blocks the add.
    SecItemDelete(baseQuery(keyId) as CFDictionary)
    var attributes = baseQuery(keyId)
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(attributes as CFDictionary, nil)
    switch status {
    case errSecSuccess: return
    case errSecInteractionNotAllowed: throw KeychainStoreError.locked
    default: throw KeychainStoreError.os(status)
    }
  }

  func delete(_ keyId: String) throws {
    try clearIfFreshInstall()
    try checkDelete(SecItemDelete(baseQuery(keyId) as CFDictionary))
  }

  func deleteAll() throws {
    try checkDelete(SecItemDelete(serviceQuery() as CFDictionary))
    defaults.set(true, forKey: Self.installedFlagKey)
    installChecked = true
  }

  private func clearIfFreshInstall() throws {
    if installChecked { return }
    if !defaults.bool(forKey: Self.installedFlagKey) {
      try deleteAll()
    }
    installChecked = true
  }

  private func checkDelete(_ status: OSStatus) throws {
    switch status {
    case errSecSuccess, errSecItemNotFound: return
    case errSecInteractionNotAllowed: throw KeychainStoreError.locked
    default: throw KeychainStoreError.os(status)
    }
  }

  private func serviceQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
    ]
  }

  private func baseQuery(_ keyId: String) -> [String: Any] {
    var query = serviceQuery()
    query[kSecAttrAccount as String] = keyId
    return query
  }
}
