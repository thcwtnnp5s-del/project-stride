// The save protocol: encoding, slot selection, commit, and compare-and-swap.
//
// Quantities throughout are distinct and non-summing — 137, 291, 613 — so that
// a drop, a duplicate, and an off-by-one each produce a *distinguishable*
// total. Three records of 100, or two grants of 500, would let all three hide.

import 'dart:convert';
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
        originSaltFingerprint: null,
      );

      final FrameResult framed = unframe(first);
      expect(framed.verified, isTrue);
      final SaveEnvelope envelope = decodeEnvelope(framed.payload!);

      final Uint8List second = encodeSnapshot(
        state: envelope.state,
        saveId: testSaveId,
        generation: 1,
        lastAppliedTransaction: 1,
        originSaltFingerprint: null,
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
            originSaltFingerprint: null,
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

  _saltRefusal();
  _watermarkPersistence();
  _saltReachesTheSnapshot();
}

// The origin pseudonymization salt, and what happens when it changes.
//
// Wired in response to two sub-agent findings: LoadRefusal.originKeyReset was
// declared and never produced, while DECISIONS/0012 and the completion report
// both described it as implemented. Documented-but-absent is worse than either
// alone, because a reviewer reads it as a safeguard that exists.
void _saltRefusal() {
  group('origin salt', () {
    Future<Uint8List> savedWith(String? fingerprint) async {
      final GameEngine engine = newEngine();
      sync(
        engine,
        incremental(<StepObservation>[obs(phone, 0, 613)], next: 'c1'),
      );
      return encodeSnapshot(
        state: engine.state,
        saveId: testSaveId,
        generation: 0,
        lastAppliedTransaction: 1,
        originSaltFingerprint: fingerprint,
      );
    }

    Future<LoadOutcome> loadWith(Uint8List slot, String? current) async {
      final FaultingDevice device = FaultingDevice()..seed('save_slot_a', slot);
      return newRepo(
        device,
      ).repo.load(registry: saveRegistry, originSaltFingerprint: current);
    }

    test('a changed salt fails closed', () async {
      // Every origin re-keys, so the live retention window would be granted a
      // second time. Nothing downstream would ever detect that.
      final LoadOutcome outcome = await loadWith(
        await savedWith('aaaaaaaaaaaaaaaa'),
        'bbbbbbbbbbbbbbbb',
      );

      expect(outcome, isA<LoadRefused>());
      expect((outcome as LoadRefused).reason, LoadRefusal.originKeyReset);
    });

    test('the refusal names neither fingerprint', () async {
      // Both are derived from health-source identity, and this string reaches
      // a diagnostic surface.
      final LoadRefused refused =
          await loadWith(
                await savedWith('aaaaaaaaaaaaaaaa'),
                'bbbbbbbbbbbbbbbb',
              )
              as LoadRefused;

      expect(refused.explanation, isNot(contains('aaaaaaaaaaaaaaaa')));
      expect(refused.explanation, isNot(contains('bbbbbbbbbbbbbbbb')));
      expect(
        refused.explanation,
        contains('Reconnect health'),
        reason: 'a fail-closed refusal must name the way out of it',
      );
    });

    test('a matching salt loads normally', () async {
      final LoadOutcome outcome = await loadWith(
        await savedWith('aaaaaaaaaaaaaaaa'),
        'aaaaaaaaaaaaaaaa',
      );

      expect(outcome, isA<SaveLoaded>());
      expect((outcome as SaveLoaded).state.steps.totalGranted, 613);
    });

    test('a save with no salt has no origins to re-key', () async {
      // Written before any health source was read. There is nothing to refuse.
      final LoadOutcome outcome = await loadWith(
        await savedWith(null),
        'bbbbbbbbbbbbbbbb',
      );

      expect(outcome, isA<SaveLoaded>());
    });

    test('the fingerprint is omitted, not written as null', () async {
      // An explicit null would mean "deliberately nothing", which is not what
      // absence means here -- and omitting it keeps saves written before the
      // field existed byte-identical, which the frozen v1 fixture depends on.
      final String text = utf8.decode(unframe(await savedWith(null)).payload!);
      expect(text, isNot(contains('originSaltFingerprint')));

      final String withSalt = utf8.decode(
        unframe(await savedWith('aaaaaaaaaaaaaaaa')).payload!,
      );
      expect(withSalt, contains('originSaltFingerprint'));
    });
  });
}

// Per-origin watermarks must survive a reload.
//
// Without this the save layer silently double-grants: every origin comes back
// unsettled, so the whole live retention window is granted a second time on the
// next sync. F-04's arithmetic cannot save it, because the record it consults
// is exactly the one that was dropped.
void _watermarkPersistence() {
  group('origin watermarks survive a reload', () {
    test('a settled origin stays settled across a restart', () async {
      final (:SaveRepository repo, :FaultingDevice device) = newRepo();
      final GameEngine engine = newEngine();

      int generation = -1;
      int transaction = 0;
      for (int day = 0; day < 14; day++) {
        final EngineResult r = engine.execute(
          ReconcileStepSync(
            response: incremental(
              <StepObservation>[obs(phone, day * 24, 1000)],
              next: 'd$day',
              completeThroughIndex: day * 24 + 1,
            ),
          ),
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

      final Map<StepOriginKey, int> before =
          engine.state.steps.checkpoint.originWatermarks;
      expect(before, isNotEmpty, reason: 'the fixture must actually compact');
      expect(engine.state.steps.totalGranted, 14000);

      // Restart from the durable bytes alone.
      final SaveLoaded loaded =
          await newRepo(device).repo.load(registry: saveRegistry) as SaveLoaded;

      expect(
        loaded.state.steps.checkpoint.originWatermarks,
        before,
        reason: 'a dropped watermark map re-grants the whole retention window',
      );

      // The proof that matters: replay an already-settled bucket after the
      // restart and confirm it grants nothing.
      final GameEngine resumed = GameEngine(
        registry: saveRegistry,
        state: loaded.state,
      );
      expect(
        grantedBy(
          sync(
            resumed,
            incremental(<StepObservation>[obs(phone, 0, 1000)], next: 'again'),
          ),
        ),
        0,
      );
      expect(resumed.state.steps.totalGranted, 14000);
    });
  });
}

// The salt fingerprint must reach the snapshot through commit().
//
// It did not. `encodeSnapshot` took the fingerprint as an OPTIONAL parameter,
// `SaveRepository.commit` had no such parameter at all, and the call site
// simply omitted it — so every snapshot the protocol has ever written recorded
// no fingerprint, `_checkSalt` found null on load, and the fail-closed refusal
// could never fire.
//
// The F-05 salt tests passed throughout, because they seeded slot bytes by
// calling `encodeSnapshot` directly with a fingerprint. They proved the *load*
// path and never touched the *commit* path.
//
// Found by the F-06 Technical Critic. It is the second inert fix this
// milestone; the first was LG-3. Both had passing tests that exercised
// everything except the thing that was broken.
void _saltReachesTheSnapshot() {
  group('the salt fingerprint survives a real commit', () {
    test('a committed snapshot records the fingerprint', () async {
      final (:SaveRepository repo, :FaultingDevice device) = newRepo();
      final GameEngine engine = newEngine();
      final EngineResult r = engine.execute(
        const GrantSyntheticSteps(steps: 613, reason: 'salt'),
      );

      await commit(
        repo,
        after: engine.state,
        events: r.events,
        generation: -1,
        lastTransaction: 0,
        saltFingerprint: 'aaaaaaaaaaaaaaaa',
      );

      // Read the bytes the protocol actually wrote, not bytes a test built.
      final SaveEnvelope envelope = decodeEnvelope(
        unframe(device.committedBytes('save_slot_a')!).payload!,
      );
      expect(
        envelope.originSaltFingerprint,
        'aaaaaaaaaaaaaaaa',
        reason:
            'a snapshot with no fingerprint makes the salt check dead code, '
            'and a re-keyed origin then re-grants the retention window',
      );
    });

    test('a changed salt then fails closed, end to end', () async {
      final (:SaveRepository repo, :FaultingDevice device) = newRepo();
      final GameEngine engine = newEngine();
      final EngineResult r = engine.execute(
        const GrantSyntheticSteps(steps: 613, reason: 'salt'),
      );
      await commit(
        repo,
        after: engine.state,
        events: r.events,
        generation: -1,
        lastTransaction: 0,
        saltFingerprint: 'aaaaaaaaaaaaaaaa',
      );

      final LoadOutcome outcome = await newRepo(device).repo.load(
        registry: saveRegistry,
        originSaltFingerprint: 'bbbbbbbbbbbbbbbb',
      );

      expect(outcome, isA<LoadRefused>());
      expect((outcome as LoadRefused).reason, LoadRefusal.originKeyReset);
    });

    test('the matching salt still loads', () async {
      final (:SaveRepository repo, :FaultingDevice device) = newRepo();
      final GameEngine engine = newEngine();
      final EngineResult r = engine.execute(
        const GrantSyntheticSteps(steps: 613, reason: 'salt'),
      );
      await commit(
        repo,
        after: engine.state,
        events: r.events,
        generation: -1,
        lastTransaction: 0,
        saltFingerprint: 'aaaaaaaaaaaaaaaa',
      );

      final LoadOutcome outcome = await newRepo(device).repo.load(
        registry: saveRegistry,
        originSaltFingerprint: 'aaaaaaaaaaaaaaaa',
      );
      expect(outcome, isA<SaveLoaded>());
      expect((outcome as SaveLoaded).state.steps.totalGranted, 613);
    });
  });
}
