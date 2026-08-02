# Project Setup

**Authority:** `DECISIONS/0010_CROSS_PLATFORM_STACK.md`, `DECISIONS/0009_PLATFORM_AND_DISTRIBUTION.md`

> **Project Stride is a Flutter application** targeting Android and iOS, with first-party Swift (HealthKit) and Kotlin (Health Connect) health adapters behind a Pigeon-typed boundary.
>
> It is **not** a native SwiftUI app. That was `DECISIONS/0002`, superseded on 2026-08-01. If you find a document describing a `StrideCore` Swift package or an `xcodegen` workflow, it is history — see `MIGRATION_CLOSURE_REPORT.md`.

---

## Requirements

| | |
|---|---|
| Development OS | **Windows, macOS, or Linux** — Android development works on all three |
| Flutter | Current stable (3.44.8 verified) |
| Dart | Bundled with Flutter (3.12.2 verified) |
| JDK | 17 (Temurin verified) |
| Android SDK | platform-36, build-tools 36.1.0 |
| Xcode | **macOS only**, and only for iOS builds — CI covers compilation |

Android is fully developable on Windows. See `TOOLCHAIN_REPORT_WINDOWS.md` for the verified Windows setup.

---

## Layout

```text
ProjectStride/
├── lib/                        Flutter app — main.dart, ui/
├── packages/
│   ├── stride_core/            PURE DART — no Flutter, no plugins, no dart:io
│   └── stride_health/          First-party health plugin
│       ├── pigeons/            Contract — single source of truth
│       ├── android/            Kotlin — Health Connect
│       ├── ios/                Swift — HealthKit (SPM layout)
│       └── example/            Host app for native tests
├── test/                       App widget tests
├── android/  ios/              Flutter platform runners
├── Scripts/                    Guards and local verification
└── .github/workflows/ci.yml    Four-job matrix
```

Full detail in `TECHNICAL/PROJECT_STRUCTURE.md`.

---

## First-time setup

```bash
git clone https://github.com/thcwtnnp5s-del/project-stride.git
cd project-stride
flutter pub get
```

Then resolve the packages:

```bash
(cd packages/stride_core && dart pub get) && (cd packages/stride_health && flutter pub get) && (cd packages/stride_health/example && flutter pub get)
```

---

## Verification

Everything below runs on Windows. Nothing here needs macOS.

```bash
./Scripts/verify.sh
```

Runs, in order: core purity guard, dependency policy guard, format check, `stride_core` analyze and tests, workspace analyze, app tests, plugin tests. It degrades gracefully when a toolchain is absent and says so; `--strict` makes an absent toolchain a failure.

Run the app on an Android emulator:

```bash
flutter emulators --launch stride_pixel && flutter run
```

---

## The two enforced rules

### 1. `stride_core` stays pure

It must not import `package:flutter`, `dart:ui`, `dart:io`, or any plugin, and its `pubspec.yaml` must not declare a Flutter dependency.

**When the core needs a platform capability, do not import it.** Define a port in `packages/stride_core/lib/src/ports/`, implement it in the app or in `stride_health`, and inject it. `StepProvider` is the worked example.

Enforced by `packages/stride_core/test/core_purity_test.dart` and `Scripts/check-core-purity.sh`, both reading `StrideCore.forbiddenImports` so the rule and its guards cannot drift.

### 2. No third-party health package

Health integration is first-party, in `packages/stride_health`. No external package may own change tokens or anchors, reconciliation, deletion handling, double-count prevention, or ledger semantics.

Enforced by `Scripts/check-dependency-policy.sh` and a CI job. Utility packages remain allowed after normal dependency review.

---

## Regenerating the platform boundary

After editing `packages/stride_health/pigeons/health_api.dart`:

```bash
cd packages/stride_health && dart run pigeon --input pigeons/health_api.dart
```

Commit the generated Dart, Kotlin, and Swift. CI fails if they are stale. The Pigeon version is pinned exactly — an unpinned upgrade rewrites headers and fails the drift check for reasons unrelated to the contract.

Generated files are excluded from the format check: Pigeon output is not `dart format` clean, and formatting it would fail the drift check on the next regeneration.

---

## What needs macOS

Only these:

- Compiling, signing, and archiving the iOS app
- TestFlight upload
- iOS simulator or physical iPhone testing
- Developing and debugging the Swift HealthKit adapter (S-01b)
- iOS audio, haptic, and battery validation

**The CI macOS job compiles the iOS shell, the Swift adapter, and the Swift unit tests on every push**, so the iOS branch cannot rot between rare manual builds. Everything else runs on Windows.

## What needs a physical device

Real health data. Health Connect permissions and step records on Android; HealthKit authorization, anchored queries, and locked-device behavior on iOS; background sync, process-kill, and installed-APK validation on both. Tasks S-01, S-01b, and V-02b.
