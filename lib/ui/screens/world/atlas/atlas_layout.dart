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

  /// The edge's identity, independent of which way it was declared. Used as a
  /// set key by the route layer so highlighting is a lookup rather than a
  /// scan.
  String get key => '${a.id.value}|${b.id.value}';

  /// The key an edge between [x] and [y] would have, in either order.
  static String keyOf(ContentId x, ContentId y) =>
      x.compareTo(y) <= 0 ? '${x.value}|${y.value}' : '${y.value}|${x.value}';
}

/// What the inspector needs to describe a journey, and the route layer needs
/// to draw it.
///
/// **Every figure here comes from the session**, profile-scaled as it gives
/// them, and none of it is a rule: `TravelTo` charges the first leg and
/// re-checks everything. [totalCost] is the sum of the legs of a walk the
/// player will make one road at a time — a *quotation for the whole journey*,
/// not a price anything charges at once.
final class AtlasWay {
  const AtlasWay({
    required this.hops,
    required this.edges,
    required this.totalCost,
    required this.firstLegCost,
  });

  /// Each leg's destination, in order, ending at the target. Length is the
  /// number of roads walked; `hops.first` is the place the Travel button
  /// actually sets out for.
  final List<AtlasNode> hops;

  /// The edges the walk uses, for the preview.
  final List<AtlasEdge> edges;

  /// The sum of every leg's step cost.
  final int totalCost;

  /// The first leg's cost — the figure the Travel button charges.
  final int firstLegCost;

  /// Whether the target is one road away.
  bool get isDirect => hops.length == 1;

  /// The places passed through on the way, excluding the target.
  List<AtlasNode> get via => hops.sublist(0, hops.length - 1);
}

final class AtlasScene {
  AtlasScene._({
    required this.layout,
    required this.nodes,
    required this.edges,
    required this.current,
    required this.destinations,
    required this._neighbours,
    required this._legCost,
    required this._byId,
  });

  /// Joins [layout] to what [session] projects. Returns null when the layout is
  /// absent, in which case the screen shows its list.
  static AtlasScene? build(StrideSession session) {
    final AtlasLayout? layout = session.atlasLayout;
    if (layout == null) return null;
    return join(
      layout: layout,
      places: session.regionPlaces,
      routes: session.regionRoutes,
      options: session.destinations,
    );
  }

  /// The join itself, over values rather than a session.
  ///
  /// Exists so a test can build a scene over a fixture layout — a world of a
  /// different size, a layout carrying landmarks — without booting a save.
  /// [build] is the only caller in the app, and it passes the session's own
  /// projections unaltered: this is not a second source of any of them.
  static AtlasScene? join({
    required AtlasLayout layout,
    required List<RegionPlace> places,
    required List<RegionRoute> routes,
    required List<TravelOption> options,
  }) {
    final Map<ContentId, AtlasNode> byId = <ContentId, AtlasNode>{};
    AtlasNode? current;
    for (final RegionPlace place in places) {
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
    final Map<String, int> legCost = <String, int>{};
    final Set<String> seen = <String>{};
    final List<AtlasEdge> edges = <AtlasEdge>[];
    for (final RegionRoute route in routes) {
      neighbours.putIfAbsent(route.from, () => <ContentId>[]).add(route.to);
      // Directed, because a road may be priced differently each way and the
      // quotation must be for the direction the player would walk.
      legCost['${route.from.value}>${route.to.value}'] = route.stepCost;
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
        for (final TravelOption option in options) option.id: option,
      },
      neighbours: neighbours,
      legCost: legCost,
      byId: byId,
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

  /// `from>to` → the profile-scaled cost of that one road, as the session
  /// gave it.
  final Map<String, int> _legCost;

  final Map<ContentId, AtlasNode> _byId;

  double get worldWidth => layout.worldWidth.toDouble();
  double get worldHeight => layout.worldHeight.toDouble();

  AtlasNode? nodeFor(ContentId id) => _byId[id];

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

  /// The whole walk from [current] to [target] — its legs, the edges it uses,
  /// what it costs in all, and what the first leg costs.
  ///
  /// Null when [target] is where the player already stands, or when no chain
  /// of roads reaches it: in both cases there is nothing to preview and
  /// nothing highlights.
  ///
  /// The costs are sums of [RegionRoute.stepCost], which the session already
  /// scaled through the active balance profile. Nothing is computed here that
  /// the engine does not also compute — the engine charges leg by leg, and
  /// [AtlasWay.firstLegCost] is the leg it would charge first.
  AtlasWay? routeSummary(ContentId target) {
    if (target == current.id) return null;
    final List<ContentId>? via = wayTo(target);
    if (via == null) return null;

    final List<ContentId> chain = <ContentId>[...via, target];
    final List<AtlasNode> hops = <AtlasNode>[];
    final List<AtlasEdge> path = <AtlasEdge>[];
    final Map<String, AtlasEdge> byKey = <String, AtlasEdge>{
      for (final AtlasEdge edge in edges) edge.key: edge,
    };

    int total = 0;
    int first = 0;
    ContentId from = current.id;
    for (final (int i, ContentId to) in chain.indexed) {
      final AtlasNode? node = nodeFor(to);
      if (node == null) return null;
      hops.add(node);
      final int cost = _legCost['${from.value}>${to.value}'] ?? 0;
      total += cost;
      if (i == 0) first = cost;
      final AtlasEdge? edge = byKey[AtlasEdge.keyOf(from, to)];
      if (edge != null) path.add(edge);
      from = to;
    }

    return AtlasWay(
      hops: List<AtlasNode>.unmodifiable(hops),
      edges: List<AtlasEdge>.unmodifiable(path),
      totalCost: total,
      firstLegCost: first,
    );
  }

  /// How much room [node]'s hit target has before it starts stealing another
  /// place's thumb space, in world pixels. Infinite for a lone place.
  ///
  /// Measured on the **larger axis** rather than as a straight-line distance,
  /// because a hit target is a square: two squares of half-width `r` centred
  /// `d` apart on their widest axis miss each other exactly when `2r < d`, and
  /// a Euclidean measure would permit a diagonal pair to overlap on both axes
  /// while passing the test.
  double separationAround(AtlasNode node) {
    double nearest = double.infinity;
    for (final AtlasNode other in nodes) {
      if (other.id == node.id) continue;
      final double dx = (other.x - node.x).abs();
      final double dy = (other.y - node.y).abs();
      final double d = dx > dy ? dx : dy;
      if (d < nearest) nearest = d;
    }
    return nearest;
  }
}
