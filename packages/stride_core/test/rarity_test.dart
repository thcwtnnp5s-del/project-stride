// Authored item rarity — the enum's shape (`DECISIONS/0021` §4).
//
// The *content* half of rarity — that every shipped item carries one, which
// rank each item has, and that Legendary is still reserved — is asserted in
// `production_content_test.dart`, next to the other facts about the bundle.
// The loader's two refusals are in `broken_fixtures_test.dart`, next to the
// other broken fixtures. This file is only the enum, and it exists because
// three separate things depend on the order being exactly what the owner
// wrote: the wire strings, the ranks, and the UI's one style table.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

void main() {
  group('Rarity', () {
    test('is complete, and in the owner\'s ascending order', () {
      // Spelled out as a literal rather than derived from `values`, which
      // would make this assert that the enum equals itself. The order is the
      // decision; the list is the record of it.
      expect(Rarity.values, <Rarity>[
        Rarity.uncommon,
        Rarity.common,
        Rarity.rare,
        Rarity.epic,
        Rarity.legendary,
      ]);

      // **Uncommon sits below Common**, which is the reverse of the usual RPG
      // convention and is deliberate — it is the order the owner's rarity list
      // gave. If this ever fires because someone "fixed" it, the fix is a
      // decision, not a code change (`RULES.md` G-3).
      expect(Rarity.uncommon.rank, lessThan(Rarity.common.rank));
    });

    test('ranks are 0..4 and match the declaration order', () {
      expect(Rarity.values.map((Rarity r) => r.rank), <int>[0, 1, 2, 3, 4]);
      for (int i = 1; i < Rarity.values.length; i++) {
        expect(
          Rarity.values[i].rank,
          greaterThan(Rarity.values[i - 1].rank),
          reason: 'ranks must strictly increase for a sort to mean anything',
        );
      }
    });

    test('labels are the player-facing words, capitalised once', () {
      expect(Rarity.values.map((Rarity r) => r.label), <String>[
        'Uncommon',
        'Common',
        'Rare',
        'Epic',
        'Legendary',
      ]);
    });

    test(
      'the wire name is the enum name, and the lookup covers every rank',
      () {
        for (final Rarity rarity in Rarity.values) {
          expect(rarity.wireName, rarity.name);
          expect(
            Rarity.byWireName[rarity.wireName],
            rarity,
            reason: '${rarity.name} is not authorable',
          );
        }
        expect(Rarity.byWireName, hasLength(Rarity.values.length));
        expect(Rarity.byWireName['mythic'], isNull);
      },
    );
  });

  group('LocationKind', () {
    test('is complete', () {
      // The four words `DECISIONS/0021` §5 names, in the order it names them.
      expect(LocationKind.values, <LocationKind>[
        LocationKind.haven,
        LocationKind.wilds,
        LocationKind.worksite,
        LocationKind.perilous,
      ]);
      expect(LocationKind.values.map((LocationKind k) => k.label), <String>[
        'Haven',
        'Wilds',
        'Worksite',
        'Perilous',
      ]);
    });
  });
}
