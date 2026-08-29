/// The universal activity result (GFCP01 device correction): every
/// completed activity gets a visible card; ordinary stays readable and
/// unobtrusive, notable takes the reward light, repeats merge instead of
/// stacking, a hidden tab's card waits, and none of it changes a single
/// awarded figure. Deterministic pumps throughout — nothing sleeps.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/activity_result.dart';
import 'package:stride_core/stride_core.dart' show ContentId, Rarity;

ActivityResult _result({
  String verb = 'MINED',
  String item = 'item.copper_ore',
  String name = 'Copper Ore',
  int quantity = 2,
  int bonus = 0,
  int xp = 12,
  Rarity? rarity,
  bool incremental = false,
}) => ActivityResult(
  verb: verb,
  itemId: ContentId.unchecked(item),
  itemName: name,
  quantity: quantity,
  bonusQuantity: bonus,
  skillName: 'Mining',
  xp: xp,
  rarity: rarity,
  incremental: incremental,
);

Widget _host({
  required ActivityResult? result,
  required Object? token,
  VoidCallback? onExpired,
  bool reduceMotion = false,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: ActivityResultHost(
      result: result,
      resultToken: token,
      onExpired: onExpired,
      child: const SizedBox.expand(),
    ),
  ),
);

void main() {
  testWidgets('an ordinary completion is visibly answered, and reads for '
      'seconds, not a flash', (WidgetTester tester) async {
    await tester.pumpWidget(_host(result: null, token: null));
    expect(find.text('MINED'), findsNothing);

    await tester.pumpWidget(_host(result: _result(), token: 1));
    await tester.pump();
    expect(find.text('MINED'), findsOneWidget);
    expect(find.text('Copper Ore ×2'), findsOneWidget);
    expect(find.text('+12 Mining XP'), findsOneWidget);

    // Still readable well past a toast's life…
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('Copper Ore ×2'), findsOneWidget);
    // …and gone on its own after the hold + fade.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    expect(find.text('Copper Ore ×2'), findsNothing);
  });

  testWidgets('a bonus yield is its own line and takes the reward light', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(result: _result(quantity: 3, bonus: 1), token: 1),
    );
    await tester.pump();
    expect(find.text('+1 bonus yield'), findsOneWidget);
    expect(_result(bonus: 1).notable, isTrue);
    expect(_result().notable, isFalse);
    await tester.pumpAndSettle();
  });

  test('rarity elevates from uncommon up, never common', () {
    expect(_result(rarity: Rarity.common).notable, isFalse);
    expect(_result(rarity: Rarity.uncommon).notable, isTrue);
    expect(_result(rarity: Rarity.rare).notable, isTrue);
  });

  testWidgets('rapid repeats of the same item merge into one card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(result: _result(incremental: true), token: 1),
    );
    await tester.pump();
    expect(find.text('Copper Ore ×2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpWidget(
      _host(result: _result(incremental: true), token: 2),
    );
    await tester.pump();
    // One card, summed — never a second popup.
    expect(find.text('Copper Ore ×4'), findsOneWidget);
    expect(find.text('+24 Mining XP'), findsOneWidget);
    expect(find.byType(ActivityResultCard), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a different result replaces the card instead of merging', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(result: _result(incremental: true), token: 1),
    );
    await tester.pump();
    await tester.pumpWidget(
      _host(
        result: _result(
          item: 'item.tin_ore',
          name: 'Tin Ore',
          quantity: 1,
          incremental: true,
        ),
        token: 2,
      ),
    );
    await tester.pump();
    expect(find.text('Tin Ore ×1'), findsOneWidget);
    expect(find.text('Copper Ore ×2'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('cumulative queue restatements replace in place', (
    WidgetTester tester,
  ) async {
    // The controllers hand the host running totals (not increments):
    // boundary two's card says ×4, never ×6.
    await tester.pumpWidget(_host(result: _result(quantity: 2), token: 1));
    await tester.pump();
    await tester.pumpWidget(_host(result: _result(quantity: 4), token: 2));
    await tester.pump();
    expect(find.text('Copper Ore ×4'), findsOneWidget);
    expect(find.byType(ActivityResultCard), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a token clearing to null never blanks a card mid-read', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_host(result: _result(), token: 1));
    await tester.pump();
    // The session's 5 s result timer clears the report; the snapshot stays.
    await tester.pumpWidget(_host(result: null, token: null));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Copper Ore ×2'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a tap dismisses early and reports expiry once', (
    WidgetTester tester,
  ) async {
    int expired = 0;
    await tester.pumpWidget(
      _host(result: _result(), token: 1, onExpired: () => expired++),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(ActivityResultCard));
    await tester.pump();
    expect(find.byType(ActivityResultCard), findsNothing);
    expect(expired, 1);
    await tester.pump(const Duration(seconds: 5));
    expect(expired, 1);
  });

  testWidgets('reduced motion still shows the card — and still clears it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(result: _result(), token: 1, reduceMotion: true),
    );
    await tester.pump();
    expect(find.text('Copper Ore ×2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    expect(find.text('Copper Ore ×2'), findsNothing);
  });

  testWidgets('a hidden surface\'s card waits for the player', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TickerMode(
          enabled: false,
          child: ActivityResultHost(
            result: _result(verb: 'CRAFTING COMPLETE', name: 'Oak Plank'),
            resultToken: 1,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    // Far past the hold: the paused clock kept the summary standing.
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Oak Plank ×2'), findsOneWidget);
    // The tab fronted: the clock runs, the card reads, then clears.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TickerMode(
          enabled: true,
          child: ActivityResultHost(
            result: _result(verb: 'CRAFTING COMPLETE', name: 'Oak Plank'),
            resultToken: 1,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Oak Plank ×2'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Oak Plank ×2'), findsNothing);
  });

  test('the verb table answers every profession and falls back honestly', () {
    expect(activityVerbFor('skill.mining'), 'MINED');
    expect(activityVerbFor('skill.woodcutting'), 'CHOPPED');
    expect(activityVerbFor('skill.foraging'), 'FORAGED');
    expect(activityVerbFor('skill.cooking'), 'COOKED');
    expect(activityVerbFor('skill.smithing'), 'FORGED');
    expect(activityVerbFor('skill.someday_fishing'), 'GATHERED');
    expect(activityVerbFor(null), 'GATHERED');
  });
}
