# F-04 Completion Report — Step Ledger and Reconciliation Domain Model

**Date:** 2026-08-02
**Task:** F-04 — platform-neutral step ledger and reconciliation
**Status:** ✅ **Complete.** 138 `stride_core` tests pass; 147 across the workspace.
**Review:** `DESIGN_REVIEW_F04.md` — approved with changes; **one item escalated**
**Scope held:** no HealthKit, Health Connect, permissions, background work, storage, serialization, UI, or gameplay

> ⚠️ **One decision needs the owner before F-05.** The persisted shape narrows a Game Bible rule. See §9 and `TECHNICAL/STEP_LEDGER_PRIVACY.md` §5.

---

## 1. Final terminology

| Term | Meaning | Monotonic |
|---|---|---|
| **`totalObserved`** | What the source currently says it recorded | **No** — a correction or deletion lowers it |
| **`totalGranted`** | What the game has credited the player | **Yes** — never decreases |
| **`totalSpent`** | What has been committed to activities | Yes |
| **`banked`** | Earned and unspent — derived | — |
| **`checkpoint`** | Cursor, watermark, sync count | — |
| **`sourceState`** | How the provider last presented itself | — |
| **`recovery`** | Whether a bounded recovery is in flight | — |

`banked = totalGranted − totalSpent`, and `0 ≤ totalSpent ≤ totalGranted`. Both asserted on every construction; a violating ledger throws.

**`totalGranted` is never derived from the latest observed total.** That separation is the whole safety argument: if it were, a health correction would silently revoke progress the player already earned and possibly spent.

The F-03 names (`granted`/`allocated`) are gone, as instructed.

---

## 2. Persisted vs. transient

Full detail in `TECHNICAL/STEP_LEDGER_PRIVACY.md`. In summary:

**Transient** — raw samples, record UIDs, precise timestamps, the `SyncResponse` itself. Aggregated by the adapter before reaching the core; discarded when reconciliation returns. **No raw health history ever enters `stride_core`.**

**Persisted** — four counters, an opaque cursor, a watermark, a sync count, a recovery state, a source state, two diagnostic counters, and `grantedSlices`.

**`grantedSlices`** maps `(origin, bucket)` → *steps already granted for that slice*, bounded to a 48-hour window and compacted into `grantedBeforeWatermark` as slices age out. It records **what the game credited**, not what the player walked — those diverge the moment a correction arrives. It is what makes replay, overlap, multi-origin, and bounded recovery safe through one rule instead of six special cases.

---

## 3. Every invariant

| # | Invariant | Enforced by |
|---|---|---|
| 1 | `totalGranted` never decreases | No code path lowers it; asserted across five generated sequences at every step |
| 2 | `newlyGranted >= 0` | `max(0, …)` at the slice level; asserted on the accepted outcome and on every generated step |
| 3 | Replaying identical input grants zero, leaves the ledger otherwise unchanged, and records no duplicate | Scenario 3, plus a ten-fold replay test |
| 4 | The cursor is authorized strictly after the ledger commits | Event order: checkpoint is always last. Tested by replaying a partial commit |
| 5 | Spending is separate from ingestion | `AllocateSteps` touches only `totalSpent`; no activity logic exists |
| 6 | `banked = totalGranted − totalSpent` | Derived, never stored; asserted at every generated step |
| 7 | `0 ≤ totalSpent ≤ totalGranted` | Constructor throws; spending refuses rather than clamping |
| 8 | `totalObserved ≥ 0` | Clamped at zero; asserted |
| 9 | A settled (pre-watermark) slice can never be granted again | Skipped in reconciliation; tested |
| 10 | Compaction never loses granted credit | Dropped amounts fold into `grantedBeforeWatermark`; tested over six days |
| 11 | No day boundaries or timezone arithmetic exist | Buckets are opaque intervals; no calendar type in the package |
| 12 | No native type enters `stride_core` | Purity guard, 22 files |
| 13 | No clock, randomness, locale, or platform read | Static source scan from F-03, still green |

---

## 4. The exact thirteen scenarios

Written as black-box tests **before** the reconciler existed. Every assertion is on an observable outcome — newly granted, final observed, final granted, checkpoint disposition, recovery state, retry safety. **None asserts the arithmetic.**

| # | Scenario | Asserted outcome |
|---|---|---|
| 1 | First synchronization | 2000 granted from empty; cursor authorized |
| 2 | Normal incremental | Only the new slice credited |
| 3 | Identical batch replay | **0 granted**; ledger otherwise identical |
| 4 | Overlapping batches | Only the genuinely new hour credited |
| 5 | Delayed records | A late slice is credited when it arrives |
| 6 | Upward correction | Only the increase credited — 300, not 800 |
| 7 | Downward correction | Observed falls to 400, granted stays 1000, banked stays 1000, **no `StepsRemoved` event**, and restating the original does not re-grant |
| 8 | Deletion | Observed falls, granted preserved |
| 9 | Interruption before ledger commit | Original state untouched; retry produces the same answer |
| 10 | Ledger committed, checkpoint interrupted | Grant persists, **cursor stays old**, replay grants 0 |
| 11 | Multiple origins | Counted separately; replay of one grants 0; correcting one does not disturb the other |
| 12 | Empty / no-change | 0 granted, cursor still advances |
| 13 | Expired token with bounded recovery | Six sub-tests — see below |

### Scenario 13 in detail

| Sub-case | Asserted |
|---|---|
| Recovery grants only what was uncredited | 300, not 1300 |
| The ledger is never reset | Granted stays 900 when a rescan reports 100 |
| No accidental full-history grant | A full 12-hour rescan grants 0 |
| A truncated window records the gap | Gap counted; only real content credited |
| Interrupted before commit | Retry produces the same result |
| **Interrupted mid-flight** | Recovery recorded as started-and-unfinished; retry completes cleanly |
| Interrupted after grant, before checkpoint | Grant persists, cursor stays old, replay grants 0 |

**Mapping note:** the canonical list is preserved exactly. Scenario 13 was expanded from one test to seven, because "bounded authoritative recovery" has several distinguishable failure modes and one assertion could not have covered them. No scenario was renamed, merged, or dropped.

---

## 5. Selected prototype strategy

> **Absolute observations keyed by `(origin, bucket)`, with bounded per-slice granted amounts.**

An observation is an **absolute** figure — "the source now believes this slice contains 400 steps" — not a delta. Reconciling one is:

```text
alreadyGranted  = ledger.grantedFor(key)
newlyGranted   += max(0, observed − alreadyGranted)
grantedFor(key) = max(alreadyGranted, observed)
```

Every awkward case falls out without a branch:

| Case | Why |
|---|---|
| Replay | `observed == alreadyGranted` → delta zero |
| Overlap | Same key, same slot |
| Delayed record | New key, granted once |
| Upward correction | Only the increase |
| Downward correction | `max(0, …)` grants nothing; `max(alreadyGranted, …)` keeps the credit |
| Deletion | Observed → 0, granted unchanged |
| Multiple origins | Different keys, never merged |
| **Recovery** | An authoritative rescan is **the same arithmetic** over a bounded window |

That last row is why it was chosen. Recovery is not a special path with its own rules to get wrong — it is ordinary reconciliation over a bounded set of slices.

---

## 6. Rejected alternatives

**Watermark and overlap arithmetic** — the original hypothesis, `max(0, windowTotal − grantedSinceWatermark)`. Stores the least. Rejected because it assumes a window total stable enough for arithmetic over it to mean something: it cannot distinguish a restatement from a new observation, cannot separate two devices, and cannot tell which part of a rescan window was already granted. Four of the required scenarios become approximations.

**Persistent record identity** — dedupe by platform record UID. Most precise. Rejected because retaining identifiers indefinitely is unbounded storage and would leave the game holding a shadow copy of health data. *Transient* identity within a single pass remains available to an adapter and is not forbidden.

**Per-origin aggregates only** — totals per device, no time dimension. Handles multi-device; still cannot distinguish a restatement from new data within one device.

**Time-bucket fingerprints without origin** — handles replay and correction; merges two devices into one bucket, so a genuine second device is read as a correction and silently under-granted. Rejected: it fails quietly, which is the worst way to fail.

**Hybrid (chosen)** — per-slice granted amounts *bounded* by a retention window, compacted into a scalar behind a watermark. Keeps the precision where corrections actually arrive and the scalar economy everywhere else.

---

## 7. Event architecture

| Event | Emitted |
|---|---|
| `StepSourceStateChanged` | When availability changes — and only then, so a repeated failure does not flood the stream |
| `StepRecoveryStarted` | Before reconciling, on recovery only |
| `StepObservationReconciled` | Observed totals, slice records, watermark, correction count |
| `StepsGranted` | Only when something was credited |
| `StepRecoveryCompleted` | After the grant, on recovery only |
| `StepCheckpointAuthorized` | **Always last** |

**There is no `StepsRemoved` event.** A health correction changes what the source says, never what the player has. Inventing one would invite a listener to undo a grant — and would eventually put "you lost 600 steps" on a screen.

Observing and granting are separate events on purpose: a batch can update the source's view while crediting nothing, and anything reacting to *progress* — audio, the return summary — should hear only `StepsGranted`.

All state changes pass through the canonical reducer.

---

## 8. Typed outcomes

| Outcome | Meaning |
|---|---|
| `ReconciliationAccepted` | Reconciled; `newlyGranted` may be 0 |
| `ReconciliationRefused(serviceUnavailable, retryable)` | No health service |
| `ReconciliationRefused(permissionUnavailable, retryable)` | Not readable |
| `ReconciliationRefused(transientFailure, retryable)` | Read failed |
| `ReconciliationRefused(malformedBatch, not retryable)` | Adapter fault → engine `malformed_sync_batch` rejection |

Nothing throws for an expected condition. A refused sync leaves the ledger untouched and **does not advance the cursor** — tested for all three unavailability reasons.

---

## 9. ⚠️ Assumptions awaiting real-API validation

**A1 — The 48-hour retention window.** *(Escalated: `DESIGN_REVIEW_F04.md` CR-1, privacy doc §5.)* A judgement, not a derivation. If corrections routinely arrive later, steps are silently under-granted — the quietest possible failure, and no test here can catch it because no test here has real health data. **S-01 must measure actual correction latency.**

**A2 — `grantedSlices` narrows a Game Bible rule.** `GAME_BIBLE/HEALTH_INTEGRATION` says persist *"ingested total, consumed total, sync anchor"* and **"never a step history"**. Per-device, per-hour granted amounts for 48 hours is more than that list. It is derived, bounded, and compacted — and calling it "not a history" would be a word game. **Three options with a recommendation are in the privacy document §5. This should be answered before F-05, because F-05 serializes whatever shape is settled.**

**A3 — Bucket granularity is the adapter's choice.** The core treats buckets as opaque. If an adapter emits one bucket per day, precision drops; per minute, `grantedSlices` grows. S-01 and S-01b must pick and justify a granularity.

**A4 — Origin stability.** Assumes a platform's origin identifier is stable across app restarts and OS updates. If Health Connect reissues them, a re-issued origin looks like a new device and re-grants its window.

**A5 — Health Connect token expiry frequency is unknown.** The recovery path is proven correct in the model; how often it fires in practice is not.

**A6 — Deletion is reported as a zero observation.** If a platform instead simply omits a deleted slice, the adapter must synthesize the zero — otherwise a deletion is invisible and observed drifts above reality.

---

## 10. Test count and exact results

```text
=== Core purity ===        core purity: OK (22 Dart files, 7 forbidden imports)
=== Dependency policy ===  dependency policy: OK (4 pubspec files)
=== Format ===             clean
=== stride_core ===        No issues found!   00:00 +138: All tests passed!
=== Workspace analyze ===  No issues found!
=== Flutter tests ===      00:00 +2: All tests passed!
=== stride_health tests === 00:00 +7: All tests passed!
All checks passed.
```

**138 `stride_core` tests** — 97 from F-01/F-02/F-03, **41 new**: 23 reconciliation scenarios (13 canonical, 7 recovery sub-cases, 4 provider-unavailability, malformed batch) and 18 invariant/property tests including five seeded 120-step sequences.

Runtime under one second, on Windows, with no emulator and no Mac.

### Required testing coverage

| Required | Covered |
|---|---|
| `totalGranted` never decreases | Property test, every step of 5 sequences |
| `newlyGranted` never negative | Property test + scenario assertions |
| Spent cannot exceed granted | 3 tests, including constructor rejection |
| Banked derivation | Asserted at every generated step |
| Repeated batches idempotent | Scenario 3 + ten-fold replay |
| Old snapshots immutable | 2 tests |
| Rejected/unavailable sync does not mutate | 3 unavailability reasons + malformed |
| Cursor not authorized before commit | Scenario 10 + partial-commit replay |
| Interruption at every recovery boundary | 3 sub-cases of scenario 13 |
| Multiple origins do not double-grant | Scenario 11 |
| Downward corrections | Scenarios 7, 8, 13b |
| No native types in `stride_core` | Purity guard |
| Purity and determinism guards green | Both |

---

## 11. Unresolved risks

| # | Risk | Severity |
|---|---|---|
| R1 | Retention window too short for real correction latency | **High** — silent under-grant. A1. |
| R2 | Privacy narrowing adopted without ratification | **High** — A2, escalated |
| R3 | Origin identifiers not stable across reinstalls | Medium — would re-grant a window |
| R4 | Adapter omits rather than zeroes deletions | Medium — observed drifts above reality |
| R5 | `totalSpent` records no destination | Low — by design until activities exist |
| R6 | `grantedSlices` growth under a very fine bucket granularity | Low — bounded by window, but the constant assumes hourly |

---

## 12. Recommended F-05 scope

> ### F-05 — Save, ledger persistence, and crash recovery.

The natural next task, and the one the ledger has been shaped for.

### In scope

- `SaveEnvelope` with `schemaVersion`, `contentPackVersion`, and the state
- **Atomic write**: serialize → temp → rename, with one rolling backup used when the primary fails to decode
- `GameState` ↔ JSON round-trip, exact
- The **append-only step ledger file**: batch appended and flushed *before* the snapshot, so a crash mid-write can neither double-count nor lose a batch
- Idempotent replay on launch — a ledger batch newer than the snapshot is replayed; a matching one is skipped
- The version-1 migration hook, shipping as a no-op with a test proving a version-0 fixture is rejected cleanly
- Validation of a state arriving from outside, including the `eventSequence` consistency issue left open by F-03

### Out of scope

Health ingestion, cloud sync, UI, activities, and the platform file adapter — `SaveStore` stays a port; the app implements it.

### Recommended acceptance criteria

1. Save → reload → state is value-identical, including the ledger and its slices
2. A write interrupted mid-flight leaves the previous save loadable
3. A corrupt primary falls back to the backup
4. A version-0 fixture is rejected clearly, not crashed on
5. **Ledger replay after a simulated crash between ledger-write and snapshot-write yields identical state** — the F-04 commit ordering carried into persistence
6. An externally supplied state with an inconsistent `eventSequence` is rejected
7. The save contains **no raw health data** — asserted by inspecting the serialized form
8. `stride_core` purity holds: `SaveStore` is a port, `dart:io` stays out
9. All four CI jobs green

**Answer A2 first.** F-05 serializes the persisted shape, and settling privacy after the save format exists is the expensive order.

---

## 13. Recommendation

**Approve F-04, and answer the escalated privacy question before F-05.**

The model does what it was asked to. The thirteen scenarios were written first, they assert the contract rather than the arithmetic, and the mechanism could change tomorrow without rewriting one of them.

The finding I would put in front of the owner is not a bug — it is that the safest reconciler the studio could build persists slightly more than the Game Bible said it would, and that trade should be made deliberately rather than discovered later in a diff.
