# Migration Execution Plan — Swift Scaffold to Flutter

**Date:** 2026-08-01
**Owner agent:** Technical Director
**Authority:** `DECISIONS/0010_CROSS_PLATFORM_STACK.md`
**Status:** Presented for owner approval. **Not executed.**
**Assessment:** `MIGRATION_IMPACT_F01.md` — cost roughly one session

---

## Governing constraints

Four rules bind this migration. They come from the owner's migration-safety instruction and the critic review, and they exist because a stack change is the easiest possible moment to lose things quietly.

### 1. This is a translation, not a redesign *(CR-F-1)*

`DECISIONS/0004` froze scope against a Swift implementation, and every task is about to be re-created in Dart. Each re-creation is an opportunity to add "just one more thing" on the grounds that it is new code anyway.

> **Any behavioral change discovered during migration requires a decision record, not a judgement call.** Good ideas go to `JOURNAL/`, where nothing is approved by default.

### 2. Do not mechanically port unverified Swift *(CR-F-2)*

**The Swift F-01 scaffold was never compiled.** Translating never-compiled Swift into Dart would carry unknown errors across a language boundary while wearing the appearance of a port.

The scaffold is **reference for its enforcement patterns**, not a source to translate line by line:

- A core that cannot import the UI framework
- A guard implemented twice, reading one shared list
- A verification script honest about what it did not run
- The QA-F01-2 lesson: assert the build setting, not the runtime value
- The `verify.sh` bug: a script whose purpose is graceful degradation must be run in the degraded case

Those lessons carry. The code does not.

### 3. Preserve history, mark supersession, delete nothing that explains a decision

The Swift scaffold lives at commit `859d0ac`. `DECISIONS/0002` is marked superseded and retained. The v1.1 architecture plan and task breakdown are archived, not deleted.

### 4. Portable work is preserved intact

Decisions `0001`, `0003`–`0009`, `0011`; the ledger rules; the thirteen reconciliation scenarios; every Game Bible document; every design review and critic report. None of it is re-derived.

---

## Steps

### M-1 — Prepare *(no code)*

**Deliverables:** Git remote created; branch `migration/flutter`; Flutter SDK and Android SDK installed on the Dell; Android emulator running.

**Acceptance:**
1. `flutter doctor` reports no blocking issues for Android
2. An emulator launches and runs a stock Flutter counter app
3. `git remote -v` shows the remote — required for CI and for GitHub release artifacts (`DECISIONS/0011`)

**Rollback:** none needed; nothing has changed in the repository.

### M-2 — Scaffold the structure

**Deliverables:** The layout in `TECHNICAL/PROJECT_STRUCTURE.md` — Flutter app, `packages/stride_core`, `packages/stride_health` with its `example/`, `assets/content/v1/`, and Pigeon definition.

**Acceptance:**
1. `packages/stride_core/pubspec.yaml` declares **no `flutter` dependency**
2. `dart test` runs in `stride_core` **on Windows**, with at least one real assertion
3. `flutter run` launches the placeholder on an Android emulator **from Windows**
4. `dart run pigeon` generates all three sides from one definition; the Pigeon version is **pinned**
5. No third-party health package appears in any `pubspec.yaml`
6. `minSdkVersion` chosen, with its player consequence stated *(TD-F-4)*
7. Android `allowBackup` disabled — an auto-backup restored to a second device would duplicate the step ledger

**Rollback:** delete the branch. `main` is untouched.

### M-3 — Port the enforcement patterns

**Deliverables:** `test/core_purity_test.dart`; `Scripts/check-core-purity.sh` updated for Dart; `Scripts/verify.sh` rewritten for the Flutter toolchain.

**Acceptance:**
1. The purity guard **fails** when `package:flutter` is added to `stride_core`, demonstrated once — as it was for Swift
2. The guard does not false-positive on the forbidden module names appearing in comments or string literals
3. Both enforcement points read **one shared list**
4. `dart:io` is on the forbidden list — the core touches neither the file system nor the clock
5. `verify.sh` is run in every mode it supports, including the degraded ones, before it is trusted

Criterion 5 is there because the Swift version of this script shipped with an unreachable fallback path that only appeared when someone ran it on a machine without the toolchain.

**Rollback:** delete the branch.

### M-4 — Wire CI

**Deliverables:** `.github/workflows/ci.yml` active on the remote.

**Acceptance:**
1. The `core`, `dependency-policy`, `app-android`, and `ios` jobs all run on push
2. **The macOS job compiles iOS** — satisfying `DECISIONS/0010`: the iOS branch must not remain uncompiled
3. A deliberately broken commit fails the pipeline; a clean one passes — **demonstrated once in each direction**
4. The dependency-policy job **fails** when a health package is added to a `pubspec.yaml`, demonstrated once
5. The APK artifact is downloadable from the run

Criteria 3 and 4 are demonstrations, not assertions. A guard nobody has watched fail is a guard nobody knows works.

**Rollback:** disable the workflow; nothing else depends on it.

### M-5 — Retire the Swift scaffold

**Deliverables:** `StrideCore/`, `App/`, and `project.yml` removed. `TECHNICAL/PROJECT_SETUP.md` rewritten for Flutter on Windows.

**Acceptance:**
1. No Swift or Xcode-project file remains outside `packages/stride_health/ios/` and the Flutter `ios/` runner
2. `git log` still reaches the scaffold at `859d0ac`
3. `MILESTONES/F-01_COMPLETION_REPORT.md` retained, marked superseded
4. No document still instructs a reader to run `xcodegen generate`

**Rollback:** `git revert`. This is the first irreversible-feeling step, and it is deliberately last — the tree carries both stacks until everything Flutter is green.

### M-6 — Close the migration

**Deliverables:** `PROJECT_STATE.md` and `FILE_MANIFEST.md` updated; branch merged; F-01 restarted in Flutter form.

**Acceptance:**
1. `PROJECT_STATE.md` names Flutter, both platforms, and the current task
2. `FILE_MANIFEST.md` lists the new structure and the archived documents
3. CI green on `main`
4. F-01 (Flutter) marked **In progress**, its Swift predecessor **Superseded**

---

## What must be true before F-02 starts

The lesson from the Swift attempt, carried forward as a gate:

| # | Condition |
|---|---|
| 1 | `dart test` passes on `stride_core` on the owner's machine |
| 2 | `flutter test` passes on Windows |
| 3 | The app runs on an Android emulator from Windows |
| 4 | **CI is green, including the macOS iOS-compile job** |
| 5 | The purity guard has been demonstrated failing |
| 6 | The dependency-policy guard has been demonstrated failing |

Condition 4 matters most. Under the Swift path, F-02 was gated on a build that never happened — and that gate is the only reason this migration costs one session instead of five.

---

## Risks

| # | Risk | Mitigation |
|---|---|---|
| M-R1 | Migration becomes redesign | Constraint 1; any behavioral change needs a decision record |
| M-R2 | Unverified Swift ported as though verified | Constraint 2; patterns carry, code does not |
| M-R3 | Flutter setup consumes more time than expected | M-1 is standalone; discovering a toolchain problem there costs nothing |
| M-R4 | iOS job fails first run for signing or CocoaPods reasons | Expected. `--no-codesign` avoids signing entirely; budget one debugging pass |
| M-R5 | A health plugin is added "temporarily" during scaffolding | The dependency-policy job fails the build. Risk X-01. |
| M-R6 | Something in the archived plans is lost | Nothing is deleted; archives are referenced from the live documents |

---

## Estimate

| Step | Effort |
|---|---|
| M-1 Prepare | Half a session — mostly SDK downloads |
| M-2 Scaffold | One session |
| M-3 Enforcement | Half a session |
| M-4 CI | Half a session, plus one likely iOS debugging pass |
| M-5 Retire | Under an hour |
| M-6 Close | Under an hour |

**Roughly two to three sessions**, against the one estimated in `MIGRATION_IMPACT_F01.md`. That assessment counted the translation only; this plan adds CI wiring and toolchain setup, which are new capability rather than migration cost.

---

## Recommendation

**Approve and execute.**

The order is deliberate: **the Swift scaffold is retired last**, at M-5, after everything Flutter is green. Until then the tree carries both and the migration can be abandoned at any point by deleting a branch.

Nothing in this plan touches game design. Every decision except the stack survives, and the architecture's shape survives with it.
