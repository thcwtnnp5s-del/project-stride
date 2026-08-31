// Fable Depth Offensive 01 (`DECISIONS/0028`): five engine-driven walked
// play-proofs of the pack, in the `verge_tier_loop_test.dart` idiom — real
// commands, printed step bills, and the "every step of the bill is accounted
// for" sum against what the engine actually charged (`MISTAKES.md` M-07:
// the graph saying reachable is not the same as a player walking it).
//
// The five, per the thesis (§11, §16) and BUILD-C §3:
//
//  1. FRESH SHORT LOOP — a fresh save's first session still fits in a short
//     walk: meadow, one broth, one board completion, under 2,000 gather-steps.
//  2. OWNER-LIKE INSTALL SWEEP — the selection principle's promise AT INSTALL:
//     the rank-2 projects contribute, the Known-gated elites accept, and the
//     Smithing 8–10 recipes are gated by level and by nothing else.
//  3. GRANARY ARC — the Granary's whole bill from empty bags, walked, landing
//     in the MEDIUM band and completing exactly once.
//  4. UNDERCROFT CHAIN — rubbings (sigil shown, never consumed) → project →
//     the two new nodes unlock → the first descent consumes its stew.
//  5. FROSTWARDEN ROAD — the deterministic road to the Frostwarden Coat,
//     beating the ~50k-step frost_claw expectation by a wide margin.
//
// Mid-game states are built directly and handed to the engine, exactly as a
// decoded save would be — the `combat_test.dart` / `veteran_hunts_test.dart`
// pattern. Every staged fact is one the owner's save has already earned
// (thesis §16); each is justified where it is staged.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'content_test_support.dart';
import 'step_support.dart';

final ContentRegistry registry = loadProduction(
  productionSource,
).requireRegistry;

// -- Locations ----------------------------------------------------------------
final ContentId haven = ContentId.unchecked('location.havens_rest');
final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId mine = ContentId.unchecked('location.stonefall_mine');
final ContentId frostmere = ContentId.unchecked('location.frostmere');
final ContentId hollow = ContentId.unchecked('location.forgotten_hollow');

// -- Skills -------------------------------------------------------------------
final ContentId woodcutting = ContentId.unchecked('skill.woodcutting');
final ContentId mining = ContentId.unchecked('skill.mining');
final ContentId foraging = ContentId.unchecked('skill.foraging');
final ContentId smithing = ContentId.unchecked('skill.smithing');
final ContentId cooking = ContentId.unchecked('skill.cooking');

// -- Enemies ------------------------------------------------------------------
final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId goblin = ContentId.unchecked('enemy.cave_goblin');
final ContentId boar = ContentId.unchecked('enemy.wild_boar');
final ContentId bear = ContentId.unchecked('enemy.oakback_bear');
final ContentId lynx = ContentId.unchecked('enemy.frost_lynx');
final ContentId ram = ContentId.unchecked('enemy.mountain_ram');
final ContentId guardian = ContentId.unchecked('enemy.hollow_guardian');
final ContentId oldGrey = ContentId.unchecked('enemy.old_grey');
final ContentId foreman = ContentId.unchecked('enemy.gallery_foreman');

// -- Projects -----------------------------------------------------------------
final ContentId mill = ContentId.unchecked('project.havens_rest_mill');
final ContentId watchtower = ContentId.unchecked('project.ranger_watchtower');
final ContentId lift = ContentId.unchecked('project.stonefall_lift');
final ContentId shelter = ContentId.unchecked('project.frostmere_shelter');
final ContentId fieldCamp = ContentId.unchecked('project.hollow_field_camp');
final ContentId granary = ContentId.unchecked('project.havens_rest_granary');
final ContentId galleryWorks = ContentId.unchecked(
  'project.lower_gallery_works',
);
final ContentId undercroft = ContentId.unchecked('project.hollow_undercroft');

// -- Contracts ----------------------------------------------------------------
final ContentId herbalSupplies = ContentId.unchecked(
  'contract.herbal_supplies',
);
final ContentId bearWatch = ContentId.unchecked('contract.bear_watch');
final ContentId predatorControl = ContentId.unchecked(
  'contract.predator_control',
);
final ContentId highlandSurvey = ContentId.unchecked(
  'contract.highland_survey',
);
final ContentId scholarsInterest = ContentId.unchecked(
  'contract.scholars_interest',
);
final ContentId barrowRubbings = ContentId.unchecked(
  'contract.barrow_rubbings',
);
final ContentId firstDescent = ContentId.unchecked('contract.first_descent');

// -- Resource nodes -----------------------------------------------------------
final ContentId meadowPatch = ContentId.unchecked('resource_node.meadow_patch');
final ContentId millGarden = ContentId.unchecked('resource_node.mill_garden');
final ContentId duskcapGrove = ContentId.unchecked(
  'resource_node.duskcap_grove',
);
final ContentId wardedGrove = ContentId.unchecked('resource_node.warded_grove');
final ContentId frostpineStand = ContentId.unchecked(
  'resource_node.frostpine_stand',
);
final ContentId shelteredFrostMeadow = ContentId.unchecked(
  'resource_node.sheltered_frost_meadow',
);
final ContentId hardenedCopperSeam = ContentId.unchecked(
  'resource_node.hardened_copper_seam',
);
final ContentId deepTinSeam = ContentId.unchecked(
  'resource_node.deep_tin_seam',
);
final ContentId oldWorkings = ContentId.unchecked('resource_node.old_workings');
final ContentId veiledSilkstrand = ContentId.unchecked(
  'resource_node.veiled_silkstrand',
);
final ContentId hollowThicket = ContentId.unchecked(
  'resource_node.hollow_thicket',
);
final ContentId undercroftSilkfall = ContentId.unchecked(
  'resource_node.undercroft_silkfall',
);
final ContentId deepHollowThicket = ContentId.unchecked(
  'resource_node.deep_hollow_thicket',
);

// -- Recipes ------------------------------------------------------------------
final ContentId rHerbBroth = ContentId.unchecked('recipe.herb_broth');
final ContentId rHerbBrothPair = ContentId.unchecked('recipe.herb_broth_pair');
final ContentId rOakPlankImproved = ContentId.unchecked(
  'recipe.oak_plank_improved',
);
final ContentId rPinePlank = ContentId.unchecked('recipe.pine_plank');
final ContentId rBronzeIngot = ContentId.unchecked('recipe.bronze_ingot');
final ContentId rDuskcapSkewer = ContentId.unchecked('recipe.duskcap_skewer');
final ContentId rFieldRations = ContentId.unchecked('recipe.field_rations');
final ContentId rHeartyStew = ContentId.unchecked('recipe.hearty_stew');
final ContentId rExpeditionStew = ContentId.unchecked('recipe.expedition_stew');
final ContentId rWaywardenTunic = ContentId.unchecked('recipe.waywarden_tunic');
final ContentId rTinbracedPickaxe = ContentId.unchecked(
  'recipe.tinbraced_pickaxe',
);
final ContentId rFrostwardenCoat = ContentId.unchecked(
  'recipe.frostwarden_coat',
);
final ContentId rReclaimAxe = ContentId.unchecked('recipe.reclaim_bronze_axe');
final ContentId rReclaimPickaxe = ContentId.unchecked(
  'recipe.reclaim_bronze_pickaxe',
);
final ContentId rReclaimChestplate = ContentId.unchecked(
  'recipe.reclaim_bronze_chestplate',
);

// -- Items --------------------------------------------------------------------
final ContentId meadowHerb = ContentId.unchecked('item.meadow_herb');
final ContentId herbBroth = ContentId.unchecked('item.herb_broth');
final ContentId duskcap = ContentId.unchecked('item.duskcap');
final ContentId duskcapSkewer = ContentId.unchecked('item.duskcap_skewer');
final ContentId travelerRation = ContentId.unchecked('item.traveler_ration');
final ContentId heartyStew = ContentId.unchecked('item.hearty_stew');
final ContentId expeditionStew = ContentId.unchecked('item.expedition_stew');
final ContentId oakLog = ContentId.unchecked('item.oak_log');
final ContentId oakPlank = ContentId.unchecked('item.oak_plank');
final ContentId pineLog = ContentId.unchecked('item.pine_log');
final ContentId pinePlank = ContentId.unchecked('item.pine_plank');
final ContentId copperOre = ContentId.unchecked('item.copper_ore');
final ContentId tinOre = ContentId.unchecked('item.tin_ore');
final ContentId scrapMetal = ContentId.unchecked('item.scrap_metal');
final ContentId bronzeIngot = ContentId.unchecked('item.bronze_ingot');
final ContentId rimeBlossom = ContentId.unchecked('item.rime_blossom');
final ContentId gloomSilk = ContentId.unchecked('item.gloom_silk');
final ContentId hollowRoot = ContentId.unchecked('item.hollow_root');
final ContentId boarHide = ContentId.unchecked('item.boar_hide');
final ContentId boarTusk = ContentId.unchecked('item.boar_tusk');
final ContentId bearPelt = ContentId.unchecked('item.bear_pelt');
final ContentId lynxPelt = ContentId.unchecked('item.lynx_pelt');
final ContentId ramWool = ContentId.unchecked('item.ram_wool');
final ContentId hollowSigil = ContentId.unchecked('item.hollow_sigil');
final ContentId travelerTunic = ContentId.unchecked('item.traveler_tunic');
final ContentId bronzeSword = ContentId.unchecked('item.bronze_sword');
final ContentId bronzeLongsword = ContentId.unchecked('item.bronze_longsword');
final ContentId bronzeAxe = ContentId.unchecked('item.bronze_axe');
final ContentId bronzePickaxe = ContentId.unchecked('item.bronze_pickaxe');
final ContentId bronzeChestplate = ContentId.unchecked(
  'item.bronze_chestplate',
);
final ContentId reinforcedPickaxe = ContentId.unchecked(
  'item.reinforced_pickaxe',
);
final ContentId bearhideCoat = ContentId.unchecked('item.bearhide_coat');
final ContentId frostlinedJerkin = ContentId.unchecked(
  'item.frostlined_jerkin',
);
final ContentId frostwardenCoat = ContentId.unchecked('item.frostwarden_coat');

/// The owner-like midgame state (thesis §16): every rank-1 project complete,
/// the wolf and the goblin Known, professions in the middle of their ladders,
/// bronze gear in the bag, standing at [at].
///
/// Every staged fact is one the owner's save has already earned:
///
/// - `completedProjects` — the five rank-1 projects are the recorded midgame
///   (the Granary/Lower Gallery/Undercroft gates read exactly this set);
/// - wolf and goblin at Known — 25 wolf victories were the Wolf Problem
///   grind, and the goblin galleries are the bronze road (read from the
///   registry's own `knownAt`, never hardcoded);
/// - Smithing 7 / Mining 8 / Woodcutting 7 / Foraging 9 / Cooking 9 — the
///   pre-0028 ceilings were S7/C9, and the gathering ladders sit where the
///   shipped nodes (old_workings Min 8, veiled_silkstrand For 8) put them;
/// - bronze kit — the longsword and Bearhide Coat are the pre-0028 capstones
///   (`verge_tier_loop_test` walks the longsword's own bill), the Reinforced
///   Pickaxe is the tier-2 tool `contract.mine_hardware` teaches, and the
///   Bronze Sword is the Hollow's standing entry key.
GameEngine ownerLikeMidgame({
  required ContentId at,
  Map<ContentId, int> items = const <ContentId, int>{},
  Map<ContentId, int> skillXp = const <ContentId, int>{},
  Map<ContentId, int> victories = const <ContentId, int>{},
  Map<ContentId, int> contractCompletions = const <ContentId, int>{},
}) {
  final GameEngine fresh = GameEngine.newGame(registry: registry);
  Inventory inventory = fresh.state.inventory
      .adding(bronzeSword, 1)
      .adding(bronzeLongsword, 1)
      .adding(bronzeAxe, 1)
      .adding(reinforcedPickaxe, 1)
      .adding(bearhideCoat, 1);
  for (final MapEntry<ContentId, int> e in items.entries) {
    inventory = inventory.adding(e.key, e.value);
  }
  const int experience = 3650; // The veteran_hunts_test persona.
  final int level = CombatRules.levelFor(experience);
  final GameState state = fresh.state.copyWith(
    inventory: inventory,
    equipment: Equipment(<EquipmentSlot, ContentId>{
      EquipmentSlot.weapon: bronzeLongsword,
      EquipmentSlot.armor: bearhideCoat,
    }),
    skills: SkillProgress(<ContentId, int>{
      woodcutting: 2020, // level 7
      mining: 2800, // level 8
      foraging: 2970, // level 9
      smithing: 2390, // level 7 — below every 0028 recipe, deliberately
      cooking: 2970, // level 9 — the pre-0028 ceiling
      ...skillXp,
    }),
    player: PlayerState(
      level: level,
      experience: experience,
      hp: CombatRules.maxHpFor(level),
    ),
    world: WorldState(
      currentLocation: at,
      unlockedLocations: <ContentId>{haven, woods, mine, frostmere, hollow},
    ),
    progress: fresh.state.progress.copyWith(
      completedProjects: <ContentId>{
        mill,
        watchtower,
        lift,
        shelter,
        fieldCamp,
      },
      enemyVictories: <ContentId, int>{
        wolf: registry.enemies[wolf]!.knownAt,
        goblin: registry.enemies[goblin]!.knownAt,
        ...victories,
      },
      contractCompletions: contractCompletions,
    ),
  );
  return GameEngine(registry: registry, state: state);
}

/// One walked proof: an engine, the events it committed, and the bill
/// arithmetic — everything asserted is read off the engine or its events,
/// never recomputed from content.
final class _Walk {
  _Walk(this.engine);

  final GameEngine engine;
  final List<GameEvent> log = <GameEvent>[];
  int startBanked = 0;

  GameState get state => engine.state;

  void fund(int steps, String reason) {
    must(GrantSyntheticSteps(steps: steps, reason: reason));
    startBanked = engine.state.steps.banked;
  }

  EngineResult exec(GameCommand command) {
    final EngineResult r = engine.execute(command);
    log.addAll(r.events);
    return r;
  }

  void must(GameCommand command) {
    final EngineResult r = exec(command);
    expect(
      r.isAccepted,
      isTrue,
      reason: '${command.name} was refused: ${r.rejection}',
    );
  }

  int spentAt(String label, void Function() body) {
    final int before = engine.state.steps.banked;
    body();
    final int cost = before - engine.state.steps.banked;
    // ignore: avoid_print
    print('  ${label.padRight(40)} ${cost.toString().padLeft(7)} steps');
    return cost;
  }

  /// The bill's two step-charging classes, summed off the committed events.
  int get gatherSteps => log.whereType<ResourceGathered>().fold<int>(
    0,
    (int sum, ResourceGathered e) => sum + e.stepsSpent,
  );

  int get travelSteps => log.whereType<LocationTravelled>().fold<int>(
    0,
    (int sum, LocationTravelled e) => sum + e.stepsSpent,
  );

  /// What the engine actually took from the bank since [fund].
  int get spent => startBanked - engine.state.steps.banked;

  int owned(ContentId item) => engine.state.inventory.quantityOf(item);

  void gatherUntil(ContentId node, ContentId item, int quantity) {
    while (owned(item) < quantity) {
      must(GatherResource(node: node));
    }
  }

  void craftUntil(ContentId recipe, ContentId output, int quantity) {
    while (owned(output) < quantity) {
      must(CraftItem(recipe: recipe));
    }
  }

  /// Fights to resolution: brace answers every telegraph, [food] is eaten at
  /// or below [eatAt] — the veteran_hunts_test policy. True on victory.
  bool fight(ContentId enemy, {ContentId? food, int eatAt = 20}) {
    must(StartEncounter(enemy: enemy));
    for (int i = 0; i < 160 && engine.state.encounter != null; i++) {
      final EncounterState e = engine.state.encounter!;
      final bool eat =
          food != null &&
          e.playerHp <= eatAt &&
          e.playerHp < e.playerMaxHp &&
          engine.state.inventory.has(food);
      final GameCommand command = eat
          ? CombatEat(item: food)
          : e.telegraph
          ? const CombatBrace()
          : const CombatAttack();
      final EngineResult r = exec(command);
      expect(r.isAccepted, isTrue, reason: '${r.rejection}');
      if (r.events.any((GameEvent ev) => ev is EncounterWon)) return true;
      if (r.events.any((GameEvent ev) => ev is EncounterLost)) return false;
    }
    fail('fight with ${enemy.value} did not resolve');
  }

  void mustWin(ContentId enemy, {ContentId? food, int eatAt = 20}) {
    expect(
      fight(enemy, food: food, eatAt: eatAt),
      isTrue,
      reason: 'the walk needs the win over ${enemy.value}',
    );
  }

  /// Eats [food] outside combat until full or the bag runs out.
  void healUp(ContentId food) {
    while (engine.state.player.hp <
            CombatRules.maxHpFor(engine.state.player.level) &&
        engine.state.inventory.has(food)) {
      must(EatFood(item: food));
    }
  }

  bool enemyAvailable(ContentId enemy) => engine.state.world.isAvailable(
    enemy,
    registry.enemies[enemy]!.encountersPerVisit,
  );

  int bountyCount(ContentId contract) =>
      engine.state.progress.bountyProgress[contract] ?? 0;

  void printTotal(String label, int total) {
    // ignore: avoid_print
    print(
      '  ${'—' * 40} ${'—' * 7}\n'
      '  ${label.padRight(40)} ${total.toString().padLeft(7)} steps\n',
    );
  }
}

void main() {
  test('proof 1 — fresh short loop: meadow, one broth, one board completion '
      'inside 2,000 gather-steps', () {
    // The walked bill (authored figures, charged by the engine):
    //
    //   Gather Meadow Patch ×7        7 × 80 =   560 steps
    //   Cook Herb Broth (2 herbs)                  0 steps (crafting is free)
    //   Complete "Herbal Supplies" (5 herbs)       0 steps
    //   ------------------------------------------------
    //   TOTAL                                    560 steps — the SHORT band.
    //
    // Seven gathers fund both pursuits: two herbs become the broth, five are
    // the healer's order. No travel — the whole first session is at home.
    final _Walk w = _Walk(newEngine());
    w.fund(5000, 'depth offensive proof 1: fresh short loop');

    // ignore: avoid_print
    print('\nDEPTH OFFENSIVE proof 1 — fresh short loop\n');
    w.spentAt('Gather Meadow Patch x7', () {
      for (int i = 0; i < 7; i++) {
        w.must(GatherResource(node: meadowPatch));
      }
    });
    w.spentAt('Cook: Herb Broth (no steps)', () {
      w.must(CraftItem(recipe: rHerbBroth));
    });
    w.spentAt('Complete: Herbal Supplies (no steps)', () {
      w.must(CompleteContract(contract: herbalSupplies));
    });
    w.printTotal('TOTAL, first session', w.spent);

    // The broth exists and the board paid out — at least one completion.
    expect(w.log.whereType<ItemCrafted>().single.item, herbBroth);
    final ContractCompleted done = w.log.whereType<ContractCompleted>().single;
    expect(done.contract, herbalSupplies);
    expect(done.completionsAfter, 1, reason: 'at least one contract completed');

    // The bill, as the engine charged it.
    expect(
      w.gatherSteps,
      560,
      reason: 'seven meadow gathers at the authored 80 steps each',
    );
    expect(w.travelSteps, 0, reason: 'the first session never leaves home');
    expect(
      w.gatherSteps,
      lessThanOrEqualTo(2000),
      reason: 'the opening loop stays in the SHORT band',
    );
    expect(
      w.spent,
      w.gatherSteps + w.travelSteps,
      reason: 'every step of the bill is accounted for',
    );
  });

  test('proof 2 — owner-like install sweep: the 0028 pursuits exist the '
      'moment the pack lands, with not one step walked', () {
    // Thesis §16, at install on the owner-like save: the Granary and the
    // Lower Gallery are on their boards (their `requiresProject` gates read
    // the completed Mill and Lift), Old Grey and the Foreman accept (wolf
    // and goblin are already Known), and the Smithing 8–10 recipes are
    // locked by level and by nothing else. No steps are granted anywhere in
    // this proof — immediate pursuits are the claim, not walking.

    // -- The rank-2 projects contribute (requiresProject satisfied) ---------
    final _Walk atHaven = _Walk(
      ownerLikeMidgame(at: haven, items: <ContentId, int>{oakPlank: 1}),
    );
    final EngineResult granaryOffer = atHaven.exec(
      ContributeToProject(
        project: granary,
        contributions: <ContentId, int>{oakPlank: 1},
      ),
    );
    expect(
      granaryOffer.isAccepted,
      isTrue,
      reason:
          'the Granary opens the moment the pack lands — the Mill is '
          'already built (${granaryOffer.rejection})',
    );
    final ProjectContributed granaryReceipt = granaryOffer.events
        .whereType<ProjectContributed>()
        .single;
    expect(granaryReceipt.project, granary);
    expect(granaryReceipt.projectCompleted, isFalse);

    final _Walk atMine = _Walk(
      ownerLikeMidgame(at: mine, items: <ContentId, int>{oakPlank: 1}),
    );
    expect(
      atMine
          .exec(
            ContributeToProject(
              project: galleryWorks,
              contributions: <ContentId, int>{oakPlank: 1},
            ),
          )
          .isAccepted,
      isTrue,
      reason: 'the Lower Gallery opens at install — the Lift is built',
    );

    // Control: the same command on a fresh save is refused for the gate,
    // proving the gate reads project completion and nothing else.
    final EngineResult freshRefusal = newEngine().execute(
      ContributeToProject(
        project: granary,
        contributions: <ContentId, int>{oakPlank: 1},
      ),
    );
    expect(freshRefusal.isAccepted, isFalse);
    expect(freshRefusal.rejection!.code, RejectionCode.projectNotAvailable);

    // -- The Known-gated veterans accept (gates already met) ----------------
    expect(
      _Walk(
        ownerLikeMidgame(at: woods),
      ).exec(StartEncounter(enemy: oldGrey)).isAccepted,
      isTrue,
      reason: 'Old Grey shows itself — the wolf is already Known',
    );
    expect(
      _Walk(
        ownerLikeMidgame(at: mine),
      ).exec(StartEncounter(enemy: foreman)).isAccepted,
      isTrue,
      reason: 'the Foreman shows itself — the goblin is already Known',
    );

    // -- The Smithing 8–10 recipes: gated by level, and by nothing else -----
    // Every ingredient is granted, so the only refusal left standing is the
    // level — and `recipeLockReason` (the projections' own oracle) answers
    // null, proving no project or contract lock hides behind the ladder.
    final Map<ContentId, int> benchStock = <ContentId, int>{
      travelerTunic: 1,
      boarHide: 2,
      boarTusk: 2,
      ramWool: 4,
      tinOre: 3,
      bronzeIngot: 2,
      pinePlank: 1,
      frostlinedJerkin: 1,
      bearPelt: 2,
      lynxPelt: 2,
      bronzePickaxe: 1,
      bronzeChestplate: 1,
    };
    final List<ContentId> ladder = <ContentId>[
      rWaywardenTunic, // S8
      rReclaimAxe, // S8
      rReclaimPickaxe, // S8
      rReclaimChestplate, // S8
      rTinbracedPickaxe, // S9
      rFrostwardenCoat, // S10
    ];

    final GameEngine smithSeven = ownerLikeMidgame(
      at: haven,
      items: benchStock,
    );
    for (final ContentId recipe in ladder) {
      expect(
        smithSeven.recipeLockReason(
          registry.recipes[recipe]!,
          smithSeven.state,
        ),
        isNull,
        reason:
            '${recipe.value}: no project or contract lock — the ladder is '
            'the only gate',
      );
      final EngineResult refused = smithSeven.execute(
        CraftItem(recipe: recipe),
      );
      expect(refused.isAccepted, isFalse);
      expect(
        refused.rejection!.code,
        RejectionCode.skillLevelTooLow,
        reason:
            '${recipe.value}: with every ingredient in hand, Smithing 7 is '
            'refused for the level and for nothing else',
      );
    }

    final GameEngine smithTen = ownerLikeMidgame(
      at: haven,
      items: benchStock,
      skillXp: <ContentId, int>{smithing: 5460}, // level 10
    );
    for (final ContentId recipe in ladder) {
      expect(
        smithTen.execute(CraftItem(recipe: recipe)).isAccepted,
        isTrue,
        reason: '${recipe.value}: at Smithing 10 the craft goes through',
      );
    }

    // No steps were walked to see any of it.
    expect(atHaven.state.steps.banked, 0);
    expect(atMine.state.steps.banked, 0);
    expect(smithSeven.state.steps.banked, 0);
    expect(smithTen.state.steps.banked, 0);
  });

  test('proof 3 — the Granary arc: the whole bill from empty bags lands in '
      'the MEDIUM band and completes exactly once', () {
    // From the owner-like midgame with EMPTY material bags (gear only) and
    // the Foraging road finished (For 10 — hollow_thicket is authored
    // pre-0028 at For 10, and walking the arc on it keeps the root leg
    // deterministic instead of leaning on the Guardian's 70% drop).
    //
    // The Granary's authored bill:
    //   Stage 1: oak_plank ×12 (24 oak logs), pine_plank ×3 (9 pine logs)
    //   Stage 2: bronze_ingot ×5 (10 copper, 5 tin), scrap_metal ×3
    //   Stage 3: traveler_ration ×4, duskcap_skewer ×4, hearty_stew ×2,
    //            herb_broth ×6  (23 herbs, 6 duskcap, 2 hollow roots)
    //
    // The walked bill (authored ceilings; bonus yields can only shorten it):
    //   Frostmere: frostpine ×9 ................ 9 × 240 = 2,160
    //   Travel Frostmere -> Mine ......................... 3,000
    //   Mine: hardened copper ×5 ............... 5 × 200 = 1,000
    //         deep tin ×3 ...................... 3 × 190 =   570
    //         old workings ×3 .................. 3 × 260 =   780
    //   Travel Mine -> Woods ............................. 1,000
    //   Woods: warded grove ×12 ............... 12 × 200 = 2,400
    //          duskcap ×6 ...................... 6 × 130 =   780
    //   Travel Woods -> Hollow ........................... 2,400
    //   Hollow: hollow thicket ×2 .............. 2 × 300 =   600
    //   Travel Hollow -> Woods -> Haven .................. 2,900
    //   Haven: mill garden ×12 ................ 12 × 120 = 1,440
    //   ---------------------------------------------------------
    //   CEILING ......................................... 19,030
    //   WALKED (deterministic — the seed is a pure function
    //   of the starting state) ........................... 18,900
    //
    // — inside the 8,000–20,000 MEDIUM band, walked as one provisioning
    // circuit from the far end of the world home (any other start only adds
    // travel; the segments below are what the engine actually charged).
    final _Walk w = _Walk(
      ownerLikeMidgame(
        at: frostmere,
        skillXp: <ContentId, int>{foraging: 3820}, // level 10
      ),
    );
    w.fund(40000, 'depth offensive proof 3: granary arc');

    // ignore: avoid_print
    print('\nDEPTH OFFENSIVE proof 3 — the Granary arc\n');

    w.must(EquipItem(item: bronzeAxe));
    w.spentAt('Frostmere: frostpine (9 pine logs)', () {
      w.gatherUntil(frostpineStand, pineLog, 9);
    });
    w.spentAt('Travel -> Stonefall Mine', () {
      w.must(TravelTo(destination: mine));
    });
    w.must(EquipItem(item: reinforcedPickaxe));
    w.spentAt('Mine: copper 10, tin 5, scrap 3', () {
      w.gatherUntil(hardenedCopperSeam, copperOre, 10);
      w.gatherUntil(deepTinSeam, tinOre, 5);
      w.gatherUntil(oldWorkings, scrapMetal, 3);
    });
    w.spentAt('Travel -> Whispering Woods', () {
      w.must(TravelTo(destination: woods));
    });
    w.must(EquipItem(item: bronzeAxe));
    w.spentAt('Woods: oak 24, duskcap 6', () {
      w.gatherUntil(wardedGrove, oakLog, 24);
      w.gatherUntil(duskcapGrove, duskcap, 6);
    });
    w.spentAt('Travel -> Forgotten Hollow', () {
      w.must(TravelTo(destination: hollow));
    });
    w.spentAt('Hollow: roots 2', () {
      w.gatherUntil(hollowThicket, hollowRoot, 2);
    });
    w.spentAt('Travel -> Woods -> Haven', () {
      w.must(TravelTo(destination: woods));
      w.must(TravelTo(destination: haven));
    });
    w.spentAt('Haven: herbs 23', () {
      w.gatherUntil(millGarden, meadowHerb, 23);
    });

    w.spentAt('Cook and smith the larder (no steps)', () {
      w.craftUntil(rOakPlankImproved, oakPlank, 12);
      w.craftUntil(rPinePlank, pinePlank, 3);
      w.craftUntil(rBronzeIngot, bronzeIngot, 5);
      w.craftUntil(rHerbBrothPair, herbBroth, 10);
      w.craftUntil(rDuskcapSkewer, duskcapSkewer, 4);
      w.craftUntil(rFieldRations, travelerRation, 4);
      w.craftUntil(rHeartyStew, heartyStew, 2);
    });

    w.spentAt('Contribute all three stages (no steps)', () {
      w.must(
        ContributeToProject(
          project: granary,
          contributions: <ContentId, int>{oakPlank: 12, pinePlank: 3},
        ),
      );
      w.must(
        ContributeToProject(
          project: granary,
          contributions: <ContentId, int>{bronzeIngot: 5, scrapMetal: 3},
        ),
      );
      w.must(
        ContributeToProject(
          project: granary,
          contributions: <ContentId, int>{
            travelerRation: 4,
            duskcapSkewer: 4,
            heartyStew: 2,
            herbBroth: 6,
          },
        ),
      );
    });

    final int total = w.spent;
    w.printTotal('TOTAL, the Granary arc', total);

    // Completion fired exactly once, on the third stage.
    final List<ProjectContributed> completions = w.log
        .whereType<ProjectContributed>()
        .where((ProjectContributed e) => e.projectCompleted)
        .toList();
    expect(
      completions,
      hasLength(1),
      reason: 'the project-complete event fires exactly once',
    );
    expect(completions.single.project, granary);
    expect(w.state.progress.isProjectComplete(granary), isTrue);

    // The bill, as the engine charged it: the MEDIUM band.
    expect(
      total,
      greaterThan(8000),
      reason: 'the Granary costs $total steps — a project, not an errand',
    );
    expect(
      total,
      lessThan(20000),
      reason: 'the Granary costs $total steps — MEDIUM, not a capstone',
    );
    expect(
      w.gatherSteps + w.travelSteps,
      total,
      reason: 'every step of the bill is accounted for',
    );
  });

  test('proof 4 — the Undercroft chain: the sigil is shown and kept, the '
      'nodes unlock, and the first descent eats its stew', () {
    // From the owner-like midgame with the Field Camp complete (it is, in
    // the builder), the hollow_sigil in the bag (the Guardian's 100% drop —
    // the owner has beaten it), The Scholar's Interest on the record (the
    // completion that revealed hollow_depths and asked for the sigil the
    // first time), and the Foraging road finished (For 10 — the chain's own
    // nodes are authored For 9/10).
    //
    // The chain's authored bill:
    //   barrow_rubbings: pine_plank ×2, gloom_silk ×1 (sigil SHOWN)
    //   Stage 1: oak_log ×6, pine_plank ×3
    //   Stage 2: bronze_ingot ×4 (8 copper, 4 tin), scrap_metal ×2
    //   Stage 3: gloom_silk ×3, hearty_stew ×2, boar_hide ×2
    //   first_descent: expedition_stew ×1 (CONSUMED) + one Guardian victory
    //
    // The walked bill (authored ceilings; drops and bonus yields can only
    // shorten the loops, and boar re-arms are counted where they happen):
    //   Frostmere: frostpine ×15 .............. 15 × 240 = 3,600
    //              frost meadow ×1 (2 rime) ..... 1 × 260 =   260
    //   Travel Frostmere -> Mine ......................... 3,000
    //   Mine: hardened copper ×4, deep tin ×2, workings ×2  1,700
    //   Travel Mine -> Woods ............................. 1,000
    //   Woods: warded grove ×3, duskcap ×1 ................  730
    //          boar hides ×2 (fights cost no steps)
    //   Travel Woods -> Haven -> Woods (herbs, re-arm) ... 1,000
    //   Haven: mill garden ×3 .............................  360
    //   Travel Woods -> Hollow ........................... 2,400
    //   Hollow: veiled silkstrand ×2, thicket ×3 ......... 1,500
    //           silkfall ×1 + deep thicket ×1 (unlocked) ..  580
    //   ---------------------------------------------------------
    //   CEILING (before boar re-arm luck) ............... 16,130
    //   WALKED (deterministic; one boar re-arm) ......... 15,650
    final _Walk w = _Walk(
      ownerLikeMidgame(
        at: frostmere,
        items: <ContentId, int>{hollowSigil: 1},
        skillXp: <ContentId, int>{foraging: 3820}, // level 10
        contractCompletions: <ContentId, int>{scholarsInterest: 1},
      ),
    );
    w.fund(40000, 'depth offensive proof 4: undercroft chain');

    // ignore: avoid_print
    print('\nDEPTH OFFENSIVE proof 4 — the Undercroft chain\n');

    w.must(EquipItem(item: bronzeAxe));
    w.spentAt('Frostmere: pine 15, rime 2', () {
      w.gatherUntil(frostpineStand, pineLog, 15);
      w.gatherUntil(shelteredFrostMeadow, rimeBlossom, 2);
    });
    w.spentAt('Travel -> Stonefall Mine', () {
      w.must(TravelTo(destination: mine));
    });
    w.must(EquipItem(item: reinforcedPickaxe));
    w.spentAt('Mine: copper 8, tin 4, scrap 2', () {
      w.gatherUntil(hardenedCopperSeam, copperOre, 8);
      w.gatherUntil(deepTinSeam, tinOre, 4);
      w.gatherUntil(oldWorkings, scrapMetal, 2);
    });
    w.spentAt('Travel -> Whispering Woods', () {
      w.must(TravelTo(destination: woods));
    });
    w.must(EquipItem(item: bronzeAxe));
    w.spentAt('Woods: oak 6, duskcap 1', () {
      w.gatherUntil(wardedGrove, oakLog, 6);
      w.gatherUntil(duskcapGrove, duskcap, 1);
    });
    w.spentAt('Boar hides x2 + herbs 6 (re-arms counted)', () {
      // Fights cost no steps; only the Haven round trips that re-arm the
      // boars — and fetch the stew herbs on the first pass — are charged.
      bool herbsFetched = false;
      while (w.owned(boarHide) < 2) {
        if (w.enemyAvailable(boar)) {
          w.mustWin(boar);
        } else {
          w.must(TravelTo(destination: haven));
          if (!herbsFetched) {
            w.gatherUntil(millGarden, meadowHerb, 6);
            herbsFetched = true;
          }
          w.must(TravelTo(destination: woods));
        }
      }
      if (!herbsFetched) {
        w.must(TravelTo(destination: haven));
        w.gatherUntil(millGarden, meadowHerb, 6);
        w.must(TravelTo(destination: woods));
      }
    });
    w.spentAt('Travel -> Forgotten Hollow', () {
      w.must(TravelTo(destination: hollow));
    });

    // The Undercroft's nodes do not exist as workable things yet.
    final EngineResult silkfallLocked = w.exec(
      GatherResource(node: undercroftSilkfall),
    );
    expect(silkfallLocked.isAccepted, isFalse);
    expect(
      silkfallLocked.rejection!.code,
      RejectionCode.nodeLocked,
      reason: 'the Silkfall is behind the Undercroft until it opens',
    );
    final EngineResult thicketLocked = w.exec(
      GatherResource(node: deepHollowThicket),
    );
    expect(thicketLocked.isAccepted, isFalse);
    expect(thicketLocked.rejection!.code, RejectionCode.nodeLocked);

    w.spentAt('Hollow: silk 4, roots 3', () {
      w.gatherUntil(veiledSilkstrand, gloomSilk, 4);
      w.gatherUntil(hollowThicket, hollowRoot, 3);
    });

    w.spentAt('Craft the descent kit (no steps)', () {
      w.craftUntil(rPinePlank, pinePlank, 5);
      w.craftUntil(rBronzeIngot, bronzeIngot, 4);
      w.craftUntil(rHeartyStew, heartyStew, 3);
      w.craftUntil(rExpeditionStew, expeditionStew, 1);
    });

    // Rubbings from the Sealed Door: the sigil is SHOWN, never consumed —
    // the L-1 boundary, live (requiresOwned on an entry-adjacent quest item).
    final int sigilBefore = w.owned(hollowSigil);
    expect(sigilBefore, 1);
    w.must(CompleteContract(contract: barrowRubbings));
    final ContractCompleted rubbings = w.log
        .whereType<ContractCompleted>()
        .singleWhere((ContractCompleted e) => e.contract == barrowRubbings);
    expect(
      rubbings.consumed.containsKey(hollowSigil),
      isFalse,
      reason: 'requiresOwned shows the sigil; the consumed map never lists it',
    );
    expect(
      w.owned(hollowSigil),
      sigilBefore,
      reason: 'the sigil is still in the bag after the rubbings',
    );

    // The project, staged through real contributions.
    w.must(
      ContributeToProject(
        project: undercroft,
        contributions: <ContentId, int>{oakLog: 6, pinePlank: 3},
      ),
    );
    w.must(
      ContributeToProject(
        project: undercroft,
        contributions: <ContentId, int>{bronzeIngot: 4, scrapMetal: 2},
      ),
    );
    w.must(
      ContributeToProject(
        project: undercroft,
        contributions: <ContentId, int>{
          gloomSilk: 3,
          heartyStew: 2,
          boarHide: 2,
        },
      ),
    );
    final List<ProjectContributed> completions = w.log
        .whereType<ProjectContributed>()
        .where((ProjectContributed e) => e.projectCompleted)
        .toList();
    expect(completions, hasLength(1));
    expect(completions.single.project, undercroft);

    // The two new nodes are now gatherable — one real gather each.
    w.spentAt('Silkfall + deep thicket, once each', () {
      w.must(GatherResource(node: undercroftSilkfall));
      w.must(GatherResource(node: deepHollowThicket));
    });

    // The First Descent: accepted, fought, and the stew is consumed.
    w.must(AcceptContract(contract: firstDescent));
    w.mustWin(guardian);
    final int stewBefore = w.owned(expeditionStew);
    expect(stewBefore, greaterThanOrEqualTo(1));
    w.must(CompleteContract(contract: firstDescent));
    final ContractCompleted descent = w.log
        .whereType<ContractCompleted>()
        .singleWhere((ContractCompleted e) => e.contract == firstDescent);
    expect(
      descent.consumed[expeditionStew],
      1,
      reason: 'the descent consumes its expedition stew — the orphan retired',
    );
    expect(w.owned(expeditionStew), stewBefore - 1);

    final int total = w.spent;
    w.printTotal('TOTAL, the Undercroft chain', total);
    expect(
      total,
      greaterThan(8000),
      reason: 'the chain costs $total steps — a rank-2 arc, not an errand',
    );
    expect(
      total,
      lessThan(20000),
      reason: 'the chain costs $total steps — the Lower Gallery band',
    );
    expect(
      w.gatherSteps + w.travelSteps,
      total,
      reason: 'every step of the bill is accounted for',
    );
  });

  test('proof 5 — the Frostwarden road: the deterministic peer beats the '
      '~50k frost_claw expectation', () {
    // The pre-0028 alpine coat (Clawguard) waited on a 6% signature drop —
    // ~17 lynx wins expected, at two per visit with a 6,000-step Frostmere
    // re-arm between pairs: the recorded ~50k-step stall. The Frostwarden
    // Coat is 0028's deterministic answer: guaranteed bounty pelts and
    // walked roads, no signature anywhere in the bill.
    //
    // Staged start, each grant one the owner's save has already earned:
    // - frostlined_jerkin — the donor. Pre-0028 midgame content (the
    //   cold_weather_kit pattern); the wave assumes it and retires the stall
    //   ABOVE it, so the road is measured from the jerkin, not before it.
    // - hearty_stew ×6 — larder, not progress: food changes no step figure,
    //   and the elite wave's own tuning assumes a provisioned hunter.
    // - Smithing 10 — the ladder's XP is proof 2's subject; this proof
    //   measures the WALK to the coat's materials, not the smithing grind.
    //
    // The walked road (travel only — fights and crafts cost no steps):
    //   Haven -> Woods ....................................  500
    //   bear_pelt ×2: Bear Watch pays one guaranteed pelt
    //     per completion (70% drops shortcut); each re-arm
    //     is a Woods<->Haven round trip ................ 1,000/re-arm
    //   Woods -> Mine -> Frostmere ....................... 4,000
    //   lynx_pelt ×2 / ram_wool ×2: Predator Control and
    //     Highland Survey pay guaranteed materials per
    //     completion (35%/60% drops shortcut); each re-arm
    //     is a Frostmere<->Mine round trip ............. 6,000/re-arm
    //   Craft: Frostwarden Coat (no steps)
    //   ---------------------------------------------------------
    //   FLOOR 4,500; CEILING under ~19,500 with worst re-arm luck.
    //   WALKED (deterministic; bears in one visit, one
    //   Frostmere re-arm) ............................... 10,500
    //   — either way far under the ~50,000-step signature expectation.
    final _Walk w = _Walk(
      ownerLikeMidgame(
        at: haven,
        items: <ContentId, int>{frostlinedJerkin: 1, heartyStew: 6},
        skillXp: <ContentId, int>{smithing: 5460}, // level 10
      ),
    );
    w.fund(40000, 'depth offensive proof 5: frostwarden road');

    // ignore: avoid_print
    print('\nDEPTH OFFENSIVE proof 5 — the Frostwarden road\n');

    w.spentAt('Travel -> Whispering Woods', () {
      w.must(TravelTo(destination: woods));
    });
    w.spentAt('Bear pelts x2 (Bear Watch, re-arms counted)', () {
      while (w.owned(bearPelt) < 2) {
        if (w.enemyAvailable(bear)) {
          if (!w.state.progress.acceptedContracts.contains(bearWatch)) {
            w.must(AcceptContract(contract: bearWatch));
          }
          w.healUp(heartyStew);
          w.mustWin(bear, food: heartyStew, eatAt: 22);
          if (w.owned(bearPelt) < 2 && w.bountyCount(bearWatch) >= 1) {
            w.must(CompleteContract(contract: bearWatch));
          }
        } else {
          w.must(TravelTo(destination: haven));
          w.must(TravelTo(destination: woods));
        }
      }
    });
    w.spentAt('Travel -> Mine -> Frostmere', () {
      w.must(TravelTo(destination: mine));
      w.must(TravelTo(destination: frostmere));
    });
    w.spentAt('Lynx pelts x2, ram wool x2 (re-arms counted)', () {
      while (w.owned(lynxPelt) < 2 || w.owned(ramWool) < 2) {
        bool fought = false;
        if (w.owned(lynxPelt) < 2 && w.enemyAvailable(lynx)) {
          if (!w.state.progress.acceptedContracts.contains(predatorControl)) {
            w.must(AcceptContract(contract: predatorControl));
          }
          w.healUp(heartyStew);
          w.mustWin(lynx, food: heartyStew, eatAt: 22);
          if (w.owned(lynxPelt) < 2 && w.bountyCount(predatorControl) >= 2) {
            w.must(CompleteContract(contract: predatorControl));
          }
          fought = true;
        }
        if (w.owned(ramWool) < 2 && w.enemyAvailable(ram)) {
          if (!w.state.progress.acceptedContracts.contains(highlandSurvey)) {
            w.must(AcceptContract(contract: highlandSurvey));
          }
          w.healUp(heartyStew);
          w.mustWin(ram, food: heartyStew, eatAt: 22);
          if (w.owned(ramWool) < 2 && w.bountyCount(highlandSurvey) >= 2) {
            w.must(CompleteContract(contract: highlandSurvey));
          }
          fought = true;
        }
        if (!fought) {
          w.must(TravelTo(destination: mine));
          w.must(TravelTo(destination: frostmere));
        }
      }
    });
    w.spentAt('Craft: Frostwarden Coat (no steps)', () {
      w.must(CraftItem(recipe: rFrostwardenCoat));
    });

    final int total = w.spent;
    w.printTotal('TOTAL to the Frostwarden Coat', total);

    // The coat exists, the jerkin was consumed, and no signature item was
    // consumed anywhere on the road.
    final ItemCrafted crafted = w.log.whereType<ItemCrafted>().singleWhere(
      (ItemCrafted e) => e.item == frostwardenCoat,
    );
    expect(crafted.consumed[frostlinedJerkin], 1);
    expect(w.state.inventory.has(frostwardenCoat), isTrue);
    expect(w.owned(frostlinedJerkin), 0, reason: 'the donor was consumed');
    final Set<ContentId> everConsumed = <ContentId>{
      for (final ItemCrafted e in w.log.whereType<ItemCrafted>())
        ...e.consumed.keys,
    };
    expect(
      everConsumed.contains(ContentId.unchecked('item.frost_claw')),
      isFalse,
      reason: 'the deterministic road never touches the signature claw',
    );

    // The bill, as the engine charged it — the road that beats the stall.
    expect(
      total,
      lessThan(20000),
      reason:
          'the deterministic road costs $total steps — the ~50k frost_claw '
          'expectation is beaten, not matched',
    );
    expect(
      w.gatherSteps + w.travelSteps,
      total,
      reason: 'every step of the bill is accounted for',
    );
  });
}
