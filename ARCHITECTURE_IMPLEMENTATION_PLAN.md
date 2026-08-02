# Architecture Implementation Plan

**Project:** Project Stride
**Milestone:** 01 — First Adventure Vertical Slice
**Version:** 1.1 — review findings applied
**Date:** 2026-08-01
**Author:** Technical Director, Studio Stride
**Status:** Awaiting owner approval — no production code written
**Reviews:** `DESIGN_REVIEW.md`, `CRITIC_REPORT.md`

Completes `TECHNICAL/ARCHITECTURE_IMPLEMENTATION_PLAN_TEMPLATE.md`. Binding decisions: `DECISIONS/0001`–`0004`.

---

## 1. Recommended stack

| Concern | Choice | Notes |
|---|---|---|
| Language | Swift 6, strict concurrency | |
| Minimum OS | iOS 17 | Observation, SwiftUI maturity, Swift Testing |
| UI | SwiftUI + `@Observable` view models | |
| Simulation | `StrideCore` local Swift package | Pure, deterministic, no platform frameworks |
| Health | HealthKit, behind `StepProvider` | |
| Persistence | Versioned `Codable` snapshot + append-only step ledger | Atomic writes, file protection |
| Content | JSON with versioned schemas | Bundled, decoded at launch |
| Audio | AVAudioEngine, behind `AudioDirecting` | |
| Haptics | Core Haptics, behind `HapticPlaying` | |
| Tests | Swift Testing (core), XCTest (integration) | |
| Dependencies | **None at runtime** | Third-party runtime additions require a decision record |
| Devices | iPhone only, **portrait only** | No iPad idiom, no landscape (`DECISIONS/0009`) |
| Distribution | Local builds, then TestFlight | No App Store launch preparation (`DECISIONS/0009`) |

Approved in `DECISIONS/0002_TECHNOLOGY_STACK.md` and `DECISIONS/0009_PLATFORM_AND_DISTRIBUTION.md`.

Test matrix: one small iPhone simulator, one contemporary standard-size simulator, and the owner's physical iPhone once its model is provided. Simulators cannot validate HealthKit, Core Haptics, or battery — those criteria require the device.

**Constraint of record:** iOS development requires macOS.

### 1.1 Alternatives considered

Recorded in full in `DECISIONS/0002_TECHNOLOGY_STACK.md` §Alternatives: React Native/Expo (rejected — HealthKit bridge fidelity, two languages), Flutter (strongest runner-up, revisit only if Android is promoted from "maybe" to "planned"), Kotlin Multiplatform (architecturally clean, rejected on solo-project cost before loop validation), Unity/Godot (rejected — engine overhead for a game with no renderer).

---

## 2. Application architecture

### 2.1 Layers

```text
┌─────────────────────────────────────────────┐
│  Presentation — SwiftUI views, @Observable  │  app target
│  view models, navigation, animation          │
├─────────────────────────────────────────────┤
│  Adapters — HealthKitStepProvider,          │  app target
│  FileSaveStore, AVAudioDirector,            │
│  CoreHapticsPlayer, BundleContentLoader     │
├─────────────────────────────────────────────┤
│  Ports — protocols owned by StrideCore      │  StrideCore
├─────────────────────────────────────────────┤
│  Simulation — GameState, reducers, rules,   │  StrideCore
│  reconciliation, activities, crafting,      │
│  combat, XP, events                         │
├─────────────────────────────────────────────┤
│  Content — JSON schemas + decoded value     │  StrideCore types,
│  types (items, recipes, nodes, enemies,     │  bundled JSON
│  locations, audio cues)                     │
└─────────────────────────────────────────────┘
```

Dependencies point **inward only**. `StrideCore` knows nothing about SwiftUI, HealthKit, AVFoundation, Core Haptics, the file system, or the clock.

### 2.2 The one enforced rule

`StrideCore/Package.swift` declares no platform framework dependencies. A CI check (and a pre-commit grep) fails the build if any file under `Sources/StrideCore` contains `import SwiftUI`, `import UIKit`, `import HealthKit`, `import AVFoundation`, or `import CoreHaptics`.

This is not architectural purity for its own sake. It is what makes the simulation testable in milliseconds, keeps balance work independent of the UI, and means a future Android port re-implements a specified system rather than reverse-engineering one.

### 2.3 Ports defined by StrideCore

```swift
protocol StepProvider {
    func requestAuthorization() async throws -> StepAuthorization
    func fetchNewSteps(since anchor: StepAnchor?) async throws -> StepFetchResult
}

protocol SaveStore {
    func load() throws -> SaveEnvelope?
    func save(_ envelope: SaveEnvelope) throws
    func appendLedger(_ entry: StepLedgerEntry) throws
    func readLedgerTail(count: Int) throws -> [StepLedgerEntry]
}

protocol ContentLoader {
    func loadContentPack() throws -> ContentPack
}

protocol AudioDirecting { func emit(_ event: GameEvent) }
protocol HapticPlaying  { func emit(_ event: GameEvent) }
```

Each has a production implementation in the app target and a deterministic test double in the test target.

### 2.4 Simulation shape

`StrideCore` exposes a single entry point:

```swift
public struct GameEngine {
    public private(set) var state: GameState
    public let content: ContentPack

    public mutating func apply(_ intent: PlayerIntent) -> [GameEvent]
    public mutating func ingest(steps: Int) -> [GameEvent]
    public mutating func consumeSteps(_ count: Int) -> [GameEvent]
}
```

- **`GameState` is a value type.** Copyable, `Codable`, `Equatable`. This makes save/load trivially correct and lets tests diff whole states.
- **Every mutation returns `[GameEvent]`.** Events are the sole channel to audio, haptics, and the "what changed" summary. Nothing in the simulation ever names a sound file or a UI animation; it emits `.resourceGathered(item: .oakLog, count: 3)` and the adapters decide what that sounds and feels like.
- **No randomness without a seed.** All variance draws from a seeded generator stored in `GameState`, so any outcome is reproducible from a state plus an intent. This is what makes combat balance testable.
- **No clock.** The simulation never reads the current time. Timestamps enter only as data on ingestion records, for display.

### 2.5 Event catalogue (initial)

`GameEvent` is the contract between systems and senses. Milestone 01 needs roughly: `stepsIngested`, `stepsConsumed`, `activityStarted`, `activityProgressed`, `activityCompleted`, `resourceGathered`, `skillXPGained`, `skillLevelUp`, `travelDeparted`, `travelArrived`, `locationDiscovered`, `itemCrafted`, `craftFailed`, `itemEquipped`, `encounterStarted`, `playerActed`, `enemyActed`, `damageDealt`, `damageTaken`, `consumableUsed`, `encounterWon`, `encounterRetreated`, `characterLevelUp`, `saveWritten`.

Every event carries enough payload to select a material-specific sound (`GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md`: copper must not sound like iron).

---

## 3. State management

### 3.1 In the core

`GameState` is one value type composed of: `player` (level, XP, HP, attributes), `steps` (ingested, consumed, discrepancy), `skills` (five levels + XP), `inventory`, `equipment`, `world` (current location, discovered locations, travel progress), `activity` (the single selected activity, if any), `encounter` (optional in-flight combat), and `rng`.

**One activity at a time** in Milestone 01, recorded as a design decision in `DECISIONS/0006_SINGLE_ACTIVITY.md` — it is the Lead Game Designer's call, not a technical convenience, and it has a real player consequence: while travelling, you cannot gather.

### 3.2 In the app

A single `@Observable final class GameStore` owns the `GameEngine`, is `@MainActor`, and exposes read-only projections to views. Views send `PlayerIntent`s; the store applies them, fans the returned events out to audio and haptics, and persists.

No global mutable state, no singletons other than the store, no view reaching into another view's state.

### 3.3 Threading

- Simulation: synchronous, main actor. It is arithmetic over a small struct; there is nothing to parallelize.
- HealthKit and disk I/O: `async`, off the main actor, results marshalled back before touching state.
- Audio: AVAudioEngine's own threads, driven by fire-and-forget event emission.

---

## 4. Local-save strategy

### 4.1 Two artifacts

**A. `save.json` — the snapshot.** The full `GameState`, plus a schema version.

```swift
struct SaveEnvelope: Codable {
    let schemaVersion: Int      // 1 for Milestone 01
    let contentPackVersion: Int
    let writtenAt: Date         // display only
    let state: GameState
}
```

Written atomically: serialize → write to `save.json.tmp` → `FileManager.replaceItemAt`. A crash mid-write leaves the previous good save intact. One rolling backup (`save.backup.json`) is retained and used if the primary fails to decode.

**B. `steps.ledger` — the append-only step log.** One line per ingestion batch. Written **before** the snapshot, and before any gameplay consumes the steps. See §6.

### 4.2 Why a snapshot, not a database

The entire Milestone 01 state is a few kilobytes: five skill levels, an inventory of tens of stacks, four locations, one optional encounter. A snapshot is simpler, fully diffable in tests, and trivially versioned.

**Escalation path, documented now so it is not a surprise:** if the state grows past roughly a megabyte or writes become perceptible, migrate to SQLite via GRDB. The `SaveStore` port makes that a swap of one adapter.

### 4.3 Migration

`schemaVersion` is checked on load. Milestone 01 ships version 1 and a `migrate(from:to:)` function that is a no-op — but the *mechanism* ships now, with a test proving a version-0 fixture is rejected cleanly rather than crashing. Retro-fitting migration onto a shipped save format is far more expensive than carrying an empty hook.

### 4.4 File protection

Saves are written with `.completeFileProtectionUnlessOpen`. They contain derived gameplay counters, never raw health samples — but the counters are step-derived, so they get the same care.

---

## 5. iOS and HealthKit approach

### 5.1 Permissions

Read-only authorization for `HKQuantityTypeIdentifier.stepCount`. Nothing else. No write access, ever.

`NSHealthShareUsageDescription` states plainly: step counts advance your activities and travel; the data stays on your device.

The permission is requested **after** an in-app explanation screen, not on first launch cold. HealthKit does not report read-denial (by design, to avoid leaking that the user has no data), so the app must behave correctly when authorization is granted but zero samples arrive — indistinguishable states, one code path.

### 5.2 Reading

`HKAnchoredObjectQuery` over `stepCount`, persisting `HKQueryAnchor`. Anchored queries give exactly what is needed: new samples since the anchor, plus deletions, without date arithmetic.

Manually-entered samples (`HKMetadataKeyWasUserEntered == true`) are filtered by default, with a visible setting to include them (`GAME_BIBLE/HEALTH_INTEGRATION`).

### 5.3 Background delivery is best-effort

`enableBackgroundDelivery(for:frequency:)` with the HealthKit background capability is enabled — but **cold-launch backfill is the source of truth.**

HealthKit data is encrypted at rest and **unreadable while the device is locked**. A background wake on a locked phone cannot read steps. Any design that depends on background reads is broken; any design that reconciles fully on foreground launch is correct regardless. Background delivery is therefore treated as an optimization that may silently never fire.

This is the single most important platform constraint in the project, and it is why §6 is designed the way it is.

### 5.4 Failure and revocation

| Situation | Behavior |
|---|---|
| Authorization never granted | Game fully playable; a persistent, non-nagging banner offers to connect. Manual step entry available. |
| Authorization revoked in Settings | Same as above. Existing progress untouched. |
| HealthKit unavailable (iPad, simulator) | `StepProvider` reports unavailable; manual/simulated provider used. |
| Query error | Anchor unchanged, retry next launch. Never advance `stepsIngested` on a failed read. |

Nothing about a missing permission ever blocks a screen, a craft, or a fight. Steps gate rate, never access.

---

## 6. Step-reconciliation model

This is the highest-severity system in the project (risk R-01). A subtle bug here silently destroys trust in everything else, so it is specified rather than left to implementation.

### 6.1 The ledger

Two monotonic counters live in `GameState.steps`:

- `stepsIngested` — everything ever read from the provider
- `stepsConsumed` — everything ever spent on activities

Available steps = `stepsIngested − stepsConsumed − discrepancyDebt`. **Both counters only ever increase.**

### 6.2 No day boundaries, no timezone logic

Steps are a ledger, not a daily budget. There is no "today's steps", no midnight rollover, no local-calendar arithmetic anywhere in the reconciliation path.

This eliminates an entire bug class at a stroke: DST transitions, flights across timezones, midnight edge cases, and retroactive Health writes all become non-events. A step read at any time from any date is simply added to the total exactly once.

### 6.3 The ingestion sequence

1. Run the anchored query. Receive `(newSamples, deletedObjects, newAnchor)`.
2. Sum `newSamples` (after the manual-entry filter) into `delta`.
3. **Append `{batchID, delta, newAnchor, timestamp}` to `steps.ledger` and flush.**
4. Increase `stepsIngested` by `delta`; store `newAnchor`.
5. Write the snapshot.
6. Emit `.stepsIngested(delta)`.

Step 3 preceding steps 4–5 is what makes crash recovery safe: on launch, if the ledger's last `batchID` is newer than the snapshot's, the batch is replayed; if it matches, it is skipped. Idempotent by construction, so a crash mid-reconciliation can neither double-count nor lose a batch.

### 6.4 Corrections and deletions never claw back

If deletions or corrections would reduce the legitimate ingested total below `stepsConsumed`, the game **does not** revoke granted progress. It records the shortfall in `discrepancyDebt` and absorbs it against future ingestion.

`discrepancyDebt` is capped so a pathological Health correction cannot leave the player permanently unable to progress. Beyond the cap, the debt is forgiven and logged.

The cap is a **provisional content tunable**, not a Swift constant. Its intended shape is roughly three days of the player's typical walking; the actual value is derived in `GAME_BIBLE/BALANCE/` once the owner's daily step count is known.

The player never watches progress disappear. This is a direct application of the no-punishment non-negotiable, and it is deliberately generous: in the rare conflict between perfect accounting and player trust, trust wins.

### 6.5 Allocation

Available steps apply to exactly one selected activity. Allocation is explicit: the player chooses what their walking goes toward, and unallocated steps bank indefinitely and never expire.

Banked steps never expiring is load-bearing. Expiry would be an FOMO mechanic, which the Kernel forbids.

### 6.6 Overflow on return

A player returning after two weeks may bank 80,000 steps against an activity needing 5,000. The excess completes the activity, and the remainder **stays banked** — it is not spilled into a random next activity and not discarded. The return summary shows what completed and what is still available to spend.

This preserves player agency (`03_DESIGN_PILLARS.md`: "Walking should create decisions rather than automate the entire game"). The walk earned the steps; the player decides where they go.

### 6.7 Testability

The entire model is exercised through `StepProvider` with zero HealthKit involvement. Required scenarios, all deterministic:

| # | Scenario | Assertion |
|---|---|---|
| 1 | Simple ingest | Counters exact |
| 2 | Same batch delivered twice | No double count |
| 3 | Out-of-order samples | Order-independent total |
| 4 | Deletion within available | Debt recorded, no clawback |
| 5 | Deletion exceeding consumed | Debt recorded, progress intact |
| 6 | Debt beyond cap | Forgiven, logged, player unblocked |
| 7 | 14-day absence, 100k steps | Single reconciliation, correct total |
| 8 | Crash between ledger and snapshot | Replay yields identical state |
| 9 | Crash after snapshot | No replay, no double count |
| 10 | Timezone change mid-sequence | No effect whatsoever |
| 11 | Authorization revoked mid-session | Graceful, counters frozen |
| 12 | Zero-step week | No progress, no penalty, no nag |

These tests are written **before** the feature (task F-04 in the breakdown).

---

## 7. Data-driven content model

### 7.1 Files

`Content/v1/` bundled with the app: `items.json`, `recipes.json`, `skills.json`, `resource_nodes.json`, `locations.json`, `enemies.json`, `encounters.json`, `audio_cues.json`, `strings.json`.

Every file carries `{"schemaVersion": 1, "entries": [...]}`. IDs are stable string slugs (`oak_log`, `bronze_pickaxe`, `forest_wolf`) — never array indices, never localized names.

### 7.2 Loading and validation

`ContentPack` is decoded once at launch and validated:

- Every referenced ID resolves
- No recipe is unreachable from starting equipment (this is the automated guard against the tool-bootstrap class of bug from C-05)
- Every gatherable resource has a consumer
- Every skill has XP curve, unlock cadence, and milestone rewards
- Every material referenced by an audio cue exists

Validation failure is a **build-time test failure**, not a runtime crash. Content is authored data, so content errors are caught by the test suite that runs against the bundled pack.

### 7.3 Balance data and profiles

All tunable numbers live in content, never in Swift: XP curves, steps-per-gather, steps-per-travel-segment, yields, damage, HP, drop tables, and the `discrepancyDebt` cap.

Tuning must be possible without touching code, because the first numbers will be wrong.

Two profiles exist (`DECISIONS/0007`):

- **Production** — the real balance data, the only profile that ships
- **Accelerated** — a separate development/test profile that reaches states quickly for QA and automated tests

The accelerated profile is a *distinct* content profile, never an overlay or a mutation of production values. Switching profiles leaves production data byte-identical, asserted by test. It is unavailable in release builds, and pacing assertions always run against production values.

---

## 8. Audio architecture

### 8.1 Semantic events, never file names

Systems emit `GameEvent`s. `AVAudioDirector` maps events to **asset IDs** via `audio_cues.json`; `AUDIO/AUDIO_ASSET_MANIFEST.md` maps asset IDs to files and provenance. No simulation code knows a sound exists, and no code or content references a filename or path.

That indirection is what makes shipping placeholders safe: replacing a generated placeholder with a better recording is a one-row manifest change (`DECISIONS/0005`).

This is what lets audio ship as a first-class system from Phase 3 with placeholder assets, satisfying the locked pillar without blocking on asset sourcing (gap G-05).

### 8.2 Buses

Four AVAudioEngine mixer nodes: **ambience** (looping region bed, crossfaded on location change), **action** (gathering, crafting, combat), **UI** (taps, confirmations), **music** (sparse; region themes and encounter stings).

Independent volume per bus in settings, plus a master mute. Respects the silent switch and ducks for other audio — a walking game will often be playing over a podcast, and Stride must never fight the player's own audio.

### 8.3 Material identity

`audio_cues.json` keys on `(event, material, tier)`, so oak and pine chop differently and copper and iron ring differently, as required by `GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md`. Missing cues fall back to a generic sound and **fail a content validation test**, so silent gaps cannot ship unnoticed.

### 8.4 Memory and battery

Short cues preloaded as buffers; ambience beds streamed. Total audio memory budget: 30 MB — **provisional**, to be confirmed against real assets in task A-05. Ambience does not run while the app is backgrounded — no background audio session in Milestone 01, since the game does not play during the walk.

### 8.5 Haptics

`CoreHapticsPlayer` consumes the same events. Every haptic pairs with a sound and is individually disableable. Haptics are never the sole channel for information.

---

## 9. Test strategy

| Layer | Framework | Scope |
|---|---|---|
| Simulation | Swift Testing | Reconciliation, XP, gathering, crafting, combat, save round-trip. Runs in seconds, no simulator. |
| Content | Swift Testing | Schema validation, reference integrity, reachability, audio cue coverage |
| Adapters | XCTest | Save atomicity, crash-recovery replay, `HealthKitStepProvider` against a stubbed store |
| Integration | XCTest | Full loop: ingest → allocate → gather → craft → equip → fight → save → reload |
| UI | XCUITest | Smoke only — launch, tab navigation, start an activity, resolve an encounter |
| Manual | Checklist | Real device, real walking, real Health data; the only way to validate feel |

### 9.1 Required suites — the actual gate

Coverage percentage is not a gate. It is gameable and says nothing about whether the right things are tested. These named suites are the gate:

1. The twelve step-reconciliation scenarios (§6.7)
2. Save round-trip, interrupted write, corruption fallback, version rejection, ledger replay idempotence
3. XP curve boundaries and cap behavior for all five skills
4. Fresh-start-to-Bronze reachability
5. Combat determinism across 1,000 seeded encounters
6. The preparation-gate simulations under optimal play
7. Content validation, including deferred-vocabulary rejection
8. The `stepsConsumed` leak invariant

Coverage may be reported for information. It is never the criterion.

**Determinism is the through-line.** No test depends on wall-clock time, real HealthKit, or unseeded randomness. A failing test names a specific broken rule.

`/qa-check` categories map to layers as: step-data correctness → simulation + adapters; save integrity → adapters; offline behavior → integration; UX clarity and balance → manual.

---

## 10. Performance and battery

Stride is not compute-bound. The realistic risks are HealthKit polling, audio, and animation.

- **Reconciliation runs on launch and on foreground, not on a timer.** No polling loop.
- **No background execution** beyond opportunistic HealthKit delivery. No background fetch, no location services, no pedometer.
- Targets: cold launch to interactive < 1.5 s; reconciliation of a two-week absence < 500 ms; steady-state 60 fps; no measurable battery drain while backgrounded, because nothing runs.
- Idle CPU while foregrounded and inactive should be ~0% — no timers ticking, which is a natural consequence of step-clocked progression.

The step-clocked decision pays a real dividend here: a time-clocked game must simulate elapsed time and keep something ticking. Stride simulates only on step delivery.

---

## 11. Privacy and permissions

- **Raw health data never leaves the device.** No cloud, no accounts, no analytics, no crash reporters, no third-party SDKs in Milestone 01.
- Persisted health-derived state is three numbers plus an opaque anchor. No step history, no timestamps beyond the ledger's, no daily breakdown.
- A visible **Disconnect and reset** control clears the anchor, the ledger, and all step counters, leaving gameplay progress intact.
- Permission rationale is shown in-app before the system sheet, in plain language, with no dark patterns and no repeated prompting after a decline.
- **A privacy policy is required** before TestFlight distribution (gap G-09) — TestFlight still goes through App Review, App Review requires a privacy policy for any app requesting HealthKit access, and the App Privacy questionnaire must declare health data usage. Drafted during Phase 2, not at submission. Store listing, screenshots, and marketing copy are explicitly **out of scope** (`DECISIONS/0009`).
- **Step counts are never presented as targets.** No goal rings, no daily quotas, no "you walked less than usual." The simulation fixtures in `DECISIONS/0007` (2,500 / 7,500 / 15,000 steps per day) are test inputs and must never surface in player-facing copy as recommendations or expected behavior.

---

## 12. Future cloud and leaderboard compatibility

Milestone 04 may add leaderboards, friend comparison, or cloud save. Nothing is built for it now, but three cheap choices keep the door open:

1. **Stable content IDs** — a server could reference `oak_log` meaningfully.
2. **Versioned save schema** — a sync layer needs a version to negotiate.
3. **A value-type `GameState`** — serializable to anything, with no object graph to untangle.

Explicitly **not** built now: user IDs, device IDs, sync conflict resolution, server-authoritative validation, network layer, or a `CKRecord`-shaped save. Each would be speculative complexity, and `07_DECISION_FRAMEWORK.md` asks whether complexity is worth present player value. Here it is not.

One caveat recorded honestly: a leaderboard built on client-authoritative step data cannot be trusted against determined manipulation. If Milestone 04 pursues competitive comparison, that is a design problem requiring its own decision, not a technical detail to be patched in later.

---

## 13. Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| A-01 | Reconciliation bug corrupts progress | Critical | Ledger-before-snapshot, idempotent replay, 12-scenario suite written before the feature, no-clawback rule |
| A-02 | Background delivery assumed reliable | High | Foreground backfill is the source of truth; background treated as an optimization that may never fire |
| A-03 | Balance unknowable without real walking | High | All numbers in content; debug step injector; first values explicitly provisional |
| A-04 | Audio deferred despite being a pillar | High | Events emitted from Phase 3; placeholder cues acceptable, missing hooks are not; validation test fails on uncovered materials |
| A-05 | `StrideCore` purity erodes under deadline | Medium | Automated import check in CI and pre-commit |
| A-06 | Snapshot save outgrows its design | Medium | `SaveStore` port; GRDB escalation path documented |
| A-07 | Content scope creep | Medium | Frozen scope in `DECISIONS/0004`; additions need a decision record |
| A-08 | Onboarding under-designed | Medium | It grants starting gear and teaches the loop; treated as a real feature in Phase 5, not a formality |
| A-09 | No visual identity | Medium | Gap G-04 must close before Phase 5 |
| A-10 | Solo momentum loss | Medium | Small, independently shippable, independently testable tasks |

---

## 14. Recommendation

**Approve and proceed to Phase 1.**

The architecture is deliberately conservative. It adds no framework, no dependency, and no abstraction that the vertical slice does not need, while placing the one genuinely hard problem — step reconciliation — behind an interface that can be tested exhaustively without a device.

Two things should be understood as accepted trade-offs rather than oversights:

1. **Android is deferred, not enabled.** A future port rewrites everything above `StrideCore`.
2. **The snapshot save is intentionally simple.** It will need replacing if the game grows well beyond the vertical slice. That is a good problem to have, and the port makes it a one-adapter change.

The first implementation task, `F-01`, builds the skeleton and the reconciliation test harness *before* any gameplay depends on it. That ordering is the plan's main defence against its own worst risk.

### Open items — all closed

| Item | Resolved by |
|---|---|
| Xcode version and target device set | `DECISIONS/0009` — current stable Xcode, iOS 17, iPhone portrait only |
| TestFlight vs. App Store distribution | `DECISIONS/0009` — TestFlight only, no store launch preparation |
| Balance pacing targets | `DECISIONS/0007` — loop validated in one to two weeks; fixtures 2,500 / 7,500 / 15,000 |
| Audio sourcing budget and licence preference | `DECISIONS/0005` — lean prototype budget, generated and CC0, full provenance |

**One physical constraint remains:** iOS builds require macOS, and the repository currently lives on a Windows machine. See `MILESTONES/F-01_COMPLETION_REPORT.md`.
