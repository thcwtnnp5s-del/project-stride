# FMPO02 — UI family generation ledger

`get_balance` start (2026-09-02): **9551 remaining**, 449 used this cycle.
`get_balance` end: **8513 remaining**, 1486 used this cycle.

The account-level delta is 1038. **This family requested 95.** The rest belongs to
the other Wave 2 PROD leads working the same Tier-3 account concurrently; the
figure of record for UI is the per-job count below, not the account delta.

Cap: 450. Requested: **95**. Under cap by 355.

| job/id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| 7da60dbd | pixflux | 64² | 1 | ACCEPT | journal_leaf master; quiet warm fleck, ships |
| 4bd250ef | pixflux | 64² | 1 | REJECT | leather: flat fill, no grain to scale |
| 7a379465 | pixflux | 64² | 1 | REJECT | steel: two heavy inks 21 L* apart, a pattern |
| 093b4ccf | pixflux | 64² | 1 | REJECT | leather retry: orange blotches survive flat-field |
| 7cdce017 | pixflux | 64² | 1 | ACCEPT | steel master; fine speckle after flat-field |
| 4335462c | pixflux | 64² | 1 | ACCEPT | oilcloth master |
| 596b3905 | pixflux | 64² | 1 | ACCEPT | buckram master |
| f5690f0c | pixflux | 64² | 1 | REJECT | bench_oak: 100% one ink, flat fill |
| e3a10f2f | pixflux | 64² | 1 | ACCEPT | slate master |
| 1267e663 | pixflux | 64² | 1 | REJECT | chart_vellum: flat fill |
| a76b5446 | pixflux | 64² | 1 | REJECT | cork: master carries no grain to scale |
| 7592f989 | pixflux | 64² | 1 | REJECT | plan_linen: drawn chalk loops, an object not a grain |
| 972a8b04 | pixflux | 128² | 1 | REJECT | modal_128: round stud heads on the corner straps (P-D1) |
| 4d03ac0e | pixflux | 128² | 1 | REJECT | modal_128: a boss centred in every edge run (§3.4) |
| 43bd0054 | pixflux | 128² | 1 | REJECT | modal_128: large warm round disc per corner — coin register |
| e22a9068 … e90b3c7d (10) | pixflux | 128² | 10 | REJECT | surfaces at 128²: the model answered "detailed" with a flat field; 7 of 10 came back with zero grain in every window |
| 41199e70 | pixflux | 64² | 1 | ACCEPT | leather master (pore speckle) |
| 166d31d5 | pixflux | 64² | 1 | REJECT | leather: flat fill |
| e11e69d8 | pixflux | 64² | 1 | ACCEPT | bench_oak master (directional grain survives) |
| b9116d71 | pixflux | 64² | 1 | REJECT | bench_oak: flat fill |
| 4bff95ee | pixflux | 64² | 1 | REJECT | chart_vellum: flat fill |
| 71ec7dfe | pixflux | 64² | 1 | ACCEPT* | chart_vellum master — *ships without grain, see report |
| cc656761 | pixflux | 64² | 1 | REJECT | cork: no grain |
| b7cf1e2a | pixflux | 64² | 1 | REJECT | cork: no grain |
| 7ac465df | pixflux | 64² | 1 | REJECT | chart_vellum burlap: real texture, reads as BRICKWORK tiled |
| 5a6f65a2 | pixflux | 384×48 | 1 | REJECT | band probe: at 48 tall the model draws a toolbar of icons, not a scene |
| 3841a45f | pixflux | 384×96 | 1 | ACCEPT | band_forge — 96 tall is the working canvas, crop to 48 |
| 4615a23b | pixflux | 384×48 | 1 | REJECT | world_chart at 48: icon row |
| a2489ffb | pixflux | 384×96 | 1 | ACCEPT | band_cookfire |
| c895e6d8 | pixflux | 384×96 | 1 | REJECT | bench: cold blue ground, wrong material |
| cade52b4 | pixflux | 384×96 | 1 | REJECT | foraging: repeating identical bushes |
| eaa81aa3 | pixflux | 384×96 | 1 | REJECT | mining: reads as a masonry wall |
| 79b7fb06 | pixflux | 384×96 | 1 | REJECT | combat_kit: drawn compartments — Flutter measures those |
| 767692d7 | pixflux | 384×96 | 1 | REJECT | world_chart: framed tray, reads as a slot |
| 56b9226c | pixflux | 384×96 | 1 | REJECT | encounter_ground: oxblood brick paving |
| 9ef9128d | pixflux | 384×96 | 1 | REJECT | adventure_trail: closed oval path, reads as a running track |
| 779b815d | pixflux | 384×96 | 1 | REJECT | boards_batten: floating plank on a pale field |
| c32e35e9 | pixflux | 384×96 | 1 | REJECT | forge alt: flat-lay on a pale plank |
| fd0fd33a | pixflux | 384×96 | 1 | ACCEPT | band_bench |
| 386dedd4 | pixflux | 384×96 | 1 | REJECT | mining: gold sparkle glints — the four-point star register |
| 826b1e6d | pixflux | 384×96 | 1 | REJECT | combat_kit: small warm round discs — coin register |
| 6ccac4b9 | pixflux | 384×96 | 1 | ACCEPT | band_world_chart |
| dcb41acf | pixflux | 384×96 | 1 | ACCEPT | band_adventure_trail |
| a736cdaa | pixflux | 384×96 | 1 | REJECT | encounter_ground: still tiled paving |
| 3e100154 | pixflux | 384×96 | 1 | ACCEPT | band_boards_batten |
| e2dfdc81 | pixflux | 384×96 | 1 | ACCEPT | band_foraging |
| 39ad765f | pixflux | 384×96 | 1 | ACCEPT | band_mining (no glints) |
| d15a7b94 | pixflux | 384×96 | 1 | ACCEPT | band_encounter_ground |
| 3fb87140 | pixflux | 384×96 | 1 | ACCEPT | band_combat_kit (discs gone) |
| 28431e3c | pixflux | 64² | 1 | REJECT | strap_corner: drew four complete little frames |
| 4bf5e943 | pixflux | 64² | 1 | REJECT | strap_corner: four complete little frames again |
| 4a7b90e7 | pixflux | 48² | 1 | REJECT | corner_mark: one frame with a disc in the middle |
| 1a0b75e7 | pixflux | 48² | 1 | REJECT | corner_mark: four diagonal squares with spikes |
| 180ef81e | pixflux | 32² | 1 | REJECT | tack: drew a book, not a tack |
| 4faa0c0c | pixflux | 32² | 1 | REJECT | tab_index: drew a frame |
| bc316c37 | pixflux | 32² | 1 | REJECT | tab_index: drew a dotted frame |
| 15fc9097 | pixflux | 64×16 | 1 | REJECT | rule_plate: two hairlines, no body |
| daf21e36 | pixflux | 64×16 | 1 | ACCEPT | rule_plate — caps ship, run does not (see report) |
| ab791a3b | pixflux | 64×32 | 1 | ACCEPT | btn_plate master |
| e170d4dd | pixflux | 64×32 | 1 | REJECT | btn_plate: ragged rim |
| 7ba705cf | pixflux | 64×32 | 1 | REJECT | btn_plate: diagonal streak across the face |
| 20dbcaef | pixflux | 48×24 | 1 | ACCEPT | btn_compact master |
| 0c883476 | pixflux | 48×24 | 1 | REJECT | btn_compact: busy face |
| 083cd78d | pixflux | 48×24 | 1 | REJECT | btn_compact: rim too thin to measure |
| 26f76d49 | pixflux | 64×16 | 1 | ACCEPT | nav_welt strip |
| 7b7eb094 | pixflux | 64×24 | 1 | ACCEPT | header_shelf strip |
| e10e6840 | pixflux | 32² | 1 | REJECT | nav_plate: no measurable band (0/0/0/1) — cannot be a nine-patch |
| b739f393 | pixflux | 48×24 | 1 | REJECT | banked_cartouche: no measurable band (0/4/1/5) |
| cde1e400 | pixflux | 384×176 | 1 | ACCEPT | bg_workbench |
| 9f5f757b | pixflux | 384×176 | 1 | REJECT | bg_workbench alt: busier, less scrim-ready |
| 5a434749 / fed1b50d | pixen | 16² ×2 | 2 | ACCEPT* | nav adventure + _hi |
| 4e0ec844 / a0482431 | pixen | 16² ×2 | 2 | ACCEPT* | nav character + _hi |
| 36ca6bc5 / 2f4d32f7 | pixen | 16² ×2 | 2 | ACCEPT* | nav skills + _hi (weak referent) |
| 9043516e / f0193eaf | pixen | 16² ×2 | 2 | ACCEPT* | nav inventory + _hi |
| e99e8da8 / c9adf083 | pixen | 16² ×2 | 2 | ACCEPT* | nav craft + _hi |
| 2fc4a34b | pixen | 16² | 1 | ACCEPT* | nav world (octagonal rose) |
| 1eba684c | pixen | 16² | 1 | REJECT | nav world_hi: radial burst — §11, hard blocker |
| bb082059 / 2d39f15d | pixen | 16² ×2 | 2 | REJECT | world retry: round warm disc — coin register |
| 4d0c3ffd / 3d6b9dbe | pixen | 16² ×2 | 2 | REJECT | skills retry: plane reads as a wedge at 14px |

`ACCEPT*` = shipped to `out/` as a candidate, not recommended for integration
this round. See `MILESTONES/evidence/FMPO02/wave2/UI_report.md`.

## Totals

- Requested: **95**
- Accepted (shipped to `out/`): **34 jobs**
- Rejected: **61 jobs**
- Batches recorded and left after two failures: **modal_128** (3 rolls),
  **strap_corner / corner_mark / tab_index / tack** (2 rolls each),
  **nav_plate**, **banked_cartouche** (1 roll each, both fail on measured geometry).
