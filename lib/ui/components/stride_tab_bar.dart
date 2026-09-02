/// The six-destination bottom navigation.
///
/// ## What the owner said, and what it was
///
/// The device verdict on `59c4723` was **"bottom nav plain"**. Measured, it
/// was: a flat `surfaceCard` fill, a 1 px rule, six two-tone glyphs, and an
/// active tab declared by a slightly lighter rectangle. The one piece of
/// chrome the player sees on every screen of the product had one authored
/// element in it — the welt — and nothing else that said *leather*, *pressed*,
/// or *here*.
///
/// This file is the strap it became (`DIR-15_mobile_ux.md` §2):
///
/// - **The bar is a leather strap.** `grain_leather` runs the full height and
///   **into the home-indicator inset** — the paint moved here from
///   `StrideScaffold`, where a flat `#201C17` under the leather made a seam
///   across the bottom of every screen on a notched device.
/// - **The welt is the header's stitch.** `nav_welt_v2` is 8 × 6 at ×2 = 12 dp,
///   which is `ScreenHeader.shelfHeight` exactly, so the top of the app and
///   the bottom of the app are terminated by the same material.
/// - **An inactive tab is a well stamped into the strap.** Two inks, ≤ 6 L\*
///   apart, under the ceiling.
/// - **The active tab is a plate raised out of it**, lit along its top edge
///   against the welt, breaking the bar's top edge — the "you are here" mark
///   that reads as a physical change rather than as a highlight.
///
/// ## Q-26, answered: the glyph is type, the backing is chrome
///
/// FMPO02 authored eleven nav glyphs in the chassis ramp and PROD-UI
/// recommended against swapping them: authored under the `#7C7263` ceiling
/// they top out around 3.4:1 against the bar, where the shipped flat
/// silhouettes read at roughly 6:1, and the authored `_hi` pair separated
/// *less* than the derived remap did. `DIR-15` §2 settles it — **the glyph
/// belongs to the type ladder and its backing belongs to the chrome ceiling**.
///
/// So the six shipped silhouettes stay, and the active state is carried
/// entirely by the plate under them. That is what retires `_hi`: with a lit
/// plate under it, a brightened glyph is a second signal saying the same thing
/// less clearly, and `nav_world_hi` — the one variant FMPO02 could never
/// author — stops being needed at all. `Scripts/art/nav-active-variant.js` and
/// the six `_hi` PNGs are dead with this change.
///
/// ## Why the well and the plate are painted rather than rastered
///
/// `DIR-15` §2 specified both as nine-patches. Fourteen `pixen` rolls across
/// three prompt strategies could not produce one: the model draws a lit object
/// in perspective with studs, above the ceiling — the same boundary FMPO02
/// measured on `nav_plate_32` ("band 0/0/0/1 — a solid plate with no rim") and
/// on four other frame families it shipped none of. `RULES.md` A-1's fallback
/// applies: **PixelLab failed, so the temporary construction stays and the
/// gap is escalated**, rather than the round spending its cap re-deriving a
/// written-down reason (`MISTAKES.md` M-05).
///
/// It is also the reading `DECISIONS/0029` prefers. A raster may be an edge, a
/// tiled surface, or a discrete ornament, and it "may never carry a boundary
/// Flutter needs to measure". The active plate's boundary — 4 dp in from a
/// 52-wide cell, its lit rule against the welt — is measured by Flutter on
/// every build. The strap's material and its stitch are raster; the boundary
/// is Flutter's. The registry rows (`KitFrame.navWell`, `navPlateActive`) are
/// declared and empty, so a plate that is authored later lands without a call
/// site moving.
library;

import 'package:flutter/widgets.dart';

import '../shell/stride_destination.dart';
import 'stride_scaffold.dart';
import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'panel_skin.dart';
import 'pixel_asset.dart';
import 'surfaces.dart';

class StrideTabBar extends StatelessWidget {
  const StrideTabBar({
    super.key,
    required this.selected,
    required this.onSelect,
    this.bottomInset,
  });

  final StrideDestination selected;
  final ValueChanged<StrideDestination> onSelect;

  /// The home-indicator inset, painted **in the strap's own leather** below the
  /// tabs rather than in a flat colour underneath it.
  ///
  /// `StrideScaffold` used to draw this itself, in `surfaceCard`, which on a
  /// notched device put a flat rectangle under a leather bar — a seam along
  /// the bottom of every screen in the product, and the fourth item on
  /// `DIR-15`'s failure list. The scaffold now passes the figure down and the
  /// bar spends it, so the material runs to the bottom of the glass.
  ///
  /// It is deliberately **not** part of [StrideGeometry.tabBarHeight]: the bar
  /// is 64 dp of chrome wherever it is drawn, and the inset is a device fact
  /// added below it. `band_plate_test.dart` measures the 64.
  final double? bottomInset;

  /// The welt's room, reserved whether or not its raster decodes.
  ///
  /// **12, up from 8.** `nav_welt_v2` is 8 × 6 native at ×2, and 12 is
  /// `ScreenHeader.shelfHeight` — the same stitch terminating both frames, so
  /// they read as one chassis rather than as two unrelated edges. The bar's
  /// height is unchanged: the tabs give up 12 of their 64 instead of 8.
  static double get weltHeight => KitTiles.thicknessFor(KitTile.navWelt);

  /// The 64 dp content box — the tabs themselves, above the home-indicator
  /// inset the strap paints below them.
  ///
  /// A key rather than a private detail because the inset moved **inside**
  /// this widget (see [bottomInset]), so the bar's own bottom is now the
  /// bottom of the glass and is no longer a proxy for where the tabs end.
  /// `phase1_ui_test.dart` asserts that the tabs clear the home indicator,
  /// which is the invariant that actually matters, and it needs something
  /// stable to measure it against.
  static const Key contentKey = Key('stride_tab_bar_content');

  @override
  Widget build(BuildContext context) {
    final SurfaceTile? leather = PanelSurfaces.of(PanelSurface.leather);
    return _Leather(
      tile: leather,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            key: contentKey,
            // Fixed rather than minimum, and legitimately so: the labels below
            // run under `withNoTextScaling`, so nothing inside this bar can
            // grow. That clamp is what makes a fixed height safe here and
            // nowhere else in the app — see `StrideGeometry.tabBarHeight`.
            height: StrideGeometry.tabBarHeight,
            child: MediaQuery.withNoTextScaling(
              // Scoped to the tab-bar labels ONLY, and this is a real
              // accessibility cost taken deliberately rather than defaulted
              // into. Six fixed-width destinations at 9.5 px leave `Adventure`
              // roughly 4 dp of margin at 320 dp; under any enlarged scale the
              // six labels either wrap to three lines or overflow, and there is
              // no arrangement of six equal columns that avoids it.
              //
              // The clamp is correct *here* specifically because the tab bar is
              // chrome the player already knows by glyph and position. Every
              // content surface keeps free scaling.
              child: Stack(
                children: <Widget>[
                  // The tabs first, so the active plate's lit top edge can be
                  // drawn over the welt: the plate breaks the bar's top edge,
                  // which is what makes it read as raised rather than as a
                  // lighter rectangle inside a frame.
                  Positioned.fill(
                    top: weltHeight,
                    child: Row(
                      children: <Widget>[
                        for (final StrideDestination d
                            in StrideDestination.values)
                          Expanded(
                            child: _Tab(
                              destination: d,
                              isSelected: d == selected,
                              onTap: d.enabled ? () => onSelect(d) : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // The welt: an authored strip where a 1 px line was. Tiled at
                  // period 8, horizontally only, the last tile clipped —
                  // measured by `check-tile-seam.js` before it shipped, because
                  // a join that beats every 16 logical px across the bottom of
                  // every screen is the most visible possible place to get a
                  // seam wrong.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: KitEdge(
                        tile: KitTile.navWelt,
                        fallbackColor: StrideColors.borderDefault,
                      ),
                    ),
                  ),
                  // The active plate's lit rule, drawn last so it sits *on* the
                  // welt rather than under it.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: weltHeight,
                    child: IgnorePointer(
                      child: Row(
                        children: <Widget>[
                          for (final StrideDestination d
                              in StrideDestination.values)
                            Expanded(
                              child: d == selected
                                  ? const _PlateBreak()
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // The strap runs into the home indicator. Same leather, no seam.
          SizedBox(height: bottomInset ?? StrideBottomInset.of(context)),
        ],
      ),
    );
  }
}

/// The lit sliver the active plate pushes up through the welt.
///
/// Inset by the same 4 dp the plate is, so the break is exactly the plate's
/// width and reads as one object crossing the stitch rather than as a mark
/// drawn on it.
class _PlateBreak extends StatelessWidget {
  const _PlateBreak();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: _Tab.plateInset),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 2,
        decoration: const BoxDecoration(color: StrideColors.actionEdge),
      ),
    ),
  );
}

/// The bar's material: the flat card fill, then oiled leather over it.
///
/// A private wrapper rather than a bare [SurfaceFill] because the tile may be
/// absent — the registry is allowed to be empty, and an empty registry must
/// paint exactly what shipped before.
class _Leather extends StatelessWidget {
  const _Leather({required this.tile, required this.child});

  final SurfaceTile? tile;
  final Widget child;

  @override
  Widget build(BuildContext context) => tile == null
      ? DecoratedBox(
          decoration: const BoxDecoration(color: StrideColors.surfaceCard),
          child: child,
        )
      : SurfaceFill(
          tile: tile!,
          fill: StrideColors.surfaceCard,
          child: child,
        );
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final StrideDestination destination;
  final bool isSelected;
  final VoidCallback? onTap;

  /// How far the active plate stands in from its cell's edges, so the strap
  /// shows around it and it reads as a separate object lying on the leather.
  static const double plateInset = 4;

  /// The stamped well behind an inactive glyph: 36 × 28 dp (`DIR-15` §2).
  ///
  /// Sized to the glyph rather than to the cell, because a well as wide as the
  /// cell is a second bar, not a well.
  static const double wellWidth = 36;
  static const double wellHeight = 28;

  @override
  Widget build(BuildContext context) {
    // Q-26: the glyph is type. The shipped silhouette is used in both states —
    // the plate under it, not a brighter variant of it, is what says "here".
    final Widget glyph = PixelAsset.nav(destination.glyph);

    final Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        isSelected
            ? glyph
            : SizedBox(
                width: wellWidth,
                height: wellHeight,
                // The well: two inks under the ceiling, a shadowed top-left lip
                // and a faintly lit bottom-right one. It is the same light
                // direction every other piece of chrome in the product is drawn
                // under (upper left), which is why it reads as pressed into the
                // strap rather than as a box around the glyph.
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: StrideColors.surfaceGround,
                    border: Border(
                      top: BorderSide(color: StrideColors.surfaceGround),
                      left: BorderSide(color: StrideColors.surfaceGround),
                      right: BorderSide(color: StrideColors.separator),
                      bottom: BorderSide(color: StrideColors.separator),
                    ),
                  ),
                  child: Center(child: glyph),
                ),
              ),
        const SizedBox(height: StrideSpace.iconLabelGap),
        Text(
          destination.label,
          // Inactive labels at `textSecondary`, not `textMuted`: six 9.5 px
          // labels are the smallest type in the app and the owner's device read
          // the bar as "extremely plain" — muted grey on a dark bar is most of
          // why (ART-12 §8).
          style: isSelected
              ? StrideType.tabLabelActive.copyWith(
                  color: StrideColors.textPrimary,
                )
              : StrideType.tabLabel.copyWith(color: StrideColors.textSecondary),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
      ],
    );

    // The active tab is a plate raised out of the strap: inset from the cell's
    // edges, a lit top edge against the welt, the well gone. The fill alone was
    // what read as plain; the lit edge and the break through the welt are what
    // make it a bookmark rather than a highlight.
    //
    // `KitFrame.navPlateActive` is declared and empty, so when a plate is
    // authored it lands here without this call site moving — `KitPlate` already
    // reserves the same 8 dp inset the raster will use.
    final Widget body = isSelected
        ? Padding(
            padding: const EdgeInsets.fromLTRB(plateInset, 0, plateInset, 0),
            child: KitPlate(
              frame: KitFrame.navPlateActive,
              fill: StrideColors.surfaceRaised,
              raised: true,
              padding: EdgeInsets.zero,
              child: Center(child: content),
            ),
          )
        : Center(child: content);

    if (!destination.enabled) {
      // Not built yet, and honest about it. No snackbar, no dialog, no
      // navigation — a disabled control that explains itself by doing nothing
      // is less misleading than one that acknowledges a tap it will not honour.
      //
      // **0.28, down from 0.4.** Independent Visual QA, given the requirement
      // in advance, still read `Skills` and `Craft` as tappable across all four
      // screens and called it the highest-frequency defect in the set. The
      // reason 0.4 was not enough is that the *enabled* tabs are already
      // restrained, so 40% of subdued is not obviously less than subdued.
      return IgnorePointer(child: Opacity(opacity: 0.28, child: body));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: body,
    );
  }
}
