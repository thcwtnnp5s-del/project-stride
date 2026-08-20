/// The three tracked-objective slots: Journey, Pursuit, Contract
/// (`DECISIONS/0023` §1).
///
/// Informative, never escrow: every figure is a live projection against the
/// current bank and bag, a Journey reserves nothing, and clearing a slot
/// changes no economy figure. The card's whole job is the owner's sentence —
/// "I'm only about 1,400 steps away from what I want."
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show GoalSlot;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

class GoalTrackerCard extends StatelessWidget {
  const GoalTrackerCard({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final TrackedGoalsView goals = c.session.trackedGoals;

    // Nothing tracked yet: one line, not three empty slots. The full card is
    // ~180 dp of hints, and on a 390 dp phone that alone pushes the gather
    // control — the screen's primary action — below the fold
    // (`test/fold_clearance_test.dart`). A player who tracks a goal has asked
    // for the taller card; a fresh save has not.
    if (goals.journey == null &&
        goals.pursuit == null &&
        goals.contract == null) {
      return const SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeading(label: 'Goals'),
            SizedBox(height: StrideSpace.s4),
            Text(
              'Nothing tracked. Set a journey on the atlas, a pursuit from '
              'the Craft screen, or a contract from a location board.',
              style: StrideType.micro,
            ),
          ],
        ),
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(label: 'Goals'),
          const SizedBox(height: StrideSpace.s6),
          _SlotRow(
            label: 'JOURNEY',
            slot: GoalSlot.journey,
            controller: c,
            filled: goals.journey != null,
            child: goals.journey == null
                ? const _EmptySlot(
                    hint: 'Choose a destination on the World atlas.',
                  )
                : _JourneyBody(view: goals.journey!),
          ),
          const _SlotRule(),
          _SlotRow(
            label: 'PURSUIT',
            slot: GoalSlot.pursuit,
            controller: c,
            filled: goals.pursuit != null,
            child: goals.pursuit == null
                ? const _EmptySlot(hint: 'Track an item from the Craft screen.')
                : _PursuitBody(view: goals.pursuit!),
          ),
          const _SlotRule(),
          _SlotRow(
            label: 'CONTRACT',
            slot: GoalSlot.contract,
            controller: c,
            filled: goals.contract != null,
            child: goals.contract == null
                ? const _EmptySlot(hint: 'Track work from a location board.')
                : _ContractBody(view: goals.contract!),
          ),
        ],
      ),
    );
  }
}

class _SlotRule extends StatelessWidget {
  const _SlotRule();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: StrideSpace.s8),
    height: 1,
    color: StrideColors.separator,
  );
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.label,
    required this.slot,
    required this.controller,
    required this.filled,
    required this.child,
  });

  final String label;
  final GoalSlot slot;
  final SessionController controller;
  final bool filled;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(child: Text(label, style: StrideType.microLabel)),
          if (filled)
            Semantics(
              button: true,
              label: 'Stop tracking $label',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: controller.busy
                    ? null
                    : () => controller.trackGoal(slot, null),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StrideSpace.s6,
                  ),
                  child: Text(
                    'CLEAR',
                    style: StrideType.microLabel.copyWith(
                      color: StrideColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: StrideSpace.s2),
      child,
    ],
  );
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) => Text(
    hint,
    style: StrideType.micro.copyWith(color: StrideColors.textMuted),
  );
}

class _JourneyBody extends StatelessWidget {
  const _JourneyBody({required this.view});

  final JourneyGoalView view;

  @override
  Widget build(BuildContext context) {
    final String status;
    if (view.arrived) {
      status = 'You are here.';
    } else if (view.totalCost == null) {
      status = 'No known route from here.';
    } else if (view.ready) {
      status = 'READY — the way is affordable now.';
    } else {
      status = '${formatSteps(view.shortfall ?? 0)} more steps needed';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AdaptiveText(view.destinationName, style: StrideType.itemName),
        if (view.totalCost != null && !view.arrived)
          Text(
            '${formatSteps(view.banked)} available / '
            '${formatSteps(view.totalCost!)} required'
            '${view.legNames.length > 1 ? ' · by way of ${view.legNames.take(view.legNames.length - 1).join(', ')}' : ''}',
            style: StrideType.micro,
          ),
        Text(
          status,
          style: StrideType.sub.copyWith(
            color: view.ready && !view.arrived
                ? StrideColors.accentSteps
                : StrideColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _PursuitBody extends StatelessWidget {
  const _PursuitBody({required this.view});

  final PursuitGoalView view;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      AdaptiveText(view.itemName, style: StrideType.itemName),
      if (view.owned)
        Text(
          'In hand — pursuit complete.',
          style: StrideType.sub.copyWith(color: StrideColors.textSecondary),
        )
      else ...<Widget>[
        for (final PursuitLineView line in view.lines)
          Text(
            line.satisfied
                ? '${line.name} ✓'
                : '${line.name} ${line.held} / ${line.required}',
            style: StrideType.micro,
          ),
        if (view.needs.isNotEmpty) ...<Widget>[
          const SizedBox(height: StrideSpace.s2),
          Text(
            'Need: ${view.needs.map((PursuitNeedView n) => '${n.name} ×${n.quantity}').join(', ')}',
            style: StrideType.micro.copyWith(
              color: StrideColors.textSecondary,
            ),
          ),
          if (view.needs.first.sourceName case final String source)
            Text(
              '${view.needs.first.viaEnemy ? 'Hunt at' : 'Suggested source'}: '
              '$source',
              style: StrideType.micro.copyWith(
                color: StrideColors.textSecondary,
              ),
            ),
        ] else
          Text(
            'Everything needed is in hand — craft it.',
            style: StrideType.sub.copyWith(color: StrideColors.accentSteps),
          ),
      ],
    ],
  );
}

class _ContractBody extends StatelessWidget {
  const _ContractBody({required this.view});

  final ContractGoalView view;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: AdaptiveText(view.name, style: StrideType.itemName),
          ),
          if (view.stageLabel case final String stage)
            Text(
              stage.toUpperCase(),
              style: StrideType.microLabel.copyWith(
                color: StrideColors.textSecondary,
              ),
            ),
        ],
      ),
      Text(
        view.locationName,
        style: StrideType.micro.copyWith(color: StrideColors.textMuted),
      ),
      for (final PursuitLineView line in view.lines)
        Text(
          line.satisfied
              ? '${line.name} ✓'
              : '${line.name} ${line.held} / ${line.required}',
          style: StrideType.micro,
        ),
      if (view.readyToAdvance && !view.complete)
        Text(
          'Ready to advance.',
          style: StrideType.sub.copyWith(color: StrideColors.accentSteps),
        ),
    ],
  );
}
