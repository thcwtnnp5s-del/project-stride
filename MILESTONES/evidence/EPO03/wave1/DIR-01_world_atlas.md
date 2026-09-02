# DIR-01 — World Atlas Creative Director (EPO03 Wave 1)

2026-09-02 · 0 generations · sources: BRIEF_CONTEXT §2, D0033, GOV-04 (FMPO02;
GOV-03 absent), ATLAS_REGION_LOG, ART-03 · looked at `atlas_base.png`, all
`zone_*`/`grid_*` crops, `head_x1.png` · anchors = `atlas_layout.json` ÷ 6.

## TOP FAILURES (phone-visible, ranked)

1. **South strand y 810–870** — ruler stripe sand→lime→sea, 650 px; the delta
   dies on it. P0, golden-held.
2. **Forest west wall x≈256, y 380–580** — canopy ends on a vertical, one pan
   west of Haven's Rest.
3. **Ice→volcano butt y≈280** and the **shelf front** — cyan hairline on
   black rock; hard white diagonal 700→860.
4. **NW snowline y≈264–270, x 0–210** — horizontal above the terraces (log:
   NOT FIXED). Producer missed it.
5. **SW corner** — vertical turquoise shore, lime slab, blue-blob orchard
   300–460 × 870–1020.

## GEOGRAPHIC STORY

The Worldspine walls the west. Snow is the north, one sheet from the White
Reach to the Frozen Shelf, calving into the eastern sea where Emberhold's heat
keeps Rimewatch's cape open. Two rivers: the great one rises in Frostmere's
cirque, drops through the Stonefall gap, passes Millbridge and fans into the
Amberfield delta — the map's sink, met by the sea at the Ferry Crossing; its
channels must braid on into tidal flats, creeks and a curved shore before the
Sunward Strand. The lesser rises in the NW snow, cuts the terraces, today dies
in the meadow; it becomes the beck the pass road follows to the SW shore.
Haven's Rest is the hub; the caravan road leaves the wood's west bays and
switchbacks to Wayfarer's Pass, the only way through the spine; the mine road
climbs into the cirque. N→S: snow → Longwood → Whispering Woods → plain and
wheat → marsh → flats → strand → sea. W→E: spine → foothill meadow → downs →
gloaming wood → west shore. Worst on the phone: strand stripe, forest wall,
ice–volcano butt.

## WHAT TO REPLACE

| Zone (atlas px) | Producer | Director | Reason |
|---|---|---|---|
| South band 0–800 × 780–1024 | FULL | **FULL, widened 0–860 × 700–1024** | the whole apron→shore stack fails; the delta braids into flats inside the core's bottom band (D0033 §2); the spit's flat shore is the same band |
| SW corner 0–260 × 760–1024 | FULL | **FULL, merged** | one coast, one hand; S1 wood hosts the storm pocket |
| NE shelf 480–800 × 0–300 | RECOMPOSE edge | **RECOMPOSE 680–860 × 0–300 only** | the teal leads are the north's best painting; only the front fails |
| Volcano north face 600–760 × 250–310 | missed | **RECOMPOSE** | ice meets rock on a hairline; ash snow, steam, melt pool; towers frozen |
| West road loop 0–260 × 460–630 | RECOMPOSE | **confirm** | the road has no reason; climb to Wayfarer's Pass along a beck |
| Far-west wall 0–70 × 540–780 | RECOMPOSE | **RECOMPOSE 0–120 × 520–700** | slab is 120 wide; pasted peak (210,590) joins the foothills; below 700 is SOUTH's |
| Core forest west face 236–320 × 380–580 | RECOMPOSE core | **confirm** | bays and copses; forest stays at Greenwatch, Whispering Woods, Deepwood Shrine |
| NW snowline 0–256 × 236–300 | missed | **RECOMPOSE** | the log's unfixed ruler line; melt tongues, a moraine |

## WHAT TO KEEP

Core interior; N1, N2, N3 interior; W1, W2, W3 (scree retouch only); volcano
and every island golden; east sea (LIFE populates, no acreage). **Core
treeline 256–400 × 230–290 downgraded to RETOUCH** — a diagonal band, not a
line, outside the opening FOV.

**Shared-edge rule.** The heavier verdict paints the edge (FULL > RECOMPOSE >
RETOUCH > KEEP; ties to the crop containing it), goes *second* against the
neighbour's accepted composite, then hands over the accepted ±40 px crop,
which the neighbour freezes.

## PRODUCTION FAMILY

Every region: `inpaint_image`, ≤512² crop of the current composite, graded
jittered mask (`tools/atlas-mask.js`), dither-SELECT, single-defect loop;
style source the core master (`atlas_59c4723_1024.png`).

| Territory | Rect | Owns (verdict) | Regions (crop, est. cost) | Edges: paints → hands to | Anchors — do not move | To LANDMARKS | Cap |
|---|---|---|---|---|---|---|---|
| **PROD-WORLD-NORTH** | 0–600 × 0–300 | N1, N2, N3-west (KEEP); treeline (RETOUCH); NW snowline (RECOMPOSE) | R-N1 snowline 0–256 × 228–300 (256×72, 25 ×2); R-N2 treeline 256–400 × 226–290 (144×64, 20 ×1.5) | paints y=300 × 0–320 → WEST; x=600 both KEEP, nothing | `frostmere_north_wall` 400–560 × 256–276 byte-exact; basin 403–550 × 282–362; Longwood (316,296); Frozen Shelf (445,176); White Reach (600,60); stormdrake (350,190), snowdrift (330,150), flurry (456,286) | **Ice tower foundation 412–540 × 96–224** — hand over now (N3 is KEEP) | **100** |
| **PROD-WORLD-WEST** | 0–320 × 300–700 | W1, W2 (KEEP); W3 downs (RETOUCH); road loop, far-west wall, core forest face (RECOMPOSE; face is a core re-base, composited before the `approved` snapshot) | R-W1 face 216–320 × 370–590 (104×220, 25 ×2); R-W2 pass road + foothills 0–260 × 440–640 (260×200, 40 ×2, one hand); R-W3 downs/scree 0–200 × 600–700 (25 ×1.5) | paints x=320 vs core (KEEP); receives y=300 from NORTH; accepts R-W2/R-W3 *before* SOUTH paints y=700 | Worldspine (157,333); Lanterngard (66,424); Wayfarer's Pass (187,542) sits on the road at a col; road exits west edge at y≈545; Greenwatch (286,431) forest edge; Deepwood Shrine (304,556) deep wood; Whispering Woods 300–430 × 460–560 stays forest; caravan (225,512), stag (156,493); goldens `roadjoin_corridor_west`, `west_caravan_road`, `caravan_corridor`, `stag_box` re-extracted in R-W2's commit | **Fairy glade 296–392 × 404–500** — after R-W1 accepted | **200** |
| **PROD-WORLD-SOUTH** | 0–860 × 700–1024 | south band, SW corner, delta apron, SE spit shore (FULL); marsh mouth 320–620 × 700–730 (KEEP marsh) | paint east→west: R-S1 apron/flats 340–700 × 700–880; R-S2 spit + cape shore 600–860 × 720–900; R-S3 Sunward shore 400–760 × 840–1024; R-S4 SW strand 160–520 × 780–1024; R-S5 corner/west shore 0–320 × 700–1024 in two crops (six crops, 25–40 ×2) | paints y=700 × 0–320 (after WEST), y=700 × 320–768 vs core marsh, cape water vs EAST → hands WEST, EAST | Sunward Strand (511,860) keeps a beach; Marshlight (508,708), Sunken Rows (406,711) marsh; Reedmouth (606,686) water; Wolfwood (334,686) wood; black gable (786,786) keeps its wood; flock (456,730); goldens `flock_south`, `south_strand_w/e` re-extracted, rects follow the new shore, never emptied | **Storm knoll 168–264 × 816–952** — after R-S5 accepted | **440** |
| **PROD-WORLD-EAST** | 600–1024 × 0–700 | calving front 680–860 × 0–300, volcano north face 600–760 × 250–310 (RECOMPOSE); volcano, skerries, Far Isles, Wanderer's Isles, Tern Isles, Saltreach Light, sea (KEEP) | R-E1 front north 680–880 × 0–160 (25 ×1.5); R-E2 front south + ice/rock/sea tri-join 660–860 × 140–310 (25 ×1.5, towers masked); R-E3 north face 596–700 × 240–310 (20 ×1.5) | freezes x<600 (NORTH's N2); y=700 water, nothing | Rimewatch (639,296), Emberhold (743,288) towers exact; Rimespire prop (824,156) keeps ice under it; `volcano_east_cliff`, `cinder_skerries`, `far_isles`, `ne_iceberg`, `wanderers_isles_w/e` byte-exact; `east_watchtower_flank` masked frozen (re-extract only if touched); redwyrm (700,240), breath (780,300), volcano overlay (668,284) | — | **140** |

Unowned: 860–1024 × 700–1024, open sea, KEEP.

## PIXELLAB BUDGET

Unit (GOV-04): `inpaint_image` 20 at ≤160×300, 25 at ≤300×298, 40 at ≈350²;
512² taken at 40. Re-rolls ×2 on FULL, ×1.5 on RECOMPOSE. **NORTH 100 · WEST
200 · SOUTH 440 · EAST 140 = 880.** LANDMARKS outside this sum: recommend 250
(three sites × ~80). Hard caps — stop and report.

## PHONE-SCALE SUCCESS CRITERIA (197×426 FOV, iPhone final)

- **NORTH** — FOV (128,268): snow ends in tongues with a moraine, no
  horizontal run ≥12 px. FOV (330,260): pines step dense→sparse→single→drift.
  Basin and north-wall golden unchanged.
- **WEST** — FOV (187,542): the road climbs between two shoulders, beck and
  ford beside it, caravan on it, the peak part of a range. FOV (286,431):
  bays and copses, no vertical run ≥12 px; forest unbroken at (383,509),
  (304,556).
- **SOUTH** — FOV (511,860): shore bends ≥30° in view, sand width varies
  ≥2:1, one creek mouth, delta channels run into the flats, no band spans the
  width. FOV (160,900): wood → dune → shore; west shoreline not vertical; no
  lime slab, no blue-blob orchard.
- **EAST** — FOV (780,150): broken front, bergs and brash in the water, no
  diagonal run ≥12 px, ice under the Rimespire. FOV (680,290): rock meets ice
  through ash snow and steam; both towers exactly where they were.
- **All** — no generated rectangle; guards and goldens pass; re-extraction
  diffs are the only authorization trail.
