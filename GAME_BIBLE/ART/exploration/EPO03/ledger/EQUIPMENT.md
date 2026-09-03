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
| 36–38 | warden east frames holding the steel sword / bronze sword / longsword, from the state's own east rotation | `edit_image_pixen` | `8f88965a` `ea54c02d` `85dce6fb` | 3 | **ACCEPT** | box grows right by 13 / 13 / 27 px; hood, mantle, split skirt, face and foot row identical across all three |
| — | the first two of those | `edit_image_pixen` | `8111d68f` `7bbbf650` | 0 | **FAILED** | PixelLab returned `[500] Out of CUDA memory` twice; re-fired as rows 36–37 |
| 39–42 | warden tool frames: bronze pick / bronze axe / steel pick / steel axe, from the west rotation | `edit_image_pixen` | `464f4c91` `89f6fa64` `46cf9932` `5041db01` | 4 | **ACCEPT** | four distinct heads on one unchanged body |
| 43 | warden bust — the shipped coat portrait re-hooded | `edit_image_pixen` | `67abff8b` | 1 | **ACCEPT** | same face, eyes, beard and framing; hood and mantle only |
| 44–63 | warden combat, 4 held classes × 5 tracks, v3 east | `animate_character` | 20 groups | 20 | 17 ACCEPT, 3 RE-ROLL | the unarmed punch drew a **black-and-white checkerboard** where the fist should be; the steel and longsword overhead cuts left the 64-row window by 19 and 38 px, and the longsword's union box measured 84 px on an 80-wide canvas |
| 64–67 | warden bare: idle-breathe 8 / look-around 7 (south), walk-west 6 / forage 9 (west) | `animate_character` | 4 groups | 4 | **ACCEPT** | hood up throughout; the forage kneels **west**, the side the stage stands the plant on, so unlike FMPO02's it is not mirrored |
| 68–71 | warden gather: bronze/steel pick mine, bronze/steel axe woodcut, v3 west | `animate_character` | 4 groups | 4 | **ACCEPT** | tool present in all 8 of each; the bronze pick loop's 29 px of impact sparks are keyed by `equip-prep`'s largest-component rule |
| 72–74 | the three re-rolls: the punch as "a bare hand plainly a hand in every frame", the two cuts as "a flat horizontal sweep at waist height, the blade never rising above his shoulder" | `animate_character` | `4a3d3298` `c0d7ed8e` `583b8175` | 3 | **ACCEPT** | all three fit the window with 0 px clipped |
| 75 | warden smith 7f, reference-mode re-dress against the warden figure | `edit_image` (reference) | `d2f7615a` | ~20 | **REJECT** | the reference rotated him: f1 and f6 show his back, f2 turns him to the viewer with both arms up. Reference mode carries the reference's *pose* as well as its clothes |
| 76 | warden cook 7f, same route | `edit_image` (reference) | `75d68cb1` | ~20 | **ACCEPT** | pose, spoon, pack and foot row kept exactly; only the clothing changed |
| 77 | warden smith, **text** mode with "the same pose seen from the side facing right, never turned toward the viewer" | `edit_image` (text) | `e890172e` | ~20 | REJECT | pose fixed, but it invented a small anvil in f3–f4 (box 42 → 61 px) that the stage already draws as its own prop |
| 78 | warden smith, text mode again with "add nothing to the picture: no anvil, no ground, no workbench" | `edit_image` (text) | `22e82915` | ~20 | **ACCEPT** | every frame's box within ±2 px of the source, foot row 62 throughout, hammer and spark kept, nothing added |
| 79–83 | **P4** special axe head — a serrated hooked bronze bit with a bone horn spike — swapped into the five bodies' bronze woodcut loops | `edit_image` (text) | `64992fa9` `5a5d48e1` `8e2e05ab` `8bc650b4` `f5ff455f` | ~100 | **REJECT (class)** | the head is genuinely different — wider, hooked, serrated, bone-spiked — but it **morphs between frames**: on the warden strip it is pale in f1, small and dark in f2 and a forked orange hook in f3/f5; the plate strip leaves a stray chip in f5. A head that changes shape mid-swing is a worse defect than the hue-only one it was meant to fix, and 65 generations could not re-roll five strips. `goblin_toothed_axe` and `hornbound_bronze_axe` stay `tool.axe.bronze`. Sheets `p4_plate_axe_x3.png`, `p4_axes_x3.png` |
| 84–88 | **P4** special pick head — a long curved bone horn tip on the bronze socket — swapped into the five bodies' bronze mining loops | `edit_image` (text) | `4f75f715` `0f390aa3` `ae9e2601` `a9f200fb` `76aa8310` | ~100 | **ACCEPT (all five)** | one bone-white curved tip, the same shape in all 40 frames, on five unchanged bodies; every frame's foot row equal to its bronze source's; 0 gold, 0 partial alpha. Sheets `p4_picks_x2.png`, `p4_heads_x4.png` |

## Family total

| block | cost lines |
|---|---:|
| P1 — base+steel brace, plate pick recolour | 40 |
| P2 — the longsword class, 4 bodies × 5 tracks | 30 |
| P3 — the warden body, 30 strips + figure + bust | ~165 |
| P4 — the special heads (pick accepted, axe rejected) | ~200 |
| **Total** | **~435 of a 500 cap** |

## Standing facts, continued

- **`edit_image` reference mode carries the reference's pose, not only its
  clothes.** It was right for the cook (a compact figure) and wrong for the
  smith (a two-armed swing), where it turned the man to the viewer and to his
  back. Text mode with an explicit "the same pose seen from the side facing
  right" holds the pose; add "add nothing to the picture" or it will invent
  the station furniture.
- **v3 leaves the 64-row window on any overhead cut** once the figure is drawn
  a little larger, and it reports that only as a taller source canvas. The
  lever that fixes it is describing a **flat horizontal sweep at waist height,
  the blade never rising above the shoulder** — the same wording that fixed
  the coat's longsword brace.
- `edit_image_pixen` fails with `[500] Out of CUDA memory` under load; it is a
  server fault, costs nothing, and the same call succeeds when re-fired.
