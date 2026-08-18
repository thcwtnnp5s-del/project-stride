# TRANSFORMATION_01 — world atlas package (stream C)

```
STATUS: AUTHOR-ACCEPTED, AWAITING QA VERDICT (M-04). Nothing here is in assets/.
Everything is native pixel size. The app displays at ×2 nearest-neighbour;
multiply every coordinate below by 2 for display space.
```

Source folder for `Scripts/art/package-art.js` emit lines (integration lead adds
them): `GAME_BIBLE/ART/exploration/TRANSFORMATION_01/out/world/` and `out/env/`.

## 1. Files

| Source file (out/…) | Proposed shipped path | Native | Display | Notes |
|---|---|---|---|---|
| `world/atlas_base_384x688.png` | `world/atlas_base.png` | 384×688 | ×2 → 768×1376 | opaque, 0 border px, 0 non-opaque px, 0 teal px |
| `world/landmark_havens_rest_96x96.png` | `world/landmark_havens_rest.png` | 96×96 | ×2 | anchor = bottom-centre of palisade (see §2) |
| `world/landmark_whispering_woods_96x80.png` | `world/landmark_whispering_woods.png` | 96×80 | ×2 | |
| `world/landmark_forgotten_hollow_96x80.png` | `world/landmark_forgotten_hollow.png` | 96×80 | ×2 | |
| `world/landmark_stonefall_mine_96x80.png` | `world/landmark_stonefall_mine.png` | 96×80 | ×2 | |
| `world/landmark_frostmere_96x72.png` | `world/landmark_frostmere.png` | 96×72 | ×2 | optional — the base already draws the tarn; B may prefer to leave it off and use the base tarn as the tap target |
| `env/prop_lone_oak_48x48.png` | `env/prop_lone_oak.png` | 48×48 | ×2 | scatter prop |
| `env/prop_boulders_48x40.png` | `env/prop_boulders.png` | 48×40 | ×2 | scatter prop |
| `env/prop_pine_clump_48x56.png` | `env/prop_pine_clump.png` | 48×56 | ×2 | scatter prop |
| `env/prop_hedgerow_48x32.png` | `env/prop_hedgerow.png` | 48×32 | ×2 | scatter prop; runs to both side edges by design (tileable end-to-end) |
| `env/prop_cairn_32x40.png` | `env/prop_cairn.png` | 32×40 | ×2 | scatter prop |
| `env/prop_dead_tree_40x48.png` | `env/prop_dead_tree.png` | 40×48 | ×2 | scatter prop |
| `env/prop_snowdrift_48x32.png` | `env/prop_snowdrift.png` | 48×32 | ×2 | scatter prop |
| `env/overlay_cloud_wisp_96x48_f0.png` | `env/overlay_cloud_wisp.png` | 96×48 | ×2 | **static**, 1 frame; drift is code. Composite at ~0.45 opacity |
| `env/overlay_cloud_shadow_96x48_f0.png` | `env/overlay_cloud_shadow.png` | 96×48 | ×2 | **static**, 1 frame; drift is code. Composite at ~0.22 opacity — the asset is a solid dark shape and MUST NOT be drawn opaque |
| `env/overlay_forest_mist_96x48_f0..f5.png` | `env/overlay_forest_mist_f{i}.png` | 96×48 | ×2 | 6-frame loop, **4 fps**; composite at ~0.5 opacity |
| `env/overlay_snow_flurry_64x64_f0..f7.png` | `env/overlay_snow_flurry_f{i}.png` | 64×64 | ×2 | 8-frame loop, **6 fps**; opaque is fine (sparse specks) |
| `env/overlay_forge_smoke_32x48_f0..f5.png` | `env/overlay_forge_smoke_f{i}.png` | 32×48 | ×2 | 6-frame loop, **5 fps**; composite at ~0.7 opacity; anchor bottom-centre on the lodge chimney |

Every sprite: alpha is 0 or 255 only (measured), no `#58d6c0`. Overlays carry
no alpha of their own — translucency is a compositor multiplier, exactly as the
contact shadow is a compositor step (`PIXELLAB_STYLE_SPEC_01.md` §10b Rule A).

**Not delivered:** water shimmer for the tarn (three attempts, none produced a
keyed glint sprite — see `world/README.md`). Grass/wind ripple: optional, skipped.

## 2. Proposed `atlas_layout` (native px on `atlas_base_384x688.png`)

Anchor convention: (x, y) is the point on the map the object represents;
`ax, ay` is the pixel inside the sprite that should land there (bottom-centre
of the object's footprint, so it "stands" on the terrain). Display = ×2.

### Locations

| Location | x | y | landmark sprite | ax | ay | terrain colour under it | lum | plate |
|---|---:|---:|---|---:|---:|---|---:|---|
| Haven's Rest | 120 | 571 | landmark_havens_rest_96x96 | 48 | 52 | `#756d4e` meadow olive-khaki | 109 | dark plate / light text |
| Whispering Woods | 100 | 296 | landmark_whispering_woods_96x80 | 48 | 44 | `#3c3f2e` deep canopy | 61 | light plate / dark text |
| Forgotten Hollow | 80 | 135 | landmark_forgotten_hollow_96x80 | 48 | 48 | `#4a4b42` wet grey-green | 74 | light plate / dark text |
| Stonefall Mine | 307 | 362 | landmark_stonefall_mine_96x80 | 48 | 40 | `#38302d` adit shadow; `#736a59` heath just below (lum 107) | 49 | light plate / dark text |
| Frostmere | 295 | 85 | landmark_frostmere_96x72 (optional) | 48 | 36 | `#b3c1cc` ice / snowfield | 191 | dark plate / light text |

Where the base already draws each place: hamlet ring centre (120,571); forest
track mouth (100,300) — the dark canopy gap where the track vanishes; ruin arch
(80,135); adit mouth (307,359), ore cart (300,414); tarn centre (295,85).

### Road nodes (polyline hints for the route layer)

| Node | x | y | what it is |
|---|---:|---:|---|
| HR_gate | 150 | 539 | hamlet's north-east opening onto the bridge road |
| HR_bridge | 175 | 529 | timber bridge over the Meadowrun |
| HR_north | 107 | 494 | where the north track leaves the hamlet |
| N1 | 100 | 354 | north track, forest fringe |
| WW_mouth | 100 | 300 | track enters the oak canopy |
| J1 | 235 | 412 | junction: forest track meets the ore road |
| ORE1 | 250 | 419 | ore road, mid |
| MINE_yard | 300 | 375 | rails' end below the adit |
| PASS_foot | 300 | 340 | pass leaves the mine yard northward |
| PASS_mid | 305 | 215 | Rimeward Pass in the notch |
| TARN_shore | 300 | 120 | pass reaches the tarn basin |
| HOLLOW_path0 | 100 | 215 | faint path leaves the forest's north edge |
| HOLLOW_arch | 80 | 140 | path ends at the ruin arch |
| SOUTH_exit | 15 | 674 | road leaves the frame south-west (future country; not a destination) |

Routes (per `03_REGIONAL_ECOLOGY_PHASE_2.md` §3): HR→WW = HR_north→N1→WW_mouth;
HR→SM = HR_gate→HR_bridge→J1→ORE1→MINE_yard; WW→SM = WW_mouth→N1→J1→MINE_yard
(the forest track drops to J1); WW→FH = HOLLOW_path0→HOLLOW_arch (faint, no
road); SM→FM = PASS_foot→PASS_mid→TARN_shore. There is no HR→FM edge drawn.

### Suggested prop scatter (optional richness; all native px, anchor bottom-centre)

| prop | x | y |
|---|---:|---:|
| prop_lone_oak | 60 | 470 |
| prop_hedgerow | 210 | 470 |
| prop_boulders | 300 | 470 |
| prop_pine_clump | 260 | 300 |
| prop_cairn | 312 | 250 |
| prop_dead_tree | 40 | 80 |
| prop_snowdrift | 340 | 140 |

Overlay suggestions: cloud wisp/shadow drift anywhere over the south half;
forest mist over (60–140, 40–120) and the Hollow; snow flurry over (230–384,
0–200); forge smoke anchored at (118, 548) — the lodge chimney inside the
hamlet ring (the base draws its own thin smoke thread there).

## 3. What the base is

`create_image_pro`, 384×688 (the API's maximum for the 9:16 portrait ratio —
432×768 was refused with "max 384x688"; 384×640 was also proven), seed 31,
`style_image_url` = Traveler south rotation, `style_copy=["color_palette"]`, no
palette words in the prompt. Two 384×640 candidates were also drawn and kept in
`world/candidates/base/`. The previous `region_map_phase2_384x640.png` remains
the fallback if QA rejects this base.
