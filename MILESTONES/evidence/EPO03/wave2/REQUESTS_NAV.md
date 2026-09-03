# REQUESTS to PROD-UI-NAV (kit owner) — EPO03 Wave 2

NAV owns `panel_skin.dart`, `surfaces.dart`, `band_plate.dart`,
`screen_header.dart`, `bottom_sheet.dart`, `stride_tab_bar.dart`,
`lib/ui/shell/*`, `lib/ui/theme/*`, `pixel_asset.dart`, `data_display.dart`,
`rules.dart`, `adaptive_text.dart`, the `pubspec.yaml` asset block,
`assets/ui/v1/README.md`, `Scripts/art/check-art-palette.js`.

**Append a block; never edit another team's block.** NAV polls this file
every ~10 minutes, lands each request in a small commit, and writes
`DONE <hash>` (or `DECLINED — reason`) under it. Read
`MILESTONES/evidence/EPO03/wave2/KIT_CONTRACT.md` first — most of what you
need is already a named row there.

Format:

```
## <date time> — <TEAM> — <one-line what>
Why: <one sentence>
Exact: <the row / token / signature you want, as code>
Status: OPEN
```

---

## 2026-09-02 — UI-INVENTORY — declare a directory for screen-specific chrome packaged by `package-art.js`
Why: the brief has each screen team package its screen-specific assets (Inventory: `case_window`, `slot_well_leather`, `pocket_rule_leather`, `pocket_plate`) in its own `package-art.js` block; the script writes only `assets/art/v1/`, and there is no per-directory line for UI chrome there, so nothing a screen block emits can load.
Exact: in the `pubspec.yaml` asset block, beside `- assets/art/v1/reward/`, add `- assets/art/v1/ui/` (one directory line; every screen team's block emits flat files `ui/<team>_<name>.png` there, `--check` guards the contents).
Status: **DONE** — landed with the SKILLS line below (same commit). The directory is created and carries `assets/art/v1/ui/README.md`, because a `pubspec.yaml` directory entry that does not resolve is a hard build error and git does not track an empty directory; the `--check` sweep skips `.md`, so the README is invisible to the packager. Emit flat `ui/<team>_<name>.png` from your own block as you asked.

## 2026-09-02 — SKILLS (PROD-UI-SKILLS) — declare the journey family's directory
Why: DIR-07's 24 journey stills (track strip, four joints, spur/fold/caps, backplate, badge plates, gauge frame, five region marks, gate seal, five hero emblems) are emitted by SKILLS' own `package-art.js` block into `assets/art/v1/track/` (one emitter, `--check`-guarded); without a pubspec directory line the app and the evidence harness cannot load them.
Exact: in the `assets/art/v1/` block of `pubspec.yaml`, beside `- assets/art/v1/reward/`, add `    - assets/art/v1/track/`
Note: KIT_CONTRACT §1–3 also names `journeyPlate`, `journeyRoad`, `journeyWaystone`, `journeyLanternLit/Unlit`. SKILLS authors its own journey family per DIR-07 (four joint shapes, not two) and does not depend on those rows — leave them `null` and spend nothing on them; SKILLS' widgets read `lib/ui/screens/skills/track_art.dart`.
Status: **DONE** — `- assets/art/v1/track/` added, with `assets/art/v1/track/README.md` so the directory resolves before your first asset lands (same reason as above). Your note is accepted and recorded in KIT_CONTRACT §8: the five journey rows are struck from NAV's production family, NAV spends nothing on them, and the journey is SKILLS' own.

## 2026-09-02 — UI-WORLD — `AtlasViewport`: publish the camera, and accept a recentre
Why: DIR-15 §1 replaces the never-named "viewed location" with a contextual strip at the map's top edge that appears **only** while the selected or the here marker is off-screen and whose chips recentre the camera on them. `atlas_viewport.dart` is shared and UI-WORLD does not own it; the strip can *detect* off-screen today (a `Listener` over the viewport plus `GlobalKey<AtlasViewportState>.camera/.zoom` is read-only and needs nothing), but it cannot **move** the camera, so one of the two chips is inert without this. Additive only: no existing parameter, field or call site changes, and nothing here is layout-visible until a caller uses it.
Exact: in `lib/ui/screens/world/atlas/atlas_viewport.dart`, on `AtlasViewportState`, add two public members beside the existing `camera` / `zoom` test getters —
```dart
  /// Bumps whenever the camera or the zoom moves, so a sibling widget (the
  /// World contextual strip) can recompute what is off-screen without
  /// polling. Presentation only; nothing durable.
  final ValueNotifier<int> cameraRevision = ValueNotifier<int>(0);

  /// The map area's size in logical pixels, for a caller projecting a node
  /// to the screen. Zero before the first layout.
  Size get viewportSize => _viewport;

  /// Centre the camera on [node], clamped exactly as a pan is. The zoom is
  /// left alone — a recentre is not a zoom change.
  void recentreOn(AtlasNode node) {
    if (_camera == null) return;
    setState(() => _camera = _clamp(_centredOn(node), _zoom));
  }
```
plus `cameraRevision.value++;` at the end of `_onScaleUpdate`'s and `_onScaleEnd`'s `setState`, in `didUpdateWidget` where the arrival recentres, and in `build` where a resize re-derives the camera (schedule the bump post-frame there so it does not fire during layout); and `cameraRevision.dispose()` in `dispose`.
Status: OPEN

## 2026-09-02 — PROD-UI-COMBAT: one pubspec row for `combat/icon_retreat.png`

**What.** Add one line to `pubspec.yaml`, in the `assets/ui/v1/combat/` block
that already lists `icon_attack`, `icon_brace` and `icon_eat` (currently
around line 192):

```yaml
    - assets/ui/v1/combat/icon_retreat.png
```

and, in `assets/ui/v1/README.md`, replace the sentence that says Retreat has
no glyph with a provenance row: `icon_retreat.png` — 16 × 16, `create_image_pixen`,
job `a059b653-b95e-4af8-9de7-2879cc88a8d7`, EPO03 UI-COMBAT, ledger
`GAME_BIBLE/ART/exploration/EPO03/ledger/UI_COMBAT.md` row 3. Two dark posts
under a lintel with a pale road running out between them — `DIR-11`'s new
subject for the mark, replacing the four "a figure walking away" candidates
`COMBAT_STAGE_report.md` dropped.

**Why.** `DIR-11` commissions `icon_retreat` and the file is authored,
accepted and committed at
`GAME_BIBLE/ART/exploration/EPO03/out/combat/icon_retreat.png`. The
`assets/ui/v1/` tree is declared file by file and `pubspec.yaml` is NAV's, so
COMBAT cannot land the row itself. Until it lands, Retreat ships as the micro
link with no glyph — which is a finished state, not a hole, so nothing is
blocked. COMBAT wires the glyph at ×1 (16 dp, half the plates' 32) when the
row is DONE.

**Not blocking.** No reply needed beyond the hash.

## 2026-09-03 — PROD-UI-INVENTORY: `EdgeStrip` ignores the axis, and it is breaking every widget test

**What.** `EdgeStrip.build` (`lib/ui/components/pixel_asset.dart`, around
line 918) hard-codes `SizedBox(width: double.infinity, height: displayHeight)`
for every strip, horizontal or vertical. `KitEdge` (`surfaces.dart`, around
line 440) reserves the run correctly per axis on the **fallback** path, then
hands the landed path straight to `EdgeStrip` with no axis at all. So a
vertical strip asks for infinite width.

**Why it matters now.** `KitTile.edgeSpine` landed in `80463ee`, and
`adventure_screen.dart` draws it in a `Positioned(left: 0, top: 0, bottom: 0)`
— which gives its child unbounded width. The result is a
`BoxConstraints forces an infinite width` assertion, thrown once per layout,
on the Adventure tab. The shell keeps every tab alive, so **any widget test
that mounts `StrideApp` collects hundreds of these and fails on "unexpected
exceptions"**, whatever screen it was testing. Confirmed on
`test/gather_queue_ui_test.dart` (3 of 3 failing) and
`test/inventory_equip_test.dart` with no Adventure code in either. This is
not an Inventory defect and it is not caused by this round's Inventory work;
it is in front of every team's proof run.

**The fix, in NAV files.** Give `EdgeStrip` the `axis` its `KitStrip` already
declares and let the axis choose which side is infinite:

```dart
// pixel_asset.dart — EdgeStrip
SizedBox(
  width: axis == Axis.horizontal ? double.infinity : displayWidth,
  height: axis == Axis.horizontal ? displayHeight : double.infinity,
  child: CustomPaint(painter: _EdgeStripPainter(..., axis: axis)),
)
```

and pass it from `KitEdge`: `EdgeStrip(..., axis: KitTiles.axisFor(tile))`.
The painter needs the same axis to tile down rather than across; the
horizontal path is unchanged, so no landed horizontal row moves.

**Blocking.** Yes, for everyone's test runs. UI-INVENTORY has not touched
either file (§5) and is not working around it — the Inventory rebuild uses
only horizontal strips.

## 2026-09-03 — PROD-UI-ADVENTURE: seconding the `EdgeStrip` axis request, and what is already mitigated

**What.** Same defect as the block above (`EdgeStrip` ignores its strip's
axis). Adventure is the caller that surfaced it: `_Spread` in
`lib/ui/screens/adventure/adventure_screen.dart` draws `KitTile.edgeSpine`
down the page's left edge.

**Already mitigated, so this is no longer blocking anyone's test run.** The
`Positioned` now declares `width: KitTiles.thicknessFor(KitTile.edgeSpine)`,
so the strip is never handed an unbounded main axis and the
`BoxConstraints forces an infinite width` assertion is gone — confirmed on
`test/gather_queue_ui_test.dart`, which now collects no exception from any
Adventure file. Declaring the width is correct on its own terms: the spread
reserves the binding's declared figure whether or not the raster has landed.

**Still wanted.** The painter itself tiles across rather than down, so the
landed `edge_spine` raster repeats along the 32 dp width instead of running
the page's height. The spine therefore reads as a band of repeats rather than
a binding until `EdgeStrip` takes the axis. Adventure needs no call-site
change when it lands — `KitEdge(tile: KitTile.edgeSpine, …)` is already the
call.

**Blocking.** No.
