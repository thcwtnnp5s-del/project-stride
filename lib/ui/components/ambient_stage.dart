/// One stage, two performers, one rule: the gather has priority.
///
/// The [SpriteAnimation] that plays a successful gather stays exactly what it
/// was — one shot, on the result, resting on frame 0. This widget puts an
/// [AmbientPlayer] beside it and decides which is visible:
///
/// - a gather is playing → the gather, and the ambient player is suspended;
/// - an ambient scene is showing → the scene, and the gather widget is hidden
///   (kept mounted, so it can still receive the next `playToken`);
/// - otherwise → the gather widget at its rest frame, which is the same figure
///   the ambient player rests on. Two rests that are the same picture is what
///   makes the hand-off invisible.
///
/// ## The composition
///
/// The stage is also where the figure meets its scenery — the node vignette,
/// an oak stand or a copper seam — and the owner's device review found the two
/// fighting: the figure stood *through* the vignette on one ground line, the
/// cat landed off the stage or on top of the tree, and the whole read as PNGs
/// stacked rather than one scene. [AmbientStageLayout] is the answer, and it
/// is a **model, not an engine**: two zones, a handful of measured numbers,
/// and a test that holds every scene to them (`test/ambient_composition_test`).
///
/// - The **scenery** is far. It is ×1 art, and it is drawn behind the figures,
///   against the stage's left edge and **raised** so its baseline sits well
///   above the figures' ground line — the near/far split the location
///   vignettes already use. Raised, a ×2 figure standing in front of it reads
///   as depth; on the same ground line it reads as a giant in a shrub.
/// - The **figures** are near, at ×2, on the stage floor, with the Traveler's
///   feet at a fixed spot right of centre. Right, because the Traveler's
///   companions — the cat batting a string, the cat under a petting hand, the
///   cat in the combined petting sprite — are all authored on his viewer-left,
///   and the ground band under the raised scenery is exactly where a small
///   near thing on the ground goes. Every scene's offsets are authored in
///   `ambient_assets.dart` against the measured extents so nothing leaves the
///   stage and nothing lands on the vignette; the stage clips regardless.
///
/// Nothing here reads the domain. The play token arrives from the caller
/// exactly as it always did.
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../icons/sprite_footprints.dart';
import 'ambient_player.dart';
import 'ambient_scene.dart';
import 'grounded_sprite.dart';
import 'pixel_asset.dart';
import 'sprite_animation.dart';

/// One frame of the activity loop. 110 ms — the same hold `SpriteAnimation`
/// gives the one-shot gather, so the working loop and the one-shot it replaces
/// read at the same tempo.
const Duration _activityFrameDuration = Duration(milliseconds: 110);

/// The far scenery of a stage: one ×1 vignette with its measured opaque box.
final class StageScenery {
  const StageScenery({
    required this.assetPath,
    required this.bounds,
    this.native = 96,
    this.behindFigure = false,
  });

  final String assetPath;

  /// Whether this prop is painted **before** the figure rather than after.
  ///
  /// The default — after — is right for something the Traveler works *down
  /// onto*: an anvil, a cookfire, an ore boulder at knee height. Painting it
  /// last puts it nearer the camera, and the tool passes behind its far edge
  /// at the bottom of the swing, which is what depth looks like.
  ///
  /// It is wrong for anything tall enough to occlude the swing. Blind QA
  /// found the case: a tree trunk drawn after the figure **hid the axe
  /// completely**, and the reviewer's honest first read of the frame was "a
  /// man pointing at a tree". A prop the tool disappears into is not a prop
  /// the tool is hitting.
  ///
  /// Declared per prop rather than inferred from the bounds. The question is
  /// not how tall the art is, it is whether the tool's arc crosses it — and
  /// the person who chose the loop is the one who knows.
  final bool behindFigure;

  /// Native square size of the vignette, in pixels.
  final int native;

  /// Opaque box inside the vignette, measured by
  /// `Scripts/art/measure-ambient-extents.js`.
  final SpriteBounds bounds;
}

/// Where everything on the stage goes, in dp, for one stage size.
///
/// Pure arithmetic over the constants below; the widget lays out with it and
/// the composition test lays out with it, so the two cannot disagree.
final class AmbientStageLayout {
  const AmbientStageLayout({
    required this.width,
    required this.height,
    this.scale = 2,
  });

  final double width;
  final double height;
  final int scale;

  /// The Traveler's ground-contact centre as a fraction of the stage width.
  /// Right of centre: see the library doc for why the companions need the
  /// room on his left.
  static const double travelerCentre = 0.6;

  /// Room kept between the widest scene's right edge and the stage edge —
  /// the raised stretch arm reaches 128 dp right of the 64-box's left edge.
  static const double travelerRightRoom = 6;

  /// Left inset of the scenery, dp.
  static const double sceneryInset = 4;

  /// How far above the stage floor the scenery's **lowest opaque row** sits,
  /// dp — its measured base, not its frame edge, so a vignette with ten
  /// transparent rows under it is not raised ten dp higher than one without.
  /// This is the depth cue: the base is 39 dp above the Traveler's ground
  /// line, and one dp clear of the tallest companion's ears (a cat's opaque
  /// top is row 10, so its ears are 46 dp above the floor).
  static const double sceneryBaseline = 47;

  /// The 64-box's own contact centre in dp: the gather rest footprint's centre
  /// (`SpriteFootprints.gather`, 19..42 → 31) at scale. Every scene shares it,
  /// so the figure never jumps between rest and scene.
  double get _footprintCentre => SpriteFootprints.gather.centerX * scale;

  double get groupWidth => 64.0 * scale;

  /// The group's box is the sprite plus the contact shadow's bleed.
  double get groupHeight => (64 + ContactShadowSpec.bleed) * scale;

  /// Left edge of the 64-box, snapped to whole dp so sprite pixels stay on
  /// the grid, and held back from the right edge so the widest scene fits.
  double get groupLeft {
    final double wanted = (width * travelerCentre - _footprintCentre)
        .roundToDouble();
    final double most = width - groupWidth - travelerRightRoom;
    return wanted < most ? wanted : most;
  }

  double get groupTop => height - groupHeight;

  /// The stage floor, in dp from the top: the rest frame's lowest opaque row.
  double get groundLine =>
      groupTop + (SpriteFootprints.gather.bottom + 1) * scale;

  /// The 64-box, in stage dp.
  Rect get groupRect =>
      Rect.fromLTWH(groupLeft, groupTop, groupWidth, groupHeight);

  /// The figure's ground-contact centre, in stage dp. Where the feet are.
  double get feetCentre => groupLeft + SpriteFootprints.gather.centerX * scale;

  /// Room between the figure's feet and the prop he is working on, dp.
  static const double propGap = 8;

  /// Where a **near interaction prop** goes: the thing the Traveler is
  /// working *on*, as opposed to the place he is working *in*.
  ///
  /// Two placements, and the difference is the whole point of the pair:
  ///
  /// - [sceneryRect] is **far** — left edge, raised, ×1 behind the figure.
  ///   It answers *where is he*, and it is right for an idle location.
  /// - This is **near** — on his own ground line, immediately in front of
  ///   his feet, drawn after him. It answers *what is he hitting*.
  ///
  /// In front means whichever side the loop actually works towards, which is
  /// **not the same for every profession**. Woodcutting, foraging, smithing
  /// and cooking all face west; the mining loop raises the pick over the
  /// left shoulder and brings it down to the **east**, and its debris flies
  /// east too. Placing every prop west put the ore boulder behind the
  /// miner's back and fired his chips into bare floor.
  ///
  /// The prop's measured base sits exactly on the ground line either way, so
  /// the figure and the thing he is working on share one floor — the single
  /// fact that separates "a scene" from "two sprites in a box".
  Rect propRect(StageScenery p, {bool east = false}) => Rect.fromLTWH(
    east ? feetCentre + propGap : feetCentre - propGap - p.native,
    groundLine - (p.bounds.bottom + 1),
    p.native.toDouble(),
    p.native.toDouble(),
  );

  /// The prop's opaque box in stage dp.
  Rect propOpaque(StageScenery p, {bool east = false}) {
    final Rect r = propRect(p, east: east);
    return Rect.fromLTRB(
      r.left + p.bounds.left,
      r.top + p.bounds.top,
      r.left + p.bounds.right + 1,
      r.top + p.bounds.bottom + 1,
    );
  }

  Rect sceneryRect(StageScenery s) => Rect.fromLTWH(
    sceneryInset,
    height - sceneryBaseline - (s.bounds.bottom + 1),
    s.native.toDouble(),
    s.native.toDouble(),
  );

  /// The scenery's opaque box in stage dp.
  Rect sceneryOpaque(StageScenery s) {
    final Rect r = sceneryRect(s);
    return Rect.fromLTRB(
      r.left + s.bounds.left,
      r.top + s.bounds.top,
      r.left + s.bounds.right + 1,
      r.top + s.bounds.bottom + 1,
    );
  }

  /// A box authored in 64-box sprite pixels, in stage dp.
  Rect placed(SpriteBounds b) => Rect.fromLTRB(
    groupLeft + b.left * scale,
    groupTop + b.top * scale,
    groupLeft + (b.right + 1) * scale,
    groupTop + (b.bottom + 1) * scale,
  );

  Rect get stageRect => Rect.fromLTWH(0, 0, width, height);
}

class AmbientStage extends StatefulWidget {
  const AmbientStage({
    super.key,
    required this.gatherFrames,
    required this.gatherFootprint,
    required this.playToken,
    required this.scenes,
    required this.restFrame,
    required this.restFootprint,
    this.scenery,
    this.prop,
    this.propEast = false,
    this.scale = 2,
    this.scenesPerVisit = 4,
    this.cadence = AmbientCadence.standard,
    this.seed,
    this.activityFrames,
    this.activityFootprint,
    this.activityActive = false,
    this.activityCanvas = 64,
  });

  /// See [SpriteAnimation].
  final List<String> gatherFrames;
  final SpriteFootprint gatherFootprint;
  final Object? playToken;

  /// The activity mode: while [activityActive] and [activityFrames] are both
  /// supplied, the stage loops those frames continuously — replacing the
  /// ambient cadence, the companion scenes, the rest frame **and** the
  /// one-shot [playToken] animation, whose completion feedback is UI-level
  /// during a queue. The scenery composition is unchanged; when inactive the
  /// stage behaves exactly as before these parameters existed.
  final List<String>? activityFrames;
  final SpriteFootprint? activityFootprint;
  final bool activityActive;

  /// The activity frames' native width. The work loops are wider than the
  /// 64-box — a swung axe needs the room on both sides of the figure — and
  /// the loop is drawn with its **feet centre on the rest pose's feet
  /// centre**, so starting a queue never makes the Traveler sidestep. The
  /// overhang is headroom the stage's own clip owns; height stays the 64-row
  /// convention (feet on row 62).
  final int activityCanvas;

  /// See [AmbientPlayer].
  final AmbientSceneSet scenes;
  final String restFrame;
  final SpriteFootprint restFootprint;
  final int? scenesPerVisit;

  /// What the player does after the visit. `null` is the visit and then the
  /// rest frame; the default is the idle cadence. See [AmbientPlayer].
  final AmbientCadence? cadence;
  final int? seed;

  /// The far vignette behind the figures, or none. The *place*.
  final StageScenery? scenery;

  /// The near prop the figure is working on, or none. The *thing*.
  ///
  /// Drawn on the figure's ground line, immediately in front of his feet and
  /// **after** him in paint order, so a swung tool passes in front of the
  /// prop's far side and lands on it. See [AmbientStageLayout.propRect].
  ///
  /// This slot exists because the craft screen needed it first and placed its
  /// forge by hand, and the Adventure stage then needed exactly the same
  /// thing for a copper seam. Two hand-placements of one idea is one idea
  /// too few.
  final StageScenery? prop;

  /// Which side of the figure [prop] stands on — see
  /// [AmbientStageLayout.propRect]. A property of the **loop**, not of the
  /// prop: the same ore boulder goes east of a miner and would go west of
  /// anyone facing the other way.
  final bool propEast;

  final int scale;

  @override
  State<AmbientStage> createState() => _AmbientStageState();
}

/// The near prop, placed by the layout. One builder, so the two paint-order
/// branches cannot drift into two different placements.
Widget _prop(AmbientStageLayout layout, StageScenery prop, bool east) =>
    Positioned(
  left: layout.propRect(prop, east: east).left,
  top: layout.propRect(prop, east: east).top,
  child: PixelAsset(
    assetPath: prop.assetPath,
    nativeWidth: prop.native,
    nativeHeight: prop.native,
    scale: 1,
  ),
);

class _AmbientStageState extends State<AmbientStage> {
  bool _gatherPlaying = false;
  bool _sceneShowing = false;

  @override
  void didUpdateWidget(AmbientStage old) {
    super.didUpdateWidget(old);
    // Crossing into or out of activity mode unmounts the performers, so the
    // callbacks that would have cleared these flags never arrive. Reset them
    // here; the freshly mounted players report their real state on the next
    // change, and both rests are the same picture in the meantime.
    if (widget.activityActive != old.activityActive) {
      _gatherPlaying = false;
      _sceneShowing = false;
    }
  }

  void _onGatherPlaying(bool playing) {
    if (playing == _gatherPlaying) return;
    _gatherPlaying = playing;
    _rebuild();
  }

  void _onScene(AmbientScene? scene) {
    final bool showing = scene != null;
    if (showing == _sceneShowing) return;
    _sceneShowing = showing;
    _rebuild();
  }

  /// Both callbacks can arrive from a child's `didUpdateWidget` — a new play
  /// token starts the gather during this widget's own build. A `setState` then
  /// is an error, so the rebuild waits for the end of the frame; the child has
  /// already changed, only the visibility swap is a frame late.
  void _rebuild() {
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
  Widget build(BuildContext context) {
    final List<String>? activityFrames = widget.activityFrames;
    final SpriteFootprint? activityFootprint = widget.activityFootprint;
    final bool activityRunning =
        widget.activityActive &&
        activityFrames != null &&
        activityFootprint != null;

    final bool ambientVisible = _sceneShowing && !_gatherPlaying;

    // The two performers, in the 64-box — or, in activity mode, the working
    // loop alone. The ambient player and the one-shot gather are not mounted
    // while a queue works: the cadence must not run behind the loop, and a
    // remount afterwards starting a fresh visit is the documented behaviour of
    // both players.
    final Widget figures = activityRunning
        // Feet-centre alignment: the loop's canvas is its own width, but the
        // figure must stand exactly where the rest pose stands, so the loop
        // is shifted by the difference between the two footprints' centres.
        ? Transform.translate(
            offset: Offset(
              (widget.gatherFootprint.centerX - activityFootprint.centerX) *
                  widget.scale,
              0,
            ),
            child: _ActivityLoop(
              frames: activityFrames,
              footprint: activityFootprint,
              canvas: widget.activityCanvas,
              scale: widget.scale,
            ),
          )
        : Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: <Widget>[
              // Sizes the stack. Hidden — not removed — while a scene shows, so its
              // controller and its precached frames survive and the next play
              // token lands on a live widget.
              Visibility(
                visible: !ambientVisible,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: SpriteAnimation(
                  frames: widget.gatherFrames,
                  footprint: widget.gatherFootprint,
                  playToken: widget.playToken,
                  scale: widget.scale,
                  onPlayingChanged: _onGatherPlaying,
                ),
              ),
              // Offstage while resting, never unmounted: unmounting would restart
              // the visit on every rest. Offstage still ticks, and it is skipped by
              // hit-testing and by default finders — the rest frame the player
              // would draw here is the one SpriteAnimation is already showing.
              Positioned(
                bottom: 0,
                child: Offstage(
                  offstage: !ambientVisible,
                  child: AmbientPlayer(
                    scenes: widget.scenes,
                    restFrame: widget.restFrame,
                    restFootprint: widget.restFootprint,
                    scale: widget.scale,
                    suspended: _gatherPlaying,
                    scenesPerVisit: widget.scenesPerVisit,
                    cadence: widget.cadence,
                    seed: widget.seed,
                    onSceneChanged: _onScene,
                  ),
                ),
              ),
            ],
          );

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // A stage placed loose (a test's `Center`) is exactly the figures'
          // own box: no scenery room, group at the left edge.
          final double s = widget.scale.toDouble();
          final AmbientStageLayout layout = AmbientStageLayout(
            width: constraints.hasBoundedWidth
                ? constraints.maxWidth
                : 64 * s + AmbientStageLayout.travelerRightRoom,
            height: constraints.hasBoundedHeight
                ? constraints.maxHeight
                : (64 + ContactShadowSpec.bleed) * s,
            scale: widget.scale,
          );
          final StageScenery? scenery = widget.scenery;
          final StageScenery? prop = widget.prop;
          return SizedBox(
            width: layout.width,
            height: layout.height,
            child: Stack(
              // Layers may overhang the 64-box; the caller's clip is the stage
              // edge, and the table keeps them inside it anyway.
              clipBehavior: Clip.none,
              children: <Widget>[
                if (scenery != null)
                  Positioned(
                    left: layout.sceneryRect(scenery).left,
                    top: layout.sceneryRect(scenery).top,
                    child: PixelAsset(
                      assetPath: scenery.assetPath,
                      nativeWidth: scenery.native,
                      nativeHeight: scenery.native,
                      scale: 1,
                    ),
                  ),
                if (prop != null && prop.behindFigure)
                  _prop(layout, prop, widget.propEast),
                Positioned(
                  left: layout.groupLeft,
                  top: layout.groupTop,
                  child: figures,
                ),
                // After the figure by default: the tool reaches over the
                // prop's near edge and lands on it, rather than behind it.
                // See `StageScenery.behindFigure` for the exception.
                if (prop != null && !prop.behindFigure)
                  _prop(layout, prop, widget.propEast),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The continuous working loop a running activity queue shows.
///
/// Deliberately **not** [SpriteAnimation] with a repeating token: that widget's
/// whole contract is "a discrete command happened once", and the queue's
/// contract is the opposite — visible ongoing work whose each completion is
/// reported at UI level. Looping only while mounted means it costs nothing
/// offscreen, and the vsync-driven controller stops under `TickerMode` like
/// every other stage animation. Reduced motion holds frame 0, the shared
/// standing pose.
class _ActivityLoop extends StatefulWidget {
  const _ActivityLoop({
    required this.frames,
    required this.footprint,
    required this.canvas,
    required this.scale,
  });

  final List<String> frames;
  final SpriteFootprint footprint;
  final int canvas;
  final int scale;

  @override
  State<_ActivityLoop> createState() => _ActivityLoopState();
}

class _ActivityLoopState extends State<_ActivityLoop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _activityFrameDuration * widget.frames.length,
  )..addListener(_onTick);

  int _frame = 0;
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      for (final String frame in widget.frames) {
        precacheImage(AssetImage(frame), context);
      }
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      if (_frame != 0) setState(() => _frame = 0);
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  void _onTick() {
    final int next = (_controller.value * widget.frames.length).floor().clamp(
      0,
      widget.frames.length - 1,
    );
    if (next == _frame) return;
    setState(() => _frame = next);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GroundedSprite(
    assetPath: widget.frames[_frame],
    footprint: widget.footprint,
    canvas: widget.canvas,
    canvasHeight: 64,
    scale: widget.scale,
  );
}
