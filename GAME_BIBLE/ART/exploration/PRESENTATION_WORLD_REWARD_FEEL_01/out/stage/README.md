# PWRF01 — work stages

The focused profession compositions the owner's second device review asked
for (§3–§5): a tighter place per profession, and an interchangeable resource
object per node, standing on the Traveler's own ground line where his tool
lands.

## Shipped

| Ship path | Source | Size |
|---|---|---|
| `work/bg_mining.png` | `work_mining_b_0` | 384 × 176 |
| `work/bg_woodcutting.png` | `work_woodcutting_0` | 384 × 176 |
| `work/bg_foraging.png` | `work_foraging_0` | 384 × 176 |
| `work/prop_copper_seam.png` | `prop_copper_b_0` | 96² |
| `work/prop_tin_seam.png` | `prop_tin_b_0` | 96² |
| `work/prop_hardened_copper_seam.png` | `prop_hardened_b_0` | 96² |
| `work/prop_oak_stand.png` | `prop_wood_a_2` | 96² |
| `work/prop_meadow_patch.png` | `prop_forage_a_0` | 96² |
| `work/prop_duskcap_grove.png` | `prop_duskcap_0` | 96² |

Frostpine, Rimefrost Hollow and Hollow Thicket have **no work prop**. They
fall back to their existing node vignettes, still placed at the interaction
point rather than far-left — worse than a purpose-drawn work face, and far
better than where they were. A gap, on record, not an oversight.

## Generations (2026-08-21/22) — 13 total

**Backdrops** (`create_image_pro`, 384 × 176, style-matched to a node plate)

| # | Job | Outcome |
|---|---|---|
| 1 | `c8cab9ad` mine wall | **REJECTED.** Wall from the top edge to the bottom edge, no wall/floor junction anywhere. Blind QA: *"no ground plane, no cast shadows"* — and a 0.72 multiply shadow on near-black floor is invisible, so the figure could not be grounded at all |
| 2 | `c818412f` forest | **ACCEPTED** |
| 3 | `6114b7b2` scrub | **ACCEPTED** |
| 4 | `e33b13af` mine working, floor-first prompt | **ACCEPTED.** Pale floor across the lower two thirds, pit props standing on it and meeting a beam. The contact shadow now registers |

**Props** (`create_image_pro` for a family base, then `inpaint_image` for the
variants — §31 prefers editing to regenerating, and it is also what makes the
three ores one outcrop with different metal in it rather than three rocks)

| # | Job | Outcome |
|---|---|---|
| 5 | `69ec0456` mining base, ×4 | **ACCEPTED** (candidate 0). Flat exposed face, rubble at the base |
| 6 | `16484095` woodcutting base, ×4 | **ACCEPTED** (candidate 2). Candidate 1 shipped first and was **withdrawn** — see below |
| 7 | `564c19c5` foraging base, ×4 | **ACCEPTED** (candidate 0). Candidate 1 shipped first and was **withdrawn** — see below |
| 8 | `3a438fb8` tin, inpaint | **REJECTED.** Blind QA: reads as *cracks*, not a resource — *"a rock that has been hit a few times"*, first label "stone" |
| 9 | `900fd141` hardened, inpaint | **REJECTED — BLOCKER.** Blind QA's candidate readings, in order: *"barnacles, eggs, fungus, bread rolls"*. Rounded convex lumps are the visual grammar of organisms |
| 10 | `455853e1` duskcap, inpaint | **ACCEPTED** |
| 11 | `8711bacf` frostpine, inpaint | **REJECTED.** Lost the axe notch and read as an ice column / frozen waterfall, not a frosted pine |
| 12 | `be1e9a5e` tin retry, inpaint | **ACCEPTED.** Angular blocky silver facets; blind QA's first word "quartz", which is a mineral rather than damage |
| 13 | `e76c24fb` hardened retry, inpaint | **ACCEPTED.** Radiating dark-red angular shards; blind QA's first word "crystal", second "garnet" |
| 14 | `b34eb2c2` copper retry, inpaint | **ACCEPTED — BLOCKER fix.** The original's glowing orange fissures were read as *"lava / a hot rock"*, a **state** rather than a material. Solid opaque copper bands, no glow |

Nine accepted of fourteen. Every rejection came from blind review, and three
of them were of plates the author had already shipped.

## QA — two blind rounds, and what each one actually found

M-13 staging (neutral scratchpad paths, non-ordinal two-letter plate names,
first-impression questions before any reveal), ×2 review view (M-05),
in-context composites rather than isolated sprites.

### Round 1 — FAIL

Found the two placement defects that no widget test could see, and the
reviewer was right about both:

- **The axe was invisible.** The trunk was painted *after* the figure, and it
  is tall enough to swallow the swing. Verbatim: *"a man pointing at a
  tree"*. Fixed by `StageScenery.behindFigure` — a prop the tool disappears
  into is not a prop the tool is hitting.
- **A hard-edged grass rectangle** under the trunk with the Traveler's boot
  straddling its right edge. The woodcut candidate the author picked carried
  its own opaque grass slab, which reads as a tile seam against a forest
  floor. Fixed by shipping candidate 2, which carries only tufts.

It also reported three defects that were **the harness lying, not the art** —
recorded here because the lesson is the harness's, not the reviewer's:

1. *"Corrupt scanlines in the sky"* — the harness **clamped** the 384 px
   backdrop across the 393 px stage. `PixelScene` centre-clips and never
   stretches.
2. *"No ground plane"* — the harness omitted `LocationStage`'s ground-band
   gradient.
3. *"No cast shadow on any character"* — the harness omitted the multiply
   contact shadow entirely.

A review harness that under-draws the product turns a reviewer into a bug
report about the harness. All three are now reproduced in the harness.

### Round 2 — FAIL, and it found the biggest one

With an honest harness, the reviewer found the defect that mattered most:

- **The mining loop works EAST.** The Traveler faces east, raises the pick
  over his left shoulder and brings it down to his right, and his chips fly
  right. Every prop was being placed west, so the ore sat behind the miner's
  back and his debris hit bare floor. Verbatim: *"holding a pickaxe near a
  boulder, not in contact"*. Fixed by `AmbientAssets.worksEast`, a table
  rather than a measurement — the union of a swinging tool's frame bounds is
  symmetric, so the extents cannot answer this and only looking can.
- **The forager's face was covered** by the herb prop's blossoms; the figure
  read as *"a bear rooting in a bush"*. Fixed by shipping the low foraging
  candidate (opaque top row 37 rather than 16), which clears the head.
- The copper, tin and hardened misreads above.

## Notes on record, not fixed in this round

- The foraging backdrop's upper quarter is a flat khaki field; it reads as
  receding haze in motion and as empty canvas in a still.
- The oak stump's cut face is drawn near-frontally and disagrees slightly
  with the ground plane the log establishes.
- Three ore props share one boulder silhouette by design, and the swap
  boundary is visible as a soft seam on close inspection.
- No native-resolution or ×8 pass was run in either round: the reviewer has
  read-only tools and was given the ×2 view alone. Tangency and stray-pixel
  inspection is **uninspected, not cleared**.

**Packaging:** `Scripts/art/package-art.js` § WORK STAGES.
**Wiring:** `AmbientAssets._workBackdrops`, `_workProps`, `worksEast`.
**Placement:** `AmbientStageLayout.propRect`, `StageScenery.behindFigure`.
