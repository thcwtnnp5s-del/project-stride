# Design Review — F-04 Step Ledger and Reconciliation

**Subject:** `packages/stride_core/lib/src/steps/`, the reducer and engine integration, and the F-04 test suite
**Date:** 2026-08-02
**Reviewers:** Creative Director, Systems Designer, Technical Director, Critic Agent, QA Director

## Outcome

> **Approved with changes, and one item escalated to the owner.**

Seven findings. Five applied, one recorded, **one escalated** — the retention window narrows a rule in the Game Bible and the reviewers agreed that is the owner's call, not the studio's.

---

## Technical Director review

### Summary

The choice to make an observation an **absolute figure keyed by `(origin, bucket)`** rather than a delta is the decision the whole task rests on, and it is right. Deltas cannot express a correction and cannot be replayed; absolutes can do both, and every one of the thirteen scenarios then falls out of one arithmetic rule rather than thirteen branches.

The commit ordering — recovery started, observation reconciled, steps granted, recovery completed, **checkpoint last** — is the crash-safety contract made structural rather than documented. Two findings.

### Findings

**TD-1 — `StepRecoveryStarted` carries a zero window.** *(Applied.)*

The engine emitted `windowStartMillis: 0, windowEndMillis: 0` because the outcome did not carry the window through. Harmless today — nothing reads it — but a field that exists and is always wrong is worse than no field: someone will eventually trust it.

*Change:* `ReconciliationAccepted` now carries the window, and the event reports the real bounds.

**TD-2 — `sourceState` is not reset to `available` on a `NoChangeSync`.** *(Applied.)*

A provider that had failed and then answered "no change" left the ledger still marked unavailable, so the UI would keep apologizing after the problem cleared.

*Change:* any accepted reconciliation, including no-change, restores `available`.

---

## QA Director review

### Summary

Thirteen scenarios as black-box tests, written before the reconciler, each asserting observable outcomes and none asserting the arithmetic. That was the instruction and it was followed literally — I checked for `windowTotal`, `grantedSinceWatermark`, and `max(` in the scenario file and found none.

The property tests are the part I would defend hardest: five seeded sequences of 120 mixed operations each, with monotonicity, non-negativity, the spend bound, and the banked derivation asserted at *every* step rather than at the end.

### Findings

**QA-1 — One scenario asserted the wrong thing about interrupted recovery.** *(Applied — and it was my error, not the code's.)*

I expected `recovery.isActive` to be true after a crash between the grant and the checkpoint. It is false, correctly: `StepRecoveryCompleted` precedes the checkpoint, so at that point recovery genuinely had completed and only cursor persistence was lost.

*Change:* the expectation is corrected, **and** a new scenario was added for the case that actually models an unfinished recovery — death immediately after `StepRecoveryStarted`, before anything reconciles. That one does leave `recovery.isActive` true, which is exactly what a retry needs to know.

Worth recording plainly: the original test would have passed if the engine had authorized the cursor before completing recovery. It was asserting a behaviour that did not exist and would have masked a real ordering change.

**QA-2 — `Random(seed)` was avoided in favour of a hand-rolled LCG.** *(Applied, and I want it kept.)*

`Random(seed)` is reproducible within a Dart version, not necessarily across them. A property test whose failure cannot be replayed byte-for-byte on another machine is a property test nobody can debug at the moment they most need to.

---

## Systems Designer review

### Summary

The terminology now says what it means: observed is what the source claims, granted is what the player has, spent is what they committed, banked is the difference. The distinction is not cosmetic — it is the reason a health correction cannot revoke earned progress.

### Findings

**SD-1 — `AllocateSteps` still has nothing to allocate *to*.** *(Recorded.)*

It moves steps from banked to spent with no activity attached. Correct for F-04 — activities are out of scope — but it means `totalSpent` currently records that steps left the bank and nothing about where they went.

*Response:* no change. When activities arrive, spending gains a target and the event gains a field. The ledger shape does not need to move for that.

---

## Creative Director review

### Summary

Nothing player-facing exists yet, and the one thing that will be player-facing is right: **there is no `StepsRemoved` event.** A health correction changes what Health says, never what the player has. Had that event existed, some future screen would have shown "you lost 600 steps", and the player promise would have been broken by an event name.

`grantedAheadOfObserved` deserves a note too — it means the eventual answer to "why does the game say more than my Health app?" is a number the game already knows, rather than a shrug.

### Finding

**CD-1 — A repeated provider failure emits nothing after the first.** *(Approved as-is.)*

Right call. A player with Health Connect uninstalled would otherwise accumulate an event per sync forever, and the return summary is driven off that stream.

---

## Critic Agent review

### Summary

Scope held: no HealthKit, no Health Connect, no permissions, no background work, no storage, no serialization, no UI, no gameplay. `stride_core` is still 22 files of pure Dart with no clock, no randomness, no platform.

Two findings, one of which I am escalating rather than deciding.

### Findings

**CR-1 — ⚠️ `grantedSlices` narrows a Game Bible rule. Escalated.**

`GAME_BIBLE/HEALTH_INTEGRATION` says to persist *"ingested total, consumed total, sync anchor"* and **"never a step history"**.

`grantedSlices` is more than that list. For up to 48 hours it holds per-device, per-hour **granted amounts**. That is derived rather than raw, and it is bounded and compacted — but it is close enough to a coarse recent step record that calling it "not a history" would be a word game.

It is also what makes replay, overlap, multi-origin, and bounded recovery provably safe. The scalar alternative stores strictly less and cannot distinguish a restatement from a new observation, which breaks four of the required scenarios.

**This is a real trade between two things the project has committed to, and it is the owner's to resolve, not the studio's.** `TECHNICAL/STEP_LEDGER_PRIVACY.md` §5 sets out three options with a recommendation. Until it is ratified it stands as a **known deviation**, not a settled decision.

I want to be clear that I am not objecting to the engineering. I am objecting to it being adopted silently.

**CR-2 — The 48-hour window is a guess wearing a constant's clothing.** *(Applied.)*

Nothing verifies that corrections actually arrive inside it. If they routinely arrive later, steps are silently under-granted — the quietest possible failure, and one no test here can catch because no test here has real health data.

*Change:* documented as a judgement rather than a derivation, with the property asserted by test and the *value* explicitly listed among the assumptions awaiting real-device validation at S-01.

### What I checked and found clean

- No `StepsRemoved` event, and no path by which a grant decreases.
- No day boundaries, no timezone arithmetic, no calendar anywhere — buckets are opaque intervals.
- No native or platform type in `stride_core`; `SyncResponse` is fully neutral.
- The cursor cannot be authorized before the ledger commits — enforced by event order, tested by replaying a partial commit.
- Deferred vocabulary still absent.

---

## Consolidated changes

| ID | Change | Status |
|---|---|---|
| TD-1 | Recovery event carries the real window | Applied |
| TD-2 | Any accepted sync restores `available` | Applied |
| QA-1 | Corrected interruption expectation; added the mid-flight case | Applied |
| QA-2 | Deterministic LCG instead of `Random(seed)` | Applied |
| CR-2 | 48 hours documented as a judgement awaiting validation | Applied |
| SD-1 | `totalSpent` records no destination yet | Recorded |
| **CR-1** | **Retention narrows a Game Bible rule** | ⚠️ **Escalated to owner** |

## Follow-up

F-05 may proceed on approval. **CR-1 should be answered first** — the persisted shape is what F-05 will serialize, and settling it after the save format exists would be the expensive order.
