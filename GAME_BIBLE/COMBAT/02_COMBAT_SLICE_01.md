# Combat Slice 01 — the first playable encounter loop

**Status:** Implementation contract for Playable Expansion 01. Balance figures
are **PROVISIONAL test balance**, not design decisions. Rules that touch a
locked decision cite it; everything else here is reversible.
**Governed by:** `DECISIONS/0003_COMBAT_MODEL.md` (turn-based, 6–12 turns,
retreat-not-death, encounter state persists, no combat skills in M01),
`GAME_BIBLE/COMBAT/01_COMBAT_PHILOSOPHY.md`, `RULES.md` P-7, P-4, E-1, E-2.
**Recorded in:** `DECISIONS/0020_COMBAT_SLICE_01.md` (state v4, the
driven-off rule, retreat destination, exactly-once rewards) and
`DECISIONS/0021_REPEATABLE_ENCOUNTERS_AND_RARITY.md` (state v5, authored
encounters per visit, the Frost Lynx, item rarity).

## 1. The question this slice answers

> Is fighting things in Stride fun enough to build on?

So it is deliberately small: three enemies that already exist in content, one
attack action, one tactical action (eat), retreat, character XP, and the
equipment the player already crafts. No skills, no status effects, no party,
no dungeon, no currency.

## 2. Where encounters happen

Each canonical enemy stays in its canonical location — regional ecology, not
one arena:

| Enemy | Location | Role | Behaviour | Per visit |
|---|---|---|---|---:|
| `enemy.forest_wolf` | Whispering Woods | first fight, winnable with the starting loadout | **flurry** — two light bites a turn | 2 |
| `enemy.cave_goblin` | Stonefall Mine | needs a Bronze Sword; the Chestplate makes it safe | **steady** — one strike a turn | 2 |
| `enemy.frost_lynx` | Frostmere | needs bronze; the region that had no combat | **flurry** — two light strikes a turn | 2 |
| `enemy.hollow_guardian` | Forgotten Hollow | boss; needs bronze, armour and food | **guarded** — every third turn a heavy strike, telegraphed the turn before | 1 |

An encounter is **intentional**: the player is at the location and taps
*Start Combat* on that enemy's card. Nothing ambushes anyone.

The Frost Lynx was added by `DECISIONS/0021` because Frostmere was the one
region a player could reach and find nothing to fight — an alpine pass with
two gathering nodes and no reason to arrive armed.

## 3. Cost and availability — no steps to fight, but not free forever

- Starting an encounter costs **no steps**. The player paid to get here
  (`RULES.md` P-3 is satisfied by travel; the prompt's rule: a player at the
  encounter with zero banked steps can still fight).
- **Encounters per visit.** Each enemy authors `encountersPerVisit` (integer
  ≥ 1, default 1). `WorldState.visitVictories` counts victories over each enemy
  *during the current visit*; the enemy is available while the count is below
  the authored figure, and when it is spent `StartEncounter` is refused with
  `enemy_driven_off` — the same wire code, because from the player's side the
  enemy is still driven off and still returns when they move on.
- **Any move empties the map** — any `LocationTravelled` / `LocationEntered` /
  retreat / defeat relocation. Step-clocked (travel costs steps), not
  wall-clock, so `RULES.md` P-4 holds and there is no free drop farm. Defeat
  and retreat count **no** victory — the player may come back and try again
  with the whole allowance intact.
- Reload, tab changes and relaunch change nothing: the count is in the save.
- A boss authors `1`, which is exactly the `DECISIONS/0020` rule. A different
  recurrence policy needs no framework, only a smaller number.
- No wall-clock recharge, no energy meter, no stamina.

## 4. The player's combat figures (derived, never stored)

Computed by `CombatRules` in `stride_core` from the current state and content
at encounter start, then **snapshotted into the encounter** so a fight is a
closed system (swapping armour mid-fight changes nothing until the next one):

```text
maxHp     = 40 + 4 × (level − 1)
attack    = weapon.power  (item in the weapon slot; 1 if unarmed)  + (level − 1) ~/ 2
defence   = armour.power  (item in the armor slot; 0 if none)
```

Tools in the tool slot never count. Character level comes from character XP:

```text
level thresholds (cumulative XP): L1 0 · L2 100 · L3 300 · L4 600 · L5 1000
                                  L6 1500 · L7 2100 · L8 2800 · L9 3600 · L10 4500 (cap)
```

These constants live in `CombatRules` (code, documented as provisional) rather
than in a content file — they are rules of the one player archetype, not
authored content. They move to content the day a second archetype exists.

## 5. Enemy data (content, `enemies.json`)

Existing fields keep their meaning. Three are added, all optional with
defaults: `behavior` (`steady` default | `flurry` | `guarded`), `xp` (character
XP on victory, default 0), and `encountersPerVisit` (≥ 1, default 1 —
`DECISIONS/0021` §1; a pack that says nothing behaves exactly as it did).
Provisional numbers:

| Enemy | health | attack | defence | behavior | xp | per visit | drops |
|---|---:|---:|---:|---|---:|---:|---|
| forest_wolf | 20 | 4 | 0 | flurry | 30 | 2 | meadow_herb ×1 @60%, wolf_pelt ×1 @45% |
| cave_goblin | 32 | 8 | 3 | steady | 60 | 2 | copper_ore ×2 @55%, tin_ore ×1 @30% |
| frost_lynx | 30 | 9 | 2 | flurry | 80 | 2 | rime_blossom ×1 @50%, lynx_pelt ×1 @35% |
| hollow_guardian | 60 | 11 | 4 | guarded | 150 | 1 | hollow_sigil ×1 @100%, hollow_root ×2 @70% |

`profile.enemyHealthPercent` scales health at encounter start and
`profile.xpPercent` scales the character XP awarded (QA profile); the HP bar
shows the scaled figures. `encountersPerVisit` is **not** profile-scaled: it is
a rule about recurrence, not a pacing number, and a QA profile that doubled it
would be testing a game the player never gets.

### What the pelts are for

Combat now yields materials nothing else does, so a fight is a step in the
crafting chain rather than a detour from it (provisional, `DECISIONS/0021` §1):

| Item | Rarity | Source |
|---|---|---|
| `item.wolf_pelt` | Common | Forest Wolf, 45% |
| `item.lynx_pelt` "Frost Lynx Pelt" | Rare | Frost Lynx, 35% |

| Recipe | Skill | Ingredients | Output | XP |
|---|---|---|---|---:|
| `recipe.wolfhide_jerkin` | Smithing 2 | 3 × wolf_pelt + 1 × oak_handle | Wolfhide Jerkin (armor, power 4, **Rare**) | 60 |
| `recipe.frostlined_jerkin` | Smithing 4 | 1 × wolfhide_jerkin + 2 × lynx_pelt | Frost-lined Jerkin (armor, power 6, **Epic**) | 120 |

Rarity itself is canonical in `GAME_BIBLE/SYSTEMS/08_ITEM_RARITY.md`; the
figures above are content, and provisional like everything else here.

## 6. A round

The durable unit is **one round**: the player's action and the enemy's reply
resolve in **one command, one commit**. A save is therefore always at the
start of a player turn — there is no durable "the enemy owes you a hit" state
to get wrong on relaunch, and no way to dodge a reply by closing the app.

```text
player action ──► [attack | eat | retreat]
  attack: enemy takes max(1, attack − enemy.defence + roll)   roll ∈ {−1, 0, +1}
          enemy hp 0 → EncounterWon (rewards, once) — round ends here
  eat:    consumes one owned consumable with healing > 0; heals min(healing, missing)
          refused when hp is already full
  retreat: EncounterRetreated — round ends here
enemy reply (unless the round already ended)
  steady:  one strike   max(1, enemy.attack − defence + roll)
  flurry:  two strikes  each max(1, enemy.attack − defence + roll)
  guarded: turns 1,2 normal; turn 3 heavy = 2 × enemy.attack − defence (min 1),
           and the round *before* a heavy turn ends with `telegraph = true`
  player hp 0 → EncounterLost — the player is retreated
otherwise CombatRoundEnded(turn + 1, telegraph)
```

`roll` is a deterministic function of the encounter **seed**, the turn number
and a salt (`CombatRules.roll(seed, turn, salt)`); the seed is derived from
`eventSequence` and the enemy id at encounter start. Same state, same command
⇒ same outcome (`DECISIONS/0003` §Consequences: a seeded resolver). No `Random`
in `stride_core` (`RULES.md` E-1).

Drops roll the same way at victory: `percentRoll(seed, dropIndex, victoryTurn) <
chancePercent` (0..99).

## 7. Outcomes

- **Victory** — one `EncounterWon` event: character XP (level recomputed and
  written on the event), drops added to inventory, encounter cleared, and this
  visit's victory count for that enemy incremented. **Exactly once by
  construction**: the reward is a field of the event that also clears the
  encounter, applied by one reducer branch; a replay applies it once; a second
  reward needs a second encounter, which needs the count to allow it. Raising
  a count from 1 to 2 changed how many fights a visit holds and changed
  nothing about how many times one fight pays (`DECISIONS/0021` §2).
- **Defeat** — `EncounterLost`: encounter cleared, player moved to the
  **nearest safe location** (BFS over connections from where they stand, ties
  by id; if the current location is safe, they stay). Nothing else changes:
  inventory, equipment, XP, skill XP, unlocked locations, banked steps all
  untouched (`RULES.md` P-7). Consumables eaten during the fight stay eaten
  (`DECISIONS/0003`).
- **Retreat** — `EncounterRetreated`: identical to defeat in effect, chosen.

## 8. Refusals

| Command | Refused when | Code |
|---|---|---|
| `StartEncounter` | enemy unknown · enemy not at the player's location · an encounter is already active · this visit's `encountersPerVisit` is spent | `unknown_enemy` · `enemy_not_here` · `encounter_in_progress` · `enemy_driven_off` |
| `CombatAttack` / `CombatEat` / `CombatRetreat` | no encounter active | `no_encounter` |
| `CombatEat` | item unknown · not owned · not a consumable with healing · hp already full | `unknown_item` · `item_not_owned` · `not_edible` · `health_full` |
| `GatherResource`, `TravelTo` | an encounter is active | `encounter_in_progress` |

Crafting and equipping stay allowed during an encounter (they cannot change a
fight already snapshotted; crafting food mid-fight is harmless).

## 9. State — version 5

```text
GameState.encounter      : EncounterState?      (null = none)
  enemy, location, seed, turn (1-based), playerHp, playerMaxHp,
  playerAttack, playerDefence, enemyHp, enemyMaxHp, telegraph (bool)
GameState.player         : level and experience now change (victory XP)
WorldState.visitVictories: Map<ContentId, int>  (enemy id → victories this
                                                 visit; emptied on any move)
```

State version **5**; `StateMigrations` step v4→v5 with `rebasesEconomy:
false` — the migration commits the format bump and nothing else
(`DECISIONS/0021` §3).

`visitVictories` replaces the v4 `WorldState.drivenOff` set, which was this map
with the count fixed at one. The **v4 decoder is frozen and unchanged**: it
reads the `drivenOff` list and decodes each listed enemy at a count of `1`,
which is what a v4 save said — at v4 one victory was the whole allowance. v1–v3
decoders read `encounter` as null and the map as empty, which is what those
saves meant: combat did not exist.

Frozen fixture `v5_baseline.save`; the v1–v4 fixtures are untouched and remain
byte-identical.

`visitVictories` is deliberately **not keyed by location**. It is only ever
meaningful where the player stands, because any move empties it; a per-location
map would be a second mechanism recording one fact, and it would let a player
bank victories across a circuit — the free drop farm the count exists to
prevent.

## 10. Presentation contract (Flutter, `lib/`)

- The Adventure tab shows an **Encounter card** per enemy at the location
  (name, threat line, *Start Combat*). When the enemy can be fought the button
  carries the count — *"2 of 2 this visit"*, *"1 of 2 this visit"* — because
  "you can fight this twice more before you have to travel" is the planning a
  player with a route in mind is doing. When it cannot, the button is disabled
  with the truthful reason in the engine's own order: *"Driven off — returns
  after you travel"* (unchanged wording), *"Finish your current encounter"*,
  *"Reload before fighting"*. While `encounter != null` the Adventure tab renders
  the **combat stage** instead of the gather cards, so a cold relaunch lands
  the player back in the fight without any navigation state.
- The stage: side-view; Traveler on the left facing east, enemy on the right
  facing west, on a terrain backdrop; HP bars for both; the turn number; a
  one-line log; the telegraph line when set; three controls — **Attack**,
  **Eat** (opens the owned consumables), **Retreat**.
- After a command returns, the widget **plays the round's events in order**
  (attack → impact → enemy reaction → enemy attack → Traveler reaction) with
  HP bars settling to the committed values. Nothing is rendered optimistically
  before the commit; the sequence is a replay of facts already durable.
- Results: victory shows XP and drops once; defeat/retreat says where the
  player now is and that nothing was lost. Then the tab returns to the
  location's cards.
- No wall-clock: no timers that advance the fight; the animation sequence is
  a `TickerMode`-gated presentation of an already-resolved round.
