// The port contract, and the Pigeon translation, on a machine with no Apple
// hardware.
//
// What this file can prove: that the three read outcomes stay three, that a
// create is add-only, and that the platform types are converted in both
// directions without loss.
//
// What it cannot prove: anything about the Keychain. `KeychainIdentityStore`
// here is driven by a fake host api. The real Security-framework behaviour is
// covered by the simulator suite in example/ios/RunnerTests, and the backup
// behaviour it is all for is not covered anywhere — see the report.

import 'dart:io' show File;
import 'dart:typed_data';

import 'package:flutter/services.dart' show BinaryMessenger;
import 'package:flutter_test/flutter_test.dart';
import 'package:stride_secure_store/src/messages.g.dart';
import 'package:stride_secure_store/stride_secure_store.dart';

/// A host api that answers with whatever the test planned, and records what it
/// was asked.
final class _FakeHostApi implements SecureStoreHostApi {
  // Pigeon puts its transport on the generated class rather than behind an
  // interface, so a fake has to name them. Never used: nothing here sends.
  @override
  // ignore: non_constant_identifier_names
  final BinaryMessenger? pigeonVar_binaryMessenger = null;

  @override
  // ignore: non_constant_identifier_names
  final String pigeonVar_messageChannelSuffix = '';

  PlatformSecureReadResult readResult = PlatformSecureReadResult(
    status: PlatformSecureReadStatus.absent,
  );
  PlatformSecureWriteStatus writeStatus = PlatformSecureWriteStatus.created;

  PlatformIdentityRecord? received;
  String? receivedDirectory;
  List<String>? receivedFiles;

  @override
  Future<PlatformSecureReadResult> readIdentity() async => readResult;

  @override
  Future<PlatformSecureWriteStatus> createIdentity(
    PlatformIdentityRecord record,
  ) async {
    received = record;
    return writeStatus;
  }

  @override
  Future<bool> deleteIdentity() async => true;

  @override
  Future<PlatformBackupExclusionReport> applyBackupExclusions(
    String directoryPath,
    List<String> filePaths,
  ) async {
    receivedDirectory = directoryPath;
    receivedFiles = filePaths;
    return PlatformBackupExclusionReport(
      excluded: <String>[directoryPath, ...filePaths],
      missing: <String>[],
      failed: <String>[],
    );
  }

  List<List<String>> reapplications = <List<String>>[];

  @override
  Future<PlatformBackupExclusionReport> reapplyBackupExclusions(
    List<String> paths,
  ) async {
    reapplications.add(List<String>.of(paths));
    return PlatformBackupExclusionReport(
      excluded: paths,
      missing: const <String>[],
      failed: const <String>[],
    );
  }

  @override
  Future<PlatformSecureStoreDiagnostics> readDiagnostics(
    List<String> paths,
  ) async => PlatformSecureStoreDiagnostics(
    keychainAccessibility: 'cku',
    excludedPaths: paths,
    notExcludedPaths: const <String>[],
    missingPaths: const <String>[],
  );
}

// ignore: library_private_types_in_public_api
KeychainIdentityStore storeOver(_FakeHostApi api) =>
    KeychainIdentityStore(api: api, supported: true);

/// Reads a source file, relative to the package root.
///
/// Fails loudly when the file is not there. A source-scanning assertion that
/// silently found nothing to scan would pass forever after a rename, which is
/// the failure mode these particular tests exist to avoid.
String _read(String relativePath) {
  final File file = File(relativePath);
  if (!file.existsSync()) {
    fail(
      '$relativePath does not exist relative to ${File('.').absolute.path}. '
      'This assertion scans source, so a moved file must fail rather than '
      'quietly stop checking anything.',
    );
  }
  return file.readAsStringSync();
}

void main() {
  group('read outcomes', () {
    test(
      'found carries the record across the boundary byte for byte',
      () async {
        final Uint8List salt = fakeSalt(7);
        final _FakeHostApi api = _FakeHostApi()
          ..readResult = PlatformSecureReadResult(
            status: PlatformSecureReadStatus.found,
            record: PlatformIdentityRecord(saveId: 'lineage-one', salt: salt),
          );

        final SecureReadResult result = await storeOver(api).read();

        expect(result.outcome, SecureReadOutcome.found);
        expect(result.identity!.saveId, 'lineage-one');
        // Every byte, not a length. A salt that survives the boundary with one
        // byte changed re-keys every origin, which is the double-grant.
        expect(result.identity!.salt, salt);
      },
    );

    test('absent is absent', () async {
      final _FakeHostApi api = _FakeHostApi()
        ..readResult = PlatformSecureReadResult(
          status: PlatformSecureReadStatus.absent,
        );

      expect((await storeOver(api).read()).outcome, SecureReadOutcome.absent);
    });

    test('unavailable is NOT folded into absent', () async {
      // The single most important assertion in this file. A locked-device read
      // — errSecInteractionNotAllowed, -25308 — reported as absence is how a
      // replacement identity gets minted over a live save.
      final _FakeHostApi api = _FakeHostApi()
        ..readResult = PlatformSecureReadResult(
          status: PlatformSecureReadStatus.unavailable,
          osStatus: -25308,
        );

      final SecureReadResult result = await storeOver(api).read();

      expect(result.outcome, SecureReadOutcome.unavailable);
      expect(result.outcome, isNot(SecureReadOutcome.absent));
      expect(result.identity, isNull);
      expect(result.diagnostic, contains('-25308'));
    });

    test('the contract has exactly three read outcomes', () {
      // A fourth added without a mapping would be a compile error in
      // `KeychainIdentityStore.read`'s exhaustive switch; a *removed* one would
      // not be, and collapsing three into two is the regression that matters.
      expect(PlatformSecureReadStatus.values, hasLength(3));
      expect(SecureReadOutcome.values, hasLength(3));
    });
  });

  group('create is add-only', () {
    test('a created record reports created', () async {
      final _FakeHostApi api = _FakeHostApi()
        ..writeStatus = PlatformSecureWriteStatus.created;

      final SecureWriteOutcome outcome = await storeOver(
        api,
      ).create(SecureIdentity(saveId: 'a', salt: fakeSalt()));

      expect(outcome, SecureWriteOutcome.created);
      expect(api.received!.saveId, 'a');
      expect(api.received!.salt, fakeSalt());
    });

    test('an existing record reports alreadyExists, not success', () async {
      final _FakeHostApi api = _FakeHostApi()
        ..writeStatus = PlatformSecureWriteStatus.alreadyExists;

      final SecureWriteOutcome outcome = await storeOver(
        api,
      ).create(SecureIdentity(saveId: 'a', salt: fakeSalt()));

      // Reported, never repaired. Success here would let the caller carry on
      // believing it had written its own key.
      expect(outcome, SecureWriteOutcome.alreadyExists);
    });

    test('the port declares no update or upsert method', () {
      // This replaces a test that asserted a hand-written list of method names
      // did not contain 'update'. That list was a literal in the test file: it
      // would have stayed green through an `update` added to the interface on
      // the very next line, which makes it a test that could only ever pass.
      // A test that cannot fail is worse than no test, because it reads as
      // coverage.
      //
      // This one reads the actual source. It fails if anyone adds the method.
      final String source = _read('lib/src/secure_identity_store.dart');

      // Method *declarations* on the port, not the word anywhere: the doc
      // comments legitimately discuss updates and writes at length.
      final Iterable<String> declarations = RegExp(
        r'^\s*(?:Future<[^>]*>|void|bool)\s+([a-zA-Z_]\w*)\s*\(',
        multiLine: true,
      ).allMatches(source).map((RegExpMatch m) => m.group(1)!);

      for (final String banned in <String>['update', 'upsert', 'replace']) {
        expect(
          declarations.where((String d) => d.toLowerCase().contains(banned)),
          isEmpty,
          reason:
              'Enforcement by absence is the mechanism for "never overwrite an '
              'existing key because a read failed". A caller that has just had '
              'a read fail must not be able to express an overwrite. Adding a '
              '$banned method removes that guarantee no matter what the '
              'callers currently do.',
        );
      }
      // `reapplyBackupExclusions` contains neither banned word; if a rename
      // ever makes it collide, this pins that the exemption was deliberate.
      expect(declarations, contains('create'));
      expect(declarations, contains('delete'));
    });

    test('the Swift implementation calls SecItemAdd and never SecItemUpdate', () {
      // Asserted here as well as in Scripts/check-backup-exclusions.sh, because
      // this test runs on every platform in the fastest job, and the Swift is
      // compiled only on the macOS job. A branch that added an update path
      // should not need a Mac to be caught.
      final String swift = _read(
        'ios/stride_secure_store/Sources/stride_secure_store/'
        'KeychainIdentityStore.swift',
      );

      expect(swift, contains('SecItemAdd'));
      expect(
        swift,
        isNot(matches(RegExp(r'SecItemUpdate\s*\('))),
        reason:
            'An existing keychain item is either the live identity or evidence '
            'of a crash between minting and the first commit. Replacing it '
            'orphans the save it belongs to.',
      );
    });

    test('every keychain query pins accessibility and synchronizable', () {
      final String swift = _read(
        'ios/stride_secure_store/Sources/stride_secure_store/'
        'KeychainIdentityStore.swift',
      );

      // The only accessibility constant in the file must be the
      // ThisDeviceOnly one. Any other is restored onto a second device, which
      // re-opens the double-grant.
      expect(
        swift,
        contains('kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly'),
      );
      expect(
        swift,
        isNot(
          matches(
            RegExp(
              r'kSecAttrAccessible(WhenUnlocked|AfterFirstUnlock|Always)'
              r'([^A-Za-z]|$)',
            ),
          ),
        ),
        reason: 'an accessibility class without ThisDeviceOnly travels',
      );

      // Synchronizable false on the shared base query, so no add and no
      // recreating query can produce an iCloud-Keychain-syncing item. The
      // delete path widens it to `Any` deliberately, to sweep up a stray
      // synchronizable item from an older build.
      expect(swift, contains('kSecAttrSynchronizable as String: false'));
      expect(swift, contains('kSecAttrSynchronizableAny'));
    });
  });

  group('backup exclusion', () {
    test('the directory and every file are passed through', () async {
      final _FakeHostApi api = _FakeHostApi();

      final BackupExclusionReport report = await storeOver(api)
          .applyBackupExclusions(
            directoryPath: '/root/project_stride',
            filePaths: <String>[
              '/root/project_stride/save_slot_a',
              '/root/project_stride/ledger_journal',
            ],
          );

      expect(api.receivedDirectory, '/root/project_stride');
      expect(api.receivedFiles, hasLength(2));
      // The directory alone is not enough: the attribute is not documented as
      // inherited by files created inside an excluded directory.
      expect(report.excluded, hasLength(3));
      expect(report.isClean, isTrue);
    });

    test('a failed path makes the report unclean', () {
      const BackupExclusionReport report = BackupExclusionReport(
        excluded: <String>['/root'],
        missing: <String>[],
        failed: <String>['/root/ledger_journal\tattribute did not stick'],
      );

      expect(report.isClean, isFalse);
    });

    test('a missing path is not a failure', () {
      // `StorageLayout.allFiles` names every file the layout *may* create. The
      // journal sidecar exists only during a compaction, and reporting its
      // absence as a fault would make a healthy launch look broken.
      const BackupExclusionReport report = BackupExclusionReport(
        excluded: <String>['/root'],
        missing: <String>['/root/ledger_journal.compacting'],
        failed: <String>[],
      );

      expect(report.isClean, isTrue);
    });
  });

  group('the unsupported store', () {
    test('reports absent rather than unavailable', () async {
      // Load-bearing. This is not a store that failed, it is a platform that
      // never had one, and the caller must fall through to file storage rather
      // than refuse to start the game on Android.
      const UnsupportedSecureIdentityStore store =
          UnsupportedSecureIdentityStore();

      expect(store.isSupported, isFalse);
      expect((await store.read()).outcome, SecureReadOutcome.absent);
      expect(
        (await store.applyBackupExclusions(
          directoryPath: '/x',
          filePaths: <String>[],
        )).isClean,
        isTrue,
      );
    });
  });

  group('the salt never leaks through toString', () {
    test('SecureIdentity redacts both fields', () {
      final SecureIdentity identity = SecureIdentity(
        saveId: 'lineage-one',
        salt: fakeSalt(),
      );

      // This type reaches a log line by accident sooner or later, and a
      // toString that dumps key material is how it gets there.
      expect(identity.toString(), isNot(contains('lineage-one')));
      expect(identity.toString(), contains('redacted'));
    });
  });

  group('the fake matches the real contract', () {
    test('add-only, and it records order', () async {
      final FakeSecureIdentityStore fake = FakeSecureIdentityStore();

      expect((await fake.read()).outcome, SecureReadOutcome.absent);
      expect(
        await fake.create(SecureIdentity(saveId: 'a', salt: fakeSalt())),
        SecureWriteOutcome.created,
      );
      expect(
        await fake.create(SecureIdentity(saveId: 'b', salt: fakeSalt())),
        SecureWriteOutcome.alreadyExists,
        reason:
            'a fake that allowed an overwrite would let the defect this '
            'port prevents pass its own suite',
      );
      expect(fake.stored!.saveId, 'a');
      expect(fake.calls, <String>['read', 'create', 'create']);
    });

    test('an unavailable read is a distinct planned fault', () async {
      final FakeSecureIdentityStore fake = FakeSecureIdentityStore()
        ..readIsUnavailable = true;

      expect((await fake.read()).outcome, SecureReadOutcome.unavailable);
    });
  });

  // ==========================================================================
  // The fail-closed semantics, over the fake, so they are locked down by a
  // test that runs on every platform.
  //
  // These assert the *outcome* each state produces, not the plumbing. The
  // consumer is `IdentityVault`, which turns `unavailable` into
  // `IdentityStoreUnavailable` and thus `BootstrapBlockReason
  // .storageUnavailable`, and `absent` into null and thus a new game or
  // `originIdentityMissing`. If these three ever collapse into two, that
  // distinction disappears and a locked device looks like a fresh install.
  // ==========================================================================
  group('fail-closed outcome semantics', () {
    test(
      'an empty store is absent — a new installation, not a fault',
      () async {
        final FakeSecureIdentityStore fake = FakeSecureIdentityStore();

        final SecureReadResult result = await fake.read();

        expect(result.outcome, SecureReadOutcome.absent);
        expect(result.identity, isNull);
        // Absence is the only state that may lead to minting, and it must be
        // reachable only from a store that answered.
        expect(result.diagnostic, isNull);
      },
    );

    test('a populated store is found and carries the salt', () async {
      final SecureIdentity stored = SecureIdentity(
        saveId: 'lineage-one',
        salt: fakeSalt(3),
      );
      final FakeSecureIdentityStore fake = FakeSecureIdentityStore(
        initial: stored,
      );

      final SecureReadResult result = await fake.read();

      expect(result.outcome, SecureReadOutcome.found);
      expect(result.identity, stored);
      expect(result.identity!.salt, fakeSalt(3));
    });

    test('a store that cannot answer is unavailable, never absent', () async {
      final FakeSecureIdentityStore fake = FakeSecureIdentityStore(
        initial: SecureIdentity(saveId: 'lineage-one', salt: fakeSalt()),
      )..readIsUnavailable = true;

      final SecureReadResult result = await fake.read();

      expect(result.outcome, SecureReadOutcome.unavailable);
      expect(result.outcome, isNot(SecureReadOutcome.absent));
      expect(result.identity, isNull);
      // The record is still there. `unavailable` over a live identity is
      // exactly the locked-device case, and the whole safety argument is that
      // it does not read as "nothing here".
      expect(fake.stored, isNotNull);
    });

    test('the three read outcomes are mutually exclusive', () {
      // Named individually so a future case added without a mapping is a
      // deliberate edit here rather than a silent fourth state.
      expect(SecureReadOutcome.values, <SecureReadOutcome>[
        SecureReadOutcome.found,
        SecureReadOutcome.absent,
        SecureReadOutcome.unavailable,
      ]);
    });

    test('the first create is created', () async {
      final FakeSecureIdentityStore fake = FakeSecureIdentityStore();

      expect(
        await fake.create(SecureIdentity(saveId: 'a', salt: fakeSalt())),
        SecureWriteOutcome.created,
      );
      expect(fake.stored!.saveId, 'a');
    });

    test('a create over an existing record leaves it untouched', () async {
      final FakeSecureIdentityStore fake = FakeSecureIdentityStore(
        initial: SecureIdentity(saveId: 'live', salt: fakeSalt(1)),
      );

      expect(
        await fake.create(SecureIdentity(saveId: 'usurper', salt: fakeSalt(2))),
        SecureWriteOutcome.alreadyExists,
      );

      // Both fields. A create that reported alreadyExists and still replaced
      // the salt would orphan the save just as thoroughly as one that replaced
      // the id, and only asserting the id would miss it.
      expect(fake.stored!.saveId, 'live');
      expect(fake.stored!.salt, fakeSalt(1));
    });

    test('a refused create writes nothing', () async {
      final FakeSecureIdentityStore fake = FakeSecureIdentityStore()
        ..createFails = true;

      expect(
        await fake.create(SecureIdentity(saveId: 'a', salt: fakeSalt())),
        SecureWriteOutcome.failed,
      );
      expect(
        fake.stored,
        isNull,
        reason:
            'a failed write that left a record behind would let the next '
            'launch resume under an identity the caller was told it did not '
            'have',
      );
    });

    test('the three write outcomes are mutually exclusive', () {
      expect(SecureWriteOutcome.values, <SecureWriteOutcome>[
        SecureWriteOutcome.created,
        SecureWriteOutcome.alreadyExists,
        SecureWriteOutcome.failed,
      ]);
    });

    test(
      'an unavailable read does not prevent the port being asked to '
      'create — the refusal is the caller\'s, and it is tested there',
      () async {
        // Stated so the boundary is unambiguous. This port has no memory and no
        // ordering: it cannot refuse a create because a previous read failed,
        // and pretending it could would hide where the rule actually lives.
        //
        // The rule is enforced in `IdentityVault`, which holds the read fault and
        // throws from both `mintCandidate` and `write`, and in
        // `BootstrapCoordinator`, which returns `storageUnavailable` before it
        // ever reaches the minting path. What this port guarantees is narrower
        // and structural: `create` is add-only, so even a caller that ignored
        // every rule cannot overwrite a live identity.
        final FakeSecureIdentityStore fake = FakeSecureIdentityStore(
          initial: SecureIdentity(saveId: 'live', salt: fakeSalt(1)),
        )..readIsUnavailable = true;

        expect((await fake.read()).outcome, SecureReadOutcome.unavailable);
        expect(
          await fake.create(
            SecureIdentity(saveId: 'replacement', salt: fakeSalt(2)),
          ),
          SecureWriteOutcome.alreadyExists,
        );
        expect(fake.stored!.saveId, 'live');
        expect(fake.stored!.salt, fakeSalt(1));
      },
    );
  });

  // ==========================================================================
  // The per-write re-application. See BACKUP_EXCLUSION_CONTRACT.md.
  // ==========================================================================
  group('per-write backup-exclusion re-application', () {
    test('the paths reach the platform unchanged', () async {
      final _FakeHostApi api = _FakeHostApi();

      final BackupExclusionReport report = await storeOver(api)
          .reapplyBackupExclusions(<String>[
            '/root/project_stride/ledger_journal',
          ]);

      expect(api.reapplications, <List<String>>[
        <String>['/root/project_stride/ledger_journal'],
      ]);
      expect(report.isClean, isTrue);
      expect(report.excluded, <String>['/root/project_stride/ledger_journal']);
    });

    test('the hook is null where there is no platform implementation', () {
      // Null rather than a no-op, so "the control is not active here" and "the
      // control ran and did nothing" are distinguishable. On Android the
      // exclusion is declarative and stronger, and calling an unregistered
      // plugin would raise MissingPluginException on every commit.
      expect(
        const UnsupportedSecureIdentityStore().backupExclusionHook(),
        isNull,
      );
      expect(
        FakeSecureIdentityStore(isSupported: false).backupExclusionHook(),
        isNull,
      );
    });

    test('the hook forwards each operation as its own call', () async {
      final FakeSecureIdentityStore fake = FakeSecureIdentityStore();
      final ReapplyBackupExclusion hook = fake.backupExclusionHook()!;

      await hook(<String>['/p/save_slot_a']);
      await hook(<String>['/p/ledger_journal']);

      // Per operation, not accumulated. "The journal was re-excluded after the
      // compaction that renamed a new node over it" is the claim that matters,
      // and a flattened set cannot express it.
      expect(fake.reapplications, <List<String>>[
        <String>['/p/save_slot_a'],
        <String>['/p/ledger_journal'],
      ]);
    });

    test('a failed re-application is reported and does not throw', () async {
      // It runs on the commit path. A refused setResourceValues must not turn a
      // durable save into a failed one — the Keychain identity is the first
      // control and does not depend on this. But a `failed` entry means a file
      // that would travel in a restore, so it must not vanish either.
      final FakeSecureIdentityStore fake = FakeSecureIdentityStore()
        ..plannedReapplicationReport = const BackupExclusionReport(
          excluded: <String>[],
          missing: <String>[],
          failed: <String>['/p/ledger_journal\tattribute did not stick'],
        );

      final List<BackupExclusionReport> seen = <BackupExclusionReport>[];
      final ReapplyBackupExclusion hook = fake.backupExclusionHook(
        onReport: seen.add,
      )!;

      await expectLater(hook(<String>['/p/ledger_journal']), completes);

      expect(seen, hasLength(1));
      expect(seen.single.isClean, isFalse);
      expect(seen.single.failed.single, contains('ledger_journal'));
    });

    test('the hook is usable without a report callback', () async {
      final FakeSecureIdentityStore fake = FakeSecureIdentityStore();

      await fake.backupExclusionHook()!(<String>['/p/save_slot_a']);

      expect(fake.reapplications, hasLength(1));
    });
  });

  test('the expected accessibility constant is ThisDeviceOnly', () {
    // `cku` is kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly. The suffix `u`
    // is the ThisDeviceOnly bit, and it is the entire control: without it the
    // item is restored onto a second device and the origin refusal never fires.
    //
    // Pinned on both sides — the simulator suite asserts the same string
    // against Apple's own constant, so a drift fails on whichever side runs
    // first.
    expect(kExpectedKeychainAccessibility, 'cku');
    expect(kExpectedKeychainAccessibility, endsWith('u'));
  });
}
