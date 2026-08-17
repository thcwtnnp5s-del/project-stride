# UI Facelift 01 — responsive hardening and presentation quality

```
STATUS: IMPLEMENTATION COMPLETE — awaiting physical-device review
Branch: ui-facelift-01
```

Opened after Playable Demo Phase 1 closed on a physical iPhone, to make the UI
feel deliberate before large new systems are built on it, and to fix **D-01** as
a class of defect rather than as one number.

Phase 1 is not reopened. F-07, OD-01 and OD-02 are not started.

---

## 1. The audit, and what it found

Read-only pass over `lib/ui/` — 24 files, four screens, one shell — against the
brief's five perspectives.

### A. Responsive layout

| Finding | Where | Severity |
|---|---|---|
| **A-1** Fixed 72 dp box + `TextOverflow.clip` around the banked figure | `screen_header.dart` | **D-01, on-device** |
| **A-2** `itemTileMinHeight` documented as a *floor*, passed to `mainAxisExtent`, which is **exact** | `inventory_screen.dart` | latent |
| **A-3** `headerHeight` fixed at 61 dp around a stack that grows with the text scaler | `screen_header.dart` | latent |
| **A-4** `_Arrow` positioned by `top: 24`, a constant standing in for a type measurement | `gather_node_card.dart` | latent |
| **A-5** Fixed `height:` on chip (26), gate (22) and button (44 / 56) | `data_display.dart` | latent |
| **A-6** `RequirementGate` used `Container(alignment:)`, which expands to its constraints — inside a `Wrap` each gate was silently full width and the `Wrap`'s `spacing` had nothing to space | `data_display.dart` | visible |

### B. Typography and hierarchy

- **B-1** The primary action's label (13.5) was **smaller** than the card titles,
  section headings and skill names around it — the wrong end of the hierarchy
  for the only control on the screen.
- **B-2** Inventory's item name at 10 px was so much weaker than the icon and
  count that the grid scanned as icons alone, against L-17's "icon + label +
  count is the complete semantic unit".
- **B-3** `BANKED FROM WALKING` — nineteen letter-spaced uppercase characters —
  measured **wider than the figure it captioned**, so the readout's width, and
  therefore how little was left for the screen title, was set by its own caption
  rather than by the player's data.
- **B-4** Per-skill XP and the inventory carried-total were set in the same muted
  11 px as inline captions, though both are values.

### C. Component system

- **C-1** `LabeledValueTile` used an **unbounded** `FittedBox(scaleDown)`. It
  never clipped and it also never stopped: `9,999,999` in a narrow tile renders
  around 9 px. That is D-01's information loss with better manners.
- **C-2** No primitive existed for "text that must not be truncated", so every
  site solved it separately, and most solved it with `TextOverflow.clip`.
- **C-3** Three-across value tiles plus two arrow glyphs are the densest
  arrangement in the app and had no yielding behaviour at all.

### D. Real-data stress

Measured against a **real Roboto face**, not the test harness's square fallback:

- **D-a** `455,281` needs ≈ 77 dp at `headerValue`; the box was 72. *The defect.*
- **D-b** `EXPERIENCE` needs 73.4 dp at `microLabel`; the third cost tile gave it
  **46 dp at 320 dp, 59 at 360, 70 at 393**. The word was clipped on every
  supported phone.
- **D-c** `90` in the Steps cost tile was given **16 dp** and needs 19.8 at
  320 dp — the leading walking glyph took 30 of the tile's 45 dp of content.
- **D-d** `9,999,999` in a two-across tile with a leading glyph needs 77.3 dp in
  the 75 available at 320 dp.

**D-b and D-c are previously unknown on-device defects of the same class as
D-01**, found by changing the instrument rather than by looking harder.

### E. Device-test coverage

- **E-1** The five overflow tests assert `takeException() == null`.
  `TextOverflow.clip` raises nothing, so they are structurally incapable of
  seeing any of A-1, D-b or D-c. `MISTAKES.md` M-06, third occurrence.
- **E-2** The goldens rendered `12,480` — six characters, which fits the box
  seven did not.
- **E-3** The goldens had **no font**, so every glyph was a filled rectangle.
- **E-4** `phase1_ui_test.dart` was intermittently failing on Windows *before*
  this branch, and the cause was real: `tapAndAwait` waits on `StrideSession`,
  while the button labels are driven by `SessionController.busy`, which clears
  later.

---

## 2. D-01 — the root fix

**72 was never the bug.** The bug was the shape: *a fixed box holding a value the
player grows without bound, failing silently.* Raising the constant would have
moved the failure to eight characters.

Four changes, in order of how much they matter:

1. **`AdaptiveText`** (`lib/ui/components/adaptive_text.dart`) — the one
   implementation of "this text must not lose a character". Given a finite
   width it renders every character, at the designed size where that fits and at
   a **bounded** reduction where it does not. Given an unbounded width it takes
   its intrinsic size. It measures the *inherited* style merged with its own, so
   it lays out and measures in the same font.
2. **`bankedFigureWidth` → `bankedFigureMinWidth`.** The stability the fixed box
   bought is real and is kept — below 72 dp the readout does not move, so a new
   player's four-figure balance still does not jitter the eyebrow beside it.
   Above it, the figure takes the width it needs.
3. **The header yields in the right direction.** The readout may claim up to 62%
   of the bar; the screen title, which is one of four fixed short words, is what
   compresses. `headerHeight` became a minimum.
4. **`ValueTileRow`** — a row of value tiles that **stacks when the tiles no
   longer fit**, decided by measuring the same strings at the same floor with
   the same scaler, not by a width breakpoint. A breakpoint would be another
   constant standing in for a measurement, which is D-01's whole story.

---

## 3. Facelift changes

### Shared

| Change | Reason |
|---|---|
| Tab bar 74 → **64 dp** | 45 dp of content in a 74 dp bar; 10 dp back on every screen |
| Button 44 → **48 dp** min, label 13.5 → **15** | the only control on the screen was set below the card titles |
| Chip / gate / button heights → minimums | fixed boxes around type that scales |
| `RequirementGate` shrink-wraps | the two conditions now share one line |
| `BANKED FROM WALKING` → **`BANKED STEPS`** | the caption was setting the readout's width; teal and the walking glyph already say "from walking" |

### Adventure

- The **`AVAILABLE 455,281` row is removed.** It printed the same
  `usableEnergy` the header prints permanently — the third restatement of one
  number, and the one directly above the button, competing with it. The
  shortfall case still names the exact steps to walk, on the button.
- **The two `→` glyphs are removed** from the cost triple. At 320 dp they took
  64 dp of the card's 264 — a quarter of it — to decorate a sequence the labels
  already state in order, and they are what made `EXPERIENCE` and `90` clip.
  The asset stays in the set; whether a sequence mark returns is the owner's.
- The **walking glyph moves from the value line to the label line** in every
  value tile. It marks the category, which is what the label does.

### Inventory

- Top padding 12 → 10, heading gap 10 → 8.
- Item name 10 → **10.5**; carried total promoted from muted caption to a
  primary-colour figure.
- Grid extent derived from the text scaler, floored at the designed 119 dp.

### Character

- **Two cards became one.** The portrait card's right 40% was empty beside the
  word `Traveler`, and a separate two-tile card underneath answered "how far
  along am I". Level and skill levels are now lines beside the portrait — text
  that wraps and shrinks, not the tile that was reverted last time for
  overflowing at 320 dp.
- `Total skill XP` gained a unit line; per-skill XP is tabular and secondary
  rather than muted.

### World

- A **`YOU ARE HERE / Haven's Rest`** caption sits directly under the map. The
  screen's first question was answered in the first row of a legend 640 dp down.
- The map is **deliberately not cropped**. Its subjects run the whole length —
  settlement at the top, mine mouths on the right flank, ruin at the bottom — so
  any crop that buys a screenful of scrolling deletes a place the legend names.

**No travel affordance was added.** Nothing on the screen is a control; the
existing test asserting zero `StrideButton`s on it still passes.

---

## 4. Evidence — and it is a different kind

`test/ui_responsive_test.dart`, **64 new tests**.

**A real font is loaded and its absence is a failure, not a skip.**
`test/support/real_font.dart` registers Roboto from the SDK's own cache. The
`flutter test` fallback draws every glyph as a filled rectangle ≈ 0.84 em wide
against Roboto's ≈ 0.55, so a width assertion taken against it measures the
harness — and the natural response, shrinking real type until the fake font is
satisfied, makes the shipped UI worse.

The goldens now load it too. They still cannot judge insets, and Roboto is not
SF Pro — but a typographic fault is now *visible in the image* instead of
merging into a box, and the goldens now take the same layout branch a device
does.

| Assertion | Replaces |
|---|---|
| The header's `Text.data` **equals `formatSteps(value)`** | — |
| For **every single-line paragraph in the tree**, `RenderParagraph.getMaxIntrinsicWidth` ≤ its laid-out width | `takeException() == null` |
| The readout does not move below its minimum width | a comment claiming it |
| `AdaptiveText` bottoms out at its floor | the unbounded `FittedBox` |

Matrix: **7 banked values × 4 widths**, plus every screen at 4 widths with a real
save, plus **3 text scales × 2 widths × 4 screens**, plus primitive stress at
`999,999` / `9,999,999` / `×999` across 4 widths × 3 scales.

Four new goldens at the **accepted save's own figures** — 455,371 banked, one
gather, 455,281 — kept alongside the small-value four, because a new player's
short figure is also real.

`phase1_ui_test.dart`'s `tapAndAwait` now waits for the controller to leave its
busy state, asserting `busy() == false` rather than lengthening a sleep. Three
consecutive full runs, clean.

**Totals: 158 app tests + 8 goldens, all green.**

`Scripts/verify.sh --strict` passes end to end — core purity, the product-UI
boundary, art packaging, dependency policy, storage privacy, and the iOS,
Android, single-writer, step-model and origin-privacy guards with their
self-tests. `flutter analyze lib test` is clean.

> An earlier run of `verify.sh` reported `SELF-TEST FAILED: the live working
> tree was modified by the self-test`. That was **my** fault, not the guard's:
> documentation was being edited while the run was in flight, so the guard's
> before/after `git status` snapshots legitimately differed. Re-run against a
> quiet tree, it passes. Recorded because the message names the wrong culprit
> convincingly, and the next person to see it should not go hunting the guard.

---

## 5. Visual QA, and the one correction pass

An independent Visual QA read the four rendered screens at play scale and
returned **FAIL**, 2 blockers / 7 majors / 10 minors. Its own staging note is
worth keeping: the round **was not blind** — the filenames name the screens and
the brief named L-16, L-17 and the World rule before it saw a pixel — so some
findings are directed rather than discovered. That is a fair criticism of how it
was staged (`MISTAKES.md` M-04) and the findings are weighed accordingly.

**Acted on, in one focused pass:**

| Finding | Change |
|---|---|
| `Skills` and `Craft` still read as tappable, on all four screens — "highest-frequency defect in the set" | disabled opacity **0.4 → 0.28**. 0.4 was measured against full strength; the live tabs are already restrained, so the margin has to be judged against *them* |
| `5 / 100 5 skills` — three numbers and a slash in one run, second thing the eye reaches | the unit moved to its own line; `Level`'s dangling `character` qualifier removed |
| `5058` ungrouped beside `455,281` on the same screen | thousands-separated like every other figure |
| The item count reads as the second line of the name, not as a quantity | `itemCount` 13 → **14.5**, a point and a half clear of the name |

**Not acted on, with reasons rather than silence:**

- **"The illustration shows a standing man on a card named Meadow Patch."** That
  is the activity stage — the Traveler performing the action the button
  executes, deliberate and documented. A correct observation of what is drawn,
  and not a defect.
- **"`YOU ARE HERE` with no marker on the map."** Deliberate. `world_screen.dart`
  rejects a pin because a pin is the thing a player tries to drag, and the
  screen's whole discipline is that it must not imply travel.
- **"`6 items` vs five tiles."** Correct by design: the header counts quantity,
  not stacks.
- **"Inventory is 55% empty."** True, and it is what owning five things looks
  like. Filling it would need a capacity affordance, which `RULES.md` P-5 and the
  screen's own doc forbid.
- **"`Woodcutting` reads in the reserved teal family."** `skillWoodcutting` is
  `#3F8F63`, a green, against teal `#58D6C0` — but "reads as" is a perceptual
  claim and the reviewer is the right instrument for it. Escalated, not decided
  (`RULES.md` G-3). Related to Q-04.
- **"The primary button does not read as a button."** Partly fair — it shares
  `surfaceRaised` with the chips. Giving it an outline would extend the border
  ladder to a sixth element, which is an identity call. Raised for the owner.
- **"Sprite edges look softly scaled."** `PixelAsset` asserts integer scale in
  debug and item icons are 48 px at ×1; this is the source art, not a scaling
  fault.

**The verdict is not re-run and is not overturned here.** Two of the blockers are
readings of deliberate design and one major is genuinely open; the four
corrections above are what the pass could act on without deciding something that
belongs to the owner.

---

## 6. What this pass does NOT cover

- **The physical device.** Not run. It needs the owner's Mac and iPhone, and
  this facelift is not complete without it (`MISTAKES.md` M-06).
- **Safe-area insets.** Still zero under `flutter test`; the shell's inset
  handling is guarded by an existing test but only against synthetic values.
- **SF Pro.** Roboto is a stand-in with similar advance widths, not the font an
  iPhone draws.
- **Gameplay and persistence.** No command, reducer, save, ledger or health path
  was touched. The only test changes outside the UI are the busy-state wait and
  one finder disambiguated by the new World caption.
- **Skills and Craft**, which remain disabled and out of scope.
- **Android.** Untouched, still paused by owner priority.

---

## 6. Known limitations and open judgment calls

1. **Text scale 1.4 at 320 dp is met by stacking, not by fitting.** Two value
   tiles side by side cannot hold `9,999,999` at that scale in 106 dp; the row
   becomes a column. That is the layout yielding rather than the type shrinking,
   which is the right direction, but it makes those cards taller.
2. **The region map does not reach the screen edges.** It is 384 px native at
   ×1 and phones are 393 and 430 dp wide, so a few dp of app ground shows either
   side. Fixing it means a non-integer scale (forbidden, L-18) or new art (out
   of scope for this pass).
3. **`_PlaceRow` colours the current location teal**, which L-16 reserves for
   walking and steps. It predates this pass; the new caption deliberately does
   **not** repeat it, and the question is raised for the owner rather than
   decided here (`RULES.md` G-3). See `JOURNAL/OPEN_QUESTIONS.md` Q-04.
4. **Adventure is still about two screenfuls** before the gather button. The
   removed row and tightened gaps shortened it; the vignette and the activity
   stage are the height, and both are approved presentation.
