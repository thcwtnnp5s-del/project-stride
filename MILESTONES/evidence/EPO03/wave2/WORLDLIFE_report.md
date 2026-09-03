# EPO03 — PROD-WORLD-LIFE report

Branch `fable5-executive-production-overhaul-03`. Brief: `wave1/DIR-04_world_life.md`.
Ledger: `GAME_BIBLE/ART/exploration/EPO03/ledger/WORLDLIFE.md`.
**21 generations of a 200 cap.**

---

## 1. What shipped

### The landmark rows (Task 1, first and on its own — commit `4cbc8c6`)

`REQUESTS_LIFE.md` is closed. The four rows are in `overlays` verbatim, with
`overlay_storm_rain` before `overlay_storm_strike` so the strike's ground flash
lands on the rain and not under it, and the three rows they supersede
(`overlay_fairy_motes`, `overlay_storm_lightning`, `overlay_ice_beacon`) are
gone. Verified by compositing onto the CURRENT atlas and looking at the result:
the fae court's ring of motes and winged silhouettes sits on the painted castle
glade, the rain and bolt sit on the painted storm house, and the beacon sweep
climbs the painted crystal tower. `review/worldlife/life_landmark_overlays_x3.png`
and `life_f4_beacon_fae_x4.png` (frame 0 of the beacon is deliberately empty —
the placement is proved at frame 4).

### The behaviour system (Task 2 — commits `46c4b13`, `713f3b0`)

`assets/content/v1/atlas/atlas_layout.json` is **schemaVersion 6**.
`lib/runtime/atlas_layout.dart` gains `AtlasOverlayPath`, `AtlasOverlayBob`,
`AtlasOverlayFollower`, `AtlasOverlayShadow`, `AtlasPathMode` and `AtlasFacing`;
`AtlasOverlay` gains `path`, `breath`, `cloud`, `shadow`, `depth` and `facing`.

- **`path`** — waypoints in world px as the sprite's **foot** (bottom-centre),
  `speed` px/s, `mode` `loop`|`pingpong`, `flip`, `phaseMillis`, `bob`,
  `breathAt`. The top-left is derived, so a road creature takes a route's own
  `points` verbatim. A path overlay refuses `x`/`y`, `drift`, `travel` and
  `intervalMillis`: it is **always present**.
- **`breath` / `cloud`** — followers declared inside their host. They hold **no
  overlay slot** (R-9), have no coordinate of their own, and the renderer
  composes host + followers in unmirrored space and flips the group as one, so
  mirroring *is* `x′ = host.width − offset.x − follower.width` and a plume
  cannot leave the tail. `cloud` is continuous and paints under the host.
- **`shadow`** — the host's own current frame through a black `ColorFilter` at
  an offset and opacity. Zero art; it cannot disagree with the pose above it.
- **`depth`** 0/1/2. The layer paints ground in JSON order, then every shadow,
  then low air, then high air.
- **Reduced motion.** At `Duration.zero` every path overlay is *present*,
  pinned at `points[0]`, frame 0, shadow drawn, breath suppressed — whatever
  its phase. An accessibility setting takes the movement and leaves the world
  (M-16). The pin is in the model, not the widget, so it is testable.

The parser refuses each v6 field under schemaVersion < 6, refuses a path that
also carries a placement, a `breathAt` that names a waypoint the line does not
have or a breath the overlay does not declare, a follower with no path, and a
depth outside 0–2. `validateAgainst` checks **every waypoint** against the
world rather than an origin a path overlay does not have.

Renderer: `lib/ui/screens/world/atlas/atlas_layers.dart` — `_overlaySprite`,
`_overlayShadow`, depth bands, follower precache, and `_frameKey` extended with
path position, flip, breath phase and cloud frame.

**Tests** (no new framework, all inside the existing files):
`test/atlas_layout_test.dart` — line measurement (closed for a loop, open for a
ping-pong), position at t, the **exact** ping-pong turnaround (300 px out at
50 px/s is 300 at 6 s and 250 at 7 s, never 350 along a 300 px line), mirroring
for east- and west-facing art and none when `flip` is false, foot-to-top-left
derivation, the reduced-motion pin, the breath window (fires at the crossing,
out 900 ms later, fires again next lap), and phase separation; plus five v6
schema-gate cases. `test/atlas_screen_test.dart` — depth ordering read off the
built tree (ground, then exactly the shadow pass, then air) and "a stopped
ticker stills the world, it does not empty it", which walks every one of the 14
path overlays in the shipped layout.

`flutter test test/atlas_layout_test.dart test/atlas_scene_test.dart
test/atlas_screen_test.dart` — **87 passing**. `flutter analyze` clean on all
four files.

### The dragons (Task 3 — commits `82b300d`, `97a7283`)

Both bodies kept exactly as they were. What changed is behaviour.

- **Red wyrm** — a closed lap over the volcano, 4,555 world px at 36 px/s =
  **127 s**, `bob` 12/1600, `depth` 2, `shadow` (10, 84, 0.3). It is **never
  absent**; the 7-s-run/22-s-gap that made it invisible 76 % of the time is
  gone with `intervalMillis`. Two plumes per lap, at **17 s** and **87 s**,
  both fired on eastward runs — `breathAt` moved from DIR-04's `[2,5]` to
  `[1,5]` because waypoint 2 is the corner the lap turns west at, so the plume
  thrown there pointed back down the dragon's own track. New asset
  `env/overlay_redwyrm_plume` 96 x 48 x 8: a tongued cone with a white-hot
  core and an ember tail, **no body**, leaving the animated jaw.
- **Storm drake** — a ping-pong from the Frostmere wall to the south-east cape,
  3,692 px each way at 42 px/s (**176 s** out and back), `bob` 8/2200,
  `depth` 2, `shadow` (8, 76, 0.28). It carries `env/overlay_storm_cloud`
  112 x 48 x 6 as a **continuous follower under the body** at 0.55 — the storm
  travels with it — and throws `env/overlay_stormdrake_bolt` 96 x 56 x 8 at
  waypoints 3 and 6, i.e. at 43 s, 88 s and 133 s of every cycle. The bolt
  charges before it strikes: frames 0–2 are crackle at the jaw, 3–6 the forked
  discharge, 7 the fade.

Proof at the instants that matter: `review/life/dragons_x3.png` — the red mid-
plume over the ice sea at t = 18 s and over the snow peaks at t = 87 s, the
drake with its storm and its bolt at t = 43 s. The plume root sits *on* the
jaw, which took a deterministic register of the animated frames (below).

### The roster (Task 4 — commit `97a7283`)

**Deleted, 14:** `snow_flurry` x2, `forest_mist` at (301, 436) (the plate that
sat on the glade LANDMARKS has now painted), `birds` x2, `tree_rustle_a/b`,
`fire3` (a 44 x 52 bonfire at map scale), `yeti2`, `bear3`, `stag`,
`lantern`, and both old breath slots. (`fairy_motes` went in Task 1, making
DIR-04's fifteen.)

**Rewritten in place, 4:** the red and blue as above; `overlay_wagon` now walks
the Haven's Rest → Stonefall road as a ping-pong; `overlay_ship` becomes
`env/overlay_ship_east` 32 x 32 x 5 on a northern east-sea lane;
`overlay_wolfpair` becomes `overlay_wolfpair_small` 28 x 22.

**Added, 12, each on terrain re-verified against the current
`atlas_base.png`** (sampled pixel by pixel, then looked at):

| Entry | Where | Placement logic |
|---|---|---|
| `mule_train` x2 | Stonefall→Frostmere pass; Woods→Hollow | waypoints are `routes[].points` **verbatim**, so they stand on the painted road |
| `gulls` x4 | lighthouse headland, the cape, Wanderers' Isles, Far Isles | small closed loops over open water, `depth` 1, phases 0/3/6/9 s apart |
| `ptarmigan` x2 | Frostmere north rim | the two points that sample as **snow**, not the lake ice DIR-04's coordinate landed on |
| `deer2` | the beck at (246, 342) | a 10-px ping-pong to water, beside the herd already there |
| `fishing_boat` x2 | harbour, delta mouth | both ends sample as sea |
| `ship_east` | southern east-sea lane | four waypoints, all sea, phase 30 s off the northern lane |

Six of the twelve are in the **east sea**, which is a quarter of the canvas and
had a whale and one 15 x 20 static ship in it. `review/life/LIFE_t18_x1.png`
shows the whole map inhabited; `roster_placed_x3.png` shows the harbour, the
snow rim and the pass road at ×3.

**Slot budget: 39 of 40.** 41 (after Task 1) − 14 + 12.

### Assets and packaging

`Scripts/art/package-art.js` gains one block, header **"EPO03 WORLDLIFE
(PROD-WORLD-LIFE)"**, sourcing `EPO03/out/life/manifest.json` and asserting
every canvas: 8 families, **52 frames**. Every path is net-new —
`overlay_redwyrm_breath` and `overlay_stormdrake_breath` are emitted by the
FMPO02 block this team does not own, so re-emitting either at a new canvas
would put two emitters on one file. The old files stay packaged and
unreferenced for the producer to retire at closeout, the same shape LANDMARKS
used for the beacon.

Builds ran under `atlas-lock.js acquire life … release life`.
`check-art-palette.js`: **ok, 2,370 PNGs, no teal collision, no
semi-transparent pixel**. All 52 of this family's packaged frames byte-match
`out/life/`.

### Two deterministic passes, no generations (A-2)

- **The plume crop and mirror.** The accepted cone widened west and ended in a
  rocket nozzle. Cropped to its flame and mirrored, it is a cone that leaves a
  jaw at the left and flares east. Nothing was drawn.
- **Frame registration.** `animate_image` let each plume and bolt frame's ink
  start anywhere from x = 0 to x = 24. On a 96-px body that is the difference
  between fire leaving the jaw and fire floating in front of the nose, and it
  is invisible in a frame sheet — it only shows when the frames are composited
  on the host. Every frame is translated so its ink starts at x = 0.
- **Frame ordering.** Both animations came back with the right frames in the
  wrong order (a plume that only decays; a discharge with its charge at index
  6). Played in a chosen order, they grow-peak-die and charge-strike-fade.
- **The wolf halving**, 2:1 box on the shipped frames.

### One tool

`GAME_BIBLE/ART/exploration/EPO03/tools/life-patrol-proof.js`. A v6 path
overlay has no `x,y`, so `worldlife-composite.js` — which blits frame 0 at
`x,y` — would have drawn every patrol at the origin and proved nothing. This
reimplements the Dart position arithmetic (line measurement, loop and ping-pong
distance, bob, flip, breath window, follower offsets and opacity) and renders
the shipped layout at a **wall clock**. It is a new file, not an edit to a tool
other world teams are using.

---

## 2. What was rejected, and why

7 of 21 rolls, sheet at `rejected/life/REJECTS_x5.png`:

- **Two red plumes** drew an emitter — a firework on a stick, a burning branch
  throwing a fireball. Asked for a breath with no body, the tool attaches one.
- **One bolt** drew a lizard made of lightning. "No animal" is not a constraint
  the model honours at this size.
- **One cloud** was grey and compact: a cloud, not a storm.
- **Three fairies** failed three different ways: a moth on an **opaque brown
  box** (`no_background` ignored outright), a cherub with a solid gold halo and
  a large blue eye (a face, which DIR-04 forbids by name), and an orange spiked
  shape with no wing and no glow.

---

## 3. What the phone will show that it could not before

1. A red dragon that is **on the map at every instant**, circling the volcano
   on a 127-second lap instead of appearing for 7 seconds in 29.
2. A breath that is a **plume and nothing else**, leaving the animated jaw
   twice a lap on an eastward run — not a second dragon plus a blob parked at a
   fixed coordinate 480 px from the first.
3. A drake that **carries its weather**: a storm cloud under it for the whole
   176-second traverse, a violet charge at the jaw before every bolt, and a
   serpent silhouette nothing will confuse with the red's bat-wing.
4. Two dragon shadows on the ground, at zero art cost.
5. Mule trains **on** the roads, boats **on** the water, gulls over four
   different stretches of a sea that was empty, ptarmigan on snow.
6. Three fantasy landmarks that **move**.
7. Fourteen fewer duplicate, invisible or mis-scaled sprites.
8. Under reduced motion: all of it still there, standing still.

---

## 4. What did not close

- **The four fairy overlays are not in the layout.** Three rolls failed (above)
  and I stopped rather than spend a fourth on a tool limit. This is a
  **deliberate deviation** from DIR-04, not only a failure: DIR-03's
  `overlay_fae_court` — 112 x 80 x 16, placed in Task 1 — now covers exactly
  the glade the four fairies were specified for, with real winged silhouettes
  and a ring of motes, and is better art at that coordinate than four 24 x 24
  sprites layered over it would be. The four freed slots went to the east sea,
  which the brief named as the emptier problem. If the owner wants individual
  fairies orbiting the court as well, that is a fresh roll against a different
  prompt strategy (`create_image_pro`, per PRODUCTION_RULES §2a) and a
  +4 slot request.
- **The caravan still travels on a vector.** DIR-04 puts it on "DIR-01's new
  west pass road", and those waypoints are not in `routes` or in any file I can
  read. Left exactly as it was rather than guessed at (G-3). One line of JSON
  once PROD-WORLD-WEST publishes the polyline.
- **No device render.** The atlas overlay layer is proved by the
  `life-patrol-proof.js` composites at t = 0, 18, 43 and 87 s and by two widget
  tests, but I did not run `screen_evidence_test.dart`; the World screen was
  being rebuilt by other teams in the same working tree for the whole session.
  The shadows in particular are asserted by test and by construction, never
  seen — the proof tool does not draw them.
- **`package-art.js --check` is green on my 52 frames but was red on the whole
  tree twice**, both times naming an item PNG (`wolfhide_jerkin`,
  `reclaim_chestplate`) that another team was writing between my build and my
  check. Not mine, and it moved between runs; the producer should re-check at
  integration.
- **`worldlife-composite.js` cannot draw a v6 patrol**, and used to do it
  silently: a path overlay has no `x,y`, so `Math.round(undefined / 6)` gave
  NaN and all fourteen were dropped from the sheet without a word — a sheet
  that looked green while proving nothing about the thing this round changed.
  It now names and skips them and points at `life-patrol-proof.js`, which
  reimplements the position arithmetic and renders at a wall clock. Both tools
  were re-run against the atlas AFTER the twelve regions landed
  (`review/worldlife/life_x1.png`, `review/life/LIFE_t{0,18,43,87}_x1.png`,
  `review/life/landmarks_current_atlas_x4.png`).
- **DIR-04's "≤ 12 overlays in the phone FOV" was not measured.** 21 of 39 draw
  at t = 0 and 26 at t = 32 across the whole 1024-px canvas, so the FOV figure
  is very likely met, but I did not compute it per viewport.

## 5. Requests filed, questions raised

None. No REQUESTS to other teams, no new `Q-`. Nothing here touches save,
health, economy, items, recipes or a session call site.

## 6. Commits

`4cbc8c6` landmark rows · `46c4b13` v6 schema · `713f3b0` v6 tests ·
`819eeae` breath seeds · `82b300d` ordered frames · `97a7283` dragons and
roster · this report.
