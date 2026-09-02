/// The container primitives: card, nested block, and inset well.
///
/// The surface ladder is four levels and the border ladder is exactly one
/// weight in exactly one colour. A nested block is declared by its fill alone; a
/// well is declared by fill *and* outline. That is the whole system, and it
/// should not be extended without a reason.
///
/// **The reason arrived** (`DECISIONS/0029`, owner ruling 2026-08-31). The
/// system was built narrow on purpose and then never given a second visual
/// register, so one rectangle came to draw thirty-four panels and the product
/// read as an application rather than a game. [SectionCard] now names a
/// [PanelRole], and `panel_skin.dart` decides whether that role has authored
/// art. The ladder above is unchanged; what changed is that a rung may now be
/// made of something.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'adaptive_text.dart';
import 'panel_skin.dart';
import 'pixel_asset.dart';

/// The universal content container.
///
/// [wash] (Fable V2 Iteration 02) breathes an identity colour down from the
/// card's top — a skill's deep on its Skills card, a region's deep on a
/// place card — fading into the ordinary card surface by mid-height. The
/// deeps are authored within ~6 L* of the card colour, so a washed card
/// reads as *atmosphere on the same surface*, never as a fifth surface
/// rung; type contrast is measured against [StrideColors.surfaceCard]
/// either way. One primitive, so identity washes cannot become per-screen
/// one-offs.
/// [role] (PRESENTATION_COMBAT_EVOLUTION_01) names what this panel **is**, so
/// that authored frame art can replace the painted rectangle later without
/// touching any of the ~34 call sites. Today every role resolves to null in
/// [PanelSkins] and every card paints exactly what it always painted; the
/// registry is the whole integration surface of `DECISIONS/0029`. See
/// `panel_skin.dart` for why the genericness the owner named is this one
/// rectangle repeated, and why a registry is the fix rather than a parameter.
/// The smallest gap kept between an authored frame's inner line and the type
/// inside it. Not zero: type beginning hard against the frame's inner dark line
/// reads as a layout error even when the arithmetic is right.
const double _framedGap = 6;

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding,
    this.wash,
    this.role = PanelRole.card,
    this.surface = PanelSurface.none,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? wash;
  final PanelRole role;

  /// What the panel's interior is made of (FMPO02). [PanelSurface.none] is
  /// the flat fill every card had before; an authored material is drawn as a
  /// tiled grain under the child, inside the frame's band when the role is
  /// framed and inside the rounded rectangle when it is not. This, not a
  /// second border, is how two screens stop looking like one screen.
  final PanelSurface surface;

  /// The painted rectangle: what every panel looks like until its role has
  /// art, and what every panel falls back to if that art fails to load.
  BoxDecoration _painted() => BoxDecoration(
    color: wash == null ? StrideColors.surfaceCard : null,
    gradient: wash == null
        ? null
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[wash!, StrideColors.surfaceCard],
            stops: const <double>[0, 0.45],
          ),
    border: Border.all(color: StrideColors.borderDefault),
    borderRadius: StrideRadius.card,
  );

  @override
  Widget build(BuildContext context) {
    final EdgeInsetsGeometry pad =
        padding ?? const EdgeInsets.all(StrideSpace.cardPadding);
    final PanelSkin? skin = PanelSkins.of(role);
    final SurfaceTile? tile = PanelSurfaces.of(surface);

    if (skin == null) {
      // The unframed path. A surface role reserves nothing (it is not
      // waiting for a frame); a framed role whose asset is absent reserves
      // its inset so the material changes and the layout does not.
      final double reserve = PanelSkins.insetFor(role);
      final EdgeInsetsGeometry padding = reserve == 0
          ? pad
          : pad.add(EdgeInsets.all(reserve)).resolve(TextDirection.ltr);
      if (tile == null || wash != null) {
        // A wash is a gradient over the flat fill; a grain under a gradient
        // is neither material nor atmosphere, so a washed card stays flat.
        return Container(
          width: double.infinity,
          padding: padding,
          decoration: _painted(),
          child: child,
        );
      }
      // Material: the grain tiles inside the same rounded rectangle, the
      // border stays the one weight in the one colour, and the flat fill is
      // painted first so a tile that fails to load is today's card.
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: StrideColors.borderDefault),
          borderRadius: StrideRadius.card,
        ),
        child: SurfaceFill(
          tile: tile,
          fill: StrideColors.surfaceCard,
          radius: StrideRadius.card,
          child: Padding(padding: padding, child: child),
        ),
      );
    }
    // The frame owns the edge; the fill still owns the middle, so body text
    // never sits on frame art.
    //
    // **The frame's band replaces the padding rather than adding to it.**
    // `PixelFrame` already insets by `skin.inset`, and the band is a material
    // margin — it is the same breathing room the padding exists to provide, so
    // charging for both double-counts it. Stacking them cost 30 dp per side
    // against the unskinned 15, and that is not a taste question: at 320 dp
    // with the accessibility text scale at x1.4 it took "Woodcutting" below the
    // width it needs, which `ui_responsive_test.dart` catches and
    // `DECISIONS/0029` forbids outright — decorative art may never reduce
    // large-text support.
    //
    // So the caller's padding is reduced by what the frame already spent, and
    // floored at a small gap so type never begins hard against the frame's
    // inner line. A caller passing a deliberately large padding still gets the
    // extra room it asked for, measured from the same place as before.
    final EdgeInsets resolved = pad.resolve(TextDirection.ltr);
    final EdgeInsets interior = EdgeInsets.fromLTRB(
      math.max(_framedGap, resolved.left - skin.inset),
      math.max(_framedGap, resolved.top - skin.inset),
      math.max(_framedGap, resolved.right - skin.inset),
      math.max(_framedGap, resolved.bottom - skin.inset),
    );

    return SizedBox(
      width: double.infinity,
      child: PixelFrame(
        skin: skin,
        fallback: _painted(),
        surface: tile,
        child: DecoratedBox(
          decoration: BoxDecoration(color: StrideColors.surfaceCard),
          child: Padding(padding: interior, child: child),
        ),
      ),
    );
  }
}

/// A block nested inside a card. Fill only — no border.
class SurfaceBlock extends StatelessWidget {
  const SurfaceBlock({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding ?? const EdgeInsets.all(StrideSpace.blockPadding),
    decoration: const BoxDecoration(
      color: StrideColors.surfaceBlock,
      borderRadius: StrideRadius.inner,
    ),
    child: child,
  );
}

/// The recessed frame that holds pixel content.
///
/// **Takes a content size and adds the border itself**, so the rendered box is
/// `content + 2` on each axis. This is the Flutter form of the fix that cost
/// Round 03 three diagnoses: a 96 px sprite inside a 96 px `border-box` got 94 px
/// of content and was silently rescaled off its integer multiple.
///
/// A caller writing `InsetWell(size: 96)` around a 96 px sprite is the bug. The
/// API is shaped so that is unsayable — you pass what the sprite needs, and the
/// well is bigger than that by construction.
class InsetWell extends StatelessWidget {
  const InsetWell({
    super.key,
    required this.contentWidth,
    required this.contentHeight,
    required this.child,
  });

  /// A square well sized to a sprite's displayed edge.
  const InsetWell.square({
    super.key,
    required double contentSize,
    required this.child,
  }) : contentWidth = contentSize,
       contentHeight = contentSize;

  final double contentWidth;
  final double contentHeight;
  final Widget child;

  static const double _border = 1;

  @override
  Widget build(BuildContext context) => Container(
    width: contentWidth + _border * 2,
    height: contentHeight + _border * 2,
    decoration: BoxDecoration(
      color: StrideColors.surfaceGround,
      border: Border.all(color: StrideColors.borderDefault, width: _border),
      borderRadius: StrideRadius.inner,
    ),
    // No ClipRRect. Clipping is how a sprite loses its outermost pixel row
    // without anyone noticing; the sprite is sized to fit and the assert in
    // PixelAsset is what proves it does.
    child: Center(child: child),
  );
}

/// The micro-label / optional-trailing-value row that heads a section.
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      Expanded(
        child: Text(
          label.toUpperCase(),
          style: StrideType.microLabel,
          maxLines: 1,
          overflow: TextOverflow.clip,
        ),
      ),
      ?trailing,
    ],
  );
}

// =============================================================================
// EPO03 — THE KIT'S WIDGETS
//
// `panel_skin.dart` holds the three kit registries; these are what a screen
// team actually writes. Each one takes a kit name, asks the registry for art,
// and paints a declared fallback when there is none — so a screen built today
// against `KitFrame.slotWell` looks deliberate today and gains material the
// day the row lands, without moving.
//
// The fallbacks are not placeholders. They are the square-cornered, one-weight,
// one-colour construction the product already ships, which is why a screen is
// finished when it is built rather than when the art arrives.
// =============================================================================

/// A piece of kit furniture: a well, a plate, a ribbon, a tab.
///
/// Draws [KitFrames.of]'s nine-patch when the row has landed, and a square
/// recess or plate in the token ladder when it has not. Either way the content
/// is inset by [KitFrames.insetFor], which is the same figure in both cases.
class KitPlate extends StatelessWidget {
  const KitPlate({
    super.key,
    required this.frame,
    required this.child,
    this.fill = StrideColors.surfaceCard,
    this.surface = PanelSurface.none,
    this.padding,
    this.width,
    this.height,
    this.raised = false,
  });

  /// A well sized to the content it holds, the way [InsetWell] is.
  ///
  /// The caller passes what the content needs and the plate is bigger than
  /// that by its own frame — so `KitPlate.well(contentSize: 96)` around a
  /// 96 dp sprite is correct rather than the bug it would be if the well were
  /// sized to 96 itself. That arithmetic is the Flutter form of the fix that
  /// cost Round 03 three diagnoses, and it is why the API has no `size`.
  KitPlate.well({
    super.key,
    required this.frame,
    required this.child,
    required double contentWidth,
    required double contentHeight,
    this.fill = StrideColors.surfaceGround,
    this.surface = PanelSurface.none,
    this.raised = false,
  }) : padding = EdgeInsets.zero,
       width = contentWidth + (KitFrames.insetFor(frame) * 2),
       height = contentHeight + (KitFrames.insetFor(frame) * 2);

  final KitFrame frame;
  final Widget child;

  /// What the interior is painted. A well passes [StrideColors.surfaceGround]
  /// — the page showing through, which is what makes a well read as recessed.
  final Color fill;

  /// An optional grain inside the frame's band.
  final PanelSurface surface;

  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  /// Whether the fallback reads as standing off the page rather than sunk into
  /// it: a lit top edge instead of a shadowed one. Ignored once art lands —
  /// the raster carries its own light.
  final bool raised;

  /// The fallback: a square recess or plate, one weight, one colour.
  ///
  /// The lit or shadowed top edge is the whole signal. It is the same
  /// construction `StrideButton` uses for its own lit rim, so a kit plate and
  /// a button agree about where the light comes from (upper left, always).
  BoxDecoration _painted() => BoxDecoration(
    color: fill,
    border: Border(
      top: BorderSide(
        color: raised ? StrideColors.actionEdge : StrideColors.surfaceGround,
        width: 2,
      ),
      left: const BorderSide(color: StrideColors.borderDefault),
      right: const BorderSide(color: StrideColors.borderDefault),
      bottom: BorderSide(
        color: raised
            ? StrideColors.borderDefault
            : StrideColors.separator,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final PanelSkin? skin = KitFrames.of(frame);
    final SurfaceTile? tile = PanelSurfaces.of(surface);
    final double inset = KitFrames.insetFor(frame);
    final EdgeInsetsGeometry pad = padding ?? EdgeInsets.all(inset);

    if (skin == null) {
      // No art yet: spend the same inset, so the day the row lands the
      // material changes and the layout does not.
      final Widget body = Padding(padding: pad, child: child);
      return SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: _painted(),
          child: tile == null
              ? body
              : SurfaceFill(tile: tile, fill: fill, child: body),
        ),
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: PixelFrame(
        skin: skin,
        fallback: _painted(),
        surface: tile,
        child: DecoratedBox(
          decoration: BoxDecoration(color: fill),
          child: Padding(padding: pad, child: child),
        ),
      ),
    );
  }
}

/// A kit strip, run along its axis.
///
/// Horizontal strips fill their width and are [KitTiles.thicknessFor] tall;
/// vertical strips fill their height and are that wide. The room is reserved
/// whether or not the raster decodes.
class KitEdge extends StatelessWidget {
  const KitEdge({
    super.key,
    required this.tile,
    this.fallbackColor,
    this.fallbackAtEnd = false,
  });

  final KitTile tile;

  /// The line drawn in the strip's place while the raster is absent — the
  /// boundary the strip replaces. Null leaves the run blank, which only a
  /// caller drawing its own line wants.
  final Color? fallbackColor;

  /// Which edge of the reserved run the fallback line sits on.
  final bool fallbackAtEnd;

  @override
  Widget build(BuildContext context) {
    final KitStrip? strip = KitTiles.of(tile);
    final double thickness = KitTiles.thicknessFor(tile);
    final Axis axis = KitTiles.axisFor(tile);

    if (strip == null) {
      // Reserve the run and draw the line it replaces.
      final Widget line = fallbackColor == null
          ? const SizedBox.shrink()
          : Align(
              alignment: axis == Axis.horizontal
                  ? (fallbackAtEnd
                        ? Alignment.bottomCenter
                        : Alignment.topCenter)
                  : (fallbackAtEnd
                        ? Alignment.centerRight
                        : Alignment.centerLeft),
              child: SizedBox(
                width: axis == Axis.horizontal ? double.infinity : 1,
                height: axis == Axis.horizontal ? 1 : double.infinity,
                child: ColoredBox(color: fallbackColor!),
              ),
            );
      return SizedBox(
        width: axis == Axis.horizontal ? double.infinity : thickness,
        height: axis == Axis.horizontal ? thickness : double.infinity,
        child: line,
      );
    }
    return EdgeStrip(
      assetPath: strip.assetPath,
      nativeWidth: strip.nativeWidth,
      nativeHeight: strip.nativeHeight,
      scale: strip.scale,
      fallbackColor: fallbackColor,
      fallbackAtBottom: fallbackAtEnd,
    );
  }
}

/// A discrete kit ornament, drawn once at integer scale.
///
/// Reserves [KitMarks.sizeFor] whether or not the row has landed, so an
/// ornament arriving later does not reflow the row it sits in.
class KitOrnament extends StatelessWidget {
  const KitOrnament({super.key, required this.mark, this.fallback});

  final KitMark mark;

  /// Drawn in the reserved box while the row is empty. Null draws nothing,
  /// which is what an ornament that is pure decoration wants.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final KitOrnamentArt? art = KitMarks.of(mark);
    final Size size = KitMarks.sizeFor(mark);
    if (art == null) {
      return SizedBox.fromSize(size: size, child: fallback);
    }
    return PixelAsset(
      assetPath: art.assetPath,
      nativeWidth: art.nativeWidth,
      nativeHeight: art.nativeHeight,
      scale: art.scale,
    );
  }
}

/// Which page material a rule is drawn on.
enum KitRuleStyle { journal, bench, chart }

/// A ruled line across the page, with an optional title sitting on it.
///
/// One widget so that "a rule under a heading" cannot become nine different
/// hand-assembled constructions across eight screens — which is the mechanism
/// that produced the repeated-card rhythm this round exists to end. The caps
/// are ornaments when they land; the run is a tile; the fallback is the one
/// hairline the product already draws, at the same height, so nothing moves.
class KitRule extends StatelessWidget {
  const KitRule({super.key, this.style = KitRuleStyle.journal, this.title});

  final KitRuleStyle style;

  /// Drawn above the rule in the display face. Null draws the rule alone.
  final String? title;

  KitTile get _tile => switch (style) {
    KitRuleStyle.journal => KitTile.ruleJournal,
    KitRuleStyle.bench => KitTile.ruleBench,
    KitRuleStyle.chart => KitTile.ruleChart,
  };

  @override
  Widget build(BuildContext context) {
    final Widget rule = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const KitOrnament(mark: KitMark.ruleCapLeft),
        Expanded(
          child: KitEdge(
            tile: _tile,
            fallbackColor: StrideColors.separator,
          ),
        ),
        const KitOrnament(mark: KitMark.ruleCapRight),
      ],
    );
    if (title == null) return rule;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AdaptiveText(title!, style: StrideType.sectionHeading),
        const SizedBox(height: StrideSpace.rowGap),
        rule,
      ],
    );
  }
}

/// The page a screen is written on.
///
/// **This is the round's replacement for the card.** A tab root is one ground
/// of one material, full-bleed, with content sitting directly on it under
/// rules — not a column of dark rectangles. It has no border and no radius by
/// construction, so a screen built on it cannot reproduce the rhythm the
/// owner's device read named.
///
/// The flat fill is painted first, so a grain that fails to load is the ground
/// the screen always had.
class PageGround extends StatelessWidget {
  const PageGround({
    super.key,
    required this.child,
    this.surface = PanelSurface.journalLeaf,
    this.spine = false,
    this.fill = StrideColors.surfaceGround,
  });

  final Widget child;

  /// The page's material. One per screen — that is the whole point of the
  /// surface axis, and two materials on one page is two pages.
  final PanelSurface surface;

  /// Whether the page is bound: a spine down its left edge.
  final bool spine;

  final Color fill;

  @override
  Widget build(BuildContext context) {
    final SurfaceTile? tile = PanelSurfaces.of(surface);
    final Widget body = tile == null
        ? ColoredBox(color: fill, child: child)
        : SurfaceFill(tile: tile, fill: fill, child: child);
    if (!spine) return body;
    return Stack(
      children: <Widget>[
        Positioned.fill(child: body),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: KitEdge(
            tile: KitTile.edgeSpine,
            fallbackColor: StrideColors.borderDefault,
          ),
        ),
      ],
    );
  }
}
