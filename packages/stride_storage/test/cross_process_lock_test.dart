// Cross-PROCESS exclusion, through the persistence owner.
//
// This is the file CI runs by name on Linux (`.github/workflows/ci.yml`,
// job `core`, step "stride_storage cross-process lock test (Linux)").
//
// ## What it proves, exactly
//
// A second **operating-system process** holding `transaction.lock` excludes the
// persistence owner, and the owner reports that as the typed busy result rather
// than as a hang, a throw, or a partial write. That is the Android
// process-separation case: an app process and a separate background worker
// process cannot both be inside a transaction.
//
// ## What it does NOT prove — and this is the whole point
//
// **Nothing about two isolates inside one process.** On Linux and macOS Dart
// implements `RandomAccessFile.lock` with `fcntl` record locks, which are owned
// by the process: a second isolate in this process asking for the same range is
// granted it. This test passing on Linux is therefore *fully compatible* with
// the OS lock being completely transparent between isolates, which it is.
//
// Same-process isolate serialization is a property of the persistence-owner
// isolate and of nothing else. It is proved in `persistence_owner_test.dart`,
// case 6, which is named for exactly this confusion.
//
// ## It is not skipped anywhere
//
// A second Dart process and a kernel file lock exist on Windows, Linux and
// macOS alike, and the existing `concurrency_test.dart` case 6 already
// demonstrates the primitive on Windows. Guarding this to POSIX would trade a
// real local signal for nothing, so it runs everywhere and CI additionally runs
// it on Linux, where the shipping platform's semantics live.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:stride_storage/stride_storage.dart';
import 'package:test/test.dart';

const String _saveId = 'cross-process-save-0001';

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

/// Length and digest of every declared artifact, so a same-length rewrite is
/// still visible.
String _durableImage(StorageLayout layout) {
  final List<String> lines = <String>[];
  for (final File file in layout.allFiles) {
    // The lock file is excluded deliberately: it holds no data and every
    // acquire truncates it to zero bytes. It is not part of the save.
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

void main() {
  final Map<String, String> content = _contentFiles;
  final ContentRegistry registry = const ContentLoader()
      .load(ContentSource(content), profileId: BalanceProfile.productionId)
      .requireRegistry;

  test(
    '5 a second OS PROCESS holding the lock refuses the owner with the typed '
    'busy result, and this says nothing about isolates',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'stride_xproc_',
      );
      addTearDown(() {
        try {
          if (temp.existsSync()) temp.deleteSync(recursive: true);
        } on Object {
          // A handle Windows still holds is not the subject under test.
        }
      });
      final Directory root = Directory(
        '${temp.path}/${StorageLayout.directoryName}',
      );
      root.createSync(recursive: true);
      final StorageLayout layout = StorageLayout(root);

      // --- a real save first, so a refusal has something to protect ---------
      PersistenceOwner owner = await PersistenceOwner.spawn(
        PersistenceOwnerConfig(
          storageRoot: root,
          contentFiles: content,
          balanceProfileId: BalanceProfile.productionId.value,
          // Short on purpose: an unbounded wait is a hang, and a hang during a
          // step sync is indistinguishable, to the player, from the game
          // losing their walk.
          lockTimeout: const Duration(milliseconds: 300),
        ),
      );
      addTearDown(() async {
        try {
          await owner.shutdown();
        } on Object {
          // Already gone.
        }
      });

      PersistenceClient client = await PersistenceClient.connect(
        owner.endpoint,
      );
      expect(await client.load(), isA<NoSaveFound>());
      final GameEngine engine = GameEngine.newGame(registry: registry);
      expect(
        await client.commit(
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

      final SaveLoaded head = await client.load() as SaveLoaded;
      final GameEngine writer = GameEngine(
        registry: registry,
        state: head.state,
      );
      final EngineResult granted = writer.execute(
        const GrantSyntheticSteps(steps: 4242, reason: 'blocked by a process'),
      );

      // --- a second OS process takes the lock -------------------------------
      final File script = File('${temp.path}/hold_lock.dart');
      script.writeAsStringSync(_holderScript);
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
        onTimeout: () =>
            throw StateError('the holder never locked. stderr: $childErr'),
      );

      // Liveness is not padding. A holder that exited the instant it printed
      // LOCKED would have its lock released by its own death, and the refusal
      // below would be contention with a ghost.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(
        heartbeats,
        greaterThan(0),
        reason: 'the holder stopped heartbeating before the probe ran',
      );
      _say('holder pid ${holder.pid} holds the lock, $heartbeats heartbeats');

      final String before = _durableImage(layout);
      expect(before, isNotEmpty, reason: 'the fixture must be on the medium');

      // --- the typed refusal ------------------------------------------------
      final Stopwatch clock = Stopwatch()..start();
      final CommitOutcome busy = await client.commit(
        after: writer.state,
        events: granted.events,
        saveId: _saveId,
        expectation: CommitExpectation(
          expectedSnapshotGeneration: head.generation,
          expectedLastAppliedTransaction: head.lastAppliedTransaction,
        ),
        originSaltFingerprint: null,
      );
      clock.stop();
      _say('refused after ${clock.elapsedMilliseconds}ms: $busy');

      expect(
        busy,
        isA<CommitRefused>(),
        reason:
            'a lock held by another PROCESS must exclude the owner isolate, '
            'or the separate-process case -- an Android background worker in '
            'its own process -- is unprotected',
      );
      expect((busy as CommitRefused).reason, CommitRefusal.storageBusy);
      expect(
        clock.elapsed,
        lessThan(const Duration(seconds: 10)),
        reason: 'the refusal must be bounded; an unbounded wait is a hang',
      );
      expect(
        _durableImage(layout),
        before,
        reason: 'a busy refusal must not write, delete, or repair a byte',
      );

      // A read has no safe fallback: NoSaveFound would be a wiped character
      // and a SaveLoaded would be a fabrication. It is a typed refusal, not a
      // throw — a caller that must catch an exception to learn "not now"
      // eventually catches one that meant something else.
      final LoadOutcome busyLoad = await client.load();
      _say('busy load: $busyLoad');
      expect(busyLoad, isA<LoadRefused>());
      expect((busyLoad as LoadRefused).reason, LoadRefusal.storageBusy);
      expect(
        _durableImage(layout),
        before,
        reason: 'a busy load must not write, delete, or repair a byte',
      );

      // Compaction and reset are refused in their own vocabularies, both of
      // which promise the same thing: nothing was touched.
      expect((await client.compact()).refusal, CompactionRefusal.storageBusy);
      final EraseOutcome busyErase = await client.eraseAll();
      expect(busyErase, isA<EraseRefused>());
      expect((busyErase as EraseRefused).reason, EraseRefusal.storageBusy);
      expect(
        _durableImage(layout),
        before,
        reason:
            'a refused reset must record no intent and delete nothing. This '
            'is the assertion that a busy erase is not a half-erase',
      );

      final int beatsBefore = heartbeats;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(
        heartbeats,
        greaterThan(beatsBefore),
        reason:
            'the holder died during the probe, so the refusal may have been '
            'contention with a ghost rather than with a live holder',
      );

      // --- and it is transient, not a wedge ---------------------------------
      holder.kill(ProcessSignal.sigkill);
      final int code = await holder.exitCode.timeout(
        const Duration(seconds: 15),
      );
      _say('holder killed, exit code $code');

      // The kernel released it, not the child: it was killed, not asked to
      // clean up. This is why an OS lock and not a sentinel file — a sentinel
      // survives the kill and refuses every later launch forever.
      await owner.shutdown();
      owner = await PersistenceOwner.spawn(
        PersistenceOwnerConfig(
          storageRoot: root,
          contentFiles: content,
          balanceProfileId: BalanceProfile.productionId.value,
          lockTimeout: const Duration(seconds: 5),
        ),
      );
      client = await PersistenceClient.connect(owner.endpoint);

      final SaveLoaded reread = await client.load() as SaveLoaded;
      final GameEngine retry = GameEngine(
        registry: registry,
        state: reread.state,
      );
      final EngineResult again = retry.execute(
        const GrantSyntheticSteps(steps: 4242, reason: 'after the holder died'),
      );
      expect(
        await client.commit(
          after: retry.state,
          events: again.events,
          saveId: _saveId,
          expectation: CommitExpectation(
            expectedSnapshotGeneration: reread.generation,
            expectedLastAppliedTransaction: reread.lastAppliedTransaction,
          ),
          originSaltFingerprint: null,
        ),
        isA<CommitDurable>(),
        reason:
            'the lock survived the death of its holder, which is the sentinel-'
            'file failure mode: every later launch refuses forever, and '
            'Android kills apps routinely',
      );
      expect(
        (await client.load() as SaveLoaded).state.steps.totalGranted,
        4242,
        reason: 'the refused commit must not have landed as well',
      );
      expect(
        layout.transactionLock.existsSync(),
        isTrue,
        reason:
            'the lock file is never deleted -- deleting a file another process '
            'holds a lock on leaves two processes locking two inodes that '
            'share a name',
      );

      await client.close();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// A standalone program that takes the lock and holds it until killed.
///
/// The periodic timer is load-bearing: the Dart VM exits when the event loop
/// has no pending work, and an uncompleted `Completer` is not pending work. A
/// holder without it exits the instant it prints LOCKED.
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
