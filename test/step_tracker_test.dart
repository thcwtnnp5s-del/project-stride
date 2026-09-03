// The step tracker tells the truth about what was counted, and when
// (`DECISIONS/0026`; the physical-device polish pass, item 1).
//
// ## What these cases pin
//
// The local-day fold lives in `StrideSession.stepHistory()` — the one
// documented home of the timezone policy Q-UI-9 refused to let a widget
// invent. These cases pin its attribution rules to controlled bucket
// times:
//
//   1. a slice counts toward the local day its bucket starts in;
//   2. today's hours group the same way, ascending, absent when empty;
//   3. the week is the trailing seven local days and nothing else — a
//      slice compacted past the retention horizon leaves the days and
//      stays in the lifetime figure;
//   4. "last synced" moves only when the store was actually read.
//
// Times are built with the local `DateTime` constructor throughout, so the
// cases assert the same local-day arithmetic on any machine's timezone.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');

/// A fixed local "now": mid-day, away from midnight, so the cases are not
/// sensitive to when the suite runs.
final DateTime now = DateTime(2026, 8, 24, 12, 30);

StepObservation at(DateTime start, int steps) => StepObservation(
  key: ObservationKey(
    origin: phone,
    bucket: TimeBucket(
      startMillis: start.millisecondsSinceEpoch,
      endMillis: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    ),
  ),
  steps: steps,
);

SyncFetch pageOf(List<StepObservation> observations) => SyncFetch(
  IncrementalSync(
    observations: observations,
    nextCursor: SyncCursor.ofString('c0'),
    completeness: CompleteThrough(
      throughMillis: now.millisecondsSinceEpoch,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: now
            .subtract(const Duration(days: 30))
            .millisecondsSinceEpoch,
        intervalEndMillis: now.millisecondsSinceEpoch,
        queryGeneration: 1,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_tracker'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  Future<StrideSession> boot(List<SyncFetch> script) async {
    final StrideSession session = await StrideSession.start(
      overrideRoot: root,
      source: MockStepSource(script: script),
    );
    session.activityWallClock = () => now.millisecondsSinceEpoch;
    return session;
  }

  test('slices land on the local day their bucket starts in', () async {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final StrideSession s = await boot(<SyncFetch>[
      pageOf(<StepObservation>[
        // Two hours of this morning, one hour of yesterday evening, one of
        // six days ago — the oldest day still inside the week.
        at(today.add(const Duration(hours: 9)), 1200),
        at(today.add(const Duration(hours: 10)), 800),
        at(today.subtract(const Duration(hours: 3)), 3000),
        at(
          today
              .subtract(const Duration(days: 6))
              .add(const Duration(hours: 15)),
          500,
        ),
      ]),
    ]);
    await s.syncSteps();

    final StepHistory history = s.stepHistory();
    expect(history.days, hasLength(7));
    expect(history.today.isToday, isTrue);
    expect(history.today.granted, 2000);
    expect(history.days[5].granted, 3000, reason: 'yesterday');
    expect(history.days.first.granted, 500, reason: 'six days ago');
    expect(history.week, 2000 + 3000 + 500);
    expect(history.originCount, 1);

    // Today's hours, ascending, exactly the two that hold steps.
    expect(history.hoursToday, hasLength(2));
    expect(history.hoursToday.first.granted, 1200);
    expect(history.hoursToday.last.granted, 800);
    expect(
      history.hoursToday.first.startMillis <
          history.hoursToday.last.startMillis,
      isTrue,
    );
  });

  test(
    'a compacted slice leaves the week and stays in the lifetime figure',
    () async {
      final DateTime today = DateTime(now.year, now.month, now.day);
      final StrideSession s = await boot(<SyncFetch>[
        pageOf(<StepObservation>[
          at(today.add(const Duration(hours: 9)), 1000),
          // Ten days ago: behind the ledger's seven-day retention horizon
          // relative to the newest observation, so it is compacted into
          // `grantedBeforeWatermark` on commit.
          at(
            today
                .subtract(const Duration(days: 10))
                .add(const Duration(hours: 12)),
            9000,
          ),
        ]),
      ]);
      await s.syncSteps();

      final StepHistory history = s.stepHistory();
      expect(history.week, 1000, reason: 'the old walk is not a recent day');
      expect(
        history.lifetimeGranted,
        10000,
        reason: 'compaction folds credit, never deletes it',
      );
    },
  );

  test('last synced moves only when the store was actually read', () async {
    final StrideSession s = await boot(<SyncFetch>[
      pageOf(const <StepObservation>[]),
    ]);
    expect(s.stepHistory().lastSyncAtMillis, isNull);

    await s.syncSteps();
    expect(s.stepHistory().lastSyncAtMillis, now.millisecondsSinceEpoch);

    // The script is exhausted: the mock now reports a transient failure,
    // which is not a read and must not refresh the mark.
    final int mark = s.stepHistory().lastSyncAtMillis!;
    await s.syncSteps();
    expect(s.stepHistory().lastSyncAtMillis, mark);
  });

  testWidgets('the Character card opens the tracker, and both spans render', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final DateTime today = DateTime(now.year, now.month, now.day);
    final StrideSession session = (await tester.runAsync(
      () async => boot(<SyncFetch>[
        pageOf(<StepObservation>[
          at(today.add(const Duration(hours: 8)), 2500),
        ]),
      ]),
    ))!;
    await tester.runAsync(session.syncSteps);

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Character'));
    await tester.pumpAndSettle();

    // The compact card: today's figure and the tracker's door.
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Step Tracker'), findsOneWidget);

    // The folio is a longer page than the card it replaced, so the tracker's
    // index tab can sit below the fold. Bring it into view before tapping:
    // a tap on an off-screen widget hit-tests wherever its centre lands, which
    // silently does nothing and then fails somewhere else entirely.
    await tester.ensureVisible(find.text('Step Tracker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Step Tracker'));
    await tester.pumpAndSettle();

    // Week view first: seven day rows, today emphasised, the sync card.
    expect(find.text('TODAY'), findsOneWidget);

    // EPO03 made the tracker a page of the Character folio — ruled sections
    // with Day/Week as index tabs — so the Sync section sits below the fold
    // where the old card had it in view. Scroll to it: the control, its
    // freshness line and its guard are unchanged, and asserting them still
    // matters. What would NOT be acceptable is dropping the assertions
    // because the page grew.
    await tester.dragUntilVisible(
      find.text('Sync steps'),
      find.byType(ListView).last,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sync steps'), findsOneWidget);
    expect(find.textContaining('Synced'), findsOneWidget);
    expect(find.textContaining('Lifetime credited'), findsOneWidget);

    // The Day span: the hour that earned the figure.
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('2,500'), findsWidgets);

    // And back out.
    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();
    expect(find.text('Step Tracker'), findsOneWidget);
  });
}
