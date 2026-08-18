/// Where each place sits on the World Atlas, read from a versioned asset.
///
/// ## What this is
///
/// A **layout**, not content. `locations.json` says which places exist, what
/// they cost to walk between and what grows there; this file says where each
/// one is drawn on the atlas surface, in **world pixels** — a coordinate space
/// that belongs to the art and never to a screen. Nothing here depends on the
/// viewport size, the device pixel ratio or the zoom, and nothing here is a
/// game rule: a place with no coordinate is still a place the engine will
/// travel to, it merely cannot be pointed at.
///
/// ## Why it is loaded here and not in `lib/ui`
///
/// `Scripts/check-ui-boundary.sh` forbids asynchronous loading under `lib/ui`
/// (no `FutureBuilder`, and the session is resolved before `runApp`). So the
/// layout is read once, at `StrideSession.start`, exactly the way the content
/// pack is, and exposed as a synchronous value. A widget that had to await it
/// would reintroduce the zero-flash the guard exists to prevent.
///
/// ## Failure is reported, never thrown at the player
///
/// A malformed or incomplete layout is a **packaging** fault. The parser throws
/// [AtlasLayoutException]; `StrideSession.start` catches it, records the
/// problems, and the World screen falls back to its list-only presentation. In
/// debug the problems are printed and rendered so they are found at startup;
/// in release the atlas is simply absent and the game is unchanged.
library;

import 'dart:convert' show jsonDecode;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:stride_core/stride_core.dart' show ContentId, ContentIdParse;

/// The path of the shipped layout. Declared file by file in `pubspec.yaml`,
/// like every other asset.
const String atlasLayoutAsset = 'assets/content/v1/atlas/atlas_layout.json';

/// The schema this reader understands. A file declaring another version is
/// refused rather than guessed at.
const int atlasLayoutSchemaVersion = 1;

/// Thrown when the layout cannot be parsed. Carries the field that failed so
/// the message points at the JSON, not at the reader.
final class AtlasLayoutException implements Exception {
  const AtlasLayoutException(this.message);

  final String message;

  @override
  String toString() => 'AtlasLayoutException: $message';
}

/// One image the base geography layer is composed of, in **native pixels**.
///
/// The base may be one image or a grid of tiles. Each tile names an art asset
/// by key (resolved to a path by the UI's asset table, never here), where its
/// top-left sits in native pixels, and its native size. World pixels are native
/// pixels times [AtlasLayout.scale].
final class AtlasTile {
  const AtlasTile({
    required this.asset,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// The asset key, e.g. `world/region_map`. Resolved by the UI.
  final String asset;
  final int x;
  final int y;
  final int width;
  final int height;
}

/// A landmark drawn at a location, in **native pixels**.
///
/// [anchorX] and [anchorY] name the pixel of the landmark image that sits on
/// the location's world coordinate — the base of a gate, the mouth of a mine —
/// so the art can be authored on any canvas and still stand where the marker
/// is.
final class AtlasLandmark {
  const AtlasLandmark({
    required this.asset,
    required this.width,
    required this.height,
    required this.anchorX,
    required this.anchorY,
  });

  final String asset;
  final int width;
  final int height;
  final int anchorX;
  final int anchorY;
}

/// One place on the atlas, in **world pixels**.
final class AtlasLocation {
  const AtlasLocation({
    required this.id,
    required this.x,
    required this.y,
    required this.hitRadius,
    required this.landmark,
  });

  final ContentId id;

  /// The world coordinate the marker is centred on and a landmark's anchor
  /// stands at.
  final double x;
  final double y;

  /// The tappable radius around ([x], [y]), in world pixels. At zoom 1 a world
  /// pixel is a logical pixel, so `22` is the 44 dp accessibility floor.
  final double hitRadius;

  /// Null until the art stream delivers one; the marker and label stand alone.
  final AtlasLandmark? landmark;
}

/// A small looping sprite composited over the geography — cloud, mist, smoke.
///
/// Presentation only. It carries no meaning, marks nothing, and grants nothing;
/// it exists so the world does not look like a still photograph.
final class AtlasOverlay {
  const AtlasOverlay({
    required this.asset,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.frameCount,
    required this.frameMillis,
    required this.driftX,
    required this.driftY,
    this.opacity = 1,
  });

  /// The asset key of the frame sequence. Frame `n` resolves to
  /// `<asset>_f<n>`; the UI's asset table owns the exact naming.
  final String asset;

  /// The world coordinate of the sprite's top-left, at drift zero.
  final double x;
  final double y;

  /// Native size of one frame.
  final int width;
  final int height;

  /// How many frames the loop has, and how long each holds.
  final int frameCount;
  final int frameMillis;

  /// World pixels per second the sprite drifts before wrapping back. Zero for a
  /// sprite that loops in place.
  final double driftX;
  final double driftY;

  /// A compositor multiplier in (0, 1]. The sprites carry no alpha of their
  /// own; a cloud shadow is a solid dark shape that must never be drawn
  /// opaque, exactly as the contact shadow is a compositor step.
  final double opacity;
}

/// A scatter prop — a lone oak, a cairn, a snowdrift — standing on the base at
/// a world coordinate. Decoration only: not tappable, not a place.
final class AtlasProp {
  const AtlasProp({
    required this.asset,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.anchorX,
    required this.anchorY,
  });

  final String asset;

  /// The world coordinate the anchor pixel stands on.
  final double x;
  final double y;

  /// Native size and the anchor pixel inside it (bottom-centre of the base).
  final int width;
  final int height;
  final int anchorX;
  final int anchorY;
}

/// The drawn course of one road between two places, in world pixels.
///
/// A polyline the route layer dots along instead of a straight line, so the
/// dotted road can follow the track the base art paints. Presentation only:
/// adjacency still comes from content, and a route with no polyline is drawn
/// straight.
final class AtlasRoute {
  const AtlasRoute({
    required this.from,
    required this.to,
    required this.points,
  });

  final ContentId from;
  final ContentId to;

  /// Intermediate points, in order from [from] to [to]; the two ends are the
  /// places themselves.
  final List<({double x, double y})> points;

  bool joins(ContentId a, ContentId b) =>
      (from == a && to == b) || (from == b && to == a);
}

/// The whole layout, as read from the asset.
final class AtlasLayout {
  const AtlasLayout({
    required this.worldWidth,
    required this.worldHeight,
    required this.scale,
    required this.tiles,
    required this.locations,
    required this.overlays,
    this.props = const <AtlasProp>[],
    this.routes = const <AtlasRoute>[],
  });

  /// The world surface, in world pixels.
  final int worldWidth;
  final int worldHeight;

  /// World pixels per native art pixel. `2` for the current pass: base art is
  /// authored at 384 × 640 and shown at ×2 nearest-neighbour.
  final int scale;

  final List<AtlasTile> tiles;
  final List<AtlasLocation> locations;
  final List<AtlasOverlay> overlays;
  final List<AtlasProp> props;
  final List<AtlasRoute> routes;

  /// The drawn course between [a] and [b], or null to draw it straight.
  AtlasRoute? routeBetween(ContentId a, ContentId b) {
    for (final AtlasRoute route in routes) {
      if (route.joins(a, b)) return route;
    }
    return null;
  }

  /// The location entry for [id], or null when the layout has none.
  AtlasLocation? locationFor(ContentId id) {
    for (final AtlasLocation location in locations) {
      if (location.id == id) return location;
    }
    return null;
  }

  /// Parses the JSON text. Throws [AtlasLayoutException] on any structural
  /// fault; never returns a partial layout.
  static AtlasLayout parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (e) {
      throw AtlasLayoutException('not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      throw AtlasLayoutException('the document must be an object');
    }

    final int version = _int(decoded, 'schemaVersion');
    if (version != atlasLayoutSchemaVersion) {
      throw AtlasLayoutException(
        'schemaVersion $version is not $atlasLayoutSchemaVersion',
      );
    }

    final Map<String, Object?> world = _object(decoded, 'world');
    final int worldWidth = _int(world, 'width', within: 'world');
    final int worldHeight = _int(world, 'height', within: 'world');
    if (worldWidth <= 0 || worldHeight <= 0) {
      throw const AtlasLayoutException('world size must be positive');
    }

    final int scale = _int(decoded, 'scale');
    if (scale < 1) {
      throw const AtlasLayoutException('scale must be at least 1');
    }

    final Map<String, Object?> base = _object(decoded, 'base');
    final List<AtlasTile> tiles = <AtlasTile>[
      for (final (int i, Object? raw) in _list(
        base,
        'tiles',
        within: 'base',
      ).indexed)
        _tile(raw, i),
    ];
    if (tiles.isEmpty) {
      throw const AtlasLayoutException('base.tiles must not be empty');
    }

    final List<AtlasLocation> locations = <AtlasLocation>[
      for (final (int i, Object? raw) in _list(decoded, 'locations').indexed)
        _location(raw, i),
    ];
    final Set<String> seen = <String>{};
    for (final AtlasLocation location in locations) {
      if (!seen.add(location.id.value)) {
        throw AtlasLayoutException(
          'locations lists ${location.id.value} more than once',
        );
      }
    }

    final List<AtlasOverlay> overlays = <AtlasOverlay>[
      for (final (int i, Object? raw) in _list(decoded, 'overlays').indexed)
        _overlay(raw, i),
    ];

    final List<AtlasProp> props = <AtlasProp>[
      if (decoded['props'] != null)
        for (final (int i, Object? raw) in _list(decoded, 'props').indexed)
          _prop(raw, i),
    ];
    final List<AtlasRoute> routes = <AtlasRoute>[
      if (decoded['routes'] != null)
        for (final (int i, Object? raw) in _list(decoded, 'routes').indexed)
          _route(raw, i),
    ];

    return AtlasLayout(
      worldWidth: worldWidth,
      worldHeight: worldHeight,
      scale: scale,
      tiles: List<AtlasTile>.unmodifiable(tiles),
      locations: List<AtlasLocation>.unmodifiable(locations),
      overlays: List<AtlasOverlay>.unmodifiable(overlays),
      props: List<AtlasProp>.unmodifiable(props),
      routes: List<AtlasRoute>.unmodifiable(routes),
    );
  }

  /// Everything wrong with this layout **for these locations**, as sentences.
  ///
  /// Empty when the layout is usable. Structural faults are already refused by
  /// [parse]; these are the semantic ones — a content location with nowhere to
  /// stand, a coordinate off the surface, a hit target too small to tap. They
  /// are reported rather than thrown because the right response is a fallback
  /// presentation, not a refused launch.
  List<String> validateAgainst(Iterable<ContentId> contentLocations) {
    final List<String> problems = <String>[];

    final Set<String> known = <String>{
      for (final ContentId id in contentLocations) id.value,
    };
    for (final ContentId id in contentLocations) {
      if (locationFor(id) == null) {
        problems.add('${id.value} has no atlas coordinate');
      }
    }
    for (final AtlasLocation location in locations) {
      if (!known.contains(location.id.value)) {
        problems.add(
          '${location.id.value} is in the atlas but not in locations.json',
        );
      }
      if (location.x < 0 ||
          location.y < 0 ||
          location.x > worldWidth ||
          location.y > worldHeight) {
        problems.add(
          '${location.id.value} lies outside the $worldWidth×$worldHeight '
          'world at (${location.x}, ${location.y})',
        );
      }
      if (location.hitRadius < minimumHitRadius) {
        problems.add(
          '${location.id.value} hit radius ${location.hitRadius} is under '
          'the $minimumHitRadius world-pixel floor',
        );
      }
      if (location.hitRadius > maximumHitRadius) {
        problems.add(
          '${location.id.value} hit radius ${location.hitRadius} is over '
          '$maximumHitRadius and would swallow its neighbours',
        );
      }
    }
    for (final AtlasTile tile in tiles) {
      final int right = (tile.x + tile.width) * scale;
      final int bottom = (tile.y + tile.height) * scale;
      if (tile.x < 0 ||
          tile.y < 0 ||
          right > worldWidth ||
          bottom > worldHeight) {
        problems.add('tile ${tile.asset} does not fit inside the world');
      }
    }
    for (final AtlasProp prop in props) {
      if (prop.x < 0 ||
          prop.y < 0 ||
          prop.x > worldWidth ||
          prop.y > worldHeight) {
        problems.add('prop ${prop.asset} stands outside the world');
      }
    }
    for (final AtlasRoute route in routes) {
      if (locationFor(route.from) == null || locationFor(route.to) == null) {
        problems.add(
          'route ${route.from.value}→${route.to.value} joins a place the '
          'atlas does not have',
        );
      }
    }
    for (final AtlasOverlay overlay in overlays) {
      if (overlay.x < 0 ||
          overlay.y < 0 ||
          overlay.x > worldWidth ||
          overlay.y > worldHeight) {
        problems.add('overlay ${overlay.asset} starts outside the world');
      }
    }
    return problems;
  }

  /// 22 world pixels is a 44 dp diameter at zoom 1 — the accessibility floor.
  static const double minimumHitRadius = 22;

  /// Above this a target stops being a place and starts being a region.
  static const double maximumHitRadius = 96;

  // -- JSON helpers, each naming the field it failed on ----------------------

  static Map<String, Object?> _object(
    Map<String, Object?> parent,
    String key, {
    String? within,
  }) {
    final Object? value = parent[key];
    if (value is Map<String, Object?>) return value;
    throw AtlasLayoutException('${_at(key, within)} must be an object');
  }

  static List<Object?> _list(
    Map<String, Object?> parent,
    String key, {
    String? within,
  }) {
    final Object? value = parent[key];
    if (value is List<Object?>) return value;
    throw AtlasLayoutException('${_at(key, within)} must be a list');
  }

  static int _int(Map<String, Object?> parent, String key, {String? within}) {
    final Object? value = parent[key];
    if (value is int) return value;
    throw AtlasLayoutException('${_at(key, within)} must be an integer');
  }

  static double _number(
    Map<String, Object?> parent,
    String key, {
    String? within,
  }) {
    final Object? value = parent[key];
    if (value is num) return value.toDouble();
    throw AtlasLayoutException('${_at(key, within)} must be a number');
  }

  static String _string(
    Map<String, Object?> parent,
    String key, {
    String? within,
  }) {
    final Object? value = parent[key];
    if (value is String && value.isNotEmpty) return value;
    throw AtlasLayoutException(
      '${_at(key, within)} must be a non-empty string',
    );
  }

  static String _at(String key, String? within) =>
      within == null ? key : '$within.$key';

  static AtlasTile _tile(Object? raw, int index) {
    if (raw is! Map<String, Object?>) {
      throw AtlasLayoutException('base.tiles[$index] must be an object');
    }
    final String at = 'base.tiles[$index]';
    final AtlasTile tile = AtlasTile(
      asset: _string(raw, 'asset', within: at),
      x: _int(raw, 'x', within: at),
      y: _int(raw, 'y', within: at),
      width: _int(raw, 'width', within: at),
      height: _int(raw, 'height', within: at),
    );
    if (tile.width <= 0 || tile.height <= 0) {
      throw AtlasLayoutException('$at size must be positive');
    }
    return tile;
  }

  static AtlasLocation _location(Object? raw, int index) {
    if (raw is! Map<String, Object?>) {
      throw AtlasLayoutException('locations[$index] must be an object');
    }
    final String at = 'locations[$index]';
    final String rawId = _string(raw, 'id', within: at);
    final ContentIdParse parsed = ContentId.parse(rawId);
    final ContentId? id = parsed.id;
    if (id == null) {
      throw AtlasLayoutException('$at.id: ${parsed.explanation}');
    }
    final Object? landmarkRaw = raw['landmark'];
    AtlasLandmark? landmark;
    if (landmarkRaw != null) {
      if (landmarkRaw is! Map<String, Object?>) {
        throw AtlasLayoutException('$at.landmark must be an object or null');
      }
      final String lat = '$at.landmark';
      landmark = AtlasLandmark(
        asset: _string(landmarkRaw, 'asset', within: lat),
        width: _int(landmarkRaw, 'width', within: lat),
        height: _int(landmarkRaw, 'height', within: lat),
        anchorX: _int(landmarkRaw, 'anchorX', within: lat),
        anchorY: _int(landmarkRaw, 'anchorY', within: lat),
      );
      if (landmark.width <= 0 || landmark.height <= 0) {
        throw AtlasLayoutException('$lat size must be positive');
      }
    }
    return AtlasLocation(
      id: id,
      x: _number(raw, 'x', within: at),
      y: _number(raw, 'y', within: at),
      hitRadius: _number(raw, 'hitRadius', within: at),
      landmark: landmark,
    );
  }

  static AtlasOverlay _overlay(Object? raw, int index) {
    if (raw is! Map<String, Object?>) {
      throw AtlasLayoutException('overlays[$index] must be an object');
    }
    final String at = 'overlays[$index]';
    final Map<String, Object?> driftRaw = _object(raw, 'drift', within: at);
    final AtlasOverlay overlay = AtlasOverlay(
      asset: _string(raw, 'asset', within: at),
      x: _number(raw, 'x', within: at),
      y: _number(raw, 'y', within: at),
      width: _int(raw, 'width', within: at),
      height: _int(raw, 'height', within: at),
      frameCount: _int(raw, 'frames', within: at),
      frameMillis: _int(raw, 'frameMillis', within: at),
      driftX: _number(driftRaw, 'x', within: '$at.drift'),
      driftY: _number(driftRaw, 'y', within: '$at.drift'),
      opacity: raw['opacity'] == null ? 1 : _number(raw, 'opacity', within: at),
    );
    if (overlay.opacity <= 0 || overlay.opacity > 1) {
      throw AtlasLayoutException('$at.opacity must be in (0, 1]');
    }
    if (overlay.frameCount < 1 || overlay.frameMillis < 1) {
      throw AtlasLayoutException(
        '$at needs at least one frame of positive length',
      );
    }
    if (overlay.width <= 0 || overlay.height <= 0) {
      throw AtlasLayoutException('$at size must be positive');
    }
    return overlay;
  }

  static AtlasProp _prop(Object? raw, int index) {
    if (raw is! Map<String, Object?>) {
      throw AtlasLayoutException('props[$index] must be an object');
    }
    final String at = 'props[$index]';
    final AtlasProp prop = AtlasProp(
      asset: _string(raw, 'asset', within: at),
      x: _number(raw, 'x', within: at),
      y: _number(raw, 'y', within: at),
      width: _int(raw, 'width', within: at),
      height: _int(raw, 'height', within: at),
      anchorX: _int(raw, 'anchorX', within: at),
      anchorY: _int(raw, 'anchorY', within: at),
    );
    if (prop.width <= 0 || prop.height <= 0) {
      throw AtlasLayoutException('$at size must be positive');
    }
    return prop;
  }

  static AtlasRoute _route(Object? raw, int index) {
    if (raw is! Map<String, Object?>) {
      throw AtlasLayoutException('routes[$index] must be an object');
    }
    final String at = 'routes[$index]';
    ContentId idOf(String key) {
      final ContentIdParse parsed = ContentId.parse(
        _string(raw, key, within: at),
      );
      final ContentId? id = parsed.id;
      if (id == null) {
        throw AtlasLayoutException('$at.$key: ${parsed.explanation}');
      }
      return id;
    }

    final List<({double x, double y})> points = <({double x, double y})>[];
    for (final (int i, Object? p) in _list(raw, 'points', within: at).indexed) {
      if (p is! List<Object?> ||
          p.length != 2 ||
          p[0] is! num ||
          p[1] is! num) {
        throw AtlasLayoutException('$at.points[$i] must be [x, y]');
      }
      points.add((x: (p[0]! as num).toDouble(), y: (p[1]! as num).toDouble()));
    }
    return AtlasRoute(from: idOf('from'), to: idOf('to'), points: points);
  }
}

/// Reads and parses the shipped layout. Throws [AtlasLayoutException] when the
/// asset is missing or malformed; the caller decides what a missing atlas
/// means.
Future<AtlasLayout> loadAtlasLayoutFromAssets({AssetBundle? bundle}) async {
  final AssetBundle assets = bundle ?? rootBundle;
  final String text;
  try {
    text = await assets.loadString(atlasLayoutAsset);
  } on Object catch (e) {
    throw AtlasLayoutException(
      'could not read $atlasLayoutAsset from the asset bundle. Is it declared '
      'under `flutter: assets:` in pubspec.yaml? ($e)',
    );
  }
  return AtlasLayout.parse(text);
}
