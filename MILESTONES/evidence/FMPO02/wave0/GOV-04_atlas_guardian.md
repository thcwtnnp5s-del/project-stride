# GOV-04 — World Protection / Atlas Guardian report

Facts only, gathered by repo investigation for the planned FMPO02 regional
repaint / expansion. No art direction proposed.

## 1. The atlas master and how it renders

- **File:** `assets/art/v1/world/atlas_base.png` — one native tile, **1024×1024**
  (`assets/content/v1/atlas/atlas_layout.json` → `base.tiles[0]`: `{asset:
  "world/atlas_base", x:0, y:0, width:1024, height:1024}`).
- **World scale:** `scale: 6` (world pixels per native pixel). **World surface:
  6144×6144 world px.**
- **Loaded by:** `lib/runtime/atlas_layout.dart` (`AtlasLayout.parse`,
  `loadAtlasLayoutFromAssets`) — read synchronously at `StrideSession.start`
  from `assets/content/v1/atlas/atlas_layout.json` (path constant
  `atlasLayoutAsset`). Async loading is forbidden under `lib/ui` by
  `Scripts/check-ui-boundary.sh`, so this is a pre-`runApp` read, not a
  `FutureBuilder`. On parse failure the session records problems and
  `WorldScreen` falls back to a non-atlas list presentation
  (`lib/ui/screens/world/world_screen.dart`, `_ListFallback`).
- **Rendering widget:** `lib/ui/screens/world/atlas/atlas_viewport.dart`
  (`AtlasViewport`/`AtlasViewportState`) inside `lib/ui/screens/world/world_screen.dart`
  (`WorldScreen`). Layer stack, back to front, all children of one
  `Transform`+`OverflowBox` sized to the world: `AtlasBaseLayer` →
  `AtlasRouteLayer` → `AtlasLandmarkLayer` → `AtlasOverlayLayer` →
  `AtlasMarkerLayer` (`lib/ui/screens/world/atlas/atlas_layers.dart`).
  The join between layout data and session state is `AtlasScene`
  (`lib/ui/screens/world/atlas/atlas_layout.dart`, note: this is a *different*
  file from `lib/runtime/atlas_layout.dart` — same name, two libraries).
- **Pannable/zoomable:** yes, hand-rolled `GestureDetector` scale gesture
  (no `InteractiveViewer`, deliberately — pixel-snapping and zoom-grid
  requirements it doesn't promise). Drag pans, pinch zooms about the fingers,
  tap on a marker selects. Zoom range is `AtlasZoom.forScale(layout.scale)`:
  `absoluteFloor = 1/scale` (native ×1), `initial = 2/scale` (native ×2, the
  opening view), `max = 4/scale` (native ×4). On the shipped scale-6 layout
  these are 0.167 / 0.333 / 0.667. The floor is the larger of
  "whole world fits viewport width" and `absoluteFloor`, snapped to a
  device-pixel-integral grid (`AtlasViewportState.minZoom`,
  `_zoomUnit`). Camera and zoom are snapped to whole device pixels
  (`_snapCamera`, `_snapZoom`) so pixel art is never bilinear-blurred.
- **Viewport model:** the world is drawn at native size inside a
  world-sized `OverflowBox`/`Transform`, translated+scaled by camera/zoom;
  `ClipRect` bounds the visible window. An "overview" boundary
  (`zoom < zooms.overviewBelow`, i.e. below native ×2) thins landmark
  captions/marker art/scatter props off zoomed-out views — one LOD
  boundary, no LOD engine.
- **Location coordinates:** `assets/content/v1/atlas/atlas_layout.json`
  → `locations[]`, each `{id, x, y, hitRadius, landmark}` in **world pixels**.
  Game content (`assets/content/v1/locations.json`) knows nothing about
  pixels; `AtlasLayout` knows nothing about the player — `AtlasScene.join`
  (`lib/ui/screens/world/atlas/atlas_layout.dart`) is the one place the two
  are joined, once per build.

## 2. The protected-zone registry

Two registries, both enforced in `Scripts/art/package-art.js` at packaging
time (`--check` / build), both documented in `RULES.md` **A-4**:

### A. The frozen core (A-4 guard proper)

- **Constant (package-art.js, in the `world/atlas_base.png` composition
  block):**
  ```js
  const PROT = { x0: 256, y0: 256, x1: 768, y1: 768, band: 20 };
  ```
  All coordinates are **1024² atlas px** (native, i.e. world px ÷ 6).
  A snapshot (`approved = base.clone()`) is taken after the byte-preserved
  512² master + five approved-era static patches + the dither crossfade are
  composed ("the 559669e state"). Every repair layer composited after that
  point (WACUI bridges, World Atlas Restore 01 adopts, etc.) is restored
  back to the snapshot for any pixel deeper than a 20px hash-feathered rim
  band (`protDepth`, `keepRepair`). A final guard walks every pixel with
  `protDepth > PROT.band` and throws if it differs from the snapshot (deep
  ocean-conform teal is exempt):
  > `throw new Error(`world/atlas_base: protected interior drift — ${drift}
  > px of the approved master core were repainted by a repair layer
  > (M-15)`);`
  **Effective hard-frozen core** (per `PROTECTION_PLAN.md`, ATLAS-C audit):
  **(276,276)–(748,748)** atlas px, water-exempt — i.e. the declared
  256–768 rect minus the 20px writable rim on every side.
- All five playable locations (Haven's Rest, Whispering Woods, Stonefall
  Mine, Forgotten Hollow, Frostmere) and the Amberfield painted town sit
  **inside this hard-frozen core** already, per `PROTECTION_PLAN.md`.

### B. The landmark registry (A-4 extension, outside/at the edge of the core)

- **File:** `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/landmark_registry.json`.
  15 entries, each `{id, x, y, w, h}` in atlas px, each with a committed
  golden PNG at `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/goldens/<id>.png`
  extracted from the accepted composite post-ocean-conform.
- **The 15 byte-enforced landmark goldens** (path stem
  `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/goldens/`) and their
  registered rects (atlas px):

  | id | x,y | w×h |
  |---|---|---|
  | frostmere_north_wall | 400,256 | 160×20 |
  | east_watchtower_flank | 744,273 | 8×50 |
  | volcano_east_cliff | 752,260 | 72×210 |
  | roadjoin_corridor_west | 216,480 | 60×78 |
  | west_caravan_road | 128,495 | 128×80 |
  | caravan_corridor | 199,506 | 46×26 |
  | stag_box | 156,493 | 28×22 |
  | flock_south | 456,748 | 64×27 |
  | south_strand_w | 128,810 | 400×60 |
  | south_strand_e | 512,810 | 288×60 |
  | wanderers_isles_w | 785,490 | 80×47 |
  | wanderers_isles_e | 920,503 | 85×34 |
  | cinder_skerries | 920,175 | 80×75 |
  | far_isles | 940,205 | 55×80 |
  | ne_iceberg | 974,210 | 17×15 |

- **package-art.js enforcement (quoted):**
  ```js
  for (const lm of reg.landmarks) {
    const golden = png.load(path.join(REM01, 'goldens', `${lm.id}.png`));
    ...
    if (drift > 0) {
      throw new Error(`world/atlas_base: protected landmark '${lm.id}' drifted ` +
        `(${drift} px vs its golden) — a layer repainted a registry feature ` +
        `(A-4 extension, World Atlas Remaster 01)`);
    }
  }
  ```
  Deep-teal water inside a golden is exempt (same exemption as the core
  guard, because the global ocean conform's statistics legitimately shift
  when any layer touches any water). "Deliberate re-authoring of a landmark
  = re-extracting its golden in the same commit; the golden's git diff is
  the authorization" (registry file's own header comment).

## 3. Known defect register

**Source:** `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/iteration_02/WORLD_ATLAS_REMASTER_01_DEVICE_DEFECT_REGISTER.md`
(2026-08-28, branch `world-atlas-remaster-01`, baseline `6375851`), authority
= seven physical-iPhone screenshots taken by the owner. Coordinates are
1024² atlas px. Severity: P0 world-illusion blocker, P1 strong distraction,
P2 cosmetic.

| ID | Atlas (x,y) | Symptom | Sev | Status after iteration 02 |
|---|---|---|---|---|
| D-01 | x 250–268 × y 260–780 (+ledger segments) | Forest wall: dense canopy ends on a razor vertical against open plain — master-core west face showing through too-thin rim | P0 | Partial (DET meadow-side stamp fringes shipped; canopy-face bays deferred to post-reset GEN) |
| D-02 | y 810–870 × x 0–560 | Latitude layer-cake: three horizontal bands (sward/sand/lime) across the south | P0 | Not fixed — blocked on Q-13 (lime-identity decision) |
| D-12 | x 110–280 × y 855–968 | SW dark forest slab, near-black canopy on brightest lime ground, worst value cliff | P0→P1 | Partial (DET fringes shipped; interior glades OWNER) |
| D-04 | x 250–350 × y 750–805 | Canopy/sand scalloped cut + red route-dot debris | P1 | Partial (red-dot despeckle shipped; banding is OWNER/A-4) |
| D-05 | x 620–780 × y 800–870 | SE cape staircase; **self-inflicted**: a ghost-sail flotsam fill rect offset-copied open sea over a generated beach corner | P1 | Fixed (fill-predicate fix + golden re-extraction shipped) |
| D-03 | x 865–1024 × y 0–110 | Pale panel in floe field | P1→P2 | Native-verified clean (minification artifact, not a real defect) |
| D-06 | x 257–374 × y 257–272 | Treeline confetti: 74 isolated dark flecks (owner red box) | P1 | Fixed (DET despeckle + straggler stamps shipped) |
| D-07 | x 220–242 × y 120–180 | R5 remnant panel, straight edges | P1 | Not fixed — GEN post-reset |
| D-08 | x 435–530 × y 205–270 | Ghost mountain: painterly smudge amid crisp peaks | P1 | Not fixed — GEN post-reset |
| D-09 | x 380–660 × y 755–775 | Marsh→silt hard join, no interleave | P1 | Not fixed — GEN post-reset |
| D-10 | x 952–970 × y 265–282 | Hollow atoll ring, unfinished read | P1 | Not fixed — GEN post-reset |
| D-11 | x 795–815 × y 0–150 | Vertical floe texture-density seam | P1 | Not fixed — GEN post-reset |
| D-14 | x 705–761 × y 235–303 | Green confetti/drip smear over ice cliff (owner green box, "north's ugliest patch") | P1 (owner-marked) | Fixed (DET cleanup shipped) |
| D-13 | x 370–420 × y 590–675 | Farm/forest hard join, zero hedge | P2 | Not fixed — **OWNER only** (inside A-4 core; logged, not touched) |
| D-15 | x 741–748 × y 820–855 | Orphan surf column west of D-05's fill rect | P2 | Unresolved / re-log |
| D-16 | x 760–900 × y 60–200 | Floe speckle → gray static at zoom | P2 | Not fixed — GEN post-reset with D-11 |
| D-17 | x 270–340 × y 260–350 | Conifer sprite corduroy (repeated columns) | P2 | Not fixed — mostly inside A-4 core, OWNER/accept |
| D-18 | x 40–75 × y 270–320 | Flat olive band vs glacier, hard edge | P2 | Not fixed — GEN post-reset |
| D-19 | x 620–720 × y 745–770 | Rust speckle band, marsh/sea | P2 | Not fixed — GEN post-reset with D-09 |
| D-20 | x 740–775 × y 720–765 | Teal pixel spray, island shore | P2 | Not fixed — DET despeckle candidate |
| D-21 | islands (800–860,490–535) | Twin islands read copy-pasted | P2 | Accept this round |
| D-22 | (230–320,180–260),(220–265,380–420) | Ice crack-cell density boundary | P2 | Accept/fold into north pass |
| D-23 | ≈(800,895),(930,895) | Two identical wave-mark clusters | P2 | DET candidate / accept |
| D-24 | x 10–90 × y 690–780 | Boulder confetti on plain | P2 | Accept; GEN foothill pass post-reset |
| D-25 (ATLAS-K addendum) | mask x 380–670 × y 748–806 | Delta's western braids die in dry sand at y=838 | P1 | Not fixed — S3/S4 "Delta apron" GEN post-reset |
| D-26 (ATLAS-K addendum) | crop ≈(480,0) 200×280 | NE ice-character luminance split (constructed-looking, no seam metric catches it) | P1 | Not fixed — R6 "North Shelf Join" GEN post-reset |

Not exposed by iteration 02 (neither confirmed nor cleared): a mint remnant
(560–615, 0–95); a D-7 floe corner (510,27); owner_04's peninsula left edge
(occluded by owner's own markup, needs a clean re-shot).

**As of VAWO01** (`MILESTONES/VISUAL_AUDIO_WORLD_OVERHAUL_01.md`, "Known and
not fixed"): *"The atlas master was not repainted... Left alone
deliberately — four passes have failed there (M-12/M-14/M-15) and the
owner's own mandated repair loop is single-defect and device-verified, with
no device available this session."* The defect register above is therefore
still the live state entering FMPO02.

## 4. The owner's mandated repair loop

**Written in `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/README.md`**
(§10, "Stop conditions"), quoted in full:

> "**Per-region loop (mandatory, the owner's single-defect discipline at
> regional grain):** capture BEFORE → state the problem → geographic intent
> → protected zones → generate → inspect variants → select/reject →
> integrate in the production pipeline → regenerate the shipping atlas →
> inspect full atlas, region context, every perimeter, phone-FOV, max zoom
> → ACCEPT / REWORK / REJECT → only then the next region. Never a batch of
> unreviewed regions. **The physical iPhone remains the final authority**;
> this round's desk verdicts are staging for the owner's device checklist."

Referenced again in `MILESTONES/VISUAL_AUDIO_WORLD_OVERHAUL_01.md` line 436:
*"the owner's own mandated repair loop is single-defect and
device-verified"*.

The underlying rule is `RULES.md` **A-4** ("Approved atlas interiors are
protected in tooling, and a repair may write only its transition band" →
`MISTAKES.md` M-15) plus **A-3** ("Production atlas expansions are
transition-authored across every boundary... no generated boundary ships
until a blind read at iPhone-viewport scale confirms biome, coastline,
detail-scale and palette continuity, and no visible generated rectangle
remains" → `MISTAKES.md` M-12, M-14).

**Is a broad regional repaint permitted?** Not as a batch. The loop is
explicit that it runs **one region at a time**, each carried through
generate → integrate → regenerate the shipping composite → full-atlas
device-scale inspection → an explicit ACCEPT/REWORK/REJECT verdict —
**before the next region starts**. "Never a batch of unreviewed regions" is
the operative constraint; a plan that authors N regions and then reviews
all N at once is exactly the shape the owner has ruled out. Evidence a
region's repair must carry before it may ship: (1) it stayed inside its
declared protected zones (A-4/A-3 tooling checks pass — core guard +
landmark goldens), (2) a blind read at iPhone-viewport scale at the
composite, high-zoom, and phone-FOV levels showing biome, coastline,
detail-scale/drawing-hand and palette continuity across every boundary the
repair created (A-3), (3) an explicit owner ACCEPT on a physical iPhone —
desk/device-simulated verdicts are staging only, not the verdict itself.

## 5. The overlay animation layer

- **Layout JSON path:** `assets/content/v1/atlas/atlas_layout.json`,
  `overlays[]` array (schema documented in `lib/runtime/atlas_layout.dart`,
  class `AtlasOverlay`). Current file: `schemaVersion: 5`, **32 overlays**.
- **Schema fields** (`AtlasOverlay`, all in world pixels/ms except noted):
  - `asset` — key resolved by `AtlasAssets.framePath` to
    `assets/art/v1/env/<asset>_f<n>.png`.
  - `x`, `y` — world coordinate of the sprite's top-left at drift/travel zero.
  - `width`, `height` — native frame size (native px, scaled ×`layout.scale` at draw).
  - `frames` (`frameCount`), `frameMillis` — loop length and per-frame hold.
  - `drift: {x,y}` — world px/sec continuous drift; wraps at the world edge
    (mutually exclusive with `travel`).
  - `opacity` (default 1) — compositor multiplier in (0,1].
  - `intervalMillis` (v4, default 0) — quiet gap between plays; 0 = continuous loop.
  - `travel: {x,y}` (v5) — world px/sec moved *during one play*, measured
    from the end of the quiet gap; never wraps; requires `intervalMillis`
    and excludes `drift`.
  - `playLoops` (v5, default 1) — how many times the frame loop repeats
    within one play.
  - Derived: `activeMillis = frameCount*frameMillis*playLoops`,
    `cycleMillis = activeMillis+intervalMillis`, `visibleAt(t)`,
    `frameIndexAt(t)`, `playMillisAt(t)`.
- **Dart driver:** `lib/ui/screens/world/atlas/atlas_layers.dart`,
  `AtlasOverlayLayer` / `_AtlasOverlayLayerState`
  (`with SingleTickerProviderStateMixin`).
  - **Ticker:** created only `if (widget.scene.layout.overlays.isNotEmpty)`
    (`createTicker(_onTick)..start()` in `initState`); disposed in `dispose`.
  - **Coarse repaint:** `_onTick` computes a cheap fingerprint
    (`_frameKey`) of every overlay's visibility/frame-index/drift position
    and only calls `setState` when it changes — not on every vsync.
  - **Pause-when-hidden:** the ticker itself doesn't check visibility; it is
    wrapped in a `TickerMode` at the viewport (`AtlasViewport` doc comment:
    "Motion is gated... through a single `TickerMode` here... Since the
    shell keeps every tab's screen alive (Fable V2), what stops the atlas
    when its tab is hidden is the shell's own per-tab `TickerMode` wrap
    (`stride_shell.dart`), not an unmount — the two TickerModes nest, and
    either being disabled silences everything here.") An intermittent
    overlay is simply not built during its quiet gap (comment in
    `AtlasOverlayLayer.build`), and with the ticker off `_elapsed` holds so
    frozen frames read as a held/absent creature, never a mid-appearance freeze.
  - **Precaching:** `didChangeDependencies` precaches every frame of every
    overlay once (`precacheImage`).
  - **Frame timing:** `frameIndexAt`/`visibleAt`/`playMillisAt` are pure
    functions of elapsed `Duration` on `AtlasOverlay` (`lib/runtime/atlas_layout.dart`),
    so the driver only supplies the clock.
- **All 32 existing overlays** (asset / x,y / w×h / frames / cycle):

  | asset | x,y | w×h | frames×ms | interval | travel/drift | opacity |
  |---|---|---|---|---|---|---|
  | overlay_snow_flurry ×3 | (2736,1716)(3126,1896)(2496,2106) | 64×64 | 8×167 | – | – | 1 |
  | overlay_forest_mist ×4 | (1806,2616)(2076,3516)(1776,4056)(2976,4236) | 96×48 | 6×250 | – | – | 0.4 |
  | overlay_birds ×3 | (3336,2616)(4056,3336)(2616,3876) | 24×24 | 6×167 | – | drift(16,-3) | 0.9 |
  | overlay_smoke ×2 | (2664,3036)(3342,2940) | 16×14 | 6×220 | – | – | 0.8 |
  | overlay_volcano | (4008,1704) | 64×64 | 17×250 | 14000 | – | 1 |
  | overlay_tree_rustle_a | (1656,3576) | 48×48 | 9×300 | 9000 | – | 1 |
  | overlay_tree_rustle_b | (2112,3960) | 44×44 | 9×320 | 13000 | – | 1 |
  | overlay_ripple_coast | (4056,3216) | 40×48 | 8×350 | – | – | 1 |
  | overlay_ripple_delta | (3720,3960) | 36×48 | 8×350 | – | – | 1 |
  | overlay_cloud_shadow ×2 | (2436,3186)(2136,3686) | 96×48 | 1×1000 | – | drift(12,0) | 0.16 |
  | overlay_cloud_wisp | (3036,2336) | 96×48 | 1×1000 | – | drift(9,0) | 0.3 |
  | overlay_fire3 | (1704,3744) | 44×52 | 10×200 | – | – | 1 |
  | overlay_yeti2 | (2940,1944) | 44×34 | 8×350 | – | – | 1 |
  | overlay_bear2 | (2040,3552) | 26×28 | 19×320 | 20000 | – | 1 |
  | overlay_nessie | (3972,3459) | 44×33 | 17×400 | 26000 | travel(-12,0) | 1 |
  | **overlay_skydragon** (existing green dragon) | (2028,1968) | 68×31 | 28×400 | 40000 | travel(-30,-5), playLoops 1 | 1 |
  | overlay_whale | (4848,3588) | 38×41 | 9×350 | 30000 | – | 1 |
  | overlay_ship | (4728,3888) | 15×20 | 1×14000 | 45000 | travel(-9,4) | 1 |
  | overlay_stag | (936,2958) | 28×22 | 20×400 | 34000 | – | 1 |
  | overlay_flock | (2736,4380) | 64×40 | 13×250 | 23000 | – | 1 |
  | overlay_caravan | (1350,3072) | 20×19 | 1×12000 | 52000 | travel(-12,-1) | 1 |
  | **overlay_redwyrm** (VAWO01) | (4416,1836) | 72×32 | 9×400 | 61000 | travel(30,-13), playLoops 1 | 1 |
  | **overlay_stormdrake** (VAWO01) | (4992,4128) | 72×32 | 9×380 | 67000 | travel(-30,9), playLoops 1 | 1 |

  (Counts of 1 for snow_flurry/forest_mist/birds/cloud_shadow entries above
  reflect multiple placements of the same asset at different coordinates,
  each its own JSON overlay object.)

- **Existing green dragon:** `env/overlay_skydragon`, frames
  `assets/art/v1/env/overlay_skydragon_f0.png` … `_f27.png` (28 frames,
  68×31 px each, verified via `identify`), at world (2028,1968), a single
  40s-interval play that travels (-30,-5) world px/s. Per
  `VISUAL_AUDIO_WORLD_OVERHAUL_01.md`: "the dragon on the volcano is the
  largest and is earned."
- **VAWO01 red wyrm / storm drake:** `env/overlay_redwyrm` (9 frames,
  `_f0`…`_f8`, 72×32 px, `assets/art/v1/env/overlay_redwyrm_f*.png`) at
  world (4416,1836); `env/overlay_stormdrake` (9 frames, `_f0`…`_f8`,
  72×32 px, `assets/art/v1/env/overlay_stormdrake_f*.png`) at world
  (4992,4128). Milestone acceptance criterion 22: "The red wyrm and the
  storm drake read as different creatures on the world map, and neither
  obscures a settlement or a route."
- **The three landmark props** (scatter props, `AtlasProp`, non-interactive,
  not the `landmarks[]` named-caption list): declared in `atlas_layout.json`
  `props[]`:
  - `env/prop_rimespire` at world (4944,936), native 48×72,
    anchor (24,71) — `assets/art/v1/env/prop_rimespire.png` (48×72 px file).
  - `env/prop_lanterngard` at world (396,2544), native 72×56,
    anchor (36,55) — `assets/art/v1/env/prop_lanterngard.png` (72×56 px file).
  - `env/prop_black_gable` at world (4716,4716), native 56×52,
    anchor (28,51) — `assets/art/v1/env/prop_black_gable.png` (56×52 px file).
- **What adding a new travelling creature requires, exactly:**
  1. PNG frame sequence at `assets/art/v1/env/<name>_f0.png` … `_f<n-1>.png`,
     all identical size, transparent background (art produced through
     PixelLab per A-1/A-2). No `pubspec.yaml` edit needed — the whole
     `assets/art/v1/env/` directory is already declared
     (`pubspec.yaml` line 196), guarded by `package-art.js --check` rather
     than a per-file manifest.
  2. One new object appended to `overlays[]` in
     `assets/content/v1/atlas/atlas_layout.json`: `asset` (key, no path/ext),
     `x`,`y` (world px spawn/origin), `width`,`height` (native px, must match
     the PNG headers exactly or `PixelAsset` flags a mismatch in debug),
     `frames`, `frameMillis`. For a creature that appears/withdraws rather
     than loops forever: `intervalMillis` (>0, needs schemaVersion ≥ 4). For
     a creature that flies/swims/walks a stretch during its play rather than
     idling or wrapping: `travel:{x,y}` world px/s + `playLoops` (needs
     schemaVersion ≥ 5, and requires `intervalMillis`, and is mutually
     exclusive with `drift`). For a creature that loops in place forever
     while gently drifting and wrapping at the world edge instead: `drift:{x,y}`.
  3. `AtlasLayout.validateAgainst`/`_overlay` parsing will refuse: zero/negative
     size or frame count, `opacity` outside (0,1], negative `intervalMillis`,
     `playLoops<1`, both `travel` and `drift` set, `travel` without
     `intervalMillis`, or a spawn point outside the 6144×6144 world.
  4. If the new sprite's coordinate lands inside the protected core (atlas
     px 276–748 after ÷6, i.e. world 1656–4488) or overlaps a registered
     landmark's rect (§2), the sprite itself doesn't touch `atlas_base.png`
     (it composites at runtime, not into the master), so it does **not**
     trip the A-4 core/landmark guards — those guards protect the base
     painting, not the overlay layer. Placement still must not obscure a
     settlement or route per the milestone's own acceptance bar (criterion 22).
  5. No code change is required in `atlas_layers.dart` — the overlay driver
     is fully data-driven off the JSON; only genuinely new *behaviour*
     (a sixth motion mode beyond loop/drift/travel) would need a schema
     bump and driver change.

## 6. Region definitions (five locations, atlas pixel extents/anchors)

From `assets/content/v1/locations.json` (game content) joined to
`assets/content/v1/atlas/atlas_layout.json` `locations[]` (pixel anchors) and
`PROTECTION_PLAN.md` (painted footprints, atlas px = world px ÷ 6):

| Location | Terrain | World anchor (x,y) | hitRadius (world px) | Atlas-px marker | Atlas-px painted footprint |
|---|---|---|---|---|---|
| Haven's Rest (start, safe) | grassland | (2736,3126) | 72 | (456,521) r12 | 413–487 × 508–552 |
| Whispering Woods | forest | (2298,3054) | 72 | (383,509) r12 | ~300–430 × 460–560 |
| Stonefall Mine | foothills | (3396,2976) | 72 | (566,496) r12 | massif 513–613×468–523; adit 553–580×488–515 |
| Forgotten Hollow | forest | (3366,3306) | 72 | (561,551) r12 | 540–598 × 530–575 |
| Frostmere | alpine | (2988,1866) | 72 | (498,311) r12 | on the frozen basin (403–550×282–362 lake; 396–565×258–380 full cirque) |

All five sit inside the hard-frozen A-4 core (atlas 276–748 both axes), per
`PROTECTION_PLAN.md`. Roads (`atlas_layout.json` `routes[]`): Haven's Rest↔
Whispering Woods, Haven's Rest↔Stonefall Mine, Whispering Woods↔Stonefall
Mine, Whispering Woods↔Forgotten Hollow, Stonefall Mine↔Frostmere (5 routes,
each with a drawn polyline of 1–3 points).

## 7. What previous repaint attempts did, and why each failed

- **M-12 (World & Reward Depth 01, 2026-08-19):** grew the atlas from one
  384×688 tile to a 2×2 grid — **independent tiled generation**, same
  palette reference per tile, prompts written from measured edge colours,
  a seam-distance metric, re-rolls. **Failed** because a seam is a
  simultaneous hue/value/saturation/texture step and palette-distance
  metrics can't see texture or drawing-hand; two independent blind Visual
  QA passes read the composite as "four maps from different games pasted
  into a grid" despite passing single-tile viewports and the seam metric.
  335 generations spent; only one join shipped, two tiles withheld.
- **M-14 (World Map Polish 01/03, World Map Expansion Refinement 02, World
  Atlas Coherence UI 01, 2026-08-26):** **seam blending on a composed
  atlas** — byte-preserved master, style-referenced ring pieces against
  64² edge crops, a deterministic dither crossfade at each seam, palette
  mean/std conform for water/snow, `package-art.js --check` passing every
  round. **Failed** because pixel-edge continuity (what all of that
  measures) is not geographic/artistic continuity — the dither is a 1-D
  pixel swap along a perfectly straight lattice line, narrowing a seam to a
  noisy band but authoring nothing across it, so at the layout's ×6 display
  scale the owner's iPhone still saw straight rectangles (torn scan-line
  column, ice wall/comb, delta comb, ocean panel, beach cut-off) across
  four consecutive passes.
- **M-15 (World Atlas Coherence UI 01, found/fixed by World Atlas Restore
  01, 2026-08-27):** the *right* method from M-14 — **inpaint bridges over
  the seams from wide crops with frozen margins** (twelve bridges + seven
  edge fixes) — **failed** because "byte-preserved master" described only
  the input, and nothing in the pipeline enforced it on the output: bridges
  generated from wide crops landed wherever their crop reached (one 128px
  deep), and **35.3% of the master interior was repainted**, erasing the
  Frostmere frozen basin and the volcano's watchtowers. Three device
  passes reviewed only the seams being fixed and never audited the
  fix's own footprint against the pre-repair baseline. This is the failure
  that produced the A-4 tooling guard now in `package-art.js`.
- **Root-cause summary in one line each:** M-12 — texture/drawing-hand
  mismatch invisible to colour metrics. M-14 — pixel-continuity metrics
  measured the wrong thing; only phone-scale viewing ever caught the
  rectangle. M-15 — protection lived in intention ("bridges are for the
  seams") rather than in tooling, so a generous crop silently overwrote
  approved content.

## 8. Runtime memory

- **`lib/main.dart`** (before `runApp`):
  ```dart
  PaintingBinding.instance.imageCache
    ..maximumSize = 2000
    ..maximumSizeBytes = 48 << 20;
  ```
  Raised entry cap from Flutter's default 1,000 to 2,000 (the app ships 872
  PNGs today; VAWO01 pushed close to the default cap). `maximumSizeBytes`
  is deliberately **lowered** from Flutter's 100 MiB default to **48 MiB**
  — comment states total decoded art is ~20 MiB against a 44 MiB budget
  (`FOUNDATION_K_PERFORMANCE.md`), so 48 MiB is a ceiling the budget fits
  inside, making overspend show up as a visible eviction stutter rather
  than invisible growth.
  Also noted in the same comment block: **no `cacheWidth`/`cacheHeight`/
  `ResizeImage` is used anywhere** — the app magnifies pixel art at integer
  scale (L-18) and resampling at decode would drop columns before
  `filterQuality` is consulted, so downscale-on-decode is deliberately not
  applied to any art including the atlas.
  This is the only `imageCache`/`maximumSizeBytes` reference in `lib/`.
  A larger or additional atlas tile (atlas expansion) and any new creature
  frame sets added for FMPO02 count directly against this 48 MiB /
  2000-entry budget; no other budget or guard currently exists in code for
  atlas-specific memory.

## File/path index for follow-on work

- Atlas master: `assets/art/v1/world/atlas_base.png` (1024×1024)
- Layout data: `assets/content/v1/atlas/atlas_layout.json` (schema v5)
- Layout schema/loader: `lib/runtime/atlas_layout.dart`
- Scene join: `lib/ui/screens/world/atlas/atlas_layout.dart`
- Viewport: `lib/ui/screens/world/atlas/atlas_viewport.dart`
- Layers (base/route/landmark/overlay/marker): `lib/ui/screens/world/atlas/atlas_layers.dart`
- Screen: `lib/ui/screens/world/world_screen.dart`
- Asset path table: `lib/ui/icons/atlas_assets.dart`
- Packaging/protection tooling: `Scripts/art/package-art.js`
- Landmark registry + goldens: `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/landmark_registry.json`, `.../goldens/*.png`
- Protection plan (coordinate table, classes HF/FC/SOFT): `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/PROTECTION_PLAN.md`
- Device defect register: `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/iteration_02/WORLD_ATLAS_REMASTER_01_DEVICE_DEFECT_REGISTER.md`
- Repair-loop mandate: `GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/README.md` §10
- Rules: `RULES.md` A-1..A-4
- Mistakes: `MISTAKES.md` M-12, M-14, M-15
- Game content locations: `assets/content/v1/locations.json`
- Open questions blocking southern-zone repaint: `JOURNAL/OPEN_QUESTIONS.md` Q-13 (lime-identity / A-4 exceptions)
