# Project Stride — Project State

**Version:** 1.5
**Status:** Migration steps M-1 to M-3 executed; stop gate reached
**Current Phase:** Milestone 01 — awaiting owner review before M-4 and F-02

## Project identity

Project Stride is a mobile-first, solo **step-powered asynchronous RPG with idle-style planning**, with MMO-style long-term progression. Real-world walking powers travel, gathering, exploration, crafting preparation, and adventure.

Built in Flutter for **Android and iOS**. Android first, for interactive development on Windows; iOS kept compiling continuously in CI.

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
| 0002 | ~~Native Swift + SwiftUI~~ — **superseded by 0010** | `DECISIONS/0002_TECHNOLOGY_STACK.md` |
| 0003 | Turn-based, retreat-not-death combat; no combat skills in M01 | `DECISIONS/0003_COMBAT_MODEL.md` |
| 0004 | M01 scope frozen — no currency, no merchants, five skills, six tabs | `DECISIONS/0004_MILESTONE_01_SCOPE.md` |
| 0005 | Audio sourcing — lean prototype budget, full provenance, replaceable asset IDs | `DECISIONS/0005_AUDIO_SOURCING.md` |
| 0006 | One activity at a time; travelling and gathering are a choice | `DECISIONS/0006_SINGLE_ACTIVITY.md` |
| 0007 | Loop validated in one to two weeks; maxing skills not required | `DECISIONS/0007_PROGRESSION_PACING.md` |
| 0008 | Earned opportunity never expires; nothing decays | `DECISIONS/0008_STEPLESS_WEEK.md` |
| 0009 | Portrait only, phone only, no store launch — *amended for Android* | `DECISIONS/0009_PLATFORM_AND_DISTRIBUTION.md` |
| 0010 | **Flutter, pure Dart core, first-party health adapters, Android first** | `DECISIONS/0010_CROSS_PLATFORM_STACK.md` |
| 0011 | Staged private distribution — APK → Play internal; TestFlight later | `DECISIONS/0011_DISTRIBUTION_CHANNELS.md` |

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
7. ~~Wait for owner approval before production implementation.~~ **Approved 2026-08-01**
8. ~~Execute F-01 (Swift).~~ **Authored, never compiled — paused, see below**
9. ~~Reopen the technology-stack decision.~~ **Done — `ARCHITECTURE_REVIEW_CROSS_PLATFORM.md`**
10. ~~Owner approval of the Flutter recommendation.~~ **Approved 2026-08-01**
11. ~~Revise architecture, structure, CI, and task plan; run four-role review.~~ **Done**
12. ~~Owner approval of the revised plans.~~ **Approved 2026-08-01**
13. ~~Execute migration M-1, M-2, M-3.~~ **Done — `MIGRATION_COMPLETION_REPORT.md`**
14. **Owner review at the M-3 stop gate.** ← current state

## Current documents

| Document | Purpose |
|---|---|
| `ARCHITECTURE_IMPLEMENTATION_PLAN.md` | v2.0 Flutter — the technical plan |
| `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md` | v2.0 — 41 tasks, review findings applied |
| `TECHNICAL/PROJECT_STRUCTURE.md` | Package layout and the Pigeon boundary |
| `.github/workflows/ci.yml` | Build matrix — Linux for Dart/Android, macOS for iOS |
| `MIGRATION_EXECUTION_PLAN.md` | M-1 to M-6, with acceptance criteria |
| `DESIGN_REVIEW_FLUTTER.md` | Four-role review, approved with changes |
| `ARCHITECTURE_REVIEW_CROSS_PLATFORM.md` | Why Flutter |

Archived, not deleted: `TECHNICAL/ARCHITECTURE_IMPLEMENTATION_PLAN_SWIFT_ARCHIVED.md`, `MILESTONES/MILESTONE_01_TASK_BREAKDOWN_SWIFT_ARCHIVED.md`, `DECISIONS/0002` (superseded).

## Migration status

**M-1, M-2, M-3 executed.** M-4 (CI), M-5 (retire the Swift scaffold), M-6 (close) remain.

The Flutter workspace exists and is verified on Windows: **17 tests, analyze clean, both enforcement guards demonstrated failing and recovering.** Full detail in `MIGRATION_COMPLETION_REPORT.md`.

The Swift scaffold is still in the tree, unbuilt and inert, retired last at M-5.

### Two blockers

| # | Blocker | Effect |
|---|---|---|
| 1 | **JDK install failed** — the download stalled twice against its CDN | Blocks `sdkmanager`, adb, the emulator, and every Android build. Recovery steps in `TOOLCHAIN_REPORT_WINDOWS.md` |
| 2 | **GitHub repo not created** — `gh` login is interactive | Blocks CI. Exact commands in `MIGRATION_COMPLETION_REPORT.md` §7 |

Neither is a design problem, and neither invalidates the work done.

### Toolchain

| | |
|---|---|
| Flutter | ✅ 3.44.8 at `C:\Users\jwspa\dev\flutter` |
| Dart | ✅ 3.12.2 |
| Android cmdline-tools | ✅ at `C:\Users\jwspa\dev\android-sdk` |
| JDK, adb, emulator | ⛔ blocked |
| GitHub CLI | ✅ 2.97.0, not authenticated |
| Xcode | ➖ iOS-only; CI macOS job covers compilation |

### Not yet compiled anywhere

**All Apple code.** `HealthKitAdapter.swift` and the generated Swift are authored and never built — the CI macOS job in M-4 is the first time any of it compiles. Treat as unverified until then.

macOS is not needed for the critical path. Real HealthKit testing, signing, TestFlight, interactive iOS UX, and iOS audio/haptic validation need a Mac later.

## Open gaps to close during Milestone 01

| ID | Gap | When |
|---|---|---|
| G-04 | No visual identity document | Task P-01, before Phase 5 |
| G-06 | No derived balance numbers | Task S-06 |
| G-09 | No privacy policy artifact | Task S-07 |

*(G-05 closed by `DECISIONS/0005`; G-07 closed by the reviewed task breakdown.)*

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
