// Combat Slice 01: the first playable encounter loop.
//
// The contract is `GAME_BIBLE/COMBAT/02_COMBAT_SLICE_01.md`; the record is
// `DECISIONS/0020_COMBAT_SLICE_01.md`. Every figure asserted here is
// PROVISIONAL test balance — the *shape* of each assertion (a refusal code, an
// event sequence, an invariant) is what the slice guarantees; the numbers move
// when the owner plays it.
//
// Most of these tests build a state directly and hand it to `GameEngine`, the
// same way the bootstrap does with a decoded save. That is deliberate: getting
// the player to Stonefall Mine with a Bronze Sword through gather → craft →
// travel is proven elsewhere (`craft_test.dart`, `travel_test.dart`,
// `world_graph_test.dart`), and re-walking it here would make every combat
// assertion depend on the crafting economy.

import 'dart:convert';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'bootstrap_test.dart'
    show MemoryIdentityStore, boot, liveIdentity, qaRegistry;
import 'save_support.dart';
import 'step_support.dart';

// -- Content ids ------------------------------------------------------------

final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId goblin = ContentId.unchecked('enemy.cave_goblin');
final ContentId guardian = ContentId.unchecked('enemy.hollow_guardian');
final ContentId lynx = ContentId.unchecked('enemy.frost_lynx');

final ContentId haven = ContentId.unchecked('location.havens_rest');
final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId mine = ContentId.unchecked('location.stonefall_mine');
final ContentId frostmere = ContentId.unchecked('location.frostmere');
final ContentId hollow = ContentId.unchecked('location.forgotten_hollow');

final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId trainingAxe = ContentId.unchecked('item.training_axe');
final ContentId bronzeSword = ContentId.unchecked('item.bronze_sword');
final ContentId tunic = ContentId.unchecked('item.traveler_tunic');
final ContentId chestplate = ContentId.unchecked('item.bronze_chestplate');
final ContentId herbBroth = ContentId.unchecked('item.herb_broth');
final ContentId heartyStew = ContentId.unchecked('item.hearty_stew');
final ContentId oakLog = ContentId.unchecked('item.oak_log');
final ContentId meadowHerb = ContentId.unchecked('item.meadow_herb');
final ContentId wolfPelt = ContentId.unchecked('item.wolf_pelt');
final ContentId lynxPelt = ContentId.unchecked('item.lynx_pelt');
final ContentId rimeBlossom = ContentId.unchecked('item.rime_blossom');

final ContentId oakStand = ContentId.unchecked('resource_node.oak_stand');

// -- Builders ---------------------------------------------------------------

/// One production registry for the whole file; loading it reads the bundle.
final ContentRegistry registry = stepRegistry;

/// A player standing at [location], with the starting loadout plus
/// [extraItems], wearing [weapon] and [armor], at [experience] character XP,
/// with [banked] steps. Built as a state and handed to the engine, exactly as
/// a decoded save would be.
GameEngine playerAt(
  ContentId location, {
  Map<ContentId, int> extraItems = const <ContentId, int>{},
  ContentId? weapon,
  ContentId? armor,
  int experience = 0,
  int banked = 0,
  ContentRegistry? content,
}) {
  final ContentRegistry reg = content ?? registry;
  final GameEngine fresh = GameEngine.newGame(registry: reg);
  if (banked > 0) {
    fresh.execute(GrantSyntheticSteps(steps: banked, reason: 'combat test'));
  }
  Inventory inventory = fresh.state.inventory;
  for (final MapEntry<ContentId, int> e in extraItems.entries) {
    inventory = inventory.adding(e.key, e.value);
  }
  final GameState state = fresh.state.copyWith(
    inventory: inventory,
    equipment: Equipment(<EquipmentSlot, ContentId>{
      EquipmentSlot.weapon: ?weapon,
      EquipmentSlot.armor: ?armor,
    }),
    player: PlayerState(
      level: CombatRules.levelFor(experience),
      experience: experience,
    ),
    world: WorldState(
      currentLocation: location,
      unlockedLocations: <ContentId>{haven, location},
    ),
  );
  return GameEngine(registry: reg, state: state);
}

/// The default first fight: starting loadout, Training Sword and Tunic worn,
/// standing in the Whispering Woods.
GameEngine woodsWithStartingLoadout({int experience = 0}) => playerAt(
  woods,
  weapon: trainingSword,
  armor: tunic,
  experience: experience,
);

/// Attacks until the encounter resolves, returning every result in order.
List<EngineResult> fightToTheEnd(GameEngine engine, {int maxRounds = 60}) {
  final List<EngineResult> results = <EngineResult>[];
  for (int i = 0; i < maxRounds && engine.state.encounter != null; i++) {
    final EngineResult r = engine.execute(const CombatAttack());
    expect(r.isAccepted, isTrue, reason: '${r.rejection}');
    results.add(r);
  }
  expect(engine.state.encounter, isNull, reason: 'fight did not resolve');
  return results;
}

List<GameEvent> eventsOf(Iterable<EngineResult> results) => <GameEvent>[
  for (final EngineResult r in results) ...r.events,
];

T lastEvent<T extends GameEvent>(Iterable<EngineResult> results) =>
    eventsOf(results).whereType<T>().last;

RejectionCode? codeOf(EngineResult r) => r.rejection?.code;

/// How many fights with [enemy] one visit holds, read from the shipped pack
/// rather than restated — the figures are provisional balance and the rule
/// under test is the count, not the number.
int perVisit(ContentId enemy) => registry.enemies[enemy]!.encountersPerVisit;

/// Everything about a state that a fight must not touch: the ledger, skills,
/// equipment, unlocked locations. Inventory and location are compared by the
/// caller because they legitimately move.
void expectUntouchedByCombat(GameState before, GameState after) {
  expect(after.steps, before.steps, reason: 'no step is spent or granted');
  expect(after.skills, before.skills, reason: 'no skill XP moves');
  expect(after.equipment, before.equipment);
  expect(after.world.unlockedLocations, before.world.unlockedLocations);
}

void main() {
  group('CombatRules — the resolver is pure and bounded', () {
    test('roll is always in {-1, 0, +1} and every value occurs', () {
      final Set<int> seen = <int>{};
      for (int seed = 0; seed < 40; seed++) {
        for (int turn = 1; turn <= 20; turn++) {
          for (int salt = 0; salt < 4; salt++) {
            final int r = CombatRules.roll(seed * 7919, turn, salt);
            expect(r, inInclusiveRange(-1, 1));
            seen.add(r);
          }
        }
      }
      expect(seen, <int>{-1, 0, 1});
    });

    test('percentRoll is always in 0..99', () {
      for (int seed = 0; seed < 200; seed++) {
        for (int i = 0; i < 4; i++) {
          expect(
            CombatRules.percentRoll(seed * 104729, i, 5),
            inInclusiveRange(0, 99),
          );
        }
      }
    });

    test('rolls are a pure function of (seed, turn, salt)', () {
      expect(CombatRules.roll(12345, 3, 1), CombatRules.roll(12345, 3, 1));
      expect(
        CombatRules.seedFor(10, wolf),
        CombatRules.seedFor(10, wolf),
        reason: 'the seed is derived, never drawn',
      );
      expect(
        CombatRules.seedFor(10, wolf),
        isNot(CombatRules.seedFor(10, goblin)),
        reason: 'two enemies started at the same point get their own script',
      );
      expect(
        CombatRules.seedFor(10, wolf),
        isNot(CombatRules.seedFor(11, wolf)),
      );
    });

    test('strike never deals less than 1, and heavy ignores the roll', () {
      expect(CombatRules.strike(1, 4, -1), 1);
      expect(CombatRules.strike(1, 4, 1), 1);
      expect(CombatRules.strike(9, 3, -1), 5);
      expect(CombatRules.strike(9, 3, 1), 7);
      expect(CombatRules.heavyStrike(11, 7), 15);
      expect(CombatRules.heavyStrike(1, 40), 1);
      expect(CombatRules.isHeavyTurn(3), isTrue);
      expect(CombatRules.isHeavyTurn(6), isTrue);
      expect(CombatRules.isHeavyTurn(1), isFalse);
      expect(CombatRules.isHeavyTurn(2), isFalse);
    });

    test('level thresholds, max HP and the attack bonus (provisional)', () {
      expect(CombatRules.levelFor(0), 1);
      expect(CombatRules.levelFor(99), 1);
      expect(CombatRules.levelFor(100), 2);
      expect(CombatRules.levelFor(299), 2);
      expect(CombatRules.levelFor(300), 3);
      expect(CombatRules.levelFor(4500), 10);
      expect(CombatRules.levelFor(999999), 10, reason: 'level 10 is the cap');
      expect(CombatRules.maxHpFor(1), 40);
      expect(CombatRules.maxHpFor(3), 48);
      expect(CombatRules.maxHpFor(10), 76);
      expect(CombatRules.attackBonusFor(1), 0);
      expect(CombatRules.attackBonusFor(2), 0);
      expect(CombatRules.attackBonusFor(3), 1);
      expect(CombatRules.attackBonusFor(10), 4);
    });

    test('loadoutFor: weapon and armour slots count, tools never do', () {
      PlayerCombatLoadout loadout({
        ContentId? weapon,
        ContentId? armor,
        int experience = 0,
      }) => CombatRules.loadoutFor(
        playerAt(
          woods,
          weapon: weapon,
          armor: armor,
          experience: experience,
        ).state,
        registry,
      );

      expect(
        loadout(),
        const PlayerCombatLoadout(maxHp: 40, attack: 1, defence: 0),
      );
      expect(
        loadout(weapon: trainingSword, armor: tunic),
        PlayerCombatLoadout(
          maxHp: 40,
          attack: 3,
          defence: 2,
          weaponItem: trainingSword,
          armorItem: tunic,
        ),
      );
      expect(loadout(weapon: bronzeSword).attack, 9);
      expect(loadout(armor: chestplate).defence, 7);
      // A tool in the weapon slot is not a weapon.
      expect(loadout(weapon: trainingAxe).attack, 1);
      expect(loadout(weapon: trainingAxe).weaponItem, isNull);
      // Level 3: +8 max HP, +1 attack.
      expect(
        loadout(weapon: trainingSword, experience: 300),
        PlayerCombatLoadout(
          maxHp: 48,
          attack: 4,
          defence: 0,
          weaponItem: trainingSword,
        ),
      );
    });

    test(
      'retreatDestination is the nearest safe location, BFS, ties by id',
      () {
        ContentId from(ContentId location) =>
            CombatRules.retreatDestination(playerAt(location).state, registry);
        expect(from(haven), haven, reason: 'already safe: stay');
        expect(from(woods), haven);
        expect(from(mine), haven);
        expect(from(hollow), haven, reason: 'two hops: hollow → woods → haven');
        expect(from(frostmere), haven, reason: 'frostmere → mine → haven');
      },
    );
  });

  group('StartEncounter — eligibility, in refusal order', () {
    test('unknown enemy', () {
      final GameEngine engine = woodsWithStartingLoadout();
      final EngineResult r = engine.execute(
        StartEncounter(enemy: ContentId.unchecked('enemy.nothing')),
      );
      expect(codeOf(r), RejectionCode.unknownEnemy);
    });

    test('the enemy is not at the player\'s location', () {
      final GameEngine engine = playerAt(haven);
      final EngineResult r = engine.execute(StartEncounter(enemy: wolf));
      expect(codeOf(r), RejectionCode.enemyNotHere);
      expect(identical(r.state, engine.state), isTrue);
    });

    test('an encounter is already in progress', () {
      final GameEngine engine = woodsWithStartingLoadout();
      expect(engine.execute(StartEncounter(enemy: wolf)).isAccepted, isTrue);
      final EngineResult again = engine.execute(StartEncounter(enemy: wolf));
      expect(codeOf(again), RejectionCode.encounterInProgress);
    });

    test(
      'accepted: costs no steps, works at zero banked, snapshots the loadout',
      () {
        final GameEngine engine = woodsWithStartingLoadout();
        final GameState before = engine.state;
        expect(before.steps.banked, 0);

        final EngineResult r = engine.execute(StartEncounter(enemy: wolf));
        expect(r.isAccepted, isTrue, reason: '${r.rejection}');
        final EncounterStarted started = r.events.single as EncounterStarted;
        expect(started.enemy, wolf);
        expect(started.location, woods);
        expect(started.seed, CombatRules.seedFor(before.eventSequence, wolf));
        expect(started.playerHp, 40);
        expect(started.playerMaxHp, 40);
        expect(started.playerAttack, 3, reason: 'training sword');
        expect(started.playerDefence, 2, reason: 'traveler tunic');
        expect(started.enemyHp, 20);
        expect(started.enemyMaxHp, 20);

        final EncounterState encounter = engine.state.encounter!;
        expect(encounter.turn, 1);
        expect(encounter.telegraph, isFalse);
        expect(encounter.enemyHp, 20);
        expect(engine.state.steps, before.steps);

        // Snapshotted: swapping armour now changes nothing in this fight.
        engine.execute(const UnequipItem(slot: EquipmentSlot.armor));
        expect(engine.state.encounter!.playerDefence, 2);
      },
    );
  });

  group('one round — attack and the enemy\'s reply', () {
    test('flurry (wolf): one player strike, two enemy strikes, round ends', () {
      final GameEngine engine = woodsWithStartingLoadout();
      engine.execute(StartEncounter(enemy: wolf));
      final EncounterState e0 = engine.state.encounter!;

      final EngineResult r = engine.execute(const CombatAttack());
      expect(r.isAccepted, isTrue);
      expect(r.events.map((GameEvent e) => e.name), <String>[
        'CombatPlayerStruck',
        'CombatEnemyStruck',
        'CombatEnemyStruck',
        'CombatRoundEnded',
      ]);

      final CombatPlayerStruck hit = r.events[0] as CombatPlayerStruck;
      expect(hit.turn, 1);
      expect(
        hit.damage,
        CombatRules.strike(
          3,
          0,
          CombatRules.roll(e0.seed, 1, CombatRules.playerStrikeSalt),
        ),
      );
      expect(hit.damage, inInclusiveRange(2, 4));
      expect(hit.enemyHpAfter, 20 - hit.damage);

      final CombatEnemyStruck bite0 = r.events[1] as CombatEnemyStruck;
      final CombatEnemyStruck bite1 = r.events[2] as CombatEnemyStruck;
      expect(bite0.strikeIndex, 0);
      expect(bite1.strikeIndex, 1);
      expect(bite0.heavy, isFalse);
      expect(bite0.damage, inInclusiveRange(1, 3), reason: '4 − 2 ± 1');
      expect(bite1.damage, inInclusiveRange(1, 3));
      expect(bite0.playerHpAfter, 40 - bite0.damage);
      expect(bite1.playerHpAfter, 40 - bite0.damage - bite1.damage);

      final CombatRoundEnded ended = r.events[3] as CombatRoundEnded;
      expect(ended.turn, 2);
      expect(ended.telegraph, isFalse);

      final EncounterState e1 = engine.state.encounter!;
      expect(e1.turn, 2);
      expect(e1.enemyHp, hit.enemyHpAfter);
      expect(e1.playerHp, bite1.playerHpAfter);
    });

    test('steady (goblin): exactly one enemy strike a round', () {
      final GameEngine engine = playerAt(
        mine,
        weapon: bronzeSword,
        armor: tunic,
      );
      engine.execute(StartEncounter(enemy: goblin));
      final EngineResult r = engine.execute(const CombatAttack());
      expect(r.events.whereType<CombatEnemyStruck>(), hasLength(1));
      final CombatPlayerStruck hit = r.events.first as CombatPlayerStruck;
      expect(hit.damage, inInclusiveRange(5, 7), reason: '9 − 3 ± 1');
      final CombatEnemyStruck strike = r.events
          .whereType<CombatEnemyStruck>()
          .single;
      expect(strike.damage, inInclusiveRange(5, 7), reason: '8 − 2 ± 1');
      expect(strike.heavy, isFalse);
    });

    test(
      'guarded (guardian): heavy on turn 3, telegraphed at the end of turn 2',
      () {
        final GameEngine engine = playerAt(
          hollow,
          weapon: bronzeSword,
          armor: chestplate,
          extraItems: <ContentId, int>{bronzeSword: 1},
        );
        engine.execute(StartEncounter(enemy: guardian));

        final EngineResult t1 = engine.execute(const CombatAttack());
        final CombatEnemyStruck s1 = t1.events
            .whereType<CombatEnemyStruck>()
            .single;
        expect(s1.heavy, isFalse);
        expect(s1.damage, inInclusiveRange(3, 5), reason: '11 − 7 ± 1');
        expect((t1.events.last as CombatRoundEnded).telegraph, isFalse);
        expect(engine.state.encounter!.telegraph, isFalse);

        final EngineResult t2 = engine.execute(const CombatAttack());
        final CombatRoundEnded end2 = t2.events.last as CombatRoundEnded;
        expect(end2.turn, 3);
        expect(end2.telegraph, isTrue, reason: 'the round before a heavy turn');
        expect(engine.state.encounter!.telegraph, isTrue);

        final EngineResult t3 = engine.execute(const CombatAttack());
        final CombatEnemyStruck s3 = t3.events
            .whereType<CombatEnemyStruck>()
            .single;
        expect(s3.heavy, isTrue);
        expect(s3.turn, 3);
        expect(
          s3.damage,
          2 * 11 - 7,
          reason: 'heavy: 2 × attack − defence, no roll',
        );
        final CombatRoundEnded end3 = t3.events.last as CombatRoundEnded;
        expect(end3.turn, 4);
        expect(end3.telegraph, isFalse);
        expect(engine.state.encounter!.telegraph, isFalse);
      },
    );

    test('damage never drops below 1 (unarmed against the guardian)', () {
      final GameEngine engine = playerAt(
        hollow,
        extraItems: <ContentId, int>{bronzeSword: 1},
      );
      engine.execute(StartEncounter(enemy: guardian));
      final EngineResult r = engine.execute(const CombatAttack());
      final CombatPlayerStruck hit = r.events.first as CombatPlayerStruck;
      expect(hit.damage, 1, reason: 'max(1, 1 − 4 ± 1)');
    });

    test('armour changes what the goblin does to you: tunic vs chestplate', () {
      int damageTaken(ContentId armor) {
        final GameEngine engine = playerAt(
          mine,
          weapon: bronzeSword,
          armor: armor,
        );
        engine.execute(StartEncounter(enemy: goblin));
        return engine
            .execute(const CombatAttack())
            .events
            .whereType<CombatEnemyStruck>()
            .single
            .damage;
      }

      // Same seed either way (same event sequence, same enemy), so the roll is
      // identical and only the defence differs.
      final int withTunic = damageTaken(tunic);
      final int withChestplate = damageTaken(chestplate);
      expect(withTunic, inInclusiveRange(5, 7));
      expect(
        withChestplate,
        inInclusiveRange(1, 2),
        reason: 'max(1, 8 − 7 ± 1)',
      );
      expect(withTunic - withChestplate, 5);
    });

    test(
      'a weapon changes what you do to the goblin: training vs bronze vs unarmed',
      () {
        int damageDealt(ContentId? weapon) {
          final GameEngine engine = playerAt(
            mine,
            weapon: weapon,
            armor: tunic,
          );
          engine.execute(StartEncounter(enemy: goblin));
          return (engine.execute(const CombatAttack()).events.first
                  as CombatPlayerStruck)
              .damage;
        }

        final int unarmed = damageDealt(null);
        final int training = damageDealt(trainingSword);
        final int bronze = damageDealt(bronzeSword);
        expect(unarmed, 1, reason: 'max(1, 1 − 3 ± 1)');
        expect(training, inInclusiveRange(1, 1), reason: 'max(1, 3 − 3 ± 1)');
        expect(bronze, inInclusiveRange(5, 7));
        expect(bronze - training, greaterThanOrEqualTo(4));
      },
    );

    test('a level-3 character has 48 HP and +1 attack in the snapshot', () {
      final GameEngine engine = woodsWithStartingLoadout(experience: 300);
      final EncounterStarted started =
          engine.execute(StartEncounter(enemy: wolf)).events.single
              as EncounterStarted;
      expect(started.playerMaxHp, 48);
      expect(started.playerHp, 48);
      expect(started.playerAttack, 4);
    });
  });

  group('CombatEat', () {
    GameEngine damagedInTheWoods({
      Map<ContentId, int> food = const <ContentId, int>{},
    }) {
      final GameEngine engine = playerAt(
        woods,
        weapon: trainingSword,
        armor: tunic,
        extraItems: food,
      );
      engine.execute(StartEncounter(enemy: wolf));
      // One round: the wolf always lands at least 2 across its two bites.
      engine.execute(const CombatAttack());
      expect(engine.state.encounter!.playerHp, lessThan(40));
      return engine;
    }

    test(
      'heals min(healing, missing), consumes exactly one, spends the turn',
      () {
        final GameEngine engine = damagedInTheWoods(
          food: <ContentId, int>{herbBroth: 2},
        );
        final EncounterState before = engine.state.encounter!;
        final int missing = before.playerMaxHp - before.playerHp;

        final EngineResult r = engine.execute(CombatEat(item: herbBroth));
        expect(r.isAccepted, isTrue, reason: '${r.rejection}');
        final CombatConsumableUsed used =
            r.events.first as CombatConsumableUsed;
        expect(used.item, herbBroth);
        expect(used.healed, missing < 12 ? missing : 12);
        expect(used.playerHpAfter, before.playerHp + used.healed);
        expect(used.turn, before.turn);
        expect(
          engine.state.inventory.quantityOf(herbBroth),
          1,
          reason: 'exactly one eaten',
        );

        // The turn was spent: the wolf still bites, and the turn advances.
        expect(r.events.whereType<CombatEnemyStruck>(), hasLength(2));
        expect((r.events.last as CombatRoundEnded).turn, before.turn + 1);
        expect(engine.state.encounter!.turn, before.turn + 1);
      },
    );

    test('a big meal is capped at the missing HP', () {
      final GameEngine engine = damagedInTheWoods(
        food: <ContentId, int>{heartyStew: 1},
      );
      final EncounterState before = engine.state.encounter!;
      final CombatConsumableUsed used =
          engine.execute(CombatEat(item: heartyStew)).events.first
              as CombatConsumableUsed;
      expect(used.healed, before.playerMaxHp - before.playerHp);
      expect(used.playerHpAfter, before.playerMaxHp);
    });

    test(
      'refusals, in order: no encounter, unknown, not owned, not edible, full',
      () {
        final GameEngine idle = woodsWithStartingLoadout();
        expect(
          codeOf(idle.execute(CombatEat(item: herbBroth))),
          RejectionCode.noEncounter,
        );

        final GameEngine engine = playerAt(
          woods,
          weapon: trainingSword,
          armor: tunic,
          extraItems: <ContentId, int>{oakLog: 1, herbBroth: 1},
        );
        engine.execute(StartEncounter(enemy: wolf));
        expect(
          codeOf(
            engine.execute(
              CombatEat(item: ContentId.unchecked('item.nothing')),
            ),
          ),
          RejectionCode.unknownItem,
        );
        expect(
          codeOf(engine.execute(CombatEat(item: heartyStew))),
          RejectionCode.itemNotOwned,
        );
        expect(
          codeOf(engine.execute(CombatEat(item: oakLog))),
          RejectionCode.notEdible,
        );
        expect(
          codeOf(engine.execute(CombatEat(item: trainingSword))),
          RejectionCode.notEdible,
        );
        expect(
          codeOf(engine.execute(CombatEat(item: herbBroth))),
          RejectionCode.healthFull,
          reason: 'turn 1, nothing has happened yet',
        );
        expect(
          engine.state.inventory.quantityOf(herbBroth),
          1,
          reason: 'a refusal eats nothing',
        );
        expect(
          engine.state.encounter!.turn,
          1,
          reason: 'a refusal spends no turn',
        );
      },
    );
  });

  group('CombatRetreat', () {
    test(
      'moves the player to the nearest safe location and changes nothing else',
      () {
        final GameEngine engine = woodsWithStartingLoadout();
        engine.execute(StartEncounter(enemy: wolf));
        engine.execute(const CombatAttack());
        final GameState before = engine.state;

        final EngineResult r = engine.execute(const CombatRetreat());
        expect(r.isAccepted, isTrue);
        final EncounterRetreated retreated =
            r.events.single as EncounterRetreated;
        expect(retreated.enemy, wolf);
        expect(retreated.location, woods);
        expect(retreated.retreatTo, haven);

        final GameState after = engine.state;
        expect(after.encounter, isNull);
        expect(after.world.currentLocation, haven);
        expect(
          after.world.visitVictories,
          isEmpty,
          reason: 'retreat counts no victory',
        );
        expect(after.inventory, before.inventory);
        expect(after.player, before.player);
        expectUntouchedByCombat(before, after);
      },
    );

    test('is refused with no encounter', () {
      expect(
        codeOf(woodsWithStartingLoadout().execute(const CombatRetreat())),
        RejectionCode.noEncounter,
      );
      expect(
        codeOf(woodsWithStartingLoadout().execute(const CombatAttack())),
        RejectionCode.noEncounter,
      );
    });
  });

  group('victory', () {
    test(
      'one EncounterWon carries XP, level and drops; the visit count moves',
      () {
        final GameEngine engine = woodsWithStartingLoadout();
        final GameState before = engine.state;
        engine.execute(StartEncounter(enemy: wolf));
        final int seed = engine.state.encounter!.seed;

        final List<EngineResult> rounds = fightToTheEnd(engine);
        final EncounterWon won = lastEvent<EncounterWon>(rounds);
        final EngineResult last = rounds.last;
        expect(last.events.last, same(won));
        expect(
          last.events.whereType<CombatEnemyStruck>(),
          isEmpty,
          reason:
              'the round ends at the killing blow; the enemy does not reply',
        );
        expect(last.events.whereType<CombatRoundEnded>(), isEmpty);

        expect(won.enemy, wolf);
        expect(won.location, woods);
        expect(won.characterXp, 30);
        expect(won.experienceAfter, 30);
        expect(won.levelBefore, 1);
        expect(won.levelAfter, 1);
        // Drops are a pure function of the seed, by declaration order:
        // meadow herb ×1 at 60% (index 0), wolf pelt ×1 at 45% (index 1).
        final int winningTurn = (last.events.first as CombatPlayerStruck).turn;
        final bool herbDrops =
            CombatRules.percentRoll(seed, 0, winningTurn) < 60;
        final bool peltDrops =
            CombatRules.percentRoll(seed, 1, winningTurn) < 45;
        expect(won.drops, <ContentId, int>{
          if (herbDrops) meadowHerb: 1,
          if (peltDrops) wolfPelt: 1,
        });

        final GameState after = engine.state;
        expect(after.encounter, isNull);
        expect(after.player, const PlayerState(level: 1, experience: 30));
        expect(
          after.inventory.quantityOf(meadowHerb),
          before.inventory.quantityOf(meadowHerb) + (herbDrops ? 1 : 0),
        );
        expect(
          after.inventory.quantityOf(wolfPelt),
          before.inventory.quantityOf(wolfPelt) + (peltDrops ? 1 : 0),
        );
        expect(
          after.world.currentLocation,
          woods,
          reason: 'a win does not move you',
        );
        // One victory of the two this visit allows (`DECISIONS/0021` §1).
        expect(after.world.victoriesThisVisit(wolf), 1);
        expect(after.world.remaining(wolf, perVisit(wolf)), 1);
        expect(after.world.isAvailable(wolf, perVisit(wolf)), isTrue);
        expectUntouchedByCombat(before, after);
      },
    );

    test('a visit holds exactly the authored number of fights', () {
      final GameEngine engine = woodsWithStartingLoadout();
      expect(perVisit(wolf), 2, reason: 'the content this test is about');

      // First fight: allowed, rewards once.
      engine.execute(StartEncounter(enemy: wolf));
      fightToTheEnd(engine);
      expect(engine.state.player.experience, 30);
      expect(engine.state.world.victoriesThisVisit(wolf), 1);

      // Second fight, same visit, no travel between them: allowed, and it
      // rewards once more. This is the whole change — the owner's "too
      // restrictive" was one fight per visit, not one reward per fight.
      expect(engine.execute(StartEncounter(enemy: wolf)).isAccepted, isTrue);
      fightToTheEnd(engine);
      expect(engine.state.player.experience, 60);
      expect(engine.state.world.victoriesThisVisit(wolf), 2);

      // Third: refused, with the unchanged wire code.
      expect(
        codeOf(engine.execute(StartEncounter(enemy: wolf))),
        RejectionCode.enemyDrivenOff,
      );
      expect(engine.state.world.remaining(wolf, perVisit(wolf)), 0);
      expect(engine.state.world.isAvailable(wolf, perVisit(wolf)), isFalse);

      // Travel away and back: available again, and the count is reset rather
      // than decremented — leaving costs the walk, which is the limiter
      // (`RULES.md` P-4).
      engine.execute(EnterLocation(location: haven));
      expect(
        engine.state.world.visitVictories,
        isEmpty,
        reason: 'any move empties the map',
      );
      engine.execute(EnterLocation(location: woods));
      expect(engine.state.world.victoriesThisVisit(wolf), 0);
      expect(engine.execute(StartEncounter(enemy: wolf)).isAccepted, isTrue);
    });

    test('a boss authors one fight a visit, and is spent after it', () {
      // The Hollow Guardian keeps `encountersPerVisit: 1`, which is exactly
      // the `DECISIONS/0020` rule: a different recurrence policy needs no
      // framework, only a smaller number.
      expect(perVisit(guardian), 1);
      final GameEngine engine = playerAt(
        hollow,
        weapon: bronzeSword,
        armor: chestplate,
        experience: 4500,
        extraItems: <ContentId, int>{heartyStew: 6},
      );
      engine.execute(StartEncounter(enemy: guardian));
      final List<EngineResult> rounds = fightToTheEnd(engine, maxRounds: 60);
      expect(
        rounds.last.events.last,
        isA<EncounterWon>(),
        reason: 'a level-10 player in bronze must be able to take the boss',
      );
      expect(engine.state.world.victoriesThisVisit(guardian), 1);
      expect(
        engine.state.world.isAvailable(guardian, perVisit(guardian)),
        isFalse,
      );
      expect(
        codeOf(engine.execute(StartEncounter(enemy: guardian))),
        RejectionCode.enemyDrivenOff,
      );
    });

    test('the Frost Lynx gives Frostmere a fight, twice a visit', () {
      // The one region that had no combat (`DECISIONS/0021` §1). Bronze is the
      // stated requirement, so that is what it is fought with.
      expect(perVisit(lynx), 2);
      final GameEngine engine = playerAt(
        frostmere,
        weapon: bronzeSword,
        armor: chestplate,
        experience: 600,
      );
      expect(engine.execute(StartEncounter(enemy: lynx)).isAccepted, isTrue);
      final EncounterWon won = lastEvent<EncounterWon>(
        fightToTheEnd(engine, maxRounds: 60),
      );
      expect(won.enemy, lynx);
      expect(won.location, frostmere);
      expect(won.characterXp, 80);
      expect(engine.state.world.victoriesThisVisit(lynx), 1);
      expect(engine.state.world.isAvailable(lynx, perVisit(lynx)), isTrue);

      // Its drops are the two Frostmere materials, and nothing else can be in
      // the map — a drop the enemy does not author would be a reducer defect.
      for (final ContentId item in won.drops.keys) {
        expect(<ContentId>[rimeBlossom, lynxPelt], contains(item));
      }
    });

    test('replaying the log applies each visit\'s rewards once, in order', () {
      final GameEngine engine = woodsWithStartingLoadout();
      final GameState pre = engine.state;
      final List<GameEvent> events = <GameEvent>[];

      // Two fights this visit, a round trip, then a third.
      for (int i = 0; i < 2; i++) {
        events
          ..addAll(engine.execute(StartEncounter(enemy: wolf)).events)
          ..addAll(eventsOf(fightToTheEnd(engine)));
      }
      events
        ..addAll(engine.execute(EnterLocation(location: haven)).events)
        ..addAll(engine.execute(EnterLocation(location: woods)).events)
        ..addAll(engine.execute(StartEncounter(enemy: wolf)).events)
        ..addAll(eventsOf(fightToTheEnd(engine)));

      expect(events.whereType<EncounterWon>(), hasLength(3));
      expect(engine.state.player.experience, 90);
      expect(engine.state.world.victoriesThisVisit(wolf), 1);

      final GameState replayed = const EventReducer().applyAll(pre, events);
      expect(replayed, engine.state);
      expect(
        canonicalDurableGameState(replayed),
        canonicalDurableGameState(engine.state),
      );
      expect(
        replayed.player.experience,
        90,
        reason: 'three victories, three rewards — not three per replay',
      );
      expect(
        replayed.world.visitVictories,
        engine.state.world.visitVictories,
        reason: 'the moves in the log clear the map on replay too',
      );
    });

    test('an EncounterWon does not duplicate across the journal codec', () {
      final GameEngine engine = woodsWithStartingLoadout();
      final GameState pre = engine.state;
      final List<GameEvent> events = <GameEvent>[
        ...engine.execute(StartEncounter(enemy: wolf)).events,
        ...eventsOf(fightToTheEnd(engine)),
      ];

      // Encode every event, decode it back, and reduce the decoded log onto
      // the same starting state. A codec that dropped or doubled a drop, or a
      // reducer that counted the victory twice, lands somewhere else.
      final List<GameEvent> roundTripped = <GameEvent>[
        for (final GameEvent e in events)
          decodeEvent(
            jsonDecode(canonicalJson(encodeEvent(e))) as Map<String, Object?>,
          )!,
      ];
      final GameState fromDecoded = const EventReducer().applyAll(
        pre,
        roundTripped,
      );

      expect(fromDecoded, engine.state);
      expect(fromDecoded.world.victoriesThisVisit(wolf), 1);
      expect(fromDecoded.inventory, engine.state.inventory);
    });

    test('a victory over a level threshold levels the character', () {
      final GameEngine engine = woodsWithStartingLoadout(experience: 90);
      engine.execute(StartEncounter(enemy: wolf));
      final EncounterWon won = lastEvent<EncounterWon>(fightToTheEnd(engine));
      expect(won.experienceAfter, 120);
      expect(won.levelBefore, 1);
      expect(won.levelAfter, 2);
      expect(engine.state.player, const PlayerState(level: 2, experience: 120));
      // The next fight snapshots the new level's HP.
      engine.execute(EnterLocation(location: haven));
      engine.execute(EnterLocation(location: woods));
      final EncounterStarted next =
          engine.execute(StartEncounter(enemy: wolf)).events.single
              as EncounterStarted;
      expect(next.playerMaxHp, 44);
    });

    test('the visit count resets after paid travel too', () {
      final GameEngine engine = playerAt(
        woods,
        weapon: trainingSword,
        armor: tunic,
        banked: 2000,
      );
      // Spend the whole visit, so the reset is the thing being observed and
      // not a count that had room left anyway.
      for (int i = 0; i < perVisit(wolf); i++) {
        expect(engine.execute(StartEncounter(enemy: wolf)).isAccepted, isTrue);
        fightToTheEnd(engine);
      }
      expect(engine.state.world.isAvailable(wolf, perVisit(wolf)), isFalse);
      expect(engine.execute(TravelTo(destination: haven)).isAccepted, isTrue);
      expect(engine.state.world.visitVictories, isEmpty);
      expect(engine.execute(TravelTo(destination: woods)).isAccepted, isTrue);
      expect(engine.execute(StartEncounter(enemy: wolf)).isAccepted, isTrue);
    });

    test(
      'replaying the events reproduces the state — the reward lands once',
      () {
        final GameEngine engine = woodsWithStartingLoadout();
        final GameState pre = engine.state;
        final List<GameEvent> events = <GameEvent>[
          ...engine.execute(StartEncounter(enemy: wolf)).events,
          ...eventsOf(fightToTheEnd(engine)),
        ];
        expect(events.whereType<EncounterWon>(), hasLength(1));

        final GameState replayed = const EventReducer().applyAll(pre, events);
        expect(replayed, engine.state);
        expect(
          canonicalDurableGameState(replayed),
          canonicalDurableGameState(engine.state),
        );
        expect(replayed.player.experience, 30, reason: 'once, not per replay');
      },
    );

    test('the QA profile scales enemy health and XP, not the reward shape', () {
      final GameEngine engine = playerAt(
        woods,
        weapon: trainingSword,
        armor: tunic,
        content: qaRegistry,
      );
      final EncounterStarted started =
          engine.execute(StartEncounter(enemy: wolf)).events.single
              as EncounterStarted;
      expect(started.enemyHp, 5, reason: '20 at enemyHealthPercent 25');
      final EncounterWon won = lastEvent<EncounterWon>(fightToTheEnd(engine));
      expect(won.characterXp, 300, reason: '30 at xpPercent 1000');
      expect(engine.state.player.level, 3);
    });
  });

  group('defeat', () {
    test(
      'the player is moved to safety and loses nothing but the food they ate',
      () {
        // Unarmed and unarmoured at level 1 against the guardian: 11 ± 1 a turn,
        // 1 damage dealt a turn — the fight cannot be won.
        final GameEngine engine = playerAt(
          hollow,
          extraItems: <ContentId, int>{bronzeSword: 1, herbBroth: 1},
        );
        final GameState before = engine.state;
        engine.execute(StartEncounter(enemy: guardian));
        engine.execute(const CombatAttack());
        expect(engine.execute(CombatEat(item: herbBroth)).isAccepted, isTrue);

        final List<EngineResult> rounds = fightToTheEnd(engine, maxRounds: 10);
        final EngineResult last = rounds.last;
        expect(last.events.last, isA<EncounterLost>());
        final EncounterLost lost = last.events.last as EncounterLost;
        expect(lost.enemy, guardian);
        expect(lost.location, hollow);
        expect(
          lost.retreatTo,
          haven,
          reason: 'hollow → woods (unsafe) → haven',
        );
        // The killing strike is the last thing before the loss; no round-end.
        expect(last.events.whereType<CombatRoundEnded>(), isEmpty);
        expect(
          (last.events[last.events.length - 2] as CombatEnemyStruck)
              .playerHpAfter,
          0,
        );

        final GameState after = engine.state;
        expect(after.encounter, isNull);
        expect(after.world.currentLocation, haven);
        expect(
          after.world.visitVictories,
          isEmpty,
          reason: 'defeat counts no victory, and the relocation clears the map',
        );
        expect(after.player, before.player, reason: 'no XP on defeat');
        expect(
          after.inventory,
          before.inventory.removing(herbBroth, 1),
          reason: 'consumables eaten stay eaten; nothing else moves',
        );
        expectUntouchedByCombat(before, after);

        // Coming back is allowed: defeat does not lock the enemy.
        engine.execute(EnterLocation(location: hollow));
        expect(
          engine.execute(StartEncounter(enemy: guardian)).isAccepted,
          isTrue,
        );
      },
    );
  });

  group('determinism', () {
    test(
      'same start state and commands twice ⇒ identical events and states',
      () {
        List<Map<String, Object?>> run() {
          final GameEngine engine = playerAt(
            mine,
            weapon: bronzeSword,
            armor: tunic,
            extraItems: <ContentId, int>{herbBroth: 2},
          );
          final List<GameEvent> events = <GameEvent>[
            ...engine.execute(StartEncounter(enemy: goblin)).events,
            ...engine.execute(const CombatAttack()).events,
            ...engine.execute(CombatEat(item: herbBroth)).events,
            ...eventsOf(fightToTheEnd(engine)),
          ];
          return <Map<String, Object?>>[
            for (final GameEvent e in events) encodeEvent(e),
            <String, Object?>{'state': canonicalDurableGameState(engine.state)},
          ];
        }

        final String a = canonicalJson(run());
        final String b = canonicalJson(run());
        expect(a, b);
      },
    );
  });

  group('while an encounter is active', () {
    test(
      'gathering and travel are refused; unknown ids still read as unknown',
      () {
        final GameEngine engine = playerAt(
          woods,
          weapon: trainingSword,
          armor: tunic,
          banked: 5000,
        );
        engine.execute(EquipItem(item: trainingAxe));
        engine.execute(StartEncounter(enemy: wolf));

        expect(
          codeOf(engine.execute(GatherResource(node: oakStand))),
          RejectionCode.encounterInProgress,
        );
        expect(
          codeOf(engine.execute(TravelTo(destination: haven))),
          RejectionCode.encounterInProgress,
        );
        expect(
          codeOf(
            engine.execute(
              GatherResource(
                node: ContentId.unchecked('resource_node.nothing'),
              ),
            ),
          ),
          RejectionCode.unknownResourceNode,
        );
        expect(
          codeOf(
            engine.execute(
              TravelTo(destination: ContentId.unchecked('location.nothing')),
            ),
          ),
          RejectionCode.unknownLocation,
        );
        expect(engine.state.steps.banked, 5000, reason: 'nothing charged');
      },
    );

    test('equipping is allowed and does not change the snapshotted fight', () {
      final GameEngine engine = playerAt(
        woods,
        weapon: trainingSword,
        armor: tunic,
        extraItems: <ContentId, int>{bronzeSword: 1},
      );
      engine.execute(StartEncounter(enemy: wolf));
      expect(engine.execute(EquipItem(item: bronzeSword)).isAccepted, isTrue);
      expect(engine.state.encounter!.playerAttack, 3);
    });
  });

  group('persistence', () {
    test(
      'a fight in progress round-trips through the codec and the journal',
      () {
        final GameEngine engine = playerAt(
          hollow,
          weapon: bronzeSword,
          armor: chestplate,
          extraItems: <ContentId, int>{bronzeSword: 1},
        );
        engine.execute(StartEncounter(enemy: guardian));
        engine.execute(const CombatAttack());
        engine.execute(const CombatAttack());
        final GameState mid = engine.state;
        expect(mid.encounter!.telegraph, isTrue);

        final Uint8List bytes = encodeSnapshot(
          state: mid,
          saveId: testSaveId,
          generation: 3,
          lastAppliedTransaction: 3,
          originSaltFingerprint: null,
        );
        final SaveEnvelope envelope = decodeEnvelope(unframe(bytes).payload!);
        expect(envelope.gameStateVersion, StateVersion.current.value);
        expect(envelope.state, mid);
        expect(envelope.state.encounter, mid.encounter);
        expect(
          canonicalDurableGameState(envelope.state),
          canonicalDurableGameState(mid),
        );

        // The reloaded fight continues exactly as the unreloaded one would.
        final GameEngine resumed = GameEngine(
          registry: registry,
          state: envelope.state,
        );
        final EngineResult a = engine.execute(const CombatAttack());
        final EngineResult b = resumed.execute(const CombatAttack());
        expect(
          canonicalJson(a.events.map(encodeEvent).toList()),
          canonicalJson(b.events.map(encodeEvent).toList()),
        );
        expect(resumed.state, engine.state);
      },
    );

    test('every combat event survives the journal codec', () {
      final GameEngine engine = playerAt(
        woods,
        weapon: trainingSword,
        armor: tunic,
        extraItems: <ContentId, int>{herbBroth: 1},
      );
      final List<GameEvent> events = <GameEvent>[
        ...engine.execute(StartEncounter(enemy: wolf)).events,
        ...engine.execute(const CombatAttack()).events,
        ...engine.execute(CombatEat(item: herbBroth)).events,
        ...engine.execute(const CombatRetreat()).events,
      ];
      // A loss and a win, from other fights, so all eight types are covered.
      final GameEngine losing = playerAt(
        hollow,
        extraItems: <ContentId, int>{bronzeSword: 1},
      );
      losing.execute(StartEncounter(enemy: guardian));
      final GameEngine winning = woodsWithStartingLoadout();
      winning.execute(StartEncounter(enemy: wolf));
      final List<GameEvent> all = <GameEvent>[
        ...events,
        ...eventsOf(fightToTheEnd(losing, maxRounds: 10)),
        ...eventsOf(fightToTheEnd(winning)),
      ];
      expect(
        all.map((GameEvent e) => e.name).toSet(),
        containsAll(<String>[
          'EncounterStarted',
          'CombatPlayerStruck',
          'CombatConsumableUsed',
          'CombatEnemyStruck',
          'CombatRoundEnded',
          'EncounterWon',
          'EncounterLost',
          'EncounterRetreated',
        ]),
      );

      for (final GameEvent event in all) {
        final Map<String, Object?> json = encodeEvent(event);
        final GameEvent? back = decodeEvent(
          jsonDecode(canonicalJson(json)) as Map<String, Object?>,
        );
        expect(back, isNotNull, reason: '${event.name} did not decode');
        expect(
          canonicalJson(encodeEvent(back!)),
          canonicalJson(json),
          reason: event.name,
        );
        expect(back.runtimeType, event.runtimeType);
      }

      // And as one journal record, through the framing.
      final JournalRecord record = JournalRecord(
        formatVersion: SaveFormatVersion.current,
        saveId: testSaveId,
        transactionId: 1,
        eventSequenceBefore: events.first.sequence,
        eventSequenceAfter: events.last.sequence + 1,
        events: events,
      );
      final JournalLineResult line = decodeJournalLine(
        encodeJournalLine(record),
      );
      expect(line.ok, isTrue);
      expect(
        canonicalJson(line.record!.events.map(encodeEvent).toList()),
        canonicalJson(events.map(encodeEvent).toList()),
      );
    });

    test(
      'mid-fight and post-victory saves survive the repository and bootstrap',
      () async {
        final (:SaveRepository repo, :FaultingDevice device) = newRepo();
        final GameEngine engine = woodsWithStartingLoadout();
        // Genesis commit so the lineage exists.
        CommitDurable durable =
            await commit(
                  repo,
                  after: engine.state,
                  events: const <GameEvent>[],
                  generation: -1,
                  lastTransaction: 0,
                  saltFingerprint: liveIdentity.saltFingerprint,
                )
                as CommitDurable;

        final EngineResult start = engine.execute(StartEncounter(enemy: wolf));
        durable =
            await commit(
                  repo,
                  after: engine.state,
                  events: start.events,
                  generation: durable.generation,
                  lastTransaction: durable.transactionId,
                  saltFingerprint: liveIdentity.saltFingerprint,
                )
                as CommitDurable;
        final EngineResult round = engine.execute(const CombatAttack());
        durable =
            await commit(
                  repo,
                  after: engine.state,
                  events: round.events,
                  generation: durable.generation,
                  lastTransaction: durable.transactionId,
                  saltFingerprint: liveIdentity.saltFingerprint,
                )
                as CommitDurable;

        // Cold relaunch, mid-fight: the player lands back in the encounter.
        final BootstrapExistingGame mid =
            (await boot(
                  device: device.reboot(),
                  identity: MemoryIdentityStore(liveIdentity),
                )).outcome
                as BootstrapExistingGame;
        expect(mid.engine.state, engine.state);
        expect(mid.engine.state.encounter, isNotNull);
        expect(mid.engine.state.encounter!.turn, 2);
        expect(mid.migration, isNull, reason: 'a v4 save does not migrate');

        // Finish it, commit, relaunch: the reward is there once.
        final List<EngineResult> rounds = fightToTheEnd(engine);
        for (final EngineResult r in rounds) {
          durable =
              await commit(
                    repo,
                    after: r.state,
                    events: r.events,
                    generation: durable.generation,
                    lastTransaction: durable.transactionId,
                    saltFingerprint: liveIdentity.saltFingerprint,
                  )
                  as CommitDurable;
        }
        final BootstrapExistingGame won =
            (await boot(
                  device: device.reboot(),
                  identity: MemoryIdentityStore(liveIdentity),
                )).outcome
                as BootstrapExistingGame;
        expect(won.engine.state, engine.state);
        expect(won.engine.state.encounter, isNull);
        expect(won.engine.state.player.experience, 30);
        // The visit count survives the relaunch, because it is state and not
        // navigation: the player comes back to a wolf they have already beaten
        // once this visit, with one fight left.
        expect(won.engine.state.world.victoriesThisVisit(wolf), 1);
        expect(
          won.engine.state.world.remaining(wolf, perVisit(wolf)),
          perVisit(wolf) - 1,
        );
      },
    );
  });

  group('pacing (PROVISIONAL — a smoke test, not balance)', () {
    /// Rounds a fight takes, and whether the player won, over [seeds] distinct
    /// seeds. Seeds vary with the event sequence, so each variant grants a
    /// different number of no-op step batches before the fight.
    List<({int rounds, bool won})> sample(
      GameEngine Function() build, {
      int seeds = 12,
      ContentId? enemy,
    }) {
      final List<({int rounds, bool won})> out = <({int rounds, bool won})>[];
      for (int i = 0; i < seeds; i++) {
        final GameEngine engine = build();
        for (int j = 0; j < i; j++) {
          engine.execute(const GrantSyntheticSteps(steps: 1, reason: 'seed'));
        }
        engine.execute(StartEncounter(enemy: enemy!));
        final List<EngineResult> rounds = fightToTheEnd(engine);
        out.add((
          rounds: rounds.length,
          won: rounds.last.events.last is EncounterWon,
        ));
      }
      return out;
    }

    test(
      'a wolf with the starting loadout resolves in ~5–14 rounds and is winnable',
      () {
        final List<({int rounds, bool won})> runs = sample(
          woodsWithStartingLoadout,
          enemy: wolf,
        );
        for (final ({int rounds, bool won}) run in runs) {
          expect(run.rounds, inInclusiveRange(5, 14), reason: '$runs');
        }
        expect(
          runs.where((({int rounds, bool won}) r) => r.won).length,
          greaterThanOrEqualTo(runs.length * 2 ~/ 3),
          reason: 'the first fight is meant to be winnable: $runs',
        );
      },
    );

    test('a bronze-sword goblin resolves in ~4–10 rounds and is winnable', () {
      final List<({int rounds, bool won})> runs = sample(
        () => playerAt(mine, weapon: bronzeSword, armor: tunic),
        enemy: goblin,
      );
      for (final ({int rounds, bool won}) run in runs) {
        expect(run.rounds, inInclusiveRange(4, 10), reason: '$runs');
      }
      expect(
        runs.where((({int rounds, bool won}) r) => r.won).length,
        greaterThanOrEqualTo(runs.length * 2 ~/ 3),
        reason: '$runs',
      );
    });
  });
}
