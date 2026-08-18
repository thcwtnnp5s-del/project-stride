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

/// The zoom range. 1 is the art at its integer display scale; 2 is close
/// enough to read a landmark and far enough that a phone still shows a
/// neighbourhood rather than a single tile.
abstract final class AtlasZoom {
  const AtlasZoom._();

  static const double min = 1;
  static const double max = 2;
}

class AtlasViewport extends StatefulWidget {
  const AtlasViewport({
    super.key,
    required this.scene,
    required this.selected,
    required this.onSelect,
  });

  final AtlasScene scene;
  final ContentId? selected;
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
  double _zoom = AtlasZoom.min;

  Size _viewport = Size.zero;

  Offset _gestureCamera = Offset.zero;
  double _gestureZoom = AtlasZoom.min;
  Offset _gestureFocal = Offset.zero;

  AppLifecycleState? _lifecycle;

  /// Where the camera is, in world pixels. For tests.
  Offset get camera => _camera ?? Offset.zero;

  /// The current zoom. For tests.
  double get zoom => _zoom;

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
    // Arriving somewhere recentres the camera on it once. A pan the player
    // made since is theirs to keep otherwise; only a change of location
    // moves the window.
    if (oldWidget.scene.current.id != widget.scene.current.id &&
        _camera != null) {
      _camera = _clamp(_centredOn(widget.scene.current), _zoom);
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
      AtlasZoom.min,
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
  double _snapZoom(double zoom, double dpr) {
    final double unit = dpr == dpr.roundToDouble()
        ? 1 / (widget.scene.layout.scale * dpr)
        : 0.25;
    return ((zoom / unit).round() * unit).clamp(AtlasZoom.min, AtlasZoom.max);
  }

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
                      AtlasRouteLayer(scene: widget.scene),
                      AtlasLandmarkLayer(scene: widget.scene),
                      AtlasOverlayLayer(scene: widget.scene),
                      AtlasMarkerLayer(
                        scene: widget.scene,
                        selected: widget.selected,
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
