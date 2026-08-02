import 'package:meta/meta.dart';

import '../content/content_id.dart';
import '../content/definitions.dart';

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
/// **Temporary shape.** F-03 unlocks by command so the architecture can be
/// proven end to end. In the real game an unlock is a *consequence* — of
/// arriving somewhere, of crafting the item a gate requires — and leaving it as
/// a command the player issues would eventually let the UI unlock the world.
///
/// F-04 or the travel task should demote this to an internal effect
/// (`DESIGN_REVIEW_F03.md`, finding CD-2).
@immutable
final class UnlockLocation extends GameCommand {
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
