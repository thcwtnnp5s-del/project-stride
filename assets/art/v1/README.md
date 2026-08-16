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
| `item/*.png` (11) | 48 × 48 | 48 (×1) | `PIXELLAB_STABILIZATION_01/out/icons_full/` |
| `item/unknown.png` | 48 × 48 | 48 (×1) | drawn by the packaging script — see below |
| `portrait/traveler.png` | 64 × 64 | 128 (×2) | `PIXELLAB_PROOF_02/out/character/traveler_portrait_64.png` |
| `sprite/traveler_south.png` | 64 × 64 | 128 (×2) | `PIXELLAB_PROOF_02/out/character/traveler_south_64.png` |
| `anim/gather_f0..f7.png` | 64 × 64 | 128 (×2) | `PIXELLAB_STABILIZATION_01/out/animation/gather_trim_f*.png` |
| `location/havens_rest.png` | 384 × 176 | 384 (×1) | `PIXELLAB_STABILIZATION_01/out/location/havens_rest_vignette_512x384.png`, keyed and cropped |
| `world/region_map.png` | 384 × 640 | 384 (×1) | `PIXELLAB_STABILIZATION_01/out/world/region_map_384x640.png` |

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
