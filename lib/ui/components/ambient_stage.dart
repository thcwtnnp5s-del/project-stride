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

/// The far scenery of a stage: one ×1 vignette with its measured opaque box.
final class StageScenery {
  const StageScenery({
    required this.assetPath,
    required this.bounds,
    this.native = 96,
  });

  final String assetPath;

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
    this.scale = 2,
    this.scenesPerVisit = 4,
    this.seed,
  });

  /// See [SpriteAnimation].
  final List<String> gatherFrames;
  final SpriteFootprint gatherFootprint;
  final Object? playToken;

  /// See [AmbientPlayer].
  final AmbientSceneSet scenes;
  final String restFrame;
  final SpriteFootprint restFootprint;
  final int? scenesPerVisit;
  final int? seed;

  /// The far vignette behind the figures, or none.
  final StageScenery? scenery;

  final int scale;

  @override
  State<AmbientStage> createState() => _AmbientStageState();
}

class _AmbientStageState extends State<AmbientStage> {
  bool _gatherPlaying = false;
  bool _sceneShowing = false;

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
    final bool ambientVisible = _sceneShowing && !_gatherPlaying;

    // The two performers, in the 64-box. Sized by the gather widget.
    final Widget figures = Stack(
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
                Positioned(
                  left: layout.groupLeft,
                  top: layout.groupTop,
                  child: figures,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
