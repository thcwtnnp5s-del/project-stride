# FINAL-04 — world atlas / environment, adversarial

Judged on pixels: `assets/art/v1/world/atlas_base.png` at ×1 and ×3–×8 crops, the
`review/atlas/*_after_{x2,fov}` pairs, `review/worldlife/ATLAS_PLACEMENT_FINAL_x1.png`,
`out/worldlife/manifest.json`. Measurements are mine; BEFORE = `git show
4d9a81f:assets/art/v1/world/atlas_base.png`. The log is unusually honest and I have not
re-reported what it concedes, except where the shipped pixels contradict its verdict.

1. **BLOCKER — N2 ships airbrushed, the exact criterion roll 1 was rejected on.**
   `atlas_base.png` 300–530 × 0–200 and `N2_after_fov.png`: smooth gradient drifts,
   anti-aliased peaks, no cel bands, no pixel staircase. Roll 2 is recorded as "flat cel
   bands … visible pixel staircases"; it is not. BEFORE at that rect was crisp — bad
   content, right dialect. This is good content in the wrong dialect: criterion 4 / M-12.
   *Fix:* re-roll with a posterisation acceptance gate (distinct values per 32×32 vs N1),
   or value-quantise the accepted generation before compositing.

2. **BLOCKER — 110 px razor vertical at atlas x≈513, y 0–110, two drawing hands either
   side.** 495–540 × 0–130 at ×8: N2's soft painting left, untouched crisp master pack ice
   right. Column x=513 mean L1 = 81.0 vs band median 29.6 (y 0–89). NB2's log calls it "a
   tone step rather than a drawn line … much weaker than the edge below it was" — it is a
   dialect step and the strongest vertical left on the map. BEFORE had no cut here.
   *Fix:* extend NB2 upward to y=0 (its rect stops at 90), or pull N2's mask back to x≈480
   above y=90.

3. **BLOCKER — both hero props are isometric diorama tiles on a top-down map.**
   `prop_fairy_castle` (287–383 × 393–473) and `prop_storm_house` (190–246 × 858–922) in
   `ATLAS_PLACEMENT_FINAL_x1.png`: rhombi with four straight edges and an extruded soil
   side-wall — a plinth — sitting on top-down canopy, their internal trees in side
   elevation. The castle's oaks are ~28 px crowns against the map's ~10 px; the manifest's
   "matches the forest canopy scale" is false. Visible as stickers at ×1 across the map.
   *Fix:* re-author flat, top-down, no ground plate, no side wall, at map canopy scale.

4. **BLOCKER — the world-life placement evidence is stale.** `ATLAS_PLACEMENT_FINAL_x1.png`
   is 00:38; N1/N2 landed 01:13, N3 01:22, NB2 01:31 — its north is the old honeycomb, so
   it is composited on the pre-repaint atlas and no northern placement is verified against
   what ships. Two already fail: `overlay_yeti3` (600–644 × 160–200) straddles N3's open
   teal lead — a snow ape waist-deep in water; `prop_ice_tower` (452–500 × 172–252) stands
   on open slope, its named crag at 452–490 × 154–169 floating above the spire.
   *Fix:* re-composite against HEAD and re-verify all 20 entries before any device pass.

5. **SHOULD-FIX — creature overlays are 3–4× map scale with no ground contact.**
   `overlay_deer2` renders ~38×37 atlas px beside 14 px conifers and 8 px Haven's Rest
   roofs (210–300 × 310–390 at ×6). Same class: wolfpair 56×44, yeti3 44×40, wagon 32×32.
   None casts a shadow; every tree does. *Fix:* halve each canvas, add a 1–2 px contact
   shadow — or declare them markers and treat them consistently as such.

6. **SHOULD-FIX — `overlay_fairy_motes` lands on rock and reads as coins.** Placed at
   378–410 × 420–452, the brown scree east of the glade, not "beside the castle"; renders
   as ~9 evenly spaced gold discs on grey rock, against "bronze not gold, no coins".
   *Fix:* move to ≈360,430 inside the glade; desaturate to honey-green.

7. **SHOULD-FIX — unremoved generation debris in the sea ice.** Sage-green pixels at
   ~709–742 × 171–214; a grey-lavender smudge at ~634–647 × 106–121. Nothing there is
   legitimately green or violet; N1/N3's red debris was despeckled, this was missed.
   *Fix:* `tools/despeckle.js` on both hues over 640–790 × 100–220.

8. **SHOULD-FIX — dither band and inconsistent floe outlines in N3.** Regular
   salt-and-pepper at ~701–742 × 236–259; floes at 690–730 × 184–214 carry a hard
   near-black 1 px contour no other floe has. *Fix:* despeckle; re-key contours to teal.

9. **SHOULD-FIX — the GAP snowline moved, it is not gone.** `H y=271, x=90..161` is a 72 px
   unbroken ruler run (plus `y=270, x=79..131`, 53 px); row 271 scores 143.8 vs a 250–290
   band median of 72.4 — the dominant horizontal in the band N1 claims to have frayed.
   *Fix:* one short inpaint over 60–200 × 255–290, or hand-place drifts across the run.

10. **SHOULD-FIX — two more measured horizontal steps no log mentions.** y≈106 across
    x 504–772 (110.9 vs median 56.2) at N3's top join, where the log says "no horizontal
    ruler line"; and y≈903 across x 277–500 (117 vs median 49), an abrupt brightness step
    above S1/S2's machair, visible at ×3 in 150–500 × 880–928. *Fix:* widen those top
    ramps and re-grade, or record them.

11. **SHOULD-FIX — W1's east join is a vertical content cliff at x≈243 from y≈340 down.**
    BEFORE continuous forest, AFTER pale meadow meeting surviving canopy on a near-vertical
    line (210–300 × 310–390, both). The ramp may wander numerically; meadow-vs-forest is a
    content change, so it reads as an edge. *Fix:* interlock with 2–3 authored tree fingers
    reaching west instead of trusting the ramp.

12. **SHOULD-FIX — the A-4 rim speckle column survives at 256–275.** Isolated-pixel density
    per column over y 300–470: 11–32% inside the rim (peak 32.2% at x=269) vs 2.3–8.2% in
    the core at 276–300. Byte-identical to BEFORE, so `rimBlock` worked and this is not the
    round's damage — but W1's Read claims "no dither column" and at ×5 a 20 px speckle
    stripe runs down the forest wall. *Fix:* none without the owner's core decision; put it
    in front of them now rather than deferring a fourth time.

13. **NOTE — D-22 survives across roughly a third of the north.** The 32×32 change map shows
    0% change east of x≈768 for all y<260. The log prices this deliberately; agreed, but at
    ×1 a half-repainted north reads worse than a uniformly bad one did.
14. **NOTE — N3's west floes are a tessellation.** 485–570 × 100–180: small cells packed
    edge-to-edge with teal grout — the honeycomb the brief forbids. NB2's log concedes they
    are "smaller and more tightly packed". Enlarge and separate.
15. **NOTE — the strand band still layer-cakes at phone FOV.** `S2_after_fov.png`: sand with
    no sea, `H y=827..828 x=131..236` a 103 px straight top edge, one driftwood stamp four
    times along it, ~8 identical blue rosettes at 300–480 × 885–925. The strand-golden
    UNRESOLVED escalation is right and now urgent.
16. **NOTE — repeated stamps sit below the QA tool's reach.** `atlas-qa.js` checks 10×10
    pairs within 40 px and reports 0 everywhere, yet the conifers at 240–370 × 250–310 are
    3 stamps repeated ~30× with no size or value variation, and the soft snow cones at
    455–615 × 220–265 are one shape three times ~60 px apart. Widen to ~120 px / 16×16
    before trusting that 0.

**Verdict: REJECT for device** — the geography is genuinely better and the log is honest,
but N2 ships in the wrong drawing dialect against a 110 px razor seam (1, 2), both hero
props are isometric dioramas on a top-down map (3), and world-life placement was verified
against an atlas that no longer exists (4).
