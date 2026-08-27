/// The activity stage's composition, held to its rules for every scene × every
/// node vignette, with the same `AmbientStageLayout` the card draws with.
///
/// The owner's device review found the figure standing through the vignette,
/// the cat off the stage or on the tree, and props competing with the scenery
/// (`MILESTONES/TRANSFORMATION_BUILD_01.md` §8). The rules below are the fix
/// stated as arithmetic over **measured** extents — the union opaque boxes in
/// `ambient_assets.dart`, printed by `Scripts/art/measure-ambient-extents.js`
/// — so a re-authored offset or a new scene cannot quietly reintroduce any of
/// them. Pixels, not perception: whether the result *reads* right is judged on
/// the rendered stage (`MISTAKES.md` M-06), and this file only guarantees the
/// geometry the read depends on.
library;

import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:stride/ui/components/ambient_scene.dart';
import 'package:stride/ui/components/ambient_stage.dart';
import 'package:stride/ui/icons/ambient_assets.dart';
import 'package:stride/ui/theme/stride_metrics.dart';

/// The stage's interior at the reference card (393 dp: a 180 dp stage less its
/// border and vertical padding), and the widest stacked layout (a 320 dp phone
/// with the identity below the stage) so a wider stage is not assumed to be
/// easier.
const List<AmbientStageLayout> _layouts = <AmbientStageLayout>[
  AmbientStageLayout(
    width: StrideGeometry.activityStage - 2,
    height: StrideGeometry.activityStage - 2 * StrideSpace.s6 - 2,
  ),
  AmbientStageLayout(
    width: 296,
    height: StrideGeometry.activityStage - 2 * StrideSpace.s6 - 2,
  ),
];

/// The scenery's measured base must sit at least this far above the
/// Traveler's ground line, or the two read as sharing one ground.
const double _minRaise = 24;

/// At least this much of the scenery's opaque box stays clear of the standing
/// Traveler's (the rest pose and the gather swing, `restBounds`) — a vignette
/// mostly behind the figure is not scenery. Judged on the standing box, not
/// each scene's: a scene's union box spans its raised arms or its own cat,
/// and covering the vignette with a box is not covering it with a figure.
const double _minSceneryVisible = 0.5;

bool _inside(Rect inner, Rect outer) =>
    inner.left >= outer.left - 1e-6 &&
    inner.top >= outer.top - 1e-6 &&
    inner.right <= outer.right + 1e-6 &&
    inner.bottom <= outer.bottom + 1e-6;

double _area(Rect r) => r.isEmpty ? 0 : r.width * r.height;

void main() {
  final List<AmbientScene> scenes = AmbientAssets.scenes.scenes;
  final List<StageScenery> scenery = AmbientAssets.allScenery.toList();

  test('every scene and every node is measured, not defaulted', () {
    // A defaulted box is the whole canvas; the table must carry real numbers,
    // or every rule below is checking the frame edge rather than the art.
    for (final AmbientScene s in scenes) {
      expect(
        s.bounds.width < s.canvas || s.bounds.height < s.canvasHeight,
        isTrue,
        reason: '${s.id}: Traveler bounds are the whole canvas',
      );
      for (final AmbientLayer l in s.layers) {
        expect(
          l.bounds.width < l.canvas || l.bounds.height < l.canvas,
          isTrue,
          reason: '${s.id}: a layer\'s bounds are the whole canvas',
        );
      }
    }
    // 9 since PRESENTATION_WORLD_REWARD_FEEL_01 B-3 added the Hardened
    // Copper Seam; 12 since Fable V2 (`DECISIONS/0027`) added the three
    // Verge nodes as byte-copy plates; 17 since Iteration 03 added the five
    // depth nodes the same way; `node_art_resolution_test` holds the count
    // to the content pack, so this stays a plain census.
    expect(scenery, hasLength(17), reason: 'one entry per node vignette');
  });

  test(
    'every scene the player can draw is one of the scenes measured here',
    () {
      // The idle cadence has two pools, and both are derived from the one table
      // above — a micro-idle is a scene, held to every rule below like any
      // other. This is the assertion that keeps it that way: a pool assembled
      // anywhere else would put frames on the stage that nothing has measured.
      final Set<String> measured = scenes.map((AmbientScene s) => s.id).toSet();
      for (final AmbientSceneSet pool in <AmbientSceneSet>[
        AmbientAssets.scenes.visitScenes,
        AmbientAssets.scenes.microIdles,
      ]) {
        for (final AmbientScene s in pool.scenes) {
          expect(
            measured,
            contains(s.id),
            reason: '${s.id} is not in the table',
          );
        }
      }
      expect(
        AmbientAssets.scenes.microIdles.isEmpty,
        isFalse,
        reason: 'with no pool the cadence idles on full scenes',
      );
      expect(
        AmbientAssets.scenes.visitScenes.isEmpty,
        isFalse,
        reason: 'a visit needs scenes that are not idle-only',
      );
    },
  );

  for (final AmbientStageLayout layout in _layouts) {
    group('stage ${layout.width.toInt()} × ${layout.height.toInt()}', () {
      test('the 64-box and its ground line are on the stage', () {
        expect(_inside(layout.groupRect, layout.stageRect), isTrue);
        expect(
          _inside(layout.placed(AmbientAssets.restBounds), layout.stageRect),
          isTrue,
        );
        expect(layout.groundLine, lessThanOrEqualTo(layout.height));
      });

      for (final StageScenery n in scenery) {
        test('${n.assetPath.split('/').last}: raised, on stage, visible', () {
          final Rect node = layout.sceneryOpaque(n);
          expect(
            _inside(node, layout.stageRect),
            isTrue,
            reason: 'scenery $node leaves the stage',
          );
          expect(
            node.bottom,
            lessThanOrEqualTo(layout.groundLine - _minRaise),
            reason:
                'scenery base ${node.bottom} is not raised off the ground '
                'line ${layout.groundLine}',
          );
          final Rect standing = layout.placed(AmbientAssets.restBounds);
          expect(
            1 - _area(standing.intersect(node)) / _area(node),
            greaterThanOrEqualTo(_minSceneryVisible),
            reason: 'the standing Traveler covers too much of the scenery',
          );
        });
      }

      for (final AmbientScene s in scenes) {
        test('${s.id}: figures stay on the stage and apart as authored', () {
          final Rect traveler = layout.placed(s.travelerBounds);
          expect(
            _inside(traveler, layout.stageRect),
            isTrue,
            reason: 'Traveler $traveler leaves ${layout.stageRect}',
          );
          for (final AmbientLayer l in s.layers) {
            final Rect box = layout.placed(l.placedBounds);
            expect(
              _inside(box, layout.stageRect),
              isTrue,
              reason: 'layer ${l.track.frames.first} $box leaves the stage',
            );
            final int intrusion = l.placedBounds.overlapY(s.travelerBounds) > 0
                ? l.placedBounds.overlapX(s.travelerBounds)
                : 0;
            expect(
              intrusion,
              lessThanOrEqualTo(s.companionAllowance),
              reason:
                  'layer ${l.track.frames.first} reaches $intrusion px into '
                  'the Traveler; the scene allows ${s.companionAllowance}',
            );
          }
        });

        if (s.layers.isEmpty) continue;
        for (final StageScenery n in scenery) {
          test('${s.id} at ${n.assetPath.split('/').last}', () {
            final Rect node = layout.sceneryOpaque(n);
            for (final AmbientLayer l in s.layers) {
              final Rect box = layout.placed(l.placedBounds);
              expect(
                box.overlaps(node),
                isFalse,
                reason:
                    'layer ${l.track.frames.first} $box lands on the '
                    'scenery $node',
              );
            }
          });
        }
      }

      // The fauna variants (Fable V2 Iteration 02): every region's creature,
      // standing into every scene `scenesFor` composes it into, held to the
      // same three rules as an authored layer — on the stage, out of the
      // Traveler beyond the scene's allowance, and off every node's scenery.
      // One test per layout rather than per combination: the placements are
      // four constants, and a failure names its scene.
      test('every fauna variant keeps to the same composition rules', () {
        for (final AmbientSceneSet set in AmbientAssets.allFaunaSceneSets) {
          for (final AmbientScene s in set.scenes) {
            for (final AmbientLayer l in s.layers) {
              final Rect box = layout.placed(l.placedBounds);
              expect(
                _inside(box, layout.stageRect),
                isTrue,
                reason:
                    '${s.id}: layer ${l.track.frames.first} $box leaves '
                    'the stage',
              );
              final int intrusion =
                  l.placedBounds.overlapY(s.travelerBounds) > 0
                  ? l.placedBounds.overlapX(s.travelerBounds)
                  : 0;
              expect(
                intrusion,
                lessThanOrEqualTo(s.companionAllowance),
                reason:
                    '${s.id}: layer ${l.track.frames.first} reaches '
                    '$intrusion px into the Traveler',
              );
              for (final StageScenery n in scenery) {
                expect(
                  box.overlaps(layout.sceneryOpaque(n)),
                  isFalse,
                  reason:
                      '${s.id}: layer ${l.track.frames.first} lands on '
                      '${n.assetPath.split('/').last}',
                );
              }
            }
          }
        }
      });
    });
  }
}
