# ART-09 — Combat Presentation Brief (FMPO02 Wave 1)

Owner verdict on 4d9a81f: "battlefield attractive; giant lower command frame dominates the fight." Confirmed
against `pair_combat_wolf_slash.png` and the goldens: the stage (192dp+HUD) is small and painted;
`_CombatControls` beneath it is four full-width grey `StrideButton` rectangles, no icon, no plate, ≈252dp
(≈30% of 852dp, ≈35–40% with its card). This brief inverts that ratio and turns the command cluster into
small authored plates.

## 1. Layout, 393×852, budgeted

| Band | dp | Change |
|---|---|---|
| Header | 61 | unchanged |
| **Stage** | 192→**256** | taller backdrop family (§2) |
| HUD (HP gauges) | 40 | authored plates, not bare bars (§3) |
| Narration | 28 | one line, on the stage, not the card (§4) |
| Command cluster | **136** | 2×2 plates + Retreat link (§5), was 252 |
| Tab bar | 64 | unchanged |
| Gaps/padding | ~40 | unchanged pattern |
| **Total** | ~757/852 | 95dp headroom vs. today's near-overflow math |

Stage+HUD+narration: **324dp (38%)**. Command cluster: **136dp (16%)** — inverted from today's roughly even
split, with no engine, save, or button-semantic change.

## 2. Stage: taller backdrop family

Now: 192×96 native ×2 = 384×192dp, HUD beneath, clipped 11–12dp/side at 393dp. Propose **192×128 @×2 =
384×256dp** (width and travelerColumn(58)/enemyColumn(138) unchanged, only vertical canvas grows). Ground
row moves native row 88→~118, adding 60dp sky/canopy (guardian head clearance 32dp→~90dp) and room for the
narration strip. All 9 biome backdrops re-authored at the new canvas — a height extension, not new scenes.
**9 × (1+2 reroll) = 27 gens.**

## 3. HUD: authored gauge, not a bare rectangle

Today's bars are hand-rolled flat fills, no frame — the one part of the screen still reading as "an
application displaying RPG data" (PCE01 §1). `hp_gauge_frame.png`: one plate, 96×16 native, corner 8/band 4,
tiled centre, ×2 = 192×32dp, two instances (traveler/enemy) with name label above. Fill stays a flat rect
(`textPrimary`/`danger`) drawn inside the frame's inset — frame is raster, fill and width are Flutter
(DECISIONS/0029 boundary). One frame, two instances, no per-creature art. **1+3 reroll = 4 gens.**
Turn/round marker: replaces the flat `TURN 1` label with a small plate, 32×16 native ×2 = 64×32dp, corner
6/band 3, same top-left stage placement already licensed as "on the picture." **1+3 = 4 gens.**

## 4. Narration: one line, on the stage

Replace `_CombatLog`'s heading+up-to-4-lines block (40–100dp on the card) with **one line** on a parchment
strip along the new backdrop's bottom edge — latest beat only, or the intent line pre-round; "This round"
heading drops, position already says "now." Tap-to-skip text stays, same strip. `narration_strip.png`:
tiled parchment, 96×20 native, corner 6/band 4, alpha-edged top, ×2 ≈ 40dp. **1+3 = 4 gens.** Removes the
log block entirely from the command card — the single biggest cut from the 252dp column.

## 5. Command cluster: 2×2 plates + quiet Retreat

2×2 grid: Attack/Brace row one, Eat/Retreat row two, Retreat as a quiet text link (no plate) beside Eat,
per the owner's ask. Each plate 72×72dp (icon 32dp @×2 over 16×16 native icon-plane, label beneath at
`StrideType.micro`), full-plate tap target. Two per row + `cardGap` = 154dp wide, fits 361dp content twice.
Two rows = 152dp visual; folding Brace's sublabel into a hold-to-reveal tooltip and trimming the
guard-reading line to 13dp yields **136dp total**, vs. 252dp today.

Assets (`create_ui_asset`, 64×64 native, corner 14/band 6, drawn 36×36 native ×2 = 72dp, matching the
subject-plane density):

| Plate | Material |
|---|---|
| `plate_attack.png` | red leather over dark steel edge (danger accent) |
| `plate_brace.png` | blue-grey tempered steel (`defenseSheen` accent) |
| `plate_eat.png` | carved wooden bowl rim |
| Retreat | **no plate — plain text link** |

All three share chassis DNA (rounded corner, single outline, key-light upper-left) — one family, three
materials, not three languages (Batch D's own rule for the modal frame). **3 × (1+3 reroll) = 12 gens.**
Icon glyphs (crossed blades / raised shield / bowl) reuse the 14×14 nav-icon canvas and silhouette
language. **3 × 4 = 12 gens.** Retreat stays `StrideButton.secondary`: 34dp visual inside a 44dp hit
region, verbatim reuse, zero new art. Brace's "Take N instead of M" sublabel moves from a permanent second
line to a long-press/hold reveal (Flutter-only, zero gens); the plate keeps a one-line, non-numeric
"hold for detail" hint inside the 136dp budget.

## 6. Reaction presentation + accessibility

**Shake/flash** (new): a heavy blow gets a ≤4dp stage translate-shake (2 cycles, ~120ms) and a
single-frame `dangerDim` flash on the backdrop only, never HUD/command cluster. **Reduce Motion**
(`MediaQuery.disableAnimationsOf`) zeroes both — `combat_stage.dart` has no Reduce Motion branch today
(PCE01 §4), so this must reuse the pattern `craft_screen.dart`/`skills_screen.dart` already apply, not a
new one. Existing `fx_impact`/`fx_bite` (32×32, 5 frames) are **kept as-is** — they read correctly on
device and are not the named defect.

**Damage numerals**: type, never raster — every HP figure and any floating damage numeral is
`Text`/`AdaptiveText`, as `_ResultPanel`'s XP line already is; none exists yet in `_Shot`, and if one is
added it must be type.

**Accessibility**: all plates + Retreat ≥44dp tap target (plates 72dp; Retreat's 34dp visual in a 44dp hit
region, existing pattern). Dynamic Type: labels use `StrideType.micro` under existing scale handling; a
scaled label wraps to two lines before a plate grows — plates stay 72×72, text is the flexible dimension.
Narration/gauges hold WCAG-AA contrast; never reuse `textMuted` (documented pre-existing failure, PCE01
§11) on new elements.

## 7. Generation estimate

| Item | Gens |
|---|---|
| Backdrop family (9 biomes, taller) | 27 |
| HP gauge frame | 4 |
| Turn/round marker | 4 |
| Narration strip | 4 |
| Attack/Brace/Eat plates | 12 |
| Plate icons ×3 | 12 |
| Reroll contingency | ~13 |
| **Total** | **~76**, ceiling **~150** if the backdrop pass needs a second full round |

## 8. Scope note

`GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md` Batch D states the combat frame "takes the chassis from
Batch A... adds nothing inside it." This brief supersedes that for the **command-cluster plates only**
(§5), on direct instruction; the card's own frame/chassis stays the one `chassis_64.png` family (DNA-6).
Batch D's text should be corrected, not silently contradicted.
