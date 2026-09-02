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
/// The backdrop is 192 × 128 with the ground on row 120; the stage draws it
/// at ×2. It was 192 × 96 with the ground on row 88 until FMPO02 wave 2
/// re-authored the four biome canvases 32 rows taller
/// (`ART-09_combat_brief.md` §2, `COMBAT_STAGE_report.md`): the width and both
/// standing columns are unchanged and the ground keeps its 8-row offset from
/// the canvas bottom, so **only the sky grew** and no figure moved relative to
/// the scene. Every figure stands with its anchor row on that ground row, its
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
/// stands 72 rows above the ground — 144 dp — and the ground is 240 dp down
/// the 256 dp backdrop: the whole creature fits inside the backdrop with 96 dp
/// of sky above its crown, against 32 dp on the old canvas. Nothing needs to
/// overflow the stage's top edge, and the tallest figure in the game no longer
/// crowds the two corner chips.
library;

import 'package:stride_core/stride_core.dart' show ContentId;

import '../components/ambient_scene.dart';
import '../components/panel_skin.dart';
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
    this.brace,
  });

  final CombatTrack idle;

  /// The planted guard a Brace holds (FMPO02). `null` plays a held idle, as
  /// every Traveler set did before a stance pose was authored; only the
  /// Traveler carries one.
  final CombatTrack? brace;

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

  /// 128 since FMPO02 wave 2. The `_128` files are the same four scenes with
  /// 32 rows of sky, canopy or ceiling added above the old row 32; the 96-tall
  /// originals stay packaged, and pointing the four constants below back at
  /// them is the whole of a rollback.
  static const int backdropHeight = 128;

  /// The row both figures stand on (manifest `groundRow`) — 8 rows up from the
  /// canvas bottom, as it was at 96 (row 88) and is at 128.
  static const int backdropGroundRow = 120;

  /// The backdrop column the Traveler's footprint centre stands on.
  static const int travelerColumn = 58;

  /// The backdrop column the enemy's footprint centre stands on.
  static const int enemyColumn = 138;

  static const String backdropForest = '$_art/backdrop_forest_128.png';
  static const String backdropMine = '$_art/backdrop_mine_128.png';
  static const String backdropHollow = '$_art/backdrop_hollow_128.png';
  static const String backdropFrostmere = '$_art/backdrop_frostmere_128.png';

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
    // The base body's guard, authored in EPO03 (DIR-08 failure 4).
    //
    // FMPO02 gave a brace to the two VAWO01 base sets and to all nine armoured
    // loadouts, and missed this one — the *shipped* base set, which is what a
    // Traveler holding the Training Sword fights with. So the one loadout every
    // new player starts in was the only one where pressing Brace produced no
    // braced figure at all. The strip is `traveler_base_bronze_brace` with the
    // blade re-drawn as the pale steel training blade by a single six-frame
    // edit, so it is this figure's own guard rather than a borrowed one
    // (`Scripts/art/package-art.js`, EPO03 EQUIPMENT).
    brace: _baseBrace('steel', SpriteFootprints.combatTravelerBaseSteelBrace),
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
    brace: _baseBrace('unarmed', SpriteFootprints.combatTravelerBaseUnarmedBrace),
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
    brace: _baseBrace('bronze', SpriteFootprints.combatTravelerBaseBronzeBrace),
    impactRise: 34,
  );

  // ------------------------------------------ FMPO02 armoured loadouts

  /// One armoured loadout: a body class holding a weapon class, four tracks,
  /// east-facing, 80 × 64 with the feet on row 62 — the same geometry as the
  /// VAWO01 sets, from the same canonical Traveler. Frame counts are what
  /// PixelLab v3 returned for every set (8 / 8 / 6 / 8); the strike frame is
  /// measured per set from the blade's reach and is the one figure that
  /// differs between loadouts.
  static CombatantArt _loadout(
    String body,
    String held, {
    required int strikeFrame,
    required SpriteFootprint idle,
    required SpriteFootprint attack,
    required SpriteFootprint hit,
    required SpriteFootprint stagger,
    required SpriteFootprint brace,
    int canvasWidth = 80,
  }) {
    CombatTrack t(String track, int frames, double fps, AmbientLoop loop,
            SpriteFootprint footprint) =>
        _track(
          'traveler_${body}_${held}_$track',
          frames,
          fps,
          loop,
          canvasWidth: canvasWidth,
          canvasHeight: 64,
          anchorRow: 62,
          footprint: footprint,
        );
    return CombatantArt(
      idle: t('idle', 8, 6, AmbientLoop.pingpong, idle),
      attack: t('attack', 8, 10, AmbientLoop.once, attack),
      strikeFrame: strikeFrame,
      hit: t('hit', 6, 8, AmbientLoop.once, hit),
      stagger: t('stagger', 8, 8, AmbientLoop.once, stagger),
      // Six frames into the guard, held on the last.
      brace: t('brace', 6, 10, AmbientLoop.once, brace),
      impactRise: 34,
    );
  }

  /// The brace track for a VAWO01 base-body set, authored in FMPO02.
  static CombatTrack _baseBrace(String held, SpriteFootprint footprint) =>
      _track(
        'traveler_base_${held}_brace',
        6,
        10,
        AmbientLoop.once,
        canvasWidth: 80,
        canvasHeight: 64,
        anchorRow: 62,
        footprint: footprint,
      );

  /// `'<bodyClass>|<weaponClass>'` → the loadout. Strike frames from
  /// `FMPO02/tools/measure-reach.js` over the packaged strips: the blade's
  /// reach per frame, the blow on its furthest extension (or the first of
  /// two equal peaks, so the strip keeps follow-through where it has any).
  static final Map<String, CombatantArt> armouredLoadouts =
      <String, CombatantArt>{
        'armor.plate|weapon.bronze': _loadout(
          'plate',
          'bronze',
          strikeFrame: 6,
          idle: SpriteFootprints.combatTravelerPlateBronzeIdle,
          attack: SpriteFootprints.combatTravelerPlateBronzeAttack,
          hit: SpriteFootprints.combatTravelerPlateBronzeHit,
          stagger: SpriteFootprints.combatTravelerPlateBronzeStagger,
          brace: SpriteFootprints.combatTravelerPlateBronzeBrace,
        ),
        'armor.plate|weapon.steel': _loadout(
          'plate',
          'steel',
          strikeFrame: 7,
          idle: SpriteFootprints.combatTravelerPlateSteelIdle,
          attack: SpriteFootprints.combatTravelerPlateSteelAttack,
          hit: SpriteFootprints.combatTravelerPlateSteelHit,
          stagger: SpriteFootprints.combatTravelerPlateSteelStagger,
          brace: SpriteFootprints.combatTravelerPlateSteelBrace,
        ),
        'armor.plate|weapon.unarmed': _loadout(
          'plate',
          'unarmed',
          strikeFrame: 7,
          idle: SpriteFootprints.combatTravelerPlateUnarmedIdle,
          attack: SpriteFootprints.combatTravelerPlateUnarmedAttack,
          hit: SpriteFootprints.combatTravelerPlateUnarmedHit,
          stagger: SpriteFootprints.combatTravelerPlateUnarmedStagger,
          brace: SpriteFootprints.combatTravelerPlateUnarmedBrace,
        ),
        'armor.jerkin|weapon.bronze': _loadout(
          'jerkin',
          'bronze',
          strikeFrame: 2,
          idle: SpriteFootprints.combatTravelerJerkinBronzeIdle,
          attack: SpriteFootprints.combatTravelerJerkinBronzeAttack,
          hit: SpriteFootprints.combatTravelerJerkinBronzeHit,
          stagger: SpriteFootprints.combatTravelerJerkinBronzeStagger,
          brace: SpriteFootprints.combatTravelerJerkinBronzeBrace,
        ),
        'armor.jerkin|weapon.steel': _loadout(
          'jerkin',
          'steel',
          strikeFrame: 7,
          idle: SpriteFootprints.combatTravelerJerkinSteelIdle,
          attack: SpriteFootprints.combatTravelerJerkinSteelAttack,
          hit: SpriteFootprints.combatTravelerJerkinSteelHit,
          stagger: SpriteFootprints.combatTravelerJerkinSteelStagger,
          brace: SpriteFootprints.combatTravelerJerkinSteelBrace,
        ),
        'armor.jerkin|weapon.unarmed': _loadout(
          'jerkin',
          'unarmed',
          strikeFrame: 3,
          idle: SpriteFootprints.combatTravelerJerkinUnarmedIdle,
          attack: SpriteFootprints.combatTravelerJerkinUnarmedAttack,
          hit: SpriteFootprints.combatTravelerJerkinUnarmedHit,
          stagger: SpriteFootprints.combatTravelerJerkinUnarmedStagger,
          brace: SpriteFootprints.combatTravelerJerkinUnarmedBrace,
        ),
        'armor.coat|weapon.bronze': _loadout(
          'coat',
          'bronze',
          strikeFrame: 7,
          idle: SpriteFootprints.combatTravelerCoatBronzeIdle,
          attack: SpriteFootprints.combatTravelerCoatBronzeAttack,
          hit: SpriteFootprints.combatTravelerCoatBronzeHit,
          stagger: SpriteFootprints.combatTravelerCoatBronzeStagger,
          brace: SpriteFootprints.combatTravelerCoatBronzeBrace,
        ),
        'armor.coat|weapon.steel': _loadout(
          'coat',
          'steel',
          strikeFrame: 2,
          idle: SpriteFootprints.combatTravelerCoatSteelIdle,
          attack: SpriteFootprints.combatTravelerCoatSteelAttack,
          hit: SpriteFootprints.combatTravelerCoatSteelHit,
          stagger: SpriteFootprints.combatTravelerCoatSteelStagger,
          brace: SpriteFootprints.combatTravelerCoatSteelBrace,
        ),
        'armor.coat|weapon.unarmed': _loadout(
          'coat',
          'unarmed',
          strikeFrame: 2,
          idle: SpriteFootprints.combatTravelerCoatUnarmedIdle,
          attack: SpriteFootprints.combatTravelerCoatUnarmedAttack,
          hit: SpriteFootprints.combatTravelerCoatUnarmedHit,
          stagger: SpriteFootprints.combatTravelerCoatUnarmedStagger,
          brace: SpriteFootprints.combatTravelerCoatUnarmedBrace,
        ),
      };

  /// **The Bronze Longsword is a different weapon to look at** (EPO03,
  /// DIR-08 failure 1).
  ///
  /// The epic Bronze Longsword and the uncommon Bronze Sword resolved to one
  /// set, so the blade at the end of a long crafting chain was pixel-identical
  /// to the blade that went into it. This is the fifth held class: a blade
  /// half again as long, with a straight cross-guard and a two-hand grip,
  /// whose tip passes the front foot in the idle. It is a *silhouette*
  /// difference, which is what survives at sprite scale — a recolour would not
  /// have been worth authoring.
  ///
  /// Four bodies, five tracks each, all twenty east-facing on row 62 and made
  /// the way `package-art.js`'s EPO03 EQUIPMENT block records: a one-generation
  /// `edit_image_pixen` on each body's own shipped bronze idle frame, then one
  /// v3 animation per track from that frame.
  ///
  /// **The base body's tracks are 104 wide, not 80.** Its blade came back the
  /// longest of the four and its attack measures 98 px across, so the declared
  /// width grows and is recorded rather than the frames being re-cropped
  /// (ART-05 §3). All five of its tracks share the wider canvas so the figure
  /// cannot shift between them; the anchor row is 62 as everywhere else.
  ///
  /// Strike frames are the measured furthest extension of the blade across
  /// the attack strip, as the armoured loadouts' are.
  static final Map<String, CombatantArt> longswordLoadouts =
      <String, CombatantArt>{
        'armor.plate|weapon.longsword': _loadout(
          'plate',
          'longsword',
          strikeFrame: 7,
          idle: SpriteFootprints.combatTravelerPlateLongswordIdle,
          attack: SpriteFootprints.combatTravelerPlateLongswordAttack,
          hit: SpriteFootprints.combatTravelerPlateLongswordHit,
          stagger: SpriteFootprints.combatTravelerPlateLongswordStagger,
          brace: SpriteFootprints.combatTravelerPlateLongswordBrace,
        ),
        'armor.jerkin|weapon.longsword': _loadout(
          'jerkin',
          'longsword',
          strikeFrame: 7,
          idle: SpriteFootprints.combatTravelerJerkinLongswordIdle,
          attack: SpriteFootprints.combatTravelerJerkinLongswordAttack,
          hit: SpriteFootprints.combatTravelerJerkinLongswordHit,
          stagger: SpriteFootprints.combatTravelerJerkinLongswordStagger,
          brace: SpriteFootprints.combatTravelerJerkinLongswordBrace,
        ),
        'armor.coat|weapon.longsword': _loadout(
          'coat',
          'longsword',
          // The coat's arc shoulders the blade and drives it forward rather
          // than chopping from overhead, so its furthest reach is early.
          strikeFrame: 2,
          idle: SpriteFootprints.combatTravelerCoatLongswordIdle,
          attack: SpriteFootprints.combatTravelerCoatLongswordAttack,
          hit: SpriteFootprints.combatTravelerCoatLongswordHit,
          stagger: SpriteFootprints.combatTravelerCoatLongswordStagger,
          brace: SpriteFootprints.combatTravelerCoatLongswordBrace,
        ),
        'base|weapon.longsword': _loadout(
          'base',
          'longsword',
          strikeFrame: 7,
          canvasWidth: 104,
          idle: SpriteFootprints.combatTravelerBaseLongswordIdle,
          attack: SpriteFootprints.combatTravelerBaseLongswordAttack,
          hit: SpriteFootprints.combatTravelerBaseLongswordHit,
          stagger: SpriteFootprints.combatTravelerBaseLongswordStagger,
          brace: SpriteFootprints.combatTravelerBaseLongswordBrace,
        ),
      };

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
  /// ("goring lunge f3–f6") and defeat ("sinks and lies from f4"). The pack
  /// authored no hit track and the stage recoiled the figure instead until
  /// FMPO02 wave 2 (`ENEMIES_report.md` §2) authored one at the family's own
  /// canvas and anchor row, so nothing here moved. 56² canvas, anchor row 43.
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
    hit: _track(
      'boar_hit',
      6,
      8,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 43,
      footprint: SpriteFootprints.combatBoarHit,
    ),
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
  /// and attack ("mandibles gape f3–f6"). `crawler_defeat` stayed withheld
  /// ("legs curl slightly; no collapse read") and the pack authored no hit
  /// track, so the stage held the hit pose on victory and recoiled the figure
  /// on a blow. FMPO02 wave 2 (`ENEMIES_report.md` §2) authored both, at the
  /// same canvas and anchor row. 48² canvas, anchor row 40 — a low armoured
  /// arthropod.
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
    hit: _track(
      'crawler_hit',
      6,
      8,
      AmbientLoop.once,
      canvasWidth: 48,
      canvasHeight: 48,
      anchorRow: 40,
      footprint: SpriteFootprints.combatCrawlerHit,
    ),
    // The defeat the pack withheld, re-authored in FMPO02 wave 2. Its own
    // report is candid that the collapse is weak — the legs splay and the
    // body settles, but the height drops only ~9 % across eight frames, and
    // two rolls looked the same. It is shipped rather than faked, and it is
    // still a clearer victory read than holding the hit pose.
    defeat: _track(
      'crawler_defeat',
      8,
      8,
      AmbientLoop.once,
      canvasWidth: 48,
      canvasHeight: 48,
      anchorRow: 40,
      footprint: SpriteFootprints.combatCrawlerDefeat,
    ),
    // Opaque rows 6..40: the plated back's centre is about row 23.
    impactRise: 17,
  );

  /// The Stonefall deep-gallery salamander (Regional Content Pack 01). The
  /// pack authored no hit track and the stage recoiled the figure until
  /// FMPO02 wave 2 authored one (`ENEMIES_report.md` §2). 56² canvas,
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
    hit: _track(
      'salamander_hit',
      6,
      8,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 50,
      footprint: SpriteFootprints.combatSalamanderHit,
    ),
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
  /// withheld (blind QA read it as a walk). The pack authored no hit track and
  /// the stage recoiled the figure until FMPO02 wave 2 authored one
  /// (`ENEMIES_report.md` §2). 76² canvas, anchor row 61.
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
    hit: _track(
      'bear_hit',
      6,
      8,
      AmbientLoop.once,
      canvasWidth: 76,
      canvasHeight: 76,
      anchorRow: 61,
      footprint: SpriteFootprints.combatBearHit,
    ),
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

  // ---------------------------------------------------------------- elites

  // THE FOUR VETERAN HUNTS GET THEIR OWN SPRITES.
  //
  // `DECISIONS/0028` shipped the named elites pointing at their base species'
  // files, which made a Veteran Hunt the same animal under a different label.
  // FMPO02 wave 2 (`ENEMIES_report.md` §3) authored an **idle and an attack**
  // for each — grey muzzle and scar on the wolf, iron helmet and bulk on the
  // goblin, a dark frosted coat and white chest on the lynx, glowing rune
  // cracks and lighter stone on the guardian. All four passed a blind
  // side-by-side at card size: same species, something is different.
  //
  // **The other tracks are borrowed from the base family on purpose.** The
  // round authored two tracks per elite, not five, so the flinch, the defeat
  // and the guardian's heavy strike below are the base species' own
  // `CombatTrack` objects, reused by reference. That is visible to a player
  // only at the moment a blow lands or the fight ends, and the alternative —
  // withholding them — would cost the elites the flinch and the defeat their
  // own species already has. When a later round authors elite tracks, the
  // borrowed lines are what it replaces.
  //
  // Canvases, anchor rows and strike frames are the report's measurements.
  // Each elite carries its own footprint, measured from its own frame 0, so
  // the matriarch sitting one row lower than the lynx (40 against 39, the
  // edit made the cat huskier) needs no correction.

  /// Old Grey — the veteran wolf. Hit is `null` as it is for the wolf, whose
  /// own flinch stayed withheld; the stage recoils the figure.
  static final CombatantArt oldGrey = CombatantArt(
    idle: _track(
      'old_grey_idle',
      8,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 40,
      footprint: SpriteFootprints.combatOldGreyIdle,
    ),
    attack: _track(
      'old_grey_attack',
      8,
      10,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 40,
      footprint: SpriteFootprints.combatOldGreyAttack,
    ),
    // Leftmost reach, one frame before retraction (report §3).
    strikeFrame: 3,
    // Borrowed from the wolf.
    defeat: wolf.defeat,
    impactRise: 14,
  );

  /// The Gallery Foreman — the veteran cave goblin. Hit and defeat borrowed.
  static final CombatantArt galleryForeman = CombatantArt(
    idle: _track(
      'gallery_foreman_idle',
      8,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 46,
      footprint: SpriteFootprints.combatGalleryForemanIdle,
    ),
    attack: _track(
      'gallery_foreman_attack',
      8,
      10,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 46,
      footprint: SpriteFootprints.combatGalleryForemanAttack,
    ),
    strikeFrame: 5,
    // Borrowed from the goblin.
    hit: goblin.hit,
    defeat: goblin.defeat,
    impactRise: 18,
  );

  /// The Rimeclaw Matriarch — the veteran frost lynx. Hit is `null` as it is
  /// for the lynx, whose flinch stayed withheld; defeat borrowed.
  static final CombatantArt rimeclawMatriarch = CombatantArt(
    idle: _track(
      'rimeclaw_matriarch_idle',
      8,
      6,
      AmbientLoop.pingpong,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 40,
      footprint: SpriteFootprints.combatRimeclawMatriarchIdle,
    ),
    attack: _track(
      'rimeclaw_matriarch_attack',
      8,
      10,
      AmbientLoop.once,
      canvasWidth: 56,
      canvasHeight: 56,
      anchorRow: 40,
      footprint: SpriteFootprints.combatRimeclawMatriarchAttack,
    ),
    strikeFrame: 5,
    // Borrowed from the lynx.
    defeat: lynx.defeat,
    impactRise: 13,
  );

  /// The Awakened Guardian. Heavy and hit borrowed from the guardian, whose
  /// defeat is withheld, so this one holds the hit pose on victory too.
  static final CombatantArt guardianAwakened = CombatantArt(
    idle: _track(
      'guardian_awakened_idle',
      8,
      4,
      AmbientLoop.pingpong,
      canvasWidth: 96,
      canvasHeight: 96,
      anchorRow: 83,
      footprint: SpriteFootprints.combatGuardianAwakenedIdle,
    ),
    attack: _track(
      'guardian_awakened_attack',
      8,
      8,
      AmbientLoop.once,
      canvasWidth: 96,
      canvasHeight: 96,
      anchorRow: 83,
      footprint: SpriteFootprints.combatGuardianAwakenedAttack,
    ),
    // The heavy-swing extension (report §3).
    strikeFrame: 5,
    // Borrowed from the guardian, ids and all: `guardian_attack` is the
    // telegraphed heavy, per this library's own doc note about the swapped
    // guardian ids.
    heavy: guardian.heavy,
    heavyStrikeFrame: guardian.heavyStrikeFrame,
    hit: guardian.hit,
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
    // Veteran Hunts (`DECISIONS/0028`). These four used to resolve to their
    // base species, so a named elite was that species relabelled. FMPO02
    // wave 2 gave each its own idle and attack; the rest of each set is still
    // the base family's, borrowed by reference in the four entries above.
    'enemy.old_grey' => oldGrey,
    'enemy.gallery_foreman' => galleryForeman,
    'enemy.rimeclaw_matriarch' => rimeclawMatriarch,
    'enemy.guardian_awakened' => guardianAwakened,
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

/// The combat interface's own authored pieces (FMPO02 wave 2).
///
/// Sprites are above; these are the HUD and command-cluster rasters that
/// PROD-COMBAT-STAGE produced alongside them, with the geometry taken from the
/// `.json` sidecar beside each PNG rather than from the brief that
/// commissioned it (`panel_skin.dart` — a frame whose declared geometry
/// disagrees with its pixels renders wrong in a way that looks like a layout
/// bug).
///
/// ## What the delivered art actually is, which is not what the brief assumed
///
/// `ART-09_combat_brief.md` §5 asked for three **plates**: rounded rectangles
/// a nine-patch could stretch to a command cell. The sidecars duly record
/// `corner 10 / band 12` for all three, and hedge it — "a nine-slice
/// approximation … at the shipped 64 × 32 size no slicing is required".
///
/// Measured against the pixels, they are not nine-patches at all. Every one of
/// the three is a **centred blob on a transparent 64 × 32 field**: Brace is a
/// diamond spanning columns 9–53 and rows 3–28, Eat an oval, Attack a rough
/// medallion — the four 10 × 10 corner blocks a nine-patch would sample are
/// fully transparent in all three files, and so are the edge strips between
/// them. Rendered through `PixelFrame` they would tile the blob's own arc
/// across the cell and draw nothing in the middle.
///
/// So they are integrated as what they are: **ornaments Flutter positions**,
/// the third of the three things `DECISIONS/0029` allows a raster to be, drawn
/// at ×2 with no stretch and no resample. Their opaque content is 48–56 dp
/// tall at ×2 and fits a 56 dp command cell; only transparent rows are
/// clipped. The declared `corner 10 / band 12` is also **unrepresentable** as
/// a [PanelSkin] — `band > corner` trips the assert that says the band is the
/// material inside the corner block — which is a second, independent signal
/// from the same measurement, and is not a rule to relax.
///
/// `hp_gauge_frame` is the one genuine nine-patch of the set and is used as
/// one. `turn_marker`'s own sidecar already says `"type": "fixed"`.
abstract final class CombatHudAssets {
  const CombatHudAssets._();

  static const String _ui = 'assets/ui/v1/combat';

  // ------------------------------------------------------------- HP gauge

  /// The gauge chassis: a horizontal nine-patch, `corner 6 / band 3` exactly
  /// as `hp_gauge_frame.json` measures it, drawn at ×2 — so at its native
  /// 32 dp height the whole 16-row canvas reproduces pixel-for-pixel and only
  /// the horizontal band tiles.
  static const PanelSkin gaugeFrame = PanelSkin(
    assetPath: '$_ui/hp_gauge_frame.png',
    nativeWidth: 96,
    nativeHeight: 16,
    corner: 6,
    band: 3,
    scale: 2,
  );

  /// The gauge's drawn height in logical pixels — its native 16 rows at ×2.
  static const double gaugeHeight = 32;

  /// Where the Flutter-painted fill lives inside the frame, in logical pixels
  /// from the gauge's top-left. **These are the sidecar's figures, doubled**:
  /// the visible pill occupies rows 4–11 of the 16-row canvas and its flat
  /// section is rows 5–10, so the fill is inset to those rows and to columns
  /// 7–88, "not the full 16 px height or full 96 px width"
  /// (`hp_gauge_frame.json`, integration note).
  ///
  /// The fill is a rectangle Flutter paints and the frame is drawn **over**
  /// it, so the pill's own tapered top and bottom rows always sit on the fill
  /// rather than the fill spilling past them. `DECISIONS/0029`: the raster
  /// carries the material, never the state.
  static const double gaugeFillTop = 10;
  static const double gaugeFillHeight = 12;
  static const double gaugeFillInset = 14;

  // ----------------------------------------------------------- turn marker

  /// The leather tab beside the TURN chip. Fixed, never stretched
  /// (`turn_marker.json`).
  static const String turnMarker = '$_ui/turn_marker.png';
  static const int turnMarkerNative = 24;

  // --------------------------------------------------------------- plates

  /// The command ornaments. 64 × 32 native, drawn at ×2 behind the label.
  static const String plateAttack = '$_ui/plate_attack.png';
  static const String plateBrace = '$_ui/plate_brace.png';
  static const String plateEat = '$_ui/plate_eat.png';

  static const int plateNativeWidth = 64;
  static const int plateNativeHeight = 32;

  /// The 16 × 16 glyphs, drawn at ×2 to the left of the label. Retreat has
  /// none on purpose: four candidates never produced a readable footprint and
  /// `ART-09` §5 had already specified it as a plain text link
  /// (`COMBAT_STAGE_report.md`).
  static const String iconAttack = '$_ui/icon_attack.png';
  static const String iconBrace = '$_ui/icon_brace.png';
  static const String iconEat = '$_ui/icon_eat.png';

  static const int iconNative = 16;

  // ------------------------------------------------------ narration strip

  /// **Authored, packaged, and deliberately not drawn** — see
  /// `combat_screen.dart`'s `_CombatLog` and `test/combat_ui_test.dart`'s
  /// contrast guard.
  ///
  /// The strip is parchment. Composited over the stage, its drawn body (rows
  /// 4–10) has a mean relative luminance of 0.246, which is 2.90 : 1 against
  /// `textPrimary` — and its four brightest rows, the ones a line of type
  /// actually sits on, are 1.85 : 1. The narration keeps the translucent fill
  /// it shipped with until a darker strip is authored; the guard test holds
  /// the figure so the swap is a measurement away rather than a redesign.
  static const String narrationStrip = '$_ui/narration_strip.png';
  static const int narrationStripWidth = 64;
  static const int narrationStripHeight = 16;
}
