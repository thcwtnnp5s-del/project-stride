# World Map Expansion Refinement 02

**Date:** 2026-08-25 · **Branch:** `playable-phase-2-multiregion` ·
**Start HEAD:** `4f8459e` · **Status:** built, awaiting the owner's review and
device test.
Art round: `GAME_BIBLE/ART/exploration/WORLD_MAP_EXPANSION_REFINEMENT_02/README.md`
(job ids, rejects, and the transport record live there).

## §1 The brief

The owner's physical-device review of the World Map Polish 03 build: the
direction is good, the atlas needs one more major pass. (1) Some pieces and
biome transitions do not line up cleanly. (2) The flying dragon flies
backwards; it should breathe a little fire. (3) The west is so dense with
mountains and forest it reads as closed, not explorable. (4) The world
should feel bigger again, in all four directions. (5) Eggs must make
visual/geographic sense; add a few new quiet surprises. (6) Do not solve
scale with more names.

No device screenshots reached this machine; the written findings above are
the acceptance evidence, and each was verified against the shipped assets
before work began (four parallel review agents: canon, architecture,
visual, test-impact — their findings are folded in below).

## §2 Seam coherence (brief item 1)

The four worst WMP03 joins are gone at the source, not disguised:

- **East dither band** (the full-height "torn scan-line" column): the east
  strip regenerated with a labelled context reference — the adjacent
  composed column, not only a 64² style chip — and its volcanic top faded
  into open sea by a follow-up edit. The WMP03 recipe's gap (a style chip
  does not carry a water palette) is on the record in the art round.
- **NE "night patch"**: the dark navy sea was partly in the retained north
  strip, not only the corner — fixed by an edit-in-place daylight
  conversion of the strip's right end plus a regenerated corner, then a
  deterministic vertical water-palette conform so glacial cyan grades into
  ocean teal instead of meeting it at a line.
- **SE beach cut-off**: corner regenerated (candidate #3; the other three
  pulled land across the top edge and were passed over).
- **South luminance line**: broken by an irregular canopy-spill edit
  spanning the seam.
- Two 1px generation borders (WMP03's corner_sw, this round's corner_nw and
  south_w letterboxing) were found by an edge scan and stripped — the
  dotted seam lines they caused are gone.

## §3 The western corridor (brief item 3)

The west strip is regenerated with varied peak silhouettes (the wallpaper
repetition is gone) and a broad mountain pass. A winding dirt caravan road
now runs continuously from the interior bank road at Whispering Woods,
across a log bridge, through a cut in the master's forest (an edit-in-place
patch — the master file itself stays byte-preserved), up the pass meadow,
and on into the second ring's western valley, where it fades toward the
frontier past a standing stone. It is scenery that promises travel: no new
hit target, no travel-graph change, no location moved (G-3 — a destination
there is the World Designer's/owner's to name).

Canon note: `GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md` §8 sketched
the west as the Meadowrun estuary and the east as the Dust Reach; the
shipped, twice-device-accepted atlas has the Worldspine west and ocean
east. This round follows the shipped geography per the owner's explicit
brief; the ecology doc now carries an amendment note rather than a silent
contradiction.

## §4 The world, doubled again (brief item 4)

The base grows 768 → **1024** (world 4608 → **6144** px at scale 6, ~1.78×
the area). The 512² master is still byte-preserved, now at (256, 256),
inside two rings. The second ring is twelve pieces referencing the
corrected inner ring's actual edges: polar snowfield and frozen sea north,
open ocean and a thin islet chain east, plains-to-coast and warm sea south,
and the western valley. Deliberately empty-but-authored space everywhere —
no landmark stuffing.

Two recorded production lessons: (a) generation cannot hold a flat ocean's
exact palette (four rolls drifted; evidence kept) — flat water is now a
deterministic assembly of the approved east strip's own ocean (A-2
crop+assembly), with generation reserved for content; (b) the companion
`waterconform` tool (mean/std match, snapped to the target's own palette —
invents no colors) fixed every remaining water/snow tint step for zero
generations.

The whole-world survey: at 1024 native the zoom floor's fit rule means the
entire world may no longer frame on one phone screen at once. This is the
intended "less everything-fits-on-one-board" feel, and it is on the device
checklist as an explicit owner call.

## §5 The dragon (brief item 2)

The WMP03 data flew the sprite tail-first: head drawn west, `travel: {x: 30}`
east. Fixed in data — travel negated, origin shifted so the same sky
corridor is crossed head-first westward. The fire breath landed on the
first roll (1 generation): jaws open, a small flame puffs west from the
mouth, fades. The journey is now flight ×2 + breath — 28 frames,
`playLoops: 1` — so the breath happens exactly once per crossing, ~11 s,
still at a 40 s quiet interval.

## §6 Eggs (brief item 5)

- **Corridor collision found by sweep, not on device**: the fire egg's box
  sat exactly on the new road — its always-visible frame 0 would have
  painted pre-corridor forest over it. The burn scar is re-authored in the
  south-west forest (also answering the visual review's copse-size flag).
- **New**: a westbound **caravan** (20×19 wagon + oxen) travels the pass
  road every ~52 s; a **stag** steps from the treeline beside the road
  every ~34 s (bear-pattern entrance/exit, pinned to the empty painting); a
  **flock** of marsh birds lifts from the reeds every ~23 s (first attempt
  turned the pools transparent — rejected, on the record; the `no_background`
  retry is the shipped one).
- Yeti, bear, nessie, whale, ship, volcano, rustles and ripples are
  untouched and re-swept at the new coordinates; the volcano overlay was
  verified pixel-aligned on its cone after the sweep. All intervals remain
  mutually distinct, so nothing phase-locks.
- The placement sweep (tools/placement_sweep.js) runs every overlay box at
  origin and travel endpoint against hit circles, glyphs and route points:
  the new overlays are clean (one 10 px feathered-edge graze recorded);
  Marshlight's label moved NW clear of the flock's box.

## §7 Labels (brief item 6)

Outer Shoal removed (four names in one SE column). The Worldspine moved off
the pass onto its ridge. Three restrained names on a ~78 % larger world:
Wayfarer's Pass, The White Reach, The Far Isles — net 21 → 23 landmarks,
label density down per area. All future-tier names remain art-stream
proposals under Q-07.

## §8 What did not change

Playable-location coordinates (all five shifted +768 with the master —
their painted ground is identical), travel graph and costs, step
accounting, health sync, saves, economy, audio. Ambient timers remain
presentation-only while the World screen is shown. Layout schema stays
**v5** — no new fields were needed. The World screen's code is untouched:
every camera/zoom value derives from the layout.

## §9 Verification

- App suite **658**: all pass (two atlas literal tests updated
  deliberately: world 6144, landmarks 23/21; the marker-glyph count 26→28).
- `flutter analyze` clean.
- Guard set clean (step-model's production-scan false positive remains the
  separate pre-existing task recorded at Playable Polish 02).
- `package-art.js --check` clean from tracked sources: **792 files** (the
  1024 composition, 63 → 82 overlay frames; overlay_fire2 retired under the
  orphan sweep).
- Goldens: only `phase1_world.png` / `phase1_world_large.png` changed;
  regenerated and visually reviewed (framing unchanged — the opening
  viewport is master interior).
- Placement sweep as §6.

## §10 PixelLab accounting

Balance **1,416 → 815** (601 generations, verified by `get_balance` before
and after; resets 2026-09-16). The spend: 4 inner-ring pieces (120), 7
corrective edits (~140), 12+5 ring-2 rolls (~330), eggs and probes (~11).
Rejects and their evidence files are in the art round's §F. The transport
helper (`tools/plab.js`) is committed this time — WMP03's uncommitted-helper
gap is closed.

## §11 Deferred

- Ring-2 ocean depth banding east of the inner strip's gradient (subtle;
  judge on device).
- The whole-world-survey zoom-floor owner call (§4).
- PWRF01's standing next-pass items (drainage network, projection ruling)
  remain deferred on the record.
- No `phaseMillis` cadence field: period-picking still suffices (v6 idea
  recorded by the architecture review, deliberately not taken).

## §12 iPhone acceptance checklist

1. Full-map sweep N/S/E/W: does it read as one authored continent?
2. Every join: inner ring (glacier top, east ocean, NE corner, SE shallows,
   south forest line) and all outer-ring seams at survey and mid zoom.
3. Western corridor: road continuous from Whispering Woods to the far
   valley; west feels open, wilderness intact.
4. Dragon: unquestionably head-first; breath from the mouth, once per
   crossing; rare and calm.
5. Volcano: bubbling/burst unchanged, aligned, not a sticker.
6. Fire (new SW location): reads as a quiet burn scar, not a forest-fire
   event; does not cover the road.
7. Yeti / bear / nessie / whale / ship: unchanged, integrated at new scale.
8. New eggs: caravan on the road (slow, westbound), stag at the treeline,
   flock over the marsh — quiet, unlabeled, no tap.
9. Label pass: SE column decluttered; Wayfarer's Pass / White Reach / Far
   Isles read faint; no overlap at common zooms.
10. Pan/zoom performance on the 1024 base; default centering on the current
    place; whole-world survey framing — owner call on the new floor feel.
11. Reduce Motion: no egg appears; map stays still.
12. Regression spot-check: travel costs unchanged, sync/banked steps
    unchanged, audio unchanged, save survives relaunch.
