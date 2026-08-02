// On-device checks that the platform channel is wired end to end.
//
// M-2 scope: the boundary answers, and answers without throwing. Real step
// data, permission flows, and reconciliation behavior are S-01, S-01b, and
// V-02b — all of which need a physical device.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final StepProvider provider = PlatformStepProvider();

  testWidgets('isAvailable crosses the channel and returns a bool', (
    WidgetTester tester,
  ) async {
    // Against the M-2 shells this returns false. That is the point: the game
    // must be fully playable when the health service is absent, and the shell
    // exercises that path.
    expect(await provider.isAvailable(), isA<bool>());
  });

  testWidgets('requestAuthorization reports a state rather than throwing', (
    WidgetTester tester,
  ) async {
    expect(await provider.requestAuthorization(), isA<StepAuthorization>());
  });

  testWidgets('fetchNewSteps returns a well-formed result', (
    WidgetTester tester,
  ) async {
    final StepFetchResult result = await provider.fetchNewSteps();

    expect(result.newSteps, isNonNegative);
    expect(result.deletedSteps, isNonNegative);
    // An invalidated cursor must always carry the rescan needed to recover
    // from it — a bare invalidation would leave reconciliation with no
    // authoritative figure and no safe move.
    if (result.status == CursorStatus.invalidated) {
      expect(result.rescan, isNotNull);
    }
  });
}
