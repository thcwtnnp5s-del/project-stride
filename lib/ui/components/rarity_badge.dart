/// The rarity word, as a small pill and as a bare label.
///
/// **The word is the point.** The ink beside it is a second channel, not the
/// channel: the owner's direction is that a player must be able to read *Rare*,
/// *Epic*, *Legendary* without separating five hues. So this widget always
/// renders text, and the colour rides along on it.
///
/// Null rarity renders **nothing** — a zero-size box, not a placeholder and not
/// a default rank. A null on a session projection means the content pack has no
/// definition for the item (`stride_session.dart`), and inventing `UNCOMMON`
/// there would make a content fault look like an authored choice
/// (`rarity_style.dart`, `RarityStyle.maybe`).
library;

import 'package:flutter/widgets.dart';
import 'package:stride_core/stride_core.dart' show Rarity;

import '../theme/rarity_style.dart';
import '../theme/stride_metrics.dart';
import '../theme/stride_typography.dart';
import 'adaptive_text.dart';

/// `RARE` — the rarity word in its own ink on a faint plate of its own accent.
///
/// Sized and spaced like [RequirementGate], which is the app's existing "a
/// short uppercase capsule stating a fact" form, so a rarity does not arrive as
/// a new kind of object. It is **filled and not outlined**, which is the one
/// difference: a gate states a condition the player can act on and an outline
/// keeps it from reading as a control; a rarity states what a thing *is*, and
/// the faint plate is what lets a dark accent be seen at all at 10 px.
class RarityBadge extends StatelessWidget {
  const RarityBadge({super.key, required this.rarity}) : _plated = true;

  /// The word alone, with no plate and no padding, shrinking to fit.
  ///
  /// For the surfaces measured too narrow for the pill: the equipped-slot
  /// columns, which are a third of a 320 dp card each. Uses [AdaptiveText], so
  /// in a bounded box it steps down rather than clipping — `UNCOMMON` is the
  /// longest of the five and it is the one that decides these layouts.
  const RarityBadge.compact({super.key, required this.rarity})
    : _plated = false;

  /// Null renders nothing at all.
  final Rarity? rarity;

  final bool _plated;

  /// The floor the compact form shrinks to. Higher than [AdaptiveText]'s
  /// default because this type is already the smallest role in the app —
  /// [StrideType.compactLabel] is 9.5 px, and 0.85 of it is 8.1. Below that the
  /// word stops being readable, which would defeat the whole reason it is here.
  static const double compactFloor = 0.85;

  @override
  Widget build(BuildContext context) {
    final RarityStyle? style = RarityStyle.maybe(rarity);
    if (style == null) return const SizedBox.shrink();

    if (!_plated) {
      return AdaptiveText(
        style.badgeLabel,
        style: StrideType.compactLabel,
        color: style.ink,
        minScale: compactFloor,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.accent,
        borderRadius: StrideRadius.gate,
      ),
      // Padding, never a fixed height: the label grows with the text scaler and
      // a fixed capsule around growing type is the D-01 shape
      // (`adaptive_text.dart`). Same reasoning, same numbers as
      // [RequirementGate].
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StrideSpace.s6,
          vertical: 2,
        ),
        child: Text(
          style.badgeLabel,
          style: StrideType.gateLabel.copyWith(color: style.ink),
          maxLines: 1,
        ),
      ),
    );
  }
}
