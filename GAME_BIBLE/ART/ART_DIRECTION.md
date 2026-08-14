# Art Direction

**Status: EXPLORATION — no production art direction is chosen.**

Nothing in this document is a locked visual decision. It records the intent that
is settled, the candidates that are not, and the properties that must stay
undecided until a direction is compared and chosen.

An agent reading this file for a value it does not contain must **stop and ask**
rather than infer one. See `RULES.md` G-3.

---

## Current design intent

Settled enough to constrain the exploration:

- **2D-first**
- **Pixel-art leaning**
- **Not restricted to literal 8-bit limitations** — historical hardware
  constraints are not a design goal
- **Mobile readability is critical** — the phone is the only target, and a
  sprite that reads on a desktop monitor may not read in a hand
- **Strong silhouettes** — readable at small size, in motion, and against busy
  backgrounds
- **MMO-inspired world and progression feel**
- **Modern polish is allowed** — lighting, effects, and finish are not capped by
  the pixel-art idiom
- **AI-assisted asset production is acceptable**
- **Consistency and a style guide outrank one-off visual novelty** — a
  beautiful asset that does not match the set is a defect

---

## Candidate directions

Three deliberately distinct treatments. **None is preferred, and none is
eliminated.**

### A — Classic Pixel MMO Lite

The traditional pixel MMO register: readable, familiar, economical to produce,
and honest about being a sprite game.

### B — Modern Premium Pixel Fantasy

Pixel foundations with contemporary finish — richer lighting, more animation
weight, higher effective detail while keeping the pixel identity.

### C — Stylized 2D Fantasy

Illustrative rather than pixel-based. Shapes, linework, and colour do the work
that pixel density does in A and B.

---

## Exploration rule

> **For major visual systems, compare 2–3 deliberately distinct treatments
> before locking a production direction.**

"Deliberately distinct" is the operative phrase: three variations on one idea
compare nothing. The candidates must be far enough apart that choosing between
them is a real decision.

Comparisons must hold **subject and composition constant** so the comparison is
about art direction rather than about which image happened to be better staged.
The canonical comparison scene for the first exploration is defined in
`PROJECT_STATE.md` under *Project Stride Visual Exploration 01*.

---

## UNRESOLVED — do not decide silently

None of the following has been chosen. They are listed so their absence reads
as **deliberate** rather than as an oversight to be helpfully filled in:

- **Palette** — no colours, ramps, or restrictions are set
- **Sprite dimensions** — no character, tile, or icon size is set
- **Camera angle** — top-down, three-quarter, side-on, and orthographic are all
  still open
- **Animation frame counts** — no frame budget per action is set
- **Exact rendering treatment** — outlining, dithering, shading model, and
  lighting approach are all open
- **Exact character proportions** — no head-to-body ratio or figure style is set
- **Final UI visual language** — HUD, panels, iconography, and typography are
  open; `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md` governs UX structure, not
  visual style

A candidate direction may *propose* values for these during exploration. A
proposal inside a comparison is not a decision, and does not become one by being
the only one written down.

---

## Related

- `GAME_BIBLE/ART/templates/EIGHT_DIRECTION_CHARACTER.md` — the reusable
  character-view production template
- `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md` — UX structure and navigation
- `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md` — the subjects the first
  comparison depicts
- `PROJECT_STATE.md` — Visual Exploration 01 scope and canonical scene
