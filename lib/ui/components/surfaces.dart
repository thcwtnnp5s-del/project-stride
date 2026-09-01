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
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? wash;
  final PanelRole role;

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

    if (skin == null) {
      // The unskinned path reserves the room a frame of this role will take,
      // so the day art lands the material changes and the layout does not.
      // Without this the reserve is a comment rather than a behaviour, and
      // every panel in the product reflows on the first asset — with the art
      // taking the blame for a text-wrap regression it did not cause.
      // `card` and `kitTray` reserve zero, so the overwhelming majority of
      // panels are byte-identical to what shipped.
      final double reserve = PanelSkins.insetFor(role);
      return Container(
        width: double.infinity,
        padding: reserve == 0
            ? pad
            : pad.add(EdgeInsets.all(reserve)).resolve(TextDirection.ltr),
        decoration: _painted(),
        child: child,
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
