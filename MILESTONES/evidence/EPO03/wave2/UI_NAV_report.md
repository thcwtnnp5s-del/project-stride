# PROD-UI-NAV — the kit and the bottom nav (EPO03 Wave 2)

Branch `fable5-executive-production-overhaul-03`. Cap **320**, spent **32**.
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

**Assets: one accepted of thirty-two rolls.** `assets/ui/v1/nav/nav_welt_v2.png`
(8 × 6, ×2, guard-clean, sidecar beside it), drawn by *both* the nav bar and the
header shelf — one chassis, one stitch, layout-neutral.

**Renders.** `GAME_BIBLE/ART/exploration/EPO03/review/device/nav/` (all six tabs
+ driven states), `nav_square/` (the same after the radius change).
Judged crops: `review/ui/nav_header_six.png` (header + bar, six tabs),
`nav_six_tabs_x2.png`, `radius_before_after.png`, `welt_run2_x4.png`.

**Tests.** `panel_skin_test.dart`, `band_plate_test.dart`, `phase1_ui_test.dart`
— **51 passing**. `flutter analyze lib/ui/` clean.
`check-art-palette.js`: 1,883 PNGs, no teal collision, no semi-transparent
pixel, chrome under the ceiling. `nav-active-variant.js --check` still green.
Goldens **not** regenerated — every tab's chrome changed, so all twelve will
differ; the producer regenerates after inspecting the diff.

## What was rejected, and the finding behind it

Thirty-one rolls rejected, each with a written reason in the ledger. They fail
in **one** direction: asked for flat, plain, tileable chrome, `pixen` draws *a
lit object in perspective, decorated with studs, above the `#7C7263` ceiling*.
Four strategies were tried — direct request, request with the interior keyed,
a 128² sheet of recesses to cut from, a 128² sheet of pads — and the two sheets
came back **rotated on the diagonal**, so no axis-aligned crop exists and the
production plan's window search cannot rescue them (rotating pixel art is not
a deterministic post-step; A-2 forbids inventing the pixels it needs).

FMPO02 measured this same boundary on `modal_128`, `strap_corner_64`,
`corner_mark_48`, `tab_index_32x16` and `nav_plate_32` and shipped none of them.
It is a capability boundary, not a prompt problem, and `MISTAKES.md` M-05
forbids paying for it twice — so **`KitFrames` and `KitMarks` ship declared and
empty**, the remaining 288 generations are deliberately unspent, and every
consumer paints a square, one-weight fallback. Nothing a screen team codes
against changes when a row eventually lands: the `…For()` lookups return the
declared geometry either way.

Sheets: `review/ui/frames_x3.png`, `nav_small_x6.png`, `strips_x3.png`,
`sheets_x4.png`.

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

- **The frame and ornament families have no art.** Wells, ribbons, tabs, page
  edges, stage frames, rules, rails and the quiet-button caps are all
  fallbacks. Named, not softened: `DIR-05`'s kit is ~15 % delivered as raster.
  Re-authoring needs a tool that will draw flat axis-aligned chrome — a
  different model, or a hand-authored master — and that is a decision for the
  producer, not a re-roll.
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
