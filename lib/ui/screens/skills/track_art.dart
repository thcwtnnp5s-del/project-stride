/// The Skills journey's own art registry (EPO03, `DIR-07`).
///
/// The journey family was struck from the shared kit contract (`KIT_CONTRACT`
/// §8, 2026-09-02): NAV authors none of it, so the road, its joints, its
/// folds, its badges and its caps live here, in
/// `assets/art/v1/track/`, and this screen is the only consumer.
///
/// ## The doctrine, unchanged
///
/// A row that has not landed resolves to **null**, the widget paints its own
/// one-weight fallback, and the layout figure is reserved **either way**
/// (`PanelSkins.insetFor` precedent, `KIT_CONTRACT` §0). So the journey lays
/// out identically before and after a raster arrives: art changes the
/// material, never the geometry. That is what let the screen be finished as
/// structure first and gain material afterwards.
///
/// ## L-18
///
/// No raster in this family carries a number, a word or a state. A level
/// badge is a blank stone plate and `LV n` is set in `StrideType` over it; the
/// four joint states are told apart by **shape**, not by a label baked into
/// the pixels.
library;

import 'package:flutter/widgets.dart' show Size;
import 'package:stride_core/stride_core.dart' show ContentId;

import '../../components/panel_skin.dart' show PanelSkin;
import 'journey_model.dart' show JoinState;

/// A single drawn mark: its source size and the integer scale it ships at.
final class TrackMark {
  const TrackMark({
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

/// A strip tiled along one axis at integer scale, last tile clipped.
final class TrackStrip {
  const TrackStrip({
    required this.assetPath,
    required this.nativeWidth,
    required this.nativeHeight,
    this.scale = 2,
  }) : assert(scale >= 1, 'integer multiples only (L-18)');

  final String assetPath;
  final int nativeWidth;
  final int nativeHeight;
  final int scale;

  double get width => (nativeWidth * scale).toDouble();
  double get period => (nativeHeight * scale).toDouble();
}

abstract final class TrackArt {
  static const String _dir = 'assets/art/v1/track';

  // ---------------------------------------------------------------------
  // Geometry — declared, spent unconditionally, identical with or without a
  // raster. Nothing below this line may be read from an asset.
  // ---------------------------------------------------------------------

  /// The gutter the road runs down, and the box every joint is centred in.
  static const double rail = 48;

  /// The road's own width inside that rail.
  static const double roadWidth = 32;

  /// A joint's box — the shape that says reached / here / next / far.
  static const double jointExtent = 48;

  /// A fold in the road, and the end cap that closes it.
  static const double foldHeight = 48;
  static const double capHeight = 48;

  /// The level badge plate: a blank stone, `LV n` set in type over it.
  static const Size badge = Size(56, 40);

  /// An entry's well — an item icon, a cairn, or a region mark.
  static const double wellContent = 48;

  /// The trade's hero emblem at the head of the road.
  static const double emblem = 64;

  /// The gate seal beside an entry that needs more than the level.
  static const double seal = 24;

  // ---------------------------------------------------------------------
  // Rows. A null row is the normal state of this table, not an error.
  // ---------------------------------------------------------------------


  /// Which rows have actually landed and been read at phone scale.
  ///
  /// **This set is the registry's on-switch.** A mark is declared below with
  /// its real geometry the day it is designed, and starts drawing the day its
  /// name is added here — one line, after the render has been looked at. A
  /// name absent from this set resolves to null and the widget paints the
  /// fallback it was built with, at the same size.
  static const Set<String> _landed = <String>{};

  static bool _has(String path) => _landed.contains(path);

  /// The road itself — a vertical strip, tiled down the rail, never
  /// stretched; the last tile is clipped.
  static const TrackStrip _road = TrackStrip(
    assetPath: '$_dir/road_ink.png',
    nativeWidth: 16,
    nativeHeight: 32,
  );

  static TrackStrip? get road => _has(_road.assetPath) ? _road : null;

  /// The four joints, by state. Shape carries the state; the raster carries
  /// no numeral and no word.
  static const Map<JoinState, TrackMark> _joints = <JoinState, TrackMark>{
    JoinState.reached: TrackMark(
      assetPath: '$_dir/joint_reached.png',
      nativeWidth: 24,
      nativeHeight: 24,
    ),
    JoinState.current: TrackMark(
      assetPath: '$_dir/joint_here.png',
      nativeWidth: 24,
      nativeHeight: 24,
    ),
    JoinState.next: TrackMark(
      assetPath: '$_dir/joint_next.png',
      nativeWidth: 24,
      nativeHeight: 24,
    ),
    JoinState.far: TrackMark(
      assetPath: '$_dir/joint_far.png',
      nativeWidth: 24,
      nativeHeight: 24,
    ),
  };

  static TrackMark? jointFor(JoinState join) {
    final TrackMark? m = _joints[join];
    return m != null && _has(m.assetPath) ? m : null;
  }

  /// The painted fold an empty run or a walked stretch sinks into.
  static const TrackMark _fold = TrackMark(
    assetPath: '$_dir/road_fold.png',
    nativeWidth: 16,
    nativeHeight: 24,
  );

  static TrackMark? get fold => _has(_fold.assetPath) ? _fold : null;

  /// The cap that closes the road at the content horizon.
  static const TrackMark _endCap = TrackMark(
    assetPath: '$_dir/road_end.png',
    nativeWidth: 16,
    nativeHeight: 24,
  );

  static TrackMark? get endCap => _has(_endCap.assetPath) ? _endCap : null;

  /// The blank stone a level numeral is set on — worn behind the walker, lit
  /// at and ahead of them. Two plates, no numerals (L-18).
  static const TrackMark _badgeWorn = TrackMark(
    assetPath: '$_dir/badge_worn.png',
    nativeWidth: 28,
    nativeHeight: 20,
  );
  static const TrackMark _badgeLit = TrackMark(
    assetPath: '$_dir/badge_lit.png',
    nativeWidth: 28,
    nativeHeight: 20,
  );

  static TrackMark? badgePlate({required bool lit}) {
    final TrackMark m = lit ? _badgeLit : _badgeWorn;
    return _has(m.assetPath) ? m : null;
  }

  /// The one node with a backplate: "you are here".
  static const PanelSkin? herePlate = null;

  /// The gauge frame beside the hero emblem, whose window `ProgressRule`
  /// fills. Nine-patch: corners once, edges tiled, interior never drawn.
  static const PanelSkin? gaugeFrame = null;

  /// The seal on an entry that needs more than its level.
  static const TrackMark _gateSeal = TrackMark(
    assetPath: '$_dir/gate_seal.png',
    nativeWidth: 24,
    nativeHeight: 24,
    scale: 1,
  );

  static TrackMark? get gateSeal =>
      _has(_gateSeal.assetPath) ? _gateSeal : null;

  /// A trade's hero emblem, 64².
  static TrackMark? emblemFor(ContentId skill) {
    final String? name = switch (skill.value) {
      'skill.foraging' => 'emblem_foraging',
      'skill.woodcutting' => 'emblem_woodcutting',
      'skill.mining' => 'emblem_mining',
      'skill.smithing' => 'emblem_smithing',
      'skill.cooking' => 'emblem_cooking',
      _ => null,
    };
    if (name == null) return null;
    final String path = '$_dir/$name.png';
    if (!_has(path)) return null;
    return TrackMark(
      assetPath: path,
      nativeWidth: 64,
      nativeHeight: 64,
      scale: 1,
    );
  }

  /// A region's mark, for a site entry's well. Null until the five marks
  /// land; the well then falls back to the site's own node art.
  static TrackMark? regionMark(String? place) => null;
}
