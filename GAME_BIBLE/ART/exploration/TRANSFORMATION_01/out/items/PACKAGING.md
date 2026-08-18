# out/items — packaging map (workstream F)

Source file → intended shipped path → native → display. The integration lead
adds the emit lines to `Scripts/art/package-art.js`; nothing here is copied by
this stream. All files: RGBA8 PNG, zero semi-transparent pixels, zero teal.

## Item icons (extend `ITEM_ICONS`; the ids exist in `assets/content/v1/items.json`)

| Source | Shipped path | Native | Display |
|---|---|---|---|
| `icon_hollow_root_48.png` | `assets/art/v1/item/hollow_root.png` | 48×48 | ×1 in the 84 px inventory cell |
| `icon_pine_plank_48.png` | `assets/art/v1/item/pine_plank.png` | 48×48 | ×1 |
| `icon_bronze_sword_48.png` | `assets/art/v1/item/bronze_sword.png` | 48×48 | ×1 |
| `icon_bronze_axe_48.png` | `assets/art/v1/item/bronze_axe.png` | 48×48 | ×1 |
| `icon_bronze_pickaxe_48.png` | `assets/art/v1/item/bronze_pickaxe.png` | 48×48 | ×1 |
| `icon_bronze_chestplate_48.png` | `assets/art/v1/item/bronze_chestplate.png` | 48×48 | ×1 |
| `icon_herb_broth_48.png` | `assets/art/v1/item/herb_broth.png` | 48×48 | ×1 |
| `icon_hearty_stew_48.png` | `assets/art/v1/item/hearty_stew.png` | 48×48 | ×1 |
| `icon_hollow_sigil_48.png` | `assets/art/v1/item/hollow_sigil.png` | 48×48 | ×1 — **pending the blind grid read**; alternate is `../../items/candidates/hollow_sigil_c3.png` |

Note: `package-art.js` currently reads icons from `PIXELLAB_STABILIZATION_01/out/icons_full`;
these nine live under `TRANSFORMATION_01/out/items/` and need their own source
root in the script.

## Gather-node card art (new asset family; no `assets/art/v1/node/` exists yet)

| Source | Shipped path | Native | Display |
|---|---|---|---|
| `node_meadow_patch_96.png` | `assets/art/v1/node/meadow_patch.png` | 96×96 | ×1 or ×2 in the gather card (brief §2) |
| `node_oak_stand_96.png` | `assets/art/v1/node/oak_stand.png` | 96×96 | same |
| `node_duskcap_grove_96.png` | `assets/art/v1/node/duskcap_grove.png` | 96×96 | same |
| `node_copper_seam_96.png` | `assets/art/v1/node/copper_seam.png` | 96×96 | same |
| `node_tin_seam_96.png` | `assets/art/v1/node/tin_seam.png` | 96×96 | same |
| `node_rimefrost_hollow_96.png` | `assets/art/v1/node/rimefrost_hollow.png` | 96×96 | same |
| `node_frostpine_stand_96.png` | `assets/art/v1/node/frostpine_stand.png` | 96×96 | same |
| `node_hollow_thicket_96.png` | `assets/art/v1/node/hollow_thicket.png` | 96×96 | same |

Ids match `assets/content/v1/resource_nodes.json` (`resource_node.<id>`).
Grounding: none baked in; if a node sits on the card ground, apply the
compositor contact-shadow rule (STYLE_SPEC §10b Rule A) or none.

## Skill icons (OD-04 second attempt — lead decides which size ships, if either)

| Source | Shipped path | Native | Display |
|---|---|---|---|
| `skill_foraging_24.png` … `skill_cooking_24.png` | `assets/ui/v1/skill_<id>.png` | 24×24 | **×1** = 24 px (the widget declares native size; today it declares 12 and draws ×2 — the declaration would change to 24 / ×1) |
| `skill_foraging_12.png` … `skill_cooking_12.png` | `assets/ui/v1/skill_<id>.png` | 12×12 | ×2 = 24 px, drop-in for the current declaration; nearest-neighbour reductions of the 24s |

`assets/ui/v1/README.md` must be updated by whoever packages (provenance table
says gen_assets.js; these are PixelLab). The 24-native route is a UI-density
change and needs the UI Pixel Designer's say-so, not just packaging.
