# WORLD_REWARD_DEPTH_01 — combat stream (workstream G, part 2)

```
STATUS: round record · the Frostmere enemy, its backdrop, and one reward effect · NOT CANON
Author: PixelLab ambient/combat correction agent (workstream G), 2026-08-19.
Nothing here is committed, staged, or written to assets/, lib/, Scripts/ — the lead integrates.
QA VERDICT is written by an independent Visual QA agent (MISTAKES.md M-04); AUTHOR ASSESSMENT below it is mine.
```

Governed by `MILESTONES/WORLD_REWARD_DEPTH_01.md` §5 (`enemy.frost_lynx` at `location.frostmere`) ·
`../../PLAYABLE_EXPANSION_01/combat/README.md` §1 (the shared visual language for the stage, reused
unchanged) · `RULES.md` A-1/A-2 · `MISTAKES.md` M-04/M-05 · `NEUTRAL_STAGING_CHECKLIST.md`.

## 1. Character id

> **Stride Frost Lynx `d7477134-0834-4322-a3b5-c01caec4045b`**
> (standard mode, quadruped `cat` template, `side` view, 4 directions, size 40 → **56 canvas**;
> west rotation 38 × 27 px. Medium shading, single-colour black outline, high detail.)

Four earlier lynx characters were generated and **not used** — keep them or delete them, they are
not referenced by anything:
`d2e1b9e2-7642-47b4-9d34-d56bff7c8326` (c1, cat, medium detail — a pink house cat) ·
`d3675e04-220e-405b-9b17-c3cfa5569556` (c2, lion — a cream house cat) ·
`03966fe2-08ed-4c6f-afdf-890def41764f` (c4, lion, high detail — a brown striped wildcat) ·
`f6fb7fae-8567-4964-9edc-73175cce30e4` (c5, cat, high detail — a white cat).

Animation groups on the used character (all west):
`lynx_idle_west` cf9a11be · `lynx_attack_west` 4fad41b7 · `lynx_hit_west` 345143dd ·
`lynx_defeat_west` 66bab71a.

Images: `create_image_pixen` backdrops abdfeae9 (c1, not used), **4aba4329 (c2, used)**;
reward effect pixen 16da4855 (c1, rejected), 9355da68 (c2) → `animate_image` 06f6154f (rejected).

## 2. Spend

From the tools' own cost lines (account shared with the concurrent world-art stream E — balance
deltas are not this agent's spend).

| Target | Tool | Calls | Gens |
|---|---|---|---|
| Frost Lynx characters c1, c2, c3, c4, c5 | `create_character` standard, quadruped, side, 40 | 5 | 5 |
| Frost Lynx c3 v3 (rejected by the API: v3 has no quadruped mode) | `create_character` v3 | 1 | 0 |
| Lynx west animations: idle, attack, hit, defeat | `animate_character` v3, west, keep_first_frame | 4 | 4 |
| `backdrop_frostmere` c1, c2 | `create_image_pixen` 192 × 96 opaque | 2 | 2 |
| `fx_reward_burst` source c1, c2 | `create_image_pixen` 32 × 32 transparent | 2 | 2 |
| `fx_reward_burst` animation | `animate_image` 32 × 32, 6 f | 1 | 1 |
| **combat subtotal** | | **15** | **14** |

Workstream total across ambient (9), combat (14) and items (6): **29 of the 70 budget.**

## 3. Method

- The lynx follows the wolf's method exactly (`PLAYABLE_EXPANSION_01/combat` §2): `create_character`
  standard with a quadruped template, `side` camera, size 40 → 56 canvas, then `animate_character`
  mode `v3` with `keep_first_frame=true` so **frame 0 of every track is the west rotation pose** —
  one shared anchor across idle, attack, hit and defeat.
- v3 output canvas is 68 × 68 (56 + 12 padding); packaging crops at **(6, 6) → 56 × 56**, matching
  the wolf's and goblin's canvas. Standing baseline **row 39**.
- Palette: nearest-colour remap ≤ 48 to the lynx's own west rotation palette (the same
  per-figure rule PE01 used). Only 29–69 pixels per sequence were more than 0 from a rotation
  colour; 4–7 colours per sequence sit beyond 48 and were kept.
- Backdrop: `create_image_pixen` 192 × 96 opaque, then nearest-colour remap to the location
  vignette `assets/art/v1/location/frostmere.png` (mean distance before remap **10.5**, **0**
  pixels beyond 48 — the pixen palette was already within the vignette's range).
- **Teal check** (`#58d6c0` ± 12, the banned colour): **0 hits** in every frame and the backdrop.
- **0 semi-transparent pixels** in every figure frame; the alpha quantiser never fired.
  **0 clipped frames.**
- Nothing was hand-drawn or pixel-edited (`RULES.md` A-2).

## 4. Round log

### 4.1 The lynx — five characters before one read

All five used the same size, camera and template family; only the description changed. Judged at
×6 beside the shipped `wolf_idle_f0` (`qa/_lynx_all_x6.png`) and then **on the actual snow
backdrop at ×2 beside the Traveler** (`qa/_ctx_lynx_all.png`), which is what decided it.

| # | template / style | result | verdict |
|---|---|---|---|
| c1 | cat, medium detail, basic shading | a plain pink-white domestic cat: no ear tufts, no markings, no ruff, long tail, maroon outline | **rejected** |
| c2 | lion, medium detail, basic shading | longer and heavier but still a cream house cat, no tufts, long tail | **rejected** |
| **c3** | **cat, high detail, medium shading** | **a smoky charcoal-grey wild cat with a cream throat and belly, dark muzzle bars, visible upright ear tufts, yellow eye, dark outline, strong flat shading** | **chosen** |
| c4 | lion, high detail, medium shading | a warm brown striped wildcat, no tufts, long thin curled tail; silhouette very close to the wolf's | rejected |
| c5 | cat, high detail, medium shading, "pale silver-white winter coat" | a white cat — and on the snow backdrop at ×2 **it very nearly disappears** | **rejected on evidence** |

**Deviation from the brief, stated out loud.** The brief asked for a "pale grey-white coat with
faint darker markings". c5 is that animal, and `qa/_ctx_lynx_all.png` shows why it cannot ship: a
pale figure on a pale snowfield has no silhouette at ×2, which is the same class of failure as
M-05. c3 is a **mid-to-dark grey with a cream throat and belly** — still a grey lynx, but with the
value contrast the snow demands. Both are staged blind so QA judges the pictures, not the words. If
the lead wants the pale coat, the backdrop has to get darker; that is a design call, not an art
fix.

Prompt for c3 (verbatim): "a wild lynx standing in profile: smoky grey-brown back and flanks barred
with dark charcoal stripes and spots, a bright cream throat ruff and pale cream belly, dark charcoal
muzzle bars and brows, tall ears each topped by an upright black tuft of hair, a short stubby tail
with a black tip, long thick legs and heavy paws, compact powerful body, strong dark outline, flat
matte shading with clear light and dark steps, warm earthy muted palette"

### 4.2 Lynx animations (verbatim action descriptions, all `directions=["west"]`)

- `lynx_idle` (cf9a11be, 6 f + rotation): "standing on all four feet in profile, alert and
  breathing: the ribcage rises and falls, the shoulders settle, the tail sways and flicks slowly,
  the head lifts and turns a few degrees and comes back, the paws stay planted in the same place,
  ending in the same standing pose it began in"
  → a small, stable breathing idle; the paws do stay put. Same near-imperceptibility QA noted on
  the shipped wolf idle. **Packaged.**
- `lynx_attack` (4fad41b7, 8 f + rotation): "a quick pouncing swipe in profile: crouching back low
  on its haunches, then rearing up and lashing out with one front paw, claws out and jaws open, and
  dropping straight back down onto all four feet in the very same spot, ending in the standing pose
  it began in, the body never travelling forward across the ground"
  → f2–f5 crouch low with the jaws open, f6–f8 extend forward into the pounce. The "no travel"
  instruction was **not** obeyed: the body advances ≈ 10 px toward the Traveler and stays there at
  f8 (bounds left 3 vs the idle's 10). The shipped `wolf_attack` travels 3 px, so this is a
  difference of degree. **Packaged** with the travel recorded in the manifest note — the stage
  returns to `lynx_idle` after a `once` play, so the figure snaps back.
- `lynx_hit` (345143dd, 6 f + rotation): "struck by a blow in profile: the whole body flinches
  sharply backward and down, the head twists away and the ears flatten, the front paws skid back a
  little, then it braces and pushes back up onto all four feet in its standing pose, the paws never
  leaving the same patch of ground"
  → at ×2 it reads as a **crouching prowl or a slow stalk**, not a flinch — the same failure the
  wolf's hit had across three rounds in PE01. **Author withholds** after one round rather than
  spending three more on a known-hard shape; PE01's answer (`fx_impact` at the enemy plus a UI-side
  recoil offset) already exists and covers the lynx.
- `lynx_defeat` (66bab71a, 6 f + rotation): "beaten and sinking down in profile: the legs buckle and
  fold under the body, the shoulders drop, the head lowers all the way to the ground, and it comes
  to rest lying still on its side with the legs tucked, not moving again"
  → stands, flattens, and lies still from f4. Clear at ×2. **Packaged.**

### 4.3 `backdrop_frostmere`

- c1 (pixen abdfeae9, seed 3101): a snowfield behind a **band of boulders running the full width**,
  with small pines standing in the bottom band where the fighters go. The boulder band reads as a
  stone wall across the stage. **Rejected.**
- **c2** (pixen 4aba4329, seed 3102), verbatim: "a wide alpine snowfield battleground seen from eye
  level: the whole bottom third is one flat unbroken sheet of pale blue-white snow with no rocks and
  no bushes on it, behind it a low soft bank of drifted snow, then a row of dark green snow-laden
  pine trees across the middle with two grey boulders half buried among them, a distant ridge of
  pale grey-blue mountains, and a cold pale sky band at the top — pixel art game battle backdrop,
  flat matte shading in a few clear steps, light from the upper left, muted cold limited palette,
  no figures, no people, no animals, no text, no glow"
  → an unbroken flat snow band across the lower third, frost pines and one boulder mid-ground, a
  ridge, a cold sky band. Same composition rules as `backdrop_forest`: figures stand on **ground
  row 88** with plain ground under them. **Chosen.**

### 4.4 `fx_reward_burst` — withheld

- c1 (pixen 16da4855, seed 4101): "a small soft pale burst of light: a compact warm off-white core
  with four short tapering rays and a few small pale gold specks around it …" → the tapering rays
  came out as four little **blades**; reads as a shuriken or crossed swords. **Rejected.**
- c2 (pixen 9355da68, seed 4102): "a small tight cluster of soft pale sparkles: one round soft
  cream-white dot in the middle with six or seven tiny pale cream specks scattered close around it,
  nothing else … no rays, no blades, no star shape, no coin, no explosion …" → a soft cream disc
  ringed by specks. Usable as a still, but the disc already reads as a **pearl**.
- animation (06f6154f), action verbatim: "the light bursting outward and fading: the pale specks fly
  out away from the centre in all directions and thin away to nothing, while the soft centre spreads
  outward, breaks up and dims until the frame is almost empty"
  → the model did the opposite: the centre disc **grows and stays solid**, and by f4–f6 it is a
  lumpy brown-grey stone. At ×8 (`qa/_burst_anim_x8.png`) the sequence reads as a **coin or an egg
  getting dirty**. That is exactly the failure the brief said to withhold on.

**Disposition: WITHHELD**, at the brief's two-attempt limit (two pixen sources plus one animate).
Not packaged into `out/combat/`; the frames stay in `candidates/fx_reward_burst/` and are staged
blind so QA can confirm the read independently. If the lead still wants a reward flourish, the
useful next step is *not* another `create_image_pixen` roll — pixen keeps drawing the noun. A UI-side
scale-and-fade of the item icon itself would be a deterministic presentation of a durable fact
(`RULES.md` A-2), and needs no art at all.

## 5. Delivered (`out/combat/manifest.json` is the contract)

`anchor` = the standing baseline row that sits on the backdrop's `groundRow`.
`baseline` = the lowest opaque row of the sequence.

| id | kind | frames | fps | loop | canvas | anchor | bounds | status |
|---|---|---|---|---|---|---|---|---|
| `lynx_idle` | enemy.frost_lynx | 7 | 6 | pingpong | 56 | 39 | 10,13..51,39 | packaged, awaiting QA |
| `lynx_attack` | enemy.frost_lynx | 9 | 10 | once | 56 | 39 | 3,13..52,39 | packaged, awaiting QA |
| `lynx_hit` | enemy.frost_lynx | 7 | 10 | once | 56 | 39 | 8,13..51,39 | **author withholds** |
| `lynx_defeat` | enemy.frost_lynx | 7 | 8 | once | 56 | 39 | 5,13..51,40 | packaged, awaiting QA |
| `backdrop_frostmere` | backdrop | 1 | – | static | 192 × 96 | groundRow 88 | – | packaged, awaiting QA |
| `fx_reward_burst` | effect | – | – | – | 32 | – | – | **withheld, not packaged** |

QA material: `qa/combat_sheet_x{1,2,8}.png` (one row per sequence), `qa/_lynx_anim_x2.png`
(390-wide ×2 phone composite — the verdict view), `qa/combat_context_x2.png` and
`qa/combat_context2_x2.png` (Traveler east + lynx west on the backdrop at ×2: idle pair, pounce,
the Traveler's swing against the lynx flinch, and the lynx down), `qa/_lynx_all_x6.png` (the five
characters beside the shipped wolf), `qa/_ctx_lynx_all.png` (the contrast evidence),
`qa/_burst_anim_x8.png`.

## 6. Neutral staging

Blind set: **`p2w6/`** (30 files, opaque shuffled codes, no text, no chrome). Key:
`tools/BLIND_KEY.txt`, outside the staged folder. Sequence codes carry `_a` native, `_b` ×2,
`_c` ×8; codes ending `_p` are single ×2 scene plates. Distractors: the CURRENT shipped `wolf_idle`,
`wolf_attack`, `wolf_defeat`, a `backdrop_forest` scene plate and an empty `backdrop_forest`.

STAGING CHECK: A1 ✓ · A2 (`_a.._c` are scale labels, `_p` is presentation — say so to the reviewer)
✓ · A3 opaque dir ✓ · A4 shuffled by fixed permutation ✓ · A5 ✓ · A6 native / ×2 / ×8 / in-context ✓ ·
B1 no baked text ✓ · B2 no UI chrome — the plates are backdrop and figures only, no bars, no
numbers ✓ · B3 no labelled sheet inside `p2w6/` ✓ · D1 key outside ✓ · D4 same known limit as the
ambient stream. **STAGING CHECK: PASS**

## 7. AUTHOR ASSESSMENT

What I believe holds at ×2 (`qa/combat_context_x2.png`):

- **The lynx reads as a wild cat and not as the wolf.** Different value (grey with a cream throat
  against the wolf's near-black with a cream ruff), different head shape, ear tufts, shorter body.
  It stands at the same waist height as the wolf, which keeps the region's first fight honest.
- **`lynx_attack`** — the crouch into an open-jawed forward pounce is the clearest of the four
  sequences. My doubt is the travel: the animal ends 10 px forward of where it started and the
  stage has to snap it back when the track finishes.
- **`lynx_defeat`** — lying flat in the snow is unambiguous, and the last three frames are a stable
  hold.
- **`backdrop_frostmere`** — flat snow where the fighters stand, a treeline that is not busy behind
  them, and it is palette-conformed to the Frostmere vignette so travelling into a fight there does
  not change the region's colour. My doubt: there is a hard horizontal ice edge at about row 60 that
  passes behind both figures' heads.

What I doubt hardest: **`lynx_idle` may be imperceptible** — the same note QA gave the wolf idle —
and **`lynx_hit` does not read as a flinch**, which is why I withhold it.

What I do not put forward: lynx characters c1, c2, c4, c5; `backdrop_frostmere` c1;
`fx_reward_burst` in any of its three forms.

## 8. QA VERDICT (independent Visual QA)

_(to be filled by an independent Visual QA agent working from `p2w6/`; the author does not
self-certify — `MISTAKES.md` M-04)_

**QA VERDICT:** (blind, independent, 2026-08-19; reviewer read no README/key; the set was staged with the CURRENT shipped art as distractors)

Per candidate (blind codes → key in tools/BLIND_KEY.txt):
- **rn = NEW lynx_idle** — "grey, pointy-eared, long-tailed quadruped facing left, head lowering into a crouch; at ×2 a grey cat stalking (a player might say lynx); ends crouched, no return." **PASS-WITH-NOTE** (pingpong in the table).
- **gt = NEW lynx_attack** — "crouches, gathers, stretches full length leftward, foreleg extended, mouth open: a cat pouncing/swiping. Strong, legible at ×1 and ×2." **PASS.**
- **fk = lynx_hit (author withheld)** — "creeping then looking at you; purpose ambiguous." **PASS-WITH-NOTE** — stays withheld.
- **mu = NEW lynx_defeat** — "flattens progressively until prone; legible as a downed animal; no jump." **PASS.** Preferred over the shipped wolf_defeat (lo) which "pops" at 4→5.
- **va = fx_reward_burst (author withheld)** — "emissive glow / coin-like disc; final frame an unidentifiable blob." **FAIL** (MAJOR B) — not packaged.
- Plates: **tq_p (NEW backdrop_frostmere, empty)** reads as a snowfield with pines and mountains; **ze_p / ah_p / ci_p (lynx idle / attack / defeat on the frostmere plate)** — cat reads clearly, dark on pale — **PASS**; **ob_p (CURRENT wolf on the forest plate, distractor)** — "dark dog-shaped patch; legs merge into ground, back into trunk" — **PASS-WITH-NOTE (MAJOR-leaning B)**, a pre-existing cosmetic issue recorded in the milestone.
- Shipped distractors: dy wolf_idle PASS-WITH-NOTE (weak loop seam), xi wolf_attack PASS ("best loop in the set"), lo wolf_defeat PASS-WITH-NOTE (missing in-between 4→5).

Set verdict as written: **FAIL** (va fails; ob_p needs separation; gt, xi, mu pass clean; rn, fk, dy, lo pass-with-note; prefer gt over fk, mu over lo).

### Lead's disposition (2026-08-19)
Accepted and promoted: **lynx_idle, lynx_attack, lynx_defeat, backdrop_frostmere**. Withheld: lynx_hit (the stage recoils the figure + fx_impact, as for the wolf). Rejected: fx_reward_burst (the victory panel uses a deterministic icon scale-and-fade instead — A-2). The wolf-on-forest contrast note is recorded under known cosmetic issues.
