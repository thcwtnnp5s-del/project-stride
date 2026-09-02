# FMPO02 — WORLDLIFE generation ledger (ART-04)

Balance at start: **9,551 generations** (credits $0.00, Tier 3, resets 2026-10-01).
Cap for this family: **320**. Requested: **60**. Every job below cost 1 generation
(pixen stills, `edit_image_pixen` edits, and every `animate_image` call reported
`cost: 1 generation` — all frame sets sit under the 65,536 px-per-generation step).

| job/id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| 6ecd94cc | pixen | 96x64 | 1 | REJECT | red dragon, wings both swept one side — reads as a dive, not a cruise |
| 754ee551 | pixen | 96x64 | 1 | REJECT | red dragon, wingspan swamps the volcano on the atlas composite |
| 7dc146bc | pixen | 96x64 | 1 | **ACCEPT** | red dragon flight still — horned head, ember jaw, compact airborne pose |
| b361f0cf | pixen | 96x56 | 1 | REJECT | blue serpent too pale — vanishes on Frostmere snow |
| ff98c3a1 | pixen | 96x56 | 1 | REJECT | blue serpent, weakest silhouette of the three |
| aad935e1 | pixen | 96x56 | 1 | **ACCEPT** | blue storm serpent still — dark slate, spined crest, reads on snow |
| 96c50337 | pixen | 56x64 | 1 | REJECT | storm house: plain cabin + smoke plume, no storm |
| 4abf636e | pixen | 56x64 | 1 | **ACCEPT** | storm house — cloud pocket, 3 lit windows, bent dead trees |
| f376bc2d | pixen | 48x80 | 1 | **ACCEPT** | ice tower — dark stone core is what makes it read against snow |
| e051e4ae | pixen | 48x80 | 1 | REJECT | ice tower all-white with a hard black outline; cut-out, lost on snow |
| 24a36216 | pixen | 28x28 | 1 | **ACCEPT** | bear still |
| f52059e8 | pixen | 24x24 | 1 | REJECT | wagon at 24px — indistinct brown lump |
| d7f6ab41 | pixen | 20x20 | 1 | REJECT | fishing boat at 20px — a smear |
| 24425828 | pixen | 32x32 | 1 | REJECT | fairies — bright confetti squares, the exact §7 failure |
| 0ec570ec | pixen | 40x32 | 1 | REJECT | deer at 40x32 — orange blob, two animals do not separate |
| 2c0521b9 | pixen | 44x36 | 1 | REJECT | "yeti" came back a quadruped polar bear |
| c9e4d903 | pixen | 48x48 | 1 | REJECT | wolves — pale blob on a hard isometric dirt diamond (the `fire2` failure) |
| 36d3c54c | pixen | 24x24 | 1 | REJECT | ship — stray orange artefact, sails indistinct |
| cf993855 | pixen | 48x64 | 1 | **ACCEPT** | forked lightning bolt — white core, real side branches |
| b4476efd | pixen | 16x16 | 1 | **ACCEPT** | chimney smoke still |
| 6c629926 | pixen | 16x16 | 1 | REJECT | "smoke" came back a lit brazier |
| 4b4ec42f | pixen | 48x40 | 1 | **ACCEPT** | doe + fawn, legs separated, no ground platform |
| 27b81bc4 | pixen | 44x40 | 1 | **ACCEPT** | bipedal shaggy yeti |
| 1bfba8fa | pixen | 28x28 | 1 | REJECT | ship — reads as a person in a boat under an orange sun blob |
| 95b91be5 | pixen | 24x24 | 1 | **ACCEPT** | fishing boat |
| 164da7b4 | pixen | 32x32 | 1 | REJECT | fairies — owl/cat faces |
| 6d4fe546 | pixen | 32x32 | 1 | **ACCEPT** | covered wagon + two oxen, shapes separate |
| b88dda19 | pixen | 24x24 | 1 | **ACCEPT** | crows still |
| a8adcadf | pixen | 56x44 | 1 | REJECT | wolves overlap into a muddle; tan not slate |
| 2549df1f | pixen | 16x16 | 1 | **ACCEPT** | lantern flame (12x12 impossible — PixelLab minimum side is 16) |
| 23db247d | pixen | 32x32 | 1 | **ACCEPT** | blown-snow ribbon |
| 566feaba | pixen | 24x24 | 1 | REJECT | sea birds — two opaque dark rectangles baked in; duplicates shipped `overlay_birds` |
| 2ea5e838 | pixen | 32x32 | 1 | REJECT | fairies — opaque dark background, reads as a decorative tile |
| 0cbdc63b | pixen | 32x32 | 1 | REJECT | fairies — closer, but ~15 gold dashes, confetti-like |
| 41b99472 | pixen | 28x28 | 1 | REJECT | ship — reads as a feather/arrowhead. Third failure: line abandoned |
| 2920a085 | pixen | 32x32 | 1 | **ACCEPT** | fairy motes — 6 warm gold glows, halos, no faces, no cyan |
| dc72753e | pixen | 16x16 | 1 | REJECT | "smoke" came back a white stick. Second failure: variant B abandoned |
| 890b82c2 | pixen | 56x44 | 1 | **ACCEPT** | two slate-grey wolves, clearly separated, no base |
| 0af4717a | edit_pixen | 128x64 | 1 | **ACCEPT** | red fire-breath still — hard-edged cone, orange-white core, smoke tail |
| 0f9d74f3 | edit_pixen | 128x56 | 1 | REJECT | blue breath came back inside a hard UI-style panel frame |
| 9535f5b6 | edit_pixen | 128x56 | 1 | REJECT | blue breath — the "bolt" is a fat chevron/arrow glyph (§7 UI-icon shape) |
| 13588344 | edit_pixen | 128x56 | 1 | **ACCEPT** | blue breath still — genuine branching fork, transparent, no frame |
| 764a106a | animate | 96x64x9 | 1 | **ACCEPT** | red flight — full wingbeat cycle, identity holds across frames |
| d1422fc9 | animate | 96x56x9 | 1 | **ACCEPT** | blue flight — travelling body wave, fins ripple |
| cc7b2260 | animate | 48x80x7 | 1 | **ACCEPT** | ice beacon pulse — 224–341 px change per frame, tower geometry static |
| 6f03141e | animate | 128x64x9 | 1 | **ACCEPT (8 of 9)** | red breath. Frame 8 dropped — the dragon itself vanishes from it |
| 5c3c2cf2 | animate | 96x56x9 | 1 | REJECT | blue breath at 96 wide — superseded by the 128-wide set |
| 2d9677c0 | animate | 128x56x9 | 1 | **ACCEPT (8 of 9)** | blue breath — arc fires on f0–f1, serpent flies on |
| 82fbe2e0 | animate | 48x40x9 | 1 | **ACCEPT** | deer — doe's head lifts and lowers, fawn shifts and turns |
| 687a7415 | animate | 28x28x9 | 1 | **ACCEPT** | bear amble cycle |
| 86e1e3e2 | animate | 44x40x9 | 1 | **ACCEPT** | yeti stride; the pass also cleaned the still's loose snow spray |
| 31bc0207 | animate | 48x64x9 | 1 | **ACCEPT (8 of 9)** | bolt flash — 2478 → 155 opaque px, last frames near-empty |
| b2ece02c | animate | 24x24x7 | 1 | **ACCEPT** | crows wheeling |
| c52ba077 | animate | 56x44x9 | 1 | **ACCEPT** | wolf pair in place |
| a68dfb19 | animate | 32x32x9 | 1 | REJECT | motes go dark and debris-like from frame 4 |
| e979b409 | animate | 16x16x5 | 1 | **ACCEPT** | lantern flicker |
| da1f7963 | animate | 32x32x9 | 1 | **ACCEPT** | snow drift lifts, scatters, settles (1107 → 486 px) |
| 392c528e | animate | 16x16x7 | 1 | **ACCEPT** | chimney smoke rising and drifting |
| f1507894 | animate | 24x24x5 | 1 | **ACCEPT** | fishing boat rocking |
| adce7f36 | animate | 32x32x9 | 1 | **ACCEPT (4 of 9)** | motes re-roll; shipped frames 0,1,5,6 — the ones that stay lit |

**Totals — requested 60 · accepted 34 · rejected 26 · cap 320 · spend 19% of cap.**

Balance at end: **8,758 generations** (account-wide).

The account-wide delta is 793, but **only 60 of those are this family's**. The
other ~733 belong to the other FMPO02 wave-2 PROD leads generating concurrently
on the same account — the same contention that produced repeated
`rate limit exceeded (20/20 jobs)` errors throughout this run and forced work
into small batches. WORLDLIFE's own spend is the 60 rows above: **19% of the
320 cap**.

## Abandoned lines (recorded and left, per the two-failure rule)
- **Ship under sail** — 3 attempts (36d3c54c, 1bfba8fa, 41b99472). The shipped
  `overlay_ship` (15x20) stays as-is.
- **Sea birds** — 1 attempt (566feaba), baked-in opaque rectangles, and it
  duplicates the shipped `overlay_birds`. Not chased.
- **Chimney smoke variant B** — 2 attempts (6c629926, dc72753e). Variant A ships;
  the shipped `overlay_smoke` is the second variant.

## Guard results on all 34 shipped files
`partialAlpha=0`, `reservedTeal=0` on every frame (131 PNGs). Pure-black outline
pixels are present, matching the shipped baseline exactly — `overlay_skydragon_f0`,
`overlay_redwyrm_f0`, `prop_rimespire` and `prop_black_gable` all have
`minRGBsum=0` too, so this is the established env convention, not a new defect.
