# ENEMIES ledger — FMPO02 Wave 2 (ART-08)

`get_balance` at open: generations_used 450 / 10000 (9550 remaining).
`get_balance` at close: generations_used 1378 / 10000 (8621 remaining).
Note: this PixelLab account is shared by every concurrent PROD-* lead this
wave, so the account-wide delta (928) is not this family's spend. The table
below is summed from each job this lead actually issued: **43 generations**
(cap was 280; ~15% used, well under the 40% checkpoint).

## Habitat plates (`create_image_pixen`, 192×76, opaque)

| job/id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| 4f3d3a3d-1d8a-4678-a0fe-aa26cce0f6d7 (pre-existing, downloaded+judged only) | pixen | 192×76 | 0 (prior session) | ACCEPT | forest floor: mossy roots, packed dirt, leaf litter, dusk, ground line lower third — matches brief, no sky, no teal |
| 2430a899-b259-417d-9ca5-c844a7c29a55 | pixen | 192×76 | 1 | REJECT | forest candidate 2: fallen log dominates the plate, reads closer to a staged scene than a ground plane |
| 8ef3b4df-8af4-4e16-b875-50c34b73c559 | pixen | 192×76 | 1 | REJECT | forest candidate 3: roots frame both sides like an archway, less natural than c1 |
| 92bb8fb8-0371-4208-8ab1-2697db0d8772 | pixen | 192×76 | 1 | REJECT | rocky candidate 1: pale disc + grey gradient upper-left reads as sky/moon |
| daa43bc0-bd20-4a2f-8007-2afa8abce0fe | pixen | 192×76 | 1 | REJECT | rocky candidate 2: isometric stair/corridor with lit sconces — architecture with depth, not a flat side-view ground plane |
| dd7a57e8-a6d8-4b1b-b98b-6c592b23426b | pixen | 192×76 | 1 | ACCEPT → SUPERSEDED | rocky candidate 3: cut stone block + loose plank on flat cobbled floor. Initially shipped; producer review flagged it as "props on a stage" (the owner's own named failure) and a stray pale sky-disc at higher zoom. Replaced, see round 2. |
| 8c7a7c0d-989f-49ce-ac64-9b4c6fcad4b9 | pixen | 192×76 | 1 | REJECT | cave candidate 1: row of literal torch flames along the top edge — violates no-fire |
| b16a55cb-e6dd-4b85-accf-fe55a0ba09e8 | pixen | 192×76 | 1 | ACCEPT (kept) | cave candidate 2: dark rock, one lantern glow (no flame silhouette drawn). Producer review called this "a wall seen face-on"; round-2 reroll (below) produced nothing better, so this stays. |
| ac365349-4c5d-4392-a7b8-f4be368cc9aa | pixen | 192×76 | 1 | REJECT | cave candidate 3: glowing orange cross-hatched floor cracks read as lava/fire |
| a4467d52-b749-4aef-a182-31d654b0538c | pixen | 192×76 | 1 | REJECT | snow candidate 1: dense saturated dark-green pine treeline breaks the cool-slate/frostmere palette family and edges toward a visible sky band |
| 8a57b982-7118-4dfb-a102-15087c4fd070 | pixen | 192×76 | 1 | REJECT | snow candidate 2: kept as backup; reads a little too abstract/minimal next to c3 |
| 8aed2798-ab15-418b-b65b-008604fc1de0 | pixen | 192×76 | 1 | ACCEPT | snow candidate 3: pale rime-frosted conifers, packed snow ridge, correct cool-family anchor |
| a1f5095c-ff24-47b4-83be-bb06e7138063 | pixen | 192×76 | 1 | REJECT | hollow candidate 1: full tree with hills/horizon visible behind it — sky/horizon violation |
| baee207f-6161-400c-9a57-e6bfad5adb54 | pixen | 192×76 | 1 | REJECT | hollow candidate 2: kept as backup; radial root system has no flat strip for a creature to stand on |
| c623cbfb-877e-4f75-a502-48a80e826675 | pixen | 192×76 | 1 | ACCEPT | hollow candidate 3: roots crossing horizontally, pale fungi caps, dark earth floor below, no sky |

### Round 2 rerolls (producer-directed, one roll each, 3 candidates)

| job/id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| 23e06070-e8c0-4d1c-aaf7-0aba04a0fa02 | pixen | 192×76 | 1 | REJECT | rocky r2-c1: still reads as stacked cut blocks, not a natural shelf |
| 628293e7-173d-4088-a9c2-06e62772b2db | pixen | 192×76 | 1 | **ACCEPT** | rocky r2-c2: jagged natural rock, dark cave-mouth gap behind, scree floor, one timber log at the far right only — replaces dd7a57e8 as `habitat_rocky_ledge` |
| 5b064089-55c8-44a4-ac7b-d84f23e7a41a | pixen | 192×76 | 1 | REJECT | rocky r2-c3: an arm/knee accidentally rendered at the right edge — violates "no creatures" |
| 821002ce-4558-4308-8cc3-d42a21454855 | pixen | 192×76 | 1 | REJECT | cave r2-c1: the warm glow at center is a small standing torch/brazier shape with an open flame — violates no-fire |
| 783575fa-0539-4290-860c-b7c05e183090 | pixen | 192×76 | 1 | REJECT | cave r2-c2: an arched doorway/tunnel opening in true perspective — architecture with depth, not a flat plate |
| f7c3a197-f364-42e6-bd07-3d3477bd195e | pixen | 192×76 | 1 | REJECT | cave r2-c3: wall texture reads as vine/leaf material, wrong for basalt cave |

**Cave shadow verdict: kept `b16a55cb` (cave_c2).** None of the three reroll
candidates beat it — one had an explicit flame, one was a full architectural
tunnel, one had the wrong wall material. The "reads like a wall, not a floor"
concern the producer raised is not fully resolved; flagging as open rather
than spending further rerolls without a new approach (see report).

## Missing tracks (`animate_image` on shipped idle frame 0)

| job/id | tool | canvas×frames | cost | verdict | reason |
|---|---|---|---|---|---|
| 8c7828cb-ae6f-4afd-a15e-2e0c70776eb2 | animate_image | 56×56, 6f | 1 | ACCEPT | boar_hit: species holds, single component every frame, anchor row 43 unchanged |
| 4932db93-697d-45b1-95a4-3819824ec794 | animate_image | 76×76, 6f | 1 | ACCEPT | bear_hit: same checks pass, anchor row 61 unchanged |
| 998a2083-346d-4ba8-bdfa-193afea478b4 | animate_image | 56×56, 6f | 1 | ACCEPT | salamander_hit: same checks pass, anchor row 50 unchanged |
| fca3d024-f7b3-433f-9c60-b977f585761d | animate_image | 48×48, 6f | 1 | ACCEPT | crawler_hit: same checks pass, anchor row 40 unchanged |
| 0c836fdc-2780-4dee-af12-8dfd7ab1a0f7 | animate_image | 48×48, 8f | 1 | REJECT (reroll) | crawler_defeat roll 1: legs shift but the body height only shrinks ~9% — the same "no collapse read" the brief called out as the prior method's failure |
| e24a4fb7-11f0-4b1c-bbf7-79dce6035f78 | animate_image | 48×48, 8f | 1 | **ACCEPT (partial)** | crawler_defeat roll 2 (2-roll cap reached): legs visibly splay wider and the body sits a little lower/flatter, single component throughout, but still not a dramatic "drops flat" read. Shipped as the better of the two rolls with the limitation recorded honestly rather than claimed as fully solved — matches the ENEMY_ROUND_RECORD_01 §6 precedent for `animate_image`'s in-place-only motion. |

## Elite distinguishing-state edits (`edit_image_pixen` on idle frame 0)

| job/id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| 45c0935c-1d28-4366-8fa1-d2962ab6a72f | edit_image_pixen | 56×56 | 1 | REJECT (reroll) | old_grey edit 1: result nearly indistinguishable from the base wolf — no visible muzzle/scar/coat change |
| 9c27de71-d571-43d3-a34a-91616fb7f32f | edit_image_pixen | 56×56 | 1 | ACCEPT | old_grey edit 2: pale ash-grey coat, light muzzle, bold shoulder scar — clear at a glance, same silhouette/canvas |
| 53e3a7af-0a15-4540-8012-a1c2677a6b6f | edit_image_pixen | 56×56 | 1 | ACCEPT | gallery_foreman: iron helmet replaces leather cap, bulkier torso |
| 05d54aeb-5af4-4f03-919f-ea8541f6a031 | edit_image_pixen | 56×56 | 1 | ACCEPT | rimeclaw_matriarch: charcoal-grey coat replaces tan, frost-white chest patch, darker ear tufts |
| 5687ecb3-ac3d-422c-9a39-83e99147fc63 | edit_image_pixen | 96×96 | 1 | ACCEPT | guardian_awakened: glowing amber rune cracks down the body, lighter stone tone, same silhouette |

## Elite idle + attack (`animate_image` on the accepted edit)

| job/id | tool | canvas×frames | cost | verdict | reason |
|---|---|---|---|---|---|
| ec03ffe7-37fa-4fa9-8275-7faabeffdd07 | animate_image | 56×56, 8f | 1 | ACCEPT (cleaned) | old_grey idle: 4 of 8 frames carried a tiny disconnected fleck near the muzzle (breath-mist artifact, Chebyshev 48 from reserved teal — not a violation, but a stray second component). Removed deterministically (keep-largest-component script), re-verified single component, anchor row 40 unchanged. |
| 4ebb8ba5-3f3b-4fa4-bcaa-04ccee5f7abb | animate_image | 56×56, 8f | 1 | ACCEPT | old_grey attack: lunge-and-pull-back, single component every frame |
| 393abeb0-76e9-4e95-bbed-8138cdd40826 | animate_image | 56×56, 8f | 1 | ACCEPT | gallery_foreman idle: helmet and build stay intact through breathing sway |
| 43bc9e27-461d-4b83-87cb-3ab0de6bc53d | animate_image | 56×56, 8f | 1 | ACCEPT | gallery_foreman attack: clear forward swing |
| b6518064-d6ed-4a3f-9595-708b17131894 | animate_image | 56×56, 8f | 1 | ACCEPT | rimeclaw_matriarch idle: identity holds; anchor row measures 40, 1px below the shipped lynx's 39 (flagged, see report) |
| 11ae212f-ee8a-4d52-9757-6f85220d69c8 | animate_image | 56×56, 8f | 1 | ACCEPT | rimeclaw_matriarch attack: crouch-and-lunge read, same anchor note as idle |
| a6cbabab-1408-4e37-ac83-390a0e0f9848 | animate_image | 96×96, 8f | 2 | ACCEPT | guardian_awakened idle: glow persists, anchor row 83 unchanged |
| ab9bb945-c3ac-4ed0-8857-2dded9882c2b | animate_image | 96×96, 8f | 2 | ACCEPT | guardian_awakened attack: heavy forward swing, anchor row 83 unchanged |

## Boar↔Ram insurance

| job/id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| 3fc8daba-2af4-458d-8dd3-858fb413a2b4 | edit_image_pixen | 56×56 | 0 (server error) | FAILED | infra failure ("Out of CUDA memory"), not a content rejection — retried once per cost-discipline norms |
| e2ac9801-1023-45fd-875b-535255c61dbb | edit_image_pixen | 56×56 | 1 | ACCEPT | ram horns thickened into a bold tight curl — clearly bolder outline than the original thin curve, same silhouette bounds otherwise (10,9..48,42) |
| f5cc1cbf-5d6e-4409-8162-9f888760af0e | animate_image | 56×56, 6f | 1 | ACCEPT | one-roll re-animation of the thickened-horn idle reproduces the breathing cycle cleanly (7 frames total, matches the shipped ram_idle count); anchor row 42 unchanged. Shipped as a candidate replacement set, not wired in — integrator's call (see report). |

## Totals

- Requested (this lead, successful jobs): 41 jobs, **43 generations** (14+6 habitat round 1+2, 6 missing-track, 5 elite edits, 10 elite idle/attack, 2 ram insurance for the ram idle + edit; the failed ram edit charged 0).
- Accepted: 5 habitat plates, 5 missing-track deliverables (4 hit + 1 partial defeat), 5 elite edits→10 elite animation tracks, 1 ram insurance edit + reproduced idle.
- Rejected: 16 habitat candidates, 1 crawler-defeat roll, 1 old_grey edit roll.
- Cap: 280 generations. Used: 43 (~15%), well under the 40% checkpoint.
