# COMBAT_STAGE — FMPO02 Wave 2 ledger

Family: combat (stage backdrops + HUD chrome). Cap: 160 generations (own spend, tracked below —
the account `get_balance` figure is shared across every concurrent PROD-* lead this wave, so its
start/end delta is not this family's spend alone).

`get_balance` at open: generations_remaining 9229, generations_used 771 (of 10000 this cycle).
`get_balance` at close: generations_remaining 8630, generations_used 1369.

## Backdrops (192x128, inpaint_image, mask 192x40 at (0,0), 8-row overlap with original rows 32-39)

| job/id | tool | canvas | cost | ACCEPT/REJECT/RE-ROLL | reason |
|---|---|---|---|---|---|
| 422c1032-f890-4b42-8ff7-4cf17cb864c5 | inpaint_image | 192x128 | 20 | ACCEPT | forest: seam at row 32 invisible, higher trunks + dusk canopy gaps, no creatures, top less busy than the ground/trunk band |
| 893ea325-23fd-4af8-8d10-524c4423c7d4 | inpaint_image | 192x128 | 20 | REJECT | mine r1: drew an exterior sunburst medallion + open barn rafters/daylight above an underground doorway — breaks the enclosed-mine premise |
| 5af76790-7093-40c9-8f79-ac4b65adf5f2 | inpaint_image (re-roll, seed 7712) | 192x128 | 20 | ACCEPT | mine r2: continuing rock ceiling arch, timber cross-beam, one hanging lantern, no sun/sky; seam invisible |
| 06bd0868-fa63-4e4a-ac48-c7a13d5cadf5 | inpaint_image | 192x128 | 20 | ACCEPT | hollow: twisted roots continue upward into violet-grey gloom with a moon; seam invisible |
| 6e200db6-ad5c-4501-b2cb-7c6d74b8f052 | inpaint_image | 192x128 | 20 | ACCEPT | frostmere: distant mountains + overcast pale sun above the existing pine treeline; seam invisible |

Backdrop subtotal: 5 jobs × 20 = **100 generations**. Forest/hollow/frostmere accepted on the
first roll; mine used its one allowed re-roll and passed.

## HUD (create_image_pixen, transparent, 3 candidates each unless noted)

| job/id | tool | canvas | cost | ACCEPT/REJECT/RE-ROLL | reason |
|---|---|---|---|---|---|
| 0875981c (seed 11) | create_image_pixen | 16x16 | 1 | ACCEPT (hp_gauge cap+band source) | clean rounded leather nub with a flat tileable cross-section (cols 7-12 share identical vertical extent) |
| 07d15325 (seed 12) | create_image_pixen | 16x16 | 1 | REJECT | almost fully transparent/failed render |
| ed319d12 (seed 13) | create_image_pixen | 16x16 | 1 | REJECT | bright gold/red ornate rim reads as a gem/ornament, off-family shine |
| 635dd3cd (seed 21, turn_a) | create_image_pixen | 24x24 | 1 | REJECT | reads as a knapsack/pouch with strap+buckle, too depicted for a plain tab |
| 6da3738f (seed 22, turn_b) | create_image_pixen | 24x24 | 1 | ACCEPT | clean rolled-leather coin/tab, single outline, material only |
| 584a7279 (seed 23, turn_c) | create_image_pixen | 24x24 | 1 | REJECT | has a small dangling tool-charm silhouette — a depicted object, not plain material |
| 91df6ad2 (seed 31, narr_a) | create_image_pixen | 16x16 | 1 | REJECT | roughly square stamp/seal, not a strip cross-section |
| 13a9d281 (seed 32, narr_b) | create_image_pixen | 16x16 | 1 | ACCEPT (narration tile source) | flat continuous middle band (rows 5-9 solid cols 1-14), ragged top/bottom |
| ae01f11f (seed 33, narr_c) | create_image_pixen | 16x16 | 1 | REJECT | good torn-edge silhouette but both side columns are fully transparent — tiles as disconnected islands, not a strip |
| d7914f6c (seed 41, attack_a) | create_image_pixen | 64x32 | 1 | REJECT | crossed-dagger emblem baked in — plates must carry no icon |
| 8879d664 (seed 42, attack_b) | create_image_pixen | 64x32 | 1 | ACCEPT | plain oval, dark rim, no icon, oxblood family |
| 3e583368 (seed 43, attack_c) | create_image_pixen | 64x32 | 1 | REJECT | hexagonal silver+red starburst — too ornate, breaks chassis-DNA match with the other two plates |
| 501d0072 (seed 51, brace_a) | create_image_pixen | 64x32 | 1 | REJECT | rendered as a full shield silhouette, not a plate — shape family mismatch |
| 98ea9b33 (seed 52, brace_b) | create_image_pixen | 64x32 | 1 | ACCEPT | plain blue-steel diamond, no icon |
| e8ffaeee (seed 53, brace_c) | create_image_pixen | 64x32 | 1 | REJECT | acceptable but a rougher bevel than brace_b, redundant once b is picked |
| 15d456c7 (seed 61, eat_a) | create_image_pixen | 64x32 | 1 | ACCEPT | plain wood disc, flat grain, no depicted object |
| eee30909 (seed 62, eat_b) | create_image_pixen | 64x32 | 1 | REJECT | reads as a coiled-rope/wreath with a stick handle — a depicted object, not plain material |
| 13375c58 (seed 63, eat_c) | create_image_pixen | 64x32 | 1 | REJECT | radial cut-log rings read as a depicted tree-stump object, more ornament than material |
| f9b5aadd (seed 71, icon_attack_a) | create_image_pixen | 16x16 | 1 | REJECT | readable but softer silhouette than b |
| 65df796a (seed 72, icon_attack_b) | create_image_pixen | 16x16 | 1 | ACCEPT | clean crossed-swords silhouette, clear hilts |
| 18261b06 (seed 73, icon_attack_c) | create_image_pixen | 16x16 | 1 | REJECT | near-duplicate of b, slightly busier hilt color |
| dd736558 (seed 81, icon_brace_a) | create_image_pixen | 16x16 | 1 | REJECT | reads as a multicoloured gem/amulet, not a shield; includes near-teal fleck |
| d2b36759 (seed 82, icon_brace_b) | create_image_pixen | 16x16 | 1 | REJECT | reads as a wrapped cloth/mirror shard more than a shield |
| d6232ff4 (seed 83, icon_brace_c) | create_image_pixen | 16x16 | 1 | ACCEPT | clearest round-shield-with-straps read |
| 1ba64781 (seed 91, icon_eat_a) | create_image_pixen | 16x16 | 1 | REJECT | green pea flecks add a second hue family beyond the bowl |
| f2df328a (seed 92, icon_eat_b) | create_image_pixen | 16x16 | 1 | REJECT | acceptable but busier stew texture than c |
| 75439cd8 (seed 93, icon_eat_c) | create_image_pixen | 16x16 | 1 | ACCEPT | simplest solid warm bowl-of-food read |
| 5ac17be6 (seed 101, icon_retreat_a) | create_image_pixen | 16x16 | 1 | REJECT | unreadable — background static/noise, no clear silhouette |
| e65c2b8e (seed 102, icon_retreat_b) | create_image_pixen | 16x16 | 1 | REJECT | two dark blobs, does not read as footprints |
| 25fa3633 (seed 103, icon_retreat_c) | create_image_pixen | 16x16 | 1 | REJECT | trail shape has stray magenta/pink pixels — palette violation (out-of-family hue) |
| 1f5c42b9 (seed 201, icon_retreat re-roll) | create_image_pixen | 16x16 | 1 | REJECT | re-roll still reads as two abstract blobs, not footprints |

HUD subtotal: 30 generations. `reduce_colors` (hp_gauge cap+band composite, plate_attack, plate_eat)
× 3 successful calls × 0.1 = 0.3 generations (2 more calls errored on inline-base64 truncation before
processing and were not billed). HUD total ≈ **30.3 generations**.

## Family total

100 (backdrop) + 30.3 (HUD) ≈ **130.3 of the 160 cap**. Retreat icon spent 4 of its budget across
one initial set of 3 plus one re-roll and never produced a readable footprint glyph; per the "fails
twice, deliver nothing" rule it ships with **no icon** — which matches ART-09 §5's own design
(Retreat is a plain `StrideButton.secondary` text link, never a plate/icon).
