# Combat Slice 01 — the first playable encounter loop

**Status:** Implementation contract for Playable Expansion 01. Balance figures
are **PROVISIONAL test balance**, not design decisions. Rules that touch a
locked decision cite it; everything else here is reversible.
**Governed by:** `DECISIONS/0003_COMBAT_MODEL.md` (turn-based, 6–12 turns,
retreat-not-death, encounter state persists, no combat skills in M01),
`GAME_BIBLE/COMBAT/01_COMBAT_PHILOSOPHY.md`, `RULES.md` P-7, P-4, E-1, E-2.
**Recorded in:** `DECISIONS/0020_COMBAT_SLICE_01.md` (state v4, the
driven-off rule, retreat destination, exactly-once rewards).

## 1. The question this slice answers

> Is fighting things in Stride fun enough to build on?

So it is deliberately small: three enemies that already exist in content, one
attack action, one tactical action (eat), retreat, character XP, and the
equipment the player already crafts. No skills, no status effects, no party,
no dungeon, no currency.

## 2. Where encounters happen

Each canonical enemy stays in its canonical location — regional ecology, not
one arena:

| Enemy | Location | Role | Behaviour |
|---|---|---|---|
| `enemy.forest_wolf` | Whispering Woods | first fight, winnable with the starting loadout | **flurry** — two light bites a turn |
| `enemy.cave_goblin` | Stonefall Mine | needs a Bronze Sword; the Chestplate makes it safe | **steady** — one strike a turn |
| `enemy.hollow_guardian` | Forgotten Hollow | boss; needs bronze, armour and food | **guarded** — every third turn a heavy strike, telegraphed the turn before |

An encounter is **intentional**: the player is at the location and taps
*Start Combat* on that enemy's card. Nothing ambushes anyone.

## 3. Cost and availability — no steps to fight, but not free forever

- Starting an encounter costs **no steps**. The player paid to get here
  (`RULES.md` P-3 is satisfied by travel; the prompt's rule: a player at the
  encounter with zero banked steps can still fight).
- **Driven off.** After a victory the enemy is driven off *at this location*
  and cannot be fought again until the player **moves** — any
  `LocationTravelled` / `LocationEntered` / retreat clears the driven-off set.
  Step-clocked (travel costs steps), not wall-clock, so `RULES.md` P-4 holds
  and there is no free drop farm. Defeat and retreat do **not** mark the enemy
  driven off — the player may come back and try again.
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

Existing fields keep their meaning. Two are added, both optional with defaults:
`behavior` (`steady` default | `flurry` | `guarded`) and `xp` (character XP on
victory, default 0). Provisional numbers:

| Enemy | health | attack | defence | behavior | xp | drops |
|---|---:|---:|---:|---|---:|---|
| forest_wolf | 20 | 4 | 0 | flurry | 30 | meadow_herb ×1 @60% |
| cave_goblin | 32 | 8 | 3 | steady | 60 | copper_ore ×2 @55%, tin_ore ×1 @30% |
| hollow_guardian | 60 | 11 | 4 | guarded | 150 | hollow_sigil ×1 @100%, hollow_root ×2 @70% |

`profile.enemyHealthPercent` scales health at encounter start and
`profile.xpPercent` scales the character XP awarded (QA profile); the HP bar
shows the scaled figures.

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
  written on the event), drops added to inventory, encounter cleared, enemy
  marked driven off here. **Exactly once by construction**: the reward is a
  field of the event that also clears the encounter, applied by one reducer
  branch; a replay applies it once; a second victory needs a second encounter.
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
| `StartEncounter` | enemy unknown · enemy not at the player's location · an encounter is already active · enemy driven off here | `unknown_enemy` · `enemy_not_here` · `encounter_in_progress` · `enemy_driven_off` |
| `CombatAttack` / `CombatEat` / `CombatRetreat` | no encounter active | `no_encounter` |
| `CombatEat` | item unknown · not owned · not a consumable with healing · hp already full | `unknown_item` · `item_not_owned` · `not_edible` · `health_full` |
| `GatherResource`, `TravelTo` | an encounter is active | `encounter_in_progress` |

Crafting and equipping stay allowed during an encounter (they cannot change a
fight already snapshotted; crafting food mid-fight is harmless).

## 9. State — version 4

```text
GameState.encounter : EncounterState?          (null = none)
  enemy, location, seed, turn (1-based), playerHp, playerMaxHp,
  playerAttack, playerDefence, enemyHp, enemyMaxHp, telegraph (bool)
GameState.player    : level and experience now change (victory XP)
WorldState.drivenOff: Set<ContentId>            (enemy ids; cleared on any move)
```

State version **4**; `StateMigrations` step v3→v4 with `rebasesEconomy:
false` — the migration commits the format bump and nothing else. v1–v3
decoders read `encounter` as null and `drivenOff` as empty. Frozen fixture
`v4_baseline.save`; v1/v2/v3 fixtures untouched.

## 10. Presentation contract (Flutter, `lib/`)

- The Adventure tab shows an **Encounter card** per enemy at the location
  (name, threat line, *Start Combat*; disabled with the truthful reason —
  driven off / not ready). While `encounter != null` the Adventure tab renders
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
