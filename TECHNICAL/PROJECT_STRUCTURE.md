# Project Structure

**Authority:** `DECISIONS/0010_CROSS_PLATFORM_STACK.md`
**Status:** **Built.** Created at migration step M-2 and verified on Windows — see `MIGRATION_COMPLETION_REPORT.md`.

> Two things differ from the pre-build specification, both discovered by actually running the tooling:
>
> * The plugin's iOS side uses the **Swift Package Manager layout** (`ios/stride_health/Sources/stride_health/`), not `ios/Classes/`. Pigeon was writing Swift into a directory that would never have been compiled.
> * `Messages.g.kt` lives under the full package path, `android/src/main/kotlin/com/projectstride/stride_health/`.

---

## Layout

```text
ProjectStride/
├── lib/                              Flutter app
│   ├── main.dart
│   ├── store/                        GameStore — owns GameEngine, fans events out
│   ├── adapters/                     SaveStore, ContentLoader, Audio, Haptics
│   └── ui/                           Six tabs + combat modal
│
├── packages/
│   ├── stride_core/                  PURE DART — no Flutter, no plugins, no dart:io
│   │   ├── pubspec.yaml              dependencies: (none beyond meta/collection)
│   │   ├── lib/
│   │   │   ├── stride_core.dart      Public API
│   │   │   └── src/
│   │   │       ├── state/            GameState and members — all immutable
│   │   │       ├── events/           GameEvent catalogue
│   │   │       ├── engine/           GameEngine, reducers
│   │   │       ├── steps/            Ledger, reconciliation
│   │   │       ├── content/          Schemas, ContentPack, validation
│   │   │       └── ports/            StepProvider, SaveStore, ContentLoader,
│   │   │                             AudioDirecting, HapticPlaying
│   │   └── test/                     dart test — runs on Windows, no emulator
│   │
│   └── stride_health/                Repository-owned. Not a third-party plugin.
│       ├── pubspec.yaml
│       ├── pigeons/health_api.dart   Interface definition — the source of truth
│       ├── lib/
│       │   ├── stride_health.dart
│       │   └── src/
│       │       ├── messages.g.dart           Pigeon-generated Dart
│       │       ├── platform_step_provider.dart
│       │       └── mock_step_provider.dart   Deterministic, for tests
│       ├── android/src/main/kotlin/com/projectstride/stride_health/
│       │   ├── StrideHealthPlugin.kt
│       │   ├── HealthConnectAdapter.kt       Changes API
│       │   └── Messages.g.kt                 Pigeon-generated
│       ├── ios/stride_health/Sources/stride_health/   (SPM layout)
│       │   ├── StrideHealthPlugin.swift
│       │   ├── HealthKitAdapter.swift        HKAnchoredObjectQuery
│       │   └── Messages.g.swift              Pigeon-generated
│       ├── example/                  Minimal host app for platform tests
│       │   ├── lib/main.dart                 Exercises the plugin directly
│       │   ├── integration_test/             On-device channel checks
│       │   ├── android/                      Hosts Kotlin tests
│       │   └── ios/                          Compiles the Swift adapter in CI
│       └── test/                     Dart tests for the mock provider
│
├── assets/content/v1/                Nine JSON files, versioned schemas
├── android/                          Flutter Android runner
├── ios/                              Flutter iOS runner
├── test/                             App-level widget and golden tests
├── integration_test/                 On-device loop tests
├── Scripts/
│   ├── check-core-purity.sh
│   └── verify.sh
└── .github/workflows/ci.yml
```

---

## Why the health adapter is its own package

Three reasons, in order of weight:

1. **The boundary is enforced by the package manifest.** `stride_health` can depend on Flutter and platform code; `stride_core` cannot depend on either. Putting health inside the app would make the separation a convention instead of a constraint.
2. **It is independently testable.** Kotlin adapter tests run on Windows; Swift adapter tests run in the macOS CI job. Neither needs the game.
3. **The prohibition is visible.** A third-party health package appearing anywhere in the dependency tree is easy to spot when the first-party one is a named package.

`packages/` rather than a separate repository: a solo project does not need cross-repo version negotiation, and a path dependency keeps refactors atomic.

---

## The Pigeon boundary

`packages/stride_health/pigeons/health_api.dart` is the single source of truth. One definition generates the Dart, Kotlin, and Swift sides.

```dart
// Illustrative shape — final types settled in F-01.
class StepFetchResult {
  int newSteps;
  int deletedSteps;
  Uint8List? anchor;      // Opaque. HKQueryAnchor on iOS, changes token on Android.
  bool anchorInvalidated; // Health Connect can expire a token; forces a resync path.
}

@HostApi()
abstract class HealthHostApi {
  StepAuthorizationResult requestAuthorization();
  bool isAvailable();
  StepFetchResult fetchNewSteps(Uint8List? anchor);
}
```

Three methods. That narrowness is what makes cross-platform fidelity achievable, and it is a property of steps-only integration.

**Why Pigeon rather than a raw `MethodChannel`:** a contract change that is not reflected on all three sides fails to *compile*. With untyped maps it fails at runtime, as a null, in the system that governs whether the player's walk counted. That is the wrong place to economize.

Regenerate after any change to the definition:

```bash
dart run pigeon --input packages/stride_health/pigeons/health_api.dart
```

Generated files are committed, and CI verifies they are current — a stale `messages.g.dart` is otherwise invisible until it breaks. **Pin the Pigeon version** in `pubspec.yaml`: without a pin, a tool upgrade rewrites header comments and fails the freshness check for reasons unrelated to a stale contract.

### The example app

`packages/stride_health/example/` is a minimal Flutter app that exercises the plugin directly. It exists to host platform tests: Kotlin instrumentation tests on Android, and Swift XCTest on iOS — which is what the CI macOS job runs.

It is not a demo and not a second app. It is the only practical way to test a Flutter plugin's native halves in isolation from the game.

### The opaque anchor

The core stores and returns `anchor` without inspecting it. On iOS it wraps an archived `HKQueryAnchor`; on Android, a Health Connect changes token.

`anchorInvalidated` exists because Health Connect tokens can expire, with no iOS equivalent. When it is set, the adapter reports that incremental sync was lost — and the reconciliation engine must handle that **without double-counting and without clawing back**, which is exactly what the ledger's monotonic counters and `discrepancyDebt` already provide.

*Worth stating plainly: this is a real platform difference, not a wrinkle. It is handled by design rather than by a special case, which is the test of whether the ledger model was right.*

---

## The purity rule

`stride_core/lib/**` must not import:

`package:flutter/*` · `dart:ui` · `dart:io` · `package:flutter_test/*` · any plugin package

`dart:io` is included deliberately — the core touches neither the file system nor the clock. Persistence goes through `SaveStore`; time enters only as data.

Enforced twice, reading one shared list: `test/core_purity_test.dart` and `Scripts/check-core-purity.sh`. The script runs on Windows via Git Bash and is suitable as a pre-commit hook.

`stride_core/pubspec.yaml` declares no `flutter` dependency, which makes the rule structural as well as tested.

---

## The health-plugin prohibition, mechanically

CI fails if any `pubspec.yaml` declares a known health aggregation package. The check names the specific offenders and is deliberately blunt — this is risk X-01, and the moment the platform channel becomes tedious a plugin will look like a shortcut that saves an afternoon.

Utility packages remain allowed after normal dependency review, provided they do not own health-data correctness.
