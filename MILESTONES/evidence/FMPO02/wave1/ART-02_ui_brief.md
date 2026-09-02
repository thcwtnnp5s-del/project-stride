# ART-02 — the UI family system: bands, surfaces, pictures

**Diagnosis.** One frame + one flat `surfaceCard` fill is the whole visual system; the
`surfacePath` lever exists in `PanelSkin` and is read by nothing. Identity was meant to come
from three axes (band / surface / picture); two were never built, so the chassis carried it
all and became wallpaper. Batches B–I did not fail — they were never run
(`CHASSIS_ROUND_RECORD_01` §7). Batch A's lesson stands: **to change a border's weight,
change the canvas, not the adjective**, and one accepted frame costs ~18 gens. **The fix is
not more borders.** Border families stay at **two**, forever: `chassis_64` (shipped) and
`modal_128` (Batch D); every identity below is carried by SURFACE + BAND + ORNAMENT +
PICTURE. That is L-18 as amended, read literally.

## 1. Architecture: the `surfacePath` lever, exactly

`PanelRole` stays a closed six (it selects a **frame**). Add an orthogonal axis that selects
an **interior** and nothing else:

```dart
enum PanelSurface { none, journalLeaf, oiledLeather, oilcloth, benchOak,  // panel_skin.dart
                    buckram, cork, chartVellum, planLinen }
abstract final class PanelSurfaces { static const Map<PanelSurface,String> authored = {}; }
// SectionCard gains `this.surface = PanelSurface.none`; PixelFrame gains `surfacePath`.
```

- `_PixelFrameState` resolves a **second** `ImageStream` for `surfacePath`, same lifecycle
  as `_resolve()`, re-resolved when the path changes, `null` tolerated silently.
- `_FramePainter.paint()` — **before** corners/edges: `interior = Rect.fromLTWH(inset,
  inset, size.width-2*inset, size.height-2*inset)`; `canvas.save(); clipRect(interior);`
  tile `surfaceNative * scale` (32 src × 2 = **64 logical**) in +X/+Y from `interior.topLeft`
  with `FilterQuality.none, isAntiAlias:false`; last row/column **clipped, never rescaled**
  (§3.3 precedent); `restore()`. `shouldRepaint` compares both image identities.
- `SectionCard` keeps `DecoratedBox(color: surfaceCard)` **under** the frame, so a tile that
  fails to load degrades to today's card, not a hole. Nothing about inset, padding
  subtraction, hit targets or text measurement changes; empty the map, one commit back.

## 2. Registry proposal — 11 families, 2 borders, 8 surfaces

| Family | Role (frame) | Surface | Band / picture | Ornament |
|---|---|---|---|---|
| Adventure (field journal) | `card` + `heroPlate` | `journalLeaf` | place vignette recrop (0 gens) | `strap_corner_*` on the hero |
| Craft (workbench + folio) | `card` | `benchOak` (station) / `journalLeaf` (folio) / `oilcloth` (tray) | 5 trade bands = Batch B, **reused** | `tab_index`, `rule_*` |
| Skills (guild handbook) | `card` | `buckram` | 5 trade bands (Batch B) | `rule_*` between unlock lines |
| Inventory (equipment case) | `kitTray` | `oilcloth` | — | `strap_corner_*` on loadout |
| Character (traveler folio) | `heroPlate` | `journalLeaf` | — | `strap_corner_*` on portrait |
| Combat (field kit) | `combatFrame` | `oiledLeather` | — | `rule_*` over the log |
| Encounters (field guide) | `card` | `journalLeaf` | regional ground strip | `rule_*` under the strip |
| World (navigator's atlas) | `card` | `chartVellum` | atlas is its own picture | `corner_mark_*` |
| Boards (pinned parchment) | `boardSlip` | `cork` | — | `tack` |
| Projects (blueprint ledger) | `boardSlip` | `planLinen` | — | `tack`, `rule_*` |
| Reward (trophy) | `modalFrame` | `journalLeaf` **warm remap** (A-2, 0 gens) | — | `rule_cap_*` |

## 3. Assets to produce

**S — surfaces.** `create_image_pixen(w=64,h=64,no_background=false,view="high top-down",
outline="single color outline")` + SC-SURFACE verbatim; ship 32×32 by quarter-mirror fold
(seamless by construction); ≤6 L\* total variation — *if a tile is interesting, it is wrong*.
Eight → `assets/ui/v1/surface/`: `grain_journal_leaf, grain_leather, grain_oilcloth,
grain_bench_oak, grain_buckram, grain_cork, grain_chart_vellum, grain_plan_linen`. Prompt
shape per P-C1/C3/C4: material, two or three values, *"no seam, no hem, no edge, no writing,
no ruling, no object lying on it"*. **24 gens.**

**F — the second frame.** `modal_128.png`, Batch D P-D1 verbatim (128×128, `side`,
transparent, corner 24 / band 8). Registered to `modalFrame` only. **12 gens.**

**BAND — pictures.** Batch B's five 384×48 trade bands, authored once and consumed **twice**
(Skills card headers, Craft station headers) — that reuse is why Craft costs almost nothing.
**15 gens.** Six family bands at 384×48 (`band_world_chart`, `band_boards_batten`,
`band_projects_plan`, `band_encounter_ground`, `band_combat_kit`, `band_adventure_trail`),
SC-BAND clause; author at 384×96 and take the lower 48 by crop if the model composes a
scene. **18 gens.**

**ORN — discrete ornaments** (positioned by Flutter, never inside a tiled run). One plate per
group, all ends drawn in one roll so the key light stays upper-left: `strap_corner_64` →
4×(12×12); `rule_plate_64x16` → `rule_cap_left/right` (12×16) + `rule_run` (8×4); `tack`
(≤12×12, trimmed from 16×16); `tab_index_32x16` (index tab for the open folio row);
`corner_mark_48` → 4×(12×12) chart brackets. **36 gens.**

**BTN — button faces: one plate, not nine.** 0029 forbids raster state variants outright, so
the nine registers are **not** nine assets. Author **two**: `btn_plate_48.png` (64×32 src,
corner 8, band 4, nine-patch through `PixelFrame`) and `btn_compact_32.png` (48×24 src,
corner 6, band 3). Every register — commit / attack / defense / ready / equip / craft /
travel / combat — is a **deterministic index remap** of `btn_plate` onto the existing hue
token (A-2, `remap.js`, **0 gens**; the `#7C6A4A` ceiling still binds). Pressed = today's
translate-onto-ledge + light-out, in Flutter. Disabled = **no plate at all**, painted flat —
an unpressable thing has no thickness. Selected = Flutter's border. **24 gens.**

**NAV — bottom bar.** `grain_leather` behind the whole 64dp bar plus `nav_welt.png` (8×4 src)
tiled along its **top** edge: the bar becomes a strap, not a void. Active tab:
`nav_plate_32.png` (32×32 src, corner 8, band 4) through `PixelFrame`, `journalLeaf`
interior, `StrideRadius.tabActive`'s bottom-only corners — a lifted bookmark. Tab width is
65.5dp at 393 (fractional), so the plate **tiles and clips**; a fixed-size plate is refused
for exactly that. Icons: re-author all **12** nav glyphs (14×14, 6 pairs) as objects in the
chassis ramp, closing the `nav-active-variant.js` derived-`_hi` debt — same referent as
today (L-15), only the material changes. **54 gens.**

**HDR — header.** `header_shelf.png` (8×6 src) tiled along the header's bottom edge, replacing
the 1px separator: the header sits on a welt. `banked_cartouche.png` (48×24 src, nine-patch,
corner 6/band 3) — a pressed plate **behind** the banked numeral, fixed-size, placed by
Flutter. It must never size, fill or drain with the value: banked steps are a stock the
player owns, a numeral with a glyph, never a meter (§11). Region tint stays the existing
`forRegion` wash over the shelf. **24 gens.**

**CRAFT / ENC / TRAY.** `bg_workbench.png` 384×176 (Batch G P-G1, conditional on the shipped
work backdrops reading as gathering sites) + 4 station plinths: **30 gens**. Five 384×96
regional ground strips for the encounter creature band (try the free vignette recrop first —
0 gens): **20.** `well_plate_32` + `tray_divider`: **16.**

**Budget.** 24+12+15+18+36+24+54+24+30+20+16 = **273 committed**, +**123** blind-round
re-author reserve, +**54** seam escalation = **450**. Escalate before any `inpaint_image`.

## 4. Craft recomposition, at the widget level

The database read comes from one structural fact: **every recipe is its own rounded card.**
Kill that — rows become leaves of one folio, separated by a hairline.

- `CraftBench` (root) — `ScreenBackdrop(bg_workbench, scrimmed)` behind everything.
- `StationHeader` — replaces `SectionHeading`: a 384×48 trade band clipped edge-to-edge,
  Cinzel station name over it, `LV n` right. **Pure presentation swap** — grouping stays
  readiness-banded. *Regrouping by station is a UX decision, not an art one: **UNRESOLVED**,
  needs UX-01 + owner.*
- `RecipeFolioRow` — replaces `_RecipeRow`. No card, no border. `journalLeaf` runs behind the
  whole section; each row is 72dp with a `rule_run` hairline beneath. **Output prominence:**
  the 48-native icon in a `MountedWell` (4 `strap_corner_*` tabs), left; right, a run of 24dp
  ingredient thumbnails — the row reads *ingredients → output*, not name-and-chip.
- `RecipeFolioRow.open` — expands in place (as today); the output icon redraws at native 48
  **×2 = 96dp** — integer scale, zero new art, real hero prominence — and `tab_index` marks
  the open row's outer edge. `IngredientTray` follows: an `oilcloth` strip carrying a 32dp
  `InsetWell` + held/required per ingredient, laid out as a tray, not a table of lines.
- `ReadyMark` — a small pressed leather notch at the row's outer edge plus today's
  `positiveReady` ink. Not a meter, not a fill, not a badge.
- `Locked` — no lock, padlock or keyhole art anywhere (§11). The row keeps the folio surface
  at reduced opacity and the output icon loses its corner straps: *not yet mounted in the
  folio*. `_reason()` text is unchanged and stays the only statement of why.
- `_ActiveCraftPanel` / `CraftRepetitionBar` / `ActivityResultCard`: untouched.

## 5. Reject list — refused on semantics, however well drawn

Nine authored button-state faces (state is Flutter's — 0029). A wax seal, medallion or any
small warm round disc — the coin register, and Stride has no currency (P-6). A drawn slot,
socket, compartment, cell, grid line or column rule — Flutter measures those. A lock,
padlock, keyhole or chain for Craft's locked band. Any timer, hourglass, cooldown ring,
durability bar, capacity meter or gauge; any waisted symmetric mass; any bar, ring or
draining vessel near banked steps. A rarity gem, tier chevron, star rating or rank pip; a
four-point star or radial burst behind a reward. Any word, numeral or letterform in any
raster asset — bitmap type is not in scope and is not a future option. Any full-screen
raster; a backplate is restrained, scrimmed, behind everything. `centerSlice` or any stretch.
A third border family. Rivets, studs, eyelets or buckles **inside a tiled run**. Any pixel
within ΔRGB 10 of `#58D6C0`; any chrome above `#7C6A4A`. Fire, embers or glowing metal in a
smithing or cooking band; figures, stalls or prices in the workbench plate. Mirrored
ornaments — a mirror flips the key light to the upper right, a small permanent error.
