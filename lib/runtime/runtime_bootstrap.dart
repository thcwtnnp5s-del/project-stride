/// Wires the pure bootstrap coordinator to real Flutter storage.
///
/// Everything decision-shaped lives in `stride_core`'s `BootstrapCoordinator`,
/// which is pure and exhaustively tested. This file supplies only the three
/// things the core cannot have: an asset bundle, a filesystem path, and a
/// source of randomness for minting an identity.
///
/// That split is the point. Startup logic that lived here would be reachable
/// only by a Flutter integration test on a device or emulator; the same logic
/// behind ports runs under `dart test` in milliseconds, including every
/// refusal path.
library;

import 'dart:convert';
import 'dart:io' show Directory;
import 'dart:math';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';
import 'package:stride_storage/stride_storage.dart';

import 'asset_content.dart';

/// Everything a running game needs, once startup has succeeded.
final class StrideRuntime {
  const StrideRuntime({
    required this.outcome,
    required this.repository,
    required this.layout,
    required this.pseudonymizer,
  });

  final BootstrapOutcome outcome;
  final SaveRepository repository;
  final StorageLayout layout;

  /// The boundary a raw platform source identifier must cross before it can be
  /// reasoned about. Held here because the salt lives beside the save, and
  /// nothing else in the app is allowed to construct one.
  final OriginPseudonymizer? pseudonymizer;
}

/// Opens storage under application support and runs startup.
///
/// **Application support, never documents and never external storage.** On
/// Android that is app-private and removed with the app's data; on iOS it is
/// not exposed to Files. A documents directory would put a step ledger
/// somewhere a file manager can browse.
Future<StrideRuntime> bootstrapStride({
  Directory? overrideRoot,
  bool treatAsRelease = false,
  Random? random,
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
  );
  final FileIdentityStore identityStore = FileIdentityStore(layout);

  final BootstrapCoordinator coordinator = BootstrapCoordinator(
    repository: repository,
    identityStore: identityStore,
    // Production always. The QA profile is selected only by an explicit
    // developer configuration, never by a build flag defaulting one way.
    profileId: BalanceProfile.productionId,
    treatAsRelease: treatAsRelease,
  );

  // **The salt is minted once per installation and then persisted.**
  //
  // Regenerating it per launch would re-key every origin, so the save would
  // fail closed on the second start and the game would open exactly once. It
  // is never derived from a device identifier, which would make it a device
  // identifier; and its *fingerprint*, not the salt, is what reaches the save.
  final Random entropy = random ?? Random.secure();
  StoredIdentity? stored = await identityStore.readStored();

  if (stored == null) {
    stored = StoredIdentity(
      saveId: base64Url.encode(
        List<int>.generate(12, (_) => entropy.nextInt(256)),
      ),
      salt: Uint8List.fromList(
        List<int>.generate(16, (_) => entropy.nextInt(256)),
      ),
    );
    // Written before startup runs, so a crash between minting and the first
    // commit leaves an identity with no save — which the coordinator treats as
    // a new game and reuses, rather than minting a second one that would orphan
    // any save that did exist.
    await identityStore.writeStored(stored);
  }

  final BootstrapOutcome outcome = await coordinator.run(
    loadContent: loadContentFromAssets,
    // Already written above, so this is only ever the value the coordinator
    // reads back. It cannot mint a *different* identity than the one the
    // pseudonymizer below is built from.
    mintIdentity: () => stored!.public,
  );

  return StrideRuntime(
    outcome: outcome,
    repository: repository,
    layout: layout,
    // Only meaningful once startup succeeded; a blocked bootstrap has no
    // business pseudonymizing anything.
    pseudonymizer: outcome is BootstrapBlocked
        ? null
        : OriginPseudonymizer(stored.salt),
  );
}
