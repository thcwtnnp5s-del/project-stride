# PLAYABLE_POLISH_01 — art round

The art stream of the Playable Polish 01 pass (`MILESTONES/PLAYABLE_POLISH_01.md`).
Two items, both corrections of shipped work rather than new content.
PixelLab balance at the start: 1,940 generations; spent: 14.

## 1. Mining loop — re-authored (ACCEPTED)

**Fault.** The ACTIVITY_FEEL_01 mining loop (`mine2`) was generated on the
west-facing Traveler, but the strike landed **east** — behind the figure's
own back. The stage accommodated it (`worksEast`, PWRF01) by putting the seam
east, which made the pick touch the ore and made the whole scene read as a
man working with his back to the rock. The owner's device called it
"visually backward in-context", and the in-context harness
(`test/stage_evidence_test.dart`) confirms: beard left, pack right, seam
right, pick landing behind the pack.

**Fix.** `animate_character` v3 on the Traveler (`c82b7da5…`), west, 8
frames, custom start frame = `mine2_f0` (the held-pick pose), two
phrasings, 1 generation each:

| Group | Description | Verdict |
|---|---|---|
| `9bc84469` `mine3_strike_front_a` | "raises the pickaxe over the head … swings it down hard in FRONT … never behind his back" | **ACCEPTED** — pick low in front → raised → over the shoulder (anticipation) → strike low in front. Frame 5 (the head passing directly over the crown, reading as a halo) dropped at packaging. |
| `e70aad11` `mine3_strike_front_b` | "… rock chips fly at the point of impact …" | rejected — same arc with white swoosh arcs behind the shoulder that read as noise at ×2; frames not retained |

Ships as `ambient/activity_mine_f0..7` from `out/ambient/mine3a_f*.png`
(96 × 96 source; crop x 12, y 16, 60 × 64, feet on row 62). `worksEast` now
answers no for every profession and the seam sits west with every other
prop. In-context capture: `qa/stage_mine_after.png` beside
`qa/stage_mine_before.png`.

No frame repair for woodcutting, foraging, smithing, cooking or the combat
attack/hit was needed: each was re-captured in context this round and
faces and acts toward its target.

## 2. Ore seams — three materials, one structural language (ACCEPTED)

**Fault.** The three PWRF01 work props were one boulder with a vein patch
swapped; the copper streaks were still visible on the tin rock. "Same node
with a slightly altered pasted overlay" (owner).

**Method.** `create_image_pixen`, 96 × 96, `no_background`, side view,
single black outline, one shared prompt skeleton (a slate outcrop two-thirds
of a figure's height, loose stones at the base, muted palette) with only the
material clause changed. Three rounds, 12 generations; `out/props/`:

| File | Seed | Verdict |
|---|---|---|
| `seam_copper_s4101`, `seam_tin_s4101`, `seam_hardened_s4101` | 4101 | round 1 — materials distinct, but copper carried loud cyan oxidation edges and hardened glowed like lava rock |
| `seam_copper_s7720` | 7720 | **ACCEPTED copper** → `prop_copper_seam_96` |
| `seam_tin_s7720`, `seam_tin_s31` | 7720, 31 | rejected — both read as plain rock; the silver was only an edge highlight |
| `seam_hardened_s7720` | 7720 | rejected — glow again despite the "no glow" clause |
| `seam_hardened_s31` | 31 | **ACCEPTED hardened** → `prop_hardened_copper_seam_96` — darker, blockier, thick dull bronze bands, jutting crystals, no glow |
| `seam_copper_s31` | 31 | rejected — browner rock, less clean than 7720 |
| `seam_tin3_s7720` | 7720 | **ACCEPTED tin** → `prop_tin_seam_96` — wide pale silver bands in darker slate, unmistakably not copper |
| `seam_tin3_s4101`, `seam_tin3_s9001` | 4101, 9001 | rejected — round nuggets read as water droplets / a cobbled ball |

Pixen lesson for the record: "veins of tin" gets edge highlights; "WIDE
SHINY bands … much lighter than the rock" gets a readable metal.

In-context capture of the three seams: `qa/stage_seams_after.png`.

Woodcutting and foraging props were reviewed at the same time and left
alone: the oak stump with chips, the meadow patch with basket, and the
duskcap ring are already distinct at a glance.
