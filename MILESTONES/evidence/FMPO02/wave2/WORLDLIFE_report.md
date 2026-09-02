# FMPO02 wave 2 — WORLDLIFE report (ART-04)

Balance **9,551 → 8,758** account-wide; **60 generations are this family's** (the
rest belong to the wave's other PROD leads on the same account). Cap 320 — **19% used**.
Ledger: `GAME_BIBLE/ART/exploration/FMPO02/ledger/WORLDLIFE.md`.
Files: `GAME_BIBLE/ART/exploration/FMPO02/out/worldlife/` (131 PNGs + `manifest.json`).
Placement proof: `review/worldlife/ATLAS_PLACEMENT_FINAL_x1.png`, `ATLAS_NORTH_x2.png`.

## Accepted — 19 assets (17 overlays, 3 props; `prop_ice_tower` pairs with an overlay)

| asset | canvas | frames | atlas x,y | world x,y |
|---|---|---|---|---|
| `overlay_redwyrm` *(supersedes)* | 96x64 | 9 | 700,240 | 4200,1440 |
| `overlay_redwyrm_breath` | 128x64 | 8 | 780,300 | 4680,1800 |
| `overlay_stormdrake` *(supersedes)* | 96x56 | 9 | 350,190 | 2100,1140 |
| `overlay_stormdrake_breath` | 128x56 | 8 | 832,688 | 4992,4128 |
| `prop_ice_tower` | 48x80 | 1 | tl 452,172 | anchor 2712,1512 |
| `overlay_ice_beacon` | 48x80 | 7 | 452,172 | 2712,1032 |
| `prop_fairy_castle` | 96x80 | 1 | tl 287,393 | anchor 2010,2832 |
| `overlay_fairy_motes` | 32x32 | 4 | 378,420 | 2268,2520 |
| `prop_storm_house` | 56x64 | 1 | tl 190,858 | anchor 1308,5526 |
| `overlay_storm_lightning` | 48x64 | 8 | 208,838 | 1248,5028 |
| `overlay_deer2` | 48x40 | 9 | 230,330 | 1380,1980 |
| `overlay_bear3` | 28x28 | 9 | 330,650 | 1980,3900 |
| `overlay_yeti3` | 44x40 | 9 | 600,160 | 3600,960 |
| `overlay_wolfpair` | 56x44 | 9 | 302,698 | 1812,4188 |
| `overlay_wagon` | 32x32 | 1 | 400,512 | 2400,3072 |
| `overlay_crows` | 24x24 | 7 | 536,506 | 3216,3036 |
| `overlay_snowdrift` | 32x32 | 9 | 330,150 | 1980,900 |
| `overlay_lantern` | 16x16 | 5 | 450,520 | 2700,3120 |
| `overlay_chimney_smoke2` | 16x16 | 7 | 462,514 | 2772,3084 |
| `overlay_fishing_boat` | 24x24 | 5 | 740,660 | 4440,3960 |

## Exact JSON entries for `atlas_layout.json`

**Replace** the two shipped dragon rows with these (same asset keys, no new ids):

```json
{ "asset": "env/overlay_redwyrm", "x": 4200, "y": 1440, "width": 96, "height": 64, "frames": 9, "frameMillis": 400, "playLoops": 2, "intervalMillis": 22000, "drift": {"x":0,"y":0}, "travel": {"x": 22, "y": -4}, "opacity": 1 }
{ "asset": "env/overlay_stormdrake", "x": 2100, "y": 1140, "width": 96, "height": 56, "frames": 9, "frameMillis": 340, "playLoops": 2, "intervalMillis": 26000, "drift": {"x":0,"y":0}, "travel": {"x": 30, "y": 6}, "opacity": 1 }
```

**Add** to `overlays[]`:

```json
{ "asset": "env/overlay_redwyrm_breath", "x": 4680, "y": 1800, "width": 128, "height": 64, "frames": 8, "frameMillis": 180, "playLoops": 1, "intervalMillis": 31000, "drift": {"x":0,"y":0}, "opacity": 1 }
{ "asset": "env/overlay_stormdrake_breath", "x": 4992, "y": 4128, "width": 128, "height": 56, "frames": 8, "frameMillis": 340, "playLoops": 1, "intervalMillis": 34000, "drift": {"x":0,"y":0}, "travel": {"x": -26, "y": 8}, "opacity": 1 }
{ "asset": "env/overlay_ice_beacon", "x": 2712, "y": 1032, "width": 48, "height": 80, "frames": 7, "frameMillis": 320, "playLoops": 2, "intervalMillis": 12000, "drift": {"x":0,"y":0}, "opacity": 1 }
{ "asset": "env/overlay_fairy_motes", "x": 2268, "y": 2520, "width": 32, "height": 32, "frames": 4, "frameMillis": 300, "playLoops": 4, "intervalMillis": 17000, "drift": {"x":0,"y":0}, "opacity": 1 }
{ "asset": "env/overlay_storm_lightning", "x": 1248, "y": 5028, "width": 48, "height": 64, "frames": 8, "frameMillis": 110, "playLoops": 1, "intervalMillis": 13000, "drift": {"x":0,"y":0}, "opacity": 1 }
{ "asset": "env/overlay_deer2", "x": 1380, "y": 1980, "width": 48, "height": 40, "frames": 9, "frameMillis": 300, "playLoops": 2, "intervalMillis": 35000, "drift": {"x":0,"y":0}, "opacity": 1 }
{ "asset": "env/overlay_bear3", "x": 1980, "y": 3900, "width": 28, "height": 28, "frames": 9, "frameMillis": 320, "playLoops": 2, "intervalMillis": 30000, "drift": {"x":0,"y":0}, "opacity": 1 }
{ "asset": "env/overlay_yeti3", "x": 3600, "y": 960, "width": 44, "height": 40, "frames": 9, "frameMillis": 350, "playLoops": 2, "intervalMillis": 28000, "drift": {"x":0,"y":0}, "opacity": 1 }
{ "asset": "env/overlay_wolfpair", "x": 1812, "y": 4188, "width": 56, "height": 44, "frames": 9, "frameMillis": 300, "playLoops": 2, "intervalMillis": 27000, "drift": {"x":0,"y":0}, "opacity": 1 }
{ "asset": "env/overlay_wagon", "x": 2400, "y": 3072, "width": 32, "height": 32, "frames": 1, "frameMillis": 12000, "playLoops": 1, "intervalMillis": 48000, "drift": {"x":0,"y":0}, "travel": {"x": -11, "y": 1}, "opacity": 1 }
{ "asset": "env/overlay_crows", "x": 3216, "y": 3036, "width": 24, "height": 24, "frames": 7, "frameMillis": 260, "playLoops": 2, "intervalMillis": 24000, "drift": {"x":0,"y":0}, "opacity": 1 }
{ "asset": "env/overlay_snowdrift", "x": 1980, "y": 900, "width": 32, "height": 32, "frames": 9, "frameMillis": 220, "playLoops": 1, "intervalMillis": 19000, "drift": {"x": 6, "y": 0}, "opacity": 1 }
{ "asset": "env/overlay_lantern", "x": 2700, "y": 3120, "width": 16, "height": 16, "frames": 5, "frameMillis": 240, "drift": {"x":0,"y":0}, "opacity": 1 }
{ "asset": "env/overlay_chimney_smoke2", "x": 2772, "y": 3084, "width": 16, "height": 16, "frames": 7, "frameMillis": 240, "playLoops": 3, "intervalMillis": 11000, "drift": {"x":0,"y":0}, "opacity": 1 }
{ "asset": "env/overlay_fishing_boat", "x": 4440, "y": 3960, "width": 24, "height": 24, "frames": 5, "frameMillis": 400, "playLoops": 3, "intervalMillis": 26000, "drift": {"x":0,"y":0}, "travel": {"x": -5, "y": 2}, "opacity": 1 }
```

**Add** to `props[]`:

```json
{ "asset": "env/prop_fairy_castle", "x": 2010, "y": 2832, "width": 96, "height": 80, "anchorX": 48, "anchorY": 79 }
{ "asset": "env/prop_storm_house", "x": 1308, "y": 5526, "width": 56, "height": 64, "anchorX": 28, "anchorY": 63 }
{ "asset": "env/prop_ice_tower", "x": 2712, "y": 1512, "width": 48, "height": 80, "anchorX": 24, "anchorY": 79 }
```

## Slot budget — 15 new overlays wanted, 8 free. Retirement proposal.

32/40 used. The two dragons supersede in place and cost nothing. That leaves
**8 free slots for 15 new overlays**, so seven must come from retirements.

**Fill the 8 free slots with the assets that answer the owner's complaint directly:**
`overlay_fairy_motes`, `overlay_storm_lightning`, `overlay_ice_beacon`,
`overlay_wolfpair`, `overlay_deer2`, `overlay_wagon`,
`overlay_redwyrm_breath`, `overlay_stormdrake_breath`.

**Retire these seven to seat the rest** (`bear3`, `yeti3`, `crows`, `snowdrift`,
`fishing_boat`, `lantern`, `chimney_smoke2`). Every candidate is near-invisible
atmosphere — a 1-frame plate at ≤0.3 opacity, or the third/fourth copy of one effect:

| retire | why it costs nothing perceptually |
|---|---|
| `overlay_cloud_shadow` @2436,3186 | 1 frame, opacity **0.16** |
| `overlay_cloud_shadow` @2136,3686 | 1 frame, opacity **0.16** |
| `overlay_cloud_wisp` @3036,2336 | 1 frame, opacity **0.3** |
| `overlay_snow_flurry` @2496,2106 | 3rd of 3; `overlay_snowdrift` is the better effect |
| `overlay_forest_mist` @2976,4236 | 4th of 4, opacity 0.4 |
| `overlay_forest_mist` @1776,4056 | 3rd of 4, opacity 0.4 |
| `overlay_birds` @2616,3876 | 3rd of 3; `overlay_crows` supersedes it in character |

Retiring these also *reduces* continuous-overlay pressure inside the J-3 band
(x276–706) — all seven run continuously today. Net: 40/40 overlays, 3 props.

If the owner prefers fewer new slots, **`overlay_lantern` and
`overlay_chimney_smoke2` are the first two to cut** — they are the least legible
at ×1 — followed by `overlay_snowdrift`.

## Judgement calls the integrator should know about

1. **The red dragon moved.** At its shipped spawn (atlas 736,306) a red dragon
   sits on red volcanic rock and is invisible — proved on the placement
   composite. Moved to 700,240, the volcano's north shoulder, where it is
   silhouetted against the ice shelf. Same reason put the fire-breath over open
   sea at 780,300 rather than in the caldera, where the plume merged with lava.
2. **The two briefs disagree on the blue drake's spawn** (ART-03 §6 says
   2280,1140; ART-04 §4 says 2400,1650). I followed ART-03 §6 as instructed, then
   shifted 30px west to 2100,1140 to clear the ice tower.
3. **Prop anchors.** ART-03 §6 quotes "world anchors" that are actually the rect's
   top-left. Under the shipped convention (`prop_black_gable`: x,y is the anchor's
   world position, anchorX/Y the sprite-local anchor) I re-derived them. Both
   forms are in `manifest.json` — please confirm which the brief intended.
4. **`prop_fairy_castle` is 96 wide, not ART-03's 64.** The accepted probe reads
   correctly on the atlas because the tree canopy inside it matches the forest's
   own canopy scale. Re-authoring at 64 would mean rebuilding it.
5. **The ice tower costs two slots** (prop + overlay) because the beacon animation
   shimmers the whole tower, not just the spire — measured change bbox is
   43x76 of a 48x80 sprite, so no small beacon crop exists.
   `overlay_ice_beacon_f0.png` is **byte-identical** to `prop_ice_tower.png`, so
   the tower never blinks between plays. The one-slot alternative is a single
   continuous overlay, but atlas x452 is inside the J-3 restricted band.
6. **Frames dropped, deterministically, never repainted.** Red breath ships 8 of
   9 (the dragon vanishes from frame 8). Blue breath ships 8 of 9. Bolt ships 8 of
   9. Fairy motes ship 4 of 9 — source frames 0,1,5,6, the ones that stay lit;
   the generator turned the motes into dark insect shapes on alternate frames
   across two attempts.
7. **`overlay_chimney_smoke2` has a small chimney pot baked into its base** — it
   must sit on a roofline, never on open ground.
8. **`overlay_lantern` is 16x16, not the requested 12x12** — PixelLab rejects any
   side below 16.
9. **The two red overlays can co-occur.** Intervals are 22s and 31s so it is
   uncommon, but if the owner ever sees two red dragons at once, phase them.

## Not delivered (recorded and left, per the two-failure rule)
- **Ship under sail** — 3 attempts, all failed (a person in a boat, a feather).
  The shipped `overlay_ship` stays.
- **Sea birds** — 1 attempt with opaque rectangles baked in; it also duplicates
  the shipped `overlay_birds`. Not chased.
- **Chimney smoke variant B** — 2 attempts (a brazier, then a white stick).
  Variant A ships; the shipped `overlay_smoke` serves as the second variant.

## Verification done
- Every one of the 131 shipped PNGs: `partialAlpha=0`, `reservedTeal=0`
  (#58D6C0 ±10). Pure-black outline pixels match the shipped env baseline
  (`overlay_skydragon`, `overlay_redwyrm`, `prop_rimespire`, `prop_black_gable`
  all carry them) — established convention, not a new defect.
- Every placement composited onto the real `atlas_base.png` and read at ×1 and
  ×2. Three positions were corrected because of what the composite showed.
- `overlay_skydragon` (68x31, 28f) untouched; no file in `assets/` was modified
  by this family. (`assets/art/v1/world/atlas_base.png` shows dirty in git — that
  is the concurrent atlas lead's work. `tools/onatlas.js` only *reads* the master
  and writes its crops elsewhere.)
- No Dart, no JSON, no `package-art.js` edited, as instructed.

**Caveat on the placement proof:** the composites were rendered against
`atlas_base.png` as it stood during this run, while the terrain lead was editing
it. Placements are given in stable atlas coordinates, but three of them were
chosen for *contrast against the terrain underneath* — the red dragon and its
breath (against ice and sea) and the crows (against grass, not dark forest). If
the atlas master repaints the volcano's north shoulder, the east coast, or the
Forgotten Hollow, re-check those three on the final master.

## UNRESOLVED
- **The slot retirement list needs an owner decision** before integration. Seven
  overlays must go to seat all fifteen new ones, or seven of the new ones must
  be dropped. My recommendation is the retirement table above; it costs seven
  near-invisible low-opacity plates and buys seven readable creatures.
- **Prop anchor convention** (item 3) — confirm before the props are placed.

---

# Addendum — WORLD_FIX pass (answering FINAL-04 #3, #4, #5, #6)

Cap 160 generations, spent 160. Ledger:
`GAME_BIBLE/ART/exploration/FMPO02/ledger/WORLD_FIX.md`. Placement evidence:
`review/worldlife/ATLAS_PLACEMENT_HEAD_x1.png` and `_north_x2.png`, both
written by `tools/worldlife-composite.js`, which reads the atlas and the
layout at HEAD-of-disk and the sprites from the **packaged** `assets/art/v1/`
tree — so a sheet cannot pass against pixels that no longer exist. That was
FINAL-04 #4's whole complaint about the old sheet, and it is now structural
rather than a promise.

## #3 — the hero props are no longer isometric dioramas

Both were re-authored with `create_map_object` against a crop of their own
site, which is what finally broke the plinth: six `pixen` rolls at 64x48 and
40x36 all came back as diorama tiles on an extruded soil block, whatever the
prompt said.

| | was | now |
|---|---|---|
| `prop_fairy_castle` | 96x80 rhombus, soil side wall, internal oaks at ~28 px against the map's ~10 px canopy | **31x39**, flat, no plate, no side wall — the smallest landmark prop on the atlas |
| `prop_storm_house` | 56x64 diorama on a plinth | **25x21**, one dark roof and one lit window seen from above |

`review/fix/PLACE_glade_x4.png` and `PLACE_storm_x4.png` show both on the
current atlas. `overlay_storm_lightning` moved with the house so the bolt
still ends on its roof; the sprite itself is unchanged.

## #4 — placement re-verified against HEAD, and two entries moved

- **`overlay_yeti3`** was at atlas 600,160, straddling N3's open teal lead —
  a snow ape waist-deep in water. Now 600,190, solid snow.
- **`prop_ice_tower`** anchored at atlas y=252, eighty pixels below the crag
  it is named for. The crag measures 452–490 x 153–178 on the current
  composite; the anchor is now its foot, atlas (468,177), and
  `overlay_ice_beacon` moved with it so `_f0` still sits byte-identical on the
  prop rect.
- All 46 entries were composited and read. Nothing else stands on water or on
  the wrong terrain.

## #5 — creature scale, and what it cost

| | was | now |
|---|---|---|
| `overlay_deer2` | 48x40, 9f | **16x16, 1f** |
| `overlay_yeti3` | 44x40, 9f | **16x17, 1f** |
| `overlay_wagon` | 32x32, 1f | **14x13, 1f** |
| `overlay_wolfpair` | 56x44, 9f | **unchanged** |

`review/fix/cmp_deer.png` is the clearest proof: the shipped doe rendered
three times the height of the conifers beside her; the replacement sits in the
same band as the trees.

**Two honest costs.**

1. **The deer and the yeti lost their loops.** The cap was reached before the
   `animate_image` calls could be rolled, so they ship as static markers
   (`frames: 1`, no interval — always drawn). FINAL-04 #5's own second option
   is "declare them markers and treat them consistently as such", and that is
   now literally what they are. Restoring motion costs four `animate_image`
   calls, about 8 generations.
2. **`overlay_wolfpair` was not halved.** Two rolls at 28x28 failed the way
   the first round's did — one on a hard isometric snow diamond, one an
   unreadable grey blob. ART-03 §7's two-failure stop applies: the accepted
   full-size pair stays rather than shipping the plate this round exists to
   remove.

## #6 — the motes are off the scree and are no longer gold

Moved from atlas 378,420 (brown scree) to **292,424**, canopy immediately west
of the castle, and toned: each of the four frames desaturated 35% toward its
own luma with a honey-green cast, deterministically
(`tools/worldfix-prep.js`, the `toneBronze` pattern). The sweep that chose
0.35 is `review/fix/motes_tone_sweep.png` — 0.25 was still gold, 0.45 went
grey. They now read as pale honey lights on the canopy.

**NOT FIXED: they are still discs, not winged silhouettes.** Two re-authoring
rolls were rejected — one came back an opaque forest scene with `no_background`
ignored, the other six 8x5 orange insects, three times the 2–3 px body the
brief asked for — and the cap stopped a third. The diagnosis for the next
round is the canvas: at 32x32 the model draws an 8 px body whatever the prompt
says, so roll it at **16x16**.

## Guards

`node Scripts/art/package-art.js` and `--check` green (1,767 files up to
date); `check-art-palette.js` ok over 1,822 PNGs — no teal collision, no
semi-transparent pixel. `flutter test test/atlas_layout_test.dart
test/atlas_screen_test.dart test/atlas_scene_test.dart` — **71 passed**.
Overlay count is still **40**; no slot was added.

Sixteen orphan frames (`overlay_deer2_f1..f8`, `overlay_yeti3_f1..f8`) were
deleted from `assets/art/v1/env/`; `--check` reported every one of them before
they went, which is the guard doing its job.

## Addendum 2 — cap-raise pass: the loops came back, the motes did not

**The three halved creatures are animated again.** The cap was what stopped
them last pass, not the art; with +120 they cost 3 generations between them.

| overlay | canvas | frames | play |
|---|---|---|---|
| `overlay_deer2` | 16x16 | **5** (`d41aef2d`) | 300 ms x 4 loops / 35 s |
| `overlay_yeti3` | 16x17 | **5** (`5afb2ef9`) | 350 ms x 4 loops / 28 s |
| `overlay_wagon` | 14x13 | **5** (`017b3d4a`) | 400 ms x 6 loops / 48 s — six loops keep the 12 s of travel it had as a still |

Each was animated from its own halved still, so the canvases the review asked
for are unchanged and no sprite grew back. Read on the atlas at ×7–×8:
`review/fix/deer_astrip.png`, `yeti_astrip.png`, `wagon_astrip.png` — the doe
lifts and lowers her head while the fawn shifts, the snow ape sways at the
shoulders, the oxen plod and the wagon rocks. No frame drifts off its origin,
no frame changes colour, and all fifteen frames are fully opaque-or-transparent
(0 partial-alpha pixels). **The static-marker debt from the last pass is
cleared.** `atlas_layout.json` frame counts and timings updated to match.

**The motes stay as they are — the 16x16 roll failed too.** The diagnosis
("at 32x32 the model draws an 8 px body whatever the prompt says, so roll it at
16x16") was wrong about the lever. At 16x16 the model drew **one fairy
character with a face and a body** (`review/fix/motes16_x12.png`), which the
brief forbids outright. Three rolls now: an opaque scene, six orange insects,
one figure. The shipped four frames — moved off the scree and toned honey-green
— remain what ships, and the disc shape is recorded as **NOT FIXED**.

The next attempt should stop asking for creatures at all: the thing wanted is a
particle field, so author it as scattered specks with a forced palette
(`create_image_pixflux` with `color_image`) rather than as "fairies", or accept
the toned discs as final. That is an owner call, not another roll.

## Guards, cap-raise pass

`package-art.js` and `--check` green (**1,779 files up to date**);
`check-art-palette.js` ok over 1,834 PNGs; `flutter test` on the three atlas
suites — **71 passed**. Overlays still **40**.
