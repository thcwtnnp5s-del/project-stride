# ACTIVITY_FEEL_01 — PixelLab production round

**Milestone:** `MILESTONES/ACTIVITY_FEEL_PRESENTATION_01.md` (stream E) ·
**Date:** 2026-08-19/20 · **Balance at open: 266** generations (verified by
`get_balance`; the memory figure of ≈780 was stale).

## 1. World master — ACCEPTED (blind PASS-WITH-NOTE), r2

The atlas base re-authored as **one** 384 × 688 painting for display at
layout `scale: 4` (1536 × 2752 world px) — the whole landmass in one
generation, so seams cannot exist (`MISTAKES.md` M-12 applied: regenerate the
base at the size wanted, never butt tiles).

- `world/master_r1.png` — `create_image_pro` 384×688, style anchored on the
  shipped `atlas_base.png` via raw.githubusercontent URL (40 gens),
  job `86b9e43b`. Blind Visual QA on phone-framed survey/standard/close
  views plus four biome-join details, against the shipped two-tile world
  staged identically: **map_b PASS-WITH-NOTE, "CLEAR IMPROVEMENT"** —
  reads as a continent slice; settlements small within the landscape; no
  assembly seams; vibrant without garishness; crisp at max zoom.
  One MAJOR: the Forgotten Hollow cave region read as an "ink blot / hole
  in the map" at survey zoom.
- `world/cave_inpainted_96.png` — `inpaint_image` on the 96×96 crop at
  native (52,254), mask (30,28,48,44), job `9353aed4` (~20 gens): a framed
  cave mouth, no pure black. Composited back → **`world/master_r2.png`**,
  the shipped candidate (`qa/map_b2_hollow_x2.png` for the after view).
- MINOR notes accepted as known cosmetics (see milestone §known issues):
  two foliage-kit contrast (dark-outlined trees beside soft pale bushes),
  moor squiggle texture, the long unsupported mine rail, small unnameable
  props (spiky object at the mine, grey blob at the ruined tower).
- QA staging lesson recorded: the reviewer could see sibling production
  filenames while locating the neutral views — stage future blind rounds
  in a directory whose path reveals nothing.

Location/route geometry measured off the painting:
`world/atlas_layout_draft.json` (verified visually via
`world/draft_overlay_x2.png`). Landmark names *Old Watch* and *Broken
Tower* are art-stream proposals like the Q-07 ones, not World Designer
decisions.

## 2. Gathering profession loops — ACCEPTED (blind PASS-WITH-NOTE ×3)

`animate_character` v3 on the Traveler (`c82b7da5…`), west-facing, 1 gen
each. Round 1 (jobs in groups `2ef7748d` woodcut / `64f73d02` mine /
`4d697704` forage): the axe and pick **floated detached around the body**
— the known failure; the forage kneel-and-pick was good. Round 2 for
woodcut/mine re-animated **from a round-1 frame in which the tool is
already held**, with the end frame pinned to the same pose for loop
closure (groups `caef2d2b` woodcut2 / `33e4c61d` mine2) — tools held
throughout, swing arc and rock chips present.

Blind filmstrip verdicts at ×2: **woodcut2 PASS-WITH-NOTE** ("man swinging
an axe"; one detached-axe frame, one recovery pop), **mine2
PASS-WITH-NOTE** ("mining"; stray flecks above the head on the raise
frames), **forage PASS-WITH-NOTE** ("crouching and picking from the
ground"; soft semantics without a target object — the stage's node
scenery anchors it in the app).

Frame-order authoring applied at packaging (deterministic selection,
A-2): woodcut ships frames [0,1,2,3,5,6,7,8] (drops the detached-axe
frame); mine ships [0,1,2,4,5,8] (drops the head-fleck frames); forage
ships all 9 and the Dart table plays it ping-pong (0…8…1) so the stand-up
never pops.

Files: `activity_loops/woodcut2_f*.png`, `mine2_f*.png`, `forage_f*.png`
(raw); QA strips under `activity_loops/qa/`.

## 3. Step mark — ACCEPTED (blind round 3), replaces OD-03's turquoise boot

Three blind rounds, two geometry findings worth keeping:

- **A boot print cannot fit 12×12.** 64 pro candidates (job `cb02c0ec`,
  20 gens): every *connected* print measured 8×14–10×16 — a print's
  natural aspect is ~1:1.7, and the 12×12 slot forces the squat blob that
  sank OD-03 round 1. A trimmed print read as "a padlock / keyhole" in
  blind round 1. This closes the print direction at this slot size.
- **Shaded detail fragments at 24 dp.** A 3-ink remap of a PixelLab boot
  read as "sprout / bird / corrupted sprite" in blind round 2 (FAIL);
  the same round confirmed a **bold solid silhouette** is what survives.
- Round 3 winner: `step_icon/boot_bold_a_16.png` (pixen, job `018c3fa4`) —
  a sturdy cuffed traveler's boot, 12×12 opaque, bold silhouette **with**
  readable sole/cuff structure. Palette-conformed (A-2 luminance remap,
  3 inks) to the canonical teal `#58D6C0` family →
  `glyph_steps_new_12.png`, and the muted twin `#B3A794` family →
  `glyph_steps_muted_new_12.png`, preserving `walking_glyph.dart`'s
  two-colour rule. Blind round 3 verdict (`step_icon/qa3/`): the new mark
  **PASS-WITH-NOTE — "the only one with pixel-art craft… Ship RIGHT"**;
  the incumbent chrome glyph, facing a real competitor, was misread as
  "the letter L / a Tetris piece" and **FAILED**. Noted residual risk:
  a boot can read as an equipment slot; counter adjacency resolves it.

Rejected artifacts kept for the record: pixen prints/trails (jobs
`89fbadbb`, `f126a026`, `a6268501`, `e6b83884`, `cc2864ed`, `8ab22659`),
pro print set (64), first boots (`5f2878ed`, `96938e25`), teal remaps
`m1`/`m3`/`boot2`.

## 4. World life — bird flock overlay

`env` overlay: three distant birds, dark silhouettes (pixen `849e439a`,
1 gen; a first attempt `64ebfd1b` read as parrots and was rejected),
animated as a seamless 6-frame loop by pinning the last frame to the
first (`animate_image` `f45e3c55`, 1 gen) → `world_life/birds_f0..5.png`,
packaged as `env/overlay_birds`. Water shimmer stays dropped (five prior
failures, `MISTAKES.md`/memory); the forge-smoke overlay is retired at
scale 4 (a 32×48 plume draws 128×192 world px — taller than the hamlet).

## 5. Ledger

| Item | Gens |
|---|---:|
| World master r1 (pro 384×688) | 40 |
| Cave inpaint r2 | 20 |
| Profession loops r1 ×3 + r2 ×2 | 5 |
| Step icon: pixen ×8, pro 16px ×1 (64 candidates), bold boots ×2 | 30 |
| Birds ×2 + loop ×1 | 3 |
| **Total ≈** | **98** |

Balance 266 → **167** remaining (measured by `get_balance` at close; 99
spent, the table's ≈98 plus rounding in per-call billing).
