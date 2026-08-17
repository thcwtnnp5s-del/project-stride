// The intended Phase 2 loop, walked end to end, with the step budget printed.
//
// This is the integration critic's question asked as a test: **can a player
// actually complete the loop the milestone advertises, and what does it cost in
// real walking?** A content set can satisfy every structural check and still be
// unplayable because the numbers are wrong, and the numbers are exactly what a
// week of the owner's walking is about to be spent against.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

final ContentId havensRest = ContentId.unchecked('location.havens_rest');
final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId stonefall = ContentId.unchecked('location.stonefall_mine');
final ContentId frostmere = ContentId.unchecked('location.frostmere');

final ContentId trainingAxe = ContentId.unchecked('item.training_axe');
final ContentId trainingPick = ContentId.unchecked('item.training_pickaxe');

void main() {
  test('the whole advertised loop is completable, and here is the bill', () {
    final GameEngine engine = newEngine();
    // A generous but finite grant, so an unaffordable step shows up as a
    // rejection rather than as a silent stall.
    engine.execute(
      const GrantSyntheticSteps(steps: 200000, reason: 'loop budget probe'),
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

    int spentAt(String label, void Function() body) {
      final int before = engine.state.steps.banked;
      body();
      final int cost = before - engine.state.steps.banked;
      // ignore: avoid_print
      print('  ${label.padRight(34)} ${cost.toString().padLeft(7)} steps');
      return cost;
    }

    // ignore: avoid_print
    print('\nPHASE 2 LOOP — provisional step budget\n');

    // Tools must be *equipped*, not merely owned. The starting loadout grants
    // them into the inventory and `GameStarted` equips nothing.
    must(EquipItem(item: trainingAxe));

    final int forage = spentAt('Forage x5 at Haven\'s Rest', () {
      for (int i = 0; i < 5; i++) {
        must(
          GatherResource(
            node: ContentId.unchecked('resource_node.meadow_patch'),
          ),
        );
      }
    });

    final int toWoods = spentAt('Travel -> Whispering Woods', () {
      must(TravelTo(destination: woods));
    });

    final int chop = spentAt('Chop oak x6', () {
      for (int i = 0; i < 6; i++) {
        must(
          GatherResource(node: ContentId.unchecked('resource_node.oak_stand')),
        );
      }
    });

    final int toStonefall = spentAt('Travel -> Stonefall Mine', () {
      must(TravelTo(destination: stonefall));
    });

    must(EquipItem(item: trainingPick));

    final int mine = spentAt('Mine copper x6', () {
      for (int i = 0; i < 6; i++) {
        must(
          GatherResource(
            node: ContentId.unchecked('resource_node.copper_seam'),
          ),
        );
      }
    });

    // Tin needs Mining 3, and copper is the only way to earn Mining xp. This
    // is the first place the loop asks the player to keep going rather than to
    // move on, so it is measured rather than assumed.
    final int toTin = spentAt('...more copper, to reach Mining 3', () {
      while (engine.registry.skills[ContentId.unchecked('skill.mining')]!
              .levelAt(
                engine.state.skills.experienceIn(
                  ContentId.unchecked('skill.mining'),
                ),
              ) <
          3) {
        must(
          GatherResource(
            node: ContentId.unchecked('resource_node.copper_seam'),
          ),
        );
      }
    });

    final int tin = spentAt('Mine tin x6', () {
      for (int i = 0; i < 6; i++) {
        must(
          GatherResource(node: ContentId.unchecked('resource_node.tin_seam')),
        );
      }
    });

    // Crafting costs nothing, which is the point — but the skill gates are
    // real, so the chain has to be walked in order.
    // Smithing is earned by smelting, which is the point of the rebalance the
    // critic pass forced: ore becomes metal immediately, and the axe is a few
    // crafts away rather than twenty oak logs away.
    final ContentId smithing = ContentId.unchecked('skill.smithing');
    int smithLevel() => engine.registry.skills[smithing]!.levelAt(
      engine.state.skills.experienceIn(smithing),
    );

    spentAt('Craft: ingots and a handle (no steps)', () {
      must(CraftItem(recipe: ContentId.unchecked('recipe.oak_handle')));
      while (engine.state.inventory.quantityOf(
                ContentId.unchecked('item.copper_ore'),
              ) >=
              2 &&
          engine.state.inventory.quantityOf(
                ContentId.unchecked('item.tin_ore'),
              ) >=
              1) {
        must(CraftItem(recipe: ContentId.unchecked('recipe.bronze_ingot')));
      }
    });

    expect(
      smithLevel(),
      greaterThanOrEqualTo(2),
      reason:
          'smelting the ore this trip must reach Smithing 2, or the Bronze Axe '
          'is gated behind a second expedition the loop never advertises',
    );

    spentAt('Craft: Bronze Axe (no steps)', () {
      must(CraftItem(recipe: ContentId.unchecked('recipe.bronze_axe')));
    });

    expect(
      engine.state.inventory.has(ContentId.unchecked('item.bronze_axe')),
      isTrue,
      reason: 'the first crafted upgrade is the proof the loop works',
    );

    final int toFrostmere = spentAt('Travel -> Frostmere (the pass)', () {
      must(TravelTo(destination: frostmere));
    });

    final int total = start - engine.state.steps.banked;
    // ignore: avoid_print
    print(
      '  ${'—' * 34} ${'—' * 7}\n'
      '  ${'TOTAL to a Bronze Axe at Frostmere'.padRight(34)} '
      '${total.toString().padLeft(7)} steps\n'
      '  ${'at 7,000 steps a day'.padRight(34)} '
      '${(total / 7000).toStringAsFixed(1).padLeft(7)} days\n',
    );

    // The milestone's own pacing requirement: useful feedback within days, not
    // months (`DECISIONS/0007`, and the Phase 2 brief's balance section).
    expect(
      total,
      lessThan(7000 * 5),
      reason:
          'reaching the first crafted upgrade and the alpine region costs '
          '$total steps — more than five ordinary days of walking, which is '
          'past the point where the owner can produce feedback',
    );
    expect(
      total,
      greaterThan(3000),
      reason:
          'the whole loop costs only $total steps, which is under a single '
          "day's walking — the economy would be giving progression away",
    );

    // Every figure above is spent, and the ledger agrees.
    expect(
      engine.state.steps.totalSpent,
      total,
      reason: 'the budget and the ledger must be the same arithmetic',
    );
    expect(
      forage + toWoods + chop + toStonefall + mine + toTin + tin + toFrostmere,
      total,
    );
  });
}
