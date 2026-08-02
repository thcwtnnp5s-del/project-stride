# Decision: Milestone 01 Progression Pacing

**Status:** Approved
**Date:** 2026-08-01
**Owner:** Project owner
**Supersedes:** The provisional "4–6 weeks per skill" target in `MILESTONE_01_TASK_BREAKDOWN.md` v1.1 task S-06
**Raised by:** Critic review CR-3 in `CRITIC_REPORT.md`

## Context

The first-pass balance proposal implied 4–6 weeks of walking per skill and, with one activity at a time (`DECISIONS/0006`), 20–30 weeks to exhaust all five skills. The Critic flagged that as a very long feedback loop for a milestone whose purpose is to *validate the loop*.

## Decision

**Milestone 01 must expose and validate the complete loop within roughly one to two weeks of ordinary movement.**

**Completing the vertical slice does not require all five skills to reach level 20.** Level 20 is the cap, not the completion condition.

### Provisional pacing targets

These are **testable balance hypotheses, not immutable constants.**

| Beat | Target |
|---|---|
| First gathering result | First few hundred allocated steps |
| First combat encounter | ~1,000–2,000 total steps |
| First bronze upgrade | ~3,000–6,000 allocated steps |
| Access to the ordinary starter areas | ~10,000–20,000 total steps |
| Reasonable Hollow Guardian readiness | ~25,000–40,000 total allocated steps |
| Level 20 in one skill | Provisionally 60,000–90,000 allocated steps |
| Maxing all five skills | **Not required for Milestone 01 completion** |

At the reference fixture of 7,500 steps/day, Guardian readiness lands around day 4–6 and the full loop is validated well inside two weeks. At the low fixture of 2,500 steps/day it lands around day 10–16 — still inside the intended window.

### Step-count testing fixtures

| Fixture | Steps/day |
|---|---|
| Low | 2,500 |
| Reference | 7,500 |
| High | 15,000 |

**These are simulation fixtures only.** They must never be presented in the game, in documentation, or in any player-facing copy as health recommendations, activity targets, or expected player behavior. Project Stride does not tell anyone how much to walk. `GAME_BIBLE/HEALTH_INTEGRATION/01_APPLE_HEALTH_DESIGN.md` already forbids implying medical interpretation; this extends that to implied behavioral norms.

### Developer/test balance profile

A separate accelerated balance profile exists for QA and automated testing.

- It is a distinct content profile, **not** a modification of production balance data
- Selecting it never mutates, overwrites, or migrates production values
- It is unavailable in release builds
- Automated tests that assert *pacing* run against production values; tests that merely need to *reach a state quickly* may use the accelerated profile

## Alternatives considered

**Keep the long curve.** Rejected: a 20–30 week validation cycle means the milestone's real acceptance criterion — does the owner want to continue — cannot be judged until far too late to act on.

**Shorten by lowering the level cap.** Rejected: the cap of 20 is starter-content identity (`GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md`) and cutting it would shrink the sense of a long game. Better to reach the *loop* quickly and leave the *cap* distant.

## Reasoning

The vertical slice's job is to prove the loop, not to be finished. Front-loading the beats — a gathering result in hundreds of steps, a fight in one or two thousand, bronze in a few thousand — means the player experiences plan → walk → return → craft → fight within the first few days.

Level 20 staying distant at 60,000–90,000 steps is deliberate. It preserves the promise of a game measured in months without gating validation behind it.

## Consequences

- Task S-06's acceptance criteria are replaced by these targets.
- Task V-06's completion criterion no longer implies skill maxing.
- Milestone 01 will be *validatable* long before it is *exhausted*, which is the correct relationship for a vertical slice.
- Every one of these numbers lives in content and is expected to move once real walking data arrives at V-04.

## Follow-up

- `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md` tasks S-05, S-06, V-04, V-06 updated.
- `GAME_BIBLE/BALANCE/01_FIRST_PASS_NUMBERS.md` derives concrete per-node and per-recipe values from these targets during S-06.
