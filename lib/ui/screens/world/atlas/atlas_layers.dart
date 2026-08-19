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

import '../../../../runtime/stride_session.dart';
import '../../../components/pixel_asset.dart';
import '../../../icons/atlas_assets.dart';
import '../../../theme/stride_colors.dart';
import '../../../theme/stride_typography.dart';
import 'atlas_layout.dart';

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
class AtlasRouteLayer extends StatelessWidget {
  const AtlasRouteLayer({super.key, required this.scene});

  final AtlasScene scene;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: IgnorePointer(
      child: CustomPaint(
        size: Size(scene.worldWidth, scene.worldHeight),
        painter: _RoutePainter(scene),
      ),
    ),
  );
}

class _RoutePainter extends CustomPainter {
  const _RoutePainter(this.scene);

  final AtlasScene scene;

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

  @override
  void paint(Canvas canvas, Size size) {
    final Paint contour = Paint()..color = const Color(0xB314120F);
    final Paint ink = Paint()..color = const Color(0xD9F0E7D8);
    for (final AtlasEdge edge in scene.edges) {
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
            width: _dot,
            height: _dot,
          );
          canvas.drawRect(
            Rect.fromCenter(
              center: dot.center,
              width: _contour,
              height: _contour,
            ),
            contour,
          );
          canvas.drawRect(dot, ink);
          d += _pitch;
        }
        carry = d - length;
        walked += length;
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.scene != scene;
}

// ----------------------------------------------------------------- landmarks

/// A landmark PNG standing on each place that has one. Nothing is drawn for a
/// place without art — the marker and label carry it until the art arrives.
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
    required this.onSelect,
  });

  final AtlasScene scene;
  final ContentId? selected;
  final ValueChanged<ContentId> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: scene.worldWidth,
    height: scene.worldHeight,
    child: Stack(
      children: <Widget>[
        // The pulse first, so every marker and label paints over it.
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
        for (final AtlasNode node in scene.nodes) ...<Widget>[
          _MarkerLabel(node: node, scene: scene),
          _HitTarget(node: node, scene: scene, onSelect: onSelect),
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

  /// The label sits this far below the marker's centre.
  static const double labelOffset = 14;

  /// Wide enough for the longest place name at a 1.4× text scale. Names are
  /// centred, and the plate fades at its sides, so the unused width is
  /// invisible rather than a box.
  static const double labelWidth = 184;
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
  const _MarkerLabel({required this.node, required this.scene});

  final AtlasNode node;
  final AtlasScene scene;

  @override
  Widget build(BuildContext context) {
    final bool current = node.id == scene.current.id;
    return Positioned(
      left: node.x - AtlasMarkerSpec.labelWidth / 2,
      top: node.y + AtlasMarkerSpec.labelOffset,
      width: AtlasMarkerSpec.labelWidth,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Color(0x0014120F),
                Color(0xD914120F),
                Color(0xD914120F),
                Color(0x0014120F),
              ],
              stops: <double>[0, 0.2, 0.8, 1],
            ),
          ),
          child: Text(
            node.place.displayName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: StrideType.microLabel.copyWith(
              // Weight marks the current place, never a hue (Q-04, L-16).
              color: current
                  ? StrideColors.textPrimary
                  : StrideColors.textSecondary,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// The tappable square around a place. Square rather than round because a
/// square that contains the hit circle is never smaller than it, and the
/// difference at the corners is not one a thumb can find.
class _HitTarget extends StatelessWidget {
  const _HitTarget({
    required this.node,
    required this.scene,
    required this.onSelect,
  });

  final AtlasNode node;
  final AtlasScene scene;
  final ValueChanged<ContentId> onSelect;

  @override
  Widget build(BuildContext context) {
    final double r =
        scene.layout.locationFor(node.id)?.hitRadius ??
        AtlasLayout.minimumHitRadius;
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
