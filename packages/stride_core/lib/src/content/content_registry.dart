import 'dart:collection';

import 'package:meta/meta.dart';

import 'balance_profile.dart';
import 'content_id.dart';
import 'definitions.dart';

/// Validated content, ready to use.
///
/// A registry cannot be constructed from content that failed validation — the
/// loader returns errors instead. Anything holding one may assume every
/// reference resolves, which means the simulation never has to defend against
/// a dangling ID at runtime.
///
/// All collections are sorted by ID. Iteration order is therefore identical on
/// every run, on every platform, regardless of the order files were read in —
/// the determinism requirement, made structural rather than promised.
@immutable
final class ContentRegistry {
  ContentRegistry({
    required Map<ContentId, ItemDefinition> items,
    required Map<ContentId, SkillDefinition> skills,
    required Map<ContentId, LocationDefinition> locations,
    required Map<ContentId, ResourceNodeDefinition> resourceNodes,
    required Map<ContentId, RecipeDefinition> recipes,
    required Map<ContentId, EnemyDefinition> enemies,
    Map<ContentId, ContractDefinition> contracts =
        const <ContentId, ContractDefinition>{},
    Map<ContentId, ProjectDefinition> projects =
        const <ContentId, ProjectDefinition>{},
    Map<ContentId, RumorDefinition> rumors =
        const <ContentId, RumorDefinition>{},
    required this.profile,
    required this.startingLoadout,
  }) : items = UnmodifiableMapView<ContentId, ItemDefinition>(
         SplayTreeMap<ContentId, ItemDefinition>.of(items),
       ),
       skills = UnmodifiableMapView<ContentId, SkillDefinition>(
         SplayTreeMap<ContentId, SkillDefinition>.of(skills),
       ),
       locations = UnmodifiableMapView<ContentId, LocationDefinition>(
         SplayTreeMap<ContentId, LocationDefinition>.of(locations),
       ),
       resourceNodes = UnmodifiableMapView<ContentId, ResourceNodeDefinition>(
         SplayTreeMap<ContentId, ResourceNodeDefinition>.of(resourceNodes),
       ),
       recipes = UnmodifiableMapView<ContentId, RecipeDefinition>(
         SplayTreeMap<ContentId, RecipeDefinition>.of(recipes),
       ),
       enemies = UnmodifiableMapView<ContentId, EnemyDefinition>(
         SplayTreeMap<ContentId, EnemyDefinition>.of(enemies),
       ),
       contracts = UnmodifiableMapView<ContentId, ContractDefinition>(
         SplayTreeMap<ContentId, ContractDefinition>.of(contracts),
       ),
       projects = UnmodifiableMapView<ContentId, ProjectDefinition>(
         SplayTreeMap<ContentId, ProjectDefinition>.of(projects),
       ),
       rumors = UnmodifiableMapView<ContentId, RumorDefinition>(
         SplayTreeMap<ContentId, RumorDefinition>.of(rumors),
       );

  final Map<ContentId, ItemDefinition> items;
  final Map<ContentId, SkillDefinition> skills;
  final Map<ContentId, LocationDefinition> locations;
  final Map<ContentId, ResourceNodeDefinition> resourceNodes;
  final Map<ContentId, RecipeDefinition> recipes;
  final Map<ContentId, EnemyDefinition> enemies;
  final Map<ContentId, ContractDefinition> contracts;
  final Map<ContentId, ProjectDefinition> projects;
  final Map<ContentId, RumorDefinition> rumors;

  /// A location's local-need rotation deck, in authored [ContractDefinition.
  /// deckOrder]. Registry maps are sorted by id, which loses authored order —
  /// this is where deck order survives, derived once here so the engine and
  /// every projection read the same sequence.
  List<ContentId> localNeedDeck(ContentId location) {
    final List<ContractDefinition> deck =
        contracts.values
            .where(
              (ContractDefinition c) =>
                  c.location == location &&
                  c.contractClass == ContractClass.localNeed,
            )
            .toList()
          ..sort((ContractDefinition a, ContractDefinition b) {
            final int byOrder = a.deckOrder.compareTo(b.deckOrder);
            return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
          });
    return List<ContentId>.unmodifiable(
      deck.map((ContractDefinition c) => c.id),
    );
  }

  /// The selected balance profile. Numbers reported by this registry are base
  /// values; the profile scales them at the point of use.
  final BalanceProfile profile;

  /// What the player is granted at Haven's Rest onboarding
  /// (`DECISIONS/0004_MILESTONE_01_SCOPE.md`).
  final List<ContentId> startingLoadout;

  /// Every ID the registry knows, sorted.
  List<ContentId> get allIds => <ContentId>[
    ...items.keys,
    ...skills.keys,
    ...locations.keys,
    ...resourceNodes.keys,
    ...recipes.keys,
    ...enemies.keys,
    ...contracts.keys,
    ...projects.keys,
    ...rumors.keys,
  ]..sort();

  LocationDefinition get startLocation =>
      locations.values.firstWhere((LocationDefinition l) => l.isStart);

  /// A stable fingerprint of the registry's contents.
  ///
  /// Two loads of the same files under the same profile must produce the same
  /// signature. Used by the determinism test, where comparing signatures is a
  /// far more legible failure than comparing two large object graphs.
  String get signature {
    final StringBuffer buffer = StringBuffer('profile=${profile.id}');
    for (final ContentId id in allIds) {
      buffer.write(';$id');
    }
    return buffer.toString();
  }

  int get entryCount =>
      items.length +
      skills.length +
      locations.length +
      resourceNodes.length +
      recipes.length +
      enemies.length +
      contracts.length +
      projects.length +
      rumors.length;
}
