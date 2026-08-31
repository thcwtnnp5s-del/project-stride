// Fable Depth Offensive 01 rails (`DECISIONS/0028`): the `requiresProject`
// project gate, the `requiresKnownEnemy` veteran gate, and the L-1 entry-key
// safety validator.
//
// Loader tests mutate one production file in memory and load the rest
// unchanged, so each rule is exercised against otherwise-real content —
// the `productionWithOverride` philosophy without a disk fixture, because
// every mutation here *adds* an entry rather than restating a file.
// Engine tests build a state directly and hand it to `GameEngine`, exactly
// as a decoded save would be (the `combat_test.dart` pattern).

import 'dart:convert';

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'content_test_support.dart';

final ContentId haven = ContentId.unchecked('location.havens_rest');
final ContentId woods = ContentId.unchecked('location.whispering_woods');
final ContentId wolf = ContentId.unchecked('enemy.forest_wolf');
final ContentId mill = ContentId.unchecked('project.havens_rest_mill');

/// The production bundle with [entries] appended to the entry list of
/// [filename] (and, via [edit], arbitrary decoded-map surgery).
ContentSource productionPlus(
  String filename, {
  List<Map<String, Object?>> entries = const <Map<String, Object?>>[],
  void Function(Map<String, Object?> decoded)? edit,
}) {
  final Map<String, String> files = Map<String, String>.of(
    productionSource.files,
  );
  final Map<String, Object?> decoded =
      jsonDecode(files[filename]!) as Map<String, Object?>;
  (decoded['entries']! as List<Object?>).addAll(entries);
  edit?.call(decoded);
  files[filename] = jsonEncode(decoded);
  return ContentSource(files);
}

/// The production mill project's id string, asserted real before use.
const String millId = 'project.havens_rest_mill';

Map<String, Object?> gatedProject(String id, {required String requires}) =>
    <String, Object?>{
      'id': id,
      'displayName': 'Test Annex',
      'location': 'location.havens_rest',
      'brief': 'A test annex.',
      'requiresProject': requires,
      'stages': <Object?>[
        <String, Object?>{
          'name': 'Stage one',
          'requires': <Object?>[
            <String, Object?>{'item': 'item.oak_log', 'quantity': 1},
          ],
        },
      ],
    };

void main() {
  group('requiresProject — loader', () {
    test('an unknown referent is refused', () {
      final ContentLoadResult result = loadProduction(
        productionPlus(
          'projects.json',
          entries: <Map<String, Object?>>[
            gatedProject('project.test_annex', requires: 'project.no_such'),
          ],
        ),
      );
      expect(result.registry, isNull);
      expect(reports(result.report, 'project.no_such'), isTrue);
    });

    test('a self-reference is refused', () {
      final ContentLoadResult result = loadProduction(
        productionPlus(
          'projects.json',
          entries: <Map<String, Object?>>[
            gatedProject('project.test_annex', requires: 'project.test_annex'),
          ],
        ),
      );
      expect(result.registry, isNull);
      expect(reports(result.report, 'requires itself'), isTrue);
    });

    test('a two-project cycle is refused', () {
      final ContentLoadResult result = loadProduction(
        productionPlus(
          'projects.json',
          entries: <Map<String, Object?>>[
            gatedProject('project.test_a', requires: 'project.test_b'),
            gatedProject('project.test_b', requires: 'project.test_a'),
          ],
        ),
      );
      expect(result.registry, isNull);
      // Each project in a 2-cycle reports the loop from its own perspective
      // ("requires itself through …"); the shared suggestion is the stable
      // signature.
      expect(reports(result.report, 'bottom out'), isTrue);
    });
  });

  group('requiresProject — engine', () {
    ContentRegistry gatedRegistry() => loadProduction(
      productionPlus(
        'projects.json',
        entries: <Map<String, Object?>>[
          gatedProject('project.test_annex', requires: millId),
        ],
      ),
    ).registry!;

    GameEngine engineWith(
      ContentRegistry registry, {
      Iterable<ContentId> completed = const <ContentId>[],
    }) {
      final GameEngine fresh = GameEngine.newGame(registry: registry);
      final GameState state = fresh.state.copyWith(
        inventory: fresh.state.inventory.adding(
          ContentId.unchecked('item.oak_log'),
          5,
        ),
        progress: fresh.state.progress.copyWith(
          completedProjects: <ContentId>{
            ...fresh.state.progress.completedProjects,
            ...completed,
          },
        ),
      );
      return GameEngine(registry: registry, state: state);
    }

    test('a gated project rejects contributions with project_not_available '
        'and mutates nothing', () {
      final ContentRegistry registry = gatedRegistry();
      final GameEngine engine = engineWith(registry);
      final GameState before = engine.state;
      final EngineResult result = engine.execute(
        ContributeToProject(
          project: ContentId.unchecked('project.test_annex'),
          contributions: <ContentId, int>{
            ContentId.unchecked('item.oak_log'): 1,
          },
        ),
      );
      expect(result.isAccepted, isFalse);
      expect(result.rejection!.code, RejectionCode.projectNotAvailable);
      expect(result.rejection!.explanation, contains('opens once'));
      expect(identical(engine.state, before), isTrue);
    });

    test('completing the prerequisite opens the gate', () {
      final ContentRegistry registry = gatedRegistry();
      final GameEngine engine = engineWith(
        registry,
        completed: <ContentId>[mill],
      );
      final EngineResult result = engine.execute(
        ContributeToProject(
          project: ContentId.unchecked('project.test_annex'),
          contributions: <ContentId, int>{
            ContentId.unchecked('item.oak_log'): 1,
          },
        ),
      );
      expect(result.isAccepted, isTrue, reason: '${result.rejection}');
    });
  });

  group('requiresKnownEnemy — loader', () {
    Map<String, Object?> veteran(String id, {required String requires}) =>
        <String, Object?>{
          'id': id,
          'displayName': 'Test Veteran',
          'location': 'location.whispering_woods',
          'health': 40,
          'attack': 10,
          'defence': 3,
          'isBoss': false,
          'drops': <Object?>[
            <String, Object?>{
              'item': 'item.wolf_pelt',
              'quantity': 1,
              'chancePercent': 100,
            },
          ],
          'xp': 100,
          'requiresKnownEnemy': requires,
        };

    test('an unknown referent is refused', () {
      final ContentLoadResult result = loadProduction(
        productionPlus(
          'enemies.json',
          entries: <Map<String, Object?>>[
            veteran('enemy.test_veteran', requires: 'enemy.no_such'),
          ],
        ),
      );
      expect(result.registry, isNull);
      expect(reports(result.report, 'enemy.no_such'), isTrue);
    });

    test('a self-reference is refused', () {
      final ContentLoadResult result = loadProduction(
        productionPlus(
          'enemies.json',
          entries: <Map<String, Object?>>[
            veteran('enemy.test_veteran', requires: 'enemy.test_veteran'),
          ],
        ),
      );
      expect(result.registry, isNull);
      expect(reports(result.report, 'never happen'), isTrue);
    });
  });

  group('requiresKnownEnemy — engine', () {
    ContentRegistry veteranRegistry() => loadProduction(
      productionPlus(
        'enemies.json',
        entries: <Map<String, Object?>>[
          <String, Object?>{
            'id': 'enemy.test_veteran',
            'displayName': 'Test Veteran',
            'location': 'location.whispering_woods',
            'health': 40,
            'attack': 10,
            'defence': 3,
            'isBoss': false,
            'drops': <Object?>[
              <String, Object?>{
                'item': 'item.wolf_pelt',
                'quantity': 1,
                'chancePercent': 100,
              },
            ],
            'xp': 100,
            'requiresKnownEnemy': 'enemy.forest_wolf',
          },
        ],
      ),
    ).registry!;

    GameEngine inWoods(ContentRegistry registry, {int wolfVictories = 0}) {
      final GameEngine fresh = GameEngine.newGame(registry: registry);
      final GameState state = fresh.state.copyWith(
        world: WorldState(
          currentLocation: woods,
          unlockedLocations: <ContentId>{haven, woods},
        ),
        progress: fresh.state.progress.copyWith(
          enemyVictories: <ContentId, int>{
            if (wolfVictories > 0) wolf: wolfVictories,
          },
        ),
      );
      return GameEngine(registry: registry, state: state);
    }

    test('below Known the veteran refuses with enemy_not_known '
        'and mutates nothing', () {
      final ContentRegistry registry = veteranRegistry();
      final int knownAt = registry.enemies[wolf]!.knownAt;
      final GameEngine engine = inWoods(
        registry,
        wolfVictories: knownAt - 1,
      );
      final GameState before = engine.state;
      final EngineResult result = engine.execute(
        StartEncounter(enemy: ContentId.unchecked('enemy.test_veteran')),
      );
      expect(result.isAccepted, isFalse);
      expect(result.rejection!.code, RejectionCode.enemyNotKnown);
      expect(result.rejection!.explanation, contains('Known'));
      expect(identical(engine.state, before), isTrue);
    });

    test('at Known the veteran offers a normal encounter', () {
      final ContentRegistry registry = veteranRegistry();
      final int knownAt = registry.enemies[wolf]!.knownAt;
      final GameEngine engine = inWoods(registry, wolfVictories: knownAt);
      final EngineResult result = engine.execute(
        StartEncounter(enemy: ContentId.unchecked('enemy.test_veteran')),
      );
      expect(result.isAccepted, isTrue, reason: '${result.rejection}');
      expect(engine.state.encounter, isNotNull);
      expect(
        engine.state.encounter!.enemy.value,
        'enemy.test_veteran',
      );
    });
  });

  group('L-1 entry-key safety', () {
    // `item.bronze_sword` is the Forgotten Hollow's entry key in production
    // content — the exact item the rule exists for.
    test('a recipe consuming an entry key is refused', () {
      final ContentLoadResult result = loadProduction(
        productionPlus(
          'recipes.json',
          entries: <Map<String, Object?>>[
            <String, Object?>{
              'id': 'recipe.test_reforge',
              'displayName': 'Test Reforge',
              'skill': 'skill.smithing',
              'requiredLevel': 1,
              'ingredients': <Object?>[
                <String, Object?>{'item': 'item.bronze_sword', 'quantity': 1},
              ],
              'outputItem': 'item.bronze_ingot',
              'outputQuantity': 1,
              'xp': 10,
            },
          ],
        ),
      );
      expect(result.registry, isNull);
      expect(reports(result.report, 'opens a location'), isTrue);
    });

    test('a contract delivery consuming an entry key is refused', () {
      final ContentLoadResult result = loadProduction(
        productionPlus(
          'contracts.json',
          entries: <Map<String, Object?>>[
            <String, Object?>{
              'id': 'contract.test_tribute',
              'displayName': 'Test Tribute',
              'location': 'location.havens_rest',
              'class': 'regional',
              'brief': 'A test.',
              'requires': <Object?>[
                <String, Object?>{'item': 'item.bronze_sword', 'quantity': 1},
              ],
              'rewardCharacterXp': 10,
            },
          ],
        ),
      );
      expect(result.registry, isNull);
      expect(reports(result.report, 'opens a location'), isTrue);
    });

    test('a project stage consuming an entry key is refused', () {
      final ContentLoadResult result = loadProduction(
        productionPlus(
          'projects.json',
          entries: <Map<String, Object?>>[
            <String, Object?>{
              'id': 'project.test_shrine',
              'displayName': 'Test Shrine',
              'location': 'location.havens_rest',
              'brief': 'A test.',
              'stages': <Object?>[
                <String, Object?>{
                  'name': 'Stage one',
                  'requires': <Object?>[
                    <String, Object?>{
                      'item': 'item.bronze_sword',
                      'quantity': 1,
                    },
                  ],
                },
              ],
            },
          ],
        ),
      );
      expect(result.registry, isNull);
      expect(reports(result.report, 'opens a location'), isTrue);
    });

    test('requiresOwned on an entry key stays legal — show, never spend', () {
      final ContentLoadResult result = loadProduction(
        productionPlus(
          'contracts.json',
          entries: <Map<String, Object?>>[
            <String, Object?>{
              'id': 'contract.test_showing',
              'displayName': 'Test Showing',
              'location': 'location.havens_rest',
              'class': 'regional',
              'brief': 'A test.',
              'requiresOwned': <Object?>['item.bronze_sword'],
              'rewardCharacterXp': 10,
            },
          ],
        ),
      );
      expect(result.registry, isNotNull, reason: '${result.report.errors}');
    });
  });
}
