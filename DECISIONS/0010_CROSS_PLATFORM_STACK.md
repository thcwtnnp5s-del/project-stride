# Decision: Cross-Platform Stack — Flutter with First-Party Health Adapters

**Status:** Approved
**Date:** 2026-08-01
**Owner:** Project owner
**Supersedes:** `DECISIONS/0002_TECHNOLOGY_STACK.md`
**Basis:** `ARCHITECTURE_REVIEW_CROSS_PLATFORM.md`

## Context

`DECISIONS/0002` selected native Swift + SwiftUI on two premises that changed: iOS was the only platform, and macOS was available for development. The primary development machine is a Dell running Windows 11, and some intended players use Android.

Under the superseded decision, roughly 0% of the project was verifiable on the owner's machine — demonstrated concretely by F-01, where four of six acceptance criteria could not be executed.

## Decision

### 1. Adopt Flutter

Flutter carries the shared mobile application: UI, navigation, state orchestration, game presentation, and platform-neutral game logic.

A **pure Dart core package** holds deterministic game rules and simulation. It imports no Flutter, no plugin, and no platform code.

Targets:

- **Android first**, for interactive development on Windows
- **iOS maintained in parallel** through compile-and-test CI
- **Mobile only** — no desktop or web target, in any build configuration

### 2. First-party health adapters

Health integration is a **repository-owned Flutter package**, not a third-party dependency.

```text
packages/
  stride_core/          Pure Dart. Rules, simulation, ports. No Flutter.
  stride_health/        Repository-owned plugin.
    lib/                Dart StepProvider + mock adapter
    android/            Kotlin — Health Connect
    ios/                Swift — HealthKit
```

The Dart `StepProvider` interface is deliberately small. Implementations:

- **HealthKit** in Swift
- **Health Connect** in Kotlin
- **Mock/test adapter** in Dart, for deterministic testing

The platform boundary uses **Pigeon-generated typed channels**, or an equivalent strongly typed boundary. Hand-rolled `MethodChannel` string maps are not acceptable for the system that governs step correctness.

#### The prohibition

No third-party health aggregation plugin may be the source of truth for:

- change tokens or anchors
- reconciliation
- deletion handling
- double-count prevention
- ledger semantics

This is the condition the entire Flutter fidelity case rests on. A general health plugin would place the project's highest-severity system — never double-count, never lose legitimate steps — behind a third party's interpretation of anchored queries and change tokens.

Third-party utility packages remain permitted after normal dependency review, provided they do not own health-data correctness.

### 3. Android first, iOS continuously verified

The complete vertical slice may be developed and tested interactively on Android from Windows.

**GitHub Actions is added early**, with:

- Linux jobs for Dart and Android validation
- A macOS job for iOS compilation and unit tests
- Native adapter compilation on both platforms
- Formatting, analysis, and test checks

> **The iOS branch must not be allowed to remain uncompiled until the end.**

Regular Mac access remains required later for: physical iPhone and real HealthKit testing, signing, TestFlight, interactive iOS UX testing, and audio and haptic validation.

## Reasoning

- **~90% of the project becomes verifiable on the development machine**, against ~0% under the superseded decision. 35 of 40 tasks require no Mac.
- Under Flutter the Mac performs a *build*, not *development*, which is what makes CI a genuine substitute for most iOS work. Under Kotlin Multiplatform or separate native apps, the SwiftUI half could not be written on Windows at all.
- Health Connect's Changes API is the close analogue of `HKAnchoredObjectQuery`. The ledger model — monotonic counters, no day boundaries, no clawback — maps to both platforms essentially unchanged.
- First-party channels give Flutter the same platform fidelity as native, for roughly 300 lines of native code, precisely because the interface is two methods and integration is steps-only.

## Consequences

- `DECISIONS/0002` is superseded. The Swift scaffold is preserved in git history at commit `859d0ac` and removed from the working tree during migration.
- Every other decision survives: `0001`, `0003`, `0004`, `0005`, `0006`, `0007`, `0008` are platform-neutral. `0009` is amended, not replaced.
- The architecture's shape survives — pure core, ports, ledger, semantic events, JSON content. `ARCHITECTURE_IMPLEMENTATION_PLAN.md` is revised to v2.0 rather than rethought.
- **Audio control is less direct than AVAudioEngine.** This is the one real capability cost, and task A-04b exists to surface it at Phase 3 rather than Phase 5.
- Dart lacks Swift's value semantics, so `GameState` immutability becomes a discipline enforced by test rather than a language guarantee.
- A framework dependency on Flutter itself is accepted, mitigated by the pure-Dart core having no Flutter dependency.

## Follow-up

- `ARCHITECTURE_IMPLEMENTATION_PLAN.md` revised to v2.0
- `TECHNICAL/PROJECT_STRUCTURE.md` defines the package layout and Pigeon boundary
- `.github/workflows/ci.yml` defines the build matrix
- `MIGRATION_EXECUTION_PLAN.md` sequences the change with acceptance criteria
