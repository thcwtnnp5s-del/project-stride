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

  /// **TEMPORARY ART — awaiting a canonical step-economy mark.**
  /// `JOURNAL/OPEN_QUESTIONS.md` **OD-03**, owner direction 2026-08-17.
  ///
  /// The turquoise boot below is placeholder work. It is the symbol of the
  /// thing the whole product is about — real-world walking — and it appears
  /// beside every step figure in the app: the persistent header readout, the
  /// walking band, the cost tiles, the route distances on the World screen.
  ///
  /// **The replacement is one asset used everywhere the step economy is
  /// named**, not a glyph redrawn per surface. Both variants below are the same
  /// mark in two colours under the rule in `walking_glyph.dart`, and the
  /// replacement must preserve that pairing or replace the rule with it.
  ///
  /// **Do not improvise a vector or icon-font substitute.** L-18 governs pixel
  /// content and this is pixel content; a stopgap in another medium would be a
  /// second visual language in the most-repeated mark in the product.
  ///
  /// Teal. Steps the player has actually walked — a stock or flow they own.
  static const String stepsGlyph = '$_base/glyph_steps.png';

  /// **TEMPORARY ART.** See [stepsGlyph] and `OPEN_QUESTIONS.md` OD-03.
  ///
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

  /// The illustrated region map.
  ///
  /// **Still not a control**, and the distinction is finer than it was. `TravelTo`
  /// exists as of Phase 2, so the routes drawn here *can* now be walked — but
  /// they are walked from the World screen's destination rows, not from the
  /// picture. The map has no hit testing, no pin, and nothing draggable.
  static const String regionMap = '$_art/world/region_map.png';

  /// One arrival vignette per location, all five.
  ///
  /// Four of these are Phase 2 (`GAME_BIBLE/ART/exploration/PIXELLAB_
  /// STABILIZATION_01/out/location/`). Before them, travelling to Whispering
  /// Woods showed the same screen as staying home minus a picture — the Adventure
  /// screen was already location-aware in its *nodes* and had art for exactly one
  /// place, so the milestone's headline feature arrived somewhere that looked
  /// like nowhere.
  static const Map<String, String> _vignetteByLocation = <String, String>{
    'location.havens_rest': '$_art/location/havens_rest.png',
    'location.whispering_woods': '$_art/location/whispering_woods.png',
    'location.stonefall_mine': '$_art/location/stonefall_mine.png',
    'location.frostmere': '$_art/location/frostmere.png',
    'location.forgotten_hollow': '$_art/location/forgotten_hollow.png',
  };

  /// The arrival vignette for a location, or null where none is drawn.
  ///
  /// Null rather than a placeholder: a vignette is a 176 px band across the
  /// whole screen, and a placeholder that size would read as a broken image
  /// rather than as absent art.
  static String? vignetteFor(ContentId location) =>
      _vignetteByLocation[location.value];

  /// A second framing of each location — Regional Content Pack 01's five
  /// accepted vignette variants (the Ford, the Ring, the Spoil Heaps, the
  /// Mere, the Pass), integrated by Fable V2 (`DECISIONS/0027`) for the World
  /// inspector so the atlas panel can show the destination without repeating
  /// the Adventure backdrop pixel for pixel.
  static const Map<String, String> _altVignetteByLocation = <String, String>{
    'location.havens_rest': '$_art/location/alt_havens_rest.png',
    'location.whispering_woods': '$_art/location/alt_whispering_woods.png',
    'location.stonefall_mine': '$_art/location/alt_stonefall_mine.png',
    'location.frostmere': '$_art/location/alt_frostmere.png',
    'location.forgotten_hollow': '$_art/location/alt_forgotten_hollow.png',
  };

  /// The variant framing for a location, or null where none is packaged.
  static String? altVignetteFor(ContentId location) =>
      _altVignetteByLocation[location.value];

  // ----------------------------------------------------------------- skills

  /// All five Milestone 01 skills.
  ///
  /// Originally only Foraging shipped, on the reasoning that it was the only
  /// skill with a Phase 1 *action*. Visual QA found the consequence: the
  /// Character screen lists five skills, four rows had no icon, and the one
  /// that did read as a stray decoration rather than as a member of a set.
  /// Shipping four more 12 × 12 sprites was cheaper than the defect.
  ///
  /// **OD-04 round 2 — one PixelLab set, five silhouette families** (leaf
  /// sprig, log round, ore lump, anvil, two-handled pot; Transformation Build
  /// 01). Round 1 failed blind QA because two hafted tools were the same object
  /// at play scale; this set has none. 24 × 24 native drawn ×1 — see
  /// `PixelAsset.skill`. Awaiting the round's Visual QA verdict at play scale
  /// (`TRANSFORMATION_01/items/README.md`); the temporary 12 × 12 set it
  /// replaced is in git history should the verdict fail.
  ///
  /// They appear in two places: the Skills/Character rows and the gather
  /// card's skill chip, both at 24 logical px, which is the verdict view.
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
  /// Every item in `items.json` now has an icon; [itemUnknown] remains the
  /// honest answer for a content pack that names one this set does not cover.
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
    'item.duskcap': '$_art/item/duskcap.png',
    'item.rime_blossom': '$_art/item/rime_blossom.png',
    'item.duskcap_skewer': '$_art/item/duskcap_skewer.png',
    'item.frostbloom_tea': '$_art/item/frostbloom_tea.png',

    // Transformation Build 01. The nine that rendered the slab: the whole
    // bronze tier, the two cooked bowls, the Hollow's root and its sigil. Four
    // of these are crafted outputs, so the Craft screen no longer offers to
    // make a blank. Blind grid read of the sigil is recorded in
    // `TRANSFORMATION_01/items/README.md`.
    'item.hollow_root': '$_art/item/hollow_root.png',
    'item.pine_plank': '$_art/item/pine_plank.png',
    'item.bronze_sword': '$_art/item/bronze_sword.png',
    'item.bronze_axe': '$_art/item/bronze_axe.png',
    'item.bronze_pickaxe': '$_art/item/bronze_pickaxe.png',
    'item.bronze_chestplate': '$_art/item/bronze_chestplate.png',
    'item.herb_broth': '$_art/item/herb_broth.png',
    'item.hearty_stew': '$_art/item/hearty_stew.png',
    'item.hollow_sigil': '$_art/item/hollow_sigil.png',

    // World & Reward Depth 01. The four icons were packaged (blind QA PASS)
    // and these entries were forgotten, so every surface — victory rewards,
    // Inventory, Craft — rendered the deliberately blank `unknown` slab on a
    // physical phone. `phase2_content_test`'s every-item-resolves assertion
    // now makes that omission a failing test rather than a device finding.
    'item.wolf_pelt': '$_art/item/wolf_pelt.png',
    'item.lynx_pelt': '$_art/item/lynx_pelt.png',
    'item.wolfhide_jerkin': '$_art/item/wolfhide_jerkin.png',
    'item.frostlined_jerkin': '$_art/item/frostlined_jerkin.png',

    // Exploration & Progression Loop 01. Three material icons integrated from
    // Regional Content Pack 01's accepted set, and the milestone's own
    // twelve-icon pixen round — every verdict, prompt and re-roll in
    // `EXPLORATION_PROGRESSION_LOOP_01/items/README.md`. All twelve accepted
    // across three blind rounds (heat scale, ram wool and the toolhead each
    // re-rolled after failed first reads).
    'item.boar_tusk': '$_art/item/boar_tusk.png',
    'item.bear_pelt': '$_art/item/bear_pelt.png',
    'item.ram_horn': '$_art/item/ram_horn.png',
    'item.oak_plank': '$_art/item/oak_plank.png',
    'item.scrap_metal': '$_art/item/scrap_metal.png',
    'item.heat_scale': '$_art/item/heat_scale.png',
    'item.ram_wool': '$_art/item/ram_wool.png',
    'item.boar_hide': '$_art/item/boar_hide.png',
    'item.reinforced_pickaxe': '$_art/item/reinforced_pickaxe.png',
    'item.pristine_wolf_fang': '$_art/item/pristine_wolf_fang.png',
    'item.great_tusk': '$_art/item/great_tusk.png',
    'item.goblin_toolhead': '$_art/item/goblin_toolhead.png',
    'item.ember_core': '$_art/item/ember_core.png',
    'item.frost_claw': '$_art/item/frost_claw.png',
    'item.pristine_horn': '$_art/item/pristine_horn.png',

    // Fable V2 Experiment 01 (`DECISIONS/0027`). The Verge tier's three Epic
    // pieces and the silk that binds the longsword — all four icons from
    // Regional Content Pack 01's accepted gear/material sets, integrated at
    // last instead of sitting unused in the exploration tree.
    'item.gloom_silk': '$_art/item/gloom_silk.png',
    'item.bronze_longsword': '$_art/item/bronze_longsword.png',
    'item.bearhide_coat': '$_art/item/bearhide_coat.png',
    'item.hornbound_bronze_axe': '$_art/item/hornbound_bronze_axe.png',

    // Fable V2 Iteration 03. The Masterwork variants and the two foods wear
    // recorded byte-copies of the icon of the item each one CONSUMES — the
    // same piece, reforged around a trophy (or the dish it is cooked from),
    // so the copy and its donor almost never share a bag. Distinct authored
    // icons are the recorded future PixelLab round
    // (`MILESTONES/FABLE_V2_EXPERIMENT_01.md`, Iteration 03).
    'item.fanghilt_sword': '$_art/item/fanghilt_sword.png',
    'item.tuskbound_jerkin': '$_art/item/tuskbound_jerkin.png',
    'item.goblin_toothed_axe': '$_art/item/goblin_toothed_axe.png',
    'item.scalewarmed_chestplate': '$_art/item/scalewarmed_chestplate.png',
    'item.clawguard_coat': '$_art/item/clawguard_coat.png',
    'item.hornpoint_pickaxe': '$_art/item/hornpoint_pickaxe.png',
    'item.traveler_ration': '$_art/item/traveler_ration.png',
    'item.expedition_stew': '$_art/item/expedition_stew.png',

    // Fable Depth Offensive 01 (`DECISIONS/0028`). The three bronze-lineage
    // pieces wear recorded byte-copies of the icon of the item each recipe
    // CONSUMES — the same piece, rebuilt around the trophy haul — so the copy
    // and its donor almost never share a bag. Distinct authored icons are the
    // recorded future PixelLab round.
    'item.waywarden_tunic': '$_art/item/waywarden_tunic.png',
    'item.tinbraced_pickaxe': '$_art/item/tinbraced_pickaxe.png',
    'item.frostwarden_coat': '$_art/item/frostwarden_coat.png',
  };

  // ------------------------------------------------------------------ nodes

  /// One vignette per gather node — 96 × 96, transparent, no figures — drawn
  /// on the Adventure gather card so a node is a *place at the place* rather
  /// than a name and a button. Null where a content pack names a node this
  /// set does not cover; the card reserves the slot either way.
  static const Map<String, String> _nodeArt = <String, String>{
    'resource_node.meadow_patch': '$_art/node/meadow_patch.png',
    'resource_node.oak_stand': '$_art/node/oak_stand.png',
    'resource_node.duskcap_grove': '$_art/node/duskcap_grove.png',
    'resource_node.copper_seam': '$_art/node/copper_seam.png',
    'resource_node.tin_seam': '$_art/node/tin_seam.png',
    'resource_node.hardened_copper_seam': '$_art/node/hardened_copper_seam.png',
    'resource_node.rimefrost_hollow': '$_art/node/rimefrost_hollow.png',
    'resource_node.frostpine_stand': '$_art/node/frostpine_stand.png',
    'resource_node.hollow_thicket': '$_art/node/hollow_thicket.png',
    // Fable V2 (`DECISIONS/0027`): deterministic copies of the scenery each
    // node deepens (A-2); distinct authored art is a recorded future round.
    'resource_node.deep_tin_seam': '$_art/node/deep_tin_seam.png',
    'resource_node.oldgrowth_frostpine': '$_art/node/oldgrowth_frostpine.png',
    'resource_node.silkstrand_thicket': '$_art/node/silkstrand_thicket.png',
    // Fable V2 Iteration 03: the five depth nodes, same deterministic-copy
    // rule — each reuses the scenery of the node whose subject it deepens.
    'resource_node.heartwood_oak': '$_art/node/heartwood_oak.png',
    'resource_node.old_workings': '$_art/node/old_workings.png',
    'resource_node.veiled_silkstrand': '$_art/node/veiled_silkstrand.png',
    'resource_node.sheltered_frost_meadow':
        '$_art/node/sheltered_frost_meadow.png',
    'resource_node.mill_garden': '$_art/node/mill_garden.png',
    // Fable Depth Offensive 01 (`DECISIONS/0028`): the five depth nodes, same
    // deterministic-copy rule — each reuses the scenery of the node whose
    // subject it deepens.
    'resource_node.warded_grove': '$_art/node/warded_grove.png',
    'resource_node.gallery_tin_lode': '$_art/node/gallery_tin_lode.png',
    'resource_node.collapsed_span': '$_art/node/collapsed_span.png',
    'resource_node.undercroft_silkfall': '$_art/node/undercroft_silkfall.png',
    'resource_node.deep_hollow_thicket': '$_art/node/deep_hollow_thicket.png',
  };

  static String? nodeFor(ContentId node) => _nodeArt[node.value];

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

  // ---------------------------------------------------------------- recipes

  /// Recipe-level art, for the recipes whose OUTPUT ITEM does not name the
  /// job (`ART-07_item_brief.md` §3).
  ///
  /// Three recipes need this and no others: the reclaims all output
  /// `item.bronze_ingot`, so the bench drew the same plain ingot on three
  /// rows with no cue to which piece was being salvaged. The brief's answer
  /// is a salvage crate stamped with the reclaimed item's silhouette —
  /// process, not output — which matches the model `stride_session.dart`
  /// already keeps (reclaims are carved out of the lineage graph).
  ///
  /// This is a **presentation** path and nothing else: the recipe's output,
  /// its ingredients and its lineage are unchanged, and `itemFor` still
  /// answers everywhere `item.bronze_ingot` is the literal thing on screen.
  static const Map<String, String> _recipeIcons = <String, String>{
    'recipe.reclaim_bronze_axe': '$_art/item/reclaim_axe.png',
    'recipe.reclaim_bronze_pickaxe': '$_art/item/reclaim_pickaxe.png',
    'recipe.reclaim_bronze_chestplate': '$_art/item/reclaim_chestplate.png',
  };

  /// Which of [_recipeIcons] is actually **packaged** — present on disk and
  /// declared in `pubspec.yaml`.
  ///
  /// Deliberately separate from the path table, and deliberately empty until
  /// the art lands. A path is a promise the bundle has to keep: naming an
  /// undeclared asset renders a silent blank where a recognisable ingot used
  /// to be, which is a worse screen than the one the brief is fixing. So the
  /// table records the intent, this set records the fact, and the integrator
  /// flips one row on per accepted crate — the same two-list discipline
  /// `item_icon_resolution_test.dart` exists to enforce for items.
  ///
  /// All three crates landed in FMPO02 wave 2 (`ITEMS_report.md`): packaged by
  /// `Scripts/art/package-art.js` into `assets/art/v1/item/` and declared file
  /// by file in `pubspec.yaml`, so the promise the path table makes is now one
  /// the bundle keeps.
  static const Set<String> _packagedRecipeIcons = <String>{
    'recipe.reclaim_bronze_axe',
    'recipe.reclaim_bronze_pickaxe',
    'recipe.reclaim_bronze_chestplate',
  };

  /// Whether [recipe] has recipe-level art that is packaged and safe to draw.
  static bool hasRecipeIcon(ContentId recipe) =>
      _packagedRecipeIcons.contains(recipe.value) &&
      _recipeIcons.containsKey(recipe.value);

  /// The icon a recipe row draws: its own art where that exists and is
  /// packaged, and otherwise the output item's icon — the rule every
  /// non-reclaim recipe has always followed.
  ///
  /// Two ids rather than a `RecipeOption`, because this file names no type
  /// from `stride_session.dart` and must not start: it is a lookup table, and
  /// the caller already holds both ids.
  static String recipeIconFor(ContentId recipe, ContentId outputItem) =>
      hasRecipeIcon(recipe) ? _recipeIcons[recipe.value]! : itemFor(outputItem);

  // ------------------------------------------------------------- navigation

  static const String navAdventure = '$_base/nav_adventure.png';
  static const String navCharacter = '$_base/nav_character.png';
  static const String navSkills = '$_base/nav_skills.png';
  static const String navInventory = '$_base/nav_inventory.png';
  static const String navCraft = '$_base/nav_craft.png';
  static const String navWorld = '$_base/nav_world.png';

  // The six `_hi` active variants are **retired** (EPO03, `DIR-15` §2, Q-26).
  //
  // Three of them shipped from `gen_assets.js` and three were derived by
  // `Scripts/art/nav-active-variant.js` from the index remap those three
  // measured. They existed to answer one question — which tab am I on — and
  // the bar now answers it with a **raised, lit plate** under the glyph
  // instead (`stride_tab_bar.dart`).
  //
  // Q-26 is why the plate wins and the brighter glyph loses. A nav glyph sits
  // on the type ladder, not under the chrome ceiling: the shipped silhouettes
  // read at roughly 6:1 against the bar, and every attempt to author a pair
  // inside the ceiling separated *less* than the derived remap did while
  // costing legibility at 14 px (FMPO02 `UI_report.md` §5). With a lit plate
  // carrying the state, a second brightened glyph says the same thing again,
  // more weakly — and `nav_world_hi`, the one variant FMPO02 could never
  // author at all, stops being a gap in the set.
  //
  // The PNGs and their `pubspec.yaml` rows stay for now, and so does
  // `nav-active-variant.js` and its CI check: deleting a shipped asset and
  // editing the workflow that guards it is a separate change with a separate
  // owner, and a declared asset nothing draws costs a bundle entry, not a
  // defect. Removing the constants is what makes the retirement real in code —
  // nothing can reach for a brighter glyph by accident.
}
