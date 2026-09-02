# DIR-04 — World Life / Creature Director (EPO03 wave 1)

No generations spent. Coordinates are **atlas px** unless marked world (= atlas × 6).

## TOP FAILURES (phone-visible, ranked)

1. **Red dragon absent 76% of the time** — 7 s run, 22 s gap.
2. **Both breaths are a second dragon plus a blob** — no plume ever leaves the animated jaw.
3. **Blue drake: no charge, no storm, no cloud.**
4. **Fairies are six gold discs** (0033 resolved Q-28).
5. **Scatter, not habitation:** duplicate bears and yetis, three flurries, four mist plates, a 44×52 bonfire, wolves at twice deer scale.

## BEHAVIOUR SYSTEM (PROD-WORLD-LIFE owns `atlas_layout.dart` + `atlas_layers.dart`; schemaVersion 6)

```jsonc
{ "asset":"env/overlay_redwyrm","width":96,"height":64,"frames":9,"frameMillis":400,
  "depth":2, "faces":"east",
  "path":{ "points":[[4200,1440],[4800,1620],[5040,2100],[4770,2640],[4140,2850],[3540,2520],[3660,1680]],
           "speed":36, "mode":"loop", "flip":true, "phaseMillis":0,
           "bob":{"amplitude":12,"periodMillis":1600},
           "breathAt":[2,5],
           "breath":{"asset":"env/overlay_redwyrm_breath","width":96,"height":48,"frames":8,"frameMillis":120,"offset":{"x":88,"y":10}} },
  "shadow":{"dx":10,"dy":84,"opacity":0.3}, "opacity":1 }
```

- `points`: **world px of the sprite's foot (bottom-centre)**; top-left = (px − width·scale/2, py − height·scale), so road creatures take `routes[].points` verbatim. A `path` overlay has no `x/y`, `drift`, `travel`, `intervalMillis` and is **always visible**.
- L = polyline length (closed for `loop`). `loop`: s = speed·(t + phase) mod L. `pingpong`: s′ = speed·t mod 2L; s = s′ ≤ L ? s′ : 2L − s′. Frames loop independently.
- `flip`: mirror when the segment's dx disagrees with `faces` (`Transform.flip`). `bob`: y += A·sin(2πt/period).
- `breathAt`: when s crosses waypoint k, `breath` plays once at host top-left + `offset`, following the host, mirrored with it (x′ = host.width − offset.x − breath.width). Declared inside its host: **no overlay slot** (R-9).
- `shadow`: the current frame repainted black (`ColorFilter`) at `opacity`, offset (`dx`,`dy`), depth 0. Zero art.
- `depth` 0 ground (default) · 1 low air (birds, fairies, mist) · 2 high air (dragons, cloud). Paint 0 in JSON order, then shadows, then 1, then 2.
- **Reduce Motion / ticker off:** t = 0 — every path overlay *present*, pinned at `points[0]`, frame 0, shadow drawn, no breath.
- `_frameKey` adds path and breath state. Tests: v6 gates, position at t, flip, breath window, depth.

## WHAT TO REPLACE

| Asset | Verdict | Spec |
|---|---|---|
| `overlay_redwyrm_breath` | **REGENERATE plume-only 96×48**, 8 f | tongued hard-edged cone, orange-white core, ember tail; no body |
| `overlay_stormdrake_breath` | **REGENERATE plume-only 96×56**, 8 f | f0–2 charge (crackle at jaw, crest), f3–6 forked bolt, f7 fade; white core, violet halo, no teal |
| `overlay_fairy_motes` | **DELETE → 4 fairy overlays** 24×24, 4–6 f | one 6–8 px winged silhouette: cream wing, honey glow, 1 px body, no face |
| `overlay_ship` 15×20 1 f | **RE-ROLL 32×32**, 4 f | two-failure stop → keep old |
| `overlay_wolfpair` 56×44 | **HALVE deterministically** (2:1 box, palette snap, `despeckle 4`) | fallback pixen 28×28 |
| **DELETE as clutter (15)** | `snow_flurry`×2, `forest_mist`@(301,436), `birds`×2, `tree_rustle_a/b`, `fire3`, `yeti2`, `bear3`, `stag`, `lantern`, both breath slots, `fairy_motes` | invisible, duplicate, wrong scale or repainted terrain |

## WHAT TO KEEP

Red body 96×64 (accepted wingbeat; spend on behaviour). Blue body 96×56 (serpentine, reads on snow). Green `skydragon` untouched. Everything else not named stays; `ice_beacon` and `storm_lightning` move with DIR-03's landmarks.

## PRODUCTION FAMILY (pixen ×4–6 + `animate_image`, 1 gen each)

**HERO**
- **Red patrol** (JSON above): shoulder (700,240), sea (800,270), (840,350) *breath east over sea*, coast (795,440), foothills (690,475), snow peaks (590,420) *breath west over snow*, ice (610,280); never over the dark rock. Lap ≈126 s. 16 gens.
- **Blue patrol**, pingpong, speed 42, `bob` 8/2200: north wall (440,268), lake (455,335), peaks (560,395), foothills (640,470) *bolt*, sea (730,560), cape (800,690), sea (870,720) *bolt*; `breathAt [3,6]`. **Storm cloud**: continuous follower `cloud` (as `breath`; 112×48, 6 f, opacity 0.55, offset (−8,−14), under the body) — the storm travels with it. 20 gens.
- **Fairies ×4** at DIR-03's glade (335,452): rings (318,438)(350,436)(356,462)(322,466) and (340,448)(360,440)(352,470); approach (300,448)↔(335,430); hover (333,449)↔(337,452). Speeds 14–20, `bob` 4–6/1100–1500, `flip`, depth 1. 18 gens.

**MID**
- Wagon: Haven's Rest→Stonefall route, pingpong, speed 9. 0.
- Mule train 24×24 (two laden mules + rider; never a lone walking figure, R-4): Stonefall→Frostmere pass, speed 7; second entry Woods→Hollow. 8.
- Caravan re-animated 4 f on DIR-01's new west pass road (waypoints from DIR-01). 1.
- Deer herd: `deer2` + a second entry pingponging 30 px to the beck (240,345). 0.
- Ship, east route: Saltreach (760,645), Wanderers' Isles (835,500), Far Isles (955,275), speed 8. 8.
- Boats: harbour (724,628)↔(745,655); delta mouth (640,690)↔(670,700). 0.
- Wolves halved; bear2, nessie, whale, yeti3 in place; `smoke` reused on Whispering Woods roofs. 0–4.

**SUBTLE**
- Gulls 24×24, 4 f, `bob` loops at the light (735,615) and cape (790,700). 5; one failure → pale-toned `crows`.
- Ptarmigan 16×16, 4 f hop, Frostmere north shore (470,265). 5.

Slots: 40 − 15 + 12 = **37/40**.

## PIXELLAB BUDGET

Estimate 85 (all 1-gen calls); **cap 200**; the pool's remainder goes to landmarks. No `create_map_object`/`inpaint` here.

## PHONE-SCALE SUCCESS CRITERIA

1. Red never absent; on screen ≥40% of any 3-minute dwell in the volcano FOV; two plumes per lap, each a tongued cone leaving the animated jaw at 1:1.
2. Red vs blue told apart at overview zoom (bat-wing vs serpent); blue always carries its cloud and shows charge before every bolt.
3. Red wingspan ≥3× the wolf pair, ≥6× a deer; no MID creature taller than adjacent canopy.
4. ≥3 fairies with wing hints around the glade at ×2; none reads as a square, face or figure.
5. On `worldlife-composite.js` at t = 0, L/3, 2L/3: road creatures on painted road, boats on water, ≤12 overlays in the phone FOV, nothing over a marker or label.
6. Reduce Motion: every creature present and pinned.
7. Guards green; owner ACCEPT on the iPhone at opening zoom, ×2, ×4.
