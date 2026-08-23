import 'package:meta/meta.dart';

import '../content/content_id.dart';
import '../content/definitions.dart';
import '../steps/sync_batch.dart';
import 'game_state.dart';

/// Something the player (or a system) wants to happen.
///
/// ## Commands are not events
///
/// A command is a *request*, and may be refused: equipping an item you do not
/// own, entering a location you have not unlocked, spending steps you have not
/// walked. An event is a *fact* that has already been accepted, and applying it
/// can never fail.
///
/// Keeping them separate is what lets the reducer be total. If commands were
/// applied directly, every reducer branch would need to re-check validity, and
/// replaying a saved sequence could produce a different answer than the first
/// run — which would make saves and replay untrustworthy in the same stroke.
@immutable
sealed class GameCommand {
  const GameCommand();

  /// A stable identifier for logging and test naming. Not localized, not shown
  /// to a player.
  String get name;

  /// Whether a player-facing surface may issue this command.
  ///
  /// False for commands that exist to drive the engine from tests, debug tools,
  /// or future internal systems. A UI that offered one of these would let the
  /// player grant themselves progress or open the world.
  ///
  /// Enforced by [playerFacing] and by test, not by convention.
  bool get isPlayerFacing => true;

  /// The commands a player-facing surface may offer.
  ///
  /// Filtering here rather than at each call site means a new internal command
  /// is excluded by default: forgetting to mark one is a visible test failure,
  /// where forgetting to exclude one would be silent.
  static List<GameCommand> playerFacing(Iterable<GameCommand> commands) =>
      commands.where((GameCommand c) => c.isPlayerFacing).toList();
}

/// Commit banked steps to progress.
///
/// F-03 has no activities to commit them *to* — that is F-04 and beyond. What
/// this proves is the arithmetic and the refusal: allocating more than the
/// player has banked must be rejected, not thrown.
@immutable
final class AllocateSteps extends GameCommand {
  const AllocateSteps({required this.steps});

  final int steps;

  @override
  String get name => 'AllocateSteps';
}

/// Add steps to the ledger without a health source.
///
/// **A system command, not a player action.** Real steps arrive through
/// reconciliation from HealthKit or Health Connect (S-01, S-01b). This exists so
/// that F-03 can exercise the ledger deterministically, and so that the debug
/// step injector (S-05) has a legitimate entry point rather than reaching into
/// state directly.
///
/// ## Why a back door here is safe
///
/// This is the shape of a thing that quietly survives into production and lets
/// someone grant themselves progress, so two properties keep it honest:
///
/// * It is a **command**, subject to the same validation and the same reducer
///   as everything else. A path that bypassed the pipeline would behave
///   differently from the real one, which is the one thing a test harness must
///   never do.
/// * [reason] is **mandatory and recorded on the event**, so a state built from
///   synthetic steps can never be mistaken for one built from real walking.
///
/// Neither is incidental. See `DESIGN_REVIEW_F03.md`, finding CR-1.
@immutable
final class GrantSyntheticSteps extends GameCommand {
  @override
  bool get isPlayerFacing => false;

  const GrantSyntheticSteps({required this.steps, required this.reason});

  final int steps;

  /// Why these steps exist, recorded so a state can never be mistaken for one
  /// built from real walking.
  final String reason;

  @override
  String get name => 'GrantSyntheticSteps';
}

/// Wear or wield an owned item.
@immutable
final class EquipItem extends GameCommand {
  const EquipItem({required this.item});

  final ContentId item;

  @override
  String get name => 'EquipItem';
}

/// Remove whatever occupies a slot.
@immutable
final class UnequipItem extends GameCommand {
  const UnequipItem({required this.slot});

  final EquipmentSlot slot;

  @override
  String get name => 'UnequipItem';
}

/// Open a location for travel.
///
/// **Internal and test-only.** Marked so by owner instruction closing F-03: it
/// must not reach a player command surface, and [isPlayerFacing] is false.
///
/// In the real game an unlock is a *consequence* — of arriving somewhere, of
/// crafting the item a gate requires. That unlock-condition system is
/// deliberately deferred; what is retained meanwhile is the
/// [LocationUnlocked] event, so when real conditions arrive they emit the same
/// fact through the same reducer and nothing downstream changes.
@immutable
final class UnlockLocation extends GameCommand {
  @override
  bool get isPlayerFacing => false;

  const UnlockLocation({required this.location});

  final ContentId location;

  @override
  String get name => 'UnlockLocation';
}

/// Move to an already-unlocked location, free.
///
/// **Internal since Phase 2.** [TravelTo] is the player's way of moving, and it
/// charges. This one is retained because tests, the debug harness, and the
/// reachability model all need a way to place the player somewhere without
/// buying the journey — but a surface that offered it would hand the player free
/// travel in a game whose central claim is that distance costs walking.
///
/// The `isPlayerFacing` flag is what enforces that, and the classification test
/// is what enforces the flag.
@immutable
final class EnterLocation extends GameCommand {
  @override
  bool get isPlayerFacing => false;

  const EnterLocation({required this.location});

  final ContentId location;

  @override
  String get name => 'EnterLocation';
}

/// Walk a route, paying for it out of banked steps.
///
/// **The command the World screen was missing.** `OD-02` named its absence as
/// the first of two dependencies blocking a geographic world: a map whose whole
/// point is that places are far apart needs a system that can cross the
/// distance, or it is describing lengths nothing can traverse.
///
/// ## What makes a journey legal
///
/// Adjacency, not unlock state. A destination is reachable when the location the
/// player is standing in declares a connection to it — so the content graph is
/// the authority on what the world looks like, and no caller can fabricate a
/// route by naming two places. Arriving is what unlocks a location, which is why
/// travelling somewhere new is possible and travelling somewhere impossible is
/// not.
///
/// ## Why the cost is not a parameter
///
/// Same reason as [GatherResource]: it is read from the connection and scaled by
/// the active balance profile inside the engine. A caller-supplied cost would let
/// a UI decide what distance is worth.
@immutable
final class TravelTo extends GameCommand {
  const TravelTo({required this.destination});

  final ContentId destination;

  @override
  String get name => 'TravelTo';
}

/// Turn held materials into an item.
///
/// Crafting **costs no steps** (`GAME_BIBLE/SYSTEMS/04_CRAFTING_SYSTEM_
/// FRAMEWORK.md`) — the steps were already spent gathering the materials, and
/// charging again would make the Craft screen a toll booth between the player
/// and a reward they have already walked for.
///
/// The consequence is a rule worth stating: **any recipe the player can afford
/// in materials is craftable at any step balance**, including zero. That is what
/// keeps "steps gate rate, never access" honest, and it is the answer the game
/// has for a player who cannot walk this week (`Q-01`).
@immutable
final class CraftItem extends GameCommand {
  const CraftItem({required this.recipe});

  final ContentId recipe;

  @override
  String get name => 'CraftItem';
}

/// Re-base the playable step economy at a cutover point.
///
/// **Internal, and issued from exactly one place**: the bootstrap migration
/// path, for each `StateMigrations` step that declares `rebasesEconomy`
/// (`DECISIONS/0016` for state version 2, `DECISIONS/0018` for state version
/// 3). It is not a player action, not a debug action, and not something a
/// surface may offer — a command that zeroes the player's balance must have
/// exactly one caller.
///
/// ## Why exactly-once is the state version, and not a flag beside it
///
/// The temptation is to add an `epochEstablished` boolean and guard on it. That
/// would be a second mechanism recording the same fact, and two mechanisms
/// recording one fact are two mechanisms that will eventually disagree.
///
/// The state version already carries it, durably: the save on disk declares its
/// version, `SaveRepository` refuses a slot whose header and payload disagree
/// about it, and the migration writes a state at the current version. A second
/// launch reads a current-version save, [StateVersion.migrationRequired] is
/// false, and this command is never issued.
///
/// ## The defence behind the version
///
/// The command also refuses on its own evidence: the epoch it finds records the
/// state version whose step established it (`EconomyEpoch.
/// establishedAtStateVersion`), and the command refuses whenever that is at or
/// beyond [toStateVersion]. So the v3 step re-bases a v2 epoch exactly once and
/// refuses a v3 epoch; the v2 step re-bases the origin exactly once and refuses
/// a v2 epoch. This is what a second cutover needed that "refuse any non-origin
/// epoch" could not give — and it is still defence *behind* the version, not a
/// second source of truth.
///
/// Crash safety falls out of the same property. If the commit never lands, the
/// old-version save is still on disk and the next launch recomputes an identical
/// migration from identical inputs — this command is a pure function of the
/// ledger it is handed.
@immutable
final class EstablishEconomyEpoch extends GameCommand {
  @override
  bool get isPlayerFacing => false;

  const EstablishEconomyEpoch({
    required this.fromStateVersion,
    required this.toStateVersion,
  }) : assert(
         toStateVersion > fromStateVersion,
         'a migration step moves the state version forward',
       );

  /// The version the save was read at, recorded on the event for diagnosis.
  final int fromStateVersion;

  /// The version this step establishes the epoch for. Recorded on the epoch as
  /// `establishedAtStateVersion`, and the figure the exactly-once guard reads.
  final int toStateVersion;

  @override
  String get name => 'EstablishEconomyEpoch';
}

/// Retire everything a brand-new game's first authorised reconcile observed,
/// so the game begins spendable-zero (`DECISIONS/0019`).
///
/// **Internal, and issued from exactly one place**: `StrideSession`, after the
/// first successful, authorised foreground sync of a game whose epoch is still
/// the origin. A fresh install has no save to migrate, so 0018 cannot reach it
/// — and without this the first sync would bank the health store's retention
/// window as currency the player never walked *for the game*.
///
/// ## Exactly-once is the epoch itself
///
/// Accepted only while `epoch.isOrigin`. The event it produces moves the mark
/// off the origin, so a second attempt is refused by the state alone — no flag,
/// no counter, no version bump. Pure over the ledger it is handed: a crash
/// between the sync's commit and this one is followed by a launch that reads
/// the same totals and computes the same mark.
@immutable
final class EstablishNewGameBaseline extends GameCommand {
  @override
  bool get isPlayerFacing => false;

  const EstablishNewGameBaseline({required this.stateVersion});

  /// The running state version, recorded on the epoch as
  /// `establishedAtStateVersion` so a later migration step (which only
  /// re-bases marks established at an *older* version) leaves this mark alone
  /// until it means to move it.
  final int stateVersion;

  @override
  String get name => 'EstablishNewGameBaseline';
}

/// Begin a fresh playtest (`DECISIONS/0025`): the spendable balance and the
/// player-facing walked count start again from zero, and with [freshStart]
/// so does the game — while the step ledger's history, dedupe and cursor
/// stay exactly as they are.
///
/// Player-facing, deliberately: this is the owner's own control, behind a
/// confirmation, on the Character tab. It is the one re-basing that is not a
/// migration step, and it is allowed to run more than once — each run is a
/// deliberate, confirmed act, never time, absence, or a side effect.
///
/// Refused while a fight is on or a queue is running, unless [freshStart],
/// which discards both as part of beginning again.
@immutable
final class ResetPlaytest extends GameCommand {
  const ResetPlaytest({required this.freshStart, required this.stateVersion});

  /// Also return the game state — bag, gear, skills, character, world,
  /// progression — to new. False resets only the two baselines.
  final bool freshStart;

  /// The running state version, recorded on the epoch as
  /// `establishedAtStateVersion`.
  final int stateVersion;

  @override
  String get name => 'ResetPlaytest';
}

/// Work a resource node once, paying for it out of banked steps.
///
/// **The first command that turns walking into something.** Until S-01A the
/// ledger had a debit path — [AllocateSteps] — and nothing to debit *for*: it
/// subtracted from `banked` and produced no item, no experience, and no reason
/// for a player to press it. That is why this exists as a distinct command
/// rather than as a caller pairing [AllocateSteps] with an inventory change.
/// Two commands would be two transactions, and a process killed between them
/// would leave the steps spent and the herbs not gathered.
///
/// ## Repeating, one node at a time
///
/// Gathering is a **repeating** activity (`ActivityKind.repeating`), and this
/// command is one repetition: one node's `stepCost`, one yield, one xp award.
/// The activity *scheduler* — which decides how a repetition is queued while
/// the player is away — is not S-01A, and building one here would be inventing
/// the part `DECISIONS/0006` says has to be designed rather than assumed.
///
/// ## Why the cost is not a parameter
///
/// It is read from content and scaled by the active balance profile, at
/// validation time, in the engine. A caller-supplied cost would let a UI, a
/// test, or a debug screen decide what walking is worth.
@immutable
final class GatherResource extends GameCommand {
  const GatherResource({required this.node});

  final ContentId node;

  @override
  String get name => 'GatherResource';
}

/// Begin a finite, player-initiated activity queue at a resource node
/// (`DECISIONS/0022`).
///
/// The **only** wall-clock progression in Project Stride, and the queue is the
/// named exception `RULES.md` P-4 carries. [nowEpochMillis] arrives **in** the
/// command — the core reads no clock, exactly as the health path's buckets
/// arrive as data.
///
/// Starting **spends nothing**. Every completed repetition is resolved later,
/// by [ReconcileActivityQueue], through the same validation and effects as
/// [GatherResource] — so walking remains the engine and a queue that runs out
/// of banked steps stops.
///
/// Refused when the node is unknown or not at the player's location, when the
/// gather prerequisites (skill level, equipped tool) are unmet, when
/// [requested] is below one, when a queue is already active, or during an
/// encounter.
@immutable
final class StartActivityQueue extends GameCommand {
  const StartActivityQueue({
    required this.node,
    required this.requested,
    required this.durationMillis,
    required this.nowEpochMillis,
  });

  final ContentId node;

  /// How many repetitions the player asked for. The queue's hard cap.
  final int requested;

  /// The authored duration of one repetition, in milliseconds. Presentation
  /// pacing carried in as data and frozen on the queue, so a later retune
  /// cannot re-time a queue already running.
  final int durationMillis;

  /// The wall-clock time the queue starts — the first repetition's anchor.
  final int nowEpochMillis;

  @override
  String get name => 'StartActivityQueue';
}

/// Resolve every repetition the elapsed wall-clock time has completed
/// (`DECISIONS/0022` §6).
///
/// **Internal.** Dispatched by the app's activity plumbing — on a repetition
/// boundary, on resume, on relaunch — never offered as a control. Safe to
/// issue at any time: with no queue, no elapsed repetition, or a backward
/// clock it is accepted with no events and commits nothing, so a second
/// reconcile immediately after a first is a no-op by construction.
///
/// Each completed repetition is validated and applied through the same path as
/// [GatherResource]. The first repetition that cannot legally complete stops
/// the queue there with the reason, keeping every prior completion.
@immutable
final class ReconcileActivityQueue extends GameCommand {
  @override
  bool get isPlayerFacing => false;

  const ReconcileActivityQueue({required this.nowEpochMillis});

  /// The wall-clock time of this reconciliation. Elapsed time is measured
  /// against the queue's anchor and clamped at zero — a clock that moved
  /// backwards completes nothing and moves nothing (`DECISIONS/0022` §6).
  final int nowEpochMillis;

  @override
  String get name => 'ReconcileActivityQueue';
}

/// Stop the activity queue (`DECISIONS/0022` §7).
///
/// Reconciles elapsed time first — fully-elapsed repetitions commit exactly as
/// [ReconcileActivityQueue] would commit them — then clears the queue
/// regardless. The partial current repetition commits nothing. With no queue
/// active it is accepted with no events, so the app's exclusive-command seam
/// can issue it unconditionally.
@immutable
final class StopActivityQueue extends GameCommand {
  const StopActivityQueue({required this.nowEpochMillis});

  /// The wall-clock time of the stop, for the closing reconciliation.
  final int nowEpochMillis;

  @override
  String get name => 'StopActivityQueue';
}

/// Reconcile a normalized provider response against the ledger.
///
/// **Internal.** Real syncs are driven by the app's platform adapter, not by
/// anything a player taps. Marked so a player-facing surface cannot offer it.
///
/// The command carries an already-normalized [SyncResponse]. No HealthKit or
/// Health Connect type reaches the core: an adapter translates, and the core
/// reconciles whatever shape it is handed.
@immutable
final class ReconcileStepSync extends GameCommand {
  @override
  bool get isPlayerFacing => false;

  const ReconcileStepSync({required this.response});

  final SyncResponse response;

  @override
  String get name => 'ReconcileStepSync';
}

/// Begin a fight with an enemy at the player's location.
///
/// **Costs no steps** (`DECISIONS/0020` §3): the walk here was the price. What
/// stops a free, unlimited drop farm is the driven-off rule — after a victory
/// the enemy cannot be fought again at this location until the player moves,
/// and moving costs steps. Refused while an encounter is already active, when
/// the enemy is elsewhere, or when it has been driven off here.
@immutable
final class StartEncounter extends GameCommand {
  const StartEncounter({required this.enemy});

  final ContentId enemy;

  @override
  String get name => 'StartEncounter';
}

/// Strike the enemy. One round: the player's attack and the enemy's reply
/// resolve together, in one command and one commit (`DECISIONS/0020` §2).
@immutable
final class CombatAttack extends GameCommand {
  const CombatAttack();

  @override
  String get name => 'CombatAttack';
}

/// Eat one owned consumable to heal, spending the turn: the enemy still
/// replies. Refused when the item does not heal or HP is already full.
@immutable
final class CombatEat extends GameCommand {
  const CombatEat({required this.item});

  final ContentId item;

  @override
  String get name => 'CombatEat';
}

/// Leave the fight. The player is moved to the nearest safe location and
/// nothing else changes; the enemy is *not* driven off (`DECISIONS/0020` §4).
@immutable
final class CombatRetreat extends GameCommand {
  const CombatRetreat();

  @override
  String get name => 'CombatRetreat';
}

// -- Exploration & Progression Loop 01 (`DECISIONS/0023`) ----------------------

/// Eat one owned consumable **outside combat** to heal (`DECISIONS/0023` §4).
///
/// Refused during an encounter — [CombatEat] is the in-fight path and spends
/// the turn; this one spends nothing but the food. Refused at full HP so a
/// tap cannot waste a meal, and refused for items that do not heal.
@immutable
final class EatFood extends GameCommand {
  const EatFood({required this.item});

  final ContentId item;

  @override
  String get name => 'EatFood';
}

/// Set or clear one tracked-objective slot (`DECISIONS/0023` §1).
///
/// Informative, never escrow: accepting a Journey reserves nothing, and
/// switching slots changes no economy figure. [target] null clears the slot.
@immutable
final class TrackGoal extends GameCommand {
  const TrackGoal({required this.slot, this.target});

  final GoalSlot slot;
  final ContentId? target;

  @override
  String get name => 'TrackGoal';
}

/// Accept a bounty contract, so qualifying victories start counting
/// (`DECISIONS/0023` §2; brief §79 — only victories **after acceptance**
/// count). Refused for contracts without a bounty: a delivery order needs no
/// acceptance, it is completed the moment the goods are handed over.
@immutable
final class AcceptContract extends GameCommand {
  const AcceptContract({required this.contract});

  final ContentId contract;

  @override
  String get name => 'AcceptContract';
}

/// Complete a contract at its board: exact items removed, exact rewards
/// granted, completion recorded — one event, one commit, exactly once
/// (`DECISIONS/0023` §2). A shortfall of any kind refuses with zero mutation.
@immutable
final class CompleteContract extends GameCommand {
  const CompleteContract({required this.contract});

  final ContentId contract;

  @override
  String get name => 'CompleteContract';
}

/// Contribute materials to a community project's current stage
/// (`DECISIONS/0023` §3). Partial contributions are the point: the amounts
/// are explicit, validated against what is held and what the stage still
/// needs, removed immediately and permanently, and never withdrawable. Stage
/// and project completion ride the same event when the contribution fills
/// the stage.
@immutable
final class ContributeToProject extends GameCommand {
  ContributeToProject({required this.project, required Map<ContentId, int> contributions})
    : contributions = Map<ContentId, int>.unmodifiable(contributions);

  final ContentId project;

  /// Item → amount to donate. Every entry must be positive, held, and still
  /// needed by the current stage.
  final Map<ContentId, int> contributions;

  @override
  String get name => 'ContributeToProject';
}
