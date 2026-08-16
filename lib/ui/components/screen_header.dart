/// The screen header, and the persistent banked-steps readout in its trailing
/// slot.
library;

import 'package:flutter/widgets.dart';

import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
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
    height: StrideGeometry.headerHeight,
    padding: const EdgeInsets.symmetric(horizontal: StrideSpace.screenGutter),
    alignment: Alignment.center,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                eyebrow.toUpperCase(),
                style: StrideType.screenEyebrow,
                maxLines: 1,
                // Clip, never ellipsis. A clipped label is visibly clipped,
                // which is information; an ellipsis is a claim that a string
                // was too long, about strings that are fixed and were designed
                // to fit.
                overflow: TextOverflow.clip,
                softWrap: false,
              ),
              Text(
                title,
                style: StrideType.screenTitle,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
              ),
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[
          const SizedBox(width: StrideSpace.s8),
          trailing!,
        ],
      ],
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
          SizedBox(
            // Fixed width, right-aligned, tabular — so a growing figure never
            // shifts the eyebrow beside it, and never lands the glyph on a
            // fractional x.
            width: StrideGeometry.bankedFigureWidth,
            child: Text(
              formatSteps(bankedSteps),
              style: StrideType.headerValue,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
            ),
          ),
        ],
      ),
      Text(
        'BANKED FROM WALKING',
        style: StrideType.screenEyebrow.copyWith(color: StrideColors.textMuted),
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
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
