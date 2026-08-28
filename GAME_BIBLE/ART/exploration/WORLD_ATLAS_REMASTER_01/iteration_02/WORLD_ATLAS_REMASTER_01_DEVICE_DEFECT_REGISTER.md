# WORLD ATLAS REMASTER 01 — Iteration 02 — Device Defect Register

**Date:** 2026-08-28 · **Branch:** `world-atlas-remaster-01` · **Baseline HEAD:** `6375851`
**Authority:** seven physical-iPhone screenshots taken by the owner 2026-08-26 23:30–23:32,
copied verbatim to `iteration_02/device_screens/owner_01..07_*.png`. The screenshots
supersede all prior desk verdicts. Green/red thin rectangles in five screenshots are
**owner markup annotations** (no debug overlay exists in `lib/` — verified by source grep),
i.e. the owner pointed at specific areas; those areas are treated as owner-confirmed.

Mapping method: each screenshot matched to a nearest-neighbour crop of the shipped
`assets/art/v1/world/atlas_base.png` (`iteration_02/maps/*.png`); coordinates below are
1024² atlas px. Independent screenshot-by-screenshot audit by ATLAS-I (Visual QA);
native-resolution verification crops rendered for every suspect rectangle.

**PixelLab balance at audit time: 25 generations (queried, `get_balance`), $0.00 credits,
reset 2026-09-16.** 25 is exactly the round's untouchable reserve; one inpaint call bills
~20–40. Any single generation therefore consumes the entire correction capacity.

Severity: **P0** world-illusion blocker · **P1** strong distraction · **P2** cosmetic.
Treatment: **DET** deterministic (0 generations) · **GEN** authored PixelLab repaint ·
**OWNER** blocked on an owner decision (A-4 core or golden re-authorization).

---

## Screenshot index

| Shot | Area (atlas) | Owner markup | Contents |
|---|---|---|---|
| owner_01 | ~(0–420, 560–1024) SW quadrant | green box, top-right (farm/forest join) | forest wall south run, SW dark block, latitude break, south beach |
| owner_02 | ~(380–780, 680–1024) south delta/strand | green line, top edge | delta → silt → strand → lime plain → sea |
| owner_03 | ~(620–1024, 800–1024) SE open sea | none | cape tip, open sea |
| owner_04 | ~(740–1024, 460–820) east archipelago | 2 green vertical lines, left edge (occludes peninsula coast) | islands, peninsula edge |
| owner_05 | ~(700–1024, 0–320) NE ice front | green box, bottom-left (volcano cape junction / green confetti) | shelf → floes → sea, skerries |
| owner_06 | ~(40–340, 230–470) Worldspine NW | green box, right (Longwood wall) | mountain chain, conifer mass |
| owner_07 | ~(220–540, 120–420) north icefield | green + red boxes, bottom (treeline band) | icefield, treeline conifer band |

---

## Defect register (severity order)

| ID | Shots | Atlas (x, y) | Symptom at phone FOV | Provenance / source layer | Protected content nearby | Treatment | Gen? | Sev |
|---|---|---|---|---|---|---|---|---|
| D-01 | 06, 01 | x 250–268 × y 260–780 (one column; incl. ledger segments y 300–360, 495–576; plus pale scar x 260–272 × y 390–450) | **The forest wall**: dense conifer/canopy mass ends on a razor vertical against open plain; full density → zero in one column. The single strongest "two paintings touching" read. | Master-core west face (A-4 frozen at x ≥ 276) showing through the too-thin writable shoulder; R2 fixed only y 576–808. | A-4 core face; roadjoin golden (216–276 × 480–558); caravan-road golden (128–256 × 495–575); rim band x 256–276; bear2 far east (≥72 px) | Belts A1/B2 (ATLAS-J): DET sprite-stamp taper on open meadow x 200–256 now; GEN bays into standing canopy face x 245–276 post-reset; road-band segment OWNER (golden re-auth) | partial | **P0** |
| D-02 | 01, 02 | y 810–870 × x 0–560 (break centered y≈850) | **Latitude layer-cake**: olive sward / straight inland sand strip / bright lime plain stacked in three horizontal bands across the whole south. | Zone-1 harmonization deferral (pre-existing); strand adoptions froze the sand strip. | South-strand goldens (128–800 × 810–870); R3/R3c/R4 accepted content | The value cliff is worst where dark canopy meets lime (see D-12); ATLAS-J: ladder mid-rungs bridge the chroma. Full harmonization GEN post-reset + OWNER (strand golden conflicts) | yes | **P0** |
| D-12 | 01 | x 110–280 × y 855–968 | **SW dark forest slab**: near-black canopy block, straight top edge y≈860, abrupt east edge x≈280, sitting directly on brightest lime ground — worst value cliff in the atlas. Ghost half-dithered trees on east edge (245–275 × 885–955). | Old master content south of the core; R3 authored only x ≤ 126. | Strand_w golden covers block top (y 855–870); R3/R3c accepted west | Belts C1/C2/C5: DET lime-substrate sprite-stamp fringes (x 280–330 E, y 940–1005 S, x 100–140 W) now; GEN bays + ghost-tree replacement (x 238–285) post-reset; interior glades OWNER | partial | **P0**→P1 after fringes |
| D-04 | 01 | x 250–350 × y 750–805 | Canopy south cut onto sand belt: hard scalloped boundary with tone step; rust-red dotted trail specks (295–355, 795–805). | Master-core canopy banding (267–330 × 750–800 is A-4-frozen) + route-dot debris. | A-4 core to y 748… (banding partly in core); flock overlay (456–520 × 730–770) far east | Red-dot despeckle DET (outside core); banding OWNER (A-4) or GEN below y 748 post-reset | partial | P1 |
| D-05 | 02, 03 | x 620–780 × y 800–870 | **SE cape staircase**: pale sand slab w/ straight right edge x≈683; straight internal sand top edge y≈836; razor L-cut at x≈748/y≈844 into flat sea. | Slab+edge: accepted strand_e adoption content. **The L-cut is self-inflicted: the ghost-sail flotsam fill rect (748–796, 844–906) offset-copied open sea over the generated beach corner.** | Strand_e golden (512–800 × 810–870) — the damaged state is IN the golden | Fill-predicate fix DET (skip warm-sand pixels; restores pre-fill beach corner) + golden re-extraction (R3b-precedent authorization trail). Slab/terrace edges GEN post-reset | partial | P1 |
| D-03 | 05 | x 865–1024 × y 0–110 | Pale rectangular panel read in floe field. | **Native-verified clean** (`ne_panel_x3.png`): organic floes; the read is minification banding of fine floe texture at far zoom. | Cinder Skerries, Far Isles (FC) | GEN post-reset only if re-shot confirms: coarsen floe scale near the front so it survives minification. No source defect to fix now | no | P1→P2 |
| D-06 | 07, 06 | x 257–374 × y 257–272 | **Treeline confetti** (owner red box): 74 isolated 1–2 px dark flecks hovering on snow above the canopy — verified isolated (≥5 pale neighbours each). | Old generation debris above the conifer band. | Entirely inside writable rim band; Frostmere north-wall golden starts x 400 (clear); yeti2 far east | **DET despeckle** (red-fleck pattern) + DET straggler-pine stamps (belt B1) | no | P1 |
| D-07 | 07 | x 220–242 × y 120–180 | R5 remnant panel: darker strip with miniature mountains, straight right edge x≈240, bottom y≈178 (ATLAS-H F2). | Pre-existing content above R5 roll-2's narrowed mask. | R5 accepted region below; NW glacier vignette west | GEN post-reset (headed reset list with D7-floe already) | yes | P1 |
| D-08 | 07 | x 435–530 × y 205–270 | Ghost mountain: low-contrast painterly smudge amid crisp pixel peaks — reads as a stain. | Old master content, style mismatch. | Frostmere cirque golden south (400–560 × 256–276); Frozen Shelf label | GEN post-reset (small crop, freeze cirque golden edge) | yes | P1 |
| D-09 | 02 | x 380–660 × y 755–775 | Marsh→silt join: vivid green/blue marsh sits on gray silt along a contour with no interleaving. | Master delta belt (partly in core: x ≤ 748 y ≤ 748 core ends at 748 — this is y > 748, outside; x 380–660 writable) | Delta HF (520–690 × 595–748); flock overlay (456–520 × 730–770) golden sliver y 748–770 | GEN post-reset (wetland interleave belt); flock box standoff | yes | P1 |
| D-10 | 05 | x 952–970 × y 265–282 | Hollow atoll ring: tan ellipse outline, sea-colour interior — reads unfinished. | Far Isles family (FC). | Far Isles FC (940–995 × 205–285) | GEN post-reset (fill as sand cay or remove); FC = improve under review | yes | P1 |
| D-11 | 05 | x 795–815 × y 0–150 | Vertical texture seam: floe cells left, smoother wash right, near-straight. | R1 interior texture-density change (logged P2 at acceptance, promoted by device). | White Reach label west | GEN post-reset (floe-scale blend pass over the front) | yes | P1 |
| D-14 | 05 | x 705–761 × y 235–303 | Green confetti smear over ice cliff w/ drip trails (owner green box; ATLAS-H "north's ugliest patch"). 870 greenish px measured: 639 outside PROT, 231 in east rim band, **0 core-frozen**. | Old generation debris over the cliff. | Registry `volcano_east_cliff` golden is **752–824 × 260–470** (the 752–820×272–436 figure is the WAR01 adoption band, not the golden — ATLAS-L): clip to x < 752 for y ≥ 260; **exclude `east_watchtower_flank` golden 744–751 × 273–322**; defensively skip protDepth > 20 | **DET cleanup** (nearest-ice fill, scoped rect, neighborhood-tested) | no | P1 (owner-marked) |
| D-13 | 01 | x 370–420 × y 590–675 | Farm/forest hard join: gold fields butt dark canopy, zero hedge. | Amberfield HF + master core — fully frozen. | Amberfield HF; A-4 core | **OWNER only** (A-4 semantics); log, do not touch | no | P2 |
| D-15 | 03 | x 741–748 × y 820–855 | White streak / orphan surf column below cape — sits WEST of the fill rect (x0=748), so the D-05 predicate fix alone does not reach it (ATLAS-L). | Adjacent to the ghost-sail fill clip; strand_e content. | Strand_e golden | Own item: treat with D-05 only if the treated area is explicitly extended west (same-commit golden re-extraction covers it); otherwise re-log unresolved | no | P2 |
| D-16 | 05, 04 | x 760–900 × y 60–200 | Floe speckle → gray static at far zoom. | Minification of fine texture (native clean). | — | Accept / GEN floe-coarsening post-reset with D-11 | no | P2 |
| D-17 | 06 | x 270–340 × y 260–350 | Conifer sprite corduroy (aligned identical columns). | Master canopy, mostly A-4 core (x ≥ 276, y ≥ 276). | A-4 core | OWNER (core) / accept | no | P2 |
| D-18 | 06 | x 40–75 × y 270–320 | Flat olive band abutting glacier at hard edge. | Master NW filler. | NW glacier vignette | GEN post-reset (small) | yes | P2 |
| D-19 | 02 | x 620–720 × y 745–770 | Rust/brown speckle band at marsh/sea meeting. | Master delta belt edge. | Saltreach headland HF south | GEN post-reset with D-09 | yes | P2 |
| D-20 | 04 | x 740–775 × y 720–765 | Teal pixel spray on big island west shore. | Island edge sparkle debris. | Island land registry-held (Wanderer's) — spray is on shore/water | DET despeckle candidate (verify px classes first) | no | P2 |
| D-21 | 04 | islands (800–860, 490–535) | Twin kidney-silhouette islands read copy-pasted; 1 px sand outlines alias to dashes. | Master archipelago. | Wanderer's Isles goldens | Accept this round; GEN variation post-reset if owner flags | no | P2 |
| D-22 | 07 | (230–320, 180–260); (220–265, 380–420) | Ice crack-cell density boundary; green pocket ends near-straight against snow. | R5/master junction; minification-amplified. | R5 region; NW vignette | Accept / fold into post-reset north pass | no | P2 |
| D-23 | 03 | ≈(800, 895), (930, 895) | Two identical wave-mark clusters at same latitude. | Sparkle tiling in conform. | — | DET candidate (re-seed sparkle in those cells) / accept | no | P2 |
| D-24 | 01 | x 10–90 × y 690–780 | Boulder confetti on plain below NW mountains. | Master filler scatter. | Ring-2 valley road (0–128 × 495–580) far north | Accept; GEN foothill pass post-reset (Zone 6 family) | no | P2 |

**Not exposed by this set (neither confirmed nor cleared):** mint remnant (560–615, 0–95);
D7 floe corner (510, 27). owner_04's peninsula left edge is occluded by owner markup —
needs a clean re-shot before judging.

## ATLAS-K hydrology/coast addenda (measured)

- **D-25 (new, P1, feeds D-02/D-09):** the delta's western braids die in dry sand —
  zero water columns cross the strand at y=838 for x 360–640; channels fan west and
  stop mid-flat. Treatment: **S3/S4 "Delta apron" GEN post-reset** (~20): mask
  x 380–670 × y 748–806, top carved to y 774 under the flock sliver, braids redrawn
  converging east to the trunk; replaces the D-19 red speckle with clumped reed
  margins. No golden conflict (stays above y 810).
- **D-26 (new, P1, the NE "constructed" read root):** a 30-point luminance
  ice-character field split at R1's west boundary — interior shelf (460–550 × 40–140)
  mean [174,215,224] ponded-gray vs R1 shelf (640–740 × 40–140) mean [210,235,244]
  clean-white; no single-column step >10 exists, so no seam metric sees it.
  Treatment: **R6 "North Shelf Join" GEN post-reset** (~25–35): crop ≈(480,0) 200×280,
  mask ≈x 520–660 × y 0–250; also resolves D7 floe corner + mint remnant; prompt the
  front's outer band toward fewer, larger plates (≥10–14 px) so shapes survive
  minification (covers D-11/D-16).
- **D-05 refinement:** the pale sand block is structurally fine (own dune tufts) —
  only its temperature is foreign. **Deterministic 1:1 shade-ramp conform** of its 4–6
  sand shades onto the cream ramp (638–686 × 810–857), structure-preserving, A-2.
  Entirely inside strand_e golden → golden re-extraction, owner sign-off flagged.
- **Lime identity question:** whether the world keeps a distinct bright coastal band
  is a world-design decision — UNRESOLVED, escalated (G-3); belt treatments preserve
  lime identity and fix only its edges until the owner rules.

---

## Register summary

- **P0 families:** the west/center forest wall column (D-01), the south latitude
  layer-cake (D-02), the SW dark slab on lime (D-12). All three are exactly the owner's
  "dense tile-like biome block → abrupt edge" complaint.
- **Owner-marked boxes resolve to:** farm/forest join (D-13, core-frozen), Longwood wall
  (D-01), treeline band (D-06 + D-01 north), green cliff confetti (D-14), strand/delta
  band (D-02/D-09), peninsula edge (occluded, unresolved).
- **Deterministic-now set (0 generations):** D-06 despeckle + B1 straggler stamps,
  D-14 cliff cleanup, D-04 red-dot despeckle, D-05/D-15 ghost-sail fill predicate fix
  (+ golden re-extraction), density-ladder stamp fringes for D-01 (meadow side) and
  D-12 (east/south/west fringes), D-20/D-23 if pixel classes verify.
- **Authored-repaint set (post-reset 2026-09-16):** D-01 canopy-face bays, D-02
  harmonization, D-12 canopy bays + ghost trees, D-07, D-08, D-09/D-19, D-10, D-11/D-16
  floe coarsening, D-18; plus carried D7-floe and mint remnant.
- **Owner decisions needed:** A-4 exceptions for in-core defects (D-13 farm join, D-17
  corduroy, D-04 banding, Longwood interior); strand-golden re-extractions beyond the
  D-05 fill fix; C4 interior glades in the SW block.
