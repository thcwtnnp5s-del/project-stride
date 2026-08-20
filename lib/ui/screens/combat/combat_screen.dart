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

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/pixel_asset.dart';
import '../../components/rarity_badge.dart';
import '../../components/rarity_item_title.dart';
import '../../components/surfaces.dart';
import '../../icons/pixel_icons.dart';
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
    if (view == null) {
      if (outcome == null || report == null) return const SizedBox.shrink();
      return _ResultPanel(
        // Keyed on the outcome, so a second fight in the same visit builds a
        // fresh State and replays its reveal rather than inheriting the last
        // panel's finished clock.
        key: ObjectKey(outcome),
        report: report,
        outcome: outcome,
        controller: c,
      );
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
          _ResultPanel(
            key: ObjectKey(outcome),
            report: report,
            outcome: outcome,
            controller: c,
          )
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
/// ## What a victory reads as, top to bottom
///
/// `VICTORY` · *the enemy falls* · the **experience block**, on its own nested
/// ground so the figure is not one more sentence · **REWARDS**, one framed row
/// per drop carrying icon, name in its rarity's ink, the rarity word, and the
/// quantity · `Continue`.
///
/// The separation is the point. The shipped panel ran the XP and the drops
/// together as two lines of prose — `+30 XP` then `Drops: Meadow Herb, Wolf
/// Pelt ×2` — so winning a fight and winning *something* arrived as the same
/// sentence, and the rarity the content authors had already decided was
/// invisible.
///
/// ## What it deliberately is not
///
/// No chest, no reveal, no "tap to open", no burst, no currency, nothing
/// stacked or sequenced to be opened. `RULES.md` **P-6** forbids the systems
/// that presentation belongs to, and a panel that *looks* like a loot box
/// teaches the loop that a loot box exists. The one flourish is
/// [_RewardIcon] — a single scale-and-fade of art already on disk, once,
/// never looping.
class _ResultPanel extends StatefulWidget {
  const _ResultPanel({
    super.key,
    required this.report,
    required this.outcome,
    required this.controller,
  });

  final CombatReport report;
  final CombatBeat outcome;
  final SessionController controller;

  @override
  State<_ResultPanel> createState() => _ResultPanelState();
}

class _ResultPanelState extends State<_ResultPanel>
    with SingleTickerProviderStateMixin {
  /// One controller for the whole panel, sliced by [Interval] per row, rather
  /// than one controller and one delayed callback per row.
  ///
  /// Deterministic by construction: with a single clock the stagger is a
  /// function of the row index, so the reveal is identical on every run and a
  /// test can settle it. Per-row `Future.delayed` would put N timers in flight
  /// that outlive a dispose.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: _revealTotal(_rewardCount),
  );

  /// Resolved from the ambient `MediaQuery`, so it is read in
  /// [didChangeDependencies] and not in `initState`.
  bool _started = false;

  int get _rewardCount => switch (widget.outcome) {
    final WonBeat w => w.drops.length,
    _ => 0,
  };

  /// One row's reveal, and the gap between two rows starting.
  static const Duration _rowDuration = Duration(milliseconds: 350);
  static const Duration _rowStagger = Duration(milliseconds: 80);

  static Duration _revealTotal(int rows) => Duration(
    milliseconds:
        _rowDuration.inMilliseconds +
        _rowStagger.inMilliseconds * (rows > 0 ? rows - 1 : 0),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Reduced motion is honoured by arriving already finished, not by playing
    // faster: the rows are the information, and the animation is the only part
    // anyone asked to be rid of.
    if (MediaQuery.disableAnimationsOf(context) || _rewardCount == 0) {
      _reveal.value = 1;
    } else {
      // One-shot. Nothing here repeats, reverses, or waits on the clock for a
      // second pass — the panel is a still image three hundred milliseconds
      // after it appears.
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  /// The slice of [_reveal] that belongs to row [index].
  Animation<double> _rowCurve(int index) {
    final int total = _revealTotal(_rewardCount).inMilliseconds;
    final double begin = (_rowStagger.inMilliseconds * index) / total;
    final double end = begin + _rowDuration.inMilliseconds / total;
    return CurvedAnimation(
      parent: _reveal,
      curve: Interval(begin, end > 1 ? 1 : end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CombatBeat outcome = widget.outcome;
    final String heading = switch (outcome) {
      WonBeat() => 'Victory',
      LostBeat() => 'Driven back',
      RetreatedBeat() => 'Retreated',
      _ => 'Encounter over',
    };
    // Victory itemises; the two retreats say where the player now is and that
    // nothing was lost, in the log's own words — unchanged.
    final List<Widget> body = switch (outcome) {
      final WonBeat o => _victory(o),
      _ => <Widget>[
        Text(
          describeBeat(outcome, widget.report.enemyName),
          style: StrideType.body,
          maxLines: 4,
        ),
      ],
    };
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Victory gets the headline weight a win deserves — the card title,
          // not a section eyebrow; the two retreats keep the quieter heading,
          // because losing nothing is not an event to celebrate.
          if (outcome is WonBeat)
            AdaptiveText(heading.toUpperCase(), style: StrideType.cardTitle)
          else
            SectionHeading(label: heading),
          const SizedBox(height: StrideSpace.s10),
          ...body,
          const SizedBox(height: StrideSpace.s12),
          // Primary and full width: it is the only thing to do here, and the
          // acknowledgement is what clears the report and returns the cards.
          // `acknowledgeCombat` is idempotent — a second tap on a panel that
          // is already gone would find no report and do nothing.
          StrideButton(
            label: 'Continue',
            onPressed: widget.controller.acknowledgeCombat,
          ),
        ],
      ),
    );
  }

  List<Widget> _victory(WonBeat o) => <Widget>[
    Text(
      '${widget.report.enemyName} falls.',
      style: StrideType.body,
      maxLines: 2,
    ),
    const SizedBox(height: StrideSpace.s10),
    // The experience, on its own ground.
    SurfaceBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('EXPERIENCE', style: StrideType.microLabel, maxLines: 1),
          const SizedBox(height: StrideSpace.s4),
          AdaptiveText('+${o.xp} XP', style: StrideType.numericValue),
          if (o.levelledUp) ...<Widget>[
            const SizedBox(height: StrideSpace.s2),
            AdaptiveText(
              'Level ${o.levelAfter}!',
              style: StrideType.sub,
              color: StrideColors.textPrimary,
            ),
          ],
        ],
      ),
    ),
    const SizedBox(height: StrideSpace.s12),
    const Text('REWARDS', style: StrideType.microLabel, maxLines: 1),
    const SizedBox(height: StrideSpace.s6),
    if (o.drops.isEmpty)
      // Quiet, and never an apology. Nothing was lost and nothing is owed;
      // the drop tables are chances, and a chance that did not land is a fact
      // rather than a failure (`RULES.md` P-5, P-7).
      const Text('No drops this time.', style: StrideType.micro, maxLines: 2)
    else
      for (int i = 0; i < o.drops.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(height: StrideSpace.s6),
        _RewardRow(line: o.drops[i], reveal: _rowCurve(i)),
      ],
  ];
}

/// One dropped item: its icon, its name in its rarity's ink, the rarity word,
/// and how many — inside a 1 px frame of the same rarity's accent.
///
/// The quantity is [StrideType.itemCount], the same role the inventory grid
/// gives `×24`, so `×2` here and `×2` there are the same object.
///
/// ## Why the badge is on its own line
///
/// It shared the name's column first, and that column is what is left of the
/// row after a 48 px icon and a three-digit count. At 320 dp and text scale 1.4
/// it comes to about 93 dp, and `LEGENDARY` — the longest of the five words,
/// and the rank nothing carries yet, so nobody would have found this on a
/// device — needs 131.4. Beneath the name it has the frame's full width less
/// the icon indent, which is 184 dp in the same case.
class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.line, required this.reveal});

  final RewardLine line;
  final Animation<double> reveal;

  /// The icon's edge plus its gap: what the badge is indented by, so the word
  /// starts under the name rather than under the picture.
  static const double _nameIndent = 48 + StrideSpace.s10;

  @override
  Widget build(BuildContext context) => RarityFrame(
    rarity: line.rarity,
    padding: const EdgeInsets.all(StrideSpace.s8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // `itemFor` never returns null: an item this icon set does not
            // cover yet — the new pelts and jerkins, until the lead packages
            // them — gets the deliberately non-representational slab, and the
            // name beside it carries the meaning (**L-17**).
            _RewardIcon(assetPath: PixelIcons.itemFor(line.id), reveal: reveal),
            const SizedBox(width: StrideSpace.s10),
            Expanded(
              // Wrapping, because this is the narrowest full-width name
              // surface in the app: at 320 dp the name column is 116 dp and
              // `Frost-lined Jerkin` needs 198.9 at this role. A name is
              // prose; it takes the second line rather than the smaller type.
              child: RarityName.wrapping(
                name: line.name,
                rarity: line.rarity,
                style: StrideType.sub,
              ),
            ),
            const SizedBox(width: StrideSpace.s8),
            AdaptiveText('×${line.quantity}', style: StrideType.itemCount),
          ],
        ),
        // The word, always. Colour is never the only carrier.
        if (line.rarity != null) ...<Widget>[
          const SizedBox(height: StrideSpace.s6),
          Padding(
            padding: const EdgeInsets.only(left: _nameIndent),
            child: Align(
              alignment: Alignment.centerLeft,
              child: RarityBadge(rarity: line.rarity),
            ),
          ),
        ],
      ],
    ),
  );
}

/// The one flourish: an approved 48 px item icon, scaled and faded in once.
///
/// **A-2, and nothing more.** This invents no object, no silhouette, no frame
/// and no illustrated content — it is a deterministic transformation of art
/// PixelLab already made, played once. It does not loop, it does not bounce
/// past 1, and there is no second element on screen that exists only to move.
///
/// [FadeTransition] and [ScaleTransition] rather than an [AnimatedBuilder]
/// around the sprite: both rebuild nothing, so the `Image` is decoded once and
/// the transform runs on the layer.
class _RewardIcon extends StatelessWidget {
  const _RewardIcon({required this.assetPath, required this.reveal});

  final String assetPath;
  final Animation<double> reveal;

  /// The scale it starts from. **0.86, not 0** — a sprite scaled from nothing
  /// is resampled through every fractional size on the way up, and this is
  /// pixel art whose whole reason for existing is landing on whole pixels. A
  /// short, shallow move reads as arrival without ever putting the icon far
  /// off its integer multiple for long.
  static const double _from = 0.86;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: reveal,
    child: ScaleTransition(
      scale: Tween<double>(begin: _from, end: 1).animate(reveal),
      child: PixelAsset.item(assetPath),
    ),
  );
}
