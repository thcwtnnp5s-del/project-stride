# 0013 — Single-writer-isolate persistence

**Status:** Approved
**Date:** 2026-08-03
**Authority:** Owner ruling of 2026-08-03, superseding the F-06 persistence-coordinator ruling
**Supersedes:** the requirement that a persistence-owner isolate own repository access and that all in-process callers communicate through it
**Task:** F-06

---

## Decision

Project Stride runs an **explicitly single-writer-isolate** persistence model.

Exactly one isolate may construct a `SaveRepository`, construct a filesystem
persistence store, or touch the save directory. That guarantee is enforced by
`Scripts/check-single-writer.sh`, not by a runtime mechanism.

Three protection layers, and what each one actually covers:

| Layer | Mechanism | Covers | Does **not** cover |
|---|---|---|---|
| 1 | Path-keyed in-isolate mutex in `FileTransactionLock` | Two repository instances in **one** isolate | A second isolate |
| 2 | OS advisory lock (`fcntl` / `LockFileEx`) | Separate OS **processes** | Anything inside one process, on POSIX |
| 3 | Compare-and-swap on every commit | Stale revisions, and defence in depth | Nothing about ordering |

**Nothing in this list serializes two isolates.** That is the whole reason the
rule below is binding rather than advisory.

### The binding architecture rule

> **No background isolate, callback, worker, or platform entry point may
> instantiate `SaveRepository`, construct filesystem persistence stores, or
> access the save directory directly.**

**S-01 must design and validate a real persistence coordinator before enabling
any Health Connect background writer.** Enabling background delivery without one
reintroduces the exact defect described below.

---

## 1. What was found, and why the earlier ruling changed

The F-06 ruling required a persistence-owner isolate because Dart's
`RandomAccessFile` locks are POSIX advisory locks and do not exclude multiple
isolates in one process. That reasoning was correct and the evidence turned out
to be **worse than stated**.

CI run `30767931205` was the first time four of the storage test files ever
executed on Linux. The result was 94 passed, 11 failed — against 105/105 on
Windows:

```
S1 same-process exclusion: a second FileTransactionLock over the same file is refused
Expected: null      Actual: <Instance of '_FileLockHandle'>
```

Both acquirers in that test are in **one isolate**. `fcntl` ownership is the
*process*, so the OS lock is a no-op against yourself — not merely across
isolates. Within one process it serialized **nothing**.

Downstream consequences, all real: `totalGranted` reported 7 where 0 was
required (grant-accounting divergence), `journalAppendFailed` instead of a clean
CAS refusal, `SaveLoaded` where `LoadRefused` was required, and the `-1` journal
fork sentinel.

Windows passed all eleven because `LockFileEx` is per-handle — the opposite
semantics. **A green Windows run was never evidence for this property**, and the
suite had been read as verification for its whole life.

The path-keyed in-isolate mutex (layer 1) closes the case that actually failed.

---

## 2. Why the owner isolate is not being wired

The prototype was built and tested. It is being **removed from the production
tree** rather than wired, because wiring it at this milestone would delete
working controls to close a race the app does not have.

Three concrete blockers, all verified in source:

1. **`SaveRepository` is a `final class`** and `BootstrapCoordinator.repository`
   is typed against it. A client-backed adapter cannot be substituted. Bootstrap
   is where the first load and the new-game commit happen, so an owner that
   bootstrap cannot reach does not own the directory.
2. **The per-write backup-exclusion hook cannot cross the port.** The owner
   constructed its stores with no `reapplyExclusion`, so routing through it would
   remove the iCloud-restore control that F-06 just wired and guarded.
3. **The owner never passed `originSaltFingerprint`** and re-encoded its reply
   with `null`, which would have made the salt fail-closed check silently
   inoperative.

And the threat is not present: iOS/HealthKit background delivery arrives on the
root isolate. The second-isolate writer is the Android/Health Connect shape,
which Milestone 01 defers.

Safely wiring it would require redesigning the repository abstraction, the
backup-exclusion callbacks, salt-fingerprint propagation, platform messaging,
and a Health Connect background execution model that does not exist until S-01.

---

## 3. Why it is removed rather than kept

**Dead production code described as a protection layer is worse than no layer.**

A closure critic confirmed the prototype was reachable only from its own tests:
zero references in `lib/`, `test/`, or `integration_test/`. Meanwhile
`TECHNICAL/PERSISTENCE_CONCURRENCY.md` described it as layer 1 of three, and its
own doc asserted a rule — *no in-process caller may construct its own
`SaveRepository` over a directory an owner is serving* — that was unviolated only
because no owner was ever serving. A future reader would have counted three
layers and had two.

It is preserved in git history at `9fbb66c` and its design findings are recorded
in `TECHNICAL/PERSISTENCE_CONCURRENCY.md`. It is **not** retained as
experimental runtime code, and **no speculative replacement interface was
created during F-06**.

Its one piece of irreplaceable evidence — what the raw kernel lock does between
two isolates in one process — is preserved as an executed probe in
`packages/stride_storage/test/linux_lock_semantics_test.dart`. That probe
asserts no locking outcome, because the outcome is platform-dependent in the
worst direction: Windows reports `refused`, Linux reports `acquired`.

---

## 4. Enforcement

`Scripts/check-single-writer.sh`, run by `Scripts/verify.sh` and by CI.

- Enumerates **approved production construction sites** as `path|Symbol` pairs.
  Six sites, in two files.
- Scans **production source only**. Tests construct repositories directly on
  purpose; scanning them would make the guard meaningless.
- Rejects any construction elsewhere, and any background execution entry point
  at all.
- **`--self-test` injects three violations and asserts each is rejected**: a
  background isolate constructing a repository, a plain unauthorized
  construction with no background marker, and a background entry point that
  touches no persistence type. The third exists so check B is proven
  independently of check A.

It deliberately does **not** count occurrences. Two earlier guards in this
repository were defeated by a closure critic for exactly that: one matched
`\.eraseAll\s*\(` and could not see a bare self-call, the other counted call
sites and was satisfied by a no-op decoy while the real site was deleted. An
allow-list has nothing to inflate.

---

## 5. Consequences

- The concurrency guarantee is now **architectural**, not runtime. If the rule
  is broken, the guard fails the build; there is no mechanism that would make a
  second writer isolate safe.
- Adding a background entry point is a **blocked** action until S-01, not a
  reviewable one.
- `packages/stride_storage/test/cross_process_lock_test.dart` and
  `persistence_owner_test.dart` were removed with the prototype; their surviving
  properties are re-proved owner-free in `linux_lock_semantics_test.dart`.

## 6. Follow-up

- **S-01** — design and validate a real persistence coordinator before enabling
  any Health Connect background writer. It must carry the per-write
  backup-exclusion hook and `originSaltFingerprint` across the port, which the
  prototype did not.
- The Linux concurrency proofs must keep running in CI. Linux is the signal;
  Windows is the permissive-looking platform and is not evidence for layer 1.
