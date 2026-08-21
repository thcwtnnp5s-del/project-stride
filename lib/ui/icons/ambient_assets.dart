/// The ambient scene table: which frames make which scene, and where each
/// companion stands.
///
/// ## Where this comes from
///
/// Written from the PixelLab manifest at
/// `GAME_BIBLE/ART/exploration/TRANSFORMATION_01/out/ambient/manifest.json`
/// (Transformation Build 01, stream E). One `AmbientScene` per Traveler
/// sequence; the orange cat and the two props are companion *layers* placed by
/// offset. Frames live at `assets/art/v1/ambient/<id>_f{i}.png`, packaged by
/// `Scripts/art/package-art.js`, which also measures every footprint below into
/// `SpriteFootprints` — nothing here is measured or guessed by hand.
///
/// ## Geometry, once
///
/// Every Traveler frame is 64 rows tall with the feet on row 62. Three scenes
/// are 80 wide (raised arms, a pick head) and one is 96 wide (Traveler + cat in
/// one sprite); `anchorX` says which column of the wide frame lines up with the
/// standard 64-box, so the figure never jumps between scenes. Layer offsets are
/// in the *64-box's* pixel coordinates.
///
/// Cat frames are 40 × 40 with the feet on row 27, so a cat standing on the
/// Traveler's ground row has `dy = 62 − 27 = 35`. The fire is 32 × 32 with its
/// base on row 28 (`dy = 34`).
///
/// ## Extents, measured
///
/// Every `bounds` below is the union opaque box across all frames of that
/// sequence, printed by `node Scripts/art/measure-ambient-extents.js` against
/// the packaged art on 2026-08-19, and copied here as constants. They are what
/// the offsets are authored against and what `test/ambient_composition_test`
/// checks the whole table with, on the same `AmbientStageLayout` the card
/// draws with:
///
/// ```text
/// cat_bat_yarn      40x40  4,11..34,27     traveler_crouch_pet    64x64 14,1..47,63
/// cat_lie_rest      40x40  6,13..31,27     traveler_dangle_string 64x64  0,1..49,62
/// cat_roll          40x40  4,10..34,27     traveler_drink         64x64 14,0..46,62
/// cat_settle        40x40  5,10..31,27     traveler_eat           64x64 15,1..47,62
/// cat_sit_down      40x40  5,10..30,27     traveler_head_scratch  64x64 10,1..46,62
/// cat_stretch       40x40  4,10..34,27     traveler_pack_check    64x64 13,1..56,62
/// prop_fire         32x32  3,3..28,28      traveler_pushups_side  80x64  9,1..72,62
/// pair_pet_cat      96x64 12,1..78,62      traveler_sit_ground    64x64 14,1..47,62
///                                          traveler_stretch       80x64  6,0..72,62
///                                          traveler_wipe_brow     64x64 10,1..48,62
/// ```
///
/// The stage puts the 64-box's left edge 45 dp in from a 178 dp stage's left
/// (`AmbientStageLayout.travelerCentre`), so a layer's opaque left may reach
/// −22 px and the widest frame's right, 64 px, still clears the edge. Every
/// companion is on the Traveler's viewer-left — the string, the petting hand
/// and the combined sprite were all authored that way, and the cats all face
/// east, towards him — under the raised scenery, on the ground.
///
/// ## The micro-idle pool
///
/// `AmbientPlayer`'s idle cadence draws its small beats from the scenes in this
/// table that carry an `idleWeight` — the pool is *derived* from the one list
/// (`AmbientSceneSet.microIdles`), so a micro-idle is measured, composed and
/// tested exactly like any other scene and there is no second list to keep in
/// step. The dedicated idles `idle_breathe` (3) and `look_around` (2.5) carry
/// most beats; `wipe_brow` (1.2), `pack_check` (0.8) and `head_scratch` (0.5)
/// stay in the pool at low weight so the idle never repeats one gesture.
/// `traveler_shift_weight` was withheld (it does not return to the rest pose).
///
/// ## What this is not
///
/// A pet system, a fire system, or a rest system. Nothing here has state, and
/// nothing outside `AmbientPlayer` reads it (`ambient_scene.dart`).
library;

import '../components/ambient_scene.dart';
import '../components/ambient_stage.dart' show StageScenery;
import 'pixel_icons.dart';
import 'sprite_footprints.dart';

const String _art = 'assets/art/v1';

/// `ambient/<id>_f0.png … <id>_f{count-1}.png`.
List<String> _frames(String id, int count) => List<String>.generate(
  count,
  (int i) => '$_art/ambient/${id}_f$i.png',
  growable: false,
);

const int _catDy = 35;
const int _fireDy = 34;

// Measured union opaque bounds — see the library doc.
const SpriteBounds _bCatBatYarn = SpriteBounds(
  left: 4,
  top: 11,
  right: 34,
  bottom: 27,
);
const SpriteBounds _bCatLieRest = SpriteBounds(
  left: 6,
  top: 13,
  right: 31,
  bottom: 27,
);
const SpriteBounds _bCatRoll = SpriteBounds(
  left: 4,
  top: 10,
  right: 34,
  bottom: 27,
);
const SpriteBounds _bCatSettle = SpriteBounds(
  left: 5,
  top: 10,
  right: 31,
  bottom: 27,
);
const SpriteBounds _bCatSitDown = SpriteBounds(
  left: 5,
  top: 10,
  right: 30,
  bottom: 27,
);
const SpriteBounds _bCatStretch = SpriteBounds(
  left: 4,
  top: 10,
  right: 34,
  bottom: 27,
);
const SpriteBounds _bPropFire = SpriteBounds(
  left: 3,
  top: 3,
  right: 28,
  bottom: 28,
);
const SpriteBounds _bPairPetCat = SpriteBounds(
  left: 12,
  top: 1,
  right: 78,
  bottom: 62,
);
const SpriteBounds _bCrouchPet = SpriteBounds(
  left: 14,
  top: 1,
  right: 47,
  bottom: 63,
);
const SpriteBounds _bDangleString = SpriteBounds(
  left: 0,
  top: 1,
  right: 49,
  bottom: 62,
);
const SpriteBounds _bDrink = SpriteBounds(
  left: 14,
  top: 0,
  right: 46,
  bottom: 62,
);
const SpriteBounds _bEat = SpriteBounds(
  left: 15,
  top: 1,
  right: 47,
  bottom: 62,
);
const SpriteBounds _bHeadScratch = SpriteBounds(
  left: 10,
  top: 1,
  right: 46,
  bottom: 62,
);
const SpriteBounds _bPackCheck = SpriteBounds(
  left: 13,
  top: 1,
  right: 56,
  bottom: 62,
);
// World & Reward Depth 01: the book-scale correction keeps the book inside the
// standing silhouette (measured 2026-08-19; the PE01 read reached x 1..61).
const SpriteBounds _bRead = SpriteBounds(
  left: 15,
  top: 1,
  right: 46,
  bottom: 62,
);
const SpriteBounds _bIdleBreathe = SpriteBounds(
  left: 13,
  top: 0,
  right: 48,
  bottom: 62,
);
const SpriteBounds _bLookAround = SpriteBounds(
  left: 12,
  top: 1,
  right: 51,
  bottom: 62,
);
const SpriteBounds _bPushupsSide = SpriteBounds(
  left: 9,
  top: 1,
  right: 72,
  bottom: 62,
);
const SpriteBounds _bSitGround = SpriteBounds(
  left: 14,
  top: 1,
  right: 47,
  bottom: 62,
);
const SpriteBounds _bStretch = SpriteBounds(
  left: 6,
  top: 0,
  right: 72,
  bottom: 62,
);
const SpriteBounds _bWipeBrow = SpriteBounds(
  left: 10,
  top: 1,
  right: 48,
  bottom: 62,
);

AmbientTrack _cat(
  String id,
  int frames,
  double fps, {
  AmbientLoop loop = AmbientLoop.loop,
  int repeats = 6,
}) => AmbientTrack(
  frames: _frames(id, frames),
  fps: fps,
  loop: loop,
  repeats: repeats,
);

/// The cat sitting down once and staying seated (frame 7 is the seated hold;
/// `once` holds the last frame for the rest of the scene).
AmbientLayer _catSitsAt(int dx) => AmbientLayer(
  track: _cat('cat_sit_down', 8, 6, loop: AmbientLoop.once),
  canvas: 40,
  footprint: SpriteFootprints.ambientCatSitDown,
  bounds: _bCatSitDown,
  dx: dx,
  dy: _catDy,
);

/// Withheld after independent Visual QA at play scale (TRANSFORMATION_01/
/// ambient/README.md, 2026-08-17): `traveler_axe_inspect` (the pale head read
/// as a sheet of paper; the Playable Expansion 01 re-roll then read as a
/// mallet — still withheld). Two of the three withheld scenes were corrected in
/// that round (PLAYABLE_EXPANSION_01/ambient/README.md): `traveler_read` (a
/// large dark book with a bright page block — Visual QA PASS at ×2) and
/// `traveler_pick_inspect` (crouched over a pick held horizontal and low, never
/// raised — PASS-WITH-NOTE "holding a pick, not mining; second read
/// idle-with-tool", enabled by lead override because that note *is* the read
/// the correction was for). World & Reward Depth 01 then re-rolled the read at
/// book scale (the PE01 book was "huge" on the phone) and a second blind pass
/// read the pick scene as "pickaxe pops into existence, no action" — FAIL — so
/// the override is withdrawn: the read below is the corrected one, and the
/// pick and axe frames stay packaged and out.
abstract final class AmbientAssets {
  /// The frame the Traveler rests on between scenes and after a visit. The
  /// gather rest pose, so ambient → gather → ambient has no visual pop: every
  /// transition passes through the same standing figure.
  static const String restFrame = '$_art/anim/gather_f0.png';
  static const SpriteFootprint restFootprint = SpriteFootprints.gather;

  /// The union opaque box of the eight gather frames — the rest pose and the
  /// swing that plays over the scenery most often (measured 2026-08-19).
  static const SpriteBounds restBounds = SpriteBounds(
    left: 14,
    top: 0,
    right: 49,
    bottom: 63,
  );

  /// The working loop an active gathering queue plays for [skill], with its
  /// footprint below — one entry per profession, looked up by the skill's
  /// content-id string (`skill.woodcutting` — `assets/content/v1/skills.json`).
  ///
  /// **A string key, deliberately, not a `ContentId`.** The ambient boundary
  /// guard (`ambient_player_test.dart`, "ambient sources touch nothing but
  /// presentation") forbids this file any `stride_core` reference — ambient is
  /// presentation only. The caller passes `skill.value`; the table is the same
  /// either way.
  ///
  /// The three shipped loops are PixelLab west-facing work cycles
  /// (`ACTIVITY_FEEL_01/README.md` §2, blind PASS-WITH-NOTE each), packaged
  /// by `package-art.js` to one fixed box per loop with the feet on row 62.
  /// Foraging plays **ping-pong** — down the kneel and back up through the
  /// same frames — because the source loop ends crouched and a hard wrap to
  /// standing would pop; listing the paths twice is frame-order authoring,
  /// not duplicated assets. Cooking and smithing are unlisted and fall back
  /// to the gather cycle rather than to nothing, so a future content pack
  /// cannot mount an empty stage.
  static List<String> activityLoopFor(String skill) =>
      _activityLoops[skill] ?? PixelIcons.gatherFrames;

  /// Whether [skill] has an authored working loop of its own. False for a
  /// profession the art rounds have not delivered — the craft stage then
  /// renders no figure rather than a wrong one (the gather fallback above is
  /// for the gather stage, whose skills all have loops).
  static bool hasActivityLoop(String skill) =>
      _activityLoops.containsKey(skill);

  /// The rest-pose footprint of [activityLoopFor]'s frame set — the same
  /// pairing `SpriteAnimation` requires, for the same shadow reason.
  static SpriteFootprint activityFootprintFor(String skill) =>
      _activityFootprints[skill] ?? SpriteFootprints.gather;

  /// The loop's frame width in native pixels. The work loops are wider than
  /// the 64-box because the tool's swing needs the room; the stage aligns
  /// the figures by their feet centres, so a wider canvas costs nothing but
  /// clipped arc tips at the stage edge.
  static int activityCanvasFor(String skill) => _activityCanvases[skill] ?? 64;

  static final List<String> _woodcutFrames = _frames('activity_woodcut', 8);
  static final List<String> _mineFrames = _frames('activity_mine', 6);
  static final List<String> _forageFrames = _frames('activity_forage', 9);

  /// The craft loops (PRESENTATION_WORLD_REWARD_FEEL_01 §17): the Traveler
  /// at a forge and at a cookfire, the same west-facing family and the same
  /// 64-row ground convention as the gathering loops.
  static final List<String> _smithFrames = _frames('activity_smith', 7);
  static final List<String> _cookFrames = _frames('activity_cook', 7);

  static final Map<String, List<String>> _activityLoops =
      <String, List<String>>{
        'skill.woodcutting': _woodcutFrames,
        'skill.mining': _mineFrames,
        'skill.foraging': <String>[
          ..._forageFrames,
          for (int i = 7; i >= 1; i--) _forageFrames[i],
        ],
        'skill.smithing': _smithFrames,
        'skill.cooking': _cookFrames,
      };

  static const Map<String, SpriteFootprint> _activityFootprints =
      <String, SpriteFootprint>{
        'skill.woodcutting': SpriteFootprints.ambientActivityWoodcut,
        'skill.mining': SpriteFootprints.ambientActivityMine,
        'skill.foraging': SpriteFootprints.ambientActivityForage,
        'skill.smithing': SpriteFootprints.ambientActivitySmith,
        'skill.cooking': SpriteFootprints.ambientActivityCook,
      };

  static const Map<String, int> _activityCanvases = <String, int>{
    'skill.woodcutting': 76,
    'skill.mining': 66,
    'skill.foraging': 44,
    'skill.smithing': 74,
    'skill.cooking': 46,
  };

  /// The node vignettes as stage scenery, keyed by the asset path
  /// `PixelIcons.nodeFor` returns, each with its measured opaque box
  /// (`measure-ambient-extents.js`, 2026-08-19; all 96 × 96).
  static StageScenery? sceneryFor(String? nodeArt) =>
      nodeArt == null ? null : _scenery[nodeArt];

  static const Map<String, StageScenery> _scenery = <String, StageScenery>{
    '$_art/node/meadow_patch.png': StageScenery(
      assetPath: '$_art/node/meadow_patch.png',
      bounds: SpriteBounds(left: 15, top: 16, right: 88, bottom: 85),
    ),
    '$_art/node/oak_stand.png': StageScenery(
      assetPath: '$_art/node/oak_stand.png',
      bounds: SpriteBounds(left: 2, top: 4, right: 95, bottom: 94),
    ),
    '$_art/node/duskcap_grove.png': StageScenery(
      assetPath: '$_art/node/duskcap_grove.png',
      bounds: SpriteBounds(left: 12, top: 8, right: 79, bottom: 78),
    ),
    '$_art/node/copper_seam.png': StageScenery(
      assetPath: '$_art/node/copper_seam.png',
      bounds: SpriteBounds(left: 10, top: 11, right: 79, bottom: 90),
    ),
    '$_art/node/tin_seam.png': StageScenery(
      assetPath: '$_art/node/tin_seam.png',
      bounds: SpriteBounds(left: 2, top: 6, right: 93, bottom: 90),
    ),
    // PRESENTATION_WORLD_REWARD_FEEL_01 B-3 — the node RCP01 shipped without
    // stage art. Bounds measured by Scripts/art/png.js on the accepted plate.
    '$_art/node/hardened_copper_seam.png': StageScenery(
      assetPath: '$_art/node/hardened_copper_seam.png',
      bounds: SpriteBounds(left: 10, top: 11, right: 79, bottom: 90),
    ),
    '$_art/node/rimefrost_hollow.png': StageScenery(
      assetPath: '$_art/node/rimefrost_hollow.png',
      bounds: SpriteBounds(left: 2, top: 5, right: 93, bottom: 91),
    ),
    '$_art/node/frostpine_stand.png': StageScenery(
      assetPath: '$_art/node/frostpine_stand.png',
      bounds: SpriteBounds(left: 12, top: 6, right: 83, bottom: 87),
    ),
    '$_art/node/hollow_thicket.png': StageScenery(
      assetPath: '$_art/node/hollow_thicket.png',
      bounds: SpriteBounds(left: 1, top: 3, right: 94, bottom: 93),
    ),
  };

  /// The craft station a profession works at, as stage scenery — the forge
  /// for smithing, the cookfire for cooking
  /// (PRESENTATION_WORLD_REWARD_FEEL_01 §17). Null for a profession with no
  /// authored station, in which case the craft stage shows the figure alone.
  ///
  /// Same role the node vignettes play on the gathering stage: ×1 art behind
  /// the ×2 figure, raised off the ground line, placed by
  /// `AmbientStageLayout`. Bounds measured by `Scripts/art/png.js` on the
  /// packaged props.
  static StageScenery? stationFor(String skill) => _stations[skill];

  static const Map<String, StageScenery> _stations = <String, StageScenery>{
    'skill.smithing': StageScenery(
      assetPath: '$_art/node/station_forge.png',
      native: 64,
      bounds: SpriteBounds(left: 4, top: 18, right: 59, bottom: 61),
    ),
    'skill.cooking': StageScenery(
      assetPath: '$_art/node/station_cookfire.png',
      native: 64,
      bounds: SpriteBounds(left: 6, top: 20, right: 57, bottom: 60),
    ),
  };

  /// Every scenery entry, for the composition test.
  static Iterable<StageScenery> get allScenery => _scenery.values;

  static final AmbientSceneSet scenes = AmbientSceneSet(<AmbientScene>[
    // ---------------------------------------------------------- solo scenes
    AmbientScene(
      id: 'stretch',
      // Frames 0..3 only: shoulders rolling out to arms held level. Frames 4
      // and 5 raise the arms straight up, and Visual QA read that peak as a
      // cheer at ×2 (README §QA); cutting the peak is a playback fix, not an
      // art fix. The bounds are still the six-frame union, which is wider
      // than these four need — conservative, and measured.
      traveler: AmbientTrack(
        frames: _frames('traveler_stretch', 4),
        fps: 6,
        loop: AmbientLoop.pingpong,
        repeats: 3,
      ),
      footprint: SpriteFootprints.ambientTravelerStretch,
      canvas: 80,
      bounds: _bStretch,
    ),
    AmbientScene(
      id: 'drink',
      traveler: AmbientTrack(
        frames: _frames('traveler_drink', 9),
        fps: 8,
        repeats: 2,
      ),
      footprint: SpriteFootprints.ambientTravelerDrink,
      bounds: _bDrink,
    ),
    // World & Reward Depth 01: the read scene re-rolled at book scale after the
    // owner saw the PE01 book "huge" on the phone — blind Visual QA read the
    // shipped frames as "unfolding a giant map" (FAIL) and the replacement as
    // "reading a small book" (PASS-WITH-NOTE: one-shot, closed by pingpong).
    // Solo scene; bounds 15..46, so a companion could now sit beside it — none
    // is placed yet. `pick_inspect` is OUT of the rotation: the same blind pass
    // read the shipped frames as "pickaxe pops into existence, no grip, no
    // action" (FAIL); the PE01 lead override is withdrawn and the frames stay
    // packaged (WORLD_REWARD_DEPTH_01/ambient/README.md §8).
    AmbientScene(
      id: 'read',
      traveler: AmbientTrack(
        frames: _frames('traveler_read', 9),
        fps: 6,
        loop: AmbientLoop.pingpong,
        repeats: 2,
      ),
      footprint: SpriteFootprints.ambientTravelerRead,
      bounds: _bRead,
    ),
    // The idle-cadence micro-idles (World & Reward Depth 01, blind QA PASS /
    // PASS-WITH-NOTE). `idleOnly`: never one of a visit's scenes; `idleWeight`
    // ~3 so they carry most idle beats over the stand-ins below.
    AmbientScene(
      id: 'idle_breathe',
      traveler: AmbientTrack(
        frames: _frames('traveler_idle_breathe', 7),
        fps: 5,
        loop: AmbientLoop.pingpong,
        // One breath out and back (2.4 s): a micro-idle recurs, so it stays
        // under the cadence's 4 s ceiling.
        repeats: 1,
      ),
      footprint: SpriteFootprints.ambientTravelerIdleBreathe,
      bounds: _bIdleBreathe,
      idleWeight: 3,
      idleOnly: true,
    ),
    AmbientScene(
      id: 'look_around',
      traveler: AmbientTrack(
        frames: _frames('traveler_look_around', 7),
        fps: 5,
        loop: AmbientLoop.pingpong,
        repeats: 1,
      ),
      footprint: SpriteFootprints.ambientTravelerLookAround,
      bounds: _bLookAround,
      idleWeight: 2.5,
      idleOnly: true,
    ),
    AmbientScene(
      id: 'pack_check',
      traveler: AmbientTrack(
        frames: _frames('traveler_pack_check', 6),
        fps: 6,
        loop: AmbientLoop.pingpong,
        repeats: 2,
      ),
      footprint: SpriteFootprints.ambientTravelerPackCheck,
      bounds: _bPackCheck,
      // Micro-idle stand-in — see the class doc.
      idleWeight: 0.8,
    ),
    AmbientScene(
      id: 'wipe_brow',
      traveler: AmbientTrack(
        frames: _frames('traveler_wipe_brow', 7),
        fps: 7,
        repeats: 2,
      ),
      footprint: SpriteFootprints.ambientTravelerWipeBrow,
      bounds: _bWipeBrow,
      // Micro-idle stand-in — see the class doc. The shortest solo scene in
      // the table (2.0 s) and the least eventful, so it carries the pool.
      idleWeight: 1.2,
    ),

    // ----------------------------------------------- scenes with the cat
    AmbientScene(
      id: 'pet_cat',
      traveler: AmbientTrack(
        frames: _frames('pair_pet_cat', 11),
        fps: 7,
        repeats: 2,
      ),
      // The Traveler occupies x 32..95 of the combined sprite; the footprint
      // is the standing sprite's own contact span shifted by that anchor, so
      // the shadow sits under the figure rather than spanning figure and cat.
      // In 64-box terms the cat reaches to −20, which the stage's 45 dp of
      // left room holds.
      footprint: const SpriteFootprint(left: 51, right: 74, bottom: 62),
      canvas: 96,
      anchorX: 32,
      bounds: _bPairPetCat,
      weight: 2,
    ),
    AmbientScene(
      id: 'dangle_string',
      traveler: AmbientTrack(
        frames: _frames('traveler_dangle_string', 9),
        fps: 7,
        loop: AmbientLoop.pingpong,
        repeats: 2,
      ),
      footprint: SpriteFootprints.ambientTravelerDangleString,
      bounds: _bDangleString,
      layers: <AmbientLayer>[
        // The string hangs at x 0..3 of the frame; the cat's swatting paw is
        // at x ≈ 24..28 of its own, so −24 puts the paw under the string. Its
        // box then reaches −20..10 against the arm's 0..49: the overlap is
        // the arm above the cat, not the cat in the man.
        AmbientLayer(
          track: _cat('cat_bat_yarn', 8, 8),
          canvas: 40,
          footprint: SpriteFootprints.ambientCatBatYarn,
          bounds: _bCatBatYarn,
          dx: -24,
          dy: _catDy,
        ),
      ],
      companionAllowance: 12,
      weight: 1.5,
    ),
    AmbientScene(
      id: 'crouch_pet',
      traveler: AmbientTrack(
        frames: _frames('traveler_crouch_pet', 11),
        fps: 7,
        repeats: 2,
      ),
      footprint: SpriteFootprints.ambientTravelerCrouchPet,
      bounds: _bCrouchPet,
      // The hand reaches to x ≈ 14–18; the cat sits under it, viewer-left,
      // its back (x −3..22) meeting the crouched body (14..47) by 9 px —
      // the touch is the scene.
      layers: <AmbientLayer>[_catSitsAt(-8)],
      companionAllowance: 10,
      weight: 1.5,
    ),
    AmbientScene(
      id: 'sit_by_fire',
      traveler: AmbientTrack(
        frames: _frames('traveler_sit_ground', 11),
        fps: 6,
        loop: AmbientLoop.pingpong,
        repeats: 1,
      ),
      footprint: SpriteFootprints.ambientTravelerSitGround,
      bounds: _bSitGround,
      layers: <AmbientLayer>[
        // The cat curled on his viewer-left, at −22..3 against the seated
        // 14..47: clear, and on the floor under the scenery. (It lay at 42
        // once — on the vignette.)
        AmbientLayer(
          track: _cat('cat_lie_rest', 4, 3, repeats: 4),
          canvas: 40,
          footprint: SpriteFootprints.ambientCatLieRest,
          bounds: _bCatLieRest,
          dx: -28,
          dy: _catDy,
        ),
        // The fire on his other side, behind him: at 39..64 its box shares
        // 9 px with his, which is the flame's edge showing past his shoulder
        // and knee, and its far edge is 5 dp inside the stage. It stood on
        // his viewer-left at −24 first, and its flame tip crossed into the
        // raised scenery's base on every node — the fire is 26 px tall and
        // the cat is 17, and only one of them fits under a base 47 dp up.
        AmbientLayer(
          track: _cat('prop_fire', 4, 6, repeats: 8),
          canvas: 32,
          footprint: SpriteFootprints.ambientPropFire,
          bounds: _bPropFire,
          dx: 36,
          dy: _fireDy,
          behind: true,
        ),
      ],
      companionAllowance: 9,
      weight: 1.5,
    ),
    AmbientScene(
      id: 'eat',
      traveler: AmbientTrack(
        frames: _frames('traveler_eat', 9),
        fps: 8,
        loop: AmbientLoop.pingpong,
        repeats: 2,
      ),
      footprint: SpriteFootprints.ambientTravelerEat,
      bounds: _bEat,
      // Sitting at −13..12, three pixels short of him.
      layers: <AmbientLayer>[_catSitsAt(-18)],
    ),
    AmbientScene(
      id: 'head_scratch',
      traveler: AmbientTrack(
        frames: _frames('traveler_head_scratch', 9),
        fps: 8,
        repeats: 2,
      ),
      footprint: SpriteFootprints.ambientTravelerHeadScratch,
      bounds: _bHeadScratch,
      layers: <AmbientLayer>[
        // Rolling on his viewer-left (−22..8 against 10..46). At 44 it rolled
        // across the vignette.
        AmbientLayer(
          track: _cat('cat_roll', 9, 7, loop: AmbientLoop.pingpong, repeats: 2),
          canvas: 40,
          footprint: SpriteFootprints.ambientCatRoll,
          bounds: _bCatRoll,
          dx: -26,
          dy: _catDy,
        ),
      ],
      // Micro-idle stand-in — see the class doc. Lowest of the three: the cat
      // rolling is the most eventful thing in the pool, so it comes round
      // least often.
      idleWeight: 0.5,
    ),
    AmbientScene(
      id: 'pushups',
      traveler: AmbientTrack(
        frames: _frames('traveler_pushups_side', 11),
        fps: 6,
        loop: AmbientLoop.pingpong,
        repeats: 2,
      ),
      footprint: SpriteFootprints.ambientTravelerPushupsSide,
      canvas: 80,
      bounds: _bPushupsSide,
      layers: <AmbientLayer>[
        // The plank's feet are at the frame's left; the cat settles by them
        // (−21..5 against 1..64), watching. In 64-box coordinates, so the
        // 80-frame's anchor of 8 is already accounted for.
        AmbientLayer(
          track: _cat('cat_settle', 7, 5, loop: AmbientLoop.once),
          canvas: 40,
          footprint: SpriteFootprints.ambientCatSettle,
          bounds: _bCatSettle,
          dx: -26,
          dy: _catDy,
        ),
      ],
      companionAllowance: 6,
    ),
    AmbientScene(
      id: 'stretch_with_cat',
      // Same four-frame cut as `stretch`.
      traveler: AmbientTrack(
        frames: _frames('traveler_stretch', 4),
        fps: 6,
        loop: AmbientLoop.pingpong,
        repeats: 3,
      ),
      footprint: SpriteFootprints.ambientTravelerStretch,
      canvas: 80,
      bounds: _bStretch,
      layers: <AmbientLayer>[
        // Stretching alongside him, viewer-left. The boxes share 14 px only
        // because his box includes the level arm; the cat is on the ground
        // and the arm is at shoulder height. At 56 it stood on the vignette.
        AmbientLayer(
          track: _cat(
            'cat_stretch',
            7,
            6,
            loop: AmbientLoop.pingpong,
            repeats: 2,
          ),
          canvas: 40,
          footprint: SpriteFootprints.ambientCatStretch,
          bounds: _bCatStretch,
          dx: -22,
          dy: _catDy,
        ),
      ],
      companionAllowance: 16,
      weight: 0.8,
    ),
  ]);
}
