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
import 'package:stride_core/stride_core.dart' show ItemCategory;

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
    final List<_Group> groups = _groups(entries);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        StrideSpace.screenGutter,
        // 10, not 12. The heading is a micro-label and needs less air above it
        // than a card does; the grid is the content and should start sooner.
        StrideSpace.s10,
        StrideSpace.screenGutter,
        StrideSpace.s16,
      ),
      children: <Widget>[
        if (c.session.isStale) ...<Widget>[
          StaleBanner(busy: c.busy, onReload: c.reload),
          const SizedBox(height: StrideSpace.cardGap),
        ],
        if (entries.isEmpty)
          const SectionCard(
            child: Text('You are carrying nothing.', style: StrideType.body),
          )
        else
          // One card, holding the whole of what the player owns.
          //
          // The grid used to sit directly on the page ground under a bare
          // heading, so an early-game inventory of five things was a small
          // cluster of tiles floating above 430 dp of black — which the owner
          // and Visual QA both read as unfinished rather than as sparse. A
          // frame gives the sparseness an edge: the emptiness is now clearly
          // *outside* the container, which is what "you own a few things" looks
          // like, instead of *inside* it, which is what a broken screen looks
          // like.
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeading(
                  label: 'Carried',
                  // The carried total, given the weight of a figure rather than
                  // of a footnote. It is the one aggregate on the screen and it
                  // was set in the same 11 px muted style as an inline caption.
                  trailing: Text(
                    total == 1 ? '1 item' : '$total items',
                    style: StrideType.micro.copyWith(
                      color: StrideColors.textPrimary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                for (final _Group group in groups) ...<Widget>[
                  const SizedBox(height: StrideSpace.s10),
                  // The group's name, only where there is more than one group.
                  // With a single kind of thing a divider label is noise.
                  if (groups.length > 1) ...<Widget>[
                    Text(
                      group.label.toUpperCase(),
                      style: StrideType.compactLabel,
                      maxLines: 1,
                    ),
                    const SizedBox(height: StrideSpace.s6),
                  ],
                  _ItemGrid(entries: group.entries),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// The player's items, grouped by the category the **content pack** already
  /// assigns them.
  ///
  /// `InventoryEntry.category` is `ItemCategory` straight off
  /// `ItemDefinition` — the same field `ContentLoader` uses to decide what a
  /// gather may yield. So this is reading existing data, not inventing a
  /// classification: no new system, no capacity, no encumbrance, no rarity, and
  /// nothing here that survives a content pack that stops setting it.
  ///
  /// Order is the enum's, which runs material → equipment → consumable → quest:
  /// what walking produces first, then what it is spent on. Entries whose
  /// category the pack does not supply are kept, in a trailing group, rather
  /// than dropped — an item the player owns must appear.
  static List<_Group> _groups(List<InventoryEntry> entries) {
    const Map<ItemCategory, String> names = <ItemCategory, String>{
      ItemCategory.material: 'Materials',
      ItemCategory.equipment: 'Equipment',
      ItemCategory.consumable: 'Consumables',
      ItemCategory.quest: 'Quest',
    };

    return <_Group>[
      for (final ItemCategory category in ItemCategory.values)
        if (entries.any((InventoryEntry e) => e.category == category))
          _Group(
            label: names[category]!,
            entries: entries
                .where((InventoryEntry e) => e.category == category)
                .toList(growable: false),
          ),
      if (entries.any((InventoryEntry e) => e.category == null))
        _Group(
          label: 'Other',
          entries: entries
              .where((InventoryEntry e) => e.category == null)
              .toList(growable: false),
        ),
    ];
  }
}

class _Group {
  const _Group({required this.label, required this.entries});

  final String label;
  final List<InventoryEntry> entries;
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
          //
          // **But `mainAxisExtent` is exact, not minimum**, and
          // `itemTileMinHeight` was documented as a floor and passed straight
          // in. A grid cell is therefore a fixed box around type that grows
          // with the text scaler: at 1.4 the second line of a wrapped name and
          // the count beneath it had nowhere to go, and clipped silently. That
          // is D-01's shape in the inventory.
          //
          // A grid needs one height for every cell, so the extent is computed
          // from the same terms the tile spends — icon, two name lines, the
          // count, and the tile's own padding — under the ambient scaler, and
          // floored at the designed value so nothing shrinks below the
          // approved proportion.
          mainAxisExtent: _tileExtent(MediaQuery.textScalerOf(context)),
        ),
        itemBuilder: (BuildContext context, int i) =>
            _ItemTile(entry: entries[i]),
      );
    },
  );

  /// The height one cell needs at [scaler], never below the designed floor.
  ///
  /// Two name lines, always — the tile reserves the wrap whether or not this
  /// particular name uses it, because a grid cannot give one cell a different
  /// height from its neighbours and reserving is the only way the tall case
  /// fits.
  static double _tileExtent(TextScaler scaler) {
    double lineOf(TextStyle style) =>
        scaler.scale(style.fontSize!) * (style.height ?? 1);

    const double iconEdge = 48; // PixelAsset.item at x1.
    const double padding = _tilePadTop + _tilePadBottom;
    const double gaps = StrideSpace.s6 * 2; // spaceBetween, at minimum.

    final double needed =
        padding +
        iconEdge +
        gaps +
        lineOf(StrideType.itemName) * 2 +
        lineOf(StrideType.itemCount);

    return needed > StrideGeometry.itemTileMinHeight
        ? needed
        : StrideGeometry.itemTileMinHeight;
  }
}

const double _tilePadTop = 12;
const double _tilePadBottom = 8;

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
    padding: const EdgeInsets.fromLTRB(3, _tilePadTop, 3, _tilePadBottom),
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
        // `×24` in the primary text colour, one step up from the name beside
        // it. Icon leads, count confirms, name disambiguates — the L-17 unit
        // with a hierarchy inside it instead of three flat runs.
        Text('×${entry.count}', style: StrideType.itemCount),
      ],
    ),
  );
}
