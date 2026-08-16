/// The walking mark, and the rule for which of its two colours to use.
///
/// The approved renders show the boot glyph in teal three times (the header, the
/// walked figure, the walked tile) and muted three times (`90 per gather`,
/// `4,500 steps to Level 9` on two screens). Visual QA flagged that correctly as
/// "the app's single most important semantic mark, presented in two colours
/// across six instances with no discoverable rule".
///
/// A rule *is* recoverable from the usage, and under it all six existing
/// instances are correct:
///
/// > **Teal = steps the player has actually walked** — a stock or a flow they
/// > own. **Muted = steps as a unit of measure** — a price, a distance, a
/// > requirement.
///
/// The defect was never the two colours; it was that nobody wrote the rule down.
/// So the caller passes the *semantics* and this widget picks the asset. A call
/// site cannot choose a colour, which is what stops the distinction eroding.
///
/// This is a proposal, not canon — the owner may equally rule that one mark in
/// one colour is worth more than the distinction. If so, this is one file to
/// change.
library;

import 'package:flutter/widgets.dart';

import '../icons/pixel_icons.dart';
import 'pixel_asset.dart';

enum WalkingRole {
  /// Steps the player owns — banked, granted, walked. Teal.
  stock,

  /// Steps as a unit — a cost, a requirement, a distance. Muted.
  unit,
}

class WalkingGlyph extends StatelessWidget {
  const WalkingGlyph({super.key, required this.role, this.scale = 2});

  final WalkingRole role;
  final int scale;

  @override
  Widget build(BuildContext context) => PixelAsset.glyph(switch (role) {
    WalkingRole.stock => PixelIcons.stepsGlyph,
    WalkingRole.unit => PixelIcons.stepsGlyphMuted,
  }, scale: scale);
}
