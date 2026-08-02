// Closure Critic probes — pure-core half.
//
// Every test here asserts the behaviour the shipped documentation claims. A
// failure is a defect in the code or a lie in the doc, never a defect here.
// Nothing in this file is skipped and nothing is weakened.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'content_test_support.dart';
import 'save_support.dart';

/// A salt fingerprint fixture. Never a real one — this string reaches a
/// diagnostic surface in the assertions below.
const String saltNow = 'aaaaaaaaaaaaaaaa';

/// A device carrying a save produced by real commits, not a hand-built
/// envelope. A fixture that skipped the commit path would prove nothing about
/// what the load path meets.
Future<({FaultingDevice device})> savedGame({
  int commits = 2,
  String saveId = testSaveId,
}) async {
  final (:SaveRepository repo, :FaultingDevice device) = newRepo();
  final GameEngine engine = GameEngine.newGame(registry: saveRegistry);

  int generation = -1;
  int transaction = 0;
  for (int i = 0; i < commits; i++) {
    final EngineResult r = engine.execute(
      GrantSyntheticSteps(steps: <int>[613, 291, 137][i % 3], reason: 'seed$i'),
    );
    final CommitDurable durable =
        await repo.commit(
              after: engine.state,
              events: r.events,
              saveId: saveId,
              expectation: CommitExpectation(
                expectedSnapshotGeneration: generation,
                expectedLastAppliedTransaction: transaction,
              ),
              originSaltFingerprint: saltNow,
            )
            as CommitDurable;
    generation = durable.generation;
    transaction = durable.transactionId;
  }
  return (device: device.reboot());
}

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

/// A snapshot store that cannot be read at all.
///
/// Distinct from bytes that are wrong: "the medium will not answer" is not
/// absence, and only absence licenses clearing an orphan.
final class UnreadableSnapshots implements SnapshotSlotStore {
  const UnreadableSnapshots();

  @override
  Future<Uint8List?> read(SnapshotSlot slot) async =>
      throw StateError('storage medium unavailable');

  @override
  Future<void> write(SnapshotSlot slot, Uint8List bytes) async =>
      throw StateError('storage medium unavailable');

  @override
  Future<void> erase(SnapshotSlot slot) async =>
      throw StateError('storage medium unavailable');
}

/// Snapshot slots that refuse to be deleted, for the reset-ordering probes.
final class UnerasableSnapshots implements SnapshotSlotStore {
  const UnerasableSnapshots();

  @override
  Future<Uint8List?> read(SnapshotSlot slot) async => null;

  @override
  Future<void> write(SnapshotSlot slot, Uint8List bytes) async {}

  @override
  Future<void> erase(SnapshotSlot slot) async =>
      throw StateError('the slot cannot be deleted');
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
  bool eraseThrows = false;

  /// Places an identity as if a previous launch had written it.
  void seed(ReconciliationIdentity identity) => _held = identity;

  @override
  Future<ReconciliationIdentity?> read() async => _held;

  @override
  Future<void> write(ReconciliationIdentity identity) async {
    writes.add(identity);
    _held = identity;
  }

  @override
  Future<void> erase() async {
    if (eraseThrows) throw StateError('identity erase refused');
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
  // Closed in F-06. `commit` already passed `onBusy`; `load`, `compact` and
  // `eraseAll` did not, so a busy save made them throw a bare `StateError`,
  // and bootstrap caught the load one and reported `storageUnavailable` —
  // the wrong reason, because the storage is available and in use. `onBusy` is
  // now required, so no operation can decline to name its busy result.
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
      // in this protocol has a name in `LoadRefusal`; this one used to escape
      // as an untyped `StateError` whose only description was an English
      // sentence, and reached the player as "Stride could not read its save
      // files", which is not what happened.
      final LoadOutcome outcome = await busyRepo().load(registry: saveRegistry);
      expect(outcome, isA<LoadRefused>());
      expect((outcome as LoadRefused).reason, LoadRefusal.storageBusy);
    });

    test('a busy load can never be read as "no save exists"', () async {
      // The failure that matters. `NoSaveFound` is the new-game trigger, so a
      // busy save that presented as one would start a fresh character over a
      // live save that another process is mid-commit on.
      final LoadOutcome outcome = await busyRepo().load(registry: saveRegistry);
      expect(outcome, isNot(isA<NoSaveFound>()));

      final String text = (outcome as LoadRefused).explanation.toLowerCase();
      for (final String phrase in <String>[
        'no save',
        'not found',
        'new game',
        'nothing saved',
      ]) {
        expect(
          text.contains(phrase),
          isFalse,
          reason: 'the busy explanation reads as absence: "$phrase"',
        );
      }
    });

    test('a busy compaction is a typed skip', () async {
      final CompactionOutcome outcome = await busyRepo().compact();
      expect(outcome.refusal, CompactionRefusal.storageBusy);
      expect(outcome.removed, 0);
    });

    test('a busy eraseAll refuses and records no reset intent', () async {
      final SaveRepository repo = busyRepo();
      final EraseOutcome outcome = await repo.eraseAll();

      expect(outcome, isA<EraseRefused>());
      expect((outcome as EraseRefused).reason, EraseRefusal.storageBusy);
    });
  });

  // =========================================================================
  // C4 — an orphan identity is contained, and is never a permanent failure
  // =========================================================================
  //
  // ## What this group used to assert, and why it no longer does
  //
  // It asserted that a refused first commit must write no identity at all —
  // that an identity can never remain after an interrupted first save. The
  // owner has since ruled the opposite: provisioning is **identity-first**,
  // because the two orderings fail asymmetrically. An identity with no save is
  // a recoverable orphan; a save with no identity is `originIdentityMissing`
  // forever, caused by us. So the old premise is now explicitly disallowed and
  // the test is replaced rather than weakened.
  //
  // Its stated app-layer harm was checked and is false. `IdentityVault.write`
  // does not write the salt-less core-facing shape: it persists the full
  // candidate through `_backend.create`, salt included, so
  // `FileIdentityStore.readStored` has a `salt` field to find and does not
  // throw on the next launch. `test/identity_vault_orphan_test.dart` at the app
  // root is the regression on that specific claim.
  //
  // What is left to prove is not "no orphan" but "a contained orphan": it can
  // never bind to an unrelated save, it is cleaned only on conclusive proof of
  // absence, and it never turns the next launch into a throw.
  group('C4 an orphan identity is contained', () {
    Future<BootstrapOutcome> bootOver(
      SaveRepository repo,
      RecordingIdentityStore identity, {
      String mintsSaveId = 'probe-save',
    }) =>
        BootstrapCoordinator(
          repository: repo,
          identityStore: identity,
          profileId: BalanceProfile.productionId,
        ).run(
          loadContent: () async => productionSource,
          mintIdentity: () => ReconciliationIdentity(
            saveId: mintsSaveId,
            saltFingerprint: 'probe-fingerprint',
          ),
        );

    test('cannot bind to an unrelated later save', () async {
      // The orphan says lineage X. The device holds a real save under lineage
      // Y. Resuming would write every later commit under X, forking the
      // journal on the very next transaction.
      final saved = await savedGame(commits: 2, saveId: 'lineage-y');
      final RecordingIdentityStore identity = RecordingIdentityStore()
        ..seed(
          const ReconciliationIdentity(
            saveId: 'lineage-x',
            saltFingerprint: saltNow,
          ),
        );

      final BootstrapOutcome outcome = await bootOver(
        newRepo(saved.device.reboot()).repo,
        identity,
      );

      expect(outcome, isA<BootstrapBlocked>());
      expect(
        (outcome as BootstrapBlocked).reason,
        BootstrapBlockReason.originIdentityMismatch,
      );
      expect(
        identity.erases,
        0,
        reason:
            'a save exists, so nothing about the identity is provably '
            'orphaned',
      );
    });

    test('cannot silently bypass a lineage check', () async {
      // The same fixture, asserted as an inequality against the resume path:
      // an orphan must never produce a *ready* game over someone else's save.
      final saved = await savedGame(commits: 2, saveId: 'lineage-y');
      final RecordingIdentityStore identity = RecordingIdentityStore()
        ..seed(
          const ReconciliationIdentity(
            saveId: 'lineage-x',
            saltFingerprint: saltNow,
          ),
        );

      final BootstrapOutcome outcome = await bootOver(
        newRepo(saved.device.reboot()).repo,
        identity,
      );

      expect(outcome, isNot(isA<BootstrapExistingGame>()));
      expect(outcome, isNot(isA<BootstrapNewGame>()));
    });

    test('is cleaned only when absence is conclusively proven', () async {
      // The whole rule, as a table. `erases` is the observable, and it may be
      // 1 in exactly one row.
      final saved = await savedGame(commits: 1);

      Future<int> erasesFor(SaveRepository repo) async {
        final RecordingIdentityStore identity = RecordingIdentityStore()
          ..seed(
            const ReconciliationIdentity(
              saveId: testSaveId,
              saltFingerprint: saltNow,
            ),
          );
        await bootOver(repo, identity);
        return identity.erases;
      }

      // A truncated slot. Present but zero-length is exactly what a death
      // between a truncate and a write leaves.
      final FaultingDevice truncated = saved.device.reboot()
        ..seed('save_slot_a', Uint8List(0))
        ..seed('save_slot_b', Uint8List(0));
      expect(await erasesFor(newRepo(truncated).repo), 0);

      // A corrupt slot.
      final FaultingDevice corrupt = saved.device.reboot()
        ..seed('save_slot_a', Uint8List.fromList(utf8.encode('not a save')))
        ..seed('save_slot_b', Uint8List.fromList(<int>[0, 1, 2, 3]));
      expect(await erasesFor(newRepo(corrupt).repo), 0);

      // Busy: nothing was read at all, so nothing is proven.
      expect(
        await erasesFor(
          SaveRepository(
            snapshots: FaultingSnapshotStore(FaultingDevice()),
            journal: FaultingJournal(FaultingDevice()),
            lock: const AlwaysBusyLock(),
            lockTimeout: const Duration(milliseconds: 1),
          ),
        ),
        0,
      );

      // Unreadable: the read faults rather than answering.
      expect(
        await erasesFor(
          SaveRepository(
            snapshots: const UnreadableSnapshots(),
            journal: FaultingJournal(FaultingDevice()),
          ),
        ),
        0,
      );

      // Both slots absent and the journal empty — the only row that erases.
      expect(
        await erasesFor(newRepo().repo),
        1,
        reason:
            'this is the one observation that proves the orphan has no save, '
            'and therefore the one that licenses deleting it',
      );
    });

    test('does not cause a permanent next-launch failure', () async {
      // Two launches over the same doubles, and neither may throw. The first
      // blocks with the journal unwritable; the second, over the same identity
      // store, must still produce a typed outcome rather than an exception out
      // of startup.
      final RecordingIdentityStore identity = RecordingIdentityStore();
      SaveRepository unwritable() => SaveRepository(
        snapshots: const EmptySnapshots(),
        journal: const UnappendableJournal(),
      );

      final BootstrapOutcome first = await bootOver(unwritable(), identity);
      expect(first, isA<BootstrapBlocked>());

      final BootstrapOutcome second = await bootOver(unwritable(), identity);
      expect(
        second,
        isA<BootstrapOutcome>(),
        reason: 'the second launch must be an outcome, never a throw',
      );
      expect(second, isA<BootstrapBlocked>());
    });

    test('a refused first commit attempts cleanup', () async {
      final RecordingIdentityStore identity = RecordingIdentityStore();

      final BootstrapOutcome outcome = await bootOver(
        SaveRepository(
          snapshots: const EmptySnapshots(),
          journal: const UnappendableJournal(),
        ),
        identity,
      );

      expect(outcome, isA<BootstrapBlocked>());
      expect(
        (outcome as BootstrapBlocked).reason,
        BootstrapBlockReason.storageUnavailable,
      );
      expect(identity.writes, hasLength(1));
      expect(
        identity.erases,
        1,
        reason:
            'the commit wrote nothing, so the identity provably has no save '
            'under it and the orphan rule applies',
      );
    });

    test(
      'a cleanup that throws still yields a typed blocked outcome',
      () async {
        final RecordingIdentityStore identity = RecordingIdentityStore()
          ..eraseThrows = true;

        final BootstrapOutcome outcome = await bootOver(
          SaveRepository(
            snapshots: const EmptySnapshots(),
            journal: const UnappendableJournal(),
          ),
          identity,
        );

        expect(
          outcome,
          isA<BootstrapBlocked>(),
          reason:
              'a failed cleanup leaves a recoverable orphan, not an escaping '
              'exception',
        );
        expect(identity.erases, 0);
      },
    );
  });

  // =========================================================================
  // C5 — reset is deliberate, ordered, and never automatic recovery
  // =========================================================================
  group('C5 the reset protocol', () {
    test('an interrupted reset never reads back as a new install', () async {
      final saved = await savedGame(commits: 2);
      final FaultingDevice device = saved.device.reboot();

      // A reset that died after the slots went and before the journal did.
      // Byte-for-byte identical to a fresh install except for the intent.
      final SaveRepository repo = newRepo(device).repo;
      device
        ..seed('journal', encodeResetMarkerLine())
        ..erase('save_slot_a')
        ..erase('save_slot_b');

      final LoadOutcome outcome = await repo.load(registry: saveRegistry);
      expect(
        outcome,
        isNot(isA<NoSaveFound>()),
        reason: 'a half-erased directory must never present as a new install',
      );
      expect((outcome as LoadRefused).reason, LoadRefusal.resetIncomplete);
    });

    test('re-running the reset completes it', () async {
      final saved = await savedGame(commits: 2);
      final FaultingDevice device = saved.device.reboot()
        ..seed('journal', encodeResetMarkerLine())
        ..erase('save_slot_a')
        ..erase('save_slot_b');

      final SaveRepository repo = newRepo(device).repo;
      expect(await repo.eraseAll(), isA<EraseComplete>());
      expect(
        await newRepo(device).repo.load(registry: saveRegistry),
        isA<NoSaveFound>(),
      );
    });

    test('the intent survives a reset that cannot delete a slot', () async {
      // The ordering property, observed from the outside: the slot delete
      // fails, and the intent is on disk anyway — which is only possible if it
      // was written first.
      final FaultingDevice device = (await savedGame()).device;
      final SaveRepository repo = SaveRepository(
        snapshots: const UnerasableSnapshots(),
        journal: FaultingJournal(device),
      );

      final EraseOutcome outcome = await repo.eraseAll();
      expect(
        (outcome as EraseRefused).reason,
        EraseRefusal.snapshotEraseFailed,
      );

      final List<Uint8List> lines = await FaultingJournal(device).readLines();
      expect(lines.any(isResetMarkerLine), isTrue);
    });

    test('an incomplete reset refuses the next commit', () async {
      // Committing onto a half-erased directory would leave live records after
      // the intent and make the reset unresumable.
      final FaultingDevice device = (await savedGame()).device
        ..seed('journal', encodeResetMarkerLine());
      final GameEngine engine = GameEngine.newGame(registry: saveRegistry);
      final EngineResult r = engine.execute(
        const GrantSyntheticSteps(steps: 500, reason: 'reset probe'),
      );

      final CommitOutcome outcome = await commit(
        newRepo(device).repo,
        after: engine.state,
        events: r.events,
        generation: -1,
        lastTransaction: 0,
      );
      expect((outcome as CommitRefused).reason, CommitRefusal.resetInProgress);
    });

    test(
      'a full reset deletes the identity last, and only on success',
      () async {
        final saved = await savedGame(commits: 2);
        final FaultingDevice device = saved.device.reboot();
        final RecordingIdentityStore identity = RecordingIdentityStore()
          ..seed(
            const ReconciliationIdentity(
              saveId: testSaveId,
              saltFingerprint: saltNow,
            ),
          );

        final EraseOutcome outcome = await ResetCoordinator(
          repository: newRepo(device).repo,
          identityStore: identity,
        ).resetEverything();

        expect(outcome, isA<EraseComplete>());
        expect(identity.erases, 1);
        expect(device.exists('save_slot_a'), isFalse);
        expect(device.exists('save_slot_b'), isFalse);
        expect(device.exists('journal'), isFalse);
      },
    );

    test('a refused storage erase never reaches the identity', () async {
      final RecordingIdentityStore identity = RecordingIdentityStore()
        ..seed(
          const ReconciliationIdentity(
            saveId: testSaveId,
            saltFingerprint: saltNow,
          ),
        );

      final EraseOutcome outcome = await ResetCoordinator(
        repository: SaveRepository(
          snapshots: FaultingSnapshotStore(FaultingDevice()),
          journal: FaultingJournal(FaultingDevice()),
          lock: const AlwaysBusyLock(),
          lockTimeout: const Duration(milliseconds: 1),
        ),
        identityStore: identity,
      ).resetEverything();

      expect((outcome as EraseRefused).reason, EraseRefusal.storageBusy);
      expect(
        identity.erases,
        0,
        reason:
            'an identity deleted while a save survives makes that save '
            'unopenable forever',
      );
    });

    test('a failed identity erase is typed, not thrown', () async {
      final saved = await savedGame(commits: 1);
      final RecordingIdentityStore identity = RecordingIdentityStore()
        ..seed(
          const ReconciliationIdentity(
            saveId: testSaveId,
            saltFingerprint: saltNow,
          ),
        )
        ..eraseThrows = true;

      final EraseOutcome outcome = await ResetCoordinator(
        repository: newRepo(saved.device.reboot()).repo,
        identityStore: identity,
      ).resetEverything();

      expect(
        (outcome as EraseRefused).reason,
        EraseRefusal.identityEraseFailed,
      );
    });

    test('no recovery path in stride_core erases a save', () {
      // Asserted against the source, because the guarantee is "no code path
      // calls this", and a behavioural test can only ever sample the paths
      // someone thought of.
      final List<String> offenders = <String>[];
      for (final File file in _coreSources()) {
        final String source = file.readAsStringSync();
        for (final RegExpMatch m in RegExp(
          r'\.eraseAll\s*\(',
        ).allMatches(source)) {
          offenders.add('${file.path}:${m.start}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'eraseAll must be reachable only from a deliberate player action '
            'through ResetCoordinator, never as automatic repair. Callers '
            'found: $offenders',
      );

      // And the one legitimate caller is the reset coordinator itself, which
      // this scan deliberately excludes — so prove it still exists rather than
      // letting the assertion above pass because the method was deleted.
      expect(
        File(
          'lib/src/save/reset.dart',
        ).readAsStringSync().contains('repository.eraseAll()'),
        isTrue,
      );
    });
  });
}

/// Every `stride_core` source except the reset coordinator, which is the one
/// place a reset is allowed to originate.
List<File> _coreSources() {
  final Directory lib = Directory('lib');
  return lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .where(
        (File f) => !f.path.replaceAll(r'\', '/').endsWith('save/reset.dart'),
      )
      .toList();
}
