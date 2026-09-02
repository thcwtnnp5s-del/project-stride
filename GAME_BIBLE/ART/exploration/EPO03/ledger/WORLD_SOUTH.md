# EPO03 — WORLD_SOUTH ledger (PROD-WORLD-SOUTH, territory 0–860 × 700–1024)

Cap **440 generations**. One row per job: what was asked, tool, job id, the
tool's own cost line, verdict, reason. Family total = the sum of cost lines —
never a balance delta (M-17). Region specs: `src/atlas/regions_south.json`;
accepted regions: `out/atlas/manifest_south.json`.

| # | region / roll | tool | job id | canvas / mask / seed | cost line | verdict | reason |
|---|---|---|---|---|---|---|---|
| 1 | S1 roll 1 — delta shore and spit | inpaint_image | 3fec50bc-8563-4445-a185-2d3d20f4cdca | crop 512x324 @ (348,700) (30d27f3) / mask 428x284 @ (44,40) / seed 6001 | cost: ~40 generations | _pending_ | DIR-02 spine + PLAINS->MARSH apron + COAST->SEA sentence; "no open sea" clause reworded to "no new open sea beyond the existing shore" because the crop legitimately holds the sea |
