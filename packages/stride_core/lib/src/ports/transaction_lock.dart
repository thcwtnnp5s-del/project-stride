/// An exclusive lock held across a whole save transaction.
///
/// ## Why an in-process queue was not enough
///
/// `SaveRepository` serializes its own operations through a future queue, and
/// that is necessary but not sufficient. Each repository instance has its own
/// queue, so two instances over one directory — an app resuming while a
/// background worker syncs, which is exactly what Health Connect delivery
/// introduces — hold two independent queues that know nothing about each other.
///
/// Both then read the same durable head, both find their compare-and-swap
/// expectation satisfied, both compute the same next transaction id, and both
/// append. CAS is checked and released *before* the append; it is not atomic
/// across instances and nothing on disk enforces it.
///
/// Either outcome loses: matching record shapes are absorbed as a duplicate and
/// that batch of granted steps is silently gone, or differing shapes give
/// `journalForked`, which compaction cannot clear — because compaction only
/// runs inside a commit and a commit needs a load. That one is a permanent
/// brick.
///
/// ## What the implementation must provide
///
/// A **real OS-level exclusive lock**, not a sentinel file whose existence is
/// checked. An existence check has a race between the check and the create, and
/// it survives a process kill: a crashed holder leaves the sentinel behind and
/// every later launch refuses forever. An OS lock is released by the kernel
/// when the holding process dies, which is the property that matters.
///
/// On `dart:io` that is `RandomAccessFile.lock(FileLock.exclusive)`, which maps
/// to `flock`/`fcntl` on POSIX and `LockFileEx` on Windows.
library;

import 'package:meta/meta.dart';

/// Why a transaction could not start.
enum LockRefusal {
  /// Another holder kept the lock past the acquisition timeout.
  ///
  /// Bounded on purpose: an unbounded wait against a holder that never yields
  /// is a hang, and a hang during a step sync is indistinguishable, to the
  /// player, from the game losing their walk.
  storageBusy,

  /// The lock could not be created or opened at all.
  storageUnavailable,
}

/// Thrown only when a caller misuses the lock, never for contention.
///
/// Contention is an outcome; a double release is a bug.
final class LockStateError extends StateError {
  LockStateError(super.message);
}

/// A held lock. Released exactly once, in a `finally`.
abstract interface class TransactionLockHandle {
  /// Releases the lock and closes the underlying handle.
  ///
  /// Must tolerate being called after the process has already lost the lock —
  /// releasing something the kernel already reclaimed is not an error.
  Future<void> release();
}

/// Acquires the whole-transaction lock.
abstract interface class TransactionLock {
  /// Waits up to [timeout] for exclusive access.
  ///
  /// Returns null on contention rather than throwing, because a busy save is an
  /// ordinary state the caller must handle and not an exceptional one.
  Future<TransactionLockHandle?> acquire(Duration timeout);
}

/// A lock that is always immediately available.
///
/// For the in-memory implementations, where there is no medium to contend over
/// and the repository's own queue already serializes everything. **Never for a
/// real filesystem** — using it there would restore precisely the cross-instance
/// race this port exists to close.
@immutable
final class UncontendedLock implements TransactionLock {
  const UncontendedLock();

  @override
  Future<TransactionLockHandle?> acquire(Duration timeout) async =>
      const _UncontendedHandle();
}

@immutable
final class _UncontendedHandle implements TransactionLockHandle {
  const _UncontendedHandle();

  @override
  Future<void> release() async {}
}
