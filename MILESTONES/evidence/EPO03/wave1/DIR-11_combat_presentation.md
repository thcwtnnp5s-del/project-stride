# DIR-11 — Combat Presentation (EPO03 Wave 1)

Evidence: five device captures (`FMPO02/review/device/combat/`), the nine HUD
assets at ×4, the three combat Dart files. Zero generations spent.

## TOP FAILURES

1. **Ratio.** Picture 256 dp (30% of 852); under it a 100 dp type band
   (display-serif names, rod gauges, 20-pt numerals), a 219 dp grey card,
   then ~200 dp of bare ground. A third fight, two-thirds chrome and void.
2. **The command card is app UI.** Grey rounded rectangles; the plates are
   isometric ornaments floating behind labels (cushion, diamond, bowl — three
   perspectives); `icon_attack` has a baked checker ground; Retreat is the
   widest control.
3. **No chassis.** A card-radius clip, rod gauges, bare TURN/BOSS chips; the
   intent line sits below the gauges, cut off from the fight.
4. **Refused assets left holes** (turn coin, parchment strip; Q-22 open).
5. **Feedback is thin.** The heavy blow brightens a sentence; the wolf's hit
   is a 3 dp jerk; gauges snap; the frame never moves.

## WHAT TO REPLACE

**Layout (393×852; content 727 dp under header 61 / tab 64):**

- **Stage chassis 384 dp (53%)**: frame 12 · lintel 64 (both gauge wells,
  TURN/BOSS chips centred) · picture 256 · sill 40 (narration) · frame 12.
  Full-bleed; picture clipped 7.5 dp/side under the frame.
- **Intent line 18 dp** on the page under the sill: "It will strike twice."
  in danger rust; the guard sentence when Brace is suggested; "Fighting…"
  during replay.
- **Page ~207 dp**: leather ground, no card; Eat chooser and result resolve
  here.
- **Command rail 118 dp (16%)** pinned above the tab bar: three 64×64 dp
  nine-patch plates (32 dp icon, micro label); Retreat a micro link beneath,
  right-aligned, 44 dp hit. Fight:rail 3.3:1 (≈1.2:1 today).
- **Enemy scale**: the wolf (88×56 dp, shoulder at the Traveler's hip) is
  right; the 80 dp gap between them is not. `enemyColumn` 138→128 (guardian's
  right edge 176 < 192).

**States:** brace armed = 2 dp `defenseSheen` rim + existing haptic; eat with
nothing = plate at 55%, label alone; held = 40%; Retreat is never a plate.

**Narration:** one line, `textPrimary` on the dark sill (>7:1); the parchment
tile retires.

**Feedback (Flutter only; zeroed under Reduce Motion as `combat_stage.dart:346`
does):** stage shake 4 dp / 2 cycles / 120 ms on a landed hit, 6 dp / 3 on
heavy; one-frame white overlay on the picture only (12% / 24%); gauge ghost —
the lost span holds pale 400 ms, then drains; wolf recoil 3→6 dp with a
one-frame scaleY 0.92 squash; brace absorb tints the frame rim `defenseSheen`
150 ms, no shake; a new narration line slides up 120 ms.

**Dart (COMBAT-owned files only):** `combat_screen.dart`:
`StaggeredReveal[CombatStage, SectionCard>_CombatControls]` → `_BattlePage`
sized to the viewport (`StrideGeometry` metrics; scrolls on short phones):
`Column[CombatStage, _IntentLine, Expanded(_Page), _CommandRail]`.
`_CommandRail` = `SurfaceFill(leather)` + `Row[_CommandPlate×3]` +
`_RetreatLink`; `_CommandPlate` is a new local widget, not `StrideButton`
(NAV-owned). `c.combatAttack/Brace/Eat(itemId)/Retreat`, `acknowledgeCombat`,
`_ResultPanel`, `RewardRaise`, `_CombatLog` wording: unchanged.
`combat_stage.dart`: `_Hud/_Combatant` → `_Lintel` above `_Scene`, `_Sill`
below, `_StageFrame` around; `_Shot` gains `shake`, `ghostHp`. Goldens after
diff inspection.

## WHAT TO KEEP

The four 192×128 backdrops ("battlefield attractive"); every sprite, track and
effect; `icon_brace`, `icon_eat`; `_Chip` type; the victory/defeat/retreat
panel, rules and resolution; the Eat chooser's `StrideButton.secondary` rows.

## PRODUCTION FAMILY

All `create_image_pixen`, 3 candidates + ≤3 reroll; **front-on, full-bleed,
rectangular** — a disc, a perspective tile or an empty corner is a REJECT.
Style: `chassis_64.png`, `grain_leather.png`, ART-13 §2. **Q-22 closes here**:
ART-09 §3 is amended to these canvases; the 64×32 ornaments, 24² coin and
64×16 parchment retire.

| Asset | Canvas | Geometry | Count | Gens |
|---|---|---|---|---|
| `stage_frame` — iron-bound dark bark | 48² nine-patch | corner 12 / band 6 | 1 | 6 |
| `rail_plate` — lintel + sill, oiled leather, iron edge | 32² nine-patch | corner 8 / band 6 | 1 | 6 |
| `gauge_well` — recessed track; fill is Flutter (0029) | 28² nine-patch | corner 7 / band 4 | 1 | 6 |
| `chip_plate` — TURN/BOSS tab, never a coin | 24² nine-patch | corner 6 / band 4 | 1 | 4 |
| `plate_attack/brace/eat` — oxblood / bluesteel / wood | 32² nine-patch | corner 10 / band 6 | 3 | 18 |
| `icon_attack` — no ground | 16² glyph | — | 1 | 4 |
| `icon_retreat` — new subject: an open gate, a road through it | 16² glyph | — | 1 | 4 |
| **Tranche 1 (UI)** | | | 9 | **48** |
| Tranche 2: backdrop extension 192×128→192×160 (+64 dp sky, FMPO02 mask-rows method; picture 320 dp, page ~143) | `inpaint_image` 192×160 (20 tier) | — | 4 | **80** + ≤2 rerolls (40) |

## PIXELLAB BUDGET

**Cap 150.** Tranche 1 first, cap 60. Tranche 2 only if ≥80 remain — all four
backdrops or none (heights must match). Nominal 128–140. Units per GOV-04:
pixen 1; inpaint 20 at ≤160×300.

## PHONE-SCALE SUCCESS CRITERIA

1. Framed stage ≥50% of content height at 393×852; rail ≤17%, its top
   ≥560 dp down; no bare ground beneath it.
2. Gauges read as wells in the lintel; names micro, numerals `sub`.
3. Every plate is a whole plate: no edge inside the cell, no floating
   ornament, no checker under Attack, one perspective across three.
4. Sill narration ≥7:1; intent line readable at arm's length.
5. A landed hit moves the picture and ghosts the gauge; Reduce Motion shows
   neither.
6. Wolf and Traveler ≤60 dp apart; guardian's crown clear of the frame.
7. Retreat lighter than any plate; 44 dp hit.
8. Goldens regenerated after inspection.
