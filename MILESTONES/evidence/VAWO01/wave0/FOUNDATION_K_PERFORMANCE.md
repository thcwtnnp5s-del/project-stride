# FOUNDATION-K — Performance / Mobile Rendering Audit (VAWO01, wave 0)

**Role:** Performance / Mobile Rendering Auditor · **Mode:** read-and-report only
**Date:** 2026-09-01 · **Branch at audit:** `presentation-combat-evolution-01`
**Repo root:** `C:\Users\jwspa\Downloads\ProjectStride_ClaudeCode_Handoff_COMPLETE\ProjectStride`

Every figure below is measured from the working tree at the branch head, not
estimated. Decoded-memory figures are `width × height × 4` bytes (Flutter
decodes every PNG to RGBA8888 regardless of the file's own colour type — the
20 colormap PNGs in `assets/ui/v1/` are no cheaper in memory than the RGBA ones).

**The charge:** do not ship a beautiful screen that runs badly on the iPhone.
The honest headline is that this app is in much better shape than that warning
implies. The ticker discipline is already correct and already documented; the
scaling discipline makes a downscaled image structurally unrepresentable. There
are exactly **four** real exposures, and all four are things the coming work
would introduce rather than things already broken.

---

## 0 · The four findings that matter

| # | Finding | Measured | Where it bites |
|---|---|---|---|
| **K-1** | **The image cache is never configured.** Flutter's default `imageCache.maximumSize` is **1,000 entries**. The bundle ships **871 PNGs**. | 871 / 1000 = **87.1 % of the entry cap consumed today** | The overhaul adds ~800 files. Past 1,000 the cache evicts entries that animations are about to re-request — a re-decode mid-sequence, i.e. a dropped frame in an 8-frame cycle. The **byte** cap (100 MiB) is not the binding constraint: mean decoded size is 23.8 KiB, so entries bind **4.3× sooner** than bytes. |
| **K-2** | **Hidden tabs stop ticking but do not stop rebuilding or laying out.** `IndexedStack` keeps all six screens alive; each screen's `build` calls `SessionScope.of(context)` (an `InheritedNotifier`), so one `notifyListeners()` marks **all six** screen elements dirty. `IndexedStack` paints one child but lays out all of them. | World tab rebuilds `AtlasScene.build()` (6 fresh collections) and re-lays-out a **6144 × 6144** `Stack` of ~120 positioned children on every session notify, offstage | Every gather completion, every step sync, every craft tick, from any tab |
| **K-3** | **`Opacity` over the world overlays is cheap only because each one wraps exactly one image.** A single `drawImageRect` accepts opacity directly; a *multi-child* subtree forces a real `saveLayer`. | A dragon at layout `scale: 6` occupies 68 × 31 native → **408 × 186 logical → 1224 × 558 device px = 2.73 MB offscreen per creature per frame** | The planned dragons/fairies. If a creature becomes `Opacity(child: Stack([body, wings, glow]))`, 12 of them is **32.8 MB of saveLayer traffic per frame**. This is the single sharpest cliff in the plan. |
| **K-4** | **There is no performance test, benchmark, profiling harness, or CI performance job anywhere in the repository.** | 0 hits for `benchmark`, `Timeline`, `addTimingsCallback`, `flutter drive`, `--profile` across `lib/`, `test/`, `integration_test/`, `Scripts/`, `.github/` | Nothing will catch a regression from any of the above. The budget in §7 is therefore prose unless §10's rules are made mechanical. |

---

## 1 · The current asset payload

### 1.1 Totals

| Category | Files | On disk | Decoded (RGBA8888) |
|---|---:|---:|---:|
| **Audio — music** (`.m4a`, AAC 192 kbps, 150 s each) | 5 | **17,294,274 B (16.49 MB)** | streamed, not decoded to RAM |
| **Audio — SFX** (`.wav`, PCM 16-bit stereo 44.1 kHz) | 5 | **1,164,630 B (1.11 MB)** | 1.11 MB (already PCM) |
| **Images** (`.png`) | **871** | **1,970,399 B (1.88 MB)** | **21,189,256 B (20.21 MiB)** |
| **Data** (`.json`) | 11 | 118,599 B (0.11 MB) | — |
| **Docs shipped in tree** (`.md`, not bundled) | 4 | 21,319 B | — |
| **TOTAL `assets/`** | **896** | **≈ 20.57 MB of bundled payload** | **≈ 21.3 MiB image+SFX resident worst case** |

Two ratios worth writing down, because the budget in §7 rests on them:

- **Compression ratio of this art: 10.75 : 1** (21,189,256 decoded ÷ 1,970,399
  on disk). Flat-palette pixel art compresses extraordinarily well, which is
  why the *disk* figure is a bad proxy for the cost. 1 MB of new PNG is
  ~10.8 MiB of decoded texture.
- **Mean decoded size per PNG: 23,822 B (23.3 KiB).** This is what makes the
  entry cap bind before the byte cap (K-1).

**Audio is 90 % of the bundle and 0 % of the memory problem.** Five 150-second
tracks at 192 kbps are 3.6 MB each. Images are 9 % of the bundle and 100 % of
the texture-memory problem. These are two independent budgets and must not be
traded against each other.

### 1.2 Decoded memory by directory

| Directory | PNGs | Decoded | Note |
|---|---:|---:|---|
| `assets/art/v1/world/` | 7 | **5,185,344 B (4.95 MiB)** | `atlas_base.png` alone is 4,194,304 B — **19.8 % of all image memory in the product** |
| `assets/art/v1/combat/` | 262 | 4,605,632 B (4.39 MiB) | enemy/traveler tracks + 4 backdrops |
| `assets/art/v1/ambient/` | 240 | 3,362,816 B (3.21 MiB) | activity loops, micro-idles |
| `assets/art/v1/location/` | 10 | 2,703,360 B (2.58 MiB) | 384 × 176 vignettes ×2 variants |
| `assets/art/v1/work/` | 15 | 1,953,792 B (1.86 MiB) | gather backdrops + props/stations |
| `assets/art/v1/env/` | 218 | 1,705,992 B (1.63 MiB) | world-map overlay frames |
| `assets/art/v1/node/` | 24 | 843,776 B (824 KiB) | resource-node vignettes |
| `assets/art/v1/item/` | 59 | 543,744 B (531 KiB) | 48² item icons |
| `assets/art/v1/anim/` | 14 | 229,376 B (224 KiB) | gather + traveler west walk |
| `assets/art/v1/portrait/`, `sprite/` | 2 | 32,768 B | 64² |
| `assets/ui/v1/` | 20 | 19,504 B | nav/skill/glyph, 12–24 px |

### 1.3 The 30 largest individual assets

| # | Bytes | Dimensions | Path |
|---:|---:|---|---|
| 1 | 3,691,264 | 150 s AAC | `assets/audio/v1/music/music_haven_01.m4a` |
| 2 | 3,681,318 | 150 s AAC | `assets/audio/v1/music/music_whispering_woods_01.m4a` |
| 3 | 3,650,561 | 150 s AAC | `assets/audio/v1/music/music_stonefall_mine_01.m4a` |
| 4 | 3,636,602 | 150 s AAC | `assets/audio/v1/music/music_forgotten_hollow_01.m4a` |
| 5 | 3,634,529 | 150 s AAC | `assets/audio/v1/music/music_frostmere_01.m4a` |
| 6 | **521,346** | **1024 × 1024** | **`assets/art/v1/world/atlas_base.png`** |
| 7 | 352,878 | 2.0 s PCM | `assets/audio/v1/sfx/sfx_craft_cooking_01.wav` |
| 8 | 282,318 | 1.6 s PCM | `assets/audio/v1/sfx/sfx_gather_foraging_01.wav` |
| 9 | 176,478 | 1.0 s PCM | `assets/audio/v1/sfx/sfx_gather_woodcutting_01.wav` |
| 10 | 176,478 | 1.0 s PCM | `assets/audio/v1/sfx/sfx_gather_mining_01.wav` |
| 11 | 176,478 | 1.0 s PCM | `assets/audio/v1/sfx/sfx_craft_smithing_01.wav` |
| 12 | 79,057 | 384 × 640 | `assets/art/v1/world/region_map.png` |
| 13 | 45,586 | 384 × 176 | `assets/art/v1/location/forgotten_hollow.png` |
| 14 | 37,074 | 384 × 176 | `assets/art/v1/location/havens_rest.png` |
| 15 | 34,213 | JSON | `assets/content/v1/contracts.json` |
| 16 | 33,961 | 384 × 176 | `assets/art/v1/location/alt_whispering_woods.png` |
| 17 | 27,771 | 384 × 176 | `assets/art/v1/location/alt_forgotten_hollow.png` |
| 18 | 27,647 | 384 × 176 | `assets/art/v1/location/alt_frostmere.png` |
| 19 | 25,619 | 384 × 176 | `assets/art/v1/work/bg_woodcutting.png` |
| 20 | 24,594 | 384 × 176 | `assets/art/v1/location/whispering_woods.png` |
| 21 | 22,895 | 384 × 176 | `assets/art/v1/work/bg_foraging.png` |
| 22 | 22,473 | 384 × 176 | `assets/art/v1/location/stonefall_mine.png` |
| 23 | 21,534 | 384 × 176 | `assets/art/v1/work/bg_mining.png` |
| 24 | 19,853 | 384 × 176 | `assets/art/v1/location/alt_havens_rest.png` |
| 25 | 19,665 | JSON | `assets/content/v1/recipes.json` |
| 26 | 19,141 | 384 × 176 | `assets/art/v1/location/frostmere.png` |
| 27 | 18,006 | JSON | `assets/content/v1/atlas/atlas_layout.json` |
| 28 | 16,583 | 384 × 176 | `assets/art/v1/location/alt_stonefall_mine.png` |
| 29 | 16,393 | 384 × 176 | `assets/art/v1/work/bg_woodworking.png` |
| 30 | 16,027 | 384 × 176 | `assets/art/v1/work/bg_smithing.png` |

### 1.4 Images whose pixel dimensions exceed their display size

**There are none, and the architecture makes it structurally impossible.**

`lib/ui/components/pixel_asset.dart` takes a *native size and an integer scale*,
never a width. Displayed size is `native × scale` with `scale ≥ 1`, so an image
can only ever be **magnified**. `_RenderExactSizeBox.performLayout` (same file,
~L520) throws a `FlutterError` in debug if a parent offers less room than the
declared size, so the silent Flutter failure mode — parent tightens the
constraint, `SizedBox` honours it, sprite renders at 4.7× instead of 5× with no
overflow stripe — is converted into a loud one. `Scripts/check-ui-boundary.sh`
confines `Image.asset|file|network|memory`, `DecorationImage` and `paintImage`
to that one file.

The one measurable waste is deliberate and small. `PixelScene` (same file, L155+)
**clips** rather than scales: 384 px-wide scene art on a 360 dp phone loses
6.25 % of its decoded pixels, on a 320 dp phone 16.7 %. Across the 25 scene
images (`location/` + `work/`, 4,657,152 B decoded) that is **291 KiB wasted on
a 360 dp device, 778 KiB on a 320 dp device**. The alternative — non-integer
downscaling of a palisade of evenly spaced posts — is worse, and the record
says so. Not a defect; noted so it is not rediscovered.

**Distribution of PNG dimensions** (all 871): the modal sizes are 64² (157),
56² (147), 48² (85), 96² (65), 40² (56). Exactly **one** image exceeds 384 px on
either axis: `atlas_base.png`.

---

## 2 · The world map — the texture-memory question, answered exactly

### 2.1 Is the atlas one image or tiled?

**Architecturally tiled; today, one tile.**

`assets/content/v1/atlas/atlas_layout.json` declares `base.tiles` as an array.
It currently contains exactly one entry:

```json
"scale": 6,
"world": { "width": 6144, "height": 6144 },
"base": { "tiles": [ { "asset": "world/atlas_base", "x": 0, "y": 0,
                       "width": 1024, "height": 1024 } ] }
```

`AtlasBaseLayer.build` (`lib/ui/screens/world/atlas/atlas_layers.dart:47–77`)
iterates `scene.layout.tiles` and emits one `Positioned(PixelAsset(...))` per
tile at `tile.x * scale, tile.y * scale`. The tiling machinery exists and is
exercised by exactly one tile.

### 2.2 The numbers

| Quantity | Value |
|---|---|
| Source file | `assets/art/v1/world/atlas_base.png`, 521,346 B on disk |
| Pixel dimensions | **1024 × 1024** |
| **Decoded memory** | **1024 × 1024 × 4 = 4,194,304 B = 4.000 MiB exactly** |
| GPU-resident copy | a further ~4 MiB while the texture is uploaded and the CPU bitmap is still referenced → **~8 MiB peak for the base tile alone** |
| Layout scale | `6` (`atlas_layout.json`) |
| World size in logical dp | **6144 × 6144** |
| Drawn size | `PixelAsset(nativeWidth: 1024, nativeHeight: 1024, scale: 6)` → `Image.asset(width: 6144, height: 6144, fit: BoxFit.fill, filterQuality: none)` |
| Zoom range | `AtlasZoom.forScale(6)`: floor `1/6 ≈ 0.1667`, initial `2/6 ≈ 0.333`, max `4/6 ≈ 0.667` |

**4.000 MiB is the number.** It is 19.8 % of all image memory in the product and
it is unavoidable: the world *is* that painting. The important corollary is that
**it must not grow**. A 2048² remaster would be **16.78 MiB decoded** — a 4×
increase for a 2× linear gain, and on a 3 GB device (§7.0) it alone would exceed
a third of the whole image budget.

### 2.3 Is it cached? Is it downscaled before decode?

**Cached: yes, by the framework's default `ImageCache`, with no configuration.**
There is no `PaintingBinding.instance.imageCache.maximumSize`/`maximumSizeBytes`
assignment anywhere in `lib/`. Grep confirms zero hits. See K-1.

**Downscaled before decode: no, deliberately and correctly.**
`pixel_asset.dart:142–150` carries the reasoning verbatim:

> `cacheWidth` / `cacheHeight` are DELIBERATELY not set. They resample at decode
> time, permanently, before `filterQuality` is ever consulted — on a 20 px
> source that drops whole columns.

This is right and must not be "optimised". `cacheWidth` on pixel art is a
correctness bug, not a performance win. The atlas is **magnified 6×**, so there
is nothing to reclaim: the decoded bitmap is already the smallest honest
representation. Likewise there are no `2.0x/`/`3.0x/` variant directories,
because `AssetImage` would resolve them by `devicePixelRatio` and change
`ImageInfo.scale` out from under the explicit width — also documented in place.

**Conclusion: the single biggest texture-memory risk is quantified at exactly
4.000 MiB and is already as small as it can honestly be.** The risk is not the
atlas as it stands. The risk is what gets layered on top of it (§3.2, §9).

### 2.4 The world-sized subtree — the structural hazard

`AtlasViewport.build` (`atlas_viewport.dart:~400–450`) produces:

```
ClipRect > GestureDetector > TickerMode > OverflowBox(6144×6144)
  > Transform(translate, scale) > SizedBox(6144×6144) > Stack
      ├ AtlasBaseLayer      (RepaintBoundary, 6144×6144)
      ├ AtlasRouteLayer     (RepaintBoundary, CustomPaint 6144×6144)
      ├ AtlasLandmarkLayer  (RepaintBoundary, 6144×6144)
      ├ AtlasOverlayLayer   (RepaintBoundary, 6144×6144)
      └ AtlasMarkerLayer    (hit-testing layer)
```

Two consequences the coming work must respect:

1. **Every layer is a `RepaintBoundary` whose bounds are 6144 × 6144 logical px.**
   At DPR 3 that is 18,432 device px per side — beyond Metal's 16,384 max
   texture dimension, so the raster cache will refuse these layers outright
   (which is the correct outcome; painting stays cull-rect-bounded). But it
   means **any widget that induces a `saveLayer` over the world stack** —
   `Opacity`, `ColorFiltered`, `ShaderMask`, `BackdropFilter`, `ClipPath` with
   `Clip.antiAliasWithSaveLayer` — asks the engine for an offscreen at those
   bounds. It survives today only because the `ClipRect` sits *above* the whole
   thing and the device clip intersects the request. That is one refactor away
   from a black screen. Rule R-6 in §10.
2. **The whole world Stack is built and laid out even when off-camera.** The
   `Stack` has no viewport culling: all ~120 positioned children exist as
   elements and render objects regardless of where the camera is. Adding N
   animated creatures adds N elements to that Stack whether or not any of them
   is on screen. Rule R-3.

### 2.5 Visible-overlay count, measured

At the **survey floor** (`zoom = 0.1667`, the furthest out a 430 dp phone can
pinch on a 6144-wide world) the viewport covers `430/0.1667 × 932/0.1667 =
2580 × 5592` world px — **38 % of the world area**. Of the 30 overlays declared,
that is **≈ 11 in frame simultaneously**. At the opening view (`zoom = 0.333`)
the viewport covers 9.5 % of the world, ≈ 3–8 in frame depending on clustering.

**11 is the shipped, accepted, device-tested number.** The budget in §7 is
calibrated to it rather than invented.

---

## 3 · Animation infrastructure — every ticker in the app

### 3.1 The inventory

Sixteen vsync-driven clocks exist. **All sixteen are disposed correctly**
(verified: every file with a controller has a matching `dispose()` that calls
`.dispose()` on it before `super.dispose()`; `atlas_layers.dart` has 5 clocks and
5 matching disposals plus two listener detachments at L1540–1541).

| # | file:line | Drives | Disposed | Pauses when hidden? |
|---|---|---|---|---|
| 1 | `ui/screens/world/atlas/atlas_layers.dart:368` | `createTicker` — **all ~30 world-map overlays on one ticker** | ✅ L444 | ✅ **double-gated**: viewport `TickerMode` (lifecycle+reduce-motion) *and* shell per-tab `TickerMode` |
| 2 | `atlas_layers.dart:923` | `AtlasPulse` — the you-are-here breath, `..repeat()` | ✅ L930 | ✅ same double gate |
| 3 | `atlas_layers.dart:1203` | `AtlasArrivalBurst` main ring, one-shot `forward()` | ✅ L1285 | ✅ |
| 4 | `atlas_layers.dart:1215` | `AtlasArrivalBurst._grace` — 400 ms card-wait | ✅ L1284 | ✅ |
| 5 | `atlas_layers.dart:1478` | `AtlasTravelTrace` spark; `addListener(() => setState(() {}))` | ✅ L1542 | ✅ |
| 6 | `ui/components/ambient_stage.dart:580` | `_ActivityLoop` — the working loop; also emits the audio beat | ✅ | ✅ shell `TickerMode` |
| 7 | `ui/components/ambient_player.dart:244` | Ambient scene sequencer | ✅ | ✅ own `WidgetsBindingObserver` + `TickerMode` |
| 8 | `ui/components/sprite_animation.dart:72` | One-shot gather animation | ✅ L120 | ✅ |
| 9 | `ui/components/activity_result.dart:275` | Result-card life clock | ✅ | ✅ **explicitly** reads `TickerMode.valuesOf(context)` and `stop()`s |
| 10 | `ui/components/reward_beat.dart:306` | `StaggeredReveal` | ✅ | ✅ |
| 11 | `ui/screens/adventure/activity_panel.dart:671` | Repetition fill bar | ✅ | ✅ |
| 12 | `ui/screens/adventure/encounter_card.dart:475` | Encounter idle visit | ✅ | ✅ + `WidgetsBindingObserver` |
| 13 | `ui/screens/combat/combat_stage.dart:204` | Combat choreography | ✅ | ✅ + `WidgetsBindingObserver` |
| 14 | `ui/screens/craft/craft_screen.dart:1164` | `_CompletionPulse` flash | ✅ | ⚠️ see §3.3 |
| 15 | `ui/screens/craft/craft_screen.dart:1240` | `CraftRepetitionBar` fill | ✅ | ✅ |
| 16 | `ui/screens/world/travel_transition.dart:168` | Travel card | ✅ | ✅ |

### 3.2 The gate that makes this work — and how it was learned

`lib/ui/shell/stride_shell.dart:139–169` wraps **each of the six `IndexedStack`
children in its own `TickerMode`**, enabled only for the selected tab. The
comment records why, and it is the load-bearing fact of this whole audit:

> `IndexedStack` builds hidden children with `maintainAnimation: true`, so the
> framework inserts NO `TickerMode` of its own — without these wraps a visited
> World tab kept its atlas overlay ticker scheduling 120 Hz frames from any tab,
> and a hidden Adventure stage kept looping and firing its audio cues.

That was found and fixed as **PERF-A** in `MILESTONES/FABLE_V2_EXPERIMENT_01.md`
§6 / commit `4707a2e`. The second gate is `AtlasViewport`'s own `TickerMode`
(`atlas_viewport.dart:402`), enabled only when
`_lifecycle == AppLifecycleState.resumed && !MediaQuery.disableAnimationsOf(context)`.
The two nest; either disabling silences the whole atlas.

**Route visibility is handled by the framework and needs nothing.** The four
pushed routes — `bestiary_screen.dart:43`, `goal_board_screen.dart:46`,
`step_tracker_screen.dart:47`, `skill_detail_screen.dart:68` — are all
`MaterialPageRoute`, i.e. opaque. Flutter's `Overlay` sets `tickerEnabled: false`
on maintained entries below the topmost opaque entry, so the shell's tickers
stop for free once the push transition completes. No action required, but it
should be *known*, because a future `PageRouteBuilder` with `opaque: false`
would silently lose that protection.

### 3.3 Animations that run while hidden

**Verdict: none of the sixteen tickers runs while its screen is hidden.** That
is a genuinely clean result and it should be stated plainly rather than hedged.

Three qualifications, in descending order of importance:

- **`_CompletionPulseState._onChange` (`craft_screen.dart:1181–1187`) fires a
  haptic from a `ChangeNotifier` callback, not from a ticker.** `CraftController`
  is app-scoped (`stride_app.dart:114`), so a craft repetition completing while
  the player is on another tab calls `AudioScope.read(context).hapticLight()`
  from an unseen screen. `TickerMode` does not gate `ChangeNotifier` callbacks —
  only the `_flash.forward()` on the next line. **This is the same class of
  defect as M-16** (Reduce Motion silencing SFX because the cue fired from an
  animation ticker): feedback and motion wired to the same signal, so gating one
  mis-gates the other. Severity: low today (one light haptic), but the plan adds
  "more audio voices" to exactly this surface.
- **A muted `Ticker` keeps accumulating elapsed time.** `Ticker._startTime` is
  not reset on unmute, so `_AtlasOverlayLayerState._elapsed` jumps forward by the
  full hidden duration on return to the World tab. Today every overlay either
  drifts-and-wraps or runs a `playLoops` interval, so the jump is invisible.
  A *travelling* creature (`travelX`/`travelY`, the `overlay.playMillisAt(t)`
  branch at `atlas_layers.dart:~410`) would reappear mid-flight at an arbitrary
  point. `activity_result.dart:264–290` already solves this correctly for its
  own clock — that pattern is the precedent to copy.
- **Timers are not ticker-gated at all**, by design. `ActivityController`
  (`ui/state/activity_controller.dart:203–204, 351, 418, 558, 566, 640`),
  `AudioController` fades (`audio/audio_controller.dart:133–134, 437`). All are
  one-shot and chained — `Timer.periodic` is forbidden in `lib/` outright and
  the repo enforces it (`s01a_vertical_slice_test.dart` §14). Both controllers
  carry `WidgetsBindingObserver` and a `_halted` predicate for backgrounding.
  Correct as built.

### 3.4 The overlay ticker's per-frame cost — measured from the source

`_AtlasOverlayLayerState._onTick` (`atlas_layers.dart:386–392`) runs on **every
vsync while the World tab is frontmost — 120 Hz on ProMotion**. Each tick calls
`_frameKey(previous)` and `_frameKey(elapsed)`, and each `_frameKey` walks all
30 overlays calling `visibleAt`, `frameIndexAt` and `_driftPosition`.

- **60 overlay evaluations per tick × 120 Hz = 7,200 per second.**
  (The comment at L404 says "one position computation per overlay per tick, not
  two" — that is true *within* one `_frameKey`, but `_onTick` calls `_frameKey`
  twice per tick because it recomputes the previous key rather than caching it.)
- When the key changes, `setState` rebuilds the whole layer, and the build at
  L465–467 calls **`_driftPosition` twice per visible overlay** — once for `.dx`,
  once for `.dy`:
  ```dart
  left: _driftPosition(overlay, _elapsed).dx.floorToDouble(),
  top:  _driftPosition(overlay, _elapsed).dy.floorToDouble(),
  ```

None of this is expensive at 30 overlays — it is float arithmetic and modulo.
It is recorded because it is **linear in overlay count** and the plan adds
creatures. At 60 overlays it is 14,400 evaluations/second before a single pixel
is drawn.

---

## 4 · Image loading

| Question | Answer |
|---|---|
| **Does the app use `precacheImage`?** | Yes, at **8 sites**, all in `didChangeDependencies` behind a `_precached` latch: `atlas_layers.dart:382` (every frame of every world overlay), `ambient_player.dart:261,263`, `ambient_stage.dart:602`, `sprite_animation.dart:91`, `encounter_card.dart:489`, `combat_stage.dart:280`, `travel_transition.dart:84,85,87`. The reasoning is right and stated: *"Decoding a frame mid-animation would drop it, and a dropped frame in an eight-frame cycle is an eighth of the action."* |
| **Is there an image-cache size configuration?** | **No.** Zero occurrences of `imageCache`, `maximumSize`, `maximumSizeBytes` or `PaintingBinding` in `lib/`. Defaults apply: **1,000 entries / 100 MiB**. **This is K-1.** |
| **Gapless playback?** | Yes — `gaplessPlayback: true` on both `Image.asset` sites (`pixel_asset.dart:152, 268`). |
| **Repeated decodes?** | No. Frames are cached by `AssetImage` key; `SpriteAnimation`/`_ActivityLoop`/`CombatStage` swap `assetPath` per frame and the cache returns the already-decoded `ui.Image`. Decode happens once per file per cache lifetime. |
| **Sprite sheets decoded once and sliced?** | **There are no sprite sheets.** Every animation frame is a separate PNG (`overlay_skydragon_f0..f27.png`, `bear_attack2_f0..f8.png`, …). Per-frame decode cost is fine (one decode each, cached); the cost is **871 cache entries against a 1,000 cap** and 871 separate asset-bundle lookups. |

### 4.1 The precache blast radius

`AtlasOverlayLayer.didChangeDependencies` (L376–384) precaches **every frame of
every overlay in the layout** the first time the World tab is built:

| Overlay | Frames | Native | Decoded |
|---|---:|---|---:|
| `overlay_volcano` | 17 | 64 × 64 | 278,528 B |
| `overlay_skydragon` | 28 | 68 × 31 | 235,904 B |
| `overlay_flock` | 13 | 64 × 40 | 133,120 B |
| `overlay_snow_flurry` | 8 | 64 × 64 | 131,072 B |
| `overlay_forest_mist` | 6 | 96 × 48 | 110,592 B |
| `overlay_nessie` | 17 | 44 × 33 | 98,736 B |
| `overlay_fire3` | 10 | 44 × 52 | 91,520 B |
| `overlay_tree_rustle_a` | 9 | 48 × 48 | 82,944 B |
| …18 others | | | |
| **All `env/overlay_*`** | **211 files** | | **1,653,256 B (1.58 MiB)** |

So the World tab's first build pins **1.58 MiB + 4.00 MiB atlas = 5.58 MiB**
and **218 cache entries** — a quarter of the 1,000-entry cap for one tab.
There is already a **28-frame flying dragon** shipping (`overlay_skydragon`), so
the planned "animated dragons" is an *extension of a working mechanism*, not a
new capability. That is the most useful thing in this section: the reference
cost of one 28-frame flying creature at this art scale is **236 KB decoded and
28 cache entries.**

---

## 5 · Widget rebuild hygiene on the busiest screens

### 5.1 The structural finding (K-2)

`lib/ui/stride_app.dart:225–235` nests four root `InheritedNotifier`s:

```
SessionScope(SessionController) > ActivityScope > CraftScope > AudioScope > StrideShell
```

Each screen's `build` opens with `SessionScope.of(context)` — e.g.
`adventure_screen.dart:79`, `world_screen.dart:147` — which is
`dependOnInheritedWidgetOfExactType`, registering that screen's element as a
dependent. `StrideShell` keeps all six screens alive in an `IndexedStack`
(deliberately: "a tab change no longer destroys every screen's ephemeral state").

**Therefore one `notifyListeners()` from the session dirties all six screen
elements.** `IndexedStack` paints only the selected child but `RenderStack`
lays out **all** of them. So on every gather completion, step sync, craft
repetition or travel commit:

- `WorldScreen.build` runs `AtlasScene.build(s)` (`world_screen.dart:149`),
  which allocates 6 fresh collections (`byId`, `neighbours`, `legCost`, `seen`,
  `edges`, `rumorLandmarks`) and returns a **new `AtlasScene` identity**;
- because the identity is new, `_RoutePainter.shouldRepaint`'s `old.scene != scene`
  and `_StaticRingPainter.shouldRepaint`'s `old.scene != scene` both return true;
- the 6144 × 6144 Stack of ~120 positioned children re-builds and re-lays-out —
  **offstage**.

`TickerMode` stops the *clocks*. Nothing stops the *build and layout*. This is
the exposure the coming work will multiply: 9-slice frames "across all UI" put a
`PixelFrame` — a `StatefulWidget` with an `ImageStream` subscription and a
`CustomPaint` — at 34 `SectionCard` call sites × six screens, all rebuilding
together.

### 5.2 `setState` inside animation callbacks

| Site | Rebuild scope | Verdict |
|---|---|---|
| `atlas_layers.dart:391` `_onTick` → `setState` | the whole overlay layer: up to 30 `Positioned > Opacity > PixelAsset` | **Guarded correctly.** `_frameKey` gates the rebuild on a *whole world pixel* of movement or a frame-index change, not on every vsync. This is the right pattern and the right place to copy from. |
| `atlas_layers.dart:1481` `..addListener(() => setState(() {}))` | `AtlasTravelTrace` | Unconditional per-vsync `setState`, but the widget is a single `CustomPaint` and lives ~2 s. Acceptable. |
| `ambient_stage.dart:~625` `_onTick` → `setState(() => _frame = next)` | one `GroundedSprite` | Guarded on `next == _cursor`. Correct. |
| `sprite_animation.dart:~113` | one `GroundedSprite` | Guarded on `next == _frame`. Correct. |
| `atlas_viewport.dart:_onScaleUpdate` → `setState` | the whole 6144² Stack, **per pan frame** | The layers are `RepaintBoundary`s so paint is a re-composite, but **build and layout of ~120 children run on every drag frame**. Currently ~2 ms; linear in child count. |

### 5.3 `const` hygiene

**`prefer_const_constructors` is not enabled.** `analysis_options.yaml` is one
line — `include: package:flutter_lints/flutter.yaml` — and flutter_lints 6.0.0
enables only `prefer_const_constructors_in_immutables`, not
`prefer_const_constructors` or `prefer_const_declarations`. The
`// ignore: prefer_const_constructors` comments in `stride_shell.dart:137–166`
are therefore inert; the deliberate non-const choice there (so the incoming tab
rebuilds rather than showing stale state) is correct and would need those
ignores only if the rule were turned on.

Consequence: **nothing mechanically catches a missing `const` on a hot path.**
With `PixelFrame` about to appear at 34 call sites, a non-const `PanelSkin`
argument would defeat the `didUpdateWidget` short-circuit at
`pixel_asset.dart:~370` (`if (old.skin.assetPath != widget.skin.assetPath) _resolve();`)
only if the path string changed — but a non-const `Decoration` fallback would
churn a new `DecoratedBox` decoration every rebuild.

### 5.4 Expensive work inside `build()`

- **`AtlasScene.build(s)` in `WorldScreen.build`** — §5.1. The most expensive
  per-build allocation in the app.
- **`AtlasScene.namedLandmarks`** (`atlas_layout.dart:~218`) is a getter that
  allocates `[...layout.landmarks, ...rumorLandmarks]` — a fresh 23-element list
  on **every call**, and it is called from the landmark layer's build.
- **`_ContactShadowPainter.paint`** (`grounded_sprite.dart:~165`) constructs a
  `RadialGradient(...).createShader(oval)` on every paint. `shouldRepaint`
  correctly gates it on footprint/scale, so it repaints rarely — but every
  animated sprite frame *is* a repaint, so this runs once per sprite per frame.
  At the current 1–3 sprites on screen it is invisible. At a layered character
  (§9) with a shadow per layer it would be 3×.
- **Sorting**: all `..sort()` calls live in `lib/runtime/stride_session.dart`
  (13 sites) and `craft_memory.dart:83`, i.e. inside session projections, not
  inside `build()`. Clean.
- **No image decode in any `build()`.** All decode is `precacheImage` in
  `didChangeDependencies` behind a latch.

### 5.5 A constraint the coming work will otherwise break

`_ContactShadowPainter` paints with `BlendMode.multiply` and the source says why
this matters:

> Multiply against what is already painted beneath — the scenery, or a card's
> fill. **This is why a grounded sprite must share a layer with its background
> rather than sitting behind an opacity or a shader mask of its own.**

So "richer gathering scenes" and "layered equipment compositing" both have a
hard constraint: **you may not wrap a `GroundedSprite` in `Opacity`,
`ShaderMask`, `ColorFiltered`, or a `RepaintBoundary` that isolates it from its
background**, or the contact shadow multiplies against transparent black and the
character floats. This is a *correctness* rule with a *performance* rationale
attached (the alternative — a `saveLayer` per sprite — is the expensive fix).

---

## 6 · Audio runtime

### 6.1 Voice count and pooling

| Question | Answer, with the source |
|---|---|
| **Max simultaneous players** | **2 music + 5 SFX = 7 `AudioPlayer` instances**, and in practice **2 music + 1 audible SFX**. |
| **Music** | At most two ever exist: `_music` and `_fadingOut` (`audio_controller.dart:126–131`). `_retireCurrentMusic` disposes anything already fading before promoting a new one — *"two dying tracks under a new one is a mush no crossfade needs."* A `_musicEpoch` counter (L128) disposes any async start that comes back stale, so rapid travel taps end with exactly one track. |
| **SFX pooling** | **Pooled, one persistent player per cue path**: `AudioplayersOutput._cuePlayers` is a `Map<String, AudioPlayer>` created lazily on first use (`audio_output.dart:52`). Five cue paths ship, so five players. `PlayerMode.lowLatency` + `ReleaseMode.stop` keeps the decoded source warm. |
| **Can a cue layer over itself?** | **No.** `playCue` does `await player.stop()` then `play()` on the same instance — retrigger, never layer. |
| **Rate limiting** | Per-cue `cooldownMillis` (`audio_controller.dart:~258`), resolved *after* the file lookup so a missing asset does not consume the cooldown slot. Haptics have their own floors: light 120 ms, medium 400 ms, heavy 1200 ms, selection 80 ms (`_hapticFloorMillis`, L347–352), with an `always: true` payoff bypass. |
| **Disposal** | `AudioController.dispose` cancels the save timer (flushing a pending write), cancels every fade timer, disposes both music channels, disposes the output (which disposes and clears all cue players), and removes the lifecycle observer. Complete. |
| **Does audio continue after navigation?** | **By design, yes for music; no for SFX.** Music is app-scoped and region-keyed: `setRegion` early-returns when the assignment is unchanged, so tab changes and route pushes do not restart the track. SFX cannot outlive the screen because the only caller is `AmbientStage.onActivityBeat` — a *visible* animation ticker crossing its strike frame — and `playSkillCue` refuses while `_halted`. |
| **Leak check** | **No leak found.** The only path that constructs an `AudioPlayer` outside the controller is none: no widget anywhere constructs a player (grep confirms `AudioPlayer(` appears only in `audio_output.dart`). The controller is a single root-scoped instance. |

### 6.2 Session category

`AudioPlayer.global.setAudioContext(AudioContextConfig(respectSilence: true).build())`
gives iOS the **ambient** category: honours the ring/silent switch, mixes with
other apps, is silenced by the OS in the background, and requires **no
background-audio entitlement**. That is a deliberate milestone contract and it
caps what the mix can ever be — ambient sessions are the lowest-priority mixer
clients on iOS and are the first thing the OS thins under pressure. It is a real
constraint on "more audio voices."

### 6.3 Memory

All five SFX are PCM 16-bit stereo 44.1 kHz, 1.0–2.0 s, **1.11 MB total**, all
resident once played (`ReleaseMode.stop` keeps the source warm). Music streams;
each track is 150 s of 192 kbps AAC = ~3.6 MB on disk, decoded in a rolling
buffer by AVAudioPlayer. Audio memory is not a concern at any plausible scale
here — **audio's cost is bundle size, and it is already 90 % of the bundle**.

---

## 7 · The performance budget for VAWO01

### 7.0 The device floor, established

`ios/Runner.xcodeproj/project.pbxproj` sets `IPHONEOS_DEPLOYMENT_TARGET = 17.0`
at all three configurations. iOS 17 drops the iPhone 8 and X, so **the oldest
device this app must run on is the iPhone XR / XS / SE (2nd gen)** — A12/A13,
**3 GB RAM**, DPR 2. `test/ui_responsive_test.dart:58` tests down to **320 dp**.

That gives the anchors:

| Anchor | iPhone XR / SE2 (floor) | iPhone 15 Pro Max (target) |
|---|---|---|
| RAM | 3 GB | 8 GB |
| iOS jetsam ceiling for the app | ~1.35 GB | ~3.0 GB |
| Logical size | 414 × 896 / 375 × 667 | 430 × 932 |
| DPR | 2 | 3 |
| Framebuffer | 828 × 1792 × 4 = **5.9 MB** | 1290 × 2796 × 4 = **14.4 MB** |
| Frame budget | 16.67 ms (60 Hz) | **8.33 ms (120 Hz ProMotion)** |

**The 8.33 ms budget is the one that binds**, and it binds on the *newest*
device, not the oldest — ProMotion halves the frame budget. A world map that
runs at a comfortable 14 ms is 60 fps on an XR and a **stuttering 120→60 drop**
on the 15 Pro Max, which is exactly the "beautiful screen that runs badly"
failure the brief names.

### 7.1 The budget

| # | Budget | Limit | Justification |
|---|---|---|---|
| **B-1** | **Max additional decoded texture memory** | **+24 MiB** (total resident art ≤ **44 MiB**) | Current is 20.21 MiB. Skia holds a GPU copy beside the CPU bitmap while both are live, so 44 MiB decoded ≈ **88 MiB of image memory**. Against the 3 GB floor device's ~1.35 GB jetsam ceiling, and a Flutter baseline of ~150 MB for an app this size plus a 5.9 MB framebuffer, that is **~7 % of the device's budget** — enough headroom that a raster-cache spike or a photo-library share sheet cannot tip it. It also keeps the total under Flutter's default 100 MiB byte cap by a factor of 2, so eviction never becomes routine. |
| **B-2** | **Max simultaneous animated elements on the world map** | **40 declared, ≤ 12 in frame at any zoom, on ≤ 2 tickers** | 30 declared / ~11 in frame at the survey floor is the shipped, device-tested figure (§2.5). 40/12 is a 33 %/9 % increase over a known-good baseline — a real gain that stays inside measured territory. **Two tickers, not forty**: the existing single-ticker pattern (`atlas_layers.dart:368`) costs 7,200 float evaluations/sec at 30 overlays; per-creature `AnimationController`s would cost 40 vsync registrations and 40 `setState`s per frame instead of one. |
| **B-3** | **Max simultaneous audio voices** | **4** (1 music + 1 crossfading music + **2** SFX) | Music is already hard-capped at 2 by `_retireCurrentMusic`. SFX is currently effectively 1. The limit is not memory (1.11 MB of PCM) — it is (a) the **ambient** AVAudioSession category, the lowest-priority mixer client on iOS, and (b) audibility: more than ~3 concurrent transients on a phone speaker is mush. Raising SFX from 1 to 2 buys layered feedback (a strike plus a material tail) without needing a mixer. **Any design needing a 5th voice needs a mixing design first, not a 5th player.** |
| **B-4** | **Max sprite layers per character** | **3** (base body strip + 1 equipment layer + 1 effect layer) | Draw cost is not the constraint — 3 sprites × 3 layers = 9 `drawImageRect` per combat frame is nothing. Two things are: **(a) the contact shadow.** `BlendMode.multiply` requires the sprite to share a layer with its background (§5.5), so layers must be siblings in one `Stack`, never nested `Opacity`s — every added layer is another chance to break that. **(b) precache and cache entries.** Combat precaches `CombatAssets.framesFor(enemy, location)` on mount; at K layers that set is K×. At 3 layers a ~110-frame combat set is 330 entries — a third of the current cache cap on its own. |
| **B-5** | **Max new asset payload** | **+2.5 MB of PNG** and **+8 MB of audio**, as two independent budgets | +2.5 MB PNG × the **measured 10.75:1** ratio = **+26.9 MiB decoded**, which lands on B-1 with a small margin. Audio is separate because it costs bundle, not memory: +8 MB is **two more 150 s tracks at 192 kbps**, or four at 128 kbps, or ~40 s of new PCM SFX. Total bundle goes 20.6 MB → ~31 MB, comfortably under the App Store's 200 MB over-the-air threshold. |
| **B-6** | **Max total PNG count** | **1,600 files, with `imageCache.maximumSize` raised to 2,000 in the same commit** | This is the hard one and it is B-1's real enforcement mechanism. 871 today against a **1,000** default cap. Any plan that adds files without raising the cap starts thrashing. Set `maximumSize = 2000` and `maximumSizeBytes = 48 << 20` — *lowering* the byte cap from the 100 MiB default is correct here, because it makes B-1 self-enforcing: exceed 48 MiB of live decoded art and the cache starts evicting, which is a visible stutter in QA rather than a silent memory climb in the field. |
| **B-7** | **Frame budget** | **8.33 ms on the 15 Pro Max**, with the world map ≤ 5 ms build+layout+paint | The target device is ProMotion. A 120 Hz surface that misses is worse than a 60 Hz surface that holds, because the drop is visible as a halving. Reserve 3.3 ms for platform, text and the shell. |

---

## 8 · Existing performance tests, benchmarks and profiling harnesses

**There are none.** This is K-4.

Searched `lib/`, `test/`, `integration_test/`, `Scripts/`, `.github/` for
`benchmark`, `Timeline`, `flutter drive`, `--profile`, `DevTools`,
`reportTimings`, `addTimingsCallback`, `frame_polic`. The only hit in the entire
repository is a **comment** in `Scripts/ios/build-release-device.sh:8`.

What exists, and what could carry a performance assertion:

| Harness | How to run | What it could be extended to prove |
|---|---|---|
| `Scripts/verify.sh` (`--strict` in CI) | `bash ./Scripts/verify.sh` | The natural home for a static asset-budget check (file count, total decoded bytes) — it already runs the art-packaging `--check`. |
| `Scripts/check-ui-boundary.sh` | `bash ./Scripts/check-ui-boundary.sh` | Already confines `Image.(asset\|file\|network\|memory)`, `DecorationImage`, `paintImage` to `pixel_asset.dart`. **It does not match `drawImageRect`, `drawAtlas`, `drawImageNine` or `drawRawAtlas`** — a hole shaped exactly like the coming 9-slice and sprite-batching work. |
| `Scripts/art/package-art.js --check` | `node ./Scripts/art/package-art.js --check` | Reports `art packaging: 851 files up to date`. Already measures every PNG's footprint at packaging time — the cheapest place to add a dimension/count budget gate. |
| 15 golden tests in `test/goldens/` | `flutter test --tags golden` | Render whole screens through a real pipeline; a widget-count or layer-count assertion could ride the same pumps. |
| `test/ui_responsive_test.dart` | `flutter test test/ui_responsive_test.dart` | Already sweeps 320/360/393/430 dp asserting no overflow. The right place for "no screen builds more than N widgets at 320 dp." |
| `integration_test/restart_test.dart` | `flutter test integration_test/` on a device | The only on-device harness. Could be extended with `SchedulerBinding.addTimingsCallback` to record build/raster times across a scripted tour. |
| CI (`.github/workflows/ci.yml`) | 12 guard jobs + analyze + 3 test suites | **No performance job.** |

**Recommendation, minimum viable:** one Dart test that walks `assets/` and fails
if PNG count > 1,600 or total decoded bytes > 44 MiB, plus one line added to
`check-ui-boundary.sh`'s pattern for the canvas image ops. Both are cheap,
mechanical, and turn §7 from prose into a guard. Anything more elaborate is
subject to G-1 / M-01 and should not be built without a named uncovered risk.

---

## 9 · Risk register for the planned work

### R1 · Animated dragons and fairies on the world map

| | |
|---|---|
| **Risk** | Per-frame `saveLayer` at world scale; ticker count growth; cache-entry exhaustion |
| **Mechanism** | Each overlay today is `Positioned > Opacity > PixelAsset`. `Opacity` over a **single** `drawImageRect` uses the engine's `children_can_accept_opacity` fast path — the alpha folds into the draw, no offscreen. Make the child a `Stack` (body + wings + glow, or a creature + its own shadow) and the fast path is gone: the engine allocates a real `saveLayer` at the child's bounds. At `scale: 6` a 68 × 31 creature is 408 × 186 logical = **1224 × 558 device px = 2.73 MB** per creature per frame. Twelve creatures = **32.8 MB of offscreen allocation and blit per frame**, inside an 8.33 ms budget. |
| **Second mechanism** | The world `Stack` has no culling. N creatures = N elements built and laid out regardless of camera position, and N more entries in a 1,000-entry image cache (the shipped `overlay_skydragon` is 28 files / 236 KB by itself). |
| **Third mechanism** | A muted ticker accumulates elapsed time (§3.3), so a *travelling* creature on `travelX`/`travelY` reappears mid-flight at an arbitrary point after a tab dwell. |
| **Required mitigation** | (a) **One image per overlay child, always** — a creature that needs two parts is two sibling overlays, not a nested `Stack` under one `Opacity`. If a composite is unavoidable, bake it in PixelLab (A-1) rather than compositing at runtime. (b) Ride the **existing single ticker** (`atlas_layers.dart:368`); no new `AnimationController` on the atlas. (c) Cap at B-2. (d) Adopt `activity_result.dart:264–290`'s explicit `TickerMode.valuesOf` pattern for any `travel`-kind creature so its clock freezes rather than accumulating. |

### R2 · Layered equipment compositing on the character

| | |
|---|---|
| **Risk** | Contradicts a recorded architectural decision; contact shadow breakage; precache multiplication |
| **Mechanism** | `lib/ui/icons/traveler_art.dart` is a shipped-inert seam that **explicitly rejected runtime overlays** in favour of precomposed variant strips: *"A weapon overlay needs a per-frame hand anchor and occlusion order on 100+ frames of flattened art that already contains a baked generic tool the overlay would double-draw. That data does not exist and cannot be measured deterministically."* If VAWO01 reverses that, the reversal is a **decision**, not an implementation detail (G-3). |
| **Performance reality** | Runtime layering is the **payload-cheaper** option: precomposed is `V_weapon × V_armor × F` strips; layered is `(V_weapon + V_armor) × F`. At 4 weapons, 4 armours, 110 frames that is **1,760 files vs 880** — the layered option is half, and the precomposed option alone would blow B-6. So the performance argument *favours* layering; the correctness argument (missing anchors, baked-in tools) opposes it. Both must be settled together. |
| **Second mechanism** | `_ContactShadowPainter` uses `BlendMode.multiply` and requires the sprite to share a layer with its background (§5.5). A layered figure must be **sibling images inside one `Stack` sharing one shadow**, never nested `Opacity`/`ShaderMask`/isolating `RepaintBoundary` per layer. |
| **Third mechanism** | `CombatStage.didChangeDependencies` precaches `CombatAssets.framesFor(enemy, location)` on mount. At K layers that is K× the frames, K× the cache entries, and K× the mount-time decode — a visible hitch entering a fight. |
| **Required mitigation** | (a) Escalate the architecture reversal to a decision record before any code. (b) **≤ 3 layers** (B-4). (c) One `Stack`, one shadow, siblings only. (d) Precache **only the equipped combination**, not every variant; the variant tables in `traveler_art.dart` must resolve before precache, not after. |

### R3 · 9-slice pixel frames across all UI

| | |
|---|---|
| **Risk** | A `StatefulWidget` with an `ImageStream` subscription and a `CustomPaint` at 34+ call sites, all rebuilding on every session notify |
| **Mechanism** | `PixelFrame` (`pixel_asset.dart:~340`) resolves an `AssetImage` in `didChangeDependencies`, holds an `ImageStream` + `ImageStreamListener`, and `setState`s when the image arrives. `_FramePainter.paint` draws 4 corners plus **`ceil(w/stripW) × 2 + ceil(h/stripH) × 2` tiled strips** — for a 340 dp-wide panel with a 16 px strip at scale 2 that is ~21 top + 21 bottom + edges ≈ **46 `drawImageRect` calls per frame per panel**. At 34 panels that is **~1,560 draw calls** if they were all on one screen; realistically 6–8 panels per screen = ~370 draw calls. Combined with K-2 (all six screens rebuild together), this is the change most likely to convert a clean 8.33 ms into a missed frame. |
| **Second mechanism** | The `PanelSkins` registry ships empty and CI enforces that an empty registry lays out identically. **That is also the performance escape hatch** — the whole feature reverts in one commit. It must stay that way. |
| **Required mitigation** | (a) Every `PixelFrame` gets a `RepaintBoundary` so a panel's frame is not re-rastered when its body text changes. (b) `shouldRepaint` already compares `image` and `assetPath` — keep it; never add the panel `Size` to it. (c) **Measure a real screen with the registry full before filling it**, using the golden harness. (d) Keep the one-commit revert. (e) Prefer `canvas.drawAtlas` over N `drawImageRect` calls if a panel exceeds ~32 strip tiles — one batched call instead of 46. |

### R4 · Richer gathering scenes

| | |
|---|---|
| **Risk** | Scene-class images are the third-largest decoded category and they are precached per-visit |
| **Mechanism** | `location/` + `work/` are 25 images at 384 × 176 = **4.66 MiB decoded** for what is currently a mostly-static backdrop. "Richer" means more layers or more frames; both multiply a 270 KB-per-image base. `AmbientPlayer.didChangeDependencies` precaches `widget.scenes.allFrames` — **every frame of every scene in the set** — on first build. A richer scene set makes that a longer, larger, mount-time decode burst. |
| **Second mechanism** | `PixelScene` clips rather than scales, so a 320 dp phone already discards 16.7 % of every scene's decoded pixels (§1.4). Wider or taller scene art multiplies waste that is invisible on the 430 dp target device. |
| **Required mitigation** | (a) Scene art stays at **384 px wide**; extra richness is more *layers within* the 384 × 176 frame, not a bigger frame. (b) Precache the **active** scene's frames, not `allFrames`, once the set exceeds ~40 frames. (c) Every added scene layer counts against B-1 at 270 KB per full-width layer — three new layers per location × 5 locations = 4.05 MiB, a sixth of the entire budget. Budget them explicitly. |

### R5 · More audio voices

| | |
|---|---|
| **Risk** | Bundle size, and the M-16 class of defect repeating |
| **Mechanism** | Audio is already **90 % of the bundle** (18.46 MB of 20.57 MB). Each 150 s track at 192 kbps is 3.6 MB. Five more region tracks is **+18 MB — a 90 % bundle increase for content the player hears once per region change.** |
| **Second mechanism** | The **ambient** AVAudioSession category (`audio_output.dart:57–60`) is a deliberate, entitlement-free contract. It is the lowest-priority mixer client on iOS. Voice counts above ~4 are not reliably delivered under memory pressure or with another app mixing. |
| **Third mechanism** | **M-16 repeating.** `_CompletionPulseState._onChange` (`craft_screen.dart:1181`) already fires a haptic from a `ChangeNotifier` callback that `TickerMode` does not gate — feedback wired to a motion signal is exactly the shape of the Reduce-Motion blackout. Adding voices to that surface without separating the cadence cursor from the drawn frame (the fix `ambient_stage.dart` already carries) reintroduces it. |
| **Required mitigation** | (a) Cap at B-3 (4 voices). (b) **Drop new region music to 128 kbps** — 2.4 MB per 150 s track instead of 3.6 MB, saving 33 % on the dominant bundle cost, and inaudible on a phone speaker under an ambient session. (c) Ambience loops must be **short and looping** (≤ 20 s), never 150 s one-shots. (d) Every new cue fires through `AudioController.playSkillCue`'s cooldown; **no widget may construct an `AudioPlayer`** (the property that makes the leak class unrepresentable today). (e) Any new feedback signal must separate *cadence* from *drawn frame*, per `ambient_stage.dart`'s `_cursor` / `_frame` split. |

### R6 · Cross-cutting — the rebuild storm (K-2)

| | |
|---|---|
| **Risk** | Every feature above lands inside a tree where one `notifyListeners()` rebuilds and re-lays-out all six screens |
| **Mechanism** | §5.1. `IndexedStack` + root `InheritedNotifier` + `SessionScope.of(context)` at the top of each screen's `build`. `TickerMode` stops clocks; nothing stops builds. |
| **Required mitigation** | Do **not** refactor the state architecture during VAWO01 — that is a separate, larger change and outside this milestone. Instead: (a) memoise `AtlasScene` in `_WorldScreenState` keyed on the session fields it actually reads, so a session notify that does not move the player does not rebuild the atlas; (b) put a `RepaintBoundary` under each `PixelFrame`; (c) add the widget-count assertion of §8 so the storm's cost is measured before and after. |

---

## 10 · Mandatory rules for the implementation

These are stated as enforceable invariants, in the register of `RULES.md`. Each
names what it forbids and why, so a future session can tell a rule from a
preference.

**Texture memory and assets**

- **R-1.** Every image over **256 px on either axis** must be justified in the
  milestone record with its decoded cost (`w × h × 4`). Today exactly one image
  qualifies (`atlas_base.png`, 4.000 MiB). A second one is a decision, not a
  detail.
- **R-2.** **`cacheWidth`/`cacheHeight`/`ResizeImage` remain forbidden on pixel
  art.** They resample at decode time, before `filterQuality` is consulted, and
  drop whole columns on a small source. This is not a perf-vs-quality trade to
  revisit; it is a correctness rule with `pixel_asset.dart:142` as its home.
  *(The generic industry rule "every image over N px must use cacheWidth" is
  actively wrong for this codebase and must not be imported.)*
- **R-3.** **`PaintingBinding.instance.imageCache.maximumSize` must be set
  explicitly to 2,000 and `maximumSizeBytes` to `48 << 20` in the first commit
  that adds an asset.** Shipping past 1,000 PNGs on the default cap is a silent
  thrash, not a warning.
- **R-4.** Total shipped PNGs ≤ **1,600**; total decoded art ≤ **44 MiB**; new
  PNG payload ≤ **+2.5 MB** on disk. Asserted by a test in `test/`, run by
  `Scripts/verify.sh`.
- **R-5.** New audio: ≤ **+8 MB** bundle. New region music at **128 kbps**, not
  192. Ambience loops ≤ **20 s**.

**World map**

- **R-6.** **No widget that induces a `saveLayer` may wrap the world-sized
  subtree.** `Opacity`, `ColorFiltered`, `ShaderMask`, `BackdropFilter`,
  `ClipPath(clipBehavior: antiAliasWithSaveLayer)` above the `Transform` in
  `atlas_viewport.dart` request an offscreen at 6144 × 6144 logical bounds
  (18,432 device px at DPR 3, past Metal's 16,384 limit). The `ClipRect` at the
  top is what saves it today; nothing may be inserted between them.
- **R-7.** **Every world-map overlay's `Opacity` wraps exactly one image.** A
  creature needing two parts is two sibling overlay entries, or one baked
  PixelLab sprite — never a nested `Stack` under one `Opacity`. Breaking this
  costs 2.73 MB of offscreen per creature per frame.
- **R-8.** **Every world-map animation rides the existing shared `Ticker`**
  (`atlas_layers.dart:368`). No new `AnimationController` may be added to the
  atlas layers. New tickers anywhere in the app must be inside a `TickerMode`
  tied to tab visibility — which on this shell means being a descendant of one
  of the six wraps in `stride_shell.dart:139–169`.
- **R-9.** ≤ **40 declared overlays**, ≤ **12 in frame** at any zoom, verified at
  the survey floor on a 430 dp viewport (the widest, therefore worst, case).
- **R-10.** Any overlay using `travelX`/`travelY` must read
  `TickerMode.valuesOf(context).enabled` and freeze its own clock, per
  `activity_result.dart:264–290`. A muted `Ticker` accumulates elapsed time;
  a travelling creature would otherwise teleport after a tab dwell.

**Sprites and characters**

- **R-11.** ≤ **3 sprite layers per character**, as **siblings in one `Stack`
  sharing one contact shadow**. No `Opacity`, `ShaderMask`, `ColorFiltered` or
  isolating `RepaintBoundary` between a `GroundedSprite` and its background —
  the shadow's `BlendMode.multiply` requires a shared layer.
- **R-12.** Precache **only the resolved, equipped combination**, never every
  variant. Variant resolution happens before `precacheImage`, not after.
- **R-13.** Reversing `traveler_art.dart`'s precomposed-strip architecture in
  favour of runtime overlays is a **decision record**, not an implementation
  choice (G-3). It may be the right call — layering halves the file count — but
  it needs the per-frame hand-anchor and occlusion-order data that the current
  record says does not exist.

**Panels and UI**

- **R-14.** Every `PixelFrame` is wrapped in a `RepaintBoundary`. Its
  `shouldRepaint` may compare the image and the asset path and nothing else —
  never the panel `Size`.
- **R-15.** A frame whose tiling exceeds **32 strip patches** must batch through
  `canvas.drawAtlas` rather than issuing N `drawImageRect` calls.
- **R-16.** The `PanelSkins` registry keeps its **one-commit revert**: empty
  registry ⇒ identical layout, reading and navigation, enforced by CI. It is the
  performance escape hatch as well as the art one.
- **R-17.** `Scripts/check-ui-boundary.sh`'s pattern is extended to match
  `drawImageRect|drawImageNine|drawAtlas|drawRawAtlas`, so canvas-level image
  painting is confined to `pixel_asset.dart` the way the `Image.*` constructors
  already are. A guard with a hole shaped like the next feature is worse than no
  guard.

**Rebuilds and audio**

- **R-18.** `AtlasScene` is memoised in `_WorldScreenState` on the session fields
  it reads. A session notify that does not move the player, change a route or
  reveal a rumour must not rebuild the atlas.
- **R-19.** **No widget constructs an `AudioPlayer`.** Every sound goes through
  `AudioController` via `AudioScope`. This is what makes the duplicate-player
  defect class unrepresentable rather than merely avoided; it must survive the
  overhaul.
- **R-20.** Any new feedback signal separates **cadence** from **drawn frame**,
  per `ambient_stage.dart`'s `_cursor`/`_frame` split, so gating motion never
  gates sound (M-16). In particular, no haptic or cue may fire from a
  `ChangeNotifier` callback on a screen the player cannot see — the existing
  instance at `craft_screen.dart:1181` should be fixed in passing.
- **R-21.** ≤ **4 simultaneous audio voices** (2 music + 2 SFX). A design that
  needs a fifth needs a mixing design first.

**Verification**

- **R-22.** Before the milestone closes, the World tab and the busiest crafting
  screen are measured on the **iPhone 15 Pro Max in profile mode at 120 Hz**,
  not on a simulator and not at 60 Hz. The ProMotion budget is 8.33 ms and it is
  the binding constraint; a 60 Hz pass proves nothing about the target device.

---

## 11 · What this audit did not cover

- No profiling was run. There is no harness (§8) and building one is subject to
  G-1 / M-01 — it needs a named uncovered risk first. Every figure here is
  static analysis and arithmetic over measured file headers.
- Android was not examined (`RULES.md`: an iOS task does not touch Android).
- `packages/stride_core`, `stride_health`, `stride_storage` were not examined;
  no rendering or asset code lives there.
- The atlas's *content* is FOUNDATION-F's subject; this report treats
  `atlas_base.png` only as 4.000 MiB of texture.
- The audio *mix* is FOUNDATION-E's subject; this report treats the audio layer
  only as players, voices, timers and bytes.
