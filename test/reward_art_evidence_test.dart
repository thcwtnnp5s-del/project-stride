/// Device-size evidence for the VAWO01 reward round.
///
/// The owner's test of this work is a comparison, not an assertion: *"crafting
/// a Bronze Sword must visually feel more significant than Herb Broth without
/// becoming casino-like."* So this renders both, side by side, at the width
/// they occupy on a phone, and a human decides (`RULES.md` A-3).
///
/// Gated on `COMBAT_EVIDENCE_DIR`; asserts only that each card built.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/activity_result.dart';
import 'package:stride/ui/theme/stride_theme.dart';
import 'package:stride_core/stride_core.dart' show ContentId, Rarity;

import 'support/real_font.dart';

void main() {
  setUpAll(loadRealFont);

  final String? dir = Platform.environment['COMBAT_EVIDENCE_DIR'];

  final Map<String, ActivityResult> cases = <String, ActivityResult>{
    'broth': ActivityResult(
      verb: 'COOKED',
      itemId: ContentId.unchecked('item.meadow_herb'),
      itemName: 'Herb Broth',
      quantity: 1,
      skill: ContentId.unchecked('skill.cooking'),
      skillName: 'Cooking',
      xp: 12,
      rarity: Rarity.common,
    ),
    'bronze_sword': ActivityResult(
      verb: 'FORGED',
      itemId: ContentId.unchecked('item.bronze_ingot'),
      itemName: 'Bronze Sword',
      quantity: 1,
      bonusQuantity: 1,
      skill: ContentId.unchecked('skill.smithing'),
      skillName: 'Smithing',
      xp: 140,
      rarity: Rarity.uncommon,
    ),
  };

  for (final MapEntry<String, ActivityResult> c in cases.entries) {
    testWidgets('the result card for ${c.key} at phone width', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(393, 300);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: strideTheme(),
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  child: ActivityResultCard(result: c.value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Decode before capture, or the marks paint as holes.
      await tester.runAsync(() async {
        final BuildContext ctx = tester.element(
          find.byType(ActivityResultCard),
        );
        for (final ImageProvider p in <ImageProvider>[
          for (final Element e in find.byType(Image).evaluate())
            (e.widget as Image).image,
        ]) {
          await precacheImage(p, ctx);
        }
      });
      await tester.pumpAndSettle();
      expect(find.byType(ActivityResultCard), findsOneWidget);

      if (dir == null || dir.isEmpty) return;
      await tester.runAsync(() async {
        final ui.Image image = await captureImage(
          find.byType(RepaintBoundary).last.evaluate().single,
        );
        final ByteData? bytes = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        Directory(dir).createSync(recursive: true);
        File(
          '$dir/result_${c.key}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }
}
