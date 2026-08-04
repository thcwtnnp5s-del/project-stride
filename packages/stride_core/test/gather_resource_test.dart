// The playable action: banked energy becomes a resource.
//
// S-01A's product claim is that a walk turns into something. `AllocateSteps`
// debited the ledger and produced nothing, so until now the claim rested on a
// number going down. These assert the whole transaction: the refusals that
// protect it, the arithmetic, the atomicity, and the journal round trip that
// makes it survive a relaunch.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

final ContentId meadow = ContentId.unchecked('resource_node.meadow_patch');
final ContentId oakStand = ContentId.unchecked('resource_node.oak_stand');
final ContentId herb = ContentId.unchecked('item.meadow_herb');
final ContentId foraging = ContentId.unchecked('skill.foraging');

/// The base cost from `assets/content/v1/resource_nodes.json`.
///
/// Read from the registry rather than written down, so a content retune moves
/// the expectation with it instead of failing a test for the wrong reason.
int baseCost(ContentRegistry registry) =>
    registry.resourceNodes[meadow]!.stepCost;

GameEngine engineWith(int banked) {
  final GameEngine engine = newEngine();
  if (banked > 0) {
    engine.execute(GrantSyntheticSteps(steps: banked, reason: 'test'));
  }
  return engine;
}

void main() {
  final ContentRegistry registry = stepRegistry;
  final int cost = registry.profile.applyStepCost(baseCost(registry));

  group('GatherResource — refusals', () {
    test('an unknown node is refused and changes nothing', () {
      final GameEngine engine = engineWith(10000);
      final GameState before = engine.state;

      final EngineResult result = engine.execute(
        GatherResource(node: ContentId.unchecked('resource_node.nowhere')),
      );

      expect(result.isRejected, isTrue);
      expect(result.rejection!.code, RejectionCode.unknownResourceNode);
      // The same object, not an equal one: nothing was rebuilt, so nothing
      // could have been partially applied.
      expect(identical(engine.state, before), isTrue);
    });

    test('a node somewhere else is refused, naming travel as the answer', () {
      // Oak Stand is in Whispering Woods; a new game starts at Haven's Rest.
      final GameEngine engine = engineWith(10000);
      final GameState before = engine.state;

      final EngineResult result = engine.execute(
        GatherResource(node: oakStand),
      );

      expect(result.rejection!.code, RejectionCode.resourceNodeNotHere);
      expect(identical(engine.state, before), isTrue);
    });

    test('insufficient energy is refused, not clamped', () {
      final GameEngine engine = engineWith(cost - 1);
      final GameState before = engine.state;

      final EngineResult result = engine.execute(GatherResource(node: meadow));

      expect(result.rejection!.code, RejectionCode.insufficientSteps);
      expect(engine.state.steps.banked, cost - 1);
      expect(engine.state.inventory.quantityOf(herb), 0);
      expect(identical(engine.state, before), isTrue);
    });

    test('exactly enough energy is enough', () {
      // The boundary, asserted because `>` and `>=` are one keystroke apart and
      // the wrong one refuses a player who walked precisely far enough.
      final GameEngine engine = engineWith(cost);
      expect(engine.execute(GatherResource(node: meadow)).isAccepted, isTrue);
      expect(engine.state.steps.banked, 0);
    });

    test('the level requirement is checked before the cost', () {
      // Pine Ridge needs Woodcutting 8 and an axe. A level-1 player with no
      // energy must be told about the level, not about the price — sending them
      // walking towards a wall they will still hit is the worse answer.
      final GameEngine engine = engineWith(0);
      engine.execute(
        UnlockLocation(
          location: ContentId.unchecked('location.whispering_woods'),
        ),
      );
      engine.execute(
        EnterLocation(
          location: ContentId.unchecked('location.whispering_woods'),
        ),
      );

      final EngineResult result = engine.execute(
        GatherResource(node: ContentId.unchecked('resource_node.pine_ridge')),
      );

      expect(result.rejection!.code, RejectionCode.skillLevelTooLow);
    });

    test('a tool in the bag is not a tool in hand', () {
      // Oak Stand needs an axe, and the starting loadout grants a training axe
      // — into the *inventory*. `GameStarted` equips nothing. So this asserts
      // the distinction the requirement is actually about: owning a tool is not
      // wielding one, and the engine checks equipment.
      final GameEngine engine = engineWith(100000);
      engine.execute(
        UnlockLocation(
          location: ContentId.unchecked('location.whispering_woods'),
        ),
      );
      engine.execute(
        EnterLocation(
          location: ContentId.unchecked('location.whispering_woods'),
        ),
      );
      final ContentId axe = ContentId.unchecked('item.training_axe');
      expect(engine.state.inventory.has(axe), isTrue);

      expect(
        engine.execute(GatherResource(node: oakStand)).rejection!.code,
        RejectionCode.toolRequired,
      );

      engine.execute(EquipItem(item: axe));
      expect(engine.execute(GatherResource(node: oakStand)).isAccepted, isTrue);
    });
  });

  group('GatherResource — the transaction', () {
    test('spends exactly the profile-scaled cost, once', () {
      final GameEngine engine = engineWith(10000);
      final int before = engine.state.steps.banked;

      engine.execute(GatherResource(node: meadow));

      expect(engine.state.steps.banked, before - cost);
      expect(engine.state.steps.totalSpent, cost);
      // Granted never moves on a spend. Observed/granted/spent are three
      // different questions and a spend answers only the third.
      expect(engine.state.steps.totalGranted, 10000);
    });

    test('grants the yield and the experience in the same event', () {
      final GameEngine engine = engineWith(10000);

      final EngineResult result = engine.execute(GatherResource(node: meadow));

      expect(result.events, hasLength(1));
      final ResourceGathered event = result.events.single as ResourceGathered;

      final ResourceNodeDefinition node = registry.resourceNodes[meadow]!;
      expect(event.stepsSpent, cost);
      expect(event.quantity, registry.profile.applyYield(node.yieldsQuantity));
      expect(event.experience, registry.profile.applyXp(node.xp));

      expect(engine.state.inventory.quantityOf(herb), event.quantity);
      expect(engine.state.skills.experienceIn(foraging), event.experience);
    });

    test('repeating it is a second spend, not an idempotent no-op', () {
      // Gathering is a repeating activity. Two presses are two gathers, which
      // is the opposite of the equip path where the second is a no-op.
      final GameEngine engine = engineWith(10000);
      engine.execute(GatherResource(node: meadow));
      engine.execute(GatherResource(node: meadow));

      expect(engine.state.steps.totalSpent, cost * 2);
      expect(
        engine.state.inventory.quantityOf(herb),
        registry.profile.applyYield(
              registry.resourceNodes[meadow]!.yieldsQuantity,
            ) *
            2,
      );
    });

    test('spending is bounded by granted, never by observed', () {
      // A downward health correction lowers `totalObserved` and must never
      // reach into what the player already earned and spent.
      final GameEngine engine = engineWith(10000);
      engine.execute(GatherResource(node: meadow));
      final int spent = engine.state.steps.totalSpent;

      sync(
        engine,
        IncrementalSync(observations: <StepObservation>[obs(phone, 0, 0)]),
      );

      expect(engine.state.steps.totalSpent, spent);
      expect(engine.state.steps.totalGranted, 10000);
    });
  });

  group('GatherResource — replay', () {
    test('the event round-trips through the journal codec', () {
      final GameEngine engine = engineWith(10000);
      final ResourceGathered original =
          engine.execute(GatherResource(node: meadow)).events.single
              as ResourceGathered;

      final GameEvent? decoded = decodeEvent(encodeEvent(original));

      expect(decoded, isA<ResourceGathered>());
      final ResourceGathered round = decoded! as ResourceGathered;
      expect(round.sequence, original.sequence);
      expect(round.node, original.node);
      expect(round.stepsSpent, original.stepsSpent);
      expect(round.item, original.item);
      expect(round.quantity, original.quantity);
      expect(round.skill, original.skill);
      expect(round.experience, original.experience);
    });

    test('replaying the event reproduces the state that was committed', () {
      final GameEngine engine = engineWith(10000);
      final GameState before = engine.state;
      final List<GameEvent> events = engine
          .execute(GatherResource(node: meadow))
          .events;

      const EventReducer reducer = EventReducer();
      final GameState replayed = reducer.applyAll(
        before,
        events.map((GameEvent e) => decodeEvent(encodeEvent(e))!),
      );

      expect(replayed, engine.state);
    });

    test('a corrupt record is refused rather than replayed into a throw', () {
      // `stepsSpent` is what raises `totalSpent`, and `StepLedger` throws when
      // spent exceeds granted. A negative figure out of a damaged journal must
      // therefore be refused by the decoder — turning a bad record into a
      // repair, which the load path handles, rather than into a launch that
      // cannot start.
      final GameEngine engine = engineWith(10000);
      final Map<String, Object?> json = encodeEvent(
        engine.execute(GatherResource(node: meadow)).events.single,
      );

      expect(decodeEvent(<String, Object?>{...json, 'stepsSpent': -1}), isNull);
      expect(decodeEvent(<String, Object?>{...json, 'quantity': -1}), isNull);
      expect(decodeEvent(<String, Object?>{...json, 'xp': -1}), isNull);
    });
  });

  group('the level curve', () {
    test('levelAt walks the thresholds rather than dividing', () {
      final SkillDefinition skill = registry.skills[foraging]!;
      expect(skill.levelAt(0), 1);
      expect(skill.levelAt(skill.xpThresholds[1] - 1), 1);
      expect(skill.levelAt(skill.xpThresholds[1]), 2);
      expect(skill.levelAt(1 << 30), skill.maxLevel);
    });
  });
}
