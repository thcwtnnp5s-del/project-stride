/// The only place an asset path string appears.
///
/// The inventory icon set is not approved (`ART_DIRECTION.md` UNRESOLVED), so a
/// single lookup table means resolving it later is one edit rather than a hunt
/// through widgets. It also means an unmapped item has one honest answer instead
/// of a crash.
library;

import 'package:stride_core/stride_core.dart' show ContentId;

abstract final class PixelIcons {
  const PixelIcons._();

  /// Interface chrome — glyphs, navigation, skill marks. Authored as UI, sized
  /// to the UI grid, and changed when the interface changes.
  static const String _base = 'assets/ui/v1';

  /// Game art — portrait, sprites, item icons, scenes, animation. Authored in
  /// PixelLab and packaged by `Scripts/art/package-art.js`.
  ///
  /// The two roots are separate because the two things change for different
  /// reasons and at different rates. A nav glyph is redrawn when the tab bar is
  /// redesigned; the Traveler is not.
  static const String _art = 'assets/art/v1';

  // ------------------------------------------------------------------ glyphs

  /// Teal. Steps the player has actually walked — a stock or flow they own.
  static const String stepsGlyph = '$_base/glyph_steps.png';

  /// Muted. Steps as a unit of measure — a price, a distance, a requirement.
  static const String stepsGlyphMuted = '$_base/glyph_steps_muted.png';

  static const String arrowGlyph = '$_base/glyph_arrow.png';

  // --------------------------------------------------------------- portrait

  /// The Traveler portrait — 64 × 64, PixelLab.
  ///
  /// This replaced a code-rendered placeholder from the paused portrait
  /// workstream (`GAME_BIBLE/ART/exploration/CHARACTER_PORTRAIT_CLOSEOUT.md`).
  /// That workstream's own closeout records what its four rounds never solved:
  /// the lower face, the ear, the jaw/neck junction and the mouth, each "present
  /// in measurements, absent in perception". The PixelLab portrait resolves all
  /// four, and it is production art rather than evidence.
  ///
  /// Nothing about any layout depends on its content. The frame is a component,
  /// the image is an asset, and swapping this one path is the whole migration.
  static const String portraitTraveler = '$_art/portrait/traveler.png';

  // ---------------------------------------------------------------- sprites

  /// The Traveler at rest, facing the viewer.
  static const String travelerSouth = '$_art/sprite/traveler_south.png';

  // -------------------------------------------------------------- animation

  /// The gather cycle, in order: stand, lean, crouch, take the herb, rise
  /// holding it.
  ///
  /// Eight frames, trimmed from ten. Blind review found the last three to be
  /// "near-identical frontal standing holds… two of these three are dead
  /// weight", so the tail was cut to a single hold with the herb still in hand.
  static const List<String> gatherFrames = <String>[
    '$_art/anim/gather_f0.png',
    '$_art/anim/gather_f1.png',
    '$_art/anim/gather_f2.png',
    '$_art/anim/gather_f3.png',
    '$_art/anim/gather_f4.png',
    '$_art/anim/gather_f5.png',
    '$_art/anim/gather_f6.png',
    '$_art/anim/gather_f7.png',
  ];

  // ----------------------------------------------------------------- scenes

  /// The illustrated region map. **Presentation only** — it depicts routes that
  /// no command can walk, so nothing on it is a control.
  static const String regionMap = '$_art/world/region_map.png';

  static const Map<String, String> _vignetteByLocation = <String, String>{
    'location.havens_rest': '$_art/location/havens_rest.png',
  };

  /// The arrival vignette for a location, or null where none is drawn.
  ///
  /// Null rather than a placeholder: a vignette is a 176 px band across the
  /// whole screen, and a placeholder that size would read as a broken image
  /// rather than as absent art.
  static String? vignetteFor(ContentId location) =>
      _vignetteByLocation[location.value];

  // ----------------------------------------------------------------- skills

  /// All five Milestone 01 skills.
  ///
  /// Originally only Foraging shipped, on the reasoning that it was the only
  /// skill with a Phase 1 *action*. Visual QA found the consequence: the
  /// Character screen lists five skills, four rows had no icon, and the one
  /// that did read as a stray decoration rather than as a member of a set.
  /// Shipping four more 12 × 12 sprites was cheaper than the defect.
  static const Map<String, String> _skillIcons = <String, String>{
    'skill.foraging': '$_base/skill_foraging.png',
    'skill.woodcutting': '$_base/skill_woodcutting.png',
    'skill.mining': '$_base/skill_mining.png',
    'skill.smithing': '$_base/skill_smithing.png',
    'skill.cooking': '$_base/skill_cooking.png',
  };

  /// The icon for a skill, or null when a content pack names one this set does
  /// not cover.
  ///
  /// Callers laying out a list **must reserve the slot either way**. A row that
  /// collapses when the icon is null gives the list two different left margins
  /// and destroys its alignment rail.
  static String? skillFor(ContentId skill) => _skillIcons[skill.value];

  // ------------------------------------------------------------------ items

  /// The PixelLab 48 × 48 family — every item it covers, not only the five a
  /// Phase 1 player can hold.
  ///
  /// The predecessor set was scoped to five deliberately, because four of its
  /// icons produced confident wrong nouns at play scale (`ICON_REPAIR_04.md`
  /// §9) and shipping them would have put a lie in the grid. That constraint
  /// belonged to that set. This one was blind-reviewed in the actual four-wide
  /// grid at play scale, and the verdict across the whole grid was **"none
  /// outright contradict"** (`PIXELLAB_STABILIZATION_01/README.md` §3 item 4).
  ///
  /// The remaining nine items in `items.json` — the bronze tier, the cooked
  /// food, the Hollow Sigil — have no icon here and resolve to [itemUnknown].
  /// None of them is craftable or obtainable in Phase 1.
  static const Map<String, String> _itemIcons = <String, String>{
    'item.bronze_ingot': '$_art/item/bronze_ingot.png',
    'item.copper_ore': '$_art/item/copper_ore.png',
    'item.meadow_herb': '$_art/item/meadow_herb.png',
    'item.oak_handle': '$_art/item/oak_handle.png',
    'item.oak_log': '$_art/item/oak_log.png',
    'item.pine_log': '$_art/item/pine_log.png',
    'item.tin_ore': '$_art/item/tin_ore.png',
    'item.training_axe': '$_art/item/training_axe.png',
    'item.training_pickaxe': '$_art/item/training_pickaxe.png',
    'item.training_sword': '$_art/item/training_sword.png',
    'item.traveler_tunic': '$_art/item/traveler_tunic.png',
  };

  /// A deliberately non-representational slab, for an item with no icon.
  ///
  /// It must not read as a lock, an equipment slot, an empty or disabled cell,
  /// or currency — the exact four-way wrong read the Hollow Sigil scored, in the
  /// one grid cell most likely to be misread. So: two colours, a rim, and
  /// nothing inside. It looks unfinished because it is.
  static const String itemUnknown = '$_art/item/unknown.png';

  /// Never null. An item the icon set does not cover still gets a tile, a label
  /// and a count — icon + label + count is the semantic unit (**L-17**), and the
  /// label carries the meaning while the icon is honest about being absent.
  static String itemFor(ContentId item) =>
      _itemIcons[item.value] ?? itemUnknown;

  /// Whether [item] has a real icon. Lets a screen decide what to show; it does
  /// not change what [itemFor] returns.
  static bool hasItemIcon(ContentId item) => _itemIcons.containsKey(item.value);

  // ------------------------------------------------------------- navigation

  static const String navAdventure = '$_base/nav_adventure.png';
  static const String navAdventureActive = '$_base/nav_adventure_hi.png';
  static const String navCharacter = '$_base/nav_character.png';
  static const String navCharacterActive = '$_base/nav_character_hi.png';
  static const String navSkills = '$_base/nav_skills.png';
  static const String navInventory = '$_base/nav_inventory.png';
  static const String navInventoryActive = '$_base/nav_inventory_hi.png';
  static const String navCraft = '$_base/nav_craft.png';
  static const String navWorld = '$_base/nav_world.png';

  /// Derived from [navWorld] by `Scripts/art/nav-active-variant.js`, using the
  /// index remap measured from the three glyph pairs that already shipped — so
  /// the fourth selectable tab brightens exactly like the other three rather
  /// than by a rule invented for it.
  static const String navWorldActive = '$_base/nav_world_hi.png';
}
