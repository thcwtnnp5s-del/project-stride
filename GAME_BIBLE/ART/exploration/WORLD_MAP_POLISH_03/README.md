# World Map Polish 03 — art round

**Date:** 2026-08-25 · **Balance:** 1,815 → **1,416** (399 generations,
verified by `get_balance` before and after; resets 2026-09-16).
Milestone record: `MILESTONES/WORLD_MAP_POLISH_03.md`.

Everything in `out/` is a tracked packaging source; everything in `rejected/`
is evidence. `Scripts/art/package-art.js --check` must pass from a clean
checkout.

## A. The expanded world base (`out/world/`)

Eight PixelLab **Pro** pieces form a frontier ring around the untouched
512 × 512 master painting, composing a 768 × 768 base (world 4608 × 4608 at
scale 6). Every piece was style-referenced against a 64 × 64 crop of the
master's own adjacent edge (the fire round's method, scaled up); the joins
get a deterministic dither crossfade at packaging.

| File | Job | Note |
|---|---|---|
| `strip_west_128x512.png` | `4bb586d2` | v2. The Worldspine chain + forest. v1 (`c048bbc1`) came back as a brown scree field with no ridge and no canopy edge — rejected (`rejected/strip_west_v1_scree_REJECTED.png`). A first attempt (`2c0cbf7b`) failed PixelLab's policy filter on wording, regenerated with a reworded prompt |
| `strip_north_512x128.png` | `5d9c372e` | v2. Conifers → glacier top → volcanic rock along the master edge; pack ice above. v1 (`fb971590`) had oversized floes and pale sea where the master's conifers sit — rejected (`rejected/strip_north_v1_bigfloes_REJECTED.png`) |
| `strip_east_128x512.png` | `de525b77` | Open sea deepening east, three islets. First roll accepted |
| `strip_south_512x128.png` | `11d60066` | Forest → plains → estuary bay and Sunward coast. First roll accepted |
| `corner_nw_128.png` | `2474c242` #3 | Snow conifers + ice shelf (4 candidates; #3 matches both snowy neighbours) |
| `corner_ne_128.png` | `1d85f18f` #0 | Cold navy sea, cinder skerries, steam |
| `corner_sw_128.png` | `a4477df1` #1 | v2: the Worldspine tapering into forest. v1 (`cf8c3842`) was pure canopy and cut the west strip's mountain chain dead at the tile line |
| `corner_se_128.png` | `8835db69` #1 | Open sea, one sandbar islet |

## B. Reworked in-place scenes (`out/env/inplace_*`)

Method: a 64 × 64 crop of the master (`_src_64`), rewritten by `edit_image`,
animated by `animate_image` (frames `_raw_64_f*`), then composited back onto
the source crop through a fixed content box at packaging (the animations
wobble terrain outside the subject; the box kills that). Boxes are recorded
in `package-art.js`.

| Scene | Edit job | Anim job | Verdict |
|---|---|---|---|
| `fire2` (burn scar, west fork) | `09dc85ed` | `4f83ce44` (10f) | Irregular charred patch, standing trunks, embers, two flames, smoke — replaces the circular black hollow. Continuous loop |
| `yeti2` (ice-fisher, the tarn) | `9109d7cd` | `38699aea` (8f) | Seated at a real ice hole, rod held in every frame (the part-2 rod-drop failure did not recur with the grounded scene as input). Continuous loop. Emitted box trimmed 2 rows at the top so it clears Frostmere's hit circle |
| `bear2` (peek, southern forest) | `b3084000` | `904f70b5` (12f + pinned empty ending) | Head ~12 px — a hidden creature, not a mascot. Cycle = source frame + the duck-away frames reversed (entrance) + forward (look, blink, duck); intermittent |

## C. Creatures (`out/env/creature_*`)

| Creature | Source | Jobs | Verdict |
|---|---|---|---|
| `nessie` (48 × 36 pixen, seed 12) | `f237b4d6` | sub still `2eaa5286`; rise `6a92af41` (6f, pinned sub→risen); swim-dive `01cc4ee5` (10f, pinned risen→sub) | The loch serpent: head + arched neck + humps, white waterline ripples. The 17-frame joined cycle opens and closes on the same near-empty splash. Two map-object attempts rejected (blob `18b6bee8`, giant head `edb607ef`); a both-ends-pinned single animation (`222deb58`) never rose and is superseded |
| `skydragon` (72 × 32 pixen, seed 31) | `aca4aeeb` | anim `6b284d7b` (10f) | Long winding jade dragon, small wings, undulating flight. Map-object attempts rejected (wingless eel `75d6e5de`, smear `e404856e`); the 96 × 44 pixen (`008eb8c3`) was right but too large for a "rare sighting" and was re-rolled smaller |
| `whale` (map object) | `2d398f8c` | anim `c779f5be` (8f) | Dark back, dorsal roll, spout, wake rings |
| `ship` (map object) | `5065cde7` | still only | A 15 × 20 sloop; motion is the v5 `travel` field, not frames |

## D. Rejected outright

- **Aurora shimmer** over the glacier (`13e37958`): the animation reshaped
  the ice sheet instead of adding light — the same failure family as the
  five-times-failed water shimmer. Not re-attempted (evidence:
  `rejected/aurora_inplace_attempt_f5_REJECTED.png`).

## E. Transport note

Long inline base64 arguments to the MCP server corrupted repeatedly in
transit this session (single-character errors, confirmed by byte counts).
All image-carrying calls were therefore driven by a small JSON-RPC helper
that reads the PNG bytes straight from disk (same endpoint, same bearer
token, recorded in the milestone). Poll-only calls stayed on the normal MCP
tools.
