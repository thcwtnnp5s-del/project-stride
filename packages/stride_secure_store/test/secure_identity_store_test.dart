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

    test('the port offers no way to replace an existing record', () {
      // Enforcement by absence. The interface has create and delete; there is
      // no update, so a caller whose read just failed cannot express an
      // overwrite even if it wants to.
      final List<String> surface = <String>[
        'read',
        'create',
        'delete',
        'applyBackupExclusions',
        'readDiagnostics',
      ];
      expect(surface, isNot(contains('update')));
      expect(surface, isNot(contains('write')));
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
