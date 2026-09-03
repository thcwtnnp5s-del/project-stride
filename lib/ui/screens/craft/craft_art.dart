/// The workshop's own art registry (EPO03, `DIR-06`).
///
/// Craft's chrome is screen-specific — a category glyph, a wax seal, a page's
/// dog-ear, the impression a finished craft leaves — so by `KIT_CONTRACT` §8
/// it lives in `assets/art/v1/ui/` under this screen's own prefix rather than
/// in the shared kit. Everything structural the screen needs (the sealed
/// page, the plinth well, the shelf, the ribbon, the ornate divider) comes
/// from the kit and is not restated here.
///
/// ## The doctrine, unchanged
///
/// A row that has not landed resolves to **null**, the widget paints its own
/// one-weight fallback, and the layout figure is reserved **either way**
/// (`TrackArt`'s precedent, `KIT_CONTRACT` §0). The recipe book therefore
/// lays out identically before and after a raster arrives: art changes the
/// material, never the geometry.
///
/// ## L-18
///
/// No raster here carries a numeral, a word or a state. A wax seal is a blank
/// seal and the level it asks for is set in `StrideType` over it; the five
/// category glyphs are told apart by **shape**, and each keeps its written
/// label beneath it regardless.
library;

import 'package:flutter/widgets.dart' show Size;

/// A single drawn mark: its source size and the integer scale it ships at.
final class CraftMark {
  const CraftMark({
    required this.assetPath,
    required this.nativeWidth,
    required this.nativeHeight,
    this.scale = 2,
  }) : assert(scale >= 1, 'integer multiples only (L-18)');

  final String assetPath;
  final int nativeWidth;
  final int nativeHeight;
  final int scale;

  Size get size =>
      Size((nativeWidth * scale).toDouble(), (nativeHeight * scale).toDouble());
}

abstract final class CraftArt {
  static const String _dir = 'assets/art/v1/ui';

  // ---------------------------------------------------------------------
  // Geometry — declared, spent unconditionally, identical with or without a
  // raster. Nothing below this line may be read from an asset.
  // ---------------------------------------------------------------------

  /// A category glyph on the rail: 24 native at x2.
  static const double categoryGlyph = 48;

  /// A wax seal on a sealed page, with the required level set over it.
  static const double seal = 64;

  /// The dog-ear folded off a sealed page's outer corner.
  static const double dogEar = 24;

  /// The impression a finished craft presses onto the output well.
  static const double stamp = 96;

  /// The pursuit bookmark hanging off the folio's top edge.
  static const Size ribbon = Size(24, 40);

  // ---------------------------------------------------------------------
  // Rows. A null row is the normal state of this table, not an error.
  // ---------------------------------------------------------------------

  /// Which rows have actually landed and been read at phone scale.
  ///
  /// **This set is the registry's on-switch.** A mark is declared below with
  /// its real geometry the day it is designed, and starts drawing the day its
  /// name is added here — one line, after the render has been looked at.
  static const Set<String> _landed = <String>{};

  static bool _has(String path) => _landed.contains(path);

  static CraftMark? _resolve(CraftMark m) => _has(m.assetPath) ? m : null;

  /// The five filter glyphs, keyed by the rail's own token.
  static const Map<String, CraftMark> _categories = <String, CraftMark>{
    'all': CraftMark(
      assetPath: '$_dir/craft_cat_all.png',
      nativeWidth: 24,
      nativeHeight: 24,
    ),
    'materials': CraftMark(
      assetPath: '$_dir/craft_cat_materials.png',
      nativeWidth: 24,
      nativeHeight: 24,
    ),
    'food': CraftMark(
      assetPath: '$_dir/craft_cat_food.png',
      nativeWidth: 24,
      nativeHeight: 24,
    ),
    'gear': CraftMark(
      assetPath: '$_dir/craft_cat_gear.png',
      nativeWidth: 24,
      nativeHeight: 24,
    ),
    'tools': CraftMark(
      assetPath: '$_dir/craft_cat_tools.png',
      nativeWidth: 24,
      nativeHeight: 24,
    ),
  };

  static CraftMark? categoryFor(String token) {
    final CraftMark? m = _categories[token];
    return m == null ? null : _resolve(m);
  }

  /// The wax seals, one per crafting trade plus the taught seal the
  /// contract-gated chapter wears. Keyed by the lower-cased skill name so a
  /// trade with no seal of its own falls back to the painted disc rather
  /// than borrowing another trade's wax.
  static const Map<String, CraftMark> _seals = <String, CraftMark>{
    'smithing': CraftMark(
      assetPath: '$_dir/craft_seal_smithing.png',
      nativeWidth: 32,
      nativeHeight: 32,
    ),
    'cooking': CraftMark(
      assetPath: '$_dir/craft_seal_cooking.png',
      nativeWidth: 32,
      nativeHeight: 32,
    ),
    'woodcutting': CraftMark(
      assetPath: '$_dir/craft_seal_woodcutting.png',
      nativeWidth: 32,
      nativeHeight: 32,
    ),
    'taught': CraftMark(
      assetPath: '$_dir/craft_seal_taught.png',
      nativeWidth: 32,
      nativeHeight: 32,
    ),
  };

  static CraftMark? sealFor(String skill) {
    final CraftMark? m = _seals[skill.toLowerCase()];
    return m == null ? null : _resolve(m);
  }

  static const CraftMark _dogEarMark = CraftMark(
    assetPath: '$_dir/craft_dogear.png',
    nativeWidth: 12,
    nativeHeight: 12,
  );

  static CraftMark? get dogEarMark => _resolve(_dogEarMark);

  static const CraftMark _stampMade = CraftMark(
    assetPath: '$_dir/craft_stamp_made.png',
    nativeWidth: 48,
    nativeHeight: 48,
  );

  static CraftMark? get stampMade => _resolve(_stampMade);

  static const CraftMark _ribbonPursuit = CraftMark(
    assetPath: '$_dir/craft_ribbon_pursuit.png',
    nativeWidth: 12,
    nativeHeight: 20,
  );

  static CraftMark? get ribbonPursuit => _resolve(_ribbonPursuit);
}
