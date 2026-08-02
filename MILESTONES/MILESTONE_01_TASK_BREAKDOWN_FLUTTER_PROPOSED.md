# Milestone 01 Task Breakdown — Flutter (Proposed)

**Version:** 2.0-proposed
**Date:** 2026-08-01
**Status:** **Proposal.** Does not replace `MILESTONE_01_TASK_BREAKDOWN.md` until the owner approves `ARCHITECTURE_REVIEW_CROSS_PLATFORM.md`.

Read alongside the approved breakdown. Tasks marked **unchanged** keep their objective, deliverables, acceptance criteria, and tests verbatim — only the language and toolchain differ. Tasks marked **changed**, **new**, or **split** are given in full.

---

## What changed at the plan level

| Change | Effect |
|---|---|
| Two platforms | Every acceptance criterion touching a device now reads "on both platforms," and the step-provider work splits in two |
| Windows-primary development | Most tasks are no longer Mac-blocked; sequencing changes accordingly |
| Android-first sequencing | iOS adapter and iOS acceptance move later, without leaving the milestone |
| First-party platform channels | A dedicated task per platform, and a standing rule against health plugins |
| Audio via packages | An early spike, so the one real capability risk surfaces at Phase 3 rather than Phase 5 |

**Task count:** 37 → 40. Three tasks added (S-01b, S-09, A-04b); one renumbered.

---

## Phase 0 — Studio initialization

Unchanged, plus:

| ID | Title | Owner | Status |
|---|---|---|---|
| P0-09 | Cross-platform architecture review | Technical Director | Done |
| P0-10 | **Owner approval of the Flutter recommendation** | Owner | **Pending** |

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
  6. Android manifest and iOS runner both constrain to **portrait only**
  7. iOS builds via cloud CI or a Mac — **may trail criteria 1–6**, tracked separately
- **Tests:** Core purity test and script; deliberate-violation check; Android emulator launch; orientation checks
- **Documentation:** `TECHNICAL/PROJECT_SETUP.md`
- **Status:** Not started — supersedes the paused Swift F-01

### F-02 — Content schemas and loader *(unchanged)*

All seven acceptance criteria carry over verbatim, including the `isSafe` location flag, `activityKind`, and the deferred-vocabulary build guard. `Codable` becomes explicit JSON serialization.

### F-03 — GameState, events, and the engine entry point *(unchanged, one addition)*

All five criteria carry over. Added:

  6. **Immutability is enforced, not assumed.** Dart lacks Swift's value semantics, so `GameState` and its members are immutable by construction (`final` fields, no in-place mutation), asserted by a test that mutating a returned state cannot affect the engine's own.

*This is the one place the language change creates real risk: the original design leaned on Swift value types for save correctness and test diffing.*

### F-04 — Step reconciliation test harness *(unchanged — and now runs on Windows)*

All twelve scenarios, written before the feature. Under the approved Swift plan these could not run on the owner's machine at all; under Flutter they run in `dart test` in under a second.

**Ordering rule stands: F-04 before S-02. Do not reorder it.**

### F-05 — Save, ledger, and crash recovery *(unchanged)*

### F-06 — Skill framework *(unchanged)*

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
  3. **The twelve F-04 scenarios pass against this adapter as well as the Android one** — one ledger, two adapters, identical results
  4. Locked-device read failure is handled: foreground backfill remains the source of truth
- **Tests:** The F-04 suite against the iOS adapter; adapter tests against a stubbed HealthKit store
- **Documentation:** `TECHNICAL/HEALTHKIT_INTEGRATION.md`
- **Status:** Blocked — needs macOS access
- **Note:** Authorable on Windows; **not verifiable there.** Treat as unverified until a Mac compiles and runs it — the F-01 lesson.

### S-02 — Reconciliation engine *(unchanged — turns F-04 green)*

All six criteria carry over, including the no-clawback rule and the content-tunable debt cap. Added:

  7. The engine is **platform-agnostic**: it consumes `StepProvider` results and never branches on platform.

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
- **Deliverables:** A working prototype of the four-bus mix, a seamless ambience crossfade on location change, and cue variant rotation
- **Acceptance criteria:**
  1. Four independent buses — ambience, action, UI, music — with independent volume
  2. **Ambience crossfade on arrival with no audible seam or gap**
  3. Repeated gathering rotates variants rather than repeating one sample
  4. Ducking for other apps' audio; silent switch respected; no background audio session
  5. Verified on Android; **iOS verification may trail**
- **Tests:** Manual listening check by the Audio Director; bus routing tests
- **Status:** Not started
- **Note:** Risk X-02. Audio is the one capability Flutter genuinely costs versus native. Finding a wall here at Phase 3 is recoverable; finding it at Phase 5 is not.

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

### P-01 — Visual identity *(unchanged)*

One addition: the palette and motion language must read correctly under **both** platform conventions, since Flutter renders its own widgets rather than adopting native controls.

### P-02 — Navigation and six tabs *(changed)*

All five criteria carry over. Added:

  6. Layouts adapt correctly on both a small and a contemporary standard-size device, on **both platforms**
  7. **Android back-button and gesture navigation behave correctly**, including inside the combat modal, which must not be dismissible by back gesture mid-encounter

### P-03 — The return summary *(unchanged)*
### P-04 — Combat screen *(unchanged, plus P-02.7)*
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
                          └─ S-01b (iOS) ····┐  needs macOS
                             S-09 (CI) ······┘
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
| **Needs macOS** | S-01b, S-09, plus the iOS half of V-01, V-02, V-03, V-06 |

**35 of 40 tasks require no Mac.** The five that do are concentrated in the iOS adapter, the build pipeline, and final iOS acceptance.

---

## Scope guard

Unchanged from `DECISIONS/0004`: four locations, five skills, three enemies, six tabs plus one modal, no currency, no merchants. Additions require a decision record.

**One new standing rule:** no third-party health plugin, on either platform. Step adapters are first-party platform channels. This is risk X-01, it is the condition the entire Flutter fidelity case rests on, and a health package appearing in `pubspec.yaml` should fail review.
