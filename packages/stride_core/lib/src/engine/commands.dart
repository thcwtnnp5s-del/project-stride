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

/// Move to an unlocked location.
///
/// No travel cost here. Travel consumes steps over time (`DECISIONS/0001`), and
/// that belongs with the activity model, not with the command that proves
/// movement is gated on being unlocked.
@immutable
final class EnterLocation extends GameCommand {
  const EnterLocation({required this.location});

  final ContentId location;

  @override
  String get name => 'EnterLocation';
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
