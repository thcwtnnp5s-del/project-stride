# 0014 — S-01A precedes F-07; foreground health only

**Status:** Approved
**Date:** 2026-08-03
**Authority:** Owner priority decision of 2026-08-03
**Task:** S-01A
**Amends:** the sequencing in `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md`

---

## Decision

**S-01A — foreground HealthKit and Health Connect integration with a
device-validation harness — now precedes F-07 (skill framework).**

F-07 is **deferred until after foreground health validation**. The earlier
roadmap ordering is preserved as history in the task breakdown; this record is
the amendment, not a rewrite.

### Why the reorder

Step ingestion is the input to everything F-07 would build on. A skill framework
sitting on an unvalidated ingestion path multiplies the cost of any correction:
the ledger arithmetic, the completeness model, and the origin privacy boundary
would all be load-bearing for gameplay before any of them had met a real
platform. Validating ingestion first is the cheaper order.

---

## Boundary — foreground synchronization only

S-01A does **not** enable, and must not enable:

- background Health Connect delivery
- background HealthKit observers
- background isolates writing persistence
- background workers accessing `SaveRepository`
- gameplay systems, skill framework, gathering, crafting, combat, audio

**The F-06 binding rule remains fully active** and is unchanged by this record:

> No background isolate, callback, worker, or platform entry point may
> instantiate `SaveRepository`, construct filesystem persistence stores, or
> access the save directory directly.

Enforced by `Scripts/check-single-writer.sh`. See `DECISIONS/0013`.

Background synchronization is **S-01B**, and it must not begin until S-01A is
closed and a real persistence coordinator exists.

---

## The finding S-01A must resolve

Discovered while scoping this task, and it is the reason S-01A is substantial
rather than a thin adapter fill-in.

**The codebase holds two parallel step-ingestion models, and the platform
boundary is wired to the one nothing uses.**

| | Live model (F-04/F-05) | Dead model (F-01 era) |
|---|---|---|
| Entry point | `ReconcileStepSync(SyncResponse)` → `GameEngine` → `StepReconciler.reconcile` | `StepProvider.fetchNewSteps` → `StepFetchResult` |
| Shape | per-origin `StepObservation` keyed by `ObservationKey(origin, bucket)` | flat `newSteps: int`, `deletedSteps: int` |
| Completeness | scoped `SyncCompleteness` — data type, origin scope, UTC interval, query generation | **none** |
| Origins | `StepOriginKey`, pseudonymized | **none** |
| Pagination | `PartialDelivery` vs `CompleteThrough` | **none** |
| Consumers | `GameEngine`, `StepReconciler` | **nothing** |

`StepProvider`, `StepFetchResult`, `PlatformStepProvider`, `MockStepProvider`,
and the three-method Pigeon contract are all the dead model. Verified by grep:
outside their own definitions and tests, nothing references them.

This is the same shape as the F-06 persistence-owner finding — code that reads
as a live layer and is reachable by nothing. It was harmless while the adapters
were shells. It stops being harmless the moment a real adapter is written
against it, because the flat contract **cannot express** what the core requires:
per-origin attribution, scoped completeness, or partial pages.

### Consequence for S-01A

The platform boundary must be extended to carry per-origin observations,
completeness scope, and pagination state, and the bridge must produce
`SyncResponse` rather than `StepFetchResult`. The dead model is then retired or
rewritten rather than left beside the new one.

This is **not** a reopening of F-06. It is the S-01 boundary work, which is what
S-01A exists to do.

---

## Save compatibility of the new enum values

S-01A adds `originKeyingUnconfigured` to three enums: `ProviderUnavailableReason`,
`ReconciliationCode`, and `SourceState`. Only `SourceState` reaches a save.

**Forward compatible.** `SourceState` is serialized **by name**
(`'sourceState': ledger.sourceState.name`) and decoded by name lookup, so a save
written by an older build carries a name this build still resolves. Appending a
member breaks nothing that already exists on disk.

**Downgrade is NOT promised.** A save written by this build while the source
state is `originKeyingUnconfigured` carries a name an older binary has never
heard of. That older build refuses the save rather than guessing — which is the
correct behaviour and the same fail-closed path every other unknown value takes
— but it *is* a refusal, and the player would see a blocked launch until they
returned to a current build.

This is recorded rather than fixed. Project Stride has no installed base
(`DECISIONS/0011` — no iOS build has ever been distributed, Android is APK and
Play-internal only), so there is no version to downgrade *to*. **Downgrade
compatibility is not a guarantee this project makes**, and nothing should be
designed on the assumption that it is.

## Evidence categories

S-01A must report evidence in these categories and never blur them:

1. pure-Dart / domain verified
2. native unit tested
3. Android emulator verified
4. physical Android verified
5. iOS simulator verified
6. physical iPhone verified
7. still unverified

**Simulator evidence is never to be described as physical-device validation.**
This project has already had one class of defect — the POSIX lock hole — survive
because a green run on the wrong platform was read as verification.

---

## Follow-up

- **S-01B** — background synchronization. Blocked on S-01A closure *and* on a
  real persistence coordinator (`DECISIONS/0013` §6).
- **F-07** — skill framework. Deferred until foreground health validation is
  complete.
- `IPHONE_TESTING_READINESS.md` records what remains before the owner can install
  the technical harness on a physical iPhone.
