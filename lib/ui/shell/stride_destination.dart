/// The six navigation destinations.
///
/// The set and its order are fixed by `DECISIONS/0004` §5 and are not the
/// designer's to change. There is no seventh tab and no combat tab — combat is a
/// modal.
///
/// ## All six are built as of Playable Phase 2
///
/// Skills and Craft were the last two, and the reasoning below is preserved
/// rather than deleted because it is the argument that would have to be made
/// again the next time a destination ships ahead of its screen. [enabled]
/// stays — it is what made the wait honest, and it is what would make the next
/// one honest too.
///
/// ## Why the unbuilt ones were shown disabled rather than hidden
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
  adventure('Adventure', PixelIcons.navAdventure, enabled: true),
  character('Character', PixelIcons.navCharacter, enabled: true),
  skills('Skills', PixelIcons.navSkills, enabled: true),
  inventory('Inventory', PixelIcons.navInventory, enabled: true),
  craft('Craft', PixelIcons.navCraft, enabled: true),
  world('World', PixelIcons.navWorld, enabled: true);

  const StrideDestination(this.label, this.glyph, {this.enabled = false});

  final String label;

  /// The tab's silhouette — **one glyph per destination, both states**.
  ///
  /// There used to be a second, brighter `_hi` variant per tab. It is retired
  /// (EPO03, `DIR-15_mobile_ux.md` §2, Q-26): the active tab is now a raised
  /// lit plate, and a brightened glyph on top of that says the same thing a
  /// second time, more weakly. `pixel_icons.dart` records the measurement
  /// behind that — a nav glyph belongs to the type ladder, its backing to the
  /// chrome ceiling, and no authored pair ever separated as well as the plate
  /// does.
  final String glyph;

  /// Whether this destination has a screen behind it.
  ///
  /// True for all six since Playable Phase 2. Kept rather than removed: it is
  /// the mechanism that prevents a live-looking tab that does nothing, and
  /// deleting it would mean re-inventing it the next time a destination is
  /// added ahead of its screen.
  final bool enabled;
}
