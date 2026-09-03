# EPO03 — WORLD_EAST ledger (PROD-WORLD-EAST, team `east`, cap 140)

Territory 600–1024 × 0–700 (DIR-01). One row per PixelLab job; the cost is
the tool's own cost line, never a balance delta (M-17). Family total = the
sum of the cost column. Salts 100–119. Regions file
`src/atlas/regions_east.json`; manifest `out/atlas/manifest_east.json`.

| # | Region / ask | Tool | Job id | Seed | Cost | Verdict | Reason / evidence |
|---|---|---|---|---|---:|---|---|
| 1 | E1 roll 1 — calving front + honeycomb in one 260x210 ask, crop 580,0 340x300 | `inpaint_image` | `a3a708e0-44fe-4154-9cab-117e3912e4a9` | 1001 | 25 | REJECT | one enormous smooth glacier tongue with airbrushed gradients and an outlined rim; slab terrain, straight mask edge visible, red dashed border. Intent changed: split into E1 front strip + E3 pack interior. `rejected/atlas_E1_r1.txt`, `review/atlas/E1_r1_x2.png` |
| 2 | E1 roll 2 — front strip 750-880 x 40-250, prompt led with broken floes | `inpaint_image` | `260773ad-1d96-4a60-8a03-7a946b6fad5d` | 1002 | 25 | REJECT | drew a NEW honeycomb: near-uniform pebble floes in a net of heavy navy leads, darker than the master`s teal; the straight ice/sea edge was left. Two rolls, two generator patterns → intent changed to a ribbon mask, not a new seed. `review/atlas/E1_r2_x2.png` |
| 3 | E1 roll 3 — RIBBON: authorization cut to a band straddling the ice margin (landMargin 32 / seaMargin 24, `atlas-maskcut.js` extended), pack interior frozen; prompt asks only for the margin | `inpaint_image` | `05f28ed5-05a5-4840-b5c0-40be6e7d2d32` | 1003 | 25 | **ACCEPT** | the hard white diagonal is gone: lobed margin with bays and headlands, a shadow along the ice foot, calved bergs at several sizes, brash thinning seaward. Violet shadow remapped to the neighbouring ice palette (`atlas-quantise`, 13 entries, 0 gens); 185 one-pixel islands filled (`atlas-fleck`, 0 gens). Ice still under Rimespire (824,156) = #e1f5fc. `review/atlas/E1_after_fov_x2.png` |
| 4 | E2 roll 1 — ice-to-volcano join, crop 560,188 240x172, inpaint atlas 600-760 x 228-320, Rimewatch tower holed, Emberhold + east cliff held by their golden keepouts | `inpaint_image` | `e52ddd83-03fc-4b6e-9ad0-5555ea84a394` | 1004 | 20 | pending | submitted 2026-09-02 |

**Deterministic passes (0 generations):** `atlas-quantise.js` palette remap of
E1 (spread 14, palette from atlas 640–900 × 20–260, 13 entries) and a new
`atlas-fleck.js` one-pixel-island fill. Both are A-2 remaps of existing
colours, both tried before spending the cap again (PRODUCTION_RULES §2a).

**Cap:** 140. Spent so far 75 (25 + 25 + 25). Accepted 1, rejected 2.
