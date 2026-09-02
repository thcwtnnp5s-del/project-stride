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
/// traveler_combat_idle 80x64 25,6..73,62 (Polish 02 re-author)
///                                          wolf_idle       56x56  7,12..51,40
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
    this.stagger,
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

  /// The overwhelmed collapse — the Traveler's defeat-as-retreat: stumble
  /// backward, drop, end on one knee. Only the Traveler carries one; the
  /// enemies have [defeat]. Defeat is retreat, never death (`RULES.md` P-7),
  /// so the last frame is a figure down but alive, held while the enemy
  /// stands its ground.
  final CombatTrack? stagger;

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
  static const String backdropFrostmere = '$_art/backdrop_frostmere.png';

  /// The backdrop for a fight at [location]. Forest is the fallback: a new
  /// location arriving in a content pack must not crash the stage
  /// (`RULES.md` E-5); it fights in the woods until it has its own art.
  static String backdropFor(ContentId location) => switch (location.value) {
    'location.stonefall_mine' => backdropMine,
    'location.forgotten_hollow' => backdropHollow,
    'location.frostmere' => backdropFrostmere,
    _ => backdropForest,
  };

  // -------------------------------------------------------------- Traveler

  static final CombatantArt traveler = CombatantArt(
    // Re-authored east-in-profile with the sword visible (PLAYABLE_POLISH_02):
    // the PE01 idle drifted to three-quarter view and read as facing away
    // from the enemy on the owner's device. 80-wide like the attack — the
    // blade reaches past the 64-box.
    idle: _track(
      'traveler_combat_idle',
      9,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 80,
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
    // f0 standing, f1–f3 stumbling backward, f4 dropping, f5–f8 down on one
    // knee; the stage holds f8. 8 fps so the fall reads — nine frames come to
    // 1125 ms (Activity Feel & Presentation 01 correction, defeat beat).
    stagger: _track(
      'traveler_stagger',
      9,
      8,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 64,
      anchorRow: 62,
      footprint: SpriteFootprints.combatTravelerStagger,
    ),
    // Opaque rows 4..62: the chest is about row 28, 34 above the feet.
    impactRise: 34,
  );

  // ------------------------------------------------- Traveler gear variants

  /// **The Traveler with nothing in his hands** (VAWO01).
  ///
  /// The base set bakes a generic pale-steel sword into every frame, so a
  /// Traveler who has equipped no weapon still fought with one — the interface
  /// contradicting durable state. `TravelerArt.combatantFor` routes an empty
  /// weapon slot here instead.
  ///
  /// No [stagger]. The Traveler's defeat-as-retreat strip is the *base*
  /// figure's, sword and all, so reusing it would put the blade back in his
  /// hands at the one moment the camera holds on him. The choreography's
  /// documented fallback covers it: with no stagger track it holds the flinch,
  /// which is this set's own empty-handed flinch (`LostBeat`).
  ///
  /// Frames are PixelLab v3 on the canonical Traveler; geometry and
  /// preparation in `package-art.js`, VAWO01 combat gear variants.
  static final CombatantArt travelerUnarmed = CombatantArt(
    // Native 80x64 from the character rotation — this one strip is a template
    // animation, and stands on row 63 rather than the v3 crop's 62. Declared
    // per track precisely so the two can differ without the figure shifting.
    idle: _track(
      'traveler_unarmed_idle',
      8,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 80,
      canvasHeight: 64,
      anchorRow: 63,
      footprint: SpriteFootprints.combatTravelerUnarmedIdle,
    ),
    attack: _track(
      'traveler_unarmed_attack',
      7,
      10,
      AmbientLoop.once,
      canvasWidth: 80,
      canvasHeight: 64,
      anchorRow: 62,
      footprint: SpriteFootprints.combatTravelerUnarmedAttack,
    ),
    // Measured, not guessed: the fist's reach per frame is
    // 56 56 68 66 72 60 57 — f4 is the extension, f5–f6 the recovery.
    strikeFrame: 4,
    hit: _track(
      'traveler_unarmed_hit',
      7,
      8,
      AmbientLoop.once,
      canvasWidth: 80,
      canvasHeight: 64,
      anchorRow: 62,
      footprint: SpriteFootprints.combatTravelerUnarmedHit,
    ),
    // Nine frames at 8 fps through to the kneel, held — the base strip's own
    // shape and tempo, re-authored empty-handed. Borrowing the base's would
    // have put the generic sword back in his hands at the one moment the
    // camera lingers on him. Defeat is retreat, never death (`RULES.md` P-7):
    // the last frame is a figure down on one knee and alive.
    stagger: _track(
      'traveler_unarmed_stagger',
      9,
      8,
      AmbientLoop.once,
      canvasWidth: 80,
      canvasHeight: 64,
      anchorRow: 62,
      footprint: SpriteFootprints.combatTravelerUnarmedStagger,
    ),
    // Opaque rows 1..62, the same standing height as the base figure, so the
    // impact still lands on the chest.
    impactRise: 34,
  );

  /// **The Traveler holding the Bronze Sword he actually forged** (VAWO01).
  ///
  /// Covers all three bronze-tier blades. `item.training_sword` deliberately
  /// has no variant: the base set's pale-steel blade *is* a plain training
  /// sword, so the base is already honest for it.
  static final CombatantArt travelerBronze = CombatantArt(
    idle: _track(
      'traveler_bronze_idle',
      9,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 80,
      canvasHeight: 64,
      anchorRow: 62,
      footprint: SpriteFootprints.combatTravelerBronzeIdle,
    ),
    attack: _track(
      'traveler_bronze_attack',
      7,
      10,
      AmbientLoop.once,
      canvasWidth: 80,
      canvasHeight: 64,
      anchorRow: 62,
      footprint: SpriteFootprints.combatTravelerBronzeAttack,
    ),
    // Blade reach per frame is 63 58 56 71 52 70 73: f4 is the cock-back, f5
    // the thrust arriving, f6 the held extension. The blow lands on f5 so the
    // strip has a frame of follow-through after it, rather than firing the
    // impact on the last frame it will ever draw.
    strikeFrame: 5,
    hit: _track(
      'traveler_bronze_hit',
      5,
      8,
      AmbientLoop.once,
      canvasWidth: 80,
      canvasHeight: 64,
      anchorRow: 62,
      footprint: SpriteFootprints.combatTravelerBronzeHit,
    ),
    // The bronze retreat. The first roll came back with the blade turning
    // serrated over its last three frames — the weapon becoming a different
    // object mid-strip, which is the ghost gear this round exists to prevent —
    // so it was rejected and re-rolled with the sword held clear of the
    // ground. All nine frames now carry one clean tapered blade.
    stagger: _track(
      'traveler_bronze_stagger',
      9,
      8,
      AmbientLoop.once,
      canvasWidth: 80,
      canvasHeight: 64,
      anchorRow: 62,
      footprint: SpriteFootprints.combatTravelerBronzeStagger,
    ),
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

  /// The Frost Lynx — Frostmere's first enemy, **re-authored in VAWO01**
  /// (`ENEMY_ROUND_RECORD_01.md`).
  ///
  /// The shipped version followed the wolf's method exactly — same quadruped
  /// template, same camera, same size — and measured 74 % silhouette overlap
  /// with it in place, the only pair in the nine-enemy roster that failed to
  /// read apart at stage scale. Its own accepted QA note described a
  /// "long-tailed quadruped", which is the one thing a lynx is not. The
  /// replacement carries the cues a wolf cannot: black ear tufts, a stump
  /// tail, a cheek ruff, long legs and a spotted tan coat.
  ///
  /// `lynx_hit` stays withheld (it read as a prowl) — the stage recoils the
  /// figure, as it does for the wolf. 56² canvas, anchor row 39 on every
  /// track, unchanged, so nothing downstream of this table moved.
  static final CombatantArt lynx = CombatantArt(
    idle: _track(
      'lynx_idle',
      7,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 39,
      footprint: SpriteFootprints.combatLynxIdle,
    ),
    attack: _track(
      'lynx_attack',
      9,
      10,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 39,
      footprint: SpriteFootprints.combatLynxAttack,
    ),
    // Measured, not inherited: the re-authored strike's leftmost reach per
    // frame is 8 7 7 6 6 6 7 5 5, so f7 is the furthest extension and f8 is
    // the one frame of follow-through after the blow. The strip stalks
    // forward rather than leaping — `animate_image` animates largely in
    // place, and two rolls moved the body 1 px and 3 px against the previous
    // track's ~10. That is recorded as a known limit of the method rather
    // than faked with a per-frame translation the artist never authored.
    strikeFrame: 7,
    defeat: _track(
      'lynx_defeat',
      7,
      8,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 39,
      footprint: SpriteFootprints.combatLynxDefeat,
    ),
    // Opaque rows 13..40: the body's centre is about row 26.
    impactRise: 13,
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

  /// The Whispering Woods boar (Regional Content Pack 01, integrated by
  /// Exploration & Progression Loop 01). Pack blind QA accepted idle, attack
  /// ("goring lunge f3–f6") and defeat ("sinks and lies from f4"); the pack
  /// authored no hit track, so the stage recoils the figure, as for the wolf.
  /// 56² canvas, anchor row 43.
  static final CombatantArt boar = CombatantArt(
    idle: _track(
      'boar_idle',
      7,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 43,
      footprint: SpriteFootprints.combatBoarIdle,
    ),
    attack: _track(
      'boar_attack',
      9,
      10,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 43,
      footprint: SpriteFootprints.combatBoarAttack,
    ),
    // The goring lunge is f3–f6; the tusks connect on f4.
    strikeFrame: 4,
    defeat: _track(
      'boar_defeat',
      7,
      8,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 43,
      footprint: SpriteFootprints.combatBoarDefeat,
    ),
    // Opaque rows 8..43: the body's centre is about row 26.
    impactRise: 17,
  );

  /// The Frostmere mountain ram (Regional Content Pack 01). `ram_hit` is
  /// withheld — the template flinch is a head turn only, the known
  /// quadruped-flinch failure — so the stage recoils the figure. 56² canvas,
  /// anchor row 42.
  static final CombatantArt ram = CombatantArt(
    idle: _track(
      'ram_idle',
      7,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 42,
      footprint: SpriteFootprints.combatRamIdle,
    ),
    attack: _track(
      'ram_attack',
      9,
      10,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 42,
      footprint: SpriteFootprints.combatRamAttack,
    ),
    // The head rears f2–f3, then the horns drive forward f4–f6; the butt
    // lands on f5.
    strikeFrame: 5,
    defeat: _track(
      'ram_defeat',
      7,
      8,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 42,
      footprint: SpriteFootprints.combatRamDefeat,
    ),
    // Opaque rows 9..42: the body's centre is about row 26.
    impactRise: 16,
  );

  /// The Stonefall scree crawler (Regional Content Pack 01, integrated by
  /// Fable V2 Experiment 01 — `DECISIONS/0027`). Pack blind QA accepted idle
  /// and attack ("mandibles gape f3–f6"); `crawler_defeat` stayed withheld
  /// ("legs curl slightly; no collapse read"), so the stage holds the hit
  /// pose on victory exactly as it does for the guardian, and the pack
  /// authored no hit track, so the stage recoils the figure. 48² canvas,
  /// anchor row 40 — a low armoured arthropod.
  static final CombatantArt crawler = CombatantArt(
    idle: _track(
      'crawler_idle',
      7,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 48,
      canvasHeight: 48,
      anchorRow: 40,
      footprint: SpriteFootprints.combatCrawlerIdle,
    ),
    attack: _track(
      'crawler_attack',
      9,
      10,
      AmbientLoop.once,
      canvasWidth: 48,
      canvasHeight: 48,
      anchorRow: 40,
      footprint: SpriteFootprints.combatCrawlerAttack,
    ),
    // The mandibles gape f3–f6; the crushing grip closes on f4.
    strikeFrame: 4,
    // Opaque rows 6..40: the plated back's centre is about row 23.
    impactRise: 17,
  );

  /// The Stonefall deep-gallery salamander (Regional Content Pack 01). The
  /// pack authored no hit track; the stage recoils the figure. 56² canvas,
  /// anchor row 50 — a low-slung creature whose raised head carries the
  /// opaque top.
  static final CombatantArt salamander = CombatantArt(
    idle: _track(
      'salamander_idle',
      7,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 50,
      footprint: SpriteFootprints.combatSalamanderIdle,
    ),
    attack: _track(
      'salamander_attack',
      9,
      10,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 50,
      footprint: SpriteFootprints.combatSalamanderAttack,
    ),
    // The mouth gapes with teeth f3–f6; the bite closes on f4.
    strikeFrame: 4,
    defeat: _track(
      'salamander_defeat',
      7,
      8,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 50,
      footprint: SpriteFootprints.combatSalamanderDefeat,
    ),
    // Opaque rows 5..50: the body's centre is about row 27.
    impactRise: 22,
  );

  /// The Oakback Bear (Regional Content Pack 01, the optional high-danger
  /// mark). The attack is the file called `bear_attack2` — the pack's round-2
  /// rear-up/roar/swipe, its QA_PASS_D ACCEPT; round 1 (`bear_attack`) is
  /// withheld (blind QA read it as a walk). No hit track was authored; the
  /// stage recoils the figure. 76² canvas, anchor row 61.
  static final CombatantArt bear = CombatantArt(
    idle: _track(
      'bear_idle',
      7,
      5,
      AmbientLoop.pingpong,
      canvasWidth: 76,
      canvasHeight: 76,
      anchorRow: 61,
      footprint: SpriteFootprints.combatBearIdle,
    ),
    attack: _track(
      'bear_attack2',
      9,
      8,
      AmbientLoop.once,
      canvasWidth: 76,
      canvasHeight: 76,
      anchorRow: 61,
      footprint: SpriteFootprints.combatBearAttack2,
    ),
    // Rear-up and roar f2–f4, the swipe comes down f5–f6.
    strikeFrame: 5,
    defeat: _track(
      'bear_defeat',
      7,
      6,
      AmbientLoop.once,
      canvasWidth: 76,
      canvasHeight: 76,
      anchorRow: 61,
      footprint: SpriteFootprints.combatBearDefeat,
    ),
    // Opaque rows 12..61: the trunk's centre is about row 36.
    impactRise: 24,
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
    'enemy.frost_lynx' => lynx,
    'enemy.wild_boar' => boar,
    'enemy.mountain_ram' => ram,
    'enemy.salamander' => salamander,
    'enemy.oakback_bear' => bear,
    'enemy.scree_crawler' => crawler,
    // Veteran Hunts (`DECISIONS/0028`): named elites reuse their species'
    // full combat set — zero generations; the hold-hit-pose precedent covers
    // withheld frames.
    'enemy.old_grey' => wolf,
    'enemy.gallery_foreman' => goblin,
    'enemy.rimeclaw_matriarch' => lynx,
    'enemy.guardian_awakened' => guardian,
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

  /// The effect drawn on the Traveler when [enemy] lands a blow: the
  /// creatures whose attack is a mouth — wolf, lynx, salamander — bite,
  /// everything else strikes.
  static EffectArt strikeEffectOf(ContentId enemy) => switch (enemy.value) {
    'enemy.forest_wolf' ||
    'enemy.frost_lynx' ||
    'enemy.salamander' ||
    'enemy.old_grey' ||
    'enemy.rimeclaw_matriarch' => fxBite,
    _ => fxImpact,
  };

  /// Every frame the stage may draw for a fight against [enemy] — what it
  /// precaches on mount. The other enemies' tracks are not decoded.
  ///
  /// [traveler] is the *resolved* gear variant, not the base set. Precaching
  /// the base while the stage draws the bronze strips would decode the blade
  /// on its first painted frame — visible on a phone as gear that flickers in,
  /// which is the defect the variant round exists to avoid. Defaults to the
  /// base so a caller that has no equipment fact still gets sane behaviour.
  static List<String> framesFor(
    ContentId enemy,
    ContentId location, {
    CombatantArt? traveler,
  }) {
    final CombatantArt t = traveler ?? CombatAssets.traveler;
    final CombatantArt? e = enemyFor(enemy);
    return <String>[
      backdropFor(location),
      ...t.idle.track.frames,
      ...t.attack.track.frames,
      ...?t.hit?.track.frames,
      ...?t.stagger?.track.frames,
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
