import Flutter
import Security
import UIKit
import XCTest

@testable import stride_secure_store

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
///   * that the item persists past the object that wrote it
///   * that `kSecAttrAccessible` is exactly
///     `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
///   * that the exclusion is applied and verified on real paths, including
///     paths named the way `StorageLayout` names them
///   * that the exclusion is re-applied after the directory is deleted and
///     recreated, which is the case a one-shot implementation gets wrong
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

    XCTAssertEqual(store.create(expected), .created)

    guard case .found(let actual) = store.read() else {
      return XCTFail("a created item must read back as .found")
    }
    XCTAssertEqual(actual.saveId, expected.saveId)
    // Every byte. A salt that comes back with one byte changed re-keys every
    // origin, and the live retention window is granted a second time.
    XCTAssertEqual(actual.salt, expected.salt)
  }

  func testReadWithNothingStoredIsAbsentNotAnError() {
    // Absence is a normal state — it is what a genuinely new installation looks
    // like — and it must be distinguishable from a store that could not answer.
    guard case .absent = store.read() else {
      return XCTFail("an empty keychain must report .absent")
    }
  }

  func testItemSurvivesANewStoreInstance() {
    XCTAssertEqual(store.create(record()), .created)

    // A different object, reading the same platform store. This proves the
    // record is not in-process state.
    //
    // It is NOT a relaunch: XCTest runs one host process, and a true
    // cold-launch read after a device reboot needs a physical device. See the
    // class comment.
    let second = KeychainIdentityStore()
    guard case .found(let actual) = second.read() else {
      return XCTFail("the item must outlive the object that wrote it")
    }
    XCTAssertEqual(actual.saveId, "lineage-one")
  }

  // MARK: - 2. Add-only — the rule the whole design rests on

  func testSecondCreateDoesNotOverwriteTheFirst() {
    XCTAssertEqual(store.create(record("first")), .created)

    let outcome = store.create(record("second"))

    XCTAssertEqual(
      outcome, .alreadyExists,
      "a second create must be reported, never applied"
    )

    guard case .found(let actual) = store.read() else {
      return XCTFail("the original must still be there")
    }
    XCTAssertEqual(
      actual.saveId, "first",
      "overwriting a live identity orphans the save it belongs to"
    )
  }

  func testDeleteRemovesTheItem() {
    XCTAssertEqual(store.create(record()), .created)
    XCTAssertTrue(store.delete())

    guard case .absent = store.read() else {
      return XCTFail("a deleted item must read back as .absent")
    }
  }

  // MARK: - 3. Accessibility — ThisDeviceOnly is the entire control

  func testStoredItemIsAfterFirstUnlockThisDeviceOnly() {
    XCTAssertEqual(store.create(record()), .created)

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
    XCTAssertEqual(store.create(record()), .created)

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
      "no synchronizable copy of the identity may exist")

    query[kSecAttrSynchronizable as String] = false
    XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &item), errSecSuccess)
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
}
