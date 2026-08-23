// The gather card's queue surface (`ACTIVITY_FEEL_PRESENTATION_01` §4a):
// the quantity selector and its affordability clamp, the active panel's
// progress and cumulative gains, and Stop.
//
// The exactly-once accounting itself is `activity_controller_test.dart`'s;
// this file covers the surface a player touches — that the selector never
// offers a queue the balance cannot fund, and that the active card reports
// truthfully and stops cleanly.
//
// The activity timing is the injected fake, so a repetition "takes" ten
// seconds by advancing a hand clock inside `runAsync` — no real waits, and
// the dispatch's file I/O runs where real async can complete.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/state/activity_controller.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/fake_activity_timing.dart';

final ContentId kNode = ContentId.unchecked('resource_node.meadow_patch');
final ContentId kHerb = ContentId.unchecked('item.meadow_herb');

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

SyncFetch page(int steps) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: phone,
          bucket: TimeBucket(startMillis: t0, endMillis: t0 + hour),
        ),
        steps: steps,
      ),
    ],
    nextCursor: SyncCursor.ofString('c1'),
    completeness: CompleteThrough(
      throughMillis: t0 + hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: t0,
        intervalEndMillis: t0 + hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_queue_ui'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  /// Boots a funded session and pumps the app with the fake activity timing.
  Future<StrideSession> pumpFunded(
    WidgetTester tester,
    FakeTiming fake,
    int steps,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Unmounts before the framework's pending-timer check; disposing the
    // controllers cancels the result and summary timers.
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final StrideSession session = (await tester.runAsync(
      () => StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(steps)],
        ),
      ),
    ))!;
    // The session's activity commands must read the same fake clock the
    // controller's timing does — one wall clock, exactly as production
    // (`DECISIONS/0022` §8).
    session.activityWallClock = fake.wallClock;
    // First sync is the new game's baseline (`DECISIONS/0019`); the second
    // banks the funding page.
    await tester.runAsync(() => session.syncSteps());
    await tester.runAsync(() => session.syncSteps());
    expect(session.usableEnergy, steps);

    await tester.pumpWidget(
      StrideApp(
        session: session,
        syncOnStart: false,
        activityTiming: fake.timing,
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  /// Selects the Meadow Patch activity row — since the Adventure restructure
  /// (PRESENTATION_WORLD_REWARD_FEEL_01 §6) the queue controls live in the
  /// selected activity's expanded detail, not on an always-open card.
  Future<void> selectMeadowPatch(WidgetTester tester) async {
    await tapVisible(tester, find.text('Meadow Patch'));
    await tester.pumpAndSettle();
  }

  /// Waits (in real milliseconds) for the dispatch's file I/O to land. Must
  /// run inside `runAsync`, like every real-I/O wait in this suite.
  Future<void> until(bool Function() condition) async {
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue);
  }

  /// Waits for a dispatch that was STARTED BY A TAP — i.e. inside the test
  /// harness's fake-async zone. Its awaits resume as fake-zone microtasks, so
  /// the real-I/O wait (`runAsync`) must be interleaved with pumps that flush
  /// them; a bare `runAsync` loop would watch the condition forever while the
  /// continuation sits queued. Same shape `inventory_equip_test` uses.
  Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(condition(), isTrue);
  }

  testWidgets('the quantity selector renders, quotes the total, and clamps '
      'to what banked steps afford', (WidgetTester tester) async {
    final FakeTiming fake = FakeTiming();
    // 400 banked at 80 a gather affords exactly five.
    await pumpFunded(tester, fake, 400);
    await selectMeadowPatch(tester);

    expect(find.text('Gather ×1 — 80 steps'), findsOneWidget);
    expect(find.textContaining('1 × 80 = 80 steps'), findsOneWidget);

    await tapVisible(tester, find.text('×5'));
    expect(find.text('Gather ×5 — 400 steps'), findsOneWidget);
    expect(find.textContaining('5 × 80 = 400 steps'), findsOneWidget);

    // ×10 is not affordable: the selection clamps and the honest number stays
    // visible — the UI never implies a queue the balance cannot complete.
    await tapVisible(tester, find.text('×10'));
    expect(find.text('Gather ×5 — 400 steps'), findsOneWidget);
    expect(find.text('Gather ×10 — 800 steps'), findsNothing);

    // The stepper cannot climb past the affordable count either.
    await tapVisible(tester, find.text('+'));
    expect(find.text('Gather ×5 — 400 steps'), findsOneWidget);

    await tapVisible(tester, find.text('−'));
    expect(find.text('Gather ×4 — 320 steps'), findsOneWidget);
    expect(find.textContaining('4 × 80 = 320 steps'), findsOneWidget);
  });

  testWidgets('stop before any completion returns the card to idle with '
      'nothing spent and nothing granted', (WidgetTester tester) async {
    final FakeTiming fake = FakeTiming();
    final StrideSession session = await pumpFunded(tester, fake, 1000);
    await selectMeadowPatch(tester);

    await tapVisible(tester, find.text('×5'));
    await tapVisible(tester, find.text('Gather ×5 — 400 steps'));

    // The active panel replaces the gather control immediately; the durable
    // queue commits under real async (`DECISIONS/0022` §5).
    expect(find.text('Gathering 0 / 5'), findsOneWidget);
    expect(find.text('Stop gathering'), findsOneWidget);
    expect(find.text('48s'), findsOneWidget);
    expect(find.textContaining('Gather ×'), findsNothing);
    await pumpUntil(
      tester,
      () => session.activityQueue != null && !session.isBusy,
    );

    final ActivityController activity = tester
        .widget<ActivityScope>(find.byType(ActivityScope))
        .notifier!;
    await tapVisible(tester, find.text('Stop gathering'));
    // The stop's commit is real I/O too; wait for the presentation to settle.
    await pumpUntil(
      tester,
      () => session.activityQueue == null && !activity.active,
    );
    await tester.pumpAndSettle();

    expect(find.text('Gathering 0 / 5'), findsNothing);
    expect(find.text('Gather ×5 — 400 steps'), findsOneWidget);
    expect(session.totalSpent, 0, reason: 'nothing completed, nothing spent');
    expect(session.inventoryCount(kHerb), 0);
  });

  testWidgets('each completion updates the counter and the cumulative gains '
      'without a modal, and stop keeps what completed', (
    WidgetTester tester,
  ) async {
    final FakeTiming fake = FakeTiming();
    final StrideSession session = await pumpFunded(tester, fake, 1000);
    await selectMeadowPatch(tester);

    await tapVisible(tester, find.text('×10'));
    await tapVisible(tester, find.text('Gather ×10 — 800 steps'));
    expect(find.text('Gathering 0 / 10'), findsOneWidget);
    // The durable queue's commit is real file I/O; let it land before the
    // clock moves, so the anchor is the moment the player saw the bar start.
    await pumpUntil(
      tester,
      () => session.activityQueue != null && !session.isBusy,
    );

    // The app's own controller, read back through its scope so the wait
    // condition is the completion itself — the inventory moves inside the
    // command, a beat before the controller counts it.
    final ActivityController activity = tester
        .widget<ActivityScope>(find.byType(ActivityScope))
        .notifier!;

    // First repetition: advance the fake clock inside runAsync so the
    // dispatch's real file I/O can complete.
    await tester.runAsync(() async {
      fake.advance(const Duration(seconds: 48));
      await until(() => activity.completed == 1);
    });
    await tester.pump();

    expect(session.inventoryCount(kHerb), 1);
    expect(find.text('Gathering 1 / 10'), findsOneWidget);
    expect(find.text('Meadow Herb gained: 1'), findsOneWidget);
    expect(find.text('+10 Foraging XP'), findsOneWidget);
    expect(
      find.text('Stop gathering'),
      findsOneWidget,
      reason: 'the loop was not interrupted by the completion',
    );

    // Second repetition accumulates.
    await tester.runAsync(() async {
      fake.advance(const Duration(seconds: 48));
      await until(() => activity.completed == 2);
    });
    await tester.pump();
    expect(session.inventoryCount(kHerb), 2);

    expect(find.text('Gathering 2 / 10'), findsOneWidget);
    expect(find.text('Meadow Herb gained: 2'), findsOneWidget);
    expect(find.text('+20 Foraging XP'), findsOneWidget);

    // Stop mid-third: the two completed repetitions stay committed, and the
    // summary strip reports them on the idle card.
    await tapVisible(tester, find.text('Stop gathering'));
    await pumpUntil(
      tester,
      () => session.activityQueue == null && !activity.active,
    );
    await tester.pumpAndSettle();

    expect(session.totalSpent, 160, reason: 'exactly the two completions');
    expect(session.inventoryCount(kHerb), 2);
    expect(find.textContaining('Gather ×'), findsOneWidget);
    expect(find.text('Meadow Herb ×2'), findsOneWidget);
  });
}
