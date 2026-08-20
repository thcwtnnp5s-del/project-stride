// The finite activity queue (`DECISIONS/0022`): durable, wall-clock-anchored,
// and exactly-once by commit.
//
// Every timestamp here is data carried in on a command — the engine reads no
// clock, so a "five minutes in the pocket" case is a literal, not a sleep.
// The §38 correction-brief scenarios are proven at engine level here;
// `test/activity_controller_test.dart` at the root proves the same semantics
// through the app's controller and real persistence.

import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

final ContentId meadow = ContentId.unchecked('resource_node.meadow_patch');
final ContentId oakStand = ContentId.unchecked('resource_node.oak_stand');
final ContentId herb = ContentId.unchecked('item.meadow_herb');
final ContentId foraging = ContentId.unchecked('skill.foraging');
final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId trainingAxe = ContentId.unchecked('item.training_axe');

/// One repetition's authored duration for these tests, in milliseconds.
const int dur = 10000;

/// The queue's wall-clock birth. An arbitrary epoch instant; only differences
/// matter, and the backward-clock case subtracts from it.
const int t0 = 1750000000000;

GameEngine engineWith(int banked) {
  final GameEngine engine = newEngine();
  if (banked > 0) {
    engine.execute(GrantSyntheticSteps(steps: banked, reason: 'test'));
  }
  return engine;
}

StartActivityQueue start({int requested = 5, int now = t0}) =>
    StartActivityQueue(
      node: meadow,
      requested: requested,
      durationMillis: dur,
      nowEpochMillis: now,
    );

void main() {
  final ContentRegistry registry = stepRegistry;
  final int cost = registry.profile.applyStepCost(
    registry.resourceNodes[meadow]!.stepCost,
  );
  final int yield_ = registry.profile.applyYield(
    registry.resourceNodes[meadow]!.yieldsQuantity,
  );
  final int xp = registry.profile.applyXp(registry.resourceNodes[meadow]!.xp);

  group('StartActivityQueue — refusals, and what starting does not do', () {
    test('an unknown node is refused and changes nothing', () {
      final GameEngine engine = engineWith(10000);
      final GameState before = engine.state;

      final EngineResult result = engine.execute(
        StartActivityQueue(
          node: ContentId.unchecked('resource_node.nowhere'),
          requested: 1,
          durationMillis: dur,
          nowEpochMillis: t0,
        ),
      );

      expect(result.rejection!.code, RejectionCode.unknownResourceNode);
      expect(identical(engine.state, before), isTrue);
    });

    test('a node somewhere else is refused', () {
      final GameEngine engine = engineWith(10000);
      final EngineResult result = engine.execute(
        StartActivityQueue(
          node: oakStand,
          requested: 1,
          durationMillis: dur,
          nowEpochMillis: t0,
        ),
      );
      expect(result.rejection!.code, RejectionCode.resourceNodeNotHere);
    });

    test('fewer than one repetition is refused', () {
      final GameEngine engine = engineWith(10000);
      expect(
        engine.execute(start(requested: 0)).rejection!.code,
        RejectionCode.invalidAmount,
      );
    });

    test('a second queue is refused while one runs', () {
      final GameEngine engine = engineWith(10000);
      expect(engine.execute(start()).isAccepted, isTrue);
      expect(
        engine.execute(start()).rejection!.code,
        RejectionCode.activityQueueActive,
      );
    });

    test('starting during an encounter is refused', () {
      final GameEngine engine = engineWith(10000);
      engine.execute(UnlockLocation(location: woods));
      engine.execute(EnterLocation(location: woods));
      expect(engine.execute(StartEncounter(enemy: wolf)).isAccepted, isTrue);

      final EngineResult result = engine.execute(
        StartActivityQueue(
          node: oakStand,
          requested: 1,
          durationMillis: dur,
          nowEpochMillis: t0,
        ),
      );
      expect(result.rejection!.code, RejectionCode.encounterInProgress);
    });

    test('the gather prerequisites gate the start — a tool in the bag is not '
        'a tool in hand', () {
      // Oak Stand needs an axe equipped; the starting loadout only *owns* one.
      final GameEngine engine = engineWith(10000);
      engine.execute(UnlockLocation(location: woods));
      engine.execute(EnterLocation(location: woods));

      final EngineResult refused = engine.execute(
        StartActivityQueue(
          node: oakStand,
          requested: 1,
          durationMillis: dur,
          nowEpochMillis: t0,
        ),
      );
      expect(refused.rejection!.code, RejectionCode.toolRequired);

      engine.execute(EquipItem(item: trainingAxe));
      expect(
        engine
            .execute(
              StartActivityQueue(
                node: oakStand,
                requested: 1,
                durationMillis: dur,
                nowEpochMillis: t0,
              ),
            )
            .isAccepted,
        isTrue,
      );
    });

    test('starting pre-spends nothing — a zero balance may still queue', () {
      // `DECISIONS/0022` §3: every completion pays at its own reconciliation.
      // A player who queues before walking simply finds the queue stopped at
      // the first completion the balance cannot fund.
      final GameEngine engine = engineWith(0);

      final EngineResult result = engine.execute(start(requested: 3));

      expect(result.isAccepted, isTrue);
      expect(engine.state.steps.totalSpent, 0);
      expect(engine.state.activityQueue, isA<ActivityQueueState>());
      final ActivityQueueState queue = engine.state.activityQueue!;
      expect(queue.node, meadow);
      expect(queue.requested, 3);
      expect(queue.completed, 0);
      expect(queue.durationMillis, dur);
      expect(queue.anchorEpochMillis, t0);
    });
  });

  group('ReconcileActivityQueue — the §38 arithmetic', () {
    test('with no queue it is a no-op success: no events, no commit', () {
      final GameEngine engine = engineWith(1000);
      final GameState before = engine.state;

      final EngineResult result = engine.execute(
        const ReconcileActivityQueue(nowEpochMillis: t0),
      );

      expect(result.isAccepted, isTrue);
      expect(result.events, isEmpty);
      expect(identical(engine.state, before), isTrue);
    });

    test('less than one repetition elapsed completes nothing', () {
      final GameEngine engine = engineWith(1000)..execute(start());
      final GameState before = engine.state;

      final EngineResult result = engine.execute(
        const ReconcileActivityQueue(nowEpochMillis: t0 + dur - 1),
      );

      expect(result.isAccepted, isTrue);
      expect(result.events, isEmpty);
      expect(identical(engine.state, before), isTrue);
      expect(engine.state.activityQueue!.anchorEpochMillis, t0);
    });

    test('crossing one boundary completes exactly one repetition', () {
      final GameEngine engine = engineWith(1000)..execute(start());

      final EngineResult result = engine.execute(
        const ReconcileActivityQueue(nowEpochMillis: t0 + dur + 1500),
      );

      expect(result.isAccepted, isTrue);
      final ActivityQueueReconciled event =
          result.events.single as ActivityQueueReconciled;
      expect(event.completions, hasLength(1));
      expect(event.completions.single.stepsSpent, cost);
      expect(event.completions.single.item, herb);
      expect(event.completions.single.quantity, yield_);
      expect(event.completions.single.skill, foraging);
      expect(event.completions.single.experience, xp);
      expect(event.completedAfter, 1);
      expect(event.anchorAfter, t0 + dur);
      expect(event.cleared, isFalse);
      expect(event.stopReason, isNull);

      expect(engine.state.steps.totalSpent, cost);
      expect(engine.state.inventory.quantityOf(herb), yield_);
      expect(engine.state.skills.experienceIn(foraging), xp);
      expect(engine.state.activityQueue!.completed, 1);
      expect(engine.state.activityQueue!.anchorEpochMillis, t0 + dur);
    });

    test('a second reconcile at the same instant is a no-op — exactly-once '
        'by commit, not by clock', () {
      final GameEngine engine = engineWith(1000)..execute(start());
      engine.execute(const ReconcileActivityQueue(nowEpochMillis: t0 + dur));
      final GameState before = engine.state;

      final EngineResult again = engine.execute(
        const ReconcileActivityQueue(nowEpochMillis: t0 + dur),
      );

      expect(again.isAccepted, isTrue);
      expect(again.events, isEmpty);
      expect(identical(engine.state, before), isTrue);
      expect(engine.state.steps.totalSpent, cost, reason: 'still one spend');
    });

    test('crossing N boundaries completes exactly N', () {
      final GameEngine engine = engineWith(1000)..execute(start());

      final EngineResult result = engine.execute(
        // Three and a half repetitions: the half commits nothing.
        ReconcileActivityQueue(nowEpochMillis: t0 + 3 * dur + dur ~/ 2),
      );

      final ActivityQueueReconciled event =
          result.events.single as ActivityQueueReconciled;
      expect(event.completions, hasLength(3));
      expect(event.anchorAfter, t0 + 3 * dur);
      expect(event.cleared, isFalse);
      expect(engine.state.steps.totalSpent, 3 * cost);
      expect(engine.state.inventory.quantityOf(herb), 3 * yield_);
      expect(engine.state.activityQueue!.completed, 3);
    });

    test('time beyond the whole queue caps at the requested count and '
        'clears the queue', () {
      final GameEngine engine = engineWith(1000)..execute(start(requested: 3));

      final EngineResult result = engine.execute(
        // An hour in the pocket against a three-repetition queue.
        const ReconcileActivityQueue(nowEpochMillis: t0 + 3600000),
      );

      final ActivityQueueReconciled event =
          result.events.single as ActivityQueueReconciled;
      expect(event.completions, hasLength(3), reason: 'capped at requested');
      expect(event.completedAfter, 3);
      expect(event.cleared, isTrue);
      expect(event.stopReason, isNull);
      expect(engine.state.activityQueue, isNull);
      expect(engine.state.steps.totalSpent, 3 * cost);

      // And nothing further accrues, ever: the queue is gone.
      final EngineResult later = engine.execute(
        const ReconcileActivityQueue(nowEpochMillis: t0 + 7200000),
      );
      expect(later.events, isEmpty);
      expect(engine.state.steps.totalSpent, 3 * cost);
    });

    test('a backward clock completes nothing and leaves the anchor exactly '
        'where it was', () {
      final GameEngine engine = engineWith(1000)..execute(start());
      final GameState before = engine.state;

      final EngineResult result = engine.execute(
        const ReconcileActivityQueue(nowEpochMillis: t0 - 3600000),
      );

      expect(result.isAccepted, isTrue);
      expect(result.events, isEmpty);
      expect(identical(engine.state, before), isTrue);
      expect(
        engine.state.activityQueue!.anchorEpochMillis,
        t0,
        reason:
            'moving the anchor on a backward clock would eat the progress the '
            'player already banked toward the current repetition',
      );

      // The clock recovering resumes exactly where the queue left off.
      final EngineResult recovered = engine.execute(
        const ReconcileActivityQueue(nowEpochMillis: t0 + dur),
      );
      expect(
        (recovered.events.single as ActivityQueueReconciled).completions,
        hasLength(1),
      );
    });

    test('insufficient banked steps stops the queue at the last affordable '
        'completion, with the reason, and no negative balance', () {
      // Funds exactly two completions with 70 left over.
      final GameEngine engine = engineWith(2 * cost + 70)..execute(start());

      final EngineResult result = engine.execute(
        const ReconcileActivityQueue(nowEpochMillis: t0 + 5 * dur),
      );

      final ActivityQueueReconciled event =
          result.events.single as ActivityQueueReconciled;
      expect(event.completions, hasLength(2));
      expect(event.completedAfter, 2);
      expect(event.cleared, isTrue);
      expect(event.stopReason, 'insufficient_steps');
      expect(engine.state.activityQueue, isNull);
      expect(engine.state.steps.banked, 70, reason: 'never negative');
      expect(engine.state.inventory.quantityOf(herb), 2 * yield_);
    });

    test('a prerequisite that became invalid stops the queue before the '
        'invalid completion, keeping every prior one', () {
      // An oak queue whose axe is unequipped after one committed repetition.
      final GameEngine engine = engineWith(100000);
      engine.execute(UnlockLocation(location: woods));
      engine.execute(EnterLocation(location: woods));
      engine.execute(EquipItem(item: trainingAxe));
      engine.execute(
        StartActivityQueue(
          node: oakStand,
          requested: 5,
          durationMillis: dur,
          nowEpochMillis: t0,
        ),
      );
      engine.execute(const ReconcileActivityQueue(nowEpochMillis: t0 + dur));
      expect(engine.state.activityQueue!.completed, 1);
      final int spentAfterOne = engine.state.steps.totalSpent;

      engine.execute(const UnequipItem(slot: EquipmentSlot.tool));
      final EngineResult result = engine.execute(
        const ReconcileActivityQueue(nowEpochMillis: t0 + 4 * dur),
      );

      final ActivityQueueReconciled event =
          result.events.single as ActivityQueueReconciled;
      expect(event.completions, isEmpty, reason: 'the first candidate refused');
      expect(event.completedAfter, 1, reason: 'the prior completion is kept');
      expect(event.cleared, isTrue);
      expect(event.stopReason, 'tool_required');
      expect(engine.state.activityQueue, isNull);
      expect(engine.state.steps.totalSpent, spentAfterOne);
    });

    test('an encounter that began mid-queue refuses the completion, with '
        'the truthful reason', () {
      final GameEngine engine = engineWith(100000);
      engine.execute(UnlockLocation(location: woods));
      engine.execute(EnterLocation(location: woods));
      engine.execute(EquipItem(item: trainingAxe));
      engine.execute(
        StartActivityQueue(
          node: oakStand,
          requested: 3,
          durationMillis: dur,
          nowEpochMillis: t0,
        ),
      );
      engine.execute(StartEncounter(enemy: wolf));

      final EngineResult result = engine.execute(
        const ReconcileActivityQueue(nowEpochMillis: t0 + dur),
      );

      final ActivityQueueReconciled event =
          result.events.single as ActivityQueueReconciled;
      expect(event.completions, isEmpty);
      expect(event.cleared, isTrue);
      expect(event.stopReason, 'encounter_in_progress');
    });

    test('a queue of completions is byte-identical, ledger and inventory, to '
        'the same number of manual gathers — one shared path', () {
      // The no-divergence claim of `DECISIONS/0022` §6, asserted as an
      // equivalence rather than trusted to a refactor.
      final GameEngine queued = engineWith(1000)..execute(start());
      queued.execute(
        const ReconcileActivityQueue(nowEpochMillis: t0 + 3 * dur),
      );

      final GameEngine manual = engineWith(1000);
      for (int i = 0; i < 3; i++) {
        expect(manual.execute(GatherResource(node: meadow)).isAccepted, isTrue);
      }

      expect(
        canonicalDurableStepLedger(queued.state.steps),
        canonicalDurableStepLedger(manual.state.steps),
      );
      expect(queued.state.inventory, manual.state.inventory);
      expect(queued.state.skills, manual.state.skills);
    });
  });

  group('StopActivityQueue — reconcile first, then clear regardless', () {
    test('with no queue it is a no-op success, so the exclusive-command seam '
        'may issue it unconditionally', () {
      final GameEngine engine = engineWith(1000);
      final GameState before = engine.state;

      final EngineResult result = engine.execute(
        const StopActivityQueue(nowEpochMillis: t0),
      );

      expect(result.isAccepted, isTrue);
      expect(result.events, isEmpty);
      expect(identical(engine.state, before), isTrue);
    });

    test('stop at 27 s of a 10 s × 5 queue commits exactly 2, discards the '
        'partial, and clears the queue', () {
      final GameEngine engine = engineWith(1000)..execute(start());

      final EngineResult result = engine.execute(
        const StopActivityQueue(nowEpochMillis: t0 + 27000),
      );

      final ActivityQueueStopped event =
          result.events.single as ActivityQueueStopped;
      expect(event.completions, hasLength(2));
      expect(event.completedAfter, 2);
      expect(event.stopReason, isNull);
      expect(engine.state.activityQueue, isNull);
      expect(engine.state.steps.totalSpent, 2 * cost);
      expect(engine.state.inventory.quantityOf(herb), 2 * yield_);

      // Nothing left to reconcile: the partial third bought nothing and owes
      // nothing.
      final EngineResult later = engine.execute(
        const ReconcileActivityQueue(nowEpochMillis: t0 + 3600000),
      );
      expect(later.events, isEmpty);
      expect(engine.state.steps.totalSpent, 2 * cost);
    });

    test('stop before the first boundary commits nothing and clears', () {
      final GameEngine engine = engineWith(1000)..execute(start());

      final EngineResult result = engine.execute(
        const StopActivityQueue(nowEpochMillis: t0 + 5000),
      );

      final ActivityQueueStopped event =
          result.events.single as ActivityQueueStopped;
      expect(event.completions, isEmpty);
      expect(event.completedAfter, 0);
      expect(engine.state.activityQueue, isNull);
      expect(engine.state.steps.totalSpent, 0);
    });
  });

  group('durability — the queue survives the codecs', () {
    test('a state with an active queue round-trips through the snapshot '
        'codec byte-identically', () {
      final GameEngine engine = engineWith(1000)..execute(start());
      engine.execute(const ReconcileActivityQueue(nowEpochMillis: t0 + dur));
      final GameState state = engine.state;
      expect(state.activityQueue, isNotNull);

      final Uint8List bytes = encodeSnapshot(
        state: state,
        saveId: 'queue-round-trip',
        generation: 1,
        lastAppliedTransaction: 1,
        originSaltFingerprint: null,
      );
      final SaveEnvelope decoded = decodeEnvelope(unframe(bytes).payload!);

      expect(decoded.state.activityQueue, state.activityQueue);
      expect(
        canonicalDurableGameState(decoded.state),
        canonicalDurableGameState(state),
      );
    });

    test('the three queue events round-trip through the journal codec', () {
      final List<GameEvent> events = <GameEvent>[
        ActivityQueueStarted(
          sequence: 7,
          node: meadow,
          requested: 5,
          durationMillis: dur,
          anchorEpochMillis: t0,
        ),
        ActivityQueueReconciled(
          sequence: 8,
          node: meadow,
          completions: <ActivityCompletion>[
            ActivityCompletion(
              stepsSpent: cost,
              item: herb,
              quantity: yield_,
              skill: foraging,
              experience: xp,
            ),
          ],
          completedAfter: 1,
          anchorAfter: t0 + dur,
          cleared: false,
        ),
        ActivityQueueStopped(
          sequence: 9,
          node: meadow,
          completions: const <ActivityCompletion>[],
          completedAfter: 1,
          stopReason: 'insufficient_steps',
        ),
      ];

      for (final GameEvent event in events) {
        final GameEvent? decoded = decodeEvent(encodeEvent(event));
        expect(decoded, isNotNull, reason: event.name);
        expect(decoded!.name, event.name);
        expect(encodeEvent(decoded), encodeEvent(event), reason: event.name);
      }
    });

    test('replaying the committed queue events reproduces the state', () {
      // The reducer half of exactly-once: the same events applied to the same
      // starting state land on the same figures, with no clock anywhere.
      final GameEngine live = engineWith(1000);
      final GameState genesis = live.state;
      final List<GameEvent> journal = <GameEvent>[
        ...live.execute(start()).events,
        ...live
            .execute(const ReconcileActivityQueue(nowEpochMillis: t0 + 2 * dur))
            .events,
        ...live
            .execute(const StopActivityQueue(nowEpochMillis: t0 + 3 * dur + 1))
            .events,
      ];

      const EventReducer reducer = EventReducer();
      final GameState replayed = reducer.applyAll(genesis, journal);

      expect(
        canonicalDurableGameState(replayed),
        canonicalDurableGameState(live.state),
      );
      expect(replayed.activityQueue, isNull);
      expect(replayed.steps.totalSpent, 3 * cost);
    });
  });
}
