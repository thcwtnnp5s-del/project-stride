// F-06 finding F7 — the per-write backup-exclusion diagnostic must have a
// reader.
//
// `StrideRuntime.perWriteExclusionFailures` was declared, populated by the
// stores on every commit and compaction, and then read by nothing: zero
// references anywhere in `lib/`, `test/` or `integration_test/`. Its own doc
// comment said failures were "surfaced rather than swallowed". They were
// swallowed.
//
// That is a worse state than having no diagnostic. A control with a dead
// diagnostic looks observed in review and in the source, and the condition it
// reports — a save file that would travel in an iCloud restore, and therefore
// a step ledger replayed on a second device against a HealthKit source the
// first one already consumed from — is silent by nature. Nothing else would
// ever have told anyone.
//
// These tests are the reader. If either the eager sink or
// `describeBackupExclusion` is removed, the diagnostic goes dead again and
// this file fails.

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/runtime_bootstrap.dart';
import 'package:stride_secure_store/stride_secure_store.dart';

void main() {
  // rootBundle, for the content pack.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('stride_exclusion_diag');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// A store whose per-write re-application always fails for [paths].
  ///
  /// The launch sweep is left clean on purpose. The two controls are separate
  /// and the per-write one is the half that regressed, so a fixture that failed
  /// both could pass while only the launch report was being read.
  FakeSecureIdentityStore failingReapplication(List<String> paths) =>
      FakeSecureIdentityStore()
        ..plannedReapplicationReport = BackupExclusionReport(
          excluded: const <String>[],
          missing: const <String>[],
          failed: <String>[for (final String p in paths) '$p\tattribute lost'],
        );

  test('a per-write failure reaches a sink at the moment it happens', () async {
    final List<String> reported = <String>[];
    final StrideRuntime runtime = await bootstrapStride(
      overrideRoot: root,
      secureStore: failingReapplication(<String>['/x/ledger_journal']),
      random: Random(1750000000),
      onPerWriteExclusionFailure: reported.add,
    );

    // Bootstrap of a new game commits, which is what fires the hook. If this
    // is empty the probe is not exercising the per-write path at all.
    expect(
      runtime.perWriteExclusionFailures,
      isNotEmpty,
      reason: 'the fixture did not reach a per-write re-application',
    );
    expect(
      reported,
      isNotEmpty,
      reason:
          'the per-write exclusion failure was accumulated into a list and '
          'never announced. A failure that only appears in a field nobody '
          'reads is a failure nobody will ever see, and this one means a save '
          'file would travel in an iCloud restore.',
    );
    expect(reported.first, contains('ledger_journal'));
    expect(
      reported.length,
      runtime.perWriteExclusionFailures.length,
      reason: 'every accumulated failure must also have been announced',
    );
  });

  test('the accumulated list has a reader that names the paths', () async {
    final StrideRuntime runtime = await bootstrapStride(
      overrideRoot: root,
      secureStore: failingReapplication(<String>['/x/save_slot_a']),
      random: Random(1750000000),
      onPerWriteExclusionFailure: (String _) {},
    );

    expect(
      runtime.backupExclusionHealthy,
      isFalse,
      reason:
          'the launch sweep was clean and the per-write hook was not, so a '
          'health check that reads only the launch report would say clean — '
          'which is exactly the case the two controls are kept apart for',
    );

    final String description = runtime.describeBackupExclusion();
    expect(description, contains('save_slot_a'));
    expect(description, contains('FAILED'));
  });

  test(
    'a clean launch is reported as clean, so the reader is not vacuous',
    () async {
      // Without this, a `describeBackupExclusion` hard-wired to report a problem
      // would pass everything above.
      final StrideRuntime runtime = await bootstrapStride(
        overrideRoot: root,
        secureStore: FakeSecureIdentityStore(),
        random: Random(1750000000),
        onPerWriteExclusionFailure: (String _) {},
      );

      expect(runtime.perWriteExclusionFailures, isEmpty);
      expect(runtime.backupExclusionHealthy, isTrue);
      expect(runtime.describeBackupExclusion(), contains('clean'));
      expect(runtime.describeBackupExclusion(), isNot(contains('FAILED')));
    },
  );
}
