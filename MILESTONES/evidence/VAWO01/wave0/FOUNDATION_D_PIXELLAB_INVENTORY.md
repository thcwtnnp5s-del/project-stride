# FOUNDATION-D — PixelLab Inventory Audit

```
STATUS: read-and-report only · no file modified except this one · NOT CANON
Agent: FOUNDATION-D, VAWO01 Wave 0. Date: 2026-09-01.
Branch: presentation-combat-evolution-01 @ 6d41bce.
Every count below is from a command run this session, not from a document.
```

**The owner's premise is half right, and the half that is wrong matters.**
There is a real menu of already-paid-for art sitting unused — but the largest
item on it is not unused *art*. It is **already-shipped art used on one surface
when it could serve seven**. The single biggest visible payoff in this audit
costs **zero generations and zero new files**, and three of the four
top-ranked items are Dart edits against assets already in `pubspec.yaml`.

The second finding is a correction to the premise: a large fraction of the
unshipped exploration art is unshipped **because a blind reviewer rejected it**,
with the verdict written down. Those verdicts are respected below and flagged
explicitly, because "strong existing assets sitting unused" and "assets a
reviewer already refused" look identical on disk.

---

## 1. What the five canonical art documents claim

### `GAME_BIBLE/ART/PIXELLAB_ASSET_INVENTORY.md` (107 lines)

The index across every round's verdicts, established 2026-08-27 by Fable V2
Experiment 01, explicitly so "no good production art rots unused because nobody
audited it." Classifies assets **A** (used) through **I** (unclear). Its §3
"Viable but deliberately unused" and §5 "Superseded / failed — do not integrate"
are the closest thing the repo has to a pre-existing menu.

**This audit verified it against disk and found it accurate.** Every claim I
spot-checked held. It is stale in exactly one place: it predates PCE01 landing
`PanelSkin`/`PixelFrame`, so its picture of the UI primitives is one milestone
behind. Treat it as authoritative and update it when VAWO01 ships.

### `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md` (1,043 lines)

The post-refresh generation queue: nine batches (A chassis frame kit, B skills
trade bands, C surface grains, D combat, E reward, F inventory, G craft, H board,
I backplates), ~35 committed generations against a 4,516 cycle allowance. Its
headline is that **generations are cheap and blind review rounds are the real
cost**, and that the first window buys Batch A and nothing else.

Two sections are directly load-bearing for this audit:

- **§4 "Reuse first — what must NOT be generated"** — a verified-on-disk table of
  existing material that removes work from the queue. It is the seed of THE MENU
  below, and I re-verified all six of its rows.
- **§11 "DO NOT AUTHOR"** — semantic blockers. No timer/hourglass/capacity/gauge
  shapes, no coin or price, no rarity gem, no D-pad or steering affordance, **no
  text or numerals in any raster at any size**, no per-state frame variants, no
  `centerSlice`. Also the craft prohibitions: no AA, no semi-transparent pixel,
  no gradient, no glow, no cast shadow. Any menu item that violates these is
  refused however well drawn.
- **§12** corrects a stale claim in the material-direction draft: **OD-03 (the
  step glyph) is CLOSED**, shipped by Activity Feel 01. `glyph_steps.png` is a
  real PixelLab boot, and I confirmed it is the only one of 871 shipped PNGs
  carrying `#58D6C0`.

Its most useful negative claim, which I verified: **there is no parchment, no
leather, no metal plate, no frame, no border, no divider, no ornament and no
seamless tile anywhere in this repository.** `assets/ui/v1/` is 20 PNGs and every
one is a 12–24 px nav or skill glyph (the pubspec declares 21 lines; the
directory holds 20 PNGs plus a README). Chassis frame material genuinely does not
exist and cannot be found by looking harder.

### `GAME_BIBLE/ART/ART_DIRECTION.md` (402 lines)

Owner-locked direction. Direction A "Classic Pixel MMO Lite" as amended by Owner
Direction Round 01 and the UI Baseline Closeout (2026-08-16). The invariant that
governs every integration below is **L-18**: every raster is drawn at an exact
integer multiple of its native size with nearest-neighbour filtering — which is
why "crop, never stretch" recurs, and why `centerSlice` is banned.

### `GAME_BIBLE/ART/UI_MATERIAL_DIRECTION_01.md` (461 lines, DRAFT)

The diagnosis that every screen is the same material. Proposes primitives P-1
`PanelSkin`/`PanelRole` through P-8 `HeroPlate`, and — critically for VAWO01 —
**§4 "What ships now, with zero new art" (N-1 … N-7)**, ranked by identity gained
÷ cost. §6 draws the Flutter-owns/raster-owns line.

**Landing status verified this session:** N-7 (`PanelSkin`, `PanelRole`,
`PixelFrame`) **has shipped** — `lib/ui/components/panel_skin.dart` is 208 lines,
`PixelFrame` is at `pixel_asset.dart:315`. **N-2, N-3, N-5 and N-6 have not** —
there is no `lib/ui/components/screen_backdrop.dart`, and
`lib/ui/screens/adventure/bestiary_screen.dart` contains no combat-asset
reference. That is four unclaimed zero-art wins, and it is the top of THE MENU.

### `GAME_BIBLE/ART/PIXEL_ART_CRAFT_SPEC.md` (692 lines)

Craft law, not direction. Owns the three-quarter orientation, pose and gesture,
cluster grammar, value and palette, resource-node and environment craft, UI craft
(§6), the red-flag list (§7), and §8's standard output set and review procedure —
the ×1/×2/×8 strip plus the **blind** independent Visual QA read. §8 is the
mechanism that produced every verdict quoted in this report, and it is why a
"WITHHELD" asset is not a free win.

---

## 2. Asset directory census

### 2.1 Shipped tree — `assets/` (896 files, 23 MB)

| Path | Files | Contents |
|---|---:|---|
| `assets/art/v1/combat/` | 262 | 4 stage backdrops + 10 creature sets (Traveler, wolf, goblin, guardian, lynx, boar, ram, salamander, bear, scree crawler) as idle/attack/hit/defeat + `fx_bite`, `fx_impact` |
| `assets/art/v1/ambient/` | 240 | 15 Traveler idle loops, 8 cat loops, 5 activity loops, `pair_pet_cat`, `prop_fire`, `prop_yarn`, 4 fauna stills — 64² unless noted |
| `assets/art/v1/env/` | 218 | 21 animated atlas overlays (`overlay_*`) + 7 static `prop_*`, 20–96 px |
| `assets/art/v1/item/` | 59 | 48² inventory icons |
| `assets/art/v1/node/` | 24 | 96² resource-node vignettes + 2 64² stations |
| `assets/ui/v1/` | 21 (20 PNG) | 12 nav glyphs 14², 3 glyphs 12², 5 skill icons 24², README |
| `assets/art/v1/work/` | 15 | 6 work backdrops 384×176, 6 props 96², 3 stations 96² |
| `assets/art/v1/anim/` | 14 | `gather_f0-7` + `traveler_walk_west_f0-5`, all 64² |
| `assets/content/v1/` | 11 | content JSON + `atlas/atlas_layout.json` |
| `assets/art/v1/location/` | 10 | 5 primary + 5 `alt_*` vignettes, all 384×176 |
| `assets/art/v1/world/` | 7 | `atlas_base.png` 1024², `region_map.png` 384×640, 5 markers 20² |
| `assets/audio/v1/` | 11 | 5 music `.m4a`, 5 sfx `.wav`, README |
| `assets/art/v1/portrait|sprite` | 2 | `traveler.png` 64², `traveler_south.png` 64² |

**871 PNGs, 242 distinct asset keys.**

### 2.2 Generation workspace — `GAME_BIBLE/ART/exploration/` (6,286 files, 5,755 images, 89 MB)

41 round directories. **1,670 files are git-tracked**; the rest are local-only by
`.gitignore` design (lines 138–218: deny-all with per-round exceptions for the
paths `package-art.js` actually reads).

Image breakdown: **1,983 in `out/` (deliverable)**, **3,015 in
`qa/`/`review/`/`rejected/`/`candidates/`/`evidence/` (process artefacts, not
assets)**, 757 in raw/work/blind-code directories.

Largest rounds by size: `PLAYABLE_EXPANSION_01` 15 MB/1,562 files,
`WORLD_REWARD_DEPTH_01` 14 MB/659, `WORLD_ATLAS_COHERENCE_UI_01` 12 MB/185,
`TRANSFORMATION_01` 10 MB/970, `REGIONAL_CONTENT_PACK_01` 8 MB/794.

**No art lives anywhere else.** `Scripts/art/` holds tooling only;
`MILESTONES/evidence/` holds one screenshot; `build/` is generated.

---

## 3. What is actually shipped, and the packaging pipeline

`pubspec.yaml` declares assets in two styles: **file-by-file** for content JSON,
UI glyphs, item icons, anim frames, locations and audio; and **whole-directory**
for the four bulk families (`ambient/`, `combat/`, `world/`, `env/`, `node/`,
`work/`), with an in-file comment explaining that listing those individually
would be "a second copy of that manifest that drifts."

**The pipeline.** `Scripts/art/package-art.js` (117 KB) is the only writer of
`assets/art/v1/`. It reads only from `GAME_BIBLE/ART/exploration/`, and CI re-runs
it with `--check` so a hand-edited asset fails the build. Sources are resolved
from named round constants (`STABLE`, `CHARACTER`, `TRANSFORM`, `AMBIENT_FIX_SRC`,
`AMBIENT_WRD_SRC`, `FAUNA_SRC`, `WRD`, …) and gated on per-round
`manifest.json` files carrying a **`status` field** — only `accepted` entries are
emitted, and `withheld_manifest.json` entries are skipped unless an explicit
override set names them (`AMBIENT_FIX_OVERRIDES = new Set(['traveler_pick_inspect'])`).

**This is the provenance system, and it is good.** Manifests found:
`REGIONAL_CONTENT_PACK_01/out/{enemies,fauna,gear,materials,vignettes,world}/manifest.json`,
`TRANSFORMATION_01/out/ambient/`, `PLAYABLE_EXPANSION_01/out/{ambient,combat}/`
(+ `withheld_manifest.json`), `WORLD_REWARD_DEPTH_01/{ambient,combat,items}/`,
`EXPLORATION_PROGRESSION_LOOP_01/out/items/`, `PLAYABLE_POLISH_02/out/combat/`,
plus `REGIONAL_CONTENT_PACK_01/INTEGRATION_MANIFEST.md` and
`WORLD_ATLAS_REMASTER_01/regions_manifest.json`. Per-round `README.md` files carry
the transcribed blind QA verdicts.

**Adding an asset to the game is therefore: track the source (gitignore
exception) → add/flip its manifest entry or a `package-art.js` emit → run the
script → declare in `pubspec.yaml` if not in a bulk directory → reference from
`lib/ui/icons/*.dart`.** Three test guards enforce the lists agreeing:
`item_icon_resolution_test`, `node_art_resolution_test`, `atlas_scene_test`.

### Reference computation

I extracted all 242 shipped asset keys (basename minus `_f<N>`) and matched them
against the concatenated `lib/` Dart source, the `test/` + `integration_test/`
source, and the content JSON (paths are built dynamically from IDs, so
path-literal grepping alone gives false positives).

| Result | Keys | Files |
|---|---:|---:|
| Shipped and referenced by `lib/` or resolved through content JSON | 235 | 859 |
| **Shipped, in the app bundle, referenced by nothing** | **7** | **12** |

**The 7 orphans — art the player has already downloaded and can never see:**

| Asset | Native | Status |
|---|---|---|
| `assets/art/v1/env/prop_boulders.png` | 48×40 | in `pubspec`, past `--check`, no consumer |
| `assets/art/v1/env/prop_dead_tree.png` | 40×48 | " |
| `assets/art/v1/env/prop_hedgerow.png` | 48×32 | " |
| `assets/art/v1/env/prop_lone_oak.png` | 48×48 | " |
| `assets/art/v1/env/prop_pine_clump.png` | 48×56 | " |
| `assets/art/v1/env/prop_snowdrift.png` | 48×32 | " |
| `assets/art/v1/env/overlay_forge_smoke_f0–f5.png` | 32×48 ×6 | animated, 6 frames, no layout entry |

`prop_cairn` (32×40) is the seventh sibling and **is** placed — it appears in
`atlas_layout.json` via `atlas_scene_test.dart`. That proves the placement
mechanism works and that these six are one layout-JSON entry each away from
being visible. The UI production plan §4 already recorded them ("`lib/`
references none of them") and correctly declined to conscript them into chrome —
they belong to a world/atlas decision. **VAWO01 is that decision's natural home.**

---

## 4. Unused inventory by category

Everything below is unshipped. Classification: **GOOD-AND-SHIPPABLE** ·
**SALVAGEABLE-WITH-WORK** · **WRONG-STYLE** · **OBSOLETE** ·
**REJECTED-BY-PRIOR-REVIEW**.

### 4.1 UI frames, panels, banners, textures

**Nothing exists.** Verified: no parchment, leather, metal plate, frame, border,
divider, ornament or seamless tile in the repository, shipped or unshipped. The
closest material is:

| Asset | Native | Class | Note |
|---|---|---|---|
| `PLAYABLE_EXPERIENCE_REFINEMENT_01/out/stage/mine_masonry_s41.png`, `_s97.png` | 384×176 | **SALVAGEABLE-WITH-WORK** | Tracked. Rejected for **placement**, not craft — the best masonry in the repo. UI plan §4 names it the Batch C-3 reference and a crop source. |
| `PLAYABLE_EXPERIENCE_REFINEMENT_01/out/stage/mine_rock_s7`, `woods_open_s7`, `woods_stump_s41`, `woods_stump_s97` | 384×176 | **SALVAGEABLE-WITH-WORK** | Same round, same disposition. Alternate stage framings. |
| `PIXELLAB_PROOF_02/out/environment/tileset_dirt_grass_32.png`, `tileset_grass_stone_32.png` | 128×128 | **REJECTED-BY-PRIOR-REVIEW** | Inventory §5 lists PROOF_02 env tilesets under **G (failed)**. |
| `WALKSCAPE_PIVOT_01/UI_EXPLORATION_01|02/assets/` | 102 imgs | **OUT OF SCOPE** | Code-rendered mockups, not PixelLab output (inventory §6). |
| `DIRECTION_A_ROUND_01/ui_density/out/` | 11 | **OUT OF SCOPE** | Same. |

**Conclusion: Batch A is authoring a material class from nothing. No amount of
inventory searching changes that.**

### 4.2 Item and inventory icons

| Asset | Native | Class | Verdict source |
|---|---|---|---|
| `PIXELLAB_STABILIZATION_01/out/icons_full/icon_canvas_backpack_48.png` | 48² | **SALVAGEABLE-WITH-WORK** | Tracked. No `item.canvas_backpack` exists; a capacity item contradicts the no-capacity stance (Q-UI-1). Design decision first. |
| `RCP01/out/gear/icon_reinforced_bronze_pickaxe_48.png` | 48² | **REJECTED-BY-PRIOR-REVIEW** | Manifest `WITHHELD` after **three** rounds: jumble / polearm / …. |
| `RCP01/out/materials/icon_granite_chitin_48.png` | 48² | **REJECTED-BY-PRIOR-REVIEW** | `WITHHELD` after **four** rounds: helmet / seashell / pauldrons. Its material was struck with it. |
| `PLAYABLE_EXPANSION_01/items/withheld/icon_pine_plank_48.png` | 48² | **REJECTED-BY-PRIOR-REVIEW** | Collides with `oak_handle` in the grid; worse than what ships. |
| `PLAYABLE_EXPANSION_01/items/withheld/node_tin_seam_96.png` | 96² | **SALVAGEABLE-WITH-WORK** | Withheld: gains the ore cue, trades a "cookie" read for a "tile" read. README names the fix: **one** pixen roll for an irregular outcrop. 1 generation. |
| `PIXELLAB_PROOF_02/out/icons/` (12), `PIXELLAB_PROOF_03/out/icons_full/` (12), `PIXELLAB_PROOF_01/out/` (15) | 48²/32² | **OBSOLETE** | Superseded duplicates of the shipped stabilization set (inventory §5 **F**). |

### 4.3 Skill icons

| Asset | Class | Verdict |
|---|---|---|
| `SKILL_ICONS_OD04/out/*_48.png`, `*_12.png` (10 files) | **REJECTED-BY-PRIOR-REVIEW** | `ROUND_01_RESULT.md` header: **"QA VERDICT: FAIL. Not shipped."** BLOCKER — Woodcutting and Mining read as the same object at ×2. Kept "as evidence, not as candidates." |

The carried finding is worth more than the art: **two hafted tools cannot be
told apart at 12×12**; the next round must separate by silhouette *family*, not
head geometry.

### 4.4 Creature and enemy art

From `RCP01/out/enemies/manifest.json` (183 files, fully tracked):

| Asset | Frames | Native | Class | Verdict |
|---|---:|---|---|---|
| `weaver_idle` | 7 | 48² | **GOOD-AND-SHIPPABLE** (content-gated) | `accepted` — "dark figure on the dark Hollow ground band, check in context" |
| `weaver_attack`, `weaver_attack2` | 9, 9 | 48² | **REJECTED-BY-PRIOR-REVIEW** | Two rounds; "indistinguishable from idle at x2", "still reads barely". Explicit *stop*. |
| `weaver_defeat`, `crawler_defeat` | 7, 7 | 48² | **REJECTED-BY-PRIOR-REVIEW** | "legs curl slightly; no collapse read" |
| `bat_idle` / `bat_attack` / `bat_defeat` | 7/9/7 | 40² | **REJECTED-BY-PRIOR-REVIEW** | Identity failure: gargoyle / small dragon / owl |
| `bear_attack` (round 1) | 9 | 76² | **REJECTED-BY-PRIOR-REVIEW** | Read as a walk, not a swipe. `bear_attack2` shipped instead. |
| `ram_hit` | 4 | 56² | **REJECTED-BY-PRIOR-REVIEW** | Head turn only — the known quadruped-flinch failure |

**The Hollow Weaver is the one real content opportunity here, and it cannot
fight.** Inventory §4 defers it as major content: a creature needs an attack that
reads. Its accepted idle is a **presence**, not an encounter.

### 4.5 Fauna and ambient creatures — the richest unused seam

From `RCP01/out/fauna/manifest.json`, **44/44 files tracked**, 17 manifest entries,
**16 marked `accepted`**. Four 16-px stills ship. **Twelve accepted assets do not:**

| Asset | Frames | Native | Class |
|---|---:|---|---|
| `fauna_butterfly_16` | 1 | 16² | **GOOD-AND-SHIPPABLE** — accepted stage-scale still, no region claimed it |
| `fauna_{hare,songbird,crow,ptarmigan,bat,butterfly}_32` | 1 each | 32²/24² | **GOOD-AND-SHIPPABLE** — accepted "concept scale"; needs a surface larger than the 16-px stage slot |
| `fauna_hare_loop` | 7 | 32² | **GOOD-AND-SHIPPABLE** — ear twitch / head turn |
| `fauna_songbird_loop` | 7 | 32² | **GOOD-AND-SHIPPABLE** — head turn |
| `fauna_crow_loop` | 7 | 32² | **GOOD-AND-SHIPPABLE** — head turn |
| `fauna_butterfly_loop` | 5 | 24² | **GOOD-AND-SHIPPABLE** — flutter |
| `fauna_bat_loop` | 5 | 32² | **SALVAGEABLE** — the 16-px bat still failed ("moth at x2"); the 32-px loop was accepted separately |
| `fauna_bat_16` | 1 | 16² | **REJECTED-BY-PRIOR-REVIEW** — reads as a moth |

**31 accepted animation frames of regional wildlife, paid for, QA-passed, and
not in the build.** The blocker is stated in inventory §3 and it is a design
question, not a craft one: the loops are 24/32-px canvases the 16-px stage slot
does not take, and an animated companion is a step past "quiet life" that the
stills should prove out first.

`ACTIVITY_FEEL_01/world_life/` additionally holds `birds_f0-5` (24²),
`wave_f0-5` (24²), `smoke_f0-5` (20²) — but `overlay_birds` and `overlay_smoke`
ship from `out/env/`, and the AF01 wave loop is listed **G (rejected)**.

### 4.6 Traveler / character sprites and directions

`PLAYABLE_EXPANSION_01/combat/candidates/trav_zip/…/animations/` holds **34
animation sets of the production Traveler** at 88×88 (cropped to 64² at (12,12),
feet on row 62). Only `traveler_walk/west/` is gitignore-excepted and shipped.

| Asset | Frames | Class | Verdict |
|---|---:|---|---|
| `traveler_walk/{north,south,east,north-east,north-west,south-east,south-west}` | 6 each = 42 | **SALVAGEABLE-WITH-WORK** | Untracked. `east` loses the vest on f0–f1. Inventory §3: mirroring frames is a creative change PixelLab owns (A-2); needs a direction-QA round *and* a consumer. |
| `traveler_gather/{north,south,east,west}` | 5 each | **SALVAGEABLE-WITH-WORK** | Untracked; no direction-aware staging exists |
| `traveler_herb_gather_pro/south` | 16 | **SALVAGEABLE-WITH-WORK** | Untracked; the longest single Traveler sequence in the repo, never staged |
| `px_axe_whet`, `px_axe_whet2`, `px_pick_kneel`, `px_plank_east`, `px_squats`, `px_stretch_fold` | 9–11 each | **REJECTED-BY-PRIOR-REVIEW** | `PLAYABLE_EXPANSION_01/ambient/README.md` §6 disposition table: sickle head, floating stone, "legs cut off", bow with headless mid-frames, "neither clearly beats `traveler_pushups_side`" |
| `out/ambient/traveler_stretch_side_f0-8`, `traveler_pick_inspect_alt_f0-6` | 9, 7 | **REJECTED-BY-PRIOR-REVIEW** | Withheld: "no better than the current"; packaged "for the record only" |
| `PIXELLAB_PROOF_02/out/character/traveler_*_64.png` (8 directions) | 1 each | **SALVAGEABLE-WITH-WORK** | Untracked (2/18 tracked). Predates the production character; carries a backpack flicker in the matching walk set |
| `PIXELLAB_PROOF_02/out/character/second_*_64.png` (9) | 1 each | **class I — unclear** | Inventory: style transfer PASSED, the asset FAILED. **The proven `create_character` + `style_character_id` recipe is the real asset** for a future NPC cast. |
| `PIXELLAB_PROOF_02/out/animation/walk_*` (8 dirs × 6) | 48 | **OBSOLETE** | Superseded by trav_zip |

**Net: the Traveler animation seam looks enormous and is mostly already
adjudicated.** The genuinely unexamined items are `traveler_herb_gather_pro`
(16 f) and the four-direction `traveler_gather`.

### 4.7 Portraits

`PORTRAIT_SYSTEM_03/` (120 imgs), `PORTRAIT_FACE_PROOF_01/` (85),
`CHARACTER_REBUILD_01/02`, `TRAVELER_REFINE_03`, `FAR_ARM_FEASIBILITY_01`,
`DIRECTION_A_ROUND_01`, `WALKSCAPE_*`, `CODE_RENDER_01`, `HAVENS_REST_*`.

**All OUT OF SCOPE.** Inventory §6: code-rendered exploration (not PixelLab), and
**the character workstream is PAUSED, NOT APPROVED**
(`CHARACTER_PORTRAIT_CLOSEOUT.md`). One portrait ships:
`assets/art/v1/portrait/traveler.png`, 64². Do not mine these for VAWO01.

### 4.8 Props, buildings, map features, world landmarks

| Asset | Native | Class | Verdict |
|---|---|---|---|
| `RCP01/out/world/prop_{plank_bridge,waystone,ruin_corner,mine_headframe,ore_cart_rails,elder_oak,alpine_hut,cold_camp,ruined_tower,hamlet_cluster}` | 32²–96×64 | **GOOD-AND-SHIPPABLE** (10, all `accepted`) | **Sources are UNTRACKED (0/13).** Palette-conformed against the *retired* 384×688 base; Reviewer C mandated an in-place ×2 contrast check against the current 1024 composite |
| `RCP01/out/world/prop_charcoal_clamp` | 48×40 | **REJECTED-BY-PRIOR-REVIEW** | "reads as a usable cook/smelt station — implied interaction, L-17" |
| `RCP01/out/world/prop_deer_group` | 40×32 | **REJECTED-BY-PRIOR-REVIEW** | "unidentifiable at x2" |
| `WORLD_REWARD_DEPTH_01/world/out/world/landmark_{ferry_crossing,old_watch,standing_stones,stone_bridge}` | 64×40–64×80 | **SALVAGEABLE-WITH-WORK** | Tracked (12/12). Host tiles retired; need re-conform + placement |
| `WORLD_REWARD_DEPTH_01/world/out/env/prop_{crag,dune,reedbed_strip,ridge_strip,sea_stack,treeline_strip,treeline_strip_v}` | 48×40–96×40 | **SALVAGEABLE-WITH-WORK** | Tracked. Terrain-belt strips |
| `WORLD_REWARD_DEPTH_01/world/out/world/atlas_{east,south,southeast}_384x688` | 384×688 | **OBSOLETE** | Inventory §5 **F**: retired base |
| `PIXELLAB_PROOF_02/out/environment/obj_{oak_tree_96,palisade_96x64,boulder_48,shrub_48}` | 48²–96² | **SALVAGEABLE-WITH-WORK** | Untracked; predates the current env style |
| `PLAYABLE_POLISH_01/out/props/seam_*` (15 variants) | 96² | **OBSOLETE** | Selection rounds for the three shipped `prop_*_seam` plates |
| `WORLD_MAP_POLISH_01/03`, `WORLD_MAP_EXPANSION_REFINEMENT_02` `out/env`, `out/world` | various | **OBSOLETE / REJECTED** | Raw and `_src`/`_edit` intermediates for shipped overlays; inventory §5 lists WMP03 `strip_east`/`corner_ne`/`corner_se` and WMP01 v1 creatures + fire v1 as **F/G** |

### 4.9 Dragons

The flying dragon is **REJECTED-BY-PRIOR-REVIEW** (inventory §5 **G**: "the aurora
and flying-dragon rejects"). What survived and **already ships** is
`overlay_skydragon` (from `WORLD_MAP_POLISH_03/out/env/creature_skydragon_still_72x32`),
placed in `atlas_layout.json` alongside `overlay_nessie`, `overlay_whale`,
`overlay_yeti2`, `overlay_bear2`, `overlay_stag`, `overlay_ship`, `overlay_volcano`.
**There is no unused dragon worth integrating.**

### 4.10 Location vignettes and profession / gathering scenes

| Asset | Native | Class | Note |
|---|---|---|---|
| `PIXELLAB_STABILIZATION_01/out/location/{havens_rest,whispering_woods,stonefall_mine,frostmere,forgotten_hollow}_vignette_512x384` | 512×384 | **GOOD-AND-SHIPPABLE** | Tracked. The shipped 384×176 banners are the `VIGNETTE_CROP {x:56, y:132}` window of these. **Any other 384×176 window is an A-2 recrop, not authoring** — `x` may range 0–128, `y` 0–208. UI plan §4 names this "Batch I's entire content." |
| `PIXELLAB_STABILIZATION_01/out/location/tavern_interior_GROUNDING_TEST.png`, `PIXELLAB_PROOF_03/out/location/tavern_interior_vignette_512x384` | 512×384 | **REJECTED-BY-PRIOR-REVIEW** (deferred, §4 H) | Right register, **MAJOR lighting defect**, and no tavern canon exists. A rest/inn design question first. |
| `PRESENTATION_WORLD_REWARD_FEEL_01/out/craft/{cook,cook2,smith2,smith3,smith4}_f0-8` | 88² | **SALVAGEABLE-WITH-WORK** | 45 frames of crafting-in-progress. The five shipped `activity_*` ambient loops came from this family; these are the unselected alternates. Tracked. |
| `ACTIVITY_FEEL_01/activity_loops/{forage,mine,mine2}_f0-8` | 88² | **OBSOLETE / REJECTED** | `mine2` loop is inventory §5 **G**; the rest are the selection round for shipped `activity_*` |
| `PIXELLAB_PROOF_03/out/world/region_map_384x640` | 384×640 | **OBSOLETE** | Superseded by the shipped `region_map.png` |

---

## 5. THE MENU

**Prioritized by (visible payoff ÷ effort), honest about verdicts.** Effort is
in the units this project actually spends: **Dart edits**, **`package-art.js`
emits**, **gitignore exceptions**, **PixelLab generations**, and — the real
currency per the UI plan — **blind review rounds**.

Where an item is a Dart-only integration, no generations and no blind round are
needed, because no new pixel is authored.

### Tier 1 — Zero generations, zero new files, already in the bundle (do these first)

| # | Asset | What it is | Where it goes | Effort |
|---:|---|---|---|---|
| 1 | `assets/art/v1/location/alt_{havens_rest,whispering_woods,stonefall_mine,frostmere,forgotten_hollow}.png` (5 × 384×176) | Accepted alternate framings of the five locations; today only the atlas inspector and travel card use them | **DIR-A N-2** — a scrimmed 132-px top-anchored backdrop band behind 7 pictureless tabs (Skills, Character, Inventory, Craft, Step Tracker, Goal Board, Field Notes) | 1 new widget (`screen_backdrop.dart`) + 7 call sites. **The largest identity gain in the audit.** |
| 2 | `assets/art/v1/work/bg_{cooking,smithing,woodworking,foraging,mining,woodcutting}.png` (6 × 384×176) | Six work backdrops; `AmbientAssets.workBackdropFor` already resolves them; consumed on exactly **one** surface (`location_stage.dart:147`) | **DIR-A N-6** — Skill Detail, keyed by skill. Five trade pages become five different places | ≈4 lines once #1 exists |
| 3 | `assets/art/v1/combat/*_idle_f0.png` (10 creatures) | Idle first-frames of every creature in the game | **DIR-A N-3** — Field Notes / `bestiary_screen.dart`. 262 combat files exist; the one screen about creatures shows **zero** | ≈15 lines. Must gate on `known` or it spoils discovery |
| 4 | `assets/art/v1/env/prop_{boulders,dead_tree,hedgerow,lone_oak,pine_clump,snowdrift}.png` | Six orphaned static props, 32×40–48×56, shipped and past `--check`, referenced by nothing | `atlas_layout.json` placements — same mechanism `prop_cairn` already uses | 6 JSON entries + a ×2 contrast check. Needs a world/atlas placement decision |
| 5 | `assets/art/v1/env/overlay_forge_smoke_f0-5.png` (32×48 ×6) | A 6-frame animated smoke plume, orphaned | `atlas_layout.json` — Haven's Rest forge or Stonefall. The only unused *animated* overlay | 1 JSON entry |
| 6 | `assets/art/v1/item/*.png` (59 icons) | Already shipped | **DIR-A N-5** — Inventory hero plate: equipped loadout as three 48-px icons instead of a one-line summary | P-8 + 4 call sites |
| 7 | `assets/art/v1/work/station_{forge,cookfire,woodbench}.png` (96²) | Three craft stations, used on the node surface only | Craft screen hero plate / craft-at-rest — UI plan §4 calls the work family "Batch G's entire first pass" for **zero** generations | ≈10 lines |

### Tier 2 — Zero generations, source on disk, needs a packaging step

| # | Asset | What it is | Where it goes | Effort |
|---:|---|---|---|---|
| 8 | `PIXELLAB_STABILIZATION_01/out/location/*_vignette_512x384.png` (5) | The full scenes the shipped 384×176 banners are cropped from. **Tracked.** | Alternate 384×176 crop windows (A-2 recrop, `x` 0–128, `y` 0–208) → Batch I restrained backplates, or a taller presentation surface | `package-art.js` emit + pubspec lines. **0 generations.** No new authoring — recrop only |
| 9 | `RCP01/out/fauna/fauna_hare_loop_f0-6` (7 × 32²) | Accepted ear-twitch / head-turn loop | Ambient stage companion at Haven's Rest, upgrading the shipped still to a living animal | Emit + `AmbientAssets` slot that accepts a 32-px canvas. **Design gate: is an animated companion past "quiet life"?** |
| 10 | `RCP01/out/fauna/fauna_songbird_loop_f0-6` (7 × 32²) | Accepted | Whispering Woods, same slot | As #9 |
| 11 | `RCP01/out/fauna/fauna_crow_loop_f0-6` (7 × 32²) | Accepted | Forgotten Hollow, same slot | As #9 |
| 12 | `RCP01/out/fauna/fauna_butterfly_loop_f0-4` (5 × 24²) | Accepted flutter | Haven's Rest or Woods | As #9 |
| 13 | `RCP01/out/fauna/fauna_butterfly_16.png` | Accepted **stage-scale** still — the same 16-px format as the four that ship, and no region claimed it | A second Haven's Rest companion, or Stonefall (currently empty because `fauna_bat_16` failed) | **Lowest-effort art addition in this document**: one manifest line. 0 generations |
| 14 | `RCP01/out/fauna/fauna_{hare,songbird,crow,ptarmigan,butterfly,bat}_32.png` (6) | Accepted "concept scale" stills | Field Notes creature cards, or any surface bigger than the stage slot | Emit + a consumer |
| 15 | `RCP01/out/world/prop_{plank_bridge,waystone,ruin_corner,mine_headframe,ore_cart_rails,elder_oak,alpine_hut,cold_camp,ruined_tower,hamlet_cluster}` (10) | Ten accepted atlas props: a bridge, a road marker, a ruin, a headframe, an ore cart, an elder oak, an alpine hut, a cold camp, a tower, a hamlet | Atlas **layout-placed layers, never atlas-image edits** (A-4/M-15 protected-interior guard) | **Sources are UNTRACKED — `.gitignore` exception + explicit `git add` first (M-08).** Then Reviewer C's mandated in-place ×2 contrast check against the current 1024 composite. Atlas work was frozen by owner order; **needs owner unfreeze** |
| 16 | `WORLD_REWARD_DEPTH_01/world/out/world/landmark_{ferry_crossing,old_watch,standing_stones,stone_bridge}` (4) | Named world landmarks, 64×40–64×80. **Tracked.** | Atlas landmark layer — `atlas_assets.dart` already documents `world/landmark_<slug>.png` as a supported key | Re-conform to the 1024 composite + placement. Same atlas freeze as #15 |
| 17 | `WORLD_REWARD_DEPTH_01/world/out/env/prop_{crag,sea_stack,reedbed_strip,ridge_strip,treeline_strip,treeline_strip_v,dune}` (7) | Terrain belt strips, 48×40–96×40. **Tracked.** | Atlas terrain belts (the WAR01 stamp-belt mechanism) | As #16 |
| 18 | `PRESENTATION_WORLD_REWARD_FEEL_01/out/craft/{cook,cook2,smith2,smith3,smith4}_f0-8` (45 × 88²) | Unselected alternates from the round that produced the five shipped `activity_*` loops. **Tracked.** | A second craft loop per trade, so repeat crafting is not one identical animation | Emit + rotation slot. **Needs a blind ×2 read** — these lost their selection round, so they are alternates, not rejects |
| 19 | `PLAYABLE_EXPERIENCE_REFINEMENT_01/out/stage/{mine_masonry_s41,mine_masonry_s97,mine_rock_s7,woods_open_s7,woods_stump_s41,woods_stump_s97}` (6 × 384×176) | The best masonry and woodland stage plates in the repo. **Tracked.** Rejected for *placement*, not craft | Batch C-3 surface-grain reference; crop source for the mining trade band if Batch B-3 fails twice | 0 generations as reference. As shipped art, needs a placement decision |
| 20 | `PIXELLAB_STABILIZATION_01/out/icons_full/icon_canvas_backpack_48.png` | An accepted 48² backpack icon. **Tracked.** | Nothing yet — no `item.canvas_backpack` exists | **HOLD.** A capacity item contradicts the no-capacity stance (Q-UI-1). Listed so a future session stops rediscovering it |

### Tier 3 — Content-gated: real art, blocked on a design decision

| # | Asset | What it is | Blocker |
|---:|---|---|---|
| 21 | `RCP01/out/enemies/weaver_idle_f0-6` (7 × 48²) | Accepted Hollow Weaver idle. **Tracked.** | Both attacks and defeat were withheld after two rounds — **it cannot fight**. Its silk role already went to the Silkstrand Thicket. Viable only as a **non-combat presence** in the Hollow, if VAWO01 wants one |
| 22 | `RCP01/out/fauna/fauna_bat_loop_f0-4` (5 × 32²) | Accepted wing-flap loop | The 16-px bat still failed ("moth at x2"); the 32-px loop passed separately. Stonefall has no companion. Needs a ×2 read at the intended size before use |
| 23 | `trav_zip/…/traveler_herb_gather_pro/south` (16 f, 88²) | The longest single Traveler sequence in the repo, never staged | **Untracked.** Never went through §8 review. Needs a gitignore exception + a blind round |
| 24 | `trav_zip/…/traveler_gather/{north,south,east,west}` (5 f each) | Four-direction gather | **Untracked.** No direction-aware staging exists. Needs a consumer first |
| 25 | `trav_zip/…/traveler_walk/{7 non-west directions}` (42 f) | The production Traveler's remaining walk directions | **Untracked.** `east` loses the vest on f0–f1. Only worth it if route-line animation appears |
| 26 | `PIXELLAB_PROOF_02/out/character/second_*_64.png` (9) | A second character rotation + portrait | The asset FAILED but the **style transfer PASSED**. The `create_character` + `style_character_id` recipe is the real deliverable — for an NPC cast, if one is designed |
| 27 | `PLAYABLE_EXPANSION_01/items/withheld/node_tin_seam_96.png` | Withheld node plate: gains the ore cue, trades "cookie" for "tile" | The README names the fix precisely: **one** pixen roll for an irregular outcrop with c1's seam treatment. **1 generation**, highest-confidence single spend in this report |

### Do NOT integrate — prior blind review refused these

`weaver_attack`/`attack2`/`defeat`, `crawler_defeat`, `bat_idle`/`attack`/`defeat`,
`fauna_bat_16`, `bear_attack` r1, `ram_hit`, `lynx prowl` · `prop_deer_group`,
`prop_charcoal_clamp` (L-17 implied interaction) · `icon_granite_chitin_48` (4
rounds), `icon_reinforced_bronze_pickaxe_48` (3 rounds), `icon_pine_plank_48` ·
the entire `SKILL_ICONS_OD04` round (**QA VERDICT: FAIL**) · every `px_*`
Traveler alternate, `traveler_stretch_side`, `traveler_pick_inspect_alt` · all of
`PIXELLAB_PROOF_01` · tavern interior (MAJOR lighting defect, no tavern canon) ·
PROOF_02 env tilesets and picking-up gather · AF01 wave loop and `mine2` ·
the aurora and flying-dragon rejects · retired 384×688 atlas tiles ·
everything under any `rejected/`.

---

## 6. Findings for the milestone

1. **The best available art is already in the player's bundle.** Menu items 1–7
   cost zero generations and zero new files. Four of them (N-2, N-3, N-5, N-6)
   were specified in `UI_MATERIAL_DIRECTION_01.md` §4 and verified this session as
   **not yet landed**. N-7 shipped in PCE01; the rest did not.

2. **Twelve shipped files are downloaded by every player and displayed to none.**
   Six `env/prop_*` and `overlay_forge_smoke_f0-5`. `prop_cairn` proves the
   placement mechanism works. This is the cleanest defect in the audit.

3. **Fauna is the richest unused *art* seam: 31 accepted animation frames plus 7
   accepted stills, fully tracked, not in the build.** The blocker is a design
   question ("is an animated companion past quiet life?") and a 16-vs-32-px stage
   slot — not craft, and not money.

4. **The ten RCP01 atlas props are accepted and UNTRACKED (0/13 files).** Using
   them requires a `.gitignore` exception and an **explicitly staged** `git add`
   (M-08), plus the atlas freeze being lifted. Flagging rather than acting.

5. **No UI frame, panel, banner, border, ornament or seamless tile exists.**
   Batch A authors a material class from nothing. No inventory search changes this.

6. **A large share of "unused" art is refused art.** Of the notable unshipped
   assets, roughly half carry a written blind-QA rejection. The audit's value is
   as much in the 30+ assets it takes *off* the table as in the 27 it puts on.

7. **`PIXELLAB_ASSET_INVENTORY.md` is accurate and should be updated, not
   replaced,** when VAWO01 closes — plus the §12 correction striking the stale
   OD-03 row from `UI_MATERIAL_DIRECTION_01.md` §5 (DIR-A's document to change).

**Nothing in this report is a decision.** Items 15–17 need the atlas freeze
lifted; 9–14 and 21–22 need an ambient-density design call; 20 needs Q-UI-1.
Those belong to their owners.
