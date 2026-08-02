# Persistence concurrency — the three layers

**Status:** F-06. Applies to `packages/stride_storage` and `packages/stride_core/lib/src/save/`.

Project Stride's save directory can be reached by more than one writer at a time.
On Android, Health Connect background delivery is the concrete case: the app is in
the foreground while a background worker syncs steps. Two writers over one save
directory, unguarded, either lose a batch of granted steps or fork the journal —
and a forked journal is a **permanent brick**, because `journalForked` refuses
every load, and the only thing that can clear it is compaction, which runs inside
a commit, which needs a load.

Four separate mechanisms guard that. They are **not** redundant, none replaces
another, and each covers something the others do not.

| Layer | Where | Serializes | Does **not** cover |
|---|---|---|---|
| 1. Persistence-owner isolate | `stride_storage/lib/src/persistence_owner.dart` | callers **within one OS process**, across isolates | a second OS process — **and it is not wired into the app**; see below |
| 2. In-isolate path mutex | `stride_storage/lib/src/file_lock.dart` | two acquirers **inside one isolate** — two `FileTransactionLock`s, two `SaveRepository`s, two overlapping operations | a second isolate: Dart copies `static` state per isolate, so a second isolate gets its own table and its own mutex |
| 3. OS advisory file lock | `stride_storage/lib/src/file_lock.dart` | **separate OS processes** | **anything inside one process, on POSIX** — see the next section |
| 4. Compare-and-swap | `stride_core/lib/src/save/save_repository.dart` | commits against a head that moved, whatever moved it | nothing it is asked to; it is a check, not a lock |

**The app is covered by layers 2, 3 and 4 only.** Layer 1 exists, is tested, and
is reached by nothing outside its own test file. What that leaves open, and why,
is spelled out under Layer 1.

---

## The POSIX caveat, in plain language

`FileTransactionLock` calls `RandomAccessFile.lock(FileLock.exclusive)`. That maps
to different kernel primitives on different platforms, and the difference matters
more than it looks:

- **Linux and macOS** use `fcntl` record locks. **`fcntl` locks belong to the
  process, not to the file descriptor and not to the thread.** A second acquirer
  in the same process asks the kernel for a lock the kernel believes it already
  granted to that owner, and is granted it again. Worse, closing *any* descriptor
  onto that file drops the whole process's locks on it.
- **Windows** uses `LockFileEx`, whose locks belong to the *handle*. A second
  acquirer in the same process **is** refused.

So, stated at full strength:

> **On Linux and macOS the OS file lock serializes nothing at all within one
> process.** Not two isolates, and not two `SaveRepository` instances in the
> *same* isolate. Android is Linux. Two objects in one isolate racing over one
> save directory — which is the ordinary shape of an app committing while a
> sync completes — were unguarded by it.

This was originally recorded here as an isolate-only caveat, with the OS lock
described as serializing separate processes "except for isolates". That was too
generous by exactly one case, and it was the more likely case. CI run
`30767931205` on ubuntu is where it surfaced: `concurrency_test.dart` case 0
constructs two acquirers in one isolate, and Linux granted both.

And the failure mode is the worst-shaped one available: the property *looks*
proven on a Windows development machine and is simply absent on the shipping
platform. A green local test run was evidence for the opposite of what it
appeared to say.

### What closes the same-process half

`FileTransactionLock` takes an **in-isolate mutex, keyed on the canonical
lock-file path, before it opens the file** and before it asks the kernel for
anything. Layer 2 in the table above.

Before the open, not merely before the kernel call, and that ordering is
load-bearing: on POSIX a losing acquirer that had opened the file would, on
timing out, close its descriptor — and that close drops the whole process's
locks on the file. The winner would keep believing it was exclusive while a
genuine second process walked in. Holding the mutex across the open means at
most one descriptor onto the lock file is ever open in this isolate.

Three further properties, each of which has a probe:

- **The key is canonical, not the raw string.** The resolved parent directory
  plus the file's own name, case-folded on Windows only. Four spellings of one
  path would otherwise be four mutexes over one inode, which is no mutex. The
  honest limitation: a symlink whose *final* segment is the lock file itself is
  not followed. Resolving the full path would require the file to exist, which
  would put the open outside the mutex.
- **The wait is bounded and spends the caller's `lockTimeout`.** There are now
  two mutexes per operation — `SaveRepository`'s per-instance writer queue and
  this global per-path one — so a caller that reaches persistence from inside
  its own transaction, or that touches two repositories, can order them
  differently. Bounded acquisition makes that a typed `storageBusy` refusal
  rather than a hang, which is the same reason `maxCommitRetries` is bounded.
- **It is per isolate and cannot be anything else.** Dart copies `static` state
  into every isolate. A spawned isolate gets its own empty table and its own
  mutexes, and both proceed. It closes the same-isolate hole and closes nothing
  else.

### The descriptor-close hazard, which no mutex can reach

Independently of any lock: on POSIX, closing any descriptor onto a file drops
every `fcntl` lock the *process* holds on it. Two isolates that each merely open
and close the lock file will silently strip each other's kernel locks — no
error, no exception, no observable event. An in-isolate mutex cannot see it,
because the other party is not in this isolate.

This is the second, independent reason a second isolate must never be pointed at
a save directory this one is serving. The first is that the OS lock would not
have excluded it either.

### What cross-process test success does and does not prove

`packages/stride_storage/test/cross_process_lock_test.dart` starts a **second
operating-system process**, has it take the lock, and asserts that the owner is
refused with the typed busy result and writes nothing. `concurrency_test.dart`
case 6 does the same for a raw repository.

Those tests are correct. They passed on Linux for the first time in CI run
`30767931205`; before that run they had only ever been executed on Windows.

**They say nothing whatsoever about two isolates in one process.** A Linux run
passing them is fully compatible with the lock being completely transparent
between isolates — which, on Linux, it is. The two properties are different
properties. They must never again be cited for each other.

`packages/stride_storage/test/persistence_owner_test.dart` case 6 exists solely
to keep that distinction on the record. It is named for the confusion, it
*observes* what the raw kernel lock does between two isolates on whichever host
it runs on, prints the observation into the log, and asserts no locking outcome
at all — because the outcome is platform-dependent. What it asserts instead is
that the owner isolate serializes them either way.

---

## Layer 1 — the persistence-owner isolate

> **Status: built, tested, and not wired into the app.** `bootstrapStride`
> constructs a plain `SaveRepository` and hands it out as
> `StrideRuntime.repository`. Nothing in `lib/` or `integration_test/`
> references `PersistenceOwner` or `PersistenceClient`; its only callers are its
> own tests. Read the rest of this section as a design that is exercised, not as
> a control that is deployed.

One isolate owns the save directory. Every in-process caller reaches persistence
by sending it a message.

**No in-process caller may construct its own `SaveRepository` over a directory
an owner is serving.** Doing so restores exactly the race this layer closes, and
on POSIX nothing underneath will catch it.

### Why it is not wired, and what would have to change

Three concrete blockers, none of them a matter of effort:

1. **`SaveRepository` is a `final class`.** `BootstrapCoordinator.repository` is
   typed against it, so a `PersistenceClient`-backed adapter cannot be
   substituted — Dart forbids implementing a `final` class. Bootstrap is where
   the first load and the new-game commit happen, so an owner that bootstrap
   cannot reach is an owner that does not own the directory. Closing this means
   extracting an interface in `stride_core`.
2. **The per-write backup-exclusion hook cannot cross the port.** It is a
   closure over a Flutter `MethodChannel`. `_Owner.build` constructs
   `FileSnapshotStore`, `FileLedgerJournal` and `FileTransactionLock` with no
   `reapplyExclusion` at all, so routing the app through the owner would delete
   a shipped iCloud-restore control — the one `Scripts/check-backup-exclusions.sh`
   guards — in exchange for a race the app does not currently have.
3. **The owner's load does not carry `originSaltFingerprint`.** `_Owner._load`
   calls `repository.load(registry:, treatAsRelease:)` and nothing else, and
   re-encodes the reply with `originSaltFingerprint: null`. The salt fail-closed
   check — the thing that stops a restored device replaying a step ledger
   against a HealthKit source the first device already consumed from — would be
   silently inoperative.

**The case it defends against does not exist at Milestone 01.** The milestone
ships iOS with HealthKit, whose background delivery arrives on the root isolate.
The second-isolate writer is the Android/Health Connect shape, and Android is
explicitly deferred. So this is infrastructure ahead of its requirement, which
the project's own code philosophy lists under *avoid*.

**Recommendation:** either wire it — which means (1), (2) and (3) first, as one
piece of work when Android is actually on the table — or delete it and recover
it from history at that point. Keeping it unwired and *labelled as a deployed
layer*, which is what this document previously did, is the one option with no
upside: it made the app look protected against a case nothing protected it from.
It is retained for now rather than deleted only because `.github/workflows/ci.yml`
names `persistence_owner_test.dart` in the Linux concurrency-proof step, and
`persistence_owner_test.dart` case 6 is currently the only executed evidence of
what the raw kernel lock does between two isolates.

- `PersistenceOwner.spawn(config)` starts the owner and supervises it.
- `PersistenceOwner.endpoint` is a sendable address. Any isolate can hold it.
- `PersistenceClient.connect(endpoint)` registers a caller.
- The client exposes `load`, `commit`, `compact`, `eraseAll`, plus a `stats`
  diagnostic.

**Requests are executed strictly one at a time**, through a single future chain
inside the owner. `stats().maxConcurrentHandlers` reports the high-water mark of
concurrently-running handlers; the tests assert it is 1, and the owner also keeps
a bounded `begin:`/`end:` trace so the serialization can be read rather than
trusted.

**Exactly-once.** Each request carries a caller-assigned id. The owner replies
once, to the port carried in that request. The client removes the pending entry
on first delivery, so a duplicated reply cannot complete a completer twice.

### What crosses the port

Primitives, `String`s, `Uint8List`s and `SendPort`s — nothing else. `GameState`
and `GameEvent` travel through the **existing save codec**: state as
`encodeSnapshot`/`decodeEnvelope`, events as
`encodeJournalLine`/`decodeJournalLine`.

Dart would happily deep-copy most object graphs between isolates in one group.
Relying on that would make the wire format an accident of whichever fields the
engine happened to have on the day. The save codec is the one encoding that is
versioned, digested, and already tested for round-trip fidelity.

### Owner death, and the two failures that must stay apart

The supervisor lives in the isolate that *spawned* the owner, so it outlives it.
That is structural, not incidental: **a `SendPort` to a dead isolate accepts
messages and drops them silently** — no error, no exception, no close event — so
a caller holding only the owner's port would wait forever. The supervisor
registers `onExit` and `onError`, and broadcasts the death to every registered
client, which fails every waiting request.

Independently, **every request carries a timer**. A supervision scheme that is
merely *believed* to be complete is how a save system acquires a permanent silent
hang.

Two conditions, deliberately not merged:

| Condition | Result | Why separate |
|---|---|---|
| **Storage busy** — another *process* holds the OS lock | the core's own `storageBusy`: `LoadRefusal`, `CommitRefusal`, `CompactionRefusal`, `EraseRefusal` | The owner was there, took no lock, and **wrote nothing**. It can promise that. |
| **Owner unreachable** — killed, uncaught error, no reply | `PersistenceUnavailable(PersistenceFailure…)` thrown | It **cannot** promise that. An owner killed between a durable journal append and its reply leaves an outcome nobody observed, and `storageBusy`'s "nothing was written" would be a false statement. |

Both mean the same thing at the call site — *do not release the step cursor, try
again* — and that is safe because F-04 grants `max(0, observed - granted)` and
the journal absorbs an identical duplicate. They still must stay distinguishable,
because one is an ordinary Tuesday and the other wants an owner restart.

Recovery is explicit: `PersistenceOwner.restart()`. The owner never respawns
itself, because an owner that did would loop on a save it cannot read, taking the
OS lock on every pass — turning a diagnosable fault into a directory nothing else
can open.

---

## Layer 3 — the OS advisory lock

Kept, and not optional. A second OS process has no way to reach layer 1's ports,
and the in-isolate mutex of layer 2 is invisible to it.
Its other property is the one a sentinel file cannot have: **the kernel releases
it when the holder dies.** A sentinel survives a process kill, so a crashed
holder would make every later launch refuse forever — and Android kills apps
routinely.

Held across the **whole** transaction, not just the append: from reading the
durable head, through CAS validation, the journal append and read-back, the
snapshot write, and compaction. Narrowing it to the append alone would leave the
read-head-to-append window open, which is where the race lives.

---

## Layer 4 — compare-and-swap

Kept, and not made redundant by any lock. Locks answer "is anyone else inside
right now"; CAS answers "is the durable state still the one this caller reasoned
about". A caller that loaded, thought for a while, and then committed can be
stale without any lock ever having been contended.

`CommitExpectation` carries the generation and last transaction the caller
loaded. The commit lands only if durable state still matches. The retry budget is
bounded on purpose: an unbounded retry loop against a writer that never yields is
a hang, and a hang during a step sync looks to the player exactly like the game
losing their walk.

---

## Evidence

Only executed runs are listed. "Executed on Linux" below means a named CI run
whose log shows the test passing — not that the file exists and is not skipped.

| Property | Test | Executed on |
|---|---|---|
| Caller isolates are serialized through one owner | `persistence_owner_test.dart` case 1 | Windows; Linux in run `30767931205` |
| N requests produce N results, no duplicate, no loss | case 2 | Windows; Linux in run `30767931205` |
| No journal fork under isolate concurrency | case 3 | Windows; Linux in run `30767931205` |
| Owner death is typed and recoverable | case 4 | Windows; Linux in run `30767931205` |
| A second **process** is refused, with the typed busy result | `cross_process_lock_test.dart` | Windows; Linux in run `30767931205` |
| Cross-process success does **not** prove isolate exclusion | `persistence_owner_test.dart` case 6 | Windows (recorded *refused* — `LockFileEx`); Linux in run `30767931205` (recorded **acquired**, confirming the hole) |
| A second acquirer in one isolate never opens the lock file | `closure_probes_test.dart` case S6 | Windows; **not yet on Linux** |
| Two path spellings share one mutex | `closure_probes_test.dart` case S6 | Windows; **not yet on Linux** |
| The mutex wait is bounded and refuses in a typed way | `closure_probes_test.dart` case S6 | Windows; **not yet on Linux** |
| Same-process exclusion end to end | `concurrency_test.dart` cases 0–8, `closure_probes_test.dart` S1 | Windows; **failed on Linux** in run `30767931205`, which is what this change addresses |

### Corrections to what this section used to claim

- It said `cross_process_lock_test.dart` was "named again on Linux in CI". At the
  time that was written, no CI run had executed it on Linux at all.
  `concurrency_test.dart`, `closure_probes_test.dart`, `cross_process_lock_test.dart`
  and `persistence_owner_test.dart` first ran on Linux in run `30767931205`,
  where **94 passed and 11 failed**.
- The CI step *stride_storage concurrency proofs (Linux, no skips allowed)* has
  **never executed**. It is reported as `-` in run `30767931205` because the
  step before it failed, and no earlier run reached it either. Its no-skip guard
  is real and it is correctly written; it has simply never had the chance to
  run, and must not be cited as evidence until it has.
- Nothing is skipped, conditionally or otherwise. That remains true and is
  checked by the step above — once that step runs.

**The Linux CI run is the authoritative signal for every property in this
document.** A green Windows run says the opposite of what it appears to say
about layer 3, because `LockFileEx` is per-handle. The S6 probes were written
specifically so that layer 2 — the part that *is* platform-independent — can be
confirmed from a development machine without waiting for CI; they observe the
mutex directly rather than inferring it from a refusal the OS lock would have
produced anyway.

### What none of it proves

`dart test` runs in one process on a developer machine or a CI runner. These
tests prove the *protocol* and the *serialization*. They are not evidence about
real Android process death, real Health Connect background delivery, or a device
whose write cache does not honour a barrier. That evidence needs a device, and it
is tracked separately.
