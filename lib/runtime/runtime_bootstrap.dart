/// Wires the pure bootstrap coordinator to real Flutter storage.
///
/// Everything decision-shaped lives in `stride_core`'s `BootstrapCoordinator`,
/// which is pure and exhaustively tested. This file supplies only the things
/// the core cannot have: an asset bundle, a filesystem path, a source of
/// randomness, and a platform-specific place to keep the identity.
///
/// That split is the point. Startup logic that lived here would be reachable
/// only by a Flutter integration test on a device or emulator; the same logic
/// behind ports runs under `dart test` in milliseconds, including every
/// refusal path.
library;

import 'dart:io' show Directory;
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';
// Both packages declare a `ReapplyBackupExclusion`, deliberately: the binding
// between them is structural, because `stride_storage` must not depend on
// Flutter and so cannot import this one. The two are the same shape; the
// storage-side name is the one the store constructors are declared against, so
// that is the one kept in scope here.
import 'package:stride_secure_store/stride_secure_store.dart'
    hide ReapplyBackupExclusion;
import 'package:stride_storage/stride_storage.dart';

import 'asset_content.dart';
import 'identity_vault.dart';

/// Everything a running game needs, once startup has succeeded.
final class StrideRuntime {
  const StrideRuntime({
    required this.outcome,
    required this.repository,
    required this.layout,
    required this.pseudonymizer,
    required this.backupExclusion,
    required this.perWriteExclusionFailures,
    required this.identityStorage,
  });

  final BootstrapOutcome outcome;
  final SaveRepository repository;
  final StorageLayout layout;

  /// The boundary a raw platform source identifier must cross before it can be
  /// reasoned about. Held here because the salt lives in the vault, and nothing
  /// else in the app is allowed to construct one.
  final OriginPseudonymizer? pseudonymizer;

  /// What the **launch sweep** achieved: the directory and every file that
  /// already existed when the app started.
  ///
  /// Surfaced rather than swallowed. A non-empty `failed` list means a file
  /// that exists would travel in an iCloud restore — the second of the two
  /// controls failing. The first, the device-bound identity, still holds, and
  /// that is why this is reported rather than fatal.
  final BackupExclusionReport backupExclusion;

  /// Paths the **per-write** re-application could not exclude, accumulated for
  /// the life of this runtime.
  ///
  /// Live rather than a snapshot: the stores append to it on every commit and
  /// compaction, so a reader sees everything that has failed so far. Kept
  /// distinct from [backupExclusion] because a file can pass at launch and then
  /// fail after a rename replaces its node — collapsing the two would hide
  /// exactly that case, which is the one that regressed.
  final List<String> perWriteExclusionFailures;

  /// `keychain` on iOS, `app-private file` elsewhere. Diagnostics only.
  final String identityStorage;
}

/// Opens storage under application support and runs startup.
///
/// **Application support, never documents and never external storage.** On
/// Android that is app-private and removed with the app's data; on iOS it is
/// not exposed to Files. A documents directory would put a step ledger
/// somewhere a file manager can browse.
///
/// ## The order, and why it is this order
///
/// 1. Open the storage directory.
/// 2. Resolve the secure store, and build the repository with its per-write
///    backup-exclusion hook. Constructing a repository performs no I/O, so this
///    can precede the vault without weakening the rule below.
/// 3. Open the identity vault. This applies `NSURLIsExcludedFromBackupKey` to
///    the directory and every file `StorageLayout` declares **that exists at
///    launch**, and then *reads* the identity.
/// 4. Run the coordinator, which loads the save and only then decides whether
///    a new identity is minted.
///
/// Nothing between steps 1 and 4 writes an identity. An earlier version wrote
/// one before calling the coordinator, which made the "a save survived but its
/// identity did not" refusal unreachable from the app: the coordinator never
/// saw `stored == null`, so a save with a freshly minted identity beside it
/// resumed under the wrong lineage.
///
/// The coordinator does write, and may delete, an identity in step 4 — see
/// `bootstrap.dart`'s rule 5. An identity the load has proven has no save and
/// no journal beside it is an orphan, and is replaced rather than reused. That
/// is the only deletion any launch performs, and it is the coordinator's
/// decision rather than this file's, which is the whole point of the split.
///
/// ## The exclusion is two controls, not one
///
/// The launch sweep in step 3 covers what is already on disk. It cannot cover
/// what does not exist yet — the snapshot slots, the journal and the lock file
/// are all created *after* it runs — and it does not survive replacement:
/// `NSURLIsExcludedFromBackupKey` is a property of the filesystem node, and a
/// rename over the top gives the path a different node. `replaceLines` renames a
/// sidecar over the journal on every compaction, so a launch-only sweep leaves
/// the journal **losing** an exclusion it previously had. That one is a
/// regression rather than a gap.
///
/// So the stores also carry a per-write hook, injected here because
/// `stride_storage` must not depend on Flutter. Between them: the sweep covers
/// what exists at launch, the hook covers everything created or replaced
/// afterwards. See `packages/stride_secure_store/BACKUP_EXCLUSION_CONTRACT.md`.
Future<StrideRuntime> bootstrapStride({
  Directory? overrideRoot,
  bool treatAsRelease = false,
  Random? random,
  SecureIdentityStore? secureStore,
}) async {
  final Directory support =
      overrideRoot ?? await getApplicationSupportDirectory();
  final StorageLayout layout = StorageLayout(
    Directory('${support.path}/${StorageLayout.directoryName}'),
  );
  await layout.ensureExists();

  // Resolved here rather than inside `IdentityVault.open`, because the
  // repository needs the same instance for its per-write exclusion hook.
  final SecureIdentityStore secure = secureStore ?? KeychainIdentityStore();

  // Collected rather than thrown. A file that could not be excluded is the one
  // condition meaning the ledger would travel in a restore, so it must reach a
  // diagnostic — but the Keychain identity is the first control and does not
  // depend on this succeeding, so it must not block a commit or startup.
  final List<String> exclusionFailures = <String>[];
  ReapplyBackupExclusion? hook() => secure.backupExclusionHook(
    onReport: (BackupExclusionReport r) => exclusionFailures.addAll(r.failed),
  );

  final SaveRepository repository = SaveRepository(
    snapshots: FileSnapshotStore(layout, reapplyExclusion: hook()),
    journal: FileLedgerJournal(layout, reapplyExclusion: hook()),
    // The real OS-level lock, never the default `UncontendedLock`.
    //
    // A repository over a real directory with an uncontended lock is exactly
    // the cross-instance race `TransactionLock` exists to close, restored at
    // the one construction site a player actually runs. Health Connect
    // background delivery opens a second writer over this same directory, and
    // `UncontendedLock`'s own documentation forbids it here.
    //
    // The OS lock is one of three layers, not the whole answer: it is
    // process-level on POSIX and does not exclude a second isolate in this
    // process. See `TECHNICAL/PERSISTENCE_CONCURRENCY.md`.
    lock: FileTransactionLock(layout.transactionLock, reapplyExclusion: hook()),
  );

  // **The salt is minted once per installation and then persisted.**
  //
  // Regenerating it per launch would re-key every origin, so the save would
  // fail closed on the second start and the game would open exactly once. It is
  // never derived from a device identifier, which would make it a device
  // identifier; and its *fingerprint*, not the salt, is what reaches the save.
  //
  // On iOS it lives in the Keychain as `ThisDeviceOnly`, which Apple documents
  // as excluded from backup and not restored onto a second device — so a
  // restored device blocks with `originIdentityMissing` rather than silently
  // replaying the ledger against a health source the first device already
  // consumed from. That Apple behaviour is relied upon and verified nowhere in
  // this repository. See `identity_vault.dart` for the full account.
  final IdentityVault vault = await IdentityVault.open(
    layout: layout,
    // The resolved instance, not the nullable parameter. Two instances would
    // be two plugin channels reporting into two different places.
    secureStore: secure,
    entropy: random,
  );

  final BootstrapCoordinator coordinator = BootstrapCoordinator(
    repository: repository,
    identityStore: vault,
    // Production always. The QA profile is selected only by an explicit
    // developer configuration, never by a build flag defaulting one way.
    profileId: BalanceProfile.productionId,
    treatAsRelease: treatAsRelease,
  );

  final BootstrapOutcome outcome = await coordinator.run(
    loadContent: loadContentFromAssets,
    // In memory only. The coordinator calls this after looking for a save, and
    // persists it through `vault.write` on the new-game path alone.
    mintIdentity: vault.mintCandidate,
  );

  final Uint8List? salt = vault.salt;

  return StrideRuntime(
    outcome: outcome,
    repository: repository,
    layout: layout,
    backupExclusion: vault.backupExclusion,
    perWriteExclusionFailures: exclusionFailures,
    identityStorage: vault.storageDescription,
    // Only meaningful once startup succeeded; a blocked bootstrap has no
    // business pseudonymizing anything.
    pseudonymizer: outcome is BootstrapBlocked || salt == null
        ? null
        : OriginPseudonymizer(salt),
  );
}
