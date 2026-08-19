// Combat Slice 01 through the real session (`GAME_BIBLE/COMBAT/02`,
// `DECISIONS/0020`): the encounter projections, the four combat commands, and
// what a cold reload finds mid-fight and after it.
//
// `packages/stride_core/test/combat_test.dart` proves the rules. This file
// proves `StrideSession` drives them over the real repository and the real
// file layout — one round, one commit — and that its projections are read
// from state rather than remembered.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/stride_session.dart';
import 'package:stride_core/stride_core.dart';
import 'package:stride_health/stride_health.dart';

final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId haven = ContentId.unchecked('location.havens_rest');
final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId tunic = ContentId.unchecked('item.traveler_tunic');
final ContentId meadowPatch = ContentId.unchecked('resource_node.meadow_patch');
final ContentId herbBrothRecipe = ContentId.unchecked('recipe.herb_broth');
final ContentId herbBroth = ContentId.unchecked('item.herb_broth');

final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
const int hour = 60 * 60 * 1000;
const int t0 = 1750000000000;

SyncFetch page(int steps, {int index = 0, String cursor = 'c1'}) => SyncFetch(
  IncrementalSync(
    observations: <StepObservation>[
      StepObservation(
        key: ObservationKey(
          origin: phone,
          bucket: TimeBucket(
            startMillis: t0 + index * hour,
            endMillis: t0 + (index + 1) * hour,
          ),
        ),
        steps: steps,
      ),
    ],
    nextCursor: SyncCursor.ofString(cursor),
    completeness: CompleteThrough(
      throughMillis: t0 + (index + 1) * hour,
      scope: CompletenessScope(
        dataType: HealthDataType.steps,
        origins: SomeOrigins(<StepOriginKey>{phone}),
        intervalStartMillis: t0,
        intervalEndMillis: t0 + (index + 1) * hour,
        queryGeneration: 1,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('stride_combat'));
  tearDown(() {
    if (!root.existsSync()) return;
    try {
      root.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows holds a handle a moment past close.
    }
  });

  /// A cold launch over [root]. A store that had nothing at install and serves
  /// [steps] afterwards: the first sync is the baseline (`DECISIONS/0019`),
  /// the second banks the page.
  Future<StrideSession> launch({int steps = 0}) => StrideSession.start(
    overrideRoot: root,
    source: MockStepSource(
      script: <SyncFetch>[
        SyncFetch(const NoChangeSync()),
        if (steps > 0) page(steps),
      ],
    ),
  );

  /// A funded session standing in the Whispering Woods, wearing the starting
  /// sword and tunic unless [armed] is false.
  Future<StrideSession> atWoods({int steps = 5000, bool armed = true}) async {
    final StrideSession s = await launch(steps: steps);
    await s.syncSteps();
    await s.syncSteps();
    expect(s.usableEnergy, steps);
    if (armed) {
      expect((await s.equip(trainingSword)).succeeded, isTrue);
      expect((await s.equip(tunic)).succeeded, isTrue);
    }
    final TravelReport t = await s.travel(woods);
    expect(t.succeeded, isTrue, reason: '${t.rejection}: ${t.detail}');
    return s;
  }

  /// Attacks until the encounter resolves; returns the outcome beat.
  Future<CombatBeat> fightToTheEnd(StrideSession s) async {
    for (int i = 0; i < 60 && s.encounter != null; i++) {
      final CombatReport r = await s.combatAttack();
      expect(r.succeeded, isTrue, reason: '${r.rejection}: ${r.detail}');
      final CombatBeat? outcome = r.outcome;
      if (outcome != null) return outcome;
    }
    fail('the fight did not resolve');
  }

  test('projections read the encounter from state, and a win drives the enemy '
      'off until the player moves', () async {
    final StrideSession s = await atWoods();

    // Before: the card is offered, and nothing is being fought.
    expect(s.encounter, isNull);
    final List<EncounterOption> here = s.encountersHere;
    expect(here.map((EncounterOption o) => o.enemyId), <ContentId>[wolf]);
    expect(here.single.available, isTrue);
    expect(here.single.reason, isNull);
    expect(here.single.maxHealth, 20);
    expect(here.single.xp, 30);
    expect(here.single.dropNames, <String>['Meadow Herb']);

    final CombatFigures before = s.combatFigures;
    expect(before.level, 1);
    expect(before.maxHp, 40);
    expect(before.attack, 3, reason: 'Training Sword, power 3');
    expect(before.defence, 2, reason: 'Traveler Tunic, power 2');
    expect(before.weaponName, 'Training Sword');
    expect(before.armorName, 'Traveler Tunic');
    expect(before.nextLevelThreshold, 100);
    expect(before.experienceToNextLevel, 100);

    final CombatReport started = await s.startEncounter(wolf);
    expect(started.succeeded, isTrue, reason: started.detail);
    expect(started.events.single, isA<EncounterStartedBeat>());
    final EncounterView v = s.encounter!;
    expect(v.enemyId, wolf);
    expect(v.enemyName, 'Forest Wolf');
    expect(v.turn, 1);
    expect((v.playerHp, v.playerMaxHp), (40, 40));
    expect((v.playerAttack, v.playerDefence), (3, 2));
    expect((v.enemyHp, v.enemyMaxHp), (20, 20));
    expect(v.behavior, EnemyBehavior.flurry);
    expect(v.isBoss, isFalse);
    expect(
      s.encountersHere.single.reason,
      'encounter_in_progress',
      reason: 'the card must say why it is disabled while a fight is on',
    );
    expect((await s.startEncounter(wolf)).rejection, 'encounter_in_progress');
    // Gather and travel are refused mid-fight with the same code, so the
    // Adventure and World surfaces can name it.
    expect((await s.travel(haven)).rejection, 'encounter_in_progress');

    // One round changes the committed figures, and the view follows them.
    final CombatReport round = await s.combatAttack();
    expect(round.succeeded, isTrue);
    final PlayerStruckBeat struck = round.events
        .whereType<PlayerStruckBeat>()
        .single;
    expect(s.encounter!.enemyHp, struck.enemyHpAfter);
    expect(s.encounter!.turn, 2);
    expect(round.events.whereType<EnemyStruckBeat>(), hasLength(2));

    final int herbsBefore = s.inventoryCount(
      ContentId.unchecked('item.meadow_herb'),
    );
    final CombatBeat outcome = await fightToTheEnd(s);
    expect(
      outcome,
      isA<WonBeat>(),
      reason: 'the wolf is winnable with the starting loadout',
    );
    final WonBeat won = outcome as WonBeat;
    expect(won.xp, 30);
    expect(s.encounter, isNull);
    expect(s.combatFigures.experience, 30);
    expect(s.combatFigures.experienceToNextLevel, 70);

    // Driven off — the card says so, and the engine agrees — until travel.
    expect(s.encountersHere.single.reason, 'enemy_driven_off');
    expect((await s.startEncounter(wolf)).rejection, 'enemy_driven_off');

    // A cold reload finds no encounter and the drops exactly once.
    final StrideSession again = await launch();
    expect(again.encounter, isNull);
    expect(again.currentLocation, woods);
    expect(again.combatFigures.experience, 30);
    final int herbsDropped = won.drops
        .where(((String, int) d) => d.$1 == 'Meadow Herb')
        .fold(0, (int a, (String, int) d) => a + d.$2);
    expect(
      again.inventoryCount(ContentId.unchecked('item.meadow_herb')),
      herbsBefore + herbsDropped,
    );
    expect(again.encountersHere.single.reason, 'enemy_driven_off');

    // Moving clears the driven-off set.
    expect((await again.travel(haven)).succeeded, isTrue);
    expect(again.encountersHere, isEmpty, reason: "Haven's Rest is safe");
    expect((await again.travel(woods)).succeeded, isTrue);
    expect(again.encountersHere.single.available, isTrue);
  });

  test('a cold reload mid-encounter restores the same fight', () async {
    final StrideSession s = await atWoods();
    expect((await s.startEncounter(wolf)).succeeded, isTrue);
    expect((await s.combatAttack()).succeeded, isTrue);
    expect((await s.combatAttack()).succeeded, isTrue);
    final EncounterView live = s.encounter!;
    expect(live.turn, 3);

    // In-place reload, then a second launch over the same root: both are the
    // journal replayed, and both must land at the start of the same turn.
    await s.reload();
    final EncounterView reloaded = s.encounter!;
    expect(reloaded.turn, live.turn);
    expect(reloaded.playerHp, live.playerHp);
    expect(reloaded.enemyHp, live.enemyHp);

    final StrideSession again = await launch();
    final EncounterView cold = again.encounter!;
    expect(cold.enemyId, wolf);
    expect(cold.turn, live.turn);
    expect(cold.playerHp, live.playerHp);
    expect(cold.enemyHp, live.enemyHp);
    expect(cold.telegraph, live.telegraph);
    // And the fight goes on from there.
    expect((await again.combatAttack()).succeeded, isTrue);
    expect(again.encounter?.turn ?? live.turn + 1, live.turn + 1);
  });

  test(
    'defeat retreats the player to Haven\'s Rest and loses nothing',
    () async {
      // Unarmed and unarmoured: attack 1 against a flurry is not a fight the
      // starting kit wins.
      final StrideSession s = await atWoods(armed: false);
      final int bankedBefore = s.usableEnergy;
      final List<InventoryEntry> inventoryBefore = s.inventoryEntries;
      final List<SkillSummary> skillsBefore = s.skillSummaries;
      final CombatFigures figuresBefore = s.combatFigures;

      expect((await s.startEncounter(wolf)).succeeded, isTrue);
      final CombatBeat outcome = await fightToTheEnd(s);
      expect(outcome, isA<LostBeat>());
      expect((outcome as LostBeat).retreatToName, "Haven's Rest");

      expect(s.encounter, isNull);
      expect(s.currentLocation, haven);
      expect(s.usableEnergy, bankedBefore, reason: 'no step is spent');
      expect(
        s.inventoryEntries.map((InventoryEntry e) => (e.id, e.count)),
        inventoryBefore.map((InventoryEntry e) => (e.id, e.count)),
      );
      expect(
        s.skillSummaries.map((SkillSummary k) => (k.id, k.experience)),
        skillsBefore.map((SkillSummary k) => (k.id, k.experience)),
      );
      expect(s.combatFigures.experience, figuresBefore.experience);
      expect(s.combatFigures.attack, figuresBefore.attack);
      expect(s.combatFigures.defence, figuresBefore.defence);

      // Not driven off: back at the woods the wolf is offered again.
      expect((await s.travel(woods)).succeeded, isTrue);
      expect(s.encountersHere.single.available, isTrue);

      // And a cold reload agrees about where the player is.
      final StrideSession again = await launch();
      expect(again.encounter, isNull);
      expect(again.currentLocation, woods);
    },
  );

  test(
    'eating heals and consumes exactly one, and retreat is a choice',
    () async {
      final StrideSession s = await launch(steps: 5000);
      await s.syncSteps();
      await s.syncSteps();
      // Two gathers at the meadow, one broth from three herbs.
      expect((await s.gather(meadowPatch)).succeeded, isTrue);
      expect((await s.gather(meadowPatch)).succeeded, isTrue);
      final CraftReport broth = await s.craft(herbBrothRecipe);
      expect(broth.succeeded, isTrue, reason: '${broth.rejection}');
      expect(s.inventoryCount(herbBroth), 1);
      expect((await s.equip(trainingSword)).succeeded, isTrue);
      expect((await s.equip(tunic)).succeeded, isTrue);
      expect((await s.travel(woods)).succeeded, isTrue);

      expect((await s.startEncounter(wolf)).succeeded, isTrue);
      expect(
        (await s.combatEat(herbBroth)).rejection,
        'health_full',
        reason: 'a fight starts at full health',
      );
      expect(s.inventoryCount(herbBroth), 1, reason: 'a refusal eats nothing');
      expect(
        s.edibles.map((EdibleOption e) => (e.itemId, e.count)),
        <(ContentId, int)>[(herbBroth, 1)],
      );

      // Take a round of bites, then eat.
      expect((await s.combatAttack()).succeeded, isTrue);
      final int hpBefore = s.encounter!.playerHp;
      expect(hpBefore, lessThan(40));
      final CombatReport ate = await s.combatEat(herbBroth);
      expect(ate.succeeded, isTrue, reason: '${ate.rejection}: ${ate.detail}');
      final ConsumableUsedBeat used = ate.events
          .whereType<ConsumableUsedBeat>()
          .single;
      expect(used.itemName, 'Herb Broth');
      expect(used.healed, greaterThan(0));
      expect(used.healed, lessThanOrEqualTo(12));
      expect(used.playerHpAfter, hpBefore + used.healed);
      expect(s.inventoryCount(herbBroth), 0, reason: 'exactly one consumed');
      expect(s.edibles, isEmpty);
      // The enemy replied after the meal: the committed HP is the last strike's.
      expect(
        s.encounter!.playerHp,
        ate.events.whereType<EnemyStruckBeat>().last.playerHpAfter,
      );

      final CombatReport left = await s.combatRetreat();
      expect(left.succeeded, isTrue);
      expect(left.outcome, isA<RetreatedBeat>());
      expect((left.outcome as RetreatedBeat).retreatToName, "Haven's Rest");
      expect(s.encounter, isNull);
      expect(s.currentLocation, haven);
      expect(s.inventoryCount(herbBroth), 0, reason: 'eaten stays eaten');
    },
  );

  test('a stale session refuses combat as session_not_ready', () async {
    final StrideSession s = await atWoods();
    expect((await s.startEncounter(wolf)).succeeded, isTrue);
    // A second writer over the same root advances the durable head; the first
    // session's next commit is refused and it marks itself stale.
    final StrideSession other = await launch();
    expect((await other.combatAttack()).succeeded, isTrue);
    final CombatReport refused = await s.combatAttack();
    expect(refused.succeeded, isFalse);
    expect(refused.rejection, 'commit_refused');
    expect(s.isStale, isTrue);
    expect((await s.combatAttack()).rejection, 'session_not_ready');
    expect(s.encountersHere.single.reason, 'encounter_in_progress');
    await s.reload();
    expect(s.isStale, isFalse);
    expect(s.encounter!.turn, other.encounter!.turn);
  });
}
