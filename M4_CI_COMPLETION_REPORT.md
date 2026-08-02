# M-4 Completion Report — Cross-Platform CI Validation

**Date:** 2026-08-02
**Repository:** `thcwtnnp5s-del/project-stride` (private)
**Branch:** `master`
**Status:** ✅ **Complete. All four jobs green on master.**

---

## 1. Headline

> **The iOS branch compiles.** The first time any Apple code in this project met a compiler, it failed. That is the entire justification for the macOS job, delivered on its first run.

Four jobs, all green on `master` at run **30730542145**. Three deliberate violations demonstrated failing on a disposable branch. Master was never left broken.

---

## 2. Workflow runs

Repository: `https://github.com/thcwtnnp5s-del/project-stride`
Run URL pattern: `…/actions/runs/<id>`

| # | Run ID | Branch | Commit | Result | What it established |
|---|---|---|---|---|---|
| 1 | `30729788361` | master | `b2cbdaa` | ❌ failure | Scripts were not executable on Linux |
| 2 | `30729874564` | master | `1c9f4d2` | ❌ failure | **Swift did not compile** |
| 3 | `30730182928` | master | `e54d72f` | ✅ **success** | First fully green run — all four jobs |
| 4 | `30730488575` | ci-failure-demo (PR #1) | `33e64eb` | ❌ failure | Purity + Pigeon drift caught |
| 5 | `30730542145` | master | `7231bb1` | ✅ **success** | Green after guard reordering — **current master** |
| 6 | `30730543864` | ci-failure-demo | `cf8e765` | ❌ failure | Purity guard message printed |
| 7 | `30730835437` | ci-failure-demo | `6dc4f5c` | ❌ failure | Dependency policy guard message printed |

PR #1 was closed unmerged and its branch deleted.

---

## 3. Exact job results — run 30730542145 (current master)

### Job 1 — Dart core · ubuntu-latest · ✅ success

| Step | Result |
|---|---|
| Resolve dependencies | ✅ |
| Core purity guard | ✅ |
| Dependency policy guard | ✅ |
| Format check | ✅ |
| Analyze (`--fatal-infos --fatal-warnings`) | ✅ |
| stride_core tests | ✅ 8 passed |
| App tests | ✅ 2 passed |
| stride_health Dart tests | ✅ 7 passed |

### Job 2 — Pigeon bindings · ubuntu-latest · ✅ success

| Step | Result |
|---|---|
| Resolve dependencies | ✅ |
| Regenerate and verify bindings | ✅ Dart, Kotlin, and Swift all match the contract |

### Job 3 — Android · ubuntu-latest · ✅ success

| Step | Result |
|---|---|
| Build application debug APK | ✅ |
| Build health-plugin example debug APK | ✅ |
| Kotlin adapter unit tests | ✅ 5 passed |
| Upload debug APK | ✅ artifact, 14-day retention |

No production signing. Debug signing only — no keystore, no secrets.

### Job 4 — iOS compile · macos-latest · ✅ success

| Step | Result |
|---|---|
| Resolve Flutter dependencies | ✅ |
| Regenerate and verify Pigeon output | ✅ verified independently on macOS |
| Platform-neutral tests | ✅ all 17 re-run on macOS |
| Compile iOS application shell | ✅ `--no-codesign` |
| Compile Swift health adapter | ✅ via the plugin host app |
| Unit tests not requiring HealthKit authorization | ✅ (no Swift test target yet — see §6) |

No signing, no TestFlight.

---

## 4. Behaviorally tested vs. compile-tested only

**Behavioral** — the code runs and its output is asserted:

| Check | Where |
|---|---|
| 8 `stride_core` tests — module contract, purity detector, rescan bounds | core, ios |
| 2 app widget tests — renders, links `stride_core`, no gameplay affordances | core, ios |
| 7 `stride_health` Dart tests — mock provider, deletions, invalidation, truncation | core, ios |
| **5 Kotlin adapter tests** — absence reports unavailable, valid never carries a rescan, no cursor offered when unavailable | android |
| Core purity guard | core |
| Dependency policy guard | core |
| Pigeon three-way binding drift | pigeon, ios |
| `dart format`, `flutter analyze --fatal-infos --fatal-warnings` | core |

**Compile-only** — it builds; nothing asserts what it does at runtime:

| Check | Why it stops there |
|---|---|
| Android debug APK (both) | Build artifacts, never launched in CI |
| Kotlin adapter *within the APK* | Its tests run on the JVM; the packaged form is compile-only |
| **iOS application shell** | `--no-codesign` output is not installable |
| **Swift health adapter** | No simulator execution, no Swift test target yet |

**No iOS check is behavioral.** The macOS job proves the Swift compiles and the Pigeon contract holds across all three sides. It proves nothing about HealthKit.

---

## 5. The deliberate failure demonstration

Three violations, on branch `ci-failure-demo` via PR #1. **Master was never broken.**

### 5.1 Core purity — run `30730543864`

```text
[Core purity guard] packages/stride_core/lib/src/ci_violation_probe.dart:2:import 'package:flutter/material.dart';
[Core purity guard] error: stride_core must stay pure.
[Core purity guard] ##[error]Process completed with exit code 1.
```

### 5.2 Pigeon drift — run `30730543864`

An extra field added to `PlatformRescan` in the contract, bindings left stale:

```text
[Regenerate and verify bindings] ##[error]Pigeon bindings are stale. Regenerate and commit:
[Regenerate and verify bindings] ##[error]  cd packages/stride_health && dart run pigeon --input pigeons/health_api.dart
[Regenerate and verify bindings] ##[error]Process completed with exit code 1.
```

### 5.3 Dependency policy — run `30730835437`

`health: ^11.0.0` added to the app pubspec:

```text
[Dependency policy guard] error: prohibited health package in ./pubspec.yaml
[Dependency policy guard] 15:  health: ^11.0.0
[Dependency policy guard] error: dependency policy violation.
[Dependency policy guard] Health integration is first-party, in packages/stride_health.
[Dependency policy guard] ##[error]Process completed with exit code 1.
```

This is risk **X-01**, the one the entire Flutter fidelity case rests on. It is now mechanically enforced, and the enforcement has been watched working.

### 5.4 What the demonstration itself caught

The first demo run exposed an ordering problem worth more than the demo. A `package:flutter` import inside `stride_core` is *also* an analyzer error, so the job died at analyze and **the guards never ran** — their specific messages, which name the rule and the fix, were never printed.

Guards now run first. A developer who adds a health package reads *"prohibited health package in ./pubspec.yaml"*, not a generic analyzer complaint three steps later. Committed to master in `7231bb1`.

An exercise meant to prove the guards work instead improved them, which is the argument for actually running these things rather than reasoning about them.

---

## 6. Fixes required for macOS/iOS compilation

Two, both found only by the macOS runner.

### 6.1 Scripts were not executable — run `30729788361`

```text
./Scripts/check-core-purity.sh: Permission denied
##[error]Process completed with exit code 126
```

Windows does not carry the POSIX executable bit, so the scripts were committed `100644` and Linux refused them. Fixed with `git update-index --chmod=+x`, plus CI now invoking them through `bash` explicitly so a future script added from Windows cannot reintroduce it.

*(Linux, not macOS — but the same class: a platform assumption invisible on the development machine.)*

### 6.2 `HealthKitAdapter` did not compile — run `30729874564`

```text
Swift Compiler Error (Xcode): Cannot find type 'FlutterStandardTypedData' in scope
```

The adapter imported only `Foundation`, but the Pigeon contract passes the opaque cursor as `FlutterStandardTypedData`. Fixed by adding `import Flutter`.

**This is the finding that justifies the whole job.** That Swift had been committed across three commits, reviewed, and described in two reports as "authored but never compiled." Every tool available on Windows was satisfied with it. It did not build.

The standing instruction — *the iOS branch must not be allowed to remain uncompiled until the end* — was correct, and the cost of ignoring it compounds with every file added.

---

## 7. Remaining unverified Apple-specific behavior

Everything beyond "it compiles."

| Area | Verified by | Needs |
|---|---|---|
| Swift adapter compiles | ✅ CI run 30730542145 | — |
| Pigeon Swift contract holds | ✅ CI | — |
| HealthKit authorization flow | ❌ | Physical iPhone (S-01b) |
| `HKAnchoredObjectQuery`, anchors, deletions | ❌ | Physical iPhone (S-01b) |
| `wasUserEntered` filtering | ❌ | Physical iPhone |
| Locked-device read failure | ❌ | Physical iPhone |
| Background delivery | ❌ | Physical iPhone |
| Cross-adapter equivalence | ❌ | Both devices (V-02b) |
| iOS audio, haptics, battery | ❌ | Physical iPhone |
| Signing, archiving, TestFlight | ❌ | Real Mac + Apple Developer Program |
| iOS UI, layout, gestures | ❌ | Simulator or device |

**No Swift unit-test target exists yet.** The iOS job checks for one and reports honestly when absent rather than silently passing. It arrives with the real HealthKit implementation at S-01b — tests that need interactive authorization cannot run on a CI runner at all, which is what V-02b and a physical device are for.

---

## 8. Token-expiration recovery — reframed

Per owner instruction, the equation is now an **initial hypothesis**, not settled architecture.

**The contract remains binding** — six clauses, unchanged:

1. Never reset the game ledger
2. Never treat rescanned history as all new
3. Never claw back granted progress
4. Never silently discard the cursor and grant full history
5. Persist a replacement token only after the ledger commit
6. Interrupted recovery is safe to retry

**The mechanism is open.** `max(0, windowTotal − grantedSinceWatermark)` is the default because it is simple and needs no persisted shadow of health data. It has a known weakness: it assumes a window total stable enough for arithmetic over it to mean something, which retroactive writes or multiple data origins could undermine.

Permitted alternatives, alone or combined: **record identities, origin metadata, time buckets, overlap fingerprints, aggregate reads, or a hybrid.** Settled at S-01 against the real Health Connect API.

One clarification added while reframing: using record identity *transiently within a single recovery pass* was never forbidden. The privacy constraint is on what the game **persists**, not what it reads — so identity-within-a-pass is the first alternative to reach for.

**Scenario 13 asserts the contract, not the arithmetic.** A test written against the equation would need rewriting when the mechanism changes, and a test you rewrite to make it pass has stopped being a test.

Updated in `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §6.6, `MILESTONE_01_TASK_BREAKDOWN.md` F-04, and `step_provider.dart`.

---

## 9. Recommended next task

> ### Execute M-5 and M-6 — retire the Swift scaffold and close the migration.

CI is green across all four jobs. The gate that has held since the Swift attempt is now satisfied:

| # | Condition | Status |
|---|---|---|
| 1 | `dart test` passes on the owner's machine | ✅ |
| 2 | `flutter test` passes on Windows | ✅ |
| 3 | App runs on an Android emulator from Windows | ✅ |
| 4 | **CI green, including the macOS iOS-compile job** | ✅ |
| 5 | Purity guard demonstrated failing | ✅ locally and in CI |
| 6 | Dependency policy guard demonstrated failing | ✅ locally and in CI |

M-5 removes `StrideCore/`, `App/`, and `project.yml` — inert since M-2, preserved in history at `859d0ac`. M-6 updates the manifest and closes the migration. Both are short.

**Then F-02**, on owner approval. It has been correctly gated on this all along, and the two compile failures found here are the evidence that the gate was worth keeping.
