# EPO03 — WORLD_NORTH ledger (PROD-WORLD-NORTH, team `north`, salts 40–59)

Cap **100 generations**. Territory 0–600 × 0–300 (DIR-01). Family total = the
sum of the tool's own cost lines below — never a balance delta (M-17); no
`get_balance` call is made by this team.

Regions: `E/src/atlas/regions_north.json` (pending) → `E/out/atlas/manifest_north.json`
(accepted only). Evidence: `E/review/atlas/NA_*`, `NB_*`. Rejected rolls:
`E/rejected/atlas/`.

| job id | tool | canvas (region, inpaint rect, seed) | cost line | verdict | reason |
|---|---|---|---|---|---|
| `6672f5c4-4545-4efb-8abe-5c5e3a49bbb2` | inpaint_image | NA 316x164 @ (0,176), inpaint 0,40 276x84, seed 40 | ~25 generations | **ACCEPT** | NW snowline r1. The horizontal snow/meadow ruler line at y=267 and the vertical patch seam at x=171 are gone; the olive dead-zone smear at 170-214 x 220-270 is now moraine, rust bracken and snow tongues between rock knolls, firs thinning upward, the beck running south. changed-outside-mask 4,941 (blocked). repeated 10x10 pairs 0; orphan flecks 475 (peer range 214-609). |
| `ed63f7d1-106b-42e1-add7-475a3b0786e5` | inpaint_image | NB 216x188 @ (208,148), inpaint 48,44 120x104, seed 41 | ~20 generations | **ACCEPT** | Core treeline r1. The honeycomb cell-net at 278-356 x 227-252 is painted out; the gridded identical outlier firs become an uneven thinning of unequal sizes; the canopy edge climbs in a spur with snow bays between the fingers. N2 crag byte-held (verify bbox stops at crop 167,147). changed-outside-mask 2,573 (blocked); mask blocked 2,640 (golden ramp toward frostmere_north_wall). repeated 10x10 pairs 0; orphan flecks 325. Near-duplicate sprite-bearing 10x10 blocks in the rect: 34 -> 20 pairs. |
