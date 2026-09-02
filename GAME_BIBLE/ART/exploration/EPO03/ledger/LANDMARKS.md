 REJECT | 15–18 px insect filling the canvas (wasp/bee/moth); the spec is a 6–10 px silhouette. Superseded by the 96x64 swarm roll. rejected/landmarks/fairy_ABC.txt |REJECT | 15–18 px insect filling the canvas (wasp/bee/moth); the spec is a 6–10 px silhouette. Superseded by the 96x64 swarm roll. rejected/landmarks/fairy_ABC.txt |REJECT | 15–18 px insect filling the canvas (wasp/bee/moth); the spec is a 6–10 px silhouette. Superseded by the 96x64 swarm roll. rejected/landmarks/fairy_ABC.txt |# EPO03 — PROD-WORLD-LANDMARKS ledger

Brief: `MILESTONES/evidence/EPO03/wave1/DIR-03_fantasy_landmarks.md`. Cap **300**.
Family total = the sum of the tool's own cost lines below; never a balance delta (M-17).
Regions: `E/src/atlas/regions_landmarks.json` (pending) → `E/out/atlas/manifest_landmarks.json` (accepted). Salts 120–139.

| job id | tool | what was asked | size | cost line | verdict | reason |
|---|---|---|---|---|---|---|
| 283d63dd | inpaint_image | L3 ice bastion r1: three stepped terraces, crystalline tower at (468,177), SW causeway with ice pillars, sastrugi (seed 1201) | 200x192 crop, mask 120x120 @ (40,44) | ~20 | **REJECT** | isometric stepped ziggurat with stairs and straight edges, an object ON the snow (the pedestal failure at 85 px); "three stepped terraces" read as a countable unit → pyramid. Intent changed for r2. rejected/atlas/L3_r1.txt |
| 0a74bbe1 | create_image_pixen | storm rain still A: diagonal 1-px pale streaks + dark wisps at top (seed 1211) | 96x96 | 1 | REJECT | three cartoon cumulus clouds (a cloud shape) |
| 7804285a | create_image_pixen | storm rain still B (seed 1212) | 96x96 | 1 | **ACCEPT** (still) | dark churning wisps at the top, dense 1-px white diagonal streaks 6–10 px; goes to animate_image |
| e7bd86f8 | create_image_pixen | storm strike main fork, white core violet edge, 2–3 branches (seed 1221) | 80x96 | 1 | REJECT | cartoon zigzag bolt glyph, not a fork |
| 6c2e96ac | create_image_pixen | storm strike thinner second fork (seed 1222) | 80x96 | 1 | **ACCEPT** | a real thin fork, white core with violet fringe, two branches; f3 of the strike |
| 9d1d5ef4 | create_image_pixen | fairy silhouette A: 8 px body, cream wings, honey glow, no face (seed 1231) | 24x24 | 1 | pending | |
| ba335260 | create_image_pixen | fairy silhouette B (seed 1232) | 24x24 | 1 | pending | |
| 60377176 | create_image_pixen | fairy silhouette C, moth wings (seed 1233) | 24x24 | 1 | pending | |
| 8bdd1c8e | create_image_pixen | storm strike main fork re-roll: realistic channel, 2-px white core, three branches, "not a zigzag icon" (seed 1223) | 80x96 | 1 | **ACCEPT** | a bright crooked main channel with five thin branches, top to bottom centre; f1 of the strike (out/landmarks/strike_fork_main.png) |
| fe5c6c38 | create_image_pixen | fairy swarm A: eight 6–8 px fairies on one canvas, to cut individual sprites from (seed 1241) | 96x64 | 1 | **ACCEPT** | nine 9×8 px fairies (dark body, cream wings, gold glow tips), all top-facing; the cut source for the fae court; goes to animate_image for the wingbeat |
| 2f9185f7 | create_image_pixen | fairy swarm B (seed 1242) | 96x64 | 1 | **ACCEPT** (reserve) | eight 8–13 px fairies in a ring facing eight directions; kept as directional variants |
| 372c4ad9 | inpaint_image | L3 ice bastion r2: intent changed — rugged natural glacier mound, seracs and crevasses, top-down, slender tower on the summit, winding SW causeway; "no pyramid/ziggurat/steps" (seed 1202) | 200x192 crop, mask 120x120 @ (40,44) | ~20 | **CANDIDATE** (held against r3) | a rugged organic ice mound ~85 px with blue south faces, seracs and a crystal spire; no pedestal, no straight edge beyond the cliff foot; the causeway barely reads and the spire is ~15×22 px. review/atlas/L3_r2_preview_x2.png |
| c7f6305b | animate_image | storm rain: rain_B still → 8 f pouring loop, wisps churning (seed 1251) | 96x96 ×8 | 2 | **PARTIAL — kept for the wisps only** | the model emptied the rain from 6 of 8 frames (measured: f2,f3,f5,f6,f7,f8 have 0 opaque px below row 28) but the cloud wisps do churn. Rows 0–27 of each frame are used; the rain body is the accepted still scrolled 3,6 px/frame with wrap by `tools/rain-assemble.js` (0 gens, A-2: every pixel is an authored pixel). |
| 3532c6da | animate_image | fairy swarm A → 4 f wingbeat, hover in place (seed 1261) | 96x64 ×4 | 1 | **ACCEPT** | wings open/close across the 4 frames and the bodies hold station; the 12×12 cut at (33,8) keeps one fairy centred (bbox drift ≤2 px). The cut source for `overlay_fae_court`. |
| 817cd7de | inpaint_image | L3 r3: same intent, the causeway made a clearly visible 5-px pillared road to a gate and the tower the tallest thing in the scene (seed 1203) | 200x192 crop, mask 120x120 @ (40,44) | ~20 | **ACCEPT — SHIPPED** | the causeway now reads as a pale pillared road climbing from the SW to a dark gate, the spire is the tallest thing in the scene, the mound is organic ice with blue south faces and drifts north; nothing lit under the Frozen Shelf marker; QA: repeated sprite pairs 0. manifest_landmarks.json, review/atlas/L3_after_x2.png |
| bb97072f | edit_image_pixen | beacon sweep LEFT over the shipped L3 crop (seed 1281) | 96x96 | 0 (failed) | INFRA FAIL | `[500] Out of CUDA memory` — no image returned; re-submitted as 397015a4 |
| 397015a4 | edit_image_pixen | beacon sweep far LEFT (seed 1285) | 96x96 | 1 | **ACCEPT** | crown flare + a pale cone reaching down-left over the causeway; 1,024 lit px after keying |
| 1d1d93f4 | edit_image_pixen | beacon sweep DOWN/centre (seed 1282) | 96x96 | 1 | **ACCEPT** | the widest cone, straight down the causeway; 1,518 lit px |
| b42d5403 | edit_image_pixen | beacon sweep RIGHT (seed 1283) | 96x96 | 1 | **ACCEPT** | a narrower cone down-right; 750 lit px |
| 55b29557 | edit_image_pixen | beacon crown only, no beam (seed 1284) | 96x96 | 1 | **ACCEPT** | the dim crown glint the sweep opens and closes on; 138 lit px |
| f28c485f | create_image_pixen | beacon drift sparkle: 1–2 px cold-white glints (seed 1271) | 32x32 | 1 | **ACCEPT** | sparse single-pixel cold-white and pale-blue glints, correctly spaced |
| 09edcc61 | create_image_pixen | beacon drift sparkle B (seed 1272) | 32x32 | 1 | REJECT | four-point violet-blue stars, too saturated and too busy for a snow glitter |
| de827074 | inpaint_image | L2 storm pocket r1: gloom hollow, black gable at (218,900) with three amber windows, blasted leaning trees, wet track (seed 1301) | 176x176 crop, mask 96x96 @ (40,40) | ~20 | **ACCEPT — SHIPPED** | the house reads as a destination at 34 px with lit windows; two blasted trees and a charred split one; puddled track. Heath 60 px east is 33.5 L* brighter and west 24.0 L* brighter than the ground at the house. `south_strand_w` re-extracted in the same commit. QA: repeated sprite pairs 0. |
| 1e07df6f | inpaint_image | L2 r2: the whole rect under a storm shadow, gloom heaviest at the middle (seed 1302) | 176x176 crop, mask 96x96 @ (40,40) | ~20 | **REJECT** | a hard-edged dark RECTANGLE filling the mask exactly — the generated rectangle the round exists to remove. Asking for a field-wide tonal shift asks the model for a panel. r1 stands. rejected/atlas/L2_r2.txt |

## Assembly (0 generations — deterministic, A-2)

| tool | what it does | why not PixelLab |
|---|---|---|
| `tools/rain-assemble.js` | `overlay_storm_rain` 8 f: rows 0–27 are the animate pass wisps, the rain body is the accepted still scrolled 3,6 px/frame with wrap | the animate pass emptied the rain out of six of its eight frames (measured); the still is PixelLab art either way |
| `tools/strike-assemble.js` | `overlay_storm_strike` 8 f: fork + a 30 px dithered ground flash, afterglow, second fork, fade, four empty | DIR-03 specifies this frame plan as script-assembled; the forks are PixelLab pixels translated onto the roof |
| `tools/beacon-key.js` | `overlay_ice_beacon_sweep` 10 f: subtracts the shipped crop from four lit passes, drops 8-connected components under 10 px, sweeps L→C→R→C with a drifting sparkle | DIR-03 specifies diff-key; every kept pixel is one the model added |
| `tools/fairy-arcs.js` | `overlay_fae_court` 16 f: seven fairies on ellipses round the castle, three-frame glow trails, a gathering pulse at f10–15 | DIR-03 specifies `fairy-arcs.js`; the sprite is PixelLab's 4-frame wingbeat, only placed |

## Totals (sum of the tool cost lines above)

| | generations |
|---|---:|
| L3 inpaints (r1 reject, r2 candidate, r3 shipped) | 60 |
| L2 inpaints (r1 shipped, r2 reject) | 40 |
| overlay stills and animations | 17 |
| beacon edits and sparkles (one infra failure, 0) | 6 |
| **spent so far** | **123** of the 300 cap |
| L1 inpaints still to come (up to 3 rolls at ~25) | budgeted 75 |
