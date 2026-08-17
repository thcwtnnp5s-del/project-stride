# 0016 — The playable step economy begins at an epoch, not at zero granted

**Status:** Approved
**Date:** 2026-08-17
**Owner:** project owner
**Supersedes:** nothing
**Graduates:** `JOURNAL/OPEN_QUESTIONS.md` **OD-01**
**Amends:** `DECISIONS/0012_SAVE_FORMAT.md` — state version 2

---

## Context

Playable Demo Phase 1 closed with the owner's device holding **459,043 banked
steps** against **459,223 granted**. Those steps are real: the device observed
them, the ledger credited them, and the player walked them. But they were
accumulated by an integration proving it could count, across weeks of HealthKit
backfill validation — not by a player choosing to walk toward anything.

At roughly 90 steps per gather that balance is about five thousand actions
already paid for. Building Phase 2's progression on top of it would mean the
first playable economy started fully funded, and every pacing judgment the owner
made in the following weeks would be a judgment about a game nobody will play.

The owner directed a one-time cutover (`OD-01`). This ADR is the design.

## The constraint that shapes the whole decision

Three project laws bear on it, and two of them forbid the obvious
implementations outright:

| Rule | What it forbids here |
|---|---|
| **H-2** — granted is monotonic, no clawback | Lowering `totalGranted`. A cutover that subtracts is a clawback. |
| **H-3** — the cursor prevents double-counting | Rewinding or discarding the sync cursor. That re-grants the retention window — the precise failure two device runs proved absent. |
| **P-5** — nothing decays, earned opportunity never expires | Any *recurring* retirement of banked steps. |

`OD-01` had already narrowed the field to the right answer: *"the second
preserves H-2 by construction and is the one to cost first."*

## Decision

**The step ledger records an `EconomyEpoch` — the point on both running totals
at which the playable economy began — and `banked` is measured from that mark.**

```text
banked = (totalGranted - epoch.grantedAtStart) - (totalSpent - epoch.spentAtStart)
```

Nothing is subtracted. Nothing is deleted. Nothing is rewound. `totalObserved`,
`totalGranted`, `totalSpent`, `grantedSlices`, `grantedBeforeWatermark`, the
cursor, the per-origin watermarks and the sync count all pass through the cutover
byte-identical — asserted directly, by rebuilding the migrated ledger with the
epoch put back to the origin and comparing the whole canonical encoding
(`economy_epoch_cutover_test.dart`, group 3).

### Why both counters and not just granted

The Phase 1 save had also spent 180 steps on the acceptance gathers. Marking only
granted would leave `banked` at −180 the instant the epoch was set, and the
ledger's own invariant would reject the state. A balance is the difference of two
running totals, so the mark is a point on both axes. This is asserted as
unrepresentable rather than merely avoided.

### Why it is a generalization rather than a special case

A new game marks the epoch at `(0, 0)`, under which the formula reduces exactly
to the pre-epoch `granted - spent`. There is therefore no "is an epoch in
effect?" branch anywhere in the codebase, and the old behaviour is not a legacy
path — it is this path, with the mark at the origin.

### Exactly-once is the state version, and nothing else

`StateVersion.current` becomes **2**. A v1 save decodes with the origin epoch —
which is not a fallback but what a v1 save meant — and `migrationRequired` is
true for it. `BootstrapCoordinator._migrate` reshapes the state, issues the
internal `EstablishEconomyEpoch` command, and commits. The committed save is v2,
so the next launch never enters the path.

A boolean flag beside the version was considered and rejected: two mechanisms
recording one fact are two mechanisms that will eventually disagree. The version
is already durable, already checked for header/payload agreement by
`SaveRepository`, and already the thing a decoder is chosen by.

The command *also* refuses a non-origin epoch, and that is defence behind the
version rather than a second source of truth — a command that can zero a
player's balance should say so out loud if anything ever asks it twice.

### Crash safety falls out of purity

Every step before the commit is a pure function of the loaded state. If the
process dies at any point, the pre-migration save is on disk unchanged and the
next launch derives an identical migration from identical inputs. There is no
partial state to detect and no repair to run, because nothing was written. A
migration that cannot be committed **blocks startup** rather than being played
in memory — see `BootstrapBlockReason.stateMigrationNotCommittable` for why the
alternative is a permanently wrong balance.

## How this squares with P-5

`OD-01` flagged this as Kernel-adjacent and it is worth answering plainly rather
than by assertion.

**P-5 forbids decay, expiry, FOMO, streaks, and upkeep — recurring mechanisms
that take back what a player earned as a consequence of time passing or of
absence.** None of that is present here. No banked step is removed by the passage
of time, by absence, or by any rule that will fire again. The epoch is a
**single, deliberate, owner-authorized cutover** retiring one specific body of
validation data, at a defined point, once, with no code path capable of moving it
a second time.

The retired steps also remain **reportable**. `totalGranted` still carries every
one of them and `EconomyEpoch.retiredSteps` still names them, so the product can
truthfully say what the owner has walked. A cutover that made the history
unreportable would be a product lying about the walking it exists to celebrate,
and that would be a genuine P-5 problem rather than this one.

**P-5 is unamended and applies in full going forward.** A second epoch would need
its own decision and would have to answer this question again, less easily.

## Consequences

- `steps.epoch` is persisted: two integers, reviewed for privacy
  (`save_privacy_test.dart`). Both are aggregates of figures the ledger already
  persists in the clear, so the epoch discloses nothing `totalGranted` does not —
  no bucket, no timestamp, no origin, no cursor content.
- The frozen v1 save fixture is **unchanged**. Its round-trip test becomes
  decode-only, exactly as `save_migration_test.dart`'s regeneration policy
  instructed, and a new frozen `v2_baseline.save` carries the byte-exact
  round-trip forward. The v2 fixture is the v1 fixture put through the real
  migration, by `tool/generate_v2_baseline.dart`, run once.
- The persistence conformance transcript's two slot digests moved. Every
  behavioural line above them is byte-identical, and the +46-byte delta is the
  exact length of the inserted JSON — checked, not accepted.
- `BootstrapExistingGame` gains `migration` and `expectation`. Callers must use
  `expectation` rather than `load` to build a `CommitExpectation`, because a
  migration commits between them.

## What was rejected

| Option | Why not |
|---|---|
| Subtract from `totalGranted` | Contradicts H-2 outright. Also loses the history. |
| Raise `totalSpent` to `totalGranted` | Legal by the invariant and preserves granted, but conflates "retired at migration" with "spent on activities" in every diagnostic that reads `totalSpent`. The two are different facts and the ledger's whole design is about not collapsing different facts. |
| A fresh ledger | Discards the cursor and the granted slices, which is H-3 exactly. |
| Rewind the cursor and re-import | The failure mode the architecture exists to prevent. |
| A single `stepsForfeited` counter | Works, but says less: it records that something was retired without recording where the economy began, and it cannot express the spent axis without a second field anyway. |
