# EPO03 — UI-WORLD ledger

Team `world` (PROD-UI-WORLD), branch `fable5-executive-production-overhaul-03`.
Cap: **60 generations. Spent: 0.**

| # | Asked | Tool | Job id | Cost line | Verdict | Reason |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | **No PixelLab job was submitted.** See below. |

**Family total: 0 generations.**

## Why nothing was generated, said plainly

DIR-15's production family for this screen is four marks — `peek_plate` with
its leather tab, `sheet_grip`, `label_plate` / `label_plate_selected`, and a
recentre chip — costed at 1 generation each on `create_image_pixen`. Two
things landed between that costing and this shift, and together they made the
whole family the wrong first spend:

1. **`create_image_pixen` does not draw flat chrome.** The kit owner spent
   **32 rolls** across four prompt strategies on exactly this class of asset
   and shipped one (`KIT_CONTRACT.md` §8, `UI_KIT.md`): the model returns the
   piece in perspective, with a stud at each corner, above the `#7C7263`
   ceiling, or rotated off-axis so no nine-patch can be cut. The four rows
   above are therefore not four 1-generation rolls; on the proven route
   (`create_image_pro` with an accepted grain as the style reference) they are
   four calls at 20–40 each — the whole cap, for chrome behind a screen whose
   actual failure was geometric.

2. **Every one of the four already has a landed name and a finished
   fallback.** `KitFrame.peekPlate`, `KitMark.peekTab`, `KitMark.sheetGrip`,
   `KitFrame.labelPlate`, `KitFrame.labelPlateSelected` and
   `KitTile.sheetEdge` are all declared in the kit contract, all resolve to
   `null`, and all reserve their declared geometry either way — so the sheet
   is laid out identically before and after any of them arrives, and gains
   material the day one lands without reflowing a single dp.

`PRODUCTION_RULES.md` §2a states the rule this follows: *"Build the Dart
structure first. Every screen's page model is mostly layout on materials that
already ship. A screen rebuilt on existing grains and painted rules is
transformed even if none of its new marks ever land; a screen waiting on art
is not transformed at all."* The World sheet's defect was **247 dp of panel
over a new painting and a marker tap that put it back** — a geometry problem,
answered in geometry, and the renders under
`GAME_BIBLE/ART/exploration/EPO03/review/device/world/` show the result at
91 % map.

The cap is a ceiling, not a quota. What the screen now consumes:

| Used | Source | Cost |
|---|---|---|
| `KitFrame.slotWell` (the peek's kind-glyph well) | landed kit row, `kit/slot_well.png` | 0 |
| `KitMark.sheetGrip` (the sheet's grip) | declared kit row, painted fallback | 0 |
| `world/marker_haven`, `_wilds`, `_worksite`, `_perilous` at ×1 | the shipped atlas kind-marker table | 0 |
| `btn_compact` through `StrideButton.secondary` (the peek's Travel) | shipped | 0 |
| the strip's carets | a `CustomPainter` triangle — chrome, not type, so it renders identically on every device and in the evidence harness where a geometric-shapes codepoint would fall back to another font | 0 |

The four unauthored marks are named as open work in
`MILESTONES/evidence/EPO03/wave2/UI_WORLD_report.md`, with the pro method and
the canvas sizes, so the next shift spends against a known route rather than
re-deriving the pixen boundary at its own cap's expense.
