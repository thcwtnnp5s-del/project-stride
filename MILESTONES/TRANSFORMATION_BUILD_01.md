# Transformation Build 01 — record

**Opened / implemented:** 2026-08-17 · **Branch:** `playable-phase-2-multiregion`
(on top of the device-tested Phase 2 build `852cf72`; the docs-only handoff
`017262e` sits between).
**Owner direction:** the "Transformation Build master prompt" — one large,
coordinated pass so the next iPhone build reads as a game rather than a systems
prototype. **Status:** implementation complete, awaiting the owner's device
review (§7 script).

---

## 1. What materially changed from the last device build

| Surface | Before (`852cf72`) | Now |
|---|---|---|
| **World** | one static 384 × 640 picture, travel rows above it | a **pannable / pinch-zoomable atlas** (768 × 1376 world px, PixelLab base at ×2) with **tappable location targets**, landmarks, scatter props, drifting cloud shadows, forest mist, snow flurries and forge smoke; a selection panel beneath with the same truthful travel copy and the **Travel** button; dotted routes that follow the drawn tracks |
| **Adventure stage** | Traveler rests on gather frame 0 | the Traveler plays **12 rotating ambient scenes** (stretch, drink, eat, pack check, wipe brow, dozing by a fire, dangling yarn for the cat, petting the cat, …) with the **orange cat** as a companion layer; a gather still interrupts and takes priority; **each gather node's own vignette** stands on the stage |
| **Items** | 9 of 24 items rendered the placeholder slab, including 4 craft outputs | **all 24 items have PixelLab icons** |
| **Skills** | 5 temporary code icons, two hafted tools alike | **OD-04 round 2**: leaf sprig, log round, ore lump, anvil, two-handled pot — five silhouette families, 24 px native |
| **Economy** | banked ≈ 5,123 from Phase 2 validation | **banked = 0 at first launch** of this build; `TOTAL WALKED` unchanged; cursor unchanged (`DECISIONS/0018`, state v3) |
| **Install** | Debug build, launches only tethered | **Release build via `Scripts/ios/build-release-device.sh`**, launches from the Home Screen unplugged (`TECHNICAL/IOS_DEVICE_INSTALL.md`) |

Unchanged by design: gathering, travel, crafting, skills, equipment, save
atomicity, foreground-only health sync, the six-tab shell.

## 2. World atlas — architecture

- `assets/content/v1/atlas/atlas_layout.json` — schema v1: world size, scale,
  base tiles, locations (world px + hit radius + optional landmark anchor),
  routes (polylines), props, overlays (frames, drift, **opacity**).
- `lib/runtime/atlas_layout.dart` — strict parser + `validateAgainst(content)`;
  loaded once at `StrideSession.start`; a bad layout falls back to the old
  list presentation, never a crash.
- `lib/ui/screens/world/atlas/` — `AtlasScene` (layout ⋈ session projections;
  BFS "reached by way of"), `AtlasViewport` (pan/zoom 1–2×, pixel-snapped,
  camera centred on the current place, one `TickerMode` gate for all motion),
  layers: base → routes → props+landmarks → overlays → markers/labels/hit
  targets → selection panel. `SessionController.travel` is the only command.
- Not a joystick: no avatar, no drag token, no walkable field. The pulse under
  the current place is a caption in the shape of a circle.

## 3. Ambient system

`AmbientScene/Track/Layer/SceneSet` (`lib/ui/components/ambient_scene.dart`),
`AmbientPlayer` (one `AnimationController`, no timers, lifecycle-paused,
bounded visits of 4 scenes then rest), `AmbientStage` (gather priority). Table
in `lib/ui/icons/ambient_assets.dart`, footprints measured by
`package-art.js`. Grants nothing, reads nothing, persists nothing.

## 4. PixelLab production (all under `GAME_BIBLE/ART/exploration/TRANSFORMATION_01/`)

| Stream | Accepted | Withheld / rejected | Spend (approx.) |
|---|---|---|---|
| C world | atlas base 384×688, 5 landmarks (2 not placed), 7 props, 5 overlay families (22 frames) | water shimmer (4 fails), cloud loop | ~170–270 |
| E ambient | 13 Traveler sequences + 1 pair, cat (9 actions), fire, yarn — 185 frames | 3 sequences withheld after QA (axe_inspect, pick_inspect, read); 8 rejected in-round | ~40 |
| F items | 9 icons, 8 node vignettes, 5 skill icons (24 + 12 px) | — | 110 |
| lead | 1 inpaint (thicket mark) | | 20 |

Balance: 1,119 → ~780 generations. Independent Visual QA verdicts and the
lead's dispositions are appended to each stream README (`items/`, `world/`,
`ambient/`). Category-D escalation for the owner: skill icons ship 24-native
at ×1 (a density exception to the ×2 UI grid).

## 5. Steps / reset — `DECISIONS/0018`

State version 3. Migration table `StateMigrations`: v1→v2 (0016, re-bases),
v2→v3 (0018, re-bases); a future step re-bases only if it says so.
`EconomyEpoch.establishedAtStateVersion` makes each re-basing exactly-once per
version. `totalGranted`, `totalObserved`, `totalSpent`, slices, watermarks,
cursor and sync count are byte-identical across the migration (asserted).
Tests: `packages/stride_core/test/transformation_epoch_test.dart` (24) cover
history-intact, banked 0, cursor unmoved, repeat sync grants 0, new steps grant
once, spending after reset, save→reload, no second migration, v1→v3 chain.
Frozen `v3_baseline.save` (+30 bytes = the new field). v1/v2 fixtures untouched.

## 6. Verification

`Scripts/verify.sh --strict`, `flutter test` (app), `dart test` in
`stride_core` (546) and `stride_storage` (108), `package-art.js --check`, the
UI-boundary / single-writer / origin-privacy / core-purity guards. Goldens
regenerated once for the new art (world, adventure, character, craft, skills)
and reviewed by eye and by Visual QA.

## 7. Physical-device test script (owner)

1. **Install** — Mac: update clone, `git checkout playable-phase-2-multiregion`,
   copy `ios/Flutter/Local.xcconfig.example` → `Local.xcconfig` with your Team
   ID, plug in the iPhone, `bash Scripts/ios/build-release-device.sh`. Trust
   the developer / enable Developer Mode if asked. **Unplug.**
2. **Unplugged launch** — tap Project Stride on the Home Screen. It must open.
3. **Zero balance** — header shows **0 banked steps**; `TOTAL WALKED` still
   ≈ 464,946+ (history intact). Note the number.
4. **Startup sync** — after the first frame the sync runs; if you have walked
   since the last Phase 2 sync, banked rises by exactly those steps and
   `TOTAL WALKED` by the same amount.
5. **Duplicate sync** — tap **Sync steps** immediately: banked must not move.
6. **Walk** — walk 500+ steps, reopen: banked rises once by that amount.
7. **World** — drag the atlas around, pinch to zoom, tap Whispering Woods:
   panel shows cost 600 and **Travel**; tap Frostmere: no button, "reached by
   way of Stonefall Mine". Travel when affordable; the camera re-centres and
   the pulse moves. Watch mist / snow / smoke for a few seconds; nothing should
   stutter while panning.
8. **Adventure** — leave the stage alone ~30 s: the Traveler plays a few
   scenes with the cat and settles. Gather once: the gather animation plays,
   loot/XP as before, then ambient resumes. Note each node's vignette.
9. **Inventory / Craft / Skills** — no placeholder slabs; bronze tools distinct
   from training tools; five skill icons distinct at a glance.
10. **Persistence** — force-quit, cold launch: balance, location, inventory,
    skills, equipped tools all intact; no flash of zeros.
11. **After 7 days** the free-team profile expires: rerun step 1 (reinstall in
    place; the save survives). Never delete the app to "refresh".

## 8. Known issues

- **BLOCKER:** none known.
- **GAMEPLAY/DESIGN:** `traveler_stretch` peak reads "cheer" and `pushups_side`
  prone frames read "collapsed" at ×2 (kept, owner to judge on device);
  `node_tin_seam` reads "boulder", weakly "ore"; the atlas pulse/overlays only
  run once the platform reports `resumed` (expected at launch — one glance);
  skill icons at 24-native ×1 vs the ×2 UI grid (category D).
- **COSMETIC:** two logs / two planks are hue-twins; `pine_plank` alone reads
  paper; foraging sprout low-contrast in grey; Frostmere/Haven's Rest landmark
  PNGs packaged but not placed; the isometric hamlet hero vignette vs the
  top-down atlas are two cameras for one place; water shimmer not delivered;
  three ambient sequences withheld pending a PixelLab correction round.

## 9. Recommended next milestone

Play this build for several days. On current evidence the next *system* is
still the **combat vertical slice** (`DECISIONS/0003`, retreat-not-death,
one region, ~3 archetypes) — the atlas and the ambient life now give it a
world to sit in, and the bronze tier finally has icons to equip. Fold in a
PixelLab correction round for the three withheld ambient scenes and the two
weak nodes, and audio (`OD-06`) once the owner resends the source references.
