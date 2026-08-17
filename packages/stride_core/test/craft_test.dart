// CraftItem — turning walked-for materials into capability.
//
// Recipes have existed in content since F-02 and had no command to consume
// them, which is why the Craft tab shipped disabled in Phase 1. This is that
// command.
//
// The property most worth guarding is **atomicity**: ingredients leave and the
// output arrives in one fact. The journal is append-only, so a design that split
// them would make reachable a durable state in which the player's ore is gone
// and the ingot never came — and the ore represents steps they actually walked.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

final ContentId oakLog = ContentId.unchecked('item.oak_log');
final ContentId oakHandle = ContentId.unchecked('item.oak_handle');
final ContentId copperOre = ContentId.unchecked('item.copper_ore');
final ContentId tinOre = ContentId.unchecked('item.tin_ore');
final ContentId bronzeIngot = ContentId.unchecked('item.bronze_ingot');
final ContentId bronzeAxe = ContentId.unchecked('item.bronze_axe');
final ContentId meadowHerb = ContentId.unchecked('item.meadow_herb');
final ContentId herbBroth = ContentId.unchecked('item.herb_broth');

final ContentId smithing = ContentId.unchecked('skill.smithing');
final ContentId cooking = ContentId.unchecked('skill.cooking');

final ContentId recipeOakHandle = ContentId.unchecked('recipe.oak_handle');
final ContentId recipeBronzeIngot = ContentId.unchecked('recipe.bronze_ingot');
final ContentId recipeBronzeAxe = ContentId.unchecked('recipe.bronze_axe');
final ContentId recipeHerbBroth = ContentId.unchecked('recipe.herb_broth');

/// An engine holding [items] and [experience], without walking there first.
///
/// Built by substituting state rather than by playing the chain: a crafting
/// test that had to gather its own inputs would fail for gathering reasons and
/// report them as crafting ones.
GameEngine engineHolding(
  Map<ContentId, int> items, {
  Map<ContentId, int> experience = const <ContentId, int>{},
}) {
  final GameEngine seed = newEngine();
  Inventory inventory = seed.state.inventory;
  items.forEach((ContentId item, int count) {
    inventory = inventory.adding(item, count);
  });
  return GameEngine(
    registry: seed.registry,
    state: seed.state.copyWith(
      inventory: inventory,
      skills: SkillProgress(<ContentId, int>{
        ...seed.state.skills.experienceBySkill,
        ...experience,
      }),
    ),
  );
}

void main() {
  group('1 — a successful craft', () {
    test('consumes exactly the ingredients and grants exactly the output', () {
      final GameEngine engine = engineHolding(<ContentId, int>{oakLog: 5});

      final EngineResult result = engine.execute(
        CraftItem(recipe: recipeOakHandle),
      );

      expect(result.isAccepted, isTrue, reason: '${result.rejection}');
      expect(
        engine.state.inventory.quantityOf(oakLog),
        3,
        reason: '5 − 2. Exactly the recipe amount, not all of them.',
      );
      expect(engine.state.inventory.quantityOf(oakHandle), 1);
    });

    test('awards experience in the recipe’s skill', () {
      final GameEngine engine = engineHolding(<ContentId, int>{oakLog: 2});

      engine.execute(CraftItem(recipe: recipeOakHandle));

      expect(engine.state.skills.experienceIn(smithing), 15);
    });

    test('spends no steps at all', () {
      // GAME_BIBLE/SYSTEMS/04: the steps were already spent gathering, and
      // charging again would make crafting a toll booth in front of a reward
      // the player has already walked for.
      final GameEngine engine = engineHolding(<ContentId, int>{oakLog: 2});
      engine.execute(const GrantSyntheticSteps(steps: 500, reason: 'test'));

      engine.execute(CraftItem(recipe: recipeOakHandle));

      expect(engine.state.steps.banked, 500);
      expect(engine.state.steps.totalSpent, 0);
    });

    test('works at a zero step balance', () {
      // The consequence worth asserting rather than inferring: any recipe the
      // player can afford in materials is craftable at any balance, including
      // none. This is the game's answer to a week nobody could walk (Q-01).
      final GameEngine engine = engineHolding(<ContentId, int>{oakLog: 2});
      expect(engine.state.steps.banked, 0);

      expect(
        engine.execute(CraftItem(recipe: recipeOakHandle)).isAccepted,
        isTrue,
      );
      expect(engine.state.inventory.quantityOf(oakHandle), 1);
    });

    test('a multi-ingredient recipe takes the right amount of each', () {
      final GameEngine engine = engineHolding(
        <ContentId, int>{copperOre: 5, tinOre: 5},
        experience: <ContentId, int>{smithing: 150},
      );

      final EngineResult result = engine.execute(
        CraftItem(recipe: recipeBronzeIngot),
      );

      expect(result.isAccepted, isTrue, reason: '${result.rejection}');
      expect(engine.state.inventory.quantityOf(copperOre), 3, reason: '5 − 2');
      expect(engine.state.inventory.quantityOf(tinOre), 4, reason: '5 − 1');
      expect(engine.state.inventory.quantityOf(bronzeIngot), 1);
    });

    test('an exhausted ingredient leaves no zero-count ghost', () {
      final GameEngine engine = engineHolding(<ContentId, int>{oakLog: 2});

      engine.execute(CraftItem(recipe: recipeOakHandle));

      expect(engine.state.inventory.counts.containsKey(oakLog), isFalse);
      expect(engine.state.inventory.quantityOf(oakLog), 0);
    });

    test('it is one event, carrying literal amounts', () {
      final GameEngine engine = engineHolding(
        <ContentId, int>{copperOre: 2, tinOre: 1},
        experience: <ContentId, int>{smithing: 150},
      );

      final EngineResult result = engine.execute(
        CraftItem(recipe: recipeBronzeIngot),
      );

      expect(result.events, hasLength(1));
      final ItemCrafted event = result.events.single as ItemCrafted;
      expect(event.consumed, <ContentId, int>{copperOre: 2, tinOre: 1});
      expect(event.item, bronzeIngot);
      expect(event.quantity, 1);
      expect(event.skill, smithing);
      expect(event.experience, 30);
    });
  });

  group('2 — refusals', () {
    test('an unknown recipe is refused', () {
      final EngineResult result = engineHolding(<ContentId, int>{}).execute(
        CraftItem(recipe: ContentId.unchecked('recipe.philosophers_stone')),
      );

      expect(result.rejection!.code, RejectionCode.unknownRecipe);
    });

    // Bronze Axe, not Bronze Ingot, and the swap is worth a note.
    //
    // The ingot used to be the level-gate fixture at Smithing 2. The Phase 2
    // integration critic pass moved it to Smithing 1 — smelting is the *entry*
    // to Smithing, and gating it behind ten oak handles made "you mined ore and
    // cannot smelt it" the first thing a player met at the Craft screen. The
    // ordering rules below are unchanged; only the recipe that still has a gate
    // is different.
    test('too low a skill level is refused, and names the requirement', () {
      final GameEngine engine = engineHolding(<ContentId, int>{
        bronzeIngot: 9,
        oakHandle: 9,
      });

      final EngineResult result = engine.execute(
        CraftItem(recipe: recipeBronzeAxe),
      );

      expect(result.rejection!.code, RejectionCode.skillLevelTooLow);
      expect(result.rejection!.explanation, contains('Smithing 2'));
    });

    test('the level is checked before the ingredients', () {
      // Same ordering rule as gathering and travel: tell the player the thing
      // they cannot fix by walking, first.
      final GameEngine engine = engineHolding(<ContentId, int>{});

      final EngineResult result = engine.execute(
        CraftItem(recipe: recipeBronzeAxe),
      );

      expect(result.rejection!.code, RejectionCode.skillLevelTooLow);
    });

    test('smelting is reachable on the first visit to the forge', () {
      // The critic finding, as a regression. A player who has walked to
      // Stonefall, mined ore, and opened Craft must be able to smelt it —
      // without a detour through a different skill's material.
      final GameEngine engine = engineHolding(<ContentId, int>{
        copperOre: 2,
        tinOre: 1,
      });

      expect(
        engine.execute(CraftItem(recipe: recipeBronzeIngot)).isAccepted,
        isTrue,
        reason: 'ore must become metal at Smithing 1, with no prerequisite',
      );
    });

    test('missing ingredients are refused, and every shortfall is named', () {
      // Not just the first. A player two ingots and one handle short should
      // learn both in one refusal; discovering the second only after fixing the
      // first is the drip-feed that makes a craft screen feel evasive.
      final GameEngine engine = engineHolding(
        <ContentId, int>{},
        experience: <ContentId, int>{smithing: 700},
      );

      final EngineResult result = engine.execute(
        CraftItem(recipe: recipeBronzeAxe),
      );

      expect(result.rejection!.code, RejectionCode.insufficientIngredients);
      expect(result.rejection!.explanation, contains('Bronze Ingot 2 short'));
      expect(result.rejection!.explanation, contains('Oak Handle 1 short'));
    });

    test('one short is still short', () {
      final GameEngine engine = engineHolding(<ContentId, int>{meadowHerb: 2});

      final EngineResult result = engine.execute(
        CraftItem(recipe: recipeHerbBroth),
      );

      expect(result.rejection!.code, RejectionCode.insufficientIngredients);
      expect(result.rejection!.explanation, contains('Meadow Herb 1 short'));
    });

    test('a refused craft consumes nothing', () {
      final GameEngine engine = engineHolding(<ContentId, int>{meadowHerb: 2});
      final GameState before = engine.state;

      expect(
        engine.execute(CraftItem(recipe: recipeHerbBroth)).isRejected,
        isTrue,
      );

      expect(
        identical(engine.state, before),
        isTrue,
        reason: 'the same object — nothing was rebuilt, so nothing was partial',
      );
      expect(engine.state.inventory.quantityOf(meadowHerb), 2);
    });
  });

  group('3 — the whole bronze chain runs', () {
    test('ore and logs become a Bronze Axe, and the sums are exact', () {
      // The chain the milestone exists to prove. Every quantity below comes
      // from `recipes.json`, and the arithmetic is written out so a content
      // retune that breaks the chain fails here with a readable difference.
      //
      // Bronze Axe = 2 ingots + 1 handle
      //   2 ingots = 4 copper + 2 tin
      //   1 handle = 2 oak
      final GameEngine engine = engineHolding(
        <ContentId, int>{copperOre: 4, tinOre: 2, oakLog: 2},
        experience: <ContentId, int>{smithing: 700},
      );

      expect(
        engine.execute(CraftItem(recipe: recipeOakHandle)).isAccepted,
        isTrue,
      );
      expect(
        engine.execute(CraftItem(recipe: recipeBronzeIngot)).isAccepted,
        isTrue,
      );
      expect(
        engine.execute(CraftItem(recipe: recipeBronzeIngot)).isAccepted,
        isTrue,
      );
      final EngineResult axe = engine.execute(
        CraftItem(recipe: recipeBronzeAxe),
      );

      expect(axe.isAccepted, isTrue, reason: '${axe.rejection}');
      expect(engine.state.inventory.quantityOf(bronzeAxe), 1);
      expect(
        engine.state.inventory.counts.keys.map((ContentId i) => i.value),
        isNot(contains('item.copper_ore')),
        reason: 'the inputs were consumed to the last unit',
      );
      expect(engine.state.inventory.quantityOf(tinOre), 0);
      expect(engine.state.inventory.quantityOf(oakLog), 0);
      expect(engine.state.inventory.quantityOf(bronzeIngot), 0);
      expect(engine.state.inventory.quantityOf(oakHandle), 0);
    });

    test('the crafted axe is a real tier-1 axe', () {
      // The point of the chain: it unlocks Frostpine Stand, which needs an axe
      // of tier 1. If this ever stops being true the alpine region becomes
      // unreachable content.
      final ItemDefinition axe = newEngine().registry.items[bronzeAxe]!;

      expect(axe.toolKind, ToolKind.axe);
      expect(axe.tier, 1);
      expect(axe.slot, EquipmentSlot.tool);
    });
  });

  group('4 — crafting persists', () {
    test('the inventory and experience survive a save round trip', () {
      final GameEngine engine = engineHolding(<ContentId, int>{meadowHerb: 3});
      engine.execute(CraftItem(recipe: recipeHerbBroth));

      final GameState reloaded = decodeEnvelope(
        unframe(
          encodeSnapshot(
            state: engine.state,
            saveId: 'craft-0001',
            generation: 1,
            lastAppliedTransaction: 1,
            originSaltFingerprint: null,
          ),
        ).payload!,
      ).state;

      expect(reloaded.inventory.quantityOf(herbBroth), 1);
      expect(reloaded.inventory.quantityOf(meadowHerb), 0);
      expect(reloaded.skills.experienceIn(cooking), 12);
    });

    test('the event survives the journal codec', () {
      final GameEngine engine = engineHolding(
        <ContentId, int>{copperOre: 2, tinOre: 1},
        experience: <ContentId, int>{smithing: 150},
      );
      final EngineResult result = engine.execute(
        CraftItem(recipe: recipeBronzeIngot),
      );

      final GameEvent? round = decodeEvent(encodeEvent(result.events.single));

      expect(round, isA<ItemCrafted>());
      final ItemCrafted decoded = round! as ItemCrafted;
      expect(decoded.consumed, <ContentId, int>{copperOre: 2, tinOre: 1});
      expect(decoded.item, bronzeIngot);
      expect(decoded.experience, 30);
    });

    test('encoding one event twice produces identical bytes', () {
      // The consumed map is sorted on encode. Without that, the journal would
      // depend on how the ingredient list happened to be built, and two runs of
      // the same craft would write different lines.
      final ItemCrafted event = ItemCrafted(
        sequence: 0,
        recipe: recipeBronzeIngot,
        consumed: <ContentId, int>{tinOre: 1, copperOre: 2},
        item: bronzeIngot,
        quantity: 1,
        skill: smithing,
        experience: 30,
      );
      final ItemCrafted reversed = ItemCrafted(
        sequence: 0,
        recipe: recipeBronzeIngot,
        consumed: <ContentId, int>{copperOre: 2, tinOre: 1},
        item: bronzeIngot,
        quantity: 1,
        skill: smithing,
        experience: 30,
      );

      expect(
        canonicalJson(encodeEvent(event)),
        canonicalJson(encodeEvent(reversed)),
      );
    });

    test('a corrupt negative consumption is refused, not replayed', () {
      // A negative consumption would *add* inventory on replay — a corrupt
      // record minting items rather than a save loading.
      final Map<String, Object?> encoded = encodeEvent(
        ItemCrafted(
          sequence: 0,
          recipe: recipeHerbBroth,
          consumed: <ContentId, int>{meadowHerb: 3},
          item: herbBroth,
          quantity: 1,
          skill: cooking,
          experience: 12,
        ),
      );
      (encoded['consumed']! as List<Object?>).first = <String, Object?>{
        'item': meadowHerb.value,
        'n': -3,
      };

      expect(decodeEvent(encoded), isNull);
    });
  });
}
