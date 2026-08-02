# Design Review — F-03 Runtime Spine

**Subject:** `packages/stride_core/lib/src/engine/` and the F-03 test suite
**Date:** 2026-08-02
**Reviewers:** Creative Director, Systems Designer, Technical Director, Critic Agent, QA Director

## Outcome

> **Approved with changes.**

Eight findings. Six applied, two recorded for F-04.

The reviewers agree the shape is right: commands are requests, events are facts, one reducer writes, and the engine cannot read a clock. The findings concern places where the *architecture* is sound but a detail would have caused trouble later.

---

## Technical Director review

### Summary

The command/event split and the canonical reducer are correct, and the deep-immutability treatment is the real work here. Copying on construction *and* wrapping unmodifiable is the combination that matters — either alone leaves a hole. Three findings.

### Findings

**TD-1 — A rejection returned the same state object, which the tests then relied on.** *(Applied — kept, and documented.)*

`execute` returns `before` by identity on rejection, and tests assert `identical(engine.state, before)`. That is stronger than value equality and worth keeping, but it was accidental rather than stated. If someone later "tidied" it into `before.copyWith()`, the tests would fail for a reason nobody would understand from the diff.

*Change:* the behaviour is now documented at the return site as deliberate.

**TD-2 — `GameEngine` is mutable, holding `_state`.** *(Recorded.)*

The state is immutable; the engine is a mutable holder of the latest one. That is the right call — a purely functional engine would push sequence-number bookkeeping onto every caller — but it means the engine is not safely shared across isolates, which the architecture plan's §3.3 assumes it will not be.

*Response:* no change. Recorded so the assumption is explicit rather than implied.

**TD-3 — Nothing prevents constructing a state whose `eventSequence` disagrees with its history.** *(Recorded for F-05.)*

`copyWith(eventSequence: 0)` is used in the replay tests to build a blank base, which is legitimate for a test but is also a public route to an inconsistent state. Real protection belongs with persistence, where a state arrives from outside and must be checked.

*Response:* F-05 owns save validation. Noted there.

### Recommendation

Approve with TD-1 applied.

---

## QA Director review

### Summary

Every one of the fifteen required test areas is covered, and the immutability tests probe all three directions the specification asked about. Two findings, one of which was a genuinely misleading test.

### Findings

**QA-1 — A test named for `invalid_equipment_slot` asserted `item_not_owned`.** *(Applied.)*

It tried to equip an Oak Log the player did not have, so it never reached the slot check. It passed, and it proved nothing about the rule in its name — the exact failure mode the F-02 fixture work had just been through.

*Change:* the item is granted first, so the command gets past ownership and the slot rule is what actually fires.

**QA-2 — Determinism was only tested behaviourally.** *(Applied.)*

Two runs agreeing is evidence, not proof: a clock read landing in the same millisecond, or a random draw that happens to repeat, would pass. A behavioural test cannot distinguish "deterministic" from "lucky".

*Change:* added `engine_purity_test.dart`, a source scan rejecting `DateTime.now`, `Stopwatch`, `Random(`, `Platform.`, `Zone.current`, locale, and timezone reads across all of `lib/`. It strips comments and string literals first, includes a self-check that the detector still works, and asserts the scan actually covers the engine files rather than passing vacuously.

### Recommendation

Approve with QA-1 and QA-2 applied. QA-2 is the more valuable of the two.

---

## Systems Designer review

### Summary

The state carries what progression will need and nothing it will not. Storing skill *experience* and deriving level from the content curve is the right way round. One finding.

**SD-1 — `StepState` has `granted`/`allocated`, but F-04 needs `ingested`/`consumed`.** *(Recorded, deliberate.)*

The reconciliation model uses different words for a reason: `ingested` is what came from the health source, `granted` is what the game accepted, and after a correction those can differ. The F-03 names describe what exists today honestly, and F-04 will extend rather than rename.

*Response:* no change. Renaming now would mean inventing the distinction before the thirteen scenarios that define it.

### Recommendation

Approve.

---

## Creative Director review

### Summary

Nothing player-facing exists yet, which is correct for a spine. Two observations worth recording because they are decisions in disguise.

**CD-1 — The player starts with equipment granted but not worn.** *(Applied — as a test, not a change.)*

Defensible: equipping is the first small decision a player makes, and P-05's onboarding can teach the loop by having them do it. But it was implicit in the factory rather than stated anywhere.

*Change:* an explicit test asserts it, with the reasoning in a comment, so a future change to auto-equip is a deliberate act rather than a silent one.

**CD-2 — `UnlockLocation` is a player command in F-03 and should not stay one.** *(Recorded.)*

In the real game an unlock is a *consequence* — of arriving somewhere, of crafting the item a gate requires. Leaving it as a command the player issues would eventually let the UI unlock the world.

*Response:* documented on the command as temporary. F-04 or the travel task should demote it to an internal effect.

### Recommendation

Approve.

---

## Critic Agent review

### Summary

Scope held. No gathering, no crafting, no combat, no travel costs, no health ingestion, no persistence, no UI, no audio. The behavioural slice is genuinely minimal and every command in it exists to prove something structural.

### Findings

**CR-1 — `GrantSyntheticSteps` is a back door, and needs to stay an obvious one.** *(Applied.)*

It adds steps with no health source. That is necessary — F-03 cannot test a ledger it has no way to fill — and it is also exactly the shape of a thing that quietly survives into production and lets someone grant themselves progress.

Two properties make it safe: it goes through the same validation and the same reducer as everything else, so it cannot behave differently from the real path; and it carries a mandatory `reason` recorded on the event, so a state built from synthetic steps can never be mistaken for one built from real walking.

*Change:* both properties are now documented on the command as the reason it is acceptable, not incidental detail.

**CR-2 — The engine accepts a command and emits zero events when re-equipping what is already worn.** *(Applied.)*

Accepted-but-eventless is unusual and could read as a bug. It is right: the operation is idempotent, and inventing an `ItemEquipped` fact for something that did not change would corrupt any replay or audio driven off the stream.

*Change:* documented at the branch, and a test asserts the empty event list and unchanged state identity.

### What I checked and found clean

- No wall-clock progression anywhere, now enforced by source scan as well as by behaviour.
- State stores IDs, never definitions — asserted by a test that the signature contains `item.training_sword` and not `Training Sword`.
- Rejections never mutate: identity-checked, not just value-checked.
- Sequence numbers monotonic and gap-free; a rejection consumes none.
- `stride_core` purity holds — 19 files, no Flutter, no `dart:io`.
- Both balance profiles produce structurally identical states.

### Recommendation

**Approve.**

---

## Consolidated changes

| ID | Change | Status |
|---|---|---|
| TD-1 | Document identity-preserved rejection as deliberate | Applied |
| QA-1 | Fix the mislabelled `invalid_equipment_slot` test | Applied |
| QA-2 | Add a static no-ambient-input source scan | Applied |
| CD-1 | Test and explain granted-not-worn starting equipment | Applied |
| CR-1 | Document why the synthetic-step command is safe | Applied |
| CR-2 | Document and test accepted-but-eventless | Applied |
| TD-2 | Engine is a mutable holder; not isolate-safe | Recorded |
| TD-3 | `eventSequence` consistency belongs to F-05 | Recorded |
| SD-1 | `granted`/`allocated` will gain `ingested`/`consumed` at F-04 | Recorded |
| CD-2 | `UnlockLocation` should become an internal effect | Recorded |

## Follow-up

No further review required before F-04.
