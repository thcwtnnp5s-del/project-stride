/// The layers of the World Atlas, bottom to top, each drawn in **world pixels**.
///
/// The viewport (`atlas_viewport.dart`) puts these in one world-sized stack and
/// pans and zooms the stack. Each layer is its own [RepaintBoundary], so a pan
/// re-composites five layers rather than re-rasterising a 768 × 1280 picture,
/// and the one layer that animates — the overlays — repaints alone.
///
/// ## What is drawn in code, and what is not
///
/// `RULES.md` A-1/A-2: PixelLab makes the art. Everything below that depicts
/// the *world* is a PNG placed at a coordinate — the base tiles, the landmarks,
/// the drifting overlays. What is drawn here is **interface chrome only**: a
/// ring under a place, a dotted line where content declares a road, a text
/// plate under a name. None of it depicts terrain, a building or weather.
///
/// ## Not a joystick, still
///
/// There is no avatar on this surface, nothing that can be dragged, and no
/// figure that walks. The current location is marked by a pulsing ring, which
/// is a caption in the shape of a circle: it points at a place and it does not
/// move. Tapping a place *selects* it — the travel control lives in the panel
/// beneath, and it exists only because `TravelTo` does.
library;

import 'package:flutter/scheduler.dart'
    show SchedulerBinding, SchedulerPhase, Ticker;
import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

// The named-landmark and kind-glyph types are not in the session's re-export
// list — a landmark is packaging data the session has no opinion about — so
// they are imported from the layout library itself. Same library the session
// re-exports the rest from, so no symbol is defined twice.
import '../../../../runtime/atlas_layout.dart'
    show
        AtlasLandmarkTier,
        AtlasNamedLandmark,
        AtlasOverlayFollower,
        AtlasOverlayShadow;
import '../../../../runtime/stride_session.dart';
import '../../../components/pixel_asset.dart';
import '../../../icons/atlas_assets.dart';
import '../../../theme/stride_colors.dart';
import '../../../theme/stride_metrics.dart';
import '../../../theme/stride_typography.dart';
import '../travel_pacing.dart';
import 'atlas_layout.dart';
import 'atlas_place_info.dart';

// ---------------------------------------------------------------------- base

/// The geography: one image, or a grid of tiles, at the layout's scale.
class AtlasBaseLayer extends StatelessWidget {
  const AtlasBaseLayer({super.key, required this.scene});

  final AtlasScene scene;

  @override
  Widget build(BuildContext context) {
    final int scale = scene.layout.scale;
    return RepaintBoundary(
      child: SizedBox(
        width: scene.worldWidth,
        height: scene.worldHeight,
        child: Stack(
          children: <Widget>[
            for (final AtlasTile tile in scene.layout.tiles)
              Positioned(
                left: (tile.x * scale).toDouble(),
                top: (tile.y * scale).toDouble(),
                child: PixelAsset(
                  assetPath: AtlasAssets.pathFor(tile.asset),
                  nativeWidth: tile.width,
                  nativeHeight: tile.height,
                  scale: scale,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- routes

/// A dotted line along every road content declares. Muted, never teal.
///
/// The lines say *a road exists*; they carry no state. A road to a place the
/// player cannot afford looks exactly like one they can, because affordability
/// is the panel's sentence to say and a colour-coded road would be an
/// availability system drawn on the ground.
///
/// ## The route preview, and why it is not a second rule
///
/// When a place other than *here* is selected, the edges of the walk that
/// reaches it are drawn **heavier and brighter** and every other road keeps
/// today's weight. That is emphasis on a path the scene already computed from
/// content adjacency ([AtlasScene.routeSummary]), shown so the player can see
/// which roads the journey uses before reading the sentence that says so. It
/// grants nothing, enables nothing, and is absent when no chain of roads
/// reaches the selection — the map does not invent a way.
///
/// Still not teal (L-16): a road is not walking, and a highlighted road is not
/// a quantity of steps. The emphasis is weight and brightness only.
class AtlasRouteLayer extends StatelessWidget {
  const AtlasRouteLayer({
    super.key,
    required this.scene,
    required this.zoom,
    this.way,
  });

  final AtlasScene scene;

  /// The camera's zoom. The dots and their pitch counter-scale below 1 dp per
  /// world pixel ([AtlasMarkerSpec.chromeScale]) so the previewed walk stays a
  /// followable line at the survey floor instead of degenerating into dust.
  final double zoom;

  /// The walk to the selected place, or null when the selection is *here* or
  /// unreachable. Nothing highlights in that case.
  final AtlasWay? way;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      child: CustomPaint(
        size: Size(scene.worldWidth, scene.worldHeight),
        painter: _RoutePainter(scene, <String>{
          for (final AtlasEdge edge in way?.edges ?? const <AtlasEdge>[])
            edge.key,
        }, AtlasMarkerSpec.chromeScale(zoom)),
      ),
    ),
  );
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.scene, this.highlighted, this.chrome);

  final AtlasScene scene;

  /// [AtlasEdge.key] for every edge on the previewed walk.
  final Set<String> highlighted;

  /// The counter-scale every dot and the pitch are multiplied by, 1 at and
  /// above the authored reading ([AtlasMarkerSpec.chromeScale]).
  final double chrome;

  /// World pixels between dot centres, and the dot's side. Squares rather than
  /// round dots so the line sits in the same pixel language as the art under
  /// it.
  static const double _pitch = 10;
  static const double _dot = 3;

  /// The dark square under each dot, one world pixel proud on every side. A
  /// light dot with only a drop shadow vanished on Frostmere's snow and the
  /// pale rock above the mine (device review, checklist item 4); a full dark
  /// contour is what every sprite on the atlas carries for the same reason,
  /// and it costs the line nothing on grass or forest.
  static const double _contour = _dot + 2;

  /// The previewed walk's dots: one world pixel bigger and fully opaque, with
  /// a contour that grows with them. Big enough to follow with the eye at 1×,
  /// small enough that the road is still a dotted line rather than a ribbon.
  static const double _dotOnWay = 5;
  static const double _contourOnWay = _dotOnWay + 2;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint contour = Paint()..color = const Color(0xB314120F);
    final Paint ink = Paint()..color = const Color(0xD9F0E7D8);
    final Paint contourOnWay = Paint()..color = const Color(0xE614120F);
    final Paint inkOnWay = Paint()..color = const Color(0xFFF0E7D8);
    final double pitch = _pitch * chrome;
    for (final AtlasEdge edge in scene.edges) {
      final bool onWay = highlighted.contains(edge.key);
      final double dotSide = (onWay ? _dotOnWay : _dot) * chrome;
      final double contourSide = (onWay ? _contourOnWay : _contour) * chrome;
      final Paint dotPaint = onWay ? inkOnWay : ink;
      final Paint contourPaint = onWay ? contourOnWay : contour;
      // Follow the drawn course where the layout gives one — the dots then
      // ride the track the base art paints — otherwise the straight line.
      final AtlasRoute? course = scene.layout.routeBetween(
        edge.a.id,
        edge.b.id,
      );
      final List<Offset> points = <Offset>[Offset(edge.a.x, edge.a.y)];
      if (course != null) {
        final bool forward = course.from == edge.a.id;
        final Iterable<({double x, double y})> mids = forward
            ? course.points
            : course.points.reversed;
        for (final ({double x, double y}) p in mids) {
          points.add(Offset(p.x, p.y));
        }
      }
      points.add(Offset(edge.b.x, edge.b.y));

      // One dot cadence along the whole polyline, so a corner does not bunch
      // or gap the dots. Start a pitch in so no dot sits under either marker.
      double carry = pitch;
      double total = 0;
      for (int i = 1; i < points.length; i++) {
        total += (points[i] - points[i - 1]).distance;
      }
      double walked = 0;
      for (int i = 1; i < points.length; i++) {
        final Offset a = points[i - 1];
        final Offset b = points[i];
        final double length = (b - a).distance;
        if (length == 0) continue;
        final Offset unit = (b - a) / length;
        double d = carry;
        while (d < length) {
          if (walked + d > total - pitch / 2) break;
          final Offset c = a + unit * d;
          final Rect dot = Rect.fromCenter(
            center: Offset(c.dx.roundToDouble(), c.dy.roundToDouble()),
            width: dotSide,
            height: dotSide,
          );
          canvas.drawRect(
            Rect.fromCenter(
              center: dot.center,
              width: contourSide,
              height: contourSide,
            ),
            contourPaint,
          );
          canvas.drawRect(dot, dotPaint);
          d += pitch;
        }
        carry = d - length;
        walked += length;
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.scene != scene ||
      old.chrome != chrome ||
      old.highlighted.length != highlighted.length ||
      !old.highlighted.containsAll(highlighted);
}

// ----------------------------------------------------------------- landmarks

/// A landmark PNG standing on each place that has one, and on each named piece
/// of geography that has one. Nothing is drawn where there is no art — the
/// marker and label carry it until the art arrives.
///
/// Wholly static: no ticker, no state, one repaint boundary. It does not
/// hit-test, which is what makes a named landmark scenery rather than a place
/// (`WORLD_REWARD_DEPTH_01.md` §7).
///
/// In the [overview] — zoomed out past the opening view — the scatter props
/// and the named landmarks' marker art are not built at all: at survey
/// distance the painted geography carries them, and a 20 px cairn drawn at a
/// quarter of its reading size is noise rather than information. A location's
/// own landmark building stays at every zoom — it is the visual identity of a
/// place the player can actually walk to, and the place's label and ring stay
/// with it.
class AtlasLandmarkLayer extends StatelessWidget {
  const AtlasLandmarkLayer({
    super.key,
    required this.scene,
    required this.overview,
  });

  final AtlasScene scene;

  /// Whether the camera is out past `AtlasZoom.overviewBelow` — the viewport
  /// owns the threshold; the layers only obey it.
  final bool overview;

  @override
  Widget build(BuildContext context) {
    final int scale = scene.layout.scale;
    return RepaintBoundary(
      child: IgnorePointer(
        child: SizedBox(
          width: scene.worldWidth,
          height: scene.worldHeight,
          child: Stack(
            children: <Widget>[
              // Scatter props first, so a landmark always paints over one.
              if (!overview)
                for (final AtlasProp prop in scene.layout.props)
                  Positioned(
                    left: prop.x - prop.anchorX * scale,
                    top: prop.y - prop.anchorY * scale,
                    child: PixelAsset(
                      assetPath: AtlasAssets.pathFor(prop.asset),
                      nativeWidth: prop.width,
                      nativeHeight: prop.height,
                      scale: scale,
                    ),
                  ),
              // Named geography, under the places: a ruin never paints over a
              // settlement the player can walk to.
              if (!overview)
                for (final AtlasNamedLandmark named in scene.layout.landmarks)
                  if (named.marker case final AtlasLandmark art)
                    Positioned(
                      left: named.x - art.anchorX * scale,
                      top: named.y - art.anchorY * scale,
                      child: PixelAsset(
                        assetPath: AtlasAssets.pathFor(art.asset),
                        nativeWidth: art.width,
                        nativeHeight: art.height,
                        scale: scale,
                      ),
                    ),
              for (final AtlasNode node in scene.nodes)
                if (scene.layout.locationFor(node.id)?.landmark
                    case final AtlasLandmark landmark)
                  Positioned(
                    left: node.x - landmark.anchorX * scale,
                    top: node.y - landmark.anchorY * scale,
                    child: PixelAsset(
                      assetPath: AtlasAssets.pathFor(landmark.asset),
                      nativeWidth: landmark.width,
                      nativeHeight: landmark.height,
                      scale: scale,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ overlays

/// Small looping sprites drifting over the geography — cloud, mist, smoke.
///
/// One ticker drives every overlay, so a dozen clouds cost one frame callback,
/// and the whole layer is one repaint boundary. The ticker obeys [TickerMode]:
/// the viewport wraps this in one that is disabled unless the app is resumed,
/// so nothing here runs in the background or in a test that has not asked for
/// motion.
class AtlasOverlayLayer extends StatefulWidget {
  const AtlasOverlayLayer({super.key, required this.scene});

  final AtlasScene scene;

  @override
  State<AtlasOverlayLayer> createState() => _AtlasOverlayLayerState();
}

class _AtlasOverlayLayerState extends State<AtlasOverlayLayer>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _elapsed = Duration.zero;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    // No ticker at all for a layout with nothing to animate. The shipped
    // layout carries ~30 overlays (flurries, mist, birds, smoke, the
    // volcano), so this ticker runs whenever the World tab is frontmost —
    // and ONLY then: the shell's per-tab [TickerMode] (Iteration 02,
    // PERF-A) is what stops it scheduling 120 Hz frames from a hidden tab
    // now that screens stay alive across tab switches.
    if (widget.scene.layout.overlays.isNotEmpty) {
      _ticker = createTicker(_onTick)..start();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    for (final AtlasOverlay overlay in widget.scene.layout.overlays) {
      for (final String path in AtlasAssets.framePaths(
        overlay.asset,
        overlay.frameCount,
      )) {
        precacheImage(AssetImage(path), context);
      }
      // Followers are drawn from the host's frame callback, so their frames
      // have to be warm by then too: a plume that decodes on the tick it
      // fires is a plume the player sees arrive late.
      for (final AtlasOverlayFollower? follower in <AtlasOverlayFollower?>[
        overlay.breath,
        overlay.cloud,
      ]) {
        if (follower == null) continue;
        for (final String path in AtlasAssets.framePaths(
          follower.asset,
          follower.frameCount,
        )) {
          precacheImage(AssetImage(path), context);
        }
      }
    }
  }

  void _onTick(Duration elapsed) {
    // Coarse: repaint when some overlay's frame index or drift position has
    // moved by a whole world pixel, not on every vsync.
    final Duration previous = _elapsed;
    _elapsed = elapsed;
    if (_frameKey(previous) != _frameKey(elapsed)) setState(() {});
  }

  /// A cheap fingerprint of everything the paint depends on at [t].
  int _frameKey(Duration t) {
    int key = 0;
    for (final AtlasOverlay overlay in widget.scene.layout.overlays) {
      // Visibility first: an intermittent overlay appearing or withdrawing
      // is a repaint even when its frame index happens to match.
      key = key * 31 + (overlay.visibleAt(t) ? 1 : 0);
      key = key * 31 + overlay.frameIndexAt(t);
      // One position computation per overlay per tick, not two — this runs
      // every vsync while the tab is frontmost (PERF-A cheap win).
      final Offset at = _driftPosition(overlay, t);
      key = key * 31 + at.dx.floor();
      key = key * 31 + at.dy.floor();
      // v6: a creature that has turned round, or has just opened its jaw, has
      // changed what is on screen without moving a whole world pixel.
      key = key * 31 + (overlay.flippedAt(t) ? 1 : 0);
      final ({int index, int millis})? breath = overlay.breathPhaseAt(t);
      key = key * 31 + (breath == null ? 0 : 1 + breath.index);
      final AtlasOverlayFollower? plume = overlay.breath;
      if (breath != null && plume != null) {
        key = key * 31 + plume.frameIndexAt(breath.millis);
      }
      final AtlasOverlayFollower? cloud = overlay.cloud;
      if (cloud != null) {
        key = key * 31 + cloud.frameIndexAt(t.inMilliseconds);
      }
    }
    return key;
  }

  /// Where the sprite is at [t]. A drifting sprite wraps, re-entering from
  /// the opposite edge of the world once it has drifted off; a travelling
  /// sprite (v5) moves from its origin only while its play runs and stands
  /// at the origin again for every new play — the parser holds the two kinds
  /// of motion mutually exclusive.
  Offset _driftPosition(AtlasOverlay overlay, Duration t) {
    if (overlay.hasPath) {
      // v6: the line says where the sprite is, and at t = 0 the line says
      // points[0] — so a stopped ticker leaves every creature standing on its
      // first waypoint instead of erasing it (M-16).
      final ({double x, double y}) at = overlay.topLeftAt(
        t,
        widget.scene.layout.scale,
      );
      return Offset(at.x, at.y);
    }
    if (overlay.travelX != 0 || overlay.travelY != 0) {
      final double playSeconds = overlay.playMillisAt(t) / 1000;
      return Offset(
        overlay.x + overlay.travelX * playSeconds,
        overlay.y + overlay.travelY * playSeconds,
      );
    }
    final double seconds = t.inMicroseconds / Duration.microsecondsPerSecond;
    final double w = widget.scene.worldWidth;
    final double h = widget.scene.worldHeight;
    final int scale = widget.scene.layout.scale;
    final double spanX = w + overlay.width * scale;
    final double spanY = h + overlay.height * scale;
    double x = overlay.x + overlay.driftX * seconds;
    double y = overlay.y + overlay.driftY * seconds;
    if (overlay.driftX != 0) {
      x = (x % spanX + spanX) % spanX - overlay.width * scale;
    }
    if (overlay.driftY != 0) {
      y = (y % spanY + spanY) % spanY - overlay.height * scale;
    }
    return Offset(x, y);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  /// One overlay, positioned in world space, with its followers on it.
  ///
  /// The whole sprite — host, cloud under it, plume over it — is composed in
  /// unmirrored space and then flipped as one, so a follower's offset needs no
  /// second set of coordinates: mirroring the group about the host's centre
  /// *is* `x′ = host.width − offset.x − follower.width`, and the plume leaves
  /// the jaw in both directions because it cannot do anything else.
  Widget _overlaySprite(AtlasOverlay overlay, int scale) {
    final Offset at = _driftPosition(overlay, _elapsed);
    final ({int index, int millis})? breath = overlay.breathPhaseAt(_elapsed);
    final AtlasOverlayFollower? plume = overlay.breath;
    final AtlasOverlayFollower? cloud = overlay.cloud;

    Widget follower(AtlasOverlayFollower f, int frame) => Positioned(
      left: (f.offsetX * scale).toDouble(),
      top: (f.offsetY * scale).toDouble(),
      child: Opacity(
        opacity: f.opacity,
        child: PixelAsset(
          assetPath: AtlasAssets.framePath(f.asset, frame),
          nativeWidth: f.width,
          nativeHeight: f.height,
          scale: scale,
        ),
      ),
    );

    Widget body = PixelAsset(
      assetPath: AtlasAssets.framePath(
        overlay.asset,
        overlay.frameIndexAt(_elapsed),
      ),
      nativeWidth: overlay.width,
      nativeHeight: overlay.height,
      scale: scale,
    );

    if (cloud != null || (plume != null && breath != null)) {
      body = SizedBox(
        width: (overlay.width * scale).toDouble(),
        height: (overlay.height * scale).toDouble(),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            // The storm is under the drake that carries it: a bolt is thrown
            // from inside the cloud, not from in front of it.
            if (cloud != null)
              follower(cloud, cloud.frameIndexAt(_elapsed.inMilliseconds)),
            Positioned(left: 0, top: 0, child: body),
            if (plume != null && breath != null)
              follower(plume, plume.frameIndexAt(breath.millis)),
          ],
        ),
      );
    }

    if (overlay.flippedAt(_elapsed)) {
      body = Transform.flip(flipX: true, child: body);
    }

    return Positioned(
      left: at.dx.floorToDouble(),
      top: at.dy.floorToDouble(),
      child: Opacity(
        // The compositor multiplier: the sprites are opaque art and the
        // layout says how faint each one sits.
        opacity: overlay.opacity,
        child: body,
      ),
    );
  }

  /// The host's current frame repainted flat black and dropped below it.
  ///
  /// No art and no second asset: the shadow is the pose, so it can never
  /// disagree with the creature casting it.
  Widget _overlayShadow(
    AtlasOverlay overlay,
    AtlasOverlayShadow shadow,
    int scale,
  ) {
    final Offset at = _driftPosition(overlay, _elapsed);
    Widget body = ColorFiltered(
      colorFilter: const ColorFilter.mode(Color(0xFF000000), BlendMode.srcATop),
      child: PixelAsset(
        assetPath: AtlasAssets.framePath(
          overlay.asset,
          overlay.frameIndexAt(_elapsed),
        ),
        nativeWidth: overlay.width,
        nativeHeight: overlay.height,
        scale: scale,
      ),
    );
    if (overlay.flippedAt(_elapsed)) {
      body = Transform.flip(flipX: true, child: body);
    }
    return Positioned(
      left: (at.dx + shadow.dx).floorToDouble(),
      top: (at.dy + shadow.dy).floorToDouble(),
      child: Opacity(opacity: shadow.opacity, child: body),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int scale = widget.scene.layout.scale;
    // v6 depth bands. Ground life paints in JSON array order exactly as it
    // always did; then every shadow, so a dragon's shadow falls across the
    // ground it is over; then low air, then high air. Nothing sorts by y —
    // this is a painted map, not a scene graph.
    final List<AtlasOverlay> drawn = <AtlasOverlay>[
      for (final AtlasOverlay overlay in widget.scene.layout.overlays)
        if (overlay.visibleAt(_elapsed)) overlay,
    ];
    return RepaintBoundary(
      child: IgnorePointer(
        child: SizedBox(
          width: widget.scene.worldWidth,
          height: widget.scene.worldHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // An intermittent overlay (v4 `intervalMillis`) is simply not
              // built during its quiet gap — the creature is gone, not
              // paused. A v6 path overlay has no gap and is always here: with
              // the ticker off it stands on its first waypoint rather than
              // vanishing, because an accessibility setting may take the
              // motion and not the world (M-16).
              for (final AtlasOverlay overlay in drawn)
                if (overlay.depth == 0) _overlaySprite(overlay, scale),
              for (final AtlasOverlay overlay in drawn)
                if (overlay.shadow case final AtlasOverlayShadow shadow)
                  _overlayShadow(overlay, shadow, scale),
              for (final AtlasOverlay overlay in drawn)
                if (overlay.depth == 1) _overlaySprite(overlay, scale),
              for (final AtlasOverlay overlay in drawn)
                if (overlay.depth == 2) _overlaySprite(overlay, scale),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- markers

/// The ring, the label and the hit target for every place; the pulse under the
/// current one; the highlight on the selected one.
///
/// This is the only layer that hit-tests. Tapping a marker calls [onSelect]
/// with the place's id and nothing else — no command is dispatched from the
/// map, ever. A drag that starts on a marker is a pan (the viewport's gesture
/// wins the arena the moment the pointer moves), so panning cannot select.
class AtlasMarkerLayer extends StatelessWidget {
  const AtlasMarkerLayer({
    super.key,
    required this.scene,
    required this.selected,
    required this.kinds,
    required this.zoom,
    required this.overview,
    required this.arrivalToken,
    required this.onSelect,
    this.travelFrom,
    this.travelLegPlaces,
    this.arrivalStanding = false,
    this.journey,
  });

  final AtlasScene scene;
  final ContentId? selected;

  /// The tracked Journey goal's destination, for its gold ring. Null when
  /// no journey is set.
  final ContentId? journey;

  /// What kind of place each node is, resolved once per build by the screen
  /// through `AtlasPlaceInfo.kindOf` — the single seam this stream reads place
  /// detail through.
  final Map<ContentId, AtlasPlaceKind> kinds;

  /// The camera's zoom. Labels counter-scale by it so type stays the size it
  /// was designed at, whatever the world is doing; the ring, pulse and burst
  /// chrome counter-scales below 1 dp per world pixel
  /// ([AtlasMarkerSpec.chromeScale]) so *here* still reads at the survey
  /// floor.
  final double zoom;

  /// Whether the camera is out past the overview threshold. Landmark captions
  /// hide out here — the place labels, glyphs, rings and the current marker
  /// are the survey's whole vocabulary.
  final bool overview;

  /// Bumped once per arrival. Zero means *nothing has arrived this session*,
  /// and no burst is built at all — opening the screen is not an arrival.
  final int arrivalToken;

  /// Where the last journey set out from, for the travel trace. Null before
  /// any journey this session.
  final AtlasNode? travelFrom;

  /// The last journey's committed legs, in order — the places walked
  /// through. The trace rides the drawn road of every hop instead of the
  /// straight line the single from→to pair used to fall back to on
  /// multi-leg journeys. Null keeps the pair behavior.
  final List<ContentId>? travelLegPlaces;

  /// Whether the journey's result line is still on screen — the pulse wears
  /// the warm arrival ink exactly as long as the panel is announcing the
  /// arrival, and not a frame longer (F4). Presentation state, read from the
  /// controller's held report.
  final bool arrivalStanding;

  final ValueChanged<ContentId> onSelect;

  @override
  Widget build(BuildContext context) {
    final double chrome = AtlasMarkerSpec.chromeScale(zoom);
    return SizedBox(
      width: scene.worldWidth,
      height: scene.worldHeight,
      child: Stack(
        children: <Widget>[
          // Named geography's labels first: a place's name always paints over
          // a landmark's, never the other way round.
          //
          // The overview drops the **minor** tier and keeps the far ones. A
          // ferry crossing and a stone bridge are the caption tier a survey
          // does without; a heard rumor and a distant tower are exactly what
          // a survey of the wider world exists to show (brief §62), and once
          // the world doubled north and south they became the only thing
          // telling a player there is anywhere else to go (§21–§22).
          //
          // This is the label LOD, and it is the whole of it: no other rule
          // is needed while the far tier is this sparse across 2752 × 3072
          // world pixels.
          RepaintBoundary(
            child: IgnorePointer(
              child: SizedBox(
                width: scene.worldWidth,
                height: scene.worldHeight,
                child: Stack(
                  children: <Widget>[
                    // The layout's named geography, plus every rumor the
                    // player has heard (`DECISIONS/0023` §8) — the scene
                    // joins the two so this layer needs no opinion.
                    for (final AtlasNamedLandmark named
                        in (overview
                            ? <AtlasNamedLandmark>[
                                ...scene.rumorLandmarks,
                                ...scene.namedLandmarks.where(
                                  (AtlasNamedLandmark l) =>
                                      l.tier == AtlasLandmarkTier.future,
                                ),
                              ]
                            : scene.namedLandmarks))
                      _LandmarkLabel(landmark: named, zoom: zoom),
                  ],
                ),
              ),
            ),
          ),
          // The kind glyph under the ring. Absent until the art lands, and its
          // absence is the shipped state: the ring is the fallback, not a
          // placeholder drawn in code (RULES.md A-1).
          if (scene.layout.kindMarkers.isNotEmpty)
            RepaintBoundary(
              child: IgnorePointer(
                child: SizedBox(
                  width: scene.worldWidth,
                  height: scene.worldHeight,
                  child: Stack(
                    children: <Widget>[
                      for (final AtlasNode node in scene.nodes)
                        if (scene.layout.markerForKind(
                              (kinds[node.id] ?? AtlasPlaceKind.wilds)
                                  .markerKind,
                            )
                            case final AtlasLandmark glyph)
                          Positioned(
                            left: node.x - glyph.anchorX * scene.layout.scale,
                            top: node.y - glyph.anchorY * scene.layout.scale,
                            child: PixelAsset(
                              assetPath: AtlasAssets.pathFor(glyph.asset),
                              nativeWidth: glyph.width,
                              nativeHeight: glyph.height,
                              scale: scene.layout.scale,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          // The rings, then the pulse, so every marker and label paints over it.
          Positioned.fill(
            child: RepaintBoundary(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _StaticRingPainter(
                    scene: scene,
                    selected: selected,
                    chrome: chrome,
                    journey: journey,
                  ),
                ),
              ),
            ),
          ),
          // The pulse and burst keep their layout box and are visually scaled
          // about its centre, so the marker's world coordinate stays their
          // centre at every zoom while *here* reads at the survey floor.
          Positioned(
            left: scene.current.x - AtlasMarkerSpec.pulseRadius,
            top: scene.current.y - AtlasMarkerSpec.pulseRadius,
            child: RepaintBoundary(
              child: IgnorePointer(
                child: Transform.scale(
                  scale: chrome,
                  child: AtlasPulse(
                    arrival: arrivalStanding && arrivalToken > 0,
                  ),
                ),
              ),
            ),
          ),
          // The travel trace: a spark running the walked road, played once
          // per arrival and then gone (brief §53's marker movement, 2–4 s).
          // Chrome, not art: a bright square on the road the route layer
          // already draws. Keyed on the token exactly as the burst is.
          if (arrivalToken > 0 && travelFrom != null)
            RepaintBoundary(
              child: IgnorePointer(
                child: AtlasTravelTrace(
                  key: ValueKey<int>(arrivalToken),
                  scene: scene,
                  from: travelFrom!,
                  to: scene.current,
                  legPlaces: travelLegPlaces,
                  chrome: chrome,
                ),
              ),
            ),
          if (arrivalToken > 0)
            Positioned(
              left: scene.current.x - AtlasMarkerSpec.burstRadius,
              top: scene.current.y - AtlasMarkerSpec.burstRadius,
              child: RepaintBoundary(
                child: IgnorePointer(
                  child: Transform.scale(
                    scale: chrome,
                    // Keyed on the token, so each arrival builds a fresh widget
                    // that plays once and then holds at nothing. A rebuild for
                    // any other reason — a pan, a selection — reuses it and
                    // replays nothing.
                    child: AtlasArrivalBurst(key: ValueKey<int>(arrivalToken)),
                  ),
                ),
              ),
            ),
          for (final AtlasNode node in scene.nodes) ...<Widget>[
            _MarkerLabel(node: node, scene: scene, zoom: zoom),
            _HitTarget(
              node: node,
              scene: scene,
              zoom: zoom,
              onSelect: onSelect,
            ),
          ],
        ],
      ),
    );
  }
}

/// The geometry of a marker, in world pixels. One place, so every marker on
/// the atlas is the same marker.
abstract final class AtlasMarkerSpec {
  const AtlasMarkerSpec._();

  /// The ring under every place.
  static const double ringRadius = 7;
  static const double ringStroke = 2;

  /// The current location's ring — heavier, and the pulse runs out from it.
  static const double currentRingRadius = 9;
  static const double currentRingStroke = 3;

  /// The solid centre inside the current location's ring: *here* as a
  /// bullseye. It is the one cue that does not depend on motion — the pulse
  /// stops under reduced motion and before the platform reports resumed — and
  /// it is what tells the current place from a selected one, whose extra ring
  /// is a hollow one outside. Chrome, not art: it depicts nothing but a point.
  static const double currentDotRadius = 3;

  /// The selection ring, drawn outside whichever ring the place already has.
  static const double selectedRadius = 14;
  static const double selectedStroke = 2;

  /// How far the pulse travels before it fades out.
  static const double pulseRadius = 26;

  /// How far the one-shot arrival burst travels. Further than the pulse, so
  /// arriving reads as an event rather than a faster breath.
  static const double burstRadius = 40;

  /// The label sits this far below the marker's centre.
  static const double labelOffset = 14;

  /// A label's plate hugs its name: the laid-out text width, ceiled to a
  /// whole dp, plus this much padding a side. Screen dp, like everything
  /// about a label. There is no fixed plate width — a fixed 184 dp plate,
  /// counter-scaled at the survey floor, painted a bar half the world wide
  /// over the geography it was meant to caption (device review).
  static const double labelPadX = 7;

  /// Above and below the line box. Tight, so the plate is a tag on the
  /// ground rather than a chip-height control.
  static const double labelPadY = 2;

  /// A landmark hangs closer to its coordinate than a place does: it has no
  /// ring to clear.
  static const double landmarkLabelOffset = 9;

  /// How much the interface chrome — rings, pulse, burst, route dots —
  /// counter-scales at [zoom].
  ///
  /// The world-pixel constants above were designed when a world pixel was a
  /// logical pixel, so they are really **dp figures**: a 9 dp ring reads, a
  /// 2.25 dp one does not. Below 1 dp per world pixel the chrome therefore
  /// grows by `1 / zoom` in world terms and displays at its authored dp size
  /// — which is what keeps the current-place bullseye and the previewed walk
  /// legible at the survey floor, on any layout scale. At and above 1 the
  /// factor is 1 and the chrome scales with the world, exactly as it always
  /// has on the shipped layout.
  ///
  /// Labels are not chrome for this purpose: they already counter-scale fully
  /// (`_WorldLabel`), and the art — glyphs, landmarks, props — is never
  /// resampled to solve a legibility problem (`RULES.md` A-2); the overview
  /// LOD hides the small art instead.
  static double chromeScale(double zoom) => zoom < 1 ? 1 / zoom : 1;
}

/// The rings that do not move: one per place, a heavier one under the current
/// place, and the selection ring. Redrawn only when the selection changes.
class _StaticRingPainter extends CustomPainter {
  const _StaticRingPainter({
    required this.scene,
    required this.selected,
    required this.chrome,
    this.journey,
  });

  final AtlasScene scene;
  final ContentId? selected;

  /// The tracked Journey goal's destination, or null when none is set — it
  /// wears a gold ring so the place the player committed to walking toward
  /// is findable at a glance (Fable V2 Iteration 02, GAME-A #4). The gold
  /// is `goalActive`, the goal hue, and nothing else on the atlas uses it;
  /// chrome, not art, exactly as every ring here.
  final ContentId? journey;

  /// [AtlasMarkerSpec.chromeScale] for the current zoom: every radius and
  /// stroke is multiplied by it so the rings hold their authored dp size when
  /// the world shrinks under them.
  final double chrome;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint outline = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xE614120F);
    final Paint ink = Paint()
      ..style = PaintingStyle.stroke
      ..color = StrideColors.textPrimary;
    final Paint fill = Paint()..color = const Color(0x8014120F);
    final Paint dark = Paint()..color = const Color(0xE614120F);
    final Paint light = Paint()..color = StrideColors.textPrimary;

    for (final AtlasNode node in scene.nodes) {
      final Offset c = Offset(node.x, node.y);
      final bool current = node.id == scene.current.id;
      final double r =
          (current
              ? AtlasMarkerSpec.currentRingRadius
              : AtlasMarkerSpec.ringRadius) *
          chrome;
      final double stroke =
          (current
              ? AtlasMarkerSpec.currentRingStroke
              : AtlasMarkerSpec.ringStroke) *
          chrome;
      canvas.drawCircle(c, r, fill);
      // A dark outline either side of the light ring, so it reads on snow and
      // on forest alike — the same reason every sprite carries a dark contour.
      canvas.drawCircle(c, r, outline..strokeWidth = stroke + 2 * chrome);
      canvas.drawCircle(c, r, ink..strokeWidth = stroke);
      if (current) {
        canvas.drawCircle(
          c,
          (AtlasMarkerSpec.currentDotRadius + 1) * chrome,
          dark,
        );
        canvas.drawCircle(c, AtlasMarkerSpec.currentDotRadius * chrome, light);
      }

      if (node.id == selected) {
        canvas.drawCircle(
          c,
          AtlasMarkerSpec.selectedRadius * chrome,
          outline..strokeWidth = (AtlasMarkerSpec.selectedStroke + 2) * chrome,
        );
        canvas.drawCircle(
          c,
          AtlasMarkerSpec.selectedRadius * chrome,
          ink..strokeWidth = AtlasMarkerSpec.selectedStroke * chrome,
        );
      }

      // The Journey ring: gold, outside the place's own ring and inside a
      // selection's — visible together with either. Not drawn on the
      // current place: an arrived journey's marker is the you-are-here
      // bullseye, and two rings would say two things.
      if (node.id == journey && !current) {
        final double jr = (AtlasMarkerSpec.ringRadius + 3) * chrome;
        canvas.drawCircle(
          c,
          jr,
          outline..strokeWidth = (AtlasMarkerSpec.ringStroke + 2) * chrome,
        );
        canvas.drawCircle(
          c,
          jr,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = StrideColors.goalActive
            ..strokeWidth = AtlasMarkerSpec.ringStroke * chrome,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StaticRingPainter old) =>
      old.selected != selected ||
      old.scene != scene ||
      old.chrome != chrome ||
      old.journey != journey;
}

/// The expanding, fading ring under the player's location.
///
/// A caption, not a token: it does not move, cannot be dragged, and depicts
/// nothing but *here*. Its controller repeats only while [TickerMode] allows —
/// the viewport disables it whenever the app is not in the foreground — and it
/// is disposed with the layer, so leaving the tab stops it.
class AtlasPulse extends StatefulWidget {
  const AtlasPulse({super.key, this.arrival = false});

  /// One breath. Slow, so it reads as a place being pointed at rather than an
  /// alert.
  static const Duration period = Duration(milliseconds: 1800);

  /// While the arrival banner still stands (Fable V2 Iteration 02, F4), the
  /// breath wears the warm reward light instead of parchment — "you just got
  /// here" for as long as the panel is saying so. Colour only: no extra
  /// ticker, and under reduced motion the pulse stays as still as ever.
  final bool arrival;

  @override
  State<AtlasPulse> createState() => _AtlasPulseState();
}

class _AtlasPulseState extends State<AtlasPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AtlasPulse.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: AtlasMarkerSpec.pulseRadius * 2,
    height: AtlasMarkerSpec.pulseRadius * 2,
    child: CustomPaint(
      painter: _PulsePainter(_controller, arrival: widget.arrival),
    ),
  );
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.progress, {required this.arrival})
    : super(repaint: progress);

  final Animation<double> progress;
  final bool arrival;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.value;
    final Offset c = size.center(Offset.zero);
    final double r =
        AtlasMarkerSpec.currentRingRadius +
        (AtlasMarkerSpec.pulseRadius - AtlasMarkerSpec.currentRingRadius) * t;
    // Fades to nothing before the loop restarts, so there is no visible snap.
    final double alpha = (1 - t) * (1 - t) * 0.85;
    // A dark contour under the light ring, as the static rings have: a light
    // ring alone is invisible over Frostmere's snow, and the current place
    // must read wherever the player stands.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFF14120F).withValues(alpha: alpha * 0.9),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color =
            (arrival ? StrideColors.rewardLightInk : StrideColors.textPrimary)
                .withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_PulsePainter old) =>
      old.progress != progress || old.arrival != arrival;
}

/// The place's name under its marker, on a compact plate that takes exactly
/// the width the name needs — a tag standing on the ground, so type stays
/// readable over lit canopy and over snow without boxing the geography in.
class _MarkerLabel extends StatelessWidget {
  const _MarkerLabel({
    required this.node,
    required this.scene,
    required this.zoom,
  });

  final AtlasNode node;
  final AtlasScene scene;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final bool current = node.id == scene.current.id;
    return _WorldLabel(
      key: ValueKey<String>('atlas-label:${node.id.value}'),
      x: node.x,
      y: node.y + AtlasMarkerSpec.labelOffset,
      zoom: zoom,
      // Dark enough that the name reads over anything, light enough that the
      // geography ghosts through rather than being cut out by the plate.
      plateAlpha: 0xC0,
      text: node.place.displayName,
      style: StrideType.microLabel.copyWith(
        // Weight marks the current place, never a hue (Q-04, L-16).
        color: current ? StrideColors.textPrimary : StrideColors.textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// A named landmark's caption: the quiet tier.
///
/// Three things separate it from a place's label, and all three are needed —
/// any one alone would leave a reader guessing. It is **smaller** (a size down
/// the scale), **dimmer** (`textMuted`, the palette's quietest readable ink) and
/// its plate is **fainter** (a little over half the opacity), so it sits on the
/// ground rather than on a chip. A `future`-tier landmark is quieter again and
/// carries a trailing em dash — *Far Town —* — the typographic mark for a
/// sentence that does not finish, which is exactly what a road pointing off the
/// known map is.
///
/// It has no hit target and no ring. Nothing about it repays a tap, and the
/// whole layer is inside an `IgnorePointer`.
class _LandmarkLabel extends StatelessWidget {
  const _LandmarkLabel({required this.landmark, required this.zoom});

  final AtlasNamedLandmark landmark;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final bool far = landmark.tier == AtlasLandmarkTier.future;
    return _WorldLabel(
      key: ValueKey<String>('atlas-caption:${landmark.id}'),
      x: landmark.x,
      y: landmark.y + AtlasMarkerSpec.landmarkLabelOffset,
      zoom: zoom,
      plateAlpha: far ? 0x66 : 0x8C,
      text: far ? '${landmark.name} —' : landmark.name,
      style: StrideType.micro.copyWith(
        color: StrideColors.textMuted,
        letterSpacing: 0.3,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// One line of type standing on the world surface, at a fixed **screen** size.
///
/// ## Why the label counter-scales and the map does not
///
/// Everything else on this surface is geography: a ring, a road, a landmark
/// sprite all belong to the world and are right to grow and shrink with it. A
/// name does not. At the new zoom floor the world is drawn at half size, and a
/// label that scaled with it would put 11 dp type on screen at 5.5 dp — a place
/// name unreadable at exactly the zoom a player uses to find places. Scaling it
/// the other way is no better: at 2× the names would tower over the map they
/// annotate and collide with each other.
///
/// So the label is laid out at its designed size and multiplied by `1 / zoom`
/// inside the world transform. The two scales cancel: type is rasterised at 1:1
/// device pixels at **every** zoom, which is both legible and crisp — the same
/// reason the camera is pixel-snapped. Its *anchor* stays a world coordinate,
/// so the name still travels with the place.
///
/// ## The plate hugs the name
///
/// The plate's width is **measured, never a constant**: the name's laid-out
/// width, ceiled to a whole dp, plus [AtlasMarkerSpec.labelPadX] a side. The
/// measurement uses the ambient style merged under this label's own and the
/// ambient text scale — exactly the layout the `Text` below will do, which is
/// what `AdaptiveText` established a `TextPainter` must be handed to be
/// trusted (M-06). A long name therefore takes the width it needs and is
/// never wrapped or truncated; a short one sits in a tag barely wider than
/// itself. The old fixed 184 dp plate, counter-scaled at the survey floor,
/// read as a full-width black bar over the geography — and its side-fade
/// gradient, which existed only to soften that fixed width, dies with it.
class _WorldLabel extends StatelessWidget {
  const _WorldLabel({
    super.key,
    required this.x,
    required this.y,
    required this.zoom,
    required this.plateAlpha,
    required this.text,
    required this.style,
  });

  /// The world coordinate the label is centred under.
  final double x;
  final double y;

  final double zoom;

  /// The plate's opacity, 0–255. A landmark's is fainter than a place's.
  final int plateAlpha;

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // Measure what will actually be painted: the ambient style with this
    // label's style merged over it, at the ambient text scale. A bare role
    // has no font family, and a `TextPainter` handed one measures a fallback
    // font instead of the theme's (see `AdaptiveText`).
    final TextStyle merged = DefaultTextStyle.of(context).style.merge(style);
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: merged),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double textWidth = painter.width;
    painter.dispose();

    // Screen dp: the plate, like the type on it, holds this size at every
    // zoom. Ceiled so the box is never a fraction short of its own name, and
    // so the plate's edges land on whole pixels once its left edge does.
    final double plateWidth =
        textWidth.ceilToDouble() + AtlasMarkerSpec.labelPadX * 2;
    final Color plate = const Color(0xFF14120F).withAlpha(plateAlpha);
    // The paint transform below scales about the layout box's top centre, so
    // the painted left edge sits at `centre·zoom − plateWidth/2` screen dp.
    // Choose the centre that puts that figure on a whole logical pixel —
    // where the camera's own snapping puts the rest of the surface — and the
    // whole-dp width lands the right edge there too. The top snaps directly:
    // scaling about the top centre leaves it where the layout put it.
    final double snappedLeft = (x * zoom - plateWidth / 2).roundToDouble();
    return Positioned(
      left: (snappedLeft + plateWidth / 2) / zoom - plateWidth / 2,
      top: (y * zoom).roundToDouble() / zoom,
      width: plateWidth,
      child: IgnorePointer(
        child: Transform.scale(
          scale: 1 / zoom,
          alignment: Alignment.topCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AtlasMarkerSpec.labelPadX,
              vertical: AtlasMarkerSpec.labelPadY,
            ),
            decoration: BoxDecoration(
              color: plate,
              borderRadius: StrideRadius.chip,
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              // Unreachable: the box is the measurement plus padding. Left as
              // `clip` so a regression is visible rather than an ellipsis's
              // claim that the name was too long.
              overflow: TextOverflow.clip,
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

/// The one-shot ring that plays where the player has just arrived.
///
/// Travel is instantaneous and strategic: the engine moves the player and the
/// camera recentres. Without a beat at the destination the whole journey is a
/// silent jump, and the owner's note was that arriving should *land*. This is
/// that beat and nothing more — one expanding ring, ~600 ms, then gone.
///
/// It is not an avatar, does not traverse the route, and marks no progress: it
/// is the arrival's punctuation, drawn at the place the engine says the player
/// now stands. Its controller runs once (`forward`, never `repeat`), obeys the
/// viewport's [TickerMode] like everything else on this surface, and is
/// disposed with the widget — so a burst cut short by leaving the tab leaves no
/// ticker behind.
class AtlasArrivalBurst extends StatefulWidget {
  const AtlasArrivalBurst({super.key});

  /// Short enough to be over before a thumb reaches the panel.
  static const Duration period = Duration(milliseconds: 600);

  @override
  State<AtlasArrivalBurst> createState() => _AtlasArrivalBurstState();
}

class _AtlasArrivalBurstState extends State<AtlasArrivalBurst>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AtlasArrivalBurst.period,
  );

  /// While the travel card plays, the burst waits for its **arrival
  /// anticipation** phase instead of firing at commit — where the old
  /// timing spent the ring entirely behind the card's barrier
  /// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 2). The card registers its
  /// clock only after its bounded precache, so the burst grants a short
  /// ticker-driven grace before concluding no card is coming; with none, it
  /// fires as it always did.
  late final AnimationController _grace = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  TravelPresentationHandle? _waitingOn;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    TravelPresentationLink.active.addListener(_onLink);
    _grace.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && _waitingOn == null) _fire();
    });
    final TravelPresentationHandle? handle =
        TravelPresentationLink.active.value;
    if (handle == null) {
      _grace.forward();
    } else {
      _adopt(handle);
    }
  }

  void _adopt(TravelPresentationHandle handle) {
    _grace.stop();
    _waitingOn = handle;
    handle.clock.addListener(_onCardClock);
    _onCardClock();
  }

  void _fire() {
    if (_fired) return;
    _fired = true;
    _detach();
    if (mounted) _controller.forward();
  }

  void _onCardClock() {
    final TravelPresentationHandle? handle = _waitingOn;
    if (handle == null) return;
    if (handle.clock.value >=
        TravelPacing.anticipationFractionForLegs(handle.legs)) {
      _fire();
    }
  }

  /// A card arrived during the grace, or the card left before its
  /// anticipation phase (popped by the system) — fire now rather than never.
  void _onLink() {
    if (_fired) return;
    final TravelPresentationHandle? handle =
        TravelPresentationLink.active.value;
    if (handle != null && _waitingOn == null) {
      _adopt(handle);
    } else if (handle == null && _waitingOn != null) {
      _fire();
    }
  }

  void _detach() {
    TravelPresentationLink.active.removeListener(_onLink);
    _waitingOn?.clock.removeListener(_onCardClock);
    _waitingOn = null;
  }

  @override
  void dispose() {
    _detach();
    _grace.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: AtlasMarkerSpec.burstRadius * 2,
    height: AtlasMarkerSpec.burstRadius * 2,
    child: CustomPaint(painter: _BurstPainter(_controller)),
  );
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = progress.value;
    // Invisible at rest, at both ends. That matters for more than taste: under
    // reduced motion or before the platform reports resumed the ticker never
    // runs, the value stays at 0, and a burst that painted a solid ring at
    // t = 0 would become a permanent second ring around the player.
    if (t <= 0 || t >= 1) return;
    final Offset c = size.center(Offset.zero);
    // Fast out: most of the travel happens in the first third, the way a
    // struck surface rings.
    final double eased = 1 - (1 - t) * (1 - t) * (1 - t);
    final double r =
        AtlasMarkerSpec.currentRingRadius +
        (AtlasMarkerSpec.burstRadius - AtlasMarkerSpec.currentRingRadius) *
            eased;
    final double alpha = t < 0.12 ? t / 0.12 : (1 - t) / 0.88;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFF14120F).withValues(alpha: alpha * 0.8),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = StrideColors.textPrimary.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}

/// The tappable square around a place. Square rather than round because a
/// square that contains the hit circle is never smaller than it, and the
/// difference at the corners is not one a thumb can find.
///
/// ## The target grows as the map shrinks, up to the room it has
///
/// The layout's `hitRadius` is in world pixels, and at zoom 1 a world pixel is
/// a logical pixel — which is what makes 22 the 44 dp accessibility floor. Once
/// the zoom floor drops below 1 to fit a larger world, that stops being true:
/// at 0.5× a 44 world-pixel target is 22 dp on screen, and the floor the layout
/// validator enforces silently stops holding at exactly the zoom a player uses
/// to survey.
///
/// So the world radius grows by `1 / zoom` when zoomed out, and is capped at
/// just under half the distance to the nearest other place, so a bigger target
/// can never reach into a neighbour's. At zoom ≥ 1 the growth term is below the
/// authored radius and nothing changes at all.
class _HitTarget extends StatelessWidget {
  const _HitTarget({
    required this.node,
    required this.scene,
    required this.zoom,
    required this.onSelect,
  });

  final AtlasNode node;
  final AtlasScene scene;
  final double zoom;
  final ValueChanged<ContentId> onSelect;

  /// The most of the gap to a neighbour one target may claim. Under a half, so
  /// two adjacent targets always leave a seam between them.
  static const double _crowdingLimit = 0.45;

  @override
  Widget build(BuildContext context) {
    final double authored =
        scene.layout.locationFor(node.id)?.hitRadius ??
        AtlasLayout.minimumHitRadius;
    final double wanted = AtlasLayout.minimumHitRadius / zoom;
    final double room = scene.separationAround(node) * _crowdingLimit;
    double r = wanted > authored ? wanted : authored;
    if (r > room) r = room < authored ? authored : room;
    return Positioned(
      left: node.x - r,
      top: node.y - r,
      width: r * 2,
      height: r * 2,
      child: Semantics(
        button: true,
        label: node.place.displayName,
        child: GestureDetector(
          key: ValueKey<String>('atlas-hit:${node.id.value}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(node.id),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- travel trace

/// A spark running the road just walked — the journey made visible on the
/// map, then gone.
///
/// Chrome, not art (`RULES.md` A-2): a bright square with the route dots'
/// own contour, riding the same polyline course the route layer draws — the
/// drawn track where the layout gives one, the straight line otherwise, and
/// on a multi-leg journey the **concatenation of every walked hop's course**
/// (the old single from→to pair fell back to a straight line cross-country
/// the moment the journey had a middle).
///
/// ## One trip, one clock (GAME_FEEL_CHARACTER_PRESENTATION_01, item 2)
///
/// While the travel card plays, this spark mirrors the card's own controller
/// through [TravelPresentationLink] — the walking figure and the dot are two
/// views of one clock, so a skip on the card snaps the dot home with it and
/// the two can never disagree. When no card runs (it failed to open, or was
/// popped by the system) the spark falls back to its own controller at the
/// identical `TravelPacing` duration. Reduced motion skips it entirely —
/// the arrival burst and the recentred camera already say what happened.
class AtlasTravelTrace extends StatefulWidget {
  const AtlasTravelTrace({
    super.key,
    required this.scene,
    required this.from,
    required this.to,
    required this.chrome,
    this.legPlaces,
  });

  final AtlasScene scene;
  final AtlasNode from;
  final AtlasNode to;

  /// The committed legs' places in walked order, or null for the plain
  /// from→to pair.
  final List<ContentId>? legPlaces;

  /// The marker chrome counter-scale at the current zoom.
  final double chrome;

  @override
  State<AtlasTravelTrace> createState() => _AtlasTravelTraceState();
}

class _AtlasTravelTraceState extends State<AtlasTravelTrace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;
  bool _skipped = false;

  /// The legs as they stood at mount. Snapshotted: the controller's result
  /// timer clears the journey summary after ~5 s, well inside the longer
  /// presentation, and a course that collapses to the straight pair
  /// mid-flight would make the dot jump roads.
  late final List<ContentId>? _legPlaces = widget.legPlaces == null
      ? null
      : List<ContentId>.of(widget.legPlaces!);

  /// The card's clock, while one is registered — the mirror source.
  TravelPresentationHandle? _handle;

  /// Set once the mirrored card has left; the spark is then done whatever
  /// its last mirrored value was — a popped card must not strand a dot
  /// mid-road pointing at a walk that is already over.
  bool _finished = false;

  int get _legCount {
    final int? legs = _legPlaces?.length;
    return legs == null || legs < 1 ? 1 : legs;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: TravelPacing.durationForLegs(_legCount),
    )..addListener(() => setState(() {}));
    TravelPresentationLink.active.addListener(_onLink);
  }

  void _onLink() {
    final TravelPresentationHandle? handle =
        TravelPresentationLink.active.value;
    if (handle != null) {
      // Adopt the card's clock; the fallback stops where it is. Both run
      // the same pacing table, so the hand-over jump is at most the card's
      // precache head start.
      _controller.stop();
      _handle?.clock.removeListener(_onClock);
      _handle = handle;
      handle.clock.addListener(_onClock);
      _rebuildSafely();
      return;
    }
    if (_handle != null) {
      _handle!.clock.removeListener(_onClock);
      _handle = null;
      _finished = true;
      _rebuildSafely();
    }
  }

  void _onClock() => _rebuildSafely();

  /// The link can notify from another route's build (the card mounting or
  /// leaving); a setState then is a framework assertion, so it waits for
  /// the end of the frame — the `AmbientStage._rebuild` pattern.
  void _rebuildSafely() {
    if (!mounted) return;
    final SchedulerBinding binding = SchedulerBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduced motion: the arrival burst and the recentred camera already say
    // what happened; a moving spark is exactly the motion being declined.
    _skipped = MediaQuery.disableAnimationsOf(context);
    if (_skipped) return;
    // A card may already be playing when this arrival's trace mounts.
    _onLink();
    if (_handle == null) _controller.forward();
  }

  @override
  void dispose() {
    TravelPresentationLink.active.removeListener(_onLink);
    _handle?.clock.removeListener(_onClock);
    _controller.dispose();
    super.dispose();
  }

  /// The walked course: every committed hop's drawn track where the layout
  /// has one, the straight line otherwise — the route painter's own rule,
  /// applied per leg.
  List<Offset> _course() {
    final List<AtlasNode> chain = _chain();
    final List<Offset> points = <Offset>[Offset(chain.first.x, chain.first.y)];
    for (int i = 1; i < chain.length; i++) {
      final AtlasNode a = chain[i - 1];
      final AtlasNode b = chain[i];
      final AtlasRoute? drawn = widget.scene.layout.routeBetween(a.id, b.id);
      if (drawn != null) {
        final bool forward = drawn.from == a.id;
        final Iterable<({double x, double y})> mids = forward
            ? drawn.points
            : drawn.points.reversed;
        for (final ({double x, double y}) p in mids) {
          points.add(Offset(p.x, p.y));
        }
      }
      points.add(Offset(b.x, b.y));
    }
    return points;
  }

  /// The nodes walked, in order: origin, then every leg's place the scene
  /// knows. An id the scene cannot resolve is skipped rather than guessed;
  /// the final node is always [AtlasTravelTrace.to], so a fully unresolved
  /// list degrades to the plain pair.
  List<AtlasNode> _chain() {
    final List<AtlasNode> chain = <AtlasNode>[widget.from];
    final List<ContentId>? legs = _legPlaces;
    if (legs != null && legs.isNotEmpty) {
      for (final ContentId id in legs) {
        for (final AtlasNode node in widget.scene.nodes) {
          if (node.id == id) {
            chain.add(node);
            break;
          }
        }
      }
    }
    if (chain.last.id != widget.to.id) chain.add(widget.to);
    return chain;
  }

  @override
  Widget build(BuildContext context) {
    final double raw = _handle?.clock.value ?? _controller.value;
    final int legs = _handle?.legs ?? _legCount;
    if (_skipped || _finished || raw >= 1 || _controller.isCompleted) {
      return const SizedBox.shrink();
    }
    final List<Offset> course = _course();
    double total = 0;
    for (int i = 1; i < course.length; i++) {
      total += (course[i] - course[i - 1]).distance;
    }
    if (total == 0) return const SizedBox.shrink();

    // The shared course mapping: holds at the origin through the card's
    // departure window, eases along the road with the travel loop, and is
    // home before the arrival rest.
    final double t = TravelPacing.courseProgress(raw, legs);
    double remaining = total * t;
    Offset at = course.first;
    for (int i = 1; i < course.length; i++) {
      final Offset a = course[i - 1];
      final Offset b = course[i];
      final double length = (b - a).distance;
      if (length == 0) continue;
      if (remaining <= length) {
        at = a + (b - a) * (remaining / length);
        break;
      }
      remaining -= length;
      at = b;
    }

    final double side = 7 * widget.chrome;
    final double contour = side + 2 * widget.chrome;
    return SizedBox(
      width: widget.scene.worldWidth,
      height: widget.scene.worldHeight,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: at.dx - contour / 2,
            top: at.dy - contour / 2,
            child: Container(
              width: contour,
              height: contour,
              color: const Color(0xE614120F),
              alignment: Alignment.center,
              child: Container(
                width: side,
                height: side,
                color: const Color(0xFFF0E7D8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
