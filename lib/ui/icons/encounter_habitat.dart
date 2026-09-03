/// The ground a creature stands on, by region — the encounter card's habitat
/// plate table (`ART-08_enemy_brief.md` §2, superseded by `DIR-12` EPO03).
///
/// ## What a plate is, from EPO03 on
///
/// A **habitat window**, not a ground strip. The ART-08 gate ("contact and
/// material, never a scene; no midground, nothing above the headroom line")
/// was authored to stop a battle background appearing behind every card, and
/// it succeeded — but the five plates it produced put creatures at the foot of
/// a wall (`rocky_ledge`, `cave_shadow`), on gravel below the habitat
/// (`snowbank`) and on no floor at all (`hollow_rootbed`). DIR-12 measured
/// every one of those against `_EnemyStage`'s own seating arithmetic and the
/// owner ruled the direction forward: *"Enemy previews should feel like
/// wildlife in habitats."*
///
/// So a plate now carries:
///
/// * a **floor in the lower ~40 %** that the creature demonstrably stands on,
///   its ground line on rows 68–72 of 76 (92–95 of 96 for a boss chamber) —
///   the band's existing bottom alignment, so no `footprint`/`groundOffset()`
///   arithmetic moves;
/// * a **midground** that names the region;
/// * an **atmosphere band** at the top — mist, cave dark, snow light.
///
/// And still: **no open sky, no ruler-straight horizon, no props.** A log, a
/// lantern on a post, a cut block or a plank is the "staged scene" failure and
/// is rejected. Plates stay *regional and reusable* — one per region, not one
/// per card — so the owner's cost objection to a battle background per
/// encounter still holds exactly.
///
/// ## The foreground is the other half
///
/// A backdrop alone leaves the creature a cut-out pasted on a picture. Each
/// plate therefore has a **transparent foreground strip** drawn *above* the
/// creature — grass tufts, scree rubble, a drift lip, root loops — so
/// something in the habitat overlaps its feet and it is *in* the scene rather
/// than in front of it. The cave adds a **canopy**: a stalactite fringe hung
/// from the top edge, which is the one place a habitat legitimately closes
/// over a creature's head.
///
/// Every one of these is optional at the file level: a slug whose PNG is
/// missing decodes to nothing and the layer simply is not there
/// (`RULES.md` E-5).
///
/// ## Why the table is keyed by place and not by enemy
///
/// A habitat is a property of *where the player is standing*, and the card is
/// only ever drawn for enemies that live at the current location. Keying by
/// place means an enemy added to a region needs no row here, an elite draws
/// its base species' ground for free, and the table cannot disagree with
/// itself about two creatures sharing a floor.
///
/// [byEnemy] carries the two exceptions a place key cannot state: the
/// salamander lives in the mine's ember gallery rather than on its working
/// ledge (**Q-21**, ruled), and the Awakened Guardian's chamber is the same
/// chamber *roused* — a lighting state of one room, not a second room.
library;

import 'package:stride_core/stride_core.dart' show ContentId;

/// One authored habitat window: its ground, what is drawn in front of the
/// creature, and what hangs over its head.
final class HabitatPlate {
  const HabitatPlate({
    required this.slug,
    required this.caption,
    this.nativeHeight = commonHeight,
    this.foreground,
    this.canopy,
  }) : assert(slug != '', 'a plate needs a name');

  /// The file's own name — `forest_floor` is `habitat_forest_floor.png`. Also
  /// the token [EncounterHabitat.enabled] is written in, so turning a plate on
  /// is naming the art rather than repeating a path.
  final String slug;

  /// What the dossier calls this ground, in the habitat caption under the
  /// creature's name ("Whispering Woods · forest floor"). A field guide names
  /// the habitat; that is most of what makes it a field guide.
  final String caption;

  /// The plate's own canvas height in source pixels. A boss chamber is taller
  /// than a roadside habitat because a boss needs headroom above its head —
  /// the Guardian at 146 dp in a 152 band read *cramped*, which is the exact
  /// opposite of the presence it is supposed to have.
  final int nativeHeight;

  /// The transparent strip drawn **above** the creature, or null. 192 ×
  /// [foregroundHeight], bottom-aligned on the same edge as the plate.
  final String? foreground;

  /// The transparent fringe hung from the **top** edge, or null. 192 ×
  /// [canopyHeight]. The cave's stalactites; nothing else has one.
  final String? canopy;

  String get assetPath => 'assets/art/v1/combat/habitat_$slug.png';

  String? get foregroundPath => foreground == null
      ? null
      : 'assets/art/v1/combat/habitat_fg_$foreground.png';

  String? get canopyPath =>
      canopy == null ? null : 'assets/art/v1/combat/habitat_top_$canopy.png';

  /// Native canvas width, in source pixels — one figure for every plate, so
  /// the band's horizontal framing never depends on which region it is.
  static const int nativeWidth = 192;

  /// A roadside habitat's canvas height.
  static const int commonHeight = 76;

  /// A boss chamber's canvas height. 96, not 76: the Guardian's own content is
  /// 73 source rows, so 76 left it three rows of air.
  static const int bossHeight = 96;

  /// The foreground strip's canvas height, and the canopy fringe's. **32, not
  /// the 28 and 20 DIR-12 costed:** PixelLab's canvas rule is that any side
  /// under 32 forces a square canvas, so 192 × 28 is not a canvas the tool can
  /// draw. Both strips are mostly transparent either way — what matters is
  /// that the drawn detail sits on the correct edge, which the prompt asks for
  /// and the sheet read checks.
  static const int foregroundHeight = 32;
  static const int canopyHeight = 32;

  /// The band's own scale. Integer only (L-18).
  static const int scale = 2;

  /// The drawn height in logical pixels — what the band becomes when this
  /// plate carries the ground. Derived from [nativeHeight], never a second
  /// constant that could drift from the canvas above it.
  double get displayHeight => (nativeHeight * scale).toDouble();

  /// Whether this window is a boss chamber: taller, darker, framed heavier.
  bool get isChamber => nativeHeight >= bossHeight;
}

/// Region → habitat window.
abstract final class EncounterHabitat {
  const EncounterHabitat._();

  /// Leaf litter over dark loam, ferns and a trunk behind, dappled shade
  /// above: the Whispering Woods floor. The one plate DIR-12 kept unchanged —
  /// the wolf already stands *on* this one.
  static const HabitatPlate forestFloor = HabitatPlate(
    slug: 'forest_floor',
    caption: 'forest floor',
    foreground: 'forest_floor',
  );

  /// A scree shelf in shallow top-down, the working wall only as the top
  /// third: the Stonefall galleries.
  static const HabitatPlate rockyLedge = HabitatPlate(
    slug: 'rocky_ledge',
    caption: 'shelf rock',
    foreground: 'rocky_ledge',
  );

  /// Basalt flagstone underfoot with an ember rim from a floor fissure — the
  /// salamander's gallery. Mapped by **enemy family**, not by place: see
  /// [plateFor]'s producer ruling on Q-21.
  static const HabitatPlate caveShadow = HabitatPlate(
    slug: 'cave_shadow',
    caption: 'ember gallery',
    foreground: 'cave_shadow',
    canopy: 'cave_shadow',
  );

  /// Wind-packed snow all the way to the bottom row, rime treeline behind:
  /// Frostmere.
  static const HabitatPlate snowbank = HabitatPlate(
    slug: 'snowbank',
    caption: 'wind-packed snow',
    foreground: 'snowbank',
  );

  /// The boss chamber: loam floor, roots rising behind, fungus bio-light.
  /// 192 × 96 — the Forgotten Hollow's one room, and the only plate a
  /// creature has headroom in.
  static const HabitatPlate hollowChamber = HabitatPlate(
    slug: 'hollow_chamber',
    caption: 'root chamber',
    nativeHeight: HabitatPlate.bossHeight,
    foreground: 'hollow_chamber',
  );

  /// The same chamber, roused: darker, rune-lit. A lighting state of one
  /// room, which is why it shares the chamber's foreground.
  static const HabitatPlate hollowChamberAwakened = HabitatPlate(
    slug: 'hollow_chamber_awakened',
    caption: 'root chamber, roused',
    nativeHeight: HabitatPlate.bossHeight,
    foreground: 'hollow_chamber',
  );

  /// The two within-region splits a place key cannot state. Keyed by the
  /// species id so the elite of a species stands on its species' ground.
  static const Map<String, HabitatPlate> byEnemy = <String, HabitatPlate>{
    'enemy.salamander': caveShadow,
    'enemy.guardian_awakened': hollowChamberAwakened,
  };

  /// Every plate by the region whose ground it is.
  ///
  /// Haven's Rest is absent on purpose rather than by omission: no enemy in
  /// `enemies.json` lives there, so a settlement plate would be art authored
  /// for a card that is never drawn.
  static const Map<String, HabitatPlate> byPlace = <String, HabitatPlate>{
    'location.whispering_woods': forestFloor,
    'location.stonefall_mine': rockyLedge,
    'location.frostmere': snowbank,
    'location.forgotten_hollow': hollowChamber,
  };

  /// The slugs whose art has landed and been accepted on device.
  ///
  /// **This is the switch, and it is on.** Empty would be "no plate
  /// anywhere". Removing one puts that region back on the derived band height
  /// at once, and adding it lights them again — nothing else in the widget
  /// path is conditional, so neither direction is a redesign.
  static const Set<String> enabled = <String>{
    'forest_floor',
    'rocky_ledge',
    'cave_shadow',
    'snowbank',
    'hollow_chamber',
    'hollow_chamber_awakened',
  };

  /// The plate for [enemy] at [place], or null when neither has ground
  /// authored — or the ground is not switched on.
  static HabitatPlate? plateFor(ContentId place, {ContentId? enemy}) {
    final HabitatPlate? plate =
        (enemy == null ? null : byEnemy[enemy.value]) ?? byPlace[place.value];
    if (plate == null || !enabled.contains(plate.slug)) return null;
    return plate;
  }
}
