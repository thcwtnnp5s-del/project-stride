/// Pure projections of the progression loop (`DECISIONS/0023`): enemy
/// knowledge tiers, settlement development states, journey routing, and the
/// pursuit analyzer.
///
/// Everything here is a pure function of state and content. Nothing mutates,
/// nothing rolls, nothing reads a clock — these answer the questions the goal
/// tracker and the boards ask, in one place, so no widget re-derives a rule
/// (`RULES.md` E-2).
library;

import 'dart:collection';

import 'package:meta/meta.dart';

import '../content/content_id.dart';
import '../content/content_registry.dart';
import '../content/definitions.dart';
import 'game_state.dart';

/// How well the player knows an enemy (`DECISIONS/0023` §5). Compact by
/// design: after [known] it stops.
enum KnowledgeTier {
  /// Never encountered.
  unseen,

  /// Encountered at least once (victories may still be zero — starting a
  /// fight is what makes an enemy Seen).
  seen,

  /// Victories at or past the enemy's `studiedAt`.
  studied,

  /// Victories at or past the enemy's `knownAt` — bestiary complete,
  /// signature-drop existence revealed.
  known,
}

/// The tier [state] gives [enemy].
///
/// Presence in `progress.enemyVictories` — written on the first
/// `EncounterStarted` — is what distinguishes [KnowledgeTier.seen] at zero
/// victories from [KnowledgeTier.unseen].
KnowledgeTier knowledgeTierFor(
  GameState state,
  EnemyDefinition enemy,
) {
  final int? victories = state.progress.enemyVictories[enemy.id];
  if (victories == null) return KnowledgeTier.unseen;
  if (victories >= enemy.knownAt) return KnowledgeTier.known;
  if (victories >= enemy.studiedAt) return KnowledgeTier.studied;
  return KnowledgeTier.seen;
}

/// A settlement's current named development state, or null when the location
/// has no settlement identity (`DECISIONS/0023` §3).
///
/// The base label is content (`LocationDefinition.developmentState`);
/// completed projects at the location override it, highest
/// `developmentRank` first, ties broken by id so the answer is stable.
/// Never a point total.
String? developmentStateFor(
  ContentRegistry registry,
  GameState state,
  ContentId location,
) {
  final LocationDefinition? place = registry.locations[location];
  if (place == null) return null;

  String? best;
  int bestRank = -1;
  ContentId? bestId;
  for (final ContentId projectId in state.progress.completedProjects) {
    final ProjectDefinition? project = registry.projects[projectId];
    if (project == null) continue;
    if (project.location != location) continue;
    final String? to = project.developmentTo;
    if (to == null) continue;
    if (project.developmentRank > bestRank ||
        (project.developmentRank == bestRank &&
            (bestId == null || projectId.compareTo(bestId) > 0))) {
      best = to;
      bestRank = project.developmentRank;
      bestId = projectId;
    }
  }
  return best ?? place.developmentState;
}

/// One leg of a journey's cheapest route.
@immutable
final class JourneyLeg {
  const JourneyLeg({required this.to, required this.stepCost});

  final ContentId to;

  /// Profile-scaled, as `TravelTo` would charge it.
  final int stepCost;
}

/// The Journey tracker's answer (`DECISIONS/0023` §1): the cheapest known
/// route and what it costs, against the current bank. **Informative, never
/// escrow** — nothing here reserves a step.
@immutable
final class JourneyStatus {
  const JourneyStatus({
    required this.destination,
    required this.legs,
    required this.totalCost,
    required this.banked,
  });

  final ContentId destination;

  /// In travel order, from where the player stands. Empty when the player is
  /// already there or no route exists.
  final List<JourneyLeg> legs;

  /// The route's whole cost, profile-scaled. Zero when already there; null
  /// when no route connects.
  final int? totalCost;

  /// The spendable balance at the time of asking.
  final int banked;

  /// Steps still missing, or zero when the journey is affordable. Null when
  /// no route exists.
  int? get shortfall {
    final int? cost = totalCost;
    if (cost == null) return null;
    final int gap = cost - banked;
    return gap < 0 ? 0 : gap;
  }

  /// READY: the whole route is affordable right now.
  bool get ready => totalCost != null && banked >= totalCost!;
}

/// The cheapest route from where the player stands to [destination], by
/// Dijkstra over the connection graph with profile-scaled leg costs.
///
/// Ties break by id order so the answer is stable. The route is knowledge,
/// not permission: `TravelTo` still validates every leg on execute.
JourneyStatus journeyStatusFor(
  ContentRegistry registry,
  GameState state,
  ContentId destination,
) {
  final ContentId start = state.world.currentLocation;
  final int banked = state.steps.banked;
  if (start == destination) {
    return JourneyStatus(
      destination: destination,
      legs: const <JourneyLeg>[],
      totalCost: 0,
      banked: banked,
    );
  }

  final Map<ContentId, int> best = <ContentId, int>{start: 0};
  final Map<ContentId, ContentId> cameFrom = <ContentId, ContentId>{};
  final SplayTreeSet<(int, ContentId)> frontier =
      SplayTreeSet<(int, ContentId)>(((int, ContentId) a, (int, ContentId) b) {
        final int byCost = a.$1.compareTo(b.$1);
        return byCost != 0 ? byCost : a.$2.compareTo(b.$2);
      })..add((0, start));

  while (frontier.isNotEmpty) {
    final (int cost, ContentId here) = frontier.first;
    frontier.remove(frontier.first);
    if (cost > (best[here] ?? cost)) continue;
    if (here == destination) break;
    final LocationDefinition? location = registry.locations[here];
    if (location == null) continue;
    for (final LocationConnection connection in location.connections) {
      final int legCost = registry.profile.applyStepCost(connection.stepCost);
      final int next = cost + legCost;
      final int? known = best[connection.to];
      if (known == null || next < known) {
        best[connection.to] = next;
        cameFrom[connection.to] = here;
        frontier.add((next, connection.to));
      }
    }
  }

  final int? totalCost = best[destination];
  if (totalCost == null) {
    return JourneyStatus(
      destination: destination,
      legs: const <JourneyLeg>[],
      totalCost: null,
      banked: banked,
    );
  }

  final List<JourneyLeg> legs = <JourneyLeg>[];
  ContentId cursor = destination;
  while (cursor != start) {
    final ContentId previous = cameFrom[cursor]!;
    legs.add(
      JourneyLeg(to: cursor, stepCost: best[cursor]! - best[previous]!),
    );
    cursor = previous;
  }
  return JourneyStatus(
    destination: destination,
    legs: List<JourneyLeg>.unmodifiable(legs.reversed),
    totalCost: totalCost,
    banked: banked,
  );
}

/// One direct requirement of a pursuit's recipe, with what is held.
@immutable
final class PursuitLine {
  const PursuitLine({
    required this.item,
    required this.required,
    required this.held,
  });

  final ContentId item;
  final int required;

  /// Clamped to [required] — the line reads "1 / 3", never "7 / 3".
  final int held;

  bool get satisfied => held >= required;
}

/// One base material the pursuit is short of, with a suggested source.
@immutable
final class PursuitNeed {
  const PursuitNeed({
    required this.item,
    required this.quantity,
    this.sourceNode,
    this.sourceLocation,
    this.sourceEnemy,
  });

  final ContentId item;

  /// How many are still missing after everything held is counted once.
  final int quantity;

  /// A node that yields it, and where that node is hosted — the "Suggested
  /// source: Stonefall Mine" line. Null when nothing gathers it.
  final ContentId? sourceNode;
  final ContentId? sourceLocation;

  /// An enemy that drops it, when no node yields it.
  final ContentId? sourceEnemy;
}

/// The Pursuit tracker's answer (`DECISIONS/0023` §1): what the tracked item
/// still needs, recursively, without double-counting anything held.
@immutable
final class PursuitPlan {
  const PursuitPlan({
    required this.item,
    required this.recipe,
    required this.lines,
    required this.needs,
    required this.owned,
  });

  final ContentId item;

  /// The recipe the plan is computed against — the available (non-locked)
  /// recipe producing the item — or null when nothing craftable makes it
  /// (a drop-only or gather-only pursuit).
  final ContentId? recipe;

  /// The recipe's direct requirements, for the "Bronze Ingot 1 / 3" rows.
  final List<PursuitLine> lines;

  /// The base materials still missing, deepest-first resolved — the "Need:
  /// Copper Ore ×4" rows. Empty when everything is in hand.
  final List<PursuitNeed> needs;

  /// Whether the player already owns the pursued item.
  final bool owned;

  bool get complete => owned || (recipe != null && needs.isEmpty);
}

/// Computes the pursuit plan for [item].
///
/// A recipe is usable when it is not locked by a project or contract the
/// state has not satisfied ([availableRecipeFor]). Held materials are
/// counted **once**, against a working ledger that is decremented as the
/// walk consumes them — the double-count rule the brief's §81 names.
/// Recursion depth is bounded by the recipe graph's own acyclicity (a recipe
/// cannot consume its own output; cross-cycles stop at the visited guard and
/// fall back to treating the item as a base need).
PursuitPlan pursuitPlanFor(
  ContentRegistry registry,
  GameState state,
  ContentId item,
) {
  final RecipeDefinition? recipe = availableRecipeFor(registry, state, item);
  final Map<ContentId, int> working = <ContentId, int>{
    ...state.inventory.counts,
  };
  final bool owned = (working[item] ?? 0) > 0;

  if (recipe == null) {
    final List<PursuitNeed> needs = owned
        ? const <PursuitNeed>[]
        : <PursuitNeed>[_needFor(registry, item, 1)];
    return PursuitPlan(
      item: item,
      recipe: null,
      lines: const <PursuitLine>[],
      needs: needs,
      owned: owned,
    );
  }

  // Fold the recipe's direct requirements for the display lines.
  final Map<ContentId, int> direct = <ContentId, int>{};
  for (final RecipeIngredient ingredient in recipe.ingredients) {
    direct[ingredient.item] =
        (direct[ingredient.item] ?? 0) + ingredient.quantity;
  }
  final List<PursuitLine> lines = <PursuitLine>[
    for (final MapEntry<ContentId, int> e in direct.entries)
      PursuitLine(
        item: e.key,
        required: e.value,
        held: (working[e.key] ?? 0) > e.value
            ? e.value
            : (working[e.key] ?? 0),
      ),
  ]..sort((PursuitLine a, PursuitLine b) => a.item.compareTo(b.item));

  final Map<ContentId, int> missing = <ContentId, int>{};
  _resolveNeeds(
    registry,
    state,
    direct,
    working,
    missing,
    <ContentId>{recipe.outputItem},
  );

  final List<PursuitNeed> needs = <PursuitNeed>[
    for (final MapEntry<ContentId, int> e
        in (missing.entries.toList()..sort(
          (MapEntry<ContentId, int> a, MapEntry<ContentId, int> b) =>
              a.key.compareTo(b.key),
        )))
      _needFor(registry, e.key, e.value),
  ];

  return PursuitPlan(
    item: item,
    recipe: recipe.id,
    lines: lines,
    needs: needs,
    owned: owned,
  );
}

/// The recipe that currently produces [item], respecting project and
/// contract gating, or null. When both a retired and an improved recipe
/// exist for one output, exactly one is available at a time by construction
/// (the Mill retires one and unlocks the other in the same completion).
RecipeDefinition? availableRecipeFor(
  ContentRegistry registry,
  GameState state,
  ContentId item,
) {
  for (final RecipeDefinition recipe in registry.recipes.values) {
    if (recipe.outputItem != item) continue;
    if (_recipeLocked(recipe, state)) continue;
    return recipe;
  }
  return null;
}

bool _recipeLocked(RecipeDefinition recipe, GameState state) {
  final ContentId? projectGate = recipe.unlockedByProject;
  if (projectGate != null && !state.progress.isProjectComplete(projectGate)) {
    return true;
  }
  final ContentId? retiredBy = recipe.retiredByProject;
  if (retiredBy != null && state.progress.isProjectComplete(retiredBy)) {
    return true;
  }
  final ContentId? contractGate = recipe.unlockedByContract;
  if (contractGate != null && state.progress.completionsOf(contractGate) == 0) {
    return true;
  }
  return false;
}

/// Consumes held stock and recurses into craftable deficits, accumulating
/// base-material shortfalls into [missing].
void _resolveNeeds(
  ContentRegistry registry,
  GameState state,
  Map<ContentId, int> required,
  Map<ContentId, int> working,
  Map<ContentId, int> missing,
  Set<ContentId> visiting,
) {
  for (final MapEntry<ContentId, int> need in required.entries) {
    final int held = working[need.key] ?? 0;
    final int consumed = held < need.value ? held : need.value;
    if (consumed > 0) working[need.key] = held - consumed;
    final int deficit = need.value - consumed;
    if (deficit == 0) continue;

    final RecipeDefinition? recipe = visiting.contains(need.key)
        ? null
        : availableRecipeFor(registry, state, need.key);
    if (recipe == null) {
      missing[need.key] = (missing[need.key] ?? 0) + deficit;
      continue;
    }

    final int batches = (deficit + recipe.outputQuantity - 1) ~/
        recipe.outputQuantity;
    final Map<ContentId, int> nested = <ContentId, int>{};
    for (final RecipeIngredient ingredient in recipe.ingredients) {
      nested[ingredient.item] =
          (nested[ingredient.item] ?? 0) + ingredient.quantity * batches;
    }
    _resolveNeeds(registry, state, nested, working, missing, <ContentId>{
      ...visiting,
      need.key,
    });
  }
}

PursuitNeed _needFor(ContentRegistry registry, ContentId item, int quantity) {
  for (final MapEntry<ContentId, ResourceNodeDefinition> e
      in registry.resourceNodes.entries) {
    if (e.value.yieldsItem != item) continue;
    for (final LocationDefinition location in registry.locations.values) {
      if (location.resourceNodes.contains(e.key)) {
        return PursuitNeed(
          item: item,
          quantity: quantity,
          sourceNode: e.key,
          sourceLocation: location.id,
        );
      }
    }
    return PursuitNeed(item: item, quantity: quantity, sourceNode: e.key);
  }
  for (final EnemyDefinition enemy in registry.enemies.values) {
    if (enemy.drops.any((EnemyDrop d) => d.item == item)) {
      return PursuitNeed(
        item: item,
        quantity: quantity,
        sourceEnemy: enemy.id,
        sourceLocation: enemy.location,
      );
    }
  }
  return PursuitNeed(item: item, quantity: quantity);
}
