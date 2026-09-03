/// The workshop's primary axis: three stations, drawn, standing on one shelf.
///
/// ## Why this is a widget rather than more chips
///
/// The owner's device verdict on the Craft screen was "a long mobile
/// database/list of repeated rectangles". The screen's top-level axis was four
/// text chips over one flat list of 39 rows, so nothing on it named a *place*
/// — and a bench, a forge and a cookfire are places, already drawn, already
/// packaged, already used by the running craft's stage
/// (`AmbientAssets.stationFor`). `ART-12_ux_brief.md` §1 makes the station the
/// primary axis and demotes the categories to a filter inside it, at the cost
/// of no content change and no new save state: every recipe already resolves
/// to a station through `AmbientAssets.craftStationKind`.
///
/// ## What EPO03 changed (`DIR-06` §2)
///
/// The owner's second read was that selection was **a brass border and
/// nothing else** — "the station is a picture in a box". Three plates each
/// wearing their own rounded rectangle is the card rhythm the round exists to
/// end, and a border cannot say "you are standing here".
///
/// So the strip is now one piece of furniture rather than three cards:
///
/// * a **shared shelf** (`KitTile.railShelf`) runs the full width beneath all
///   three, so the plates stand on one continuous surface;
/// * each station sits in a **plinth well** (`KitFrame.slotWell`) — recessed
///   when it is not the chosen one, and **raised** (lit lip, the kit's own
///   `raised` construction) when it is;
/// * the unchosen props keep their `lockedScrim`, the chosen one is full
///   colour, and the labels are engraved under the shelf rather than inside a
///   box.
///
/// No border colour, no radius and no new token is introduced: the raised /
/// recessed pair *is* the selection, which is what makes it survive at
/// 393 dp with the brass turned off.
///
/// ## The one measurement that matters
///
/// The plates are 88 dp tall and the props are 96² native drawn at ×1, so the
/// art is **taller than its plate** and has to be seated rather than fitted.
/// Fitting would rescale it off its integer multiple (L-18); centring it would
/// float each station at a different height, because a 96² canvas has a
/// different number of empty rows under each subject. So the plate seats the
/// prop by its measured `bounds.bottom` — the same arithmetic
/// `_EnemyStage.groundOffset` uses to put five creatures on one floor — and
/// clips whatever the plate cannot hold, which is at most two rows off the top
/// of the bench and the cookfire and nothing at all off the forge.
library;

import 'package:flutter/widgets.dart';

import '../icons/ambient_assets.dart';
import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'adaptive_text.dart';
import 'ambient_stage.dart';
import 'panel_skin.dart';
import 'pixel_asset.dart';
import 'surfaces.dart';

/// One station and the census of what it holds.
@immutable
final class StationEntry {
  const StationEntry({
    required this.kind,
    required this.label,
    required this.total,
    required this.ready,
  });

  /// The kind `AmbientAssets.craftStationKind` resolves — `forge`,
  /// `woodbench`, `cookfire`. The art table is keyed by it.
  final String kind;

  /// The player-facing name.
  final String label;

  /// How many recipes this station holds, whatever their readiness.
  final int total;

  /// How many of those can be made right now.
  final int ready;
}

/// Three station plinths, one row, equal widths, one shelf.
class StationStrip extends StatelessWidget {
  const StationStrip({
    super.key,
    required this.stations,
    required this.selected,
    required this.onSelect,
  });

  final List<StationEntry> stations;

  /// The selected station's [StationEntry.kind].
  final String selected;

  final ValueChanged<String> onSelect;

  /// The plate's height. The tap target is the plate *and* its label, so this
  /// is comfortably past the 44 dp floor either way.
  static const double plateHeight = 88;

  /// The props' native canvas, drawn ×1 (`AmbientAssets._stations`).
  static const int propNative = 96;

  /// How far to push a prop down so every station stands on one ground line.
  ///
  /// The 96² canvas has empty rows below each subject — the forge ends at row
  /// 88 of 96 — so seating the canvas rather than the subject would float the
  /// three at three different heights and the strip would stop reading as a
  /// row of workstations. Identical in form to `_EnemyStage.groundOffset`,
  /// and identical in purpose.
  static double groundOffset(StageScenery prop) =>
      (propNative - 1 - prop.bounds.bottom).toDouble();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final StationEntry entry in stations) ...<Widget>[
            if (entry != stations.first) const SizedBox(width: StrideSpace.s8),
            Expanded(
              child: _StationPlinth(
                entry: entry,
                selected: entry.kind == selected,
                onTap: () => onSelect(entry.kind),
              ),
            ),
          ],
        ],
      ),
      // The shelf all three stand on. One material, full width, no border —
      // the piece of furniture that replaces three boxes.
      const KitEdge(
        tile: KitTile.railShelf,
        fallbackColor: StrideColors.borderDefault,
      ),
      const SizedBox(height: StrideSpace.s6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final StationEntry entry in stations) ...<Widget>[
            if (entry != stations.first) const SizedBox(width: StrideSpace.s8),
            Expanded(
              child: _StationLabel(
                entry: entry,
                selected: entry.kind == selected,
                onTap: () => onSelect(entry.kind),
              ),
            ),
          ],
        ],
      ),
    ],
  );
}

/// One station's plinth: the prop in a well, recessed or raised.
class _StationPlinth extends StatelessWidget {
  const _StationPlinth({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final StationEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final StageScenery? prop = AmbientAssets.stationFor(entry.kind);
    final String census =
        '${entry.total} recipe'
        '${entry.total == 1 ? '' : 's'} · ${entry.ready} ready';

    return Semantics(
      button: true,
      selected: selected,
      label: '${entry.label}, $census',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: KitPlate(
          frame: KitFrame.slotWell,
          // The chosen plinth stands off the shelf; the other two are sunk
          // into it. The lit lip is the kit's own, so a raised station and a
          // pressed button agree about where the light comes from.
          raised: selected,
          fill: selected
              ? StrideColors.surfaceCard
              : StrideColors.surfaceGround,
          padding: EdgeInsets.zero,
          height: StationStrip.plateHeight,
          child: prop == null
              ? const SizedBox.shrink()
              : ClipRect(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned(
                        left: 0,
                        right: 0,
                        // Negative: the empty rows under the subject hang
                        // below the plate and are clipped, which is what puts
                        // the subject's own feet on the plinth's edge.
                        bottom: -StationStrip.groundOffset(prop),
                        height: StationStrip.propNative.toDouble(),
                        child: PixelScene(
                          assetPath: prop.assetPath,
                          nativeWidth: StationStrip.propNative,
                          nativeHeight: StationStrip.propNative,
                          // Unselected stations recede, exactly as a locked
                          // recipe's icon does — identity stays readable,
                          // attention does not scatter.
                          overlay: selected
                              ? null
                              : const Positioned.fill(
                                  child: ColoredBox(
                                    color: StrideColors.lockedScrim,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// The station's name and census, engraved on the bench under the shelf.
class _StationLabel extends StatelessWidget {
  const _StationLabel({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final StationEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AdaptiveText(
            entry.label,
            style: StrideType.microLabel,
            color: selected
                ? StrideColors.textPrimary
                : StrideColors.textSecondary,
          ),
          const SizedBox(height: StrideSpace.s2),
          // One line since EPO03 (`DIR-06` §2). The two-line form existed
          // because "23 recipes · 0 ready" needed 96 dp at `AdaptiveText`'s
          // legibility floor and a plate is ~91 dp wide; dropping the noun
          // buys the line back without lowering the floor, and the screen
          // reader still hears the whole sentence from the plinth's own
          // label.
          AdaptiveText(
            '${entry.total} · ${entry.ready} ready',
            style: StrideType.micro,
            color: entry.ready > 0
                ? StrideColors.positiveReady
                : StrideColors.textMuted,
          ),
        ],
      ),
    ),
  );
}
