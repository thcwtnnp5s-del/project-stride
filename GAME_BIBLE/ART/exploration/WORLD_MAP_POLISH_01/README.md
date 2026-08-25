# WORLD_MAP_POLISH_01 — the atlas breathes, and the west catches fire

**Date:** 2026-08-24 · **Branch:** `playable-phase-2-multiregion` ·
**Workstream:** World Map Polish 01 (record: `MILESTONES/WORLD_MAP_POLISH_01.md`)

Two deliverables, both presentation-only:

1. **The western forest-fire landmark** — a small animated cluster of burning
   trees at the western river fork, PixelLab-authored, composited as an
   `overlays` entry in `atlas_layout.json`. Decorative environmental
   storytelling only: no hit target, no label, no quest, no world-state.
2. **The restored ambience** — the smoke and cloud overlays the 512 × 512
   continent replacement dropped (chimney smoke at Haven's Rest, mine smoke at
   the Stonefall adit, two drifting cloud shadows, one cloud wisp) and the
   drift the birds lost, re-placed on the new painting's geography.

## Forest fire — provenance (PixelLab, 2026-08-24)

Method: `create_map_object` **style-matched by inpainting** against a 64 × 64
crop of the shipped master at the western river fork (native 24,218 — the
fork's own west-bank canopy), so the cluster is painted in the atlas's own
tree language and palette. Animation: `animate_image` on the accepted still.

| Attempt | Job / object | Verdict |
|---|---|---|
| v1 | `a523dc42-cd79-4f0c-9224-a1fb25259e99` | **REJECTED** — three flames on a dark blob; no readable trees. `rejected/fire_cluster_v1_64x64.png` |
| v2 | `7d021c8a-cea4-4968-95d7-64fb4ad9441b` | Candidate — irregular canopy cluster in the painting's own blob style, one crown aflame over a charred heart; blends convincingly in context |
| pixen v2 | `faedb540-8ff5-465e-9bd2-7ddb443626c7` | **REJECTED for the atlas** — reads strongly as burning pines but at icon scale and in a side-view drawing hand the map does not use. `rejected/fire_pixen_64x64.png` |
| v3 | `b91818a5-4cef-49ff-8de1-1b1073c87cda` | **REJECTED** — five separate campfire icons, no trees. `rejected/fire_cluster_v3_64x64.png` |
| v4 | `7b2c2b1c-342b-43bc-ad9a-7dbf382ecb6d` | **REJECTED** — one round clump, single central flame, stray background artifact top-right. `rejected/fire_cluster_v4_64x64.png` |
| v5 | `3b7bab1d-a188-4778-8865-3aa4a16903f5` | **ACCEPTED** — a burnt hollow eaten into the canopy ring with two live flames; in-context composite reads unmistakably as "the forest has burnt here and is still burning", visible at the survey floor without dominating. `out/env/fire_cluster_still_64x64.png` |

### The animation

`animate_image` job `f9ce81f3-b07f-46f1-b418-ea455ab3b800` on the accepted
still (64 × 64, 8 generated frames): flames flicker and sway in place, embers
drift up, the canopy and char stay perfectly still — the union of opaque
bounds across all nine frames is identical, which is exactly the restraint
the brief asked for.

**The loop is the eight generated frames, not the input still.** The input's
flames are a size larger than every generated frame, so a loop wrapping
through it would pop once a cycle — the same reason the snow flurry shipped
frames 1–8. Each frame is deterministically cropped (A-2) from the 64 × 64
canvas to the 40 × 40 content box at (12, 12) and staged here as
`out/env/overlay_forest_fire_40x40_f0..7.png`; `package-art.js` § World Map
Polish 01 emits `assets/art/v1/env/overlay_forest_fire_f0..7.png`.

### Placement

`atlas_layout.json` overlay entry: world (210, 1386), 40 × 40 native at
scale 6, 8 frames at 200 ms (1.6 s loop), drift 0, opacity 1 — the burn
scar's centre lands on the west bank of the western river fork (native
≈ 55, 251), the far-west forest the world record calls "a stamped
single-motif fill … wants a couple of authored features". Decorative only:
no hit target, no label, no interaction, no audio (deferred with the rest of
the ambience seams). Cloud shadows are listed after it, so a drifting shadow
passes over the fire rather than under it.

### Generation count

7 PixelLab generations this round: 6 fire stills (5 map-object rolls + 1
pixen; 5 rejected, 1 accepted) + 1 animation. Balance 1,840 → 1,833,
matching exactly.

---

# Part 2 — the ambient-life pass (2026-08-25)

The completion of the owner's "map feels alive" request: easter eggs and
ambient motion, all presentation-only, no labels, no hit targets, no
gameplay. Runtime support: `atlas_layout.json` schema **v4** adds an
optional overlay `intervalMillis` — a quiet gap between plays, gap-first so
a frozen clock (tests, reduced motion, background) shows no creature at all.

## Audit before generating

- **Water shimmer/ripple sprites**: five recorded failures across two
  earlier rounds with a standing "stop re-attempting" note. Not re-attempted.
  This pass uses a different method entirely — animating crops of the
  painting itself (below) — which is why water finally moves.
- **Oakback Bear combat sprites**: exist, wrong scale/projection for a map
  peek. Not reused.
- Yeti, water dragon, volcano activity, tree rustle: nothing existed.

## Method A — in-place living regions

A crop of the shipped master is animated with `animate_image` and placed
back at its exact source coordinate, so the painting itself moves. Frame 0
is the untouched source crop (an intermittent play therefore fades in from
nothing); the generated frames get a deterministic 6-px edge feather back
onto the source (A-2 compositing) so no seam box can show. Where a crop's
edge reached into a landmark glyph's box, the emitted frames are cropped
away from the glyph instead (`package-art.js` `out` — Sunken Rows,
Reedmouth, Outer Shoal all checked).

| Set | Source crop (native) | Job | Behaviour |
|---|---|---|---|
| `overlay_volcano` | (412, 28) 64² | `474db612` 16f | Lava swells → dark smoke → small burst → settles; 17 frames (src + 16) × 250 ms, quiet 14 s |
| `overlay_tree_rustle_a` | (20, 340) 48² | `77521ee9` 8f | Canopy sways gently; 9 f × 300 ms, quiet 9 s. **First location (40, 298), job `12f63b22`, was abandoned in placement review** — its crop would have covered the Deepwood Shrine glyph; regenerated from a clean spot |
| `overlay_tree_rustle_b` | (96, 404) 48² | `cd4e54ce` 8f | Same, 9 f × 320 ms, quiet 13 s; emitted 44² (clear of Sunken Rows) |
| `overlay_ripple_coast` | (420, 280) 48² | `7e7392c0` 8f | Continuous 8-frame water loop × 350 ms; emitted 40×48 (clear of Outer Shoal) |
| `overlay_ripple_delta` | (352, 404) 48² | `07c57ed7` 8f | Continuous, emitted 36×48 from x+12 (clear of Reedmouth) |
| *(bay ripple)* | (452, 208) 48² | `750a412a` | **REJECTED** — the model invented a small creature at the crop edge and over-bold waves. `rejected/ripple_bay_strip_REJECTED.png` |

## Method B — creature easter eggs (style-matched map objects + animation)

| Creature | Accepted still | Animation | Behaviour |
|---|---|---|---|
| `overlay_yeti` | `10853f03` (v2; v1 `b9f6d8b8` lost the rod — `rejected/yeti_v1_no_rod_64x64.png`) | **STATIC, failure recorded (A-1):** two `animate_image` attempts (`84706774`, `bc64851c`) dropped the fishing rod in most frames; both strips in `rejected/`. A patient fisher beats a flickering rod; the idle-motion seam stays open | Sits ice-fishing on the frozen tarn's east ice, world (1461, 423), 24×30 |
| `overlay_water_dragon` | `8284ff8f` (v3; v1 `ee089592` a puddle-cat, v2 `cfdca5b5` a duck in foam — both in `rejected/`) | `603d7d0b` 8f — body undulates, head sways, foam flecks, coils lower at the end | Pops up in the eastern sea NW of Saltreach Light, world (2436, 1923), 40×36; 9 f × 450 ms every ~30 s |
| `overlay_bear_peek` | `a78e07da` (v2; v1 `f3e90a6b` an angular hamster — `rejected/bear_v1_64x64.png`) | `8fdeee7d` 8f — looks slowly left, right, blinks, returns (~5.4 s) | Peeks from the southern forest edge by the farmland, world (546, 2106), 28×24; 9 f × 600 ms every ~26 s |

## Generation count, part 2

17 generations: yeti 2 stills + 2 animation attempts (both rejected);
dragon 3 stills + 1 animation; bear 2 stills + 1 animation; volcano 1;
rustle 3 (one abandoned in placement review); ripples 3 (one rejected).
Balance check in the milestone record. In-context placement previews:
scratchpad `prev3_*`.

## Restored ambience — what was dropped and where it returns

The scale-4 layout (commit `400b5d9`) shipped 13 overlays; the 512 × 512
replacement (`dbf2b34`) rewrote the list to 10 and lost, without a recorded
decision: both cloud shadows, the cloud wisp, the chimney smoke, both forge
smokes — and zeroed every drift, including the birds'. PWRF01's device
script §19 still asks for "cloud shadows drifting … smoke at the hamlet and
the mine", so this round treats the drop as a regression and re-places the
same accepted assets on the new painting:

| Overlay | Placement (world px) | Note |
|---|---|---|
| `env/overlay_smoke` | 1128, 1500 · opacity 0.8 | Chimney thread on the orange-roofed Haven's Rest lodge |
| `env/overlay_smoke` | 1806, 1404 · opacity 0.8 | The Stonefall adit. The 32 × 48 `overlay_forge_smoke` column was tried first and **rejected in preview** — at the adit's scale it read as boulders rolling uphill; the small thread reads as a working mine |
| `env/overlay_cloud_shadow` ×2 | 900, 1650 and 600, 2150 · drift x 12 · opacity 0.16 | Meadow and farmland, drifting east, wrapping |
| `env/overlay_cloud_wisp` | 1500, 800 · drift x 9 · opacity 0.3 | Over the high range |
| `env/overlay_birds` ×3 | existing spots · drift restored (16, −3) | The flocks fly again instead of flapping in place |

One existing mist patch moves: `env/overlay_forest_mist` at (330, 1260) →
(270, 1080), out of the fire's corner of the forest — mist over a fire would
read as steam and mute the one landmark this round adds.

Preview composites (inspection only, never shipped): scratchpad
`prev1_*` / `prev2c_*`.
