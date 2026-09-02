# REWARDS — FMPO02 wave2 ledger (PROD-REWARDS)

Balance at open: **9,551 remaining / 449 used / 10,000 total** (shared account,
other family leads generating concurrently this session).
Balance at close: **9,102 remaining / 898 used / 10,000 total**.
This family's spend: **21 generations** (cap 90).

`mark_craft_done` was **not generated** — ART-10_reward_brief.md §1 explicitly
rules against a new craft-completion asset ("gets no new asset... a mark per
craft repeats eleven unrelated borders one family later"); the task list
conflicting with the canonical brief is recorded as UNRESOLVED in
`JOURNAL/OPEN_QUESTIONS.md` rather than silently resolved either way.

`plate_project` was **not generated** — `seal_project` (existing, shipped,
placed) already reads clearly as project completion (teal medallion, a
set-square/ruler stamp, distinct silhouette from `seal_contract`'s scroll).
Zoomed at ×8 (`review/reward_seal_project_x8.png`) to confirm before deciding
to skip. Separately flagged (not fixed, out of scope): `seal_project`'s fill
is teal, and `#58D6C0`-family teal is reserved for walking (L-16/L-19) —
existing pre-round defect, not touched here.

| job/id | tool | canvas | cost | ACCEPT/REJECT/RE-ROLL | reason |
|---|---|---|---|---|---|
| mark_rare_drop_a (0930c020) | pixen | 24² | 1 | REJECT | reads as armored vest, not a bundle |
| mark_rare_drop_b (623a8b39) | pixen | 24² | 1 | REJECT | reads as a small creature (fuzzy head, two feet) at ×16 |
| mark_rare_drop_c (a3cceee0) | pixen | 24² | 1 | REJECT | drawstring sack carries a circular stamp that reads as a seal/coin disc |
| mark_rare_drop_d (3992f4f1) | pixen | 24² | 1 | REJECT | radiating pointed straps read as a star/X, explicitly excluded |
| mark_rare_drop_e (ba14a1f5) | pixen re-roll, revised construction clause | 24² | 1 | ACCEPT (alt) | clean round sack, cord knot — good but f chosen as primary |
| mark_rare_drop_f (5b1d0d1d) | pixen re-roll | 24² | 1 | **ACCEPT — primary** | round-bottomed cloth sack, crossed cord tie, muted earthy palette closest to family (badge_milestone/mark_knowledge) |
| mark_rare_drop_g (f78150c1) | pixen re-roll | 24² | 1 | REJECT | acceptable but redundant with f, boxier silhouette reads slightly tag-like |
| seal_signature_a (a45f79be) | pixen | 96×48 | 1 | **ACCEPT — primary** | rectangular leather plate, 4 rivets, stitched border, 3 claw gouges — no extra background shape |
| seal_signature_b (28b39740) | pixen | 96×48 | 1 | REJECT | adds an oval underlying plate/halo not asked for, plus bright edge highlights |
| seal_signature_c (8ef371d6) | pixen | 96×48 | 1 | REJECT | same oval-halo defect as b |
| seal_signature_d (51c0e54b) | pixen | 96×48 | 1 | REJECT | same oval-halo defect as b/c |
| seal_masterwork_a (bf681716) | pixen | 96×48 | 1 | REJECT | dark wood plaque sits on an added oval serving-plate halo, not asked for |
| seal_masterwork_b (580a192d) | pixen | 96×48 | 1 | REJECT | same oval-halo defect as a |
| seal_masterwork_c (1455ba48) | pixen | 96×48 | 1 | REJECT | same oval-halo defect as a/b |
| seal_masterwork_d (ca384818) | pixen re-roll, prompt bans backing shape | 96×48 | 1 | ACCEPT (alt) | clean, but medallion/rivets read closer to gold than bronze |
| seal_masterwork_e (49d056e3) | pixen re-roll | 96×48 | 1 | **ACCEPT — primary** | dark wood plank, bronze medallion, crossed hammer-and-tongs, reddish-copper reads (not gold) |
| tile_parchment_a (d72dca28) | pixen 64² source | 64² | 1 | REJECT (raw) | hard dark frame/vignette at edges; usable only via corner-crop |
| tile_parchment_b (551afd37) | pixen 64² source | 64² | 1 | REJECT | bakes a circular ornamental ring + tree/hammer glyph — "no object lying on it" |
| tile_parchment_c (d97f20b4) | pixen 64² source | 64² | 1 | REJECT (raw) | strong radial vignette, brighter centre; usable only via corner-crop |
| tile_parchment_d (a6bd7c8a) | pixen re-roll, anti-vignette clause | 64² | 1 | REJECT (raw) | still framed at edges; also a directional diagonal wood-grain, too "interesting" once folded |
| tile_parchment_e (02732d52) | pixen re-roll | 64² | 1 | REJECT (raw) | still framed at edges; interior crop reads as a busy basket-weave, too high-frequency |
| tile_notable_plate cand.1 (a2_folded, from tile_parchment_a) | crop.js + fold.js (0 gen, deterministic) | 32² | 0 | ACCEPT (alt) | mirror-folded interior crop of a; subtle mottled grain, low contrast, seamless |
| tile_notable_plate cand.2 (c2_folded, from tile_parchment_c) | crop.js + fold.js (0 gen) | 32² | 0 | **ACCEPT — primary** | mirror-folded interior crop of c; smoothest, lowest-contrast, warm dark oat/parchment, seamless by construction |
| tile_notable_plate cand.3 (c3_folded, from tile_parchment_c, different corner) | crop.js + fold.js (0 gen) | 32² | 0 | ACCEPT (alt) | same source image, second corner sample; slightly more olive, also usable |
| tile_notable_plate reject (d_folded) | fold.js (0 gen) | 32² | 0 | REJECT | folds into a diamond/kaleidoscope pattern — reads as decorative, not boring |
| tile_notable_plate reject (e2_folded) | fold.js (0 gen) | 32² | 0 | REJECT | folds into a busy checkerboard-speckle pattern, too high-frequency |

**Totals.** Requested: 21 raw generations (16 icon/banner + 5 tile-source).
Accepted (shipped to `out/`): 4 assets (mark_rare_drop, seal_signature,
seal_masterwork, grain_notable_plate). Accepted-alt (kept in `raw/reward/`,
not packaged): 4. Rejected: 13, each with the reason above so a future re-roll
does not repeat it (M-05). `plate_project` and `mark_craft_done`: 0
generations spent, both resolved without generating (see notes above).

Get_balance: **open 9,551 / 449 used**; **close 9,102 / 898 used**
(shared Tier 3 account; other FMPO02 family leads were generating
concurrently, hence the larger account-wide delta than this family's 21).
