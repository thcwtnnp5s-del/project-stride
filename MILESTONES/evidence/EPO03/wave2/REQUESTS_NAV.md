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
