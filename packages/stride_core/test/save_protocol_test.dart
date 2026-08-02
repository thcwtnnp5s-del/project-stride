// The save protocol: encoding, slot selection, commit, and compare-and-swap.
//
// Quantities throughout are distinct and non-summing — 137, 291, 613 — so that
// a drop, a duplicate, and an off-by-one each produce a *distinguishable*
// total. Three records of 100, or two grants of 500, would let all three hide.

import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'save_support.dart';
import 'step_support.dart';

void main() {
  group('canonical encoding', () {
    test('a state round-trips byte-identically', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 613)], next: 'c1'),
      );
      engine.execute(const AllocateSteps(steps: 137));

      final Uint8List first = encodeSnapshot(
        state: engine.state,
        saveId: testSaveId,
        generation: 1,
        lastAppliedTransaction: 1,
      );

      final FrameResult framed = unframe(first);
      expect(framed.verified, isTrue);
      final SaveEnvelope envelope = decodeEnvelope(framed.payload!);

      final Uint8List second = encodeSnapshot(
        state: envelope.state,
        saveId: testSaveId,
        generation: 1,
        lastAppliedTransaction: 1,
      );

      // The assertion that fires the day someone adds a field to GameState
      // without thinking about saves — otherwise an entirely silent change
      // until a player's save fails to load in the field.
      expect(second, first);
      expect(envelope.state.signature, engine.state.signature);
    });

    test('object key order does not depend on insertion order', () {
      expect(
        canonicalJson(<String, Object?>{'b': 1, 'a': 2}),
        canonicalJson(<String, Object?>{'a': 2, 'b': 1}),
      );
    });

    test('a double is refused rather than silently written', () {
      // A step count that round-trips as 1.0 becomes a type error on load.
      expect(
        () => canonicalJson(<String, Object?>{'steps': 1.0}),
        throwsA(isA<SaveCodecException>()),
      );
    });

    test('an origin key survives the round trip exactly', () {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[
          obs(phone, 0, 291),
          obs(watch, 1, 613),
        ], next: 'c1'),
      );

      final SaveEnvelope envelope = decodeEnvelope(
        unframe(
          encodeSnapshot(
            state: engine.state,
            saveId: testSaveId,
            generation: 1,
            lastAppliedTransaction: 1,
          ),
        ).payload!,
      );

      final Set<StepOriginKey> origins = envelope.state.steps.grantedSlices.keys
          .map((ObservationKey k) => k.origin)
          .toSet();
      expect(origins, <StepOriginKey>{phone, watch});
      expect(
        envelope.state.steps.totalGranted,
        904,
        reason: 'a split or merged key would move this number',
      );
    });
  });

  group('commit and slot selection', () {
    test('the first commit writes slot a and is durable', () async {
      final (:SaveRepository repo, :FaultingDevice device) = newRepo();
      final GameEngine engine = newEngine();
      final EngineResult result = engine.execute(
        const GrantSyntheticSteps(steps: 613, reason: 'test'),
      );

      final CommitOutcome outcome = await commit(
        repo,
        after: engine.state,
        events: result.events,
        generation: -1,
        lastTransaction: 0,
      );

      expect(outcome, isA<CommitDurable>());
      final CommitDurable durable = outcome as CommitDurable;
      expect(durable.transactionId, 1);
      expect(durable.generation, 0);
      expect(durable.snapshotDurable, isTrue);
      expect(durable.retries, 0);

      // The journal is flushed before the snapshot is written. A test that
      // passes without any flush proves the harness is lossless.
      expect(device.flushCountFor('journal'), greaterThan(0));
    });

    test('commits alternate slots and never overwrite the live one', () async {
      final (:SaveRepository repo, :FaultingDevice device) = newRepo();
      final GameEngine engine = newEngine();

      final List<SnapshotSlot> written = <SnapshotSlot>[];
      int generation = -1;
      int transaction = 0;

      for (final int steps in <int>[137, 291, 613, 137]) {
        final EngineResult r = engine.execute(
          GrantSyntheticSteps(steps: steps, reason: 'g$steps'),
        );
        final CommitDurable d =
            await commit(
                  repo,
                  after: engine.state,
                  events: r.events,
                  generation: generation,
                  lastTransaction: transaction,
                )
                as CommitDurable;
        written.add(d.slot);
        generation = d.generation;
        transaction = d.transactionId;
      }

      expect(written, <SnapshotSlot>[
        SnapshotSlot.a,
        SnapshotSlot.b,
        SnapshotSlot.a,
        SnapshotSlot.b,
      ], reason: 'atomicity comes from never touching the live copy');
      expect(device.exists('save_slot_a'), isTrue);
      expect(device.exists('save_slot_b'), isTrue);
    });

    test('the highest generation wins on load', () async {
      final (:SaveRepository repo, :FaultingDevice device) = newRepo();
      final GameEngine engine = newEngine();

      int generation = -1;
      int transaction = 0;
      for (final int steps in <int>[137, 291, 613]) {
        final EngineResult r = engine.execute(
          GrantSyntheticSteps(steps: steps, reason: 'g$steps'),
        );
        final CommitDurable d =
            await commit(
                  repo,
                  after: engine.state,
                  events: r.events,
                  generation: generation,
                  lastTransaction: transaction,
                )
                as CommitDurable;
        generation = d.generation;
        transaction = d.transactionId;
      }

      final LoadOutcome outcome = await newRepo(
        device,
      ).repo.load(registry: saveRegistry);

      expect(outcome, isA<SaveLoaded>());
      final SaveLoaded loaded = outcome as SaveLoaded;
      expect(loaded.state.steps.totalGranted, 1041);
      expect(loaded.generation, 2);
      expect(loaded.replayedTransactions, 0);
    });

    test('no save at all is the only new-game path', () async {
      final SaveRepository repo = newRepo().repo;
      expect(await repo.load(registry: saveRegistry), isA<NoSaveFound>());
    });
  });

  group('compare-and-swap', () {
    test('a stale expectation is refused, and nothing is written', () async {
      final (:SaveRepository repo, :FaultingDevice device) = newRepo();
      final GameEngine engine = newEngine();

      final EngineResult first = engine.execute(
        const GrantSyntheticSteps(steps: 613, reason: 'first'),
      );
      await commit(
        repo,
        after: engine.state,
        events: first.events,
        generation: -1,
        lastTransaction: 0,
      );

      final String before = device.image();

      // A second writer that still believes the save is empty.
      final EngineResult second = engine.execute(
        const GrantSyntheticSteps(steps: 291, reason: 'stale'),
      );
      final CommitOutcome outcome = await commit(
        repo,
        after: engine.state,
        events: second.events,
        generation: -1,
        lastTransaction: 0,
      );

      expect(outcome, isA<CommitRefused>());
      expect(
        (outcome as CommitRefused).reason,
        CommitRefusal.conflictRetryLimitExhausted,
      );
      expect(
        device.image(),
        before,
        reason: 'a refused commit must not write anything at all',
      );
    });

    test('reloading after a conflict lets the retry succeed', () async {
      final (:SaveRepository repo, :FaultingDevice device) = newRepo();
      final GameEngine engine = newEngine();

      final EngineResult first = engine.execute(
        const GrantSyntheticSteps(steps: 613, reason: 'first'),
      );
      final CommitDurable durable =
          await commit(
                repo,
                after: engine.state,
                events: first.events,
                generation: -1,
                lastTransaction: 0,
              )
              as CommitDurable;

      final SaveLoaded reloaded =
          await repo.load(registry: saveRegistry) as SaveLoaded;

      final EngineResult second = engine.execute(
        const GrantSyntheticSteps(steps: 291, reason: 'after reload'),
      );
      final CommitOutcome retry = await commit(
        repo,
        after: engine.state,
        events: second.events,
        generation: reloaded.generation,
        lastTransaction: reloaded.lastAppliedTransaction,
      );

      expect(retry, isA<CommitDurable>());
      expect((retry as CommitDurable).transactionId, durable.transactionId + 1);

      final SaveLoaded finalLoad =
          await newRepo(device).repo.load(registry: saveRegistry) as SaveLoaded;
      expect(finalLoad.state.steps.totalGranted, 904);
    });

    test('overlapping commits are serialized, not interleaved', () async {
      final (:SaveRepository repo, :FaultingDevice device) = newRepo();
      final GameEngine engine = newEngine();

      final EngineResult a = engine.execute(
        const GrantSyntheticSteps(steps: 137, reason: 'a'),
      );
      final EngineResult b = engine.execute(
        const GrantSyntheticSteps(steps: 291, reason: 'b'),
      );

      // Both start from the same expectation. One must win and one must be
      // refused; a fork would leave two records at the same transaction.
      final List<CommitOutcome> outcomes =
          await Future.wait(<Future<CommitOutcome>>[
            commit(
              repo,
              after: engine.state,
              events: a.events,
              generation: -1,
              lastTransaction: 0,
            ),
            commit(
              repo,
              after: engine.state,
              events: b.events,
              generation: -1,
              lastTransaction: 0,
            ),
          ]);

      expect(outcomes.whereType<CommitDurable>().length, 1);
      expect(outcomes.whereType<CommitRefused>().length, 1);

      final LoadOutcome loaded = await newRepo(
        device,
      ).repo.load(registry: saveRegistry);
      expect(loaded, isA<SaveLoaded>());
      expect((loaded as SaveLoaded).repairs, isEmpty);
    });
  });
}
