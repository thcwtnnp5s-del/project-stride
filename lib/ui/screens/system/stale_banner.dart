/// Shown when the session's in-memory state has advanced past the durable
/// state.
///
/// **Deliberately plain and deliberately undesigned** (Q-UI-8), like
/// `BlockedScreen`, and isolated for the same reason.
///
/// It is a blocking statement rather than a status row, and that distinction is
/// the whole point. While stale, every figure the session reports is **ahead of
/// disk**: the engine applied the gather, the commit did not land, and the herbs
/// on screen are herbs the next launch will not have. The dev harness renders
/// this as one row among fifteen, which is fine for an instrument a developer
/// reads — a player would read the herb count and not the row.
///
/// The recovery is Reload, which rereads from disk and rebuilds. It is not a
/// retry: a refused commit means durable state moved under this transaction, and
/// nothing is fixed by trying harder from a state that has already diverged.
library;

import 'package:flutter/widgets.dart';

import '../../components/data_display.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

class StaleBanner extends StatelessWidget {
  const StaleBanner({super.key, required this.onReload, required this.busy});

  final VoidCallback onReload;
  final bool busy;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(StrideSpace.cardPadding),
    decoration: BoxDecoration(
      color: StrideColors.surfaceBlock,
      border: Border.all(color: StrideColors.borderDefault),
      borderRadius: StrideRadius.card,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'The last save did not land',
          style: StrideType.sectionHeading,
        ),
        const SizedBox(height: StrideSpace.s6),
        const Text(
          'The numbers on this screen are ahead of what is stored. '
          'Reload to go back to your saved progress. Nothing has been lost.',
          style: StrideType.body,
        ),
        const SizedBox(height: StrideSpace.s12),
        StrideButton(
          label: busy ? 'Reloading…' : 'Reload',
          onPressed: busy ? null : onReload,
        ),
      ],
    ),
  );
}
