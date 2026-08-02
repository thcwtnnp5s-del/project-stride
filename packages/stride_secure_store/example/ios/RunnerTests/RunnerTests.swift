import Flutter
import Security
import UIKit
import XCTest

@testable import stride_secure_store

// =============================================================================
// Diagnostics
//
// Every assertion in this file that touches a `SecItem*` API reports the
// numeric OSStatus. This is not decoration. The first CI run of this suite
// failed twelve tests and the log said only which ones; "expected absent"
// tells you nothing, and "expected absent, got unavailable(-34018
// errSecMissingEntitlement)" tells you the host was unsigned and none of the
// logic under test was ever reached. One is a cycle of guessing and one is the
// answer.
// =============================================================================

/// An OSStatus as a number plus, where the platform knows one, a name.
///
/// The number comes first and is never omitted: `SecCopyErrorMessageString`
/// returns nil for plenty of real statuses, and a failure message that degrades
/// to "unknown error" is the failure this function exists to prevent.
func describe(_ status: OSStatus) -> String {
  // A small table for the statuses this code actually reasons about, because
  // these are the ones whose names carry the diagnosis.
  //
  // Written as literals rather than as the `errSec*` symbols on purpose: the
  // per-platform availability of some of those constants varies by SDK, and a
  // diagnostic helper that fails to compile costs a whole CI cycle to find out
  // about. The numbers are the stable part — they are what appears in a log.
  let known: [OSStatus: String] = [
    0: "errSecSuccess",
    -25300: "errSecItemNotFound",
    -25299: "errSecDuplicateItem",
    -25308: "errSecInteractionNotAllowed",
    -26275: "errSecDecode",
    -50: "errSecParam",
    -34018: "errSecMissingEntitlement",
  ]
  if let name = known[status] { return "\(status) \(name)" }
  if let message = SecCopyErrorMessageString(status, nil) {
    return "\(status) (\(message))"
  }
  return "\(status)"
}

func describe(_ outcome: SecureReadOutcome) -> String {
  switch outcome {
  case .found(let record):
    return ".found(saveId: \(record.saveId), salt: \(record.salt.count) bytes)"
  case .absent:
    return ".absent"
  case .unavailable(let status):
    return ".unavailable(\(describe(status)))"
  }
}

func describe(_ outcome: SecureWriteOutcome) -> String {
  switch outcome {
  case .created: return ".created"
  case .alreadyExists: return ".alreadyExists"
  case .failed(let status): return ".failed(\(describe(status)))"
  }
}

/// A probe, not a test. It asserts nothing and cannot fail.
///
/// It performs the three Keychain calls the store performs, against its own
/// service string, and prints the raw OSStatus of each. The point is that the
/// *environment* — specifically whether the test host was signed and therefore
/// has an `application-identifier` entitlement — is legible in the CI log of
/// every run, passing or failing.
///
/// The workflow runs this suite on its own against a deliberately unsigned host
/// (`CODE_SIGNING_ALLOWED=NO`) as a diagnostic step, which is how the -34018
/// claim in the comments above is evidence rather than folklore.
final class KeychainEntitlementProbe: XCTestCase {

  /// Deliberately not `KeychainIdentityStore.service`. A probe that shared the
  /// real item's identity could leave state behind that made a real test pass
  /// or fail for a reason that had nothing to do with it.
  private static let service = "com.projectstride.stride.ci-entitlement-probe"
  private static let account = "probe"

  private func query(_ extra: [String: Any] = [:]) -> CFDictionary {
    var q: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Self.service,
      kSecAttrAccount as String: Self.account,
    ]
    for (k, v) in extra { q[k] = v }
    return q as CFDictionary
  }

  override func setUp() {
    super.setUp()
    _ = SecItemDelete(query())
  }

  override func tearDown() {
    _ = SecItemDelete(query())
    super.tearDown()
  }

  func testProbeReportsTheRawKeychainStatusesAndNeverFails() {
    var item: CFTypeRef?

    let emptyRead = SecItemCopyMatching(
      query([kSecReturnData as String: true]), &item)
    let add = SecItemAdd(
      query([
        kSecValueData as String: Data([0x01]),
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      ]), nil)
    let readBack = SecItemCopyMatching(
      query([kSecReturnData as String: true]), &item)

    // `print`, not an assertion. xcodebuild captures stdout, and the workflow
    // greps for this prefix on both the passing and the failing path.
    print("KEYCHAIN PROBE: SecItemCopyMatching(nothing stored) -> \(describe(emptyRead))")
    print("KEYCHAIN PROBE: SecItemAdd                          -> \(describe(add))")
    print("KEYCHAIN PROBE: SecItemCopyMatching(after add)      -> \(describe(readBack))")
    print(
      """
      KEYCHAIN PROBE: expected on a signed host: \
      \(describe(-25300)) / \(describe(0)) / \(describe(0)). \
      All three coming back \(describe(-34018)) means the test host carries no \
      application-identifier entitlement, which means code signing was \
      disabled for this step and no Keychain logic was exercised at all.
      """)
  }
}

/// Simulator tests for the device-bound identity store.
///
/// ===========================================================================
/// What these prove
/// ===========================================================================
///
/// The iOS Simulator has a real Keychain. `SecItemAdd`, `SecItemCopyMatching`,
/// `SecItemDelete` and the `kSecAttrAccessible` attribute all behave, and
/// `NSURLIsExcludedFromBackupKey` is a real resource value on a real APFS
/// volume. So this suite genuinely exercises:
///
///   * key creation and read-back, including the salt byte for byte
///   * that a second create does not overwrite the first
///   * that a create over an item whose read just *failed* does not overwrite
///     it either, byte for byte and attribute for attribute
///   * that a present-but-unreadable item reads as `unavailable`, never
///     `absent`
///   * that no operation here can bring an item into existence, and that none
///     of them produces a synchronizable one
///   * that the item persists past the object that wrote it
///   * that `kSecAttrAccessible` is exactly
///     `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
///   * that the exclusion is applied and verified on real paths, including
///     paths named the way `StorageLayout` names them
///   * that the exclusion is re-applied after the directory is deleted and
///     recreated, which is the case a one-shot implementation gets wrong
///   * **that an atomic write and a rename over the top each destroy the
///     exclusion**, which is why a launch-only application is not enough and
///     `BACKUP_EXCLUSION_CONTRACT.md` exists — and, as the counter-cases, that
///     an in-place truncate and `FileManager.replaceItemAt` each preserve it
///
/// ===========================================================================
/// What these CANNOT prove — read this before quoting the suite as evidence
/// ===========================================================================
///
/// 1. **That `ThisDeviceOnly` items are omitted from an iCloud backup.** That
///    is a property of Apple's backup implementation. There is no API to ask.
///    It needs two physical iPhones, an iCloud account, a real backup and a
///    real restore.
/// 2. **That `NSURLIsExcludedFromBackupKey` is honoured by iCloud or by
///    Finder.** Same reason. Setting an attribute and reading it back proves
///    the attribute is set, and nothing more.
/// 3. **Anything about a locked device.** A simulator is never locked, so
///    `errSecInteractionNotAllowed` — the status the whole `unavailable`
///    outcome exists for — is not reachable here. Its handling is covered by
///    the Dart port test with a fake, which proves the mapping, not the
///    trigger.
/// 4. **Relaunch, honestly.** `testItemSurvivesANewStoreInstance` proves the
///    item is not in-process state. It is not a process relaunch: XCTest runs
///    one host process. A true cold-launch read after a device reboot needs a
///    physical device.
/// 5. **That the app's real save directory is covered.** These tests use
///    temporary directories named the way `StorageLayout` names files. The
///    binding between the two is asserted in Dart
///    (`test/identity_vault_test.dart`, "cover the directory and every file
///    StorageLayout declares") and by
///    `Scripts/check-backup-exclusions.sh`, because `StorageLayout` is Dart and
///    is not reachable from Swift.
final class SecureStoreTests: XCTestCase {

  private let store = KeychainIdentityStore()

  override func setUp() {
    super.setUp()
    // The simulator Keychain is shared across runs of the same simulator
    // device, so a leftover item from a previous run would make
    // `testCreateThenRead` pass for the wrong reason.
    store.delete()
  }

  override func tearDown() {
    store.delete()
    super.tearDown()
  }

  private func record(_ saveId: String = "lineage-one") -> SecureIdentityRecord {
    // Sixteen bytes, not all equal, including 0x00 and 0xFF — a truncation, a
    // fill, or a C-string conversion each show up as a different failure.
    SecureIdentityRecord(
      saveId: saveId,
      salt: Data([0x00, 0x01, 0x7F, 0x80, 0xFF, 0x2A, 0x13, 0x64,
                  0xAB, 0xCD, 0xEF, 0x10, 0x20, 0x30, 0x40, 0x50])
    )
  }

  // MARK: - 1. Creation and read

  func testCreateThenRead() {
    let expected = record()

    let created = store.create(expected)
    XCTAssertEqual(created, .created, "create returned \(describe(created))")

    let outcome = store.read()
    guard case .found(let actual) = outcome else {
      return XCTFail("a created item must read back as .found, got \(describe(outcome))")
    }
    XCTAssertEqual(actual.saveId, expected.saveId)
    // Every byte. A salt that comes back with one byte changed re-keys every
    // origin, and the live retention window is granted a second time.
    XCTAssertEqual(actual.salt, expected.salt)
  }

  func testReadWithNothingStoredIsAbsentNotAnError() {
    // Absence is a normal state — it is what a genuinely new installation looks
    // like — and it must be distinguishable from a store that could not answer.
    let outcome = store.read()
    guard case .absent = outcome else {
      return XCTFail(
        """
        An empty keychain must report .absent, got \(describe(outcome)).

        errSecMissingEntitlement here is not a defect in this store: it means \
        the test host was built without a signature and so has no \
        application-identifier entitlement, and the Keychain refused the call \
        before any of the logic under test ran.
        """)
    }
  }

  func testItemSurvivesANewStoreInstance() {
    let created = store.create(record())
    XCTAssertEqual(created, .created, "create returned \(describe(created))")

    // A different object, reading the same platform store. This proves the
    // record is not in-process state.
    //
    // It is NOT a relaunch: XCTest runs one host process, and a true
    // cold-launch read after a device reboot needs a physical device. See the
    // class comment.
    let second = KeychainIdentityStore()
    let outcome = second.read()
    guard case .found(let actual) = outcome else {
      return XCTFail(
        "the item must outlive the object that wrote it, got \(describe(outcome))")
    }
    XCTAssertEqual(actual.saveId, "lineage-one")
  }

  // MARK: - 2. Add-only — the rule the whole design rests on

  func testSecondCreateDoesNotOverwriteTheFirst() {
    let first = store.create(record("first"))
    XCTAssertEqual(first, .created, "the first create returned \(describe(first))")

    let outcome = store.create(record("second"))

    XCTAssertEqual(
      outcome, .alreadyExists,
      "a second create must be reported, never applied; got \(describe(outcome))"
    )

    let read = store.read()
    guard case .found(let actual) = read else {
      return XCTFail("the original must still be there, got \(describe(read))")
    }
    XCTAssertEqual(
      actual.saveId, "first",
      "overwriting a live identity orphans the save it belongs to"
    )
  }

  func testDeleteRemovesTheItem() {
    let created = store.create(record())
    XCTAssertEqual(created, .created, "create returned \(describe(created))")
    XCTAssertTrue(store.delete(), "delete reported failure")

    let outcome = store.read()
    guard case .absent = outcome else {
      return XCTFail("a deleted item must read back as .absent, got \(describe(outcome))")
    }
  }

  // MARK: - 3. Accessibility — ThisDeviceOnly is the entire control

  func testStoredItemIsAfterFirstUnlockThisDeviceOnly() {
    let created = store.create(record())
    XCTAssertEqual(created, .created, "create returned \(describe(created))")

    XCTAssertEqual(
      store.storedAccessibility(),
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String,
      """
      The item must be AfterFirstUnlockThisDeviceOnly.

      ThisDeviceOnly is what keeps it out of an encrypted backup and off a
      restored second device. Without it the identity travels with the save,
      the salt fingerprint matches, LoadRefusal.originKeyReset never fires, and
      the ledger replays against a HealthKit source the first device already
      consumed from.

      AfterFirstUnlock rather than WhenUnlocked so cold-launch backfill can read
      it on a pocketed phone that has been unlocked once since boot.
      """
    )
  }

  func testTheAccessibilityConstantMatchesTheValuePinnedInDart() {
    // `kExpectedKeychainAccessibility` in lib/src/keychain_identity_store.dart
    // is 'cku', asserted by the Dart suite on Windows where Apple's constant is
    // unavailable. This is the other half of that pin: if Apple ever changed
    // the raw value, the Dart assertion would be silently wrong and only this
    // test would notice.
    XCTAssertEqual(
      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String, "cku")
  }

  func testStoredItemIsNotSynchronizable() {
    let created = store.create(record())
    XCTAssertEqual(created, .created, "create returned \(describe(created))")

    // iCloud Keychain sync would be a second way for the identity to reach
    // another device, and it would defeat the control just as thoroughly as a
    // backup does. `ThisDeviceOnly` already precludes it; this asserts the
    // explicit `kSecAttrSynchronizable: false` rather than relying on that.
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: KeychainIdentityStore.service,
      kSecAttrAccount as String: KeychainIdentityStore.account,
      kSecAttrSynchronizable as String: true,
      kSecReturnData as String: true,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    XCTAssertEqual(
      status, errSecItemNotFound,
      "no synchronizable copy of the identity may exist; got \(describe(status))")

    query[kSecAttrSynchronizable as String] = false
    let nonSync = SecItemCopyMatching(query as CFDictionary, &item)
    XCTAssertEqual(
      nonSync, errSecSuccess,
      "the non-synchronizable item must be readable; got \(describe(nonSync))")
  }

  // MARK: - 3b. Nothing but a create may write, and nothing recreates

  /// Adds an item directly, bypassing the store, so a test can set up states
  /// the store's own API cannot produce.
  @discardableResult
  private func addRaw(
    data: Data,
    synchronizable: Bool = false,
    accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
  ) -> OSStatus {
    let attributes: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: KeychainIdentityStore.service,
      kSecAttrAccount as String: KeychainIdentityStore.account,
      kSecAttrSynchronizable as String: synchronizable,
      kSecAttrAccessible as String: accessible,
      kSecValueData as String: data,
    ]
    return SecItemAdd(attributes as CFDictionary, nil)
  }

  /// The raw bytes currently stored, bypassing `decode`.
  private func rawStoredData() -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: KeychainIdentityStore.service,
      kSecAttrAccount as String: KeychainIdentityStore.account,
      kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else {
      return nil
    }
    return item as? Data
  }

  func testAPresentButUnreadableItemIsUnavailableNotAbsent() {
    // The status a real device produces for this case is
    // errSecInteractionNotAllowed, and a simulator is never locked, so that
    // exact trigger is unreachable here. This exercises the same branch through
    // the one non-success path that IS reachable: an item that is present and
    // does not decode.
    //
    // The rule under test is the general one — everything that is not
    // errSecItemNotFound is `unavailable` — and getting it wrong for a corrupt
    // record is the same defect as getting it wrong for a locked device: the
    // bootstrap is told a phone with a live save is a new installation.
    let added = addRaw(data: Data([0xDE, 0xAD, 0xBE, 0xEF]))
    XCTAssertEqual(added, errSecSuccess, "SecItemAdd returned \(describe(added))")

    switch store.read() {
    case .unavailable(let status):
      XCTAssertEqual(
        status, errSecDecode,
        "an item that is present and does not decode must report errSecDecode; "
          + "got \(describe(status))")
    case .absent:
      XCTFail(
        """
        A present-but-unreadable item reported as .absent is how the bootstrap \
        comes to mint a second identity beside a save it can no longer \
        interpret. Absence must be reachable only from errSecItemNotFound.
        """)
    case .found:
      XCTFail("garbage must not decode to a record")
    }
  }

  func testACreateAfterAFailedReadDoesNotClobberTheStoredItem() {
    // The ruling's fifth item, executed rather than argued. Set up the exact
    // situation the rule names: an item is present, a read of it fails, and a
    // caller then tries to create a replacement.
    let existing = Data([0xDE, 0xAD, 0xBE, 0xEF])
    let added = addRaw(data: existing)
    XCTAssertEqual(added, errSecSuccess, "SecItemAdd returned \(describe(added))")

    let before = store.read()
    guard case .unavailable = before else {
      return XCTFail("precondition: the read must fail, got \(describe(before))")
    }

    let outcome = store.create(record("replacement"))

    XCTAssertEqual(
      outcome, .alreadyExists,
      "SecItemAdd must refuse, because there is no update path to fall back on; "
        + "got \(describe(outcome))")
    XCTAssertEqual(
      rawStoredData(), existing,
      """
      The stored bytes must be byte-for-byte what they were. An unreadable \
      record may still be the live identity — this is what a partially failed \
      write or a future format looks like — and replacing it orphans the save \
      whose origin keys it produced.
      """)
  }

  func testAFailedReadFollowedByCreateLeavesTheAccessibilityAlone() {
    // A create that was refused must not have edited the item's attributes
    // either. `SecItemAdd` returning errSecDuplicateItem is documented as
    // making no change; this pins it, because a variant that relaxed
    // accessibility on the existing item would be invisible everywhere else.
    let added = addRaw(
      data: Data([0x01]), accessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
    XCTAssertEqual(added, errSecSuccess, "SecItemAdd returned \(describe(added))")

    _ = store.create(record())

    XCTAssertEqual(
      store.storedAccessibility(),
      kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String,
      "a refused create must change nothing at all, attributes included")
  }

  func testReadingAnEmptyStoreCreatesNothing() {
    // Every query in this file must be incapable of creating an item. A
    // `SecItemCopyMatching` cannot, but a future edit that reached for
    // `SecItemAdd`-on-miss inside a read would be exactly the "write after a
    // failed read" the design forbids, and would look reasonable in review.
    _ = store.read()
    _ = store.storedAccessibility()
    _ = store.read()

    XCTAssertNil(rawStoredData(), "no read may bring an item into existence")
  }

  func testNoOperationEverProducesASynchronizableItem() {
    // Checked after every operation rather than only after a create. iCloud
    // Keychain sync is a second transport to another device and would defeat
    // the control exactly as a backup does.
    let created = store.create(record())
    XCTAssertEqual(created, .created, "create returned \(describe(created))")
    _ = store.read()
    _ = store.storedAccessibility()
    _ = store.create(record("second"))

    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: KeychainIdentityStore.service,
      kSecAttrAccount as String: KeychainIdentityStore.account,
      kSecAttrSynchronizable as String: true,
      kSecReturnData as String: true,
    ]
    var item: CFTypeRef?
    let sync = SecItemCopyMatching(query as CFDictionary, &item)
    XCTAssertEqual(
      sync, errSecItemNotFound,
      "no synchronizable copy of the identity may exist after any operation; "
        + "got \(describe(sync))")

    query[kSecAttrSynchronizable as String] = false
    let nonSync = SecItemCopyMatching(query as CFDictionary, &item)
    XCTAssertEqual(
      nonSync, errSecSuccess,
      "the non-synchronizable item must be readable; got \(describe(nonSync))")
  }

  func testDeleteSweepsUpAStraySynchronizableItem() {
    // The one place the base query is deliberately widened. An older build, or
    // a bug, could have left a synchronizable item behind; a reset that left it
    // in place would let it reappear afterwards as a second identity.
    let added = addRaw(data: Data([0x01]), synchronizable: true)
    XCTAssertEqual(added, errSecSuccess, "SecItemAdd returned \(describe(added))")

    XCTAssertTrue(store.delete(), "delete reported failure")
    XCTAssertNil(rawStoredData())
  }

  // MARK: - 4. Encoding

  func testTheRecordRoundTripsThroughItsEncoding() {
    let original = record("lineage-with-/+=-base64-edge-bytes")
    guard let data = KeychainIdentityStore.encode(original),
      let decoded = KeychainIdentityStore.decode(data)
    else {
      return XCTFail("the record must round-trip")
    }
    XCTAssertEqual(decoded, original)
  }

  func testGarbageDecodesToNilRatherThanAnEmptyRecord() {
    // A record that decoded to an empty salt would be *worse* than a failed
    // read: it would be accepted, and every origin would key against sixteen
    // zero bytes.
    XCTAssertNil(KeychainIdentityStore.decode(Data([0xDE, 0xAD, 0xBE, 0xEF])))
    XCTAssertNil(KeychainIdentityStore.decode(Data("{}".utf8)))
    XCTAssertNil(KeychainIdentityStore.decode(Data("{\"saveId\":\"a\"}".utf8)))
  }
}

/// Backup exclusion, on real paths.
final class BackupExclusionTests: XCTestCase {

  private var root: URL!

  /// The filenames `StorageLayout` declares.
  ///
  /// Duplicated from Dart because `StorageLayout` is not reachable from Swift.
  /// The duplication is *checked*: `Scripts/check-backup-exclusions.sh` reads
  /// the real list out of `file_storage.dart` and fails if this list drifts, so
  /// a sixth file cannot be added on one side alone.
  static let declaredFiles = [
    "save_slot_a",
    "save_slot_b",
    "ledger_journal",
    "ledger_journal.compacting",
    "reconciliation_identity",
    "transaction.lock",
  ]

  override func setUpWithError() throws {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("project_stride_test_\(UUID().uuidString)")
    try FileManager.default.createDirectory(
      at: root, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: root)
  }

  private func create(_ names: [String]) -> [String] {
    names.map { name in
      let url = root.appendingPathComponent(name)
      FileManager.default.createFile(atPath: url.path, contents: Data([0x01]))
      return url.path
    }
  }

  private func isExcluded(_ path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    let values = try? url.resourceValues(forKeys: [.isExcludedFromBackupKey])
    return values?.isExcludedFromBackup == true
  }

  // MARK: - 1. The directory and every declared file

  func testEveryDeclaredFileIsExcluded() {
    let paths = create(Self.declaredFiles)

    let report = BackupExclusion.apply(directoryPath: root.path, filePaths: paths)

    XCTAssertTrue(report.failed.isEmpty, "failed: \(report.failed)")
    // The directory plus all six.
    XCTAssertEqual(report.excluded.count, Self.declaredFiles.count + 1)

    XCTAssertTrue(isExcluded(root.path), "the directory itself must be excluded")
    for path in paths {
      // Not inherited. The attribute is documented per-node, and a directory
      // that is excluded while a file inside it is not is still a ledger that
      // travels.
      XCTAssertTrue(isExcluded(path), "\(path) must be excluded in its own right")
    }
  }

  func testAFileThatDoesNotExistIsMissingNotFailed() {
    // `StorageLayout.allFiles` names every file the layout *may* create. The
    // journal sidecar exists only during a compaction, and reporting its
    // absence as a fault would make a healthy launch look broken.
    let report = BackupExclusion.apply(
      directoryPath: root.path,
      filePaths: [root.appendingPathComponent("ledger_journal.compacting").path]
    )

    XCTAssertEqual(report.missing.count, 1)
    XCTAssertTrue(report.failed.isEmpty)
  }

  // MARK: - 2. The case a one-shot implementation gets wrong

  func testExclusionIsReappliedAfterTheDirectoryIsRecreated() throws {
    var paths = create(["save_slot_a"])
    _ = BackupExclusion.apply(directoryPath: root.path, filePaths: paths)
    XCTAssertTrue(isExcluded(root.path))

    // Exactly what a restore, a reinstall, or a wipe-and-recover does. The
    // attribute lives on the filesystem node, so it goes with the node.
    try FileManager.default.removeItem(at: root)
    try FileManager.default.createDirectory(
      at: root, withIntermediateDirectories: true)
    paths = create(["save_slot_a"])

    XCTAssertFalse(
      isExcluded(root.path),
      "the fixture must actually lose the attribute, or this proves nothing")

    let report = BackupExclusion.apply(directoryPath: root.path, filePaths: paths)

    XCTAssertTrue(report.failed.isEmpty)
    XCTAssertTrue(isExcluded(root.path))
    XCTAssertTrue(isExcluded(paths[0]))
  }

  func testApplyingTwiceIsIdempotent() {
    let paths = create(["save_slot_a"])

    _ = BackupExclusion.apply(directoryPath: root.path, filePaths: paths)
    let second = BackupExclusion.apply(directoryPath: root.path, filePaths: paths)

    // It runs on every launch, so "already excluded" must be a success and not
    // an error anyone is tempted to suppress.
    XCTAssertTrue(second.failed.isEmpty)
    XCTAssertEqual(second.excluded.count, 2)
  }

  // MARK: - 2b. The case a launch-only implementation gets wrong
  //
  // Apple documents NSURLIsExcludedFromBackupKey as a resource value on the
  // filesystem node. These tests demonstrate the consequence on a real APFS
  // volume: the ordinary file operations a save system performs leave the path
  // naming a different node, and the new node was never excluded.
  //
  // This is the evidence for BACKUP_EXCLUSION_CONTRACT.md. Without the
  // per-write re-application, an atomic write, a rename over the top, or a
  // file created after the launch sweep each leaves a file that would travel in
  // a restore, with nothing anywhere reporting it.
  //
  // Two operations are counter-cases and are asserted as such, so the contract
  // is precise rather than superstitious: an in-place truncate and
  // `FileManager.replaceItemAt` both PRESERVE the attribute. Neither is an
  // operation `stride_storage` performs, and re-application after them is a
  // cheap no-op, so nothing rests on that — but a rule stated more broadly than
  // the evidence supports is how a contract stops being believed.

  func testAnAtomicWriteDropsTheExclusion() {
    let path = create(["save_slot_a"])[0]
    _ = BackupExclusion.apply(paths: [path])
    XCTAssertTrue(isExcluded(path))

    // `.atomic` writes a temporary file and renames it over the destination.
    // The destination path now names the temporary file's node.
    try? Data([0x02]).write(to: URL(fileURLWithPath: path), options: .atomic)

    XCTAssertFalse(
      isExcluded(path),
      "an atomic write replaces the node, and the exclusion goes with it")

    XCTAssertTrue(BackupExclusion.apply(paths: [path]).failed.isEmpty)
    XCTAssertTrue(isExcluded(path))
  }

  func testARenameOverTheTopDropsTheExclusion() {
    // This is `FileLedgerJournal.replaceLines`, exactly: write the sidecar,
    // then rename it over the journal. Dart's `File.rename` is rename(2), which
    // replaces the directory entry.
    let journal = root.appendingPathComponent("ledger_journal")
    let sidecar = root.appendingPathComponent("ledger_journal.compacting")

    FileManager.default.createFile(atPath: journal.path, contents: Data([0x01]))
    _ = BackupExclusion.apply(paths: [journal.path])
    XCTAssertTrue(isExcluded(journal.path))

    // The sidecar is fresh. The launch sweep reported it `missing`, because it
    // did not exist then — which is healthy, and is also why it carries no
    // attribute now.
    FileManager.default.createFile(atPath: sidecar.path, contents: Data([0x02]))
    XCTAssertEqual(rename(sidecar.path, journal.path), 0)

    XCTAssertFalse(
      isExcluded(journal.path),
      """
      After a journal compaction the journal path names the sidecar's node. \
      A launch-only application of the exclusion is therefore correct until \
      the first compaction and silently wrong after it — the ledger would \
      travel in a restore and replay against a health source the original \
      device already consumed from.
      """)

    XCTAssertTrue(BackupExclusion.apply(paths: [journal.path]).failed.isEmpty)
    XCTAssertTrue(isExcluded(journal.path))
  }

  /// The counter-case, corrected against what the platform actually does.
  ///
  /// This test previously asserted that `replaceItemAt` DROPS the exclusion,
  /// by analogy with the atomic write and the rename above. CI run
  /// 30769049772 disagreed: it was the one `BackupExclusionTests` case to
  /// fail, while `testARenameOverTheTopDropsTheExclusion` — the case the
  /// per-write re-application actually exists for — passed.
  ///
  /// The analogy was wrong, and the documentation was right about why:
  /// `replaceItemAt` is the "safe save" primitive, and without
  /// `.usingNewMetadataOnly` it deliberately carries the ORIGINAL item's
  /// metadata onto the replacement. Preserving the attribute is the whole
  /// point of the API. The rename and the atomic write make no such promise,
  /// and they are the operations `stride_storage` actually performs.
  ///
  /// So this now asserts preservation. Three things make that a real
  /// assertion rather than a test bent to fit:
  ///
  ///   * `try`, not `try?`. A `replaceItemAt` that threw would leave the
  ///     original in place and its attribute intact, which is indistinguishable
  ///     from preservation — swallowing the error would let a failed
  ///     replacement masquerade as the finding.
  ///   * the file contents are checked, so the replacement is proven to have
  ///     happened at all.
  ///   * the re-application is still exercised afterwards, and it must still
  ///     be a no-op-shaped success.
  ///
  /// Nothing about the contract loosens: re-application after every write is
  /// still required, because this is Apple's behaviour and not a guarantee
  /// this project controls, and because the operations that DO destroy the
  /// attribute are the ones the save system uses.
  func testReplaceItemAtPreservesTheExclusion() throws {
    let target = root.appendingPathComponent("save_slot_a")
    let replacement = root.appendingPathComponent("save_slot_a.new")
    FileManager.default.createFile(atPath: target.path, contents: Data([0x01]))
    FileManager.default.createFile(atPath: replacement.path, contents: Data([0x02]))
    _ = BackupExclusion.apply(paths: [target.path])
    XCTAssertTrue(isExcluded(target.path), "precondition: the target must be excluded")

    // Throws rather than swallows: see the comment above.
    _ = try FileManager.default.replaceItemAt(target, withItemAt: replacement)

    // The replacement really happened. Without this, a no-op would read as
    // "the attribute was preserved".
    let contents = try Data(contentsOf: target)
    XCTAssertEqual(
      contents, Data([0x02]),
      "the replacement's bytes must be at the target path")
    let survived = isExcluded(target.path)
    print("BACKUP EXCLUSION: replaceItemAt -> excluded == \(survived)")
    XCTAssertTrue(
      survived,
      """
      replaceItemAt is documented to carry the original item's metadata onto \
      the replacement unless .usingNewMetadataOnly is given, and on this OS it \
      does: the exclusion survives.

      If this ever fails, Apple's behaviour has changed and \
      BACKUP_EXCLUSION_CONTRACT.md section 1 must be corrected again — the \
      per-write re-application already covers it either way, which is why this \
      is a documented observation and not a load-bearing dependency.
      """)

    // Re-application after it is still correct and still cheap.
    XCTAssertTrue(BackupExclusion.apply(paths: [target.path]).failed.isEmpty)
    XCTAssertTrue(isExcluded(target.path))
  }

  func testAFileCreatedAfterTheSweepIsNotExcludedUntilReapplied() {
    // Every file in the layout is created at some point after launch: the
    // snapshot slots on the first commit, the transaction lock on the first
    // transaction, the sidecar during a compaction. The launch sweep reports
    // each of them `missing`, correctly, and covers none of them.
    let report = BackupExclusion.apply(
      directoryPath: root.path,
      filePaths: [root.appendingPathComponent("save_slot_a").path])
    XCTAssertEqual(report.missing.count, 1)

    let path = create(["save_slot_a"])[0]
    XCTAssertFalse(isExcluded(path), "a file born after the sweep carries nothing")

    XCTAssertTrue(BackupExclusion.apply(paths: [path]).failed.isEmpty)
    XCTAssertTrue(isExcluded(path))
  }

  func testTruncatingInPlaceKeepsTheExclusion() {
    // The counter-case, so the contract is precise rather than superstitious.
    // `writeVerified` opens FileMode.write, which truncates the existing inode
    // instead of replacing it, so the attribute survives. Re-applying is still
    // required after it — the file may not have existed beforehand — but this
    // pins which operations do and do not destroy the attribute, so the
    // contract is not defended by folklore.
    let path = create(["save_slot_a"])[0]
    _ = BackupExclusion.apply(paths: [path])

    // The pre-13.4 spellings deliberately: this package deploys to iOS 13.0,
    // and the throwing `truncate(atOffset:)`/`write(contentsOf:)` pair is
    // 13.4+.
    let handle = FileHandle(forWritingAtPath: path)
    handle?.truncateFile(atOffset: 0)
    handle?.write(Data([0x09, 0x09]))
    handle?.closeFile()

    XCTAssertTrue(
      isExcluded(path),
      "an in-place truncate keeps the inode, so it keeps the resource value")
  }

  // MARK: - 2c. The per-write entry point

  func testApplyPathsCoversExactlyTheListItWasGiven() {
    let paths = create(["save_slot_a", "save_slot_b"])

    let report = BackupExclusion.apply(paths: [paths[0]])

    XCTAssertEqual(report.excluded, [paths[0]])
    XCTAssertTrue(isExcluded(paths[0]))
    // No directory, and nothing else swept in. The per-write call is on the
    // commit path and must stay proportional to the operation.
    XCTAssertFalse(isExcluded(paths[1]))
    XCTAssertFalse(isExcluded(root.path))
  }

  func testApplyPathsReportsAMissingPathRatherThanFailing() {
    let report = BackupExclusion.apply(
      paths: [root.appendingPathComponent("never_written").path])

    XCTAssertEqual(report.missing.count, 1)
    XCTAssertTrue(
      report.failed.isEmpty,
      "a write that was rolled back leaves a path with no file, and that is not "
        + "a fault the commit path should shout about")
  }

  func testApplyPathsIsIdempotent() {
    let paths = create(["save_slot_a"])

    _ = BackupExclusion.apply(paths: paths)
    let second = BackupExclusion.apply(paths: paths)

    XCTAssertTrue(second.failed.isEmpty)
    XCTAssertEqual(second.excluded, paths)
  }

  func testTheLaunchSweepAndThePerWriteCallAreTheSameCode() {
    // `apply(directoryPath:filePaths:)` delegates to `apply(paths:)`. Asserted
    // because the tempting optimisation is a second, cheaper implementation for
    // the hot path that skips the read-back — which would report success for
    // precisely the replaced-node case it exists to catch.
    let paths = create(["save_slot_a"])

    let sweep = BackupExclusion.apply(directoryPath: root.path, filePaths: paths)

    XCTAssertEqual(sweep.excluded, [root.path] + paths)
  }

  // MARK: - 3. Inspection

  func testInspectSeparatesExcludedFromNotExcluded() {
    let paths = create(["save_slot_a", "save_slot_b"])
    _ = BackupExclusion.exclude(path: paths[0])

    let result = BackupExclusion.inspect(
      paths: paths + [root.appendingPathComponent("nothing_here").path])

    XCTAssertEqual(result.excluded, [paths[0]])
    XCTAssertEqual(result.notExcluded, [paths[1]])
    XCTAssertEqual(result.missing.count, 1)
  }
}

/// The Pigeon adapter's mapping rules, over a fake backend.
///
/// No Keychain here on purpose: these assert the translation, which is where a
/// three-state read outcome quietly becomes two.
final class SecureStoreAdapterTests: XCTestCase {

  private struct FakeBackend: SecureIdentityBackend {
    var readOutcome: SecureReadOutcome = .absent
    var writeOutcome: SecureWriteOutcome = .created
    var accessibility: String? = "cku"

    func read() -> SecureReadOutcome { readOutcome }
    func create(_ record: SecureIdentityRecord) -> SecureWriteOutcome { writeOutcome }
    func delete() -> Bool { true }
    func storedAccessibility() -> String? { accessibility }
  }

  private func read(_ adapter: SecureStoreAdapter) -> PlatformSecureReadResult {
    var captured: PlatformSecureReadResult!
    adapter.readIdentity { captured = try? $0.get() }
    return captured
  }

  func testFoundCarriesTheRecord() {
    let salt = Data([0x01, 0x02, 0x03])
    let adapter = SecureStoreAdapter(
      backend: FakeBackend(
        readOutcome: .found(SecureIdentityRecord(saveId: "a", salt: salt))))

    let result = read(adapter)

    XCTAssertEqual(result.status, .found)
    XCTAssertEqual(result.record?.saveId, "a")
    XCTAssertEqual(result.record?.salt.data, salt)
  }

  func testUnavailableIsNotFoldedIntoAbsent() {
    // The single most important mapping in the plugin. -25308 is
    // errSecInteractionNotAllowed, which is what a read gets before the first
    // unlock since boot. Reported as absence, it tells the bootstrap that a
    // device with a live save is a new installation.
    let adapter = SecureStoreAdapter(
      backend: FakeBackend(readOutcome: .unavailable(-25308)))

    let result = read(adapter)

    XCTAssertEqual(result.status, .unavailable)
    XCTAssertNotEqual(result.status, .absent)
    XCTAssertNil(result.record)
    XCTAssertEqual(result.osStatus, -25308)
  }

  func testAbsentCarriesNoStatusCode() {
    let result = read(SecureStoreAdapter(backend: FakeBackend(readOutcome: .absent)))

    XCTAssertEqual(result.status, .absent)
    // Absence is a normal state, not an error condition, and an OSStatus here
    // would invite a caller to treat it as one.
    XCTAssertNil(result.osStatus)
  }

  func testAlreadyExistsIsReportedRatherThanSucceeding() {
    let adapter = SecureStoreAdapter(
      backend: FakeBackend(writeOutcome: .alreadyExists))

    var captured: PlatformSecureWriteStatus?
    adapter.createIdentity(
      record: PlatformIdentityRecord(
        saveId: "a", salt: FlutterStandardTypedData(bytes: Data([0x01])))
    ) { captured = try? $0.get() }

    // Success here would let the caller carry on believing it had written its
    // own key over someone else's.
    XCTAssertEqual(captured, .alreadyExists)
  }

  func testThereAreExactlyThreeReadStatuses() {
    // Collapsing three into two is the regression that matters, and a removed
    // case is not a compile error the way an added one is.
    XCTAssertEqual(PlatformSecureReadStatus.allCases.count, 3)
  }

  func testFailedCreateIsNotReportedAsSuccess() {
    let adapter = SecureStoreAdapter(
      backend: FakeBackend(writeOutcome: .failed(-25300)))

    var captured: PlatformSecureWriteStatus?
    adapter.createIdentity(
      record: PlatformIdentityRecord(
        saveId: "a", salt: FlutterStandardTypedData(bytes: Data([0x01])))
    ) { captured = try? $0.get() }

    XCTAssertEqual(captured, .failed)
  }

  func testReapplyBackupExclusionsIsCarriedThroughTheBoundary() throws {
    // The per-write call, over a real file, through the Pigeon-facing adapter.
    // The mapping is the part that could silently lose the `failed` list, which
    // is the only entry in the report that means a file would travel.
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("reapply_\(UUID().uuidString)")
    try FileManager.default.createDirectory(
      at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let present = directory.appendingPathComponent("save_slot_a")
    FileManager.default.createFile(atPath: present.path, contents: Data([0x01]))
    let absent = directory.appendingPathComponent("ledger_journal.compacting")

    var report: PlatformBackupExclusionReport?
    SecureStoreAdapter(backend: FakeBackend())
      .reapplyBackupExclusions(paths: [present.path, absent.path]) {
        report = try? $0.get()
      }

    XCTAssertEqual(report?.excluded, [present.path])
    XCTAssertEqual(report?.missing, [absent.path])
    XCTAssertEqual(report?.failed, [])

    let values = try URL(fileURLWithPath: present.path)
      .resourceValues(forKeys: [.isExcludedFromBackupKey])
    XCTAssertEqual(values.isExcludedFromBackup, true)
  }
}
