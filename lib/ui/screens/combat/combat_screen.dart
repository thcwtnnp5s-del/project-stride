/// The encounter in progress: the animated stage, this round's log, the three
/// controls, and the outcome panel.
///
/// ## Shape
///
/// The Adventure tab renders this in place of the location's cards while
/// `session.encounter != null`, and keeps it up while an outcome report is
/// waiting to be acknowledged (`GAME_BIBLE/COMBAT/02` §10). The stage
/// (`combat_stage.dart`) sits above; the log, the controls, the Eat chooser
/// and the result panel are the boundary it sits on, and they read the same
/// projections it does.
///
/// ## What it never does
///
/// It renders nothing optimistically: every HP figure the HUD settles on is
/// `EncounterView`, read live after the commit, and every log line and every
/// beat the stage replays is a `CombatBeat` the session built from an event
/// already on disk. It never diffs state to find out what happened, and it
/// never re-derives a figure a beat already carries. No wall-clock: nothing
/// here advances the fight; the replay is a `TickerMode`-gated presentation
/// of a round already resolved.
///
/// ## The one thing it remembers
///
/// The engine clears the encounter on the same commit that decides it, so
/// when a Won/Lost/Retreated report arrives `session.encounter` is already
/// null and the stage would have no enemy to fell. This widget keeps the
/// **last non-null `EncounterView`** it was built with — enemy id, names,
/// location, maxima — for exactly as long as the outcome stands unacknowledged.
/// It is presentation memory of a fact the engine committed, held for one
/// panel's lifetime, cleared with the report; it decides nothing and outlives
/// nothing (`RULES.md` E-2).
library;

import 'package:flutter/widgets.dart';

import '../../../runtime/stride_session.dart';
import '../../components/data_display.dart';
import '../../components/surfaces.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import 'combat_stage.dart';

class CombatScreen extends StatefulWidget {
  const CombatScreen({super.key});

  @override
  State<CombatScreen> createState() => _CombatScreenState();
}

class _CombatScreenState extends State<CombatScreen> {
  /// The last live view — see the library doc.
  EncounterView? _lastView;

  /// True while the stage replays a round; the controls are disabled and the
  /// outcome panel waits.
  bool _playing = false;

  void _onPlayingChanged(bool playing) {
    if (playing == _playing) return;
    setState(() => _playing = playing);
  }

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final EncounterView? live = s.encounter;
    final CombatReport? report = c.lastCombat;
    final CombatBeat? outcome = report?.outcome;

    if (live != null) {
      _lastView = live;
    } else if (outcome == null) {
      // Nothing to stage and nothing to acknowledge.
      _lastView = null;
    }
    final EncounterView? view = _lastView;

    // The fight has ended and its result has not been acknowledged. With no
    // remembered view — a relaunch cannot have one, and a report cannot
    // outlive one — the panel stands alone; otherwise the stage plays the
    // outcome first and the panel follows.
    if (view == null) {
      if (outcome == null || report == null) return const SizedBox.shrink();
      return _ResultPanel(report: report, outcome: outcome, controller: c);
    }

    final bool ended = live == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CombatStage(
          view: view,
          report: report,
          ended: ended,
          onPlayingChanged: _onPlayingChanged,
        ),
        const SizedBox(height: StrideSpace.cardGap),
        if (ended && outcome != null && report != null && !_playing)
          _ResultPanel(report: report, outcome: outcome, controller: c)
        else
          SectionCard(
            padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _CombatLog(
                  report: report,
                  enemyName: view.enemyName,
                  playing: _playing,
                ),
                const SizedBox(height: StrideSpace.s12),
                _CombatControls(
                  view: view,
                  controller: c,
                  locked: _playing || ended,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The round's beats as plain lines, most recent round only. Ephemeral by
/// construction — it is the last report, not a history.
///
/// Held back while the stage replays the round: the lines would otherwise
/// tell the ending before the blows land. They appear, complete, when the
/// replay ends or is skipped.
class _CombatLog extends StatelessWidget {
  const _CombatLog({
    required this.report,
    required this.enemyName,
    required this.playing,
  });

  final CombatReport? report;
  final String enemyName;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final CombatReport? r = report;
    if (playing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(label: 'This round'),
          const SizedBox(height: StrideSpace.s6),
          Text('Tap the stage to skip.', style: StrideType.micro),
        ],
      );
    }
    final List<String> lines = r == null
        ? const <String>[]
        : !r.succeeded
        ? <String>[_refusalText(r)]
        : <String>[
            for (final CombatBeat b in r.events) describeBeat(b, enemyName),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeading(label: 'This round'),
        const SizedBox(height: StrideSpace.s6),
        if (lines.isEmpty)
          Text('Choose your action.', style: StrideType.micro)
        else
          for (final String line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: StrideSpace.s2),
              child: Text(
                line,
                style: StrideType.micro.copyWith(
                  color: StrideColors.textPrimary,
                ),
              ),
            ),
      ],
    );
  }

  static String _refusalText(CombatReport r) => switch (r.rejection) {
    'session_busy' => 'Still finishing the last action',
    'session_not_ready' => 'Reload before fighting on',
    'commit_refused' => 'That could not be saved — reload before continuing',
    'no_encounter' => 'There is no fight to act in',
    'health_full' => 'Your health is already full',
    'not_edible' => 'That cannot be eaten',
    'item_not_owned' => 'You have none of that left',
    _ => r.detail ?? 'That action was refused',
  };
}

/// One beat as one line. Public within the file's library so the result panel
/// and the log agree on the wording; presentation only.
String describeBeat(CombatBeat b, String enemy) => switch (b) {
  EncounterStartedBeat() =>
    'The fight begins. ${b.enemyName} ${b.enemyHp} / ${b.enemyMaxHp}, '
        'you ${b.playerHp} / ${b.playerMaxHp}.',
  PlayerStruckBeat() =>
    'You strike for ${b.damage}. $enemy is at ${b.enemyHpAfter}.',
  ConsumableUsedBeat() =>
    'You eat ${b.itemName} and recover ${b.healed}. '
        'You are at ${b.playerHpAfter}.',
  EnemyStruckBeat() =>
    '$enemy ${b.heavy ? 'lands a heavy blow' : 'strikes'} for ${b.damage}. '
        'You are at ${b.playerHpAfter}.',
  RoundEndedBeat() =>
    b.telegraph
        ? 'Turn ${b.turn}. The $enemy gathers itself…'
        : 'Turn ${b.turn}.',
  WonBeat() =>
    '$enemy falls. +${b.xp} XP'
        '${b.levelledUp ? ' — level ${b.levelAfter}!' : ''}'
        '${b.drops.isEmpty ? '' : ' Drops: ${dropsText(b.drops)}.'}',
  LostBeat() => 'You retreat to ${b.retreatToName}. Nothing was lost.',
  RetreatedBeat() => 'You retreat to ${b.retreatToName}. Nothing was lost.',
};

/// `Meadow Herb, Wolf Pelt ×2`.
String dropsText(List<(String, int)> drops) => drops
    .map(((String, int) d) => d.$2 == 1 ? d.$1 : '${d.$1} ×${d.$2}')
    .join(', ');

/// Attack · Eat · Retreat, all disabled while a command is in flight and
/// while the stage replays the last round ([locked]).
class _CombatControls extends StatefulWidget {
  const _CombatControls({
    required this.view,
    required this.controller,
    required this.locked,
  });

  final EncounterView view;
  final SessionController controller;

  /// True while a replay runs or the fight has ended: nothing may be tapped.
  final bool locked;

  @override
  State<_CombatControls> createState() => _CombatControlsState();
}

class _CombatControlsState extends State<_CombatControls> {
  /// Whether the Eat chooser is open. Presentational; nothing durable.
  bool _choosing = false;

  @override
  Widget build(BuildContext context) {
    final SessionController c = widget.controller;
    final EncounterView view = widget.view;
    final List<EdibleOption> edibles = c.session.edibles;
    // Busy is the command in flight; locked is the replay of the one that
    // returned. Either way the player waits, and neither reads as a refusal.
    final bool held = c.busy || widget.locked;
    final bool full = view.playerHp >= view.playerMaxHp;
    final String? eatReason = edibles.isEmpty
        ? 'Nothing to eat'
        : full
        ? 'Health is full'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        StrideButton(
          label: held ? 'Fighting…' : 'Attack',
          onPressed: held ? null : c.combatAttack,
        ),
        const SizedBox(height: StrideSpace.s8),
        StrideButton(
          label: _choosing ? 'Eat — choose' : 'Eat',
          subLabel: held ? null : eatReason,
          onPressed: held || eatReason != null
              ? null
              : () => setState(() => _choosing = !_choosing),
        ),
        if (_choosing && eatReason == null) ...<Widget>[
          const SizedBox(height: StrideSpace.s6),
          Wrap(
            spacing: StrideSpace.s6,
            runSpacing: StrideSpace.s6,
            children: <Widget>[
              for (final EdibleOption e in edibles)
                StrideButton.secondary(
                  label: '${e.name} +${e.healing} (×${e.count})',
                  onPressed: held
                      ? null
                      : () {
                          setState(() => _choosing = false);
                          c.combatEat(e.itemId);
                        },
                ),
            ],
          ),
        ],
        const SizedBox(height: StrideSpace.s8),
        // No confirm step: retreating loses nothing, and the label says so,
        // so a second tap would guard against nothing.
        StrideButton.secondary(
          label: 'Retreat — nothing is lost',
          onPressed: held ? null : c.combatRetreat,
        ),
      ],
    );
  }
}

/// Victory, defeat or retreat, once, with an OK that acknowledges it.
class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.report,
    required this.outcome,
    required this.controller,
  });

  final CombatReport report;
  final CombatBeat outcome;
  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final String heading = switch (outcome) {
      WonBeat() => 'Victory',
      LostBeat() => 'Driven back',
      RetreatedBeat() => 'Retreated',
      _ => 'Encounter over',
    };
    // Victory itemises; the two retreats say where the player now is and that
    // nothing was lost, in the log's own words.
    final CombatBeat o = outcome;
    final List<Widget> lines = switch (o) {
      WonBeat() => <Widget>[
        Text('${report.enemyName} falls.', style: StrideType.body, maxLines: 2),
        const SizedBox(height: StrideSpace.s6),
        Text(
          '+${o.xp} XP'
          '${o.levelledUp ? ' — level ${o.levelAfter}!' : ''}',
          style: StrideType.numericValue.copyWith(
            color: StrideColors.textPrimary,
          ),
        ),
        if (o.drops.isNotEmpty) ...<Widget>[
          const SizedBox(height: StrideSpace.s6),
          Text(
            'Drops: ${dropsText(o.drops)}',
            style: StrideType.sub.copyWith(color: StrideColors.textPrimary),
            maxLines: 3,
          ),
        ],
      ],
      _ => <Widget>[
        Text(
          describeBeat(outcome, report.enemyName),
          style: StrideType.body,
          maxLines: 4,
        ),
      ],
    };
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeading(label: heading),
          const SizedBox(height: StrideSpace.s10),
          ...lines,
          const SizedBox(height: StrideSpace.s12),
          StrideButton(label: 'OK', onPressed: controller.acknowledgeCombat),
        ],
      ),
    );
  }
}
