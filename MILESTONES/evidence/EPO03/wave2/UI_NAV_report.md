# PROD-UI-NAV — the kit and the bottom nav (EPO03 Wave 2)

Branch `fable5-executive-production-overhaul-03`. Cap **320**, spent **258**.
Ledger `GAME_BIBLE/ART/exploration/EPO03/ledger/UI_KIT.md`. Contract
`MILESTONES/evidence/EPO03/wave2/KIT_CONTRACT.md`. Requests
`REQUESTS_NAV.md`.

## What shipped

| | Commit |
|---|---|
| **KIT_CONTRACT** — the names, canvases, nine-patch insets and Dart API seven screen teams code against before the art exists | `7dc6a12` |
| **Two requests served** — `assets/art/v1/ui/` (UI-INVENTORY) and `assets/art/v1/track/` (SKILLS), each with the README that makes the directory resolve | `0684b1c` |
| **The kit scaffold** — `KitFrame`/`KitTile`/`KitMark` registries in `panel_skin.dart`; `KitPlate`, `KitPlate.well`, `KitEdge`, `KitOrnament`, `KitRule`, `PageGround` in `surfaces.dart`; `nav_welt_v2` shipped | `d32a01f` |
| **The bottom nav** — leather strap, stamped wells, raised lit plate breaking the welt, the stitch shared with the header, leather into the home-indicator inset | `ade5a62` |
| **`_hi` retired in code** — one glyph per destination; `glyphActive` and the six `PixelIcons.nav*Active` constants gone (Q-26) | `2db6fe6` |
| **The corner radius retired** — `card`/`inner` square, `chip`/`gate` at 2, `tabActive` deprecated | `771930e` |

| **The kit's art** — three pro frames and four remapped rejects, registered | `5b92ef6` |

**Assets: thirteen shipped.** `nav/nav_welt_v2.png` (8 × 6, ×2), drawn by *both* the
nav bar and the header shelf — one chassis, one stitch, layout-neutral — plus
`kit/`: `inset_well` (61², corner 16 / band 15, ×1), `slot_well` (32², 6 / 4,
×2), `stage_frame` (114², **26** / 19, ×1), `rule_journal` (8 × 6 tile,
transparent ground), `rule_chart` (8 × 4), `rail_shelf` (384 × 32 picture rail),
`tab_plate` (48 × 32 ornament). All guard-clean, each with a measured sidecar.

**Renders.** `GAME_BIBLE/ART/exploration/EPO03/review/device/nav/` (all six tabs
+ driven states), `nav_square/` (the same after the radius change).
Judged crops: `review/ui/nav_header_six.png` (header + bar, six tabs),
`nav_six_tabs_x2.png`, `radius_before_after.png`, `welt_run2_x4.png`.

**Tests.** 2,034 PNGs pass the palette guard and 26 strips wrap cleanly at their declared period. `panel_skin_test.dart`, `band_plate_test.dart`, `phase1_ui_test.dart`
— **51 passing**. `flutter analyze lib/ui/` clean.
`check-art-palette.js`: 1,883 PNGs, no teal collision, no semi-transparent
pixel, chrome under the ceiling. `nav-active-variant.js --check` still green.
Goldens **not** regenerated — every tab's chrome changed, so all twelve will
differ; the producer regenerates after inspecting the diff.

## What was rejected, and the correction I had to be sent back for

Twenty-four rolls stand rejected with written reasons. They fail in **one**
direction: asked for flat, plain, tileable chrome, `pixen` draws *a lit object
in perspective, decorated with studs, above the ceiling*. Four prompt
strategies were tried and the two "sheet to cut from" masters came back
**rotated on the diagonal**, so no axis-aligned crop exists.

**I then drew the wrong conclusion from that** — "the frame class is closed" —
and shipped the kit declared and empty. The producer sent it back on two
counts and was right on both:

1. **Over the ceiling is a deterministic remap, not a rejection**, with
   precedent in this repo (VAWO01's `chassis_64` clamp; `keyBorderWhite` in
   the packager). Four candidates I had marked CHECK were failing on
   brightness alone while the drawing was right. All four now ship, for
   **zero generations**. One of them, `tab_plate`, was never over the ceiling
   at all — I had not measured it.
2. **I never changed tool.** All thirty-two rolls were `create_image_pixen`.
   `create_image_pro` takes labelled references; given an accepted grain tile
   as the style and `chassis_64` as the construction reference, it drew clean
   flat hollow nine-patches **in the first call for all three families**, 36
   candidates for 60 generations.

The finding that survives is narrower and correct: **`pixen` cannot draw a flat
hollow frame; pro can.** The rest of the kit is unlanded because it was not
authorised this pass, not because it is impossible.

One defect worth carrying forward: the stage frame's corner is **26, not its
band of 19**, because its iron cap is wider than its band and at 19 the painter
tiles the cap along every beam. No numeric measurement shows this —
`tools/ninepatch-proof.js` renders the patch the way `_FramePainter` will, and
`review/ui/np_stage19.png` beside `np_stage26.png` is the whole argument.

Sheets: `review/ui/frames_x3.png`, `nav_small_x6.png`, `strips_x3.png`,
`sheets_x4.png`, `pro_insetwell_x4.png`, `pro_finalists_x3.png`,
`np_all_x2.png`, `remapped_four.png`.

## What the phone will show that it could not before

- The bar is **leather that reaches the home indicator** — the flat `#201C17`
  rectangle that used to sit under it on every notched device is gone.
- **The same stitch hems the header and the bar.** Two unrelated edges at two
  thicknesses became one piece of leatherwork.
- An inactive tab is a **well stamped into the strap**; the active tab is a
  **plate raised out of it**, lit along its top edge, breaking the welt.
- **Nothing is round.** Every panel, block and well in the product is square
  from `771930e`, including on screens no team has touched yet.

## What did not close

- **Ten kit names still have no art**: `insetStage`, `pageSealed`, `slipPinned`,
  `ribbonLabel`, `peekPlate`, `labelPlate`(`Selected`), `navWell`,
  `navPlateActive`, `btnPlateV2`, plus `ruleBench`, `pocketRule`, `edgeTorn`,
  `edgeSpine`, `caseStrap`, `railStrap`, `sheetEdge` and every `KitMark` but
  `tabPlate`. They paint fallbacks. **This is now a budget question, not a
  capability one** — pro is the proven route, 228 generations remain, and the
  three families authorised this pass all succeeded on the first call.
- **The three frames are not yet on a screen.** No screen consumes `KitFrame`
  yet — the screens belong to other teams — so the proof is
  `ninepatch-proof.js` at real panel sizes, not a device render.
- **`StrideSheet.docked` is not built.** WORLD's peek/half/full sheet is
  specified in KIT_CONTRACT §5 and unimplemented; WORLD is unblocked for
  everything except the sheet itself.
- **The `_hi` PNGs, their `pubspec.yaml` rows and `nav-active-variant.js`
  still exist.** Retired in code only — deleting a shipped asset and editing
  the CI workflow that guards it has a different owner.
- **Goldens are stale by design** (see above).
- **No device verdict.** Every judgement here is the 393 × 852 DPR-1 harness;
  the iPhone is the authority and has not seen it.

## Q- raised

None. Q-26 was **answered** by `DIR-15` §2 and is now implemented: the glyph is
type, the backing is chrome, and the plate — not a brighter glyph — carries the
active state.


---

## Final pass — the producer released the full cap

Spend **258 of 320**. **Thirteen assets ship**, from 3 accepted of 32 pixen
rolls plus 10 accepted across 11 pro calls and deterministic post-work.

**Landed:** `nav_welt_v2`; frames `inset_well`, `slot_well`, `stage_frame`,
`btn_plate_v2`, `page_sealed`; tiles `rule_journal`, `rule_chart`,
`rail_shelf`, `edge_spine`; ornaments `tab_plate`, `ribbon_label`,
`rule_ornate_a`. Commits `5b92ef6`, `80463ee`, `3e1fa02`.

**Three findings worth more than the assets:**

1. **A white face is a key, not a reject.** The button plate and the sealed
   page both came back with painted-white centres and measured as "solid
   plate, not a frame". Keying every pixel over L 0.5 to alpha 0 turned six
   rejects into usable frames for zero generations.
2. **A corner is not a band.** Twice now the corner block had to be wider than
   the measured rim — 26 against 19 on the stage frame, 8 against 5 on the
   button — because the corner *cap* is wider than the *rim*, and at the
   smaller figure the painter tiles the cap along every run. No measurement
   shows this; `ninepatch-proof.js` renders it.
3. **The incumbent can win.** 40 generations across 128 nav candidates
   produced nothing better than the Flutter-painted nav plate and well. The
   nav is not swapped, and that is a measured verdict.

**Rejected in this pass, with reasons:** `inset_stage` (solid, no hole),
`rule_bench` (a pure-black hairline `separator` already draws better),
`pocket_rule` (tiles as a blue-grey checkerboard), `case_strap` (unreadably
dark), `edge_torn` (a closed scrap, not an edge), `rail_strap` (grey rubble),
`nav_well` and `nav_plate_active` (open or paper-thin outlines), and the three
torn-edge `page_sealed` candidates — rejected *for* the tear, which makes the
bottom band 0 at mid-span and cannot carry one inset.

**Still open:** eighteen kit names have no art and paint fallbacks; `ribbonLabel`
is fixed-width until someone writes a three-patch painter; `btnPlateV2` is
registered but not wired into `StrideButton`'s 43 call sites; goldens remain
stale by design; no device verdict on any of it.
