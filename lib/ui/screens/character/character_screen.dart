/// What walking has built.
///
/// ## Levels are shown, and that is not a rule in a widget
///
/// The skill level comes from `SkillDefinition.levelAt`, the same function
/// `GameEngine` gates gathering on. Calling it is **reading a domain function**,
/// not computing a rule, and it is projected through `StrideSession` rather than
/// reached for directly.
///
/// **XP into the current level is deliberately absent** — no `220 / 720` and no
/// bar. That span needs `xpThresholds[level - 1]` and `xpThresholds[level]`, and
/// indexing a content curve in a widget *is* rule math. If it is wanted later it
/// belongs on `SkillDefinition` beside `levelAt`, which is where the curve
/// already lives.
///
/// A progress track is therefore not built at all in Phase 1. There is nothing
/// honest to fill one with, and a track that exists with no legitimate caller is
/// a standing invitation to fabricate a fraction — which is exactly the Round 02
/// defect where four of five bars contradicted their captions.
library;

import 'package:flutter/widgets.dart';

import '../../../runtime/stride_session.dart';
import '../../components/data_display.dart';
import '../../components/pixel_asset.dart';
import '../../components/screen_header.dart' show formatSteps;
import '../../components/surfaces.dart';
import '../../components/walking_glyph.dart';
import '../../icons/pixel_icons.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import '../system/stale_banner.dart';

class CharacterScreen extends StatelessWidget {
  const CharacterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final StrideSession s = c.session;
    final List<SkillSummary> skills = s.skillSummaries;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        StrideSpace.screenGutter,
        StrideSpace.s12,
        StrideSpace.screenGutter,
        StrideSpace.s16,
      ),
      children: <Widget>[
        if (s.isStale) ...<Widget>[
          StaleBanner(busy: c.busy, onReload: c.reload),
          const SizedBox(height: StrideSpace.cardGap),
        ],

        SectionCard(
          padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // TEMPORARY placeholder. The portrait workstream is paused with no
              // approved asset; PixelIcons.portraitTemporary is the whole
              // migration surface when it resumes.
              InsetWell.square(
                contentSize: 96,
                child: PixelAsset.portrait(PixelIcons.portraitTemporary),
              ),
              const SizedBox(width: StrideSpace.s12),
              const Expanded(
                child: Text('Traveler', style: StrideType.cardTitle),
              ),
            ],
          ),
        ),
        const SizedBox(height: StrideSpace.cardGap),

        // Two tiles across the card's FULL width, rather than squeezed into the
        // column beside the portrait.
        //
        // Visual QA found a single narrow tile leaving the right 40% of the
        // identity card empty, which read as incomplete because every other card
        // in the system fills its width. Adding a second tile beside the
        // portrait fixed the emptiness and created a 73 dp tile at 320 dp, which
        // a 22 px numeral overflows. Giving the pair the full width is the fix
        // that holds at every supported size instead of trading one defect for
        // another.
        //
        // Both figures are projections, not rule math: the character level is
        // stored, and the skill totals sum `skillSummaries`, whose levels
        // already came from the content curve's own `levelAt`.
        SectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: LabeledValueTile(
                  label: 'Level',
                  value: '${s.characterLevel}',
                  unit: 'character',
                ),
              ),
              const SizedBox(width: StrideSpace.s8),
              Expanded(
                child: LabeledValueTile(
                  label: 'Skill levels',
                  value:
                      '${skills.fold(0, (int a, SkillSummary k) => a + k.level)}'
                      ' / '
                      '${skills.fold(0, (int a, SkillSummary k) => a + k.maxLevel)}',
                  unit:
                      '${skills.length} skills, cap '
                      '${skills.isEmpty ? 0 : skills.first.maxLevel} each',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: StrideSpace.cardGap),

        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeading(label: 'What walking has built'),
              const SizedBox(height: StrideSpace.s10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: LabeledValueTile(
                      label: 'Total walked',
                      value: formatSteps(s.totalGranted),
                      unit: 'steps earned',
                      leading: const WalkingGlyph(role: WalkingRole.stock),
                      valueColor: StrideColors.accentSteps,
                    ),
                  ),
                  const SizedBox(width: StrideSpace.s8),
                  Expanded(
                    child: LabeledValueTile(
                      label: 'Total skill XP',
                      value: formatSteps(s.totalSkillExperience),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: StrideSpace.cardGap),

        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeading(label: 'Skills'),
              const SizedBox(height: StrideSpace.s10),
              for (final SkillSummary skill in skills) _SkillRow(skill: skill),
            ],
          ),
        ),
      ],
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.skill});

  final SkillSummary skill;

  @override
  Widget build(BuildContext context) {
    final String? icon = PixelIcons.skillFor(skill.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: StrideSpace.s10),
      child: Row(
        children: <Widget>[
          // The rail is reserved whether or not this skill has an icon. A row
          // that collapsed when the icon was null would give the list two
          // different left margins and no alignment rail — which is exactly
          // what Visual QA found when only one of five skills had a sprite.
          SizedBox(
            width: 26,
            height: 26,
            child: icon == null
                ? null
                : InsetWell.square(
                    contentSize: 24,
                    child: PixelAsset.skill(icon),
                  ),
          ),
          const SizedBox(width: StrideSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  skill.displayName,
                  style: StrideType.sub.copyWith(
                    color: StrideColors.forSkill(skill.id),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
                Text(
                  '${formatSteps(skill.experience)} XP',
                  style: StrideType.micro,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text('${skill.level}', style: StrideType.numericValue),
              Text('/ ${skill.maxLevel}', style: StrideType.micro),
            ],
          ),
        ],
      ),
    );
  }
}
