/// The six-destination bottom navigation.
library;

import 'package:flutter/widgets.dart';

import '../shell/stride_destination.dart';
import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'pixel_asset.dart';

class StrideTabBar extends StatelessWidget {
  const StrideTabBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final StrideDestination selected;
  final ValueChanged<StrideDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: StrideColors.surfaceCard,
        border: Border(top: BorderSide(color: StrideColors.borderDefault)),
      ),
      child: SizedBox(
        height: StrideGeometry.tabBarHeight,
        child: MediaQuery.withNoTextScaling(
          // Scoped to the tab-bar labels ONLY, and this is a real accessibility
          // cost taken deliberately rather than defaulted into.
          //
          // Six fixed-width destinations at 9.5 px leave `Adventure` roughly 4 dp
          // of margin at 320 dp. Under any enlarged text scale the six labels
          // either wrap to three lines or overflow, and there is no arrangement of
          // six equal columns that avoids it.
          //
          // The clamp is correct *here* specifically because the tab bar is chrome
          // the player already knows by glyph and position. Every content
          // surface — every figure, name, and sentence the player actually has to
          // read — keeps free scaling.
          child: Row(
            children: <Widget>[
              for (final StrideDestination d in StrideDestination.values)
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
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        PixelAsset.nav(
          isSelected ? destination.glyphActive : destination.glyph,
        ),
        const SizedBox(height: StrideSpace.iconLabelGap),
        Text(
          destination.label,
          style: isSelected ? StrideType.tabLabelActive : StrideType.tabLabel,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
      ],
    );

    final Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected ? StrideColors.surfaceBlock : const Color(0x00000000),
        borderRadius: isSelected ? StrideRadius.tabActive : null,
      ),
      child: SizedBox.expand(child: content),
    );

    if (!destination.enabled) {
      // Not built yet, and honest about it. No snackbar, no dialog, no
      // navigation — a disabled control that explains itself by doing nothing
      // is less misleading than one that acknowledges a tap it will not honour.
      return IgnorePointer(child: Opacity(opacity: 0.4, child: body));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: body,
    );
  }
}
