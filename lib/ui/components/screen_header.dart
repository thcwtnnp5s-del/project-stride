/// The screen header, and the persistent banked-steps readout in its trailing
/// slot.
library;

import 'package:flutter/widgets.dart';

import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'adaptive_text.dart';
import 'walking_glyph.dart';

/// Eyebrow and title on the left, a trailing slot on the right.
///
/// Deliberately not a `SliverAppBar`: it does not collapse, and it must not
/// acquire a scroll behaviour it was never designed with.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Container(
    // A minimum, not a fixed height. See `StrideGeometry.headerMinHeight`: a
    // fixed 61 dp vertically clips the eyebrow/title stack under an enlarged
    // text scale, which is D-01's shape on the other axis.
    constraints: const BoxConstraints(
      minHeight: StrideGeometry.headerMinHeight,
    ),
    padding: const EdgeInsets.symmetric(
      horizontal: StrideSpace.screenGutter,
      vertical: StrideSpace.s6,
    ),
    alignment: Alignment.center,
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Shrink-within-bounds rather than clip. These strings are
                // fixed and short, which is exactly why they are the right
                // side of the header to yield: the banked figure is player
                // data and grows, the titles are four known words.
                AdaptiveText(
                  eyebrow.toUpperCase(),
                  style: StrideType.screenEyebrow,
                ),
                AdaptiveText(title, style: StrideType.screenTitle),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: StrideSpace.s8),
            // Bounded, so the readout cannot take the whole bar, and generous,
            // so the figure wins the contest against the title. Without the
            // cap this is a non-flex `Row` child with unbounded constraints.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    constraints.maxWidth *
                    StrideGeometry.bankedFigureMaxFraction,
              ),
              child: trailing!,
            ),
          ],
        ],
      ),
    ),
  );
}

/// The persistent HUD element: a stock the player owns.
///
/// A numeral with a glyph — **not** a bar. It does not drain, it has no refill
/// affordance, and nothing about it expires (`RULES.md` P-5,
/// `DECISIONS/0008`). It is identical on every screen.
class BankedStepsReadout extends StatelessWidget {
  const BankedStepsReadout({super.key, required this.bankedSteps});

  final int bankedSteps;

  /// The label under the figure.
  ///
  /// **`BANKED STEPS`, shortened from `BANKED FROM WALKING`.** Nineteen
  /// letter-spaced uppercase characters measured wider than the figure they
  /// captioned, so the readout's width — and therefore how little was left for
  /// the screen title — was being set by its own caption rather than by the
  /// player's data. The teal and the walking glyph beside it already say "from
  /// walking" (`ART_DIRECTION.md` L-16); the words were saying it a second time,
  /// in the widest possible form, in the tightest space in the app.
  static const String label = 'BANKED STEPS';

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: <Widget>[
      Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Teal: these are steps the player has walked and owns.
          const WalkingGlyph(role: WalkingRole.stock),
          const SizedBox(width: StrideSpace.iconLabelGap),
          // A **minimum** width, right-aligned, tabular — so a growing figure
          // never shifts the eyebrow beside it and never lands the glyph on a
          // fractional x, and so a figure wider than the minimum is drawn in
          // full rather than clipped. This is the D-01 fix.
          //
          // `Flexible` matters: the parent caps the readout, and without it a
          // `Row` child with `mainAxisSize.min` would still demand its full
          // intrinsic width and overflow that cap instead of shrinking into it.
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: StrideGeometry.bankedFigureMinWidth,
              ),
              child: AdaptiveText(
                formatSteps(bankedSteps),
                style: StrideType.headerValue,
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
      AdaptiveText(
        label,
        style: StrideType.screenEyebrow,
        color: StrideColors.textMuted,
        textAlign: TextAlign.right,
      ),
    ],
  );
}

/// Thousands-separated, with a comma.
///
/// `ART_DIRECTION.md` **L-14**: `1,240` must not read as `1.240`. Under the
/// hybrid this is a string the platform lays out rather than a bitmap glyph, so
/// the defect class that produced that lock is gone — but the formatting is
/// still stated in one place rather than at each call site.
///
/// Deliberately not `NumberFormat`: `stride_core` is locale-free by rule (E-1),
/// and a figure that renders `1.240` in one locale and `1,240` in another would
/// reintroduce exactly the ambiguity L-14 forbids.
String formatSteps(int value) {
  final String digits = value.abs().toString();
  final StringBuffer out = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
