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
import 'package:stride/ui/components/adaptive_text.dart';
import 'package:stride/ui/components/pixel_asset.dart';
import 'package:stride/ui/screens/world/atlas/atlas_layers.dart';
import 'package:stride/ui/screens/world/atlas/atlas_layout.dart';
import 'package:stride/ui/screens/world/atlas/atlas_place_info.dart';
import 'package:stride/ui/screens/world/atlas/atlas_viewport.dart';
import 'package:stride_core/stride_core.dart'
    show ContentId, LocationKind, Terrain;

import 'support/real_font.dart';

ContentId id(String slug) => ContentId.unchecked('location.$slug');

/// The ranges the viewport derives — spelled once, so an expectation below
/// reads as the rule it checks.
const AtlasZoom zooms2 = AtlasZoom.forScale(2);
const AtlasZoom zooms4 = AtlasZoom.forScale(4);

/// A world four times the shipped one, with the tile grid the art brief
/// describes — so nothing here is satisfied by the current geometry.
const String _bigWorld = '''
{
  "schemaVersion": 2,
  "world": { "width": 1536, "height": 2752 },
  "scale": 2,
  "base": { "tiles": [
    { "asset": "world/atlas_master", "x": 0, "y": 0, "width": 384, "height": 688 },
    { "asset": "world/atlas_master", "x": 384, "y": 0, "width": 384, "height": 688 },
    { "asset": "world/atlas_master", "x": 0, "y": 688, "width": 384, "height": 688 },
    { "asset": "world/atlas_master", "x": 384, "y": 688, "width": 384, "height": 688 }
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

/// The world the lead is about to ship: **one** 384 × 688 master painting at
/// `scale: 4` — a 1536 × 2752 world-pixel surface. Everything scale-derived
/// must move with it: floor 0.25, initial 0.5, max 1, and every overlay, prop
/// and landmark drawn at ×4. Places sit at least 400 world pixels apart on
/// their larger axis, which is what lets an 88-world-pixel hit radius (44 dp
/// at the 0.25 floor) grow without crowding.
const String _scale4World = '''
{
  "schemaVersion": 2,
  "world": { "width": 1536, "height": 2752 },
  "scale": 4,
  "base": { "tiles": [
    { "asset": "world/atlas_master", "x": 0, "y": 0, "width": 384, "height": 688 }
  ] },
  "locations": [
    { "id": "location.a", "x": 250, "y": 2300, "hitRadius": 44, "landmark": null },
    { "id": "location.b", "x": 700, "y": 1400, "hitRadius": 40, "landmark": null },
    { "id": "location.c", "x": 1300, "y": 400, "hitRadius": 40, "landmark": null },
    { "id": "location.d", "x": 300, "y": 1100, "hitRadius": 40, "landmark": null }
  ],
  "landmarks": [
    { "id": "landmark.watchtower", "name": "Ruined Watchtower",
      "x": 1000, "y": 900, "tier": "minor",
      "marker": { "asset": "world/marker_landmark", "width": 20, "height": 20,
                  "anchorX": 10, "anchorY": 10 } },
    { "id": "landmark.far_town", "name": "Far Town",
      "x": 1400, "y": 2600, "tier": "future" }
  ],
  "routes": [],
  "props": [
    { "asset": "env/prop_cairn", "x": 600, "y": 1600, "width": 32, "height": 40,
      "anchorX": 16, "anchorY": 38 }
  ],
  "overlays": [
    { "asset": "env/overlay_cloud_wisp", "x": 500, "y": 1000, "width": 96,
      "height": 48, "frames": 1, "frameMillis": 1000,
      "drift": { "x": 0, "y": 0 }, "opacity": 0.4 },
    { "asset": "env/overlay_cloud_shadow", "x": 100, "y": 900, "width": 96,
      "height": 48, "frames": 1, "frameMillis": 1000,
      "drift": { "x": 9, "y": 0 }, "opacity": 0.22 }
  ]
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

RegionPlace _place(
  String slug, {
  bool current = false,
  bool safe = false,
  String? name,
}) => RegionPlace(
  id: id(slug),
  displayName: name ?? slug.toUpperCase(),
  isCurrent: current,
  isSafe: safe,
  isUnlocked: true,
  stepCostFromHere: null,
  resourceCount: 0,
  terrain: Terrain.grassland,
  kind: LocationKind.wilds,
);

AtlasScene _scene({String layout = _bigWorld, String? bName}) =>
    AtlasScene.join(
      layout: AtlasLayout.parse(layout),
      places: <RegionPlace>[
        _place('a', current: true, safe: true),
        _place('b', name: bName),
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
      // 393 / 1536 is 0.256, below this scale's absolute floor, so the floor
      // wins and half the width is what a player surveys — the case the
      // milestone names for a wide world at scale 2.
      expect(state.minZoom, zooms2.absoluteFloor);
      expect(state.zoom, zooms2.initial);
    });

    testWidgets('lets a narrower world be seen whole, and no further', (
      WidgetTester tester,
    ) async {
      // A 500-wide world: 393 / 500 is 0.786, well above the absolute floor,
      // so the bottom of the range comes from the viewport fit — snapped
      // *down* onto the whole-device-pixel grid (sixths at dpr 3, scale 2) so
      // the world-framing zoom is also a crisp one. 4/6 shows all 500 world
      // pixels in a 393 dp window with room to spare; the next grid stop up,
      // 5/6, would not.
      final AtlasScene narrow = _scene(
        layout: _bigWorld.replaceFirst(
          '"world": { "width": 1536, "height": 2752 }',
          '"world": { "width": 500, "height": 2752 }',
        ),
      );
      final AtlasViewportState state = await pump(tester, scene: narrow);
      expect(state.minZoom, closeTo(4 / 6, 0.0001));
      expect(state.minZoom, greaterThan(zooms2.absoluteFloor));
      expect(393 / state.minZoom, greaterThanOrEqualTo(500));
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
      expect(state.zoom, zooms2.max);
      await _pinch(tester, 300, 40);
      expect(
        state.zoom,
        zooms2.absoluteFloor,
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
      expect(state.zoom, zooms2.absoluteFloor);

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
      // at both ends of the range rather than once at 1×. At the floor the
      // overview LOD hides the landmark captions entirely (that is its job),
      // so out there only the place names are on the surface to collide.
      //
      // What collides is the **plate**, not the bare text: the plate is the
      // painted rect a viewer sees, and it is strictly larger than the name
      // on it, so measuring it is the tighter assertion.
      final AtlasViewportState state = await pump(tester, scene: _scene());
      const List<String> places = <String>[
        'atlas-label:location.a',
        'atlas-label:location.b',
        'atlas-label:location.c',
        'atlas-label:location.d',
      ];
      const List<String> captions = <String>[
        'atlas-caption:landmark.watchtower',
        'atlas-caption:landmark.far_town',
      ];
      void check(String at, List<String> keys) {
        for (int i = 0; i < keys.length; i++) {
          final Rect a = tester.getRect(_plate(keys[i]));
          for (int j = i + 1; j < keys.length; j++) {
            expect(
              a.overlaps(tester.getRect(_plate(keys[j]))),
              isFalse,
              reason: '"${keys[i]}" and "${keys[j]}" collide at $at',
            );
          }
        }
      }

      check('1×', <String>[...places, ...captions]);
      await _pinch(tester, 300, 40);
      expect(state.zoom, zooms2.absoluteFloor);
      check('the zoom floor', places);
      for (final String caption in captions) {
        expect(
          find.byKey(ValueKey<String>(caption)),
          findsNothing,
          reason: 'the overview carries no landmark captions',
        );
      }
      await _pinch(tester, 100, 400);
      expect(state.zoom, zooms2.max);
      check('2×', <String>[...places, ...captions]);
    });

    testWidgets('a place name stays the size it was designed at, at any zoom', (
      WidgetTester tester,
    ) async {
      // The reason labels counter-scale: at the floor the world is drawn at
      // half size, and a name that scaled with it would be 5.5 dp type.
      final AtlasViewportState state = await pump(tester, scene: _scene());
      final double atOne = tester.getSize(find.text('A')).height;

      await _pinch(tester, 300, 60);
      expect(state.zoom, zooms2.absoluteFloor);
      expect(tester.getSize(find.text('A')).height, closeTo(atOne, 0.5));

      await _pinch(tester, 100, 400);
      expect(state.zoom, zooms2.max);
      expect(tester.getSize(find.text('A')).height, closeTo(atOne, 0.5));
    });

    testWidgets('a label plate hugs its name, never a fixed width', (
      WidgetTester tester,
    ) async {
      // The regression this pins: a fixed 184 dp plate, counter-scaled at the
      // survey floor, painted a bar half the world wide (device review). The
      // plate must take the width its own name needs — no more.
      const String longName = 'Stonefall Crossing';
      final AtlasViewportState state = await pump(
        tester,
        scene: _scene(bName: longName),
      );
      const String shortKey = 'atlas-label:location.a';
      const String longKey = 'atlas-label:location.b';

      final Rect shortPlate = tester.getRect(_plate(shortKey));
      final Rect longPlate = tester.getRect(_plate(longKey));
      // Two names of very different length take very different plates…
      expect(longPlate.width, greaterThan(shortPlate.width + 60));
      // …and a one-letter name sits in a tag, nowhere near the old 184 dp bar.
      expect(shortPlate.width, lessThan(40));

      // Neither name lost a glyph: the box each `Text` was given is at least
      // the width its string needs at full size — `AdaptiveText.fitsWithin`
      // is the same measurement the label itself makes, and the property that
      // actually fails when a fixed box clips (M-06).
      for (final (String key, String name) in <(String, String)>[
        (shortKey, 'A'),
        (longKey, longName),
      ]) {
        final Element element = tester.element(_labelText(key));
        final TextStyle painted = DefaultTextStyle.of(
          element,
        ).style.merge(tester.widget<Text>(_labelText(key)).style);
        expect(
          AdaptiveText.fitsWithin(
            name,
            painted,
            MediaQuery.textScalerOf(element),
            tester.getSize(_labelText(key)).width,
          ),
          isTrue,
          reason: '"$name" does not fit the box its plate gave it',
        );
      }

      // The plate counter-scales with its type: at the survey floor it holds
      // its on-screen size instead of swallowing half the world.
      await _pinch(tester, 300, 60);
      expect(state.zoom, zooms2.absoluteFloor);
      expect(
        tester.getRect(_plate(shortKey)).width,
        closeTo(shortPlate.width, 0.5),
      );
    });

    testWidgets('a landmark caption is narrower and fainter than a place '
        'label with the same name', (WidgetTester tester) async {
      // The two-tier hierarchy, asserted on the painted plate: for one and
      // the same string, the caption's lighter weight and tighter tracking
      // must yield a narrower plate, and its ink must be fainter.
      await pump(tester, scene: _scene(bName: 'Ruined Watchtower'));
      const String placeKey = 'atlas-label:location.b';
      const String captionKey = 'atlas-caption:landmark.watchtower';

      expect(
        tester.getRect(_plate(captionKey)).width,
        lessThan(tester.getRect(_plate(placeKey)).width),
      );

      double plateAlpha(String key) {
        final Container plate = tester.widget<Container>(_plate(key));
        return (plate.decoration! as BoxDecoration).color!.a;
      }

      expect(plateAlpha(captionKey), lessThan(plateAlpha(placeKey)));
    });
  });

  group('the zoom range derives from the layout scale', () {
    test('scale 2 — the shipped range, exactly', () {
      expect(zooms2.absoluteFloor, 0.5);
      expect(zooms2.initial, 1);
      expect(zooms2.max, 2);
      expect(zooms2.overviewBelow, zooms2.initial);
    });

    test('scale 4 — the master-painting range', () {
      expect(zooms4.absoluteFloor, 0.25);
      expect(zooms4.initial, 0.5);
      expect(zooms4.max, 1);
      expect(zooms4.overviewBelow, zooms4.initial);
    });

    test('the continuous floor is the larger of fit and absolute, capped', () {
      expect(zooms2.minFor(viewportWidth: 393, worldWidth: 1536), 0.5);
      expect(
        zooms2.minFor(viewportWidth: 393, worldWidth: 500),
        closeTo(393 / 500, 1e-12),
      );
      expect(zooms2.minFor(viewportWidth: 393, worldWidth: 100), zooms2.max);
      expect(
        zooms4.minFor(viewportWidth: 390, worldWidth: 1536),
        closeTo(390 / 1536, 1e-12),
      );
    });

    test('chrome counter-scales below 1 dp per world pixel, never above', () {
      expect(AtlasMarkerSpec.chromeScale(0.25), 4);
      expect(AtlasMarkerSpec.chromeScale(0.5), 2);
      expect(AtlasMarkerSpec.chromeScale(1), 1);
      expect(AtlasMarkerSpec.chromeScale(2), 1);
    });
  });

  group('the viewport over the scale-4 master painting', () {
    Future<AtlasViewportState> pump(
      WidgetTester tester, {
      required AtlasScene scene,
      double width = 390,
      double height = 700,
    }) async {
      // A real phone's window, not the harness's 800 × 600 default — the
      // 700 dp viewport below must actually get its 700 dp, or the framing
      // assertions would measure a silently shorter window.
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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

    Finder art(String contains) => find.byWidgetPredicate(
      (Widget w) => w is PixelAsset && w.assetPath.contains(contains),
    );

    testWidgets('derives floor, opening view and ceiling from the scale', (
      WidgetTester tester,
    ) async {
      final AtlasViewportState state = await pump(
        tester,
        scene: _scene(layout: _scale4World),
      );
      expect(
        state.zoom,
        zooms4.initial,
        reason: 'the screen opens at native ×2 — exactly the accepted reading',
      );
      expect(
        state.minZoom,
        zooms4.absoluteFloor,
        reason: '390 / 1536 snaps down onto the pixel grid to native ×1',
      );
      await _pinch(tester, 100, 400);
      expect(state.zoom, zooms4.max, reason: 'native ×4 and no further');
      await _pinch(tester, 300, 40);
      expect(state.zoom, zooms4.absoluteFloor);
    });

    testWidgets('frames the whole world inside a phone window at the floor', (
      WidgetTester tester,
    ) async {
      final AtlasScene scene = _scene(layout: _scale4World);
      final AtlasViewportState state = await pump(tester, scene: scene);
      await _pinch(tester, 300, 40);
      expect(state.zoom, zooms4.absoluteFloor);
      // The clamp centres a world smaller than the window on both axes, so
      // every edge of the 1536 × 2752 surface is inside the 390 × 700 window.
      expect(state.camera.dx, lessThanOrEqualTo(0));
      expect(
        state.camera.dx + 390 / state.zoom,
        greaterThanOrEqualTo(scene.worldWidth),
      );
      expect(state.camera.dy, lessThanOrEqualTo(0));
      expect(
        state.camera.dy + 700 / state.zoom,
        greaterThanOrEqualTo(scene.worldHeight),
      );
    });

    testWidgets('the overview hides landmark captions, marker art and props', (
      WidgetTester tester,
    ) async {
      final AtlasViewportState state = await pump(
        tester,
        scene: _scene(layout: _scale4World),
      );
      // The opening view sits exactly on the boundary, which is *near*:
      // everything draws, as it does today.
      expect(find.text('Ruined Watchtower'), findsOneWidget);
      expect(find.text('Far Town —'), findsOneWidget);
      expect(art('marker_landmark'), findsOneWidget);
      expect(art('prop_cairn'), findsOneWidget);

      await _pinch(tester, 300, 40);
      expect(state.zoom, lessThan(zooms4.overviewBelow));
      expect(find.text('Ruined Watchtower'), findsNothing);
      expect(find.text('Far Town —'), findsNothing);
      expect(art('marker_landmark'), findsNothing);
      expect(art('prop_cairn'), findsNothing);
      // The survey's vocabulary stays: every place name, and *here*.
      for (final String name in <String>['A', 'B', 'C', 'D']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.byType(AtlasPulse), findsOneWidget);

      await _pinch(tester, 100, 400);
      expect(state.zoom, greaterThanOrEqualTo(zooms4.overviewBelow));
      expect(find.text('Ruined Watchtower'), findsOneWidget);
      expect(art('prop_cairn'), findsOneWidget);
    });

    testWidgets('keeps every target at the 44 dp floor at 0.25, no overlap', (
      WidgetTester tester,
    ) async {
      final AtlasViewportState state = await pump(
        tester,
        scene: _scene(layout: _scale4World),
      );
      await _pinch(tester, 300, 40);
      expect(state.zoom, zooms4.absoluteFloor);
      const List<String> ids = <String>[
        'location.a',
        'location.b',
        'location.c',
        'location.d',
      ];
      for (int i = 0; i < ids.length; i++) {
        final Rect a = tester.getRect(_hit(ids[i]));
        expect(a.width, greaterThanOrEqualTo(44), reason: ids[i]);
        expect(a.height, greaterThanOrEqualTo(44), reason: ids[i]);
        for (int j = i + 1; j < ids.length; j++) {
          expect(
            a.overlaps(tester.getRect(_hit(ids[j]))),
            isFalse,
            reason: '${ids[i]} and ${ids[j]} share thumb space at the floor',
          );
        }
      }
    });

    testWidgets('the here-marker and route dots counter-scale at the floor', (
      WidgetTester tester,
    ) async {
      final AtlasViewportState state = await pump(
        tester,
        scene: _scene(layout: _scale4World),
      );
      await _pinch(tester, 300, 40);
      expect(state.zoom, zooms4.absoluteFloor);

      // The pulse is visually scaled by the chrome factor about its own
      // centre, so *here* reads at its authored dp size while its anchor
      // stays the place's world coordinate.
      final Transform scaled = tester.widget<Transform>(
        find
            .ancestor(
              of: find.byType(AtlasPulse),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(
        scaled.transform.getMaxScaleOnAxis(),
        closeTo(AtlasMarkerSpec.chromeScale(state.zoom), 1e-9),
      );
      final Offset pulse = tester.getCenter(find.byType(AtlasPulse));
      final Offset here = tester.getCenter(_hit('location.a'));
      expect((pulse - here).distance, lessThan(1));

      // And the route layer is fed the live zoom, which is what its painter
      // derives the dot chrome from.
      expect(
        tester.widget<AtlasRouteLayer>(find.byType(AtlasRouteLayer)).zoom,
        state.zoom,
      );
    });

    testWidgets('overlays and props stand at world coordinates at scale 4', (
      WidgetTester tester,
    ) async {
      await pump(tester, scene: _scene(layout: _scale4World));
      Positioned pos(Finder f) => tester.widget<Positioned>(
        find.ancestor(of: f, matching: find.byType(Positioned)).first,
      );

      // A still overlay sits exactly where the layout says, and draws at ×4 —
      // twice its scale-2 size, which is correct: the whole world doubled.
      final Positioned still = pos(art('overlay_cloud_wisp'));
      expect(still.left, 500);
      expect(still.top, 1000);
      expect(tester.getSize(art('overlay_cloud_wisp')), const Size(384, 192));

      // A drifting overlay's wrap domain is world pixels wide: it may sit up
      // to its own scaled width off the west edge, and never off the east.
      final Positioned drifting = pos(art('overlay_cloud_shadow'));
      expect(drifting.left, greaterThanOrEqualTo(-96.0 * 4));
      expect(drifting.left, lessThan(1536));

      // A prop stands with its anchor pixel on the coordinate, scaled ×4.
      final Positioned cairn = pos(art('prop_cairn'));
      expect(cairn.left, 600 - 16 * 4);
      expect(cairn.top, 1600 - 38 * 4);
      expect(tester.getSize(art('prop_cairn')), const Size(128, 160));
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

/// The painted plate behind one label — the `Container` inside the keyed
/// label widget. Its rect is what a viewer sees covering geography, so the
/// collision and geometry tests below measure it rather than the bare text.
Finder _plate(String key) => find.descendant(
  of: find.byKey(ValueKey<String>(key)),
  matching: find.byType(Container),
);

/// The label's `Text`, for measuring the box the name was actually given.
Finder _labelText(String key) => find.descendant(
  of: find.byKey(ValueKey<String>(key)),
  matching: find.byType(Text),
);

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
