/// A one-shot sprite animation that plays on a signal and returns to rest.
///
/// ## Why one-shot rather than looping
///
/// The animation depicts a **discrete command**. `GatherResource` happens once
/// per tap; a loop would depict a character gathering continuously, which is the
/// persistent-activity system Phase 1 deliberately does not have — the same
/// system the `54 / 90` progress bar, the `Stop` button and the `Change
/// activity` button were all cut for asserting.
///
/// So it rests on frame 0, plays once when a gather succeeds, and rests again.
/// What the player sees matches what the engine did.
///
/// ## Why it plays on the result rather than on the tap
///
/// A refused gather must not animate. Driving the animation from the tap would
/// show the Traveler picking a herb they did not get — the fabricated-success
/// defect, in motion, and more convincing than a text line would be.
library;

import 'package:flutter/widgets.dart';

import '../icons/sprite_footprints.dart';
import 'grounded_sprite.dart';

/// How long each frame holds.
///
/// Eight frames at 110 ms is 880 ms end to end — long enough to read as a
/// deliberate action, short enough that the result line and the refreshed step
/// balance are not waiting on it. Nothing in the domain is gated on this: the
/// command has already committed before the first frame is drawn.
const Duration _frameDuration = Duration(milliseconds: 110);

class SpriteAnimation extends StatefulWidget {
  const SpriteAnimation({
    super.key,
    required this.frames,
    required this.footprint,
    required this.playToken,
    this.scale = 2,
    this.canvas = 64,
    this.onPlayingChanged,
  });

  /// Called with `true` when a play starts and `false` when it completes, so a
  /// parent that shows something else while this rests can yield the moment a
  /// gather begins. Presentation wiring only; nothing is decided here.
  final ValueChanged<bool>? onPlayingChanged;

  /// In order. Frame 0 is the rest pose and is what shows when nothing is
  /// playing.
  final List<String> frames;

  /// The rest-pose footprint, shared by every frame. See
  /// `Scripts/art/package-art.js` — a per-frame footprint would swell and shrink
  /// the shadow under a character whose feet never move.
  final SpriteFootprint footprint;

  /// Changing this to a new non-null value plays the animation once. Null never
  /// plays. The caller supplies the identity of the event, so a rebuild for any
  /// other reason cannot retrigger it.
  final Object? playToken;

  final int scale;

  /// Native frame width, in sprite pixels.
  ///
  /// 64 for the gather cycle. The per-skill work loops are wider — the tool's
  /// swing needs the room — so a one-shot built from one of those renders at
  /// the wrong canvas unless it says so. Passed through to [GroundedSprite],
  /// which is what actually knows how to size a non-square frame.
  final int canvas;

  @override
  State<SpriteAnimation> createState() => _SpriteAnimationState();
}

class _SpriteAnimationState extends State<SpriteAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
          vsync: this,
          duration: _frameDuration * widget.frames.length,
        )
        ..addListener(_onTick)
        ..addStatusListener(_onStatus);

  int _frame = 0;
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decoding a frame mid-animation would drop it, and a dropped frame in an
    // eight-frame cycle is an eighth of the action. Done here rather than in
    // initState because it needs a BuildContext.
    if (_precached) return;
    _precached = true;
    for (final String frame in widget.frames) {
      precacheImage(AssetImage(frame), context);
    }
  }

  @override
  void didUpdateWidget(SpriteAnimation old) {
    super.didUpdateWidget(old);
    if (widget.playToken != null && widget.playToken != old.playToken) {
      _controller.forward(from: 0);
    }
  }

  void _onStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
        widget.onPlayingChanged?.call(true);
      case AnimationStatus.completed || AnimationStatus.dismissed:
        widget.onPlayingChanged?.call(false);
      case AnimationStatus.reverse:
        break;
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
  Widget build(BuildContext context) {
    // Rest on frame 0 whenever nothing is running, rather than holding the last
    // frame: the final pose has the herb in hand, and leaving it there would be
    // a durable depiction of a result that has already been collected.
    final int frame = _controller.isAnimating ? _frame : 0;
    return GroundedSprite(
      assetPath: widget.frames[frame],
      footprint: widget.footprint,
      scale: widget.scale,
      canvas: widget.canvas,
    );
  }
}
