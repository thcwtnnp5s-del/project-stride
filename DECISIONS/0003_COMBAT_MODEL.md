# Decision: Combat Model — Turn-Based, Retreat-Not-Death

**Status:** Approved
**Date:** 2026-08-01
**Owner:** Project owner
**Supersedes:** "Turn-based combat for initial prototype — Provisional" in `PROJECT_KERNEL/12_DECISION_LOG.md`

## Context

The Kernel marked turn-based combat provisional and explicitly required review before implementation. `GAME_BIBLE/COMBAT/01_COMBAT_PHILOSOPHY.md` left the choice open between turn-based and time-sliced, and no document defined encounter length, action economy, or the consequence of losing.

Loss consequence was the sharp edge: the Kernel forbids punishment for absence but says nothing about punishment for defeat. A death penalty that destroys walked progress would violate the player promise; a fight with no stakes makes preparation pointless.

Raised as contradictions **C-02** and **C-03** in `STUDIO_INITIALIZATION_REPORT.md`.

## Decision

### Encounter structure

- **Turn-based.** No real-time pressure. The player may take as long as they like on any turn.
- **Approximately 6–12 turns** for an ordinary encounter.
- **Interruptible where practical.** A phone call, a closed app, or a pocketed device must not lose the encounter. Encounter state persists.

### Defeat

Defeat:

- Retreats the player to their most recent safe destination
- Keeps consumables already used consumed
- Resets the encounter
- May require travel or preparation before retrying
- **Never** removes equipment, inventory, skill XP, character XP, or any previous progression

There is no death, no item loss, no XP loss, and no progress rollback in Project Stride.

### Combat progression

Milestone 01 grows combat power through **character progression and equipment only**. Dedicated combat skills and weapon mastery are deferred to Milestone 02.

## Alternatives considered

**Turn-based with a real penalty on loss** (dropped materials, lost progress). Rejected: collides directly with the player promise and the no-punishment non-negotiable. Preparation is already meaningfully rewarded by the retreat cost — spent consumables and the travel back.

**Time-sliced / real-time-lite.** More visceral, but hostile to one-handed use, interruption, and the 30-second micro-session. Rejected.

**Adding a combat skill to the slice.** Rejected: it would let the player grind past the Hollow Guardian instead of preparing for it, which is precisely what `COMBAT_PHILOSOPHY.md` argues against.

## Reasoning

- Turn-based suits the documented session model: micro sessions, interruption, one-handed touch, and readable decisions.
- Retreat-not-death keeps stakes real without breaking the promise. The cost of losing is time, consumables, and the walk back — all recoverable, none punitive.
- Gating the mini-boss on preparation rather than levels makes walking the path to power, which is the whole thesis of the game.

## Consequences

- `StrideCore` owns a deterministic, seeded combat resolver. Given the same state and seed, an encounter always resolves identically — which makes balance testable.
- Encounter state is part of the save. Cold-launching mid-fight resumes the fight.
- Character level supplies HP and a small attack/defence contribution; equipment and consumables supply the rest.
- Enemy design must assume the player *can* retry indefinitely. Difficulty comes from requiring the right preparation, not from attrition.
- Any future proposal introducing a death penalty is a Kernel-level change requiring a new decision record.

## Follow-up

- Update `PROJECT_KERNEL/12_DECISION_LOG.md` (status Provisional → Locked) and `GAME_BIBLE/COMBAT/01_COMBAT_PHILOSOPHY.md`.
- Encounter pacing, action set, and enemy statistics are specified during Phase 4 of `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md`.
