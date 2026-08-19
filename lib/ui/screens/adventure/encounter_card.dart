/// One enemy at this location, what fighting it means, and the action.
///
/// Reads an [EncounterOption] projection and dispatches
/// `SessionController.startEncounter`. It carries **no step cost anywhere**:
/// starting an encounter is free by decision (`DECISIONS/0020` §3), and a cost
/// tile here would be the most convincing lie on the tab.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show EnemyBehavior;

import '../../../runtime/stride_session.dart';
import '../../components/data_display.dart';
import '../../components/surfaces.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

class EncounterCard extends StatelessWidget {
  const EncounterCard({super.key, required this.option});

  final EncounterOption option;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final EncounterOption o = option;

    return SectionCard(
      padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(o.name, style: StrideType.cardTitle, maxLines: 2),
          Text(
            o.isBoss ? 'Guards this place' : 'Roams here',
            style: StrideType.sub,
            maxLines: 1,
          ),
          const SizedBox(height: StrideSpace.s10),
          Wrap(
            spacing: StrideSpace.s6,
            runSpacing: StrideSpace.s6,
            children: <Widget>[
              if (o.isBoss) const RequirementGate(label: 'Boss'),
              RequirementGate(label: _behaviorLabel(o.behavior)),
            ],
          ),
          const SizedBox(height: StrideSpace.s10),
          ValueTileRow(
            tiles: <LabeledValueTile>[
              LabeledValueTile(label: 'Health', value: '${o.maxHealth}'),
              LabeledValueTile(label: 'Attack', value: '${o.attack}'),
              LabeledValueTile(label: 'Defence', value: '${o.defence}'),
            ],
          ),
          const SizedBox(height: StrideSpace.s8),
          Text(
            _rewards(o),
            style: StrideType.micro.copyWith(color: StrideColors.textSecondary),
            maxLines: 2,
          ),
          const SizedBox(height: StrideSpace.s12),
          StrideButton(
            label: c.busy ? 'Starting…' : 'Start Combat',
            subLabel: c.busy ? null : _subLabel(o),
            onPressed: c.busy || !o.available
                ? null
                : () => c.startEncounter(o.enemyId),
          ),
        ],
      ),
    );
  }

  static String _behaviorLabel(EnemyBehavior b) => switch (b) {
    EnemyBehavior.steady => 'One strike a turn',
    EnemyBehavior.flurry => 'Two light strikes a turn',
    EnemyBehavior.guarded => 'Heavy strike every third turn',
  };

  static String _rewards(EncounterOption o) {
    final String xp = '${o.xp} XP';
    if (o.drops.isEmpty) return 'Rewards: $xp';
    final String names = o.drops.map((DropPreview d) => d.name).join(', ');
    return 'Rewards: $xp, $names';
  }

  /// What the button says under itself: how much of this visit is left, or the
  /// truthful reason it is disabled, in the engine's order.
  ///
  /// An available enemy now carries a figure rather than nothing, because
  /// "you can fight this" and "you can fight this twice more before you have
  /// to travel" are different pieces of planning and the second is the one a
  /// player with a route in mind is actually asking about
  /// (`DECISIONS/0021` §1). The spent line is unchanged, word for word: the
  /// player's experience of it did not change, only how many wins it took.
  static String? _subLabel(EncounterOption o) => o.available
      ? '${o.remainingThisVisit} of ${o.encountersPerVisit} this visit'
      : _reasonText(o.reason);

  /// The truthful reason the button is disabled, in the engine's order.
  static String? _reasonText(String? reason) => switch (reason) {
    null => null,
    'enemy_driven_off' => 'Driven off — returns after you travel',
    'encounter_in_progress' => 'Finish your current encounter',
    'session_not_ready' => 'Reload before fighting',
    _ => 'Not available right now',
  };
}
