# EPO03 — WORLD_SOUTH ledger (PROD-WORLD-SOUTH, territory 0–860 × 700–1024)

Cap **440 generations**. One row per job: what was asked, tool, job id, the
tool's own cost line, verdict, reason. Family total = the sum of cost lines —
never a balance delta (M-17). Region specs: `src/atlas/regions_south.json`;
accepted regions: `out/atlas/manifest_south.json`.

| # | region / roll | tool | job id | canvas / mask / seed | cost line | verdict | reason |
|---|---|---|---|---|---|---|---|
| 1 | S1 roll 1 — delta shore and spit | inpaint_image | 3fec50bc-8563-4445-a185-2d3d20f4cdca | crop 512x324 @ (348,700) (30d27f3) / mask 428x284 @ (44,40) / seed 6001 | cost: ~40 generations | **REJECT** | The coast is right — no stripe, diagonal bending shore, surf/sand/rock/shallows, angled dunes, braided channels into flats, spit hooks south. But the flats run too far south and the Sunward Strand anchor (511,860) loses its beach (D0033 §3 / GOV-03 §3). Not a drawing failure: the intent is changed for roll 2, not the seed. rejected/atlas/S1_r1.png + S1_r1_sunward_x4.png |
| 2 | S1 roll 2 — same crop/rect, changed intent | inpaint_image | 7922d150-b123-4b7e-a389-8ba753f09d66 | crop 512x324 @ (348,700) (30d27f3) / mask 428x284 @ (44,40) / seed 6011 | cost: ~40 generations | _pending_ | Intent changed, not the seed: flats confined to the upper third, a broad sand beach with angled dunes named across the WHOLE middle of the picture so the Sunward Strand anchor (511,860) keeps a beach; sea explicitly "kept exactly where it already is" |
