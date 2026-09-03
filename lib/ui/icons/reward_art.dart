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

  /// A rare-or-better output — a cloth sack cinched at the neck, not a gem
  /// or a coin. Rarity-neutral so the same mark reads for Rare, Epic and
  /// Legendary alike; the word beside it, not the mark, names the rank
  /// (FMPO02 wave2, `REWARDS_report.md`).
  static const String markRareDrop = '$_root/mark_rare_drop.png';

  // ------------------------------------------------ 48², standing on its own

  /// A level gained.
  static const String plateLevelUp = '$_root/plate_level_up.png';

  /// A milestone reached — a cairn, for distance covered.
  static const String badgeMilestone = '$_root/badge_milestone.png';

  /// A profession's own advancement.
  ///
  /// **UNRESOLVED, unplaced** (`JOURNAL/OPEN_QUESTIONS.md` Q-24): no beat in
  /// the game currently names a whole-roadmap event distinct from an
  /// ordinary level-up, so wiring this to a guessed surface would be a
  /// silent design decision (`RULES.md` G-3). The asset exists; the
  /// occasion it marks does not yet.
  static const String markerProfession = '$_root/marker_profession.png';

  /// A contract closed.
  static const String sealContract = '$_root/seal_contract.png';

  /// A project completed.
  ///
  /// **`seal_project_bronze`, not `seal_project`** (EPO03, DIR-13 failure 5).
  /// The VAWO01 drawing is a set-square pressed into *teal* wax, and teal is
  /// the walking accent, reserved for step figures alone (`ART_DIRECTION.md`
  /// L-16). It sits outside `check-art-palette`'s DeltaRGB-10 radius, so no
  /// guard ever caught it; a zoom sheet did. The shipped file is the same
  /// drawing with its hue remapped to bronze — deterministic, per-colour,
  /// inventing nothing (`RULES.md` A-2). The teal master still ships as an
  /// orphan file — its emit is in the VAWO01 block, which this round does not
  /// own — and nothing reads it; dropping that one list row is a producer's
  /// line to delete.
  static const String sealProject = '$_root/seal_project_bronze.png';

  // ------------------------------------------------------- 96×48, a banner

  /// A signature drop — one of a kind, not merely a rarity tier. A
  /// rectangular leather plate, riveted and stitched, wide enough that it
  /// never shares a slot with the 48² seals it stands beside in kind but not
  /// in size (`RewardLayer.emblemSize`, FMPO02 wave2).
  static const String sealSignature = '$_root/seal_signature.png';

  /// A masterwork completion — the ceiling of craft quality, not a rung on
  /// the rarity ladder. A dark wood plank stamped with a bronze
  /// hammer-and-tongs medallion. One of only two marks wide enough to need
  /// [RewardLayer.emblemSize] (`ART-10_reward_brief.md` §1, §3).
  static const String sealMasterwork = '$_root/seal_masterwork.png';

  // ------------------------------------------------------------- ornament

  /// The corner bracket a notable result wears. 32² native, drawn ×1.
  static const String ornamentCorner = '$_root/ornament_corner.png';

  // ----------------------------------------- 89 × 22, the verb's own ribbon

  /// The plate the activity's verb is stamped on — one ribbon drawing
  /// (`KitMark.ribbonLabel`) in six skill tones (EPO03, DIR-13).
  ///
  /// DIR-13's second top failure was that a craft and a gather are the same
  /// picture: the result card swapped one grey micro word and nothing else,
  /// so MINED and FORGED were indistinguishable at arm's length. The verb now
  /// sits in a ribbon whose **wax tone** is the skill's, which is a difference
  /// the eye catches before it reads a letter.
  ///
  /// No word is baked: the ribbon's centre is transparent and the verb is set
  /// in type over the card's own fill (L-18). [stampVerbFor] resolves the
  /// tone; an unknown skill takes [stampVerbGathered], which is honest rather
  /// than wrong.
  static const String stampVerbMining = '$_root/stamp_verb_mining.png';
  static const String stampVerbWoodcutting =
      '$_root/stamp_verb_woodcutting.png';
  static const String stampVerbForaging = '$_root/stamp_verb_foraging.png';
  static const String stampVerbCooking = '$_root/stamp_verb_cooking.png';
  static const String stampVerbSmithing = '$_root/stamp_verb_smithing.png';
  static const String stampVerbGathered = '$_root/stamp_verb_gathered.png';

  /// The ribbon's authored footprint, drawn at ×1.
  static const int stampWidth = 89;
  static const int stampHeight = 22;

  /// The verb ribbon for a skill id, or the neutral one when the skill is
  /// unknown — a craft report carries a skill *name* and no id, and a node
  /// with no definition carries neither.
  static String stampVerbFor(String? skillId) => switch (skillId) {
    'skill.mining' => stampVerbMining,
    'skill.woodcutting' => stampVerbWoodcutting,
    'skill.foraging' => stampVerbForaging,
    'skill.cooking' => stampVerbCooking,
    'skill.smithing' => stampVerbSmithing,
    _ => stampVerbGathered,
  };

  // --------------------------------------------- 32², the rank's wax seal

  /// The wax seal a Rare-or-better find is sealed with — Craft's blank seal
  /// (`craft_seal_blank`) re-hued per rank (EPO03, DIR-13).
  ///
  /// **Three tones, deliberately.** The producer's running note on the recipe
  /// book is that six sealed pages carrying six identical saturated red seals
  /// read as a grid of stamps rather than as six sealed pages; the answer that
  /// note named as cheapest is a deterministic wax-tone remap. This family is
  /// that answer, applied before the seals ship rather than after.
  ///
  /// Blank, like the seal it comes from: the rank is stated in the word beside
  /// it, never pressed into the wax.
  static const String sealWaxRare = '$_root/seal_wax_rare.png';
  static const String sealWaxEpic = '$_root/seal_wax_epic.png';
  static const String sealWaxLegendary = '$_root/seal_wax_legendary.png';

  /// The wax seal's authored footprint, drawn at ×1.
  static const int sealWaxExtent = 32;

  // -------------------------------------------- 28 × 24, the ledger's tally

  /// A five-bar gate tally — four uprights and the stroke across them.
  ///
  /// The batch summary's picture. A run of five planks used to read as one
  /// line saying `×5`; it now reads as a tally on a ruled page. Static, by
  /// construction: the strokes are laid out at full size from the first frame
  /// and nothing counts up (`RULES.md` P-6).
  static const String glyphTally = '$_root/glyph_tally.png';

  static const int tallyWidth = 28;
  static const int tallyHeight = 24;

  /// Every asset in the set, for a precache or a coverage test.
  static const List<String> all = <String>[
    markExp,
    markSkillXp,
    markBonusYield,
    markKnowledge,
    markRareDrop,
    plateLevelUp,
    badgeMilestone,
    markerProfession,
    sealContract,
    sealProject,
    sealSignature,
    sealMasterwork,
    ornamentCorner,
    stampVerbMining,
    stampVerbWoodcutting,
    stampVerbForaging,
    stampVerbCooking,
    stampVerbSmithing,
    stampVerbGathered,
    sealWaxRare,
    sealWaxEpic,
    sealWaxLegendary,
    glyphTally,
  ];
}
