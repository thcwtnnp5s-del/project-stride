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

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

// The named-landmark and kind-glyph types are not in the session's re-export
// list — a landmark is packaging data the session has no opinion about — so
// they are imported from the layout library itself. Same library the session
// re-exports the rest from, so no symbol is defined twice.
import '../../../../runtime/atlas_layout.dart'
    show AtlasLandmarkTier, AtlasNamedLandmark;
import '../../../../runtime/stride_session.dart';
import '../../../components/pixel_asset.dart';
import '../../../icons/atlas_assets.dart';
import '../../../theme/stride_colors.dart';
import '../../../theme/stride_typography.dart';
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
  const AtlasRouteLayer({super.key, required this.scene, this.way});

  final AtlasScene scene;

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
        }),
      ),
    ),
  );
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.scene, this.highlighted);

  final AtlasScene scene;

  /// [AtlasEdge.key] for every edge on the previewed walk.
  final Set<String> highlighted;

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
    for (final AtlasEdge edge in scene.edges) {
      final bool onWay = highlighted.contains(edge.key);
      final double dotSide = onWay ? _dotOnWay : _dot;
      final double contourSide = onWay ? _contourOnWay : _contour;
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
      double carry = _pitch;
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
          if (walked + d > total - _pitch / 2) break;
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
          d += _pitch;
        }
        carry = d - length;
        walked += length;
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.scene != scene ||
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
class AtlasLandmarkLayer extends StatelessWidget {
  const AtlasLandmarkLayer({super.key, required this.scene});

  final AtlasScene scene;

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
    // No ticker at all for a layout with nothing to animate. The current pass
    // ships no overlays; the layer must cost nothing until it has work.
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
      key = key * 31 + _frameIndex(overlay, t);
      key = key * 31 + _driftPosition(overlay, t).dx.floor();
      key = key * 31 + _driftPosition(overlay, t).dy.floor();
    }
    return key;
  }

  static int _frameIndex(AtlasOverlay overlay, Duration t) =>
      (t.inMilliseconds ~/ overlay.frameMillis) % overlay.frameCount;

  /// Where the sprite is at [t], wrapped so it re-enters from the opposite
  /// edge of the world once it has drifted off.
  Offset _driftPosition(AtlasOverlay overlay, Duration t) {
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

  @override
  Widget build(BuildContext context) {
    final int scale = widget.scene.layout.scale;
    return RepaintBoundary(
      child: IgnorePointer(
        child: SizedBox(
          width: widget.scene.worldWidth,
          height: widget.scene.worldHeight,
          child: Stack(
            children: <Widget>[
              for (final AtlasOverlay overlay in widget.scene.layout.overlays)
                Positioned(
                  left: _driftPosition(overlay, _elapsed).dx.floorToDouble(),
                  top: _driftPosition(overlay, _elapsed).dy.floorToDouble(),
                  child: Opacity(
                    // The compositor multiplier: the sprites are opaque art
                    // and the layout says how faint each one sits.
                    opacity: overlay.opacity,
                    child: PixelAsset(
                      assetPath: AtlasAssets.framePath(
                        overlay.asset,
                        _frameIndex(overlay, _elapsed),
                      ),
                      nativeWidth: overlay.width,
                      nativeHeight: overlay.height,
                      scale: scale,
                    ),
                  ),
                ),
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
    required this.arrivalToken,
    required this.onSelect,
  });

  final AtlasScene scene;
  final ContentId? selected;

  /// What kind of place each node is, resolved once per build by the screen
  /// through `AtlasPlaceInfo.kindOf` — the single seam this stream reads place
  /// detail through.
  final Map<ContentId, AtlasPlaceKind> kinds;

  /// The camera's zoom. Labels counter-scale by it so type stays the size it
  /// was designed at, whatever the world is doing.
  final double zoom;

  /// Bumped once per arrival. Zero means *nothing has arrived this session*,
  /// and no burst is built at all — opening the screen is not an arrival.
  final int arrivalToken;

  final ValueChanged<ContentId> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: scene.worldWidth,
    height: scene.worldHeight,
    child: Stack(
      children: <Widget>[
        // Named geography's labels first: a place's name always paints over a
        // landmark's, never the other way round.
        RepaintBoundary(
          child: IgnorePointer(
            child: SizedBox(
              width: scene.worldWidth,
              height: scene.worldHeight,
              child: Stack(
                children: <Widget>[
                  for (final AtlasNamedLandmark named in scene.layout.landmarks)
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
                            (kinds[node.id] ?? AtlasPlaceKind.wilds).markerKind,
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
                painter: _StaticRingPainter(scene: scene, selected: selected),
              ),
            ),
          ),
        ),
        Positioned(
          left: scene.current.x - AtlasMarkerSpec.pulseRadius,
          top: scene.current.y - AtlasMarkerSpec.pulseRadius,
          child: const RepaintBoundary(
            child: IgnorePointer(child: AtlasPulse()),
          ),
        ),
        if (arrivalToken > 0)
          Positioned(
            left: scene.current.x - AtlasMarkerSpec.burstRadius,
            top: scene.current.y - AtlasMarkerSpec.burstRadius,
            child: RepaintBoundary(
              child: IgnorePointer(
                // Keyed on the token, so each arrival builds a fresh widget
                // that plays once and then holds at nothing. A rebuild for any
                // other reason — a pan, a selection — reuses it and replays
                // nothing.
                child: AtlasArrivalBurst(key: ValueKey<int>(arrivalToken)),
              ),
            ),
          ),
        for (final AtlasNode node in scene.nodes) ...<Widget>[
          _MarkerLabel(node: node, scene: scene, zoom: zoom),
          _HitTarget(node: node, scene: scene, zoom: zoom, onSelect: onSelect),
        ],
      ],
    ),
  );
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

  /// Wide enough for the longest place name at a 1.4× text scale. Names are
  /// centred, and the plate fades at its sides, so the unused width is
  /// invisible rather than a box.
  static const double labelWidth = 184;

  /// A landmark's label is narrower, because a landmark's name is a caption
  /// rather than a destination and a wide plate under a small name reads as an
  /// empty control.
  static const double landmarkLabelWidth = 150;

  /// A landmark hangs closer to its coordinate than a place does: it has no
  /// ring to clear.
  static const double landmarkLabelOffset = 9;
}

/// The rings that do not move: one per place, a heavier one under the current
/// place, and the selection ring. Redrawn only when the selection changes.
class _StaticRingPainter extends CustomPainter {
  const _StaticRingPainter({required this.scene, required this.selected});

  final AtlasScene scene;
  final ContentId? selected;

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
      final double r = current
          ? AtlasMarkerSpec.currentRingRadius
          : AtlasMarkerSpec.ringRadius;
      final double stroke = current
          ? AtlasMarkerSpec.currentRingStroke
          : AtlasMarkerSpec.ringStroke;
      canvas.drawCircle(c, r, fill);
      // A dark outline either side of the light ring, so it reads on snow and
      // on forest alike — the same reason every sprite carries a dark contour.
      canvas.drawCircle(c, r, outline..strokeWidth = stroke + 2);
      canvas.drawCircle(c, r, ink..strokeWidth = stroke);
      if (current) {
        canvas.drawCircle(c, AtlasMarkerSpec.currentDotRadius + 1, dark);
        canvas.drawCircle(c, AtlasMarkerSpec.currentDotRadius, light);
      }

      if (node.id == selected) {
        canvas.drawCircle(
          c,
          AtlasMarkerSpec.selectedRadius,
          outline..strokeWidth = AtlasMarkerSpec.selectedStroke + 2,
        );
        canvas.drawCircle(
          c,
          AtlasMarkerSpec.selectedRadius,
          ink..strokeWidth = AtlasMarkerSpec.selectedStroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StaticRingPainter old) =>
      old.selected != selected || old.scene != scene;
}

/// The expanding, fading ring under the player's location.
///
/// A caption, not a token: it does not move, cannot be dragged, and depicts
/// nothing but *here*. Its controller repeats only while [TickerMode] allows —
/// the viewport disables it whenever the app is not in the foreground — and it
/// is disposed with the layer, so leaving the tab stops it.
class AtlasPulse extends StatefulWidget {
  const AtlasPulse({super.key});

  /// One breath. Slow, so it reads as a place being pointed at rather than an
  /// alert.
  static const Duration period = Duration(milliseconds: 1800);

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
    child: CustomPaint(painter: _PulsePainter(_controller)),
  );
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

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
        ..color = StrideColors.textPrimary.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(_PulsePainter old) => old.progress != progress;
}

/// The place's name under its marker, on a plate that fades at the sides —
/// the same device as the map caption, so type stays readable over lit
/// canopy and over snow without a hard-edged box on the ground.
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
      x: node.x,
      y: node.y + AtlasMarkerSpec.labelOffset,
      width: AtlasMarkerSpec.labelWidth,
      zoom: zoom,
      plateAlpha: 0xD9,
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
/// It has no hit target, no ring, and no plate edge. Nothing about it repays a
/// tap, and the whole layer is inside an `IgnorePointer`.
class _LandmarkLabel extends StatelessWidget {
  const _LandmarkLabel({required this.landmark, required this.zoom});

  final AtlasNamedLandmark landmark;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final bool far = landmark.tier == AtlasLandmarkTier.future;
    return _WorldLabel(
      x: landmark.x,
      y: landmark.y + AtlasMarkerSpec.landmarkLabelOffset,
      width: AtlasMarkerSpec.landmarkLabelWidth,
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
class _WorldLabel extends StatelessWidget {
  const _WorldLabel({
    required this.x,
    required this.y,
    required this.width,
    required this.zoom,
    required this.plateAlpha,
    required this.text,
    required this.style,
  });

  /// The world coordinate the label is centred under.
  final double x;
  final double y;

  /// The label's width in **screen** dp; its world footprint is this over
  /// [zoom].
  final double width;

  final double zoom;

  /// The plate's peak opacity, 0–255. A landmark's is fainter than a place's.
  final int plateAlpha;

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final double worldWidth = width / zoom;
    final Color plate = const Color(0xFF14120F).withAlpha(plateAlpha);
    // Snapped to a whole logical pixel *after* the zoom, so the plate's fade
    // and the type's baseline land where the camera's own snapping puts the
    // rest of the surface. `v * zoom` rounded, back over `zoom`, is the world
    // coordinate nearest a whole screen pixel.
    double snap(double v) => (v * zoom).roundToDouble() / zoom;
    return Positioned(
      left: snap(x - worldWidth / 2),
      top: snap(y),
      width: worldWidth,
      child: IgnorePointer(
        child: Transform.scale(
          scale: 1 / zoom,
          alignment: Alignment.topCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  plate.withAlpha(0),
                  plate,
                  plate,
                  plate.withAlpha(0),
                ],
                stops: const <double>[0, 0.2, 0.8, 1],
              ),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AtlasArrivalBurst.period,
  )..forward();

  @override
  void dispose() {
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
