# F-05 — Sub-Agent Reconciliation

**Date:** 2026-08-02
**Status:** ⚠️ **Implementation not started.** Four blocking decisions await the owner.
**Inputs:** Persistence Architect, Crash-Recovery QA, Privacy and Security Reviewer, Technical Critic

The owner's F-05 authorization required four focused sub-agents and that *"the orchestrator must reconcile their findings before implementation."* This is that reconciliation.

---

## 1. What changed before anything else

The Technical Critic did not review the design — it ran the code, and found **three lost-grant defects in already-approved F-04**. Two need no crash. They are ordinary provider behaviour.

| | Defect | Cost |
|---|---|---|
| **LG-2** | A newest-first paginated backfill settles the watermark from its own newest hour, so the older page is discarded on arrival | **55,200 of 64,800 steps destroyed**, silently |
| **LG-3** | One origin's recent slice moves a global horizon past a *different* origin's unsynced window | A reconnecting watch loses its entire backlog |
| **W-1** | The watermark was recomputed independently of compaction, advancing past slices compaction had correctly declined to drop | The mechanism that made LG-2 and LG-3 reachable |

**Fixed and pushed at `8336774`.** The core no longer infers completeness; `SyncResponse.completeThroughMillis` is an assertion the adapter makes, and without it nothing compacts and the watermark does not move. Five regression tests, all of which fail against the pre-fix reconciler. 149 core tests pass.

LG-3 is the one worth pausing on. Its failure mode is *the player went away, so their steps did not count* — a direct violation of the Kernel's no-punishment-for-absence rule, shipped inside a system built to honour it.

**Two lessons carried forward.** First, F-04's thirteen scenarios tested one crash boundary thoroughly and the rest not at all; its crash-safety prose was broader than its proof. Second, the reason these defects survived review is that every test asserted the arithmetic was right, and none asserted that data the arithmetic never saw would still be credited.

---

## 2. Where the four agents agree

Unprompted, and from different directions:

1. **The journal is the commit point; the snapshot is a rebuildable cache.** Architect and QA converge on this independently. It makes crash safety a property of one fsync rather than of an ordering argument across five.
2. **The core must never infer what only the adapter knows.** The Critic's lost grants, the Privacy reviewer's unvalidated `StepOrigin`, and the Architect's completeness rules are the same mistake in three places.
3. **The journal is a privacy artifact.** `StepObservationReconciled` carries the full `grantedSlicesAfter` map. An uncompacted journal is a permanent, unbounded step history — exactly what the owner's retention ruling bounds, reintroduced through the back door. Compaction is therefore an obligation, not a size heuristic.
4. **Idempotent reconciliation will mask replay bugs.** QA's central finding: because F-04 grants `max(0, observed − granted)`, a loader that replays every record unconditionally forever produces the *correct* `totalGranted` in every crash-boundary test. Every replay test must carry a non-idempotent effect or it proves nothing.
5. **Concurrent commit has no design answer** and is not exotic — Android Health Connect background delivery can run while the app resumes.

---

## 3. Where they conflict, and my rulings

These are technical calls. I am making them rather than escalating.

| Conflict | Ruling |
|---|---|
| Architect wants two-slot ping-pong; approved plan §4.1 says temp+rename | **Escalated — see §4.1.** It contradicts approved text, so it is not mine to overturn. |
| QA asks whether the cursor is a second durable artifact | **The snapshot is the sole authority.** `SyncCheckpoint.cursor` lives inside `StepLedger` inside `GameState`, so cursor and grants are the same bytes and cannot diverge. Any native-side anchor cache is a cache, re-derivable from the snapshot on load. **Caching the HealthKit anchor or Health Connect token natively is prohibited** and becomes a port-contract rule — the Critic identifies it as the likeliest production path to a permanent lost grant. |
| Architect wants cursor publication moved earlier (after the journal fsync, not after the snapshot) | **Accepted.** Publication is not persistence. The rule that matters is *the cursor may be released to the adapter only after the journal append returns*. The owner's stated step 6 satisfies that rule but is stricter than needed, and the strictness costs a second fsync on the one path the player waits on. This is a refinement of the owner's contract, not a departure from it — the ordering guarantee is unchanged. |
| Architect's compaction floor vs. the owner's unqualified step 7 | **Floor accepted.** Compacting without one can delete the only record a fallback snapshot would need. Floor = `min(lastAppliedLedgerTransaction)` over *verified* snapshots; compaction refused outright when fewer than two verify. |
| Critic says `assert(eventSequence)` is the only replay guard and is stripped in release | **Accepted, and this is a real bug today.** It becomes a runtime rejection on the load path. `StepsGranted.grantedTotalAfter` is carried and never read; the reducer will set rather than add. |
| Architect recommends CRC-32C over SHA-256 | **Accepted.** The threat is corruption, not tampering; there is no server, and any digest we compute a save editor can recompute. Adding a dependency to a package whose value is having two, for a property we cannot enforce, is the wrong trade. Noted as revisitable if social comparison ever appears. |

---

## 4. Blocking decisions — these are yours

### 4.1 Snapshot atomicity: rename, or two slots?

The approved plan (§4.1) and your step 5 both say temp file plus atomic replace. The Architect argues this is **not achievable from Dart**: there is no way to fsync a directory, so the rename is not durably ordered against the file's contents.

|  | Temp + rename (approved) | Two-slot ping-pong |
|---|---|---|
| Atomicity from | Filesystem rename semantics we cannot verify from Dart | Never overwriting the live copy |
| In practice | Works on ext4/APFS almost always | Works by construction |
| Cost | — | ~5 KB, one extra read at launch |
| Risk | Unverifiable from where we stand | Unusual pattern; a future contributor may "simplify" it away |

**My recommendation: two slots**, with a comment in the port explaining why, and a plan amendment. The journal makes a lost snapshot recoverable either way, so this changes how often we replay at startup, not whether we lose data.

### 4.2 Concurrent commit — in scope, or explicitly deferred?

Two writers on one save is not hypothetical: S-01 uses Health Connect background delivery, so a WorkManager job can be mid-commit when you open the app. Background sync plus foreground sync double-grants, and **it will not reproduce on a developer's desk**.

Options: (a) put a save generation counter with compare-and-swap into F-05 scope, ~half a day; (b) write an explicit deferral naming background sync as the risk. **Silence is the option that ships the bug.** I recommend (a).

### 4.3 Profile mismatch in release builds

A save built under `accelerated_qa` carries XP that was not earned at production pacing. Should loading it into a release build be a **hard refusal**? The Architect recommends yes — it is the same guard as the existing release safeguard. It means a real save becomes unloadable, so I want it confirmed rather than assumed.

### 4.4 Journal as intent log, not event store

Aggressive compaction keeps the journal at 1–2 records, which is required by your retention ruling. The cost: no history to reconstruct "what changed while you were away" from, and no post-hoc debugging of a reconciliation defect from a player's device. The alternative — an event store with health fields redacted at compaction — adds a redaction mechanism that must itself be correct, and a redaction bug is the quietest possible privacy failure.

**I recommend the intent log.** Reopening this after the format ships is expensive, so it is worth one sentence from you now.

---

## 5. Also outstanding

- **`StepOrigin` is an unvalidated `String`.** Its obvious iOS implementation is `HKSource.name` — a device name, which your ruling explicitly forbids persisting. Needs validation at the boundary, not a convention. *(Privacy reviewer, blocking)*
- **Bucket *width* is unconstrained** while the ruling constrains only retention *length*. One-minute buckets would satisfy the ruling and produce a far finer activity record than intended.
- **`ObservationKey` must not serialize via `toString()`** — origin ids containing `@` or `|` split or merge keys, which silently re-grants or under-grants.
- **`totalObserved` ratchets down under correction churn** and never recovers, so `grantedAheadOfObserved` — the field that exists to answer "why does the game say more than Health does?" — reports a divergence that isn't there.
- **`F04_COMPLETION_REPORT.md` still argues 48-hour retention**; the code is 7 days with a 48-hour floor. The approval record does not match the artifact.
- **`packages/stride_core/lib/src/ports/step_provider.dart` is stale** — it still uses `DateTime` and a scalar model F-04 superseded, sitting unreferenced in the directory F-05's ports will join.

---

## 6. Recommendation

**Answer §4, then F-05 implements in one pass.** The design is settled apart from those four points; three of them contradict already-approved text or change scope, which is why they are not mine to decide.

What I would not do is build the save format first and decide after. F-05 serializes whatever shape is settled, and every one of these questions changes either the bytes on disk or the guarantees they carry.
