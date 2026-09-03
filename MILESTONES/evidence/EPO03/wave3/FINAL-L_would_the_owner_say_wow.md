# FINAL-L — Would the owner say "wow"?

**Reviewer:** FINAL-L (adversarial, built none of this)
**Date:** 2026-09-03
**Before:** `59c4723` (the build the owner rejected)
**After:** HEAD, branch `fable5-executive-production-overhaul-03`
**Generations spent:** 0
**Files changed:** this report only

The owner's bar, verbatim: *"THE NEXT IPHONE BUILD SHOULD PRODUCE: 'THIS FEELS
LIKE A MUCH MORE FINISHED GAME.' Not: 'Looks a little cleaner.'"* And the round
must not close if the phone comparison looks incremental.

I judged what the eye sees, side by side, screen by screen. I did not read the
craft ledger, the commit list, or the wave reports first, and I have not
weighted anything by how much work went into it.

---

## Verdict

**BETTER BUT NOT WOW.**

There are two surfaces here that are genuinely transformed and would carry a
"wow" on their own — the skill roadmap and the recipe book. There are two that
are unchanged. And there are three where the shipping golden is *visibly worse
than the build the owner already rejected*. That last group is the problem. The
owner will not average. He will open Character, or start a fight, and the
sentence in his head will be "you broke this", not "this feels finished".

The round should not close on this comparison.

---

## Per-surface

| Surface | Verdict | What the eye sees |
|---|---|---|
| Skill detail (Mining) | **SUBSTANTIAL** | The single strongest thing in the round. Before: a grey stack of identical text rows, LV 1–6, indistinguishable. After: an illustrated milestone ladder — a vertical rail, a carved tower per tier that grows as it climbs, an ore icon beside every unlock, a "LV 1 / YOU ARE HERE" marker, and a yield line under each. This reads as a designed progression screen rather than a list widget. |
| Recipe book (Craft) | **SUBSTANTIAL** | A screen that did not exist. Wax-seal level medallions on a leather ground, grouped "SMITHING · LEVELS 1–3 / 4–6", locked entries dimmed but *legible* so you can see what you are walking toward. This is the one place the game looks authored rather than assembled. |
| World atlas (whole map) | **SUBSTANTIAL** | Zoomed out, this is a different world. The west is rock outcrop, moor grass and boulder field instead of repeated shrub blobs; a keep now sits on a hill above the treeline; the north gains a real glacier cliff face; and the entire south coast — previously a muddy dark-green mass ending on a hard diagonal water edge — is repainted as a sand spit, headland, tidal shallows and a barrow mouth in the southwest. Caveat below. |
| World screen (in game) | **INCREMENTAL** | The map is cropped to Haven's Rest, so most of the atlas work is off-screen. What is visible is the new keep top-left and denser trees. And the destination sheet is now a one-line peek strip — the before showed WORK · Notice Board · 5 open and both gathering sites at rest; the after shows "Settlement · You are here" and nothing else. Prettier map, thinner screen. |
| Craft overview | **INCREMENTAL** | Real gains: category icons above the filter tabs, a green "Ready ×1", a bookmark Track affordance, tighter station tiles. Real losses: the ×1/×5/×10 batch chips and the "up to ×2" hint are gone from view. Net, a cleaner version of the same screen. This is the literal definition of "looks a little cleaner". |
| Skills list | **UNCHANGED** | I compared these pixel for pixel. Same rows, same icons, same spacing, same colours. Only the XP numbers differ. A tab the owner will open in the first ten seconds is untouched. |
| Adventure | **INCREMENTAL, arguably worse** | The Expedition Kit card lost its containing panel and is now flat rules on the page. Serif headers were added. But "MEADOW PATCH" now wraps to two lines, its subtitle wraps to two more, and Mill Garden's requirement wraps to three — where before each entry was one tidy line inside a card. More typographic ambition, less legible result. |
| Inventory | **INCREMENTAL, arguably worse** | Before: an ornate bordered gear panel, corner brackets, each slot showing icon + item name + stat (Training Sword / ATK 3). After: the border is gone, and the three slots are flat empty boxes with a silhouette glyph. Serif "Materials"/"Equipment" headers with rules are an improvement; the gear panel is a clear step down. |
| Character | **WORSE** | See weakest link. |
| Combat stage | **MIXED, with a hole in it** | Genuinely better: a framed stage with corner ornaments, an HP header row reading Traveler 40/40 · TURN 1 · 20/20 Forest Wolf, and coloured intent on the buttons (red Attack, blue Brace). Genuinely worse: roughly a fifth of the screen between the log line and the command rail is an empty brown void. I confirmed this is not a golden artefact — `combat_screen.dart` renders `SizedBox.expand()` inside an `Expanded` when `_logOpen` is false, which is the default state at turn 1. Also, "Retreat — nothing is lost" has been demoted from a button to right-aligned grey text. |
| Combat victory | **SUBSTANTIAL (small)** | A new reward card — VICTORY / Forest Wolf falls / +30 XP / Wolf Pelt ×1 / Continue. Clean and well-typeset. It is a modal over a fully black screen, so it lands as a good component rather than a finished moment. |

### The atlas caveat

The atlas repaint is the round's largest body of visible work and the owner will
mostly not see it. The World screen crops tight to Haven's Rest. Unless he pinches
out to the coast and the western moor, "we repainted the world" reads to him as
"you moved a castle". This is not an argument against the work — it is an argument
that the round has no screen that *shows* it.

---

## Weakest link

**Character.**

This is the one that will produce "you still haven't fixed X", and it is worse
than that — it is the one that will produce "this used to look better".

Before, Character opened on a framed portrait card with corner brackets, and
three labelled gear slots underneath showing a sword, a tunic, and one empty
box, each captioned. It looked like a character sheet.

After: the frame is gone. The portrait floats in a plain box. The three gear
slots are stacked in a column at the far right as empty outlined squares, and
then the *same three slots are restated* immediately below as plain text rows —
"WEAPON Empty / ARMOUR Empty / TOOL Empty". The same nothing, said twice, in two
different visual languages. Under the name sits a decorative divider line that
belongs to no section. "Step Tracker" is clipped at the bottom edge.

Combat's empty void is the close runner-up and is cheaper to fix. But Character
is the screen the owner taps to see *himself*, and it is currently the least
finished-looking surface in the game.

---

## What would move this to WOW

Not more sprites. Three repairs, all presentation-only:

1. Rebuild the Character gear block — one representation of the slots, restore
   the frame, kill the duplicate text rows and the orphan divider.
2. Fill or collapse the combat dead zone; give the round log a resting state
   that occupies its space.
3. Give the Skills list the treatment the skill *detail* already got. It is the
   most-visited screen in the game and it is byte-identical to the rejected build.

Do those and the two genuinely transformed screens stop being exceptions and
start being the standard. Ship as-is and the honest answer to the owner's
question is "looks a little cleaner — and the character screen looks worse."
