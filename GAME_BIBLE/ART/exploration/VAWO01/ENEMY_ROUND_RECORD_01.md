# VAWO01 — Enemy Silhouette Round 01

**Date:** 2026-09-02
**Generations:** 9 (2 rejected characters, 4 stills, 3 animations + 1 re-roll).
**Owner instruction served:** *"69.5 % wolf/lynx overlap is too high. Review
every enemy at card and combat size; improve silhouette/scale/idle/attack/
hit/defeat/regional identity; don't regenerate already-good enemies."*

---

## 1. The measurement, and what it actually found

Two numbers, because they answer different questions.

**Shape-normalised IoU** (each sprite scaled into a common 32² box, so only the
*outline* is compared) puts eight pairs above 69 %, led by boar/bear at 76.2 %.
That measure is misleading on its own: it deliberately throws away scale, and
scale is half of how the player tells a bear from a boar.

**In-place silhouette IoU** (the sprites as the stage actually draws them) is
the honest figure, and it exonerates almost the whole roster. Rendered at the
stage's own ×2 and looked at (`review/enemies_stage_x2.png`), boar, ram, bear,
goblin, crawler, salamander and guardian each read as themselves immediately.

**Exactly one pair failed: wolf and lynx.**

| Measure | Wolf vs lynx |
|---|---:|
| In-place silhouette IoU | **74.0 %** |
| Alpha mask agreement across the canvas | **95.3 %** |
| Shared opaque pixels that are the same colour | 0.5 % |

That last row matters: this was **not** a recolour. They were drawn twice, and
came out the same animal.

So the round did what the owner asked and no more — one enemy re-authored,
eight left alone.

## 2. Why they converged

It is in the previous round's own record. `WORLD_REWARD_DEPTH_01/combat/
README.md` §2: the lynx *"follows the wolf's method exactly"* — same
`create_character` standard mode, same quadruped template family, same `side`
camera, same size 40 → 56 canvas. And its accepted Visual QA note describes the
result as a *"grey, pointy-eared, **long-tailed** quadruped"*, which is
precisely the silhouette a lynx does not have.

Same pipeline, same parameters, same species. The convergence was designed in.

## 3. What was tried, and what worked

| Attempt | Result |
|---|---|
| `create_character` standard, `cat` template, lynx cues in the description | A flat **white house cat**. No tufts, no bobbed tail, long tail, off-palette |
| `create_character` standard, `lion` template, stronger cues | Near-identical white house cat |
| `create_image_pixen` 56², "frost lynx" with full cue list | Unmistakably a lynx — but ¾ front-facing and roughly twice the roster's scale |
| `create_image_pixen` **48 × 32**, "exact flat side profile" | **Accepted.** Strict profile, correct scale |

The finding, which is the reusable part: **standard quadruped mode is
template-dominated and ignores descriptive silhouette cues**, and v3 has no
quadruped mode at all (the previous round recorded the API rejecting it). When
a creature's *shape* is the defect, the character rig is the wrong tool — a
freeform still plus `animate_image` is the route that gives silhouette control.

The low, wide canvas did the rest of the work: at 56² the model drew a portrait;
at 48 × 32 it had nowhere to put a ¾ view and drew a profile.

## 4. The accepted lynx

Cues a wolf cannot have, all present: two tall black ear tufts, a stump tail, a
flared cheek ruff, long legs, and a spotted tan coat against the wolf's grey.

| Track | Frames | Source |
|---|---:|---|
| `lynx_idle` | 7 | `animate_image`, breathing and settling in place |
| `lynx_attack` | 9 | `animate_image`, second roll — crouch, then stretch forward low |
| `lynx_defeat` | 7 | `animate_image`, legs buckle, sinks to the belly, holds |

Frame counts are **unchanged** from the shipped tracks (7 / 9 / 7), so nothing
downstream moved: the canvas is still 56², the anchor row still 39, and
`lynx_hit` stays withheld.

### Result

| | Before | After |
|---|---:|---:|
| Wolf vs lynx, in-place IoU | 74.0 % | **51.1 %** |

Evidence: `review/enemies_stage_after_x2.png` — the whole roster at stage scale.

## 5. Deterministic placement (`RULES.md` A-2)

The frames are authored 48 × 32 and the roster's canvas is 56² with the
standing baseline on row 39. Each track is padded by **one offset computed from
its own frame 0**, never per frame: a per-frame re-centring would iron the
animation flat. Verified after padding — every track's frame 0 sits at
`8,10..49,39`, against the shipped lynx's `10,13..51,39`. Nothing was cropped,
scaled, recoloured or drawn.

## 6. The known limit, recorded rather than faked

The previous lynx attack travelled **~10 px** toward the Traveler. The
re-authored one travels **3 px** (the first roll managed 1). `animate_image`
animates largely in place, and two prompts explicitly demanding a long leap did
not change that — it is a property of the tool, not of the wording.

The strip still reads as a strike: the body lowers and stretches, the jaws
open, `fx_bite` fires at the Traveler and the stage recoils him. `strikeFrame`
was re-measured from the new frames (leftmost reach 8 7 7 6 6 6 7 5 5) and moved
from 6 to **7**, so the blow lands on the furthest extension with one frame of
follow-through.

**This was not corrected with a per-frame translation.** Baking travel into the
frames would be motion the artist never authored, and the contact shadow — taken
from frame 0 — would stay behind while the body slid out of it. The honest state
is a stalking strike and a recorded limitation.

## 7. What was deliberately not touched

Eight enemies. The owner's instruction included *"don't regenerate already-good
enemies"*, and the in-place measurement plus the stage-scale read agreed that
boar, ram, bear, goblin, crawler, salamander and guardian are already distinct.
Regenerating them would have spent generations to make the roster *different*
rather than *better*, and risked losing art that passed blind QA.
