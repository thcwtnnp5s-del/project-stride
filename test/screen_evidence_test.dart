// The screen-evidence harness (PLAYABLE_POLISH_01): the real app at phone
// width, driven into the states a polish pass needs to *look at* — a gear
// recipe open on Craft, the Inventory with equipment, the Character tab —
// and written to `SCREEN_EVIDENCE_DIR` when that variable is set. Silent
// without it, and then a mount-and-drive smoke test. The same pattern as
// `stage_evidence_test.dart` and `board_reward_layer_test.dart`, for the
// same reason (MISTAKES.md M-06): a golden is regression evidence between
// revisions; this is for seeing.
//
// Usage:
//   SCREEN_EVIDENCE_DIR=/tmp/screens flutter test test/screen_evidence_test.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/components/stride_tab_bar.dart';
import 'package:stride/ui/stride_app.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

import 'support/real_font.dart';

final ContentId kNode = ContentId.unchecked('resource_node.meadow_patch');
final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId tunic = ContentId.unchecked('item.traveler_tunic');

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
  final String? dir = Platform.environment['SCREEN_EVIDENCE_DIR'];

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_screens'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  Future<void> settleImages(WidgetTester tester) async {
    await tester.runAsync(() async {
      for (final Element e in find.byType(Image).evaluate()) {
        final Image image = e.widget as Image;
        await precacheImage(image.image, e);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (dir == null) return;
    await settleImages(tester);
    await tester.runAsync(() async {
      final ui.Image image = await captureImage(
        find.byType(StrideApp).evaluate().single,
      );
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<void> open(WidgetTester tester, String tab) async {
    await tester.tap(
      find.descendant(of: find.byType(StrideTabBar), matching: find.text(tab)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the polished surfaces, driven into their telling states', (
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
          script: <SyncFetch>[SyncFetch(const NoChangeSync()), page(12480)],
        ),
      );
      await s.syncSteps();
      await s.syncSteps();
      for (int i = 0; i < 3; i++) {
        await s.gather(kNode);
      }
      await s.equip(trainingSword);
      await s.equip(tunic);
      return s;
    }))!;

    await tester.pumpWidget(StrideApp(session: session, syncOnStart: false));
    await tester.pumpAndSettle();
    await capture(tester, 'adventure');

    await open(tester, 'Inventory');
    await capture(tester, 'inventory');

    await open(tester, 'Craft');
    await tester.tap(find.text('Bronze Sword').first);
    await tester.pumpAndSettle();
    expect(find.text('ATTACK'), findsOneWidget);
    expect(find.text('UPGRADE'), findsOneWidget);
    await capture(tester, 'craft_gear_open');

    await open(tester, 'Character');
    await capture(tester, 'character');
    // The foot of the sheet: the owner's playtest controls, and the
    // confirmation they open (`DECISIONS/0025`).
    await tester.dragUntilVisible(
      find.text('Reset walking baseline'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start a fresh playtest'));
    await tester.pumpAndSettle();
    expect(find.text('START A FRESH PLAYTEST?'), findsOneWidget);
    await capture(tester, 'character_playtest_confirm');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await open(tester, 'Skills');
    await capture(tester, 'skills');
  });
}
