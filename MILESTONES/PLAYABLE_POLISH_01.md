# Playable Polish 01 — the record

**Branch:** `playable-phase-2-multiregion`, on top of Playable Experience
Refinement 01 (`1880d5d`). **Status:** implementation complete, not pushed,
awaiting the owner's review and device test.
**Brief:** the owner's polish pass of 2026-08-23, in its own priority order —
animation correctness, resource differentiation, Goal Board and reward
overlay, gear stats, general UI, safe reset, then bounded combat and
systems work. A refinement pass, not an expansion: no new content, no new
mechanic except the owner-directed reset, no economy re-basing except by
the owner's own hand.

## The commits

| Commit | What |
|---|---|
| `f9321c9` | Art: the miner faces the seam; three seams read as three metals |
| `2cd2d35` | Presentation: the reward layer; every MEDIUM/MAJOR payoff rises above its surface; the Goal Board refined |
| `eeb26fc` | Gear: evaluable at a glance in the bag and on the bench; tile rows one height; source count off the play surface |
| `39de384` | Accounting: the playtest reset (`DECISIONS/0025`), state v9 |
| `1e8dc1c` | Combat: the blow's quality recorded and said, arithmetic untouched |
| (this) | Docs: the record, open questions Q-09–Q-11, state v2.15 |

## §1 — Animation audit (Priority 0.1)

**Finding.** The record before this pass said "no frame repair was needed
for mining". The in-context harness (`test/stage_evidence_test.dart`)
disagreed: the ACTIVITY_FEEL_01 mining loop was a west-facing figure whose
strike landed **east**, behind his own back, and the stage had bent around
the fault (`worksEast`) by placing the seam east — so in context the
Traveler worked with his back to the ore, the pick landing behind his pack.
That is the "visually backward" the owner saw.

**Fix.** Re-authored through PixelLab (`animate_character` v3 on the
Traveler, west, start frame = the held-pick pose; two phrasings, one
accepted) — `mine3a`: pick low in front → raised → over the shoulder →
strike low in front. `worksEast` is false for every profession; the seam
sits west with every other prop. Before/after plates:
`GAME_BIBLE/ART/exploration/PLAYABLE_POLISH_01/qa/`.

**Audited and left alone**, each re-captured in context this round:
woodcutting (faces the stump, axe lands on it, backswing behind reads as
wind-up), foraging (kneels to the patch), smithing and cooking (work west
at the station; the ping-pong order stands), the combat attack and hit
(the Traveler lunges east into the enemy; impact on the enemy), the
single-gather one-shot. No locked resource plays a work loop (the gate from
the last pass stands; `mine_hardened_locked` capture).

## §2 — Ore seams (Priority 0.2)

The three PWRF01 props were one boulder with a swapped vein patch. Each is
now its own `create_image_pixen` generation under one prompt skeleton
(slate outcrop two-thirds of a figure high, loose stones, muted palette)
differing only in the material clause: **copper** warm orange-brown veins
in blue-grey slate; **tin** wide pale silver bands in darker slate;
**hardened copper** a denser, darker, blockier outcrop with thick dull
bronze bands and jutting crystals. Twelve generations over three rounds;
candidates, seeds, rejections and the pixen lesson ("veins of tin" gets
edge highlights; "WIDE SHINY bands … much lighter than the rock" gets a
metal) in the round README. Woodcutting and foraging props reviewed and
kept: stump-with-chips, meadow-with-basket and duskcap ring are already
distinct at a glance.

## §3–§4 — The reward layer and the Goal Board (Priority 0.3–0.4)

`lib/ui/components/reward_layer.dart`. A scrim over the surface, a framed
panel in the result's own ink with a top rule, the beats resolving once
(`StaggeredReveal`), held until Continue. Every MEDIUM and MAJOR result
rises in it: an order delivered / bounty claimed / contract complete
(eyebrow by type, the consumed goods named, the items as `RewardItemRow`s
with icon and rarity, EXPERIENCE, RECIPE LEARNED, RUMOR HEARD, the
`LevelUpCard`); a project stage (MEDIUM) and a completed project (MAJOR —
headline, the settlement's change, the permanent line); finished equipment
(rarity-framed, the stat delta, **Equip beside Continue**); a level gained
at a node or the bench; victory (`VICTORY · Forest Wolf falls`, EXPERIENCE,
REWARDS, knowledge, level, bounty lines) and defeat / retreat (plain frame,
`DRIVEN BACK · Retreated to … · Nothing was lost`). MINOR results stay
inline on their timers — a single gather, a component craft, a plain
contribution, an acceptance, a refusal.

`RewardRaise` lifts controller-driven results (craft, gather, combat) into
the layer after the frame that sees them, keyed on the report so a rebuild
raises nothing twice; without a Navigator (a bare harness) it draws the
panel inline so `combat_presentation_order_test` still proves the beats in
order. The combat log beneath the scrim no longer narrates the ending.

The board beneath: the open job is **one block** — a raised head, a rule,
the brief, the requirement chips, `REWARD` as a labelled group, **Deliver
/ Claim / Accept primary** beside Track; a finishable job's frame takes the
dim step accent; LOCKED rows mute their title and chip; the project tile's
stage is a pill, `About this project · more` replaces a glyph that is not
in every face, and Contribute is the filled control with the offer as its
sub-label.

Regression: `test/board_reward_layer_test.dart` (hands in Herbal Supplies
through the real app, expects the layer and that the board did not print
the result into itself; `BOARD_EVIDENCE_DIR` captures), `combat_victory`
golden regenerated.

## §5 — General polish (Priority 0.5)

Value tiles in a row share one height (the Character tab's COMBAT row read
as three different boxes). The step-source count leaves the Adventure sync
line and the held banner; its one home is the Character tab's Total walked
unit line. A screen-evidence harness (`test/screen_evidence_test.dart`,
`SCREEN_EVIDENCE_DIR`) drives the app into the telling states — Craft with
a gear recipe open, Inventory with equipment, Character's foot with the
playtest confirmation — so the pass could be *looked at* (M-06). Goldens
for Inventory and Character regenerated and reviewed.

## §6 — Gear stats (Priority 1)

`StrideSession.gearStatsOf(item)` — one projection for the bag and the
bench: slot, the stat (Attack / Defence; a tool is its kind and tier, since
the engine reads no tool power), the passives in player words (cold
weather, wilderness ready, the pickaxe bonus, what sites a tool works), the
worn item and its figure, and a verdict (UPGRADE / DOWNGRADE / SIDEGRADE /
EMPTY SLOT / EQUIPPED). The Inventory tile spends its reserved marker line
on it — `ATK 9 +6`, `DEF 2`, `TIER 0`; worn is the Unequip beneath — and
the equipped summary shows each slot's figure; the Craft detail carries
`GearStatsBlock` above the materials. The clipping detector caught
`PICKAXE T0` at 70 dp in a 68 dp cell, hence `TIER n`.
`test/gear_stats_test.dart` pins the verdicts and the wording.

## §7 — The playtest reset (Priority 2) — `DECISIONS/0025`

Delivered in full, including the fresh-start path, because the safety
argument held: `ResetPlaytest({freshStart})` moves the economy mark and
sets a walked baseline at the same point and **touches no counter, slice,
watermark or cursor**. Banked Steps and Total Walked start at zero; the
lifetime figure is named beside the reset one on the Character tab; with
freshStart the game returns to the new-game shape. State v9 adds
`epoch.walkedAtStart`. Proven in core and through the real session:
the same samples re-delivered after a reset — incrementally, by rescan,
across a relaunch — grant zero; new walking is credited exactly once;
refused mid-fight and mid-queue unless fresh. The controls are the last
block on the Character tab, each behind a two-line confirmation with one
filled control. **The owner chooses when.**

## §8–§10 — Bounded systems work (Priority 3)

- **§8 Combat variability.** The existing −1/0/+1 roll is now recorded on
  the strike events and said in the log (`A strong hit for 4`, `A glancing
  blow for 1`, `hits hard`, `grazes you`). No figure changed. Widening the
  roll and the D20 presentation are **Q-09**, with the engine seam named.
- **§9 Travel encounters.** No scaffolding added — the clean seam is
  named in **Q-11**.
- **§10 Bank cap and combat energy.** Deferred by the owner's own
  ordering. The concrete model, state and UI plan is **Q-10**: a third
  ledger counter (forfeited above the cap at grant time, `totalGranted`
  honest), energy derived from granted-since-mark and energy-spent on the
  ledger, a refusal code, pips in the step band; state v10; one session
  once the ADR exists.

## Verification

App **623**, `stride_core` **695**, `stride_health` **143**,
`stride_storage` **108** — all passing (the five cross-process lock probes
that timed out last pass ran green this time). `flutter analyze` clean
across the repository; core purity, single writer, origin privacy, UI
boundary guards clean; `package-art.js --check` clean; goldens
`combat_victory`, `phase1_inventory(_large)`, `phase1_character(_large)`
regenerated and reviewed. The `check-step-model` guard's note about
`test/combat_session_test.dart` predates this pass and was not touched.

**Nothing in the health adapters changed. No economy re-basing ran.** The
one schema change (v9) is asked for by name in `DECISIONS/0025`.

## Deferred, deliberately

- Q-09 (roll spread / D20), Q-10 (cap + energy), Q-11 (road encounters).
- The cook loop's bowl/implement relationship and the forge prop's
  perspective (cosmetic, from the last pass).
- Q-08 (two-source policy) still awaits the owner's device answer; the
  count is now on the Character tab only.

## Device acceptance — one thing at a time

1. Stonefall, select Copper: the Traveler faces the seam, the pick comes
   over his shoulder and lands on the rock in front of him. Tin is silver;
   Hardened is the dark dense lump.
2. Goal Board, open a job: one block, Deliver filled beside Track. Hand in
   an order: the board dims and the payoff rises; Continue returns you.
3. Finish a Bronze Sword: the reveal with `Attack 3 → 9`, Equip beside
   Continue.
4. Win a fight: `VICTORY · Forest Wolf falls` over the stage; lose one:
   `DRIVEN BACK`. Read the log's blow words during the round.
5. Inventory: `ATK 3`, `DEF 2`, `TIER 0` on the tiles; Craft › Bronze
   Sword: the gear block with UPGRADE +6.
6. Character › foot: **do not reset yet** unless you mean to. When you do:
   Reset walking baseline → confirm → Banked 0, Total walked 0, `lifetime
   471,…` beneath; relaunch; sync; nothing re-banks; walk; it banks once.

---

# Correction pass — 2026-08-23, from the owner's physical-device review

**Branch:** `playable-phase-2-multiregion`, on top of the published
`3dae9e8`. **Status:** implementation complete, not pushed. A correction and
refinement pass on this workstream, not a new milestone. The future
equipment / combat / crafting depth work (material tiers, weapon families,
Slash/Crush/Pierce, ammunition, combat energy, the 5,000 cap, D20 rolls,
road and NPC encounters) **remains deferred** to a fresh session —
`EQUIPMENT_COMBAT_CRAFTING_DEPTH_01` — after this pass is physically
accepted; nothing of it was started here.

## What the device proved, and what it found

The fresh-playtest reset **works**: Banked 0, Total Walked 0, skills and
character at 1, starter bag restored, goals cleared, lifetime preserved;
old walking did not re-bank; 328 genuinely new steps banked once after a
manual sync. Nothing in that path changed. The findings were presentation,
pace and semantics, answered below in the brief's letters.

## A — SPENT is this playtest's; the starter loadout is worn

- The Adventure band's `SPENT` read the lifetime counter (~57,140) after a
  reset. It now reads **`spentThisEpoch`** — `totalSpent − epoch.spentAtStart`,
  the ledger's own figure — so a fresh playtest shows `Spent 0` beside
  `Total walked 0`. A projection; no counter moved. The Character tab
  gains `Spent this playtest` / `Lifetime spent` tiles once a reset has
  made the two different figures (`walkedBaselineMoved`).
- A fresh playtest now **wears** the starter loadout — sword, tunic, and
  the first tool in loadout order (the Training Axe; the pickaxe stays a
  tap away in the bag) — via `PlaytestReset.equippedItems`
  (`ContentRegistry.startingEquipment`), so a fresh game is playable at
  once. **A brand-new install still grants unworn**: changing
  `GameEngine.newGame`'s first transcript would have re-based fourteen
  engine fixtures and the frozen cross-implementation conformance
  transcript for a UX nicety on a path the owner does not take; deferred,
  named here, not forgotten.

## B — Profession tools are not power-compared

`gearStatsOf` judges a tool **by tier within its profession**, and a tool
of another profession is **`TOOL SWAP`** — never UPGRADE / SIDEGRADE, never
a figure. The Craft block for a tool reads `WOODCUTTING TOOL · Tier 1 ·
Works woodcutting sites up to tier 1 · Currently equipped: Bronze Pickaxe ·
Mining tool · Tier 1`. The craft reveal says the tool line and `Swaps out
Bronze Pickaxe · Mining tool · Tier 1` instead of `Tool power 4 → 4`;
weapons and armour keep their stat delta. No "tool power" exists
mechanically (`CombatRules` reads weapon and armour power only), and none
was invented (`test/gear_stats_test.dart`).

## C — MINOR craft results are transient

A MINOR result no longer pins the recipe selection (only a running queue
or a held MEDIUM result does), clears on its timer (now 4 s), and clears
at once when the player opens any row. A held result keeps its Continue.
(`craft_flow_test`: "a MINOR result is transient".)

## D — Goal Board, one more pass

READY is the one filled pill (dim step accent); a row or project holding
the Contract goal slot says `TRACKED`; the **project tile is collapsed by
default** — name, stage pill, the stage's materials in one tabular line —
and opens on tap, or by itself when the player can contribute. Rows,
chips, the open-job block and the board's fiction names are unchanged.

## E — One frame, inside the layer

Inside `RewardLayer` every beat is frameless (`RewardLayerScope`), the
headline steps up to card-title weight, beats are separated by a hairline,
the top accent rule is gone, and an item row keeps its rarity frame only
from Uncommon up — a Common drop is a plain row with no badge. Inline on a
card, a beat frames itself exactly as before. Combat's EXPERIENCE block is
a labelled group, not a box. `combat_victory` golden regenerated.

## F / G — Hardened seam round 2; the audit repeated

One PixelLab round (3 gens) for the hardened seam; accepted seed 7720 —
copper's own silhouette, darker, compressed, thick bands, crystal clusters
(`GAME_BIBLE/ART/exploration/PLAYABLE_POLISH_01/README.md` §3). Copper and
tin stand. Every profession loop re-captured in context: mining faces the
seam and lands on it, the seam is west, locked does not animate; no loop
regenerated.

## H — Gathering paces at 100 steps a minute

`ActivityDurations.forNode(node, cost)`: **600 ms per spendable step**, on
the profile-scaled cost the engine charges (`StrideSession.costOf`), times
the site's authored `workSpeedPercent` (content, default 100 — the one
seam for a future special site; no shipped node authors it). Meadow Patch
(80) is 48 s; 200 is 2 min; 1,000 is 10 min; ×N scales by construction.
Queue semantics untouched: finite, background-reconciled on the anchor,
cancel keeps completions, each completion the unchanged command, no
escrow, no background sync (`activity_controller_test` re-timed, all 16
cases pass; `activity_pace_test` pins the brief's table).

## I — Crafting is deliberate, and still costs zero steps

`RecipeDefinition.craftSeconds` (content, per recipe): components 30–45 s
(Oak Plank 30, Oak Handle 40, Bronze Ingot 45, Pine Plank 45), food 45–90 s
(Herb Broth 45, Duskcap Skewer 60, Frostbloom Tea 75, Hearty Stew 90), gear
120–180 s (Bronze Axe / Pickaxe / Wolfhide Jerkin 120, Bronze Sword /
Reinforced Pickaxe 150, Bronze Chestplate / Frost-lined Jerkin 180).
`CraftDurations.of` reads it; category defaults (40/60/120) catch an
unauthored recipe. The steps-per-minute rule is **not** applied to
crafting; `craft_flow_test` asserts the ledger does not move across a run.

## J / K — Rarity re-based: "how exceptional", not "where in progression"

Owner ruling on device, superseding 2026-08-19: **Common (neutral) <
Uncommon (green) < Rare (blue) < Epic (purple) < Legendary (orange)**.
The enum order, the style table (the two hexes swapped names; nothing in
the palette moved), `items.json`, `08_ITEM_RARITY.md`, `DECISIONS/0021` §4
(amended, not rewritten) and the tests changed together. Training gear and
every everyday material and first meal are Common; standard Bronze,
Lynx Pelt and the healing meals Uncommon; a passive (Wolfhide Jerkin,
Reinforced Pickaxe) and every signature Rare; Frost-lined Jerkin, Hollow
Sigil and Frost Claw Epic; Legendary still empty and never required.
Presentation follows: Common is a plain row, Uncommon a green frame, Rare
up a noticeable payoff; no casino motion, streaks or timers.

## Verification

App **629**, `stride_core` **697**, `stride_storage` **108**,
`stride_health` **143** (compile-only dependency; no health logic
changed) — all passing. `flutter analyze` clean; core purity, single
writer, origin privacy guards clean; `package-art.js --check` clean.
Goldens regenerated and reviewed: `combat_victory`, `phase1_inventory(_large)`,
`phase1_character(_large)`, `craft_stage`, `phase2_craft(_large)`.

New or extended focused tests, by the brief's numbering: (1–2)
`playtest_reset_session_test` (SPENT 0 / lifetime kept / replay 0 across
relaunch / worn loadout); (3) `gear_stats_test` TOOL SWAP; (4)
`craft_flow_test` transient MINOR; (5–6) `activity_pace_test` the table and
the speed seam; (7) `activity_controller_test` and `craft_flow_test`
re-timed, exact counts; (8–9) `craft_flow_test` zero-step, `activity_pace_test`
authored seconds; (10–12) `rarity_test`, `production_content_test`,
`gear_stats_test` (tier separate from rarity); (13–14)
`board_reward_layer_test` (layer up, Continue returns to the board; the
route is `barrierDismissible: false`); (15) `stage_evidence_test` captures.

## Deferred from this pass

- Starter loadout worn on a **brand-new install** (see A).
- Everything in `EQUIPMENT_COMBAT_CRAFTING_DEPTH_01` (above), Q-09, Q-10,
  Q-11 — unchanged.

## Device acceptance — the correction pass

1. Character › Start a fresh playtest → Adventure band: `Total walked 0 ·
   Spent 0`; Inventory: sword, tunic and axe worn; walk, Sync: banks once.
2. Craft › Bronze Axe with a pickaxe worn: `WOODCUTTING TOOL · Tier 1 ·
   TOOL SWAP · Currently equipped: … Mining tool · Tier 1`; craft it: the
   reveal names the tool and the swap, no "Tool power".
3. Craft a Bronze Ingot ×1: ~45 s; `CRAFTED` shows briefly, then the card is
   clean; opening another recipe clears it at once.
4. Gather Meadow Patch ×5: `48s` a repetition, ~4 min the queue; background
   and return: the right count, nothing more.
5. Goal Board: READY is a pill; the project is one row until tapped; a
   tracked job says TRACKED; deliver an order: one-frame overlay.
6. Stonefall: the hardened seam reads as dark compressed copper.
7. Inventory: training gear `COMMON` neutral; Bronze `UNCOMMON` green.
