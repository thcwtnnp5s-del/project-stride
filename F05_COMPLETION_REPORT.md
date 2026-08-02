# F-05 Completion Report — Local Save, Ledger Persistence, Crash Recovery

**Date:** 2026-08-02
**Task:** F-05 — save system, step-ledger persistence, transactional commit, crash recovery
**Authority:** Owner rulings of 2026-08-02 — four design rulings, cursor authority, completeness contract, origin privacy, late data
**Decision record:** `DECISIONS/0012_SAVE_FORMAT.md`
**Status:** ✅ **Complete.** 247 `stride_core` tests, 266 across the workspace. Full verification green, twice from fresh storage.

---

## 1. Sub-agent assignments and findings

Four focused sub-agents, spawned against **compiling code rather than a sketch**, so their findings are about what exists rather than what was intended.

| Agent | Scope | Outcome |
|---|---|---|
| **Storage Protocol** | Two-slot snapshots, validation, CAS, single-writer | Implemented by the orchestrator directly. The protocol *is* the crash-safety argument, and splitting its authorship from its invariants invites a second implementation that disagrees about ordering |
| **Fault Matrix** | Every crash boundary, concurrency, divergent slots, journal recovery | **1 real bug** — see §1.1. 18 tests |
| **Migration** | Version decoders, prior-version fixture, invariant revalidation | **1 real hazard, outside Dart** — see §1.3. 34 tests |
| **Privacy Auditor** | Serialized fields, pseudonymization boundary, retention, redaction | **No leak found; one open hole in the ruling** — see §1.4. 23 tests |

### 1.1 Fault Matrix — a durable commit that reported failure

In `_commitOnce`, every operation past the commit point was guarded except the last:

```dart
if (snapshotDurable) await _compact();   // unguarded
```

Compaction performs real I/O. Any failure propagated out through `commit()`, so the caller's future completed with an **error** rather than `CommitDurable` — directly contradicting the comment three lines above it.

The consequence is worse than a spurious error. The contract says a caller that does not see `CommitDurable` must assume the batch did not commit and **must not release the step cursor**. So an unwritable sidecar — full storage, a locked file, iOS data protection while the device is locked during a background sync — would throw on the step-sync path and freeze the cursor on a transaction that was in fact durable.

F-04's idempotence keeps the totals correct throughout, which is precisely why this would never surface as wrong numbers. It would surface as **step ingestion quietly ceasing to make progress**, with a crash log nobody connects to the save layer.

Fixed by guarding the call. The public `compact()` still surfaces its errors; only post-commit hygiene is swallowed.

**Why the eleven existing protocol tests missed it:** none of them faulted the journal *after* the commit point. Every one either faulted before it or not at all.

### 1.2 A test that proves the suite is load-bearing

Step reconciliation grants `max(0, observed − alreadyGranted)`. A loader that replays every journal record unconditionally, forever, produces the **correct `totalGranted`** in every crash test. So a naive suite proves nothing.

Every committed batch therefore carries a non-idempotent effect — `GrantSyntheticSteps(291)` plus `AllocateSteps(137)` as one transaction — and every post-restart assertion checks `totalSpent` alongside `totalGranted`. A double replay reads 274; a dropped replay reads 0.

Verified by mutating the loader to replay unconditionally: **13 of 18 tests failed.** The mutation was reverted.


### 1.3 Migration — a hazard in git rather than in Dart

`core.autocrlf=true` on the development machine, and no `.gitattributes`.

The save frame separator is a single `0x0A`. Git would have rewritten it to `0x0D 0x0A` on checkout — changing the payload length, breaking the CRC-32C, and making a fixture that is supposed to be immutable **differ per clone**.

It would have presented as a mysterious integrity mismatch on a second machine, or in CI, rather than as a checkout problem. That is the kind of failure that costs a day and teaches nothing.

Closed with a scoped `.gitattributes` marking `*.save` binary. The migration suite now asserts the fixture's byte length and the absence of any `0x0D`, with a reason string naming the cause, so a regression diagnoses itself. I verified `git check-attr` reports `binary: set` rather than taking the report on trust.

**Fixture policy, recorded so it is not renegotiated:** `v1_baseline.save` is frozen forever. When `StateVersion.current` becomes 2, a `_V2StateDecoder` is added, the v1 fixture and decoder are left untouched, v1's round-trip test becomes decode-only, and a new frozen `v2_baseline.save` carries the round-trip property forward. Never chain v1→v2→v3. **Regenerating the fixture is never the fix.**

### 1.4 Privacy — no leak, and one genuinely open hole

The auditor found **no value on disk that the ruling forbids**. Slices are structural `{o,s,e,g}`; the origin type cannot hold a name; the decoder's rejection carries a length only; there is no `print`, no logging, no telemetry, no export path anywhere in `stride_core`.

Android backup was already correct — **domain-wide exclusions rather than a filename allowlist**, so the new save artifacts are covered by construction. An allowlist would have silently missed them when F-05 renamed everything. But nothing asserted it, and a manifest edit or a library manifest merged in by a future plugin would have changed it with no test failing. `Scripts/check-backup-exclusions.sh` now guards both transports and all five domains; I confirmed it fails when `allowBackup` is flipped and when a single domain is dropped.

**The open hole was bucket resolution.** The ruling bounds retention *length* and says nothing about *resolution*, so one-minute buckets would have been fully compliant as written — roughly ten thousand entries per origin, a minute-by-minute record of when the player moved, kept for a week. Nobody would have chosen that; it would simply have been whatever the adapter emitted, and the adapter is not written yet.

`TimeBucket.minimumWidthMillis` is now one hour, enforced at the reconciler boundary as a typed refusal **rather than an `assert`** — asserts are stripped from release builds, and release is where a player's data is. One hour is also what the retention document's own sizing estimate always assumed; the document now says so.

**One documentation correction.** `STEP_LEDGER_PRIVACY.md` §2 claimed the rescan window is "recorded only as a truncation count, not the window". That was false and contradicted §3 of the same document — the window is persisted and rides in the journal until compaction. Corrected in place, with the withdrawn claim left visible.

---

## 2. Two-slot selection rules, exactly

Artifacts: `save_slot_a`, `save_slot_b`, `journal`, and the origin salt.

Each complete slot carries a monotonic **generation**, save format version, **last applied journal transaction**, integrity digest, the full payload, and a **commit-complete marker written last**.

**A slot is a candidate only if all of these hold**, checked in this order — the order is what produces distinct diagnoses rather than one undifferentiated "corrupt":

1. Present and non-empty — else `slotAbsent`
2. Frame line parses, magic matches — else `slotMalformedEncoding`
3. Format version ≤ current — else `slotFutureSaveFormat`, **refused before decoding anything**
4. Byte length equals the declared length — short is `slotTruncated`, long is `slotMalformedEncoding`
5. CRC-32C over the payload matches — else `slotIntegrityMismatch`
6. Envelope decodes and its state version is supported — else `slotUnsupportedStateVersion`
7. `commitComplete` is present — else `slotIncompleteCommit`
8. Envelope agrees with its own payload on event sequence, state version, and profile — else `slotHeaderDisagreesWithPayload`

Checking length before digest is deliberate: truncation and corruption call for different recovery, and a digest-first check reports every truncation as corruption.

**Selection:** the candidate with the **highest generation** wins.

**Writing:** always to the slot that is *not* live. The live copy is never opened for writing, which is where atomicity comes from.

**No current-slot pointer is required for correctness.** If one is added later as a hint, recovery must ignore it when stale or corrupt — a pointer recovery trusts is a third thing that can be wrong.

**Equal generations, different contents → `LoadRefused(divergentSlotsAtSameGeneration)`.** Fail closed. There is no principled way to choose, and choosing wrong either duplicates or destroys a grant. Nothing is deleted, so a human recovery path survives; a test asserts the durable bytes are identical before and after the refusal.

**Both absent *and* the journal empty is the only new-game path.** Treating "no readable snapshot" as "new player" is a successful load that returns a wiped character.

---

## 3. Compare-and-swap conflict behaviour

Every transaction carries `expectedSnapshotGeneration` and `expectedLastAppliedTransaction`. The commit proceeds only if durable state still matches both.

On conflict:

- **Nothing partial is written.** Asserted by comparing the durable image byte-for-byte before and after a refused commit.
- The coordinator re-reads durable state and retries, bounded by `maxCommitRetries` (default 3).
- Past the limit: `CommitRefused(conflictRetryLimitExhausted)`. The caller must reload, reconcile against the newer state, and try again — which is safe precisely because F-04 grants `max(0, observed − granted)`.

**The retry budget is bounded on purpose.** An unbounded loop against a writer that never yields is a hang, and a hang during a step sync is indistinguishable, to the player, from the game losing their walk.

A single-writer queue also serializes operations within the process. **It is explicitly not treated as sufficient by itself** — Health Connect background delivery can run in a separate worker, and an in-memory mutex in one isolate says nothing about another. Actual background-worker integration is S-01.

**`snapshotDurable == false` is not an error.** The journal is the commit point; the snapshot is a cache, and the next launch replays. Three tests depend on this. When the app layer consumes `CommitDurable`, that flag must not become a "save failed" toast.

---

## 4. Cursor authority

**The validated snapshot is the sole durable authority for the provider cursor or token.**

This holds *structurally*, not by discipline. `SyncCheckpoint.cursor` lives inside `StepLedger` inside `GameState`, and a whole batch is one journal record — so the cursor and the grant that authorized it are **the same bytes**. There is no durable state in which one advanced and the other did not.

Native adapters **may** hold a cursor transiently during one operation. They **must not** persist or advance it independently, and **must not** cache a newer cursor outside the committed snapshot.

This is a decision record rather than a code comment because caching the HealthKit anchor in `NSUserDefaults`, or the Health Connect token in `SharedPreferences`, is the *natural* thing for an adapter author to do and looks like an optimization. It decouples cursor from ledger: a snapshot fallback then rolls back the grants but not the cursor, and everything in between becomes permanently unrecoverable.

---

## 5. The completeness assertion contract

The core **never infers** how much of a provider's data has arrived. Inferring it is what destroyed 55,200 steps of a paginated backfill and every backlog a reconnecting watch carried.

An adapter may assert completeness **only after fully exhausting every page for the declared scope**, and the assertion is scoped by:

| | |
|---|---|
| Data type | `HealthDataType.steps` today. Present so an adapter that later reads distance or workouts does not have its step assertion silently widened |
| Origin scope | `AllOrigins` (the adapter genuinely enumerated the platform's source list) or `SomeOrigins` (only the named sources) |
| UTC interval | The window actually queried |
| Query generation | So an assertion made under a since-invalidated anchor is not acted on |

Three states, not a boolean:

- **`PartialDelivery`** — pages outstanding. Nothing may be settled. The correct value for every page but the last of a paginated read, and for a truncated rescan.
- **`CompleteThrough`** — every page drained for the declared scope.
- **`RecoveryCompleteThrough`** — a bounded rescan covered its whole window. Distinct because a recovery's authority stops at the window it could reach; it never claims more than `intervalEndMillis`.

**A bare boolean is forbidden** because it cannot distinguish "every page for every source through Tuesday" from "page 1 of 9, whose newest record happens to be Tuesday" — and it cannot express "everything the phone wrote, while the watch has been offline for a week," which is the case where a returning player's walk vanishes.

Absent an assertion, nothing compacts and the watermark does not move. The ledger grows a little rather than risking a silent lost grant.

---

## 6. `StepOriginKey` and the pseudonymization boundary

`StepOrigin` was a free-form `String`, and its obvious iOS implementation is `HKSource.name` — a device name, which a player may have called anything, and which the ruling forbids persisting.

**`StepOriginKey` accepts only sixteen lowercase hex characters, or the reserved literal `unknown`.** A device name is not a representable value. The rule is enforced by the type system rather than by review; it cannot be forgotten, only deliberately worked around, which is a reviewable act.

The narrow alphabet also removes a serialization hazard: no separator, no non-ASCII, nothing that could split or merge a key on round-trip and silently re-grant a window or under-grant a real second device.

`OriginPseudonymizer` in `stride_health` is the **only** thing that can produce a key, and the only place a raw platform identifier exists in Dart — for exactly as long as one call takes.

**Keyed, not a bare hash.** An unkeyed digest of a package name is trivially reversible by anyone holding a list of package names, which is everyone, so it would be a pseudonym in name only.

**Rejections carry the length, never the value.** An exception message is a diagnostic surface, and the rejected value may be exactly the display name the type exists to exclude.

### 6.1 What happens if the salt is lost or reset

Every origin re-keys. Concretely:

- Newly-keyed origins have no `grantedSlices`, so their recent buckets look ungranted. **Within the retention window, that window would be granted a second time.**
- The old origins' slices age out and compact normally. No credit is lost — `totalGranted` and `grantedBeforeWatermark` are origin-independent.

So a lost salt is a **double-grant** risk, not a lost-grant risk, and it is bounded by the retention window rather than unbounded.

**The rule: a save whose salt cannot be matched fails closed.** The envelope records a non-reversing fingerprint of the salt; a load that cannot reproduce it refuses with `originKeyReset` rather than guessing. Refusing is recoverable — the player can be offered a health reconnect, which clears health state and keeps earned progress. A silent double-grant is not recoverable, because nothing detects it.

The salt is stored beside the save, covered by the same backup exclusions, and **never derived from a device identifier**, which would make it a device identifier.

---

## 7. Corrections made to the F-04 approval record

The F-05 review found **three lost-grant defects in already-approved F-04**, two of which needed no crash. Full detail in `F04_COMPLETION_REPORT.md` §14; the corrections were made *before* F-05 implementation began, on the owner's instruction.

| Claim as approved | Corrected to |
|---|---|
| 48-hour retention window (§3, §5, §9, §11) | **7-day prototype default, 48-hour configurable minimum**, enforced by a throwing constructor |
| The core derives the settled watermark | **The adapter asserts completeness**; the core never infers it |
| Commit ordering makes lost grants impossible | It closed **one** path; three others were open |
| Invariant 9, "a settled slice is never granted again" | Restated: a slice is settled **only where an adapter asserted completeness**, never merely because newer data arrived |
| Invariant 10, "compaction never loses granted credit" | Marked near-vacuous — the test asserted both figures independently and never related them |
| "Interruption at every recovery boundary" | Marked **overstated**: three cut points of five, and the helper *filtered* one event type rather than truncating, modelling no crash that can occur |
| A2 privacy escalation open | **Answered** by the owner ruling |

§13's recommendation — "the finding I would put in front of the owner is not a bug" — **stands as written**, with a pointer to §14 recording what it missed. Rewriting it would hide the error rather than correct it.

`DESIGN_REVIEW_F04.md` records the procedural cause: all five roles **read** the code and none **ran** it.

### 7.1 The lesson carried into F-05

Every F-04 test asserted the arithmetic was right. None asserted that **data the arithmetic never saw would still be credited**.

A test that supplies well-formed input and checks the output cannot find a bug whose signature is *input that never arrives*. F-05's fault matrix therefore includes cases where data is late, partial, out of order, or absent — not only where it is corrupt.

---

## 8. `/loop` iterations and root causes fixed

**Two iterations. Stopped at the two-consecutive-clean-passes condition.**

| Pass | From fresh storage | Fixtures | Result |
|---|---|---|---|
| 1 | ✅ | unchanged | 247 core + 2 app + 17 health, all guards |
| 2 | ✅ | unchanged | identical |

**Stated plainly: the loop found nothing, because the defects had already been found and fixed during the sub-agent phase, each with its own commit.** Reporting eight iterations of churn would be more impressive and less true.

Every suite constructs a fresh in-memory device per test, so "initialize fresh temporary storage" is a property of the harness rather than a step in the loop — and `reboot()` returns a *new* instance, so a test cannot leak state across the restart it claims to be testing.

The root causes fixed during implementation, all before the loop ran:

| # | Root cause | Found by | Commit |
|---|---|---|---|
| 1 | Unguarded `_compact()` turned a durable commit into a thrown error, freezing the cursor | Fault Matrix | `8e64edf` |
| 2 | `core.autocrlf` would rewrite the frozen fixture's `0x0A` separator, breaking its digest per clone | Migration | `1d90830` |
| 3 | Bucket *resolution* was unconstrained, so minute buckets would have been compliant | Privacy Auditor | `bc4ebf4` |
| 4 | `originKeyReset` / `originKeyRejected` documented as safeguards, never produced | Migration + Privacy | `bc4ebf4` |
| 5 | Android backup exclusions correct but unasserted | Privacy Auditor | `bc4ebf4` |
| 6 | **A global watermark cannot express per-origin settlement — LG-3 was never actually fixed** | Orchestrator, via a test written to prove the opposite | `ae06719` |
| 7 | `StepCheckpointAuthorized` dropped the watermark map, unsettling every origin | Orchestrator | `ae06719` |
| 8 | The snapshot did not persist the watermark map, so a reload re-granted the window | Orchestrator | `ae06719` |
| 9 | A healthy single-commit save reported itself `degraded` | Orchestrator | `6f4519b` |
| 10 | Pseudonymizer emitted 17-character keys for negative hashes | Orchestrator | `04c9282` |

**No test was weakened and no fixture was edited to obtain green.** Two tests were corrected, both times because the *fixture* did not reach the assertion:

- A privacy test ended on a spend and an equip, so the retained journal record carried no slices — the test failed with its own "proved nothing" reason string.
- A corruption test pinned `slotMalformedEncoding` where the diagnosis is now the more specific `originKeyRejected`, which is the improvement that agent asked for.

---

## 9. Test inventory

**247 `stride_core`**, up from 149 at F-04. **17 `stride_health`**, up from 7. **2 app.** 266 total, plus 5 Kotlin and 12 Swift in CI.

| Suite | Tests | Covers |
|---|---|---|
| `save_corruption_test.dart` | 27 | Every typed refusal; malformed encoding in six shapes; a digest test that proves the tampered payload still parses |
| `save_privacy_test.dart` | 23 | Assertions against **raw durable bytes**, not decoded objects |
| `save_fault_matrix_test.dart` | 18 | Eight crash boundaries plus concurrency and divergent slots |
| `save_protocol_test.dart` | 17 | Encoding, slot selection, CAS, salt refusal, watermark persistence |
| `lost_grant_regression_test.dart` | 11 | The three F-04 defects, bucket resolution, per-origin scoping |
| `save_migration_test.dart` | 7 | Frozen v1 fixture, byte-identical round trip, version refusals |
| `origin_pseudonymizer_test.dart` | 12 | A device name cannot cross the boundary or be constructed |

The suite that matters most is the one asserting on bytes. Every other save test can be clean while the file that produced it carries a field nobody reads.

---

## 10. CI identifiers

**Run `30762430717`** on `8657d30`. All four jobs green.

| Job | ID | Runner | Duration |
|---|---|---|---|
| Dart core | `91535256409` | ubuntu | 1m21s |
| Pigeon bindings | `91535256437` | ubuntu | 37s |
| iOS compile | `91535397058` | **macOS** | 6m30s |
| Android | `91535397099` | ubuntu | 7m27s |

The `ios` job is the one that matters most: nothing about the Apple branch is verifiable on Windows, and it has caught a compile failure before — `HealthKitAdapter.swift` missing `import Flutter`, in code that had been committed three times and described as working.

The `.gitattributes` fix is also only truly proven here: CI checks the repository out fresh, so the frozen fixture passing on a runner is the evidence that the `autocrlf` hazard is actually closed rather than merely closed on this machine.

**One standing annotation, unrelated to F-05:** `actions/checkout@v4` targets Node 20, which GitHub has deprecated and is forcing onto Node 24. Not breaking anything; worth a bump when something else touches CI.

---

## 11. Unresolved risks and required follow-up

### Carried into S-01

| | |
|---|---|
| **Adapter durability is unverifiable from the core** | `LedgerJournal.appendLine` promises to return only once durable. A platform that lies is survivable only because the snapshot write follows; if a device lied about both, `commit()` would return `CommitDurable` over nothing. Needs an adapter-level test, not a core test |
| **`lateDiscardedSlices` on real hardware** | Every nonzero occurrence must be investigated. Nonzero means real steps were probably lost |
| **Retention is provisional** | 7 days is a judgement. S-01 must measure actual correction latency |
| **Background-worker concurrency** | CAS is implemented and tested in-process. Health Connect background delivery is out of F-05 scope and must be reconciled against this contract rather than assumed safe |
| **Native cursor caching is prohibited** | `DECISIONS/0012` §5. The natural adapter implementation breaks it, and the failure is permanent and silent |

### Open, and honestly named

**Journal growth on the snapshot-failure path is unbounded and unobserved.** Compaction refuses when fewer than two slots verify — correct, since the floor is undefined — and `_commitOnce` only compacts when the snapshot is durable. On a device where snapshot writes keep failing, the journal grows while every reconciliation record carries a slice map. The healthy path is tight (the retained record is always the newest, so its slices are inside the live window), but there is no counter, no diagnosis, and no ceiling. *Privacy Auditor R-privacy-2.*

**An origin with no completeness assertion never compacts.** Deliberate — silence about a source is not an assertion about it — but an abandoned origin retains slices indefinitely. Bounded in practice because an adapter that enumerated the platform's source list asserts `AllOrigins`; unbounded if one persistently cannot. Needs an eviction rule once a real adapter exists.

**`ObservationKey.toString()` renders an origin key and a bucket.** Documented diagnostic-only and unreachable from any persisted or player-visible surface today, but it is the *default* rendering, so a future interpolation into an exception message writes health-derived data without anyone deciding to.

**`totalObserved` ratchets down under correction churn** and never recovers, so `grantedAheadOfObserved` — the field that exists to answer "why does the game say more than Health does?" — can report a divergence that is not there. Diagnostic only, but it is the diagnostic reached for when investigating everything above. *Carried from the F-04 critic review; not fixed in F-05.*

### The procedural finding

**Three of the ten root causes above were found by writing a test intended to demonstrate that something already worked.** The per-origin watermark defect is the clearest: the earlier LG-3 fix was committed, reported as complete, and had a passing regression test — and it only passed because that test never asserted completeness. The fix worked by never exercising the path it was supposed to protect.

The habit worth keeping: when a test is written to confirm a fix, it has to be able to fail. A regression test that passes against the pre-fix code is not a regression test.
