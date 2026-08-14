# Template — Eight-Direction Character Sheet

A reusable production spec for generating a character's eight directional views
as a single sheet.

## Provenance

- **Owner-provided requirement.**
- **Introduced 2026-08-13**, during planning for Visual Exploration 01.
- **Did not previously exist in the repository.** It is not a conversion or
  restatement of an earlier document; it was authored from the owner's stated
  requirement.
- **Currently an exploration template, not a locked art-style decision.** It
  defines *layout and orientation*, which are style-independent. Everything
  style-specific is parameterized below and stays unresolved until
  `GAME_BIBLE/ART/ART_DIRECTION.md` leaves EXPLORATION status.

---

## Layout

A **3×3 grid**. The **centre cell is empty.** Eight cells, eight views.

Every view faces **outward** — away from the centre, in the direction its cell
sits relative to the middle. The sheet reads as a character turning on the spot,
and the grid position *is* the facing.

```
┌─────────────┬─────────────┬─────────────┐
│  back-left  │    back     │ back-right  │
│  diagonal   │             │  diagonal   │
├─────────────┼─────────────┼─────────────┤
│  left side  │   (empty)   │ right side  │
├─────────────┼─────────────┼─────────────┤
│ front-left  │    front    │ front-right │
│  diagonal   │             │  diagonal   │
└─────────────┴─────────────┴─────────────┘
```

## Directional mapping

Exact and not to be reinterpreted:

| Cell | View | Facing |
|---|---|---|
| **top-left** | back-left diagonal | outward toward upper-left |
| **top-center** | back | outward toward top |
| **top-right** | back-right diagonal | outward toward upper-right |
| **middle-left** | left side | outward toward left |
| **center** | *empty* | — |
| **middle-right** | right side | outward toward right |
| **bottom-left** | front-left diagonal | outward toward lower-left |
| **bottom-center** | front | outward toward bottom |
| **bottom-right** | front-right diagonal | outward toward lower-right |

Top row is **back**. Middle row is **side**. Bottom row is **front**.

---

## Requirements

### Views

- **Exactly 8 views.** Not seven, not nine, and the centre stays empty.
- **Full body** in every view — no crops, no bust shots, no cut-off feet.
- **True diagonal rotations.** The four diagonals are genuinely rotated views of
  the character, not a front or side view nudged or skewed.
- **No mirrored or duplicated directions.** Left and right are drawn
  independently. Mirroring is the shortcut this spec exists to forbid: it flips
  asymmetric equipment, parts, and details to the wrong side.

### Identity

- **The exact same character in all eight views.** One individual, rotated —
  not eight interpretations of a description.
- **Consistent proportions, colours, equipment, and silhouette** across every
  view. A detail visible in one view must be present and correctly placed in the
  others where it would be visible.

### Presentation

- **Transparent or plain background.** No scenery, ground plane, shadow plate,
  or environment.
- **No text, labels, arrows, captions, watermarks, grid lines, or UI** anywhere
  on the sheet.

---

## Parameters — resolved per art direction

Deliberately unset. These come from `GAME_BIBLE/ART/ART_DIRECTION.md` once a
direction is locked, and **must not be invented** to complete a request:

| Parameter | Value |
|---|---|
| `{{ART_DIRECTION}}` | UNRESOLVED — candidate A, B, or C |
| `{{RESOLUTION}}` | UNRESOLVED — per-view pixel dimensions |
| `{{PALETTE}}` | UNRESOLVED |
| `{{CAMERA_ANGLE}}` | UNRESOLVED — governs what "side" and "diagonal" look like |
| `{{PROPORTIONS}}` | UNRESOLVED — head-to-body ratio and figure style |
| `{{RENDERING_TREATMENT}}` | UNRESOLVED — outlining, shading, dithering |
| `{{CHARACTER_SUBJECT}}` | Per request — e.g. the player character in starter Traveler gear |
| `{{EQUIPMENT}}` | Per request — must match `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md` |

During exploration, a comparison may supply provisional values for the
unresolved rows to make a candidate renderable. **Those remain provisional.**
A value used in an exploration image has not been chosen, and does not become
the project's value by appearing in one.

---

## Usage note

Layout and orientation above are **fixed and style-independent** — they hold
whichever direction wins. Only the parameter table changes when the art
direction locks, which is what makes this template reusable across all three
candidates and beyond them.
