/// Everything the player holds.
///
/// Icon + label + count is the complete semantic unit (`ART_DIRECTION.md`
/// **L-17**). The icon lets the eye sort the grid; the label removes the
/// remaining ambiguity.
///
/// ## Equipping
///
/// `EventReducer._started` adds the starting loadout to *inventory only* —
/// nothing is equipped on a new game — and gathering nodes require an
/// **equipped** tool, so without a control here Woodcutting and Mining were
/// unreachable on the phone. Each equipment tile therefore carries a compact
/// `Equip` / `Unequip` control and an `EQUIPPED` marker, and the Equipment
/// group opens with a one-line summary of the three slots. All of it is read
/// from the session's projections (`equippedIn`, `isEquipped`) and dispatched
/// through `SessionController` — the screen decides nothing about what may be
/// worn; the engine refuses, and the refusal is rendered (`RULES.md` E-2).
///
/// ## What is not here, and why
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
import 'package:stride_core/stride_core.dart'
    show ContentId, EquipmentSlot, ItemCategory, Rarity;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/gear_stats.dart';
import '../../components/pixel_asset.dart';
import '../../components/rarity_badge.dart';
import '../../components/rarity_item_title.dart';
import '../../components/surfaces.dart';
import '../../icons/pixel_icons.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/rarity_style.dart';
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
                  if (group.equipment) ...<Widget>[
                    const _EquippedSummary(),
                    if (c.lastEquip case final EquipReport report) ...<Widget>[
                      const SizedBox(height: StrideSpace.s6),
                      _EquipResult(report: report, removed: c.lastEquipRemoved),
                    ],
                    const SizedBox(height: StrideSpace.s8),
                  ],
                  if (group.consumable) ...<Widget>[
                    // Where food matters now: persistent HP, restored between
                    // encounters by eating (`DECISIONS/0023` §4).
                    Text(
                      'HP ${c.session.playerHp} / ${c.session.playerMaxHp}',
                      style: StrideType.sub.copyWith(
                        color: StrideColors.textSecondary,
                      ),
                    ),
                    if (c.lastFood case final FoodReport report) ...<Widget>[
                      const SizedBox(height: StrideSpace.s6),
                      _FoodResult(report: report),
                    ],
                    const SizedBox(height: StrideSpace.s6),
                  ],
                  _ItemGrid(
                    entries: group.entries,
                    equipment: group.equipment,
                    consumable: group.consumable,
                  ),
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
            equipment: category == ItemCategory.equipment,
            consumable: category == ItemCategory.consumable,
            entries: entries
                .where((InventoryEntry e) => e.category == category)
                .toList(growable: false),
          ),
      if (entries.any((InventoryEntry e) => e.category == null))
        _Group(
          label: 'Other',
          equipment: false,
          consumable: false,
          entries: entries
              .where((InventoryEntry e) => e.category == null)
              .toList(growable: false),
        ),
    ];
  }
}

class _Group {
  const _Group({
    required this.label,
    required this.equipment,
    required this.consumable,
    required this.entries,
  });

  final String label;

  /// Whether these tiles carry the equip control. Only the equipment group
  /// does — materials and consumables occupy no slot.
  final bool equipment;

  /// Whether these tiles carry the eat control (`DECISIONS/0023` §4).
  final bool consumable;
  final List<InventoryEntry> entries;
}

/// What the last out-of-combat meal did.
class _FoodResult extends StatelessWidget {
  const _FoodResult({required this.report});

  final FoodReport report;

  @override
  Widget build(BuildContext context) => SurfaceBlock(
    child: AdaptiveText(
      report.succeeded
          ? 'Ate ${report.itemName} — +${report.healed} HP '
                '(${report.hpAfter} now).'
          : _refusalText(report),
      style: StrideType.sub,
      color: report.succeeded
          ? StrideColors.textPrimary
          : StrideColors.textSecondary,
    ),
  );

  static String _refusalText(FoodReport report) => switch (report.rejection) {
    'health_full' => 'You are already at full health.',
    'encounter_in_progress' => 'Finish the fight first — eat from there.',
    'not_edible' => 'That is not something you can eat.',
    'item_not_owned' => 'You no longer have that.',
    'session_busy' => 'Something else is still running.',
    'session_not_ready' => 'The game is not ready. Reload and try again.',
    'commit_refused' => 'That did not save. Reload before trying again.',
    _ => 'That could not be eaten.',
  };
}

/// The three slots and what is in each — `—` when empty.
///
/// A summary, not a second control: the tiles below carry the buttons. It is
/// here so the player can see at a glance what they are wielding without
/// scanning the grid for markers.
class _EquippedSummary extends StatelessWidget {
  const _EquippedSummary();

  static const List<(EquipmentSlot, String)> _slots = <(EquipmentSlot, String)>[
    (EquipmentSlot.weapon, 'Weapon'),
    (EquipmentSlot.armor, 'Armour'),
    (EquipmentSlot.tool, 'Tool'),
  ];

  @override
  Widget build(BuildContext context) {
    final StrideSession session = SessionScope.of(context).session;
    // Slot → what is in it, with its rarity, from the projection the engine's
    // own `Equipment.bySlot` backs. Read once rather than per column.
    final Map<EquipmentSlot, EquippedSummary> worn =
        <EquipmentSlot, EquippedSummary>{
          for (final EquippedSummary e in session.equippedSummary) e.slot: e,
        };
    return SurfaceBlock(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final (EquipmentSlot slot, String label) in _slots)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label.toUpperCase(),
                    style: StrideType.compactLabel,
                    maxLines: 1,
                  ),
                  const SizedBox(height: StrideSpace.s2),
                  RarityName(
                    name: worn[slot]?.displayName ?? '—',
                    rarity: worn[slot]?.rarity,
                    style: StrideType.sub,
                    fallback: worn.containsKey(slot)
                        ? StrideColors.textPrimary
                        : StrideColors.textMuted,
                  ),
                  // The rarity word under the name, compact: each of these
                  // three columns is a third of the block, which at 320 dp is
                  // about 76 dp — narrower than the plated badge, and the
                  // reason the compact form exists.
                  if (worn[slot]?.rarity case final Rarity r) ...<Widget>[
                    const SizedBox(height: StrideSpace.s2),
                    RarityBadge.compact(rarity: r),
                  ],
                  // The figure combat reads, or what the tool opens — the
                  // same line the tile carries, so the summary and the grid
                  // never disagree about a piece.
                  if (worn[slot] case final EquippedSummary e)
                    if (session.gearStatsOf(e.itemId) case final GearStats g) ...<Widget>[
                      const SizedBox(height: StrideSpace.s2),
                      Text(
                        GearStatLine.textOf(g),
                        style: StrideType.compactLabel.copyWith(
                          color: StrideColors.textSecondary,
                        ),
                        maxLines: 1,
                      ),
                    ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EquipResult extends StatelessWidget {
  const _EquipResult({required this.report, required this.removed});

  final EquipReport report;
  final bool removed;

  @override
  Widget build(BuildContext context) => SurfaceBlock(
    child: AdaptiveText(
      report.succeeded
          ? removed
                ? 'Set ${report.itemName} aside.'
                : 'Equipped ${report.itemName}.'
          : _refusalText(report),
      style: StrideType.sub,
      color: report.succeeded
          ? StrideColors.textPrimary
          : StrideColors.textSecondary,
    ),
  );

  /// Refusals are keyed on the stable wire code, never on the explanation
  /// string — the code is the contract and the sentence is free to change.
  static String _refusalText(EquipReport report) => switch (report.rejection) {
    'item_not_owned' => 'You no longer have that.',
    'invalid_equipment_slot' => 'That cannot be worn or wielded.',
    'unknown_item' => 'That item is not in this content pack.',
    'slot_empty' => 'Nothing is equipped there.',
    'session_busy' => 'Something else is still running.',
    'session_not_ready' => 'The game is not ready. Reload and try again.',
    'commit_refused' => 'That did not save. Reload before trying again.',
    _ => 'That could not be equipped.',
  };
}

class _ItemGrid extends StatelessWidget {
  const _ItemGrid({
    required this.entries,
    required this.equipment,
    this.consumable = false,
  });

  final List<InventoryEntry> entries;
  final bool equipment;
  final bool consumable;

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
          mainAxisExtent: _tileExtent(
            MediaQuery.textScalerOf(context),
            withControl: equipment || consumable,
          ),
        ),
        itemBuilder: (BuildContext context, int i) => _ItemTile(
          entry: entries[i],
          equipment: equipment,
          consumable: consumable,
        ),
      );
    },
  );

  /// The height one cell needs at [scaler], never below the designed floor.
  ///
  /// Two name lines, always — the tile reserves the wrap whether or not this
  /// particular name uses it, because a grid cannot give one cell a different
  /// height from its neighbours and reserving is the only way the tall case
  /// fits.
  ///
  /// An [equipment] cell additionally spends the `EQUIPPED` marker line and
  /// the control beneath it — reserved for every cell in the group, equipped
  /// or not, for the same reason.
  ///
  /// Since the rarity pass the cell also spends [RarityRule.thickness] and one
  /// more gap, reserved for every cell whether or not the content pack gave
  /// that item a definition — an unreserved rule is the same defect the two
  /// name lines exist to avoid, since a grid has one height for all its cells.
  /// It does not scale: a 2 dp mark is a mark, not type.
  static double _tileExtent(TextScaler scaler, {required bool withControl}) {
    double lineOf(TextStyle style) =>
        scaler.scale(style.fontSize!) * (style.height ?? 1);

    const double iconEdge = 48; // PixelAsset.item at x1.
    const double padding = _tilePadTop + _tilePadBottom;
    const double gaps = StrideSpace.s6 * 3; // spaceBetween, at minimum.

    final double needed =
        padding +
        RarityRule.thickness +
        iconEdge +
        gaps +
        lineOf(StrideType.itemName) * 2 +
        lineOf(StrideType.itemCount);

    final double base = needed > StrideGeometry.itemTileMinHeight
        ? needed
        : StrideGeometry.itemTileMinHeight;

    if (!withControl) return base;

    // The marker line, the control at its minimum, and the gaps around them.
    // The control's own label grows with the scaler inside its minimum, so
    // only the line above it is scaled here.
    final double control =
        StrideSpace.s6 +
        lineOf(StrideType.compactLabel) +
        StrideSpace.s6 +
        StrideGeometry.buttonHeightSecondary;
    return base + control;
  }
}

const double _tilePadTop = 12;
const double _tilePadBottom = 8;

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.entry,
    required this.equipment,
    this.consumable = false,
  });

  final InventoryEntry entry;

  /// Whether this tile carries the equip control and marker.
  final bool equipment;

  /// Whether this tile carries the eat control (`DECISIONS/0023` §4).
  final bool consumable;

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
        // The rank's mark, and not its word, for a measured reason
        // ([RarityRule]): `UNCOMMON` needs 72.3 dp at text scale 1.4 in a
        // 393 dp four-column cell that has 68.8. The word is carried by every
        // surface that gives an item a full row — the equipped summary
        // directly above this grid, the victory panel, the craft card.
        RarityRule(rarity: entry.rarity),
        PixelAsset.item(PixelIcons.itemFor(entry.id)),
        Text(
          entry.displayName,
          style: StrideType.itemName.copyWith(
            // The rarity recolours the name and changes nothing else about it
            // — same size, same weight, same two-line clamp. A rank is not a
            // promotion (`rarity_item_title.dart`).
            color: RarityStyle.inkOr(entry.rarity, StrideColors.textSecondary),
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.clip,
        ),
        // `×24` in the primary text colour, one step up from the name beside
        // it. Icon leads, count confirms, name disambiguates — the L-17 unit
        // with a hierarchy inside it instead of three flat runs.
        Text('×${entry.count}', style: StrideType.itemCount),
        if (equipment) _EquipControl(item: entry.id),
        if (consumable) _EatControl(item: entry.id),
      ],
    ),
  );
}

/// The `Eat` control on a consumable tile — the out-of-combat heal
/// (`DECISIONS/0023` §4). The reserved line above the button carries nothing
/// (consumables have no EQUIPPED state); it keeps every controlled tile's
/// button at one height, exactly as the equip group reserves it.
class _EatControl extends StatelessWidget {
  const _EatControl({required this.item});

  final ContentId item;

  @override
  Widget build(BuildContext context) {
    final SessionController controller = SessionScope.read(context);
    final SessionController watched = SessionScope.of(context);
    final StrideSession session = watched.session;
    // A hint, not the rule: `EatFood` re-validates fullness, ownership and
    // the no-mid-combat rule on execute (`RULES.md` E-2).
    final bool enabled =
        !watched.busy &&
        session.isReady &&
        session.encounter == null &&
        session.playerHp < session.playerMaxHp;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('', style: StrideType.compactLabel, maxLines: 1),
        const SizedBox(height: StrideSpace.s6),
        Center(
          child: StrideButton.secondary(
            label: 'Eat',
            onPressed: enabled ? () => controller.eatFood(item) : null,
          ),
        ),
      ],
    );
  }
}

/// The `EQUIPPED` marker and the `Equip` / `Unequip` control on one tile.
///
/// The marker line is reserved even when empty so every tile in the group
/// puts its control at the same height; the grid gives them all one extent.
class _EquipControl extends StatelessWidget {
  const _EquipControl({required this.item});

  final ContentId item;

  @override
  Widget build(BuildContext context) {
    final SessionController controller = SessionScope.read(context);
    final SessionController watched = SessionScope.of(context);
    final StrideSession session = watched.session;
    final bool equipped = session.isEquipped(item);
    final bool enabled = !watched.busy && session.isReady;

    // Unequip is by slot, and the slot is whichever one holds this item —
    // read from the same projection that marked it EQUIPPED.
    EquipmentSlot? slotOf() {
      for (final EquipmentSlot slot in EquipmentSlot.values) {
        if (session.equippedIn(slot) == item) return slot;
      }
      return null;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The marker line carries the stat now (PLAYABLE_POLISH_01 §6):
        // `ATK 7 · +2` against the worn weapon, `DEF 3 · WORN` for what is
        // on the Traveler's back. The EQUIPPED marker is folded into it as
        // the word WORN, so the line the tile reserved answers two questions
        // instead of one and the grid's extent is unchanged.
        if (session.gearStatsOf(item) case final GearStats g)
          GearStatLine(stats: g)
        else
          Text(
            equipped ? 'EQUIPPED' : '',
            style: StrideType.compactLabel.copyWith(
              color: StrideColors.textPrimary,
            ),
            maxLines: 1,
          ),
        const SizedBox(height: StrideSpace.s6),
        // Centred in the tile: the secondary control shrink-wraps to the left
        // of whatever it is given, and a left-hugging button in a centred
        // column of icon, name and count would read as misaligned.
        Center(
          child: StrideButton.secondary(
            label: equipped ? 'Unequip' : 'Equip',
            onPressed: !enabled
                ? null
                : equipped
                ? () {
                    final EquipmentSlot? slot = slotOf();
                    if (slot != null) controller.unequip(slot);
                  }
                : () => controller.equip(item),
          ),
        ),
      ],
    );
  }
}
