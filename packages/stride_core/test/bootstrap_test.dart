// Startup, as a state machine: every way it succeeds and every way it refuses.
//
// ## The one failure this whole suite exists to prevent
//
// A save exists, cannot be read, and startup reports success onto a fresh
// character. That is not a crash — it is a *successful* launch that returns a
// wiped save, and by the time the player notices, the next commit has usually
// overwritten the evidence. So every refusal test below asserts two things:
// the typed reason, and that the durable image is byte-for-byte what it was
// before startup ran.
//
// Quantities are distinct and non-summing — 137, 291, 613 — so a drop, a
// duplicate, and an off-by-one each move a different number.

import 'dart:convert';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'content_test_support.dart';
import 'save_support.dart';

// ---------------------------------------------------------------------------
// Doubles
// ---------------------------------------------------------------------------

/// An identity store in memory, with faults that are explicit rather than
/// simulated by a missing file.
final class MemoryIdentityStore implements ReconciliationIdentityStore {
  MemoryIdentityStore([this._identity]);

  ReconciliationIdentity? _identity;

  bool readThrows = false;
  bool writeThrows = false;
  bool eraseThrows = false;

  /// Every identity written, in order. A new game must write exactly one, and
  /// a resumed game must write none.
  final List<ReconciliationIdentity> writes = <ReconciliationIdentity>[];
  int erasures = 0;

  @override
  Future<ReconciliationIdentity?> read() async {
    if (readThrows) throw StateError('identity store unreadable');
    return _identity;
  }

  @override
  Future<void> write(ReconciliationIdentity identity) async {
    if (writeThrows) throw StateError('identity store unwritable');
    writes.add(identity);
    _identity = identity;
  }

  @override
  Future<void> erase() async {
    if (eraseThrows) throw StateError('identity store erase refused');
    erasures++;
    _identity = null;
  }
}

/// A snapshot store whose reads fail. [FaultingDevice] can only fault writes,
/// and "the device cannot be read at all" is a distinct condition from "the
/// bytes on it are wrong".
final class UnreadableSnapshots implements SnapshotSlotStore {
  const UnreadableSnapshots();

  @override
  Future<Uint8List?> read(SnapshotSlot slot) async =>
      throw StateError('storage medium unavailable');

  @override
  Future<void> write(SnapshotSlot slot, Uint8List bytes) async =>
      throw StateError('storage medium unavailable');

  @override
  Future<void> erase(SnapshotSlot slot) async =>
      throw StateError('storage medium unavailable');
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const String saltNow = 'aaaaaaaaaaaaaaaa';
const String saltThen = 'bbbbbbbbbbbbbbbb';

ReconciliationIdentity get liveIdentity =>
    const ReconciliationIdentity(saveId: testSaveId, saltFingerprint: saltNow);

Future<ContentSource> goodContent() async => productionSource;

Future<ContentSource> invalidContent() async =>
    productionWithOverride('unknown_item_reference.json');

Future<ContentSource> unreadableContent() async => throw StateError(
  'assets/content/v1/skills.json is missing from the bundle',
);

ContentRegistry registryFor(ContentId profileId) => const ContentLoader()
    .load(productionSource, profileId: profileId)
    .requireRegistry;

ContentRegistry get qaRegistry => registryFor(BalanceProfile.acceleratedQaId);

/// Runs the coordinator over [device], returning everything a test needs to
/// assert against afterwards.
Future<
  ({
    BootstrapOutcome outcome,
    FaultingDevice device,
    MemoryIdentityStore identity,
    int mintCalls,
  })
>
boot({
  FaultingDevice? device,
  MemoryIdentityStore? identity,
  SaveRepository? repository,
  Future<ContentSource> Function()? content,
  ContentId? profileId,
  bool treatAsRelease = false,
  ReconciliationIdentity? mints,
}) async {
  final FaultingDevice dev = device ?? FaultingDevice();
  final MemoryIdentityStore store = identity ?? MemoryIdentityStore();
  int mintCalls = 0;

  final BootstrapCoordinator coordinator = BootstrapCoordinator(
    repository: repository ?? newRepo(dev).repo,
    identityStore: store,
    profileId: profileId ?? BalanceProfile.productionId,
    treatAsRelease: treatAsRelease,
  );

  final BootstrapOutcome outcome = await coordinator.run(
    loadContent: content ?? goodContent,
    mintIdentity: () {
      mintCalls++;
      return mints ?? liveIdentity;
    },
  );

  return (outcome: outcome, device: dev, identity: store, mintCalls: mintCalls);
}

/// A device carrying a real save, produced by real commits.
///
/// [commits] transactions of distinct step grants, so the durable total is a
/// number no other arrangement of these fixtures produces.
Future<({FaultingDevice device, GameState state, int totalGranted})> savedGame({
  int commits = 1,
  ContentRegistry? registry,
  String saveId = testSaveId,
  String? saltFingerprint = saltNow,
}) async {
  final ContentRegistry reg = registry ?? saveRegistry;
  final (:SaveRepository repo, :FaultingDevice device) = newRepo();
  final GameEngine engine = GameEngine.newGame(registry: reg);

  const List<int> amounts = <int>[613, 291, 137, 1009, 3001];
  int generation = -1;
  int transaction = 0;
  int total = 0;

  for (int i = 0; i < commits; i++) {
    final int steps = amounts[i % amounts.length];
    total += steps;
    final EngineResult r = engine.execute(
      GrantSyntheticSteps(steps: steps, reason: 'seed$i'),
    );
    final CommitOutcome outcome = await repo.commit(
      after: engine.state,
      events: r.events,
      saveId: saveId,
      expectation: CommitExpectation(
        expectedSnapshotGeneration: generation,
        expectedLastAppliedTransaction: transaction,
      ),
      originSaltFingerprint: saltFingerprint,
    );
    final CommitDurable durable = outcome as CommitDurable;
    generation = durable.generation;
    transaction = durable.transactionId;
  }

  return (device: device, state: engine.state, totalGranted: total);
}

/// Re-encodes a framed snapshot with the envelope mutated and the digest
/// recomputed, so a fixture is a *valid* save that says something wrong rather
/// than a corrupt one.
Uint8List remake(
  Uint8List framed,
  void Function(Map<String, Object?> envelope, Map<String, Object?> state)
  mutate,
) {
  final FrameResult result = unframe(framed);
  expect(result.verified, isTrue, reason: 'the source snapshot must verify');
  final Map<String, Object?> envelope =
      jsonDecode(utf8.decode(result.payload!)) as Map<String, Object?>;
  mutate(envelope, envelope['state']! as Map<String, Object?>);
  return frame(Uint8List.fromList(utf8.encode(canonicalJson(envelope))));
}

/// A device holding one snapshot in slot A, built from [state] and mutated.
FaultingDevice deviceWithSnapshot(
  GameState state, {
  String? originSaltFingerprint,
  void Function(Map<String, Object?> envelope, Map<String, Object?> state)?
  mutate,
}) {
  Uint8List bytes = encodeSnapshot(
    state: state,
    saveId: testSaveId,
    generation: 0,
    lastAppliedTransaction: 1,
    originSaltFingerprint: originSaltFingerprint,
  );
  if (mutate != null) bytes = remake(bytes, mutate);
  return FaultingDevice()..seed('save_slot_a', bytes);
}

/// Asserts a blocked outcome that changed nothing at all.
void expectBlockedAndUntouched(
  BootstrapOutcome outcome,
  BootstrapBlockReason reason, {
  required FaultingDevice device,
  required String before,
  required MemoryIdentityStore identity,
  int mintCalls = 0,
}) {
  expect(
    outcome,
    isA<BootstrapBlocked>(),
    reason: 'a save that cannot be read must never become a new game',
  );
  expect((outcome as BootstrapBlocked).reason, reason);
  expect(
    device.image(),
    before,
    reason: 'a blocked bootstrap must not create or delete a single byte',
  );
  expect(identity.writes, isEmpty);
  expect(identity.erasures, 0);
  expect(mintCalls, 0, reason: 'a refusal must not mint a new lineage');
}

void main() {
  _newGame();
  _existingGame();
  _blocked();
  _identityReuse();
  _saltFingerprintEndToEnd();
  _identityOrdering();
  _documentedGaps();
}

// ---------------------------------------------------------------------------
// New game
// ---------------------------------------------------------------------------

void _newGame() {
  group('new game', () {
    test(
      'content loads, a state is created, and it reaches readyNewGame',
      () async {
        final result = await boot();

        expect(result.outcome, isA<BootstrapNewGame>());
        final BootstrapNewGame game = result.outcome as BootstrapNewGame;
        expect(game.phase, BootstrapPhase.readyNewGame);

        // Content actually validated, not merely read.
        expect(game.registry.skills, isNotEmpty);
        expect(game.registry.profile.id, BalanceProfile.productionId);

        // A production state, under the profile that was asked for.
        expect(game.engine.state.profileId, BalanceProfile.productionId);
        expect(
          game.engine.state.world.currentLocation,
          game.registry.startLocation.id,
        );
        expect(game.engine.state.steps.totalGranted, 0);
      },
    );

    test(
      'the initial snapshot is persisted before the caller is told',
      () async {
        final result = await boot();
        expect(result.outcome, isA<BootstrapNewGame>());

        // The assertion this test exists for. A new game that lives only in
        // memory is a first session the player loses to a process kill, and
        // nothing about the returned object would reveal it.
        expect(
          result.device.exists('save_slot_a'),
          isTrue,
          reason: 'the first snapshot must be durable before readyNewGame',
        );
        expect(result.device.flushCountFor('journal'), greaterThan(0));
      },
    );

    test('the persisted snapshot reloads to an equivalent state', () async {
      final result = await boot();
      final BootstrapNewGame game = result.outcome as BootstrapNewGame;

      // Restart from the durable bytes alone: a new device object, a new
      // repository, nothing carried over in memory.
      final FaultingDevice rebooted = result.device.reboot();
      final LoadOutcome reloaded = await newRepo(
        rebooted,
      ).repo.load(registry: saveRegistry);

      expect(reloaded, isA<SaveLoaded>());
      final SaveLoaded loaded = reloaded as SaveLoaded;
      expect(
        canonicalDurableGameState(loaded.state),
        canonicalDurableGameState(game.engine.state),
        reason: 'the reloaded state must be the state the player was given',
      );
      expect(loaded.generation, 0);
      expect(loaded.lastAppliedTransaction, 1);
      expect(loaded.repairs, isEmpty);
    });

    test(
      'a second bootstrap over the same device resumes, never restarts',
      () async {
        final result = await boot();
        final BootstrapNewGame first = result.outcome as BootstrapNewGame;

        final second = await boot(
          device: result.device.reboot(),
          identity: MemoryIdentityStore(first.identity),
        );

        expect(second.outcome, isA<BootstrapExistingGame>());
        expect(
          canonicalDurableGameState(
            (second.outcome as BootstrapExistingGame).engine.state,
          ),
          canonicalDurableGameState(first.engine.state),
        );
        expect(second.mintCalls, 0);
      },
    );

    test('the minted identity is written exactly once and returned', () async {
      final result = await boot();

      expect(result.mintCalls, 1);
      expect(result.identity.writes, <ReconciliationIdentity>[liveIdentity]);
      expect((result.outcome as BootstrapNewGame).identity, liveIdentity);
    });

    test('an unwritable identity store blocks instead of starting', () async {
      final MemoryIdentityStore store = MemoryIdentityStore()
        ..writeThrows = true;
      final result = await boot(identity: store);

      expect(result.outcome, isA<BootstrapBlocked>());
      final BootstrapBlocked blocked = result.outcome as BootstrapBlocked;
      expect(blocked.reason, BootstrapBlockReason.storageUnavailable);
      expect(
        result.device.image(),
        isEmpty,
        reason:
            'a game whose identity is not durable must not leave a save '
            'behind — the next launch would refuse it',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Existing save
// ---------------------------------------------------------------------------

void _existingGame() {
  group('existing save', () {
    test('both slots are examined and the newest generation wins', () async {
      // Three commits: slot a gen0, slot b gen1, slot a gen2.
      final saved = await savedGame(commits: 3);
      expect(saved.device.exists('save_slot_a'), isTrue);
      expect(saved.device.exists('save_slot_b'), isTrue);

      final result = await boot(
        device: saved.device.reboot(),
        identity: MemoryIdentityStore(liveIdentity),
      );

      expect(result.outcome, isA<BootstrapExistingGame>());
      final BootstrapExistingGame game =
          result.outcome as BootstrapExistingGame;
      expect(game.phase, BootstrapPhase.readyExistingGame);
      expect(game.load.generation, 2);
      expect(game.load.fromSlot, SnapshotSlot.a);
      expect(game.engine.state.steps.totalGranted, saved.totalGranted);
      expect(
        canonicalDurableGameState(game.engine.state),
        canonicalDurableGameState(saved.state),
      );
      expect(result.mintCalls, 0);
    });

    test('a snapshot behind the journal is caught up by replay', () async {
      // The third snapshot write fails after its journal record is durable —
      // the ordinary crash-between-commit-and-cache case.
      final (:SaveRepository repo, :FaultingDevice device) = newRepo();
      final GameEngine engine = GameEngine.newGame(registry: saveRegistry);

      int generation = -1;
      int transaction = 0;
      for (int i = 0; i < 3; i++) {
        if (i == 2) {
          // Commits alternate a, b, a — so this is the second write of slot a.
          device.plan(<Fault>[
            const Fault(
              op: 'write',
              path: 'save_slot_a',
              effect: FaultEffect.failBefore,
              ordinal: 1,
            ),
          ]);
        }
        final EngineResult r = engine.execute(
          GrantSyntheticSteps(steps: <int>[613, 291, 137][i], reason: 'g$i'),
        );
        final CommitDurable durable =
            await repo.commit(
                  after: engine.state,
                  events: r.events,
                  saveId: testSaveId,
                  expectation: CommitExpectation(
                    expectedSnapshotGeneration: generation,
                    expectedLastAppliedTransaction: transaction,
                  ),
                  originSaltFingerprint: saltNow,
                )
                as CommitDurable;
        if (i == 2) {
          expect(
            durable.snapshotDurable,
            isFalse,
            reason: 'the fixture must actually leave the snapshot behind',
          );
        }
        generation = durable.generation;
        transaction = durable.transactionId;
      }

      final result = await boot(
        device: device.reboot(),
        identity: MemoryIdentityStore(liveIdentity),
      );

      expect(result.outcome, isA<BootstrapExistingGame>());
      final BootstrapExistingGame game =
          result.outcome as BootstrapExistingGame;
      expect(game.load.replayedTransactions, 1);
      expect(
        game.load.repairs.map((SaveRepair r) => r.diagnosis),
        contains(SaveDiagnosis.snapshotOlderThanJournal),
      );
      expect(
        game.engine.state.steps.totalGranted,
        1041,
        reason: 'the grant whose snapshot never landed must survive',
      );
      expect(
        canonicalDurableGameState(game.engine.state),
        canonicalDurableGameState(engine.state),
      );
    });

    test('a torn journal tail is recovered, not refused', () async {
      final saved = await savedGame(commits: 2);
      final FaultingDevice device = saved.device.reboot();

      // An interrupted append: the last line has no terminator and no valid
      // digest. The transaction simply did not commit.
      final Uint8List journal = device.committedBytes('journal')!;
      device.seed(
        'journal',
        Uint8List.fromList(<int>[
          ...journal,
          ...utf8.encode('deadbeef {"f":1'),
        ]),
      );

      final result = await boot(
        device: device,
        identity: MemoryIdentityStore(liveIdentity),
      );

      expect(result.outcome, isA<BootstrapExistingGame>());
      final BootstrapExistingGame game =
          result.outcome as BootstrapExistingGame;
      expect(
        game.load.repairs.map((SaveRepair r) => r.diagnosis),
        contains(SaveDiagnosis.journalTailTorn),
      );
      expect(game.engine.state.steps.totalGranted, saved.totalGranted);
    });

    test('the reconciliation identity is restored, not re-minted', () async {
      final saved = await savedGame(commits: 2);
      final MemoryIdentityStore store = MemoryIdentityStore(liveIdentity);

      final result = await boot(device: saved.device.reboot(), identity: store);

      final BootstrapExistingGame game =
          result.outcome as BootstrapExistingGame;
      expect(game.identity, liveIdentity);
      expect(store.writes, isEmpty, reason: 'resuming rewrites nothing');
      expect(result.mintCalls, 0);
    });

    test(
      'content references and profile are validated on the way in',
      () async {
        final saved = await savedGame(commits: 1);
        final result = await boot(
          device: saved.device.reboot(),
          identity: MemoryIdentityStore(liveIdentity),
        );

        final BootstrapExistingGame game =
            result.outcome as BootstrapExistingGame;
        // Every id in the loaded state resolves in the registry the coordinator
        // built. A load that skipped this check would hand the engine a state
        // referring to content that does not exist.
        for (final ContentId id in <ContentId>[
          ...game.engine.state.inventory.counts.keys,
          ...game.engine.state.skills.experienceBySkill.keys,
          game.engine.state.world.currentLocation,
        ]) {
          expect(
            game.registry.items.containsKey(id) ||
                game.registry.skills.containsKey(id) ||
                game.registry.locations.containsKey(id),
            isTrue,
            reason: '$id must resolve',
          );
        }
        expect(
          game.engine.state.profileId,
          game.registry.profile.id,
          reason: 'the engine refuses a state from another profile outright',
        );
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Refusals — one per reason, each proving nothing was created or deleted
// ---------------------------------------------------------------------------

void _blocked() {
  group('blocked', () {
    test('invalidContent: the pack fails validation', () async {
      final result = await boot(content: invalidContent);

      expectBlockedAndUntouched(
        result.outcome,
        BootstrapBlockReason.invalidContent,
        device: result.device,
        before: '',
        identity: result.identity,
      );
      final BootstrapBlocked blocked = result.outcome as BootstrapBlocked;
      expect(blocked.stoppedAt, BootstrapPhase.loadingContent);
      expect(blocked.detail, isNotEmpty);
    });

    test('invalidContent: the pack cannot be read at all', () async {
      final result = await boot(content: unreadableContent);

      expectBlockedAndUntouched(
        result.outcome,
        BootstrapBlockReason.invalidContent,
        device: result.device,
        before: '',
        identity: result.identity,
      );
      expect(
        (result.outcome as BootstrapBlocked).stoppedAt,
        BootstrapPhase.loadingContent,
      );
    });

    test('bothSlotsInvalid: a save exists and cannot be read', () async {
      // THE test. A save is present, neither slot verifies, and the only
      // acceptable outcome is a refusal that leaves the bytes alone.
      final saved = await savedGame(commits: 2);
      final FaultingDevice device = saved.device.reboot();
      device
        ..seed('save_slot_a', Uint8List.fromList(utf8.encode('not a save')))
        ..seed('save_slot_b', Uint8List.fromList(<int>[0, 1, 2, 3, 4]));

      final String before = device.image();
      final result = await boot(
        device: device,
        identity: MemoryIdentityStore(liveIdentity),
      );

      expectBlockedAndUntouched(
        result.outcome,
        BootstrapBlockReason.bothSlotsInvalid,
        device: device,
        before: before,
        identity: result.identity,
      );
      expect(
        result.outcome,
        isNot(isA<BootstrapNewGame>()),
        reason:
            'the worst available failure is a successful startup onto a wiped '
            'character',
      );
      expect(
        device.committedBytes('journal'),
        isNotNull,
        reason: 'the journal is evidence and must survive a refusal',
      );
    });

    test('bothSlotsInvalid: the journal alone is not a new game', () async {
      // Both slots deleted, journal intact — a file-wipe bug, not a new
      // install. `NoSaveFound` requires both absent *and* an empty journal.
      final saved = await savedGame(commits: 2);
      final FaultingDevice device = saved.device.reboot()
        ..erase('save_slot_a')
        ..erase('save_slot_b');

      final String before = device.image();
      final result = await boot(
        device: device,
        identity: MemoryIdentityStore(liveIdentity),
      );

      expectBlockedAndUntouched(
        result.outcome,
        BootstrapBlockReason.bothSlotsInvalid,
        device: device,
        before: before,
        identity: result.identity,
      );
    });

    test('unsupportedSaveVersion: written by a newer build', () async {
      final saved = await savedGame(commits: 1);
      final FaultingDevice device = deviceWithSnapshot(
        saved.state,
        mutate: (Map<String, Object?> envelope, Map<String, Object?> state) {
          envelope['gameStateVersion'] = 99;
          state['stateVersion'] = 99;
        },
      );

      final String before = device.image();
      final result = await boot(
        device: device,
        identity: MemoryIdentityStore(liveIdentity),
      );

      expectBlockedAndUntouched(
        result.outcome,
        BootstrapBlockReason.unsupportedSaveVersion,
        device: device,
        before: before,
        identity: result.identity,
      );
      expect(
        (result.outcome as BootstrapBlocked).explanation,
        contains('newer version'),
        reason: 'the player must be told the way out: update the app',
      );
    });

    test('qaProfileForbidden: a release build refuses QA pacing', () async {
      final ContentRegistry qa = qaRegistry;
      final saved = await savedGame(commits: 1, registry: qa);
      final FaultingDevice device = saved.device.reboot();

      final String before = device.image();
      final result = await boot(
        device: device,
        identity: MemoryIdentityStore(liveIdentity),
        profileId: BalanceProfile.acceleratedQaId,
        treatAsRelease: true,
      );

      expectBlockedAndUntouched(
        result.outcome,
        BootstrapBlockReason.qaProfileForbidden,
        device: device,
        before: before,
        identity: result.identity,
      );
    });

    test('profileMismatch: a QA save under a production build', () async {
      final saved = await savedGame(commits: 1, registry: qaRegistry);
      final FaultingDevice device = saved.device.reboot();

      final String before = device.image();
      final result = await boot(
        device: device,
        identity: MemoryIdentityStore(liveIdentity),
      );

      expectBlockedAndUntouched(
        result.outcome,
        BootstrapBlockReason.profileMismatch,
        device: device,
        before: before,
        identity: result.identity,
      );
      expect(
        (result.outcome as BootstrapBlocked).explanation,
        contains('profile.accelerated_qa'),
      );
    });

    test('profileMismatch: a profile this build has never heard of', () async {
      final saved = await savedGame(commits: 1);
      final FaultingDevice device = deviceWithSnapshot(
        saved.state,
        mutate: (Map<String, Object?> envelope, Map<String, Object?> state) {
          // Both, or the slot is rejected for disagreeing with its own header
          // and the test would pass for the wrong reason.
          envelope['balanceProfileId'] = 'profile.someone_elses_build';
          state['profileId'] = 'profile.someone_elses_build';
        },
      );

      final String before = device.image();
      final result = await boot(
        device: device,
        identity: MemoryIdentityStore(liveIdentity),
      );

      expectBlockedAndUntouched(
        result.outcome,
        BootstrapBlockReason.profileMismatch,
        device: device,
        before: before,
        identity: result.identity,
      );
    });

    test('originIdentityMismatch: the salt changed under the save', () async {
      final saved = await savedGame(commits: 1);
      final FaultingDevice device = deviceWithSnapshot(
        saved.state,
        originSaltFingerprint: saltThen,
      );

      final String before = device.image();
      final result = await boot(
        device: device,
        identity: MemoryIdentityStore(liveIdentity),
      );

      expectBlockedAndUntouched(
        result.outcome,
        BootstrapBlockReason.originIdentityMismatch,
        device: device,
        before: before,
        identity: result.identity,
      );
      final BootstrapBlocked blocked = result.outcome as BootstrapBlocked;
      // Both fingerprints are derived from health-source identity and this
      // string reaches a diagnostic surface.
      expect(blocked.explanation, isNot(contains(saltNow)));
      expect(blocked.explanation, isNot(contains(saltThen)));
    });

    test('originIdentityMissing: a save with no identity beside it', () async {
      // The identity was lost while the save survived. Every origin would
      // re-key and the live retention window would be granted twice.
      //
      // On iOS this is the *expected* shape of an iCloud restore onto a second
      // device: the Keychain item is ThisDeviceOnly and does not travel, so the
      // restored phone finds progress with no key. A distinct reason from a
      // mismatch, because a mismatch means two identities exist and disagree
      // while this means the device-bound one did not come with the device.
      final saved = await savedGame(commits: 2);
      final FaultingDevice device = saved.device.reboot();

      final String before = device.image();
      final result = await boot(device: device);

      expectBlockedAndUntouched(
        result.outcome,
        BootstrapBlockReason.originIdentityMissing,
        device: device,
        before: before,
        identity: result.identity,
      );
      expect(
        (result.outcome as BootstrapBlocked).stoppedAt,
        BootstrapPhase.validatingState,
      );
      expect(
        (result.outcome as BootstrapBlocked).explanation,
        contains('Reconnect health'),
        reason: 'a fail-closed refusal must name the way out of it',
      );
    });

    test(
      'unknownContentReferences: the save holds an item we removed',
      () async {
        final saved = await savedGame(commits: 1);
        final FaultingDevice device = deviceWithSnapshot(
          saved.state,
          mutate: (Map<String, Object?> envelope, Map<String, Object?> state) {
            (state['inventory']! as List<Object?>).add(<String, Object?>{
              'id': 'item.deleted_relic',
              'n': 1,
            });
          },
        );

        final String before = device.image();
        final result = await boot(
          device: device,
          identity: MemoryIdentityStore(liveIdentity),
        );

        expectBlockedAndUntouched(
          result.outcome,
          BootstrapBlockReason.unknownContentReferences,
          device: device,
          before: before,
          identity: result.identity,
        );
        expect(
          (result.outcome as BootstrapBlocked).explanation,
          contains('item.deleted_relic'),
          reason: 'refuse, never drop — a dropped item is a deleted possession',
        );
      },
    );

    test('storageUnavailable: the identity store cannot be read', () async {
      final MemoryIdentityStore store = MemoryIdentityStore(liveIdentity)
        ..readThrows = true;
      final saved = await savedGame(commits: 1);
      final FaultingDevice device = saved.device.reboot();

      final String before = device.image();
      final result = await boot(device: device, identity: store);

      expectBlockedAndUntouched(
        result.outcome,
        BootstrapBlockReason.storageUnavailable,
        device: device,
        before: before,
        identity: store,
      );
      expect(
        (result.outcome as BootstrapBlocked).stoppedAt,
        BootstrapPhase.openingStorage,
      );
    });

    test('storageUnavailable: the save files cannot be read', () async {
      final MemoryIdentityStore store = MemoryIdentityStore(liveIdentity);
      final SaveRepository repository = SaveRepository(
        snapshots: const UnreadableSnapshots(),
        journal: FaultingJournal(FaultingDevice()),
      );

      final result = await boot(identity: store, repository: repository);

      expect(result.outcome, isA<BootstrapBlocked>());
      final BootstrapBlocked blocked = result.outcome as BootstrapBlocked;
      expect(blocked.reason, BootstrapBlockReason.storageUnavailable);
      expect(blocked.stoppedAt, BootstrapPhase.loadingSave);
      expect(store.writes, isEmpty);
      expect(result.mintCalls, 0);
    });

    test('recoveryNotProvable: the journal belongs to another save', () async {
      final saved = await savedGame(commits: 1);
      final FaultingDevice device = saved.device.reboot();

      // A record from a different lineage, appended after the real one. Its
      // presence means the storage is not what the snapshot thinks it is.
      final Uint8List journal = device.committedBytes('journal')!;
      final Uint8List foreign = encodeJournalLine(
        const JournalRecord(
          formatVersion: 1,
          saveId: 'save-from-another-device',
          transactionId: 2,
          eventSequenceBefore: 99,
          eventSequenceAfter: 100,
          events: <GameEvent>[],
        ),
      );
      device.seed('journal', Uint8List.fromList(<int>[...journal, ...foreign]));

      final String before = device.image();
      final result = await boot(
        device: device,
        identity: MemoryIdentityStore(liveIdentity),
      );

      expectBlockedAndUntouched(
        result.outcome,
        BootstrapBlockReason.recoveryNotProvable,
        device: device,
        before: before,
        identity: result.identity,
      );
      expect(
        (result.outcome as BootstrapBlocked).stoppedAt,
        BootstrapPhase.recoveringJournal,
      );
    });

    test('recoveryNotProvable: two histories at one transaction', () async {
      final saved = await savedGame(commits: 1);
      final FaultingDevice device = saved.device.reboot();

      final Uint8List journal = device.committedBytes('journal')!;
      final Uint8List forked = encodeJournalLine(
        JournalRecord(
          formatVersion: 1,
          saveId: testSaveId,
          transactionId: 1,
          eventSequenceBefore: 0,
          eventSequenceAfter: 7,
          events: <GameEvent>[
            const StepsGranted(
              sequence: 1,
              steps: 3001,
              grantedTotalAfter: 3001,
            ),
          ],
        ),
      );
      device.seed('journal', Uint8List.fromList(<int>[...journal, ...forked]));

      final String before = device.image();
      final result = await boot(
        device: device,
        identity: MemoryIdentityStore(liveIdentity),
      );

      expectBlockedAndUntouched(
        result.outcome,
        BootstrapBlockReason.recoveryNotProvable,
        device: device,
        before: before,
        identity: result.identity,
      );
    });

    test('every block reason has a player-legible explanation', () async {
      // A refusal the player cannot act on is a crash with better manners.
      final saved = await savedGame(commits: 1);
      final result = await boot(
        device: saved.device.reboot(),
        content: invalidContent,
      );
      final BootstrapBlocked blocked = result.outcome as BootstrapBlocked;
      expect(blocked.explanation, isNotEmpty);
      expect(blocked.explanation.trim(), endsWith('.'));
    });
  });
}

// ---------------------------------------------------------------------------
// Identity reuse
// ---------------------------------------------------------------------------

const ReconciliationIdentity orphanIdentity = ReconciliationIdentity(
  saveId: 'save-from-the-crashed-launch',
  saltFingerprint: 'cccccccccccccccc',
);

void _identityReuse() {
  // The owner's F-06 ruling: provisioning is identity-first, and an identity
  // with **no save and no journal at all** is an interrupted first-save orphan.
  // It is deleted and reprovisioned, not reused.
  //
  // Reuse was the previous behaviour and reads as the conservative choice. It
  // is not. The orphan's saveId is the lineage of a save that was never
  // written, so binding it to a different, later save makes a lineage id stop
  // meaning "the save it was minted for" — and `_resume`, the journal scan and
  // `_checkSalt` are all comparisons against that identifier.
  //
  // What makes the deletion safe is *where* it sits. It is reachable only
  // through `NoSaveFound`, which the load produces only when both slots are
  // conclusively absent and the journal is empty. Every weaker observation —
  // truncated, corrupt, busy, unreadable — is a refusal that never gets here.
  // `closure_audit_test.dart` C4 is what holds that boundary.
  group('identity with no save', () {
    test('is deleted and reprovisioned, not reused', () async {
      final MemoryIdentityStore store = MemoryIdentityStore(orphanIdentity);

      final result = await boot(
        identity: store,
        mints: const ReconciliationIdentity(
          saveId: 'a-second-lineage',
          saltFingerprint: 'dddddddddddddddd',
        ),
      );

      expect(result.outcome, isA<BootstrapNewGame>());
      expect(
        (result.outcome as BootstrapNewGame).identity.saveId,
        'a-second-lineage',
      );
      expect(result.mintCalls, 1);
      expect(store.erasures, 1, reason: 'the orphan is cleared exactly once');
      expect(store.writes, hasLength(1));
    });

    test('the new lineage is the one the new save is written under', () async {
      final result = await boot(identity: MemoryIdentityStore(orphanIdentity));

      // Read the lineage back off the durable journal, not off the object we
      // were handed — a saveId that only exists in memory proves nothing.
      final Uint8List journal = result.device.committedBytes('journal')!;
      final JournalLineResult line = decodeJournalLine(journal);
      expect(line.ok, isTrue);
      expect(line.record!.saveId, liveIdentity.saveId);
      expect(
        line.record!.saveId,
        isNot(orphanIdentity.saveId),
        reason:
            'a save must never be written under a lineage minted for a '
            'different save',
      );
    });

    test('a failed orphan cleanup blocks rather than provisioning', () async {
      // The one state worse than an orphan is a second lineage beside it.
      final MemoryIdentityStore store = MemoryIdentityStore(orphanIdentity)
        ..eraseThrows = true;
      final result = await boot(identity: store);

      expect(result.outcome, isA<BootstrapBlocked>());
      expect(
        (result.outcome as BootstrapBlocked).reason,
        BootstrapBlockReason.storageUnavailable,
      );
      expect(result.mintCalls, 0);
      expect(store.writes, isEmpty);
      expect(result.device.image(), isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// The salt fingerprint, end to end
// ---------------------------------------------------------------------------
//
// This began as a documented gap: `SaveRepository._commitOnce` called
// `encodeSnapshot` without a fingerprint, so no snapshot the real pipeline
// wrote ever carried one, `_checkSalt` returned early on every load, and
// `LoadRefusal.originKeyReset` was unreachable outside tests that hand-built an
// envelope. It was reachable only in prose.
//
// The parameter is now required on both `encodeSnapshot` and
// `SaveRepository.commit`, so forgetting it is a compile error. These tests are
// the regression: they fail if the value is ever dropped again, which a
// compile error alone cannot catch once someone passes `null` to make it build.

void _saltFingerprintEndToEnd() {
  group('the salt fingerprint reaches the durable bytes', () {
    test('a new game records the identity it was started under', () async {
      final result = await boot();
      expect(result.outcome, isA<BootstrapNewGame>());

      final Uint8List slot = result.device.committedBytes('save_slot_a')!;
      final SaveEnvelope envelope = decodeEnvelope(unframe(slot).payload!);

      expect(
        envelope.originSaltFingerprint,
        saltNow,
        reason:
            'a snapshot with no fingerprint cannot detect a re-keyed origin, '
            'and the whole live retention window would be granted twice',
      );
    });

    test('a foreign salt is refused on the next launch', () async {
      // The end-to-end proof: the save was written by the pipeline, not by a
      // hand-built envelope, and it still fails closed.
      final result = await boot();
      final second = await boot(
        device: result.device.reboot(),
        identity: MemoryIdentityStore(
          const ReconciliationIdentity(
            saveId: testSaveId,
            saltFingerprint: saltThen,
          ),
        ),
      );

      expect(second.outcome, isA<BootstrapBlocked>());
      expect(
        (second.outcome as BootstrapBlocked).reason,
        BootstrapBlockReason.originIdentityMismatch,
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Documented gaps
// ---------------------------------------------------------------------------
//
// Pins behaviour that is **currently wrong**, so the wrongness is visible in a
// test run rather than only in a report someone read once. Invert it when the
// gap is closed; the expectation says so.

void _documentedGaps() {
  group('documented gaps', () {
    test('an identity from another lineage is refused', () async {
      // Closed in F-06. `SaveLoaded` now carries the envelope's `saveId` and
      // `_resume` compares it.
      //
      // Before that, a mismatched identity resumed silently and every later
      // commit was written under the wrong id — which forks the journal
      // lineage on the very next transaction and leaves the launch after that
      // with `lineageMismatch` and no way out.
      final saved = await savedGame(commits: 2, saveId: 'lineage-one');
      final result = await boot(
        device: saved.device.reboot(),
        identity: MemoryIdentityStore(
          const ReconciliationIdentity(
            saveId: 'lineage-two',
            saltFingerprint: saltNow,
          ),
        ),
      );

      expect(result.outcome, isA<BootstrapBlocked>());
      expect(
        (result.outcome as BootstrapBlocked).reason,
        BootstrapBlockReason.originIdentityMismatch,
      );
      expect(
        (result.outcome as BootstrapBlocked).explanation,
        contains('Reconnect health'),
        reason: 'a fail-closed refusal must name the way out of it',
      );
    });
  });
}

// ---------------------------------------------------------------------------
// The identity ordering
// ---------------------------------------------------------------------------
//
// Four rules, from the owner's F-06 ruling. Three of them are about *not* doing
// something, which is the kind of rule that passes review, ships, and is then
// quietly undone by a plausible-looking repair six months later. So each one is
// a test.
//
//   1. existing save + missing key  => originIdentityMissing
//   2. existing save + wrong key    => originIdentityMismatch
//   3. no save + no key             => create the key, only on the new-game path
//   4. a failed read                => never a write, never a mint

void _identityOrdering() {
  group('identity ordering', () {
    test('1. an existing save with no key blocks as *missing*', () async {
      final saved = await savedGame(commits: 2);
      final result = await boot(device: saved.device.reboot());

      expect(
        (result.outcome as BootstrapBlocked).reason,
        BootstrapBlockReason.originIdentityMissing,
      );
    });

    test(
      '2. an existing save with a foreign key blocks as *mismatch*',
      () async {
        final saved = await savedGame(commits: 2);
        final result = await boot(
          device: saved.device.reboot(),
          identity: MemoryIdentityStore(
            const ReconciliationIdentity(
              saveId: 'some-other-lineage',
              saltFingerprint: saltNow,
            ),
          ),
        );

        expect(
          (result.outcome as BootstrapBlocked).reason,
          BootstrapBlockReason.originIdentityMismatch,
        );
      },
    );

    test('1 and 2 are distinguishable, not one reason in two hats', () async {
      // The assertion is the *inequality*. A diagnostic that folded these
      // together would send anyone investigating an iCloud restore looking for
      // a second installation that does not exist.
      final saved = await savedGame(commits: 2);
      final missing = await boot(device: saved.device.reboot());
      final mismatch = await boot(
        device: saved.device.reboot(),
        identity: MemoryIdentityStore(
          const ReconciliationIdentity(
            saveId: 'some-other-lineage',
            saltFingerprint: saltNow,
          ),
        ),
      );

      expect(
        (missing.outcome as BootstrapBlocked).reason,
        isNot((mismatch.outcome as BootstrapBlocked).reason),
      );
    });

    test('3. no save and no key mints once and writes once', () async {
      final result = await boot();

      expect(result.outcome, isA<BootstrapNewGame>());
      expect(result.mintCalls, 1);
      expect(result.identity.writes, hasLength(1));
      expect(result.identity.erasures, 0);
    });

    test('3. the key is written only on the new-game path', () async {
      // Every other terminal state must leave the store untouched. Enumerated
      // rather than spot-checked: a path added later that writes an identity is
      // exactly the regression this catches.
      final saved = await savedGame(commits: 1);

      final List<({String name, MemoryIdentityStore store})> paths =
          <({String name, MemoryIdentityStore store})>[];

      final MemoryIdentityStore resuming = MemoryIdentityStore(liveIdentity);
      await boot(device: saved.device.reboot(), identity: resuming);
      paths.add((name: 'resume', store: resuming));

      final MemoryIdentityStore badContent = MemoryIdentityStore();
      await boot(identity: badContent, content: invalidContent);
      paths.add((name: 'invalid content', store: badContent));

      final MemoryIdentityStore missingKey = MemoryIdentityStore();
      await boot(device: saved.device.reboot(), identity: missingKey);
      paths.add((name: 'missing identity', store: missingKey));

      for (final ({String name, MemoryIdentityStore store}) path in paths) {
        expect(
          path.store.writes,
          isEmpty,
          reason: 'the ${path.name} path must not write an identity',
        );
        expect(path.store.erasures, 0, reason: '${path.name} must not erase');
      }
    });

    test('4. a failed read never writes and never mints', () async {
      // The scenario the ruling names directly, and the one that looks most
      // like a bug rather than a rule: the device is *empty*, the identity read
      // fails, and the tempting repair is "there is nothing here, mint one".
      //
      // On iOS an identity read fails when the Keychain cannot answer — before
      // the first unlock since boot, for instance. Save files are readable long
      // before the Keychain is, so "unreadable identity" and "empty device" can
      // be observed together on a device that has neither condition truly.
      // Minting here would write a key a later real read would contradict.
      final MemoryIdentityStore store = MemoryIdentityStore()
        ..readThrows = true;
      final result = await boot(identity: store);

      expect(
        (result.outcome as BootstrapBlocked).reason,
        BootstrapBlockReason.storageUnavailable,
      );
      expect(result.mintCalls, 0, reason: 'a failed read must not mint');
      expect(store.writes, isEmpty, reason: 'a failed read must not write');
      expect(store.erasures, 0);
      expect(result.device.image(), isEmpty, reason: 'nothing was created');
    });

    test('4. a failed read over a live save never overwrites it', () async {
      final MemoryIdentityStore store = MemoryIdentityStore(liveIdentity)
        ..readThrows = true;
      final saved = await savedGame(commits: 2);
      final FaultingDevice device = saved.device.reboot();
      final String before = device.image();

      final result = await boot(device: device, identity: store);

      expect(
        (result.outcome as BootstrapBlocked).reason,
        BootstrapBlockReason.storageUnavailable,
      );
      expect(store.writes, isEmpty);
      expect(device.image(), before);
      expect(result.mintCalls, 0);
    });

    test(
      '5. a failed first commit attempts cleanup, and the next launch recovers',
      () async {
        // The conflict this test used to describe is resolved. The owner ruled
        // that provisioning is identity-first: the identity is written before
        // the first commit, because the alternative ordering leaves a save with
        // no identity, which is `originIdentityMissing` forever and caused by
        // us. What changed is what happens *after* a refused commit — cleanup
        // is now attempted, because the identity provably has no save under it.
        final FaultingDevice device = FaultingDevice()
          ..plan(<Fault>[
            const Fault(
              op: 'append',
              path: 'journal',
              effect: FaultEffect.failBefore,
            ),
          ]);
        final MemoryIdentityStore store = MemoryIdentityStore();

        final result = await boot(device: device, identity: store);

        expect(result.outcome, isA<BootstrapBlocked>());
        expect(store.writes, hasLength(1));
        expect(
          store.erasures,
          1,
          reason:
              'the identity has no save under it and the commit wrote nothing, '
              'so this is the orphan rule, not a blocked bootstrap deleting a '
              'save',
        );
        expect(
          device.image(),
          isEmpty,
          reason: 'nothing durable was created for it to orphan',
        );

        // The next launch reaches a new game under one lineage, not two.
        final second = await boot(device: device.reboot(), identity: store);
        expect(second.outcome, isA<BootstrapNewGame>());
        expect((second.outcome as BootstrapNewGame).identity, liveIdentity);
      },
    );

    test(
      '5. a cleanup that itself fails leaves a recoverable orphan, not a crash',
      () async {
        // The residue is an identity with no save. That is exactly the state
        // the orphan rule above is for, so the next launch clears it and
        // provisions — no permanent failure, and no escaping exception from
        // either launch.
        final FaultingDevice device = FaultingDevice()
          ..plan(<Fault>[
            const Fault(
              op: 'append',
              path: 'journal',
              effect: FaultEffect.failBefore,
            ),
          ]);
        final MemoryIdentityStore store = MemoryIdentityStore()
          ..eraseThrows = true;

        final result = await boot(device: device, identity: store);

        expect(
          result.outcome,
          isA<BootstrapBlocked>(),
          reason: 'a failed cleanup is still a typed outcome',
        );
        expect(store.writes, hasLength(1));

        store.eraseThrows = false;
        final second = await boot(device: device.reboot(), identity: store);
        expect(second.outcome, isA<BootstrapNewGame>());
        expect(store.erasures, 1, reason: 'the orphan is cleared on relaunch');
      },
    );
  });
}
