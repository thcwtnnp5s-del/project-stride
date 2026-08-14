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
