# FMPO02 — world atlas region production log (ART-03)

Round: FMPO02 Wave 2, PROD-WORLD-TERRAIN. Cap **450 generations**; balance at
start **9551**. Method, coordinates and acceptance bar: ART-03
(`MILESTONES/evidence/FMPO02/wave1/ART-03_atlas_brief.md`). Protection facts:
GOV-04 (`MILESTONES/evidence/FMPO02/wave0/GOV-04_atlas_guardian.md`).
Mandated loop: `WORLD_ATLAS_REMASTER_01/README.md` §10 — one region at a time,
BEFORE → intent → generate → composite → guards → full atlas + ×2 perimeter +
197×426 phone FOV → explicit verdict → only then the next.

The physical iPhone remains the final authority. Every verdict below is a desk
verdict, staging for the owner's device checklist.

---

## Standing finding: the A-4 rim cannot carry a content change

Discovered on W1 and applied to every region afterwards.

`package-art.js` protects the frozen core (256..768)² and hash-dithers its
20 px rim: `keepRepair(x,y,d) = d <= 20 && hash(x,y,5) >= d/21`. That dither
runs on **every** repair layer unconditionally — a region's own mask cannot
switch it off. So wherever a region writes the rim, the composite is roughly
half new pixels and half master pixels: measured on W1 roll 1, **1697
generation vs 1946 base pixels across atlas 256–276 × 276–460**.

Where the two are the same terrain that is invisible, which is what the rim is
for. Where a region deliberately changes the terrain there — W1 replacing the
canopy wall with a meadow bay — the 50/50 selection reads as exactly the
**speckled dither column** ART-03 §7.3 rejects and M-14 shipped four times.

The guard is not the thing to change (G-4). The region is. `atlas-mask.js`
grew a per-region `rimBlock` flag that forces mask alpha to 0 anywhere inside
the protected rect, and the authored rect is pulled back so its ramp reaches 0
at the core wall. **Consequence, on the record:** the part of D-01's forest
wall that lies inside the rim (atlas 256–276) is not fixable by this method.
Fixing it needs an owner decision about the core itself.

## Standing method note: the mask is graded by agreement

A dither ramp SELECTS whole pixels from two images (A-2 — nothing is ever
averaged). Where they agree, that reads as texture and the join disappears.
Where they disagree, a 50/50 selection reads as salt-and-pepper. So
`atlas-mask.js` measures local dissimilarity between the generation and the
crop over a 5×5 box and, above it, commits the ramp wholly to whichever side
it already favours. The commit contour is the jittered ramp contour, which
wanders ±10 px and is never straight: the join is drawn as a treeline instead
of sprayed as noise. Below the threshold the ramp dithers freely as before.

---

## W1 — West Verge (forest face + taper)

| | |
|---|---|
| Crop | `src/atlas/W1_crop.png`, origin (128,228), 196×298 |
| Inpaint mask | 100×184 at (48,48) in crop coords — frozen margins 48/48/48/66 |
| Job | `14236bc8-09a1-4584-8961-f6101c354284` · seed **701** · 25 generations |
| Authored rect (final) | atlas **176–256 × 276–460**, `rimBlock` on (right ramp anchored exactly on the core wall at x=256) |
| Ramps | left 20, right 28, top 32, bottom 24; width wander ±60%; salt 20 |
| Mask | 6,368 px authorized · 6,345 feathered · 25,908 blocked |
| Files | `out/atlas/W1.png`, `out/atlas/W1_mask.png` |
| Evidence | `review/atlas/W1_{before,after}_{full,x2,fov}.png`, `W1_after_edgeE.png` |

**Problem (BEFORE).** D-01: the canopy ends on a razor vertical against open
plain; the meadow west of it carries scattered dark conifer stamps that read
as confetti rather than woodland, and a dark smudge column sits on the join.

**Intent.** Canopy face breaks into bays, promontories, stepping-stone groves
and lone oaks; a beck runs out of the trees into the meadow.

**Containment.** `atlas-verify.js`: 18,322 px changed inside the mask, **0
outside**; changed bbox (48,48)..(147,231) — exactly the inpaint rectangle.

**Guards.** `package-art.js` and `--check` both green: protected-interior
drift 0, all 15 landmark goldens byte-held.

**Read.** The forest edge breaks into copses and lone trees stepping out onto
the meadow; the conifer confetti is gone, replaced by rounded oak groves in a
graded density ladder. At 197×426 phone FOV there is no rectangle, no straight
boundary, no dither column and no repair footprint; one drawing hand and one
detail scale across all four perimeters at ×4.

**Not achieved.** The beck the intent asked for landed in the A-4 rim
(atlas ~258–275) and is therefore not adopted; the rim keeps the master. The
inner half of the D-01 wall (256–276) is unchanged — see the standing finding
above.

**Verdict: ACCEPT** (desk).

---

## Standing method note: ramps are one-sided and anchored on the inpaint edge

Found on W2 roll 1, and it changed every region's geometry.

The first mask put a symmetric ramp on a hash-jittered midline. That cannot
work at a region boundary: the midline's wander can only move the visible join
further **inside** the generation, never outside it, because outside it there
is no new content to move into. So in every column where the wander pushed the
midline outward, the composite fell back to the inpaint's own hard cut — and
W2's snow/meadow join shipped as a **razor-straight horizontal line at atlas
y=258, about 175 px long**: M-14, exactly.

The fix: each ramp is now **one-sided**, anchored on the authored rect edge
(which is the inpaint rectangle's own edge) with alpha 0 there, rising inward;
the **width** carries the ±60% hash wander instead of the midline. The
half-alpha contour still wanders ±10 px, but it is now always strictly inside
authored terrain, so the inpaint cut can never be the thing you see.

---

## W2 — West Foothill Meadows

| | |
|---|---|
| Crop | `src/atlas/W2_crop.png`, origin (0,210), 228×338 |
| Inpaint mask | 172×212 at (8,48) — frozen margins 8 (canvas edge) / 48 / 48 / 78 |
| Job | `6bd327c0-4022-4e19-883e-8c4abad6c39b` · seed **702** · 25 generations |
| Authored rect | atlas **8–180 × 258–470** |
| Ramps | left 24, right 24, top 32, bottom 24; width wander ±60%; salt 21 |
| Mask | 23,957 px authorized · 8,643 feathered · 9,360 blocked |
| Files | `out/atlas/W2.png`, `out/atlas/W2_mask.png` |
| Evidence | `review/atlas/W2_{before,after}_{full,x2,fov}.png`, `W2_after_edgeE.png` |

**Problem (BEFORE).** D-18/D-24 and the dead zone: flat olive sward, confetti
boulders, two snow-capped cones pasted onto lowland grass, one road wandering
through nothing. No scale cue, no habitation, no reason to look.

**Intent.** Rolling foothill meadows terracing up to the Worldspine: hedged
pasture, bracken tussocks, copses of 3–7 trees, a beck with a stone ford,
sheep-crop paler on the ridges; the lowland snow-cones become rock knolls.

**Containment.** 36,311 px changed inside the mask, **0 outside**; changed
bbox (8,48)..(179,259) — exactly the inpaint rectangle.

**Guards.** `package-art.js` and `--check` green; core drift 0, 15 goldens held.

**Read.** Foothill pasture divided by hedge banks, a beck descending from the
snowline through a stone ford, copses and bracken clumps, rock knolls, paler
sheep-crop on the terraces. It reads as country that is grazed and lived in
rather than as a green field. The ×4 east join (atlas 148–212) shows one
drawing hand and one detail scale with no dither column and no straight edge.

**Not fully achieved.** The eastern pair of snow-cones kept their white caps;
they now sit at the foot of a larger brown massif, so they read as peaks above
a snowline rather than as cones pasted on grass, which was the defect. Left as
is.

**Carried forward (coordinator note, for N1).** The snow-to-meadow boundary
above the new fields (atlas y ≈ 240–262, x 0–200) is still a straight
horizontal line. It is pre-existing and sits in a gap no region authors: W2's
mask starts at y=258 and N1's ends at y=250. N1's mask is extended downward to
≈ y 272 so the snowfield frays into the meadow, and W2's FOV is re-rendered
after.

**Verdict: ACCEPT** (desk).

---

## W3 — West Downs (south)

| | |
|---|---|
| Crop | `src/atlas/W3_crop.png`, origin (0,556), 248×290 |
| Inpaint mask | 192×190 at (8,40) — frozen margins 8 (canvas edge) / 48 / 40 / 60 |
| Rolls | roll 1 `dd406075-6704-4a10-85a2-03859a636227` seed 703 — **REJECT**; roll 2 `bd3a4faf-4902-4786-9511-84a5ab3b3dda` seed **713** — accepted. 50 generations |
| Authored rect | atlas **8–200 × 596–786** |
| Ramps | left 24, right 24, top 24, bottom 32; width wander ±60%; salt 22 |
| Mask | 23,004 px authorized · 10,760 feathered · 13,300 blocked |
| Files | `out/atlas/W3.png`, `out/atlas/W3_mask.png`; rejected roll `rejected/atlas/W3_r1.png` |
| Evidence | `review/atlas/W3_{before,after}_{full,x2,fov}.png`, `W3_r1_x2.png` |

**Problem (BEFORE).** D-24 and dead acreage: boulder confetti on flat plain,
and three near-identical little snow-capped cones sitting at a latitude that
has no business having them — they read as copy-pasted stamps.

**Roll 1 — REJECT.** The generated area came back as a **paler rectangular
slab with four razor edges** — a tone shift no ramp can dissolve. Inside it:
a drystone sheepfold drawn as a literal rounded **rectangle** with sheep as
white dots, and "hollow-ways" rendered as wide brown tracks that read as
roads. Two of those three are things ART-03's own prompt spine forbids ("no
new buildings… no roads… no rectangles") while its region sentence asked for
them; the sentence lost. Recorded, not chased.

**Roll 2 — intent.** The same meadow stepping south into rough grazing:
bracken and gorse thickening downhill, low thorn scrub, boulders gathered into
outcrops rather than confetti, grading into the south-western woods along a
ragged edge; and an explicit instruction to hold the surrounding grass green
edge to edge with no lighter panel.

**Containment.** 36,427 px changed inside the mask, **0 outside**.

**Guards.** `package-art.js` green; core drift 0, 15 goldens held.

**Read.** Rough grazing land: gorse clumps, grouped boulder outcrops, scrub
thickening downhill into the south-western woods. The repeated snow-cones are
gone; one peak remains, and it has a massif under it. No tone panel, no
rectangle.

**Measured (`tools/atlas-qa.js`).** Repeated 10×10 sprite pairs within 40 px:
**0**. Orphan flecks 58.3 per 10k px — *below* the approved core hero region's
own 69.8 per 10k, so the flecks are drawing detail, not noise. No despeckle
applied. (W1 58.7, W2 43.7; controls: core hero 69.8, east archipelago 29.2,
Whispering Woods 26.2.)

**Verdict: ACCEPT** (desk).

---

## N1 — Snow Country West

| | |
|---|---|
| Crop | `src/atlas/N1_crop.png`, origin (0,0), 300×298 |
| Inpaint mask | 252×282 at (0,0) — top and left are the canvas edge; frozen margins right 48, bottom 16 |
| Job | `fbff25c6-13e8-499a-b176-1321e9c7e297` · seed **704** · 25 generations |
| Authored rect | atlas **0–252 × 0–272** |
| Ramps | left 0, top 0 (canvas edges), right 32, bottom 32; salt 23 |
| Mask | 56,153 px authorized · 6,331 feathered · 528 blocked |
| Files | `out/atlas/N1.png` (despeckled), `out/atlas/N1_mask.png`; raw `raw/atlas/N1_r1.png` |
| Evidence | `review/atlas/N1_{before,after}_{full,x2,fov}.png`, `GAP_snowline_{before,after}_x3.png` |

**Problem (BEFORE).** The largest incoherent surface on the map: one continuous
polygon crack-net across the whole northern band (D-22), reading as dried mud
or shattered safety glass rather than snow — no drifts, no wind, no relief, no
scale cue. Plus D-07's straight-edged remnant panel at (220–242, 120–180).

**Intent.** Wind-drifted snowfield: sastrugi combed NW→SE, drift shadows
behind ridges and rocks, cornices, blue-shadowed hollows, rock nunataks, a
frozen tarn, pale rime conifers thinning to singles on the south margin.

**Coordinator correction, executed.** The snow-to-meadow boundary at atlas
y ≈ 264, x 0–210 was a ruler-straight horizontal line sitting in a gap no
region authored (W2's mask starts at y=258; N1's original mask stopped at
y=250). N1's inpaint mask was extended to y=282 and its authored rect to
y=272, so the region paints **through** the old line and the bottom ramp still
lies wholly inside generated terrain. BEFORE/AFTER of that strip:
`review/atlas/GAP_snowline_{before,after}_x3.png` — the level edge is gone,
replaced by drifts, snow patches and rime conifers on an uneven margin.

**Debris removed.** The generation drew a **red dashed border** along its top
and left edges — 132 px, forbidden outright by the prompt spine. Removed by
`tools/despeckle.js red`, which replaces each debris pixel with its nearest
clean neighbour from a fixed offset list; nothing is invented, and nothing in
the northern snow country is legitimately red (the volcano is at x ≥ 580).
Same deterministic A-2 pattern as the NW-ice red-fleck pass already shipping
in `package-art.js`.

**Containment.** 52,050 px changed inside the mask. 4,515 px differ outside
the authored rect — that is the deliberate 10 px band of generated terrain
below y=272 that the bottom ramp needs to fade through; the mask blocks it, so
none of it ships.

**Guards.** `package-art.js` and `--check` green; core drift 0, 15 goldens held.

**Read.** Snow country: wind-combed drifts, dark rock nunataks, blue meltwater
tarns, rime-frosted conifers thinning north, and a southern margin that frays
into the foothill meadow. No cell pattern survives anywhere in the region.
Repeated 10×10 sprite pairs within 40 px: **0**. Flecks 46 per 10k px, below
the approved core's 70.

**East perimeter deferred.** N1's right edge (atlas ~240–252) currently abuts
the untouched honeycomb field, and the join between new snow and old crack-net
reads hard. N2 (atlas 240–520) supersedes that ground and the join is
re-judged after it lands — the two regions overlap by design across 240–252.

**Verdict: ACCEPT** (desk), east perimeter re-judged with N2.

---

## N2 — Frostmere Approach

| | |
|---|---|
| Crop | `src/atlas/N2_crop.png`, origin (196,0), 372×300 |
| Inpaint mask | 280×236 at (44,0) — top is the canvas edge; frozen margins left 44, right 48, bottom 64 |
| Rolls | roll 1 `4bea2aa9-25d2-4fd1-beb4-d2af69bfc385` seed 705 — **REJECT**; `reduce_colors` `80783de4-…` — **REJECT**; roll 2 `d416d1b9-8da5-481d-834e-0114f52ad63d` seed **715** — accepted. 80.1 generations |
| Authored rect | atlas **240–520 × 0–236** |
| Ramps | left 12 (paired with N1), right 8 (paired with N3), top 0 (canvas), bottom 32; salt 24 |
| Mask | 55,587 px authorized · 8,115 feathered · 14,528 blocked |
| Files | `out/atlas/N2.png`, `out/atlas/N2_mask.png`; rejects in `rejected/atlas/` |

**Problem (BEFORE).** The crack-cell net continuing east (D-22), the R5 remnant
panel, and D-08's "ghost mountains" — a painterly smudge sitting among crisp
peaks.

**Roll 1 — REJECT.** The geography was right (crevasses, glacier tongues,
moraine, a rock crag for the Ice-Mage Tower site) but it was **drawn
airbrushed**: soft blended shading, no cel bands, no pixel staircase, edges
anti-aliased. At ×4 it reads as a digital painting downsampled, not pixel art
— a dialect step against N1 sitting right beside it, which is criterion 4 and
the M-12 failure exactly.

**Cheap fix attempted and rejected.** `reduce_colors` (0.1 gen) onto a
256-swatch palette built from the master crop's own most frequent colours cut
13,192 colours to 251 — and changed nothing that mattered. The softness is
structural (blended *forms*), not palette: the accepted N1 carries 17,328
colours and reads perfectly crisp. Recorded so nobody tries it again.

**Roll 2.** Same geography, but the prompt leads with the **drawing hand** —
"hard-edged 16-bit pixel-art snow like a SNES overworld map, flat cel bands of
three or four values with a hard one-pixel step, visible pixel staircases" —
and the geography follows. That inverted order is what fixed it.

**Containment.** 66,047 px changed inside the mask, **0 outside**.

**Guards.** `package-art.js` and `--check` green. Repeated sprite pairs: **0**.

**Read.** A glacier cirque with a headwall, a crevasse field of long dark
splits, moraine-stained rock, a bare crag standing clear (the Ice-Mage Tower
site, §6), and crisp peaks along the top. The cell net is gone across the
whole region.

**Verdict: ACCEPT** (desk).

---

## NB1 — N1/N2 bridge (not an ART-03 region)

| | |
|---|---|
| Crop | `src/atlas/NB1_crop.png`, origin (180,0), 160×300 — cut from the composite **after** N1 and N2 landed, published at commit `f71aa30` so PixelLab could fetch it |
| Inpaint mask | 72×250 at (44,0) — frozen margins left 44, right 44, bottom 50 |
| Job | `afcd4512-e318-4abf-a269-c3d819fce180` · seed **716** · 25 generations |
| Authored rect | atlas **224–296 × 0–250** · ramps left 24, right 24, top 0, bottom 32 · salt 29 |

**Why it exists.** ART-03 gives N1 the mask 0–252 and N2 the mask 240–520:
the two crops overlap by **12 atlas px**, and a boundary cannot be authored in
12 px. Two 32 px ramps both fall below the agreement-commit threshold inside a
gap that narrow, so both commit to 0 and the old honeycomb **leaked through
the seam**. Pairing the ramps (12 + 12, half-alpha contours meeting at atlas
246) closed the leak — but then the contour could wander only ±3.6 px and the
join read as a **straight vertical line at atlas x=246 down the full height of
the phone viewport**. Measured, looked at, and rejected at FOV.

**The fix is the one M-14 taught: author the join, don't blend it.** A crop of
the *current composite* already carries N1's flatter snow in its left margin
and N2's blue-banded drifts in its right, both frozen, so a single inpaint can
draw one slope across them. Because the result agrees with its neighbours at
its own margins, the bridge's ramps sit in low-dissimilarity terrain and
dither freely — the join disappears instead of committing to a contour.

**Result.** At phone FOV and at ×4 the drift bands now run unbroken across
atlas 214–286; no vertical seam, no dither column, one drawing hand.

**Verdict: ACCEPT** (desk). Recorded as a standing lesson: **adjacent ART-03
regions need a bridge wherever their crops overlap by less than about 60 px.**
N2/N3 overlap by 16 px and are watched for the same defect.

---

## N3 — North Shelf & Floe Join — rolls 1-2 (superseded by roll 3 below)

| | |
|---|---|
| Crop | `src/atlas/N3_crop.png`, origin (460,0), 356×304 · inpaint 268×232 at (44,0) |
| Rolls | `a2ec1581-030d-45d4-a650-38013e85a92b` seed 706 — REJECT; `378ad451-f947-49b2-aee6-5eb425a85cc0` seed 717 — REJECT. 80 generations, none shipped |
| Files | `rejected/atlas/N3_r1.png`, `rejected/atlas/N3_r2.png` |

**Roll 1.** Asking for "large ice plates each at least twelve pixels across
with dark water between them" is, read literally, a request for a
**tessellation** — and it produced exactly the honeycomb the same prompt
forbade three sentences later, plus a dark navy rectangle for the sea. The
brief's own geographic sentence and its own prohibition are in conflict here.

**Roll 2.** Rewritten as a drifted snow shelf with a ragged calving edge and
only three or four separated floes. The honeycomb went away and the shelf read
well — but the top third came back as a **flat solid teal rectangle** of
generated open water, which ART-03 §3 rules out in as many words ("never
generate flat water", 0/4 historical acceptance), with a drawn red border
around the mask for good measure.

**Stopped.** ART-03 §7's hard stop and M-12: a region that fails twice is
recorded and left. The composite is unchanged — N3 ships nothing, and the
crack net across atlas 504–772 survives this round.

**Diagnosis for whoever picks this up.** The failure is in the mask, not the
prompt. N3's mask runs y 0–232, which reaches well into open-sea latitudes, so
**every roll is forced to invent sea** — and generated flat water has never
once been accepted here. The fix is a shorter mask that stops where the ice
stops (roughly y 90–232) and leaves the water to the deterministic ocean
conform that already owns it. That is a mask redesign, not another roll, and
it belongs to the next round.

**Consequence: E1 is not opened.** ART-03 gates region 11 on "N3's review
saying the east half still speckles". N3 has no accepted review, so the gate
does not open.

---

## S1 — SW Gloaming (the black slab)

| | |
|---|---|
| Crop | `src/atlas/S1_crop.png`, origin (48,790), 300×282 |
| Inpaint mask | 204×106 at (48,96) — frozen margins 48/48/96/80 |
| Job | `4982f64d-6de8-4f43-95e9-0b6d960081e6` · seed **707** · 25 generations |
| Authored rect | atlas **96–300 × 886–992** · ramps left 24, right 32, top 32, bottom 24 · salt 26 |
| Mask | 10,352 authorized · 7,407 feathered · 24,000 blocked |

**Problem (BEFORE).** D-12, a P0: a near-black canopy slab sitting on the
brightest lime ground — the worst value cliff on the map, with no internal
structure at all.

**Shaped around the golden.** ART-03 puts S1's mask at y 838–986, but
`south_strand_w` occupies 810–870 and its 20 px keepout reaches to y=890.
The region therefore starts at y=886 and only really bites from 891 down. The
top of the slab (atlas 855–886) is untouched — see UNRESOLVED below.

**Containment.** 17,726 px changed inside the mask. 18,260 px differ outside
it, and all of that is the crop's off-canvas padding (atlas y ≥ 1024) being
flattened to white by `no_background:false`; the mask blocks it and the blit
skips `ty >= 1024`, so none of it ships.

**Guards.** green. Repeated sprite pairs: **0**.

**Read.** The slab is now a wood: individual round crowns readable throughout,
canopy stepped from a dark hollow up to lit crowns on the ridge, three grassy
glades open inside it, and scattered outliers where it meets open ground. The
value cliff is much reduced.

**Verdict: ACCEPT** (desk).

---

## S2 — South Coastal Plain

| | |
|---|---|
| Crop | `src/atlas/S2_crop.png`, origin (256,726), 348×346 |
| Inpaint mask | 260×138 at (44,160) — reaches the canvas edge at the bottom |
| Rolls | roll 1 `0fee52cb-5db6-4009-b673-70d1e48b7eee` seed 708 — **REJECT**; roll 2 `126ab542-2803-4352-9250-ab9dbfb559bd` seed **718** — accepted. 80 generations |
| Authored rect | atlas **300–560 × 886–1024** · ramps left 24, right 24, top 32, bottom 0 (canvas) · salt 27 |
| Mask | 24,627 authorized · 7,086 feathered · 46,384 blocked |

**Problem (BEFORE).** D-02, a P0: the south reads as three stacked latitude
bands — sward, then a pale sand stripe running through the *interior*, then
bright lime. A layer cake, not a coast.

**Roll 1 — REJECT, and it was my error, not the model's.** I omitted
`no_background`, so the service auto-detected transparency from the crop's
off-canvas padding rows and returned a **cut-out**: 68.4% of the mask area
came back transparent. Recorded because the trap is easy to walk into — every
southern crop carries padding past y=1024.

**Roll 2.** Same prompt with `no_background:false` and an explicit "solid
opaque ground everywhere" clause.

**Shaped around the goldens.** Both strands (810–870) plus their keepouts own
y 790–890, and `flock_south` blocks another patch, so S2 authors only the
band **below** the strand. The stripe itself is untouchable — UNRESOLVED.

**Guards.** green. Repeated sprite pairs: **0**.

**Read.** Low dune ridges and narrow tidal creeks now run north–south, across
the latitude instead of along it, with gorse and thorn clumps and sand
blow-outs. The lime band is no longer a band — it is machair with structure
running through it, which is ART-03 §2's own recommended default for Q-13.

**Verdict: ACCEPT** (desk).

---

## S3 — Delta Apron — **DEFERRED without spending a generation**

Measured before generating, and the measurement stopped it. S3's declared band
(atlas 372–676 × 740–789, 14,896 px) breaks down as:

| | px | share |
|---|---|---|
| `flock_south` golden + 20 px keepout | 5,145 | 34.5% |
| Inside the A-4 frozen core (unwritable) | 1,592 | 10.7% |
| Inside the A-4 rim (writable, but `keepRepair`-dithered — the W1 finding) | 3,980 | 26.7% |
| Free | 4,179 | 28.1% |

With `rimBlock` on, the built mask has **0 fully-authorized pixels** and only
3,959 partial ones: the free 28% is fragmented and none of it is far enough
from an edge for a 32 px ramp to reach full alpha. There is nothing here for a
generation to land on. D-09, D-19 and D-25 survive this round.

**Not attempted.** Spending 25 generations to write a few thousand
half-alpha pixels fails cost discipline; the honest answer is that this band
is inside protected geometry and needs an owner decision, not a roll.

---

## S4 — SE Terrace & Spit — **DEFERRED without spending a generation**

S4's entire declared mask (atlas 628–786 × 806–880) lies inside
`south_strand_e` (512–800 × 810–870) plus its 20 px keepout (790–890).
**Nothing in it is writable.** ART-03 §2 already flagged this: rows 8 and 10
cross the strand goldens and re-extracting a golden is an owner
authorization, not a producer's. D-05 residue, D-15 and D-20 survive.

---

## UNRESOLVED — the strand goldens block the southern P0s

ART-03 §2 names this and it stayed true all round: **S1's top, S2's stripe and
all of S4 sit inside `south_strand_w` / `south_strand_e` (y 810–870) or
their keepouts.** The layer-cake defect D-02 — a P0, the owner's own
complaint — *is* the strand band, and the band is byte-enforced.

Deliberately re-authoring a landmark means re-extracting its golden in the
same commit, and the golden's git diff is the authorization (landmark registry
header, R3b pattern). **That authorization is the owner's to give and I have
not assumed it.** Every southern region here was shaped to stay clear.

What it would unblock, if granted: the sand stripe stops running through the
interior; S1's slab is fixed to its top edge instead of from y=891 down; S4
becomes possible at all. Recorded in `JOURNAL/OPEN_QUESTIONS.md`.

---

## N3 — roll 3 — **ACCEPTED**

Re-authorised by the coordinator after the round's first pass: one roll, cap 60
generations, with the diagnosis I recorded on the deferral applied.

| | |
|---|---|
| Crop | `src/atlas/N3_crop.png`, origin (460,0), 356×304 (unchanged — no new crop published) |
| Inpaint mask | **268×142 at (44,90)** — was 268×232 at (44,0). Frozen margins 44 on all four sides |
| Job | `835092d1-0930-4eba-a701-420df2118bad` · seed **726** · 40 generations |
| Authored rect | atlas **504–772 × 90–232** · ramps left 10, right 32, top 32, bottom 32 · salt 25 · `rimBlock` |
| Mask | 21,936 authorized · 13,071 feathered · 20,856 blocked |

**What changed, and it was the mask.** Rolls 1 and 2 both failed because the
mask ran to y=0 and therefore reached open-sea latitudes, forcing every roll to
invent sea — and generated flat water has never been accepted here. Shortening
the mask to y 90–232 removed the requirement to invent water at all, and the
honeycomb/flat-panel failure went with it. The prompt still leads with the
drawing hand and now asks for **pack ice thinning off a shelf** — floes of
varying size, worn and rounded, never touching, with narrow winding leads —
plus an explicit instruction to leave every existing teal patch exactly where
and what it is.

**Goldens.** The shortened mask sits entirely above every nearby golden's
keepout: `frostmere_north_wall` begins at y=236, `volcano_east_cliff` at
y=240, `east_watchtower_flank` at y=253.

**Containment.** 32,145 px changed inside the mask; 2,907 outside it (the
generation reached down to crop y=292), all blocked by the mask — the guards
confirm none of it reached a golden.

**N2/N3 join — no bridge needed.** The generations overlap by 16 px (atlas
504–519), well under the 60 px the NB1 lesson set as the bridge threshold, so a
bridge was budgeted for. It proved unnecessary because the two edges can be
made *provably* complementary: N2's right ramp draws `wander(sy, salt+1)` with
salt 24 and N3's left draws `wander(sy, salt+0)` with salt 25 — **the same
call**. Setting both ramps to 10 makes their half-alpha contours move
symmetrically about atlas 511.5, with half-width k = R(1+0.6w)/2 ≤ 8 for R=10
and a gap requiring k > 8. So the join can never open, and at ×3 it reads as
N2's drifted snow flowing into N3's leads along an organic contour, with no
vertical line. (N2's right ramp was 40 while N3 was deferred; it is back to 10.)

**Top join.** At ×3 the floe field grows out of the surviving fast ice with no
horizontal ruler line — the old crack lines widen into lead channels.

**Guards.** `package-art.js` and `--check` green; core drift 0, 15 goldens
held. Repeated 10×10 sprite pairs within 40 px: **0**. 3 red debris px
despeckled.

**Honestly bounded.** The crack net survives *above* y=90 and east of x=772
(E1's ground). That is the deliberate price of the shortened mask, and the
right trade: a smaller region that reads, rather than a full-height one that
invents sea. E1 remains unopened.

**Verdict: ACCEPT** (desk). The physical iPhone is still the authority.

---

## NB2 — N2/N3 bridge (not an ART-03 region)

| | |
|---|---|
| Crop | `src/atlas/NB2_crop.png`, origin (440,60), 140×200 — cut from the composite **after** N2 and N3 landed, published at commit `2bb50f0` so PixelLab could fetch it |
| Inpaint mask | 72×140 at (36,30) — frozen margins left 36, right 32, top 30, bottom 30 |
| Job | `67e99899-46b8-4560-aaac-a40dce8126d3` · seed **736** · 20 generations |
| Authored rect | atlas **476–548 × 90–230** · ramps left 32, right 32, top 32, bottom 32 · salt 30 · `rimBlock` |
| Mask | 2,755 authorized · 5,849 feathered · 3,360 blocked |
| Files | `out/atlas/NB2.png`, `out/atlas/NB2_mask.png` |
| Evidence | `review/atlas/NB2_{before,after}_{full,x2,fov}.png`, `NB2_join_compare_x3.png`, `NB2_after_upper_x4.png` |

**Why it exists, and why N3's own join note did not settle it.** N3 roll 3
recorded "no bridge needed": N2's right ramp and N3's left ramp draw the *same*
`wander` call at width 10, so the two half-alpha contours move symmetrically
about atlas 511.5 and the join can never open a gap. That argument is correct
and it is about **coverage**, not about **content**. A 10 px ramp cannot carry a
texture change, and this join is one: flat drifted snow on the left, teal leads
and rounded floes on the right. With the agreement grading commiting the ramp
wholly to one side wherever the two differ — which is everywhere here — the
contour had only ±3 px of wander to hide in, and at ×2 and at phone FOV the
result read as a **near-vertical edge at atlas x ≈ 508 over y ≈ 117–178**. The
NB1 lesson applies exactly: adjacent regions need a bridge wherever their crops
give a boundary less than about 60 px to be authored in.

**Method.** The NB1 pattern unchanged: crop the *current composite* so N2's snow
sits frozen in the left margin and N3's floes frozen in the right, then inpaint
one continuous surface across them. Prompt leads with the drawing hand (the N2
roll-2 inversion) and asks for drifted snow breaking up into the first worn
floes and narrow winding leads, the shelf edge fraying diagonally.

**Goldens.** The mask stops at atlas y=230 — **6 px clear** of
`frostmere_north_wall`'s 20 px keepout, which begins at y=236.

**Containment.** `atlas-verify.js`: 8,284 px changed inside the mask; changed
bbox (36,30)..(107,169), exactly the inpaint rectangle, so nothing was redrawn
outside it. 1,444 px changed inside the inpaint rect but outside the graded
mask (the ramp shoulders); the mask blocks them and none ship.

**Guards.** `package-art.js` and `--check` both green: protected-interior drift
0, all 15 landmark goldens byte-held. No guard touched.

**Measured.** `atlas-qa.js` over atlas 440–580 × 60–260: repeated 10×10 sprite
pairs within 40 px **0**; orphan flecks 82 raw over 28,000 px = **29.3 per
10k**, well under the approved core hero region's own 69.8, so no despeckle. 0
red debris pixels — the border artefact N1 and N3 roll 2 drew did not recur.

**Read.** `NB2_join_compare_x3.png` is the decisive view. The razor vertical at
atlas 508 is gone: the floe field now frays leftward and downward in a lobed
tongue, its top corner broken into separate small floes stepping out onto the
drifted snow, and its left boundary is a stepped organic diagonal. At ×2 no
vertical line, no dither column, no rectangle, no repair footprint. At 197×426
phone FOV the pack ice reads as one shelf edge thinning westward. At ×1 the
whole northern floe band runs unbroken from x ≈ 480 east.

**Honestly bounded.** Two things this did not do.

1. The bridge's floes are **smaller and more tightly packed** than N3's next to
   them, so there is a mild scale step in floe size across the tongue. It reads
   as brash grading into larger floes, which is directional and plausible, and
   `atlas-qa` finds no repeated sprite — but it is denser than the neighbour and
   worth the owner's eye at ×2. It is not the D-22 crack-net (thin dark lines on
   flat pale ground) and it is not a lattice.
2. The join **above** the mask — atlas x ≈ 505–518, y 0–90, where N2's right
   edge meets the surviving master ice — is unchanged. It is outside this
   brief's y-range and it is a tone step rather than a drawn line
   (`NB2_after_upper_x4.png`), much weaker than the edge below it was, but it
   is still the last straight-ish thing on that meridian.

**Verdict: ACCEPT** (desk). The physical iPhone remains the authority.

---

# WORLD_FIX pass — answering FINAL-04 and FINAL-12

Cap **160 generations**; balance at start **8,173**, at close **8,013** —
**spent exactly 160, and it bound.** Ledger: `ledger/WORLD_FIX.md`. Same
mandated loop as above: one defect at a time, generate → composite → guards →
×2 + phone FOV → explicit verdict. The physical iPhone remains the authority.

## N1 / N2 dialect — **the deterministic fix worked; no re-roll spent**

FINAL-04 #1 is correct and I could reproduce it before touching anything:
`review/fix/BEFORE_N2_x6.png` beside `BEFORE_N1_x6.png` is smooth gradient
against pixel staircase. FINAL-12 #9 is also correct — the shipped N1 is
softer than the master it replaced.

**Measured, not judged.** Over a fixed rect, per-scanline horizontal luma
deltas classed as *hard* (≥10) or *soft gradient* (2–10):

| | hard step % | soft gradient % |
|---|---|---|
| master `4d9a81f` NW (the reference dialect) | 16.56 | **16.73** |
| N1 as shipped | 17.23 | **23.64** |
| N2 as shipped | 17.75 | **20.69** |
| N1 after the remap | 16.67 | **16.02** |
| N2 after the remap | 16.14 | **13.96** |

**Method.** `tools/atlas-quantise.js`: build a palette from the ORIGINAL master
(`git show 4d9a81f:assets/art/v1/world/atlas_base.png`, kept at
`src/atlas/MASTER_4d9a81f_atlas_base.png`) by taking its colours in frequency
order and accepting each only if it is ≥ *spread* from every colour already
accepted, then snap every pixel to the nearest entry. **No dithering** — a
dither would put two colours where the generation put one and read as the
noise this round exists to remove. A-2 holds: every output pixel is a colour
that already exists in an approved image.

**Two parameters were chosen by measurement, and both differ from the brief.**

1. **Palette rect 0–300 × 0–200, not × 0–260.** The extra sixty rows reach the
   master's southern vegetation margin and contribute seven olive/khaki
   entries; snapping snow to those sprayed visible yellow-green flecks across
   N1 (`review/fix/N1_quant16_x6.png`). At y<200 the palette carries one warm
   entry and the flecks are gone.
2. **Spread 7 (71 entries), not the flattest setting.** 13 and 16 look
   handsome at ×6 but land at 1.7% soft gradient against the master's 16.7% —
   *more* posterised than the reference. 7 lands on the master's own numbers.

**Applied to N1, N2 and NB1** — the snow group — and **restricted to each
region's own inpaint rect** (`--rect-only`), so the frozen crop margins stay
byte-identical and the agreement grading still sees agreement at the edges.
Masks rebuilt afterwards from the remapped generations.

**Rejected for N3 and NB2.** `review/fix/N3_raw_vs_s7_x5.png`: the pack ice's
teal is not in a snow palette, and snapping it speckled the floes and blotched
the leads. Those two keep their own pixels; NB2 is now the graded transition
between the remapped snow and the untouched floes, which is what a bridge is
for.

**Cost: 0 generations** — and that is the only reason items 3–6 fitted inside
the cap at all.

**Verdict: ACCEPT** (desk) for N1, N2, NB1. **REJECT** the remap for N3, NB2.

## NB3 — the north razor bridge — **ACCEPTED**

| | |
|---|---|
| Crop | `src/atlas/NB3_crop.png`, origin (440,0), 140×150 — cut from the composite **after** the N1/N2 remap, published at commit `c8b8605` |
| Inpaint mask | 72×110 at (36,0) — frozen margins left 36, right 32, bottom 40; top is the canvas edge |
| Job | `10666417-e4d7-4099-b910-566bfde431a3` · seed **746** · 20 generations |
| Authored rect | atlas **476–548 × 0–110** · ramps left 32, right 32, top 0, bottom 32 · salt 31 · `rimBlock` |
| Mask | 1,808 authorized · 4,337 feathered · 0 blocked |

**Why.** FINAL-04 #2: NB2 fixed this meridian only from y=90 down. Above it
the razor survived — `review/fix/RAZOR_before_x6.png` shows N2's snow meeting
the untouched master pack ice on a straight vertical at atlas x≈513, over
110 px, with two drawing hands either side.

**Containment.** Changed bbox in crop coords (36,0)..(107,109) — exactly the
inpaint rectangle. 1,764 px changed inside that rectangle but outside the
graded mask (the ramp shoulders); the mask blocks them and none ship.

**Guards.** `package-art.js` and `--check` green; protected-interior drift 0,
15 goldens byte-held. The mask ends 126 px above the A-4 core and far above
every keepout in the north.

**Measured.** Per-column mean L1 over y 0–110: the old razor at x=513 falls
from **81.0 to 59.7**, and the band median rises 29.6 → 38.1, so the peak-to-
median ratio goes 2.74 → 2.22. The columns that now score highest (514, 524)
are the *drawn lead itself*, not a join — `review/fix/NB3_after_razor_x6.png`.

**Read.** The straight cut is gone. A winding dark lead runs down from the
canvas edge and the snow interlocks with the floes along it. At 197×426 phone
FOV (`review/fix/NB3_after_fov.png`) the shelf reads as one fraying edge.

**Honestly bounded.** The floes NB3 draws are smaller and more tightly packed
than N3's, the same mild scale step NB2 conceded. And D-22's crack net still
survives east of x≈640 — the priced trade FINAL-04 #13 already names.

**Verdict: ACCEPT** (desk).

## Sea-ice sage debris — removed, 342 px

FINAL-04 #7 measured correctly and the origin is worth recording: the sage
patch (#6dc5b2, 343 px in atlas 620–790 × 90–235) is in **neither** the
`4d9a81f` master **nor** N3's own generation. It is produced downstream, by
the deterministic ocean conform, so a despeckle on the region source removed
nothing. The cleanup now sits in `package-art.js` **after**
`remWater.shoalRamp` — the same pattern as the flotsam and ghost-sail passes,
each debris pixel taking the colour of the nearest clean pixel on a fixed
offset list. Rect-gated, because the same predicate matches every blade of
grass on the map.

**The lavender half of #7 is not reproducible.** A loose predicate (blue ≥
green and red > green) over atlas 500–800 × 90–240 finds **one** pixel. The
smudge the review saw at 634–647 × 106–121 is grey-blue shelf ice, and I have
recorded it as not-a-defect rather than invent a fix for it.

## GAP snowline (FINAL-04 #9) — **NOT FIXED, and the cheap fix is disproved**

After the N1 remap the numbers moved: the 72 px run at y=271 is down to
**22 px**, but y=270 now scores 106.0 against a band median of 47.9, with a
**43 px** run at x 89–131.

The coordinator offered a ramp widening as the zero-generation alternative. I
tried it: N1's bottom ramp 32 → 56, mask rebuilt, repackaged, re-measured —
row 270 scored **106.0, run 43, unchanged to the digit**. The reason is that
row 270 is *below* N1's authorization and inside W2's own top ramp: it is a
terrain boundary the base composite already carries, not a join either region
draws. A ramp cannot move it. It needs the authored fraying the coordinator
budgeted, and the cap was spent. The ramp change was reverted.

## S1 wood edge (FINAL-12 #10) — **NOT FIXED, and measured smaller than reported**

Before spending on it I measured with the same row/column run test:

- west edge, columns 84–136 over y 890–988: longest straight run **10 px** at
  x=96, against a band median column score of 40.1. That is a content cliff,
  not a ruler line;
- north edge, rows 880–900 over x 96–300: longest run **31 px** at y=893.

And most of that north band is unwritable: `south_strand_w` plus its 20 px
keepout owns y ≤ 890, so an inpaint could only fray from y=890 down — the
same UNRESOLVED strand-golden block this log already records. Recorded with
its measurements so the next round can price it honestly.

---

## Cap-raise pass (+120) — items 1 and 4

### 1. The grey-green rectangle at atlas 195–245 × 200–256 — **NOT ATTEMPTED, blocked on transport**

The coordinator's re-read of the defect is right and my earlier row-270 framing
was its bottom edge only. `review/fix/GAPRECT_before_x4.png` (atlas 150–300 ×
130–320 at ×4) shows a drab olive-grey slab of master terrain sitting between
N1 and the frozen core's rim, with spruce standing on its top edge — terrain no
region's mask ever covered.

**Measured before, so the after has something to be measured against.**

| | score | band median | longest straight run |
|---|---|---|---|
| vertical, x=200 (y 150–260) | 55.0 | 40.7 | 17 px |
| vertical, x=201 | 63.0 | 40.7 | 13 px |
| vertical, x≈240 (the slab's true right edge) | 92.8 at x=233, 93.9 at x=230 | 40.7 | — |
| horizontal, y=160 (x 150–256) | 15.2 | 39.3 | 8 px |
| horizontal, y=255 (the slab's true bottom edge) | **133.4** | 39.3 | — |

So the slab's hard edges measure at **x≈230–233** and **y=255**, not at the
x≈200 / y=160 the brief names; x=200 and y=160 are inside it. The prescribed
inpaint rect (atlas 150–256 × 140–310) covers all of it either way and is the
right rect.

**Why it was not rolled.** The mandated method inpaints over a crop of the
current composite, and `inpaint_image` needs that crop by URL. The standing
practice — and the explicit instruction for NB3 earlier in this same pass — is
to commit and push the crop so PixelLab can fetch it by commit SHA. This pass
was instructed to make **no commits**, so no URL exists. The only other
transport is inline base64, and the crop is **38,024 base64 characters**
(138×202 with 16 px frozen margins, already the smallest image that can carry
the prescribed 106×170 mask). PixelLab's own tool note is that MCP clients
routinely truncate inline base64 of that size, and every attempt to shrink it
failed: RGB re-encode with Sub and Up filters came back *larger* (43.6k and
47.6k), RGB with filter 0 saved 1.1% (37.6k), and max-level deflate saved
nothing.

The crop is cut and waiting at `src/atlas/GAP_crop.png` (origin 134,124,
138×202; mask 16,16 106×170 = atlas 150–256 × 140–310). **One line unblocks
it:** permission to commit and push that single file, exactly as `c8b8605`
published NB3's. The roll is then ~20–25 generations.

**The deterministic alternative stays disproved** — see the WORLD_FIX section
above: N1's bottom ramp 32 → 56 moved row 270's score by 0.0, because none of
this slab is inside any region's authorization.

### 4. S1 north edge — **SKIPPED under the brief's own rule**

The rule was: skip if the writable band is under 20 px tall. It is **10 px**,
and even that is barely writable.

`south_strand_w` (128,810,400×60) zeroes the mask within 20 px and then ramps
back over a further 24, so on the column x=200:

- alpha is **0.00** through y=889 — that is the whole top of the defect
  (rows 886 and 889);
- alpha reaches 0.04 at y=890 and only **0.42 by y=899**, the last defect row;
- the first fully-authorized row is **y=913**, fourteen rows *below* the defect.

So the writable band containing the defect is y 890–899 — **10 px, all of it
under half authorization**. Skipped, 0 generations. It stays part of the
standing UNRESOLVED strand-golden block: re-extracting that golden is the
owner's authorization, not a producer's.

---

## GAP — the grey-green slab — **ACCEPTED**

| | |
|---|---|
| Crop | `src/atlas/GAP_crop.png`, origin (134,124), 138×202 — cut from the composite **after** the N1/N2 palette remap, published at commit `c79e197` so PixelLab could fetch it |
| Inpaint mask | 106×170 at (16,16) — frozen margins 16 on all four sides |
| Job | `bb3ad9bf-d866-4f52-847c-b5d1c56b3cca` · seed **756** · 20 generations · **one roll, no re-roll needed** |
| Authored rect | atlas **150–256 × 140–310** · ramps left 32, right **20**, top 32, bottom 32 · salt 32 · `rimBlock` |
| Mask | 7,884 authorized · 7,050 feathered · 1,120 blocked |
| Files | `out/atlas/GAP.png`, `out/atlas/GAP_mask.png` |
| Evidence | `review/atlas/GAP_{before,after}_{full,x2,fov}.png`, `review/fix/GAPRECT_{before,after}_x4.png`, `GAP_rightjoin_x6.png`, `GAP_measure_{before,after}.txt` |

**Provenance corrected before the roll, and it changes what this is.** The
brief describes the slab as terrain no region's mask covered. Measured, it is
not: N1's mask reads **255** across it and the composite there is
**byte-identical to N1's own generation**; only **54 of 2,856 px (1.9%)** of
the rect still match the `4d9a81f` master. The slab is N1's own "rime conifers
on the south margin" drawn as a flat mass, which the palette remap then
snapped flatter. So GAP is a **repaint of an accepted region**, not a fill of a
hole, and it composites **after N1 and NB1** to supersede them. Recorded
because it changes who owns the defect.

**The measured edges, before and after** (`tools/gap-measure.js`, identical
code both times; score = mean L1 across the line, run = longest unbroken stretch
over threshold 28).

| line | before | after |
|---|---|---|
| vertical x=200 | 55.0, run **17** | 26.4, run **6** |
| vertical x=230 | 93.9, run **19** | 62.9, run **4** |
| vertical x=233 | 92.8, run **27** | 60.0, run **4** |
| horizontal y=160 | 15.2, run 8 | 37.4, run **6** |
| horizontal y=255 | **133.4**, run **35** | 64.7, run **5** |
| band medians | 40.7 / 39.3 | 38.4 / 37.1 |

Every straight run collapsed — 17→6, 19→4, 27→4, 8→6, 35→5 — and y=255, the
slab's bottom edge and the strongest horizontal in the band, fell from 133.4 to
64.7. y=160 rose from 15.2 to 37.4, which is the point: it was *below* the band
median before because it lay inside a flat slab, and it now sits at the median
as ordinary texture.

**The right ramp was chosen by sweep, not by convention — and roll 1 needed it.**
At the conventional 32 the ramp reached full alpha only at atlas ≈224, so the
slab's rightmost columns survived as a **7 × 28 grey rectangle at atlas
239–246 × 227–255** — the exact defect class this round removes, smaller but
crisper than what it replaced. That is a mask-coverage fault, not a generation
fault, so a re-roll would not have touched it. Sweeping the right ramp
(surviving slab-grey px in atlas 236–252 × 225–258 / worst straight run in
columns 230–256):

| ramp | 8 | 12 | 16 | **20** | 24 | 28 | 32 |
|---|---|---|---|---|---|---|---|
| sliver px | 1 | 1 | 3 | **10** | 61 | 107 | 155 |
| worst run | 14 | 36 | 14 | **10** | 23 | 23 | 18 |

**20** is the minimum of the straight-run metric with the sliver down **94%**
(155 → 10 px, scattered and invisible at ×6). Fixed at 20; the re-roll
allowance was not spent.

**Containment.** `atlas-verify.js`: 14,702 px changed inside the mask; changed
bbox in crop coords (16,16)..(121,185) — exactly the inpaint rectangle. 3,075
px changed inside that rectangle but outside the graded mask (the ramp
shoulders and the `rimBlock` zone); the mask blocks them and none ship.

**Guards.** `package-art.js` and `--check` green (1,779 files up to date).
Asserted directly rather than inferred: **15/15 landmark goldens held** under
the guard's own rule (byte-equal, with its deep-water exemption), and the GAP
mask covers 1,120 px of the A-4 protected rect at **max alpha 0** — `rimBlock`
holding the frozen core and its dithered rim untouched. `check-art-palette.js`
ok over 1,834 PNGs. `flutter test` on the three atlas suites: **71 passed**.

**Read.** At ×4 the flat olive-grey rectangle is gone: a wind-drifted snowfield
runs down from the north in sastrugi bands and breaks into a ragged conifer
treeline with scrub lobes and rock outcrops, the treeline diagonal and
interlocking rather than cut. At ×6 on the right join there is no vertical
column, no rectangle and no dither stripe. At 197×426 phone FOV the snow grades
into the western meadows as one slope, one drawing hand.

**Honestly bounded.** The new worst columns in the band are 213 (84.5) and 232
(79.1) with runs of 4–10 — drawn treeline edges, not seams. Ten slab-grey
pixels survive inside atlas 236–252 × 225–258 and are below the despeckle
threshold; they are recorded rather than swept.

**Verdict: ACCEPT** (desk). The physical iPhone remains the authority.
