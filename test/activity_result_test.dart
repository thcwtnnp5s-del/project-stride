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

/// The name and its quantity are two widgets now, not one string: the tally
/// slip sets the name in rarity ink on the left and the figure down the right
/// margin, the way a ledger is written (EPO03, DIR-13). The property under
/// test is unchanged — *this item, this many, on the card* — so the finder
/// moves and the assertion does not weaken.
void _expectItem(String name, int quantity, {bool present = true}) {
  expect(find.text(name), present ? findsOneWidget : findsNothing);
  if (quantity > 1) {
    expect(find.text('×$quantity'), present ? findsOneWidget : findsNothing);
  }
}

/// Likewise for a fact line: the words on the left, the figure on the right.
void _expectFact(String label, String figure, {bool present = true}) {
  expect(find.text(label), present ? findsOneWidget : findsNothing);
  expect(find.text(figure), present ? findsOneWidget : findsNothing);
}

void main() {
  testWidgets('an ordinary completion is visibly answered, and reads for '
      'seconds, not a flash', (WidgetTester tester) async {
    await tester.pumpWidget(_host(result: null, token: null));
    expect(find.text('MINED'), findsNothing);

    await tester.pumpWidget(_host(result: _result(), token: 1));
    await tester.pump();
    expect(find.text('MINED'), findsOneWidget);
    _expectItem('Copper Ore', 2);
    _expectFact('Mining XP', '+12');

    // Still readable well past a toast's life…
    await tester.pump(const Duration(milliseconds: 2500));
    _expectItem('Copper Ore', 2);
    // …and gone on its own after the hold + fade.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump();
    _expectItem('Copper Ore', 2, present: false);
  });

  testWidgets('a bonus yield is its own line and takes the reward light', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(result: _result(quantity: 3, bonus: 1), token: 1),
    );
    await tester.pump();
    _expectFact('Bonus yield', '+1');
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
    _expectItem('Copper Ore', 2);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpWidget(
      _host(result: _result(incremental: true), token: 2),
    );
    await tester.pump();
    // One card, summed — never a second popup.
    _expectItem('Copper Ore', 4);
    _expectFact('Mining XP', '+24');
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
    _expectItem('Tin Ore', 1);
    _expectItem('Copper Ore', 2, present: false);
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
    _expectItem('Copper Ore', 4);
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
    _expectItem('Copper Ore', 2);
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
    _expectItem('Copper Ore', 2);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    _expectItem('Copper Ore', 2, present: false);
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
    _expectItem('Oak Plank', 2);
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
    _expectItem('Oak Plank', 2);
    await tester.pumpAndSettle();
    _expectItem('Oak Plank', 2, present: false);
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
