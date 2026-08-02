import 'package:meta/meta.dart';

import 'content_id.dart';
import 'content_registry.dart';
import 'definitions.dart';
import 'validation.dart';

/// Why a target could not be reached.
enum BlockReason {
  /// A node needs a tool that can only be crafted from what that node yields.
  toolBootstrapDeadlock,

  /// A recipe needs an ingredient nothing produces.
  missingIngredient,

  /// Recipes depend on each other with no way in.
  circularDependency,

  /// A resource sits behind equipment made from that same resource.
  resourceBehindItsOwnOutput,

  /// A location requires an item that can only be obtained inside it.
  unobtainableEntryRequirement,

  /// Reachable in principle, but nothing produces it at all.
  nothingProducesIt,
}

/// A target the player cannot get to, and why.
@immutable
final class ReachabilityBlock {
  const ReachabilityBlock({
    required this.target,
    required this.reason,
    required this.explanation,
    required this.suggestion,
  });

  final ContentId target;
  final BlockReason reason;
  final String explanation;
  final String suggestion;
}

/// The result of walking the progression graph.
@immutable
final class ReachabilityResult {
  const ReachabilityResult({
    required this.reachableItems,
    required this.reachableLocations,
    required this.usableRecipes,
    required this.blocks,
  });

  final Set<ContentId> reachableItems;
  final Set<ContentId> reachableLocations;
  final Set<ContentId> usableRecipes;
  final List<ReachabilityBlock> blocks;

  bool get isReachable => blocks.isEmpty;
}

/// Proves the player can get from the starting loadout to a target tier.
///
/// ## What this is
///
/// A fixpoint walk over the progression graph. Starting from the granted
/// loadout at the start location, it repeatedly asks: which locations can I now
/// enter, which nodes can I now gather, which recipes can I now craft — until
/// nothing new becomes available. Whatever is still missing was never
/// obtainable.
///
/// ## What this is not
///
/// **Balance.** It ignores step costs, XP, and skill levels entirely. A chain
/// requiring nine million steps passes. The question here is *possible at all*,
/// which is the question a content author gets wrong in ways that are invisible
/// until someone plays for an hour and gets stuck.
///
/// Skill levels are deliberately excluded: a level requirement is always
/// satisfiable given enough of an activity the player can already do, so folding
/// it in would turn a structural check into a pacing check and hide the
/// structural answer.
final class ReachabilityValidator {
  const ReachabilityValidator(this.registry);

  final ContentRegistry registry;

  /// Walks the graph and reports what cannot be reached from the loadout.
  ReachabilityResult analyse({required List<ContentId> targets}) {
    final Set<ContentId> items = <ContentId>{...registry.startingLoadout};
    final Set<ContentId> locations = <ContentId>{};
    final Set<ContentId> recipesUsed = <ContentId>{};

    // Seed with the start location. Entry requirements do not apply to it —
    // a start the player cannot enter would be a different kind of broken, and
    // the validator reports that separately.
    final LocationDefinition start = registry.startLocation;
    locations.add(start.id);

    bool changed = true;
    while (changed) {
      changed = false;

      // Travel: any connection out of a reachable location whose entry
      // requirements are already held.
      for (final ContentId locationId in locations.toList()) {
        final LocationDefinition? location = registry.locations[locationId];
        if (location == null) continue;
        for (final LocationConnection connection in location.connections) {
          if (locations.contains(connection.to)) continue;
          final LocationDefinition? destination =
              registry.locations[connection.to];
          if (destination == null) continue;
          if (destination.entryRequirements.every(items.contains)) {
            locations.add(destination.id);
            changed = true;
          }
        }
      }

      // Gathering: nodes at reachable locations whose tool requirement is met.
      for (final ContentId locationId in locations) {
        final LocationDefinition? location = registry.locations[locationId];
        if (location == null) continue;
        for (final ContentId nodeId in location.resourceNodes) {
          final ResourceNodeDefinition? node = registry.resourceNodes[nodeId];
          if (node == null) continue;
          if (!_hasTool(items, node)) continue;
          if (items.add(node.yieldsItem)) changed = true;
        }
      }

      // Crafting: recipes whose every ingredient is held.
      for (final RecipeDefinition recipe in registry.recipes.values) {
        if (!recipe.ingredients.every(
          (RecipeIngredient i) => items.contains(i.item),
        )) {
          continue;
        }
        recipesUsed.add(recipe.id);
        if (items.add(recipe.outputItem)) changed = true;
      }
    }

    final List<ReachabilityBlock> blocks = <ReachabilityBlock>[];
    for (final ContentId target in targets) {
      if (items.contains(target)) continue;
      blocks.add(_diagnose(target, items, locations));
    }

    return ReachabilityResult(
      reachableItems: Set<ContentId>.unmodifiable(items),
      reachableLocations: Set<ContentId>.unmodifiable(locations),
      usableRecipes: Set<ContentId>.unmodifiable(recipesUsed),
      blocks: List<ReachabilityBlock>.unmodifiable(blocks),
    );
  }

  bool _hasTool(Set<ContentId> items, ResourceNodeDefinition node) {
    if (node.requiredToolKind == ToolKind.none) return true;
    return items.any((ContentId id) {
      final ItemDefinition? item = registry.items[id];
      return item != null &&
          item.toolKind == node.requiredToolKind &&
          item.tier >= node.minimumToolTier;
    });
  }

  /// Works out *why* a target is unreachable, so the error names the actual
  /// problem rather than "not reachable".
  ///
  /// A message saying only that Bronze cannot be reached leaves an author
  /// reading the whole content set. A message saying the axe needed for oak is
  /// itself made from oak points at the edit.
  ReachabilityBlock _diagnose(
    ContentId target,
    Set<ContentId> reachable,
    Set<ContentId> reachableLocations,
  ) {
    // Produced by a node?
    final List<ResourceNodeDefinition> producingNodes = registry
        .resourceNodes
        .values
        .where((ResourceNodeDefinition n) => n.yieldsItem == target)
        .toList();

    // Produced by a recipe?
    final List<RecipeDefinition> producingRecipes = registry.recipes.values
        .where((RecipeDefinition r) => r.outputItem == target)
        .toList();

    if (producingNodes.isEmpty && producingRecipes.isEmpty) {
      return ReachabilityBlock(
        target: target,
        reason: BlockReason.nothingProducesIt,
        explanation:
            '"$target" cannot be obtained: no resource node yields it '
            'and no recipe produces it',
        suggestion:
            'add a resource node or recipe that produces it, or grant '
            'it in the starting loadout',
      );
    }

    // A node exists but its tool is unobtainable.
    for (final ResourceNodeDefinition node in producingNodes) {
      if (_hasTool(reachable, node)) continue;
      final String toolKind = node.requiredToolKind.name;
      final List<ItemDefinition> tools = registry.items.values
          .where(
            (ItemDefinition i) =>
                i.toolKind == node.requiredToolKind &&
                i.tier >= node.minimumToolTier,
          )
          .toList();

      // Is every qualifying tool made from something this node produces?
      final bool selfReferential =
          tools.isNotEmpty &&
          tools.every(
            (ItemDefinition tool) =>
                _dependsOn(tool.id, node.yieldsItem, <ContentId>{}),
          );

      if (selfReferential) {
        return ReachabilityBlock(
          target: target,
          reason: BlockReason.resourceBehindItsOwnOutput,
          explanation:
              '"$target" needs a $toolKind of tier ${node.minimumToolTier}+, but '
              'every such tool is crafted from "${node.yieldsItem}", which is '
              'what this node produces',
          suggestion:
              'grant a starting $toolKind in the loadout, or lower '
              '"${node.id}" minimumToolTier so an existing tool qualifies',
        );
      }

      return ReachabilityBlock(
        target: target,
        reason: BlockReason.toolBootstrapDeadlock,
        explanation:
            '"$target" is gathered at "${node.id}", which needs a $toolKind of '
            'tier ${node.minimumToolTier}+ that the player can never obtain',
        suggestion: tools.isEmpty
            ? 'no item defines toolKind "$toolKind" at that tier — define one, '
                  'or change the node requirement'
            : 'grant a qualifying $toolKind in the starting loadout, or lower '
                  'the node\'s minimumToolTier',
      );
    }

    // A node exists and the tool is fine, so the location must be closed.
    for (final ResourceNodeDefinition node in producingNodes) {
      final LocationDefinition? host = registry.locations.values
          .cast<LocationDefinition?>()
          .firstWhere(
            (LocationDefinition? l) =>
                l != null && l.resourceNodes.contains(node.id),
            orElse: () => null,
          );
      if (host == null || reachableLocations.contains(host.id)) continue;

      final List<ContentId> blockingRequirements = host.entryRequirements
          .where((ContentId r) => !reachable.contains(r))
          .toList();

      return ReachabilityBlock(
        target: target,
        reason: BlockReason.unobtainableEntryRequirement,
        explanation:
            '"$target" is only found in "${host.id}", which requires '
            '${blockingRequirements.join(', ')} to enter — and that cannot be '
            'obtained outside it',
        suggestion:
            'remove the entry requirement, make the required item '
            'obtainable earlier, or move the resource to a reachable location',
      );
    }

    // Recipes remain. Find which ingredient is the problem.
    for (final RecipeDefinition recipe in producingRecipes) {
      final List<ContentId> missing = recipe.ingredients
          .map((RecipeIngredient i) => i.item)
          .where((ContentId i) => !reachable.contains(i))
          .toList();
      if (missing.isEmpty) continue;

      final List<ContentId> circular = missing
          .where((ContentId m) => _dependsOn(m, target, <ContentId>{}))
          .toList();
      if (circular.isNotEmpty) {
        return ReachabilityBlock(
          target: target,
          reason: BlockReason.circularDependency,
          explanation:
              '"$target" needs ${circular.join(', ')}, which in turn depends on '
              '"$target" — a cycle with no way in',
          suggestion:
              'break the cycle: make one of them gatherable, or grant '
              'a starting item that opens the chain',
        );
      }

      return ReachabilityBlock(
        target: target,
        reason: BlockReason.missingIngredient,
        explanation:
            '"$target" is crafted by "${recipe.id}", which needs '
            '${missing.join(', ')} — none of which the player can obtain',
        suggestion: 'make ${missing.first} obtainable, or change the recipe',
      );
    }

    return ReachabilityBlock(
      target: target,
      reason: BlockReason.nothingProducesIt,
      explanation: '"$target" is unreachable from the starting loadout',
      suggestion: 'check the chain of nodes and recipes that lead to it',
    );
  }

  /// Whether [item] transitively requires [dependency] to craft.
  ///
  /// Each branch gets its own [seen] set. Sharing one across siblings looks like
  /// a harmless memoization, but in a diamond-shaped graph — two ingredients
  /// that both lead to the same base material — the first branch marks the
  /// shared node visited and the second returns false, under-reporting a real
  /// cycle. The failure mode is a *passing* test, which is the worst kind.
  bool _dependsOn(ContentId item, ContentId dependency, Set<ContentId> seen) {
    if (item == dependency) return true;
    if (seen.contains(item)) return false;

    final Set<ContentId> path = <ContentId>{...seen, item};
    for (final RecipeDefinition recipe in registry.recipes.values) {
      if (recipe.outputItem != item) continue;
      for (final RecipeIngredient ingredient in recipe.ingredients) {
        if (_dependsOn(ingredient.item, dependency, path)) return true;
      }
    }
    return false;
  }

  /// Runs the analysis and reports blocks as validation errors.
  ValidationReport validate({
    required List<ContentId> targets,
    String sourceFile = 'progression graph',
  }) {
    final ReachabilityResult result = analyse(targets: targets);
    final ErrorCollector collector = ErrorCollector();
    for (final ReachabilityBlock block in result.blocks) {
      collector.add(
        sourceFile: sourceFile,
        entryId: block.target.value,
        field: block.reason.name,
        explanation: block.explanation,
        suggestion: block.suggestion,
      );
    }
    return collector.toReport();
  }
}
