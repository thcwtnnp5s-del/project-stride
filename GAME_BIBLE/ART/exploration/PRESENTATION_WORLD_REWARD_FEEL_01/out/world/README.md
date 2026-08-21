# PWRF01 — the continent master

## atlas_master_688x384.png — ACCEPTED

The world atlas base painting. Replaces the portrait
`ACTIVITY_FEEL_01/out/world/atlas_master_384x688.png`, which stays in its
round directory as evidence.

**Format:** 688 × 384 native, drawn at atlas scale 4 → **2752 × 1536 world
px** (the previous master was 1536 × 2752 — the axes are swapped, which is
the owner's §32 ask made literal: the world is now wide, and the survey
floor leaves it pannable east/west).

## Provenance (PixelLab, 2026-08-21)

| Step | Job | Method | Outcome |
|---|---|---|---|
| Base | `8d566521` | `create_image_pro`, 688 × 384, `style_image_url` = the shipped AF01 master (copying **outline, detail, shading**; palette deliberately free, so §35's regional vibrancy is not clamped to the old muted family) | Generated whole — **one painting, no joins** (M-12) |
| Fix 1 | `3f5a1140` | `inpaint_image`, mask 50 × 32 at the foothills | **Stonefall reads as a worked mine** — timber adit, spoil heap, cart track. Was a shadow; this was the round's BLOCKER |
| Fix 2 | `ff46a6e0` | `inpaint_image`, mask 52 × 40 beside the hamlet | **Whispering Woods exists** — pale airy broadleaf woodland, distinct from the dark western forest |
| Fix 3 | `0ce45280` | `inpaint_image`, mask 120 × 98 over the coast | **Town shrunk and hamlet merged** — the walled port is now a distant dot; the split hut clusters read as one Haven's Rest |
| Fix 4 | `e1e164bb` | `inpaint_image`, mask 96 × 100 over the delta | **Marsh de-speckled** — broad legible tidal channels replace confetti |
| Fix 5 | `7574591c` | `inpaint_image`, mask 124 × 116 over the marsh/sea border | **Seam repaired** — fix 4's paste left a flat-water rectangle against the textured sea; regenerated wider to carry the wave texture through |

**Total: 1 base generation + 5 inpaints.**

## QA

Two blind rounds, M-13 staging (neutral scratchpad path, `painting_a` /
`painting_b` / `candidate2`, the shipped master included unlabelled as a
control, first-impression questions answered before any intent was revealed).

**Round 1 — FAIL.** The reviewer, blind, called the raw candidate *"a
storybook nation you could cross in a screen"* and independently judged the
**shipped portrait master** as feeling *bigger* — the exact inverse of the
brief's headline. Five findings gated ship: mine unreadable (BLOCKER), light
forest missing, hamlet split, town oversized (the dominant scale cue), marsh
speckle.

**Round 2 — PASS.** A fresh reviewer, blind, enumerated all five playable
features unprompted, called the constructed rock feature *"a mine entrance"*,
described the world as *"a multi-day-journey region — large"*, and found *"no
rectangular patch, no straight seam, no banding"*. Seam verdicts: mine CLEAN,
town/coast CLEAN, marsh/sea CLEAN, light-woods VISIBLE-BUT-ACCEPTABLE.

**Notes carried on record (non-blocking):**
- The Stonefall adit reads "mine or mountain outpost" — unique enough with
  its runtime label, not unique from pixels alone.
- Ambiguous lighter marks in the western forest: `landmark.old_watch` is
  placed on them, which converts the ambiguity into a labelled question.
- The meadow band around Haven's Rest is one step brighter than the other
  grass tones — detectable as a treated region, reads as a biome.
- Lava saturation in the north-east is the loudest thing on the map.

## Geography, against the brief's §33

WEST ancient forest with a ruin · CENTRE the playable cluster (hamlet, light
woods, mine foothills, blighted hollow) · NORTH alpine glacier and frozen
lake · FAR NORTH-EAST volcanic rock with lava fissures · EAST coast, river
mouth, walled port, islands, marsh · SOUTH farmland, grasslands, river basin.
The playable cluster occupies roughly the upper-right sixth of the canvas.

**Packaging:** `Scripts/art/package-art.js` § PWRF01 →
`assets/art/v1/world/atlas_master.png`. Layout, markers, routes, rumors and
the thirteen ambient overlays: `assets/content/v1/atlas/atlas_layout.json`.
