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
  /// Neutral. Ordinary and expected: starter gear, everyday materials, the
  /// food a first kitchen makes. The floor (PLAYABLE_POLISH_01 correction
  /// pass, owner ruling 2026-08-23 — this order supersedes the 2026-08-19
  /// one; `GAME_BIBLE/SYSTEMS/08_ITEM_RARITY.md`).
  common('Common'),

  /// Green. A useful, meaningful improvement: standard Bronze equipment, the
  /// food that heals properly.
  uncommon('Uncommon'),

  /// Blue. Genuinely exciting: signatures, enhanced equipment with a
  /// passive, the reward of a real contract or a real enemy.
  rare('Rare'),

  /// Purple. "I really needed this": a boss token, the best armour authored.
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
    this.frostGuard = 0,
    this.wildernessYieldPercent = 0,
    this.toolBonusYieldPercent = 0,
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

  /// Incoming-damage reduction in alpine-terrain fights while this armour is
  /// worn — the Frost-lined Jerkin's Cold Weather effect. Applied by the
  /// engine after the ordinary strike arithmetic, floored at 1 damage. A
  /// **narrow tagged modifier**, deliberately not a resistance framework
  /// (`DECISIONS/0023` — Exploration & Progression Loop 01).
  final int frostGuard;

  /// Percent chance of +1 yield on Woodcutting/Foraging nodes while this item
  /// is equipped — the Wolfhide Jerkin's Wilderness Ready passive. Rolled
  /// deterministically from the event sequence (`DECISIONS/0023` §9).
  final int wildernessYieldPercent;

  /// Percent chance of +1 yield on nodes whose required tool kind this item
  /// satisfies — the Reinforced Pickaxe's mining bonus. Same deterministic
  /// roll discipline as [wildernessYieldPercent].
  final int toolBonusYieldPercent;

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
    'frostGuard',
    'wildernessYieldPercent',
    'toolBonusYieldPercent',
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
      frostGuard: reader.optionalInt('frostGuard', min: 0, max: 100),
      wildernessYieldPercent: reader.optionalInt(
        'wildernessYieldPercent',
        min: 0,
        max: 100,
      ),
      toolBonusYieldPercent: reader.optionalInt(
        'toolBonusYieldPercent',
        min: 0,
        max: 100,
      ),
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
    this.safeAfterProject,
    this.developmentState,
    this.boardName,
    this.boardSlots = 3,
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

  /// A project whose completion makes this location safe — the Frostmere
  /// Shelter (`DECISIONS/0023` §3–4). Null for locations whose safety is
  /// static. The engine answers "is this place safe *now*" from [isSafe] OR
  /// this project being in the completed set; content alone cannot say.
  final ContentId? safeAfterProject;

  /// The settlement's named development state before any project has changed
  /// it — "Struggling" for Haven's Rest. Null for places with no settlement
  /// identity. Never an XP bar: the current state is derived from completed
  /// projects (`DECISIONS/0023` §3).
  final String? developmentState;

  /// What this location calls its contract board — "Notice Board",
  /// "Ranger Requests", "Mine Ledger", "Expedition Ledger". Null when the
  /// place has no board. Fiction, one backend (`DECISIONS/0023` §2).
  final String? boardName;

  /// How many local needs the board shows at once (the rotation window),
  /// clamped to the deck. Default 3.
  final int boardSlots;

  static const Set<String> fields = <String>{
    'id',
    'displayName',
    'terrain',
    'isSafe',
    'isStart',
    'connections',
    'entryRequirements',
    'resourceNodes',
    'safeAfterProject',
    'developmentState',
    'boardName',
    'boardSlots',
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
      safeAfterProject: reader.map.containsKey('safeAfterProject')
          ? reader.requireId('safeAfterProject', ContentNamespace.project)
          : null,
      developmentState: reader.map.containsKey('developmentState')
          ? reader.requireString('developmentState')
          : null,
      boardName: reader.map.containsKey('boardName')
          ? reader.requireString('boardName')
          : null,
      boardSlots: reader.optionalInt('boardSlots', fallback: 3, min: 1, max: 6),
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
    this.workSpeedPercent = 100,
    this.bonusYieldLevel = 0,
    this.bonusYieldPercent = 0,
    this.unlockedByProject,
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

  /// The skill level from which [bonusYieldPercent] applies — the small
  /// profession yield improvements (`DECISIONS/0023` §9, brief §38).
  /// Zero means the node offers no bonus.
  final int bonusYieldLevel;

  /// Percent chance of +1 yield once the player's level in [skill] reaches
  /// [bonusYieldLevel]. Rolled deterministically; recorded on the event.
  final int bonusYieldPercent;

  /// A project whose completion is required before this node may be worked —
  /// the Stonefall Lift's hardened seam. Null for always-available nodes.
  final ContentId? unlockedByProject;

  /// How fast this site is worked, as a percentage of the default pace
  /// (PLAYABLE_POLISH_01 correction pass, finding H). The default pace is
  /// **100 spendable steps per minute of work** — `0.6 s` a step — and
  /// this scales it: 200 works twice as fast, 50 half. Presentation pacing
  /// only: every completion still spends the same steps through the same
  /// command, and the engine never reads it. Authored rarely; the seam
  /// exists so a future special site need not change the formula.
  final int workSpeedPercent;

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
    'bonusYieldLevel',
    'workSpeedPercent',
    'bonusYieldPercent',
    'unlockedByProject',
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
      workSpeedPercent: reader.optionalInt(
        'workSpeedPercent',
        fallback: 100,
        min: 25,
        max: 400,
      ),
      xp: reader.requireInt('xp', min: 0, max: 1000000),
      bonusYieldLevel: reader.optionalInt('bonusYieldLevel', min: 0, max: 99),
      bonusYieldPercent: reader.optionalInt(
        'bonusYieldPercent',
        min: 0,
        max: 100,
      ),
      unlockedByProject: reader.map.containsKey('unlockedByProject')
          ? reader.requireId('unlockedByProject', ContentNamespace.project)
          : null,
    );
    return reader.isComplete ? definition : null;
  }
}

/// The workstation a recipe is worked at, for the craft stage's scene.
/// Presentation-only content data: the engine never reads it, and a recipe
/// without one leaves the scene to the skill's default.
enum CraftStation { forge, woodbench, cookfire }

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
    this.craftSeconds,
    this.station,
    this.unlockedByProject,
    this.retiredByProject,
    this.unlockedByContract,
  });

  final ContentId id;
  final String displayName;
  final ContentId skill;
  final int requiredLevel;
  final List<RecipeIngredient> ingredients;
  final ContentId outputItem;
  final int outputQuantity;
  final int xp;

  /// A project whose completion makes this recipe available — the Mill's
  /// improved plank processing is a *new* recipe unlocked by the Mill, beside
  /// the old one it retires (`DECISIONS/0023` §3). Null: always available.
  final ContentId? unlockedByProject;

  /// A project whose completion **removes** this recipe — the pre-Mill
  /// three-log plank recipe. Null: never retired.
  final ContentId? retiredByProject;

  /// A one-time contract whose completion teaches this recipe — Wolfhide via
  /// Woodland Aid, the Reinforced Pickaxe via Replace the Mine Hardware,
  /// the Frost-lined Jerkin via the Cold-Weather Kit. Null: known from the
  /// start.
  final ContentId? unlockedByContract;

  /// How long one repetition of this recipe takes at the bench, in seconds
  /// (PLAYABLE_POLISH_01 correction pass, finding I). Crafting costs **zero
  /// steps**, so it cannot be paced by the steps-per-minute rule; its pace
  /// is authored per recipe for delayed gratification — a component is a
  /// small job, a sword a real one. Null falls back to the category default
  /// the craft controller keeps. Presentation pacing: the engine validates
  /// and commits each repetition exactly as before, and never reads this.
  final int? craftSeconds;

  /// Where this recipe is worked, for the craft stage's scene — an oak
  /// plank is bench work even though the Smithing skill owns it, and the
  /// authored word is what keeps that from being a hardcoded item list in
  /// a widget (`RULES.md` E-5). Null: the presentation defaults by skill.
  /// The engine never reads this.
  final CraftStation? station;

  static const Set<String> fields = <String>{
    'id',
    'displayName',
    'skill',
    'requiredLevel',
    'ingredients',
    'outputItem',
    'outputQuantity',
    'xp',
    'craftSeconds',
    'station',
    'unlockedByProject',
    'retiredByProject',
    'unlockedByContract',
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
      craftSeconds: reader.map.containsKey('craftSeconds')
          ? reader.requireInt('craftSeconds', min: 1, max: 3600)
          : null,
      station: reader.map.containsKey('station')
          ? reader.requireEnum<CraftStation>('station', const <String,
              CraftStation>{
              'forge': CraftStation.forge,
              'woodbench': CraftStation.woodbench,
              'cookfire': CraftStation.cookfire,
            })
          : null,
      unlockedByProject: reader.map.containsKey('unlockedByProject')
          ? reader.requireId('unlockedByProject', ContentNamespace.project)
          : null,
      retiredByProject: reader.map.containsKey('retiredByProject')
          ? reader.requireId('retiredByProject', ContentNamespace.project)
          : null,
      unlockedByContract: reader.map.containsKey('unlockedByContract')
          ? reader.requireId('unlockedByContract', ContentNamespace.contract)
          : null,
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
    this.studiedAt = 3,
    this.knownAt = 6,
    this.knownXp = 25,
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

  /// Lifetime victories at which the enemy becomes **Studied** — fuller loot
  /// information and a line of ecology (`DECISIONS/0023` §5). Compact by
  /// design: Studied, then Known, then it stops.
  final int studiedAt;

  /// Lifetime victories at which the enemy becomes **Known** — bestiary
  /// complete, signature-drop existence revealed, and [knownXp] awarded once
  /// on the crossing victory.
  final int knownAt;

  /// One-time Character XP for reaching Known, before the balance profile is
  /// applied. Carried on the crossing `EncounterWon` event, so it is
  /// exactly-once by the same construction as the victory reward.
  final int knownXp;

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
    'studiedAt',
    'knownAt',
    'knownXp',
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
      studiedAt: reader.optionalInt('studiedAt', fallback: 3, min: 1, max: 100),
      knownAt: reader.optionalInt('knownAt', fallback: 6, min: 1, max: 100),
      knownXp: reader.optionalInt(
        'knownXp',
        fallback: 25,
        min: 0,
        max: 1000000,
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
    this.signature = false,
  });

  final ContentId item;
  final int quantity;

  /// Whole percent, 1–100. Not a double: floating point in content invites
  /// values that differ between platforms, and the simulation is deterministic.
  final int chancePercent;

  /// A signature rare drop (`DECISIONS/0023` §5–6): optional excitement,
  /// never on the critical path. Its **existence** is hidden on encounter
  /// cards until the enemy is Known; the drop itself can land at any time —
  /// concealment is presentation, never a roll change.
  final bool signature;

  static const Set<String> fields = <String>{
    'item',
    'quantity',
    'chancePercent',
    'signature',
  };

  static EnemyDrop? read(JsonReader reader, int index) {
    reader.rejectUnknownFields(fields);
    final EnemyDrop drop = EnemyDrop(
      item: reader.requireId('item', ContentNamespace.item),
      quantity: reader.optionalInt('quantity', fallback: 1, min: 1, max: 1000),
      chancePercent: reader.requireInt('chancePercent', min: 1, max: 100),
      signature: reader.optionalBool('signature'),
    );
    return reader.isComplete ? drop : null;
  }
}

/// An item and a count — the shared shape contract requirements, contract
/// rewards, and project stage requirements are written in.
///
/// Structurally identical to [RecipeIngredient], and deliberately a separate
/// type: an ingredient is consumed by crafting, while these appear as
/// requirements *and* as rewards, and sharing the recipe type would let a
/// reward read as something the recipe system owns.
@immutable
final class ItemQuantity {
  const ItemQuantity({required this.item, required this.quantity});

  final ContentId item;
  final int quantity;

  static const Set<String> fields = <String>{'item', 'quantity'};

  static ItemQuantity? read(JsonReader reader, int index) {
    reader.rejectUnknownFields(fields);
    final ItemQuantity value = ItemQuantity(
      item: reader.requireId('item', ContentNamespace.item),
      quantity: reader.optionalInt('quantity', fallback: 1, min: 1, max: 10000),
    );
    return reader.isComplete ? value : null;
  }
}

/// A profession XP award carried by a contract reward.
@immutable
final class SkillXpAward {
  const SkillXpAward({required this.skill, required this.xp});

  final ContentId skill;

  /// Before the balance profile is applied — scaled at completion time, like
  /// every other base figure.
  final int xp;

  static const Set<String> fields = <String>{'skill', 'xp'};

  static SkillXpAward? read(JsonReader reader, int index) {
    reader.rejectUnknownFields(fields);
    final SkillXpAward value = SkillXpAward(
      skill: reader.requireId('skill', ContentNamespace.skill),
      xp: reader.requireInt('xp', min: 1, max: 1000000),
    );
    return reader.isComplete ? value : null;
  }
}

/// The three contract classes (`DECISIONS/0023` §2).
///
/// Wire strings are `local_need` | `bounty` | `regional`.
enum ContractClass {
  /// A small repeatable authored delivery order, living in its location's
  /// rotation deck: 2–3 visible at a time, rotated by completion, never by
  /// time.
  localNeed,

  /// A standing repeatable combat order — the deterministic anti-grind
  /// backstop (`DECISIONS/0023` §6). Must be **accepted** before victories
  /// count; always visible on its board rather than in the rotation deck.
  bounty,

  /// A one-time authored objective. May unlock recipes, reveal rumors, and
  /// tell a small regional story.
  regional,
}

/// Something a location's board asks for (`DECISIONS/0023` §2).
@immutable
final class ContractDefinition {
  const ContractDefinition({
    required this.id,
    required this.displayName,
    required this.location,
    required this.contractClass,
    required this.brief,
    this.deckOrder = 0,
    this.requires = const <ItemQuantity>[],
    this.requiresOwned = const <ContentId>[],
    this.bountyEnemy,
    this.bountyCount = 0,
    this.requiresContract,
    this.requiresCompletedNeedAt,
    this.requiresProject,
    this.rewardItems = const <ItemQuantity>[],
    this.rewardSkillXp = const <SkillXpAward>[],
    this.rewardCharacterXp = 0,
    this.revealRumors = const <ContentId>[],
  });

  final ContentId id;
  final String displayName;

  /// The location whose board offers this. Completion requires standing here.
  final ContentId location;

  final ContractClass contractClass;

  /// One or two sentences of board fiction. Shown, never parsed.
  final String brief;

  /// Position in the location's rotation deck, for [ContractClass.localNeed].
  /// 1-based; the loader requires it on local needs and refuses it elsewhere.
  final int deckOrder;

  /// Items **consumed** on completion.
  final List<ItemQuantity> requires;

  /// Items the player must **hold** at completion but keeps — the
  /// Cold-Weather Kit asks to see a Wolfhide Jerkin, not to take it.
  final List<ContentId> requiresOwned;

  /// The enemy a bounty counts, with [bountyCount] victories required.
  /// Only qualifying victories **after acceptance** count (`DECISIONS/0023`
  /// §2; brief §79).
  final ContentId? bountyEnemy;
  final int bountyCount;

  /// A one-time contract that must be complete before this one is offered.
  final ContentId? requiresContract;

  /// A location at which at least one local need must have been completed
  /// before this contract is offered — Woodland Aid's "complete a Whispering
  /// Woods request".
  final ContentId? requiresCompletedNeedAt;

  /// A project whose completion is required before this contract is offered —
  /// the Shelter's advanced expedition contracts.
  final ContentId? requiresProject;

  final List<ItemQuantity> rewardItems;
  final List<SkillXpAward> rewardSkillXp;

  /// Character XP on completion, before the balance profile is applied.
  final int rewardCharacterXp;

  /// Rumors revealed on completion.
  final List<ContentId> revealRumors;

  /// Whether completing this contract again is legal. One-time for
  /// [ContractClass.regional]; repeatable otherwise.
  bool get isRepeatable => contractClass != ContractClass.regional;

  static const Set<String> fields = <String>{
    'id',
    'displayName',
    'location',
    'class',
    'brief',
    'deckOrder',
    'requires',
    'requiresOwned',
    'bountyEnemy',
    'bountyCount',
    'requiresContract',
    'requiresCompletedNeedAt',
    'requiresProject',
    'rewardItems',
    'rewardSkillXp',
    'rewardCharacterXp',
    'revealRumors',
  };

  static ContractDefinition? read(JsonReader reader) {
    reader.rejectUnknownFields(fields);
    final ContractDefinition definition = ContractDefinition(
      id: reader.requireId('id', ContentNamespace.contract),
      displayName: reader.requireString('displayName'),
      location: reader.requireId('location', ContentNamespace.location),
      contractClass: reader
          .requireEnum<ContractClass>('class', const <String, ContractClass>{
            'local_need': ContractClass.localNeed,
            'bounty': ContractClass.bounty,
            'regional': ContractClass.regional,
          }),
      brief: reader.requireString('brief'),
      deckOrder: reader.optionalInt('deckOrder', min: 1, max: 100),
      requires: List<ItemQuantity>.unmodifiable(
        reader.objectList<ItemQuantity>('requires', ItemQuantity.read),
      ),
      requiresOwned: List<ContentId>.unmodifiable(
        reader.idList('requiresOwned', ContentNamespace.item),
      ),
      bountyEnemy: reader.optionalId('bountyEnemy', ContentNamespace.enemy),
      bountyCount: reader.optionalInt('bountyCount', min: 1, max: 100),
      requiresContract: reader.optionalId(
        'requiresContract',
        ContentNamespace.contract,
      ),
      requiresCompletedNeedAt: reader.optionalId(
        'requiresCompletedNeedAt',
        ContentNamespace.location,
      ),
      requiresProject: reader.optionalId(
        'requiresProject',
        ContentNamespace.project,
      ),
      rewardItems: List<ItemQuantity>.unmodifiable(
        reader.objectList<ItemQuantity>('rewardItems', ItemQuantity.read),
      ),
      rewardSkillXp: List<SkillXpAward>.unmodifiable(
        reader.objectList<SkillXpAward>('rewardSkillXp', SkillXpAward.read),
      ),
      rewardCharacterXp: reader.optionalInt(
        'rewardCharacterXp',
        min: 0,
        max: 1000000,
      ),
      revealRumors: List<ContentId>.unmodifiable(
        reader.idList('revealRumors', ContentNamespace.rumor),
      ),
    );
    return reader.isComplete ? definition : null;
  }
}

/// One stage of a community project.
@immutable
final class ProjectStage {
  const ProjectStage({
    required this.name,
    required this.requires,
    this.characterXp = 0,
  });

  final String name;

  /// Materials this stage needs, delivered by partial contribution.
  final List<ItemQuantity> requires;

  /// Character XP on stage completion, before the profile is applied.
  final int characterXp;

  static const Set<String> fields = <String>{'name', 'requires', 'characterXp'};

  static ProjectStage? read(JsonReader reader, int index) {
    reader.rejectUnknownFields(fields);
    final ProjectStage stage = ProjectStage(
      name: reader.requireString('name'),
      requires: List<ItemQuantity>.unmodifiable(
        reader.objectList<ItemQuantity>('requires', ItemQuantity.read),
      ),
      characterXp: reader.optionalInt('characterXp', min: 0, max: 1000000),
    );
    if (stage.requires.isEmpty) {
      // A stage nothing can be contributed to can never complete.
      return null;
    }
    return reader.isComplete ? stage : null;
  }
}

/// A large staged permanent investment that visibly changes the world
/// (`DECISIONS/0023` §3). The reward is world change and capability —
/// permanent effects are declared on the content they affect
/// (`unlockedByProject` / `retiredByProject` / `safeAfterProject`) and
/// answered by the completed-projects set in state.
@immutable
final class ProjectDefinition {
  const ProjectDefinition({
    required this.id,
    required this.displayName,
    required this.location,
    required this.brief,
    required this.stages,
    this.completionCharacterXp = 0,
    this.completionHeadline,
    this.developmentTo,
    this.developmentRank = 0,
    this.revealRumors = const <ContentId>[],
  });

  final ContentId id;
  final String displayName;
  final ContentId location;
  final String brief;

  /// In order. At least one; contributions fill the current stage only.
  final List<ProjectStage> stages;

  /// Character XP on full completion, before the profile is applied — on top
  /// of the final stage's own award.
  final int completionCharacterXp;

  /// The completion banner — "HAVEN'S REST MILL RESTORED". Null falls back to
  /// a generic line.
  final String? completionHeadline;

  /// The development state this project's completion moves its settlement to
  /// — "Recovering". Null when completion does not rename the settlement.
  final String? developmentTo;

  /// Tie-break when several completed projects at one location each name a
  /// development state: the highest rank wins. Zero is fine while at most one
  /// project per location carries [developmentTo].
  final int developmentRank;

  /// Rumors revealed on completion.
  final List<ContentId> revealRumors;

  static const Set<String> fields = <String>{
    'id',
    'displayName',
    'location',
    'brief',
    'stages',
    'completionCharacterXp',
    'completionHeadline',
    'developmentTo',
    'developmentRank',
    'revealRumors',
  };

  static ProjectDefinition? read(JsonReader reader) {
    reader.rejectUnknownFields(fields);
    final ProjectDefinition definition = ProjectDefinition(
      id: reader.requireId('id', ContentNamespace.project),
      displayName: reader.requireString('displayName'),
      location: reader.requireId('location', ContentNamespace.location),
      brief: reader.requireString('brief'),
      stages: List<ProjectStage>.unmodifiable(
        reader.objectList<ProjectStage>('stages', ProjectStage.read),
      ),
      completionCharacterXp: reader.optionalInt(
        'completionCharacterXp',
        min: 0,
        max: 1000000,
      ),
      completionHeadline: reader.map.containsKey('completionHeadline')
          ? reader.requireString('completionHeadline')
          : null,
      developmentTo: reader.map.containsKey('developmentTo')
          ? reader.requireString('developmentTo')
          : null,
      developmentRank: reader.optionalInt('developmentRank', min: 0, max: 100),
      revealRumors: List<ContentId>.unmodifiable(
        reader.idList('revealRumors', ContentNamespace.rumor),
      ),
    );
    if (definition.stages.isEmpty) return null;
    return reader.isComplete ? definition : null;
  }
}

/// A lightweight authored rumor — a name and a hint about somewhere that is
/// not playable yet (`DECISIONS/0023` §8). Revealed by contracts, projects,
/// or discoveries; carries no timer and no obligation.
@immutable
final class RumorDefinition {
  const RumorDefinition({
    required this.id,
    required this.displayName,
    required this.hint,
  });

  final ContentId id;

  /// The atlas label — "Eastern City ?".
  final String displayName;

  /// The sentence the player reads — "Travelers speak of a walled city
  /// beyond the eastern marshes."
  final String hint;

  static const Set<String> fields = <String>{'id', 'displayName', 'hint'};

  static RumorDefinition? read(JsonReader reader) {
    reader.rejectUnknownFields(fields);
    final RumorDefinition definition = RumorDefinition(
      id: reader.requireId('id', ContentNamespace.rumor),
      displayName: reader.requireString('displayName'),
      hint: reader.requireString('hint'),
    );
    return reader.isComplete ? definition : null;
  }
}
