# EPO03 — WORLD_SOUTH ledger (PROD-WORLD-SOUTH, territory 0–860 × 700–1024)

Cap **440 generations**. One row per job: what was asked, tool, job id, the
tool's own cost line, verdict, reason. Family total = the sum of cost lines —
never a balance delta (M-17). Region specs: `src/atlas/regions_south.json`;
accepted regions: `out/atlas/manifest_south.json`.

| # | region / roll | tool | job id | canvas / mask / seed | cost line | verdict | reason |
|---|---|---|---|---|---|---|---|
| 1 | S1 roll 1 — delta shore and spit | inpaint_image | 3fec50bc-8563-4445-a185-2d3d20f4cdca | crop 512x324 @ (348,700) (30d27f3) / mask 428x284 @ (44,40) / seed 6001 | cost: ~40 generations | **REJECT** | The coast is right — no stripe, diagonal bending shore, surf/sand/rock/shallows, angled dunes, braided channels into flats, spit hooks south. But the flats run too far south and the Sunward Strand anchor (511,860) loses its beach (D0033 §3 / GOV-03 §3). Not a drawing failure: the intent is changed for roll 2, not the seed. rejected/atlas/S1_r1.png + S1_r1_sunward_x4.png |
| 2 | S1 roll 2 — same crop/rect, changed intent | inpaint_image | 7922d150-b123-4b7e-a389-8ba753f09d66 | crop 512x324 @ (348,700) (30d27f3) / mask 428x284 @ (44,40) / seed 6011 | cost: ~40 generations | **ACCEPT** | Intent changed, not the seed: flats confined to the upper third, a broad sand beach with angled dunes named across the WHOLE middle of the picture so the Sunward Strand anchor (511,860) keeps a beach; sea explicitly "kept exactly where it already is" |

## S1 — the delta shore, the Sunward strand and the spit (ACCEPTED)

| | |
|---|---|
| Crop | `src/atlas/S1_crop.png`, origin (348,700), 512×324, published at `30d27f3` |
| Inpaint | 428×284 at (44,40) — frozen margins 44 left / 40 top / 40 right / 0 bottom (canvas edge) |
| Authored rect | atlas **392–820 × 740–1024** · ramps left 32, right 24, top 32, bottom 0 · salt **60** · `coreAuthor: true` (the apron enters the core's bottom rim) |
| Mask | 98,990 authorized · 18,792 feathered · 0 blocked |
| Containment | changed-inside-mask 117,735; changed-outside-mask 3,768 (all inside the frozen margins, blocked at packaging); changed bbox (44,40)..(471,323) = the inpaint rectangle |
| Goldens re-authored | `flock_south`, `south_strand_w`, `south_strand_e` — all three declared in `reauthorizes` and re-extracted from `raw/atlas/S1_pre_guard.png` in this commit (D0033). No registry rect edited. |
| Guards | `package-art.js` green after re-extraction; core drift 0; 15 goldens held. `--check`: the only problems are eight `assets/art/v1/ambient/traveler_plate_bronzepick_mine_f*.png` written by PROD-EQUIPMENT mid-flight — not mine, `world/atlas_base.png` is up to date. |
| `atlas-qa.js` | repeated 10×10 sprite pairs **0**; orphan flecks 1,032 = **62.2 per 10k px**, measured **down** from the same rect's BEFORE rate of 77.2 (the metric counts the sea's authored white ticks) |
| Longest straight edge runs | horizontal 29 px at y=796 (a silt-bar tonal step inside the flats, not a line); vertical 27 px at x=809 (the spit's own shoreline). Both looked at ×6: `review/atlas/S1_r2_runs_x6.png`. |
| Evidence | `review/atlas/S1_before_{fov,x2}.png`, `S1_r2_x2.png`, `S1_preview_{x2,fov_x2}.png`, `S1_r2_fov_sunward_x2.png`, `S1_after_{full,x2,fov}.png`, `S1_r2_anchor_x5.png`, `S1_flock_ba_x6.png` |

**Read.** The latitude stripe is gone. Marsh wets into grey silt in fingers;
braided channels converge into one trunk that reaches the sea past silt bars; a
broad sand beach with dune ridges set at an angle and gorse-dotted machair
behind runs diagonally across the middle, narrowing and swinging as it goes; a
creek cuts it at a small rock headland; a one-pixel surf line and a ragged
shoal band follow the sand; the wooded headland keeps its trees and its sand
rim continues as a spit hooking south into the sea. At 197×426 ×2 the shore
changes direction more than twice, sand width varies well over 2:1, and no band
spans the view.

**Sunward Strand anchor (511,860), measured, not asserted.** Sand-family
coverage in the marker box 501–521 × 850–870: **before 2.3 %, after 2.8 %** —
the anchor is not regressed. In the wider 40² box it falls 28.2 % → 12.3 %: the
marker now sits on the dune/machair lip with the beach immediately south of it
rather than in the middle of the old sand band. Named as residual in the
report; not chased with a third roll, because roll 1 proved a third variation
risks the best painting in the territory for ~20 px of sand.

| # | region / roll | tool | job id | canvas / mask / seed | cost line | verdict | reason |
|---|---|---|---|---|---|---|---|
| 3 | S2 roll 1 — the interior sand stripe and the SW wood edge | inpaint_image | 24eb1233-afd0-4d8a-9ecf-63cd3b9c5242 | crop 512x324 @ (128,700) (b2ec6a3, cut from the composite S1 shipped into) / mask 268x284 @ (44,40) / seed 6002 | cost: ~40 generations | **ACCEPT** | Measured first: inside the rect 172-440 x 740-1024 there are only scattered pond/beck pixels and NO sea, so the y 810-870 sand belt here is sand in the middle of the land. Intent: no sea, therefore no beach — heath, gorse, bracken and a beck replace the belt; the wood's straight top edge breaks into bays and copses; the blue-rimmed orchard becomes ordinary broadleaf; machair only at the far right where S1's dune belt starts; the reserved storm-knoll pocket (168-264 x 816-952) kept plain and open for LANDMARKS |

## S2 — the interior sand stripe and the SW wood edge (ACCEPTED)

| | |
|---|---|
| Crop | `src/atlas/S2_crop.png`, origin (128,700), 512×324, cut from the composite S1 shipped into, published at `b2ec6a3` |
| Inpaint | 268×284 at (44,40) — frozen margins 44 left / 40 top / **200 right** (all of S1's new coast, so PixelLab re-seats against it) / 0 bottom (canvas edge) |
| Authored rect | atlas **172–440 × 740–1024** · ramps left 32, right 32, top 32, bottom 0 · salt **61** · `coreAuthor: true` (256–440 × 740–768 is core rim) |
| Mask | 54,013 authorized · 17,931 feathered · 21,528 blocked (all in the frozen margins — `south_strand_e`'s and `flock_south`'s keepouts; only 4,168 zero-alpha px fall inside the authored rect, and those are the ramp edges themselves) |
| Containment | changed-inside-mask 71,934; changed-outside-mask 4,165 (frozen margin, blocked at packaging); changed bbox = the inpaint rectangle exactly |
| Goldens re-authored | `south_strand_w` — declared and re-extracted from `raw/atlas/S2_pre_guard.png` in this commit. Registry rect unchanged. |
| Guards | `package-art.js` green; `--check` **fully green, 1,827 files up to date**; core drift 0; 15 goldens held. `check-art-palette.js` and `check-tile-seam.js` green. |
| `atlas-qa.js` | repeated 10×10 sprite pairs **0**; orphan flecks 1,017 (the same rect measured 1,370 before — the metric is dominated by the sea's authored white ticks) |
| **Stripe kill, measured** | sand-family coverage in the old belt **172–440 × 810–870: before 31.9 %, after 2.3 %** |
| Straight runs | no vertical run ≥14 px anywhere in the rect. Longest horizontal 19 px at y=828 x 172–191 — the ramp meeting the *untouched* old strand at the S2/S3 boundary; S3's rect (0–256) overwrites it. Next: 15 px at y=824 x 392, which is the beck's own bank (looked at ×6: `review/atlas/S2_r1_runs_x6.png`). |
| Evidence | `review/atlas/S2_before_{fov,x2}.png`, `S2_r1_x2.png`, `S2_preview_{x2,fov_x2}.png`, `S2_r1_runs_x6.png`, `S2_after_{full,x2,fov}.png` |

**Read.** The sand belt that ran across dry land is gone: rough grazing and
heath, gorse clumps, bracken, boulders and a beck that winds east into the
marsh. The wood no longer ends on a ruler — bays, promontories and stepping
copses with lone oaks. The pale blue-rimmed orchard is ordinary broadleaf
woodland in the map's own greens. The grass pales into machair only where S1's
dune belt starts, and the S1/S2 join at x≈440 does not read. The reserved
storm-knoll pocket (168–264 × 816–952) is plain open heath, ready for LANDMARKS.

| # | region / roll | tool | job id | canvas / mask / seed | cost line | verdict | reason |
|---|---|---|---|---|---|---|---|
| 4 | S3 roll 1 — the SW corner's vertical shore | inpaint_image | aec776d8-ce2d-45e7-b152-e37459caea9d | crop 300x364 @ (0,660) (c58265f, cut from the composite S2 shipped into) / mask 256x324 @ (0,40) / seed 6003 | cost: ~40 generations | **REJECT** — the coast is right (curving bay, rock headland, boulders, varying sand, creek, surf, angled dunes; lime slab gone) but the generation deleted the SW wood and left a ~120x90 dead zone with a brown stain. Intent changed for roll 2, not the seed. rejected/atlas/S3_r1.png + S3_r1_deadzone_x3.png | BEFORE, measured: the west shore is a near-vertical turquoise cut with a uniform sand ribbon and banded shallows in a brighter dialect than the rest of the sea; the wood ends on a razor vertical (longest straight vertical edge run in 0-256 x 860-1024 = 16 px at x=113, plus 14 px at x=18). Intent: a shore that swings — headland, bay, varying sand width, surf, angled dunes, machair, a creek; the wood's west face broken into copses; the lime slab given structure; the reserved storm-knoll pocket left plain |
| 5 | S3 roll 2 — same crop/rect, changed intent | inpaint_image | 33079c45-666a-4e34-94d7-974224da0719 | crop 300x364 @ (0,660) (c58265f) / mask 256x324 @ (0,40) / seed 6013 | cost: ~40 generations | **ACCEPT** | Intent changed, not the seed: the wood is named as KEPT ("it is not cleared"), only its straight western and northern edges break into copses; the open ground is confined to the upper middle and must be textured heath, "never an empty field"; "no bare brown patches" added to the forbidden list |

## S3 — the SW corner (ACCEPTED)

| | |
|---|---|
| Crop | `src/atlas/S3_crop.png`, origin (0,660), 300×364, cut from the composite S2 shipped into, published at `c58265f` |
| Inpaint | 256×324 at (0,40) — frozen margins 0 left (canvas edge) / 40 top / 44 right / 0 bottom (canvas edge) |
| Authored rect | atlas **0–256 × 700–1024** · ramps left 0 (canvas), right 32, top 32, bottom 0 (canvas) · salt **62** · `coreAuthor: false` (the rect stops one pixel short of x=256) |
| Mask | 69,066 authorized · 8,861 feathered · 2,112 blocked (`south_strand_w`'s keepout, in the frozen right margin) |
| Containment | changed-inside-mask 77,911; changed-outside-mask 5,090 (frozen margins, blocked at packaging) |
| Goldens re-authored | `south_strand_w`, re-extracted from `raw/atlas/S3_pre_guard.png` in this commit. Registry rect unchanged. |
| Guards | `package-art.js` **green** (1,827 files; core drift 0, 15 goldens held). `check-art-palette.js` green. `--check` currently throws ENOENT on `EPO03/out/equip/ls/traveler_coat_longsword_brace_f0.png` — PROD-EQUIPMENT's source mid-flight, not mine; an earlier `--check` this session was fully green with S1+S2 shipped. |
| `atlas-qa.js` | repeated 10×10 sprite pairs **0**; orphan flecks 310 |
| Straight runs | longest vertical 20 px at x=53 y 825 and 17 px at x=17 y 875 — both the rocky headland's own rock/grass and shore edges (`review/atlas/S3_r2_runs_x6.png`, left panel). Longest horizontal 15 px at y=795. |
| Evidence | `review/atlas/S3_before_{fov,x2}.png`, `S3_r1_x2.png` (rejected), `S3_r2_x2.png`, `S3_preview_x2.png`, `S3_r2_fov160_x2.png` (the DIR-01 named FOV), `S3_r2_fov_seam_x2.png`, `S3_r2_runs_x6.png`, `S3_after_{full,x2,fov}.png` |

**The water conform, and why a new tool rather than a third roll.** The roll came
back with its own sea — `#438383` and hundreds of neighbours where the map's sea
is one flat `#3e98a6` — the DIR-02 failure mode "a mask reaching open sea forces
the model to invent water". The global conform in `package-art.js` cannot repair
it: `ocean_unify`'s rectangles start at **x=300**, so the south-western wedge has
never been inside them, which is also why the sea there was *already* an
off-dialect turquoise (`#4eb9a5` / `#2c9da3`, 82 %) before this round. Rather
than spend a third roll on water PixelLab has never once got right here (FMPO02:
0/4), the region's own open water is remapped by `tools/conform-region-water.js`
using `ocean_unify`'s own algorithm and its own target swatch: measure, map
mean/std, snap to the target's palette — every output pixel is a colour the
accepted sea is already made of (A-2; nothing averaged, nothing invented). The
SW sea now measures **`#3e98a6` 100 %** against the east sea's `#3e98a6` 99 %,
so the corner's turquoise panel is gone as well as the shoreline.
**What the tool got wrong first, and now guards against:** `isDeep` alone also
matches the blue-green outline pixels inside dark foliage, and the first run
turned the wood cyan. A pixel is conformed only when ≥ 80 % of its 9×9
neighbourhood is also deep — open-water interiors only.

**Read.** The west shore is no longer a vertical turquoise cut: it swings out
into a low rocky headland with boulders standing in the water, back into a bay
with a wide beach, and the sand narrows to nothing at the rock. Surf hugs it; a
creek winds out of the wood and cuts the beach. Behind it dune ridges at an
angle, then gorse-and-bracken heath with boulders, then the wood — which is
still there, now with a broken edge instead of a slab. The lime slab is gone.
At the DIR-01 FOV (160,900) the stack reads wood → heath → dune → shore.

**Residual, named.** At ×6 there is a tonal step ~17 px long at x≈244 where S3's
heath meets S2's sward inside the right ramp. At 197×426 ×2
(`S3_r2_fov_seam_x2.png`) it does not read. A bridge region is the prescribed
fix and is affordable within the cap.
