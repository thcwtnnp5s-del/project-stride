/// The one seam every Traveler-drawing surface fetches its strips through —
/// the visible-equipment foundation
/// (GAME_FEEL_CHARACTER_PRESENTATION_01, item 5; architecture (B):
/// precomposed equipment-state sprite sets behind a single resolver).
///
/// ## What this is
///
/// Today every Traveler visual is one flattened strip with one baked outfit:
/// a generic pale-steel sword in every combat frame, a generic axe and pick
/// in the work loops, whatever is actually equipped — including nothing.
/// The owner wants equipped gear to become visible on the figure, and the
/// asset audit's honest answer is that **no on-body variant art exists yet**
/// and none may be generated this pass (the 25-generation reserve is the
/// atlas correction's).
///
/// So this file is the contract, shipped behaviorally inert:
///
/// - [EquipmentVisualState] (the session's fact projection) comes in;
/// - the item table maps item ids to **coarse variant classes** — never a
///   strip per item, which is how the combinatorics stay governable;
/// - the strip tables map (sequence family, variant) to packaged art;
/// - an absent entry — today, every entry — resolves to the **base strip**,
///   byte-identical to what every surface drew before this file existed.
///   Render base, never fake (`RULES.md` A-1): no hand-drawn gear, no
///   code-tinted blades, no icon pasted into a hand.
///
/// A future PixelLab gear round lands by packaging its strips through
/// `package-art.js` (which measures footprints as it does for everything)
/// and adding rows to the two tables below. No rendering-surface code
/// changes — that is the point of the seam.
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

  /// Item id → coarse variant class (`'item.bronze_sword' →
  /// 'weapon.bronze'`). **Deliberately empty**: no approved on-body art
  /// exists for any class yet, and an unmapped item is the base outfit by
  /// construction. Authored data, not code — a gear art round appends rows
  /// here (E-5).
  static const Map<String, String> variantOfItem = <String, String>{};

  /// (combat) weapon-variant class → the full combatant set for it.
  /// Empty until the first weapon round — which must include an
  /// **unarmed** set, because the baked generic sword currently
  /// contradicts an empty weapon slot (recorded in the milestone's gap
  /// register).
  static const Map<String, CombatantArt> combatVariants =
      <String, CombatantArt>{};

  /// (walk) armor-variant class → a six-frame west walk. Empty likewise.
  static const Map<String, List<String>> walkWestVariants =
      <String, List<String>>{};

  static String? _variantOf(String? itemId) =>
      itemId == null ? null : variantOfItem[itemId];

  /// The combat set for [visual] — the base Traveler until a weapon round
  /// lands. A fight's loadout is honest to snapshot at encounter start.
  static CombatantArt combatantFor(EquipmentVisualState visual) =>
      combatVariants[_variantOf(visual.weapon?.itemId)] ??
      CombatAssets.traveler;

  /// The travel walk for [visual] — the base west cycle until an armor
  /// round lands.
  static List<String> walkWestFor(EquipmentVisualState visual) =>
      walkWestVariants[_variantOf(visual.armor?.itemId)] ??
      travelerWalkWestFrames;
}
