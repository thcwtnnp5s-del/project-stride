# EPO03 — EQUIPMENT family generation ledger

Team PROD-EQUIPMENT (`equipment`). Date 2026-09-02. **Cap 500.** Canonical
Traveler `c82b7da5-cda0-44eb-ae4e-30d73689e115`, group `eb569ca7-…`.
Family total = the sum of the cost lines below, never a balance delta (M-17);
`get_balance` is the producer's checkpoint, not this family's measure.

## Rows

| # | what was asked | tool | job id | cost line | verdict | reason |
|---|---|---|---|---:|---|---|
| 1 | **P1a** `base\|steel` brace 6f — text re-dress of the accepted `traveler_base_bronze_brace` f0–f5 (80×64): bronze blade → plain pale steel training blade | `edit_image` (text) | `e3589384` | ~20 | **ACCEPT** | first roll. Steel blade in f0–f2, body/pose/pack unchanged in all six, 0 detached px, 0 partial alpha, foot rows 61–63 (the shipped `plate_bronze_brace` is 61–62, so inside family tolerance). Inherits the source pose's weakness: the blade is hidden behind the forearms in f3–f5. Sheets `review/equip/p1_base_steel_brace_x3.png`, `brace_family_x3.png` |
| 2 | **P1b** Plate Bronze Pick mine 8f — text recolour of the saturated-orange head (wave-A probe `0f7a53bf`) to the muted copper the other four bronze tool strips use | `edit_image` (text) | `9930a833` | ~20 | **ACCEPT** | first roll. Head now inside the copper ramp — `toneBronze` snaps **0** px where the old strip needed the remap; breastplate, pauldrons, hair, haft and pose identical in all 8; foot row 62 in every frame; 0 detached, 0 partial, 0 gold; the f4 swing-streak the packager keyed is gone. Sheets `p1_plate_pick_muted_x3.png`, `p1_plate_pick_toned_vs_family_x4.png` |
| 3 | Longsword silhouette probe on `plate_bronze_idle_f0` | `edit_image_pixen` | `30435184` | 1 | REJECT | longer than the source and guarded, but the tip stops short of the front boot — superseded by row 4 |
| 4 | **P2** longsword start frame, plate | `edit_image_pixen` | `3db1538e` (seed 701) | 1 | **ACCEPT** | blade box right edge 59 → **70** (+11 px), straight cross-guard, two-hand grip; left/top/foot rows identical to the source, so identity and anchor carry over untouched |
| 5 | **P2** longsword start frame, jerkin | `edit_image_pixen` | `6c572c10` (seed 702) | 1 | **ACCEPT** | 57 → **70** (+13 px); the cleanest of the four — long straight blade well past the boot |
| 6 | **P2** longsword start frame, coat | `edit_image_pixen` | `8e686e59` (seed 703) | 1 | **ACCEPT** | 57 → **71**; coat, hood and pose unchanged |
| 7 | **P2** longsword start frame, base | `edit_image_pixen` | `cb9b067e` (seed 704) | 1 | **ACCEPT** | 60 → **79**; the longest of the four, tip at the canvas edge — recorded, watched through the animation tracks |

Sheet for rows 4–7: `review/equip/longsword_f0_pair_x4.png`,
`longsword_f0_all_x4.png`.

## Standing facts measured this round

- **A longsword costs 1 generation, not 44.** `edit_image_pixen` (1 gen) on an
  *accepted shipped frame* produces the new silhouette, and `animate_character`
  v3 takes that loose PNG as `custom_start_frame_url` — so a whole five-track
  weapon class on one body is ≈6 generations, where FMPO02's
  `create_character_state` + animate route costs ≈49. The identity comes from
  the character id; the pose and the gear come from the frame.
- `edit_image` at 80×64 bills ~20 per call whatever the frame count (≤9
  frames at that width), so a whole strip goes in one call — never per frame.
- The `toneBronze` remap in `package-art.js` is worth mirroring locally
  (`tools/tone-bronze.js`) so a candidate is reviewed as it will ship.

## Rows, continued — P2 the longsword class

| # | what was asked | tool | job id | cost line | verdict | reason |
|---|---|---|---|---:|---|---|
| 8–12 | plate longsword idle 8 / attack 8 / hit 6 / stagger 8 / brace 6, v3 east from the plate start frame | `animate_character` v3 | `4ee8574a` `2e82a666` `d738b612` `01a9dd07` `30e4ed54` | 5 | 4 ACCEPT, stagger RE-ROLL | stagger walked backwards instead of going down |
| 13–17 | jerkin, same five | `animate_character` v3 | `1dc65748` `ef4433bf` `033e233e` `8338fefd` `91d58aa2` | 5 | 3 ACCEPT, hit + stagger RE-ROLL | the flinch lunged forward almost horizontal; the stagger walked backwards |
| 18–22 | coat, same five | `animate_character` v3 | `fc5de18e` `86e6f504` `0bae29fa` `127f01dd` `7a492326` | 5 | 4 ACCEPT, brace RE-ROLL | the brace raised the blade overhead: union box 70 rows, 19 px clipped at f4 — it does not fit the 64-row canvas |
| 23–27 | base, same five | `animate_character` v3 | `1b98b86f` `a14eb7e0` `922f3031` `cf4cce45` `35f71d78` | 5 | 2 ACCEPT, attack + hit + stagger RE-ROLL | the attack shouldered the blade and walked; the flinch lost the blade entirely at f3 (the documented v3 dissolve) and drifted to three-quarter view; the stagger walked backwards |
| 28 | plate stagger, re-rolled describing the END POSE ("down on one knee, head low") | `animate_character` v3 | `e34adfa3` | 1 | **ACCEPT** | knees buckle, down on a knee by f5–f7, blade clear of the ground |
| 29 | jerkin hit, re-rolled ("feet planted, torso rocks back, standing upright") | `animate_character` v3 | `8ce16168` | 1 | **ACCEPT** | upright recoil, blade visible in all 6 |
| 30 | jerkin stagger, re-rolled as above | `animate_character` v3 | `59eb31ac` | 1 | **ACCEPT** | sinks to a kneel by f4 |
| 31 | base attack, re-rolled ("feet planted… never walking") | `animate_character` v3 | `6aef2221` | 1 | **ACCEPT** | two-handed windup and cut, blade in all 8 |
| 32 | base stagger, re-rolled | `animate_character` v3 | `264de4fc` | 1 | **ACCEPT** | down on a knee by f5 |
| 33 | base hit, re-rolled | `animate_character` v3 | `7d97383a` | 1 | **ACCEPT** | upright, blade in all 6 |
| 34 | coat brace, re-rolled ("level across his chest… never raised above his head") | `animate_character` v3 | `378d11d2` | 1 | **ACCEPT** | horizontal guard, cross-guard readable, fits the 64-row window with 0 clipped |

**P2 subtotal 25 v3 rolls + 5 pixen start frames = 30 generations for 20 shipped
tracks.** The FMPO02 route (`create_character_state` + animate) would have been
≈245 for the same five-track sets on five bodies.

Census over all 20 accepted strips: 0 gold-leaning pixels, 0 detached
components, 0 partial-alpha pixels; every strip windowed by `equip-prep` to a
single window per strip with the modal foot row on 62. Sheets `review/equip/ls_*`;
device proof `review/device/equip/gear_longsword_{idle,swing}.png` beside
`gear_bronze_*`.

## Rows, continued — P3 the warden body

| # | what was asked | tool | job id | cost line | verdict | reason |
|---|---|---|---|---:|---|---|
| 35 | Waywarden body state on the canonical Traveler, 80×64: tiered shoulder mantle wider than the shoulders, pointed hood up, knee-length split skirt showing both legs, tall boots, cloak tail, empty hands | `create_character_state` | `76bf1ace` | ~44 | pending | |
