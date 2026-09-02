/// An equipment case, and then a pack.
///
/// Icon + label + count is the complete semantic unit (`ART_DIRECTION.md`
/// **L-17**). The icon lets the eye sort the grid; the label removes the
/// remaining ambiguity.
///
/// ## The case (FMPO02, `ART-12_ux_brief.md` §2)
///
/// The screen opens on what the player is *wearing*: the standing Traveler at
/// ×2 beside three slot plates. It replaces a summary block that sat buried in
/// the middle of the Equipment group, where the one thing a player checks a bag
/// for was below the fold behind two rows of materials.
///
/// The case is a **readout**. Equip and Unequip stay on the pack tile, which is
/// the only surface with room for the engine's refusal sentence; tapping a
/// plate scrolls to that item's tile and selects it, so the case points at the
/// control rather than becoming a second one.
///
/// ## Two grids, and why the materials one drops its labels
///
/// Materials run five across at 66 dp, where a two-line name does not fit, so
/// the name becomes the tile's Semantics label and the detail block under the
/// grid. That is a trade with a stated limit: the moment the ambient text
/// scaler grows past the point a 66 dp tile can carry, the grid drops to four
/// or three columns and the names come back. Gear runs three across at 114,
/// which is what the Equip control needs.
///
/// ## Equipping
///
/// `EventReducer._started` adds the starting loadout to *inventory only* —
/// nothing is equipped on a new game — and gathering nodes require an
/// **equipped** tool, so without a control here Woodcutting and Mining were
/// unreachable on the phone. Each equipment tile therefore carries a compact
/// `Equip` / `Unequip` control and an `EQUIPPED` marker, and the case above the
/// pack reads the three slots back. All of it is read
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
    show ContentId, EquipmentSlot, ItemCategory;

import '../../../runtime/stride_session.dart';
import '../../components/adaptive_text.dart';
import '../../components/data_display.dart';
import '../../components/gear_stats.dart';
import '../../components/loadout_readout.dart';
import '../../components/pixel_asset.dart';
import '../../components/rarity_item_title.dart';
import '../../components/panel_skin.dart';
import '../../components/surfaces.dart';
import '../../icons/pixel_icons.dart';
import '../../icons/traveler_art.dart';
import '../../../audio/audio_events.dart';
import '../../state/audio_scope.dart';
import '../../state/session_controller.dart';
import '../../state/session_scope.dart';
import '../../theme/rarity_style.dart';
import '../../theme/stride_colors.dart';
import '../../theme/stride_metrics.dart';
import '../../theme/stride_typography.dart';
import '../system/stale_banner.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  /// The equipment tile whose full evaluation is open beneath the grid —
  /// ephemeral UI selection, never a game figure (`RULES.md` E-2). Added by
  /// the physical-device polish pass (item 5): the tile's one line says
  /// `TIER 1`; what that tier *opens* needs the room of a block.
  ContentId? _gearDetail;

  /// The material / consumable / quest tile whose purpose block is open —
  /// the same pattern for the other three groups (Fable V2,
  /// `DECISIONS/0027`): a Boar Tusk and a Bronze Ingot used to be
  /// indistinguishable in purpose from the grid.
  ContentId? _itemDetail;

  /// The open detail block, whichever kind, so a selection can scroll it
  /// into view: with two grid rows of equipment the block used to land
  /// ~300 dp below the tapped tile — often below the fold, where a tap
  /// looked like it did nothing (Fable V2 UX audit S5).
  final GlobalKey _detailKey = GlobalKey();

  /// One key per item tile, so the equipment case can scroll the pack to the
  /// piece a slot plate names. Created on demand and kept: an item leaves the
  /// bag rarely, and a stale key with no context is inert.
  final Map<String, GlobalKey> _tileKeys = <String, GlobalKey>{};

  GlobalKey _tileKey(ContentId id) =>
      _tileKeys.putIfAbsent(id.value, GlobalKey.new);

  void _reveal() => _scrollTo(() => _detailKey.currentContext, 0.2);

  void _scrollTo(ValueGetter<BuildContext?> target, double alignment) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? at = target();
      if (at == null || !mounted) return;
      Scrollable.ensureVisible(
        at,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: alignment,
      );
    });
  }

  /// A slot plate names a piece; this is what tapping it does. The plate is a
  /// readout, so the tap moves the player to the control rather than acting.
  void _openFromSlot(ContentId id) {
    setState(() {
      _itemDetail = null;
      _gearDetail = id;
    });
    _scrollTo(() => _tileKeys[id.value]?.currentContext, 0.3);
  }

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
          const SizedBox(height: StrideSpace.rhythmRow),
        ],
        // The case, whether or not the pack has anything in it: the loadout is
        // a fact about the player, not about the bag, and a new game whose
        // three slots are empty is exactly the state the case exists to show.
        _EquipmentCase(onSelect: _openFromSlot),
        const SizedBox(height: StrideSpace.rhythmHero),
        if (entries.isEmpty)
          const SectionCard(
            role: PanelRole.kitTray,
            surface: PanelSurface.oilcloth,
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
            role: PanelRole.kitTray,
            surface: PanelSurface.oilcloth,
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
                  // 16 between named groups, 8 between peers inside one — the
                  // three rhythms of ART-12 §0, never one value twice.
                  const SizedBox(height: StrideSpace.rhythmGroup),
                  // The group's name, only where there is more than one group.
                  // With a single kind of thing a divider label is noise.
                  if (groups.length > 1) ...<Widget>[
                    SectionHeading(label: group.label),
                    const SizedBox(height: StrideSpace.rhythmRow),
                  ],
                  if (group.equipment)
                    if (c.lastEquip case final EquipReport report) ...<Widget>[
                      _EquipResult(report: report, removed: c.lastEquipRemoved),
                      const SizedBox(height: StrideSpace.rhythmRow),
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
                      const SizedBox(height: StrideSpace.rhythmRow),
                      _FoodResult(report: report),
                    ],
                    const SizedBox(height: StrideSpace.rhythmRow),
                  ],
                  _ItemGrid(
                    entries: group.entries,
                    equipment: group.equipment,
                    consumable: group.consumable,
                    material: group.material,
                    keyOf: _tileKey,
                    selected: group.equipment ? _gearDetail : _itemDetail,
                    // One detail open at a time, whichever kind: two blocks
                    // at once would be two answers to one tap, and the one
                    // reveal key must be unique in the tree.
                    onSelect: group.equipment
                        ? (ContentId id) {
                            setState(() {
                              _itemDetail = null;
                              _gearDetail = _gearDetail == id ? null : id;
                            });
                            if (_gearDetail != null) _reveal();
                          }
                        : (ContentId id) {
                            setState(() {
                              _gearDetail = null;
                              _itemDetail = _itemDetail == id ? null : id;
                            });
                            if (_itemDetail != null) _reveal();
                          },
                  ),
                  // The opened piece's full evaluation — the same
                  // `GearStatsBlock` the craft bench shows, under the grid
                  // it was opened from, so the bag can answer "why does a
                  // better tool matter" without a trip to the bench (this
                  // pass, item 5).
                  if (group.equipment && _gearDetail != null)
                    if (c.session.gearStatsOf(_gearDetail!)
                        case final GearStats g) ...<Widget>[
                      const SizedBox(height: StrideSpace.rhythmRow),
                      KeyedSubtree(
                        key: _detailKey,
                        child: GearStatsBlock(stats: g),
                      ),
                    ],
                  // The opened item's purpose — what it is for, where it
                  // comes from, what it makes possible (Fable V2). Only in
                  // the group that owns the selected tile, so the block
                  // opens beside its trigger.
                  //
                  // **The name renders whether or not a purpose exists.** In a
                  // five-across materials grid the tile has no room for a
                  // label, so this block is where the name is said; gating it
                  // on the purpose would leave a tapped tile with nothing to
                  // show and no way to learn what it is.
                  if (!group.equipment && _itemDetail != null)
                    if (group.entries.any(
                      (InventoryEntry e) => e.id == _itemDetail,
                    )) ...<Widget>[
                      const SizedBox(height: StrideSpace.rhythmRow),
                      KeyedSubtree(
                        key: _detailKey,
                        child: _ItemPurposeBlock(
                          name: c.session.displayNameOf(_itemDetail!),
                          purpose: c.session.itemPurposeOf(_itemDetail!),
                        ),
                      ),
                    ],
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
            material: category == ItemCategory.material,
            entries: entries
                .where((InventoryEntry e) => e.category == category)
                .toList(growable: false),
          ),
      if (entries.any((InventoryEntry e) => e.category == null))
        _Group(
          label: 'Other',
          equipment: false,
          consumable: false,
          material: false,
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
    required this.material,
    required this.entries,
  });

  final String label;

  /// Whether these tiles carry the equip control. Only the equipment group
  /// does — materials and consumables occupy no slot.
  final bool equipment;

  /// Whether these tiles carry the eat control (`DECISIONS/0023` §4).
  final bool consumable;

  /// Whether this group takes the dense five-across grid (ART-12 §2). Only
  /// materials do: they are the group a player holds forty of, and the only
  /// one whose tile has nothing to carry but a picture and a count.
  final bool material;

  final List<InventoryEntry> entries;
}

/// What one item is *for* — sources above uses, uses above trivia — under
/// the grid the tile was tapped in (Fable V2, `DECISIONS/0027`).
///
/// Progressive disclosure by construction: nothing renders until a tile is
/// tapped, and each line renders only when the content pack has something
/// to say. A trophy says it is one, so dead-by-design stops reading as a
/// recipe the player has not found.
class _ItemPurposeBlock extends StatelessWidget {
  const _ItemPurposeBlock({required this.name, required this.purpose});

  final String name;

  /// Null when the content pack says nothing about this item. The block still
  /// renders: in the five-across materials grid it is the only place the name
  /// appears (ART-12 §2).
  final ItemPurposeView? purpose;

  @override
  Widget build(BuildContext context) {
    final ItemPurposeView? purpose = this.purpose;
    if (purpose == null) {
      return SurfaceBlock(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AdaptiveText(name, style: StrideType.itemName),
            const SizedBox(height: StrideSpace.s4),
            Text(
              'Nothing in the world asks for this yet.',
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            ),
          ],
        ),
      );
    }
    final List<(String, String)> lines = <(String, String)>[
      if (purpose.healing > 0) ('EATS AS', '+${purpose.healing} HP'),
      // The derived lineage (`DECISIONS/0028` §6): a piece's future stated
      // before its uses, because "this becomes something better" is the
      // stronger fact. The consuming recipe is already deduplicated out of
      // USED IN by the projection.
      if (purpose.upgradesInto.isNotEmpty)
        (
          'UPGRADES INTO',
          purpose.upgradesInto
              .map((LineageEdge e) => '${e.toName} — ${e.recipeName}')
              .join('\n'),
        ),
      if (purpose.usedInRecipes.isNotEmpty)
        ('USED IN', purpose.usedInRecipes.join(', ')),
      if (purpose.wantedBy.isNotEmpty)
        ('WANTED BY', purpose.wantedBy.join('\n')),
      if (purpose.craftedBy.isNotEmpty)
        ('CRAFTED BY', purpose.craftedBy.join(', ')),
      if (purpose.gatheredAt.isNotEmpty)
        ('GATHERED AT', purpose.gatheredAt.join('\n')),
      if (purpose.droppedBy.isNotEmpty)
        ('DROPPED BY', purpose.droppedBy.join('\n')),
    ];

    return SurfaceBlock(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AdaptiveText(name, style: StrideType.itemName),
          if (purpose.isTrophy) ...<Widget>[
            const SizedBox(height: StrideSpace.s4),
            Text(
              'A keepsake — proof of a rare find.',
              style: StrideType.micro.copyWith(
                color: StrideColors.textSecondary,
              ),
            ),
          ],
          for (final (String label, String value) in lines) ...<Widget>[
            const SizedBox(height: StrideSpace.s6),
            Text(label, style: StrideType.microLabel, maxLines: 1),
            const SizedBox(height: StrideSpace.s2),
            Text(
              value,
              style: StrideType.micro.copyWith(
                color: StrideColors.textSecondary,
              ),
            ),
          ],
          if (!purpose.isTrophy && lines.isEmpty) ...<Widget>[
            const SizedBox(height: StrideSpace.s4),
            Text(
              'Nothing in the world asks for this yet.',
              style: StrideType.micro.copyWith(color: StrideColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
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

/// The equipment case: the Traveler as they stand, and the three slots as
/// plates beside them (ART-12 §2).
///
/// ## What replaced what
///
/// This was a summary block sitting *inside* the Equipment group, three
/// text columns wide, under a 64 dp figure at ×1. Two things were wrong with
/// it: the loadout — the first thing a player opens a bag to check — was
/// below two rows of materials, and the figure was drawn small enough that
/// the armour classes it exists to distinguish were not separable.
///
/// So it is the screen's hero now: the figure at ×2 in a well, and the slots
/// as plates rather than as columns of running text. Still a readout — the
/// grid keeps the buttons ([SlotPlate] says why) — and still every fact from
/// the same projections the engine reads.
class _EquipmentCase extends StatelessWidget {
  const _EquipmentCase({required this.onSelect});

  /// What a plate's tap does: select this item's tile in the pack below and
  /// scroll it into view.
  final ValueChanged<ContentId> onSelect;

  static const List<(EquipmentSlot, String)> _slots = <(EquipmentSlot, String)>[
    (EquipmentSlot.weapon, 'Weapon'),
    (EquipmentSlot.armor, 'Armour'),
    (EquipmentSlot.tool, 'Tool'),
  ];

  /// The narrowest a plate may be and still hold its own type beside the
  /// figure: plate padding 8 + icon well 50 + gap 8, and 60 dp of type — which
  /// is `ARMOUR` at 37.3 with room for the enlarged case rather than exactly
  /// none. Below this the case stacks.
  static const double _plateFloor = 126;

  @override
  Widget build(BuildContext context) {
    final StrideSession session = SessionScope.of(context).session;
    // Slot → what is in it, with its rarity, from the projection the engine's
    // own `Equipment.bySlot` backs. Read once rather than per plate.
    final Map<EquipmentSlot, EquippedSummary> worn =
        <EquipmentSlot, EquippedSummary>{
          for (final EquippedSummary e in session.equippedSummary) e.slot: e,
        };
    final Set<String> held = <String>{
      for (final InventoryEntry e in session.inventoryEntries) e.id.value,
    };

    // **What the player is wearing, as a figure** (VAWO01, Q-14), now at ×2 —
    // 64 native doubled, never a fractional fit to the well. Resolved through
    // `TravelerArt` from the session's existing projection; an unmapped item
    // falls back to the base Traveler.
    //
    // Decorative: the plates state every fact it shows.
    final Widget figure = ExcludeSemantics(
      child: InsetWell.square(
        contentSize: StrideGeometry.portraitContent,
        child: PixelAsset(
          assetPath: TravelerArt.figureFor(session.equipmentVisualState),
          nativeWidth: 64,
          nativeHeight: 64,
          scale: 2,
        ),
      ),
    );

    final List<Widget> plates = <Widget>[
      for (final (EquipmentSlot slot, String label) in _slots) ...<Widget>[
        if (slot != _slots.first.$1)
          const SizedBox(height: StrideSpace.rhythmRow),
        SlotPlate(
          slot: label,
          itemName: worn[slot]?.displayName,
          rarity: worn[slot]?.rarity,
          iconPath: worn[slot] == null
              ? null
              : PixelIcons.itemFor(worn[slot]!.itemId),
          // The figure combat reads, or what the tool opens — the same line
          // the tile carries, from the same projection, so the case and the
          // grid cannot disagree about a piece.
          stat: switch (worn[slot]) {
            final EquippedSummary e => switch (session.gearStatsOf(e.itemId)) {
              final GearStats g => GearStatLine.textOf(g),
              _ => null,
            },
            _ => null,
          },
          // Only where there is a tile to scroll to. An equipped piece the
          // pack no longer lists cannot be pointed at, and a tap that scrolls
          // nowhere is worse than no tap.
          onTap: worn[slot] == null || !held.contains(worn[slot]!.itemId.value)
              ? null
              : () => onSelect(worn[slot]!.itemId),
        ),
      ],
    ];

    return SectionCard(
      role: PanelRole.heroPlate,
      surface: PanelSurface.oilcloth,
      padding: const EdgeInsets.all(StrideSpace.cardPaddingCompact),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // **The narrow branch, and it is measured rather than chosen.**
          //
          // Beside a 130 dp well the plates get whatever the card has left. At
          // the 393 reference that is 175 dp, which a plate spends as icon 50 +
          // gap 8 + 109 of type. At 320 the card itself is 244 wide inside the
          // frame, the plates get 102, and the type column falls to **36** —
          // where `WEAPON` needs 37.6 and clips, which is what
          // `ui_responsive_test` measured the first time this was a plain Row.
          //
          // So below the width a plate's type actually needs, the case stacks:
          // the figure keeps its integer ×2 (shrinking it is not available —
          // L-18), and the plates take the card's whole width instead of a
          // third of it. Nothing is dropped and nothing is rescaled; the two
          // things simply stop competing for one line.
          final double forPlates =
              constraints.maxWidth -
              StrideGeometry.portraitContent -
              2 -
              StrideSpace.s12;
          if (forPlates >= _plateFloor) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                figure,
                const SizedBox(width: StrideSpace.s12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: plates,
                  ),
                ),
              ],
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(child: figure),
              const SizedBox(height: StrideSpace.rhythmRow),
              ...plates,
            ],
          );
        },
      ),
    );
  }
}

class _EquipResult extends StatelessWidget {
  const _EquipResult({required this.report, required this.removed});

  final EquipReport report;
  final bool removed;

  @override
  Widget build(BuildContext context) {
    final Widget line = SurfaceBlock(
      child: AdaptiveText(
        report.succeeded
            ? removed
                  ? 'Set ${report.itemName} aside.'
                  : report.statChanged
                  // The swap's story, not just its fact — "ATK 7 → 9" from
                  // the same loadout the engine fights with (Fable V2).
                  ? 'Equipped ${report.itemName} — ${report.statLabel} '
                        '${report.statBefore} → ${report.statAfter}.'
                  : 'Equipped ${report.itemName}.'
            : _refusalText(report),
        style: StrideType.sub,
        color: report.succeeded
            ? StrideColors.textPrimary
            : StrideColors.textSecondary,
      ),
    );
    // A successful swap settles into place — one small scale-and-fade, per
    // report, so "ATK 7 → 9" lands as a change rather than appearing as
    // standing text. Refusals arrive flat; an error is not a moment.
    if (!report.succeeded || MediaQuery.disableAnimationsOf(context)) {
      return line;
    }
    return TweenAnimationBuilder<double>(
      key: ObjectKey(report),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: line,
      builder: (BuildContext context, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 1.04 - 0.04 * t, child: child),
      ),
    );
  }

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
    required this.keyOf,
    this.consumable = false,
    this.material = false,
    this.selected,
    this.onSelect,
  });

  final List<InventoryEntry> entries;
  final bool equipment;
  final bool consumable;

  /// Whether this group takes the dense grid (ART-12 §2).
  final bool material;

  /// The key the equipment case scrolls to for a given item.
  final GlobalKey Function(ContentId) keyOf;

  /// The tile whose evaluation is open beneath the grid, and the tap that
  /// toggles it. Null for groups whose tiles have nothing to expand.
  final ContentId? selected;
  final ValueChanged<ContentId>? onSelect;

  /// The narrowest column a 48 dp icon and its 3 dp tile padding can sit in
  /// with anything left over. Below this the grid takes fewer columns rather
  /// than rescaling the sprite (ART-12 §2).
  static const double _columnFloor = 56;

  /// The materials floor: a picture and a count, and nothing that wraps.
  static const double _denseFloor = 84;

  /// The gear floor: what a 114 dp tile spends on two name lines, the stat
  /// line and the Equip control.
  static const double _gearFloor = 132;

  /// How many columns this group takes at [width].
  ///
  /// **Only materials are dense**, and only while the type is small enough to
  /// live in a 66 dp tile. The scaler test is the whole reason the rule is a
  /// rule and not a constant: at an enlarged text scale a five-across tile can
  /// carry neither the count nor a name, so the grid gives up a column and
  /// hands the names back rather than clipping either.
  static int _columnsFor(
    double width,
    TextScaler scaler, {
    required bool dense,
  }) {
    if (!dense) return 3;
    final bool enlarged = scaler.scale(11) > 13;
    for (final int n in const <int>[5, 4, 3]) {
      if (n == 5 && enlarged) continue;
      if ((width - _gapFor(n) * (n - 1)) / n >= _columnFloor) return n;
    }
    return 3;
  }

  /// 6 at five columns, 8 at four or fewer (ART-12 §0).
  static double _gapFor(int columns) =>
      columns >= 5 ? StrideSpace.rowGap : StrideSpace.gridGap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final TextScaler scaler = MediaQuery.textScalerOf(context);
      final int columns = _columnsFor(
        constraints.maxWidth,
        scaler,
        dense: material,
      );
      // A tile only loses its name where the name cannot fit — five across.
      // At four or three the materials tile is an ordinary tile again.
      final bool compact = material && columns >= 5;

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
          crossAxisSpacing: _gapFor(columns),
          mainAxisSpacing: _gapFor(columns),
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
            scaler,
            withName: !compact,
            withControl: equipment || consumable,
            floor: compact
                ? _denseFloor
                : material
                ? StrideGeometry.itemTileMinHeight
                : _gearFloor,
          ),
        ),
        itemBuilder: (BuildContext context, int i) => _ItemTile(
          key: keyOf(entries[i].id),
          entry: entries[i],
          equipment: equipment,
          consumable: consumable,
          compact: compact,
          selected: selected == entries[i].id,
          onTap: onSelect == null ? null : () => onSelect!(entries[i].id),
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
  ///
  /// A dense cell ([withName] false) spends neither name line, and its [floor]
  /// is the materials figure rather than the gear one — but it is derived the
  /// same way, from the same terms, under the same scaler. A constant
  /// `mainAxisExtent` is the defect, whatever number it holds (D-01).
  static double _tileExtent(
    TextScaler scaler, {
    required bool withName,
    required bool withControl,
    required double floor,
  }) {
    double lineOf(TextStyle style) =>
        scaler.scale(style.fontSize!) * (style.height ?? 1);

    const double iconEdge = 48; // PixelAsset.item at x1.
    const double padding = _tilePadTop + _tilePadBottom;
    // spaceBetween, at minimum: one gap fewer when the name is not drawn.
    final double gaps = StrideSpace.s6 * (withName ? 3 : 2);

    final double needed =
        padding +
        RarityRule.thickness +
        iconEdge +
        gaps +
        (withName ? lineOf(StrideType.itemName) * 2 : 0) +
        lineOf(StrideType.itemCount);

    final double base = needed > floor ? needed : floor;

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
    super.key,
    required this.entry,
    required this.equipment,
    this.consumable = false,
    this.compact = false,
    this.selected = false,
    this.onTap,
  });

  final InventoryEntry entry;

  /// Whether this tile carries the equip control and marker.
  final bool equipment;

  /// Whether this tile carries the eat control (`DECISIONS/0023` §4).
  final bool consumable;

  /// Whether this tile is in the dense five-across grid, where the name is
  /// the Semantics label and the detail block rather than a line of type.
  final bool compact;

  /// Whether this tile's evaluation is open beneath the grid, and the tap
  /// that toggles it. The tap wraps the whole tile; the equip control
  /// inside keeps its own gesture and wins where they overlap.
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget tile = _tile(context);
    if (onTap == null) return tile;
    return Semantics(
      button: true,
      selected: selected,
      label: entry.displayName,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
      ),
    );
  }

  Widget _tile(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: selected ? StrideColors.surfaceRaised : StrideColors.surfaceCard,
      border: Border.all(
        color: selected ? StrideColors.actionEdge : StrideColors.borderDefault,
      ),
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
        // In the dense grid the name is the Semantics label and the detail
        // block under the grid; a 66 dp tile cannot hold a two-line name at
        // any size this system is willing to set one in.
        if (!compact)
          Text(
            entry.displayName,
            style: StrideType.itemName.copyWith(
              // The rarity recolours the name and changes nothing else about
              // it — same size, same weight, same two-line clamp. A rank is
              // not a promotion (`rarity_item_title.dart`).
              color: RarityStyle.inkOr(
                entry.rarity,
                StrideColors.textSecondary,
              ),
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
                : () async {
                    // A successful equip clicks into place — the selection
                    // haptic, only when the engine accepted. A refusal
                    // renders its sentence and stays silent.
                    await controller.equip(item);
                    if (context.mounted &&
                        (controller.lastEquip?.succeeded ?? false)) {
                      AudioScope.maybeRead(context)?.hapticSelection();
                      // The commit sound beside the pulse (QUEUE_03 §8).
                      AudioEvents.commit(AudioScope.maybeRead(context));
                    }
                  },
          ),
        ),
      ],
    );
  }
}
