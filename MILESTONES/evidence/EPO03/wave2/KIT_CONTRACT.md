# EPO03 — the UI KIT CONTRACT (PROD-UI-NAV, kit owner)

**Status: BINDING for Wave 2.** Code against this now; the art swaps in under
the same names. Published 2026-09-02; every later change is appended under
§8 with a commit hash, never edited in place.

Everything below is either an **asset name + canvas + geometry** or a **Dart
symbol** in a file NAV owns (`panel_skin.dart`, `surfaces.dart`,
`pixel_asset.dart`, `stride_metrics.dart`, `bottom_sheet.dart`,
`stride_tab_bar.dart`). The registries follow the FMPO02 doctrine exactly:
**a row that has not landed resolves to `null`, the widget paints its
fallback, and the layout figure is reserved either way** — so your screen lays
out identically before and after the raster arrives (`PanelSkins.insetFor`
precedent, GOV-05 §4).

Requests (new rows, tokens, a painter) go to
`MILESTONES/evidence/EPO03/wave2/REQUESTS_NAV.md` — append a dated block;
NAV polls it every ~10 minutes and marks each DONE with a hash.

---

## 0. The three kinds, and the widget for each

| Kind | What it is | Registry (`panel_skin.dart`) | Widget (`surfaces.dart` / `pixel_asset.dart`) | Fallback while art is absent |
|---|---|---|---|---|
| **Frame** | a nine-patch cut *in*: corners once, edges tiled, interior **never drawn** (Flutter's fill) | `KitFrame` enum → `KitFrames.of(f) : PanelSkin?`, `KitFrames.insetFor(f) : double` | `KitPlate(frame:, child:, fill:, surface:, padding:)` | square rectangle, `fill` + 1 px `borderDefault`, inset by the declared band |
| **Tile** | a strip repeated along one axis at integer scale, last tile clipped | `KitTile` enum → `KitTiles.of(t) : KitStrip?`, `KitTiles.thicknessFor(t) : double` | `KitEdge(tile:, fallbackColor:, fallbackAtEnd:)` | a box of the declared thickness with a 1 px line (or nothing) |
| **Mark** | a discrete ornament Flutter positions, drawn once at integer scale | `KitMark` enum → `KitMarks.of(m) : KitOrnament?`, `KitMarks.sizeFor(m) : Size` | `KitOrnament(mark:, fallback:)` | a `SizedBox` of the declared display size (optionally your `fallback` child) |

Plus one ground: **`PageGround(surface:, spine:, child:)`** — a full-bleed
material page (no border, no radius, `SurfaceFill` of a `PanelSurface`,
optional `KitTile.edgeSpine` down the left). Every tab root sits on one.

`SectionCard` **stays** (modals, the reward layer, screens not yet rebuilt) but
its radius token is now square — see §6.

---

## 1. Frames (`KitFrame`) — nine-patches, `assets/ui/v1/kit/<name>.png` + `.json`

Geometry is **declared** here and **measured** at packaging; the measured
figure wins and is recorded in §8 if it differs. `PanelSkin` insets by
**band × scale**, never by corner. All ×2 unless stated.

| `KitFrame` | Asset | Authored canvas | corner / band (declared) | Inset dp | Used for |
|---|---|---|---|---|---|
| `insetWell` | `inset_well` | 64² | 8 / 4 | 8 | figure/bust window (Inventory, Character) |
| `slotWell` | `slot_well` | 48² | 6 / 3 | 6 | equipment slot wells, item wells, station plinth wells |
| `insetStage` | `inset_stage` | 96² | 12 / 6 | 12 | a stage window (Adventure/Encounter creature stage) |
| `stageFrame` | `stage_frame` | 128² | 16 / 8 | 16 | Combat's heavy stage frame; gauges hang from its lower band |
| `pageSealed` | `page_sealed` | 128×64 | 12 / 6 | 12 | recipe-book sealed page (Craft locked tiers) |
| `slipPinned` | `slip_pinned` | 128×48 | 10 / 5 | 10 | pinned goal slips (Adventure) |
| `ribbonLabel` | `ribbon_label` | 96×32 → crop 96×24 | 6 / 3 | 6 | level / rarity / boss / cost ribbons — **type on Flutter's fill** |
| `tabPlate` | `tab_plate` | 48×32 → crop 48×24 | 6 / 3 | 6 | folio index tabs (Craft), peek-strip leather tab (World) |
| `journeyPlate` | `journey_plate` | 64² | 8 / 4 | 8 | illustrated unlock plates on the Skills journey line |
| `peekPlate` | `peek_plate` | 32² | 8 / 8 | 16 | the World peek strip's leather plate |
| `labelPlate` | `label_plate` | 24×12 (author 24², crop) | 3 / 2 | 4 | atlas marker label plate (WORLD requests `_MarkerLabel(plateAsset:)`) |
| `labelPlateSelected` | `label_plate_selected` | 24×12 | 3 / 2 | 4 | ember-edged selected label plate |
| `navWell` | `nav/nav_well` | 24×20 (author 24², crop) | 4 / 2 | 4 | inactive tab's stamped well (NAV) |
| `navPlateActive` | `nav/nav_plate_active` | 32×28 (author 32², crop) | 4 / 4 | 8 | the raised lit active tab plate (NAV) |
| `btnPlateV2` | `btn_plate_v2` | 96×48 | 8 / 4 | 8 | the one primary plate per screen (`StrideButton` swaps when measured) |

Rules a frame obeys: interior transparent (never drawn); no once-only ornament
inside an edge run; no `#201C17`/`#14120F` pixels; brightest pixel ≤ `#7C7263`
(L 0.1722); key light upper-left; **no text, numeral or state** in the raster.

```dart
// panel_skin.dart
enum KitFrame { insetWell, slotWell, insetStage, stageFrame, pageSealed, slipPinned,
  ribbonLabel, tabPlate, journeyPlate, peekPlate, labelPlate, labelPlateSelected,
  navWell, navPlateActive, btnPlateV2 }

abstract final class KitFrames {
  static const Map<KitFrame, PanelSkin> authored;   // rows land with a device read
  static PanelSkin? of(KitFrame f);
  static double insetFor(KitFrame f);               // declared band×scale until measured; same before and after
}
```

```dart
// surfaces.dart
class KitPlate extends StatelessWidget {
  const KitPlate({
    required KitFrame frame,
    required Widget child,
    Color fill = StrideColors.surfaceCard,       // what the interior is painted; a well passes surfaceGround
    PanelSurface surface = PanelSurface.none,    // optional grain inside the band
    EdgeInsetsGeometry? padding,                 // added INSIDE the band (floored at 6 dp gap when framed)
    double? width, double? height,               // pass for a well; omit to shrink-wrap
  });
}
```

Well idiom (a sprite in a well — the `InsetWell` arithmetic carried over): pass
the sprite's display size as `width/height` **plus** `2 × KitFrames.insetFor(f)`;
`KitPlate.well(frame:, contentWidth:, contentHeight:, child:)` does that sum
for you and centres the child. Never wrap a `PixelAsset` in a `KitPlate`
smaller than the sprite — the `PixelAsset` assert will fire, correctly.

---

## 2. Tiles (`KitTile`) — repeated strips, `assets/ui/v1/kit/<name>.png`

| `KitTile` | Asset | Native (period × thickness) | Scale | Axis | Thickness dp | Used for |
|---|---|---|---|---|---|---|
| `ruleJournal` | `rule_journal` | 8×4 | 2 | h | 8 | ruled lines on `journalLeaf` (Adventure, Character ledger) |
| `ruleBench` | `rule_bench` | 8×4 | 2 | h | 8 | rules on `benchOak` (Craft) |
| `ruleChart` | `rule_chart` | 8×4 | 2 | h | 8 | rules on `chartVellum` (World strip) |
| `pocketRule` | `pocket_rule` | 96×12 (author 96×32, crop) | 1 | h | 12 | pocket dividers on the pack (Inventory) |
| `edgeTorn` | `edge_torn` | 64×12 (author 64×32, crop) | 1 | h | 12 | torn page foot (Craft sealed pages, slips) |
| `edgeSpine` | `edge_spine` | 16×64 (author 32×64, crop) | 2 | **v** | 32 wide | the book's spine at a page's left (Adventure, Character) |
| `caseStrap` | `case_strap` | 64×16 (author 64×32, crop) | 2 | h | 32 | the equipment case's strap (Inventory) |
| `railShelf` | `rail_shelf` | 384×72 | 1 | h | 72 | the station shelf (Craft) — plinth wells are `slotWell` plates placed over it |
| `railStrap` | `rail_strap` | 384×40 | 1 | h | 40 | the command rail's ground (Combat) |
| `journeyRoad` | `journey_road` | 16×32 (author 32², crop) | 2 | **v** | 32 wide | the road down the Skills journey's left rail |
| `navWelt` | `nav/nav_welt_v2` | 8×6 | 2 | h | 12 | the nav strap's stitch welt = the header shelf's stitch (one chassis) |
| `sheetEdge` | `nav/sheet_edge` | 8×6 | 2 | h | 12 | the docked sheet's top edge (World) |

```dart
// panel_skin.dart
enum KitTile { ruleJournal, ruleBench, ruleChart, pocketRule, edgeTorn, edgeSpine, caseStrap,
  railShelf, railStrap, journeyRoad, navWelt, sheetEdge }

@immutable final class KitStrip { final String assetPath; final int nativeWidth, nativeHeight, scale; final Axis axis;
  double get thickness; }   // nativeHeight×scale for h, nativeWidth×scale for v

abstract final class KitTiles {
  static const Map<KitTile, KitStrip> authored;
  static KitStrip? of(KitTile t);
  static double thicknessFor(KitTile t);          // declared; reserve it unconditionally
}
```

```dart
// pixel_asset.dart — EdgeStrip gains an axis; KitEdge wraps the registry
class EdgeStrip { const EdgeStrip({..., Axis axis = Axis.horizontal}); }   // existing ctors unchanged
class KitEdge extends StatelessWidget {
  const KitEdge({required KitTile tile, Color? fallbackColor, bool fallbackAtEnd = false});
  // horizontal: width ∞, height = thickness; vertical: height ∞, width = thickness
}
```

A **rule under a title** (rule + optional caps) is one widget so nobody
hand-assembles it: `KitRule(style: KitRuleStyle.journal | bench | chart, {String? title})`
— caps are `KitMark.ruleCapLeft/Right` when they exist, the run is the tile,
the fallback is a 1 px `separator` line at the same height (8 dp box).

---

## 3. Marks (`KitMark`) — discrete ornaments, `assets/ui/v1/kit/<name>.png`

| `KitMark` | Asset | Native | Scale | Display dp | Used for |
|---|---|---|---|---|---|
| `ruleOrnateA` | `rule_ornate_a` | 192×16 (author 192×32, crop) | 1 | 192×16 | the ornate rule under a name (Character, Encounter species plate) |
| `ruleOrnateB` | `rule_ornate_b` | 192×16 | 1 | 192×16 | second ornate rule (chapter openings, Skills overview) |
| `ruleCapLeft` / `ruleCapRight` | `rule_cap_l`, `rule_cap_r` | 12×4 each (cut from the rule masters) | 2 | 24×8 | ends of a `KitRule` — authored, never mirrored (key light) |
| `journeyWaystone` | `journey_waystone` | 24×32 (author 32², crop) | 2 | 48×64 | a level waystone on the journey line |
| `journeyLanternLit` | `journey_lantern_lit` | 32² | 2 | 64² | "you are here" |
| `journeyLanternUnlit` | `journey_lantern_unlit` | 32² | 2 | 64² | A-2 pencil remap of the lit lantern (0 generations) |
| `gaugeBracketLeft` / `gaugeBracketRight` | `gauge_bracket_l`, `_r` | 48×16 each (author 48×32, crop) | 2 | 96×32 | the gauge hangers under Combat's frame |
| `peekTab` | `peek_tab` | 48×12 (author 48×32, crop) | 2 | 96×24 | the leather tab on the World peek strip |
| `sheetGrip` | `sheet_grip` | 24×6 (author 24², crop) | 2 | 48×12 | the docked sheet's grip |
| `btnQuietCapLeft` / `btnQuietCapRight` | `btn_quiet_cap_l`, `_r` | 16×24 (author 24², crop) | 2 | 32×48 | ends of a quiet underlined action |

```dart
// panel_skin.dart
enum KitMark { ruleOrnateA, ruleOrnateB, ruleCapLeft, ruleCapRight, journeyWaystone,
  journeyLanternLit, journeyLanternUnlit, gaugeBracketLeft, gaugeBracketRight, peekTab,
  sheetGrip, btnQuietCapLeft, btnQuietCapRight }
@immutable final class KitOrnament { final String assetPath; final int nativeWidth, nativeHeight, scale; Size get size; }
abstract final class KitMarks { static const Map<KitMark, KitOrnament> authored; static KitOrnament? of(KitMark m); static Size sizeFor(KitMark m); }

// pixel_asset.dart
class KitOrnament extends StatelessWidget { const KitOrnament({required KitMark mark, Widget? fallback}); }
```

---

## 4. Surfaces — no new `PanelSurface` this round

The page model rides the eleven shipped grains (`journalLeaf`, `benchOak`,
`buckram`, `leather`, `oilcloth`, `steel`, `slate`, `chartVellum`, `cork`,
`planLinen`, `notable`). `chartVellum` ships without grain (99.4 % one ink);
NAV will re-roll it if the nav/kit budget leaves room and will announce a
swap in §8 — same name, same row, no call-site change. Ask for a new material
only with a screen that has no home in that list.

---

## 5. The docked sheet (`bottom_sheet.dart`) — WORLD consumes, NAV builds

```dart
enum SheetStop { peek, half, full }

class StrideSheet {
  // existing: StrideSheet({open, onDismiss, child, label}) — Craft, unchanged
  const StrideSheet.docked({
    required SheetStop stop,
    required ValueChanged<SheetStop> onStop,
    required Widget peek,          // the one-row peek content (64 dp; grows under Dynamic Type, min 64)
    required Widget child,         // half/full content (scrolls inside)
    double peekHeight = 64,
    double halfFraction = 0.36,    // clamp(0.36×body, 232, 300)
    double fullFraction = 0.70,
    double fade = 24,              // translucent fade above the sheet; NO scrim
    String? label,
  });
}
```

Behaviour (DIR-15 §1): drag snaps to the nearest stop, fling > 300 dp/s moves
one stop; grip tap peek→half, half/full→peek; the caller decides what a map
tap or marker tap does (`onStop`); Reduce Motion snaps. The sheet's top edge is
`KitTile.sheetEdge`, its grip `KitMark.sheetGrip`, its ground `leather`; a
`KitTile.navWelt`-class stitch is *not* repeated here (one welt per screen).
Must be the last child of a full-screen `Stack`, as today.

---

## 6. Tokens that change under you (theme, `stride_metrics.dart`)

| Token | Was | Now | Why |
|---|---|---|---|
| `StrideRadius.card` | 14 | **0** (`BorderRadius.zero`) | DIR-05 §1: square corners; "radius-14 rectangles at 34 call sites" is the tell |
| `StrideRadius.inner` | 10 | **0** | `SurfaceBlock`/`InsetWell` fallback squares off; wells are now `KitPlate`s |
| `StrideRadius.chip` / `gate` | 8 / 6 | **2** each (kept, retiring) | chips die screen by screen; until then they stop reading as pills |
| `StrideRadius.tabActive` | bottom 8 | **retired** (`@Deprecated`) | the active tab is a nine-patch plate |
| `StrideSpace.rhythmHero/Group/Row` | 24 / 16 / 8 | unchanged | the three rhythms already exist; use them, never `cardGap` on a rebuilt screen |
| `StrideTabBar.weltHeight` | 8 | **12** | nav_welt_v2 8×6 ×2 = the header shelf's 12 |
| `StrideGeometry.tabBarHeight` | 64 | 64 | stays |

The **"Claude-generated" tells** retired at kit level, so you inherit them:
one radius (square) everywhere; `PageGround` instead of a card at every tab
root; content-driven rules (`KitRule`) instead of a border per block; one
`btnPlateV2` primary per screen and quiet underlined actions
(`StrideButton.quiet` lands with `btn_quiet_cap_*`) instead of a button per
tile. Do not add a new radius or a new border colour; request a token.

---

## 7. What NAV guarantees, and when

| When (from publish) | Landed |
|---|---|
| ≤ 45 min | this contract; `REQUESTS_NAV.md` open; **the Dart scaffold** — every enum, registry (empty rows), `KitPlate`, `KitEdge`, `KitOrnament`, `KitRule`, `PageGround`, the token changes; `flutter analyze` clean; you can compile and lay out against it |
| ≤ 2 h | first frames (`insetWell`, `slotWell`, `stageFrame`, `ribbonLabel`, `tabPlate`) and the three plain rules registered; `StrideSheet.docked` |
| ≤ 4 h | the rest of the frames, tiles, marks; the bottom nav rebuilt; `_hi` remaps retired |
| continuous | requests served in small commits, DONE with hash |

A row that fails its device read is left `null` and named in §8 — your
fallback stays. Nothing in this contract moves a save, a health call, an
item, or a step cost.

---

## 8. Amendments (append-only, newest last)

- 2026-09-02 — contract published (this commit).
- 2026-09-02 — `pubspec.yaml` gains two packaged directories, `assets/art/v1/ui/`
  (screen-specific chrome, flat `ui/<team>_<name>.png`, requested by
  UI-INVENTORY) and `assets/art/v1/track/` (the Skills journey family,
  requested by PROD-UI-SKILLS). Each carries a `README.md` so the directory
  resolves before its first asset lands — an unresolvable directory entry is
  a hard build error, git tracks no empty directory, and `package-art.js
  --check` skips `.md`. **This is not the shared kit**: chrome every screen
  uses stays in `assets/ui/v1/`, declared file by file.
- 2026-09-02 — **the journey family is struck from §1–§3 and from NAV's
  production family.** `KitFrame.journeyPlate`, `KitTile.journeyRoad`,
  `KitMark.journeyWaystone`, `journeyLanternLit`, `journeyLanternUnlit` stay
  declared and permanently `null`; NAV authors none of them and spends no
  generations on them. SKILLS authors the journey itself per DIR-07 (four
  joint shapes, not two) into `assets/art/v1/track/`, and its widgets read
  `lib/ui/screens/skills/track_art.dart`. Anyone else wanting a journey mark
  asks SKILLS, not NAV.
