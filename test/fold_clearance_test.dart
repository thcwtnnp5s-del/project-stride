/// Where the Adventure screen's answers land relative to the fold, on real
/// viewports with real safe-area insets.
///
/// ## What this asserts since the Adventure restructure
///
/// PRESENTATION_WORLD_REWARD_FEEL_01 §4–§6 replaced the per-node gather cards
/// (each ~380 dp with its own stage) with one location stage and a compact
/// activity list. The fold property changed shape with it:
///
/// 1. **"What can I do here" is answered without scrolling.** Every activity
///    row is fully above the fold on every supported viewport, idle. The old
///    test asserted this of the one gather button; the list is now the
///    screen's first answer.
/// 2. **Selecting an activity brings its action within one scroll.** The
///    expanded detail may legitimately cross the fold on small phones — the
///    accepted trade is a scroll, never a hidden or clipped control — so the
///    gather button is asserted *reachable and whole*, not necessarily
///    above the fold.
///
/// ## What the harness cannot do, and how this works around it
///
/// `flutter test` supplies **zero** safe-area insets, so a fold measured
/// under it is 90–100 dp more generous than any phone. Every case below
/// therefore supplies the real device's insets explicitly. It also has no
/// real font, so `loadRealFont()` is mandatory (M-06).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/stride_tab_bar.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/real_font.dart';

final ContentId kNode = ContentId.unchecked('resource_node.meadow_patch');
final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

/// A supported viewport, with the insets the real device reports.
typedef Device = ({
  String name,
  double width,
  double height,
  double top,
  double bottom,
});

/// The device matrix. Insets are the platform's, not invented: 44 pt on the
/// notch generation, 47 on the 12–14 family, 59 where the Dynamic Island
/// sits, and 34 for the home indicator throughout.
const List<Device> kDevices = <Device>[
  (name: 'iPhone X / XS / 11 Pro', width: 375, height: 812, top: 44, bottom: 34),
  (name: 'iPhone 12 / 13 / 14', width: 390, height: 844, top: 47, bottom: 34),
  (name: 'iPhone 14 / 15 Pro', width: 393, height: 852, top: 59, bottom: 34),
  (name: 'iPhone 15 Pro Max', width: 430, height: 932, top: 59, bottom: 34),
  (name: 'small Android', width: 360, height: 780, top: 24, bottom: 0),
];

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

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_fold'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  for (final Device d in kDevices) {
    testWidgets('${d.name} — ${d.width.toInt()}x${d.height.toInt()}', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = Size(d.width * 3, d.height * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));

      // A real save at the device-acceptance figure, so the header carries a
      // seven-character value and the walking band is at its true width.
      final StrideSession session = (await tester.runAsync(
        () => StrideSession.start(
          overrideRoot: root,
          source: MockStepSource(script: <SyncFetch>[page(455371)]),
        ),
      ))!;
      await tester.runAsync(() => session.syncSteps());
      await tester.runAsync(() => session.gather(kNode));

      final EdgeInsets insets = EdgeInsets.only(top: d.top, bottom: d.bottom);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(viewPadding: insets, padding: insets),
          child: StrideApp(session: session, syncOnStart: false),
        ),
      );
      await tester.pumpAndSettle();

      // The fold is the tab bar's top edge: below it the player sees chrome,
      // not content. Taken from the laid-out bar rather than computed from
      // the screen height, so a change to the bar's own geometry moves it
      // here too.
      final double fold = tester.getTopLeft(find.byType(StrideTabBar)).dy;

      // PROPERTY 1 — every activity row is above the fold, idle. Haven's
      // Rest hosts the Meadow Patch; its row is the screen's first answer to
      // "what can I do here" and must be whole without scrolling.
      final Finder row = find.text('Meadow Patch');
      expect(row, findsOneWidget, reason: 'the activity row must exist');
      expect(
        tester.getRect(row).bottom,
        lessThanOrEqualTo(fold),
        reason:
            'the activity list must answer "what can I do here" without '
            'scrolling on ${d.name}',
      );

      // No gather control exists while nothing is selected — the compact
      // list, not a wall of buttons, is the redesign's point.
      expect(find.textContaining('Gather ×'), findsNothing);

      // PROPERTY 2 — selecting expands the detail, and its action is
      // reachable and whole. The detail may cross the fold on small phones;
      // the accepted trade is a scroll, never a hidden control.
      await tester.tap(row);
      await tester.pumpAndSettle();
      final Finder button = find.widgetWithText(
        StrideButton,
        'Gather ×1 — 80 steps',
      );
      expect(button, findsOneWidget, reason: 'the game action must exist');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(button).bottom,
        lessThanOrEqualTo(fold + 0.5),
        reason: 'the gather control must be reachable and whole on ${d.name}',
      );
    });
  }
}
