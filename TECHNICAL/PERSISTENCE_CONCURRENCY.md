# Persistence concurrency

**Model:** single-writer-isolate
**Decision:** `DECISIONS/0013_SINGLE_WRITER_PERSISTENCE.md`
**Evidence:** `packages/stride_storage/test/linux_lock_semantics_test.dart`
**Enforcement:** `Scripts/check-single-writer.sh`

---

## The model in one paragraph

Exactly **one isolate** may touch the save directory. Within that isolate, two
repository instances are serialized by a path-keyed mutex. Across separate OS
processes, an advisory file lock excludes a second writer. Every commit is
additionally guarded by compare-and-swap. **No layer serializes two isolates**,
and none is intended to — that case is prohibited by architecture rule and
enforced by a build guard, not handled at runtime.

---

## The four things you must not misread

### 1. No background persistence isolate is currently active

There is none. Not disabled, not dormant — absent. The app has exactly one
writer, constructed in `lib/runtime/runtime_bootstrap.dart`.

### 2. The removed owner prototype is not a production protection layer

A `PersistenceOwner` isolate was built during F-06 and **removed** at
`DECISIONS/0013`. It never ran outside its own tests. It is preserved in git
history at `9fbb66c`; its design findings are in §5 below. If a document, a
comment, or a memory tells you an owner isolate protects anything here, that text
is stale — check the tree.

### 3. Background Health Connect writing is prohibited

Not discouraged. Prohibited, and enforced: `Scripts/check-single-writer.sh`
rejects any background execution entry point in production source, whether or not
it touches persistence.

### 4. S-01 must design and validate the real coordinator before enabling it

Before any Health Connect background writer is turned on. It must carry the
per-write backup-exclusion hook and `originSaltFingerprint` across the port — the
prototype did neither, which is part of why it was not wired.

---

## The three layers

| # | Layer | Mechanism | Serializes | Does **not** cover |
|---|---|---|---|---|
| 1 | Path-keyed in-isolate mutex | Static map from canonical lock-file path to a FIFO mutex, in `file_lock.dart` | Two `SaveRepository` / `FileTransactionLock` instances in **one isolate** | A second isolate — a Dart static is copied per isolate |
| 2 | OS advisory lock | `RandomAccessFile.lock(FileLock.exclusive)` → `fcntl` on POSIX, `LockFileEx` on Windows | Separate OS **processes** | **Anything inside one process, on POSIX** |
| 3 | Compare-and-swap | `CommitExpectation` checked against the durable head, in `save_repository.dart` | Commits against a head that moved, whatever moved it | Ordering — it detects, it does not prevent |

None of these replaces another.

## Layer 2 is weaker than it looks, and this is the important section

`FileTransactionLock` calls `RandomAccessFile.lock(FileLock.exclusive)`, which
maps to different kernel primitives on different platforms:

- **Linux and macOS** use `fcntl` record locks. **`fcntl` locks belong to the
  process**, not to the descriptor and not to the thread. A second acquirer in the
  same process asks for a lock the kernel believes it already granted to that
  owner, and is granted it again. Worse, closing *any* descriptor onto that file
  drops the whole process's locks on it.
- **Windows** uses `LockFileEx`, whose locks belong to the *handle*. A second
  acquirer in the same process **is** refused.

Stated at full strength:

> **On Linux and macOS the OS file lock serializes nothing at all within one
> process.** Not two isolates, and not two `SaveRepository` instances in the
> *same* isolate. Android is Linux.

This was originally recorded here as an isolate-only caveat, with the OS lock
described as serializing separate processes "except for isolates". That was too
generous by exactly one case, and it was the more likely case. CI run
`30767931205` on ubuntu is where it surfaced — **94 passed, 11 failed**, against
105/105 on Windows:

```
S1 same-process exclusion: a second FileTransactionLock over the same file is refused
Expected: null      Actual: <Instance of '_FileLockHandle'>
```

Downstream it produced `totalGranted` of 7 where 0 was required — grant-accounting
divergence — and the `-1` journal-fork sentinel.

The failure mode is the worst-shaped one available: the property *looks* proven on
a Windows development machine and is simply absent on the shipping platform. A
green local run was evidence for the opposite of what it appeared to say.

### What closes the same-process half

`FileTransactionLock` takes an **in-isolate mutex, keyed on the canonical
lock-file path, before it opens the file** and before it asks the kernel for
anything.

Before the open, not merely before the kernel call, and that ordering is
load-bearing: on POSIX a losing acquirer that had opened the file would, on
timing out and closing its descriptor, drop the *winner's* lock. Releasing the
mutex last — after the close, in a `finally` — is the same argument from the other
end. Under that ordering at most one descriptor onto the lock file is ever open in
this isolate.

The mutex wait is **bounded by the same deadline** as the lock poll, so contention
stays a typed `storageBusy` and never becomes a hang.

### What nothing closes

A Dart `static` is copied per isolate, so the mutex table in a second isolate is a
different table. Combined with the descriptor-close hazard — which sits below the
level any Dart-side mechanism can reach — a second writer isolate is **prohibited
rather than handled**. That is the whole content of the single-writer model.

---

## Evidence

`packages/stride_storage/test/linux_lock_semantics_test.dart` is the named
evidence file. It runs on every platform and must pass on every platform, but
**Linux is the signal**.

| Property | Status |
|---|---|
| Two repository instances in one isolate are serialized; no journal fork | Executed |
| A second `FileTransactionLock` in this isolate is refused while the first holds | Executed |
| A separate OS process is excluded, with a typed busy result on load, commit, compact and eraseAll | Executed |
| Process death releases the OS lock | Executed |
| CAS rejects stale state and writes nothing | Executed |

Plus one **caveat probe**, which asserts no locking outcome on purpose:

> *cross-process exclusion does NOT prove same-process isolate exclusion*

It spawns a second isolate, has it attempt the raw kernel lock, and **records** the
answer. Windows reports `refused`; Linux reports `acquired`. Pinning either would
make the suite red on one platform for a true reason. Cross-process success must
never be quoted as same-process isolate exclusion — that conflation is what this
document exists to prevent.

### Corrections to what this document used to claim

Recorded because it was the same class of mistake twice: asserting evidence that
had not been produced.

- It claimed the cross-process refusal was *"named again on Linux in CI"*. It had
  not been. That text was written before any such run existed.
- `concurrency_test.dart`, `closure_probes_test.dart`, `cross_process_lock_test.dart`
  and `persistence_owner_test.dart` had **never run on Linux** before run
  `30767931205`. Every earlier F-06 run died at the format check or earlier, in the
  same job, before reaching the storage step.
- It listed the owner isolate as layer 1 of four and described it as serializing
  cross-isolate callers. It never ran outside its own tests, and it is now removed.

---

## §5 — design findings from the removed owner prototype

Preserved because they are the useful residue of the work, and because S-01 will
need them.

- **A `SendPort` to a dead isolate accepts messages and drops them silently.** No
  error, no close event. A caller holding only the owner's port waits forever. The
  supervisor must therefore live in the **spawning** isolate, not in the owner,
  plus a per-request timeout as a backstop. A supervision scheme that is merely
  *believed* complete is how a permanent silent hang happens.
- **Do not send engine objects across the port.** Dart would deep-copy the graphs,
  but that makes the wire format an accident of whichever fields the engine had
  that day. Use the save codec — the one encoding that is versioned, digested, and
  round-trip tested.
- **Exactly-once needs caller-assigned request ids**, one reply to the port carried
  in that request, and removal of the pending entry on first delivery, so a
  duplicate reply cannot complete a completer twice.
- **Storage conditions and owner-liveness conditions must stay distinguishable.**
  Routing a dead owner into `CommitRefused(storageBusy, 'nothing was written')` is
  a lie: an owner killed between a durable journal append and its reply leaves an
  outcome nobody observed. Both mean "do not release the cursor"; only one means
  "nothing happened".
- **The coordinator must carry the per-write backup-exclusion hook and
  `originSaltFingerprint`.** The prototype constructed its stores without the hook
  and re-encoded loads with a null fingerprint, which would have removed the
  iCloud-restore control and silently disabled the salt fail-closed check.
- **`SaveRepository` being a `final class` blocks substitution.** S-01 will need an
  extracted interface in `stride_core` that `BootstrapCoordinator` can be typed
  against, because bootstrap is where the first load and the new-game commit happen.
