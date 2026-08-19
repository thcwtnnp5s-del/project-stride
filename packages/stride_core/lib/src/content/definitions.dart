import 'package:meta/meta.dart';

import 'content_id.dart';
import 'json_reader.dart';

/// What an item is for.
enum ItemCategory { material, equipment, consumable, quest }

/// How hard an item was to come by. **`DECISIONS/0021` §4.**
///
/// ## What rarity is, and what it must never become
///
/// Rarity is **authored content and presentation metadata**. It says nothing
/// about what an item does: no random rolls, no affixes, no sockets, no item
/// level, no gear score, and no stat derived from the rank. A Rare sword hits
/// for exactly the `power` its definition gives it, and would hit for the same
/// figure if it were relabelled Common tomorrow. Anything else needs a new
/// decision (`DECISIONS/0021` §4), because it would turn an inventory label
/// into a progression system nobody designed.
///
/// It lives in `stride_core` rather than in a Flutter colour table for the
/// reason `SkillStanding` gives about level curves: inventory, crafting,
/// victory rewards, the encounter card and the atlas all read it, and a
/// property four surfaces read is a property that has to be testable without a
/// widget.
///
/// ## The order, exactly as the owner wrote it
///
/// Ascending by [rank]: **uncommon · common · rare · epic · legendary**.
///
/// That puts *Uncommon* **below** *Common*, which is the reverse of the
/// convention most RPGs use. It is deliberate and it is not a typo on this
/// side: the owner's rarity list named them in this order with these colours
/// (grey · green · blue · purple · orange), and an implementation that
/// "corrected" it would have silently made a design decision
/// (`RULES.md` G-3). If the names were meant the conventional way round, the
/// fix is a two-line swap in `items.json` and this doc comment — not a code
/// change. See `GAME_BIBLE/SYSTEMS/08_ITEM_RARITY.md`.
enum Rarity {
  /// Grey. Tier-0 gathered material: picked up in handfuls without a tool.
  uncommon('Uncommon'),

  /// Green. Processed, cooked, granted, or gathered behind a real requirement.
  common('Common'),

  /// Blue. Bronze-tier equipment and the materials only combat yields.
  rare('Rare'),

  /// Purple. The end of a chain: a boss token, the best armour authored.
  epic('Epic'),

  /// Orange. **Nothing carries it yet** — reserved so the enum, the style
  /// table and the tests all cover the rank before content needs it.
  legendary('Legendary');

  const Rarity(this.label);

  /// Shown to the player.
  final String label;

  /// Position in the ascending order, 0–4. Comparable across ranks; never a
  /// multiplier, a stat, or an input to any rule.
  int get rank => index;

  /// The string a content file writes, and the only spelling the loader
  /// accepts. Equal to the enum's own name so the two cannot drift.
  String get wireName => name;

  /// The lookup table the loader reads with, keyed by [wireName].
  ///
  /// Built from [values] rather than written out, so a new rank is authorable
  /// the moment it is declared and can never be silently unreadable.
  static Map<String, Rarity> get byWireName => <String, Rarity>{
    for (final Rarity r in Rarity.values) r.wireName: r,
  };
}

/// Where a piece of equipment goes. Milestone 01 has three slots
/// (`DECISIONS/0004`); accessories are deferred.
enum EquipmentSlot { weapon, armor, tool }

/// What a tool can do. Gathering nodes require a kind, not a specific item, so
/// a Bronze Axe satisfies a node that a Training Axe also satisfies.
enum ToolKind { axe, pickaxe, none }

/// What a skill is for.
enum SkillCategory { gathering, production }

/// The physical character of a place. **OD-02.**
///
/// ## Why this is content and not art
///
/// `OD-02` names the world's governing rule — *a coherent geographic and
/// economic system, not a collection of themed zones* — and then names the
/// dependency that has to come first: deciding what a region **is** in data
/// precedes drawing one. Terrain is that decision. It is what makes "oak grows
/// in the temperate forest and pine grows above the treeline" a fact the content
/// set holds, rather than a convention two authors happen to share.
///
/// It is deliberately **coarse**. Four values describe the whole first playable
/// slice, and a fifth would have to earn its place by changing what can be
/// expressed rather than by adding a word. A terrain vocabulary finer than the
/// world is a taxonomy pretending to be a model.
///
/// New values are added when a region needs one, not in advance. The eventual
/// arid, coastal and wetland regions are named in
/// `GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md` §8 as expansion exits, and
/// are deliberately absent here until something occupies them — an enum value no
/// content uses is a promise the code cannot keep.
enum Terrain {
  /// Open temperate lowland. River meadow, pasture, plain.
  grassland,

  /// Temperate broadleaf woodland. Closed canopy, damp floor.
  forest,

  /// The rising ground at the foot of a mountain range. Cut rock, thin scrub.
  foothills,

  /// At or above the treeline. Snow, frozen water, bare rock, cold conifer.
  alpine,
}

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
    required this.rarity,
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

  /// How hard this was to come by. **Required in content** (`DECISIONS/0021`).
  ///
  /// Required rather than defaulted so that "every item has a valid rarity"
  /// holds by construction rather than by a test that has to be remembered.
  /// A default would answer the question for an author who never asked it, and
  /// the wrong answer would be indistinguishable from a considered one.
  final Rarity rarity;

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
    'rarity',
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
      // Required, and refused when unknown: `requireEnum` reports a missing
      // field and an unrecognised value with the allowed list in the
      // suggestion, which is what makes an authoring slip a load error with a
      // fix in it rather than a silent grey label.
      rarity: reader.requireEnum<Rarity>('rarity', Rarity.byWireName),
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

/// Everything a surface needs to describe one skill's progress. **F-07.**
///
/// ## Why this type exists at all
///
/// A level is one number, and a screen that only ever showed a level would not
/// need it. What a progression screen actually shows is a *position between two
/// thresholds* — 340 XP into level 4, 220 to go — and computing that means
/// indexing `xpThresholds`, handling the top of the curve, and knowing that
/// index 0 is level 1.
///
/// That is rule math. Done in a widget it becomes a second implementation of
/// the curve, sitting beside the one the engine gates on, free to disagree the
/// first time a content pack retunes a skill (`RULES.md` E-2). So it is done
/// here, once, and projected.
///
/// Nothing is stored. Every field is derived from the experience handed in, for
/// the reason `SkillProgress` gives: a stored level would disagree with the
/// curve after a retune, and the disagreement would be invisible.
@immutable
final class SkillStanding {
  const SkillStanding({
    required this.skill,
    required this.displayName,
    required this.level,
    required this.maxLevel,
    required this.totalExperience,
    required this.experienceIntoLevel,
    required this.experienceForLevel,
  });

  final ContentId skill;
  final String displayName;

  /// The level the player has reached, 1-based.
  final int level;

  final int maxLevel;

  /// All experience ever earned in this skill. Keeps rising past [maxLevel].
  final int totalExperience;

  /// Experience earned since reaching [level]. Zero at a fresh level-up.
  ///
  /// At max level this keeps counting rather than freezing. The player is still
  /// earning; there is simply nothing left to buy, and a bar pinned at zero
  /// would say the opposite.
  final int experienceIntoLevel;

  /// Experience needed to cross from [level] to the next one, or null at
  /// [maxLevel].
  ///
  /// Null rather than zero, deliberately: zero is a legitimate span nowhere on
  /// this curve, and a caller dividing by it would produce infinity rather than
  /// a caught case. Null makes "there is no next level" impossible to read past.
  final int? experienceForLevel;

  bool get isMaxLevel => level >= maxLevel;

  /// Experience still to go, or null at [maxLevel].
  int? get experienceToNextLevel {
    final int? span = experienceForLevel;
    if (span == null) return null;
    final int remaining = span - experienceIntoLevel;
    return remaining < 0 ? 0 : remaining;
  }

  /// How far through the current level, 0.0–1.0. **1.0 at max level.**
  ///
  /// A full bar is the honest reading of a finished curve. An empty one would
  /// say "no progress" about the player who has made all of it.
  double get progress {
    final int? span = experienceForLevel;
    if (span == null || span <= 0) return 1;
    final double fraction = experienceIntoLevel / span;
    return fraction < 0
        ? 0
        : fraction > 1
        ? 1
        : fraction;
  }

  @override
  String toString() =>
      'SkillStanding($skill lvl $level/$maxLevel; $experienceIntoLevel'
      '${experienceForLevel == null ? '' : '/$experienceForLevel'} into level)';
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

  /// Cumulative experience required to *reach* [level], 1-based.
  ///
  /// Clamped at both ends rather than throwing. A level below 1 or above
  /// [maxLevel] is a caller error, but the honest answer to "what does level 0
  /// cost" is 0 and to "what does level 99 cost" is the top of the curve —
  /// neither is worth taking the game down for.
  int experienceForLevel(int level) {
    if (level <= 1) return 0;
    final int index = level - 1;
    return index >= xpThresholds.length
        ? xpThresholds.last
        : xpThresholds[index];
  }

  /// The full progression picture at [experience]. **F-07.**
  ///
  /// The one place the curve is read for display. See [SkillStanding] for why
  /// this is not a widget's job.
  SkillStanding standingAt(int experience) {
    final int level = levelAt(experience);
    final int floor = experienceForLevel(level);
    final bool atMax = level >= maxLevel;
    return SkillStanding(
      skill: id,
      displayName: displayName,
      level: level,
      maxLevel: maxLevel,
      totalExperience: experience,
      experienceIntoLevel: experience - floor,
      // The span of the *current* level: what the next one costs, less what this
      // one did. Null at the top, where there is no next one to span to.
      experienceForLevel: atMax ? null : experienceForLevel(level + 1) - floor,
    );
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
    required this.terrain,
    required this.isSafe,
    required this.isStart,
    required this.connections,
    required this.entryRequirements,
    required this.resourceNodes,
  });

  final ContentId id;
  final String displayName;

  /// What kind of ground this is. **Required**, deliberately.
  ///
  /// A location with no terrain is a place with no reason for its resources to
  /// be there, which is precisely what `OD-02` forbids. Making it required means
  /// the question is answered when a place is created rather than inferred later
  /// from what someone happened to put in it.
  final Terrain terrain;

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
    'terrain',
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
      terrain: reader.requireEnum<Terrain>('terrain', const <String, Terrain>{
        'grassland': Terrain.grassland,
        'forest': Terrain.forest,
        'foothills': Terrain.foothills,
        'alpine': Terrain.alpine,
      }),
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

/// How an enemy replies each round (`GAME_BIBLE/COMBAT/02_COMBAT_SLICE_01.md`
/// §6). Wire strings are `steady` | `flurry` | `guarded`.
enum EnemyBehavior {
  /// One strike a turn.
  steady,

  /// Two light strikes a turn.
  flurry,

  /// Turns 1 and 2 normal; every third turn a heavy strike, telegraphed at the
  /// end of the round before.
  guarded,
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
    this.behavior = EnemyBehavior.steady,
    this.xp = 0,
    this.encountersPerVisit = 1,
  });

  final ContentId id;
  final String displayName;
  final ContentId location;
  final int health;
  final int attack;
  final int defence;
  final bool isBoss;
  final List<EnemyDrop> drops;

  /// How the enemy replies each round. Optional in content; defaults to
  /// [EnemyBehavior.steady] (Combat Slice 01).
  final EnemyBehavior behavior;

  /// Character XP on victory, before the balance profile is applied. Optional
  /// in content; defaults to 0 (Combat Slice 01).
  final int xp;

  /// How many times this enemy may be beaten during **one visit** to its
  /// location. **`DECISIONS/0021` §1.**
  ///
  /// Optional in content and **1 by default**, which is exactly the
  /// `DECISIONS/0020` rule this field generalises: one victory and the enemy
  /// is driven off until the player moves. A content pack that says nothing
  /// therefore behaves as it always did.
  ///
  /// The counter it gates lives in `WorldState.visitVictories` and is emptied
  /// by every move, so the limiter is *travel* — steps — and never a clock
  /// (`RULES.md` P-4). A different recurrence policy for a boss needs no
  /// framework, only a smaller number: the Hollow Guardian authors `1`.
  ///
  /// Minimum 1. Zero would make an enemy that ships in a location and can
  /// never be fought — an unreachable card, which is a content mistake rather
  /// than a design, so the loader refuses it.
  final int encountersPerVisit;

  static const Set<String> fields = <String>{
    'id',
    'displayName',
    'location',
    'health',
    'attack',
    'defence',
    'isBoss',
    'drops',
    'behavior',
    'xp',
    'encountersPerVisit',
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
      behavior: reader.map.containsKey('behavior')
          ? reader.requireEnum<EnemyBehavior>(
              'behavior',
              const <String, EnemyBehavior>{
                'steady': EnemyBehavior.steady,
                'flurry': EnemyBehavior.flurry,
                'guarded': EnemyBehavior.guarded,
              },
            )
          : EnemyBehavior.steady,
      xp: reader.optionalInt('xp', min: 0, max: 1000000),
      encountersPerVisit: reader.optionalInt(
        'encountersPerVisit',
        fallback: 1,
        min: 1,
        max: 100,
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
