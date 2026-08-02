/// A real OS-level exclusive lock over the save directory, plus the in-isolate
/// mutex the OS lock cannot supply on POSIX.
///
/// `RandomAccessFile.lock(FileLock.exclusive)` maps to `fcntl`/`flock` on POSIX
/// and `LockFileEx` on Windows. Two properties matter, and neither is available
/// from anything simpler:
///
/// **It is genuinely exclusive across processes.** A second process asking for
/// the same range is refused by the kernel, not by a check this code performs.
/// There is no window between testing and taking it.
///
/// **The kernel releases it when the holder dies.** This is the reason a
/// sentinel file is not an acceptable substitute. A sentinel has a race between
/// the existence check and the create, and — far worse — it *survives* a
/// process kill: a crashed holder leaves the file behind and every subsequent
/// launch refuses forever, turning a transient condition into a permanently
/// unstartable game. Android kills apps routinely, so that is not a rare case.
///
/// The lock file holds no data. It exists only to have something lockable, and
/// is never read or written — so a stale one is harmless and it is never
/// deleted, because deleting a file another process holds a lock on is exactly
/// how you end up with two processes locking two different inodes that share a
/// name.
///
/// ## What the OS lock does NOT do, and why this file has a mutex in it
///
/// On Linux and macOS Dart implements `RandomAccessFile.lock` with
/// `fcntl(F_SETLK)`. **`fcntl` record locks are owned by the process**, not by
/// the descriptor and not by the thread. A second acquirer inside the same
/// process — a second `FileTransactionLock`, a second `SaveRepository`, a
/// second isolate — asks the kernel for a lock the kernel believes it already
/// granted to that owner, and is granted it again. Within one process the OS
/// lock therefore serializes **nothing at all**.
///
/// On Windows it maps to `LockFileEx`, which is per-handle and does refuse. So
/// the property looks proven on a Windows development machine and is simply
/// absent on the platform the game ships to. A green Windows run is evidence
/// for the opposite of what it appears to say.
///
/// [FileTransactionLock] therefore takes an in-isolate mutex, keyed on the lock
/// file's canonical path, *before* it opens the file and asks the kernel for
/// anything. See [_PathMutex] for the four things that mutex does and does not
/// cover.
library;

import 'dart:async';
import 'dart:io';

import 'package:stride_core/stride_core.dart';

import 'file_storage.dart' show ReapplyBackupExclusion, StorageException;

/// An exclusive lock on one file, for the lifetime of one transaction.
final class FileTransactionLock implements TransactionLock {
  const FileTransactionLock(
    this.lockFile, {
    this.pollInterval = const Duration(milliseconds: 15),
    this.reapplyExclusion,
  });

  final File lockFile;

  /// Re-applied after the lock file is opened, which is what creates it.
  ///
  /// `transaction.lock` is in `StorageLayout.allFiles` and therefore in the
  /// audited set, so leaving it unexcluded makes the launch report internally
  /// inconsistent. It holds no data, so this is consistency rather than a leak.
  /// See [ReapplyBackupExclusion].
  final ReapplyBackupExclusion? reapplyExclusion;

  /// How often to retry while waiting.
  ///
  /// Dart offers no blocking-with-timeout lock: `FileLock.blockingExclusive`
  /// waits forever, which would turn contention into a hang. Polling a
  /// non-blocking `exclusive` lock is what makes the timeout expressible.
  ///
  /// A blocking wait would also occupy an I/O thread for the whole timeout, and
  /// enough of them would starve the pool the holder itself needs to make
  /// progress — deadlock by exhaustion.
  final Duration pollInterval;

  /// One mutex per canonical lock-file path, for this isolate.
  ///
  /// **Per isolate, not per process.** Dart copies static state into every
  /// isolate; a second isolate gets its own empty map and its own mutexes. This
  /// closes the same-isolate hole and closes nothing else. See [_PathMutex].
  static final Map<String, _PathMutex> _mutexes = <String, _PathMutex>{};

  @override
  Future<TransactionLockHandle?> acquire(Duration timeout) async {
    // One deadline for the whole acquire. The mutex wait, the canonicalization
    // I/O and the OS-lock polling all spend from it, because a caller asked for
    // `timeout` and not for `timeout` per internal stage. An unbounded wait
    // anywhere in here converts a `storageBusy` refusal — which the caller can
    // act on by keeping its step cursor and retrying — into a hang, which is
    // the exact failure `maxCommitRetries` is bounded to avoid.
    final DateTime deadline = DateTime.now().add(timeout);

    final String key = await _canonicalKey();
    final _PathMutex mutex = _mutexes.putIfAbsent(key, () => _PathMutex(key));

    // Taken BEFORE the open, not merely before the kernel call. On POSIX,
    // closing *any* descriptor onto a file drops every `fcntl` lock the process
    // holds on that file. If a losing acquirer opened the file and then closed
    // it on timeout, that close would strip the winner's lock while the winner
    // still believed it was exclusive. Holding the mutex across the open means
    // at most one descriptor onto this path is ever open in this isolate.
    if (!await mutex.acquire(_remaining(deadline))) {
      // The same typed refusal as an expired OS-lock wait: null means busy.
      // A caller must not be able to tell which stage refused, because both
      // mean "someone else is inside, nothing was written".
      return null;
    }

    RandomAccessFile handle;
    try {
      final Directory parent = lockFile.parent;
      if (!parent.existsSync()) await parent.create(recursive: true);
      // Opened for write because a shared-mode open cannot take an exclusive
      // lock on Windows.
      handle = await lockFile.open(mode: FileMode.write);
    } on Object catch (e) {
      _releaseMutex(mutex);
      throw StorageException('open lock ${lockFile.path}', e);
    }

    // The open above is what creates the lock file, so it is created after the
    // launch sweep looked for it.
    try {
      await reapplyExclusion?.call(<String>[lockFile.path]);
    } on Object {
      // Documented not to throw, but a hook that did would otherwise leak both
      // the descriptor and the mutex — a permanently wedged save directory for
      // this isolate. The error itself is preserved unchanged.
      await _closeQuietly(handle);
      _releaseMutex(mutex);
      rethrow;
    }

    while (true) {
      try {
        await handle.lock(FileLock.exclusive);
        return _FileLockHandle(
          handle,
          lockFile.path,
          () => _releaseMutex(mutex),
        );
      } on FileSystemException {
        // Held by another process. Not an error — contention is ordinary.
        if (!DateTime.now().isBefore(deadline)) {
          // Close our handle before giving up, or the descriptor leaks and a
          // long-running process eventually cannot open anything at all.
          await _closeQuietly(handle);
          _releaseMutex(mutex);
          return null;
        }
        // Never overshoot the deadline by a poll interval.
        final Duration left = _remaining(deadline);
        await Future<void>.delayed(left < pollInterval ? left : pollInterval);
      } on Object catch (e) {
        await _closeQuietly(handle);
        _releaseMutex(mutex);
        throw StorageException('lock ${lockFile.path}', e);
      }
    }
  }

  /// The mutex key: the resolved parent directory plus the file's own name.
  ///
  /// Keying on the raw path string would be wrong. `./saves/transaction.lock`,
  /// an absolute path, a path through a symlinked directory and a path with a
  /// redundant separator are four different strings naming one inode, and four
  /// different strings would be four different mutexes over that one inode —
  /// which is no mutex at all.
  ///
  /// `resolveSymbolicLinks` is the correct canonicalization, but it throws when
  /// the target does not exist, and the lock file is created by the very
  /// `open()` this key must precede. Resolving *after* the open would put the
  /// open outside the mutex, which is precisely what the POSIX descriptor-close
  /// hazard forbids. So the **parent directory** is resolved instead: it is
  /// guaranteed to exist (`StorageLayout.ensureExists`, and the create below),
  /// and it carries every symlink and relative segment in the path.
  ///
  /// **The honest limitation:** a symlink whose *final* segment is the lock file
  /// itself is not followed, so two paths differing only in that last hop would
  /// still key differently. Nothing in this project creates one, and the
  /// alternative costs the descriptor-close guarantee.
  Future<String> _canonicalKey() async {
    final Directory parent = lockFile.parent;
    String parentPath;
    try {
      if (!parent.existsSync()) await parent.create(recursive: true);
      parentPath = await parent.resolveSymbolicLinks();
    } on Object {
      // A directory that cannot be resolved will fail the open a moment later
      // with a real diagnostic. Falling back keeps this method from being the
      // one that reports it, and an absolute path is still a far better key
      // than the raw string.
      parentPath = parent.absolute.path;
    }

    final List<String> segments = lockFile.path
        .split(RegExp(r'[/\\]'))
        .where((String s) => s.isNotEmpty)
        .toList();
    final String name = segments.isEmpty ? '' : segments.last;
    final String key = '$parentPath${Platform.pathSeparator}$name';

    // NTFS and APFS-by-default are case-insensitive, so two spellings that
    // differ only in case are one file there and two files on Linux. Folding
    // case on Windows only is correct on both.
    return Platform.isWindows ? key.toLowerCase() : key;
  }

  static Duration _remaining(DateTime deadline) {
    final Duration left = deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  static Future<void> _closeQuietly(RandomAccessFile handle) async {
    try {
      await handle.close();
    } on Object {
      // Nothing useful to do on a cleanup path, and throwing here would mask
      // the refusal or the exception being unwound.
    }
  }

  /// Releases [mutex] and drops it from the table once nobody wants it.
  ///
  /// Pruning is safe because both halves are synchronous: `putIfAbsent` and the
  /// mutex's uncontended acquire happen in one turn of the event loop, as does
  /// `release`. No acquirer can be holding a reference to a mutex this method
  /// has just decided is idle.
  ///
  /// Without pruning the table would retain one entry per save directory ever
  /// locked. In the app that is one; in the test suite it is thousands.
  static void _releaseMutex(_PathMutex mutex) {
    mutex.release();
    if (mutex.isIdle) _mutexes.remove(mutex.key);
  }
}

/// A bounded, FIFO, in-isolate mutex over one canonical path.
///
/// It exists because the OS lock underneath it does not serialize a second
/// acquirer in the same process on POSIX. It is worth being exact about what
/// that buys and what it does not:
///
/// **Covers:** two `FileTransactionLock` instances, or two `SaveRepository`
/// instances, or any two overlapping operations, inside **this isolate**.
///
/// **Does not cover: a second isolate.** `static` state in Dart is *per
/// isolate*, not per process — a spawned isolate gets its own copy of the table
/// this mutex lives in, so two isolates take two different mutexes and both
/// proceed. Nothing in this file can close that; only a single-owner
/// arrangement above it can.
///
/// **Does not cover — and cannot see — the descriptor-close hazard.** On POSIX,
/// closing any descriptor onto a file drops the whole *process's* locks on that
/// file. Two isolates that each open and close the lock file will silently
/// strip each other's kernel locks, with no error and no observable event. That
/// is the second, independent reason a second isolate must never be pointed at
/// a save directory this one is serving.
///
/// **Bounded on purpose.** `acquire` takes a deadline and answers `false` when
/// it expires. Two mutexes are now in play per operation — `SaveRepository`'s
/// own per-instance writer queue, and this global per-path one — and any path
/// that touches two repositories in one isolate can order them differently and
/// deadlock. A bounded acquire makes that a typed `storageBusy` refusal instead
/// of a hang. The same boundedness is what lets an operation that re-enters
/// persistence from inside its own transaction (the mid-transaction probe in
/// `concurrency_test.dart` case 8 is exactly this shape) refuse rather than
/// wedge.
final class _PathMutex {
  _PathMutex(this.key);

  final String key;

  bool _held = false;
  final List<Completer<bool>> _waiters = <Completer<bool>>[];

  bool get isIdle => !_held && _waiters.isEmpty;

  /// Not `async`, deliberately: the uncontended path must mark the mutex held
  /// in the same event-loop turn as the call, so that `putIfAbsent` followed by
  /// `acquire` cannot interleave with a `release` that prunes the table.
  Future<bool> acquire(Duration timeout) {
    if (!_held) {
      _held = true;
      return Future<bool>.value(true);
    }

    final Completer<bool> waiter = Completer<bool>();
    _waiters.add(waiter);
    final Timer timer = Timer(timeout, () {
      if (waiter.isCompleted) return;
      _waiters.remove(waiter);
      waiter.complete(false);
    });
    return waiter.future.whenComplete(timer.cancel);
  }

  void release() {
    while (_waiters.isNotEmpty) {
      final Completer<bool> next = _waiters.removeAt(0);
      if (next.isCompleted) continue; // Timed out between grant and delivery.
      // Ownership passes directly. Clearing `_held` first would let a fresh
      // caller barge in front of a queue that has already waited.
      next.complete(true);
      return;
    }
    _held = false;
  }
}

final class _FileLockHandle implements TransactionLockHandle {
  _FileLockHandle(this._handle, this._path, this._releaseMutex);

  final RandomAccessFile _handle;
  final String _path;
  final void Function() _releaseMutex;
  bool _released = false;

  @override
  Future<void> release() async {
    // Idempotent. `release()` is called from a `finally`, and a `finally` that
    // can itself throw would mask the exception it is unwinding.
    if (_released) return;
    _released = true;
    try {
      try {
        await _handle.unlock();
      } on Object {
        // The kernel may have reclaimed it already — if the file was replaced,
        // or during shutdown. Unlocking something already unlocked is not a
        // failure worth propagating out of a cleanup path.
      }
      try {
        await _handle.close();
      } on Object catch (e) {
        throw StorageException('close lock $_path', e);
      }
    } finally {
      // Last, and unconditionally.
      //
      // Last, because on POSIX closing this descriptor drops the process's
      // locks on this file: the next in-isolate acquirer must not be able to
      // open and lock the file until this descriptor is gone, or our close
      // would strip the lock it just took.
      //
      // Unconditionally, because a close that failed still means this acquirer
      // is finished. Leaving the mutex held would wedge the save directory for
      // the life of the isolate — every later operation refusing `storageBusy`
      // against a holder that no longer exists.
      _releaseMutex();
    }
  }
}
