/// The guard reading must agree with the resolver, exactly, always.
///
/// The fight now tells the player what the next blow costs against the armour
/// they are wearing, and what bracing would save. That is the Studied tier's
/// mechanical payoff and the answer to "equipment should matter more" — but it
/// is only worth anything if it is **true**. A projection that promised 6 and
/// then dealt 9 would be worse than silence: it would teach the player to
/// distrust the one number the game volunteers.
///
/// So this file re-derives the reading independently from
/// `GameEngine._enemyReply`'s own arithmetic and holds the two together across
/// every shipped enemy, a ladder of real armour values, both terrains, and
/// every turn in the guarded cycle. The order is the part that is easy to get
/// wrong and impossible to see: **brace halves first, frost guard subtracts
/// second, and both floor at 1.** Swap them and the Frostwarden Coat quietly
/// starts lying in exactly one region.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride_core/stride_core.dart';

/// The resolver's arithmetic, written out longhand from
/// `game_engine.dart:_enemyReply` — deliberately a second implementation, so
/// a change to either side has to be made twice and noticed once.
int _engineDamage({
  required int enemyAttack,
  required int playerDefence,
  required int roll,
  required bool heavy,
  required bool braced,
  required int frostGuard,
}) {
  int damage = heavy
      ? CombatRules.heavyStrike(enemyAttack, playerDefence)
      : CombatRules.strike(enemyAttack, playerDefence, roll);
  if (braced) damage = damage ~/ 2 < 1 ? 1 : damage ~/ 2;
  if (frostGuard > 0) {
    damage = damage - frostGuard < 1 ? 1 : damage - frostGuard;
  }
  return damage;
}

void main() {
  // The shipped roster's real figures, base tier and Veterans.
  const Map<String, (int atk, int def, EnemyBehavior b)> roster =
      <String, (int, int, EnemyBehavior)>{
        'forest_wolf': (4, 0, EnemyBehavior.flurry),
        'wild_boar': (6, 2, EnemyBehavior.steady),
        'oakback_bear': (11, 3, EnemyBehavior.guarded),
        'cave_goblin': (8, 3, EnemyBehavior.steady),
        'salamander': (8, 2, EnemyBehavior.guarded),
        'scree_crawler': (6, 6, EnemyBehavior.steady),
        'frost_lynx': (9, 2, EnemyBehavior.flurry),
        'mountain_ram': (7, 4, EnemyBehavior.steady),
        'hollow_guardian': (11, 4, EnemyBehavior.guarded),
        'old_grey': (13, 4, EnemyBehavior.flurry),
        'gallery_foreman': (15, 5, EnemyBehavior.guarded),
        'rimeclaw_matriarch': (14, 5, EnemyBehavior.flurry),
        'guardian_awakened': (14, 5, EnemyBehavior.guarded),
      };

  // The real armour ladder, plus the frost-guard pieces.
  const List<(int def, int frost)> armours = <(int, int)>[
    (0, 0), // unarmoured
    (2, 0), // Traveler Tunic
    (7, 0), // Bronze Chestplate
    (6, 2), // Frost-lined Jerkin
    (9, 0), // Bearhide Coat
    (8, 3), // Frostwarden Coat
    (9, 2), // Clawguard Coat
  ];

  test('every reading matches the resolver, on every enemy and every coat', () {
    for (final MapEntry<String, (int, int, EnemyBehavior)> e
        in roster.entries) {
      final (int atk, int _, EnemyBehavior behavior) = e.value;
      for (final (int def, int frost) in armours) {
        for (final bool alpine in <bool>[false, true]) {
          // Walk a full guarded cycle so the heavy turn is covered.
          for (int turn = 1; turn <= 3; turn++) {
            final bool heavy =
                behavior == EnemyBehavior.guarded &&
                CombatRules.isHeavyTurn(turn);
            final int effectiveFrost = alpine ? frost : 0;

            final int expectLow = _engineDamage(
              enemyAttack: atk,
              playerDefence: def,
              roll: heavy ? 0 : -1,
              heavy: heavy,
              braced: false,
              frostGuard: effectiveFrost,
            );
            final int expectHigh = _engineDamage(
              enemyAttack: atk,
              playerDefence: def,
              roll: heavy ? 0 : 1,
              heavy: heavy,
              braced: false,
              frostGuard: effectiveFrost,
            );
            final int expectBracedLow = _engineDamage(
              enemyAttack: atk,
              playerDefence: def,
              roll: heavy ? 0 : -1,
              heavy: heavy,
              braced: true,
              frostGuard: effectiveFrost,
            );

            final CombatGuardReading r = StrideSession.computeGuardReading(
              enemyAttack: atk,
              enemyBehavior: behavior,
              playerDefence: def,
              playerFrostGuard: frost,
              turn: turn,
              alpine: alpine,
              enemyDefence: 0,
              playerAttack: 1,
            );

            final String where =
                '${e.key} def=$def frost=$frost alpine=$alpine turn=$turn';
            expect(r.lowest, expectLow, reason: 'lowest @ $where');
            expect(r.highest, expectHigh, reason: 'highest @ $where');
            expect(
              r.bracedLowest,
              expectBracedLow,
              reason: 'bracedLowest @ $where',
            );
            final int expectBracedHigh = _engineDamage(
              enemyAttack: atk,
              playerDefence: def,
              roll: heavy ? 0 : 1,
              heavy: heavy,
              braced: true,
              frostGuard: effectiveFrost,
            );
            expect(
              r.bracedHighest,
              expectBracedHigh,
              reason: 'bracedHighest @ $where',
            );
            expect(
              r.strikes,
              behavior == EnemyBehavior.flurry ? 2 : 1,
              reason: 'strikes @ $where',
            );
            expect(r.heavy, heavy, reason: 'heavy @ $where');
          }
        }
      }
    }
  });

  test('brace halves BEFORE frost guard subtracts', () {
    // The order the engine documents, and the one a reimplementation gets
    // backwards. Guardian heavy 22 vs defence 8, frost guard 3, alpine:
    //   correct   -> (22-8)=14, braced 7, then -3 = 4
    //   backwards -> 14-3 = 11, braced 5
    final CombatGuardReading r = StrideSession.computeGuardReading(
      enemyAttack: 11,
      enemyBehavior: EnemyBehavior.guarded,
      playerDefence: 8,
      playerFrostGuard: 3,
      turn: 3,
      alpine: true,
      enemyDefence: 0,
      playerAttack: 1,
    );
    expect(r.heavy, isTrue);
    expect(r.lowest, 11); // 22 - 8 = 14, then frost guard 3 -> 11
    expect(r.bracedLowest, 4); // 14 halved = 7, then frost guard 3 -> 4
  });

  test('frost guard is inert outside alpine terrain', () {
    final CombatGuardReading warm = StrideSession.computeGuardReading(
      enemyAttack: 11,
      enemyBehavior: EnemyBehavior.guarded,
      playerDefence: 8,
      playerFrostGuard: 3,
      turn: 3,
      alpine: false,
      enemyDefence: 0,
      playerAttack: 1,
    );
    expect(warm.lowest, 14, reason: 'the coat must not warm the Hollow');
  });

  test('every figure floors at 1 — a strike always lands', () {
    // P-7's shape in the reading: no armour, no stance and no coat can make a
    // blow cost nothing, so the projection must never promise zero.
    final CombatGuardReading r = StrideSession.computeGuardReading(
      enemyAttack: 4,
      enemyBehavior: EnemyBehavior.flurry,
      playerDefence: 99,
      playerFrostGuard: 99,
      turn: 1,
      alpine: true,
    );
    expect(r.lowest, greaterThanOrEqualTo(1));
    expect(r.bracedLowest, greaterThanOrEqualTo(1));
  });

  group('the label tells the truth about its own value', () {
    test('a wolf at low guard is told bracing barely helps', () {
      // 4 attack, 0 defence: 3–5 becomes 1–2 braced. It IS a saving, so the
      // label states the figures rather than discouraging.
      final CombatGuardReading r = StrideSession.computeGuardReading(
        enemyAttack: 4,
        enemyBehavior: EnemyBehavior.flurry,
        playerDefence: 0,
        playerFrostGuard: 0,
        turn: 1,
        alpine: false,
      );
      expect(r.strikes, 2);
      // The round total, not just the per-blow band: "3-5 twice" makes a
      // player at 8 health do arithmetic at the worst possible moment.
      expect(r.takenLabel, contains('this round'));
    });

    test('a blow already floored at 1 admits bracing saves nothing', () {
      // Crawler 6 attack against defence 9: every strike is floored to 1, and
      // half of 1 is still 1. The button must not claim a saving it cannot
      // deliver.
      final CombatGuardReading r = StrideSession.computeGuardReading(
        enemyAttack: 6,
        enemyBehavior: EnemyBehavior.steady,
        playerDefence: 9,
        playerFrostGuard: 0,
        turn: 1,
        alpine: false,
      );
      expect(r.worthwhile, isFalse);
      // It still states the figure; what it drops is the recommendation, and
      // it names the cost that makes bracing wrong here.
      expect(r.braceLabel, contains('gives up your strike'));
    });

    test('a heavy blow states one exact figure, never a band', () {
      // The heavy takes no roll, which is what makes the telegraph worth
      // reading: the number is knowable, not estimated.
      final CombatGuardReading r = StrideSession.computeGuardReading(
        enemyAttack: 11,
        enemyBehavior: EnemyBehavior.guarded,
        playerDefence: 3,
        playerFrostGuard: 0,
        turn: 3,
        alpine: false,
      );
      expect(r.lowest, r.highest);
      expect(r.takenLabel, '19'); // 2*11 - 3
      expect(r.braceLabel, contains('Take 9 instead of 19'));
    });

    test('armour visibly moves the number — the whole point', () {
      // The Oakback Bear's heavy: seven points of coat is 20 damage versus
      // 13, which in the real fight is dying on turn 5 versus winning at 64%
      // health. The game now says so before the bar empties.
      int heavyAgainst(int def) => StrideSession.computeGuardReading(
        enemyAttack: 11,
        enemyBehavior: EnemyBehavior.guarded,
        playerDefence: def,
        playerFrostGuard: 0,
        turn: 3,
        alpine: false,
      ).lowest;
      expect(heavyAgainst(2), 20);
      expect(heavyAgainst(9), 13);
    });
  });
}
