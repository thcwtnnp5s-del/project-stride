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

  /// Aligning figures for every numeral the player reads.
  ///
  /// **Alegreya Sans defaults to old-style figures**, and that default is wrong
  /// for this product in a way that is obvious the moment it renders: `12,480`
  /// came back with a descending 4 and a short 8, and `1 / 20` set the two
  /// numbers at visibly different heights. Old-style figures are drawn to sit
  /// inside lowercase prose; every numeral here is DATA — a step count, a level,
  /// an XP figure, a price — and data wants one height.
  static const List<FontFeature> _lining = <FontFeature>[
    FontFeature.liningFigures(),
  ];

  /// Lining **and** tabular: for figures that change in place or stack into a
  /// column, where a proportional digit makes the value jitter and a column of
  /// counts fail to align.
  ///
  /// **Public, and call sites must use it rather than building their own.**
  /// Twenty-two sites used to write `fontFeatures: [FontFeature.tabularFigures()]`
  /// into a `copyWith`, and `copyWith` REPLACES the list rather than adding to
  /// it — so every one of them silently dropped lining figures and rendered
  /// old-style digits. On the Adventure header that showed as `12,480` with a
  /// descending 4 and an x-height 0, directly beside a header figure that was
  /// lining. One exported constant makes the partial list unsayable.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.liningFigures(),
    FontFeature.tabularFigures(),
  ];

  /// The display register: screen and card titles, section headings, and the
  /// short all-caps labels that sit above a figure.
  ///
  /// Cinzel — inscriptional Roman capitals. Chosen because the identity this
  /// product reaches for is *carved and authored*, and the two obvious
  /// alternatives both fail: blackletter is the faux-medieval the owner ruled
  /// out, and a pixel display face at body sizes is the retro-arcade read that
  /// L-18 as amended forbids outright — **bitmap type is not in scope**. A
  /// serif with real Roman proportions stays legible at 11 px, which a
  /// decorative fantasy face does not.
  static const String displayFamily = 'Cinzel';

  /// The reading register, and every numeral.
  ///
  /// Alegreya Sans — humanist, warm, drawn for continuous text, and carrying
  /// real **lining** figures. That last part is not a nicety: the economy
  /// column stacks banked steps, costs and counts, and old-style figures with
  /// descending 3s and 9s in a right-aligned column read as noise.
  static const String textFamily = 'AlegreyaSans';

  /// Cinzel ships as a **variable** font, so `fontWeight` alone selects the
  /// default instance and every display style would render at one weight.
  /// The axis is therefore set explicitly, and `fontWeight` is kept beside it:
  /// the variation drives rendering, the weight keeps fallback and semantics
  /// right if the font ever fails to load.
  ///
  /// A `const` list, not a helper function — every style below is a compile-time
  /// constant and is used inside `const` widget trees at eight call sites.
  ///
  /// One weight, because every display role is authored at 700. A second
  /// variation constant is added when a role actually needs one, not before.
  static const List<FontVariation> _wght700 = <FontVariation>[
    FontVariation('wght', 700),
  ];

  /// `HAVEN'S REST` — the location line above the screen title.
  /// Uppercased by the caller, not by a text transform.
  static const TextStyle screenEyebrow = TextStyle(
    fontFamily: displayFamily,
    fontVariations: _wght700,
    fontSize: 11,
    height: 13 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 11 * 0.05,
    color: StrideColors.textMuted,
  );

  /// `Adventure`, `Inventory`, `Character`.
  ///
  /// **18, not the 19 the CSS spec carries, and the reason is the face.**
  /// Cinzel sets wider than the system font it replaced and has a taller cap
  /// height, so at 19 it both overflowed and looked larger than 19. At x1.2
  /// text scale on a 320 dp phone "Haven's Rest" needed 150.0 dp of the 148.3
  /// it was given — a real clip, caught by `ui_responsive_test`.
  ///
  /// Reducing the nominal size is the honest correction rather than a
  /// concession: it restores the *apparent* size the spec asked for while
  /// giving the string back the room it needs.
  static const TextStyle screenTitle = TextStyle(
    fontFamily: displayFamily,
    fontVariations: _wght700,
    fontSize: 18,
    height: 22 / 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 18 * -0.02,
    color: StrideColors.textPrimary,
  );

  /// The banked-steps figure in the header. The one place accent type appears.
  static const TextStyle headerValue = TextStyle(
    fontFamily: textFamily,
    fontSize: 19,
    height: 22 / 19,
    fontWeight: FontWeight.w700,
    letterSpacing: 19 * -0.01,
    fontFeatures: tabularFigures,
    color: StrideColors.accentSteps,
  );

  /// The largest figure on a screen. 28/30 per `build_html.js` `.t-display`.
  static const TextStyle numericHero = TextStyle(
    fontFamily: textFamily,
    fontSize: 28,
    height: 30 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 28 * -0.02,
    fontFeatures: tabularFigures,
    color: StrideColors.textPrimary,
  );

  /// Tile values — `24`, `6,250`, `90`.
  static const TextStyle numericValue = TextStyle(
    fontFamily: textFamily,
    fontSize: 22,
    height: 24 / 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 22 * -0.01,
    fontFeatures: tabularFigures,
    color: StrideColors.textPrimary,
  );

  /// `Meadow Patch`, `Traveler`.
  ///
  /// **19, not 21** — the same metric compensation as [screenTitle], and this
  /// is where it was measured: at x1.4 on a 320 dp phone "Woodcutting" needed
  /// 163.0 dp of the 156.9 available, a 4% overflow that clips a skill name on
  /// the screen whose whole subject is skill names.
  static const TextStyle cardTitle = TextStyle(
    fontFamily: displayFamily,
    fontVariations: _wght700,
    fontSize: 19,
    height: 24 / 19,
    fontWeight: FontWeight.w700,
    letterSpacing: 19 * -0.02,
    color: StrideColors.textPrimary,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontFamily: displayFamily,
    fontVariations: _wght700,
    fontSize: 16,
    height: 19 / 16,
    fontWeight: FontWeight.w700,
    color: StrideColors.textPrimary,
  );

  /// `STEPS`, `YIELD`, `EQUIPPED`, `CARRIED`. The system's dominant pattern is
  /// this label sitting above a [numericValue].
  ///
  /// **This is the one short label that stays in the TEXT family, and it is a
  /// width decision rather than a taste one.**
  ///
  /// Every other short label takes the display face. This one lives inside
  /// two-up value tiles, which are the narrowest measured box in the product:
  /// at x1.4 on a 320 dp phone the tile gives about 79 dp, and "TOTAL WALKED"
  /// in Cinzel caps needs 92. Cinzel sets roughly 16% wider than the sans it
  /// replaced, and there is no size or tracking that closes a 16% gap while
  /// leaving an 11 px label readable.
  ///
  /// The identity cost is small and the failure cost is not: these labels are
  /// muted 11 px captions above a figure, so they carry the least character of
  /// any display role, and clipping one is a caption that lies about which
  /// number it belongs to.
  static const TextStyle microLabel = TextStyle(
    fontFamily: textFamily,
    fontFeatures: _lining,
    fontSize: 11,
    height: 13 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 11 * 0.05,
    color: StrideColors.textMuted,
  );

  static const TextStyle body = TextStyle(
    fontFamily: textFamily,
    fontFeatures: _lining,
    fontSize: 12.5,
    height: 18 / 12.5,
    fontWeight: FontWeight.w400,
    color: StrideColors.textSecondary,
  );

  /// `Gathering Meadow Herb`.
  static const TextStyle sub = TextStyle(
    fontFamily: textFamily,
    fontFeatures: _lining,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w600,
    color: StrideColors.textSecondary,
  );

  /// Inline metadata — `per gather`, `Meadow Herb`, `Foraging XP`.
  static const TextStyle micro = TextStyle(
    fontFamily: textFamily,
    fontFeatures: _lining,
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
    fontFamily: textFamily,
    fontFeatures: _lining,
    fontSize: 9.5,
    height: 12 / 9.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 9.5 * 0.08,
    color: StrideColors.textMuted,
  );

  static const TextStyle tabLabel = TextStyle(
    fontFamily: textFamily,
    fontFeatures: _lining,
    fontSize: 9.5,
    height: 11 / 9.5,
    fontWeight: FontWeight.w600,
    color: StrideColors.textMuted,
  );

  static const TextStyle tabLabelActive = TextStyle(
    fontFamily: textFamily,
    fontFeatures: _lining,
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
    fontFamily: textFamily,
    fontFeatures: _lining,
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
    fontFamily: textFamily,
    fontSize: 14.5,
    height: 16 / 14.5,
    fontWeight: FontWeight.w700,
    fontFeatures: tabularFigures,
    color: StrideColors.textPrimary,
  );

  /// **15, up from 13.5.** The primary action was set smaller than the card
  /// titles, the skill names and the section headings around it, which is the
  /// wrong end of the hierarchy for the only control on the screen. It is still
  /// below [cardTitle], so the card still announces itself before its button.
  static const TextStyle buttonLabel = TextStyle(
    fontFamily: textFamily,
    fontFeatures: _lining,
    fontSize: 15,
    height: 18 / 15,
    fontWeight: FontWeight.w700,
    color: StrideColors.textPrimary,
  );

  /// A utility control's label. Two points under [buttonLabel], which is the
  /// type half of demoting `Sync steps` beneath `Gather`.
  static const TextStyle buttonLabelSecondary = TextStyle(
    fontFamily: textFamily,
    fontFeatures: _lining,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w600,
    color: StrideColors.textSecondary,
  );

  /// `REQUIRES FORAGING 1`, `NO TOOL NEEDED`.
  static const TextStyle gateLabel = TextStyle(
    fontFamily: textFamily,
    fontFeatures: _lining,
    fontSize: 10,
    height: 12 / 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 10 * 0.06,
    color: StrideColors.textSecondary,
  );
}
