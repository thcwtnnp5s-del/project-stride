# Migration Closure Report — M-5 and M-6

**Date:** 2026-08-02
**Repository:** `thcwtnnp5s-del/project-stride` (private), branch `master`
**Final CI run:** **`30752832663`** (commit `fe2f195`) — all four jobs green
**Prior run with identical code coverage:** `30752314906` (commit `ae66232`), where the 12 Swift tests first executed
**Status:** ✅ **The Flutter migration is complete.**

---

## 1. Headline

`DECISIONS/0010` is now the active architecture, in the tree as well as on paper. The Swift scaffold is gone, every document that described it is banded or rewritten, and **twelve Swift unit tests run on a simulator in CI** — the first behavioral coverage Apple-side code has ever had in this project.

Migration span: `DECISIONS/0002` (native Swift) → `0010` (Flutter), M-1 through M-6, seven commits, no history rewritten.

---

## 2. Files retired

Removed from the working tree at M-5. All preserved in history at commit **`859d0ac`**.

| Path | Was |
|---|---|
| `StrideCore/Package.swift` | Swift package manifest |
| `StrideCore/Sources/StrideCore/StrideCore.swift` | Module marker |
| `StrideCore/Tests/StrideCoreTests/CorePurityTests.swift` | Swift purity test |
| `StrideCore/Tests/StrideCoreTests/ModuleTests.swift` | Swift module test |
| `App/Stride/StrideApp.swift` | SwiftUI entry point |
| `App/Stride/RootPlaceholderView.swift` | SwiftUI placeholder |
| `App/Stride/Info.plist` | App Info.plist |
| `App/StrideTests/AppShellTests.swift` | XCTest shell tests |
| `project.yml` | XcodeGen specification |

Also removed: the `Stride.xcodeproj/` ignore rule, now meaningless.

**Nothing was squashed, rebased, or force-pushed.** `git log` reaches every commit of the superseded architecture.

---

## 3. Files retained

### The current Flutter iOS adapter — explicitly *not* retired

`packages/stride_health/ios/` is live production code, not scaffold. It contains `StrideHealthPlugin.swift`, `HealthKitAdapter.swift`, and generated `Messages.g.swift`, and it compiles in CI on every push.

### Migration documentation, kept deliberately

`MIGRATION_EXECUTION_PLAN.md`, `MIGRATION_IMPACT_F01.md`, `MIGRATION_COMPLETION_REPORT.md`, `M4_CI_COMPLETION_REPORT.md`, `ARCHITECTURE_REVIEW_CROSS_PLATFORM.md`, `MILESTONES/evidence/m2_android_emulator.png`.

### Historical documents, banded not deleted

Each now opens with a banner naming the replacement and saying plainly **do not implement anything below**:

- `DECISIONS/0002_TECHNOLOGY_STACK.md`
- `TECHNICAL/ARCHITECTURE_IMPLEMENTATION_PLAN_SWIFT_ARCHIVED.md`
- `MILESTONES/MILESTONE_01_TASK_BREAKDOWN_SWIFT_ARCHIVED.md`
- `MILESTONES/F-01_COMPLETION_REPORT.md`
- `STUDIO_INITIALIZATION_REPORT.md` §4 — the stack recommendation only; the audit itself stands

---

## 4. Documentation updated

### The one that mattered most

**All ten `.claude/agents/` definitions** still told a future agent:

> *Native Swift + SwiftUI, iOS 17+, with a platform-free `StrideCore` package (`DECISIONS/0002`)*

Those files load as standing context whenever a role is invoked. An agent asked for a technical review would have reasoned from a stack that no longer exists and a package that no longer exists. **This was the single most likely way a future Claude agent could have been misled**, and it survived four earlier document sweeps because it lives outside the documentation tree.

All ten now state Flutter, the pure-Dart `stride_core`, the first-party adapters, the no-third-party-health-plugin rule, and Android-first sequencing.

### Others

| Document | Change |
|---|---|
| `TECHNICAL/PROJECT_SETUP.md` | Was an Xcode/`xcodegen` document. Rewritten for Flutter, opening with an explicit "this is not a native SwiftUI app" |
| `FILE_MANIFEST.md` | Rewritten. Source tree, decision table with 0010 marked active and 0002 superseded, historical section |
| `PROJECT_KERNEL/12_DECISION_LOG.md` | 0010 marked **the active architecture decision** |
| `DECISIONS/0010` | Marked **ACTIVE**, migration complete |
| `.gitignore` | Swift scaffold rules removed |
| `DECISIONS/0003` | Stale bare `COMBAT_PHILOSOPHY.md` reference corrected |
| `DESIGN_REVIEW_FLUTTER.md` | Referenced `…_FLUTTER_PROPOSED.md`, renamed at promotion |
| `PROJECT_STATE.md` | Updated |

### Broken-path audit

A link checker over every Markdown file resolved every backticked file reference. Two genuine breaks found and fixed (above). The remainder are **forward references to planned deliverables** — `QA_REPORT.md`, `TECHNICAL/HEALTHKIT_INTEGRATION.md`, `GAME_BIBLE/BALANCE/01_FIRST_PASS_NUMBERS.md`, `items.json`, `audio_cues.json` — each named in a task that will create it. Those are correct, not stale.

### Could an obsolete file mislead a future agent?

Audited, and the answer is no:

1. No retired file remains in the tree.
2. Every historical document carries a banner in its first ten lines.
3. `CLAUDE.md`, `PROJECT_STATE.md`, `FILE_MANIFEST.md`, and `TECHNICAL/PROJECT_SETUP.md` — the four most likely entry points — all name Flutter within the first screen.
4. The ten agent definitions are corrected.
5. `grep -rl "Native Swift" --include="*.md"` returns only banded historical documents.

---

## 5. Swift tests added

`packages/stride_health/example/ios/RunnerTests/RunnerTests.swift` — **12 tests, all executed** on `iPhone 17 Pro` simulator in run `30752314906`.

### The refactor that made them possible

`HealthKitAdapter` now takes an injectable `HealthKitStepSource`. Production uses `HealthKitStepStore` (the S-01b shell); tests substitute fakes returning fabricated `RawStepReading` values, and fakes that throw.

This is not a compromise around missing HealthKit access. **An interactive authorization prompt cannot be answered on a CI runner**, so any test needing one could never run there. The injectable seam is the only way to get real coverage of mapping and error handling on a runner at all.

### Coverage against the six required areas

| # | Required | Tests |
|---|---|---|
| 1 | Unavailable service → normalized unavailable status | `testUnavailableServiceReportsUnavailable` |
| 2 | Authorization mapping matches the Pigeon/Dart contract | `testAuthorizationStatesMapOneToOne` — every `allCases` value round-trips, plus a case-count assertion that fails if a state is added without a mapping |
| 3 | A valid response does not require a rescan | `testValidResponseCarriesNoRescan`, `testInvalidatedResponseCarriesRescanAndZeroDelta` |
| 4 | An unavailable response offers no persistable cursor | `testUnavailableResponseOffersNoCursor`, `testInvalidatedResponseOffersNoCursor` |
| 5 | Cursor bytes pass through the typed boundary | `testOutboundCursorBytesSurviveTheBoundary`, `testInboundCursorAndWatermarkReachTheSource`, `testEmptyCursorIsPreservedRatherThanCoercedToNil` |
| 6 | Native errors become the typed error result, no crash | `testReadFailureBecomesTypedFailure`, `testAuthorizationFailureBecomesTypedFailure`, `testAFailingSourceDoesNotTrap` |

Three assertions worth calling out, because each encodes a rule the ledger depends on:

- **An invalidated response reports `newSteps = 0` even when the source supplied a figure.** The delta stream is broken; passing the number through is exactly the double-count scenario 13 exists to prevent.
- **An empty cursor is preserved, not coerced to nil.** An empty cursor and a missing cursor mean different things — one the platform produced, the other "never synced".
- **A failing source is called ten times without trapping.** A health read that goes wrong is a normal outcome the game survives, not a reason to take the app down.

---

## 6. Final CI run — `30752314906`

Commit `ae66232` on `master`. **All four jobs green.**

### Job 1 — Dart core · ubuntu · ✅

Resolve · core purity guard · dependency policy guard · format check · analyze `--fatal-infos --fatal-warnings` · `stride_core` **8 tests** · app **2 tests** · `stride_health` **7 tests**.

### Job 2 — Pigeon bindings · ubuntu · ✅

Regenerate and verify — Dart, Kotlin, and Swift all match the contract.

### Job 3 — Android · ubuntu · ✅

Application debug APK · plugin example debug APK · Kotlin adapter **5 JVM tests** · APK artifact uploaded. No production signing.

### Job 4 — iOS compile · macOS · ✅

Resolve · Pigeon verified independently on macOS · platform-neutral tests re-run (**17**) · iOS shell compiled `--no-codesign` · Swift adapter compiled · **12 Swift tests executed on iPhone 17 Pro simulator**. No signing, no TestFlight.

**Total automated tests: 44** — 17 Dart, 5 Kotlin, 12 Swift, plus the Dart suite re-run on macOS.

---

## 7. Behavioral vs. compile-only coverage

**Behavioral** — code runs, output asserted:

| Coverage | Where |
|---|---|
| 8 `stride_core` tests | core, ios |
| 2 app widget tests | core, ios |
| 7 `stride_health` Dart tests | core, ios |
| 5 Kotlin adapter tests (JVM) | android |
| **12 Swift adapter tests (simulator)** | **ios** |
| Core purity guard, dependency policy guard | core |
| Pigeon three-way drift | pigeon, ios |
| Format, analyze | core |

**Compile-only** — builds; runtime behavior unasserted:

| Coverage | Why |
|---|---|
| Android debug APKs | Built, never launched in CI |
| iOS application shell | `--no-codesign` output is not installable |
| `HealthKitStepStore` production path | It is the S-01b shell; only the *adapter around it* is tested |
| `HealthConnectAdapter` production path | Same — the Health Connect implementation is S-01 |

The change since M-4: iOS moved from **entirely compile-only** to **compile-plus-behavioral for the adapter layer**. The platform data sources on both sides remain shells, and that is the honest boundary.

---

## 8. Remaining unverified Apple-specific behavior

Everything touching HealthKit itself.

| Area | Needs |
|---|---|
| HealthKit authorization flow and denial | Physical iPhone (S-01b) |
| `HKAnchoredObjectQuery`, anchor persistence | Physical iPhone (S-01b) |
| `deletedObjects` handling | Physical iPhone (S-01b) |
| `HKMetadataKeyWasUserEntered` filtering | Physical iPhone |
| Locked-device read failure | Physical iPhone — cannot be simulated |
| Background delivery under real conditions | Physical iPhone |
| iOS audio, haptics, battery | Physical iPhone |
| Signing, archiving, TestFlight | Real Mac + Apple Developer Program |
| iOS UI, layout, gestures | Simulator or device |

The Swift tests prove the adapter maps correctly and fails safely. They prove **nothing** about whether HealthKit returns what we expect.

---

## 9. Remaining physical-device requirements

### Android

| Requirement | Task |
|---|---|
| Health Connect permission flow, real step records | S-01 |
| Changes API tokens against a real store | S-01 |
| **Token invalidation and bounded rescan recovery** | S-01, scenario 13 |
| Background sync under Doze and OEM battery policies | S-01 |
| Process-kill and save integrity | V-03 |
| Installed-APK validation | V-01 |
| Fourteen-day real-data log | V-02 — starts at S-02 |

### iPhone

| Requirement | Task |
|---|---|
| Everything in §8 | S-01b |
| Fourteen-day real-data log | V-02 |

### Both

**V-02b — cross-adapter equivalence.** The thirteen scenarios against both real adapters, comparing normalized outcomes for new steps, duplicates, delayed additions, corrections, deletions, interrupted sync, invalid-cursor recovery, and no-clawback. Internal cursor formats need not match; newly grantable progress and ledger outcomes must.

This is the mitigation for risk X-06 and cannot be done without both devices.

---

## 10. Migration-safety constraints — final audit

| Constraint | Status |
|---|---|
| Preserve all history, especially `859d0ac` | ✅ reachable, no rewriting |
| Do not rewrite or squash prior architecture | ✅ no rebase, no force-push |
| Do not remove the current Flutter iOS adapter | ✅ live and compiling |
| Remove obsolete scaffold files, scripts, references | ✅ nine files plus ignore rules |
| Preserve useful migration documentation | ✅ six documents plus evidence |
| Audit docs for stale native-Swift-as-current claims | ✅ ten agent definitions, setup doc, manifest, four banners |
| No obsolete file can mislead a future agent | ✅ §4 |
| Translation, not redesign | ✅ no behavioral change; no new decision record needed |

---

## 11. Closure checklist

| Item | Status |
|---|---|
| Four-job CI matrix run | ✅ `30752314906` |
| All jobs green | ✅ |
| `PROJECT_STATE.md` updated | ✅ |
| `FILE_MANIFEST.md` updated | ✅ |
| Technical structure docs updated | ✅ `PROJECT_SETUP.md`, `PROJECT_STRUCTURE.md` |
| `DECISIONS/0010` marked active | ✅ decision file and Kernel log |
| Previous architecture marked superseded | ✅ retained, banded |
| Broken internal paths checked | ✅ two fixed; rest are forward references |
| Local and `origin/master` synchronized | ✅ |
| Working tree clean | ✅ |

---

## 12. Recommended F-02 scope

> ### F-02 — Content schemas and loader: the platform-neutral content foundation.

Entirely in `packages/stride_core` and `assets/content/v1/`. **Runs on Windows, needs no device, no emulator, no Mac.**

### In scope

- **Stable content IDs** — string slugs, never array indices, never localized names
- **Item definitions** — raw materials, processed components, finished equipment, consumables, with tiers
- **Skill definitions** — the five M-01 skills, XP curves, unlock cadence, milestone rewards
- **Region and location definitions** — four locations, the travel graph, `isSafe`
- **Recipe definitions** — inputs, outputs, skill and level requirements
- **Enemy definitions** — three enemies with statistics and reward tables
- **Schema versioning** — `{"schemaVersion": 1, "entries": [...]}` with a migration hook that ships as a no-op but exists
- **Duplicate-ID rejection**
- **Cross-reference validation** — every referenced ID resolves
- **Human-readable validation errors** — naming the file, the entry, and the fix
- **Test fixtures** — one deliberately broken fixture per validation rule
- **Balance profiles** — production and accelerated QA, as separate profiles where switching never mutates production data (`DECISIONS/0007`)

### Explicitly out of scope

HealthKit or Health Connect ingestion · production UI · combat implementation · audio implementation · broad save-state implementation.

*(F-02 defines the content **schemas**; F-05 implements the save. The distinction matters: writing a save format now would couple it to a content model that is still being shaped.)*

---

## 13. Recommended F-02 acceptance criteria

1. All content files decode into typed `stride_core` values, and `dart test` runs them **on Windows in under a second**
2. Every ID is a stable string slug; **no array-index reference exists anywhere**
3. **Duplicate IDs are rejected**, within a file and across files, with the offending ID and both locations named
4. **Every cross-reference resolves** — recipes to items, nodes to skills and items, enemies to locations and drops, locations to each other, cues to materials
5. **No recipe is unreachable from starting equipment** — an automated path test from Training Sword/Axe/Pickaxe to Bronze. This is the guard against the C-05 bootstrap class of bug
6. **Every gatherable has a consumer**; no orphan items
7. Every skill has an XP curve with **no gaps from level 1 to 20**, and the cap is enforced
8. **Validation failures are test failures, never runtime crashes** — content is authored data, so content errors are caught by the suite that runs against the bundled pack
9. **Validation messages are human-readable**: file, entry ID, what is wrong, and what would fix it. A message a future author cannot act on has failed
10. **One deliberately broken fixture per validation rule**, each proving the validator catches it — a validator nobody has watched fail is a validator nobody knows works
11. `activityKind: terminating | repeating` present on activities; `isSafe` present on locations
12. **The deferred-vocabulary guard fails the build** on `expedition`, `profession`, `adventureMomentum`, `currency`, `merchant`, or any combat-skill identifier
13. **Production and accelerated balance profiles are distinct.** Switching leaves production values byte-identical, asserted by test; the accelerated profile is unavailable in release builds
14. **`stride_core` purity holds** — no Flutter, no plugin, no `dart:io` introduced by content loading
15. **No balance constant appears in Dart source.** Everything tunable lives in content
16. All four CI jobs stay green

---

## 14. Recommendation

**The migration is closed.** Proceed to F-02 on owner approval.

One note for the record. The gate that held from the Swift attempt onward — *do not build the next task on an unverified foundation* — was tested twice and paid twice: F-02 was blocked on a Swift build that never happened, saving a five-session rewrite; and the macOS job caught Swift that had been committed three times and described in two reports as working. It did not compile.

F-02 needs no such gate. It is pure Dart, it runs on the owner's machine in under a second, and every claim it makes will be verifiable where it is written.
