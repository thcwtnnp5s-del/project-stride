import 'package:meta/meta.dart';

import '../content/content_id.dart';
import '../content/definitions.dart';
import '../steps/sync_batch.dart';

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
