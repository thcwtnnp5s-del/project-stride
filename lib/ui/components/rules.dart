/// The two rules a recomposed list is built from: the hairline that separates
/// peers inside one panel, and the progress rule that measures one of them.
///
/// ## Why these are primitives and not two more `Container`s
///
/// FMPO02 (`ART-12_ux_brief.md` §4–§5) replaces "one bordered card per item"
/// with "one panel whose items are separated by a rule". That is the whole
/// structural move on Skills and on Adventure, and it only reads as one system
/// if the separator is the same one pixel in the same colour in both places.
/// Written inline it would be two `Container(height: 1, color: …)`s today and
/// five subtly different ones by the end of the milestone — which is exactly
/// how the app acquired thirty-four copies of one rectangle.
///
/// Neither rule carries a word, a number or a boundary anything measures
/// against: they are ornament in the `DECISIONS/0029` sense, positioned by
/// Flutter, and the layout is identical with them removed.
library;

import 'package:flutter/widgets.dart';

import '../theme/stride_colors.dart';

/// The 1 px separator between peers inside one panel.
///
/// Full-bleed by construction — it is drawn by the panel, not by the row, so
/// the caller places it *between* rows rather than giving every row a bottom
/// edge. A trailing separator under the last row is a border, and the panel
/// already has one.
class HairlineRule extends StatelessWidget {
  const HairlineRule({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 1,
    width: double.infinity,
    child: ColoredBox(color: StrideColors.separator),
  );
}

/// A 4 dp progress rule, flush to the bottom edge of the row it measures.
///
/// **Not a bar, and the difference is the point.** A bar is an object inside a
/// card with a radius and two ends; this is the row's own lower edge, dyed as
/// far along as the player has got. It carries no label — the row above it
/// already says which skill and which level — and it is never given a
/// percentage, because a rule that had to be read as a figure would be a
/// figure badly drawn.
///
/// The fill eases to its committed fraction, and **reduced motion branches
/// explicitly**: `TweenAnimationBuilder` does not honour
/// `MediaQuery.disableAnimationsOf` on its own, which is the feel-audit
/// finding `SkillProgressBar` records. Key this widget by whatever makes the
/// ladder change — a skill's level — so a level-up snaps to the new ladder
/// instead of rewinding through the old one.
class ProgressRule extends StatelessWidget {
  const ProgressRule({
    super.key,
    required this.fraction,
    required this.ink,
    this.height = 4,
  });

  /// Position within the current level, 0..1. Clamped here rather than
  /// trusted: the projection is the authority on the figure, not on its range.
  final double fraction;

  /// The trade's own ink — `StrideColors.forSkill`.
  final Color ink;

  final double height;

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ColoredBox(color: StrideColors.surfaceBlock),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: fraction.clamp(0.0, 1.0)),
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (BuildContext context, double value, Widget? child) =>
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value,
                  child: child,
                ),
            child: ColoredBox(color: ink),
          ),
        ],
      ),
    );
  }
}
