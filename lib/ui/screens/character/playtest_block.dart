/// The owner's playtest controls (`DECISIONS/0025`), on the Character tab.
///
/// Two acts, each behind its own confirmation, each dispatching one command
/// through the ordinary path and presenting its result in the reward layer:
///
/// - **Reset the walking baseline** — the spendable balance and the
///   walked figure start again from zero. The bag, the gear, the skills,
///   the world: untouched.
/// - **Start a fresh playtest** — the above, and the game itself begins
///   again at Haven's Rest with the starting loadout.
///
/// Neither touches the step ledger's history: the lifetime counter, the
/// dedupe slices, the watermarks and the cursor are what they were, and the
/// next sync reads forward from where the last one stopped. A re-delivered
/// hour of old walking grants nothing (`packages/stride_core/test/
/// playtest_reset_test.dart`).
///
/// Quiet by design: a small block at the foot of the sheet, secondary
/// controls, the plainest copy. It is an owner's instrument in a player's
/// product, and it should look like neither a feature nor a dare.
library;

import 'package:flutter/widgets.dart';

import '../../../runtime/stride_session.dart';
import '../../components/data_display.dart';
import '../../components/reward_beat.dart';
import '../../components/reward_layer.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';

class PlaytestBlock extends StatefulWidget {
  const PlaytestBlock({super.key});

  @override
  State<PlaytestBlock> createState() => _PlaytestBlockState();
}

class _PlaytestBlockState extends State<PlaytestBlock> {
  /// Which act is awaiting its confirmation, or null. Ephemeral UI state.
  bool? _confirmingFresh;

  /// A refusal, in place, until the next tap.
  String? _refusal;

  Future<void> _go(bool freshStart) async {
    final SessionController c = SessionScope.read(context);
    final StrideSession s = c.session;
    final int walked = s.walkedSinceBaseline;
    final PlaytestResetReport? report = await c.resetPlaytest(
      freshStart: freshStart,
    );
    if (!mounted || report == null) return;
    setState(() => _confirmingFresh = null);
    if (!report.succeeded) {
      setState(() => _refusal = _refusalText(report));
      return;
    }
    await showRewardLayer(
      context,
      tier: RewardTier.medium,
      accent: StrideColors.accentSteps,
      beats: <Widget>[
        RewardBeat(
          tier: RewardTier.medium,
          eyebrow: freshStart ? 'FRESH PLAYTEST' : 'BASELINE RESET',
          title: freshStart ? 'The game begins again' : 'Walking starts again',
          accent: StrideColors.accentSteps,
          lines: <String>[
            'Banked steps 0 · Total walked 0',
            '${formatSteps(walked)} walked and '
                '${formatSteps(report.retiredBanked)} banked are retired, '
                'not lost: the lifetime figure keeps them.',
            if (freshStart)
              'Bag, gear, skills, character and progress are new. '
                  'Back at the start.',
            'Only new walking is spendable. Old steps cannot come back.',
          ],
        ),
      ],
    );
  }

  static String _refusalText(PlaytestResetReport r) => switch (r.rejection) {
    'encounter_in_progress' => 'Finish or retreat from the fight first.',
    'activity_queue_active' => 'Stop the running activity first.',
    'session_busy' => 'Something else is still running.',
    'session_not_ready' => 'The game is not ready. Reload and try again.',
    'commit_refused' => 'That did not save. Reload before trying again.',
    _ => r.detail ?? 'That could not be done.',
  };

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final bool busy = c.busy;
    final bool? confirming = _confirmingFresh;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(label: 'Playtest'),
          const SizedBox(height: StrideSpace.s6),
          Text(
            'Start the count again. Lifetime walking, the step history and '
            'the sync cursor are kept; old steps can never be re-banked.',
            style: StrideType.micro.copyWith(color: StrideColors.textSecondary),
            maxLines: 4,
          ),
          const SizedBox(height: StrideSpace.s10),
          if (confirming == null)
            Wrap(
              spacing: StrideSpace.s8,
              runSpacing: StrideSpace.s6,
              children: <Widget>[
                StrideButton.secondary(
                  label: 'Reset walking baseline',
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          _refusal = null;
                          _confirmingFresh = false;
                        }),
                ),
                StrideButton.secondary(
                  label: 'Start a fresh playtest',
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          _refusal = null;
                          _confirmingFresh = true;
                        }),
                ),
              ],
            )
          else
            _Confirm(
              fresh: confirming,
              busy: busy,
              onCancel: () => setState(() => _confirmingFresh = null),
              onConfirm: () => _go(confirming),
            ),
          if (_refusal case final String text) ...<Widget>[
            const SizedBox(height: StrideSpace.s6),
            Text(
              text,
              style: StrideType.micro.copyWith(color: StrideColors.textPrimary),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }
}

/// The second step: what will happen, in one block, and the one filled
/// control that does it. Cancel is the quiet one.
class _Confirm extends StatelessWidget {
  const _Confirm({
    required this.fresh,
    required this.busy,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool fresh;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) => SurfaceBlock(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          fresh ? 'START A FRESH PLAYTEST?' : 'RESET THE WALKING BASELINE?',
          style: StrideType.microLabel.copyWith(color: StrideColors.textPrimary),
          maxLines: 1,
        ),
        const SizedBox(height: StrideSpace.s4),
        Text(
          fresh
              ? 'Banked steps and Total walked go to 0. The bag, gear, '
                    'skills, character, contracts and projects start over at '
                    'Haven\'s Rest. Any fight or activity in progress is '
                    'dropped.'
              : 'Banked steps and Total walked go to 0. Everything else — '
                    'bag, gear, skills, progress — stays.',
          style: StrideType.micro.copyWith(color: StrideColors.textSecondary),
          maxLines: 5,
        ),
        const SizedBox(height: StrideSpace.s8),
        Row(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: StrideButton(
                label: busy ? '…' : (fresh ? 'Start fresh' : 'Reset baseline'),
                onPressed: busy ? null : onConfirm,
              ),
            ),
            const SizedBox(width: StrideSpace.s8),
            Expanded(
              flex: 2,
              child: StrideButton.secondary(
                label: 'Cancel',
                onPressed: busy ? null : onCancel,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
