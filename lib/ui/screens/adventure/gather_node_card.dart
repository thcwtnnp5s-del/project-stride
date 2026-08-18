/// One gatherable node, its cost, and the action.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart'
    show ContentId, ResourceNodeDefinition, ToolKind;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/ambient_stage.dart';
import '../../components/data_display.dart';
import '../../components/pixel_asset.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../icons/ambient_assets.dart';
import '../../icons/pixel_icons.dart';
import '../../icons/sprite_footprints.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

class GatherNodeCard extends StatelessWidget {
  const GatherNodeCard({super.key, required this.node});

  final ResourceNodeDefinition node;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;

    final int cost = s.costOf(node.id) ?? node.stepCost;
    final String skillName = s.displayNameOf(node.skill);
    final String yieldName = s.displayNameOf(node.yieldsItem);

    final Widget identity = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SkillChip(skill: node.skill, label: skillName),
        const SizedBox(height: StrideSpace.s6),
        Text(node.displayName, style: StrideType.cardTitle, maxLines: 2),
        Text('Gathering $yieldName', style: StrideType.sub, maxLines: 2),
      ],
    );

    return SectionCard(
      padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The figure and what it is doing, side by side.
          //
          // The stage used to be a full-width band above the identity: a
          // 128 dp sprite centred in a ~330 dp box, so about 85% of the largest
          // rectangle on the screen was empty ground, and the node's name
          // arrived below it. Two objects, ~220 dp, one of them mostly nothing.
          //
          // Beside each other they are one object about 145 dp tall, and the
          // card now says "this figure, gathering this thing, here" in a single
          // read. The gathering presentation itself is unchanged — same sprite,
          // same contact shadow, same play-on-success token.
          _StageAndIdentity(node: node, identity: identity),

          const SizedBox(height: StrideSpace.s10),
          Wrap(
            spacing: StrideSpace.s6,
            runSpacing: StrideSpace.s6,
            children: <Widget>[
              RequirementGate(
                label: 'Requires $skillName ${node.requiredLevel}',
              ),
              RequirementGate(
                label: node.requiredToolKind == ToolKind.none
                    ? 'No tool needed'
                    : 'Needs a ${node.requiredToolKind.name}',
              ),
            ],
          ),

          // The `THIS ACTION` heading is gone. Three tiles labelled STEPS,
          // YIELD and EXPERIENCE, directly above a button that says
          // `Gather — 90 steps`, do not need a caption telling the player they
          // describe an action; it cost 28 dp between the player and the
          // control.
          const SizedBox(height: StrideSpace.s10),
          _CostTriple(
            node: node,
            cost: cost,
            yieldName: yieldName,
            skillName: skillName,
          ),

          // The `AVAILABLE 455,281` row that sat here is gone.
          //
          // It printed `s.usableEnergy` — the identical value the header prints
          // persistently, on this screen and every other, in accent teal at
          // 19 px. Three restatements of one number (header, the Your Walking
          // card's affordance sentence, and this row) is what made the card feel
          // like a form rather than an action, and the smallest of the three was
          // the one immediately above the button, competing with it.
          //
          // Nothing is lost: the shortfall case still names the exact number of
          // steps to walk, on the button itself, where the player is looking.
          const SizedBox(height: StrideSpace.s12),
          _GatherControl(node: node, cost: cost),
        ],
      ),
    );
  }
}

/// The stage beside the node's identity, or above it where the phone is too
/// narrow for both.
///
/// The threshold is **measured, not chosen**: the identity column needs enough
/// width for the node's own title, so the same `AdaptiveText.fitsWithin` the
/// title will use is asked first. A longer name from a future content pack, or
/// an enlarged text scale, drops it back to the stacked arrangement rather than
/// crushing the title.
///
/// ## Why the stage stays beside the identity, and what it costs
///
/// The owner's device review asked for two things that pull against each other:
/// **a stage generous enough to hold a future animation**, and **the gather
/// control still above the fold**. The arithmetic is worth writing down, because
/// the next person to grow either of them needs it.
///
/// A real iPhone at 852 dp gives the scroll view roughly **634 dp** once the
/// status inset (59), the header (61), the tab bar (64) and the home indicator
/// (34) are taken. The stack above the button spends:
///
/// ```text
/// vignette             176
/// walking band          70
/// gap                   10
/// card padding          12
/// STAGE                180   <-- StrideGeometry.activityStage
/// gap                   10
/// requirement gates     24
/// gap                   10
/// cost tiles            78
/// gap                   12
/// button                48
///                      ----
/// button bottom        630   against 634
/// ```
///
/// So the stage can be 180 **only because the identity sits beside it rather
/// than under it**. Stacking them adds the identity's ~94 dp and puts the button
/// 90 dp below the fold. That is what happens at 320 dp, where there is no room
/// for both — and it is the right trade there, because a crushed node title is
/// worse than a scroll.
///
/// The goldens flatter this by about 93 dp: `flutter test` supplies no insets,
/// so the button looks comfortably clear in an image and is 4 dp clear on a
/// phone. Judge it on the phone (`MISTAKES.md` M-06).
class _StageAndIdentity extends StatelessWidget {
  const _StageAndIdentity({required this.node, required this.identity});

  final ResourceNodeDefinition node;
  final Widget identity;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextStyle inherited = DefaultTextStyle.of(context).style;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double beside =
            constraints.maxWidth - _stageWidth - StrideSpace.s12;
        final bool sideBySide =
            beside > 0 &&
            AdaptiveText.fitsWithin(
              node.displayName,
              inherited.merge(StrideType.cardTitle),
              scaler,
              beside,
            );

        if (!sideBySide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _ActivityStage(node: node),
              const SizedBox(height: StrideSpace.s10),
              identity,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: StrideGeometry.activityStage,
              child: _ActivityStage(node: node),
            ),
            const SizedBox(width: StrideSpace.s12),
            Expanded(child: identity),
          ],
        );
      },
    );
  }

  /// The width the identity column is measured against.
  ///
  /// The stage's own edge plus the gap between them. Stated once so the
  /// fits-or-stacks decision and the box that decision is about cannot drift
  /// apart.
  static const double _stageWidth = StrideGeometry.activityStage;
}

/// The activity's contextual art: the Traveler, standing on ground, who gathers
/// once when a gather succeeds.
///
/// This is the ACTIVITY presentation scale — "UI-driven action plus contextual
/// art". It is deliberately **not** a scene the player moves through. There is
/// no terrain to cross, no position, and no camera; there is a figure performing
/// the action the button just executed.
///
/// ## It is a viewport, not a frame around a sprite
///
/// The box is [StrideGeometry.activityStage] square and the figure in it is
/// 128 dp. **That slack is the feature.** The composition pass sized this to the
/// rest pose plus padding, which was correct for the one animation that exists
/// and wrong for every one that does not yet: a gathering swing, a recoil, a
/// second combatant in a later milestone. The owner's device review asked for
/// the room back and asked for it to be held.
///
/// So the figure is **seated low rather than centred** — its feet near the
/// stage's floor, with the headroom above it. That is where an arc, a raised
/// tool, or a projectile goes, and it is also simply how a figure standing on
/// ground reads. Centring the sprite in a taller box would put the slack under
/// its feet, which reads as floating and gives the animation nothing.
///
/// **Do not shrink this to fit the current sprite.** If a future layout needs
/// the height back, the number and its cost are in
/// `StrideGeometry.activityStage` and in `_StageAndIdentity`'s own doc.
class _ActivityStage extends StatelessWidget {
  const _ActivityStage({required this.node});

  final ResourceNodeDefinition node;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);

    // The identity of a *successful* gather at this node, and nothing else. A
    // refusal leaves this null, so the figure does not mime picking a herb the
    // player did not receive.
    final ActionReport? report = c.lastActionNode == node.id
        ? c.lastAction
        : null;
    final Object? playToken = report != null && report.succeeded
        ? report
        : null;

    return Container(
      width: double.infinity,
      // A **minimum**, so the stage cannot be squeezed below the room the
      // animations need, and so an enlarged text scale grows the card around it
      // rather than cropping the figure.
      constraints: const BoxConstraints(
        minHeight: StrideGeometry.activityStage,
      ),
      padding: const EdgeInsets.symmetric(vertical: StrideSpace.s6),
      decoration: BoxDecoration(
        // `surfaceBlock`, deliberately, and NOT the darker `surfaceGround` the
        // inset wells use.
        //
        // The contact shadow multiplies against whatever is underneath, so the
        // figure darkens the ground it stands on rather than carrying a grey
        // patch that would be the same colour on any surface. That is the right
        // technique and it has one requirement: **there has to be something to
        // darken.** Against `surfaceGround` (#14120F) a 0.72 multiply moves the
        // pixels by about four values, and the first render of this stage
        // reproduced the exact failure the shadow spec was tuned to escape — a
        // shadow nobody could perceive.
        //
        // This is the same finding the blind reviewer made at strength 0.45,
        // arriving by a different route: there, the shadow was too weak; here,
        // the ground was too dark for any strength to show. Raising the
        // strength would have been the wrong fix, because the ellipse would
        // then be invisible here and far too heavy on the next surface.
        color: StrideColors.surfaceBlock,
        border: Border.all(color: StrideColors.borderDefault),
        borderRadius: StrideRadius.inner,
      ),
      // Bottom-aligned, not centred: the figure stands on the stage's floor and
      // the slack is headroom. See this class's doc — that is where a swing or
      // a raised tool goes, and slack under a standing figure reads as floating.
      //
      // Between gathers the stage is not empty: `AmbientStage` rotates the
      // Traveler through a few ambient scenes and settles back on the same
      // rest pose. Presentation only — the scenes grant nothing, read nothing,
      // and the gather still plays exactly on `playToken`, taking priority.
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          // The node itself — an oak stand, a copper seam — behind the figure
          // and to one side, so the stage reads "this figure, at this place".
          // Terrain art from PixelLab at ×1; the figure in front of it at ×2 is
          // the same near/far scale split the location vignettes already use.
          // Not a scene the player moves through: nothing here is a position.
          if (PixelIcons.nodeFor(node.id) case final String art)
            Positioned(
              right: StrideSpace.s6,
              bottom: 0,
              child: PixelAsset(
                assetPath: art,
                nativeWidth: 96,
                nativeHeight: 96,
                scale: 1,
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AmbientStage(
              gatherFrames: PixelIcons.gatherFrames,
              gatherFootprint: SpriteFootprints.gather,
              playToken: playToken,
              scenes: AmbientAssets.scenes,
              restFrame: AmbientAssets.restFrame,
              restFootprint: AmbientAssets.restFootprint,
            ),
          ),
        ],
      ),
    );
  }
}

/// `STEPS 90 → YIELD ×2 → EXPERIENCE +10`.
class _CostTriple extends StatelessWidget {
  const _CostTriple({
    required this.node,
    required this.cost,
    required this.yieldName,
    required this.skillName,
  });

  final ResourceNodeDefinition node;
  final int cost;
  final String yieldName;
  final String skillName;

  /// Three tiles, no arrows and no glyph — and both removals are measurements
  /// rather than taste.
  ///
  /// At 320 dp the card has 264 dp inside its padding. Two arrow glyphs at
  /// 24 dp plus their 8 dp of padding took **64 of it — a quarter of the card**
  /// — to decorate a sequence the three labels already state in order. What was
  /// left gave each tile 65 dp, and the leading walking glyph took 30 of the
  /// first tile's 45 dp of content, so `90` was drawn in 16 dp and needed 19.8.
  /// The step figure on the gather card was clipped on every 320 dp phone.
  ///
  /// Without them each tile has 82 dp and every value and label fits at full
  /// size. The walking glyph is not lost: it is on the header permanently and
  /// on the Your Walking card above, both of which have room for it.
  @override
  Widget build(BuildContext context) => ValueTileRow(
    tiles: <LabeledValueTile>[
      LabeledValueTile(
        label: 'Steps',
        value: formatSteps(cost),
        unit: 'per gather',
      ),
      LabeledValueTile(
        label: 'Yield',
        // Not scaled by the balance profile, unlike cost — there is no
        // `yieldOf` to match `costOf`. Under `profile.production` every
        // multiplier is 100 so this is exact; under an accelerated QA profile
        // it would under-report. Recorded as Q-UI-10, not silently ignored.
        value: '×${node.yieldsQuantity}',
        unit: yieldName,
      ),
      LabeledValueTile(
        label: 'Experience',
        value: '+${node.xp}',
        unit: '$skillName XP',
      ),
    ],
  );
}

// The `→` glyph that sat between the cost tiles is gone; `_CostTriple`'s own
// doc records the measurement. It was additionally positioned by `top: 24`, a
// constant that is correct at exactly one text scale — the label line, the gap
// and the value line above it all grow with the scaler — so it was a second
// instance of a number standing in for a measurement, on the vertical axis.
//
// `PixelIcons.arrowGlyph` is left in the asset set and the packaging script. It
// is not deleted here: whether the sequence arrow returns in some form is a
// visual-identity question for the owner, and removing the asset would make
// that decision on their behalf.

/// The button, and the ephemeral line beneath it.
class _GatherControl extends StatelessWidget {
  const _GatherControl({required this.node, required this.cost});

  final ResourceNodeDefinition node;
  final int cost;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;

    // `canGather` is a hint used to DISABLE, never to decide. It checks
    // affordability and readiness only — not location, skill level, or tool. The
    // engine re-validates all five on execute and its answer is authoritative,
    // so a refusal that arrives anyway is rendered rather than pre-empted.
    final bool affordable = s.canGather(node.id);
    final int shortfall = cost - s.usableEnergy;

    final ActionReport? report = c.lastActionNode == node.id
        ? c.lastAction
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StrideButton(
          label: c.busy ? 'Gathering…' : 'Gather — ${formatSteps(cost)} steps',
          subLabel: !c.busy && !affordable && shortfall > 0
              ? 'Walk ${formatSteps(shortfall)} more steps'
              : null,
          onPressed: c.busy || !affordable ? null : () => c.gather(node.id),
        ),
        if (report != null) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          _ResultStrip(report: report, skill: node.skill),
        ],
      ],
    );
  }
}

/// The result of the gather that just happened.
///
/// **Ephemeral by construction.** Every value comes from the `ActionReport` the
/// command just returned — not from state, not accumulated, not persisted. It
/// clears on a timer, on the next command, and on a tab change, because a result
/// line that persisted would be indistinguishable from the durable "recent
/// gains" system Phase 1 does not have.
class _ResultStrip extends StatelessWidget {
  const _ResultStrip({required this.report, required this.skill});

  final ActionReport report;

  /// The node's skill, for the hue only. The report carries the skill's display
  /// *name*, which is the right thing to print but cannot be mapped back to a
  /// content id — so the id comes from the node this card is already for, which
  /// is the same skill by construction.
  final ContentId skill;

  @override
  Widget build(BuildContext context) {
    if (!report.succeeded) {
      return Text(
        _refusalText(report),
        style: StrideType.micro.copyWith(color: StrideColors.textPrimary),
      );
    }

    final String item = report.itemName ?? 'items';
    final String qty = '${report.quantity ?? 0}';
    // Both from the report, which takes them from the ResourceGathered event.
    // Reading `node.xp` here would be the unscaled base value, and diffing skill
    // XP across the await would be widget arithmetic over durable state.
    final String? skillName = report.skillName;
    final int? xp = report.experience;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '$item ×$qty',
            style: StrideType.micro.copyWith(color: StrideColors.textPrimary),
          ),
        ),
        if (skillName != null && xp != null)
          Text(
            '+$xp $skillName XP',
            style: StrideType.micro.copyWith(
              color: StrideColors.forSkill(skill),
            ),
          ),
      ],
    );
  }

  static String _refusalText(ActionReport r) => switch (r.rejection) {
    'insufficient_steps' => 'Not enough banked steps yet',
    'session_busy' => 'Still finishing the last action',
    'session_not_ready' => 'Reload before gathering again',
    'commit_refused' => 'That could not be saved — reload before continuing',
    'skill_level_too_low' => 'Your skill level is too low here',
    'tool_required' => 'You need the right tool for this',
    'resource_node_not_here' => 'That is not available at this location',
    _ => r.detail ?? 'That action was refused',
  };
}
