# GOV-04 — PixelLab / asset-pipeline production cheat-sheet (EPO03)

Reference only; nothing here is a design decision. Every figure below is
either a live `get_balance` checkpoint, a cost line from a FMPO02 family
ledger (`GAME_BIBLE/ART/exploration/FMPO02/ledger/*.md`), or read from the
current tree at 59c4723. Sources: `MILESTONES/evidence/FMPO02/wave0/
GOV-03_asset_pipeline_inventory.md`, `wave2/PRODUCTION_RULES.md`,
`FMPO02/GENERATION_LEDGER.md` (reconciliation), `MISTAKES.md` M-17/M-18.

**Balance at FMPO02 closeout (2026-09-02): 7,989 remaining of 10,000, Tier 3,
resets 2026-10-01.** Call `get_balance` at open and close; never plan from a
remembered figure. While more than one agent holds the account, a family's
spend is the **sum of its own cost lines**, never a balance delta (M-17).

---

## 1. PixelLab tool facts — measured in FMPO02

| Tool | Canvas / limits (tool contract) | Measured cost (FMPO02 ledger rows) | Notes |
|---|---|---|---|
| `create_image_pixen` | 16–768 per side, multiple of 4, area ≤512²; below 32 must be square (16/20/24/28) | **1** at every size used: 48² icons, 16²–96×64 world life, 384×176 gather backdrops, 64²/128² UI tiles, 384×96 bands | Default for stills; 3–4 candidates, pick one. `no_background=true` for sprites. Min side 16 — a 12 px flame is impossible. |
| `create_image_pixflux` | img2img / forced palette / isometric | **1** (384×176 backdrops, incl. `img2img` at strength 60/150) | img2img barely moved dressed-stone walls (GATHER: 8 rolls, 0 accepted). |
| `create_image_pro` | 512² square / 688×384 16:9; returns 64 candidates ≤42 px, 16 ≤85, 4 ≤170, 1 above; up to 4 labelled `reference_images` (url preferred) | **40** at 384×176 (GATHER: 3 rolls, 3 accepted after 31 pixflux rejects) | Cost per call, not per candidate. Use where the brief says so. |
| `edit_image_pixen` | single frame | **1** (56², 96², 128×64) | Elite recolours, breath still. Try before any 20–40 edit. |
| `edit_image` (text mode) | inputs ≤512²; frames per call: ≤64 px 16, ≤80 px 9, ≤128 px 4, larger 1 | **≈20** per call at 80×64 × 8 frames (steel-head recolours: 6 strips ≈120) | Billed by the whole frame grid — batch a strip into one call. |
| `edit_image` (reference mode) | as above, **one fewer** frame per call (80 px → 8) | **≈20** per call (coat re-dress ×3 = 60; craft loops 7 f at 74×64 / 46×64 ×6 ≈120) | `reference_image_url` + short `description`; keeps pose, swaps garment. |
| `inpaint_image` | image 32²–**512²**; rectangle mask or mask PNG (white = regenerate); `crop_to_mask` default true | **20** at ≤192×128 / 140×150 / 140×200 / 160×300; **25** at 196×298 … 300×298; **40** at 348×346 / 356×304 / 372×300 | Billed by *image* size, not mask size — crop tight. Omitting `no_background` on a padded crop returned a 68 % transparent cut-out (TERRAIN S2 r1). |
| `animate_image` | frame ≤256²; w×h×frames ≤524,288; `frame_count` even 4–16; result = input + N frames | **1** at 56²×8 f, 76²×6 f, 96×64×9, 128×64×9, 16²×5; **2** at 96²×8 f | In-place motion only (collapse/defeat reads weak). Ledger "×9" = 8 generated + the input frame. |
| `animate_character` (v3 template) | character canvas 88–104² | **1** per track (EQUIPMENT: 36 combat + 8 tool + 11 bare tracks) | Template animations can drop held props — run the weapon-presence check. |
| `create_character_state` | source canvas or `override_width/height` (multiple of 4, ≤256); charge resolved at generation, **can exceed the 20 reserved** | **≈44** at 80×64 (reconciled; the lead's ~120 was a shared-account delta — M-17) | Keeps identity across 4/8 rotations. Leave 40 headroom near plan end. |
| `create_map_object` | 32–400 px; style-match (inpainting) mode ≤192²; `background_image` is **base64 only** | **≈32** (40×36, 64×48 with a background crop) | The only way FMPO02 got plinth-free map props (fairy castle, storm house). Background must be a tiny crop (≤5 KB inline). |

### Image hosting and chaining

- **Inline base64 truncates above ≈5 KB.** Map-scale inpaints cannot go through
  MCP inline; sprite-scale can, but prefer URLs everywhere.
- **Working route:** commit the crop/source under
  `GAME_BIBLE/ART/exploration/EPO03/src/<family>/`, push, then use
  `https://raw.githubusercontent.com/thcwtnnp5s-del/project-stride/<commit-sha>/<repo path>`.
  The **commit-SHA form propagates immediately**; the branch-name form can 404
  for minutes. A push is mandatory (TERRAIN pushed `f71aa30`, `2bb50f0` mid-round
  for one crop each).
- **PixelLab's own URLs chain directly:** `get_image` download URLs, character
  rotation/animation URLs → `image_url`, `image_urls`, `first_frame_url`,
  `reference_image_url`, `style_image_url`, `reference_images[].url`.
  Exception: `create_map_object.background_image` takes base64 only.
- `cloudflared`/tunnels are blocked by the auto-mode classifier; do not try.
- Download every kept candidate with `EPO03/tools/fetch.js <url> <out>`;
  never accept from a thumbnail — sheet at ×2–×4 on `#14120F` and Read it.

### `.gitignore` block for EPO03 (add before the first commit)

`GAME_BIBLE/ART/exploration/**` is ignored wholesale; `**/` and `**/*.md`
are already un-ignored. `git add` of an ignored path aborts the whole add
silently — check `git status --short | grep -v '^??'` before committing.

```gitignore
# Executive Production Overhaul 03 — deterministic tools, job/crop sources
# (PixelLab reads them from raw.githubusercontent.com), and the selected out/
# tree package-art.js reads. raw/ candidate dumps and QA plates stay local.
!GAME_BIBLE/ART/exploration/EPO03/tools/**
!GAME_BIBLE/ART/exploration/EPO03/src/**
!GAME_BIBLE/ART/exploration/EPO03/out/**
!GAME_BIBLE/ART/exploration/EPO03/review/**
!GAME_BIBLE/ART/exploration/EPO03/rejected/**
```

`raw/` needs no line (still caught by the wholesale rule); VAWO01's explicit
`raw/**` re-ignore is belt-and-braces only. Stage explicit paths (G-8).

---

## 2. Packaging — exploration `out/` → `assets/art/v1`

**Writer:** `Scripts/art/package-art.js` (only writer of `assets/art/v1/` and
of the generated `lib/ui/icons/sprite_footprints.dart`). Reads **only** from
`GAME_BIBLE/ART/exploration/<ROUND>/out/...` via `Scripts/art/png.js`
(`load/loadAny/save/crop/blit/scale/fill/bounds/footprint`, RGBA8, no npm).

```sh
node Scripts/art/package-art.js            # writes assets/art/v1 + sprite_footprints.dart
node Scripts/art/package-art.js --check    # CI: writes nothing; reports missing:/stale:/unexpected:, exit 1
node Scripts/art/check-art-palette.js      # NOT in CI — run by hand (also --self-test)
node Scripts/art/check-tile-seam.js        # NOT in CI — every declared strip; --measure <png> --period <n> [--axis h|v]
node Scripts/art/nav-active-variant.js --check   # CI
node Scripts/art/measure-ambient-extents.js      # read-only bounds report
```

`--check` compares every `emit()` against disk and sweeps for orphans, so
**one emitter owns one path** — a replacement moves the existing emitter's
*source* (the `fmpo02ItemPath` / `fmpo02GatherPath` override pattern) rather
than adding a second `emit`, or CI reports the correct file as `stale:`.
`pubspec.yaml` lists `item/`, `node/`, `sprite/`… **per file** and
`ambient/`, `combat/`, `env/`… **per directory** — a new item icon or node
plate needs a pubspec line; a new env/combat/ambient frame does not.

### Manifest / table conventions used by the FMPO02 block (copy these)

| Family | Source path under `FMPO02/out/` | Contract | Emits |
|---|---|---|---|
| Items | `items/icon_<id>_48.png` | 48×48 asserted; re-authored ids listed in `fmpo02ItemPath` | `item/<id>.png` + `PixelIcons._itemIcons` row + pubspec line |
| Gather backdrops / props | `gather/bg_<region>_<skill>.png` (384×176), `gather/prop_<subject>.png` (48²) | override by basename in `fmpo02GatherPath` | `work/bg_*.png`, `work/prop_*.png` (props get footprints) |
| Enemies | `enemies/<track>_f<n>.png`, `enemies/habitat_<biome>.png` | inline `[id, frames, edge]` table; habitats 192×76 opaque, no footprint | `combat/<id>_f<n>.png`; f0 → `combatFootprints['combat_<id>']` |
| World life (env overlays/props) | `worldlife/manifest.json` → `assets[]: {name, kind: prop|overlay, canvas:"WxH", frames, frameMillis, playLoops, intervalMillis, travel, atlas{x,y}, world{x,y}}` | every canvas asserted from the manifest | `env/<name>_f<n>.png` / `env/<name>.png`; **placement is NOT done here** — `atlas_layout.json` is hand-edited |
| Rewards | `reward/<id>.png` | `[id, w, h]` (24², 96×48) | `reward/<id>.png` + `RewardArt` |
| Combat stage | `combat/backdrop_<biome>_128.png` | 192×128 | new ids beside the 96-tall set |
| Equipment strips | `equip/tracks/<id>_f<n>.png` + `PREP_SUMMARY.json` | `fmpoStrip(id, frames, width, mirror, dest, footprints)`: width×64, foot row 62; `toneBronze` remap on `/bronze/` ids; `despeckle(frame, 4)` on named strips; ghost-gear assert | `combat/…` or `ambient/…`; f0 footprint |
| Portrait busts | `portrait/traveler_<body>.png` | 64² | `portrait/traveler_<body>.png` |
| Atlas regions | `atlas/manifest.json` → `regions[]: {id, x, y, w, h, salt, status}` + `<id>.png` + `<id>_mask.png` (24 px alpha ramp) | anything but `status: "accepted"` throws; dither SELECT by shared hash | composed into `world/atlas_base.png` (1024², protected-interior + landmark-golden guards, M-15) |
| UI chrome | `out/ui/**` via `FMPO02/tools/ui-package.js` | `.json` sidecar per PNG: `asset, destination, kind, corner, band, period, scale, tiles, master, canvas, guards{teal,semi,over,colours,maxHex,maxL,verdict}` | **hand-copied** into `assets/ui/v1/<class>/` (band/, button/, combat/, frame/, header/, nav/, surface/) + provenance row in `assets/ui/v1/README.md`; packaging never touches this tree |

UI kinds and their geometry: nine-patch (`frame/chassis_64` corner 16 band 8
period 8 scale 2; `button/btn_plate` corner 4 band 0; `btn_compact` corner 5
band 2) — `PanelSkin` insets by **band**, never corner; longitudinal tiles
(`header/header_shelf` 8×6, `nav/nav_welt` 8×4, period 8, horizontal only,
last tile clipped); interior surface tiles (`surface/grain_*` 32², period 32,
both axes, ≤5-ink ramp); picture bands (`band/band_*` 384×48, drawn once at
×1, clipped, never tiled). Wave-2 UI rule of thumb (ART-13): a surface tile
is a grain, ≤6 L\* between its inks — anything with two inks 21 L\* apart is a
pattern and was rejected.

### Guards

| Guard | Rule | Threshold |
|---|---|---|
| `check-art-palette.js` **teal** | no opaque pixel near reserved `#58D6C0` anywhere in `assets/art/v1` + `assets/ui/v1` | Chebyshev radius **10**; one allowlisted file `glyph_steps.png` |
| … **alpha** | no pixel with `0 < a < 255` | zero tolerance (integer scaling stays exact) |
| … **ceiling** | no opaque pixel in `assets/ui/v1/{frame,surface,ornament}` brighter than `textMuted #7C7263` | WCAG relative luminance, exact |
| … **substrate** | no `assets/ui/v1/frame` pixel in `surfaceCard #201C17` or `surfaceGround #14120F` | exact match |
| `check-tile-seam.js` **wrap / period** | last column vs first column of each declared strip; declared period is the real one; reads the frame sheet's sidecar `corner` | period **8**; wrap tolerance 2.5× interior column variation; flat floor 1.5, flat ceiling 6 |
| `despeckle(frame, 4)` (packager) | drops every 8-connected opaque component < 4 px, on named strips only | lone chips from keyed effects / edits (M-18) |
| ghost-gear guard `attachedPixelCount` (packager) | every opaque pixel of a combat/equipment frame must be one 8-connected component (largest-mass, not lowest-pixel — M-18) | packaging throws otherwise |
| protected interior + landmark goldens (packager) | atlas repairs may not repaint the 512² core beyond a 20 px rim; goldens in `WORLD_ATLAS_REMASTER_01/goldens` must match | byte diff (M-15) |
| `FMPO02/tools/keeplargest.js <thr> in out`, `despeckle.js in out <kind> [passes] [--rect x0,y0,x1,y1]`, `checkteal.js`, `checkframes.js` | pre-packaging cleanups | deterministic only (A-2) |

Exit codes for the guards: 0 satisfied, 1 policy violation
(`STRIDE_GUARD[...]`), 2 infrastructure fault (`STRIDE_INFRA[...]`).

**EBUSY hazard.** On this Windows working copy, two agents running
`package-art.js` (or one agent packaging while another's editor/`flutter
test` holds a file in `assets/art/v1` or `lib/ui/icons/sprite_footprints.dart`)
fails with `EBUSY: resource busy or locked` mid-write, leaving a partial
tree that `--check` then reports as stale/missing. The EPO03 brief's rule:
on EBUSY **wait and rerun**; never edit `package-art.js` outside your named
block; one packaging run at a time per checkout. A `git stash` chain that
times out stays stashed — check `git stash list`.

---

## 3. Atlas overlay schema and what the renderer can do

`assets/content/v1/atlas/atlas_layout.json` — `schemaVersion` **5**,
`scale` **6** (one atlas px = 6 world px), `base.tiles` one 1024² tile,
`landmarks` **23**, `props` **6**, `overlays` **40**. Model:
`lib/runtime/atlas_layout.dart` (`AtlasOverlay`, `AtlasProp`,
`AtlasNamedLandmark`); renderer `lib/ui/screens/world/atlas/atlas_layers.dart`.

```jsonc
// overlay — x,y = sprite TOP-LEFT in world px (atlas px × 6)
{"asset":"env/overlay_storm_lightning","x":1164,"y":4908,"width":48,"height":64,
 "frames":8,"frameMillis":110,"playLoops":1,"intervalMillis":13000,
 "drift":{"x":0,"y":0},"opacity":1}
// travelling overlay (v5)
{"asset":"env/overlay_redwyrm","x":4200,"y":1440,"width":96,"height":64,"frames":9,
 "frameMillis":400,"playLoops":2,"intervalMillis":22000,"drift":{"x":0,"y":0},
 "travel":{"x":22,"y":-4},"opacity":1}
// prop — x,y = ANCHOR position in world px; anchorX/Y sprite-local
{"asset":"env/prop_ice_tower","x":2808,"y":1062,"width":48,"height":80,"anchorX":24,"anchorY":79}
// landmark
{"id":"landmark.rimewatch","name":"Rimewatch","x":3834,"y":1776,"tier":"future",
 "marker":{"asset":"world/marker_landmark","width":20,"height":20,"anchorX":10,"anchorY":10}}
```

| Capability | Available? | How |
|---|---|---|
| Frame loop | **Yes** | `frames` × `frameMillis`; `frameIndexAt` = elapsed-in-play ÷ frameMillis mod frames |
| Per-overlay cadence (e.g. lightning every 13 s) | **Yes** | `intervalMillis` (v4) = quiet gap during which the sprite is **not built**; `playLoops` (v5) = plays per cycle; `cycleMillis = frames×frameMillis×playLoops + intervalMillis` |
| Continuous drift | **Yes** | `drift{x,y}` world px/s, wraps around the world span (birds 16,-3; snowdrift 6,0) |
| Straight-line journey | **Yes** | `travel{x,y}` world px/s from origin for the play duration, **resets at the gap**, never wraps; requires `intervalMillis`, excludes `drift` |
| Waypoint / patrol polyline | **No** | one vector per overlay; no path, no turn, no easing |
| Per-overlay scale | **No** | every layer draws at layout `scale` (6, integer); no scale field |
| Opacity | **Yes** | `opacity` 0–1 compositor multiplier (mist 0.4, smoke 0.8) |
| Layering / z | **Partial** | overlays paint in **JSON array order** inside their own layer; no z field. Stack (atlas_viewport.dart:427–438): Base → Route → Landmark (props, then named landmarks, then location landmarks) → **Overlay** → Marker. Overlays therefore always sit over props and landmarks and under place markers/labels |
| Mirroring / rotation / tint | **No** | author a second asset |
| Overview zoom | props/landmarks hidden past `AtlasZoom.overviewBelow`; overlays are not | |
| Motion off | one ticker for the whole layer, obeys `TickerMode` (background, reduced motion, tests freeze `_elapsed`) | |

Schema gates: `intervalMillis` needs v4, `travel`/`playLoops` need v5 —
a dropped field is a thrown `AtlasLayoutException`, not a silent fallback.
Positions are floored to whole world px. `atlas_layout.json` is hand-edited;
packaging only makes a sprite available.

### Current `assets/art/v1/env/` inventory (frames × native size)

Overlays: bear2 19×26×28 · bear3 9×28² · birds 6×24² · caravan 1×20×19 ·
chimney_smoke2 7×16² · cloud_shadow 1×96×48 (unplaced) · cloud_wisp 1×96×48
(unplaced) · crows 7×24² · deer2 5×16² · fairy_motes 4×32² · fire3 10×44×52 ·
fishing_boat 5×24² · flock 13×64×40 · forest_mist 6×96×48 · forge_smoke
6×32×48 (unplaced) · ice_beacon 7×48×80 · lantern 5×16² · nessie 17×44×33 ·
**redwyrm 9×96×64 · redwyrm_breath 8×128×64** · ripple_coast 8×40×48 ·
ripple_delta 8×36×48 · ship 1×15×20 · skydragon 28×68×31 · smoke 6×16×14 ·
snow_flurry 8×64² · snowdrift 9×32² · stag 20×28×22 · **storm_lightning
8×48×64** · **stormdrake 9×96×56 · stormdrake_breath 8×128×56** ·
tree_rustle_a 9×48² · tree_rustle_b 9×44² · volcano 17×64² · wagon 5×14×13 ·
whale 9×38×41 · wolfpair 9×56×44 · yeti2 8×44×34 · yeti3 5×16×17.

Props (single frame): black_gable 56×52 · boulders 48×40 · cairn 32×40 ·
dead_tree 40×48 · **fairy_castle 31×39** · hedgerow 48×32 · **ice_tower 48×80**
· lanterngard 72×56 · lone_oak 48×48 · pine_clump 48×56 · rimespire 48×72 ·
snowdrift 48×32 · **storm_house 25×21**. Placed props (6): rimespire,
lanterngard, black_gable, fairy_castle, storm_house, ice_tower. The dragons,
their breath, the fairy motes (over the castle at 1752,2544), the lightning
(over the storm house at 1164,4908) and the ice beacon (over the ice tower at
2664,588) are all FMPO02 world-life emits from `out/worldlife/manifest.json`.

---

## 4. Traveler sprite-strip conventions

Resolver: `lib/ui/icons/traveler_art.dart` (`TravelerArt`). **Two axes:**
body class × held-item class, coarse by tier, never per item.

- Body classes: `base` | `armor.plate` | `armor.jerkin` | `armor.coat`
  (`variantOfItem`; unmapped armour → base).
- Held classes: `weapon.unarmed` (empty slot is a *value*) | `weapon.steel`
  (training_sword and any unmapped weapon) | `weapon.bronze`; tools
  `tool.{axe,pick}.{steel,bronze}` (only counted when they match the skill).
- Fallthrough, same on every axis: exact pair → body with the other armed
  class (`_nearestArmed`) → base body with held class → base
  (`CombatAssets.traveler`). Gather: `skill|body|held` → `skill|body|steel` →
  (armoured only) `skill|body|bronze` → `skill|base|held`. Foraging is
  `skill.foraging|body` (no tool). Craft: `skill.{smithing,cooking}|armor.<body>`.
- Frame size: combat strips **80×64**, foot row **62** (one window per strip,
  never per frame). Ambient widths: woodcut/mine 80, forage 64, smith 74,
  cook 46, idle_breathe / look_around / walk_west 64 — all ×64 tall.
- Naming: `combat/traveler_<body>_<held>_<track>_f<n>.png` with tracks
  idle 8 / attack 8 / hit 6 / stagger 8 / brace 6;
  `ambient/traveler_<body>_<tool><skill>_f<n>.png` (e.g.
  `traveler_plate_bronzepick_mine`, `traveler_coat_steelaxe_woodcut`),
  `traveler_<body>_forage` (9 f, **mirrored** at packaging), `_smith` (7),
  `_cook` (7), `_idle_breathe` (8), `_look_around` (7), `_walk_west` (6).
  Forage and craft loops are ping-ponged in code from the authored frames.
- Standing figures `sprite/traveler_south[_plate|_jerkin|_coat].png` 64²;
  busts `portrait/traveler_<body>.png` 64²; base walk `anim/traveler_walk_west_f0-5`
  64², feet row 62.

**What exists (`assets/art/v1`):**

| Body | Combat sets (idle/attack/hit/stagger/brace) | Ambient strips |
|---|---|---|
| base | steel = `traveler_combat_idle` 9 / `traveler_attack` 4 / `traveler_hit` 6 / `traveler_stagger` 9 (pre-PixelLab, no brace); `traveler_unarmed_*` 8/7/7/9 + `traveler_base_unarmed_brace` 6; `traveler_bronze_*` 9/7/5/9 + `traveler_base_bronze_brace` 6 | `base_bronzeaxe_woodcut`, `base_bronzepick_mine` (+ the older `activity_woodcut/mine/forage/smith/cook`, `gather`, 20+ base idles) |
| plate, jerkin, coat (each) | 3 held classes × 5 tracks = **15 strips** (8/8/6/8/6 f) | `bronzeaxe_woodcut`, `steelaxe_woodcut`, `bronzepick_mine`, `steelpick_mine`, `forage`, `smith`, `cook`, `idle_breathe`, `look_around`, `walk_west` = **10 strips** |

Totals: 47 FMPO02 combat sets (581 prepared frames in `out/equip/tracks/`),
32 FMPO02 ambient strips. Every f0 feeds `sprite_footprints.dart`
(regenerated by packaging; commit it). `equipment_projection_test.dart`
asserts body class of the resolved art equals the armour's class.

---

## 5. Evidence harnesses and the "device" render

All harnesses are `flutter test` files that are silent smoke tests unless
their env var is set, in which case they write PNGs. Every one renders the
real app at **393×852 logical px, devicePixelRatio 1.0** — the iPhone 15 Pro
point grid. There is **no Pro Max (430×932) render harness**; that profile
exists only as a layout probe in `test/fold_clearance_test.dart:62`. The 41
FMPO02 screens under `GAME_BIBLE/ART/exploration/FMPO02/review/device/` are
393×852 raw harness output, viewed ×2–×3 on contact sheets, not device
screenshots — the owner's iPhone remains the final authority (A-3).

| Var | Test | Writes |
|---|---|---|
| `SCREEN_EVIDENCE_DIR` | `test/screen_evidence_test.dart` | adventure, character, inventory, skills, craft_gear_open, v2_*/v3_*/gfcp_* screens (`review/device/*.png`) |
| `STAGE_EVIDENCE_DIR` | `test/stage_evidence_test.dart` | work-mode `LocationStage`: mine_copper, mine_tin, mine_hardened_locked, woods_oak, haven_meadow (`review/device/stage/`) |
| `COMBAT_EVIDENCE_DIR` | `test/combat_golden_test.dart` (goldens always run), `combat_gear_evidence_test.dart`, `craft_stage_evidence_test.dart`, `reward_art_evidence_test.dart` | wolf slash, guardian idle/heavy/struck, gear_* stages, craft stage, reward cards (`review/device/combat/`) |
| `BOARD_EVIDENCE_DIR` | `test/board_reward_layer_test.dart` | board before / open job / reward layer (`review/device/board/`) |

Exact command (Git Bash; Flutter is not on PATH — M-09 memory):

```sh
export JAVA_HOME="/c/Program Files/Eclipse Adoptium/jdk-17.0.20.8-hotspot"
export PATH="$JAVA_HOME/bin:/c/Users/jwspa/dev/flutter/bin:$PATH"
cd /c/Users/jwspa/Downloads/ProjectStride_ClaudeCode_Handoff_COMPLETE/ProjectStride
SCREEN_EVIDENCE_DIR="$PWD/GAME_BIBLE/ART/exploration/EPO03/review/device" \
  flutter test test/screen_evidence_test.dart
STAGE_EVIDENCE_DIR="$PWD/GAME_BIBLE/ART/exploration/EPO03/review/device/stage" \
  flutter test test/stage_evidence_test.dart
COMBAT_EVIDENCE_DIR="$PWD/GAME_BIBLE/ART/exploration/EPO03/review/device/combat" \
  flutter test test/combat_golden_test.dart test/combat_gear_evidence_test.dart \
  test/craft_stage_evidence_test.dart test/reward_art_evidence_test.dart
BOARD_EVIDENCE_DIR="$PWD/GAME_BIBLE/ART/exploration/EPO03/review/device/board" \
  flutter test test/board_reward_layer_test.dart
```

`screen_evidence_test.dart` equips only the starting loadout (FINAL-03
blocker): an armoured-loadout screen needs a new `testWidgets` there, not a
unit test over path strings. Goldens (`flutter test --update-goldens`) are
regenerated only after each diff is inspected at phone scale. Contact sheets:
`EPO03/tools/sheet.js <out> <scale> <cols> <bg> <frames...>`; atlas crops on
the composed master: `onatlas.js <out> <cx> <cy> <cw> <ch> <scale> <specs...>`.

---

## 6. Top hazards, ranked

1. **Cost accounting on a shared account** — record the tool's own cost line
   per job; a balance delta taken while other leads generate is the round's
   figure, not yours (M-17: ≈120 vs ≈44 drove a wrong cut).
2. **Second emitter / stale `--check`** — replacing shipped art means moving
   the existing emitter's source; a second `emit` for the same path fails CI
   on a correct file. Untracked `out/` sources (missing gitignore exception)
   make `--check` fail on a clean checkout.
3. **Mass, not extremes, defines the figure** — lowest/leftmost/brightest
   pixel heuristics delete the man and keep the chip (M-18); use
   largest-component + `despeckle(4)`, and the ghost-gear guard as written.
4. Base64 truncation above ≈5 KB silently corrupts an input — host on the
   pushed commit SHA. `create_map_object` backgrounds must be tiny crops.
5. `inpaint_image` without `no_background` on a padded crop returns a
   cut-out; cost is by image size, so crop the image, not just the mask.
6. Concurrent `package-art.js` on Windows → `EBUSY`; wait and rerun, one run
   at a time.
