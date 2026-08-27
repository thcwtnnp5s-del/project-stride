// The sync-forensics projection (Fable V2 Iteration 02, Q-08 evidence):
// one arithmetic, three surfaces. `syncDiagnostics()` folds the same
// committed `grantedSlices` as `stepHistory()` and the bank, so the Step
// Tracker's Today, the diagnostics card's TODAY CREDITED, and the banked
// gain cannot disagree — and the per-source split is exactly the overlap
// the owner's device shows (Oura + iPhone summed).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_diag'));
  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
  final StepOriginKey ring = StepOriginKey('0f1e2d3c4b5a6978');
  const int hour = 60 * 60 * 1000;

  StepObservation at(StepOriginKey origin, int startMillis, int steps) =>
      StepObservation(
        key: ObservationKey(
          origin: origin,
          bucket: TimeBucket(
            startMillis: startMillis,
            endMillis: startMillis + hour,
          ),
        ),
        steps: steps,
      );

  testWidgets(
      'two sources over the same afternoon: one arithmetic, three surfaces',
      (WidgetTester tester) async {
    // Buckets inside *today* by the session's own wall clock, so the
    // local-day fold attributes them to Today deterministically. Anchor at
    // local noon to stay clear of midnight edges.
    final DateTime now = DateTime.now();
    final int noon =
        DateTime(now.year, now.month, now.day, 12).millisecondsSinceEpoch;

    final StrideSession session = (await tester.runAsync(
      () => StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[
            // The baseline sync a fresh game retires (DECISIONS/0019).
            SyncFetch(const NoChangeSync()),
            // The owner's afternoon: phone and ring both record 1-3 PM.
            SyncFetch(
              IncrementalSync(
                observations: <StepObservation>[
                  at(phone, noon + hour, 1500),
                  at(phone, noon + 2 * hour, 1500),
                  at(ring, noon + hour, 1450),
                  at(ring, noon + 2 * hour, 1450),
                ],
                nextCursor: SyncCursor.ofString('c1'),
                completeness: const PartialDelivery(),
              ),
            ),
          ],
        ),
      ),
    ))!;

    await tester.runAsync(() => session.syncSteps()); // baseline, retired
    final int bankedBefore = session.usableEnergy;
    await tester.runAsync(() => session.syncSteps()); // two-source afternoon

    final int bankedGain = session.usableEnergy - bankedBefore;
    final StepHistory history = session.stepHistory();
    final SyncDiagnosticsView d = session.syncDiagnostics();

    // The overlap semantics, pinned end to end at the session: both
    // sources' records credited (Q-08 option 1 — current design).
    expect(bankedGain, 5900);
    expect(history.today.granted, 5900);
    expect(d.todayTotal, 5900);
    expect(history.originCount, 2);
    expect(d.perOrigin, hasLength(2));

    // The split itself — the forensic figure the device test compares
    // against the Health app's Sources list. Labels are positional in
    // stable key order: '0f1e…' (ring) sorts before 'a1b2…' (phone).
    expect(d.perOrigin[0].label, 'Source A');
    expect(d.perOrigin[0].todayGranted, 2900);
    expect(d.perOrigin[1].label, 'Source B');
    expect(d.perOrigin[1].todayGranted, 3000);

    // No identity anywhere in the view (H-7): labels are the whole story.
    for (final OriginDiagnosticsLine line in d.perOrigin) {
      expect(line.label, isNot(contains(phone.value)));
      expect(line.label, isNot(contains(ring.value)));
    }

    // A second sync with nothing new moves none of the three surfaces.
    await tester.runAsync(() => session.syncSteps());
    expect(session.usableEnergy - bankedBefore, 5900);
    expect(session.syncDiagnostics().todayTotal, 5900);
  });
}
