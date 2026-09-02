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
/// ## A handbook, not five posters (FMPO02, `ART-12_ux_brief.md` §4)
///
/// Five near-identical cards — plate, name, level, bar, caption, three unlock
/// lines and a `ROADMAP` hint apiece — took ~1000 dp to say five things that
/// differ only in a hue and a number, and the repetition is what made the tab
/// read as a database printout rather than a guild handbook. The five cards
/// are now five **spines** of one card: 64 dp each, hairline separated, with
/// the level's progress dyed into the spine's own lower edge.
///
/// The unlock lines went with them — and wave 3 brought three of them back.
/// Sending every roadmap line to [SkillDetailScreen] left five names, five
/// levels and roughly 55 % of the screen as bare ground, which the adversarial
/// review measured as an information-hierarchy regression against the very card
/// the spine replaced (FINAL-01 #3, FINAL-10 #2). A spine now carries the next
/// three unlocks and the XP caption under its rule: still one card, still
/// hairline separated, roughly 300 dp shorter than the five posters and no
/// longer a list of names in a void. The detail screen keeps the *whole*
/// roadmap; the spine carries the part a player decides on.
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
import 'package:stride_core/stride_core.dart' show ContentId, SkillStanding;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/panel_skin.dart';
import '../../components/pixel_asset.dart';
import '../../components/rules.dart';
import '../../components/surfaces.dart';
import '../../icons/pixel_icons.dart';
import '../../icons/reward_art.dart';
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
          SizedBox(height: StrideSpace.rhythmGroup),
        ],
        // One card, five spines. `padding: zero` because a spine's progress
        // rule is flush to its own lower edge and full bleed — it is the
        // spine's edge, not an object laid on top of it — so the card's
        // interior gutter belongs to the row and not to the panel. The clip
        // is what keeps the first and last full-bleed rules inside the card's
        // radius; `SectionCard` paints its surface behind the child and does
        // not clip it.
        //
        // `buckram` is the handbook's own material (`ART-02` §2). It resolves
        // to null until the tile ships, and the card then paints exactly the
        // flat fill it always painted.
        SectionCard(
          surface: PanelSurface.buckram,
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: StrideRadius.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final (int i, SkillStanding standing)
                    in standings.indexed) ...<Widget>[
                  if (i > 0) const HairlineRule(),
                  SkillSpine(
                    standing: standing,
                    upcoming: _nextUnlocks(session, standing.skill),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The unlocks still ahead for [skill], in roadmap order, capped at [take].
///
/// Three, because three is what the card carried before FMPO02 collapsed it to
/// a spine and the review called the result a hierarchy regression: five bare
/// icon-and-level rows over roughly 55 % empty ground, with the roadmap a tap
/// away instead of on the screen (FINAL-01 #3, FINAL-10 #2). One line answers
/// "what next"; three answer "where is this going", which is the question a
/// player asks before deciding what to walk toward today.
///
/// Capped **here**, in the one place that reads the projection, so a widget
/// cannot quietly grow the cap (`RULES.md` E-2).
List<SkillUnlock> _nextUnlocks(
  StrideSession session,
  ContentId skill, {
  int take = 3,
}) {
  final List<SkillUnlock> ahead = <SkillUnlock>[];
  for (final SkillUnlock u in session.unlocksFor(skill)) {
    if (u.unlocked) continue;
    ahead.add(u);
    if (ahead.length == take) break;
  }
  return ahead;
}

/// One profession, as a 64 dp spine of the handbook.
///
/// The whole spine is the control (`ART-12` §4): 64 dp is well past the 44 dp
/// floor, it opens the roadmap wherever the finger lands, and the `ROADMAP`
/// text hint is gone — a row that is entirely a button does not need a word
/// saying so.
///
/// The **face** is a `Stack`, not a `Column`, and that is load-bearing. The
/// rule has to sit on the face's bottom edge while the face grows with the text
/// scaler; a `Column` would need a bounded height to pin it there, and a fixed
/// 64 dp box around scaling type is D-01's shape. Here the padded row sizes the
/// stack, `minHeight` holds the rhythm at scale 1.0, and the rule stays on the
/// bottom edge wherever that edge lands.
///
/// Beneath the rule, and outside that stack, sits the XP caption (FMPO02
/// wave 3). It is the one part of the spine whose height is not the face's, so
/// it is the one part that is a plain `Column` child.
class SkillSpine extends StatelessWidget {
  const SkillSpine({
    super.key,
    required this.standing,
    this.upcoming = const <SkillUnlock>[],
  });

  final SkillStanding standing;

  /// The unlocks still ahead, in roadmap order and already capped at three by
  /// [_nextUnlocks]; empty when everything is open.
  ///
  /// One micro line each under the name — `Level 2 opens Oak Stand` — so the
  /// spine says where the trade is going and the screen is not five names in a
  /// void (FMPO02 producer review, restored to three lines in wave 3 after
  /// FINAL-01 #3 measured the collapse to one as a regression against the card
  /// this replaced).
  final List<SkillUnlock> upcoming;

  /// The spine's rhythm height, and its touch target.
  static const double height = 64;

  /// The rule's weight — the spine's lower edge, dyed.
  static const double ruleHeight = 4;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // The glance the spine answers, said in full: the roadmap it opens and
      // the position the rule draws. `SkillProgressBar`'s sentence is reused
      // verbatim rather than paraphrased — a bar with no label is a shape,
      // and so is a rule.
      label:
          '${standing.displayName} roadmap. '
          '${SkillProgressBar.semanticsLabelFor(standing)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => SkillDetailScreen.open(context, standing.skill),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: height),
              child: _face(context),
            ),
            // The figures, under the rule that draws them (FMPO02 wave 3).
            // The spine already carries the position as a *shape*; a shape
            // with no number is the half of the old card that got lost, and
            // "1,240 to level 6" is the sentence that makes walking toward
            // this trade a decision rather than a guess. Same widget as the
            // roadmap's own header, so the two surfaces cannot disagree.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                StrideSpace.s12,
                StrideSpace.s6,
                StrideSpace.s12,
                StrideSpace.s10,
              ),
              child: SkillProgressCaption(standing: standing),
            ),
          ],
        ),
      ),
    );
  }

  /// The spine's own face: crest, name, roadmap lines, level, and the rule
  /// pinned to the face's lower edge.
  ///
  /// A `Stack`, not a `Column`, and that is load-bearing — see the class doc.
  Widget _face(BuildContext context) {
    final Color accent = StrideColors.forSkill(standing.skill);
    return Stack(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            StrideSpace.s12,
            StrideSpace.s12,
            StrideSpace.s12,
            StrideSpace.s12 + ruleHeight,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SkillPlate(skill: standing.skill),
              const SizedBox(width: StrideSpace.iconLabelGap),
              Expanded(
                // Wraps rather than shrinks. At 320 dp with the
                // accessibility scale at 1.4, `Woodcutting` needs
                // 170 dp of the 168 the spine can give it beside a
                // 32 dp crest and `LV 1` — two and a half pixels
                // short, and `AdaptiveText` is already at its floor
                // there. A `minScale` low enough to absorb that is
                // the illegibility trade `adaptive_text.dart`
                // refuses; the spine is a **minimum** 64 dp and can
                // simply be taller.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      standing.displayName,
                      style: StrideType.cardTitle.copyWith(color: accent),
                      maxLines: 2,
                    ),
                    for (final SkillUnlock u in upcoming)
                      Text(
                        'Level ${u.requiredLevel} opens ${u.displayName}',
                        // Wraps rather than clips: the 320 dp guard
                        // (ui_responsive_test) forbids an ellipsis.
                        style: StrideType.micro,
                        maxLines: 2,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: StrideSpace.s8),
              AdaptiveText(
                standing.isMaxLevel ? 'MAX' : 'LV ${standing.level}',
                style: StrideType.numericValue,
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          // Keyed by level so a level-up snaps to the new ladder
          // rather than rewinding through it.
          child: ProgressRule(
            key: ValueKey<int>(standing.level),
            fraction: standing.progress,
            ink: accent,
            height: ruleHeight,
          ),
        ),
      ],
    );
  }
}

/// The profession's crest: its icon on a plate of its own deep with a hairline
/// in its ink (Fable V2 Iteration 02) — not a floating glyph.
///
/// The rail is reserved whether or not the icon resolves: a null icon must not
/// shift the name of every other skill out of alignment.
class SkillPlate extends StatelessWidget {
  const SkillPlate({super.key, required this.skill});

  final ContentId skill;

  static const double extent = 32;

  @override
  Widget build(BuildContext context) {
    final String? icon = PixelIcons.skillFor(skill);
    return Container(
      width: extent,
      height: extent,
      decoration: BoxDecoration(
        color: StrideColors.forSkillDeep(skill),
        border: Border.all(color: StrideColors.forSkill(skill)),
        borderRadius: StrideRadius.inner,
      ),
      child: icon == null ? null : Center(child: PixelAsset.skill(icon)),
    );
  }
}

class SkillHeaderRow extends StatelessWidget {
  const SkillHeaderRow({super.key, required this.standing});

  final SkillStanding standing;

  @override
  Widget build(BuildContext context) {
    final Color accent = StrideColors.forSkill(standing.skill);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SkillPlate(skill: standing.skill),
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

  /// The sentence a bar — or a [ProgressRule] drawn from the same standing —
  /// is read aloud as. One statement, so the two shapes cannot describe the
  /// same fact two ways.
  static String semanticsLabelFor(SkillStanding standing) => standing.isMaxLevel
      ? '${standing.displayName} at maximum level'
      : '${standing.displayName} level ${standing.level}, '
            '${standing.experienceIntoLevel} of '
            '${standing.experienceForLevel} experience into the level';

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
      label: semanticsLabelFor(standing),
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
        // The skill's own progress, distinct from a run's `mark_exp`
        // (`RewardArt`, ART-10 §1) — this bar advances on the skill's own
        // curve, not the session's. Decorative: the figures beside it
        // already state the fact.
        const ExcludeSemantics(
          child: PixelAsset(
            assetPath: RewardArt.markSkillXp,
            nativeWidth: 24,
            nativeHeight: 24,
            scale: 1,
          ),
        ),
        const SizedBox(width: StrideSpace.s6),
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
