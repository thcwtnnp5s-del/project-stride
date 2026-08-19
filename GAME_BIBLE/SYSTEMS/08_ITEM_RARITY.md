# Item Rarity

**Status:** Implementation contract for World & Reward Depth 01. The **ranks,
their order and their colours** are owner direction and are not provisional.
Which rank each item carries is content, and is provisional like every other
balance figure.
**Recorded in:** `DECISIONS/0021_REPEATABLE_ENCOUNTERS_AND_RARITY.md` §4.
**Canonical for:** the rarity vocabulary and the authored table.
Item categories, slots and equipment semantics stay canonical in
`06_INVENTORY_AND_EQUIPMENT_SYSTEM.md`; the enemies and recipes that produce
these items stay canonical in `GAME_BIBLE/COMBAT/02_COMBAT_SLICE_01.md`.

## What rarity is

One word on an item saying how hard it was to come by. It is **authored**, not
rolled: an item's rank is written in `items.json` beside its name and does not
change while the player holds it.

Rarity exists so that a reward reads as a reward. A victory panel listing "Wolf
Pelt" and "Frost Lynx Pelt" in identical grey says nothing about which one was
worth the walk; the same two lines in green and blue say it before the player
has read either word.

## What rarity must never become

**No mechanical consequence, ever, without a new decision.** No random rolls,
no affixes, no sockets, no item level, no gear score, and no stat derived from
the rank. A Rare sword hits for exactly the `power` its definition gives it and
would hit for the same figure if it were relabelled Common tomorrow.

This is a line, not a caution. Procedural gear is out of scope for this
milestone by name, and the whole appeal of a rarity ladder is that it invites
one. Rarity is a *presentation* property that the inventory, the craft list,
the encounter card and the victory panel read; it is not an input to any rule
in `stride_core`, and nothing in the engine consults it.

## The ranks

Ascending. `Rarity.rank` is 0–4 and `Rarity.wireName` is the lowercase enum
name, which is the only spelling `items.json` accepts.

| Rank | Name | Wire | Colour | What earns it |
|---:|---|---|---|---|
| 0 | Uncommon | `uncommon` | grey | Tier-0 gathered material — picked up in handfuls, no tool required |
| 1 | Common | `common` | green | Processed, cooked, granted, or gathered behind a real requirement |
| 2 | Rare | `rare` | blue | Bronze-tier equipment, and the materials only combat yields |
| 3 | Epic | `epic` | purple | The end of a chain: a boss token, the best armour authored |
| 4 | Legendary | `legendary` | orange | **Nothing yet** — reserved |

### The caveat — raised, and closed by the owner

**Uncommon sits below Common.** That is the reverse of the convention most RPGs
use, where Common is the floor and Uncommon the first step up.

It was implemented exactly as the owner's rarity list wrote it — those names,
in that order, with those colours — and flagged rather than quietly
"corrected", because an implementation that fixed it would have made a design
decision while pretending to fix a typo (`RULES.md` G-3).

✅ **RESOLVED — owner ruling, 2026-08-19:** the order and colour mapping are
**intentional and canonical**: Uncommon = gray → Common = green → Rare = blue →
Epic = purple → Legendary = orange, ascending in exactly this order. This is
Stride's own ladder, not a transcription slip, and it is no longer open to
"conventional" correction. The flag in `Rarity`'s doc comment,
`rarity_test.dart` and the milestone record predates this ruling; this
document is the canonical answer they point at.

Legendary is deliberately empty. The enum declares it, the UI style table
covers it, and `production_content_test.dart` asserts that no shipped item
carries it — so the rank is ready before content needs it, and adding the first
Legendary item is a visible edit rather than a quiet one.

## The authored table

Provisional. The rationale throughout is **tier of effort to obtain**, not
power.

| Rarity | Items |
|---|---|
| Uncommon | `oak_log` · `copper_ore` · `tin_ore` · `meadow_herb` · `duskcap` |
| Common | `pine_log` · `rime_blossom` · `hollow_root` · `wolf_pelt` · `oak_handle` · `bronze_ingot` · `pine_plank` · `training_sword` · `training_axe` · `training_pickaxe` · `traveler_tunic` · `herb_broth` · `duskcap_skewer` |
| Rare | `lynx_pelt` · `bronze_sword` · `bronze_axe` · `bronze_pickaxe` · `bronze_chestplate` · `wolfhide_jerkin` · `hearty_stew` · `frostbloom_tea` |
| Epic | `hollow_sigil` · `frostlined_jerkin` |
| Legendary | *(none)* |

Two things in that table are worth naming:

- **The starting loadout is Common, not Uncommon.** It is granted rather than
  gathered, and a player's first sword sitting a rank below the grass they pick
  would read as a joke at their expense.
- **`wolf_pelt` is Common and `lynx_pelt` is Rare** even though both come from
  a single fight. The wolf is the first enemy in the game and the lynx needs
  bronze and an alpine crossing; the gap between them is the gap the ranks are
  there to show.

## How it is enforced

`rarity` is a **required** field in `items.json`. The loader refuses an item
with no `rarity` and an item with an unrecognised one, naming the field and
listing the five allowed values in the suggestion
(`missing_rarity.json`, `unknown_rarity.json`).

That makes "every item has a valid rarity" true **by construction** rather than
by a test somebody has to remember to write: an item without one never reaches
a `ContentRegistry`, so no surface can be handed an item whose rank is a guess.
A default would have answered the question for an author who never asked it,
and a wrong answer would be indistinguishable from a considered one.

## Where it is read

`Rarity` lives in `stride_core`'s content layer, so it is testable without a
widget, and the session projects it onto everything a screen colours:

```text
InventoryEntry.rarity          the inventory grid
EquippedSummary.rarity         the Character and Inventory equipped lines
RecipeOption.outputRarity      the Craft list — what you are working towards
DropPreview.rarity             the encounter card's drop preview
RewardLine.rarity              the victory panel
```

Each is nullable, and null means only that the content pack has no definition
for that id — a content fault, reported rather than defaulted. It is never a
rarity an author chose, because an author who chose nothing cannot load.

**The UI has one rarity style table** (`lib/ui/theme/rarity_style.dart`). One
enum, one colour per rank, one place to change it. A second table is how a
Rare item ends up blue on one screen and purple on another.
