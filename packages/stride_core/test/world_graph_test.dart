// The world as a graph, and the properties a player would discover the hard way.
//
// The content loader already rejects dangling references, self-connections, a
// missing start, and a gathered material nothing consumes. This file covers what
// it does not: whether the graph the player actually walks holds together.
//
// These are integration-critic questions asked as tests, because every one of
// them is invisible until someone plays for an hour and gets stuck.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'step_support.dart';

final ContentId havensRest = ContentId.unchecked('location.havens_rest');

ContentRegistry get world => stepRegistry;

/// Locations reachable from the start by following connections, ignoring
/// entry requirements and cost.
Set<ContentId> connectedFromStart() {
  final Set<ContentId> seen = <ContentId>{world.startLocation.id};
  final List<ContentId> queue = <ContentId>[world.startLocation.id];
  while (queue.isNotEmpty) {
    final LocationDefinition? here = world.locations[queue.removeLast()];
    if (here == null) continue;
    for (final LocationConnection edge in here.connections) {
      if (seen.add(edge.to)) queue.add(edge.to);
    }
  }
  return seen;
}

void main() {
  group('1 — the travel graph', () {
    test('every location is connected to the start', () {
      // An island is content nobody can ever visit. It costs nothing to check
      // and is impossible to see by reading the file.
      expect(
        connectedFromStart(),
        hasLength(world.locations.length),
        reason:
            'unreachable: '
            '${world.locations.keys.toSet().difference(connectedFromStart())}',
      );
    });

    test('every route runs both ways, at the same price', () {
      // A one-way edge strands the player. An asymmetric one means the same
      // road costs different amounts depending on which end you start from,
      // which no geography justifies and every player would read as a bug.
      for (final LocationDefinition from in world.locations.values) {
        for (final LocationConnection out in from.connections) {
          final LocationDefinition to = world.locations[out.to]!;
          final Iterable<LocationConnection> back = to.connections.where(
            (LocationConnection c) => c.to == from.id,
          );
          expect(
            back,
            hasLength(1),
            reason: '${from.id} → ${to.id} has no return route',
          );
          expect(
            back.single.stepCost,
            out.stepCost,
            reason:
                '${from.id} ↔ ${to.id} costs ${out.stepCost} one way and '
                '${back.single.stepCost} the other',
          );
        }
      }
    });

    test('no location declares the same destination twice', () {
      // A duplicate edge is harmless to the engine — it takes the first — and
      // would show the player the same place twice on the World screen.
      for (final LocationDefinition from in world.locations.values) {
        final List<ContentId> targets = from.connections
            .map((LocationConnection c) => c.to)
            .toList();
        expect(
          targets.toSet(),
          hasLength(targets.length),
          reason: '${from.id} lists a destination more than once',
        );
      }
    });

    test('the start location has no entry requirement', () {
      expect(world.startLocation.entryRequirements, isEmpty);
      expect(world.startLocation.id, havensRest);
      expect(world.startLocation.isSafe, isTrue);
    });
  });

  group('2 — every place has a purpose', () {
    test('no location is empty of things to do', () {
      // A place with nothing in it is a step cost with no reward behind it.
      for (final LocationDefinition location in world.locations.values) {
        final bool hasSomething =
            location.resourceNodes.isNotEmpty ||
            world.enemies.values.any(
              (EnemyDefinition e) => e.location == location.id,
            );
        expect(
          hasSomething,
          isTrue,
          reason: '${location.id} has no resources and no enemies',
        );
      }
    });

    test('every resource node lives in exactly one location', () {
      // Zero would make it unreachable; two would make "where do I get this?"
      // have no single answer and would double the yield of one walk.
      for (final ContentId node in world.resourceNodes.keys) {
        final Iterable<LocationDefinition> hosts = world.locations.values.where(
          (LocationDefinition l) => l.resourceNodes.contains(node),
        );
        expect(hosts, hasLength(1), reason: '$node is hosted ${hosts.length}×');
      }
    });

    test('no crafted output is a dead end', () {
      // Every recipe output must be usable: as an ingredient, as equipment, as
      // a consumable, or as a key to somewhere. An output that is none of those
      // is walking that bought nothing.
      for (final RecipeDefinition recipe in world.recipes.values) {
        final ItemDefinition output = world.items[recipe.outputItem]!;
        final bool used =
            world.recipes.values.any(
              (RecipeDefinition r) => r.ingredients.any(
                (RecipeIngredient i) => i.item == output.id,
              ),
            ) ||
            output.slot != null ||
            output.category == ItemCategory.consumable ||
            world.locations.values.any(
              (LocationDefinition l) => l.entryRequirements.contains(output.id),
            );
        expect(
          used,
          isTrue,
          reason: '"${output.id}" is crafted by ${recipe.id} and does nothing',
        );
      }
    });
  });

  group('3 — the geography is a system, not a theme park (OD-02)', () {
    test('every location declares its terrain', () {
      // Required by the schema, asserted here as intent: a place with no
      // terrain is a place with no reason for its resources to be there.
      for (final LocationDefinition location in world.locations.values) {
        expect(location.terrain, isNotNull, reason: '${location.id}');
      }
    });

    test('the slice covers four terrains across five locations', () {
      expect(world.locations, hasLength(5));
      expect(
        world.locations.values.map((LocationDefinition l) => l.terrain).toSet(),
        <Terrain>{
          Terrain.grassland,
          Terrain.forest,
          Terrain.foothills,
          Terrain.alpine,
        },
      );
    });

    test('mining happens in the foothills and nowhere else', () {
      // The granite contact zone is where copper and tin actually occur. Ore in
      // a meadow would be the themed-zone failure OD-02 names, on the day
      // terrain was introduced.
      final ContentId mining = ContentId.unchecked('skill.mining');
      for (final LocationDefinition location in world.locations.values) {
        for (final ContentId nodeId in location.resourceNodes) {
          if (world.resourceNodes[nodeId]!.skill != mining) continue;
          expect(
            location.terrain,
            Terrain.foothills,
            reason: '$nodeId mines ${location.terrain.name}',
          );
        }
      }
    });

    test('timber comes from wooded ground, and the species follow climate', () {
      // Oak is a temperate lowland broadleaf; pine is a cold-climate conifer.
      // Both growing in one forest is exactly what OD-02 forbids.
      final ContentId woodcutting = ContentId.unchecked('skill.woodcutting');
      final Map<String, Terrain> expected = <String, Terrain>{
        'item.oak_log': Terrain.forest,
        'item.pine_log': Terrain.alpine,
      };
      for (final LocationDefinition location in world.locations.values) {
        for (final ContentId nodeId in location.resourceNodes) {
          final ResourceNodeDefinition node = world.resourceNodes[nodeId]!;
          if (node.skill != woodcutting) continue;
          expect(
            location.terrain,
            expected[node.yieldsItem.value],
            reason:
                '${node.yieldsItem} is felled on ${location.terrain.name}, '
                'which is not where that tree grows',
          );
        }
      }
    });

    test('foraging is the skill that travels', () {
      // Its rungs sit in different climates at different levels, so levelling
      // it is literally the act of going somewhere colder or darker. This is
      // the clearest expression of OD-02 in the slice.
      final ContentId foraging = ContentId.unchecked('skill.foraging');
      final Set<Terrain> climates = <Terrain>{};
      for (final LocationDefinition location in world.locations.values) {
        for (final ContentId nodeId in location.resourceNodes) {
          if (world.resourceNodes[nodeId]!.skill != foraging) continue;
          climates.add(location.terrain);
        }
      }
      expect(
        climates.length,
        greaterThanOrEqualTo(3),
        reason: 'foraging sits in only $climates',
      );
    });
  });

  group('4 — the player cannot be stranded or dead-ended', () {
    test('a tool gate is never satisfied only by what it gates', () {
      // "Requiring a tool that can only be crafted using the resource the tool
      // unlocks" — named in the Phase 2 brief. The reachability validator
      // proves the whole graph; this names the specific shape so a failure
      // reads as the thing it is.
      final ReachabilityResult result = ReachabilityValidator(
        world,
      ).analyse(targets: ContentLoader.defaultReachabilityTargets);

      expect(result.blocks, isEmpty, reason: '${result.blocks}');
      expect(result.isReachable, isTrue);
    });

    test('the alpine timber gate is openable, and is a real gate', () {
      // Frostpine Stand needs a tier-1 axe, which is the Bronze Axe, which is
      // the whole Mining → Smithing chain. That is the intended shape: a player
      // can always reach Frostmere and look at it, and cannot harvest it early.
      final ResourceNodeDefinition pine = world
          .resourceNodes[ContentId.unchecked('resource_node.frostpine_stand')]!;
      final ItemDefinition trainingAxe =
          world.items[ContentId.unchecked('item.training_axe')]!;
      final ItemDefinition bronzeAxe =
          world.items[ContentId.unchecked('item.bronze_axe')]!;

      expect(pine.minimumToolTier, 1);
      expect(
        trainingAxe.tier,
        lessThan(pine.minimumToolTier),
        reason: 'the granted axe must not already open the alpine timber',
      );
      expect(bronzeAxe.tier, greaterThanOrEqualTo(pine.minimumToolTier));
      expect(
        ReachabilityValidator(world)
            .analyse(targets: <ContentId>[ContentId.unchecked('item.pine_log')])
            .blocks,
        isEmpty,
      );
    });

    test('no travel cost is large enough to strand a returning player', () {
      // The player can always walk more, so no cost is a permanent trap. What
      // a cost *can* do is exceed what the owner has authorised a journey to
      // feel like. The bound used to be twenty of the cheapest gather (1,600);
      // Exploration & Progression Loop 01 deliberately made distance dear —
      // the Frostmere leg is an expedition the Journey tracker exists to make
      // walkable-toward — and its brief caps the worst authored leg at 4,000
      // steps (§52, owner-approved playtest targets; `DECISIONS/0023`).
      // The ceiling is the owner's figure, not this test's derivation.
      final int worstLeg = world.locations.values
          .expand((LocationDefinition l) => l.connections)
          .map((LocationConnection c) => c.stepCost)
          .reduce((int a, int b) => a > b ? a : b);

      expect(
        worstLeg,
        lessThanOrEqualTo(4000),
        reason:
            'the longest route ($worstLeg) exceeds the 4,000-step ceiling the '
            'owner authorised for a single leg (brief §52); a dearer road '
            'needs its own ruling',
      );
    });
  });
}
