# REWARDS — EPO03 wave2 ledger (PROD-REWARDS, team `rewards`)

Cap **90** generations. Family total is the **sum of the cost lines below**,
never a balance delta (M-17). Every candidate is fetched to `raw/reward/`,
sheeted at ×2 on the slip's own paper tone and Read before its verdict (§2).
Brief: `MILESTONES/evidence/EPO03/wave1/DIR-13_reward_game_feel.md`.

| # | asked | tool | job id | cost line | verdict | reason |
|---|---|---|---|---|---|---|
| 1 | `stamp_verb_*` ×6 — the verb ribbon re-hued per skill (mining/woodcutting/foraging/cooking/smithing/gathered) from `assets/ui/v1/kit/ribbon_label.png` | `tools/wax-tone.js` (deterministic remap, A-2) | — | cost: 0 generations | ACCEPT | The kit's `KitMark.ribbonLabel` already **is** the "short label plate" DIR-13 budgeted 8 rolls to author. Six tones off one drawing make MINED / CHOPPED / FORGED differ across the room without a generation. Sheet `review/rewards/derived.png`, Read. |
| 2 | `seal_wax_rare` / `_epic` / `_legendary` — the blank wax seal re-hued per rank from `assets/art/v1/ui/craft_seal_blank.png` | `tools/wax-tone.js` | — | cost: 0 generations | ACCEPT | DIR-13 budgeted 6 rolls for `seal_rare_wax`; Craft had already authored a blank seal. Three tones answer the producer's running note directly — this family is **not** a second grid of identical red stamps. Sheet `review/rewards/derived.png`, Read. |
| 3 | `seal_project_bronze` — the project seal re-hued off the reserved teal | `tools/wax-tone.js` (target `#C08A46`) | — | cost: 0 generations | ACCEPT | DIR-13 top failure 5: `seal_project` is drawn in the walking teal (L-16). It measures *outside* `check-art-palette`'s DeltaRGB-10 radius, so no guard caught it, but on the zoom sheet it is plainly the step accent. A remap fixes it for nothing; DIR-13 budgeted a 6-roll re-roll. |
| 4 | `glyph_tally` — five-bar gate tally, 4 uprights + 1 diagonal, 40x32 to crop to 32x16 | `create_image_pixen` x4 | `5857a090`, `95864968`, `4e458a22`, `be4befb4` | cost: ~4 generations | **ACCEPT job be4befb4** (candidates a/b/c REJECT) | Sheet `review/rewards/tally_sheet.png`, Read at x6. `be4befb4` is the only clean hand-inked tally: four thin uprights and one diagonal. `5857a090` draws six crossed strokes (unreadable as five), `95864968` draws a wooden fence with a plank across it (illustration, not notation) and `4e458a22` draws two crossed timbers. Accepted candidate cropped to 28x24 and lifted onto the card ink ramp by `wax-tone.js --lift 0.55`: at its authored value (max L* 11.4, #32170D) it was invisible on `surfaceCard` (L* ~10) — a measurement, not a taste (`review/rewards/tally_final.png`). |

**Family total: 4 generations** (cap 90). Requested 4, accepted 1, rejected 3.
Ten further assets landed at **cost 0** by deterministic remap of drawings
this repo had already accepted — rows 1-3. DIR-13 budgeted 66 generations;
the kit and the Craft workshop had already authored the shapes.
