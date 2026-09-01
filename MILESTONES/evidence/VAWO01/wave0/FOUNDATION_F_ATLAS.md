# FOUNDATION-F — World / Atlas Protection Audit (VAWO01, wave 0)

**Role:** World / Atlas Protection Auditor · **Mode:** read-and-report only
**Date:** 2026-09-01 · **Branch at audit:** `presentation-combat-evolution-01`
**Repo root:** `C:\Users\jwspa\Downloads\ProjectStride_ClaudeCode_Handoff_COMPLETE\ProjectStride`

All coordinates in this document are **1024² atlas pixels** unless stated
otherwise. World pixels = atlas px × 6 (`atlas_layout.json` `scale: 6`,
world 6144 × 6144). Location `hitRadius` 72 world px = 12 atlas px.

---

## 1 · History and the current accepted state

### 1.1 How the 1024² canvas was built

The atlas is **not** a painting; it is a deterministic composition performed by
`Scripts/art/package-art.js` from tracked PixelLab sources. Structure
(`package-art.js` ~L1484–1560):

| Ring | Source round | Placement |
|---|---|---|
| Outer ring (12 pieces) | `WORLD_MAP_EXPANSION_REFINEMENT_02/out/world/` | the 128 px frame: corners 128², N/S strips 384×128, E/W strips 128×384/512 |
| Inner ring (8 pieces) | `WORLD_MAP_POLISH_03/out/world/` + WMER02 replacements | offset +128; N strip 512×128 at (256,128), W/E strips 128×512 at (128,256)/(768,256), S strip 512×128 at (256,768), four 128² corners |
| **Master painting** | `PRESENTATION_WORLD_REWARD_FEEL_01` `whole_a_0.png`, **512 × 512** | blitted **byte-preserved at (256, 256)** |
| Static in-place patches | WMER02 | `northfix2_edit` (640,128) 128², `eaststriptop_edit` (768,256) 128×64, `corridor_edit` (256,483) 128×75, `southjoin_edit` (188,738) 256×60, `roadjoin_edit` (216,480) 104×72 |
| Dither crossfade | deterministic (A-2) | 11 px hash-swap bands on seams x/y ∈ {128, 256, 768, 896} |
| Repair layers | WACUI bridges, WAR01 inpaint adoptions, WAR01 remaster regions, despeckles, stamp belts | clipped by the A-4 guard |
| Ocean conform + shoal ramp | `ocean_unify.js`, `water_join.js` | runs **last**, globally |

Everything after the dither is a "repair layer" and is subject to the
protected-interior machinery in §3.

### 1.2 The milestone sequence

| Milestone | What it did | Outcome |
|---|---|---|
| `MILESTONES/WORLD_MAP_POLISH_01.md` | Western forest fire; restored the ambient overlay set the 512² replacement had silently dropped (cloud shadows, wisp, chimney/forge smoke, drifts) | Device: direction right, execution wrong — bear mascot-sized, yeti floated, water dragon read as a slug |
| `MILESTONES/WORLD_MAP_POLISH_03.md` | World 2.25× bigger: 512² master byte-preserved at (128,128) inside a **768²** base; 8 style-referenced ring pieces; layout **schema v5** (`playLoops`, `travel`); creature rework as *in-place scenes* | Device: right world, one more major pass; dragon flew backwards; west read as closed |
| `MILESTONES/WORLD_MAP_EXPANSION_REFINEMENT_02.md` | Grew to **1024²** (world 6144); master moved to (256,256); two rings; seam-corrected E/W strips; caravan pass in the west strip | Device: still reads as assembled |
| `MILESTONES/WORLD_ATLAS_COHERENCE_UI_01.md` | 12 cross-boundary `inpaint_image` **bridges** + global ocean conform; World tab becomes map-first (`Stack`, translucent panel) | **Caused the damage**: bridges blitted with no boundary |
| `MILESTONES/WORLD_ATLAS_RESTORE_01.md` | **The repair.** Measured **35.3 % of the master interior had drifted** — Frostmere basin erased under generic snowfield, both volcano watchtowers deleted, east coastline rewritten by a bridge reaching 128 px inside. Introduced the A-4 protected-interior snapshot + rim band + drift guard; retired `east_x768`; ocean conform moved last; four surgical re-authoring inpaints; World panel became gradient glass with a fold | `MISTAKES.md` **M-15**; `RULES.md` **A-4** |
| `MILESTONES/WORLD_ATLAS_REMASTER_01.md` | **Regional recomposition** rather than seam repair: 7 accepted regions (R1–R5, R3b, R3c), deterministic east-bay shoaling ramp + NW despeckle, a tracked `regions_manifest.json` with an accepted/withheld status gate, and a **landmark registry** of 15 goldens outside the core. 180 generations spent; balance 205 → **25** | ATLAS-H verdict "Yes — install"; 802/802 suite green |
| Remaster **Iteration 02** | Seven owner iPhone screenshots became the **device defect register** (24 + 2 defects); shipped 5 deterministic cleanups + 5 stamp belts, **0 generations**; wrote `POST_RESET_GENERATION_PLAN.md` for stage 2 | Still awaiting device acceptance |

### 1.3 Current accepted state (verified this audit)

- `node ./Scripts/art/package-art.js --check` → **`art packaging: 851 files up to date`**. Both guards pass; the atlas is byte-reproducible from tracked sources.
- Shipped atlas: `assets/art/v1/world/atlas_base.png`, **1024 × 1024**, 521,346 bytes.
- The atlas as shipped still carries the **stage-2** defect set (§7): the owner's own device verdict is "it still reads as assembled/patchwork". The stage-2 authored repaints were deliberately deferred to the **2026-09-16 PixelLab reset** with **25 generations** remaining.
- Three owner decisions are still open (`JOURNAL/OPEN_QUESTIONS.md` Q-13): lime-band identity, A-4 core exceptions, strand-golden re-extraction approvals.

---

## 2 · The protected-region registry — where the data lives

There are **two** protection mechanisms and **three** data sources.

### 2.1 Mechanism 1 — the A-4 protected interior (hard-coded)

Declared **in code**, not in data, at `Scripts/art/package-art.js:1602`:

```js
const PROT = { x0: 256, y0: 256, x1: 768, y1: 768, band: 20 };
const approved = base.clone();
// Depth inside the protected rect (0 = outside; 1 = rim pixel).
const protDepth = (x, y) => {
  if (x < PROT.x0 || x >= PROT.x1 || y < PROT.y0 || y >= PROT.y1) return 0;
  return Math.min(x - PROT.x0, y - PROT.y0, PROT.x1 - 1 - x, PROT.y1 - 1 - y) + 1;
};
// In the rim band a hash dither keeps repair pixels near the perimeter and
// approved pixels toward the core, so the clip line is never straight.
const keepRepair = (x, y, d) => d <= PROT.band && hash(x, y, 5) >= d / (PROT.band + 1);
```

Solving `protDepth > band`: the **hard-frozen core is x ∈ [276, 747] × y ∈ [276, 747]**
(472 × 472 = 222,784 px = **21.25 %** of the atlas). The 20 px ring
256–276 / 748–768 on each side is the **writable, hash-feathered rim band**.

`approved` is the snapshot taken *after* master + 5 static patches + dither
crossfade — "the 559669e state".

### 2.2 Mechanism 2 — the landmark registry (tracked JSON + goldens)

**Data:** `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/landmark_registry.json`
**Goldens:** `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/goldens/<id>.png` (15 PNGs)

| id | x range | y range | area | Feature |
|---|---|---|---|---|
| `frostmere_north_wall` | 400–560 | 256–276 | 3,200 | Frostmere cirque's north wall inside the rim band |
| `east_watchtower_flank` | 744–752 | 273–323 | 400 | East watchtower's flank crossing the rim |
| `volcano_east_cliff` | 752–824 | 260–470 | 15,120 | Volcano east cliff → coves → shallows |
| `roadjoin_corridor_west` | 216–276 | 480–558 | 4,680 | Road-join / corridor west end |
| `west_caravan_road` | 128–256 | 495–575 | 10,240 | West caravan road across the pass meadow |
| `caravan_corridor` | 199–245 | 506–532 | 1,196 | Caravan overlay's road surface |
| `stag_box` | 156–184 | 493–515 | 616 | Stag overlay's ground |
| `flock_south` | 456–520 | 748–775 | 1,728 | Flock overlay's ground below the master edge |
| `south_strand_w` | 128–528 | 810–870 | 24,000 | South strand, west band |
| `south_strand_e` | 512–800 | 810–870 | 17,280 | South strand, east band |
| `wanderers_isles_w` | 785–865 | 490–537 | 3,760 | Wanderer's Isles, west cluster |
| `wanderers_isles_e` | 920–1005 | 503–537 | 2,890 | Wanderer's Isles, east cluster |
| `cinder_skerries` | 920–1000 | 175–250 | 6,000 | Cinder Skerries |
| `far_isles` | 940–995 | 205–285 | 4,400 | The Far Isles |
| `ne_iceberg` | 974–991 | 210–225 | 255 | NE iceberg |

Total golden area 95,765 px = **9.13 %** of the atlas (the strand pair
overlaps by 16 px in x, so the union is slightly smaller).

### 2.3 Source 3 — the coordinate protection table (documentation, not enforced)

`GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/PROTECTION_PLAN.md` is the
ATLAS-C audit and the **authoritative human-readable table**. It classifies
every feature **HF** (hard-frozen, guard-enforced), **FC**
(frozen-centre / generated-surround) or **SOFT** (terrain type and palette must
survive; pixels may be re-authored). It is the only place naming features the
guards cover only *incidentally* (because they sit inside the core rect).

Named protected features, from that table:

**Playable settlements (all inside the core, HF):** Haven's Rest marker (456,521)
r12, painted 413–487 × 508–552 · Whispering Woods (383,509), ~300–430 × 460–560 ·
Stonefall Mine (566,496), massif 513–613 × 468–523, adit 553–580 × 488–515 ·
Forgotten Hollow (561,551), 540–598 × 530–575 · Frostmere (498,311) on the basin ·
Amberfield painted town 445–512 × 600–652, fields 380–580 × 583–700.

**Frostmere / Glasslake (the M-15 casualty):** frozen lake 403–550 × 282–362 ·
full glacial cirque 396–565 × 258–380 · north cirque wall in the rim band
400–560 × 256–276 (registry).

**Volcano and structures:** massif 580–817 × 278–465 · west watchtower
627–646 × 290–323 · east watchtower 727–751 × 273–323 · crater / eruption
overlay box 668–732 × 284–348 · east cliff→coves band 752–820 × 272–436 (visible
cliff 768–824 × 300–470; the **registry rect is 752–824 × 260–470**) · dark
speckled headland 756–800 × 279–310 (FC, known residual).

**Roads / routes:** corridor cut 256–384 × 483–558 (HF) · road join 216–320 ×
480–552 · log bridge est. 300–325 × 488–512 · west caravan road 128–256 ×
495–575 (road pixels HF, meadow FC) · ring-2 western valley road 0–128 × 495–580
(FC, centreline frozen) · caravan egg corridor 199–245 × 506–532 · stag egg box
156–184 × 493–515 · Wayfarer's Pass label ground (187,542) SOFT.
Route polylines (interface data, in `atlas_layout.json`): HR→WW via (421,518);
HR→SM via (506,518),(541,506); WW→SM via (436,488),(506,478),(551,488);
WW→FH via (406,556),(456,576),(521,571); SM→FM via (556,461),(539,416),(518,366).

**Rivers, delta, coast, islands:** Meadowrun channel 485–545 × 400–610 ·
Millbridge 490–510 × 546–566 · Delta + Ferry Crossing + Reedmouth + Marshlight
520–690 × 595–748 · east coastline + beach + shallows 618–700 × 470–700 ·
Saltreach Light tower 710–728 × 613–655, headland 645–738 × 608–672 ·
Tern Isles 672–752 × 505–590 · south strand 128–528 and 512–800 × 810–870 ·
Wanderer's Isles 785–865 × 490–537 and 920–1005 × 503–537 · Cinder Skerries
920–1000 × 175–250 (FC) · Far Isles 940–995 × 205–285 (FC) · flotsam-cleanup
rects (886–910, 622–662), (866–906, 760–784), (748–796, 844–906) SOFT (keep
open water).

**Ambient overlay anchors — the ground beneath each in-place scene.** An overlay's
frame 0 is an untouched source crop, so repainting the ground under its box makes
the sprite pop a rectangle of the old painting:
volcano eruption 668–732 × 284–348 (HF) · smoke 444–460 × 506–520 and
557–573 × 490–504 (HF) · yeti2 490–534 × 324–358 (HF) · bear2 340–366 × 592–620
(HF — the "bear-pop forest feature") · fire3 284–328 × 624–676 (HF) ·
tree_rustle_a 276–324 × 596–644, tree_rustle_b 352–396 × 660–704 (HF) ·
ripple_coast 676–716 × 536–584, ripple_delta 620–656 × 660–708 (HF) ·
flock 456–520 × 730–770 (HF; y 748–770 by registry) · nessie corridor
648–706 × 576–610 (SOFT water) · snow flurries ×3 456–520 × 286–350,
521–585 × 316–380, 416–480 × 351–415 (SOFT snow) · forest mist ×4
301–397 × 436–484, 346–442 × 586–634, 296–392 × 676–724, 496–592 × 706–754
(SOFT forest) · birds ×3 556–580 × 436–460, 676–700 × 556–580, 436–460 × 646–670
(SOFT) · whale 808–846 × 598–639, ship 765–805 × 645–680 (SOFT open water) ·
**skydragon corridor 282–406 × 318–360 (SOFT — biome only)**.

**Frontier label grounds (SOFT — terrain must keep matching the name):**
Worldspine (157,333) ridge · Frozen Shelf (445,176) pack ice · White Reach
(600,60) polar ice · Sunward Strand (511,860) beach · the three island labels.
Note the island label anchors sit in open water W/NW of their painted clusters —
protect the **painted clusters**, not the anchors.

---

## 3 · The guard implementation — exactly what it blocks

Both guards live at the end of the atlas block in `Scripts/art/package-art.js`
and run on **every** packaging invocation, `--check` included.

### 3.1 Repair-clip pass (runs mid-composition, `package-art.js:1657–1668`)

```js
  // Protected-interior restore: undo every bridge pixel that landed deeper
  // than the rim band, feathering across the band so no straight clip line
  // can read (World Atlas Restore 01). This brings back the Frostmere frozen
  // basin, the volcano watchtowers and the approved east coastline.
  for (let y = PROT.y0; y < PROT.y1; y++) {
    for (let x = PROT.x0; x < PROT.x1; x++) {
      const d = protDepth(x, y);
      if (keepRepair(x, y, d)) continue;
      const ai = base.idx(x, y);
      for (let k = 0; k < 4; k++) base.data[ai + k] = approved.data[ai + k];
    }
  }
```

Each later repair family repeats the same clip inline — the region layer at
`:1805`, the adoption blits at `:1700` and `:1756`, the despeckles at `:1862`
and `:1915`. The idiom is always `if (protDepth(tx, ty) > PROT.band) continue;`.

### 3.2 Protected-interior drift guard (`package-art.js:2045–2068`)

```js
  // Protected-interior guard: beyond the rim band, every pixel that is not
  // conformable open water must be byte-identical to the approved snapshot.
  {
    let drift = 0;
    for (let y = PROT.y0; y < PROT.y1; y++) {
      for (let x = PROT.x0; x < PROT.x1; x++) {
        if (protDepth(x, y) <= PROT.band) continue;
        const i = base.idx(x, y);
        const same = base.data[i] === approved.data[i] && /* g, b */;
        if (same) continue;
        // The ocean conform legitimately remaps teal deep water in place.
        if (oceanTool.isDeep(approved.data[i], approved.data[i + 1], approved.data[i + 2])) continue;
        drift++;
      }
    }
    if (drift > 0) {
      throw new Error(`world/atlas_base: protected interior drift — ${drift} px ` +
        `of the approved master core were repainted by a repair layer (M-15)`);
    }
  }
```

- **Blocks:** any non-deep-water pixel change inside x ∈ [276,747] × y ∈ [276,747].
- **Allows:** everything in the 20 px rim band (subject to the hash feather, so a repair only "wins" statistically near the perimeter); the ocean conform's remap of pixels that were **deep teal in the snapshot** (RGB compared, alpha ignored).
- **Failure mode:** a thrown `Error` — packaging aborts and `--check` fails, so CI goes red rather than shipping drift.

### 3.3 Landmark-registry guard (`package-art.js:2070–2107`)

```js
    const reg = JSON.parse(
      fs.readFileSync(path.join(REM01, 'landmark_registry.json'), 'utf8'));
    for (const lm of reg.landmarks) {
      const golden = png.load(path.join(REM01, 'goldens', `${lm.id}.png`));
      if (golden.width !== lm.w || golden.height !== lm.h) { throw ... }
      let drift = 0;
      for (let sy = 0; sy < lm.h; sy++) {
        for (let sx = 0; sx < lm.w; sx++) {
          const gi = golden.idx(sx, sy), ai = base.idx(lm.x + sx, lm.y + sy);
          const same = /* RGB equal */;
          if (same) continue;
          if (oceanTool.isDeep(golden.data[gi], golden.data[gi+1], golden.data[gi+2])) continue;
          drift++;
        }
      }
      if (drift > 0) {
        throw new Error(`world/atlas_base: protected landmark '${lm.id}' drifted ` +
          `(${drift} px vs its golden) — a layer repainted a registry feature ` +
          `(A-4 extension, World Atlas Remaster 01)`);
      }
    }
```

- **Blocks:** any non-deep-water RGB change inside any of the 15 golden rects, wherever they are (they are all outside or straddling the core).
- **Allows:** deep-teal water drift (the global conform's statistics legitimately shift whenever any layer changes any water).
- **The authorization protocol:** deliberate re-authoring of a landmark means **re-extracting its golden PNG in the same commit** — the golden's git diff *is* the authorization record. Precedents: `south_strand_w` (R3b), `south_strand_e` (D-05 fill fix).

### 3.4 The region status gate (`package-art.js:1786–1806`)

```js
    for (const region of manifest.regions) {
      if (region.status !== 'accepted') {
        throw new Error(`atlas region ${region.id}: status '${region.status}' — ` +
          `only accepted regions may ship`);
      }
      ...
      if (m < 255 && hash(tx, ty, region.salt) >= m / 255) continue;
      const d = protDepth(tx, ty);
```

A region is a **masked dither-select blit** — selection, never averaging (A-2):
every output pixel is one of the two approved images' own pixels. Regions are
placed after every legacy repair layer and **before** the ocean conform. **Salts
1–14 are taken** (1–7 by crossfade/rim/adoption/shoal, 8–14 by the seven
regions); a new region must claim **salt ≥ 15**.

### 3.5 Invocation

| Where | Command |
|---|---|
| CI (`.github/workflows/ci.yml:135`) | `node ./Scripts/art/package-art.js --check` under "Shipped art matches the packaging step" |
| Local (`Scripts/verify.sh:148`) | same |
| Regeneration | `node Scripts/art/package-art.js` (no flag) — writes `assets/art/v1/` + one generated Dart file |

`--check` writes nothing and compares byte-for-byte, so a hand-edited asset, a
stale asset, or an unexpected extra file all fail. Current result: **851 files up
to date**.

**Governing rule text** — `RULES.md` **A-4**: *"Approved atlas interiors are
protected in tooling, and a repair may write only its transition band. …
Repainting approved geography to solve a seam is a defect, not a technique; masks
are authored in or outside the band."* Related: **A-1** (PixelLab makes the art),
**A-2** (deterministic transformation is not authoring), **A-3** (production
atlas expansions are transition-authored across every boundary; no generated
boundary ships until a blind read at iPhone-viewport scale confirms continuity).

---

## 4 · The master atlas image and every derived asset

### 4.1 Shipped

| Path | Size | Bytes | Notes |
|---|---|---|---|
| `assets/art/v1/world/atlas_base.png` | 1024 × 1024 | 521,346 | **The atlas.** One image — *not* tiled |
| `assets/art/v1/world/region_map.png` | 384 × 640 | 79,057 | Retired from the World tab; kept as the atlas **fallback** |
| `assets/art/v1/world/marker_haven.png` | 20 × 20 | 143 | Kind glyph |
| `assets/art/v1/world/marker_wilds.png` | 20 × 20 | 281 | Kind glyph |
| `assets/art/v1/world/marker_worksite.png` | 20 × 20 | 191 | Kind glyph |
| `assets/art/v1/world/marker_perilous.png` | 20 × 20 | 152 | Kind glyph |
| `assets/art/v1/world/marker_landmark.png` | 20 × 20 | 164 | Kind glyph |
| `assets/content/v1/atlas/atlas_layout.json` | — | — | schema v5; the tile table, 5 locations, 23 landmarks, 5 routes, 0 props, **30 overlays** |
| `assets/art/v1/env/overlay_*_f*.png` | 15×20 … 96×48 | 788 KB total (218 files incl. props) | The map-life sprite frames |
| `assets/art/v1/env/prop_*.png` (7) | 32–96 px | — | Scatter props — **shipped but unreferenced**; `props` is `[]` |

### 4.2 Tile structure

**There is none.** `atlas_layout.json` declares exactly one base tile:

```json
"base": { "tiles": [ { "asset": "world/atlas_base", "x": 0, "y": 0,
                       "width": 1024, "height": 1024 } ] }
```

The layout format *supports* a tile grid (`AtlasBaseLayer` loops
`scene.layout.tiles`), but the shipped world is a single 1024² PNG scaled ×6.

### 4.3 Principal sources (tracked, not shipped)

- **The master painting:** `GAME_BIBLE/ART/exploration/PRESENTATION_WORLD_REWARD_FEEL_01/out/world/whole_a_0.png` — 512 × 512, blitted at (256,256).
- Inner ring: `GAME_BIBLE/ART/exploration/WORLD_MAP_POLISH_03/out/world/`
- Outer ring + static patches: `GAME_BIBLE/ART/exploration/WORLD_MAP_EXPANSION_REFINEMENT_02/out/world/`
- Bridges: `GAME_BIBLE/ART/exploration/WORLD_ATLAS_COHERENCE_UI_01/out/bridges/`
- Ocean conform: `.../WORLD_ATLAS_COHERENCE_UI_01/tools/ocean_unify.js`
- Regions: `.../WORLD_ATLAS_REMASTER_01/{out,src}/`, manifest `regions_manifest.json`
- Goldens: `.../WORLD_ATLAS_REMASTER_01/goldens/`
- Shoal ramp / extra rects: `.../WORLD_ATLAS_REMASTER_01/tools/water_join.js`
- Stamp belts: `.../WORLD_ATLAS_REMASTER_01/iteration_02/tools/stamp_belts.js`
- Pre-remaster reference: `.../WORLD_ATLAS_REMASTER_01/review/before/atlas_base_before.png`

---

## 5 · How the world map renders

**Screen:** `lib/ui/screens/world/world_screen.dart` — a `Stack` where the atlas
fills the content area with `Positioned.fill` and the selection panel floats over
it as gradient glass (`0xB4` → `0xE6`), with a drag handle and a fold to a 76 px
peek strip.

**Viewport:** `lib/ui/screens/world/atlas/atlas_viewport.dart` (461 lines).

- **Hand-rolled gesture, deliberately not `InteractiveViewer`** — the camera must land on whole device pixels (a fractional translation gets bilinear-blurred regardless of `FilterQuality.none`) and the zoom must settle where one source pixel is a whole number of device pixels.
- **Zoom stops** (`AtlasZoom.forScale(6)`): `absoluteFloor = 1/scale` (native ×1), `initial = 2/scale` (native ×2 — the accepted opening view), `max = 4/scale` (native ×4). The effective floor is `max(viewportWidth/worldWidth, absoluteFloor)`.
- **`overviewBelow = initial`** — one LOD boundary, no LOD engine. Below it, landmark captions, landmark marker art and scatter props are **not built at all**; place labels, kind glyphs, rings, the current marker and the routes stay.
- **Motion gating:** a single `TickerMode` here, nested inside the shell's per-tab `TickerMode` (`stride_shell.dart`). Either being disabled silences every animated thing on the atlas.
- **Vocabulary:** drag pans, pinch zooms about the fingers, tap on a marker selects. No avatar, no draggable figure, nothing that issues a command. The viewport does not know `SessionController` exists.

**Layers** — `lib/ui/screens/world/atlas/atlas_layers.dart` (1,652 lines), one
world-sized `Stack`, each layer its own `RepaintBoundary`, bottom to top
(`atlas_viewport.dart:427–438`):

1. **`AtlasBaseLayer`** — the geography. Loops `layout.tiles`; one `PixelAsset` per tile at `tile.x*scale`, `tile.y*scale`.
2. **`AtlasRouteLayer`** — `CustomPaint` dotted lines along every declared road; the selected journey's edges drawn heavier/brighter. Chrome only, never teal (L-16).
3. **`AtlasLandmarkLayer`** — a static PNG on each place/named landmark that has one. No ticker, no hit-testing (that is what makes a named landmark scenery rather than a place). Hidden in overview.
4. **`AtlasOverlayLayer`** — ***the map-life / animation layer.*** See §5.1.
5. **`AtlasMarkerLayer`** — rings, labels, kind glyphs, the pulse under *here*, the gold journey ring, arrival burst. **The only layer that hit-tests**; a drag beginning on a marker becomes a pan.

Chrome (rings, labels) counter-scales by zoom so type stays its designed size.

### 5.1 The existing overlay / animation layer — YES, one already exists

`AtlasOverlayLayer` (`atlas_layers.dart:334–487`) is a `StatefulWidget` with
**one `Ticker` driving all 30 overlays**, the whole layer inside one
`RepaintBoundary` and an `IgnorePointer` (overlays never take input).

- **Repaints coarsely, not per vsync:** `_frameKey(t)` fingerprints every overlay's visibility, frame index and floor-ed drift position; `setState` fires only when the fingerprint changes.
- **Two mutually exclusive kinds of motion** (`_driftPosition`):
  - `drift {x,y}` — world px/s, **wraps** around the world edges.
  - `travel {x,y}` — world px/s **during a play only**, never wraps; the sprite stands at its origin again for each new play. Schema v5; the parser refuses `travel` on a continuous loop and refuses `travel` beside `drift`.
- **Intermittency:** `intervalMillis` (v4) is a quiet gap during which the widget is **not built at all** — the creature is *gone*, not paused. `playLoops` (v5) repeats a frame loop within one play.
- **`opacity`** is a compositor multiplier applied per overlay.
- **Precaching:** every frame of every overlay is `precacheImage`d in `didChangeDependencies`.
- Positions are `floorToDouble()`-snapped so nothing samples fractionally.

**Layout data model:** `lib/runtime/atlas_layout.dart` (1,077 lines) — `AtlasOverlay`
carries `asset, x, y, width, height, frameCount, frameMillis, driftX, driftY,
opacity, intervalMillis, travelX, travelY, playLoops`, with
`visibleAt(t)`, `frameIndexAt(t)`, `playMillisAt(t)`, `activeMillis`,
`cycleMillis`. Schema fields are **version-gated**: a pre-v4 document carrying
`intervalMillis`, or a pre-v5 document carrying `travel`, is *refused*, never
silently downgraded.

**Adding a new creature therefore touches exactly four things:**
1. PixelLab frames → an exploration `out/` directory (A-1).
2. `emit('env/overlay_<id>_f<n>.png', …)` lines in `package-art.js` (crop/frame selection recorded in code, A-2).
3. An `overlays[]` entry in `assets/content/v1/atlas/atlas_layout.json`.
4. Nothing in Dart — the layer is data-driven.

`test/atlas_layout_test.dart:169` (*"every asset the layout names is packaged at
its declared size"*) walks every frame of every overlay and asserts the file
exists with the exact IHDR dimensions the layout declares, so a mismatch fails
the suite rather than flickering on device.

---

## 6 · Existing map-life assets

`assets/art/v1/env/` — 218 files, 788 KB. 22 overlay families, **all shipped and
all animated except where noted**, plus 7 unused props.

| Overlay | Frames | Native px | Placement (atlas px) | Motion |
|---|---|---|---|---|
| `overlay_skydragon` | 28 | 68 × 31 | (338, 328) | **The existing green dragon.** `travel` (−30, −5) px/s, `playLoops: 1`, 40 s gap — flies NW across the north forest |
| `overlay_nessie` | 17 | 44 × 33 | (662, 576.5) | `travel` (−12, 0), 26 s gap — lake/coast serpent |
| `overlay_whale` | 9 | 38 × 41 | (808, 598) | 30 s gap, in place |
| `overlay_ship` | 1 | 15 × 20 | (788, 648) | `travel` (−9, 4), 45 s gap — **single frame** |
| `overlay_caravan` | 1 | 20 × 19 | (225, 512) | `travel` (−12, −1), 52 s gap — **single frame**, rides the west caravan road |
| `overlay_stag` | 20 | 28 × 22 | (156, 493) | 34 s gap |
| `overlay_flock` | 13 | 64 × 40 | (456, 730) | 23 s gap |
| `overlay_bear2` | 19 | 26 × 28 | (340, 592) | 20 s gap — **in-place scene** (edit of the painting) |
| `overlay_yeti2` | 8 | 44 × 34 | (490, 324) | continuous — **in-place scene** |
| `overlay_fire3` | 10 | 44 × 52 | (284, 624) | continuous — **in-place scene**, SW forest burn |
| `overlay_volcano` | 17 | 64 × 64 | (668, 284) | 14 s gap — eruption |
| `overlay_smoke` ×2 | 6 | 16 × 14 | (444,506), (557,490) | continuous, opacity 0.8 |
| `overlay_forge_smoke` | 3 | — | — | packaged, **not placed in the layout** |
| `overlay_birds` ×3 | 6 | 24 × 24 | (556,436), (676,556), (436,646) | `drift` (16, −3), opacity 0.9 |
| `overlay_snow_flurry` ×3 | 8 | 64 × 64 | (456,286), (521,316), (416,351) | continuous |
| `overlay_forest_mist` ×4 | 6 | 96 × 48 | (301,436), (346,586), (296,676), (496,706) | continuous, opacity 0.4 |
| `overlay_tree_rustle_a/b` | 9 / 9 | 48² / 44² | (276,596) / (352,660) | 9 s / 13 s gaps |
| `overlay_ripple_coast` / `_delta` | 8 / 8 | 40×48 / 36×48 | (676,536) / (620,660) | continuous |
| `overlay_cloud_shadow` ×2 | 1 | 96 × 48 | (406,531), (356,614) | `drift` (12,0), opacity 0.16 |
| `overlay_cloud_wisp` | 1 | 96 × 48 | (506,389) | `drift` (9,0), opacity 0.30 |
| `env/prop_{boulders,cairn,dead_tree,hedgerow,lone_oak,pine_clump,snowdrift}.png` | static | — | **none — `props: []`** | The scatter-prop channel exists in code and data and is entirely unused |

**Non-map fauna already generated elsewhere:** `assets/art/v1/ambient/` carries
`fauna_{crow,hare,ptarmigan,songbird}_16_f0.png` (16 px, **single frame, not
animated, not placed on the atlas**) and a full cat animation set — these are
gather-stage / companion assets, not atlas overlays.

**The in-place-scene technique** (`package-art.js:2112–2175`) is the anti-pop
mechanism and is the precedent any new grounded creature should follow: a 64²
crop of the master is edited by PixelLab (`edit_image`) and animated
(`animate_image`); each frame is composited back onto its source crop through a
fixed **content box** (rings 0–1 pure source, 2–3 blend 2:1, 4–5 blend 1:2,
interior generated) and only the box is emitted. Frame 0 is the untouched source
crop, so the loop's rest state *is* the painting.

**Retired for cause** (`WORLD_MAP_POLISH_03`): the part-2 bear (mascot-sized
head), yeti (floated) and water dragon (read as a slug) all failed device review.
`fire2` is retired because the WMER02 caravan corridor was cut through its content
box, so its always-visible frame 0 would paint pre-corridor forest over the road —
**the standing warning that an overlay's ground and the atlas must change
together.**

---

## 7 · Known outstanding visual defects

Source of record:
`GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/iteration_02/WORLD_ATLAS_REMASTER_01_DEVICE_DEFECT_REGISTER.md`
(authority: seven owner iPhone screenshots, 2026-08-26, in
`iteration_02/device_screens/`). Planned fixes:
`iteration_02/POST_RESET_GENERATION_PLAN.md`.

Severity: **P0** world-illusion blocker · **P1** strong distraction · **P2** cosmetic.

### 7.1 P0 — the three "two paintings touching" families

| ID | Coordinates | Symptom | Status / proposed fix |
|---|---|---|---|
| **D-01** | column **x 250–276 × y 260–780** (ledger segments y 300–360, 495–576; pale scar 260–272 × 390–450) | **The hard treeline wall.** Dense conifer canopy ends on a razor vertical against open plain — full density to zero in one column. The single strongest defect | Iteration 02 shipped the A1 meadow-side stamp taper (14 stamps, x 200–256). **Open:** plan item **W1** — crop ≈(176,260) 128×220, mask x 228–275 × y 280–460, author bays/glades into the standing canopy face, never past x 275. **50 gens.** The canopy face at x ≥ 276 is A-4-frozen — OWNER decision |
| **D-02** | **y 810–870 × x 0–560**, break centred y≈850 | **South latitude layer-cake:** olive sward / straight inland sand strip / bright lime plain in three horizontal bands across the whole south | **BLOCKED on Q-13** (lime-band identity). Plan item **Z1**: if lime stays, terrain-following graded remix (0 gens + golden re-extractions); if one green wins, whole-plain conform + edge repaints. Overlaps both strand goldens |
| **D-12** | **x 110–280 × y 855–968**; ghost trees 245–275 × 885–955 | **SW dark forest slab:** near-black canopy block, straight top edge y≈860, abrupt east edge x≈280, on the brightest lime ground — worst value cliff in the atlas | Iteration 02 shipped C1/C2/C5 stamp fringes (16 stamps). **Open:** plan item **S1** — crop ≈(96,816) 224×160, perimeter ring mask ~x 120–290 × y 846–958, replace ghost hybrid trees, break the level top line. **45 gens.** Rows 846–870 intrude on `south_strand_w` → golden re-extraction, owner-flagged |

### 7.2 P1

| ID | Coordinates | Symptom | Status / proposed fix |
|---|---|---|---|
| D-26 | split at R1's west boundary; interior shelf (460–550 × 40–140) mean [174,215,224] vs R1 shelf (640–740 × 40–140) mean [210,235,244] | **NE "constructed" read root:** ponded-gray vs clean-white ice character. No column step >10, so no seam metric sees it | Plan item **R6** — crop ≈(480,0) 200×280, mask x 520–660 × y 0–250; also resolves the D7 floe corner and the mint remnant; prompt for ≥10–14 px plates so shapes survive minification. **60 gens.** Stop ≥6 px above the Frostmere golden (y 256) |
| D-25 | y=838, x 360–640 — zero water columns cross the strand | **Delta braids die in dry sand** | Plan item **S3/S4** — crop ≈(340,700) 380×140, mask x 380–670 × y 748–806 carved to y 774 under the flock sliver. **45 gens** |
| D-09 | x 380–660 × y 755–775 | Marsh→silt join: vivid green/blue marsh on gray silt along a contour, no interleaving | Same S3/S4 region |
| D-05 | x 620–780 × y 800–870; slab right edge x≈683, internal top y≈836 | **SE cape staircase.** Iteration 02 fixed the self-inflicted L-cut (the ghost-sail flotsam fill had offset-copied open sea over the beach corner) | Residue open: plan item **S5** — crop ≈(600,790) 200×110, mask x 630–780 × y 812–858. **40 gens.** Inside `south_strand_e` golden → re-extraction. Alternative: ATLAS-K's deterministic 1:1 shade-ramp conform of the slab's 4–6 sand shades onto the cream ramp (638–686 × 810–857), **0 gens** |
| D-07 | x 220–242 × y 120–180 | R5 remnant panel: darker strip with miniature mountains, straight right edge x≈240 | Plan item **N2** — crop (190,110) 90×90, mask x 214–242 × y 120–180 |
| D-08 | x 435–530 × y 205–270 | Ghost mountain: low-contrast painterly smudge amid crisp pixel peaks | Plan item **N2** — crop (410,190) 140×100, mask x 435–530 × y 205–268; carve above the Frostmere golden at y 256 where x ≥ 400. N2 total **45 gens** |
| D-11 | x 795–815 × y 0–150 | Vertical texture seam: floe cells left, smoother wash right | Folded into R6 (floe-scale blend) |
| D-10 | x 952–970 × y 265–282 | Hollow atoll ring: tan outline with sea-coloured interior | Post-reset; inside `far_isles` (FC — improve under review) |
| D-14 | x 705–761 × y 235–303 | Green confetti smear over the ice cliff with drip trails (owner-marked) | Iteration 02 shipped a deterministic nearest-ice fill; **in-golden residue remains** → plan item **N3**, tiny crop ≈(740,250) 60×70, mask x 748–762 × y 258–300, **25 gens**, gated on the device re-shot |
| D-03 | x 865–1024 × y 0–110 | Pale rectangular panel read in the floe field | **Native-verified clean** — minification banding of fine floe texture. No source defect; covered by R6's coarsening |
| D-06 | x 257–374 × y 257–272 | Treeline confetti — 74 isolated dark flecks on snow (owner red box) | **FIXED** Iteration 02: deterministic despeckle + 15 straggler-pine stamps (belt B1) |
| D-04 | x 250–350 × y 750–805 | Canopy south cut onto sand, scalloped boundary + rust-red trail specks | Red dots removed Iteration 02 (`strand_w` re-authorized). **Banding remains** — partly A-4 core, OWNER |
| D-15 | x 741–748 × y 820–855 | White streak / orphan surf column below the cape | Treated with D-05 Iteration 02 (beach toe + surf restored) |

### 7.3 P2

D-13 farm/forest hard join **x 370–420 × y 590–675** — gold fields butt dark
canopy, zero hedge; **fully A-4-frozen, OWNER only** · D-17 conifer sprite
corduroy **x 270–340 × y 260–350**, mostly core · D-18 flat olive band abutting
glacier **x 40–75 × y 270–320** · D-19 rust/brown speckle **x 620–720 × y 745–770**
(with S3/S4) · D-20 teal pixel spray **x 740–775 × y 720–765** · D-21 twin
kidney islands read copy-pasted **(800–860, 490–535)** · D-22 ice crack-cell
density boundary **(230–320, 180–260)** and green pocket **(220–265, 380–420)** ·
D-23 two identical wave clusters ≈**(800,895)** and **(930,895)** · D-24 boulder
confetti **x 10–90 × y 690–780** · D-16 floe speckle → gray static
**x 760–900 × y 60–200**.

**Neither confirmed nor cleared:** mint remnant **(560–615, 0–95)**; D7 floe
corner **(510, 27)**; owner_04's peninsula left edge (occluded by the owner's own
markup — needs a clean re-shot).

---

## 8 · The definitive two lists

### 8.1 LIST A — PROTECTED (must not be repainted)

**A1 · The A-4 hard-frozen core — machine-enforced, no exceptions without an owner ruling.**

> **x ∈ [276, 747] × y ∈ [276, 747]** (472 × 472 px, 21.25 % of the atlas).
> Enforced by the drift guard at `package-art.js:2045`. The only permitted change
> is the ocean conform's remap of pixels that were already deep teal.

Everything in §2.3's HF tables that lies in this rect is protected *by* this rect:
all five settlements, Amberfield's town and fields, the Frostmere/Glasslake basin
and cirque, the volcano massif and both watchtowers, the crater box, the corridor
cut, Meadowrun, Millbridge, the delta/Ferry Crossing/Reedmouth/Marshlight, the
east coastline, Saltreach Light, Tern Isles, and the overlay grounds for volcano,
smoke ×2, yeti2, **bear2 (340–366 × 592–620 — the bear-pop forest feature)**,
fire3, tree_rustle a/b, ripple_coast and ripple_delta.

**A2 · The 20 px rim band — writable but hash-feathered, never a straight edge.**

> The ring 256–276 and 748–768 on each side, inside the core rect. A repair may
> write here; the `keepRepair` dither means a repair wins near the perimeter and
> loses near the core, so no straight clip line can read. **This is where a mask
> is allowed to end**, and it is the only place a fair-game region may touch the
> core.

**A3 · The 15 registry goldens — machine-enforced byte-wise, wherever they sit.**

| id | x | y | Feature |
|---|---|---|---|
| `frostmere_north_wall` | 400–560 | 256–276 | Frostmere north cirque wall |
| `east_watchtower_flank` | 744–752 | 273–323 | East watchtower flank |
| `volcano_east_cliff` | 752–824 | 260–470 | Volcano east cliff / coves |
| `roadjoin_corridor_west` | 216–276 | 480–558 | Road join / corridor west end |
| `west_caravan_road` | 128–256 | 495–575 | West caravan road |
| `caravan_corridor` | 199–245 | 506–532 | Caravan overlay ground |
| `stag_box` | 156–184 | 493–515 | Stag overlay ground |
| `flock_south` | 456–520 | 748–775 | Flock overlay ground |
| `south_strand_w` | 128–528 | 810–870 | South strand west |
| `south_strand_e` | 512–800 | 810–870 | South strand east |
| `wanderers_isles_w` | 785–865 | 490–537 | Wanderer's Isles west |
| `wanderers_isles_e` | 920–1005 | 503–537 | Wanderer's Isles east |
| `cinder_skerries` | 920–1000 | 175–250 | Cinder Skerries |
| `far_isles` | 940–995 | 205–285 | Far Isles |
| `ne_iceberg` | 974–991 | 210–225 | NE iceberg |

Escape hatch, and the only one: **re-extract the golden PNG in the same commit**
as the repaint. The git diff is the authorization. Precedents `south_strand_w`
(R3b) and `south_strand_e` (D-05). Any strand-golden re-extraction is currently
**owner-flagged** (Q-13).

**A4 · Interaction-critical geometry (not pixel-protected, but semantically frozen).**
No repaint may change what these coordinates *mean*, because the layout's hit
targets and polylines are authored against them: the five location markers and
their r12 hit circles; the five route polylines; the 23 landmark label anchors;
and every overlay box in §6 — an overlay's frame 0 is an untouched source crop,
so repainting under a box makes the sprite pop a rectangle of the old painting
(the retired `fire2` is the recorded proof).

**A5 · SOFT — pixels may be re-authored, terrain identity may not.**
Nessie corridor 648–706 × 576–610 (coastal water) · snow flurries ×3 · forest
mist ×4 · birds ×3 · whale 808–846 × 598–639 and ship 765–805 × 645–680 (open
water) · **skydragon corridor 282–406 × 318–360 (biome only)** · Ring-2 western
valley road 0–128 × 495–580 (centreline frozen) · flotsam rects (886–910,622–662),
(866–906,760–784), (748–796,844–906) (keep open water) · Cinder Skerries and Far
Isles surrounds (FC) · dark speckled headland 756–800 × 279–310 (FC) · the
frontier label grounds — Worldspine (157,333) ridge, Frozen Shelf (445,176) pack
ice, White Reach (600,60) polar ice, Sunward Strand (511,860) beach.

### 8.2 LIST B — FAIR GAME (weak non-protected areas, owner-authorized for recomposition)

Everything **outside** the A1 core, **outside** the 15 goldens and respecting the
A4/A5 constraints. That is **≈70 %** of the atlas: the two 128 px rings plus the
strip between them, i.e. the bands x < 276, x ≥ 748, y < 276, y ≥ 748. Ordered by
owner-visible impact.

| # | Zone | Rect | Defect it suffers | Constraint |
|---|---|---|---|---|
| **B1** | **West verge / forest-wall shoulder** | x 200–276 × y 260–780 | **D-01 P0** hard treeline wall (razor vertical, full canopy → zero) | Golden standoff: `roadjoin_corridor_west` (216–276 × 480–558), `west_caravan_road` (128–256 × 495–575), `caravan_corridor`, `stag_box`. The canopy face itself at x ≥ 276 is core — mask must end at x 275. Plan W1 |
| **B2** | **SW dark slab** | x 100–290 × y 846–1005 | **D-12 P0** near-black canopy block on lime, straight top y≈860, abrupt east edge x≈280, ghost half-dithered trees 245–275 × 885–955 | Rows 846–870 intrude on `south_strand_w` → re-extraction, owner-flagged. Plan S1 |
| **B3** | **South latitude band** | x 0–800 × y 748–1024 (the cake break is y 810–870, centred y≈850) | **D-02 P0** three-band layer-cake; **D-04** canopy south cut + banding below y 748; **D-24** boulder confetti x 10–90 × y 690–780 | `south_strand_w/e` goldens cover y 810–870 across x 128–800; `flock_south` covers 456–520 × 748–775. **Blocked on Q-13** (lime identity). Plan Z1 |
| **B4** | **Delta apron / marsh–silt–surf transition** | x 340–720 × y 748–806 | **D-25 P1** braids die in dry sand; **D-09 P1** marsh/silt contour with no interleaving; **D-19 P2** rust speckle 620–720 × 745–770 | Carve to y 774 under the `flock_south` sliver; ≥4 px standoff from the delta HF (520–690 × 595–748). Plan S3/S4 |
| **B5** | **North shelf / ice-character split** | x 480–680 × y 0–280 | **D-26 P1** ponded-gray vs clean-white ice dialects; **D-11 P1** texture seam x 795–815 × y 0–150; **D-16/D-03 P2** floe speckle → gray static; mint remnant 560–615 × 0–95; D7 floe corner (510,27) | Stop ≥6 px above `frostmere_north_wall` (y 256). White Reach label must stay pack ice. Plan R6 |
| **B6** | **NW icefield** | x 0–276 × y 0–276 | **D-07 P1** R5 remnant panel 220–242 × 120–180 (straight right edge x≈240); **D-22 P2** crack-cell density boundary (230–320,180–260) and green pocket (220–265,380–420) | R5 accepted region below; NW glacier vignette west. Plan N2 |
| **B7** | **North treeline / ghost mountain** | x 276–560 × y 0–276 | **D-08 P1** ghost mountain 435–530 × 205–270 (painterly smudge amid crisp peaks); D-06 treeline confetti (already fixed) | Carve above the Frostmere golden at y 256 where x ≥ 400. Plan N2 |
| **B8** | **SE cape / terrace** | x 600–800 × y 790–870 | **D-05 P1** pale sand slab, straight right edge x≈683, internal terrace line y≈836 | Entirely inside `south_strand_e` → re-extraction, owner-flagged. **0-gen alternative** exists (shade-ramp conform 638–686 × 810–857). Plan S5 |
| **B9** | **NE ice cliff junction** | x 700–752 × y 235–303 | **D-14 P1** residue — green confetti drip trails over the ice cliff (owner-marked) | Clip to x < 752 for y ≥ 260 (`volcano_east_cliff`); exclude `east_watchtower_flank` 744–752 × 273–323; skip protDepth > 20. Plan N3 |
| **B10** | **East archipelago waters** | x 748–1024 × y 276–748 | **D-20 P2** teal pixel spray 740–775 × 720–765; **D-21 P2** twin kidney islands read copy-pasted (800–860, 490–535); **D-23 P2** identical wave clusters ≈(800,895),(930,895) | `wanderers_isles_w/e` island land is golden — the spray sits on shore/water outside it. Whale and ship corridors are SOFT open water |
| **B11** | **NW glacier margin** | x 0–128 × y 260–340 | **D-18 P2** flat olive band abutting glacier at a hard edge | NW vignette; small |
| **B12** | **Far-north / far-east open ocean and outer ring generally** | x 0–1024 × y 0–128; x 896–1024 × y 0–1024; x 0–128 × y 0–1024; x 0–1024 × y 896–1024 minus goldens | Featureless conformed sea and ice — the emptiest, weakest surface on the map | This is the **best real estate for new magical landmarks and creature life**: no goldens outside the island clusters, no core, no overlay grounds. Ocean conform runs last and will re-conform any deep teal placed here |

**Also fair game as an authoring surface, though not defective:** the seven
accepted remaster regions (`r1_ice` 560–1024 × 0–320, `r2_verge` 152–336 ×
528–856, `r3_sketch` 0–200 × 720–1024, `r3b_band` 72–184 × 800–1024, `r4_coast`
420–612 × 820–1024, `r5_nwice` 166–396 × 124–300, `r3c_topedge` 0–176 × 780–936).
They are recent, device-reviewed work; superseding one means a new manifest entry
(regions are applied in list order, later wins) with **salt ≥ 15**.

### 8.3 Hard blockers to respect before any of this executes

1. **PixelLab budget = 25 generations**, the untouchable reserve, until the **2026-09-16 reset**. A single inpaint bills ~20–40, so the current capacity is *one* correction. `get_balance` before planning any call — never trust a remembered figure.
2. **Q-13 open questions** (`JOURNAL/OPEN_QUESTIONS.md`): lime-band identity (gates B3, colours B2/B4 prompts); A-4 core exceptions for owner-marked in-core defects (D-13, D-17, D-04 banding, Longwood interior); strand-golden re-extraction approvals; and a clean re-shot of owner_04's peninsula edge.
3. **The owner's mandated single-defect loop**: author → validate → render → inspect → adjust, per region; a region failing twice restores the composite and defers (M-12). **No batch of unreviewed terrain fixes.** The physical iPhone is the final authority.
4. **A-3**: no generated boundary ships until a blind read at iPhone-viewport scale confirms biome, coastline, detail-scale and palette continuity.

---

## 9 · Atlas tests and validation — what exists and how to run it

| Check | Command | What it proves |
|---|---|---|
| **Art packaging + both atlas guards** | `node ./Scripts/art/package-art.js --check` | Every shipped asset byte-matches what the packaging step produces from tracked sources; the protected-interior drift guard and the 15-golden landmark guard both pass; no unexpected or missing files. Current: **851 files up to date** |
| Regenerate the atlas | `node ./Scripts/art/package-art.js` | Writes `assets/art/v1/` + one generated Dart file. The guards throw here too |
| Nav variants | `node ./Scripts/art/nav-active-variant.js --check` | Derived nav art |
| Layout ↔ asset contract | `flutter test test/atlas_layout_test.dart` (760 lines) | The shipped layout parses and is bundled; every content location has a coordinate and nothing else does; the base tiles cover the world at the declared scale; **every asset the layout names is packaged at its declared IHDR size** (tiles, location landmarks, landmark art, kind glyphs, props, every overlay frame); the master carries no landmark cutouts; schema version gating v1→v5, including refusing pre-v4 `intervalMillis` and pre-v5 `travel`, refusing `travel` on a continuous loop and `travel` beside `drift`; intermittent and travelling overlay timing |
| Scene projection | `flutter test test/atlas_scene_test.dart` (935 lines) | Layout → `AtlasScene` |
| Screen behaviour | `flutter test test/atlas_screen_test.dart` (728 lines) | The real screen over a real save |
| Panel view model | `flutter test test/atlas_inspector_test.dart` (546 lines) | What the selection panel says about a place |
| **World goldens** | `flutter test test/phase1_golden_test.dart` | `test/goldens/phase1_world.png` and `phase1_world_large.png` — the World tab as rendered. **These only cover the default viewport (centred on Haven's Rest)**; every remaster region lay outside it, which is why "World goldens unchanged and passing" held through the whole remaster. **A fair-game repaint near Haven's Rest, or a new overlay inside the default view, will move them and must be regenerated and reviewed** |
| Whole local gate | `bash ./Scripts/verify.sh` | Includes `package-art.js --check` at line 148 |
| CI | `.github/workflows/ci.yml` step *"Shipped art matches the packaging step"* (line 135) | Same two `--check` commands |

**Caveat carried from `PRESENTATION_COMBAT_EVOLUTION_01`:** CI is currently RED on
a pre-existing `craft_memory` violation unrelated to the atlas, so suite figures
in recent records are local runs. `package-art.js --check` was run **during this
audit** and is clean.

There is **no** test that renders the whole atlas and asserts anything perceptual.
The only perceptual authority is the owner's physical iPhone, and the only
machine protection is the two byte-wise guards. That is the whole safety net.

---

## 10 · Audit notes and flagged uncertainties

- **Coordinate ambiguity in the defect register.** D-04's note says "267–330 × 750–800 is A-4-frozen", but the guard freezes only y ≤ 747. y 750–767 is rim band, y ≥ 768 is fully outside. **The guard is authoritative**; treat the register's prose as approximate and re-derive from `protDepth` before masking.
- **Golden vs adoption band for the volcano east cliff.** The registry rect is **752–824 × 260–470**; PROTECTION_PLAN quotes 752–820 × 272–436 as the WAR01 *adoption* band. ATLAS-L already resolved this in favour of the registry rect. Use the registry.
- **`south_strand_w` and `south_strand_e` overlap** on x 512–528 × y 810–870; a repaint there dirties both goldens.
- **`overlay_forge_smoke`** is packaged (3 frames) but appears in no layout `overlays` entry — an existing, free, already-approved map-life asset.
- **`props: []`** — the scatter-prop channel is fully implemented in the parser, the layer and the test, with seven approved prop PNGs shipped, and is entirely unused. It is the cheapest existing route to static map dressing, and it correctly hides at overview zoom.
- **Not confirmed from repo evidence** (carried from PROTECTION_PLAN): the log bridge's exact pixels; the western standing stone (attested, not located); whether the island label anchors' offset from their painted clusters is deliberate or drift.
