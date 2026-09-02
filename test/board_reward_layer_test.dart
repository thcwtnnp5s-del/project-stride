// A delivery is a payoff, and a payoff is its own plane
// (PLAYABLE_POLISH_01 §3–§4).
//
// The owner's device found a completed contract reading as text embedded in
// the board. Now the board stays where it is and the reward rises over it:
// this file hands in Herbal Supplies through the real app, expects the
// reward layer — the eyebrow, the item row, the experience, Continue — and
// expects the board beneath to have moved on without it. With
// `BOARD_EVIDENCE_DIR` set it also writes the board before, the open job,
// and the layer, so the result can be looked at rather than counted
// (MISTAKES.md M-06).

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/reward_layer.dart';
import 'package:stride/ui/state/session_controller.dart';
import 'package:stride/ui/state/session_scope.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/real_font.dart';

final ContentId kNode = ContentId.unchecked('resource_node.meadow_patch');

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
  setUpAll(loadRealFont);
  final String? dir = Platform.environment['BOARD_EVIDENCE_DIR'];

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_board_rl'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (dir == null) return;
    await tester.runAsync(() async {
      final ui.Image image = await captureImage(
        find.byType(MaterialApp).evaluate().single,
      );
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  SessionController controller() {
    final Element scope = find.byType(SessionScope).evaluate().first;
    return (scope.widget as SessionScope).notifier!;
  }

  /// Taps and waits for the command's real file I/O to land (it never
  /// completes under FakeAsync alone), then lets the layer settle.
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    for (int i = 0; i < 500; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
      if (!controller().busy && i > 0) break;
    }
    expect(controller().busy, isFalse, reason: 'the command never returned');
  }

  testWidgets('handing in an order raises the reward layer over the board', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

    final StrideSession session = (await tester.runAsync(() async {
      final StrideSession s = await StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(
          script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(3000)],
        ),
      );
      await s.syncSteps();
      await s.syncSteps();
      for (int i = 0; i < 5; i++) {
        final ActionReport r = await s.gather(kNode);
        expect(r.succeeded, isTrue, reason: '${r.rejection}');
      }
      return s;
    }))!;

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();
    // Scrolled to first, and this is not a workaround for a missing control.
    // The Adventure screen is a ListView, and the Goal Board entry sits below
    // the summary card near the bottom of it; since FMPO02 put the trail band
    // over the expedition kit and the ground band under the encounter list,
    // 393 x 852 no longer holds everything above the tab bar. A widget the
    // player reaches by scrolling is one `tester.tap` cannot reach at all —
    // it taps a coordinate, and an unscrolled coordinate lands on the tab bar.
    // The claim this test makes is about the reward layer, and it is unchanged.
    await tester.ensureVisible(find.text('Goal Board').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goal Board').first);
    await tester.pumpAndSettle();
    await capture(tester, 'board_closed');

    await tester.tap(find.text('Herbal Supplies'));
    await tester.pumpAndSettle();
    expect(find.text('Deliver'), findsOneWidget);
    await capture(tester, 'board_open');

    await tapAndSettle(tester, find.text('Deliver'));
    await capture(tester, 'board_layer');

    // The layer, above the board: the eyebrow, the reward, the experience,
    // and one way out.
    expect(find.byType(RewardLayer), findsOneWidget);
    expect(find.text('ORDER DELIVERED'), findsOneWidget);
    expect(find.text('Herb Broth'), findsOneWidget);
    expect(find.text('+30 Foraging XP'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // The board beneath did not print the result into itself.
    expect(find.text('HERBAL SUPPLIES COMPLETE'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byType(RewardLayer), findsNothing);
    expect(find.text('CLOSE'), findsOneWidget, reason: 'still on the board');
  });
}
