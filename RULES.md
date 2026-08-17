# Project Stride — Rules

Permanent project laws and invariants, stated as **one enforceable line each**.

## What this file is, and what it is not

This is an **index, not a source.** Every rule below is already decided
somewhere else, and that somewhere else stays canonical:

| Canonical for | Lives in |
|---|---|
| Product philosophy and non-negotiables | `PROJECT_KERNEL/` |
| Architectural decisions | `DECISIONS/` (ADRs) |
| Game and design requirements | `GAME_BIBLE/` |
| Current milestone and project state | `PROJECT_STATE.md` |

The value here is that an agent or a reviewer can read **one page** and know
what may not be broken, then follow the reference for the reasoning. Large
blocks are deliberately not copied — a rule restated in two places is a rule
that will eventually disagree with itself.

**Changing a rule requires changing its canonical source first.** Editing this
file alone changes nothing. Kernel-level changes require explicit owner
approval (`STUDIO_OPERATIONS/CHANGE_MANAGEMENT.md`).

A rule appears here only if it has actually been earned — decided by the owner,
recorded in an ADR, or proven by a milestone. Aspirations do not belong here.

---

## Product

**P-1 — Mobile-first, and mobile-only.**
iOS first, Android via Health Connect later. Desktop is not a target.
→ `PROJECT_KERNEL/05_NON_NEGOTIABLES.md`, `DECISIONS/0009`

**P-2 — Solo PvE. No multiplayer, trading, guilds, or PvP.**
→ `PROJECT_KERNEL/05_NON_NEGOTIABLES.md`, `PROJECT_KERNEL/06_ANTI_FEATURES.md`

**P-3 — Real-world steps are the progression input.**
Walking is the engine, not a bonus.
→ `PROJECT_KERNEL/05_NON_NEGOTIABLES.md`, `GAME_BIBLE/SYSTEMS/02_WALKING_INTEGRATION.md`

**P-4 — No wall-clock progression masquerading as walking.**
Time passing is never a substitute for movement. Progression is step-clocked.
→ `DECISIONS/0001_PROGRESSION_CLOCK.md`

**P-5 — Absence is never punished.**
No FOMO, login streaks, expiring rewards, decay, spoilage, or upkeep. Nothing
stored decays or expires — ever.

**Unamended by the Phase 2 economy cutover**, which is a single, deliberate,
owner-authorized re-basing of one body of validation data at a defined point —
not a recurring mechanism, and not something time or absence can trigger. The
retired steps remain reportable. A second epoch would need its own decision.
→ `PROJECT_KERNEL/06_ANTI_FEATURES.md`, `DECISIONS/0008_STEPLESS_WEEK.md`,
`DECISIONS/0016_ECONOMY_EPOCH_CUTOVER.md`

**P-6 — No monetization systems.**
No premium currency, ads, loot boxes, gacha, or battle passes, unless the owner
explicitly reconsiders.
→ `PROJECT_KERNEL/06_ANTI_FEATURES.md`

**P-7 — Defeat costs progress, never possessions.**
Defeat never removes equipment, inventory, skill XP, character XP, or any
previous progression. No death, no item loss, no rollback.
→ `GAME_BIBLE/COMBAT/01_COMBAT_PHILOSOPHY.md`

**P-8 — Offline-first.** Core gameplay never requires connectivity.
→ `PROJECT_KERNEL/05_NON_NEGOTIABLES.md`

---

## Health and step accounting

**H-1 — Observed, granted, spent, and banked are four distinct concepts.**
Observed is what the platform reported; granted is what the ledger credited;
spent is what the player consumed; banked is what remains usable. Collapsing
any two of them is how steps get double-counted or silently lost.
→ `TECHNICAL/STEP_LEDGER_PRIVACY.md`, `F04_COMPLETION_REPORT.md`

**H-2 — Granted is monotonic. There is no clawback.**
Granted energy never decreases. A correction reduces what is *observed*, never
what was already credited.

A **spendable balance** may be re-based, once, by an economy epoch — which moves
a mark, not a counter, and leaves `totalGranted` untouched. That is what makes
the Phase 2 cutover compatible with this rule rather than an exception to it.
→ `DECISIONS/0012_SAVE_FORMAT.md`, `DECISIONS/0016_ECONOMY_EPOCH_CUTOVER.md`

**H-3 — A candidate cursor becomes durable only after safe reconciliation and
save commit.**
The order is inviolable: adapter returns data and a *candidate* cursor →
reconciliation produces grants → ledger and snapshot commit → only then is the
cursor durable. No adapter may cache, advance, or persist one.
→ `DECISIONS/0012_SAVE_FORMAT.md`, `packages/stride_health/lib/src/cursor_authorization.dart`

**H-4 — A cursor may be offered only where the delivery contract permits it.**
Non-final pages offer nothing. `cursorOfferedWhenProhibited` is a real defect
signal and must never be weakened, suppressed in UI, or accommodated by
loosening reconciliation.
→ `MISTAKES.md` M-03, `S01A_PHYSICAL_VALIDATION.md`

**H-5 — Foreground health sync only.**
No `HKObserverQuery`, no background delivery, no background modes, until a
later milestone explicitly authorizes it. Foreground cold-launch backfill is
the source of truth.
→ `DECISIONS/0014_S01A_PRIORITY_AND_SCOPE.md`

**H-6 — First-party native health adapters.**
No third-party health aggregation plugin may be the source of truth for step
data. The never-double-count guarantee is not delegated.
→ `DECISIONS/0010_CROSS_PLATFORM_STACK.md`

**H-7 — Health data privacy is structural.**
No bundle identifier, device name, source name, salt, origin-key byte, or
cursor content is ever logged, displayed, or persisted. Origins are a count;
the cursor is present or absent.
→ `TECHNICAL/STEP_LEDGER_PRIVACY.md`, `Scripts/check-origin-privacy.sh`

---

## Engineering

**E-1 — `stride_core` is pure Dart.**
No Flutter, no plugins, no `dart:io`, no clock, randomness, locale, or platform
reads. Enforced by static scan.
→ `Scripts/check-core-purity.sh`, `TECHNICAL/PROJECT_STRUCTURE.md`

**E-2 — Player-facing UI must not become an alternate source of durable game
state.**
Game mutations flow through the established command → engine/reducer →
persistence path. A widget may read state and dispatch commands; it may not
compute or hold durable state of its own.

An architectural governance rule backed by the current design — deliberately
**not** backed by an ADR, guard, or test, and not a request for one.
→ `TECHNICAL/PROJECT_STRUCTURE.md`, `ARCHITECTURE_IMPLEMENTATION_PLAN.md`

**E-3 — Single-writer persistence.**
No background isolate, callback, worker, or platform entry point may
instantiate `SaveRepository`, construct filesystem persistence stores, or touch
the save directory directly.
→ `DECISIONS/0013_SINGLE_WRITER_PERSISTENCE.md`, `Scripts/check-single-writer.sh`

**E-4 — Under-settle rather than over-settle.**
Where the platform contradicts itself, choose the option that settles fewer
buckets and grants no more steps. Under-settling costs a little ledger growth;
over-settling buries steps permanently. The two errors are not symmetric.
→ `packages/stride_health/lib/src/platform_step_source.dart`

**E-5 — Content is data, not code.**
Data-driven content wherever practical; no hardcoded game content.
→ `PROJECT_KERNEL/05_NON_NEGOTIABLES.md`

**E-6 — A content set is not proven until something plays it.**
Reference validation, reachability, and graph checks answer *is this possible*.
They cannot answer *would anyone find it*, and a chain that is completable only
in an order nobody would guess passes every one of them.
→ `MISTAKES.md` M-07, `packages/stride_core/test/phase2_loop_budget_test.dart`

---

## Governance

**G-1 — Verification must stay proportional to the risk being changed.**
The smallest focused regression proof plus existing CI and guards is the
default. A new verification framework or a repeated-validation campaign
requires a **concrete uncovered risk**, named before the work starts.
→ `MISTAKES.md` M-01

**G-2 — Toolchain and CI upgrades are explicit work, never incidental drift.**
Versions are pinned. An upgrade gets its own branch, its own reformatting, its
own full run, and its own decision — never a side effect of another task.
→ `MISTAKES.md` M-02, `.github/workflows/ci.yml`

**G-3 — Unresolved design choices stay visibly unresolved.**
Label them `UNRESOLVED` and record them in `JOURNAL/OPEN_QUESTIONS.md`. An
agent may not silently pick one to keep moving, and an implementation detail
must never quietly become a design decision.
→ `PROJECT_KERNEL/11_AI_OPERATING_INSTRUCTIONS.md`

**G-4 — Never weaken an invariant to make a test pass.**
A failing guard is evidence about the code, not about the guard. Suppressing a
fault, loosening an assertion, or accommodating a violation upstream is a
change to the rule and requires the rule's owner.
→ `MISTAKES.md` M-03

**G-5 — Durable knowledge belongs in repository documents.**
Anything a future session must know goes into the repo — a decision, a spec, a
state update, a mistake entry. Chat memory is not project memory.
→ `PROJECT_KERNEL/11_AI_OPERATING_INSTRUCTIONS.md`

**G-6 — Documentation is part of done.**
A milestone is not closed until `PROJECT_STATE.md` and the affected canonical
documents reflect reality.
→ `STUDIO_OPERATIONS/WORKFLOW.md`

**G-7 — One canonical home per concept.**
No document duplicates another's authority. New requirements extend the
existing canonical location rather than opening a second one.
