# F-01 Completion Report — Foundation Skeleton and Core Purity

**Task:** F-01
**Owner agent:** Technical Director
**Date:** 2026-08-01
**Status:** **Complete except build verification, which is blocked on macOS access**
**Reviews:** QA Director and Critic Agent, below

---

## 1. What was built

| Deliverable | Path |
|---|---|
| `StrideCore` package manifest | `StrideCore/Package.swift` |
| Core module marker | `StrideCore/Sources/StrideCore/StrideCore.swift` |
| Core module tests | `StrideCore/Tests/StrideCoreTests/ModuleTests.swift` |
| Core purity tests | `StrideCore/Tests/StrideCoreTests/CorePurityTests.swift` |
| App entry point | `App/Stride/StrideApp.swift` |
| Placeholder screen | `App/Stride/RootPlaceholderView.swift` |
| App Info.plist | `App/Stride/Info.plist` |
| App target tests | `App/StrideTests/AppShellTests.swift` |
| Xcode project spec | `project.yml` |
| Import boundary guard | `Scripts/check-core-purity.sh` |
| Full verification pass | `Scripts/verify.sh` |
| Setup documentation | `TECHNICAL/PROJECT_SETUP.md` |

Nothing else. No game state, no content schema, no HealthKit, no save file, no navigation, no visual design.

---

## 2. Acceptance criteria

| # | Criterion | Result |
|---|---|---|
| 1 | App builds and launches to a placeholder screen on both simulators | ⛔ **Blocked** — no macOS |
| 2 | `StrideCore` tests run with `swift test`, no simulator, under a second | ⛔ **Blocked** — no Swift toolchain |
| 3 | Import guard **fails** when a forbidden import is added, demonstrated once | ✅ **Verified** |
| 4 | `Info.plist` permits portrait only, with a check | ✅ Written and asserted; assertion unexecuted |
| 5 | iOS 17 target, iPhone-only, no iPad idiom | ✅ Written and asserted; assertion unexecuted |
| 6 | No third-party runtime dependency declared | ✅ **Verified** |

### Criterion 3 — the evidence

Executed here, on this machine, since the guard needs only bash and grep:

```text
--- clean tree ---
core purity: OK (1 source files, 11 forbidden modules checked)      exit=0

--- with a probe file containing `import SwiftUI` / `import HealthKit` ---
__violation_probe.swift:1:import SwiftUI
__violation_probe.swift:2:import HealthKit
error: StrideCore must not import platform frameworks.               exit=1

--- probe removed ---
core purity: OK (1 source files, 11 forbidden modules checked)      exit=0
```

The clean pass is itself a false-positive test: `StrideCore.swift` contains `"SwiftUI"` and `"HealthKit"` as string literals in the `forbiddenImports` array, and the guard correctly ignores them. It matches import *statements*, not the word.

### Criterion 6 — the evidence

`StrideCore/Package.swift` declares an empty `dependencies` array with a comment stating that adding to it requires a decision record. `project.yml` declares one package, the local `StrideCore`. XcodeGen is a build-time tool that ships nothing into the app.

---

## 3. The blocker

**iOS development requires macOS. This repository is on Windows 11, with no Swift toolchain, no Xcode, and no simulator.**

```text
$ command -v swift       → not installed
$ command -v xcodebuild  → not installed
```

`DECISIONS/0009` says "the current stable Xcode installed on the development machine." That machine is not this one. Everything authorable has been authored; criteria 1 and 2 need a Mac, and criteria 4 and 5 are written as executable assertions that have never been run.

**This is not a small caveat.** Swift code that has never been compiled should be assumed to contain compile errors. The sources here are short and conventional, but that is a reason for mild confidence, not a substitute for a build.

### What is needed

Either the repository moves to a Mac, or one is added to the workflow. On a Mac, the whole verification is:

```bash
brew install xcodegen && xcodegen generate && ./Scripts/verify.sh
```

Until then F-01 is **In review**, not **Done**, and F-02 should not start — building the content schema on an unverified skeleton would compound the risk.

---

## 4. Decisions taken during implementation

**Generated Xcode project rather than a committed `.xcodeproj`.** A `.pbxproj` is opaque, machine-ordered, and conflicts constantly; `project.yml` is reviewable text. This adds XcodeGen as a build-time tool. It ships nothing, so it does not engage the no-dependencies rule in `DECISIONS/0002` — but it is a tool the owner must install, so it is flagged rather than assumed. `TECHNICAL/PROJECT_SETUP.md` documents an equivalent manual path.

*Contributing reason, stated plainly:* hand-writing a valid `.pbxproj` in an environment where it cannot be opened or compiled would produce a file nobody could trust. A forty-line spec is honest about what was actually verified.

**The forbidden-import list lives in `StrideCore.swift`.** Both enforcement points read from it, so the rule and its enforcement cannot drift.

**No HealthKit usage string in `Info.plist` yet.** It arrives in S-01 with the capability and the rationale screen. Declaring a permission the app cannot justify would be backwards.

---

## 5. QA Director review

### Summary

The deliverables match the scope limit exactly — no gameplay, no HealthKit, no production UI. The purity guard is the only criterion that could be executed here, and it was, including its failure path. My concern is entirely about what could not be run.

### Findings

**QA-F01-1 — Four criteria are written but unexecuted.** Criteria 1, 2, 4, and 5 exist as code and assertions that have never compiled. Criteria 4 and 5 in particular *look* verified in the table above because the assertions are written; they are not. The table marks this honestly, and I want it restated here so nobody skims the checkmarks: **an assertion that has never run has verified nothing.**

*Required:* F-01 stays In review until `./Scripts/verify.sh` passes on a Mac. Do not mark it Done on the strength of authored-but-unbuilt code.

**QA-F01-2 — `testDeploymentTargetIsAtLeastIOS17` tests the wrong thing.** It asserts the *runtime* OS version of the simulator or device, not the *build setting*. A device running iOS 18 passes it regardless of what the deployment target is set to. It would only catch a misconfiguration if someone ran the tests on an iOS 16 device, which the deployment target already prevents.

*Required:* replace with a build-setting check, or delete it. A test that cannot fail for the reason it claims to test is worse than no test — it produces false confidence.

**QA-F01-3 — `verify.sh` skips simulator builds when `xcodebuild` is absent and exits 0.** That is the right behavior for a developer running the toolchain-independent checks, but it means a misconfigured CI runner would report success having built nothing.

*Required:* add a `--strict` flag that fails when `xcodebuild` is missing, and use it in CI when CI exists.

### Recommendation

Approve the work. **Do not close the task.** Apply QA-F01-2 now, QA-F01-3 when CI is set up, and hold In review until a Mac build passes.

---

## 6. Critic Agent review

### Summary

Scope discipline held. The placeholder screen is genuinely a placeholder rather than a smuggled first draft of the Adventure tab, and the Info.plist omits the HealthKit string rather than getting ahead of S-01. Two findings, one of which I consider load-bearing.

### Findings

**CR-F01-1 — Building further on an unverified skeleton is the real risk.** F-02 through F-05 all sit on this foundation. If `Package.swift`'s `swiftLanguageMode` setting, the XcodeGen spec, or the test target wiring is wrong, every task built on top inherits the problem and the debugging surface grows with each one.

*Recommendation:* hard-gate F-02 on a green `verify.sh`. This is the cheapest possible moment to find out the skeleton is wrong. It is also exactly the reasoning behind ordering F-04 before S-02, so the principle is already established.

**CR-F01-2 — `SWIFT_TREAT_WARNINGS_AS_ERRORS: YES` is set project-wide before a single line of real code exists.** I am flagging it as a prediction rather than an objection: it is the correct setting, and it is also the setting most likely to be quietly switched off during the first frustrating afternoon in Phase 3.

*Recommendation:* leave it on, and record here that turning it off is a decision requiring a note, not a keystroke.

### What I checked and found clean

- No gameplay leaked into F-01. No state, no content, no skills, no steps.
- No deferred vocabulary anywhere — no Expedition, Profession, Adventure Momentum, currency, merchant, or combat skill.
- No Kernel violation, no anti-feature, no premature abstraction.
- The dual enforcement of the purity rule reading one shared list is a genuinely good detail; it closes the usual failure where a guard drifts from the rule it guards.

### Recommendation

**Approve, task remains open.** CR-F01-1 is a gate, not a suggestion.

---

## 7. Status and next step

**F-01: In review.** All authorable work is complete. Build verification requires macOS.

### Corrections applied during review

1. **QA-F01-2 — applied.** `testDeploymentTargetIsAtLeastIOS17` is replaced by `testDeploymentTargetIsIOS17`, which reads `MinimumOSVersion` from the built Info.plist — the build setting itself rather than the runtime OS. A companion `testTargetsIPhoneOnly` checks `UIDeviceFamily == [1]`.
2. **QA-F01-3 — applied.** `verify.sh` takes `--strict`, which fails when the toolchain is absent instead of skipping.

### A third defect, found while testing the fix

Verifying `--strict` exposed a bug in `verify.sh` that neither review caught: it called `swift test` unguarded under `set -e`, so on a machine with no Swift toolchain it died at exit 127 before ever reaching its graceful xcodebuild fallback. The fallback was unreachable on exactly the machines it existed for.

Fixed by guarding the Swift step the same way as the xcodebuild step. Verified in all three modes:

```text
default : purity OK → swift skipped → xcodebuild skipped → exit 0
strict  : purity OK → error, swift not found            → exit 1
--nope  : error, unknown option                          → exit 2
```

Worth recording plainly: a script whose whole purpose is graceful degradation was not itself run in the degraded case until someone tried it. The tests I *could* run on this machine found a defect the reviews reasoned past.

**The next step is not F-02.** It is confirming where the Mac is, running `./Scripts/verify.sh`, and reporting the result. F-02 is gated on that being green.
