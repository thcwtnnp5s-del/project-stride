# FINAL-08 — mobile performance review, FMPO02 wave 3 @ 9e555d3

## Measured
`git diff --stat 4d9a81f..HEAD -- assets`: 811 files changed, 785 PNGs (750 new,
35 modified). `du`: art/v1=8.4M, ui/v1=255K, assets/ total=29M. `main.dart:44-46`:
`imageCache.maximumSize=2000`, `maximumSizeBytes=48<<20` (48 MiB), unchanged.

Decoded (w×h×4) per category the brief named: atlas_base.png 1024²=4.00 MiB (1
file); 4 combat backdrops 192×128=0.375 MiB total; 39 overlay sequences /
`env/overlay_*`, 334 frames, 15×20..128×64 = 2.97 MiB; 425 equipment frames
`combat/traveler_*` (410@80×64, 9@56×64, 6@64×64) = 8.22 MiB across 12 loadouts;
11 surface tiles 32²=0.043 MiB; 10 bands 384×48=0.703 MiB. Sum of every category
resident **simultaneously** (never actually reached) ≈16.3 MiB = 34% of the cap.

## Findings

1. **NOTE** — `lib/ui/screens/world/atlas/atlas_layers.dart:376-384`. World tab
   precaches all 39 overlay sequences (334 frames, 2.97 MiB) unconditionally on
   first build, not just reachable ones (fairy_motes/whale/nessie are rare,
   single-region). Plus atlas_base (4.00 MiB) + 5 markers: ≈7.0 MiB per visit —
   cheap now, but overlay count went 0→39 in one round and this stops being free
   at 2-3x that. Fix: gate precache by region, or lazy-load on first paint.

2. **Confirmed non-issue** — `combat_assets.dart` `framesFor` (own doc: "the
   other enemies' tracks are not decoded") + `combat_stage.dart:309-317`.
   Precache is per-encounter — one backdrop + the *resolved* gear variant's 4
   tracks + the matched enemy's tracks + 2 effects, ~60-70 frames, never the
   425-frame equipment total. The brief's premise of eager precache is wrong.

3. **Confirmed non-issue** — `combat_stage.dart:271-278,323` binds gear once in
   `initState`/on enemy change only, but `combat_screen.dart:220` keys
   `CombatStage` on `_fightArrival` (full remount per fight); line 228 documents
   the snapshot as deliberate (GFCP01 item 5), not staleness.

4. **Confirmed non-issue** — `stride_shell.dart:158-187` gates all six tabs with
   `TickerMode(enabled: ...)`. `SurfaceFill`/`EdgeStrip`
   (`pixel_asset.dart:495-930`) both call `_slot.detach()` in `dispose()`, which
   calls `_stream.removeListener()` before clearing refs (`_AssetImageSlot`,
   line 391-397). `BandPlate` is stateless. Atlas overlay `Ticker` disposed at
   line 444. No leak in any of the three named widgets.

5. **NOTE** — `data_display.dart:364` `StrideButton`, 47 call sites (not 43).
   Each `PixelFrame` resolves one of two shared rasters (`btn_plate.png` 58×26,
   `btn_compact.png` 46×22, ≤6 KB combined); `ImageCache` dedups by `AssetImage`
   key, so 47 instances share one decode each. No multiplicative cost.

6. **NOTE** — `pubspec.yaml:264-268`. The bulk families behind most of this
   round's 750 new files (`env/`, `combat/`, `world/`, `ambient/`, `node/`,
   `work/`, `reward/`) are whole-directory entries, not per-file rows, so
   `AssetManifest` growth is directory-count, not +750 rows. No startup concern.

7. **SHOULD-FIX** — `assets/art/v1/world/region_map.png` (384×640=0.94 MiB,
   pre-existing) is drawn by `world_screen.dart:532` via its own
   `PixelScene`/`AssetImage`, outside `atlas_layers.dart`'s precache bookkeeping
   (finding 1). Not a regression, but the World tab's true worst-case first
   paint is ≈7.9 MiB, not 7.0 MiB — fold it into the World budget next round.

## Verdict
No blockers: the pessimistic sum of every packaged category (16.3 MiB) is 34%
of the 48 MiB cap, combat precache is scoped per-encounter not eager, and all
three disposal paths asked about are clean — ship, with finding 1 (plus its
finding-7 correction) tracked as the one eager-precache path to make
need-based before the overlay roster grows further.
