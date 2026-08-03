// On-device checks that the platform channel is wired end to end.
//
// Scope: the boundary answers, and answers without throwing. Real step data,
// permission flows, and reconciliation behaviour need a physical device.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // A host-only salt. See the note in example/lib/main.dart: this host writes
  // no ledger, so a fixed salt is safe here and nowhere else.
  final Uint8List hostSalt = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8]);

  late StepSyncSource source;

  setUpAll(() async {
    final OriginKeyingInstall install = await PlatformStepSource.open(
      salt: hostSalt,
    );
    // Fail-closed, end to end: if the native adapter did not accept the device
    // identity there is no source to test with, and reading anyway would key
    // every origin under nothing.
    expect(
      install.isInstalled,
      isTrue,
      reason: 'the adapter refused the identity: ${install.refusal?.name}',
    );
    source = install.source!;
  });

  testWidgets('an empty salt is refused before the channel is touched', (
    WidgetTester tester,
  ) async {
    final OriginKeyingInstall refused = await PlatformStepSource.open(
      salt: Uint8List(0),
    );
    expect(refused.refusal, OriginKeyingRefusal.emptySalt);
    expect(refused.source, isNull);
  });

  testWidgets('a mismatched algorithm version is refused, not absorbed', (
    WidgetTester tester,
  ) async {
    // A silent fallback would produce keys nothing else on the device agrees
    // with, which is indistinguishable from a new device and re-grants the
    // whole retention window.
    final OriginKeyingInstall refused = await PlatformStepSource.open(
      salt: hostSalt,
      algorithmVersion: 9999,
    );
    expect(refused.refusal, OriginKeyingRefusal.unsupportedAlgorithm);
  });

  testWidgets('availability crosses the channel and reports a state', (
    WidgetTester tester,
  ) async {
    // Against the shells this is unavailable. That is the point: the game must
    // be fully playable when the health service is absent, and the shell
    // exercises that path.
    final HealthAvailability result = await source.availability();
    if (!result.available) {
      // "No" must arrive with a reason. A bare false leaves the caller unable
      // to tell "not installed" from "read failed, try again".
      expect(result.reason, isNotNull);
    }
  });

  testWidgets('requestAuthorization reports a state rather than throwing', (
    WidgetTester tester,
  ) async {
    expect(await source.requestAuthorization(), isA<HealthAuthorization>());
  });

  testWidgets('fetchSteps returns a well-formed SyncResponse', (
    WidgetTester tester,
  ) async {
    final SyncFetch fetch = await source.fetchSteps(const SyncRequest());

    // The bridge produces the value the simulation actually consumes. Anything
    // else is the two-model defect DECISIONS/0014 exists to close.
    expect(fetch.response, isA<SyncResponse>());

    switch (fetch.response) {
      case ProviderUnavailableSync():
        // Unavailable never advances a cursor and never settles anything.
        break;
      case NoChangeSync(:final SyncCursor? nextCursor):
        expect(nextCursor, anything);
      case IncrementalSync(:final List<StepObservation> observations):
        for (final StepObservation observation in observations) {
          expect(observation.steps, isNonNegative);
          // Sub-hour buckets would be a minute-by-minute record of when the
          // player moved. The bridge refuses them before they reach here.
          expect(observation.key.bucket.isPersistable, isTrue);
        }
      case ContractViolationSync(:final SyncContractViolation violation):
        // Never a legitimate answer from a real adapter: it means the page's
        // status and its completeness disagreed about what was read, so no
        // reading of it is better than a guess. On a device this is a native
        // defect, and it is worth failing loudly for.
        fail('the adapter sent a self-contradictory page: $violation');
      case CursorInvalidatedSync(:final RescanWindow window):
        // A bare invalidation would leave reconciliation with no authoritative
        // figure and no safe move.
        expect(window.endMillis, greaterThan(window.startMillis));
    }
  });
}
