import Foundation
import Security

/// The device-bound reconciliation identity, in the iOS Keychain.
///
/// ===========================================================================
/// Why the Keychain and not a file
/// ===========================================================================
///
/// F-06 persisted the pseudonymization salt in a file beside the save, covered
/// by the same backup exclusions. On Android that is enough. On iOS it was not,
/// and the way it failed is worth stating precisely because it is subtle:
///
///   1. Application Support is included in iCloud backup by default. No
///      Info.plist key and no build setting changes that.
///   2. So the save slots, the ledger journal, and the identity file all
///      travelled together in a restore.
///   3. On the second device the salt fingerprint therefore still matched the
///      one recorded in the restored snapshot envelope.
///   4. `SaveRepository._checkSalt` passed. `LoadRefusal.originKeyReset` never
///      fired.
///   5. The step ledger then resumed against a HealthKit source the *original*
///      device had already consumed from — the double-grant the entire
///      reconciliation design exists to prevent, now silent.
///
/// The fail-closed check was defeated by the exact transport it was designed to
/// detect, because the evidence and the thing it was meant to prove travelled
/// in the same suitcase.
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` breaks the pairing.
/// `ThisDeviceOnly` items are not included in an encrypted backup and are not
/// restored onto a different device. A restored phone therefore finds the save
/// present and the identity **absent**, which is `originIdentityMissing`, and
/// the refusal fires again.
///
/// `AfterFirstUnlock` rather than `WhenUnlocked`: cold-launch backfill and any
/// best-effort background wake must be able to read this once the device has
/// been unlocked once since boot. `WhenUnlocked` would fail on a pocketed
/// phone, and while that failure is *typed* rather than silent, designing so
/// that the normal path runs through the error path is not a design.
///
/// `kSecAttrSynchronizable` is explicitly false. `ThisDeviceOnly` already
/// precludes iCloud Keychain sync; stating it means a later edit that relaxes
/// the accessibility class does not silently also enable sync.
///
/// ===========================================================================
/// What this code cannot prove
/// ===========================================================================
///
/// The simulator has a Keychain and honours `SecItemAdd`, `SecItemCopyMatching`
/// and the `kSecAttrAccessible` attribute, so creation, read, delete, add-only
/// semantics, and the configured accessibility constant are all testable in CI.
///
/// **Nothing here proves the backup behaviour itself.** That an item with this
/// accessibility is genuinely omitted from an encrypted iCloud backup, and
/// genuinely not restored to a second device, is a property of Apple's backup
/// implementation. It can only be demonstrated with two physical iPhones, an
/// iCloud account, a real backup and a real restore. Until that is done it is
/// documented Apple behaviour that this code relies on, not a verified claim.
enum KeychainAccessibility {
  /// The one value this app is allowed to use. Exposed so both the production
  /// path and the test assert the same constant rather than two spellings.
  static let required = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
}

/// The stored record.
struct SecureIdentityRecord: Equatable {
  let saveId: String
  let salt: Data
}

/// What a read produced.
///
/// Three cases, and the third is the entire safety argument. `absent` is only
/// ever produced by `errSecItemNotFound`; every other non-success status is
/// `unavailable`. A locked-device read reporting absence is how a replacement
/// identity gets minted over a live save.
enum SecureReadOutcome: Equatable {
  case found(SecureIdentityRecord)
  case absent
  case unavailable(OSStatus)
}

enum SecureWriteOutcome: Equatable {
  case created
  /// `errSecDuplicateItem`. **Never** followed by an update.
  case alreadyExists
  case failed(OSStatus)
}

/// The seam. Production talks to the Keychain; the adapter tests substitute a
/// fake so mapping rules are asserted without touching the device store.
protocol SecureIdentityBackend {
  func read() -> SecureReadOutcome
  func create(_ record: SecureIdentityRecord) -> SecureWriteOutcome
  @discardableResult func delete() -> Bool
  /// The raw `kSecAttrAccessible` value on the stored item, or nil when there
  /// is none. Diagnostics only.
  func storedAccessibility() -> String?
}

/// The real Keychain.
struct KeychainIdentityStore: SecureIdentityBackend {

  /// Fixed literals. Never derived from a device name, a health source, or
  /// anything the player can influence — a keychain service string is as much
  /// a privacy artifact as a filename, and the same rule applies.
  static let service = "com.projectstride.stride.reconciliation-identity"
  static let account = "reconciliation-identity"

  /// There is deliberately no `kSecAttrAccessGroup`. An access group is what
  /// would let a sibling app or an app-extension share this item, and sharing
  /// a device-binding token is the opposite of what it is for.
  private func baseQuery() -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.account,
      // Explicit. `ThisDeviceOnly` already precludes sync; saying so means a
      // later relaxation of the accessibility class does not silently also
      // turn on iCloud Keychain.
      kSecAttrSynchronizable as String: false,
    ]
  }

  func read() -> SecureReadOutcome {
    var query = baseQuery()
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    switch status {
    case errSecSuccess:
      guard let data = item as? Data, let record = Self.decode(data) else {
        // Present but unreadable. **Not absence.** A corrupt record reported
        // as "new installation" is how the bootstrap comes to mint a second
        // identity beside a save it can no longer interpret.
        return .unavailable(errSecDecode)
      }
      return .found(record)

    case errSecItemNotFound:
      // The only path to `absent`.
      return .absent

    default:
      // Everything else, and `errSecInteractionNotAllowed` (-25308) in
      // particular: that is what a read gets before the first unlock since
      // boot, and it means "ask me later", not "there is nothing here".
      return .unavailable(status)
    }
  }

  func create(_ record: SecureIdentityRecord) -> SecureWriteOutcome {
    guard let data = Self.encode(record) else { return .failed(errSecParam) }

    var attributes = baseQuery()
    attributes[kSecValueData as String] = data
    attributes[kSecAttrAccessible as String] = KeychainAccessibility.required

    let status = SecItemAdd(attributes as CFDictionary, nil)
    switch status {
    case errSecSuccess:
      return .created
    case errSecDuplicateItem:
      // Reported, never repaired. There is no `SecItemUpdate` anywhere in this
      // file, and its absence is the enforcement: a caller whose read just
      // failed cannot express an overwrite.
      return .alreadyExists
    default:
      return .failed(status)
    }
  }

  @discardableResult
  func delete() -> Bool {
    // Deleting is scoped by service and account only. Synchronizable is set to
    // `any` here so a stray synchronizable item from an earlier build cannot
    // survive a reset and reappear as a second identity.
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.account,
      kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
    ]

    let status = SecItemDelete(query as CFDictionary)
    return status == errSecSuccess
  }

  func storedAccessibility() -> String? {
    var query = baseQuery()
    query[kSecReturnAttributes as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let attributes = item as? [String: Any]
    else { return nil }

    return attributes[kSecAttrAccessible as String] as? String
  }

  // MARK: - Encoding
  //
  // One item holding both fields, so the lineage id and the salt can never be
  // half-written relative to each other. Two items would give a window in which
  // a save id exists with no salt.

  static func encode(_ record: SecureIdentityRecord) -> Data? {
    let payload: [String: Any] = [
      "saveId": record.saveId,
      "salt": record.salt.base64EncodedString(),
    ]
    return try? JSONSerialization.data(withJSONObject: payload)
  }

  static func decode(_ data: Data) -> SecureIdentityRecord? {
    guard
      let object = try? JSONSerialization.jsonObject(with: data),
      let map = object as? [String: Any],
      let saveId = map["saveId"] as? String,
      let salt = map["salt"] as? String,
      let bytes = Data(base64Encoded: salt)
    else { return nil }
    return SecureIdentityRecord(saveId: saveId, salt: bytes)
  }
}
