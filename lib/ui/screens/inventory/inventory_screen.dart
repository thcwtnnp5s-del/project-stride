/// Everything the player holds.
///
/// Icon + label + count is the complete semantic unit (`ART_DIRECTION.md`
/// **L-17**). The icon lets the eye sort the grid; the label removes the
/// remaining ambiguity.
///
/// ## What is not here, and why
///
/// **No `EQUIPPED` card.** `EventReducer._started` adds the starting loadout to
/// *inventory only* — nothing is equipped on a new game — and Phase 1 has no
/// equip affordance. The card would be three permanently empty slots.
///
/// **No category filter pills.** Phase 1's item set is five kinds, and the pills
/// would additionally assert quest and consumable systems that have no items.
///
/// **No capacity affordance of any kind** — no slot denominator, no dashed empty
/// cells, no bar, no warning colour, no encumbrance. No capacity system exists
/// (Q-UI-1), and `116 items` is a plain fact about what the player owns that
/// implies no limit. That framing belongs to a game with upkeep, and Stride has
/// none (`RULES.md` P-5).
library;

import 'package:flutter/widgets.dart';

import '../../../runtime/stride_session.dart';
import '../../components/pixel_asset.dart';
import '../../components/surfaces.dart';
import '../../icons/pixel_icons.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import '../system/stale_banner.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController c = SessionScope.of(context);
    final List<InventoryEntry> entries = c.session.inventoryEntries;
    final int total = entries.fold(0, (int a, InventoryEntry e) => a + e.count);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        StrideSpace.screenGutter,
        StrideSpace.s12,
        StrideSpace.screenGutter,
        StrideSpace.s16,
      ),
      children: <Widget>[
        if (c.session.isStale) ...<Widget>[
          StaleBanner(busy: c.busy, onReload: c.reload),
          const SizedBox(height: StrideSpace.cardGap),
        ],
        SectionHeading(
          label: 'Carried',
          trailing: Text(
            total == 1 ? '1 item' : '$total items',
            style: StrideType.micro,
          ),
        ),
        const SizedBox(height: StrideSpace.s10),
        if (entries.isEmpty)
          const SectionCard(
            child: Text('You are carrying nothing.', style: StrideType.body),
          )
        else
          _ItemGrid(entries: entries),
      ],
    );
  }
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({required this.entries});

  final List<InventoryEntry> entries;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      // Fluid columns, not the prototype's fixed 84 px. Four fixed columns plus
      // gaps and gutters total 392, which is tuned to a 393 dp reference and to
      // nothing else — on a 360 dp Android phone it overflows.
      const int wanted = 4;
      final double raw =
          (constraints.maxWidth - StrideSpace.gridGap * (wanted - 1)) / wanted;

      // Floored to an even number so a 40 px icon centred in the tile lands on a
      // whole logical pixel rather than a fractional x, which would antialias a
      // sprite that is meant to be crisp. Costs at most 2 dp of grid width.
      final double column = (raw / 2).floorToDouble() * 2;

      final int columns = column >= StrideGeometry.gridColumnFloor ? wanted : 3;

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),

        // Both of these are load-bearing, and neither is obvious.
        //
        // `ScrollView` resolves its padding as
        // `padding ?? (primary ? MediaQuery.paddingOf(context) : zero)`, and
        // `primary` defaults to true for a vertical view with no controller.
        // So a nested grid with no explicit padding silently adopts the
        // **device's safe-area padding** — which put roughly 57 dp of empty
        // space between the CARRIED heading and the first row on a phone with a
        // status bar, and nothing at all under `flutter test`, whose harness
        // supplies zero insets. The gap was invisible to every test and to the
        // goldens, and obvious in the first device screenshot.
        //
        // `StrideScaffold` is the one place insets are handled (see its own
        // doc); this grid re-applying the top inset is the same double-inset
        // defect the SafeArea rule exists to prevent, arriving through a
        // default rather than through a widget.
        primary: false,
        padding: EdgeInsets.zero,

        itemCount: entries.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: StrideSpace.gridGap,
          mainAxisSpacing: StrideSpace.gridGap,
          // mainAxisExtent, not childAspectRatio: an aspect ratio forces a
          // height derived from the width, and a wrapped two-line item name
          // then clips instead of growing the row.
          mainAxisExtent: StrideGeometry.itemTileMinHeight,
        ),
        itemBuilder: (BuildContext context, int i) =>
            _ItemTile(entry: entries[i]),
      );
    },
  );
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.entry});

  final InventoryEntry entry;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: StrideColors.surfaceCard,
      border: Border.all(color: StrideColors.borderDefault),
      borderRadius: StrideRadius.inner,
    ),
    padding: const EdgeInsets.fromLTRB(3, 12, 3, 7),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        PixelAsset.item(PixelIcons.itemFor(entry.id)),
        Text(
          entry.displayName,
          style: StrideType.itemName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.clip,
        ),
        Text('×${entry.count}', style: StrideType.itemCount),
      ],
    ),
  );
}
