# WORLD_REWARD_DEPTH_01 — ambient packaging

```
STATUS: packaging contract for the lead · NOT CANON · nothing here has been integrated
```

Companion to `README.md`. Regenerate everything below with
`node tools/package.js` (reads `tools/accept.json`).

## 1. Files

`out/ambient/`:

```
traveler_read_f0.png … traveler_read_f8.png              (9)
traveler_read_alt_f0.png … traveler_read_alt_f8.png      (9)
traveler_idle_breathe_f0.png … _f6.png                   (7)
traveler_look_around_f0.png … _f6.png                    (7)
traveler_shift_weight_f0.png … _f6.png                   (7)
manifest.json            — accepted entries only (empty until Visual QA reports)
withheld_manifest.json   — every entry, in the same schema, for the record
```

Every file is **64 × 64 PNG, RGBA, 0 semi-transparent pixels** (alpha quantised at 128;
the quantiser never fired — PixelLab produced none).

## 2. Geometry

| fact | value |
|---|---|
| Source canvas from `animate_character` v3 | 88 × 88 |
| Crop origin | **(12, 12)** |
| Packaged canvas | **64 × 64** |
| Feet / standing baseline | **row 62** on every frame of every sequence (no 63-row dips this round) |
| Opaque pixels touching a crop edge | **0** in all 39 frames |

The 64-box, the crop origin and the baseline are the same numbers as
TRANSFORMATION_01 and PLAYABLE_EXPANSION_01. No `anchorX` is needed: no sequence is
wider than 64.

## 3. Measured opaque bounds and footprints

`bounds` = union opaque box across the sequence. `footprint` = `Scripts/art/png.js`
`footprint()` on frame 0 — the same function `package-art.js` uses.

```text
traveler_read          64x64  15,1..46,62   footprint x 19..42 (24 px), bottom 62
traveler_read_alt      64x64  14,1..46,62   footprint x 19..42 (24 px), bottom 62
traveler_idle_breathe  64x64  13,0..48,62   footprint x 19..42 (24 px), bottom 62
traveler_look_around   64x64  12,1..51,62   footprint x 19..42 (24 px), bottom 62
traveler_shift_weight  64x64  12,1..50,62   footprint x 19..42 (24 px), bottom 62

for comparison, the CURRENT shipped art:
ambient/traveler_read_f0.png  footprint x 19..42 (24 px), bottom 62
anim/gather_f0.png            footprint x 19..42 (24 px), bottom 63   (the rest frame)
```

All five sequences share the shipped ambient footprint exactly, so the contact shadow
and the stage's `travelerCentre` placement are unchanged.

**Footprint note for `traveler_read`.** The corrected book stays inside the standing
silhouette: union bounds 15,1..46,62 against the shipped read's 1,1..61,62. In 64-box
coordinates the scene now occupies the same width as `traveler_drink` or `traveler_eat`.

## 4. Manifest schema

Same schema as the PE01 ambient manifest, plus a measured `bounds` object:

```json
{ "id": "traveler_read", "frames": 9, "fps": 6, "loop": "pingpong",
  "canvas": 64, "baseline": 62,
  "bounds": { "left": 15, "top": 1, "right": 46, "bottom": 62 },
  "note": "…" }
```

## 5. Suggested Dart entries (for the lead — not written by this agent)

`lib/ui/icons/ambient_assets.dart`, replacing the existing `read` scene:

```dart
const SpriteBounds _bRead = SpriteBounds(left: 15, top: 1, right: 46, bottom: 62);

AmbientScene(
  id: 'read',
  traveler: AmbientTrack(
    frames: _frames('traveler_read', 9),
    fps: 6,
    loop: AmbientLoop.pingpong,
    repeats: 2,
  ),
  footprint: SpriteFootprints.ambientTravelerRead, // remeasured by package-art from the new f0
  bounds: _bRead,
),
```

Micro-idles for stream F's `microIdles` pool (new entries; **not** for the main
rotation — they are the quiet beat between visits):

```dart
const SpriteBounds _bIdleBreathe = SpriteBounds(left: 13, top: 0, right: 48, bottom: 62);
const SpriteBounds _bLookAround  = SpriteBounds(left: 12, top: 1, right: 51, bottom: 62);

AmbientScene(
  id: 'idle_breathe',
  traveler: AmbientTrack(
    frames: _frames('traveler_idle_breathe', 7),
    fps: 5,
    loop: AmbientLoop.pingpong,
    repeats: 2,
  ),
  footprint: SpriteFootprints.ambientTravelerIdleBreathe,
  bounds: _bIdleBreathe,
),
AmbientScene(
  id: 'look_around',
  traveler: AmbientTrack(
    frames: _frames('traveler_look_around', 7),
    fps: 5,
    loop: AmbientLoop.pingpong,
    repeats: 1,
  ),
  footprint: SpriteFootprints.ambientTravelerLookAround,
  bounds: _bLookAround,
),
```

Both are solo scenes with no companion layer. `pingpong` is what closes the loop:
frame 6 has returned most of the way to the rest pose but not exactly, so playing
6→0 on the way back removes any pop when the cadence drops back to the held rest frame.

## 6. Not to be packaged

`traveler_shift_weight_f*.png` and `traveler_read_alt_f*.png` are in `out/ambient/`
for the record and are listed only in `withheld_manifest.json`. `package-art.js`
must read `manifest.json` only.
