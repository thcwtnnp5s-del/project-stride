// The Veteran Hunts (`DECISIONS/0028`): four named elites that finally put
// the shipped combat systems under load. These proofs pin the DESIGN claims,
// not just the mechanism:
//
// - the gate: a veteran refuses below Known and offers at Known (production
//   content, not a fixture — the rails test covers the synthetic case);
// - the Foreman is brace-or-lose: from the same state, braced telegraphs win
//   and attack-only loses (deterministic — the seed is a pure function of
//   the starting state, so each policy's walk is one reproducible fight);
// - the Matriarch makes alpine armor beat raw power for the first time;
// - the Awakened falls to the full kit — best gear plus provisions — and
//   not to gear alone;
// - a veteran drops no signature (the elite signature roll ships OFF) and
//   its bounty pays exactly once.
//
// The states are built directly and handed to the engine, exactly as a
// decoded save would be (the combat_test.dart pattern).

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'content_test_support.dart';

final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId mine = ContentId.unchecked('location.stonefall_mine');
final ContentId frostmere = ContentId.unchecked('location.frostmere');
final ContentId hollow = ContentId.unchecked('location.forgotten_hollow');
final ContentId haven = ContentId.unchecked('location.havens_rest');

final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId goblin = ContentId.unchecked('enemy.cave_goblin');
final ContentId lynx = ContentId.unchecked('enemy.frost_lynx');
final ContentId guardian = ContentId.unchecked('enemy.hollow_guardian');

final ContentId oldGrey = ContentId.unchecked('enemy.old_grey');
final ContentId foreman = ContentId.unchecked('enemy.gallery_foreman');
final ContentId matriarch = ContentId.unchecked('enemy.rimeclaw_matriarch');
final ContentId awakened = ContentId.unchecked('enemy.guardian_awakened');

final ContentId longsword = ContentId.unchecked('item.bronze_longsword');
final ContentId bearhide = ContentId.unchecked('item.bearhide_coat');
final ContentId scalewarmed = ContentId.unchecked('item.scalewarmed_chestplate');
final ContentId expeditionStew = ContentId.unchecked('item.expedition_stew');
final ContentId heartyStew = ContentId.unchecked('item.hearty_stew');

final ContentRegistry registry = loadProduction(productionSource).requireRegistry;

/// A late-game player standing at [location] with the base species Known,
/// wearing [weapon]/[armor], carrying [food] — the persona these fights are
/// tuned against.
GameEngine hunter(
  ContentId location, {
  required ContentId knownBase,
  ContentId? weapon,
  ContentId? armor,
  Map<ContentId, int> food = const <ContentId, int>{},
  int experience = 3650,
}) {
  final GameEngine fresh = GameEngine.newGame(registry: registry);
  Inventory inventory = fresh.state.inventory;
  for (final MapEntry<ContentId, int> e in food.entries) {
    inventory = inventory.adding(e.key, e.value);
  }
  if (weapon != null) inventory = inventory.adding(weapon, 1);
  if (armor != null) inventory = inventory.adding(armor, 1);
  final int level = CombatRules.levelFor(experience);
  final GameState state = fresh.state.copyWith(
    inventory: inventory,
    equipment: Equipment(<EquipmentSlot, ContentId>{
      EquipmentSlot.weapon: ?weapon,
      EquipmentSlot.armor: ?armor,
    }),
    player: PlayerState(
      level: level,
      experience: experience,
      hp: CombatRules.maxHpFor(level),
    ),
    world: WorldState(
      currentLocation: location,
      unlockedLocations: <ContentId>{haven, location},
    ),
    progress: fresh.state.progress.copyWith(
      enemyVictories: <ContentId, int>{
        knownBase: registry.enemies[knownBase]!.knownAt,
      },
    ),
  );
  return GameEngine(registry: registry, state: state);
}

/// Fights to the end under a policy: when [braceTelegraphs] and the enemy's
/// heavy is telegraphed, brace; when HP falls to [eatAt] and [food] is held,
/// eat; otherwise attack. Returns true on victory, false on defeat.
bool fight(
  GameEngine engine,
  ContentId enemy, {
  bool braceTelegraphs = false,
  ContentId? food,
  int eatAt = 20,
  int maxRounds = 120,
}) {
  final EngineResult start = engine.execute(StartEncounter(enemy: enemy));
  expect(start.isAccepted, isTrue, reason: '${start.rejection}');
  for (int i = 0; i < maxRounds && engine.state.encounter != null; i++) {
    final EncounterState e = engine.state.encounter!;
    final bool eat =
        food != null &&
        e.playerHp <= eatAt &&
        e.playerHp < e.playerMaxHp &&
        engine.state.inventory.has(food);
    final GameCommand command = eat
        ? CombatEat(item: food)
        : (braceTelegraphs && e.telegraph)
        ? const CombatBrace()
        : const CombatAttack();
    final EngineResult r = engine.execute(command);
    expect(r.isAccepted, isTrue, reason: '${r.rejection}');
    final bool won = r.events.any((GameEvent ev) => ev is EncounterWon);
    if (won) return true;
    final bool lost = r.events.any((GameEvent ev) => ev is EncounterLost);
    if (lost) return false;
  }
  fail('fight with ${enemy.value} did not resolve');
}

void main() {
  test('a veteran refuses below Known and offers at Known — production gate', () {
    // One victory short of Known: hidden rule aside, the engine refuses.
    final GameEngine below = hunter(
      woods,
      knownBase: wolf,
      weapon: longsword,
      armor: bearhide,
    );
    final GameState short = below.state.copyWith(
      progress: below.state.progress.copyWith(
        enemyVictories: <ContentId, int>{
          wolf: registry.enemies[wolf]!.knownAt - 1,
        },
      ),
    );
    final GameEngine engine = GameEngine(registry: registry, state: short);
    final EngineResult refused = engine.execute(StartEncounter(enemy: oldGrey));
    expect(refused.isAccepted, isFalse);
    expect(refused.rejection!.code, RejectionCode.enemyNotKnown);

    final GameEngine at = hunter(
      woods,
      knownBase: wolf,
      weapon: longsword,
      armor: bearhide,
    );
    expect(
      at.execute(StartEncounter(enemy: oldGrey)).isAccepted,
      isTrue,
    );
  });

  test('the Foreman is brace-or-lose for a provisioned hunter: one stew in '
      'the bag, braced telegraphs win and ignoring them loses', () {
    // Tuning finding, recorded (Q-06 evidence): against a guarded enemy,
    // brace alone never converts an attack-only loss — the forfeited attack
    // round almost exactly cancels the halved heavy (≈4–5 HP net per
    // heavy). Brace's value ACCUMULATES across a longer, provisioned
    // fight, so the honest brace-or-lose claim is made with the same one
    // stew on both sides: the only difference between the walks is the
    // telegraph answered or ignored.
    GameEngine fresh() => hunter(
      mine,
      knownBase: goblin,
      weapon: longsword,
      armor: bearhide,
      food: <ContentId, int>{heartyStew: 1},
    );
    expect(
      fight(fresh(), foreman, braceTelegraphs: true, food: heartyStew),
      isTrue,
      reason: 'braced heavies should carry the fight',
    );
    expect(
      fight(fresh(), foreman, food: heartyStew),
      isFalse,
      reason: 'ignoring the telegraph should lose the fight',
    );
  });

  test('the Matriarch makes alpine armor beat raw power', () {
    // Scale-Warmed (DEF 7, frostGuard 3) wins where Bearhide (DEF 9, no
    // guard) loses: in the alpine fight the guard is worth more than two
    // points of defence against a flurry. The first time armor choice, not
    // armor number, decides a fight.
    GameEngine with_(ContentId armor) => hunter(
      frostmere,
      knownBase: lynx,
      weapon: longsword,
      armor: armor,
    );
    expect(
      fight(with_(scalewarmed), matriarch, braceTelegraphs: true),
      isTrue,
      reason: 'frostGuard armor should carry the alpine fight',
    );
    expect(
      fight(with_(bearhide), matriarch, braceTelegraphs: true),
      isFalse,
      reason: 'raw defence without the guard should fall short',
    );
  });

  test('the Awakened falls to the full kit and not to gear alone', () {
    GameEngine geared({Map<ContentId, int> food = const <ContentId, int>{}}) =>
        hunter(
          hollow,
          knownBase: guardian,
          weapon: longsword,
          armor: bearhide,
          food: food,
        );
    expect(
      fight(
        geared(food: <ContentId, int>{expeditionStew: 2}),
        awakened,
        braceTelegraphs: true,
        food: expeditionStew,
        eatAt: 24,
      ),
      isTrue,
      reason: 'brace + provisions should win',
    );
    expect(
      fight(geared(), awakened, braceTelegraphs: true),
      isFalse,
      reason: 'gear and brace without provisions should not be enough',
    );
  });

  test('a veteran drops no signature, and its knowledge ladder still works', () {
    for (final ContentId id in <ContentId>[
      oldGrey,
      foreman,
      matriarch,
      awakened,
    ]) {
      final EnemyDefinition elite = registry.enemies[id]!;
      expect(
        elite.drops.where((EnemyDrop d) => d.signature),
        isEmpty,
        reason: '${id.value}: the elite signature roll ships OFF '
            '(`DECISIONS/0028`)',
      );
      expect(elite.requiresKnownEnemy, isNotNull);
      expect(elite.encountersPerVisit, 1);
      // Compressed study: a named individual is understood fast.
      expect(elite.studiedAt, 1);
      expect(elite.knownAt, 2);
    }
  });

  test('a hunt inherits its quarry\'s gate: not acceptable below Known, '
      'acceptable at it', () {
    // Wave 4 finding, fixed: the four hunt cards used to bypass the Seen
    // gate entirely — visible and acceptable on the first visit, naming an
    // enemy no surface admitted existed. The gate is derived from the
    // enemy's own requiresKnownEnemy, never a second field.
    final ContractDefinition hunt = registry.contracts.values.firstWhere(
      (ContractDefinition c) => c.bountyEnemy == oldGrey,
    );
    final GameEngine below = hunter(
      woods,
      knownBase: wolf,
      weapon: longsword,
      armor: bearhide,
    );
    final GameState short = below.state.copyWith(
      progress: below.state.progress.copyWith(
        enemyVictories: <ContentId, int>{
          wolf: registry.enemies[wolf]!.knownAt - 1,
        },
      ),
    );
    final GameEngine engine = GameEngine(registry: registry, state: short);
    final EngineResult refused = engine.execute(
      AcceptContract(contract: hunt.id),
    );
    expect(refused.isAccepted, isFalse);
    expect(refused.rejection!.code, RejectionCode.contractNotAvailable);
    expect(refused.rejection!.explanation, contains('Known'));

    final GameEngine at = hunter(
      woods,
      knownBase: wolf,
      weapon: longsword,
      armor: bearhide,
    );
    expect(
      at.execute(AcceptContract(contract: hunt.id)).isAccepted,
      isTrue,
    );
  });

  test('an elite bounty pays exactly once — regional class with bountyEnemy', () {
    final List<ContractDefinition> hunts = registry.contracts.values
        .where(
          (ContractDefinition c) =>
              c.bountyEnemy != null &&
              <ContentId>[oldGrey, foreman, matriarch, awakened]
                  .contains(c.bountyEnemy),
        )
        .toList();
    expect(hunts, hasLength(4), reason: 'one hunt per veteran');
    for (final ContractDefinition hunt in hunts) {
      expect(
        hunt.isRepeatable,
        isFalse,
        reason: '${hunt.id.value}: a hunt is an accomplishment, paid once '
            '(`DECISIONS/0028` — its character XP is in the one-time band)',
      );
      expect(hunt.rewardCharacterXp, greaterThan(0));
    }
  });
}
