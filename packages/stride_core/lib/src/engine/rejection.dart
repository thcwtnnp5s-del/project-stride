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

  /// No such resource node exists in the loaded content.
  unknownResourceNode('unknown_resource_node'),

  /// No such recipe exists in the loaded content.
  unknownRecipe('unknown_recipe'),

  /// The player does not hold enough of one or more ingredients.
  insufficientIngredients('insufficient_ingredients'),

  /// No route runs from where the player is standing to where they asked to go.
  ///
  /// Distinct from [locationLocked] on purpose. Locked means "you have not
  /// opened this yet"; this means "you cannot get there **from here**" — the
  /// answer is a different first leg, not more progression.
  routeNotFound('route_not_found'),

  /// The destination requires an item the player does not hold.
  entryRequirementUnmet('entry_requirement_unmet'),

  /// The playable economy has already been re-based on this ledger, for the
  /// state version asked for or a later one.
  ///
  /// A refusal rather than a silent no-op: re-running the cutover would zero the
  /// player's balance a second time, and a command that can do that must say so
  /// out loud when it is asked to do it twice. Precise about *which* cutover:
  /// a v3 step re-bases a v2 epoch once and refuses a v3 epoch
  /// (`DECISIONS/0018`).
  economyEpochAlreadySet('economy_epoch_already_set'),

  /// The node exists, but not at the location the player is standing in.
  ///
  /// Travel is the answer, and travel costs steps — which is the point of the
  /// refusal rather than an inconvenience of it.
  resourceNodeNotHere('resource_node_not_here'),

  /// The gathering skill is below the node's required level.
  skillLevelTooLow('skill_level_too_low'),

  /// No tool of the required kind and tier is equipped.
  toolRequired('tool_required'),

  /// The engine has no content registry to validate against.
  contentNotLoaded('content_not_loaded'),

  /// No such enemy exists in the loaded content.
  unknownEnemy('unknown_enemy'),

  /// The enemy exists, but not at the location the player is standing in.
  enemyNotHere('enemy_not_here'),

  /// An encounter is already active. Refuses a second `StartEncounter`, and
  /// refuses gathering and travel until the fight is resolved
  /// (`GAME_BIBLE/COMBAT/02_COMBAT_SLICE_01.md` §8).
  encounterInProgress('encounter_in_progress'),

  /// The enemy was beaten here and stays driven off until the player moves
  /// (`DECISIONS/0020` §3).
  enemyDrivenOff('enemy_driven_off'),

  /// A combat action was issued with no encounter active.
  noEncounter('no_encounter'),

  /// The item is not a consumable that heals.
  notEdible('not_edible'),

  /// The player's HP is already full; eating would waste the food and the turn.
  healthFull('health_full'),

  /// A finite activity queue is already running; one at a time
  /// (`DECISIONS/0022`). Stop it or let it finish before starting another.
  activityQueueActive('activity_queue_active'),

  // -- Exploration & Progression Loop 01 (`DECISIONS/0023`) --------------------

  /// No such contract exists in the loaded content.
  unknownContract('unknown_contract'),

  /// The contract exists, but its board is at another location. Travel is the
  /// answer, and travel costs steps.
  contractNotHere('contract_not_here'),

  /// The contract exists at this board but is not currently offered: a
  /// one-time contract already completed, a local need not in the visible
  /// rotation, or an unmet prerequisite (a required contract, local-need
  /// history, or project).
  contractNotAvailable('contract_not_available'),

  /// Only bounty-bearing contracts are accepted; a delivery order is simply
  /// completed when the goods are handed over.
  contractNotAcceptable('contract_not_acceptable'),

  /// The bounty is already accepted; victories are already counting.
  contractAlreadyAccepted('contract_already_accepted'),

  /// The bounty's qualifying victories have not been counted yet — either the
  /// contract was never accepted, or the count since acceptance is short.
  bountyUnmet('bounty_unmet'),

  /// The contract requires holding an item the player does not have. Distinct
  /// from [insufficientIngredients]: nothing would be consumed, the board
  /// only asks to see it.
  requirementNotOwned('requirement_not_owned'),

  /// No such community project exists in the loaded content.
  unknownProject('unknown_project'),

  /// The project exists, but at another location. Contributions are made in
  /// person.
  projectNotHere('project_not_here'),

  /// The project is already complete; nothing more can be contributed.
  projectComplete('project_complete'),

  /// A contribution named a non-positive amount, an item the stage does not
  /// need or has already received in full, or more than the player holds.
  /// Refused with zero mutation.
  invalidContribution('invalid_contribution'),

  /// The recipe exists but is not currently craftable: not yet unlocked by
  /// its project or contract, or retired by a completed project.
  recipeLocked('recipe_locked'),

  /// The node exists but its project has not been completed.
  nodeLocked('node_locked'),

  /// A goal-tracker target does not fit its slot: a Journey that is not a
  /// location, a Pursuit that is not an item, a Contract that is neither a
  /// contract nor a project — or an id the content pack does not know.
  invalidGoal('invalid_goal'),

  /// A normalized sync batch violated an invariant.
  ///
  /// An adapter fault rather than a player action, but returned rather than
  /// thrown: a malformed batch must not take the app down, and the app needs to
  /// be able to skip it and carry on.
  malformedSyncBatch('malformed_sync_batch');

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
