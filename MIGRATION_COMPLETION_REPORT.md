# Migration Completion Report — M-1 through M-3

**Date:** 2026-08-01
**Steps executed:** M-1 (prepare), M-2 (scaffold), M-3 (enforcement)
**Not executed:** M-4 (CI activation), M-5 (retire Swift scaffold), M-6 (close)
**Commit:** `5fe0796`
**Status:** **Stop gate reached. Awaiting owner review before F-02.**

---

## 1. Headline

The Flutter workspace exists, compiles, and is tested. **17 tests pass on Windows in under a second**, with no emulator, no simulator, and no Mac.

Two things are outstanding, one of which needs the owner:

| | |
|---|---|
| ⛔ **JDK install failed** | Blocks the Android build and the emulator check |
| ⏸ **GitHub repo not created** | `gh` needs an interactive login — commands in §7 |

Neither blocks the work already done, and neither is a design problem.

---

## 2. Files and packages created

### Pure Dart core — `packages/stride_core`

| File | Purpose |
|---|---|
| `pubspec.yaml` | **No Flutter dependency.** The rule made structural |
| `lib/stride_core.dart` | Public API |
| `lib/src/core_info.dart` | Module marker and the forbidden-import list both guards read |
| `lib/src/ports/step_provider.dart` | The `StepProvider` port and the cursor-recovery contract |
| `test/core_info_test.dart` | Module and contract tests |
| `test/core_purity_test.dart` | The boundary, enforced in test form |

### First-party health plugin — `packages/stride_health`

| File | Purpose |
|---|---|
| `pigeons/health_api.dart` | **Single source of truth** for all three platform sides |
| `lib/src/messages.g.dart` | Pigeon-generated Dart |
| `lib/src/platform_step_provider.dart` | Translates the boundary into the core port. No reconciliation logic |
| `lib/src/mock_step_provider.dart` | Scriptable provider — the instrument the thirteen scenarios use |
| `android/…/StrideHealthPlugin.kt` | Registration |
| `android/…/HealthConnectAdapter.kt` | Shell + full spec for S-01 |
| `android/…/Messages.g.kt` | Pigeon-generated Kotlin |
| `ios/stride_health/Sources/stride_health/StrideHealthPlugin.swift` | Registration |
| `ios/…/HealthKitAdapter.swift` | Shell + full spec for S-01b |
| `ios/…/Messages.g.swift` | Pigeon-generated Swift |
| `example/` | Host app — the only practical way to test a plugin's native halves |
| `test/mock_step_provider_test.dart` | 7 tests |

### App shell

`lib/main.dart`, `lib/ui/root_placeholder.dart`, `test/app_shell_test.dart`, `pubspec.yaml`, `android/`, `ios/`.

**Mobile only, verified:** the project has `android/` and `ios/` and no `web/`, `windows/`, `linux/`, or `macos/` directory.

### Tooling

`Scripts/check-core-purity.sh`, `Scripts/check-dependency-policy.sh` (new), `Scripts/verify.sh`, `.gitignore` (rewritten for Flutter, with an explicit secrets block), `TOOLCHAIN_REPORT_WINDOWS.md`.

---

## 3. What compiled and ran on Windows

Full `./Scripts/verify.sh` output, all green:

```text
=== Core purity ===
core purity: OK (3 Dart files, 7 forbidden imports checked)
=== Dependency policy ===
dependency policy: OK (4 pubspec files checked)
=== Format (hand-written Dart only) ===
=== stride_core: analyze and test (no Flutter, no emulator) ===
No issues found!
00:00 +8: All tests passed!
=== Workspace analyze ===
No issues found! (ran in 7.8s)
=== Flutter tests ===
00:00 +2: All tests passed!
=== stride_health tests ===
00:00 +7: All tests passed!
All checks passed.
```

**17 tests: 8 core + 2 app + 7 plugin.** Static analysis clean across the workspace with `--fatal-infos`. Pigeon generated all three sides from one definition.

This is the migration's whole point, delivered: under the superseded Swift decision, none of this could run on the owner's machine.

### Guards demonstrated failing

A guard nobody has watched fail is a guard nobody knows works.

**Purity guard** — injected `import 'package:flutter/material.dart'` into `stride_core`:

```text
__probe.dart:1:import 'package:flutter/material.dart';
error: stride_core must stay pure.
script exit=1
```

The Dart test failed on the same probe. After removal: `core purity: OK`.

**Dependency policy** — injected `health: ^11.0.0` into the app pubspec:

```text
error: prohibited health package in ./pubspec.yaml
15:  health: ^11.0.0
exit=1
```

After removal: `dependency policy: OK`.

**`verify.sh`** — exercised in all three modes: default (skips absent toolchains, exit 0), `--strict` (fails on an absent toolchain, exit 1), unknown flag (exit 2).

---

## 4. What compiled on macOS CI

**Nothing yet.** M-4 was not executed, and CI cannot run before the GitHub repository exists.

`.github/workflows/ci.yml` is written and committed. It has never run, so **it must be treated as unverified** — the same standard applied to the Swift scaffold. Expect at least one debugging pass on first execution; that cost is budgeted in `MIGRATION_EXECUTION_PLAN.md` (M-R4).

### Which CI checks are compile-only versus behaviorally verified

| Check | Job | Kind |
|---|---|---|
| Dart format, analyze | `core`, `app-android` | **Behavioral** — the tool either passes or fails |
| `dart test` on `stride_core` | `core` | **Behavioral** |
| Core purity | `core` | **Behavioral** |
| Dependency policy | `dependency-policy` | **Behavioral** |
| Pigeon drift | `app-android` | **Behavioral** |
| `flutter test` widget/unit | `app-android` | **Behavioral** |
| `flutter test` in `stride_health` | `app-android` | **Behavioral** |
| Android APK build | `app-android` | **Compile-only** |
| Kotlin adapter | `app-android` | **Compile-only** — Health Connect behavior arrives in S-01 |
| iOS app build (unsigned) | `ios` | **Compile-only** |
| Swift adapter | `ios` | **Compile-only** — HealthKit behavior arrives in S-01b |

**No iOS check is behavioral.** The macOS job proves the Swift compiles and the Pigeon contract holds across all three sides. It proves nothing about HealthKit, which needs a physical iPhone (V-02b).

---

## 5. Known warnings and failures

### ⛔ JDK install failed — Android-blocking

Two attempts, both failing at download rather than install:

```text
Microsoft.OpenJDK.17        → InternetOpenUrl() failed. 0x80072f78
EclipseAdoptium.Temurin.17  → stalled past a 15-minute timeout
```

Probably a network restriction on the JDK CDNs: Flutter's ~1 GB clone and the 136 MB Android command-line tools both succeeded over the same connection.

**Consequence:** `sdkmanager` and Gradle cannot run, so `platform-tools`/`adb`, the emulator, and the Android licences are all blocked. `flutter doctor` reports `[X] Android toolchain`.

**M-2 acceptance criterion 3 — "app runs on an Android emulator from Windows" — is therefore NOT met.** Recovery steps are in `TOOLCHAIN_REPORT_WINDOWS.md` §"To finish the Android chain".

### ⏸ GitHub repository not created

`gh` 2.97.0 is installed but not authenticated, and login is interactive. Paused here per instruction. Commands in §7.

### Expected, not failures

- **Xcode absent.** Not listed by `flutter doctor` on Windows at all. iOS compiles in CI.
- **Visual Studio absent.** Only needed for Windows *desktop* builds. Mobile only — ignore permanently.
- **Chrome/Edge listed as devices.** SDK-level web support; the project has no `web/` target.

---

## 6. Apple-specific behavior still unverified

Everything. Nothing Apple has been compiled or run.

| Area | Verified by |
|---|---|
| Swift adapter compiles | CI `ios` job — **after M-4** |
| Pigeon Swift contract holds | CI `ios` job — **after M-4** |
| HealthKit authorization | S-01b, physical iPhone |
| Anchored queries, deletions, `wasUserEntered` | S-01b + V-02b |
| Locked-device read failure | Physical iPhone |
| Background delivery | Physical iPhone |
| iOS audio, haptics, battery | Physical iPhone |
| Signing, TestFlight | Real Mac access |

`HealthKitAdapter.swift` is **authored but never compiled.** Treat it as unverified — the F-01 lesson, applied to itself.

---

## 7. Owner action — create the GitHub repository

`gh` is installed; the login is interactive. From the repository root:

```bash
gh auth login --hostname github.com --git-protocol https --web
```

Then, still from the repository root:

```bash
gh repo create project-stride --private --source=. --remote=origin --push
```

That creates a **private** repository named `project-stride`, sets `origin`, and pushes **all four commits**, including the superseded Swift scaffold at `859d0ac`.

Verify:

```bash
git remote -v && git log --oneline
```

GitHub Actions is enabled by default on new repositories; the workflow runs on the first push. Confirm at `https://github.com/<you>/project-stride/actions`.

### Nothing sensitive is committed

Scanned before committing: no keystores, certificates, provisioning profiles, tokens, service-account files, or `local.properties`. `.gitignore` now has an explicit secrets block covering `*.jks`, `*.keystore`, `*.p12`, `*.pem`, `key.properties`, `.env*`, `google-services.json`, and `GoogleService-Info.plist`.

Signing credentials will be needed eventually for Play and TestFlight. **They go in GitHub Actions secrets, never in the repository.**

---

## 8. Deviations from the specification

Three, all discovered by running the tooling rather than reasoning about it.

**8.1 — The Flutter package template is not pure.** `flutter create --template=package` produces a package that depends on Flutter and `flutter_test`, which is precisely what the purity rule forbids. `stride_core` was rewritten by hand: no Flutter, `dart test` instead of `flutter_test`, `lints` instead of `flutter_lints`.

**8.2 — The iOS plugin uses the Swift Package Manager layout.** Pigeon was configured to write into `ios/Classes/`, matching the pre-build specification. The template actually generates `ios/stride_health/Sources/stride_health/`, so the generated Swift would have sat in a directory that is never compiled — and CI would have "passed" while building none of it. Corrected in `pigeons/health_api.dart` and in `TECHNICAL/PROJECT_STRUCTURE.md`.

**8.3 — Pigeon output is not `dart format` clean.** Formatting it would fail the drift check on the next regeneration; leaving it unformatted would fail a whole-tree format check. Resolved by formatting hand-written Dart only, in both `verify.sh` and CI.

Also corrected: the CI Android step called `./gradlew` directly, but Flutter's generated `android/.gitignore` excludes the Gradle wrapper, so that would fail on a fresh checkout. It now goes through `flutter build`.

**None of these changed a design decision.** They are the difference between a specification and a build — the reason M-2 was worth executing before F-02 rather than after.

---

## 9. Migration-safety constraints — honoured

| Constraint | Status |
|---|---|
| Preserve the Swift scaffold in git history | ✅ `859d0ac`, and still in the working tree until M-5 |
| Mark the Swift decision superseded, not deleted | ✅ `DECISIONS/0002` retained with a supersession header |
| Do not mechanically port unverified Swift | ✅ Nothing translated line by line. The **patterns** carried: a core that cannot import the UI framework, guards reading one shared list, a verify script honest about what it skipped |
| Preserve portable decisions, ledger rules, tests, docs | ✅ `0001`, `0003`–`0009`, `0011` untouched |
| Replace the task plan only after four-role review | ✅ `DESIGN_REVIEW_FLUTTER.md`, all ten findings applied |
| Translation, not redesign | ✅ No behavioral change introduced; no decision record needed |

---

## 10. Acceptance against `MIGRATION_EXECUTION_PLAN.md`

### M-1 — Prepare

| # | Criterion | Result |
|---|---|---|
| 1 | `flutter doctor` clean for Android | ⛔ **Not met** — JDK blocked |
| 2 | Emulator runs a stock Flutter app | ⛔ **Not met** — blocked by 1 |
| 3 | Git remote configured | ⏸ **Paused** — needs owner login |

### M-2 — Scaffold

| # | Criterion | Result |
|---|---|---|
| 1 | `stride_core` declares no Flutter dependency | ✅ |
| 2 | `dart test` runs on Windows with real assertions | ✅ 8 tests |
| 3 | `flutter run` on an Android emulator | ⛔ **Not met** — blocked by M-1 |
| 4 | Pigeon generates all three sides; version pinned | ✅ pinned `27.3.0` |
| 5 | No third-party health package | ✅ enforced |
| 6 | `minSdkVersion` chosen with player consequence stated | ⛔ **Not met** — needs the Android SDK to set meaningfully |
| 7 | `allowBackup` disabled | ⛔ **Not met** — deferred with 6 |

### M-3 — Enforcement

| # | Criterion | Result |
|---|---|---|
| 1 | Purity guard demonstrated failing | ✅ script and test |
| 2 | No false positive on comments/strings | ✅ tested explicitly |
| 3 | Both enforcement points read one shared list | ✅ |
| 4 | `dart:io` on the forbidden list | ✅ |
| 5 | `verify.sh` run in every mode | ✅ three modes |

**M-3 is complete. M-1 and M-2 are complete except what the JDK blocks.**

---

## 11. Recommended next task

> ### Install a JDK, finish the Android SDK, and create the GitHub repository — then execute M-4.

In order:

1. **Owner:** run the two `gh` commands in §7.
2. **Owner or Studio:** install Temurin 17 and finish the SDK chain per `TOOLCHAIN_REPORT_WINDOWS.md`. Retrying winget is worth one attempt; the direct `.msi` from adoptium.net is the fallback.
3. **Studio:** close the three deferred M-2 criteria — `minSdkVersion` with its player consequence, `allowBackup=false`, and the emulator run.
4. **Studio:** execute **M-4**, wiring CI and demonstrating it failing on a deliberately broken commit and passing on a clean one. **This is the first time any Apple code will be compiled.**

**F-02 should not start until CI is green, including the macOS job.** That gate is exactly what kept this migration to one session of rework instead of five, and the reasoning has not changed.

M-5 (retire the Swift scaffold) deliberately comes last, after everything Flutter is green. Until then the tree carries both and the migration can still be abandoned.
