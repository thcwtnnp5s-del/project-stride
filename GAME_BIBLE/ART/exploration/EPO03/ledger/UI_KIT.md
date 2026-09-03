# EPO03 — UI_KIT family generation ledger (PROD-UI-NAV)

Cap **320** (kit ≈260, nav ≈60). Family total is the **sum of the tool's own
cost lines** below, never a balance delta (M-17) — several teams hold this
account at once.

`create_image_pixen` is 1 per roll. `pro` and `inpaint` are refused for chrome
by the brief and were never called. A canvas rejected by the tool's own
validator (short side under 32) queues no job and costs nothing; those are
recorded as `—` so the re-issue is not mistaken for a re-roll.

## Running total

| | Rolls | Cost |
|---|---:|---:|
| Batch 1 — lost to job expiry | 16 | **16** |
| Batch 2 — the kit's first real pass | 14 | **14** |
| Batch 3 — sheets to cut from | 2 | **2** |
| Batch 4 — the welt, deterministic post-work | 0 | **0** |
| Batch 5 — `create_image_pro`, three frames | 3 calls / 36 candidates | **60** |
| Batch 6 — the four brightness rejects, remapped | 0 | **0** |
| Batch 7 — pro wave 2 (ribbon, sealed page, button, inset stage) + 6 pixen strips | 4 calls + 6 | **86** |
| Batch 8 — pro wave 3 (ornate rule, sealed retry, nav well, nav plate) | 4 calls | **80** |
| **Spent** | | **258** |
| Remaining under cap | | **62** |

**Shipped: eight assets.** The first thirty-two rolls produced one, and the
conclusion drawn from them — "the frame class is closed" — **was wrong, and the
producer was right to send it back.** Two corrections, both cheap:

1. **Brightness is a remap, not a rejection.** Four candidates were marked
   CHECK for being over the ceiling while the drawing itself was right.
   Deterministic post-work resolved all four for **zero generations** (batch 6).
   The repo already knew how — `ceiling-clamp.js` is VAWO01's `chassis_64`
   operation, and keying a ground is `package-art.js`'s `keyBorderWhite`.
2. **The tool was never changed.** All thirty-two rolls were `create_image_pixen`.
   `create_image_pro` takes labelled reference images; given an accepted grain
   tile as the style and `chassis_64` as the construction, it drew flat,
   axis-aligned, hollow, stud-free nine-patches **in the first call for all
   three families** (batch 5). What thirty-two pixen rolls could not do, three
   pro calls did.

The honest reading of batch 2–3 is therefore narrower than it was written:
**pixen** cannot draw a flat hollow frame. That is still true and still
recorded. It was not evidence about the frame class.

---

## Batch 1 — sixteen rolls generated, then lost (cost paid, no verdict)

Sixteen `create_image_pixen` rolls were submitted and completed; the session
was cut off before they were downloaded, and PixelLab keeps a job for **8
hours**. Every one returned `job … not found` on resume. **The generations
were spent and the results are unrecoverable.**

This is a process defect, not an art verdict, and it is recorded as cost
because it is cost. The rule it teaches — already in GOV-04's "download every
kept candidate", now paid for — is **fetch to disk in the same turn the job
completes, before doing anything else.** Every later batch in this ledger does.

| jobs | tool | canvas | cost | verdict | reason |
|---|---|---|---:|---|---|
| ee666e33, dfda49c5, dbc395de, f2c3549d, dd8c5348, cf0a6de1, 5f2732c4, 37aa673a, 9b73f571, d1292ba9, 8f973482, 519fbd50, 86ff309e, 9ae19eae, 7815294c, aa20fb59 | pixen | 24²–384×72 | 16 | **LOST** | job results expired (8 h) during the session gap; never downloaded, never judged |

What the inline thumbnails showed before they expired is kept as **triage
only** — it steered batch 2's prompts and is not a verdict on any file: the two
128² frames came back ornate with corner studs, and one nav plate came back as
a pale round disc (the coin register the FMPO02 reject list names).

## Batch 2 — the first real pass, sheeted at ×3/×6 and read

Sheets: `review/ui/frames_x3.png`, `nav_small_x6.png`, `strips_x3.png`.

| job | asset | canvas | cost | verdict | reason |
|---|---|---|---:|---|---|
| b9092b86 | `inset_well_b` | 64² | 1 | **REJECT** | reads as a hole in glittering ice, not leather; the rim is near-white sparkle, far over the `#7C7263` ceiling |
| dbca05f5 | `slot_well_b` | 48² | 1 | **REJECT** | drawn in **perspective** — a box seen from an angle. Its four sides are foreshortened differently, so no nine-patch can be cut from it |
| 3aff912f | `inset_stage_b` | 128² | 1 | **REJECT** | pale tan planks well over the ceiling, and a **screw head at each corner** — the stud register P-D1 forbids by name |
| 4b804787 | `stage_frame_b` | 128² | 1 | **REJECT** | stone-block window with a **round bolt at each inner corner**; block joints fall at fixed points, so the edge runs cannot tile at an arbitrary length |
| 29ff6914 | `nav_well_b` | 32² | 1 | **REJECT** | the model drew an **object inside the well** — a small orange crab-like ornament. A well is empty by definition |
| 011f76f4 | `nav_plate_active_c` | 32² | 1 | **REJECT** | perspective again: a pillow seen at an angle, on a chainmail ground nobody asked for |
| 7478a6ba | `peek_plate_b` | 32² | 1 | **REJECT** | pale tan face over the ceiling, with a violet halo fringe around the silhouette |
| 6513ff7b | `ribbon_label_b` | 96×32 | 1 | **REJECT** | an empty outline — a wireframe rectangle with notched ends and almost no fill. No material to read |
| e7d2ffa4 | `rule_bench_b` | 96×32 | 1 | **REJECT** | drew a **plank**, an object, instead of a groove scored across a board |
| 6ce69c34 | `rule_journal_b` | 96×32 | 1 | **CHECK** | the ink line is right and dark, but it wobbles and the paper around it is cream, far over the ceiling. Usable only if a straight window wraps and the paper keys out — see batch 4 |
| a3bee939 | `rule_chart_b` | 96×32 | 1 | **CHECK** | a straight uniform sepia rule with tick marks; ticks unevenly spaced and the vellum is over the ceiling. Same test as above |
| d28d7cfa | `tab_plate_b` | 48×32 | 1 | **CHECK** | a genuine dark leather tab with a stitch border. All four corners rounded rather than the two asked for; measure before declaring geometry |
| 7a0c4880 | `nav_welt_v2_b` | 64×32 | 1 | **ACCEPT (master)** | dark leather with a clean even saddle-stitch row. The one unambiguous success of the pass. Ships as a **cut**, not whole: `tile-cut.js` takes the best-wrapping 8×6 window |
| 62529e80 | `rail_shelf_b` | 384×72 | 1 | **CHECK** | a plausible oak plank front with an iron lip; needs a ceiling read and a look at whether it repeats along its length |

**The pattern, named once so it is not paid for again.** Eleven of fourteen
failed the same way: asked for *flat, plain, tileable chrome*, the model draws
*a lit object in perspective, decorated, above the ceiling*. FMPO02 recorded
exactly this for `modal_128` (3 rolls), `strap_corner_64` (2), `corner_mark_48`
(2), `tab_index_32x16` (2) and `nav_plate_32` (1) and shipped none of them.
**That is a measured capability boundary, not a prompt problem**, and M-05
forbids re-rolling into it. Where the model *does* succeed is the material
strip and the material sheet — every FMPO02 surface, both chrome edges, and
this pass's welt.

So the family changes method rather than repeating: **author a large flat
sheet, cut the small piece out of it deterministically** (`tile-cut.js`, the
window search that turned a 64×16 welt strip into the shipped 8×4 tile). Batch
3 is that.

## Batch 3 — sheets to cut from

| job | asset | canvas | cost | verdict | reason |
|---|---|---|---:|---|---|
| 0edd4777 | `sheet_recesses_a` | 128² | 1 | **REJECT** | the recesses are drawn as a bandolier **on the diagonal**; no axis-aligned window contains one, so nothing can be cut. Stitching also runs near-cream, over the ceiling |
| e77988f0 | `sheet_pads_a` | 128² | 1 | **REJECT** | the pads are rotated a few degrees off axis for the same reason, and their lit rims sit over the ceiling |

Sheet: `review/ui/sheets_x4.png`. **Four strategies, one answer.** Asked
directly the model draws an object; asked for a sheet to cut from, it draws the
sheet at an angle. `GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN` §3.5's window
search cannot rescue a rotated source — rotating pixel art is not a
deterministic post-step and A-2 forbids inventing the pixels it would need.
**The frame and ornament classes are closed for this round** (`RULES.md` A-1's
escalation clause, `MISTAKES.md` M-05), and `KitFrames`/`KitMarks` ship
declared and empty with every consumer painting its fallback.

## Batch 4 — the welt, cut and clamped (0 generations)

Deterministic post-work on the batch-2 master, A-2 throughout:

| step | tool | result |
|---|---|---|
| band crop | `png.crop` rows 0–5 | the stitch row, away from the master's pure-white bottom row |
| ceiling clamp | `tools/ceiling-clamp.js` (**new**) | 1 colour / 8 px, `#A87353` → `#97674A`, linear-light rescale — the operation VAWO01 used on `chassis_64`, now written down |
| tile cut | `tools/tile-cut.js --w 8 --h 6` | window (12,0), join 15.219 vs interior 38.341 |
| proof | `tools/strip-proof.js` (**new**) | 25 repeats across 393 dp, read at ×4: `review/ui/welt_run2_x4.png` |
| package | `tools/kit-package.js` (**new**) | `out/ui/nav/nav_welt_v2.{png,json}` — teal 0, semi-alpha 0, over-ceiling 0, max `#815235` L=0.1096 |

**ACCEPT.** Reads as a continuous saddle stitch at phone scale with no visible
join. Shipped to `assets/ui/v1/nav/nav_welt_v2.png`; drawn by both the nav bar
and the header shelf.


## Batch 5 — `create_image_pro`, the frames

Three calls, 20 generations each, **60 total**. Each carried
`style_image_url` = an accepted grain tile (`grain_leather`, `grain_bench_oak`)
with `style_copy` = palette + shading + detail, plus two labelled
`reference_images`: the same grain ("the material this is cut from") and
`chassis_64` ("the flat straight-on square nine-patch construction to copy").
Cost is per call, so the small canvases returned 16 candidates each.

| job | family | canvas | candidates | cost | verdict |
|---|---|---|---:|---:|---|
| e2f51423 | `inset_well` | 64² | 16 | 20 | **ACCEPT** candidate 1 — band 15/15/15/15, spread 0, max L 0.0484. 9 of 16 usable, 3 blank, 3 asymmetric |
| e7fdfe47 | `slot_well` | 48² | 16 | 20 | **ACCEPT** candidate 6 — band 5/4/5/4, spread 1, max L 0.0791. 11 of 16 usable |
| 23986e06 | `stage_frame` | 128² | 4 | 20 | **ACCEPT** candidate 3 — band 19/19/19/19, spread 0, max L 0.0855. Candidates 0 and 1 rejected: **band 0**, i.e. the top run is transparent at mid-span — the `modal_128` geometry failure exactly |

Sheets: `review/ui/pro_insetwell_x4.png`, `pro_finalists_x3.png`. Every
candidate measured by `tools/frame-measure.js` (**new**) — which crops to
content first, because measuring a band from the canvas edge reads 0 on every
side when the frame sits inside a transparent margin.

**The corner is 26, not 19, and `tools/ninepatch-proof.js` (new) is why.** The
stage frame's band measures 19, but its iron corner cap is wider than its band.
Declaring corner 19 puts the cap inside the edge strip, and the painter then
tiles the cap along every beam — visible in `review/ui/np_stage19.png`, invisible
in the source PNG and in every numeric measurement. At corner 26 the cap draws
once per corner and the beams run unbroken (`np_stage26.png`). This is the
defect `PIXELLAB_UI_PRODUCTION_PLAN` §3.2.1 warns about, caught by rendering
the patch the way `_FramePainter` will rather than by trusting the numbers.

## Batch 6 — the four brightness rejects, resolved for zero generations

| asset | was | operation | result |
|---|---|---|---|
| `rule_journal` | 96.9 % over ceiling — an ink line on cream paper | `rule-cut.js --key 0.09`: paper keyed to alpha 0, 95 px of ink kept, rows 12–17, best-wrapping 8-wide window | 8 × 6 tile, transparent ground, max L 0.0699, **clean** |
| `rule_chart` | 95.4 % over ceiling — a sepia rule with ticks on vellum | `rule-cut.js --key 0.16 --band 0.02`, rows 14–17 so the ticks standing on the line survive | 8 × 4 tile, max L 0.0486, **clean** |
| `rail_shelf` | 23.8 % over ceiling | `ceiling-clamp.js` (4 colours), then cropped to rows 17–48 — the stone wall the model drew above and below the plank is not the shelf | 384 × 32 picture rail, max L 0.1710, **clean** |
| `tab_plate` | **already under the ceiling** (max L 0.1462) | none needed — the CHECK was about geometry, and the measurement settled it: band 19/1/28/1, wildly asymmetric, so it cannot carry one inset | ships as a **discrete ornament**, 48 × 32 at ×1 — the third thing `DECISIONS/0029` allows |

`rule-cut.js` learned one thing worth keeping: crop to the inked **band**, not
the inked **extent**. Two stray specks in the corners of the chart's sheet made
the extent the whole 32-row canvas, and a rule eight times taller than its own
line is not a rule.


## Batch 7 — the second pro wave, and six pixen strips (86)

| job / roll | family | cost | verdict |
|---|---|---:|---|
| a5f7d9f2 | `ribbon_label` | 20 | **ACCEPT as ornament** (candidate 2). Band 6/0/0/0 — the swallowtail notches are transparent at mid-height, so it is a **three**-patch and `PixelFrame` only draws nine. Ships fixed-width at 89 × 22 |
| 407e9549 | `btn_plate_v2` | 20 | **ACCEPT** (candidate 1). Came back with a **white face**, which measured as "solid plate, not a frame"; keying every pixel over L 0.5 to alpha 0 turned three rejects into three clean 5/5/5/5 frames. Corner **8**, not 5 — at 5 the rounded corner clips (`np_btn5.png`) |
| 0974a636 | `page_sealed` | 20 | **REJECT** — all four came back white despite a dark style reference. Retried in batch 8 by naming the value in the prompt |
| 9ad8fa2b | `inset_stage` | 20 | **REJECT** — all four solid, no hole. (A first attempt 404'd on a stale commit SHA and cost nothing; the reference must be pushed *before* the call) |
| 9901cfb5 | `edge_spine` | 1 | **ACCEPT** — binding cords at measured rows 1,7,13,20,26,32,38,45,51,57; the 7-row window at row 51 wraps best. Clamped, tiles cleanly (`p_spine_x3.png`) |
| 6335ee0c | `rule_bench` | 1 | **REJECT** — a pure-black 1 px hairline. `StrideColors.separator` already draws that, better |
| a75c7706 | `pocket_rule` | 1 | **REJECT** — tiles as a hard blue-grey checkerboard: plaid, and the wrong temperature for waxed canvas |
| 888538db | `case_strap` | 1 | **REJECT** — too dark to read; no legible material at phone scale |
| 08e5d885 | `edge_torn` | 1 | **REJECT** — a closed cream scrap, not a tileable edge |
| 665547a0 | `rail_strap` | 1 | **REJECT** — grey rubble noise with an over-ceiling highlight |

## Batch 8 — the third pro wave (80)

| job | family | cost | verdict |
|---|---|---:|---|
| d6ef7c80 | `rule_ornate_a` | 20 | **ACCEPT** — symmetric end flourishes, a centre diamond, dull tarnished brass, 192 × 16 exactly as declared, max L 0.0733. The illustrated section divider Skills, Character and Encounter all wanted |
| 1f04b00d | `page_sealed` | 20 | **ACCEPT** (candidate 0) — band 15/15/15/15, spread 0, dark deckled page edge. The retry worked because the prompt names the value ("dark brown and dim, never white, never cream") and references an accepted **kit** asset rather than a grain tile. Candidates 1–3 carry the torn lower edge the brief asked for and are rejected *for it*: a tear makes the bottom band 0 at mid-span |
| 2470cfe8 | `nav_well` | 20 | **REJECT** — 64 candidates, none usable; every one an open or paper-thin outline |
| a0ae5cc8 | `nav_plate_active` | 20 | **REJECT** — 64 candidates; the best are thin broken outlines with a gold fleck. **They lose to the Flutter-painted plate the producer accepted**, so the nav is not swapped. Spending 40 to learn that the incumbent is better is a real answer, not a waste |

**The nav stays painted.** That is now a measured verdict rather than a
fallback: pro was given the same brief that produced three good frames, with
64 candidates per call, and produced nothing that beats what ships.
