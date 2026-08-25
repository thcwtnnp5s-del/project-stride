# World Map Polish 03 — the world doubles, and the eggs learn to belong

**Date:** 2026-08-25 · **Branch:** `playable-phase-2-multiregion` ·
**Start HEAD:** `5b0395d` (World Map Polish 01 part 2, state v2.20)
**Status:** implementation complete, awaiting the owner's physical-device pass.

Art round and full PixelLab provenance:
`GAME_BIBLE/ART/exploration/WORLD_MAP_POLISH_03/README.md`.

## What this pass is

The owner's device review of the part-2 ambient-life layer ruled the
*direction* right and the *execution* wrong: the fire read as a black-circle
sticker, the bear head was mascot-sized, the yeti floated, the water dragon
read as a slug. The same brief asked for the world to feel about twice as
big. This pass answers both: every flagged egg is reworked, a flying dragon
and three more eggs are added, and the atlas grows a frontier ring in all
four directions. Presentation-only throughout: no labels with panels, no hit
targets, no gameplay, no audio, no state.

## 1. The world is 2.25× bigger, without repainting anything

The accepted 512 × 512 master painting sits **byte-preserved** at the centre
of a new composed 768 × 768 base (`world/atlas_base`, world 4608 × 4608 px at
scale 6). Around it, eight PixelLab Pro pieces — each style-referenced
against a 64 × 64 crop of the master's own adjacent edge:

- **West** — the Worldspine: a snow-capped mountain wall running the full
  height of the frontier, forest lapping its foothills, tapering out in the
  south-west corner.
- **North** — the glacier breaks into a frozen polar sea of pack ice; the
  volcano's rock drops into cold navy water with steaming cinder skerries.
- **East** — open ocean deepening offshore, small pine islets.
- **South** — the forest thins to southern grassland, the delta opens into
  an estuary bay and a pale-sand coast.

**Why composition is not M-12's stacked screenshots:** those were separately
generated full paintings butt-joined with no treatment. Here every ring
piece inherits palette/outline/detail/shading from the exact edge it
touches, the joins get a deterministic dither crossfade (pixels swap across
the seam with distance-falling probability — no invented colours, A-2), and
the packaging step records the whole transformation. The forest joins read
as invisible; the water joins read as offshore texture at max zoom.

The five playable places, their routes, and every prior overlay shift by
+768 world px and are otherwise untouched. The zoom stops are unchanged
(they are native-art facts); the survey view now pans across a continent it
cannot contain, which is the "vast world" feel the brief asked for.

**Five new frontier landmarks** (future tier — quieter caption, suffixed, no
hit target): The Worldspine (west), The Frozen Shelf (north), Cinder
Skerries (north-east), Wanderer's Isles (east), Sunward Strand (south).
Nothing fake is tappable; they are the same honest landmark mechanism as the
existing fourteen.

## 2. Layout schema v5 — journeys, and long plays

Two optional overlay fields, both refused below v5 (the same
dropped-behaviour rule as v4's `intervalMillis`):

- **`travel: {x, y}`** — world px/sec the sprite moves *during one play*,
  measured from the end of the quiet gap, reset by the next one, never
  wrapped. Requires `intervalMillis` (a continuous loop has no play start)
  and excludes `drift` (one sprite, one kind of motion). This is what "the
  serpent swims a little way west, then dives" is made of.
- **`playLoops`** — how many times a play runs through the frame loop before
  the gap returns. `frameIndexAt`'s modulo already wraps frames, so the
  change is one multiplication in `activeMillis`. This is what lets the sky
  dragon undulate a 10-frame loop across a 12-second crossing without
  duplicate frame files.

## 3. The reworked eggs

The integration failure shared by all four flagged eggs was *pastedness* —
transparent sprites sitting on the painting. The fix is method, not just
art: the fire, yeti and bear are now **edits of the painting itself**
(`edit_image` on a 64 × 64 crop, animated, composited back through a fixed
content box whose outer rings feather to the source — the box also kills the
animation's terrain wobble). Only the box region ships; everything outside
it is the painting, by construction.

| Egg | Was | Now |
|---|---|---|
| **Fire** | A circular black hollow with pasted flames | An irregular scorched scar eaten into the west-fork canopy: charred standing trunks, embers, two small flames, a drifting smoke wisp. Continuous 2 s flicker at world (954, 2106) |
| **Yeti** | A floating still with a rod | Seated on the tarn ice at a real dark ice-hole, line in the water, small cast shadow; the rod survives all 8 frames of a gentle bob-and-dip loop. Continuous, world (2172, 1176) |
| **Bear** | A 28-px teddy face with pink ears | A ~12-px brown head that rises out of a canopy gap, looks left and right, blinks, and ducks away, the leaves closing over it (exit frames pinned to the untouched canopy; the entrance is the exit reversed). Every ~20 s, world (1272, 2784) |
| **Water dragon** | A green donut worm | A loch serpent: small head on an arched neck, two humps at the waterline, white ripples. Rises from a splash, swims ~72 px west (v5 travel), dives back to the same splash — 17 frames, ~7 s, every ~26 s, in the eastern sea NW of Saltreach Light |

## 4. The new eggs

- **Sky dragon** (the owner's ask): a long, slim jade dragon with small
  wings, undulating across the north-western forest — 12 s of slow wavy
  flight (10 frames × 3 `playLoops`, travel +30/−5), then gone for ~40 s.
  64 × 31 native: a sighting, not a set piece.
- **Whale**: a dorsal roll, spout and wake rings far out in the new eastern
  water, ~3 s every ~30 s.
- **Sail**: a 15 × 20 sloop crossing the southern sea on a 14-second
  one-frame play carried entirely by travel, every ~45 s.
- **Rejected on its merits:** an aurora shimmer over the glacier — the
  animation reshaped the ice instead of adding light, the same failure
  family as the five-times-failed water shimmer; not re-attempted.

Placement review: a programmatic sweep of every new overlay's box — at its
origin *and* its travel endpoint — against every location hit circle,
landmark glyph/label zone and rumor spot. One collision found (the yeti
scene's top rows grazed Frostmere's hit circle) and fixed by trimming two
blank-ice rows from the emitted box, since an in-place scene cannot move.

## 5. Retirements

`overlay_forest_fire`, `overlay_yeti`, `overlay_water_dragon` and
`overlay_bear_peek` are no longer emitted or shipped; their sources stay in
`WORLD_MAP_POLISH_01/out/env/` as evidence. `world/atlas_master.png` no
longer ships as its own asset — the painting lives inside `atlas_base`
(the packaging step still size-checks the source it composes from).

## 6. Verification

- `flutter analyze` — clean.
- App suite — **658** (655 + 3: v5 travel/playLoops gating both directions,
  the travel-needs-interval and travel-excludes-drift refusals, and the
  journey/loop cadence contract), all green. `stride_core` untouched.
- `package-art.js --check` — clean (**740** files; the composed base, 63 new
  overlay frames, all reproducible from tracked sources on a clean
  checkout); the orphan sweep enforces the retirements.
- CI guard set (core purity, UI boundary, dependency policy, backup
  exclusions) — clean.
- Goldens — **unchanged by design and verified so**: the world goldens
  centre on the current location, whose surrounding pixels are identical
  inside the composed base; every new egg is either outside the golden
  viewport or intermittent (invisible at the harness's frozen clock).
- Every reworked and new egg reviewed in composited context at map scale
  (sheets in the round's working set); seams reviewed at ×4.

## 7. PixelLab accounting

Balance 1,815 → **1,416** — 399 generations: the eight-piece ring plus three
strip/corner re-rolls (~320, Pro at 20–40 per call), four `edit_image`
scenes (~80), nine pixen candidates and nine animations (1 each), with
rejects itemised in the round README. One transport finding on the record:
long inline base64 corrupted in transit repeatedly, so image-carrying calls
went through a direct JSON-RPC helper reading bytes from disk (same MCP
endpoint and token).

## 8. Deliberately not done

- No repaint or move of the five playable places — spreading them apart
  means repainting the accepted master, which map-scale tooling still
  cannot do (the recorded MCP inpaint ceiling); the felt scale comes from
  the frontier ring. Restated, not dropped.
- No new travelable locations: the frontier is honest scenery until the
  World Designer / owner names a destination (G-3).
- No egg audio (owner ruling: generation closed); no lore or labels for any
  egg.
- Drainage/projection/delta-bar items from the part-1 record: still
  deferred, unchanged.

## 9. Device acceptance checklist (World screen)

1. Open the World tab: it opens centred on your location, readable, and
   pans much farther in every direction than before — mountains west, pack
   ice north, open ocean east, coast and plains south.
2. Pinch out: the survey shows a continent that keeps going; the five
   places no longer feel like the whole world. Pan to each edge and confirm
   the frontier looks painted, not pasted — especially along the old
   borders (forest→mountains west, glacier→pack ice north, sea→sea east,
   farmland→coast south).
3. Confirm the five new quiet names (The Worldspine, The Frozen Shelf,
   Cinder Skerries, Wanderer's Isles, Sunward Strand) read as far-off
   geography and are not tappable.
4. **Fire** (west river fork): an irregular burnt scar with charred trunks,
   embers, two small flames and a smoke wisp — no black circle, no sticker.
5. **Yeti** (the frozen tarn, near Frostmere): sitting *on* the ice at a
   dark fishing hole, rod gently dipping. It should look like it lives
   there.
6. **Bear** (southern forest edge): within ~20 s a small bear head rises
   from a gap in the canopy, looks around, blinks, ducks away and the
   leaves close. Small, subtle, cute.
7. **Loch serpent** (eastern sea, NW of Saltreach Light): within ~30 s it
   rises from a splash of rings, swims visibly westward with neck arched
   and humps showing, and dives. Clearly a creature surfacing — no slug.
8. **Sky dragon** (over the north-western forest): within ~45 s a long thin
   dragon crosses the sky in slow waves for ~12 s and is gone. Rare, cool,
   not dominating.
9. **Whale** (far eastern water) and the **sail** (southern sea): occasional,
   distant, believable.
10. Confirm the map still feels calm — nothing everywhere at once — and no
    egg covers a place name, marker, route or tap target, at any zoom.
11. Tap each of the five places: selection, route preview and the journey
    panel behave exactly as before.
12. Toggle iOS Reduce Motion: all motion stops (the intermittent eggs
    vanish entirely); off brings it back.
