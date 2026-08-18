/// The atlas as the World screen draws it: layout coordinates joined to what
/// the session knows about each place.
///
/// `AtlasLayout` (from `lib/runtime`) says **where** things are, in world
/// pixels, and knows nothing about the player. `StrideSession` says which place
/// is current, which are reachable and at what price, and which roads exist —
/// and knows nothing about pixels. [AtlasScene] is the join, computed once per
/// build from the two, so no layer widget has to do the lookup itself.
///
/// **Nothing here is a rule.** Connections come from `regionRoutes`, which is
/// content adjacency; the current location and every price come from the
/// session's projections; and "reached by way of" is a walk over the same
/// content graph the engine validates against. `TravelTo` re-checks all of it.
library;

import 'dart:collection' show Queue;

import 'package:stride_core/stride_core.dart' show ContentId;

import '../../../../runtime/stride_session.dart';

/// One place, positioned.
final class AtlasNode {
  const AtlasNode({required this.place, required this.x, required this.y});

  final RegionPlace place;

  /// World pixels.
  final double x;
  final double y;

  ContentId get id => place.id;
}

/// One road, drawn once. [a] and [b] are ordered by id so that a route
/// declared in both directions is one edge.
final class AtlasEdge {
  const AtlasEdge({required this.a, required this.b});

  final AtlasNode a;
  final AtlasNode b;
}

final class AtlasScene {
  AtlasScene._({
    required this.layout,
    required this.nodes,
    required this.edges,
    required this.current,
    required this.destinations,
    required this._neighbours,
  });

  /// Joins [layout] to what [session] projects. Returns null when the layout is
  /// absent, in which case the screen shows its list.
  static AtlasScene? build(StrideSession session) {
    final AtlasLayout? layout = session.atlasLayout;
    if (layout == null) return null;

    final Map<ContentId, AtlasNode> byId = <ContentId, AtlasNode>{};
    AtlasNode? current;
    for (final RegionPlace place in session.regionPlaces) {
      final AtlasLocation? at = layout.locationFor(place.id);
      // Validated at load, so this cannot be null for a shipped layout; a
      // place the layout does not know is skipped rather than drawn at (0, 0).
      if (at == null) continue;
      final AtlasNode node = AtlasNode(place: place, x: at.x, y: at.y);
      byId[place.id] = node;
      if (place.isCurrent) current = node;
    }
    if (current == null) return null;

    final Map<ContentId, List<ContentId>> neighbours =
        <ContentId, List<ContentId>>{};
    final Set<String> seen = <String>{};
    final List<AtlasEdge> edges = <AtlasEdge>[];
    for (final RegionRoute route in session.regionRoutes) {
      neighbours.putIfAbsent(route.from, () => <ContentId>[]).add(route.to);
      final AtlasNode? from = byId[route.from];
      final AtlasNode? to = byId[route.to];
      if (from == null || to == null) continue;
      final bool ordered = from.id.compareTo(to.id) <= 0;
      final AtlasNode a = ordered ? from : to;
      final AtlasNode b = ordered ? to : from;
      if (seen.add('${a.id.value}|${b.id.value}')) {
        edges.add(AtlasEdge(a: a, b: b));
      }
    }

    return AtlasScene._(
      layout: layout,
      nodes: List<AtlasNode>.unmodifiable(byId.values),
      edges: List<AtlasEdge>.unmodifiable(edges),
      current: current,
      destinations: <ContentId, TravelOption>{
        for (final TravelOption option in session.destinations)
          option.id: option,
      },
      neighbours: neighbours,
    );
  }

  final AtlasLayout layout;
  final List<AtlasNode> nodes;
  final List<AtlasEdge> edges;

  /// Where the player stands.
  final AtlasNode current;

  /// The journeys the session offers from [current], by destination.
  final Map<ContentId, TravelOption> destinations;

  final Map<ContentId, List<ContentId>> _neighbours;

  double get worldWidth => layout.worldWidth.toDouble();
  double get worldHeight => layout.worldHeight.toDouble();

  AtlasNode? nodeFor(ContentId id) {
    for (final AtlasNode node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  /// The travel option for [id], or null when no road runs there from here.
  TravelOption? optionFor(ContentId id) => destinations[id];

  /// The places a walk from [current] to [target] passes through, in order,
  /// excluding both ends — so a screen can say *reached by way of Stonefall
  /// Mine*. Empty when [target] is adjacent or is [current]; null when no
  /// chain of roads reaches it at all.
  ///
  /// Breadth-first over content adjacency, fewest hops. Not a route the engine
  /// will walk for the player — travel is one road at a time — and not a cost
  /// estimate; it is the answer to "which way".
  List<ContentId>? wayTo(ContentId target) {
    final ContentId start = current.id;
    if (target == start) return const <ContentId>[];
    final Map<ContentId, ContentId?> cameFrom = <ContentId, ContentId?>{
      start: null,
    };
    final Queue<ContentId> frontier = Queue<ContentId>()..add(start);
    while (frontier.isNotEmpty) {
      final ContentId here = frontier.removeFirst();
      for (final ContentId next in _neighbours[here] ?? const <ContentId>[]) {
        if (cameFrom.containsKey(next)) continue;
        cameFrom[next] = here;
        if (next == target) {
          final List<ContentId> path = <ContentId>[];
          ContentId? step = cameFrom[target];
          while (step != null && step != start) {
            path.add(step);
            step = cameFrom[step];
          }
          return path.reversed.toList(growable: false);
        }
        frontier.add(next);
      }
    }
    return null;
  }
}
