/// The World Atlas layout asset, and the reader that refuses to guess at it.
///
/// ## The risks these cover, named before the work
///
/// - **A place with nowhere to stand.** `locations.json` gains a location and
///   `atlas_layout.json` does not: the atlas would draw four of five places and
///   the fifth would be reachable by travel and invisible on the map. Caught by
///   `validateAgainst` against the *shipped* content, not a fixture.
/// - **A coordinate off the surface, or a target too small to tap.** Both are
///   silent at runtime — a marker outside the world is clipped, a 10 px target
///   simply misses — so they are refused at load.
/// - **A structural fault reported as a partial layout.** `parse` throws and
///   names the field; it never returns a layout missing a list.
/// - **A schema bump that silently drops data.** v2 adds `landmarks` and
///   `kindMarkers`; a v1 document must still parse (there is one in the field —
///   the shipped file until this milestone), and a v1 document *carrying* the
///   v2 blocks must be refused rather than read with them thrown away.
/// - **A landmark that is really a place.** A landmark has no hit target and no
///   panel, so one that duplicates a location id, or a second landmark's id, is
///   a place drawn twice with only one way in.
library;

import 'dart:convert' show JsonEncoder, jsonDecode;
import 'dart:io';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart' show AssetBundle, ByteData;
import 'package:flutter_test/flutter_test.dart';
import 'package:stride/runtime/atlas_layout.dart';
import 'package:stride_core/stride_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The shipped content pack's locations, read the way `stride_core` reads
  /// them, so the assertion is against what the game will actually load.
  late List<ContentId> contentLocations;
  late String shippedLayout;
  late String bareLayout;

  setUpAll(() {
    final ContentLoadResult result = const ContentLoader().load(
      ContentSource(<String, String>{
        for (final FileSystemEntity entity in Directory(
          'assets/content/v1',
        ).listSync())
          if (entity is File && entity.path.endsWith('.json'))
            entity.uri.pathSegments.last: entity.readAsStringSync(),
      }),
      profileId: BalanceProfile.productionId,
    );
    contentLocations = result.registry!.locations.keys.toList();
    shippedLayout = File(
      'assets/content/v1/atlas/atlas_layout.json',
    ).readAsStringSync();
    // The shipped world with its landmarks and glyph table removed: the
    // schema cases below drop their own entries into an empty `landmarks`
    // list against the real world size, ids and validator.
    final Map<String, Object?> bare =
        (jsonDecode(shippedLayout) as Map<String, Object?>)
          ..['landmarks'] = <Object?>[]
          ..remove('kindMarkers');
    bareLayout = const JsonEncoder.withIndent('  ').convert(bare);
  });

  group('the shipped layout', () {
    test('parses, and is declared in the asset bundle', () async {
      final AtlasLayout layout = AtlasLayout.parse(shippedLayout);
      expect(layout.worldWidth, greaterThan(0));
      expect(layout.worldHeight, greaterThan(0));
      expect(layout.tiles, isNotEmpty);

      // The same bytes through the bundle — which is what proves the
      // pubspec line exists. A layout on disk that is not declared is one the
      // app cannot see.
      final AtlasLayout fromBundle = await loadAtlasLayoutFromAssets();
      expect(fromBundle.locations.length, layout.locations.length);
    });

    test('gives every content location a coordinate, and nothing else', () {
      final AtlasLayout layout = AtlasLayout.parse(shippedLayout);
      expect(contentLocations, isNotEmpty);
      expect(
        layout.validateAgainst(contentLocations),
        isEmpty,
        reason: 'every problem here is one the World screen would hide',
      );
      // Both directions: the atlas names no place the content lacks.
      expect(layout.locations.length, contentLocations.length);
    });

    test(
      'keeps every coordinate inside the world and every target tappable',
      () {
        final AtlasLayout layout = AtlasLayout.parse(shippedLayout);
        for (final AtlasLocation location in layout.locations) {
          expect(location.x, inInclusiveRange(0, layout.worldWidth));
          expect(location.y, inInclusiveRange(0, layout.worldHeight));
          // 44 dp diameter at zoom 1 is the accessibility floor; the layout
          // carries a radius, so the floor is 22.
          expect(
            location.hitRadius,
            greaterThanOrEqualTo(AtlasLayout.minimumHitRadius),
          );
          expect(
            location.hitRadius,
            lessThanOrEqualTo(AtlasLayout.maximumHitRadius),
          );
        }
      },
    );

    test('the painted master carries no landmark cutouts to obscure', () {
      // OD-05: animation must never obscure a destination. Overlays paint
      // above the landmark-art layer, and the old base+south world placed
      // per-location cutouts there, so this test used to sweep every
      // drifting overlay against every cutout's box. The master painting
      // (Activity Feel 01) draws every settlement and ruin into the base
      // itself, below the overlays and below nothing that can be obscured;
      // markers and labels sit above overlays by z-order as before. Asserted
      // so that if a cutout ever returns to the shipped layout, this test
      // fails and the overlay-sweep rule it replaced is revived with it
      // (see git history).
      final AtlasLayout layout = AtlasLayout.parse(shippedLayout);
      expect(layout.overlays, isNotEmpty);
      for (final AtlasLocation location in layout.locations) {
        expect(
          location.landmark,
          isNull,
          reason:
              '${location.id.value} carries landmark art: restore the '
              'overlay-sweep assertion this test replaced',
        );
      }
    });

    test('the base tiles cover the world at the declared scale', () {
      final AtlasLayout layout = AtlasLayout.parse(shippedLayout);
      int right = 0;
      int bottom = 0;
      for (final AtlasTile tile in layout.tiles) {
        right = (tile.x + tile.width) * layout.scale > right
            ? (tile.x + tile.width) * layout.scale
            : right;
        bottom = (tile.y + tile.height) * layout.scale > bottom
            ? (tile.y + tile.height) * layout.scale
            : bottom;
      }
      expect(
        right,
        layout.worldWidth,
        reason: 'no unpainted strip on the right',
      );
      expect(bottom, layout.worldHeight, reason: 'no unpainted strip below');
    });
  });

  group('the schema', () {
    /// The shipped document with its version reset and the v2 blocks removed —
    /// which is exactly what the file was before this milestone.
    String asV1() => bareLayout
        .replaceFirst('"schemaVersion": 2', '"schemaVersion": 1')
        .replaceFirst('"landmarks": [],\n', '');

    test('ships at the current version', () {
      expect(AtlasLayout.parse(shippedLayout).schemaVersion, 2);
      expect(atlasLayoutSchemaVersion, 2);
    });

    test('still reads a v1 document, with no landmarks', () {
      final AtlasLayout v1 = AtlasLayout.parse(asV1());
      expect(v1.schemaVersion, 1);
      expect(v1.landmarks, isEmpty);
      expect(v1.kindMarkers, isEmpty);
      // Everything else is unchanged: the two versions describe one world.
      final AtlasLayout v2 = AtlasLayout.parse(shippedLayout);
      expect(v1.locations.length, v2.locations.length);
      expect(v1.worldWidth, v2.worldWidth);
      expect(v1.routes.length, v2.routes.length);
    });

    test('refuses v1 carrying v2 blocks rather than dropping them', () {
      final String lying = bareLayout.replaceFirst(
        '"schemaVersion": 2',
        '"schemaVersion": 1',
      );
      expect(
        () => AtlasLayout.parse(lying),
        throwsA(
          isA<AtlasLayoutException>().having(
            (AtlasLayoutException e) => e.message,
            'message',
            contains('schemaVersion 2'),
          ),
        ),
      );
    });

    test('refuses a version it has never heard of', () {
      for (final String version in <String>['0', '3', '99']) {
        expect(
          () => AtlasLayout.parse('{"schemaVersion": $version}'),
          throwsA(isA<AtlasLayoutException>()),
          reason: version,
        );
      }
    });

    test('reads landmarks, their tier and their optional art', () {
      final AtlasLayout layout = AtlasLayout.parse(
        _withLandmarks(bareLayout, '''
          { "id": "landmark.ruined_watchtower", "name": "Ruined Watchtower",
            "x": 700, "y": 900, "tier": "minor",
            "marker": { "asset": "world/landmark_watchtower", "width": 48,
                        "height": 48, "anchorX": 24, "anchorY": 46 } },
          { "id": "landmark.far_town", "name": "Far Town",
            "x": 80, "y": 60, "tier": "future" }
        '''),
      );
      expect(layout.landmarks, hasLength(2));
      expect(layout.landmarks.first.name, 'Ruined Watchtower');
      expect(layout.landmarks.first.tier, AtlasLandmarkTier.minor);
      expect(layout.landmarks.first.marker?.anchorY, 46);
      expect(layout.landmarks.last.tier, AtlasLandmarkTier.future);
      expect(layout.landmarks.last.marker, isNull);
      expect(layout.validateAgainst(contentLocations), isEmpty);
    });

    test('refuses a tier it cannot draw', () {
      expect(
        () => AtlasLayout.parse(
          _withLandmarks(bareLayout, '''
            { "id": "landmark.x", "name": "X", "x": 10, "y": 10,
              "tier": "major" }
          '''),
        ),
        throwsA(
          isA<AtlasLayoutException>().having(
            (AtlasLayoutException e) => e.message,
            'message',
            contains('landmarks[0].tier'),
          ),
        ),
      );
    });

    test('refuses a landmark with no name to draw', () {
      expect(
        () => AtlasLayout.parse(
          _withLandmarks(bareLayout, '''
            { "id": "landmark.x", "name": "", "x": 10, "y": 10,
              "tier": "minor" }
          '''),
        ),
        throwsA(isA<AtlasLayoutException>()),
      );
    });

    test('reports a duplicate landmark id, and one stolen from a place', () {
      final AtlasLayout layout = AtlasLayout.parse(
        _withLandmarks(bareLayout, '''
          { "id": "landmark.x", "name": "X", "x": 10, "y": 10, "tier": "minor" },
          { "id": "landmark.x", "name": "X again", "x": 20, "y": 20, "tier": "minor" },
          { "id": "location.frostmere", "name": "Not Frostmere", "x": 30, "y": 30,
            "tier": "minor" }
        '''),
      );
      final List<String> problems = layout.validateAgainst(contentLocations);
      expect(problems, hasLength(2));
      expect(problems.first, contains('more than once'));
      expect(problems.last, contains('location.frostmere'));
    });

    test('reports a landmark that lies off the surface', () {
      final AtlasLayout layout = AtlasLayout.parse(
        _withLandmarks(bareLayout, '''
          { "id": "landmark.x", "name": "X", "x": 99999, "y": 10,
            "tier": "minor" }
        '''),
      );
      expect(
        layout.validateAgainst(contentLocations).single,
        contains('outside the'),
      );
    });

    test('refuses a marker glyph for a kind that does not exist', () {
      final String bad = bareLayout.replaceFirst(
        '"landmarks": [],',
        '"landmarks": [], "kindMarkers": { "hamlet": '
            '{ "asset": "world/marker_hamlet", "width": 16, "height": 16, '
            '"anchorX": 8, "anchorY": 8 } },',
      );
      expect(
        () => AtlasLayout.parse(bad),
        throwsA(
          isA<AtlasLayoutException>().having(
            (AtlasLayoutException e) => e.message,
            'message',
            contains('kindMarkers.hamlet'),
          ),
        ),
      );
    });

    test('reads the five marker glyph slots when they are declared', () {
      final String withGlyphs = bareLayout.replaceFirst(
        '"landmarks": [],',
        '"landmarks": [], "kindMarkers": {'
            '${atlasMarkerKinds.map((String k) => '"$k": {"asset": "world/marker_$k", '
                '"width": 16, "height": 16, "anchorX": 8, "anchorY": 8}').join(',')}},',
      );
      final AtlasLayout layout = AtlasLayout.parse(withGlyphs);
      expect(layout.kindMarkers, hasLength(atlasMarkerKinds.length));
      expect(layout.markerForKind('worksite')?.asset, 'world/marker_worksite');
      expect(layout.markerForKind('hamlet'), isNull);
    });

    test('ships the five glyphs, four landmarks and the one master world', () {
      // Activity Feel & Presentation 01: the base + south tile column is
      // retired for ONE master painting at scale 4 — 1536 × 2752 world px,
      // no tile joins to fail a blind read (`MISTAKES.md` M-12). The device
      // correction pass re-authored the painting as a continent whose
      // inhabited region is a modest north-eastern slice; the Broken Tower
      // landmark retired with the old moor (the continent paints one tower,
      // Old Watch), leaving four: Millbridge, Old Watch, Ferry Crossing and
      // the future-tier Far Town. Asserted so removing a glyph, the tile or
      // a landmark is a deliberate edit here too.
      final AtlasLayout layout = AtlasLayout.parse(shippedLayout);
      expect(layout.kindMarkers.keys, unorderedEquals(atlasMarkerKinds));
      expect(layout.tiles, hasLength(1));
      expect(layout.scale, 4);
      expect(layout.worldWidth, 1536);
      expect(layout.worldHeight, 2752);
      expect(layout.landmarks, hasLength(4));
      expect(
        layout.landmarks.where(
          (AtlasNamedLandmark l) => l.tier == AtlasLandmarkTier.future,
        ),
        hasLength(1),
      );
      expect(layout.validateAgainst(contentLocations), isEmpty);
    });
  });

  group('the reader', () {
    test('refuses a location that is not a content id, naming the field', () {
      final String bad = shippedLayout.replaceFirst(
        '"location.havens_rest"',
        '"Havens Rest"',
      );
      expect(
        () => AtlasLayout.parse(bad),
        throwsA(
          isA<AtlasLayoutException>().having(
            (AtlasLayoutException e) => e.message,
            'message',
            contains('locations[0].id'),
          ),
        ),
      );
    });

    test('refuses a duplicate location rather than drawing it twice', () {
      final String dupe = shippedLayout.replaceFirst(
        '"location.frostmere"',
        '"location.havens_rest"',
      );
      expect(
        () => AtlasLayout.parse(dupe),
        throwsA(isA<AtlasLayoutException>()),
      );
    });

    test('reports a missing content location as a problem, not a crash', () {
      final AtlasLayout layout = AtlasLayout.parse(shippedLayout);
      final List<String> problems = layout.validateAgainst(<ContentId>[
        ...contentLocations,
        ContentId.unchecked('location.somewhere_new'),
      ]);
      expect(problems, hasLength(1));
      expect(problems.single, contains('location.somewhere_new'));
    });

    test('reports a target under the accessibility floor', () {
      final String small = shippedLayout.replaceFirst(
        '"hitRadius": 48',
        '"hitRadius": 10',
      );
      final AtlasLayout layout = AtlasLayout.parse(small);
      expect(
        layout.validateAgainst(contentLocations).single,
        contains('hit radius'),
      );
    });

    test('a missing asset is a typed error naming the bundle', () async {
      expect(
        () => loadAtlasLayoutFromAssets(bundle: _EmptyBundle()),
        throwsA(isA<AtlasLayoutException>()),
      );
    });
  });
}

/// The shipped document with [entries] dropped into its empty `landmarks`
/// list. Written this way so every landmark case is tested against the real
/// world size, the real location ids and the real validator — a hand-built
/// fixture would prove the parser reads a fixture.
String _withLandmarks(String layout, String entries) =>
    layout.replaceFirst('"landmarks": [],', '"landmarks": [$entries],');

/// A bundle with nothing in it, so the loader's "not declared" path runs.
class _EmptyBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('Unable to load asset: $key');

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      throw FlutterError('Unable to load asset: $key');
}
