/// The three-line tracked-goal summary Adventure keeps, now that the full
/// planning surface lives on the Goal Board (PRESENTATION_WORLD_REWARD_FEEL_01
/// §9).
///
/// One line per filled slot — the goal's name and the single most useful
/// figure — and one button. The full tracker with its per-line material
/// breakdowns, sources and clear controls is the Goal Board's overview tab;
/// Adventure answers "what am I working toward" in three glances and nothing
/// more (§44: tertiary information does not live on every Adventure card).
library;

import 'package:flutter/widgets.dart';

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import 'goal_board_screen.dart';

class GoalSummaryCard extends StatelessWidget {
  const GoalSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final TrackedGoalsView goals = c.session.trackedGoals;
    final bool empty =
        goals.journey == null && goals.pursuit == null &&
        goals.contract == null;

    return SectionCard(
      padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(label: 'Current goals'),
          const SizedBox(height: StrideSpace.s6),
          if (empty)
            Text(
              'Nothing tracked yet.',
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            )
          else ...<Widget>[
            if (goals.journey case final JourneyGoalView j)
              _SummaryLine(
                label: 'JOURNEY',
                name: j.destinationName,
                status: _journeyStatus(j),
                emphasised: j.ready && !j.arrived,
              ),
            if (goals.pursuit case final PursuitGoalView p)
              _SummaryLine(
                label: 'PURSUIT',
                name: p.itemName,
                status: _pursuitStatus(p),
                emphasised: p.owned ||
                    (!p.owned && p.needs.isEmpty),
              ),
            if (goals.contract case final ContractGoalView k)
              _SummaryLine(
                label: 'CONTRACT',
                name: k.name,
                status: _contractStatus(k),
                emphasised: k.readyToAdvance && !k.complete,
              ),
          ],
          const SizedBox(height: StrideSpace.s8),
          StrideButton(
            label: 'Goal Board',
            onPressed: () => GoalBoardScreen.open(context),
          ),
        ],
      ),
    );
  }

  static String _journeyStatus(JourneyGoalView j) {
    if (j.arrived) return 'you are here';
    if (j.totalCost == null) return 'no known route';
    if (j.ready) return 'READY';
    return '${formatSteps(j.shortfall ?? 0)} more steps';
  }

  static String _pursuitStatus(PursuitGoalView p) {
    if (p.owned) return 'in hand';
    if (p.needs.isEmpty) return 'ready to craft';
    return 'needs ${p.needs.map((PursuitNeedView n) => '${n.quantity} ${n.name}').join(', ')}';
  }

  static String _contractStatus(ContractGoalView k) {
    if (k.complete) return 'complete';
    if (k.readyToAdvance) return 'ready to deliver';
    final PursuitLineView? first = k.lines
        .where((PursuitLineView l) => !l.satisfied)
        .firstOrNull;
    if (first == null) return 'in progress';
    return '${first.name} ${first.held} / ${first.required}';
  }
}

/// `JOURNEY  Frostmere — READY`, one line, the figure in the accent only when
/// it is the "go now" state.
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.name,
    required this.status,
    required this.emphasised,
  });

  final String label;
  final String name;
  final String status;
  final bool emphasised;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: StrideSpace.s4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        SizedBox(
          width: 76,
          child: Text(label, style: StrideType.microLabel),
        ),
        Expanded(
          child: AdaptiveText(
            '$name — $status',
            style: StrideType.sub,
            color: emphasised
                ? StrideColors.accentSteps
                : StrideColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}
