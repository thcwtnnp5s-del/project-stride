# DIR-02 — Regional environment: the transition specification (EPO03)

Atlas px (world ×6; phone FOV 197×426). Sources: 59c4723 master, `zone_*` crops, FMPO02 region log, D0033. 0 generations spent.

## STYLE LOCK — measured on the core master, binding on every producer

One-pixel dark outline (median 1 px; 2 px only where crowns stack): `#0d1c19` on vegetation, `#26242a` on rock. Flat cel steps, hard one-pixel edges, no anti-aliasing. Canopy: four greens (`#447534` → `#3e6a39` → `#305833` → outline), crowns on a 6–8 px pitch (≈40 px on the phone) in two or three value plies; sward `#4d7f37`/`#3e6a39`. Snow: four values (`#ecf6fe #ddeff6 #d0e6f4 #acd4e7`), sastrugi as long NW→SE bands. Rock three values (`#88796b #5c5248 #3c3a41`); sand three (`#f6d69e #e3c789 #d7b982`); roads `#ddc2a0`, 4–6 px, unoutlined. Water: open sea one flat `#3e98a6` (one colour covers 90 % of any sea rect) with sparse 2–4 px white ticks; shallows a ragged 4–8 px `#66ccb1`/`#4eb9a5` band; channels `#2c9da3`; ice `#e4f6fe` with `#3e98a6` leads. A roll whose 90 %-coverage colour count is over twice the adjoining master rect's is a dialect step — reject before compositing.

## Prompt spine (verbatim; the transition sentence swaps in)

`Hard-edged 16-bit pixel-art overworld map, top-down, like a SNES atlas: crisp one-pixel dark outlines, flat cel bands of three or four values with a hard one-pixel step, visible pixel staircases, no gradients, no airbrush, no anti-aliasing. <TRANSITION SENTENCE>. Continue the surrounding terrain in its own colours, solid opaque ground everywhere, hold the neighbouring grass, snow or sand edge to edge with no lighter panel. No towers, buildings, roads, text, borders or frames unless named. No straight edges, no rectangles, no repeated identical sprites, no hex, cell or honeycomb pattern, no open sea.`

The hand leads, geography follows (the N2 inversion). Never name a countable unit ("plates at least twelve pixels" became a honeycomb). The sentence may not ask for what the spine forbids (W3 roll 1).

## Mask and margin rules (every transition)

Crop the *current* composite, ≤512 per side, ≥44 px frozen margin per free side, pushed by commit SHA. Ramps one-sided, alpha 0 on the inpaint edge rising inward: **24 px on a free edge, 32 px across a texture change**; width wander ±60 %, unique salt, half-alpha contour ±10 px, never straight. Agreement grading; dither-select only; ramp edges in uniform terrain. Crops overlapping <60 px get a bridge crop. `no_background:false` wherever the crop carries off-canvas padding. Alpha 0 within 20 px of any golden not re-extracted in the same commit. Core re-base regions composite before the `approved` snapshot (D0033 §2); `rimBlock` on elsewhere.

## The seven transitions

| Transition | Rects | Transition sentence | Must eliminate | 197×426 blind check |
|---|---|---|---|---|
| FOREST→PLAINS | core west face **236–320 × 380–580** (re-base); S1 north edge **96–300 × 846–900** (re-extract `south_strand_w`) | Canopy breaking westward into bays, promontories, stepping copses of three to seven crowns and lone oaks over sixty to eighty pixels, bracken under the outliers, then open meadow | treeline walls, density shifts, patch rectangles, dead zones | cannot point to where the wood ends; ≥3 outlier steps over ≥40 px; no vertical run >12 px |
| PLAINS→MARSH | delta apron **372–676 × 740–830** (re-extract `flock_south`; rim re-base); marsh lip **396–440 × 660–740** | Sward wetting into marsh: reed clumps, waterlogged ground darkening in fingers, braided channels converging east into one trunk that reaches the sea through silt bars and tidal flats | marsh joins, rivers that do not read, layer-cake banding, patch rectangles | one channel traceable marsh→sea; the marsh line fingered; no horizontal run >12 px |
| PLAINS→MOUNTAIN | far-west wall **0–70 × 540–780**; road loop **0–260 × 460–630** (re-extract the four road goldens) | Foothills rising to the Worldspine: pasture into rock knolls, scree fans, a snow-line, a col, boulders densest at the wall's foot; the road follows a beck, fords it and switchbacks into the pass | slab terrain, strange road bends, landmarks sitting on terrain, dead zones | rock density rises toward the wall; every road bend has a cause; no grey slab |
| FOREST→SNOW | core treeline **256–420 × 220–300** (re-base) | Conifers climbing into altitude: dark firs thinning to pale rime-flagged singles, drifts pooling between them, snow under the last trees, blue shadows deepening upward | snow cut-lines, treeline walls, style mismatches, straight boundaries | pines sparser and paler upward over ≥30 px; no horizontal run >12 px; one hand across GAP, N2, core |
| SNOW→ICE | calving front **620–820 × 40–290** (mask stops at the ice edge; sea untouched); crack-net **772–1010 × 30–200** gated | Snow shelf thickening into a glacial front: a graded shelf edge, calved bergs, brash ice, narrow winding leads; the pack-ice interior kept | straight boundaries, slab terrain, the cell net, style mismatches | shelf edge lobed with bergs beyond it; the sea is the existing sea; no white diagonal |
| COAST→SEA | south band **0–800 × 780–1024**, SW corner **0–260 × 760–1024**, SE spit **628–786 × 806–880** (re-extract both strand goldens; Sunward Strand beach survives in place) | A coast, not a band: shore running diagonally and curving, dune ridges at an angle, machair grading landward into sward through gorse, creeks cutting the beach, rock headlands, a ragged shoal band and a one-pixel surf line hugging the sand | layer-cake banding, surf/shore mismatch, straight boundaries, patch rectangles | shoreline changes direction ≥2× in the FOV; surf follows it; no latitude stripe; sand only where sea reaches |
| VOLCANIC | volcano foot **600–740 × 400–470** (retouch only; `volcano_east_cliff` untouched) | Ash fans and scorched ground reaching from the cone in tongues, black rock through the green, heat-cracked earth near the vents, no ring | slab terrain, dead zones, style mismatches | ash reaches into green as tongues; cone and foot one painting; east cliff byte-held |

Worst three: COAST→SEA (the layer cake, P0), FOREST→PLAINS at the core face, SNOW→ICE at the white diagonal.

## Three PixelLab failure modes (FMPO02 log) and the fix

1. **Airbrushed dialect** (N2 roll 1). Fix: the spine leads with the hand; `reduce_colors` does not repair it (proved).
2. **Invented water, tessellation, tone panel** (N3 rolls 1–2; W3 roll 1): a mask reaching open sea forces a flat teal rectangle; a countable unit becomes honeycomb; a lighter panel no ramp dissolves. Fix: mask stops where land or ice stops; water stays deterministic; "hold the grass edge to edge".
3. **Cut-outs and drawn borders** (S2 roll 1 68 % transparent; N1 132 px red dashed border). Fix: `no_background:false` plus "solid opaque ground everywhere"; `despeckle.js red` before review; inspect every roll's edges.
