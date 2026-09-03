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
///   `kindMarkers`; v3 adds `rumors` (Exploration & Progression Loop 01). A
///   v1 document must still parse (there was one in the field — the shipped
///   file two milestones ago), and a document *carrying* a later version's
///   blocks under an earlier version must be refused rather than read with
///   them thrown away.
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
import 'package:stride/ui/icons/atlas_assets.dart';
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
    // list against the real world size, ids and validator. The v4 and v5
    // overlay fields are stripped too, so the versions the cases rewind to
    // stay honest documents of their own era.
    final Map<String, Object?> bare =
        (jsonDecode(shippedLayout) as Map<String, Object?>)
          ..['landmarks'] = <Object?>[]
          ..remove('kindMarkers')
          ..remove('rumors');
    for (final Object? overlay in bare['overlays']! as List<Object?>) {
      (overlay! as Map<String, Object?>)
        ..remove('intervalMillis')
        ..remove('travel')
        ..remove('playLoops')
        // The v6 behaviour fields go too, and a path overlay's derived
        // placement fields come back, so a rewound document is an honest
        // document of its own era rather than a v6 file wearing an old number.
        ..remove('path')
        ..remove('breath')
        ..remove('cloud')
        ..remove('shadow')
        ..remove('depth')
        ..remove('faces')
        ..putIfAbsent('x', () => 0)
        ..putIfAbsent('y', () => 0)
        ..putIfAbsent('drift', () => <String, Object?>{'x': 0, 'y': 0});
    }
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

    test('every asset the layout names is packaged at its declared size', () {
      // The risk, seen live in World Map Polish 01's re-anchor: the layout is
      // data and the PNGs are packaging, and nothing held them together — an
      // overlay could name six frames of a sequence whose files were never
      // emitted, or declare 64 × 64 over a 32 × 32 file, and the failure would
      // be a blank flicker on the device rather than anything a suite catches.
      // Every reference the layout can make is walked here: base tiles,
      // location landmarks, named-landmark art, kind glyphs, props, and every
      // frame of every overlay, each asserted present with the IHDR size the
      // layout declares.
      final AtlasLayout layout = AtlasLayout.parse(shippedLayout);

      void expectPng(String path, int width, int height, String owner) {
        final File file = File(path);
        expect(
          file.existsSync(),
          isTrue,
          reason: '$owner names $path, which is not packaged',
        );
        final List<int> header = file.readAsBytesSync().sublist(16, 24);
        int be(int offset) =>
            (header[offset] << 24) |
            (header[offset + 1] << 16) |
            (header[offset + 2] << 8) |
            header[offset + 3];
        expect(
          '${be(0)}x${be(4)}',
          '${width}x$height',
          reason: '$owner declares ${width}x$height for $path',
        );
      }

      for (final AtlasTile tile in layout.tiles) {
        expectPng(
          AtlasAssets.pathFor(tile.asset),
          tile.width,
          tile.height,
          'tile',
        );
      }
      for (final AtlasLocation location in layout.locations) {
        if (location.landmark case final AtlasLandmark art) {
          expectPng(
            AtlasAssets.pathFor(art.asset),
            art.width,
            art.height,
            location.id.value,
          );
        }
      }
      for (final AtlasNamedLandmark landmark in layout.landmarks) {
        if (landmark.marker case final AtlasLandmark art) {
          expectPng(
            AtlasAssets.pathFor(art.asset),
            art.width,
            art.height,
            landmark.id,
          );
        }
      }
      for (final MapEntry<String, AtlasLandmark> entry
          in layout.kindMarkers.entries) {
        expectPng(
          AtlasAssets.pathFor(entry.value.asset),
          entry.value.width,
          entry.value.height,
          'kindMarkers.${entry.key}',
        );
      }
      for (final AtlasProp prop in layout.props) {
        expectPng(
          AtlasAssets.pathFor(prop.asset),
          prop.width,
          prop.height,
          'prop',
        );
      }
      for (final AtlasOverlay overlay in layout.overlays) {
        for (final String path in AtlasAssets.framePaths(
          overlay.asset,
          overlay.frameCount,
        )) {
          expectPng(path, overlay.width, overlay.height, overlay.asset);
        }
      }
    });
  });

  group('the schema', () {
    /// The shipped document with its version reset and the later blocks
    /// removed — which is exactly what the file was in earlier milestones.
    String asV1() => bareLayout
        .replaceFirst('"schemaVersion": 6', '"schemaVersion": 1')
        .replaceFirst('"landmarks": [],\n', '');

    test('ships at the current version', () {
      expect(AtlasLayout.parse(shippedLayout).schemaVersion, 6);
      expect(atlasLayoutSchemaVersion, 6);
    });

    test('still reads a v1 document, with no landmarks and no rumors', () {
      final AtlasLayout v1 = AtlasLayout.parse(asV1());
      expect(v1.schemaVersion, 1);
      expect(v1.landmarks, isEmpty);
      expect(v1.kindMarkers, isEmpty);
      expect(v1.rumors, isEmpty);
      // Everything else is unchanged: the two versions describe one world.
      final AtlasLayout current = AtlasLayout.parse(shippedLayout);
      expect(v1.locations.length, current.locations.length);
      expect(v1.worldWidth, current.worldWidth);
      expect(v1.routes.length, current.routes.length);
    });

    test('refuses v1 carrying v2 blocks rather than dropping them', () {
      final String lying = bareLayout.replaceFirst(
        '"schemaVersion": 6',
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

    test('refuses v2 carrying the rumors block rather than dropping it', () {
      // The shipped document has real rumors; only its version lies.
      final String lying = shippedLayout.replaceFirst(
        '"schemaVersion": 6',
        '"schemaVersion": 2',
      );
      expect(
        () => AtlasLayout.parse(lying),
        throwsA(
          isA<AtlasLayoutException>().having(
            (AtlasLayoutException e) => e.message,
            'message',
            contains('schemaVersion 3'),
          ),
        ),
      );
    });

    test('refuses a version it has never heard of', () {
      for (final String version in <String>['0', '6', '99']) {
        expect(
          () => AtlasLayout.parse('{"schemaVersion": $version}'),
          throwsA(isA<AtlasLayoutException>()),
          reason: version,
        );
      }
    });

    test('refuses pre-v4 overlays carrying intervalMillis', () {
      // A v3 reader would play the loop continuously — dropped behaviour is
      // refused exactly as dropped data is.
      final String lying = bareLayout
          .replaceFirst('"schemaVersion": 6', '"schemaVersion": 3')
          .replaceFirst('"frames": 8,', '"frames": 8, "intervalMillis": 9000,');
      expect(
        () => AtlasLayout.parse(lying),
        throwsA(
          isA<AtlasLayoutException>().having(
            (AtlasLayoutException e) => e.message,
            'message',
            contains('schemaVersion 4'),
          ),
        ),
      );
    });

    test('refuses a negative interval', () {
      final String bad = bareLayout.replaceFirst(
        '"frames": 8,',
        '"frames": 8, "intervalMillis": -1,',
      );
      expect(
        () => AtlasLayout.parse(bad),
        throwsA(
          isA<AtlasLayoutException>().having(
            (AtlasLayoutException e) => e.message,
            'message',
            contains('intervalMillis'),
          ),
        ),
      );
    });

    test('an intermittent overlay opens quiet, plays whole, and repeats', () {
      // 4 frames × 250 ms after a 2 s gap: a 3 s cycle whose first two
      // seconds draw nothing. The gap comes FIRST so a clock that never
      // advances — the test harness, reduced motion, the background — shows
      // no creature at all rather than one frozen mid-appearance.
      const AtlasOverlay egg = AtlasOverlay(
        asset: 'env/overlay_egg',
        x: 0,
        y: 0,
        width: 32,
        height: 32,
        frameCount: 4,
        frameMillis: 250,
        driftX: 0,
        driftY: 0,
        intervalMillis: 2000,
      );
      expect(egg.cycleMillis, 3000);
      expect(egg.visibleAt(Duration.zero), isFalse);
      expect(egg.visibleAt(const Duration(milliseconds: 1999)), isFalse);
      expect(egg.visibleAt(const Duration(milliseconds: 2000)), isTrue);
      expect(egg.frameIndexAt(const Duration(milliseconds: 2000)), 0);
      expect(egg.frameIndexAt(const Duration(milliseconds: 2750)), 3);
      // The next cycle: quiet again, then frame 0 again — the rise always
      // plays from its first frame.
      expect(egg.visibleAt(const Duration(milliseconds: 3000)), isFalse);
      expect(egg.visibleAt(const Duration(milliseconds: 5000)), isTrue);
      expect(egg.frameIndexAt(const Duration(milliseconds: 5000)), 0);

      // interval 0 is the continuous loop, cadence unchanged.
      const AtlasOverlay loop = AtlasOverlay(
        asset: 'env/overlay_loop',
        x: 0,
        y: 0,
        width: 32,
        height: 32,
        frameCount: 4,
        frameMillis: 250,
        driftX: 0,
        driftY: 0,
      );
      for (final int t in <int>[0, 249, 250, 999, 1000, 1250]) {
        final Duration at = Duration(milliseconds: t);
        expect(loop.visibleAt(at), isTrue, reason: '$t');
        expect(loop.frameIndexAt(at), t ~/ 250 % 4, reason: '$t');
      }
    });

    test('refuses pre-v5 overlays carrying travel', () {
      // A v4 reader would pin the travelling sprite to its origin — dropped
      // motion, refused exactly as dropped data is.
      final String lying = shippedLayout
          .replaceFirst('"schemaVersion": 6', '"schemaVersion": 4')
          .replaceFirst(
            '"intervalMillis": 14000,',
            '"intervalMillis": 14000, "travel": { "x": -12, "y": 0 },',
          );
      expect(
        () => AtlasLayout.parse(lying),
        throwsA(
          isA<AtlasLayoutException>().having(
            (AtlasLayoutException e) => e.message,
            'message',
            contains('schemaVersion 5'),
          ),
        ),
      );
    });

    test('refuses travel on a continuous loop, and travel beside drift', () {
      // Travel is measured from the start of a play; a continuous loop has
      // no play boundary, so the combination is meaningless and refused.
      final String continuous = bareLayout.replaceFirst(
        '"frames": 8,',
        '"frames": 8, "travel": { "x": -12, "y": 0 },',
      );
      expect(
        () => AtlasLayout.parse(continuous),
        throwsA(
          isA<AtlasLayoutException>().having(
            (AtlasLayoutException e) => e.message,
            'message',
            contains('intervalMillis'),
          ),
        ),
      );
      // One sprite, one kind of motion: drift wraps forever, travel resets
      // each play — both at once is two owners for one position.
      // Anchored on the snowdrift, the last drifting overlay in the shipped
      // document: EPO03 deleted the two drifting bird rows this case used to
      // rewrite, and a `replaceFirst` that silently matches nothing would
      // turn this into a test of the unmodified file (which the `isNot`
      // below is here to catch).
      final String both = shippedLayout.replaceFirst(
        '"drift": {\n        "x": 6,\n        "y": 0\n      },',
        '"drift": { "x": 6, "y": 0 }, '
            '"intervalMillis": 9000, "travel": { "x": -12, "y": 0 },',
      );
      expect(both, isNot(shippedLayout), reason: 'the rewrite must land');
      expect(
        () => AtlasLayout.parse(both),
        throwsA(
          isA<AtlasLayoutException>().having(
            (AtlasLayoutException e) => e.message,
            'message',
            contains('travel and drift'),
          ),
        ),
      );
    });

    test('a travelling overlay journeys during its play and resets', () {
      // 4 frames × 250 ms after a 2 s gap, moving west 12 world px/s: the
      // sprite stands at its origin through the whole gap, retraces the same
      // 12-px journey during each 1 s play, and starts over from the origin.
      const AtlasOverlay serpent = AtlasOverlay(
        asset: 'env/overlay_serpent',
        x: 100,
        y: 50,
        width: 32,
        height: 32,
        frameCount: 4,
        frameMillis: 250,
        driftX: 0,
        driftY: 0,
        intervalMillis: 2000,
        travelX: -12,
      );
      expect(serpent.playMillisAt(Duration.zero), 0);
      expect(serpent.playMillisAt(const Duration(milliseconds: 1999)), 0);
      expect(serpent.playMillisAt(const Duration(milliseconds: 2000)), 0);
      expect(serpent.playMillisAt(const Duration(milliseconds: 2500)), 500);
      expect(serpent.playMillisAt(const Duration(milliseconds: 2999)), 999);
      // The next cycle: the journey has reset with the play.
      expect(serpent.playMillisAt(const Duration(milliseconds: 3000)), 0);
      expect(serpent.playMillisAt(const Duration(milliseconds: 5100)), 100);

      // playLoops stretches the play: the same four frames run three times
      // over — frameIndexAt's modulo wraps them — before the gap returns.
      const AtlasOverlay dragon = AtlasOverlay(
        asset: 'env/overlay_dragon',
        x: 0,
        y: 0,
        width: 32,
        height: 32,
        frameCount: 4,
        frameMillis: 250,
        driftX: 0,
        driftY: 0,
        intervalMillis: 2000,
        travelX: 30,
        playLoops: 3,
      );
      expect(dragon.activeMillis, 3000);
      expect(dragon.cycleMillis, 5000);
      expect(dragon.visibleAt(const Duration(milliseconds: 1999)), isFalse);
      expect(dragon.visibleAt(const Duration(milliseconds: 4900)), isTrue);
      // Second pass through the loop, still inside one play.
      expect(dragon.frameIndexAt(const Duration(milliseconds: 3100)), 0);
      expect(dragon.playMillisAt(const Duration(milliseconds: 4900)), 2900);
      expect(dragon.visibleAt(const Duration(milliseconds: 5000)), isFalse);
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

    test('ships the five glyphs, the far tier and the one composed world', () {
      // World Map Expansion Refinement 02: the owner's second scale-up. The
      // accepted 512 × 512 master painting is byte-preserved at the centre
      // of ONE composed 1024 × 1024 base — WMP03's inner frontier ring
      // (seam-corrected this round) inside a second ring of twelve pieces,
      // dither-crossfaded at every join by the packaging step — so the world
      // is 6144 × 6144 world px at scale 6, with a caravan corridor opening
      // the west. Still one tile at runtime: the composition happens in
      // `package-art.js`, where the seam treatment is recorded and
      // reproducible (M-12's stacked screenshots were untreated butt joins
      // of unrelated generations).
      //
      // Twenty-three landmarks stand. Two are minor captions (Millbridge,
      // Ferry Crossing) and twenty-one are **future** tier — places the
      // roads point at and do not reach. This round retired Outer Shoal
      // (four names stacked in one south-east column on the device) and
      // added three frontier names (Wayfarer's Pass, The White Reach, The
      // Far Isles). The tier is the classification the brief asked for: the
      // atlas draws it quieter, suffixes it, gives it no hit target and
      // keeps the whole layer inside an `IgnorePointer`, so a promise
      // cannot be tapped by accident.
      //
      // Asserted so removing a glyph, the tile, or the far tier is a
      // deliberate edit here too.
      final AtlasLayout layout = AtlasLayout.parse(shippedLayout);
      expect(layout.kindMarkers.keys, unorderedEquals(atlasMarkerKinds));
      expect(layout.tiles, hasLength(1));
      expect(layout.tiles.single.asset, 'world/atlas_base');
      expect(layout.scale, 6);
      expect(layout.worldWidth, 6144);
      expect(layout.worldHeight, 6144);
      expect(layout.landmarks, hasLength(23));
      expect(
        layout.landmarks.where(
          (AtlasNamedLandmark l) => l.tier == AtlasLandmarkTier.future,
        ),
        hasLength(21),
      );
      // No future landmark is a travelable place: the two sets are disjoint
      // by id, which is what "visual only" has to mean in a layout file.
      final Set<String> places = <String>{
        for (final AtlasLocation l in layout.locations) l.id.value,
      };
      for (final AtlasNamedLandmark l in layout.landmarks) {
        expect(
          places.contains(l.id),
          isFalse,
          reason: '${l.id} is a landmark and must not also be a destination',
        );
      }
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
        '"hitRadius": 72',
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

  // -------------------------------------------------------------- v6 paths
  //
  // The risk these cover, named before the work: **a creature that is not
  // where the map says it is.** A patrol is arithmetic on a polyline, and
  // every one of these failures is silent on a phone — a dragon a few pixels
  // off its ridge, a mule beside its road, a plume leaving the tail, a
  // ping-pong that overshoots its cape by a frame and snaps back, a reduced
  // motion setting that empties the world instead of stilling it.
  group('a path overlay', () {
    // A 100 x 100 square: four sides of exactly 100 world px, so every
    // expectation below is a whole number a reader can check by hand.
    List<({double x, double y})> square() => const <({double x, double y})>[
      (x: 0, y: 0),
      (x: 100, y: 0),
      (x: 100, y: 100),
      (x: 0, y: 100),
    ];

    AtlasOverlay creature({
      AtlasPathMode mode = AtlasPathMode.loop,
      bool flip = true,
      int phaseMillis = 0,
      List<int> breathAt = const <int>[],
      AtlasOverlayFollower? breath,
      AtlasFacing facing = AtlasFacing.east,
    }) => AtlasOverlay(
      asset: 'env/overlay_test',
      x: 0,
      y: 0,
      width: 10,
      height: 8,
      frameCount: 4,
      frameMillis: 100,
      driftX: 0,
      driftY: 0,
      facing: facing,
      breath: breath,
      path: AtlasOverlayPath(
        points: square(),
        speed: 50,
        mode: mode,
        flip: flip,
        phaseMillis: phaseMillis,
        breathAt: breathAt,
      ),
    );

    test('measures the line, closing it only for a loop', () {
      expect(creature().path!.totalLength, closeTo(400, 0.001));
      expect(
        creature(mode: AtlasPathMode.pingpong).path!.totalLength,
        closeTo(300, 0.001),
      );
    });

    test('is at the position the arithmetic says, at t', () {
      final AtlasOverlayPath line = creature().path!;
      // 50 px/s: one second in, halfway along the first side.
      expect(line.footAt(const Duration(seconds: 1)).x, closeTo(50, 0.001));
      expect(line.footAt(const Duration(seconds: 1)).y, closeTo(0, 0.001));
      // Three seconds: 150 px, so halfway down the second side.
      expect(line.footAt(const Duration(seconds: 3)).x, closeTo(100, 0.001));
      expect(line.footAt(const Duration(seconds: 3)).y, closeTo(50, 0.001));
      // A lap is 8 s, and the ninth second repeats the first.
      expect(line.footAt(const Duration(seconds: 9)).x, closeTo(50, 0.001));
    });

    test('turns round exactly at the end of a ping-pong, not past it', () {
      final AtlasOverlayPath line = creature(
        mode: AtlasPathMode.pingpong,
      ).path!;
      // 300 px out at 50 px/s is 6 s: the far end, on the tick it turns.
      expect(line.distanceAt(const Duration(seconds: 6)), closeTo(300, 0.001));
      expect(line.footAt(const Duration(seconds: 6)).x, closeTo(0, 0.001));
      expect(line.footAt(const Duration(seconds: 6)).y, closeTo(100, 0.001));
      // A second later it is 50 px back the way it came, never 350 px along
      // a line that is only 300 px long.
      expect(line.distanceAt(const Duration(seconds: 7)), closeTo(250, 0.001));
      expect(line.footAt(const Duration(seconds: 7)).x, closeTo(50, 0.001));
      // And the whole out-and-back closes at 12 s.
      expect(line.distanceAt(const Duration(seconds: 12)), closeTo(0, 0.001));
    });

    test('mirrors only when the segment runs against the art', () {
      final AtlasOverlay east = creature();
      // First side runs east, which is the way the art faces.
      expect(east.flippedAt(const Duration(seconds: 1)), isFalse);
      // Third side runs west.
      expect(east.flippedAt(const Duration(seconds: 5)), isTrue);
      // Art that faces west is mirrored on exactly the opposite sides.
      final AtlasOverlay west = creature(facing: AtlasFacing.west);
      expect(west.flippedAt(const Duration(seconds: 1)), isTrue);
      expect(west.flippedAt(const Duration(seconds: 5)), isFalse);
      // And a path that did not ask for mirroring never mirrors.
      expect(
        creature(flip: false).flippedAt(const Duration(seconds: 5)),
        isFalse,
      );
    });

    test('reads points as the foot, and derives the top-left', () {
      // 10 x 8 native at scale 6 is 60 x 48 drawn: the sprite hangs above its
      // waypoint and is centred on it, which is what puts a mule ON the road.
      final ({double x, double y}) at = creature().topLeftAt(
        const Duration(seconds: 1),
        6,
      );
      expect(at.x, closeTo(50 - 30, 0.001));
      expect(at.y, closeTo(0 - 48, 0.001));
    });

    test('is present and pinned when the clock never moves (M-16)', () {
      final AtlasOverlay pinned = creature(
        phaseMillis: 4000,
        breathAt: const <int>[0],
        breath: const AtlasOverlayFollower(
          asset: 'env/overlay_test_breath',
          width: 8,
          height: 8,
          frameCount: 4,
          frameMillis: 100,
          offsetX: 4,
          offsetY: 0,
        ),
      );
      // Present: a path overlay has no quiet gap to disappear into, so
      // reduced motion cannot delete it.
      expect(pinned.visibleAt(Duration.zero), isTrue);
      // Pinned at points[0] — the phase does NOT move it, or a stilled world
      // would show every creature at an arbitrary point of its lap.
      expect(pinned.path!.footAt(Duration.zero).x, 0);
      expect(pinned.path!.footAt(Duration.zero).y, 0);
      expect(pinned.topLeftAt(Duration.zero, 6).x, closeTo(-30, 0.001));
      // Frame 0, not mirrored, and no plume frozen in the air.
      expect(pinned.frameIndexAt(Duration.zero), 0);
      expect(pinned.flippedAt(Duration.zero), isFalse);
      expect(pinned.breathPhaseAt(Duration.zero), isNull);
    });

    test('breathes as it crosses the waypoints it names, and not between', () {
      final AtlasOverlay dragon = creature(
        breathAt: const <int>[2],
        breath: const AtlasOverlayFollower(
          asset: 'env/overlay_test_breath',
          width: 8,
          height: 8,
          frameCount: 8,
          frameMillis: 100,
          offsetX: 4,
          offsetY: 0,
        ),
      );
      // Waypoint 2 is 200 px along at 50 px/s: 4 s into every 8 s lap, and
      // the plume is 800 ms long.
      expect(dragon.breathPhaseAt(const Duration(seconds: 4))?.index, 2);
      expect(dragon.breathPhaseAt(const Duration(seconds: 4))?.millis, 0);
      expect(
        dragon.breathPhaseAt(const Duration(milliseconds: 4400))?.millis,
        400,
      );
      // 900 ms after the crossing the plume is out.
      expect(dragon.breathPhaseAt(const Duration(milliseconds: 4900)), isNull);
      // And it fires again on the next lap, not once and never after — the
      // 76 %-absent dragon this schema exists to replace.
      expect(dragon.breathPhaseAt(const Duration(seconds: 12))?.index, 2);
    });

    test('phase moves two creatures off each other on one line', () {
      final AtlasOverlay lead = creature();
      final AtlasOverlay follow = creature(phaseMillis: 2000);
      expect(
        follow.path!.distanceAt(const Duration(seconds: 1)),
        closeTo(lead.path!.distanceAt(const Duration(seconds: 3)), 0.001),
      );
    });
  });

  group('the v6 schema', () {
    test('reads a path overlay out of the shipped world', () {
      final AtlasLayout layout = AtlasLayout.parse(
        _withOverlay(shippedLayout, _pathOverlay),
      );
      final AtlasOverlay patrol = layout.overlays.firstWhere(
        (AtlasOverlay o) => o.asset == 'env/overlay_test_patrol',
      );
      expect(patrol.hasPath, isTrue);
      expect(patrol.path!.points.length, 3);
      expect(patrol.depth, 2);
      expect(patrol.shadow!.opacity, closeTo(0.3, 0.001));
      expect(patrol.breath!.asset, 'env/overlay_test_breath');
      // The layout still validates: a path overlay's waypoints are checked
      // against the world, not a coordinate it does not have.
      expect(
        layout
            .validateAgainst(contentLocations)
            .where((String p) => p.contains('overlay_test_patrol')),
        isEmpty,
      );
    });

    test('refuses a path that also carries a placement', () {
      expect(
        () => AtlasLayout.parse(
          _withOverlay(
            shippedLayout,
            _pathOverlay.replaceFirst('"width"', '"x": 10, "width"'),
          ),
        ),
        throwsA(
          isA<AtlasLayoutException>().having(
            (AtlasLayoutException e) => e.message,
            'message',
            contains('always present'),
          ),
        ),
      );
    });

    test(
      'refuses a breath the path never fires, and a fire with no breath',
      () {
        expect(
          () => AtlasLayout.parse(
            _withOverlay(
              shippedLayout,
              _pathOverlay.replaceFirst('"breathAt": [1]', '"breathAt": [7]'),
            ),
          ),
          throwsA(isA<AtlasLayoutException>()),
        );
      },
    );

    test('refuses a depth that is not ground, low air or high air', () {
      expect(
        () => AtlasLayout.parse(
          _withOverlay(
            shippedLayout,
            _pathOverlay.replaceFirst('"depth": 2', '"depth": 3'),
          ),
        ),
        throwsA(
          isA<AtlasLayoutException>().having(
            (AtlasLayoutException e) => e.message,
            'message',
            contains('depth'),
          ),
        ),
      );
    });

    test('refuses pre-v6 documents carrying the behaviour fields', () {
      expect(
        () => AtlasLayout.parse(
          _withOverlay(
            shippedLayout,
            _pathOverlay,
          ).replaceFirst('"schemaVersion": 6', '"schemaVersion": 5'),
        ),
        throwsA(
          isA<AtlasLayoutException>().having(
            (AtlasLayoutException e) => e.message,
            'message',
            contains('schemaVersion 6'),
          ),
        ),
      );
    });
  });
}

/// A v6 patrol, written the way the layout writes one, for the schema cases.
const String _pathOverlay =
    '{"asset": "env/overlay_test_patrol", "width": 96, "height": 64, '
    '"frames": 9, "frameMillis": 400, "depth": 2, "faces": "east", '
    '"opacity": 1, '
    '"shadow": {"dx": 10, "dy": 84, "opacity": 0.3}, '
    '"breath": {"asset": "env/overlay_test_breath", "width": 96, '
    '"height": 48, "frames": 8, "frameMillis": 120, '
    '"offset": {"x": 88, "y": 10}}, '
    '"path": {"points": [[4200, 1440], [4800, 1620], [5040, 2100]], '
    '"speed": 36, "mode": "loop", "flip": true, "phaseMillis": 0, '
    '"breathAt": [1], "bob": {"amplitude": 12, "periodMillis": 1600}}}';

/// [layout] with [entry] added at the head of its `overlays` list.
String _withOverlay(String layout, String entry) =>
    layout.replaceFirst('"overlays": [', '"overlays": [$entry,');

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
