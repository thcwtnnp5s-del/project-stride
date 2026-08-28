# WORLD ATLAS REMASTER 01 — Round Record

**Branch:** `world-atlas-remaster-01` (from `fable-v2-experiment` @ `3aabfae`)
**Date opened:** 2026-08-27
**Mandate:** reconstruct the atlas into a coherent illustrated world by regional
recomposition, protecting the geography and landmarks that already work. Not a
seam-repair pass (`MISTAKES.md` M-12/M-14/M-15; `RULES.md` A-3/A-4; owner brief).

This README opens with the round's **Design Thesis** — written after a
seven-agent audit (provenance, geography, protection, production method,
phone-scale critique, compositor design, interaction constraints) and before
any generation. Production sections follow it as the round proceeds.

All coordinates are **1024² atlas px** (world px = atlas × 6).

---

## DESIGN THESIS

### 1. Why previous repair methods failed

Four passes of evidence, one conclusion each:

- **M-12** — independently generated tiles butted edge-to-edge never became one
  painting; palette conform and seam metrics measure pixel-edge continuity, not
  geographic or artistic continuity.
- **M-14** — narrow dither/seam bands are straight axis-aligned bands at ×6
  phone scale; blending narrows a seam but authors nothing across it. And *a
  repair has a perimeter too*: a bridge that removes a seam can ship its own
  rectangular footprint.
- **M-15** — repairs with no enforced boundary repainted 35.3 % of the approved
  master interior (Frostmere basin erased, watchtowers deleted). Protection
  that lives in intention fails silently; it must live in tooling.
- The ocean refinement showed the one place determinism wins outright: flat
  open water, where one palette is the whole answer.

The compound lesson: **edge-local fixes cannot repair regional incoherence.**
When a defect spans a region — two ice dialects, a half-map forest wall, an
unpainted corner — the region must be re-authored as one geographic scene, with
protected pixels mechanically excluded.

A critical audit finding frames this round: **the current shipped composite has
never been device-reviewed.** The last atlas the owner saw (`6c1cb88`) still
contained the M-15 interior damage. The WAR01 restore, the four adoptions and
the final ocean conform are desk-reviewed only. This round's phone-scale audit
of the *current* file is therefore the honest baseline.

### 2. What geographic structure the world should have

One north–south continent (compass per the amended
`GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md` §8): frozen shelf and pack
ice across the north; a glaciated NW massif; the Worldspine wall down the west
with Wayfarer's Pass; a temperate forested heart around the Meadowrun river
(source ~(515,360) below the icefield, gorge past Stonefall, past Haven's
Rest, braiding around Amberfield into the SE delta); a fire-against-ice
volcanic cape in the east; a marsh/silt/strand belt in the south; open ocean
with an island scatter east and southeast. The interior hydrology already
works. The intended reads per system: mountain chains connect and taper;
forests thin over 30–50 px gradients, never at walls; the north is one
climatic sequence (shelf ice → floes → brash → open cold sea); the volcano
radiates from its geological source (already true); rivers reach the sea
(already true in the east; the west plain is dry — acceptable lee-side
geography, logged, not this round's problem).

### 3. What is already good (preserve, do not touch)

Per the blind phone-scale critique: the **center hero region** (~300–620,
300–800) — mountains, glacier lake, river, hamlet, henge, walled village,
braided delta; the **volcano peninsula and coast** (600–800, 280–470)
including the glacier-meltwater channel ("genuinely seamless"); the **NW
glacier vignette** (0–210, 60–240); the **western meadows/road interior**;
the **gray tidal-flat estuary transition** (300–630, 740–850); the **east
archipelago and open sea** (768–1024, 260–1024).

### 4. What needs regional recomposition (the defect ledger)

Phone-scale P0 blockers (blind sweep, current composite):

| ID | Defect | Bounds |
|---|---|---|
| D1 | Dead-straight vertical waterline through the east bay/delta — the ocean-conform rect's own western edge at x≈637 showing in flat water | x≈637, y 440–960 |
| D2 | NE pack-ice dialect seam + black shape decapitated mid-form; flat mint strip | x≈755, y 0–280 |
| D3 | NW crackle-ice paste rectangle, corner at (240,141); amputated nunatak at x=256 | (240–380, 141–270) |
| D4 | The great forest wall — density/saturation wall on the master's west boundary; half-ghost peak sliced at (220–280, 585–680) | x 250–258, y 300–800 |
| D5 | SW unfinished line-art "sketchlands" meeting paint at a dithered vertical; sand-rectangle corner at (118,825) | (0–140, 690–1024) |
| D6 | SE surf/beach chopped flat at a vertical cut | x=512, y 905–1015 |

P1: D7 floe-dialect corner at (510,27); D8 NE-corner ghost tonal rectangles in
open water (~988–1024, 30–150). P2 and below-zone defects logged in §Deferred.

### 5. Protected landmarks (enforced, not remembered)

The full coordinate protection table lives in `PROTECTION_PLAN.md` in this
round (ATLAS-C audit). Headlines: the A-4 guard already hard-freezes the
master core (276,276)–(748,748). Outside it, this round adds a **landmark
registry with committed golden crops** and a packaging guard (see §7):
volcano east cliff/coves (752–824, 260–470), both watchtowers, the WAR01
south strand bands (128–800, 810–870), the west caravan road + corridor/road
patches (128–320, 480–575), the stag/fire/flock in-place overlay boxes, the
Frostmere basin rim-band edge, and the SE island clusters. Every in-place
ambient overlay box is frozen ground (frame 0 is an untouched source crop —
repainting beneath one makes the old painting pop through).

### 6. What is replaceable

Everything inside a planned region's mask that is not registry-protected —
specifically the NE ice collage, the west forest-wall transition band west of
x≈276, the SW sketchlands, and the D6 cut. Open flat water may be conformed
deterministically anywhere (A-2).

### 7. Method

**Pipeline (tooling first, zero generations):**

- Regions integrate as **post-snapshot layers** in `package-art.js`, blitted
  after the WAR01 adoptions and WACUI edge fixes, before flotsam/ocean
  conform. The A-4 snapshot, restore, rim band and drift guard stay
  byte-identical to today — regions stay outside the protected core, and any
  accidental rim intrusion is clipped by the existing `keepRepair` machinery.
  (The audit's alternative — pre-snapshot placement redefining the approved
  interior — was considered and rejected for this round: it requires an
  owner-level A-4 semantics change and none of the planned regions need core
  pixels. Recorded here per G-3.)
- Each region ships with a tracked **manifest entry** (`manifest.json`:
  bounds, source generation, graded mask, status accepted/withheld — a
  withheld region throws, the RCP pattern) and a **graded grayscale mask**
  composited by **hash dither-select** (never averaging — every output pixel
  is one of the two approved images' own pixels, A-2), fresh salt.
- **Guards per region:** status gate; mask containment (any changed pixel
  outside the mask throws); landmark identity (registry pixels byte-equal
  after the blit).
- **Landmark registry guard:** committed golden crops for the protected
  features of §5, compared byte-wise after the full composition (post-conform)
  — any layer that touches one fails packaging and `--check`. Deliberate
  re-authoring = re-extracting the golden in the same commit.

**Generation:** `inpaint_image` over a wide crop of the **live shipped
composite** with frozen margins — the only method with a near-perfect
first-roll record (WACUI 12/12, WAR01 4/4). Crop ≥48 px larger than the mask
on every side; mask edges land in uniform terrain; protected features sit
outside the mask with ≥20 px standoff; prompts carry the WAR01 guardrails
verbatim (exact palette, same pixel-art hand, "no new towers, buildings,
roads, rivers"), fixed recorded seeds. **Never generate flat water** (0/4
historical acceptance) — water is deterministic. Partial adoption is a
first-class outcome. All image transport through the WMER02 `plab.js` direct
client (the interactive MCP layer corrupts base64 >~5.5 KB).

### 8. Budget (queried, not remembered)

**205 generations remaining**, $0.00 credits, reset 2026-09-16. Cost model:
full-region inpaint ≈35 (worst 40); sub-region ≈25; correction ≈22.

| Item | Plan |
|---|---|
| Phase 0 deterministic (D1, D8) | **0** |
| R1 NE Pack-Ice (D2) | 35 |
| R2 West Verge (D4) | 35 |
| R3 SW Sketchlands (D5) | 35 |
| R4 SE surf cut (D6, small — **gated**: only if spend after R2 review ≤ 120) | 25 |
| Correction round (rate-based) | 50 |
| **Reserve (untouchable below)** | **25** |

Hard stops: next call's worst case would breach the reserve; a region fails
twice (M-12 rule — restore composite, record, defer); the drift guard throws;
R1's primary bills >40 (cost model wrong → re-plan before R2).

### 9. Ordered region plan

**Phase 0 — deterministic water fixes, 0 gens:** dissolve D1 by extending the
conform predicate over all deep water east of the coast and replacing the hard
rect edge with a depth-following, hash-irregularized shoaling ramp between the
two approved water palettes (selection dither, A-2 — flat water is the one
place determinism is the whole answer); conform the D8 ghost rectangles.
Phone-scale render review before/after; if the ramp still reads straight, D1
graduates to a small correction-round inpaint.

**R1 — NE Pack-Ice Corridor** (~(640–1024, 0–320)): shelf ice calving to
floes to brash to open water as one NW→SE gradient; the decapitated black
wedge either deleted or made a real skerry in the Cinder Skerries family.
Keeps: volcano north cape, Far Isles, interior ice west of the mask edge.
First because it is the lowest-risk canvas (no settlements, no routes, ice is
forgiving) and proves the new compositor machinery.

**R2 — West Verge / the forest wall** (~(160–300, 440–860) tall crop): the
interior forest thins westward into fingers, clearings and parkland over
30–50 px; the half-ghost peak resolved (completed as a Worldspine outlier or
removed); mask's east edge feathers into the rim band, never deeper. Keeps:
caravan road course + forest entry (245, 505–520), caravan/stag/fire overlay
grounds, everything east of x≈276.

**R3 — SW Sketchlands** (~(0–176, 660–1024)): the Worldspine's southern spur
stepping down to the SW coast, painted in the chain's own language; ruin
scraps finished or removed; sand-rect corner at (118,825) healed if the mask
reaches. Keeps: coastline hand-off band toward the south strand (which is
registry-protected).

**R4 (gated) — SE surf cut** (small crop ~(430–590, 860–1024)): continue the
beach/surf arc through the x=512 cut. Keeps: south strand band (mask sits
below/around it), Sunward Strand label ground.

**Deferred to the 2026-09-16 reset** (recommended plan, not this round): D3
NW crackle-ice rectangle (next-highest P0; first call on any end-of-round
surplus above reserve, else deferred); D7 floe corner; Zone 1 southern-shore
harmonization (the y≈810 lime-palette latitude break — conflicts with the
protected strand and exceeds 512² anyway); Zone 5 treeline-band re-author
(confetti treeline); canopy banding (267–330, 750–800); peninsula dot-spray
tip; Wayfarer's col painting; the Glasslake/Frostmere naming question (logged
for the World Designer, not a paint fix).

### 10. Stop conditions

Listed in §8, plus: any region that would require moving a location hit
target, route polyline vertex, or label to make its art work is out of scope —
regions are chosen so this cannot arise; the round stops when the six P0s are
resolved or their budget is exhausted. After the one-world illusion holds at
phone scale, remaining P1/P2 items are logged, not chased.

**Per-region loop (mandatory, the owner's single-defect discipline at regional
grain):** capture BEFORE → state the problem → geographic intent → protected
zones → generate → inspect variants → select/reject → integrate in the
production pipeline → regenerate the shipping atlas → inspect full atlas,
region context, every perimeter, phone-FOV, max zoom → ACCEPT / REWORK /
REJECT → only then the next region. Never a batch of unreviewed regions. The
physical iPhone remains the final authority; this round's desk verdicts are
staging for the owner's device checklist.

---

## Production log

### Phase 0 — deterministic water joins (0 generations) — ACCEPTED (desk)

**Problem:** D1 — the ocean-conform rect's west edge at x=636 read as a
dead-straight waterline through the east bay (probe: unconformed bright
deep-predicate water rgb(141,201,159) west of the line vs conformed
rgb(62,152,166) east, a three-pixel step). D8 — the rect's y=60 top edge
left the far-NE corner's water unconformed (rgb 135–144 vs 62).

**Fix:** `tools/water_join.js` + an optional `extraRects` parameter on
WACUI's `ocean_unify.unify` (default byte-identical). The bay strip
[560,440,76,520] and corner strip [896,0,128,60] join the SAME single global
transform; a hash-dithered remix (salt 7) then restores original bright bay
water with probability 1→0 across x 560→636, turning the step into ~76 px of
shoaling. Ramp y stops at 860 where the pre-existing south conform rect
begins — the first cut (y1=960) restored raw panel water over the already-
uniform south sea as a visible column and was rejected in review; the
corrected version leaves the south sea byte-comparable to before.

**Review:** before/after ×3 crops of the bay (520,460,200,300), the strand
(520,760,200,220) and the NE corner (880,0,144,170). The waterline is gone —
the bay grades bright→deep with speckle that reads as water sparkle; the
corner is one sea; no new edges. Pre-existing residual logged (not
introduced here): a pale sand block with a straight left edge at
~(638–686, 810–857) inside the strand band.

### R1 — NE Pack-Ice Corridor — in production

**Problem (D2 + top-right junctions):** two ice dialects butt at a straight
vertical seam x≈755 (soft floes on pale teal west vs fine crackle-pack on
darker teal east); a truncated black shape at (725–770, 215–250) reads as a
deleted paste; a flat mint strip and mint-tinted floes (~620–760); the
top-right pale sheet meets the field in straight junctions.

**Geographic intent:** one climatic gradient — shelf ice west breaking into
drifting floes, brash, then open cold sea south-east; the black wedge
becomes a small snow-capped volcanic skerry (Cinder Skerries family); no
straight boundary anywhere.

**Protected:** volcano cape + watchtowers (mask carved to 20 px standoffs),
Cinder Skerries and the pale iceberg (outside the mask), White Reach label
ground (west of the mask), Frostmere basin (far outside).

**Method:** `inpaint_image` over crop (560,0) 464×320 of the live composite;
custom irregular mask (`tools/prep_r1.js`): left edge x=608, bottom
258/253/245 with standoff carves, east boundary a diagonal (760,258)→(910,70)
+14 px seaward following the existing ragged ice edge, top strip y<90 to the
canvas edge; 51.8 % of the crop. Seed 601. Job
`990e11d6-cbdb-4dda-803c-cd621965e7d4`, ~40 generations.

**Verdict: ACCEPT (desk), first roll.** The dialect seam is gone — one
crackle-shelf language with dark meltwater cracks across the whole field,
breaking raggedly east into floes → brash → open sea; the truncated black
wedge is removed; the top-right pale-sheet junctions are dissolved into
floe scatter; skerries, iceberg, watchtowers and cape byte-preserved (the
landmark-registry guard proves it). Integrated as manifest region `r1_ice`
(salt 8) blitted post-legacy-layers, pre-conform; goldens extracted;
packaging green. Inspection set: context ×2, left-edge strip ×3, bottom
strip ×3, phone-FOV 197×350 ×2, full survey — no rectangle, no straight
boundary at any perimeter. P2 residuals logged: a faint mint remnant west
of the mask (560–615 × 0–95, reads as meltwater-stained floes beside White
Reach's teal pools); a mild plate-vs-floe texture-density shift at the
mask's west edge that reads as shelf structure. Device confirmation remains
the owner's checklist item.

**Budget after R1:** 205 → 165 (billed exactly the planned worst case 40).

### R2 — West Verge / the forest wall — in production

**Problem (D4, south half):** the interior forest's west edge runs as a
straight density/saturation wall down x≈256 from y≈545 to ~830 — the master
boundary showing as art — and a half-ghost snowy peak at (205–280, 585–690)
is sliced by it (summit painted, west face smeared, east flank overpainted
by canopy). WAR01's `west_join` already authored the 360–584 band; this
region owns 576–808.

**Geographic intent:** the canopy thins westward into forest fingers,
groves, scattered trees and clearings over a wandering gradient; the ghost
peak resolved as one finished rocky outlier with foothills; no straight
boundary.

**Protected:** west caravan road band (golden, mask starts at y=576 below
it), WAR01 south strand (golden from y=810 — mask ends at 808 in canopy and
the accepted strand top provides the lower transition), fire3/rustle
overlay boxes and Wolfwood label (east of the mask), A-4 rim band at
x 256–276 (mask feathers in, never the core).

**Method:** `inpaint_image` over crop (152,528) 184×328; rect mask
x 200–272 × y 576–808 (`tools/prep_r2.js`), 27.7 % of the crop. Seed 602.
Job `52930f0c-9dc8-4a82-9c85-fe2318b50f1d`.

**Verdict: ACCEPT (desk), first roll.** The ghost peak is a complete
finished outlier with rock faces, snow summit and conifer foothills; the
gray smears are gone; the canopy edge wanders with bays and promontories,
stepping-stone groves and lone trees grading into the meadow. In the
before/after phone-FOV pair (170,520 197×350 ×2) the wall read is broken —
what remains of vertical alignment reads as a forest edge. Integrated as
manifest region `r2_verge` (salt 9); guards green (road-band and strand
goldens byte-held). Residuals logged, all pre-existing and out of this
region's scope: the wall segment y 495–576 inside the protected caravan
road band (softened by WAR01's west_join scatter), the y 300–360 segment
(deferred Zone 5), and the canopy banding at (267–330, 750–800) which is
master-core content the A-4 guard freezes.

### R3 — SW Sketchlands — in production

**Problem (D5):** the bottom-left corner is uncolored line-art — black
outline hills and pen-stroke pines on flat green with halftone dither —
meeting finished paint along a dithered vertical at x≈118. It reads as an
unpainted layer of the file. Source review narrowed the true defect to
y ≥ ~848: the plain and rock ledges of 690–845 are finished art and stay.

**Geographic intent:** the Worldspine's southern spur steps down as painted
gray ledges and rocky foothills into mossy plain, scrub and conifer groves,
meeting the sandy beach and surf arc that curves around the SW corner,
continuous with the painted coast east of x≈128.

**Protected:** WAR01 south strand golden (x ≥ 128 — mask x1=126), the
Zone-1 coastline hand-off (130–260, 960–1024) outside the mask, ring-2
valley road band far above.

**Method:** `inpaint_image` over crop (0,720) 200×304; rect mask x 0–126 ×
y 848–1024 (canvas edges at left/bottom), 36.5 % of the crop
(`tools/prep_r3.js`). Seed 603. Job
`03c3cabe-04a7-4f1c-b8e7-8d55e06da6e4`, ~25 generations.

**Verdict: REWORK → ACCEPT.** The primary roll replaced all line-art with
painted plain, boulders, stepped ledges, conifer groves and a finished SW
beach/surf arc — but review found the pre-existing checker-dither column
(x≈122–132, the old sketch/paint blend) surviving just east of the mask,
reading as a vertical speckle line through plain, forest and surf.
**R3b correction:** `inpaint_image` crop (72,800) 112×224, mask x 116–138 ×
y 848–1024 (`tools/prep_r3b.js`), seed 604, job
`82887e67-c143-4ac6-b27a-ae8ff7871b95`, ~20 generations. The band's
128–138 × 848–870 sliver lies inside the south_strand_w golden — that
sliver contained the checker defect itself, and was deliberately
re-authorized by `tools/reauthorize_strand_w.js` (220 px copied from the
reviewed R3b generation through R3b's own mask; the golden's diff is the
authorization trail). Both integrated (regions `r3_sketch` salt 10,
`r3b_band` salt 11); guards green; the boundary strip at ×4 and phone-FOV
show one continuous painting — no checker, no straight boundary.

### R4 — SE surf cut (D6) — ACCEPT

**Problem:** the shoreline terminated against a razor-straight vertical at
x=512 (y ~908–960) — the beach arc and its surf chopped flat against open
sea, with a checker-dither patch at (483–517, 883–907).

**Method:** `inpaint_image` crop (420,820) 192×204, mask x 468–564 ×
y 874–1024 (both strand goldens end at 870; mask starts 874)
(`tools/prep_r4.js`). Seed 605. Job
`d96e37cf-5a06-47a5-ad57-c2671f0ca037`, ~20 generations.

**Verdict: ACCEPT (desk), first roll.** One continuous shoreline arc now
sweeps from the lower-left surf up through the old cut to join the strand's
beach — green coastal plain with scrub inside the curve, one sea outside;
the checker patch is gone. Integrated as region `r4_coast` (salt 12);
guards green; phone-FOV (420,760 197×264 ×2) shows silt flats → strand →
coast as one geography.

### R5 — NW crackle-ice paste rectangle (D3) — in production

**Problem:** the `d2b_floe` edge-fix's own footprint: a fine-crackle ice
block with a straight vertical left edge at x≈239 (y ~205–270) against
smooth snowfield, and the nunatak row (250–360, 130–165) sitting on its
shelf, west end fading oddly.

**Method:** `inpaint_image` crop (166,78) 254×222; stepped mask x 214–372,
y 126–252 (top drops to 158 east of x=340 to keep the teal melt-pond;
bottom 252 keeps the Frostmere north-wall golden at 256+)
(`tools/prep_r5.js`). Seed 606. Job
`45982efd-9ac9-4f43-a859-77638e9a827c`, ~20 generations.

**Roll 1: REJECTED.** The generation deleted most of the nunatak row
instead of completing it, invented a new melt-lake joining the pond, and
left red pixel flecks at the pond rim — three of the brief's rejection
criteria at once. Preserved as `rejected/r5_nwice_roll1_f0.png`.

**Roll 2 (narrowed):** the actual P0 is the straight edge *below* the row
(y 205–270), so the retry freezes the mountains and pond entirely — crop
(166,124) 230×176, rect mask x 214–348 × y 172–252, plain-icefield-only
prompt. Seed 616. Job `267bd852-c302-4133-b04d-2f72004bb81c`,
~20 generations. This is the region's second and final roll (M-12's
two-failure stop applies).

**Roll 2 verdict: ACCEPT (desk).** The straight edge below the row is
dissolved into a continuous plate-to-crackle gradient; the nunatak row,
melt-pond and treeline are untouched (frozen). Integrated as region
`r5_nwice` (salt 13); guards green. A short remnant of the old edge above
the mask (x≈240, y 141–172) is broken visually by the mountain silhouette —
logged P2.

**Red-fleck despeckle (0 generations):** eleven pre-existing bright-red
artifact pixels on the nunatak row and pond rim (281–406 × 128–153, older
generation debris) removed by a deterministic scoped despeckle in
package-art.js (each replaced with the pixel two rows below, the flotsam
pattern; nothing legitimate is red west of the volcano).

### Round closure — generation phase

**Budget:** 205 → **45** (160 spent: R1 40, R2 20, R3 25, R3b 20, R4 20,
R5 roll1 20 rejected, R5 roll2 ~20; estimates vs. billing differ by 5 in
the round's favor). The 25-generation reserve stands untouched for one
owner-confirmed device defect; the 20 above it is deliberately not spent —
the remaining defects are P1/P2 and "do not chase perfection" applies.

**All six phone-scale P0s resolved:** D1 (deterministic shoal ramp), D2
(R1), D3 (R5), D4 south half (R2), D5 (R3+R3b), D6 (R4). D8 resolved
deterministically alongside D1.

**Residual ledger (deferred to the 2026-09-16 reset or later rounds):**
- P1: D7 floe-dialect corner at (510, 27) near the world's top edge.
- P2: mint remnant west of R1's mask (560–615 × 0–95); R1 plate-vs-floe
  texture shift at its west edge; R5's short remnant edge (240, 141–172);
  the forest-wall segments y 300–360 and 495–576 (Zone 5 / protected road
  band); canopy banding (267–330 × 750–800, A-4-frozen master core); the
  treeline confetti band (Zone 5); the pale sand block at (638–686,
  810–857) inside the strand; the south lime-palette latitude break at
  y≈810 (Zone 1 harmonization, exceeds 512² and conflicts with the
  protected strand); Wayfarer's painted col; the Glasslake/Frostmere
  naming question (World Designer).

**Verification:** `package-art.js --check` clean (843 files, atlas
byte-reproducible from tracked sources including all five regions, masks,
manifest, registry and goldens); `flutter analyze` clean; atlas layout +
scene tests green (56); full app suite **802/802**; World goldens
**unchanged and passing** — every region lies outside the default
viewport, so `phase1_world*.png` needed no regeneration. Review set in
`review/` (surveys, five region before/after pairs, phone-FOV crops, nine
perimeter strips, protected overlay).

### ATLAS-H — independent final art-director review

Verdict: **"Yes — install."** Independent per-pixel landmark diff (its own
tooling, not the shipped guards): Frostmere basin 0/20,618 px changed,
caravan road 0/10,240, settlements 0; every changed pixel outside the five
regions is a water recolor. All five worst boundary reads eliminated; no
P0 findings; "a genuine remaster, not a cover-up — 11.9 % of the atlas
changed, 0 pixels of landmark drift."

Two P1 findings, dispositioned:
- **F1 — R3's own mask top shipped as a straight tone step at y=848
  (x 0–137)** with a clipped boulder and hybrid trees. A repair's own
  perimeter is never shipped (owner directive, M-14) — corrected by
  **R3c** (below) with the round's last usable generations.
- **F2 — R5 residual panel edge (x≈239, y 128–178)**: pre-existing
  content above R5's narrowed roll-2 mask (the un-repainted remnant
  already logged P2 at R5 acceptance; H rates it P1 at phone FOV).
  Deferred: the 25-gen reserve remains available if the owner confirms it
  on device; otherwise it heads the reset-cycle list with D7.

P2 findings F3–F8 (R2 speckle fringe, the softened x=636 ramp limit, R5
honeycomb density, NW treeline pepper line, the pre-existing green
confetti over the ice cliff at (720–770, 245–290) — flagged as the north's
ugliest remaining patch and recommended as the next repair-loop target —
and older ghost rows/plain seams) join the residual ledger unchanged.

**Honest water-footprint note (H's process finding):** joining the bay and
NE-corner strips to the single global ocean transform shifted the shared
conform statistics, so sparkle/tone pixels re-snapped across the *entire*
eastern sea, including ~10 water-only px inside the protected strand box
(water is exempt from the goldens by design, exactly for this). The visual
effect is a benign sparkle unification; recorded here so the manifest's
scope statement is not read as the full byte footprint.

### R3c — SW top-edge correction (ATLAS-H F1)

`inpaint_image` crop (0,780) 176×156, mask x 0–126 × y 828–888
(`tools/prep_r3c.js`), seed 607, job
`7278ae61-a3c8-456b-a6fd-a08a7d99a49f`, ~20 generations — the round's
last generation; the 25 reserve is not touched.

**Verdict: ACCEPT (desk), first roll.** The straight tone step is gone —
the olive plain flows continuously across the old line; the boulder
cluster sits whole and shaded; the hybrid trees are replaced with
single-style trees. Integrated as region `r3c_topedge` (salt 14); guards
green; `--check` clean; review set regenerated.

**FINAL BUDGET: 205 → 25.** 180 spent across seven accepted generations
and one recorded rejection; the reserve is exactly intact. Generation is
closed for this round.
