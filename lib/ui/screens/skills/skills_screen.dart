/// The Skills screen — progression visibility, and nothing else.
///
/// ## What this screen is for
///
/// The Character screen already lists the five skills with their levels. This
/// one answers the question that list cannot: **what is the next level, how far
/// away is it, and what does it buy?**
///
/// That is deliberately the whole scope. It is not a wiki, not an encyclopedia
/// of the content pack, and not a second inventory. A player opens it to decide
/// where to walk next.
///
/// ## Every number here is derived in the domain
///
/// `SkillStanding` comes from `SkillDefinition.standingAt` in `stride_core` —
/// the same file whose `levelAt` the engine gates gathering on. Nothing on this
/// screen indexes `xpThresholds`, because a widget that did would be a second
/// implementation of the level curve, free to disagree with the engine's the
/// first time a content pack retunes a skill (`RULES.md` E-2, F-07).
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show SkillStanding;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/pixel_asset.dart';
import '../../components/surfaces.dart';
import '../../icons/pixel_icons.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import '../system/stale_banner.dart';

class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController controller = SessionScope.of(context);
    final StrideSession session = controller.session;
    final List<SkillStanding> standings = session.skillStandings;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        StrideSpace.screenGutter,
        StrideSpace.s12,
        StrideSpace.screenGutter,
        StrideSpace.s16,
      ),
      children: <Widget>[
        if (session.isStale) ...<Widget>[
          StaleBanner(busy: controller.busy, onReload: controller.reload),
          SizedBox(height: StrideSpace.cardGap),
        ],
        for (final SkillStanding standing in standings) ...<Widget>[
          _SkillCard(standing: standing),
          SizedBox(height: StrideSpace.cardGap),
        ],
      ],
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.standing});

  final SkillStanding standing;

  @override
  Widget build(BuildContext context) {
    final SessionController controller = SessionScope.of(context);
    final List<SkillUnlock> unlocks = controller.session.unlocksFor(
      standing.skill,
    );

    // The next thing this skill opens, not all of them. A card listing every
    // gate would answer "what exists" when the player asked "what next".
    final SkillUnlock? next = unlocks
        .where((SkillUnlock u) => !u.unlocked)
        .firstOrNull;
    final int openCount = unlocks.where((SkillUnlock u) => u.unlocked).length;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Header(standing: standing),
          SizedBox(height: StrideSpace.s12),
          _ProgressBar(standing: standing),
          SizedBox(height: StrideSpace.s8),
          _ProgressCaption(standing: standing),
          SizedBox(height: StrideSpace.s12),
          _UnlockLine(next: next, openCount: openCount),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.standing});

  final SkillStanding standing;

  @override
  Widget build(BuildContext context) {
    final String? icon = PixelIcons.skillFor(standing.skill);
    final Color accent = StrideColors.forSkill(standing.skill);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // The rail is reserved whether or not the icon resolves. A null icon
        // must not shift the name of every other skill out of alignment —
        // `PixelIcons.skillFor` returns null by design and the caller carries
        // the layout.
        SizedBox(
          width: 26,
          height: 26,
          child: icon == null ? null : Center(child: PixelAsset.skill(icon)),
        ),
        SizedBox(width: StrideSpace.iconLabelGap),
        Expanded(
          child: AdaptiveText(
            standing.displayName,
            style: StrideType.cardTitle,
            color: accent,
          ),
        ),
        SizedBox(width: StrideSpace.s8),
        AdaptiveText(
          standing.isMaxLevel ? 'MAX' : 'LV ${standing.level}',
          style: StrideType.numericValue,
        ),
      ],
    );
  }
}

/// A two-tone bar showing position within the current level.
///
/// Drawn with sized boxes rather than a `LinearProgressIndicator` so it inherits
/// the app's own palette and corner radius rather than Material's, and so it
/// carries no implicit animation — nothing here is loading.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.standing});

  final SkillStanding standing;

  @override
  Widget build(BuildContext context) {
    final Color accent = StrideColors.forSkill(standing.skill);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final double filled = width * standing.progress;
        return Semantics(
          // Read aloud as a sentence, because a bar with no label is a shape.
          label: standing.isMaxLevel
              ? '${standing.displayName} at maximum level'
              : '${standing.displayName} level ${standing.level}, '
                    '${standing.experienceIntoLevel} of '
                    '${standing.experienceForLevel} experience into the level',
          child: ClipRRect(
            borderRadius: StrideRadius.chip,
            child: SizedBox(
              height: 8,
              width: width,
              child: Stack(
                children: <Widget>[
                  ColoredBox(
                    color: StrideColors.surfaceBlock,
                    child: const SizedBox.expand(),
                  ),
                  SizedBox(
                    width: filled,
                    child: ColoredBox(
                      color: accent,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProgressCaption extends StatelessWidget {
  const _ProgressCaption({required this.standing});

  final SkillStanding standing;

  @override
  Widget build(BuildContext context) {
    // Max level says what is true — the experience is still accruing, there is
    // simply nothing left to buy. "0 to next level" would be a different and
    // false statement.
    final String left = standing.isMaxLevel
        ? '${standing.totalExperience} XP total'
        : '${standing.experienceIntoLevel} / '
              '${standing.experienceForLevel} XP';
    final String right = standing.isMaxLevel
        ? 'Level ${standing.maxLevel} of ${standing.maxLevel}'
        : '${standing.experienceToNextLevel} to level '
              '${standing.level + 1}';

    return Row(
      children: <Widget>[
        Flexible(child: AdaptiveText(left, style: StrideType.micro)),
        SizedBox(width: StrideSpace.s8),
        Flexible(
          child: AdaptiveText(
            right,
            style: StrideType.micro,
            textAlign: TextAlign.end,
            color: StrideColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _UnlockLine extends StatelessWidget {
  const _UnlockLine({required this.next, required this.openCount});

  final SkillUnlock? next;
  final int openCount;

  @override
  Widget build(BuildContext context) {
    final SkillUnlock? upcoming = next;

    // "Everything open" is a real and satisfying state, and it needs its own
    // sentence rather than an empty space where a goal used to be.
    if (upcoming == null) {
      return AdaptiveText(
        openCount == 0
            ? 'Nothing in this content pack uses it yet.'
            : 'Everything this skill opens is open.',
        style: StrideType.micro,
        color: StrideColors.textMuted,
      );
    }

    final String where = upcoming.where == null ? '' : ' at ${upcoming.where}';
    return AdaptiveText(
      'Level ${upcoming.requiredLevel} opens ${upcoming.displayName}$where',
      style: StrideType.micro,
      color: StrideColors.textMuted,
    );
  }
}
