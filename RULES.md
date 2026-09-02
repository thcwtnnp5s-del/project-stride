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

One named exception, owner-ruled on hardware: a **finite, player-initiated
activity queue** advances by elapsed real time across background and
relaunch — every completion still spends banked steps through the unchanged
gather semantics, so time paces the conversion of walking, never replaces
it. Nothing else may cite this exception; a second one needs its own
decision.
→ `DECISIONS/0001_PROGRESSION_CLOCK.md`,
`DECISIONS/0022_FINITE_BACKGROUND_ACTIVITY.md`

**P-5 — Absence is never punished.**
No FOMO, login streaks, expiring rewards, decay, spoilage, or upkeep. Nothing
stored decays or expires — ever.

**Unamended by the Phase 2 economy cutover**, which is a single, deliberate,
owner-authorized re-basing of one body of validation data at a defined point —
not a recurring mechanism, and not something time or absence can trigger. The
retired steps remain reportable. A second epoch would need its own decision —
and has one: the Transformation playtest epoch, a second and equally singular
owner-authorised re-basing, after which any re-basing must be a named migration
table step — or a brand-new game's own first authorised reconcile, retired once
as the game's baseline (`0019`) — or, third and last, the owner's own
**playtest reset** (`0025`): a confirmed player command that moves the same
mark and a walked baseline, may run again because each run is a deliberate
act, and can never fire from time, absence, or a side effect. Still unamended.
→ `PROJECT_KERNEL/06_ANTI_FEATURES.md`, `DECISIONS/0008_STEPLESS_WEEK.md`,
`DECISIONS/0016_ECONOMY_EPOCH_CUTOVER.md`,
`DECISIONS/0018_TRANSFORMATION_PLAYTEST_EPOCH.md`, `DECISIONS/0019_NEW_GAME_BASELINE.md`,
`DECISIONS/0025_PLAYTEST_RESET.md`

**P-6 — No monetization systems.**
No premium currency, ads, loot boxes, gacha, or battle passes, unless the owner
explicitly reconsiders.
→ `PROJECT_KERNEL/06_ANTI_FEATURES.md`

**P-7 — Defeat costs progress, never possessions.**
Defeat never removes equipment, inventory, skill XP, character XP, or any
previous progression. No death, no item loss, no rollback.
→ `GAME_BIBLE/COMBAT/01_COMBAT_PHILOSOPHY.md`, `DECISIONS/0020_COMBAT_SLICE_01.md`

**P-8 — Offline-first.** Core gameplay never requires connectivity.
→ `PROJECT_KERNEL/05_NON_NEGOTIABLES.md`

**P-9 — Goal tracking never reserves, escrows, or auto-spends steps.**
A tracked Journey, Pursuit, or Contract is information: every figure it shows
is a live projection, clearing it changes no economy figure, and nothing
tracked expires. Spending remains an explicit player command, always.
→ `DECISIONS/0023_EXPLORATION_PROGRESSION_LOOP.md`,
`GAME_BIBLE/SYSTEMS/09_EXPLORATION_PROGRESSION_LOOP.md`

**P-10 — Repeatable RNG is never load-bearing, and permanent effects apply
exactly once.**
Nothing a contract, recipe, or project *requires* is a low-chance drop;
signature rares are trophies, not ingredients, and bounties count only
deterministic post-acceptance victories. A completed community project is
permanent, and its effects are content-declared predicates over the set of
completed projects — structurally incapable of double application on replay.
→ `DECISIONS/0023_EXPLORATION_PROGRESSION_LOOP.md`,
`GAME_BIBLE/SYSTEMS/09_EXPLORATION_PROGRESSION_LOOP.md`

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

A **spendable balance** may be re-based by an economy epoch — which moves a
mark, not a counter, and leaves `totalGranted` untouched. That is what makes
the Phase 2 cutover and the Transformation playtest epoch compatible with this
rule rather than exceptions to it. Only a migration table step that names its
decision, a new game's one-time baseline (`0019`), or the owner's confirmed
playtest reset (`0025`) may set the mark — and the reset sets the
player-facing walked baseline at the same point, leaving `totalGranted`, the
slices, the watermarks and the cursor exactly as they were.
→ `DECISIONS/0012_SAVE_FORMAT.md`, `DECISIONS/0016_ECONOMY_EPOCH_CUTOVER.md`,
`DECISIONS/0018_TRANSFORMATION_PLAYTEST_EPOCH.md`, `DECISIONS/0019_NEW_GAME_BASELINE.md`,
`DECISIONS/0025_PLAYTEST_RESET.md`

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

**G-8 — Stage explicit paths. Never `git add -A` or `git add .`**
Name the paths a commit is for, or read `git status --short` before committing.
A blind stage published 929 untracked files — including third-party reference
imagery marked `DO NOT COMMIT` — to a public repository, and required a history
rewrite to undo. A commit that adds far more files than its message describes is
a defect signal, not a tidy-up.
→ `MISTAKES.md` M-08

---

## Production art

**A-1 — PixelLab is the production-art and production-animation engine.**
Claude may art-direct, prompt, select outputs, edit and inpaint through
PixelLab, and integrate the results. Claude may **not** manufacture new
production artwork or animation frames in code when PixelLab can do the creative
task. Where PixelLab fails: preserve the temporary asset, record the failure,
escalate — never silently substitute code-drawn art.
→ owner direction, 2026-08-17

**A-2 — Deterministic transformation of approved art is not authoring.**
Crop, nearest-neighbour scale, sprite-sheet assembly, keying, palette or index
remap, selected/disabled-state derivation, and format conversion are permitted
in code, **provided they invent no new object, silhouette, animation frame, or
illustrated content.** The nav `_hi` variants are a derivation of this kind and
stand.
→ owner direction, 2026-08-17

**A-3 — Production atlas expansions are transition-authored across every
boundary.** Tile-local generation plus seam blending, palette conform, or a seam
metric is triage, not evidence of visual continuity: no generated boundary ships
until a blind read at iPhone-viewport scale confirms biome, coastline,
detail-scale and palette continuity, and no visible generated rectangle remains.
→ `MISTAKES.md` M-12, M-14

**A-4 — Approved atlas interiors are protected in tooling, and a repair may
write only its transition band.** The composition pipeline snapshots the
approved interior before any repair layer, restores every repair pixel deeper
than the narrow rim band, and fails packaging on any core drift. Repainting
approved geography to solve a seam is a defect, not a technique; masks are
authored in or outside the band.
→ `MISTAKES.md` M-15, `Scripts/art/package-art.js` (protected interior),
`MILESTONES/WORLD_ATLAS_RESTORE_01.md`,
`DECISIONS/0033_ATLAS_REBASELINE_AUTHORITY.md` (how an approved interior is
replaced: re-baselined in the same commit, never by weakening the guard)
