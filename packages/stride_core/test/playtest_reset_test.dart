// The playtest reset (`DECISIONS/0025`): the one re-basing that is not a
// migration, and the proof that it moves a mark and nothing else.
//
// The owner's requirement, in their words: preserve the forward-only
// HealthKit cursor / watermark / dedupe safety; do not regrant old
// historical steps; do not break the accounting safety work; the
// player-facing progression baseline can reset, but the ingestion cursor
// must remain safe. Each line below is one of those, as an assertion.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

void main() {
  final ContentId node = ContentId.unchecked('resource_node.meadow_patch');

  /// A game that has walked three hours, spent some, and holds a cursor.
  GameEngine walked() {
    final GameEngine engine = newEngine();
    final EngineResult first = sync(
      engine,
      incremental(<StepObservation>[
        obs(phone, 0, 600),
        obs(phone, 1, 500),
        obs(watch, 1, 120),
      ], next: 'c1'),
    );
    expect(grantedBy(first), 1220);
    final EngineResult gathered = engine.execute(GatherResource(node: node));
    expect(gathered.isAccepted, isTrue, reason: '$gathered');
    return engine;
  }

  group('the baseline reset (freshStart: false)', () {
    test('banked and the walked figure start again; the counters do not', () {
      final GameEngine engine = walked();
      final StepLedger before = engine.state.steps;
      expect(before.banked, greaterThan(0));
      expect(before.walkedSinceBaseline, 1220);

      final EngineResult r = engine.execute(
        const ResetPlaytest(freshStart: false, stateVersion: 9),
      );
      expect(r.isAccepted, isTrue, reason: '$r');
      expect(r.events.single, isA<PlaytestReset>());

      final StepLedger after = engine.state.steps;
      // The mark moved.
      expect(after.banked, 0);
      expect(after.walkedSinceBaseline, 0);
      expect(after.epoch.grantedAtStart, before.totalGranted);
      expect(after.epoch.spentAtStart, before.totalSpent);
      expect(after.epoch.walkedAtStart, before.totalGranted);
      expect(after.epoch.establishedAtStateVersion, 9);
      // The counters did not (RULES.md H-2).
      expect(after.totalGranted, before.totalGranted);
      expect(after.totalSpent, before.totalSpent);
      expect(after.totalObserved, before.totalObserved);
      // The history that keeps a re-grant impossible did not (H-3, H-4).
      expect(after.checkpoint, before.checkpoint);
      expect(after.grantedSlices, before.grantedSlices);
      expect(after.grantedBeforeWatermark, before.grantedBeforeWatermark);
      expect(after.recovery, before.recovery);
      // The event reports what it retired, for the record.
      final PlaytestReset event = r.events.single as PlaytestReset;
      expect(event.retiredBanked, before.banked);
      expect(event.freshStart, isFalse);
    });

    test('the same history re-delivered after the reset grants nothing', () {
      final GameEngine engine = walked();
      engine.execute(const ResetPlaytest(freshStart: false, stateVersion: 9));

      // The adapter re-delivers the hours it already delivered — a Watch's
      // late batch, a replayed page, a rescan. Every one is already in the
      // slice map, so the ledger credits zero and the bank stays at zero.
      final EngineResult replay = sync(
        engine,
        incremental(<StepObservation>[
          obs(phone, 0, 600),
          obs(phone, 1, 500),
          obs(watch, 1, 120),
        ], next: 'c1'),
      );
      expect(grantedBy(replay), 0);
      expect(engine.state.steps.banked, 0);
      expect(engine.state.steps.walkedSinceBaseline, 0);

      final EngineResult rescanned = sync(
        engine,
        rescan(
          <StepObservation>[obs(phone, 0, 600), obs(phone, 1, 500)],
          fromIndex: 0,
          toIndex: 2,
          next: 'c2',
        ),
      );
      expect(grantedBy(rescanned), 0);
      expect(engine.state.steps.banked, 0);
    });

    test('new walking after the reset is credited once and is spendable', () {
      final GameEngine engine = walked();
      engine.execute(const ResetPlaytest(freshStart: false, stateVersion: 9));

      final EngineResult fresh = sync(
        engine,
        incremental(<StepObservation>[obs(phone, 2, 800)], next: 'c2'),
      );
      expect(grantedBy(fresh), 800);
      expect(engine.state.steps.banked, 800);
      expect(engine.state.steps.walkedSinceBaseline, 800);
      expect(engine.state.steps.totalGranted, 1220 + 800);

      final EngineResult again = sync(
        engine,
        incremental(<StepObservation>[obs(phone, 2, 800)], next: 'c3'),
      );
      expect(grantedBy(again), 0, reason: 'once, never twice');
      expect(engine.state.steps.banked, 800);
    });

    test('the bag, the gear and the world are untouched', () {
      final GameEngine engine = walked();
      final GameState before = engine.state;
      engine.execute(const ResetPlaytest(freshStart: false, stateVersion: 9));
      final GameState after = engine.state;
      expect(after.inventory.counts, before.inventory.counts);
      expect(after.equipment.bySlot, before.equipment.bySlot);
      expect(after.skills.experienceBySkill, before.skills.experienceBySkill);
      expect(after.world.currentLocation, before.world.currentLocation);
      expect(after.player, before.player);
      expect(after.progress, before.progress);
    });

    test('it may run again — each run is a deliberate act', () {
      final GameEngine engine = walked();
      engine.execute(const ResetPlaytest(freshStart: false, stateVersion: 9));
      sync(engine, incremental(<StepObservation>[obs(phone, 2, 300)]));
      expect(engine.state.steps.banked, 300);
      final EngineResult second = engine.execute(
        const ResetPlaytest(freshStart: false, stateVersion: 9),
      );
      expect(second.isAccepted, isTrue, reason: '$second');
      expect(engine.state.steps.banked, 0);
      expect(engine.state.steps.totalGranted, 1520);
    });

    test('a fight in progress refuses the baseline-only reset', () {
      final GameEngine engine = newEngine();
      sync(engine, incremental(<StepObservation>[obs(phone, 0, 5000)]));
      final ContentId woods = ContentId.unchecked('location.whispering_woods');
      final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
      final ContentId sword = ContentId.unchecked('item.training_sword');
      expect(engine.execute(EquipItem(item: sword)).isAccepted, isTrue);
      expect(engine.execute(TravelTo(destination: woods)).isAccepted, isTrue);
      final EngineResult started = engine.execute(StartEncounter(enemy: wolf));
      expect(started.isAccepted, isTrue, reason: '$started');

      final EngineResult refused = engine.execute(
        const ResetPlaytest(freshStart: false, stateVersion: 9),
      );
      expect(refused.isAccepted, isFalse);
      expect(
        refused.rejection!.code,
        RejectionCode.encounterInProgress,
      );
      expect(identical(engine.state, started.state), isTrue);
    });
  });

  group('the fresh start (freshStart: true)', () {
    test('the game begins again on top of the untouched ledger', () {
      final GameEngine engine = walked();
      final StepLedger ledgerBefore = engine.state.steps;
      expect(engine.state.inventory.counts, isNotEmpty);

      final EngineResult r = engine.execute(
        const ResetPlaytest(freshStart: true, stateVersion: 9),
      );
      expect(r.isAccepted, isTrue, reason: '$r');
      final GameState after = engine.state;

      // The new-game shape: the starting loadout, nothing worn, every
      // skill at zero, the start location only, a fresh character, an
      // empty progression block, no fight, no queue.
      final GameEngine fresh = newEngine();
      expect(after.inventory.counts, fresh.state.inventory.counts);
      expect(after.equipment.bySlot, isEmpty);
      expect(after.skills.experienceBySkill, fresh.state.skills.experienceBySkill);
      expect(after.world.currentLocation, fresh.state.world.currentLocation);
      expect(after.world.unlockedLocations, fresh.state.world.unlockedLocations);
      expect(after.player, fresh.state.player);
      expect(after.progress, ProgressState.initial());
      expect(after.encounter, isNull);
      expect(after.activityQueue, isNull);

      // The ledger: the mark moved, nothing else.
      expect(after.steps.banked, 0);
      expect(after.steps.walkedSinceBaseline, 0);
      expect(after.steps.totalGranted, ledgerBefore.totalGranted);
      expect(after.steps.totalSpent, ledgerBefore.totalSpent);
      expect(after.steps.checkpoint, ledgerBefore.checkpoint);
      expect(after.steps.grantedSlices, ledgerBefore.grantedSlices);

      // And the event sequence kept counting: a reset is an event in the
      // transcript, not a new transcript.
      expect(after.eventSequence, greaterThan(0));
    });

    test('a fresh start discards a fight in progress', () {
      final GameEngine engine = newEngine();
      sync(engine, incremental(<StepObservation>[obs(phone, 0, 5000)]));
      final ContentId woods = ContentId.unchecked('location.whispering_woods');
      final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
      final ContentId sword = ContentId.unchecked('item.training_sword');
      engine.execute(EquipItem(item: sword));
      engine.execute(TravelTo(destination: woods));
      expect(engine.execute(StartEncounter(enemy: wolf)).isAccepted, isTrue);

      final EngineResult r = engine.execute(
        const ResetPlaytest(freshStart: true, stateVersion: 9),
      );
      expect(r.isAccepted, isTrue, reason: '$r');
      expect(engine.state.encounter, isNull);
      expect(
        engine.state.world.currentLocation,
        ContentId.unchecked('location.havens_rest'),
      );
    });
  });

  test('the event survives the journal codec', () {
    final GameEngine engine = walked();
    final EngineResult r = engine.execute(
      const ResetPlaytest(freshStart: true, stateVersion: 9),
    );
    final PlaytestReset event = r.events.single as PlaytestReset;
    final GameEvent? back = decodeEvent(encodeEvent(event));
    expect(back, isA<PlaytestReset>());
    final PlaytestReset decoded = back! as PlaytestReset;
    expect(decoded.sequence, event.sequence);
    expect(decoded.grantedAtStart, event.grantedAtStart);
    expect(decoded.spentAtStart, event.spentAtStart);
    expect(decoded.previousGrantedAtStart, event.previousGrantedAtStart);
    expect(decoded.previousSpentAtStart, event.previousSpentAtStart);
    expect(decoded.previousWalkedAtStart, event.previousWalkedAtStart);
    expect(decoded.stateVersion, 9);
    expect(decoded.freshStart, isTrue);
    expect(decoded.startLocation, event.startLocation);
    expect(decoded.grantedItems, event.grantedItems);
  });
}
