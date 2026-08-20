/// The small data-display primitives: the label/value tile, the skill chip, the
/// requirement gate, and the primary button.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

import '../icons/pixel_icons.dart';
import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'adaptive_text.dart';
import 'pixel_asset.dart';
import 'surfaces.dart';

/// The system's dominant pattern: a micro-label above a value, with an optional
/// unit line beneath.
class LabeledValueTile extends StatelessWidget {
  const LabeledValueTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.leading,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? unit;

  /// A glyph marking what kind of quantity this is — the walking mark, usually.
  ///
  /// **On the label line, not the value line.** It used to sit immediately
  /// before the numeral, where it took 30 dp of a two-across tile's 106 dp of
  /// content at 320 dp — so `9,999,999` was measured needing 77.3 dp in the 75
  /// it was left. The glyph marks the *category*, which is what the label does,
  /// so putting the two together costs nothing and gives the figure the tile's
  /// whole width.
  final Widget? leading;

  final Color? valueColor;

  /// The floor [AdaptiveText] uses for a tile's value and label.
  ///
  /// Public because [ValueTileRow] measures against them to decide whether a
  /// row of tiles still fits side by side. Two places must agree on this number
  /// and there is one of it.
  static const double floorScale = 0.8;

  /// The horizontal cost of [leading] — a 12 px glyph at ×2, plus its gap.
  static const double leadingExtent = 24 + StrideSpace.iconLabelGap;

  @override
  Widget build(BuildContext context) => SurfaceBlock(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: StrideSpace.iconLabelGap),
            ],
            // The label shrinks too, and this is not belt-and-braces.
            //
            // `EXPERIENCE` needs 73.4 dp at 11 px and was given 46 in a
            // three-across tile at 320 dp, so the shipped build drew
            // `EXPERIENC` on the Adventure screen — a clipped word, on a
            // device, that no test in the repository could see, because
            // `TextOverflow.clip` raises nothing. Same defect as D-01, one
            // card down.
            Flexible(
              child: AdaptiveText(
                label.toUpperCase(),
                style: StrideType.microLabel,
                minScale: floorScale,
              ),
            ),
          ],
        ),
        const SizedBox(height: StrideSpace.s4),
        // Shrink-to-fit rather than clip or overflow.
        //
        // These tiles sit two- and three-across inside cards, so their width
        // falls as the phone narrows while the numeral inside them grows with
        // the player's progress. At 320 dp a two-across tile gives a 22 px
        // figure about 106 logical px, which nine characters do not fit in —
        // and the failure mode without this is a RenderFlex overflow, which is
        // a yellow stripe on a shipping screen.
        //
        // **Was an unbounded `FittedBox(scaleDown)`.** That never clipped, and
        // it also never stopped: `9,999,999` in a narrow tile came out around
        // 9 px, which is legally present and practically unreadable. An
        // unbounded shrink trades a visible defect for an invisible one, which
        // is the D-01 trade in reverse. [AdaptiveText] shrinks the same way and
        // stops at [floorScale] — 17.6 px, still above the supporting-text
        // floor — and [ValueTileRow] stacks the tiles rather than asking for
        // more than that.
        //
        // This is chrome, not pixel content — L-18's integer-scale rule governs
        // sprites, and no sprite goes through here.
        AdaptiveText(
          value,
          style: StrideType.numericValue,
          color: valueColor,
          minScale: floorScale,
        ),
        if (unit case final String u) ...<Widget>[
          const SizedBox(height: StrideSpace.s2),
          Text(u, style: StrideType.micro, maxLines: 2),
        ],
      ],
    ),
  );
}

/// Two or three [LabeledValueTile]s that sit side by side while they fit, and
/// stack when they do not.
///
/// ## Why this is a widget rather than a `Row` at each call site
///
/// A row of value tiles is the app's densest arrangement and the one whose
/// content the player grows: `9,999,999` in a two-across tile at 320 dp needs
/// 109 dp at text scale 1.4 and has 106. There is no font size inside
/// [LabeledValueTile.floorScale] that fixes that, and lowering the floor to
/// reach it would answer an accessibility request by making the type smaller —
/// which is the wrong direction, and the trade this system already refuses.
///
/// The right yield is the layout's, not the type's. Below the width the tiles
/// actually need, they stop competing for one line.
///
/// The decision is **measured, not thresholded**. A breakpoint on width or on
/// scale factor is another constant standing in for a measurement, and it is
/// wrong for exactly the strings nobody tested with — which is D-01's whole
/// story. This asks [AdaptiveText.fitsWithin] the same question the tile itself
/// will ask, at the same floor, with the same scaler.
class ValueTileRow extends StatelessWidget {
  const ValueTileRow({super.key, required this.tiles});

  final List<LabeledValueTile> tiles;

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    // The ambient style carries the font family; see `AdaptiveText.build`.
    // Measuring the bare role here would ask the wrong font whether the tiles
    // fit, and the answer decides the layout branch.
    final TextStyle inherited = DefaultTextStyle.of(context).style;

    TextStyle atFloor(TextStyle style) => inherited.merge(
      style.copyWith(fontSize: style.fontSize! * LabeledValueTile.floorScale),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double each =
            (constraints.maxWidth - StrideSpace.s8 * (tiles.length - 1)) /
            tiles.length;
        // SurfaceBlock's padding on both sides.
        final double content = each - StrideSpace.blockPadding * 2;

        bool fits = content > 0;
        for (final LabeledValueTile tile in tiles) {
          if (!fits) break;
          final double labelRoom = tile.leading == null
              ? content
              : content - LabeledValueTile.leadingExtent;
          fits =
              AdaptiveText.fitsWithin(
                tile.value,
                atFloor(StrideType.numericValue),
                scaler,
                content,
              ) &&
              AdaptiveText.fitsWithin(
                tile.label.toUpperCase(),
                atFloor(StrideType.microLabel),
                scaler,
                labelRoom,
              );
        }

        if (fits) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < tiles.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: StrideSpace.s8),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < tiles.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: StrideSpace.s8),
              tiles[i],
            ],
          ],
        );
      },
    );
  }
}

/// Skill icon plus uppercase skill name, on a raised chip.
class SkillChip extends StatelessWidget {
  const SkillChip({super.key, required this.skill, required this.label});

  final ContentId skill;
  final String label;

  @override
  Widget build(BuildContext context) {
    final String? icon = PixelIcons.skillFor(skill);
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: const BoxDecoration(
        color: StrideColors.surfaceRaised,
        borderRadius: StrideRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            PixelAsset.skill(icon),
            const SizedBox(width: StrideSpace.iconLabelGap),
          ],
          Text(
            label.toUpperCase(),
            style: StrideType.compactLabel.copyWith(
              color: StrideColors.forSkill(skill),
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ],
      ),
    );
  }
}

/// An outlined uppercase capsule stating a condition — `REQUIRES FORAGING 1`,
/// `NO TOOL NEEDED`.
///
/// **Outlined, never filled.** It states a fact; it is not a control, and a
/// filled capsule beside a real button would read as a second one.
class RequirementGate extends StatelessWidget {
  const RequirementGate({super.key, required this.label, this.unmet = false});

  final String label;

  /// True when the stated condition is currently FAILING — the skill level the
  /// player does not have, the tool that is not equipped.
  ///
  /// The treatment is primary-ink type in the same outlined capsule, and that
  /// is deliberate restraint, not timidity. The palette has **no** warning or
  /// error colour, by written decision (`StrideColors` — a warning hue is how
  /// an unrequested pressure system acquires a colour), and this capsule may
  /// not fill (a filled capsule beside a real button reads as a second one, per
  /// the class doc above). Within those two rules the available emphasis is
  /// ink: a failing gate is the brightest text in its row while its met peers
  /// stay quiet, and the label itself states the concrete failure.
  final bool unmet;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: StrideColors.borderDefault),
      borderRadius: StrideRadius.gate,
    ),
    // Padding rather than a fixed 22 dp box with `Container(alignment:)`.
    //
    // Two things were wrong with that. `Container`'s alignment expands to the
    // incoming constraints, and inside a `Wrap` those are the full line width —
    // so each gate was silently a full-width capsule and the `Wrap`'s `spacing`
    // had nothing to space. And the 22 was a fixed height around type that
    // grows with the text scaler. Padding shrink-wraps on both axes and derives
    // the height from the line box, which is the same result at scale 1.0 and a
    // correct one above it.
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: StrideSpace.s8,
        vertical: 5,
      ),
      child: Text(
        label.toUpperCase(),
        style: unmet
            ? StrideType.gateLabel.copyWith(color: StrideColors.textPrimary)
            : StrideType.gateLabel,
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    ),
  );
}

/// The primary action control.
///
/// Disabled rather than hidden when the action cannot run: the cost stays
/// visible, so the player can see what they are walking toward.
class StrideButton extends StatelessWidget {
  const StrideButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.subLabel,
  }) : secondary = false;

  /// A **utility** control, not the screen's game action.
  ///
  /// Shorter, quieter, and shrink-wrapped rather than stretched. `Sync steps`
  /// is the case this exists for: the owner's device review found it reading as
  /// more important than `Gather`, which is the actual game action — a
  /// full-width filled control at the same height and fill as the one that
  /// spends steps and yields loot.
  ///
  /// Demotion is by **size, weight and width**, not by hue: the palette has one
  /// accent and `ART_DIRECTION.md` L-16 reserves it for walking and steps, so
  /// there is no "secondary colour" available and inventing one would be a
  /// palette change smuggled in as a layout fix.
  const StrideButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
  }) : subLabel = null,
       secondary = true;

  final String label;

  /// Null disables the control.
  final VoidCallback? onPressed;

  /// A `micro` line beneath the label — the shortfall, usually.
  final String? subLabel;

  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Widget body = Container(
      // Minimums. The label is composed — `Gather — 9,999,999 steps` at an
      // enlarged text scale is a real string — so a fixed box is the D-01
      // shape again, and the sub-label variant was a second magic number
      // (56) derived from the first.
      constraints: BoxConstraints(
        minHeight: secondary
            ? StrideGeometry.buttonHeightSecondary
            : subLabel == null
            ? StrideGeometry.buttonHeight
            : StrideGeometry.buttonHeight + 12,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: secondary ? StrideSpace.s10 : StrideSpace.s12,
        vertical: secondary ? StrideSpace.s4 : StrideSpace.s6,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: !enabled
            ? StrideColors.surfaceBlock
            // One rung down the surface ladder from the primary control, which
            // is the only level that reads as *raised*.
            : secondary
            ? StrideColors.surfaceBlock
            : StrideColors.surfaceRaised,
        border: secondary
            ? Border.all(color: StrideColors.borderDefault)
            : null,
        borderRadius: StrideRadius.inner,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AdaptiveText(
            label,
            style: secondary
                ? StrideType.buttonLabelSecondary
                : StrideType.buttonLabel,
            color: enabled ? null : StrideColors.textMuted,
            textAlign: TextAlign.center,
          ),
          if (subLabel case final String s) ...<Widget>[
            const SizedBox(height: StrideSpace.s2),
            AdaptiveText(
              s,
              style: StrideType.micro,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );

    // Semantics carries the button role and its enabled state, because the
    // control is a plain GestureDetector — there is no Material widget here to
    // supply either, and a screen reader would otherwise announce a bare label.
    return Semantics(
      button: true,
      enabled: enabled,
      label: subLabel == null ? label : '$label. $subLabel',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        // A secondary control shrink-wraps; a primary one fills its column.
        // Width is half of what makes the primary action read as primary.
        child: secondary
            ? Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: body,
              )
            : body,
      ),
    );
  }
}
