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
