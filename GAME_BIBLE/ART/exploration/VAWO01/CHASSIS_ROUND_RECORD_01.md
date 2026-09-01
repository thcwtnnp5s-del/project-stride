# Batch A — the chassis frame kit: round record

```
STATUS: ACCEPTED · 1 asset shipped · 18 generations spent
Date: 2026-09-01 · Branch: visual-audio-world-overhaul-01
Authority: DECISIONS/0030 (which reopened the budget DECISIONS/0029 recorded
as exhausted) · Queue: GAME_BIBLE/ART/PIXELLAB_UI_PRODUCTION_PLAN.md § Batch A
```

**Balance of record.** `get_balance` at round open: **10,000 remaining, 0 used,
Tier 3, resets 2026-10-01**. Spent in this round: **18**. The plan budgeted
1 accepted + 3 re-roll = 4; the overspend is explained in § 4 and was worth it.

**Shipped:** `assets/ui/v1/frame/chassis_64.png` — 64 × 64, corner block 16,
band 8, scale ×2. Registered against `PanelRole.card`, `heroPlate` and
`boardSlip`.

---

## 1. The two findings the plan asked round 1 to record

The production plan § 13 lists both as open and asks round 1 to settle them
either way. Both are now settled.

**`view: "side"` is correct for flat interface art.** It was recorded as
"unproven in this repository" — every prior round used `low top-down` or
`high top-down`. Measured across six candidates:

| `view` | Result |
|---|---|
| `side` | Flat, straight-on frames in **4 of 4** rolls. Correct. |
| `high top-down` | A segmented rail with discrete blocks in the runs (1102), and one broken non-frame (1106). |
| `low top-down` | Bright gold, glossy, specular highlight (1105) — three separate craft violations at once. |

`side` is the setting for this asset class. The two top-down modes are not
near-misses; they answer a different question.

**The model fills the centre, and keying is the right answer.** The plan
predicts this and says explicitly: key it, do not re-roll. Confirmed — 3 of 4
`side` rolls at 96 × 96 filled the centre with a decorative panel. All were
recoverable by flood-fill alpha key. **Interestingly the 64 × 64 rolls did not
fill it at all**, which is a second finding: at the smaller canvas the model
reads "hollow border" literally.

## 2. What was accepted, and the deterministic work done to it

`chassis_64.png`, from seed **2202 at 64 × 64**, `view: side`,
`outline: single color outline`, `no_background: true`.

Post-work, all A-2 (invents no object, silhouette, frame or illustrated
content):

1. **Crop to content** — none needed; the roll filled the canvas exactly.
2. **Speck removal** — none needed; one connected component.
3. **Interior key** — none needed; the centre came back transparent.
4. **Ceiling clamp** — **5 colours, 208 pixels.** The model's stitch line came
   back near-white, which breaks the § 6 luminance ceiling (`textMuted
   #7C7263`) and would have put chrome brighter than the words on every panel.
   Only the offending colours moved, order-preserving, onto the ramp.

**The clamp replaced a full remap, and that is the round's methodological
finding.** The first correction quantised *every* colour onto the five-ink ramp
by rank. It passed the guard and destroyed the asset — the frame came back
olive and lost the warm brown that made it read as oiled leather. An earlier
attempt normalising raw per-pixel luminance was worse still: one near-white
stitch set the maximum, ~80% of pixels were dark outline, and the leather
compressed into the darkest ink, leaving a black rectangle with a faint dashed
line.

**The rule this round establishes: correct only the violation.** The ceiling
forbids art *brighter* than `textMuted`; it says nothing about the rest of the
ramp. Repainting 3,279 pixels to fix a breach that lives in 208 is not a
palette conform, it is a repaint, and it showed.

## 3. Geometry, measured not guessed

| Quantity | Plan's figure | Shipped | Note |
|---|---|---|---|
| Sheet | 96 × 96 | **64 × 64** | § 4 |
| Corner block | 16 | **16** | must contain the whole corner cap |
| Band | 6 | **8** | measured, symmetric on all four runs |
| Inset (band × scale) | 12 | **16** | what content is inset by |
| Scale | ×2 | **×2** | UI chrome density, § 3.1 |
| Repeat period | 8 | 8 | all four runs wrap; guard green |

Mirrored in `assets/ui/v1/frame/chassis_64.json` for
`Scripts/art/check-tile-seam.js`.

## 4. Why 18 generations and not 4

Three rounds, and each answered a question the previous one raised.

- **Round 1 (6 gens, 96 × 96).** Established `view`. Best candidate (1101) had
  bands of **5 / 6 / 12 / 12** — asymmetric, and `PanelSkin.inset` is a single
  number, so the vertical runs would have put body text on frame art.
- **Round 2 (6 gens, 96 × 96, "same thickness on all four sides").** The clause
  worked: 2202 came back **11 / 11 / 11 / 11**, clean, hollow, continuous
  stitch. Accepted on craft — and then rejected on *weight*. At ×2 an 11 px
  band is a 22 logical px inset, and rendered at all four device widths it
  dominated the short cards.
- **Round 3 (3 gens).** "Only four pixels thick" produced fragmented,
  asymmetric frames in all three rolls — 57 to 68 disconnected components. The
  model does not thin a border on request; it breaks it.
- **Round 4 (3 gens, 64 × 64).** The actual fix was the **canvas**, not the
  adjective. The band is roughly a fixed *fraction* of the sheet, so a smaller
  sheet at the same ×2 density gives a thinner band in logical pixels. Seed
  2202 re-rolled at 64 × 64 returned band **8** — 16 logical — with corner caps
  the 96 rolls never produced.

**The finding worth carrying forward: to change a border's weight, change the
canvas, not the wording.** Two rounds were spent learning that.

## 5. What was rejected, and why

All 17 rejected rolls are in `rejected/`, kept deliberately — a rejected roll
with a written verdict is what the next round is built on (M-05).

| Candidate | Verdict |
|---|---|
| `chassis_r1_side_1101` | Good runs (invariance 0.46–0.73) but bands **5/6/12/12**. Asymmetric. |
| `chassis_r1_topdown_1102` | Segmented rail — discrete blocks inside the runs, forbidden by § 3.4. |
| `chassis_r1_1103_side` | Clean stitch, but corner specks and a key that ate the top band. |
| `chassis_r1_1104_side` | Empty centre, but discrete L-brackets mid-run **and** corner bosses; "no metal studs" was in the prompt. |
| `chassis_r1_1105_lowtd` | Bright gold, glossy, white specular. Reads as currency (P-6) and breaks the ceiling. |
| `chassis_r1_1106_hitd` | Not a frame — corner arcs and a dashed line. |
| `chassis_r2_2201 / 2205 / 2206` | `detail: low` fragmented the border: 62, 46 and 68 components. |
| `chassis_r2_2203 / 2204` | Bands 0/8/0/4 and 6/7/6/8 with run invariance to 13.7. Noisy. |
| `chassis_r3_3301 / 3302 / 3303` | "Four pixels thick" — all three fragmented or collapsed. |
| `chassis_r2_2202_96_superseded` | **Accepted, then superseded.** Craft is good and it is kept as the fallback if the 64 is ever rejected on device; its 22 px inset is the only thing wrong with it. |
| `chassis_64_4401 / 4402` | 4401 chamfered/octagonal, less clean. 4402 carried 210 colours — noise. |

## 6. Verification

- `Scripts/art/check-art-palette.js` — **872 PNGs, green.** No teal collision,
  no semi-transparent pixel, chrome under the ceiling.
- `Scripts/art/check-tile-seam.js` — **4 strips, all wrap at period 8.**
- `Scripts/art/package-art.js --check` — 851 files, unaffected (this asset is
  hand-maintained, not packaged).
- Rendered at **320 / 360 / 393 / 430 dp**, at a short card and a tall one,
  through a reimplementation of `_FramePainter`'s exact tiling loops
  (`tools/render-frame.js`). No visible beat at any width.
- `flutter test` — **969 pass.** Three golden files changed and were inspected,
  not accepted blind.
- `flutter analyze` — clean.

**One real regression was found and fixed, not accepted.** At 320 dp with the
accessibility text scale at ×1.4, `ui_responsive_test.dart` failed:
`"Woodcutting" needs 103.9 dp and was given 93.3`. The frame's band and the
card's padding were both charging for the same breathing room — 30 dp per side
against the unskinned 15. `SectionCard` now subtracts the frame's inset from
the caller's padding, floored at a 6 dp gap. `DECISIONS/0029` forbids
decorative art reducing large-text support, so this was the art's defect to
fix, not the test's assertion to relax.

## 7. Still open

- **Device acceptance.** Rendered goldens are not a device read (M-06). The
  chassis is unaccepted until the owner sees it on the iPhone.
- **Three screens do not benefit.** Inventory, Craft and World goldens are
  byte-unchanged: their panels are hand-rolled surfaces, not `SectionCard`, or
  are `kitTray`. Skills, Character, Adventure and the craft stage did change.
  This is `FOUNDATION_C_UI.md`'s finding — the shared layer stops at the card,
  with 96 one-off private widget classes past it — and it is not fixable by
  art.
- **Corner radius.** The chassis silhouette is near-square (arc 2 src px)
  against `StrideRadius.card`'s 14 logical. The painted fallback therefore has
  visibly rounder corners than the frame. Judged acceptable, and arguably
  desirable: "generic rounded panels" is the complaint being answered.
- **Batches C, B, D, E, F, G, H, I** of the production plan are unstarted.
