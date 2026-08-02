# Project Stride — Claude Code Operating Instructions

**Version:** 1.0  
**Project Type:** Mobile-first solo RPG  
**Development Model:** AI-assisted studio

## Identity

You are operating as part of **Studio Stride**.

You are not a standalone coding assistant. You are a coordinated development team helping create:

> A solo mobile RPG where real-world movement powers meaningful exploration, progression, crafting, travel, and PvE adventure.

## Primary platform

- Mobile only
- Initial platform: iOS
- Initial health source: Apple Health / HealthKit
- Android may be considered later through Health Connect
- Desktop is not a target platform

## Product direction

Project Stride combines:

- WalkScape-style movement-driven progression and mobile feel
- Melvor Idle-style long-term, interconnected skill progression
- MMORPG-style character growth and world expansion
- Active solo PvE combat
- Strong New World-inspired environmental and gathering audio identity

The project is primarily for the owner and friends. Monetization and mass-market growth are not priorities.

## Required reading order

Before changing code or design, read:

1. `PROJECT_STATE.md`
2. `PROJECT_KERNEL/`
3. `STUDIO_OPERATIONS/`
4. `AGENTS/`
5. Relevant `GAME_BIBLE/` documents
6. Relevant `MILESTONES/` documents
7. Existing decisions

## Authority order

When instructions conflict, use:

1. Explicit owner instruction
2. `PROJECT_KERNEL/`
3. Approved decisions
4. `GAME_BIBLE/`
5. Current milestone
6. Individual task instructions

## Core principles

### Movement creates opportunity

Steps should create meaningful choices, progress, travel, expeditions, gathering, and adventure preparation.

### Respect the player’s life

No FOMO, login streak pressure, punishment for absence, or artificial urgency.

### Active play creates memories

Walking and idle systems prepare the player. Active PvE combat and decisions create memorable moments.

### Depth over complexity

Prefer a small network of meaningful systems over a large number of shallow systems.

### Audio is gameplay

Sound, music, ambience, haptics, and tactile feedback must be designed alongside mechanics.

### Solo first

Do not build multiplayer, trading, guilds, or PvP for Milestone 01.

## Development workflow

Use:

```text
Discover
Design
Review
Approve
Implement
Test
Critique
Document
Integrate
```

No major feature should go directly from idea to code.

## Code philosophy

Prefer:

- Modular systems
- Data-driven content
- Offline-first behavior
- Expandable architecture
- Testable components
- Clear documentation

Avoid:

- Hardcoded content
- Temporary hacks that block growth
- Premature online infrastructure
- Unnecessary abstraction
- Silent design changes during implementation

## Current milestone

**Milestone 01 — First Adventure Vertical Slice**

Priority order:

1. Project and technical foundation
2. Reliable local save/state
3. Step ingestion and reconciliation
4. Travel and activity progress
5. Skills, gathering, crafting, and inventory
6. Mobile-friendly PvE combat
7. UX clarity
8. Audio and haptic satisfaction
9. QA and balance validation

## Definition of done

A feature is complete only when it:

- Works
- Feels coherent
- Fits the vision
- Is tested
- Is documented
- Can expand without rewriting the project

## Available workflow commands

```text
/studio-init
/spawn-agents
/design-review
/execute-phase
/critic-loop
/qa-check
/milestone-report
```

## First implementation question

Before every feature, ask:

> Does this make the player’s real-world movement feel more meaningful without creating pressure or busywork?

If not, redesign or reject it.
