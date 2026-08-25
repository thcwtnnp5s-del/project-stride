# World Map Polish 01 — the atlas breathes, and the west catches fire

**Date:** 2026-08-24 · **Branch:** `playable-phase-2-multiregion` ·
**Start HEAD:** `0905b76` (Playable Polish 02, state v2.18)
**Status:** implementation complete, awaiting the owner's physical-device pass
(alongside the standing Playable Polish 02 / Audio Presentation 01 items).

Art round and full PixelLab provenance:
`GAME_BIBLE/ART/exploration/WORLD_MAP_POLISH_01/README.md`.

## What this pass is

A presentation-only World/atlas pass, run before the next iPhone acceptance
review. Two deliverables:

1. **A western forest-fire landmark** — the owner's new ask: a small animated
   cluster of burning trees at the western river fork.
2. **The restored map ambience** — the outstanding prior request: the smoke
   and cloud overlays (and every drift) that the 512 × 512 continent
   replacement dropped, re-placed on the new painting's geography.

Nothing in gameplay, health, saves, audio, or the step ledger is touched. The
change surface is: `atlas_layout.json`, eight new packaged overlay PNGs, one
`package-art.js` section, one new test, `.gitignore` re-includes, and docs.

## The re-anchor: what canon said was outstanding

- **PWRF01 device script §19** asks for *"snow in the north, mist in the
  western forest, cloud shadows drifting, birds on the coast, smoke at the
  hamlet and the mine."* The scale-4 layout (`400b5d9`) shipped 13 overlays
  answering it. The 512 × 512 replacement (`dbf2b34`) rewrote the list to 10
  — losing both cloud shadows, the cloud wisp, the chimney smoke and both
  forge smokes, and zeroing every drift (the bird flocks flapped in place) —
  with no recorded decision. This pass treats that as a regression and
  restores the same accepted assets at coordinates derived from the new
  painting.
- **The world record's next-pass list** (PWRF01 world README: drainage, the
  stamped west forest, a projection ruling, the delta bars) **remains
  deferred**: map-scale inpainting is still blocked by the recorded ~5.5 KB
  MCP transport ceiling, and the projection ruling is an owner direction
  call. Not silently dropped — restated here. The fire cluster incidentally
  gives the stamped west quarter one of the "authored features" that record
  asks for.

## 1. The western forest fire

- **What ships:** `env/overlay_forest_fire` — a burnt hollow eaten into the
  canopy with two live flames, style-matched by PixelLab inpainting against
  the shipped master's own west-fork canopy, animated by `animate_image`
  (8 frames, 200 ms, canopy and char perfectly still, flames flickering,
  embers rising). Placed at world (210, 1386): the scar's centre sits on the
  west bank of the western river fork. Six stills were generated; five are
  rejected on the record (flame icons without trees, a circular clump, an
  icon-scale pine stand) and kept as evidence.
- **What it is not:** no hit target, no label, no quest, no timer, no burn
  spread, no world-state, no audio. It is an `overlays` entry — the same
  presentation-only mechanism as the snow flurries — and the marker layer
  still paints every place's ring and label above it.
- **Scale check:** ~38 native px of content → ~76 dp at the opening zoom,
  ~38 dp at the survey floor: visible from the whole-world survey, smaller
  than the hamlet cluster, and it draws the eye west without dominating.

## 2. The restored ambience

| Overlay | Placement (world px) | Note |
|---|---|---|
| `overlay_smoke` | 1128, 1500 · 0.8 | Chimney thread on the orange-roofed Haven's Rest lodge |
| `overlay_smoke` | 1806, 1404 · 0.8 | The Stonefall adit. `overlay_forge_smoke` (32 × 48) was tried first and rejected in preview — at this adit's scale the column read as boulders; the small thread reads as a working mine |
| `overlay_cloud_shadow` ×2 | (900, 1650), (600, 2150) · drift x 12 · 0.16 | Meadow and farmland, drifting east, wrapping — the device-accepted opacity |
| `overlay_cloud_wisp` | (1500, 800) · drift x 9 · 0.3 | Over the high range |
| `overlay_birds` ×3 | unchanged spots | Drift restored to (16, −3): the flocks fly again |

One mist patch moved: (330, 1260) → (270, 1080), out of the fire's corner —
mist over a fire reads as steam and would mute the landmark.

Paint order (list order) keeps clouds above smoke and fire, and the marker
layer above everything, so no destination label can be obscured (OD-05).

## 3. Verification

- `flutter analyze` — clean.
- App suite — **652** (651 + the new layout-asset test), all green.
- New focused test (`atlas_layout_test.dart`): every asset the shipped
  layout names — base tiles, landmark art, kind glyphs, props, and **every
  frame of every overlay** — exists as a packaged file with the declared
  IHDR size. This is the seam this pass exercised: layout JSON and packaged
  PNGs had nothing holding them together, and a missing frame would have
  been a blank flicker on the device.
- `package-art.js --check` — clean (623 files, the 8 new frames
  reproducible from tracked sources on a clean checkout).
- No goldens changed: the atlas goldens render the viewport with animations
  off, and no existing test's assertions touch the overlay list's contents.

## 4. PixelLab accounting

Balance 1,840 → **1,833**: exactly the round's 7 jobs — 6 fire stills
(5 map-object rolls + 1 pixen; 5 rejected, on the record) and 1 animation.
The round README itemises every job id. Resets 2026-09-16.

## 5. Deliberately not done

- No forest-fire audio (owner ruling: audio generation closed at balance 61;
  the seam is `AudioCue` + the overlay's coordinates, noted for the future).
- No fire label, name, or lore — naming a landmark is a World Designer /
  owner call (G-3); the fire is scenery.
- No new map-scale art corrections (drainage, forest texture, projection,
  delta bars) — still blocked / owner-gated, see the re-anchor above.
- No interaction-model change: pan, pinch, tap-to-select, and the travel
  panel are untouched.

---

# Part 2 — the ambient-life pass (2026-08-25)

**Start HEAD:** `61e530d` (part 1). The owner recovered the cut-off half of
the original request: easter eggs and ambient motion — a blue yeti ice
fishing, water ripples, a cute water dragon, volcano activity, tree rustle,
and a forest-creature peek. All shipped as presentation-only atlas overlays:
no labels, no hit targets, no quests, no timers-as-gameplay, no audio, no
state.

## The one runtime change: overlay intermittence (layout schema v4)

"Occasional" was not expressible: the overlay system only looped
continuously. `atlas_layout.json` v4 adds one optional overlay field,
`intervalMillis` — a quiet gap between plays of the loop, during which the
overlay draws nothing. The gap comes **first** in the cycle, so a clock that
never advances (the test harness, reduced motion, a backgrounded app) shows
no creature at all rather than one frozen mid-appearance — and the goldens
stay egg-free by construction. Pre-v4 documents refuse the field, exactly as
v1 refuses `landmarks` and v2 refuses `rumors`. Pure cadence helpers
(`visibleAt` / `frameIndexAt`) live on `AtlasOverlay` and are unit-tested;
`AtlasOverlayLayer` simply skips an overlay during its gap.

## What was audited before generating

The five-times-failed "water shimmer" sprite (standing stop-re-attempting
note) was **not** re-attempted — water moves via a new method instead. The
Oakback Bear combat sprites are the wrong projection for a map peek and were
not reused. Nothing else usable existed. Full audit in the round README.

## What ships, and where

| Element | Where (world px) | Behaviour |
|---|---|---|
| **Volcano activity** | the caldera, (2472, 168) | Lava swells, dark smoke, a small burst, settles — 4.25 s play every ~18 s. An animated crop of the painting itself, placed back at its source coordinate |
| **Tree rustle ×2** | west forest (120, 2040); southern forest (576, 2424) | The canopy sways for ~2.7 s every 9 s / 13 s — offset so they never sync |
| **Water ripples ×2** | coast shallows (2520, 1680); the delta (2184, 2424) | Continuous slow 2.8 s loops of the painting's own water |
| **Blue yeti ice fishing** | the frozen tarn's east ice, (1461, 423) | A tiny yeti with a fishing rod over an ice hole. **Static still** — two animation attempts dropped the rod in most frames; both rejected on the record (A-1), the idle-motion seam stays open |
| **Water dragon** | the eastern sea NW of Saltreach Light, (2436, 1923) | Surfaces every ~30 s, undulates and sways for ~4 s, coils lower, gone |
| **Bear peek** | southern forest edge by the farmland, (546, 2106) | A bear head pops up every ~26 s, looks slowly left and right, blinks, ~5.4 s |

Distribution: north-east (volcano), north (yeti), east (dragon, coast
ripple), south-east (delta ripple), south-west (bear, rustle b), west
(rustle a, and part 1's fire). Nothing stacked, and every in-place crop was
checked against the layout's landmark-glyph boxes — three collisions found
in placement review (Deepwood Shrine, Sunken Rows corner, Reedmouth,
Outer Shoal) and fixed by regenerating one rustle from a clean spot and
cropping the emitted frames of the other three sets away from the glyphs.
Creatures and in-place regions all sit clear of place markers, labels,
route lines and hit targets; clouds still pass over everything.

## The seam-box problem, and the feather

An opaque animated crop against the still painting would read as a living
rectangle. Every in-place frame therefore gets a deterministic edge feather
at packaging: the outer two pixel rings are the source crop's own pixels,
the next two blend 2:1 toward the source, the next two 1:2 (A-2 —
compositing two approved images; the motion inside is PixelLab's). Frame 0
of every intermittent in-place set is the source crop itself, so a play
fades in from the painting and no pop marks the appearance.

## Verification

- App suite **655** (652 + 3: v4 gating both directions, negative interval,
  and the open-quiet/play-whole/repeat cadence contract), all green;
  `stride_core` untouched.
- `flutter analyze` clean; `package-art.js --check` clean (693 files, all
  70 new frames reproducible from tracked sources); the six CI guard
  scripts clean.
- The layout-asset presence test from part 1 now covers all 70 new frames
  automatically.
- Goldens: **unchanged** — the new elements sit outside the goldens'
  viewport, intermittent overlays are invisible at the harness's frozen
  clock by design, and the golden test passed without regeneration.
- Every placement verified in composited context previews at map scale.

## PixelLab accounting, part 2

Balance 1,833 → **1,815**: 18 generations for 17 jobs (the 16-frame volcano
animation costs 2). Rejected on the record: 2 yeti animation attempts, 2
dragon stills, 1 yeti still, 1 bear still, 1 bay ripple set, 1 relocated
rustle set. Cycle resets 2026-09-16.

## Device acceptance checklist (World screen additions)

1. Open the World tab. The map opens centred on your location and is
   readable at normal iPhone scale.
2. Pan and pinch: pinch out to the whole-world survey, back in to ×4.
3. Confirm the five visitable places are easy to identify and tap, and that
   tapping one still previews its route and journey in the panel below.
4. Pan to the **western river fork** (far west, in the deep forest).
5. Confirm the **forest-fire scar** is clearly visible: a dark burnt hollow
   in the canopy with small flames.
6. Confirm it reads as a small cluster of burning trees, animates smoothly
   (gentle flicker, ~1.6 s loop), and is not distracting or UI-like.
7. Confirm it is **not tappable** and carries no label.
8. Watch the map elsewhere: chimney smoke at Haven's Rest, a smoke thread at
   the Stonefall adit, two faint cloud shadows and a wisp drifting east,
   bird flocks actually flying, snow still falling in the north, mist in the
   west and south (none of it over the fire).
9. Confirm no overlay obscures a place name or marker for long, and no
   UI overlap/clipping at the western edge of the world.
10. Confirm travel, audio, save and step behaviour are unchanged (no
    gameplay surface was touched).

### Part 2 — ambient life (linger on each area ~30 s; the eggs are timed)

11. **Volcano** (far north-east): within ~18 s the crater stirs — lava
    swells, a smoke puff, a small burst, then it settles. Restrained, not a
    disaster; interesting from the survey zoom.
12. **Frozen tarn** (north, by Frostmere): find the tiny **blue yeti ice
    fishing** on the east ice. It is a still figure, not tappable, no label.
13. **Eastern sea** (near the lighthouse): wait ~30 s — the **water dragon**
    surfaces, sways and undulates for a few seconds, coils lower, and is
    gone. "Did I just see that?" is the intended feeling.
14. **Coast shallows and the delta**: the water visibly but gently moves in
    two places — slow ripples, no visual noise, shorelines still.
15. **Forests** (west and south): occasional patches of canopy rustle for a
    couple of seconds, in different places at different times — not a
    global wind.
16. **Southern forest edge by the farmland**: within ~26 s a **bear head**
    pops out of the trees, looks around slowly (~5 s), blinks, and ducks
    away.
17. Confirm none of the new life covers a place name, marker glyph, route
    line or tap target, and that the map never feels like it is constantly
    moving everywhere at once.
18. Toggle iOS Reduce Motion: the eggs and living regions stop entirely
    (the map goes still); turning it off brings them back.
