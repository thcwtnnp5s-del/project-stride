# FMPO02 — TERRAIN ledger (world atlas regional recomposition)

Cap: **450 generations**. Balance at start: **9551** (used 449 of 10000, resets
2026-10-01).

| job/id | tool | canvas | cost | ACCEPT/REJECT/RE-ROLL | reason |
|---|---|---|---|---|---|
| 14236bc8-09a1-4584-8961-f6101c354284 | inpaint_image | 196x298 (W1, mask 100x184 @48,48, seed 701) | 25 | ACCEPT | W1 West Verge — canopy face breaks into copses, conifer confetti becomes oak groves; 0 px outside mask; guards green |
| 6bd327c0-4022-4e19-883e-8c4abad6c39b | inpaint_image | 228x338 (W2, mask 172x212 @8,48, seed 702) | 25 | ACCEPT | W2 West Foothill Meadows — hedged pasture, beck with a ford, copses, rock knolls replace dead sward; 0 px outside mask; guards green |
| dd406075-6704-4a10-85a2-03859a636227 | inpaint_image | 248x290 (W3, mask 192x190 @8,40, seed 703) | 25 | REJECT | W3 roll 1 — the generated area is a paler rectangular slab with four razor edges; a drystone sheepfold drawn as a literal rounded rectangle; hollow-ways read as brown roads; gorse repeats as identical dot clusters. rejected/atlas/W3_r1.png |
| bd3a4faf-4902-4786-9511-84a5ab3b3dda | inpaint_image | 248x290 (W3, mask 192x190 @8,40, seed 713) | 25 | ACCEPT | W3 roll 2 — rough grazing, gorse, boulder outcrops, 3 repeated snow-cones gone; no rectangle; 0 dup sprites; 0 px outside mask; guards green |
| fbff25c6-13e8-499a-b176-1321e9c7e297 | inpaint_image | 300x298 (N1, mask 252x282 @0,0, seed 704) | 25 | ACCEPT | N1 Snow Country West — honeycomb crack field becomes wind-drifted sastrugi, nunataks, tarns, rime conifers; snowline ruler edge gone; 132 red border px despeckled; guards green |
| 4bea2aa9-25d2-4fd1-beb4-d2af69bfc385 | inpaint_image | 372x300 (N2, mask 280x236 @44,0, seed 705) | 40 | REJECT | N2 roll 1 — geography right (crevasses, glacier, crag) but drawn airbrushed: soft blended shading, no cel bands, no pixel staircase. A dialect step against N1 (criterion 4). rejected/atlas/N2_r1.png |
| 80783de4-d17d-4a71-92ad-748063519022 | reduce_colors | 372x300 (N2 roll 1, 256-swatch master palette) | 0.1 | REJECT | Cheap fix attempt: cut 13,192 colours to 251, but the softness is structural (blended forms), not palette. N1 itself has 17,328 colours and reads crisp. rejected/atlas/N2_r1_quant.png |
| d416d1b9-8da5-481d-834e-0114f52ad63d | inpaint_image | 372x300 (N2, mask 280x236 @44,0, seed 715) | 40 | ACCEPT | N2 roll 2 — hard cel bands and pixel staircases; crevasse field, glacier tongues, moraine, tower crag, crisp peaks; honeycomb gone; guards green |
| afcd4512-e318-4abf-a269-c3d819fce180 | inpaint_image | 160x300 (NB1 N1/N2 bridge, mask 72x250 @44,0, seed 716) | 25 | ACCEPT | The 12 px crop overlap left a straight vertical seam at atlas x=246 down the whole phone viewport; bridge inpaint over the composite carries one snow slope across. Crop published at f71aa30 |
| a2ec1581-030d-45d4-a650-38013e85a92b | inpaint_image | 356x304 (N3, mask 268x232 @44,0, seed 706) | 40 | REJECT | N3 roll 1 — asking for "large plates with water between them" produced the exact honeycomb tessellation the prompt forbade, plus a dark navy rectangle for the sea. rejected/atlas/N3_r1.png |
| 378ad451-f947-49b2-aee6-5eb425a85cc0 | inpaint_image | 356x304 (N3, mask 268x232 @44,0, seed 717) | 40 | REJECT | N3 roll 2 — honeycomb gone and the shelf reads well, but the top third came back as a FLAT solid teal rectangle of generated open water (ART-03 §3: never generate flat water, 0/4 historically) plus a drawn red border. Second failure -> region DEFERRED, not chased. rejected/atlas/N3_r2.png |
| 4982f64d-6de8-4f43-95e9-0b6d960081e6 | inpaint_image | 300x282 (S1, mask 204x106 @48,96, seed 707) | 25 | pending | S1 SW Gloaming — shaped around south_strand_w |

Requested: — · Accepted: — · Rejected: —

Balance at end: —
