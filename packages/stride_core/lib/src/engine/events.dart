import 'package:meta/meta.dart';

import '../content/content_id.dart';
import '../content/definitions.dart';

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
