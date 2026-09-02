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
        // Fixed rather than minimum, and legitimately so: the labels below run
        // under `withNoTextScaling`, so nothing inside this bar can grow. That
        // clamp is what makes a fixed height safe here and nowhere else in the
        // app — see `StrideGeometry.tabBarHeight`.
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
          // Inactive labels at `textSecondary`, not `textMuted`: six 9.5 px
          // labels are the smallest type in the app and the owner's device
          // read the bar as "extremely plain" — muted grey on a dark bar is
          // most of why (ART-12 §8).
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

    // The active tab is a lifted plate: inset from the bar's edges, raised
    // fill, and a 2 dp lit rule along its top — the "you are here" mark. The
    // fill alone was what read as plain; the rule is what makes it a
    // bookmark rather than a highlight (ART-12 §8).
    final Widget body = isSelected
        ? Padding(
            padding: const EdgeInsets.fromLTRB(
              StrideSpace.s4,
              0,
              StrideSpace.s4,
              StrideSpace.s4,
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: StrideColors.surfaceRaised,
                borderRadius: StrideRadius.tabActive,
                border: Border(
                  top: BorderSide(color: StrideColors.actionEdge, width: 2),
                ),
              ),
              child: SizedBox.expand(child: content),
            ),
          )
        : SizedBox.expand(child: content);

    if (!destination.enabled) {
      // Not built yet, and honest about it. No snackbar, no dialog, no
      // navigation — a disabled control that explains itself by doing nothing
      // is less misleading than one that acknowledges a tap it will not honour.
      //
      // **0.28, down from 0.4.** Independent Visual QA, given the requirement in
      // advance, still read `Skills` and `Craft` as tappable across all four
      // screens and called it the highest-frequency defect in the set. The
      // reason 0.4 was not enough is that the *enabled* tabs are already
      // restrained — a muted 9.5 px label under a two-tone glyph — so 40% of
      // subdued is not obviously less than subdued. The margin has to be judged
      // against the live tabs, not against full strength.
      return IgnorePointer(child: Opacity(opacity: 0.28, child: body));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: body,
    );
  }
}
