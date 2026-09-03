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

/// The schema this reader writes and prefers. A file declaring a version
/// outside [atlasLayoutMinimumSchemaVersion] … [atlasLayoutSchemaVersion] is
/// refused rather than guessed at.
///
/// **v2 adds two optional blocks and nothing else.** Every v1 document is a
/// valid v2 document with `landmarks` and `kindMarkers` absent, which is why
/// both versions parse here rather than one of them needing a converter:
///
/// - `landmarks` — named, non-interactive geography (a ruin, a ferry, a far
///   town). It has a name and a coordinate and *no* hit target, no panel and no
///   travel: it is a caption on the map, in the same sense the current-location
///   ring is a caption. A place the player can go to is a `location`, and the
///   two lists may not name the same id.
/// - `kindMarkers` — the glyph art for each kind of place (`world/marker_haven`
///   and its four siblings). Absent until the art lands, and absent is not a
///   fault: the marker layer draws its ring chrome instead.
///
/// **v3 adds one optional block:** `rumors` — where each authored rumor
/// (`rumors.json`, `DECISIONS/0023` §8) stands on the map *if the player has
/// heard it*. A spot, not a place: no hit target, no travel, no art — the
/// label is the rumor's own name ("Eastern City ?"), drawn only once the
/// state says the rumor is revealed. An unheard rumor draws nothing, which is
/// the discovery model's RUMORED tier made literal.
///
/// **v4 adds one optional overlay field:** `intervalMillis` — a quiet gap
/// between plays of an overlay's loop, during which the overlay draws
/// nothing at all. Absent or zero is the continuous loop every earlier
/// document meant. This is what makes an *occasional* piece of map life — a
/// creature that peeks and withdraws, a volcano that stirs and settles —
/// expressible as data rather than as a wall of blank frames.
///
/// **v5 adds two optional overlay fields.** `playLoops` — how many times one
/// play runs through the frame loop before the quiet gap returns (so a
/// creature can undulate its short loop across a long journey without the
/// asset set carrying duplicate frames). And `travel` — world pixels per second
/// the sprite moves *during one play*, measured from the moment its quiet gap
/// ends and reset by the next gap. This is a journey, not a drift: a serpent
/// that surfaces and swims a little way west before diving, a dragon that
/// crosses a stretch of sky and is gone. It therefore requires
/// `intervalMillis` (a continuous loop has no play boundary to measure from)
/// and excludes `drift` (one sprite, one kind of motion), and it never wraps —
/// the play ends before the world's edge does.
///
/// **v6 adds behaviour to an overlay, and nothing to any other block.** Five
/// optional overlay fields, each absent from every v1–v5 document:
///
/// - `path` — a waypoint polyline the sprite walks, flies or swims along at a
///   constant speed, `loop` (the polyline closes) or `pingpong` (it turns
///   round at each end). Points are the world coordinate of the sprite's
///   **foot** — bottom-centre — so a creature that follows a road takes that
///   road's `routes[].points` verbatim instead of a hand-computed top-left. A
///   path overlay has no `x`/`y`, no `drift`, no `travel` and no
///   `intervalMillis`: it is **always present**, which is the whole point.
///   Before v6 the only patrol expressible here was a straight line ending in
///   a disappearance, and a dragon absent three quarters of the time reads as
///   a bug rather than as a world.
/// - `bob` (inside `path`) — a sine on the sprite's y, so flight is not a
///   ruler-straight glide.
/// - `breath` / `cloud` — **followers**, declared inside their host and drawn
///   with it. They are not overlays: they hold no slot, carry no coordinate of
///   their own and cannot be placed anywhere except on the creature that owns
///   them. `breath` fires once as the host crosses each waypoint named in
///   `path.breathAt`; `cloud` is continuous and is drawn *under* the host, so
///   a storm travels with the drake that carries it.
/// - `shadow` — the host's own current frame, repainted flat black at an
///   opacity and offset. No art, no second asset, and no way for the shadow to
///   disagree with the pose above it.
/// - `depth` — 0 ground (the default, and every pre-v6 overlay), 1 low air,
///   2 high air. The layer paints depth 0 in JSON array order, then every
///   shadow, then depth 1, then depth 2, so a dragon passes over the birds
///   rather than through them.
///
/// **Reduced motion does not delete the world.** With the ticker stopped the
/// elapsed clock holds at zero, and at zero every path overlay is drawn
/// *pinned at `points[0]`, frame 0, shadow included, breath suppressed*. An
/// accessibility setting takes the movement away and leaves the creature
/// standing there; it does not empty the map (`MISTAKES.md` M-16).
const int atlasLayoutSchemaVersion = 6;

/// The oldest schema this reader still accepts.
const int atlasLayoutMinimumSchemaVersion = 1;

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

/// A sprite anchored on a world coordinate, in **native pixels**.
///
/// [anchorX] and [anchorY] name the pixel of the image that sits on the
/// coordinate — the base of a gate, the mouth of a mine, the centre of a
/// marker glyph — so the art can be authored on any canvas and still stand
/// where the coordinate is.
///
/// Three things are described by this one shape, and deliberately so: a
/// location's landmark building, a named landmark's own art, and the kind
/// glyph under a marker. They differ in *where* they are declared, never in
/// what the renderer has to know.
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

/// How loudly a named landmark is drawn.
enum AtlasLandmarkTier {
  /// Geography inside the known world — a ruin beside a road, a ferry
  /// crossing. Drawn small and quiet, below the place labels.
  minor('minor'),

  /// Somewhere the roads point at and do not yet reach. Quieter still, and
  /// suffixed so it cannot be mistaken for a place with a panel behind it.
  future('future');

  const AtlasLandmarkTier(this.wireName);

  /// The word in the JSON. Never derived from the enum name, so renaming the
  /// enum is not a content migration.
  final String wireName;

  static AtlasLandmarkTier? ofWire(String wire) {
    for (final AtlasLandmarkTier tier in values) {
      if (tier.wireName == wire) return tier;
    }
    return null;
  }
}

/// A named piece of geography that is **not** a place.
///
/// It has a name and a coordinate and nothing else: no hit target, no panel,
/// no travel, no state. The rule it exists to keep is the one the prompt
/// states as "clearly non-interactive" — a player must be able to tell, before
/// touching the screen, that *Ruined Watchtower* is scenery and *Stonefall
/// Mine* is somewhere they can walk to.
///
/// [id] is a plain string, not a `ContentId`, because a landmark is not
/// content: the engine has never heard of it and never will. It must still be
/// unique, and must not collide with a location id — a landmark wearing a
/// place's id would be a place drawn twice, once without a way in.
final class AtlasNamedLandmark {
  const AtlasNamedLandmark({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.tier,
    required this.marker,
  });

  final String id;

  /// What the label says. Authored, never derived from [id].
  final String name;

  /// World pixels — the point the label hangs under and the marker anchors on.
  final double x;
  final double y;

  final AtlasLandmarkTier tier;

  /// The art, when there is any. Null draws the label alone.
  final AtlasLandmark? marker;
}

/// The five glyph slots a marker may be drawn from, by wire name.
///
/// The words match `LocationKind` in `stride_core` plus `landmark`, but this
/// library deliberately does **not** import that enum: a layout file is
/// packaging data that must parse before any content is loaded, and a marker
/// slot is an art key rather than a game concept.
const List<String> atlasMarkerKinds = <String>[
  'haven',
  'wilds',
  'worksite',
  'perilous',
  'landmark',
];

/// A small looping sprite composited over the geography — cloud, mist, smoke.
///
/// Presentation only. It carries no meaning, marks nothing, and grants nothing;
/// it exists so the world does not look like a still photograph.
/// How an overlay's y is nudged along its path, so flight is not a ruler.
final class AtlasOverlayBob {
  const AtlasOverlayBob({required this.amplitude, required this.periodMillis});

  /// World pixels above and below the path.
  final double amplitude;

  /// Milliseconds for one full up-and-down.
  final int periodMillis;

  /// The offset to add to y at [t]. Zero at t = 0, so a pinned creature sits
  /// exactly on its waypoint rather than a few pixels off it.
  double offsetAt(Duration t) {
    if (periodMillis <= 0) return 0;
    const double twoPi = 6.283185307179586;
    return amplitude * _sin(twoPi * t.inMilliseconds / periodMillis);
  }

  /// A local sine, so this library keeps its two imports. Bhaskara's rational
  /// approximation is within 0.002 of `sin` over a full turn — far under one
  /// world pixel at any amplitude a creature bobs by.
  static double _sin(double x) {
    const double twoPi = 6.283185307179586;
    const double pi = 3.141592653589793;
    double a = x % twoPi;
    if (a < 0) a += twoPi;
    final bool negative = a > pi;
    if (negative) a -= pi;
    final double value =
        16 * a * (pi - a) / (5 * pi * pi - 4 * a * (pi - a));
    return negative ? -value : value;
  }
}

/// A sprite with no place of its own on the map, drawn on its host.
///
/// The dragon's breath and the storm drake's cloud are both this. A follower
/// holds **no overlay slot**: it has no `x`/`y`, cannot be placed alone, and
/// exists only for as long as the frame that draws its host. [offsetX] and
/// [offsetY] are sprite-local, measured from the host's top-left, and are
/// mirrored with the host when it flips, so a plume always leaves the jaw and
/// never the tail.
final class AtlasOverlayFollower {
  const AtlasOverlayFollower({
    required this.asset,
    required this.width,
    required this.height,
    required this.frameCount,
    required this.frameMillis,
    required this.offsetX,
    required this.offsetY,
    this.opacity = 1,
  });

  final String asset;
  final int width;
  final int height;
  final int frameCount;
  final int frameMillis;

  /// Sprite-local, from the host's top-left, in native pixels.
  final int offsetX;
  final int offsetY;

  final double opacity;

  /// One play of the follower, in milliseconds.
  int get durationMillis => frameCount * frameMillis;

  /// The frame at [millis] into a play, clamped inside the sequence.
  int frameIndexAt(int millis) =>
      millis <= 0 ? 0 : millis ~/ frameMillis % frameCount;

}

/// The host's own frame, repainted flat black and dropped below it.
///
/// Zero art: the renderer colour-filters the frame that is already on screen,
/// so the shadow can never disagree with the pose that casts it.
final class AtlasOverlayShadow {
  const AtlasOverlayShadow({
    required this.dx,
    required this.dy,
    required this.opacity,
  });

  /// World pixels, from the host's top-left.
  final double dx;
  final double dy;

  final double opacity;
}

/// How a path is walked once its end is reached.
enum AtlasPathMode {
  /// The polyline closes: the last point joins the first and the creature
  /// circles forever.
  loop,

  /// The creature turns round at each end and retraces the line.
  pingpong,
}

/// Which way the sprite's art faces, before any mirroring.
enum AtlasFacing { east, west }

/// A waypoint polyline an overlay travels along at a constant speed.
///
/// [points] are the world coordinate of the sprite's **foot** — bottom-centre
/// — because that is the coordinate a road, a shoreline and a ridge are drawn
/// in. The top-left the renderer needs is derived
/// (`x − width·scale/2`, `y − height·scale`), so a mule train can take a
/// route's own `points` verbatim and stand on the road rather than beside it.
final class AtlasOverlayPath {
  AtlasOverlayPath({
    required this.points,
    required this.speed,
    required this.mode,
    required this.flip,
    required this.phaseMillis,
    required this.breathAt,
    this.bob,
  }) : _cumulative = _measure(points, mode);

  /// World coordinates of the sprite's foot, in order.
  final List<({double x, double y})> points;

  /// World pixels per second along the line.
  final double speed;

  final AtlasPathMode mode;

  /// Whether the sprite is mirrored when the segment it is on runs against
  /// the direction the art faces.
  final bool flip;

  /// Milliseconds added to the clock, so two creatures on one line do not
  /// move in lockstep.
  final int phaseMillis;

  /// Waypoint indices at which the host's `breath` fires.
  final List<int> breathAt;

  final AtlasOverlayBob? bob;

  /// Cumulative arc length at each waypoint; the last entry is the total,
  /// including the closing segment when the mode is [AtlasPathMode.loop].
  final List<double> _cumulative;

  static List<double> _measure(
    List<({double x, double y})> points,
    AtlasPathMode mode,
  ) {
    final List<double> out = <double>[0];
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += _distance(points[i - 1], points[i]);
      out.add(total);
    }
    if (mode == AtlasPathMode.loop && points.length > 1) {
      total += _distance(points.last, points.first);
      out.add(total);
    }
    return out;
  }

  static double _distance(({double x, double y}) a, ({double x, double y}) b) {
    final double dx = b.x - a.x;
    final double dy = b.y - a.y;
    return _sqrt(dx * dx + dy * dy);
  }

  /// Newton's method, so this library needs no `dart:math`. Twenty-four passes
  /// put a double within its own precision for any length an atlas can hold.
  static double _sqrt(double v) {
    if (v <= 0) return 0;
    double g = v > 1 ? v / 2 : 1;
    for (int i = 0; i < 24; i++) {
      g = 0.5 * (g + v / g);
    }
    return g;
  }

  /// The whole line, closing segment included for a loop.
  double get totalLength => _cumulative.last;

  /// Arc length at waypoint [index].
  double lengthAtWaypoint(int index) => _cumulative[index];

  /// Milliseconds for one full cycle — a lap for a loop, an out-and-back for
  /// a ping-pong.
  double get cycleMillis =>
      (mode == AtlasPathMode.pingpong ? 2 : 1) * totalLength / speed * 1000;

  /// Distance travelled along the line at [t].
  ///
  /// `loop`: `s = speed·(t + phase) mod L`. `pingpong`:
  /// `s′ = speed·(t + phase) mod 2L`, then `s = s′ ≤ L ? s′ : 2L − s′` — the
  /// turnaround is exact, so a creature that reaches the cape is at the cape
  /// on the tick it turns, never one pixel past it.
  double distanceAt(Duration t) {
    final double length = totalLength;
    if (length <= 0) return 0;
    final double seconds = (t.inMilliseconds + phaseMillis) / 1000;
    double s = speed * seconds;
    if (mode == AtlasPathMode.loop) {
      return (s % length + length) % length;
    }
    final double span = 2 * length;
    s = (s % span + span) % span;
    return s <= length ? s : span - s;
  }

  /// Where the sprite's foot is at [t], and which way the segment under it
  /// runs (`dx` positive is eastward).
  ///
  /// **At `Duration.zero` this is `points[0]` exactly**, whatever the phase.
  /// That is the reduced-motion pin: the ticker never advances, the clock
  /// holds at zero, and every creature stands on its first waypoint instead
  /// of vanishing (M-16).
  ({double x, double y, double dx}) footAt(Duration t) {
    if (t == Duration.zero) {
      final double dx = points.length > 1 ? points[1].x - points[0].x : 1;
      return (x: points[0].x, y: points[0].y, dx: dx);
    }
    final double s = distanceAt(t);
    for (int i = 1; i < _cumulative.length; i++) {
      if (s <= _cumulative[i] || i == _cumulative.length - 1) {
        final ({double x, double y}) a = points[i - 1];
        final ({double x, double y}) b = i < points.length
            ? points[i]
            : points.first;
        final double segment = _cumulative[i] - _cumulative[i - 1];
        final double f = segment <= 0
            ? 0
            : ((s - _cumulative[i - 1]) / segment).clamp(0.0, 1.0);
        return (
          x: a.x + (b.x - a.x) * f,
          y: a.y + (b.y - a.y) * f,
          dx: b.x - a.x,
        );
      }
    }
    return (x: points[0].x, y: points[0].y, dx: 1);
  }
}

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
    this.intervalMillis = 0,
    this.travelX = 0,
    this.travelY = 0,
    this.playLoops = 1,
    this.depth = 0,
    this.facing = AtlasFacing.east,
    this.path,
    this.breath,
    this.cloud,
    this.shadow,
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

  /// Milliseconds of nothing between plays of the loop (v4). Zero — every
  /// pre-v4 document — is the continuous loop.
  final int intervalMillis;

  /// World pixels per second the sprite moves during one play (v5), measured
  /// from the end of the quiet gap and reset by the next one. Zero for a
  /// sprite that plays in place. Unlike [driftX]/[driftY] this never wraps:
  /// the journey is as long as the play and no longer.
  final double travelX;
  final double travelY;

  /// How many times one play runs through the frame loop (v5). One — every
  /// pre-v5 document — is the single pass. [frameIndexAt]'s modulo already
  /// wraps the frames, so a longer play simply loops them.
  final int playLoops;

  /// One play, in milliseconds: the frame loop, [playLoops] times over.
  int get activeMillis => frameCount * frameMillis * playLoops;

  /// One full cycle: the play plus the quiet gap.
  int get cycleMillis => activeMillis + intervalMillis;

  /// Whether the overlay draws anything at [elapsed]. Always true for a
  /// continuous loop. For an intermittent one the cycle opens with its quiet
  /// gap, so a clock that never advances — the test harness, reduced motion,
  /// a backgrounded app — shows *no creature at all* rather than one frozen
  /// mid-appearance, and a freshly opened screen holds its first discovery
  /// back for one gap.
  bool visibleAt(Duration elapsed) =>
      intervalMillis == 0 ||
      elapsed.inMilliseconds % cycleMillis >= intervalMillis;

  /// The frame to draw at [elapsed]. For a continuous loop this is the old
  /// modular cadence unchanged; for an intermittent one the play starts from
  /// frame 0 the moment its gap ends, so a creature's rise always plays from
  /// its first frame. Meaningless while [visibleAt] is false — clamped inside
  /// the frame range regardless, so a caller that ignores visibility still
  /// gets a frame that exists.
  int frameIndexAt(Duration elapsed) {
    final int inCycle = elapsed.inMilliseconds % cycleMillis;
    final int inPlay = inCycle >= intervalMillis ? inCycle - intervalMillis : 0;
    return inPlay ~/ frameMillis % frameCount;
  }

  /// Milliseconds into the current play at [elapsed] — zero throughout the
  /// quiet gap, so a travelling sprite stands at its origin until its play
  /// begins and retraces the same journey every cycle.
  int playMillisAt(Duration elapsed) {
    if (intervalMillis == 0) return elapsed.inMilliseconds;
    final int inCycle = elapsed.inMilliseconds % cycleMillis;
    return inCycle >= intervalMillis ? inCycle - intervalMillis : 0;
  }

  /// Which band the overlay paints in (v6): 0 ground, 1 low air, 2 high air.
  /// Every pre-v6 overlay is 0, which is where it already painted.
  final int depth;

  /// Which way the art faces before mirroring (v6). Only [path] reads it.
  final AtlasFacing facing;

  /// The waypoint line this overlay travels (v6), or null for a sprite that
  /// stays where the layout put it. A path overlay is **always present**: it
  /// has no quiet gap to disappear into.
  final AtlasOverlayPath? path;

  /// A follower that fires once per crossing of each `path.breathAt`
  /// waypoint, drawn over the host (v6).
  final AtlasOverlayFollower? breath;

  /// A follower drawn continuously *under* the host (v6) — the storm a drake
  /// carries with it.
  final AtlasOverlayFollower? cloud;

  /// The host's frame repainted flat black beneath it (v6).
  final AtlasOverlayShadow? shadow;

  /// Whether this overlay moves along a waypoint line rather than sitting at
  /// [x], [y].
  bool get hasPath => path != null;

  /// The sprite's top-left in world pixels at [t], for a path overlay, at a
  /// layout [scale]. Derived from the foot: `points` are the bottom-centre of
  /// the sprite, which is the coordinate roads and shorelines are drawn in.
  ///
  /// Returns [x], [y] unchanged for an overlay with no path, so a caller need
  /// not branch.
  ({double x, double y}) topLeftAt(Duration t, int scale) {
    final AtlasOverlayPath? line = path;
    if (line == null) return (x: x, y: y);
    final ({double x, double y, double dx}) foot = line.footAt(t);
    final double bob = t == Duration.zero
        ? 0
        : (line.bob?.offsetAt(t) ?? 0);
    return (
      x: foot.x - width * scale / 2,
      y: foot.y + bob - height * scale,
    );
  }

  /// Whether the sprite is mirrored at [t] — true when the segment under it
  /// runs against [facing] and the path asked for mirroring.
  bool flippedAt(Duration t) {
    final AtlasOverlayPath? line = path;
    if (line == null || !line.flip) return false;
    final double dx = line.footAt(t).dx;
    if (dx == 0) return false;
    return facing == AtlasFacing.east ? dx < 0 : dx > 0;
  }

  /// Which `breathAt` waypoint is firing at [t], and how far into the plume,
  /// or null when no breath is in the air.
  ///
  /// The host crosses waypoint *k* at arc length `cum[k]`, so it crosses at
  /// clock `cum[k] / speed` within each cycle — twice per cycle in ping-pong,
  /// once on the way out and once on the way back. The plume is up for its
  /// own duration from each of those instants.
  ///
  /// **Null at `Duration.zero`.** A pinned creature is not mid-breath
  /// (M-16's pin shows the world, not one frozen explosion).
  ({int index, int millis})? breathPhaseAt(Duration t) {
    final AtlasOverlayPath? line = path;
    final AtlasOverlayFollower? plume = breath;
    if (line == null || plume == null || line.breathAt.isEmpty) return null;
    if (t == Duration.zero) return null;
    final double cycle = line.cycleMillis;
    if (cycle <= 0) return null;
    final double duration = plume.durationMillis.toDouble();
    final double clock = (t.inMilliseconds + line.phaseMillis).toDouble();
    final double lap = line.totalLength / line.speed * 1000;
    for (final int k in line.breathAt) {
      if (k < 0 || k >= line.points.length) continue;
      final double at = line.lengthAtWaypoint(k) / line.speed * 1000;
      final List<double> crossings = line.mode == AtlasPathMode.pingpong
          ? <double>[at, 2 * lap - at]
          : <double>[at];
      for (final double crossing in crossings) {
        final double since = ((clock - crossing) % cycle + cycle) % cycle;
        if (since < duration) {
          return (index: k, millis: since.round());
        }
      }
    }
    return null;
  }
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

/// Where one authored rumor stands on the map, in world pixels.
///
/// [id] is a real `ContentId` in the `rumor` namespace — unlike a landmark,
/// a rumor *is* content (`rumors.json` carries its name and hint), and the
/// coordinate here is only where the atlas hangs that name once the player
/// has heard it.
final class AtlasRumorSpot {
  const AtlasRumorSpot({required this.id, required this.x, required this.y});

  final ContentId id;
  final double x;
  final double y;
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
    this.landmarks = const <AtlasNamedLandmark>[],
    this.kindMarkers = const <String, AtlasLandmark>{},
    this.rumors = const <AtlasRumorSpot>[],
    this.schemaVersion = atlasLayoutSchemaVersion,
  });

  /// The world surface, in world pixels.
  final int worldWidth;
  final int worldHeight;

  /// World pixels per native art pixel. `2` for the current pass: the base
  /// tiles are authored at their native size and shown at ×2 nearest
  /// neighbour.
  ///
  /// **Nothing outside this file may assume the world's size.** It is one tile
  /// today and a 2 × 2 grid once the art stream lands; every camera bound,
  /// zoom floor and clamp reads [worldWidth] and [worldHeight].
  final int scale;

  final List<AtlasTile> tiles;
  final List<AtlasLocation> locations;
  final List<AtlasOverlay> overlays;
  final List<AtlasProp> props;
  final List<AtlasRoute> routes;

  /// Named, non-interactive geography. Empty for a v1 document.
  final List<AtlasNamedLandmark> landmarks;

  /// The glyph art for each kind of marker, by wire name
  /// ([atlasMarkerKinds]). Empty until the art lands; the marker layer draws
  /// ring chrome for a kind with no entry, which is the state this ships in.
  final Map<String, AtlasLandmark> kindMarkers;

  /// Where each authored rumor stands, once heard. Empty for a pre-v3
  /// document, and empty is not a fault — rumors then simply have no marker.
  final List<AtlasRumorSpot> rumors;

  /// The rumor spot for [id], or null when the layout places none.
  AtlasRumorSpot? rumorFor(ContentId id) {
    for (final AtlasRumorSpot rumor in rumors) {
      if (rumor.id == id) return rumor;
    }
    return null;
  }

  /// The version the document declared. Kept so a screen can say what it read
  /// rather than what it hoped for.
  final int schemaVersion;

  /// The glyph for [kind], or null when the art has not landed.
  AtlasLandmark? markerForKind(String kind) => kindMarkers[kind];

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
    if (version < atlasLayoutMinimumSchemaVersion ||
        version > atlasLayoutSchemaVersion) {
      throw AtlasLayoutException(
        'schemaVersion $version is outside $atlasLayoutMinimumSchemaVersion'
        '..$atlasLayoutSchemaVersion',
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

    // The two v2 blocks. A v1 document carrying either is a version lie, not a
    // forward-compatible file: it would parse under a reader that has never
    // heard of landmarks and silently lose them.
    if (version < 2 &&
        (decoded['landmarks'] != null || decoded['kindMarkers'] != null)) {
      throw const AtlasLayoutException(
        'landmarks and kindMarkers need schemaVersion 2',
      );
    }
    // The v3 block, on the same terms.
    if (version < 3 && decoded['rumors'] != null) {
      throw const AtlasLayoutException('rumors need schemaVersion 3');
    }
    // The v4 field, on the same terms: an earlier reader would parse an
    // intermittent overlay as a continuous loop — dropped behaviour rather
    // than dropped data, and refused all the same.
    if (version < 4) {
      for (final Object? raw in _list(decoded, 'overlays')) {
        if (raw is Map<String, Object?> && raw['intervalMillis'] != null) {
          throw const AtlasLayoutException(
            'intervalMillis needs schemaVersion 4',
          );
        }
      }
    }
    // The v5 field, on the same terms: an earlier reader would pin a
    // travelling sprite to its origin — dropped motion, refused all the same.
    if (version < 5) {
      for (final Object? raw in _list(decoded, 'overlays')) {
        if (raw is Map<String, Object?> &&
            (raw['travel'] != null || raw['playLoops'] != null)) {
          throw const AtlasLayoutException(
            'travel and playLoops need schemaVersion 5',
          );
        }
      }
    }
    // The v6 behaviour fields, on the same terms. An earlier reader would
    // draw a patrolling dragon parked at the origin of a path it cannot see,
    // with no shadow and no plume — dropped behaviour, refused all the same.
    if (version < 6) {
      for (final Object? raw in _list(decoded, 'overlays')) {
        if (raw is! Map<String, Object?>) continue;
        for (final String key in const <String>[
          'path',
          'breath',
          'cloud',
          'shadow',
          'depth',
          'faces',
        ]) {
          if (raw[key] != null) {
            throw AtlasLayoutException('$key needs schemaVersion 6');
          }
        }
      }
    }
    final List<AtlasNamedLandmark> landmarks = <AtlasNamedLandmark>[
      if (decoded['landmarks'] != null)
        for (final (int i, Object? raw) in _list(decoded, 'landmarks').indexed)
          _namedLandmark(raw, i),
    ];
    final Map<String, AtlasLandmark> kindMarkers = <String, AtlasLandmark>{};
    if (decoded['kindMarkers'] != null) {
      final Map<String, Object?> raw = _object(decoded, 'kindMarkers');
      for (final MapEntry<String, Object?> entry in raw.entries) {
        if (!atlasMarkerKinds.contains(entry.key)) {
          throw AtlasLayoutException(
            'kindMarkers.${entry.key} is not one of '
            '${atlasMarkerKinds.join(', ')}',
          );
        }
        kindMarkers[entry.key] = _landmarkArt(
          entry.value,
          'kindMarkers.${entry.key}',
        );
      }
    }

    final List<AtlasRumorSpot> rumors = <AtlasRumorSpot>[
      if (decoded['rumors'] != null)
        for (final (int i, Object? raw) in _list(decoded, 'rumors').indexed)
          _rumor(raw, i),
    ];
    final Set<String> rumorIds = <String>{};
    for (final AtlasRumorSpot rumor in rumors) {
      if (!rumorIds.add(rumor.id.value)) {
        throw AtlasLayoutException(
          'rumors lists ${rumor.id.value} more than once',
        );
      }
    }

    return AtlasLayout(
      worldWidth: worldWidth,
      worldHeight: worldHeight,
      scale: scale,
      tiles: List<AtlasTile>.unmodifiable(tiles),
      locations: List<AtlasLocation>.unmodifiable(locations),
      overlays: List<AtlasOverlay>.unmodifiable(overlays),
      props: List<AtlasProp>.unmodifiable(props),
      routes: List<AtlasRoute>.unmodifiable(routes),
      landmarks: List<AtlasNamedLandmark>.unmodifiable(landmarks),
      kindMarkers: Map<String, AtlasLandmark>.unmodifiable(kindMarkers),
      rumors: List<AtlasRumorSpot>.unmodifiable(rumors),
      schemaVersion: version,
    );
  }

  static AtlasRumorSpot _rumor(Object? raw, int index) {
    if (raw is! Map<String, Object?>) {
      throw AtlasLayoutException('rumors[$index] must be an object');
    }
    final String at = 'rumors[$index]';
    final String rawId = _string(raw, 'id', within: at);
    final ContentIdParse parsed = ContentId.parse(rawId);
    final ContentId? id = parsed.id;
    if (id == null) {
      throw AtlasLayoutException('$at.id: ${parsed.explanation}');
    }
    return AtlasRumorSpot(
      id: id,
      x: _number(raw, 'x', within: at),
      y: _number(raw, 'y', within: at),
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
      final AtlasOverlayPath? line = overlay.path;
      if (line == null) {
        if (overlay.x < 0 ||
            overlay.y < 0 ||
            overlay.x > worldWidth ||
            overlay.y > worldHeight) {
          problems.add('overlay ${overlay.asset} starts outside the world');
        }
        continue;
      }
      // A path overlay has no origin to check, so every waypoint is checked
      // instead: one point off the surface is a creature that walks off the
      // edge of the world for part of its lap, which no single-coordinate
      // test would have caught.
      for (final (int i, ({double x, double y}) p) in line.points.indexed) {
        if (p.x < 0 || p.y < 0 || p.x > worldWidth || p.y > worldHeight) {
          problems.add(
            'overlay ${overlay.asset} waypoint $i lies outside the '
            '$worldWidth×$worldHeight world at (${p.x}, ${p.y})',
          );
        }
      }
    }

    // Landmarks. A landmark is scenery with a name, so the faults worth
    // catching are the ones that would make it look like a place: a duplicate
    // id (drawn twice), an id a location already owns (a place with a second,
    // dead label), or a coordinate off the surface (a name clipped away).
    final Set<String> landmarkIds = <String>{};
    final Set<String> placeIds = <String>{
      ...known,
      for (final AtlasLocation location in locations) location.id.value,
    };
    for (final AtlasNamedLandmark landmark in landmarks) {
      if (!landmarkIds.add(landmark.id)) {
        problems.add('landmarks lists ${landmark.id} more than once');
      }
      if (placeIds.contains(landmark.id)) {
        problems.add(
          'landmark ${landmark.id} uses the id of a place the player can '
          'travel to',
        );
      }
      if (landmark.name.trim().isEmpty) {
        problems.add('landmark ${landmark.id} has no name to draw');
      }
      if (landmark.x < 0 ||
          landmark.y < 0 ||
          landmark.x > worldWidth ||
          landmark.y > worldHeight) {
        problems.add(
          'landmark ${landmark.id} lies outside the $worldWidth×$worldHeight '
          'world at (${landmark.x}, ${landmark.y})',
        );
      }
    }
    for (final AtlasRumorSpot rumor in rumors) {
      if (rumor.x < 0 ||
          rumor.y < 0 ||
          rumor.x > worldWidth ||
          rumor.y > worldHeight) {
        problems.add(
          'rumor ${rumor.id.value} lies outside the world at '
          '(${rumor.x}, ${rumor.y})',
        );
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

  static bool _bool(Map<String, Object?> parent, String key, {String? within}) {
    final Object? value = parent[key];
    if (value is bool) return value;
    throw AtlasLayoutException('${_at(key, within)} must be true or false');
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
    final AtlasLandmark? landmark = landmarkRaw == null
        ? null
        : _landmarkArt(landmarkRaw, '$at.landmark');
    return AtlasLocation(
      id: id,
      x: _number(raw, 'x', within: at),
      y: _number(raw, 'y', within: at),
      hitRadius: _number(raw, 'hitRadius', within: at),
      landmark: landmark,
    );
  }

  /// The `{asset, width, height, anchorX, anchorY}` block, wherever it appears
  /// — a location's landmark, a named landmark's art, a kind glyph. [at] is
  /// the JSON path, so the message names the caller's field rather than this
  /// helper's.
  static AtlasLandmark _landmarkArt(Object? raw, String at) {
    if (raw is! Map<String, Object?>) {
      throw AtlasLayoutException('$at must be an object or null');
    }
    final AtlasLandmark art = AtlasLandmark(
      asset: _string(raw, 'asset', within: at),
      width: _int(raw, 'width', within: at),
      height: _int(raw, 'height', within: at),
      anchorX: _int(raw, 'anchorX', within: at),
      anchorY: _int(raw, 'anchorY', within: at),
    );
    if (art.width <= 0 || art.height <= 0) {
      throw AtlasLayoutException('$at size must be positive');
    }
    return art;
  }

  static AtlasNamedLandmark _namedLandmark(Object? raw, int index) {
    if (raw is! Map<String, Object?>) {
      throw AtlasLayoutException('landmarks[$index] must be an object');
    }
    final String at = 'landmarks[$index]';
    final String tierWire = _string(raw, 'tier', within: at);
    final AtlasLandmarkTier? tier = AtlasLandmarkTier.ofWire(tierWire);
    if (tier == null) {
      throw AtlasLayoutException(
        '$at.tier "$tierWire" is not one of '
        '${AtlasLandmarkTier.values.map((AtlasLandmarkTier t) => t.wireName).join(', ')}',
      );
    }
    final Object? markerRaw = raw['marker'];
    return AtlasNamedLandmark(
      // `_string` already refuses an empty name and an empty id.
      id: _string(raw, 'id', within: at),
      name: _string(raw, 'name', within: at),
      x: _number(raw, 'x', within: at),
      y: _number(raw, 'y', within: at),
      tier: tier,
      marker: markerRaw == null ? null : _landmarkArt(markerRaw, '$at.marker'),
    );
  }

  static AtlasOverlay _overlay(Object? raw, int index) {
    if (raw is! Map<String, Object?>) {
      throw AtlasLayoutException('overlays[$index] must be an object');
    }
    final String at = 'overlays[$index]';
    // A path overlay carries none of the placement fields: its position comes
    // from the line, and `drift` is not merely unused but forbidden below.
    final Object? pathRaw = raw['path'];
    final Map<String, Object?>? driftRaw = raw['drift'] == null && pathRaw != null
        ? null
        : _object(raw, 'drift', within: at);
    final Map<String, Object?>? travelRaw = raw['travel'] == null
        ? null
        : _object(raw, 'travel', within: at);
    final AtlasOverlayPath? path = pathRaw == null
        ? null
        : _overlayPath(pathRaw, at);
    final AtlasOverlay overlay = AtlasOverlay(
      asset: _string(raw, 'asset', within: at),
      x: raw['x'] == null && path != null ? 0 : _number(raw, 'x', within: at),
      y: raw['y'] == null && path != null ? 0 : _number(raw, 'y', within: at),
      width: _int(raw, 'width', within: at),
      height: _int(raw, 'height', within: at),
      frameCount: _int(raw, 'frames', within: at),
      frameMillis: _int(raw, 'frameMillis', within: at),
      driftX: driftRaw == null ? 0 : _number(driftRaw, 'x', within: '$at.drift'),
      driftY: driftRaw == null ? 0 : _number(driftRaw, 'y', within: '$at.drift'),
      opacity: raw['opacity'] == null ? 1 : _number(raw, 'opacity', within: at),
      intervalMillis: raw['intervalMillis'] == null
          ? 0
          : _int(raw, 'intervalMillis', within: at),
      travelX: travelRaw == null ? 0 : _number(travelRaw, 'x', within: '$at.travel'),
      travelY: travelRaw == null ? 0 : _number(travelRaw, 'y', within: '$at.travel'),
      playLoops: raw['playLoops'] == null
          ? 1
          : _int(raw, 'playLoops', within: at),
      depth: raw['depth'] == null ? 0 : _int(raw, 'depth', within: at),
      facing: _facing(raw, at),
      path: path,
      breath: raw['breath'] == null
          ? null
          : _follower(raw['breath'], '$at.breath'),
      cloud: raw['cloud'] == null
          ? null
          : _follower(raw['cloud'], '$at.cloud'),
      shadow: raw['shadow'] == null
          ? null
          : _shadow(raw['shadow'], '$at.shadow'),
    );
    if (overlay.depth < 0 || overlay.depth > 2) {
      throw AtlasLayoutException(
        '$at.depth must be 0 (ground), 1 (low air) or 2 (high air)',
      );
    }
    if (path != null) {
      if (raw['drift'] != null ||
          raw['travel'] != null ||
          raw['intervalMillis'] != null ||
          raw['x'] != null ||
          raw['y'] != null) {
        throw AtlasLayoutException(
          '$at declares a path and also x/y, drift, travel or intervalMillis. '
          'A path says where the sprite is at every instant, and it is always '
          'present: there is nothing left for the others to say',
        );
      }
      for (final int k in path.breathAt) {
        if (k < 0 || k >= path.points.length) {
          throw AtlasLayoutException(
            '$at.path.breathAt names waypoint $k, and the line has '
            '${path.points.length}',
          );
        }
      }
      if (path.breathAt.isNotEmpty && overlay.breath == null) {
        throw AtlasLayoutException(
          '$at.path.breathAt fires a breath the overlay does not declare',
        );
      }
    } else if (overlay.breath != null || overlay.cloud != null) {
      throw AtlasLayoutException(
        '$at declares a follower without a path; a follower has no coordinate '
        'of its own and cannot stand anywhere on its own',
      );
    }
    if (overlay.playLoops < 1) {
      throw AtlasLayoutException('$at.playLoops must be at least 1');
    }
    if ((overlay.travelX != 0 || overlay.travelY != 0) &&
        overlay.intervalMillis == 0) {
      throw AtlasLayoutException(
        '$at.travel needs intervalMillis: a journey is measured from the '
        'start of a play, and a continuous loop has none',
      );
    }
    if ((overlay.travelX != 0 || overlay.travelY != 0) &&
        (overlay.driftX != 0 || overlay.driftY != 0)) {
      throw AtlasLayoutException(
        '$at declares both travel and drift; one sprite has one kind of '
        'motion',
      );
    }
    if (overlay.opacity <= 0 || overlay.opacity > 1) {
      throw AtlasLayoutException('$at.opacity must be in (0, 1]');
    }
    if (overlay.frameCount < 1 || overlay.frameMillis < 1) {
      throw AtlasLayoutException(
        '$at needs at least one frame of positive length',
      );
    }
    if (overlay.intervalMillis < 0) {
      throw AtlasLayoutException('$at.intervalMillis must not be negative');
    }
    if (overlay.width <= 0 || overlay.height <= 0) {
      throw AtlasLayoutException('$at size must be positive');
    }
    return overlay;
  }

  static AtlasFacing _facing(Map<String, Object?> raw, String at) {
    final Object? value = raw['faces'];
    if (value == null) return AtlasFacing.east;
    return switch (value) {
      'east' => AtlasFacing.east,
      'west' => AtlasFacing.west,
      _ => throw AtlasLayoutException('$at.faces must be "east" or "west"'),
    };
  }

  static AtlasOverlayPath _overlayPath(Object? raw, String host) {
    final String at = '$host.path';
    if (raw is! Map<String, Object?>) {
      throw AtlasLayoutException('$at must be an object');
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
    if (points.length < 2) {
      throw AtlasLayoutException(
        '$at needs at least two waypoints; one point is a place, not a patrol',
      );
    }
    final double speed = _number(raw, 'speed', within: at);
    if (speed <= 0) {
      throw AtlasLayoutException('$at.speed must be positive');
    }
    final Object? modeRaw = raw['mode'];
    final AtlasPathMode mode = switch (modeRaw) {
      null || 'loop' => AtlasPathMode.loop,
      'pingpong' => AtlasPathMode.pingpong,
      _ => throw AtlasLayoutException('$at.mode must be "loop" or "pingpong"'),
    };
    final List<int> breathAt = <int>[];
    if (raw['breathAt'] != null) {
      for (final (int i, Object? k) in _list(
        raw,
        'breathAt',
        within: at,
      ).indexed) {
        if (k is! int) {
          throw AtlasLayoutException('$at.breathAt[$i] must be a waypoint index');
        }
        breathAt.add(k);
      }
    }
    AtlasOverlayBob? bob;
    if (raw['bob'] != null) {
      final Map<String, Object?> bobRaw = _object(raw, 'bob', within: at);
      bob = AtlasOverlayBob(
        amplitude: _number(bobRaw, 'amplitude', within: '$at.bob'),
        periodMillis: _int(bobRaw, 'periodMillis', within: '$at.bob'),
      );
      if (bob.periodMillis < 1) {
        throw AtlasLayoutException('$at.bob.periodMillis must be positive');
      }
    }
    return AtlasOverlayPath(
      points: List<({double x, double y})>.unmodifiable(points),
      speed: speed,
      mode: mode,
      flip: raw['flip'] == null ? false : _bool(raw, 'flip', within: at),
      phaseMillis: raw['phaseMillis'] == null
          ? 0
          : _int(raw, 'phaseMillis', within: at),
      breathAt: List<int>.unmodifiable(breathAt),
      bob: bob,
    );
  }

  static AtlasOverlayFollower _follower(Object? raw, String at) {
    if (raw is! Map<String, Object?>) {
      throw AtlasLayoutException('$at must be an object');
    }
    final Map<String, Object?> offset = _object(raw, 'offset', within: at);
    final AtlasOverlayFollower follower = AtlasOverlayFollower(
      asset: _string(raw, 'asset', within: at),
      width: _int(raw, 'width', within: at),
      height: _int(raw, 'height', within: at),
      frameCount: _int(raw, 'frames', within: at),
      frameMillis: _int(raw, 'frameMillis', within: at),
      offsetX: _int(offset, 'x', within: '$at.offset'),
      offsetY: _int(offset, 'y', within: '$at.offset'),
      opacity: raw['opacity'] == null ? 1 : _number(raw, 'opacity', within: at),
    );
    if (follower.width <= 0 || follower.height <= 0) {
      throw AtlasLayoutException('$at size must be positive');
    }
    if (follower.frameCount < 1 || follower.frameMillis < 1) {
      throw AtlasLayoutException(
        '$at needs at least one frame of positive length',
      );
    }
    if (follower.opacity <= 0 || follower.opacity > 1) {
      throw AtlasLayoutException('$at.opacity must be in (0, 1]');
    }
    return follower;
  }

  static AtlasOverlayShadow _shadow(Object? raw, String at) {
    if (raw is! Map<String, Object?>) {
      throw AtlasLayoutException('$at must be an object');
    }
    final AtlasOverlayShadow shadow = AtlasOverlayShadow(
      dx: _number(raw, 'dx', within: at),
      dy: _number(raw, 'dy', within: at),
      opacity: _number(raw, 'opacity', within: at),
    );
    if (shadow.opacity <= 0 || shadow.opacity > 1) {
      throw AtlasLayoutException('$at.opacity must be in (0, 1]');
    }
    return shadow;
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
