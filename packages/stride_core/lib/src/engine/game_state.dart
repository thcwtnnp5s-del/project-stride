import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../content/content_id.dart';
import '../content/definitions.dart';
import '../steps/step_ledger.dart';
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
  }) : unlockedLocations = _frozenIdSet(unlockedLocations);

  final ContentId currentLocation;
  final Set<ContentId> unlockedLocations;

  bool isUnlocked(ContentId location) => unlockedLocations.contains(location);

  WorldState unlocking(ContentId location) => WorldState(
    currentLocation: currentLocation,
    unlockedLocations: <ContentId>{...unlockedLocations, location},
  );

  WorldState movingTo(ContentId location) => WorldState(
    currentLocation: location,
    unlockedLocations: unlockedLocations,
  );

  @override
  bool operator ==(Object other) =>
      other is WorldState &&
      other.currentLocation == currentLocation &&
      const SetEquality<ContentId>().equals(
        other.unlockedLocations,
        unlockedLocations,
      );

  @override
  int get hashCode => Object.hash(
    currentLocation,
    const SetEquality<ContentId>().hash(unlockedLocations),
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
      other.eventSequence == eventSequence;

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
  );

  /// A stable, human-readable fingerprint.
  ///
  /// Used by determinism and replay tests, where comparing two signatures is a
  /// far more legible failure than comparing two object graphs.
  String get signature {
    final StringBuffer buffer = StringBuffer()
      ..write('v$stateVersion;profile=$profileId;seq=$eventSequence;')
      ..write('lvl=${player.level};xp=${player.experience};')
      ..write('steps=(${steps.signature});')
      ..write('at=${world.currentLocation};')
      ..write('open=${world.unlockedLocations.join(',')};')
      ..write(
        'inv=${inventory.counts.entries.map((MapEntry<ContentId, int> e) => '${e.key}x${e.value}').join(',')};',
      )
      ..write(
        'eq=${equipment.bySlot.entries.map((MapEntry<EquipmentSlot, ContentId> e) => '${e.key.name}=${e.value}').join(',')};',
      )
      ..write(
        'skills=${skills.experienceBySkill.entries.map((MapEntry<ContentId, int> e) => '${e.key}=${e.value}').join(',')}',
      );
    return buffer.toString();
  }

  @override
  String toString() => 'GameState($signature)';
}
