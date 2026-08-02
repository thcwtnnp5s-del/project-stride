# Persistence concurrency — the three layers

**Status:** F-06. Applies to `packages/stride_storage` and `packages/stride_core/lib/src/save/`.

Project Stride's save directory can be reached by more than one writer at a time.
On Android, Health Connect background delivery is the concrete case: the app is in
the foreground while a background worker syncs steps. Two writers over one save
directory, unguarded, either lose a batch of granted steps or fork the journal —
and a forked journal is a **permanent brick**, because `journalForked` refuses
every load, and the only thing that can clear it is compaction, which runs inside
a commit, which needs a load.

Three separate mechanisms guard that. They are **not** redundant, none replaces
another, and each proves something the other two do not.

| Layer | Where | Serializes | Does **not** cover |
|---|---|---|---|
| 1. Persistence-owner isolate | `stride_storage/lib/src/persistence_owner.dart` | callers **within one OS process**, across isolates | a second OS process |
| 2. OS advisory file lock | `stride_storage/lib/src/file_lock.dart` | **separate OS processes** | isolates inside one process, on POSIX |
| 3. Compare-and-swap | `stride_core/lib/src/save/save_repository.dart` | commits against a head that moved, whatever moved it | nothing it is asked to; it is a check, not a lock |

---

## The POSIX caveat, in plain language

`FileTransactionLock` calls `RandomAccessFile.lock(FileLock.exclusive)`. That maps
to different kernel primitives on different platforms, and the difference matters
more than it looks:

- **Linux and macOS** use `fcntl` record locks. **`fcntl` locks belong to the
  process, not to the file descriptor and not to the thread.** If one isolate
  holds the lock and a second isolate in the *same process* asks for it, the
  kernel sees the same owner and **grants it**. Worse, closing *any* descriptor
  onto that file drops the whole process's locks on it.
- **Windows** uses `LockFileEx`, whose locks belong to the *handle*. A second
  isolate in the same process **is** refused.

Two isolates share one process. So:

> **The OS file lock does not serialize two isolates on Linux or macOS. Android
> is Linux. The exact case `file_lock.dart` was introduced to make safe — a
> Health Connect background isolate running beside the app — is the case it does
> not cover.**

And the failure mode is the worst-shaped one available: the property *looks*
proven on a Windows development machine and is simply absent on the shipping
platform. A green local test run was evidence for the opposite of what it
appeared to say.

### What cross-process test success does and does not prove

`packages/stride_storage/test/cross_process_lock_test.dart` starts a **second
operating-system process**, has it take the lock, and asserts that the owner is
refused with the typed busy result and writes nothing. `concurrency_test.dart`
case 6 does the same for a raw repository.

Those tests are correct, they are green, and CI runs them on Linux.

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

One isolate owns the save directory. Every in-process caller reaches persistence
by sending it a message.

**No in-process caller may construct its own `SaveRepository` over a directory
an owner is serving.** Doing so restores exactly the race this layer closes, and
on POSIX nothing underneath will catch it.

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

## Layer 2 — the OS advisory lock

Kept, and not optional. A second OS process has no way to reach layer 1's ports.
Its other property is the one a sentinel file cannot have: **the kernel releases
it when the holder dies.** A sentinel survives a process kill, so a crashed
holder would make every later launch refuse forever — and Android kills apps
routinely.

Held across the **whole** transaction, not just the append: from reading the
durable head, through CAS validation, the journal append and read-back, the
snapshot write, and compaction. Narrowing it to the append alone would leave the
read-head-to-append window open, which is where the race lives.

---

## Layer 3 — compare-and-swap

Kept, and not made redundant by either lock. Locks answer "is anyone else inside
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

| Property | Test | Runs on |
|---|---|---|
| Caller isolates are serialized through one owner | `persistence_owner_test.dart` case 1 | all |
| N requests produce N results, no duplicate, no loss | case 2 | all |
| No journal fork under isolate concurrency | case 3 | all |
| Owner death is typed and recoverable | case 4 | all |
| A second **process** is refused, with the typed busy result | `cross_process_lock_test.dart` | all; named again on Linux in CI |
| Cross-process success does **not** prove isolate exclusion | `persistence_owner_test.dart` case 6 | all; the Linux run is the informative one |

Nothing is skipped, conditionally or otherwise. The CI step
*stride_storage concurrency proofs (Linux, no skips allowed)* fails if a skip
ever appears, because a platform-guarded skip there would silently retire the
only proof that runs on the semantics we actually ship.

### What none of it proves

`dart test` runs in one process on a developer machine or a CI runner. These
tests prove the *protocol* and the *serialization*. They are not evidence about
real Android process death, real Health Connect background delivery, or a device
whose write cache does not honour a barrier. That evidence needs a device, and it
is tracked separately.
