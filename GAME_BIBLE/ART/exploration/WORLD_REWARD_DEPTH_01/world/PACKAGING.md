# WORLD_REWARD_DEPTH_01 — world atlas package (stream E)

```
STATUS: ROUND 2 (fix round) COMPLETE. AUTHOR-ACCEPTED, AWAITING SECOND
INDEPENDENT QA VERDICT (M-04, M-05). Nothing here is in assets/. Nothing committed.
Everything is native pixel size. The app displays at x2 nearest-neighbour;
multiply every native coordinate below by 2 for world/display space.
```

Round 1 verdict: `QA_VERDICT_ROUND1.md` (**FAIL** on composite continuity).
Round 2 changes and evidence: `README.md` §10–§13.
Blind set for the second verdict: `qa/blind_r2/`, key `tools/blind_key_r2.json`.

Source folders for `Scripts/art/package-art.js` emit lines (the integration
lead adds them): `GAME_BIBLE/ART/exploration/WORLD_REWARD_DEPTH_01/world/out/world/`
and `.../out/env/`.

---

## 1. World size

| | Native | World px (scale 2) |
|---|---|---|
| **Recommended** | **768 x 1376** | **1536 x 2752** |

`atlas_layout.json` `world` becomes `{ "width": 1536, "height": 2752 }`.
`scale` stays 2. All five playable locations and all five routes keep their
current coordinates unchanged.

### `base.tiles`

```json
"tiles": [
  { "asset": "world/atlas_base",      "x": 0,   "y": 0,   "width": 384, "height": 688 },
  { "asset": "world/atlas_east",      "x": 384, "y": 0,   "width": 384, "height": 688 },
  { "asset": "world/atlas_south",     "x": 0,   "y": 688, "width": 384, "height": 688 },
  { "asset": "world/atlas_southeast", "x": 384, "y": 688, "width": 384, "height": 688 }
]
```

Tile rects above are **native**. If `AtlasLayout` expects world px, multiply by 2.

**Fallback**, if the second QA verdict still fails the composite: drop the
`atlas_east` and `atlas_southeast` rows and set `world` to
`{ "width": 768, "height": 2752 }` (base + south only). Round 2 evidence says
this should not be needed — see README §13.

---

## 2. Files

All measured: tiles fully opaque, `nonOpaque=0`, `semi=0`, `teal=0`, 0 white
border, bounds = full canvas. All cutouts keyed (alpha strictly 0 or 255),
no `#58d6c0`.

### `out/world/`

| Source file | Proposed shipped key | Native | Round 2 status |
|---|---|---|---|
| `atlas_east_384x688.png` | `world/atlas_east` | 384x688 | unchanged from round 1 |
| `atlas_south_384x688.png` | `world/atlas_south` | 384x688 | unchanged from round 1 |
| `atlas_southeast_384x688.png` | `world/atlas_southeast` | 384x688 | **REPLACED** — now seed 137 |
| `marker_haven_20x20.png` | `world/marker_haven` | 20x20 | **re-conformed mid-tone** (was white-filled) |
| `marker_wilds_20x20.png` | `world/marker_wilds` | 20x20 | unchanged |
| `marker_worksite_20x20.png` | `world/marker_worksite` | 20x20 | **dirt pad keyed off + mid-tone** |
| `marker_perilous_20x20.png` | `world/marker_perilous` | 20x20 | unchanged |
| `marker_landmark_20x20.png` | `world/marker_landmark` | 20x20 | **REPLACED** — three boulders (was the "cauldron" cairn) |
| `landmark_old_watch_64x80.png` | `world/landmark_old_watch` | 64x80 | packaged, not placed — §5 |
| `landmark_standing_stones_64x48.png` | `world/landmark_standing_stones` | 64x48 | **grass disc keyed off**; packaged, not placed |
| `landmark_ferry_crossing_64x48.png` | `world/landmark_ferry_crossing` | 64x48 | packaged, not placed — §5 |
| `landmark_stone_bridge_64x40.png` | `world/landmark_stone_bridge` | 64x40 | packaged, not placed — §5 |

### `out/env/`

| Source file | Proposed shipped key | Native | Anchor (ax, ay) | Placed? |
|---|---|---|---|---|
| `prop_sea_stack_48x56.png` | `env/prop_sea_stack` | 48x56 | 24, 50 | yes |
| `prop_crag_48x40.png` | `env/prop_crag` | 48x40 | 24, 38 | yes |
| `prop_dune_64x32.png` | `env/prop_dune` | 64x32 | 32, 25 | yes |
| `prop_treeline_strip_96x32.png` | `env/prop_treeline_strip` | 96x32 | 48, 21 | once only |
| `prop_reedbed_strip_96x32.png` | `env/prop_reedbed_strip` | 96x32 | 48, 23 | **no** — §6 |
| `prop_ridge_strip_96x40.png` | `env/prop_ridge_strip` | 96x40 | 48, 32 | **no** — §6 |
| `prop_treeline_strip_v_32x96.png` | `env/prop_treeline_strip_v` | 32x96 | 16, 95 | **no** — §6 |

Anchor convention: `(x, y)` is the map point the object stands at; `(ax, ay)`
is the pixel inside the sprite that lands there — bottom-centre of the measured
opaque bounds.

**No overlays are delivered.** See §9.

---

## 3. Existing props reused (already shipped, no new art)

`prop_lone_oak` (48x48), `prop_pine_clump` (48x56), `prop_boulders` (48x40),
`prop_hedgerow` (48x32), `prop_dead_tree` (40x48), `prop_cairn` (32x40).
Nothing about them changes.

---

## 4. Proposed `landmarks` list for `atlas_layout.json`

Schema per `MILESTONES/WORLD_REWARD_DEPTH_01.md` §7. Coordinates are **world px**
(native x 2). All six are **non-interactive**: no hit target, no panel.

```json
"landmarks": [
  { "id": "landmark.old_watch",       "name": "Old Watch",       "x": 1238, "y": 430,
    "tier": "minor",
    "marker": { "asset": "world/marker_landmark", "width": 20, "height": 20, "anchorX": 10, "anchorY": 10 } },
  { "id": "landmark.nine_stones",     "name": "The Nine Stones", "x": 1152, "y": 690,
    "tier": "minor",
    "marker": { "asset": "world/marker_landmark", "width": 20, "height": 20, "anchorX": 10, "anchorY": 10 } },
  { "id": "landmark.stone_bridge",    "name": "Millbridge",      "x": 380,  "y": 2056,
    "tier": "minor",
    "marker": { "asset": "world/marker_landmark", "width": 20, "height": 20, "anchorX": 10, "anchorY": 10 } },
  { "id": "landmark.ferry_crossing",  "name": "Ferry Crossing",  "x": 340,  "y": 2256,
    "tier": "minor",
    "marker": { "asset": "world/marker_landmark", "width": 20, "height": 20, "anchorX": 10, "anchorY": 10 } },
  { "id": "landmark.drowned_harbour", "name": "Drowned Harbour", "x": 1368, "y": 2176,
    "tier": "minor",
    "marker": { "asset": "world/marker_landmark", "width": 20, "height": 20, "anchorX": 10, "anchorY": 10 } },
  { "id": "landmark.far_town",        "name": "Beyond the known roads", "x": 340, "y": 2656,
    "tier": "future",
    "marker": { "asset": "world/marker_landmark", "width": 20, "height": 20, "anchorX": 10, "anchorY": 10 } }
]
```

**Drowned Harbour moved** from (1378, 2256) to (1368, 2176) — the round-2
south-east tile draws its harbour and beacon in a different place. Read off a
32 px grid over the new tile (`qa/_r2_grid_se.png`).

**Names remain proposals, not decisions.** "Old Watch", "Ferry Crossing" and
"Drowned Harbour" come from the brief; "The Nine Stones", "Millbridge" and the
far town's label are mine and belong to the World Designer, not to an art
stream. Flagged `UNRESOLVED` for the lead (`RULES.md` G-3).

### Marker glyphs for the five playable places

`world/marker_<kind>` is drawn **under the existing ring chrome**. Glyph anchor
is the centre, `(10, 10)`.

| Location | World px | Glyph |
|---|---|---|
| Haven's Rest | 240, 1142 | `marker_haven` |
| Whispering Woods | 200, 592 | `marker_wilds` |
| Forgotten Hollow | 160, 270 | `marker_perilous` |
| Stonefall Mine | 614, 724 | `marker_worksite` |
| Frostmere | 590, 170 | `marker_wilds` *(guess — `LocationKind` is stream B's derivation)* |

The glyphs are now **mid-tone, not white-filled**, so they read on snow as well
as grass and no longer pop as UI chrome inside the hamlet (round-1 NOTE C).
They are deliberately quieter than the ring; the ring carries the affordance.

---

## 5. Landmark sprites: packaged but NOT placed

`landmark_old_watch`, `landmark_standing_stones`, `landmark_ferry_crossing`,
`landmark_stone_bridge` are delivered and conformed, but **the proposed layout
places none of them**: each tile already draws its own version of the feature at
that coordinate, and compositing the sprite over it reproduces the
TRANSFORMATION_01 double-palisade MAJOR. The label plus the small marker glyph
is enough.

They are packaged so a future tile that lacks the feature can use them, and so
the lead can overrule this call with the art in hand.

---

## 6. Seam-cover prop placement

**The authoritative machine-readable list is `tools/placement_r2.json`** — 44
entries, native top-left blit positions, exactly as composited in
`qa/mock_atlas_x2.png`. For `props` entries in `atlas_layout.json`:
`x_world = (blitX + ax) * 2`, `y_world = (blitY + ay) * 2`.

The round's standing finding, now confirmed twice:

> **Continuous strips do not cover seams; irregular clusters of curved props
> do.** A full-width strip reads as a ruled border. Round 1 QA independently
> flagged both remaining strips as defects (`vd4`: "reed-marsh block has a
> straight rectangular bottom edge"; `rl2/am6/e4y`: the vertical treeline
> "reads as a poplar / stacked hedge"). Both are now **unplaced**.

### Seam base <-> east (vertical, x = 384) — round 2: stamps varied

Round 1 QA: "the same pillar+ledge stamped twice ... a vertical strip of
stamped objects". Now no two adjacent stamps are the same asset, x varies by
±16 px and the y spacing is irregular.

| prop | blit x | blit y |
|---|---|---:|
| `env/prop_pine_clump` | 352 | 238 |
| `env/prop_boulders` | 372 | 286 |
| `env/prop_dead_tree` | 346 | 330 |
| `env/prop_crag` | 374 | 372 |
| `env/prop_pine_clump` | 350 | 404 |
| `env/prop_cairn` | 378 | 452 |
| `env/prop_boulders` | 344 | 486 |
| `env/prop_pine_clump` | 368 | 520 |
| `env/prop_crag` | 348 | 566 |
| `env/prop_lone_oak` | 372 | 600 |
| `env/prop_pine_clump` | 346 | 642 |

Above y = 238 nothing is needed: the base's snowfield runs straight into the
east tile's snow wall.

### Seam base <-> south (horizontal, y = 688) and the straight lane

Round 1 MINOR: "a dead-straight pale vertical band of constant width from the
tree clump to the frame edge". **Identified:** it is the south tile's own
hedged farm road, drawn at tile-local x 44–52 (`#8f8162`) with hedgerows at
x 36 and x 60, running straight from its top edge to about y 250. It is drawn
geography, not a tile artefact or a prop line. It is now punctuated by props
set to alternate sides of the lane, so it reads as a hedged lane with trees and
waymarks rather than a ruled edge.

| prop | blit x | blit y | why |
|---|---|---:|---|
| `env/prop_lone_oak` | 4 | 668 | copse over the road jog at the seam |
| `env/prop_pine_clump` | 34 | 650 | copse over the road jog |
| `env/prop_lone_oak` | 52 | 676 | copse over the road jog |
| `env/prop_dead_tree` | 10 | 744 | west of the lane |
| `env/prop_hedgerow` | 56 | 806 | east of the lane |
| `env/prop_lone_oak` | 6 | 852 | west of the lane |
| `env/prop_hedgerow` | 58 | 912 | east of the lane |
| `env/prop_lone_oak` | 214 | 690 | breaks the open-meadow stretch |
| `env/prop_treeline_strip` | 296 | 684 | one short segment, east of the river |

**Nothing over the river** (native x 250–270): it crosses within 6 px and needs
no help. Round 1 QA called this "the one good join".

### Seam east <-> south-east (horizontal, y = 688)

Round 1 MAJOR. The round-2 tile fixes this at source; the scatter now only
adds texture.

| prop | blit x | blit y |
|---|---|---:|
| `env/prop_boulders` | 396 | 672 |
| `env/prop_crag` | 448 | 662 |
| `env/prop_boulders` | 508 | 680 |
| `env/prop_crag` | 566 | 668 |
| `env/prop_boulders` | 628 | 676 |
| `env/prop_crag` | 690 | 684 |

### Seam south <-> south-east (vertical, x = 384)

Round 1 MAJOR (hue step). No longer bare — four widely spaced props straddle it
to break the field-texture change. Still **no strip**.

| prop | blit x | blit y |
|---|---|---:|
| `env/prop_lone_oak` | 362 | 940 |
| `env/prop_hedgerow` | 368 | 1046 |
| `env/prop_lone_oak` | 360 | 1150 |
| `env/prop_hedgerow` | 366 | 1256 |

---

## 7. Scatter props on the new territory

| prop | blit x | blit y | where |
|---|---|---:|---|
| `env/prop_crag` | 660 | 230 | east moor, north of the watchtower |
| `env/prop_dune` | 599 | 1208 | shore below the headland |
| `env/prop_sea_stack` | 714 | 1168 | offshore, south-east |

`prop_reedbed_strip` was placed in round 1 and is **withdrawn** — QA saw its
straight rectangular bottom edge.

---

## 8. Routes

**No route polylines change**, and no new route is proposed. The five playable
routes are untouched.

Scenery-only tracks that must **not** get `routes` entries: the pass track east
across the moor (east tile), the road south past the far town (south tile), and
the farm lane in the south tile's north-west.

---

## 9. Overlays

None delivered. The mandated single water-shimmer retry failed (fifth failure
across two rounds — README §6); the optional wave-foam and reed-sway loops were
not attempted, because both generation budgets went to the tiles and the seams,
which is where the verdicts were. The eight existing overlay entries in
`atlas_layout.json` are unaffected.
