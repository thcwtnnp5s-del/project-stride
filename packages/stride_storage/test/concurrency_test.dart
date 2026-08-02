// Adversarial proof of the whole-transaction save lock.
//
// Every test here runs against a real temporary directory and a real
// `FileTransactionLock`. Nothing is mocked, because the property under test is
// a kernel property: `RandomAccessFile.lock(FileLock.exclusive)` maps to
// `LockFileEx` on Windows and `fcntl` on POSIX, and a fake would prove only
// that the fake was written to agree with the test.
//
// ## What each case is attacking
//
// | Case | Attack |
// |---|---|
// | 1 | Two repositories racing over one directory, fifty times |
// | 2 | Two writers holding the same expected generation |
// | 3 | A waiter must actually land, not merely fail politely |
// | 4 | A bounded wait must refuse in a typed way and write nothing |
// | 5 | An exception mid-transaction must still release |
// | 6 | A killed holder must not retain the lock |
// | 7 | Exactly-once granting under concurrency |
// | 8 | The hold must span the WHOLE transaction, not just the append |
//
// ## Why a single pass would prove nothing
//
// Case 1 is a race. A race that is lost one time in twenty passes a single run
// and ships. It is therefore run fifty times, and it asserts the *invariant*
// (unique transaction ids, exactly-once granting) rather than a particular
// winner, because which instance wins the lock is not something the protocol
// promises and not something a test should pin.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:stride_storage/stride_storage.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

ContentSource get _productionSource {
  for (final String candidate in <String>[
    '../../assets/content/v1',
    'assets/content/v1',
  ]) {
    final Directory dir = Directory(candidate);
    if (!dir.existsSync()) continue;
    final Map<String, String> files = <String, String>{};
    for (final FileSystemEntity e in dir.listSync()) {
      if (e is File && e.path.endsWith('.json')) {
        files[e.uri.pathSegments.last] = e.readAsStringSync();
      }
    }
    return ContentSource(files);
  }
  throw StateError('content not found from ${Directory.current.path}');
}

const String saveId = 'concurrency-save-0001';

/// A fresh directory that is deleted whichever way the test ends.
StorageLayout freshLayout() {
  final Directory root = Directory.systemTemp.createTempSync('stride_conc_');
  addTearDown(() => _bestEffortDelete(root));
  final StorageLayout layout = StorageLayout(
    Directory('${root.path}/${StorageLayout.directoryName}'),
  );
  layout.root.createSync(recursive: true);
  return layout;
}

void _bestEffortDelete(Directory root) {
  try {
    if (root.existsSync()) root.deleteSync(recursive: true);
  } on Object {
    // A directory Windows still holds a handle on is not the subject under
    // test. Case 4 asserts handle release directly instead.
  }
}

/// A repository configured exactly as the app configures one.
SaveRepository repoOver(
  StorageLayout layout, {
  Duration lockTimeout = const Duration(seconds: 5),
  int maxCommitRetries = 3,
  SnapshotSlotStore? snapshots,
  LedgerJournal? journal,
}) => SaveRepository(
  snapshots: snapshots ?? FileSnapshotStore(layout),
  journal: journal ?? FileLedgerJournal(layout),
  maxCommitRetries: maxCommitRetries,
  lock: FileTransactionLock(layout.transactionLock),
  lockTimeout: lockTimeout,
);

Future<CommitOutcome> commitOf(
  SaveRepository repo, {
  required GameState after,
  required List<GameEvent> events,
  required int generation,
  required int lastTransaction,
}) => repo.commit(
  after: after,
  events: events,
  saveId: saveId,
  originSaltFingerprint: null,
  expectation: CommitExpectation(
    expectedSnapshotGeneration: generation,
    expectedLastAppliedTransaction: lastTransaction,
  ),
);

/// One real, valid save, so every probe attacks a populated directory.
Future<void> seedSave(StorageLayout layout, ContentRegistry registry) async {
  final GameEngine engine = GameEngine.newGame(registry: registry);
  final CommitOutcome outcome = await commitOf(
    repoOver(layout),
    after: engine.state,
    events: const <GameEvent>[],
    generation: -1,
    lastTransaction: 0,
  );
  expect(outcome, isA<CommitDurable>(), reason: 'the seed must commit');
}

/// Every transaction id physically present in the journal.
List<int> journalTransactionIds(StorageLayout layout) {
  if (!layout.journal.existsSync()) return <int>[];
  final Uint8List bytes = layout.journal.readAsBytesSync();
  final List<int> ids = <int>[];
  int start = 0;
  for (int i = 0; i < bytes.length; i++) {
    if (bytes[i] != 0x0A) continue;
    final JournalLineResult parsed = decodeJournalLine(
      Uint8List.sublistView(bytes, start, i + 1),
    );
    // -1 marks an unparseable line, so a torn record cannot masquerade as
    // "no duplicate".
    ids.add(parsed.ok ? parsed.record!.transactionId : -1);
    start = i + 1;
  }
  return ids;
}

/// Length and digest of every declared artifact. A same-length rewrite is
/// still visible, which a length-only comparison would miss.
String durableImage(StorageLayout layout) {
  final List<String> lines = <String>[];
  for (final File file in layout.allFiles) {
    // The lock file itself is excluded on purpose: it holds no data, is never
    // read or written, and is truncated to zero bytes by every acquire. It is
    // not part of the save.
    if (file.path == layout.transactionLock.path) continue;
    if (!file.existsSync()) continue;
    final Uint8List bytes = file.readAsBytesSync();
    lines.add(
      '${file.uri.pathSegments.last}:${bytes.length}:${crc32cHex(bytes)}',
    );
  }
  lines.sort();
  return lines.join('\n');
}

int grantedIn(LoadOutcome outcome) =>
    (outcome as SaveLoaded).state.steps.totalGranted;

void say(Object? m) => stdout.writeln('  >> $m');

// ---------------------------------------------------------------------------
// Injected faults
// ---------------------------------------------------------------------------

/// A snapshot store whose every operation fails.
///
/// Used to throw from *inside* the locked region, which is the only way to
/// prove the release is in a `finally` and not on the success path.
final class ThrowingSnapshots implements SnapshotSlotStore {
  const ThrowingSnapshots();

  @override
  Future<Uint8List?> read(SnapshotSlot slot) async =>
      throw const StorageException('read', 'injected fault');

  @override
  Future<void> write(SnapshotSlot slot, Uint8List bytes) async =>
      throw const StorageException('write', 'injected fault');

  @override
  Future<void> erase(SnapshotSlot slot) async =>
      throw const StorageException('erase', 'injected fault');
}

/// A journal that runs a callback **after the append and before the return**.
///
/// That instant is the middle of the transaction: the journal record exists on
/// disk, and the snapshot still describes the previous generation. If the lock
/// covered only the append, a second instance would observe exactly this.
final class HookedJournal implements LedgerJournal {
  HookedJournal(this._inner);

  final LedgerJournal _inner;

  /// Fired once, then cleared, so compaction inside the same commit cannot
  /// re-enter it.
  Future<void> Function()? afterAppend;

  @override
  Future<void> appendLine(Uint8List line) async {
    await _inner.appendLine(line);
    final Future<void> Function()? hook = afterAppend;
    afterAppend = null;
    if (hook != null) await hook();
  }

  @override
  Future<List<Uint8List>> readLines() => _inner.readLines();

  @override
  Future<void> replaceLines(List<Uint8List> lines) =>
      _inner.replaceLines(lines);

  @override
  Future<bool> discardIncompleteCompaction() =>
      _inner.discardIncompleteCompaction();

  @override
  Future<void> erase() => _inner.erase();
}

// ---------------------------------------------------------------------------

void main() {
  final ContentRegistry registry = const ContentLoader()
      .load(_productionSource, profileId: BalanceProfile.productionId)
      .requireRegistry;

  // =========================================================================
  // 0 — the primitive itself
  // =========================================================================
  //
  // Everything below rests on `FileTransactionLock` being mutually exclusive
  // between two acquirers. Asserting that directly means a platform on which
  // the primitive is weaker fails *here*, with a message that names the cause,
  // rather than as a mystifying data-loss failure eight tests later.
  group('0 the lock primitive', () {
    test('a second acquirer is refused while the first holds', () async {
      final StorageLayout layout = freshLayout();
      final FileTransactionLock lock = FileTransactionLock(
        layout.transactionLock,
      );

      final TransactionLockHandle? first = await lock.acquire(
        const Duration(seconds: 2),
      );
      expect(first, isNotNull, reason: 'an uncontended acquire must succeed');

      final TransactionLockHandle? second = await lock.acquire(
        const Duration(milliseconds: 150),
      );
      expect(
        second,
        isNull,
        reason:
            'the lock is not mutually exclusive between two acquirers. On '
            'POSIX, Dart implements RandomAccessFile.lock with fcntl(F_SETLK), '
            'whose locks are owned by the PROCESS and not by the file '
            'descriptor -- so a second open in the same process is granted, '
            'and closing any descriptor drops the whole process\'s locks. '
            'Every cross-instance guarantee below is void if this fails.',
      );

      await first!.release();

      final TransactionLockHandle? third = await lock.acquire(
        const Duration(milliseconds: 500),
      );
      expect(third, isNotNull, reason: 'release must actually release');
      await third!.release();
    });

    test('release is idempotent and leaves no handle behind', () async {
      final StorageLayout layout = freshLayout();
      final FileTransactionLock lock = FileTransactionLock(
        layout.transactionLock,
      );
      final TransactionLockHandle handle = (await lock.acquire(
        const Duration(seconds: 2),
      ))!;
      await handle.release();
      await handle.release();

      // A handle Windows still holds cannot be deleted. This is the assertion
      // that "released" means the descriptor is gone, not merely unlocked.
      layout.transactionLock.deleteSync();
      expect(layout.transactionLock.existsSync(), isFalse);
    });

    test('a timed-out acquire does not leak a descriptor', () async {
      final StorageLayout layout = freshLayout();
      final FileTransactionLock lock = FileTransactionLock(
        layout.transactionLock,
      );
      final TransactionLockHandle holder = (await lock.acquire(
        const Duration(seconds: 2),
      ))!;

      for (int i = 0; i < 20; i++) {
        expect(await lock.acquire(const Duration(milliseconds: 5)), isNull);
      }

      await holder.release();
      final TransactionLockHandle? after = await lock.acquire(
        const Duration(seconds: 2),
      );
      expect(
        after,
        isNotNull,
        reason:
            'twenty refused acquires must not exhaust the descriptor table or '
            'leave a stale lock behind',
      );
      await after!.release();
    });
  });

  // =========================================================================
  // 1 — two repositories, one directory, fifty times
  // =========================================================================
  group('1 concurrent instances over one directory', () {
    test(
      'fifty races leave a unique, unforked journal every time',
      () async {
        const int iterations = 50;
        final List<String> outcomeShapes = <String>[];
        int totalDurable = 0;

        for (int i = 0; i < iterations; i++) {
          final Directory root = Directory.systemTemp.createTempSync(
            'stride_race_',
          );
          final StorageLayout layout = StorageLayout(
            Directory('${root.path}/${StorageLayout.directoryName}'),
          );
          layout.root.createSync(recursive: true);
          try {
            await seedSave(layout, registry);

            final SaveRepository a = repoOver(layout);
            final SaveRepository b = repoOver(layout);

            final SaveLoaded la =
                await a.load(registry: registry) as SaveLoaded;
            final SaveLoaded lb =
                await b.load(registry: registry) as SaveLoaded;

            final GameEngine ea = GameEngine(
              registry: registry,
              state: la.state,
            );
            final GameEngine eb = GameEngine(
              registry: registry,
              state: lb.state,
            );
            // Non-summing quantities: 5000 alone, 11 alone and 5011 are three
            // different numbers, so a drop and a double-grant land differently.
            final EngineResult ra = ea.execute(
              const GrantSyntheticSteps(steps: 5000, reason: 'foreground'),
            );
            final EngineResult rb = eb.execute(
              const GrantSyntheticSteps(steps: 11, reason: 'background worker'),
            );

            final List<CommitOutcome> outcomes =
                await Future.wait(<Future<CommitOutcome>>[
                  commitOf(
                    a,
                    after: ea.state,
                    events: ra.events,
                    generation: la.generation,
                    lastTransaction: la.lastAppliedTransaction,
                  ),
                  commitOf(
                    b,
                    after: eb.state,
                    events: rb.events,
                    generation: lb.generation,
                    lastTransaction: lb.lastAppliedTransaction,
                  ),
                ]);

            // --- the journal is unforked ------------------------------------
            final List<int> ids = journalTransactionIds(layout);
            expect(
              ids,
              isNot(contains(-1)),
              reason: 'iteration $i: an unparseable journal line',
            );
            expect(
              ids.toSet().length,
              ids.length,
              reason:
                  'iteration $i: two records claim the same transaction id, so '
                  'compare-and-swap did not span instances. Journal ids: $ids',
            );

            // --- no two durable results share an id -------------------------
            final List<CommitDurable> durable = outcomes
                .whereType<CommitDurable>()
                .toList();
            expect(
              durable.map((CommitDurable d) => d.transactionId).toSet().length,
              durable.length,
              reason: 'iteration $i: two durable commits at one transaction id',
            );
            expect(
              durable,
              isNotEmpty,
              reason: 'iteration $i: neither writer landed; the lock starves',
            );
            totalDurable += durable.length;

            // --- exactly-once granting --------------------------------------
            int expectedGranted = 0;
            if (outcomes[0] is CommitDurable) expectedGranted += 5000;
            if (outcomes[1] is CommitDurable) expectedGranted += 11;

            final LoadOutcome reread = await repoOver(
              layout,
            ).load(registry: registry);
            expect(
              reread,
              isA<SaveLoaded>(),
              reason:
                  'iteration $i: the next launch cannot open the save. A '
                  'journalForked refusal here is a permanent brick, because '
                  'compaction only runs inside a commit and a commit needs a '
                  'load. Outcome: $reread',
            );
            expect(
              grantedIn(reread),
              expectedGranted,
              reason:
                  'iteration $i: the durable state does not equal the sum of '
                  'the commits that reported success',
            );
            expect(
              (reread as SaveLoaded).repairs
                  .map((SaveRepair r) => r.diagnosis)
                  .toList(),
              isNot(contains(SaveDiagnosis.journalDuplicateTransaction)),
              reason:
                  'iteration $i: a duplicate transaction was absorbed, which '
                  'silently discards that batch of granted steps',
            );

            outcomeShapes.add(
              outcomes
                  .map(
                    (CommitOutcome o) => o is CommitDurable
                        ? 'durable'
                        : 'refused:${(o as CommitRefused).reason.name}',
                  )
                  .join('+'),
            );
          } finally {
            _bestEffortDelete(root);
          }
        }

        say('$iterations races, outcome shapes: ${outcomeShapes.toSet()}');
        say('durable commits across all races: $totalDurable');
        expect(
          totalDurable,
          greaterThanOrEqualTo(iterations),
          reason: 'every race must land at least one commit',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  // =========================================================================
  // 2 — same expected generation
  // =========================================================================
  group('2 two writers at one generation', () {
    test(
      'exactly one is durable, the other is typed and wrote nothing',
      () async {
        final StorageLayout layout = freshLayout();
        await seedSave(layout, registry);

        final SaveRepository a = repoOver(layout);
        final SaveRepository b = repoOver(layout);
        final SaveLoaded head = await a.load(registry: registry) as SaveLoaded;

        final GameEngine ea = GameEngine(registry: registry, state: head.state);
        final GameEngine eb = GameEngine(registry: registry, state: head.state);
        final EngineResult ra = ea.execute(
          const GrantSyntheticSteps(steps: 613, reason: 'writer a'),
        );
        final EngineResult rb = eb.execute(
          const GrantSyntheticSteps(steps: 291, reason: 'writer b'),
        );

        // Deliberately identical expectations. This is the exact configuration
        // in which unguarded compare-and-swap admits both.
        final List<CommitOutcome> outcomes =
            await Future.wait(<Future<CommitOutcome>>[
              commitOf(
                a,
                after: ea.state,
                events: ra.events,
                generation: head.generation,
                lastTransaction: head.lastAppliedTransaction,
              ),
              commitOf(
                b,
                after: eb.state,
                events: rb.events,
                generation: head.generation,
                lastTransaction: head.lastAppliedTransaction,
              ),
            ]);

        say('outcomes: ${outcomes.map(_describe).join(' | ')}');

        final List<CommitDurable> durable = outcomes
            .whereType<CommitDurable>()
            .toList();
        expect(
          durable,
          hasLength(1),
          reason:
              'two writers holding one expectation must produce exactly one '
              'durable commit; ${durable.length} did',
        );

        final CommitRefused refused = outcomes
            .whereType<CommitRefused>()
            .single;
        expect(
          refused.reason,
          anyOf(
            CommitRefusal.conflictRetryLimitExhausted,
            CommitRefusal.storageBusy,
          ),
          reason: 'the loser must refuse in a way the caller can act on',
        );
        expect(
          refused.detail,
          isNotNull,
          reason: 'a refusal with no detail cannot be diagnosed in the field',
        );

        // And the durable state is that single winner, never both.
        final SaveLoaded after =
            await repoOver(layout).load(registry: registry) as SaveLoaded;
        expect(
          after.state.steps.totalGranted,
          anyOf(613, 291),
          reason: '904 here would mean both landed at one transaction id',
        );
        expect(
          journalTransactionIds(layout).toSet().length,
          journalTransactionIds(layout).length,
        );
      },
    );
  });

  // =========================================================================
  // 3 — the waiter lands
  // =========================================================================
  group('3 a contended writer waits and succeeds', () {
    test('a commit blocked by a brief holder still commits', () async {
      final StorageLayout layout = freshLayout();
      await seedSave(layout, registry);

      final SaveRepository repo = repoOver(
        layout,
        lockTimeout: const Duration(seconds: 10),
      );
      final SaveLoaded head = await repo.load(registry: registry) as SaveLoaded;
      final GameEngine engine = GameEngine(
        registry: registry,
        state: head.state,
      );
      final EngineResult r = engine.execute(
        const GrantSyntheticSteps(steps: 777, reason: 'the patient writer'),
      );

      const Duration hold = Duration(milliseconds: 400);
      final TransactionLockHandle holder = (await FileTransactionLock(
        layout.transactionLock,
      ).acquire(const Duration(seconds: 2)))!;

      final Stopwatch clock = Stopwatch()..start();
      final Future<CommitOutcome> pending = commitOf(
        repo,
        after: engine.state,
        events: r.events,
        generation: head.generation,
        lastTransaction: head.lastAppliedTransaction,
      );

      // The commit must still be in flight while the lock is held. Without
      // this, a lock that never engaged would pass the test below by simply
      // finishing first.
      bool settled = false;
      unawaited(pending.then((_) => settled = true));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(
        settled,
        isFalse,
        reason: 'the commit completed while another holder had the lock',
      );

      await Future<void>.delayed(hold);
      await holder.release();

      final CommitOutcome outcome = await pending;
      clock.stop();
      say('waited ${clock.elapsedMilliseconds}ms, then ${_describe(outcome)}');

      expect(
        outcome,
        isA<CommitDurable>(),
        reason:
            'contention must be a wait, not a failure. A refusal here would '
            'strand a batch of granted steps behind a lock that had already '
            'been released',
      );
      expect(clock.elapsed, greaterThanOrEqualTo(hold));
      expect(
        (await repoOver(layout).load(registry: registry) as SaveLoaded)
            .state
            .steps
            .totalGranted,
        777,
      );
    });
  });

  // =========================================================================
  // 4 — bounded wait, typed refusal, nothing written
  // =========================================================================
  group('4 the timeout is bounded and clean', () {
    test('a holder past lockTimeout gives storageBusy and no write', () async {
      final StorageLayout layout = freshLayout();
      await seedSave(layout, registry);

      final SaveRepository repo = repoOver(
        layout,
        lockTimeout: const Duration(milliseconds: 120),
      );
      final SaveLoaded head = await repo.load(registry: registry) as SaveLoaded;
      final GameEngine engine = GameEngine(
        registry: registry,
        state: head.state,
      );
      final EngineResult r = engine.execute(
        const GrantSyntheticSteps(steps: 1234, reason: 'doomed'),
      );

      final TransactionLockHandle holder = (await FileTransactionLock(
        layout.transactionLock,
      ).acquire(const Duration(seconds: 2)))!;

      final String before = durableImage(layout);
      expect(before, isNotEmpty, reason: 'the fixture must be on the medium');

      final Stopwatch clock = Stopwatch()..start();
      final CommitOutcome outcome = await commitOf(
        repo,
        after: engine.state,
        events: r.events,
        generation: head.generation,
        lastTransaction: head.lastAppliedTransaction,
      );
      clock.stop();

      say(
        'refused after ${clock.elapsedMilliseconds}ms: ${_describe(outcome)}',
      );

      expect(outcome, isA<CommitRefused>());
      expect((outcome as CommitRefused).reason, CommitRefusal.storageBusy);
      expect(
        outcome.detail,
        contains('nothing was written'),
        reason:
            'the caller decides whether to hold the cursor from this string '
            'and the reason alone',
      );
      expect(
        clock.elapsed,
        lessThan(const Duration(seconds: 3)),
        reason:
            'an unbounded wait is a hang, and a hang during a step sync looks '
            'to the player exactly like the game losing their walk',
      );
      expect(
        durableImage(layout),
        before,
        reason: 'a busy refusal must not write, delete, or repair a byte',
      );

      await holder.release();

      // And the same commit lands once the holder yields, proving the refusal
      // was transient rather than a wedged repository.
      expect(
        await commitOf(
          repo,
          after: engine.state,
          events: r.events,
          generation: head.generation,
          lastTransaction: head.lastAppliedTransaction,
        ),
        isA<CommitDurable>(),
      );
    });

    test('a busy load refuses rather than inventing a safe answer', () async {
      final StorageLayout layout = freshLayout();
      await seedSave(layout, registry);

      final TransactionLockHandle holder = (await FileTransactionLock(
        layout.transactionLock,
      ).acquire(const Duration(seconds: 2)))!;

      final SaveRepository repo = repoOver(
        layout,
        lockTimeout: const Duration(milliseconds: 100),
      );

      // A load that cannot start has nothing safe to return: `NoSaveFound`
      // would be a wiped character and a `SaveLoaded` would be a fabrication.
      //
      // It used to throw a `StateError`, and this case asserted that. F-06
      // replaced the throw with `LoadRefusal.storageBusy` — contention is an
      // ordinary condition, and a caller that must catch an exception to learn
      // "not now" eventually catches one that meant something else. The
      // property under test is unchanged: refuse, and invent nothing.
      final LoadOutcome busy = await repo.load(registry: registry);
      expect(busy, isA<LoadRefused>());
      expect((busy as LoadRefused).reason, LoadRefusal.storageBusy);
      expect(
        busy.explanation,
        isNotEmpty,
        reason: 'a refusal with nothing to show the player is not usable',
      );

      await holder.release();
      expect(await repo.load(registry: registry), isA<SaveLoaded>());
    });
  });

  // =========================================================================
  // 5 — an exception inside the transaction still releases
  // =========================================================================
  group('5 exceptions release the lock', () {
    test(
      'a throwing store leaves the lock free for the next acquirer',
      () async {
        final StorageLayout layout = freshLayout();
        final SaveRepository poisoned = repoOver(
          layout,
          snapshots: const ThrowingSnapshots(),
        );
        final GameEngine engine = GameEngine.newGame(registry: registry);
        final EngineResult r = engine.execute(
          const GrantSyntheticSteps(steps: 42, reason: 'poisoned'),
        );

        await expectLater(
          commitOf(
            poisoned,
            after: engine.state,
            events: r.events,
            generation: -1,
            lastTransaction: 0,
          ),
          throwsA(isA<StorageException>()),
        );

        // The lock must be free *immediately*, with a timeout short enough that
        // a lingering hold cannot pass by luck.
        final TransactionLockHandle? next = await FileTransactionLock(
          layout.transactionLock,
        ).acquire(const Duration(milliseconds: 50));
        expect(
          next,
          isNotNull,
          reason:
              'an exception leaked the lock. On a real filesystem only a '
              'process death would clear it, so every later launch of the game '
              'would refuse to open the save',
        );
        await next!.release();

        // And the repository is not wedged: a healthy instance still works.
        expect(
          await repoOver(layout).load(registry: registry),
          isA<NoSaveFound>(),
        );
      },
    );

    test('a throwing load releases too, and the queue survives it', () async {
      final StorageLayout layout = freshLayout();
      final SaveRepository poisoned = repoOver(
        layout,
        snapshots: const ThrowingSnapshots(),
      );

      for (int i = 0; i < 3; i++) {
        await expectLater(
          poisoned.load(registry: registry),
          throwsA(isA<StorageException>()),
          reason:
              'attempt $i: after the first throw the writer queue must still '
              'accept work, or the repository is permanently wedged',
        );
      }

      final TransactionLockHandle? next = await FileTransactionLock(
        layout.transactionLock,
      ).acquire(const Duration(milliseconds: 50));
      expect(next, isNotNull);
      await next!.release();
    });
  });

  // =========================================================================
  // 6 — a killed holder does not retain the lock
  // =========================================================================
  //
  // This is the property that makes an OS lock better than a sentinel file, and
  // it is the only case in this file that cannot be demonstrated from inside a
  // single process: a sentinel would pass every other test here and fail this
  // one, permanently, on the first crash.
  //
  // A real second Dart process is used rather than an isolate, because
  // isolates share a process and killing one does not exercise the kernel's
  // reclamation path at all.
  group('6 process death releases the lock', () {
    test(
      'killing the holder frees the lock for this process',
      () async {
        final StorageLayout layout = freshLayout();
        await seedSave(layout, registry);

        final File script = File('${layout.root.path}/../hold_lock.dart');
        script.writeAsStringSync(_holderScript);
        addTearDown(() {
          if (script.existsSync()) script.deleteSync();
        });

        final Process holder = await Process.start(
          Platform.resolvedExecutable,
          <String>[script.path, layout.transactionLock.path],
        );
        addTearDown(() => holder.kill(ProcessSignal.sigkill));

        final Completer<void> locked = Completer<void>();
        final StringBuffer childErr = StringBuffer();
        int heartbeats = 0;
        holder.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((String line) {
              if (line.trim() == 'LOCKED' && !locked.isCompleted) {
                locked.complete();
              }
              if (line.trim() == 'ALIVE') heartbeats++;
            });
        holder.stderr
            .transform(utf8.decoder)
            .listen((String s) => childErr.write(s));

        await locked.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw StateError(
            'the child process never took the lock. stderr: $childErr',
          ),
        );

        // The child must be PROVEN alive before anything is concluded from a
        // refusal, and proven alive again after.
        //
        // This is not defensive padding. The first version of this probe held the
        // lock behind `await Completer<void>().future`, which does not keep the
        // Dart VM alive -- the child exited the instant it printed LOCKED, the
        // lock was released by its death, and the test reported that the lock had
        // failed to exclude a second process. A liveness heartbeat is the only
        // thing that separates "the lock did not hold" from "the holder was
        // already gone".
        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect(
          heartbeats,
          greaterThan(0),
          reason:
              'the child stopped heartbeating before the probe ran, so a '
              'successful acquire below would prove nothing about the lock',
        );
        say('child pid ${holder.pid} holds the lock, $heartbeats heartbeats');

        // The lock is genuinely cross-process: this is what a Dart-level mutex
        // could not provide.
        final SaveRepository repo = repoOver(
          layout,
          lockTimeout: const Duration(milliseconds: 300),
        );
        final CommitOutcome busy = await commitOf(
          repo,
          after: GameEngine.newGame(registry: registry).state,
          events: const <GameEvent>[],
          generation: 0,
          lastTransaction: 1,
        );
        expect(
          busy,
          isA<CommitRefused>(),
          reason:
              'a lock held by another PROCESS must exclude this one, or the '
              'guarantee is only in-process and the Health Connect worker case '
              'is unprotected',
        );
        expect((busy as CommitRefused).reason, CommitRefusal.storageBusy);

        final int heartbeatsBefore = heartbeats;
        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect(
          heartbeats,
          greaterThan(heartbeatsBefore),
          reason:
              'the child died during the probe, so the refusal above may have '
              'been contention with a ghost rather than with a live holder',
        );

        // Killed, not asked to exit. A holder that got a chance to clean up
        // would prove nothing about a crash.
        holder.kill(ProcessSignal.sigkill);
        final int code = await holder.exitCode.timeout(
          const Duration(seconds: 15),
        );
        say('child killed, exit code $code');

        // The kernel, not the child, must have released it.
        final SaveLoaded head =
            await repoOver(layout).load(registry: registry) as SaveLoaded;
        final GameEngine engine = GameEngine(
          registry: registry,
          state: head.state,
        );
        final EngineResult r = engine.execute(
          const GrantSyntheticSteps(steps: 555, reason: 'after the crash'),
        );
        final CommitOutcome after = await commitOf(
          repoOver(layout, lockTimeout: const Duration(seconds: 5)),
          after: engine.state,
          events: r.events,
          generation: head.generation,
          lastTransaction: head.lastAppliedTransaction,
        );
        say('after the kill: ${_describe(after)}');

        expect(
          after,
          isA<CommitDurable>(),
          reason:
              'the lock survived the death of its holder. That is the sentinel-'
              'file failure mode: a crashed holder makes every later launch '
              'refuse forever, and Android kills apps routinely',
        );
        expect(
          layout.transactionLock.existsSync(),
          isTrue,
          reason:
              'the lock file is never deleted -- deleting a file another process '
              'holds a lock on leaves two processes locking two inodes that '
              'share a name',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  // =========================================================================
  // 7 — exactly-once granting under concurrency
  // =========================================================================
  group('7 exactly-once granting', () {
    test(
      'durable totalGranted equals the sum of the commits that landed',
      () async {
        final StorageLayout layout = freshLayout();
        await seedSave(layout, registry);

        const List<int> batches = <int>[137, 291, 613, 1000, 7];
        final List<SaveRepository> repos = <SaveRepository>[
          for (int i = 0; i < batches.length; i++)
            repoOver(layout, lockTimeout: const Duration(seconds: 10)),
        ];

        final SaveLoaded head =
            await repos.first.load(registry: registry) as SaveLoaded;

        final List<CommitOutcome> outcomes =
            await Future.wait(<Future<CommitOutcome>>[
              for (int i = 0; i < batches.length; i++)
                () {
                  final GameEngine e = GameEngine(
                    registry: registry,
                    state: head.state,
                  );
                  final EngineResult r = e.execute(
                    GrantSyntheticSteps(steps: batches[i], reason: 'writer $i'),
                  );
                  return commitOf(
                    repos[i],
                    after: e.state,
                    events: r.events,
                    generation: head.generation,
                    lastTransaction: head.lastAppliedTransaction,
                  );
                }(),
            ]);

        int expected = 0;
        for (int i = 0; i < batches.length; i++) {
          if (outcomes[i] is CommitDurable) expected += batches[i];
        }
        say('outcomes: ${outcomes.map(_describe).join(' | ')}');
        say('expected totalGranted: $expected');

        // Every batch is distinct and none sums to another, so a double-grant
        // and a dropped grant land on different numbers.
        final SaveLoaded after =
            await repoOver(layout).load(registry: registry) as SaveLoaded;
        expect(
          after.state.steps.totalGranted,
          expected,
          reason:
              'a commit that reported success and is not in the durable state '
              'is a lost grant; a batch counted twice is a fabricated one',
        );

        final List<int> ids = journalTransactionIds(layout);
        expect(ids, isNot(contains(-1)));
        expect(ids.toSet().length, ids.length, reason: 'journal ids: $ids');
        expect(
          outcomes.whereType<CommitDurable>(),
          isNotEmpty,
          reason: 'five contenders and no winner means the lock starves',
        );
      },
    );
  });

  // =========================================================================
  // 8 — the hold spans the WHOLE transaction
  // =========================================================================
  //
  // A lock around the append alone would still pass cases 1 through 7 most of
  // the time. This constructs the exact instant that distinguishes them: the
  // journal record is durable and the snapshot has not been rewritten, so the
  // save on disk is half a transaction old.
  group('8 the lock covers the whole transaction', () {
    test(
      'a second instance cannot observe a half-finished transaction',
      () async {
        final StorageLayout layout = freshLayout();
        await seedSave(layout, registry);

        final HookedJournal hooked = HookedJournal(FileLedgerJournal(layout));
        final SaveRepository writer = repoOver(layout, journal: hooked);
        final SaveLoaded head =
            await writer.load(registry: registry) as SaveLoaded;
        final GameEngine engine = GameEngine(
          registry: registry,
          state: head.state,
        );
        final EngineResult r = engine.execute(
          const GrantSyntheticSteps(steps: 4242, reason: 'mid-transaction'),
        );

        // A second instance with a short fuse, so a narrow lock shows up as an
        // observation rather than as a slow test.
        final SaveRepository observer = repoOver(
          layout,
          lockTimeout: const Duration(milliseconds: 150),
        );

        bool intermediateStateExisted = false;
        Object? observerLoad;
        CommitOutcome? observerCommit;

        hooked.afterAppend = () async {
          // Read the medium directly, behind the lock's back, to prove the
          // half-finished state is real and not hypothetical.
          final List<int> ids = journalTransactionIds(layout);
          final Uint8List? slotA = await FileSnapshotStore(
            layout,
          ).read(SnapshotSlot.a);
          final SaveEnvelope envelope = decodeEnvelope(
            unframe(slotA!).payload!,
          );
          intermediateStateExisted =
              ids.length > 1 &&
              envelope.lastAppliedTransaction <
                  ids.reduce((int a, int b) => a > b ? a : b);
          say(
            'mid-transaction: journal ids $ids, live snapshot lastTx '
            '${envelope.lastAppliedTransaction}',
          );

          try {
            observerLoad = await observer.load(registry: registry);
          } on Object catch (e) {
            observerLoad = e;
          }
          observerCommit = await commitOf(
            observer,
            after: engine.state,
            events: r.events,
            generation: head.generation,
            lastTransaction: head.lastAppliedTransaction,
          );
        };

        final CommitOutcome outcome = await commitOf(
          writer,
          after: engine.state,
          events: r.events,
          generation: head.generation,
          lastTransaction: head.lastAppliedTransaction,
        );

        expect(outcome, isA<CommitDurable>());
        expect(
          intermediateStateExisted,
          isTrue,
          reason:
              'the probe did not actually catch the transaction mid-flight, so '
              'it proves nothing about the width of the hold',
        );
        say('observer load  -> ${observerLoad.runtimeType}');
        say('observer commit -> ${_describe(observerCommit!)}');

        // A refusal, not a read. It was a `StateError` until F-06 made
        // contention a typed outcome; what matters here is unchanged and is
        // the same in both shapes — the observer did NOT get a state back.
        expect(
          observerLoad,
          isA<LoadRefused>(),
          reason:
              'a second instance read the save while a transaction was half '
              'written, which means the lock is narrower than the transaction. '
              'It would have read a snapshot older than the journal and then '
              'committed against a stale head. Got: $observerLoad',
        );
        expect((observerLoad! as LoadRefused).reason, LoadRefusal.storageBusy);
        expect(
          observerCommit,
          isA<CommitRefused>(),
          reason:
              'a second instance committed inside another instance\'s '
              'transaction',
        );
        expect(
          (observerCommit! as CommitRefused).reason,
          CommitRefusal.storageBusy,
        );

        // And the transaction that did land is intact and singular.
        final SaveLoaded after =
            await repoOver(layout).load(registry: registry) as SaveLoaded;
        expect(after.state.steps.totalGranted, 4242);
        final List<int> ids = journalTransactionIds(layout);
        expect(ids.toSet().length, ids.length);
      },
    );

    test('the hold also covers compaction, after the snapshot write', () async {
      // Compaction runs after the snapshot is durable and still inside the
      // commit. A lock released at the snapshot write would let a second
      // instance read the journal while it is being replaced.
      final StorageLayout layout = freshLayout();
      await seedSave(layout, registry);

      final SaveRepository repo = repoOver(layout);
      final SaveRepository observer = repoOver(
        layout,
        lockTimeout: const Duration(milliseconds: 100),
      );

      // Two commits, so both slots verify and compaction has a floor.
      int generation = 0;
      int transaction = 1;
      final SaveLoaded head = await repo.load(registry: registry) as SaveLoaded;
      final GameEngine engine = GameEngine(
        registry: registry,
        state: head.state,
      );
      for (final int steps in <int>[137, 291]) {
        final EngineResult r = engine.execute(
          GrantSyntheticSteps(steps: steps, reason: 'g$steps'),
        );
        final CommitDurable d =
            await commitOf(
                  repo,
                  after: engine.state,
                  events: r.events,
                  generation: generation,
                  lastTransaction: transaction,
                )
                as CommitDurable;
        generation = d.generation;
        transaction = d.transactionId;
      }

      // No sidecar may survive a completed commit, and the observer must be
      // able to work now that the commit has fully returned.
      expect(
        layout.journalSidecar.existsSync(),
        isFalse,
        reason: 'a surviving sidecar means compaction was cut short',
      );
      expect(await observer.load(registry: registry), isA<SaveLoaded>());
    });
  });
}

String _describe(CommitOutcome outcome) => switch (outcome) {
  final CommitDurable d =>
    'durable tx=${d.transactionId} gen=${d.generation} '
        'slot=${d.slot.name} retries=${d.retries}',
  final CommitRefused r => 'refused ${r.reason.name}',
};

/// A standalone program that takes the lock and then holds it until it is
/// killed. Pure `dart:io`, so it needs no package resolution.
const String _holderScript = r'''
import 'dart:async';
import 'dart:io';

Future<void> main(List<String> args) async {
  final RandomAccessFile handle = await File(args[0]).open(mode: FileMode.write);
  await handle.lock(FileLock.exclusive);
  stdout.writeln('LOCKED');
  await stdout.flush();

  // A periodic timer, not a bare pending Future.
  //
  // The Dart VM exits when the event loop has no pending work, and an
  // uncompleted Completer is not pending work. A holder written as
  // `await Completer<void>().future` therefore EXITS immediately, its lock is
  // released by its own death, and the parent concludes the lock does not
  // exclude across processes. The timer keeps the process alive; the heartbeat
  // lets the parent prove it.
  Timer.periodic(const Duration(milliseconds: 100), (Timer _) {
    stdout.writeln('ALIVE');
  });
  await Completer<void>().future;
}
''';
