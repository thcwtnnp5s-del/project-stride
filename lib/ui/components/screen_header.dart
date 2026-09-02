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
    this.regionInk,
    this.regionDeep,
    this.rule,
  });

  final String eyebrow;
  final String title;
  final Widget? trailing;

  /// The 1 px rule under the bar, in the region's ink at 24 % (FMPO02,
  /// `ART-12_ux_brief.md` §8).
  ///
  /// **The header needs an end, and it must not be a second frame.** The wash
  /// fades into the screen's ground, so the bar has no lower edge at all and
  /// the eye reads the header and the first card as one column of stuff. A
  /// hairline in the place's own ink terminates it and says nothing else; at
  /// 24 % it is a change of value, not a line drawn round something.
  ///
  /// Null — the default — leaves a header exactly as it was, which is what
  /// every pushed route wants: a route that is already a modal layer does not
  /// need a rule saying where it stops.
  final Color? rule;

  /// The region's biome colour (Fable V2 Iteration 02): [regionInk] tints the
  /// **place's name** — which since PRESENTATION_COMBAT_EVOLUTION_01 is the
  /// [title], not the [eyebrow] — and [regionDeep] breathes a short vertical
  /// wash down from the top of the bar. Both null keeps the header exactly as
  /// it always was; the banked readout stays the brightest thing either way
  /// (L-16 composition).
  final Color? regionInk;
  final Color? regionDeep;

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
    decoration: regionDeep == null && rule == null
        ? null
        : BoxDecoration(
            gradient: regionDeep == null
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[regionDeep!, StrideColors.surfaceGround],
                  ),
            // Beneath the wash, and inside the box: a `Border` is drawn within
            // the container's own bounds, so the bar terminates without
            // growing and `headerMinHeight` still resolves to 61 at scale 1.
            border: rule == null
                ? null
                : Border(
                    bottom: BorderSide(color: rule!.withValues(alpha: 0.24)),
                  ),
          ),
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Shrink-within-bounds rather than clip.
                //
                // **The reasoning here changed** with the header inversion
                // (PRESENTATION_COMBAT_EVOLUTION_01). It used to read "the
                // titles are four known words", which justified this side of
                // the header yielding first. The title is now a **place
                // name** — content, not a fixed string — and "Whispering
                // Woods" beside a five-figure banked readout on a 320 dp
                // phone is D-01's shape one axis over. `AdaptiveText` shrinks
                // rather than clips, which is what keeps that honest, and it
                // is now load-bearing rather than belt-and-braces.
                // **Wraps, where it used to shrink.** The eyebrow was four
                // known words — `CRAFT`, `WORLD` — and one line at one size
                // was never in question. It is now the place's own
                // descriptor (FMPO02 §8), and `SETTLEMENT · GRASSLAND`
                // wants 196 dp of the 153 a 320 dp phone can spare beside
                // the banked readout. `AdaptiveText`'s floor cannot absorb
                // that, and lowering the floor to make it fit is the trade
                // `adaptive_text.dart` refuses — so the breadcrumb takes a
                // second line on the narrowest phones and every character
                // survives. Nothing changes for a short eyebrow: one word
                // still lays out on one line at full size.
                Text(
                  eyebrow.toUpperCase(),
                  style: StrideType.screenEyebrow,
                  maxLines: 2,
                ),
                AdaptiveText(
                  title,
                  style: StrideType.screenTitle,
                  color: regionInk,
                ),
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
              // The figure counts to its new value instead of teleporting —
              // a sync visibly *pays into* the header, which is the one
              // moment the whole game is about (Fable V2, `DECISIONS/0027`).
              // ~400 ms, tabular figures so nothing jitters; reduced motion
              // jumps, as everywhere else. Presentation only: the tween's
              // endpoints are the committed value.
              child: MediaQuery.disableAnimationsOf(context)
                  ? AdaptiveText(
                      formatSteps(bankedSteps),
                      style: StrideType.headerValue,
                      textAlign: TextAlign.right,
                    )
                  : TweenAnimationBuilder<int>(
                      tween: IntTween(begin: bankedSteps, end: bankedSteps),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (BuildContext context, int shown, Widget? _) =>
                          AdaptiveText(
                            formatSteps(shown),
                            style: StrideType.headerValue,
                            textAlign: TextAlign.right,
                          ),
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
