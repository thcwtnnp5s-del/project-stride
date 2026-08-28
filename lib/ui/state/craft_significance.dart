/// How much a finished craft matters — derived from what was actually made,
/// never hardcoded per item (GAME_FEEL_CHARACTER_PRESENTATION_01, item 1).
///
/// The owner's finding was that finishing an item mostly reads as "it got
/// added to inventory": every completion, from a tenth plank to a first
/// Bronze Sword, ended the same size. The answer is not a bigger celebration
/// for everything — a modal for every trivial plank is a nag — but a
/// **significance the presentation derives from real content**:
///
/// | Significance | Derived from |
/// |---|---|
/// | major | output rarity ≥ Epic |
/// | medium (held) | finished equipment/tool, a level gained anywhere in the queue, a Rare output, or the first-ever craft of an Uncommon+ output |
/// | minor (transient) | everything else |
///
/// One pure function over report facts. No per-item branch can exist here,
/// because no item identity is an input. Honest by construction: nothing
/// here loops, expires, or manufactures excitement — the inputs are the
/// player's own committed results (`RULES.md` P-5, P-6).
library;

import 'package:stride_core/stride_core.dart' show Rarity;

enum CraftSignificance { minor, medium, major }

/// Derives the significance of a finished craft queue.
///
/// [firstCraft] is the presentation-side memory's answer (see
/// `craft_memory.dart`) — it can be lost with a reinstall, which is why the
/// elevation it buys never makes a lifetime factual claim in copy; it only
/// presents the moment more strongly.
CraftSignificance craftSignificanceOf({
  required Rarity? outputRarity,
  required bool isEquipment,
  required bool levelledUp,
  required bool firstCraft,
}) {
  final int rank = outputRarity?.rank ?? 0;
  if (rank >= Rarity.epic.rank) return CraftSignificance.major;
  if (isEquipment ||
      levelledUp ||
      outputRarity == Rarity.rare ||
      (firstCraft && rank >= Rarity.uncommon.rank)) {
    return CraftSignificance.medium;
  }
  return CraftSignificance.minor;
}
