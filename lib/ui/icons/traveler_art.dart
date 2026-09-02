/// The one seam every Traveler-drawing surface fetches its strips through —
/// the visible-equipment foundation
/// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 5; architecture (B):
/// precomposed equipment-state sprite sets behind a single resolver).
///
/// ## What this is
///
/// Every Traveler visual used to be one flattened strip with one baked
/// outfit: a generic pale-steel sword in every combat frame, a generic axe
/// and pick in the work loops, whatever was actually equipped — including
/// nothing. This is the seam that lets equipped gear become visible on the
/// figure without every drawing surface learning what equipment is.
///
/// So this file is the contract:
///
/// - [EquipmentVisualState] (the session's fact projection) comes in;
/// - the item table maps item ids to **coarse variant classes** — never a
///   strip per item, which is how the combinatorics stay governable;
/// - the strip tables map (sequence family, variant) to packaged art;
/// - an absent entry resolves to the **base strip**, byte-identical to what
///   every surface drew before this file existed. Render base, never fake
///   (`RULES.md` A-1): no hand-drawn gear, no code-tinted blades, no icon
///   pasted into a hand.
///
/// ## What has since landed
///
/// The file shipped behaviourally inert, with both tables empty. Two rounds
/// have filled them:
///
/// - **Armour** (VAWO01) — three `create_character_state` figures on the
///   canonical Traveler, so eight chest items now show what is worn.
/// - **Weapons** (VAWO01) — an `unarmed` and a `bronze` combat set. The
///   unarmed one is the important half: an empty weapon slot used to fall
///   through to the base, whose every frame bakes a generic steel sword, so
///   the stage drew a blade the player did not own. [combatantFor] treats an
///   empty slot as a value rather than a miss for exactly that reason.
///
/// The walk table is still empty, and still degrades to the base cycle.
///
/// ## Rejected: runtime overlays
///
/// A weapon overlay needs a per-frame hand anchor and occlusion order on
/// 100+ frames of flattened art that already contains a baked generic tool
/// the overlay would double-draw. That data does not exist and cannot be
/// measured deterministically — it is a creative judgment, which A-1 gives
/// to PixelLab. Precomposed variant strips ride the existing pipeline
/// unchanged instead.
///
/// ## FMPO02 — two axes, every context
///
/// The owner's device found the contradiction VAWO01 left: Inventory showed
/// the Bronze Chestplate, and Adventure, the mine, the grove and the fight
/// showed the white shirt. So the tables here become **two-axis** — body
/// class × held-item class — and the resolver answers for every context that
/// draws the man: combat, the three gather loops, the ambient idles, the
/// travel walk, the standing figure. Each answer is a precomposed PixelLab
/// state animated for that context (`ART-05_equipment_brief.md`).
///
/// The fallthrough order is the honest one, and it is the same on every
/// axis: the exact pair, then the body with the base held item, then the base
/// body with the held item, then the base. A missing pair degrades one axis at
/// a time, never both, and never to a hole. `equipment_projection_test.dart`
/// asserts that for every equippable armour the resolved art's body class
/// equals the armour's class — "no revert to base clothes", as code.
library;

import '../../runtime/stride_session.dart' show EquipmentVisualState;
import '../components/ambient_scene.dart';
import 'combat_assets.dart';
import 'sprite_footprints.dart';

/// One authored working loop for a (skill, body, tool) triple: the frames
/// and the geometry the stage needs, because a new strip owns its own canvas
/// and footprint rather than borrowing the base loop's.
final class GatherStrip {
  const GatherStrip({
    required this.frames,
    required this.footprint,
    required this.canvasWidth,
    required this.strikeFrame,
  });

  final List<String> frames;
  final SpriteFootprint footprint;
  final int canvasWidth;
  final int strikeFrame;
}

abstract final class TravelerArt {
  const TravelerArt._();

  /// The body class of the base figure — the shirt and vest, and the row
  /// every unmapped armour degrades to.
  static const String baseBody = 'base';

  /// Held-item classes. Coarse by tier, never per item (ART-05 §1).
  static const String weaponUnarmed = 'weapon.unarmed';
  static const String weaponSteel = 'weapon.steel';
  static const String weaponBronze = 'weapon.bronze';
  static const String toolAxeSteel = 'tool.axe.steel';
  static const String toolAxeBronze = 'tool.axe.bronze';
  static const String toolPickSteel = 'tool.pick.steel';
  static const String toolPickBronze = 'tool.pick.bronze';

  /// The base six-frame west walk — the travel card's cycle, canonical
  /// here so the card and any future variant table cannot drift apart.
  static final List<String> travelerWalkWestFrames = List<String>.generate(
    6,
    (int i) => 'assets/art/v1/anim/traveler_walk_west_f$i.png',
    growable: false,
  );

  /// Item id → coarse variant class.
  ///
  /// **Coarse on purpose.** Ten armour items resolve to three classes, because
  /// a strip per item is how the combinatorics stop being governable — and
  /// because the classes are what the player actually reads at sprite scale: a
  /// breastplate, a fur jerkin, a long coat. Two bronze chestplates that differ
  /// by a frost resistance value look identical to an eye and should.
  ///
  /// An unmapped item is the base outfit by construction, so a content pack
  /// that adds an item before its art exists degrades to the Traveler rather
  /// than to a hole. Authored data, not code (E-5).
  static const Map<String, String> variantOfItem = <String, String>{
    // The starter tunics are the base figure — no row, deliberately.
    // Plate: hard bronze over the shirt.
    'item.bronze_chestplate': 'armor.plate',
    'item.scalewarmed_chestplate': 'armor.plate',
    // Jerkin: hide and fur, bulkier through the chest.
    'item.wolfhide_jerkin': 'armor.jerkin',
    'item.tuskbound_jerkin': 'armor.jerkin',
    'item.frostlined_jerkin': 'armor.jerkin',
    // Coat: long, belted, the heaviest silhouette.
    'item.bearhide_coat': 'armor.coat',
    'item.clawguard_coat': 'armor.coat',
    'item.frostwarden_coat': 'armor.coat',
    // Weapons. `item.training_sword` **is mapped now** (FMPO02): its absence
    // was honest only on the base body, whose baked blade is a plain steel
    // sword. On a plated body the same fallthrough drew the base clothes —
    // exactly the revert the owner banned — so the steel class exists and
    // the base body's row for it resolves to the shipped base set.
    'item.training_sword': weaponSteel,
    'item.bronze_sword': weaponBronze,
    'item.bronze_longsword': weaponBronze,
    'item.fanghilt_sword': weaponBronze,
    // Tools, by head material. The training tools are the base loops'
    // baked steel heads; the bronze family covers every forged and
    // improved tool, which all read as one bronze head at sprite scale.
    'item.training_axe': toolAxeSteel,
    'item.bronze_axe': toolAxeBronze,
    'item.hornbound_bronze_axe': toolAxeBronze,
    'item.goblin_toothed_axe': toolAxeBronze,
    'item.training_pickaxe': toolPickSteel,
    'item.bronze_pickaxe': toolPickBronze,
    'item.reinforced_pickaxe': toolPickBronze,
    'item.hornpoint_pickaxe': toolPickBronze,
    'item.tinbraced_pickaxe': toolPickBronze,
  };

  /// The body class [visual] wears: an armour's class, or [baseBody] for
  /// nothing equipped or an armour with no authored class.
  static String bodyClassOf(EquipmentVisualState visual) =>
      variantOfItem[visual.armor?.itemId] ?? baseBody;

  /// The weapon class [visual] holds. **An empty slot is a value, not a
  /// miss** — it resolves to [weaponUnarmed] before any table is consulted.
  /// An equipped weapon with no authored class reads as [weaponSteel]: the
  /// base set's baked blade is the honest picture of "some sword".
  static String weaponClassOf(EquipmentVisualState visual) {
    final String? id = visual.weapon?.itemId;
    if (id == null) return weaponUnarmed;
    return variantOfItem[id] ?? weaponSteel;
  }

  /// The tool class [visual] carries for [skill] — a pick for mining, an axe
  /// for woodcutting — or null when the equipped tool is not that
  /// profession's (or nothing is equipped), in which case the loop draws the
  /// profession's steel training tool, which is what the base loops bake.
  static String? toolClassOf(EquipmentVisualState visual, String skill) {
    final String? cls = variantOfItem[visual.tool?.itemId];
    if (cls == null) return null;
    final bool isPick = cls.startsWith('tool.pick');
    final bool isAxe = cls.startsWith('tool.axe');
    return switch (skill) {
      'skill.mining' when isPick => cls,
      'skill.woodcutting' when isAxe => cls,
      _ => null,
    };
  }

  static String _pair(String body, String held) => '$body|$held';

  /// Armour class → the standing figure that wears it.
  ///
  /// One 64² south rotation per class, from PixelLab
  /// `create_character_state` on the canonical Traveler — the same individual
  /// the shipped sprite is a rotation of, so these are variants rather than
  /// lookalikes.
  static const Map<String, String> armorFigures = <String, String>{
    'armor.plate': 'assets/art/v1/sprite/traveler_south_plate.png',
    'armor.jerkin': 'assets/art/v1/sprite/traveler_south_jerkin.png',
    'armor.coat': 'assets/art/v1/sprite/traveler_south_coat.png',
  };

  /// The standing figure for [visual] — what the player is wearing.
  ///
  /// The base Traveler when nothing is equipped, or when what is equipped has
  /// no authored class. Never a hole, never a guess.
  static String figureFor(EquipmentVisualState visual) =>
      armorFigures[_variantOf(visual.armor?.itemId)] ??
      'assets/art/v1/sprite/traveler_south.png';

  /// (combat) `'<bodyClass>|<weaponClass>'` → the full combatant set.
  ///
  /// The three base-body rows are VAWO01's: the shipped base set *is* the
  /// base body with a steel sword, and the unarmed and bronze sets are its
  /// empty-handed and bronze-armed siblings. The armoured rows land from
  /// FMPO02's state matrix — nine states, four tracks each — and are
  /// registered in `CombatAssets` as they are accepted.
  static final Map<String, CombatantArt> combatVariants =
      <String, CombatantArt>{
        _pair(baseBody, weaponSteel): CombatAssets.traveler,
        _pair(baseBody, weaponUnarmed): CombatAssets.travelerUnarmed,
        _pair(baseBody, weaponBronze): CombatAssets.travelerBronze,
        // The nine FMPO02 loadouts: three armoured bodies × three weapon
        // classes, keyed identically.
        ...CombatAssets.armouredLoadouts,
      };

  static const String _ambient = 'assets/art/v1/ambient';

  static List<String> _strip(String id, int n) => List<String>.generate(
    n,
    (int i) => '$_ambient/${id}_f$i.png',
    growable: false,
  );

  /// A nine-frame kneel played down and back up through the same frames —
  /// the base forage loop's own frame-order authoring, for the same reason:
  /// the source ends crouched and a hard wrap to standing would pop.
  static List<String> _forage(String body) {
    final List<String> f = _strip('traveler_${body}_forage', 9);
    return <String>[...f, for (int i = 7; i >= 1; i--) f[i]];
  }

  /// (gather) `'<skill>|<bodyClass>|<toolClass>'` → the working loop.
  ///
  /// Foraging carries no tool and keys as `'skill.foraging|<bodyClass>'`.
  /// The base body's steel rows are the shipped `activity_*` loops, so they
  /// are not listed: an absent row resolves to `AmbientAssets` exactly as
  /// before this table existed. Strike frames are measured
  /// (`FMPO02/tools/measure-reach.js`): the frame on which the tool head
  /// reaches furthest west, where the prop stands.
  ///
  /// **Named gaps** (PROD-EQUIPMENT, two rolls each, v3 kept inventing a
  /// detached stump or a swing-arc effect): plate + bronze axe, coat + bronze
  /// pick, base + bronze pick. Those loadouts resolve one axis down — the
  /// armour stays on with the steel tool, or the base body with the bronze
  /// tool — never to a hole and never to the shirt.
  static final Map<String, GatherStrip> gatherVariants = <String, GatherStrip>{
    'skill.woodcutting|armor.jerkin|tool.axe.bronze': GatherStrip(
      frames: _strip('traveler_jerkin_bronzeaxe_woodcut', 8),
      footprint: SpriteFootprints.ambientTravelerJerkinBronzeaxeWoodcut,
      canvasWidth: 80,
      strikeFrame: 7,
    ),
    'skill.woodcutting|armor.coat|tool.axe.bronze': GatherStrip(
      frames: _strip('traveler_coat_bronzeaxe_woodcut', 8),
      footprint: SpriteFootprints.ambientTravelerCoatBronzeaxeWoodcut,
      canvasWidth: 80,
      strikeFrame: 1,
    ),
    'skill.woodcutting|base|tool.axe.bronze': GatherStrip(
      frames: _strip('traveler_base_bronzeaxe_woodcut', 8),
      footprint: SpriteFootprints.ambientTravelerBaseBronzeaxeWoodcut,
      canvasWidth: 80,
      strikeFrame: 7,
    ),
    'skill.mining|armor.jerkin|tool.pick.bronze': GatherStrip(
      frames: _strip('traveler_jerkin_bronzepick_mine', 8),
      footprint: SpriteFootprints.ambientTravelerJerkinBronzepickMine,
      canvasWidth: 80,
      strikeFrame: 7,
    ),
    'skill.mining|armor.plate|tool.pick.bronze': GatherStrip(
      frames: _strip('traveler_plate_bronzepick_mine', 8),
      footprint: SpriteFootprints.ambientTravelerPlateBronzepickMine,
      canvasWidth: 80,
      strikeFrame: 0,
    ),
    'skill.foraging|armor.plate': GatherStrip(
      frames: _forage('plate'),
      footprint: SpriteFootprints.ambientTravelerPlateForage,
      canvasWidth: 64,
      strikeFrame: 8,
    ),
    'skill.foraging|armor.jerkin': GatherStrip(
      frames: _forage('jerkin'),
      footprint: SpriteFootprints.ambientTravelerJerkinForage,
      canvasWidth: 64,
      strikeFrame: 8,
    ),
    'skill.foraging|armor.coat': GatherStrip(
      frames: _forage('coat'),
      footprint: SpriteFootprints.ambientTravelerCoatForage,
      canvasWidth: 64,
      strikeFrame: 8,
    ),
  };

  static List<AmbientScene> _idles(
    String body,
    SpriteFootprint breathe,
    SpriteFootprint look,
  ) => <AmbientScene>[
    AmbientScene(
      id: '${body}_idle_breathe',
      traveler: AmbientTrack(
        frames: _strip('traveler_${body}_idle_breathe', 8),
        fps: 6,
        loop: AmbientLoop.pingpong,
        repeats: 3,
      ),
      footprint: breathe,
      weight: 2,
      idleWeight: 2,
    ),
    AmbientScene(
      id: '${body}_look_around',
      traveler: AmbientTrack(
        frames: _strip('traveler_${body}_look_around', 7),
        fps: 6,
        loop: AmbientLoop.pingpong,
        repeats: 2,
      ),
      footprint: look,
      idleWeight: 1,
    ),
  ];

  /// (idle) body class → the ambient scenes authored for that body. The
  /// base body uses `AmbientAssets.scenes` and is not listed. Two scenes per
  /// armour — breathing and looking around — which is fewer than the base
  /// figure's fifteen, and deliberately so: the base set is a living
  /// character study, and an armoured Traveler standing at rest is the same
  /// man in the clothes he chose. The companion and prop scenes that draw no
  /// Traveler come along from the base table by construction.
  static final Map<String, List<AmbientScene>> idleVariants =
      <String, List<AmbientScene>>{
        'armor.plate': _idles(
          'plate',
          SpriteFootprints.ambientTravelerPlateIdleBreathe,
          SpriteFootprints.ambientTravelerPlateLookAround,
        ),
        'armor.jerkin': _idles(
          'jerkin',
          SpriteFootprints.ambientTravelerJerkinIdleBreathe,
          SpriteFootprints.ambientTravelerJerkinLookAround,
        ),
        'armor.coat': _idles(
          'coat',
          SpriteFootprints.ambientTravelerCoatIdleBreathe,
          SpriteFootprints.ambientTravelerCoatLookAround,
        ),
      };

  /// (walk) body class → a six-frame west walk. The base is not listed.
  static final Map<String, List<String>> walkWestVariants =
      <String, List<String>>{
        'armor.plate': _strip('traveler_plate_walk_west', 6),
        'armor.jerkin': _strip('traveler_jerkin_walk_west', 6),
        'armor.coat': _strip('traveler_coat_walk_west', 6),
      };

  static String? _variantOf(String? itemId) =>
      itemId == null ? null : variantOfItem[itemId];

  /// The combat set for [visual] — what the Traveler is wearing **and**
  /// holding. A fight's loadout is honest to snapshot at encounter start.
  ///
  /// Resolution: the exact pair; then the same body holding the weapon it
  /// has art for closest to the truth (an armoured body never falls to the
  /// base body while any armoured row for it exists — that is the revert the
  /// owner banned); then the base body with the same weapon; then the base.
  static CombatantArt combatantFor(EquipmentVisualState visual) {
    final String body = bodyClassOf(visual);
    final String weapon = weaponClassOf(visual);
    return combatVariants[_pair(body, weapon)] ??
        _nearestArmed(body, weapon) ??
        combatVariants[_pair(baseBody, weapon)] ??
        CombatAssets.traveler;
  }

  /// The same body with another weapon class, preferring the truthful
  /// neighbour: an unmapped blade shows as steel, a missing bronze shows as
  /// steel, a missing steel shows as bronze — never as empty hands, and
  /// never as another body.
  static CombatantArt? _nearestArmed(String body, String weapon) {
    if (body == baseBody || weapon == weaponUnarmed) return null;
    for (final String alt in <String>[weaponSteel, weaponBronze]) {
      if (alt == weapon) continue;
      final CombatantArt? art = combatVariants[_pair(body, alt)];
      if (art != null) return art;
    }
    return null;
  }

  /// The working loop for [skill] on [visual], or null when the base loop
  /// (`AmbientAssets.activityLoopFor`) is the answer. Null is a value the
  /// stage understands: it means "the shipped base loop", which is honest for
  /// the base body with a steel tool and is the E-5 degradation for
  /// everything not yet authored.
  ///
  /// Resolution: the exact triple; then the body with its steel tool (the
  /// armour stays on, the tool tier is the axis that degrades); then the base
  /// body with the equipped tool tier; then null.
  static GatherStrip? gatherStripFor(String skill, EquipmentVisualState visual) {
    final String body = bodyClassOf(visual);
    final String? tool = toolClassOf(visual, skill);
    if (skill == 'skill.foraging') {
      return gatherVariants['$skill|$body'];
    }
    final String steel = skill == 'skill.mining' ? toolPickSteel : toolAxeSteel;
    final String held = tool ?? steel;
    return gatherVariants['$skill|$body|$held'] ??
        gatherVariants['$skill|$body|$steel'] ??
        gatherVariants['$skill|$baseBody|$held'];
  }

  /// The ambient idle set for [visual]: the base table for the base body,
  /// and for an armoured body its own authored scenes **plus** every base
  /// scene that draws no Traveler at all (the cat alone, the fire, the yarn)
  /// — derived from the one list by what each scene draws, never from a
  /// second hand-kept list that can drift.
  static AmbientSceneSet idleScenesFor(
    EquipmentVisualState visual, {
    required AmbientSceneSet base,
  }) {
    final List<AmbientScene>? own = idleVariants[bodyClassOf(visual)];
    if (own == null || own.isEmpty) return base;
    return AmbientSceneSet(<AmbientScene>[
      ...own,
      for (final AmbientScene s in base.scenes)
        if (!s.traveler.frames.any((String f) => f.contains('traveler_')) &&
            !s.traveler.frames.any((String f) => f.contains('pair_')))
          s,
    ]);
  }

  /// The travel walk for [visual] — the body's own cycle, or the base.
  static List<String> walkWestFor(EquipmentVisualState visual) =>
      walkWestVariants[_variantOf(visual.armor?.itemId)] ??
      travelerWalkWestFrames;

  /// The frame the Traveler rests on between scenes, for [visual]: the
  /// armoured body's own breathing rest, or null for the base (the caller's
  /// `AmbientAssets.restFrame`). Without this an armoured figure would pop
  /// back into the shirt for the beat between a scene ending and the next
  /// beginning — the revert, in the one place the eye is waiting for it.
  static String? restFrameFor(EquipmentVisualState visual) {
    final List<AmbientScene>? own = idleVariants[bodyClassOf(visual)];
    return own == null || own.isEmpty ? null : own.first.traveler.frames.first;
  }

  /// The footprint that goes with [restFrameFor], or null likewise.
  static SpriteFootprint? restFootprintFor(EquipmentVisualState visual) {
    final List<AmbientScene>? own = idleVariants[bodyClassOf(visual)];
    return own == null || own.isEmpty ? null : own.first.footprint;
  }

  /// Whether any FMPO02 gather row exists — the stage test uses it to know
  /// whether the equipment axis is live.
  static bool get hasGatherVariants => gatherVariants.isNotEmpty;
}
