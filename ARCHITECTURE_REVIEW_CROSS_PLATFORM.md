# Cross-Platform Architecture Review

**Project:** Project Stride
**Date:** 2026-08-01
**Reviewers:** Technical Director, with QA Director and Critic Agent
**Trigger:** Owner reopened `DECISIONS/0002_TECHNOLOGY_STACK.md`
**Status:** **Recommendation pending owner approval. The existing architecture is not replaced.**

---

## 1. Why this review exists

`DECISIONS/0002` selected native Swift + SwiftUI on the understanding that iOS was the only platform and that a Mac was available. Three facts have since changed:

1. The primary development machine is a **Dell running Windows 11**
2. Some intended players use **Android**
3. The private beta should support **both platforms if reasonably achievable**

Unchanged: mobile-only, solo-first, steps-only health integration, no public store launch.

The native-Swift decision is not merely suboptimal under these facts — under the first one it is close to unworkable. Native iOS development cannot happen on Windows at all.

### The constraint that governs everything

> **Compiling, signing, and distributing an iOS app requires macOS. No cross-platform framework changes this.**

Flutter, Kotlin Multiplatform, React Native, and native Swift are identical on this point. Xcode runs only on macOS, and the iOS toolchain is Xcode. What the options differ on is **how much work requires a Mac and how often** — which, for a Windows-primary solo developer, is the question that actually matters.

The honest framing is not "which option avoids the Mac" but "which option lets the most work happen without one."

---

## 2. The three options

| | Option A — Flutter | Option B — Kotlin Multiplatform | Option C — Separate native apps |
|---|---|---|---|
| Shared UI | Dart/Flutter, both platforms | None — SwiftUI + Compose separately | None |
| Shared logic | Dart package | Kotlin `commonMain` | None |
| iOS shell | Flutter-rendered | SwiftUI | SwiftUI |
| Android shell | Flutter-rendered | Jetpack Compose | Jetpack Compose |
| Health adapters | Platform channels | Native per platform | Native per platform |

---

## 3. Evaluation

### 3.1 Amount of shared UI code

| | Shared UI |
|---|---|
| **A — Flutter** | **~100%.** One widget tree renders on both platforms. |
| **B — KMP** | **0%.** SwiftUI and Compose are written separately, as the owner specified. *(Compose Multiplatform could share iOS UI, but that is a different option from the one under review and carries its own maturity questions on iOS.)* |
| **C — Native ×2** | **0%.** |

Stride is a UI-heavy game. Six tabs, a combat modal, a return summary, inventory, crafting, skills — the presentation layer is most of the visible work. Duplicating it doubles the largest slice of the project.

Worse for a Windows-primary developer: under B and C, **the SwiftUI half cannot be written or previewed on the Dell at all.** Half the UI work becomes Mac-gated.

**A wins decisively.**

### 3.2 Amount of shared game-logic code

| | Shared logic |
|---|---|
| **A — Flutter** | **~95%.** `stride_core` as a pure Dart package. |
| **B — KMP** | **~90%.** `commonMain` in Kotlin. |
| **C — Native ×2** | **0%.** Every rule implemented twice, in two languages, kept in sync by hand. |

A and B are close. C is disqualifying: the step-reconciliation ledger, the XP curves, the crafting graph, and the combat resolver would exist twice, and *two implementations of a determinism guarantee are two chances to break it differently.*

The architecture already isolates the simulation behind ports (`ARCHITECTURE_IMPLEMENTATION_PLAN.md` §2), so this translates cleanly to either A or B.

**A and B tie. C fails.**

### 3.3 Windows development support

This is the criterion that reorders the whole comparison.

| | On Windows |
|---|---|
| **A — Flutter** | Full Flutter SDK, Dart toolchain, Android Studio, Android SDK, emulator, `dart test`, `flutter test`, hot reload against Android. **The entire simulation, the entire UI, and the entire Android app are developable and testable on the Dell.** |
| **B — KMP** | Kotlin, Gradle, `commonMain` tests, Android Studio, Android emulator all work. **The iOS side does not:** Kotlin/Native cannot compile iOS targets on Windows, and the SwiftUI shell cannot be written or built there. Roughly half the project is Mac-gated. |
| **C — Native ×2** | Android half fully supported; **iOS half entirely impossible.** |

Under A, the Mac is needed only to *build and ship* the iOS binary. Under B and C it is needed to *write* a substantial part of the app.

For a solo developer whose primary machine is a Dell, that is the difference between "occasional cloud build" and "cannot do the work."

**A wins decisively.**

### 3.4 iOS build requirements

Identical floor for all three: **macOS with Xcode**, an Apple Developer Program membership (~$99/yr) for TestFlight, and signing certificates.

The difference is *frequency and depth*:

| | How often a Mac is needed |
|---|---|
| **A — Flutter** | At release-candidate time: build, sign, upload. Plus occasional debugging of the two platform-channel adapters. Realistically **a handful of sessions per milestone**, and cloud CI can cover most of them. |
| **B — KMP** | Continuously, for all SwiftUI work. |
| **C — Native ×2** | Continuously, for the entire iOS application. |

**Cloud CI is a real answer under A**, and a poor one under B and C. Codemagic, GitHub Actions macOS runners, Bitrise, and Xcode Cloud all build and upload Flutter iOS apps from a Git push. Free tiers exist and are adequate for a solo hobby project. That works because under Flutter the Mac performs a *build*, not *development* — you do not need interactive Xcode sessions for work you authored in Dart on Windows.

Under B and C you would be trying to write SwiftUI through a CI runner, which is not a workflow.

**A wins.**

### 3.5 Android build requirements

| | |
|---|---|
| **A — Flutter** | Android SDK on Windows. `flutter build apk` / `appbundle`. No obstacles. |
| **B — KMP** | Gradle on Windows. No obstacles. |
| **C — Native ×2** | No obstacles. |

**Tie.** Android is the platform that works everywhere, which is a good reason to build it first.

### 3.6 HealthKit fidelity

The original argument for native Swift was HealthKit fidelity. It deserves scrutiny, because it is the strongest case against Flutter.

Stride needs, from `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §5–6:

- Read authorization for `stepCount` only
- `HKAnchoredObjectQuery` with a persisted anchor
- Deleted-object handling
- The `wasUserEntered` metadata filter
- Opportunistic background delivery
- Correct behavior when the device is locked

| | Fidelity |
|---|---|
| **A — Flutter, via a first-party platform channel** | **Full.** The Swift side of a platform channel *is* HealthKit code. Every API above is available verbatim. What crosses the channel is a plain result — new step total, deletions, opaque anchor — not a wrapped API. |
| **A — Flutter, via a third-party plugin** | **Partial and unpredictable.** See §3.13. |
| **B / C — Native** | **Full**, by definition. |

**The decisive insight: writing the HealthKit adapter as a first-party platform channel gives Flutter the same fidelity as native.** The adapter is roughly 150 lines of Swift implementing a protocol the project already defines. The `StepProvider` port makes this a swap of one implementation, exactly as designed.

The channel is thin because the *interface* is thin: `requestAuthorization()` and `fetchNewSteps(since:)`. That narrowness is what makes cross-platform viable here, and it is a property of steps-only integration.

**A ties B and C, given first-party adapters. This is conditional on §3.13 being honoured.**

### 3.7 Health Connect fidelity

Android's Health Connect is the equivalent surface, and the mapping is unusually clean:

| Concern | iOS | Android |
|---|---|---|
| Incremental sync | `HKAnchoredObjectQuery` + anchor | **Changes API** — `getChangesToken()` / `getChanges()` |
| Deletions | `deletedObjects` | Deletion records in the changes feed |
| Provenance | `wasUserEntered` metadata | `Metadata.recordingMethod` |
| Locked device | Reads fail | No direct equivalent; foreground reads always work |

The ledger model in §6 of the architecture plan — monotonic counters, no day boundaries, no clawback — maps to Health Connect's Changes API essentially without modification. That is fortunate rather than clever: the model was designed around anchored incremental sync, and Health Connect offers the same shape.

**Platform notes to verify at implementation:**

- Health Connect is built into Android 14+; earlier versions (roughly Android 9+) require the Health Connect app to be installed. The app must degrade gracefully when it is absent — same graceful-degradation path already required for a denied HealthKit permission.
- Reading history beyond ~30 days of data written by *other* apps requires the additional history permission. Stride's ledger model tolerates this well: it never needs deep history, only *new* data since the last token.
- Distributing through Google Play requires a **Health Connect data-types declaration** in Play Console. Direct APK distribution does not.

Fidelity is equal across all three options — the Kotlin adapter is the same code whether it sits behind a Flutter channel, a KMP `expect`/`actual`, or a native app.

**Tie.**

### 3.8 Background step reconciliation

| | |
|---|---|
| **iOS** | `enableBackgroundDelivery` is opportunistic and **fails while the device is locked**, because health data is encrypted at rest. |
| **Android** | No true push equivalent. `WorkManager` periodic sync is the idiom, subject to Doze and manufacturer battery restrictions. |

The architecture already made the correct call: **foreground cold-launch backfill is the source of truth; background delivery is an optimization that may silently never fire** (§5.3).

That decision now pays off twice. It was made for an iOS constraint and turns out to be exactly what Android's less predictable background model also demands. Neither platform can be trusted to wake the app reliably; both can be trusted to reconcile fully on launch.

Background work happens in the native adapter under every option. **Tie** — and notably, Flutter does not disadvantage this at all, because the reconciliation *logic* is in the shared core and only the *trigger* is native.

### 3.9 Audio and haptic capability

**This is Flutter's real cost, and it should not be minimized.**

| | Audio | Haptics |
|---|---|---|
| **A — Flutter** | Package-based (`just_audio`, `audioplayers`, `flutter_soloud`, with `audio_session` for ducking and the silent switch). Multi-bus mixing, gapless ambience crossfade, and per-cue control are achievable but **less direct than AVAudioEngine**. | Flutter's built-in haptics are coarse — light/medium/heavy impact. Rich Core Haptics patterns need a platform channel. |
| **B / C — Native** | AVAudioEngine and its Android counterpart, full control. | Core Haptics and `VibrationEffect` directly. |

`GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md` makes audio a locked first-class pillar: region beds, weather variation, per-material cues, crossfades, and haptic pairing.

Honest assessment: **Flutter can deliver all of that, at somewhat more effort and with less low-level control.** Stride is not a spatial-audio game — it needs a looping bed, crossfades on arrival, short cue playback with variant rotation, four independent volume buses, ducking, and silent-switch respect. That is well within what Flutter audio packages do.

Custom haptic authoring needs a platform channel under *every* option, since Core Haptics and Android's vibration API share nothing. Flutter loses nothing there.

The `AudioDirecting` and `HapticPlaying` ports (§2.3) already isolate this, so if a package proves inadequate it is replaced behind the port rather than surgically extracted from the game.

**B and C win, modestly. This is the clearest thing Flutter costs.**

### 3.10 Testing complexity

| | What runs on Windows |
|---|---|
| **A — Flutter** | `dart test` on the pure simulation package — **milliseconds, no emulator, no Mac**. Widget tests for the entire UI. Integration tests on an Android emulator. Only iOS integration testing needs a Mac. |
| **B — KMP** | `commonTest` for shared logic. Android instrumentation tests. **iOS tests need a Mac.** |
| **C — Native ×2** | Android tests on Windows; **all Swift tests need a Mac** — including, critically, the twelve step-reconciliation scenarios. |

Task F-04 writes the reconciliation suite *before* the feature, as the project's primary defence against its highest-severity risk. Under C, that suite could not run on the owner's machine at all. Under A, it runs in under a second on the Dell.

The core-purity rule translates directly: a Dart package that imports no Flutter, and a test enforcing it, exactly as `CorePurityTests` does today.

**A wins decisively.**

### 3.11 Private beta distribution

Both platforms, matching the owner's stated model:

**Android**
- **Google Play closed testing** — versioned, auto-updating, tester-managed. Requires a Play Console account (one-time ~$25) and, because Health Connect is used, the **data-types declaration** form.
- **Direct APK / internal distribution** — simplest possible: send a file. No review, no declaration form, no account. Manual updates.

*(Note: Google's requirement that newer personal developer accounts run a 12-tester closed test for 14 days applies to unlocking **production** access. Stride is not launching publicly, so it does not apply.)*

**iOS — TestFlight**
- Apple Developer Program (~$99/yr)
- Internal testers (up to 100, tied to App Store Connect users) — no Beta App Review
- External testers — requires Beta App Review, and a **privacy policy**, because the app requests health data
- Builds expire after 90 days

None of this differs between the three options. Flutter apps go through TestFlight and Play identically to native ones.

**Tie.** Worth noting: the friends-and-owner audience likely fits inside TestFlight's internal-tester tier, which avoids Beta App Review entirely.

### 3.12 Long-term maintainability for a solo developer using Claude Code

| | |
|---|---|
| **A — Flutter** | One language, one codebase, one test suite, one mental model. Claude Code operates on the whole project from the Dell. Dart is well-represented in training data; Flutter's conventions are consistent. |
| **B — KMP** | Two languages, two UI frameworks, an interop layer, and — decisively — **Claude Code cannot build or verify the iOS half from Windows.** Assistance on SwiftUI becomes advice rather than verified work. |
| **C — Native ×2** | Two of everything, plus the standing risk that the platforms drift apart in behavior. Every feature is implemented twice, reviewed twice, and can regress independently. |

For an AI-assisted solo studio, the ability to *verify* matters more than the ability to *write*. Code that cannot be compiled or tested on the development machine is code nobody has checked — a lesson F-01 already delivered concretely, where four of six acceptance criteria could not be executed.

**A wins decisively.**

### 3.13 Risk of plugin dependency

The strongest objection to Flutter, and it has a direct answer.

**The risk is real.** A general-purpose health plugin (the `health` package and similar) wraps both platforms behind one Dart API. That is convenient and dangerous: it means the project's highest-severity system — never double-count, never lose legitimate steps — depends on a third party's interpretation of anchored queries, deletion handling, and change tokens. Plugin abandonment, a lagging API version, or a subtle semantic difference between platforms would land squarely on the one system that must be exactly right.

**The mitigation is to not take the dependency.**

> Write the step adapters as **first-party platform channels**, owned by this project. No third-party health plugin.

- iOS: ~150 lines of Swift calling HealthKit directly
- Android: ~150 lines of Kotlin calling Health Connect directly
- Dart: a `StepProvider` implementation that marshals across the channel

This is viable precisely because the interface is narrow — two methods — and because integration is steps-only. It is a materially different proposition from wrapping a general health API.

The result: **full platform fidelity, zero plugin risk on the critical path, and roughly 300 lines of native code to maintain.** That is cheaper than the SwiftUI half of option B by an order of magnitude.

Remaining plugin exposure is confined to non-critical surfaces — audio, path resolution, preferences — all behind existing ports, all replaceable, none capable of corrupting player progress.

**A is acceptable, conditional on first-party adapters. With a general health plugin, A would be a serious risk and I would not recommend it.**

### 3.14 Ease of future expansion beyond steps

Roadmap Milestone 04 contemplates optional social features; heart rate, workouts, or distance could plausibly follow.

Every option expands the same way: add a method to the port, implement it in two native adapters. Under A that is two small channel additions. Under B, two `actual` implementations. Under C, two applications.

One caveat worth stating: the *narrowness* of the platform channel is what makes A safe. Each new health metric widens it. A future that pulls in many metrics erodes Flutter's advantage somewhat — though never to the point of B's duplicated UI.

**A and B tie; C is worst.**

---

## 4. Scorecard

| Criterion | A — Flutter | B — KMP | C — Native ×2 |
|---|:---:|:---:|:---:|
| Shared UI code | ●●● | ○ | ○ |
| Shared game logic | ●●● | ●●● | ○ |
| **Windows development** | ●●● | ●○ | ○ |
| iOS build requirements | ●●○ | ●○ | ●○ |
| Android build requirements | ●●● | ●●● | ●●● |
| HealthKit fidelity | ●●● * | ●●● | ●●● |
| Health Connect fidelity | ●●● | ●●● | ●●● |
| Background reconciliation | ●●● | ●●● | ●●● |
| **Audio and haptics** | ●●○ | ●●● | ●●● |
| Testing complexity | ●●● | ●●○ | ●○ |
| Beta distribution | ●●● | ●●● | ●●● |
| Solo + Claude Code maintainability | ●●● | ●○ | ○ |
| Plugin dependency risk | ●●○ * | ●●● | ●●● |
| Expansion beyond steps | ●●● | ●●● | ●●○ |

\* Conditional on first-party platform channels rather than a third-party health plugin.

---

## 5. Recommendation

> ### Adopt Option A — Flutter, with first-party platform channels for HealthKit and Health Connect.

This matches the owner's preferred direction, and the analysis supports it rather than merely accommodating it.

### Proposed stack

| Concern | Choice |
|---|---|
| Framework | Flutter, current stable |
| Language | Dart |
| Simulation | `stride_core` — pure Dart package, **no Flutter import** |
| State | A single store over `stride_core`, exposed to the widget tree |
| Health | `StepProvider` port; **first-party** platform channels — Swift/HealthKit, Kotlin/Health Connect |
| Persistence | Versioned JSON snapshot with atomic write + append-only step ledger |
| Content | JSON, versioned schemas, identical to the approved design |
| Audio | Behind `AudioDirecting`; package-based, replaceable |
| Haptics | Behind `HapticPlaying`; platform channel for custom patterns |
| Tests | `dart test` for the core, `flutter test` for widgets, integration on emulator/device |
| Dependencies | **No third-party health plugin.** Others require a decision record. |

### What survives unchanged

Every design decision except the stack. `DECISIONS/0001` (step-clocked), `0003` (combat), `0004` (scope freeze), `0006` (single activity), `0007` (pacing), and `0008` (stepless week) are platform-neutral and unaffected.

The architecture's *shape* also survives: layered with dependencies pointing inward, a pure simulation core, ports for every platform capability, semantic events driving audio and haptics, a ledger-based reconciliation model. `ARCHITECTURE_IMPLEMENTATION_PLAN.md` was written to be portable, and it turns out to be.

### What this costs, stated plainly

1. **Audio control is less direct than AVAudioEngine.** Achievable, but more effort for the same result, and the pillar says audio is gameplay.
2. **~300 lines of native code to maintain** across two platform channels — much less than any alternative, but not zero.
3. **iOS still requires macOS**, at build time.
4. **A framework dependency on Flutter itself**, which is a bet on Google's continued investment.

### Recommended sequencing

**Build Android first, add iOS when Mac access is arranged.**

Android is fully developable and testable on the Dell today. Sequencing that way unblocks all of Phases 1–4 immediately, and the iOS adapter becomes a well-scoped addition rather than a prerequisite. It also means the first playable build reaches Android-using friends soonest.

This is a sequencing suggestion, not a scope reduction — both platforms remain the Milestone 01 target.

---

## 6. What still requires macOS

**Hard requirements. No workaround exists.**

| # | Activity |
|---|---|
| 1 | Compiling the iOS app — Flutter's iOS build invokes Xcode |
| 2 | Code signing, provisioning profiles, archiving |
| 3 | Uploading builds to App Store Connect / TestFlight |
| 4 | Running the iOS simulator or deploying to a physical iPhone |
| 5 | Developing and debugging the Swift/HealthKit platform channel |
| 6 | iOS-specific integration and acceptance testing |
| 7 | CocoaPods dependency resolution for the iOS runner |
| 8 | Validating iOS haptics, audio session behavior, and battery |

**Ways to satisfy this, cheapest first:**

1. **Cloud CI** — Codemagic, GitHub Actions macOS runners, Bitrise, or Xcode Cloud build and upload Flutter iOS apps from a Git push. Free tiers are adequate here. Covers items 1–3 and much of 6. **Recommended starting point.**
2. **Rented Mac** — MacinCloud, MacStadium, and similar, hourly or monthly. Useful for item 5, where interactive debugging matters.
3. **Owned Mac** — a used Mac mini is the cheapest durable option and removes every constraint.

Items 4, 5, and 8 genuinely benefit from real interactive access. Items 1–3 do not.

**None of this blocks starting.** Android development proceeds on Windows today.

---

## 7. What can be developed and tested entirely on Windows

**Everything except the iOS-specific items above.** Concretely:

| Area | On the Dell |
|---|---|
| The entire simulation (`stride_core`) | ✅ `dart test`, milliseconds, no emulator |
| Step reconciliation logic and all twelve scenarios | ✅ Against the simulated provider |
| Content schemas, validation, authoring | ✅ |
| Save format, migration, crash-replay | ✅ |
| Skills, XP, gathering, crafting, inventory, equipment | ✅ |
| Combat resolver, determinism, preparation-gate simulations | ✅ |
| Balance projections at all three step fixtures | ✅ |
| **The entire UI** — six tabs, combat modal, return summary | ✅ Including hot reload |
| Widget tests and golden tests | ✅ |
| Android app, end to end | ✅ Emulator and physical device |
| **Android Health Connect adapter** | ✅ Written, built, and tested on Windows |
| Audio and haptic integration, Android side | ✅ |
| Accessibility work, Android side | ✅ |
| Android APK / App Bundle builds and Play distribution | ✅ |
| The Swift HealthKit adapter | ✍️ Authorable on Windows; **not buildable or testable** |

That last row is the honest boundary, and it is the same lesson F-01 taught: **authored is not verified.** Swift written on Windows must be treated as unverified until a Mac compiles it.

The proportion is what matters. Under the current native-Swift decision, roughly **0%** of the project is verifiable on the owner's machine. Under Flutter, it is roughly **90%**.

---

## 8. Risks of the recommendation

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| X-01 | A third-party health plugin creeps in "temporarily" | **High** | First-party channels are a decision, not a preference. A health plugin in `pubspec.yaml` should fail review. |
| X-02 | Audio quality falls short of the pillar | Medium | Prototype the ambience crossfade and cue rotation early, behind `AudioDirecting`. Evaluate at task A-04, not at Phase 5. |
| X-03 | iOS diverges silently because it is built rarely | Medium | Wire cloud CI early so every push builds iOS even before anyone runs it. A build that never runs still catches compile breaks. |
| X-04 | Health Connect availability on older Android | Medium | Graceful degradation, same path as a denied permission. Verify minimum supported version at implementation. |
| X-05 | Flutter framework risk | Low | Mitigated by the pure-Dart core: the simulation has no Flutter dependency and would survive a framework change. |
| X-06 | Platform behavioral drift in step counting | Medium | The ledger model is platform-neutral; only the adapters differ. Run the twelve scenarios against both adapters. |

---

## 9. Critic Agent note

Two things worth saying plainly.

**First, the original decision was not wrong on its facts — the facts were wrong.** `DECISIONS/0002` reasoned correctly from "iOS only, Mac available." Both premises have changed. That is a healthy reopening, not a reversal of a bad judgement, and it happened at the cheapest possible moment: F-01 is a skeleton, and F-02 was gated on a build that never happened.

**Second, watch X-01.** The moment the platform channel becomes tedious, a health plugin will look like a shortcut that saves an afternoon. It would place the project's highest-severity system behind someone else's abstraction. The entire fidelity case for Flutter rests on not taking that shortcut — the recommendation is conditional, and the condition is load-bearing.

---

## 10. Requested approval

To proceed, the owner should confirm:

1. **Adopt Flutter** with first-party platform channels — replacing `DECISIONS/0002`
2. **Sequence Android first**, adding iOS when Mac access is arranged
3. **How macOS access will be provided** — cloud CI, rented, or owned
4. **Android beta channel** — Play closed testing, or direct APK

On approval, Studio Stride will write `DECISIONS/0010_CROSS_PLATFORM_STACK.md`, supersede `0002`, amend `0009`, replace `ARCHITECTURE_IMPLEMENTATION_PLAN.md`, adopt the revised task breakdown, and restart F-01 in its Flutter form.

**Until then, nothing is replaced and F-01 remains paused.**
