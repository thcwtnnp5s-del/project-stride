# Architecture Implementation Plan

**Project:** Project Stride
**Milestone:** 01 — First Adventure Vertical Slice
**Version:** 2.0 — Flutter
**Date:** 2026-08-01
**Author:** Technical Director, Studio Stride
**Status:** Revised for `DECISIONS/0010`. Presented for approval before migration executes.

Supersedes v1.1, archived at `TECHNICAL/ARCHITECTURE_IMPLEMENTATION_PLAN_SWIFT_ARCHIVED.md`.
Completes `TECHNICAL/ARCHITECTURE_IMPLEMENTATION_PLAN_TEMPLATE.md`. Binding: `DECISIONS/0001`, `0003`–`0011`.

> **What changed from v1.1:** the language and runtime. The *shape* — layered with dependencies pointing inward, a pure simulation core, ports for every platform capability, semantic events driving audio and haptics, a ledger-based reconciliation model, JSON content with build-time validation — is unchanged. Sections marked **(unchanged)** carry over in substance.

---

## 1. Recommended stack

| Concern | Choice |
|---|---|
| Framework | Flutter, current stable |
| Language | Dart 3, sound null safety |
| Simulation | `stride_core` — pure Dart package, **no Flutter import** |
| Health | `stride_health` — repository-owned package, Pigeon-typed channels |
| State | A single store over `stride_core`, exposed to the widget tree |
| Persistence | Versioned JSON snapshot, atomic write, plus an append-only step ledger |
| Content | JSON, versioned schemas, decoded into `stride_core` value types |
| Audio | Behind `AudioDirecting`; package-based, replaceable |
| Haptics | Behind `HapticPlaying`; platform channel for custom patterns |
| Tests | `dart test` for the core, `flutter test` for widgets, integration on device |
| Platforms | Android and iOS. **Mobile only** — no desktop or web target in any configuration |
| Orientation | Portrait only, phone only, both platforms |
| Minimum OS | iOS 17; Android minimum set at F-01 against Health Connect's floor |

Approved in `DECISIONS/0010_CROSS_PLATFORM_STACK.md`. Alternatives are compared in `ARCHITECTURE_REVIEW_CROSS_PLATFORM.md`.

---

## 2. Application architecture

### 2.1 Layers

```text
┌─────────────────────────────────────────────┐
│  Presentation — Flutter widgets, navigation │  app
├─────────────────────────────────────────────┤
│  Store — holds GameEngine, fans events out  │  app
├─────────────────────────────────────────────┤
│  Adapters — stride_health, FileSaveStore,   │  app + stride_health
│  AudioDirector, HapticPlayer, ContentLoader │
├─────────────────────────────────────────────┤
│  Ports — abstract classes owned by core     │  stride_core
├─────────────────────────────────────────────┤
│  Simulation — GameState, reducers, rules,   │  stride_core
│  reconciliation, activities, crafting,      │
│  combat, XP, events                         │
├─────────────────────────────────────────────┤
│  Content — JSON schemas + value types       │  stride_core + assets
└─────────────────────────────────────────────┘
```

Dependencies point **inward only**.

### 2.2 The enforced rule

`packages/stride_core/pubspec.yaml` declares **no dependency on `flutter`**, and no dependency on any platform or plugin package. A test and a script both fail when any file under `stride_core/lib` imports `package:flutter`, `dart:ui`, `dart:io`, or any plugin.

`dart:io` is on the list deliberately: the core must not touch the file system or the clock. Persistence goes through `SaveStore`.

This is the same rule F-01 enforced in Swift, carried forward in substance. Both enforcement points read one shared list so the rule and its guard cannot drift apart.

### 2.3 Ports defined by `stride_core`

```dart
abstract interface class StepProvider {
  Future<StepAuthorization> requestAuthorization();
  Future<StepFetchResult> fetchNewSteps({StepAnchor? since});
}

// Superseded at F-05 by two narrower ports. The single SaveStore put the
// transaction protocol in the app layer, where it could not be tested by
// `dart test` in milliseconds — and the protocol *is* the crash-safety
// argument. The ports now promise only "bytes, durably"; the protocol lives
// in stride_core. See DECISIONS/0012.
abstract interface class SnapshotSlotStore {
  Future<Uint8List?> read(SnapshotSlot slot);
  Future<void> write(SnapshotSlot slot, Uint8List bytes);  // returns when durable
  Future<void> erase(SnapshotSlot slot);
}

abstract interface class LedgerJournal {
  Future<List<Uint8List>> readLines();
  Future<void> appendLine(Uint8List line);                 // the commit point
  Future<void> replaceLines(List<Uint8List> lines);
  Future<bool> discardIncompleteCompaction();
  Future<void> erase();
}

abstract interface class ContentLoader {
  Future<ContentPack> loadContentPack();
}

abstract interface class AudioDirecting { void emit(GameEvent event); }
abstract interface class HapticPlaying  { void emit(GameEvent event); }
```

`StepAnchor` is **opaque** — an encoded blob the core stores and returns without inspecting. On iOS it wraps an `HKQueryAnchor`; on Android a Health Connect changes token. The core must never know which.

That opacity is what lets one ledger serve two platforms with genuinely different sync primitives.

### 2.4 Simulation shape *(implemented at F-03)*

The engine flow is:

```text
command → validate against state + ContentRegistry
        → typed events, or a typed rejection
        → canonical reducer
        → new immutable state
```

**Commands are requests; events are facts.** A command may be refused; an event has already been accepted and applying it cannot fail. That separation is what makes the reducer total, and a total reducer is what makes replay meaningful — re-applying a saved event sequence cannot disagree with the original run, because there is nothing left to re-decide.

**One reducer writes.** Changing state in a command handler and emitting an event afterwards "for logging" produces two implementations of every rule: the one that runs, and the one replay uses. They agree until they don't, and that day a save loads as a different game than it was.

**Rejections are returned, never thrown.** Equipping an item you do not own is ordinary, not exceptional. Exceptions are reserved for programming faults — an out-of-order event, an unreadable state version — so a genuine bug cannot hide inside a handled failure. Reason codes are stable wire strings and may be added but never renamed.

**Deep immutability is enforced, not asserted.** Every collection is copied on construction *and* exposed unmodifiable. `final` in Dart prevents reassignment, not mutation: without the copy, a caller who kept the map they passed in can edit the state afterwards; without the wrapper, a caller who reads a collection off a snapshot can edit the engine and every other snapshot sharing that reference. Both failures are silent and surface far from their cause.

**State stores content IDs, never definitions.** State is the thin, serializable, long-lived half; content is the fat, reloadable half. A save embedding a definition would carry a stale copy of content that has since changed.

*Original v1.1 text follows.*

```dart
class GameEngine {
  GameState get state;
  final ContentPack content;

  List<GameEvent> apply(PlayerIntent intent);
  List<GameEvent> ingest({required int steps});
}
```

- **`GameState` is immutable.** All fields `final`, no in-place mutation, `copyWith` for derivation, value equality implemented.
- **Every mutation returns `List<GameEvent>`.** Events are the sole channel to audio, haptics, and the "what changed" summary. Nothing in the simulation names a sound file.
- **No randomness without a seed.** All variance draws from a seeded generator held in `GameState`.
- **No clock.** The simulation never reads the current time. Timestamps enter only as data on ingestion records, for display.
- **Step consumption is not publicly callable** — steps are spent only through activity progression (review finding TD-1).

#### The one language-driven risk

Swift value types gave immutability for free; Dart does not. A mutable list leaking into `GameState` would silently break save correctness and test diffing — the failure would appear as an inexplicable state divergence, far from its cause.

Mitigation: `final` fields throughout, unmodifiable collection views on construction, and a test asserting that mutating a returned state cannot affect the engine's own. This is task F-03, acceptance criterion 6.

### 2.5 Event catalogue *(unchanged)*

Roughly 24 events from `stepsIngested` through `saveWritten`, each carrying enough payload to select a material-specific cue.

---

## 3. State management

### 3.1 In the core *(unchanged)*

`GameState` composes: `player`, `steps`, `skills`, `inventory`, `equipment`, `world`, `activity`, `encounter`, `rng`.

**One activity at a time** (`DECISIONS/0006`).

### 3.2 In the app

A single `GameStore` owns the `GameEngine`, exposes read-only projections to widgets, and fans returned events out to audio and haptics before persisting.

State management package choice is deferred to F-01 and is deliberately low-stakes: the store is thin, because the engine holds the logic. Whatever is chosen must not leak into `stride_core`.

### 3.3 Threading

- Simulation: synchronous on the UI isolate. It is arithmetic over a small object graph.
- Health and disk I/O: `async`, off the platform channel, results applied before touching state.
- Audio: the package's own threads, driven by fire-and-forget emission.

No `Isolate` use in Milestone 01. If reconciliation of a very long absence ever becomes perceptible, the pure core moves to an isolate trivially — it has no platform dependencies to marshal.

---

## 4. Local-save strategy

> **⚠️ Amended 2026-08-02 by `DECISIONS/0012_SAVE_FORMAT.md`.** §4.1 below described a temp-file-plus-rename snapshot. That is **superseded**: the snapshot is two ping-pong slots. The original text is kept struck through, because "why isn't this just a rename?" is a question someone will ask again.

### 4.1 Three artifacts

**A. `save_slot_a` and `save_slot_b`** — two complete snapshots, each carrying a monotonic generation, save format version, last applied journal transaction, integrity digest, payload, and a commit-complete marker. A commit writes to the older or invalid slot and **never touches the live one**; recovery loads the highest-generation slot that verifies.

~~Written atomically: serialize → write `save.json.tmp` → rename. One rolling backup used if the primary fails to decode.~~

**Why not rename.** Dart cannot fsync a directory, so a rename is not durably ordered against the file's contents — its atomicity is a promise we have no way to verify from where we stand. Ping-pong gets atomicity from never overwriting the live copy, which is a property of the protocol rather than of the filesystem. Cost: ~5 KB and one extra read at launch. Full reasoning in `DECISIONS/0012` §1.

**B. `journal`** — the write-ahead log. Append-and-flush is **the commit point**: it precedes the snapshot write and any gameplay consuming the steps. Bounded, not an event store — records are compacted once their effect is durable in two verified snapshots, which is a privacy control rather than a size optimization (`DECISIONS/0012` §3).

**C. The origin pseudonymization salt** — stored beside the save, covered by the same backup exclusions, and fingerprinted into the envelope so a changed salt fails closed instead of silently re-granting a retention window.

### 4.2 Why a snapshot, not a database

The whole state is a few kilobytes. A snapshot is simpler, diffable in tests, trivially versioned. Escalation path if it outgrows that: SQLite via `sqflite` or `drift`, behind the unchanged `SaveStore` port.

### 4.3 Migration

`schemaVersion` checked on load; v1 ships with a no-op `migrate` and a test proving a version-0 fixture is rejected cleanly rather than crashing.

### 4.4 File protection

Saves live in the app's private documents directory. On Android, `allowBackup` is disabled — an automatic cloud backup restored to a second device would duplicate a step ledger, which is exactly the double-count the whole design exists to prevent.

*This is a new consideration with no iOS equivalent, and it is the kind of platform difference that would be easy to miss.*

---

## 5. Health integration

### 5.1 Package structure

```text
packages/stride_health/
├── lib/
│   ├── stride_health.dart          Public Dart API
│   ├── src/platform_step_provider.dart
│   ├── src/mock_step_provider.dart  Deterministic, for tests
│   └── src/messages.g.dart          Pigeon-generated
├── pigeons/health_api.dart          Interface definition — the source of truth
├── android/  …/HealthConnectAdapter.kt
└── ios/      …/HealthKitAdapter.swift
```

### 5.2 The Pigeon boundary

One interface definition generates the Dart, Kotlin, and Swift sides. A change to the contract that is not reflected on all three sides **fails to compile** rather than failing at runtime with a null.

For the system that governs step correctness, a hand-rolled `MethodChannel` passing untyped maps would be the wrong economy.

The surface is deliberately tiny:

```dart
@HostApi()
abstract class HealthHostApi {
  StepAuthorizationResult requestAuthorization();
  bool isAvailable();
  StepFetchResult fetchNewSteps(Uint8List? anchor);
}
```

Three methods. That narrowness is what makes cross-platform fidelity achievable, and it is a property of steps-only integration (`GAME_BIBLE/HEALTH_INTEGRATION`).

### 5.3 iOS — HealthKit *(unchanged in substance)*

`HKAnchoredObjectQuery` over `stepCount`, persisted `HKQueryAnchor`, `deletedObjects` handling, `HKMetadataKeyWasUserEntered` filter, opportunistic background delivery.

**Reads fail while the device is locked** — health data is encrypted at rest. Background delivery is therefore best-effort.

### 5.4 Android — Health Connect

The **Changes API** — `getChangesToken()` then `getChanges(token)` — is the direct analogue of an anchored query, returning both upserts and deletions since the token.

- Read-only `StepsRecord` permission. No write scope, ever.
- `Metadata.recordingMethod` supplies the manual-entry filter.
- Health Connect is built into Android 14+; earlier versions require the Health Connect app. **Absence degrades gracefully** — identical path to a denied permission, and the game remains fully playable.
- Deep history permissions are not requested: the ledger never needs old data, only *new* data since the last token.
- Background sync via `WorkManager`, subject to Doze and manufacturer battery policies.

### 5.5 Neither platform can be trusted to wake the app

iOS background delivery fails on a locked device. Android background work is throttled unpredictably.

> **Foreground cold-launch backfill is the source of truth on both platforms. Background delivery is an optimization that may silently never fire.**

This decision was made in v1.1 for an iOS constraint. It turns out to be exactly what Android also requires, which is fortunate — a design that depended on reliable background wake-ups would have been broken twice over.

### 5.6 Failure and revocation

| Situation | Behavior |
|---|---|
| Authorization never granted | Fully playable. Persistent, non-nagging banner. Manual entry available. |
| Revoked in settings | Same. Existing progress untouched. |
| Health Connect not installed (Android) | Same graceful path. |
| Health service unavailable | Mock/manual provider. |
| Query error | Anchor unchanged, retry next launch. **Never advance `stepsIngested` on a failed read.** |

Nothing about a missing permission ever blocks a screen, a craft, or a fight. Steps gate rate, never access (`DECISIONS/0008`).

---

## 6. Step-reconciliation model *(unchanged — now serving two platforms)*

The highest-severity system in the project.

### 6.1 The ledger

`stepsIngested` and `stepsConsumed`, both monotonic. Available = `stepsIngested − stepsConsumed − discrepancyDebt`.

### 6.2 No day boundaries, no timezone logic

Steps are a ledger, not a daily budget. DST, flights, midnight, and retroactive writes all become non-events.

### 6.3 The ingestion sequence

1. Fetch through `StepProvider`. Receive `(delta, deletions, newAnchor)`.
2. **Append `{batchID, delta, newAnchor, timestamp}` to the ledger and flush.**
3. Increase `stepsIngested`; store the anchor.
4. Write the snapshot.
5. Emit `stepsIngested`.

Step 2 preceding 3–4 makes crash recovery safe: on launch, a ledger batch newer than the snapshot is replayed; a matching one is skipped. Idempotent by construction.

### 6.4 Corrections never claw back

Shortfalls record to `discrepancyDebt`, absorbed against future ingestion, capped (a provisional content tunable, roughly three days of walking) and forgiven beyond the cap.

**The player never watches progress disappear.** In the rare conflict between perfect accounting and player trust, trust wins.

### 6.5 Allocation and overflow

One selected activity. Unallocated steps bank indefinitely and never expire. **Terminating** activities (travel) bank the remainder on completion; **repeating** activities (gathering) consume until the player's allocation is exhausted.

### 6.6 Cursor invalidation — bounded authoritative rescan

Health Connect can expire or invalidate a changes token. HealthKit anchors do not expire, so this is the one genuinely Android-specific failure mode in the project.

When it happens, the delta stream is broken and the adapter cannot say what changed. The two obvious responses are both wrong: granting everything rescanned double-counts every step already granted, and resetting the ledger erases the player's earned progress.

#### The rule

> When a Health Connect changes token expires or becomes invalid, perform a **bounded authoritative rescan**, rebuild native source state, and reconcile it against the game's monotonic granted-step ledger **without duplicating previously granted progress**.

#### The contract is binding; the mechanism is not

Recovery must satisfy every clause below. **How** it satisfies them is an implementation choice to be settled at S-01 against the real Health Connect API, not locked here.

| # | Required behavior |
|---|---|
| 1 | The game ledger is **never reset** |
| 2 | Rescanned history is **never treated as all new** |
| 3 | Granted progress is **never clawed back** |
| 4 | The cursor is **never silently discarded in favour of granting full history** |
| 5 | A replacement token is persisted **only after** the recovery batch is committed to the ledger |
| 6 | Recovery interrupted at any point is **safe to retry** and recomputes the same result |

#### Initial hypothesis — watermark and overlap arithmetic

The save persists two values alongside the cursor:

| Field | Meaning |
|---|---|
| `sourceWatermark` | An instant such that all source data at or before it is fully accounted for |
| `grantedSinceWatermark` | Steps granted from source data *after* that watermark |

On recovery the adapter re-reads the **authoritative total** for `[sourceWatermark, now]` and reports it as `windowTotal` — a total, not a delta. Reconciliation then grants:

```text
newlyGrantable = max(0, windowTotal − grantedSinceWatermark)
```

The subtraction is the overlap correction: whatever was already granted from inside the rescanned window is deducted, so re-read data cannot be re-granted. The `max(0, …)` is the no-clawback rule — if the source now reports *less* than was granted, the shortfall becomes recorded discrepancy rather than lost progress.

`sourceWatermark` advances and `grantedSinceWatermark` resets to zero only after a successful recovery.

> **This equation is a starting hypothesis, not settled architecture.** It is simple, cheap, and needs no shadow copy of health data — which is why it is the default. But it has a known weakness: it assumes the source total for a window is stable enough that arithmetic over it is meaningful. Aggregates that shift under retroactive writes, or multiple data origins writing into the same window, could make it too blunt.
>
> **Permitted alternatives, alone or in combination:** record identities, origin metadata, time buckets, overlap fingerprints, aggregate reads, or a hybrid.
>
> The choice is settled at S-01 against the real API, and whichever mechanism wins must satisfy clauses 1–6 and pass scenario 13 unchanged. **The tests assert the contract, not the equation** — that is what lets the mechanism change without the guarantees moving.

#### Bounded

`windowStart` is clamped to `StepRescan.maxRescanWindow` (30 days) before now. If the watermark is older, the window is truncated and `truncated` is set. **Steps in the unreachable gap are recorded, never granted** — they cannot be distinguished from steps already counted, and inventing progress is worse than missing it.

This is what prevents the failure mode of silently discarding the cursor and granting the full history.

#### Interrupted recovery is safe to retry

Recovery reads state and computes a number; it mutates nothing until the ledger batch is committed. **The replacement token is persisted only after that commit.** If the process dies at any point before it, the watermark, `grantedSinceWatermark`, and the old cursor are all unchanged, so the next attempt recomputes exactly the same result. Combined with the ledger's batch-identity replay guard, recovery is idempotent.

#### On record identity

Health Connect exposes per-record UIDs, and deduplicating by UID inside the overlap window would be more precise than arithmetic.

It is not the *default* mechanism for one reason worth stating plainly: retaining identifiers indefinitely is unbounded storage, and it would leave the game holding a shadow copy of health data, which `GAME_BIBLE/HEALTH_INTEGRATION` forbids. Using identity **transiently, within a single recovery pass**, has no such problem and is entirely permitted — the constraint is on what the game *persists*, not on what it reads.

If S-01 finds that arithmetic alone cannot distinguish processed from unprocessed data, identity-within-a-pass is the first alternative to try.

The **contract** is expressed in `StepRescan` in `stride_core` and tested by reconciliation scenario 13. The mechanism behind it may change; the contract may not.

### 6.7 Testability — and now, cross-platform equivalence

The twelve scenarios (§6.7 of v1.1, unchanged) run against the mock provider in `dart test`, **on Windows, in under a second**.

New requirement: **the same twelve scenarios must pass against both real adapters.** One ledger, two sync primitives, identical results. Platform behavioral drift in step counting is risk X-06.

---

## 7. Data-driven content model *(implemented at F-02)*

`assets/content/v1/` — seven JSON files, each `{"schemaVersion": 1, "kind": …, "entries": [...]}`, with stable namespaced IDs (`item.oak_log`, `skill.woodcutting`).

**Identifiers are permanent and independent of display names.** Display names are a separate field that may change freely; nothing is ever looked up by one.

**The loader never guesses.** A schema version it does not support is a hard failure, not something to coerce — silently dropping a field this build has never heard of would produce a registry that looks fine and is quietly wrong.

**`ContentSource` takes text, not a directory.** The core cannot touch the file system, so reading files is the caller's job. The side benefit is that loading cannot depend on file enumeration order, because the loader never enumerates anything.

**All practical errors are collected in one pass**, each naming its source file, entry, field, explanation, and a suggested fix — including a "did you mean…?" for a near-miss reference. Stopping at the first error would make fixing a bundle a sequence of one-error rebuilds.

Validation is a **test failure**, never a runtime crash. Seventeen deliberately broken fixtures prove each rule fires; one test proves the validator stays silent on valid content, and one proves a single broken field does not cascade.

A **reachability validator** walks the progression graph from the granted loadout to Bronze, diagnosing tool-bootstrap deadlocks, missing ingredients, cycles with no entry point, resources gated behind their own output, and unobtainable location-entry requirements. It proves reachability, not balance: step costs, quantities, and skill levels are deliberately ignored.

### 7.1 Balance profiles — base content plus profile

**Production** ships and leaves everything at 100%, so base content is the single source of truth for real numbers. **`accelerated_qa`** compresses pacing for testing.

A profile may change only four percentages — step cost, XP, yield, enemy health. It has no vocabulary for adding an item, changing a reference, or rewiring progression, because those live in a layer it cannot reach. A test asserts that both profiles produce identical IDs, recipes, and travel graphs.

**The release safeguard is mechanical.** `ReleaseSafety` reads `dart.vm.product`, which the compiler sets and a build script cannot forget, and a release build selecting a profile that is not `releaseSafe` throws at load. Validation additionally rejects a production profile that is not release-safe, and any non-production profile that is.

Shipping accelerated pacing by accident would not crash, would not fail a test that was not looking for it, and would most likely be noticed by a player wondering why level 20 took four days.

---

## 8. Audio architecture

### 8.1 Semantic events, never file names *(unchanged)*

Systems emit `GameEvent`s → `audio_cues.json` maps to **asset IDs** → `AUDIO/AUDIO_ASSET_MANIFEST.md` maps IDs to files and provenance. No code or content references a filename.

### 8.2 Buses

Four logical buses — **ambience**, **action**, **UI**, **music** — with independent volume, a master mute, ducking for other apps' audio, and silent-switch respect. A walking game will often play over a podcast and must never fight the player's own audio.

No background audio session: the game does not play during the walk.

### 8.3 Package selection is deferred to the spike

Task **A-04b** validates: four buses, destination ambience crossfades, layered and varied gathering cues, combat ducking, interruption and resume, independent volume controls, and latency and memory **on a modest Android device**.

> **Do not introduce a custom native audio engine unless the spike demonstrates a concrete blocker** (`DECISIONS/0010`, owner instruction).

This is the one capability Flutter genuinely costs against AVAudioEngine. The spike exists to find the wall at Phase 3, where it is recoverable, rather than Phase 5, where it is not. Everything sits behind `AudioDirecting`, so a package swap touches one adapter.

### 8.4 Memory

30 MB total, provisional, confirmed against real assets at A-05. Short cues preloaded, ambience beds streamed.

### 8.5 Haptics

Same events, paired to sound, individually disableable, never the sole channel for information. Flutter's built-in haptics are coarse; custom patterns go through a platform channel — which would be true on any stack, since Core Haptics and Android's vibration API share nothing.

---

## 9. Test strategy

| Layer | Tool | Runs on | Scope |
|---|---|---|---|
| Simulation | `dart test` | **Windows** | Reconciliation, XP, gathering, crafting, combat, save round-trip. Seconds, no emulator. |
| Content | `dart test` | **Windows** | Schema validation, reference integrity, reachability, cue coverage, deferred vocabulary |
| Widgets | `flutter test` | **Windows** | Every screen, golden tests for the return summary |
| Health adapters | JUnit / XCTest | Windows (Kotlin) · macOS (Swift) | Against stubbed platform stores |
| Cross-adapter | integration | device | **The twelve scenarios against both real adapters** |
| Integration | `integration_test` | device/emulator | Full loop: ingest → allocate → gather → craft → equip → fight → save → reload |
| Manual | checklist | real devices | Real walking, real health data, feel |

### 9.1 Required suites — the actual gate *(unchanged)*

Coverage percentage is not a gate. These are:

1. The twelve reconciliation scenarios — **against the mock and both real adapters**
2. Save round-trip, interrupted write, corruption fallback, version rejection, ledger replay idempotence
3. XP curve boundaries and cap behavior for all five skills
4. Fresh-start-to-Bronze reachability
5. Combat determinism across 1,000 seeded encounters
6. Preparation-gate simulations under optimal play
7. Content validation, including deferred-vocabulary rejection
8. The `stepsConsumed` leak invariant
9. **`GameState` immutability**
10. **`stride_core` purity**

**Determinism is the through-line.** No test depends on wall-clock time, real health data, or unseeded randomness.

---

## 10. Continuous integration

Defined in `.github/workflows/ci.yml`. See `TECHNICAL/PROJECT_STRUCTURE.md`.

| Job | Runner | Purpose |
|---|---|---|
| `core` | Linux | Format, analyze, `dart test` on `stride_core`, purity check |
| `app-android` | Linux | `flutter analyze`, `flutter test`, Kotlin adapter unit tests, build APK |
| `ios` | **macOS** | `flutter build ios --no-codesign`, Swift adapter compilation and unit tests |

> **The iOS branch must not be allowed to remain uncompiled until the end** (`DECISIONS/0010`).

A build nobody runs still catches compile breaks, API changes, and Pigeon contract drift — which is most of the value, and the mitigation for risk X-03.

---

## 11. Performance and battery *(unchanged in substance)*

- **Reconciliation runs on launch and on foreground, not on a timer.** No polling loop.
- No background execution beyond opportunistic health delivery. No location services, no pedometer.
- Targets: cold launch under 2 s; two-week reconciliation under 500 ms; steady 60 fps; **idle CPU near zero while foregrounded and inactive** — a natural consequence of step-clocked progression, since nothing ticks.
- Battery and memory validated on a **modest Android device**, not a flagship.

---

## 12. Privacy, permissions, and distribution

- **Raw health data never leaves the device.** No cloud, no accounts, no analytics, no crash reporters, no third-party SDKs.
- Persisted health-derived state is three numbers plus an opaque anchor. No step history, no daily breakdown.
- **Android `allowBackup` disabled** — see §4.4.
- A visible **Disconnect and reset** clears the anchor *and* the changes token, the ledger, and all step counters, leaving gameplay progress intact.
- Permission rationale shown in-app before the system sheet, plain language, no re-prompting after a decline.
- **Step counts are never presented as targets.** No goal rings, no quotas, no "you walked less than usual." The simulation fixtures in `DECISIONS/0007` never surface in player-facing copy.

**Required before distribution** (`DECISIONS/0011`): a privacy policy, the Play Console Health Connect data-types declaration, and the Data safety form. Needed for Play *or* TestFlight, so not blocked on Mac access.

Staged: local APK → signed APK / GitHub release artifacts → Play internal testing; TestFlight when Mac access exists. No public store launch.

---

## 13. Future cloud and leaderboard compatibility *(unchanged)*

Nothing built now. Three cheap choices keep the door open: stable content IDs, a versioned save schema, and a serializable state object.

Recorded honestly: a leaderboard built on client-authoritative step data cannot be trusted against determined manipulation. If Milestone 04 pursues competitive comparison, that is a design problem needing its own decision — and it is now doubly true, since two platforms means two client implementations to trust.

---

## 14. Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| A-01 | Reconciliation bug corrupts progress | Critical | Ledger-before-snapshot, idempotent replay, twelve scenarios written before the feature, no-clawback rule |
| X-01 | A third-party health plugin creeps in | **High** | Prohibited by `DECISIONS/0010`. A dependency check fails the build. |
| X-06 | Platform drift in step counting | High | One ledger, two adapters; the twelve scenarios run against both |
| A-02 | Background delivery assumed reliable | High | Foreground backfill is the source of truth on both platforms |
| X-02 | Audio falls short of the pillar | High | A-04b spike at Phase 3, behind `AudioDirecting` |
| A-03 | Balance unknowable without real walking | High | All numbers in content; debug injector; three step fixtures |
| **F-03i** | **`GameState` immutability breaks silently** | **High** | `final` fields, unmodifiable views, an explicit test. New with Dart. |
| X-03 | iOS rots between rare builds | Medium | CI compiles iOS on every push from day one |
| A-05 | Core purity erodes under deadline | Medium | Automated check in CI and pre-commit |
| X-04 | Health Connect absent on older Android | Medium | Graceful degradation, same path as a denied permission |
| **S-04a** | **Android auto-backup duplicates the ledger** | **Medium** | `allowBackup=false`. New with Android. |
| A-06 | Snapshot save outgrows its design | Medium | `SaveStore` port; sqflite/drift escalation documented |
| A-07 | Content scope creep | Medium | Frozen scope; additions need a decision record |
| X-05 | Flutter framework risk | Low | The pure-Dart core has no Flutter dependency |

---

## 15. Recommendation

**Approve and execute the migration per `MIGRATION_EXECUTION_PLAN.md`.**

The architecture is the same architecture. What changed is that it can now be built on the machine the owner owns, and shipped to the friends who actually have Android phones.

Three things are accepted trade-offs rather than oversights:

1. **Audio control is less direct than native.** A-04b is the check, and the instruction not to build a custom native audio engine without a demonstrated blocker is the right constraint on it.
2. **Dart immutability is a discipline, not a guarantee.** Tracked as its own risk with its own test.
3. **iOS remains build-gated on macOS.** CI covers compilation; real HealthKit, haptics, signing, and TestFlight still need a Mac eventually.

The step-reconciliation ordering stands: **F-04 writes the twelve scenarios before S-02 implements reconciliation.** That was the plan's main defence against its worst risk under Swift, and it is unchanged — except that now those tests run on the developer's own machine.
