/// The ambient scene table: which frames make which scene.
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
/// in the *scene frame's* pixel coordinates.
///
/// Cat frames are 40 × 40 with the feet on row 27, so a cat standing on the
/// Traveler's ground row has `dy = 62 − 27 = 35`. The fire is 32 × 32 with its
/// base on row 28 (`dy = 34`).
///
/// ## What this is not
///
/// A pet system, a fire system, or a rest system. Nothing here has state, and
/// nothing outside `AmbientPlayer` reads it (`ambient_scene.dart`).
library;

import '../components/ambient_scene.dart';
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
  dx: dx,
  dy: _catDy,
);

/// Withheld after independent Visual QA at play scale (TRANSFORMATION_01/
/// ambient/README.md, 2026-08-17): `traveler_axe_inspect` (the pale head reads
/// as a sheet of paper), `traveler_pick_inspect` (a raised pick reads as
/// "about to mine" — an idle that looks like the gather action) and
/// `traveler_read` (no book perceptible at ×2). The frames stay packaged; the
/// scenes are simply not in the rotation until a PixelLab correction round.
abstract final class AmbientAssets {
  /// The frame the Traveler rests on between scenes and after a visit. The
  /// gather rest pose, so ambient → gather → ambient has no visual pop: every
  /// transition passes through the same standing figure.
  static const String restFrame = '$_art/anim/gather_f0.png';
  static const SpriteFootprint restFootprint = SpriteFootprints.gather;

  static final AmbientSceneSet scenes = AmbientSceneSet(<AmbientScene>[
    // ---------------------------------------------------------- solo scenes
    AmbientScene(
      id: 'stretch',
      traveler: AmbientTrack(
        frames: _frames('traveler_stretch', 6),
        fps: 6,
        loop: AmbientLoop.pingpong,
        repeats: 2,
      ),
      footprint: SpriteFootprints.ambientTravelerStretch,
      canvas: 80,
    ),
    AmbientScene(
      id: 'drink',
      traveler: AmbientTrack(
        frames: _frames('traveler_drink', 9),
        fps: 8,
        repeats: 2,
      ),
      footprint: SpriteFootprints.ambientTravelerDrink,
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
    ),
    AmbientScene(
      id: 'wipe_brow',
      traveler: AmbientTrack(
        frames: _frames('traveler_wipe_brow', 7),
        fps: 7,
        repeats: 2,
      ),
      footprint: SpriteFootprints.ambientTravelerWipeBrow,
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
      footprint: const SpriteFootprint(left: 51, right: 74, bottom: 62),
      canvas: 96,
      anchorX: 32,
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
      layers: <AmbientLayer>[
        // The string end hangs at x ≈ 0–3; the cat bats at it from the left.
        AmbientLayer(
          track: _cat('cat_bat_yarn', 8, 8),
          canvas: 40,
          footprint: SpriteFootprints.ambientCatBatYarn,
          dx: -20,
          dy: _catDy,
        ),
      ],
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
      // The hand reaches to x ≈ 14–18; the cat sits under it, viewer-left.
      layers: <AmbientLayer>[_catSitsAt(-8)],
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
      layers: <AmbientLayer>[
        AmbientLayer(
          track: _cat('prop_fire', 4, 6, repeats: 8),
          canvas: 32,
          footprint: SpriteFootprints.ambientPropFire,
          dx: -24,
          dy: _fireDy,
        ),
        AmbientLayer(
          track: _cat('cat_lie_rest', 4, 3, repeats: 4),
          canvas: 40,
          footprint: SpriteFootprints.ambientCatLieRest,
          dx: 42,
          dy: _catDy,
        ),
      ],
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
      layers: <AmbientLayer>[
        AmbientLayer(
          track: _cat('cat_roll', 9, 7, loop: AmbientLoop.pingpong, repeats: 2),
          canvas: 40,
          footprint: SpriteFootprints.ambientCatRoll,
          dx: 44,
          dy: _catDy,
        ),
      ],
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
      layers: <AmbientLayer>[
        // The plank spans the frame; the cat sits off to the left, watching.
        AmbientLayer(
          track: _cat('cat_settle', 7, 5, loop: AmbientLoop.once),
          canvas: 40,
          footprint: SpriteFootprints.ambientCatSettle,
          dx: -22,
          dy: _catDy,
        ),
      ],
    ),
    AmbientScene(
      id: 'stretch_with_cat',
      traveler: AmbientTrack(
        frames: _frames('traveler_stretch', 6),
        fps: 6,
        loop: AmbientLoop.pingpong,
        repeats: 2,
      ),
      footprint: SpriteFootprints.ambientTravelerStretch,
      canvas: 80,
      layers: <AmbientLayer>[
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
          dx: 56,
          dy: _catDy,
        ),
      ],
      weight: 0.8,
    ),
  ]);
}
