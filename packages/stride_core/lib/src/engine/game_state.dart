import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../content/content_id.dart';
import '../content/definitions.dart';
import '../steps/step_ledger.dart';
import 'combat.dart';
import 'state_version.dart';

/// Deep-immutability helpers.
///
/// ## Why `final` is not enough
///
/// Dart gives none of Swift's value semantics. A `final Map` field is a
/// reference that cannot be *reassigned* — its contents remain fully mutable,
/// and it is still the same object the caller passed in. Two failures follow:
///
/// * a caller who keeps the map they constructed the state from can edit the
///   state afterwards, and
/// * a caller who reads a collection off a snapshot can edit it in place,
///   changing the engine and every other snapshot sharing that reference.
///
/// Both are silent. The state simply disagrees with itself later, far from the
/// line that caused it. So every collection is **copied on construction and
/// exposed unmodifiable**: the copy severs the caller's reference, and the
/// wrapper turns a mutation attempt into an immediate `UnsupportedError`
/// instead of a corrupted save three sessions later.
/// Copies and freezes a map keyed by content ID, in sorted key order.
///
/// Sorted rather than insertion-ordered so that two states built by different
/// routes compare and serialize identically.
Map<ContentId, V> _frozenIdMap<V>(Map<ContentId, V> source) =>
    UnmodifiableMapView<ContentId, V>(SplayTreeMap<ContentId, V>.of(source));

Set<ContentId> _frozenIdSet(Iterable<ContentId> source) =>
    UnmodifiableSetView<ContentId>(SplayTreeSet<ContentId>.of(source));

/// Copies and freezes a slot-keyed map, ordered by slot.
///
/// Enums are not `Comparable` in Dart, so the order is imposed explicitly
/// rather than inherited.
Map<EquipmentSlot, ContentId> _frozenSlotMap(
  Map<EquipmentSlot, ContentId> source,
) {
  final List<MapEntry<EquipmentSlot, ContentId>> entries =
      source.entries.toList()..sort(
        (
          MapEntry<EquipmentSlot, ContentId> a,
          MapEntry<EquipmentSlot, ContentId> b,
        ) => a.key.index.compareTo(b.key.index),
      );
  return UnmodifiableMapView<EquipmentSlot, ContentId>(
    LinkedHashMap<EquipmentSlot, ContentId>.fromEntries(entries),
  );
}

/// The character.
@immutable
final class PlayerState {
  const PlayerState({required this.level, required this.experience});

  const PlayerState.initial() : level = 1, experience = 0;

  final int level;
  final int experience;

  PlayerState copyWith({int? level, int? experience}) => PlayerState(
    level: level ?? this.level,
    experience: experience ?? this.experience,
  );

  @override
  bool operator ==(Object other) =>
      other is PlayerState &&
      other.level == level &&
      other.experience == experience;

  @override
  int get hashCode => Object.hash(level, experience);
}

/// What the player is carrying, as counts keyed by content ID.
///
/// Stores IDs, never [ItemDefinition]s. State is the thin, serializable,
/// long-lived half; content is the fat, reloadable half. Embedding a definition
/// would mean a save carrying a stale copy of content that has since changed.
@immutable
final class Inventory {
  Inventory(Map<ContentId, int> counts) : counts = _frozenIdMap(counts);

  Inventory.empty() : counts = _frozenIdMap(const <ContentId, int>{});

  final Map<ContentId, int> counts;

  bool has(ContentId item, [int quantity = 1]) =>
      (counts[item] ?? 0) >= quantity;

  int quantityOf(ContentId item) => counts[item] ?? 0;

  /// Adds [quantity] of [item], returning a new inventory.
  Inventory adding(ContentId item, int quantity) {
    if (quantity <= 0) return this;
    return Inventory(<ContentId, int>{
      ...counts,
      item: quantityOf(item) + quantity,
    });
  }

  /// Removes [quantity], dropping the key when it reaches zero so that
  /// "absent" and "zero" cannot both exist and disagree.
  Inventory removing(ContentId item, int quantity) {
    if (quantity <= 0) return this;
    final int remaining = quantityOf(item) - quantity;
    final Map<ContentId, int> next = <ContentId, int>{...counts};
    if (remaining > 0) {
      next[item] = remaining;
    } else {
      next.remove(item);
    }
    return Inventory(next);
  }

  @override
  bool operator ==(Object other) =>
      other is Inventory &&
      const MapEquality<ContentId, int>().equals(other.counts, counts);

  @override
  int get hashCode => const MapEquality<ContentId, int>().hash(counts);
}

/// What the player is wearing or wielding.
@immutable
final class Equipment {
  Equipment(Map<EquipmentSlot, ContentId> bySlot)
    : bySlot = _frozenSlotMap(bySlot);

  Equipment.empty()
    : bySlot = _frozenSlotMap(const <EquipmentSlot, ContentId>{});

  final Map<EquipmentSlot, ContentId> bySlot;

  ContentId? inSlot(EquipmentSlot slot) => bySlot[slot];

  bool isEquipped(ContentId item) => bySlot.containsValue(item);

  Equipment equipping(EquipmentSlot slot, ContentId item) =>
      Equipment(<EquipmentSlot, ContentId>{...bySlot, slot: item});

  Equipment clearing(EquipmentSlot slot) =>
      Equipment(<EquipmentSlot, ContentId>{...bySlot}..remove(slot));

  @override
  bool operator ==(Object other) =>
      other is Equipment &&
      const MapEquality<EquipmentSlot, ContentId>().equals(
        other.bySlot,
        bySlot,
      );

  @override
  int get hashCode =>
      const MapEquality<EquipmentSlot, ContentId>().hash(bySlot);
}

/// Experience per skill. Levels are derived from content curves, never stored —
/// a stored level could disagree with the curve after a content change.
@immutable
final class SkillProgress {
  SkillProgress(Map<ContentId, int> experienceBySkill)
    : experienceBySkill = _frozenIdMap(experienceBySkill);

  SkillProgress.empty()
    : experienceBySkill = _frozenIdMap(const <ContentId, int>{});

  final Map<ContentId, int> experienceBySkill;

  int experienceIn(ContentId skill) => experienceBySkill[skill] ?? 0;

  SkillProgress adding(ContentId skill, int experience) {
    if (experience <= 0) return this;
    return SkillProgress(<ContentId, int>{
      ...experienceBySkill,
      skill: experienceIn(skill) + experience,
    });
  }

  @override
  bool operator ==(Object other) =>
      other is SkillProgress &&
      const MapEquality<ContentId, int>().equals(
        other.experienceBySkill,
        experienceBySkill,
      );

  @override
  int get hashCode =>
      const MapEquality<ContentId, int>().hash(experienceBySkill);
}

/// Where the player is and what they have opened up.
@immutable
final class WorldState {
  WorldState({
    required this.currentLocation,
    required Set<ContentId> unlockedLocations,
    Map<ContentId, int> visitVictories = const <ContentId, int>{},
  }) : unlockedLocations = _frozenIdSet(unlockedLocations),
       visitVictories = _frozenIdMap(visitVictories);

  final ContentId currentLocation;
  final Set<ContentId> unlockedLocations;

  /// How many times each enemy has been beaten *at [currentLocation]* since
  /// the player last moved (`DECISIONS/0021` §1). Emptied by every move — see
  /// [movingTo]. Unmodifiable, and sorted by id so two states built by
  /// different routes serialize identically.
  ///
  /// State version 5. It replaces the v4 `drivenOff` set, which was this map
  /// with the count fixed at one: an enemy authored `encountersPerVisit: 1` —
  /// every boss, and every pack that says nothing — behaves exactly as it did.
  ///
  /// **Not keyed by location**, for the same reason the set was not: it is
  /// only ever meaningful where the player stands, because any move empties
  /// it. A per-location map would be a second mechanism recording one fact,
  /// and it would let a player bank victories across a circuit of locations,
  /// which is the free drop farm the count exists to prevent.
  final Map<ContentId, int> visitVictories;

  bool isUnlocked(ContentId location) => unlockedLocations.contains(location);

  /// Victories over [enemy] during this visit. Zero when it has not been
  /// fought here since the last move.
  int victoriesThisVisit(ContentId enemy) => visitVictories[enemy] ?? 0;

  /// How many fights with [enemy] this visit still allows, given the enemy's
  /// authored [perVisit] count. Never negative.
  ///
  /// [perVisit] is passed in rather than looked up because `WorldState` holds
  /// no registry: state is the thin serializable half and content is the fat
  /// reloadable half, and a state that embedded a content figure would carry a
  /// stale copy of it into the next content pack.
  int remaining(ContentId enemy, int perVisit) {
    final int left = perVisit - victoriesThisVisit(enemy);
    return left < 0 ? 0 : left;
  }

  /// Whether [enemy] may still be fought here this visit.
  bool isAvailable(ContentId enemy, int perVisit) =>
      remaining(enemy, perVisit) > 0;

  WorldState unlocking(ContentId location) => WorldState(
    currentLocation: currentLocation,
    unlockedLocations: <ContentId>{...unlockedLocations, location},
    visitVictories: visitVictories,
  );

  /// Moves the player, and **empties [visitVictories]**.
  ///
  /// Every move clears the map — travel, a free `EnterLocation`, a retreat, a
  /// defeat — because the recurrence rule is *step-clocked through travel*:
  /// the only limiter on re-fighting an enemy past its per-visit count is that
  /// the player has to leave and come back, and leaving costs the walk
  /// (`RULES.md` P-4, `DECISIONS/0021` §1). A move that kept the counts would
  /// make some enemies unfightable after a round trip.
  WorldState movingTo(ContentId location) => WorldState(
    currentLocation: location,
    unlockedLocations: unlockedLocations,
  );

  /// Records one more victory over [enemy] here.
  ///
  /// It counts rather than marks, and it does not clamp against the enemy's
  /// authored figure: the count is a fact about what happened, and the *rule*
  /// about how many are allowed is the engine's, applied before the fight
  /// starts. Clamping here would put the same rule in two places.
  WorldState recordingVictory(ContentId enemy) => WorldState(
    currentLocation: currentLocation,
    unlockedLocations: unlockedLocations,
    visitVictories: <ContentId, int>{
      ...visitVictories,
      enemy: victoriesThisVisit(enemy) + 1,
    },
  );

  @override
  bool operator ==(Object other) =>
      other is WorldState &&
      other.currentLocation == currentLocation &&
      const SetEquality<ContentId>().equals(
        other.unlockedLocations,
        unlockedLocations,
      ) &&
      const MapEquality<ContentId, int>().equals(
        other.visitVictories,
        visitVictories,
      );

  @override
  int get hashCode => Object.hash(
    currentLocation,
    const SetEquality<ContentId>().hash(unlockedLocations),
    const MapEquality<ContentId, int>().hash(visitVictories),
  );
}

/// The whole game, as one immutable value.
///
/// Every field is either a primitive or a deeply frozen structure. A snapshot
/// handed to a caller can be held indefinitely: nothing the engine does later
/// changes it, and nothing the caller does changes the engine.
@immutable
final class GameState {
  GameState({
    required this.stateVersion,
    required this.profileId,
    required this.contentPackVersion,
    required this.player,
    required this.inventory,
    required this.equipment,
    required this.skills,
    required this.world,
    required this.steps,
    required this.eventSequence,
    this.encounter,
  }) {
    if (!StateVersion.supports(stateVersion)) {
      throw UnsupportedStateVersionException(stateVersion);
    }
  }

  final int stateVersion;

  /// The balance profile this state was created under.
  final ContentId profileId;

  /// The content schema the state was created against.
  final int contentPackVersion;

  final PlayerState player;
  final Inventory inventory;
  final Equipment equipment;
  final SkillProgress skills;
  final WorldState world;
  final StepLedger steps;

  /// The fight in progress, or null. State version 4 (`DECISIONS/0020`).
  ///
  /// While non-null, gathering and travel are refused and the Adventure tab
  /// renders the fight; a cold relaunch lands the player back in it because it
  /// is state, not navigation.
  final EncounterState? encounter;

  /// How many events have been applied. Monotonic, and the sequence number the
  /// next event will carry.
  ///
  /// Gives every event a stable identity, which is what makes replay verifiable
  /// and, later, what makes a crash mid-write detectable.
  final int eventSequence;

  GameState copyWith({
    PlayerState? player,
    Inventory? inventory,
    Equipment? equipment,
    SkillProgress? skills,
    WorldState? world,
    StepLedger? steps,
    int? eventSequence,
    EncounterState? encounter,
    bool clearEncounter = false,
  }) => GameState(
    stateVersion: stateVersion,
    profileId: profileId,
    contentPackVersion: contentPackVersion,
    player: player ?? this.player,
    inventory: inventory ?? this.inventory,
    equipment: equipment ?? this.equipment,
    skills: skills ?? this.skills,
    world: world ?? this.world,
    steps: steps ?? this.steps,
    eventSequence: eventSequence ?? this.eventSequence,
    // Nullable-aware: `null` means "keep", so ending a fight needs an explicit
    // flag rather than a null argument that is indistinguishable from absence.
    encounter: clearEncounter ? null : (encounter ?? this.encounter),
  );

  /// Restates this state at [StateVersion.current], changing nothing else.
  ///
  /// **The one way the version field may move**, and it is deliberately not part
  /// of [copyWith]. A version is a claim about the *shape* a state has, so a
  /// caller able to set it casually beside a player level could assert a shape
  /// the value does not have — and the save would then be read by a decoder
  /// expecting fields that were never written.
  ///
  /// Migration is the only legitimate reason to move it, so this is named for
  /// that and for nothing else. It performs no upgrade of its own: the fields a
  /// new version introduces already have their defaults by the time a decoder
  /// hands the state over, and the *meaning* of the migration is carried by the
  /// events committed alongside it.
  GameState migratedToCurrentVersion() => GameState(
    stateVersion: StateVersion.current.value,
    profileId: profileId,
    contentPackVersion: contentPackVersion,
    player: player,
    inventory: inventory,
    equipment: equipment,
    skills: skills,
    world: world,
    steps: steps,
    eventSequence: eventSequence,
    encounter: encounter,
  );

  @override
  bool operator ==(Object other) =>
      other is GameState &&
      other.stateVersion == stateVersion &&
      other.profileId == profileId &&
      other.contentPackVersion == contentPackVersion &&
      other.player == player &&
      other.inventory == inventory &&
      other.equipment == equipment &&
      other.skills == skills &&
      other.world == world &&
      other.steps == steps &&
      other.eventSequence == eventSequence &&
      other.encounter == encounter;

  @override
  int get hashCode => Object.hash(
    stateVersion,
    profileId,
    contentPackVersion,
    player,
    inventory,
    equipment,
    skills,
    world,
    steps,
    eventSequence,
    encounter,
  );

  // There is deliberately no `signature` getter here.
  //
  // There used to be: a hand-written summary string, used by determinism and
  // replay tests and — the part that mattered — by `SaveRepository` to decide
  // whether two save slots at the same snapshot generation had diverged.
  //
  // It was incomplete. It omitted `steps.checkpoint.cursor` and
  // `steps.checkpoint.originWatermarks`, and carried granted slices only as a
  // count. So two states differing in the durable sync position compared
  // equal, the equal-generation refusal did not fire, and an arbitrary slot was
  // chosen; pick the further cursor and the next sync resumes past steps the
  // chosen ledger never granted, silently and permanently.
  //
  // The replacement is `canonicalDurableGameState` in `save/durable_state.dart`
  // — the exact encoding a save file carries, complete by construction because
  // the codec must already persist every durable field. It lives beside the
  // codec rather than here on purpose: a convenience summary sitting where a
  // complete comparison is assumed is what caused the defect, and a property on
  // the state object is what invited the assumption.

  @override
  String toString() =>
      'GameState(v$stateVersion;profile=$profileId;seq=$eventSequence;'
      'lvl=${player.level};steps=(${steps.signature})'
      '${encounter == null ? '' : ';encounter=$encounter'})';
}
