# Migration Impact — Swift Scaffold to Flutter

**Date:** 2026-08-01
**Status:** Proposal, pending owner approval of `ARCHITECTURE_REVIEW_CROSS_PLATFORM.md`
**Scope:** What the stack change costs, given what has already been built

---

## 1. Headline

> **The migration cost is approximately zero, and the design cost is zero.**

F-01 produced 11 files of skeleton — a package manifest, a module marker, four test files, an app shell, an Info.plist, a project spec, two scripts, and a setup document. There is no game state, no content, no HealthKit, no save format, and no UI beyond a placeholder that prints a version string.

Nothing built so far encodes a gameplay rule. Nothing is lost.

This is the direct payoff of two earlier choices: gating F-02 on a build that never happened, and writing `ARCHITECTURE_IMPLEMENTATION_PLAN.md` around ports rather than around Swift.

---

## 2. Asset-by-asset disposition

| Artifact | Fate | Notes |
|---|---|---|
| `StrideCore/Package.swift` | **Discard** | Replaced by `stride_core/pubspec.yaml` |
| `StrideCore/Sources/StrideCore/StrideCore.swift` | **Port** | ~30 lines; becomes `stride_core.dart` with the same module marker and forbidden-import list |
| `StrideCoreTests/ModuleTests.swift` | **Port** | Direct translation to `dart test` |
| `StrideCoreTests/CorePurityTests.swift` | **Port — concept intact** | The rule changes from "no platform framework" to "no `package:flutter` import." The scanning logic, the false-positive handling, and the self-check that the detector still works all translate directly. |
| `App/Stride/StrideApp.swift` | **Discard** | Replaced by `lib/main.dart` |
| `App/Stride/RootPlaceholderView.swift` | **Discard** | Replaced by a Dart placeholder widget |
| `App/Stride/Info.plist` | **Partially reusable** | Flutter generates its own iOS runner Info.plist; the portrait-only constraint carries over as a Flutter setting, and Android gains an equivalent manifest constraint |
| `App/StrideTests/AppShellTests.swift` | **Port — concept intact** | The build-setting assertions become Flutter/Gradle equivalents. The QA-F01-2 lesson (assert the build setting, not the runtime OS) applies identically. |
| `project.yml` | **Discard** | Flutter owns project generation |
| `Scripts/check-core-purity.sh` | **Port** | Same script, different forbidden list. Still runs on Windows via Git Bash. |
| `Scripts/verify.sh` | **Port and improve** | `dart test` and `flutter test` need no Mac, so the graceful-degradation logic simplifies — most of the pipeline now runs on the Dell. The `--strict` flag and the missing-toolchain guard both survive. |
| `TECHNICAL/PROJECT_SETUP.md` | **Rewrite** | Requirements change from "macOS + Xcode" to "Windows + Flutter SDK + Android SDK, with macOS or cloud CI for iOS" |

**Estimated rework: under one working session.** The scaffold is a day's work at most, and most of it is translation rather than redesign.

---

## 3. What carries over untouched

### Decisions

| # | Decision | Status |
|---|---|---|
| 0001 | Step-clocked progression | **Unaffected** |
| 0003 | Turn-based, retreat-not-death combat | **Unaffected** |
| 0004 | Milestone 01 scope freeze | **Unaffected** |
| 0005 | Audio sourcing and provenance | **Unaffected** |
| 0006 | One activity at a time | **Unaffected** |
| 0007 | Progression pacing and step fixtures | **Unaffected** |
| 0008 | Stepless-week behavior | **Unaffected** |
| 0002 | Native Swift + SwiftUI | **Superseded** |
| 0009 | Platform and distribution | **Amended** — Android added; portrait-only, iOS 17+, and no-store-launch survive |

Seven of nine decisions are platform-neutral. That ratio is the clearest evidence the design work was done at the right altitude.

### Architecture

The entire *shape* of `ARCHITECTURE_IMPLEMENTATION_PLAN.md` survives:

- Layered, dependencies pointing inward
- A pure simulation core with no platform dependency
- Ports for every platform capability — `StepProvider`, `SaveStore`, `ContentLoader`, `AudioDirecting`, `HapticPlaying`
- Value-type state, events returned from every mutation, seeded randomness, no clock in the core
- The step ledger: monotonic counters, no day boundaries, no clawback, ledger written before snapshot
- JSON content with versioned schemas and build-time validation
- Semantic audio events resolved through asset IDs
- Named required test suites rather than a coverage percentage

What changes is the *language and runtime*, not the design. `GameEngine` becomes a Dart class; `GameState` becomes an immutable Dart value type; `Codable` becomes JSON serialization.

### The reconciliation model

Unchanged, and now serving two platforms. `HKAnchoredObjectQuery` + anchor on iOS, Changes API + token on Android — the same incremental-sync shape the ledger was designed around. The twelve test scenarios apply verbatim and now run against both adapters.

---

## 4. What genuinely changes

| Area | Change |
|---|---|
| **Language** | Swift → Dart. Value semantics need explicit immutability discipline rather than being free. |
| **Persistence** | `Codable` → explicit JSON serialization. Slightly more boilerplate; the atomic-write and ledger design is identical. |
| **UI** | SwiftUI → Flutter widgets. No design work is lost, since none was done. |
| **Audio** | AVAudioEngine → Flutter audio packages behind `AudioDirecting`. **The one real capability cost.** |
| **Health** | One HealthKit adapter → two platform channels. Roughly 300 lines of native code total. |
| **Testing** | Swift Testing/XCTest → `dart test` + `flutter test`. **Runs on Windows.** |
| **Build** | Xcode-only → Flutter on Windows for Android; macOS or cloud CI for iOS. |

---

## 5. What the migration gains

Beyond Android support, three things the current path could not offer:

1. **~90% of the project becomes verifiable on the owner's machine**, up from ~0%. F-01 demonstrated the cost of the alternative concretely: four of six acceptance criteria could not be executed, and the completion report had to say so.
2. **F-02 through F-06 stop being Mac-blocked.** The content schema, the state model, the reconciliation test harness, the save format, and the skill framework can all be built and tested starting immediately.
3. **The reconciliation suite runs where the developer is.** F-04 writes twelve adversarial scenarios against the project's highest-severity risk. Under the Swift path they could not run on the Dell at all.

---

## 6. Recommendation

**Migrate.** The cost is a session of translation; the benefit is Android support and the ability to verify the work.

Delete the Swift scaffold rather than keeping it alongside — a dead parallel tree invites confusion about which is authoritative. It remains in git history at commit `859d0ac` if it is ever wanted.

The one thing worth carrying forward deliberately is the **discipline** of F-01, not its code: a core that cannot import the UI framework, enforced in two places reading one shared list, plus a verification script honest about what it did not run.
