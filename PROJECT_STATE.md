# Project Stride — Project State

**Version:** 2.0
**Status:** ✅ **F-06 complete** — device persistence, bootstrap, single-writer concurrency, iOS Keychain identity, backup exclusion, restart validation.
**Current Phase:** Milestone 01 — **S-01A in progress** (foreground HealthKit and Health Connect + device-validation harness). **F-07 deferred until after foreground health validation** — owner priority decision, `DECISIONS/0014`.

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
| 0012 | Two slots, CAS, cursor authority, origin privacy | `DECISIONS/0012_SAVE_FORMAT.md` |
| 0013 | **Single-writer-isolate persistence; no background writer until S-01** | `DECISIONS/0013_SINGLE_WRITER_PERSISTENCE.md` |
| 0014 | **S-01A precedes F-07; foreground health only, no background delivery** | `DECISIONS/0014_S01A_PRIORITY_AND_SCOPE.md` |

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
14. ~~Owner review at the M-3 stop gate.~~ **Approved**
15. ~~Execute M-4 — cross-platform CI validation.~~ **Done — `M4_CI_COMPLETION_REPORT.md`**
16. ~~Owner approval of M-4.~~ **Approved**
17. ~~Execute M-5 and M-6 — retire the Swift scaffold, close the migration.~~ **Done — `MIGRATION_CLOSURE_REPORT.md`**
18. ~~Owner approval of the closed migration.~~ **Approved**
19. ~~Execute F-02 — content schema, loader, validation.~~ **Done — `F02_COMPLETION_REPORT.md`**
20. ~~Owner approval of F-02.~~ **Approved**
21. ~~Execute F-03 — state, commands, events, engine.~~ **Done — `F03_COMPLETION_REPORT.md`**
22. ~~Owner approval of F-03.~~ **Approved**
23. ~~Execute F-04 — step ledger and reconciliation.~~ **Done — `F04_COMPLETION_REPORT.md`**
24. ~~Owner approval before F-05; answer the escalated privacy question.~~ **Approved 2026-08-02**
25. ~~Fix the three lost-grant defects the F-05 critic review found in F-04.~~ **Done — commit 8336774**
26. ~~Answer the four blocking F-05 decisions.~~ **Ruled 2026-08-02**
27. ~~Execute F-05 — save, ledger persistence, crash recovery.~~ **Done — `F05_COMPLETION_REPORT.md`**
28. ~~Owner approval before F-06.~~ **Approved 2026-08-02**
29. ~~Execute F-06 — device persistence, bootstrap, restart validation.~~ **Done — `F06_COMPLETION_REPORT.md`**
30. ~~Re-run CI and the Android process-death workflow against the final tree.~~ **Done — both green, `F06_COMPLETION_REPORT.md` §10**
31. ~~Execute F-07 — skill framework.~~ **Deferred by owner priority decision — `DECISIONS/0014`**
32. **Execute S-01A — foreground HealthKit and Health Connect integration with a device-validation harness.** ← current state
    - **Android foreground vertical slice implementation-complete**, branch `s01a-foreground-health-harness`.
      Real steps → `SyncResponse` → `ReconcileStepSync` → `GameEngine` → durable save →
      usable energy → `GatherResource` → persisted, verified across a relaunch.
      See `S01A_IMPLEMENTATION_MAP.md` and `S01A_DEVICE_VALIDATION.md`.
    - **Android physical validation PAUSED by owner priority.** The implementation is
      preserved and compiling; no Android-only work continues this milestone.
    - **iOS-first pivot.** The Swift HealthKit adapter was already complete; the shared
      vertical slice, harness, engine and save are platform-neutral and unchanged.
      21 further assertions cover the iOS configuration facts a compile cannot catch.
      See `S01A_IOS_READINESS.md`.
    - **BLOCKED on Mac access.** The owner has a Windows PC and an iPhone, no Mac and
      no paid Apple Developer membership. Flutter cannot build iOS on Windows, and the
      macOS CI job builds `--no-codesign`, which is not installable. Every install
      route terminates in a Mac; a paid membership alone would not unblock it.
      No further code change creates a path.

## F-05 closed the four decisions

All four were ruled on 2026-08-02 and implemented: two-slot ping-pong snapshots, compare-and-swap on every commit, save-authoritative balance profile, and the journal as a bounded recovery log rather than an event store. Recorded in `DECISIONS/0012_SAVE_FORMAT.md`.

## Ten root causes fixed during F-05

Four sub-agents ran against compiling code. They found a durable commit that reported failure and froze the step cursor; a `core.autocrlf` hazard that would have broken the frozen save fixture on any second machine; and unconstrained bucket *resolution*, which would have made a minute-by-minute activity log fully compliant with the retention ruling.

**The most serious was mine.** LG-3 — the origin-blind horizon that discarded a returning player's backlog — was fixed, committed, and reported closed at `8336774` with a passing regression test. The fix was inert: a single global watermark cannot express "settled for the phone, still open for the watch", and the test passed only because it never asserted completeness. Closed properly at `ae06719` with per-origin watermarks.

Full detail: `F05_COMPLETION_REPORT.md` §8. Review: `DESIGN_REVIEW_F05.md`.

## Milestone 01 progress

| Task | Status |
|---|---|
| F-01 — project skeleton, core purity | ✅ Done (Flutter form, M-2/M-3) |
| F-02 — content schemas and loader | ✅ Done |
| F-03 — GameState, events, engine | ✅ Done |
| **F-04 — step ledger and the thirteen scenarios** | ✅ **Done** |
| **F-05 — save, ledger persistence, crash recovery** | ✅ **Done** |
| **F-06 — device persistence, bootstrap, restart validation** | ✅ **Done** |
| **S-01A — foreground HealthKit + Health Connect, device harness** | **In progress** ← next |
| F-07 — skill framework | **Deferred** until after foreground health validation (`DECISIONS/0014`) |
| S-01B — background synchronization | Blocked on S-01A **and** a real persistence coordinator |

**540 automated Dart tests**, zero skipped: 357 `stride_core`, 108 `stride_storage`, 31 `stride_secure_store`, 27 app, 17 `stride_health` — plus **38 Swift simulator tests** and 5 Kotlin in CI.

Final F-06 verification: CI run **`30780992412`** (all four jobs green) and Android process-death run **`30781003035`** (PASS), both against `2d20280`.

### The F-06 finding worth carrying forward

A green **Windows** run is not evidence for anything lock-shaped. POSIX `fcntl`
locks are owned by the *process*; Windows `LockFileEx` locks are owned by the
*handle*. CI run `30767931205` was the first time four storage test files ran on
Linux: 94 passed, **11 failed**, against 105/105 on Windows — including
`totalGranted` of 7 where 0 was required. **Linux is the signal.** See
`DECISIONS/0013` and `TECHNICAL/PERSISTENCE_CONCURRENCY.md`.

`stride_core` is 31 files of pure Dart — no Flutter, no plugins, no `dart:io`, and now no clock, randomness, locale, or platform reads either, enforced by a static source scan.

## Current documents

| Document | Purpose |
|---|---|
| `ARCHITECTURE_IMPLEMENTATION_PLAN.md` | v2.0 Flutter — the technical plan |
| `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md` | v2.0 — 41 tasks, review findings applied |
| `TECHNICAL/PROJECT_STRUCTURE.md` | Package layout and the Pigeon boundary |
| `.github/workflows/ci.yml` | Build matrix — Linux for Dart/Android, macOS for iOS |
| `TECHNICAL/PROJECT_SETUP.md` | How to build and verify |
| `TOOLCHAIN_REPORT_WINDOWS.md` | Verified Windows toolchain |
| `FILE_MANIFEST.md` | Full inventory, active vs. historical |
| **`MIGRATION_CLOSURE_REPORT.md`** | **M-5/M-6, final CI, recommended F-02 scope** |
| **`F05_COMPLETION_REPORT.md`** | **Save format, crash recovery, the ten root causes** |
| **`DECISIONS/0012_SAVE_FORMAT.md`** | **Two slots, CAS, cursor authority, origin privacy** |
| `MIGRATION_EXECUTION_PLAN.md` | M-1 to M-6, with acceptance criteria |
| `DESIGN_REVIEW_FLUTTER.md` | Four-role review, approved with changes |
| `ARCHITECTURE_REVIEW_CROSS_PLATFORM.md` | Why Flutter |

Archived, not deleted: `TECHNICAL/ARCHITECTURE_IMPLEMENTATION_PLAN_SWIFT_ARCHIVED.md`, `MILESTONES/MILESTONE_01_TASK_BREAKDOWN_SWIFT_ARCHIVED.md`, `DECISIONS/0002` (superseded).

## Migration closed

**M-1 through M-6 complete.** See `MIGRATION_CLOSURE_REPORT.md`.

Repository: `thcwtnnp5s-del/project-stride` (private), branch `master`, all history preserved including the superseded Swift scaffold at `859d0ac`.

**CI green on all four jobs** — run `30752832663`. **44 automated tests**: 17 Dart, 5 Kotlin, 12 Swift, plus the Dart suite re-run on macOS.

| Job | Runner | Covers |
|---|---|---|
| Dart core | ubuntu | Guards, format, analyze (fatal), 17 tests |
| Pigeon bindings | ubuntu | Three-way contract drift |
| Android | ubuntu | Both debug APKs, 5 Kotlin tests |
| iOS compile | **macOS** | Pigeon verify, 17 tests, app + Swift adapter compilation |

**The iOS branch compiles and its adapter is behaviorally tested.** It did not compile on its first attempt — `HealthKitAdapter.swift` was missing `import Flutter`, invisible to every tool on Windows. That single finding justifies the macOS job.

The Swift scaffold was retired at M-5. All ten `.claude/agents/` definitions, which still described the native-Swift stack, were corrected — they load as standing context and were the likeliest way a future agent could have been misled.

### No blockers

### Apple: adapter tested, platform not

The Swift adapter's mapping and error handling are covered by 12 simulator tests. `HealthKitStepStore` is still the S-01b shell, so **nothing about real HealthKit is verified**. Same on Android: `HealthConnectAdapter` is a shell until S-01.

Physical devices are needed for real health data, background sync, process-kill, and cross-adapter equivalence (V-02b). A real Mac plus Apple Developer Program is needed for signing and TestFlight.

### Toolchain

| | |
|---|---|
| Flutter | ✅ 3.44.8 at `C:\Users\<username>\dev\flutter` |
| Dart | ✅ 3.12.2 |
| JDK | ✅ Temurin 17.0.20 |
| Android SDK | ✅ platform-36, build-tools 36.1.0, adb, emulator |
| AVD | ✅ `stride_pixel` (API 36) |
| GitHub CLI | ✅ 2.97.0, authenticated |
| Xcode | ➖ iOS-only; CI macOS job covers compilation |


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
