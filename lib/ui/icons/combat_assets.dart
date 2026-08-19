/// The combat art table: which frames make which track, how each figure stands
/// on the backdrop, and where an impact lands on it.
///
/// ## Where this comes from
///
/// Written from the PixelLab manifest at
/// `GAME_BIBLE/ART/exploration/PLAYABLE_EXPANSION_01/out/combat/manifest.json`
/// (Playable Expansion 01, combat stream) and its README §9 disposition.
/// Frames live at `assets/art/v1/combat/<id>_f{i}.png`, packaged by
/// `Scripts/art/package-art.js`, which also measures every footprint into
/// `SpriteFootprints` — nothing here is measured or guessed by hand. Frame
/// counts, fps, loop modes, canvases and anchor rows are the manifest's own
/// figures, copied.
///
/// ## What is deliberately absent
///
/// - `wolf_hit` and `guardian_defeat` are packaged but **withheld** (§9: three
///   rounds of the wolf flinch never read; the guardian's last defeat frames
///   drifted into a quadruped). Neither is referenced here. The wolf's hit
///   reaction is `fx_impact` at the wolf plus a UI-side recoil offset — a
///   deterministic presentation of a durable fact, not authored art
///   (`RULES.md` A-2) — and the guardian holds its hit pose on victory, as the
///   manifest note suggests.
/// - `fx_slash` was rejected and never packaged: the Traveler's attack frames
///   carry the blade sweep, so a player hit shows `fx_impact` at the enemy.
/// - The guardian's two strikes carry swapped ids on purpose. `guardian_attack`
///   is the overhead slam QA read — the **heavy** (telegraphed) strike — and
///   `guardian_swipe` is the lunge/grab — the **normal** strike. The table below
///   maps by meaning, not by file name.
///
/// ## Geometry, once
///
/// The backdrop is 192 × 96 with the ground on row 88; the stage draws it at
/// ×2. Every figure stands with its anchor row on that ground row, its
/// footprint centre on a fixed backdrop column — the Traveler on column 58
/// (≈30 % of the width), the enemy on column 138 (≈72 %) — so the pair stand
/// in the same place in the scene on every phone; a narrower phone sees less of
/// the backdrop's flanks, never a shifted fight (`PixelScene`'s reasoning).
/// Every track is placed by its **own footprint centre**: canvas left is the
/// standing column minus `footprint.centerX`, so the contact shadow is under
/// the feet on every frame of every track — the `GroundedSprite` rule. For the
/// 80-wide attack that lands 2 px from the ambient scenes' `anchorX`
/// convention (footprint centre 40 against 34 + 8), close enough that the
/// Traveler does not visibly jump when he swings.
///
/// Opaque extents, measured against the packaged art on 2026-08-19 with
/// `Scripts/art/png.js` (`bounds`, union across the sequence):
///
/// ```text
/// traveler_combat_idle 64x64 12,4..56,62   wolf_idle       56x56  7,12..51,40
/// traveler_attack      80x64 22,1..72,62   wolf_attack     56x56  4,12..51,40
/// traveler_hit         64x64 14,2..50,62   wolf_defeat     56x56  5,12..51,41
/// goblin_idle          56x56 17,8..38,46   guardian_idle   96x96 30,11..69,83
/// goblin_attack        56x56  7,9..49,46   guardian_attack 96x96 18,9..63,83
/// goblin_hit           56x56 10,10..46,46  guardian_swipe  96x96 24,13..74,83
/// goblin_defeat        56x56 10,10..45,46  guardian_hit    96x96 28,12..77,83
/// fx_impact            32x32  3,4..27,27   fx_bite         32x32  6,5..25,26
/// ```
///
/// The guardian's opaque top is row 11 with its anchor on 83, so its head
/// stands 72 rows above the ground — 144 dp — and the ground is 176 dp down the
/// 192 dp backdrop: the whole creature fits inside the backdrop with 32 dp to
/// spare. Nothing needs to overflow the stage's top edge.
library;

import 'package:stride_core/stride_core.dart' show ContentId;

import '../components/ambient_scene.dart';
import 'sprite_footprints.dart';

const String _art = 'assets/art/v1/combat';

/// `combat/<id>_f0.png … <id>_f{count-1}.png`.
List<String> _frames(String id, int count) => List<String>.generate(
  count,
  (int i) => '$_art/${id}_f$i.png',
  growable: false,
);

/// One frame sequence a combatant or effect can play, with the geometry the
/// stage needs to stand it on the ground.
final class CombatTrack {
  const CombatTrack({
    required this.id,
    required this.track,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.anchorRow,
    required this.footprint,
  });

  /// The manifest id — `wolf_attack`, `fx_impact`.
  final String id;

  final AmbientTrack track;

  final int canvasWidth;
  final int canvasHeight;

  /// The standing baseline row, sprite-local — the row that sits on the
  /// backdrop's ground row.
  final int anchorRow;

  /// Where the figure meets the ground, for the contact shadow and for the
  /// column it stands on.
  final SpriteFootprint footprint;

  Duration get duration => track.duration;
  int get frameCount => track.frames.length;
  String frame(int i) => track.frames[i];
  int frameAt(Duration elapsed) => track.frameAt(elapsed);
}

/// Everything the stage draws for one figure — the Traveler or one enemy.
final class CombatantArt {
  const CombatantArt({
    required this.idle,
    required this.attack,
    required this.strikeFrame,
    required this.impactRise,
    this.heavy,
    this.heavyStrikeFrame,
    this.hit,
    this.defeat,
  });

  final CombatTrack idle;

  /// The normal strike.
  final CombatTrack attack;

  /// The frame of [attack] on which the blow lands — when the impact effect
  /// and the target's reaction begin.
  final int strikeFrame;

  /// The heavy (telegraphed) strike, for an enemy that has one; `null` plays
  /// [attack] for a heavy blow too.
  final CombatTrack? heavy;
  final int? heavyStrikeFrame;

  /// The flinch. `null` for the wolf (withheld): the stage recoils the figure
  /// instead.
  final CombatTrack? hit;

  /// The defeat. `null` for the guardian (withheld): the stage holds the hit
  /// pose.
  final CombatTrack? defeat;

  /// Rows above the anchor row at which an impact effect on this figure is
  /// centred — its chest, from the measured opaque box.
  final int impactRise;
}

/// A short one-shot effect drawn at a point.
final class EffectArt {
  const EffectArt({
    required this.id,
    required this.track,
    required this.canvas,
  });

  final String id;
  final AmbientTrack track;

  /// Square canvas edge, in sprite pixels — 32 for both effects.
  final int canvas;

  Duration get duration => track.duration;
  int frameAt(Duration elapsed) => track.frameAt(elapsed);
  String frame(int i) => track.frames[i];
}

CombatTrack _track(
  String id,
  int frames,
  double fps,
  AmbientLoop loop, {
  required int canvasWidth,
  required int canvasHeight,
  required int anchorRow,
  required SpriteFootprint footprint,
}) => CombatTrack(
  id: id,
  track: AmbientTrack(frames: _frames(id, frames), fps: fps, loop: loop),
  canvasWidth: canvasWidth,
  canvasHeight: canvasHeight,
  anchorRow: anchorRow,
  footprint: footprint,
);

abstract final class CombatAssets {
  const CombatAssets._();

  // -------------------------------------------------------------- backdrop

  static const int backdropWidth = 192;
  static const int backdropHeight = 96;

  /// The row both figures stand on (manifest `groundRow`).
  static const int backdropGroundRow = 88;

  /// The backdrop column the Traveler's footprint centre stands on.
  static const int travelerColumn = 58;

  /// The backdrop column the enemy's footprint centre stands on.
  static const int enemyColumn = 138;

  static const String backdropForest = '$_art/backdrop_forest.png';
  static const String backdropMine = '$_art/backdrop_mine.png';
  static const String backdropHollow = '$_art/backdrop_hollow.png';

  /// The backdrop for a fight at [location]. Forest is the fallback: a new
  /// location arriving in a content pack must not crash the stage
  /// (`RULES.md` E-5); it fights in the woods until it has its own art.
  static String backdropFor(ContentId location) => switch (location.value) {
    'location.stonefall_mine' => backdropMine,
    'location.forgotten_hollow' => backdropHollow,
    _ => backdropForest,
  };

  // -------------------------------------------------------------- Traveler

  static final CombatantArt traveler = CombatantArt(
    idle: _track(
      'traveler_combat_idle',
      7,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 64,
      canvasHeight: 64,
      anchorRow: 62,
      footprint: SpriteFootprints.combatTravelerCombatIdle,
    ),
    attack: _track(
      'traveler_attack',
      4,
      10,
      AmbientLoop.once,
      canvasWidth: 80,
      canvasHeight: 64,
      anchorRow: 62,
      footprint: SpriteFootprints.combatTravelerAttack,
    ),
    // f2 is the extended blade (manifest note).
    strikeFrame: 2,
    hit: _track(
      'traveler_hit',
      6,
      8,
      AmbientLoop.once,
      canvasWidth: 64,
      canvasHeight: 64,
      anchorRow: 62,
      footprint: SpriteFootprints.combatTravelerHit,
    ),
    // Opaque rows 4..62: the chest is about row 28, 34 above the feet.
    impactRise: 34,
  );

  // --------------------------------------------------------------- enemies

  static final CombatantArt wolf = CombatantArt(
    idle: _track(
      'wolf_idle',
      8,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 40,
      footprint: SpriteFootprints.combatWolfIdle,
    ),
    attack: _track(
      'wolf_attack',
      9,
      10,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 40,
      footprint: SpriteFootprints.combatWolfAttack,
    ),
    // f5 = the bite (manifest note).
    strikeFrame: 5,
    // wolf_hit is withheld: no flinch track, the stage recoils the figure.
    defeat: _track(
      'wolf_defeat',
      7,
      8,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 40,
      footprint: SpriteFootprints.combatWolfDefeat,
    ),
    // Opaque rows 12..40: the body's centre is about row 26.
    impactRise: 14,
  );

  static final CombatantArt goblin = CombatantArt(
    idle: _track(
      'goblin_idle',
      7,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 46,
      footprint: SpriteFootprints.combatGoblinIdle,
    ),
    attack: _track(
      'goblin_attack',
      9,
      10,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 46,
      footprint: SpriteFootprints.combatGoblinAttack,
    ),
    // Overhand strike lands on f4–f5 (manifest note).
    strikeFrame: 4,
    hit: _track(
      'goblin_hit',
      4,
      10,
      // Pingpong so it comes back up (manifest note).
      AmbientLoop.pingpong,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 46,
      footprint: SpriteFootprints.combatGoblinHit,
    ),
    defeat: _track(
      'goblin_defeat',
      7,
      8,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 46,
      footprint: SpriteFootprints.combatGoblinDefeat,
    ),
    // Opaque rows 8..46: the chest is about row 28.
    impactRise: 18,
  );

  static final CombatantArt guardian = CombatantArt(
    idle: _track(
      'guardian_idle',
      7,
      4,
      AmbientLoop.pingpong,
      canvasWidth: 96,
      canvasHeight: 96,
      anchorRow: 83,
      footprint: SpriteFootprints.combatGuardianIdle,
    ),
    // The normal strike is the file called `guardian_swipe` — see the library
    // doc: the two guardian strikes carry swapped ids on purpose.
    attack: _track(
      'guardian_swipe',
      9,
      8,
      AmbientLoop.once,
      canvasWidth: 96,
      canvasHeight: 96,
      anchorRow: 83,
      footprint: SpriteFootprints.combatGuardianSwipe,
    ),
    // The forward hunch with both arms extended is f4–f5.
    strikeFrame: 4,
    // The heavy strike is the file called `guardian_attack`.
    heavy: _track(
      'guardian_attack',
      7,
      6,
      AmbientLoop.once,
      canvasWidth: 96,
      canvasHeight: 96,
      anchorRow: 83,
      footprint: SpriteFootprints.combatGuardianAttack,
    ),
    // Arm brought down and forward on f3 (manifest note).
    heavyStrikeFrame: 3,
    hit: _track(
      'guardian_hit',
      4,
      8,
      AmbientLoop.once,
      canvasWidth: 96,
      canvasHeight: 96,
      anchorRow: 83,
      footprint: SpriteFootprints.combatGuardianHit,
    ),
    // guardian_defeat is withheld: the stage holds the hit pose on victory.
    // Opaque rows 11..83: the trunk's centre is about row 47.
    impactRise: 36,
  );

  /// The art for [enemy], or `null` for an enemy the table does not know —
  /// the stage then draws the Traveler alone against the backdrop, with the
  /// figures still exact, rather than crashing on a content pack's new enemy.
  static CombatantArt? enemyFor(ContentId enemy) => switch (enemy.value) {
    'enemy.forest_wolf' => wolf,
    'enemy.cave_goblin' => goblin,
    'enemy.hollow_guardian' => guardian,
    _ => null,
  };

  // --------------------------------------------------------------- effects

  static final EffectArt fxImpact = EffectArt(
    id: 'fx_impact',
    track: AmbientTrack(
      frames: _frames('fx_impact', 5),
      fps: 12,
      loop: AmbientLoop.once,
    ),
    canvas: 32,
  );

  static final EffectArt fxBite = EffectArt(
    id: 'fx_bite',
    track: AmbientTrack(
      frames: _frames('fx_bite', 5),
      fps: 12,
      loop: AmbientLoop.once,
    ),
    canvas: 32,
  );

  /// The effect drawn on the Traveler when [enemy] lands a blow: the wolf
  /// bites, everything else strikes.
  static EffectArt strikeEffectOf(ContentId enemy) =>
      enemy.value == 'enemy.forest_wolf' ? fxBite : fxImpact;

  /// Every frame the stage may draw for a fight against [enemy] — what it
  /// precaches on mount. The other enemies' tracks are not decoded.
  static List<String> framesFor(ContentId enemy, ContentId location) {
    final CombatantArt? e = enemyFor(enemy);
    return <String>[
      backdropFor(location),
      ...traveler.idle.track.frames,
      ...traveler.attack.track.frames,
      ...?traveler.hit?.track.frames,
      if (e != null) ...<String>[
        ...e.idle.track.frames,
        ...e.attack.track.frames,
        ...?e.heavy?.track.frames,
        ...?e.hit?.track.frames,
        ...?e.defeat?.track.frames,
      ],
      ...fxImpact.track.frames,
      ...fxBite.track.frames,
    ];
  }
}
