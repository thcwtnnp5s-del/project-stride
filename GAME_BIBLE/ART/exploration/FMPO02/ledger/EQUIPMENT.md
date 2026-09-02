# FMPO02 — EQUIPMENT family generation ledger

Lead: PROD-EQUIPMENT. Date: 2026-09-02. Canonical Traveler
`c82b7da5-cda0-44eb-ae4e-30d73689e115`, group `eb569ca7-85c0-426e-b0ed-f94722af148e`.

| | generations |
|---|---:|
| **Balance at start** | **9551** remaining (449 used / 10000) |
| **Balance at end** | **8642** remaining (1357 used / 10000) |
| **Spent this session** | **909** |
| **Cap** | **600** |
| **Overrun** | **+309 (52% over)** |

## The overrun, and why it happened

`create_character_state` is documented as "20-40 generations — the tier is resolved
from the canvas at generation time". At an **80×64 override from a 64×64 source it
actually cost far more.** Attributing the aggregate: 67 animation jobs each reported
"cost: 1 generation", so ~67 of the 909 is animation; the remaining **~842 is 7
character states, ≈120 each — three to six times the documented figure.**

The plan was costed at 20-40/state (7 × 40 = 280 worst case) and would have landed
near 350 total, comfortably inside 600. The first checkpoint after 4 states + 23
animations read 225 spent, which still looked consistent with ~50/state; the true
price only became visible at the 709 checkpoint, by which point every state had
already been ordered. **Generation stopped at that checkpoint**: the steel tool
column (6 further states, ≈720 more) was abandoned, and the only spending after it
was 1-gen animation re-rolls needed to avoid shipping half sets.

**Rule for the next lead: price an 80×64 `create_character_state` at ~120
generations, and call `get_balance` immediately after the first one** rather than
trusting the docstring. Do not order a column of states before that check.

## Standing facts measured this round

- **v3 does not return one fixed canvas.** Four sizes observed across 56 tracks:
  **88×88** (most), **92×92** (coat_steel), **96×96** (base_pick, plate_axe),
  **100×100** (base_axe), **104×104** (plate_pick). The crop is therefore *derived
  per track from the measured foot row*, never assumed:
  `cropY = foot_row − 62`, `cropX = (canvasW − 80) / 2`.
- A foot row of 74 on an 88 canvas lands on **row 62** of the cropped 64-row
  canvas — the ART-05 §3 anchor — and every accepted track resolves to anchor 62.
- `create_character_state` occupies ~4 concurrent `image_pixen` job slots against a
  20-slot account limit; animations occupy 1 each. Order states ≤4 at a time.
- **v3 animation frame URLs use an id that is NOT the `animation_group_id`.** The
  path is `…/animations/<anim_dir_id>/<dir>/<i>.png` and `<anim_dir_id>` only
  appears in `get_character` output. Rotation URLs, by contrast, are predictable:
  `…/<character_id>/rotations/<dir>.png` — fetch those directly and skip the poll.
- `keep_first_frame=true` yields `frame_count + 1` frames, which is how the odd
  counts ART-05 §4 asks for (9f forage, 7f look-around) are reached, since
  `frame_count` must be even.

## Rows

| job/id | tool | canvas | cost | verdict | reason |
|---|---|---|---:|---|---|
| get_balance (start) | — | — | 0 | — | 9551 remaining |
| 9 guard combat states (pre-existing) | — | 80×64 | 0 (earlier) | ACCEPT | east rotations read: correct garment, correct weapon presence, bronze reads reddish-copper. No re-creation needed. |
| a104a334 Jerkin Bronze Pick | create_character_state | 80×64 | ~120 | ACCEPT | jerkin + reddish-copper pick, both hands |
| f9e0ade5 Coat Bronze Pick | create_character_state | 80×64 | ~120 | ACCEPT | coat + pick |
| 658c5a41 Base Bronze Pick | create_character_state | 80×64 | ~120 | ACCEPT | base + pick |
| 15139375 Plate Bronze Axe | create_character_state | 80×64 | ~120 | ACCEPT | plate + bronze axe head |
| 5ed569b8 Jerkin Bronze Axe | create_character_state | 80×64 | ~120 | ACCEPT | jerkin + axe |
| 0489b96d Coat Bronze Axe | create_character_state | 80×64 | ~120 | ACCEPT | coat + axe |
| 0d495dd2 Base Bronze Axe | create_character_state | 80×64 | ~120 | ACCEPT | base + axe |
| 36 combat tracks (east, v3, 8/8/6/8) | animate_character | 88–92 sq | 36 | 27 ACCEPT / 9 RE-ROLL | see below |
| 9 combat re-rolls | animate_character | 88–92 sq | 9 | ACCEPT | all 9 fixed on the first re-roll |
| 8 tool loops (west, v3, 8f) | animate_character | 88–104 sq | 8 | 4 ACCEPT / 1 DEFECT / 3 RE-ROLL | see below |
| 3 tool re-rolls | animate_character | 88–96 sq | 3 | REJECT (2nd failure) | recorded and left per PRODUCTION_RULES |
| 11 bare-body tracks | animate_character | 88 sq | 11 | ACCEPT | forage 9f / look-around 7f / walk-west 6f / idle-breathe 8f |
| get_balance (end) | — | — | 0 | — | 8642 remaining |

**Requested 56 tracks + 7 states · accepted 52 tracks + 7 states · 1 defect ·
3 rejected · 12 re-rolls ordered (9 succeeded, 3 failed twice).**

## Why the 9 combat re-rolls were needed

Two systematic v3 failure modes, both caught by the per-frame census in
`tools/measure.js` before a human looked:

1. **The weapon dissolves during an overhead cut.** "swinging the *steel* sword
   downward in an overhead cut" lost the blade outright on plate_steel (steel
   census 2-4 px in f3-f5) and jerkin_steel (0 px at f2), and shrank the bronze
   blade to a stub on coat_bronze (288→161 px). **The fix that worked every
   time:** `raising the long <metal> sword high overhead and chopping down in a
   wide arc, the full blade clearly visible in the right hand in every frame`.
2. **Scale and facing drift on unarmed tracks**, which have no prop to anchor the
   pose — plate_unarmed_attack rotated away from east, plate_unarmed_hit grew
   ~1.9× mid-track. **Fix:** `seen from the side facing right the whole time, …,
   the figure staying the same size`.

## Why 3 tool loops were rejected twice

v3 keeps inventing **detached scenery and impact VFX** on the gather actions, which
fails the §5.1 single-component guard outright:

- `coat_pick/mine` — large white swing-arc crescents, both attempts.
- `base_pick/mine` — swing arc plus orange spark particles; 1312 detached px at f6.
- `plate_axe/woodcut` — a **separate tree stump** baked into f3-f7 (1346/1440
  detached px), and on the re-roll a stump *and* fire.

An explicit `no impact sparks and no dust and no debris, only the figure` /
`no tree and no stump and no log and no wood chips` clause did **not** suppress
them. Recorded and left — this needs a different lever (a still + interpolation
keyframe pair, or `pro` mode), not another v3 re-roll.

## ART-01 §3 compliance — full scan of all 432 downloaded frames

Measured, not eyeballed (every pixel of every frame on disk, rejects included):
**0 partial-alpha pixels**, **0 reserved-teal pixels** (`#58D6C0` ±10),
**zero gold-leaning bronze** beyond ≤12 px per frame on the fur jerkin's
cream collar (a garment highlight, not the blade). Bronze reads reddish-copper in
every bronze set. Detached components: none in any accepted track except the
pre-existing `plate_pick/mine` (4 px, f4).

## Council closure (FINAL-03 blocker 1, 2026-09-02)

Craft drew the base body while every other stage wore the armour. Six
`edit_image` reference edits (~20 each, ≈120) re-dressed the shipped
`activity_smith` (74×64, 7f) and `activity_cook` (46×64, 7f) frames with the
plate / jerkin / coat walk_west f0 as garment reference. Job ids: plate smith
efd95c40, jerkin smith 951cdd57, coat smith 82208e92, plate cook 2fef0d95,
jerkin cook 3673034a, coat cook e1d5a546. Measured before packaging: 42/42
frames binary alpha, foot row 62 identical to the source, bounding boxes within
±2 px of the source except the coat's hem (f0/f1, 4–7 px wider, correct). All
six ACCEPT first roll — hammer, spoon, pack and pose kept in every frame;
review sheet `review/craft/craft_redress_sheet.png`. Jerkin smith keeps the
ginger hair of the other jerkin strips (the same recorded hair debt).
