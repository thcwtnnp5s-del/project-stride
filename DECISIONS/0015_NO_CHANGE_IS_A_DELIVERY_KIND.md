# 0015 — `NO_CHANGE` is a delivery kind, not an empty page

**Status:** PROVISIONAL. Adopted for S-01A on the strength of the reasoning
below; it is not yet confirmed against a real HealthKit or Health Connect change
stream, and the confirming evidence is named at the end.

**Supersedes nothing.** Extends `DECISIONS/0014`.

---

## The question

An adapter that asks "what changed since this cursor?" and is told "nothing" can
report that in two ways:

1. an **incremental** delivery carrying zero observations
2. a distinct **no-change** status

They are not the same claim, and treating them as the same is a lost grant.

## The ruling

`PlatformSyncStatus.noChange` is a **distinct delivery kind**, and it means one
specific thing:

> The platform's change stream was drained and produced nothing between the
> cursor and now.

It is **not** "the query returned no rows". A query that returns no rows may
mean the window was empty, or that the query was scoped wrongly, or that
permission is silently denied — HealthKit deliberately hides read denial so an
app cannot infer that a user has no data.

### What follows structurally

| | |
|---|---|
| Observations | **none.** A no-change page carrying observations is `SyncContractViolation.noChangeWithPayload` and the whole delivery is rejected. |
| Rescan window | **none**, same violation. |
| Completeness | `PartialDelivery` only. A no-change page asserting `CompleteThrough` or `RecoveryCompleteThrough` is `SyncContractViolation.mismatchedCompleteness`, and the whole delivery is rejected. |
| Cursor | **may advance.** This is the documented exception in `cursor_authorization.dart`. |
| Watermarks | **never move.** Nothing was vouched for. |

### Why the cursor may advance while nothing settles

Knowing that nothing arrived says nothing about what the window *held*, so no
bucket may be marked accounted-for. But the token still means "you have seen
everything up to here", and on a page where nothing changed that claim is true
without vouching for the window's contents.

It is safe precisely because nothing was settled: no bucket was marked
accounted-for, so a later delivery inside that window is still grantable. If the
cursor did **not** advance, a quiet device would re-read from the same point
forever, and every sync would re-derive the same empty answer at increasing cost.

### Why observations alongside `noChange` are rejected rather than promoted

This previously promoted the response to `IncrementalSync`, on the reasoning
that real steps must never be thrown away over a status mismatch. The owner
ruled that back, and the earlier reasoning was the weaker half of the argument:

A page whose status says "nothing arrived since your cursor" while carrying what
arrived has two halves that cannot both be true. Promoting it keeps one of them
**by guessing**. Rejecting is also strictly safer than refusing as `unavailable`
— `ContractViolationSync` reaches `GameEngine` as a malformed batch, which is
rejected outright, so not even `sourceState` moves.

It is the adapter that has to change.

---

## Why this is PROVISIONAL

The ruling rests on a claim about platform behaviour that has not yet been
observed on a device:

> that both platforms can distinguish "the change stream drained and produced
> nothing" from "the query matched nothing", and will report the former.

On iOS this is `HKAnchoredObjectQuery` returning the same anchor with empty
added/deleted sets. On Android it is a Health Connect changes token that yields
an empty change list while remaining valid. Both are documented to behave this
way. **Neither has been observed in this project on real hardware**, and
`DECISIONS/0014` is explicit that simulator evidence is never to be described as
physical-device validation.

### The evidence that would confirm it

1. **A real drain.** A device with no new step data since the cursor produces a
   `noChange` page — not an incremental page with zero observations.
2. **A real change.** The same device, after walking, produces an incremental
   page with observations and a different cursor. This is what rules out the
   adapter reporting `noChange` unconditionally.
3. **Token survival.** The cursor returned by a `noChange` page is accepted by
   the next read rather than being reported invalid.

Until all three are recorded on physical hardware, this decision is a
well-reasoned default and is labelled as one.

### If the evidence contradicts it

If a platform cannot distinguish the two cases, the correct response is **not**
to relax the contract so that whatever the adapter sends is legal. It is to
report the indistinguishable case as `PartialDelivery` with no observations,
which settles nothing and grants nothing — the choice that under-settles rather
than over-settles, consistent with the bias stated in `platform_step_source.dart`.

---

## Where this is enforced

- `packages/stride_health/lib/src/platform_step_source.dart` — `_violation`
  checks structure first, then completeness
- `packages/stride_core/lib/src/steps/sync_batch.dart` — `SyncContractViolation`
- `packages/stride_health/lib/src/cursor_authorization.dart` — the noChange row
- `packages/stride_health/test/cursor_authorization_matrix_test.dart` — the
  matrix rows, and layer 1's sweep over all three completeness values
