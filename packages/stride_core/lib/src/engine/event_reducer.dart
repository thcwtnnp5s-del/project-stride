import '../content/content_id.dart';

import '../steps/step_ledger.dart';

import 'events.dart';
import 'game_state.dart';

/// The one place state changes.
///
/// ## Canonical
///
/// Every accepted change in the game passes through here. Nothing else mutates
/// state; nothing else is allowed to. The engine validates and *decides*, then
/// hands events to this reducer and takes back a new state.
///
/// The alternative — changing state in a command handler and emitting an event
/// afterwards for logging — looks equivalent and is not. It produces two
/// implementations of every rule: the one that runs, and the one replay uses.
/// They agree until they don't, and the day they diverge is the day a save
/// loads as a different game than it was.
///
/// ## Total
///
/// [apply] cannot fail and cannot refuse. Validation happened before the event
/// existed. A reducer that could reject would make replay conditional, and a
/// conditional replay is not a replay.
///
/// ## Sequence
///
/// Each event carries its position. The reducer asserts it matches the state's
/// [GameState.eventSequence] — an out-of-order or duplicated event is a
/// programming fault, not a gameplay outcome, so it throws rather than rejects.
final class EventReducer {
  const EventReducer();

  /// Applies one event.
  GameState apply(GameState state, GameEvent event) {
    assert(
      event.sequence == state.eventSequence,
      'Event sequence ${event.sequence} does not match state sequence '
      '${state.eventSequence}. Events must be applied in order, exactly once.',
    );

    final GameState next = switch (event) {
      GameStarted() => _started(state, event),
      SyntheticStepsGranted() => _grantSteps(state, event.steps),
      StepsAllocated() => _spendSteps(state, event.steps),
      ItemEquipped() => state.copyWith(
        equipment: state.equipment.equipping(event.slot, event.item),
      ),
      ItemUnequipped() => state.copyWith(
        equipment: state.equipment.clearing(event.slot),
      ),
      LocationUnlocked() => state.copyWith(
        world: state.world.unlocking(event.location),
      ),
      LocationEntered() => state.copyWith(
        world: state.world.movingTo(event.location),
      ),
      StepRecoveryStarted() => state.copyWith(
        steps: state.steps.copyWith(
          recovery: RecoveryState(
            phase: RecoveryPhase.awaitingCommit,
            windowStartMillis: event.windowStartMillis,
            windowEndMillis: event.windowEndMillis,
            truncated: event.truncated,
            attempts: state.steps.recovery.attempts + 1,
          ),
        ),
      ),
      StepObservationReconciled() => _reconciled(state, event),
      StepsGranted() => _grantSteps(state, event.steps),
      StepCheckpointAuthorized() => state.copyWith(
        steps: state.steps.copyWith(
          checkpoint: SyncCheckpoint(
            cursor: event.cursor,
            watermarkMillis: state.steps.checkpoint.watermarkMillis,
            syncCount: event.syncCount,
          ),
        ),
      ),
      StepRecoveryCompleted() => state.copyWith(
        steps: state.steps.copyWith(recovery: const RecoveryState.idle()),
      ),
      StepSourceStateChanged() => state.copyWith(
        steps: state.steps.copyWith(sourceState: event.sourceState),
      ),
    };

    return next.copyWith(eventSequence: state.eventSequence + 1);
  }

  /// Applies a sequence in order.
  GameState applyAll(GameState state, Iterable<GameEvent> events) {
    GameState current = state;
    for (final GameEvent event in events) {
      current = apply(current, event);
    }
    return current;
  }

  GameState _started(GameState state, GameStarted event) {
    Inventory inventory = state.inventory;
    for (final ContentId item in event.grantedItems) {
      inventory = inventory.adding(item, 1);
    }
    return state.copyWith(
      inventory: inventory,
      world: WorldState(
        currentLocation: event.startLocation,
        unlockedLocations: <ContentId>{event.startLocation},
      ),
    );
  }

  /// Credits steps. Granted only ever rises.
  GameState _grantSteps(GameState state, int steps) => state.copyWith(
    steps: state.steps.copyWith(totalGranted: state.steps.totalGranted + steps),
  );

  /// Commits steps to an activity.
  ///
  /// Spending beyond banked is refused at validation, so reaching here with an
  /// impossible amount is a programming fault — [StepLedger] throws rather than
  /// clamping, because a silently clamped spend is a save that quietly
  /// disagrees with the command that produced it.
  GameState _spendSteps(GameState state, int steps) => state.copyWith(
    steps: state.steps.copyWith(totalSpent: state.steps.totalSpent + steps),
  );

  GameState _reconciled(GameState state, StepObservationReconciled event) {
    final StepLedger ledger = state.steps;
    return state.copyWith(
      steps: ledger.copyWith(
        totalObserved: event.observedAfter,
        grantedSlices: event.grantedSlicesAfter,
        grantedBeforeWatermark:
            ledger.grantedBeforeWatermark + event.grantedCompactedAway,
        checkpoint: SyncCheckpoint(
          cursor: ledger.checkpoint.cursor,
          watermarkMillis: event.watermarkMillis,
          syncCount: ledger.checkpoint.syncCount,
        ),
        lateDiscardedSlices: ledger.lateDiscardedSlices + event.lateDiscarded,
        correctionsObserved: ledger.correctionsObserved + event.correctionsSeen,
        unreachableGapEvents:
            ledger.unreachableGapEvents + (event.truncatedGap ? 1 : 0),
      ),
    );
  }
}
