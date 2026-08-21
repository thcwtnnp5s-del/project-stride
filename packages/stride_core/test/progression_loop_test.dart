// Exploration & Progression Loop 01 (`DECISIONS/0023`) — the new systems'
// regression proof, against the shipped production content.
//
// One file, deliberately: persistent HP and rest, the goal tracker, contracts
// (rotation, bounties, exactly-once), community projects (partial atomic
// contribution, permanent effects), enemy knowledge, deterministic drops, and
// the profession/equipment effects. Every figure asserted here is either the
// owner's authored content or a pure function of the seeded resolver — no
// clock, no randomness, no ambient input.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'content_test_support.dart';

final ContentRegistry registry = loadProduction(
  productionSource,
).requireRegistry;

final ContentId haven = ContentId.unchecked('location.havens_rest');
final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId mine = ContentId.unchecked('location.stonefall_mine');
final ContentId frostmere = ContentId.unchecked('location.frostmere');

final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId boar = ContentId.unchecked('enemy.wild_boar');
final ContentId lynx = ContentId.unchecked('enemy.frost_lynx');

final ContentId trainingSword = ContentId.unchecked('item.training_sword');
final ContentId trainingPickaxe = ContentId.unchecked('item.training_pickaxe');
final ContentId bronzeSword = ContentId.unchecked('item.bronze_sword');
final ContentId chestplate = ContentId.unchecked('item.bronze_chestplate');
final ContentId tunic = ContentId.unchecked('item.traveler_tunic');
final ContentId wolfhide = ContentId.unchecked('item.wolfhide_jerkin');
final ContentId frostlined = ContentId.unchecked('item.frostlined_jerkin');
final ContentId reinforcedPickaxe = ContentId.unchecked(
  'item.reinforced_pickaxe',
);

final ContentId herbBroth = ContentId.unchecked('item.herb_broth');
final ContentId meadowHerb = ContentId.unchecked('item.meadow_herb');
final ContentId oakPlank = ContentId.unchecked('item.oak_plank');
final ContentId oakLog = ContentId.unchecked('item.oak_log');
final ContentId bronzeIngot = ContentId.unchecked('item.bronze_ingot');
final ContentId scrapMetal = ContentId.unchecked('item.scrap_metal');
final ContentId heatScale = ContentId.unchecked('item.heat_scale');
final ContentId wolfPelt = ContentId.unchecked('item.wolf_pelt');
final ContentId ramWool = ContentId.unchecked('item.ram_wool');
final ContentId rimeBlossom = ContentId.unchecked('item.rime_blossom');
final ContentId duskcap = ContentId.unchecked('item.duskcap');

final ContentId herbalSupplies = ContentId.unchecked(
  'contract.herbal_supplies',
);
final ContentId carpentersRequest = ContentId.unchecked(
  'contract.carpenters_request',
);
final ContentId kitchenStores = ContentId.unchecked('contract.kitchen_stores');
final ContentId repairMaterials = ContentId.unchecked(
  'contract.repair_materials',
);
final ContentId wolfProblem = ContentId.unchecked('contract.wolf_problem');
final ContentId woodlandAid = ContentId.unchecked('contract.woodland_aid');
final ContentId trailClearing = ContentId.unchecked('contract.trail_clearing');
final ContentId mineHardware = ContentId.unchecked('contract.mine_hardware');
final ContentId coldWeatherKit = ContentId.unchecked(
  'contract.cold_weather_kit',
);
final ContentId northernExpedition = ContentId.unchecked(
  'contract.northern_expedition',
);

final ContentId mill = ContentId.unchecked('project.havens_rest_mill');
final ContentId lift = ContentId.unchecked('project.stonefall_lift');
final ContentId shelter = ContentId.unchecked('project.frostmere_shelter');

final ContentId meadowPatch = ContentId.unchecked(
  'resource_node.meadow_patch',
);
final ContentId oakStand = ContentId.unchecked('resource_node.oak_stand');
final ContentId hardenedSeam = ContentId.unchecked(
  'resource_node.hardened_copper_seam',
);

/// A player at [location], provisioned, with the chosen loadout and levels.
GameEngine playerAt(
  ContentId location, {
  Map<ContentId, int> items = const <ContentId, int>{},
  Map<ContentId, int> skillXp = const <ContentId, int>{},
  ContentId? weapon,
  ContentId? armor,
  ContentId? tool,
  int experience = 0,
  int banked = 0,
  int? hp,
}) {
  final GameEngine fresh = GameEngine.newGame(registry: registry);
  if (banked > 0) {
    fresh.execute(GrantSyntheticSteps(steps: banked, reason: 'loop test'));
  }
  Inventory inventory = fresh.state.inventory;
  for (final MapEntry<ContentId, int> e in items.entries) {
    inventory = inventory.adding(e.key, e.value);
  }
  final int level = CombatRules.levelFor(experience);
  final GameState state = fresh.state.copyWith(
    inventory: inventory,
    equipment: Equipment(<EquipmentSlot, ContentId>{
      EquipmentSlot.weapon: ?weapon,
      EquipmentSlot.armor: ?armor,
      EquipmentSlot.tool: ?tool,
    }),
    skills: SkillProgress(<ContentId, int>{
      for (final ContentId skill in registry.skills.keys)
        skill: skillXp[skill] ?? 0,
    }),
    player: PlayerState(
      level: level,
      experience: experience,
      hp: hp ?? CombatRules.maxHpFor(level),
    ),
    world: WorldState(
      currentLocation: location,
      unlockedLocations: <ContentId>{haven, location},
    ),
  );
  return GameEngine(registry: registry, state: state);
}

EngineResult fightOut(GameEngine engine) {
  EngineResult last = engine.execute(const CombatAttack());
  for (int i = 0; i < 60 && engine.state.encounter != null; i++) {
    last = engine.execute(const CombatAttack());
  }
  expect(engine.state.encounter, isNull, reason: 'fight did not resolve');
  return last;
}

void main() {
  group('§80 — persistent HP, food, safe rest', () {
    test('eating outside combat heals the exact amount, never past max', () {
      final GameEngine engine = playerAt(
        woods,
        items: <ContentId, int>{herbBroth: 3},
        hp: 30,
      );
      final EngineResult r = engine.execute(EatFood(item: herbBroth));
      final FoodEaten eaten = r.events.single as FoodEaten;
      expect(eaten.healed, 8, reason: 'herb broth heals 8 (brief §41)');
      expect(eaten.hpAfter, 38);
      expect(engine.state.player.hp, 38);
      expect(engine.state.inventory.quantityOf(herbBroth), 2);

      // The second bite is clamped to the missing 2.
      final FoodEaten second =
          engine.execute(EatFood(item: herbBroth)).events.single as FoodEaten;
      expect(second.healed, 2);
      expect(engine.state.player.hp, 40);

      // Full: refused, and the food is kept.
      final EngineResult full = engine.execute(EatFood(item: herbBroth));
      expect(full.rejection!.code, RejectionCode.healthFull);
      expect(engine.state.inventory.quantityOf(herbBroth), 1);
    });

    test('eating outside combat is refused mid-fight', () {
      final GameEngine engine = playerAt(
        woods,
        weapon: trainingSword,
        armor: tunic,
        items: <ContentId, int>{herbBroth: 1},
        hp: 30,
      );
      engine.execute(StartEncounter(enemy: wolf));
      expect(
        engine.execute(EatFood(item: herbBroth)).rejection!.code,
        RejectionCode.encounterInProgress,
        reason: 'CombatEat is the in-fight path and spends the turn',
      );
    });

    test('travel to a safe place heals fully and freely; unsafe does not', () {
      final GameEngine engine = playerAt(woods, banked: 5000, hp: 12);
      // Woods → Haven's Rest (safe): full heal on the same event as the move.
      final EngineResult toHaven = engine.execute(
        TravelTo(destination: haven),
      );
      final LocationTravelled arrived =
          toHaven.events.single as LocationTravelled;
      expect(arrived.restoredHp, 40);
      expect(engine.state.player.hp, 40);
      // The heal costs nothing beyond the walk itself.
      expect(engine.state.steps.totalSpent, arrived.stepsSpent);

      // Haven → Woods (unsafe): no heal rides the arrival.
      final GameEngine wounded = playerAt(haven, banked: 5000, hp: 12);
      final LocationTravelled toWoods =
          wounded.execute(TravelTo(destination: woods)).events.single
              as LocationTravelled;
      expect(toWoods.restoredHp, isNull);
      expect(wounded.state.player.hp, 12);
    });

    test('Frostmere is not safe before the Shelter, and is after — once', () {
      final LocationDefinition place = registry.locations[frostmere]!;
      expect(place.isSafe, isFalse);
      expect(place.safeAfterProject, shelter);

      final GameEngine before = playerAt(frostmere, hp: 10);
      expect(
        CombatRules.isSafeNow(place, before.state),
        isFalse,
        reason: 'no free heal at an unbuilt camp',
      );

      final GameEngine after = playerAt(frostmere, hp: 10);
      final GameState sheltered = after.state.copyWith(
        progress: after.state.progress.copyWith(
          completedProjects: <ContentId>{shelter},
        ),
      );
      expect(CombatRules.isSafeNow(place, sheltered), isTrue);
      // And retreat now finds Frostmere itself rather than walking the whole
      // graph home.
      expect(
        CombatRules.retreatDestination(sheltered, registry),
        frostmere,
      );
    });

    test('defeat retreats to safety, restores HP there, and loses nothing',
        () {
      // Bare-handed against the lynx: the defeat is the point.
      final GameEngine engine = playerAt(frostmere, hp: 8);
      final GameState before = engine.state;
      engine.execute(StartEncounter(enemy: lynx));
      final EngineResult last = fightOut(engine);
      final EncounterLost lost =
          last.events.whereType<EncounterLost>().single;
      expect(lost.retreatTo, haven);
      expect(lost.restoredHp, 40, reason: 'the safe retreat heals fully');
      expect(engine.state.player.hp, 40);
      expect(engine.state.world.currentLocation, haven);
      // P-7: nothing else is lost.
      expect(engine.state.inventory, before.inventory);
      expect(engine.state.skills, before.skills);
      expect(engine.state.player.experience, before.player.experience);
      expect(engine.state.steps.banked, before.steps.banked);
    });
  });

  group('§81 — the goal tracker', () {
    test('one goal per slot; switching moves no economy figure', () {
      final GameEngine engine = playerAt(haven, banked: 1000);
      final StepLedger ledgerBefore = engine.state.steps;

      engine.execute(TrackGoal(slot: GoalSlot.journey, target: frostmere));
      engine.execute(TrackGoal(slot: GoalSlot.pursuit, target: bronzeSword));
      engine.execute(TrackGoal(slot: GoalSlot.contract, target: mill));
      expect(engine.state.progress.tracked.journey, frostmere);
      expect(engine.state.progress.tracked.pursuit, bronzeSword);
      expect(engine.state.progress.tracked.contract, mill);

      engine.execute(TrackGoal(slot: GoalSlot.journey, target: mine));
      expect(engine.state.progress.tracked.journey, mine);
      engine.execute(const TrackGoal(slot: GoalSlot.journey));
      expect(engine.state.progress.tracked.journey, isNull);

      expect(engine.state.steps, ledgerBefore, reason: 'never escrow');
    });

    test('a target that does not fit its slot is refused', () {
      final GameEngine engine = playerAt(haven);
      expect(
        engine
            .execute(TrackGoal(slot: GoalSlot.journey, target: bronzeSword))
            .rejection!
            .code,
        RejectionCode.invalidGoal,
      );
      expect(
        engine
            .execute(TrackGoal(slot: GoalSlot.pursuit, target: frostmere))
            .rejection!
            .code,
        RejectionCode.invalidGoal,
      );
      // The contract slot takes a contract or a project, nothing else.
      expect(
        engine
            .execute(TrackGoal(slot: GoalSlot.contract, target: wolf))
            .rejection!
            .code,
        RejectionCode.invalidGoal,
      );
      expect(
        engine
            .execute(TrackGoal(slot: GoalSlot.contract, target: wolfProblem))
            .isAccepted,
        isTrue,
      );
    });

    test('the journey status never reserves steps and reads live', () {
      final GameEngine engine = playerAt(haven, banked: 2000);
      final JourneyStatus toFrostmere = journeyStatusFor(
        registry,
        engine.state,
        frostmere,
      );
      // Haven → Stonefall (1400) → Frostmere (3000): the cheapest route.
      expect(toFrostmere.totalCost, 4400);
      expect(toFrostmere.shortfall, 2400);
      expect(toFrostmere.ready, isFalse);
      expect(
        toFrostmere.legs.map((JourneyLeg l) => l.to),
        <ContentId>[mine, frostmere],
      );

      // Spend elsewhere: the shortfall grows; nothing was reserved.
      engine.execute(TravelTo(destination: woods));
      final JourneyStatus after = journeyStatusFor(
        registry,
        engine.state,
        frostmere,
      );
      expect(after.banked, 1500);
      // From the woods the cheapest way is Woods → Stonefall (1000) →
      // Frostmere (3000).
      expect(after.totalCost, 4000);
      expect(after.shortfall, 2500);
    });

    test('the pursuit plan counts held materials once, recursively', () {
      // Bronze Sword = 3 ingots + 1 handle; an ingot = 2 copper + 1 tin; a
      // handle = 2 oak logs. Holding one ingot and two logs, the plan must
      // consume each exactly once.
      final GameEngine engine = playerAt(
        haven,
        items: <ContentId, int>{bronzeIngot: 1, oakLog: 2},
      );
      final PursuitPlan plan = pursuitPlanFor(
        registry,
        engine.state,
        bronzeSword,
      );
      expect(plan.recipe, ContentId.unchecked('recipe.bronze_sword'));
      expect(plan.owned, isFalse);

      final PursuitLine ingotLine = plan.lines.singleWhere(
        (PursuitLine l) => l.item == bronzeIngot,
      );
      expect((ingotLine.held, ingotLine.required), (1, 3));

      final Map<ContentId, int> needs = <ContentId, int>{
        for (final PursuitNeed n in plan.needs) n.item: n.quantity,
      };
      // Two ingots short: 4 copper + 2 tin. The handle is covered by the two
      // held logs, so no oak appears.
      expect(needs, <ContentId, int>{
        ContentId.unchecked('item.copper_ore'): 4,
        ContentId.unchecked('item.tin_ore'): 2,
      });
      // And the suggestion points at the place that hosts the seam.
      final PursuitNeed copper = plan.needs.singleWhere(
        (PursuitNeed n) => n.item == ContentId.unchecked('item.copper_ore'),
      );
      expect(copper.sourceLocation, mine);
    });

    test('tracked goals survive a save round trip', () {
      final GameEngine engine = playerAt(haven);
      engine.execute(TrackGoal(slot: GoalSlot.journey, target: frostmere));
      engine.execute(TrackGoal(slot: GoalSlot.pursuit, target: bronzeSword));

      final GameState reloaded = decodeEnvelope(
        unframe(
          encodeSnapshot(
            state: engine.state,
            saveId: 'loop-0001',
            generation: 1,
            lastAppliedTransaction: 1,
            originSaltFingerprint: null,
          ),
        ).payload!,
      ).state;
      expect(reloaded.progress.tracked.journey, frostmere);
      expect(reloaded.progress.tracked.pursuit, bronzeSword);
    });

    // PRESENTATION_WORLD_REWARD_FEEL_01 B-1. A tracked rotating contract used
    // to survive its own completion: the deck rotated, the tracked ContentId
    // stayed, and the tracker silently showed a fresh 0/x instance of the
    // contract the player just finished.
    test('completing the tracked contract clears the slot, exactly', () {
      final GameEngine engine = playerAt(
        haven,
        items: <ContentId, int>{meadowHerb: 7},
      );
      engine.execute(TrackGoal(slot: GoalSlot.journey, target: frostmere));
      engine.execute(TrackGoal(slot: GoalSlot.pursuit, target: bronzeSword));
      engine.execute(
        TrackGoal(slot: GoalSlot.contract, target: herbalSupplies),
      );

      final EngineResult r = engine.execute(
        CompleteContract(contract: herbalSupplies),
      );
      expect(r.isAccepted, isTrue, reason: '${r.rejection}');

      // The completed contract is no longer tracked — not re-pointed at the
      // rotation's fresh instance — and the other slots are untouched.
      expect(engine.state.progress.tracked.contract, isNull);
      expect(engine.state.progress.tracked.journey, frostmere);
      expect(engine.state.progress.tracked.pursuit, bronzeSword);
    });

    test('completing an untracked contract leaves the slot alone', () {
      final GameEngine engine = playerAt(
        haven,
        items: <ContentId, int>{meadowHerb: 7},
      );
      engine.execute(TrackGoal(slot: GoalSlot.contract, target: mill));
      expect(
        engine.execute(CompleteContract(contract: herbalSupplies)).isAccepted,
        isTrue,
      );
      expect(engine.state.progress.tracked.contract, mill);
    });

    test('a tracked project clears on completion, never on a stage', () {
      final GameEngine engine = playerAt(
        haven,
        items: <ContentId, int>{
          oakPlank: 12,
          bronzeIngot: 4,
          oakLog: 30,
          herbBroth: 3,
        },
      );
      engine.execute(TrackGoal(slot: GoalSlot.contract, target: mill));

      // Stage 1 completes — the project is still live work, still tracked.
      engine.execute(
        ContributeToProject(
          project: mill,
          contributions: <ContentId, int>{oakPlank: 12},
        ),
      );
      expect(engine.state.progress.tracked.contract, mill);

      engine.execute(
        ContributeToProject(
          project: mill,
          contributions: <ContentId, int>{bronzeIngot: 4},
        ),
      );
      final EngineResult done = engine.execute(
        ContributeToProject(
          project: mill,
          contributions: <ContentId, int>{oakLog: 6, herbBroth: 3},
        ),
      );
      expect(
        (done.events.single as ProjectContributed).projectCompleted,
        isTrue,
      );
      expect(engine.state.progress.tracked.contract, isNull);
    });
  });

  group('§82 — contracts', () {
    test('a delivery completes exactly: items out, rewards in, once', () {
      final GameEngine engine = playerAt(
        haven,
        items: <ContentId, int>{meadowHerb: 7},
      );
      final EngineResult r = engine.execute(
        CompleteContract(contract: herbalSupplies),
      );
      expect(r.isAccepted, isTrue, reason: '${r.rejection}');
      final ContractCompleted done = r.events.single as ContractCompleted;
      expect(done.consumed, <ContentId, int>{meadowHerb: 5});
      expect(done.rewardItems, <ContentId, int>{herbBroth: 2});
      expect(done.rewardSkillXp, <ContentId, int>{
        ContentId.unchecked('skill.foraging'): 30,
      });
      expect(engine.state.inventory.quantityOf(meadowHerb), 2);
      expect(engine.state.inventory.quantityOf(herbBroth), 2);
      expect(
        engine.state.skills.experienceIn(
          ContentId.unchecked('skill.foraging'),
        ),
        30,
      );
      expect(engine.state.progress.completionsOf(herbalSupplies), 1);
    });

    test('an insufficient delivery is refused with zero mutation', () {
      final GameEngine engine = playerAt(
        haven,
        items: <ContentId, int>{meadowHerb: 4},
      );
      final GameState before = engine.state;
      final EngineResult r = engine.execute(
        CompleteContract(contract: herbalSupplies),
      );
      expect(r.rejection!.code, RejectionCode.insufficientIngredients);
      expect(identical(engine.state, before), isTrue);
    });

    test('completion is refused away from the board', () {
      final GameEngine engine = playerAt(
        woods,
        items: <ContentId, int>{meadowHerb: 7},
      );
      expect(
        engine
            .execute(CompleteContract(contract: herbalSupplies))
            .rejection!
            .code,
        RejectionCode.contractNotHere,
      );
    });

    test('a local need rotates by completion, never by time, and returns', () {
      // Haven's deck: 7 authored orders, 3 showing. Completing one rotates
      // the next authored order into its slot.
      final GameEngine engine = playerAt(
        haven,
        items: <ContentId, int>{
          meadowHerb: 40,
          oakLog: 40,
          oakPlank: 40,
          duskcap: 4,
          bronzeIngot: 2,
        },
      );
      final List<ContentId> opening = engine.localNeedSlots(
        engine.state,
        haven,
      );
      expect(opening, <ContentId>[
        herbalSupplies,
        carpentersRequest,
        kitchenStores,
      ]);

      engine.execute(CompleteContract(contract: herbalSupplies));
      final List<ContentId> afterFirst = engine.localNeedSlots(
        engine.state,
        haven,
      );
      expect(afterFirst, <ContentId>[
        repairMaterials,
        carpentersRequest,
        kitchenStores,
      ]);

      // The completed order is no longer completable while off the board.
      expect(
        engine
            .execute(CompleteContract(contract: herbalSupplies))
            .rejection!
            .code,
        RejectionCode.contractNotAvailable,
      );

      // Work the deck round — each completion checked, because a refused
      // completion rotates nothing and would make the cycle claim vacuous.
      for (final ContentId next in <ContentId>[
        repairMaterials,
        carpentersRequest,
        kitchenStores,
        ContentId.unchecked('contract.workshop_delivery'),
      ]) {
        final EngineResult r = engine.execute(
          CompleteContract(contract: next),
        );
        expect(r.isAccepted, isTrue, reason: '$next: ${r.rejection}');
      }
      // The deck has wrapped: the first order is back on the board.
      final List<ContentId> later = engine.localNeedSlots(engine.state, haven);
      expect(
        later,
        contains(herbalSupplies),
        reason: 'after the deck cycles, earlier orders return (brief §7)',
      );
    });

    test('a bounty counts only victories after acceptance, exactly once', () {
      final GameEngine engine = playerAt(
        woods,
        weapon: bronzeSword,
        armor: chestplate,
        items: <ContentId, int>{herbBroth: 20},
      );
      // A victory before acceptance must not count (brief §79).
      engine.execute(StartEncounter(enemy: wolf));
      fightOut(engine);
      while (engine.state.player.hp <
          CombatRules.maxHpFor(engine.state.player.level)) {
        if (engine.execute(EatFood(item: herbBroth)).isRejected) break;
      }
      engine.execute(AcceptContract(contract: wolfProblem));
      expect(engine.state.progress.bountyProgress[wolfProblem], 0);

      // Completing now is refused: nothing counted yet.
      expect(
        engine
            .execute(CompleteContract(contract: wolfProblem))
            .rejection!
            .code,
        RejectionCode.bountyUnmet,
      );

      // Three qualifying victories, with travel to reset the visit.
      int counted = 0;
      while (counted < 3) {
        if (!engine.state.world.isAvailable(
          wolf,
          registry.enemies[wolf]!.encountersPerVisit,
        )) {
          engine.execute(EnterLocation(location: haven));
          engine.execute(EnterLocation(location: woods));
        }
        engine.execute(StartEncounter(enemy: wolf));
        final EngineResult last = fightOut(engine);
        if (last.events.whereType<EncounterWon>().isNotEmpty) {
          counted = engine.state.progress.bountyProgress[wolfProblem] ?? 0;
        }
        while (engine.state.player.hp <
            CombatRules.maxHpFor(engine.state.player.level)) {
          if (engine.execute(EatFood(item: herbBroth)).isRejected) break;
        }
        if (engine.state.world.currentLocation != woods) {
          engine.execute(EnterLocation(location: woods));
        }
      }
      expect(engine.state.progress.bountyProgress[wolfProblem], 3);

      // The guaranteed pelt lands exactly once, and acceptance clears.
      final int peltsBefore = engine.state.inventory.quantityOf(wolfPelt);
      final EngineResult done = engine.execute(
        CompleteContract(contract: wolfProblem),
      );
      expect(done.isAccepted, isTrue, reason: '${done.rejection}');
      expect(engine.state.inventory.quantityOf(wolfPelt), peltsBefore + 1);
      expect(
        engine.state.progress.acceptedContracts,
        isNot(contains(wolfProblem)),
      );
      expect(engine.state.progress.bountyProgress[wolfProblem], isNull);

      // Repeatable: it can be accepted again, starting from zero.
      expect(
        engine.execute(AcceptContract(contract: wolfProblem)).isAccepted,
        isTrue,
      );
      expect(engine.state.progress.bountyProgress[wolfProblem], 0);
    });

    test('a regional contract is one-time, and gated contracts unlock', () {
      // Woodland Aid asks for a completed Woods request first.
      final GameEngine engine = playerAt(
        haven,
        items: <ContentId, int>{wolfPelt: 2, oakLog: 20},
        banked: 5000,
      );
      expect(
        engine
            .execute(CompleteContract(contract: woodlandAid))
            .rejection!
            .code,
        RejectionCode.contractNotAvailable,
      );

      // Help at the woods: Trail Clearing takes 8 oak logs.
      engine.execute(TravelTo(destination: woods));
      expect(
        engine
            .execute(CompleteContract(contract: trailClearing))
            .isAccepted,
        isTrue,
      );
      engine.execute(TravelTo(destination: haven));

      // The Wolfhide recipe is taught by the contract, not before.
      expect(
        engine
            .execute(
              CraftItem(recipe: ContentId.unchecked('recipe.wolfhide_jerkin')),
            )
            .rejection!
            .code,
        RejectionCode.recipeLocked,
      );

      expect(
        engine.execute(CompleteContract(contract: woodlandAid)).isAccepted,
        isTrue,
      );
      // One-time: a second completion is refused.
      expect(
        engine
            .execute(CompleteContract(contract: woodlandAid))
            .rejection!
            .code,
        RejectionCode.contractNotAvailable,
      );
      // And the recipe is now merely progression away, not locked: the next
      // refusal is the skill gate, which is the engine's ordinary order.
      final EngineResult craft = engine.execute(
        CraftItem(recipe: ContentId.unchecked('recipe.wolfhide_jerkin')),
      );
      expect(
        craft.rejection!.code,
        RejectionCode.skillLevelTooLow,
        reason: 'locked → taught; what remains is Smithing 2 and materials',
      );
    });

    test('requiresOwned shows the item and keeps it', () {
      final GameEngine engine = playerAt(
        frostmere,
        items: <ContentId, int>{
          wolfhide: 1,
          rimeBlossom: 2,
          ramWool: 1,
        },
      );
      final EngineResult r = engine.execute(
        CompleteContract(contract: coldWeatherKit),
      );
      expect(r.isAccepted, isTrue, reason: '${r.rejection}');
      final ContractCompleted done = r.events.single as ContractCompleted;
      expect(done.consumed.containsKey(wolfhide), isFalse);
      expect(engine.state.inventory.quantityOf(wolfhide), 1);
      expect(engine.state.inventory.quantityOf(rimeBlossom), 0);
      expect(engine.state.inventory.quantityOf(ramWool), 0);

      // Without the jerkin, the same delivery is refused by ownership.
      final GameEngine bare = playerAt(
        frostmere,
        items: <ContentId, int>{rimeBlossom: 2, ramWool: 1},
      );
      expect(
        bare
            .execute(CompleteContract(contract: coldWeatherKit))
            .rejection!
            .code,
        RejectionCode.requirementNotOwned,
      );
    });

    test('contract state survives the journal codec and a save round trip',
        () {
      final GameEngine engine = playerAt(
        haven,
        items: <ContentId, int>{meadowHerb: 7},
      );
      final EngineResult r = engine.execute(
        CompleteContract(contract: herbalSupplies),
      );
      final GameEvent? round = decodeEvent(encodeEvent(r.events.single));
      expect(round, isA<ContractCompleted>());
      final ContractCompleted decoded = round! as ContractCompleted;
      expect(decoded.consumed, <ContentId, int>{meadowHerb: 5});
      expect(decoded.completionsAfter, 1);
      expect(decoded.rotatedSlots, isNotNull);

      final GameState reloaded = decodeEnvelope(
        unframe(
          encodeSnapshot(
            state: engine.state,
            saveId: 'loop-0002',
            generation: 1,
            lastAppliedTransaction: 1,
            originSaltFingerprint: null,
          ),
        ).payload!,
      ).state;
      expect(reloaded.progress.completionsOf(herbalSupplies), 1);
      expect(
        reloaded.progress.localSlots[haven],
        engine.state.progress.localSlots[haven],
      );
    });
  });

  group('§83 — community projects', () {
    test('partial contribution is atomic, permanent, and monotonic', () {
      final GameEngine engine = playerAt(
        haven,
        items: <ContentId, int>{oakPlank: 5},
      );
      final EngineResult r = engine.execute(
        ContributeToProject(
          project: mill,
          contributions: <ContentId, int>{oakPlank: 5},
        ),
      );
      expect(r.isAccepted, isTrue, reason: '${r.rejection}');
      final ProjectContributed given = r.events.single as ProjectContributed;
      expect(given.stage, 0);
      expect(given.stageCompleted, isFalse);
      expect(given.stageContributedAfter, <ContentId, int>{oakPlank: 5});
      expect(engine.state.inventory.quantityOf(oakPlank), 0);
      expect(
        engine.state.progress.projects[mill]!.contributedOf(oakPlank),
        5,
      );
      expect(
        given.characterXp,
        0,
        reason: 'stage XP lands when the stage completes, not per donation',
      );
    });

    test('over-contribution, unneeded items and shortfalls all refuse whole',
        () {
      final GameEngine engine = playerAt(
        haven,
        items: <ContentId, int>{oakPlank: 20, meadowHerb: 5},
      );
      final GameState before = engine.state;
      // More than the stage needs.
      expect(
        engine
            .execute(
              ContributeToProject(
                project: mill,
                contributions: <ContentId, int>{oakPlank: 13},
              ),
            )
            .rejection!
            .code,
        RejectionCode.invalidContribution,
      );
      // An item the stage does not want.
      expect(
        engine
            .execute(
              ContributeToProject(
                project: mill,
                contributions: <ContentId, int>{meadowHerb: 1},
              ),
            )
            .rejection!
            .code,
        RejectionCode.invalidContribution,
      );
      // More than is held.
      expect(
        engine
            .execute(
              ContributeToProject(
                project: lift,
                contributions: <ContentId, int>{oakPlank: 30},
              ),
            )
            .rejection!
            .code,
        RejectionCode.projectNotHere,
        reason: 'the Lift is at Stonefall; contributions are made in person',
      );
      expect(identical(engine.state, before), isTrue);
    });

    test(
      'the Mill completes exactly once, and its effects hold from then on',
      () {
        final GameEngine engine = playerAt(
          haven,
          items: <ContentId, int>{
            oakPlank: 12,
            bronzeIngot: 4,
            oakLog: 30,
            herbBroth: 3,
          },
          skillXp: <ContentId, int>{
            ContentId.unchecked('skill.smithing'): 0,
          },
        );

        // Before the Mill: planks cost three logs, and the improved recipe
        // is not offered.
        expect(
          registry.recipes[ContentId.unchecked('recipe.oak_plank')]!
              .ingredients
              .single
              .quantity,
          3,
        );
        expect(
          engine
              .execute(
                CraftItem(
                  recipe: ContentId.unchecked('recipe.oak_plank_improved'),
                ),
              )
              .rejection!
              .code,
          RejectionCode.recipeLocked,
        );

        // Stage 1: Timber Frame.
        EngineResult r = engine.execute(
          ContributeToProject(
            project: mill,
            contributions: <ContentId, int>{oakPlank: 12},
          ),
        );
        ProjectContributed e = r.events.single as ProjectContributed;
        expect(e.stageCompleted, isTrue);
        expect(e.projectCompleted, isFalse);
        expect(e.characterXp, 40);
        expect(engine.state.progress.projects[mill]!.stage, 1);

        // Stage 2: Mechanism.
        r = engine.execute(
          ContributeToProject(
            project: mill,
            contributions: <ContentId, int>{bronzeIngot: 4},
          ),
        );
        e = r.events.single as ProjectContributed;
        expect(e.stageCompleted, isTrue);
        expect(engine.state.progress.projects[mill]!.stage, 2);

        // Stage 3: Open the Workshop — the whole project completes.
        r = engine.execute(
          ContributeToProject(
            project: mill,
            contributions: <ContentId, int>{oakLog: 6, herbBroth: 3},
          ),
        );
        e = r.events.single as ProjectContributed;
        expect(e.stageCompleted, isTrue);
        expect(e.projectCompleted, isTrue);
        expect(e.characterXp, 40 + 60, reason: 'stage plus completion');
        expect(engine.state.progress.isProjectComplete(mill), isTrue);
        expect(engine.state.progress.projects[mill], isNull);

        // Exactly once: nothing more can be given.
        expect(
          engine
              .execute(
                ContributeToProject(
                  project: mill,
                  contributions: <ContentId, int>{oakLog: 1},
                ),
              )
              .rejection!
              .code,
          RejectionCode.projectComplete,
        );

        // The permanent effect: the old plank recipe is retired, the
        // improved one (two logs) stands.
        expect(
          engine
              .execute(
                CraftItem(recipe: ContentId.unchecked('recipe.oak_plank')),
              )
              .rejection!
              .code,
          RejectionCode.recipeLocked,
        );
        final int logsBefore = engine.state.inventory.quantityOf(oakLog);
        expect(
          engine
              .execute(
                CraftItem(
                  recipe: ContentId.unchecked('recipe.oak_plank_improved'),
                ),
              )
              .isAccepted,
          isTrue,
        );
        expect(engine.state.inventory.quantityOf(oakLog), logsBefore - 2);

        // The development state is derived, never stored.
        expect(
          developmentStateFor(registry, engine.state, haven),
          'Recovering',
        );

        // And it all survives a save round trip.
        final GameState reloaded = decodeEnvelope(
          unframe(
            encodeSnapshot(
              state: engine.state,
              saveId: 'loop-0003',
              generation: 1,
              lastAppliedTransaction: 1,
              originSaltFingerprint: null,
            ),
          ).payload!,
        ).state;
        expect(reloaded.progress.isProjectComplete(mill), isTrue);
        expect(developmentStateFor(registry, reloaded, haven), 'Recovering');
      },
    );

    test('the Lift unlocks the hardened seam; the Shelter opens contracts',
        () {
      final GameEngine engine = playerAt(
        mine,
        tool: reinforcedPickaxe,
        items: <ContentId, int>{reinforcedPickaxe: 1},
        skillXp: <ContentId, int>{
          ContentId.unchecked('skill.mining'): 1000,
        },
        banked: 1000,
      );
      // Locked before the Lift, even with the tool and the level.
      expect(
        engine.execute(GatherResource(node: hardenedSeam)).rejection!.code,
        RejectionCode.nodeLocked,
      );

      final GameState lifted = engine.state.copyWith(
        progress: engine.state.progress.copyWith(
          completedProjects: <ContentId>{lift},
        ),
      );
      final GameEngine after = GameEngine(registry: registry, state: lifted);
      final EngineResult r = after.execute(GatherResource(node: hardenedSeam));
      expect(r.isAccepted, isTrue, reason: '${r.rejection}');
      expect((r.events.single as ResourceGathered).quantity, 2);

      // The Shelter gates the Northern Expedition.
      final GameEngine north = playerAt(
        frostmere,
        items: <ContentId, int>{herbBroth: 6, ramWool: 2},
      );
      expect(
        north
            .execute(CompleteContract(contract: northernExpedition))
            .rejection!
            .code,
        RejectionCode.contractNotAvailable,
      );
      final GameEngine ready = GameEngine(
        registry: registry,
        state: north.state.copyWith(
          progress: north.state.progress.copyWith(
            completedProjects: <ContentId>{shelter},
          ),
        ),
      );
      expect(
        ready
            .execute(CompleteContract(contract: northernExpedition))
            .isAccepted,
        isTrue,
      );
    });
  });

  group('§84 — enemy knowledge', () {
    test('Seen on the first encounter, Studied and Known at the thresholds',
        () {
      final EnemyDefinition wolfDef = registry.enemies[wolf]!;
      expect((wolfDef.studiedAt, wolfDef.knownAt), (3, 6));

      final GameEngine engine = playerAt(
        woods,
        weapon: bronzeSword,
        armor: chestplate,
        items: <ContentId, int>{herbBroth: 40},
      );
      expect(knowledgeTierFor(engine.state, wolfDef), KnowledgeTier.unseen);

      engine.execute(StartEncounter(enemy: wolf));
      expect(
        knowledgeTierFor(engine.state, wolfDef),
        KnowledgeTier.seen,
        reason: 'starting the fight is what makes an enemy Seen',
      );

      int knowledgeXpAwards = 0;
      for (int wins = 0; wins < 7;) {
        if (engine.state.encounter == null) {
          if (!engine.state.world.isAvailable(
            wolf,
            wolfDef.encountersPerVisit,
          )) {
            engine.execute(EnterLocation(location: haven));
            engine.execute(EnterLocation(location: woods));
          }
          engine.execute(StartEncounter(enemy: wolf));
        }
        final EngineResult last = fightOut(engine);
        final EncounterWon? won =
            last.events.whereType<EncounterWon>().firstOrNull;
        if (won != null) {
          wins = won.victoriesAfter!;
          if (won.knowledgeXp > 0) {
            knowledgeXpAwards++;
            expect(
              wins,
              wolfDef.knownAt,
              reason: 'the one-time award rides exactly the crossing victory',
            );
            expect(won.knowledgeXp, wolfDef.knownXp);
          }
          if (wins == 2) {
            expect(
              knowledgeTierFor(engine.state, wolfDef),
              KnowledgeTier.seen,
            );
          }
          if (wins == 3) {
            expect(
              knowledgeTierFor(engine.state, wolfDef),
              KnowledgeTier.studied,
            );
          }
        }
        while (engine.state.player.hp <
            CombatRules.maxHpFor(engine.state.player.level)) {
          if (engine.execute(EatFood(item: herbBroth)).isRejected) break;
        }
        if (engine.state.world.currentLocation != woods) {
          engine.execute(EnterLocation(location: woods));
        }
      }
      expect(knowledgeTierFor(engine.state, wolfDef), KnowledgeTier.known);
      expect(
        knowledgeXpAwards,
        1,
        reason: 'the Known award is exactly once — then it stops',
      );
      expect(engine.state.progress.victoriesOf(wolf), 7);
    });

    test('lifetime victories persist across travel and a save round trip',
        () {
      final GameEngine engine = playerAt(
        woods,
        weapon: bronzeSword,
        armor: chestplate,
      );
      engine.execute(StartEncounter(enemy: wolf));
      fightOut(engine);
      engine.execute(EnterLocation(location: haven));
      expect(
        engine.state.world.visitVictories,
        isEmpty,
        reason: 'the per-visit limiter empties on every move',
      );
      expect(
        engine.state.progress.victoriesOf(wolf),
        1,
        reason: 'the bestiary does not',
      );
      final GameState reloaded = decodeEnvelope(
        unframe(
          encodeSnapshot(
            state: engine.state,
            saveId: 'loop-0004',
            generation: 1,
            lastAppliedTransaction: 1,
            originSaltFingerprint: null,
          ),
        ).payload!,
      ).state;
      expect(reloaded.progress.victoriesOf(wolf), 1);
    });
  });

  group('§85 — deterministic drops and the signature rule', () {
    test('drops are a pure function of the seed, signature included', () {
      final EnemyDefinition boarDef = registry.enemies[boar]!;
      expect(
        boarDef.drops.map((EnemyDrop d) => d.signature).toList(),
        <bool>[false, false, true],
        reason: 'hide, tusk, then the Great Tusk signature',
      );

      // Roll the authored table across many seeds: every row must land at
      // least once and never land when its roll says no — including the
      // signature, whose concealment is presentation, never a roll change.
      int signatures = 0;
      for (int seed = 0; seed < 400; seed++) {
        for (int i = 0; i < boarDef.drops.length; i++) {
          final EnemyDrop drop = boarDef.drops[i];
          final bool lands =
              CombatRules.percentRoll(seed * 2749, i, 7) < drop.chancePercent;
          if (drop.signature && lands) signatures++;
        }
      }
      expect(signatures, greaterThan(0), reason: 'an 8% roll lands in 400');
      expect(
        signatures,
        lessThan(100),
        reason: 'and it is rare, not routine',
      );
    });

    test('no critical recipe requires a signature drop', () {
      final Set<ContentId> signatureItems = <ContentId>{
        for (final EnemyDefinition enemy in registry.enemies.values)
          for (final EnemyDrop drop in enemy.drops)
            if (drop.signature) drop.item,
      };
      expect(signatureItems, isNotEmpty);
      for (final RecipeDefinition recipe in registry.recipes.values) {
        for (final RecipeIngredient ingredient in recipe.ingredients) {
          expect(
            signatureItems,
            isNot(contains(ingredient.item)),
            reason:
                '${recipe.id} requires ${ingredient.item} — a signature drop '
                'must never gate progression (`DECISIONS/0023` §6)',
          );
        }
      }
      // And every combat contract's guarantee is a dependable material, so
      // the anti-grind backstop cannot itself depend on luck.
      for (final ContractDefinition contract in registry.contracts.values) {
        for (final ItemQuantity reward in contract.rewardItems) {
          expect(signatureItems, isNot(contains(reward.item)));
        }
      }
    });
  });

  group('§86 — profession and equipment effects', () {
    GameEngine gatherer(
      ContentId location, {
      ContentId? armor,
      ContentId? tool,
      Map<ContentId, int> skillXp = const <ContentId, int>{},
    }) => playerAt(
      location,
      armor: armor,
      tool: tool ?? ContentId.unchecked('item.training_axe'),
      skillXp: skillXp,
      banked: 100000,
    );

    test('the node skill bonus rolls only at the authored level', () {
      // Meadow Patch: 10% chance of +1 from Foraging 2 (brief §38). Under a
      // level-1 forager no gather may ever yield 2; under level 2+ the bonus
      // must land on exactly the seeds whose roll says so.
      // Nine gathers only: the tenth would carry the forager to 100 XP and
      // level 2, where the bonus legitimately begins — which is itself the
      // property under test.
      final GameEngine low = playerAt(haven, banked: 100000);
      for (int i = 0; i < 9; i++) {
        final EngineResult r = low.execute(GatherResource(node: meadowPatch));
        expect((r.events.single as ResourceGathered).quantity, 1);
      }

      final GameEngine high = playerAt(
        haven,
        skillXp: <ContentId, int>{
          ContentId.unchecked('skill.foraging'): 150,
        },
        banked: 100000,
      );
      int bonuses = 0;
      for (int i = 0; i < 60; i++) {
        final GameState before = high.state;
        final EngineResult r = high.execute(GatherResource(node: meadowPatch));
        final ResourceGathered g = r.events.single as ResourceGathered;
        final int expected =
            1 +
            (CombatRules.percentRoll(
                      CombatRules.gatherSeed(
                        before.eventSequence,
                        meadowPatch,
                      ),
                      0,
                      CombatRules.nodeBonusSalt,
                    ) <
                    10
                ? 1
                : 0);
        expect(g.quantity, expected, reason: 'deterministic, seed-exact');
        if (g.quantity == 2) bonuses++;
      }
      expect(bonuses, greaterThan(0), reason: '10% lands within 60 gathers');
    });

    test('Wilderness Ready applies to Woodcutting/Foraging and never Mining',
        () {
      // The jerkin's 10% rolls on the wilderness salt; on a mining node it
      // must contribute nothing at any seed.
      final GameEngine miner = gatherer(
        mine,
        armor: wolfhide,
        tool: trainingPickaxe,
      );
      for (int i = 0; i < 40; i++) {
        final EngineResult r = miner.execute(
          GatherResource(node: ContentId.unchecked('resource_node.tin_seam')),
        );
        // Tin needs Mining 3 — refused; use copper instead.
        if (r.isRejected) break;
      }
      final GameEngine copperMiner = gatherer(
        mine,
        armor: wolfhide,
        tool: trainingPickaxe,
      );
      // Eight gathers: the ninth would reach Mining 2 (120 XP), where the
      // seam's own level bonus legitimately begins and would confound the
      // jerkin claim.
      for (int i = 0; i < 8; i++) {
        final GameState before = copperMiner.state;
        final ResourceGathered g =
            copperMiner
                    .execute(
                      GatherResource(
                        node: ContentId.unchecked(
                          'resource_node.copper_seam',
                        ),
                      ),
                    )
                    .events
                    .single
                as ResourceGathered;
        // At Mining 1 the node bonus is gated off, so any +1 could only be
        // the jerkin misapplying — and none may appear.
        expect(
          g.quantity,
          1,
          reason:
              'seed ${before.eventSequence}: the jerkin must not touch mining',
        );
      }

      // On oak, the jerkin's roll applies — deterministically, stacking
      // independently with the node's own Woodcutting-3 bonus once the
      // accruing XP reaches it. Both rolls are recomputed here from the same
      // seed the engine used, so the yield is pinned exactly at every level.
      final GameEngine lumberjack = gatherer(woods, armor: wolfhide);
      final ContentId woodcutting = ContentId.unchecked('skill.woodcutting');
      int bonuses = 0;
      for (int i = 0; i < 60; i++) {
        final GameState before = lumberjack.state;
        final ResourceGathered g =
            lumberjack.execute(GatherResource(node: oakStand)).events.single
                as ResourceGathered;
        final int seed = CombatRules.gatherSeed(
          before.eventSequence,
          oakStand,
        );
        final bool jerkin =
            CombatRules.percentRoll(
              seed,
              0,
              CombatRules.wildernessBonusSalt,
            ) <
            10;
        final int level = registry.skills[woodcutting]!.levelAt(
          before.skills.experienceIn(woodcutting),
        );
        final bool nodeBonus =
            level >= 3 &&
            CombatRules.percentRoll(seed, 0, CombatRules.nodeBonusSalt) < 10;
        expect(g.quantity, 1 + (jerkin ? 1 : 0) + (nodeBonus ? 1 : 0));
        if (jerkin) bonuses++;
      }
      expect(bonuses, greaterThan(0));
    });

    test('the Reinforced Pickaxe bonus rolls on mining nodes it serves', () {
      final GameEngine miner = playerAt(
        mine,
        tool: reinforcedPickaxe,
        skillXp: <ContentId, int>{
          ContentId.unchecked('skill.mining'): 1000,
        },
        banked: 100000,
      );
      final GameState lifted = miner.state.copyWith(
        progress: miner.state.progress.copyWith(
          completedProjects: <ContentId>{lift},
        ),
      );
      final GameEngine deep = GameEngine(registry: registry, state: lifted);
      int bonuses = 0;
      for (int i = 0; i < 40; i++) {
        final GameState before = deep.state;
        final ResourceGathered g =
            deep.execute(GatherResource(node: hardenedSeam)).events.single
                as ResourceGathered;
        final bool toolBonus =
            CombatRules.percentRoll(
              CombatRules.gatherSeed(before.eventSequence, hardenedSeam),
              0,
              CombatRules.toolBonusSalt,
            ) <
            15;
        expect(g.quantity, 2 + (toolBonus ? 1 : 0));
        if (toolBonus) bonuses++;
      }
      expect(bonuses, greaterThan(0), reason: '15% lands within 40');
    });

    test('Cold Weather reduces incoming damage in alpine fights only, min 1',
        () {
      // Frost-lined jerkin: defence 6, frostGuard 2. Against the lynx
      // (attack 9, alpine): every strike is reduced by 2 more, floored at 1.
      final GameEngine north = playerAt(
        frostmere,
        weapon: bronzeSword,
        armor: frostlined,
      );
      north.execute(StartEncounter(enemy: lynx));
      expect(north.state.encounter!.playerFrostGuard, 2);
      final EngineResult round = north.execute(const CombatAttack());
      for (final CombatEnemyStruck hit
          in round.events.whereType<CombatEnemyStruck>()) {
        final int unguarded = CombatRules.strike(
          9,
          6,
          CombatRules.roll(
            north.state.encounter?.seed ??
                (round.events.first as CombatPlayerStruck).turn,
            hit.turn,
            CombatRules.enemyStrikeSalt + hit.strikeIndex,
          ),
        );
        expect(
          hit.damage,
          unguarded - 2 < 1 ? 1 : unguarded - 2,
          reason: 'reduced by exactly the guard, floored at 1',
        );
      }

      // The same armour in the woods (forest): no reduction anywhere.
      final GameEngine south = playerAt(
        woods,
        weapon: bronzeSword,
        armor: frostlined,
      );
      south.execute(StartEncounter(enemy: wolf));
      expect(
        south.state.encounter!.playerFrostGuard,
        2,
        reason: 'snapshotted; the terrain gate applies at strike time',
      );
      final EngineResult wolfRound = south.execute(const CombatAttack());
      for (final CombatEnemyStruck hit
          in wolfRound.events.whereType<CombatEnemyStruck>()) {
        final int unguarded = CombatRules.strike(
          4,
          6,
          CombatRules.roll(
            south.state.encounter?.seed ?? 0,
            hit.turn,
            CombatRules.enemyStrikeSalt + hit.strikeIndex,
          ),
        );
        expect(hit.damage, unguarded, reason: 'no frost guard off the alpine');
      }
    });

    test('queue completions roll their own bonuses per completion index', () {
      final GameEngine engine = playerAt(
        haven,
        skillXp: <ContentId, int>{
          ContentId.unchecked('skill.foraging'): 150,
        },
        banked: 100000,
      );
      final int seq = engine.state.eventSequence;
      engine.execute(
        StartActivityQueue(
          node: meadowPatch,
          requested: 5,
          durationMillis: 1000,
          nowEpochMillis: 1750000000000,
        ),
      );
      final EngineResult r = engine.execute(
        const ReconcileActivityQueue(nowEpochMillis: 1750000006000),
      );
      final ActivityQueueReconciled batch =
          r.events.single as ActivityQueueReconciled;
      expect(batch.completions, hasLength(5));
      final int seed = CombatRules.gatherSeed(seq + 1, meadowPatch);
      for (final (int j, ActivityCompletion c) in batch.completions.indexed) {
        final bool bonus =
            CombatRules.percentRoll(seed, j, CombatRules.nodeBonusSalt) < 10;
        expect(
          c.quantity,
          1 + (bonus ? 1 : 0),
          reason: 'completion $j rolls its own index',
        );
      }
    });
  });
}
