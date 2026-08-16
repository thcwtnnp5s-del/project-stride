/// One gatherable node, its cost, and the action.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart'
    show ContentId, ResourceNodeDefinition, ToolKind;

import '../../../runtime/stride_session.dart';
import '../../components/data_display.dart';
import '../../components/pixel_asset.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../components/walking_glyph.dart';
import '../../icons/pixel_icons.dart';
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
    final String? illustration = PixelIcons.activityFor(node.id);
    final String skillName = s.displayNameOf(node.skill);
    final String yieldName = s.displayNameOf(node.yieldsItem);

    return SectionCard(
      padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (illustration != null) ...<Widget>[
                InsetWell.square(
                  contentSize: 80,
                  child: PixelAsset.activity(illustration),
                ),
                const SizedBox(width: StrideSpace.s12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SkillChip(skill: node.skill, label: skillName),
                    const SizedBox(height: StrideSpace.s6),
                    Text(
                      node.displayName,
                      style: StrideType.cardTitle,
                      maxLines: 2,
                    ),
                    Text(
                      'Gathering $yieldName',
                      style: StrideType.sub,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),

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

          const SizedBox(height: StrideSpace.s12),
          const SectionHeading(label: 'This action'),
          const SizedBox(height: StrideSpace.s8),
          _CostTriple(
            node: node,
            cost: cost,
            yieldName: yieldName,
            skillName: skillName,
          ),

          const SizedBox(height: StrideSpace.s10),
          Row(
            children: <Widget>[
              const WalkingGlyph(role: WalkingRole.stock),
              const SizedBox(width: StrideSpace.iconLabelGap),
              Text('AVAILABLE', style: StrideType.microLabel),
              const SizedBox(width: StrideSpace.s6),
              Expanded(
                child: Text(
                  formatSteps(s.usableEnergy),
                  style: StrideType.micro.copyWith(
                    color: StrideColors.accentSteps,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: StrideSpace.s10),
          _GatherControl(node: node, cost: cost),
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

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(
        child: LabeledValueTile(
          label: 'Steps',
          value: formatSteps(cost),
          unit: 'per gather',
          // Muted: this is a price, not steps the player owns.
          leading: const WalkingGlyph(role: WalkingRole.unit),
        ),
      ),
      const _Arrow(),
      Expanded(
        child: LabeledValueTile(
          label: 'Yield',
          // Not scaled by the balance profile, unlike cost — there is no
          // `yieldOf` to match `costOf`. Under `profile.production` every
          // multiplier is 100 so this is exact; under an accelerated QA profile
          // it would under-report. Recorded as Q-UI-10, not silently ignored.
          value: '×${node.yieldsQuantity}',
          unit: yieldName,
        ),
      ),
      const _Arrow(),
      Expanded(
        child: LabeledValueTile(
          label: 'Experience',
          value: '+${node.xp}',
          unit: '$skillName XP',
        ),
      ),
    ],
  );
}

class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: StrideSpace.s4),
    child: Padding(
      padding: EdgeInsets.only(top: 24),
      child: PixelAsset.glyph(PixelIcons.arrowGlyph),
    ),
  );
}

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
