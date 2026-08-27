import '../content/content_id.dart';
import '../content/definitions.dart' show EquipmentSlot;

import '../steps/step_ledger.dart';

import 'combat.dart';
import 'events.dart';
import 'game_state.dart';

/// Applies one gather's effects — spend, yield, experience — in one step.
///
/// **The single application of a gather's figures**, shared by the
/// `ResourceGathered` branch, both activity-queue branches, and the engine's
/// per-completion validation walk (`DECISIONS/0022` §6). Extracted so the
/// manual gather and a queue completion cannot diverge: there is exactly one
/// place that turns the five figures into a state change.
///
/// One `copyWith`, so there is no value — not even transiently — in which the
/// ledger has been debited and the inventory has not. The figures come off an
/// event (or the engine's freshly-scaled decision), never out of the registry.
///
/// Not for general callers: this exists for the engine and the reducer, and
/// state mutations still flow only through committed events.
GameState applyGatherEffects(
  GameState state, {
  required int stepsSpent,
  required ContentId item,
  required int quantity,
  required ContentId skill,
  required int experience,
}) => state.copyWith(
  steps: state.steps.copyWith(totalSpent: state.steps.totalSpent + stepsSpent),
  inventory: state.inventory.adding(item, quantity),
  skills: state.skills.adding(skill, experience),
);

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
      ActivityQueueStarted() => state.copyWith(
        activityQueue: ActivityQueueState(
          node: event.node,
          requested: event.requested,
          completed: 0,
          durationMillis: event.durationMillis,
          anchorEpochMillis: event.anchorEpochMillis,
        ),
      ),
      ActivityQueueReconciled() => _queueReconciled(state, event),
      ActivityQueueStopped() => _queueStopped(state, event),
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
            establishedAtStateVersion: event.toStateVersion,
          ),
        ),
      ),
      PlaytestReset() => _playtestReset(state, event),
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
      // Starting the fight is what makes the enemy **Seen**: its victory
      // counter is materialised at its current value (zero for a first
      // meeting), and presence in the map is the knowledge system's "have I
      // ever faced this" fact (`DECISIONS/0023` §5).
      EncounterStarted() => state.copyWith(
        encounter: EncounterState(
          enemy: event.enemy,
          location: event.location,
          seed: event.seed,
          turn: 1,
          playerHp: event.playerHp,
          playerMaxHp: event.playerMaxHp,
          playerAttack: event.playerAttack,
          playerDefence: event.playerDefence,
          enemyHp: event.enemyHp,
          enemyMaxHp: event.enemyMaxHp,
          telegraph: false,
          playerFrostGuard: event.playerFrostGuard,
        ),
        progress: state.progress.copyWith(
          enemyVictories: <ContentId, int>{
            ...state.progress.enemyVictories,
            event.enemy: state.progress.victoriesOf(event.enemy),
          },
        ),
      ),
      CombatPlayerStruck() => state.copyWith(
        encounter: _encounterOf(state).copyWith(enemyHp: event.enemyHpAfter),
      ),
      // Consumes and heals in one step: no value, not even transiently, in
      // which the food is gone and the HP has not moved.
      CombatConsumableUsed() => state.copyWith(
        inventory: state.inventory.removing(event.item, 1),
        encounter: _encounterOf(state).copyWith(playerHp: event.playerHpAfter),
      ),
      // Narration only: the halved strikes that follow carry the figures, so
      // the stance changes no state of its own (`DECISIONS/0027`).
      CombatBraced() => state,
      CombatEnemyStruck() => state.copyWith(
        encounter: _encounterOf(state).copyWith(playerHp: event.playerHpAfter),
      ),
      CombatRoundEnded() => state.copyWith(
        encounter: _encounterOf(
          state,
        ).copyWith(turn: event.turn, telegraph: event.telegraph),
      ),
      EncounterWon() => _won(state, event),
      // Clears the fight and moves the player, and *nothing else* is lost
      // (`RULES.md` P-7) — the safe destination restores HP, which is a gain.
      // `movingTo` also empties the driven-off set, as every move does. The
      // destination is always a location the player has already unlocked (a
      // safe location on the graph behind them), so no unlock is recorded.
      EncounterLost() => state.copyWith(
        clearEncounter: true,
        world: state.world.movingTo(event.retreatTo),
        player: event.restoredHp == null
            ? null
            : state.player.copyWith(hp: event.restoredHp),
      ),
      EncounterRetreated() => state.copyWith(
        clearEncounter: true,
        world: state.world.movingTo(event.retreatTo),
        player: event.restoredHp == null
            ? null
            : state.player.copyWith(hp: event.restoredHp),
      ),
      // Consumes and heals in one step, exactly as the in-combat branch does.
      FoodEaten() => state.copyWith(
        inventory: state.inventory.removing(event.item, 1),
        player: state.player.copyWith(hp: event.hpAfter),
      ),
      GoalTracked() => state.copyWith(
        progress: state.progress.copyWith(
          tracked: state.progress.tracked.setting(event.slot, event.target),
        ),
      ),
      // Acceptance starts a fresh count: prior progress for this contract is
      // discarded, so re-accepting a completed bounty begins at zero.
      ContractAccepted() => state.copyWith(
        progress: state.progress.copyWith(
          acceptedContracts: <ContentId>{
            ...state.progress.acceptedContracts,
            event.contract,
          },
          bountyProgress: <ContentId, int>{
            ...state.progress.bountyProgress,
            event.contract: 0,
          },
        ),
      ),
      ContractCompleted() => _contractCompleted(state, event),
      ProjectContributed() => _projectContributed(state, event),
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

  /// The reset: the ledger keeps everything but its mark; with a fresh
  /// start the rest of the state is the new-game shape (`DECISIONS/0025`).
  GameState _playtestReset(GameState state, PlaytestReset event) {
    final StepLedger steps = state.steps.copyWith(
      epoch: EconomyEpoch(
        grantedAtStart: event.grantedAtStart,
        spentAtStart: event.spentAtStart,
        establishedAtStateVersion: event.stateVersion,
        walkedAtStart: event.grantedAtStart,
      ),
    );
    if (!event.freshStart) return state.copyWith(steps: steps);

    Inventory inventory = Inventory.empty();
    for (final ContentId item in event.grantedItems) {
      inventory = inventory.adding(item, 1);
    }
    Equipment equipment = Equipment.empty();
    for (final MapEntry<EquipmentSlot, ContentId> e
        in event.equippedItems.entries) {
      equipment = equipment.equipping(e.key, e.value);
    }
    return state.copyWith(
      steps: steps,
      player: const PlayerState.initial(),
      inventory: inventory,
      equipment: equipment,
      skills: SkillProgress(<ContentId, int>{
        for (final ContentId skill in state.skills.experienceBySkill.keys)
          skill: 0,
      }),
      world: WorldState(
        currentLocation: event.startLocation,
        unlockedLocations: <ContentId>{event.startLocation},
      ),
      clearEncounter: true,
      clearActivityQueue: true,
      progress: ProgressState.initial(),
    );
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
      applyGatherEffects(
        state,
        stepsSpent: event.stepsSpent,
        item: event.item,
        quantity: event.quantity,
        skill: event.skill,
        experience: event.experience,
      );

  /// Applies the k committed completions and moves — or clears — the queue,
  /// in one branch.
  ///
  /// Every completion goes through [applyGatherEffects], the same application
  /// a `ResourceGathered` gets, so a queue repetition and a manual gather
  /// cannot drift apart (`DECISIONS/0022` §6). The anchor and the completed
  /// count come off the event, never re-derived from a clock: the reducer is
  /// total and replay must reproduce the committed state.
  GameState _queueReconciled(GameState state, ActivityQueueReconciled event) {
    final GameState next = _applyCompletions(state, event.completions);
    final ActivityQueueState? queue = next.activityQueue;
    if (queue == null) {
      throw StateError(
        'an activity-queue event was applied with no queue active; events '
        'must be applied in order, and a queue begins with '
        'ActivityQueueStarted',
      );
    }
    return event.cleared
        ? next.copyWith(clearActivityQueue: true)
        : next.copyWith(
            activityQueue: queue.copyWith(
              completed: event.completedAfter,
              anchorEpochMillis: event.anchorAfter,
            ),
          );
  }

  /// The stop: the closing reconciliation's completions, then the clear —
  /// unconditionally (`DECISIONS/0022` §7).
  GameState _queueStopped(GameState state, ActivityQueueStopped event) =>
      _applyCompletions(
        state,
        event.completions,
      ).copyWith(clearActivityQueue: true);

  static GameState _applyCompletions(
    GameState state,
    List<ActivityCompletion> completions,
  ) {
    GameState next = state;
    for (final ActivityCompletion completion in completions) {
      next = applyGatherEffects(
        next,
        stepsSpent: completion.stepsSpent,
        item: completion.item,
        quantity: completion.quantity,
        skill: completion.skill,
        experience: completion.experience,
      );
    }
    return next;
  }

  /// Spends, moves, records the arrival — and, at a safe destination, heals —
  /// in one step.
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
  ///
  /// The heal comes off the event (`restoredHp`), never recomputed here: the
  /// reducer is total and replay must reproduce the committed HP after any
  /// level-curve retune.
  GameState _travelled(GameState state, LocationTravelled event) =>
      state.copyWith(
        steps: state.steps.copyWith(
          totalSpent: state.steps.totalSpent + event.stepsSpent,
        ),
        world: state.world.unlocking(event.location).movingTo(event.location),
        player: event.restoredHp == null
            ? null
            : state.player.copyWith(hp: event.restoredHp),
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

  /// The encounter a mid-fight event applies to.
  ///
  /// A combat event with no encounter is a programming fault, not a gameplay
  /// outcome: the engine only emits one against an active fight, and a journal
  /// that replays one without its `EncounterStarted` is out of order. Thrown
  /// rather than tolerated, like a sequence mismatch.
  static EncounterState _encounterOf(GameState state) {
    final EncounterState? encounter = state.encounter;
    if (encounter == null) {
      throw StateError(
        'a combat event was applied with no encounter active; events must be '
        'applied in order, and a fight begins with EncounterStarted',
      );
    }
    return encounter;
  }

  /// Rewards, clears, and counts the victory in one step.
  ///
  /// One `copyWith`, so there is no value — not even transiently inside this
  /// method — in which the reward has landed and the encounter is still open,
  /// or vice versa. That, plus the reward being a field of this one event, is
  /// what makes it exactly-once (`DECISIONS/0020` §2, `DECISIONS/0021` §2).
  /// Level and experience come off the event: recomputing the level here from
  /// a curve would let a retuned curve re-level a replayed save.
  ///
  /// The visit count is incremented here and nowhere else. A second reward
  /// therefore needs a second `EncounterWon`, which needs a second encounter,
  /// which the engine only starts while the count is below the enemy's
  /// authored `encountersPerVisit` — so raising the count from 1 to 2 changed
  /// how many fights a visit holds and changed nothing about how many times
  /// one fight pays.
  GameState _won(GameState state, EncounterWon event) {
    Inventory inventory = state.inventory;
    for (final MapEntry<ContentId, int> drop in event.drops.entries) {
      inventory = inventory.adding(drop.key, drop.value);
    }
    // HP off the event when it carries one (state v7). A pre-v7 record has
    // none to write, which is what those fights meant.
    final int hpAfter = event.playerHpAfter ?? state.player.hp;
    // Lifetime victories off the event when carried; otherwise the increment
    // lands on the same number for a pre-v7 record.
    final int victoriesAfter =
        event.victoriesAfter ?? (state.progress.victoriesOf(event.enemy) + 1);
    // Bounty counts as the engine recorded them at victory time.
    final Map<ContentId, int> bounty = event.bountyProgress.isEmpty
        ? state.progress.bountyProgress
        : <ContentId, int>{
            ...state.progress.bountyProgress,
            ...event.bountyProgress,
          };
    return state.copyWith(
      clearEncounter: true,
      inventory: inventory,
      player: PlayerState(
        level: event.levelAfter,
        experience: event.experienceAfter,
        hp: hpAfter,
      ),
      world: state.world.recordingVictory(event.enemy),
      progress: state.progress.copyWith(
        enemyVictories: <ContentId, int>{
          ...state.progress.enemyVictories,
          event.enemy: victoriesAfter,
        },
        bountyProgress: bounty,
      ),
    );
  }

  /// Consumes, rewards, records, and rotates — one branch, one fact
  /// (`DECISIONS/0023` §2). Every figure comes off the event.
  GameState _contractCompleted(GameState state, ContractCompleted event) {
    Inventory inventory = state.inventory;
    for (final MapEntry<ContentId, int> taken in event.consumed.entries) {
      inventory = inventory.removing(taken.key, taken.value);
    }
    for (final MapEntry<ContentId, int> given in event.rewardItems.entries) {
      inventory = inventory.adding(given.key, given.value);
    }
    SkillProgress skills = state.skills;
    for (final MapEntry<ContentId, int> award in event.rewardSkillXp.entries) {
      skills = skills.adding(award.key, award.value);
    }

    // A completed bounty leaves the accepted set; its progress record goes
    // with it, so a later re-acceptance starts clean.
    final Set<ContentId> accepted = <ContentId>{
      ...state.progress.acceptedContracts,
    }..remove(event.contract);
    final Map<ContentId, int> bounty = <ContentId, int>{
      ...state.progress.bountyProgress,
    }..remove(event.contract);

    final List<ContentId>? slots = event.rotatedSlots;
    final int? next = event.rotatedNext;

    // A completed contract leaves the tracker. Without this, a tracked
    // rotating local need or re-acceptable bounty silently re-points at the
    // fresh instance of the same contract — the owner's device found "Wolf
    // Problem" complete and the tracker reading "Forest Wolf defeated 0/3"
    // (PRESENTATION_WORLD_REWARD_FEEL_01 B-1). Clearing is information-only:
    // tracking never reserves or spends anything (`RULES.md` P-9), and the
    // completion's own presentation is the board's held result panel.
    final TrackedGoals tracked =
        state.progress.tracked.contract == event.contract
        ? state.progress.tracked.setting(GoalSlot.contract, null)
        : state.progress.tracked;

    return state.copyWith(
      inventory: inventory,
      skills: skills,
      player: PlayerState(
        level: event.levelAfter,
        experience: event.experienceAfter,
        hp: state.player.hp,
      ),
      progress: state.progress.copyWith(
        tracked: tracked,
        acceptedContracts: accepted,
        bountyProgress: bounty,
        contractCompletions: <ContentId, int>{
          ...state.progress.contractCompletions,
          event.contract: event.completionsAfter,
        },
        localSlots: slots == null
            ? null
            : <ContentId, List<ContentId>>{
                ...state.progress.localSlots,
                event.location: slots,
              },
        localNext: next == null
            ? null
            : <ContentId, int>{
                ...state.progress.localNext,
                event.location: next,
              },
        revealedRumors: event.revealedRumors.isEmpty
            ? null
            : <ContentId>{
                ...state.progress.revealedRumors,
                ...event.revealedRumors,
              },
      ),
    );
  }

  /// Donates, advances, and — when the stage filled — completes, in one
  /// branch (`DECISIONS/0023` §3). Progress is monotonic by construction:
  /// nothing here can lower a count or reopen a completed stage.
  GameState _projectContributed(GameState state, ProjectContributed event) {
    Inventory inventory = state.inventory;
    for (final MapEntry<ContentId, int> taken in event.contributed.entries) {
      inventory = inventory.removing(taken.key, taken.value);
    }

    final Map<ContentId, ProjectProgressState> projects =
        <ContentId, ProjectProgressState>{...state.progress.projects};
    Set<ContentId>? completed;
    if (event.projectCompleted) {
      projects.remove(event.project);
      completed = <ContentId>{
        ...state.progress.completedProjects,
        event.project,
      };
    } else if (event.stageCompleted) {
      projects[event.project] = ProjectProgressState(stage: event.stage + 1);
    } else {
      projects[event.project] = ProjectProgressState(
        stage: event.stage,
        contributed: event.stageContributedAfter,
      );
    }

    // A fully completed project leaves the tracker, exactly as a completed
    // contract does (B-1): the slot is information, the project cannot be
    // contributed to again, and the completion's presentation is the major
    // held panel. A stage completion keeps the tracking — the project is
    // still live work.
    final TrackedGoals tracked =
        event.projectCompleted &&
            state.progress.tracked.contract == event.project
        ? state.progress.tracked.setting(GoalSlot.contract, null)
        : state.progress.tracked;

    return state.copyWith(
      inventory: inventory,
      player: PlayerState(
        level: event.levelAfter,
        experience: event.experienceAfter,
        hp: state.player.hp,
      ),
      progress: state.progress.copyWith(
        tracked: tracked,
        projects: projects,
        completedProjects: completed,
        revealedRumors: event.revealedRumors.isEmpty
            ? null
            : <ContentId>{
                ...state.progress.revealedRumors,
                ...event.revealedRumors,
              },
      ),
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
