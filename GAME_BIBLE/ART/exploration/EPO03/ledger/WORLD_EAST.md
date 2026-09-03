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
| 4 | E2 roll 1 — ice-to-volcano join, crop 560,188 240x172, inpaint atlas 600-760 x 228-320 | `inpaint_image` | `e52ddd83-03fc-4b6e-9ad0-5555ea84a394` | 1004 | 20 | REJECT | the mask reached the cone, so it rebuilt the cone: rock grew north into the snow, a new crater and pool appeared, the Emberhold tower was painted out, look-alike boulders scattered on the drifts. Intent changed: `cut.freezeDark` freezes every L*<42 pixel, so the silhouette and both towers are byte-exact and only the snow side is authored. `rejected/atlas_E2_r1.txt` |
| 5 | E2 roll 2 — mask cut to the snow side only by `cut.freezeDark` (maxL 42, inflate 3; 2,892 px of rock frozen), prompt names the rock as unchangeable | `inpaint_image` | `370c32bc-38ec-4014-a78f-3bfa580bcf57` | 1005 | 20 | REJECT | freezeDark held: cone and both towers byte-exact. But given a narrow snow band beside a hard silhouette the tool invented an OBJECT — a brown antler/driftwood shape on the drift with three look-alike pebble clusters, and the smear survived. Worse than the butt joint. `rejected/atlas_E2_r2.txt` |
| 6 | E2 as shipped — deterministic: `atlas-fleck.js --dither` snaps the seam smear at atlas 630-755 x 234-286 to its local modal colour (874 px) plus 109 one-pixel islands; no PixelLab call | (none) | — | — | 0 | **ACCEPT** | the dithered smear over the snow west of the cape is gone and the snow reads as flat cel again; silhouette and both towers byte-exact. The AUTHORED ash/steam join did not close — reported, not softened. `review/atlas/E2_after_x2.png` |

**Deterministic passes (0 generations):** `atlas-quantise.js` palette remap of
E1 (spread 14, palette from atlas 640–900 × 20–260, 13 entries) and a new
`atlas-fleck.js` one-pixel-island fill. Both are A-2 remaps of existing
colours, both tried before spending the cap again (PRODUCTION_RULES §2a).

**Cap:** 140. Spent so far 75 (25 + 25 + 25). Accepted 1, rejected 2.
| 7 | E3 roll 1 — the honeycomb, crop 600,20 200x200, inpaint atlas 640-760 x 60-180 (deliberately small); ask is one unbroken sheet with wind-drift bands and a few non-meeting cracks | `inpaint_image` | `5512cd2a-bcba-4745-90b4-1f2e785d3b2c` | 1006 | 20 | **ACCEPT** | the cell net in the middle of the pack becomes one broad banded floe with long non-meeting cracks; near-duplicate 10x10 blocks in 620-800 x 20-220 fall 34.8% -> 26.4%. Palette-remapped and de-stippled deterministically (`atlas-quantise`, `atlas-fleck --dither`, 0 gens). `review/atlas/E3_preview_fov_x2.png` |

**Cap 140 — spent 135** (25 + 25 + 25 + 20 + 20 + 20). Accepted 3 regions
(E1, E2, E3), rejected 3 rolls with written reasons. Two of the three accepted
regions needed a deterministic recovery that cost nothing (`atlas-quantise`,
`atlas-fleck`), and E2 shipped with no generation at all.
