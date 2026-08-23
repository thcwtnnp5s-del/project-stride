# Item Rarity

**Status:** Implementation contract for World & Reward Depth 01, **re-based by the Playable Polish 01 correction pass (2026-08-23)**. The **ranks,
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

**Rarity answers "how exceptional is this particular item?"** Material or
equipment *tier* — Training, Bronze, and whatever comes after — answers
"where is this in progression?" and is a separate axis. A stronger material
is not automatically a higher rarity: standard Bronze is Uncommon, and a
future Iron may be Common or Uncommon too. Rarity is emotional register;
tier is progression.

| Rank | Name | Wire | Colour | What earns it |
|---:|---|---|---|---|
| 0 | Common | `common` | neutral (warm grey) | Ordinary and expected: starter gear, everyday gathered and processed materials, the first kitchen's food |
| 1 | Uncommon | `uncommon` | green | A useful, meaningful improvement: standard Bronze equipment, food that heals properly, a basic enemy's material |
| 2 | Rare | `rare` | blue | Genuinely exciting: signatures, enhanced equipment with a passive, the reward of a real contract or enemy |
| 3 | Epic | `epic` | purple | "I really needed this": a boss token, the best armour authored, a difficult reward |
| 4 | Legendary | `legendary` | orange/gold | "Holy cow" — exceptional signature or world items; **nothing yet**, reserved; never required for critical progression |

### The order — ruled twice, and this is the ruling that stands

The first implementation (2026-08-19) put **Uncommon below Common**, as the
owner's original list was written, and was ruled intentional at the time.
On physical review of Playable Polish 01 (2026-08-23) the owner found that
ladder made "Rare" meaningless — ordinary Bronze gear was Rare — and
re-based rarity onto the conventional register above, with the explicit
instruction that progression tier and rarity be separate concepts. **This
document supersedes the 2026-08-19 ruling.** The enum, the style table, the
tests and the authored table below were all changed together, so no surface
carries the old order.

The palette did not move: the same two hexes that once sat on the other two
ranks sit on these — neutral grey is now Common and moss green is now
Uncommon (`lib/ui/theme/stride_colors.dart`).

Legendary is deliberately empty. The enum declares it, the UI style table
covers it, and `production_content_test.dart` asserts that no shipped item
carries it — so the rank is ready before content needs it, and adding the
first Legendary item is a visible edit rather than a quiet one. The emotional
target for an eventual Legendary drop is roughly 1 in 1,000 of an *optional*
roll; it must never gate critical progression (`RULES.md` P-10).

## The authored table

Provisional. The rationale throughout is **how exceptional**, never power,
and never tier.

| Rarity | Items |
|---|---|
| Common | `training_sword` · `training_axe` · `training_pickaxe` · `traveler_tunic` · `oak_log` · `pine_log` · `copper_ore` · `tin_ore` · `meadow_herb` · `duskcap` · `rime_blossom` · `hollow_root` · `wolf_pelt` · `boar_hide` · `boar_tusk` · `scrap_metal` · `heat_scale` · `ram_wool` · `ram_horn` · `oak_handle` · `oak_plank` · `bronze_ingot` · `pine_plank` · `herb_broth` · `duskcap_skewer` |
| Uncommon | `bronze_sword` · `bronze_axe` · `bronze_pickaxe` · `bronze_chestplate` · `lynx_pelt` · `hearty_stew` · `frostbloom_tea` |
| Rare | `wolfhide_jerkin` · `reinforced_pickaxe` · `bear_pelt` · `pristine_wolf_fang` · `great_tusk` · `goblin_toolhead` · `ember_core` · `pristine_horn` |
| Epic | `hollow_sigil` · `frostlined_jerkin` · `frost_claw` |
| Legendary | *(none)* |

Three things in that table are worth naming:

- **The starting loadout is Common** — the floor, as a first sword should
  be — and so is everything a first walk gathers.
- **Bronze is Uncommon, not Rare.** It is the first real improvement, and it
  is *standard*: every player makes it. Rare is kept for what not every player
  will have.
- **A passive makes a piece Rare** (the Wolfhide Jerkin, the Reinforced
  Pickaxe): the enhancement is the exceptional thing, not the material.

## Presentation follows the register

Common results are low-key (the plain beat, no frame); Uncommon takes the
green ink and a modest frame; Rare earns a noticeable payoff in the reward
layer; Epic is elevated; Legendary will deserve a major beat when it
exists. Fewer, more meaningful peaks — never casino motion, streaks, timers
or FOMO (`RULES.md` P-5, P-6).

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
