/// The Steps card — the compact home of "is my walking being counted?"
/// (the physical-device polish pass, item 1; `DECISIONS/0026`).
///
/// Today, this week, when the game last read the store, and the door to the
/// full tracker. Every figure is `StrideSession.stepHistory()` — the
/// local-day fold lives there, behind the UI boundary, and this card could
/// not compute it if it wanted to (`Scripts/check-ui-boundary.sh` rule 5).
library;

import 'package:flutter/widgets.dart';

import '../../../runtime/stride_session.dart';
import '../../components/data_display.dart';
import '../../components/surfaces.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import 'step_tracker_screen.dart';

/// `Synced 14:02` / `Synced just now` — from two figures the projection
/// already carries, never from a clock read here (Q-UI-9 stays closed).
String syncedLabel(StepHistory history) {
  final int? at = history.lastSyncAtMillis;
  if (at == null) return 'Not synced yet this launch';
  final int agoMillis = history.nowMillis - at;
  if (agoMillis < 90 * 1000) return 'Synced just now';
  if (agoMillis < 60 * 60 * 1000) {
    return 'Synced ${agoMillis ~/ (60 * 1000)} min ago';
  }
  final DateTime t = DateTime.fromMillisecondsSinceEpoch(at);
  final String hh = t.hour.toString().padLeft(2, '0');
  final String mm = t.minute.toString().padLeft(2, '0');
  return 'Synced at $hh:$mm';
}

class StepsBlock extends StatelessWidget {
  const StepsBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final StepHistory history = SessionScope.of(context).session.stepHistory();

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(label: 'Steps'),
          const SizedBox(height: StrideSpace.rhythmRow),
          // Today and this week moved into the ledger above (ART-12 §3).
          // They were two value tiles here and two more figures of the same
          // kind in the card directly beneath, and a screen that says TODAY
          // twice has not made the figure more important — it has made the
          // screen a list of boxes. What is left is what this card is
          // actually for: whether the count is current, and the door to the
          // tracker.
          Text(
            <String>[
              syncedLabel(history),
              if (history.originCount > 1) '${history.originCount} sources',
            ].join(' · '),
            style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            maxLines: 1,
          ),
          const SizedBox(height: StrideSpace.s8),
          StrideButton.secondary(
            label: 'Step Tracker',
            onPressed: () => StepTrackerScreen.open(context),
          ),
        ],
      ),
    );
  }
}
