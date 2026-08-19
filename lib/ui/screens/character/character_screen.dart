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
import '../../components/adaptive_text.dart';
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

        // Identity and standing, in one card.
        //
        // These were two: a portrait card whose right 40% was empty beside the
        // word `Traveler`, and a separate card of two tiles directly beneath it.
        // The screen therefore answered "who am I" and "how far along am I" in
        // two places that had to be read in sequence, and spent a card boundary
        // and 10 dp of gap separating a fact from its own subject.
        //
        // The earlier attempt to put a tile beside the portrait was reverted
        // because a 22 px numeral overflowed the 73 dp tile it produced at
        // 320 dp. What sits here now is not that tile — it is text that wraps
        // and shrinks, in a column that yields, so the failure mode it was
        // reverted for cannot occur. The two-tile pair is not recreated
        // elsewhere; the figures it carried are the two lines below.
        //
        // Both are projections, not rule math: the character level is stored,
        // and the skill totals sum `skillSummaries`, whose levels already came
        // from the content curve's own `levelAt`.
        SectionCard(
          padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const InsetWell.square(
                contentSize: StrideGeometry.portraitContent,
                child: PixelAsset.portrait(PixelIcons.portraitTraveler),
              ),
              const SizedBox(width: StrideSpace.s12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const AdaptiveText(
                      'Traveler',
                      style: StrideType.numericHero,
                      minScale: 0.7,
                    ),
                    const SizedBox(height: StrideSpace.s8),
                    // A rule, not a gap. The name is the character; the two
                    // facts under it are the sheet. Without the separator the
                    // owner read the whole right column as metadata beside a
                    // portrait, which is a fair description of four unrelated
                    // text runs stacked at the same weight.
                    const _Rule(),
                    const SizedBox(height: StrideSpace.s8),
                    _IdentityFact(
                      // `Level`, not `Character level`. The longer wording read
                      // better and then needed 151 dp at text scale 1.4 in the
                      // 120 this column has beside the portrait at 320 dp — a
                      // clearer label that clips is not clearer. `Skill levels`
                      // directly beneath it supplies the contrast.
                      label: 'Level',
                      value: '${s.characterLevel}',
                      // The label already says which level this is; `character`
                      // beside the numeral was a qualifier reading as a
                      // sentence fragment.
                      unit: '',
                    ),
                    const SizedBox(height: StrideSpace.s8),
                    _IdentityFact(
                      label: 'Skill levels',
                      value:
                          '${skills.fold(0, (int a, SkillSummary k) => a + k.level)}'
                          ' / '
                          '${skills.fold(0, (int a, SkillSummary k) => a + k.maxLevel)}',
                      unit: '${skills.length} skills',
                    ),
                  ],
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
              ValueTileRow(
                tiles: <LabeledValueTile>[
                  LabeledValueTile(
                    label: 'Total walked',
                    value: formatSteps(s.totalGranted),
                    unit: 'steps earned',
                    leading: const WalkingGlyph(role: WalkingRole.stock),
                    valueColor: StrideColors.accentSteps,
                  ),
                  LabeledValueTile(
                    label: 'Total skill XP',
                    value: formatSteps(s.totalSkillExperience),
                    unit: 'across every skill',
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
        const SizedBox(height: StrideSpace.cardGap),

        // COMBAT — the figures the next encounter will be snapshotted from.
        //
        // Every one of them is `combatFigures`, a projection of
        // `CombatRules.loadoutFor` and the level curve — the same function the
        // engine calls at encounter start. Nothing here is arithmetic in a
        // widget: "XP to next" is a field, not `threshold - experience` done
        // here, so the day the curve moves this card moves with it.
        //
        // Below the skills, not above them: the skills card is what walking
        // has built and stays above the fold at 393 dp; where this block sits
        // in the sheet's order is the owner's call once the slice is played.
        _CombatBlock(figures: s.combatFigures),
      ],
    );
  }
}

/// Level, XP to next, Max HP, Attack (with the weapon that counts), Defence
/// (with the armour that counts). Small, in the existing tile style.
class _CombatBlock extends StatelessWidget {
  const _CombatBlock({required this.figures});

  final CombatFigures figures;

  @override
  Widget build(BuildContext context) {
    final CombatFigures f = figures;
    final int? next = f.nextLevelThreshold;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeading(label: 'Combat'),
          const SizedBox(height: StrideSpace.s10),
          ValueTileRow(
            tiles: <LabeledValueTile>[
              LabeledValueTile(label: 'Level', value: '${f.level}'),
              LabeledValueTile(
                label: 'Experience',
                value: formatSteps(f.experience),
                // At the cap there is no next threshold, and saying so is
                // more honest than a bar that cannot move.
                unit: next == null ? 'at the cap' : '/ ${formatSteps(next)}',
              ),
              LabeledValueTile(label: 'Max HP', value: '${f.maxHp}'),
            ],
          ),
          const SizedBox(height: StrideSpace.s8),
          ValueTileRow(
            tiles: <LabeledValueTile>[
              LabeledValueTile(
                label: 'Attack',
                value: '${f.attack}',
                unit: f.weaponName ?? 'unarmed',
              ),
              LabeledValueTile(
                label: 'Defence',
                value: '${f.defence}',
                unit: f.armorName ?? 'no armour',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A label, a figure and a unit on one line, for the identity card.
///
/// Deliberately **not** a [LabeledValueTile]: a tile is a filled block, and two
/// of them stacked beside the portrait would give the card three competing
/// surfaces in 128 dp. These are lines of type in the card's own ground, so the
/// portrait stays the only object in the card.
class _IdentityFact extends StatelessWidget {
  const _IdentityFact({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      // Adaptive, not plain: this column is what is left of a 320 dp card after
      // a 130 dp portrait, so it is the narrowest label surface in the app.
      AdaptiveText(
        label.toUpperCase(),
        style: StrideType.microLabel,
        minScale: 0.8,
      ),
      const SizedBox(height: StrideSpace.s2),
      // `numericValue`, not `sectionHeading`. At 16 px these figures sat beside
      // a 128 dp portrait and lost — the owner's device read was that the
      // portrait dominates and the progression beside it is metadata. 22 px is
      // the weight every other figure in the app gets, and it is what makes
      // this column a character sheet rather than a caption.
      AdaptiveText(value, style: StrideType.numericValue, minScale: 0.8),
      // The unit is on its own line, and that is a correction rather than a
      // preference.
      //
      // It first sat on the value's baseline, which rendered the skill-levels
      // fact as `5 / 100 5 skills` — three numbers and a slash in one run,
      // second thing the eye reaches on the screen. Visual QA misparsed it, and
      // a reviewer who cannot parse a figure has found a defect in the figure.
      if (unit.isNotEmpty) Text(unit, style: StrideType.micro, maxLines: 2),
    ],
  );
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
                // The XP figure is the only per-skill number that moves, and it
                // was set in the same muted 11 px as an inline caption. Tabular
                // and in the secondary text colour, it reads as a value in a
                // column of values.
                Text(
                  '${formatSteps(skill.experience)} XP',
                  style: StrideType.micro.copyWith(
                    color: StrideColors.textSecondary,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          // `LEVEL 1 / 20`, on one line, with the level the only emphasised
          // part.
          //
          // It was a stacked 22 px `1` over a muted `/ 20`, five rows deep —
          // and with every skill at level 1 that produced a column of five
          // identical bold numerals that were the loudest thing on the card
          // while saying the least. The XP figure beside them is the datum that
          // actually varies. Same numbers, same source, one line, and the
          // stripe is gone.
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('LEVEL', style: StrideType.microLabel),
              const SizedBox(width: StrideSpace.s6),
              Text(
                '${skill.level}',
                style: StrideType.sectionHeading.copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              Text(' / ${skill.maxLevel}', style: StrideType.micro),
            ],
          ),
        ],
      ),
    );
  }
}

/// A hairline rule inside a card.
///
/// `separator`, not `borderDefault` — the border ladder is exactly one weight in
/// exactly one colour and is for *outlines*. This is a within-card division,
/// which is what `StrideColors.separator` was defined for and, until now, the
/// only thing in the palette with no caller.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: StrideColors.separator,
    child: SizedBox(height: 1, width: double.infinity),
  );
}
