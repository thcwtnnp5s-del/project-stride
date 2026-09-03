/// An equipment case, and then a pack.
///
/// Icon + label + count is the complete semantic unit (`ART_DIRECTION.md`
/// **L-17**). The icon lets the eye sort the grid; the label removes the
/// remaining ambiguity.
///
/// ## What EPO03 rebuilt (`DIR-05`, the page model)
///
/// The screen used to be three dark rectangles down a black page: a card
/// holding the figure and three plates that said `TOOL` and `Empty` in boxes,
/// then one big card holding two grids of smaller dark cards, each with an
/// Equip button bar bolted under it. That is the round's first-named failure —
/// one rhythm, one weight, a button in every tile — reproduced four ways on a
/// single screen.
///
/// It is now the thing it is named after. The page is **leather**: the case.
/// The figure stands in a window cut into it (`KitFrame.insetWell`), and the
/// three slots are **wells cut into the leather** (`KitFrame.slotWell`) with
/// the worn piece seated in each. An empty well is an empty well — the recess
/// with the slot's class shadow lying in it — never the word `Empty` in a box.
/// Each piece's figure is **stamped** beside its well rather than run out as a
/// sentence.
///
/// Below a strap seam the page changes material: the pack is **canvas**, and
/// what the player owns sits in pockets **ruled in rows** on it — materials
/// five across, gear three across — with the Equip control a small plate on
/// the pocket itself. No card anywhere on the screen, and nothing rounded.
///
/// Both materials come from the shipped grain set and both frames from the
/// kit's landed rows (`KIT_CONTRACT` §8), so this rebuild cost **zero
/// generations**; the two rows that have not landed (`KitTile.pocketRule` for
/// the pocket rules, `KitTile.caseStrap` for the seam) reserve their declared
/// thickness and paint the hairline the pack already drew, so the screen gains
/// material the day either lands without moving a pixel of layout.
///
/// ## Two grids, and why the materials one drops its labels
///
/// Materials run five across, where a two-line name does not fit, so the name
/// becomes the pocket's Semantics label and the detail block under the rows.
/// That is a trade with a stated limit: the moment the ambient text scaler
/// grows past the point a five-across pocket can carry, the rows drop to four
/// or three and the names come back. Gear runs three across, which is what the
/// Equip plate needs.
///
/// ## Equipping
///
/// `EventReducer._started` adds the starting loadout to *inventory only* —
/// nothing is equipped on a new game — and gathering nodes require an
/// **equipped** tool, so without a control here Woodcutting and Mining were
/// unreachable on the phone. Each equipment pocket therefore carries a compact
/// `Equip` / `Unequip` plate and its worn state, and the case above the pack
/// reads the three slots back. All of it is read from the session's
/// projections (`equippedIn`, `isEquipped`) and dispatched through
/// `SessionController` — the screen decides nothing about what may be worn;
/// the engine refuses, and the refusal is rendered (`RULES.md` E-2).
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
import '../../components/panel_skin.dart';
import '../../components/pixel_asset.dart';
import '../../components/rarity_item_title.dart';
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

/// The canvas pack, so a test can scope a finder to the pockets rather than to
/// the case above them — both draw an item's name in the same role, and the
/// case is a readout with nothing in it to tap.
///
/// Published for the same reason `world_screen.dart` publishes its sheet keys:
/// a private widget type is not a finder, and matching on `GridView` was one.
const Key inventoryPackKey = ValueKey<String>('inventory-pack');

/// The leather case at the head of the page.
const Key inventoryCaseKey = ValueKey<String>('inventory-case');

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  /// The equipment pocket whose full evaluation is open beneath the rows —
  /// ephemeral UI selection, never a game figure (`RULES.md` E-2).
  ContentId? _gearDetail;

  /// The material / consumable / quest pocket whose purpose block is open —
  /// the same pattern for the other three groups (Fable V2,
  /// `DECISIONS/0027`): a Boar Tusk and a Bronze Ingot used to be
  /// indistinguishable in purpose from the rows.
  ContentId? _itemDetail;

  /// The open detail block, whichever kind, so a selection can scroll it
  /// into view: with two rows of equipment the block used to land ~300 dp
  /// below the tapped pocket — often below the fold, where a tap looked like
  /// it did nothing (Fable V2 UX audit S5).
  final GlobalKey _detailKey = GlobalKey();

  /// One key per pocket, so the equipment case can scroll the pack to the
  /// piece a slot well names. Created on demand and kept: an item leaves the
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

  /// A slot well names a piece; this is what tapping it does. The well is a
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

    // The page is the case: oiled leather, full bleed, no border and no
    // radius by construction (`DIR-05`, `PageGround`). The pack's canvas is
    // sewn onto it below, which is the one screen in the round that is
    // legitimately two materials — the director's table says so by name.
    return PageGround(
      surface: PanelSurface.leather,
      child: ListView(
        padding: const EdgeInsets.only(bottom: StrideSpace.s16),
        children: <Widget>[
          if (c.session.isStale)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                StrideSpace.screenGutter,
                StrideSpace.s10,
                StrideSpace.screenGutter,
                0,
              ),
              child: StaleBanner(busy: c.busy, onReload: c.reload),
            ),
          // The case, whether or not the pack has anything in it: the loadout
          // is a fact about the player, not about the bag, and a new game
          // whose three wells are empty is exactly the state the case exists
          // to show.
          Padding(
            key: inventoryCaseKey,
            padding: const EdgeInsets.fromLTRB(
              StrideSpace.screenGutter,
              StrideSpace.s12,
              StrideSpace.screenGutter,
              StrideSpace.s16,
            ),
            child: _EquipmentCase(onSelect: _openFromSlot),
          ),
          // The seam. `caseStrap` has not landed (NAV's ledger: the roll came
          // back as an unreadably dark smear), so this reserves the declared
          // 32 dp and draws the one boundary line the page already had.
          const KitEdge(
            tile: KitTile.caseStrap,
            fallbackColor: StrideColors.borderDefault,
          ),
          _Pack(
            entries: entries,
            total: total,
            groups: groups,
            controller: c,
            detailKey: _detailKey,
            keyOf: _tileKey,
            gearDetail: _gearDetail,
            itemDetail: _itemDetail,
            onSelectGear: (ContentId id) {
              setState(() {
                _itemDetail = null;
                _gearDetail = _gearDetail == id ? null : id;
              });
              if (_gearDetail != null) _reveal();
            },
            onSelectItem: (ContentId id) {
              setState(() {
                _gearDetail = null;
                _itemDetail = _itemDetail == id ? null : id;
              });
              if (_itemDetail != null) _reveal();
            },
          ),
        ],
      ),
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

  /// Whether these pockets carry the equip plate. Only the equipment group
  /// does — materials and consumables occupy no slot.
  final bool equipment;

  /// Whether these pockets carry the eat plate (`DECISIONS/0023` §4).
  final bool consumable;

  /// Whether this group takes the dense five-across row (ART-12 §2). Only
  /// materials do: they are the group a player holds forty of, and the only
  /// one whose pocket has nothing to carry but a picture and a count.
  final bool material;

  final List<InventoryEntry> entries;
}

/// The canvas pack: what the player owns, in pockets ruled in rows.
///
/// A `PageGround` inside a `PageGround` — the second material of the one
/// screen the director's table gives two. There is no card here and no
/// rectangle around the whole of it: the canvas simply begins, and the ruled
/// rows are what gives a sparse pack an edge without putting a box round it.
class _Pack extends StatelessWidget {
  const _Pack({
    required this.entries,
    required this.total,
    required this.groups,
    required this.controller,
    required this.detailKey,
    required this.keyOf,
    required this.gearDetail,
    required this.itemDetail,
    required this.onSelectGear,
    required this.onSelectItem,
  });

  final List<InventoryEntry> entries;
  final int total;
  final List<_Group> groups;
  final SessionController controller;
  final GlobalKey detailKey;
  final GlobalKey Function(ContentId) keyOf;
  final ContentId? gearDetail;
  final ContentId? itemDetail;
  final ValueChanged<ContentId> onSelectGear;
  final ValueChanged<ContentId> onSelectItem;

  @override
  Widget build(BuildContext context) {
    final SessionController c = controller;

    return PageGround(
      key: inventoryPackKey,
      surface: PanelSurface.oilcloth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          StrideSpace.screenGutter,
          StrideSpace.s14,
          StrideSpace.screenGutter,
          StrideSpace.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionHeading(
              label: 'Carried',
              // The carried total, given the weight of a figure rather than
              // of a footnote. It is the one aggregate on the screen.
              trailing: Text(
                total == 1 ? '1 item' : '$total items',
                style: StrideType.micro.copyWith(
                  color: StrideColors.textPrimary,
                  fontSize: 12.5,
                ),
              ),
            ),
            if (entries.isEmpty) ...<Widget>[
              const SizedBox(height: StrideSpace.rhythmRow),
              const KitRule(style: KitRuleStyle.chart),
              const SizedBox(height: StrideSpace.rhythmRow),
              const Text(
                'You are carrying nothing.',
                style: StrideType.body,
              ),
            ],
            for (final _Group group in groups) ...<Widget>[
              // 16 between named groups, 8 between peers inside one — the
              // three rhythms of ART-12 §0, never one value twice.
              const SizedBox(height: StrideSpace.rhythmGroup),
              // The group's name over the chart rule, only where there is
              // more than one group. With a single kind of thing a divider
              // label is noise.
              if (groups.length > 1) ...<Widget>[
                KitRule(style: KitRuleStyle.chart, title: group.label),
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
              _PocketRows(
                entries: group.entries,
                equipment: group.equipment,
                consumable: group.consumable,
                material: group.material,
                keyOf: keyOf,
                selected: group.equipment ? gearDetail : itemDetail,
                // One detail open at a time, whichever kind: two blocks
                // at once would be two answers to one tap, and the one
                // reveal key must be unique in the tree.
                onSelect: group.equipment ? onSelectGear : onSelectItem,
              ),
              // The opened piece's full evaluation — the same
              // `GearStatsBlock` the craft bench shows, under the rows it was
              // opened from, so the bag can answer "why does a better tool
              // matter" without a trip to the bench.
              if (group.equipment && gearDetail != null)
                if (c.session.gearStatsOf(gearDetail!)
                    case final GearStats g) ...<Widget>[
                  KeyedSubtree(
                    key: detailKey,
                    child: GearStatsBlock(stats: g),
                  ),
                ],
              // The opened item's purpose — what it is for, where it comes
              // from, what it makes possible (Fable V2). Only in the group
              // that owns the selected pocket, so the block opens beside its
              // trigger.
              //
              // **The name renders whether or not a purpose exists.** In a
              // five-across row the pocket has no room for a label, so this
              // block is where the name is said; gating it on the purpose
              // would leave a tapped pocket with nothing to show and no way
              // to learn what it is.
              if (!group.equipment && itemDetail != null)
                if (group.entries.any(
                  (InventoryEntry e) => e.id == itemDetail,
                )) ...<Widget>[
                  KeyedSubtree(
                    key: detailKey,
                    child: _ItemPurposeBlock(
                      name: c.session.displayNameOf(itemDetail!),
                      purpose: c.session.itemPurposeOf(itemDetail!),
                    ),
                  ),
                ],
            ],
          ],
        ),
      ),
    );
  }
}

/// What one item is *for* — sources above uses, uses above trivia — under
/// the rows the pocket was tapped in (Fable V2, `DECISIONS/0027`).
///
/// Progressive disclosure by construction: nothing renders until a pocket is
/// tapped, and each line renders only when the content pack has something
/// to say. A trophy says it is one, so dead-by-design stops reading as a
/// recipe the player has not found.
///
/// Ruled rather than boxed since EPO03: a note written on the canvas under a
/// rule, not a `surfaceBlock` rectangle sitting on it.
class _ItemPurposeBlock extends StatelessWidget {
  const _ItemPurposeBlock({required this.name, required this.purpose});

  final String name;

  /// Null when the content pack says nothing about this item. The block still
  /// renders: in the five-across row it is the only place the name appears.
  final ItemPurposeView? purpose;

  @override
  Widget build(BuildContext context) {
    final ItemPurposeView? purpose = this.purpose;
    if (purpose == null) {
      return _MarginNote(
        children: <Widget>[
          AdaptiveText(name, style: StrideType.itemName),
          const SizedBox(height: StrideSpace.s4),
          Text(
            'Nothing in the world asks for this yet.',
            style: StrideType.micro.copyWith(color: StrideColors.textMuted),
          ),
        ],
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

    return _MarginNote(
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
    );
  }
}

/// A note written on the canvas: a rule, then what it says.
///
/// The replacement for `SurfaceBlock` on this screen. A block was a dark fill
/// with a radius, which on a canvas page is a card by another name; a rule and
/// the material showing through is what a note in a pack looks like.
class _MarginNote extends StatelessWidget {
  const _MarginNote({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: StrideSpace.s6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const KitRule(style: KitRuleStyle.chart),
        const SizedBox(height: StrideSpace.s8),
        ...children,
      ],
    ),
  );
}

/// What the last out-of-combat meal did.
class _FoodResult extends StatelessWidget {
  const _FoodResult({required this.report});

  final FoodReport report;

  @override
  Widget build(BuildContext context) => _MarginNote(
    children: <Widget>[
      AdaptiveText(
        report.succeeded
            ? 'Ate ${report.itemName} — +${report.healed} HP '
                  '(${report.hpAfter} now).'
            : _refusalText(report),
        style: StrideType.sub,
        color: report.succeeded
            ? StrideColors.textPrimary
            : StrideColors.textSecondary,
      ),
    ],
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

/// The equipment case: the Traveler as they stand in a window of the case, and
/// the three slots as wells cut into the leather beside them.
///
/// ## What replaced what
///
/// FMPO02 made this the screen's hero — the figure at ×2 and the slots as
/// plates rather than as columns of running text — and it was right about the
/// hierarchy and wrong about the material. Three `surfaceBlock` rounded
/// rectangles saying `TOOL` / `Empty` is a list of empty database rows, which
/// is what the owner's device read named.
///
/// EPO03 keeps every fact and changes what carries it. The figure is in a
/// window (`KitFrame.insetWell`, the kit's measured 15 dp band); each slot is a
/// well (`KitFrame.slotWell`, 8 dp) with the worn piece seated in it or, when
/// nothing is, the slot's **class shadow** lying in the recess. The figure's
/// resolution is untouched: whatever `TravelerArt.figureFor` returns for the
/// session's `equipmentVisualState`, at a whole ×2, so a fifth armour body or a
/// new weapon appears here the day the resolver knows it.
///
/// Still a readout — the pack keeps the controls ([SlotPlate] says why) — and
/// still every fact from the same projections the engine reads.
class _EquipmentCase extends StatelessWidget {
  const _EquipmentCase({required this.onSelect});

  /// What a well's tap does: select this item's pocket in the pack below and
  /// scroll it into view.
  final ValueChanged<ContentId> onSelect;

  /// Slot, its word, and the sprite whose silhouette lies in the empty well.
  ///
  /// The shadow is the slot's **starting** piece — a sword, a tunic, a pickaxe
  /// — recoloured to one ink, never a new asset and never a padlock: an empty
  /// slot is a thing the player has not filled, not a thing being withheld.
  static const List<(EquipmentSlot, String, String)> _slots =
      <(EquipmentSlot, String, String)>[
        (EquipmentSlot.weapon, 'Weapon', 'item.training_sword'),
        (EquipmentSlot.armor, 'Armour', 'item.traveler_tunic'),
        (EquipmentSlot.tool, 'Tool', 'item.training_pickaxe'),
      ];

  /// The narrowest a slot row may be and still hold its own type beside the
  /// figure: the well (48 of sprite inside `slotWell`'s band), an 8 dp gap and
  /// 60 dp of type — which is `ARMOUR` at 37.3 with room to breathe. Below
  /// this the case stacks.
  static double get _rowFloor => SlotPlate.wellEdge + StrideSpace.s8 + 60;

  /// What the figure's window measures: 128 of sprite inside `insetWell`'s
  /// measured band. Reserved whether or not the raster decodes.
  static double get _windowEdge =>
      StrideGeometry.portraitContent +
      KitFrames.insetFor(KitFrame.insetWell) * 2;

  @override
  Widget build(BuildContext context) {
    final StrideSession session = SessionScope.of(context).session;
    // Slot → what is in it, with its rarity, from the projection the engine's
    // own `Equipment.bySlot` backs. Read once rather than per well.
    final Map<EquipmentSlot, EquippedSummary> worn =
        <EquipmentSlot, EquippedSummary>{
          for (final EquippedSummary e in session.equippedSummary) e.slot: e,
        };
    final Set<String> held = <String>{
      for (final InventoryEntry e in session.inventoryEntries) e.id.value,
    };

    // **What the player is wearing, as a figure** (VAWO01, Q-14), at ×2 — 64
    // native doubled, never a fractional fit to the window. Resolved through
    // `TravelerArt` from the session's existing projection; an unmapped item
    // falls back to the base Traveler, and a body the resolver learns later
    // appears here with no change to this call.
    //
    // Decorative: the wells state every fact it shows.
    final Widget figure = ExcludeSemantics(
      child: KitPlate.well(
        frame: KitFrame.insetWell,
        contentWidth: StrideGeometry.portraitContent,
        contentHeight: StrideGeometry.portraitContent,
        child: PixelAsset(
          assetPath: TravelerArt.figureFor(session.equipmentVisualState),
          nativeWidth: 64,
          nativeHeight: 64,
          scale: 2,
        ),
      ),
    );

    final List<Widget> wells = <Widget>[
      for (final (EquipmentSlot slot, String label, String shadow)
          in _slots) ...<Widget>[
        if (slot != _slots.first.$1)
          const SizedBox(height: StrideSpace.rhythmRow),
        Builder(
          builder: (BuildContext context) {
            final EquippedSummary? here = worn[slot];
            final GearStats? stats = here == null
                ? null
                : session.gearStatsOf(here.itemId);
            return SlotPlate(
              slot: label,
              itemName: here?.displayName,
              rarity: here?.rarity,
              iconPath: here == null ? null : PixelIcons.itemFor(here.itemId),
              shadowPath: PixelIcons.itemFor(ContentId.unchecked(shadow)),
              // The figure combat reads, or what the tool opens — the same
              // projection the pocket carries, so the case and the rows
              // cannot disagree about a piece.
              statLabel: stats == null ? null : GearStatLine.labelOf(stats),
              statFigure: stats == null ? null : GearStatLine.figureOf(stats),
              statNote: stats == null ? null : GearStatLine.noteOf(stats),
              // Only where there is a pocket to scroll to. An equipped piece
              // the pack no longer lists cannot be pointed at, and a tap that
              // scrolls nowhere is worse than no tap.
              onTap: here == null || !held.contains(here.itemId.value)
                  ? null
                  : () => onSelect(here.itemId),
            );
          },
        ),
      ],
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // **The narrow branch, and it is measured rather than chosen.**
        //
        // Beside the figure's window the slot rows get whatever the page has
        // left. At the 393 reference that is 191 dp, which a row spends as
        // well 64 + gap 8 + 119 of type. At 320 it falls to 118, where the
        // type column is 46 and `WEAPON` needs 37.6 with a name under it —
        // which is what `ui_responsive_test` measured the first time this was
        // a plain Row.
        //
        // So below the width a row's type actually needs, the case stacks:
        // the figure keeps its integer ×2 (shrinking it is not available —
        // L-18), and the wells take the page's whole width instead of a third
        // of it. Nothing is dropped and nothing is rescaled.
        final double forWells =
            constraints.maxWidth - _windowEdge - StrideSpace.s12;
        if (forWells >= _rowFloor) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              figure,
              const SizedBox(width: StrideSpace.s12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: wells,
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
            ...wells,
          ],
        );
      },
    );
  }
}

class _EquipResult extends StatelessWidget {
  const _EquipResult({required this.report, required this.removed});

  final EquipReport report;
  final bool removed;

  @override
  Widget build(BuildContext context) {
    final Widget line = _MarginNote(
      children: <Widget>[
        AdaptiveText(
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
      ],
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

/// The pack's pockets, ruled in rows.
///
/// ## Why this stopped being a `GridView`
///
/// A grid gives every cell one `mainAxisExtent`, and that extent had to be
/// **computed** from the type each cell carries under the ambient scaler,
/// because a fixed box around growing text is D-01 and a constant is that
/// defect whatever number it holds. Forty lines of arithmetic existed to
/// predict a height Flutter is perfectly able to measure.
///
/// Rows of pockets need no prediction: each row is as tall as its tallest
/// pocket, every pocket in it is stretched to that height by `IntrinsicHeight`,
/// and the type inside grows without anything clipping. The arithmetic is
/// gone, the defect it guarded against is structurally unreachable, and the
/// rows are what the pack is supposed to look like anyway.
///
/// The rule under each row is `KitTile.pocketRule`. It has not landed, so it
/// reserves its declared 12 dp and draws the separator hairline the pack
/// already drew — the pockets are seated on rules either way.
class _PocketRows extends StatelessWidget {
  const _PocketRows({
    required this.entries,
    required this.equipment,
    required this.keyOf,
    required this.onSelect,
    this.consumable = false,
    this.material = false,
    this.selected,
  });

  final List<InventoryEntry> entries;
  final bool equipment;
  final bool consumable;

  /// Whether this group takes the dense rows (ART-12 §2).
  final bool material;

  /// The key the equipment case scrolls to for a given item.
  final GlobalKey Function(ContentId) keyOf;

  /// The pocket whose evaluation is open beneath the rows, and the tap that
  /// toggles it.
  final ContentId? selected;
  final ValueChanged<ContentId> onSelect;

  /// The narrowest column a pocket's well can sit in with anything left over.
  /// Below this the rows take fewer columns rather than rescaling the sprite
  /// (ART-12 §2) — the well is the floor now, not the bare 48 dp sprite,
  /// because the sprite sits inside a frame's band on both sides.
  static double get _columnFloor => SlotPlate.wellEdge;

  /// How many columns this group takes at [width].
  ///
  /// **Only materials are dense**, and only while the type is small enough to
  /// live in a five-across pocket. The scaler test is the whole reason the
  /// rule is a rule and not a constant: at an enlarged text scale a
  /// five-across pocket can carry neither the count nor a name, so the rows
  /// give up a column and hand the names back rather than clipping either.
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
      // A pocket only loses its name where the name cannot fit — five across.
      // At four or three the materials pocket is an ordinary pocket again.
      final bool compact = material && columns >= 5;
      final double gap = _gapFor(columns);

      final List<Widget> rows = <Widget>[];
      for (int start = 0; start < entries.length; start += columns) {
        final int end = (start + columns) < entries.length
            ? start + columns
            : entries.length;
        rows.add(
          Row(
            // **Top-aligned, and the pockets are the same height anyway.**
            //
            // `IntrinsicHeight` is what a row of equal-height cells normally
            // wants, and it is unavailable here: `StrideButton` and
            // `AdaptiveText` are both `LayoutBuilder`s, and a `LayoutBuilder`
            // refuses to report an intrinsic dimension. So the pockets in one
            // group are made equal *by construction* instead — every term in
            // a pocket is fixed for its group except the item's name, and
            // [_Pocket] reserves that at two lines under the ambient scaler
            // (`_nameHeight`). Same result, no speculative layout.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = start; i < end; i++) ...<Widget>[
                if (i > start) SizedBox(width: gap),
                Expanded(
                  child: _Pocket(
                    key: keyOf(entries[i].id),
                    entry: entries[i],
                    equipment: equipment,
                    consumable: consumable,
                    compact: compact,
                    selected: selected == entries[i].id,
                    onTap: () => onSelect(entries[i].id),
                  ),
                ),
              ],
              // The row keeps its columns to the end, so a short last row
              // sits under the one above it rather than spreading.
              for (int i = end; i < start + columns; i++) ...<Widget>[
                SizedBox(width: gap),
                const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
        );
        rows.add(
          const KitEdge(
            tile: KitTile.pocketRule,
            fallbackColor: StrideColors.separator,
            fallbackAtEnd: true,
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      );
    },
  );
}

/// One pocket on the canvas: the rank's mark, the piece in a well, its name,
/// its count, and — on gear and food — the small plate that acts.
///
/// **Not a card.** There is no fill and no border: the canvas is the pocket's
/// ground, and a selected pocket says so by raising its well and drawing the
/// action edge under it, not by turning into a lighter rectangle.
class _Pocket extends StatelessWidget {
  const _Pocket({
    super.key,
    required this.entry,
    required this.equipment,
    required this.onTap,
    this.consumable = false,
    this.compact = false,
    this.selected = false,
  });

  final InventoryEntry entry;

  /// Whether this pocket carries the equip plate and its worn state.
  final bool equipment;

  /// Whether this pocket carries the eat plate (`DECISIONS/0023` §4).
  final bool consumable;

  /// Whether this pocket is in the dense five-across row, where the name is
  /// the Semantics label and the detail block rather than a line of type.
  final bool compact;

  /// Whether this pocket's evaluation is open beneath the rows, and the tap
  /// that toggles it. The tap wraps the whole pocket; the plate inside keeps
  /// its own gesture and wins where they overlap.
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: entry.displayName,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _pocket(context),
    ),
  );

  /// The room two lines of the item name need **at the ambient scaler**.
  ///
  /// Two lines, always — the pocket reserves the wrap whether or not this
  /// particular name uses it, so every pocket in a group is the same height
  /// and the plates along a row land on one line. Derived from the scaler and
  /// the role, never a constant: a fixed box around growing text is D-01, and
  /// the number does not stop being a constant because it looks generous.
  static double _nameHeight(TextScaler scaler) =>
      scaler.scale(StrideType.itemName.fontSize!) *
      (StrideType.itemName.height ?? 1) *
      2;

  Widget _pocket(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(2, StrideSpace.s8, 2, StrideSpace.s8),
    decoration: selected
        ? const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: StrideColors.actionEdge, width: 2),
            ),
          )
        : null,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The rank's mark, and not its word, for a measured reason
        // ([RarityRule]): `UNCOMMON` needs 72.3 dp at text scale 1.4 in a
        // 393 dp four-column pocket that has 68.8. The word is carried by
        // every surface that gives an item a full row.
        RarityRule(rarity: entry.rarity),
        const SizedBox(height: StrideSpace.s6),
        KitPlate.well(
          frame: KitFrame.slotWell,
          contentWidth: SlotPlate.iconEdge,
          contentHeight: SlotPlate.iconEdge,
          child: PixelAsset.item(PixelIcons.itemFor(entry.id)),
        ),
        const SizedBox(height: StrideSpace.s6),
        // In the dense row the name is the Semantics label and the detail
        // block under the rows; a five-across pocket cannot hold a two-line
        // name at any size this system is willing to set one in.
        if (!compact)
          SizedBox(
            height: _nameHeight(MediaQuery.textScalerOf(context)),
            child: Text(
              entry.displayName,
              style: StrideType.itemName.copyWith(
                // The rarity recolours the name and changes nothing else
                // about it — same size, same weight, same two-line clamp. A
                // rank is not a promotion (`rarity_item_title.dart`).
                color: RarityStyle.inkOr(
                  entry.rarity,
                  StrideColors.textSecondary,
                ),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.clip,
            ),
          ),
        const SizedBox(height: StrideSpace.s6),
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

/// The `Eat` plate on a consumable pocket — the out-of-combat heal
/// (`DECISIONS/0023` §4). The line above it carries nothing (consumables have
/// no worn state); it keeps every acting pocket's plate at one height, exactly
/// as the equip group does.
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

/// The worn line and the `Equip` / `Unequip` plate on one pocket.
///
/// The line is reserved even when empty so every pocket in the group puts its
/// plate at the same height inside the row's intrinsic box.
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
    // read from the same projection that marked it worn.
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
        // the word WORN, so the line the pocket reserved answers two
        // questions instead of one.
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
        // Centred in the pocket: the secondary control shrink-wraps to the
        // left of whatever it is given, and a left-hugging plate in a centred
        // column of picture, name and count would read as misaligned.
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
