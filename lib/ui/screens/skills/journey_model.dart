/// The Skills journey model (EPO03, `DIR-07`): a profession's roadmap
/// re-read as a **road** rather than a list of levels.
///
/// ## Why this is a separate, pure file
///
/// The old detail screen did its grouping inline inside `_Ladder.build` —
/// the earned fold, the dead-run collapse and the horizon line were three
/// loops tangled through widget construction, which is why none of them
/// could be tested without pumping a screen. The journey needs the same
/// grouping plus two more folds, and it needs it *before* layout, because
/// the road's joints are placed from the stop list. So the grouping is a
/// pure function over the projection, tested directly.
///
/// **Nothing is derived here.** Every level, state, entry, distance and
/// horizon is the projection's own (`StrideSession.skillRoadmapFor`,
/// `RULES.md` E-2, F-07). This file only decides what is *folded away*,
/// which is presentation and nothing else.
library;

import '../../../runtime/stride_session.dart';

/// What a joint on the road says about the walker's position.
///
/// Told apart by **shape** first (`DIR-07`): a driven waystone behind, a lit
/// lantern cairn here, a bronze-rimmed stone next, a faded stake far off.
/// State is redundant in ink, in type and in Semantics, so the raster carries
/// no state and the frame-removal test passes (L-18).
enum JoinState { reached, current, next, far }

JoinState _joinOf(RoadmapLevelState s) => switch (s) {
  RoadmapLevelState.earned => JoinState.reached,
  RoadmapLevelState.current => JoinState.current,
  RoadmapLevelState.next => JoinState.next,
  RoadmapLevelState.future => JoinState.far,
};

/// One thing the road does: a milestone, a fold in the road, or its end.
sealed class JourneyStop {
  const JourneyStop();
}

/// A level the road stops at, with everything it opens.
final class MilestoneStop extends JourneyStop {
  const MilestoneStop({
    required this.level,
    required this.join,
    required this.entries,
    this.xpAway,
  });

  final int level;
  final JoinState join;
  final List<SkillUnlock> entries;

  /// Carried only on the [JoinState.next] joint — the projection's own rule
  /// (`RoadmapLevel.xpAway`), and the reason no other joint shows a distance.
  final int? xpAway;
}

/// Why a fold exists: an empty run ahead, or the road already walked.
enum FoldKind { empty, passed }

/// A stretch of road with nothing on it, painted as a fold.
///
/// The numbers are never skipped — a ladder that jumps from 6 to 10 reads as
/// broken — but a run of empty levels is one fold, not four bands.
final class FoldStop extends JourneyStop {
  const FoldStop({
    required this.kind,
    required this.fromLevel,
    required this.toLevel,
    required this.unlockCount,
  });

  final FoldKind kind;
  final int fromLevel;
  final int toLevel;

  /// How many unlocks are inside the fold — 0 for an empty run, and the
  /// count already earned for a passed one.
  final int unlockCount;

  String get levelLabel =>
      fromLevel == toLevel ? 'LV $fromLevel' : 'LV $fromLevel–$toLevel';

  String get label => switch (kind) {
    FoldKind.empty => '$levelLabel · nothing yet',
    FoldKind.passed => unlockCount == 0
        ? '$levelLabel · walked'
        : '$levelLabel · $unlockCount passed',
  };
}

/// The end of the road, at the last level any content touches.
final class EndStop extends JourneyStop {
  const EndStop({required this.contentHorizon, required this.horizonReached});

  final int contentHorizon;
  final bool horizonReached;

  String get sentence => horizonReached
      ? 'Every written unlock is open. The road runs out here — nothing is '
            'written above LV $contentHorizon yet.'
      : 'The road runs out here — nothing is written above LV '
            '$contentHorizon yet.';
}

/// The roadmap as a walk: folds behind, joints ahead, an end cap.
abstract final class JourneyModel {
  /// Builds the stop list.
  ///
  /// [passedOpen] unfolds the road already walked. The **last two levels
  /// that actually opened something** stay visible either way — a road with
  /// nothing behind the walker reads as a road they have not started.
  static List<JourneyStop> from(SkillRoadmap roadmap, {bool passedOpen = false}) {
    final List<RoadmapLevel> earned = <RoadmapLevel>[
      for (final RoadmapLevel l in roadmap.levels)
        if (l.state == RoadmapLevelState.earned) l,
    ];
    final List<RoadmapLevel> ahead = <RoadmapLevel>[
      for (final RoadmapLevel l in roadmap.levels)
        if (l.state != RoadmapLevelState.earned) l,
    ];

    final List<JourneyStop> stops = <JourneyStop>[];

    // Behind: everything before the second-to-last level that opened
    // something folds into one line. The split is by index, not by filter,
    // so the fold is always a contiguous stretch of road.
    final List<int> bearing = <int>[
      for (final (int i, RoadmapLevel l) in earned.indexed)
        if (l.entries.isNotEmpty) i,
    ];
    final int split = (bearing.length <= 2 || passedOpen)
        ? 0
        : bearing[bearing.length - 2];
    if (split > 0) {
      final List<RoadmapLevel> folded = earned.sublist(0, split);
      stops.add(
        FoldStop(
          kind: FoldKind.passed,
          fromLevel: folded.first.level,
          toLevel: folded.last.level,
          unlockCount: folded.fold(
            0,
            (int a, RoadmapLevel l) => a + l.entries.length,
          ),
        ),
      );
    }
    for (final RoadmapLevel l in earned.sublist(split)) {
      // An earned level that opened nothing is a step already taken with
      // nothing on it: no joint, and no fold of its own either.
      if (l.entries.isEmpty) continue;
      stops.add(
        MilestoneStop(
          level: l.level,
          join: JoinState.reached,
          entries: l.entries,
        ),
      );
    }

    // Ahead: runs of empty levels fold; the current level always stands,
    // empty or not, because it is where the walker is.
    int i = 0;
    while (i < ahead.length) {
      final RoadmapLevel level = ahead[i];
      final bool foldable =
          level.entries.isEmpty && level.state != RoadmapLevelState.current;
      if (foldable) {
        int j = i;
        while (j + 1 < ahead.length &&
            ahead[j + 1].entries.isEmpty &&
            ahead[j + 1].state != RoadmapLevelState.current) {
          j++;
        }
        stops.add(
          FoldStop(
            kind: FoldKind.empty,
            fromLevel: level.level,
            toLevel: ahead[j].level,
            unlockCount: 0,
          ),
        );
        i = j + 1;
        continue;
      }
      stops.add(
        MilestoneStop(
          level: level.level,
          join: _joinOf(level.state),
          entries: level.entries,
          xpAway: level.xpAway,
        ),
      );
      i++;
    }

    // The honest end of the road (`DECISIONS/0028` §6): a road that simply
    // stops is indistinguishable from a cap.
    if (roadmap.contentHorizon > 0 &&
        roadmap.contentHorizon < roadmap.maxLevel) {
      stops.add(
        EndStop(
          contentHorizon: roadmap.contentHorizon,
          horizonReached: roadmap.horizonReached,
        ),
      );
    }
    return stops;
  }
}
