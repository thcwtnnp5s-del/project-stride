/// The location activity stage — one living diorama per location, in place of
/// a Traveler repeated inside every resource card.
///
/// ## What this replaces (PRESENTATION_WORLD_REWARD_FEEL_01 §4–§5)
///
/// The owner's device review found every gather card carrying its own 180 dp
/// stage with its own copy of the Traveler — "Copper Seam card has Traveler,
/// Tin Seam card has Traveler" — the busiest and most redundant thing on the
/// screen. This widget is the one stage: the location vignette is its
/// backdrop, the Traveler (and companions) live on its floor, the *selected*
/// activity's node vignette stands as its far scenery, and the profession's
/// working loop plays while a queue runs. Idle, the ambient cadence keeps the
/// figure alive exactly as the per-card stage did.
///
/// ## What it deliberately is not
///
/// Not a scene engine. It is the existing [AmbientStage] composition — one
/// model, measured offsets, the composition test — placed once, over the
/// arrival vignette instead of beside it. There is no camera, no position,
/// and nothing tappable on the picture; selection happens in the activity
/// list below (`activity_panel.dart`).
///
/// Everything here is presentation over reports and projections. Nothing
/// reads the domain directly and nothing holds durable state (`RULES.md`
/// E-2).
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ResourceNodeDefinition;

import '../../components/ambient_stage.dart';
import '../../components/pixel_asset.dart';
import '../../icons/ambient_assets.dart';
import '../../icons/pixel_icons.dart';
import '../../icons/sprite_footprints.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

class LocationStage extends StatelessWidget {
  const LocationStage({
    super.key,
    required this.locationName,
    required this.vignette,
    required this.selectedNode,
    required this.activityActive,
    required this.playToken,
  });

  /// The location's display name, captioned over the lower edge exactly as
  /// the plain arrival vignette was.
  final String locationName;

  /// The location's arrival vignette asset, or null when the pack has none —
  /// the stage then stands on the app ground the per-card stage used.
  final String? vignette;

  /// The activity the player has selected in the list below, or null when
  /// idle. Selection swaps the node's vignette onto the stage as far scenery;
  /// it never starts anything.
  final ResourceNodeDefinition? selectedNode;

  /// True while the durable queue works [selectedNode]: the stage loops the
  /// profession's working animation instead of the ambient cadence.
  final bool activityActive;

  /// The identity of a successful single gather at [selectedNode] — plays the
  /// one-shot exactly as the per-card stage did. Null plays nothing.
  final Object? playToken;

  /// The stage band's height: the vignette's native rows. The figures stand
  /// on its lower edge, which every location vignette frames as ground
  /// (`Scripts/art/package-art.js` frames them once, reviewably).
  static const double height = 176;

  @override
  Widget build(BuildContext context) {
    final ResourceNodeDefinition? node = selectedNode;
    final String? skill = node?.skill.value;

    final Widget figures = AmbientStage(
      gatherFrames: PixelIcons.gatherFrames,
      gatherFootprint: SpriteFootprints.gather,
      playToken: playToken,
      scenes: AmbientAssets.scenes,
      restFrame: AmbientAssets.restFrame,
      restFootprint: AmbientAssets.restFootprint,
      scenery: node == null
          ? null
          : AmbientAssets.sceneryFor(PixelIcons.nodeFor(node.id)),
      activityFrames: skill == null
          ? null
          : AmbientAssets.activityLoopFor(skill),
      activityFootprint: skill == null
          ? null
          : AmbientAssets.activityFootprintFor(skill),
      activityCanvas: skill == null
          ? 64
          : AmbientAssets.activityCanvasFor(skill),
      activityActive: activityActive,
    );

    return ClipRect(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // The backdrop: the arrival painting, or the stage ground the
            // per-card stage stood on where a location has no vignette.
            if (vignette case final String art)
              PixelScene.vignette(art, viewportHeight: height)
            else
              const ColoredBox(color: StrideColors.surfaceBlock),

            // The figures' ground band. The multiply contact shadow needs
            // something to darken and the painted vignettes are busy at
            // their lower edge, so a quiet gradient settles the floor the
            // figures stand on without cutting the picture with a line.
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0x0014120F), Color(0x8014120F)],
                  ),
                ),
              ),
            ),

            // The stage proper: scenery + figures, bottom-anchored, the same
            // composition model the per-card stage used
            // (`AmbientStageLayout`, `test/ambient_composition_test`).
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              height: _stageHeight,
              child: figures,
            ),

            // The name, over the lower edge, exactly as the plain vignette
            // captioned it — beside the figures rather than under a second
            // gradient of its own.
            Positioned(
              left: StrideSpace.screenGutter,
              bottom: StrideSpace.s8,
              child: Text(
                locationName,
                style: StrideType.cardTitle,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The figures' box: the 64-row sprite plus shadow bleed at ×2, the same
  /// interior the per-card stage reserved.
  static const double _stageHeight = 140;
}
