// Closure Critic probes — pure-core half.
//
// Every test here asserts the behaviour the shipped documentation claims. A
// failure is a defect in the code or a lie in the doc, never a defect here.
// Nothing in this file is skipped and nothing is weakened.

import 'dart:async';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'content_test_support.dart';
import 'save_support.dart';

// ---------------------------------------------------------------------------
// Locks that misbehave in the two ways a real one can.
// ---------------------------------------------------------------------------

/// Grants the lock, then throws when released.
///
/// `_FileLockHandle.release()` rethrows as `StorageException('close lock ...')`
/// when `RandomAccessFile.close()` fails, so this is a reachable state on a
/// real filesystem, not an invented one.
final class ThrowOnReleaseLock implements TransactionLock {
  const ThrowOnReleaseLock();

  @override
  Future<TransactionLockHandle?> acquire(Duration timeout) async =>
      const _ThrowingHandle();
}

final class _ThrowingHandle implements TransactionLockHandle {
  const _ThrowingHandle();

  @override
  Future<void> release() async => throw StateError('close lock failed');
}

/// Never available — the other-process-holds-it case.
final class AlwaysBusyLock implements TransactionLock {
  const AlwaysBusyLock();

  @override
  Future<TransactionLockHandle?> acquire(Duration timeout) async => null;
}

// ---------------------------------------------------------------------------
// Storage doubles with one specific fault each.
// ---------------------------------------------------------------------------

/// Empty storage that accepts snapshot writes and refuses journal appends.
///
/// Models a first launch on a device that has run out of space between the
/// identity write and the commit point.
final class EmptySnapshots implements SnapshotSlotStore {
  const EmptySnapshots();

  @override
  Future<Uint8List?> read(SnapshotSlot slot) async => null;

  @override
  Future<void> write(SnapshotSlot slot, Uint8List bytes) async {}

  @override
  Future<void> erase(SnapshotSlot slot) async {}
}

final class UnappendableJournal implements LedgerJournal {
  const UnappendableJournal();

  @override
  Future<List<Uint8List>> readLines() async => <Uint8List>[];

  @override
  Future<void> appendLine(Uint8List line) async =>
      throw StateError('no space left on device');

  @override
  Future<void> replaceLines(List<Uint8List> lines) async {}

  @override
  Future<bool> discardIncompleteCompaction() async => false;

  @override
  Future<void> erase() async {}
}

// ---------------------------------------------------------------------------
// An identity store that records exactly what was written.
// ---------------------------------------------------------------------------

final class RecordingIdentityStore implements ReconciliationIdentityStore {
  ReconciliationIdentity? _held;
  final List<ReconciliationIdentity> writes = <ReconciliationIdentity>[];
  int erases = 0;

  @override
  Future<ReconciliationIdentity?> read() async => _held;

  @override
  Future<void> write(ReconciliationIdentity identity) async {
    writes.add(identity);
    _held = identity;
  }

  @override
  Future<void> erase() async {
    erases++;
    _held = null;
  }
}

void main() {
  // =========================================================================
  // C1 — the single-writer queue must survive a failing lock release
  // =========================================================================
  //
  // `SaveRepository._serialized` chains every operation onto `_writer` with
  // `_writer = _writer.then(cb)`. `cb` catches everything the action throws,
  // but its `finally` calls `held.release()` OUTSIDE that catch. A release
  // that throws therefore completes `_writer` with an error, and `.then` on an
  // errored future never runs its callback -- so the Completer created by
  // every LATER call is never completed, and every later save, load,
  // compaction and erase hangs forever with no error and no log line.
  group('C1 writer queue poisoning', () {
    test('a failing lock release does not wedge the repository', () async {
      final FaultingDevice device = FaultingDevice();
      final SaveRepository repo = SaveRepository(
        snapshots: FaultingSnapshotStore(device),
        journal: FaultingJournal(device),
        lock: const ThrowOnReleaseLock(),
      );

      // First operation: the release throws after the result is completed, so
      // this one still succeeds.
      await repo.load(registry: saveRegistry);

      // Second operation. If `_writer` was poisoned this never completes.
      final LoadOutcome second = await repo
          .load(registry: saveRegistry)
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw StateError(
              'the repository is permanently wedged: _writer was completed '
              'with an error by a throwing release() and every later '
              'operation now hangs forever',
            ),
          );
      expect(second, isA<LoadOutcome>());

      // A third, to prove recovery is durable rather than one-shot.
      await repo
          .load(registry: saveRegistry)
          .timeout(const Duration(seconds: 2));
    });
  });

  // =========================================================================
  // C2 — no path through the repository re-enters _serialized
  // =========================================================================
  //
  // `_serialized` takes the lock inside the queue. A nested `_serialized` call
  // would wait on a queue entry that cannot finish until the nested one does.
  // `compact()` is public and calls `_serialized`; `_commitOnce` must reach
  // `_compact` directly. This is a regression guard on that, since the two
  // names differ by one underscore.
  group('C2 re-entrancy', () {
    test('commit, public compact and eraseAll all complete', () async {
      final ({SaveRepository repo, FaultingDevice device}) f = newRepo();
      final GameEngine engine = GameEngine.newGame(registry: saveRegistry);

      final EngineResult r = engine.execute(
        const GrantSyntheticSteps(steps: 500, reason: 'closure probe'),
      );
      final CommitOutcome out =
          await commit(
            f.repo,
            after: engine.state,
            events: r.events,
            generation: -1,
            lastTransaction: 0,
          ).timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw StateError('commit self-deadlocked'),
          );
      expect(out, isA<CommitDurable>());

      await f.repo.compact().timeout(
        const Duration(seconds: 2),
        onTimeout: () =>
            throw StateError('public compact() re-entered _serialized'),
      );

      await f.repo.eraseAll().timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw StateError('eraseAll() re-entered _serialized'),
      );
    });
  });

  // =========================================================================
  // C3 — contention produces typed refusals, not raw StateErrors
  // =========================================================================
  //
  // `commit` passes `onBusy`. `load`, `compact` and `eraseAll` do not, so a
  // busy save makes them throw a bare `StateError`. Bootstrap catches the load
  // one and reports `storageUnavailable`, which is the wrong reason: the
  // storage is available and in use. Nothing types the other two at all.
  group('C3 busy-storage surface', () {
    SaveRepository busyRepo() {
      final FaultingDevice device = FaultingDevice();
      return SaveRepository(
        snapshots: FaultingSnapshotStore(device),
        journal: FaultingJournal(device),
        lock: const AlwaysBusyLock(),
        lockTimeout: const Duration(milliseconds: 1),
      );
    }

    test('commit refuses with storageBusy and writes nothing', () async {
      final SaveRepository repo = busyRepo();
      final GameEngine engine = GameEngine.newGame(registry: saveRegistry);
      final EngineResult r = engine.execute(
        const GrantSyntheticSteps(steps: 100, reason: 'busy probe'),
      );

      final CommitOutcome out = await repo.commit(
        after: engine.state,
        events: r.events,
        saveId: testSaveId,
        expectation: const CommitExpectation(
          expectedSnapshotGeneration: -1,
          expectedLastAppliedTransaction: 0,
        ),
        originSaltFingerprint: null,
      );

      expect(out, isA<CommitRefused>());
      expect((out as CommitRefused).reason, CommitRefusal.storageBusy);
    });

    test('a busy load is a typed refusal, not an untyped throw', () async {
      // A busy save is an ordinary condition. Every other ordinary condition
      // in this protocol has a name in `LoadRefusal`; this one escapes as an
      // untyped `StateError` whose only description is an English sentence,
      // and reaches the player as "Stride could not read its save files",
      // which is not what happened.
      final LoadOutcome outcome = await busyRepo().load(registry: saveRegistry);
      expect(outcome, isA<LoadRefused>());
    });

    test('a busy compaction does not throw an untyped error', () async {
      final CompactionOutcome outcome = await busyRepo().compact();
      expect(outcome, isNotNull);
    });

    test('a busy eraseAll does not throw an untyped error', () async {
      await busyRepo().eraseAll();
    });
  });

  // =========================================================================
  // C4 — a blocked bootstrap leaves storage exactly as it found it
  // =========================================================================
  //
  // Both `bootstrap.dart` ("A blocked bootstrap never deletes anything") and
  // `runtime_bootstrap.dart` ("Written only once startup actually reached a
  // new game, so a blocked launch leaves the directory exactly as it found
  // it") make this claim.
  //
  // `_startNewGame` writes the identity BEFORE it commits. If the commit then
  // refuses -- no space, or `storageBusy` from the new OS lock -- startup
  // returns BootstrapBlocked with an identity already on disk that no save
  // corresponds to.
  //
  // In the app that record is worse than useless. The coordinator writes the
  // core-facing shape (saveId + saltFingerprint, no salt), and
  // `FileIdentityStore.readStored` throws
  // `StorageException('decode identity', '... missing a required field')` on a
  // record with no salt. `bootstrapStride` calls `readStored` at line 85
  // outside any try, so the NEXT launch throws out of startup entirely -- no
  // typed refusal, no BootstrapBlocked, no recovery short of clearing app
  // data.
  group('C4 bootstrap leaves nothing behind when it blocks', () {
    test('a refused first commit writes no identity', () async {
      final RecordingIdentityStore identity = RecordingIdentityStore();
      final SaveRepository repo = SaveRepository(
        snapshots: const EmptySnapshots(),
        journal: const UnappendableJournal(),
      );

      final BootstrapCoordinator coordinator = BootstrapCoordinator(
        repository: repo,
        identityStore: identity,
        profileId: BalanceProfile.productionId,
      );

      final BootstrapOutcome outcome = await coordinator.run(
        loadContent: () async => productionSource,
        mintIdentity: () => const ReconciliationIdentity(
          saveId: 'probe-save',
          saltFingerprint: 'probe-fingerprint',
        ),
      );

      expect(outcome, isA<BootstrapBlocked>());
      expect(
        (outcome as BootstrapBlocked).reason,
        BootstrapBlockReason.storageUnavailable,
      );
      expect(
        identity.writes,
        isEmpty,
        reason:
            'a blocked bootstrap must leave storage exactly as it found it. '
            'An identity written before a commit that then refused orphans '
            'itself, and in the app it is written in the salt-less shape that '
            'makes FileIdentityStore.readStored throw -- so the next launch '
            'throws out of bootstrapStride with no typed refusal at all',
      );
      expect(identity.erases, 0);
    });
  });
}
