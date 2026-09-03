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

// The four shipped fauna stills' opaque boxes, from the Regional Content
// Pack 01 fauna manifest (Fable V2 Iteration 02) — measured there by the
// same tooling as everything above.
const SpriteBounds _bFaunaHare = SpriteBounds(
  left: 3,
  top: 0,
  right: 12,
  bottom: 15,
);
const SpriteBounds _bFaunaSongbird = SpriteBounds(
  left: 1,
  top: 1,
  right: 14,
  bottom: 14,
);
const SpriteBounds _bFaunaCrow = SpriteBounds(
  left: 2,
  top: 3,
  right: 13,
  bottom: 13,
);
const SpriteBounds _bFaunaPtarmigan = SpriteBounds(
  left: 3,
  top: 2,
  right: 13,
  bottom: 12,
);

/// One region's creature as a companion layer: a 16 px still, standing at
/// the stage's left edge on the Traveler's own ground line, its bottom
/// opaque row on row 62. A single-frame `once` track holds it for the whole
/// scene. `dx` puts each box's left at −21 — one pixel inside the narrow
/// stage's −22 edge, well clear of every solo scene's Traveler.
AmbientLayer _faunaStill(
  String id,
  SpriteBounds bounds,
  SpriteFootprint footprint,
) => AmbientLayer(
  track: AmbientTrack(frames: _frames(id, 1), fps: 1, loop: AmbientLoop.once),
  canvas: 16,
  footprint: footprint,
  bounds: bounds,
  dx: -21 - bounds.left,
  dy: 62 - bounds.bottom,
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
  /// not duplicated assets. Smithing and cooking play the same way, for the
  /// same reason. A skill with no listed loop falls back to the gather cycle
  /// rather than to nothing, so a future content pack cannot mount an empty
  /// stage.
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

  /// Which frame of [activityLoopFor]'s list is the **strike** — the tool
  /// meeting the material — so the action cue sounds when the player sees
  /// the contact (AUDIO_PRESENTATION_01). A property of the authored loops,
  /// which is why it lives beside them and not in the audio tables.
  ///
  /// The wrap loops (mining, woodcutting) land mid-cycle; the ping-pong
  /// loops land at their turning point — the last index of the base frame
  /// run, where the hammer is on the anvil, the spoon in the pot, the hand
  /// at the plant. First-pass authoring by loop structure, expected to be
  /// retuned by ear on the device (a polish observation, not a system).
  static int strikeFrameFor(String skill) => _strikeFrames[skill] ?? 0;

  static const Map<String, int> _strikeFrames = <String, int>{
    'skill.mining': 4,
    'skill.woodcutting': 4,
    'skill.foraging': 8,
    'skill.smithing': 6,
    'skill.cooking': 6,
  };

  static final List<String> _woodcutFrames = _frames('activity_woodcut', 8);
  static final List<String> _mineFrames = _frames('activity_mine', 8);
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
        // The craft loops play ping-pong for the same reason foraging does
        // (PLAYABLE_EXPERIENCE_REFINEMENT_01 §14): both source loops end
        // with the tool low — hammer on the anvil, spoon in the pot — and
        // begin with it raised, so a hard wrap popped the tool back up in one
        // frame. Played down and back up through the same frames the stroke
        // is continuous. Frame-order authoring, not new frames (A-2).
        'skill.smithing': <String>[
          ..._smithFrames,
          for (int i = 5; i >= 1; i--) _smithFrames[i],
        ],
        'skill.cooking': <String>[
          ..._cookFrames,
          for (int i = 5; i >= 1; i--) _cookFrames[i],
        ],
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
    'skill.mining': 60,
    'skill.foraging': 44,
    'skill.smithing': 74,
    'skill.cooking': 46,
  };

  /// The node vignettes as stage scenery, keyed by the asset path
  /// `PixelIcons.nodeFor` returns, each with its measured opaque box
  /// (`measure-ambient-extents.js`, 2026-08-19; all 96 × 96).
  /// The idle scene set with the cat left out — the workplace cadence.
  ///
  /// The cat is a companion, not a UI element (§6). It belongs in the living
  /// location: idling, resting, batting a string while the Traveler stands
  /// around. It does not belong underfoot at a rock face a pickaxe is coming
  /// down on, and the owner's device found exactly that — Traveler, cat, mine
  /// entrance and a boulder all competing inside one 176 dp band.
  ///
  /// So the cat is not deleted anywhere; it is **absent from the work
  /// composition**, and returns the moment the player steps back to the
  /// location. This is the same seven solo scenes the full set opens with,
  /// with the eight companion scenes filtered out by the layer they draw
  /// rather than by a hand-kept second list that could drift.
  static final AmbientSceneSet soloScenes = AmbientSceneSet(
    scenes.scenes
        .where(
          (AmbientScene s) => !s.layers.any(
            (AmbientLayer l) =>
                l.track.frames.any((String f) => f.contains('cat')),
          ),
        )
        .toList(growable: false),
  );

  static StageScenery? sceneryFor(String? nodeArt) =>
      nodeArt == null ? null : _scenery[nodeArt];

  /// The **near work prop** for a resource node: the thing the Traveler's
  /// tool actually lands on, drawn on his own ground line
  /// (`AmbientStageLayout.propRect`).
  ///
  /// Distinct from [sceneryFor], which answers the far vignette — *where he
  /// is* rather than *what he is hitting*. One per profession family, shared
  /// by every node in it, because the owner asked for reusable compositions
  /// with an interchangeable resource object and not a bespoke scene per ore
  /// (§4). Where a node has no authored work prop the caller falls back to
  /// its node vignette, which is worse but never blank.
  static StageScenery? workPropFor(String nodeArt) => _workProps[nodeArt];

  /// The **work backdrop**: the tighter place the focused composition happens
  /// in, in place of the full location painting.
  ///
  /// **Keyed by region *and* skill since VAWO01** (`DECISIONS/0031`). It was
  /// keyed by skill alone, and there were three plates for five regions — so
  /// choosing an activity threw away the regional arrival painting and every
  /// foraging node in the game, at Haven, in the Woods, at Frostmere and in
  /// the Hollow, showed Haven's meadow. Nothing on screen said where the
  /// player was for the whole of a gather.
  ///
  /// The region comes from the [vignette] the screen is already holding —
  /// the arrival painting's own path — rather than from a location id passed
  /// down beside it. That is deliberate: the backdrop and the painting it
  /// replaces are then derived from one value and **cannot disagree about
  /// where we are**.
  ///
  /// [nodeArt] takes precedence where a node has a built variant. Those nodes
  /// only unlock when their project is complete, so the built backdrop is
  /// unconditionally correct and the stage needs no state read to choose it —
  /// and the player finally sees the thing they spent steps building, every
  /// time they work it.
  static String? workBackdropFor(
    String skill, {
    String? vignette,
    String? nodeArt,
  }) {
    final String? built = nodeArt == null ? null : _builtBackdrops[nodeArt];
    if (built != null) return built;

    final String? region = _regionOf(vignette);
    if (region != null) {
      final String? keyed = _regionWorkBackdrops['$region|$skill'];
      if (keyed != null) return keyed;
    }
    // A region×skill pair the content graph does not contain, or an unknown
    // vignette. Falls back to the profession plate rather than to nothing.
    return _workBackdrops[skill];
  }

  /// The bare region name from a location vignette path, or null.
  static String? _regionOf(String? vignette) {
    if (vignette == null) return null;
    final int slash = vignette.lastIndexOf('/');
    if (slash < 0) return null;
    final String file = vignette.substring(slash + 1);
    if (!file.endsWith('.png')) return null;
    // `alt_` variants name the same place.
    final String stem = file.substring(0, file.length - 4);
    return stem.startsWith('alt_') ? stem.substring(4) : stem;
  }

  /// region × skill → the plate authored for that pair.
  static const Map<String, String> _regionWorkBackdrops = <String, String>{
    'havens_rest|skill.foraging': '$_art/work/bg_haven_foraging.png',
    'whispering_woods|skill.woodcutting': '$_art/work/bg_woods_woodcutting.png',
    'whispering_woods|skill.foraging': '$_art/work/bg_woods_foraging.png',
    'stonefall_mine|skill.mining': '$_art/work/bg_stonefall_mining.png',
    'frostmere|skill.woodcutting': '$_art/work/bg_frostmere_woodcutting.png',
    'frostmere|skill.foraging': '$_art/work/bg_frostmere_foraging.png',
    'forgotten_hollow|skill.foraging': '$_art/work/bg_hollow_foraging.png',
  };

  /// Nodes whose unlocking project changes the place they are worked in.
  static const Map<String, String> _builtBackdrops = <String, String>{
    '$_art/node/mill_garden.png': '$_art/work/bg_haven_mill_garden.png',
    '$_art/node/warded_grove.png': '$_art/work/bg_woods_warded_grove.png',
    '$_art/node/old_workings.png': '$_art/work/bg_stonefall_lift.png',
    '$_art/node/hardened_copper_seam.png': '$_art/work/bg_stonefall_lift.png',
    '$_art/node/gallery_tin_lode.png': '$_art/work/bg_stonefall_gallery.png',
    '$_art/node/collapsed_span.png': '$_art/work/bg_stonefall_gallery.png',
    '$_art/node/sheltered_frost_meadow.png':
        '$_art/work/bg_frostmere_shelter.png',
    '$_art/node/veiled_silkstrand.png': '$_art/work/bg_hollow_field_camp.png',
    '$_art/node/undercroft_silkfall.png': '$_art/work/bg_hollow_undercroft.png',
    '$_art/node/deep_hollow_thicket.png': '$_art/work/bg_hollow_undercroft.png',
  };

  /// Whether this profession's loop works towards the figure's **east**.
  ///
  /// Every shipped loop — woodcutting, mining, foraging, smithing, cooking —
  /// faces west and acts on its viewer-left, so today the answer is always
  /// no. The hook stays because the answer is a property of the **loop**,
  /// not of the stage: the first mining loop (ACTIVITY_FEEL_01 `mine2`) was
  /// a west-facing figure whose strike landed east, behind his own back.
  /// Placing the seam east made the pick touch it and made the whole scene
  /// read as backward on the owner's device — the Traveler working with his
  /// back to the ore (PLAYABLE_POLISH_01 §1). The loop was re-authored to
  /// strike in front rather than the stage bent around the fault. If a
  /// future loop genuinely works east, say so here and nowhere else.
  ///
  /// A table rather than a measurement. The union of a loop's frame bounds is
  /// symmetric for a tool that swings through an arc, so the extents cannot
  /// answer this; only looking at the animation can, and this is where that
  /// looking is written down.
  static bool worksEast(String skill) => false;

  static const Map<String, String> _workBackdrops = <String, String>{
    'skill.mining': '$_art/work/bg_mining.png',
    'skill.woodcutting': '$_art/work/bg_woodcutting.png',
    'skill.foraging': '$_art/work/bg_foraging.png',
  };

  /// Keyed by the node's **vignette path**, the same key [sceneryFor] takes,
  /// so one lookup site answers both and a node cannot be wired into one
  /// table and forgotten in the other.
  ///
  /// **Every one of the twenty-two nodes now has an entry** (VAWO01). Twelve
  /// of them previously had none and fell through to their 96 inventory-icon
  /// vignette, which is what the owner was seeing as "a weird isolated object
  /// floating in the centre of a scene": several of those plates carry their
  /// own ground — a snow patch, a separate soil line — pasted onto an
  /// unrelated backdrop.
  ///
  /// **`native` is 48 and the stage draws these at ×2** (L-18a,
  /// `DECISIONS/0031`): everything sharing the figure's ground line shares the
  /// figure's density. The on-screen footprint is unchanged at 96 dp.
  ///
  /// `behindFigure` is true for anything the tool's arc would otherwise
  /// disappear into — the rock faces and the felled boles. It is false for the
  /// low beds, which the forager kneels down onto and should reach into.
  ///
  /// Fourteen plates across twenty-two nodes; the **scene** is the pair
  /// (backdrop, subject) and all twenty-two of those are distinct.
  static const Map<String, StageScenery> _workProps = <String, StageScenery>{
    '$_art/node/meadow_patch.png': StageScenery(
      assetPath: '$_art/work/prop_meadow_bed.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 1, top: 1, right: 46, bottom: 46),
    ),
    '$_art/node/mill_garden.png': StageScenery(
      assetPath: '$_art/work/prop_meadow_bed.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 1, top: 1, right: 46, bottom: 46),
    ),
    '$_art/node/duskcap_grove.png': StageScenery(
      assetPath: '$_art/work/prop_duskcap_bed.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 2, top: 7, right: 45, bottom: 40),
    ),
    '$_art/node/rimefrost_hollow.png': StageScenery(
      assetPath: '$_art/work/prop_rime_cushion.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 1, top: 8, right: 46, bottom: 46),
    ),
    '$_art/node/sheltered_frost_meadow.png': StageScenery(
      assetPath: '$_art/work/prop_rime_cushion.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 1, top: 8, right: 46, bottom: 46),
    ),
    '$_art/node/silkstrand_thicket.png': StageScenery(
      assetPath: '$_art/work/prop_gloom_silk.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 0, top: 4, right: 47, bottom: 47),
    ),
    '$_art/node/veiled_silkstrand.png': StageScenery(
      assetPath: '$_art/work/prop_gloom_silk.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 0, top: 4, right: 47, bottom: 47),
    ),
    '$_art/node/undercroft_silkfall.png': StageScenery(
      assetPath: '$_art/work/prop_gloom_silk.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 0, top: 4, right: 47, bottom: 47),
    ),
    '$_art/node/hollow_thicket.png': StageScenery(
      assetPath: '$_art/work/prop_hollow_root.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 1, top: 3, right: 46, bottom: 45),
    ),
    '$_art/node/deep_hollow_thicket.png': StageScenery(
      assetPath: '$_art/work/prop_hollow_root.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 1, top: 3, right: 46, bottom: 45),
    ),
    '$_art/node/oak_stand.png': StageScenery(
      assetPath: '$_art/work/prop_oak_cut.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 0, top: 0, right: 47, bottom: 41),
      behindFigure: true,
    ),
    '$_art/node/warded_grove.png': StageScenery(
      assetPath: '$_art/work/prop_oak_cut.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 0, top: 0, right: 47, bottom: 41),
      behindFigure: true,
    ),
    '$_art/node/heartwood_oak.png': StageScenery(
      assetPath: '$_art/work/prop_heartwood_oak_cut.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 0, top: 0, right: 47, bottom: 47),
      behindFigure: true,
    ),
    '$_art/node/frostpine_stand.png': StageScenery(
      assetPath: '$_art/work/prop_frostpine_cut.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 1, top: 1, right: 47, bottom: 46),
      behindFigure: true,
    ),
    '$_art/node/oldgrowth_frostpine.png': StageScenery(
      assetPath: '$_art/work/prop_oldgrowth_frostpine_cut.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 0, top: 5, right: 47, bottom: 43),
      behindFigure: true,
    ),
    '$_art/node/copper_seam.png': StageScenery(
      assetPath: '$_art/work/prop_copper_face.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 7, top: 2, right: 40, bottom: 45),
      behindFigure: true,
    ),
    '$_art/node/tin_seam.png': StageScenery(
      assetPath: '$_art/work/prop_tin_face.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 0, top: 0, right: 47, bottom: 47),
      behindFigure: true,
    ),
    '$_art/node/deep_tin_seam.png': StageScenery(
      assetPath: '$_art/work/prop_deep_tin_lode.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 1, top: 1, right: 45, bottom: 46),
      behindFigure: true,
    ),
    '$_art/node/gallery_tin_lode.png': StageScenery(
      assetPath: '$_art/work/prop_tin_face.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 0, top: 0, right: 47, bottom: 47),
      behindFigure: true,
    ),
    '$_art/node/hardened_copper_seam.png': StageScenery(
      assetPath: '$_art/work/prop_hardened_copper_face.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 0, top: 1, right: 47, bottom: 47),
      behindFigure: true,
    ),
    '$_art/node/old_workings.png': StageScenery(
      assetPath: '$_art/work/prop_ruin_face.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 0, top: 1, right: 45, bottom: 46),
      behindFigure: true,
    ),
    '$_art/node/collapsed_span.png': StageScenery(
      assetPath: '$_art/work/prop_ruin_face.png',
      native: 48,
      scale: 2,
      bounds: SpriteBounds(left: 0, top: 1, right: 45, bottom: 46),
      behindFigure: true,
    ),
  };

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
    // Fable V2 (`DECISIONS/0027`): the three Verge nodes' plates are byte
    // copies of the plates named in `package-art.js` (A-2), so each carries
    // its source's measured bounds verbatim. Distinct authored scenery is a
    // recorded future PixelLab round.
    '$_art/node/deep_tin_seam.png': StageScenery(
      assetPath: '$_art/node/deep_tin_seam.png',
      bounds: SpriteBounds(left: 2, top: 6, right: 93, bottom: 90),
    ),
    '$_art/node/oldgrowth_frostpine.png': StageScenery(
      assetPath: '$_art/node/oldgrowth_frostpine.png',
      bounds: SpriteBounds(left: 12, top: 6, right: 83, bottom: 87),
    ),
    '$_art/node/silkstrand_thicket.png': StageScenery(
      assetPath: '$_art/node/silkstrand_thicket.png',
      bounds: SpriteBounds(left: 1, top: 3, right: 94, bottom: 93),
    ),
    // Fable V2 Iteration 03: the five depth nodes' plates are byte copies
    // of the plates named in `package-art.js` (A-2), so each carries its
    // donor's measured bounds verbatim. Distinct authored scenery is the
    // recorded future PixelLab round.
    '$_art/node/heartwood_oak.png': StageScenery(
      assetPath: '$_art/node/heartwood_oak.png',
      bounds: SpriteBounds(left: 2, top: 4, right: 95, bottom: 94),
    ),
    '$_art/node/old_workings.png': StageScenery(
      assetPath: '$_art/node/old_workings.png',
      bounds: SpriteBounds(left: 10, top: 11, right: 79, bottom: 90),
    ),
    '$_art/node/veiled_silkstrand.png': StageScenery(
      assetPath: '$_art/node/veiled_silkstrand.png',
      bounds: SpriteBounds(left: 1, top: 3, right: 94, bottom: 93),
    ),
    '$_art/node/sheltered_frost_meadow.png': StageScenery(
      assetPath: '$_art/node/sheltered_frost_meadow.png',
      bounds: SpriteBounds(left: 2, top: 5, right: 93, bottom: 91),
    ),
    '$_art/node/mill_garden.png': StageScenery(
      assetPath: '$_art/node/mill_garden.png',
      bounds: SpriteBounds(left: 15, top: 16, right: 88, bottom: 85),
    ),
    // Fable Depth Offensive 01 (`DECISIONS/0028`): the five depth nodes'
    // plates are recorded byte-copies of the nodes they deepen (donor table
    // in Scripts/art/package-art.js), so each carries its donor's measured
    // bounds verbatim. Distinct authored scenery is the same future icon
    // round Iteration 03 recorded (A-1).
    '$_art/node/warded_grove.png': StageScenery(
      assetPath: '$_art/node/warded_grove.png',
      bounds: SpriteBounds(left: 2, top: 4, right: 95, bottom: 94),
    ),
    '$_art/node/gallery_tin_lode.png': StageScenery(
      assetPath: '$_art/node/gallery_tin_lode.png',
      bounds: SpriteBounds(left: 2, top: 6, right: 93, bottom: 90),
    ),
    '$_art/node/collapsed_span.png': StageScenery(
      assetPath: '$_art/node/collapsed_span.png',
      bounds: SpriteBounds(left: 10, top: 11, right: 79, bottom: 90),
    ),
    '$_art/node/undercroft_silkfall.png': StageScenery(
      assetPath: '$_art/node/undercroft_silkfall.png',
      bounds: SpriteBounds(left: 1, top: 3, right: 94, bottom: 93),
    ),
    '$_art/node/deep_hollow_thicket.png': StageScenery(
      assetPath: '$_art/node/deep_hollow_thicket.png',
      bounds: SpriteBounds(left: 1, top: 3, right: 94, bottom: 93),
    ),
  };

  /// The workstation kind a craft scene composes around, resolved from the
  /// recipe's authored `station` word with the profession as fallback
  /// (`RecipeDefinition.station` — an oak plank is bench work even though
  /// Smithing owns it). String keys for the same boundary reason as
  /// [activityLoopFor]: the caller passes `recipe.station?.name` and
  /// `skill.value`; this file names no `stride_core` type.
  static String craftStationKind(String? authored, String skill) =>
      authored ?? (skill == 'skill.cooking' ? 'cookfire' : 'forge');

  /// The work backdrop of a craft scene — the forge interior, the
  /// carpenter's bench room, the hearth — same 384 × 176 family as the
  /// profession work backdrops above (this pass, item 2). Null while a
  /// station has no authored scene; the stage then keeps its plain ground.
  static String? craftBackdropFor(String station) => _craftBackdrops[station];

  static const Map<String, String> _craftBackdrops = <String, String>{
    'forge': '$_art/work/bg_smithing.png',
    'woodbench': '$_art/work/bg_woodworking.png',
    'cookfire': '$_art/work/bg_cooking.png',
  };

  /// The craft station the Traveler works at, as stage scenery — the anvil,
  /// the bench, the cookfire (PRESENTATION_WORLD_REWARD_FEEL_01 §17; scene
  /// scale raised by the physical-device polish pass, item 2). Keyed by the
  /// station kind [craftStationKind] resolves. Null for a station with no
  /// authored prop, in which case the craft stage shows the figure alone.
  ///
  /// Same role the seam props play on the gathering stage: near art at the
  /// figure's own ground line, placed by `AmbientStageLayout`. Bounds
  /// measured by `Scripts/art/png.js` on the packaged props.
  static StageScenery? stationFor(String station) => _stations[station];

  /// The 96² Polish 02 stations. All three are tall enough to swallow a
  /// swung tool if drawn last, so they paint behind the figure and the
  /// hammer or spoon lands visibly on the working surface — the same
  /// blind-QA rule the seams and the oak trunk follow
  /// (`StageScenery.behindFigure`). The 64² `node/station_*.png` pair they
  /// supersede stays packaged as the exploration record.
  static const Map<String, StageScenery> _stations = <String, StageScenery>{
    'forge': StageScenery(
      assetPath: '$_art/work/station_forge.png',
      bounds: SpriteBounds(left: 6, top: 13, right: 89, bottom: 88),
      behindFigure: true,
    ),
    'woodbench': StageScenery(
      assetPath: '$_art/work/station_woodbench.png',
      bounds: SpriteBounds(left: 1, top: 4, right: 93, bottom: 93),
      behindFigure: true,
    ),
    'cookfire': StageScenery(
      assetPath: '$_art/work/station_cookfire.png',
      bounds: SpriteBounds(left: 5, top: 3, right: 89, bottom: 91),
      behindFigure: true,
    ),
  };

  /// Every scenery entry, for the composition test.
  static Iterable<StageScenery> get allScenery => _scenery.values;

  /// The region's ambient creature, keyed by the location's **vignette
  /// path** — the same key the stage already resolves, so a location cannot
  /// be wired into one table and forgotten in the other (Fable V2
  /// Iteration 02; Regional Content Pack 01 fauna).
  ///
  /// Stonefall Mine is deliberately absent: its 16 px bat was withheld by
  /// blind QA ("reads as a moth at ×2"), and no creature is more honest
  /// than a wrong one. The ptarmigan ships on its accepted stage-scale
  /// still; its QA note ("concept scale" on the 32) does not apply to it.
  static final Map<String, AmbientLayer> _faunaByVignette =
      <String, AmbientLayer>{
        '$_art/location/havens_rest.png': _faunaStill(
          'fauna_hare_16',
          _bFaunaHare,
          SpriteFootprints.ambientFaunaHare16,
        ),
        '$_art/location/whispering_woods.png': _faunaStill(
          'fauna_songbird_16',
          _bFaunaSongbird,
          SpriteFootprints.ambientFaunaSongbird16,
        ),
        '$_art/location/forgotten_hollow.png': _faunaStill(
          'fauna_crow_16',
          _bFaunaCrow,
          SpriteFootprints.ambientFaunaCrow16,
        ),
        '$_art/location/frostmere.png': _faunaStill(
          'fauna_ptarmigan_16',
          _bFaunaPtarmigan,
          SpriteFootprints.ambientFaunaPtarmigan16,
        ),
      };

  /// Every fauna variant scene set, for the composition test — the same
  /// geometry rules must hold with the creature standing in.
  static Iterable<AmbientSceneSet> get allFaunaSceneSets =>
      _faunaByVignette.keys.map(scenesFor);

  static final Map<String, AmbientSceneSet> _scenesByVignette =
      <String, AmbientSceneSet>{};

  /// The living-location scene set for [vignette]: the full table, with the
  /// region's creature standing at the stage's left edge in every **solo**
  /// scene. Companion scenes keep the cat — the left is the cat's room, and
  /// a hare beside a rolling cat is a zoo, not a location. A vignette with
  /// no shipped creature (Stonefall, an unknown pack) gets the plain table.
  static AmbientSceneSet scenesFor(String? vignette) {
    final AmbientLayer? fauna = vignette == null
        ? null
        : _faunaByVignette[vignette];
    if (fauna == null) return scenes;
    return _scenesByVignette.putIfAbsent(
      vignette!,
      () => AmbientSceneSet(<AmbientScene>[
        for (final AmbientScene s in scenes.scenes)
          // Solo scenes only, by the same predicate [soloScenes] filters
          // with: `pet_cat` carries its cat inside the combined 96-wide
          // sprite, not as a layer, and the fauna would stand in it.
          s.layers.isEmpty &&
                  !s.traveler.frames.any((String f) => f.contains('cat'))
              ? s.withExtraLayer(fauna)
              : s,
      ]),
    );
  }

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
      // Phasing (GAME_FEEL_CHARACTER_PRESENTATION_01 §3): the pass is
      // already cyclic — shoulders rolling out and back — so the whole
      // strip is the held loop.
      phasing: ScenePhasing.cyclic(frames: 4),
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
      phasing: ScenePhasing.cyclic(frames: 9, wrap: true),
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
      // The owner's finding, verbatim: "opens the book then closes it
      // immediately." Frames 0–4 take the book out; 5–8 are the reading
      // itself — held, page bobbing, for the drawn dwell; the reverse of
      // the intro puts the book away.
      phasing: const ScenePhasing(introEnd: 4, loopStart: 5, loopEnd: 8),
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
      // Micro-idle stand-in — see the class doc. The phasing applies only
      // to its plays as a **full** scene; a micro-idle beat stays short.
      idleWeight: 0.8,
      phasing: ScenePhasing.cyclic(frames: 6),
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
      phasing: ScenePhasing.cyclic(frames: 7, wrap: true),
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
      // "Pets the cat for a split second" — the owner's exact complaint.
      // 0–3 approach and crouch; 4–8 the stroking, held; 9–10 the strip's
      // own rise back to standing.
      phasing: const ScenePhasing(
        introEnd: 3,
        loopStart: 4,
        loopEnd: 8,
        outroStart: 9,
        outroEnd: 10,
      ),
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
      // The dangling string is cyclic — the cat keeps batting for as long
      // as the string hangs.
      phasing: ScenePhasing.cyclic(frames: 9),
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
      // Frame-inspected 2026-08-28: f0 standing, f3–f8 crouched stroking,
      // f10 standing again. The crouch holds; the strip's own end stands.
      phasing: const ScenePhasing(
        introEnd: 3,
        loopStart: 4,
        loopEnd: 8,
        outroStart: 9,
        outroEnd: 10,
      ),
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
      // "Sits by the fire briefly then leaves." 0–4 sitting down; 5–10 the
      // seated rest, held while the fire loops and the cat sleeps on
      // sustained tracks; sitting down reversed is standing up.
      phasing: const ScenePhasing(introEnd: 4, loopStart: 5, loopEnd: 10),
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
      phasing: ScenePhasing.cyclic(frames: 9),
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
      phasing: ScenePhasing.cyclic(frames: 9, wrap: true),
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
      phasing: ScenePhasing.cyclic(frames: 11),
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
      phasing: ScenePhasing.cyclic(frames: 4),
    ),
  ]);
}
