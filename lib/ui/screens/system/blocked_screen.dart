/// What the player sees when the bootstrap refused to start the game.
///
/// **Deliberately plain and deliberately undesigned.** A blocked bootstrap is a
/// real, reachable state that has never had a designed screen (Q-UI-8). Giving
/// it a polished treatment now would imply a design decision nobody has made;
/// giving it nothing would crash. This is the honest middle, and it is isolated
/// in `screens/system/` so the designed screens never grow an undesigned branch.
///
/// Two rules govern what it may say:
///
/// **The explanation is rendered verbatim.** `BootstrapBlocked.explanation` is
/// contractually player-legible and health-free, and the bootstrap code
/// explicitly declines to reword the repository's version because "two wordings
/// of the same refusal eventually disagree". This screen does not reword it
/// either.
///
/// **There is no "start a new game" escape hatch.** A blocked bootstrap
/// deliberately deletes nothing. Offering a wipe here is the exact outcome the
/// refusal state machine exists to prevent — the player's save is intact and the
/// button would destroy it.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show BootstrapBlocked;

import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key, required this.blocked});

  final BootstrapBlocked blocked;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StrideColors.surfaceGround,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(StrideSpace.s16 * 1.5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Stride could not start', style: StrideType.cardTitle),
              const SizedBox(height: StrideSpace.s12),
              Text(blocked.explanation, style: StrideType.body),
              const SizedBox(height: StrideSpace.s16),
              Text('reason: ${blocked.reason.name}', style: StrideType.micro),
              Text(
                'stopped at: ${blocked.stoppedAt.name}',
                style: StrideType.micro,
              ),
              if (blocked.detail.isNotEmpty) ...<Widget>[
                const SizedBox(height: StrideSpace.s8),
                // Content ids and profile names. Never health-derived.
                Text(blocked.detail.join('\n'), style: StrideType.micro),
              ],
              const SizedBox(height: StrideSpace.s16),
              const Text(
                'Your saved progress has not been changed or deleted.',
                style: StrideType.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
