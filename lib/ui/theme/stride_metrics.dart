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
  ///
  /// **A minimum since the facelift, not a fixed height.** 61 assumed one
  /// text scale. At 1.4 the eyebrow/title stack is taller than 61 on its own,
  /// and a fixed box would have vertically clipped the title — the same shape as
  /// D-01, one axis over. It resolves to exactly 61 at scale 1.0, so nothing
  /// moves on a default device.
  static const double headerMinHeight = 61;

  /// The **minimum** width of the banked figure's box, right-aligned and
  /// tabular, so a growing number never shifts the eyebrow beside it and never
  /// gives the glyph a fractional x.
  ///
  /// **Was `bankedFigureWidth`, a fixed 72 dp with `TextOverflow.clip`, and that
  /// was defect D-01** — physical acceptance ran at `455,281`, which is seven
  /// characters at `StrideType.headerValue`, and the final `1` was not drawn
  /// (`MILESTONES/PLAYABLE_DEMO_PHASE_1_DEVICE_RESULT.md` §5).
  ///
  /// The *stability* the fixed width bought is real and is kept: below 72 dp the
  /// box does not shrink, so the four- and five-figure values a new player sees
  /// still do not jitter the eyebrow. Above it the figure takes the width it
  /// needs, and [AdaptiveText] is what makes "takes the width it needs" true
  /// rather than aspirational.
  ///
  /// **72 was never the bug.** The bug was a fixed box holding a value the
  /// player grows without bound, failing silently. Raising the constant would
  /// have moved the failure to eight characters and left the shape intact.
  static const double bankedFigureMinWidth = 72;

  /// The share of the header a growing banked figure may claim before the title
  /// beside it starts yielding instead.
  ///
  /// The readout is the header's primary value and wins the contest; the titles
  /// are four short known strings and are the right thing to compress. Without a
  /// cap the readout is a non-flex `Row` child with unbounded constraints, and
  /// at 320 dp under enlarged text it would take the whole bar.
  static const double bankedFigureMaxFraction = 0.62;

  /// Glyph + label. The bottom safe-area inset is added below this, not folded
  /// into it — the bar's ground extends into the inset so it does not float.
  ///
  /// **64, down from 74.** Glyph 28 + gap 6 + label 11 is 45 dp of content; 74
  /// spent 29 dp on air in the one piece of chrome that is on screen at all
  /// times, on the axis phones have least of. 64 still clears the 48 dp touch
  /// target with room, and returns 10 dp to every screen.
  ///
  /// This is the one fixed height the facelift left fixed. The bar's labels run
  /// under `MediaQuery.withNoTextScaling` — a deliberate accessibility trade
  /// documented in `stride_tab_bar.dart` — so nothing inside it can grow, and a
  /// fixed box around content that cannot grow is not the D-01 shape.
  static const double tabBarHeight = 64;

  /// The portrait's displayed edge — 64 native × 2.
  ///
  /// The well around it is `portraitContent + 2`, computed by `InsetWell` rather
  /// than written down, which is the Flutter form of the fix that took Round 03
  /// three diagnoses: a 96 px sprite in a 96 px *border-box* got 94 px of
  /// content and was silently rescaled.
  static const double portraitContent = 128;

  /// The primary action's minimum height. **48, up from 44.**
  ///
  /// The gather button is the only control on the Adventure screen and it sat at
  /// the platform's minimum touch target, the same fill as a chip, in a card
  /// with six other blocks. 48 is Material's recommended target and reads as
  /// deliberate rather than as another pill.
  static const double buttonHeight = 48;

  /// A utility control's minimum height — `Sync steps`, and nothing on the
  /// gameplay path.
  ///
  /// 34, which is deliberately **below** the 44 dp touch minimum for a primary
  /// control and above the 32 dp a compact secondary conventionally gets. The
  /// gap between 34 and the primary's 48 is the demotion; making them equal is
  /// what let a utility action read as the game action on the owner's phone.
  static const double buttonHeightSecondary = 34;

  /// A floor, not a fixed height — a wrapped two-line item name grows the row
  /// rather than clipping.
  ///
  /// Raised from 111 with the icon: the PixelLab family is 48 px where the
  /// code-rendered set was 40, so the tile needs the eight back.
  ///
  /// **This was documented as a floor and used as an exact height** — the grid
  /// passed it to `mainAxisExtent`, which is precise, not minimum. A two-line
  /// name at an enlarged text scale therefore clipped, silently, exactly like
  /// D-01. The grid now derives its extent from this floor *and* the ambient
  /// text scaler; see `inventory_screen.dart`.
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
