# Design Review — F-05 Save, Ledger Persistence, Crash Recovery

**Subject:** `packages/stride_core/lib/src/save/`, `lib/src/ports/save_store.dart`, the per-origin watermark change in `lib/src/steps/`, `stride_health/lib/src/origin_pseudonymizer.dart`, and the seven F-05 test suites
**Date:** 2026-08-02
**Outcome:** ✅ **Approved.** Four items carried forward, named in §6.

> **How this review was conducted, and its main limitation.** Four of the five roles are grounded in sub-agents that **ran the code** — the Fault Matrix, Migration, and Privacy agents each executed suites against the working tree, and one mutated the loader to check its own suite was load-bearing. The Creative and Systems perspectives below are the orchestrator's synthesis and were **not** independently run.
>
> That distinction matters because `DESIGN_REVIEW_F04.md` records what happened last time: five roles read the code, none ran it, and a design with three silent lost grants passed review.

---

## 1. Technical Director

**Approved.**

The load-bearing choice is that the transaction protocol lives in `stride_core` rather than behind a port. The protocol *is* the crash-safety argument; in the app layer it could not be tested by `dart test` on Windows in milliseconds, and a test double would eventually disagree with the real implementation about ordering. The ports promise only "bytes, durably".

Two-slot ping-pong over temp-plus-rename is the right call for a reason that is a platform fact rather than a preference: **Dart cannot fsync a directory**, so rename durability is unverifiable from where we stand. Atomicity now comes from never opening the live copy for writing.

The keystone invariant — *the durable cursor never leads the durable granted state* — holds **structurally**. `SyncCheckpoint.cursor` is inside `StepLedger` inside `GameState`, and a batch is one journal record, so the cursor and its authorizing grant are the same bytes. That is worth more than any amount of careful ordering, because it cannot be got wrong by a later edit.

**The concern I would put on record:** `_serialized` gives a single-writer queue, and the design correctly refuses to treat it as sufficient. But compare-and-swap is only tested in-process. The Android background-worker case is out of scope by ruling, and the contract it must satisfy is written down — that is the right disposition, but it is a promise about future work rather than a tested property.

## 2. QA Director

**Approved.**

The suite that earns the most confidence is the one asserting on **raw durable bytes** rather than decoded objects. Everything else can be clean while the file carries a field nobody reads.

Three habits worth keeping:

- **Non-idempotent effects in every replay test.** Because reconciliation grants `max(0, observed − granted)`, a loader that replays everything forever produces correct totals in every crash test. Carrying `AllocateSteps` and asserting `totalSpent` is the difference between a suite that proves something and one that proves nothing. Verified by mutation: 13 of 18 failed.
- **Distinct non-summing quantities** — 137, 291, 613. With 100/200/300 an off-by-one, a drop, and a duplicate all become invisible.
- **The integrity fixture still parses.** Flipping `1000` to `4000` keeps valid JSON, so the test proves the *digest* rejects it rather than the parser.

**The gap I want named:** coverage is now excellent for corruption, concurrency, and crash boundaries, and still absent for *real device behaviour*. `LedgerJournal.appendLine` promises durability the core cannot verify. A platform that lies about fsync is survivable today only because a snapshot write follows it.

## 3. Critic

**Approved, with the observation that this task's own reporting was wrong twice.**

The interesting finding is not any single defect; it is that **three of ten root causes were found by writing a test intended to demonstrate that something already worked**.

The per-origin watermark case is the one to remember. LG-3 was found, fixed, committed, reported as closed, and had a passing regression test — and the fix was inert. The test passed because it never asserted completeness, so it never exercised the path the fix protects. A global watermark cannot express "settled for the phone, still open for the watch", and `isSettled` applied that one scalar to every origin. The disguise was good enough to survive its own regression test.

Two claims in this task's documents were also written before the code supported them: `originKeyReset` was described as implemented in `DECISIONS/0012` and in the completion report while never being produced. **Documented-but-absent is worse than either alone**, because a reviewer reads it as a safeguard that exists. Both are now wired and tested.

**What I would still challenge:** the journal-growth path on a device where snapshot writes persistently fail is unbounded and has no counter. The reasoning for refusing to compact is correct. The absence of any observability on it is the same shape of mistake as a silent lost grant — a condition nobody can see.

## 4. Creative Director

**Approved.**

Against the Kernel's first question — *does this make real-world movement feel more meaningful without creating pressure?* — this task is invisible when it works, and it is the difference between the game existing and not.

The two failures it prevents are the only two that would end a player's relationship with Stride: **"my walk didn't count"** and **"the game opened and my character was gone"**. Both were reachable before this task, and one of them (LG-3) was a direct violation of *no punishment for absence* — the failure mode was literally *the player went away, so their steps did not count*, shipped inside the system built to honour that rule.

The refusal texts hold the tone. A save this build cannot read says nothing has been changed or deleted; a changed health key names the way out — reconnect, progress kept — rather than reporting a fault. **Nothing here ever tells a player they lost something.**

## 5. Systems Designer

**Approved.**

Nothing in the persistence layer reads a clock, so step-clocked progression survives. `TimeBucket` millis stay opaque data, and no day boundary enters the save format.

The one systems-visible consequence: an origin the adapter cannot vouch for never compacts. Correct — silence about a source is not an assertion about it — but it means retained slices for an abandoned device grow without an eviction rule. That is a systems question, not a storage one, and it needs answering once a real adapter exists and we know how origins actually behave.

The one-hour bucket floor is a resolution decision as much as a privacy one: it fixes the granularity the whole retention estimate assumed, and it is now the thing an adapter must design toward rather than discover.

---

## 6. Carried forward

| | Item | Owner |
|---|---|---|
| 1 | **Adapter durability test** — prove `appendLine` really fsyncs before returning. The core cannot detect a lying port | S-01 |
| 2 | **Journal growth on the snapshot-failure path** — no counter, no diagnosis, no ceiling | S-01 |
| 3 | **Abandoned-origin eviction** — an origin that never asserts completeness retains slices indefinitely | S-01 / systems |
| 4 | **`totalObserved` ratchets down under correction churn**, so `grantedAheadOfObserved` can report a divergence that is not there. Carried from the F-04 critic review and still not fixed | S-06 or earlier |

## 7. The five questions

1. **Does it support the Kernel?** Yes, and it repairs a violation of it. LG-3 punished absence.
2. **Does it improve the player experience?** Only by never being noticed — which for a save system is the whole job.
3. **Is the complexity justified?** Yes, with one deliberate cut: no event store. The state is a few kilobytes, so the snapshot is the cheap artifact and a long log is the expensive one — and a long log is also a permanent step history.
4. **Does it create future problems?** Two, both named above: unobserved journal growth, and no eviction rule for an abandoned origin.
5. **What should change before approval?** Nothing blocking. The four carried items are S-01 work and are recorded rather than deferred silently.
