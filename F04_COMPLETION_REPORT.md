# F-04 Completion Report — Step Ledger and Reconciliation Domain Model

**Date:** 2026-08-02
**Task:** F-04 — platform-neutral step ledger and reconciliation
**Status:** ✅ **Complete and corrected.** 149 `stride_core` tests pass; 175 across the workspace.
**Review:** `DESIGN_REVIEW_F04.md` — approved with changes; **one item escalated**

> ### ⚠️ Amendment record — 2026-08-02, commit `8336774`
>
> **This report as originally approved described code that no longer exists, and made two claims that were false.** Read §14 before relying on anything below it.
>
> | Claim as approved | Corrected |
> |---|---|
> | 48-hour retention window | **7-day prototype default, 48-hour configurable minimum** enforced as a hard floor — the constructor throws below it |
> | The core derives the settled watermark from observed data | **The adapter asserts completeness** via `SyncResponse.completeThroughMillis`. The core never infers it. Absent an assertion, nothing compacts and the watermark does not move |
> | Commit ordering makes lost grants impossible | It closed **one** lost-grant path. **Three others were open**, two of which needed no crash at all — see §14 |
> | A2 (privacy) escalated and unanswered | **Answered** by owner ruling of 2026-08-02 |
>
> The F-05 sub-agent review that found the defects is in `F05_DESIGN_RECONCILIATION.md`.
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

**`grantedSlices`** maps `(origin, bucket)` → *steps already granted for that slice*, bounded to a **7-day prototype window with a 48-hour hard floor**, and compacted into `grantedBeforeWatermark` as slices age out — but **only once an adapter asserts how far its delivery is complete**. Absent that assertion the map grows rather than risk settling a bucket whose data has not arrived yet. It records **what the game credited**, not what the player walked — those diverge the moment a correction arrives. It is what makes replay, overlap, multi-origin, and bounded recovery safe through one rule instead of six special cases.

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
| 9 | A settled (pre-watermark) slice can never be granted again — **and a slice is settled only where an adapter asserted completeness**, never merely because newer data arrived | Skipped in reconciliation; tested. *Corrected: as originally written this permitted settling buckets that had never been observed, which is defect LG-2/LG-3 in §14* |
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

**A1 — The retention window: 7 days by default, 48 hours minimum.** *(Owner ruling, 2026-08-02. Originally 48 hours; the escalation is closed.)* A judgement, not a derivation. If corrections routinely arrive later than the window, a slice can be settled before its data lands — now **counted** by `lateDiscardedSlices` rather than silent, but still a real loss. **S-01 must measure actual correction latency, and must investigate every nonzero real-device occurrence of that counter.**

**A2 — `grantedSlices` narrows a Game Bible rule. ✅ ANSWERED — owner ruling, 2026-08-02.** Bounded persistence is approved as a **documented exception**. `grantedSlices` **is coarse recent reconciliation history and is described as such**; calling it "not a history" would be a word game. Persist only a pseudonymous origin key, a UTC bucket, the amount already granted, and minimum schema metadata. Never raw records, sub-bucket timestamps, device or source display names, workout categories, location, heart data, or native payloads. Retention 7 days default / 48 hours minimum, provisional until S-01. Local only: no telemetry, no plaintext diagnostic logging, no routine export, no automatic cloud-sync inclusion; Android backup exclusions stand. Full text: `TECHNICAL/STEP_LEDGER_PRIVACY.md`.

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

**149 `stride_core` tests** — 97 from F-01/F-02/F-03, **41 from F-04 as approved**, **6 command-classification** and **5 lost-grant regression** added by the 2026-08-02 corrections. Of the 41: 23 reconciliation scenarios (13 canonical, 7 recovery sub-cases, 4 provider-unavailability, malformed batch) and 18 invariant/property tests including five seeded 120-step sequences.

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
| ~~Interruption at every recovery boundary~~ | **Overstated.** 3 sub-cases of scenario 13, which is 3 cut points out of 5. `commitWithoutCheckpoint` *filtered* one event type rather than truncating, modelling no crash that can actually occur. Corrected to `commitUpTo<T>` using `takeWhile`; F-05's fault matrix covers the rest |
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

*(That recommendation stands as written and was accepted. §14 records what it missed.)*

---

## 14. Corrections to the approval record — 2026-08-02

**Approved:** commit `8336774`, owner ruling of 2026-08-02.

§13 said the finding worth escalating "is not a bug." That was wrong. There were three, and the F-05 Technical Critic sub-agent found them by **running** the code rather than reading it.

### 14.1 The three defects

All three shared one root cause: **the settled watermark was inferred by the core from whatever data it happened to be handed, rather than asserted by the adapter that knows what it delivered.** Anything arriving later but timestamped older than `newest − retention` was discarded with no event, no counter, and no recovery on retry — because the retry consults `grantedFor(key)`, which by then reports a slice as settled that was never granted.

| | Defect | Trigger | Cost |
|---|---|---|---|
| **LG-2** | Newest-first pagination settles the watermark from the newest page's own newest hour; the older page is then already behind it | **No crash.** HealthKit anchored queries and Health Connect change tokens both page, and nothing in the adapter contract forbade newest-first | **55,200 of 64,800 steps destroyed** in a 30-day cold-launch backfill |
| **LG-3** | The compaction horizon was a global maximum across all origins. Origin separated the *keys* but not the *horizon* | **No crash.** A watch reconnects after being offline while the phone kept syncing | The watch's entire backlog, silently |
| **W-1** | `watermarkFor` recomputed the horizon independently of `_compact`, so the watermark advanced past slices compaction had correctly declined to drop | Structural — present in every sync | The mechanism that made LG-2 and LG-3 reachable |

**LG-3 is the one that matters most.** Its failure mode is *the player went away, so their steps did not count* — a direct violation of the Kernel's no-punishment-for-absence rule, shipped inside the system built to honour it.

A fourth, **LG-1**, was identified and is *not* a defect today: `StepObservationReconciled` (which records a slice as granted) and `StepsGranted` (which credits the player) are two different events. In-memory they commit in one synchronous `applyAll`, so the gap is unreachable. **F-05 exists specifically to put a disk between them**, which is why the journal record is all-or-nothing per batch.

### 14.2 What changed

| Change | File |
|---|---|
| `SyncResponse.completeThroughMillis` — the adapter's completeness assertion, on all three data-carrying response types. The core never infers | `steps/sync_batch.dart` |
| Compaction happens **only** under an assertion. Horizon = `min(newest − retention, completeThrough)` | `steps/reconciliation.dart` |
| The persisted watermark is **exactly** the horizon compaction used, carried out of the reconciler. `watermarkFor` deleted | `steps/reconciliation.dart`, `engine/game_engine.dart` |
| `compactedGranted` computed where the merged pre-compaction map is in hand. `compactedGrantedBetween` deleted — it read the *previous* slices and folded a stale amount for any slice both raised and compacted in one batch | `steps/reconciliation.dart` |
| **`lateDiscardedSlices`** — counts observations arriving after their bucket was compacted, through the event into the ledger | `steps/step_ledger.dart`, `engine/events.dart`, `engine/event_reducer.dart` |
| `commitUpTo<T>` truncates with `takeWhile` instead of filtering one event type out of the middle | `test/step_support.dart` |
| Retention: 7-day default, 48-hour floor enforced by a throwing constructor | `steps/reconciliation.dart` |

### 14.3 The `lateDiscardedSlices` diagnostic

The design still permits one loss: an observation arriving after its bucket was compacted cannot be granted, because the record proving whether it was already credited is gone. That is a defensible trade — bounded storage against a rare late arrival — **but only if it is measurable.**

Per the owner's ruling it increments **only** under that precisely documented condition, is test-visible, produces a typed diagnostic, appears only in redacted opt-in diagnostics, and **never carries slice details or source names**. **S-01 must investigate every nonzero real-device occurrence.**

A loss you can count is a bug. A loss you cannot count is a haunting.

### 14.4 The procedural lesson

Every F-04 test asserted that the arithmetic was right. None asserted that **data the arithmetic never saw would still be credited**. Thirteen scenarios, eighteen invariant tests, five seeded sequences, and a five-role review all passed over a defect that destroys 85% of a backfill — because they all fed the reconciler complete data and checked what it did with it.

The specific habit to carry into F-05: a test that supplies well-formed input and checks the output cannot find a bug whose signature is *input that never arrives*. F-05's fault matrix must include cases where the data is late, partial, out of order, or absent — not only where it is corrupt.
