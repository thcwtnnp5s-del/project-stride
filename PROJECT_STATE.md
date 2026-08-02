# Project Stride — Project State

**Version:** 1.1
**Status:** Studio initialized; foundation decisions approved
**Current Phase:** Milestone 01 planning — architecture and task breakdown under review

## Project identity

Project Stride is a mobile-first, solo **step-powered asynchronous RPG with idle-style planning**, with MMO-style long-term progression. Real-world walking powers travel, gathering, exploration, crafting preparation, and adventure.

Progression is step-clocked: activities advance only from earned steps, never from wall-clock time. "Idle" means asynchronous planning, offline reconciliation, and delayed collection.

## Current design status

Completed foundations:

- Project identity and vision
- Design pillars and player promise
- Non-negotiables and anti-features
- AI agent roles and studio workflow
- Core gameplay loop
- Progression, skills, crafting, economy, inventory
- World, travel, and exploration direction
- PvE combat philosophy
- Mobile UX direction
- Audio identity
- Apple Health step-integration direction
- Starter-region content
- Milestone 01 vertical-slice definition
- Milestone 01 implementation sequencing
- Studio initialization audit (`STUDIO_INITIALIZATION_REPORT.md`)

## Approved foundation decisions

| # | Decision | Record |
|---|---|---|
| 0001 | Progression is step-clocked only | `DECISIONS/0001_PROGRESSION_CLOCK.md` |
| 0002 | Native Swift + SwiftUI, iOS 17+, pure `StrideCore` package | `DECISIONS/0002_TECHNOLOGY_STACK.md` |
| 0003 | Turn-based, retreat-not-death combat; no combat skills in M01 | `DECISIONS/0003_COMBAT_MODEL.md` |
| 0004 | M01 scope frozen — no currency, no merchants, five skills, six tabs | `DECISIONS/0004_MILESTONE_01_SCOPE.md` |
| 0006 | One activity at a time; travelling and gathering are a choice | `DECISIONS/0006_SINGLE_ACTIVITY.md` |

*(0005 is reserved for the audio sourcing decision, blocked on owner budget input.)*

## Current milestone

**Milestone 01 — First Adventure Vertical Slice**

The vertical slice must prove:

> Walking in real life creates a satisfying loop of planning, progression, crafting, travel, and active solo PvE adventure.

## Required player experience

The player must be able to:

1. Read and reconcile real-world steps
2. Apply those steps to an intentional activity
3. Travel to a destination or progress a gathering activity
4. Gain resources and skill experience
5. Craft or equip an upgrade
6. Enter and complete a PvE encounter
7. Save progress locally
8. Return later and clearly understand what changed

## Immediate next actions for Claude Code

1. ~~Audit the repository for contradictions or missing dependencies.~~ **Done**
2. ~~Produce `STUDIO_INITIALIZATION_REPORT.md`.~~ **Done**
3. ~~Recommend and document the initial mobile technology stack.~~ **Done — `DECISIONS/0002_TECHNOLOGY_STACK.md`**
4. ~~Create `ARCHITECTURE_IMPLEMENTATION_PLAN.md`.~~ **Done — awaiting owner approval**
5. ~~Create `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md`.~~ **Done — awaiting owner approval**
6. ~~Run design, critic, and QA review on those plans.~~ **Done — `DESIGN_REVIEW.md`, `CRITIC_REPORT.md`**
7. **Wait for owner approval before production implementation.** ← current state

## Open gaps to close during Milestone 01

| ID | Gap | When |
|---|---|---|
| G-04 | No visual identity document | Before Phase 5 |
| G-05 | No audio asset sourcing or licensing plan | Before Phase 3 |
| G-06 | No balance numbers; needs owner's typical daily step count | Before Phase 2 tuning |
| G-09 | No privacy policy artifact | During Phase 2 |

## Deferred features

- Multiplayer
- Trading
- Guilds
- PvP
- Live-service events
- Monetization
- Paid currencies
- Social pressure systems

## Active risks

- Feature creep
- Overengineering before validating the loop
- Inconsistent step accounting
- Health-data privacy mistakes
- Generic or menu-heavy presentation
- Combat disconnected from walking and preparation
- Audio being deferred until the end
