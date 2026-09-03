/// The ledger's foot — "is my walking being counted?", and the tab that
/// opens the full record (the physical-device polish pass, item 1;
/// `DECISIONS/0026`).
///
/// It was a card of its own, directly beneath a card of step figures: two
/// dark rectangles saying one thing. Since EPO03 it is the **foot of the
/// walking ledger** — the same page, under the ledger's own last rule: one
/// line of freshness, and the Step Tracker as an index tab rather than a
/// button in a box (`DIR-05`).
///
/// Every figure is `StrideSession.stepHistory()` — the local-day fold lives
/// there, behind the UI boundary, and this block could not compute it if it
/// wanted to (`Scripts/check-ui-boundary.sh` rule 5).
library;

import 'package:flutter/widgets.dart';

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/panel_skin.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The ledger's closing rule. The foot belongs to the figures above
        // it, so it is ruled off from them rather than boxed away from them.
        const KitEdge(
          tile: KitTile.ruleJournal,
          fallbackColor: StrideColors.separator,
        ),
        const SizedBox(height: StrideSpace.s6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Text(
                // Today and this week are the ledger's lines now (`ART-12`
                // §3). They were value tiles here as well, and a screen that
                // says TODAY twice has not made the figure more important —
                // it has made the screen a list of boxes. What is left is
                // what this foot is actually for: whether the count is
                // current.
                <String>[
                  syncedLabel(history),
                  if (history.originCount > 1) '${history.originCount} sources',
                ].join(' · '),
                style: StrideType.micro.copyWith(color: StrideColors.textMuted),
                maxLines: 2,
              ),
            ),
            const SizedBox(width: StrideSpace.s8),
            const _TrackerTab(),
          ],
        ),
      ],
    );
  }
}

/// The Step Tracker, as a folio index tab.
///
/// `KitFrame.tabPlate` rather than a `StrideButton`: `DIR-05` gives each
/// screen **one** primary plate, and a door out of a ledger is not it. The
/// tab reserves the frame's declared inset whether or not `tab_plate` has
/// landed, and it keeps the product's 44 dp hit floor either way.
class _TrackerTab extends StatelessWidget {
  const _TrackerTab();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Step Tracker',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => StepTrackerScreen.open(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: StrideGeometry.buttonHitFloor,
        ),
        child: KitPlate(
          frame: KitFrame.tabPlate,
          fill: StrideColors.surfaceRaised,
          raised: true,
          padding: const EdgeInsets.symmetric(
            horizontal: StrideSpace.s10,
            vertical: StrideSpace.s8,
          ),
          child: const AdaptiveText(
            'Step Tracker',
            style: StrideType.compactLabel,
            minScale: 0.8,
          ),
        ),
      ),
    ),
  );
}
