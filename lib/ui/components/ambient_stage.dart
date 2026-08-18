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
/// Nothing here reads the domain. The play token arrives from the caller
/// exactly as it always did.
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../icons/sprite_footprints.dart';
import 'ambient_player.dart';
import 'ambient_scene.dart';
import 'sprite_animation.dart';

class AmbientStage extends StatefulWidget {
  const AmbientStage({
    super.key,
    required this.gatherFrames,
    required this.gatherFootprint,
    required this.playToken,
    required this.scenes,
    required this.restFrame,
    required this.restFootprint,
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

    return RepaintBoundary(
      child: Stack(
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
      ),
    );
  }
}
