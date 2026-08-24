# PLAYABLE_POLISH_02 — craft scenes and the guard idle re-author

The physical-device polish pass's art round (2026-08-24): the craft stage's
"tiny forge in a box" becomes a real scene per workstation, and the
Traveler's combat idle stops reading as facing away from the enemy.

## Shipped

| Ship path | Source | Size | What |
|---|---|---|---|
| `work/bg_smithing.png` | `out/stage/bg_smithing_384` | 384 × 176 | smithy interior: stone forge with glowing coals, tool wall, plain flagstone working band |
| `work/bg_woodworking.png` | `out/stage/bg_woodworking_384` | 384 × 176 | carpenter's workshop: bench and shelving at the back wall, stacked oak, tool rack, plain floor band |
| `work/bg_cooking.png` | `out/stage/bg_cooking_384` | 384 × 176 | hearth corner: hanging pot over a low fire, onions and herbs on the mantel, plain flagstone band |
| `work/station_forge.png` | `out/stage/station_forge_96` | 96² | anvil on a stump with tools at the base |
| `work/station_woodbench.png` | `out/stage/station_woodbench_96` | 96² | low bench with a clamped plank, saw and shavings |
| `work/station_cookfire.png` | `out/stage/station_cookfire_96` | 96² | iron pot on a tripod over a campfire |
| `combat/traveler_combat_idle_f0..f8.png` | `out/combat/raw/0..8` crop (8,12) | 80 × 64 | the guard idle, east in profile, sword visible |

The three stations supersede the 64² `node/station_*.png` pair on the craft
stage (still packaged, unreferenced — the exploration record). All three are
tall enough to swallow a swung tool if drawn last, so they carry
`behindFigure: true` in `ambient_assets.dart` — the seam/oak-trunk blind-QA
rule.

## The combat idle, and why it was re-authored

PLAYABLE_EXPANSION_01's own round log records the deviation: *"the
Traveler's combat idle and attack are v3 outputs that drift toward
three-quarter view."* On the owner's phone that drift read as the player
**facing left / away from the enemy standing east** — a correctness
finding in the physical-device polish brief.

Fix, through PixelLab (A-1):

- `animate_character` v3, east, **custom start = the raw attack's f3** (the
  frame where the sword is extended east in strict profile), via
  `custom_start_frame_url` — inline base64 was corrupted in transit twice;
  the url path is the reliable one at this size.
- First attempt (group `fddcca89`, custom start = attack f0 crop) came back
  in clean profile but **swordless**, with a stub sprouting in late frames —
  the round-1 "sword stub" failure mode again. Rejected, kept in
  `work/idle_raw/`.
- Second attempt (group `1328f68e`, `cmb_guard_idle_east_v3`) holds the
  sword visibly in all nine frames, stays in profile, subtle sway.
  **Accepted.** Raw 96 × 88 frames in `out/combat/raw/`; packaging crops to
  80 × 64 with the feet on row 62 (`manifest.json` `crop`), 80-wide because
  the blade reaches past the 64-box exactly as the attack does.

## Generations — 6 total

| # | Job | Tool | Outcome |
|---|---|---|---|
| 1 | `1cf93ff6` smithy backdrop | pro 384×176, style = station_forge | **ACCEPTED** |
| 2 | `586a4fb5` workshop backdrop | pro 384×176, style = oak prop | **ACCEPTED** |
| 3 | `54b90c2c` hearth backdrop | pro 384×176, style = station_cookfire | **ACCEPTED** |
| 4 | `3980a55f` anvil 96² | pixen | **ACCEPTED** |
| 5 | `5ce67399` woodbench 96² | pixen | **ACCEPTED** |
| 6 | `7f84160c` cookpot tripod 96² | pixen | **ACCEPTED** |
| — | guard idle v2 (group `fddcca89`) | animate v3, 1 gen | **REJECTED** (swordless / stub) |
| — | guard idle v3 (group `1328f68e`) | animate v3, 1 gen | **ACCEPTED** |

Pro backdrops bill 40 each; total ≈ 128 generations. Balance before the
round: 1,921 (get_balance, 2026-08-24).

## Review

In-context composites via the stage evidence harness
(`STAGE_EVIDENCE_DIR` / `COMBAT_EVIDENCE_DIR`), reviewed at ×2 against the
brief's questions: does the craft stage read as a real activity scene, and
does the combat idle face the enemy. Device acceptance is the owner's.
