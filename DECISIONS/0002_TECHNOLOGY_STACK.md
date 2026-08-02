# Decision: Technology Stack — Native Swift + SwiftUI

**Status:** ⚠️ **REOPENED 2026-08-01 — under review, do not act on this document**
**Date:** 2026-08-01
**Owner:** Project owner
**Satisfies:** The technical review required by `GAME_BIBLE/TECHNICAL/01_MOBILE_ARCHITECTURE_DIRECTION.md`

> ## Reopened
>
> This decision was made on two premises that have since changed:
>
> 1. **iOS was the only target platform.** Some intended players use Android, and the private beta should support both if reasonably achievable.
> 2. **macOS was available for development.** The primary development machine is a Dell running Windows 11, where native iOS development is not possible at all.
>
> A formal comparison of Flutter, Kotlin Multiplatform, and separate native applications is in **`ARCHITECTURE_REVIEW_CROSS_PLATFORM.md`**, which recommends **Flutter with first-party HealthKit and Health Connect platform channels**.
>
> **This decision remains nominally in force but must not be acted on.** F-01 is paused. Nothing is replaced until the owner approves the recommendation, at which point this document is superseded by `DECISIONS/0010_CROSS_PLATFORM_STACK.md`.
>
> The analysis below was sound for its premises. It is retained for the record.

## Context

`GAME_BIBLE/TECHNICAL/01_MOBILE_ARCHITECTURE_DIRECTION.md` defined principles but deferred the stack, requiring a documented comparison of native iOS, cross-platform frameworks, and game engines before implementation.

## Decision

**Native iOS — Swift + SwiftUI, iOS 17 minimum.**

| Concern | Choice |
|---|---|
| Application shell | SwiftUI, `@Observable` view models |
| Game rules and simulation | `StrideCore` — a local Swift package, pure logic, deterministic |
| Health | HealthKit directly, behind a `StepProvider` interface |
| Audio | AVAudioEngine behind an `AudioDirector` interface |
| Haptics | Core Haptics, driven by the same semantic events as audio |
| Content | JSON, versioned schemas, decoded into `StrideCore` value types |
| Persistence | Versioned `Codable` snapshot, atomic write, plus an append-only step ledger |
| Tests | Swift Testing for `StrideCore`, XCTest for integration |

### Binding architectural constraint

`StrideCore` **must not** depend on SwiftUI, UIKit, HealthKit, AVFoundation, Core Haptics, or any other platform framework. All platform integrations sit behind interfaces defined in `StrideCore` and implemented in the app target.

This constraint is enforced by the package manifest — `StrideCore` declares no platform framework dependencies — and any pull toward violating it is a design smell to be resolved by moving the boundary, not by importing the framework.

## Alternatives considered

**React Native / Expo.** Fast UI iteration, one language. Rejected: HealthKit anchored queries, deletion handling, and background delivery depend on community bridges with uneven coverage; audio and haptics of the required fidelity need native modules regardless, leaving two languages to maintain instead of one.

**Flutter.** Strongest runner-up. Excellent UI control and a genuine path to Health Connect later. Rejected: same HealthKit fidelity concern, plus a weaker iOS audio story than AVAudioEngine. Revisit only if Android is promoted from "may be considered" to "planned."

**Kotlin Multiplatform + SwiftUI shell.** Architecturally the most honest two-platform answer. Rejected for Milestone 01 on cost: a second toolchain, a second language, and interop friction added to a solo project before the core loop is validated.

**Unity / Godot.** Rejected: heavy runtime, larger binaries, worse battery characteristics, and awkward HealthKit integration in exchange for rendering capability this game does not use.

## Reasoning

- HealthKit is the project's spine and its hardest correctness requirement. It belongs directly on the native API, not two abstraction layers away.
- "Audio is gameplay" is a locked pillar. AVAudioEngine and Core Haptics give full control over mixing, ducking, ambience crossfades, and haptic authoring.
- Stride is a data-driven journal app with an encounter view, not a renderer. There is no scene graph, no physics, no real-time sprite loop. An engine would be pure overhead.
- The pure-core constraint makes the simulation testable in milliseconds with no simulator, no HealthKit, and no UI.

## Consequences

- **Android is deferred, not eliminated.** A future port rewrites the UI, persistence, audio, and health layers; design documents and JSON content carry over directly. The pure-core constraint means such a port re-implements a specified, fully-tested simulation rather than reverse-engineering one out of view code.
- iOS 17 minimum excludes older devices. Acceptable for an owner-and-friends audience.
- No third-party dependencies in Milestone 01. If the save outgrows a snapshot, GRDB/SQLite is the documented escalation path.

## Follow-up

- Confirm Xcode version, target device set, and TestFlight-versus-App-Store distribution.
- Full elaboration in `ARCHITECTURE_IMPLEMENTATION_PLAN.md`.
