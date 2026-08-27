import 'package:meta/meta.dart';

import '../content/content_id.dart';
import '../content/definitions.dart';
import '../steps/reconciliation.dart';
import '../steps/step_ledger.dart';
import '../steps/step_origin_key.dart';
import '../steps/sync_batch.dart';
import 'game_state.dart' show GoalSlot;

/// Something that has happened.
///
/// An event is an accepted fact. By the time one exists, validation has already
/// passed, so applying it through the reducer cannot fail and cannot be
/// refused. That is what makes replay meaningful: feeding the same events into
/// the same starting state must always produce the same result, with no
/// re-validation and no opportunity to disagree with the original run.
///
/// Events are also the only channel to audio, haptics, and the return summary.
/// The simulation emits `ItemEquipped`; something else decides what that sounds
/// like. Nothing in here names a sound, an animation, or a screen.
@immutable
sealed class GameEvent {
  const GameEvent({required this.sequence});

  /// Position in the event stream, starting at 0.
  ///
  /// Monotonic and gap-free. Gives every event a stable identity, which is what
  /// lets a replay be verified and — once F-05 exists — lets a crash between
  /// writing an event and writing a snapshot be detected rather than guessed at.
  final int sequence;

  String get name;
}

/// A new game began.
///
/// Emitted as an event rather than assumed, so that the very first thing in a
/// game's history is a fact in the same stream as everything after it. A save
/// whose event log does not start here is a save that began somewhere unknown.
@immutable
final class GameStarted extends GameEvent {
  const GameStarted({
    required super.sequence,
    required this.profileId,
    required this.startLocation,
    required this.grantedItems,
  });

  final ContentId profileId;
  final ContentId startLocation;
  final List<ContentId> grantedItems;

  @override
  String get name => 'GameStarted';
}

/// The owner began a fresh playtest (`DECISIONS/0025`).
///
/// Moves the economy mark to the ledger's current totals — the same mark
/// `DECISIONS/0016`/`0018`/`0019` move, so `banked` reads zero — and sets
/// the walked baseline to the same point, so the player-facing walked count
/// starts again. **Touches no counter, no slice, no watermark, no cursor**:
/// `totalGranted` keeps every step ever credited (`RULES.md` H-2), the
/// granted-slice map and the per-origin watermarks keep refusing a re-grant
/// of history (H-3, H-4), and the next sync reads forward from where the
/// last one stopped.
///
/// With [freshStart] the game itself also begins again: the bag, the gear,
/// the skills, the character, the world position, the progression loop and
/// any fight or queue in flight — the new-game shape, granted [grantedItems]
/// at [startLocation], on top of the untouched ledger.
final class PlaytestReset extends GameEvent {
  const PlaytestReset({
    required super.sequence,
    required this.grantedAtStart,
    required this.spentAtStart,
    required this.previousGrantedAtStart,
    required this.previousSpentAtStart,
    required this.previousWalkedAtStart,
    required this.stateVersion,
    required this.freshStart,
    required this.startLocation,
    this.grantedItems = const <ContentId>[],
    this.equippedItems = const <EquipmentSlot, ContentId>{},
  });

  /// The new mark — the ledger's totals at the reset. The walked baseline is
  /// [grantedAtStart] too: one mark, two readings.
  final int grantedAtStart;
  final int spentAtStart;

  /// The mark this one replaces, for the record and the report.
  final int previousGrantedAtStart;
  final int previousSpentAtStart;
  final int previousWalkedAtStart;

  /// The running state version, recorded on the epoch.
  final int stateVersion;

  /// Whether the game state (not the ledger) was also returned to new.
  final bool freshStart;
  final ContentId startLocation;
  final List<ContentId> grantedItems;

  /// What the fresh game wears, by slot (`ContentRegistry.startingEquipment`).
  /// Empty for a baseline-only reset.
  final Map<EquipmentSlot, ContentId> equippedItems;

  /// What the reset retired from the spendable balance.
  int get retiredBanked =>
      (grantedAtStart - previousGrantedAtStart) -
      (spentAtStart - previousSpentAtStart);

  @override
  String get name => 'PlaytestReset';
}

/// Steps entered the ledger from a synthetic source.
@immutable
final class SyntheticStepsGranted extends GameEvent {
  const SyntheticStepsGranted({
    required super.sequence,
    required this.steps,
    required this.reason,
  });

  final int steps;
  final String reason;

  @override
  String get name => 'SyntheticStepsGranted';
}

/// Banked steps were committed.
@immutable
final class StepsAllocated extends GameEvent {
  const StepsAllocated({required super.sequence, required this.steps});

  final int steps;

  @override
  String get name => 'StepsAllocated';
}

/// A resource node was worked once: steps spent, yield taken, experience gained.
///
/// **One event, not three.** The spend, the item, and the experience are a
/// single fact and are applied by a single reducer branch, so there is no
/// instant — in memory, in the journal, or in a replay — at which the steps are
/// gone and the herbs have not arrived. Splitting it into `StepsAllocated` plus
/// an inventory event plus an experience event would make that instant real and
/// reachable: the journal is append-only and a process killed between two
/// records leaves the first one durable.
///
/// Every figure is recorded on the event rather than recomputed from content at
/// replay time. A content pack that retunes `stepCost` or `xp` next month must
/// not change what a gather the player already performed did to their save —
/// replay would then produce a different state than the one that was committed,
/// which is the one thing a replay may never do.
@immutable
final class ResourceGathered extends GameEvent {
  const ResourceGathered({
    required super.sequence,
    required this.node,
    required this.stepsSpent,
    required this.item,
    required this.quantity,
    required this.skill,
    required this.experience,
  });

  final ContentId node;

  /// Profile-scaled, as charged. Never the raw content value.
  final int stepsSpent;

  final ContentId item;
  final int quantity;
  final ContentId skill;

  /// Profile-scaled, as awarded. May be zero; a node with no xp is legal.
  final int experience;

  @override
  String get name => 'ResourceGathered';
}

// -- The activity queue (`DECISIONS/0022`) -------------------------------------
//
// Three events, one per command, each applied by one reducer branch — so the
// queue's whole lifecycle is exactly-once by commit, never by clock. Every
// completion's figures are recorded on the event exactly as `ResourceGathered`
// records a manual gather's, and for the same reason: replay must reproduce
// the committed state after any content retune.

/// One repetition's committed figures, carried on a queue event.
///
/// The same five figures a `ResourceGathered` event carries, profile-scaled as
/// charged and as awarded — because a queue completion IS a gather, resolved
/// through the same validation and applied through the same effects
/// (`DECISIONS/0022` §6). Not itself an event: the k completions of one
/// reconciliation are one fact and land in one commit.
@immutable
final class ActivityCompletion {
  const ActivityCompletion({
    required this.stepsSpent,
    required this.item,
    required this.quantity,
    required this.skill,
    required this.experience,
  });

  /// Profile-scaled, as charged. Never the raw content value.
  final int stepsSpent;

  final ContentId item;
  final int quantity;
  final ContentId skill;

  /// Profile-scaled, as awarded. May be zero; a node with no xp is legal.
  final int experience;

  @override
  bool operator ==(Object other) =>
      other is ActivityCompletion &&
      other.stepsSpent == stepsSpent &&
      other.item == item &&
      other.quantity == quantity &&
      other.skill == skill &&
      other.experience == experience;

  @override
  int get hashCode =>
      Object.hash(stepsSpent, item, quantity, skill, experience);
}

/// A finite activity queue began. Nothing is spent; the anchor starts the
/// first repetition's clock (`DECISIONS/0022` §5).
@immutable
final class ActivityQueueStarted extends GameEvent {
  const ActivityQueueStarted({
    required super.sequence,
    required this.node,
    required this.requested,
    required this.durationMillis,
    required this.anchorEpochMillis,
  });

  final ContentId node;
  final int requested;
  final int durationMillis;
  final int anchorEpochMillis;

  @override
  String get name => 'ActivityQueueStarted';
}

/// Elapsed wall-clock time completed one or more repetitions, and they
/// committed — spend, yield, and experience — in one fact.
///
/// **One event for k completions, not k events.** The anchor advances by
/// exactly `k × durationMillis` in the same commit that applies the k
/// completions, which is what makes a second reconciliation after the commit
/// find nothing left to complete (`DECISIONS/0022` §6). Emitted only when
/// something changed: a reconcile that completes nothing is accepted with no
/// events and commits nothing.
@immutable
final class ActivityQueueReconciled extends GameEvent {
  ActivityQueueReconciled({
    required super.sequence,
    required this.node,
    required List<ActivityCompletion> completions,
    required this.completedAfter,
    required this.anchorAfter,
    required this.cleared,
    this.stopReason,
  }) : completions = List<ActivityCompletion>.unmodifiable(completions);

  final ContentId node;

  /// The repetitions that committed, in order. May be empty when the very
  /// first elapsed repetition was refused — the event then records only the
  /// clearing, with [stopReason].
  final List<ActivityCompletion> completions;

  /// The queue's completed count after this event.
  final int completedAfter;

  /// The anchor after this event: the old anchor plus exactly the committed
  /// completions' worth of duration. Meaningless once [cleared].
  final int anchorAfter;

  /// Whether this event clears the queue — either every requested repetition
  /// is complete, or a repetition was refused and the queue stopped there.
  final bool cleared;

  /// The stable `RejectionCode.wire` value of the refusal that stopped the
  /// queue, or null when nothing was refused (`DECISIONS/0022` §6).
  final String? stopReason;

  @override
  String get name => 'ActivityQueueReconciled';
}

/// The queue was stopped: the closing reconciliation's fully-elapsed
/// repetitions committed, the partial one discarded, and the queue cleared —
/// one fact, one commit (`DECISIONS/0022` §7).
@immutable
final class ActivityQueueStopped extends GameEvent {
  ActivityQueueStopped({
    required super.sequence,
    required this.node,
    required List<ActivityCompletion> completions,
    required this.completedAfter,
    this.stopReason,
  }) : completions = List<ActivityCompletion>.unmodifiable(completions);

  final ContentId node;

  /// The closing reconciliation's committed repetitions, possibly empty.
  final List<ActivityCompletion> completions;

  /// The queue's completed count as it clears.
  final int completedAfter;

  /// The refusal that ended the closing reconciliation early, if one did —
  /// the stop clears the queue either way.
  final String? stopReason;

  @override
  String get name => 'ActivityQueueStopped';
}

/// An item was placed in a slot.
@immutable
final class ItemEquipped extends GameEvent {
  const ItemEquipped({
    required super.sequence,
    required this.item,
    required this.slot,
  });

  final ContentId item;
  final EquipmentSlot slot;

  @override
  String get name => 'ItemEquipped';
}

/// A slot was emptied.
@immutable
final class ItemUnequipped extends GameEvent {
  const ItemUnequipped({
    required super.sequence,
    required this.item,
    required this.slot,
  });

  final ContentId item;
  final EquipmentSlot slot;

  @override
  String get name => 'ItemUnequipped';
}

/// The playable step economy was re-based at a cutover point.
///
/// **Emitted exactly once per save per re-basing migration step** — the Phase 2
/// cutover (`DECISIONS/0016`, `toStateVersion` 2) and the Transformation
/// playtest epoch (`DECISIONS/0018`, `toStateVersion` 3). It records what the
/// two running totals read at the moment the playable economy began; from then
/// on `banked` is measured from those marks (`EconomyEpoch`).
///
/// It is a fact about the *ledger's accounting origin*, not about steps. No step
/// is created, destroyed, granted, or revoked by applying it: [StepLedger.
/// totalGranted] and [StepLedger.totalSpent] are the same on both sides, which
/// is what keeps `RULES.md` H-2 intact through a change whose entire purpose is
/// to reduce a balance.
///
/// The marks are carried on the event rather than recomputed at replay time, for
/// the same reason [ResourceGathered] carries its figures: replaying a migration
/// must reproduce the state that was committed, and a ledger that had been
/// granted more steps since would otherwise re-base to a different point and
/// zero the player a second time.
@immutable
final class EconomyEpochEstablished extends GameEvent {
  const EconomyEpochEstablished({
    required super.sequence,
    required this.grantedAtStart,
    required this.spentAtStart,
    required this.fromStateVersion,
    required this.toStateVersion,
    this.previousGrantedAtStart = 0,
    this.previousSpentAtStart = 0,
  });

  final int grantedAtStart;
  final int spentAtStart;

  /// The state version the save was read at. Diagnostic — it is what makes a
  /// journal line say which migration this was.
  final int fromStateVersion;

  /// The state version whose migration step established this mark, and the
  /// value `EconomyEpoch.establishedAtStateVersion` takes when this is applied.
  ///
  /// **Load-bearing, not diagnostic**: it is what the exactly-once guard in
  /// `EstablishEconomyEpoch` reads on the next re-basing step. A journal record
  /// written before this field existed can only be a Phase 2 cutover, so it
  /// decodes as `2` (`event_codec.dart`).
  final int toStateVersion;

  /// The mark that was in effect before this one — the origin for a Phase 2
  /// cutover, the Phase 2 mark for the Transformation epoch.
  ///
  /// Diagnostic. It lets `StateMigrationReport` say how much of the retired
  /// body *this* migration retired, as distinct from what was already retired,
  /// without re-deriving it from a ledger that has since moved. Applying the
  /// event does not read it.
  final int previousGrantedAtStart;
  final int previousSpentAtStart;

  /// What this cutover retired, over and above what was already retired.
  int get newlyRetiredSteps =>
      (grantedAtStart - spentAtStart) -
      (previousGrantedAtStart - previousSpentAtStart);

  @override
  String get name => 'EconomyEpochEstablished';
}

/// The player travelled a route, paying for it out of banked steps.
///
/// **One event, not three**, for the reason [ResourceGathered] gives: the spend,
/// the move, and the first-visit record are a single fact. Splitting them would
/// make reachable an instant — in memory, in the journal, or in a replay — at
/// which the steps are gone and the player is still standing where they were.
///
/// [stepsSpent] is profile-scaled as charged, never the raw content value, so a
/// content pack that retunes the route next month cannot change what a journey
/// the player already made did to their save.
@immutable
final class LocationTravelled extends GameEvent {
  const LocationTravelled({
    required super.sequence,
    required this.from,
    required this.location,
    required this.stepsSpent,
    required this.firstVisit,
    this.restoredHp,
  });

  final ContentId from;
  final ContentId location;

  /// Profile-scaled, as charged.
  final int stepsSpent;

  /// Whether this arrival is the one that opened the place.
  ///
  /// Carried so a listener — the return summary, audio, a future discovery
  /// system — can tell arriving somewhere new from walking a familiar road,
  /// without having to consult the world state it is about to be handed.
  final bool firstVisit;

  /// The HP this arrival restored the player to, or null when the
  /// destination is not safe (`DECISIONS/0023` §4 — safe locations heal
  /// fully, instantly, freely). Carried on the event, never recomputed by
  /// the reducer, so replay stays exact after a level-curve retune.
  final int? restoredHp;

  @override
  String get name => 'LocationTravelled';
}

/// Materials became an item.
///
/// **One event, not three.** Ingredients leave the inventory, the output
/// arrives, and the experience lands together — the same atomicity argument as
/// [ResourceGathered], and for the same reason: the journal is append-only, and
/// a process killed between two records leaves the first one durable. A player
/// whose ore vanished and whose ingot never arrived has lost the walk that
/// bought it.
///
/// Crafting **spends no steps** (`GAME_BIBLE/SYSTEMS/04_CRAFTING_SYSTEM_
/// FRAMEWORK.md`), so there is deliberately no `stepsSpent` field here. The
/// steps were already spent gathering.
///
/// [consumed] is recorded as literal amounts rather than as a recipe reference,
/// so replay reproduces the committed state even after the recipe is retuned.
@immutable
final class ItemCrafted extends GameEvent {
  ItemCrafted({
    required super.sequence,
    required this.recipe,
    required Map<ContentId, int> consumed,
    required this.item,
    required this.quantity,
    required this.skill,
    required this.experience,
  }) : consumed = Map<ContentId, int>.unmodifiable(consumed);

  final ContentId recipe;

  /// What was taken, and how much. Exact amounts as charged.
  final Map<ContentId, int> consumed;

  final ContentId item;
  final int quantity;
  final ContentId skill;

  /// Profile-scaled, as awarded.
  final int experience;

  @override
  String get name => 'ItemCrafted';
}

/// A location became available.
@immutable
final class LocationUnlocked extends GameEvent {
  const LocationUnlocked({required super.sequence, required this.location});

  final ContentId location;

  @override
  String get name => 'LocationUnlocked';
}

/// The player moved.
@immutable
final class LocationEntered extends GameEvent {
  const LocationEntered({
    required super.sequence,
    required this.from,
    required this.location,
  });

  final ContentId from;
  final ContentId location;

  @override
  String get name => 'LocationEntered';
}

/// A bounded recovery began.
///
/// Emitted **before** the observation is reconciled, so a process that dies
/// mid-recovery leaves a ledger that knows one was started and never finished.
/// Without it, a retry could not tell an interrupted first attempt from a fresh
/// one.
@immutable
final class StepRecoveryStarted extends GameEvent {
  const StepRecoveryStarted({
    required super.sequence,
    required this.windowStartMillis,
    required this.windowEndMillis,
    required this.truncated,
  });

  final int windowStartMillis;
  final int windowEndMillis;
  final bool truncated;

  @override
  String get name => 'StepRecoveryStarted';
}

/// A batch was reconciled: observed totals and slice records updated.
///
/// Carries the downward-correction count, but **there is no `StepsRemoved`
/// event**. A health correction changes what the source says, never what the
/// player has been credited, so there is no removal to announce — inventing one
/// would invite a listener to undo a grant.
@immutable
final class StepObservationReconciled extends GameEvent {
  StepObservationReconciled({
    required super.sequence,
    required this.observedAfter,
    required Map<ObservationKey, int> grantedSlicesAfter,
    required this.grantedCompactedAway,
    required this.lateDiscarded,
    required this.watermarkMillis,
    required Map<StepOriginKey, int> originWatermarks,
    required this.correctionsSeen,
    required this.truncatedGap,
    required this.wasRecovery,
  }) : grantedSlicesAfter = Map<ObservationKey, int>.unmodifiable(
         grantedSlicesAfter,
       ),
       originWatermarks = Map<StepOriginKey, int>.unmodifiable(
         originWatermarks,
       );

  final int observedAfter;
  final Map<ObservationKey, int> grantedSlicesAfter;

  /// Granted credit for slices dropped by compaction, folded into the
  /// pre-watermark total so no granted step is ever lost.
  final int grantedCompactedAway;

  /// Observations that arrived after their bucket had been compacted away.
  ///
  /// These cannot be granted — the record proving whether they were already
  /// credited is gone. Carried as a fact rather than dropped in silence,
  /// because this is the one lossy path the design still permits.
  final int lateDiscarded;

  /// Diagnostic. The lowest per-origin watermark.
  final int? watermarkMillis;

  /// Per origin, the point through which that origin is accounted for.
  final Map<StepOriginKey, int> originWatermarks;
  final int correctionsSeen;
  final bool truncatedGap;
  final bool wasRecovery;

  @override
  String get name => 'StepObservationReconciled';
}

/// Steps were credited to the player.
///
/// Separate from [StepObservationReconciled] on purpose. Observing and granting
/// are different facts: a batch can update what the source says while granting
/// nothing, and anything reacting to *progress* — audio, the return summary —
/// should hear only this one.
@immutable
final class StepsGranted extends GameEvent {
  const StepsGranted({
    required super.sequence,
    required this.steps,
    required this.grantedTotalAfter,
  }) : assert(steps > 0, 'a grant event must credit something');

  final int steps;
  final int grantedTotalAfter;

  @override
  String get name => 'StepsGranted';
}

/// The replacement cursor is now safe to persist.
///
/// **Always the last event of a reconciliation batch.** The reducer applies
/// events in order, so the ledger has already committed the grant by the time
/// this lands.
///
/// That ordering is the entire crash-safety argument. Persisting a cursor first
/// would let a process die before the grant and resume from a point whose steps
/// were never credited — steps the player walked and will never see. Doing it
/// last means an interrupted commit leaves the old cursor in place and the
/// retry recomputes exactly the same result.
@immutable
final class StepCheckpointAuthorized extends GameEvent {
  const StepCheckpointAuthorized({
    required super.sequence,
    required this.cursor,
    required this.syncCount,
  });

  /// Null when the provider offered none — an unrecovered cursor stays absent
  /// rather than being invented.
  final SyncCursor? cursor;

  final int syncCount;

  @override
  String get name => 'StepCheckpointAuthorized';
}

/// A recovery finished and the ledger is consistent again.
@immutable
final class StepRecoveryCompleted extends GameEvent {
  const StepRecoveryCompleted({
    required super.sequence,
    required this.newlyGranted,
    required this.truncated,
  });

  final int newlyGranted;
  final bool truncated;

  @override
  String get name => 'StepRecoveryCompleted';
}

/// The provider's availability changed.
@immutable
final class StepSourceStateChanged extends GameEvent {
  const StepSourceStateChanged({
    required super.sequence,
    required this.sourceState,
    this.code,
  });

  final SourceState sourceState;
  final ReconciliationCode? code;

  @override
  String get name => 'StepSourceStateChanged';
}

// -- Combat (Combat Slice 01, `DECISIONS/0020`) --------------------------------
//
// Every figure a combat event needs is recorded on it: damage as dealt, HP as
// it stands after, the reward as awarded. The reducer performs no arithmetic
// against content and no roll, so a replay reproduces the committed fight even
// after the enemy is retuned or the level curve moves. Same rule as
// `ResourceGathered`, and for the same reason.

/// A fight began. Carries the player's snapshotted figures and the enemy's
/// profile-scaled health, so the encounter is a closed system from here.
@immutable
final class EncounterStarted extends GameEvent {
  const EncounterStarted({
    required super.sequence,
    required this.enemy,
    required this.location,
    required this.seed,
    required this.playerHp,
    required this.playerMaxHp,
    required this.playerAttack,
    required this.playerDefence,
    required this.enemyHp,
    required this.enemyMaxHp,
    this.playerFrostGuard = 0,
  });

  final ContentId enemy;
  final ContentId location;
  final int seed;
  final int playerHp;
  final int playerMaxHp;
  final int playerAttack;
  final int playerDefence;

  /// The armour's frost guard at start (`DECISIONS/0023` §4). Zero on
  /// pre-v7 records, where no armour carried one.
  final int playerFrostGuard;

  /// Profile-scaled, as the fight begins. Never the raw content value.
  final int enemyHp;
  final int enemyMaxHp;

  @override
  String get name => 'EncounterStarted';
}

/// The player hit the enemy.
@immutable
final class CombatPlayerStruck extends GameEvent {
  const CombatPlayerStruck({
    required super.sequence,
    required this.damage,
    required this.enemyHpAfter,
    required this.turn,
    this.roll = 0,
  });

  final int damage;
  final int enemyHpAfter;
  final int turn;

  /// The strike's roll, −1, 0 or +1 (`CombatRules.roll`) — the one figure
  /// that made this blow weak, even or strong. Recorded so the presentation
  /// can say so (PLAYABLE_POLISH_01 §8) without re-deriving it; `0` in a
  /// journal record written before the field existed.
  final int roll;

  @override
  String get name => 'CombatPlayerStruck';
}

/// The player ate. Exactly one of [item] left the inventory.
@immutable
final class CombatConsumableUsed extends GameEvent {
  const CombatConsumableUsed({
    required super.sequence,
    required this.item,
    required this.healed,
    required this.playerHpAfter,
    required this.turn,
  });

  final ContentId item;

  /// As healed: `min(healing, missing)`, never the raw content value.
  final int healed;
  final int playerHpAfter;
  final int turn;

  @override
  String get name => 'CombatConsumableUsed';
}

/// The player braced (`DECISIONS/0027`, experimental): no strike was dealt,
/// and every enemy strike this round lands at half damage. The strikes
/// themselves follow as ordinary [CombatEnemyStruck] events whose `damage`
/// is already halved — this event is the narration of the stance, so the
/// stage and the log can say what the player chose without diffing figures.
@immutable
final class CombatBraced extends GameEvent {
  const CombatBraced({required super.sequence, required this.turn});

  final int turn;

  @override
  String get name => 'CombatBraced';
}

/// The enemy hit the player. A flurry emits two per round, [strikeIndex] 0
/// and 1; a guarded enemy's every-third-turn blow carries [heavy].
@immutable
final class CombatEnemyStruck extends GameEvent {
  const CombatEnemyStruck({
    required super.sequence,
    required this.damage,
    required this.playerHpAfter,
    required this.turn,
    required this.heavy,
    required this.strikeIndex,
    this.roll = 0,
  });

  final int damage;
  final int playerHpAfter;
  final int turn;
  final bool heavy;
  final int strikeIndex;

  /// The strike's roll, as on [CombatPlayerStruck.roll]. Always `0` for a
  /// heavy strike, which rolls nothing.
  final int roll;

  @override
  String get name => 'CombatEnemyStruck';
}

/// The round is over and the fight goes on. [turn] is the **new** turn number
/// — the one the player is about to take. [telegraph] is true when the enemy's
/// next reply will be heavy.
@immutable
final class CombatRoundEnded extends GameEvent {
  const CombatRoundEnded({
    required super.sequence,
    required this.turn,
    required this.telegraph,
  });

  final int turn;
  final bool telegraph;

  @override
  String get name => 'CombatRoundEnded';
}

/// The enemy fell. **One event carries the whole reward** — XP, the level it
/// produces, the drops — and it is the same event that clears the encounter
/// and drives the enemy off, applied by one reducer branch. That is what makes
/// the reward exactly-once by construction (`DECISIONS/0020` §2): a replay
/// applies it once, and a second reward needs a second encounter.
@immutable
final class EncounterWon extends GameEvent {
  EncounterWon({
    required super.sequence,
    required this.enemy,
    required this.location,
    required this.characterXp,
    required this.experienceAfter,
    required this.levelBefore,
    required this.levelAfter,
    required Map<ContentId, int> drops,
    this.playerHpAfter,
    this.victoriesAfter,
    this.knowledgeXp = 0,
    Map<ContentId, int> bountyProgress = const <ContentId, int>{},
  }) : drops = Map<ContentId, int>.unmodifiable(drops),
       bountyProgress = Map<ContentId, int>.unmodifiable(bountyProgress);

  final ContentId enemy;
  final ContentId location;

  /// Profile-scaled, as awarded — including [knowledgeXp] when the crossing
  /// happened, so [experienceAfter] is always `before + characterXp`.
  final int characterXp;

  /// The character's total after the award; the reducer writes this, not a sum.
  final int experienceAfter;
  final int levelBefore;

  /// Recomputed from [experienceAfter] at award time and written here, so a
  /// later change to the level curve cannot re-level a replayed save.
  final int levelAfter;

  /// What dropped, by item, as literal amounts.
  final Map<ContentId, int> drops;

  /// The player's HP as the fight ended — persistent since state v7
  /// (`DECISIONS/0023` §4). Null on records written before persistent HP
  /// existed, where its absence means what those fights meant: nothing to
  /// write, every fight began full.
  final int? playerHpAfter;

  /// Lifetime victories over [enemy] after this one. Null on pre-v7 records;
  /// the reducer then increments the counter itself, which lands on the same
  /// number.
  final int? victoriesAfter;

  /// The one-time Known award, profile-scaled, when this victory crossed the
  /// enemy's `knownAt` threshold; zero otherwise. Already folded into
  /// [characterXp] — recorded separately so a listener can announce the
  /// bestiary milestone distinctly.
  final int knowledgeXp;

  /// Accepted bounty contracts this victory advanced, with each contract's
  /// count **after** the advance (`DECISIONS/0023` §2). Written by the
  /// engine at victory time so replay reproduces the counting exactly.
  final Map<ContentId, int> bountyProgress;

  @override
  String get name => 'EncounterWon';
}

/// The player fell. The encounter clears and the player is moved to
/// [retreatTo], the nearest safe location. **Nothing else changes**
/// (`RULES.md` P-7): no item, XP, skill or step is lost. Consumables eaten
/// during the fight stay eaten (`DECISIONS/0003`).
@immutable
final class EncounterLost extends GameEvent {
  const EncounterLost({
    required super.sequence,
    required this.enemy,
    required this.location,
    required this.retreatTo,
    this.restoredHp,
  });

  final ContentId enemy;
  final ContentId location;
  final ContentId retreatTo;

  /// The HP the safe retreat restored the player to (`DECISIONS/0023` §4).
  /// Null on pre-v7 records, whose fights carried no persistent HP to
  /// restore.
  final int? restoredHp;

  @override
  String get name => 'EncounterLost';
}

/// The player chose to leave. Identical in effect to [EncounterLost].
@immutable
final class EncounterRetreated extends GameEvent {
  const EncounterRetreated({
    required super.sequence,
    required this.enemy,
    required this.location,
    required this.retreatTo,
    this.restoredHp,
  });

  final ContentId enemy;
  final ContentId location;
  final ContentId retreatTo;

  /// See [EncounterLost.restoredHp].
  final int? restoredHp;

  @override
  String get name => 'EncounterRetreated';
}

// -- Exploration & Progression Loop 01 (`DECISIONS/0023`) ----------------------

/// The player ate outside combat. Exactly one of [item] left the inventory
/// and [healed] HP arrived, as one fact.
@immutable
final class FoodEaten extends GameEvent {
  const FoodEaten({
    required super.sequence,
    required this.item,
    required this.healed,
    required this.hpAfter,
  });

  final ContentId item;

  /// As healed: `min(healing, missing)`, never the raw content value.
  final int healed;
  final int hpAfter;

  @override
  String get name => 'FoodEaten';
}

/// A tracked-objective slot changed. No economy figure moves
/// (`DECISIONS/0023` §1).
@immutable
final class GoalTracked extends GameEvent {
  const GoalTracked({required super.sequence, required this.slot, this.target});

  final GoalSlot slot;

  /// The newly tracked id, or null when the slot was cleared.
  final ContentId? target;

  @override
  String get name => 'GoalTracked';
}

/// A bounty contract was accepted; qualifying victories count from here
/// (`DECISIONS/0023` §2). Any prior bounty progress for this contract is
/// reset by applying this event — acceptance starts a fresh count.
@immutable
final class ContractAccepted extends GameEvent {
  const ContractAccepted({required super.sequence, required this.contract});

  final ContentId contract;

  @override
  String get name => 'ContractAccepted';
}

/// A contract completed: requirements consumed, rewards granted, completion
/// recorded, the local-need deck rotated — **one fact, one reducer branch**,
/// which is what makes the whole exchange exactly-once (`DECISIONS/0023` §2).
///
/// Every figure is recorded as charged and as awarded, never as defined, for
/// the reason `ResourceGathered` gives: replay must reproduce the committed
/// state after any content retune.
@immutable
final class ContractCompleted extends GameEvent {
  ContractCompleted({
    required super.sequence,
    required this.contract,
    required this.location,
    required Map<ContentId, int> consumed,
    required Map<ContentId, int> rewardItems,
    required Map<ContentId, int> rewardSkillXp,
    required this.characterXp,
    required this.experienceAfter,
    required this.levelBefore,
    required this.levelAfter,
    required this.completionsAfter,
    List<ContentId> revealedRumors = const <ContentId>[],
    this.rotatedSlots,
    this.rotatedNext,
  }) : consumed = Map<ContentId, int>.unmodifiable(consumed),
       rewardItems = Map<ContentId, int>.unmodifiable(rewardItems),
       rewardSkillXp = Map<ContentId, int>.unmodifiable(rewardSkillXp),
       revealedRumors = List<ContentId>.unmodifiable(revealedRumors);

  final ContentId contract;
  final ContentId location;

  /// Items removed, as literal amounts.
  final Map<ContentId, int> consumed;

  /// Items granted, as literal amounts.
  final Map<ContentId, int> rewardItems;

  /// Profession XP granted, profile-scaled, by skill.
  final Map<ContentId, int> rewardSkillXp;

  /// Character XP granted, profile-scaled. May be zero.
  final int characterXp;

  /// The character's total after the award; the reducer writes this, not a
  /// sum — and the level fields follow `EncounterWon`'s discipline.
  final int experienceAfter;
  final int levelBefore;
  final int levelAfter;

  /// This contract's completion count after this event.
  final int completionsAfter;

  /// Rumors this completion revealed (already-revealed ones are not listed).
  final List<ContentId> revealedRumors;

  /// For a local need: the location's board slots after rotation, and the
  /// deck index the next rotation draws from. Null for standing and regional
  /// contracts, whose boards do not rotate.
  final List<ContentId>? rotatedSlots;
  final int? rotatedNext;

  @override
  String get name => 'ContractCompleted';
}

/// Materials were contributed to a community project — removed immediately
/// and permanently — and, when the contribution filled the stage, the stage
/// (and possibly the whole project) completed in the same fact
/// (`DECISIONS/0023` §3). One event, one reducer branch: there is no instant
/// at which the planks are gone and the project has not received them, and
/// no way for a stage to complete twice.
@immutable
final class ProjectContributed extends GameEvent {
  ProjectContributed({
    required super.sequence,
    required this.project,
    required this.stage,
    required Map<ContentId, int> contributed,
    required Map<ContentId, int> stageContributedAfter,
    required this.stageCompleted,
    required this.projectCompleted,
    required this.characterXp,
    required this.experienceAfter,
    required this.levelBefore,
    required this.levelAfter,
    List<ContentId> revealedRumors = const <ContentId>[],
  }) : contributed = Map<ContentId, int>.unmodifiable(contributed),
       stageContributedAfter = Map<ContentId, int>.unmodifiable(
         stageContributedAfter,
       ),
       revealedRumors = List<ContentId>.unmodifiable(revealedRumors);

  final ContentId project;

  /// The 0-based stage this contribution filled into.
  final int stage;

  /// What this contribution donated, as literal amounts.
  final Map<ContentId, int> contributed;

  /// The stage's total received materials after this contribution.
  /// Meaningless once [stageCompleted] — the next stage starts empty.
  final Map<ContentId, int> stageContributedAfter;

  /// Whether this contribution completed the stage.
  final bool stageCompleted;

  /// Whether the completed stage was the last — the project is done and its
  /// permanent effects hold from here, exactly once.
  final bool projectCompleted;

  /// Character XP granted — the stage award plus, on completion, the
  /// project's own — profile-scaled. Zero when the stage did not complete.
  final int characterXp;
  final int experienceAfter;
  final int levelBefore;
  final int levelAfter;

  /// Rumors revealed by project completion.
  final List<ContentId> revealedRumors;

  @override
  String get name => 'ProjectContributed';
}
