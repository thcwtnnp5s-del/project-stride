/// Plays ambient scenes: picks one, runs it, rests, picks another.
///
/// ## What drives it
///
/// One `AnimationController` and nothing else. Its duration is set to the
/// current phase — a scene's length, or the rest between scenes — and its status
/// listener advances the machine when it completes. There is no `Timer`, no
/// periodic timer, and no clock read: `S-01A` forbids background execution
/// primitives in `lib/`, and an ambient system is exactly the kind of thing that
/// reaches for one. A ticker stops with the frame schedule, which is what a
/// presentation should do — offscreen, backgrounded, or under `TickerMode`, it
/// costs nothing and depicts nothing.
///
/// ## Why a visit is bounded
///
/// A visit plays [AmbientPlayer.scenesPerVisit] scenes and then settles on the
/// rest frame. The Traveler does a few things and then stands, and a new visit
/// begins when the player comes back to the app (`AppLifecycleState.resumed`)
/// or interacts (a gather ends). That is the product read the owner asked for —
/// pleasant to *open* — and it is honest about the alternative: a figure that
/// never stops moving starts to imply that something is happening
/// (`FRESH_CHAT_HANDOFF §16`: "must not pretend gameplay is happening"). It
/// also means the stage settles, which every widget test in the repository
/// relies on when it calls `pumpAndSettle`. Pass `null` for an endless
/// rotation where one is wanted deliberately.
///
/// ## Priority
///
/// The player does not know about gathers. Its parent tells it to
/// [AmbientPlayer.suspended] and it stops mid-scene; when released it rests
/// first, then begins a fresh visit. The rest frame on both sides of a gather is
/// what keeps ambient → gather → ambient from popping.
library;

import 'dart:math' show Random;

import 'package:flutter/widgets.dart';

import '../icons/sprite_footprints.dart';
import 'ambient_scene.dart';
import 'grounded_sprite.dart';

class AmbientPlayer extends StatefulWidget {
  const AmbientPlayer({
    super.key,
    required this.scenes,
    required this.restFrame,
    required this.restFootprint,
    this.scale = 2,
    this.suspended = false,
    this.scenesPerVisit = 4,
    this.restBetween = const Duration(milliseconds: 1600),
    this.seed,
    this.onSceneChanged,
  }) : assert(
         scenesPerVisit == null || scenesPerVisit > 0,
         'a visit with no scenes is the rest frame',
       );

  final AmbientSceneSet scenes;

  /// What shows between scenes and after the visit — the shared standing pose.
  final String restFrame;
  final SpriteFootprint restFootprint;

  final int scale;

  /// True while something with priority is playing on the same stage. The
  /// player stops and shows nothing until released.
  final bool suspended;

  /// Scenes per visit; `null` rotates forever.
  final int? scenesPerVisit;

  /// The hold on the rest frame before the first scene and between scenes.
  final Duration restBetween;

  /// Fixes the scene order, for tests. Presentation only — with `null` the
  /// order differs every mount, which is the point.
  final int? seed;

  /// The scene now showing, or `null` when the rest frame is. Presentation
  /// wiring for a parent that shares the stage.
  final ValueChanged<AmbientScene?>? onSceneChanged;

  @override
  State<AmbientPlayer> createState() => _AmbientPlayerState();
}

enum _Phase {
  /// Holding the rest frame before the next scene.
  rest,

  /// A scene is running.
  scene,

  /// The visit's scenes are spent; resting until something starts a new one.
  spent,
}

class _AmbientPlayerState extends State<AmbientPlayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.restBetween)
        ..addListener(_onTick)
        ..addStatusListener(_onStatus);

  late final Random _rng = Random(widget.seed);

  _Phase _phase = _Phase.spent;
  AmbientScene? _scene;
  int _played = 0;

  /// The frames on screen: Traveler first, then one per layer. Compared on
  /// every tick so a rebuild happens only when a frame actually changes.
  List<int> _frames = const <int>[0];

  bool _precached = false;

  /// True while the lifecycle, not the parent, has stopped the ticker.
  bool _heldByLifecycle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.suspended) _beginVisit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    precacheImage(AssetImage(widget.restFrame), context);
    for (final String frame in widget.scenes.allFrames) {
      precacheImage(AssetImage(frame), context);
    }
  }

  @override
  void didUpdateWidget(AmbientPlayer old) {
    super.didUpdateWidget(old);
    if (widget.suspended != old.suspended) {
      if (widget.suspended) {
        _controller.stop();
        _setScene(null, _Phase.spent);
      } else {
        // Released after a gather: a fresh visit, starting with a rest so the
        // stage settles on the standing pose before the next scene.
        _beginVisit();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_heldByLifecycle) {
        _heldByLifecycle = false;
        if (!widget.suspended) _controller.forward();
      } else if (_phase == _Phase.spent && !widget.suspended) {
        // Coming back to the app is what a visit is.
        _beginVisit();
      }
      return;
    }
    if (_controller.isAnimating) {
      _heldByLifecycle = true;
      _controller.stop();
    }
  }

  void _beginVisit() {
    _played = 0;
    _heldByLifecycle = false;
    if (widget.scenes.isEmpty) {
      _setScene(null, _Phase.spent);
      return;
    }
    _startRest();
  }

  void _startRest() {
    _setScene(null, _Phase.rest);
    _controller
      ..duration = widget.restBetween
      ..forward(from: 0);
  }

  void _startScene() {
    final AmbientScene next = widget.scenes.pick(
      _rng.nextDouble(),
      avoidId: _scene?.id ?? _lastId,
    );
    _played += 1;
    _setScene(next, _Phase.scene);
    _controller
      ..duration = next.duration
      ..forward(from: 0);
  }

  /// The last scene shown, so a rest between two scenes does not forget what
  /// preceded it and let it repeat.
  String? _lastId;

  void _setScene(AmbientScene? scene, _Phase phase) {
    if (_scene != null) _lastId = _scene!.id;
    final bool changed = scene != _scene;
    setState(() {
      _scene = scene;
      _phase = phase;
      _frames = _framesAt(Duration.zero);
    });
    if (changed) widget.onSceneChanged?.call(scene);
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    switch (_phase) {
      case _Phase.rest:
        final int? limit = widget.scenesPerVisit;
        if (limit != null && _played >= limit) {
          _setScene(null, _Phase.spent);
        } else {
          _startScene();
        }
      case _Phase.scene:
        _startRest();
      case _Phase.spent:
        break;
    }
  }

  Duration get _elapsed {
    final Duration d = _controller.duration ?? Duration.zero;
    return d * _controller.value;
  }

  List<int> _framesAt(Duration elapsed) {
    final AmbientScene? s = _scene;
    if (s == null) return const <int>[0];
    return <int>[
      s.traveler.frameAt(elapsed),
      for (final AmbientLayer l in s.layers) l.track.frameAt(elapsed),
    ];
  }

  void _onTick() {
    if (_phase != _Phase.scene) return;
    final List<int> next = _framesAt(_elapsed);
    bool same = next.length == _frames.length;
    for (int i = 0; same && i < next.length; i++) {
      same = next[i] == _frames[i];
    }
    if (same) return;
    setState(() => _frames = next);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AmbientScene? s = _scene;
    if (s == null || widget.suspended) {
      return GroundedSprite(
        assetPath: widget.restFrame,
        footprint: widget.restFootprint,
        scale: widget.scale,
      );
    }

    final int scale = widget.scale;
    final Widget traveler = GroundedSprite(
      assetPath: s.traveler.frames[_frames[0]],
      footprint: s.footprint,
      scale: scale,
      canvas: s.canvas,
      canvasHeight: s.canvasHeight,
    );
    // A wider-than-64 frame is drawn shifted left by its anchor, so the figure
    // stands exactly where the 64-wide rest frame stands. Layer offsets are
    // authored in the *scene frame's* coordinates and shift with it.
    final double shift = -(s.anchorX * scale).toDouble();

    Widget layerAt(int i) {
      final AmbientLayer l = s.layers[i];
      return Positioned(
        left: shift + (l.dx * scale),
        top: (l.dy * scale).toDouble(),
        child: GroundedSprite(
          assetPath: l.track.frames[_frames[i + 1]],
          footprint: l.footprint,
          scale: scale,
          canvas: l.canvas,
        ),
      );
    }

    // The composite is always the standard 64-box; companions and wider frames
    // overhang it. Sized the same for every scene so the stage's layout is
    // identical with and without a cat, and identical to the rest frame.
    return SizedBox(
      width: (64 * scale).toDouble(),
      height: (64 * scale + ContactShadowSpec.bleed * scale).toDouble(),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (int i = 0; i < s.layers.length; i++)
            if (s.layers[i].behind) layerAt(i),
          Positioned(top: 0, left: shift, child: traveler),
          for (int i = 0; i < s.layers.length; i++)
            if (!s.layers[i].behind) layerAt(i),
        ],
      ),
    );
  }
}
