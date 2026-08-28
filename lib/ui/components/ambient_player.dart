/// Plays ambient scenes: a visit, then an idle cadence, for as long as the
/// player is looking at the screen.
///
/// ## What drives it
///
/// One `AnimationController` and nothing else. Its duration is set to the
/// current phase — a scene's length, or a rest between scenes — and its status
/// listener advances the machine when it completes. There is no background
/// scheduling primitive of any kind and no clock read: `S-01A` forbids them in
/// `lib/`, and an ambient system is exactly the kind of thing that reaches for
/// one. A ticker stops with the frame schedule, which is what a presentation
/// should do — offscreen, backgrounded, or under `TickerMode`, it costs nothing
/// and depicts nothing. Adding the cadence below added no ticker and no
/// per-frame work: the same listener, the same frame comparison, the same early
/// return during a rest.
///
/// ## The freeze, and what caused it
///
/// The owner's device review found the stage frozen. It was not a ticker fault,
/// a `TickerMode` fault or a loop-metadata fault. It was this file's own
/// design, working: `scenesPerVisit = 4` counted four scenes and then moved to
/// a terminal phase that held the rest frame and scheduled nothing further,
/// until either `AppLifecycleState.resumed` or the end of a gather started a
/// fresh visit. A player who opened the Adventure screen and kept it open — the
/// ordinary case — saw the Traveler do four things and then stand still
/// indefinitely. The reasoning for that ("a visit is bounded; the Traveler does
/// a few things and then stands") is recorded in the milestone and is now
/// superseded by owner direction: Stride should feel alive when checked even
/// while idle, and ambient presentation should not commonly end in a visibly
/// frozen pose (`MILESTONES/WORLD_REWARD_DEPTH_01.md` §9).
///
/// ## The cadence
///
/// ```text
/// mount ─► rest(1.6s) ─► scene ─► rest ─► scene …  ×scenesPerVisit   the visit
///                                                   │
///                                                   ▼
///        ┌────────────────────────── idle ──────────────────────────┐
///        │ rest 2–4s ─► micro-idle ─► rest 2–4s ─► micro-idle ─►    │
///        │ rest 4–8s ─► a full scene ─► …  (every 3rd beat)         │
///        └──────────────────────── repeats ─────────────────────────┘
/// ```
///
/// Rest lengths are drawn from the seeded RNG inside [AmbientCadence]'s bounds,
/// so two holds in a row are not the same length; a micro-idle is a scene the
/// table marked with an [AmbientScene.idleWeight]. More than half of an idle
/// cycle is the rest frame. That ratio is the product decision: alive, not
/// busy, and never implying that something is happening (`FRESH_CHAT_HANDOFF`
/// §16).
///
/// Nothing about the cadence is a game fact. It grants nothing, reads nothing
/// and persists nothing; the only thing that changes is which PNG is on screen.
///
/// ## When it runs, and the seam that makes the suite settle
///
/// The idle cadence is a claim about the app being *in front of the player right
/// now*, and the framework states that exactly one way: an
/// `AppLifecycleState.resumed` the binding has actually reported. So:
///
/// - a **visit** starts as soon as the player is mounted, lifecycle or not —
///   that is the "pleasant to open" moment and it must not wait for a message;
/// - the **idle cadence** runs only once `resumed` has been seen, and stops on
///   anything else.
///
/// In the widget-test harness `WidgetsBinding.instance.lifecycleState` is null
/// and stays null unless a test sends a state, so a mounted stage plays its
/// visit and then settles on the rest frame — which is what every
/// `pumpAndSettle` in the suite depends on. **That asymmetry is the test seam,
/// and this paragraph is the one place it is decided.** It is not a
/// test-only branch: it is the same rule, and the same reasoning,
/// `AtlasViewport._animate` already ships with. A test that wants the endless
/// behaviour sends `resumed` (and resets it in a tear-down); a caller that
/// wants a visit and nothing after passes `cadence: null`.
///
/// The **scene dwell** (GAME_FEEL_CHARACTER_PRESENTATION_01, item 3) rides
/// the same seam: a full scene with a [ScenePhasing] holds its loopable
/// middle for a drawn 20–28 s only under `resumed` — on a device, always —
/// while the harness's visits keep their short straight-through scenes and
/// settle exactly as before. One seam, extended; not a second one.
///
/// Reduced motion is honoured on the same footing, via
/// `MediaQuery.disableAnimationsOf` — the convention the atlas set. With it on,
/// the stage is the standing figure and stays that way.
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
    this.cadence = AmbientCadence.standard,
    this.seed,
    this.onSceneChanged,
  }) : assert(
         scenesPerVisit == null || scenesPerVisit > 0,
         'a visit with no scenes is the rest frame',
       );

  final AmbientSceneSet scenes;

  /// What shows between scenes and during every idle rest — the shared
  /// standing pose.
  final String restFrame;
  final SpriteFootprint restFootprint;

  final int scale;

  /// True while something with priority is playing on the same stage. The
  /// player stops and shows nothing until released.
  final bool suspended;

  /// Scenes in the opening visit, before the idle cadence takes over. `null`
  /// makes the visit itself endless, which the cadence then never reaches.
  final int? scenesPerVisit;

  /// The hold on the rest frame before the first scene and between a visit's
  /// scenes. Idle rests are longer, and come from [cadence].
  final Duration restBetween;

  /// What happens after the visit. `null` is "the rest frame, and nothing
  /// further" — the pre-cadence behaviour, kept as an explicit choice for a
  /// caller that wants a stage which finishes.
  final AmbientCadence? cadence;

  /// Fixes the scene order and the rest lengths, for tests. Presentation only
  /// — with `null` both differ every mount, which is the point.
  final int? seed;

  /// The scene now showing, or `null` when the rest frame is. Presentation
  /// wiring for a parent that shares the stage.
  final ValueChanged<AmbientScene?>? onSceneChanged;

  @override
  State<AmbientPlayer> createState() => _AmbientPlayerState();
}

enum _Phase {
  /// Holding the rest frame before the next scene — a visit's short rest or an
  /// idle one, told apart by [_AmbientPlayerState._idling].
  rest,

  /// A scene is running.
  scene,

  /// Nothing is scheduled and nothing will be until something outside says so:
  /// the table is empty, reduced motion is on, a gather has the stage, or the
  /// caller asked for no cadence and the visit is over.
  held,
}

/// Which stretch of a **phased** scene the controller is currently running
/// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 3). [whole] is the legacy
/// straight-through playback — every unphased scene, every micro-idle, and
/// the entire widget-test harness.
enum _ScenePart { whole, intro, hold, outro }

class _AmbientPlayerState extends State<AmbientPlayer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// Built in `initState`, not lazily. A lazy field is only created by its
  /// first read, and with reduced motion on nothing ever reads it — so the
  /// initialiser ran from `dispose`, where creating a ticker means an ancestor
  /// lookup on a deactivated element. One phase of this file that never starts
  /// the controller is enough to make a lazy controller a fault.
  late final AnimationController _controller;

  late final Random _rng = Random(widget.seed);

  /// The two pools, resolved when the set arrives rather than per beat:
  /// `visitScenes` and `microIdles` walk the whole table, and an idle beat
  /// must not do that every few seconds. A table that declares no micro-idles
  /// falls back to the visit pool — the player does not invent one.
  late AmbientSceneSet _visitPool;
  late AmbientSceneSet _microPool;

  void _resolvePools() {
    final AmbientSceneSet visit = widget.scenes.visitScenes;
    _visitPool = visit.isEmpty ? widget.scenes : visit;
    final AmbientSceneSet micro = widget.scenes.microIdles;
    _microPool = micro.isEmpty ? _visitPool : micro;
  }

  _Phase _phase = _Phase.held;
  AmbientScene? _scene;
  int _played = 0;

  /// Which stretch of a phased scene is running; [_ScenePart.whole] for the
  /// legacy straight-through playback.
  _ScenePart _part = _ScenePart.whole;

  /// Scene time already spent in earlier parts, so the companion layers'
  /// sustained tracks see one continuous clock across intro → hold → outro.
  Duration _partsBefore = Duration.zero;

  /// True while the scene on stage is a phased long dwell — what decides
  /// the drawn neutral rest that follows it.
  bool _sceneHeld = false;

  /// True once the visit is spent and the idle cadence has the stage.
  bool _idling = false;

  /// Idle beats played since the cadence began — what decides when a full
  /// scene comes round.
  int _idleBeats = 0;

  /// The frames on screen: Traveler first, then one per layer. Compared on
  /// every tick so a rebuild happens only when a frame actually changes.
  List<int> _frames = const <int>[0];

  bool _started = false;

  /// The last lifecycle state the binding reported, or null when it has not
  /// reported one. See the library doc: null is "not in front of the player",
  /// and it is also the whole of the test seam.
  AppLifecycleState? _lifecycle;

  bool _reduceMotion = false;

  /// True while the lifecycle, not the parent, has stopped the ticker.
  bool _heldByLifecycle = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.restBetween)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    _resolvePools();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.disableAnimationsOf(context);
    final bool motionChanged = _started && reduce != _reduceMotion;
    _reduceMotion = reduce;

    if (!_started) {
      _started = true;
      precacheImage(AssetImage(widget.restFrame), context);
      for (final String frame in widget.scenes.allFrames) {
        precacheImage(AssetImage(frame), context);
      }
      // Started here rather than in `initState` so the first decision already
      // knows whether the platform has asked for reduced motion.
      if (!widget.suspended) _beginVisit();
      return;
    }

    if (!motionChanged) return;
    if (reduce) {
      _controller.stop();
      _hold();
    } else if (!widget.suspended) {
      _beginVisit();
    }
  }

  @override
  void didUpdateWidget(AmbientPlayer old) {
    super.didUpdateWidget(old);
    if (!identical(widget.scenes, old.scenes)) _resolvePools();
    if (widget.suspended != old.suspended) {
      if (widget.suspended) {
        _controller.stop();
        _hold();
      } else {
        // Released after a gather: a fresh visit, starting with a rest so the
        // stage settles on the standing pose before the next scene.
        _beginVisit();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_lifecycle == state) return;
    _lifecycle = state;

    if (state != AppLifecycleState.resumed) {
      // `inactive`, `paused` and `hidden` all stop it. Only the first of a run
      // of them finds the controller animating, and the flag has to survive
      // the rest — inactive → hidden → paused is one background, not three.
      if (_controller.isAnimating) {
        _heldByLifecycle = true;
        _controller.stop();
      }
      return;
    }

    // Resumed. A gather owns the stage: leave it alone, and let the release
    // start the next visit.
    if (widget.suspended || _reduceMotion) {
      _heldByLifecycle = false;
      return;
    }
    if (_heldByLifecycle) {
      // Carries on from exactly where it stopped, mid-scene or mid-rest —
      // including a rest that never got to start because the app was already
      // in the background when the phase changed.
      _heldByLifecycle = false;
      _controller.forward();
      return;
    }
    // Coming back to the app is what a visit is.
    if (_phase == _Phase.held) _beginVisit();
  }

  /// Whether the idle cadence may run at all — the library doc's rule, in one
  /// expression, asked at every transition rather than cached.
  bool get _cadenceRuns =>
      widget.cadence != null &&
      _lifecycle == AppLifecycleState.resumed &&
      !_reduceMotion &&
      !widget.suspended &&
      !widget.scenes.isEmpty;

  /// True while the app has told us it is not in the foreground. Null — never
  /// told — is not halted: a visit plays on a freshly mounted stage.
  bool get _halted =>
      _lifecycle != null && _lifecycle != AppLifecycleState.resumed;

  void _beginVisit() {
    _played = 0;
    _idleBeats = 0;
    _idling = false;
    _heldByLifecycle = false;
    if (widget.scenes.isEmpty || _reduceMotion) {
      _hold();
      return;
    }
    _startRest(widget.restBetween);
  }

  void _hold() {
    _idling = false;
    _setScene(null, _Phase.held);
  }

  /// Sets the controller to [d] and starts it — unless the app is in the
  /// background, in which case the phase is armed at zero and the resume runs
  /// it. Without this a release from a gather while backgrounded would start a
  /// ticker nobody is watching.
  void _run(Duration d) {
    _controller.duration = d;
    if (_halted) {
      _heldByLifecycle = true;
      _controller.value = 0;
      return;
    }
    _controller.forward(from: 0);
  }

  void _startRest(Duration d) {
    _setScene(null, _Phase.rest);
    _run(d);
  }

  /// Whether a full scene may dwell — the same "in front of the player"
  /// rule the idle cadence runs under, asked fresh at every scene. In the
  /// widget-test harness the lifecycle stays null, so every scene keeps its
  /// short straight-through playback and `pumpAndSettle` settles exactly as
  /// before — the documented test seam, extended, not a second one.
  bool get _dwellRuns =>
      widget.cadence != null &&
      _lifecycle == AppLifecycleState.resumed &&
      !_reduceMotion;

  /// The dwell drawn for the scene now holding.
  Duration _holdDuration = Duration.zero;

  void _startScene({required bool micro}) {
    final AmbientSceneSet pool = micro ? _microPool : _visitPool;
    final String? avoid = _scene?.id ?? _lastId;
    final AmbientScene next = pool.pick(
      _rng.nextDouble(),
      avoidId: avoid,
      alsoAvoidId: identical(avoid, _lastId) || avoid == _lastId
          ? _secondLastId
          : _lastId,
    );
    if (!_idling) _played += 1;
    // A micro-idle never dwells — the cadence's whole promise is that its
    // small beats stay small. A full scene with phasing settles in:
    // intro once, the loop held for the drawn dwell, outro once
    // (GAME_FEEL_CHARACTER_PRESENTATION_01, item 3).
    final ScenePhasing? phasing = micro ? null : next.phasing;
    if (phasing != null && _dwellRuns) {
      final AmbientCadence c = widget.cadence!;
      _sceneHeld = true;
      _holdDuration = phasing.quantizedHold(
        _between(c.sceneHoldShortest, c.sceneHoldLongest),
        next.traveler.fps,
      );
      _partsBefore = Duration.zero;
      if (phasing.hasIntro) {
        _part = _ScenePart.intro;
        _setScene(next, _Phase.scene);
        _run(phasing.introDuration(next.traveler.fps));
      } else {
        _part = _ScenePart.hold;
        _setScene(next, _Phase.scene);
        _run(_holdDuration);
      }
      return;
    }
    _sceneHeld = false;
    _part = _ScenePart.whole;
    _partsBefore = Duration.zero;
    _setScene(next, _Phase.scene);
    _run(next.duration);
  }

  /// The visit is spent: into the cadence, or onto the held rest frame.
  void _beginIdle() {
    if (!_cadenceRuns) {
      _hold();
      return;
    }
    _idling = true;
    _idleBeats = 0;
    _startIdleRest();
  }

  /// Every third idle beat is one of the visit's own scenes rather than a
  /// micro-idle. Read before the beat is counted, so the rest that precedes it
  /// and the pool it draws from cannot disagree.
  bool get _nextBeatIsFullScene =>
      (_idleBeats + 1) % widget.cadence!.fullSceneEvery == 0;

  void _startIdleRest() {
    final AmbientCadence c = widget.cadence!;
    final bool full = _nextBeatIsFullScene;
    _startRest(
      _between(
        full ? c.sceneRestShortest : c.microRestShortest,
        full ? c.sceneRestLongest : c.microRestLongest,
      ),
    );
  }

  /// A length inside the authored bounds, from the same seeded draw the scene
  /// order comes from. Presentation only — nothing reads a clock to get here.
  Duration _between(Duration shortest, Duration longest) {
    final int span = longest.inMicroseconds - shortest.inMicroseconds;
    if (span <= 0) return shortest;
    return Duration(
      microseconds:
          shortest.inMicroseconds + (_rng.nextDouble() * span).round(),
    );
  }

  /// The last two scenes shown, so a rest between scenes does not forget
  /// what preceded it — and so the pick can refuse both, killing the A-B-A
  /// rotation a long session otherwise falls into.
  String? _lastId;
  String? _secondLastId;

  void _setScene(AmbientScene? scene, _Phase phase) {
    if (_scene != null) {
      _secondLastId = _lastId;
      _lastId = _scene!.id;
    }
    if (scene == null) {
      // Rest, hold, or suspension: whatever part a dwelling scene was in,
      // it is over.
      _part = _ScenePart.whole;
      _partsBefore = Duration.zero;
    }
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
        if (_idling) {
          final bool full = _nextBeatIsFullScene;
          _idleBeats += 1;
          _startScene(micro: !full);
          return;
        }
        _startScene(micro: false);
      case _Phase.scene:
        // A dwelling scene advances through its parts before it is over.
        if (_part == _ScenePart.intro) {
          _partsBefore += _controller.duration ?? Duration.zero;
          _part = _ScenePart.hold;
          setState(() => _frames = _framesAt(Duration.zero));
          _run(_holdDuration);
          return;
        }
        if (_part == _ScenePart.hold && _scene!.phasing!.hasOutro) {
          final AmbientScene s = _scene!;
          _partsBefore += _controller.duration ?? Duration.zero;
          _part = _ScenePart.outro;
          setState(() => _frames = _framesAt(Duration.zero));
          _run(s.phasing!.outroDuration(s.traveler.fps));
          return;
        }
        _sceneFinished();
      case _Phase.held:
        break;
    }
  }

  /// The scene is over — outro done, hold with no outro spent, or a legacy
  /// straight-through track complete.
  void _sceneFinished() {
    final bool held = _sceneHeld;
    _sceneHeld = false;
    _part = _ScenePart.whole;
    _partsBefore = Duration.zero;
    if (_idling) {
      _startIdleRest();
      return;
    }
    // The hand-over is decided here rather than after one more visit rest,
    // so the visit's rest and the cadence's first one do not stack into a
    // single very long hold at exactly the moment the stage is meant to
    // start feeling alive.
    final int? limit = widget.scenesPerVisit;
    if (limit != null && _played >= limit) {
      _beginIdle();
      return;
    }
    // After a long dwell the gap is a drawn neutral interval, so the
    // rotation breathes instead of ticking; the harness's short visits
    // keep the fixed rest every settling test depends on.
    final AmbientCadence? c = widget.cadence;
    _startRest(
      held && c != null
          ? _between(c.neutralRestShortest, c.neutralRestLongest)
          : widget.restBetween,
    );
  }

  Duration get _elapsed {
    final Duration d = _controller.duration ?? Duration.zero;
    return d * _controller.value;
  }

  List<int> _framesAt(Duration elapsed) {
    final AmbientScene? s = _scene;
    if (s == null) return const <int>[0];
    if (_part == _ScenePart.whole) {
      return <int>[
        s.traveler.frameAt(elapsed),
        for (final AmbientLayer l in s.layers) l.track.frameAt(elapsed),
      ];
    }
    // A dwelling scene: the Traveler's frame comes from the phasing's part
    // mapping, and every companion layer runs **sustained** on one clock
    // spanning the whole scene — the cat keeps breathing and the fire keeps
    // flickering through the long middle instead of clamping on a last slot
    // a few seconds in.
    final ScenePhasing p = s.phasing!;
    final double fps = s.traveler.fps;
    final int frame = switch (_part) {
      _ScenePart.intro => p.introFrameAt(elapsed, fps),
      _ScenePart.hold => p.holdFrameAt(elapsed, fps),
      _ScenePart.outro => p.outroFrameAt(elapsed, fps),
      _ScenePart.whole => 0, // handled above
    };
    final Duration sceneClock = _partsBefore + elapsed;
    return <int>[
      frame,
      for (final AmbientLayer l in s.layers)
        l.track.frameAtSustained(sceneClock),
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
    // authored in the *64-box's* coordinates — the same box every scene's
    // Traveler stands in — so a cat at `dx: -20` is 20 px left of that box
    // whether the Traveler's frame is 64 or 80 wide.
    final double shift = -(s.anchorX * scale).toDouble();

    Widget layerAt(int i) {
      final AmbientLayer l = s.layers[i];
      return Positioned(
        left: (l.dx * scale).toDouble(),
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
