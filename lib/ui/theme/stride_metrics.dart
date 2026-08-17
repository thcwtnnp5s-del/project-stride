/// Spacing, radii, and the fixed geometry the approved renders earned.
library;

import 'package:flutter/painting.dart';

/// The spacing scale.
///
/// The prototype's base CSS classes are consistent; its inline `style=`
/// overrides are not — `padding:12px`, `11px`, `13px 14px`, `gap:5px`, `7px`,
/// `9px` all appear. Those are per-screen hand-tuning to fit an 852 px budget,
/// and they are drift the Flutter translation does not inherit. The scale below
/// collapses the near-duplicates.
abstract final class StrideSpace {
  const StrideSpace._();

  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;

  /// Left and right, on every screen. **Fixed, not proportional** — a
  /// proportional gutter makes a narrow phone lose content width twice.
  static const double screenGutter = s16;

  static const double cardPadding = s14;

  /// Cards carrying a grid or a hero figure.
  static const double cardPaddingCompact = s12;

  static const double blockPadding = s10;

  /// **Normalised deliberately.** The build uses 5 / 10 / 11 across three
  /// screens; that spread is budget-fitting, not design — the Activity screen's
  /// 5 px gap exists because the screen was one card too tall for 852 px. In
  /// Flutter the body scrolls, so the pressure that produced the value is gone.
  static const double cardGap = s10;

  static const double gridGap = s8;
  static const double rowGap = s6;
  static const double iconLabelGap = s6;
}

abstract final class StrideRadius {
  const StrideRadius._();

  static const BorderRadius card = BorderRadius.all(Radius.circular(14));
  static const BorderRadius inner = BorderRadius.all(Radius.circular(10));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(8));
  static const BorderRadius gate = BorderRadius.all(Radius.circular(6));

  /// Bottom corners only — the active tab's ground runs up to the bar's top
  /// edge and rounds away from it.
  static const BorderRadius tabActive = BorderRadius.only(
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );
}

/// Fixed geometry, each value carrying the reason it is that number rather than
/// the round one next to it.
abstract final class StrideGeometry {
  const StrideGeometry._();

  /// 61, not 60. With a 1 px bottom border, a 60-high header centres a 38-high
  /// stack inside 59 and lands the boot glyph on a half pixel — which
  /// antialiases a sprite that is supposed to be crisp.
  static const double headerHeight = 61;

  /// A fixed-width, right-aligned, tabular box for the banked figure, so a
  /// growing number never shifts the eyebrow beside it and never gives the
  /// glyph a fractional x.
  ///
  /// **OPEN DEFECT D-01 — this value is too small, and is deferred to the UI
  /// facelift by owner decision.** It clips the final digit of a seven-character
  /// figure: physical acceptance ran at `455,281` and lost the `1`
  /// (`MILESTONES/PLAYABLE_DEMO_PHASE_1_DEVICE_RESULT.md` §5).
  ///
  /// The fixed width itself is right and should survive the fix; 72 was simply
  /// chosen for smaller numbers than a real player accumulates. A player who
  /// walks for a month reaches seven characters and never goes back.
  ///
  /// Whoever fixes it: **the regression test must assert a rendered width or a
  /// character count against a seven-figure value.** Asserting the absence of an
  /// exception cannot work, because `TextOverflow.clip` never raises one — which
  /// is exactly why five overflow tests and four goldens all missed this.
  static const double bankedFigureWidth = 72;

  /// Glyph + label. The bottom safe-area inset is added below this, not folded
  /// into it — the bar's ground extends into the inset so it does not float.
  static const double tabBarHeight = 74;

  /// The portrait's displayed edge — 64 native × 2.
  ///
  /// The well around it is `portraitContent + 2`, computed by `InsetWell` rather
  /// than written down, which is the Flutter form of the fix that took Round 03
  /// three diagnoses: a 96 px sprite in a 96 px *border-box* got 94 px of
  /// content and was silently rescaled.
  static const double portraitContent = 128;

  static const double buttonHeight = 44;

  /// A floor, not a fixed height — a wrapped two-line item name grows the row
  /// rather than clipping.
  ///
  /// Raised from 111 with the icon: the PixelLab family is 48 px where the
  /// code-rendered set was 40, so the tile needs the eight back.
  static const double itemTileMinHeight = 119;

  /// Below this, the inventory grid drops from four columns to three.
  ///
  /// Derived, not chosen: icon 48 + tile padding 3 + 3 + border 1 + 1 + 16
  /// logical px of breathing room for the two-line name. The branch engages
  /// below 352 dp, so a 320 dp phone now takes it — which is the point. Four
  /// 48 px icons cannot fit 320 dp, and three that fit beat four that are
  /// silently rescaled.
  static const double gridColumnFloor = 72;
}
