# EPO03 — WORLD_WEST ledger (PROD-WORLD-WEST, territory 0–320 × 300–700)

Cap: **200 generations**. Region ids WA/WB/WC, salts 80–99. One row per job:
the tool's own cost line, never a balance delta (M-17). Family total = the sum
of the cost column. Verdicts are desk verdicts at 197×426 phone FOV ×2; the
physical iPhone remains the authority.

| job/id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| 7fb79946-a866-484d-a52a-1700e4f04c77 | inpaint_image | 160x280 (WA, mask 80x194 @40,40, seed 801, crop @83c9132) | 25 | ACCEPT | WA roll 1 — the vertical canopy wall at x~256 is gone: the edge bays in around atlas y 370-450, a promontory pushes west at y 460-520, stepping copses walk the meadow west. Firs above, oaks below, one hand. changed-outside-mask 2962 (blocked by the mask, not shipped); dup sprite pairs 0; orphan flecks 369, all in the frozen snowfield/fir stipple north of the rect. `--check` green, 1971 files. Evidence: review/atlas/WA_r1_x2.png, WA_preview_fov_x2.png, WA_after_x2.png |
| b86789dc-662a-43ab-8d49-3f418603b88e | inpaint_image | 344x252 (WB, mask 260x172 @0,40, seed 811, crop @c615db5) | 40 | REJECT | WB roll 1 — three faults. (a) The road was **re-drawn**, not kept: measured entry at the west edge moved from y=602 to y=534 and the whole loop flattened to a near-ruler line at y~533-542; the caravan corridor and all four goldens would be re-cut for no gain, and a straight road across the FOV is worse than the S-bend it replaced. (b) Dialect: the ranges are tall, densely hatched alpine ridges, a different hand from the atlas's flat three-value facets, and far too tall for the scale. (c) The rock mass runs flat into the mask rect's top and bottom edges and is cut horizontally there. Intent changed, not the seed: a custom inpaint mask (`src/atlas/WB_inpaint_mask.png`, road + 7 px frozen black, 37,323 white of 44,720) makes the road un-redrawable, and the prompt asks for low flat-faceted knolls in the peak's own style with pasture held at the top and bottom edges. Sheet: review/atlas/WB_r1_x2.png |
