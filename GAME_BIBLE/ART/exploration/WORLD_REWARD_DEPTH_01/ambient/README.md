# WORLD_REWARD_DEPTH_01 — ambient stream (workstream G, part 1)

```
STATUS: round record · book-scale correction + micro-idles for the ambient cadence · NOT CANON
Author: PixelLab ambient/combat correction agent (workstream G), 2026-08-19.
Nothing here is committed, staged, or written to assets/, lib/, Scripts/ — the lead integrates.
QA VERDICT is written by an independent Visual QA agent (MISTAKES.md M-04); AUTHOR ASSESSMENT below it is mine.
```

Governed by `MILESTONES/WORLD_REWARD_DEPTH_01.md` §1.4, §9 · `RULES.md` A-1/A-2 ·
`MISTAKES.md` M-04/M-05 · `NEUTRAL_STAGING_CHECKLIST.md` ·
`../../PLAYABLE_EXPANSION_01/ambient/README.md` (the method this round reuses verbatim).

## 1. What this round was for

1. **The reading book is huge** (device finding, milestone §3). `PLAYABLE_EXPANSION_01`
   fixed the TRANSFORMATION_01 failure ("no book perceptible at ×2") by over-correcting:
   the shipped `traveler_read` book spans x 1..61 of the 64 frame — wider than the
   Traveler's shoulders, and 61 px against a 32 px figure. This round finds the middle.
2. **A micro-idle for the ambient cadence** (milestone §9): stream F needs
   `traveler_idle_breathe` in the `microIdles` pool so a visit ends in a living idle
   rather than a held rest frame.

## 2. Spend

From the tools' own cost lines (the account is shared with the concurrent world-art
stream E, so `get_balance` deltas are **not** this agent's spend; balance read 700
remaining at the start of the session and 447 at the end, of which 29 are mine).

| Target | Tool | Calls | Gens |
|---|---|---|---|
| read round 1 (`wr_read_small1/2/3`) | `animate_character` v3, south, 8 f, keep_first_frame | 3 | 3 |
| read round 2 (`wr_read_mid4/mid5`) | same | 2 | 2 |
| read round 3 (`wr_read_mid6`) | same | 1 | 1 |
| micro-idles (`wr_idle_breathe`, `wr_look_around`, `wr_shift_weight`) | `animate_character` v3, south, 6 f, keep_first_frame | 3 | 3 |
| **ambient subtotal** | | **9** | **9** |

The combat and items streams of this workstream spent 14 and 6 (see their READMEs):
**29 of the 70-generation budget; 41 unspent.**

## 3. Method (unchanged from PLAYABLE_EXPANSION_01 unless stated)

- `animate_character(c82b7da5-cda0-44eb-ae4e-30d73689e115, mode="v3", keep_first_frame=true,
  directions=["south"])`. Output canvas 88×88; packaging crops at **(12,12) → 64×64**, feet on
  **row 62** — the shipped ambient anchor, unchanged.
- **Frame 0 is the rest pose, proven and not assumed.** The character's south rotation and
  `assets/art/v1/anim/gather_f0.png` differ by **10 alpha pixels** across a 32 × 62 figure, with
  identical opaque bounds except one row (`tools/cmp.js`; overlay at `qa/_ref_vs_gather_x6.png` —
  the remaining difference is the packaged file's palette pass, not the pose). So
  `keep_first_frame=true` gives the rest frame itself and **no custom start frame was needed**.
  Every micro-idle therefore starts — and through `pingpong` ends — on the rest pose, which is what
  `AmbientPlayer` holds between scenes.
- Palette: nearest-reference-colour remap ≤ 48 to the 31 idle colours
  (`candidates/_ref/f0.png` = the south rotation), same as PE01. Off-palette pixels beyond 48 are
  kept: **0** on read, 2 on read_alt, 0 / 1 / 0 on the micro-idles.
- **Zero semi-transparent pixels** arrived in any frame; the alpha quantiser never fired.
  **Zero clipped frames** — no opaque pixel touched a crop edge in any sequence.
- Nothing was hand-drawn or pixel-edited. Frame selection, crop, alpha quantise, nearest-colour
  remap and sheet assembly only (`RULES.md` A-2).
- Tools (`tools/`): `dl.js`, `fetch_groups.js` (PE01's, reused verbatim — it tolerates the CDN's
  intermittent 404s, which fired once again this round), `cmp.js`, `strip.js`, `cstrip.js`,
  `zoom.js`, `phone.js` (390-wide ×2 composite — the verdict view), `newbox.js` / `bookbox.js`
  (measure what a frame adds to the rest pose), `inspect.js`, `package.js`, `stage.js`.

## 4. Candidates and prompts (verbatim action descriptions)

### A `traveler_read` — the book-scale correction

Measured targets in the 64 frame (`tools/bookbox.js`): the head is **12 px** wide, the shoulders
**22 px**. The shipped book's opaque span is **61 px**.

- `wr_read_small1` (group d933d95e): "standing, holding a small pocket-sized book open in both
  hands at chest height, the little book no wider than his own face and no taller than his head,
  dark cover with pale cream pages, head bowed reading it, one thumb flicking a page over once,
  then reading again"
  → the book became a cream sliver ≈ 7 × 4 px at the belly. **Over-corrected — rejected**
  (`qa/_bookzoom_x8.png`, cell 2: the T01 failure again).
- `wr_read_small2` (ea4e3b1e): "standing, both hands cupped together in front of the chest holding
  a small open notebook, the notebook only about as wide as the shoulders are half, brown covers
  with bright pale pages facing up toward his face, chin tucked down to read, turning one page
  with the right hand, small and still"
  → no book at all; reads as clasped hands. **Rejected.**
- `wr_read_small3` (ac3a3654): "standing, lifting a small hand-held book from the belt up to chest
  height and opening it in both hands, the open book about the width of the face, pale cream page
  block against a dark cover, head tilted down reading, turning a single page, then reading on"
  → the same sliver, marginally larger. **Rejected.**
- `wr_read_mid4` (79a861c9): "standing, holding an open book up in both hands at chest height just
  below his chin, the open book about as wide as his chest and about as tall as his face — clearly
  narrower than his shoulders and never reaching past them — its two flat cream pages tilted up
  toward him so a solid pale rectangle shows above the dark cover, head bowed reading, one hand
  turning a single page over, then reading again"
  → a compact **brown leather book with a pale spine**, ≈ 14 × 12 px, held at chest with the head
  bowed; present and legible in **every** frame f3–f8. **Chosen → `traveler_read`.**
- `wr_read_mid5` (b408ed7e): "standing, raising a slim leather-bound field journal in one hand to
  chest height and holding it open against the palm of the other hand, the open journal a compact
  block of bright cream pages half the width of his shoulders and no taller than his head, dark
  brown cover behind it, chin lowered to read the pages, the free thumb flicking one page across,
  then reading on, feet planted"
  → a bright cream block ≈ 26 px across the chest with no visible cover: reads **sheet of paper /
  map**, and it is large again. **Rejected.**
- `wr_read_mid6` (fc99ecdb): "standing, holding a small brown leather book open in both hands at
  chest height, the open book only as wide as his chest and never reaching past his shoulders, its
  two cream pages showing as a small pale block inside the dark brown covers, head bowed to read
  the pages, one hand turning a single page over, then reading on, feet planted"
  → an **open** small book, dark cover with a cream page block and a tan spine — the most literally
  correct answer — but the page block is a thin sliver in f3–f5 and only fully reads in f7–f8.
  **Packaged as `traveler_read_alt`** for QA to compare; only one of the two is meant to ship.

**The measurement that matters** (`tools/newbox.js` — pixels that differ from the rest pose, f7):

| sequence | changed box | width |
|---|---|---|
| CURRENT shipped `traveler_read` | 1,1..61,49 | **61 px** |
| `traveler_read` (mid4) | 15,1..46,62 | **32 px** |
| `traveler_read_alt` (mid6) | 14,1..46,62 | **33 px** |

Both corrections keep the book **inside the standing figure's own 32-px silhouette**. The shipped
one is nearly twice the figure's width.

### B micro-idles

- `wr_idle_breathe` (aede162f, 6 f): "standing still and breathing quietly, a very small motion
  only: the chest and shoulders rise one pixel as he inhales and settle back as he exhales, the
  weight shifting a little from one foot to the other, the head turning a few degrees to one side
  and back, ending in exactly the same relaxed standing pose he started in, no arm gesture, no step"
  → the smallest motion of the three (peak 724 changed px at f4, back to 349 at f6). Reads as one
  standing figure throughout. **Chosen.**
- `wr_look_around` (39eaf3f6, 6 f): "standing still, looking about calmly: the head turns slowly to
  his left and pauses, then turns back across to his right and pauses, then returns to facing
  forward, the body and arms staying where they are, feet planted, no step, no gesture, no wave"
  → the head turn is visible at ×2 (f3–f5) and f6 returns near the rest pose (327 changed px).
  **Chosen.**
- `wr_shift_weight` (9f6ee459, 6 f): "standing still and easing his stance: the hips shift the body
  weight onto one leg so one shoulder drops slightly and the other rises, holding there a moment,
  then easing the weight back onto both feet and standing square again, feet stay planted on the
  ground, no step, no arm gesture"
  → the stance splays wide, the head sinks 3 px, and f6 is still 907 changed px from the rest pose —
  it does **not** return. At ×2 it reads "bracing / standing wide", not "easing his weight".
  **Author withholds**; packaged into `withheld_manifest.json` and staged for QA anyway.

## 5. Delivered (`out/ambient/manifest.json` is the contract)

All 64 × 64, feet on **row 62 on every frame of every sequence**, 0 semi-alpha, 0 clipped frames.

| id | frames | fps | loop | canvas | baseline | union bounds | footprint (frame 0) | disposition |
|---|---|---|---|---|---|---|---|---|
| `traveler_read` | 9 | 6 | pingpong | 64 | 62 | 15,1..46,62 | x 19..42 (24 px), bottom 62 | recommended replacement |
| `traveler_read_alt` | 9 | 6 | pingpong | 64 | 62 | 14,1..46,62 | x 19..42 (24 px), bottom 62 | alternative, QA to choose |
| `traveler_idle_breathe` | 7 | 5 | pingpong | 64 | 62 | 13,0..48,62 | x 19..42 (24 px), bottom 62 | recommended for the `microIdles` pool |
| `traveler_look_around` | 7 | 5 | pingpong | 64 | 62 | 12,1..51,62 | x 19..42 (24 px), bottom 62 | recommended for the `microIdles` pool |
| `traveler_shift_weight` | 7 | 5 | pingpong | 64 | 62 | 12,1..50,62 | x 19..42 (24 px), bottom 62 | **author withholds** |

Every sequence's frame-0 footprint is `x 19..42 (24 px), bottom 62` — identical to the shipped
`ambient/traveler_read_f0.png` footprint, so nothing about the stage's grounding changes.

`manifest.json` is deliberately **empty of accepted entries until Visual QA reports**; every
sequence currently sits in `withheld_manifest.json`. The lead promotes entries after the verdict
(§9).

QA material: `qa/ambient_sheet_x{1,2,8}.png` (one row per sequence),
`qa/_read_r{1,2,3}_x2.png` and `qa/_micro_r1_x2.png` (390-wide ×2 phone composites — the verdict
view), `qa/_bookzoom{,2,3}_x8.png` (the torso at ×8, where the book scale is actually decidable),
`qa/_ref_vs_gather_x6.png` (rest-pose overlay).

## 6. Neutral staging

Blind set: **`h4t9/`** (32 files, opaque shuffled codes, no text, no chrome). Key:
`tools/BLIND_KEY.txt`, outside the staged folder. Per code `_a` native, `_b` ×2, `_c` ×8,
`_d` ×2 on a plain ground band (rest figure + three frames). Distractors: the CURRENT shipped
`traveler_read`, `traveler_pick_inspect` and `traveler_wipe_brow`.

STAGING CHECK (`NEUTRAL_STAGING_CHECKLIST.md`): A1 opaque names ✓ · A2 no ordinals (`_a.._d` name
scale and presentation, not sequence — say so to the reviewer) ✓ · A3 opaque dir ✓ · A4 codes
shuffled by a fixed permutation, not build order ✓ · A5 ✓ · A6 native / ×2 / ×8 / in-context all
present ✓ · B1 no baked text ✓ · B2 plain ground band, no UI chrome ✓ · B3 no labelled sheet inside
`h4t9/` ✓ · D1 key outside ✓ · D4 known limit: the reviewer's own `git status` and `CLAUDE.md`
disclose the product premise and that a `WORLD_REWARD_DEPTH_01` round exists — discount any finding
that merely restates the premise. **STAGING CHECK: PASS**

## 7. AUTHOR ASSESSMENT

What I believe holds at ×2:

- **`traveler_read` (mid4)** — the book is present in every frame from f3, sits at chest height with
  the head bowed to it, and never widens the sprite. It answers the device finding without
  reintroducing the T01 failure. My doubt: the cover faces the viewer, so it could read
  **"holding a small box / a plaque"** rather than "reading"; and it is a brown block against a
  green vest, so its legibility rests on the pale spine.
- **`traveler_read_alt` (mid6)** — the more literally correct picture (an *open* book with cream
  pages) but it only becomes that in f7–f8; f3–f5 read as cupped hands. If QA can see the pages at
  ×2 in the earlier frames, this is the better of the two.
- **`traveler_idle_breathe`** — the safest possible micro-idle: at ×2 every frame is the same
  standing man. My doubt is the opposite of "frozen" — it may be **too small to notice**, in which
  case the cadence's visible value comes from `traveler_look_around` and this is the quiet beat.
- **`traveler_look_around`** — the head turn reads at ×2 and cannot be a gesture (the arms never
  move). My doubt: the pack swings with the head in f4–f5 and could read as a body twist.

What I do not put forward: `wr_read_small1/2/3` (invisible book), `wr_read_mid5` (a sheet of paper),
`wr_shift_weight` (splayed stance, does not return to rest).

## 8. QA VERDICT (independent Visual QA)

_(to be filled by an independent Visual QA agent working from `h4t9/`; the author does not
self-certify — `MISTAKES.md` M-04)_

**QA VERDICT:** (blind, independent, 2026-08-19; reviewer read no README/key; the set was staged with the CURRENT shipped art as distractors)

Per candidate (blind codes → key in tools/BLIND_KEY.txt):
- **nl = NEW traveler_read** — "figure lifts a small brown closed object to chest, opens it, holds it open in both hands, head tilted down. Reads as reading a small book. Book roughly head-width, plausible size. Legible at ×2 and ×1. Not a loop (frame 9 → frame 1 jump)." **PASS-WITH-NOTE** (one-shot; the table plays it pingpong, which closes it).
- **bx = read_alt** — "white smudge between the hands; cannot name it at ×2." **FAIL** (MAJOR B). Reviewer prefers nl "clearly".
- **tv = CURRENT shipped traveler_read (distractor)** — "book wider than his shoulders, ~1.5× torso, pages fanning above his head; reads as unfolding a giant map; frame 3 reads as a costume change." **FAIL** (MAJOR B) — independently confirms the owner's device finding.
- **wp = NEW traveler_idle_breathe** — "standing idle, slight breathing/weight sway, first and last frames near-identical: loops." **PASS.**
- **qm = NEW traveler_look_around** — "head and shoulders turn and hold; reads as looking off to the side; does not return to front." **PASS-WITH-NOTE** (pingpong returns it).
- **jd = traveler_shift_weight (author withheld)** — "shifting weight / small shuffle; at ×8 starts to look like a stagger." **PASS-WITH-NOTE** — stays withheld.
- **sr = CURRENT shipped traveler_pick_inspect (distractor)** — "pickaxe pops into existence between frames 1–2, hands don't grip, no action; reads as a man holding a pickaxe and doing nothing." **FAIL** (MAJOR A/B).
- **ea = CURRENT shipped traveler_wipe_brow (distractor)** — "shading eyes / wiping brow; frame 7 arm reads truncated." **PASS-WITH-NOTE** (MINOR A).
Staging note from the reviewer: folder names leaked the category; the ambient ×2 plates were frames on flat grey, not in-scene.

Set verdict as written by the reviewer: **FAIL** (tv, bx, sr fail; nl, wp pass; qm, jd, ea pass-with-note; prefer nl over tv/bx for the book).

### Lead's disposition (2026-08-19)
Accepted and promoted to manifest.json: **traveler_read (nl), traveler_idle_breathe (wp), traveler_look_around (qm)**. Rejected: read_alt. Withheld: shift_weight. Consequence for shipped art: the current read is replaced by nl; **pick_inspect is taken out of the rotation** (its PE01 lead override is withdrawn on this verdict — the frames stay packaged); wipe_brow stays with the MINOR note recorded.

## 9. INTEGRATION NOTES (for the lead)

`PACKAGING.md` carries the file list, sizes, anchors and footprints. In outline:

- `Scripts/art/package-art.js` — add a third ambient source after the PLAYABLE_EXPANSION_01 block,
  reading `WORLD_REWARD_DEPTH_01/ambient/out/ambient/manifest.json` with the same loop. Every entry
  is 64 × 64 with the feet on row 62, so the 80-wide crop branch never applies. `traveler_read`
  **replaces** the PE01 file of the same name (9 frames → 9 frames, no stale file).
- `lib/ui/icons/ambient_assets.dart` — the `read` scene's `bounds` narrows from `_bRead`
  (1,1..61,62) to **15,1..46,62**. The interesting consequence: the corrected book no longer blocks
  a companion layer, so the doc comment "the book spans x 1..61 … any cat layer should sit at
  |dx| ≥ 44" becomes wrong, and `read` *could* take a cat like the other solo scenes. That is a
  design choice for the lead, not an art fact — flagged, not made.
- The micro-idles are new scenes for stream F's `microIdles` pool, not for the main rotation.
  Suggested `AmbientScene` entries are in `PACKAGING.md`.
