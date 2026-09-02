/// The Skill Detail screen — one profession's whole plannable future
/// (Fable V2 Iteration 03).
///
/// ## What this adds over the card
///
/// The Skills card is the glance: level, bar, the next three unlock lines.
/// This route is the depth the owner asked to plan with: **every** level
/// from 1 to the last one content touches, each unlock joined to what it
/// yields, what that feeds, and what still gates it — so "what do I want
/// to level next" is answered by reading, not by walking somewhere to find
/// out.
///
/// ## Why a pushed route
///
/// A twelve-level roadmap is a document. Expanded inline, one card would
/// push the other four trades two screens down and the tab would stop
/// being a set of five professions — the compare-at-a-glance job the
/// device feedback accepted. Pushed (the `StepTrackerScreen.open`
/// pattern), the roadmap gets its own scroll and the system back gesture
/// is the one-handed exit.
///
/// ## Every fact is the projection's
///
/// `SkillRoadmap` comes from `StrideSession.skillRoadmapFor` — the same
/// `unlocksFor` ordering the card's three lines read, the same
/// `SkillDefinition` curve the engine gates with, detail lines pre-capped
/// in the projection (`RULES.md` E-2, F-07). Nothing here counts, joins,
/// or classifies.
///
/// ## Restraint rules (the UX review's caps)
///
/// A collapsed unlock row is at most two lines; expanded adds at most two
/// more and one optional Track control. Dead levels render — a skipped
/// number reads as a broken ladder — but a RUN of them collapses to one
/// muted line. The earned band folds away by default (it *is* the
/// "current benefits" answer for whoever opens it); the ladder starts the
/// player at their own level.
library;

import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/screen_header.dart';
import '../../components/stride_scaffold.dart';
import '../../components/surfaces.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import 'skills_screen.dart'
    show SkillHeaderRow, SkillProgressBar, SkillProgressCaption;

class SkillDetailScreen extends StatefulWidget {
  const SkillDetailScreen({super.key, required this.skill});

  final ContentId skill;

  /// Pushes the roadmap, re-wrapped in the pushing context's controller —
  /// the `StepTrackerScreen.open` pattern, so the route reads the same
  /// session the card did.
  static Future<void> open(BuildContext context, ContentId skill) {
    final SessionController session = SessionScope.read(context);
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionScope(
          controller: session,
          child: SkillDetailScreen(skill: skill),
        ),
      ),
    );
  }

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  /// Whether the earned band is unfolded — ephemeral presentation.
  bool _earnedOpen = false;

  /// The one expanded unlock row, by (level, name) — one open at a time,
  /// the Craft-row selection grammar.
  (int, String)? _expanded;

  @override
  Widget build(BuildContext context) {
    final SessionController controller = SessionScope.of(context);
    final SkillRoadmap? roadmap = controller.session.skillRoadmapFor(
      widget.skill,
    );

    return StrideScaffold(
      header: ScreenHeader(
        eyebrow: 'SKILLS',
        title: roadmap?.standing.displayName ?? 'Skill',
        trailing: Semantics(
          button: true,
          label: 'Close',
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
      body: roadmap == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                StrideSpace.screenGutter,
                StrideSpace.s12,
                StrideSpace.screenGutter,
                StrideSpace.s16,
              ),
              children: <Widget>[
                SectionCard(
                  wash: StrideColors.forSkillDeep(widget.skill),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SkillHeaderRow(standing: roadmap.standing),
                      const SizedBox(height: StrideSpace.s12),
                      SkillProgressBar(standing: roadmap.standing),
                      const SizedBox(height: StrideSpace.s8),
                      SkillProgressCaption(standing: roadmap.standing),
                      const SizedBox(height: StrideSpace.s8),
                      Text(
                        roadmap.totalCount == 0
                            ? 'Nothing in this content pack uses it yet.'
                            : '${roadmap.openCount} of ${roadmap.totalCount} '
                                  'unlocks open',
                        style: StrideType.micro.copyWith(
                          color: StrideColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (roadmap.levels.isNotEmpty) ...<Widget>[
                  const SizedBox(height: StrideSpace.cardGap),
                  const SectionHeading(label: 'Roadmap'),
                  const SizedBox(height: StrideSpace.s8),
                  SectionCard(
                    padding: const EdgeInsets.all(
                      StrideSpace.cardPaddingCompact,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _NextBlock(roadmap: roadmap),
                        _Ladder(
                          roadmap: roadmap,
                          skill: widget.skill,
                          earnedOpen: _earnedOpen,
                          onToggleEarned: () =>
                              setState(() => _earnedOpen = !_earnedOpen),
                          expanded: _expanded,
                          onToggleRow: ((int, String) key) => setState(
                            () => _expanded = _expanded == key ? null : key,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// The next three things this trade opens, at the top of the roadmap.
///
/// **These are the lines the Skills spine gave up** (FMPO02, `ART-12` §4).
/// The spine answers *where am I* in 64 dp; the three lines it used to carry
/// answer *what next*, and this route is where that question was already
/// being answered at length. Put at the head of the ladder rather than left
/// to be reconstructed from it: the ladder is ordered by level and a player
/// asking "what is next" should not have to scan twelve bands to find the
/// three that are.
///
/// Nothing is computed here. The entries are the projection's own, in the
/// projection's own order (`RULES.md` E-2, F-07).
class _NextBlock extends StatelessWidget {
  const _NextBlock({required this.roadmap});

  final SkillRoadmap roadmap;

  /// `Level 3 opens Duskcap Grove at Whispering Woods`, with the extra gate
  /// said where one exists — `Level 2 + a contract at Haven's Rest opens
  /// Wolfhide Jerkin` — so the block never promises what the level alone
  /// cannot deliver.
  static String lineFor(SkillUnlock u) {
    final String level = u.gate == null
        ? 'Level ${u.requiredLevel}'
        : 'Level ${u.requiredLevel} + ${u.gate}';
    final String where = u.where == null ? '' : ' at ${u.where}';
    return '$level opens ${u.displayName}$where';
  }

  @override
  Widget build(BuildContext context) {
    final List<SkillUnlock> upcoming = <SkillUnlock>[
      for (final RoadmapLevel level in roadmap.levels)
        for (final SkillUnlock u in level.entries)
          if (!u.unlocked) u,
    ].take(3).toList();

    // "Everything open" is a real and satisfying state, and the ladder's own
    // closing line already says it — a NEXT heading over nothing would be a
    // gap where a goal used to be.
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'NEXT',
          style: StrideType.microLabel.copyWith(
            color: StrideColors.textSecondary,
          ),
        ),
        const SizedBox(height: StrideSpace.s4),
        for (final (int i, SkillUnlock u) in upcoming.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : StrideSpace.s4),
            child: Text(
              lineFor(u),
              style: StrideType.micro.copyWith(
                // The nearest rung carries the emphasis; the ones behind it
                // are the road ahead, quieter.
                color: i == 0
                    ? StrideColors.textSecondary
                    : StrideColors.textMuted,
              ),
            ),
          ),
        Container(
          height: 1,
          margin: const EdgeInsets.only(
            top: StrideSpace.s8,
            bottom: StrideSpace.s4,
          ),
          color: StrideColors.separator,
        ),
      ],
    );
  }
}

/// The ladder: the earned fold, then every level from the current one to
/// the horizon, dead runs collapsed.
class _Ladder extends StatelessWidget {
  const _Ladder({
    required this.roadmap,
    required this.skill,
    required this.earnedOpen,
    required this.onToggleEarned,
    required this.expanded,
    required this.onToggleRow,
  });

  final SkillRoadmap roadmap;
  final ContentId skill;
  final bool earnedOpen;
  final VoidCallback onToggleEarned;
  final (int, String)? expanded;
  final ValueChanged<(int, String)> onToggleRow;

  @override
  Widget build(BuildContext context) {
    final List<RoadmapLevel> earned = roadmap.levels
        .where((RoadmapLevel l) => l.state == RoadmapLevelState.earned)
        .toList();
    final int earnedUnlocks = earned.fold(
      0,
      (int a, RoadmapLevel l) => a + l.entries.length,
    );
    final List<RoadmapLevel> ahead = roadmap.levels
        .where((RoadmapLevel l) => l.state != RoadmapLevelState.earned)
        .toList();

    final List<Widget> rows = <Widget>[];

    // The earned band, folded by default (the Sync-details grammar): it is
    // the "current benefits" answer, not the plan.
    if (earned.isNotEmpty) {
      rows.add(
        Semantics(
          button: true,
          label: earnedOpen ? 'Hide earned levels' : 'Show earned levels',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggleEarned,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: StrideSpace.s8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'LEVELS 1–${earned.last.level}'
                      '${earnedUnlocks > 0 ? ' · $earnedUnlocks earned' : ''}',
                      style: StrideType.microLabel.copyWith(
                        color: StrideColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    earnedOpen ? 'HIDE' : 'SHOW',
                    style: StrideType.microLabel.copyWith(
                      color: StrideColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (earnedOpen) {
        for (final RoadmapLevel level in earned) {
          if (level.entries.isEmpty) continue;
          rows.add(_LevelBand(level: level, skill: skill));
          for (final SkillUnlock u in level.entries) {
            rows.add(
              _UnlockRow(
                level: level,
                unlock: u,
                expanded: expanded == (level.level, u.displayName),
                onTap: () => onToggleRow((level.level, u.displayName)),
              ),
            );
          }
        }
      }
      rows.add(
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: StrideSpace.s4),
          color: StrideColors.separator,
        ),
      );
    }

    // The road from here: dead RUNS collapse to one muted line; a single
    // dead level keeps its own line so the ladder never skips a number.
    int i = 0;
    while (i < ahead.length) {
      final RoadmapLevel level = ahead[i];
      if (level.entries.isEmpty && level.state != RoadmapLevelState.current) {
        int j = i;
        while (j + 1 < ahead.length &&
            ahead[j + 1].entries.isEmpty &&
            ahead[j + 1].state != RoadmapLevelState.current) {
          j++;
        }
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: StrideSpace.s4),
            child: Text(
              j == i
                  ? 'LV ${level.level} · nothing yet'
                  : 'LV ${level.level}–${ahead[j].level} · nothing yet',
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            ),
          ),
        );
        i = j + 1;
        continue;
      }
      rows.add(_LevelBand(level: level, skill: skill));
      if (level.entries.isEmpty) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: StrideSpace.s4),
            child: Text(
              'Nothing new at this level.',
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            ),
          ),
        );
      }
      for (final SkillUnlock u in level.entries) {
        rows.add(
          _UnlockRow(
            level: level,
            unlock: u,
            expanded: expanded == (level.level, u.displayName),
            onTap: () => onToggleRow((level.level, u.displayName)),
          ),
        );
      }
      i++;
    }

    // The honest end of the road (`DECISIONS/0028` §6): the ladder used to
    // stop silently at the last content level, indistinguishable from a
    // cap. One muted line says which it is — and when every unlock is open,
    // the census line becomes the closure statement.
    if (roadmap.contentHorizon > 0 &&
        roadmap.contentHorizon < roadmap.maxLevel) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: StrideSpace.s8),
          child: Text(
            roadmap.horizonReached
                ? 'Every written unlock is open. The road runs out here — '
                      'nothing is written above LV ${roadmap.contentHorizon} '
                      'yet.'
                : 'The road runs out here — nothing is written above '
                      'LV ${roadmap.contentHorizon} yet.',
            style: StrideType.micro.copyWith(color: StrideColors.textMuted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// One level's band: the number, its standing, and — on the next band with
/// content only — the true XP distance.
class _LevelBand extends StatelessWidget {
  const _LevelBand({required this.level, required this.skill});

  final RoadmapLevel level;
  final ContentId skill;

  @override
  Widget build(BuildContext context) {
    final Color accent = StrideColors.forSkill(skill);
    final bool current = level.state == RoadmapLevelState.current;
    final bool next = level.state == RoadmapLevelState.next;

    return Padding(
      padding: const EdgeInsets.only(
        top: StrideSpace.s8,
        bottom: StrideSpace.s4,
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: StrideSpace.s6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: current
                  ? StrideColors.forSkillDeep(skill)
                  : StrideColors.surfaceBlock,
              border: Border.all(
                color: current ? accent : StrideColors.borderDefault,
              ),
              borderRadius: StrideRadius.chip,
            ),
            child: Text(
              'LV ${level.level}',
              style: StrideType.microLabel.copyWith(
                color: current
                    ? accent
                    : next
                    ? StrideColors.textPrimary
                    : StrideColors.textMuted,
              ),
            ),
          ),
          if (current) ...<Widget>[
            const SizedBox(width: StrideSpace.s6),
            Text('NOW', style: StrideType.microLabel.copyWith(color: accent)),
          ],
          const Spacer(),
          if (level.xpAway case final int away)
            Text(
              '$away XP away',
              style: StrideType.micro.copyWith(
                color: StrideColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// One unlock: two lines collapsed, at most two more expanded, and the
/// Track control when there is an item to pursue.
class _UnlockRow extends StatelessWidget {
  const _UnlockRow({
    required this.level,
    required this.unlock,
    required this.expanded,
    required this.onTap,
  });

  final RoadmapLevel level;
  final SkillUnlock unlock;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool earned = unlock.unlocked;
    final bool future = level.state == RoadmapLevelState.future;
    final Color ink = earned
        ? StrideColors.textSecondary
        : future
        ? StrideColors.textMuted
        : StrideColors.textPrimary;
    final bool expandable = unlock.detailLines.isNotEmpty;

    final Widget head = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AdaptiveText(
          unlock.where == null
              ? unlock.displayName
              : '${unlock.displayName} at ${unlock.where}',
          style: StrideType.sub,
          color: ink,
        ),
        if (unlock.gate case final String gate)
          Text(
            'Also needs $gate',
            style: StrideType.micro.copyWith(color: StrideColors.textMuted),
          ),
      ],
    );

    return Semantics(
      button: expandable,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: expandable ? onTap : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: StrideSpace.s4),
          padding: const EdgeInsets.symmetric(
            horizontal: StrideSpace.s8,
            vertical: StrideSpace.s6,
          ),
          constraints: const BoxConstraints(minHeight: 44),
          decoration: BoxDecoration(
            color: expanded
                ? StrideColors.surfaceRaised
                : StrideColors.surfaceBlock,
            border: Border.all(
              color: expanded
                  ? StrideColors.actionEdge
                  : StrideColors.borderDefault,
            ),
            borderRadius: StrideRadius.inner,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              head,
              if (expanded) ...<Widget>[
                const SizedBox(height: StrideSpace.s6),
                for (final String line in unlock.detailLines)
                  Text(
                    line,
                    style: StrideType.micro.copyWith(
                      color: StrideColors.textSecondary,
                    ),
                  ),
                if (unlock.trackableItem case final ContentId item) ...<Widget>[
                  const SizedBox(height: StrideSpace.s6),
                  StrideButton.secondary(
                    label: 'Track as Pursuit',
                    onPressed: () =>
                        SessionScope.read(context).trackGoalPursuit(item),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
