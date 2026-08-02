// Adversarial probes against the F-06 dart:io adapters and the pure bootstrap.
//
// Every test here is an attack, not a demonstration of intended behaviour. A
// test that PASSES here means the attack was repelled. Where an attack
// SUCCEEDED, the expectation asserts the defect and is marked `// DEFECT:` so
// it is impossible to mistake a green suite for a clean system.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:stride_storage/stride_storage.dart';
import 'package:test/test.dart';

// --- harness ---------------------------------------------------------------

Directory freshRoot() {
  final Directory d = Directory.systemTemp.createTempSync('stride_probe_');
  addTearDown(() {
    try {
      if (d.existsSync()) d.deleteSync(recursive: true);
    } on Object {
      // Windows sometimes holds a handle briefly. Not the subject under test.
    }
  });
  return d;
}

StorageLayout freshLayout() {
  final StorageLayout l = StorageLayout(
    Directory('${freshRoot().path}/${StorageLayout.directoryName}'),
  );
  l.root.createSync(recursive: true);
  return l;
}

ContentSource get productionSource {
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

ContentRegistry get registry => const ContentLoader()
    .load(productionSource, profileId: BalanceProfile.productionId)
    .registry!;

SaveRepository repoOver(StorageLayout l) => SaveRepository(
  snapshots: FileSnapshotStore(l),
  journal: FileLedgerJournal(l),
  // A real directory gets the real lock. `UncontendedLock` here would leave
  // A3 attacking a system that was never defended.
  lock: FileTransactionLock(l.transactionLock),
);

Uint8List line(String s) => Uint8List.fromList(utf8.encode('$s\n'));

const String probeSaveId = 'probe-save-0001';

Uint8List saltOf(int seed) =>
    Uint8List.fromList(List<int>.generate(16, (int i) => (i + seed) & 0xFF));

/// Writes one real, valid save so the probes attack a populated directory.
Future<GameEngine> seedSave(StorageLayout l) async {
  final GameEngine engine = GameEngine.newGame(registry: registry);
  final CommitOutcome outcome = await repoOver(l).commit(
    after: engine.state,
    events: const <GameEvent>[],
    saveId: probeSaveId,
    expectation: const CommitExpectation(
      expectedSnapshotGeneration: -1,
      expectedLastAppliedTransaction: 0,
    ),
    originSaltFingerprint: null,
  );
  expect(outcome, isA<CommitDurable>(), reason: 'seed must commit');
  return engine;
}

Future<void> writeIdentity(StorageLayout l, String saveId, int seed) =>
    FileIdentityStore(
      l,
    ).writeStored(StoredIdentity(saveId: saveId, salt: saltOf(seed)));

Future<BootstrapOutcome> boot(StorageLayout l) {
  final BootstrapCoordinator c = BootstrapCoordinator(
    repository: repoOver(l),
    identityStore: FileIdentityStore(l),
    profileId: BalanceProfile.productionId,
  );
  return c.run(
    loadContent: () async => productionSource,
    mintIdentity: () => const ReconciliationIdentity(
      saveId: 'freshly-minted',
      saltFingerprint: 'fresh-fingerprint',
    ),
  );
}

void say(Object? m) => stdout.writeln('  >> $m');

void main() {
  // =========================================================================
  // ATTACK 1 — does the adapter honour the port contract?
  // =========================================================================
  group('A1 port contract', () {
    test('write(a) does not create, read, or modify slot b', () async {
      final StorageLayout l = freshLayout();
      final FileSnapshotStore store = FileSnapshotStore(l);

      await store.write(SnapshotSlot.b, Uint8List.fromList(<int>[9, 9, 9, 9]));
      final int bModified = l.slotB.statSync().modified.microsecondsSinceEpoch;

      await store.write(
        SnapshotSlot.a,
        Uint8List.fromList(List<int>.filled(4096, 7)),
      );

      expect(await store.read(SnapshotSlot.b), <int>[9, 9, 9, 9]);
      expect(l.slotB.statSync().modified.microsecondsSinceEpoch, bModified);
      expect((await store.read(SnapshotSlot.a))!.length, 4096);
    });

    test('erase(a) does not touch b', () async {
      final StorageLayout l = freshLayout();
      final FileSnapshotStore store = FileSnapshotStore(l);
      await store.write(SnapshotSlot.a, Uint8List.fromList(<int>[1]));
      await store.write(SnapshotSlot.b, Uint8List.fromList(<int>[2]));
      await store.erase(SnapshotSlot.a);
      expect(l.slotA.existsSync(), isFalse);
      expect(await store.read(SnapshotSlot.b), <int>[2]);
    });

    test('appendLine never rewrites a byte that was already there', () async {
      final StorageLayout l = freshLayout();
      final FileLedgerJournal j = FileLedgerJournal(l);

      final List<int> expected = <int>[];
      for (int i = 0; i < 40; i++) {
        final Uint8List rec = line('record-$i-${'x' * i}');
        final List<int> before = l.journal.existsSync()
            ? l.journal.readAsBytesSync()
            : <int>[];
        await j.appendLine(rec);
        final List<int> after = l.journal.readAsBytesSync();

        expect(
          after.sublist(0, before.length),
          before,
          reason: 'append $i rewrote existing bytes',
        );
        expect(
          after.length,
          before.length + rec.length,
          reason: 'append $i did not land exactly its own bytes',
        );
        expected.addAll(rec);
      }
      expect(l.journal.readAsBytesSync(), expected);
    });

    test('readLines returns a trailing fragment as its own line', () async {
      final StorageLayout l = freshLayout();
      final FileLedgerJournal j = FileLedgerJournal(l);
      await j.appendLine(line('whole'));
      l.journal.writeAsBytesSync(utf8.encode('tor'), mode: FileMode.append);

      final List<Uint8List> lines = await j.readLines();
      expect(lines.length, 2);
      expect(utf8.decode(lines[0]), 'whole\n');
      expect(utf8.decode(lines[1]), 'tor');
    });

    test('readLines preserves empty records and CR bytes verbatim', () async {
      final StorageLayout l = freshLayout();
      l.journal.writeAsBytesSync(utf8.encode('a\r\n\nb\n'));
      final List<Uint8List> lines = await FileLedgerJournal(l).readLines();
      expect(lines.map(utf8.decode).toList(), <String>['a\r\n', '\n', 'b\n']);
    });
  });

  // =========================================================================
  // ATTACK 2 — the read-back verification
  // =========================================================================
  group('A2 read-back', () {
    test('the snapshot read-back comparison is real', () async {
      final StorageLayout l = freshLayout();
      final FileSnapshotStore store = FileSnapshotStore(l);
      await store.write(SnapshotSlot.a, Uint8List.fromList(<int>[1, 2, 3]));
      // Post-write corruption is by definition outside write()'s reach; the
      // read path must surface it as bytes, per the port contract.
      l.slotA.writeAsBytesSync(<int>[1, 2]);
      expect(await store.read(SnapshotSlot.a), <int>[1, 2]);
    });

    test(
      'DEFECT: appendLine read-back is an absolute length floor, not a check '
      'that the appended bytes landed',
      () async {
        final StorageLayout l = freshLayout();
        final FileLedgerJournal j = FileLedgerJournal(l);

        await j.appendLine(line('x' * 4000));
        final int lengthBefore = l.journal.lengthSync();

        // The shipped predicate is: `await file.length() < line.length`.
        // Evaluate it for "the append landed nothing at all".
        final Uint8List record = line('t' * 18);
        final bool shippedCheckRejects = lengthBefore < record.length;
        say(
          'journal was $lengthBefore bytes; record is ${record.length} bytes',
        );
        say(
          'shipped check would reject a total loss of the append? '
          '$shippedCheckRejects',
        );

        expect(
          shippedCheckRejects,
          isFalse,
          reason:
              'the shipped check accepts a journal that did not grow at all, '
              'because it compares TOTAL file length against RECORD length',
        );

        // The postcondition the adapter should assert, and does not:
        await j.appendLine(record);
        expect(l.journal.lengthSync(), lengthBefore + record.length);
      },
    );
  });

  // =========================================================================
  // ATTACK 3 — two repositories, one directory (the background-worker case)
  // =========================================================================
  group('A3 cross-instance concurrency', () {
    // Was skipped as a KNOWN DEFECT. It is not skipped any more.
    //
    // The defect was real: two SaveRepository instances over one directory each
    // held their own single-writer queue, `_readHead` awaited real file I/O and
    // therefore yielded, so both could read the same durable head, both find
    // their compare-and-swap expectation satisfied, both compute the same next
    // transaction id, and both append. Either outcome lost -- matching record
    // shapes were absorbed as a duplicate and that batch of granted steps was
    // silently gone, or differing shapes gave `journalForked`, which compaction
    // cannot clear because compaction only runs inside a commit and a commit
    // needs a load. That one was a permanent brick.
    //
    // It is closed by a real OS-level exclusive lock held across the WHOLE
    // transaction, wired here through `repoOver`. This test now asserts the
    // repaired behaviour rather than demonstrating the defect: one writer
    // lands, the other is refused in a typed way, and the next launch opens.
    //
    // The lock's own proof -- fifty repetitions, cross-process exclusion, a
    // killed holder, a bounded timeout, and the width of the hold -- lives in
    // concurrency_test.dart. This probe stays because it is the shape the
    // Android background worker actually has.
    test('two SaveRepository instances committing concurrently', () async {
      final StorageLayout l = freshLayout();
      await seedSave(l);

      final SaveRepository repoA = repoOver(l);
      final SaveRepository repoB = repoOver(l);

      final SaveLoaded la = await repoA.load(registry: registry) as SaveLoaded;
      final SaveLoaded lb = await repoB.load(registry: registry) as SaveLoaded;

      final GameEngine ea = GameEngine(registry: registry, state: la.state);
      final GameEngine eb = GameEngine(registry: registry, state: lb.state);

      final EngineResult ra = ea.execute(
        const GrantSyntheticSteps(steps: 5000, reason: 'probe-foreground'),
      );
      final EngineResult rb = eb.execute(
        const GrantSyntheticSteps(steps: 11, reason: 'probe-worker'),
      );
      expect(ra.events, isNotEmpty);
      expect(rb.events, isNotEmpty);
      say('foreground grants 5000, background worker grants 11');

      final List<CommitOutcome> outcomes =
          await Future.wait(<Future<CommitOutcome>>[
            repoA.commit(
              after: ea.state,
              events: ra.events,
              saveId: probeSaveId,
              expectation: CommitExpectation(
                expectedSnapshotGeneration: la.generation,
                expectedLastAppliedTransaction: la.lastAppliedTransaction,
              ),
              originSaltFingerprint: null,
            ),
            repoB.commit(
              after: eb.state,
              events: rb.events,
              saveId: probeSaveId,
              expectation: CommitExpectation(
                expectedSnapshotGeneration: lb.generation,
                expectedLastAppliedTransaction: lb.lastAppliedTransaction,
              ),
              originSaltFingerprint: null,
            ),
          ]);

      say('outcomes: ${outcomes.map((CommitOutcome o) => o.runtimeType)}');
      final List<int> txIds = <int>[];
      for (final Uint8List raw in await FileLedgerJournal(l).readLines()) {
        final JournalLineResult p = decodeJournalLine(raw);
        txIds.add(p.ok ? p.record!.transactionId : -1);
      }
      say('journal transaction ids on disk: $txIds');
      say(
        'durable commits: ${outcomes.whereType<CommitDurable>().length} of 2',
      );

      final LoadOutcome reread = await repoOver(l).load(registry: registry);
      say('next launch: ${reread.runtimeType}');
      if (reread is LoadRefused) say('refusal: ${reread.reason}');
      if (reread is SaveLoaded) {
        say('banked steps recovered: ${reread.state.steps.banked}');
        say('repairs: ${reread.repairs.map((SaveRepair r) => r.diagnosis)}');
      }

      // No fork. Two records at one transaction id is the whole attack.
      expect(txIds, isNot(contains(-1)));
      expect(
        txIds.toSet().length,
        txIds.length,
        reason:
            'two records claim the same transaction id, so compare-and-swap '
            'does not span SaveRepository instances: $txIds',
      );

      // Exactly one writer lands. Both landing at one id is a fork; neither
      // landing means the lock starves a caller that had steps to save.
      final List<CommitDurable> durable = outcomes
          .whereType<CommitDurable>()
          .toList();
      expect(durable, hasLength(1));
      final CommitRefused refused = outcomes.whereType<CommitRefused>().single;
      expect(
        refused.reason,
        anyOf(
          CommitRefusal.conflictRetryLimitExhausted,
          CommitRefusal.storageBusy,
        ),
        reason:
            'the loser must be told to reload and reconcile, not left to '
            'assume its batch is durable',
      );

      // The next launch opens, and holds exactly the winner's grant.
      expect(
        reread,
        isA<SaveLoaded>(),
        reason:
            'a journalForked refusal here is permanent: compaction only runs '
            'inside a commit and a commit needs a load',
      );
      final int expected = outcomes[0] is CommitDurable ? 5000 : 11;
      expect(
        (reread as SaveLoaded).state.steps.banked,
        expected,
        reason:
            '5011 would mean both landed; the other value would mean the '
            'commit that reported success was silently discarded',
      );
      expect(
        reread.repairs.map((SaveRepair r) => r.diagnosis),
        isNot(contains(SaveDiagnosis.journalDuplicateTransaction)),
        reason:
            'an absorbed duplicate is a batch of granted steps disappearing '
            'without any refusal reaching the caller',
      );
    });

    test('the same two commits, serialized, both land', () async {
      final StorageLayout l = freshLayout();
      await seedSave(l);
      final SaveRepository repo = repoOver(l);
      final SaveLoaded first =
          await repo.load(registry: registry) as SaveLoaded;
      final GameEngine e = GameEngine(registry: registry, state: first.state);

      final EngineResult r1 = e.execute(
        const GrantSyntheticSteps(steps: 5000, reason: 'probe-1'),
      );
      final CommitDurable d1 =
          await repo.commit(
                after: e.state,
                events: r1.events,
                saveId: probeSaveId,
                expectation: CommitExpectation(
                  expectedSnapshotGeneration: first.generation,
                  expectedLastAppliedTransaction: first.lastAppliedTransaction,
                ),
                originSaltFingerprint: null,
              )
              as CommitDurable;

      final EngineResult r2 = e.execute(
        const GrantSyntheticSteps(steps: 11, reason: 'probe-2'),
      );
      expect(
        await repo.commit(
          after: e.state,
          events: r2.events,
          saveId: probeSaveId,
          expectation: CommitExpectation(
            expectedSnapshotGeneration: d1.generation,
            expectedLastAppliedTransaction: d1.transactionId,
          ),
          originSaltFingerprint: null,
        ),
        isA<CommitDurable>(),
      );

      final SaveLoaded after =
          await repoOver(l).load(registry: registry) as SaveLoaded;
      expect(after.state.steps.banked, 5011);
    });
  });

  // =========================================================================
  // ATTACK 4 — real filesystem faults
  // =========================================================================
  group('A4 filesystem faults', () {
    test('journal path is a directory', () async {
      final StorageLayout l = freshLayout();
      Directory(l.journal.path).createSync();
      final FileLedgerJournal j = FileLedgerJournal(l);

      Object? thrown;
      try {
        await j.appendLine(line('hello'));
      } on Object catch (e) {
        thrown = e;
      }
      say('append onto a directory threw: ${thrown.runtimeType}');
      expect(thrown, isA<StorageException>());

      say(
        'readLines over a directory returned '
        '${(await j.readLines()).length} lines (File.existsSync is false '
        'for a directory, so this reads as "no journal")',
      );
    });

    test('slot path is a directory', () async {
      final StorageLayout l = freshLayout();
      Directory(l.slotA.path).createSync();
      final Uint8List? read = await FileSnapshotStore(l).read(SnapshotSlot.a);
      say(
        'read of a directory-shaped slot: $read '
        '(indistinguishable from "never written")',
      );
      expect(read, isNull);
    });

    test('DEFECT: ensureExists throws an untyped FileSystemException when the '
        'storage root path is occupied by a file', () async {
      final Directory parent = freshRoot();
      File('${parent.path}/${StorageLayout.directoryName}')
        ..createSync()
        ..writeAsStringSync('not a directory');
      final StorageLayout l = StorageLayout(
        Directory('${parent.path}/${StorageLayout.directoryName}'),
      );

      Object? thrown;
      try {
        await l.ensureExists();
      } on Object catch (e) {
        thrown = e;
      }
      say('ensureExists over an occupied root threw: ${thrown.runtimeType}');
      expect(thrown, isA<FileSystemException>());
      expect(
        thrown,
        isNot(isA<StorageException>()),
        reason:
            'runtime_bootstrap.dart calls layout.ensureExists() outside any '
            'try/catch, so this reaches the player as a crash',
      );
    });

    test('both slots truncated is refused, never silently reset', () async {
      final StorageLayout l = freshLayout();
      await seedSave(l);
      final SaveRepository repo = repoOver(l);
      final SaveLoaded loaded =
          await repo.load(registry: registry) as SaveLoaded;
      final GameEngine e = GameEngine(registry: registry, state: loaded.state);
      final EngineResult r = e.execute(
        const GrantSyntheticSteps(steps: 300, reason: 'probe'),
      );
      await repo.commit(
        after: e.state,
        events: r.events,
        saveId: probeSaveId,
        expectation: CommitExpectation(
          expectedSnapshotGeneration: loaded.generation,
          expectedLastAppliedTransaction: loaded.lastAppliedTransaction,
        ),
        originSaltFingerprint: null,
      );

      for (final File f in <File>[l.slotA, l.slotB]) {
        if (!f.existsSync()) continue;
        final Uint8List b = f.readAsBytesSync();
        f.writeAsBytesSync(b.sublist(0, b.length ~/ 2));
      }

      final LoadOutcome outcome = await repoOver(l).load(registry: registry);
      say('both slots halved -> ${outcome.runtimeType}');
      expect(outcome, isNot(isA<NoSaveFound>()));
      expect(outcome, isA<LoadRefused>());
    });
  });

  // =========================================================================
  // ATTACK 5 — make the bootstrap silently start a new game
  // =========================================================================
  group('A5 never silently new-game', () {
    test(
      'a zero-length slot PAIR is refused, never treated as a new game',
      () async {
        final StorageLayout l = freshLayout();
        await seedSave(l);
        await writeIdentity(l, probeSaveId, 0);

        // Both slot files exist and are zero bytes: exactly what FileMode.write
        // leaves behind when a process dies after truncation. Journal emptied,
        // as compaction leaves it after a healthy commit pair.
        l.slotA.writeAsBytesSync(<int>[]);
        l.slotB.writeAsBytesSync(<int>[]);
        if (l.journal.existsSync()) l.journal.writeAsBytesSync(<int>[]);

        final LoadOutcome outcome = await repoOver(l).load(registry: registry);
        say('zero-length slot pair -> ${outcome.runtimeType}');

        final BootstrapOutcome b = await boot(l);
        say('bootstrap over zero-length slot pair -> ${b.runtimeType}');

        // Fixed in F-06. A present-but-empty slot is now diagnosed
        // `slotTruncated` rather than `slotAbsent`, so the pair can no longer
        // reach the new-game path.
        //
        // This probe was written to demonstrate the defect and asserted
        // `NoSaveFound` + `BootstrapNewGame`. It is kept, inverted, because
        // the case it constructs -- both slots zeroed by a death between
        // truncate and write -- is the one failure a player cannot recover
        // from and cannot even diagnose.
        expect(
          outcome,
          isA<LoadRefused>(),
          reason:
              'a file that exists and is empty is an unreadable save, not an '
              'absent one',
        );
        expect(
          b,
          isA<BootstrapBlocked>(),
          reason:
              'startup must never mint a fresh character over a save '
              'directory that plainly had files in it',
        );
        expect(
          (b as BootstrapBlocked).reason,
          BootstrapBlockReason.bothSlotsInvalid,
        );
      },
    );

    test('a journal with no snapshot at all is blocked', () async {
      final StorageLayout l = freshLayout();
      await seedSave(l);
      await writeIdentity(l, probeSaveId, 0);
      if (!l.journal.existsSync() || l.journal.lengthSync() == 0) {
        await FileLedgerJournal(l).appendLine(line('{"not":"a record"}'));
      }
      l.slotA.deleteSync();
      if (l.slotB.existsSync()) l.slotB.deleteSync();

      final LoadOutcome outcome = await repoOver(l).load(registry: registry);
      say('journal-without-snapshot -> ${outcome.runtimeType}');
      expect(outcome, isNot(isA<NoSaveFound>()));
    });

    test('deleting only the identity blocks, it does not restart', () async {
      final StorageLayout l = freshLayout();
      await seedSave(l);
      await writeIdentity(l, probeSaveId, 0);
      l.identity.deleteSync();

      final BootstrapOutcome b = await boot(l);
      say(
        'identity deleted -> ${b.runtimeType}'
        '${b is BootstrapBlocked ? ' / ${b.reason}' : ''}',
      );
      expect(b, isNot(isA<BootstrapNewGame>()));
    });

    test('corrupting only the identity blocks, it does not restart', () async {
      final StorageLayout l = freshLayout();
      await seedSave(l);
      await writeIdentity(l, probeSaveId, 0);
      l.identity.writeAsStringSync('{ this is not json');

      final BootstrapOutcome b = await boot(l);
      say('identity corrupted -> ${b.runtimeType}');
      expect(b, isA<BootstrapBlocked>());
      expect(
        (b as BootstrapBlocked).reason,
        BootstrapBlockReason.storageUnavailable,
      );
    });

    test('an identity whose salt field is absent blocks', () async {
      final StorageLayout l = freshLayout();
      await seedSave(l);
      l.identity.writeAsStringSync('{"saveId":"$probeSaveId"}');
      final BootstrapOutcome b = await boot(l);
      say('identity missing salt -> ${b.runtimeType}');
      expect(b, isA<BootstrapBlocked>());
    });
  });

  // =========================================================================
  // ATTACK 6 — identity, salt, lineage
  // =========================================================================
  group('A6 identity and lineage', () {
    test(
      'a bare coordinator can start a genuinely new game on its own',
      () async {
        final StorageLayout l = freshLayout();
        final BootstrapOutcome b = await boot(l);
        say(
          'bare coordinator over FileIdentityStore -> ${b.runtimeType}'
          '${b is BootstrapBlocked ? ' / ${b.reason} / ${b.detail}' : ''}',
        );
        // `FileIdentityStore.write` used to throw unconditionally, so the
        // coordinator could only ever produce a block here and a new game was
        // reachable *only* through the app pre-writing the identity. Any
        // second entry point would have hit the throw.
        //
        // `write` now honours the port contract, so the coordinator stands on
        // its own.
        expect(b, isA<BootstrapNewGame>());
      },
    );

    test('a commit records the salt fingerprint it was given', () async {
      final StorageLayout l = freshLayout();
      await seedSave(l);

      final Uint8List raw = (await FileSnapshotStore(l).read(SnapshotSlot.a))!;
      final SaveEnvelope env = decodeEnvelope(unframe(raw).payload!);
      say(
        'originSaltFingerprint recorded in the snapshot: '
        '${env.originSaltFingerprint}',
      );

      // Fixed in F-06. `encodeSnapshot` took the fingerprint as an OPTIONAL
      // parameter and `commit` had none at all, so every snapshot ever
      // written recorded none and `_checkSalt` could never fire. The F-05
      // salt tests passed throughout because they seeded slot bytes by
      // calling `encodeSnapshot` directly -- they proved the load path and
      // never touched the commit path.
      //
      // The parameter is now required, so omitting it is a compile error.
      // `seedSave` deliberately passes null, which is the honest value for a
      // fixture with no identity; the end-to-end coverage lives in
      // stride_core/test/save_protocol_test.dart.
      expect(env.originSaltFingerprint, isNull);

      final SaveEnvelope withSalt = decodeEnvelope(
        unframe(
          encodeSnapshot(
            state: GameEngine.newGame(registry: registry).state,
            saveId: probeSaveId,
            generation: 0,
            lastAppliedTransaction: 0,
            originSaltFingerprint: 'abcdef0123456789',
          ),
        ).payload!,
      );
      expect(withSalt.originSaltFingerprint, 'abcdef0123456789');

      // Consequence: a completely different salt loads without complaint.
      final LoadOutcome outcome = await repoOver(l).load(
        registry: registry,
        originSaltFingerprint: 'an-entirely-different-salt-fingerprint',
      );
      say('load under a foreign salt fingerprint -> ${outcome.runtimeType}');
      expect(
        outcome,
        isA<SaveLoaded>(),
        reason:
            'DEFECT: _checkSalt is dead code; re-keying every origin and '
            'double-granting the retention window would go undetected',
      );
    });

    test('an identity from another lineage is refused, not resumed', () async {
      final StorageLayout l = freshLayout();
      await seedSave(l); // envelope saveId == probeSaveId

      await writeIdentity(l, 'a-completely-different-lineage', 40);

      final BootstrapOutcome b = await boot(l);
      say('mismatched lineage -> ${b.runtimeType}');

      // Fixed in F-06. `SaveLoaded` now carries the envelope's `saveId` and
      // `_resume` compares it against the stored identity.
      //
      // Before that, this resumed silently and every later commit was
      // written under the mismatched id — which forks the journal lineage on
      // the very next transaction and leaves the launch after that with
      // `lineageMismatch` and no way out. This probe used to demonstrate
      // that sequence; it now asserts the refusal that prevents it.
      expect(b, isA<BootstrapBlocked>());
      expect(
        (b as BootstrapBlocked).reason,
        BootstrapBlockReason.originIdentityMismatch,
      );

      // A refusal must leave the directory exactly as it found it.
      final SaveLoaded still =
          await repoOver(l).load(registry: registry) as SaveLoaded;
      expect(still.saveId, probeSaveId);
    });
  });

  // =========================================================================
  // ATTACK 7 — claims the durability table and the library docs make
  // =========================================================================
  group('A7 documentation claims', () {
    test('the advertised conformance entry point exists', () {
      final bool exists =
          File('lib/conformance.dart').existsSync() ||
          File('packages/stride_storage/lib/conformance.dart').existsSync();
      say('lib/conformance.dart exists: $exists');
      // The library doc advertised package:stride_storage/conformance.dart as
      // "the reusable conformance suite every implementation of those ports
      // must pass" while the file did not exist and the package had no tests
      // at all. A doc comment describing a test suite that is not there is how
      // a reviewer concludes an untested boundary is covered.
      expect(
        exists,
        isTrue,
        reason:
            'stride_storage.dart advertises this entry point; it must exist',
      );
    });

    test('replaceLines read-back verifies both sidecar and journal', () async {
      final StorageLayout l = freshLayout();
      final FileLedgerJournal j = FileLedgerJournal(l);
      await j.appendLine(line('one'));
      await j.appendLine(line('two'));
      await j.replaceLines(<Uint8List>[line('two')]);
      expect(utf8.decode(l.journal.readAsBytesSync()), 'two\n');
      expect(l.journalSidecar.existsSync(), isFalse);
    });

    test(
      'discardIncompleteCompaction removes the sidecar and reports it',
      () async {
        final StorageLayout l = freshLayout();
        final FileLedgerJournal j = FileLedgerJournal(l);
        l.journalSidecar.writeAsBytesSync(utf8.encode('leftover\n'));
        expect(await j.discardIncompleteCompaction(), isTrue);
        expect(l.journalSidecar.existsSync(), isFalse);
        expect(await j.discardIncompleteCompaction(), isFalse);
      },
    );

    test('allFiles covers every path the layout can actually create', () async {
      final StorageLayout l = freshLayout();
      await FileSnapshotStore(
        l,
      ).write(SnapshotSlot.a, Uint8List.fromList(<int>[1]));
      await FileSnapshotStore(
        l,
      ).write(SnapshotSlot.b, Uint8List.fromList(<int>[1]));
      await FileLedgerJournal(l).appendLine(line('r'));
      l.journalSidecar.writeAsBytesSync(<int>[1]);
      await FileIdentityStore(
        l,
      ).writeStored(StoredIdentity(saveId: 'i', salt: saltOf(1)));

      final Set<String> onDisk = l.root
          .listSync()
          .whereType<File>()
          .map((File f) => f.uri.pathSegments.last)
          .toSet();
      final Set<String> declared = l.allFiles
          .map((File f) => f.uri.pathSegments.last)
          .toSet();
      say('on disk: $onDisk');
      say('declared by allFiles: $declared');
      expect(onDisk.difference(declared), isEmpty);
    });
  });
}
