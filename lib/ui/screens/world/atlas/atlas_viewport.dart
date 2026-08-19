/// A window onto the world surface: pan on both axes, a restrained pinch zoom,
/// and pixel-snapped nearest-neighbour rendering throughout.
///
/// ## Why a hand-rolled gesture rather than `InteractiveViewer`
///
/// Two properties matter here that `InteractiveViewer` does not promise. The
/// **camera must land on whole device pixels** — a pixel-art surface panned to
/// a fractional translation is bilinear-blurred by the rasteriser regardless of
/// `FilterQuality.none` on the images — and the **zoom must settle on values
/// where one source pixel is a whole number of device pixels**, or the map's
/// evenly spaced posts beat visibly. Both are a few lines over a scale gesture
/// and would be a fight against a widget that owns its own matrix.
///
/// ## What the gesture is, and is not
///
/// A drag moves the camera. A pinch zooms about the fingers. A tap on a marker
/// selects a place. That is the whole vocabulary: there is no avatar to drag,
/// no path to trace, and nothing on this surface that issues a command. The
/// viewport does not know `SessionController` exists.
///
/// ## Motion is gated
///
/// The pulse under the current location and the drifting overlays run only
/// while the app is resumed, through a single [TickerMode] here — so one
/// lifecycle observer covers every animated thing on the atlas, and a widget
/// added later cannot forget to pause. The tab's screen is unmounted when
/// another tab is selected, which is what stops it when it is offscreen.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

import 'atlas_layers.dart';
import 'atlas_layout.dart';
import 'atlas_place_info.dart';

/// The zoom range. 1 is the art at its integer display scale; 2 is close
/// enough to read a landmark; the floor is far enough out to survey a world
/// that no longer fits a phone.
///
/// ## Why the floor is computed rather than declared
///
/// The atlas used to be one 768-wide tile and 1 was a sensible bottom: the
/// world was already about twice a phone's width, and zooming out past its
/// native scale would have shown blur for no gain. A 1536-wide world changes
/// the question — at 1× a player sees a quarter of it and has to pan blind to
/// find anywhere.
///
/// So the floor is the **larger** of two numbers, and the pair is the whole
/// rule: `viewportWidth / worldWidth` is the zoom at which the world's full
/// width fits the window, and [absoluteFloor] is as far out as the art stays
/// worth looking at. For a small world the first wins and the player can see
/// all of it and no further; for a large one the second wins and they survey
/// half the width at a time.
///
/// 0.5 is not an arbitrary bottom: the art is authored at native size and shown
/// at `scale` 2, so **0.5 of ×2 art is ×1 native** — every source pixel is
/// exactly one logical pixel, sampled nearest-neighbour, which is the crispest
/// a reduction can be. Below it the sampler would start dropping columns.
abstract final class AtlasZoom {
  const AtlasZoom._();

  /// As far out as the art is worth showing, whatever the world's size.
  static const double absoluteFloor = 0.5;

  /// The zoom the screen opens at: the art at its authored display scale.
  static const double initial = 1;

  static const double max = 2;

  /// The floor for a [worldWidth]-wide world seen through a [viewportWidth]
  /// window. Never above [max] — a world narrower than the window would
  /// otherwise pin the range shut.
  static double minFor({
    required double viewportWidth,
    required double worldWidth,
  }) {
    if (viewportWidth <= 0 || worldWidth <= 0) return absoluteFloor;
    final double whole = viewportWidth / worldWidth;
    if (whole <= absoluteFloor) return absoluteFloor;
    return whole > max ? max : whole;
  }
}

class AtlasViewport extends StatefulWidget {
  const AtlasViewport({
    super.key,
    required this.scene,
    required this.selected,
    required this.kinds,
    required this.onSelect,
    this.way,
  });

  final AtlasScene scene;
  final ContentId? selected;

  /// What kind of place each node is, resolved once by the screen.
  final Map<ContentId, AtlasPlaceKind> kinds;

  /// The walk to the selection, previewed on the roads. Null highlights
  /// nothing.
  final AtlasWay? way;

  final ValueChanged<ContentId> onSelect;

  @override
  State<AtlasViewport> createState() => AtlasViewportState();
}

/// Public so a test can read the camera. Nothing outside this file writes it.
class AtlasViewportState extends State<AtlasViewport>
    with WidgetsBindingObserver {
  /// The world coordinate at the viewport's top-left. Null until the first
  /// layout, when it is centred on the current location.
  Offset? _camera;
  double _zoom = AtlasZoom.initial;

  Size _viewport = Size.zero;

  Offset _gestureCamera = Offset.zero;
  double _gestureZoom = AtlasZoom.initial;
  Offset _gestureFocal = Offset.zero;

  /// Bumped once each time the player arrives somewhere new, so the marker
  /// layer can play a burst exactly then. Zero at launch: opening the screen
  /// is not an arrival.
  int _arrivals = 0;

  AppLifecycleState? _lifecycle;

  /// Where the camera is, in world pixels. For tests.
  Offset get camera => _camera ?? Offset.zero;

  /// The current zoom. For tests.
  double get zoom => _zoom;

  /// The zoom floor for this window and this world. For tests.
  double get minZoom => AtlasZoom.minFor(
    viewportWidth: _viewport.width,
    worldWidth: widget.scene.worldWidth,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = WidgetsBinding.instance.lifecycleState;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_lifecycle == state) return;
    setState(() => _lifecycle = state);
  }

  @override
  void didUpdateWidget(AtlasViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Arriving somewhere recentres the camera on it once, and counts as an
    // arrival so the destination's marker gets its one beat. A pan the player
    // made since is theirs to keep otherwise; only a change of location moves
    // the window.
    if (oldWidget.scene.current.id != widget.scene.current.id) {
      _arrivals++;
      if (_camera != null) {
        _camera = _clamp(_centredOn(widget.scene.current), _zoom);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Motion runs only in the foreground and only when the platform has not
  /// asked for reduced motion.
  bool get _animate =>
      // Null — "the platform has not said yet" — counts as not resumed. On a
      // device the engine reports the initial state at launch and every
      // resume after, so the atlas breathes; in the test harness it stays
      // null, so `pumpAndSettle` settles. Worth one glance on the phone.
      _lifecycle == AppLifecycleState.resumed &&
      !MediaQuery.disableAnimationsOf(context);

  Offset _centredOn(AtlasNode node) => Offset(
    node.x - _viewport.width / (2 * _zoom),
    node.y - _viewport.height / (2 * _zoom),
  );

  /// Keeps the world covering the viewport. When the world is narrower than
  /// the window at this zoom, it is centred instead.
  Offset _clamp(Offset camera, double zoom) {
    double axis(double value, double world, double window) {
      final double visible = window / zoom;
      if (visible >= world) return (world - visible) / 2;
      return value.clamp(0, world - visible);
    }

    return Offset(
      axis(camera.dx, widget.scene.worldWidth, _viewport.width),
      axis(camera.dy, widget.scene.worldHeight, _viewport.height),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureCamera = _camera ?? Offset.zero;
    _gestureZoom = _zoom;
    _gestureFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final double zoom = (_gestureZoom * details.scale).clamp(
      minZoom,
      AtlasZoom.max,
    );
    // The world point that was under the fingers when the gesture began stays
    // under them: pan and zoom fall out of the same equation.
    final Offset anchor = _gestureCamera + _gestureFocal / _gestureZoom;
    final Offset camera = anchor - details.localFocalPoint / zoom;
    setState(() {
      _zoom = zoom;
      _camera = _clamp(camera, zoom);
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    setState(() {
      _zoom = _snapZoom(_zoom, dpr);
      _camera = _clamp(_snapCamera(_camera ?? Offset.zero, _zoom, dpr), _zoom);
    });
  }

  /// The nearest zoom at which one native art pixel is a whole number of
  /// device pixels: `scale × zoom × dpr` integral. At dpr 3 and scale 2 that
  /// is every sixth; at dpr 2, every quarter. A non-integer dpr falls back to
  /// quarters, which is as good as such a screen gets.
  ///
  /// The floor is rounded **up** onto the same grid rather than clamped onto
  /// it. A floor derived from a window width — `393 / 768` — is not a grid
  /// value, and clamping to it would make the one zoom a player reaches by
  /// pinching all the way out the one zoom at which the art is resampled.
  double _snapZoom(double zoom, double dpr) {
    final double unit = dpr == dpr.roundToDouble()
        ? 1 / (widget.scene.layout.scale * dpr)
        : 0.25;
    final double floor = minZoom;
    final double snappedFloor = (floor / unit).ceil() * unit;
    final double low = snappedFloor > AtlasZoom.max
        ? AtlasZoom.max
        : snappedFloor;
    return ((zoom / unit).round() * unit).clamp(low, AtlasZoom.max);
  }

  // Double tap to zoom: considered, and not taken.
  //
  // A double tap toggling 1× and 2× would be the obvious convenience, and it
  // is not here. GestureDetector puts a double-tap recogniser in the same
  // arena as the scale recogniser, and the two do not share this surface
  // cleanly: with both declared, a pinch no longer accumulates scale from its
  // first frame — it starts once the scale recogniser has won an arena it now
  // has to contest — and a pinch that should reach 2× lands short of it.
  // Measured rather than assumed: with the double tap wired, a pinch to four
  // times the finger gap settled at 1.33 instead of 2.
  //
  // Trading a working pinch for a shortcut to the zoom the pinch already
  // reaches is a bad trade, so the vocabulary stays drag, pinch, tap. Worth
  // revisiting behind a hand-built recogniser, which is more work than this
  // milestone's convenience is worth.

  /// A camera whose screen translation is a whole number of device pixels.
  static Offset _snapCamera(Offset camera, double zoom, double dpr) {
    double axis(double v) => (v * zoom * dpr).round() / (zoom * dpr);
    return Offset(axis(camera.dx), axis(camera.dy));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final Size size = Size(constraints.maxWidth, constraints.maxHeight);
      if (size != _viewport) {
        _viewport = size;
        // The floor moves with the window, so a zoom that was legal in the
        // old one may not be in this one. Bring it inside the range before
        // the camera is derived from it.
        _zoom = _zoom.clamp(minZoom, AtlasZoom.max);
        // First layout, or a resize: land on the current location, or keep
        // the camera legal for the new window.
        _camera = _clamp(
          _camera == null ? _centredOn(widget.scene.current) : _camera!,
          _zoom,
        );
      }
      final Offset camera = _camera!;
      final double dpr = MediaQuery.devicePixelRatioOf(context);

      // Snapped at draw as well as at gesture end, so a mid-drag frame is also
      // crisp. Panning is then a translation of already-rasterised layers.
      final double tx = -(camera.dx * _zoom * dpr).round() / dpr;
      final double ty = -(camera.dy * _zoom * dpr).round() / dpr;

      return ClipRect(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onScaleEnd: _onScaleEnd,
          child: TickerMode(
            enabled: _animate,
            // The OverflowBox sits *outside* the Transform, deliberately. A
            // RenderBox refuses a hit outside its own size before it asks its
            // children, so a viewport-sized box transformed over the world
            // would only ever hit-test the top-left viewport's worth of world
            // pixels — every marker beyond that would be visible and dead.
            // With the world-sized box as the Transform's child, the
            // Transform is world-sized, and every screen point inside the
            // viewport is inside it.
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: widget.scene.worldWidth,
              maxWidth: widget.scene.worldWidth,
              minHeight: widget.scene.worldHeight,
              maxHeight: widget.scene.worldHeight,
              child: Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(tx, ty, 0, 1)
                  ..scaleByDouble(_zoom, _zoom, 1, 1),
                child: SizedBox(
                  width: widget.scene.worldWidth,
                  height: widget.scene.worldHeight,
                  child: Stack(
                    children: <Widget>[
                      AtlasBaseLayer(scene: widget.scene),
                      AtlasRouteLayer(scene: widget.scene, way: widget.way),
                      AtlasLandmarkLayer(scene: widget.scene),
                      AtlasOverlayLayer(scene: widget.scene),
                      AtlasMarkerLayer(
                        scene: widget.scene,
                        selected: widget.selected,
                        kinds: widget.kinds,
                        zoom: _zoom,
                        arrivalToken: _arrivals,
                        onSelect: widget.onSelect,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
