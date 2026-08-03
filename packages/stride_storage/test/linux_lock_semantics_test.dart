// The four properties the single-writer-isolate model actually rests on.
//
// This file is the *named evidence* for the concurrency model recorded in
// `TECHNICAL/PERSISTENCE_CONCURRENCY.md` and `DECISIONS/0013`. It exists as one
// standalone file, rather than as four findings scattered across three suites,
// because the model is quoted in documentation and a reader must be able to
// check the whole claim in one place.
//
// | # | Property | Layer |
// |---|---|---|
// | 1 | Two repository instances in ONE isolate are serialized | path-keyed mutex |
// | 2 | A separate OS PROCESS is excluded | OS advisory lock |
// | 3 | Process death releases the OS lock | OS advisory lock |
// | 4 | CAS rejects stale state | compare-and-swap |
//
// ## Why the name says Linux
//
// Properties 1 and 2 have **platform-dependent mechanisms**, and Windows is the
// permissive-looking one. `RandomAccessFile.lock` maps to `LockFileEx` on
// Windows, which is per-HANDLE, and to `fcntl(F_SETLK)` on POSIX, which is
// per-PROCESS. So on POSIX the OS lock does not exclude a second acquirer in
// the same process at all -- not a second isolate, and not even a second
// `FileTransactionLock` on the same thread.
//
// That is not a hypothesis. CI run 30767931205 was the first time these files
// executed on ubuntu, and eleven cases failed there while all of them passed on
// Windows, including `totalGranted` reporting 7 where 0 was required. The
// path-keyed in-isolate mutex exists because of that run.
//
// These tests therefore run on every platform and must pass on every platform,
// but **Linux is the signal**. A green Windows run is not evidence for
// property 1.
//
// ## What this file deliberately does NOT claim
//
// There is no persistence-owner isolate in this codebase. It was prototyped and
// removed (see `DECISIONS/0013`), so **nothing here serializes two ISOLATES**.
// The model is single-writer-isolate: exactly one isolate may touch the save
// directory, enforced by `Scripts/check-single-writer.sh` rather than by a
// runtime mechanism. Property 1 covers two repository instances in one isolate,
// which is a real and reachable case; two isolates is prohibited, not handled.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
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

const String _saveId = 'lock-semantics-0001';

void _say(Object? m) => stdout.writeln('  >> $m');

StorageLayout _freshLayout() {
  final Directory root = Directory.systemTemp.createTempSync('stride_locksem_');
  addTearDown(() {
    try {
      if (root.existsSync()) root.deleteSync(recursive: true);
    } on Object {
      // A handle Windows still holds is not the subject under test.
    }
  });
  final StorageLayout layout = StorageLayout(
    Directory('${root.path}/${StorageLayout.directoryName}'),
  );
  layout.root.createSync(recursive: true);
  return layout;
}

SaveRepository _repo(StorageLayout layout, {Duration? lockTimeout}) =>
    SaveRepository(
      snapshots: FileSnapshotStore(layout),
      journal: FileLedgerJournal(layout),
      lock: FileTransactionLock(layout.transactionLock),
      lockTimeout: lockTimeout ?? const Duration(seconds: 5),
    );

/// A held lock in a *separate OS process*, with a heartbeat so the parent can
/// prove it is still alive rather than assuming it.
const String _holderScript = r'''
import 'dart:async';
import 'dart:io';

Future<void> main(List<String> args) async {
  final RandomAccessFile handle = await File(args[0]).open(mode: FileMode.write);
  await handle.lock(FileLock.exclusive);
  stdout.writeln('LOCKED');
  await stdout.flush();

  // A periodic timer, not a bare pending Future. The Dart VM exits when the
  // event loop has no pending work, and an uncompleted Completer is not
  // pending work -- so `await Completer<void>().future` would EXIT
  // immediately, the lock would be released by the process's own death, and
  // the parent would conclude the lock does not exclude across processes.
  Timer.periodic(const Duration(milliseconds: 100), (Timer _) {
    stdout.writeln('ALIVE');
  });
  await Completer<void>().future;
}
''';

/// Starts the holder and returns once it has actually taken the lock.
Future<({Process process, int Function() heartbeats})> _startHolder(
  StorageLayout layout,
) async {
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
  int beats = 0;
  holder.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
    String line,
  ) {
    if (line.trim() == 'LOCKED' && !locked.isCompleted) locked.complete();
    if (line.trim() == 'ALIVE') beats++;
  });
  holder.stderr.transform(utf8.decoder).listen(childErr.write);

  await locked.future.timeout(
    const Duration(seconds: 30),
    onTimeout: () => throw StateError(
      'the child process never took the lock. stderr: $childErr',
    ),
  );
  return (process: holder, heartbeats: () => beats);
}

/// Entry point for property 1's second isolate. Reports what the *raw kernel
/// lock* did, and asserts nothing -- see the caveat probe.
Future<void> _rawLockProbe(List<Object> args) async {
  final SendPort reply = args[0] as SendPort;
  final String lockPath = args[1] as String;
  try {
    final RandomAccessFile h = await File(lockPath).open(mode: FileMode.write);
    try {
      await h.lock(FileLock.exclusive);
      reply.send('acquired');
    } on FileSystemException {
      reply.send('refused');
    } finally {
      await h.close();
    }
  } on Object catch (e) {
    reply.send('error: $e');
  }
}

void main() {
  final ContentRegistry registry = const ContentLoader()
      .load(_productionSource, profileId: BalanceProfile.productionId)
      .requireRegistry;

  // =========================================================================
  // 1 — two repository instances in ONE isolate are serialized
  // =========================================================================
  //
  // The layer under test is the path-keyed in-isolate mutex in
  // `FileTransactionLock`, NOT the OS lock. On POSIX the OS lock grants this
  // case outright, so before the mutex existed both instances proceeded and
  // the journal forked.
  group('1 the path-keyed mutex serializes one isolate', () {
    test('two repositories over one directory produce no fork', () async {
      final StorageLayout layout = _freshLayout();
      final SaveRepository a = _repo(layout);
      final SaveRepository b = _repo(layout);

      final GameEngine engine = GameEngine.newGame(registry: registry);
      expect(
        await a.commit(
          after: engine.state,
          events: const <GameEvent>[],
          saveId: _saveId,
          expectation: const CommitExpectation(
            expectedSnapshotGeneration: -1,
            expectedLastAppliedTransaction: 0,
          ),
          originSaltFingerprint: null,
        ),
        isA<CommitDurable>(),
      );

      // Both hold the SAME expectation, so at most one may be durable.
      final EngineResult ra = engine.execute(
        const GrantSyntheticSteps(steps: 400, reason: 'lock semantics a'),
      );
      final EngineResult rb = engine.execute(
        const GrantSyntheticSteps(steps: 700, reason: 'lock semantics b'),
      );
      const CommitExpectation same = CommitExpectation(
        expectedSnapshotGeneration: 0,
        expectedLastAppliedTransaction: 1,
      );

      final List<CommitOutcome> out = await Future.wait(<Future<CommitOutcome>>[
        a.commit(
          after: engine.state,
          events: ra.events,
          saveId: _saveId,
          expectation: same,
          originSaltFingerprint: null,
        ),
        b.commit(
          after: engine.state,
          events: rb.events,
          saveId: _saveId,
          expectation: same,
          originSaltFingerprint: null,
        ),
      ]);

      final int durable = out.whereType<CommitDurable>().length;
      _say(
        'outcomes: ${out.map((CommitOutcome o) => o.runtimeType).join(" | ")}',
      );
      expect(
        durable,
        1,
        reason:
            'exactly one may win. Two durable commits at one expected '
            'generation is a forked journal, which compaction cannot clear.',
      );

      // The refusal must be TYPED, never a throw and never a silent success.
      final CommitRefused refused = out.whereType<CommitRefused>().single;
      expect(
        refused.reason,
        anyOf(
          CommitRefusal.conflictRetryLimitExhausted,
          CommitRefusal.storageBusy,
        ),
      );

      // And the journal on disk must agree.
      final List<int> ids = <int>[];
      for (final line in await FileLedgerJournal(layout).readLines()) {
        final JournalLineResult p = decodeJournalLine(line);
        if (p.ok) ids.add(p.record!.transactionId);
      }
      _say('journal transaction ids: $ids');
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'a repeated transaction id is the fork sentinel',
      );
    });

    test('a second FileTransactionLock in this isolate is refused while the '
        'first holds', () async {
      final StorageLayout layout = _freshLayout();
      final FileTransactionLock lock = FileTransactionLock(
        layout.transactionLock,
      );

      final TransactionLockHandle? first = await lock.acquire(
        const Duration(seconds: 5),
      );
      expect(first, isNotNull);

      final TransactionLockHandle? second = await FileTransactionLock(
        layout.transactionLock,
      ).acquire(const Duration(milliseconds: 200));

      _say(
        'second same-isolate acquire: ${second == null ? "refused" : "GRANTED"}',
      );
      expect(
        second,
        isNull,
        reason:
            'On POSIX the OS lock alone GRANTS this -- fcntl ownership is '
            'the process. The path-keyed mutex is what refuses it. This is '
            'the case that failed on Linux in CI run 30767931205.',
      );

      await first!.release();
      final TransactionLockHandle? third = await lock.acquire(
        const Duration(seconds: 5),
      );
      expect(third, isNotNull, reason: 'a released lock must be reacquirable');
      await third!.release();
    });
  });

  // =========================================================================
  // 2 — a separate OS PROCESS is excluded, with a typed result
  // =========================================================================
  group('2 the OS advisory lock excludes a separate process', () {
    test('every operation refuses with its own typed busy result', () async {
      final StorageLayout layout = _freshLayout();

      // A real save first, so a refusal has something to protect.
      final SaveRepository seed = _repo(layout);
      final GameEngine engine = GameEngine.newGame(registry: registry);
      expect(
        await seed.commit(
          after: engine.state,
          events: const <GameEvent>[],
          saveId: _saveId,
          expectation: const CommitExpectation(
            expectedSnapshotGeneration: -1,
            expectedLastAppliedTransaction: 0,
          ),
          originSaltFingerprint: null,
        ),
        isA<CommitDurable>(),
      );

      final ({Process process, int Function() heartbeats}) holder =
          await _startHolder(layout);

      final SaveRepository repo = _repo(
        layout,
        lockTimeout: const Duration(milliseconds: 200),
      );

      final LoadOutcome load = await repo.load(registry: registry);
      expect(load, isA<LoadRefused>());
      expect((load as LoadRefused).reason, LoadRefusal.storageBusy);

      final EngineResult r = engine.execute(
        const GrantSyntheticSteps(steps: 100, reason: 'busy probe'),
      );
      final CommitOutcome commit = await repo.commit(
        after: engine.state,
        events: r.events,
        saveId: _saveId,
        expectation: const CommitExpectation(
          expectedSnapshotGeneration: 0,
          expectedLastAppliedTransaction: 1,
        ),
        originSaltFingerprint: null,
      );
      expect(commit, isA<CommitRefused>());
      expect((commit as CommitRefused).reason, CommitRefusal.storageBusy);

      final CompactionOutcome compact = await repo.compact();
      expect(compact.refusal, CompactionRefusal.storageBusy);

      final EraseOutcome erase = await repo.eraseAll();
      expect(erase, isA<EraseRefused>());
      expect((erase as EraseRefused).reason, EraseRefusal.storageBusy);

      _say('holder still alive: ${holder.heartbeats()} heartbeats');
      expect(
        holder.heartbeats(),
        greaterThan(0),
        reason:
            'if the child had died, its lock would have been released by the '
            'kernel and these refusals would prove nothing',
      );
    });
  });

  // =========================================================================
  // 3 — process death releases the OS lock
  // =========================================================================
  //
  // This is the property that makes an OS lock acceptable where a sentinel file
  // is not. A sentinel SURVIVES a kill: a crashed holder leaves it behind and
  // every later launch refuses forever. Android kills apps routinely, so a
  // permanently unstartable game is not a rare case.
  group('3 process death releases the OS lock', () {
    test('killing the holder frees the lock for this process', () async {
      final StorageLayout layout = _freshLayout();
      final SaveRepository repo = _repo(layout);

      final GameEngine engine = GameEngine.newGame(registry: registry);
      expect(
        await repo.commit(
          after: engine.state,
          events: const <GameEvent>[],
          saveId: _saveId,
          expectation: const CommitExpectation(
            expectedSnapshotGeneration: -1,
            expectedLastAppliedTransaction: 0,
          ),
          originSaltFingerprint: null,
        ),
        isA<CommitDurable>(),
      );

      final ({Process process, int Function() heartbeats}) holder =
          await _startHolder(layout);
      _say(
        'child pid ${holder.process.pid} holds the lock, '
        '${holder.heartbeats()} heartbeats',
      );

      holder.process.kill(ProcessSignal.sigkill);
      final int code = await holder.process.exitCode;
      _say('child killed, exit code $code');

      // No cleanup of the lock FILE anywhere -- it is deliberately never
      // deleted. The kernel alone releases the lock.
      final EngineResult r = engine.execute(
        const GrantSyntheticSteps(steps: 250, reason: 'after the kill'),
      );
      final CommitOutcome after = await repo.commit(
        after: engine.state,
        events: r.events,
        saveId: _saveId,
        expectation: const CommitExpectation(
          expectedSnapshotGeneration: 0,
          expectedLastAppliedTransaction: 1,
        ),
        originSaltFingerprint: null,
      );
      _say('after the kill: $after');
      expect(
        after,
        isA<CommitDurable>(),
        reason:
            'the kernel must reclaim the lock when the holder dies. If this '
            'fails, a crashed process has bricked the save permanently.',
      );
    });
  });

  // =========================================================================
  // 4 — CAS rejects stale state
  // =========================================================================
  //
  // The third layer, and the one that does not depend on any lock. It is what
  // catches a writer that read the head, was descheduled, and came back after
  // durable state moved underneath it.
  group('4 compare-and-swap rejects stale state', () {
    test('a commit against a superseded generation is refused, and '
        'writes nothing', () async {
      final StorageLayout layout = _freshLayout();
      final SaveRepository repo = _repo(layout);
      final GameEngine engine = GameEngine.newGame(registry: registry);

      expect(
        await repo.commit(
          after: engine.state,
          events: const <GameEvent>[],
          saveId: _saveId,
          expectation: const CommitExpectation(
            expectedSnapshotGeneration: -1,
            expectedLastAppliedTransaction: 0,
          ),
          originSaltFingerprint: null,
        ),
        isA<CommitDurable>(),
      );

      // Move durable state forward.
      final EngineResult first = engine.execute(
        const GrantSyntheticSteps(steps: 300, reason: 'advance the head'),
      );
      expect(
        await repo.commit(
          after: engine.state,
          events: first.events,
          saveId: _saveId,
          expectation: const CommitExpectation(
            expectedSnapshotGeneration: 0,
            expectedLastAppliedTransaction: 1,
          ),
          originSaltFingerprint: null,
        ),
        isA<CommitDurable>(),
      );

      final String before = _durableImage(layout);

      // Now commit against the OLD expectation, which no longer holds.
      final EngineResult stale = engine.execute(
        const GrantSyntheticSteps(steps: 900, reason: 'stale writer'),
      );
      final CommitOutcome out = await repo.commit(
        after: engine.state,
        events: stale.events,
        saveId: _saveId,
        expectation: const CommitExpectation(
          expectedSnapshotGeneration: 0,
          expectedLastAppliedTransaction: 1,
        ),
        originSaltFingerprint: null,
      );

      _say('stale commit -> $out');
      expect(out, isA<CommitRefused>());
      expect(
        (out as CommitRefused).reason,
        CommitRefusal.conflictRetryLimitExhausted,
      );
      expect(
        _durableImage(layout),
        before,
        reason:
            'a refused commit must write NOTHING. A partial write here is a '
            'grant the caller was told did not happen.',
      );
    });
  });

  // =========================================================================
  // The caveat probe — asserts no locking outcome, on purpose
  // =========================================================================
  //
  // Preserved from the removed persistence-owner suite, rewritten to use two
  // plain isolates and no owner. It is the ONLY executed evidence of what the
  // raw kernel lock does between two isolates in one process, and its result is
  // platform-dependent in the worst direction: Windows says `refused`
  // (LockFileEx is per-handle), Linux says `acquired` (fcntl ownership is the
  // process). Recorded in CI run 30767931205.
  //
  // It therefore OBSERVES and asserts nothing about the kernel. Pinning either
  // answer would make the suite red on one platform for a true reason.
  group('cross-process exclusion does NOT prove same-process isolate '
      'exclusion', () {
    test(
      'the raw kernel lock between two isolates is observed, not asserted',
      () async {
        final StorageLayout layout = _freshLayout();
        final FileTransactionLock lock = FileTransactionLock(
          layout.transactionLock,
        );
        final TransactionLockHandle? held = await lock.acquire(
          const Duration(seconds: 5),
        );
        expect(held, isNotNull);

        final ReceivePort rp = ReceivePort();
        await Isolate.spawn(_rawLockProbe, <Object>[
          rp.sendPort,
          layout.transactionLock.path,
        ]);
        final Object observed = await rp.first as Object;
        rp.close();

        _say(
          'raw kernel lock, second ISOLATE, ${Platform.operatingSystem}: '
          '$observed',
        );
        if (observed == 'acquired') {
          _say(
            '   ^ the OS lock did NOT exclude a second isolate. This is the '
            'POSIX finding, and it is why the path-keyed mutex exists and why '
            'a second writer isolate is PROHIBITED rather than handled.',
          );
        } else {
          _say(
            '   ^ this host refused it. That is a property of THIS platform '
            '(LockFileEx is per-handle) and must never be read as a general '
            'guarantee -- on POSIX the same probe reports "acquired".',
          );
        }

        // Deliberately no expectation on `observed`.
        expect(
          observed,
          anyOf('acquired', 'refused'),
          reason: 'the probe must produce a result rather than an error',
        );

        await held!.release();
      },
    );
  });
}

/// Length and CRC of every declared artifact, so a same-length rewrite is still
/// visible. The lock file is excluded: it holds no data and every acquire
/// truncates it.
String _durableImage(StorageLayout layout) {
  final List<String> lines = <String>[];
  for (final File file in layout.allFiles) {
    if (file.path == layout.transactionLock.path) continue;
    if (!file.existsSync()) continue;
    final List<int> bytes = file.readAsBytesSync();
    lines.add(
      '${file.uri.pathSegments.last}:${bytes.length}:'
      '${crc32cHex(Uint8List.fromList(bytes))}',
    );
  }
  lines.sort();
  return lines.join('\n');
}
