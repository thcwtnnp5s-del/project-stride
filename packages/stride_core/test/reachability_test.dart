// The progression-graph test.
//
// Proves the player can get from the granted loadout to Bronze, and that the
// validator diagnoses each way that chain can break. This is reachability, not
// balance: step costs and skill levels are deliberately ignored.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'content_test_support.dart';

/// Builds a registry from hand-written content, for graphs too specific to
/// express as an edit to production files.
ContentRegistry buildRegistry({
  required String items,
  required String nodes,
  required String recipes,
  required String locations,
  List<ContentId>? loadout,
  List<ContentId>? targets,
}) {
  const String skills = '''
{"schemaVersion":1,"kind":"skills","entries":[
  {"id":"skill.woodcutting","displayName":"Woodcutting","category":"gathering","maxLevel":2,"xpThresholds":[0,100]},
  {"id":"skill.smithing","displayName":"Smithing","category":"production","maxLevel":2,"xpThresholds":[0,100]}
]}''';
  const String profiles = '''
{"schemaVersion":1,"kind":"profiles","entries":[
  {"id":"profile.production","displayName":"Production","releaseSafe":true,
   "stepCostPercent":100,"xpPercent":100,"yieldPercent":100,"enemyHealthPercent":100}
]}''';

  final ContentLoadResult result = const ContentLoader().load(
    ContentSource(<String, String>{
      'skills.json': skills,
      'profiles.json': profiles,
      'items.json': items,
      'resource_nodes.json': nodes,
      'recipes.json': recipes,
      'locations.json': locations,
    }),
    profileId: BalanceProfile.productionId,
    startingLoadout: loadout,
    reachabilityTargets: targets ?? const <ContentId>[],
  );
  return result.requireRegistry;
}

/// The single block a deliberately broken graph produces.
ReachabilityBlock singleBlock(ContentRegistry registry, String target) {
  final ReachabilityResult result = ReachabilityValidator(
    registry,
  ).analyse(targets: <ContentId>[ContentId.unchecked(target)]);
  expect(result.blocks, hasLength(1), reason: 'expected exactly one block');
  return result.blocks.single;
}

void main() {
  group('production reachability', () {
    test('the player can reach Bronze from the starting loadout', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;

      final ReachabilityResult result = ReachabilityValidator(
        registry,
      ).analyse(targets: ContentLoader.defaultReachabilityTargets);

      expect(
        result.isReachable,
        isTrue,
        reason: result.blocks
            .map((ReachabilityBlock b) => '${b.reason.name}: ${b.explanation}')
            .join('\n'),
      );
    });

    test('the Bronze chain uses gathering, processing, and crafting', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;
      final ReachabilityResult result = ReachabilityValidator(
        registry,
      ).analyse(targets: ContentLoader.defaultReachabilityTargets);

      // Bronze is the proof that the loop works, so the path to it must
      // actually traverse the loop rather than shortcut it.
      for (final String id in <String>[
        'item.oak_log',
        'item.copper_ore',
        'item.tin_ore',
        'item.oak_handle',
        'item.bronze_ingot',
      ]) {
        expect(result.reachableItems, contains(ContentId.unchecked(id)));
      }
      for (final String id in <String>[
        'recipe.oak_handle',
        'recipe.bronze_ingot',
        'recipe.bronze_sword',
      ]) {
        expect(result.usableRecipes, contains(ContentId.unchecked(id)));
      }
    });

    test('every location is reachable, including behind an entry requirement', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;
      final ReachabilityResult result = ReachabilityValidator(
        registry,
      ).analyse(targets: ContentLoader.defaultReachabilityTargets);

      // Forgotten Hollow requires a Bronze Sword. The player can craft one, so
      // the gate is a milestone rather than a wall.
      //
      // Frostmere has no entry requirement at all — its gates are the
      // 1,500-step pass and the skill levels its two nodes ask for, neither of
      // which reachability models. It appears here because a player can always
      // *reach* it; whether they can harvest it is a different question, asked
      // by the engine (`GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md` §4).
      expect(result.reachableLocations, hasLength(5));
      expect(
        result.reachableLocations,
        containsAll(<ContentId>[
          ContentId.unchecked('location.forgotten_hollow'),
          ContentId.unchecked('location.frostmere'),
        ]),
      );
    });

    test('reachability ignores step cost and skill level', () {
      final ContentRegistry registry = loadProduction(
        productionSource,
      ).requireRegistry;

      // Hollow Root sits behind a level 10 requirement and a locked location.
      // Structurally obtainable; that is the only question asked here.
      final ReachabilityResult result = ReachabilityValidator(
        registry,
      ).analyse(targets: <ContentId>[ContentId.unchecked('item.hollow_root')]);

      expect(result.isReachable, isTrue);
    });
  });

  group('deadlock diagnosis', () {
    const String baseLocations = '''
{"schemaVersion":1,"kind":"locations","entries":[
  {"id":"location.start","displayName":"Start","terrain":"grassland","isSafe":true,"isStart":true,
   "connections":[],"entryRequirements":[],"resourceNodes":["resource_node.tree"]}
]}''';

    test('a tool bootstrap deadlock is named', () {
      // The axe needed for oak is made from oak.
      final ContentRegistry registry = buildRegistry(
        items: '''
{"schemaVersion":1,"kind":"items","entries":[
  {"id":"item.oak_log","displayName":"Oak Log","category":"material","rarity":"common","tier":0},
  {"id":"item.good_axe","displayName":"Good Axe","category":"equipment","rarity":"common","slot":"tool","toolKind":"axe","tier":1,"stackable":false}
]}''',
        nodes: '''
{"schemaVersion":1,"kind":"resource_nodes","entries":[
  {"id":"resource_node.tree","displayName":"Tree","skill":"skill.woodcutting",
   "requiredToolKind":"axe","minimumToolTier":1,"yieldsItem":"item.oak_log",
   "stepCost":100,"xp":10}
]}''',
        recipes: '''
{"schemaVersion":1,"kind":"recipes","entries":[
  {"id":"recipe.good_axe","displayName":"Good Axe","skill":"skill.smithing",
   "ingredients":[{"item":"item.oak_log","quantity":2}],
   "outputItem":"item.good_axe","xp":10}
]}''',
        locations: baseLocations,
        loadout: const <ContentId>[],
      );

      final ReachabilityBlock block = singleBlock(registry, 'item.oak_log');

      expect(block.reason, BlockReason.resourceBehindItsOwnOutput);
      expect(block.explanation, contains('item.oak_log'));
      expect(block.suggestion, contains('starting'));
    });

    test('a missing ingredient is named', () {
      final ContentRegistry registry = buildRegistry(
        items: '''
{"schemaVersion":1,"kind":"items","entries":[
  {"id":"item.oak_log","displayName":"Oak Log","category":"material","rarity":"common","tier":0},
  {"id":"item.rare_gem","displayName":"Rare Gem","category":"material","rarity":"common","tier":5},
  {"id":"item.trophy","displayName":"Trophy","category":"equipment","rarity":"common","slot":"weapon","tier":1,"stackable":false}
]}''',
        nodes: '''
{"schemaVersion":1,"kind":"resource_nodes","entries":[
  {"id":"resource_node.tree","displayName":"Tree","skill":"skill.woodcutting",
   "requiredToolKind":"none","yieldsItem":"item.oak_log","stepCost":100,"xp":10}
]}''',
        recipes: '''
{"schemaVersion":1,"kind":"recipes","entries":[
  {"id":"recipe.trophy","displayName":"Trophy","skill":"skill.smithing",
   "ingredients":[{"item":"item.oak_log","quantity":1},{"item":"item.rare_gem","quantity":1}],
   "outputItem":"item.trophy","xp":10}
]}''',
        locations: baseLocations,
        loadout: const <ContentId>[],
      );

      final ReachabilityBlock block = singleBlock(registry, 'item.trophy');

      expect(block.reason, BlockReason.missingIngredient);
      expect(block.explanation, contains('item.rare_gem'));
    });

    test('a circular dependency with no entry point is named', () {
      final ContentRegistry registry = buildRegistry(
        items: '''
{"schemaVersion":1,"kind":"items","entries":[
  {"id":"item.oak_log","displayName":"Oak Log","category":"material","rarity":"common","tier":0},
  {"id":"item.plank","displayName":"Plank","category":"equipment","rarity":"common","slot":"tool","tier":1,"stackable":false},
  {"id":"item.alpha","displayName":"Alpha","category":"material","rarity":"common","tier":1},
  {"id":"item.beta","displayName":"Beta","category":"material","rarity":"common","tier":1}
]}''',
        nodes: '''
{"schemaVersion":1,"kind":"resource_nodes","entries":[
  {"id":"resource_node.tree","displayName":"Tree","skill":"skill.woodcutting",
   "requiredToolKind":"none","yieldsItem":"item.oak_log","stepCost":100,"xp":10}
]}''',
        recipes: '''
{"schemaVersion":1,"kind":"recipes","entries":[
  {"id":"recipe.plank","displayName":"Plank","skill":"skill.smithing",
   "ingredients":[{"item":"item.oak_log","quantity":1}],"outputItem":"item.plank","xp":1},
  {"id":"recipe.alpha","displayName":"Alpha","skill":"skill.smithing",
   "ingredients":[{"item":"item.beta","quantity":1}],"outputItem":"item.alpha","xp":10},
  {"id":"recipe.beta","displayName":"Beta","skill":"skill.smithing",
   "ingredients":[{"item":"item.alpha","quantity":1}],"outputItem":"item.beta","xp":10}
]}''',
        locations: baseLocations,
        loadout: const <ContentId>[],
      );

      final ReachabilityBlock block = singleBlock(registry, 'item.alpha');

      expect(block.reason, BlockReason.circularDependency);
      expect(block.explanation, contains('cycle'));
    });

    test('an unobtainable location entry requirement is named', () {
      // The vault key is only found inside the vault.
      final ContentRegistry registry = buildRegistry(
        items: '''
{"schemaVersion":1,"kind":"items","entries":[
  {"id":"item.oak_log","displayName":"Oak Log","category":"material","rarity":"common","tier":0},
  {"id":"item.plank","displayName":"Plank","category":"equipment","rarity":"common","slot":"tool","tier":1,"stackable":false},
  {"id":"item.vault_key","displayName":"Vault Key","category":"quest","rarity":"common","tier":1},
  {"id":"item.vault_gem","displayName":"Vault Gem","category":"quest","rarity":"common","tier":1}
]}''',
        nodes: '''
{"schemaVersion":1,"kind":"resource_nodes","entries":[
  {"id":"resource_node.tree","displayName":"Tree","skill":"skill.woodcutting",
   "requiredToolKind":"none","yieldsItem":"item.oak_log","stepCost":100,"xp":10},
  {"id":"resource_node.vault_seam","displayName":"Vault Seam","skill":"skill.woodcutting",
   "requiredToolKind":"none","yieldsItem":"item.vault_gem","stepCost":100,"xp":10},
  {"id":"resource_node.key_cache","displayName":"Key Cache","skill":"skill.woodcutting",
   "requiredToolKind":"none","yieldsItem":"item.vault_key","stepCost":100,"xp":10}
]}''',
        recipes: '''
{"schemaVersion":1,"kind":"recipes","entries":[
  {"id":"recipe.plank","displayName":"Plank","skill":"skill.smithing",
   "ingredients":[{"item":"item.oak_log","quantity":1}],"outputItem":"item.plank","xp":1}
]}''',
        locations: '''
{"schemaVersion":1,"kind":"locations","entries":[
  {"id":"location.start","displayName":"Start","terrain":"grassland","isSafe":true,"isStart":true,
   "connections":[{"to":"location.vault","stepCost":100}],
   "entryRequirements":[],"resourceNodes":["resource_node.tree"]},
  {"id":"location.vault","displayName":"Vault","terrain":"foothills","isSafe":false,"isStart":false,
   "connections":[{"to":"location.start","stepCost":100}],
   "entryRequirements":["item.vault_key"],
   "resourceNodes":["resource_node.vault_seam","resource_node.key_cache"]}
]}''',
        loadout: const <ContentId>[],
      );

      final ReachabilityBlock block = singleBlock(registry, 'item.vault_key');

      expect(block.reason, BlockReason.unobtainableEntryRequirement);
      expect(block.explanation, contains('location.vault'));
      expect(block.suggestion, contains('entry requirement'));
    });

    test('an item nothing produces is named', () {
      final ContentRegistry registry = buildRegistry(
        items: '''
{"schemaVersion":1,"kind":"items","entries":[
  {"id":"item.oak_log","displayName":"Oak Log","category":"material","rarity":"common","tier":0},
  {"id":"item.plank","displayName":"Plank","category":"equipment","rarity":"common","slot":"tool","tier":1,"stackable":false},
  {"id":"item.phantom","displayName":"Phantom","category":"quest","rarity":"common","tier":1}
]}''',
        nodes: '''
{"schemaVersion":1,"kind":"resource_nodes","entries":[
  {"id":"resource_node.tree","displayName":"Tree","skill":"skill.woodcutting",
   "requiredToolKind":"none","yieldsItem":"item.oak_log","stepCost":100,"xp":10}
]}''',
        recipes: '''
{"schemaVersion":1,"kind":"recipes","entries":[
  {"id":"recipe.plank","displayName":"Plank","skill":"skill.smithing",
   "ingredients":[{"item":"item.oak_log","quantity":1}],"outputItem":"item.plank","xp":1}
]}''',
        locations: baseLocations,
        loadout: const <ContentId>[],
      );

      final ReachabilityBlock block = singleBlock(registry, 'item.phantom');

      expect(block.reason, BlockReason.nothingProducesIt);
      expect(block.suggestion, contains('starting loadout'));
    });
  });
}
