# DIR-15 — Mobile UX: the World sheet and the bottom nav

Read at `9cabe4f`. dp at 393×852; body = 852 − header 61 − nav 64 = **727** (device 634). Lock held: travel starts only from an explicit control showing its cost.

## TOP FAILURES

1. **Sheet by default.** `_collapsed = false`; `(727×0.34).clamp(220,360)` = 247 → **480 dp of map clear: 66% of body, 56% of screen**; every marker tap re-expands (`world_screen.dart:210`).
2. **The peek is 76 dp, 16 of them information** (40 fade, 20 handle).
3. **Here / tapped / panned-to share no vocabulary**; nothing names what the camera is on.
4. **Nav is a fill and a rule**, the active glyph an index remap; on the device the 34 pt inset under the leather is flat `#201C17` (`stride_scaffold.dart`), a seam on every screen. Q-26 open.

## WHAT TO REPLACE

### 1. World sheet — three stops

| Stop | Height | Map clear (body / screen) | Content |
|---|---|---|---|
| **Peek** (default) | **64** + 24 dp translucent fade above | **663 — 91% / 78%** (device 570) | grip 12; one row: kind glyph in a 28 dp well · name `sub` · `kind · status` `micro` · boot + cost + compact **Travel** 44×88, or "You are here" |
| **Half** | `clamp(0.36×body, 232, 300)` = **262** | **465 — 64% / 55%** | inspector head + `_TravelControls` + Set as Journey |
| **Full** | 0.70×body = **509** | **218 — 30%** | whole `AtlasInspector`; camera recentres the selection above the sheet |

Drag snaps to the nearest stop (>300 dp/s flings one); grip tap peek→half, half/full→peek; **map tap → peek**; **marker tap updates the peek, never raises the sheet** (full drops to half); peek Travel opens **half with the confirm armed** — "Set out · 1,000 steps" is the only dispatch. Back → peek. No scrim.

| | Word | Colour / marker | Lives in |
|---|---|---|---|
| Here | "You are here" | region ink; bullseye + pulse (exists) | header title — changes only on arrival |
| Selected | name + "Not yet reached / Reached / Road from here · N steps" | ivory ring (exists) + **ember-edged label plate** | the sheet, every stop |
| Journey | "Journey set" | gold ring (exists) | Set as Journey |
| Viewed | *never named* | — | a **contextual strip** at the map's top edge (22 dp, plate 0xA0) only while the selected or here marker is off-screen: "◂ Whispering Woods · 1,000" / "You are here ▸" chips recentre |

Teal only on the boot glyph.

### 2. Bottom nav

Height **64** stays; welt 8→**12**, re-cut as the header shelf's stitch (8×6 ×2) so both frames are one chassis; **leather runs into the bottom inset** (paint moves from `StrideScaffold` to `StrideTabBar._Leather`). Tabs 52×65.5. Inactive: glyph in a **stamped well** 36×28 (2 inks ≤6 L\*). Active: a **raised plate** 57×52 (4 dp inset, bottom radius 8), lit top bevel against the welt, glyph and label on it, well gone. Labels 9.5 clamped, active `textPrimary`, inactive `textSecondary`.

**Q-26: the glyph is type, the backing is chrome.** Glyphs keep the shipped 6:1 silhouettes; wells and plates obey the ceiling and the bands' text-safe test (L ≤ 0.1403). The eleven leather-ramp candidates are discarded; `_hi` remaps and `nav-active-variant.js` retire.

### 3. Reach

Targets ≥44. Rails in the thumb band y 560–788: World peek 724–788; Combat rail four 84×48 cells at y ≥ 700, **Attack at the thumb's home corner (right), Retreat far left**; primary actions below y 520.

### 4. Dart, widget level

- `bottom_sheet.dart` (NAV): `StrideSheet.docked(stop, onStop, peek, child, peekHeight 64, halfFraction 0.36, fullFraction 0.70, fade 24, no scrim)`; World consumes it.
- `world_screen.dart` (WORLD): `_collapsed` → `enum _SheetStop`; delete `_WorldInfoPanel` and the `_panel*` constants; `_PanelPeekRow` gains well, status, Travel-arms-confirm; `_ContextStrip` on a `ValueNotifier<Rect>` from `AtlasViewport` plus `onBackgroundTap`.
- `atlas_selection_panel.dart` (WORLD): split `AtlasInspectorHead`; `_TravelControls(armed:)`. `atlas_layers.dart`: **request only** — `_MarkerLabel(plateAsset:)`.
- `stride_tab_bar.dart`, `panel_skin.dart`, `stride_scaffold.dart` (NAV): `NavPlates` registry, `weltHeight 12`, inset paint.

## WHAT TO KEEP

Inspector sentences; `AtlasZoom` stops; rings and pulse; `grain_leather`; six destinations; region-ink header; `travel_transition`.

## PRODUCTION FAMILY

| Asset | Native canvas | Kind | Count | Tool | Cost |
|---|---|---|---|---|---|
| `nav_welt_v2` | 8×6 | tile, period 8, h-only | 4 | `create_image_pixen` | 1 |
| `nav_plate_active` | 32×28, corner 4 band 4 | nine-patch | 8 | pixen | 1 |
| `nav_well` | 24×20, corner 4 band 2 | nine-patch | 6 | pixen | 1 |
| `sheet_grip` | 24×6 | icon ×2 | 4 | pixen | 1 |
| `sheet_edge` | 8×6 | tile | 4 | pixen | 1 |
| `peek_plate` | 32×32, corner 8 band 8, leather | nine-patch | 6 | pixen | 1 |
| `label_plate` + `_selected` | 24×12, corner 3 band 2 | nine-patch ×2 | 6 | pixen | 1 |
| glyphs, chips | shipped set, `btn_compact` | — | 0 | — | 0 |

## PIXELLAB BUDGET

38 first pass + 22 re-roll reserve = **cap 60**.

## PHONE-SCALE SUCCESS CRITERIA

1. World opens at peek: ≥88% of the body is map; strip reads "Haven's Rest · Settlement · You are here".
2. Tap Whispering Woods: ring and route move; strip reads "Whispering Woods · Wilds · Not yet reached · 1,000 · Travel"; the sheet **does not rise**; header still Haven's Rest.
3. Travel → half sheet, "Set out · 1,000 steps"; drag down cancels; nobody has moved.
4. Pan the selection off-screen: the "◂ Whispering Woods" chip appears; tap recentres.
5. One tab reads as a raised, lit plate; glyphs ≥4.5:1 on their backing; leather reaches the home indicator, no seam.
6. Targets ≥44; peek grows at Dynamic Type 1.4 (min 64, two lines); Reduce Motion snaps.
