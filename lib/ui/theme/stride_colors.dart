/// The colour tokens, read out of the approved Round 03 build rather than
/// invented for it.
///
/// Source of truth: the `:root` block of
/// `GAME_BIBLE/ART/exploration/WALKSCAPE_PIVOT_01/UI_EXPLORATION_02/build_html.js`,
/// as rendered into `shots_03/`. Where this file and that build disagree, the
/// build is right.
///
/// ## Why plain constants and not a `ThemeExtension`
///
/// A `ThemeExtension` requires `lerp`, and `lerp` is interpolation for a
/// transition this system explicitly forbids — there is no light mode, no second
/// theme, and no motion anywhere in the design. It also makes every read
/// `Theme.of(context).extension<StrideColors>()!`: a nullable lookup with a `!`
/// at every call site, failing at runtime rather than at compile time, and
/// nothing in the tree can be `const`.
///
/// The usual argument for scoping these behind a `BuildContext` is that a plain
/// constant is reachable from anywhere including the domain. That does not apply
/// here: `stride_core` is a separate package under `packages/` and cannot import
/// from `lib/` at all, which `Scripts/check-core-purity.sh` already enforces.
library;

import 'dart:ui' show Color;

import 'package:stride_core/stride_core.dart' show ContentId;

abstract final class StrideColors {
  const StrideColors._();

  // ---------------------------------------------------------------- surfaces
  //
  // A four-level ladder. Warm near-black rather than blue-grey slate, so the
  // pixel content — timber, canvas, oat cloth, stone — sits in a related colour
  // world instead of on a generic dark app ground.

  /// Page ground. **Also the inset well**, where the same value reads recessed
  /// because it is now darker than its container. That double duty is
  /// load-bearing, not an economy: a well is the page showing through, which is
  /// why it needs no separate value and why it must always carry
  /// [borderDefault] to declare its edge.
  static const Color surfaceGround = Color(0xFF14120F);

  /// Card. The primary content container.
  static const Color surfaceCard = Color(0xFF201C17);

  /// Block nested inside a card. Also the active-tab ground.
  static const Color surfaceBlock = Color(0xFF2C2620);

  /// Chip, pill, primary button. The only level that reads as *raised* rather
  /// than *contained*.
  static const Color surfaceRaised = Color(0xFF3A332B);

  // ------------------------------------------------------------------- lines
  //
  // Exactly one weight (1 logical px) and exactly one colour. There is no
  // second border weight and no second border colour, and the ladder should not
  // be extended without a reason. Outlined: card, well, track, gate, tab-bar
  // top edge. Not outlined: nested block, chip, item-tile interior.

  static const Color borderDefault = Color(0xFF372F27);

  /// Within-card rule between sections. Never used as an outline.
  static const Color separator = Color(0xFF29231D);

  // -------------------------------------------------------------------- text

  static const Color textPrimary = Color(0xFFF0E7D8);
  static const Color textSecondary = Color(0xFFB3A794);
  static const Color textMuted = Color(0xFF7C7263);

  // ------------------------------------------------------------------ accent

  /// **L-16. Walking, steps, and banked-step quantity. Nothing else, anywhere,
  /// ever.**
  ///
  /// Deliberately not gold: a gold numeral beside a glyph reads as currency, and
  /// Stride has none (`RULES.md` P-6).
  static const Color accentSteps = Color(0xFF58D6C0);

  /// The unfilled remainder of a step-clocked track only.
  static const Color accentStepsDim = Color(0xFF2C5E57);

  // ------------------------------------------------------------- skill hues
  //
  // A skill hue appears on a skill name, a skill chip, and a skill XP fill. It
  // never appears on a numeral, a card ground, a border, or a navigation
  // element. A skill hue must never occupy more area on a screen than
  // [accentSteps] does — a composition rule, not a palette rule, and the reason
  // five hues on the Character screen do not compete with one teal figure.

  static const Color skillForaging = Color(0xFFA9C24A);
  static const Color skillWoodcutting = Color(0xFF3F8F63);
  static const Color skillMining = Color(0xFF6E9BD0);
  static const Color skillSmithing = Color(0xFFD2703C);
  static const Color skillCooking = Color(0xFFD2566A);

  /// Resolved by content id rather than by a `switch` at each call site.
  ///
  /// Falls back to [textSecondary] rather than throwing: a sixth skill arriving
  /// in a content pack must not crash a screen. Content is data (`RULES.md`
  /// E-5), so the set of skills is not something this file may assume it knows.
  static Color forSkill(ContentId skill) => switch (skill.value) {
    'skill.foraging' => skillForaging,
    'skill.woodcutting' => skillWoodcutting,
    'skill.mining' => skillMining,
    'skill.smithing' => skillSmithing,
    'skill.cooking' => skillCooking,
    _ => textSecondary,
  };

  // --------------------------------------------------------- category hues
  //
  // DEFINED AND UNUSED, deliberately. Round 03 removed the 3 px category bar
  // from each inventory cell: it was imperceptible at native, a blind reader
  // could assign a category to none of twelve items, and it was spending colour
  // that the locked teal-means-walking relationship needs. Category is carried
  // in words, by the filter pills.
  //
  // Kept because the values exist and are already reasoned. **Do not
  // reintroduce them as a colour affordance without a fresh perceptual test.**

  static const Color categoryMaterial = Color(0xFF8FA36B);
  static const Color categoryEquipment = Color(0xFF7FA6D9);
  static const Color categoryConsumable = Color(0xFFD2566A);
  static const Color categoryQuest = Color(0xFFC9A63C);

  // There is deliberately NO success, warning, or error colour, because none is
  // present on the approved screens and none is proposed. Stride has no failure
  // states in this surface area — no capacity warning, no expiry, no decay, no
  // upkeep (`RULES.md` P-5). Adding a warning hue before a screen needs one is
  // how an unrequested pressure system acquires a colour.
}
