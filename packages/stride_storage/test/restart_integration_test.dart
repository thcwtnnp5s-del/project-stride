// Restart, against a real filesystem.
//
// ## What "restart" means here, and why it is not a reboot() call
//
// A restart is simulated by **discarding every object** and constructing a
// brand-new `SaveRepository`, `FileSnapshotStore`, `FileLedgerJournal`, and
// `FileIdentityStore` over the same directory. Nothing is carried across —
// no repository, no engine, no state, no cached bytes. The only thing that
// survives is what is on disk, which is the only thing that survives a process
// kill.
//
// A test that reused a repository across the "restart" would be proving that
// a Dart object remembers its own fields.
//
// ## What this does NOT prove
//
// This is not process-death evidence and must not be cited as any. `dart test`
// runs in one process; the files persist because nothing deleted them, not
// because the OS was ever asked to keep them across a kill. What it *does*
// prove is that every byte the next launch depends on is on disk and is
// sufficient — which is the precondition for surviving a kill, and the part
// that is actually testable without a device.
//
// Real Android process-death evidence lives in `integration_test/` and
// `Scripts/android-process-death.sh`, and is documented there as manual.
//
// Quantities are distinct and non-summing — 137, 291, 613, 1009 — so a drop,
// a duplicate, and an off-by-one each move a different number.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:stride_storage/stride_storage.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Content
// ---------------------------------------------------------------------------

/// The production content pack, read from the repository.
///
/// `stride_storage` ships no content of its own; using the real pack means a
/// restart is exercised against the states the game actually produces.
ContentSource get productionSource {
  for (final String candidate in <String>[
    '../../assets/content/v1',
    'assets/content/v1',
  ]) {
    final Directory directory = Directory(candidate);
    if (!directory.existsSync()) continue;
    final Map<String, String> files = <String, String>{};
    for (final FileSystemEntity entity in directory.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      files[entity.uri.pathSegments.last] = entity.readAsStringSync();
    }
    return ContentSource(files);
  }
  throw StateError(
    'Could not locate assets/content/v1 from ${Directory.current.path}. '
    'Run from packages/stride_storage or the repository root.',
  );
}

final ContentRegistry registry = const ContentLoader()
    .load(productionSource, profileId: BalanceProfile.productionId)
    .requireRegistry;

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const String saveId = 'restart-0001';
final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

StepObservation obs(StepOriginKey origin, int index, int steps) =>
    StepObservation(
      key: ObservationKey(
        origin: origin,
        bucket: TimeBucket(
          startMillis: t0 + index * hour,
          endMillis: t0 + (index + 1) * hour,
        ),
      ),
      steps: steps,
    );

/// An incremental sync. [completeThroughIndex] is the adapter's completeness
/// assertion; omitting it means "do not compact".
IncrementalSync incremental(
  List<StepObservation> observations, {
  String? next,
  int? completeThroughIndex,
  int fromIndex = 0,
}) => IncrementalSync(
  observations: observations,
  nextCursor: next == null ? null : SyncCursor.ofString(next),
  completeness: completeThroughIndex == null
      ? const PartialDelivery()
      : CompleteThrough(
          throughMillis: t0 + completeThroughIndex * hour,
          scope: CompletenessScope(
            dataType: HealthDataType.steps,
            origins: const AllOrigins(),
            intervalStartMillis: t0 + fromIndex * hour,
            intervalEndMillis: t0 + completeThroughIndex * hour,
            queryGeneration: 1,
          ),
        ),
);

int grantedBy(EngineResult result) => result.events
    .whereType<StepsGranted>()
    .fold<int>(0, (int sum, StepsGranted e) => sum + e.steps);

/// Everything one launch of the app holds. Constructed fresh per session and
/// never shared — see the header.
final class Session {
  Session(Directory root)
    : layout = StorageLayout(root),
      repository = SaveRepository(
        snapshots: FileSnapshotStore(StorageLayout(root)),
        journal: FileLedgerJournal(StorageLayout(root)),
        lock: FileTransactionLock(StorageLayout(root).transactionLock),
      ),
      identityStore = FileIdentityStore(StorageLayout(root));

  final StorageLayout layout;
  final SaveRepository repository;
  final FileIdentityStore identityStore;

  BootstrapCoordinator get coordinator => BootstrapCoordinator(
    repository: repository,
    identityStore: identityStore,
    profileId: BalanceProfile.productionId,
  );

  Future<BootstrapOutcome> start(ReconciliationIdentity identity) =>
      coordinator.run(
        loadContent: () async => productionSource,
        mintIdentity: () => identity,
      );
}

/// The durable image: every file, its length, and its digest.
///
/// Compared before and after a refusal, and printed on failure, so "nothing
/// was touched" is an assertion rather than a hope.
String imageOf(StorageLayout layout) {
  final List<String> lines = <String>[];
  for (final File file in layout.allFiles) {
    if (!file.existsSync()) continue;
    final Uint8List bytes = file.readAsBytesSync();
    final String name = file.uri.pathSegments.last;
    lines.add('$name:${bytes.length}:${crc32cHex(bytes)}');
  }
  lines.sort();
  return lines.join('\n');
}

void main() {
  late Directory root;

  /// The identity every commit in a test is written under. Set by
  /// [seedIdentity]; carried into every snapshot so the salt fail-closed check
  /// has something real to validate against after a restart.
  late ReconciliationIdentity identityInUse;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('stride_restart_');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  /// Writes an identity the way the app does, before startup runs.
  Future<ReconciliationIdentity> seedIdentity(Session session) async {
    final StoredIdentity stored = StoredIdentity(
      saveId: saveId,
      // A fixed salt, not a random one: the fingerprint must be reproducible
      // across sessions or this suite would be testing `Random`.
      salt: Uint8List.fromList(List<int>.generate(16, (int i) => i * 7 + 3)),
    );
    await session.identityStore.writeStored(stored);
    identityInUse = stored.public;
    return identityInUse;
  }

  /// Commits one batch against the durable head, and returns the new head.
  Future<CommitDurable> commitBatch(
    Session session,
    GameState after,
    List<GameEvent> events, {
    required int generation,
    required int lastTransaction,
  }) async {
    final CommitOutcome outcome = await session.repository.commit(
      after: after,
      events: events,
      saveId: saveId,
      expectation: CommitExpectation(
        expectedSnapshotGeneration: generation,
        expectedLastAppliedTransaction: lastTransaction,
      ),
      // The real fingerprint, not null: a snapshot that records none cannot
      // detect a re-keyed origin on the next launch.
      originSaltFingerprint: identityInUse.saltFingerprint,
    );
    expect(outcome, isA<CommitDurable>(), reason: 'the fixture must commit');
    return outcome as CommitDurable;
  }

  // -------------------------------------------------------------------------

  group('a save survives a restart', () {
    test('a new game started in one session resumes in the next', () async {
      // --- session one -----------------------------------------------------
      Session session = Session(root);
      final ReconciliationIdentity identity = await seedIdentity(session);

      final BootstrapOutcome first = await session.start(identity);
      expect(first, isA<BootstrapNewGame>());
      final String signatureAtStart =
          (first as BootstrapNewGame).engine.state.signature;

      // The snapshot must be on disk before the first session is even over.
      expect(
        session.layout.slotA.existsSync(),
        isTrue,
        reason: 'a new game held only in memory is lost to a process kill',
      );

      // --- everything from session one is discarded ------------------------
      session = Session(root);

      final BootstrapOutcome second = await session.start(identity);
      expect(
        second,
        isA<BootstrapExistingGame>(),
        reason: 'the second launch must resume, never restart',
      );
      final BootstrapExistingGame resumed = second as BootstrapExistingGame;
      expect(resumed.engine.state.signature, signatureAtStart);
      expect(resumed.identity, identity);
      expect(resumed.load.repairs, isEmpty);
    });

    test('granted steps are exact across three restarts', () async {
      Session session = Session(root);
      final ReconciliationIdentity identity = await seedIdentity(session);
      await session.start(identity);

      int total = 0;
      String signature = '';

      for (final int steps in <int>[613, 291, 137]) {
        // A fresh session per batch: commit, then die.
        session = Session(root);
        final BootstrapExistingGame game =
            await session.start(identity) as BootstrapExistingGame;
        final GameEngine engine = game.engine;

        final EngineResult r = engine.execute(
          GrantSyntheticSteps(steps: steps, reason: 'walk'),
        );
        await commitBatch(
          session,
          engine.state,
          r.events,
          generation: game.load.generation,
          lastTransaction: game.load.lastAppliedTransaction,
        );
        total += steps;
        signature = engine.state.signature;
      }

      // One more restart, reading only what is on disk.
      session = Session(root);
      final BootstrapExistingGame finalLaunch =
          await session.start(identity) as BootstrapExistingGame;

      expect(finalLaunch.engine.state.steps.totalGranted, total);
      expect(finalLaunch.engine.state.steps.totalGranted, 1041);
      expect(finalLaunch.engine.state.signature, signature);
    });

    // This case used to assert the opposite: that a seeded identity survived
    // startup and kept its salt. **The owner overruled its premise.**
    //
    // Identity reuse is gone. Provisioning is identity-first, and an identity
    // sitting beside conclusively-absent save artifacts is an interrupted
    // first-save *orphan*: it names a lineage no save was ever written under,
    // and reusing it would let a later save be written under a lineage minted
    // for a different one. The launch clears it and provisions a new lineage.
    //
    // Asserting the new rule rather than weakening the old one, because
    // "does not throw" and "recovers correctly" are different properties and
    // only the second is worth having.
    test(
      'an orphan identity is cleared and a new lineage provisioned',
      () async {
        Session session = Session(root);
        final ReconciliationIdentity orphan = await seedIdentity(session);

        // Nothing has been committed, so the save artifacts are conclusively
        // absent and the seeded identity is by definition an orphan.
        expect(session.layout.slotA.existsSync(), isFalse);
        expect(session.layout.journal.existsSync(), isFalse);

        final ReconciliationIdentity minted = ReconciliationIdentity(
          saveId: 'restart-0002-reprovisioned',
          saltFingerprint: OriginSaltPolicy.fingerprint(
            Uint8List.fromList(List<int>.generate(16, (int i) => i * 11 + 5)),
          ),
        );
        final BootstrapOutcome started = await session.coordinator.run(
          loadContent: () async => productionSource,
          mintIdentity: () => minted,
        );
        expect(
          started,
          isA<BootstrapNewGame>(),
          reason: 'an orphan must not block startup; got $started',
        );

        // --- the restart, reading only what is on disk ------------------------
        session = Session(root);
        final ReconciliationIdentity? reread = await session.identityStore
            .read();

        expect(
          reread?.saveId,
          minted.saveId,
          reason: 'the durable identity must be the reprovisioned lineage',
        );
        expect(
          reread?.saveId,
          isNot(orphan.saveId),
          reason:
              'the orphan lineage was reused. A save written under a lineage '
              'minted for a different save is a lineage mismatch on every '
              'subsequent load',
        );
        expect(
          reread?.saltFingerprint,
          isNot(orphan.saltFingerprint),
          reason: 'a reprovisioned lineage carries its own salt fingerprint',
        );

        // And the record is READABLE. The coordinator writes through the
        // core-facing port, which has only a fingerprint to write — so this is
        // the salt-less shape, and `readRecord` names it instead of reporting a
        // record this package writes on purpose as a corrupt one.
        final IdentityRecord record = await session.identityStore.readRecord();
        expect(
          record,
          isA<IdentityWithoutSalt>(),
          reason:
              'BootstrapCoordinator writes ReconciliationIdentityStore.write, '
              'which has no salt to write',
        );
        expect((record as IdentityWithoutSalt).saveId, minted.saveId);
        expect(record.saltFingerprint, minted.saltFingerprint);

        // The app never reaches this shape -- IdentityVault writes the full
        // record -- so `readStored` still fails closed on it rather than
        // guessing. It must fail *legibly*, naming the shape, and it must never
        // answer "absent": that would present a live lineage as a new
        // installation.
        await expectLater(
          session.identityStore.readStored(),
          throwsA(
            isA<StorageException>().having(
              (StorageException e) => '${e.cause}',
              'cause',
              allOf(contains('no salt'), contains('readRecord')),
            ),
          ),
        );
      },
    );

    test('a full record round-trips through a restart with its salt', () async {
      final Session session = Session(root);
      await seedIdentity(session);

      // No startup: this is the vault's shape, written by writeStored, and it
      // must survive being read by a completely fresh set of objects.
      final IdentityRecord record = await Session(
        root,
      ).identityStore.readRecord();
      expect(record, isA<IdentityWithSalt>());
      expect(
        (record as IdentityWithSalt).identity.salt.length,
        16,
        reason: 'the salt itself must survive; a fingerprint cannot rebuild it',
      );
      expect((await Session(root).identityStore.readStored())!.salt.length, 16);
      expect(
        await Session(root).identityStore.readRecord(),
        isA<IdentityWithSalt>(),
      );
    });

    test('an absent identity file is absent, not damaged', () async {
      expect(
        await Session(root).identityStore.readRecord(),
        isA<IdentityAbsent>(),
      );
      expect(await Session(root).identityStore.readStored(), isNull);
      expect(await Session(root).identityStore.read(), isNull);
    });
  });

  // -------------------------------------------------------------------------

  group('per-origin watermarks survive a restart', () {
    test('a settled bucket replayed after a restart grants zero', () async {
      // The failure this guards: a dropped watermark map makes every origin
      // look new, so the whole live retention window is granted a second time.
      // F-04's arithmetic cannot catch it, because the record it consults is
      // exactly the one that was lost.
      Session session = Session(root);
      final ReconciliationIdentity identity = await seedIdentity(session);

      final BootstrapNewGame started =
          await session.start(identity) as BootstrapNewGame;
      GameEngine engine = started.engine;

      final LoadOutcome head = await session.repository.load(
        registry: registry,
      );
      int generation = (head as SaveLoaded).generation;
      int lastTransaction = head.lastAppliedTransaction;

      // Long enough that compaction runs and the ledger settles origins into
      // watermarks rather than keeping every slice.
      for (int day = 0; day < 14; day++) {
        final EngineResult r = engine.execute(
          ReconcileStepSync(
            response: incremental(
              <StepObservation>[obs(phone, day * 24, 1009)],
              next: 'day-$day',
              completeThroughIndex: day * 24 + 1,
            ),
          ),
        );
        final CommitDurable durable = await commitBatch(
          session,
          engine.state,
          r.events,
          generation: generation,
          lastTransaction: lastTransaction,
        );
        generation = durable.generation;
        lastTransaction = durable.transactionId;
      }

      final Map<StepOriginKey, int> watermarksBefore =
          engine.state.steps.checkpoint.originWatermarks;
      expect(
        watermarksBefore,
        isNotEmpty,
        reason: 'the fixture must actually settle an origin',
      );
      expect(engine.state.steps.totalGranted, 14126);

      // The journal must have been compacted, or "watermarks survived" would
      // only be proving that replay rebuilt them from records still present.
      final int journalLines = (await FileLedgerJournal(
        session.layout,
      ).readLines()).length;
      expect(
        journalLines,
        lessThan(15),
        reason: 'compaction must have removed records below the floor',
      );

      // --- restart ---------------------------------------------------------
      session = Session(root);
      final BootstrapExistingGame resumed =
          await session.start(identity) as BootstrapExistingGame;
      engine = resumed.engine;

      expect(
        engine.state.steps.checkpoint.originWatermarks,
        watermarksBefore,
        reason: 'a dropped watermark re-grants the whole retention window',
      );

      // The proof that matters, and the reason this test exists: replay a
      // bucket the ledger already settled and confirm it grants nothing.
      final EngineResult replay = engine.execute(
        ReconcileStepSync(
          response: incremental(<StepObservation>[
            obs(phone, 0, 1009),
          ], next: 'replay'),
        ),
      );
      expect(
        grantedBy(replay),
        0,
        reason: 'a settled bucket must never be granted twice',
      );
      expect(engine.state.steps.totalGranted, 14126);
    });
  });

  // -------------------------------------------------------------------------

  group('a torn journal tail is recovered', () {
    test(
      'an interrupted append is discarded and the save still loads',
      () async {
        Session session = Session(root);
        final ReconciliationIdentity identity = await seedIdentity(session);
        final BootstrapNewGame started =
            await session.start(identity) as BootstrapNewGame;
        final GameEngine engine = started.engine;

        final SaveLoaded head =
            await session.repository.load(registry: registry) as SaveLoaded;
        int generation = head.generation;
        int lastTransaction = head.lastAppliedTransaction;

        for (final int steps in <int>[613, 291]) {
          final EngineResult r = engine.execute(
            GrantSyntheticSteps(steps: steps, reason: 'walk'),
          );
          final CommitDurable durable = await commitBatch(
            session,
            engine.state,
            r.events,
            generation: generation,
            lastTransaction: lastTransaction,
          );
          generation = durable.generation;
          lastTransaction = durable.transactionId;
        }
        final String signatureBefore = engine.state.signature;

        // An append that started and did not finish: bytes with no terminator
        // and a digest that covers nothing. This is what a kill mid-`writeFrom`
        // leaves on a real device.
        final RandomAccessFile handle = await session.layout.journal.open(
          mode: FileMode.append,
        );
        await handle.writeFrom(
          Uint8List.fromList(utf8.encode('7f3a91cc {"f":1,"saveId":"rest')),
        );
        await handle.flush();
        await handle.close();

        // --- restart ---------------------------------------------------------
        session = Session(root);
        final BootstrapExistingGame resumed =
            await session.start(identity) as BootstrapExistingGame;

        expect(
          resumed.load.repairs.map((SaveRepair r) => r.diagnosis),
          contains(SaveDiagnosis.journalTailTorn),
          reason: 'a torn tail must be diagnosed, not silently swallowed',
        );
        expect(resumed.engine.state.steps.totalGranted, 904);
        expect(resumed.engine.state.signature, signatureBefore);
      },
    );

    test('a torn tail whose snapshot never landed loses nothing', () async {
      // The dangerous shape: the journal is the commit point, so a record that
      // is durable must be replayed even though the snapshot behind it is one
      // transaction stale.
      Session session = Session(root);
      final ReconciliationIdentity identity = await seedIdentity(session);
      final BootstrapNewGame started =
          await session.start(identity) as BootstrapNewGame;
      final GameEngine engine = started.engine;

      final SaveLoaded head =
          await session.repository.load(registry: registry) as SaveLoaded;

      final EngineResult r = engine.execute(
        const GrantSyntheticSteps(steps: 613, reason: 'walk'),
      );
      await commitBatch(
        session,
        engine.state,
        r.events,
        generation: head.generation,
        lastTransaction: head.lastAppliedTransaction,
      );
      final String signatureBefore = engine.state.signature;

      // Roll the snapshots back to the genesis state by deleting the newer
      // slot: the journal now leads both snapshots.
      final Uint8List slotA = session.layout.slotA.readAsBytesSync();
      final Uint8List slotB = session.layout.slotB.readAsBytesSync();
      final int genA = decodeEnvelope(
        unframe(slotA).payload!,
      ).snapshotGeneration;
      final int genB = decodeEnvelope(
        unframe(slotB).payload!,
      ).snapshotGeneration;
      (genA > genB ? session.layout.slotA : session.layout.slotB).deleteSync();

      // --- restart ---------------------------------------------------------
      session = Session(root);
      final BootstrapExistingGame resumed =
          await session.start(identity) as BootstrapExistingGame;

      expect(resumed.load.replayedTransactions, greaterThanOrEqualTo(1));
      expect(
        resumed.engine.state.steps.totalGranted,
        613,
        reason: 'a grant whose journal record is durable is never lost',
      );
      expect(resumed.engine.state.signature, signatureBefore);
    });
  });

  // -------------------------------------------------------------------------

  group('an unreadable save refuses and changes nothing', () {
    test('a corrupt pair of slots blocks and leaves the bytes alone', () async {
      Session session = Session(root);
      final ReconciliationIdentity identity = await seedIdentity(session);
      final BootstrapNewGame started =
          await session.start(identity) as BootstrapNewGame;
      final GameEngine engine = started.engine;

      final SaveLoaded head =
          await session.repository.load(registry: registry) as SaveLoaded;
      final EngineResult r = engine.execute(
        const GrantSyntheticSteps(steps: 613, reason: 'walk'),
      );
      await commitBatch(
        session,
        engine.state,
        r.events,
        generation: head.generation,
        lastTransaction: head.lastAppliedTransaction,
      );

      session.layout.slotA.writeAsBytesSync(utf8.encode('not a save at all'));
      session.layout.slotB.writeAsBytesSync(<int>[0, 1, 2, 3, 4, 5]);

      final String before = imageOf(session.layout);

      // --- restart ---------------------------------------------------------
      session = Session(root);
      final BootstrapOutcome outcome = await session.start(identity);

      expect(
        outcome,
        isA<BootstrapBlocked>(),
        reason:
            'a save that exists and cannot be read must never become a new '
            'game — that is a successful launch onto a wiped character',
      );
      expect(
        (outcome as BootstrapBlocked).reason,
        BootstrapBlockReason.bothSlotsInvalid,
      );
      expect(
        imageOf(session.layout),
        before,
        reason: 'a refusal must not write, delete, or repair a single byte',
      );
    });
  });
}
