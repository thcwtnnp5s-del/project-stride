// Adversarial proof of the persistence-owner isolate.
//
// ## The finding these tests close
//
// `concurrency_test.dart` proves `FileTransactionLock` excludes a second
// PROCESS. That is a different property from excluding a second ISOLATE, and on
// POSIX the second property is simply false: Dart implements
// `RandomAccessFile.lock` with `fcntl` record locks, which are owned by the
// process. Two isolates in one process are one lock owner. An Android Health
// Connect background isolate is therefore not excluded by the file lock at all.
//
// Case 6 in this file exists so those two properties can never be conflated
// again. It observes what the OS lock actually does between two isolates on the
// host it runs on, prints it, and then proves that the owner isolate — not the
// OS lock — is what serializes them.
//
// | Case | Attack |
// |---|---|
// | 1 | Many caller isolates committing at once; is execution serialized? |
// | 2 | N requests -> N results, no duplicate, no loss |
// | 3 | Does the on-disk journal fork under isolate concurrency? |
// | 4 | Kill the owner mid-flight: typed failure, and a recoverable relaunch |
// | 6 | Cross-process locking success does NOT prove same-process exclusion |
//
// Case 5 is cross-process locking and lives in `cross_process_lock_test.dart`,
// because CI runs that file by name on Linux.
//
// ## Why the step batches are powers of two
//
// Every commit grants a distinct power of two, so the durable `totalGranted` is
// a bitmask naming exactly which commits landed. A dropped grant and a
// double-counted grant land on different numbers, and the number says which
// one went wrong rather than merely that something did.

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

const String _saveId = 'owner-isolate-save-0001';

Map<String, String> get _contentFiles {
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
    return files;
  }
  throw StateError('content not found from ${Directory.current.path}');
}

void _say(Object? m) => stdout.writeln('  >> $m');

Directory _freshRoot() {
  final Directory temp = Directory.systemTemp.createTempSync('stride_owner_');
  addTearDown(() {
    try {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    } on Object {
      // A directory Windows still holds a handle on is not the subject under
      // test; the handle-release assertions live in concurrency_test.dart.
    }
  });
  final Directory root = Directory(
    '${temp.path}/${StorageLayout.directoryName}',
  );
  root.createSync(recursive: true);
  return root;
}

Future<PersistenceOwner> _spawnOwner(
  Directory root,
  Map<String, String> content, {
  Duration lockTimeout = const Duration(seconds: 5),
  int maxCommitRetries = 8,
}) async {
  final PersistenceOwner owner = await PersistenceOwner.spawn(
    PersistenceOwnerConfig(
      storageRoot: root,
      contentFiles: content,
      balanceProfileId: BalanceProfile.productionId.value,
      lockTimeout: lockTimeout,
      maxCommitRetries: maxCommitRetries,
    ),
  );
  addTearDown(() async {
    try {
      await owner.shutdown();
    } on Object {
      // Already dead in the kill probes. Shutting down a corpse is a no-op.
    }
  });
  return owner;
}

/// Writes the genesis save through the owner, so every probe attacks a
/// populated directory.
Future<void> _seed(PersistenceClient client, ContentRegistry registry) async {
  expect(await client.load(), isA<NoSaveFound>());
  final GameEngine engine = GameEngine.newGame(registry: registry);
  final CommitOutcome outcome = await client.commit(
    after: engine.state,
    events: const <GameEvent>[],
    saveId: _saveId,
    expectation: const CommitExpectation(
      expectedSnapshotGeneration: -1,
      expectedLastAppliedTransaction: 0,
    ),
    originSaltFingerprint: null,
  );
  expect(outcome, isA<CommitDurable>(), reason: 'the seed must commit');
}

/// Every transaction id physically present in the journal.
List<int> _journalTransactionIds(Directory root) {
  final StorageLayout layout = StorageLayout(root);
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

/// A journal line's id paired with a digest of its contents.
///
/// The fork condition is not "a repeated id" but "a repeated id carrying
/// different content" — the same id with identical content is an absorbed
/// at-least-once append, which the protocol is designed to tolerate.
Map<int, Set<String>> _journalContentById(Directory root) {
  final StorageLayout layout = StorageLayout(root);
  final Map<int, Set<String>> byId = <int, Set<String>>{};
  if (!layout.journal.existsSync()) return byId;
  final Uint8List bytes = layout.journal.readAsBytesSync();
  int start = 0;
  for (int i = 0; i < bytes.length; i++) {
    if (bytes[i] != 0x0A) continue;
    final Uint8List line = Uint8List.sublistView(bytes, start, i + 1);
    start = i + 1;
    final JournalLineResult parsed = decodeJournalLine(line);
    if (!parsed.ok) continue;
    byId
        .putIfAbsent(parsed.record!.transactionId, () => <String>{})
        .add(crc32cHex(line));
  }
  return byId;
}

/// Trims a serialization trace to start on a `begin:` entry.
///
/// The owner's trace is bounded, so a long run can be cut mid-pair. Trimming is
/// honest; asserting on a half pair would be a flake.
List<String> _fromFirstBegin(List<String> trace) {
  final int first = trace.indexWhere((String e) => e.startsWith('begin:'));
  return first < 0 ? const <String>[] : trace.sublist(first);
}

// ---------------------------------------------------------------------------
// Caller isolates
// ---------------------------------------------------------------------------

/// A caller isolate that commits a list of step batches through the owner.
///
/// It retries on compare-and-swap conflict and on a busy refusal, because a
/// refusal is a legitimate outcome of contention and the property under test is
/// that every batch lands **exactly once**, not that it lands on the first try.
Future<void> _committerIsolate(List<Object?> args) async {
  final SendPort results = args[0] as SendPort;
  final SendPort supervisor = args[1] as SendPort;
  final Map<String, String> content = (args[2] as Map<Object?, Object?>).map(
    (Object? k, Object? v) =>
        MapEntry<String, String>(k as String, v as String),
  );
  final List<int> batches = <int>[
    for (final Object? b in args[3] as List<Object?>) b as int,
  ];
  final String label = args[4] as String;

  final List<Object?> report = <Object?>[];
  try {
    final ContentRegistry registry = const ContentLoader()
        .load(ContentSource(content), profileId: BalanceProfile.productionId)
        .requireRegistry;
    final PersistenceClient client = await PersistenceClient.connect(
      PersistenceEndpoint(supervisor),
    );

    for (final int batch in batches) {
      Object? landed;
      for (int attempt = 0; attempt < 400 && landed == null; attempt++) {
        final LoadOutcome head = await client.load();
        if (head is! SaveLoaded) {
          landed = 'load-not-saveloaded:${head.runtimeType}';
          break;
        }
        final GameEngine engine = GameEngine(
          registry: registry,
          state: head.state,
        );
        final EngineResult r = engine.execute(
          GrantSyntheticSteps(steps: batch, reason: label),
        );
        final CommitOutcome outcome = await client.commit(
          after: engine.state,
          events: r.events,
          saveId: _saveId,
          expectation: CommitExpectation(
            expectedSnapshotGeneration: head.generation,
            expectedLastAppliedTransaction: head.lastAppliedTransaction,
          ),
          originSaltFingerprint: null,
        );
        if (outcome is CommitDurable) {
          landed = <Object?>[batch, outcome.transactionId, outcome.generation];
        } else {
          // Contention. Yield, then reload against the newer head — which is
          // safe precisely because F-04 grants max(0, observed - granted).
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      }
      report.add(landed ?? 'exhausted:$batch');
    }
    await client.close();
    results.send(<Object?>['ok', label, report]);
  } on Object catch (e, st) {
    results.send(<Object?>['error', label, '$e\n$st']);
  }
}

/// A caller isolate that fires N `stats` requests concurrently.
///
/// `stats` is the one operation whose reply is unique per execution: it carries
/// the owner's served counter, incremented once per request. So N requests that
/// each ran exactly once produce N *distinct* counter values, and a duplicate
/// delivery or a lost reply is visible as a repeated or missing number rather
/// than having to be inferred.
Future<void> _statsStormIsolate(List<Object?> args) async {
  final SendPort results = args[0] as SendPort;
  final SendPort supervisor = args[1] as SendPort;
  final int count = args[2] as int;
  final String label = args[3] as String;

  try {
    final PersistenceClient client = await PersistenceClient.connect(
      PersistenceEndpoint(supervisor),
    );
    final List<PersistenceOwnerStats> all = await Future.wait(
      <Future<PersistenceOwnerStats>>[
        for (int i = 0; i < count; i++) client.stats(),
      ],
    );
    await client.close();
    results.send(<Object?>[
      'ok',
      label,
      <int>[for (final PersistenceOwnerStats s in all) s.served],
      all.last.maxConcurrentHandlers,
    ]);
  } on Object catch (e, st) {
    results.send(<Object?>['error', label, '$e\n$st']);
  }
}

/// An isolate that tries to take the OS lock and reports what the kernel said.
///
/// Deliberately uses `RandomAccessFile.lock` directly rather than
/// `FileTransactionLock`, so what is observed is the raw platform behaviour and
/// not this project's polling wrapper.
Future<void> _rawLockProbeIsolate(List<Object?> args) async {
  final SendPort results = args[0] as SendPort;
  final String path = args[1] as String;
  final ReceivePort release = ReceivePort();
  results.send(<Object?>['port', release.sendPort]);

  RandomAccessFile? handle;
  try {
    handle = await File(path).open(mode: FileMode.write);
    await handle.lock(FileLock.exclusive);
    results.send(<Object?>['acquired']);
  } on FileSystemException catch (e) {
    results.send(<Object?>['refused', '${e.osError ?? e.message}']);
    await handle?.close();
    release.close();
    return;
  }

  // Held until the parent says to let go, so the second probe genuinely
  // overlaps the first.
  await release.first;
  await handle.unlock();
  await handle.close();
  release.close();
  results.send(<Object?>['released']);
}

// ---------------------------------------------------------------------------

void main() {
  final Map<String, String> content = _contentFiles;
  final ContentRegistry registry = const ContentLoader()
      .load(ContentSource(content), profileId: BalanceProfile.productionId)
      .requireRegistry;

  // =========================================================================
  // 1 — many caller isolates, one owner, serialized
  // =========================================================================
  group('1 caller isolates are serialized through one owner', () {
    test(
      'four isolates commit twelve batches and execution never overlaps',
      () async {
        final Directory root = _freshRoot();
        final PersistenceOwner owner = await _spawnOwner(root, content);

        final PersistenceClient seeder = await PersistenceClient.connect(
          owner.endpoint,
        );
        await _seed(seeder, registry);

        // Distinct powers of two: the durable total is a bitmask naming
        // exactly which of the twelve commits landed.
        const int callers = 4;
        const int perCaller = 3;
        final ReceivePort inbox = ReceivePort();
        final List<Object?> reports = <Object?>[];
        final Completer<void> allDone = Completer<void>();
        inbox.listen((Object? message) {
          reports.add(message);
          if (reports.length == callers && !allDone.isCompleted) {
            allDone.complete();
          }
        });

        for (int i = 0; i < callers; i++) {
          await Isolate.spawn(_committerIsolate, <Object?>[
            inbox.sendPort,
            owner.endpoint.supervisor,
            content,
            <int>[for (int j = 0; j < perCaller; j++) 1 << (i * perCaller + j)],
            'caller-$i',
          ], debugName: 'stride-caller-$i');
        }

        await allDone.future.timeout(const Duration(minutes: 3));
        inbox.close();

        for (final Object? report in reports) {
          expect(
            (report! as List<Object?>).first,
            'ok',
            reason: 'a caller isolate failed: $report',
          );
        }
        _say('caller reports: $reports');

        // --- serialization ------------------------------------------------
        final PersistenceOwnerStats stats = await seeder.stats();
        expect(
          stats.maxConcurrentHandlers,
          1,
          reason:
              'the owner ran ${stats.maxConcurrentHandlers} request handlers at '
              'once. With more than one in flight the queue is decorative and '
              'two callers can interleave their read-head-to-append window, '
              'which is the exact race that forks the journal',
        );

        final List<String> trace = _fromFirstBegin(stats.trace);
        expect(trace.length, greaterThan(8), reason: 'the trace is too short');
        for (int i = 0; i + 1 < trace.length; i += 2) {
          expect(
            trace[i].startsWith('begin:'),
            isTrue,
            reason: 'trace entry $i is not a begin: ${trace[i]}',
          );
          expect(
            trace[i + 1],
            'end:${trace[i].substring('begin:'.length)}',
            reason:
                'request ${trace[i]} was still open when ${trace[i + 1]} '
                'happened, so two handlers overlapped',
          );
        }
        _say(
          'served ${stats.served} requests, max concurrent '
          '${stats.maxConcurrentHandlers}, ops ${stats.byOperation}',
        );

        // --- every batch landed exactly once -------------------------------
        final LoadOutcome after = await seeder.load();
        expect(after, isA<SaveLoaded>());
        expect(
          (after as SaveLoaded).state.steps.totalGranted,
          (1 << (callers * perCaller)) - 1,
          reason:
              'the durable total is a bitmask of the twelve batches. A missing '
              'bit is a lost grant; an impossible total is a double grant',
        );
        expect(
          after.repairs.map((SaveRepair r) => r.diagnosis),
          isNot(contains(SaveDiagnosis.journalDuplicateTransaction)),
          reason:
              'a duplicate transaction was absorbed, which silently discards '
              'that batch of granted steps',
        );
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });

  // =========================================================================
  // 2 — exactly-once: N requests, N results
  // =========================================================================
  group('2 exactly-once request semantics', () {
    test(
      'one hundred concurrent requests from five isolates produce one hundred '
      'distinct results',
      () async {
        final Directory root = _freshRoot();
        final PersistenceOwner owner = await _spawnOwner(root, content);

        const int callers = 5;
        const int perCaller = 20;
        final ReceivePort inbox = ReceivePort();
        final List<Object?> reports = <Object?>[];
        final Completer<void> allDone = Completer<void>();
        inbox.listen((Object? message) {
          reports.add(message);
          if (reports.length == callers && !allDone.isCompleted) {
            allDone.complete();
          }
        });

        for (int i = 0; i < callers; i++) {
          await Isolate.spawn(_statsStormIsolate, <Object?>[
            inbox.sendPort,
            owner.endpoint.supervisor,
            perCaller,
            'storm-$i',
          ], debugName: 'stride-storm-$i');
        }
        await allDone.future.timeout(const Duration(minutes: 2));
        inbox.close();

        final List<int> observed = <int>[];
        for (final Object? report in reports) {
          final List<Object?> entry = report! as List<Object?>;
          expect(entry.first, 'ok', reason: 'a storm isolate failed: $report');
          for (final Object? served in entry[2]! as List<Object?>) {
            observed.add(served! as int);
          }
          expect(entry[3], 1, reason: 'the owner overlapped two handlers');
        }

        observed.sort();
        _say('served counters observed: ${observed.first}..${observed.last}');

        expect(
          observed,
          hasLength(callers * perCaller),
          reason: 'a reply was lost: fewer results than requests',
        );
        // The counter is incremented once per executed request, so the k-th
        // request to run observes k-1. A duplicated execution repeats a number
        // and a lost one leaves a hole; both are visible here and neither is
        // inferred.
        expect(
          observed.toSet(),
          hasLength(callers * perCaller),
          reason:
              'two requests observed the same served counter, so one request '
              'was executed twice or one reply was delivered twice',
        );
        expect(
          observed,
          <int>[for (int i = 0; i < callers * perCaller; i++) i],
          reason:
              'the served counters are not the complete range 0..N-1, so the '
              'owner executed something other than exactly these N requests',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  // =========================================================================
  // 3 — the on-disk journal does not fork
  // =========================================================================
  group('3 no journal fork under isolate concurrency', () {
    test(
      'ids are strictly increasing and no id carries two different records',
      () async {
        final Directory root = _freshRoot();
        final PersistenceOwner owner = await _spawnOwner(root, content);
        final PersistenceClient client = await PersistenceClient.connect(
          owner.endpoint,
        );
        await _seed(client, registry);

        const int callers = 3;
        const int perCaller = 2;
        final ReceivePort inbox = ReceivePort();
        final List<Object?> reports = <Object?>[];
        final Completer<void> allDone = Completer<void>();
        inbox.listen((Object? message) {
          reports.add(message);
          if (reports.length == callers && !allDone.isCompleted) {
            allDone.complete();
          }
        });
        for (int i = 0; i < callers; i++) {
          await Isolate.spawn(_committerIsolate, <Object?>[
            inbox.sendPort,
            owner.endpoint.supervisor,
            content,
            <int>[for (int j = 0; j < perCaller; j++) 1 << (i * perCaller + j)],
            'forkprobe-$i',
          ], debugName: 'stride-fork-$i');
        }
        await allDone.future.timeout(const Duration(minutes: 3));
        inbox.close();
        for (final Object? report in reports) {
          expect((report! as List<Object?>).first, 'ok', reason: '$report');
        }

        // Shut the owner down first, so nothing is mid-append while the medium
        // is read behind its back.
        await owner.shutdown();

        final List<int> ids = _journalTransactionIds(root);
        _say('journal ids on disk: $ids');
        expect(
          ids,
          isNot(contains(-1)),
          reason: 'an unparseable journal line survived a clean shutdown',
        );
        for (int i = 1; i < ids.length; i++) {
          expect(
            ids[i],
            greaterThan(ids[i - 1]),
            reason:
                'transaction ids are not strictly increasing: $ids. A repeat '
                'or a regression means two writers computed the same next id',
          );
        }

        final Map<int, Set<String>> byId = _journalContentById(root);
        for (final MapEntry<int, Set<String>> entry in byId.entries) {
          expect(
            entry.value,
            hasLength(1),
            reason:
                'transaction ${entry.key} appears with ${entry.value.length} '
                'different contents. That is a forked journal, and it is a '
                'permanent brick: journalForked refuses every load, and '
                'compaction can only run inside a commit, which needs a load',
          );
        }

        // And the next launch opens it, which is the property a fork destroys.
        final PersistenceOwner relaunched = await _spawnOwner(root, content);
        final PersistenceClient reader = await PersistenceClient.connect(
          relaunched.endpoint,
        );
        final LoadOutcome outcome = await reader.load();
        expect(outcome, isA<SaveLoaded>(), reason: 'reopen failed: $outcome');
        expect(
          (outcome as SaveLoaded).state.steps.totalGranted,
          (1 << (callers * perCaller)) - 1,
        );
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });

  // =========================================================================
  // 4 — owner death is typed and recoverable
  // =========================================================================
  //
  // The owner is made genuinely busy by a SECOND OS PROCESS holding the
  // transaction lock, not by holding it from this isolate. On POSIX a lock
  // taken in this isolate would be granted to the owner isolate as well — the
  // very defect this file exists for — so a same-process holder would make the
  // probe pass on Windows and prove nothing on Linux.
  group('4 owner death is a typed failure, and relaunch recovers', () {
    test('in-flight and subsequent callers get a typed failure, and a relaunch '
        'loads a consistent state', () async {
      final Directory root = _freshRoot();
      final StorageLayout layout = StorageLayout(root);

      // A real save first, so the relaunch has something to be consistent
      // about.
      final PersistenceOwner first = await _spawnOwner(root, content);
      final PersistenceClient seeder = await PersistenceClient.connect(
        first.endpoint,
      );
      await _seed(seeder, registry);
      final SaveLoaded head = await seeder.load() as SaveLoaded;
      final GameEngine engine = GameEngine(
        registry: registry,
        state: head.state,
      );
      final EngineResult granted = engine.execute(
        const GrantSyntheticSteps(steps: 8191, reason: 'before the kill'),
      );
      expect(
        await seeder.commit(
          after: engine.state,
          events: granted.events,
          saveId: _saveId,
          expectation: CommitExpectation(
            expectedSnapshotGeneration: head.generation,
            expectedLastAppliedTransaction: head.lastAppliedTransaction,
          ),
          originSaltFingerprint: null,
        ),
        isA<CommitDurable>(),
      );
      await seeder.close();
      await first.shutdown();

      // --- an external process takes the lock ---------------------------
      final File script = File('${root.path}/../hold_lock.dart');
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
      int heartbeats = 0;
      final StringBuffer childErr = StringBuffer();
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
          'the lock holder never started. stderr: $childErr',
        ),
      );

      // --- a request that is genuinely still in flight -------------------
      final PersistenceOwner owner = await _spawnOwner(
        root,
        content,
        // Long enough that the request cannot finish on its own during the
        // window in which it is killed.
        lockTimeout: const Duration(seconds: 60),
      );
      final PersistenceClient inFlightCaller = await PersistenceClient.connect(
        owner.endpoint,
      );
      final PersistenceClient laterCaller = await PersistenceClient.connect(
        owner.endpoint,
      );

      final Future<CommitOutcome> pending = inFlightCaller.commit(
        after: engine.state,
        events: granted.events,
        saveId: _saveId,
        expectation: const CommitExpectation(
          expectedSnapshotGeneration: 99,
          expectedLastAppliedTransaction: 99,
        ),
        originSaltFingerprint: null,
      );
      bool settled = false;
      // Both arms mark it settled. The commit is expected to fail once the
      // owner is killed, and an unhandled error on this future would fail the
      // test for the wrong reason; what is being observed here is only
      // *whether* it finished, not how.
      unawaited(
        pending.then<void>(
          (_) {
            settled = true;
          },
          onError: (Object _, StackTrace _) {
            settled = true;
          },
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(
        settled,
        isFalse,
        reason:
            'the commit finished before the kill, so nothing was in flight '
            'and the probe would prove nothing',
      );
      final int beats = heartbeats;
      expect(
        beats,
        greaterThan(0),
        reason: 'the external lock holder was never alive',
      );

      // Killed, not asked to stop. A cooperative shutdown would prove
      // nothing about process pressure or an uncaught error.
      await owner.kill();
      expect(owner.alive, isFalse);

      // The in-flight caller is answered, and answered in a type that does
      // NOT claim nothing was written. The owner was killed at an arbitrary
      // instant: it could have appended a durable journal record and died
      // before replying, and `CommitRefusal.storageBusy` asserts the opposite
      // of that. An indeterminate outcome must say so.
      Object? inFlight;
      try {
        inFlight = await pending.timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw StateError(
            'the in-flight commit never settled after the owner died. A '
            'dropped completer here is a permanent silent hang during a step '
            'sync, which to the player is indistinguishable from the game '
            'losing their walk',
          ),
        );
      } on PersistenceUnavailable catch (e) {
        inFlight = e;
      }
      _say('in-flight outcome after the kill: $inFlight');
      expect(
        inFlight,
        isA<PersistenceUnavailable>(),
        reason:
            'a dead owner must stay distinguishable from a busy one. '
            'CommitRefused(storageBusy) here would promise "nothing was '
            'written" about a transaction whose fate nobody observed',
      );
      expect(
        (inFlight as PersistenceUnavailable).failure,
        PersistenceFailure.storageUnavailable,
      );

      // The down notice reaches each registered client on its own port, and
      // port-to-port delivery order is not ordered between ports. A short
      // settle keeps this an assertion about the *design* rather than about
      // scheduler luck.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // A caller that arrives afterwards fails fast rather than parking on
      // a port nothing is listening to. Same type, same reason.
      await expectLater(
        laterCaller
            .commit(
              after: engine.state,
              events: granted.events,
              saveId: _saveId,
              expectation: const CommitExpectation(
                expectedSnapshotGeneration: 99,
                expectedLastAppliedTransaction: 99,
              ),
              originSaltFingerprint: null,
            )
            .timeout(const Duration(seconds: 10)),
        throwsA(
          isA<PersistenceUnavailable>().having(
            (PersistenceUnavailable e) => e.failure,
            'failure',
            PersistenceFailure.storageUnavailable,
          ),
        ),
      );
      await expectLater(
        laterCaller.load().timeout(const Duration(seconds: 10)),
        throwsA(
          isA<PersistenceUnavailable>().having(
            (PersistenceUnavailable e) => e.failure,
            'failure',
            PersistenceFailure.storageUnavailable,
          ),
          // Never NoSaveFound, which would be a wiped character, and never a
          // fabricated SaveLoaded.
        ),
      );

      // --- and the save is still openable --------------------------------
      holder.kill(ProcessSignal.sigkill);
      await holder.exitCode.timeout(const Duration(seconds: 15));

      await owner.restart();
      expect(owner.alive, isTrue);

      // The already-registered client is told about the new owner and works
      // again without reconnecting.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final LoadOutcome recovered = await laterCaller.load().timeout(
        const Duration(seconds: 30),
      );
      _say('after restart: $recovered');
      expect(
        recovered,
        isA<SaveLoaded>(),
        reason:
            'the save could not be opened after the owner died. A killed '
            'owner must leave the medium in a state the next launch can '
            'read, or an Android app kill is a bricked save',
      );
      expect(
        (recovered as SaveLoaded).state.steps.totalGranted,
        8191,
        reason:
            'the durable state changed across an owner death. Nothing had '
            'committed after the seed, so nothing may have moved',
      );
      expect(
        _journalContentById(
          root,
        ).values.every((Set<String> s) => s.length == 1),
        isTrue,
        reason: 'the killed owner left a forked journal behind',
      );
    }, timeout: const Timeout(Duration(minutes: 4)));

    test(
      'a shut-down owner refuses in a typed way rather than hanging',
      () async {
        final Directory root = _freshRoot();
        final PersistenceOwner owner = await _spawnOwner(root, content);
        final PersistenceClient client = await PersistenceClient.connect(
          owner.endpoint,
        );
        await _seed(client, registry);
        await owner.shutdown();

        // Every operation answers, and every one of them answers *at all* —
        // the timeouts are the assertion that none of these parks forever on
        // a port nothing is listening to.
        //
        // All five are `PersistenceUnavailable` and none is `storageBusy`.
        // The storage was not busy; there is no owner. Conflating the two
        // would have `storageBusy`'s "nothing was written" cover a case where
        // nobody knows.
        final GameEngine engine = GameEngine.newGame(registry: registry);
        final Matcher unreachable = throwsA(
          isA<PersistenceUnavailable>().having(
            (PersistenceUnavailable e) => e.failure,
            'failure',
            PersistenceFailure.storageUnavailable,
          ),
        );

        await expectLater(
          client.load().timeout(const Duration(seconds: 10)),
          unreachable,
        );
        await expectLater(
          client.compact().timeout(const Duration(seconds: 10)),
          unreachable,
        );
        await expectLater(
          client.eraseAll().timeout(const Duration(seconds: 10)),
          unreachable,
        );
        await expectLater(
          client
              .commit(
                after: engine.state,
                events: const <GameEvent>[],
                saveId: _saveId,
                expectation: const CommitExpectation(
                  expectedSnapshotGeneration: 0,
                  expectedLastAppliedTransaction: 1,
                ),
                originSaltFingerprint: null,
              )
              .timeout(const Duration(seconds: 10)),
          unreachable,
        );
        await expectLater(
          client.stats().timeout(const Duration(seconds: 10)),
          unreachable,
        );
        await client.close();
      },
    );
  });

  // =========================================================================
  // 6 — cross-process locking does NOT prove same-process isolate locking
  // =========================================================================
  //
  // READ THIS BEFORE DELETING OR "SIMPLIFYING" THIS TEST.
  //
  // `concurrency_test.dart` case 6 and `cross_process_lock_test.dart` prove
  // that `RandomAccessFile.lock(FileLock.exclusive)` excludes a second OS
  // PROCESS. Those tests are correct and they are green. They say nothing
  // whatsoever about two ISOLATES inside one process:
  //
  //   * POSIX (`fcntl`) locks are owned by the PROCESS. A second isolate in the
  //     same process asking for the same range is GRANTED it, and closing any
  //     descriptor onto that file releases the whole process's locks.
  //   * Windows (`LockFileEx`) locks are owned by the HANDLE, so a second
  //     isolate IS refused.
  //
  // So the property is platform-dependent in the worst possible direction: it
  // holds on the development machine and fails on the shipping platform. This
  // test therefore does not assert a locking outcome at all. It records what
  // the host actually did, prints it, and asserts the thing that is true
  // everywhere — that the OWNER ISOLATE is what serializes two isolates.
  group('6 cross-process lock exclusion does NOT prove same-process isolate '
      'exclusion', () {
    test(
      'two isolates race the raw OS lock; the result is recorded, not '
      'assumed, and the owner isolate is what actually serializes them',
      () async {
        final Directory root = _freshRoot();
        final StorageLayout layout = StorageLayout(root);

        // --- what does the raw kernel lock do between two isolates? -------
        Future<List<Object?>> probe(String name) async {
          final ReceivePort inbox = ReceivePort();
          final StreamIterator<Object?> messages = StreamIterator<Object?>(
            inbox,
          );
          await Isolate.spawn(_rawLockProbeIsolate, <Object?>[
            inbox.sendPort,
            layout.transactionLock.path,
          ], debugName: name);
          await messages.moveNext();
          final SendPort release =
              (messages.current! as List<Object?>)[1] as SendPort;
          await messages.moveNext();
          final List<Object?> result = messages.current! as List<Object?>;
          return <Object?>[result, release, messages, inbox];
        }

        final List<Object?> a = await probe('stride-lock-a');
        expect(
          (a[0]! as List<Object?>).first,
          'acquired',
          reason: 'the first isolate could not take an uncontended lock',
        );

        final List<Object?> b = await probe('stride-lock-b');
        final String second = (b[0]! as List<Object?>).first! as String;

        _say('platform: ${Platform.operatingSystem}');
        _say(
          'a second ISOLATE in this process asking for a lock the first '
          'isolate holds was: $second',
        );
        if (second == 'acquired') {
          _say(
            'CONFIRMED: the OS lock does NOT exclude a second isolate here. '
            'This is the documented POSIX fcntl behaviour, and it is why the '
            'persistence-owner isolate exists.',
          );
        } else {
          _say(
            'This host refused the second isolate (Windows LockFileEx is '
            'per-handle). That is a HOST property and must never be relied '
            'on: on Linux and macOS the same code grants the lock, and '
            'Android is Linux.',
          );
        }
        expect(
          second,
          anyOf('acquired', 'refused'),
          reason: 'the probe did not produce a lock outcome at all',
        );

        (a[1]! as SendPort).send(null);
        if (second == 'acquired') (b[1]! as SendPort).send(null);
        await (a[2]! as StreamIterator<Object?>).cancel();
        await (b[2]! as StreamIterator<Object?>).cancel();
        (a[3]! as ReceivePort).close();
        (b[3]! as ReceivePort).close();

        // --- the layer that IS reliable ------------------------------------
        final PersistenceOwner owner = await _spawnOwner(root, content);
        final PersistenceClient client = await PersistenceClient.connect(
          owner.endpoint,
        );
        await _seed(client, registry);

        const int callers = 2;
        const int perCaller = 2;
        final ReceivePort inbox = ReceivePort();
        final List<Object?> reports = <Object?>[];
        final Completer<void> allDone = Completer<void>();
        inbox.listen((Object? message) {
          reports.add(message);
          if (reports.length == callers && !allDone.isCompleted) {
            allDone.complete();
          }
        });
        for (int i = 0; i < callers; i++) {
          await Isolate.spawn(_committerIsolate, <Object?>[
            inbox.sendPort,
            owner.endpoint.supervisor,
            content,
            <int>[for (int j = 0; j < perCaller; j++) 1 << (i * perCaller + j)],
            'caveat-$i',
          ], debugName: 'stride-caveat-$i');
        }
        await allDone.future.timeout(const Duration(minutes: 3));
        inbox.close();
        for (final Object? report in reports) {
          expect((report! as List<Object?>).first, 'ok', reason: '$report');
        }

        final PersistenceOwnerStats stats = await client.stats();
        expect(
          stats.maxConcurrentHandlers,
          1,
          reason:
              'two isolates overlapped inside the owner. Whatever the OS '
              'lock did above, THIS is the layer that has to serialize them, '
              'and it did not',
        );
        final LoadOutcome after = await client.load();
        expect(
          (after as SaveLoaded).state.steps.totalGranted,
          (1 << (callers * perCaller)) - 1,
          reason: 'a grant was lost or duplicated between two isolates',
        );
        final Map<int, Set<String>> byId = _journalContentById(root);
        for (final MapEntry<int, Set<String>> entry in byId.entries) {
          expect(entry.value, hasLength(1), reason: 'forked at ${entry.key}');
        }
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });
}

/// A standalone program that takes the lock and holds it until killed.
///
/// Pure `dart:io`, so it needs no package resolution. A periodic timer keeps
/// the VM alive: the Dart VM exits when the event loop is empty, and an
/// uncompleted `Completer` is not pending work — a holder without the timer
/// exits immediately and its lock dies with it, which reads as "the lock did
/// not hold".
const String _holderScript = r'''
import 'dart:async';
import 'dart:io';

Future<void> main(List<String> args) async {
  final RandomAccessFile handle = await File(args[0]).open(mode: FileMode.write);
  await handle.lock(FileLock.exclusive);
  stdout.writeln('LOCKED');
  await stdout.flush();
  Timer.periodic(const Duration(milliseconds: 100), (Timer _) {
    stdout.writeln('ALIVE');
  });
  await Completer<void>().future;
}
''';
