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

---

## Correction round (2026-08-22): the continent doubles, and both attempts are on record

The owner's device verdict on the shipped continent: a major improvement over
the old narrow map, and "still feels like a REGION rather than a much larger
WORLD". §17 asked for roughly **2× the navigable footprint**, especially
north and south, and §23 required a dedicated topology/continuity review of
the **whole assembled image** — explicitly not of attractive crops.

### Attempt 1 — three bands joined (REJECTED)

Two more PixelLab Pro paintings, one arctic and one southern lowland, cropped
and butted above and below the shipped master to make 688 × 864 (world
2752 × 3456). The joins were softened with a deterministic wobbling boundary
after an ordered dither was tried first and looked worse — a chequered stripe
is a texture no painter drew (M-12).

**Blind Visual QA: FAIL, four BLOCKERs.** The reviewer read straight through
the wobble and located both joins to within three rows of where they are:

> "Two ruler-straight full-width joins at y≈253 and y≈610 partition this into
> three bands that disagree on scale, projection, rendering technique and
> biome … a viewer will not read one country, they will read three
> screenshots stacked."

The worst of it was structural, not cosmetic: at the southern join the
**eastern sea became forested land in one row** — the coastline stepped ~100
px seaward — and neither the river system nor the lava crossed either join.

**The lesson is about the method, not the execution.** Three independently
generated paintings do not agree about scale, projection, lighting or
drainage, and no seam treatment reconciles that, because the disagreement is
not at the seam. Do not assemble a continent from bands.

Evidence kept: `band_north_0.png`, `band_south_0.png`, `join_bands.js`,
`atlas_master_688x864.png`.

### Attempt 2 — one painting of the whole larger world (SHIPPED)

One `create_image_pro` generation, 512 × 512, prompted for the entire
continent at one scale with one river system running glacier → valley →
delta → sea, one coastline, and every region §16 says to preserve. At
**scale 6** that is **3072 × 3072 world px** — 2.25× the shipped footprint,
north/south doubled, east/west slightly wider — and it is still ONE painting
by one hand, so there is no join to fail a blind read.

### The topology review, run on both paintings with the same questions

This is the §23 gate, and it was run twice so the result is a measurement
rather than an opinion.

| | Shipped incumbent (688 × 384) | Replacement (512 × 512) |
|---|---|---|
| Verdict | **FAIL** | **FAIL** |
| Blockers | **1** | **0** |
| Footprint | 2752 × 1536 | 3072 × 3072 (2.25×) |

**The incumbent's blocker is real and is on the owner's phone today:** a hard
rectangular compositing box left in open water — right edge a dead-straight
vertical at x≈616 from y≈192 to y≈287, bottom edge horizontal at y≈287 —
paler flat water inside, the wave motif absent. It is residue from one of the
five inpaints of the first pass, and the reviewer's read was *"the texture
didn't load"* or *"there's a selection box in the image"*. Nobody caught it
because the first round was asked whether the five locations were findable,
not whether the water was continuous.

The replacement carries **no blocker**: "Nothing on this plate causes a
viewer to misname an object outright."

**Both fail on the same class of note**, which is the honest finding — these
are properties of the generator and the family, not of either painting:

- drainage is sparse (a whole forested upland sheds no water; one range sheds
  one river) and one river has no source;
- large areas of forest are a stamped single-motif fill;
- three or four projections and light directions coexist (oblique mountains,
  near-plan fields, elevation lighthouse and mine adit);
- biome joins are hard — ice against broadleaf canopy with no tundra between.

The replacement adds a repeated lens-shaped bar motif in the delta; the
incumbent adds mismatched settlement styles 90 px apart and islands with no
shallows halo.

### The call, and why

**Ship the replacement.** It is 2.25× the footprint the owner asked to grow,
it removes a blocker that is in the product now, and it fails only on notes
it shares with the asset it replaces. Shipping it is a strict improvement on
every axis measured.

**It does not pass the §23 gate, and this record says so.** The world item is
delivered as *materially better and still not clean*. What the next pass
needs, in order:

1. **Drainage.** Author the river network deliberately — tributaries off the
   range, a real source for the western river, downstream widening — and
   inpaint it in, rather than asking a generator for "one river system".
2. **The stamped forest.** The west quarter is texture. It wants clearings,
   density variation and a couple of authored features.
3. **A projection ruling.** Decide whether structures are icons or terrain
   and hold every one of them to it. This is a direction call, not a QA one.
4. **The delta bars.** Break the repeated lens.

None of these needs a bigger world. They need localized editing of this one,
which is the workflow `PIXELLAB_MAPS_EVALUATION.md` already adopted — with
the caveat below.

### A hard constraint discovered this round

**Map-scale inpainting cannot be driven through the MCP surface.** The
transport ceiling for an inline base64 argument measures at roughly **5.5 KB**
— a 96 × 96 sprite fits, and any crop of a painted map does not. A 344 × 96
strip of this atlas is 12–25 KB encoded and is truncated in transit. The
`_url` variants of those parameters need a URL, and there is no host.

So the five corrective inpaints of the first pass were only possible because
they were small; the coastline repair this round needed was not. Until there
is somewhere to host an image, **corrections at map scale must come from the
web Map Workshop or from a paint pass outside this pipeline.** That is the
real blocker on atlas quality, and it is a tooling blocker rather than an
art one.
