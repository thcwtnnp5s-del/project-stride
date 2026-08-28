/// The craft significance derivation, pinned
/// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 1): significance comes from
/// what was made — rarity, equipment, level, first craft — and from nothing
/// else. No per-item branch can exist, because no item identity is an input.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stride_core/stride_core.dart' show Rarity;
import 'package:stride/ui/state/craft_significance.dart';

void main() {
  CraftSignificance of({
    Rarity? rarity,
    bool equipment = false,
    bool levelled = false,
    bool first = false,
  }) => craftSignificanceOf(
    outputRarity: rarity,
    isEquipment: equipment,
    levelledUp: levelled,
    firstCraft: first,
  );

  test('ordinary components and food are minor', () {
    expect(of(rarity: Rarity.common), CraftSignificance.minor);
    expect(of(rarity: Rarity.uncommon), CraftSignificance.minor);
    expect(of(rarity: null), CraftSignificance.minor);
  });

  test('equipment, a level, or a rare output hold as medium', () {
    expect(of(rarity: Rarity.common, equipment: true),
        CraftSignificance.medium);
    expect(of(rarity: Rarity.uncommon, levelled: true),
        CraftSignificance.medium);
    expect(of(rarity: Rarity.rare), CraftSignificance.medium);
  });

  test('a first craft elevates only from uncommon up', () {
    // A first plank is still a plank.
    expect(of(rarity: Rarity.common, first: true), CraftSignificance.minor);
    expect(of(rarity: null, first: true), CraftSignificance.minor);
    expect(of(rarity: Rarity.uncommon, first: true),
        CraftSignificance.medium);
  });

  test('epic and above are major, whatever else is true', () {
    expect(of(rarity: Rarity.epic), CraftSignificance.major);
    expect(of(rarity: Rarity.legendary, equipment: true, levelled: true),
        CraftSignificance.major);
  });
}
