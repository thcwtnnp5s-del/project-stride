# WORLD_REWARD_DEPTH_01 — stream E: world atlas expansion (round record)

```
STATUS: ROUND RECORD · NOT CANON · NOTHING COMMITTED · NOTHING IN assets/
Governing brief: MILESTONES/WORLD_REWARD_DEPTH_01.md §8
Predecessor round: GAME_BIBLE/ART/exploration/TRANSFORMATION_01/world/README.md
Package + coordinates: PACKAGING.md
```

**Date:** 2026-08-19 · **Budget:** ≤ 260 generations ·
**Balance 700 → 447 = 253 spent.** Under budget by 7.

---

## 1. What this round grew

The accepted TRANSFORMATION_01 base C (`world/atlas_base`, 384×688, tile (0,0))
is untouched. Three new 384×688 tiles extend it to a 2×2 grid:

| Tile | Native origin | Character |
|---|---|---|
| `atlas_base` (existing) | (0, 0) | the known country |
| `atlas_east` | (384, 0) | high moor and heath falling to a rocky coast |
| `atlas_south` | (0, 688) | river lowlands, farms, the road to a far town |
| `atlas_southeast` | (384, 688) | grazed levels, salt marsh, estuary, headland |

World: **768 × 1376 native**, **1536 × 2752 world px at scale 2**. Existing
location and route coordinates unchanged.

---

## 2. Measured seam facts — read off the shipped base, not assumed

`tools/edge.js` and `tools/row.js` sampled `assets/art/v1/world/atlas_base.png`.

**Base south edge (row 687):**

| Native x | What is actually there |
|---|---|
| 6 – 14 | the pale dirt road, `#a48e74` — it leaves at the **bottom-left corner** |
| 16 – 250 | olive-khaki meadow, `#7c7951` / `#706d49` / `#696f45` |
| **250 – 268** | **the river**, `#545a62` / `#515351` — two thirds across |
| 270 – 306 | meadow `#7c7951` |
| 308 – 383 | darker scrub and hedge bushes, `#5c6041` |

**The brief said the base's river exits bottom-left. It does not — it exits at
x ≈ 258, two thirds across.** Every south-tile prompt was written against the
measurement rather than the brief, and that is why the river seam works.

**Base east edge (column 383), bands of average colour:**

| Native y | Class | Average | lum |
|---|---|---|---:|
| 0 – 128 | snowfield / tarn ice | `#878785` → `#aeb6be` | 134–181 |
| 129 – 214 | pale grey crag and snow | `#9b9fa2` | 142–158 |
| 215 – 300 | dark grey crag, frost pines | `#4e4f4f` | 79–112 |
| 301 – 386 | mid grey scree | `#6a6966` | 105–106 |
| 387 – 515 | grey-brown scree, sparse pines | `#575856` | 84–94 |
| 516 – 601 | dark scree fading to scrub | `#5c544c` | 85–91 |
| 602 – 687 | olive meadow, round hedge bushes | `#5a6041` | 93–107 |

---

## 3. Palette anchoring — changed from TRANSFORMATION_01

T01 anchored on the Traveler's south sprite. This round anchors on **the base
itself**.

Inline base64 of a 96×96 crop (≈3.2 KB encoded) was **truncated in transit** by
the MCP client and rejected with an explicit "keyframe image is incomplete"
error. The fix: `tools/palchip.js` builds a **48×48 palette-chip PNG** — the
N most-used colours of a region of the base as 8×8 blocks, ≈300 bytes,
≈396 base64 chars. It survives the wire, and with `style_copy=["color_palette"]`
a chip grid *is* the style reference; spatial content is irrelevant.

| Chip | Base region | Used for |
|---|---|---|
| `_pal_south.png` | (0, 440, 384, 248) | south tile |
| `_pal_east.png` | (192, 0, 192, 560) | east tile |
| `_pal_all.png` | whole base | south-east tile |

No colour words appear in any prompt.

**Then every tile and every cutout was palette-conformed** to the base with
`tools/conform.js` (each opaque pixel remapped to the nearest colour in the
base's regional palette; alpha and shape untouched — `RULES.md` A-2). This is
load-bearing, not cosmetic: the raw south tile's meadow was `#867844` against
the base's `#7c7951` and the seam showed as a hard band. Conform closed it.
Compare `qa/seam_south_s53_river_x2.png` (raw) with
`qa/seam_south_conf96_river_x2.png` (conformed).

---

## 4. Spend

`create_map_object`'s cost was **unquoted by the tool and unknown to
TRANSFORMATION_01**, which recorded "141 + 26 unquoted calls; ≤ 272 worst case"
and recommended measuring it. Measured this round by issuing one call alone
against a quiet balance:

> **`create_map_object` costs 2 generations** (96×40, basic mode). Billing is at
> **completion**, not submission — the balance does not move when the job is
> accepted.

| Tool | Size | Quoted | Calls | Sub-total |
|---|---|---:|---:|---:|
| `create_image_pro` | 384×688 | 40 | 4 | 160 |
| `create_map_object` | 32×96 … 96×64 | 2 (measured) | 16 | 32 |
| `create_image_pixen` | 20×20, 64×32 | 1 | 8 | 8 |
| **Accounted** | | | **28** | **200** |
| **Balance delta** | 700 → 447 | | | **253** |

The 53-generation gap between the quoted sum and the measured delta is **not
explained**. Two candidates: `create_map_object` may cost more than 2 at larger
canvases (the measurement was taken at 96×40 only), or another stream shares the
account — G and any other art session bill against the same subscription, and
this round ran concurrently with them. Recorded as an open measurement rather
than smoothed over. **Next round should re-measure `create_map_object` at 400×400
and confirm whether the account is genuinely quiet before attributing a delta.**

Other API limits confirmed this round: **8 concurrent jobs**, then
`rate limit exceeded`.

---

## 5. Prompts, verbatim

Shared tail on all three tiles: *"Flat matte pixel art shading, light from the
upper left. No people, animals, figures, text, labels, compass, border, frame,
grid."* All: `no_background=false`, `style_copy=["color_palette"]`,
`style_image_url` = the palette chip named in §3.

### South tile (seeds 41 and 53, identical prompt)

> Illustrated overview map of warm lowland farming country seen from high above,
> filling the whole canvas edge to edge, no border and no frame. Terrain drawn as
> painted texture and massed shape, not square tiles. Continuity at the top edge:
> a narrow dirt road enters the top edge very close to the left corner and runs
> south; a river enters the top edge two thirds of the way across from the left
> and flows south; all the rest of the top edge is open grazing meadow with low
> hedgerow lines, unbroken to the edge. The river bends through the middle of the
> map and widens into a broad slow river that leaves at the bottom edge right of
> centre. Middle band: three small farmstead clusters, each two or three thatched
> buildings with a yard, set among narrow irregular field strips of different crop
> texture divided by hedgerows and lines of trees; the strips follow the lie of the
> land and are not a regular grid. At a narrow place in the river a timber ferry
> jetty stands on each bank with a flat ferry boat between them. A small stone arch
> bridge carries the road over a side stream. An orchard of evenly spaced small
> round trees beside one farmstead. A water mill with a wheel stands on the
> riverbank with a millpond. Lower third: the road runs on south and reaches a
> distant walled town at the very bottom of the canvas, a ring wall with a
> gatehouse and packed roofs, half cut off by the bottom edge. […shared tail]

### East tile (seed 61)

> Illustrated overview map of high open moor falling east to a rocky sea coast,
> seen from high above, filling the whole canvas edge to edge, no border and no
> frame. Terrain drawn as painted texture and massed shape, not square tiles. The
> western edge is a continuous mountain wall running unbroken from the top edge to
> the bottom edge: the top sixth of the west edge is snowfield and bare ice, below
> that down to two fifths is pale broken crag, from two fifths to three quarters is
> a long slope of loose scree with a few frost pines, and the lowest eighth of the
> west edge is rough grass and low round bushes. East of that wall the land is open
> heath and rough moor grass with peat hags, scattered boulders and heather patches,
> falling gently east. Two small still tarns lie on the moor, one about one third
> across and one third down, one about half across and two thirds down. A ruined
> round stone watchtower with its top broken away stands on a rock crag about half
> across and one quarter down. A ring of upright standing stones sits on the open
> moor about one third across and one half down. A faint narrow track squeezes
> through a low notch in the mountain wall a little above the middle of the west
> edge, runs east across the moor past the standing stones, and fades out into the
> heath. A small moor stream gathers on the heath and leaves at the bottom edge one
> third of the way across from the left. The right quarter of the canvas is sea,
> with a low rocky cliff edge, a shingle strand and three tall sea stacks standing
> offshore; the sea fills the whole right edge and the top right corner. […shared tail]

### South-east tile, first attempt (seed 61) — rejected

> Illustrated overview map of a low coastal estuary and salt marsh seen from high
> above […] a stream enters at the top edge one third of the way across from the
> left; the top left quarter of the canvas is rough moor grass and heather thinning
> southward into grazing land; the whole left edge from top to bottom is low
> farmland and grazing meadow divided by hedgerow lines; the right quarter and the
> bottom third of the canvas are open sea. The stream runs south and widens into a
> broad shallow estuary that opens into the sea toward the bottom right, its channel
> braided with mud flats and pale sand banks. Broad salt marsh with reed beds and
> winding creeks fills the middle of the canvas along the estuary. A low headland
> reaches out into the sea on the right about halfway down; on it stand the ruins of
> an old harbour, a broken curving stone breakwater running out into the water, the
> stumps of timber piles, and a squat round stone beacon tower at the headland
> point. A line of low grassy sand dunes runs along the shore below the headland.
> Shallow water is drawn paler than deep water. […shared tail]

### South-east tile, second attempt (seed 88) — accepted

Corrected against the measured neighbours; the changed clauses are the reason
it works.

> Illustrated overview map of low grazed coastal levels and a salt marsh estuary
> seen from high above, filling the whole canvas edge to edge, no border and no
> frame. Terrain drawn as painted texture and massed shape, not square tiles.
> **Edge continuity, which matters more than anything else here:** the whole left
> edge from top to bottom is open farmed country, grazing fields and small crop
> closes divided by irregular curving hedgerows and lines of trees, and that farmed
> country continues inland for the left third of the canvas, its field shapes
> following the lie of the land and **never forming a regular grid**; the whole top
> edge is rough stony moor grass with scattered boulders and heather, thinning
> southward into rough pasture, and a small moor stream enters the top edge one
> quarter of the way across from the left; the top right corner is a dark wooded
> slope falling toward the shore. The stream runs south through the middle of the
> canvas and opens into a broad shallow estuary that reaches the sea at the bottom
> right, its channel winding between grassy saltings, reed beds and low banks.
> **The marsh is grazed green saltings and grassy levels cut by winding creeks, not
> bare mud.** A low headland reaches into the sea on the right about halfway down,
> carrying the ruins of an old harbour: a broken curving stone breakwater running
> out into the water, stumps of timber piles, and a squat round stone beacon tower
> at its point. A line of low grassy sand dunes runs along the shore below the
> headland. The right quarter and the bottom quarter of the canvas are open sea,
> drawn paler in the shallows and deeper away from the shore. […shared tail]

### Cutouts

All `create_map_object`, basic mode, `low top-down`, `single color outline`,
`basic shading`, `medium detail`, each ending *"only the …, no ground plane, no
grass, no base slab"*. All markers `create_image_pixen`, 20×20,
`no_background=true`, `high top-down`, `single color outline`, `low detail`,
each phrased *"tiny map marker glyph: … solid dark contour, flat fill, bold
clear silhouette"*.

---

## 6. Candidate verdicts

### Tiles

| Cand | Job | Seed | Verdict |
|---|---|---|---|
| south A | `0eecd914-…` | 41 | **Rejected.** Composition good, but the river enters the top edge 42 px east of where the base's river leaves and the road 54 px east. Both offsets are nearly equal — the tile is the right picture, translated — but the layout cannot shift a tile without leaving an unpainted column. The river break is visible at ×2 (`qa/seam_south_s41_river_x2.png`) and no prop hides a 42 px dogleg in a river. |
| **south B** | `2b0185e2-…` | **53** | **Accepted, conformed.** River enters 6 px from the base's exit; reads as one river across the seam. Road still 38 px off — covered by a copse (§6 of PACKAGING). Farmsteads, field strips, ferry punt, orchard, mill with wheel, stone bridge, walled town half-cut at the bottom edge all present. |
| **east** | `6b1824f3-…` | **61** | **Accepted, conformed.** Only seed drawn. Watchtower on a crag, standing-stone ring, two tarns, sea stacks, pass track through a notch, moor stream leaving the bottom edge. The strongest single tile of the round. |
| south-east A | `e7839e52-…` | 61 | **Rejected.** Beautiful in isolation. Fails both internal seams at ×2: its west edge is bare mudflat against the south tile's dry hedged fields (`qa/seam_C_se_upper_x2.png`), and its bottom-left is a near-rectangular field grid — the thing the prompt forbade. |
| **south-east B** | `c28bd011-…` | **88** | **Accepted, conformed.** Left edge is hedged farmland the whole height, matching its neighbour; top edge is stony moor with the stream entering at one quarter; harbour ruin, breakwater, beacon tower, dunes, saltings, sea. Fixed both of A's seam failures. |

The south-east re-roll was strictly additive — tile A was already in hand, so a
worse seed cost only generations. That is why it was worth the last 40.

### Marker glyphs

| Kind | Verdict |
|---|---|
| `marker_wilds` (tree) | **Accepted**, first try. |
| `marker_worksite` (pick on a spoil heap) | **Accepted**, first try. |
| `marker_haven`, attempt 1 (hut behind a fence) | **Rejected** — read as a gem or a chest at ×8. Too much information for 20 px. |
| `marker_haven`, attempt 2 (house with a chimney) | **Accepted.** |
| `marker_perilous`, attempt 1 (cracked standing stone) | **Rejected** — a lumpy dark blob, no crack legible. |
| `marker_perilous`, attempt 2 (trilithon arch) | **Rejected** — read as a small temple with two doorways, i.e. a *building*, which collides with `marker_haven`. |
| `marker_perilous`, attempt 3 (bare dead tree) | **Accepted.** Unmistakably distinct from the wilds tree, and it is the Hollow's own vocabulary. |
| `marker_landmark`, attempt 1 (four-stone cairn) | **Rejected** — a colourful blob. |
| `marker_landmark`, attempt 2 (three stacked flat stones) | **Accepted.** |

All five were then palette-conformed and tested **on real terrain** rather than
on a checker: `qa/_glyph_ctx_x2.png` lays them on meadow, snow and moor cut from
the finished world. All five read on all three at ×2. The dead tree and the
cairn are the least crisp on dark moor.

### Cutouts

| Object | Verdict |
|---|---|
| watchtower, standing stones, ferry jetty, stone bridge | **Accepted** as art — clean slab-free cutouts. **Not placed** (PACKAGING §5). |
| treeline strip (96×32), reedbed strip (96×32), ridge strip (96×40) | **Accepted** as art (edge-to-edge, bounds 0..95). **Failed their purpose** — see §7. |
| sea stack, crag, dune | **Accepted and placed.** `crag` carries a small grass foot that reads oddly on bare scree. |
| vertical treeline strip (32×96) | **Accepted** as art, **not placed** — a visibly repeated column of identical bushes. |
| vertical ridge strip (40×96) | **Rejected** — reads as an icicle, and its bounds (top 6, bottom 88) do not reach the strip edges, so it cannot tile end to end. |
| harbour ruin + beacon (96×64) | **Rejected** — returned on a large tan diorama slab. |
| farmstead + mill wheel (64×56) | **Rejected** — isometric diorama on a yard slab; wrong projection for a top-down atlas. |
| water shimmer (64×32 pixen ripples) | **FAILED.** Returned a black-and-white dither checkerboard, not ripple lines (`qa/_shimmer_x6.png`). This is **failure five across two rounds**. Per the brief, one attempt only — stopped. **Recommend dropping water shimmer from the backlog rather than re-attempting; five failures across four prompt strategies and three tools is enough evidence.** |

---

## 7. The round's main finding: strips do not cover seams, clusters do

The brief and the milestone both anticipated *seam-cover strips*: long thin
props laid along a join. Tested at ×2, they are **worse than the seam they
cover** — a full-width strip is a perfectly straight line of identical elements
ruled across the map, and the eye reads it as a border. The base's own
hedgerows are curved, broken and terrain-following; nothing in this world is
straight, so a straight thing is instantly foreign.

What works is **irregular clusters of curved props straddling the join** —
two or three oaks and a pine over the road jog, pines and crags stepping down
a ridge. The eye follows the cluster and stops tracing the line.

Evidence pairs, all at ×2:

| Failed strip | Working cluster |
|---|---|
| `qa/cover_south_road_x2.png` | `qa/cover3_south_road_x2.png` |
| `qa/cover2_south_river_x2.png` | — (river needed nothing) |
| `qa/cover88_C_upper_x2.png` | — (bare seam is better) |
| — | `qa/coverA_east_scree_x2.png`, `qa/coverA_east_meadow_x2.png` |

Placement tables are in `PACKAGING.md` §6. The strips are still packaged, and
flagged as unplaced with the reason.

---

## 8. QA artefacts

`qa/mock_atlas_x2.png` — the whole 2×2 world at ×2 (1536×2752) with every
proposed prop, seam cover and glyph composited. A review composite, **not a
shipped asset**.
`qa/mock_atlas_overview_half.png` — the same at ×0.5, for reading at a glance.
`qa/phone_z1_*.png` — three 390×700 phone viewports at zoom 1 (195×350 native
at ×2): Haven's Rest across the south seam, the east moor, the estuary.
`qa/phone_z05_world_quad.png` — 390×700 at zoom 0.5, centred on the point where
all four tiles meet. This is the honest test and the one to look at first.
`qa/seam_*`, `qa/cover*` — the seam and cover comparisons above.
`qa/_grid_*.png` — 32 px measuring grids used to read every coordinate in
`PACKAGING.md`.

**Blind staging:** `qa/blind/` holds 14 artefacts under opaque shuffled codes
per `NEUTRAL_STAGING_CHECKLIST` A1–A6. The key is `tools/blind_key.json`,
outside the critic-accessible folder (D1); `tools/stage_blind.js` regenerates
the staging. Filenames elsewhere in `qa/` are semantic and must not be shown to
a blind reviewer.

**The staging cannot close D4.** A subagent in this repository receives
`CLAUDE.md` and a `git status` snapshot naming `WORLD_REWARD_DEPTH_01`, so the
reviewer already knows this is an atlas for a walking RPG. Findings that
restate the premise are not independent evidence.

`STAGING CHECK: PASS`

---

## 9. AUTHOR ASSESSMENT

This is my own read and it is not a verdict (M-05).

- **The world is materially bigger and it mostly reads as one country.** North
  is cold and high, south warm and worked, west wild, east worked and then wet;
  the mountain spine runs unbroken from the base into the east tile; the river
  leaves the hamlet and reaches a walled town; a second river reaches the sea.
  At zoom 0.5 (`qa/phone_z05_world_quad.png`) it reads as a map of a place.
- **The east tile is the best thing in the round.** The watchtower and the
  standing-stone ring both read at ×2 without labels, and the moor is genuinely
  lonely. `qa/phone_z1_east_moor_x2.png`.
- **The estuary reads.** The breakwater, beacon and saltings are legible and the
  conformed sea is muted enough to belong to this palette rather than to a
  brighter game. `qa/phone_z1_estuary_x2.png`.
- **The seams, honestly, worst to best:**
  1. **east ↔ south-east (y = 688, x 384–768)** — the weakest join in the world.
     A pale grey boulder field above meets dark heather below and the value step
     is a visible horizontal band. The scattered boulders soften it; they do not
     dissolve it. If one thing gets another pass, it is this.
  2. **base ↔ south (y = 688, x 0–384)** — visible as a faint tone step across
     open meadow in the middle of the frame, where no prop reaches. The river
     crosses cleanly and the road jog is properly hidden. Acceptable.
  3. **south ↔ south-east (x = 384, lower half)** — a mild hue step between two
     farmlands. Leave it bare; every cover tried made it worse.
  4. **base ↔ east (x = 384)** — invisible above y ≈ 240 (snow into snow), and
     the pine-and-crag scatter turns the rest into a treed spur. Good.
- **Palette conform is doing a great deal of work.** Every tile before conform
  showed a hard band at its seam. If the lead wants to see how much, compare
  `qa/seam_south_s53_river_x2.png` with `qa/seam_south_conf96_river_x2.png`.
  The cost is that the tiles lose some of their own tonal range.
- **What I would not ship without a second look:** the south-east tile's field
  pattern is still more regular than anything else in the world, and at zoom 0.5
  the bottom-left corner edges toward reading as a grid. The `standing_stones`
  and `crag` cutouts carry small ground discs that a strict reading of the
  slab-free rule would fail.
- **Not delivered, and I am not going to dress it up:** no overlays at all this
  round, and water shimmer failed for the fifth time.


---

## QA VERDICT (round 1, independent blind Visual QA, 2026-08-19)

**QA VERDICT: FAIL** — the 2x2 world as composed.

Recorded in full, verbatim, in **`QA_VERDICT_ROUND1.md`** (per-file reads,
findings table, per-item verdicts and the lead's disposition). It is not
duplicated here: `RULES.md` G-7, one canonical home per concept. Headline
findings, unaltered:

| Sev | Cat | Finding |
|---|---|---|
| MAJOR | A/B | Hard straight grey-to-brown line across the east/south-east join; both streams terminate on it. |
| MAJOR | A/B | Hard hue step olive-khaki to yellow-green at south/south-east; the two lower quadrants read as different paintings. |
| MAJOR | B | Four quadrants with four palettes and densities; reads as tiles, not one world. |
| MINOR | A | base/east join hidden by a column with the same pillar and ledge stamped twice. |
| MINOR | A | Dead-straight pale vertical band from the tree clump to the frame edge. |
| MINOR | A | Reed-marsh block has a straight rectangular bottom edge. |
| MINOR | A | Stone circle on an oval grass disc; pick glyph on its own dirt pad. |
| MINOR | B | Dark three-tier glyph reads "pot / cauldron / small chest"; weakest on moor. |
| MINOR | B | Hut and pick glyphs lose their white fill on snow. |
| NOTE | C | White hut marker inside the hamlet pops as UI. |

The reviewer's own staging note stands: the task prompt named the region and
glyph categories, so "absent" findings are absent-when-prompted and are
discounted. The reviewer also flagged that **no native x1 world crop** was
supplied — a real gap in my round-1 set (checklist A6). Fixed: `qa/blind_r2/`
now carries x1, x2 and x8 rungs for both glyphs and objects.

---

# ROUND 2 — the fix round (2026-08-19)

**Balance 447 to 365 = 82 spent.** Budget was at most 100; under by 18.
**Two-round total: 700 to 365 = 335 generations.**

## 10. Spend

| Tool | Purpose | Quoted | Calls | Sub-total |
|---|---|---:|---:|---:|
| `create_image_pro` | south-east tile, seeds 104 and 137 | 40 | 2 | 80 |
| `create_image_pixen` | `marker_landmark` candidates (boulders, capped pillar) | 1 | 2 | 2 |
| **Accounted** | | | **4** | **82** |
| **Balance delta** | 447 to 365 | | | **82** |

Quoted sum and measured delta agree exactly this round. That resolves the
round-1 anomaly in favour of the second hypothesis: **the 53-generation gap in
round 1 was another stream billing the shared account, not `create_map_object`
costing more than the measured 2.** No `create_map_object` calls were made in
round 2, and the delta matched the quote to the generation.

## 11. What changed, item by item

### 1. South-east tile — the deterministic route was tried first, and failed

The lead asked for the A-2 route before any re-roll. Done, and it produced
nothing:

- **Union-conform to base + south + east** (`tools/conform2.js`, whole tile,
  nearest colour) returned a file **byte-identical to the shipped round-1
  tile** (`cmp` reports no difference). The reason: the base, south and east
  tiles had already all been conformed to the base's palette, so their union
  *is* the base's palette — the 44 colours the tile was already using.
- A second variant conformed to the narrower south-region palette also failed
  to move the seam.

Why no palette operation could work, measured rather than argued: I wrote
`tools/seamdiff.js`, which reports the mean colour either side of a join per
band and the distance between them. The south/south-east seam was **a value
step, not a hue step** — the south side sat at lum about 78 (`#564d3b`,
ploughed and wooded), the south-east side at lum about 125 (`#847d57`, pale
grazing). Both were already inside the base palette. Nearest-colour remapping
cannot close a gap between two colours that are both already in the target
palette. **Conform was the right first thing to try and the wrong tool for this
defect.**

So: re-rolled, within the authorised two seeds, with edge requirements written
from measured neighbour profiles (README section 2 method, extended to the east
tile's bottom row and the south tile's right column). Streams located with
`tools/findwater.js` at tile-local x about 119 and x about 256.

Ranked on measured seam distance — the whole point of building the metric:

| Candidate | S/SE mean | max | hard bands | E/SE mean | max | hard bands |
|---|---:|---:|---:|---:|---:|---:|
| seed 88 (round 1, QA FAIL) | 48.4 | 82.3 | 9/11 | 33.8 | 63.0 | 4/8 |
| seed 104 | 69.0 | 106.9 | 10/11 | 31.9 | 51.5 | 5/8 |
| **seed 137 — accepted** | **28.3** | **44.7** | **7/11** | **19.5** | **46.6** | **1/8** |

Seed 104 is recorded as an honest over-correction: I asked for "deeply shaded
through the middle two thirds" and got near-black tree belts (lum about 40)
against a neighbour at lum 78 to 119, which is *worse* than the pale original.
Seed 137 asked instead for "a steady middling tone ... no continuous pale band
and no continuous dark band", and that is the phrasing that worked. Seed 137
also drew both streams within about 5 px of their measured entry points, and
honoured "no village, hamlet or cluster of houses" — seed 104 grew an
unrequested settlement in the marsh, which would have read as an untappable
place.

Two seams at x2: `qa/r2_final_seamB_x2.png` (east/SE — the round-1 MAJOR) and
`qa/r2_final_seamC_x2.png` (south/SE).

### 2. base/east column — stamps varied

No two adjacent stamps are now the same asset; x varies by about 16 px either
way and the y spacing is irregular (pine, boulders, dead tree, crag, pine,
cairn, boulders, pine, crag, oak, pine). `qa/r2_final_seamA_x2.png`. Table in
`PACKAGING.md` section 6.

### 3. The straight pale band — identified

Not a tile artefact and not a prop line: it is **the south tile's own hedged
farm road**, drawn at tile-local x 44 to 52 (`#8f8162`) between hedgerows at
x 36 and x 60, running straight from its top edge to about y 250 (measured with
`tools/band.js`). Drawn geography.

Broken by props set to **alternate sides** of the lane rather than on it — the
first attempt put them down the middle and produced trees growing in the road.
It now reads as a hedged lane with trees and waymarks.

### 4. Glyphs

- `marker_landmark`: the "cauldron" is **replaced** by three rounded boulders.
  A second candidate (a capped pillar) was **rejected** — it read as a mushroom
  and its pale cap vanished on snow. Judged on four real terrain bands at x2
  (`qa/_r2_glyph_ctx_final_x2.png`), not on a checker.
- `marker_worksite`: the dirt pad occupied exactly rows 12 to 16 while the
  pick's haft ended at row 11 (`tools/ascii.js`), so a row-threshold key removes
  the pad cleanly. A colour flood-fill was tried first and **destroyed the
  glyph** — the haft shared the pad's dark — which is recorded because it is
  the kind of automated "fix" that silently ships broken art.
- `marker_haven` and `marker_worksite` are **re-conformed to a mid-luminance
  slice of the base palette** (`tools/conform_lum.js`, lum 55 to 135). This is
  the same class of operation as `conform.js` — a colour-to-colour remap, no
  shape change. It fixes both round-1 glyph findings at once: they no longer
  lose their fill on snow, and the hut no longer pops as UI chrome inside the
  hamlet.

### 5. Slabs keyed

`landmark_standing_stones`: the oval grass disc is keyed out (418 px,
`tools/keypad.js` — flood-fill from bottom-row pad colours, alpha only). The
stones now stand with a scatter of grass tufts. The `old_watch` mossy foot is
integral to the crag, not a flat pad, and was left alone.

## 12. Artefacts

`qa/mock_atlas_x2.png` — whole 2x2 world at x2 (1536x2752), 44 placements.
`qa/mock_atlas_overview_half.png` — the same at x0.5.
`qa/phone_z1_*.png` — three 390x700 viewports at zoom 1.
`qa/phone_z05_world_quad.png` — 390x700 at zoom 0.5 on the four-tile junction.
`qa/r2_final_seamA_x2.png`, `_seamB_`, `_seamC_` — the three new seams at x2.
`qa/_r2_glyph_ctx_final_x2.png` — glyphs on meadow, snow, moor and farmland.
`qa/_r2_objects_x1/x2/x8.png`, `qa/_r2_glyphs_x1/x2/x8.png` — full A6 rungs.

**Blind staging for the second verdict:** `qa/blind_r2/`, 14 files, fresh
opaque codes, key at `tools/blind_key_r2.json` (D1: outside the reviewer's
folder), regenerated by `tools/stage_blind_r2.js`. Codes re-shuffled: build
order maps to alphabetical positions 13,7,12,4,3,9,14,6,10,1,11,5,8,2. The x1
rung the round-1 reviewer said was missing is now included.

**D4 still cannot be closed by staging** — a subagent here receives `CLAUDE.md`
and a `git status` naming the milestone. And the round-1 reviewer's own note
applies again: naming the categories in the task prompt primes them.

`STAGING CHECK: PASS`

## 13. AUTHOR ASSESSMENT — does the composite now read as one country?

My own read, not a verdict (M-05).

**Mostly yes, and one of the two seam MAJORs is gone outright.**

- **east/south-east (the round-1 FAIL): fixed.** The hard grey-to-brown ruled
  line is gone; boulder-strewn moor now runs down into stony heath with
  scattered rock, and the streams continue instead of dying on the join. Hard
  bands dropped from 4/8 to 1/8, mean from 33.8 to 19.5. This is the change I
  would point at.
- **south/south-east: much improved, not perfect.** The colour step is largely
  gone (mean 48.4 to 28.3), so the two lower quadrants no longer read as
  different paintings. What remains is a **texture** difference: the new tile's
  fields are flatter and more geometric than the south tile's soft irregular
  strips. I would expect a reviewer to still see a change of hand there, and to
  call it MINOR rather than MAJOR.
- **base/east: improved but still the second-weakest join.** Varying the stamps
  removed the "same thing twice" read, and it now works as a treed, stony spur.
  The underlying contrast — dark scree meeting a pale snow face — is drawn into
  the two tiles and no prop arrangement removes it.
- **base/south: unchanged and still visible** as a faint horizontal tone step
  across open meadow in the middle of the frame, where no prop reaches. Round 1
  QA called the river crossing here "the one good join" and that still holds.

**What I would flag against myself before the reviewer does:**

- The new south-east tile's left third is a **pale, hard-edged field patchwork**.
  It is the tile's weakest quality and it sits directly on the seam QA failed.
  I chose it anyway because the measurements say it joins far better than the
  alternative, and because a soft tile that does not join is what failed last
  time — but it is a real trade, not a clean win, and a third seed might well
  have beaten both. The budget did not allow one.
- Three delivered props (`prop_reedbed_strip`, `prop_ridge_strip`,
  `prop_treeline_strip_v`) are now packaged and **unplaced**. That is honest
  rather than tidy: strips failed twice, and QA independently flagged two of
  them as defects.
- Still no overlays, and water shimmer is still not delivered.

**On the fallback:** I do not think base+south only is the right call. The east
tile drew the round's only unqualified PASS (`b2m`), and the join QA failed
hardest is the one that is now measurably fixed. My recommendation is the full
2x2 as packaged.

QA VERDICT (round 2): **FAIL** — recorded verbatim, with the lead's final disposition (ship base + south; withhold east / south-east), in `QA_VERDICT_ROUND1.md` (round 2 section).
