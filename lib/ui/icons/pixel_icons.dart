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

  static const String _base = 'assets/ui/v1';

  // ------------------------------------------------------------------ glyphs

  /// Teal. Steps the player has actually walked — a stock or flow they own.
  static const String stepsGlyph = '$_base/glyph_steps.png';

  /// Muted. Steps as a unit of measure — a price, a distance, a requirement.
  static const String stepsGlyphMuted = '$_base/glyph_steps_muted.png';

  static const String arrowGlyph = '$_base/glyph_arrow.png';

  // --------------------------------------------------------------- portrait

  /// **TEMPORARY PLACEHOLDER.**
  ///
  /// The character portrait workstream is paused with no approved asset and no
  /// approved canvas — `GAME_BIBLE/ART/exploration/CHARACTER_PORTRAIT_CLOSEOUT.md`
  /// governs it, and that document's §6 lists what a future restart must **not**
  /// inherit. This file is evidence from a failed round, used because a frame
  /// needs something in it.
  ///
  /// Nothing about any layout depends on its content. The frame is a component,
  /// the image is an asset, and they are replaceable independently: swapping
  /// this one path is the whole migration.
  static const String portraitTemporary = '$_base/portrait_traveler.png';

  // ---------------------------------------------------------- illustrations

  static const Map<String, String> _activityByNode = <String, String>{
    'resource_node.meadow_patch': '$_base/activity_meadow_patch.png',
  };

  /// The illustration for a resource node, or null when none is drawn yet.
  ///
  /// Null rather than a placeholder: an activity illustration is an 80 px
  /// feature of a card, and a card with no picture reads as a card with no
  /// picture. A placeholder that size would read as a broken image.
  static String? activityFor(ContentId node) => _activityByNode[node.value];

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

  /// Only the items a Phase 1 player can actually hold: the four starting
  /// loadout items plus the one gatherable yield.
  ///
  /// The rest of the icon set is deliberately absent. Four icons in it still
  /// produce confident wrong nouns at play scale (`ICON_REPAIR_04.md` §9), and
  /// scoping the grid to what the player holds means that unresolved question
  /// blocks nothing here.
  static const Map<String, String> _itemIcons = <String, String>{
    'item.meadow_herb': '$_base/item_meadow_herb.png',
    'item.training_sword': '$_base/item_training_sword.png',
    'item.training_axe': '$_base/item_training_axe.png',
    'item.training_pickaxe': '$_base/item_training_pickaxe.png',
    'item.traveler_tunic': '$_base/item_traveler_tunic.png',
  };

  /// A deliberately non-representational slab, for an item with no icon.
  ///
  /// It must not read as a lock, an equipment slot, an empty or disabled cell,
  /// or currency — the exact four-way wrong read the Hollow Sigil scored, in the
  /// one grid cell most likely to be misread. So: two colours, a rim, and
  /// nothing inside. It looks unfinished because it is.
  static const String itemUnknown = '$_base/item_unknown.png';

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
}
