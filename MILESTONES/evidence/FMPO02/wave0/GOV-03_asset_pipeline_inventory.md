# GOV-03 — Current Asset & PixelLab Inventory

Audit only. No quality judgments, no scope proposals. All paths repo-relative.

## 1. The packaging pipeline

`Scripts/art/package-art.js` (3032 lines) is the only writer of `assets/art/v1/`
and of the generated `lib/ui/icons/sprite_footprints.dart`. It reads **only**
from `GAME_BIBLE/ART/exploration/<ROUND>/out/...` and never from anywhere else.
`Scripts/art/png.js` is its sole dependency: a hand-rolled RGBA8 PNG codec
(`load`/`loadAny`/`save`) plus deterministic pixel ops (`crop`, `blit`, `scale`,
`fill`, `bounds`, `footprint`). No third-party packages — `pngjs` is required by
the exploration tools but is not installed anywhere in the repo, so those tools
cannot run on a clean checkout; packaging must.

**Mechanics of `emit(rel, bytes)`:** records bytes for `assets/art/v1/<rel>`
into an in-memory map. Plain run: writes the file. `--check` run (what CI
calls): compares against what's on disk and pushes to a `problems[]` list
(`missing:`, `stale:`, `unexpected:` for orphans) instead of writing; exits 1 if
any problems exist. Every source round is read via a `manifest.json` (frame
counts, canvases, `status: accepted/withheld`) so packaging cannot silently
disagree with what a PixelLab round actually delivered, and a `withheld` entry
can never ship.

**Source rounds feeding it** (chronological, each is its own directory under
`GAME_BIBLE/ART/exploration/`): `PIXELLAB_STABILIZATION_01`, `PIXELLAB_PROOF_02`
(portrait/base sprite), `TRANSFORMATION_01`, `PLAYABLE_EXPANSION_01`,
`ACTIVITY_FEEL_01`, `PLAYABLE_POLISH_01`, `PLAYABLE_POLISH_02`,
`EXPLORATION_PROGRESSION_LOOP_01`, `REGIONAL_CONTENT_PACK_01`,
`PRESENTATION_WORLD_REWARD_FEEL_01`, `PLAYABLE_EXPERIENCE_REFINEMENT_01`,
`WORLD_MAP_POLISH_01/03`, `WORLD_MAP_EXPANSION_REFINEMENT_02`,
`WORLD_ATLAS_COHERENCE_UI_01`, `WORLD_ATLAS_RESTORE_01`,
`WORLD_ATLAS_REMASTER_01`, `FABLE_V2_EXPERIMENT_01`, `FABLE_V2_ITERATION_03`,
`FABLE_DEPTH_OFFENSIVE_01`, `VAWO01` (current).

**Output dirs under `assets/art/v1/`** (974 PNGs total): `combat/` 323,
`ambient/` 240, `env/` 239, `item/` 59, `work/` 43, `node/` 24, `anim/` 14,
`reward/` 10, `location/` 10, `world/` 7, `sprite/` 4, `portrait/` 1.
Interface chrome is a **separate, hand-maintained** tree at `assets/ui/v1/`
(23 files) that packaging never touches — see §9.

**Asset key naming:** file path relative to `assets/art/v1/`, no version
suffix in the filename (`item/bronze_ingot.png`, not `icon_bronze_ingot_48`).
Sequence frames are `<id>_f<n>.png`. The Dart-side "key" used by the atlas
table is the path minus root and extension (`world/atlas_base`).

**Dart consumers (the registry, not a single "ArtRegistry" class):**
`lib/ui/icons/pixel_icons.dart` (`PixelIcons`, `ItemIcons` — items, nav, skill
glyphs, portrait, vignettes), `traveler_art.dart` (`TravelerArt` — equipment
variant resolution), `combat_assets.dart` (`CombatAssets`, `CombatantArt`,
`CombatTrack`), `ambient_assets.dart` (`AmbientAssets` — gather/ambient/work
scenes), `atlas_assets.dart` (`AtlasAssets.pathFor/framePath` — generic key→path
for `atlas_layout.json`), `reward_art.dart` (`RewardArt`), and the generated
`sprite_footprints.dart` (`SpriteFootprints`, `SpriteFootprint`). No file is
named `art_manifest.dart` or `ArtRegistry`; `class PixelAsset` (the render
widget, not a registry) lives in `lib/ui/components/pixel_asset.dart`.

### Worked example A — add one new 48×48 item icon

1. Land the accepted PixelLab PNG (exactly 48×48, RGBA8) under a new or
   existing exploration round, e.g.
   `GAME_BIBLE/ART/exploration/<ROUND>/out/items/icon_<id>_48.png`, with a
   `manifest.json` entry (`status: "accepted"`) if the round uses one.
2. In `package-art.js`, add one `emit('item/<id>.png', encode(...))` call
   (copy the `ITEM_ICONS_T01`/`eplManifest` pattern), guarded by the same
   `48x48` assertion every other icon uses.
3. In `pixel_icons.dart`, add `'item.<id>': '$_art/item/<id>.png'` to
   `_itemIcons`.
4. Add the new file's line to `pubspec.yaml` (integration lead's manual job,
   per `atlas_assets.dart`'s own doc comment — not automatic).
5. `node Scripts/art/package-art.js` (writes it), then `--check` (must report
   "up to date"); run `check-art-palette.js` by hand — not CI-gated (§2).

### Worked example B — add one new animated strip (e.g. a 6-frame ambient loop)

1. Land frames `<id>_f0.png … _f5.png` at the round's `out/` path plus a
   `manifest.json` entry naming `id`, `canvas: [w, h]`, `frames: 6`.
2. In `package-art.js`, loop the manifest the way `ambientWrdManifest`/
   `combatWrdManifest` does: load each frame, assert canvas size, `emit(
   'ambient/<id>_f<i>.png', ...)`, and on frame 0 call `png.footprint(frame)`
   into `ambientFootprints`/`combatFootprints` under key `ambient_<id>` /
   `combat_<id>` — this regenerates `sprite_footprints.dart`'s contact shadow.
3. In `ambient_assets.dart` (or `combat_assets.dart` for a fight track),
   register the sequence via the `_frames('<id>', n)` helper, fps,
   `AmbientLoop` mode, and wire it into the lookup table (skill/enemy/craft
   station) that resolves to it.
4. Add the frame paths to `pubspec.yaml`; run `package-art.js` then `--check`
   (`sprite_footprints.dart` regenerates and must be committed).
5. For a combat weapon/gear track, also run `VAWO01/tools/weapon-presence.js`
   (or rely on the inline `attachedPixelCount` single-component assertion) to
   confirm no per-frame detachment before shipping.

## 2. Guards

| Guard | Enforces | Numeric thresholds | Wired in CI? |
|---|---|---|---|
| `check-art-palette.js` | 4 rules over `assets/art/v1` + `assets/ui/v1`: **teal** collision with `#58D6C0` (L-16 reserved walking colour); **alpha**, no `0 < a < 255` anywhere; **ceiling**, no opaque chrome pixel (`assets/ui/v1/{frame,surface,ornament}`) brighter in relative luminance than `textMuted #7C7263`; **substrate**, no frame pixel (`assets/ui/v1/frame`) drawn in `surfaceCard #201C17` or `surfaceGround #14120F` | Teal Chebyshev radius **10**; one allowlisted file (`glyph_steps.png`); luminance via WCAG-linearized RGB, no numeric slack on ceiling/substrate (exact match / exceed) | **No** — not in `.github/workflows/ci.yml` |
| `check-tile-seam.js` | Tileable chassis/surface edge strips: **wrap** (last column vs first column of the repeat) and **period** (declared repeat is the real one) | Declared repeat period **8** px; wrap tolerance **2.5×** the strip's own interior column-to-column variation; flat-strip floor **1.5**, flat absolute ceiling **6** | **No** |
| `measure-ambient-extents.js` | Nothing (read-only reporting tool) — prints union opaque bounding box per `anim/`/`ambient/` sequence and single-frame bounds per `node/` vignette, for hand-transcription into layout tables | n/a | n/a (not a pass/fail guard) |
| `nav-active-variant.js` | Derives the 4th nav "active" glyph (`nav_world_hi.png`) from an index→index palette remap measured off the 3 shipped `_hi` pairs (`nav_adventure/character/inventory`); `--check` mode verifies the derived file is current | Remap must agree unanimously across the 3 reference pairs or is refused | **Yes** — `.github/workflows/ci.yml` runs `node ./Scripts/art/nav-active-variant.js --check` |

`package-art.js --check` **is** CI-gated (`ci.yml`: "Shipped art matches the
packaging step"). The palette and tile-seam guards exist and are documented as
preconditions of `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md` but are not
invoked by CI — running them is currently a manual step for anyone adding
interface (`assets/ui/v1`) art.

**Provenance requirement:** `assets/ui/v1/README.md` carries one documented row
per shipped file (source round, prompt/seed where applicable, deterministic
post-processing applied, blind-QA verdict); the file's own header states "a
shipped file with no provenance row is a QA defect." `assets/art/v1` has no
equivalent per-file README — its provenance is the `package-art.js` source
comments plus each round's own `README.md`/`*_RECORD_01.md` under
`GAME_BIBLE/ART/exploration/<ROUND>/`.

## 3. VAWO01 tools (`GAME_BIBLE/ART/exploration/VAWO01/`)

`tools/`:
| Script | Purpose |
|---|---|
| `bbox.js` | Prints the opaque bounding box + margins of one or more PNGs (quick measurement, no file writes) |
| `frame-prep.js` | Deterministic chassis-frame prep pipeline: crop, alpha-key, speck removal by connected component, palette remap — no authoring |
| `measure-frame.js` | Reads a candidate chassis frame and reports it against the production plan's fixed numbers (band 6, corner block 16, corner radius 7, repeat period 8) |
| `measure-radius.js` | Profiles a frame's top-left corner arc (first-opaque-x per row) to check corner radius |
| `render-frame.js` | Reproduces Flutter's `_FramePainter.paint` outside Flutter (corners once, edges tiled) so a frame can be judged at real draw scale before packaging |
| `weapon-presence.js` | Checks whether a held weapon survives every frame of a track — the automated version of the VAWO01 finding that PixelLab template animations can drop held props |

`src/`: `chassis_r2_prompt.txt`, `chassis_r2_prompt_flat.txt` — the two chassis
generation prompts (round 2). No script in `tools/` downloads PixelLab
results, keys backgrounds, builds contact sheets, or renders device-scale
review sheets directly — those steps are performed by round-specific tooling
in other exploration directories (e.g. `PIXELLAB_PROOF_02/tools/`,
`WORLD_ATLAS_COHERENCE_UI_01/tools/ocean_unify.js`) or by
`package-art.js` itself (background keying, cropping). `VAWO01/` top level
also holds `out/`, `raw/`, `rejected/`, `review/` (working directories) and
eight round-record markdown files (chassis, enemy, equipment, gather, reward,
weapon, world-life, world).

## 4. Item icon catalog (`assets/art/v1/item/`, all 48×48 unless noted)

59 files map to the `item.*` ids registered in `PixelIcons._itemIcons`
(`lib/ui/icons/pixel_icons.dart`). Full id list, one per line, by shipping
round: **Phase 1/Stabilization** — bronze_ingot, copper_ore, meadow_herb,
oak_handle, oak_log, pine_log, tin_ore, training_axe, training_pickaxe,
training_sword, traveler_tunic, duskcap, rime_blossom, duskcap_skewer,
frostbloom_tea. **Transformation Build 01** — hollow_root, pine_plank,
bronze_sword, bronze_axe, bronze_pickaxe, bronze_chestplate, herb_broth,
hearty_stew, hollow_sigil. **World & Reward Depth 01** — wolf_pelt, lynx_pelt,
wolfhide_jerkin, frostlined_jerkin. **Exploration & Progression Loop 01** —
boar_tusk, bear_pelt, ram_horn, oak_plank, scrap_metal, heat_scale, ram_wool,
boar_hide, reinforced_pickaxe, pristine_wolf_fang, great_tusk,
goblin_toolhead, ember_core, frost_claw, pristine_horn. **Fable V2 Experiment
01** — gloom_silk, bronze_longsword, bearhide_coat, hornbound_bronze_axe.
**Fable V2 Iteration 03** — fanghilt_sword, tuskbound_jerkin,
goblin_toothed_axe, scalewarmed_chestplate, clawguard_coat,
hornpoint_pickaxe, traveler_ration, expedition_stew (last six are recorded
byte-copies of a donor icon, not distinct art). **Fable Depth Offensive 01** —
waywarden_tunic, tinbraced_pickaxe, frostwarden_coat (also byte-copies).
Plus `item/unknown.png` — the one code-drawn (not PixelLab) asset, a
deliberately blank slab for any unmapped `item.*` id
(`PixelIcons.itemUnknown`/`itemFor`).

## 5. Traveler animation assets

| Track | Frames | Canvas | Anchor row | Path |
|---|---|---|---|---|
| `gather` (forage cycle) | 8 | 64×64 (f5 inpaint-repaired) | n/a (rest frame) | `anim/gather_f{0-7}.png` |
| `traveler_walk_west` | 6 | 64×64, feet row 62 | 62 | `anim/traveler_walk_west_f{0-5}.png` |
| ambient idles (breathe, stretch, read, drink, eat, look-around, pack-check, wipe-brow, sit-ground, head-scratch, pushups-side, axe-inspect, pick-inspect, crouch-pet, dangle-string) + cat set (sit-down, stand, stretch, walk, walk-west, lie-rest, roll, bat-yarn) + `pair_pet_cat`, `prop_fire`, `prop_yarn` | 7–9 typ. | 64×64 (80×64 tall variants cropped to 64 rows) | 62 | `ambient/<id>_f{n}.png` |
| `activity_woodcut` / `activity_mine` / `activity_forage` (gather loops) | 8 / 8 / 9 | 64 rows, variable width crop (76/60/44) | 62 | `ambient/activity_<x>_f{n}.png` |
| `activity_smith` / `activity_cook` (craft loops) | 7 / 7 | 64 rows | 62 | `ambient/activity_<x>_f{n}.png` |
| `traveler_combat_idle` (Polish 02 re-author) | 9 | 80×64 | 62 | `combat/traveler_combat_idle_f{0-8}.png` |
| `traveler_attack` | 4 | 80×64 | 62 | `combat/traveler_attack_f{0-3}.png` |
| `traveler_hit` | 6 | 64×64 | 62 | `combat/traveler_hit_f{0-5}.png` |
| `traveler_stagger` (base, defeat-as-retreat) | 9 | 56×64 | 62 | `combat/traveler_stagger_f{0-8}.png` |
| `traveler_unarmed_idle` | 8 | 80×64 | **63** | `combat/traveler_unarmed_idle_f{0-7}.png` |
| `traveler_unarmed_attack` / `_hit` / `_stagger` | 7 / 7 / 9 | 80×64 | 62 | `combat/traveler_unarmed_{track}_f{n}.png` |
| `traveler_bronze_idle` / `_attack` / `_hit` / `_stagger` | 9 / 7 / 5 / 9 | 80×64 | 62 | `combat/traveler_bronze_{track}_f{n}.png` |
| `traveler_south` (rest sprite) / `_plate` / `_jerkin` / `_coat` (armour figures) | 1 each | 64×64 | n/a | `sprite/traveler_south[_<class>].png` |

**Combat variant registration** (`lib/ui/icons/traveler_art.dart`,
`TravelerArt`): `variantOfItem` maps item ids to coarse classes
(`armor.plate` / `armor.jerkin` / `armor.coat`, `weapon.bronze`); `training_sword`
is deliberately unmapped (base figure already carries a plain steel blade).
`combatVariants` maps `'weapon.unarmed' → CombatAssets.travelerUnarmed`,
`'weapon.bronze' → CombatAssets.travelerBronze`; `combatantFor()` treats an
**empty weapon slot as `unarmed`** (a value, not a fallthrough) and any other
unmapped equipped weapon as the base `CombatAssets.traveler`. Ghost-gear
integrity is enforced inline in `package-art.js` via `attachedPixelCount()` —
every combat-variant frame's opaque pixels must form one 8-connected component
reachable from the lowest foot pixel, or packaging throws.

## 6. Enemy sprite families (`enemyFor()` in `combat_assets.dart`)

| enemy.* id | Sprite family (file prefix) | Canvas | Anchor row | idle | attack | heavy | hit | defeat |
|---|---|---|---|---|---|---|---|---|
| forest_wolf, old_grey (elite reuse) | wolf | 56² | 40 | 8f | 9f | — | withheld (packaged, unused) | 7f |
| cave_goblin, gallery_foreman (elite) | goblin | 56² | 46 | 7f | 9f | — | 4f | 7f |
| hollow_guardian, guardian_awakened (elite) | guardian | 96² | 83 | 7f | `guardian_swipe` 9f (=normal) | `guardian_attack` 7f (=heavy) | 4f | withheld (holds hit pose) |
| frost_lynx, rimeclaw_matriarch (elite) | lynx (VAWO01 re-author) | 56² | 39 | 7f | 9f | — | withheld | 7f |
| wild_boar | boar (RCP01) | 56² | 43 | 7f | 9f | — | none authored | 7f |
| mountain_ram | ram (RCP01) | 56² | 42 | 7f | 9f | — | withheld | 7f |
| salamander | salamander (RCP01) | 56² | 50 | 7f | 9f | — | none authored | 7f |
| oakback_bear | bear (RCP01, `bear_attack2` only) | 76² | 61 | 7f | 9f | — | none authored | 7f |
| scree_crawler | crawler (RCP01, experimental) | 48² | 40 | 7f | 9f | — | none authored | withheld (holds hit pose) |

Backdrops (192×96, drawn ×2, ground row 88): `backdrop_forest/mine/hollow/
frostmere.png`; `backdropFor()` defaults unmapped locations to forest.
Effects: `fx_impact` and `fx_bite` (32×32, 5 frames each) — bite is used for
mouth-attackers (wolf/lynx/salamander families), impact for everything else.
`wolf_hit` and `guardian_defeat` are **packaged but intentionally unreferenced**
(withheld by manifest status; confirmed present on disk in `assets/art/v1/
combat/` but absent from `combat_assets.dart`'s tables).

## 7. Gather scenes

**22 resource-node vignettes** (96×96, transparent, no figures) in
`assets/art/v1/node/`: meadow_patch, oak_stand, duskcap_grove, copper_seam,
tin_seam, hardened_copper_seam, rimefrost_hollow, frostpine_stand,
hollow_thicket, deep_tin_seam, oldgrowth_frostpine, silkstrand_thicket,
heartwood_oak, old_workings, veiled_silkstrand, sheltered_frost_meadow,
mill_garden, warded_grove, gallery_tin_lode, collapsed_span,
undercroft_silkfall, deep_hollow_thicket — keyed by `resource_node.*` id in
`PixelIcons._nodeArt` / `AmbientAssets._scenery`. (`node/station_forge.png`,
`node/station_cookfire.png` are older 64² craft-station props, superseded by
Polish 02's `work/station_*` but still packaged.)

**Region×skill work backdrops** (384×176, `work/bg_*.png`, 20 files): 7 keyed
`region|skill` pairs authored in VAWO01 (`haven_foraging`, `woods_woodcutting`,
`woods_foraging`, `stonefall_mining`, `frostmere_woodcutting`,
`frostmere_foraging`, `hollow_foraging`), 7 project-built variants that
override once a settlement project completes (`haven_mill_garden`,
`woods_warded_grove`, `stonefall_lift` [2 nodes], `stonefall_gallery` [2
nodes], `frostmere_shelter`, `hollow_field_camp`, `hollow_undercroft` [2
nodes]), 3 pre-VAWO01 profession fallbacks (`bg_mining/woodcutting/
foraging.png`), and 3 craft backdrops (`bg_smithing/woodworking/cooking.png`).
Selection logic in `AmbientAssets.workBackdropFor()`: built-variant → region×skill
keyed → profession fallback, in that priority order, keyed off the location
vignette's own filename so backdrop and painting can never disagree about
place.

**Gather subject "work face" plates** (48×48, `work/prop_*.png`, VAWO01,
L-18a/`DECISIONS/0031`): 14 authored subjects — meadow_bed, duskcap_bed,
rime_cushion, gloom_silk, hollow_root, oak_cut, frostpine_cut, copper_face,
tin_face, hardened_copper_face, ruin_face, heartwood_oak_cut, deep_tin_lode,
oldgrowth_frostpine_cut — each wired to specific nodes in
`AmbientAssets._workProps`, drawn ×2 at native 48 so subject and figure share
pixel density. Craft stations (anvil/bench/cookpot, `work/station_*.png`,
96×96) and 6 older 96² node props round out `work/` (43 files total).

## 8. World atlas

- **Master**: `assets/art/v1/world/atlas_base.png`, **1024×1024**, composed at
  build time by `package-art.js` from a byte-preserved 512×512 accepted
  painting (`PRESENTATION_WORLD_REWARD_FEEL_01/out/world/whole_a_0.png`) sitting
  at (256,256) inside two rings of frontier pieces (`WORLD_MAP_POLISH_03`,
  `WORLD_MAP_EXPANSION_REFINEMENT_02`), five static in-place patches, a
  dither-crossfade seam treatment, `WORLD_ATLAS_COHERENCE_UI_01` seam-bridge
  inpaints, a `WORLD_ATLAS_RESTORE_01` east-join inpaint and ghost-sail repair,
  and a final deterministic ocean-colour conform
  (`WORLD_ATLAS_REMASTER_01/tools/water_join.js`). Displayed at layout `scale
  6`. Two guards run inline during packaging: a **protected-interior** byte-diff
  against an approved snapshot (fails packaging if any repair layer repaints
  the 512×512 core beyond a 20px feathered rim — `MISTAKES.md` M-15), and a
  **landmark-registry** diff against committed golden crops.
- **Overlay layout**: `assets/content/v1/atlas/atlas_layout.json`
  (`schemaVersion`, `world`, `rumors`, `scale: 6`, `base.tiles` [one tile,
  `world/atlas_base` 1024×1024], `kindMarkers`, `locations`, `landmarks` [23
  entries], `routes`, `props`, `overlays` [32 entries]). Every coordinate for
  every drawn feature lives here, never in `package-art.js`.
- **Overlay frame paths**: `assets/art/v1/env/<name>_f<n>.png` (239 files) —
  e.g. `overlay_redwyrm`/`overlay_stormdrake` (72×32, 9f, VAWO01 dragons),
  `overlay_birds` (24×24, 6f), `overlay_smoke` (16×14 post-crop, 6f),
  `overlay_volcano`/`overlay_tree_rustle_a/b`/`overlay_ripple_coast/delta`
  (in-place animated crops of the master, World Map Polish 01), plus static
  landmark props `prop_rimespire` (48×72), `prop_lanterngard` (72×56),
  `prop_black_gable` (56×52), and world marker glyphs `world/marker_haven/
  wilds/worksite/perilous/landmark.png` (20×20).
- **Landmark goldens**: `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/
  goldens/*.png` (15 files: caravan_corridor, cinder_skerries,
  east_watchtower_flank, far_isles, flock_south, frostmere_north_wall,
  ne_iceberg, roadjoin_corridor_west, south_strand_e/w, stag_box,
  volcano_east_cliff, wanderers_isles_e/w, west_caravan_road), each registered
  by id/x/y/w/h in `WORLD_ATLAS_REMASTER_01/landmark_registry.json` and
  diffed against the composed `atlas_base` at packaging time.

## 9. UI art (`assets/ui/v1/`, hand-maintained, 23 files)

| Asset | Native | Displayed | Consumed by |
|---|---|---|---|
| `frame/chassis_64.png` (+ `chassis_64.json` geometry) | 64×64 | ×2 (band 8→16 logical px, corner block 16→32 logical px) | `PanelSkins._chassis` in `lib/ui/components/panel_skin.dart`, registered against **every** `PanelRole` (card, heroPlate, boardSlip, kitTray, combatFrame, modalFrame) as of the current commit; drawn by `PixelFrame`/`_FramePainter` in `lib/ui/components/pixel_asset.dart` |
| `nav_{adventure,character,inventory,craft,skills,world}.png` (6) | 14×14 | 28 | `PixelIcons.nav*` |
| `nav_{adventure,character,inventory,skills,craft,world}_hi.png` (4 authored + `nav_world_hi`/`nav_skills_hi`/`nav_craft_hi` derived) | 14×14 | 28 | active-tab state; 3 authored, 3 derived by `nav-active-variant.js` |
| `glyph_steps.png` / `glyph_steps_muted.png` | 12×12 | 24 | `PixelIcons.stepsGlyph`/`stepsGlyphMuted` — **temporary art**, OD-03 open |
| `glyph_arrow.png` | 12×12 | 24 | `PixelIcons.arrowGlyph` |
| `skill_{foraging,woodcutting,mining,smithing,cooking}.png` (5) | 24×24 | 24 (×1) | `PixelIcons._skillIcons`/`skillFor()` |

`PanelSkin` (in `panel_skin.dart`) is the geometry contract: `assetPath`,
`nativeWidth/Height`, `corner` (drawing figure — full corner block including
transparent bite), `band` (**layout** figure — actual inset, `content is inset
by band*scale, never corner*scale`), `scale` (integer only). `PixelFrame`'s
`_FramePainter` draws 4 corners once each plus tiled (never stretched) edge
runs per `DECISIONS/0029`'s ban on `centerSlice`. `PanelSkins.authored` is the
role→skin map; an empty entry falls back to a painted rectangle with a
reserved inset (`_reserve`) so a future asset landing never reflows layout.

## 10. Reward marks (`assets/art/v1/reward/`, 10 files, VAWO01)

24² (beside a line of type): `mark_exp.png`, `mark_skill_xp.png`,
`mark_bonus_yield.png`, `mark_knowledge.png`. 48² (stands alone): `plate_level_
up.png`, `badge_milestone.png`, `marker_profession.png`, `seal_contract.png`,
`seal_project.png`. 32² ornament: `ornament_corner.png` (the sanctioned
`DECISIONS/0029` "discrete ornament" mechanism; Flutter rotates/positions one
asset into corners rather than drawing four). All registered in
`lib/ui/icons/reward_art.dart` (`RewardArt`), with `RewardArt.all` as the
precache/coverage list.
