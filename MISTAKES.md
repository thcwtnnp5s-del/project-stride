# Project Stride — Mistakes

An evidence log of **durable lessons**, newest first.

## What belongs here

Only mistakes worth preventing again: architectural errors, process failures,
and recurring patterns. Each entry states what happened, why, what it cost, and
what prevents recurrence.

**This is not a bug diary.** An ordinary defect found and fixed inside its own
task does not belong here. A defect that reveals something about how the
project works — or how it goes wrong — does.

> **Repeated mistakes may graduate into `RULES.md`** when they represent a
> recurring pattern rather than a single incident. A rule that exists only as a
> war story is a rule nobody can enforce.

Entries are numbered in order of recording and never renumbered, so a reference
to `M-02` stays valid.

---

## M-06 — A UI was declared done on evidence that was structurally blind to how it looked

**Date:** 2026-08-16 · **Category:** process / verification ·
**Provenance:** Playable Demo Phase 1, `MILESTONES/PLAYABLE_DEMO_PHASE_1_CLOSEOUT.md` §4

### What happened

Playable Demo Phase 1's product UI passed **93 widget tests and four golden
images** and was carried as complete. The first time it was run on a device, it
had three visible defects — one of them affecting **every string in the
application**.

| Defect | Visible severity |
|---|---|
| No `Material` ancestor, so `DefaultTextStyle` resolved to Flutter's fallback — which carries `TextDecoration.underline` in double yellow | Every word in the product was underlined |
| The inventory `GridView` defaulted to `primary: true` and adopted `MediaQuery.padding` | 57 dp of dead space above the first row |
| The region list iterated `locations` alphabetically | "Where am I?" was answered with a place the player has never been |

### Root cause

**The two evidence sources were blind to these defect classes by construction,
and nobody had written down that they were.**

- `flutter test` has **no real font**. Its harness draws every glyph as a filled
  rectangle, so a golden image cannot show an underline, a wrong weight, a
  clipped descender, or any typographic fault at all. The underline merged into
  the box.
- `flutter test` supplies **zero safe-area insets**. Any defect that is a
  function of real device padding measures as exactly 0 under test. The
  inventory gap was not "small in the test" — it was *absent*, and present on
  hardware.
- Widget tests assert a string's **content**. Almost none assert its resolved
  style, so decoration, colour and weight are unguarded unless someone
  deliberately reaches for them.

The count of passing tests was doing work it could not do. 93 green tests
created confidence about *appearance*, which is not what any of them measured.

### Consequence

Caught before the owner saw it, at the cost of one device pass. Had the physical
acceptance run happened first, the owner's report would have opened with "every
word is underlined" — and the two-week judgment about whether Stride *feels*
right would have been taken against a build that looked broken.

### Prevention

- **A UI is not done until it has been looked at, running, on a device.** No
  count of green tests substitutes. This is the same lesson as M-04 — a
  technically correct change reported as a fix without perceptual verification —
  arriving through automated tests rather than through pixel measurements.
- **Golden images are regression evidence between framework revisions, and
  nothing else.** They cannot judge type. `PLAYABLE_DEMO_PHASE_1_ACCEPTANCE.md`
  already said so in prose; it needed saying where the goldens are generated,
  and now is.
- When a device pass finds a defect a test *could* have caught, **add the test
  that asserts the resolved property**, not the widget that happens to fix it.
  The underline guard asserts the inherited `TextStyle`, so it still fails if a
  `Material` is added somewhere that does not cover every screen.
- Prefer **verifying the harness's blind spots explicitly** over trusting a
  green total: insets, text scaling, and type all need a real surface.

**This does not license a verification campaign** (`RULES.md` G-1). One device
pass, on the screens that changed, with the findings written down.

### Update — 2026-08-16, third occurrence, and what finally changed

D-01 was the third instance: a fixed 72 dp box clipped the last digit off
`455,281` on the owner's phone while five overflow tests and four goldens passed.
Neither could have caught it. `TextOverflow.clip` **raises no exception**, so
`takeException() == null` is satisfied by a clipped string and an intact one
alike; and the goldens rendered `12,480`, six characters, which fits the box that
seven did not.

UI Facelift 01 changed the instruments rather than adding more of the same, and
the change is the durable part:

- **Assert the property, not the absence of an exception.** For every
  single-line paragraph in the tree, the width the text *needs* is compared with
  the width layout *gave* it. That is a screen-wide clipping detector, and it is
  what the old tests were reaching for and could not express.
- **A test that measures type needs type.** `flutter test`'s fallback font draws
  every glyph as a filled rectangle about 0.84 em wide, against Roboto's 0.55 —
  so a width assertion against it is a measurement of the harness, and "fixing"
  the app to satisfy it would shrink real type for a fake reason. A real face is
  now loaded, and its **absence fails rather than skips**.
- **Fixtures must resemble accepted saves.** The stress values are the device
  run's own figures, and a golden set now renders 455,281 beside the old 12,480.

The measurement's first run found **two further on-device defects nothing in the
repository could see**: `EXPERIENCE` clipped in the third cost tile at every
supported width, and the step cost `90` given 16 dp where it needed 19.8. Both
had shipped. Changing the instrument found in one run what looking harder had
not found in three.

The rest of M-06 stands unchanged, and the first line of it most of all: **none
of this replaces looking at a device.**

---

## M-05 — Visual decisions were made without a play-scale verdict view

**Date:** 2026-08-14 · **Category:** process / visual production ·
**Graduated to:** `PIXEL_ART_CRAFT_SPEC.md` §8,
`STUDIO_OPERATIONS/AGENT_ORCHESTRATION.md` — *Target scale and the standard
output set*

### What happened

`VISUAL_STUDIO_BASELINE_AUDIT_01` found that **no ×2 render existed anywhere in
the repository**. `TRAVELER_REFINE_03/out/` held fifteen ×8 files, three natives
and no ×2; the only available character context views were ×8 crops. Every
Traveler decision to that point had been taken on that evidence set.

### Root cause

The exploration renderers emitted native and ×8 inspection views and no ×2
play-scale proxy — not by omission in any one pass, but because each `render.js`
selected a single `SCALE` constant and wrote only that view. Review therefore
judged player-facing readability at a scale that enlarged and flattered
low-resolution detail.

**This is distinct from M-04.** M-04 is about who was permitted to judge. M-05 is
about what they were given to judge: the evidence set did not contain the view the
verdict required, so even a correctly independent reviewer would have been
deciding at the wrong scale.

### Consequence

Several Traveler defects survived repeated review because they were more legible
at ×8 than at likely game scale — hands, equipment silhouettes, material
separation, and the small corrective changes made across three passes. Blind
review later confirmed the pattern directly: the ×8 view distinguished versions
that were indistinguishable at ×2, and the single clearest piece of object craft
in the set was invisible at play scale.

### Prevention

- **Every meaningful visual review set includes ×2**, and ×2 is the verdict view.
- **×8 is inspection only** and never sufficient for graduation.
- **True in-context views must reflect actual presentation scale.** An enlarged
  crop is not a context view.
- **Silhouette-only output is required for major character work.**
- **A visual pass without the required verdict view is returned unreviewed** —
  not reviewed at whichever scale happens to be available.

### Evidence

`VISUAL_STUDIO_BASELINE_AUDIT_01`, 2026-08-14 · `TRAVELER_REFINE_03/out/`
(18 files, no ×2) · `GAME_BIBLE/ART/exploration/CODE_RENDER_01/review_set.js`

---

## M-04 — A technically correct pixel change was reported as a fix without perceptual verification

**Date:** 2026-08-14 · **Category:** process / visual production ·
**Graduated to:** `PIXEL_ART_CRAFT_SPEC.md` CR-41,
`STUDIO_OPERATIONS/AGENT_ORCHESTRATION.md` — Visual Studio

### What happened

Across three consecutive Traveler passes, the implementation report described
substantial, defensible source-level corrections — dozens of moved pixels, a
repositioned sword, a re-silhouetted pack, a palette separation — and the owner
looked at the before and after images and said they basically looked the same.

### Root cause

**The agent that authored the pixels was also the only judge of whether they
worked, and it judged them against source intent rather than against the rendered
image at the scale a player would see.** Every claim was true at the level of the
sprite map and unverified at the level of perception. The final pass then ended
with a single self-written line, `GRADUATE TRAVELER — YES`, with no independent
assessment beside it.

Two multipliers: review happened at ×8, which flatters everything and hid reads
that failed at play scale; and the source carried explicit semantic labels —
`PACK`, `SWORD`, *"the strap terminates ON the bag"* — so any reviewer with
access to it was told what to see before looking.

### Consequence

Owner review rounds spent on corrections the owner could not perceive, and a
character reported as ready that the owner still read as carrying a shield.

### Prevention

- **The perceptual law.** Source intent gets no credit — not a variable name, a
  comment, a pixel count, or a passing assertion.
- **Blind semantic read.** The critic sees neutrally staged renders before any
  intent, name, source, or version label. Staging enforces this, not intentions.
- **Perceptual delta test.** Before/after shown unlabelled and randomised. A
  correction the author called significant that reads *functionally the same* has
  not solved the problem.
- **A ×2 play-scale proxy in every render set.** ×8 is inspection scale, never
  verdict scale.
- **Separate AUTHOR ASSESSMENT and QA VERDICT lines.** The author never writes
  the second one.

### Evidence

Owner review of `TRAVELER_REFINE_03`, 2026-08-14 · the R03F → R03C correction
(53 pixels changed, reported as significant) · `AGENTS/visual_qa.md`

---

## M-03 — A HealthKit candidate cursor was offered on non-final pages

**Date:** 2026-08-13 · **Category:** architecture · **Graduated to:** `RULES.md` H-4, G-4

### What happened

The first sync on a real iPhone drained in eight pages and reported seven
`cursorOfferedWhenProhibited` faults — one per non-final page.

### Root cause

`HKAnchoredObjectQuery` returns one updated anchor per page, and that anchor is
the correct value for two different things. As a **continuation** it means
"carry on from here", which is true mid-read. As a **candidate cursor** it means
"you have seen everything up to here", which on page one of eight is false.

`HealthKitStepStore` assigned it to both on every page, and
`HealthKitAdapter.map` forwarded it as `nextCursor` without consulting
`isFinalPage` — **the only one of that page's three outbound fields that was not
gated on it**, sitting directly beside a completeness assertion and a
continuation that both were.

The Kotlin adapter already had the gate and a multi-page test for it. iOS was
the outlier, and every Swift test that supplied an anchor also declared its page
final, so 46 green tests said nothing about eight real pages of the defect.

### Consequence

**None to the player, and that is the important part.** `authorizeCursor`
refused all seven, the bridge dropped them, and only the eighth cursor reached
the save. No step was skipped or double-granted, and the save was never reset.

The real cost was to the **signal**: a correct adapter tripped the fault channel
during ordinary operation, and a fault that fires on every normal read is one
nobody will read when it matters.

### Prevention

- Where one native value feeds several outbound fields, **gate every field on
  the same page state**, or the ungated one becomes the defect.
- When two platform adapters implement one contract, a rule present in one and
  absent in the other is a defect, not a style difference. Compare them.
- A test that supplies a mid-read value must **declare the page mid-read**.
  Fixtures that always take the easy path test only the easy path.
- Never weaken the fault that caught it. The refusal was correct throughout.

### Evidence

Fix `5b68d33` · closure `6b6f596` · `S01A_PHYSICAL_VALIDATION.md` ·
`packages/stride_health/test/multi_page_cursor_regression_test.dart` ·
`packages/stride_health/example/ios/RunnerTests/RunnerTests.swift`

---

## M-02 — CI floated on Flutter `stable` and moved 3.44.8 → 3.47.0 unannounced

**Date:** 2026-08-13 · **Category:** toolchain / process · **Graduated to:** `RULES.md` G-2

### What happened

The workflow requested `channel: stable` with no version. Stable moved from
3.44.8 to 3.47.0, `dart format` changed its output, and the format check began
failing on three files nobody had touched since early August — all three
byte-identical to master.

### Root cause

An unpinned toolchain. CI ran against whatever stable was on the day, so a run's
result depended on the **date it was started** rather than on the commit.

### Consequence

The failure landed in the middle of an unrelated HealthKit defect fix and
blocked the macOS job, which `needs: [core, pigeon]` — so a formatter version
bump silently withheld the Swift and iOS evidence the fix was waiting on. It
also cost a round of diagnosis to establish the failure was not caused by the
change under review.

### Prevention

- **Pin toolchain versions exactly.** The version CI uses and the version the
  project develops on must be the same version, and must be stated.
- A toolchain upgrade is **its own task, on its own branch**, with its own
  reformatting and its own full run. It is never absorbed into unrelated work.
- When CI fails, establish whether the failing files are even in the change
  before fixing anything.

### Evidence

Pin `853b293` · `.github/workflows/ci.yml` · follow-up recorded in
`PROJECT_STATE.md` (deliberate Flutter 3.47 evaluation, not yet scheduled)

---

## M-01 — Verification depth expanded beyond the risk being covered

**Date:** 2026-08 · **Category:** process / governance · **Graduated to:** `RULES.md` G-1

### What happened

During Commit B, verification expanded substantially beyond the minimum
evidence required to close the feature. The work included broad causality,
falsification, supervisor, and mutation validation, plus a proposed
repeated-run validation campaign.

### Root cause

Verification ceased being purely risk-driven and began **generating additional
verification work of its own**. Each layer suggested the next, and no step in
that sequence was gated on a named uncovered risk.

### Consequence

Player-facing progress slowed despite strong existing regression evidence
already being in place.

### Prevention

- Verification must remain **proportional to a concrete uncovered risk**.
- Prefer the smallest focused regression proof plus existing CI and guards.
- A new verification framework, or a repeated validation campaign, requires an
  **explicit uncovered risk named before the work begins**. "It would be more
  rigorous" is not such a risk.
- Depth of verification is a scope decision and belongs to the owner.

### Provenance

Owner and project review during Commit B closure, 2026-08.

**This is a process lesson, not a defect attributable to any one code commit.**
No repository citation is offered for the management judgment, because the
judgment was made in review rather than recorded in a commit — and inventing a
citation for it would make this log less trustworthy, not more. Commit B
artifacts and `PROJECT_STATE.md` provide supporting context only.
