/// The typography roles, transcribed from the approved Round 03 build.
///
/// ## Two translation traps, both silent
///
/// **`height` in Flutter is a multiplier, not a pixel value.** Writing
/// `height: 13` on an 11 px style gives a 143 px line box, not a 13 px one.
/// Every role below is therefore written as an explicit ratio — `13 / 11` rather
/// than `1.18` — so the CSS source numbers stay checkable against the spec table
/// without arithmetic.
///
/// **`letterSpacing` in Flutter is logical pixels, not em.** CSS `.085em` on
/// 11 px type is `0.935` logical px, not `0.085`. Written out below as
/// `11 * 0.085` for the same reason.
///
/// Both of these produce output that is wrong in a way review does not catch,
/// which is why `test/ui/typography_test.dart` measures a rendered line box
/// rather than trusting the numbers here.
///
/// ## Tabular numerals
///
/// Every numeral that can change or be compared is tabular: banked steps, XP
/// figures, item counts, level numbers, tile values. Non-tabular digits make a
/// repeatedly-updating figure jitter and make a stacked column of counts fail to
/// align. On this app's densest screen that is the difference between a column
/// that scans and one that does not.
library;

import 'package:flutter/painting.dart';

import 'stride_colors.dart';

abstract final class StrideType {
  const StrideType._();

  static const List<FontFeature> _tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// `HAVEN'S REST` — the location line above the screen title.
  /// Uppercased by the caller, not by a text transform.
  static const TextStyle screenEyebrow = TextStyle(
    fontSize: 11,
    height: 13 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 11 * 0.085,
    color: StrideColors.textMuted,
  );

  /// `Adventure`, `Inventory`, `Character`.
  static const TextStyle screenTitle = TextStyle(
    fontSize: 19,
    height: 22 / 19,
    fontWeight: FontWeight.w700,
    letterSpacing: 19 * -0.01,
    color: StrideColors.textPrimary,
  );

  /// The banked-steps figure in the header. The one place accent type appears.
  static const TextStyle headerValue = TextStyle(
    fontSize: 19,
    height: 22 / 19,
    fontWeight: FontWeight.w700,
    letterSpacing: 19 * -0.01,
    fontFeatures: _tabular,
    color: StrideColors.accentSteps,
  );

  /// The largest figure on a screen. 28/30 per `build_html.js` `.t-display`.
  static const TextStyle numericHero = TextStyle(
    fontSize: 28,
    height: 30 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 28 * -0.02,
    fontFeatures: _tabular,
    color: StrideColors.textPrimary,
  );

  /// Tile values — `24`, `6,250`, `90`.
  static const TextStyle numericValue = TextStyle(
    fontSize: 22,
    height: 24 / 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 22 * -0.01,
    fontFeatures: _tabular,
    color: StrideColors.textPrimary,
  );

  /// `Meadow Patch`, `Traveler`.
  static const TextStyle cardTitle = TextStyle(
    fontSize: 21,
    height: 24 / 21,
    fontWeight: FontWeight.w700,
    letterSpacing: 21 * -0.01,
    color: StrideColors.textPrimary,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontSize: 16,
    height: 19 / 16,
    fontWeight: FontWeight.w700,
    color: StrideColors.textPrimary,
  );

  /// `STEPS`, `YIELD`, `EQUIPPED`, `CARRIED`. The system's dominant pattern is
  /// this label sitting above a [numericValue].
  static const TextStyle microLabel = TextStyle(
    fontSize: 11,
    height: 13 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 11 * 0.085,
    color: StrideColors.textMuted,
  );

  static const TextStyle body = TextStyle(
    fontSize: 12.5,
    height: 18 / 12.5,
    fontWeight: FontWeight.w400,
    color: StrideColors.textSecondary,
  );

  /// `Gathering Meadow Herb`.
  static const TextStyle sub = TextStyle(
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w600,
    color: StrideColors.textSecondary,
  );

  /// Inline metadata — `per gather`, `Meadow Herb`, `Foraging XP`.
  static const TextStyle micro = TextStyle(
    fontSize: 11,
    height: 13 / 11,
    fontWeight: FontWeight.w600,
    color: StrideColors.textSecondary,
  );

  /// Equipment-slot labels and filter pills.
  ///
  /// **9.5 px is below both the iOS 11 pt and Material 10 sp conventional
  /// floors for supporting text, and is unvalidated on hardware.** It is used
  /// because the approved renders use it; it is the first thing to re-check on a
  /// physical device.
  static const TextStyle compactLabel = TextStyle(
    fontSize: 9.5,
    height: 12 / 9.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 9.5 * 0.08,
    color: StrideColors.textMuted,
  );

  static const TextStyle tabLabel = TextStyle(
    fontSize: 9.5,
    height: 11 / 9.5,
    fontWeight: FontWeight.w600,
    color: StrideColors.textMuted,
  );

  static const TextStyle tabLabelActive = TextStyle(
    fontSize: 9.5,
    height: 11 / 9.5,
    fontWeight: FontWeight.w600,
    color: StrideColors.textPrimary,
  );

  /// Inventory item names. Two-line clamp at the call site.
  ///
  /// **10.5, up from 10.** The grid's semantic unit is icon + label + count
  /// (**L-17**), and at 10 px the label was the weakest of the three by a margin
  /// that made the grid scan as icons alone. Half a point is deliberately small:
  /// the icon still leads.
  static const TextStyle itemName = TextStyle(
    fontSize: 10.5,
    height: 13.5 / 10.5,
    fontWeight: FontWeight.w600,
    color: StrideColors.textSecondary,
  );

  /// `×24`.
  ///
  /// **14.5, up from 13.** Visual QA read the count as the second line of the
  /// item's name rather than as a quantity — the three parts of L-17's unit were
  /// all present and the discriminating one was not *reading* as a count. A
  /// point and a half over [itemName], in the primary colour rather than the
  /// secondary, is what separates them.
  static const TextStyle itemCount = TextStyle(
    fontSize: 14.5,
    height: 16 / 14.5,
    fontWeight: FontWeight.w700,
    fontFeatures: _tabular,
    color: StrideColors.textPrimary,
  );

  /// **15, up from 13.5.** The primary action was set smaller than the card
  /// titles, the skill names and the section headings around it, which is the
  /// wrong end of the hierarchy for the only control on the screen. It is still
  /// below [cardTitle], so the card still announces itself before its button.
  static const TextStyle buttonLabel = TextStyle(
    fontSize: 15,
    height: 18 / 15,
    fontWeight: FontWeight.w700,
    color: StrideColors.textPrimary,
  );

  /// `REQUIRES FORAGING 1`, `NO TOOL NEEDED`.
  static const TextStyle gateLabel = TextStyle(
    fontSize: 10,
    height: 12 / 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 10 * 0.06,
    color: StrideColors.textSecondary,
  );
}
