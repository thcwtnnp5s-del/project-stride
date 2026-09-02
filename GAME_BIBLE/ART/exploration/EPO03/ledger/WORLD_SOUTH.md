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
| 3 | S2 roll 1 — the interior sand stripe and the SW wood edge | inpaint_image | 24eb1233-afd0-4d8a-9ecf-63cd3b9c5242 | crop 512x324 @ (128,700) (b2ec6a3, cut from the composite S1 shipped into) / mask 268x284 @ (44,40) / seed 6002 | cost: ~40 generations | _pending_ | Measured first: inside the rect 172-440 x 740-1024 there are only scattered pond/beck pixels and NO sea, so the y 810-870 sand belt here is sand in the middle of the land. Intent: no sea, therefore no beach — heath, gorse, bracken and a beck replace the belt; the wood's straight top edge breaks into bays and copses; the blue-rimmed orchard becomes ordinary broadleaf; machair only at the far right where S1's dune belt starts; the reserved storm-knoll pocket (168-264 x 816-952) kept plain and open for LANDMARKS |
