/// The marks a payoff is made of (VAWO01, `REWARD_ROUND_RECORD_01.md`).
///
/// ## Why these exist
///
/// The universal result card carried no authored art of its own: an item icon,
/// three lines of type, and a border that got 1 px wider when the result was
/// notable. Crafting a Bronze Sword and cooking Herb Broth were the same
/// picture with different words — which is the owner's *"it must feel more
/// significant without becoming casino-like"* stated from the other side.
///
/// So the escalation is **material, not motion**: a common result keeps the
/// plain card, and a notable one gains a bronze corner bracket at two corners
/// and its rarity's ink. Nothing flashes, nothing counts up, nothing spins.
///
/// ## The two canvases
///
/// Both are the icon families' own conventions, so a mark keeps the same
/// logical footprint in every row it appears in:
///
/// - **24² at ×1** — a mark that sits beside a line of type, matching the
///   skill icons.
/// - **48² at ×1** — a plate, badge or seal that stands on its own, matching
///   the item icons.
///
/// [ornamentCorner] is 32² and is the exception: it is not an icon but the
/// *discrete ornament* `DECISIONS/0029` permits Flutter to position. It is
/// drawn rotated into each corner it occupies, which is a transform of one
/// authored asset and not four drawings.
library;

abstract final class RewardArt {
  const RewardArt._();

  static const String _root = 'assets/art/v1/reward';

  // ------------------------------------------- 24², beside a line of type

  /// Experience gained. The one mark that appears on almost every payoff.
  static const String markExp = '$_root/mark_exp.png';

  /// A skill's own progress, as distinct from the run's experience.
  static const String markSkillXp = '$_root/mark_skill_xp.png';

  /// A yield bonus procced — the extra above what the recipe promised.
  static const String markBonusYield = '$_root/mark_bonus_yield.png';

  /// Something learned: a recipe, a rumour, a route.
  static const String markKnowledge = '$_root/mark_knowledge.png';

  // ------------------------------------------------ 48², standing on its own

  /// A level gained.
  static const String plateLevelUp = '$_root/plate_level_up.png';

  /// A milestone reached — a cairn, for distance covered.
  static const String badgeMilestone = '$_root/badge_milestone.png';

  /// A profession's own advancement.
  static const String markerProfession = '$_root/marker_profession.png';

  /// A contract closed.
  static const String sealContract = '$_root/seal_contract.png';

  /// A project completed.
  static const String sealProject = '$_root/seal_project.png';

  // ------------------------------------------------------------- ornament

  /// The corner bracket a notable result wears. 32² native, drawn ×1.
  static const String ornamentCorner = '$_root/ornament_corner.png';

  /// Every asset in the set, for a precache or a coverage test.
  static const List<String> all = <String>[
    markExp,
    markSkillXp,
    markBonusYield,
    markKnowledge,
    plateLevelUp,
    badgeMilestone,
    markerProfession,
    sealContract,
    sealProject,
    ornamentCorner,
  ];
}
