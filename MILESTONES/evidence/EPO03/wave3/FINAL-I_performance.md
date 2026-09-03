# FINAL-I — Performance review (EPO03 wave 3)

**Question:** does this round's art and layout make the game slower, heavier, or hotter?
**Base:** 59c4723 · **HEAD:** fable5-executive-production-overhaul-03 · **Device target:** iPhone 15 Pro (ProMotion 120 Hz)
**Generations spent:** 0.

**Method.** Everything under "measured" is `git ls-tree -rl` byte arithmetic, PNG IHDR
header reads (w x h x 4 = decoded RGBA), and JSON counting over
`assets/content/v1/atlas/atlas_layout.json`. Everything under "inferred" is read from
source. **No `flutter run`, no DevTools timeline, no device trace was available to me** —
so no statement below about actual frame times, raster times, or thermals is measured.
Where I say "should be cheap", that is a reading of the code, not a profile.

---

## 1. Bundle weight — MEASURED

| | 59c4723 | HEAD | delta |
|---|---|---|---|
| `assets/` files | 1,890 | 2,459 | **+569** |
| `assets/` bytes | 24,348,974 (**23.22 MiB**) | 25,407,842 (**24.23 MiB**) | **+1.01 MiB (+4.3 %)** |

Audio is unchanged at 18.56 MiB and is 77 % of the bundle. Every byte this round added is art:

| subtree | base files / MiB | HEAD files / MiB |
|---|---|---|
| `art/v1/combat` | 771 / 0.99 | 1,072 / 1.44 |
| `art/v1/ambient` | 484 / 0.56 | 600 / 0.70 |
| `art/v1/env` | 343 / 0.33 | 437 / 0.41 |
| `art/v1/world` | 7 / 0.75 | 7 / 1.01 (`atlas_base.png` repainted) |
| `art/v1/track` | — | 11 / 0.01 (new) |
| `art/v1/ui` | — | 8 / 0.00 (new) |
| `art/v1/reward` | 13 / 0.01 | 24 / 0.02 |
| `ui/v1` (kit + surface) | 0.09 | 0.11 |

Largest single additions are the 294 new `combat/traveler_*` equipment frames and the
repainted 1024-square `atlas_base.png` (977 KB on disk).

### Against the 48 MiB ceiling

**The 48 MiB figure is not a bundle cap — it is `imageCache.maximumSizeBytes` set in
`lib/main.dart:44-46`,** and FMPO02's 16.3 MiB was the pessimistic sum of decoded RGBA
for every category resident at once. Recomputed the same way at HEAD:

| category | FMPO02 | HEAD (measured) |
|---|---|---|
| `world/atlas_base.png` 1024-square | 4.00 | 4.00 |
| `world/region_map.png` 384x640 | 0.94 | 0.94 |
| atlas overlay frames (precache set) | 2.97 (334 frames) | **3.43 (287 frames)** |
| `combat/traveler_*` equipment library | 8.22 (425 frames) | **14.39 (719 frames)** |
| surface tiles + kit strips | 0.043 | 0.20 |
| bands / rails / track / reward / ui | 0.703 | 0.97 |
| **pessimistic simultaneous sum** | **16.3 MiB (34 % of cap)** | **~24.3 MiB (51 % of cap)** |

Still inside the cap, and still a sum that is never actually reached — the traveler library
is precached **per encounter, per loadout** (`combat_stage.dart:442-449`), and one loadout
is ~0.6 MiB (three 0.20 MiB groups), not 14.39 MiB. **Byte headroom is fine.**

### The one number that crossed a line — SHOULD-FIX

`imageCache.maximumSize = 2000` **entries**. PNG count in `assets/`:

- 59c4723: **1,834** — the whole corpus fit under the entry cap; LRU eviction was unreachable.
- HEAD: **2,388** — the corpus is now **119 % of the entry cap**.

`main.dart`'s own comment says the entry count "binds roughly four times sooner than the
100 MiB byte cap does, because the mean decoded PNG here is only ~23 KiB" — that is exactly
what has happened. A long session that visits the World tab, several combat loadouts, the
ambient work loops and the rebuilt screens can now exceed 2,000 live entries and begin
evicting, and the symptom that comment predicts is a re-decode stutter when a screen is
revisited, which reads as "the new art made it slow". The mean decoded PNG here is ~21 KiB,
so 2,388 entries is roughly 50 MiB — the byte cap and the entry cap now bind at about the
same point, where before neither could.

**Fix is one line:** raise `maximumSize` to ~3000 in `lib/main.dart:45` (cost: nothing, the
48 MiB byte cap remains the real governor). Not a blocker — the failure mode is a stutter,
not a crash, and it needs an unusually broad session to reach.

---

## 2. The World tab — inferred from code, not profiled

`atlas_layout.json` at HEAD: 39 overlays (base: 40), of which **16 carry a waypoint `path`**
(61 waypoints total, max 7 per path, speeds 5-42 world px/s), 2 carry a `breath` follower,
1 a `cloud` follower, 2 a `shadow`. Depth bands: 33 ground / 4 low air / 2 high air.
Layout `scale` is 6, so the world is 6144-square logical over a single 1024-square base image.

**Verdict: no step change. The layer is well built, and this round made it slightly heavier,
not structurally worse.**

What the code actually does, and why each item is or is not a cost:

- **One ticker for the whole layer** (`atlas_layers.dart:372`), not one per overlay. The
  layer is a single `RepaintBoundary` (line 605). 17 `CustomPainter`s exist across
  `lib/ui`; **all 17 implement `shouldRepaint`, and none returns a constant `true`.**
- **Nothing runs while the tab is hidden.** The viewport wraps everything in a `TickerMode`
  gated on `resumed` (`atlas_viewport.dart:402`), nested inside the shell's per-tab
  `TickerMode` (`stride_shell.dart:158-183`). Screens stay alive across tab switches, so
  images stay resident — but no frame is scheduled. Confirmed by reading; not observed.
- **Per-vsync work when nothing changes** is `_frameKey` (line 412): one pass over 39
  overlays doing modular arithmetic, plus for each of the 16 path overlays a `footAt`
  linear scan over at most 7 cumulative segments — called **twice** per path overlay per
  tick (once via `topLeftAt`, once via `flippedAt`), plus `breathPhaseAt` for two of them.
  Order of a few thousand double operations per vsync. In AOT Dart that is single-digit
  microseconds against an 8.3 ms budget. **Inferred, not measured** — but the shape is
  right, and the "coarse fingerprint, repaint only on a whole-world-pixel change" design
  is the correct one.
- **When the key does change**, `setState` rebuilds the whole overlay `Stack`. With the
  fastest mover at 42 world px/s the key changes every ~2-3 vsyncs for that sprite alone,
  and across 39 overlays the union will change on most frames — so assume the layer
  rebuilds at close to display rate whenever the World tab is frontmost. Each rebuild is
  about 45 widgets (39 sprites, up to 3 follower sub-stacks, 2 shadows), each an `Opacity`
  over a cached `RawImage`. That is an `OpacityLayer` per sprite handed to the compositor,
  which is the same shape the base commit already had with 40 overlays. The added cost this
  round is 3 nested follower `Stack`s and **2 `ColorFiltered` shadows
  (`atlas_layers.dart:569`) — two `srcATop` colour-filter layers on small sprite bounds,
  rebuilt on every overlay repaint.** Small, but yes: the shadows do repaint per frame,
  because they are drawn from the same rebuild as the creature that casts them. With two of
  them this is the right trade; a dozen would not be.
- **No image is resolved in `build()` anywhere.** `pixel_asset.dart` routes every asset
  through `_AssetImageSlot.resolve` in `didChangeDependencies` / `didUpdateWidget`
  (lines 400-425, 513-528, 915-930) and holds the decoded `ui.Image`. `Image.asset` appears
  in **exactly one file** (`pixel_asset.dart:125`), enforced by the existing guard.
- **The Stack is world-sized and unculled.** All 39 overlays are built and laid out
  regardless of viewport, including ones far off-screen. Raster is clipped, so the GPU cost
  is bounded, but the build/layout cost is not. At 39 this is noise; it is the axis that
  would bite if the layout grows to 150.

### The flagged eager precache — not fixed, marginally better and marginally worse

FMPO02 finding: `AtlasOverlayLayer.didChangeDependencies` precaches **every** overlay
sequence unconditionally on the first build of the World tab, region-blind. That is still
true at `atlas_layers.dart:379-401`, and it now also walks each overlay's `breath` and
`cloud` followers.

- Entries precached: **322 -> 287** (fewer, because the round consolidated sequences).
- Decoded bytes precached: **2.97 -> 3.43 MiB** (more, because the new sprites are larger).
- First World-tab visit therefore costs about 3.43 + 4.00 (`atlas_base`) + 0.94
  (`region_map`, which still bypasses this bookkeeping — FMPO02 finding 7, still open)
  = **~8.4 MiB decoded and 287 decode jobs, in one `didChangeDependencies`.**

**It did not get worse in the way that matters (entry count went down), and it did not get
fixed.** Carry it forward. Gating by region is still the right fix.

---

## 3. The rebuilt screens and the kit — inferred from code

Eight screens moved onto `EdgeStrip` / `KitPlate` / `PageGround` / `SectionCard` /
`PixelFrame`. Checked the three specific hazards the brief names:

- **`CustomPaint` repainting on every build** — no. All 17 painters gate on `shouldRepaint`
  with real field comparisons (`_SurfacePainter:578`, `_FramePainter:715`,
  `_EdgeStripPainter:1050`, `_StaticRingPainter:1036`, `_CaretPainter:750`). The two
  animated painters take `super(repaint: controller)`, which is the correct idiom.
- **Images resolved in `build()`** — none. See above.
- **A tiled loop that scales with screen size** — present by construction, but **the loop
  counts are small, and I measured the step sizes rather than guessing them:**
  - `paintSurfaceTile` (`pixel_asset.dart:481-483`) is a nested loop stepping by
    `tile.extent`. Every one of the 11 registered surfaces is **32 px native at x2 = 64
    logical px**. A full-screen `PageGround` on a 393 x 852 iPhone 15 Pro is
    ceil(393/64) x ceil(852/64) = **7 x 14 = 98 `drawImageRect` calls**. A typical
    350 x 80 card is **6 x 2 = 12**. This is nothing.
  - `_EdgeStripPainter` (line 1035) is a single-axis loop. The widest strip tile is 8 px
    native at x2 = 16 logical, so a full-width rule is **about 25 draws**; `KitRule` appears
    19 times across the UI, worst case a few hundred draws for a whole screen.
  - `_FramePainter` (lines 683, 697) tiles four edges: same order of magnitude.

  Total kit painting for a dense screen is low hundreds of `drawImageRect` calls with
  `filterQuality: none` and `isAntiAlias: false` — cheaper than the equivalent area of
  gradient or shadow work the dark cards used, and these painters do **not** repaint on
  scroll (their `shouldRepaint` sees no change).
- **No `BackdropFilter`, no `MaskFilter`, no blur anywhere in the new components.** Checked.
- **No new `repeat()` controller** outside the two that already existed
  (`ambient_stage.dart:678`, the atlas current-place pulse at `atlas_layers.dart:1071`).

**Verdict: the kit is cheaper per frame than a gradient-and-shadow card, not more expensive.**
The one thing I could not check without a device is whether the extra widget depth
(`PageGround` -> `SurfaceFill` -> `CustomPaint` -> `SectionCard` -> `PixelFrame` -> content)
costs measurable build time on the largest screens — `craft_screen.dart` (+1,376 lines) and
`skill_detail_screen.dart` (+1,451 lines) are the two that grew most and are the two to
watch.

---

## 4. Regressions with a name

| # | Severity | Name | Where |
|---|---|---|---|
| 1 | **SHOULD-FIX** | **Image-cache entry cap crossed.** 2,388 PNGs vs `maximumSize = 2000`. First round where a session can evict and re-decode. Shows as a stutter on *revisiting* a screen, not on first entry. | `lib/main.dart:45` |
| 2 | CARRIED | **Eager region-blind overlay precache**, 287 entries / 3.43 MiB in one `didChangeDependencies` on first World-tab entry (~8.4 MiB with base + region map). Jank risk is on the **first** World entry of a launch. | `atlas_layers.dart:379-401` |
| 3 | CARRIED | `region_map.png` (0.94 MiB decoded) still outside the World precache bookkeeping. FMPO02 finding 7, unchanged. | — |
| 4 | WATCH | **Shadows repaint with the creature** — 2 `ColorFiltered` layers on the overlay layer's per-frame rebuild. Correct at 2; do not let this reach a dozen without a device trace. | `atlas_layers.dart:569` |
| 5 | WATCH | **Overlay Stack is unculled** — all 39 built and laid out regardless of viewport. Noise at 39; the growth axis to watch. | `atlas_layers.dart:605-628` |
| 6 | WATCH | Deeper widget trees on `craft_screen` and `skill_detail_screen`. No code smell found; purely a note on where build time would show up. | — |

**No BLOCKER.**

**Memory step change:** yes, but a bounded one — pessimistic simultaneous decoded art went
16.3 -> ~24.3 MiB (34 % -> 51 % of the 48 MiB byte cap), driven almost entirely by the
traveler equipment library growing 8.22 -> 14.39 MiB, which is loaded per-loadout and never
resident whole. Real resident set on the World tab is about 8.4 MiB, up from about 7.9 MiB.

---

## What to put in front of the device pass

**In priority order:**

1. **Enter the World tab for the first time after a cold launch, and watch for a hitch.**
   287 decode jobs fire in one `didChangeDependencies`. This is the single most likely
   visible jank in the round, and it is the one finding a profile would settle immediately
   and I cannot.
2. **Then play a long session — World, several different combat loadouts, the work loops,
   the eight rebuilt screens — and come *back* to the World tab.** If it stutters on the
   return where it did not on the first visit, that is finding 1 (entry-cap eviction), and
   the fix is one line.
3. Pan and zoom the atlas continuously for a minute and note whether the device warms. The
   overlay layer rebuilds at close to display rate by design; the arithmetic says that is
   fine, but "the arithmetic says" is not a thermal measurement.

Everything else in this report is either measured bytes or a code reading, and neither
found a reason to hold the round.
