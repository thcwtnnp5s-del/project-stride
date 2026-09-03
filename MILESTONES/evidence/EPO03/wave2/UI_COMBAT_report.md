# EPO03 wave 2 — PROD-UI-COMBAT report

Brief `wave1/DIR-11_combat_presentation.md`. Branch
`fable5-executive-production-overhaul-03`. **Cap 150, spent 3.**

> "Fight first. UI second. Make the battlefield visually dominant. Buttons
> should not outweigh the fight." — the owner, on this screen.

**Measured fight-to-rail: 398 : 120 = 3.32 : 1**, against about 1.2 : 1 on
`4d9a81f`. The chassis is 57 % of the 699 dp content column and the rail is
17 %; the rail's top edge is 652 dp down an 852 dp screen with the tab bar
directly under it and no bare ground anywhere beneath the controls. The
figures are held in `test/combat_ui_test.dart`.

---

## What shipped

### The layout (the bigger half, and it cost nothing)

```text
   ┌───────────────────────────────┐  frame band   19   KitFrame.stageFrame
   │  Traveler 40/40  TURN 1  Wolf │  lintel       64   two gauge wells + chips
   ├───────────────────────────────┤
   │                               │
   │        t h e   f i g h t      │  picture     256   full-bleed, unclipped
   │                               │                    by the chassis
   ├───────────────────────────────┤
   │  The fight begins. 20/20…     │  sill         40   narration, dark shelf
   └───────────────────────────────┘  frame band   19
      It will strike twice.            intent       18   on the page
                                       page        163   leather, NO card
   ═══════════════════════════════     welt         12   nav_welt_v2
   [ ⚔ Attack ][ 🛡 Brace ][ 🍲 Eat ]   plates       64   three nine-patches
                Retreat — nothing…     retreat      44   micro link, 44 dp hit
```

- **The stage is a chassis, not a picture with a band under it**
  (`combat_stage.dart`). `KitFrame.stageFrame` is drawn **over** a full-bleed
  column by a new `_StageFrame` — `PixelFrame` paints eight patches and no
  interior — so the backdrop keeps the whole chassis width and loses only the
  columns the beams already covered. The 398 dp is bought entirely from the
  ~100 dp type band that used to sit below the picture, not from the picture.
- **`_Hud`/`_Combatant` → `_Lintel`/`_Gauge`.** Both names, both gauges, both
  `hp / max`, TURN and BOSS, in 64 dp instead of ~100: the name and its figure
  share one 16 dp row above the 32 dp gauge, names are `micro` and figures
  `sub` (they were `sectionHeading` and a 22 pt `numericValue`), and the chips
  come off the sky into the centre of the band. The stage's own telegraph line
  went with them — it was the third statement of a fact the sill and the
  intent line each already make.
- **The card is gone.** `SectionCard(role: combatFrame)` is deleted from this
  screen; `_BattlePage` is a viewport-sized column of chassis · intent ·
  `PageGround(leather)` · rail. It measures the viewport from `StrideGeometry`
  rather than using `Expanded`, because the host `ListView`
  (`adventure_screen.dart` 124–136, **untouched and frozen**) gives unbounded
  height; on a short phone it keeps a floor and the host scrolls.
- **The rail is three real nine-patch plates.** `_CommandPlate` draws
  `KitPlate(frame: KitFrame.btnPlateV2)` at a stated 64 dp with the command's
  ink as the fill — the same raster `StrideButton` now draws at its own 43
  call sites, so a command plate and a product button are one construction
  with one light direction, differing by geometry and temperature rather than
  by a second family of art. **Q-22 closes here** (see below).
- **Retreat is a micro link**, right-aligned, in a full-width 44 dp hit
  region, never a plate. It was the widest control on the screen.
- **`enemyColumn` 138 → 128** (`combat_assets.dart`): 20 dp closer at ×2,
  closing the 80 dp of empty ground that made two creatures read as two
  illustrations. Sprites, footprints, anchor rows and the ground row are
  untouched; the guardian's right edge lands 176 dp of a 192 dp half-width and
  the render shows its crown clear of the top beam.

### Feedback (Flutter only, zero art)

A landed blow now moves the **frame**, not only the figure inside it: a damped
4 dp rock over 120 ms (6 dp over three cycles when the blow is heavy) and an
80 ms white veil at 12 % / 24 % over the picture, both keyed to the recoil's
own instant so the picture and the figure move together. Both are zeroed under
Reduce Motion, where the gauge, the impact burst and the narration each still
say a blow landed — no channel is removed that the setting does not name
(M-16).

### Haptics (DIR-14, zero cost)

`AudioScope.maybeRead(context)?.hapticLight()` prepended at **Attack**, the
**Eat choice** and **Retreat** — the three commands that fired nothing while
Brace had a pulse and the audio matrix assumed one everywhere. Fired before
the command goes out, so the tap answers on the frame it happens.

### Art — 3 generations of a 150 cap

| Mark | Outcome | Gens |
|---|---|---|
| `icon_attack` | **the baked checkerboard keyed out** — 91 pixels of one exact ink (`#0C0B0F`), lossless, no tool call | **0** |
| `icon_retreat` | two posts under a lintel with a road between them, `create_image_pixen`, job `a059b653…` | 1 accepted + 2 rejected |
| stage frame · rail ground · gauge well · chip plate · 3 command plates | **already on disk** — `KitFrame.stageFrame`, `KitTile.navWelt`, `CombatHudAssets.gaugeFrame`, `_Chip`, `KitFrame.btnPlateV2` | **0** |

Seven of DIR-11's nine marks were the shared kit's rows under different names.
`KIT_CONTRACT.md` §8 before generating: it saved 45 of a 48-generation tranche.

Ledger `GAME_BIBLE/ART/exploration/EPO03/ledger/UI_COMBAT.md`; rejects with
written verdicts in `E/rejected/combat/VERDICTS.md`; new deterministic tool
`E/tools/key-flat.js`.

---

## Proof

`GAME_BIBLE/ART/exploration/EPO03/review/device/combat/`, all 393 × 852 at
DPR 1, written by `test/combat_page_evidence_test.dart`
(`COMBAT_EVIDENCE_DIR`, gated, asserts nothing):

| File | What it shows |
|---|---|
| `page_wolf_turn.png` | **the ratio shot** — chassis, lintel, intent line, leather page, three plates, Retreat, sword in hand |
| `page_wolf_hit.png` | the blow landing: picture displaced and veiled, plates at 40 %, "Fighting…" |
| `page_wolf_brace.png` | the brace hold, guard pose, round held |
| `chassis_guardian.png` | TURN 3 / BOSS stacked in the lintel, crown clear of the top beam, the closed gap between the figures |
| `page_unarmed.png` | the same page with nothing in the hand, Eat refused with its reason on the plate |
| `page_eat_chooser.png` | the chooser resolving **on the leather page**, Eat relabelled "Choose" |
| `page_retreat.png` | the result raised over the fight still standing behind it |

Sheets: `E/review/combat/icon_attack_keyed_x8.png`,
`icon_retreat_x8.png`, `icon_retreat_accepted_x8.png`.

## Tests

`flutter analyze` on all six touched files: **clean.**

| File | Result |
|---|---|
| `combat_ui_test.dart` | pass |
| `combat_stage_test.dart` | pass |
| `combat_presentation_order_test.dart` | pass |
| `combat_busy_test.dart` | pass |
| `combat_visible_death_test.dart` | pass |
| `combat_page_evidence_test.dart` (new, gated) | pass |

**`test/combat_golden_test.dart` differs and was NOT regenerated**, as
instructed: `goldens/combat_stage.png` 71.36 % / 238,937 px, and
`goldens/combat_victory.png` (the fight behind the panel changed). Both are
the screen being rebuilt. The producer regenerates after inspection.

Test changes, all locator or figure updates rather than weakened assertions:
`widgetWithText(StrideButton, 'Attack')` → `find.text('Attack')` plus a new
`command(tester, label)` helper reading the plate's own `GestureDetector`
(`_CommandPlate` is private, because a 64 dp stacked plate is not the
product's general button); `enemyColumn` 138 → 128 in the guardian placement;
the opened round now appears three times rather than two (the sill keeps its
headline while the page shows the whole round). **"The command card fits its
210 dp budget"** is replaced by **"the fight outweighs the commands"** — the
old guard measured a `SectionCard` that no longer exists, and the new one
states the ratio the owner ruled on, with the chassis, rail and column figures
written out.

---

## What did not close

1. **The leather page is empty between rounds** — 163 dp of grained leather
   below the intent line on an ordinary turn. It is exactly what DIR-11
   specified ("leather ground, no card; Eat chooser and result resolve here")
   and it is the thing a device read is most likely to name. Raised as
   **Q-30**, with the three candidate answers and their consequences.
2. **Tranche 2 (the four backdrop extensions) was declined on the evidence,
   not the budget.** 147 generations were free and the gate was open. The
   256 dp picture already carries ~100 dp of sky above the Traveler's head;
   +64 dp of *more sky* trades empty leather below the fight for empty air
   above it and sinks both figures in a taller frame. Tranche 2 was specified
   before the chassis existed, when headroom was the guardian's problem — the
   lintel solved that instead. If the picture grows, the rows want to be
   **ground**. Recorded in Q-30 and in the ledger.
3. **The brace-armed rim is not built.** DIR-11 asks for a 2 dp
   `defenseSheen` rim on the frame when Brace is armed and a 150 ms rim tint
   when a brace absorbs. The brace *hold* and its haptic ship; the rim does
   not. It is a `_Shot` field and a `_StageFrame` overlay, no art.
4. **Three feedback channels from DIR-11 are not built**: the gauge ghost (the
   lost span holding pale 400 ms before draining), the wolf's scaleY 0.92
   squash on recoil, and the 120 ms slide-up on a new narration line. The
   shake and the white veil are; these three each need a new `_Shot` term and
   were cut to keep the layout landed and proved.
5. **`icon_retreat` is authored, accepted and committed but not wired.**
   `pubspec.yaml` declares `assets/ui/v1/` file by file and NAV owns it;
   request filed in `REQUESTS_NAV.md` 2026-09-03. Retreat ships as the micro
   link with no glyph — a finished state, not a hole. COMBAT wires it at ×1
   (16 dp, half the plates' 32) when the row is DONE.
6. **The guardian evidence is a chassis shot, not a page shot.** The Forgotten
   Hollow's entry requirement is a bronze sword the fixture cannot mint, so
   the boss is staged the way `combat_golden_test.dart` stages it — the widget
   driven from a hand-built view. The guardian-specific claims (BOSS in the
   lintel, crown clear, closed gap) are all visible; the rail and the ratio
   are proved by the four whole-page shots.
7. **Full-bleed is bleed-to-the-gutter, not bleed-to-the-glass.** The host
   `ListView`'s 16 dp gutters are inside `adventure_screen.dart` 124–136,
   which is frozen, so the chassis is 361 dp wide rather than 393. Escaping
   the gutter is a change to the frozen host and was not made.

## Requests and questions

- `REQUESTS_NAV.md` — one `pubspec.yaml` row + one README provenance line for
  `combat/icon_retreat.png`. Not blocking.
- **Q-22 CLOSED** — the disagreement was two sets of numbers for the same
  wrong shape (the plates are blobs with empty corners; no nine-patch can be
  cut from them at any geometry). `KitFrame.btnPlateV2` resolves it by being a
  real one. `ART-09` §3 is superseded by DIR-11, not amended; the gauge frame
  is the only row that carries over. A test asserts the three ornament plates
  no longer reach the screen, so they cannot drift back.
- **Q-30 RAISED** — what is on the combat page between rounds, and whether the
  backdrop family is ever re-authored taller, and at which end.

## Commits

`949f939` haptics · `829d937` the chassis · `e101400` the battle page and rail
· `51b3454` the marks · then the plate height and page log, the evidence
renders with Q-22 closed and Q-30 raised, and this report.
