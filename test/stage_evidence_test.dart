// The work-stage evidence harness (PLAYABLE_EXPERIENCE_REFINEMENT_01 §7,
// §44): renders the REAL `LocationStage` in work mode — backdrop, prop, the
// profession loop — at phone width, and writes every loop frame to
// `STAGE_EVIDENCE_DIR` when that variable is set, so tool/resource contact,
// ground-line agreement and the locked selection can be inspected in context
// rather than as isolated sprite strips. Silent without the variable, and
// then only a mount-and-pump smoke test of the five work compositions the
// brief names. The same pattern as `combat_golden_test.dart`'s
// `COMBAT_EVIDENCE_DIR`.
//
// Usage:
//   STAGE_EVIDENCE_DIR=/tmp/stage flutter test test/stage_evidence_test.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride/ui/icons/pixel_icons.dart';
import 'package:stride/ui/screens/adventure/location_stage.dart';
import 'package:stride/ui/theme/stride_theme.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final String? dir = Platform.environment['STAGE_EVIDENCE_DIR'];

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_stagecap'));
  tearDown(() {
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows handle lag.
    }
  });

  Future<void> capture(WidgetTester tester, String name) async {
    if (dir == null) return;
    await tester.runAsync(() async {
      final ui.Image image = await captureImage(
        find.byType(LocationStage).evaluate().single,
      );
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Directory(dir).createSync(recursive: true);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  for (final (String tag, String nodeId, String locId, bool locked) in <(String, String, String, bool)>[
    ('mine_copper', 'resource_node.copper_seam', 'location.stonefall_mine', false),
    ('mine_tin', 'resource_node.tin_seam', 'location.stonefall_mine', false),
    ('mine_hardened_locked', 'resource_node.hardened_copper_seam', 'location.stonefall_mine', true),
    ('woods_oak', 'resource_node.oak_stand', 'location.whispering_woods', false),
    ('haven_meadow', 'resource_node.meadow_patch', 'location.havens_rest', false),
  ]) {
    testWidgets('capture $tag', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final StrideSession s = (await tester.runAsync(
        () => StrideSession.start(
          overrideRoot: root,
          source: MockStepSource(script: <SyncFetch>[SyncFetch(const NoChangeSync())]),
        ),
      ))!;
      final ResourceNodeDefinition node =
          s.nodeDefinitionOf(ContentId.unchecked(nodeId))!;
      // The real location painting, not null.
      //
      // This was null, and that made the harness prove the wrong thing: the
      // work backdrop is resolved from the vignette (region x skill, VAWO01),
      // so a null vignette silently fell back to the legacy per-skill plate
      // and every captured frame showed art the app would not show. An
      // evidence harness that does not exercise the shipped path is evidence
      // of nothing.
      final String? vignette = PixelIcons.vignetteFor(ContentId.unchecked(locId));

      Widget stage({required bool active, required bool lock}) => MaterialApp(
        theme: strideTheme(),
        home: Material(
          child: Center(
            child: SizedBox(
              width: 393,
              child: LocationStage(
                locationName: locId,
                vignette: vignette,
                selectedNode: node,
                activityActive: active,
                playToken: null,
                locked: lock,
                lockReason: lock ? 'Needs a pickaxe' : null,
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(stage(active: false, lock: locked));
      await tester.runAsync(() async {
        for (final Element e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await capture(tester, '${tag}_selected');

      if (locked) return;
      await tester.pumpWidget(stage(active: true, lock: false));
      await tester.runAsync(() async {
        for (final Element e in find.byType(Image).evaluate()) {
          await precacheImage((e.widget as Image).image, e);
        }
      });
      await tester.pump();
      for (int f = 0; f < 9; f++) {
        await tester.pump(const Duration(milliseconds: 110));
        await capture(tester, '${tag}_f$f');
      }
    });
  }
}
