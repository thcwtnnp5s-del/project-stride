// A blow's quality is recorded, not re-derived (PLAYABLE_POLISH_01 §8).
//
// The strike roll has always existed (`CombatRules.roll`, −1/0/+1); until
// this pass it vanished into the damage figure and the fight read as
// predetermined. The event now carries the roll so the narration can say
// "a strong hit" or "a glancing blow" — from the committed event, with the
// arithmetic unchanged.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

void main() {
  final ContentId woods = ContentId.unchecked('location.whispering_woods');
  final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
  final ContentId sword = ContentId.unchecked('item.training_sword');

  GameEngine fighting() {
    final GameEngine engine = newEngine();
    sync(engine, incremental(<StepObservation>[obs(phone, 0, 5000)]));
    expect(engine.execute(EquipItem(item: sword)).isAccepted, isTrue);
    expect(engine.execute(TravelTo(destination: woods)).isAccepted, isTrue);
    expect(engine.execute(StartEncounter(enemy: wolf)).isAccepted, isTrue);
    return engine;
  }

  test('every strike event carries the roll that shaped its damage', () {
    final GameEngine engine = fighting();
    final EncounterState encounter = engine.state.encounter!;
    final EnemyDefinition enemy = stepRegistry.enemies[wolf]!;
    final EngineResult round = engine.execute(const CombatAttack());
    expect(round.isAccepted, isTrue, reason: '$round');

    final CombatPlayerStruck mine = round.events
        .whereType<CombatPlayerStruck>()
        .single;
    expect(mine.roll, inInclusiveRange(-1, 1));
    expect(
      mine.roll,
      CombatRules.roll(encounter.seed, 1, CombatRules.playerStrikeSalt),
    );
    expect(
      mine.damage,
      CombatRules.strike(encounter.playerAttack, enemy.defence, mine.roll),
      reason: 'the figure is unchanged; the roll is merely recorded',
    );
    for (final CombatEnemyStruck theirs
        in round.events.whereType<CombatEnemyStruck>()) {
      expect(theirs.roll, inInclusiveRange(-1, 1));
      if (theirs.heavy) expect(theirs.roll, 0);
    }
  });

  test('the roll survives the journal, and an old record reads as even', () {
    final GameEngine engine = fighting();
    final EngineResult round = engine.execute(const CombatAttack());
    final CombatPlayerStruck mine = round.events
        .whereType<CombatPlayerStruck>()
        .single;
    final GameEvent? back = decodeEvent(encodeEvent(mine));
    expect((back! as CombatPlayerStruck).roll, mine.roll);

    final Map<String, Object?> old = encodeEvent(mine)..remove('roll');
    expect((decodeEvent(old)! as CombatPlayerStruck).roll, 0);

    final Map<String, Object?> bad = encodeEvent(mine)..['roll'] = 7;
    expect(decodeEvent(bad), isNull, reason: 'a roll outside −1..1 is corrupt');
  });
}
