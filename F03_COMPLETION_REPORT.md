# F-03 Completion Report — Immutable State, Typed Commands and Events, Deterministic Engine

**Date:** 2026-08-02
**Task:** F-03 — the platform-neutral runtime spine
**Status:** ✅ **Complete.** 97 `stride_core` tests pass; 106 across the workspace.
**Review:** `DESIGN_REVIEW_F03.md` — approved with changes, six applied
**Scope held:** no gathering, crafting, combat, travel costs, health ingestion, persistence, UI, audio, or online systems

---

## 1. Files created

`packages/stride_core/lib/src/engine/` — 7 files:

| File | Purpose |
|---|---|
| `state_version.dart` | `StateVersion`, unsupported-version exception, migration extension point |
| `game_state.dart` | `GameState` and six nested models, with the freeze helpers |
| `commands.dart` | Six commands — requests that may be refused |
| `events.dart` | Seven events — facts that cannot fail to apply |
| `rejection.dart` | `RejectionCode`, `CommandRejection`, sealed `EngineResult` |
| `event_reducer.dart` | The canonical reducer — the only writer |
| `game_engine.dart` | Validation, entry point, new-game factory |

Tests: `engine_test.dart` (37), `engine_purity_test.dart` (3).

---

## 2. GameState and nested models

| Model | Holds |
|---|---|
| `GameState` | State version, profile ID, content pack version, and the six below, plus `eventSequence` |
| `PlayerState` | Level, experience |
| `Inventory` | Counts keyed by content ID |
| `Equipment` | Item per slot |
| `SkillProgress` | **Experience** per skill — level is derived from the content curve, never stored |
| `WorldState` | Current location, unlocked locations |
| `StepState` | `granted`, `allocated`; `banked` derived |

Three decisions worth naming:

**Experience is stored; level is not.** A stored level could disagree with the curve after a content change. Deriving it means content stays authoritative.

**`granted` and `allocated` only ever increase.** Monotonicity is the property the whole reconciliation design will rest on (F-04), and starting with it costs nothing.

**`banked` is derived, not stored.** Two numbers that must agree are one number and a bug waiting to happen.

---

## 3. Deep immutability

The requirement was explicit that `final` alone does not satisfy it, and it does not. In Dart a `final Map` is a reference that cannot be *reassigned*; its contents stay fully mutable, and it is still the caller's object.

Two failures follow, both silent:

- a caller who keeps the map they built the state from can edit the state afterwards
- a caller who reads a collection off a snapshot can edit it in place, changing the engine and every other snapshot sharing that reference

So every collection is **copied on construction and exposed unmodifiable**. The copy severs the caller's reference; the wrapper turns a mutation attempt into an immediate `UnsupportedError` instead of a corrupted save three sessions later.

### Proven in all three directions

| Test | Proves |
|---|---|
| `mutating a returned collection throws` | Every collection on a snapshot rejects mutation |
| `a snapshot cannot be mutated to change the engine` | Four attack routes, all throw; engine signature unchanged |
| `an earlier snapshot is unchanged by later commands` | Earlier snapshots frozen in time |
| `a later snapshot is unaffected by mutating an earlier one` | Snapshots do not share mutable structure |
| `mutating the map a state was built from does not change the state` | Construction copies |

---

## 4. Commands, events, and rejections

**Commands (6):** `GrantSyntheticSteps`, `AllocateSteps`, `EquipItem`, `UnequipItem`, `UnlockLocation`, `EnterLocation`.

**Events (7):** `GameStarted`, `SyntheticStepsGranted`, `StepsAllocated`, `ItemEquipped`, `ItemUnequipped`, `LocationUnlocked`, `LocationEntered`.

**Rejection codes (11):** `insufficient_steps`, `invalid_amount`, `unknown_item`, `item_not_owned`, `invalid_equipment_slot`, `slot_empty`, `unknown_location`, `location_locked`, `location_already_unlocked`, `already_at_location`, `content_not_loaded`.

Wire strings are contract. A code may be added, never renamed — a renamed code silently stops matching everywhere it was handled.

### Two behaviours worth explaining

**Swapping equipment emits two events.** A listener that only understood `ItemEquipped` would never learn the old item came off.

**Re-equipping what is already worn is accepted with zero events.** Idempotent without inventing a fact. A fabricated `ItemEquipped` for something that did not change would corrupt replay and fire audio for a non-event.

---

## 5. Engine flow and determinism

Validation reads; only the reducer writes. There is no path where a command handler changes something itself.

**The `GrantSyntheticSteps` back door.** F-03 cannot test a ledger it has no way to fill, so a synthetic-step command exists. Two properties keep it honest: it goes through the same validation and reducer as everything else, so it cannot behave differently from the real path; and its `reason` is mandatory and recorded on the event, so a state built from synthetic steps can never be mistaken for one built from real walking.

### Determinism, proven twice

**Behaviourally** — the same script produces identical events, rejections, and final state across repeated runs, including across two million iterations of real elapsed time between them.

**Statically** — `engine_purity_test.dart` scans all of `lib/` and rejects `DateTime.now`, `DateTime.timestamp`, `Stopwatch(`, `Random(`, `Zone.current`, `Platform.`, `Intl`, `timeZoneName`, `timeZoneOffset`, and `localeName`. It strips comments and string literals first, self-checks that the detector still works, and asserts the scan covers the engine files rather than passing vacuously.

The static check exists because a behavioural test cannot distinguish deterministic from lucky: a clock read landing in the same millisecond would pass. This was QA review finding QA-2.

**No wall-clock progression exists.** Steps advance the game; elapsed time does not (`DECISIONS/0001`).

---

## 6. State version

`StateVersion.current = 1`. New states use it. An unsupported version throws `UnsupportedStateVersionException` with a message naming the version found, the supported range, and which direction the mismatch runs.

A throw rather than a rejection, deliberately: rejections are for gameplay a player attempted and cannot have; an unreadable state version is a programming or deployment fault, and continuing would mean operating on a structure whose meaning is unknown.

`StateVersion.migrationRequired()` is the extension point. It returns false for everything today, and the test says so plainly rather than implying coverage that has no subject.

**No migration or persistence framework was built.** That is F-05.

---

## 7. Minimal behavioural slice

All seven required behaviours, each with tests:

1. ✅ Deterministic new game — two calls produce identical states
2. ✅ Starting equipment and location granted
3. ✅ Synthetic banked steps via an explicit system command
4. ✅ Equip and unequip owned starting items
5. ✅ Equipping an unowned item rejected as `item_not_owned`
6. ✅ Entering a locked location rejected as `location_locked`
7. ✅ Unlock then enter, through accepted events

---

## 8. Test count and exact results

```text
=== Core purity ===        core purity: OK (19 Dart files, 7 forbidden imports)
=== Dependency policy ===  dependency policy: OK (4 pubspec files)
=== Format ===             clean
=== stride_core ===        No issues found!   00:00 +97: All tests passed!
=== Workspace analyze ===  No issues found!
=== Flutter tests ===      00:00 +2: All tests passed!
=== stride_health tests === 00:00 +7: All tests passed!
All checks passed.
```

**97 `stride_core` tests** — 57 from F-01/F-02, 40 new.

### The fifteen required areas

| # | Required | Covered by |
|---|---|---|
| 1 | Deterministic new-game creation | `new game is deterministic` |
| 2 | Starting IDs resolve in registry | `every starting ID resolves in the registry` |
| 3 | Deep state immutability | 5 tests |
| 4 | Earlier snapshots unchanged | `an earlier snapshot is unchanged by later commands` |
| 5 | Deterministic command processing | `the same script produces the same events…` |
| 6 | Rejected commands do not alter state | `a rejected command leaves the state completely unchanged` |
| 7 | Changes pass through the canonical reducer | `replaying the same events produces the same final state` |
| 8 | Unsupported state version fails clearly | `an unsupported version fails clearly` |
| 9 | Stable IDs stored, not definitions | `inventory, equipment, skills, and world hold content IDs` |
| 10 | `stride_core` pure Dart | `core_purity_test.dart` + `Scripts/check-core-purity.sh` |
| 11 | No wall-clock reads in engine paths | `engine_purity_test.dart` (static) + behavioural |
| 12 | Event sequence monotonic | `is monotonic and gap-free across a session` |
| 13 | Invalid IDs return typed rejections | `an invalid ID is rejected, not thrown` |
| 14 | Replay produces the same final state | 2 reducer tests |
| 15 | Both profiles preserve structure and identity | 3 tests |

---

## 9. Unresolved questions

**Q1 — `GameEngine` is a mutable holder.** State is immutable; the engine holds the latest one. Right call — a purely functional engine would push sequence bookkeeping onto every caller — but it is not isolate-safe. The architecture plan already assumes single-isolate use; now stated rather than implied.

**Q2 — `copyWith(eventSequence:)` can build an inconsistent state.** Legitimate for the replay tests, and also a public route to a state whose sequence disagrees with its history. Real protection belongs with F-05, where a state arrives from outside and must be checked.

**Q3 — `StepState` will need renaming at F-04.** Reconciliation distinguishes `ingested` (what the health source reported) from `granted` (what the game accepted); after a correction those differ. The F-03 names are honest about what exists today. F-04 extends rather than renames.

**Q4 — `UnlockLocation` should stop being a player command.** In the real game an unlock is a consequence — of arriving, of crafting a gate's key item. Leaving it as a command would eventually let the UI unlock the world. Documented as temporary on the command itself.

**Q5 — `contentPackVersion` is hardcoded to 1.** The registry does not expose the schema version it loaded. Trivial to wire when something needs it; noted so it is not mistaken for validated.

---

## 10. Recommended F-04

> ### F-04 — The platform-neutral step ledger and reconciliation domain model, and the thirteen scenarios.

As the owner recommended, and as the task breakdown has always had it. Now unblocked: F-03 gives it a state to extend and a reducer to apply through.

**The ordering rule stands: the thirteen scenarios are written before reconciliation exists.** This is the project's primary defence against risk A-01, and it is why F-04 comes before S-02 rather than alongside it.

### In scope

- Extend `StepState` with the reconciliation counters — ingested, consumed, discrepancy debt, watermark, opaque cursor
- The ledger rules: monotonic counters, **no day boundaries, no timezone arithmetic**, no clawback
- The bounded authoritative rescan contract for cursor invalidation, satisfying all six clauses of `DECISIONS/0008`'s recovery rule
- **All thirteen scenarios as failing tests**, written against the contract rather than the arithmetic — the mechanism is still a hypothesis (`ARCHITECTURE_IMPLEMENTATION_PLAN.md` §6.6)
- `MockStepProvider` already exists in `stride_health`; F-04 wires it to the domain model

### Out of scope

Real HealthKit or Health Connect (S-01, S-01b), persistence (F-05), activities to spend steps on, and any UI.

### Recommended acceptance criteria

1. All thirteen scenarios exist and **fail for the right reason** before reconciliation is implemented
2. No scenario touches real health data, the file system, or the wall clock
3. The suite runs in under a second
4. `stepsIngested` and `stepsConsumed` never decrease — asserted as an invariant on every mutation
5. **No day-boundary or timezone arithmetic exists** anywhere in the reconciliation path, verified by inspection and by the existing static scan
6. No correction, deletion, or health edit can reduce progress already granted
7. Scenario 13 asserts all seven clauses of the recovery contract, **not the arithmetic**
8. Reconciliation is platform-agnostic — it consumes `StepProvider` results and never branches on platform
9. All four CI jobs stay green

---

## 11. Recommendation

**Approve F-03 and proceed to F-04.**

The spine does what it was asked to and nothing more. The two findings I would highlight are the ones review caught rather than the code I wrote: a test named for `invalid_equipment_slot` that never reached the slot check, and determinism proven only behaviourally when a behavioural test cannot tell deterministic from lucky. Both are now fixed, and the second produced a standing guard that will keep working long after this task.
