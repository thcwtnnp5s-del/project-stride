/// The small data-display primitives: the label/value tile, the skill chip, the
/// requirement gate, and the primary button.
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show ContentId;

import '../icons/pixel_icons.dart';
import '../theme/stride_colors.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
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

  /// A glyph rendered immediately before the value — the walking mark, usually.
  final Widget? leading;

  final Color? valueColor;

  @override
  Widget build(BuildContext context) => SurfaceBlock(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: StrideType.microLabel,
          maxLines: 1,
          overflow: TextOverflow.clip,
        ),
        const SizedBox(height: StrideSpace.s4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (leading != null) ...<Widget>[
              leading!,
              const SizedBox(width: StrideSpace.iconLabelGap),
            ],
            // Shrink-to-fit rather than clip or overflow.
            //
            // These tiles sit two- and three-across inside cards, so their
            // width falls as the phone narrows while the numeral inside them
            // grows with the player's progress. At 320 dp a two-across tile
            // gives a 22 px figure about 53 logical px, which `24 / 100` does
            // not fit in — and the failure mode without this is a RenderFlex
            // overflow, which is a yellow stripe on a shipping screen.
            //
            // `scaleDown` only ever reduces, so a figure that fits renders at
            // exactly its designed size and the type scale is unchanged on
            // every device where it fits. This is chrome, not pixel content —
            // L-18's integer-scale rule governs sprites, and no sprite goes
            // through here.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: valueColor == null
                      ? StrideType.numericValue
                      : StrideType.numericValue.copyWith(color: valueColor),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ],
        ),
        if (unit case final String u) ...<Widget>[
          const SizedBox(height: StrideSpace.s2),
          Text(u, style: StrideType.micro, maxLines: 2),
        ],
      ],
    ),
  );
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
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 9),
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
  const RequirementGate({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: StrideSpace.s8),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: StrideColors.borderDefault),
      borderRadius: StrideRadius.gate,
    ),
    child: Text(
      label.toUpperCase(),
      style: StrideType.gateLabel,
      maxLines: 1,
      overflow: TextOverflow.clip,
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
  });

  final String label;

  /// Null disables the control.
  final VoidCallback? onPressed;

  /// A `micro` line beneath the label — the shortfall, usually.
  final String? subLabel;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final Widget body = Container(
      height: subLabel == null ? StrideGeometry.buttonHeight : 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? StrideColors.surfaceRaised : StrideColors.surfaceBlock,
        borderRadius: StrideRadius.inner,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: enabled
                ? StrideType.buttonLabel
                : StrideType.buttonLabel.copyWith(
                    color: StrideColors.textMuted,
                  ),
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
          ),
          if (subLabel case final String s) ...<Widget>[
            const SizedBox(height: StrideSpace.s2),
            Text(s, style: StrideType.micro, maxLines: 1),
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
        child: body,
      ),
    );
  }
}
