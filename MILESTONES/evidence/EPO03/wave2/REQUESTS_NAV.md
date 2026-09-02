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
Status: OPEN

## 2026-09-02 — SKILLS (PROD-UI-SKILLS) — declare the journey family's directory
Why: DIR-07's 24 journey stills (track strip, four joints, spur/fold/caps, backplate, badge plates, gauge frame, five region marks, gate seal, five hero emblems) are emitted by SKILLS' own `package-art.js` block into `assets/art/v1/track/` (one emitter, `--check`-guarded); without a pubspec directory line the app and the evidence harness cannot load them.
Exact: in the `assets/art/v1/` block of `pubspec.yaml`, beside `- assets/art/v1/reward/`, add `    - assets/art/v1/track/`
Note: KIT_CONTRACT §1–3 also names `journeyPlate`, `journeyRoad`, `journeyWaystone`, `journeyLanternLit/Unlit`. SKILLS authors its own journey family per DIR-07 (four joint shapes, not two) and does not depend on those rows — leave them `null` and spend nothing on them; SKILLS' widgets read `lib/ui/screens/skills/track_art.dart`.
Status: OPEN
