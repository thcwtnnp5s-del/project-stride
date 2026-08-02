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
import 'package:stride_secure_store/stride_secure_store.dart';
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
    required this.identityStorage,
  });

  final BootstrapOutcome outcome;
  final SaveRepository repository;
  final StorageLayout layout;

  /// The boundary a raw platform source identifier must cross before it can be
  /// reasoned about. Held here because the salt lives in the vault, and nothing
  /// else in the app is allowed to construct one.
  final OriginPseudonymizer? pseudonymizer;

  /// What re-applying the platform backup exclusion achieved this launch.
  ///
  /// Surfaced rather than swallowed. A non-empty `failed` list means a file
  /// that exists would travel in an iCloud restore — the second of the two
  /// controls failing. The first, the device-bound identity, still holds, and
  /// that is why this is reported rather than fatal.
  final BackupExclusionReport backupExclusion;

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
/// 2. Open the identity vault. This re-applies `NSURLIsExcludedFromBackupKey`
///    to the directory and every file `StorageLayout` declares — every launch,
///    because the attribute lives on the filesystem node and a recreated
///    directory loses it silently — and then *reads* the identity.
/// 3. Run the coordinator, which loads the save and only then decides whether
///    a new identity is minted.
///
/// Nothing between steps 1 and 3 writes an identity. An earlier version wrote
/// one before calling the coordinator, which made the "a save survived but its
/// identity did not" refusal unreachable from the app: the coordinator never
/// saw `stored == null`, so a save with a freshly minted identity beside it
/// resumed under the wrong lineage.
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

  final SaveRepository repository = SaveRepository(
    snapshots: FileSnapshotStore(layout),
    journal: FileLedgerJournal(layout),
    // The real OS-level lock, never the default `UncontendedLock`.
    //
    // A repository over a real directory with an uncontended lock is exactly
    // the cross-instance race `TransactionLock` exists to close, restored at
    // the one construction site a player actually runs. Health Connect
    // background delivery opens a second writer over this same directory, and
    // `UncontendedLock`'s own documentation forbids it here.
    lock: FileTransactionLock(layout.transactionLock),
  );

  // **The salt is minted once per installation and then persisted.**
  //
  // Regenerating it per launch would re-key every origin, so the save would
  // fail closed on the second start and the game would open exactly once. It is
  // never derived from a device identifier, which would make it a device
  // identifier; and its *fingerprint*, not the salt, is what reaches the save.
  //
  // On iOS it lives in the Keychain as `ThisDeviceOnly`, so it does not travel
  // in an iCloud restore and a restored device blocks with
  // `originIdentityMissing` rather than silently replaying the ledger against a
  // health source the first device already consumed from. See
  // `identity_vault.dart` for the full account of that failure.
  final IdentityVault vault = await IdentityVault.open(
    layout: layout,
    secureStore: secureStore,
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
    identityStorage: vault.storageDescription,
    // Only meaningful once startup succeeded; a blocked bootstrap has no
    // business pseudonymizing anything.
    pseudonymizer: outcome is BootstrapBlocked || salt == null
        ? null
        : OriginPseudonymizer(salt),
  );
}
