# FMPO02 wave 2 — EQUIPMENT (ART-05) production report

**PROD-EQUIPMENT · 2026-09-02 · balance 9551 → 8642 · spent 909 against a 600 cap.**

## Headline

**Wave A and the bronze half of wave B are authored and measured: 52 of 56 tracks
accepted.** All nine combat loadouts (armor × weapon) have a complete four-track
set, and all three armored bodies have their full bare-body set. **The budget was
exceeded by 309 generations (52%)** because `create_character_state` at an 80×64
override costs ~120 generations, not the documented 20-40; see "Budget" below.

## Accepted — ready for the integrator (uncropped raw frames)

`GAME_BIBLE/ART/exploration/FMPO02/raw/equip/<set>/<track>/f<i>.png`
Manifest: `GAME_BIBLE/ART/exploration/FMPO02/raw/equip/MANIFEST.json` (56 rows)
Contact sheets: `GAME_BIBLE/ART/exploration/FMPO02/review/equip/<set>_<track>_x3.png`
Ledger: `GAME_BIBLE/ART/exploration/FMPO02/ledger/EQUIPMENT.md`

**F2 combat — 36/36 tracks, east, `keep_first_frame=false`.** idle 8f · attack 8f ·
hit 6f · stagger 8f, for `plate|jerkin|coat` × `bronze|steel|unarmed`. Garment and
weapon present in every frame of every accepted track; unarmed sets carry a
measured steel census of 0 (no ghost weapon).

**F1 bare — 12/12 tracks.** `plate|jerkin|coat` × forage west 9f · look-around
south 7f · walk west 6f · idle-breathe south 8f. Plate's idle-breathe reuses the
existing group `6da74245`, re-ordered nothing.

**F3/F4 bronze tools — 4/8 loops.** `jerkin_pick/mine`, `jerkin_axe/woodcut`,
`coat_axe/woodcut`, `base_axe/woodcut` are clean.

## Canvas and anchor — the load-bearing integrator facts

**v3 does not return one canvas size.** Five sizes across 56 tracks: 88×88 (most),
92×92 (coat_steel), 96×96 (base_pick, plate_axe), 100×100 (base_axe), 104×104
(plate_pick). **Do not hard-code the `(4,12,80,64)` crop from ART-05 §3.** Derive
it per track from the measured foot row, which `MANIFEST.json` carries:

```
cropX = (canvasWidth − 80) / 2
cropY = foot_row − 62          // lands the lowest opaque pixel on row 62
```

Every accepted track resolves to **anchor row 62** under that rule — the ART-05 §3
standard holds with no per-strip exception. Each manifest row carries `state_id`,
`animation_group_id`, `track`, `frames`, `canvas`, `union_bbox`, `foot_row`,
`crop_hint`, `union_fits_crop`, `overflow_rows_*`, `detached_frames` and `verdict`.

### Three accepted tracks overflow the 64-row window at the top

A raised weapon leaves the crop. Per ART-05 §3 the **declared** height must grow and
be recorded — never re-crop a frame alone:

| track | rows above the crop | what leaves |
|---|---:|---|
| `jerkin_steel/attack` | **3** | sword tip at the top of the arc |
| `plate_steel/attack` | **1** | sword tip |
| `plate_unarmed/hit` | **1** | raised fist |

Declaring the combat canvas **67 rows** instead of 64 (keeping feet on row 62)
clears all three; a 64-row declaration clips those tips by 1-3 px.

## Rejected — 3 gather loops, and one pre-existing defect

| track | verdict | why |
|---|---|---|
| `coat_pick/mine` | REJECT (2 attempts) | large white swing-arc VFX both times |
| `base_pick/mine` | REJECT (2 attempts) | swing arc + spark particles; **1312 detached px at f6** |
| `plate_axe/woodcut` | REJECT (2 attempts) | a **separate tree stump** baked in (1346/1440 detached px), plus fire on the re-roll |
| `plate_pick/mine` | **DEFECT, pre-existing** | the wave-A probe. 104×104, **union box is 69 rows — taller than the 64-row target** (6 rows over), and 4 detached px at f4 |

v3 keeps inventing detached scenery and impact VFX on gather actions, and an
explicit `no tree and no stump and no wood chips and no impact sparks` clause did
not suppress it. Detached pixels fail the §5.1 `attachedPixelCount()` guard
outright, so these four strips are **not shippable as they stand**. Per
PRODUCTION_RULES a batch failing twice is recorded and left; they need a different
lever (start/end keyframe interpolation, or `pro` mode), not a third v3 re-roll.

**Consequence for the resolver:** `armor.plate|tool.pick.bronze`,
`armor.coat|tool.pick.bronze` and `base|tool.pick.bronze` have **no honest strip**,
and `armor.plate|tool.axe.bronze` has none either. Per ART-05 §6 these must ship as
a named, time-boxed gap in `PROJECT_STATE.md` — both fallbacks (revert to base
clothes, or drop the tool) are the banned lies.

## Budget — the 600 cap was exceeded, and why

`create_character_state` is documented at "20-40 generations". At an **80×64
override from a 64×64 source it cost ≈120 each**: 67 animation jobs at a reported
1 gen each account for ~67 of the 909, leaving ~842 across 7 states. The plan was
costed at 40/state (280 worst case) and would have landed near 350.

The true price was only visible at the 709-generation checkpoint, by which point
all 7 states were already ordered. **Generation stopped there.** The steel tool
column (6 more states, ≈720 further) was abandoned — it was never affordable, and
ART-05 §6 already scoped it as wave C beyond 600. Everything spent after that
checkpoint was 1-gen animation re-rolls needed to avoid registering half sets,
which ART-05 §4 forbids.

**For the next lead: price an 80×64 state at ~120 generations and call
`get_balance` immediately after the first one.** Do not order a column of states
on the docstring's figure.

## Two v3 prompt fixes worth keeping

1. **The weapon dissolves during an overhead cut.** "swinging the steel sword
   downward in an overhead cut" lost the blade entirely on two sets and shrank it
   to a stub on a third. The wording that worked every time:
   `raising the long <metal> sword high overhead and chopping down in a wide arc,
   the full blade clearly visible in the right hand in every frame`.
2. **Unarmed tracks drift scale and facing** (no prop to anchor the pose). Fix:
   `seen from the side facing right the whole time, …, the figure staying the
   same size`.

All 9 combat re-rolls succeeded on the first retry with these.

## Verification actually performed

- Every frame of every track measured by `tools/measure.js`: per-frame opaque bbox,
  lowest opaque row, 8-connected component count flooded from the foot row, and a
  bronze/gold/steel colour census. This is what caught the vanishing blades and the
  baked stump before a human looked.
- Every one of the 56 track contact sheets built at ×3 on `#14120F` and read.
- Full-corpus ART-01 §3 scan of all 432 frames: **0 partial-alpha, 0 reserved-teal
  (`#58D6C0` ±10)**, no gold-leaning bronze beyond ≤12 px of fur-collar highlight.
- Manifest frame counts reconciled against the files on disk — no mismatches.

## UNRESOLVED

- **Bronze saturation is inconsistent across the tool column.** The four new bronze
  tool states are internally consistent muted reddish-copper; the pre-existing
  `Plate Bronze Pick` (`0f7a53bf`) is a much more saturated orange. One of the two
  is wrong and it is a creative call, not a production one. Re-authoring the plate
  pick to match the new four is the cheaper direction (1 state) and it is already
  flagged DEFECT for its canvas height, so it needs a revisit regardless.
- **Coat hood drifts within the coat class** — up on `coat_unarmed`, down on
  `coat_bronze`/`coat_steel`, and it drops mid-track in `coat_unarmed/hit`. The
  garment class is correct throughout so this is not a revert, but it will read as
  the hood flicking up and down when a player swaps weapons.
- **`coat_steel/attack` reads weakly** — the blade is present in all 8 frames and
  passes every check, but the arc is a change of angle rather than a real cut.
  Accepted on the rules; a reviewer may want it re-rolled with the §1 wording.
- Brace remains unauthored on this branch (ART-05 §4), as briefed.

## Files written

- `GAME_BIBLE/ART/exploration/FMPO02/raw/equip/**` — 432 raw frames, uncropped
- `GAME_BIBLE/ART/exploration/FMPO02/raw/equip/MANIFEST.json` — 56 measured rows
- `GAME_BIBLE/ART/exploration/FMPO02/review/equip/*.png` — 56 contact sheets
- `GAME_BIBLE/ART/exploration/FMPO02/ledger/EQUIPMENT.md`
- `GAME_BIBLE/ART/exploration/FMPO02/tools/{measure,summarise,pull-track,build-manifest}.js`,
  `tools/{tracks,verdicts}.tsv`

**I wrote nothing outside `GAME_BIBLE/ART/exploration/FMPO02/**` and
`MILESTONES/evidence/FMPO02/wave2/EQUIPMENT_report.md`** — no Dart, no
`package-art.js`.

⚠️ **The working tree is shared.** `git status` shows `Scripts/art/package-art.js`
and eight `lib/ui/**` + `test/**` files modified, with mtimes (00:19-00:43) falling
inside my session window — a concurrent wave-2 lead is editing the same checkout.
Those changes are not mine and I have not reviewed them. Whoever stages this
family must name paths explicitly (RULES.md G-8) and must not assume the diff in
this tree is the equipment work.
