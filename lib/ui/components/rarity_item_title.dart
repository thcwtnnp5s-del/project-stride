/// An item's name in its rarity's ink, and the 1 px rule that frames a card
/// carrying one.
///
/// ## The restraint rule, written where it is enforced
///
/// A rarity may recolour **type** and it may colour **one line**. It may not
/// fill a surface, tint a ground, or add a second border weight. That is the
/// owner's "do not colour every pixel of an item card" stated as something a
/// reviewer can check: if a rarity hue is covering area rather than marking an
/// edge or a word, it is wrong here.
///
/// The border ladder this extends is deliberately narrow — `surfaces.dart`
/// records exactly one weight (1 logical px) in exactly one colour, and says it
/// should not be extended without a reason. [RarityFrame] extends the *colour*
/// and keeps the *weight*, because the weight is what makes the ladder read as
/// a system and the colour is the whole information being added.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show Rarity;

import '../theme/rarity_style.dart';
import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import 'adaptive_text.dart';

/// An item's name, in its rarity's ink.
///
/// **Weight, size and family are the caller's** — a rarity changes the hue of a
/// name and nothing else about it. Promoting the type as well would make a
/// legendary shout twice, and would break the alignment of a column of names
/// that are not all the same rank.
class RarityName extends StatelessWidget {
  /// One line, shrinking within [minScale] rather than truncating — the
  /// [AdaptiveText] contract, for a name that shares a row with other things.
  const RarityName({
    super.key,
    required this.name,
    required this.rarity,
    required this.style,
    this.fallback = StrideColors.textPrimary,
    this.minScale = 0.85,
    this.textAlign = TextAlign.start,
  }) : _wraps = false;

  /// As many lines as the name needs, in a column that can grow.
  ///
  /// **Measured, not preferred.** `Frost-lined Jerkin` needs 198.9 dp at the
  /// victory panel's `sub` role and the reward row gives its name column 116 dp
  /// at 320 dp — a gap no shrink ladder inside [minScale] can close, and
  /// `AdaptiveText` says so plainly: at its floor it clips like any other
  /// `Text`. A name is prose and may wrap; the fix is the extra line, not
  /// smaller type (`test/rarity_ui_test.dart`).
  ///
  /// Uncapped on purpose. Every surface that uses this is inside a scroll view,
  /// so a name long enough for a third line costs a few dp of height, where a
  /// `maxLines` would cost the last word.
  const RarityName.wrapping({
    super.key,
    required this.name,
    required this.rarity,
    required this.style,
    this.fallback = StrideColors.textPrimary,
    this.textAlign = TextAlign.start,
  }) : minScale = 1,
       _wraps = true;

  final String name;

  /// Null falls back to [fallback] — the colour the surface would have used
  /// anyway. A missing definition must not be dressed as a rank.
  final Rarity? rarity;

  final TextStyle style;
  final Color fallback;
  final double minScale;
  final TextAlign textAlign;

  final bool _wraps;

  @override
  Widget build(BuildContext context) {
    final Color color = RarityStyle.inkOr(rarity, fallback);
    if (_wraps) {
      return Text(
        name,
        style: style.copyWith(color: color),
        textAlign: textAlign,
      );
    }
    return AdaptiveText(
      name,
      style: style,
      color: color,
      minScale: minScale,
      textAlign: textAlign,
    );
  }
}

/// A block framed by one rank's accent: the app's nested-block fill, its inner
/// radius, and a **1 px** border in the rarity's dim companion.
///
/// One reward row, one recipe result — never a whole card and never a fill. A
/// null rarity gets [StrideColors.borderDefault], which is what the block would
/// have carried with no rarity system at all.
class RarityFrame extends StatelessWidget {
  const RarityFrame({
    super.key,
    required this.rarity,
    required this.child,
    this.padding,
  });

  final Rarity? rarity;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(StrideSpace.blockPadding),
    decoration: BoxDecoration(
      color: StrideColors.surfaceBlock,
      border: Border.all(
        color: RarityStyle.maybe(rarity)?.accent ?? StrideColors.borderDefault,
      ),
      borderRadius: StrideRadius.inner,
    ),
    child: child,
  );
}

/// A rarity's mark as a short horizontal rule, for a surface with no room for
/// the word.
///
/// **The inventory grid cell is the only such surface, and it was measured
/// rather than assumed.** `UNCOMMON` — the longest of the five labels, and so
/// the one that decides the layout — needs 72.3 dp at text scale 1.4 in a
/// 393 dp four-column cell that has 68.8, even at [RarityBadge.compact]'s
/// floor. Dropping the floor further would answer an accessibility request by
/// shrinking type, which is the trade this system refuses
/// (`adaptive_text.dart`), and driving the column count off the badge width
/// would flip a 393 dp phone between three and four columns on a font-metric
/// rounding.
///
/// So the cell carries the mark and the name's ink, and the *word* appears
/// wherever an item gets a full-width row — the victory panel, the equipped
/// summary, the craft card, the character sheet. That is a real trade and it
/// is stated rather than hidden: colour is the only rarity channel inside the
/// grid.
///
/// Two logical pixels rather than one, and the **ink** rather than the accent:
/// this is a mark with no type on it, and a 1 px hairline in a dim colour at
/// the top of an 80 dp tile is not perceptible at arm's length on a phone.
class RarityRule extends StatelessWidget {
  const RarityRule({super.key, required this.rarity});

  final Rarity? rarity;

  static const double thickness = 2;

  @override
  Widget build(BuildContext context) {
    final RarityStyle? style = RarityStyle.maybe(rarity);
    // The height is spent either way, so a cell with no definition for its item
    // keeps the same interior as its neighbours instead of shifting up 2 dp.
    if (style == null) return const SizedBox(height: thickness);
    return Container(
      height: thickness,
      decoration: BoxDecoration(
        color: style.ink,
        borderRadius: const BorderRadius.all(Radius.circular(1)),
      ),
    );
  }
}
