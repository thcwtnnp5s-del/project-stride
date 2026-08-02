# Decision: Progression Clock — Step-Clocked Only

**Status:** Approved
**Date:** 2026-08-01
**Owner:** Project owner
**Supersedes:** Ambiguous "idle RPG" framing in `PROJECT_KERNEL/00_PROJECT.md` and `PROJECT_STATE.md`

## Context

The Kernel described Project Stride as a "solo idle RPG" and borrowed "idle planning" from Melvor Idle, while simultaneously locking "walking is core gameplay" and making steps the input to travel, gathering, and exploration. These describe two incompatible games: one where activities tick on wall-clock time, and one where they advance only on earned steps.

Raised as contradiction **C-01** in `STUDIO_INITIALIZATION_REPORT.md`.

## Decision

**Progress is step-clocked only.**

Activities advance only from newly earned, reconciled steps. No gathering, travel, crafting, or character progression accrues from wall-clock time alone.

Earned steps may be reconciled, and their outcomes processed, when the player next opens the app. The player never needs to keep the app running, keep it foregrounded, or return within any window.

"Idle" in Project Stride means **asynchronous planning, offline step reconciliation, and delayed collection** — not passive wall-clock progression.

Where a short description is useful, Project Stride is:

> A step-powered asynchronous RPG with idle-style planning.

## Alternatives considered

**Time-clocked with a step multiplier.** Activities tick on wall-clock time; steps accelerate them. Rejected: it makes walking a bonus rather than the engine, contradicting the locked decision "walking is core gameplay" and the project's stated *why*.

**Hybrid — steps for travel, time for gathering.** Rejected: two progression models to balance, and it blurs what walking is actually for.

## Reasoning

- It is the only reading consistent with `PROJECT_KERNEL/12_DECISION_LOG.md` → "Walking is core gameplay: Locked."
- It preserves the emotional target — "I was already going to take that walk. Now it meant something." A time-clock makes the walk optional.
- It is simpler to reason about, balance, and test. There is one input to the simulation.
- It removes any temptation toward engagement mechanics built on elapsed time.

## Consequences

- The word "idle" is retired from the Kernel as a genre label and redefined in the glossary.
- `StrideCore` advances the simulation as a pure function of consumed steps. Wall-clock time is **not** an input to activity progress. Time may still be recorded for display ("last synced", "you were away for 3 days") and for narrative flavour, never for progression.
- Deterministic testing becomes straightforward: feed N steps, assert exact outcomes. No clock mocking in the core.
- Absence produces exactly the progress the player's steps earned, no more and no less. This satisfies "no punishment for inactivity" without needing a separate rule.
- Any future proposal for time-based accrual (crop growth, forge smelting over hours, rested bonuses) is a Kernel-level change requiring a new decision record.

## Follow-up

- Update `PROJECT_KERNEL/00_PROJECT.md`, `PROJECT_KERNEL/08_GLOSSARY.md`, `PROJECT_KERNEL/13_INSPIRATION.md`, and `PROJECT_STATE.md`.
- Reflected in `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §Step reconciliation model and §Application architecture.
