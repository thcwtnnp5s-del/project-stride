# Milestone 01 Task Breakdown — Flutter

**Version:** 2.0 — review findings applied
**Date:** 2026-08-01
**Status:** Finalized. Presented for owner approval before the migration executes.
**Reviews:** `DESIGN_REVIEW_FLUTTER.md` — approved with changes; all ten findings applied and marked inline.

Supersedes v1.1, archived at `MILESTONE_01_TASK_BREAKDOWN_SWIFT_ARCHIVED.md`. Tasks marked **unchanged** keep their objective, deliverables, acceptance criteria, and tests verbatim from v1.1 — only the language and toolchain differ. Tasks marked **changed** or **new** are given in full.

---

## What changed at the plan level

| Change | Effect |
|---|---|
| Two platforms | Every acceptance criterion touching a device now reads "on both platforms," and the step-provider work splits in two |
| Windows-primary development | Most tasks are no longer Mac-blocked; sequencing changes accordingly |
| Android-first sequencing | iOS adapter and iOS acceptance move later, without leaving the milestone |
| First-party platform channels | A dedicated task per platform, and a standing rule against health plugins |
| Audio via packages | An early spike, so the one real capability risk surfaces at Phase 3 rather than Phase 5 |

**Task count:** 37 → 41. Four tasks added — S-01b (iOS adapter), S-09 (build pipeline), A-04b (audio spike), V-02b (cross-adapter equivalence).

---

## Phase 0 — Studio initialization

Unchanged, plus:

| ID | Title | Owner | Status |
|---|---|---|---|
| P0-09 | Cross-platform architecture review | Technical Director | Done |
| P0-10 | Owner approval of the Flutter recommendation | Owner | Done |
| P0-11 | Revise architecture, structure, CI, and task plan for Flutter | Technical Director | Done |
| P0-12 | Creative, technical, critic, and QA review of the revised plans | Critic Agent | Done |
| P0-13 | **Owner approval of the revised plans, then execute migration** | Owner | **Pending** |

---

## Phase 1 — Foundation

### F-01 — Project skeleton and core purity *(changed — restart)*

- **Owner:** Technical Director
- **Objective:** Flutter project, pure Dart simulation package, and the boundary between them.
- **Scope limit:** project creation, `stride_core` package, dependency and import boundaries, test targets, build verification, documentation. **No gameplay, no health integration, no production UI.**
- **Deliverables:** Flutter app project (Android + iOS runners); `stride_core` pure Dart package; placeholder screen; test setup; import boundary guard; `Scripts/verify.sh`; `TECHNICAL/PROJECT_SETUP.md`
- **Acceptance criteria:**
  1. `dart test` runs the `stride_core` suite **on Windows**, no emulator, in under a second
  2. `flutter test` runs widget tests **on Windows**
  3. App builds and launches to a placeholder on an **Android emulator, from Windows**
  4. The import guard **fails** when `package:flutter` is added to `stride_core`, demonstrated once
  5. `stride_core/pubspec.yaml` declares no Flutter dependency and no third-party health package
  6. Android manifest and iOS runner both constrain to **portrait only**; Android `allowBackup` is **disabled** — an auto-backup restored to a second device would duplicate the step ledger
  7. iOS builds in CI — **may trail criteria 1–6**, tracked separately
  8. **`minSdkVersion` is chosen and its player consequence stated** *(TD-F-4)*: which Android versions are excluded, and whether Health Connect requires a separate app install across the supported range. This is a distribution decision, not just a build setting.
- **Tests:** Core purity test and script; deliberate-violation check; Android emulator launch; orientation checks
- **Documentation:** `TECHNICAL/PROJECT_SETUP.md`
- **Status:** Not started — supersedes the paused Swift F-01

### F-02 — Content schemas and loader *(unchanged)*

All seven acceptance criteria carry over verbatim, including the `isSafe` location flag, `activityKind`, and the deferred-vocabulary build guard. `Codable` becomes explicit JSON serialization.

### F-03 — GameState, events, and the engine entry point *(unchanged, one addition)*

All five criteria carry over. Added:

  6. **Immutability is enforced, not assumed.** Dart lacks Swift's value semantics, so `GameState` and its members are immutable by construction (`final` fields, no in-place mutation), asserted by a test that mutating a returned state cannot affect the engine's own.

*This is the one place the language change creates real risk: the original design leaned on Swift value types for save correctness and test diffing.*

### F-04 — Step reconciliation test harness *(changed — thirteen scenarios)*

The twelve scenarios from v1.1, written before the feature, plus one the second platform brings with it. Under the Swift plan these could not run on the owner's machine at all; in `dart test` they run in under a second.

**Scenario 13 — cursor invalidation and bounded authoritative rescan** *(TD-F-1)*

Health Connect can expire a changes token, leaving the adapter unable to say what changed. HealthKit has no equivalent. The recovery rule is specified in `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §6.6 and encoded in `StepRescan`.

The scenario must assert every clause of it:

| # | Assertion |
|---|---|
| 13a | The game ledger is **never reset** |
| 13b | Rescanned history is **never treated as all new** |
| 13c | Granted progress is **never clawed back** — `max(0, windowTotal − grantedSinceWatermark)` |
| 13d | The cursor is **never silently discarded in favour of granting full history** |
| 13e | A replacement token is persisted **only after** the recovery batch is committed |
| 13f | Recovery interrupted at any point **recomputes the same result on retry** |
| 13g | A **truncated** window records the unreachable gap rather than granting it |

- **Acceptance:** all thirteen scenarios exist and fail for the right reason before S-02; none touches real health data, the file system, or the wall clock; the suite runs in under a second
- **Note:** the ledger's monotonic counters were *claimed* to handle this by design. That claim is untested until 13a–13g exist, and "handled by design" is exactly the kind of belief that turns out to be wrong in the one system that must not be.

> **The mechanism is not fixed.** `newlyGrantable = max(0, windowTotal − grantedSinceWatermark)` is an initial hypothesis, not settled architecture. S-01 may instead use record identities, origin metadata, time buckets, overlap fingerprints, aggregate reads, or a hybrid — whatever the real Health Connect API turns out to require.
>
> **Write 13a–13g against the contract, not the equation.** A test that asserts the arithmetic would have to be rewritten when the mechanism changes, and a test you rewrite to make it pass has stopped being a test.

**Ordering rule stands: F-04 before S-02. Do not reorder it.**

### F-05 — Save, ledger, and crash recovery *(unchanged)*

### F-06 — Device persistence, bootstrap, and restart validation *(re-scoped 2026-08-02)*

> **This entry read "Skill framework" until 2026-08-02, and that line was stale.**
>
> The owner's F-06 authorization scoped it as *device-local persistence adapters, runtime bootstrap, and restart-validation harness* — the real filesystem adapters for the F-05 protocol, the asset content source, the bootstrap state machine, and proof that the guarantees survive actual files, process termination, and restart.
>
> The stale line caused a real error: a review concluded F-06 "is supposed to be the skill framework" and used that to argue the save work had overrun its budget, and the orchestrator relayed it without checking. **The owner's authorization governs; the document was simply not updated when the scope changed.** Corrected here so the next reader does not repeat it.

**Delivers:** `stride_storage` (real `dart:io` adapters), OS-level cross-instance transaction locking, iOS Keychain identity with `ThisDeviceOnly` accessibility, backup exclusions on both platforms, the `BootstrapCoordinator` state machine, the reusable persistence conformance suite, and Android process-death evidence.

**Does not deliver:** skills, gameplay, health ingestion, or UI. The skill framework moves to a later task.

---

## Phase 2 — Step loop

### S-01 — StepProvider port and Android Health Connect adapter *(changed — Android first)*

- **Owner:** Technical Director
- **Objective:** Read steps from Health Connect through a first-party platform channel.
- **Deliverables:** `StepProvider` port in Dart; Kotlin adapter using the **Changes API** (`getChangesToken` / `getChanges`) with token persistence, deletion handling, and a recording-method filter; graceful degradation when Health Connect is absent
- **Acceptance criteria:**
  1. **First-party Kotlin channel. No third-party health plugin appears in `pubspec.yaml`** — asserted by a dependency check
  2. Read-only steps permission; no write scope requested anywhere
  3. Manually-entered records filtered by default, includable by setting
  4. A failed read leaves the token unchanged and `stepsIngested` untouched
  5. Cold-launch backfill fully reconciles a multi-day absence with no network
  6. Absent or unavailable Health Connect degrades gracefully — same path as a denied permission; **the game remains fully playable**
  7. Behavior is identical whether permission was denied or there is simply no data
  8. **Developed, built, and tested entirely on Windows**
- **Tests:** Adapter against a stubbed Health Connect store; error paths; filter behavior; degradation path
- **Documentation:** `TECHNICAL/HEALTH_CONNECT_INTEGRATION.md`
- **Status:** Not started

### S-01b — iOS HealthKit adapter *(new)*

- **Owner:** Technical Director
- **Objective:** The iOS half of the same port.
- **Dependencies:** S-01, plus macOS access
- **Deliverables:** Swift adapter using `HKAnchoredObjectQuery` with anchor persistence, deletion handling, `wasUserEntered` filter, opportunistic background delivery; HealthKit capability and usage strings
- **Acceptance criteria:**
  1. **First-party Swift channel**, no plugin
  2. Criteria 2–7 of S-01, met identically on iOS
  3. The thirteen F-04 scenarios pass against this adapter — verified formally in **V-02b**, which owns cross-adapter equivalence *(QA-F-1)*
  4. Locked-device read failure is handled: foreground backfill remains the source of truth
- **Tests:** The F-04 suite against the iOS adapter; adapter tests against a stubbed HealthKit store
- **Documentation:** `TECHNICAL/HEALTHKIT_INTEGRATION.md`
- **Status:** Blocked — needs macOS access
- **Note:** Authorable on Windows; **not verifiable there.** Treat as unverified until a Mac compiles and runs it — the F-01 lesson.

### S-02 — Reconciliation engine *(changed — turns F-04 green)*

All six criteria carry over, including the no-clawback rule and the content-tunable debt cap. Added:

  7. The engine is **platform-agnostic**: it consumes `StepProvider` results and never branches on platform
  8. **All thirteen F-04 scenarios pass, including anchor/token invalidation** *(TD-F-1)*

**On completion, start the fourteen-day real-data log immediately** — now on Android, where it can begin without waiting for Mac access.

### S-03 — Activity selection and step allocation *(unchanged)*
### S-04 — Travel *(unchanged)*
### S-08 — Early feel check *(unchanged)*

Now runs on Android, so it can happen on schedule rather than waiting for iOS.

### S-05 — Debug step injector and accelerated balance profile *(unchanged)*
### S-06 — First-pass balance numbers *(unchanged)*

All pacing targets and the three step fixtures from `DECISIONS/0007` carry over. Projections run in `dart test` on Windows.

### S-07 — Privacy policy and permission copy *(changed — two platforms)*

Added criteria:

  5. Android permission rationale meets Health Connect's requirements, including the privacy-policy link its permission flow expects
  6. The **Play Console Health Connect data-types declaration** is completed, if distributing through Play
  7. Disconnect-and-reset clears the anchor *and* the change token, on both platforms

### S-09 — iOS build pipeline *(new)*

- **Owner:** Technical Director
- **Objective:** Make iOS build automatically so it cannot silently rot between rare manual builds.
- **Dependencies:** F-01, plus a decision on how macOS access is provided
- **Deliverables:** Cloud CI configuration (Codemagic, GitHub Actions macOS runner, or equivalent) building the iOS app on push; signing configuration; TestFlight upload step
- **Acceptance criteria:**
  1. Every push to the main branch produces an iOS build
  2. A compile error in Dart or Swift **fails the pipeline within one push**, not at release time
  3. A release-candidate build uploads to TestFlight without manual Xcode work
  4. Android builds in the same pipeline
- **Tests:** A deliberately broken commit fails the pipeline; a clean commit uploads
- **Documentation:** `TECHNICAL/BUILD_PIPELINE.md`
- **Status:** Blocked — needs the macOS access decision
- **Note:** This is the mitigation for risk X-03. A build that nobody runs still catches compile breaks, and that is most of the value.

---

## Phase 3 — RPG activities

### A-00 — Author the starter content set *(unchanged)*
### A-01 — Gathering *(unchanged)*
### A-02 — Inventory and equipment *(unchanged)*
### A-03 — Crafting *(unchanged)*

All four run entirely on Windows.

### A-04 — Audio and haptic event hooks *(changed)*

All five original criteria carry over — no simulation code references a sound, cue coverage fails the build, ducking and silent-switch respect, per-bus volume, no haptic-only information. Added:

  6. Audio and haptics sit behind `AudioDirecting` and `HapticPlaying`, with **no package reference outside those adapters**, so a package swap touches two files
  7. Cues are referenced by **asset ID** only (`DECISIONS/0005`)
  8. Custom haptic patterns go through a platform channel where the Flutter API is too coarse

### A-04b — Audio capability spike *(new)*

- **Owner:** Audio Director, with Technical Director
- **Objective:** Prove Flutter can meet the audio pillar, early enough to change course.
- **Dependencies:** A-04
- **Deliverables:** A working prototype covering every capability below, on a real mid-range Android device
- **Acceptance criteria:**
  1. **Four independent buses** — music, ambience, effects, UI — with independent volume controls and a master mute
  2. **Destination ambience crossfade** on arrival, with no audible seam, gap, or dropout
  3. **Layered and varied gathering cues** — repeated chopping rotates variants rather than repeating one sample
  4. **Combat ducking** — ambience and music duck under combat audio and restore cleanly
  5. **Interruption and resume** — a phone call, another app taking audio focus, or backgrounding and returning leaves audio in a correct state, not silent and not doubled
  6. Ducking for other apps' audio; silent switch respected; no background audio session
  7. **Latency: cue trigger to audible under 100 ms** *(QA-F-2)*
  8. **Memory: total audio within the 30 MB budget** *(QA-F-2)*
  9. Criteria 1–8 verified on a **modest Android device** — mid-range, roughly three to four years old, not a flagship *(QA-F-2)*. iOS verification may trail.
- **Tests:** Instrumented latency measurement; memory profiling; bus routing tests; manual listening check by the Audio Director
- **Status:** Not started
- **Constraint:** **Do not introduce a custom native audio engine unless this spike demonstrates a concrete blocker** (`DECISIONS/0010`). A package that misses one criterion is a reason to try another package, not to write an engine.
- **Note:** Risk X-02. Audio is the one capability Flutter genuinely costs against native. Finding a wall at Phase 3 is recoverable; finding it at Phase 5 is not. Numeric targets are provisional — but a spike whose result cannot be stated as pass or fail is a spike that always passes.

### A-05 — Audio asset sourcing *(unchanged)*

All seven criteria from `DECISIONS/0005` carry over, including full manifest provenance and the prohibition on extracted assets.

---

## Phase 4 — Combat prototype

### C-01 — Combat state and resolver *(unchanged)*
### C-02 — Defeat and retreat *(unchanged)*
### C-03 — Character progression *(unchanged)*
### C-04 — Three starter enemies *(unchanged)*

All four are pure simulation. All run on Windows, including the optimal-play preparation-gate simulations.

---

## Phase 5 — Presentation

### P-01 — Visual identity *(changed)*

All original criteria carry over. Added:

  4. **State explicitly whether the visual identity is platform-adaptive or a single game aesthetic on both platforms** *(CD-F-2)*

Under SwiftUI the app would have inherited iOS conventions for free. Flutter renders its own widgets, so "feels native" is now a choice rather than a default. `GAME_BIBLE/UI_UX` asks for "a living adventure journal," which is a game aesthetic rather than a platform one — the Creative Director recommends **a single aesthetic on both platforms, with platform conventions honored only for navigation reflexes** (back gesture, scroll physics, share sheets). Either answer is defensible; leaving it unstated is not.

  5. The palette and motion language read correctly on both platforms

### P-02 — Navigation and six tabs *(changed)*

All five criteria carry over. Added:

  6. Layouts adapt correctly on both a small and a contemporary standard-size device, on **both platforms**
  7. **Android back-button and gesture navigation behave correctly**, including inside the combat modal, which must not be dismissible by back gesture mid-encounter

### P-03 — The return summary *(unchanged)*

### P-04 — Combat screen *(changed)*

All four criteria carry over. Added:

  5. **The Android back gesture during an encounter prompts "Retreat from this fight?"** — it neither does nothing nor silently retreats *(CD-F-1)*

The combat modal is dismissible only by resolving or retreating (`DECISIONS/0004`). On Android, back is a reflex, and a swallowed back gesture reads as a bug. Retreating without confirmation would spend the player's consumables on an accidental swipe. The prompt is the only option that respects both the design and the platform.
### P-05 — Onboarding *(unchanged)*
### P-06 — Region ambience *(unchanged)*

### P-07 — Accessibility pass *(changed — two platforms)*

All five criteria carry over. Added:

  6. Screen-reader support verified with **both** VoiceOver and TalkBack; the full core loop is completable with each
  7. Text scaling honored on both platforms' accessibility settings

---

## Phase 6 — Validation

### V-01 — Functional QA *(changed)*

Added: all eight required player experiences pass **on both platforms**; the zero-step session criterion applies to both.

### V-02 — Step-accounting QA on real data *(changed)*

- Fourteen consecutive days on **a real Android device**, started at S-02
- Fourteen consecutive days on **a real iPhone**, started when S-01b lands
- Both must match their platform's health total exactly, allowing only for the manual-entry filter
- **Neither platform may double-count or lose steps**, and the two must agree in behavior even though their sources differ

### V-02b — Cross-adapter equivalence *(new — QA-F-1)*

- **Owner:** QA Director, with Technical Director
- **Objective:** Prove that one ledger over two genuinely different sync primitives produces identical results.
- **Dependencies:** S-01b
- **Deliverables:** The thirteen F-04 scenarios executed against **both real adapters** — HealthKit on a physical iPhone, Health Connect on a physical Android device — with seeded health data and identical assertions
- **Acceptance criteria:** normalized outcomes must match across HealthKit and Health Connect for every case below.

  | Case | Compared |
  |---|---|
  | New steps | Newly grantable progress, ledger totals |
  | Duplicates | No double-count on either platform |
  | Delayed additions | Same total once delivered |
  | Corrections | Same discrepancy handling |
  | Deletions | Same absorption, no clawback |
  | Interrupted sync | Same state after retry |
  | Invalid/expired cursor recovery | Same newly grantable figure |
  | No-clawback behavior | Granted progress preserved identically |

  1. All thirteen scenarios pass against the real Health Connect adapter
  2. All thirteen pass against the real HealthKit adapter
  3. **Internal native cursor formats need not match** — an archived `HKQueryAnchor` and a Health Connect token are different objects, and that is fine
  4. **Newly grantable progress and ledger outcomes must match exactly**, from the same logical inputs
  5. Cursor invalidation is exercised on Android, where it actually occurs
  6. Any behavioral divergence is either eliminated or recorded as a known, bounded difference with its player-visible consequence stated
- **Tests:** The suite is the deliverable
- **Documentation:** `QA_REPORT.md`
- **Status:** Blocked — needs S-01b and both physical devices
- **Note:** This is the mitigation for risk X-06, the highest-severity risk the second platform introduces. Without its own task it would be assumed done by whoever ships last, which is how a double-count reaches a player.

### V-03 — Save, offline, and interruption QA *(changed)*

Added: force-quit matrix and airplane-mode session run on both platforms; Android process death under memory pressure is tested explicitly, since it is more aggressive than iOS backgrounding.

### V-04 — Balance review *(unchanged)*
### V-05 — Critic review *(unchanged, plus a health-plugin dependency check)*
### V-06 — Playtest and milestone report *(changed)*

The owner's playtest may run on either platform. At least one friend should test the other, so both are exercised before the milestone closes.

---

## Dependency spine

```text
P0-10 approval
  └─ F-01 → F-02 → F-03 ─┬─ F-04 ──┐
     (Windows)            ├─ F-05 ──┤
                          └─ F-06   │
                                    ↓
                        S-01 (Android) → S-02 → S-03 → S-04 → S-08
                          │                │       └─ S-06
                          │                ├─ S-05
                          │                ├─ S-07
                          │                └─ ⏱ 14-day Android log starts
                          │
                          └─ S-01b (iOS) → V-02b ···┐  needs macOS + devices
                             S-09 (CI) ·············┘
                                    ↓
                        A-00 → A-01 → A-02 → A-03
                                 └─ A-04 → A-04b → A-05
                                    ↓
                        C-01 → C-02 → C-03 → C-04
                                    ↓
        P-01 → P-02 → P-03 → P-04 ─┬─ P-05
                                    ├─ P-06
                                    └─ P-07
                                    ↓
                   V-01 → V-02 → V-03 → V-04 → V-05 → V-06
```

**Critical path:** F-01 → F-03 → F-04 → S-02 → S-03 → A-00 → A-01 → A-03 → C-01 → C-04 → P-03 → V-06 — **entirely on Windows.**

**The iOS branch (S-01b, S-09) is parallel, not blocking.** It joins before V-01. Mac access is needed for that branch and for final iOS acceptance, not for the critical path.

---

## Windows / macOS split

| | Tasks |
|---|---|
| **Windows only, no Mac needed** | F-01 – F-06, S-01, S-02, S-03, S-04, S-05, S-06, S-08, A-00 – A-05, C-01 – C-04, P-01 – P-07, V-04, V-05 |
| **Needs macOS** | S-01b, S-09, V-02b, plus the iOS half of V-01, V-02, V-03, V-06 |

**35 of 41 tasks require no Mac.** The six that do are concentrated in the iOS adapter, the build pipeline, cross-adapter equivalence, and final iOS acceptance.

Note that S-09 needs macOS only as a *CI runner*, not as a workstation — GitHub-hosted macOS runners satisfy it without the owner touching a Mac.

---

## Scope guard

Unchanged from `DECISIONS/0004`: four locations, five skills, three enemies, six tabs plus one modal, no currency, no merchants. Additions require a decision record.

**One new standing rule:** no third-party health plugin, on either platform. Step adapters are first-party platform channels. This is risk X-01, it is the condition the entire Flutter fidelity case rests on, and a health package appearing in `pubspec.yaml` should fail review.
