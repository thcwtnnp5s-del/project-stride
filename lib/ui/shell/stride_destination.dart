/// The six navigation destinations.
///
/// The set and its order are fixed by `DECISIONS/0004` §5 and are not the
/// designer's to change. There is no seventh tab and no combat tab — combat is a
/// modal.
///
/// ## Why the unbuilt three are shown disabled rather than hidden
///
/// "Least misleading" is a claim about what a viewer concludes, so compare the
/// false belief each option produces.
///
/// **Hiding them** produces *"Stride is a three-section app."* That is a false
/// statement about the product's architecture, made by the most load-bearing
/// chrome on screen, and nothing anywhere in the demo contradicts it. It also
/// changes the bar's geometry, so the six-tab layout the approved renders lock —
/// including its 320 dp touch-target risk — never gets exercised until the
/// moment three tabs are added back.
///
/// **Showing them disabled** produces *"Stride has six sections and three
/// aren't built yet."* That is true, and it is the belief the viewer would form
/// on the first tap anyway.
///
/// The genuinely misleading third option — live-looking tabs that do nothing —
/// is the one to avoid, and [enabled] is what prevents it.
library;

import '../icons/pixel_icons.dart';

enum StrideDestination {
  adventure(
    'Adventure',
    PixelIcons.navAdventure,
    PixelIcons.navAdventureActive,
    enabled: true,
  ),
  character(
    'Character',
    PixelIcons.navCharacter,
    PixelIcons.navCharacterActive,
    enabled: true,
  ),
  skills('Skills', PixelIcons.navSkills, PixelIcons.navSkills),
  inventory(
    'Inventory',
    PixelIcons.navInventory,
    PixelIcons.navInventoryActive,
    enabled: true,
  ),
  craft('Craft', PixelIcons.navCraft, PixelIcons.navCraft),
  world('World', PixelIcons.navWorld, PixelIcons.navWorldActive, enabled: true);

  const StrideDestination(
    this.label,
    this.glyph,
    this.glyphActive, {
    this.enabled = false,
  });

  final String label;
  final String glyph;

  /// The brighter variant, used only when this destination is selected. A
  /// disabled destination never becomes active, so its two values are the same
  /// asset.
  final String glyphActive;

  /// Whether this destination has a Phase 1 screen behind it.
  final bool enabled;
}
