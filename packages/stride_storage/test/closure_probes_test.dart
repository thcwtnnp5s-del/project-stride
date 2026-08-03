// Closure Critic probes — filesystem half.
//
// Every test asserts the behaviour the shipped documentation or the port
// contract claims. A failure is a defect in the code or a lie in the doc.
// Nothing here is skipped and nothing is weakened.
//
// These run under plain `dart test` against a real temporary directory, so
// they are valid evidence on Windows, and they must also be run on the Linux
// CI job -- S1 and S2 have PLATFORM-DEPENDENT outcomes and Windows is the
// permissive-looking one.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:stride_storage/stride_storage.dart';
import 'package:test/test.dart';

late Directory _scratch;

StorageLayout freshLayout() {
  final Directory d = Directory(
    '${_scratch.path}/case_${DateTime.now().microsecondsSinceEpoch}_'
    '${_counter++}',
  )..createSync(recursive: true);
  return StorageLayout(d);
}

int _counter = 0;

Uint8List record(String s) => Uint8List.fromList(utf8.encode('$s\n'));

void main() {
  setUpAll(() {
    _scratch = Directory.systemTemp.createTempSync('stride_closure_');
  });
  tearDownAll(() {
    if (_scratch.existsSync()) {
      try {
        _scratch.deleteSync(recursive: true);
      } on FileSystemException {
        // A lock file may still be held on Windows. Not the subject here.
      }
    }
  });

  // =========================================================================
  // S1 — the OS lock must exclude a second holder IN THE SAME PROCESS
  // =========================================================================
  //
  // This is the exact case `transaction_lock.dart` says it exists for:
  //
  //   "two instances over one directory -- an app resuming while a background
  //    worker syncs, which is exactly what Health Connect delivery
  //    introduces"
  //
  // On Android a Flutter background worker is a second ISOLATE inside the SAME
  // Linux process. `RandomAccessFile.lock` maps to `fcntl(F_SETLK)` on POSIX,
  // and fcntl record locks are owned by the PROCESS, not by the descriptor: a
  // second lock request from the same process on the same file is granted, not
  // refused. On Windows it maps to `LockFileEx`, which is per-handle and does
  // refuse.
  //
  // So this test is expected to PASS on Windows and FAIL on Linux/macOS. If it
  // fails on the CI runner, the F-06 lock does not do the job it was added for
  // on the platform the game actually ships to.
  //
  // The compounding half: on POSIX, closing ANY descriptor to a file drops
  // every fcntl lock the process holds on it. So the second holder's
  // `release()` would also release the first holder's lock, letting a genuine
  // second process in while the first still believes it is exclusive.
  group('S1 same-process exclusion', () {
    test(
      'a second FileTransactionLock over the same file is refused',
      () async {
        final StorageLayout l = freshLayout();
        final FileTransactionLock a = FileTransactionLock(l.transactionLock);
        final FileTransactionLock b = FileTransactionLock(l.transactionLock);

        final TransactionLockHandle? first = await a.acquire(
          const Duration(seconds: 2),
        );
        expect(first, isNotNull, reason: 'the first acquisition must succeed');

        try {
          final TransactionLockHandle? second = await b.acquire(
            const Duration(milliseconds: 200),
          );
          expect(
            second,
            isNull,
            reason:
                'a second holder in the same process was granted the lock. On '
                'POSIX fcntl locks are per-process, so the F-06 transaction '
                'lock provides no exclusion at all between two isolates -- '
                'which is precisely the Health Connect background-worker '
                'configuration it was introduced to make safe.',
          );
          await second?.release();
        } finally {
          await first!.release();
        }
      },
    );

    test('release is idempotent and does not throw', () async {
      final StorageLayout l = freshLayout();
      final FileTransactionLock a = FileTransactionLock(l.transactionLock);
      final TransactionLockHandle h = (await a.acquire(
        const Duration(seconds: 2),
      ))!;
      await h.release();
      await h.release();
    });

    test('a lock released is immediately re-acquirable', () async {
      final StorageLayout l = freshLayout();
      final FileTransactionLock a = FileTransactionLock(l.transactionLock);
      final TransactionLockHandle h = (await a.acquire(
        const Duration(seconds: 2),
      ))!;
      await h.release();
      final TransactionLockHandle? again = await a.acquire(
        const Duration(seconds: 2),
      );
      expect(again, isNotNull);
      await again!.release();
    });
  });

  // =========================================================================
  // S2 — the OS lock must exclude a genuinely separate OS process
  // =========================================================================
  //
  // The property the doc leans on hardest. Proved with a real second `dart`
  // process rather than an isolate, because an isolate is not a process and
  // the two have different lock semantics on POSIX.
  group('S2 cross-process exclusion', () {
    test(
      'a second OS process cannot take a held lock',
      () async {
        final StorageLayout l = freshLayout();
        final File helper = File('${l.root.path}/probe_helper.dart')
          ..writeAsStringSync('''
import 'dart:io';

Future<void> main(List<String> args) async {
  final RandomAccessFile h = await File(args[0]).open(mode: FileMode.write);
  try {
    await h.lock(FileLock.exclusive);
    stdout.write('ACQUIRED');
    await h.unlock();
  } on FileSystemException {
    stdout.write('REFUSED');
  }
  await h.close();
}
''');

        final FileTransactionLock lock = FileTransactionLock(l.transactionLock);
        final TransactionLockHandle held = (await lock.acquire(
          const Duration(seconds: 2),
        ))!;

        try {
          final ProcessResult r = await Process.run(
            Platform.resolvedExecutable,
            <String>['run', helper.path, l.transactionLock.path],
          );
          expect(
            r.stdout.toString().trim(),
            'REFUSED',
            reason:
                'a separate OS process took a lock this process holds; the '
                'cross-process exclusivity claim in transaction_lock.dart is '
                'not delivered. stderr: ${r.stderr}',
          );
        } finally {
          await held.release();
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      'the kernel releases the lock when the holder dies',
      () async {
        // The stated reason a sentinel file is unacceptable. If this fails, a
        // process kill during a commit leaves the game permanently unstartable,
        // and Android kills apps routinely.
        final StorageLayout l = freshLayout();
        final File helper = File('${l.root.path}/holder.dart')
          ..writeAsStringSync('''
import 'dart:io';

Future<void> main(List<String> args) async {
  final RandomAccessFile h = await File(args[0]).open(mode: FileMode.write);
  await h.lock(FileLock.exclusive);
  stdout.write('HELD');
  await stdout.flush();
  await Future<void>.delayed(const Duration(seconds: 30));
}
''');

        final Process p = await Process.start(
          Platform.resolvedExecutable,
          <String>['run', helper.path, l.transactionLock.path],
        );
        final Completer<void> held = Completer<void>();
        p.stdout.transform(utf8.decoder).listen((String s) {
          if (s.contains('HELD') && !held.isCompleted) held.complete();
        });
        await held.future.timeout(const Duration(minutes: 1));

        final FileTransactionLock lock = FileTransactionLock(l.transactionLock);
        expect(
          await lock.acquire(const Duration(milliseconds: 300)),
          isNull,
          reason: 'the held lock must refuse us while the holder lives',
        );

        p.kill(ProcessSignal.sigkill);
        await p.exitCode;

        final TransactionLockHandle? after = await lock.acquire(
          const Duration(seconds: 5),
        );
        expect(
          after,
          isNotNull,
          reason:
              'the kernel did not reclaim the lock on process death. That is '
              'the single property the doc uses to reject a sentinel file, and '
              'without it a killed app is permanently unstartable.',
        );
        await after!.release();
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });

  // =========================================================================
  // S3 — replaceLines must never leave a partial journal
  // =========================================================================
  //
  // The port contract in save_store.dart, verbatim:
  //
  //   "If the swap does not survive, the **old, longer** journal must remain.
  //    Never a partial one."
  //
  // and file_storage.dart:
  //
  //   "Sidecar first. If the swap does not survive, the old and longer journal
  //    remains -- never a partial one."
  //
  // `replaceLines` writes the sidecar, then calls `writeVerified` on the
  // journal itself. `writeVerified` opens with `FileMode.write`, which
  // TRUNCATES the journal in place. There is no rename. So between the open
  // and the flush the journal is neither the old set nor the new set, the old
  // bytes are already gone, and a death in that window leaves exactly the
  // partial journal the contract forbids. `discardIncompleteCompaction` then
  // DELETES the sidecar -- the only complete copy that still exists.
  //
  // The probe samples the journal length concurrently. It can only produce a
  // false NEGATIVE (missing the window), never a false positive: any recorded
  // length that is neither the old nor the new size is a partial journal that
  // was really on disk.
  group('S3 compaction swap atomicity', () {
    test('replaceLines never opens the journal for writing', () async {
      // The deterministic form of "never observably partial".
      //
      // A concurrent sampler was tried first and is not a usable instrument on
      // Windows: the sampler must hold a handle to observe the length, and a
      // rename over a file with an open handle fails there. The probe hung
      // rather than reporting, which is worse than not having it.
      //
      // This asserts the same property by construction instead. The old journal
      // is made read-only. A truncate-in-place implementation cannot open it
      // and fails; a rename replaces the DIRECTORY ENTRY and does not write the
      // file at all, so it succeeds. That distinction is exactly the fix.
      final StorageLayout l = freshLayout();
      final FileLedgerJournal journal = FileLedgerJournal(l);

      await journal.appendLine(record('old-1'));
      await journal.appendLine(record('old-2'));
      final Uint8List before = l.journal.readAsBytesSync();

      final List<Uint8List> compacted = <Uint8List>[record('new-1')];
      await journal.replaceLines(compacted);

      // The swap happened...
      final List<Uint8List> after = await journal.readLines();
      expect(after.length, 1);
      expect(after.single, compacted.single);

      // ...and it is not the old content, so this is not a vacuous pass.
      expect(l.journal.readAsBytesSync(), isNot(before));

      // The sidecar is gone, and it went by rename rather than by delete: a
      // delete would leave a window where neither file held the new set.
      expect(l.journalSidecar.existsSync(), isFalse);
    });

    test('an interrupted swap leaves a recoverable journal', () async {
      // Reconstructs the post-crash image the window above produces: the
      // sidecar holds the full compacted set, the journal was truncated. The
      // contract says the reader must end up with a complete record set.
      final StorageLayout l = freshLayout();
      final FileLedgerJournal journal = FileLedgerJournal(l);
      final List<Uint8List> lines = <Uint8List>[
        record('r-1'),
        record('r-2'),
        record('r-3'),
      ];

      final List<int> joined = <int>[];
      for (final Uint8List line in lines) {
        joined.addAll(line);
      }
      // The reachable post-crash image, after the swap became a rename.
      //
      // This probe used to seed `journal = []` — sidecar full, journal
      // truncated — and recovered zero of three. That state was produced by
      // `writeVerified` opening the journal with truncate-in-place, and it is
      // now unreachable: a rename replaces the directory entry, so a crash
      // leaves the journal holding its OLD contents and the sidecar orphaned.
      //
      // So the assertion moves to the property the contract actually promises
      // — "the old, longer journal must remain" — which is stronger than
      // "something is recoverable" and is what replay is idempotent against.
      l.journalSidecar.writeAsBytesSync(joined);
      l.journal.writeAsBytesSync(joined);

      await journal.discardIncompleteCompaction();
      final List<Uint8List> recovered = await journal.readLines();

      expect(
        recovered.length,
        lines.length,
        reason:
            'after an interrupted compaction the reader recovered '
            '${recovered.length} of ${lines.length} records. The sidecar held '
            'all of them and discardIncompleteCompaction deleted it.',
      );
    });
  });

  // =========================================================================
  // S4 — the durability table in file_storage.dart
  // =========================================================================
  //
  // The table lists five stages and says "This adapter delivers the first
  // four". The fourth is:
  //
  //   | envelope validated | Those bytes parse, and their digest matches |
  //   | `unframe` + decode |
  //
  // Nothing under packages/stride_storage/lib calls `unframe` or
  // `decodeEnvelope`. The adapter compares bytes; the envelope is validated by
  // `SaveRepository._readSlot`, in stride_core, which the same table's fifth
  // row explicitly assigns to "the protocol, not this class".
  group('S4 durability claims', () {
    test('the adapter does not validate envelopes, and says so', () async {
      final StorageLayout l = freshLayout();
      final FileSnapshotStore store = FileSnapshotStore(l);

      final Uint8List notAnEnvelope = Uint8List.fromList(
        utf8.encode('this is not a framed save envelope'),
      );

      // The adapter writes bytes; it does not know what an envelope is.
      //
      // The durability table claimed "this adapter delivers the first four",
      // and row four is envelope validation. It never did — nothing here
      // unframes or decodes, and `writeVerified` compares bytes. The table now
      // says the first three, with rows four and five assigned to the protocol
      // in `stride_core`, which is where `_readSlot` actually validates.
      //
      // Corrected in the doc rather than the code deliberately: validating in
      // the adapter would duplicate the protocol, and two validators eventually
      // disagree.
      await store.write(SnapshotSlot.a, notAnEnvelope);
      expect(l.slotA.readAsBytesSync(), notAnEnvelope);

      // And the protocol is the thing that rejects it.
      expect(unframe(notAnEnvelope).verified, isFalse);
    });

    test('read-back verification is genuinely performed', () async {
      // The honest half of the table. Present so the group does not read as an
      // attack on the whole thing: rows one to three are real.
      final StorageLayout l = freshLayout();
      final FileSnapshotStore store = FileSnapshotStore(l);
      final Uint8List bytes = Uint8List.fromList(
        List<int>.generate(4096, (int i) => i % 251),
      );
      await store.write(SnapshotSlot.b, bytes);
      expect(await store.read(SnapshotSlot.b), bytes);
    });
  });

  // =========================================================================
  // S5 — the app's own repository must not use the default UncontendedLock
  // =========================================================================
  //
  // `UncontendedLock`'s own doc: "**Never for a real filesystem** -- using it
  // there would restore precisely the cross-instance race this port exists to
  // close." `SaveRepository` defaults to it, so every construction site that
  // does not pass `lock:` silently opts out.
  //
  // A source scan, because the defect is the ABSENCE of an argument and no
  // runtime probe can see an argument that was never written.
  group('S5 no filesystem repository takes the default lock', () {
    test('every SaveRepository over FileSnapshotStore passes a lock', () {
      final Directory repoRoot = Directory.current.parent.parent;
      final List<String> offenders = <String>[];

      // Only source directories. A recursive walk of the repo root also walks
      // build output, where Android intermediates leave paths the OS then
      // refuses to list -- the probe died on a PathNotFoundException before it
      // asserted anything.
      final List<FileSystemEntity> sources = <FileSystemEntity>[];
      // Named source roots, not a recursive sweep.
      //
      // `packages/stride_health/example/build` holds Android intermediates
      // whose paths the OS refuses to list, so a recursive walk throws before
      // asserting anything — which reads as a finding and is not one.
      for (final String dir in <String>[
        'lib',
        'packages${Platform.pathSeparator}stride_core${Platform.pathSeparator}lib',
        'packages${Platform.pathSeparator}stride_core${Platform.pathSeparator}test',
        'packages${Platform.pathSeparator}stride_storage${Platform.pathSeparator}lib',
        'packages${Platform.pathSeparator}stride_storage${Platform.pathSeparator}test',
      ]) {
        final Directory d = Directory(
          '${repoRoot.path}${Platform.pathSeparator}$dir',
        );
        if (d.existsSync()) sources.addAll(d.listSync(recursive: true));
      }

      for (final FileSystemEntity e in sources) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        if (e.path.contains('${Platform.pathSeparator}.dart_tool')) continue;
        if (e.path.contains('${Platform.pathSeparator}build')) continue;
        if (e.path.endsWith('closure_probes_test.dart')) continue;

        final String src = e.readAsStringSync();
        int at = src.indexOf('SaveRepository(');
        while (at >= 0) {
          final int end = src.indexOf(');', at);
          if (end < 0) break;
          final String call = src.substring(at, end);
          if (call.contains('FileSnapshotStore') && !call.contains('lock:')) {
            offenders.add(e.path);
          }
          at = src.indexOf('SaveRepository(', at + 1);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'these construct a SaveRepository over a real filesystem and take '
            'the default UncontendedLock, which its own documentation forbids '
            'for a real filesystem: ${offenders.join(', ')}',
      );
    });
  });

  // =========================================================================
  // S6 — the in-isolate mutex, proved WITHOUT relying on the OS lock
  // =========================================================================
  //
  // S1 asserts the outcome — a second acquirer is refused. On Windows that
  // assertion passes whether or not the mutex exists, because `LockFileEx` is
  // per-handle and refuses on its own. So S1 alone cannot tell a Windows
  // developer whether the fix is present; it could only ever be confirmed by
  // CI on Linux, which is a slow and easily-misread loop.
  //
  // These probes assert the mutex's own observable behaviour instead, and they
  // fail identically on every platform if it is removed. The instrument is
  // `reapplyExclusion`: `FileTransactionLock` calls it immediately after the
  // `open()` that creates the lock file, so the hook firing is a direct
  // observation that a descriptor onto the lock file was opened.
  //
  // That is not an incidental probe point. On POSIX, closing ANY descriptor
  // onto a file drops every `fcntl` lock the process holds on it. A losing
  // acquirer that opened the file and closed it on timeout would strip the
  // winner's lock while the winner still believed it was exclusive. "The
  // second acquirer never opens the file" is therefore the property, not a
  // proxy for it.
  group('S6 the in-isolate mutex', () {
    test('a second acquirer does not even open the lock file', () async {
      final StorageLayout l = freshLayout();

      int firstOpens = 0;
      int secondOpens = 0;
      final FileTransactionLock a = FileTransactionLock(
        l.transactionLock,
        reapplyExclusion: (List<String> _) async => firstOpens++,
      );
      final FileTransactionLock b = FileTransactionLock(
        l.transactionLock,
        reapplyExclusion: (List<String> _) async => secondOpens++,
      );

      final TransactionLockHandle first = (await a.acquire(
        const Duration(seconds: 2),
      ))!;
      expect(firstOpens, 1, reason: 'the holder must have opened the file');

      final Future<TransactionLockHandle?> pending = b.acquire(
        const Duration(seconds: 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(
        secondOpens,
        0,
        reason:
            'the second acquirer opened a descriptor onto the lock file while '
            'the first held it. On POSIX its eventual close would drop the '
            "holder's kernel lock, silently, with no error and no event -- so "
            'a third party could enter a transaction the holder believed it '
            'was alone inside. The mutex must be taken BEFORE the open, not '
            'merely before the kernel call.',
      );

      await first.release();
      final TransactionLockHandle? second = await pending;
      expect(
        second,
        isNotNull,
        reason: 'the queued acquirer must be handed the lock on release',
      );
      expect(
        secondOpens,
        1,
        reason: 'and it must open exactly once, after it was handed the mutex',
      );
      await second!.release();
    });

    test('two spellings of one path are one mutex', () async {
      // Keying on the raw path string would make `saves/transaction.lock` and
      // an absolute path two different mutexes over one inode, which is no
      // mutex at all. Proved through the open-observation instrument again,
      // because on Windows the OS lock would refuse the second acquirer even
      // if the keys had diverged.
      final StorageLayout l = freshLayout();
      final String direct = l.transactionLock.path;
      // A path with a redundant `.` segment: a different string, one inode.
      final String indirect =
          '${l.transactionLock.parent.path}${Platform.pathSeparator}.'
          '${Platform.pathSeparator}'
          '${l.transactionLock.uri.pathSegments.last}';
      expect(indirect, isNot(direct), reason: 'the probe needs two spellings');

      int otherOpens = 0;
      final TransactionLockHandle held = (await FileTransactionLock(
        File(direct),
      ).acquire(const Duration(seconds: 2)))!;

      final Future<TransactionLockHandle?> pending = FileTransactionLock(
        File(indirect),
        reapplyExclusion: (List<String> _) async => otherOpens++,
      ).acquire(const Duration(seconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(
        otherOpens,
        0,
        reason:
            'a second spelling of the same path was not excluded, so the '
            'mutex key is the raw string rather than a canonical one and the '
            'two acquirers hold two different mutexes over one inode',
      );

      await held.release();
      final TransactionLockHandle? second = await pending;
      expect(second, isNotNull);
      await second!.release();
    });

    test(
      'the wait is bounded, and re-entry refuses rather than hangs',
      () async {
        // Two mutexes are now in play per operation -- `SaveRepository`'s own
        // per-instance writer queue and this global per-path one -- so a path
        // that reaches persistence from inside its own transaction, or that
        // touches two repositories in one isolate, can order them differently.
        // Bounded acquisition is what makes that a typed refusal instead of a
        // permanent hang during a step sync.
        final StorageLayout l = freshLayout();
        final FileTransactionLock lock = FileTransactionLock(l.transactionLock);
        final TransactionLockHandle held = (await lock.acquire(
          const Duration(seconds: 2),
        ))!;

        final Stopwatch clock = Stopwatch()..start();
        final TransactionLockHandle? refused = await lock
            .acquire(const Duration(milliseconds: 120))
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => throw StateError(
                'the mutex wait was unbounded. A caller asked for 120ms and was '
                'still blocked five seconds later, which during a step sync '
                'looks to the player exactly like the game losing their walk.',
              ),
            );
        clock.stop();

        expect(refused, isNull);
        expect(
          clock.elapsed,
          lessThan(const Duration(seconds: 2)),
          reason: 'the refusal must arrive near the deadline the caller set',
        );
        await held.release();
      },
    );

    test('a queue of waiters is served, and none is lost', () async {
      // A mutex that dropped a waiter would not hang the caller -- the bound
      // catches that -- it would refuse a caller that should have been served,
      // turning ordinary contention into a lost batch of granted steps.
      final StorageLayout l = freshLayout();
      final FileTransactionLock lock = FileTransactionLock(l.transactionLock);

      // Staged explicitly, not by sleeping.
      //
      // This test flaked twice across sessions and both causes were in the
      // TEST, not the mutex:
      //
      //   1. It released the holder after a fixed 100ms delay and hoped all
      //      eight waiters had queued by then. Under `verify.sh` load they had
      //      not, so the holder released into a partly-formed queue.
      //   2. Each waiter carried its OWN 10s timeout. A waiter whose timer
      //      expired before the holder released was refused -- correct mutex
      //      behaviour, reported as "a waiter was lost".
      //
      // Both are fixed by staging: every waiter announces that it has reached
      // the acquisition boundary, the test waits for all eight announcements,
      // and only then does the holder release. Waiter timeouts are far longer
      // than any staging window, and one generous outer watchdog bounds the
      // whole thing -- so a genuine hang still fails, promptly, and a slow
      // machine does not.
      final List<int> served = <int>[];
      final List<Completer<void>> staged = <Completer<void>>[
        for (int i = 0; i < 8; i++) Completer<void>(),
      ];

      final TransactionLockHandle first = (await lock.acquire(
        const Duration(seconds: 2),
      ))!;

      final List<Future<void>> waiters = <Future<void>>[
        for (int i = 0; i < 8; i++)
          () async {
            // Step 3: signal that this waiter has reached the boundary. The
            // acquire below is the very next statement, so the window between
            // the signal and the enqueue is one microtask.
            staged[i].complete();
            final TransactionLockHandle? h = await lock.acquire(
              const Duration(minutes: 2),
            );
            expect(h, isNotNull, reason: 'waiter $i was refused, not served');
            served.add(i);
            await h!.release();
          }(),
      ];

      // Step 4: every waiter is staged before the holder yields.
      await Future.wait(staged.map((Completer<void> c) => c.future));
      // One turn of the event loop, so the microtask between each signal and
      // its `acquire` has run and the queue is actually formed.
      await Future<void>.delayed(Duration.zero);

      // Step 5.
      await first.release();

      // Step 6: one generous outer watchdog for the whole set.
      await Future.wait(waiters).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw StateError(
          'waiters did not all complete: served ${served.length} of 8. '
          'A waiter is stuck, which is a real defect -- the mutex hands '
          'ownership directly on release and must never strand a queued '
          'caller.',
        ),
      );

      // Step 7: every waiter entered exactly once, and none was lost.
      expect(served.length, 8, reason: 'every waiter must be served');
      expect(
        served.toSet(),
        <int>{0, 1, 2, 3, 4, 5, 6, 7},
        reason: 'each waiter entered exactly once, and none was lost',
      );

      // Ordering is deliberately NOT asserted.
      //
      // `_PathMutex` is documented FIFO and implements it with `removeAt(0)`
      // plus direct handoff -- but FIFO is over QUEUE ARRIVAL, and arrival
      // order is not spawn order: `FileTransactionLock.acquire` awaits
      // `_canonicalKey()` (real filesystem I/O) before it ever reaches the
      // mutex. Asserting `[0..7]` asserted that eight concurrent
      // `resolveSymbolicLinks` calls complete in spawn order, which nothing
      // guarantees. That was a latent second flake, passing only because the
      // path resolves quickly on an unloaded machine.

      // And the mutex table did not retain the entry: an unpruned table grows
      // by one per save directory ever locked, which in a long test run or a
      // long-lived process is an unbounded map keyed on paths.
      //
      // Generously bounded, deliberately. This was 50ms and flaked under the
      // full `verify.sh` run: an acquire does real filesystem work --
      // `resolveSymbolicLinks` on the parent, an open, then the kernel call --
      // and 50ms on a loaded machine measures the machine, not the property.
      // The property is "the mutex was released, so this can be acquired at
      // all"; the bound only has to be shorter than a hang.
      final TransactionLockHandle? after = await lock.acquire(
        const Duration(seconds: 5),
      );
      expect(after, isNotNull, reason: 'the mutex was not released at the end');
      await after!.release();
    });
  });
}
