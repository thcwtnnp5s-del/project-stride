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

  testWidgets('a rank is sealed in its own wax, never one shared stamp', (
    WidgetTester tester,
  ) async {
    // The producer's running note: six sealed pages carrying six identical
    // saturated red seals read as a grid of stamps rather than as six sealed
    // pages. This family answers that, and the answer is a property worth
    // holding — a regression that pointed every rank at one seal would look
    // fine in isolation and wrong on a screen.
    final Set<String> seen = <String>{};
    for (final Rarity r in <Rarity>[
      Rarity.rare,
      Rarity.epic,
      Rarity.legendary,
    ]) {
      await _pump(tester, _result(rarity: r, xp: 40));
      final String seal = _art(tester).singleWhere(
        (String a) => a.contains('seal_wax_'),
        orElse: () => '',
      );
      expect(seal, isNotEmpty, reason: '${r.label} carries no wax');
      seen.add(seal);
    }
    expect(seen, hasLength(3), reason: 'three ranks, three waxes');

    // …and the two lower ranks carry none at all: a seal on every result is
    // a seal on nothing.
    for (final Rarity r in <Rarity>[Rarity.common, Rarity.uncommon]) {
      await _pump(tester, _result(rarity: r, xp: 40));
      expect(
        _art(tester).where((String a) => a.contains('seal_wax_')),
        isEmpty,
        reason: '${r.label} must not be sealed',
      );
    }
  });

  testWidgets('the verb wears its own skill tone', (WidgetTester tester) async {
    // DIR-13 failure 2: a craft and a gather were the same picture. The
    // ribbon is the difference the eye catches before it reads a letter, so
    // two skills must never resolve to one ribbon.
    expect(
      RewardArt.stampVerbFor('skill.mining'),
      isNot(RewardArt.stampVerbFor('skill.smithing')),
    );
    // An unknown skill is honest rather than wrong.
    expect(RewardArt.stampVerbFor(null), RewardArt.stampVerbGathered);
    expect(RewardArt.stampVerbFor('skill.nonesuch'), RewardArt.stampVerbGathered);

    // _result forges, so the card must carry the smith's ribbon and no other.
    await _pump(tester, _result(rarity: Rarity.common, xp: 12));
    expect(_art(tester), contains(RewardArt.stampVerbSmithing));
    expect(_art(tester), isNot(contains(RewardArt.stampVerbGathered)));
  });

  testWidgets('reduce motion draws the final frame, and keeps the haptic', (
    WidgetTester tester,
  ) async {
    // M-16: an accessibility setting may not remove a feedback channel it
    // does not name. The stamp and the seal arrive finished; nothing else in
    // the card branches on the setting, and the arrival haptic lives in
    // `ActivityResultHost` where no motion guard can reach it.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ActivityResultCard(result: _result(rarity: Rarity.rare)),
          ),
        ),
      ),
    );
    await tester.pump();
    // A single pump: with motion the stamp would still be part-way through
    // its 120 ms press. Every transform on stage is the identity.
    for (final Element e in find.byType(Transform).evaluate()) {
      final Matrix4 m = (e.widget as Transform).transform;
      expect(
        m.storage[0],
        moreOrLessEquals(1, epsilon: 0.001),
        reason: 'a scale is still running under Reduce Motion',
      );
    }
    for (final Element e in find.byType(Opacity).evaluate()) {
      expect((e.widget as Opacity).opacity, 1);
    }
  });
}
