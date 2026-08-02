// The conformance suite against a real directory on a real filesystem.
//
// Plus the tests that only mean anything here: proof that the files exist on
// disk, proof that the ports read from disk rather than from a cache, and proof
// that `writeVerified` really does read back what it wrote.
//
// A conformance suite that passed against a fixture which never touched a disk
// would prove nothing about disks, so the disk-specific proofs below are not
// optional extras — they are what licenses the shared suite's result.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:stride_storage/conformance.dart';
import 'package:stride_storage/stride_storage.dart';
import 'package:test/test.dart';

// --- content --------------------------------------------------------------

/// The production content directory, resolved relative to this package.
Directory get _contentDirectory {
  for (final String candidate in <String>[
    '../../assets/content/v1',
    'assets/content/v1',
  ]) {
    final Directory directory = Directory(candidate);
    if (directory.existsSync()) return directory;
  }
  throw StateError(
    'Could not locate assets/content/v1 from ${Directory.current.path}. '
    'Run tests from packages/stride_storage or the repository root.',
  );
}

ContentRegistry loadRegistry() {
  final Map<String, String> files = <String, String>{};
  for (final FileSystemEntity entity in _contentDirectory.listSync()) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    files[entity.uri.pathSegments.last] = entity.readAsStringSync();
  }
  if (files.isEmpty) {
    throw StateError('No JSON content found in ${_contentDirectory.path}');
  }
  return const ContentLoader()
      .load(ContentSource(files), profileId: BalanceProfile.productionId)
      .requireRegistry;
}

// --- the fixture ----------------------------------------------------------

/// One temporary directory, created fresh and deleted afterwards.
///
/// `createTempSync` gives a unique directory per call, so two tests physically
/// cannot share bytes. A shared root would let an ordering dependency hide
/// inside a green suite.
({PersistenceFixture fixture, Directory root}) openTempFixture() {
  final Directory root = Directory.systemTemp.createTempSync(
    'stride_conformance_',
  );
  final StorageLayout layout = StorageLayout(root);

  return (
    root: root,
    fixture: PersistenceFixture(
      snapshots: FileSnapshotStore(layout),
      journal: FileLedgerJournal(layout),
      identity: FileIdentityStore(layout),
      readArtifacts: () async {
        // Read off the disk, not through the ports. Reading back through
        // SnapshotSlotStore would prove only that the adapter returns what it
        // was handed; this proves what is actually sitting on the device.
        final Map<String, Uint8List> found = <String, Uint8List>{};
        void take(String role, File file) {
          if (file.existsSync()) found[role] = file.readAsBytesSync();
        }

        take(ArtifactRole.slotA, layout.slotA);
        take(ArtifactRole.slotB, layout.slotB);
        take(ArtifactRole.journal, layout.journal);
        take(ArtifactRole.sidecar, layout.journalSidecar);
        take(ArtifactRole.identity, layout.identity);
        return found;
      },
      // The app's own write path, salt included. The port's `write` carries
      // only a fingerprint, which cannot produce a salt, so the realistic
      // starting state has to be established through the adapter's own API.
      seedIdentity: (String saveId, Uint8List salt) => FileIdentityStore(
        layout,
      ).writeStored(StoredIdentity(saveId: saveId, salt: salt)),
      teardown: () {
        if (root.existsSync()) root.deleteSync(recursive: true);
      },
    ),
  );
}

// --- a File whose read-back lies -------------------------------------------

/// Delegates everything to a real file except [readAsBytes] and [length].
///
/// The only way to demonstrate that the read-back verification happens: a real
/// filesystem cannot be made to accept a write and then return different bytes,
/// so the lie has to come from the [File] itself.
///
/// `noSuchMethod` covers the rest of the `File` surface. Anything
/// `writeVerified` touches beyond the three members below would throw rather
/// than silently no-op, which is the behaviour a test harness should have.
class LyingFile implements File {
  LyingFile(this.inner, this.lie);

  final File inner;
  final Uint8List Function(Uint8List truth) lie;

  @override
  String get path => inner.path;

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) =>
      inner.open(mode: mode);

  @override
  Future<Uint8List> readAsBytes() async => lie(await inner.readAsBytes());

  @override
  Future<int> length() async => lie(await inner.readAsBytes()).length;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// --- tests ----------------------------------------------------------------

void main() {
  final ContentRegistry registry = loadRegistry();

  // The shared suite, defined once in lib/src/conformance.dart and executed
  // here against real files.
  runPersistenceConformance(
    name: 'filesystem',
    registry: registry,
    open: () => openTempFixture().fixture,
  );

  group('the filesystem fixture really is a filesystem', () {
    late Directory root;
    late PersistenceFixture fixture;

    setUp(() {
      final ({PersistenceFixture fixture, Directory root}) opened =
          openTempFixture();
      root = opened.root;
      fixture = opened.fixture;
    });

    tearDown(() async {
      await fixture.teardown();
    });

    test('the root is a real temporary directory, unique per test', () {
      expect(root.existsSync(), isTrue);
      expect(
        root.path.startsWith(Directory.systemTemp.path),
        isTrue,
        reason: 'the fixture must not write outside the system temp directory',
      );
      final Directory second = Directory.systemTemp.createTempSync(
        'stride_conformance_',
      );
      addTearDown(() => second.deleteSync(recursive: true));
      expect(second.path, isNot(root.path));
    });

    test('a commit leaves real files at the expected paths', () async {
      final SaveRepository repo = SaveRepository(
        snapshots: fixture.snapshots,
        journal: fixture.journal,
      );
      final GameEngine engine = GameEngine.newGame(registry: registry);
      final EngineResult result = engine.execute(
        const GrantSyntheticSteps(steps: 613, reason: 'on disk'),
      );

      final CommitOutcome outcome = await repo.commit(
        after: engine.state,
        events: result.events,
        saveId: conformanceSaveId,
        expectation: const CommitExpectation(
          expectedSnapshotGeneration: -1,
          expectedLastAppliedTransaction: 0,
        ),
        originSaltFingerprint: null,
      );
      expect(outcome, isA<CommitDurable>());

      final File slotA = File('${root.path}/save_slot_a');
      final File slotB = File('${root.path}/save_slot_b');
      final File journal = File('${root.path}/ledger_journal');

      expect(
        slotA.existsSync(),
        isTrue,
        reason: 'a suite that passes without a file on disk proves nothing',
      );
      expect(slotA.lengthSync(), greaterThan(0));
      expect(journal.existsSync(), isTrue);
      expect(journal.lengthSync(), greaterThan(0));
      expect(
        slotB.existsSync(),
        isFalse,
        reason: 'the first commit must not touch the other slot',
      );

      // The bytes on disk must decode to the envelope the protocol claims it
      // wrote — not merely be non-empty.
      final Uint8List bytes = slotA.readAsBytesSync();
      final FrameResult framed = unframe(bytes);
      expect(framed.verified, isTrue, reason: '${framed.fault}');
      final SaveEnvelope envelope = decodeEnvelope(framed.payload!);
      expect(envelope.saveId, conformanceSaveId);
      expect(envelope.snapshotGeneration, 0);
      expect(envelope.lastAppliedTransaction, 1);
      expect(envelope.commitComplete, isTrue);
      expect(envelope.state.steps.totalGranted, 613);

      // And the journal line on disk must be the transaction that authorized
      // it.
      final JournalLineResult line = decodeJournalLine(
        journal.readAsBytesSync(),
      );
      expect(line.ok, isTrue);
      expect(line.record!.transactionId, 1);
      expect(line.record!.saveId, conformanceSaveId);
    });

    test('every file created is one StorageLayout declares', () async {
      // The backup-exclusion audit reads StorageLayout.allFiles. A file created
      // outside that list would be a save artifact nobody excludes from iCloud.
      final StorageLayout layout = StorageLayout(root);
      final SaveRepository repo = SaveRepository(
        snapshots: fixture.snapshots,
        journal: fixture.journal,
      );
      final GameEngine engine = GameEngine.newGame(registry: registry);

      int generation = -1;
      int transaction = 0;
      for (final int steps in <int>[137, 291, 613]) {
        final EngineResult r = engine.execute(
          GrantSyntheticSteps(steps: steps, reason: 'g$steps'),
        );
        final CommitDurable d =
            await repo.commit(
                  after: engine.state,
                  events: r.events,
                  saveId: conformanceSaveId,
                  expectation: CommitExpectation(
                    expectedSnapshotGeneration: generation,
                    expectedLastAppliedTransaction: transaction,
                  ),
                  originSaltFingerprint: null,
                )
                as CommitDurable;
        generation = d.generation;
        transaction = d.transactionId;
      }
      await fixture.seedIdentity(conformanceSaveId, conformanceSalt);

      final Set<String> declared = layout.allFiles
          .map((File f) => f.uri.pathSegments.last)
          .toSet();
      final Set<String> present = root
          .listSync()
          .map((FileSystemEntity e) => e.uri.pathSegments.last)
          .where((String s) => s.isNotEmpty)
          .toSet();

      expect(present, isNotEmpty);
      expect(
        present.difference(declared),
        isEmpty,
        reason: 'an undeclared artifact is one no backup exclusion covers',
      );
    });

    test('the ports read from disk, not from a cache', () async {
      // Damage the file behind the adapter's back. If `read` still returns the
      // healthy bytes, the suite above was talking to memory.
      final Uint8List healthy = Uint8List.fromList(
        utf8.encode('{"m":"stride.save"}\npayload'),
      );
      await fixture.snapshots.write(SnapshotSlot.a, healthy);

      final File slotA = File('${root.path}/save_slot_a');
      expect(slotA.readAsBytesSync(), healthy);

      slotA.writeAsBytesSync(Uint8List.sublistView(healthy, 0, 5));
      expect(
        await fixture.snapshots.read(SnapshotSlot.a),
        hasLength(5),
        reason: 'the read must reflect the medium, not a remembered write',
      );

      slotA.deleteSync();
      expect(await fixture.snapshots.read(SnapshotSlot.a), isNull);
    });

    test('a journal append is a real append, not a rewrite', () async {
      final File journal = File('${root.path}/ledger_journal');
      await fixture.journal.appendLine(
        Uint8List.fromList(utf8.encode('one\n')),
      );
      final int afterFirst = journal.lengthSync();
      await fixture.journal.appendLine(
        Uint8List.fromList(utf8.encode('two\n')),
      );

      expect(journal.lengthSync(), greaterThan(afterFirst));
      expect(journal.readAsStringSync(), 'one\ntwo\n');
    });
  });

  group('read-back verification', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('stride_readback_');
    });
    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    final Uint8List payload = Uint8List.fromList(
      utf8.encode('the bytes that must come back'),
    );

    test('a healthy write returns and the bytes are on disk', () async {
      final File file = File('${root.path}/healthy');
      await writeVerified(file, payload);

      expect(file.existsSync(), isTrue);
      expect(file.readAsBytesSync(), payload);
    });

    test(
      'a read-back that returns fewer bytes fails rather than succeeding',
      () async {
        // This is the case the whole "read-back verified" claim exists for: a
        // write and flush that both return successfully and leave a short file.
        final File file = LyingFile(
          File('${root.path}/short'),
          (Uint8List truth) =>
              Uint8List.sublistView(truth, 0, truth.length - 1),
        );

        await expectLater(
          writeVerified(file, payload),
          throwsA(
            isA<StorageException>()
                .having(
                  (StorageException e) => e.operation,
                  'operation',
                  contains('read-back'),
                )
                .having(
                  (StorageException e) => '${e.cause}',
                  'cause',
                  contains('read back'),
                ),
          ),
        );
      },
    );

    test(
      'a read-back that returns different bytes fails, naming only the index',
      () async {
        final File file = LyingFile(File('${root.path}/flipped'), (
          Uint8List truth,
        ) {
          final Uint8List copy = Uint8List.fromList(truth);
          copy[3] = copy[3] ^ 0x01;
          return copy;
        });

        Object? thrown;
        try {
          await writeVerified(file, payload);
        } on Object catch (e) {
          thrown = e;
        }

        expect(thrown, isA<StorageException>());
        final StorageException failure = thrown! as StorageException;
        expect(failure.operation, contains('read-back'));
        expect('${failure.cause}', contains('byte 3'));
        expect(
          '${failure.cause}',
          isNot(contains(utf8.decode(payload))),
          reason:
              'the differing values may be save payload, and this message '
              'reaches a diagnostic',
        );
      },
    );

    test(
      'a read-back is genuinely performed on the healthy path too',
      () async {
        // The lying file returns the truth. If `writeVerified` never read back,
        // this would pass identically — so the assertion is that the read
        // *happened*, counted by the harness.
        int reads = 0;
        final File file = LyingFile(File('${root.path}/counted'), (
          Uint8List truth,
        ) {
          reads++;
          return truth;
        });

        await writeVerified(file, payload);

        expect(
          reads,
          1,
          reason: 'exactly one read-back per write, and never zero',
        );
      },
    );

    test('a write to an unopenable path fails closed', () async {
      // A directory where a file belongs. The failure is at the write, not the
      // read-back, and it must still be a typed StorageException rather than a
      // raw FileSystemException reaching the protocol.
      final Directory blocker = Directory('${root.path}/blocked')..createSync();
      expect(blocker.existsSync(), isTrue);

      await expectLater(
        writeVerified(File(blocker.path), payload),
        throwsA(
          isA<StorageException>().having(
            (StorageException e) => e.operation,
            'operation',
            contains('write'),
          ),
        ),
      );
    });
  });
}
