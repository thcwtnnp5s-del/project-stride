/// The one rarity style table.
///
/// A `Rarity` reaches the screen as three things and no more: an **ink** for
/// the item's name, a dimmer **accent** for the 1 px rule that frames it, and
/// the **label** the player reads. Every rarity-aware surface — the victory
/// panel, the inventory grid, the equipped summary, the craft card, the
/// character sheet — asks this table, so there is exactly one answer per rank
/// and changing one changes all of them.
///
/// ## Why the table and not a `switch` at each call site
///
/// The same reason [StrideColors.forSkill] exists: five call sites switching
/// on an enum are five places that agree until one of them is edited. It is
/// also the enforcement point for the two rules this palette has to keep — no
/// rank may be the walking teal (`ART_DIRECTION.md` **L-16**), and every rank
/// must be legible on the dark card surfaces — because a rule can only be
/// tested where the values are.
///
/// ## Colour is never the only carrier
///
/// [label] is not decoration. The owner's direction is that a player must be
/// able to *read* Rare, Epic and Legendary, so every surface that shows an ink
/// also shows the word, or is a dense grid cell where the word does not fit
/// and the accent rule is the whole claim (`inventory_screen.dart` records
/// that measurement). A screen that shows only the ink has dropped half the
/// information for anyone who does not separate these five hues.
library;

import 'dart:ui' show Color;

import 'package:stride_core/stride_core.dart' show Rarity;

import 'stride_colors.dart';

/// How one rank is drawn. Total, by construction: [of] is exhaustive over
/// `Rarity`, so a sixth rank is a compile error here rather than a silently
/// grey item on a device.
final class RarityStyle {
  const RarityStyle._({
    required this.rarity,
    required this.ink,
    required this.accent,
  });

  final Rarity rarity;

  /// The item's name, and the badge's word. Type weight is **unchanged** — a
  /// rarity recolours a name, it never promotes it.
  final Color ink;

  /// The 1 px rule, border, or faint plate behind the badge. Deliberately too
  /// dark to read as type: the restraint the owner asked for is that a rarity
  /// frames a card rather than fills one.
  final Color accent;

  /// The word — `Uncommon`, `Rare`. Straight off the enum, never a second
  /// spelling: `Rarity.label` is what content authored and what the session
  /// projects, and a display table that renamed a rank would be a second
  /// source for the same fact.
  String get label => rarity.label;

  /// The badge's form of [label].
  String get badgeLabel => rarity.label.toUpperCase();

  static const RarityStyle _uncommon = RarityStyle._(
    rarity: Rarity.uncommon,
    ink: StrideColors.rarityUncommon,
    accent: StrideColors.rarityUncommonDim,
  );
  static const RarityStyle _common = RarityStyle._(
    rarity: Rarity.common,
    ink: StrideColors.rarityCommon,
    accent: StrideColors.rarityCommonDim,
  );
  static const RarityStyle _rare = RarityStyle._(
    rarity: Rarity.rare,
    ink: StrideColors.rarityRare,
    accent: StrideColors.rarityRareDim,
  );
  static const RarityStyle _epic = RarityStyle._(
    rarity: Rarity.epic,
    ink: StrideColors.rarityEpic,
    accent: StrideColors.rarityEpicDim,
  );
  static const RarityStyle _legendary = RarityStyle._(
    rarity: Rarity.legendary,
    ink: StrideColors.rarityLegendary,
    accent: StrideColors.rarityLegendaryDim,
  );

  /// The style for [rarity]. Exhaustive; no default arm.
  static RarityStyle of(Rarity rarity) => switch (rarity) {
    Rarity.uncommon => _uncommon,
    Rarity.common => _common,
    Rarity.rare => _rare,
    Rarity.epic => _epic,
    Rarity.legendary => _legendary,
  };

  /// The style for a rarity that may be absent.
  ///
  /// **Null in, null out — never a default rank.** A null rarity on a session
  /// projection means the content pack has no definition for the item, which
  /// is a content fault the projections deliberately refuse to disguise
  /// (`stride_session.dart`, `InventoryEntry.rarity`). Substituting Uncommon
  /// here would turn a missing definition into a plausible grey label, and the
  /// screens would stop being able to tell the two apart. Every widget in
  /// `rarity_badge.dart` and `rarity_item_title.dart` renders *nothing extra*
  /// for null, which is the honest rendering of "unknown".
  static RarityStyle? maybe(Rarity? rarity) =>
      rarity == null ? null : of(rarity);

  /// The ink for a possibly-absent rarity, falling back to the ordinary text
  /// colour the surface would have used anyway.
  static Color inkOr(Rarity? rarity, Color fallback) =>
      rarity == null ? fallback : of(rarity).ink;
}
