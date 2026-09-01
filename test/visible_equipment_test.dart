/// Equipped armour is visible on the Traveler, and reading that costs nothing.
///
/// ## The contradiction this closes
///
/// The owner's charge was "no ghost gear" — equip something and see it. The
/// Character screen is the one surface whose entire subject is the Traveler,
/// and it drew the same fixed bust whatever was equipped.
///
/// `Q-14` asked which gear on which surfaces and was closed by owner ruling in
/// `DECISIONS/0030`. `FOUNDATION_G_EQUIPMENT.md` closed the *how* by
/// measurement: layering is not viable here — per-frame bounding-box centres
/// travel 13–23.5 px, no hand anchor exists across 219 frames, and the baked
/// blade shares all seven of its colours with the body, so the palette
/// substitution a layer would need is not deterministic and would not be A-2.
/// Precomposed variants, resolved through one seam.
///
/// ## What must stay true
///
/// **Reading the projection commits nothing.** `equipmentVisualState` is a
/// getter over `equipment.bySlot`; the variant tables are presentation-layer
/// `const` maps keyed by item id. No save field, no migration, state stays v9 —
/// and this file is where that stops being a claim.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart'
    show EquipmentVisualState, EquippedVisualFact;
import 'package:stride/ui/icons/traveler_art.dart';

const String _base = 'assets/art/v1/sprite/traveler_south.png';

EquipmentVisualState _wearing(String? armorItemId) => EquipmentVisualState(
  armor: armorItemId == null
      ? null
      : EquippedVisualFact(itemId: armorItemId, tier: 1, toolKind: 'none'),
);

void main() {
  test('an empty armour slot is the base Traveler', () {
    expect(TravelerArt.figureFor(const EquipmentVisualState()), _base);
    expect(TravelerArt.figureFor(_wearing(null)), _base);
  });

  test('an item with no authored class degrades to the base, never a hole', () {
    // The property that lets a content pack ship an item before its art: an
    // unmapped id is the Traveler, not a missing asset.
    expect(TravelerArt.figureFor(_wearing('item.not_a_real_item')), _base);
    // The starter tunics are deliberately unmapped — they ARE the base outfit.
    expect(TravelerArt.figureFor(_wearing('item.traveler_tunic')), _base);
    expect(TravelerArt.figureFor(_wearing('item.waywarden_tunic')), _base);
  });

  test('each armour class shows its own figure', () {
    final Map<String, String> byItem = <String, String>{
      for (final String id in TravelerArt.variantOfItem.keys)
        id: TravelerArt.figureFor(_wearing(id)),
    };

    // Nothing mapped may fall through to the base — a mapped item whose class
    // has no figure would be a silent regression to "ghost gear".
    for (final MapEntry<String, String> e in byItem.entries) {
      expect(
        e.value,
        isNot(_base),
        reason: '${e.key} is mapped to a class with no figure',
      );
    }

    // Three classes, three distinct pictures. Coarse classes are the point —
    // ten items to three figures — but two *classes* sharing art would mean
    // the player cannot tell a breastplate from a coat.
    expect(TravelerArt.armorFigures.values.toSet(), hasLength(3));
    expect(byItem.values.toSet(), hasLength(3));
  });

  test('the classes are the ones that were authored', () {
    expect(
      TravelerArt.armorFigures.keys.toSet(),
      <String>{'armor.plate', 'armor.jerkin', 'armor.coat'},
    );
    // Every mapped item names a class that exists. A typo here would show the
    // player the base figure and look like the feature simply not working.
    for (final MapEntry<String, String> e
        in TravelerArt.variantOfItem.entries) {
      if (!e.value.startsWith('armor.')) continue;
      expect(
        TravelerArt.armorFigures,
        contains(e.value),
        reason: '${e.key} names an armour class with no figure: ${e.value}',
      );
    }
  });

  test('reading the projection commits nothing', () {
    // The whole architecture rests on this: the visual state is derived, so
    // looking at what you are wearing can never write a save.
    const EquipmentVisualState visual = EquipmentVisualState(
      armor: EquippedVisualFact(itemId: 'item.bearhide_coat', tier: 2, toolKind: 'none'),
    );
    final String first = TravelerArt.figureFor(visual);
    final String second = TravelerArt.figureFor(visual);
    expect(first, second);
    expect(first, TravelerArt.armorFigures['armor.coat']);
  });
}
