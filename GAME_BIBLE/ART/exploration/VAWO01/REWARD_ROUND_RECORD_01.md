# VAWO01 — Reward & XP Round 01

**Date:** 2026-09-02
**Generations:** 13 (10 accepted, 3 re-rolled). Running VAWO01 total 226.
**Owner instruction served:** *"EXP emblem, skill XP mark, level-up plate,
milestone badge, profession XP marker, bonus-yield emblem, contract seal,
project seal, knowledge mark, rarity-aware result frame… Crafting a Bronze
Sword must visually feel more significant than Herb Broth without becoming
casino-like."*

---

## 1. The problem, stated from the card's side

The universal result card — the surface every gather, craft and contract
completion passes through — carried no authored art of its own. It drew an item
icon, three lines of type, and a border that got 1 px wider and changed colour
when the result was notable. **Crafting a Bronze Sword and cooking Herb Broth
were the same picture with different words.**

## 2. The ten marks

Both canvases are the icon families' existing conventions, so a mark keeps the
same logical footprint in every row it appears in.

| Asset | Native | Draws | What it marks |
|---|---:|---:|---|
| `mark_exp` | 24² | ×1 | Experience gained |
| `mark_skill_xp` | 24² | ×1 | A skill's own progress |
| `mark_bonus_yield` | 24² | ×1 | A yield bonus procced |
| `mark_knowledge` | 24² | ×1 | Something learned |
| `ornament_corner` | 32² | ×1 | The bracket a notable result wears |
| `plate_level_up` | 48² | ×1 | A level gained |
| `badge_milestone` | 48² | ×1 | A milestone reached |
| `marker_profession` | 48² | ×1 | A profession advanced |
| `seal_contract` | 48² | ×1 | A contract closed |
| `seal_project` | 48² | ×1 | A project completed |

## 3. The escalation is material, not motion

This is the whole answer to "significant without casino-like". A common result
keeps the plain card. A **notable** one — a bonus proc, or Uncommon and up —
gains its rarity's ink and a bronze corner bracket at two corners. Nothing
flashes, nothing counts up, nothing spins, and no new sound was added.

Evidence: `review/reward/result_compare_x2.png`, the two cards the owner named,
at the width they occupy on a phone.

## 4. Where each mark landed

Wired at the **one** place each fact passes through, never at call sites:

- `ActivityResultCard` — `mark_exp` on the XP line, `mark_bonus_yield` on the
  bonus line, two rotated `ornament_corner` brackets when notable. One card,
  every completion in the game.
- `LevelUpBeat` — `plate_level_up` in the leading-icon slot `RewardBeat`
  already had. Every level-up in the game routes through this beat, so the
  mark lands once rather than at each site that raises one.
- `RewardLayer` — a new optional `emblem`, centred above the beats.
  `board_card.dart` passes `seal_contract` on a closed contract and
  `seal_project` on a **completed** project only; a completed stage is
  progress, and stamping it would spend the mark before the moment it names.

`mark_skill_xp`, `mark_knowledge`, `badge_milestone` and `marker_profession`
are packaged and named but **not yet placed** — the surfaces they belong to
(the skills ledger, the knowledge track, the milestone and profession payoffs)
are not part of this round's wiring. They are recorded here as authored and
unplaced rather than quietly shipped somewhere they do not mean anything.

## 5. The corner bracket, and why it is an ornament

`DECISIONS/0029` permits a raster in a panel's outer **edge**, as a tiled
**surface**, or as **a discrete ornament Flutter positions**. The frame batch
(§7) failed to produce a nine-patch worth shipping, so the ornament is the
sanctioned mechanism that was left — and it turned out to be the better fit
anyway: it carries no word, number, state or measured boundary, and it is drawn
inside the card's own bounds so it can never sit under type or be clipped by a
tight parent.

**One asset, two corners.** `RotatedBox` turns the authored top-left bracket
into the bottom-right one. A transform of a drawing, never four drawings
(`RULES.md` A-2).

## 6. Deterministic preparation and rejections

Three of the first ten were re-rolled:

| Asset | Defect | Fix |
|---|---|---|
| `ornament_corner` | A thin filigree that read as a scratch, not an ornament | Re-rolled bolder at 32² |
| `badge_milestone` | Teal-and-orange banding on the rim; muddy | Re-rolled single-metal |
| `seal_contract` | Bright magenta wax, off-palette | Re-rolled deep oxblood |

The accepted ornament came back on an **opaque white ground**. Keyed by
flooding near-white inward from the far corner, then cropped to the bracket:
596 px removed, nothing drawn (A-2). Every other asset shipped as generated —
no crop, no clamp, zero semi-transparent pixels.

## 7. What this round did NOT land: the frame family (batches C–I)

Attempted and **rejected**, honestly recorded rather than shipped:

**13 generations across three rounds, zero accepted.** The goal was
distinct-but-related nine-patch frames for `heroPlate`, `modalFrame`,
`kitTray`, `combatFrame` and `boardSlip`, so the roles differ by band and
treatment rather than all wearing `chassis_64`.

- **Round 1** asked for five *materials* (wood, iron, bronze, leather) and got
  five different games — precisely the "eleven unrelated borders" failure
  `panel_skin.dart` warns about. My art direction was the defect, not the
  model's output.
- **Round 2** held the chassis's leather constant and varied only the corner
  treatment. That produced a real family — but on measurement only `tray`
  (band 9/9/9/9) and `slip` (9/9/9/8) were valid nine-patches; `hero`,
  `modal` and `combat` had their runs inset from the canvas edge by corner
  ornaments, so their edge strips could not tile.
- **Round 3** re-rolled the three with an explicit edge-to-edge clause. Still
  inset (hero L1 R4 T1 B6; combat L9 R9 T0 B0).

And on looking at the two survivors beside the chassis at ×8, **neither is as
good as the frame it would replace** — the tray reads busier and less crafted,
with indistinct corners and an off-centre opening. Shipping it would have made
Inventory worse, which fails the acceptance target directly.

**So nothing was registered.** `PanelSkins.authored` still maps all six roles
to the chassis, which that file already argues is the honest interim state:
one family everywhere rather than a family and a gap.

**The recorded next step is the other lever.** L-18 as amended says screens
differ by *band, surface and picture*. `PanelSkin` already declares
`surfacePath`/`surfaceNative` and `PixelFrame` does not yet render them. A
seamless interior tile per role has no nine-patch geometry to satisfy, is far
more reliable to generate, and is the cleaner path to per-role identity than
five more corner-ornamented borders. It needs widget work first, and a
contrast check for type sitting over a tiled ground.
