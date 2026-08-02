# Decision: Stepless-Week Behavior

**Status:** Approved
**Date:** 2026-08-01
**Owner:** Project owner
**Answers:** `JOURNAL/OPEN_QUESTIONS.md` Q-01, raised as CR-1 in `CRITIC_REPORT.md`

## Context

The Critic flagged that step-clocked progression has no answer for a genuinely stepless week — illness, injury, a desk-bound deadline. A player with zero banked steps and an empty inventory opens an app with nothing to do, which sits awkwardly against the player promise of a world that feels welcoming rather than demanding.

## Decision

**Progression remains step-clocked only.** `DECISIONS/0001` is unchanged and is not reopened.

The governing principle:

> **Steps govern the rate at which new opportunities are created, but previously earned opportunities remain available indefinitely.**

### With no new steps, the player may still

- Craft from owned resources
- Manage inventory and equipment
- Review goals, skills, lore, and discoveries
- Fight previously unlocked encounters
- Retry bosses, when they retain the necessary supplies
- Spend previously banked movement progress, which never expires
- Plan future activities

### With no new steps, the player may not

- Gain new travel progress
- Gain new gathering progress
- Gain new resources
- Gain new skill progression

— from wall-clock time alone. Time is never an input to progression.

### No decay, ever

No stored progress decays or expires. Not banked steps, not partial activity progress, not resources, not skill XP, not discoveries, not equipment. There is no upkeep, no spoilage, no rust, and no timer counting down anywhere in Project Stride.

## Reasoning

The distinction that resolves Q-01 is between *creating* opportunity and *consuming* it. Walking creates; the player consumes on their own schedule, forever. A stepless week costs the player new opportunity — which is honest, since they did not walk — but takes nothing away and closes nothing off.

Every affordance in the list above already exists in the Milestone 01 slice. That is the substance of the answer: this is not a new system, it is a guarantee about the existing ones, plus a balance goal that the player should generally have something banked to build, read, or fight.

## Consequences

- The "steps gate rate, never access" rule in `GAME_BIBLE/SYSTEMS/02_WALKING_INTEGRATION.md` is strengthened into this fuller principle.
- Boss retries must not require freshly-walked steps. If a player has the supplies, they can fight — which is consistent with retreat-not-death (`DECISIONS/0003`).
- Balance work carries a soft goal: a player at a natural stopping point should typically have a crafting backlog or an unlocked encounter available. This is a tuning target for `GAME_BIBLE/BALANCE/`, not an enforced mechanic.
- Any future proposal involving decay, spoilage, upkeep, or expiry contradicts this decision and `PROJECT_KERNEL/06_ANTI_FEATURES.md`, and requires explicit owner approval.
- QA must verify it: a zero-step session is playable, calm, and non-judgemental.

## Follow-up

- `GAME_BIBLE/SYSTEMS/02_WALKING_INTEGRATION.md` updated with the principle.
- `JOURNAL/OPEN_QUESTIONS.md` Q-01 marked answered.
- Acceptance criteria added to tasks S-03, C-02, P-03, and V-01.
