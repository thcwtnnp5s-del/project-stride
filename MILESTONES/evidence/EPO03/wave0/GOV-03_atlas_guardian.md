# GOV-03 — Atlas Protected-Zone Guardian (EPO03 wave 0)

Mechanics only. Permission for core/golden replacement is the producer's ADR
(D0033 landed at 9cabe4f while this was written). Facts gathered against
`Scripts/art/package-art.js` at 59c4723 (line numbers below are that file at
that commit; the atlas block is unchanged at 9cabe4f). Prior report
`MILESTONES/evidence/FMPO02/wave0/GOV-04_atlas_guardian.md` §1, §2, §5, §7, §8
remain true and are not repeated; §3's defect register is superseded by
`GAME_BIBLE/ART/exploration/FMPO02/ATLAS_REGION_LOG.md`.

Coordinates everywhere: 1024² atlas px (world px ÷ 6). Rects half-open unless
marked.

---

## 1. Blit order of `world/atlas_base.png` (package-art.js 1946–2657)

Every layer, in execution order. "clip" = the A-4 machinery applied to it.

| # | Lines | Layer | Writes (atlas px) | clip |
|---|---|---|---|---|
| 0 | 1946 | `base = new Raster(1024,1024)` | — | — |
| 1 | 1949–1960 | WMER02 outer ring, 12 pieces `r2_*_f0` | corners 128² at (0,0)(896,0)(0,896)(896,896); north_w/e 384×128 at (128,0)(512,0); west_n 128×512 (0,128); west_s 128×256 (0,640); east_n/s 128×384 (896,128)(896,512); south_w/e 384×128 (128,896)(512,896) | none |
| 2 | 1963–1967 | Inner ring: WMP03 `corner_nw_128` (128,128); WMP03 `strip_north_512x128` (256,128); WMER02 `corner_ne_conformed_v2` (768,128); WMER02 `cand_strip_west_f0` 128×512 (128,256); WMER02 `cand_strip_east_f0` 128×512 (768,256) | | none |
| 3 | 1968–1981 | WMP03 `corner_sw_128` edge-replicated (128,768); WMP03 `strip_south_512x128` (256,768); WMER02 `cand_corner_se_f3` (768,768) | | none |
| 4 | 1982–1983 | **The 512² master** `PWRF/world/whole_a_0.png` | (256,256)–(768,768) | none |
| 5 | 1986–1991 | Five static patches (WMER02 edits): `northfix2` 128² (640,128); `eaststriptop` 128×64 (768,256); `corridor` 128×75 (256,483); `southjoin` 256×60 (188,738); `roadjoin` 104×72 (216,480) | | none |
| 6 | 1995–2027 | Dither crossfade: `before = base.clone()` (1995); hash (1996–2000); seams y∈{128,256,768,896} (2008) and x∈{128,256,768,896} (2017), BAND 11, salts 1–4 | ±11 px of each lattice seam | none |
| — | **2037** | `const PROT = {x0:256,y0:256,x1:768,y1:768,band:20}` | | |
| — | **2038** | **`const approved = base.clone()` — the 559669e snapshot** | | |
| — | 2039–2046 | `protDepth`, `keepRepair` (salt 5) | | |
| 7 | 2059–2089 | WACUI bridges, 11, plain `png.blit`: north_west 288² (0,0); north_center 512×288 (256,0); north_east 256×288 (768,0); north_master 512×80 (256,224); nw_corner 220² (80,80); north_junction 512×84 (256,188); north_mtop 420×96 (300,232); west_mid 256×512 (48,256); sw 272×304 (0,592); south 512×128 (256,720); se 192² (704,704) | | unclipped here… |
| 8 | 2091–2104 | **Restore loop**: every PROT-rect pixel with `!keepRepair` ← `approved` | (256..768)² | …restored here |
| — | 2105 | `oceanTool = require(WACUI/tools/ocean_unify.js)` | | |
| 9 | 2106–2159 | WAR01 `adopt` ×4 (feather 8, salt 6, skips `protDepth>band`): east_join → 752–820 × 272–436; west_join → 236–276 × 360–584; south_strand → 128–528 × 810–870; south_strand_e → 512–800 × 810–870 | | rim-only |
| 10 | 2161–2197 | WACUI fix2 edge pieces ×7 (`keepRepair` clip): d1_nw 256×272 (176,24); d1c_nw 300² (0,0); d4_west 300×120 (0,544); d5_se 200×152 (684,684); d2_north 430×104 (290,236); d2b_floe 240×160 (240,140); d3_ne 160×260 (740,40) | | rim dither |
| 11 | 2199–2247 | REM01 regions ×7 (`regions_manifest.json`, mask dither, salts 8–14, `keepRepair` clip): r1_ice 464×320 (560,0); r2_verge 184×328 (152,528); r3_sketch 200×304 (0,720); r3b_band 112×224 (72,800); r4_coast 192×204 (420,820); r5_nwice 230×176 (166,124); r3c_topedge 176×156 (0,780) | | rim dither |
| 12 | 2249–2265 | NW-ice red-fleck despeckle | 270–410 × 120–160 | none (outside) |
| 13 | 2267–2320 | Treeline confetti despeckle | 245–399 × 240–275 | `protDepth>band` skip |
| 14 | 2322–2371 | Green-confetti cliff cleanup | 705–761 × 235–303 | golden + core excluded |
| 15 | 2373–2392 | Red-dash trail despeckle | 275–404 × 758–816 | none |
| 16 | 2394–2408 | Stamp belts (`iteration_02/tools/stamp_belts.js`, salt 15): B1_treeline 250–393×238–275; A1_westverge 200–275×278–470; C1_swblock_east 282–336×874–964; C2_swblock_south 122–305×946–1004; C5_swblock_west 98–142×872–964 | | protDepth passed in |
| 17 | **2410–2479** | **FMPO02_ATLAS_REGIONS** (`FMPO02/out/atlas/manifest.json`, 12 accepted, salts 20–32, alpha-0 skip, `keepRepair` clip): W1, W2, W3, N1, N2, NB1, S1, S2, N3, NB2, NB3, GAP | | rim dither |
| 18 | 2481–2497 | Flotsam fills: 886–910×622–662 ← (−40,0); 866–906×760–784 ← (+36,0) | | none |
| 19 | 2499–2529 | Ghost-sail restore: 748–796 × 844–906 re-blitted from WAR01 `south_strand_e_f0.png` (rows ≤879 outside the sail box), sail box + rows ≥880 ← (0,+66) | | none |
| 20 | 2531–2549 | Ocean conform: `preConform = base.clone()` (2547); `oceanTool.unify(base, remWater.EXTRA_RECTS)` (2548); `remWater.shoalRamp` salt 7 (2549) | all deep-teal water | water only |
| 21 | 2551–2591 | Sea-ice sage cleanup (predicate g>r+40 && g>b+8) | 620–790 × 90–240 | none |
| G1 | **2593–2616** | **Protected-interior drift guard**: PROT rect, `protDepth>band`, RGB ≠ `approved` and not deep teal → throw | (276..748)² effective | |
| G2 | **2618–2655** | **Landmark golden guard**: 15 goldens vs `REM01/goldens/<id>.png`, deep teal exempt → throw | | |
| E | 2657 | `emit('world/atlas_base.png', encode(base))` | | |

### 1a. Where the EPO03 core recomposition layer goes

The brief says "before the approved snapshot so its accepted regions become the
protected interior of record". Mechanically that must be read as **before the
snapshot the guard compares against**, not as "before line 2038". Inserting
the layer at line 2036 (ahead of the existing snapshot) is wrong for three
concrete reasons, each measurable on the table above:

1. **Substrate mismatch.** At line 2038 the base is the 559669e state — no
   bridges, adopts, edge fixes, REM01 regions, despeckles, belts or FMPO02
   regions. Every EPO03 crop is cut from the *current shipped* composite, so a
   mask's ramp zone (0 < m < 255) would dither the generation against terrain
   that no longer exists, and those old pixels would then be frozen as
   "approved".
2. **Clobbering outside the PROT rect.** `protDepth` is 0 outside
   256–768², so every later layer (rows 7–19) writes there unconditionally.
   Six of the eight candidate zones lie wholly or partly outside the rect;
   an EPO03 layer placed at 2036 would be overwritten by west_mid, sw, south,
   d4_west, r3_sketch, S1/S2, the belts, the ghost-sail restore, etc.
3. **Rim re-dither.** Inside the 20 px rim, `keepRepair` lets every later
   layer win with probability 1 − d/21 — the 50/50 speckle column that is the
   standing finding in `ATLAS_REGION_LOG.md` ("the A-4 rim cannot carry a
   content change"), in reverse.

**Precise insertion point:** between **line 2529** (closing `}` of the
ghost-sail block) and **line 2531** (`// Deterministic open-ocean conform`).
At that point the base *is* the shipped composite minus the conform, so the
crop source and the substrate are the same image; nothing content-bearing runs
after it except the water-only conform and the sage predicate (gated below).
Then re-take the snapshot as the block's last statement. Two edits outside
the block:

- line 2038: `const approved = base.clone();` → `let approved = base.clone();`
  (the legacy restore at 2091 still needs the 559669e snapshot);
- line 2596–2598: the guard loops `PROT.y0..PROT.y1` / `PROT.x0..PROT.x1` →
  loop `0..1024` on both axes (it already `continue`s on
  `protDepth<=band`, so with the override below this extends protection to
  every EPO03-written pixel anywhere on the canvas at 1 M iterations, ~ms);
- line 2039 `protDepth`: add a first line
  `if (claimed[y * 1024 + x]) return PROT.band + 1;` and declare
  `const claimed = new Uint8Array(1024 * 1024);` immediately before it.
  `claimed` is empty until the EPO03 block runs, so rows 7–19 behave exactly
  as today; after it, the sage pass, the drift guard and any future layer
  inserted after the block see EPO03 pixels as hard core.
- line ~2561 (sage loop body, after `const i = base.idx(x, y);`): add
  `if (protDepth(x, y) > PROT.band) continue;` — the same idiom rows 13/14
  already use — so a replaced NE shelf is not eroded by a predicate written
  for N3's seam debris.

Code shape (insert after line 2529):

```js
  // ------------------------- EPO03_ATLAS_REGIONS (core recomposition)
  //
  // D0033: the approved atlas is a state the owner may replace. Regions here
  // are the owner-authorised replacement of that state, so — unlike every
  // layer above — they are NOT clipped against the A-4 core or its rim and
  // may overwrite a landmark golden they DECLARE. What makes the new state
  // protected: every pixel this block writes is marked `claimed`, protDepth
  // treats a claimed pixel as hard core, `approved` is re-snapshotted after
  // the block, and the guards below compare against that. Five manifests,
  // one per producer team, in fixed order (later wins where masks overlap):
  // landmarks last so a re-authored landmark supersedes regional terrain.
  {
    const EPO03 = path.join(EXPLORE, 'EPO03', 'out', 'atlas');
    const MANIFESTS = ['manifest_north.json', 'manifest_south.json',
      'manifest_west.json', 'manifest_east.json', 'manifest_landmarks.json'];
    const reg = JSON.parse(
      fs.readFileSync(path.join(REM01, 'landmark_registry.json'), 'utf8'));
    const seenIds = new Set(), seenSalts = new Set(), shipped = [];
    reauthorized = new Set(); // declared at file scope for the golden guard
    for (const file of MANIFESTS) {
      const mf = path.join(EPO03, file);
      if (!fs.existsSync(mf)) {
        throw new Error(`EPO03 atlas: ${file} missing — every team commits ` +
          `{"regions":[]} at kickoff so --check stays honest`);
      }
      const manifest = JSON.parse(fs.readFileSync(mf, 'utf8'));
      for (const region of manifest.regions) {
        if (region.status !== 'accepted') {
          throw new Error(`EPO03 atlas region ${region.id} (${file}): status ` +
            `'${region.status}' — only accepted regions may ship`);
        }
        if (seenIds.has(region.id)) throw new Error(`EPO03 atlas: duplicate region id ${region.id}`);
        if (seenSalts.has(region.salt) || region.salt < 40) {
          throw new Error(`EPO03 atlas region ${region.id}: salt ${region.salt} — ` +
            `must be unique across all five manifests and >= 40 (1-15 legacy, 20-32 FMPO02)`);
        }
        seenIds.add(region.id); seenSalts.add(region.salt);
        const gen = png.load(path.join(EPO03, `${region.id}.png`));
        const mask = png.load(path.join(EPO03, `${region.id}_mask.png`));
        if (gen.width !== region.w || gen.height !== region.h ||
            mask.width !== region.w || mask.height !== region.h) {
          throw new Error(`EPO03 atlas region ${region.id}: expected ` +
            `${region.w}x${region.h}, got gen ${gen.width}x${gen.height}, ` +
            `mask ${mask.width}x${mask.height}`);
        }
        // A golden the mask touches must be declared in `reauthorizes`;
        // the golden is then re-extracted in the same commit (§2).
        const declared = new Set(region.reauthorizes || []);
        for (const lm of reg.landmarks) {
          if (declared.has(lm.id)) continue;
          for (let sy = 0; sy < region.h; sy++) {
            for (let sx = 0; sx < region.w; sx++) {
              const tx = region.x + sx, ty = region.y + sy;
              if (tx < lm.x || ty < lm.y || tx >= lm.x + lm.w || ty >= lm.y + lm.h) continue;
              if (mask.data[mask.idx(sx, sy)] !== 0) {
                throw new Error(`EPO03 atlas region ${region.id}: mask touches ` +
                  `golden '${lm.id}' at (${tx},${ty}) but does not declare it in reauthorizes`);
              }
            }
          }
        }
        for (const id of declared) reauthorized.add(id);
        for (let sy = 0; sy < region.h; sy++) {
          for (let sx = 0; sx < region.w; sx++) {
            const m = mask.data[mask.idx(sx, sy)];
            if (m === 0) continue;
            const tx = region.x + sx, ty = region.y + sy;
            if (tx < 0 || ty < 0 || tx >= 1024 || ty >= 1024) continue;
            if (m < 255 && hash(tx, ty, region.salt) >= m / 255) continue;
            const si = gen.idx(sx, sy);
            if (gen.data[si + 3] === 0) continue;
            // No protDepth / keepRepair clip: this layer IS the new approved state.
            const ai = base.idx(tx, ty);
            for (let k = 0; k < 4; k++) base.data[ai + k] = gen.data[si + k];
            claimed[ty * 1024 + tx] = 1;
          }
        }
        shipped.push(`${file.replace(/^manifest_|\.json$/g, '')}/${region.id}`);
      }
    }
    if (shipped.length) console.log(`  atlas EPO03 regions: ${shipped.join(', ')}`);
    // The interior of record is now the EPO03-inclusive composite.
    approved = base.clone();
  }
```

Manifest entry shape (same as FMPO02 plus two fields):
`{ id, x, y, w, h, salt (>=40, globally unique), status, job, seed, atlas,
review, team, reauthorizes: ["south_strand_w", ...] }`. Pending work lives in
each team's `src/atlas/regions_<team>.json`, never in a manifest (the
FMPO02 discipline: a manifest entry exists only after the loop's ACCEPT).

Golden-guard change (row G2, line 2634): for `lm.id ∈ reauthorized`, the
golden must have been re-extracted in the same commit; nothing else changes.
See §2 for how the re-extraction gets past the guard.

`GAME_BIBLE/ART/exploration/EPO03/tools/atlas-mask.js` is at present a
byte-identical copy of FMPO02's. For a core/golden region it needs two flags on
`buildMask(spec)` → `protectFactor(tx, ty, opts)`: `coreAuthor: true` skips
the `d > PROT.band` return and the `rimBlock` clause; `reauthorizes: [ids]`
skips those entries in the GOLDENS keepout loop. Everything else (one-sided
ramps, ±60 % width wander, 24/32 px, agreement grading) stays as §5 describes.

---

## 2. Re-extracting a landmark golden, and golden × candidate-zone overlaps

**Tool:** `node GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/tools/extract_goldens.js`
— reads the shipped `assets/art/v1/world/atlas_base.png`, crops **all 15**
registry rects into `WORLD_ATLAS_REMASTER_01/goldens/<id>.png`. Two precedents
for partial re-authorization (golden updated from the generation through its
mask, not from the composite): `tools/reauthorize_strand_w.js`,
`iteration_02/tools/reauthorize_strand_dots.js`.

**The catch:** the golden guard throws *before* `emit` (2657), so a composite
that changes a golden is never written to disk and `extract_goldens.js`
would re-extract the old one. Cheapest honest mechanic (no guard bypass, no
new flag on `--check`): dump the pre-guard composite to a scratch path and
extract from that, then rebuild green.

Add before line 2593: `if (process.env.ATLAS_DUMP) png.save(process.env.ATLAS_DUMP, base);`
(3 lines with a comment). Then:

```js
// node extract_one.js <composite.png> <goldenId>...  (Scripts/art/png.js API)
const path = require('path'), fs = require('fs');
const png = require(path.resolve('Scripts/art/png.js'));
const REM01 = path.resolve('GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01');
const reg = JSON.parse(fs.readFileSync(path.join(REM01, 'landmark_registry.json'), 'utf8')).landmarks;
const atlas = png.load(process.argv[2]);
for (const id of process.argv.slice(3)) {
  const lm = reg.find((l) => l.id === id);
  png.save(path.join(REM01, 'goldens', `${id}.png`), png.crop(atlas, lm.x, lm.y, lm.w, lm.h));
  console.log(`re-extracted ${id} ${lm.w}x${lm.h} @ (${lm.x},${lm.y})`);
}
```

Sequence per re-authorization commit: `ATLAS_DUMP=<scratch>/atlas_pre_guard.png node Scripts/art/package-art.js`
(fails on the golden — expected) → `node extract_one.js <scratch>/atlas_pre_guard.png south_strand_w`
→ `node Scripts/art/package-art.js` (green) → `--check` → stage the golden(s),
the manifest, the region PNGs and `assets/art/v1/world/atlas_base.png`
explicitly (G-8). The golden's git diff is the authorization trail.

### Golden overlaps per candidate zone (rect ∩ zone; "keepout" = within the 20 px mask keepout only)

| Zone | Goldens (rect ∩ zone, px) | Also in the way |
|---|---|---|
| **South band** 0–1024 × 780–1024 | south_strand_w 128–528×810–870 **FULL** (24,000); south_strand_e 512–800×810–870 **FULL** (17,280); flock_south keepout | S1, S2 (FMPO02); r3_sketch, r3b_band, r4_coast, r3c_topedge (REM01); belts C1/C2/C5; red-dash despeckle; ghost-sail + flotsam rects |
| **NE ice shelf** 480–800 × 0–300 | frostmere_north_wall 480–560×256–276 (1,600); east_watchtower_flank 744–752×273–300 (216); volcano_east_cliff 752–800×260–300 (1,920) | **HARD CORE 480–748 × 276–300** (Frostmere cirque 396–565×258–380); N3, NB2, NB3 (FMPO02); r1_ice (REM01); bridges north_center/north_east/north_master/north_mtop; d3_ne; green-confetti pass; sage pass |
| **West road loop** 0–260 × 460–630 | west_caravan_road **FULL** (10,240); caravan_corridor **FULL** (1,196); stag_box **FULL** (616); roadjoin_corridor_west 216–260×480–558 (3,432) | patches roadjoin (216,480) + corridor (256,483); west_join adopt 236–276; d4_west; r2_verge; belt A1; W1/W3 edges; A-4 rect 256–260 |
| **Far-west wall** 0–70 × 540–780 | none | W3 (FMPO02) 8–200×596–786; r3_sketch top; d4_west; sw bridge |
| **Core forest west face** 236–320 × 380–580 | roadjoin_corridor_west 236–276×480–558 (3,120); west_caravan_road 236–256×495–575 (1,600); caravan_corridor 236–245×506–532 (234) | **HARD CORE 276–320**; rim 256–276; west_join adopt; west_mid bridge; A1 belt; W1 mask ends at 256 |
| **Core canopy/snow treeline** 256–400 × 230–290 | frostmere_north_wall keepout only (rect starts x 400) | **HARD CORE 276–400 × 276–290**; rim; B1 belt 250–393×238–275; treeline despeckle; N2 bottom ramp (to 236); GAP right edge on x 256; north_master/north_junction/north_mtop; d2_north |
| **SW corner** 0–260 × 760–1024 | south_strand_w 128–260×810–870 (7,920) | S1, W3 bottom; r3_sketch, r3b_band, r3c_topedge; belts C2/C5; A-4 rect sliver 256–260×760–768 |
| **East ocean** 770–1024 × 300–1024 | wanderers_isles_w **FULL** (3,760); wanderers_isles_e **FULL** (2,890); volcano_east_cliff 770–824×300–470 (9,180); south_strand_e 770–800×810–870 (1,800); east_watchtower_flank + far_isles keepout only | east_join adopt 752–820×272–436; flotsam fills; ghost-sail 748–796×844–906; conform EXTRA_RECTS (east-bay x=636 edge is west of zone) |

Cinder_skerries (920–1000×175–250), far_isles (940–995×205–285), ne_iceberg
(974–991×210–225) sit in no candidate zone.

---

## 3. Coordinate gazetteer (`assets/content/v1/atlas/atlas_layout.json`, schema 5, scale 6)

Atlas px = world px ÷ 6. Markers draw at native size ×6 on screen; a 20×20
marker with anchor (10,10) covers ±10 atlas px around its point.
"HARD CORE" = inside 276–748²; "rim" = 256–276 band; else outside.

### Locations (`locations[]`, hitRadius 72 world = 12 atlas; kind marker 20×20 anchor 10,10)

| id | atlas (x,y) | disc | core | zone |
|---|---|---|---|---|
| location.havens_rest | (456, 521) | 444–468 × 509–533 | HARD CORE | — |
| location.whispering_woods | (383, 509) | 371–395 × 497–521 | HARD CORE | — |
| location.stonefall_mine | (566, 496) | 554–578 × 484–508 | HARD CORE | — |
| location.forgotten_hollow | (561, 551) | 549–573 × 539–563 | HARD CORE | — |
| location.frostmere | (498, 311) | 486–510 × 299–323 | HARD CORE | — (disc top row 299 abuts NE-shelf zone bottom 300) |

### Named landmarks (`landmarks[]`, all `world/marker_landmark` 20×20 anchor 10,10)

| id | name | tier | atlas (x,y) | core | zone |
|---|---|---|---|---|---|
| rimewatch | Rimewatch | future | (639, 296) | HARD CORE | **NE ice shelf** |
| emberhold | Emberhold | future | (743, 288) | HARD CORE | **NE ice shelf** |
| glasslake | Glasslake | future | (461, 334) | HARD CORE | — |
| the_taiga | The Longwood | future | (316, 296) | HARD CORE | — (6 px below canopy/treeline zone) |
| deepwood_shrine | Deepwood Shrine | future | (304, 556) | HARD CORE | **core forest west face** |
| greenwatch | Greenwatch | future | (286, 431) | HARD CORE | **core forest west face** |
| wolfwood | Wolfwood | future | (334, 686) | HARD CORE | — |
| tern_isles | Tern Isles | future | (711, 524) | HARD CORE | — |
| saltreach_light | Saltreach Light | future | (724, 628) | HARD CORE | — |
| amberfield | Amberfield | future | (481, 628) | HARD CORE | — |
| marshlight | Marshlight | future | (508, 708) | HARD CORE | — |
| reedmouth | Reedmouth | future | (606, 686) | HARD CORE | — |
| sunken_rows | Sunken Rows | future | (406, 711) | HARD CORE | — |
| stone_bridge | Millbridge | minor | (499, 556) | HARD CORE | — |
| ferry_crossing | Ferry Crossing | minor | (556, 606) | HARD CORE | — |
| worldspine | The Worldspine | future | (156.7, 333.3) | outside | — (W2 region) |
| frozen_shelf | The Frozen Shelf | future | (444.7, 176.3) | outside | — (N2 region) |
| cinder_skerries | Cinder Skerries | future | (824.7, 181.3) | outside | — |
| wanderers_isles | Wanderer's Isles | future | (829.7, 461.3) | outside | **east ocean** |
| sunward_strand | Sunward Strand | future | (511.3, 859.7) | outside | **south band** (inside south_strand_w/e seam) |
| wayfarers_pass | Wayfarer's Pass | future | (186.7, 541.7) | outside | **west road loop** (inside west_caravan_road golden) |
| white_reach | The White Reach | future | (600, 60) | outside | **NE ice shelf** |
| far_isles | The Far Isles | future | (970, 250) | outside | — (50 px north of east-ocean zone) |

### Scatter props (`props[]`, native size; footprint = anchor-relative)

| asset | anchor atlas | native | footprint (atlas) | core | zone |
|---|---|---|---|---|---|
| env/prop_rimespire | (824, 156) | 48×72 | 800–848 × 85–157 | outside | — |
| env/prop_lanterngard | (66, 424) | 72×56 | 30–102 × 369–425 | outside | — (W2) |
| env/prop_black_gable | (786, 786) | 56×52 | 758–814 × 735–787 | outside | **south band** (rows 780–787) + **east ocean** |
| env/prop_fairy_castle | (335, 452) | 31×39 | 320–351 × 414–453 | HARD CORE | abuts core-forest-west-face east edge (x 320) |
| env/prop_storm_house | (218, 900) | 25×21 | 206–231 × 880–901 | outside | **south band** + **SW corner** (inside S1) |
| env/prop_ice_tower | (468, 177) | 48×80 | 444–492 × 98–178 | outside | **NE ice shelf** (x 480–492 sliver) |

### Routes (`routes[]`, polyline via-points; endpoints are the locations above)

| route | via (atlas) | zone |
|---|---|---|
| havens_rest → whispering_woods | (421,518) | — |
| havens_rest → stonefall_mine | (506,518) (541,506) | — |
| whispering_woods → stonefall_mine | (436,488) (506,478) (551,488) | — |
| whispering_woods → forgotten_hollow | (406,556) (456,576) (521,571) | — |
| stonefall_mine → frostmere | (556,461) (539,416) (518,366) | — |

All five routes and all their via-points lie inside the hard core; none enters
a candidate zone. Rumors (`rumors[]`, not asked but on the map): eastern_city
(716,606), lower_gallery (574,488), northern_range (686,326) — all hard core,
no zone.

### Overlays that sit in a candidate zone (40 total; sprite top-left, native w×h)

NE ice shelf: overlay_volcano (668,284) 64², overlay_redwyrm (700,240) 96×64,
overlay_yeti3 (600,190) 16×17. East ocean: overlay_redwyrm_breath (780,300)
128×64, overlay_stormdrake_breath (832,688) 128×56, overlay_whale (808,598)
38×41, overlay_ship (788,648) 15×20. West road loop: overlay_stag (156,493)
28×22 — the `stag_box` golden is exactly its ground; overlay_caravan (225,512)
20×19 — `caravan_corridor` is its ground. Core forest west face:
overlay_forest_mist (301,436) 96×48, overlay_fairy_motes (292,424) 32². South
band + SW corner: overlay_storm_lightning (194,818) 48×64. Overlays composite
at runtime and never trip the guards, but the ground under a grounded creature
(stag, caravan, yeti, bear, wolfpair) is what its golden or its region must
keep plausible.

### Zone-conflict list (what must stay in place, by zone)

- **NE ice shelf:** Rimewatch and Emberhold markers (both hard core), White
  Reach marker, volcano + redwyrm + yeti3 overlay grounds, prop_ice_tower's
  right sliver, three goldens, **and 44 rows of the hard core incl. the
  Frostmere north wall**. Recommend the producer's rect stop at y=256 (or 236,
  the frostmere_north_wall keepout) unless Frostmere's north wall is the point.
- **South band:** Sunward Strand marker, prop_black_gable bottom rows,
  prop_storm_house, storm_lightning ground, both strand goldens whole,
  flock_south's keepout.
- **West road loop:** Wayfarer's Pass marker, stag and caravan grounds
  (stag_box, caravan_corridor goldens), west_caravan_road + roadjoin_corridor_west
  goldens, the two static road patches.
- **Core forest west face:** Deepwood Shrine and Greenwatch markers, forest
  mist + fairy motes grounds, fairy castle footprint on its east edge, three
  goldens' western slivers, 44 columns of hard core.
- **Core canopy/snow treeline:** The Longwood marker 6 px below the rect;
  B1 belt and treeline despeckle are both superseded under a mask.
- **SW corner:** prop_storm_house, storm_lightning ground, south_strand_w's
  west 132 columns.
- **East ocean:** Wanderer's Isles marker, whale/ship/breath grounds, both
  isle goldens whole, the volcano cliff's lower half, the strand's east end,
  prop_black_gable's east half.
- **Far-west wall:** nothing named; only W3/r3_sketch/d4_west content.

---

## 4. Timing, collision, current guard results

Measured on this Dell (node v24.18.0, Git Bash, working tree at 59c4723 +
untracked sibling work):

| Run | Wall | Exit | Output |
|---|---|---|---|
| `node Scripts/art/package-art.js` | **6.8 s** | 0 | "wrote 1779 files to assets/art/v1/" |
| `node Scripts/art/package-art.js --check` | **6.7 s** | 0 | "1779 files up to date" |

The atlas block is a small share of that; most of the time is the 1,779-file
sprite pipeline. The build is fully deterministic: two builds produce
byte-identical trees.

**What a build writes:** every emitted file under `assets/art/v1/` (1,779
paths, `fs.writeFileSync` unconditionally, even when unchanged — `emit()`,
line 48–61) plus one generated Dart file
`lib/ui/icons/sprite_footprints.dart` (line 36, written at 3643). `--check`
writes nothing (line 6, 52–57) and only pushes `missing:`/`stale:` problems.
Neither mode writes to `GAME_BIBLE/`, `.gitignore`, or any manifest. (The
`.gitignore` EPO03 block that appeared mid-run came from a sibling worker, not
from packaging.)

**Would two concurrent runs collide?**
- Two `--check`s: no — both read-only.
- Build + build, or build + `--check`: **yes, benignly for the bytes but not
  for the verdict.** Both builds write the same 1,779 paths with identical
  bytes, but a reader that opens a file mid-write sees a truncated PNG: the
  concurrent `--check` reports a false `stale:`, and any tool that reads the
  shipped atlas (`extract_goldens.js`, `atlas-review.js`, `atlas-qa.js`,
  the `png.load` of `whole_a_0.png` is a source and is safe) can decode
  garbage. Also, the build reads every team's manifest: a manifest saved
  half-written or with a non-`accepted` entry throws for *every* team's run.
  Rule for producers: **one packaging run at a time per working tree**
  (a `.package-art.lock` or just serialize in the coordinator); teams write
  manifests atomically (temp + rename) and never put a pending region in one.
  Separate git worktrees do not share `assets/art/v1/` and are safe to build
  in parallel.

**Current guard results (both runs):** protected-interior drift **0 px** (no
throw); all **15 landmark goldens byte-held** (no throw); stamp belts
`B1_treeline 15, A1_westverge 14, C1_swblock_east 6, C2_swblock_south 7,
C5_swblock_west 3`; FMPO02 regions shipped `W1, W2, W3, N1, N2, NB1, S1, S2,
N3, NB2, NB3, GAP`; sea-ice sage cleanup 342 px. `--check` green: 1779 files
up to date.

---

## 5. The mask/dither method and the phone-FOV review, for reuse

**Mask (`FMPO02/tools/atlas-mask.js`, copied verbatim into `EPO03/tools/`).**
A region is `{x,y,w,h}` crop origin + size on the 1024² atlas, an authored
`rect` in crop coords (half-open; a coordinate outside the crop means "canvas
edge, ramp 0"), four `ramps` (24 px on a free edge, 32 px where the boundary
crosses a texture change) and a unique integer `salt`. The mask is a
grayscale PNG the size of the crop: 255 = take the generation, 0 = keep the
base, in between = the probability that package-art.js's shared hash
`hash(x,y,salt)` selects the generation pixel — a **dither-SELECT, never an
average** (A-2), so every output pixel is one of the two images' own pixels.
Each ramp is **one-sided**, anchored with alpha 0 exactly on the authored-rect
edge (which must equal the inpaint rectangle's edge, so the inpaint cut can
never be the visible line) and rising inward; its **width** is jittered ±60 %
by a 24 px-cell value noise (`wander`, per-edge salt offsets 0–3) so the
half-alpha contour wanders ±10 px and no straight lattice line exists. Where
the generation and the crop are locally dissimilar (mean |ΔRGB| over a 5×5 box
above 12, fully by 45) the ramp **commits** wholly to whichever side it already
favours, so a join between different terrains is drawn as an edge instead of
sprayed as salt-and-pepper; where they agree it dithers freely and vanishes.
`protectFactor` forces alpha to 0 inside the A-4 core beyond its 20 px rim
(and in the rim too when `rimBlock` is set — the standing finding: the rim's
`keepRepair` dither re-mixes the master in at 50 % regardless of the mask, so
a content change there always reads as a speckled column) and within 20 px of
any registry golden, ramping back over a further 24 px so a keepout never
prints the golden's rectangle. The CLI (`node atlas-mask.js <id>`) grades by
agreement when `out/atlas/<id>.png` and `src/atlas/<id>_crop.png` both exist,
else emits the geometric ramp. Companion checks: `atlas-verify.js <id>
<candidate.png>` (size match; every pixel the mask does not authorize is
byte-identical to the crop — 0 px outside is the bar); `atlas-qa.js <id>` on
the *shipped* composite (repeated identical 10×10 sprite blocks within 40 px;
orphan 1–2 px flecks). Bridges (NB1/NB2/NB3 pattern) are crops cut from the
composite *after* the two regions they join have landed, so both languages sit
frozen in the margins.

**Phone-FOV review (`atlas-review.js <id> [before|after]`).** Three PNGs into
`review/atlas/`: `<id>_<tag>_full.png` — the whole 1024² atlas at ×1 (does it
read as one painting at arm's length); `<id>_<tag>_x2.png` — the crop plus 40
px of untouched perimeter on every side, `png.scale(…, 2)` (does any boundary,
dither column or repair footprint read); `<id>_<tag>_fov.png` — a **197 × 426
atlas-px crop at ×1**, centred on the crop's centre and clamped to the canvas.
197×426 is the iPhone 393×852 pt viewport at the atlas's opening zoom
(`AtlasZoom.initial = 2/scale`: native ×2, so 1 atlas px = 2 screen pt); judge
it magnified ×2 (nearest-neighbour) to see what the owner sees on first open.
The loop per region is BEFORE → intent → generate → composite → guards → full
+ ×2 + FOV → explicit verdict → next region; the physical iPhone remains the
final authority.
