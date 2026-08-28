# WORLD ATLAS REMASTER 01 — ITERATION 02 THESIS

**Date:** 2026-08-28 · **Branch:** `world-atlas-remaster-01` · **Baseline HEAD:** `6375851`
Written after the five-agent pass (ATLAS-I device critic, ATLAS-J forest/ecotone,
ATLAS-K hydrology/coast, ATLAS-L protection, ATLAS-M budget) and before any pixel change.
Companion: `WORLD_ATLAS_REMASTER_01_DEVICE_DEFECT_REGISTER.md` (the full defect table).

## 1. What defects remain on the physical iPhone?

Three P0 families and eight P1s (register D-01..D-26). The P0s: the west/center
**forest wall column** (x 250–268 × y 260–780 — the A-4 core's west face showing as
art through a too-thin writable shoulder), the **south latitude layer-cake**
(olive / sand strip / lime stacked at y 810–870 across the whole south), and the
**SW dark forest slab** (110–280 × 855–968 — darkest canopy sitting directly on the
brightest ground with zero middle rungs). The owner's markup boxes resolve to: the
Longwood wall, the treeline band, the green cliff confetti, the farm/forest join
(core-frozen), the strand/delta band, and the peninsula edge (occluded by the markup
itself — needs a clean re-shot).

## 2. Which are forest-density problems?

D-01, D-12, D-06, D-17, D-04's canopy cut. Diagnosis (ATLAS-J): the atlas has only
two vegetation states — solid L6/L7 canopy and empty L1 meadow — and every meeting
is a one-pixel cliff. The accepted R2 verge is the one place the full 7-rung ladder
exists; it is the vocabulary source for every fix.

## 3. Which are geography problems?

D-08 (ghost mountain style mismatch), D-18 (flat olive band at the glacier),
D-24 (boulder confetti plain), D-26 (two ice characters split at R1's west
boundary — a 30-point luminance field difference with no findable line), and the
farm/forest join (D-13). The Worldspine↔forest relationship is carried by the
writable L-band around the frozen core; the core interior itself cannot be
re-explained without an owner A-4 decision.

## 4. Which are coastal/hydrology problems?

D-02 (the layer-cake), D-25 (the delta's western braids die in dry sand — zero water
columns cross the strand at y=838 for x 360–640), D-09 (marsh sits on silt with no
interleaving), D-05 (SE cape staircase), D-19 (red speckle band), D-10 (hollow
atoll). ATLAS-K's frame: treat the south as one hydrological system whose braids
must visibly converge to the trunk or continue as tidal creeks to surf.

## 5. Which are still literal seam/perimeter problems?

Far fewer than before — the remaster did kill the old P0 seams. Remaining:
D-07 (R5 remnant panel edge), D-05's L-cut (self-inflicted: the ghost-sail flotsam
fill rect offset-copied sea over the generated beach corner at x=748/y=844),
D-15 (orphan surf column), D-11 (R1 interior texture split). D-03's "rectangle" is
native-verified clean — minification banding, not a source edge.

## 6. What can be fixed without PixelLab?

**Tier 1 (unconditional cleanups, precedented pattern):** D-06 treeline confetti
despeckle; D-14 green-cliff confetti cleanup (with ATLAS-L's corrected golden
clips); D-04 red-dot despeckle; D-05/D-15 ghost-sail fill predicate fix + same-commit
strand_e golden re-extraction (R3b authorization pattern).
**Tier 2 (gated per belt, owner-authorized "composited from existing assets"):**
density-ladder sprite-stamp fringes on open ground only — B1 straggler pines
(248–395 × 236–275), A1 west taper (200–256 × 276–470), C1/C2/C5 SW-slab fringes
(280–330 × 872–968; 120–305 × 940–1005; 100–140 × 870–970). Each belt passes a
phone-FOV anti-repetition desk gate or is reverted whole (ATLAS-M stop condition).
Mandatory mitigations: many distinct harvested sprites, hash-jittered spacing,
mirroring, no grid alignment, same-substrate rule.

## 7. What requires authored repaint?

The canopy-face bays that actually break the wall read (A1-east/B2 into standing
canopy), the SW slab's edge recomposition and ghost-tree replacement, R6 North Shelf
Join (D-26 + D7-floe + mint remnant, with coarser outer plates for minification),
S3/S4 delta apron (D-25/D-19), S1 coastal wood edge, D-07, D-08, D-10, D-18, and the
full south harmonization. Sized by ATLAS-J/K at ~80–150 generations — post-reset work.

## 8. What non-protected art should now be sacrificed?

Under the owner's broadened tolerance: the SW slab's east/south/west edges and ghost
half-trees; the dead-scrub speckle band; the treeline confetti band; the green cliff
smear; the pale-sand slab's foreign temperature; the R5 remnant panel; the ghost
mountain; the flat olive band; the atoll ring. None of it carries landmark identity.

## 9. Which features remain locked?

Bear2 (340–366 × 592–620, double-protected: A-4 core + overlay frame-0 rule; nearest
planned work ≥60 px away), Frostmere/Glasslake basin + north-wall golden, the
volcano massif/watchtowers/east cliff, all settlements, routes and road goldens, the
south strand goldens (except the two documented same-commit re-extractions), island
goldens, hit targets (ATLAS-L verified no belt touches any marker hit area or route
polyline), and the A-4 core generally. In-core defects the owner marked (farm/forest
join, canopy corduroy/banding) are **escalated as owner decisions, not painted**.

## 10. How should the remaining PixelLab budget be used?

**Not at all** (ATLAS-M, Option B). 25 = at most one roll of one small region with
zero reroll capacity; M-12's two-failure discipline cannot operate; a rejected roll
buys nothing and a mediocre roll invites partial adoption — the half-fixed-map
failure. The balance is treated as **zero for generation purposes** this iteration.
Reset 2026-09-16 restores a large allowance; a per-region post-reset plan with
two-roll budgets ships with this iteration (`POST_RESET_GENERATION_PLAN.md`).

## 11. What will be fixed now?

Tier 1 cleanups + Tier 2 gated stamp belts, each through the owner-mandated
single-defect loop (BEFORE → statement → protected content → intent → change →
render native/×2/phone-FOV → perimeter inspection → verdict → next), with
`package-art.js --check`, the protected-interior guard, and the landmark-registry
guard green after every accepted change. D-01/D-12 rows stay marked **stage 1 of 2**
— the meadow-side taper is explicitly not presented as the wall fix.

## 12. What will wait for reset?

Everything in §7, plus D-03/D-16 floe coarsening (only if a clean re-shot still
shows it), D-21 island variation (only if the owner flags it), and the three owner
decisions: A-4 exceptions for in-core defects, strand-golden re-extractions beyond
the two documented here, and the lime-band identity question (ATLAS-K, G-3).

## Priority confirmation

The brief nominated the west/center forest ecotone as leading P0. The agent evidence
confirms it: ATLAS-I's highest-impact single repaint is the Longwood western wall
column (spanning owner_01 + owner_06, with D-06 at its north end), with the south
layer-cake nearly tied. Iteration 02 therefore leads with the treeline/wall family
(D-06 → B1 → A1) before the south (D-04 → D-05 → C-belts), then the NE cleanup (D-14).
