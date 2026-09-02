/// The one seam every Traveler-drawing surface fetches its strips through —
/// the visible-equipment foundation
/// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 5; architecture (B):
/// precomposed equipment-state sprite sets behind a single resolver).
///
/// ## What this is
///
/// Every Traveler visual used to be one flattened strip with one baked
/// outfit: a generic pale-steel sword in every combat frame, a generic axe
/// and pick in the work loops, whatever was actually equipped — including
/// nothing. This is the seam that lets equipped gear become visible on the
/// figure without every drawing surface learning what equipment is.
///
/// So this file is the contract:
///
/// - [EquipmentVisualState] (the session's fact projection) comes in;
/// - the item table maps item ids to **coarse variant classes** — never a
///   strip per item, which is how the combinatorics stay governable;
/// - the strip tables map (sequence family, variant) to packaged art;
/// - an absent entry resolves to the **base strip**, byte-identical to what
///   every surface drew before this file existed. Render base, never fake
///   (`RULES.md` A-1): no hand-drawn gear, no code-tinted blades, no icon
///   pasted into a hand.
///
/// ## What has since landed
///
/// The file shipped behaviourally inert, with both tables empty. Two rounds
/// have filled them:
///
/// - **Armour** (VAWO01) — three `create_character_state` figures on the
///   canonical Traveler, so eight chest items now show what is worn.
/// - **Weapons** (VAWO01) — an `unarmed` and a `bronze` combat set. The
///   unarmed one is the important half: an empty weapon slot used to fall
///   through to the base, whose every frame bakes a generic steel sword, so
///   the stage drew a blade the player did not own. [combatantFor] treats an
///   empty slot as a value rather than a miss for exactly that reason.
///
/// The walk table is still empty, and still degrades to the base cycle.
///
/// ## Rejected: runtime overlays
///
/// A weapon overlay needs a per-frame hand anchor and occlusion order on
/// 100+ frames of flattened art that already contains a baked generic tool
/// the overlay would double-draw. That data does not exist and cannot be
/// measured deterministically — it is a creative judgment, which A-1 gives
/// to PixelLab. Precomposed variant strips ride the existing pipeline
/// unchanged instead.
library;

import '../../runtime/stride_session.dart' show EquipmentVisualState;
import 'combat_assets.dart';

abstract final class TravelerArt {
  const TravelerArt._();

  /// The base six-frame west walk — the travel card's cycle, canonical
  /// here so the card and any future variant table cannot drift apart.
  static final List<String> travelerWalkWestFrames = List<String>.generate(
    6,
    (int i) => 'assets/art/v1/anim/traveler_walk_west_f$i.png',
    growable: false,
  );

  /// Item id → coarse variant class.
  ///
  /// **Coarse on purpose.** Ten armour items resolve to three classes, because
  /// a strip per item is how the combinatorics stop being governable — and
  /// because the classes are what the player actually reads at sprite scale: a
  /// breastplate, a fur jerkin, a long coat. Two bronze chestplates that differ
  /// by a frost resistance value look identical to an eye and should.
  ///
  /// An unmapped item is the base outfit by construction, so a content pack
  /// that adds an item before its art exists degrades to the Traveler rather
  /// than to a hole. Authored data, not code (E-5).
  static const Map<String, String> variantOfItem = <String, String>{
    // The starter tunics are the base figure — no row, deliberately.
    // Plate: hard bronze over the shirt.
    'item.bronze_chestplate': 'armor.plate',
    'item.scalewarmed_chestplate': 'armor.plate',
    // Jerkin: hide and fur, bulkier through the chest.
    'item.wolfhide_jerkin': 'armor.jerkin',
    'item.tuskbound_jerkin': 'armor.jerkin',
    'item.frostlined_jerkin': 'armor.jerkin',
    // Coat: long, belted, the heaviest silhouette.
    'item.bearhide_coat': 'armor.coat',
    'item.clawguard_coat': 'armor.coat',
    'item.frostwarden_coat': 'armor.coat',
    // Weapons. `item.training_sword` is deliberately unmapped — the base
    // figure's baked blade is a plain steel training sword already, so it is
    // the one item the base set tells the truth about. The three bronze-tier
    // blades share a class because they share a silhouette.
    'item.bronze_sword': 'weapon.bronze',
    'item.bronze_longsword': 'weapon.bronze',
    'item.fanghilt_sword': 'weapon.bronze',
  };

  /// Armour class → the standing figure that wears it.
  ///
  /// One 64² south rotation per class, from PixelLab
  /// `create_character_state` on the canonical Traveler — the same individual
  /// the shipped sprite is a rotation of, so these are variants rather than
  /// lookalikes.
  static const Map<String, String> armorFigures = <String, String>{
    'armor.plate': 'assets/art/v1/sprite/traveler_south_plate.png',
    'armor.jerkin': 'assets/art/v1/sprite/traveler_south_jerkin.png',
    'armor.coat': 'assets/art/v1/sprite/traveler_south_coat.png',
  };

  /// The standing figure for [visual] — what the player is wearing.
  ///
  /// The base Traveler when nothing is equipped, or when what is equipped has
  /// no authored class. Never a hole, never a guess.
  static String figureFor(EquipmentVisualState visual) =>
      armorFigures[_variantOf(visual.armor?.itemId)] ??
      'assets/art/v1/sprite/traveler_south.png';

  /// (combat) weapon-variant class → the full combatant set for it.
  ///
  /// Two classes cover every weapon in the game, which is what makes the
  /// coarse mapping complete here rather than merely cheap:
  ///
  /// - `weapon.unarmed` — nothing equipped. This is the row the round existed
  ///   to add. The base set bakes a sword into all 28 of its frames, so before
  ///   this the interface showed a blade the player did not own.
  /// - `weapon.bronze` — the three bronze-tier blades, which read as one
  ///   weapon at 2× on a phone and differ only in numbers.
  ///
  /// `item.training_sword` is absent on purpose, not by omission: the base
  /// set's pale-steel blade already *is* a plain training sword, so falling
  /// through to the base is the honest answer for it.
  static final Map<String, CombatantArt> combatVariants =
      <String, CombatantArt>{
        'weapon.unarmed': CombatAssets.travelerUnarmed,
        'weapon.bronze': CombatAssets.travelerBronze,
      };

  /// (walk) armor-variant class → a six-frame west walk. Empty likewise.
  static const Map<String, List<String>> walkWestVariants =
      <String, List<String>>{};

  static String? _variantOf(String? itemId) =>
      itemId == null ? null : variantOfItem[itemId];

  /// The combat set for [visual] — what the Traveler is actually holding. A
  /// fight's loadout is honest to snapshot at encounter start.
  ///
  /// **An empty weapon slot is a value, not a miss.** It resolves to the
  /// unarmed set rather than falling through to the base, because the base is
  /// the one answer that is definitely wrong for it. Only an *equipped* item
  /// with no authored class falls through, which keeps `RULES.md` E-5 intact:
  /// a content pack that adds a weapon before its art exists still draws a
  /// Traveler with a sword, never a hole.
  static CombatantArt combatantFor(EquipmentVisualState visual) {
    final String? weapon = visual.weapon?.itemId;
    if (weapon == null) return CombatAssets.travelerUnarmed;
    return combatVariants[variantOfItem[weapon]] ?? CombatAssets.traveler;
  }

  /// The travel walk for [visual] — the base west cycle until an armor
  /// round lands.
  static List<String> walkWestFor(EquipmentVisualState visual) =>
      walkWestVariants[_variantOf(visual.armor?.itemId)] ??
      travelerWalkWestFrames;
}
