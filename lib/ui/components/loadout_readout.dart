/// The loadout readouts and the ruled ledger — the three FMPO02 primitives
/// the Inventory equipment case and the Character folio are assembled from
/// (`MILESTONES/evidence/FMPO02/wave1/ART-12_ux_brief.md` §2, §3).
///
/// ## Why these are readouts and not controls
///
/// Equipment is shown in three places now — the case at the top of the pack,
/// the dressing strip on the folio, and the tile in the grid — and exactly one
/// of them may act. A slot that could be emptied from the case, from the strip
/// and from the tile is three answers to one question, and the two that are not
/// the pack tile have no room for the refusal sentence the engine returns
/// (`RULES.md` E-2). So [SlotPlate] and [DressingChip] carry no `Equip`, no
/// `Unequip` and, deliberately, **no lock glyph**: an empty slot is a thing the
/// player has not filled yet, not a thing the game is withholding.
///
/// ## Why nothing here is a fixed box
///
/// Every height below is a `minHeight`. The designed figures — 56 for a plate,
/// 44 for a chip, 36 for a ledger row — are what the arrangement is measured
/// at, not what it is clamped to, because each one contains type that grows
/// with the ambient text scaler. A fixed box around scaling text is D-01, and
/// this file is three of the shapes it would take.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show Rarity;

import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'adaptive_text.dart';
import 'pixel_asset.dart';
import 'rarity_item_title.dart';
import 'surfaces.dart';

/// The word an empty slot uses, in one place so the case and the strip cannot
/// disagree about it.
const String kEmptySlotWord = 'Empty';

/// One equipped slot in the Inventory case: icon, slot name, item name in its
/// rank's ink, and the one stat line the tile also carries.
///
/// [onTap] scrolls the pack to this item's tile and selects it — a readout
/// that *points at* the control rather than duplicating it.
class SlotPlate extends StatelessWidget {
  const SlotPlate({
    super.key,
    required this.slot,
    this.itemName,
    this.rarity,
    this.iconPath,
    this.stat,
    this.onTap,
  });

  /// `Weapon`, `Armour`, `Tool` — uppercased here, so no caller has to.
  final String slot;

  /// What is in the slot, or null for an empty one.
  final String? itemName;
  final Rarity? rarity;
  final String? iconPath;

  /// `ATK 7 · +2`, `PICKAXE · T1` — the same line the grid tile shows, from
  /// the same projection, so the two can never disagree.
  final String? stat;

  final VoidCallback? onTap;

  /// The designed height (ART-12 §2). A floor: the three text lines inside
  /// grow with the scaler and the plate grows with them.
  static const double minHeight = 56;

  /// The icon's displayed edge — 48 native at ×1, the item family's size.
  static const double iconEdge = 48;

  @override
  Widget build(BuildContext context) {
    final bool empty = itemName == null;
    final Widget plate = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: Container(
        padding: const EdgeInsets.all(StrideSpace.s4),
        decoration: const BoxDecoration(
          color: StrideColors.surfaceBlock,
          borderRadius: StrideRadius.inner,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // An empty slot draws the well and leaves it empty — a recessed
            // silhouette, which is what "nothing is in here" looks like. Never
            // a padlock: nothing is locked.
            InsetWell.square(
              contentSize: iconEdge,
              child: iconPath == null
                  ? const SizedBox(width: iconEdge, height: iconEdge)
                  : PixelAsset.item(iconPath!),
            ),
            const SizedBox(width: StrideSpace.s8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AdaptiveText(
                    slot.toUpperCase(),
                    style: StrideType.microLabel,
                    minScale: 0.8,
                  ),
                  const SizedBox(height: StrideSpace.s2),
                  RarityName(
                    name: itemName ?? kEmptySlotWord,
                    rarity: rarity,
                    style: StrideType.itemName,
                    fallback: empty
                        ? StrideColors.textMuted
                        : StrideColors.textPrimary,
                  ),
                  if (stat case final String s) ...<Widget>[
                    const SizedBox(height: StrideSpace.s2),
                    AdaptiveText(
                      s,
                      style: StrideType.micro,
                      color: StrideColors.textSecondary,
                      minScale: 0.8,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      label: '$slot: ${itemName ?? kEmptySlotWord}',
      child: ExcludeSemantics(
        child: onTap == null
            ? plate
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: plate,
              ),
      ),
    );
  }
}

/// One slot on the Character folio's dressing strip: a 32 dp icon over the
/// item's name in its rank's ink.
///
/// A readout with no gesture at all. The folio's subject is the traveller, and
/// what they are wearing is part of the portrait's answer, not a second route
/// into the pack.
class DressingChip extends StatelessWidget {
  const DressingChip({
    super.key,
    required this.slot,
    this.itemName,
    this.rarity,
    this.iconPath,
  });

  final String slot;
  final String? itemName;
  final Rarity? rarity;
  final String? iconPath;

  /// The touch-region floor the strip keeps even though it does not act — a
  /// row of things the size of a control that is not one reads as broken; a
  /// row of things sized like the rest of the sheet reads as information.
  static const double minHeight = StrideGeometry.buttonHitFloor;

  /// **48, and the brief's 32 is why this comment exists.** ART-12 §3 asks for
  /// a 32 dp icon; the item family is authored at 48 native and there is no
  /// 32 native item set, so 32 dp would mean drawing a 48 px sprite at ×0.667.
  /// Integer sprite scales are a non-negotiable floor in the same brief's §0,
  /// [PixelAsset] asserts them, and a fractionally rescaled icon is the exact
  /// defect that assert exists to catch. The chip is 16 dp taller than drawn
  /// and every pixel in it is on its own grid.
  static const double iconEdge = 48;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$slot: ${itemName ?? kEmptySlotWord}',
    child: ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InsetWell.square(
              contentSize: iconEdge,
              child: iconPath == null
                  ? const SizedBox(width: iconEdge, height: iconEdge)
                  : PixelAsset.item(iconPath!),
            ),
            const SizedBox(height: StrideSpace.s6),
            // Wrapping, not shrinking: the strip is three columns of about
            // 100 dp at the phone reference and 76 at 320 dp, and
            // `Frost-lined Jerkin` does not fit either on one line at any
            // scale a shrink ladder is allowed to reach.
            RarityName.wrapping(
              name: itemName ?? kEmptySlotWord,
              rarity: rarity,
              style: StrideType.itemName,
              fallback: itemName == null
                  ? StrideColors.textMuted
                  : StrideColors.textPrimary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

/// One line of a ruled ledger: a micro-label left, a tabular figure right.
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.leading,
    this.note,
  });

  final String label;
  final String value;

  /// Teal marks a walking figure and nothing else — the reservation the whole
  /// palette rests on.
  final Color? valueColor;

  /// The walking mark, on the label side, where the category lives.
  final Widget? leading;

  /// A short qualifier under the label — `lifetime 12,400`, `2 sources`.
  final String? note;

  /// The designed row height (ART-12 §3). A floor, not a box.
  static const double minHeight = 36;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: minHeight),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: StrideSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (leading case final Widget mark) ...<Widget>[
            mark,
            const SizedBox(width: StrideSpace.iconLabelGap),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AdaptiveText(
                  label.toUpperCase(),
                  style: StrideType.microLabel,
                  minScale: 0.8,
                ),
                if (note case final String n) ...<Widget>[
                  const SizedBox(height: StrideSpace.s2),
                  Text(n, style: StrideType.micro, maxLines: 2),
                ],
              ],
            ),
          ),
          const SizedBox(width: StrideSpace.s8),
          // The figure takes the width it needs and shrinks before it clips,
          // which is the whole of D-01's lesson about a growing value.
          Flexible(
            child: AdaptiveText(
              value,
              style: StrideType.numericValue,
              color: valueColor,
              minScale: 0.8,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    ),
  );
}

/// A column of [LedgerRow]s divided by 1 px separators.
///
/// `separator`, not `borderDefault`: the border ladder is one weight in one
/// colour and it is for outlines. This is a within-card division.
class RuledLedger extends StatelessWidget {
  const RuledLedger({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (int i = 0; i < rows.length; i++) ...<Widget>[
        if (i > 0)
          const ColoredBox(
            color: StrideColors.separator,
            child: SizedBox(height: 1, width: double.infinity),
          ),
        rows[i],
      ],
    ],
  );
}
