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
/// keeps a compact card, and the full surface gets its own screen without a
/// permanent tab. The pushed screen is re-wrapped in the pushing context's
/// controllers (`goal_board_screen.dart` documents the scope re-wrap).
library;

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';

import '../../../runtime/stride_session.dart';
import '../../components/data_display.dart';
import '../../components/screen_header.dart';
import '../../components/surfaces.dart';
import '../../components/walking_glyph.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import 'steps_block.dart' show syncedLabel;

class StepTrackerScreen extends StatefulWidget {
  const StepTrackerScreen({super.key});

  /// Pushes the tracker, re-wrapped in the pushing context's controller.
  static Future<void> open(BuildContext context) {
    final SessionController session = SessionScope.read(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionScope(
          controller: session,
          child: const StepTrackerScreen(),
        ),
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

    return ColoredBox(
      color: StrideColors.surfaceGround,
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
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                StrideSpace.screenGutter,
                StrideSpace.s12,
                StrideSpace.screenGutter,
                StrideSpace.s16 + inset.bottom,
              ),
              children: <Widget>[
                // The span toggle: two words, one selected.
                Row(
                  children: <Widget>[
                    _SpanChip(
                      label: 'Day',
                      selected: _span == _Span.day,
                      onTap: () => setState(() => _span = _Span.day),
                    ),
                    const SizedBox(width: StrideSpace.s6),
                    _SpanChip(
                      label: 'Week',
                      selected: _span == _Span.week,
                      onTap: () => setState(() => _span = _Span.week),
                    ),
                  ],
                ),
                const SizedBox(height: StrideSpace.cardGap),

                if (_span == _Span.day)
                  _DayCard(history: history)
                else
                  _WeekCard(history: history),
                const SizedBox(height: StrideSpace.cardGap),

                // The forensic surface (Fable V2 Iteration 02, Q-08): why
                // today's figure is what it is, per pseudonymous source —
                // collapsed by default so the tracker stays a tracker.
                _DiagnosticsCard(controller: c),
                const SizedBox(height: StrideSpace.cardGap),

                // Freshness, and the one control that changes it. The
                // tracker exists to make step state trustworthy, and
                // "trustworthy" is a timestamp plus the button that moves
                // it.
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SectionHeading(label: 'Sync'),
                      const SizedBox(height: StrideSpace.s8),
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
                      StrideButton.secondary(
                        label: c.busy ? 'Checking…' : 'Sync steps',
                        onPressed: c.busy || !c.session.isReady
                            ? null
                            : c.syncSteps,
                      ),
                    ],
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
class _DiagnosticsCard extends StatefulWidget {
  const _DiagnosticsCard({required this.controller});

  final SessionController controller;

  @override
  State<_DiagnosticsCard> createState() => _DiagnosticsCardState();
}

class _DiagnosticsCardState extends State<_DiagnosticsCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final SyncDiagnosticsView d = widget.controller.session.syncDiagnostics();
    final SyncReport? last = widget.controller.lastSync;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            button: true,
            label: _open ? 'Hide sync details' : 'Show sync details',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = !_open),
              child: SectionHeading(
                label: 'Sync details',
                trailing: Text(
                  _open ? 'HIDE' : 'SHOW',
                  style: StrideType.microLabel.copyWith(
                    color: StrideColors.textSecondary,
                  ),
                ),
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
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
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
                style: StrideType.micro.copyWith(
                  color: StrideColors.textMuted,
                ),
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
      ),
    );
  }

  static Widget _factRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: StrideSpace.s2),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: StrideType.micro.copyWith(
              color: StrideColors.textSecondary,
            ),
            maxLines: 1,
          ),
        ),
        Text(
          value,
          style: StrideType.micro.copyWith(
            color: StrideColors.textPrimary,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
          maxLines: 1,
        ),
      ],
    ),
  );
}

/// Today: the headline figure, then the hours that earned it.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.history});

  final StepHistory history;

  @override
  Widget build(BuildContext context) {
    final List<StepHourLine> hours = history.hoursToday;
    final int max = hours.fold(
      0,
      (int a, StepHourLine h) => h.granted > a ? h.granted : a,
    );

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeading(
            label: 'Today',
            trailing: const WalkingGlyph(role: WalkingRole.stock),
          ),
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
      ),
    );
  }

  static String _hourLabel(int startMillis) {
    final DateTime t = DateTime.fromMillisecondsSinceEpoch(startMillis);
    return '${t.hour.toString().padLeft(2, '0')}:00';
  }
}

/// The week: seven days, oldest first, today emphasised.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.history});

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
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeading(
            label: 'This week',
            trailing: Text(
              '${formatSteps(history.week)} steps',
              style: StrideType.micro.copyWith(
                color: StrideColors.textPrimary,
                fontSize: 12.5,
              ),
            ),
          ),
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
      ),
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
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// Day / Week, as the app's one chip shape.
class _SpanChip extends StatelessWidget {
  const _SpanChip({
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
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: StrideSpace.s10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: selected
              ? StrideColors.surfaceRaised
              : StrideColors.surfaceBlock,
          border: Border.all(
            color: selected
                ? StrideColors.accentSteps
                : StrideColors.borderDefault,
          ),
          borderRadius: StrideRadius.chip,
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
  );
}
