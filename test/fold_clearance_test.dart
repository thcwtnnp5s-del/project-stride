/// Where the primary action lands relative to the fold, on real viewports with
/// real safe-area insets.
///
/// ## Why this exists
///
/// The gather control is the only game action on the Adventure screen. Whether
/// a player sees it without scrolling is a **property of the composition**, and
/// until this file nothing in the repository measured it — so it was estimated,
/// in a comment, by adding up the heights of the widgets above it.
///
/// The estimate was wrong, and the way it was wrong is the reason this is a
/// test rather than a better comment. Growing the activity stage from 145 to
/// 180 dp was expected to cost about 35 dp of clearance. On a 375 dp phone it
/// cost **95**, because at that width a 180 dp stage plus its gap leaves 127 dp
/// for a title that measures 137.3 — so `_StageAndIdentity` correctly refuses to
/// crush the title, falls back to stacking, and the identity's ~94 dp lands on
/// top of the button.
///
/// That is a **cliff, not a slope**, and no amount of arithmetic in a comment
/// would have found it. `MISTAKES.md` M-06 again: assert the property, do not
/// estimate it.
///
/// ## What the harness cannot do, and how this works around it
///
/// `flutter test` supplies **zero** safe-area insets, so a fold measured under
/// it is 90–100 dp more generous than any phone. Every case below therefore
/// supplies the real device's insets explicitly. The goldens cannot do this and
/// are not evidence about the fold.
///
/// It also has no real font, and the layout branch under test is decided by
/// **measuring a string** — so `loadRealFont()` is mandatory here for the same
/// reason it is in `ui_responsive_test.dart`.
///
/// ## This file pins an accepted limitation, deliberately
///
/// At 375 dp and below the button is **not** above the fold, and that is the
/// owner's accepted trade: a crushed node title is worse than a scroll. Those
/// cases are asserted as *stacked and reachable* rather than quietly excluded,
/// so the limitation cannot change — in either direction — without someone
/// reading this note.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/data_display.dart';
import 'package:stride/ui/components/sprite_animation.dart';
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
  bool expectSideBySide,
});

/// The device matrix. Insets are the platform's, not invented: 44 pt on the
/// notch generation, 47 on the 12–14 family, 59 where the Dynamic Island sits,
/// and 34 for the home indicator throughout.
const List<Device> kDevices = <Device>[
  (
    name: 'iPhone X / XS / 11 Pro',
    width: 375,
    height: 812,
    top: 44,
    bottom: 34,
    expectSideBySide: false,
  ),
  (
    name: 'iPhone 12 / 13 / 14',
    width: 390,
    height: 844,
    top: 47,
    bottom: 34,
    expectSideBySide: true,
  ),
  (
    name: 'iPhone 14 / 15 Pro',
    width: 393,
    height: 852,
    top: 59,
    bottom: 34,
    expectSideBySide: true,
  ),
  (
    name: 'iPhone 15 Pro Max',
    width: 430,
    height: 932,
    top: 59,
    bottom: 34,
    expectSideBySide: true,
  ),
  (
    name: 'small Android',
    width: 360,
    height: 780,
    top: 24,
    bottom: 0,
    expectSideBySide: false,
  ),
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
      // not content. Taken from the laid-out bar rather than computed from the
      // screen height, so a change to the bar's own geometry moves it here too.
      final double fold = tester.getTopLeft(find.byType(StrideTabBar)).dy;

      // The queue selector changed the label; the fold property is unchanged
      // and the selector deliberately lives in the identity column beside the
      // stage so it costs no height above the button — the arithmetic in
      // `gather_node_card.dart` still holds.
      final Finder button = find.widgetWithText(
        StrideButton,
        'Gather ×1 — 80 steps',
      );
      expect(button, findsOneWidget, reason: 'the game action must exist');

      // Which branch `_StageAndIdentity` took, read off the geometry rather
      // than off the widget tree: side by side means the node's title starts
      // to the right of the figure, stacked means it sits below it.
      final Rect title = tester.getRect(find.text('Meadow Patch'));
      final Rect figure = tester.getRect(find.byType(SpriteAnimation));
      final bool sideBySide = title.left >= figure.right;

      expect(
        sideBySide,
        d.expectSideBySide,
        reason: d.expectSideBySide
            ? 'the identity must sit beside the stage here; if this flips, the '
                  'card grew or the stage did, and the gather control just fell '
                  'roughly 94 dp — see this file\'s header'
            : 'at ${d.width.toInt()} dp there is not enough width for both, and '
                  'stacking is the accepted trade: a crushed node title is worse '
                  'than a scroll',
      );

      final double clearance = fold - tester.getRect(button).bottom;

      if (d.expectSideBySide) {
        // THE PROPERTY. The only game action on the screen is fully visible
        // without scrolling.
        expect(
          clearance,
          greaterThanOrEqualTo(0),
          reason:
              'the gather control is ${(-clearance).toStringAsFixed(1)} dp '
              'below the fold on ${d.name}. It is the screen\'s only action '
              'and a player must not have to scroll to find it.',
        );
      } else {
        // The accepted limitation, asserted rather than excluded. It must stay
        // reachable, and if it ever becomes visible without scrolling that is
        // good news that this file should stop claiming otherwise.
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(button).bottom,
          lessThanOrEqualTo(fold + 0.5),
          reason: 'the control must at least be reachable by scrolling',
        );
      }
    });
  }
}
