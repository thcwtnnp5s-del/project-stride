// The production content must be valid, deterministic, and playable.
//
// This is the test that fails when someone edits a JSON file badly, which is
// the most likely way content breaks.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'content_test_support.dart';

void main() {
  group('production content', () {
    test('loads without a single validation error', () {
      final ContentLoadResult result = loadProduction(productionSource);

      // Print the whole report on failure — an author wants the list, not the
      // first line of it.
      expect(result.isValid, isTrue, reason: result.report.format());
    });

    test('contains the Milestone 01 content set', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;

      // DECISIONS/0004, as amended by DECISIONS/0017 and DECISIONS/0021:
      // scope is frozen at five skills, **five** locations, **four** enemies.
      // A test that counts is how a freeze stays frozen — and every count here
      // moved by an ADR, which is the only way one may move.
      //
      // Five skills are unchanged and re-frozen: fishing was considered for
      // Phase 2 and rejected, and a sixth skill still needs its own decision.
      // The fourth enemy is the Frost Lynx, added by `DECISIONS/0021` to the
      // one region that had no combat.
      expect(registry.skills, hasLength(5));
      expect(registry.locations, hasLength(5));
      expect(registry.enemies, hasLength(4));

      for (final String id in <String>[
        'skill.woodcutting',
        'skill.mining',
        'skill.foraging',
        'skill.smithing',
        'skill.cooking',
      ]) {
        expect(registry.skills, contains(ContentId.unchecked(id)));
      }
      for (final String id in <String>[
        'location.havens_rest',
        'location.whispering_woods',
        'location.stonefall_mine',
        'location.frostmere',
        'location.forgotten_hollow',
      ]) {
        expect(registry.locations, contains(ContentId.unchecked(id)));
      }
      for (final String id in <String>[
        'enemy.forest_wolf',
        'enemy.cave_goblin',
        'enemy.frost_lynx',
        'enemy.hollow_guardian',
      ]) {
        expect(registry.enemies, contains(ContentId.unchecked(id)));
      }
    });

    test('every shipped item carries an authored rarity', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;

      // `DECISIONS/0021` §4 wants "all items have a valid rarity" to hold *by
      // construction*, and it does: `rarity` is a required constructor
      // parameter read by `requireEnum`, so an item without one never reaches
      // a registry. This asserts the shipped pack against that, which is the
      // part construction cannot prove — that the bundle loads at all.
      expect(registry.items, isNotEmpty);
      for (final ItemDefinition item in registry.items.values) {
        expect(
          Rarity.values,
          contains(item.rarity),
          reason: '${item.id} carries no rarity',
        );
      }

      // The rarity table in `MILESTONES/WORLD_REWARD_DEPTH_01.md` §5 and
      // `GAME_BIBLE/SYSTEMS/08_ITEM_RARITY.md`, spot-checked at each rank that
      // content occupies. Provisional balance, pinned so a silent re-label
      // shows up as a failing test rather than as a different colour on a
      // phone.
      Rarity rarityOf(String id) =>
          registry.items[ContentId.unchecked(id)]!.rarity;
      expect(rarityOf('item.oak_log'), Rarity.uncommon);
      expect(rarityOf('item.wolf_pelt'), Rarity.common);
      expect(rarityOf('item.lynx_pelt'), Rarity.rare);
      expect(rarityOf('item.wolfhide_jerkin'), Rarity.rare);
      expect(rarityOf('item.frostlined_jerkin'), Rarity.epic);
      expect(rarityOf('item.hollow_sigil'), Rarity.epic);

      // Legendary is reserved. Nothing carries it yet, and the enum, the
      // style table and the tests cover it before content needs it
      // (`DECISIONS/0021` §4).
      expect(
        registry.items.values.where(
          (ItemDefinition i) => i.rarity == Rarity.legendary,
        ),
        isEmpty,
        reason:
            'a Legendary item is a design decision, not a content edit — see '
            'GAME_BIBLE/SYSTEMS/08_ITEM_RARITY.md',
      );
    });

    test('every enemy authors how many fights a visit holds', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;

      // `DECISIONS/0021` §1: normal enemies 2, the boss 1. Provisional
      // balance; the *shape* — a boss recurs less than a roamer, and no enemy
      // is unlimited — is what the decision guarantees.
      int perVisit(String id) =>
          registry.enemies[ContentId.unchecked(id)]!.encountersPerVisit;
      expect(perVisit('enemy.forest_wolf'), 2);
      expect(perVisit('enemy.cave_goblin'), 2);
      expect(perVisit('enemy.frost_lynx'), 2);
      expect(perVisit('enemy.hollow_guardian'), 1);

      for (final EnemyDefinition enemy in registry.enemies.values) {
        expect(
          enemy.encountersPerVisit,
          greaterThanOrEqualTo(1),
          reason: '${enemy.id} could never be fought',
        );
        if (enemy.isBoss) {
          expect(
            enemy.encountersPerVisit,
            1,
            reason: 'a boss beaten twice in one visit is not a boss',
          );
        }
      }
    });

    test('every location derives a kind from what content already says', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;

      // `DECISIONS/0021` §5. Derived, so there is no second source of truth in
      // the content files for the atlas to disagree with.
      LocationKind kindOf(String id) =>
          LocationKinds.kindFor(registry, ContentId.unchecked(id));
      expect(kindOf('location.havens_rest'), LocationKind.haven);
      expect(kindOf('location.forgotten_hollow'), LocationKind.perilous);
      expect(kindOf('location.stonefall_mine'), LocationKind.worksite);
      expect(kindOf('location.whispering_woods'), LocationKind.wilds);
      expect(kindOf('location.frostmere'), LocationKind.wilds);

      // Every location resolves, and exactly one is the haven — the start.
      final List<LocationKind> kinds = <LocationKind>[
        for (final ContentId id in registry.locations.keys)
          LocationKinds.kindFor(registry, id),
      ];
      expect(kinds, hasLength(registry.locations.length));
      expect(
        kinds.where((LocationKind k) => k == LocationKind.haven),
        hasLength(1),
      );
    });

    test('the Frost Lynx gives Frostmere the combat it had none of', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;
      final EnemyDefinition lynx =
          registry.enemies[ContentId.unchecked('enemy.frost_lynx')]!;

      expect(lynx.location, ContentId.unchecked('location.frostmere'));
      expect(lynx.isBoss, isFalse);
      expect(lynx.behavior, EnemyBehavior.flurry);
      expect((lynx.health, lynx.attack, lynx.defence), (30, 9, 2));
      expect(lynx.xp, 80);
      expect(
        lynx.drops.map(
          (EnemyDrop d) => (d.item.value, d.quantity, d.chancePercent),
        ),
        <(String, int, int)>[
          ('item.rime_blossom', 1, 50),
          ('item.lynx_pelt', 1, 35),
        ],
      );
    });

    test('the pelts are obtainable, and the jerkins are craftable', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;

      // The pelts come only from combat, which is why the reachability walker
      // had to learn enemy drops (`DECISIONS/0021` §1). Without that the two
      // new recipes would be unusable in the model while working in the game.
      final ReachabilityResult result = ReachabilityValidator(registry).analyse(
        targets: <ContentId>[
          ContentId.unchecked('item.wolf_pelt'),
          ContentId.unchecked('item.lynx_pelt'),
          ContentId.unchecked('item.wolfhide_jerkin'),
          ContentId.unchecked('item.frostlined_jerkin'),
        ],
      );
      expect(
        result.isReachable,
        isTrue,
        reason: result.blocks
            .map((ReachabilityBlock b) => '${b.reason.name}: ${b.explanation}')
            .join('\n'),
      );
      for (final String id in <String>[
        'recipe.wolfhide_jerkin',
        'recipe.frostlined_jerkin',
      ]) {
        expect(result.usableRecipes, contains(ContentId.unchecked(id)));
      }
    });

    test('grants exactly the approved starting loadout', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;

      expect(
        registry.startingLoadout.map((ContentId i) => i.value).toList(),
        <String>[
          'item.training_sword',
          'item.training_axe',
          'item.training_pickaxe',
          'item.traveler_tunic',
        ],
      );
    });

    test('Traveler equipment is granted, never craftable', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;
      final ContentId tunic = ContentId.unchecked('item.traveler_tunic');

      // DECISIONS/0004: there is no leather or cloth skill in the slice, and
      // none will be added for it.
      expect(
        registry.recipes.values.where(
          (RecipeDefinition r) => r.outputItem == tunic,
        ),
        isEmpty,
      );
    });

    test('no currency or merchant content exists', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;

      // DECISIONS/0004. A shop would short-circuit the loop the slice exists to
      // validate, so its absence is asserted rather than assumed.
      for (final ContentId id in registry.allIds) {
        expect(
          id.slug,
          isNot(
            anyOf(
              contains('coin'),
              contains('gold'),
              contains('currency'),
              contains('merchant'),
              contains('shop'),
              contains('vendor'),
            ),
          ),
          reason: '$id looks like currency or merchant content',
        );
      }
    });

    test('exactly one location is the start, and it is safe', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;
      final List<LocationDefinition> starts = registry.locations.values
          .where((LocationDefinition l) => l.isStart)
          .toList();

      expect(starts, hasLength(1));
      expect(starts.single.id, ContentId.unchecked('location.havens_rest'));
      // Defeat returns the player to the most recent safe destination
      // (DECISIONS/0003). A start that is not safe would leave nowhere to go.
      expect(starts.single.isSafe, isTrue);
    });

    test('every enemy lives in a defined location', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;
      for (final EnemyDefinition enemy in registry.enemies.values) {
        expect(registry.locations, contains(enemy.location));
      }
    });

    test('every skill reaches level 20 with a strictly increasing curve', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;

      for (final SkillDefinition skill in registry.skills.values) {
        expect(skill.maxLevel, 20, reason: '${skill.id} cap');
        expect(skill.xpThresholds, hasLength(20));
        expect(skill.xpThresholds.first, 0);
        for (int i = 1; i < skill.xpThresholds.length; i++) {
          expect(
            skill.xpThresholds[i],
            greaterThan(skill.xpThresholds[i - 1]),
            reason: '${skill.id} level ${i + 1}',
          );
        }
      }
    });
  });

  group('determinism', () {
    test('the same files and profile always produce the same registry', () {
      final ContentRegistry first = loadProduction(
        productionSource,
      ).requireRegistry;
      final ContentRegistry second = loadProduction(
        productionSource,
      ).requireRegistry;

      expect(first.signature, second.signature);
      expect(first.entryCount, second.entryCount);
    });

    test('file order does not affect the result', () {
      final ContentSource forward = productionSource;
      final ContentSource reversed = ContentSource(<String, String>{
        for (final String name in forward.orderedFilenames.reversed)
          name: forward.files[name]!,
      });

      // A map built in reverse insertion order must load identically. This is
      // the concrete form of "loading may not depend on file enumeration order".
      expect(
        loadProduction(reversed).requireRegistry.signature,
        loadProduction(forward).requireRegistry.signature,
      );
    });

    test('registry iteration is sorted, not insertion-ordered', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;
      final List<ContentId> ids = registry.items.keys.toList();
      final List<ContentId> sorted = <ContentId>[...ids]..sort();

      expect(ids, sorted);
    });

    test('validation errors are reported in a stable order', () {
      final ContentSource broken = productionWithOverride('duplicate_id.json');

      final List<String> first = loadProduction(
        broken,
      ).report.errors.map((ValidationError e) => e.format()).toList();
      final List<String> second = loadProduction(
        broken,
      ).report.errors.map((ValidationError e) => e.format()).toList();

      // Determinism applies to failure too. A reordering diff in CI output is
      // noise nobody should have to read past.
      expect(first, second);
    });
  });

  group('balance profiles', () {
    test('production leaves every base value unscaled', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;
      final BalanceProfile profile = registry.profile;

      expect(profile.id, BalanceProfile.productionId);
      expect(profile.releaseSafe, isTrue);
      expect(profile.applyStepCost(120), 120);
      expect(profile.applyXp(50), 50);
      expect(profile.applyYield(2), 2);
      expect(profile.applyEnemyHealth(40), 40);
    });

    test('accelerated QA changes pacing only', () {
      final ContentRegistry production = loadProduction(
        productionSource,
      ).requireRegistry;
      final ContentRegistry qa = const ContentLoader()
          .load(productionSource, profileId: BalanceProfile.acceleratedQaId)
          .requireRegistry;

      // Identical topology: same IDs, same references, same graph. Only the
      // numbers the profile scales may differ.
      expect(qa.allIds, production.allIds);
      expect(qa.recipes.length, production.recipes.length);
      expect(qa.locations.length, production.locations.length);

      for (final ContentId id in production.recipes.keys) {
        final RecipeDefinition p = production.recipes[id]!;
        final RecipeDefinition q = qa.recipes[id]!;
        expect(q.outputItem, p.outputItem);
        expect(
          q.ingredients.map((RecipeIngredient i) => i.item),
          p.ingredients.map((RecipeIngredient i) => i.item),
        );
      }
      for (final ContentId id in production.locations.keys) {
        expect(
          qa.locations[id]!.connections.map((LocationConnection c) => c.to),
          production.locations[id]!.connections.map(
            (LocationConnection c) => c.to,
          ),
        );
      }

      // And the pacing genuinely differs, or the profile does nothing.
      expect(qa.profile.applyStepCost(1000), lessThan(1000));
      expect(qa.profile.applyXp(100), greaterThan(100));
    });

    test('scaling never rounds a cost to zero', () {
      final ContentRegistry qa = const ContentLoader()
          .load(productionSource, profileId: BalanceProfile.acceleratedQaId)
          .requireRegistry;

      // A zero step cost would make an activity complete without walking,
      // which is the one thing step-clocked progression cannot allow — even
      // under QA acceleration.
      for (int base = 1; base <= 50; base++) {
        expect(qa.profile.applyStepCost(base), greaterThanOrEqualTo(1));
        expect(qa.profile.applyYield(base), greaterThanOrEqualTo(1));
        expect(qa.profile.applyEnemyHealth(base), greaterThanOrEqualTo(1));
      }
    });

    test('an unknown profile is refused with the available list', () {
      final ContentLoadResult result = const ContentLoader().load(
        productionSource,
        profileId: ContentId.unchecked('profile.does_not_exist'),
      );

      expect(result.isValid, isFalse);
      expect(reports(result.report, 'profile.does_not_exist'), isTrue);
      expect(reports(result.report, 'profile.production'), isTrue);
    });

    test('a release build refuses the accelerated QA profile', () {
      ReleaseSafety.simulateRelease(true);
      addTearDown(() => ReleaseSafety.simulateRelease(null));

      expect(
        () => const ContentLoader().load(
          productionSource,
          profileId: BalanceProfile.acceleratedQaId,
        ),
        throwsA(
          isA<StateError>().having(
            (StateError e) => e.message,
            'message',
            allOf(contains('release build'), contains('releaseSafe')),
          ),
        ),
      );
    });

    test('a release build still loads production', () {
      ReleaseSafety.simulateRelease(true);
      addTearDown(() => ReleaseSafety.simulateRelease(null));

      expect(loadProduction(productionSource).isValid, isTrue);
    });
  });
}
