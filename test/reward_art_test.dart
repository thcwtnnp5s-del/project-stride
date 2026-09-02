/// The reward marks are on the screen, and say nothing twice (VAWO01).
///
/// The round exists because the universal result card had no authored art of
/// its own: a Bronze Sword and a bowl of Herb Broth were the same picture with
/// different words. These hold the two properties that could regress quietly —
/// that the escalation between an ordinary result and a notable one is
/// *visible*, and that none of the new art reaches a screen reader, which
/// already hears every one of these facts in words.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/activity_result.dart';
import 'package:stride/ui/components/pixel_asset.dart';
import 'package:stride/ui/icons/reward_art.dart';
import 'package:stride_core/stride_core.dart' show ContentId, Rarity;

ActivityResult _result({Rarity? rarity, int bonus = 0, int xp = 0}) =>
    ActivityResult(
      verb: 'FORGED',
      itemId: ContentId.unchecked('item.bronze_ingot'),
      itemName: 'Bronze Sword',
      quantity: 1,
      bonusQuantity: bonus,
      skill: ContentId.unchecked('skill.smithing'),
      skillName: 'Smithing',
      xp: xp,
      rarity: rarity,
    );

Future<void> _pump(WidgetTester tester, ActivityResult r) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: ActivityResultCard(result: r)),
  ),
);

List<String> _art(WidgetTester tester) => tester
    .widgetList<PixelAsset>(find.byType(PixelAsset))
    .map((PixelAsset p) => p.assetPath)
    .toList();

void main() {
  test('every mark the table names is packaged', () {
    for (final String path in RewardArt.all) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: '$path is named but not packaged',
      );
    }
    // No two entries point at one drawing: a duplicated path would mean two
    // different payoffs wearing the same mark, which is the failure the round
    // was fixing on the item icons.
    expect(RewardArt.all.toSet(), hasLength(RewardArt.all.length));
  });

  testWidgets('an ordinary result wears no ornament', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _result(rarity: Rarity.common, xp: 12));
    expect(
      _art(tester),
      isNot(contains(RewardArt.ornamentCorner)),
      reason: 'a common result must stay the plain card',
    );
    // The XP mark is not part of the escalation — it belongs to the fact, and
    // an ordinary result states that fact too.
    expect(_art(tester), contains(RewardArt.markExp));
  });

  testWidgets('a notable result gains the bracket and its bonus mark', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _result(rarity: Rarity.uncommon, bonus: 1, xp: 140));
    final List<String> art = _art(tester);
    expect(
      art.where((String a) => a == RewardArt.ornamentCorner),
      hasLength(2),
      reason: 'two corners, from one authored asset rotated',
    );
    expect(art, contains(RewardArt.markBonusYield));
    expect(art, contains(RewardArt.markExp));
  });

  testWidgets('a bonus with no rarity is still notable', (
    WidgetTester tester,
  ) async {
    // `notable` is a proc *or* uncommon-and-up; a common item that procced a
    // bonus is a moment too, and the card has to show it.
    await _pump(tester, _result(rarity: Rarity.common, bonus: 2, xp: 30));
    expect(_art(tester), contains(RewardArt.ornamentCorner));
  });

  testWidgets('none of the new art is announced', (WidgetTester tester) async {
    // Every mark restates something the words beside it already say. A screen
    // reader hearing both would hear the card twice.
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester, _result(rarity: Rarity.uncommon, bonus: 1, xp: 140));
    for (final Element e in find.byType(PixelAsset).evaluate()) {
      final PixelAsset asset = e.widget as PixelAsset;
      if (!RewardArt.all.contains(asset.assetPath)) continue;
      expect(
        find.ancestor(
          of: find.byWidget(asset),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
        reason: '${asset.assetPath} is not excluded from semantics',
      );
    }
    handle.dispose();
  });
}
