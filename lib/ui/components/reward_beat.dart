/// The one reward language (PLAYABLE_EXPERIENCE_REFINEMENT_01 §29, §31, §32).
///
/// ## Why one component
///
/// The owner's device review found every gameplay result inventing its own
/// card: a craft wrote its result into the recipe card and left it there, a
/// level-up appended `SMITHING LEVEL 4` to whatever screen happened to
/// trigger it, combat stacked an XP block and reward rows under a static
/// heading, and a finished gather printed a line that read like a log. Each
/// was truthful; together they were five visual languages for one idea —
/// *something you did just paid off*.
///
/// This file is that idea, once. Every result fits one of three tiers:
///
/// | Tier | What | Treatment |
/// |---|---|---|
/// | MINOR | an ordinary gather, craft, or drop | a quiet block: eyebrow, one title line, one or two detail lines |
/// | MEDIUM | a level-up, an equipment craft, a contract handed in, a knowledge stage | a framed beat in its own accent, heading weight, the facts beneath |
/// | MAJOR | a project completed, a significant discovery, a signature item | the same frame, card-title weight, a heavier rule |
///
/// A beat says what happened (the eyebrow), names the thing (the title), and
/// gives the facts (the lines). Nothing here loops, bursts, or waits to be
/// opened (`RULES.md` P-6): the only motion is [StaggeredReveal], which
/// resolves a list of beats top to bottom once and then holds still.
///
/// ## Transient by contract (§32)
///
/// A beat is built from a **report** — the command's own return value — and
/// never from state. It clears when its owner clears the report: a timer for
/// minor results, an acknowledgement for medium and major. Nothing here can
/// outlive the moment it describes, so no screen can grow a log.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId, Rarity;

import '../theme/rarity_style.dart';
import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'adaptive_text.dart';
import 'data_display.dart';
import 'rarity_badge.dart';

/// How much a result matters — the only axis presentation may vary on.
enum RewardTier { minor, medium, major }

/// One result, as a beat.
class RewardBeat extends StatelessWidget {
  const RewardBeat({
    super.key,
    required this.tier,
    required this.eyebrow,
    required this.title,
    this.lines = const <String>[],
    this.rarity,
    this.accent,
    this.child,
    this.onContinue,
    this.continueLabel = 'OK',
  });

  final RewardTier tier;

  /// What happened, in a word or two: `CRAFTED`, `VICTORY`, `STUDIED`.
  final String eyebrow;

  /// The thing: `Oak Plank ×1`, `Bronze Sword`, `Forest Wolf`.
  final String title;

  /// The facts beneath, one per line. Kept short by the caller.
  final List<String> lines;

  /// Colours the frame and the title when the result has a rarity.
  final Rarity? rarity;

  /// Colours the frame and the eyebrow when the result has no rarity but
  /// belongs to something — a skill, the step accent. Ignored when [rarity]
  /// is set. Null falls back to the default border.
  final Color? accent;

  /// Anything structured beneath the lines — reward rows, an Equip button.
  final Widget? child;

  /// Medium and major beats are acknowledged, not timed out. Null hides the
  /// control (the caller owns a different dismissal, or the tier is minor).
  final VoidCallback? onContinue;
  final String continueLabel;

  @override
  Widget build(BuildContext context) {
    final RarityStyle? rarityStyle = RarityStyle.maybe(rarity);
    final Color frame =
        rarityStyle?.accent ?? accent ?? StrideColors.borderDefault;
    final Color titleInk = rarityStyle?.accent ?? StrideColors.textPrimary;
    final Color eyebrowInk = switch (tier) {
      RewardTier.minor => StrideColors.textSecondary,
      _ => rarityStyle?.accent ?? accent ?? StrideColors.textSecondary,
    };
    final TextStyle titleStyle = switch (tier) {
      RewardTier.minor => StrideType.sub,
      RewardTier.medium => StrideType.sectionHeading,
      RewardTier.major => StrideType.cardTitle,
    };

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                eyebrow,
                style: StrideType.microLabel.copyWith(color: eyebrowInk),
                maxLines: 1,
              ),
            ),
            if (rarity != null) RarityBadge(rarity: rarity),
          ],
        ),
        const SizedBox(height: StrideSpace.s2),
        AdaptiveText(title, style: titleStyle, color: titleInk),
        // Prose wraps; it is never shrunk to fit. A fact line can be a
        // sentence ("+2 Max HP · harder fights are within reach"), and the
        // narrowest phone at the largest text scale is the case that decides.
        for (final String line in lines) ...<Widget>[
          const SizedBox(height: StrideSpace.s2),
          Text(
            line,
            style: (tier == RewardTier.minor ? StrideType.micro : StrideType.sub)
                .copyWith(color: StrideColors.textSecondary),
            maxLines: 3,
          ),
        ],
        if (child case final Widget c) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          c,
        ],
        if (onContinue case final VoidCallback go) ...<Widget>[
          const SizedBox(height: StrideSpace.s8),
          Align(
            alignment: Alignment.centerLeft,
            child: StrideButton.secondary(label: continueLabel, onPressed: go),
          ),
        ],
      ],
    );

    // MINOR sits on the fill alone; MEDIUM and MAJOR take a frame in their
    // accent. The difference between the two upper tiers is weight and the
    // rule's thickness, never a different shape.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StrideSpace.blockPadding),
      decoration: BoxDecoration(
        color: StrideColors.surfaceBlock,
        borderRadius: StrideRadius.inner,
        border: tier == RewardTier.minor
            ? null
            : Border.all(
                color: frame,
                width: tier == RewardTier.major ? 2 : 1,
              ),
      ),
      child: body,
    );
  }
}

/// The universal level-up (§29): LEVEL, WHAT UNLOCKED, WHY IT MATTERS.
///
/// One presentation shared by gathering, crafting and character level — it is
/// never appended to whatever surface triggered it, it is placed by that
/// surface as a beat of its own. Always MEDIUM: a level is the same size of
/// event wherever it lands.
class LevelUpCard extends StatelessWidget {
  const LevelUpCard({
    super.key,
    required this.name,
    required this.level,
    this.skill,
    this.unlocked = const <String>[],
    this.why,
  });

  /// `Smithing`, `Mining`, or `Traveler` for the character.
  final String name;
  final int level;

  /// The skill, for its hue; null colours the beat with the step accent.
  final ContentId? skill;

  /// What this level opened, by display name.
  final List<String> unlocked;

  /// The one sentence that answers "so what" — given by the caller, who
  /// knows: `+2 Max HP`, `Higher seams can be worked`.
  final String? why;

  @override
  Widget build(BuildContext context) {
    final Color accent = skill == null
        ? StrideColors.accentSteps
        : StrideColors.forSkill(skill!);
    return RewardBeat(
      tier: RewardTier.medium,
      eyebrow: 'LEVEL UP',
      title: '${name.toUpperCase()} LEVEL $level',
      accent: accent,
      lines: <String>[?why],
      child: unlocked.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('UNLOCKED', style: StrideType.microLabel),
                const SizedBox(height: StrideSpace.s2),
                for (final String item in unlocked)
                  AdaptiveText(
                    item,
                    style: StrideType.sub,
                    color: StrideColors.textPrimary,
                  ),
              ],
            ),
    );
  }
}

/// Resolves [children] top to bottom, once — the choreography every
/// multi-beat result shares (§16): each child fades and settles in after the
/// one above, on one clock, so the reveal is a function of index and a test
/// can settle it. Reduced motion arrives finished.
///
/// Fast by design: a beat takes [beat] and the next starts [stagger] later,
/// so five beats resolve in well under a second. Nothing is unskippable —
/// the children are the information and are laid out at full size from the
/// first frame; only opacity and a short rise animate.
class StaggeredReveal extends StatefulWidget {
  const StaggeredReveal({
    super.key,
    required this.children,
    this.beat = const Duration(milliseconds: 260),
    this.stagger = const Duration(milliseconds: 110),
    this.gap = StrideSpace.s8,
  });

  final List<Widget> children;
  final Duration beat;
  final Duration stagger;
  final double gap;

  @override
  State<StaggeredReveal> createState() => _StaggeredRevealState();
}

class _StaggeredRevealState extends State<StaggeredReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _total,
  );
  bool _started = false;

  Duration get _total => Duration(
    milliseconds:
        widget.beat.inMilliseconds +
        widget.stagger.inMilliseconds *
            (widget.children.length > 1 ? widget.children.length - 1 : 0),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context) || widget.children.isEmpty) {
      _clock.value = 1;
    } else {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Animation<double> _slice(int index) {
    final int total = _total.inMilliseconds;
    final double begin = (widget.stagger.inMilliseconds * index) / total;
    final double end = begin + widget.beat.inMilliseconds / total;
    return CurvedAnimation(
      parent: _clock,
      curve: Interval(begin, end > 1 ? 1 : end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (int i = 0; i < widget.children.length; i++) ...<Widget>[
        if (i > 0) SizedBox(height: widget.gap),
        FadeTransition(
          opacity: _slice(i),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(_slice(i)),
            child: widget.children[i],
          ),
        ),
      ],
    ],
  );
}
