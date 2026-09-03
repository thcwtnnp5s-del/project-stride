/// The Step Tracker — the full day/week view behind the Character tab's
/// Steps card (the physical-device polish pass, item 1; `DECISIONS/0026`).
///
/// ## What it is, and is not
///
/// A clean read of what the game has credited: today by hour, the week by
/// day, when the store was last read, and the lifetime context line. It is
/// **not** a health app — no goals, no streaks, no rings, nothing that
/// scolds an empty day (`RULES.md` P-5: absence is never punished, and a
/// tracker that makes a quiet day look like a fault would be exactly that).
///
/// Every figure is the session's `stepHistory()` projection; the bars are
/// drawn from those figures and nothing else. Days the ledger has compacted
/// are absent, and the screen says so rather than drawing them as zero.
///
/// ## Why a pushed route
///
/// Same reasoning and same mechanics as the Goal Board: the Character tab
/// keeps a compact foot to its ledger, and the full surface gets its own
/// screen without a permanent tab. The pushed screen is re-wrapped in the
/// pushing context's controllers (`goal_board_screen.dart` documents the
/// scope re-wrap).
///
/// ## The same folio, one leaf further in (EPO03, `DIR-05`)
///
/// The tracker was four stacked [SectionCard]s on a flat ground — the shape
/// the Character tab has just stopped being, on the screen that opens from
/// it. It is now the same page: a bound `journalLeaf` [PageGround], sections
/// opened by a [KitRule] rather than boxed in a card, and Day / Week as two
/// folio index tabs rather than two grey pills. Every figure, every
/// projection and the sync command itself are untouched.
library;

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';

import '../../../audio/audio_controller.dart';
import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/panel_skin.dart';
import '../../components/screen_header.dart';
import '../../components/surfaces.dart';
import '../../components/walking_glyph.dart';
import '../../state/audio_scope.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import 'steps_block.dart' show syncedLabel;

/// The bound edge plus a breath, exactly as the Character folio spends it —
/// the tracker is the same book, so its inner margin is the same figure.
double get _spineGutter =>
    KitTiles.thicknessFor(KitTile.edgeSpine) + StrideSpace.s8;

class StepTrackerScreen extends StatefulWidget {
  const StepTrackerScreen({super.key});

  /// Pushes the tracker, re-wrapped in the pushing context's controller.
  static Future<void> open(BuildContext context) {
    final SessionController session = SessionScope.read(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SessionScope(controller: session, child: const StepTrackerScreen()),
      ),
    );
  }

  @override
  State<StepTrackerScreen> createState() => _StepTrackerScreenState();
}

enum _Span { day, week }

class _StepTrackerScreenState extends State<StepTrackerScreen> {
  _Span _span = _Span.week;

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StepHistory history = c.session.stepHistory();
    final EdgeInsets inset = MediaQuery.viewPaddingOf(context);

    return PageGround(
      surface: PanelSurface.journalLeaf,
      child: Column(
        children: <Widget>[
          SizedBox(height: inset.top),
          ScreenHeader(
            eyebrow: 'Character',
            title: 'Step Tracker',
            trailing: Semantics(
              button: true,
              label: 'Close the Step Tracker',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.all(StrideSpace.s8),
                  child: Text(
                    'CLOSE',
                    style: StrideType.microLabel.copyWith(
                      color: StrideColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: <Widget>[
                ListView(
                  padding: EdgeInsets.fromLTRB(
                    _spineGutter,
                    StrideSpace.s12,
                    StrideSpace.screenGutter,
                    StrideSpace.s16 + inset.bottom,
                  ),
                  children: <Widget>[
                    // The span, as two index tabs on the folio's edge. It was
                    // two grey pills, which is `DIR-05`'s third failure — one
                    // chip shape carrying six meanings — and a span is exactly
                    // what an index tab is for: which leaf of the same record
                    // is open.
                    Row(
                      children: <Widget>[
                        _SpanTab(
                          label: 'Day',
                          selected: _span == _Span.day,
                          onTap: () => setState(() => _span = _Span.day),
                        ),
                        const SizedBox(width: StrideSpace.s6),
                        _SpanTab(
                          label: 'Week',
                          selected: _span == _Span.week,
                          onTap: () => setState(() => _span = _Span.week),
                        ),
                      ],
                    ),
                    const SizedBox(height: StrideSpace.rhythmHero),

                    if (_span == _Span.day)
                      _DayLeaf(history: history)
                    else
                      _WeekLeaf(history: history),
                    const SizedBox(height: StrideSpace.rhythmHero),

                    // The forensic surface (Fable V2 Iteration 02, Q-08): why
                    // today's figure is what it is, per pseudonymous source —
                    // collapsed by default so the tracker stays a tracker.
                    _DiagnosticsLeaf(controller: c),
                    const SizedBox(height: StrideSpace.rhythmHero),

                    // Freshness, and the one control that changes it. The
                    // tracker exists to make step state trustworthy, and
                    // "trustworthy" is a timestamp plus the button that moves
                    // it.
                    const KitRule(title: 'Sync'),
                    const SizedBox(height: StrideSpace.rhythmRow),
                    Text(
                      <String>[
                        syncedLabel(history),
                        if (history.originCount > 1)
                          '${history.originCount} sources contribute',
                      ].join(' · '),
                      style: StrideType.sub.copyWith(
                        color: StrideColors.textSecondary,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: StrideSpace.s4),
                    Text(
                      'Figures show steps the game has credited. Days '
                      'older than a week are folded into the lifetime '
                      'total.',
                      style: StrideType.micro.copyWith(
                        color: StrideColors.textMuted,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: StrideSpace.s4),
                    Text(
                      'Lifetime credited: '
                      '${formatSteps(history.lifetimeGranted)} steps',
                      style: StrideType.micro.copyWith(
                        color: StrideColors.textSecondary,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: StrideSpace.s8),
                    // **The one primary plate on this screen** (`DIR-05` §1),
                    // and the call inside it is untouched: same guard, same
                    // `syncSteps`, same single light tap only when the walk
                    // actually banked.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StrideButton.secondary(
                        label: c.busy ? 'Checking…' : 'Sync steps',
                        // Same rule as the Adventure band's sync: one light
                        // tap only when the walk actually banked.
                        onPressed: c.busy || !c.session.isReady
                            ? null
                            : () async {
                                final AudioController audio = AudioScope.read(
                                  context,
                                );
                                await c.syncSteps();
                                if ((c.lastSync?.newlyGranted ?? 0) > 0) {
                                  audio.hapticLight();
                                }
                              },
                      ),
                    ),
                  ],
                ),
                // The binding, drawn as the folio's is and for the same
                // reason (`character_screen.dart`, `REQUESTS_NAV.md`
                // 2026-09-03).
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: KitTiles.thicknessFor(KitTile.edgeSpine),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: StrideColors.surfaceGround,
                      border: Border(
                        right: BorderSide(color: StrideColors.borderDefault),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The expandable sync-forensics card (Fable V2 Iteration 02).
///
/// Everything here is [StrideSession.syncDiagnostics] — data the ledger
/// already persists, folded read-only. Sources are positional labels in
/// stable order; no identifier is ever shown (`RULES.md` H-7). The owner
/// identifies a source by holding its figure against the app that wrote it
/// — the comparison this card exists to enable.
class _DiagnosticsLeaf extends StatefulWidget {
  const _DiagnosticsLeaf({required this.controller});

  final SessionController controller;

  @override
  State<_DiagnosticsLeaf> createState() => _DiagnosticsLeafState();
}

class _DiagnosticsLeafState extends State<_DiagnosticsLeaf> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final SyncDiagnosticsView d = widget.controller.session.syncDiagnostics();
    final SyncReport? last = widget.controller.lastSync;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          label: _open ? 'Hide sync details' : 'Show sync details',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _open = !_open),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: AdaptiveText(
                        'Sync details',
                        style: StrideType.sectionHeading,
                      ),
                    ),
                    Text(
                      _open ? 'HIDE' : 'SHOW',
                      style: StrideType.microLabel.copyWith(
                        color: StrideColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: StrideSpace.rowGap),
                const KitRule(),
              ],
            ),
          ),
        ),
        if (!_open) ...<Widget>[
          const SizedBox(height: StrideSpace.s4),
          Text(
            d.multiSource
                ? '${d.perOrigin.length} sources credited today — open '
                      'for the split.'
                : 'What was read, what was credited, and why.',
            style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            maxLines: 2,
          ),
        ] else ...<Widget>[
          const SizedBox(height: StrideSpace.s8),

          // TODAY, per source — the forensic headline.
          Text('TODAY CREDITED', style: StrideType.microLabel, maxLines: 1),
          const SizedBox(height: StrideSpace.s2),
          Text(
            formatSteps(d.todayTotal),
            style: StrideType.numericValue.copyWith(
              color: StrideColors.accentSteps,
            ),
          ),
          if (d.perOrigin.isNotEmpty) ...<Widget>[
            const SizedBox(height: StrideSpace.s6),
            for (final OriginDiagnosticsLine line in d.perOrigin)
              Padding(
                padding: const EdgeInsets.only(bottom: StrideSpace.s2),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${line.label}'
                        '${line.settledToWatermark ? '' : ' · not yet vouched complete'}',
                        style: StrideType.micro.copyWith(
                          color: StrideColors.textSecondary,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    Text(
                      '${formatSteps(line.todayGranted)} today · '
                      '${formatSteps(line.retainedGranted)} this week',
                      style: StrideType.micro.copyWith(
                        color: StrideColors.textPrimary,
                        fontFeatures: StrideType.tabularFigures,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
          ],
          if (d.multiSource) ...<Widget>[
            const SizedBox(height: StrideSpace.s4),
            Text(
              'Two apps recorded the same walking. Apple Health merges '
              'them into one headline; Stride credits each source\'s own '
              'record, so its total can be higher. Compare each figure '
              'against Health\'s Sources list to see who is who.',
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
              maxLines: 5,
            ),
          ],

          // The last sync, as it reported itself.
          if (last != null) ...<Widget>[
            const SizedBox(height: StrideSpace.s10),
            Text('LAST SYNC', style: StrideType.microLabel, maxLines: 1),
            const SizedBox(height: StrideSpace.s4),
            _factRow('Read from Health', formatSteps(last.observedSteps)),
            _factRow('Newly credited', formatSteps(last.newlyGranted)),
            _factRow('Sources seen', '${last.originCount}'),
          ],

          // The ledger, lifetime.
          const SizedBox(height: StrideSpace.s10),
          Text('LEDGER', style: StrideType.microLabel, maxLines: 1),
          const SizedBox(height: StrideSpace.s4),
          _factRow('Observed, lifetime', formatSteps(d.totalObserved)),
          _factRow('Credited, lifetime', formatSteps(d.totalGranted)),
          _factRow('Spent, lifetime', formatSteps(d.totalSpent)),
          _factRow('Banked now', formatSteps(d.banked)),
          if (d.retiredSteps > 0)
            _factRow('Retired by playtest epochs', formatSteps(d.retiredSteps)),
          _factRow('Syncs committed', '${d.syncCount}'),
          _factRow('Resume bookmark', d.cursorPresent ? 'held' : 'none'),
          if (d.grantedAheadOfObserved > 0)
            _factRow(
              'Credited ahead of observed',
              formatSteps(d.grantedAheadOfObserved),
            ),
          if (d.lateDiscardedSlices > 0)
            _factRow('Too-late records set aside', '${d.lateDiscardedSlices}'),
          if (d.correctionsObserved > 0)
            _factRow('Downward revisions seen', '${d.correctionsObserved}'),
          if (d.unreachableGapEvents > 0)
            _factRow('Unreachable gaps', '${d.unreachableGapEvents}'),
        ],
      ],
    );
  }

  static Widget _factRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: StrideSpace.s2),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: StrideType.micro.copyWith(color: StrideColors.textSecondary),
            maxLines: 1,
          ),
        ),
        Text(
          value,
          style: StrideType.micro.copyWith(
            color: StrideColors.textPrimary,
            fontFeatures: StrideType.tabularFigures,
          ),
          maxLines: 1,
        ),
      ],
    ),
  );
}

/// Today: the headline figure, then the hours that earned it.
class _DayLeaf extends StatelessWidget {
  const _DayLeaf({required this.history});

  final StepHistory history;

  @override
  Widget build(BuildContext context) {
    final List<StepHourLine> hours = history.hoursToday;
    final int max = hours.fold(
      0,
      (int a, StepHourLine h) => h.granted > a ? h.granted : a,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: AdaptiveText('Today', style: StrideType.sectionHeading),
            ),
            const WalkingGlyph(role: WalkingRole.stock),
          ],
        ),
        const SizedBox(height: StrideSpace.rowGap),
        const KitRule(),
        const SizedBox(height: StrideSpace.s6),
        Text(
          formatSteps(history.today.granted),
          style: StrideType.numericHero.copyWith(
            color: StrideColors.accentSteps,
          ),
        ),
        const Text('steps credited', style: StrideType.micro),
        if (hours.isNotEmpty) ...<Widget>[
          const SizedBox(height: StrideSpace.s10),
          for (final StepHourLine hour in hours) ...<Widget>[
            _BarRow(
              label: _hourLabel(hour.startMillis),
              value: hour.granted,
              max: max,
              emphasis: false,
            ),
            const SizedBox(height: StrideSpace.s4),
          ],
        ] else ...<Widget>[
          const SizedBox(height: StrideSpace.s10),
          Text(
            'Nothing credited yet today.',
            style: StrideType.micro.copyWith(color: StrideColors.textMuted),
          ),
        ],
      ],
    );
  }

  static String _hourLabel(int startMillis) {
    final DateTime t = DateTime.fromMillisecondsSinceEpoch(startMillis);
    return '${t.hour.toString().padLeft(2, '0')}:00';
  }
}

/// The week: seven days, oldest first, today emphasised.
class _WeekLeaf extends StatelessWidget {
  const _WeekLeaf({required this.history});

  final StepHistory history;

  static const List<String> _weekdays = <String>[
    'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN', //
  ];

  @override
  Widget build(BuildContext context) {
    final int max = history.days.fold(
      0,
      (int a, StepDayLine d) => d.granted > a ? d.granted : a,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: AdaptiveText(
                'This week',
                style: StrideType.sectionHeading,
              ),
            ),
            Text(
              '${formatSteps(history.week)} steps',
              style: StrideType.micro.copyWith(
                color: StrideColors.textPrimary,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: StrideSpace.rowGap),
        const KitRule(),
        const SizedBox(height: StrideSpace.s10),
        for (final StepDayLine day in history.days) ...<Widget>[
          _BarRow(
            label: day.isToday
                ? 'TODAY'
                : _weekdays[DateTime.fromMillisecondsSinceEpoch(
                        day.startOfDayMillis,
                      ).weekday -
                      1],
            value: day.granted,
            max: max,
            emphasis: day.isToday,
          ),
          const SizedBox(height: StrideSpace.s4),
        ],
      ],
    );
  }
}

/// One label, one bar, one figure — the tracker's whole chart language.
/// A zero day draws no fill, which is a fact and not a reproach.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.emphasis,
  });

  final String label;
  final int value;
  final int max;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final double fraction = max <= 0 ? 0 : (value / max).clamp(0.0, 1.0);
    return Row(
      children: <Widget>[
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: StrideType.microLabel.copyWith(
              color: emphasis
                  ? StrideColors.accentSteps
                  : StrideColors.textSecondary,
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(width: StrideSpace.s6),
        Expanded(
          child: Container(
            height: 8,
            decoration: const BoxDecoration(
              color: StrideColors.surfaceGround,
              borderRadius: StrideRadius.gate,
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: emphasis
                      ? StrideColors.accentSteps
                      : StrideColors.accentStepsDim,
                  borderRadius: StrideRadius.gate,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: StrideSpace.s8),
        SizedBox(
          width: 58,
          child: Text(
            formatSteps(value),
            textAlign: TextAlign.right,
            style: StrideType.micro.copyWith(
              color: value > 0
                  ? StrideColors.textPrimary
                  : StrideColors.textMuted,
              fontFeatures: StrideType.tabularFigures,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// Day / Week, as the folio's index tabs.
///
/// It was the app's one chip shape, which is `DIR-05`'s third named failure —
/// a grey pill standing for six different meanings. A span is which leaf of
/// the same record is open, and that is what an index tab says. The selected
/// tab is **raised** (the kit's lit top edge, the same light `StrideButton`
/// uses) and the unselected one is not; the ink does the rest.
///
/// Brass, never teal: a chosen leaf is not a walking quantity (L-16 repair,
/// Fable V2 Iteration 02).
class _SpanTab extends StatelessWidget {
  const _SpanTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: StrideGeometry.buttonHitFloor,
        ),
        child: KitPlate(
          frame: KitFrame.tabPlate,
          raised: selected,
          fill: selected
              ? StrideColors.surfaceRaised
              : StrideColors.surfaceBlock,
          padding: const EdgeInsets.symmetric(
            horizontal: StrideSpace.s10,
            vertical: StrideSpace.s8,
          ),
          child: Text(
            label,
            style: StrideType.compactLabel.copyWith(
              color: selected
                  ? StrideColors.textPrimary
                  : StrideColors.textSecondary,
            ),
          ),
        ),
      ),
    ),
  );
}
