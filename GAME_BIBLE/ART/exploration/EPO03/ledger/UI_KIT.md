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
| **Spent so far** | **32** | **32** |
| Remaining under cap | | **288** |

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
| 0edd4777 | `leather_recesses` sheet | 128² | 1 | *pending* | a leather sheet of plain stamped recesses; the nav well and the slot wells are cut from it |
| e77988f0 | `leather_pads` sheet | 128² | 1 | *pending* | a leather sheet of plain raised pads; the active nav plate is cut from it |
