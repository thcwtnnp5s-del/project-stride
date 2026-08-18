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
  });

  final AmbientTrack track;

  /// The layer's native frame size (square), in sprite pixels — 32 or 40 for
  /// the cat.
  final int canvas;

  /// Where the layer meets the ground, in its own frame coordinates. Static,
  /// from packaging.
  final SpriteFootprint footprint;

  /// Offset of the layer's top-left from the Traveler frame's top-left, in
  /// **sprite pixels** (scaled with the sprite, so the composition holds at any
  /// integer scale).
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
  }) : canvasHeight = canvasHeight ?? canvas,
       anchorX = anchorX ?? (canvas - 64) ~/ 2,
       assert(weight > 0, 'a scene with no weight can never play');

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

  /// Native frame height. Packaging crops every Traveler scene to 64 rows with
  /// the feet on the same row as the 64 × 64 sprite (row 62), which is what
  /// lets a wider scene share the stage without the figure jumping; the field
  /// exists so a deliberately taller scene is declared rather than guessed.
  final int canvasHeight;

  /// The x, in this scene's frame, that lines up with x = 0 of the standard
  /// 64-wide Traveler box. Defaults to centring a wider frame on the box; the
  /// combined Traveler + cat sprite sets it explicitly. Presentation geometry
  /// only.
  final int anchorX;

  final List<AmbientLayer> layers;

  /// Relative likelihood of being chosen. Presentation flavour only.
  final double weight;

  /// The scene lasts as long as its Traveler track. Layers longer than that are
  /// cut; shorter ones hold their last frame.
  Duration get duration => traveler.duration;
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
