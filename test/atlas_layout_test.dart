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
library;

import 'dart:io';
import 'dart:ui' show Rect;

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

    test('no overlay sits on, or sweeps across, a landmark', () {
      // OD-05: animation must never obscure a destination. Overlays paint
      // *above* the landmark layer (markers and labels sit above overlays, so
      // they are safe by z-order), which makes this the one thing the layout
      // itself has to keep true. Device review found the forest mist parked
      // on the Forgotten Hollow's ruin and a cloud sweeping the mine's base.
      final AtlasLayout layout = AtlasLayout.parse(shippedLayout);
      final int scale = layout.scale;
      final List<(String, Rect)> landmarks = <(String, Rect)>[
        for (final AtlasLocation location in layout.locations)
          if (location.landmark case final AtlasLandmark landmark)
            (
              location.id.value,
              Rect.fromLTWH(
                location.x - landmark.anchorX * scale,
                location.y - landmark.anchorY * scale,
                (landmark.width * scale).toDouble(),
                (landmark.height * scale).toDouble(),
              ),
            ),
      ];
      expect(landmarks, isNotEmpty);
      for (final AtlasOverlay overlay in layout.overlays) {
        // A drifting overlay wraps across the whole axis it drifts on, so it
        // passes over everything in its band.
        final Rect swept = Rect.fromLTWH(
          overlay.driftX != 0 ? 0 : overlay.x,
          overlay.driftY != 0 ? 0 : overlay.y,
          overlay.driftX != 0
              ? layout.worldWidth.toDouble()
              : (overlay.width * scale).toDouble(),
          overlay.driftY != 0
              ? layout.worldHeight.toDouble()
              : (overlay.height * scale).toDouble(),
        );
        for (final (String id, Rect landmark) in landmarks) {
          expect(
            swept.overlaps(landmark),
            isFalse,
            reason:
                '${overlay.asset} at (${overlay.x}, ${overlay.y}) would '
                'obscure the landmark of $id',
          );
        }
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

  group('the reader', () {
    test('refuses another schema version', () {
      expect(
        () => AtlasLayout.parse('{"schemaVersion": 2}'),
        throwsA(isA<AtlasLayoutException>()),
      );
    });

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
        '"hitRadius": 40',
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

/// A bundle with nothing in it, so the loader's "not declared" path runs.
class _EmptyBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('Unable to load asset: $key');

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      throw FlutterError('Unable to load asset: $key');
}
