# World Atlas Coherence UI 01 — art round

**Goal.** Make the existing 1024² atlas read as **one authored painting** on a
physical iPhone, and make the World tab **map-first**. No new canvas, no ring 3,
no new regions, no new easter eggs (`PROJECT_STATE` device brief).

The prior passes (WMP01/03, WMER02) narrowed every generation seam to a dithered
band and still shipped rectangles to the device, because a straight dither band
at the layout's ×6 display scale reads as a pasted tile (`MISTAKES.md` M-14).
This round replaces seam **blending** with seam **authoring**.

## Method — cross-boundary transition authoring

For each visible seam a wide crop of the **shipped** composite (real terrain from
both sides of the join) was cut, and the central strip repainted with
`inpaint_image` while the crop's outer margins were **frozen** (the mask never
reaches them), so the returned band re-seats onto the composite with no new edge
and the terrain is carried *through* the boundary. Bridges are blitted in
`Scripts/art/package-art.js` after the dither, over the seams, in authoring order
(later wins where they overlap). The open ocean's several teal dialects are then
conformed to one accepted swatch deterministically (`ocean_unify.js`, A-2 palette
remap — invents nothing).

Transport for every image-carrying call is
`../WORLD_MAP_EXPANSION_REFINEMENT_02/tools/plab.js` (inline MCP base64 corrupts
payloads). Crops via `../WORLD_MAP_EXPANSION_REFINEMENT_02/tools/cropurl.js` and
`Scripts/art/png.js`.

### Tools (this round)
- `tools/compose_review.js` — mirrors the shipping composition for review
  (base → 12 bridges → ocean conform). `node compose_review.js <base.png> <out>`.
- `tools/ocean_unify.js` — the deterministic open-ocean conform. The authoritative
  copy is `require`d by `package-art.js`; also runnable standalone.
- `tools/seam_review.js` — the preflight safeguard: emits one iPhone-scale crop
  per generation boundary plus a `contact_sheet.png`. Run before any World device
  pass; no cell may show a straight generated rectangle (`RULES.md` A-3).
- `tools/args_*.json` — the verbatim `inpaint_image` prompt + mask for each bridge.

### Bridges (12 `inpaint_image` calls) — name, blit (x,y,w×h), seam addressed
| bridge | blit @ (x,y) | size | seam(s) authored |
|---|---|---|---|
| east_x768 | 640,256 | 256×512 | east volcanic-coast noise column (x=768) |
| north_center | 256,0 | 512×288 | ice wall (x=512) + north comb (y=128) |
| north_west | 0,0 | 288×288 | NW ice/mountain corner (x=128, y=128) |
| north_east | 768,0 | 256×288 | NE ice/skerries (y=128, x=896) |
| north_master | 256,224 | 512×80 | ice → alpine master-top (y=256) |
| nw_corner | 80,80 | 220×220 | NW frozen-margin rectangle |
| north_junction | 256,188 | 512×84 | north_center ↔ north_master merge |
| north_mtop | 300,232 | 420×96 | master-top snow-basin line (center) |
| west_mid | 48,256 | 256×512 | Worldspine (x=128) + master-west (x=256) |
| sw | 0,592 | 272×304 | SW block + y=640 butt join |
| south | 256,720 | 512×128 | delta comb (y=768) + coast |
| se | 704,704 | 192×192 | SE beach cut-off + corner |

Ocean conform rects and target swatch are recorded in `ocean_unify.js`.

## PixelLab spend
Bridges are `inpaint_image` (~28 gen each). Start balance **815**, end **480** →
**335 generations** used, within the owner's ~400 ceiling for this pass. The
ocean conform is deterministic (0 generations). No rerolls were needed — every
bridge was accepted on its first candidate. Resets 2026-09-16.

## Acceptance (device checklist for the owner)
Run `node tools/seam_review.js` and view `out/review/seams/contact_sheet.png` at
phone scale, then on the phone confirm: no cell shows a straight generated
rectangle; no coastline changes drawing style across a boundary; water colour/
detail does not jump; forest/mountain/snow density changes by geography, not by
panel; the map reads as one painting; the map dominates ~2/3 of the World tab and
the translucent panel ~1/3, readable with the atlas visible behind it; pan/zoom/
taps feel natural.

## Deliberately not done
No canvas growth, no ring 3, no new regions, no new easter eggs, no label
removals (label-density judgement deferred to the device view — see the milestone).
One tiny cosmetic whitecap fleck remains near the south coast; it reads as spray,
not a seam.
