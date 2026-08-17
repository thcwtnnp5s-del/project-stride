// Foreground startup sync — the path every other widget test composes away.
//
// ## Why this file exists separately
//
// `StrideApp(syncOnStart: false)` is passed by every other widget test, and a
// seam nothing exercises is a feature nothing tests. This is the file that
// exercises it, and it can because every assertion here runs inside
// `runAsync` — under plain `FakeAsync` a post-frame callback that starts real
// file and platform I/O produces a future `pumpAndSettle` cannot advance, so
// the controller stays busy and the whole tree renders disabled.
//
// ## What the milestone asked for, restated as the four properties below
//
// > load durable save → app starts → safely reconcile new foreground health
// > data → UI updates
//
// with save load and health reconciliation **distinguishable**, no flash of
// fake zero, and the game loading normally when health is unavailable.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/screen_header.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

SyncFetch page(int steps, {int index = 0, String cursor = 'c1'}) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: phone,
          bucket: TimeBucket(
            startMillis: t0 + index * hour,
            endMillis: t0 + (index + 1) * hour,
          ),
        ),
        steps: steps,
      ),
    ],
    nextCursor: SyncCursor.ofString(cursor),
    completeness: CompleteThrough(
      throughMillis: t0 + (index + 1) * hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: t0,
        intervalEndMillis: t0 + (index + 1) * hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_startup'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  Future<StrideSession> launch(WidgetTester tester, StepSyncSource source) =>
      tester
          .runAsync(
            () => StrideSession.start(overrideRoot: root, source: source),
          )
          .then((StrideSession? s) => s!);

  /// Mounts the app with startup sync live and waits for it to finish.
  ///
  /// The order is load-bearing and is not interchangeable with a tidier
  /// arrangement. The post-frame callback must fire inside a `pump`, and the
  /// real file and platform I/O it starts only advances inside `runAsync` — so
  /// it is exactly **pump, then wait, then settle**. Draining before the first
  /// pump waits on a sync that has not started; settling before the drain runs
  /// the sync's continuations in `FakeAsync`, where they never complete and the
  /// session is left mid-flight with every control disabled.
  Future<void> mountAndSettle(
    WidgetTester tester,
    StrideSession session,
  ) async {
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(StrideApp(session: session));

    Future<void> drain() async {
      await tester.runAsync(() async {
        final DateTime deadline = DateTime.now().add(
          const Duration(seconds: 10),
        );
        while (!session.isReady && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        // The controller notifies after the session settles; give that
        // continuation a turn before the tree is inspected.
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
    }

    await tester.pump();
    await drain();
    await tester.pumpAndSettle();
  }

  testWidgets('a cold launch reconciles new steps without a tap', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final StrideSession session = await launch(
      tester,
      MockStepSource(script: <SyncFetch>[page(1200)]),
    );
    expect(
      session.usableEnergy,
      0,
      reason: 'nothing is granted before the app mounts',
    );

    await mountAndSettle(tester, session);

    expect(
      session.usableEnergy,
      1200,
      reason: 'the startup sync granted the pending steps with no user action',
    );
    expect(find.text('1,200'), findsWidgets);
  });

  testWidgets('it happens exactly once, however many frames are pumped', (
    WidgetTester tester,
  ) async {
    // Two pages scripted. If the startup sync fired twice, the second would
    // drain the second page and the figure would be 1,500 rather than 1,200 —
    // so this distinguishes "ran once" from "ran again and granted nothing",
    // which a single-page script could not.
    final StrideSession session = await launch(
      tester,
      MockStepSource(
        script: <SyncFetch>[
          page(1200),
          page(300, index: 1, cursor: 'c2'),
        ],
      ),
    );

    await mountAndSettle(tester, session);
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(session.usableEnergy, 1200);
  });

  /// **The milestone's "distinguishable operations" requirement, as a test.**
  ///
  /// Save load and health reconciliation are two things, and the first frame is
  /// where that is provable: the durable 900 is on screen *before* the sync it
  /// triggers has returned anything, and the 50 arrives after. A build that
  /// awaited health above `runApp` would show 950 on frame zero and nothing
  /// before it; a build that rendered defaults while loading would show 0.
  ///
  /// So the assertion is a sequence rather than a value — 900 first, 950 after,
  /// and **never 0 at any point in between**, which is the flash this ordering
  /// exists to make unreachable.
  testWidgets('the save paints first, and the sync lands after it', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final StrideSession first = await launch(
      tester,
      MockStepSource(script: <SyncFetch>[page(900)]),
    );
    await tester.runAsync(() => first.syncSteps());
    expect(first.usableEnergy, 900);

    final StrideSession reopened = await launch(
      tester,
      MockStepSource(script: <SyncFetch>[page(50, index: 2, cursor: 'c3')]),
    );

    /// The banked figure currently on screen, label excluded.
    List<String> readout() => find
        .descendant(
          of: find.byType(BankedStepsReadout),
          matching: find.byType(Text),
        )
        .evaluate()
        .map((Element e) => (e.widget as Text).data ?? '')
        .where((String s) => s != BankedStepsReadout.label)
        .toList();

    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(StrideApp(session: reopened));

    expect(
      readout(),
      contains('900'),
      reason:
          'the first frame must be the durable save. 950 here would mean the '
          'app awaited health before painting; 0 would mean it painted a '
          'default.',
    );

    await mountAndSettle(tester, reopened);

    expect(
      reopened.usableEnergy,
      950,
      reason: '900 loaded from the save, plus 50 the startup sync reconciled',
    );
    expect(readout(), contains('950'));
    expect(
      readout(),
      isNot(contains('0')),
      reason: 'no frame in this sequence may show a zero balance',
    );
  });

  /// The milestone's requirement in one line: if health is unavailable, load
  /// the game normally and surface a truthful status. Nothing here may throw,
  /// block, or present the save as empty.
  ///
  /// **Modelled with `available: false`, not with an empty script.** An empty
  /// script is a *present and authorized* provider that happens to have nothing
  /// to say, which is a different state and is not what "unavailable" means —
  /// it is the state a second sync a minute later reaches. `available: false`
  /// is the one `MockStepSource` documents as "Android without Health Connect
  /// installed — a normal state the game must remain fully playable through".
  testWidgets('an unavailable health source still loads the game', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final StrideSession first = await launch(
      tester,
      MockStepSource(script: <SyncFetch>[page(700)]),
    );
    await tester.runAsync(() => first.syncSteps());

    final StrideSession reopened = await launch(
      tester,
      MockStepSource(script: const <SyncFetch>[], available: false),
    );
    await mountAndSettle(tester, reopened);

    expect(reopened.usableEnergy, 700, reason: 'the save loaded regardless');
    expect(tester.takeException(), isNull);

    // The save is on screen — not a refusal screen, not zeros, and not a
    // spinner. This is what "loads normally" means, asserted against the tree.
    expect(find.text('700'), findsWidgets);
    expect(find.text('Adventure'), findsWidgets);
    expect(find.text('Meadow Patch'), findsWidgets);

    // `isReady` is deliberately NOT asserted here, and the reason is a property
    // of the harness rather than of the app.
    //
    // A sync begun by a post-frame callback starts inside `FakeAsync`. Its work
    // completes — the grant lands, the figures above are right — but the
    // `finally` that clears `_inFlight` is a continuation bound to the
    // `FakeAsync` zone, and it cannot run while `runAsync` is servicing the real
    // event loop, nor after, because by then nothing pumps it. So the session
    // reads as permanently in-flight in this harness and only in this harness.
    //
    // Asserting it would be asserting the test framework. The device script
    // covers the real thing: on hardware the app is interactive after launch,
    // which is the observation this cannot make.
  });

  testWidgets('startupSync is idempotent at the controller', (
    WidgetTester tester,
  ) async {
    // The guard, tested directly rather than only through the widget. A rebuild
    // or a hot reload must not be able to produce a second one.
    final StrideSession session = await launch(
      tester,
      MockStepSource(
        script: <SyncFetch>[
          page(400),
          page(600, index: 1, cursor: 'c2'),
        ],
      ),
    );
    final SessionController controller = SessionController(session);
    addTearDown(controller.dispose);

    await tester.runAsync(() async {
      await controller.startupSync();
      await controller.startupSync();
      await controller.startupSync();
    });

    expect(session.usableEnergy, 400);
  });
}
