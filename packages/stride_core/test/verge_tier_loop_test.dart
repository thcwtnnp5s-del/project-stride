// The Verge gear tier (`DECISIONS/0027`, experimental), walked end to end.
//
// E-6's question for new content: not "is the Bronze Longsword reachable in
// the graph" but "can a player actually walk the advertised chain, in an
// order the screens suggest, and what does it cost in real steps?" The chain
// deliberately crosses three regions — Stonefall bronze, a Woods bounty's
// tusk, the Hollow's gathered silk — so this is the test that fails if any
// link's gate is wrong (`MISTAKES.md` M-07).

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId stonefall = ContentId.unchecked('location.stonefall_mine');
final ContentId hollow = ContentId.unchecked('location.forgotten_hollow');

final ContentId trainingAxe = ContentId.unchecked('item.training_axe');
final ContentId trainingPick = ContentId.unchecked('item.training_pickaxe');

final ContentId mining = ContentId.unchecked('skill.mining');
final ContentId smithing = ContentId.unchecked('skill.smithing');
final ContentId foraging = ContentId.unchecked('skill.foraging');

void main() {
  test('the Verge chain is completable, and here is the bill', () {
    final GameEngine engine = newEngine();
    engine.execute(
      const GrantSyntheticSteps(steps: 400000, reason: 'verge tier probe'),
    );
    final int start = engine.state.steps.banked;

    void must(GameCommand command) {
      final EngineResult r = engine.execute(command);
      expect(
        r.isAccepted,
        isTrue,
        reason: '${command.name} was refused: ${r.rejection}',
      );
    }

    int levelOf(ContentId skill) => engine.registry.skills[skill]!.levelAt(
      engine.state.skills.experienceIn(skill),
    );

    int spentAt(String label, void Function() body) {
      final int before = engine.state.steps.banked;
      body();
      final int cost = before - engine.state.steps.banked;
      // ignore: avoid_print
      print('  ${label.padRight(38)} ${cost.toString().padLeft(7)} steps');
      return cost;
    }

    /// Attacks until the encounter resolves, and requires a win: the chain's
    /// deterministic tusk route is the bounty, and a bounty counts victories.
    void mustWin(ContentId enemy) {
      must(StartEncounter(enemy: enemy));
      for (int i = 0; i < 60 && engine.state.encounter != null; i++) {
        engine.execute(const CombatAttack());
      }
      expect(engine.state.encounter, isNull, reason: 'fight did not resolve');
      expect(
        engine.state.world.currentLocation,
        woods,
        reason: 'a defeat retreats to safety — the chain needs the win',
      );
    }

    void eatToFull() {
      final ContentId broth = ContentId.unchecked('item.herb_broth');
      while (engine.state.player.hp <
              CombatRules.maxHpFor(engine.state.player.level) &&
          engine.state.inventory.has(broth)) {
        engine.execute(EatFood(item: broth));
      }
    }

    // ignore: avoid_print
    print('\nVERGE TIER — provisional step budget\n');

    must(EquipItem(item: trainingAxe));

    // -- Foraging to 6, for the Silkstrand Thicket -------------------------
    final int forage = spentAt('Forage to Foraging 6 (Haven)', () {
      while (levelOf(foraging) < 6) {
        must(
          GatherResource(
            node: ContentId.unchecked('resource_node.meadow_patch'),
          ),
        );
      }
    });

    // Broth stock for the fights ahead. Crafting costs no steps.
    spentAt('Craft: broth stock (no steps)', () {
      final ContentId herb = ContentId.unchecked('item.meadow_herb');
      while (engine.state.inventory.quantityOf(herb) >= 3 &&
          engine.state.inventory.quantityOf(
                ContentId.unchecked('item.herb_broth'),
              ) <
              14) {
        // The Cooking-4 efficiency recipe pays for the grind's herbs.
        must(
          CraftItem(
            recipe: ContentId.unchecked(
              levelOf(ContentId.unchecked('skill.cooking')) >= 4
                  ? 'recipe.herb_broth_pair'
                  : 'recipe.herb_broth',
            ),
          ),
        );
      }
    });

    // -- Oak for handles, then Stonefall bronze to Smithing 6 --------------
    final int toWoods = spentAt('Travel -> Whispering Woods', () {
      must(TravelTo(destination: woods));
    });
    final int chop = spentAt('Chop oak x8', () {
      for (int i = 0; i < 8; i++) {
        must(
          GatherResource(node: ContentId.unchecked('resource_node.oak_stand')),
        );
      }
    });
    final int toMine = spentAt('Travel -> Stonefall Mine', () {
      must(TravelTo(destination: stonefall));
    });
    must(EquipItem(item: trainingPick));

    final int grind = spentAt('Mine and smelt to Smithing 6', () {
      final ContentId copper = ContentId.unchecked('item.copper_ore');
      final ContentId tin = ContentId.unchecked('item.tin_ore');
      final ContentId pick = ContentId.unchecked('item.bronze_pickaxe');
      while (levelOf(smithing) < 6 ||
          engine.state.inventory.quantityOf(
                ContentId.unchecked('item.bronze_ingot'),
              ) <
              4) {
        while (engine.state.inventory.quantityOf(copper) < 2) {
          must(
            GatherResource(
              node: ContentId.unchecked('resource_node.copper_seam'),
            ),
          );
        }
        // Tin wants Mining 3; copper is the only teacher below it.
        while (levelOf(mining) < 3) {
          must(
            GatherResource(
              node: ContentId.unchecked('resource_node.copper_seam'),
            ),
          );
        }
        while (engine.state.inventory.quantityOf(tin) < 1) {
          // Mining 4 opens the Deep Tin Seam — double tin for a tier-1
          // pickaxe, which is the Bronze Pickaxe's reason to exist.
          must(
            GatherResource(
              node: ContentId.unchecked(
                levelOf(mining) >= 4 &&
                        engine.state.equipment.inSlot(EquipmentSlot.tool) ==
                            pick
                    ? 'resource_node.deep_tin_seam'
                    : 'resource_node.tin_seam',
              ),
            ),
          );
        }
        must(CraftItem(recipe: ContentId.unchecked('recipe.bronze_ingot')));
        // The first spare ingots become the working tools of the tier.
        if (levelOf(smithing) >= 2 &&
            !engine.state.inventory.has(pick) &&
            engine.state.inventory.quantityOf(
                  ContentId.unchecked('item.bronze_ingot'),
                ) >=
                2) {
          if (!engine.state.inventory.has(
            ContentId.unchecked('item.oak_handle'),
          )) {
            must(CraftItem(recipe: ContentId.unchecked('recipe.oak_handle')));
          }
          must(CraftItem(recipe: ContentId.unchecked('recipe.bronze_pickaxe')));
          must(EquipItem(item: pick));
        }
      }
    });

    // The sword that opens the Hollow's door.
    spentAt('Craft: Bronze Sword (no steps)', () {
      if (!engine.state.inventory.has(ContentId.unchecked('item.oak_handle'))) {
        must(CraftItem(recipe: ContentId.unchecked('recipe.oak_handle')));
      }
      while (engine.state.inventory.quantityOf(
            ContentId.unchecked('item.bronze_ingot'),
          ) <
          7) {
        // 3 for the sword, 4 kept for the longsword.
        must(CraftItem(recipe: ContentId.unchecked('recipe.bronze_ingot')));
      }
      must(CraftItem(recipe: ContentId.unchecked('recipe.bronze_sword')));
      must(EquipItem(item: ContentId.unchecked('item.bronze_sword')));
    });

    // -- The tusk: the bounty is the deterministic route (P-10) ------------
    final int toBounty = spentAt('Travel -> Woods, boar bounty', () {
      must(TravelTo(destination: woods));
      must(
        AcceptContract(
          contract: ContentId.unchecked('contract.boar_on_the_trail'),
        ),
      );
      eatToFull();
      mustWin(ContentId.unchecked('enemy.wild_boar'));
      eatToFull();
      mustWin(ContentId.unchecked('enemy.wild_boar'));
      must(
        CompleteContract(
          contract: ContentId.unchecked('contract.boar_on_the_trail'),
        ),
      );
    });
    expect(
      engine.state.inventory.has(ContentId.unchecked('item.boar_tusk')),
      isTrue,
      reason: 'the bounty guarantees the tusk — the P-10 backstop',
    );

    // -- The silk: gathered, never a drop ----------------------------------
    final int toSilk = spentAt('Travel -> Forgotten Hollow, gather silk', () {
      must(TravelTo(destination: hollow));
      must(
        GatherResource(
          node: ContentId.unchecked('resource_node.silkstrand_thicket'),
        ),
      );
    });

    // -- The weapon that asked for the whole Verge -------------------------
    spentAt('Craft: Bronze Longsword (no steps)', () {
      must(CraftItem(recipe: ContentId.unchecked('recipe.bronze_longsword')));
      must(EquipItem(item: ContentId.unchecked('item.bronze_longsword')));
    });

    final PlayerCombatLoadout loadout = CombatRules.loadoutFor(
      engine.state,
      engine.registry,
    );
    expect(loadout.attack, 12, reason: 'the second weapon beat is real');

    final int total = start - engine.state.steps.banked;
    // ignore: avoid_print
    print(
      '  ${'—' * 38} ${'—' * 7}\n'
      '  ${'TOTAL to the Bronze Longsword'.padRight(38)} '
      '${total.toString().padLeft(7)} steps\n'
      '  ${'at 7,000 steps a day'.padRight(38)} '
      '${(total / 7000).toStringAsFixed(1).padLeft(7)} days\n',
    );

    // A capstone tier, not a weekend errand — but bounded. Ten ordinary days
    // of walking is the ceiling before the chase stops producing feedback;
    // two days is the floor before it stops being a chase.
    expect(total, lessThan(7000 * 10), reason: 'the Verge costs $total steps');
    expect(
      total,
      greaterThan(7000 * 2),
      reason: 'the Verge costs $total steps',
    );
    expect(
      forage + toWoods + chop + toMine + grind + toBounty + toSilk,
      total,
      reason: 'every step of the bill is accounted for',
    );
  });
}
