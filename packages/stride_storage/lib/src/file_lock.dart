/// A real OS-level exclusive lock over the save directory.
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
library;

import 'dart:async';
import 'dart:io';

import 'package:stride_core/stride_core.dart';

import 'file_storage.dart' show StorageException;

/// An exclusive lock on one file, for the lifetime of one transaction.
final class FileTransactionLock implements TransactionLock {
  const FileTransactionLock(
    this.lockFile, {
    this.pollInterval = const Duration(milliseconds: 15),
  });

  final File lockFile;

  /// How often to retry while waiting.
  ///
  /// Dart offers no blocking-with-timeout lock: `FileLock.blockingExclusive`
  /// waits forever, which would turn contention into a hang. Polling a
  /// non-blocking `exclusive` lock is what makes the timeout expressible.
  ///
  /// Polling also keeps **two instances inside one isolate** safe. Each
  /// `SaveRepository` has its own future queue, so a second instance's
  /// transaction can begin while the first still holds the lock; the
  /// `Future.delayed` between attempts yields the event loop, letting the
  /// holder finish and release. A blocking wait would occupy an I/O thread
  /// for the whole timeout instead, and enough of them would starve the pool
  /// the holder itself needs to make progress — deadlock by exhaustion.
  final Duration pollInterval;

  @override
  Future<TransactionLockHandle?> acquire(Duration timeout) async {
    RandomAccessFile handle;
    try {
      final Directory parent = lockFile.parent;
      if (!parent.existsSync()) await parent.create(recursive: true);
      // Opened for write because a shared-mode open cannot take an exclusive
      // lock on Windows.
      handle = await lockFile.open(mode: FileMode.write);
    } on Object catch (e) {
      throw StorageException('open lock ${lockFile.path}', e);
    }

    final DateTime deadline = DateTime.now().add(timeout);
    while (true) {
      try {
        await handle.lock(FileLock.exclusive);
        return _FileLockHandle(handle, lockFile.path);
      } on FileSystemException {
        // Held by someone else. Not an error — contention is ordinary.
        if (!DateTime.now().isBefore(deadline)) {
          // Close our handle before giving up, or the descriptor leaks and a
          // long-running process eventually cannot open anything at all.
          await handle.close();
          return null;
        }
        await Future<void>.delayed(pollInterval);
      } on Object catch (e) {
        await handle.close();
        throw StorageException('lock ${lockFile.path}', e);
      }
    }
  }
}

final class _FileLockHandle implements TransactionLockHandle {
  _FileLockHandle(this._handle, this._path);

  final RandomAccessFile _handle;
  final String _path;
  bool _released = false;

  @override
  Future<void> release() async {
    // Idempotent. `release()` is called from a `finally`, and a `finally` that
    // can itself throw would mask the exception it is unwinding.
    if (_released) return;
    _released = true;
    try {
      await _handle.unlock();
    } on Object {
      // The kernel may have reclaimed it already — if the file was replaced, or
      // during shutdown. Unlocking something already unlocked is not a failure
      // worth propagating out of a cleanup path.
    }
    try {
      await _handle.close();
    } on Object catch (e) {
      throw StorageException('close lock $_path', e);
    }
  }
}
