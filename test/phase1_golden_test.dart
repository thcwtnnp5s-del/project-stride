/// Renders each Phase 1 screen at the reference viewport and writes it as a
/// golden.
///
/// **These are regression goldens between Flutter revisions, not a comparison
/// against the HTML prototype.** A browser and Skia differ on font metrics,
/// hinting, subpixel placement and antialiasing; chasing that difference is the
/// unbounded pixel-hunt `MISTAKES.md` M-01 records. Perceptual parity is judged
/// by a human against these renders, once per screen.
///
/// One viewport deliberately. A golden per screen per width is four times the
/// maintenance for a fraction of the signal, and `phase1_ui_test.dart` already
/// covers 320 / 360 / 375 / 393 / 430 for overflow.
///
/// Regenerate with:
///   flutter test test/phase1_golden_test.dart --update-goldens
@Tags(<String>['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

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

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_golden'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows handle lag.
    }
  });

  testWidgets('the four Phase 1 screens at 393 x 852', (
    WidgetTester tester,
  ) async {
    // The reference viewport the approved renders were authored at. DPR 1 so
    // the golden's pixel dimensions equal its logical dimensions and a reviewer
    // comparing it to the 393x852 HTML render is comparing like with like.
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final StrideSession session = (await tester.runAsync(
      () => StrideSession.start(
        overrideRoot: root,
        source: MockStepSource(script: <SyncFetch>[page(12480)]),
      ),
    ))!;
    await tester.runAsync(() => session.syncSteps());
    await tester.runAsync(() => session.gather(kNode));
    await tester.runAsync(() => session.gather(kNode));

    await tester.pumpWidget(StrideApp(session: session));
    await tester.pumpAndSettle();

    /// Decodes every `Image` currently in the tree, then settles.
    ///
    /// `pumpAndSettle` does not wait for asset decode — it drives the frame
    /// scheduler, and decoding happens off it. Without this, a golden captures
    /// whichever sprites happened to win the race, which looks exactly like a
    /// missing-asset bug and is not one.
    Future<void> settleImages() async {
      await tester.runAsync(() async {
        for (final Element e in find.byType(Image).evaluate()) {
          final Image image = e.widget as Image;
          await precacheImage(image.image, e);
        }
      });
      await tester.pumpAndSettle();
    }

    await settleImages();
    await expectLater(
      find.byType(StrideApp),
      matchesGoldenFile('goldens/phase1_adventure.png'),
    );

    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    await settleImages();
    await expectLater(
      find.byType(StrideApp),
      matchesGoldenFile('goldens/phase1_inventory.png'),
    );

    await tester.tap(find.text('Character'));
    await tester.pumpAndSettle();
    await settleImages();
    await expectLater(
      find.byType(StrideApp),
      matchesGoldenFile('goldens/phase1_character.png'),
    );

    await tester.tap(find.text('World'));
    await tester.pumpAndSettle();
    await settleImages();
    await expectLater(
      find.byType(StrideApp),
      matchesGoldenFile('goldens/phase1_world.png'),
    );
  });
}
