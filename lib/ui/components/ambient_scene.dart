/// The data model for ambient scenes: what the Traveler does while nothing is
/// happening, described as frames and timing and nothing else.
///
/// ## What an ambient scene is, and is not
///
/// An ambient scene is **presentation**. It is a short, self-contained piece of
/// business — stretching, reading, oiling a tool, dozing, playing with the
/// orange cat — that the activity stage plays while no gather is playing, so the
/// app is pleasant to open when the player is idle
/// (`MILESTONES/FRESH_CHAT_HANDOFF_2026_08_17.md` §16).
///
/// It grants nothing, reads nothing from the domain, and persists nothing. The
/// model below therefore has no field that could carry a game fact: no
/// duration-in-steps, no reward, no state for the cat. The cat is a companion
/// *layer* — frames at an offset — and deliberately not a companion *entity*
/// (§16: "Do not infer a pet gameplay system").
///
/// ## Where the table comes from
///
/// The scene table lives in `lib/ui/icons/ambient_assets.dart` and is written
/// from the PixelLab manifest at
/// `GAME_BIBLE/ART/exploration/TRANSFORMATION_01/out/ambient/manifest.json`.
/// Footprints are static, measured at packaging time by
/// `Scripts/art/package-art.js` — never computed from a decoded image at
/// runtime, for the same reason `SpriteFootprints` is generated: a caller must
/// not be able to disagree with the figure standing on the shadow.
library;

import '../icons/sprite_footprints.dart';

/// How a frame sequence is traversed.
enum AmbientLoop {
  /// `0 1 2 … n-1`, then again, [AmbientScene.repeats] times.
  loop,

  /// `0 1 2 … n-1 … 2 1`, then again, [AmbientScene.repeats] times.
  pingpong,

  /// `0 1 2 … n-1` exactly once, whatever [AmbientScene.repeats] says.
  once,
}

/// A frame sequence with its timing — the unit shared by the Traveler track and
/// its companion layers.
///
/// Every timing question about a track is answered here, so the player can ask
/// "which frame at time t" without knowing which track it is asking about.
final class AmbientTrack {
  const AmbientTrack({
    required this.frames,
    required this.fps,
    this.loop = AmbientLoop.loop,
    this.repeats = 1,
  }) : assert(fps > 0, 'a track must advance'),
       assert(repeats >= 1, 'a track must play at least once');

  /// Asset paths, in order.
  final List<String> frames;

  /// Frames per second. Presentation timing only.
  final double fps;

  final AmbientLoop loop;

  /// How many times the sequence runs before the scene ends. Ignored for
  /// [AmbientLoop.once].
  final int repeats;

  /// Distinct frame slots one pass through the sequence occupies.
  int get _passLength => switch (loop) {
    AmbientLoop.loop || AmbientLoop.once => frames.length,
    // 0..n-1 then n-2..1: 2n-2, or 1 for a single frame.
    AmbientLoop.pingpong => frames.length <= 1 ? 1 : frames.length * 2 - 2,
  };

  /// Total frame slots across every repeat.
  int get slotCount => switch (loop) {
    AmbientLoop.once => frames.length,
    _ => _passLength * repeats,
  };

  /// How long the whole track takes.
  Duration get duration =>
      Duration(microseconds: (slotCount / fps * 1000000).round());

  /// The frame index shown at [elapsed] since the track began. Clamped, so a
  /// track that has finished holds its final slot.
  int frameAt(Duration elapsed) {
    if (frames.isEmpty) return 0;
    final int slot = (elapsed.inMicroseconds / 1000000 * fps).floor().clamp(
      0,
      slotCount - 1,
    );
    final int inPass = slot % _passLength;
    if (loop == AmbientLoop.pingpong && inPass >= frames.length) {
      return _passLength - inPass;
    }
    return inPass;
  }
}

/// An opaque bounding box in sprite-native pixels, inclusive on all four
/// edges — the union across every frame of a sequence, measured by
/// `Scripts/art/measure-ambient-extents.js` and written into the scene table.
///
/// This is what the composition rules reason about: not the frame canvas,
/// which is mostly transparent, and not the footprint, which is only the feet.
/// It is the box a track can ever paint into, so a layout that keeps it inside
/// the stage keeps every frame inside the stage.
final class SpriteBounds {
  const SpriteBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  }) : assert(right >= left && bottom >= top, 'an empty box has no extent');

  /// The whole canvas: the honest default for a track nobody has measured.
  const SpriteBounds.canvas(int width, int height)
    : this(left: 0, top: 0, right: width - 1, bottom: height - 1);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left + 1;
  int get height => bottom - top + 1;

  SpriteBounds shift(int dx, int dy) => SpriteBounds(
    left: left + dx,
    top: top + dy,
    right: right + dx,
    bottom: bottom + dy,
  );

  SpriteBounds union(SpriteBounds o) => SpriteBounds(
    left: left < o.left ? left : o.left,
    top: top < o.top ? top : o.top,
    right: right > o.right ? right : o.right,
    bottom: bottom > o.bottom ? bottom : o.bottom,
  );

  /// Pixels of horizontal overlap with [o], or 0 when the boxes are apart.
  int overlapX(SpriteBounds o) {
    final int l = left > o.left ? left : o.left;
    final int r = right < o.right ? right : o.right;
    return r >= l ? r - l + 1 : 0;
  }

  int overlapY(SpriteBounds o) {
    final int t = top > o.top ? top : o.top;
    final int b = bottom < o.bottom ? bottom : o.bottom;
    return b >= t ? b - t + 1 : 0;
  }

  bool intersects(SpriteBounds o) => overlapX(o) > 0 && overlapY(o) > 0;

  @override
  String toString() => 'SpriteBounds($left,$top..$right,$bottom)';
}

/// A companion drawn with the Traveler — the orange cat, a prop — positioned
/// relative to the Traveler's own frame box.
///
/// It is a *layer*, not a character. It has frames, an offset, and a footprint
/// for its own contact shadow. It has no name, no mood and no state.
final class AmbientLayer {
  const AmbientLayer({
    required this.track,
    required this.canvas,
    required this.footprint,
    this.dx = 0,
    this.dy = 0,
    this.behind = false,
    SpriteBounds? bounds,
  }) : measuredBounds = bounds;

  final AmbientTrack track;

  /// [bounds] as authored, or `null` when the table has not measured it.
  final SpriteBounds? measuredBounds;

  /// The union opaque box of every frame, in the layer's own frame
  /// coordinates. Measured — see [SpriteBounds]. Defaults to the whole canvas.
  SpriteBounds get bounds =>
      measuredBounds ?? SpriteBounds.canvas(canvas, canvas);

  /// [bounds] placed in the scene's standard 64-box coordinates.
  SpriteBounds get placedBounds => bounds.shift(dx, dy);

  /// The layer's native frame size (square), in sprite pixels — 32 or 40 for
  /// the cat.
  final int canvas;

  /// Where the layer meets the ground, in its own frame coordinates. Static,
  /// from packaging.
  final SpriteFootprint footprint;

  /// Offset of the layer's top-left from the top-left of the **standard
  /// 64-box** the Traveler stands in (not the scene's own, possibly wider,
  /// frame), in **sprite pixels** — scaled with the sprite, so the composition
  /// holds at any integer scale.
  final int dx;
  final int dy;

  /// Drawn under the Traveler rather than over — for a cat behind the legs.
  final bool behind;
}

/// One ambient scene: the Traveler track plus any companion layers.
final class AmbientScene {
  const AmbientScene({
    required this.id,
    required this.traveler,
    required this.footprint,
    this.canvas = 64,
    int? canvasHeight,
    int? anchorX,
    this.layers = const <AmbientLayer>[],
    this.weight = 1,
    SpriteBounds? bounds,
    this.companionAllowance = 0,
    this.idleWeight = 0,
    this.idleOnly = false,
  }) : canvasHeight = canvasHeight ?? 64,
       anchorX = anchorX ?? (canvas - 64) ~/ 2,
       measuredBounds = bounds,
       assert(weight > 0, 'a scene with no weight can never play'),
       assert(companionAllowance >= 0, 'an allowance is a size'),
       assert(idleWeight >= 0, 'a weight is not negative'),
       assert(
         !idleOnly || idleWeight > 0,
         'an idle-only scene with no idle weight can never play at all',
       );

  /// A stable identifier — the manifest's scene name.
  final String id;

  final AmbientTrack traveler;

  /// The Traveler's ground contact for this scene, static from packaging. A
  /// seated or lying scene has a different footprint from a standing one, and
  /// this is where that difference is declared rather than guessed.
  final SpriteFootprint footprint;

  /// Native frame width of the Traveler frames. 64 for most scenes; a scene
  /// whose limbs or tools leave the 64 box is delivered wider.
  final int canvas;

  /// Native frame height, **64 unless declared**. Packaging crops every
  /// Traveler scene to 64 rows with the feet on the same row as the 64 × 64
  /// sprite (row 62), which is what lets a wider scene share the stage without
  /// the figure jumping; the field exists so a deliberately taller scene is
  /// declared rather than guessed. It defaulted to the width once, and every
  /// 80- and 96-wide scene was drawn stretched to a square — feet 32 dp below
  /// the floor, the pair sprite's cat off the stage. A wide frame is not a
  /// tall one.
  final int canvasHeight;

  /// The x, in this scene's frame, that lines up with x = 0 of the standard
  /// 64-wide Traveler box. Defaults to centring a wider frame on the box; the
  /// combined Traveler + cat sprite sets it explicitly. Presentation geometry
  /// only.
  final int anchorX;

  final List<AmbientLayer> layers;

  /// Relative likelihood of being chosen. Presentation flavour only.
  final double weight;

  /// [bounds] as authored, or `null` when the table has not measured it.
  final SpriteBounds? measuredBounds;

  /// The union opaque box of every Traveler frame, in **this scene's frame**
  /// coordinates (before [anchorX] is applied). Measured — see [SpriteBounds];
  /// the whole frame when unmeasured.
  SpriteBounds get bounds =>
      measuredBounds ?? SpriteBounds.canvas(canvas, canvasHeight);

  /// How far, in sprite pixels, a companion layer's opaque box may reach into
  /// the Traveler's — the width of the overlap, not its area. Zero for scenes
  /// where they stand apart; a few pixels where a cat is meant to be touched,
  /// or lies by a knee. Authored per scene, and what the composition test
  /// holds each scene to.
  final int companionAllowance;

  /// The Traveler's opaque box in the standard 64-box coordinates every layer
  /// offset is authored in.
  SpriteBounds get travelerBounds => bounds.shift(-anchorX, 0);

  /// The whole composition — Traveler and every layer — in 64-box
  /// coordinates. This is what a stage has to make room for.
  SpriteBounds get groupBounds => layers.fold(
    travelerBounds,
    (SpriteBounds b, AmbientLayer l) => b.union(l.placedBounds),
  );

  /// Relative likelihood of being chosen as a **micro-idle** — the small piece
  /// of business the idle cadence plays between long rests. Zero, the default,
  /// keeps the scene out of that pool entirely.
  ///
  /// Two weights rather than one because the two pools want different things.
  /// A visit wants variety, so the cat scenes carry it; an idle beat wants the
  /// subtlest thing in the table, because it recurs for as long as the player
  /// leaves the screen open. Presentation flavour only, exactly like [weight].
  final double idleWeight;

  /// True for a scene that plays **only** as a micro-idle and never as one of
  /// a visit's scenes — a breath, a look around. Nothing else about it differs;
  /// it is still measured and still held to the composition rules.
  final bool idleOnly;

  /// The scene lasts as long as its Traveler track. Layers longer than that are
  /// cut; shorter ones hold their last frame.
  Duration get duration => traveler.duration;

  /// The same scene at a different [weight] — how a scene authored once for the
  /// visit joins the micro-idle pool at its [idleWeight]. Every measured number
  /// is carried across, so the two pools cannot disagree about the geometry.
  AmbientScene withWeight(double weight) => AmbientScene(
    id: id,
    traveler: traveler,
    footprint: footprint,
    canvas: canvas,
    canvasHeight: canvasHeight,
    anchorX: anchorX,
    layers: layers,
    weight: weight,
    bounds: measuredBounds,
    companionAllowance: companionAllowance,
    idleWeight: idleWeight,
    idleOnly: idleOnly,
  );
}

/// The scenes the stage rotates through.
final class AmbientSceneSet {
  const AmbientSceneSet(this.scenes);

  final List<AmbientScene> scenes;

  bool get isEmpty => scenes.isEmpty;

  /// Weighted choice, never the same scene twice in a row when there is more
  /// than one to choose from. `roll` is a uniform draw in `[0, 1)`.
  AmbientScene pick(double roll, {String? avoidId}) {
    assert(scenes.isNotEmpty, 'nothing to pick from');
    final List<AmbientScene> pool = scenes.length > 1
        ? scenes.where((AmbientScene s) => s.id != avoidId).toList()
        : scenes;
    final double total = pool.fold(
      0,
      (double a, AmbientScene s) => a + s.weight,
    );
    double cursor = roll.clamp(0.0, 0.999999) * total;
    for (final AmbientScene s in pool) {
      cursor -= s.weight;
      if (cursor < 0) return s;
    }
    return pool.last;
  }

  /// The scenes a *visit* draws from: everything not marked
  /// [AmbientScene.idleOnly].
  AmbientSceneSet get visitScenes => AmbientSceneSet(<AmbientScene>[
    for (final AmbientScene s in scenes)
      if (!s.idleOnly) s,
  ]);

  /// The micro-idle pool: every scene with an [AmbientScene.idleWeight], taken
  /// at that weight. Empty when the table declares none — the player then falls
  /// back to the full set rather than inventing a pool.
  AmbientSceneSet get microIdles => AmbientSceneSet(<AmbientScene>[
    for (final AmbientScene s in scenes)
      if (s.idleWeight > 0) s.withWeight(s.idleWeight),
  ]);

  /// Every asset path any scene touches, for precaching.
  Iterable<String> get allFrames sync* {
    for (final AmbientScene s in scenes) {
      yield* s.traveler.frames;
      for (final AmbientLayer l in s.layers) {
        yield* l.track.frames;
      }
    }
  }
}

/// How the stage behaves *after* a visit's scenes are spent: the idle cadence.
///
/// A visit — a few authored scenes with short rests — answers "is this pleasant
/// to open". It does not answer "is this pleasant to leave open", and the
/// owner's device review found the difference: the figure did its four things
/// and then stood still for as long as the screen was up, which reads as a
/// frozen app rather than a resting Traveler.
///
/// The cadence is the answer, and it is deliberately slow. Each idle beat is a
/// hold on the rest frame, of a length drawn from the bounds below, then one
/// short piece of business — usually a **micro-idle**
/// ([AmbientScene.idleWeight]), and every [fullSceneEvery]-th beat one of the
/// visit's full scenes. More than half of an idle cycle is the rest frame,
/// because a figure that never stops moving starts to imply that something is
/// happening, and nothing is (`FRESH_CHAT_HANDOFF §16`: ambient life "must not
/// pretend gameplay is happening").
///
/// Every number here is a presentation length fed to an `AnimationController`.
/// None of it is read from a clock, none of it is persisted, and none of it can
/// grant anything (`RULES.md` P-4, S-01A).
final class AmbientCadence {
  const AmbientCadence({
    this.microRestShortest = const Duration(seconds: 2),
    this.microRestLongest = const Duration(seconds: 4),
    this.sceneRestShortest = const Duration(seconds: 4),
    this.sceneRestLongest = const Duration(seconds: 8),
    this.fullSceneEvery = 3,
  }) : assert(fullSceneEvery > 0, 'a full scene has to come round eventually');

  /// The bounds on the hold before a micro-idle. Varied inside them from the
  /// player's own seeded draw, so two beats in a row are not the same length.
  final Duration microRestShortest;
  final Duration microRestLongest;

  /// The bounds on the longer hold before a full scene.
  final Duration sceneRestShortest;
  final Duration sceneRestLongest;

  /// Every n-th idle beat is a full scene rather than a micro-idle.
  final int fullSceneEvery;

  /// What the app runs. Named so a reader of the player sees a decision rather
  /// than four literals.
  static const AmbientCadence standard = AmbientCadence();
}
