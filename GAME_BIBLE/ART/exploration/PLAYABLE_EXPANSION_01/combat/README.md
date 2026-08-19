# PLAYABLE_EXPANSION_01 — combat art (Combat Slice 01 vertical slice)

```
STATUS: round record · production sprites for the combat stage · NOT CANON
Author: PixelLab combat art director. QA VERDICT lines are written by Visual QA only (M-04).
```

Date 2026-08-19. Governed by `GAME_BIBLE/COMBAT/02_COMBAT_SLICE_01.md` §2/§6/§10,
`TRANSFORMATION_01/ART_DIRECTION_BRIEF.md` (shared visual language),
`PIXELLAB_PROOF_02/PIXELLAB_STYLE_SPEC_01.md`, `NEUTRAL_STAGING_CHECKLIST.md`,
`RULES.md` A-1/A-2, `MISTAKES.md` M-04/M-05/M-08. Budget: ≤120 PixelLab generations.

## 1. Shared visual language for combat

The stage (`02_COMBAT_SLICE_01.md` §10) is a **side view**: Traveler on the LEFT facing
**east**, enemy on the RIGHT facing **west**, both standing on the lower third of a terrain
backdrop, drawn at ×2. Everything below serves that one picture.

| Property | Rule |
|---|---|
| Camera | Enemies are generated with the `side` camera so their west rotation reads as a profile facing across the stage. The Traveler stays on his existing `low top-down` character (east rotation) — the two cameras are close enough at ×2 that the pairing is judged in the context sheet, not assumed. |
| Facing | Traveler: **east** only. Enemies: **west** only. Nothing is mirrored in code — mirroring would move the key light. |
| Key light | Upper-left, everywhere (same as every other family). |
| Outline | Single dark closed outline; dark brown rather than pure black on creatures. |
| Shading | Flat matte, few clear steps. No gradients, no glow, no bloom, no specular, no emissive eyes. |
| Palette | Warm earthy limited: olive, sage, ochre, rust, cream, warm brown, neutral grey. Teal `#58d6c0` must not appear. Enemy palettes lean on their region: wolf grey-brown (Woods), goblin grey-green skin + iron/tan (Mine), guardian moss/bark/stone (Hollow). |
| Contact shadow | None baked in; the compositor grounds figures. Backdrops carry their own ground plane. |
| Semi-transparent pixels | Zero (alpha quantised at 128 in packaging; PixelLab has never produced any so far). |
| Tone | Enemies are dangerous animals and wardens, **not cute mascots and not gore**. No blood, no severed parts, no dripping. Threat is carried by posture and teeth, not by red pixels. |
| System honesty | Nothing in any frame or backdrop implies a system the game lacks: no chests, coins, doors, HUD, health bars, numbers, text, speech bubbles, status icons, sparkles/hearts over heads. Bars, turn counter and telegraph text belong to the UI. |
| Readability | Every sequence must read at ×2 on a phone (the verdict scale, M-05). A hit reaction is a whole-body flinch/recoil, not a face change. Effects are small and bold: 32×32 or 48×48, 4–6 frames. |

### Sizes (native, before ×2)

| Figure | Canvas | Height on screen | Why |
|---|---|---|---|
| Traveler | 64×64, feet on row 62 (same anchor as `sprite/traveler_south.png` and the ambient set) | ~50 px figure | reuse the shipped anchor so combat idle and rest pose share a baseline |
| Forest wolf | ~40 px character → 56 canvas | ≈ waist height (28–32 px tall at the shoulder) | a wolf is a real animal; waist height on a walker is honest, and it keeps the first fight from looking like a boss |
| Cave goblin | ~44 px character → 60–64 canvas | ≈ 3/4 Traveler (40–48 px) | small, hunched, but armed — the fight the sword is for |
| Hollow guardian | 72–80 px character → 96–112 canvas | ≈ 1.25× Traveler (72–80 px) | the boss; taller than the Traveler but not filling the stage |
| Effects | 32×32 (impact, bite) / 48×48 (slash) | overlay | drawn over the struck figure by the UI |
| Backdrops | 192×96 opaque | 384×192 dp at ×2 | figures stand in the lower third; the lowest ~30 px is plain ground with no busy detail so figures read against it |

### Sequences to deliver

| Kind | id | What it shows |
|---|---|---|
| traveler | `traveler_combat_idle` | on guard, weight low, small breathing sway; east |
| traveler | `traveler_attack` | forward horizontal sword slash and return to guard; east |
| traveler | `traveler_hit` | flinch/recoil from a blow; east |
| enemy | `wolf_idle`, `wolf_attack` (lunge bite), `wolf_hit` (flinch) | west |
| enemy | `goblin_idle`, `goblin_attack` (club/dagger jab), `goblin_hit` | west |
| enemy | `guardian_idle`, `guardian_attack` (slow heavy overhead slam — the telegraphed heavy strike), `guardian_swipe` (normal strike, if cheap), `guardian_hit` | west |
| effect | `fx_slash`, `fx_impact`, `fx_bite` | 4–6 frames, transparent |
| backdrop | `backdrop_forest`, `backdrop_mine`, `backdrop_hollow` | one static strip each |

Defeat/collapse sequences are attempted only if the budget allows after the core set.

## 2. Method

- Wolf first (`create_character` standard, quadruped `dog`, `side`, 4 dir, size 40), judged
  at ×2 beside the Traveler on a context sheet **before** the goblin and guardian are ordered
  (representative sample first, then fan out).
- Animations: `animate_character`. Templates where a good one exists (Traveler
  `fight-stance-idle-8-frames`, `taking-punch`; quadruped templates as listed by
  `get_character`), otherwise `v3` with `keep_first_frame=true` so frame 0 is the rotation
  pose (a shared anchor). Enemies animate **west**, the Traveler **east**.
- Effects: `create_image_pixen` transparent + `animate_image`.
- Backdrops: `create_image_pixen` 192×96 opaque, palette-conformed to the location vignette by
  nearest-colour remap only if the pixen palette drifts (A-2).
- Packaging: `tools/package.js` → `../out/combat/` + `manifest.json`; then
  `Scripts/art/package-art.js` (combat section) → `assets/art/v1/combat/`.
- Nothing is hand-drawn or pixel-edited. Crop, alpha quantise, palette remap and sheet
  assembly only.

## 3. Spend

Nominal PixelLab generations issued by this round, from the tool's own cost lines (the account is
shared with other streams running concurrently; `get_balance` deltas are not this round's spend):

| What | Calls | Gens |
|---|---|---|
| `create_character` standard: wolf (quadruped `dog`, side, 40) ×1, goblin (44) ×2, guardian (76, 68) ×2 | 5 | 5 |
| `create_character` v3: goblin (44), guardian (76) — 2 gens each | 2 | 4 |
| Traveler east: template `fight-stance-idle-8-frames`, template `taking-punch`, v3 attack, v3 idle, v3 guard idle (custom start frame) | 5 | 5 |
| Wolf west: template `idle`, v3 attack, v3 hit ×3, v3 idle, v3 defeat | 7 | 7 |
| Goblin (v3 character) west: v3 idle ×2, v3 attack, v3 hit ×3, v3 defeat | 7 | 7 |
| Guardian standard (108 canvas) west: template `breathing-idle` (1), template `taking-punch` (1), v3 slam ×2 (2 each), v3 swipe (2), v3 hit ×2 (2 each), v3 idle (2), v3 defeat (2) | 9 | 16 |
| Guardian v3 (104 canvas) west: v3 idle, slam, swipe, hit, defeat — 1 gen each | 5 | 5 |
| `create_image_pixen`: backdrops ×4 (forest, mine ×2, hollow), effects ×5 (slash ×3, impact, bite) | 9 | 9 |
| `animate_image`: impact, bite, slash (crescent) | 3 | 3 |
| **Total** | **52** | **61** (budget 120) |

## 4. Round log — what was made, and from what

Character ids (PixelLab): Traveler `c82b7da5-cda0-44eb-ae4e-30d73689e115` (existing) ·
**Stride Forest Wolf `9fa78318-f835-450f-8c35-4531d0181bd6`** (standard, quadruped dog, side, 40 → 56 canvas; west rotation 38×29 px) ·
Stride Cave Goblin standard `2a7ec5df-e01a-499c-bcd9-c7180fdb9383` (44, no club, grey — not used) and
`b5f9ae26-1dfc-4a49-b102-1c862e8c5fd1` (44, ears, thin — not used) ·
**Stride Cave Goblin v3 `a42c194a-397b-40bb-b2c1-0add89b9b283`** (44 canvas, figure 37 px, hunched — used) ·
Stride Hollow Guardian standard `3a1d9fdc-8d15-472e-9446-c94989d599e4` (76 → 108 canvas, 84 px bark man with a moss disc — animated, then retired after QA read the disc as a badge/marker) and
`fc1a34f4-4904-4610-91a9-6b69fa89da36` (68, blocky, 66 px — not used) ·
**Stride Hollow Guardian v3 `ee019008-1b7d-422e-8d71-00c280d92ba9`** (76 canvas, figure 71 px, tree-trunk sentinel with a stone face — used).

Animation groups: Traveler `cmb_idle_east` e967fed2 (fight-stance, rejected) · `cmb_attack_east` 6f27bb62 · `cmb_hit_east` 7212afb2 · `cmb_idle_v3_east` 69feb27e (rejected, sword stub) · `cmb_guard_idle_east` 4f603b21 (used, custom start = attack f5).
Wolf `wolf_idle_west` 1e572e95 (template, imperceptible) · `wolf_attack_west` ba0f2ffb · `wolf_hit_west` 25238122 (baked flash) · `wolf_hit2_west` 44244706 (trot) · `wolf_hit3_west` f2fee38f (withheld) · `wolf_idle_v3_west` 0c3c010a (used) · `wolf_defeat_west` df8371c9.
Goblin `goblin_idle_west` 5091f89c (read as punch) · `goblin_idle2_west` 0896ec92 (used) · `goblin_attack_west` 003b14ee · `goblin_hit_west` cdbc5364 · `goblin_hit2_west` c955ef1e · `goblin_hit3_west` d7fc6400 (used) · `goblin_defeat_west` 5f0d5dfb.
Guardian standard: `guardian_idle_west` 7696a83d · `guardian_slam_west` a33441ce · `guardian_slam2_west` e3caf238 · `guardian_swipe_west` 14d348f5 · `guardian_hit_west` 9f24bf0b (template redrew the creature) · `guardian_hit2_west` 58527c17 · `guardian_hit3_west` 5fb84c76 · `guardian_idle_v3_west` eb5580fe · `guardian_defeat_west` 13884eca — all retired with the character.
Guardian v3: `g3_idle_west` 4f7a05fc · `g3_slam_west` c8c27576 (ships as `guardian_swipe`) · `g3_swipe_west` 7c73b9c1 (ships as `guardian_attack`) · `g3_hit_west` 0201f586 · `g3_defeat_west` e8b3a83b.
Images: backdrops pixen 5d237f33 (forest), ae649e16 (mine A, not used), a0b45a69 (mine B, used), b8ace6e8 (hollow); effects pixen 41c18462 (impact) → animate 2e687b96; f4011275 (bite) → 2f2deb0c; slash pixen c7d0fa68 (a sword), 8abb0e7b (a crescent moon), 6420bdfb (a sword) → animate 187c7974 (a shrinking moon; rejected).

### Method notes
- Every v3 output canvas is the rotation canvas plus padding: Traveler 64 → 88 (offset 12,12), wolf 56 → 64 (4,4), goblin 44 → 56 (6,6), guardian v3 76 → 104 (14,14). Packaging crops back to one fixed canvas per figure (Traveler 64 with feet on row 62 — the ambient anchor; the attack is 80×64 like the ambient wide scenes; wolf 56, goblin 56, guardian 96 at offset (4,4) of the 104).
- The Traveler's guard idle was generated with `custom_start_frame` = attack f5, so its frame 0 is the attack's last frame; the stage can chain attack → idle without a pop.
- Palette: every figure frame is remapped to its own rotation palette (Traveler: the shipped south idle's 31 colours) at nearest-colour distance ≤48 (A-2). The sword blade (pale blue-grey steel, off-palette) is kept. Backdrops are remapped to their location vignette's palette (mean distance before remap 16–28, 1–12 % of pixels beyond 48 — moss/mist highlights, kept).
- Zero semi-transparent pixels arrived in any frame; the alpha quantiser never fired. Teal check (`#58d6c0` ±12): zero hits.
- Nothing was hand-drawn or pixel-edited. Frame selection, crop, alpha quantise, nearest-colour remap and sheet assembly only.
- Prompts (verbatim action descriptions) are recorded in `tools/accept.json` notes and in the PixelLab animation/character records under the group ids above.

## 5. Delivered (`../out/combat/manifest.json` is the contract)

`anchor` = the figure's standing baseline (use this to place the feet; `baseline` is the lowest opaque row of the sequence and dips 1 px in a few lying/crouching frames). `groundRow` = the backdrop row the feet stand on. Files: `<id>_f<i>.png`; backdrops `<id>.png`.

| id | kind | frames | fps | loop | canvas | anchor | status | source (frames kept) |
|---|---|---|---|---|---|---|---|---|
| traveler_combat_idle | traveler | 7 | 6 | pingpong | 64×64 | 62 | accepted | cmb_guard_idle_east 0–6, crop (12,10) |
| traveler_attack | traveler | 4 | 10 | once | 80×64 | 62 | accepted (MARGINAL) | cmb_attack_east 1,2,3,5, crop (4,12); f2 = extended blade |
| traveler_hit | traveler | 6 | 8 | once | 64×64 | 62 | accepted | cmb_hit_east 0–5 (template taking-punch) |
| wolf_idle | enemy.forest_wolf | 8 | 6 | pingpong | 56 | 40 | accepted | wolf_idle_v3 0–7 |
| wolf_attack | enemy.forest_wolf | 9 | 10 | once | 56 | 40 | accepted | wolf_attack 0–8; f5 = open-jawed lunge |
| wolf_hit | enemy.forest_wolf | 4 | 10 | once | 56 | 40 | **withheld** | wolf_hit3 0,1,2,5 |
| goblin_idle | enemy.cave_goblin | 7 | 6 | pingpong | 56 | 46 | accepted | goblin_idle2 0–6 |
| goblin_attack | enemy.cave_goblin | 9 | 10 | once | 56 | 46 | accepted | goblin_attack 0–8; club raised f2, strike f4–5 |
| goblin_hit | enemy.cave_goblin | 4 | 10 | pingpong | 56 | 46 | accepted | goblin_hit3 0–3 (knocked onto its back; pingpong brings it up) |
| guardian_idle | enemy.hollow_guardian | 7 | 4 | pingpong | 96 | 83 | accepted | g3_idle 0–6 |
| guardian_attack | enemy.hollow_guardian | 7 | 6 | once | 96 | 83 | accepted | g3_swipe 0–6 — the heavy strike (arm raised high, brought down) |
| guardian_swipe | enemy.hollow_guardian | 9 | 8 | once | 96 | 83 | accepted (MARGINAL) | g3_slam 0–8 — the normal strike (forward hunch/grab) |
| guardian_hit | enemy.hollow_guardian | 4 | 8 | once | 96 | 83 | accepted (MARGINAL) | g3_hit 0,1,2,6 |
| wolf_defeat | enemy.forest_wolf | 7 | 8 | once | 56 | 40 | accepted | wolf_defeat 0–6 (lies down) |
| goblin_defeat | enemy.cave_goblin | 7 | 8 | once | 56 | 46 | accepted | goblin_defeat 0–6 (sits slumped) |
| guardian_defeat | enemy.hollow_guardian | 7 | 6 | once | 96 | 83 | **withheld** | g3_defeat 0–6 |
| fx_impact | effect | 5 | 12 | once | 32 | – | accepted | pixen + animate_image |
| fx_bite | effect | 5 | 12 | once | 32 | – | accepted (MARGINAL, 1-px streaks) | pixen + animate_image |
| backdrop_forest / _mine / _hollow | backdrop | 1 | – | static | 192×96 | groundRow 88 | accepted | pixen, palette-conformed |

Not packaged (rejected): `traveler_fight_stance` (template fight-stance idle — bare fists, read as a walk), `fx_slash` (a crescent moon), the standard-mode guardian set, wolf hit rounds 1–2, goblin idle round 1 and hit rounds 1–2, Traveler v3 idle (sword stub).

Deviations from the brief: the guardian is 71 px tall (≈1.15× the Traveler, brief said 1.25×) on a 96 canvas; the goblin is 37 px (brief said 40–48) but reads as a small hunched goblin and QA found the scale plausible; `fx_slash` was not achievable in three pixen rolls + one animate (pixen draws a sword or a moon) — the Traveler's own attack frames carry the blade sweep, and `fx_impact` marks the landing; the Traveler's combat idle and attack are v3 outputs that drift toward three-quarter view (the two template sequences stay in profile); the mine backdrop shows the timbered adit (the location's landmark) — QA reads its black opening as an entrance one would walk into.

## 6. QA material

- `../qa/combat_sheet_x1.png`, `_x2.png` (verdict scale), `_x8.png` (inspection) — one row per packaged sequence in manifest order.
- `../qa/combat_context_x2.png` — Traveler east + each enemy west on its backdrop at ×2, idle pair and an exchange.
- `../qa/_z9/` — the neutral staging set handed to Visual QA (opaque shuffled codes; key in `tools/_stage_key.json`, outside the staged folder). Regenerate with `node tools/stage.js`.

STAGING CHECK: PASS (A1–A6, B1–B3, C1–C14, D1–D3 followed; D4 known limit — the reviewer's own context carries the product premise and this exploration folder name; each reviewer was asked what leaked and reported it).

## 7. AUTHOR ASSESSMENT

What I believe holds at ×2: the wolf lunge-bite, the goblin overhand club strike, the guardian's raised-arm strike, the goblin knock-down, the Traveler's slash (blade extended in f2) and taking-punch recoil, the three backdrops with figures planted on row 88, the impact burst. The Traveler's guard idle chains from the attack without a pop. Every enemy sits on one canvas with one anchor across all its sequences.

What I doubt: quadruped hit reactions — three wolf rounds each read as something other than a flinch in a blind strip; the guardian's normal strike is a hunch/grab with an abrupt cut; the guardian hit is a mild stagger; the Traveler's v3 sequences turn toward the viewer and his blade is a cold pale steel that QA calls "glowy" at ×2; the bite/scratch effect is thin. The mine backdrop's adit is a strong focal doorway.

Suggested for the lead: enable `wolf_hit` only if it reads in the live stage (the motion is away from the Traveler); otherwise pair `fx_impact` with a UI-side offset. Consider a small stage padding above the guardian (head at row 5 of the backdrop when the feet are on 88).

## 8. QA VERDICT (independent Visual QA — three blind passes, verbatim conclusions)

**Pass 1 (full set, before re-rolls) — verdict FAIL.** Flags: wolf idle (no change at all), guardian idle (no perceptible change), Traveler attack (view-angle switch and disappearing prop — not a sequence), guardian hit/defeat/swipe (back appendage appears mid-strip and changes tail/cape identity across strips), effects composite plate (unclear job), fx_slash (reads as moon/C before slash), fight-stance idle (raised fist through whole walk — ambiguous action), goblin defeat (soft as a death). Goblin idle read as a punch; goblin hit indistinguishable from it. Everything else fine. Set reads as one production; misty backdrops a distinct cooler palette but consistent. Leak: folder path and the reviewer's own context primed "player vs enemy" framing; no claim depended on it.

**Pass 2 (re-rolled sequences + context plates) — per code:** Traveler attack "reads as a draw-and-slash, but the last frame is a different camera angle rather than a follow-through … the blade appears from nowhere in frame 2 … reads as a glowing blade" (marginal). Wolf idle "reads as a breathing idle; change is barely perceptible" (fine). Wolf hit "reads as a pounce/lunge landing in a low crouch; frame 4 is a dark lump" (flagged). Goblin idle "idle; near-static" (fine). Goblin hit "reads as hit-and-fall/knockdown/death" (fine). Guardian (standard) idle/hit: "the green disc reads as a marker/badge/orb rather than anatomy … a second one flickers in and out" (flagged) — this retired the standard guardian. Scenes: figures share the ground line, scale plausible; "the pitch-black doorway is a strong focal shape and reads as an entrance one would walk into"; the man's leading hand in the recoil pose "is a bright orange blob".

**Pass 3 (v3 guardian + wolf hit r3 + hollow plates) — per code:** guardian idle "reads as an idle/breathing loop" (fine); `g3_swipe` (ships as guardian_attack) "front arm shoots up high with splayed twig-fingers … reads as an overhead swipe/slam" (fine); `g3_slam` (ships as guardian_swipe) "reads as an attack wind-up/lunge or a grab, but the change from frame 5 to 6 is abrupt … head loses its tall branch spikes" (flagged); guardian hit "reads as a big spin/sweep attack or a stagger — I cannot tell which; frames 3–5 are noticeably bulkier" (flagged; those frames were dropped); guardian defeat "the last three frames read as a quadruped animal with a tail … identity drift" (flagged → withheld); wolf hit r3 "reads as a run cycle, or as run frames 1–3 with a separate crouch/pounce frame 4" (flagged → withheld); scenes fine, "the creature's grey face somewhat merges with the wall behind it" in the hollow. Leak: reviewer's own context (PixelLab, character-exploration folder names) primed "player and enemy"; nothing from filenames.

## 9. Disposition (author, after QA)

accepted: traveler_combat_idle, traveler_attack (MARGINAL — angle drift, cold blade), traveler_hit, wolf_idle, wolf_attack, wolf_defeat, goblin_idle, goblin_attack, goblin_hit, goblin_defeat, guardian_idle, guardian_attack, guardian_swipe (MARGINAL — abrupt cut), guardian_hit (MARGINAL — mild stagger), fx_impact, fx_bite (MARGINAL — thin), backdrop_forest, backdrop_mine (note: adit reads as a doorway), backdrop_hollow.
withheld (packaged, `status: withheld`, not to be drawn): wolf_hit, guardian_defeat.
rejected (not packaged): traveler_fight_stance, fx_slash, and every earlier round listed in §4.
retry reasons on record: quadruped flinch (three rounds, none read); slash effect (pixen draws the noun, not the trail); template hit on the standard guardian (redrew the creature).
