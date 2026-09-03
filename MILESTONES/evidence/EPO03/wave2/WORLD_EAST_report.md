# EPO03 — PROD-WORLD-EAST report

Team `east`, territory 600–1024 × 0–700 (DIR-01). Cap 140, **spent 135**.
Three regions accepted (E1, E2, E3), three rolls rejected with written reasons.
Ledger `GAME_BIBLE/ART/exploration/EPO03/ledger/WORLD_EAST.md`; manifest
`GAME_BIBLE/ART/exploration/EPO03/out/atlas/manifest_east.json`.

## The defect I was sent at

The producer's read ranked this the worst thing left on the map: the shelf met
open water along a hard, near-straight white diagonal, and the pack ice
north-east of it was a regular honeycomb that repeated at a glance. Both halves
are addressed. The ice-to-volcano join is not.

## E1 — the calving front (atlas 750–880 × 40–250), ACCEPTED

**BEFORE.** A flat white sheet meeting flat teal along a near-straight edge from
(866,0) to (790,250): no shelf face, no shadow, no bergs, no brash.

**Roll 1 (25 gens, seed 1001, job `a3a708e0…`) REJECT.** Asked for a calving
shelf across a 260×210 rect; the tool drew one enormous smooth glacier tongue —
airbrushed gradients, an outlined rim, a straight mask edge showing at the
lower left, and the honeycomb replaced by slab. `rejected/atlas_E1_r1.txt`.

**Roll 2 (25 gens, seed 1002, job `260773ad…`) REJECT.** Narrowed to a
750–880 strip and led the prompt with broken floes; it drew a *new* honeycomb —
near-uniform pebble floes in a net of navy leads darker than the master's teal —
and left the straight edge alone. `review/atlas/E1_r2_x2.png`.

**Two rolls, two generator patterns, so the intent changed, not the seed.**
Following the west team's roll-2 lesson (a custom mask freezing what has to
stay), I extended `tools/atlas-maskcut.js` with a **ribbon cut**: ice further
than `cut.landMargin` px from the *open-sea component* — not from the interior
leads, which as sources cut 0 px, measured — is forced to 0. The authorization
becomes a ~50 px band straddling the ice margin and the pack interior is frozen,
so the tool has no room to invent a field.

**Roll 3 (25 gens, seed 1003, job `05f28ed5…`) ACCEPT.** A lobed margin with
bays and blunt headlands, a shadow along the ice foot, calved bergs at several
distinct sizes and brash thinning seaward into clear water. Two deterministic
recoveries at zero cost before accepting (PRODUCTION_RULES §2a):
`atlas-quantise.js` remapped a violet shelf shadow onto the neighbouring ice
palette (13 entries), and a new `tools/atlas-fleck.js` filled 185 one-pixel
islands. Evidence `review/atlas/E1_after_x2.png`, `E1_preview_fov_x2.png`,
`EAST_fov_780_150.png`, `E1_after_front_x1.png`.

## E2 — the ice-to-volcano join (atlas 600–760 × 228–320), ACCEPTED WITHOUT A GENERATION

**Roll 1 (20 gens, seed 1004, job `e52ddd83…`) REJECT.** The mask reached onto
the cone, so the tool rebuilt the cone: black rock grew north into the
snowfield, a new summit crater and pool appeared, **the Emberhold tower was
painted out entirely**, and look-alike boulders were scattered on the drifts.

Intent changed: added `cut.freezeDark` to `atlas-maskcut.js`. Every source pixel
below CIE L\* 42, dilated, is forced to 0. On this crop rock and both towers sit
at L\* < 30 and everything else at L\* > 50, so the whole silhouette is frozen
byte-exact and only the snow side is authorable — "author around them, do not
repaint them" made mechanical rather than hoped for.

**Roll 2 (20 gens, seed 1005, job `370c32bc…`) REJECT.** freezeDark held (cone
and both towers byte-exact), but given a narrow snow band beside a hard black
silhouette the tool invented an **object**: a brown antler/driftwood shape lying
on the drift with three look-alike pebble clusters beside it, and the smear it
was sent to remove survived. In the composite it read worse than the butt joint.
`rejected/atlas_E2_r2.png`, `rejected/atlas_E2_r2.txt`.

**Shipped (0 generations).** E2 ships as a deterministic region. The dithered
seam smear at atlas 630–755 × 234–286 is a low-contrast 50/50 dither cloud that
the one-pixel-island predicate misses (138 px on a 7,250 px rect), so
`atlas-fleck.js --dither` snaps a local-minority pixel to the modal colour of
its 5×5 neighbourhood: 874 px snapped, 109 islands filled. Every replacement
colour is an existing neighbouring pixel; nothing is averaged (A-2). The snow
west of the cape reads as flat cel again, and the silhouette and both towers are
byte-exact. `review/atlas/E2_defleck_x3.png`, `E2_after_x2.png`.

## E3 — the honeycomb (atlas 640–760 × 60–180), ACCEPTED

**Roll 1 (20 gens, seed 1006, job `5512cd2a…`) ACCEPT.** Deliberately small
(120×120 authored) because E1 rolls 1–2 proved a wide ice mask is answered with
a pattern. The ask was one broad sheet of old fast ice carrying long wind-drift
bands, with a few long cracks that never meet and enclose nothing. The cell net
in the middle of the pack became one broad banded floe with irregular
non-meeting cracks. Palette-remapped and de-stippled deterministically (0 gens);
the stipple ring the ramp left around the new floe came out cleanly.
Evidence `review/atlas/E3_after_x2.png`, `E3_preview_fov_x2.png`,
`E3_defleck_cmp_x2.png`.

## Is the repetition measurably reduced?

**`atlas-qa`'s repeated-sprite metric reads 0 before and 0 after, on every
region.** It counts only *byte-identical* 10×10 pairs, and a drawn honeycomb
never is byte-identical — so it could not have detected this defect at all, and
using it as the triage the brief expected would have been misleading. I measured
near-duplicates instead: 10×10 blocks whose closest neighbour within 40 px has a
mean channel difference under 6.

| Rect (atlas) | BEFORE | AFTER |
|---|---:|---:|
| 620–800 × 20–220 (the honeycomb) | 34.8 % of textured blocks | **26.4 %** |
| 600–880 × 0–300 (the whole NE) | 37.6 % | **29.0 %** |

`atlas-qa` orphan flecks rose in the same window (710–920 × 0–300: 285 → 609).
That is the brash the direction asked for: "bergs and brash in the water" is
made of 1–3 px chips and the fleck predicate cannot tell brash from confetti. I
ran the deterministic island fill anyway (185 px on E1, 65 on E3) and judged the
remainder by eye at x1 — it reads as ice chips, not speck noise
(`review/atlas/E1_after_front_x1.png`).

## What the phone shows that it could not before

At FOV (780,150) the front is broken: no straight run of ≥12 px anywhere on the
ice/sea boundary, lobed bays and blunt headlands, calved bergs at several sizes,
brash thinning into clear water, and the pack behind it carrying a large banded
floe instead of a repeating cell grid. At FOV (680,290) the snow north of the
cone is clean flat cel — the dithered smear is gone. Both renders:
`review/atlas/EAST_fov_checks_x2.png`.

## Identity anchors — verified on the shipped composite

Emberhold (743,288), The White Reach (600,60) and the cone at (690,320): **0 px
changed** in a 29×29 box. Rimewatch (639,296): 6 px, all snow at the edge of the
sample box; the tower itself is untouched. Rimespire (824,156) was re-authored
as part of the front but still sits on ice (`#e1f5fc`; 169 of the 324 px in the
18×18 under it are ice). Every golden in the territory —
`volcano_east_cliff`, `east_watchtower_flank`, `cinder_skerries`, `far_isles`,
`ne_iceberg`, `wanderers_isles_w/e` — is byte-exact: **no region declared
`reauthorizes` and none was re-extracted**, and the landmark golden guard
passes. No acreage was added to the east sea; the mask stops at the ice and the
global ocean conform still owns the water.

## Guards

`node Scripts/art/package-art.js` and `--check` are green for everything this
team owns: protected-interior drift guard, landmark golden guard, EPO03 manifest
checks (ids, salts 100–102, sizes, undeclared golden touches), and
`check-tile-seam.js`. `--check` reports ~20 stale files, **all** under
`assets/art/v1/item/` — PROD-EQUIPMENT's live work in the shared tree, not mine.
No world asset is stale. Every build was taken under `atlas-lock.js`.

## What did not close

1. **The authored ice-to-volcano join.** DIR-01's criterion for FOV (680,290) is
   "rock meets ice through ash snow and steam". There is still no ash tongue, no
   melt pool and no steam — ice and black rock butt. Two rolls failed on it with
   a consistent tell: given a mask on the cone the tool rebuilds the cone; given
   a narrow snow band beside the silhouette it invents an object. E2 shipped only
   the deterministic smear removal. **This wants a REPLACE SECTION with a larger,
   squarer crop that gives the tool a whole shoulder rather than a band, and a
   budget of its own.**
2. **The honeycomb west of x=640** is untouched — the 600–640 strip I held as
   E3's frozen margin, and everything beyond into PROD-WORLD-NORTH's territory.
   E3 broke the middle of the pack, not all of it.
3. **Speckle at the cape**, atlas 740–760 × 240–265, sits inside the
   `volcano_east_cliff` golden keepout; I could not reach it without
   re-authoring a golden the brief told me to hold.
4. **Orphan flecks are up** in the front window (285 → 609). Judged acceptable
   as brash. If QA-SEAMS disagrees, the fix is a stronger `atlas-fleck --dither`
   pass over the sea side and costs nothing.
5. **5 generations of the cap are unspent** — too few to buy another roll.

## Tools added (team-owned, `GAME_BIBLE/ART/exploration/EPO03/tools/`)

- `atlas-maskcut.js`: `cut.landMargin` (the ribbon cut, anchored on the open-sea
  connected component) and `cut.freezeDark` (freeze every pixel below an L\*
  threshold). Both **narrow** a mask and never widen one (G-4).
- `atlas-fleck.js` (new): one-pixel-island fill, plus `--dither`, a modal snap
  for low-contrast dither clouds. Deterministic, existing neighbouring colours
  only, nothing averaged (A-2).

No REQUESTS filed, no Q- raised. No save, health, economy, item, recipe, node or
system change; `assets/content/v1/atlas/atlas_layout.json` untouched.
