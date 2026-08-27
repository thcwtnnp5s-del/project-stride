/// The location activity stage — one diorama per location, in two modes.
///
/// ## What this replaces (PRESENTATION_WORLD_REWARD_FEEL_01 §4–§5)
///
/// The owner's first device review found every gather card carrying its own
/// 180 dp stage with its own copy of the Traveler — "Copper Seam card has
/// Traveler, Tin Seam card has Traveler" — the busiest and most redundant
/// thing on the screen. This widget is the one stage.
///
/// ## The two modes, and why the first version needed them (§2–§3)
///
/// The second device review found the shared stage right in principle and
/// wrong in composition: **the idle composition was being reused literally as
/// the work composition.** At Stonefall the full mine painting, the Traveler,
/// the cat and a 96 px ore boulder all competed inside one 176 dp band, the
/// boulder pasted against the far-left edge of a scene laid out for the
/// Traveler and his cat, and nothing in the picture said what the Traveler
/// was physically working on.
///
/// So the stage now answers two different questions with two compositions:
///
/// **LOCATION MODE** — nothing selected. The full arrival painting, the
/// Traveler, the cat, the whole idle cadence. A pleasant living place, and
/// deliberately *no* resource prop: a place is not a job.
///
/// **WORK MODE** — an activity is selected. The backdrop tightens to the
/// profession's own work scene where one is authored and dims the location
/// painting where it is not; the resource stands on the Traveler's own ground
/// line immediately in front of him, where his tool lands; the companion
/// scenes drop out, so the cat is not underfoot at a rock face; and the
/// caption names the work rather than the place. Running the queue swaps the
/// rest pose for the profession's working loop.
///
/// ## Families, not scenes per node (§4)
///
/// There is no route, no widget and no authored scene per ore, tree or herb.
/// One composition per profession, with the resource object swapped in by
/// node — `AmbientAssets.workPropFor` — so Copper, Tin and Hardened Copper
/// are three props in one mining scene. Everything modular is data; the code
/// is the same for all nine nodes in the pack.
///
/// ## What it deliberately is not
///
/// Not a scene engine. It is the existing [AmbientStage] composition — one
/// model, measured offsets, the composition test — with the near-prop slot
/// the craft screen needed first. There is no camera, no position, and
/// nothing tappable on the picture; selection happens in the activity list
/// below (`activity_panel.dart`).
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
import '../../components/data_display.dart';

class LocationStage extends StatelessWidget {
  const LocationStage({
    super.key,
    required this.locationName,
    required this.vignette,
    required this.selectedNode,
    required this.activityActive,
    required this.playToken,
    this.locked = false,
    this.lockReason,
    this.onActivityBeat,
    this.onGatherCue,
  });

  /// The audio layer's action beats, passed through to [AmbientStage]:
  /// the working loop crossing its strike frame, and the one-shot gather
  /// beginning. Presentation wiring only — see the stage's own contract.
  final VoidCallback? onActivityBeat;
  final VoidCallback? onGatherCue;

  /// True when [selectedNode] cannot be worked yet — skill too low, tool not
  /// equipped. The scene still composes (the player is looking at the seam),
  /// but the working loop is never played and the resource is held back.
  final bool locked;

  /// The one-line reason the selection is locked, shown on the stage.
  final String? lockReason;

  /// Shadow over a locked selection's scene: enough to say "not yet", not so
  /// much that the seam disappears.
  static const Color _lockedScrim = Color(0x5A14120F);

  /// The location's display name, captioned over the lower edge in location
  /// mode. Work mode captions the activity instead.
  final String locationName;

  /// The location's arrival vignette asset, or null when the pack has none —
  /// the stage then stands on the app ground the per-card stage used.
  final String? vignette;

  /// The activity the player has selected in the list below, or null. This is
  /// the mode switch: selecting composes the work scene, and it still starts
  /// nothing.
  final ResourceNodeDefinition? selectedNode;

  /// True while the durable queue works [selectedNode]: the stage loops the
  /// profession's working animation instead of standing at the work face.
  final bool activityActive;

  /// The identity of a successful single gather at [selectedNode] — plays the
  /// one-shot exactly as the per-card stage did. Null plays nothing.
  final Object? playToken;

  /// The stage band's height: the vignette's native rows. The figures stand
  /// on its lower edge, which every location vignette frames as ground
  /// (`Scripts/art/package-art.js` frames them once, reviewably).
  static const double height = 176;

  /// The scrim that pushes the location painting back under a work scene when
  /// the profession has no backdrop of its own. Enough that the figure and
  /// the thing he is working on carry the frame; not so much that the player
  /// loses track of where they are.
  static const Color _backdropScrim = Color(0x8C14120F);

  @override
  Widget build(BuildContext context) {
    final ResourceNodeDefinition? node = selectedNode;
    final bool working = node != null;
    final String? skill = node?.skill.value;
    final String? nodeArt = node == null ? null : PixelIcons.nodeFor(node.id);

    // The resource, near, at the point the tool reaches. Falls back to the
    // node's far vignette where no work prop is authored — worse, and never
    // blank; `node_art_resolution_test` holds every node to having one or the
    // other.
    final StageScenery? prop = !working
        ? null
        : AmbientAssets.workPropFor(nodeArt ?? '') ??
              AmbientAssets.sceneryFor(nodeArt);

    final String? workBackdrop = skill == null
        ? null
        : AmbientAssets.workBackdropFor(skill);

    final Widget figures = AmbientStage(
      gatherFrames: PixelIcons.gatherFrames,
      gatherFootprint: SpriteFootprints.gather,
      playToken: playToken,
      // Work mode drops the companion scenes — the cat is a companion, not a
      // fixture, and a rock face is not where it sits (§6). The living
      // location composes the region's creature in (Fable V2 Iteration 02):
      // a hare at Haven, a songbird in the Woods — same key the backdrop
      // resolves by, so the two cannot disagree about where we are.
      scenes: working
          ? AmbientAssets.soloScenes
          : AmbientAssets.scenesFor(vignette),
      restFrame: AmbientAssets.restFrame,
      restFootprint: AmbientAssets.restFootprint,
      // The far scenery slot stays empty in both modes now. It is the slot
      // that put the ore boulder against the left edge of a scene composed
      // for the Traveler and his cat; the resource belongs in `prop`, on the
      // figure's own ground line.
      prop: prop,
      propEast: skill != null && AmbientAssets.worksEast(skill),
      activityFrames: skill == null
          ? null
          : AmbientAssets.activityLoopFor(skill),
      activityFootprint: skill == null
          ? null
          : AmbientAssets.activityFootprintFor(skill),
      activityCanvas: skill == null
          ? 64
          : AmbientAssets.activityCanvasFor(skill),
      // A locked selection never works, whatever the queue says — and the
      // queue cannot say anything, because the control that starts it is
      // disabled on the same projection. Defence in depth, not a second rule.
      activityActive: activityActive && !locked,
      activityStrikeFrame: skill == null
          ? 0
          : AmbientAssets.strikeFrameFor(skill),
      onActivityBeat: onActivityBeat,
      onGatherCue: onGatherCue,
    );

    return ClipRect(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // The backdrop. Work mode prefers the profession's own tighter
            // scene; where there is none it pushes the location painting back
            // rather than competing with it.
            if (working && workBackdrop != null)
              PixelScene.vignette(workBackdrop, viewportHeight: height)
            else if (vignette case final String art) ...<Widget>[
              PixelScene.vignette(art, viewportHeight: height),
              if (working) const ColoredBox(color: _backdropScrim),
            ] else
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

            // The stage proper: figures + near prop, bottom-anchored, the
            // same composition model the per-card stage used
            // (`AmbientStageLayout`, `test/ambient_composition_test`).
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              height: _stageHeight,
              child: figures,
            ),

            // No caption (PLAYABLE_EXPERIENCE_REFINEMENT_01 §5). The
            // card-title overlay — `COPPER SEAM`, `MEADOW PATCH` — competed
            // with the art and read as a debug label on the device; the place
            // is named in the header's eyebrow and the selected activity in
            // the row beneath, so the painting is left to breathe.

            // The locked selection (§8): the scene is composed — the player
            // asked to look at this seam — but nothing can begin, so the
            // resource sits back in shadow and the one fact that gates it is
            // said on the picture, quietly, where the work would happen.
            if (working && locked) ...<Widget>[
              const ColoredBox(color: _lockedScrim),
              if (lockReason case final String reason)
                Positioned(
                  right: StrideSpace.screenGutter,
                  bottom: StrideSpace.s8,
                  child: RequirementGate(label: reason, unmet: true),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// The figures' box: the 64-row sprite plus shadow bleed at ×2, the same
  /// interior the per-card stage reserved.
  static const double _stageHeight = 140;
}
