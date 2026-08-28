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
/// added later cannot forget to pause. Since the shell keeps every tab's
/// screen alive (Fable V2), what stops the atlas when its tab is hidden is
/// the shell's own per-tab [TickerMode] wrap (`stride_shell.dart`), not an
/// unmount — the two TickerModes nest, and either being disabled silences
/// everything here.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

import 'atlas_layers.dart';
import 'atlas_layout.dart';
import 'atlas_place_info.dart';

/// The zoom range, derived from the layout's `scale`. Nothing here — and
/// nothing anywhere on the atlas — may assume the world's size or its
/// display scale.
///
/// ## The semantics the three stops are authored in
///
/// Zoom multiplies **world pixels into logical dp**, and a world pixel is a
/// native art pixel times the layout's scale — so one native art pixel spans
/// `scale × zoom` dp on screen. The stops are therefore native-art facts
/// divided by the scale, and they land on the same three views whatever the
/// layout declares:
///
/// - [absoluteFloor] is native ×1 (`1 / scale`) — every source pixel exactly
///   one logical pixel, sampled nearest-neighbour, the crispest a reduction
///   can be. Below it the sampler would start dropping columns, so the range
///   never goes there.
/// - [initial] is native ×2 (`2 / scale`) — exactly the opening view the
///   owner accepted on the shipped layout.
/// - [max] is native ×4 (`4 / scale`) — the close-reading zoom.
///
/// On the shipped `scale: 2` layout those are 0.5 / 1 / 2, unchanged; on a
/// `scale: 4` master painting they become 0.25 / 0.5 / 1, and the floor
/// frames a 1536-wide world on a phone.
///
/// ## Why the floor is computed rather than declared
///
/// The floor is the **larger** of two numbers, and the pair is the whole
/// rule: `viewportWidth / worldWidth` is the zoom at which the world's full
/// width fits the window, and [absoluteFloor] is as far out as the art stays
/// worth looking at. For a small world the first wins and the player can see
/// all of it and no further; for a large one the second wins and the whole
/// world frames inside the window.
final class AtlasZoom {
  const AtlasZoom.forScale(int scale)
    : assert(scale >= 1, 'a layout scale is at least 1'),
      absoluteFloor = 1 / scale,
      initial = 2 / scale,
      max = 4 / scale;

  /// As far out as the art is worth showing, whatever the world's size:
  /// native ×1.
  final double absoluteFloor;

  /// The zoom the screen opens at: native ×2, the art's accepted reading.
  final double initial;

  /// Native ×4: close enough to read a landmark.
  final double max;

  /// The one overview threshold (`ACTIVITY_FEEL_PRESENTATION_01.md` §4c):
  /// zoomed out past the opening view is the **overview**. Place names, kind
  /// glyphs, rings, the current marker and the routes stay; landmark captions,
  /// their marker art and scatter props hide until the player zooms back in —
  /// geography carries them at survey distance. No LOD engine: one boundary,
  /// per layer, and this is it.
  double get overviewBelow => initial;

  /// The continuous floor for a [worldWidth]-wide world seen through a
  /// [viewportWidth] window. Never above [max] — a world narrower than the
  /// window would otherwise pin the range shut.
  double minFor({required double viewportWidth, required double worldWidth}) {
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
    this.bottomInset = 0,
    this.onExplored,
    this.arrivalStanding = false,
    this.journey,
    this.travelLegPlaces,
  });

  /// The last committed journey's legs in walked order, for the travel
  /// trace's multi-leg course. Null before any journey.
  final List<ContentId>? travelLegPlaces;

  /// The tracked Journey goal's destination, for the marker layer's gold
  /// ring. Null when no journey is set.
  final ContentId? journey;

  final AtlasScene scene;
  final ContentId? selected;

  /// Whether the last journey's result line is still on screen — handed to
  /// the marker layer so the you-are-here pulse wears the warm arrival ink
  /// for exactly as long as the panel announces the arrival (F4).
  final bool arrivalStanding;

  /// Logical height along the bottom that the translucent info panel covers.
  /// The camera centres the current (and each arrived) location in the map area
  /// *above* this inset, so the you-are-here marker never opens behind the
  /// panel. Panning and clamping still use the full window — a curious player
  /// can pull a lower place up out from behind the glass.
  final double bottomInset;

  /// What kind of place each node is, resolved once by the screen.
  final Map<ContentId, AtlasPlaceKind> kinds;

  /// The walk to the selection, previewed on the roads. Null highlights
  /// nothing.
  final AtlasWay? way;

  final ValueChanged<ContentId> onSelect;

  /// Fired on the player's first pan or pinch, so the screen can retire the
  /// how-to-look-around hint the moment it has been learned. Presentation
  /// only; nothing durable.
  final VoidCallback? onExplored;

  @override
  State<AtlasViewport> createState() => AtlasViewportState();
}

/// Public so a test can read the camera. Nothing outside this file writes it.
class AtlasViewportState extends State<AtlasViewport>
    with WidgetsBindingObserver {
  /// The world coordinate at the viewport's top-left. Null until the first
  /// layout, when it is centred on the current location.
  Offset? _camera;
  late double _zoom = zooms.initial;

  Size _viewport = Size.zero;

  Offset _gestureCamera = Offset.zero;
  double _gestureZoom = 1;
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

  /// The range for this scene's layout scale. Derived, never declared: the
  /// scale-4 master painting and the shipped scale-2 layout both read their
  /// three stops from here.
  AtlasZoom get zooms => AtlasZoom.forScale(widget.scene.layout.scale);

  /// The zoom floor for this window and this world, landed on the pixel grid.
  ///
  /// The continuous floor — `max(whole-width-fits, absoluteFloor)` — is
  /// snapped **down** onto the grid of zooms at which one native art pixel is
  /// a whole number of device pixels, unless the value below would sink under
  /// the absolute floor, in which case it snaps up instead. Down, not up: the
  /// zoom a player reaches by pinching all the way out is the world-framing
  /// survey the owner asked for, and the grid value just under the exact fit
  /// shows the whole width (the clamp centres a world narrower than the
  /// window) while staying crisp. Rounding the floor up — the old rule — left
  /// the full frame unreachable at rest.
  double get minZoom {
    final double unit = _zoomUnit(MediaQuery.devicePixelRatioOf(context));
    final double whole = zooms.minFor(
      viewportWidth: _viewport.width,
      worldWidth: widget.scene.worldWidth,
    );
    final double down = (whole / unit).floorToDouble() * unit;
    final double snapped = down >= zooms.absoluteFloor
        ? down
        : (whole / unit).ceilToDouble() * unit;
    return snapped > zooms.max ? zooms.max : snapped;
  }

  /// The spacing of zooms at which one native art pixel is a whole number of
  /// device pixels: `scale × zoom × dpr` integral. At dpr 3 and scale 2 that
  /// is every sixth; at dpr 3 and scale 4, every twelfth. A non-integer dpr
  /// falls back to quarters, which is as good as such a screen gets.
  double _zoomUnit(double dpr) =>
      dpr == dpr.roundToDouble() ? 1 / (widget.scene.layout.scale * dpr) : 0.25;

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
      // Where the journey set out from, for the travel trace: the marker
      // layer animates a spark along the walked road for a couple of seconds
      // (brief §53). Presentation only, cleared by the next arrival.
      _travelFrom = oldWidget.scene.current;
      if (_camera != null) {
        _camera = _clamp(_centredOn(widget.scene.current), _zoom);
      }
    }
  }

  /// The previous location at the moment of the last arrival, or null before
  /// any journey this session.
  AtlasNode? _travelFrom;

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

  Offset _centredOn(AtlasNode node) {
    // Centre in the map area above the info panel, not the full window, so the
    // current location opens clear of the translucent panel. Guarded so a
    // pathological inset taller than the window cannot invert the maths.
    final double visibleHeight = (_viewport.height - widget.bottomInset).clamp(
      _viewport.height * 0.25,
      _viewport.height,
    );
    return Offset(
      node.x - _viewport.width / (2 * _zoom),
      node.y - visibleHeight / (2 * _zoom),
    );
  }

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
    widget.onExplored?.call();
    final double zoom = (_gestureZoom * details.scale).clamp(
      minZoom,
      zooms.max,
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

  /// The nearest zoom on the whole-device-pixel grid, kept inside the range.
  /// [minZoom] is already a grid value, so the rest state is always one at
  /// which the pixel art is not resampled.
  double _snapZoom(double zoom, double dpr) {
    final double unit = _zoomUnit(dpr);
    return ((zoom / unit).round() * unit).clamp(minZoom, zooms.max);
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
        _zoom = _zoom.clamp(minZoom, zooms.max);
        // First layout, or a resize: land on the current location, or keep
        // the camera legal for the new window.
        _camera = _clamp(
          _camera == null ? _centredOn(widget.scene.current) : _camera!,
          _zoom,
        );
      }
      final Offset camera = _camera!;
      final double dpr = MediaQuery.devicePixelRatioOf(context);
      // Past the opening view the surface is a survey: geography, places,
      // roads, and *here*. One boundary, read by the two layers that thin out.
      final bool overview = _zoom < zooms.overviewBelow;

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
                      AtlasRouteLayer(
                        scene: widget.scene,
                        way: widget.way,
                        zoom: _zoom,
                      ),
                      AtlasLandmarkLayer(
                        scene: widget.scene,
                        overview: overview,
                      ),
                      AtlasOverlayLayer(scene: widget.scene),
                      AtlasMarkerLayer(
                        scene: widget.scene,
                        selected: widget.selected,
                        kinds: widget.kinds,
                        zoom: _zoom,
                        overview: overview,
                        arrivalToken: _arrivals,
                        travelFrom: _travelFrom,
                        travelLegPlaces: widget.travelLegPlaces,
                        arrivalStanding: widget.arrivalStanding,
                        journey: widget.journey,
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
