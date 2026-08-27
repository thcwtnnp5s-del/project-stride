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
import 'skill_detail_screen.dart';

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

    // The next few things this skill opens — not one, and not all of them.
    // One line hid the level-10 Hollow Thicket from a Foraging-4 player,
    // which is exactly the long walk this screen exists to motivate; every
    // gate would answer "what exists" when the player asked "what next"
    // (Fable V2, `DECISIONS/0027`).
    final List<SkillUnlock> upcoming = unlocks
        .where((SkillUnlock u) => !u.unlocked)
        .take(3)
        .toList();
    final int openCount = unlocks.where((SkillUnlock u) => u.unlocked).length;

    // The profession's own atmosphere (Fable V2 Iteration 02): each card
    // breathes its skill's deep from the top, so five professions stop
    // being five identical brown slabs and the tab reads as a set of
    // trades. The ink itself stays where it always was — name and fill.
    //
    // The whole card opens the profession's roadmap (Iteration 03): the
    // card stays the glance, the pushed route is the depth, and the
    // ROADMAP hint carries the Sync-fold's weight — "there is more"
    // without adding a control.
    return Semantics(
      button: true,
      label: '${standing.displayName} roadmap',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => SkillDetailScreen.open(context, standing.skill),
        child: SectionCard(
          wash: StrideColors.forSkillDeep(standing.skill),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SkillHeaderRow(standing: standing),
              SizedBox(height: StrideSpace.s12),
              SkillProgressBar(standing: standing),
              SizedBox(height: StrideSpace.s8),
              SkillProgressCaption(standing: standing),
              SizedBox(height: StrideSpace.s12),
              _UnlockLines(upcoming: upcoming, openCount: openCount),
              SizedBox(height: StrideSpace.s6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'ROADMAP',
                  style: StrideType.microLabel.copyWith(
                    color: StrideColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkillHeaderRow extends StatelessWidget {
  const SkillHeaderRow({super.key, required this.standing});

  final SkillStanding standing;

  @override
  Widget build(BuildContext context) {
    final String? icon = PixelIcons.skillFor(standing.skill);
    final Color accent = StrideColors.forSkill(standing.skill);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // The icon on a plate of its trade's deep with a hairline in its
        // ink (Fable V2 Iteration 02) — the profession's crest, not a
        // floating glyph. The rail is reserved whether or not the icon
        // resolves: a null icon must not shift the name of every other
        // skill out of alignment.
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: StrideColors.forSkillDeep(standing.skill),
            border: Border.all(color: accent),
            borderRadius: StrideRadius.inner,
          ),
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
class SkillProgressBar extends StatelessWidget {
  const SkillProgressBar({super.key, required this.standing});

  final SkillStanding standing;

  @override
  Widget build(BuildContext context) {
    final Color accent = StrideColors.forSkill(standing.skill);
    // The fill eases to its committed fraction (Fable V2 Iteration 02):
    // opening Skills after a session of gathering shows the bar *arriving*
    // where the work put it instead of teleporting. Keyed by level so a
    // level-up snaps to the new ladder rather than rewinding through it;
    // reduced motion branches explicitly — TweenAnimationBuilder does not
    // honor it on its own (feel-audit finding).
    final bool reduced = MediaQuery.disableAnimationsOf(context);

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
          width: double.infinity,
          child: Stack(
            children: <Widget>[
              ColoredBox(
                color: StrideColors.surfaceBlock,
                child: const SizedBox.expand(),
              ),
              TweenAnimationBuilder<double>(
                key: ValueKey<int>(standing.level),
                tween: Tween<double>(end: standing.progress.clamp(0.0, 1.0)),
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double value, Widget? child) =>
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: ColoredBox(
                        color: accent,
                        child: const SizedBox.expand(),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkillProgressCaption extends StatelessWidget {
  const SkillProgressCaption({super.key, required this.standing});

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

class _UnlockLines extends StatelessWidget {
  const _UnlockLines({required this.upcoming, required this.openCount});

  final List<SkillUnlock> upcoming;
  final int openCount;

  /// `Level 3 opens Duskcap Grove at Whispering Woods`, with the extra gate
  /// said where one exists — `Level 2 + a contract at Haven's Rest opens
  /// Wolfhide Jerkin` — so the screen never promises what the level alone
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
    // "Everything open" is a real and satisfying state, and it needs its own
    // sentence rather than an empty space where a goal used to be.
    if (upcoming.isEmpty) {
      return AdaptiveText(
        openCount == 0
            ? 'Nothing in this content pack uses it yet.'
            : 'Everything this skill opens is open.',
        style: StrideType.micro,
        color: StrideColors.textMuted,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
      ],
    );
  }
}
