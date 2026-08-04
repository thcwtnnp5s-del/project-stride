import 'package:meta/meta.dart';

import 'content_id.dart';
import 'json_reader.dart';

/// What an item is for.
enum ItemCategory { material, equipment, consumable, quest }

/// Where a piece of equipment goes. Milestone 01 has three slots
/// (`DECISIONS/0004`); accessories are deferred.
enum EquipmentSlot { weapon, armor, tool }

/// What a tool can do. Gathering nodes require a kind, not a specific item, so
/// a Bronze Axe satisfies a node that a Training Axe also satisfies.
enum ToolKind { axe, pickaxe, none }

/// What a skill is for.
enum SkillCategory { gathering, production }

/// Whether an activity finishes or repeats.
///
/// Travel **terminates** — you arrive, and further steps bank. Gathering
/// **repeats** — you chop the next tree until the player's allocation is spent.
/// Conflating the two was review finding QA-1.
enum ActivityKind { terminating, repeating }

/// A thing the player can hold, wear, use, or spend.
@immutable
final class ItemDefinition {
  const ItemDefinition({
    required this.id,
    required this.displayName,
    required this.category,
    required this.tier,
    required this.stackable,
    this.slot,
    this.toolKind = ToolKind.none,
    this.power = 0,
    this.healing = 0,
    this.qaOnly = false,
  });

  final ContentId id;

  /// Shown to the player. Free to change at any time — it is never a reference
  /// key, and nothing in the game looks anything up by it.
  final String displayName;

  final ItemCategory category;

  /// Progression rank. 0 for starting and raw items, 1 for Bronze.
  final int tier;

  final bool stackable;
  final EquipmentSlot? slot;
  final ToolKind toolKind;

  /// Generic combat contribution. Weapons attack, armor defends.
  final int power;

  /// Health restored, for consumables.
  final int healing;

  /// Marks content that exists only for the accelerated QA profile. Production
  /// bundles referencing it are rejected.
  final bool qaOnly;

  static const Set<String> fields = <String>{
    'id',
    'displayName',
    'category',
    'tier',
    'stackable',
    'slot',
    'toolKind',
    'power',
    'healing',
    'qaOnly',
  };

  static ItemDefinition? read(JsonReader reader) {
    reader.rejectUnknownFields(fields);
    final ContentId id = reader.requireId('id', ContentNamespace.item);
    final ItemDefinition definition = ItemDefinition(
      id: id,
      displayName: reader.requireString('displayName'),
      category: reader
          .requireEnum<ItemCategory>('category', const <String, ItemCategory>{
            'material': ItemCategory.material,
            'equipment': ItemCategory.equipment,
            'consumable': ItemCategory.consumable,
            'quest': ItemCategory.quest,
          }),
      tier: reader.optionalInt('tier', min: 0, max: 20),
      stackable: reader.optionalBool('stackable', fallback: true),
      slot: reader.map.containsKey('slot')
          ? reader.requireEnum<EquipmentSlot>(
              'slot',
              const <String, EquipmentSlot>{
                'weapon': EquipmentSlot.weapon,
                'armor': EquipmentSlot.armor,
                'tool': EquipmentSlot.tool,
              },
            )
          : null,
      toolKind: reader.map.containsKey('toolKind')
          ? reader.requireEnum<ToolKind>('toolKind', const <String, ToolKind>{
              'axe': ToolKind.axe,
              'pickaxe': ToolKind.pickaxe,
              'none': ToolKind.none,
            })
          : ToolKind.none,
      power: reader.optionalInt('power', min: 0, max: 10000),
      healing: reader.optionalInt('healing', min: 0, max: 10000),
      qaOnly: reader.optionalBool('qaOnly'),
    );
    return reader.isComplete ? definition : null;
  }
}

/// A long-term mastery path.
@immutable
final class SkillDefinition {
  const SkillDefinition({
    required this.id,
    required this.displayName,
    required this.category,
    required this.maxLevel,
    required this.xpThresholds,
  });

  final ContentId id;
  final String displayName;
  final SkillCategory category;
  final int maxLevel;

  /// Cumulative XP needed to reach each level. Index 0 is level 1 and is always
  /// zero; the list has [maxLevel] entries and must strictly increase.
  final List<int> xpThresholds;

  /// The level [experience] buys, derived rather than stored.
  ///
  /// `SkillProgress` deliberately keeps experience and not levels: a stored
  /// level would disagree with the curve the first time a content pack retunes
  /// one, and the disagreement would be invisible. Deriving it here means the
  /// curve is the single authority, and the loader has already guaranteed the
  /// list is non-empty, starts at zero, strictly increases, and has [maxLevel]
  /// entries — so this needs no defensive branch for a malformed curve.
  int levelAt(int experience) {
    int level = 1;
    for (int i = 1; i < xpThresholds.length; i++) {
      if (experience < xpThresholds[i]) break;
      level = i + 1;
    }
    return level;
  }

  static const Set<String> fields = <String>{
    'id',
    'displayName',
    'category',
    'maxLevel',
    'xpThresholds',
  };

  static SkillDefinition? read(JsonReader reader) {
    reader.rejectUnknownFields(fields);
    final SkillDefinition definition = SkillDefinition(
      id: reader.requireId('id', ContentNamespace.skill),
      displayName: reader.requireString('displayName'),
      category: reader
          .requireEnum<SkillCategory>('category', const <String, SkillCategory>{
            'gathering': SkillCategory.gathering,
            'production': SkillCategory.production,
          }),
      maxLevel: reader.requireInt('maxLevel', min: 1, max: 99),
      xpThresholds: List<int>.unmodifiable(
        reader.intList('xpThresholds', min: 0),
      ),
    );
    return reader.isComplete ? definition : null;
  }
}

/// A place in the world.
@immutable
final class LocationDefinition {
  const LocationDefinition({
    required this.id,
    required this.displayName,
    required this.isSafe,
    required this.isStart,
    required this.connections,
    required this.entryRequirements,
    required this.resourceNodes,
  });

  final ContentId id;
  final String displayName;

  /// Where the player is returned to on defeat (`DECISIONS/0003`).
  final bool isSafe;

  /// Exactly one location is the start.
  final bool isStart;

  final List<LocationConnection> connections;

  /// Items the player must hold to enter. A requirement that can only be made
  /// from resources found here is a deadlock the reachability validator catches.
  final List<ContentId> entryRequirements;

  final List<ContentId> resourceNodes;

  static const Set<String> fields = <String>{
    'id',
    'displayName',
    'isSafe',
    'isStart',
    'connections',
    'entryRequirements',
    'resourceNodes',
  };

  static LocationDefinition? read(JsonReader reader) {
    reader.rejectUnknownFields(fields);
    final LocationDefinition definition = LocationDefinition(
      id: reader.requireId('id', ContentNamespace.location),
      displayName: reader.requireString('displayName'),
      isSafe: reader.optionalBool('isSafe'),
      isStart: reader.optionalBool('isStart'),
      connections: List<LocationConnection>.unmodifiable(
        reader.objectList<LocationConnection>(
          'connections',
          (JsonReader nested, int index) =>
              LocationConnection.read(nested, index),
        ),
      ),
      entryRequirements: List<ContentId>.unmodifiable(
        reader.idList('entryRequirements', ContentNamespace.item),
      ),
      resourceNodes: List<ContentId>.unmodifiable(
        reader.idList('resourceNodes', ContentNamespace.resourceNode),
      ),
    );
    return reader.isComplete ? definition : null;
  }
}

/// A travel route. Travel is a **terminating** activity.
@immutable
final class LocationConnection {
  const LocationConnection({required this.to, required this.stepCost});

  final ContentId to;

  /// Steps to walk it, before the balance profile is applied.
  final int stepCost;

  static const Set<String> fields = <String>{'to', 'stepCost'};

  static LocationConnection? read(JsonReader reader, int index) {
    reader.rejectUnknownFields(fields);
    final LocationConnection connection = LocationConnection(
      to: reader.requireId('to', ContentNamespace.location),
      stepCost: reader.requireInt('stepCost', min: 1, max: 1000000),
    );
    return reader.isComplete ? connection : null;
  }
}

/// Something to gather. Gathering is a **repeating** activity.
@immutable
final class ResourceNodeDefinition {
  const ResourceNodeDefinition({
    required this.id,
    required this.displayName,
    required this.skill,
    required this.requiredLevel,
    required this.requiredToolKind,
    required this.minimumToolTier,
    required this.yieldsItem,
    required this.yieldsQuantity,
    required this.stepCost,
    required this.xp,
  });

  final ContentId id;
  final String displayName;
  final ContentId skill;
  final int requiredLevel;

  /// The kind of tool needed, not a specific item — so any axe of sufficient
  /// tier works, and adding a better axe does not mean editing every node.
  final ToolKind requiredToolKind;
  final int minimumToolTier;

  final ContentId yieldsItem;
  final int yieldsQuantity;
  final int stepCost;
  final int xp;

  static const Set<String> fields = <String>{
    'id',
    'displayName',
    'skill',
    'requiredLevel',
    'requiredToolKind',
    'minimumToolTier',
    'yieldsItem',
    'yieldsQuantity',
    'stepCost',
    'xp',
  };

  static ResourceNodeDefinition? read(JsonReader reader) {
    reader.rejectUnknownFields(fields);
    final ResourceNodeDefinition definition = ResourceNodeDefinition(
      id: reader.requireId('id', ContentNamespace.resourceNode),
      displayName: reader.requireString('displayName'),
      skill: reader.requireId('skill', ContentNamespace.skill),
      requiredLevel: reader.optionalInt(
        'requiredLevel',
        fallback: 1,
        min: 1,
        max: 99,
      ),
      requiredToolKind: reader.map.containsKey('requiredToolKind')
          ? reader.requireEnum<ToolKind>(
              'requiredToolKind',
              const <String, ToolKind>{
                'axe': ToolKind.axe,
                'pickaxe': ToolKind.pickaxe,
                'none': ToolKind.none,
              },
            )
          : ToolKind.none,
      minimumToolTier: reader.optionalInt('minimumToolTier', min: 0, max: 20),
      yieldsItem: reader.requireId('yieldsItem', ContentNamespace.item),
      yieldsQuantity: reader.optionalInt(
        'yieldsQuantity',
        fallback: 1,
        min: 1,
        max: 1000,
      ),
      stepCost: reader.requireInt('stepCost', min: 1, max: 1000000),
      xp: reader.requireInt('xp', min: 0, max: 1000000),
    );
    return reader.isComplete ? definition : null;
  }
}

/// Turning materials into capability. Crafting costs no steps
/// (`GAME_BIBLE/SYSTEMS/04_CRAFTING_SYSTEM_FRAMEWORK.md`) — the steps were
/// already spent gathering.
@immutable
final class RecipeDefinition {
  const RecipeDefinition({
    required this.id,
    required this.displayName,
    required this.skill,
    required this.requiredLevel,
    required this.ingredients,
    required this.outputItem,
    required this.outputQuantity,
    required this.xp,
  });

  final ContentId id;
  final String displayName;
  final ContentId skill;
  final int requiredLevel;
  final List<RecipeIngredient> ingredients;
  final ContentId outputItem;
  final int outputQuantity;
  final int xp;

  static const Set<String> fields = <String>{
    'id',
    'displayName',
    'skill',
    'requiredLevel',
    'ingredients',
    'outputItem',
    'outputQuantity',
    'xp',
  };

  static RecipeDefinition? read(JsonReader reader) {
    reader.rejectUnknownFields(fields);
    final RecipeDefinition definition = RecipeDefinition(
      id: reader.requireId('id', ContentNamespace.recipe),
      displayName: reader.requireString('displayName'),
      skill: reader.requireId('skill', ContentNamespace.skill),
      requiredLevel: reader.optionalInt(
        'requiredLevel',
        fallback: 1,
        min: 1,
        max: 99,
      ),
      ingredients: List<RecipeIngredient>.unmodifiable(
        reader.objectList<RecipeIngredient>(
          'ingredients',
          (JsonReader nested, int index) =>
              RecipeIngredient.read(nested, index),
        ),
      ),
      outputItem: reader.requireId('outputItem', ContentNamespace.item),
      outputQuantity: reader.optionalInt(
        'outputQuantity',
        fallback: 1,
        min: 1,
        max: 1000,
      ),
      xp: reader.requireInt('xp', min: 0, max: 1000000),
    );
    return reader.isComplete ? definition : null;
  }
}

@immutable
final class RecipeIngredient {
  const RecipeIngredient({required this.item, required this.quantity});

  final ContentId item;
  final int quantity;

  static const Set<String> fields = <String>{'item', 'quantity'};

  static RecipeIngredient? read(JsonReader reader, int index) {
    reader.rejectUnknownFields(fields);
    final RecipeIngredient ingredient = RecipeIngredient(
      item: reader.requireId('item', ContentNamespace.item),
      quantity: reader.optionalInt('quantity', fallback: 1, min: 1, max: 10000),
    );
    return reader.isComplete ? ingredient : null;
  }
}

/// Something to fight.
@immutable
final class EnemyDefinition {
  const EnemyDefinition({
    required this.id,
    required this.displayName,
    required this.location,
    required this.health,
    required this.attack,
    required this.defence,
    required this.isBoss,
    required this.drops,
  });

  final ContentId id;
  final String displayName;
  final ContentId location;
  final int health;
  final int attack;
  final int defence;
  final bool isBoss;
  final List<EnemyDrop> drops;

  static const Set<String> fields = <String>{
    'id',
    'displayName',
    'location',
    'health',
    'attack',
    'defence',
    'isBoss',
    'drops',
  };

  static EnemyDefinition? read(JsonReader reader) {
    reader.rejectUnknownFields(fields);
    final EnemyDefinition definition = EnemyDefinition(
      id: reader.requireId('id', ContentNamespace.enemy),
      displayName: reader.requireString('displayName'),
      location: reader.requireId('location', ContentNamespace.location),
      health: reader.requireInt('health', min: 1, max: 1000000),
      attack: reader.requireInt('attack', min: 0, max: 100000),
      defence: reader.requireInt('defence', min: 0, max: 100000),
      isBoss: reader.optionalBool('isBoss'),
      drops: List<EnemyDrop>.unmodifiable(
        reader.objectList<EnemyDrop>(
          'drops',
          (JsonReader nested, int index) => EnemyDrop.read(nested, index),
        ),
      ),
    );
    return reader.isComplete ? definition : null;
  }
}

@immutable
final class EnemyDrop {
  const EnemyDrop({
    required this.item,
    required this.quantity,
    required this.chancePercent,
  });

  final ContentId item;
  final int quantity;

  /// Whole percent, 1–100. Not a double: floating point in content invites
  /// values that differ between platforms, and the simulation is deterministic.
  final int chancePercent;

  static const Set<String> fields = <String>{
    'item',
    'quantity',
    'chancePercent',
  };

  static EnemyDrop? read(JsonReader reader, int index) {
    reader.rejectUnknownFields(fields);
    final EnemyDrop drop = EnemyDrop(
      item: reader.requireId('item', ContentNamespace.item),
      quantity: reader.optionalInt('quantity', fallback: 1, min: 1, max: 1000),
      chancePercent: reader.requireInt('chancePercent', min: 1, max: 100),
    );
    return reader.isComplete ? drop : null;
  }
}
