# EPO03 — PROD-WORLD-WEST report

Team `west` · territory atlas 0–320 × 300–700 · region ids WA/WB/WC/WD · salts
80–99 · cap **200 generations**. Branch `fable5-executive-production-overhaul-03`.
Ledger `GAME_BIBLE/ART/exploration/EPO03/ledger/WORLD_WEST.md` (one row per job,
the tool's own cost line, never a balance delta — M-17). Every verdict below is
a desk verdict read at 197×426 phone FOV ×2 on the **shipped composite**; the
physical iPhone remains the authority.

This team was resumed. A previous instance published the WA crop and submitted
the WA job before the session limit killed it; the job id in the ledger was
enough to recover the generation with `get_image` rather than spend the cap
twice (PRODUCTION_RULES §9a). Every crop after that was re-cut from the current
`assets/art/v1/world/atlas_base.png`, which by then carried SOUTH's S1/S2/S3/SA1
and LANDMARKS' L1/L2/L3.

---

## WA — core forest west face, upper (atlas 216–296 × 300–494)

**BEFORE.** DIR-01 verdict 2, ranked the second-worst transition on the phone:
the canopy stopped on a vertical wall at x≈256, one pan west of Haven's Rest,
inside the A-4 core and its rim — the thing FMPO02 could not write.
`review/atlas/WA_before_x2.png`.

**Intent.** `coreAuthor: true` under D0033, so the mask writes through the rim
and into the core. Break the wall westward into bays, promontories and stepping
copses that meet the western meadow; firs above, oaks below; the wood east of
x=296 left unbroken for the fairy glade.

**Job.** `7fb79946-a866-484d-a52a-1700e4f04c77`, `inpaint_image`, 160×280 crop,
mask 80×194 at (40,40), seed 801, **cost 25**.

**Verdict: ACCEPT.** The vertical wall is gone. The edge bays in around y 370–450,
a promontory pushes west at y 460–520, and stepping copses walk the meadow out
to the west. One hand throughout; the fir/oak change reads as altitude, not as a
patch. `changed-outside-mask` 2,962 (blocked by the graded mask, cannot ship);
repeated sprite pairs 0; orphan flecks 369, all in the frozen snowfield and fir
stipple north of the rect. `--check` green.
Evidence: `review/atlas/WA_r1_x2.png`, `WA_preview_fov_x2.png`, `WA_after_x2.png`.

---

## WB — pass road and the far-west wall (atlas 0–260 × 460–632)

**BEFORE.** DIR-01 verdict "West road loop": the caravan road S-bends across an
empty meadow for no geographic reason, the far west is bare ground with a
handful of outcrops, and a snow-capped peak sits pasted on flat grass at
(210,590) with no range behind it. `review/atlas/WB_before_x2.png`.

**Roll 1 — REJECT** (`b86789dc-662a-43ab-8d49-3f418603b88e`, 344×252, box mask
260×172 at (0,40), seed 811, **cost 40**). Three faults:

1. **The road was re-drawn, not kept.** Measured on the roll: the west-edge entry
   moved from y=602 to y=534 and the whole loop flattened to a near-ruler line
   at y≈533–542. All four goldens and the caravan overlay corridor would have
   been re-cut for nothing, and a straight road across the FOV is worse than the
   S-bend it replaced.
2. **Dialect.** Tall, densely hatched alpine ridges — a different hand from the
   atlas's flat three-value facets, and far too tall for the scale.
3. The rock mass ran flat into the mask rect's top and bottom edges and was cut
   horizontally there.

Sheet: `review/atlas/WB_r1_x2.png`.

**Intent changed, not the seed** (ATLAS_PRODUCTION_RULES §3). A **custom inpaint
mask** — `src/atlas/WB_inpaint_mask.png`, the road dilated by 7 px painted black,
37,323 white of 44,720 — makes the road literally un-redrawable, and the prompt
was rewritten to ask for low flat-faceted knolls in the existing peak's own
style with pasture held at every edge.

**Roll 2 — ACCEPT** (`16afb5a9-2445-442d-b439-22d7bb808590`, custom mask, seed
812, **cost 40**). The road came back **byte-identical** to the crop at every
sample (x=0 → y 599–605, x=100 → 538–544, x=199 → 507–548, x=258 → 513–520), so
`caravan_corridor`, `west_caravan_road`, `stag_box` and `roadjoin_corridor_west`
still have road under them and the overlay caravan route is unmoved. Every bend
now turns around a rock outcrop, a spur or a stream crossing. A beck leaves a
stony ford on the road and runs south. Scree fans and boulder trains thicken
westward to the range.

The isolated peak at (210,590) is **gone rather than integrated** — replaced by
outcrops that belong to the foothills. That satisfies "landmarks sitting on
terrain" and "no grey slab" but is not literally what DIR-01 asked; it is named
here rather than hidden.

**Goldens (D0033 §5).** All four declared in `reauthorizes` and re-extracted in
the ACCEPT commit under the build lock — the terrain *beside* the road changed
(1,853 px drift on `roadjoin_corridor_west`), so the guard threw as designed.
**No registry rect was edited**: the feature did not move, so the rects still
follow it, and none was emptied.

`changed-outside-mask` 2,968 (blocked); repeated sprite pairs 0; orphan flecks
529, overwhelmingly the scree stipple the region is made of. `--check` green.
Evidence: `review/atlas/WB_r2_x2.png`, `WB_preview_fov_x2.png`, `WB_after_x2.png`.

---

## WC — the y=700 bridge with SOUTH, and the dead downs (atlas 0–232 × 600–740)

**BEFORE.** Two defects meeting. Above the join, atlas 20–200 × 620–720 was a
pale dead slab — dominant colour `#9dab70` at 9.2 % coverage with almost no
marks on it. Below it, SOUTH's S3 (authored rect 0–256 × 700–1024) stopped with
its wood on a near-horizontal north edge at y≈720. And WB's new beck **ended
dead** in open grass at (193,620). `review/atlas/WC_crop_x2.png`.

**Intent.** A **bridge region** in the ATLAS_PRODUCTION_RULES §3 sense — one rect
holding both sides of the join, 60 px above y=700 and 40 px below, with 40 px
frozen beyond each side. S3 was not re-touched; no landed region was reopened.

**Job.** `fa915cad-05b2-495e-956e-d5e751c27836`, 288×220 crop, mask 232×140 at
(0,40), seed 821, **cost 25**.

**Verdict: ACCEPT.** The wood breaks north into the downland as bays,
promontories and outlying copses — no line can be drawn where it ends, and the
y=700 join is invisible at FOV. The downland carries gorse, heather, bracken,
tussock and boulder trains reaching out of the crag on the left. The beck runs
on from the ford through the heath and into the wood: one continuous watercourse.
`changed-outside-mask` 2,005 (blocked); repeated sprite pairs 0; orphan flecks
333. `--check` green.
Evidence: `review/atlas/WC_r1_x2.png`, `WC_preview_fov_x2.png`, `WC_after_x2.png`.

---

## WD — core forest west face, lower (atlas 236–296 × 490–620)

**BEFORE.** WA fixed the face from y 300–494; the residual below it was measured
on the shipped composite rather than guessed. Across y 490–600 the canopy edge
held x = 238–271 — a 33 px wander over 110 px of height, which is a
quasi-vertical wall — and a **dither column** of scattered dark pixels ran down
atlas x ≈ 264–270 from y 540 to 640. The acceptance bar names both by name.
`review/atlas/WD_crop_x2.png`.

**Intent.** `coreAuthor: true` (the rect reaches 236–296, through the A-4 rim
into the core, D0033). Break the border into bays, promontories, grassy inlets
biting east and stepping copses standing clear in the meadow; clear the speckle
column; keep the wood dense east of x=296 so Deepwood Shrine (304,556) and
Whispering Woods keep deep wood. The road crossing the rect is frozen by a
second custom inpaint mask, `src/atlas/WD_inpaint_mask.png` (6,623 white of
7,800), reusing what WB proved.

**Job.** `a7f0ad35-8f77-46b7-b85e-7b29c587254a`, 144×210 crop, custom mask, seed
831, **cost 20**.

**Verdict: ACCEPT.** The edge across y 490–620 now wanders x = **212–280, a
spread of 68 px** against 33 before, with a promontory, an inlet biting east, a
lone oak and three copses out in the open grass. The speckle column is gone. The
road is byte-identical again (x=199 → y 507–548, x=290 → y 516–518).
`roadjoin_corridor_west` drifted 941 px, so it, `west_caravan_road` and
`caravan_corridor` were re-extracted under the lock in the same commit; no
registry rect edited, none emptied. `changed-outside-mask` 1,382 (blocked);
repeated sprite pairs 0; orphan flecks 214. `--check` green, 2,203 files.
Evidence: `review/atlas/WD_r1_x2.png`, `WD_preview_fov_x2.png`, `WD_after_x2.png`,
and the whole-face FOV `review/atlas/WEST_face_fov_x2.png`.

---

## Cost

| region | job | cost line | verdict |
|---|---|---|---|
| WA | 7fb79946 | 25 | ACCEPT |
| WB r1 | b86789dc | 40 | REJECT |
| WB r2 | 16afb5a9 | 40 | ACCEPT |
| WC | fa915cad | 25 | ACCEPT |
| WD | a7f0ad35 | 20 | ACCEPT |

**Territory total: 150 of the 200 cap** (sum of the tools own cost lines).
Four regions accepted (WA, WB, WC, WD), one roll rejected with a written reason
and a sheet. 50 generations left unspent.

---

## What the phone will show

One pan west of Haven's Rest, the wood no longer ends on a ruled line: it bays
in and out, sends promontories into the meadow and drops lone oaks and copses
sixty to eighty pixels clear of the canopy. The caravan road still runs exactly
where the overlay expects it, but now every bend turns around a rock outcrop or
a ford; a beck leaves that ford and can be followed unbroken south through
heath and gorse into the southern wood. The far west is foothill country —
scree, boulder trains, crags, a snow dusting — instead of a bare green field
with one pasted peak on it. Where the map used to change from empty pale
downland to solid forest on a horizontal line at the south seam, it now fingers.

## The fairy glade handoff

**Already taken.** LANDMARKS landed L1 at atlas 256–464 × 352–544 while WA was
in the build, and it is committed and accepted in `manifest_landmarks.json`.
`landmarks/L1` blits *after* `west/WA` and `west/WB`, so the glade wins in the
overlap — which is the intended outcome. WA's mask stopped at x=296 exactly so
that unbroken woodland was there for the glade to be inpainted into, and WD
keeps the wood dense east of x=296 for the same reason. Nothing further is owed
to LANDMARKS from this team.

## The y=700 seam

**Closed for the west half by WC.** The bridge rect holds atlas 0–232 × 600–740,
which spans the join with 60 px of WEST above it and 40 px of SOUTH's S3 below,
both authored in one generation and both frozen ≥40 px beyond. The wood fingers
north across the old line and the beck crosses it. The seam east of x=232 (the
core marsh side, 320–768) was never WEST's and is not touched here.

## What did not close, named

- **The peak at (210,590) was removed rather than joined to the range.** DIR-01
  asked for it to join the foothills; the accepted roll replaced it with
  outcrops. Defensible, and named here for the owner rather than buried.
- **`--check` reports the atlas green, but this team never ran a Flutter
  device render.** WEST shipped only atlas pixels; the world map screen is
  rendered from `atlas_base.png`, which `package-art.js --check` verifies at
  2,203 files. Judgement above is desk judgement at phone FOV ×2 on the shipped
  composite, not an iPhone verdict.
- **50 of the 200 generations were left unspent.** No further defect in the
  territory measured badly enough to justify a roll; a roll spent on a
  transition that already reads is a worse outcome than an unspent cap.
