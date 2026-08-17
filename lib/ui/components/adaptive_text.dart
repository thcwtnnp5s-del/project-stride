/// Text that must never lose a character, and the one place that rule is
/// implemented.
///
/// ## The defect class this exists to remove
///
/// D-01: `BankedStepsReadout` put a seven-character figure — `455,281` — in a
/// fixed 72 dp box with `TextOverflow.clip`, and the final digit simply was not
/// there. **`TextOverflow.clip` raises no exception and paints no stripe.** Five
/// overflow tests asserting `takeException() == null` and four goldens rendering
/// a six-character figure all passed, and a player looking at a real save saw a
/// wrong number (`MISTAKES.md` M-06, `RULES.md` G-1).
///
/// The 72 was not the bug. The bug was the shape: **a fixed box holding a value
/// the player grows without bound, failing silently.** That shape appears
/// wherever a numeral, a name, or a label meets a fixed width, so the fix is a
/// primitive rather than a larger constant.
///
/// ## What this widget guarantees
///
/// Given a finite width, it renders **every character**, at the designed size
/// where that fits and at a bounded reduction where it does not. It never
/// truncates, never ellipsises, and never shrinks past [minScale] — an
/// unbounded `FittedBox(scaleDown)` trades a visible clip for an illegible
/// numeral, which is the same information loss wearing better manners.
///
/// Given an **unbounded** width — a non-flex child of a `Row`, which is how the
/// header's banked figure is laid out — it takes its intrinsic width at full
/// size. That is the "let the value own the horizontal space it needs" case, and
/// it is the primary D-01 fix. The shrink ladder is the fallback for a genuinely
/// narrow surface, not the mechanism.
///
/// ## The residual boundary, stated rather than hidden
///
/// At [minScale] on a surface too narrow for even that, this clips like any
/// other `Text`. It cannot conjure width. What it does is make that condition
/// **reachable by a test**: [fitsWithin] is the same measurement the widget
/// uses, so a regression test can assert the property directly instead of
/// asserting the absence of an exception that was never going to be thrown.
library;

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/widgets.dart';

/// A single line of text that shrinks within a bounded range rather than
/// truncating.
class AdaptiveText extends StatelessWidget {
  const AdaptiveText(
    this.data, {
    super.key,
    required this.style,
    this.minScale = 0.85,
    this.textAlign = TextAlign.start,
    this.color,
  }) : assert(minScale > 0 && minScale <= 1, 'minScale is a fraction of 1');

  final String data;
  final TextStyle style;

  /// The floor of the shrink ladder, as a fraction of the style's own size.
  ///
  /// 0.85 by default: enough to absorb two extra digits at the header's 19 px,
  /// and not enough to take a 22 px value below the 11 pt iOS floor for
  /// supporting text. Raise it for type that is already small; do not lower it
  /// to make a layout fit, because that is the illegibility trade this widget
  /// exists to refuse.
  final double minScale;

  final TextAlign textAlign;

  /// Applied over [style], so a caller does not have to `copyWith` at every site
  /// that only wants a different colour.
  final Color? color;

  /// The steps between 1.0 and [minScale], coarse enough that the chosen size
  /// stays a recognisable member of the type scale.
  static const double _step = 0.05;

  /// Whether [data] in [style] fits [maxWidth] at [scaler], at full size.
  ///
  /// Exposed so a test can assert the property that actually failed on the
  /// device — a rendered width against a real value — rather than the absence of
  /// an exception `TextOverflow.clip` never raises.
  static bool fitsWithin(
    String data,
    TextStyle style,
    TextScaler scaler,
    double maxWidth,
  ) => _widthOf(data, style, scaler) <= maxWidth + precisionErrorTolerance;

  static double _widthOf(String data, TextStyle style, TextScaler scaler) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: data, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return width;
  }

  TextStyle _resolved(double factor) {
    final TextStyle base = color == null ? style : style.copyWith(color: color);
    if (factor == 1) return base;
    // `height` is a multiplier, so scaling fontSize carries the line box with
    // it and the role's designed ratio survives (`stride_typography.dart`).
    return base.copyWith(fontSize: (style.fontSize ?? 14) * factor);
  }

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    // Measure what will actually be painted, which is the ambient style with
    // this widget's style merged over it — **not** this widget's style alone.
    //
    // No `StrideType` role names a `fontFamily`; the family arrives from the
    // theme, through `DefaultTextStyle`. A `TextPainter` handed a family-less
    // style falls back to a different font, so measuring the bare role means
    // laying out one font and asking a second one whether it fits. The error is
    // small on a device and large under `flutter test`, where the fallback is
    // about half again wider than Roboto — which is precisely the condition
    // that has to be right for a shrink decision to be trustworthy in either
    // place.
    final TextStyle inherited = DefaultTextStyle.of(context).style;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double factor = 1;
        if (constraints.maxWidth.isFinite) {
          for (
            double f = 1;
            f >= minScale - precisionErrorTolerance;
            f -= _step
          ) {
            factor = f;
            if (fitsWithin(
              data,
              inherited.merge(_resolved(f)),
              scaler,
              constraints.maxWidth,
            )) {
              break;
            }
          }
        }

        return Text(
          data,
          style: _resolved(factor),
          textAlign: textAlign,
          maxLines: 1,
          softWrap: false,
          // Unreachable while the ladder found a fit. Left as `clip` rather
          // than `ellipsis` for the reason `ScreenHeader` already states: a
          // clipped string is visibly clipped, which is information, where an
          // ellipsis is a claim that the string was too long.
          overflow: TextOverflow.clip,
        );
      },
    );
  }
}
