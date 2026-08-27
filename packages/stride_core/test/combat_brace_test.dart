// Brace (`DECISIONS/0027`, experimental — Q-06's candidate): deal nothing,
// halve every strike of the enemy's reply, floored at 1.
//
// The pins here are the arithmetic and the round shape: a braced reply's
// strikes carry exactly `max(1, strike ~/ 2)`, the stance is narrated by its
// own event before the strikes, and the turn still advances so the fight
// goes on. Everything is asserted from the events' own rolls, because the
// resolver is seeded and deterministic.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId stonefall = ContentId.unchecked('location.stonefall_mine');
final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId salamander = ContentId.unchecked('enemy.salamander');

void main() {
  GameEngine engineAt(ContentId location) {
    final GameEngine engine = newEngine();
    engine.execute(
      const GrantSyntheticSteps(steps: 10000, reason: 'brace probe'),
    );
    final EngineResult travelled = engine.execute(
      TravelTo(destination: location),
    );
    expect(travelled.isAccepted, isTrue, reason: '${travelled.rejection}');
    return engine;
  }

  test('brace without an encounter is refused', () {
    final GameEngine engine = newEngine();
    final EngineResult r = engine.execute(const CombatBrace());
    expect(r.rejection!.code, RejectionCode.noEncounter);
  });

  test('a braced flurry lands every strike at half damage, floored at 1', () {
    final GameEngine engine = engineAt(woods);
    engine.execute(StartEncounter(enemy: wolf));
    final int hpBefore = engine.state.encounter!.playerHp;
    final int enemyHpBefore = engine.state.encounter!.enemyHp;

    final EngineResult r = engine.execute(const CombatBrace());
    expect(r.isAccepted, isTrue, reason: '${r.rejection}');

    // The stance narrates first, then the wolf's two strikes, then the round
    // closes. No player strike anywhere: bracing deals none.
    expect(r.events.first, isA<CombatBraced>());
    expect(r.events.whereType<CombatPlayerStruck>(), isEmpty);
    final List<CombatEnemyStruck> strikes = r.events
        .whereType<CombatEnemyStruck>()
        .toList();
    expect(strikes, hasLength(2), reason: 'a flurry is two strikes');
    final EnemyDefinition wolfDef = engine.registry.enemies[wolf]!;
    for (final CombatEnemyStruck strike in strikes) {
      final int unbraced = CombatRules.strike(
        wolfDef.attack,
        engine.state.encounter!.playerDefence,
        strike.roll,
      );
      final int halved = unbraced ~/ 2 < 1 ? 1 : unbraced ~/ 2;
      expect(
        strike.damage,
        halved,
        reason: 'roll ${strike.roll}: $unbraced should brace to $halved',
      );
    }
    expect(r.events.last, isA<CombatRoundEnded>());

    // The enemy is untouched and the turn moved: a braced round is spent.
    expect(engine.state.encounter!.enemyHp, enemyHpBefore);
    expect(engine.state.encounter!.turn, 2);
    expect(engine.state.encounter!.playerHp, lessThan(hpBefore));
  });

  test('bracing the telegraphed heavy strike halves it', () {
    final GameEngine engine = engineAt(stonefall);
    engine.execute(StartEncounter(enemy: salamander));

    // Rounds 1 and 2: attack. The round-2 close telegraphs the turn-3 heavy.
    engine.execute(const CombatAttack());
    final EngineResult second = engine.execute(const CombatAttack());
    final CombatRoundEnded closed = second.events
        .whereType<CombatRoundEnded>()
        .single;
    expect(closed.telegraph, isTrue, reason: 'guarded: heavy every third turn');

    final EngineResult braced = engine.execute(const CombatBrace());
    final CombatEnemyStruck heavy = braced.events
        .whereType<CombatEnemyStruck>()
        .single;
    expect(heavy.heavy, isTrue);
    final EnemyDefinition salaDef = engine.registry.enemies[salamander]!;
    final int unbraced = CombatRules.heavyStrike(
      salaDef.attack,
      engine.state.encounter!.playerDefence,
    );
    expect(heavy.damage, unbraced ~/ 2 < 1 ? 1 : unbraced ~/ 2);
  });

  test('a braced round replays identically from its journal events', () {
    // The codec round-trip: the braced round's events survive encode/decode,
    // which is what makes the stance safe with no schema change.
    final GameEngine engine = engineAt(woods);
    engine.execute(StartEncounter(enemy: wolf));
    final EngineResult r = engine.execute(const CombatBrace());

    for (final GameEvent event in r.events) {
      final GameEvent? decoded = decodeEvent(encodeEvent(event));
      expect(decoded, isNotNull, reason: '${event.name} did not round-trip');
      expect(decoded!.name, event.name);
      expect(decoded.sequence, event.sequence);
    }
  });
}
