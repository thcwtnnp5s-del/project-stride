/// A rare find must look rare, whichever loop produced it.
///
/// The craft path has distinguished its outputs since GFCP01 — rarity, an
/// equip delta, a bench time, a held reward layer. The gather path could not,
/// for one small reason with a large effect: `ActionReport` dropped the
/// `Rarity` that `InventoryEntry` and `DropPreview` both already carried, so
/// the universal result card had nothing to escalate on.
///
/// The consequence, in the shipped content: **`item.gloom_silk` is Rare and is
/// a node yield.** Pulling it from a silkstrand thicket produced exactly the
/// same card as pulling Common `item.copper_ore` — same frame, same border
/// weight, same hold, no haptic. The single most exciting thing a gathering
/// session can produce was also its quietest moment.
///
/// These tests pin the projection and the escalation it feeds.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/activity_result.dart';
import 'package:stride_core/stride_core.dart';

void main() {
  group('the result card escalates on rarity', () {
    ActivityResult card(Rarity? rarity) => ActivityResult(
      verb: 'MINED',
      itemName: 'Something',
      quantity: 1,
      rarity: rarity,
    );

    test('a common find is an ordinary card', () {
      expect(card(Rarity.common).notable, isFalse);
    });

    test('an uncommon-or-better find is notable', () {
      // The escalation the gather path could not reach before: a 2 px accented
      // frame, the reward glow, the longer hold, and the one light haptic.
      expect(card(Rarity.uncommon).notable, isTrue);
      expect(card(Rarity.rare).notable, isTrue);
      expect(card(Rarity.epic).notable, isTrue);
      expect(card(Rarity.legendary).notable, isTrue);
    });

    test('an unknown rarity is not an accidental escalation', () {
      // Null must read as "no claim", never as "notable" — a report that
      // forgot to carry rarity should look ordinary, not exciting.
      expect(card(null).notable, isFalse);
    });

    test('a bonus-yield proc still escalates on its own', () {
      // The one escalation a gather already had, preserved: these are two
      // independent reasons for a card to be notable, not one replacing the
      // other.
      const ActivityResult proc = ActivityResult(
        verb: 'MINED',
        itemName: 'Copper Ore',
        quantity: 3,
        bonusQuantity: 1,
        rarity: Rarity.common,
      );
      expect(proc.notable, isTrue);
    });

    test('merging a run of finds keeps the rarity of the first', () {
      // Rapid taps merge into one counting card. A merge must not silently
      // demote a rare find to the common one that followed it.
      final ActivityResult first = card(Rarity.rare);
      final ActivityResult merged = first.merged(card(Rarity.common));
      expect(merged.rarity, Rarity.rare);
      expect(merged.notable, isTrue);
    });
  });
}
