# Game art — v1

**Generated. Do not edit a file in this directory.**

Everything here is produced by `Scripts/art/package-art.js` from approved
PixelLab exploration output. `Scripts/verify.sh` and CI both run it with
`--check`, so a hand-edited asset fails the build rather than shipping and being
silently reverted by the next packaging run.

To change an asset: correct it in PixelLab, update the source path or the
transformation in the packaging script, run the script, and commit both.

## Why this is a separate root from `assets/ui/v1/`

The two change for different reasons and at different rates. A navigation glyph
is redrawn when the tab bar is redesigned; the Traveler is not. Splitting them
means an interface revision cannot accidentally sweep up the game's art, and the
art pipeline does not have to know what a tab bar is.

## Contents

| Path | Native | Displayed | Source |
|---|---|---|---|
| `item/*.png` (15) | 48 × 48 | 48 (×1) | `PIXELLAB_STABILIZATION_01/out/icons_full/` |
| `item/unknown.png` | 48 × 48 | 48 (×1) | drawn by the packaging script — see below |
| `portrait/traveler.png` | 64 × 64 | 128 (×2) | `PIXELLAB_PROOF_02/out/character/traveler_portrait_64.png` |
| `sprite/traveler_south.png` | 64 × 64 | 128 (×2) | `PIXELLAB_PROOF_02/out/character/traveler_south_64.png` |
| `anim/gather_f0..f7.png` | 64 × 64 | 128 (×2) | `PIXELLAB_STABILIZATION_01/out/animation/gather_trim_f*.png` |
| `location/havens_rest.png` | 384 × 176 | 384 (×1) | `PIXELLAB_STABILIZATION_01/out/location/havens_rest_vignette_512x384.png`, keyed and cropped |
| `world/region_map.png` | 384 × 640 | — (retired from the World tab; kept as the atlas fallback) | `PIXELLAB_STABILIZATION_01/out/world/region_map_phase2_384x640.png` |
| `world/atlas_base.png` | 384 × 688 | 768 × 1376 (×2, pannable) | `TRANSFORMATION_01/out/world/atlas_base_384x688.png` — the atlas base, straight copy |
| `world/landmark_*.png` (5) | 96 × 72–96 | ×2 at atlas coordinates | `TRANSFORMATION_01/out/world/` — Haven's Rest and Frostmere are packaged but not placed (the base already draws them; Visual QA found the doubled palisade) |
| `env/prop_*.png` (7), `env/overlay_*_f*.png` (22) | 32–96 px | ×2, overlays at a layout opacity | `TRANSFORMATION_01/out/env/` |
| `ambient/*.png` (183) | 64 × 64 Traveler (80 × 64 for three wide scenes, 96 × 64 pair), 40 × 40 cat, 32 × 32 fire, 16 × 16 yarn | ×2 on the Adventure stage | `TRANSFORMATION_01/out/ambient/` via `manifest.json`; the three 80 × 80 sources are cropped to rows 8..71 so the feet stay on row 62. **Playable Expansion 01 corrections** overwrite two sequences by id from `PLAYABLE_EXPANSION_01/out/ambient/` — `traveler_read` (9 f, `manifest.json`, QA PASS) and `traveler_pick_inspect` (7 f, `withheld_manifest.json`, lead override) — see that round's README |
| `node/*.png` (8) | 96 × 96 | 96 (×1) on the gather card | `TRANSFORMATION_01/out/items/node_*_96.png` |
| `item/*.png` (+9) | 48 × 48 | 48 (×1) | `TRANSFORMATION_01/out/items/icon_*_48.png` — the bronze tier, both bowls, the root and the sigil |
| `item/pine_log.png` | 48 × 48 | 48 (×1) | `PLAYABLE_EXPANSION_01/out/items/icon_pine_log_48.png` — re-authored for oak/pine separation (Visual QA PASS); replaces the STABILIZATION_01 source for this one id |
| `combat/*.png` (119) | 64 × 64 Traveler (80 × 64 attack), 56 × 56 wolf and goblin, 96 × 96 guardian, 32 × 32 / 48 × 48 effects, 192 × 96 backdrops | ×2 on the combat stage | `PLAYABLE_EXPANSION_01/out/combat/` via `manifest.json` (kind, frames, fps, loop, canvas, baseline, `anchor`, `groundRow`, `status`); frames are already cropped there — straight copies. Sequences with `status: withheld` are packaged but must not be drawn |

Every file is drawn through `PixelAsset` or `PixelScene` at an exact integer
multiple of its native size, with nearest-neighbour filtering and no smoothing
(`ART_DIRECTION.md` **L-18**). The native size is declared in the widget, not
encoded in the filename, and there are deliberately no `2.0x/` variant
directories.

## The three assets that are not straight copies

### `location/havens_rest.png` — keyed, then framed

PixelLab returned the diorama on an **opaque white ground**, 34% of the file and
the brightest area in an otherwise dark interface. The packaging step removes it
with a **border flood fill**, not a global colour replace, so white *inside* the
art cannot be punched out by a pixel that merely matches.

It is then cropped from 512 × 384 to **384 × 176**. The source is wider than any
phone this project targets. Downscaling was rejected — the scale would be
non-integer, and a palisade of evenly spaced posts is the worst possible subject
for dropped columns. Clipping at runtime was rejected because the framing would
then change with screen width. So the framing is chosen once, in the script,
where it can be reviewed: the window keeps the gate and its approach trail, the
lodge, the forge, the well, and grass on both flanks.

### `item/unknown.png` — drawn in code, and the exception is deliberate

The one file here authored by the script rather than generated. **It is not art
and must not look like it.** Two colours, a rim, nothing inside — no aperture, no
centred mark, no frame ring.

That constraint is not aesthetic. A small element centred inside a darker frame
is chrome grammar, and chrome grammar is what made the Hollow Sigil read as a
padlock, an equipment slot, a disabled cell and a coin across five attempts —
four systems Stride does not have. This icon sits in the grid cell most likely
to be misread, so it asserts nothing at all. It looks unfinished because it is.

### `lib/ui/icons/sprite_footprints.dart` — measured, not an image

The packaging step also emits the ground-contact span of each placeable sprite,
measured across its lowest four opaque rows. That table is what makes the contact
shadow *derived from the sprite*: a caller places a sprite and cannot pass a
shadow width, so the shadow cannot disagree with the figure standing on it.

The animation is measured on its **rest frame only**, and every frame shares that
footprint. Per-frame measurement would be more faithful and would look wrong —
the figure crouches, so the shadow would swell and shrink under a character whose
feet never move.

## What replaced what

The item icons and the portrait supersede a code-rendered set in
`assets/ui/v1/`, which the milestone brief classes as **evidence, not production
art**. The Training Axe is why the swap was worth its layout cost: three rounds
of the code-rendered icon were read as "hammer" by blind reviewers in-grid, and
the PixelLab edit was the first ever read as an axe.

The portrait supersedes a placeholder from the **paused** portrait workstream
(`GAME_BIBLE/ART/exploration/CHARACTER_PORTRAIT_CLOSEOUT.md`). That closeout
records what its four rounds never solved — the lower face, the ear, the
jaw/neck junction and the mouth, each "present in measurements, absent in
perception". The PixelLab portrait resolves all four.

## Carried corrections

Two are tracked against this asset set and are recorded in
`MILESTONES/PLAYABLE_DEMO_PHASE_1_CLOSEOUT.md`:

- **The region map's watercourse** does not resolve at native scale.
- **Gather frame 5** does not resolve anatomically.

Both are scheduled production corrections against art that is otherwise
approved. Neither blocks the demo.
