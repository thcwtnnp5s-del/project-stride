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
///
/// ## When it reads the live view, and when it deliberately does not
///
/// While a combat command is in flight (`controller.busy`) the remembered
/// view is **frozen**: the engine applies a round to in-memory state
/// synchronously and only the commit awaits, so a frame rendered mid-command
/// already carries the next round's committed figures with no report to
/// choreograph them. Presenting them then is how the device showed damage
/// before the animation and an apparent mid-round heal-back
/// (`MILESTONES/ACTIVITY_FEEL_PRESENTATION_01.md` §4d); new committed figures
/// reach the stage only together with the beats that present them.
library;

import 'package:flutter/widgets.dart';

import 'package:stride_core/stride_core.dart' show KnowledgeTier;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/reward_beat.dart';
import '../../components/reward_layer.dart';
import '../../components/surfaces.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import 'combat_choreography.dart' show replays;
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

  /// The report the last build saw, by identity — how a new one is spotted
  /// on the frame it arrives.
  CombatReport? _seenReport;

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

    // Whether the stage was already in the tree when this build began — only
    // then can a report arriving now reach its `didUpdateWidget` and replay.
    final bool stageWasUp = _lastView != null;

    // The view is adopted only while no command is in flight. The engine
    // applies a round to in-memory state synchronously and only the commit
    // awaits, so a frame rendered mid-command already reads next round's
    // committed figures — with the report that would choreograph them still
    // null. Adopting `live` on that frame snapped every HP bar to its final
    // value; the replay then tweened *from* those values, which showed the
    // wolf's damage before its animation and healed the player back up to
    // "after hit 1" mid-round (the device-observed defect). Freezing the view
    // until the report arrives means new committed figures only ever reach
    // the stage together with the beats that present them. On a killing blow
    // the same mid-command frame has `live == null` with no outcome yet;
    // freezing also keeps the remembered view — and the stage — up through it.
    if (!c.busy) {
      if (live != null) {
        _lastView = live;
      } else if (outcome == null) {
        // Nothing to stage and nothing to acknowledge.
        _lastView = null;
      }
    } else if (live != null && _lastView == null) {
      // First sight of an encounter (a remount mid-command): nothing is
      // shown yet, so nothing can snap.
      _lastView = live;
    }
    final EncounterView? view = _lastView;

    // A report that will be replayed locks the controls and holds the outcome
    // panel back on the frame it arrives. The stage confirms through
    // [_onPlayingChanged] — but only post-frame, which is one frame too late
    // for the panel not to flash and the controls not to open. Mirrors the
    // stage's own condition exactly: a fresh mount does not replay a report
    // it mounted with, hence [stageWasUp].
    if (!identical(report, _seenReport)) {
      _seenReport = report;
      if (stageWasUp &&
          view != null &&
          report != null &&
          report.succeeded &&
          replays(report.events)) {
        _playing = true;
      }
    }

    // The fight has ended and its result has not been acknowledged. With no
    // remembered view — a relaunch cannot have one, and a report cannot
    // outlive one — the panel stands alone; otherwise the stage plays the
    // outcome first and the panel follows.
    // The result rises over the stage in the reward layer
    // (PLAYABLE_POLISH_01 §4) once the stage has finished playing the
    // outcome; the card beneath the scrim keeps the log and the locked
    // controls, so the fight is still there behind its own ending. Continue
    // is `acknowledgeCombat`, as before.
    if (view == null) {
      if (outcome == null || report == null) return const SizedBox.shrink();
      return RewardRaise(
        token: outcome,
        tier: RewardTier.medium,
        accent: _ResultPanel.accentOf(outcome),
        beats: _ResultPanel.beatsOf(report, outcome),
        onDismiss: c.acknowledgeCombat,
        child: const SizedBox.shrink(),
      );
    }

    final bool ended = live == null;
    final bool resolved =
        ended && outcome != null && report != null && !_playing;
    return RewardRaise(
      token: resolved ? outcome : null,
      tier: RewardTier.medium,
      accent: resolved ? _ResultPanel.accentOf(outcome) : null,
      beats: resolved
          ? _ResultPanel.beatsOf(report, outcome)
          : const <Widget>[],
      onDismiss: c.acknowledgeCombat,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CombatStage(
          view: view,
          report: report,
          ended: ended,
          onPlayingChanged: _onPlayingChanged,
        ),
        const SizedBox(height: StrideSpace.cardGap),
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
      ),
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
            // The outcome itself is the layer's; the log beneath it keeps
            // the round's blows and never narrates the ending twice.
            for (final CombatBeat b in r.events)
              if (b is! WonBeat && b is! LostBeat && b is! RetreatedBeat)
                describeBeat(b, enemyName),
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
    '${switch (b.quality) {
      StrikeQuality.strong => 'A strong hit',
      StrikeQuality.weak => 'A glancing blow',
      StrikeQuality.even => 'You strike',
    }} for ${b.damage}. $enemy is at ${b.enemyHpAfter}.',
  ConsumableUsedBeat() =>
    'You eat ${b.itemName} and recover ${b.healed}. '
        'You are at ${b.playerHpAfter}.',
  EnemyStruckBeat() =>
    '$enemy ${b.heavy
        ? 'lands a heavy blow'
        : switch (b.quality) {
            StrikeQuality.strong => 'hits hard',
            StrikeQuality.weak => 'grazes you',
            StrikeQuality.even => 'strikes',
          }} for ${b.damage}. '
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
///
/// Names and quantities only. Rarity now rides along on each [RewardLine] and
/// is deliberately *not* folded into this string — a colour is not a word, and
/// the victory panel that shows it is stream C's redesign.
String dropsText(List<RewardLine> drops) => drops
    .map(
      (RewardLine d) => d.quantity == 1 ? d.name : '${d.name} ×${d.quantity}',
    )
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

/// Victory, defeat or retreat, once, with a Continue that acknowledges it.
///
/// ## The victory choreography (PLAYABLE_EXPERIENCE_REFINEMENT_01 §16–§18)
///
/// The stage has already played the enemy's fall and its settle before this
/// panel mounts (`combat_presentation_order_test`). From here the result
/// resolves top to bottom on one clock, fast, never unskippable:
///
/// `VICTORY` · *the enemy falls* → the **experience** → the **drops**, one
/// framed row each → the **knowledge** advance, if this victory crossed one
/// → the **level-up**, if one landed → bounty progress, if any → `Continue`.
///
/// ## The hierarchy (§17)
///
/// Not every reward at equal weight. An ordinary win is XP and materials on
/// the quiet ground; a knowledge stage (Seen → Studied, Studied → Known) is a
/// MEDIUM beat naming what is now understood; a rare drop's row carries its
/// rarity frame and nothing else is louder; a character level is the
/// universal [LevelUpCard]; bounty progress is one small line.
///
/// ## What it deliberately is not
///
/// No chest, no reveal, no "tap to open", no burst, no currency, nothing
/// stacked or sequenced to be opened (`RULES.md` P-6). The motion is one
/// staggered resolve of facts already committed, once.
class _ResultPanel {
  const _ResultPanel._(this.report);

  final CombatReport report;

  /// The beats the layer resolves for [outcome], top to bottom.
  static List<Widget> beatsOf(CombatReport report, CombatBeat outcome) {
    final _ResultPanel p = _ResultPanel._(report);
    return switch (outcome) {
      final WonBeat w => p._victory(w),
      final LostBeat l => p._drivenBack(l),
      final RetreatedBeat r => p._retreated(r),
      _ => <Widget>[
        Text(
          describeBeat(outcome, report.enemyName),
          style: StrideType.body,
          maxLines: 4,
        ),
      ],
    };
  }

  /// A win takes the step accent — the ink every universal payoff wears;
  /// being driven back or retreating takes the plain frame, because losing
  /// nothing is not an event to celebrate and not one to punish.
  static Color? accentOf(CombatBeat outcome) =>
      outcome is WonBeat ? StrideColors.accentSteps : null;

  List<Widget> _victory(WonBeat o) => <Widget>[
    // The headline, with the fall beneath it — the card title weight a win
    // deserves.
    RewardBeat(
      tier: RewardTier.major,
      eyebrow: 'VICTORY',
      title: '${report.enemyName} falls',
      accent: StrideColors.accentSteps,
    ),
    // The experience, on its own ground: MINOR unless a level landed, which
    // the LevelUpCard below says.
    // No block of its own: the layer is the frame (finding E).
    RewardFacts(
      label: 'EXPERIENCE',
      children: <Widget>[
        AdaptiveText('+${o.xp} XP', style: StrideType.numericValue),
        if (o.knowledgeXp > 0)
          AdaptiveText(
            'including +${o.knowledgeXp} for knowing the ${o.enemyName}',
            style: StrideType.micro,
            color: StrideColors.textSecondary,
          ),
      ],
    ),
    // The drops. Each row carries its rarity's frame; a rare or better row
    // is therefore the loudest thing in the list without a second treatment.
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('REWARDS', style: StrideType.microLabel, maxLines: 1),
        const SizedBox(height: StrideSpace.s6),
        if (o.drops.isEmpty)
          // Quiet, and never an apology. Nothing was lost and nothing is
          // owed; the drop tables are chances, and a chance that did not land
          // is a fact rather than a failure (`RULES.md` P-5, P-7).
          const Text(
            'No drops this time.',
            style: StrideType.micro,
            maxLines: 2,
          )
        else
          for (int i = 0; i < o.drops.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: StrideSpace.s6),
            RewardItemRow(
              id: o.drops[i].id,
              name: o.drops[i].name,
              quantity: o.drops[i].quantity,
              rarity: o.drops[i].rarity,
            ),
          ],
      ],
    ),
    // The knowledge stage, when this victory crossed one (§18): Studied names
    // what is now understood and keeps the signature concealed; Known reveals
    // the signature.
    if (o.knowledgeAdvanced)
      RewardBeat(
        tier: RewardTier.medium,
        eyebrow: o.enemyName.toUpperCase(),
        title: switch (o.knowledgeAfter) {
          KnowledgeTier.known => 'KNOWN',
          KnowledgeTier.studied => 'STUDIED',
          _ => 'SEEN',
        },
        accent: StrideColors.accentSteps,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (o.knowledgeAfter == KnowledgeTier.studied &&
                o.understoodDrops.isNotEmpty) ...<Widget>[
              const Text('NEWLY UNDERSTOOD', style: StrideType.microLabel),
              for (final String name in o.understoodDrops)
                AdaptiveText(
                  name,
                  style: StrideType.sub,
                  color: StrideColors.textPrimary,
                ),
            ],
            if (o.signatureDrops.isNotEmpty) ...<Widget>[
              if (o.knowledgeAfter == KnowledgeTier.studied)
                const SizedBox(height: StrideSpace.s4),
              const Text('SIGNATURE', style: StrideType.microLabel),
              for (final String name in o.signatureDrops)
                AdaptiveText(
                  o.knowledgeAfter == KnowledgeTier.known ? name : '???',
                  style: StrideType.sub,
                  color: o.knowledgeAfter == KnowledgeTier.known
                      ? StrideColors.textPrimary
                      : StrideColors.textMuted,
                ),
            ],
          ],
        ),
      ),
    // The character level: the universal beat (§29).
    if (o.levelledUp)
      LevelUpCard(
        name: 'Traveler',
        level: o.levelAfter,
        why: '+2 Max HP · harder fights are within reach',
      ),
    // Bounty progress: one small line each, never a card (§17).
    for (final BountyProgressLine b in o.bountyProgress)
      AdaptiveText(
        '${b.contractName} · ${b.progress} / ${b.required}',
        style: StrideType.micro,
        color: StrideColors.textSecondary,
      ),
  ];

  /// Retreat-not-death (§19): where the player now is, that nothing was
  /// lost, and — when the safe destination healed them — that too, without
  /// ever implying a death. Quieter heading than a win: losing nothing is
  /// not an event to celebrate, and not one to punish.
  List<Widget> _drivenBack(LostBeat l) => <Widget>[
    RewardBeat(
      tier: RewardTier.medium,
      eyebrow: 'DRIVEN BACK',
      title: 'Retreated to ${l.retreatToName}',
      lines: <String>[
        'Nothing was lost.',
        if (l.healed) 'Rested and recovered at ${l.retreatToName}.',
      ],
    ),
  ];

  List<Widget> _retreated(RetreatedBeat r) => <Widget>[
    RewardBeat(
      tier: RewardTier.medium,
      eyebrow: 'RETREATED',
      title: 'Retreated to ${r.retreatToName}',
      lines: const <String>['Nothing was lost.'],
    ),
  ];
}

