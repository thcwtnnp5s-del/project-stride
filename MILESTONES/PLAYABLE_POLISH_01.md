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
