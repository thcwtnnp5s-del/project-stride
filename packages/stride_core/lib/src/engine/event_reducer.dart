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
      ResourceGathered() => _gathered(state, event),
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
      LocationTravelled() => _travelled(state, event),
      ItemCrafted() => _crafted(state, event),
      EconomyEpochEstablished() => state.copyWith(
        steps: state.steps.copyWith(
          epoch: EconomyEpoch(
            grantedAtStart: event.grantedAtStart,
            spentAtStart: event.spentAtStart,
          ),
        ),
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
            // Carried forward. Dropping these would unsettle every origin and
            // re-grant the whole retention window on the next sync.
            originWatermarks: state.steps.checkpoint.originWatermarks,
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

  /// Spends, yields, and awards in one step.
  ///
  /// All three parts of the fact land together. `copyWith` builds one new state
  /// rather than three, so there is no intermediate value — not even a
  /// transient one inside this method — in which the ledger has been debited and
  /// the inventory has not.
  ///
  /// The figures come off the event, never out of the registry. Replaying a
  /// gather must reproduce the state that was committed, and a content pack
  /// that retuned the node since would otherwise reproduce a different one.
  GameState _gathered(GameState state, ResourceGathered event) =>
      state.copyWith(
        steps: state.steps.copyWith(
          totalSpent: state.steps.totalSpent + event.stepsSpent,
        ),
        inventory: state.inventory.adding(event.item, event.quantity),
        skills: state.skills.adding(event.skill, event.experience),
      );

  /// Spends, moves, and records the arrival in one step.
  ///
  /// Same shape and same reasoning as [_gathered]: one `copyWith`, so there is
  /// no value anywhere — not even transiently inside this method — in which the
  /// steps have been charged and the player has not moved.
  ///
  /// `unlocking` is applied unconditionally rather than under `event.firstVisit`.
  /// Adding a location already in the set is a no-op, so the two are equivalent
  /// in effect; doing it unconditionally means the *state* depends only on where
  /// the player went, and `firstVisit` stays what it is — a note for listeners,
  /// never an input to the world.
  GameState _travelled(GameState state, LocationTravelled event) =>
      state.copyWith(
        steps: state.steps.copyWith(
          totalSpent: state.steps.totalSpent + event.stepsSpent,
        ),
        world: state.world.unlocking(event.location).movingTo(event.location),
      );

  /// Consumes, produces, and awards in one step.
  ///
  /// No ledger field is touched: crafting costs no steps, and a reducer branch
  /// that debited one would be inventing a cost the design rules out.
  GameState _crafted(GameState state, ItemCrafted event) {
    Inventory inventory = state.inventory;
    for (final MapEntry<ContentId, int> taken in event.consumed.entries) {
      inventory = inventory.removing(taken.key, taken.value);
    }
    return state.copyWith(
      inventory: inventory.adding(event.item, event.quantity),
      skills: state.skills.adding(event.skill, event.experience),
    );
  }

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
          originWatermarks: event.originWatermarks,
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
