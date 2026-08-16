/// The gameplay screen: what walking has bought, what one action costs, and the
/// action itself.
///
/// ## What this screen deliberately does not show
///
/// The approved Round 03 render carries a `PROGRESS TO NEXT GATHER · 54 / 90`
/// bar, a `Stop` button, a `Change activity` button, and a `RECENT GAINS` row.
/// **Every one of those depicts a system `stride_core` does not have**: there is
/// no persistent selected activity, no partial gather progress, and no retained
/// gains view. `GatherResource` is a discrete command.
///
/// So this screen shows the cost, the available balance, and whether the action
/// can execute — and nothing that would imply progress accruing while the player
/// is away. A screen missing a card is honest; a fabricated progress bar is a lie
/// the player can see, and it is the exact Round 02 defect where four of five
/// bars contradicted their captions.
///
/// The render's hero figure, `3,240 walked today`, is also absent. `TimeBucket`
/// is a UTC hour-granularity span, so "today" would require choosing a local-day
/// boundary and folding the granted-slice map — a timezone policy and a game rule
/// invented in a widget (`RULES.md` E-2). `TOTAL WALKED` is the honest
/// substitute and is the same class of fact.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ResourceNodeDefinition;
import 'package:stride_health/stride_health.dart' show SyncFault;

import '../../../runtime/stride_session.dart';
import '../../components/data_display.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../components/walking_glyph.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import '../system/stale_banner.dart';
import 'gather_node_card.dart';

class AdventureScreen extends StatelessWidget {
  const AdventureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final List<ResourceNodeDefinition> nodes = s.nodesHere;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        StrideSpace.screenGutter,
        StrideSpace.s12,
        StrideSpace.screenGutter,
        StrideSpace.s16,
      ),
      children: <Widget>[
        if (s.isStale) ...<Widget>[
          StaleBanner(busy: c.busy, onReload: c.reload),
          const SizedBox(height: StrideSpace.cardGap),
        ],

        _StepsBudgetCard(controller: c),
        const SizedBox(height: StrideSpace.cardGap),

        if (nodes.isEmpty)
          const SectionCard(
            child: Text(
              'There is nothing to gather here.',
              style: StrideType.body,
            ),
          )
        else
          for (final ResourceNodeDefinition node in nodes) ...<Widget>[
            GatherNodeCard(node: node),
            const SizedBox(height: StrideSpace.cardGap),
          ],
      ],
    );
  }
}

/// What walking has produced, and how far it goes.
class _StepsBudgetCard extends StatelessWidget {
  const _StepsBudgetCard({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final StrideSession s = controller.session;
    final List<ResourceNodeDefinition> nodes = s.nodesHere;

    // The sentence that relates the header's banked figure to the cost of an
    // action. Visual QA's M-4 was that the approved render states this
    // relationship nowhere: banked and today sit 60 pt apart, both large, both
    // teal, with nothing saying how a stock relates to a flow.
    //
    // The division is arithmetic on two numbers already on screen, not a game
    // rule — the cost comes from `costOf`, which applies the same balance
    // profile the engine charges with.
    String? affordance;
    if (nodes.isNotEmpty) {
      final int? cost = s.costOf(nodes.first.id);
      if (cost != null && cost > 0) {
        final int count = s.usableEnergy ~/ cost;
        affordance = count == 1
            ? 'Enough banked for 1 more gather'
            : 'Enough banked for $count more gathers';
      }
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(label: 'Your walking'),
          const SizedBox(height: StrideSpace.s10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: LabeledValueTile(
                  label: 'Total walked',
                  value: formatSteps(s.totalGranted),
                  unit: 'steps earned',
                  leading: const WalkingGlyph(role: WalkingRole.stock),
                  valueColor: StrideColors.accentSteps,
                ),
              ),
              const SizedBox(width: StrideSpace.s8),
              Expanded(
                child: LabeledValueTile(
                  label: 'Spent',
                  value: formatSteps(s.totalSpent),
                  unit: 'on gathering',
                ),
              ),
            ],
          ),
          if (affordance case final String a) ...<Widget>[
            const SizedBox(height: StrideSpace.s10),
            Row(
              children: <Widget>[
                const WalkingGlyph(role: WalkingRole.unit),
                const SizedBox(width: StrideSpace.iconLabelGap),
                Expanded(child: Text(a, style: StrideType.micro)),
              ],
            ),
          ],
          const SizedBox(height: StrideSpace.s10),
          _SyncRow(controller: controller),
        ],
      ),
    );
  }
}

/// The foreground health sync, and what the last one did.
class _SyncRow extends StatelessWidget {
  const _SyncRow({required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final SyncReport? r = controller.lastSync;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        StrideButton(
          label: controller.busy ? 'Checking…' : 'Sync steps',
          onPressed: controller.busy || !controller.session.isReady
              ? null
              : controller.syncSteps,
        ),
        if (r != null) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          Text(_describe(r), style: StrideType.micro),
          // Faults are rendered, never filtered. `RULES.md` H-4 names
          // `cursorOfferedWhenProhibited` specifically: it "must never be
          // weakened, suppressed in UI, or accommodated". A product UI naturally
          // maps a sync onto a friendly line, and faults are the field with no
          // friendly rendering — so they are the field that gets dropped.
          if (r.faults.isNotEmpty)
            Text(
              'faults: ${r.faults.map((SyncFault f) => f.name).join(', ')}',
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            ),
        ],
      ],
    );
  }

  static String _describe(SyncReport r) => switch (r.status) {
    SyncStatus.reconciled when r.newlyGranted > 0 =>
      '+${formatSteps(r.newlyGranted)} steps banked',
    // Observed is shown beside newlyGranted, never instead of it. A restated
    // bucket counts in `observedSteps` every time it is restated, so rendering
    // it as "steps earned" would tell a returning player they earned the same
    // walk twice (`RULES.md` H-1).
    SyncStatus.reconciled =>
      'No new steps to bank (${formatSteps(r.observedSteps)} already counted)',
    SyncStatus.noChange => 'No new steps since the last check',
    SyncStatus.unavailable => 'Step data is not available right now',
    SyncStatus.keyingUnconfigured => 'Health is not connected on this device',
    SyncStatus.contractViolation =>
      'That step reading was refused before it could count',
    SyncStatus.commitRefused =>
      'Those steps could not be saved — reload before continuing',
  };
}
