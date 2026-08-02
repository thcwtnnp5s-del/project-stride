import 'package:meta/meta.dart';

import 'game_state.dart';
import 'events.dart';

/// Why a command was refused.
///
/// ## Stable codes
///
/// The wire string is part of the contract, like a content ID. UI copy,
/// analytics, and tests all key off it, so a code may be added but never
/// renamed — a renamed code silently stops matching everywhere it was handled.
///
/// The human-readable message may change freely.
enum RejectionCode {
  /// Not enough banked steps for the requested allocation.
  insufficientSteps('insufficient_steps'),

  /// The requested amount was zero or negative.
  invalidAmount('invalid_amount'),

  /// No such item exists in the loaded content.
  unknownItem('unknown_item'),

  /// The item exists but the player does not have it.
  itemNotOwned('item_not_owned'),

  /// The item cannot be equipped, or names no slot.
  invalidEquipmentSlot('invalid_equipment_slot'),

  /// The slot is already empty.
  slotEmpty('slot_empty'),

  /// No such location exists in the loaded content.
  unknownLocation('unknown_location'),

  /// The location exists but has not been unlocked.
  locationLocked('location_locked'),

  /// The location is already unlocked.
  locationAlreadyUnlocked('location_already_unlocked'),

  /// The player is already there.
  alreadyAtLocation('already_at_location'),

  /// The engine has no content registry to validate against.
  contentNotLoaded('content_not_loaded');

  const RejectionCode(this.wire);

  /// The stable identifier. Never rename one of these.
  final String wire;
}

/// A refused command, with enough context to explain it.
///
/// ## Why this is returned and not thrown
///
/// Equipping an item you do not own is not an error — it is a normal thing a
/// player or a UI will attempt, and the game must answer calmly. Exceptions are
/// for programming faults: a null where one is impossible, a state version that
/// cannot exist. Conflating the two means either wrapping ordinary gameplay in
/// try/catch, or letting a genuine bug hide inside a handled failure.
@immutable
final class CommandRejection {
  const CommandRejection({
    required this.code,
    required this.command,
    required this.explanation,
    this.subject,
  });

  final RejectionCode code;

  /// The command's [GameCommand.name], for logs and test output.
  final String command;

  /// What was being acted on — usually a content ID.
  final String? subject;

  /// A sentence describing the refusal. Free to change; [code] is the contract.
  final String explanation;

  String format() =>
      '${code.wire}: $explanation${subject == null ? '' : ' ($subject)'}';

  @override
  String toString() => format();
}

/// What the engine returns from a command.
///
/// Either events and a new state, or a rejection and the **unchanged** state.
/// A rejection never produces a partial change: the sealed shape makes
/// "rejected but also modified" unrepresentable rather than merely discouraged.
@immutable
sealed class EngineResult {
  const EngineResult({required this.state});

  /// The state after the command. On rejection this is the state before it,
  /// identical in every field.
  final GameState state;

  bool get isAccepted => this is AcceptedResult;
  bool get isRejected => this is RejectedResult;

  /// The events produced, empty when rejected.
  List<GameEvent> get events => switch (this) {
    AcceptedResult(:final List<GameEvent> events) => events,
    RejectedResult() => const <GameEvent>[],
  };

  /// The rejection, or null when accepted.
  CommandRejection? get rejection => switch (this) {
    AcceptedResult() => null,
    RejectedResult(:final CommandRejection rejection) => rejection,
  };
}

@immutable
final class AcceptedResult extends EngineResult {
  AcceptedResult({required super.state, required List<GameEvent> events})
    : events = List<GameEvent>.unmodifiable(events);

  @override
  final List<GameEvent> events;
}

@immutable
final class RejectedResult extends EngineResult {
  const RejectedResult({required super.state, required this.rejection});

  @override
  final CommandRejection rejection;
}
