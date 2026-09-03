/// The loadout readouts and the ruled ledger — the three FMPO02 primitives
/// the Inventory equipment case and the Character folio are assembled from
/// (`MILESTONES/evidence/FMPO02/wave1/ART-12_ux_brief.md` §2, §3), rebuilt on
/// the EPO03 kit.
///
/// ## What EPO03 changed, and why the word left
///
/// A slot used to be a **plate**: a `surfaceBlock` rectangle holding an icon,
/// the slot's name, and — when nothing was in it — the word `Empty`. That is
/// the failure `DIR-05` names first, twice over: a dark rectangle in a column
/// of dark rectangles, and a word doing the work a shape should do. The case
/// is leather with wells **cut into** it, so a slot is now a
/// `KitFrame.slotWell` and an empty one reads as an empty well — the recess
/// with the slot's own class shadow lying in it, which is what "nothing is
/// seated here" looks like without saying anything.
///
/// The word survives in exactly one place: the Semantics label, where a
/// screen reader has no recess to feel. [kEmptySlotWord] is that string, and
/// on the case it is deliberately no longer painted.
///
/// ## Why these are readouts and not controls
///
/// Equipment is shown in three places now — the case at the top of the pack,
/// the dressing strip on the folio, and the pocket in the pack — and exactly
/// one of them may act. A slot that could be emptied from the case, from the
/// strip and from the pocket is three answers to one question, and the two
/// that are not the pack pocket have no room for the refusal sentence the
/// engine returns (`RULES.md` E-2). So [SlotPlate] and [DressingChip] carry no
/// `Equip`, no `Unequip` and, deliberately, **no lock glyph**: an empty slot
/// is a thing the player has not filled yet, not a thing the game is
/// withholding.
///
/// ## Why nothing here is a fixed box
///
/// Every height below is a `minHeight`. The designed figures — 64 for a slot
/// row, 44 for a chip, 36 for a ledger row — are what the arrangement is
/// measured at, not what it is clamped to, because each one contains type that
/// grows with the ambient text scaler. A fixed box around scaling text is
/// D-01, and this file is three of the shapes it would take.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show Rarity;

import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'adaptive_text.dart';
import 'panel_skin.dart';
import 'pixel_asset.dart';
import 'rarity_item_title.dart';
import 'surfaces.dart';

/// The word an empty slot uses **to a screen reader**, in one place so the
/// case and the strip cannot disagree about it.
///
/// Not painted by [SlotPlate] since EPO03 — the empty well is the statement
/// (`DIR-05`: *empty well: class shadow*). [DressingChip] still says it, and
/// says it on purpose: the folio's strip is three columns of type with no room
/// for a recess to speak in.
const String kEmptySlotWord = 'Empty';

/// The ink a class shadow is drawn in: one rung above the well's own ground,
/// so the silhouette reads as a shape lying in a recess rather than as a dim
/// picture of an item the player does not have.
const Color kClassShadowInk = StrideColors.borderDefault;

/// A sprite drawn as a silhouette — the class shadow in an empty well.
///
/// A deterministic recolour of a shipped item sprite, not a new asset
/// (`RULES.md` A-2): whatever the item family draws for the slot's starting
/// piece, flattened to one ink. It cannot drift from the item set, and it cost
/// nothing to make.
class ClassShadow extends StatelessWidget {
  const ClassShadow({super.key, required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) => ColorFiltered(
    colorFilter: const ColorFilter.mode(kClassShadowInk, BlendMode.srcATop),
    child: PixelAsset.item(assetPath),
  );
}

/// One equipment slot in the Inventory case: a well cut into the leather with
/// the worn piece seated in it, the slot's name, the piece's name in its
/// rank's ink, and its figure stamped beside them.
///
/// [onTap] scrolls the pack to this item's pocket and selects it — a readout
/// that *points at* the control rather than duplicating it.
class SlotPlate extends StatelessWidget {
  const SlotPlate({
    super.key,
    required this.slot,
    this.itemName,
    this.rarity,
    this.iconPath,
    this.shadowPath,
    this.statLabel,
    this.statFigure,
    this.statNote,
    this.onTap,
  });

  /// `Weapon`, `Armour`, `Tool` — uppercased here, so no caller has to.
  final String slot;

  /// What is in the slot, or null for an empty one.
  final String? itemName;
  final Rarity? rarity;
  final String? iconPath;

  /// The class shadow: a sprite from this slot's own family, drawn as a
  /// silhouette in the empty well. Null draws the bare recess.
  final String? shadowPath;

  /// The figure the piece is worth, split so it can be **stamped** rather than
  /// set as a sentence: `ATK` / `7`, `DEF` / `3`, `TIER` / `1`. [statNote] is
  /// the comparison the pack's pocket also carries — `+2`.
  final String? statLabel;
  final String? statFigure;
  final String? statNote;

  final VoidCallback? onTap;

  /// The designed row height. A floor: the type inside grows with the scaler
  /// and the row grows with it. The well itself is [wellEdge] — 48 of sprite
  /// inside `KitFrame.slotWell`'s measured band on each side.
  static const double minHeight = 64;

  /// The sprite's displayed edge — 48 native at ×1, the item family's size.
  static const double iconEdge = 48;

  /// What the well measures, band included. Reserved whether or not the
  /// `slot_well` raster decodes: `KitFrames.insetFor` returns the same figure
  /// either way (`KIT_CONTRACT` §0), which is why a case laid out today does
  /// not move when a row lands.
  static double get wellEdge =>
      iconEdge + KitFrames.insetFor(KitFrame.slotWell) * 2;

  @override
  Widget build(BuildContext context) {
    final Widget row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: minHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // The well is cut into the case, so it takes the page's own ground
          // as its fill — that is what makes a recess read as a recess rather
          // than as a fifth surface rung (`KIT_CONTRACT` §1, the well idiom).
          KitPlate.well(
            frame: KitFrame.slotWell,
            contentWidth: iconEdge,
            contentHeight: iconEdge,
            child: _seated,
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
                if (itemName case final String name) ...<Widget>[
                  const SizedBox(height: StrideSpace.s2),
                  RarityName(
                    name: name,
                    rarity: rarity,
                    style: StrideType.itemName,
                    fallback: StrideColors.textPrimary,
                  ),
                ],
                if (statFigure case final String figure) ...<Widget>[
                  const SizedBox(height: StrideSpace.s2),
                  _StatStamp(label: statLabel, figure: figure, note: statNote),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      label: '$slot: ${itemName ?? kEmptySlotWord}',
      child: ExcludeSemantics(
        child: onTap == null
            ? row
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: row,
              ),
      ),
    );
  }

  Widget get _seated {
    if (iconPath case final String path) return PixelAsset.item(path);
    if (shadowPath case final String shadow) {
      return ClassShadow(assetPath: shadow);
    }
    return const SizedBox(width: iconEdge, height: iconEdge);
  }
}

/// A figure stamped on the case: the small hard label, then the numeral in the
/// weight a count is set in, then the comparison if there is one.
///
/// This is the shape `DIR-05` asks for in place of a running `ATK 7 · +2`
/// sentence — the numeral is the thing the eye is looking for, so it is the
/// thing that carries the weight.
class _StatStamp extends StatelessWidget {
  const _StatStamp({required this.figure, this.label, this.note});

  final String figure;
  final String? label;
  final String? note;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      if (label case final String l) ...<Widget>[
        Padding(
          // The label sits under the figure's baseline the way a maker's mark
          // sits under a numeral, rather than beside it at the same weight.
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            l,
            style: StrideType.compactLabel.copyWith(
              color: StrideColors.textMuted,
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(width: StrideSpace.s4),
      ],
      Flexible(
        child: AdaptiveText(
          figure,
          style: StrideType.itemCount,
          color: StrideColors.textPrimary,
          minScale: 0.8,
        ),
      ),
      if (note case final String n) ...<Widget>[
        const SizedBox(width: StrideSpace.s4),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            n,
            style: StrideType.compactLabel.copyWith(
              color: StrideColors.textSecondary,
            ),
            maxLines: 1,
          ),
        ),
      ],
    ],
  );
}

/// One slot on the Character folio's dressing strip: a 48 dp sprite in the
/// kit's own well over the item's name in its rank's ink.
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
    this.shadowPath,
  });

  final String slot;
  final String? itemName;
  final Rarity? rarity;
  final String? iconPath;

  /// The class shadow, as in [SlotPlate]. The strip keeps the word beneath it
  /// as well: three narrow columns of type is not a surface a recess alone can
  /// speak on.
  final String? shadowPath;

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
            KitPlate.well(
              frame: KitFrame.slotWell,
              contentWidth: iconEdge,
              contentHeight: iconEdge,
              child: _seated,
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

  Widget get _seated {
    if (iconPath case final String path) return PixelAsset.item(path);
    if (shadowPath case final String shadow) {
      return ClassShadow(assetPath: shadow);
    }
    return const SizedBox(width: iconEdge, height: iconEdge);
  }
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
