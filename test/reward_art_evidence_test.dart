/// Device-size evidence for the reward round.
///
/// The owner's test of this work is a comparison, not an assertion: *"crafting
/// a Bronze Sword must visually feel more significant than Herb Broth without
/// becoming casino-like."* So this renders the whole ladder at the width a
/// phone gives it, and a human decides (`RULES.md` A-3).
///
/// EPO03 (DIR-13) extends it to the six cases the brief asks to see: a common
/// gather, a rare drop, a signature drop, a masterwork, a level-up beside a
/// result, and a batch craft summary. The first four are slips
/// (`ActivityResultCard`); the last two are what the reward layer holds, and
/// they are rendered as the layer draws them.
///
/// Gated on `COMBAT_EVIDENCE_DIR` or `BOARD_EVIDENCE_DIR`; asserts only that
/// each card built. Nothing here is a golden.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/activity_result.dart';
import 'package:stride/ui/components/reward_beat.dart';
import 'package:stride/ui/components/reward_layer.dart';
import 'package:stride/ui/icons/reward_art.dart';
import 'package:stride/ui/theme/stride_theme.dart';
import 'package:stride_core/stride_core.dart' show ContentId, Rarity;

import 'support/real_font.dart';

String? get _dir =>
    Platform.environment['COMBAT_EVIDENCE_DIR'] ??
    Platform.environment['BOARD_EVIDENCE_DIR'] ??
    Platform.environment['SCREEN_EVIDENCE_DIR'];

/// Decode every raster on stage before capture, or the marks paint as holes.
Future<void> _decode(WidgetTester tester, Finder host) async {
  await tester.runAsync(() async {
    final BuildContext ctx = tester.element(host);
    for (final ImageProvider p in <ImageProvider>[
      for (final Element e in find.byType(Image).evaluate())
        (e.widget as Image).image,
    ]) {
      await precacheImage(p, ctx);
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final String? dir = _dir;
  if (dir == null || dir.isEmpty) return;
  await tester.runAsync(() async {
    final ui.Image image = await captureImage(
      find.byType(RepaintBoundary).last.evaluate().single,
    );
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    Directory(dir).createSync(recursive: true);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadRealFont);

  final Map<String, ActivityResult> slips = <String, ActivityResult>{
    // 1. A common gather. Paper, no seal, no bracket — the ordinary case,
    //    which is the one that used to read as "nothing happened".
    'common_gather': ActivityResult(
      verb: 'MINED',
      itemId: ContentId.unchecked('item.copper_ore'),
      itemName: 'Copper Ore',
      quantity: 2,
      skill: ContentId.unchecked('skill.mining'),
      skillName: 'Mining',
      xp: 12,
      rarity: Rarity.common,
    ),
    // 2. Herb Broth, the comparison the owner named.
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
    // 3. The Bronze Sword, the other half of that comparison: cloth, the
    //    bracket, the bonus line.
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
    // 4. A rare drop: warm parchment, the sack mark, and the rank's own wax.
    'rare_drop': ActivityResult(
      verb: 'FORAGED',
      itemId: ContentId.unchecked('item.gloom_silk'),
      itemName: 'Gloom Silk',
      quantity: 1,
      skill: ContentId.unchecked('skill.foraging'),
      skillName: 'Foraging',
      xp: 64,
      rarity: Rarity.rare,
    ),
    // 5. A legendary, so the third wax tone is on the record beside the first.
    'legendary_drop': ActivityResult(
      verb: 'CHOPPED',
      itemId: ContentId.unchecked('item.oak_log'),
      itemName: 'Heartwood Bough',
      quantity: 1,
      skill: ContentId.unchecked('skill.woodcutting'),
      skillName: 'Woodcutting',
      xp: 220,
      rarity: Rarity.legendary,
    ),
    // 6. The batch craft summary: eight planks, one tally gate and the
    //    figure in the right margin.
    'batch_craft': ActivityResult(
      verb: 'CRAFTING COMPLETE',
      itemId: ContentId.unchecked('item.oak_plank'),
      itemName: 'Oak Plank',
      quantity: 8,
      skillName: 'Woodcutting',
      xp: 96,
      rarity: Rarity.common,
    ),
  };

  for (final MapEntry<String, ActivityResult> c in slips.entries) {
    testWidgets('the result slip for ${c.key} at phone width', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(393, 400);
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
      await _decode(tester, find.byType(ActivityResultCard));
      expect(find.byType(ActivityResultCard), findsOneWidget);
      await _capture(tester, 'result_${c.key}');
    });
  }

  // The two banner seals and the level-up are the layer's, not the slip's.
  final Map<String, ({String? emblem, Size size, List<Widget> beats})> layers =
      <String, ({String? emblem, Size size, List<Widget> beats})>{
        'signature_drop': (
          emblem: RewardArt.sealSignature,
          size: const Size(96, 48),
          beats: <Widget>[
            const RewardBeat(
              tier: RewardTier.major,
              eyebrow: 'SIGNATURE FIND',
              title: 'Warden’s Cloakpin',
              rarity: Rarity.epic,
              lines: <String>['One of a kind. Nothing else drops it.'],
            ),
          ],
        ),
        'masterwork_craft': (
          emblem: RewardArt.sealMasterwork,
          size: const Size(96, 48),
          beats: <Widget>[
            const RewardBeat(
              tier: RewardTier.major,
              eyebrow: 'MASTERWORK',
              title: 'Hornbound Bronze Axe',
              rarity: Rarity.epic,
              lines: <String>['The best this bench can make.'],
            ),
          ],
        ),
        'level_up_with_result': (
          emblem: null,
          size: const Size(48, 48),
          beats: <Widget>[
            const RewardBeat(
              tier: RewardTier.medium,
              eyebrow: 'FORGED',
              title: 'Bronze Sword',
              rarity: Rarity.uncommon,
            ),
            LevelUpCard(
              name: 'Smithing',
              level: 5,
              skill: ContentId.unchecked('skill.smithing'),
              unlocked: const <String>['Hornbound Bronze Axe'],
              why: 'Heavier stock can be worked.',
            ),
          ],
        ),
      };

  for (final MapEntry<String, ({String? emblem, Size size, List<Widget> beats})>
      c
      in layers.entries) {
    testWidgets('the reward layer for ${c.key} at phone size', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: strideTheme(),
          home: Scaffold(
            body: RepaintBoundary(
              child: RewardLayer(
                tier: RewardTier.major,
                emblem: c.value.emblem,
                emblemSize: c.value.size,
                beats: c.value.beats,
                onContinue: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _decode(tester, find.byType(RewardLayer));
      expect(find.byType(RewardLayer), findsOneWidget);
      await _capture(tester, 'layer_${c.key}');
    });
  }
}
