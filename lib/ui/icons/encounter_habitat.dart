/// The ground a creature stands on, by region — the encounter card's habitat
/// plate table (`ART-08_enemy_brief.md` §2).
///
/// ## What a plate is
///
/// One **flat ground plane**, 192 × 76 native, drawn at the encounter band's
/// existing ×2 — 384 × 152 dp — bottom-aligned under the creature. Leaf
/// litter, shelf rock, basalt, packed snow, loam and roots: contact and
/// material, never a scene. No horizon, no sky, no midground prop, nothing
/// above the creature's own headroom line. A plate that acquires any of those
/// has become the "full battle background per card" the owner ruled out, and
/// the brief's own QA gate rejects it.
///
/// The plate is authored with its ground line on row 74 of 76, which is the
/// band's existing bottom alignment, so the creature's per-track
/// `footprint`/`groundOffset()` arithmetic is untouched: the plate is a new
/// bottom layer under the same `Align(bottomCenter)` the figure already uses.
///
/// ## Why the table is keyed by place and not by enemy
///
/// A habitat is a property of *where the player is standing*, and the card is
/// only ever drawn for enemies that live at the current location. Keying by
/// place means an enemy added to a region needs no row here, an elite draws
/// its base species' ground for free, and the table cannot disagree with
/// itself about two creatures sharing a floor.
///
/// The brief's split *within* Stonefall — the goblins on a rocky ledge and the
/// salamander in its ember cave — is the one thing the place key cannot say on
/// its own, so [byEnemy] is consulted first and carries exactly that one
/// override. Which of the two Stonefall grounds a card shows was a design
/// decision and not an implementation detail (`RULES.md` G-3); it was recorded
/// as **Q-21** and answered there.
///
/// ## All five plates are live
///
/// [enabled] holds every slug: `forest_floor`, `rocky_ledge`, `cave_shadow`,
/// `snowbank`, `hollow_rootbed` shipped in FMPO02 and render. The set is still
/// the switch — removing a slug puts that region's cards back on the derived
/// band height (`_EnemyStage`) — but nothing here is waiting on art any more.
/// The art debt that remains is the *content* of two plates: `snowbank` and
/// `cave_shadow` read as a treeline and a wall rather than the flat ground
/// plane this file's own rule below demands (FMPO02 wave 3, FINAL-05 #3).
library;

import 'package:stride_core/stride_core.dart' show ContentId;

/// One authored ground plate.
final class HabitatPlate {
  const HabitatPlate({required this.slug})
    : assert(slug != '', 'a plate needs a name');

  /// The file's own name — `forest` is `habitat_forest.png`. Also the token
  /// [EncounterHabitat.enabled] is written in, so turning a plate on is
  /// naming the art rather than repeating a path.
  final String slug;

  String get assetPath => 'assets/art/v1/combat/habitat_$slug.png';

  /// Native canvas, in source pixels (`ART-08` §2).
  static const int nativeWidth = 192;
  static const int nativeHeight = 76;

  /// The band's own scale. Integer only (L-18); the drawn plate is therefore
  /// 384 × 152 dp and the band's full interior height when one is present.
  static const int scale = 2;

  /// The drawn height in logical pixels — what the band becomes when a plate
  /// carries the ground. Derived, never a second constant that could drift
  /// from the canvas above it.
  static double get displayHeight => (nativeHeight * scale).toDouble();
}

/// Region → ground.
abstract final class EncounterHabitat {
  const EncounterHabitat._();

  /// Leaf litter, a fallen log, dappled shade: the Whispering Woods floor.
  static const HabitatPlate forestFloor = HabitatPlate(slug: 'forest_floor');

  /// Flat grey shelf rock and rubble: the Stonefall workings.
  static const HabitatPlate rockyLedge = HabitatPlate(slug: 'rocky_ledge');

  /// Dark basalt with an ember rim glow — the salamander's chamber. Mapped
  /// by **enemy family**, not by place: see [plateFor]'s producer ruling on
  /// Q-21.
  static const HabitatPlate caveShadow = HabitatPlate(slug: 'cave_shadow');

  /// Packed snow and one wind-carved ridge: Frostmere.
  static const HabitatPlate snowbank = HabitatPlate(slug: 'snowbank');

  /// Dark loam crossed by pale roots: the Forgotten Hollow.
  static const HabitatPlate hollowRootbed = HabitatPlate(slug: 'hollow_rootbed');

  /// The one within-region split the brief asked for: the salamander lives
  /// in the mine's ember chamber, not on its working ledge. Keyed by the
  /// species id so the elite of a species stands on its species' ground.
  static const Map<String, HabitatPlate> byEnemy = <String, HabitatPlate>{
    'enemy.salamander': caveShadow,
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
    'location.forgotten_hollow': hollowRootbed,
  };

  /// The slugs whose art has landed and been accepted on device.
  ///
  /// **This is the switch, and it is on.** Empty would be "no plate
  /// anywhere"; all five slugs are listed, so every region's cards draw their
  /// authored ground. Removing one puts that region back on the derived band
  /// height at once, and adding it lights them again — nothing else in the
  /// widget path is conditional, so neither direction is a redesign.
  static const Set<String> enabled = <String>{
    'forest_floor',
    'rocky_ledge',
    'cave_shadow',
    'snowbank',
    'hollow_rootbed',
  };

  /// The plate for [enemy] at [place], or null when neither has ground
  /// authored — or the ground is not switched on.
  ///
  /// **Q-21, ruled by the producer (FMPO02):** the table stays keyed by place
  /// — a habitat is where the player is standing — with one species-level
  /// override for the creature whose habitat the brief named as different
  /// from its region's. The species map is consulted first, so an elite of
  /// that species inherits it; every other creature stands on its region.
  static HabitatPlate? plateFor(ContentId place, {ContentId? enemy}) {
    final HabitatPlate? plate =
        (enemy == null ? null : byEnemy[enemy.value]) ?? byPlace[place.value];
    if (plate == null || !enabled.contains(plate.slug)) return null;
    return plate;
  }
}
