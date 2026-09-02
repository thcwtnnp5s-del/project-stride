# FMPO02 Wave 2 — UI family (PROD-UI) report

Balance **9551 → 8513** account-wide. **This family requested 95 of its 450 cap.**
The account is shared with the other Wave 2 leads and the 1038 delta is theirs as
well as mine; the per-job count in `GAME_BIBLE/ART/exploration/FMPO02/ledger/UI.md`
is the figure of record for UI.

No Dart was edited.

---

## 1. What ships

`GAME_BIBLE/ART/exploration/FMPO02/out/ui/`. Every asset has a `.json` sidecar
carrying its measured geometry; every one passes the three
`check-art-palette.js` rules by hand (teal ΔRGB ≥ 10, alpha 0/255 only, nothing
above `#7C7263`) and the `check-tile-seam.js` wrap test where it applies.

| Asset | Path | Canvas | corner / band | PanelSkin / PanelSurface row |
|---|---|---|---|---|
| grain_journal_leaf | out/ui/surface/ | 32×32 | – / – | `PanelSurface.journalLeaf` → `assets/ui/v1/surface/grain_journal_leaf.png` |
| grain_leather | out/ui/surface/ | 32×32 | – / – | `PanelSurface.oiledLeather` |
| grain_oilcloth | out/ui/surface/ | 32×32 | – / – | `PanelSurface.oilcloth` |
| grain_buckram | out/ui/surface/ | 32×32 | – / – | `PanelSurface.buckram` |
| grain_bench_oak | out/ui/surface/ | 32×32 | – / – | `PanelSurface.benchOak` |
| grain_slate | out/ui/surface/ | 32×32 | – / – | bestiary interior (no enum member yet — ART-02 §2 lists 8, this is the 9th material) |
| grain_steel | out/ui/surface/ | 32×32 | – / – | combat interior (same note) |
| grain_cork | out/ui/surface/ | 32×32 | – / – | `PanelSurface.cork` |
| grain_plan_linen | out/ui/surface/ | 32×32 | – / – | `PanelSurface.planLinen` |
| grain_chart_vellum | out/ui/surface/ | 32×32 | – / – | `PanelSurface.chartVellum` — **ships without grain, see §4** |
| band_forge | out/ui/band/ | 384×48 | – / – | picture, drawn ×1, clipped; Craft + Skills smithing header |
| band_cookfire | out/ui/band/ | 384×48 | – / – | Craft + Skills cooking header |
| band_bench | out/ui/band/ | 384×48 | – / – | Craft + Skills woodworking header |
| band_foraging | out/ui/band/ | 384×48 | – / – | Skills foraging header |
| band_mining | out/ui/band/ | 384×48 | – / – | Skills mining header |
| band_world_chart | out/ui/band/ | 384×48 | – / – | World |
| band_encounter_ground | out/ui/band/ | 384×48 | – / – | Encounters |
| band_adventure_trail | out/ui/band/ | 384×48 | – / – | Adventure |
| band_combat_kit | out/ui/band/ | 384×48 | – / – | Combat |
| band_boards_batten | out/ui/band/ | 384×48 | – / – | Boards |
| btn_plate | out/ui/button/ | **58×26** | **4 / 0** | `PixelFrame`; every register and both states are remaps beside it |
| btn_compact | out/ui/button/ | **46×22** | **5 / 2** | as above |
| nav_welt | out/ui/nav/ | 8×4 | – / – | tiled along the nav bar's top edge, period 8, horizontal only |
| header_shelf | out/ui/header/ | 8×6 | – / – | tiled along the header's bottom edge, period 8, horizontal only |
| rule_plate_64x16 | out/ui/ornament/ | 64×16 | – / – | ships whole; caps cut from it below |
| rule_cap_left / _right | out/ui/ornament/ | 12×14 | – / – | discrete, positioned by Flutter, **authored not mirrored** |
| bg_workbench | out/ui/bg/ | 384×176 | – / – | `ScreenBackdrop`, ×1, scrimmed, behind everything |
| nav_* (11 glyphs) | out/ui/nav/ | 14×14 | – / – | **CANDIDATE ONLY — do not swap, see §5** |

**Geometry the integrator must not re-derive.** Surfaces tile on both axes from
the interior rect's top-left at `native × 2` (32 src = 64 logical), last row and
column clipped and never rescaled. Bands and `bg_workbench` are picture class:
drawn once at ×1, clipped to the card, never tiled and never stretched.
`nav_welt` and `header_shelf` tile horizontally only, period 8 src.

---

## 2. Two method findings that cost the round its generations

**Surfaces: PixelLab draws a swatch, not a material.** It vignettes the outer
ring, arches the top, and drops a cloud somewhere in the middle. All three are
low-frequency, and all three are invisible in a single tile and obvious the
moment three copies sit side by side. The vignette is the nastiest because it
*passes* `check-tile-seam`: the last column matches the first column exactly —
both are ring — so the wrap score reads 0.00 while the tiled surface grows a grid
of dark lines. `tools/surface.js` measures border bias separately for exactly
that reason.

**The quarter-mirror fold is the wrong tool at this pixel count.** The production
plan blesses it for Batch C and it is genuinely seamless by construction, but
mirror symmetry turns every surviving fleck into a butterfly and a butterfly
repeating every 32 logical px reads as plaid. Eight of eleven folded tiles failed
a blind read on that; none failed on a seam. What ships is **cut, not folded** —
a deterministic 2-D window search (plan §3.5 clause 1) that keeps the quietest
quartile by structure, then takes the best join inside the grainier half of it.

---

## 3. Three deviations, stated in the open

1. **Flat-field before snapping** (`tools/surface.js --flatten 4`). Subtract the
   master's own box-blurred L\* and put the median back. It removes the vignette,
   the arch and the blotches and keeps the per-pixel grain — which is the literal
   definition of "grain, not pattern". It is a per-pixel luminance transform, it
   invents no mark, and it can only make a tile less interesting. **ART-13 §5 does
   not name this step.**
2. **Grain-depth normalisation** (`--depth 2`). Scale the residual so its p5–p95
   spans two ramp rungs. Measured across the masters, the raw grain amplitude
   ranged 0.02–6.5 L\* for prompts differing only in the noun, against a fixed
   2.5–4.9 L\* ramp step — so whether a tile quantised to a flat fill or sprayed
   across the ramp was a coin toss, and both failures were observed on the same
   day. A master whose grain spans less than half a rung is **refused**, not
   amplified; scaling nothing would be authoring.
3. **Text-safe exposure on bands** (`tools/band.js --textsafe`). The `#7C7263`
   ceiling governs chrome *beside* the words. A station band sits *under* them,
   and the brightest legal chrome ink measures **4.26:1** against `textPrimary`
   — below the 4.5:1 every surface in ART-13 §1 is held to. One linear-light gain
   per band (×0.87–×0.93) puts the brightest pixel on 4.5:1. Every relationship
   in the picture is preserved; nothing is redrawn.

**The literal "≤6 L\* between the two most-used inks" rule is reported unchanged
and is not the whole verdict.** Every ART-13 ramp steps 6.0–8.4 L\* from base to
mid, so a 97%-flat vellum with a 3% highlight fleck fails it by the same margin
as a genuinely striped steel. `surface.js` prints the literal figure *and* the
figure restricted to inks carrying ≥10% of the tile, and calls the disagreement
`CHECK` rather than resolving it silently. One asset ships on a `CHECK`:
**grain_leather** (94.2% base + 3.3% mid fleck, literal ΔL\* 7.45, no second
heavy ink). It reads clean.

---

## 4. What did not ship, and why

| Asset | Rolls | Verdict |
|---|---|---|
| **modal_128** | 3 | **FAILED.** All three carry round stud heads on the corner straps, which P-D1 forbids by name; one puts a boss in the centre of every edge run (§3.4); one gives each corner a large warm round disc, the coin register. Geometrically they are also unusable: the corner plates protrude past the runs, so the top run is transparent at mid-span and no nine-patch can be cut. Recorded and left. |
| **strap_corner_64** | 2 | **FAILED.** Asked for four loose L-tabs, got four complete little frames both times. The model will not draw disconnected corner pieces. |
| **corner_mark_48** | 2 | **FAILED.** One frame with a disc; then four diagonal squares with spikes. |
| **tab_index_32x16** | 2 | **FAILED.** A book, then a dotted frame. |
| **tack** | 1 | **FAILED**, and worth not chasing: a small dark tack head at 12 px is one pixel away from the coin register the reject list names. |
| **rule_run (8×4)** | – | **NOT EXTRACTABLE.** The accepted rule plate's body has transparent gaps, so no fully-opaque 8×4 window exists in it. The two caps ship; the run between them has to come from a re-roll or from Flutter painting a 4-logical-px `actionEdge` line. |
| **nav_plate_32** | 1 | **FAILED on measurement.** Band 0/0/0/1 — a solid plate with no rim. It cannot be a nine-patch with corner 8 / band 4, and declaring the brief's numbers over the asset's is precisely the defect production plan §3.2.1 exists to prevent. |
| **banked_cartouche** | 1 | **FAILED on measurement.** Band 0/4/1/5 — asymmetric, no usable rim. |
| **nav_world_hi** | 2 | **HARD REJECT.** The first is a radial burst (§11, named); the retry is a small warm round disc (coin register). No acceptable variant exists, so the world pair is incomplete. |
| **grain_chart_vellum** | 4 masters | Ships, **without grain**: 99.4% one ink. Four masters produced either a dead field or, in the burlap attempt, a weave that read as **brickwork** when tiled — worse than flat. It delivers the World family's interior *hue* and nothing else. Re-author or accept knowingly. |

---

## 5. The nav glyphs: shipped as candidates, and I recommend not swapping them

Eleven of the twelve are packaged, in the **measured** `chassis_64` ramp (read out
of the accepted master by luminance percentile, per plan §6, not the five
proposed hexes). Every one is 14×14, guard-clean, alpha 0/255 only.

I still recommend the integrator **does not swap them this round**, for two
reasons that only showed up in the side-by-side (`review/ui/nav_compare.png`):

- **Legibility.** The chassis ramp tops out at `#985B30`, L = 0.144 — about
  3.4:1 against `surfaceGround`. The shipped glyphs are flat `#A8A093`-family
  silhouettes at roughly 6:1. A nav icon is closer to type than to chrome, and
  the ceiling that makes chrome recede makes a 14-px icon mushy.
- **The active signal gets weaker, not stronger.** The point of authoring the
  `_hi` pair was to close the derived-variant debt in `nav-active-variant.js`.
  Authored in one leather ramp, base and `_hi` differ less than the current
  derivation does, and the world pair has no legal `_hi` at all.

That is a design finding, not a craft failure: **UNRESOLVED — does a nav glyph
belong to the chrome ceiling or to the type ladder?** It needs UX-01 and the
owner. `JOURNAL/OPEN_QUESTIONS.md` is the right home for it.

Also recorded: **PixelLab cannot author 14×14.** pixflux needs 1024 px of area
(32×32 minimum square); pixen goes smaller but only in multiples of four. These
were authored at 16×16 on pixen, cropped to content and centred in 14 — a crop,
never a rescale.

---

## 6. For the integrator, precisely

- `PanelSurfaces.authored` takes nine entries today. `slate` and `steel` have no
  `PanelSurface` member in ART-02 §2's enum of eight; either add two or park the
  two tiles.
- **Buttons: `band` is 0 on `btn_plate`.** That is fine for a button and only for
  a button — a button's interior is a face with a label on it, not a tiled
  surface, so the inset is Flutter's padding. Do not carry a 0 band to a panel.
- Bands are already text-safe at 4.5:1 against `textPrimary`. If a scrim is added
  on top of that, the gain can be dropped — rerun `tools/band-batch.js` without
  `--textsafe`.
- Every accepted surface is reproducible from `tools/surface-batch.js`'s table
  plus the master in `raw/`; every band from `tools/band-batch.js`'s.

## 7. Tools written this round

`tools/ramp-png.js` (N×1 palette anchor, ~86 B, inlines under the 5 KB ceiling) ·
`tools/ramps.js` (ART-13 §1/§2 + plan §6 as data) · `tools/colour.js` ·
`tools/surface.js` (flat-field → depth → snap → window search → cut → verdict) ·
`tools/grain-proof.js` (tile ×2 over 200×120 with `#F0E7D8` body runs across it)
· `tools/band.js` + `band-batch.js` · `tools/tile-cut.js` · `tools/glyph.js` ·
`tools/btn-prep.js` · `tools/surface-batch.js` · `tools/ui-package.js`.
