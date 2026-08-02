# Project Setup

**Task:** F-01
**Authority:** `DECISIONS/0002_TECHNOLOGY_STACK.md`, `DECISIONS/0009_PLATFORM_AND_DISTRIBUTION.md`

---

## Requirements

| | |
|---|---|
| OS | **macOS** — iOS development is not possible on Windows or Linux |
| Xcode | Current stable |
| Swift | 6, strict concurrency |
| Deployment target | iOS 17 |
| Devices | iPhone only, portrait only |
| XcodeGen | Optional — `brew install xcodegen` |

---

## Layout

```text
ProjectStride/
├── StrideCore/                  Swift package — the simulation
│   ├── Package.swift            No dependencies. Ever.
│   ├── Sources/StrideCore/
│   └── Tests/StrideCoreTests/   Runs with `swift test`, no simulator
├── App/
│   ├── Stride/                  App target — SwiftUI shell, Info.plist
│   └── StrideTests/             App-target tests (XCTest)
├── Scripts/
│   ├── check-core-purity.sh     Import boundary guard
│   └── verify.sh                Full local verification
├── project.yml                  Xcode project spec (XcodeGen)
└── Stride.xcodeproj             Generated — not committed
```

### Why the project is generated

`Stride.xcodeproj` is not committed. A `.pbxproj` is an opaque, machine-ordered file that conflicts on nearly every branch and cannot be reviewed. `project.yml` is forty readable lines that say the same thing.

XcodeGen is a **build-time tool**, not a runtime dependency. The "no dependencies" rule in `DECISIONS/0002` governs what ships inside the app; this ships nothing. If you would rather avoid it entirely, the manual path below produces an identical target layout.

---

## First-time setup

```bash
git clone <repo> && cd ProjectStride
brew install xcodegen
xcodegen generate
open Stride.xcodeproj
```

### Manual alternative, without XcodeGen

Create in Xcode: **iOS App**, name `Stride`, interface SwiftUI, language Swift. Then:

1. Delete the generated `ContentView.swift` and `StrideApp.swift`; add the existing files from `App/Stride/` instead
2. Set the app target's Info.plist to `App/Stride/Info.plist`, and `GENERATE_INFOPLIST_FILE` to `NO`
3. **File → Add Package Dependencies → Add Local…** → select `StrideCore/`
4. Add `StrideCore` to the app target's frameworks
5. Add a unit test target named `StrideTests` pointed at `App/StrideTests/`
6. Set: deployment target **iOS 17.0**, `TARGETED_DEVICE_FAMILY` **1** (iPhone), Swift language version **6**, strict concurrency **complete**, treat warnings as errors **YES**
7. Confirm the app target's supported orientations are **portrait only**

---

## Verification

```bash
./Scripts/verify.sh
```

Runs, in order: the core purity check, the `StrideCore` test suite, then builds and tests on both simulators in the matrix. It degrades gracefully — on a machine with no Xcode it runs the toolchain-independent checks and says so rather than failing.

Simulator names come from `STRIDE_SMALL_SIM` and `STRIDE_STANDARD_SIM`, defaulting to *iPhone SE (3rd generation)* and *iPhone 16*. Override if your installed simulators differ:

```bash
STRIDE_STANDARD_SIM="iPhone 17" ./Scripts/verify.sh
```

### Core purity alone

```bash
./Scripts/check-core-purity.sh
```

Runs anywhere bash and grep exist, including Windows via Git Bash. Recommended as a pre-commit hook.

---

## The architectural rule

**`StrideCore` must not import any platform framework.**

Forbidden: SwiftUI, UIKit, AppKit, HealthKit, AVFoundation, AVFAudio, CoreHaptics, CoreLocation, CoreMotion, WidgetKit, Combine.

Enforced in two places, deliberately:

- `CorePurityTests` — fails `swift test`
- `Scripts/check-core-purity.sh` — fails pre-commit and CI

Both read the forbidden list from `StrideCore.forbiddenImports`, so the rule and its enforcement cannot drift apart.

This is not aesthetic. It is what keeps the simulation testable in milliseconds without a simulator, keeps balance work independent of the UI, and means a future port re-implements a specified system rather than reverse-engineering one out of view code.

**When you need a platform capability inside the core, you do not import it.** You define a protocol in `StrideCore`, implement it in the app target, and inject it. That is the whole pattern, and `StepProvider`, `SaveStore`, `ContentLoader`, `AudioDirecting`, and `HapticPlaying` are all instances of it (`ARCHITECTURE_IMPLEMENTATION_PLAN.md` §2.3).

---

## What is deliberately absent

F-01 is a skeleton. There is no game state, no content schema, no HealthKit, no save file, no navigation, and no design in the placeholder screen.

Those arrive in F-02 (content schemas), F-03 (state and events), F-04 (reconciliation tests), F-05 (save), and P-01/P-02 (visual identity and navigation). Adding any of it here would put implementation ahead of the reviews that own it.
