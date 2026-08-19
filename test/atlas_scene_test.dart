/// The atlas surface over a world that is not the one currently shipped.
///
/// ## The risks these cover, named before the work
///
/// - **Code that assumes 768 × 1376.** The art stream is about to quadruple the
///   world to 1536 × 2752. Every camera bound, zoom floor and clamp must come
///   from the layout, and the only way to prove that is to build the surface
///   over a *different* world and check the geometry moves with it.
/// - **A route preview that highlights the wrong roads.** The dots on the way
///   must be exactly the edges of the breadth-first walk — no more (a road that
///   merely touches the path) and no fewer.
/// - **A quotation that is not the sum of its legs.** The inspector prints a
///   total and a first leg; both must come from the session's own per-road
///   costs, and the pair must agree with each other.
/// - **A landmark that behaves like a place.** A named landmark is scenery: no
///   hit target, no selection, no panel. Tapping where one stands must do
///   nothing at all.
/// - **A one-shot animation that never stops.** The arrival burst runs once;
///   a controller that repeats, or is not disposed, is a battery leak the
///   player cannot see.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/atlas_layout.dart';
import 'package:stride/runtime/stride_session.dart'
    show RegionPlace, RegionRoute, TravelOption;
import 'package:stride/ui/screens/world/atlas/atlas_layers.dart';
import 'package:stride/ui/screens/world/atlas/atlas_layout.dart';
import 'package:stride/ui/screens/world/atlas/atlas_place_info.dart';
import 'package:stride/ui/screens/world/atlas/atlas_viewport.dart';
import 'package:stride_core/stride_core.dart'
    show ContentId, LocationKind, Terrain;

import 'support/real_font.dart';

ContentId id(String slug) => ContentId.unchecked('location.$slug');

/// A world four times the shipped one, with the tile grid the art brief
/// describes — so nothing here is satisfied by the current geometry.
const String _bigWorld = '''
{
  "schemaVersion": 2,
  "world": { "width": 1536, "height": 2752 },
  "scale": 2,
  "base": { "tiles": [
    { "asset": "world/atlas_base", "x": 0, "y": 0, "width": 384, "height": 688 },
    { "asset": "world/atlas_base", "x": 384, "y": 0, "width": 384, "height": 688 },
    { "asset": "world/atlas_base", "x": 0, "y": 688, "width": 384, "height": 688 },
    { "asset": "world/atlas_base", "x": 384, "y": 688, "width": 384, "height": 688 }
  ] },
  "locations": [
    { "id": "location.a", "x": 200, "y": 2400, "hitRadius": 44, "landmark": null },
    { "id": "location.b", "x": 700, "y": 1400, "hitRadius": 40, "landmark": null },
    { "id": "location.c", "x": 1300, "y": 400, "hitRadius": 40, "landmark": null },
    { "id": "location.d", "x": 300, "y": 1200, "hitRadius": 40, "landmark": null }
  ],
  "landmarks": [
    { "id": "landmark.watchtower", "name": "Ruined Watchtower",
      "x": 1000, "y": 900, "tier": "minor" },
    { "id": "landmark.far_town", "name": "Far Town",
      "x": 1400, "y": 2600, "tier": "future" }
  ],
  "routes": [], "props": [], "overlays": []
}
''';

/// `a — b — c`, plus a spur `a — d` that must never be highlighted on the way
/// to `c`.
List<RegionRoute> _routes() => <RegionRoute>[
  RegionRoute(from: id('a'), to: id('b'), stepCost: 800),
  RegionRoute(from: id('b'), to: id('a'), stepCost: 800),
  RegionRoute(from: id('b'), to: id('c'), stepCost: 1500),
  RegionRoute(from: id('c'), to: id('b'), stepCost: 1500),
  RegionRoute(from: id('a'), to: id('d'), stepCost: 300),
  RegionRoute(from: id('d'), to: id('a'), stepCost: 300),
];

RegionPlace _place(String slug, {bool current = false, bool safe = false}) =>
    RegionPlace(
      id: id(slug),
      displayName: slug.toUpperCase(),
      isCurrent: current,
      isSafe: safe,
      isUnlocked: true,
      stepCostFromHere: null,
      resourceCount: 0,
      terrain: Terrain.grassland,
      kind: LocationKind.wilds,
    );

AtlasScene _scene({String layout = _bigWorld}) => AtlasScene.join(
  layout: AtlasLayout.parse(layout),
  places: <RegionPlace>[
    _place('a', current: true, safe: true),
    _place('b'),
    _place('c'),
    _place('d'),
  ],
  routes: _routes(),
  options: <TravelOption>[
    TravelOption(
      id: id('b'),
      displayName: 'B',
      terrain: Terrain.forest,
      stepCost: 800,
      isReached: true,
      affordable: true,
      missingRequirements: const <String>[],
      resourceCount: 0,
    ),
  ],
)!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRealFont);

  group('the way to a place', () {
    test('is null for here, and for somewhere no road reaches', () {
      final AtlasScene scene = _scene();
      expect(scene.routeSummary(id('a')), isNull, reason: 'here');
      expect(
        scene.routeSummary(ContentId.unchecked('location.nowhere')),
        isNull,
      );
    });

    test('quotes one leg for a neighbour', () {
      final AtlasWay way = _scene().routeSummary(id('b'))!;
      expect(way.isDirect, isTrue);
      expect(way.hops.map((AtlasNode n) => n.id.value), <String>['location.b']);
      expect(way.totalCost, 800);
      expect(way.firstLegCost, 800);
      expect(way.via, isEmpty);
    });

    test('sums the legs, and names the first, for a place two roads off', () {
      final AtlasWay way = _scene().routeSummary(id('c'))!;
      expect(way.isDirect, isFalse);
      expect(way.hops.map((AtlasNode n) => n.id.value), <String>[
        'location.b',
        'location.c',
      ]);
      expect(way.totalCost, 2300, reason: '800 + 1500');
      expect(
        way.firstLegCost,
        800,
        reason: 'the only figure the Travel button charges',
      );
      expect(way.via.single.id.value, 'location.b');
    });

    test('highlights exactly the edges of the walk, and no spur', () {
      final AtlasScene scene = _scene();
      final AtlasWay way = scene.routeSummary(id('c'))!;
      expect(way.edges.map((AtlasEdge e) => e.key).toSet(), <String>{
        AtlasEdge.keyOf(id('a'), id('b')),
        AtlasEdge.keyOf(id('b'), id('c')),
      });
      // The spur to `d` exists on the surface and is not on the way.
      expect(scene.edges.length, 3);
      expect(
        way.edges.any(
          (AtlasEdge e) => e.key == AtlasEdge.keyOf(id('a'), id('d')),
        ),
        isFalse,
      );
    });
  });

  group('the viewport over a 1536 × 2752 world', () {
    Future<AtlasViewportState> pump(
      WidgetTester tester, {
      required AtlasScene scene,
      double width = 393,
      double height = 400,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: AtlasViewport(
                scene: scene,
                selected: scene.current.id,
                kinds: <ContentId, AtlasPlaceKind>{
                  for (final AtlasNode n in scene.nodes)
                    n.id: AtlasPlaceKind.wilds,
                },
                onSelect: (ContentId _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.state<AtlasViewportState>(find.byType(AtlasViewport));
    }

    testWidgets('reads its bounds from the layout, not from a constant', (
      WidgetTester tester,
    ) async {
      final AtlasScene big = _scene();
      final AtlasViewportState state = await pump(tester, scene: big);
      expect(big.worldWidth, 1536);
      expect(big.worldHeight, 2752);
      // 393 / 1536 is 0.256, below the absolute floor, so half the width is
      // what a player surveys — the case the milestone names.
      expect(state.minZoom, AtlasZoom.absoluteFloor);
      expect(state.zoom, AtlasZoom.initial);
    });

    testWidgets('lets a narrower world be seen whole, and no further', (
      WidgetTester tester,
    ) async {
      // The shipped 768-wide world: 393 / 768 is 0.512, above the floor, so
      // the bottom of the range is "the whole width fits" rather than 0.5.
      final AtlasScene shipped = _scene(
        layout: _bigWorld.replaceFirst(
          '"world": { "width": 1536, "height": 2752 }',
          '"world": { "width": 768, "height": 2752 }',
        ),
      );
      final AtlasViewportState state = await pump(tester, scene: shipped);
      expect(state.minZoom, closeTo(393 / 768, 0.0001));
      expect(state.minZoom, greaterThan(AtlasZoom.absoluteFloor));
    });

    testWidgets('opens centred on the current place and clamps every pan', (
      WidgetTester tester,
    ) async {
      final AtlasScene scene = _scene();
      final AtlasViewportState state = await pump(tester, scene: scene);
      final Rect window = tester.getRect(find.byType(AtlasViewport));
      expect(
        (window.center - tester.getCenter(_hit('location.a'))).distance,
        lessThan(2),
      );

      for (final Offset delta in <Offset>[
        const Offset(4000, 6000),
        const Offset(-4000, -6000),
      ]) {
        await tester.dragFrom(window.center, delta);
        await tester.pumpAndSettle();
        expect(state.camera.dx, greaterThanOrEqualTo(0));
        expect(state.camera.dy, greaterThanOrEqualTo(0));
        expect(
          state.camera.dx,
          lessThanOrEqualTo(scene.worldWidth - window.width / state.zoom),
        );
        expect(
          state.camera.dy,
          lessThanOrEqualTo(scene.worldHeight - window.height / state.zoom),
        );
      }
    });

    testWidgets('pinches to both ends of the range and settles on the grid', (
      WidgetTester tester,
    ) async {
      final AtlasViewportState state = await pump(tester, scene: _scene());
      await _pinch(tester, 100, 400);
      expect(state.zoom, AtlasZoom.max);
      await _pinch(tester, 300, 40);
      expect(
        state.zoom,
        AtlasZoom.absoluteFloor,
        reason: 'half of ×2 art is ×1 native — the crispest reduction there is',
      );
    });

    testWidgets('a landmark is drawn, named, and cannot be tapped', (
      WidgetTester tester,
    ) async {
      final AtlasScene scene = _scene();
      final AtlasViewportState state = await pump(tester, scene: scene);
      // Pan the watchtower into view. It has a name on the surface…
      final Offset centre = tester.getCenter(find.byType(AtlasViewport));
      await tester.dragFrom(centre, const Offset(-400, 600));
      await tester.pumpAndSettle();
      expect(find.text('Ruined Watchtower'), findsOneWidget);
      // …and the `future` tier carries its unfinished-sentence mark, which is
      // the mark that tells a road pointing off the map from a destination.
      expect(find.text('Far Town —'), findsOneWidget);
      expect(find.text('Far Town'), findsNothing);

      // …but nothing under it takes a tap: no key, no semantics button, and
      // the selection is exactly where it was.
      final Offset label = tester.getCenter(find.text('Ruined Watchtower'));
      final Offset cameraBefore = state.camera;
      await tester.tapAt(label);
      await tester.pumpAndSettle();
      expect(
        tester.widget<AtlasViewport>(find.byType(AtlasViewport)).selected,
        scene.current.id,
      );
      expect(state.camera, cameraBefore);
      expect(
        find.byKey(const ValueKey<String>('atlas-hit:landmark.watchtower')),
        findsNothing,
      );
    });

    testWidgets('a place keeps a 44 dp target at the zoom floor', (
      WidgetTester tester,
    ) async {
      // The floor exists so a thumb can find a place. At 0.5× a world-pixel
      // radius is half a logical pixel, so the target has to grow — but never
      // into a neighbour's, which the second assertion is for.
      final AtlasScene scene = _scene();
      final AtlasViewportState state = await pump(tester, scene: scene);
      await _pinch(tester, 300, 60);
      expect(state.zoom, AtlasZoom.absoluteFloor);

      final List<String> ids = <String>[
        'location.a',
        'location.b',
        'location.c',
        'location.d',
      ];
      for (int i = 0; i < ids.length; i++) {
        final Rect a = tester.getRect(_hit(ids[i]));
        expect(a.width, greaterThanOrEqualTo(44), reason: ids[i]);
        for (int j = i + 1; j < ids.length; j++) {
          expect(
            a.overlaps(tester.getRect(_hit(ids[j]))),
            isFalse,
            reason: '${ids[i]} and ${ids[j]} share thumb space at 0.5×',
          );
        }
      }
    });

    testWidgets('no name overlaps another, place or landmark, at any zoom', (
      WidgetTester tester,
    ) async {
      // Two tiers of label share one surface. A place name covered by a
      // landmark caption is a destination the player cannot read, and the
      // counter-scaling makes the geometry zoom-dependent — so it is checked
      // at both ends of the range rather than once at 1×.
      final AtlasViewportState state = await pump(tester, scene: _scene());
      const List<String> names = <String>[
        'A',
        'B',
        'C',
        'D',
        'Ruined Watchtower',
        'Far Town —',
      ];
      void check(String at) {
        for (int i = 0; i < names.length; i++) {
          final Rect a = tester.getRect(find.text(names[i]));
          for (int j = i + 1; j < names.length; j++) {
            expect(
              a.overlaps(tester.getRect(find.text(names[j]))),
              isFalse,
              reason: '"${names[i]}" and "${names[j]}" collide at $at',
            );
          }
        }
      }

      check('1×');
      await _pinch(tester, 300, 40);
      expect(state.zoom, AtlasZoom.absoluteFloor);
      check('the zoom floor');
      await _pinch(tester, 100, 400);
      expect(state.zoom, AtlasZoom.max);
      check('2×');
    });

    testWidgets('a place name stays the size it was designed at, at any zoom', (
      WidgetTester tester,
    ) async {
      // The reason labels counter-scale: at the floor the world is drawn at
      // half size, and a name that scaled with it would be 5.5 dp type.
      final AtlasViewportState state = await pump(tester, scene: _scene());
      final double atOne = tester.getSize(find.text('A')).height;

      await _pinch(tester, 300, 60);
      expect(state.zoom, AtlasZoom.absoluteFloor);
      expect(tester.getSize(find.text('A')).height, closeTo(atOne, 0.5));

      await _pinch(tester, 100, 400);
      expect(state.zoom, AtlasZoom.max);
      expect(tester.getSize(find.text('A')).height, closeTo(atOne, 0.5));
    });
  });

  group('the arrival burst', () {
    testWidgets('plays once and leaves no ticker behind', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: AtlasArrivalBurst())),
      );
      await tester.pump();
      expect(
        tester.hasRunningAnimations,
        isTrue,
        reason: 'the burst starts on its own',
      );

      await tester.pump(AtlasArrivalBurst.period + const Duration(seconds: 1));
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: 'one shot: it does not repeat',
      );

      // Torn down mid-nothing, then torn down again from a live run: neither
      // may leave a pending timer, which is what `pumpWidget` asserts on the
      // way out.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: AtlasArrivalBurst())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}

Finder _hit(String value) => find.byKey(ValueKey<String>('atlas-hit:$value'));

/// A two-finger pinch about the viewport's centre, from [from] to [to] pixels
/// apart, in ten steps.
Future<void> _pinch(WidgetTester tester, double from, double to) async {
  final Offset c = tester.getCenter(find.byType(AtlasViewport));
  final TestGesture a = await tester.startGesture(c - Offset(from / 2, 0));
  final TestGesture b = await tester.startGesture(c + Offset(from / 2, 0));
  await tester.pump();
  for (int i = 1; i <= 10; i++) {
    final double gap = from + (to - from) * i / 10;
    await a.moveTo(c - Offset(gap / 2, 0));
    await b.moveTo(c + Offset(gap / 2, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await a.up();
  await b.up();
  await tester.pumpAndSettle();
}
