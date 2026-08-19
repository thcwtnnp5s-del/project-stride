# PLAYABLE_EXPANSION_01 — ambient / readability correction round

```
STATUS: round record · correction of art that FAILED or was weak at play scale in TRANSFORMATION_01 · NOT CANON
Author: PixelLab ambient/readability correction agent (2026-08-19).
Nothing here is committed, staged, or written to assets/, lib/, Scripts/ — the lead integrates (see INTEGRATION NOTES).
QA VERDICT is written by an independent Visual QA agent (M-04); the disposition below it is the author's.
```

Governed by `../../TRANSFORMATION_01/ART_DIRECTION_BRIEF.md`, `PIXELLAB_STYLE_SPEC_01.md` §7.2 (style clause,
appended verbatim to every icon prompt), `RULES.md` A-1/A-2, `MISTAKES.md` M-04/M-05,
`NEUTRAL_STAGING_CHECKLIST.md`.

## 0. Spend

Nominal PixelLab generations issued by this agent, from the tool's own cost lines (budget ≤ 60):

| Target | Tool | Calls | Gens |
|---|---|---|---|
| A1 axe (`px_axe_whet`, `px_axe_whet2`) | `animate_character` v3, south, 8 f, keep_first_frame | 2 | 2 |
| A2 pick (`px_pick_ground`, `px_pick_kneel`) | same | 2 | 2 |
| A3 read (`px_read_bigbook`) | same | 1 | 1 |
| A4 stretch (`px_stretch_side`, `px_stretch_fold`) | same | 2 | 2 |
| A5 push-up alternative (`px_squats` south 8 f; `px_plank_east` east 10 f) | same | 2 | 2 |
| B tin seam (c1, c2) | `create_image_pixen` 96×96, side, no_background | 2 | 2 |
| C pine plank (c1, c2) | `create_image_pixen` 48×48, high top-down | 2 | 2 |
| C pine log (c1, c2) | `create_image_pixen` 48×48, high top-down | 2 | 2 |
| D foraging sprig (c1) | `create_image_pixen` 24×24, side, low detail | 1 | 1 |
| **Total** | | **16** | **16 of 60** |

`get_balance` read 775 at the start of the session; the account is shared with the parallel combat-art
agent, so the balance delta is not this agent's spend. Budget is counted from the per-call cost lines
(each call above printed `cost: 1 generation`).

## 1. Method (unchanged from T01 stream E unless stated)

- Traveler scenes: `animate_character(c82b7da5-cda0-44eb-ae4e-30d73689e115, mode="v3", frame_count=8,
  keep_first_frame=true, directions=["south"])`. Frame 0 is the south idle rotation. Output canvas 88×88;
  packaging crops at (12,12) → 64×64, feet on row 62, exactly the T01 anchor. **Every accepted correction
  fits the 64 canvas** (no 80-wide frames this round; the widest source bounds were x 13..75).
- Palette: nearest-reference-colour remap ≤ 48 to the 31 idle colours (`candidates/_ref/f0.png`), same as
  T01; off-palette pixels beyond 48 kept (pick head steel: 2 colours; axe head: 2 colours). Zero
  semi-transparent pixels arrived; the alpha quantiser never fired.
- Items/nodes: `create_image_pixen` (T01 workstream F's cheap path); node with `view="side"` and the
  "standing alone on a transparent background, no base, no platform, no tile" clause; icons with the §7.2
  style clause verbatim. Post-processing = `despeckle.js` (< 8 px orphan components → transparent; **0 px
  removed on every accepted file**), size/alpha check. No inpaint, no edit, nothing hand-drawn.
- Tools (`tools/`): `fetch_groups.js` (parse a `get_character` dump, download `px_*` groups),
  `inspect.js` (bounds/alpha/colours + ×1/×2/×8 strips per candidate), `peek.js`, `package.js`
  (`accept.json` → `out/ambient/`, `manifest.json`, `../qa/ambient_correction_sheet_x{1,2,8}.png`),
  `dl2.js` (image job download), `despeckle.js`, `view.js`, `skillbg.js`, `stage.js` (blind staging →
  `../q3m8/`, key in `tools/BLIND_KEY.txt`).
- The character zip download stayed HTTP 423 for the whole session (the parallel agent's jobs kept the
  character busy), so frames were fetched from the `get_character` dump's per-frame URLs; two frames
  404'd on the first pass and succeeded on retry (CDN lag) — `fetch_groups.js` now tolerates that.

## 2. Candidates and prompts (verbatim action descriptions)

### A1 `traveler_axe_inspect` (T01 QA: FAIL — pale head reads as paper)

- `px_axe_whet` (group cd891d35): "standing, holding a small hand axe low across the body in one hand, the
  axe has a dark iron head and a wooden haft, running a small dark whetstone held in the other hand along
  the axe head in slow strokes, then lifting the axe a little to look along its edge"
  → dark iron head on a wooden haft, held low across the body, both hands on the haft; **no whetstone
  appeared**. The head flashes pale in source f2/f4/f6 (the "stroke" became a highlight) and is dark in
  f3/f5/f7/f8. Head shape is a bell/wedge — the risk is a "mallet" read.
- `px_axe_whet2` (e4a119b7): "standing, holding a small hand axe with a dark iron head and wooden haft in
  the left hand, the axe head held up at chest height with the edge facing right, the right hand holding
  a small dark grey rectangular whetstone and rubbing it back and forth along the axe edge in slow
  visible strokes, then pausing to hold the axe up and look closely at the edge"
  → pale grey crescent head (reads sickle) and a floating whetstone at f7. **Rejected.**
- Packaged: `px_axe_whet` frames **[0,3,5,7,8]**, 5 fps, pingpong, 64 canvas — only the dark-head
  frames, so the head cannot flicker. Motion is small (haft angle, head tilt) — an idle, not a task.

### A2 `traveler_pick_inspect` (T01 QA: FAIL — raised pick reads "about to mine")

- `px_pick_ground` (48724903): "standing, then crouching down and resting a pickaxe head-down on the ground
  in front of him, holding the wooden shaft with one hand while leaning over to inspect the pickaxe head,
  tapping the head with the other hand twice, then standing back up with the pickaxe held horizontally
  low at waist height, never raised over the shoulder"
  → crouch, pick held horizontal and low across the thighs, hand goes to the head twice, never above the
  waist. Source f1–2 crouch before the pick appears (pick pops in at f3). Feet on row 63 in the crouch
  frames (1 px, as T01 tolerated). Packaged **[0,3,4,5,6,7,8]**, 6 fps, pingpong, 64 canvas.
- `px_pick_kneel` (0e633b2c): "standing, then kneeling down on one knee with a pickaxe lying flat on the
  ground in front of him, its dark iron head to one side, resting one hand on the wooden shaft and
  running the other hand slowly along the pickaxe head, tapping the head twice, then standing back up
  empty-handed"
  → kneels with the pick across the knees, head bowed to it; more static. Packaged as
  **`traveler_pick_inspect_alt`** [0,3..8], 6 fps, pingpong, 64 canvas — for QA to compare; only one of the
  two is meant to ship.

### A3 `traveler_read` (T01 QA: FAIL — no book perceptible at ×2)

- `px_read_bigbook` (4bcf4d58): "standing, lifting a large open book with a dark brown cover and thick pale
  cream pages up to chest height, holding it open wide with both hands so the big bright page block faces
  the viewer, head bowed reading it, one hand lifting to turn a page, then reading again"
  → f1–2 draws a dark closed book to the chest, f3 opens it, f4–8 a large open book (page block ≈ 40×12
  px in the 64 frame, cream on dark cover), head bowed. Oversized — a ledger/tome, not a pocket book —
  but unmistakable. Packaged **[0..8]**, 6 fps, pingpong, 64 canvas.

### A4 stretch alternative (T01 QA: PASS-WITH-NOTE — peak reads cheer)

- `px_stretch_side` (99de924f): "standing, a slow side stretch: one arm raised and bent over the top of the
  head, the other hand on the hip, leaning the upper body sideways to one side and holding the stretch,
  then straightening up and lowering the arm"
  → arm out, then bent over the head, other hand on hip, slight lean; never both arms up. Risk: "shading
  the eyes / looking into the distance". Packaged as **`traveler_stretch_side`** [0..8], 6 fps, pingpong,
  64 canvas (the T01 overhead stretch needed 80).
- `px_stretch_fold` (2ce3eb9e): "standing, a slow forward-fold stretch: bending forward at the waist with the
  knees straight, letting both arms hang down and reaching the hands toward the toes, holding the stretch
  with the head down, then slowly rolling back up to standing"
  → from the front the fold is a hunched figure with the pack looming above the head; reads bow / dejected.
  **Not packaged**; staged raw for QA only.

### A5 push-up alternative (T01 QA: PASS-WITH-NOTE — prone reads collapsed)

- `px_squats` (a3d9898b, south): "standing facing the viewer, doing slow squats: bending the knees to lower
  the hips down as if sitting on an invisible chair, arms held straight out in front for balance, then
  straightening back up to standing, twice"
  → from the front a squat is a figure 5 px shorter with the arms out low; reads wobble/bounce.
  **Not packaged.**
- `px_plank_east` (d22c9fa8, east, 10 f): "going down onto hands and toes into a high push-up plank seen
  from the side, arms straight and locked, body in one straight line, head lifted and looking forward,
  then doing slow push-ups: bending the elbows to lower the chest halfway toward the ground and pushing
  back up to the straight-arm plank, head staying up throughout, twice"
  → near-identical to the shipped `traveler_pushups_side` (same descent, same low plank; head marginally
  higher). Does **not** clearly beat it. **Not packaged.**

### B `node_tin_seam` (T01 QA: PASS-WITH-NOTE, MAJOR B — boulder / cookie)

- c1 (`71a411bc-f948-4320-9185-b46b2bff0798`, seed 1501): "a rough dark grey rock face outcrop with a wide
  bright silver-grey tin ore seam running diagonally through it, the seam studded with glinting pale
  silver cassiterite lumps and small metallic nuggets, a few fresh pick marks chipped into the seam
  exposing shiny grey metal, small broken ore chips on the ground at the base, standing alone on a
  transparent background, no base, no platform, no tile — pixel art game gather node, single dark
  outline, flat matte shading in a few clear steps, light from the upper left, warm earthy limited
  palette, no glow, no text"
  → dark grey rock face, wide diagonal silver seam with lumps, ore chips at the base. Squarish block
  silhouette (risk: "wall / tile"), but seam-in-rock is unmistakable. **Chosen** → `out/items/node_tin_seam_96.png`.
- c2 (`9adeb9f7-fcbe-403c-8dda-41917ebbd788`, seed 1502): "an irregular rounded grey rock outcrop, a lumpy
  boulder-like rock face with a wide diagonal seam of tin ore cutting through it: …" (same tail)
  → a boulder again, with a silver band, sparkle crosses (read as emote) and a scribble of pseudo-text
  under it. **Rejected.**

### C `icon_pine_plank` (T01 QA: PASS-WITH-NOTE — alone reads paper/soap)

- c1 (`fe059ca5-af8b-4f14-ac37-bfb623e4e73e`, seed 1601): "a single sawn pine plank laid flat, seen from
  directly above, a long rectangular board with squared cut ends, warm resinous yellow-tan wood with
  several long dark wood grain lines running the length of the board and two small dark knots, a slightly
  darker cut end face visible at one end showing the board's thickness — <§7.2 clause>"
  → a short thick yellow block, ≈2:1 — reads box/bar. Kept as alternate.
- c2 (`f2d6b9e1-276f-434c-841b-ce78f7bc926d`, seed 1602): "a single long thin sawn pine plank laid flat and
  diagonal across the frame, seen from above: a narrow flat board about five times longer than it is
  wide, squared cut ends, warm resinous yellow-tan wood face with three long dark wood grain lines
  running the length of the board and one small dark knot, thin darker side edge showing the board is
  thin — <§7.2 clause>"
  → warm orange-tan board with grain lines, a knot and squared ends; still ≈2.5:1, not 5:1. **Chosen** →
  `out/items/icon_pine_plank_48.png`. Note it now sits in the same warm hue as the shipped `pine_log`.

### C `icon_pine_log` (T01 QA note: oak/pine logs are hue-only twins)

- c1 (`a79e85f8-adfd-41f9-b24c-342a6d961eeb`, seed 1701): "a single short pine log lying flat, seen from
  slightly above at a diagonal: a cylinder of pale yellow-tan pine wood with thin flaky light orange-tan
  bark, two dark knots on the side, a small amber resin drip, and a cut end face showing pale cream wood
  with a few growth rings — <§7.2 clause>"
  → still orange; the "resin drip" came out blue-grey. **Rejected.**
- c2 (`b881a5a9-cdf1-4320-8f3e-8be4266e76ed`, seed 1702): "a single short pine log lying flat at a
  diagonal, seen from slightly above: a cylinder of pale straw-yellow pine wood with thin papery pale tan
  bark peeling in a strip, two small dark knots on the side and one short stub branch, cut end face
  showing pale cream wood with growth rings — <§7.2 clause>"
  → pale straw-yellow log with two stub branches and end grain; separates from oak_log (dark bark) by
  value as well as hue. Risk: "baguette". **Chosen** → `out/items/icon_pine_log_48.png`. Oak log
  untouched (regenerate ONE of the pair, per the brief).

### D `skill_foraging` (T01 QA: PASS-WITH-NOTE, MINOR A — low contrast at ×1)

Contrast check first (`../qa/_skills_on_surfaces_x4.png`, the five 24-px icons on `surfaceCard`,
`surfaceBlock`, `surfaceRaised`, `surfaceGround`): the shipped sprig is the lowest-mass icon of the five —
thin stems, mid-green, ≈45 % of the pixel mass of the log or pot — so the problem is confirmed against the
StrideColors greys.

- c1 (`c22b5387-190b-4a61-9f86-0ce73184cb01`, seed 2301, 24×24, side, low detail): "one solid connected
  shape: a bold sprig of three broad rounded leaves on a short thick stem, the leaves bright yellow-green
  and chunky, filling most of the frame, dark single outline all the way around — tiny pixel art game
  skill icon, flat matte shading in two values, light from the upper left, warm earthy limited palette,
  no detached pixels, no glow, no text, no ground"
  → three broad yellow-green leaves on a stem, 256 opaque px vs the shipped 24-px sprig; brighter and
  fuller. Colour count is high (46) — pixen anti-aliased the outline; a two-value reduction was NOT
  applied (that would be authoring; flag for the lead). **Chosen** → `out/items/skill_foraging_24.png`.
  Shipped at 24 native ×1 per the T01 lead decision; no 12-px reduction produced.

## 3. Deliverables

- `out/ambient/` frames — `traveler_axe_inspect` (5 f), `traveler_pick_inspect` (7 f),
  `traveler_pick_inspect_alt` (7 f), `traveler_read` (9 f), `traveler_stretch_side` (9 f); all 64×64,
  baseline 62 (63 in the pick crouch frames), palette-remapped, 0 semi-alpha. **`out/ambient/manifest.json`
  lists only the accepted set after QA (§6) — currently `traveler_read`; the others are listed in
  `withheld_manifest.json` for the record and are not to be packaged.**
- `out/items/icon_pine_log_48.png`, `skill_foraging_24.png` (accepted); `../items/withheld/node_tin_seam_96.png`,
  `../items/withheld/icon_pine_plank_48.png` (withheld after QA, §6); raw candidates in `../items/candidates/`.
- `../qa/ambient_correction_sheet_x{1,2,8}.png` — one row per packaged sequence, in manifest order.
- `../q3m8/` — blind staging (100 files, opaque shuffled codes, no text, no chrome). Key:
  `tools/BLIND_KEY.txt`. Set per code: `_a` native, `_b` ×2, `_c` ×8, `_d` ×2 in-context (rest figure +
  two frames on plain ground); item cells ×1/×2/×8; node plates ×1/×2/×8 + a ×1/×2 row; skill rows
  ×1/×2/×4/×8; a wood-family grid ×1/×2. Distractors: the five CURRENT T01 sequences, the current
  pine_plank/pine_log/oak_log/oak_handle/bronze_ingot icons, current tin and copper nodes, the current
  skill row, and the three unpackaged candidates.

STAGING CHECK (NEUTRAL_STAGING_CHECKLIST): A1 opaque names ✓ · A2 no ordinals (`_a.._d` are scale /
presentation, not sequence — told to the critic as such) ✓ · A3 opaque dir ✓ · A4 shuffled ✓ · A5 ✓ ·
A6 native, ×2, ×8, context present ✓ · B1 no text ✓ · B2 blank cells/ground only ✓ · B3 no labelled
sheet in `q3m8/` ✓ · D1 key outside ✓ · D4 caveat: the critic's `git status` shows `PLAYABLE_EXPANSION_01/`
and `TRANSFORMATION_01/`, disclosing that a correction round exists but not which code is which.
**STAGING CHECK: PASS**

## 4. AUTHOR ASSESSMENT

What I believe holds at ×2:
- **read** — the book is now the biggest thing in the frame; nobody will miss it. The cost is scale
  (a tome, not a pocket book); it does not read as a sign, a map or a screen because the dark cover and
  cream page block are seen edge-on-open with the head bowed.
- **pick_inspect (px_pick_ground)** — the pick is never above the waist; crouched over it with the hand
  going to the head reads inspection/checking, and it is visibly not the T01 gather strike. Steel head
  is still pale blue-grey (2 kept off-palette colours, as in T01).
- **axe_inspect** — the head is dark iron on a wooden haft, held low across the body; the "paper" read
  is gone. My doubt: at ×2 the bell-shaped head could read **mallet/hammer** in two of the five frames,
  and the motion is a small tilt — it says "holding a tool, looking at it", not "sharpening".
- **stretch_side** — cannot read as a cheer (one arm, bent, hand on hip). My doubt: "shading the eyes"
  or "looking into the distance", which is still an idle and not an emote.
- Items: tin seam c1 reads seam-in-rock with silver lumps; my doubt is the squarish silhouette
  ("wall / block"). pine_log c2 separates from oak_log by value; pine_plank c2 has grain, a knot and
  squared ends and is warm rather than paper-white, but it is a short board and it now shares a hue with
  the shipped pine_log rather than with the new pale one. Foraging c1 is fuller and brighter than the
  shipped sprig on every StrideColors surface.

What I do not put forward: `px_axe_whet2` (sickle head, floating stone), tin c2 (boulder + sparkles),
pine_log c1 (blue "resin"), pine_plank c1 (block), `px_stretch_fold` (bow), `px_squats` (wobble),
`px_plank_east` (no clear gain over the shipped plank). A5 therefore has no candidate — the shipped
`traveler_pushups_side` stays.

## 5. QA VERDICT (independent Visual QA, 2026-08-19)

The Visual QA agent type has no Write tool, so its report is transcribed here verbatim by the author
(nothing edited, nothing omitted); the code → asset key is `tools/BLIND_KEY.txt`, decoded in brackets.

> STAGING NOTE: all images opened at `_b` first; no key/manifest/README consulted. Charter file `AGENTS/visual_qa.md` deliberately not opened per the task's "image files only" instruction.
>
> PART 1 — figure strips (verdicts formed at `_b` 2×)
>
> - **wq** [CURRENT traveler_read] — (1) Front-facing figure with a rolled pack on his back looks down at a small white/cream object held in both hands at the belly; the object is a few pixels of white — cannot tell what it is (scrap of paper/note, small stone, or clasped hands with a highlight). (2) First read: (a) idling — inspecting something in his hands; second read: (d) praying / hands clasped. (3) Frames 0–1 plain standing, 2–8 head-down looking at hands; stable but low-energy. (4) **PASS-WITH-NOTE** — "looking at something small in his hands" is stable, but the object is unreadable at 2× and the pose competes with "praying".
> - **zx** [NEW traveler_pick_inspect_alt] — (1) Figure crouched with legs cut off/hidden below the knees, holding a pickaxe (grey metal head at left, orange-brown handle) horizontally at waist; the pick barely moves across the strip — no swing, no strike. (2) (b) working — but read as "holding a pick", not "mining"; second read: (a) idle-with-tool. (3) Stable; frame 3 (grip shifted, arm across) reads slightly different but same object. (4) **PASS-WITH-NOTE** — object clear (pickaxe); action is a hold, not a swing; lower legs missing in every frame incl. `_d`, so the figure appears sunk into the ground/kneeling.
> - **hv** [CANDIDATE px_plank_east] — (1) Side-view figure with backpack tips forward from standing and ends up prone on hands and toes, body straight — a press-up/plank position. (2) (c) exercising (push-up); second read arrives immediately: (e) falling forward / collapsing face-first, because the drop is a single forward topple with no arm bend visible. (3) Frames 0–2 standing, 3–4 lean, 5 mid-fall (reads as a trip), 6–11 plank; frames 6–11 have no up/down rep, so the "push-up" read depends on knowing it's a loop. (4) **PASS-WITH-NOTE** — plank pose reads at 2×; the transition (frame 5) reads as a stumble/fall.
> - **tn** [NEW traveler_axe_inspect] — (1) Front-facing figure holds an axe (dark near-black head with a paler blade edge, brown handle) horizontally at waist; only the axe angle tilts a few degrees across frames — no chop. (2) (b) working / readying a tool; second: (a) idle with tool. (3) Stable; frame 3 (axe held higher, angled) still same object. (4) **PASS-WITH-NOTE** — object reads as axe/hatchet, but the very dark blocky head also reads as a mallet/hammer at 2×; no chopping motion.
> - **kr** [CURRENT traveler_pushups_side] — (1) Side-view figure (near duplicate of hv) tips from standing to a prone hands-and-toes plank. (2) (c) exercising / plank; second: (e) fall/collapse. (3) Frames 0–3 standing, 4 lean, 5 mid-topple (reads as trip), 6–11 prone; in frames 8–11 the near hand appears to hang below the body line without clearly meeting the ground. (4) **PASS-WITH-NOTE** — same caveats as hv; I cannot distinguish kr from hv at 2× (only visible difference: pack tone/hair, cannot tell).
> - **yp** [NEW traveler_stretch_side] — (1) Front-facing figure raises one arm from side to a bent-elbow raised hand near head, then lowers it; other hand on hip. (2) (d) gesture — wave/greeting; second reads: wiping brow (frame 5, hand at forehead) and flexing a bicep (frames 3–4). (3) Not fully stable: frames 3–4 read as bicep flex, frame 5 reads as brow-wipe/head-scratch, frame 8 as wave. (4) **PASS-WITH-NOTE** — "raising a hand" is clear, but wave / flex / wipe-brow compete at 2×.
> - **bm** [CANDIDATE px_stretch_fold] — (1) Front-facing figure folds forward at the waist until his head disappears behind/below the pack and his arms hang toward the ground, then rises. (2) (d) bowing; second reads: (c) toe-touch stretch, and (e)/(a) slumped exhaustion / catching breath. (3) Frames 3–6 the head is fully occluded by the pack — the sprite reads as a headless torso/lump at 2×; frames 0–2 and 7–8 standing. (4) **PASS-WITH-NOTE** — bow/bend reads, but bow vs stretch vs exhaustion is unresolved and the headless mid-frames are a legibility hit.
> - **gd** [NEW traveler_pick_inspect] — (1) Front-facing figure holds a pickaxe (pale grey head at right, orange handle with a lighter cap at the left end) horizontally at waist, small bob, no swing. (2) (b) working — holding a pick; second: (a) idle with tool. (3) Stable; frame 6 stands taller. (4) **PASS-WITH-NOTE** — object clear; hold, not a mining stroke; reads as a mirrored version of zx.
> - **sl** [CURRENT traveler_pick_inspect] — (1) Front-facing figure lifts a pickaxe (pale ice-blue/grey head, brown handle) from his side up to fully overhead in one hand while the other arm points across his chest, then lowers it back to his side. (2) (b) working — hoisting a pick to swing; second: (d) brandishing / triumphant hoist, because it's front-on with a pointing arm and never strikes anything. (3) Frames 0–1 no tool visible; 2 tool at side; 3–6 overhead; 7–8 tool lowered at right hip — stable enough. (4) **PASS-WITH-NOTE** — object clear; "swing" vs "show off the pick" ambiguous.
> - **fj** [CANDIDATE px_squats] — (1) Front-facing figure sinks into a shallow knees-bent crouch with arms slightly out, then straightens. (2) (c) exercising — a squat; second: (a) idle bob / bracing-to-jump. (3) Stable but shallow — at 2× frames 3–5 read only as a slight dip. (4) **PASS-WITH-NOTE** — "squat" is guessable but the depth is too small to be unambiguous at 2×.
> - **cu** [NEW traveler_read] — (1) Front-facing figure opens and reads a very large book (dark cover with brown/gold trim, cream pages; pages flutter in frames 4–5); the book is wider than his shoulders. (2) (b)/(a) — reading; second: none. (3) Frames 0–2 no book visible (frame 2 dark object at chest is unreadable), 3 opening, 4–8 open book. (4) **PASS** — book/reading is unambiguous at 2×; note the book's scale is oversized.
> - **on** [CURRENT traveler_axe_inspect] — (1) Front-facing figure lifts a double-headed axe (pale/whitish steel heads, olive-brown handle) from a low grip at his hip up to a horizontal two-hand ready hold. (2) (b) working — taking up an axe; second: (a) idle with weapon. (3) Frame 1: the pale object at his thigh reads as a white cloth/rag or paper, not an axe head, at 2×; frames 3–6 stable. (4) **PASS-WITH-NOTE** — object reads once raised; frame 1 is a different read.
> - **ae** [CURRENT traveler_stretch] — (1) Front-facing figure raises both arms from sides out to a T-pose and then straight overhead; feet stay planted. (2) (c) exercising — arm-raise/jumping-jack arms; second read arrives just as fast: (d) cheering / hands-up. (3) Frame 3 (T-pose) reads as a stretch, frames 4–5 as cheer/hands-up. (4) **PASS-WITH-NOTE** — motion clear, meaning split between stretch and celebration.
>
> PART 2 — single item cells (verdict at `_b`)
>
> - **pk** [CURRENT oak_handle] — light-brown wooden plank/board, diagonal, plain grain. **PASS**.
> - **vd** [NEW pine_plank c2] — yellow-orange wooden plank with a knot hole and a split at one end; second read: two boards side by side. **PASS-WITH-NOTE**.
> - **hz** [CANDIDATE pine_plank c1] — squared timber block/beam, yellow-brown, end grain rings visible on the near face; at 2× competes with "small wooden crate/box". **PASS-WITH-NOTE**.
> - **ln** [NEW pine_log c2] — pale yellow round log with growth rings on the end and small twig stubs. **PASS**.
> - **rt** [CURRENT oak_log] — dark brown bark log with a light ring-patterned cut face. **PASS**.
> - **bq** [CURRENT pine_plank] — pale cream/blond wide plank with a small dark hole near one end; second read: wooden tag/ruler. **PASS-WITH-NOTE**.
> - **we** [CURRENT bronze_ingot, distractor] — reddish-brown metal ingot with a base flange (copper/bronze); second read: chocolate block/clay brick. **PASS-WITH-NOTE**.
> - **mj** [CURRENT pine_log] — orange-brown log, lighter cut face with rings. **PASS**.
> - **grid_b / grid_a** [oak_handle · NEW pine_log · oak_log · NEW pine_plank] — cells L→R: (1) light-brown plank, (2) pale yellow log with twigs, (3) dark-bark log with light cut face, (4) yellow-orange plank with knot hole. Hard to tell apart in a hurry: cells 1 and 4 (both diagonal planks; only colour and the knot separate them; at ×1 the knot is a couple of pixels). Cells 2 and 3 are distinguishable (colour + bark). rt vs mj (not both in the grid) would also be a near-collision — same silhouette, differ only in brown vs orange.
>
> PART 3 — larger plates
>
> - **ux** [CURRENT copper_seam, distractor] — grey-blue boulder split by a vertical seam of orange-brown nuggets (copper-coloured ore) with pebbles at the base; no symbol/sparkle/text. **PASS** (reads "copper ore rock").
> - **qa** [NEW tin_seam c1] — squarish dark grey rock block with rounded corners and a diagonal white/silver band containing round grey nodules; two white fragments on a tan ground at bottom right. The band reads as a silver/quartz vein, but at 2× it competes with "riveted metal strap laid across a stone tile"; the square silhouette reads as a tile, not a boulder. No sparkle/text. **PASS-WITH-NOTE**.
> - **em** [CANDIDATE tin_seam c2] — rounded grey-brown boulder with a curved silver band; three four-point "X" glints float on the surface and read as sparkle symbols, not stone detail; faint grey debris/scribble under the rock reads like stray marks. Second read: a stone/egg with a ribbon. **PASS-WITH-NOTE** (sparkles flagged).
> - **ko** [CURRENT tin_seam] — round tan boulder with a dark crack containing grey metallic nodules and tan rubble at the base; no sparkle/text. Strong competing read at 2×: chocolate-chip cookie/biscuit (tan disc, brown flecks, grey chips). **PASS-WITH-NOTE**.
> - **row_b / row_a** — all four read as different things: grey rock with orange seam; square grey block with silver studded stripe; round grey stone with silver band and sparkles; tan round rock with dark crack. None read as the same thing, but qa and em share the "silver diagonal band" motif and would be confused as the same *material* at ×1.
>
> PART 4 — icon rows
>
> - **sr** [NEW foraging] first icon: bright yellow-green leafy sprig (3–4 leaves on a stem). **sz** [CURRENT foraging] first icon: dull dark-green three-leaf seedling. sr is much easier to make out at both ×1 and ×2; sz's first icon nearly vanishes into the dark surface at ×1 (`sz_a`). Other four icons (cut log/stump, dark rock with orange ore, anvil, clay pot) look identical in both rows at every scale.
>
> PART 5 — What leaked
>
> - Folder path `GAME_BIBLE/ART/exploration/PLAYABLE_EXPANSION_01/` and repo context (movement RPG with crafting/mining, PixelLab art pipeline, memory notes about PixelLab) primed me to expect game sprites, resource items and gathering tools before opening anything.
> - Prompt wording: "if something is held or handled" (told me tools/objects would appear); the category list naming "exercising" and "injury/fall/collapse" primed those reads for hv/kr/fj/ae; "symbol, sparkle, text or floating mark" primed me to hunt for sparkles in Part 3; "Rows sr and sz differ only in the first icon" told me where to look; "Several codes may show related or similar actions" told me duplicates existed.
> - Code names themselves leaked nothing. No file failed to open.
>
> QA VERDICT: PASS

Leak accounting (E2): the category list in the prompt (C2/C5 — the author's fault) primed "exercising"
and "fall/collapse" for hv/kr/fj/ae/bm and "sparkle" for em; those findings are discounted as prompted
confirmations. Reads that survive unprompted: the object identifications (book, pickaxe, axe vs mallet,
plank vs box, log, silver vein vs strap, sprig), the wave/flex/brow-wipe reads on yp, the oak_handle vs
new pine_plank collision, and the "hold, not swing" reads on gd/zx/tn.

## 6. Disposition (author, applying the round's rule: an accepted correction must PASS at ×2, else WITHHOLD)

| Target | QA (new) | QA (current) | Disposition |
|---|---|---|---|
| A3 `traveler_read` | **PASS** (cu) | PASS-WITH-NOTE (wq: object unreadable / praying) | **ACCEPTED** — in `out/ambient/manifest.json`; may enter the rotation |
| A2 `traveler_pick_inspect` (px_pick_ground) | PASS-WITH-NOTE (gd: "holding a pick, not mining"; second read idle-with-tool) | PASS-WITH-NOTE (sl: hoist / brandish) | **WITHHELD** by the rule (not a clean PASS). Author's recommendation to the lead: the T01 failure ("about to mine") is gone — QA's note *is* the intended read. Frames stay in `out/ambient/traveler_pick_inspect_f0..6.png`; a ready manifest entry is in `out/ambient/withheld_manifest.json`. Lead's call. |
| A2 alt (px_pick_kneel) | PASS-WITH-NOTE (zx: legs "cut off", sunk) | – | **REJECTED** (gd is the better of the two); frames `traveler_pick_inspect_alt_*` left in `out/ambient/` for the record only |
| A1 `traveler_axe_inspect` (px_axe_whet) | PASS-WITH-NOTE (tn: axe/hatchet, but mallet/hammer competes) | PASS-WITH-NOTE (on: frame 1 reads cloth/paper) | **WITHHELD** — the paper read is gone but a hammer read replaces it. Frames stay in `out/ambient/traveler_axe_inspect_f0..4.png` for a future round; do not integrate. |
| A1 alt (px_axe_whet2) | – (not staged: sickle head, floating stone) | – | **REJECTED** |
| A4 `traveler_stretch_side` | PASS-WITH-NOTE (yp: wave / flex / brow-wipe) | PASS-WITH-NOTE (ae: stretch / cheer) | **WITHHELD** — no better than the current; the T01 stretch stays as shipped |
| A4 alt px_stretch_fold | PASS-WITH-NOTE (bm: bow, headless mid-frames) | – | **REJECTED** |
| A5 px_plank_east / px_squats | PASS-WITH-NOTE (hv ≡ kr; fj shallow) | PASS-WITH-NOTE (kr) | **REJECTED** — neither clearly beats `traveler_pushups_side`; current stays |
| B `node_tin_seam` c1 | PASS-WITH-NOTE (qa: silver vein, but tile / riveted strap) | PASS-WITH-NOTE (ko: cookie) | **WITHHELD** — moved to `items/withheld/node_tin_seam_96.png`. The new one reads "silver/quartz vein in rock" — the ore cue T01 lacked — but trades the cookie read for a tile read. Obvious next step: one more pixen roll asking for an irregular outcrop with c1's seam treatment (1 gen). |
| B c2 | PASS-WITH-NOTE (em: sparkle symbols, stray marks) | – | **REJECTED** |
| C `icon_pine_plank` c2 | PASS-WITH-NOTE (vd: two boards); **collides with oak_handle in the grid** | PASS-WITH-NOTE (bq: tag/ruler) | **WITHHELD** — moved to `items/withheld/icon_pine_plank_48.png`; the new oak_handle collision is worse than the paper note. Current stays. |
| C `icon_pine_plank` c1 | PASS-WITH-NOTE (hz: crate/box) | – | **REJECTED** |
| C `icon_pine_log` c2 | **PASS** (ln), separable from oak_log in the grid | PASS (mj) but "near-collision" with oak_log | **ACCEPTED** — `out/items/icon_pine_log_48.png` replaces the shipped pine_log; oak_log untouched |
| C `icon_pine_log` c1 | – (blue resin, not staged) | – | **REJECTED** |
| D `skill_foraging` c1 | "much easier to make out at ×1 and ×2", reads leafy sprig (sr) | "nearly vanishes at ×1" (sz) | **ACCEPTED** — `out/items/skill_foraging_24.png`; the object read is unchanged (sprig), only contrast/mass changed. Caveat: 46 colours in 24×24 (pixen anti-aliasing) against the two-value construction line; one 4-connected component. If a two-value version is wanted it should come from PixelLab, not from a code reduction. |

Net: **3 accepted** (traveler_read, icon_pine_log, skill_foraging), **5 withheld** (axe, pick, stretch_side,
tin_seam, pine_plank — current assets stay; the withheld pick is recommended for a lead override),
**8 rejected**. Spend 16 of 60; 44 unspent. No target was rolled more than twice, per the brief.

## 7. INTEGRATION NOTES (for the lead)

**`Scripts/art/package-art.js`** — add a second ambient source after the T01 ambient block:

```js
const PX01 = path.join(EXPLORE, 'PLAYABLE_EXPANSION_01', 'out');
const AMBIENT_SRC_PX01 = path.join(PX01, 'ambient');
// PLAYABLE_EXPANSION_01/out/ambient/manifest.json — corrections that PASSED Visual QA at ×2.
// Same schema as the T01 manifest; every entry is 64×64 with the feet on row 62, so the
// 80-tall crop branch never applies. An id that also exists in T01 REPLACES it (traveler_read).
```
Iterate `AMBIENT_SRC_PX01/manifest.json` exactly like the T01 loop (size check, `emit('ambient/<id>_f<i>.png')`,
footprint on frame 0), **after** the T01 loop so `ambient/traveler_read_f0..8.png` and the
`ambient_traveler_read` footprint are overwritten (9 frames now, was 9 — no stale file). Read only
`manifest.json`; the other frames in `out/ambient/` (`traveler_axe_inspect_*`, `traveler_pick_inspect_*`,
`traveler_pick_inspect_alt_*`, `traveler_stretch_side_*`) are withheld/rejected and are listed only in
`withheld_manifest.json`.

Items — in the icon section, source `icon_pine_log_48.png` from `PLAYABLE_EXPANSION_01/out/items/`
instead of `PIXELLAB_STABILIZATION_01/out/icons_full/`, and `skill_foraging_24.png` from
`PLAYABLE_EXPANSION_01/out/items/` instead of `TRANSFORMATION_01/out/items/`. Same names, same sizes
(48 / 24), 0 semi-alpha, so the emitted asset paths do not change.

**`lib/ui/icons/ambient_assets.dart`** — `traveler_read` may now enter the rotation:

```dart
AmbientScene(
  id: 'read',
  traveler: AmbientTrack(
    frames: _frames('traveler_read', 9),
    fps: 6,
    loop: AmbientLoop.pingpong,
    repeats: 2,
  ),
  footprint: SpriteFootprints.ambientTravelerRead, // regenerated by package-art from the new f0
  // canvas 64 (default)
),
```
The open book spans x 1..61 of the 64 frame at its widest (f7–8), so any cat layer should sit at
|dx| ≥ 44 (`_catSitsAt(-44)`) or be omitted. Update the withheld-list doc comment: `traveler_read` is
corrected (PLAYABLE_EXPANSION_01/ambient/README.md, 2026-08-19); `traveler_axe_inspect` and
`traveler_pick_inspect` remain withheld. If the lead overrides on the pick (§6), the entry is
`frames: _frames('traveler_pick_inspect', 7), fps: 6, loop: AmbientLoop.pingpong`, canvas 64,
baseline 63 in the crouch frames; copy its entry from `withheld_manifest.json` into `manifest.json` and
re-run package-art.

`assets/art/v1/README.md` — add the PLAYABLE_EXPANSION_01 source line for `ambient/traveler_read_*`,
the pine_log item icon, and the foraging skill icon.

Nothing else is implied. Nothing was staged or committed by this agent.
