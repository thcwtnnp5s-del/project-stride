/// The container primitives: card, nested block, and inset well.
///
/// The surface ladder is four levels and the border ladder is exactly one
/// weight in exactly one colour. A nested block is declared by its fill alone; a
/// well is declared by fill *and* outline. That is the whole system, and it
/// should not be extended without a reason.
library;

import 'package:flutter/widgets.dart';

import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';

/// The universal content container.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(StrideSpace.cardPadding),
    decoration: BoxDecoration(
      color: StrideColors.surfaceCard,
      border: Border.all(color: StrideColors.borderDefault),
      borderRadius: StrideRadius.card,
    ),
    child: child,
  );
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
