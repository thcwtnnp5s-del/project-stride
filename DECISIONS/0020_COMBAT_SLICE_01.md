# Decision: Combat Slice 01 — encounter state, driven-off rule, state version 4

**Status:** Approved (owner direction, Playable Expansion 01 master prompt, 2026-08-18)
**Date:** 2026-08-19
**Owner:** Project owner; implemented by Studio Stride

## Context

`DECISIONS/0003` locked the combat *model* — turn-based, ~6–12 turns,
interruptible, retreat-not-death — and deferred pacing, actions and enemy
statistics to the phase that builds them. Transformation Build 01 was proven on
the owner's iPhone and the owner directed the next build to add a **small
combat vertical slice** using the three enemies already in content, without a
stat system, dungeon framework or currency.

Two things needed a record rather than an implementation detail
(`RULES.md` G-3): how encounter state enters the save, and what stops a
step-free encounter from being a free drop farm.

## Decision

1. **Encounter state is part of `GameState`** (`encounter: EncounterState?`),
   and the save moves to **state version 4** through a `StateMigrations` step
   that declares `rebasesEconomy: false`. The migration bumps the format and
   nothing else; the economy epoch is untouched (`DECISIONS/0018`, `0019`
   stand). Older saves decode with no encounter and an empty driven-off set.
2. **One round is one command and one commit.** The player's action and the
   enemy's reply resolve together. A durable save is always at the start of a
   player turn; cold relaunch resumes there. Victory rewards ride on the same
   event that clears the encounter, so they are applied exactly once by
   construction — no flag, no counter.
3. **Starting an encounter costs no steps.** Real-world steps paid for the
   journey. After a **victory** the enemy is *driven off* at that location
   until the player moves (any location change clears the set). This is
   step-clocked through travel, never wall-clock (`RULES.md` P-4), and it is
   the only limiter on repeat fights. Defeat and retreat do not drive an
   enemy off.
4. **Defeat and voluntary retreat both move the player to the nearest safe
   location** (BFS over the content graph from where they stand; if already
   safe, they stay) and clear the encounter. Nothing else changes
   (`RULES.md` P-7). Consumables eaten in the fight stay eaten
   (`DECISIONS/0003`).
5. **Character XP and level become live** (`PlayerState`), earned only from
   victories, and feed max HP and a small attack bonus
   (`DECISIONS/0003`: "character level supplies HP and a small
   attack/defence contribution"). No combat skill.
6. **The resolver is seeded and deterministic**: the seed derives from the
   event sequence and the enemy id at encounter start; every roll is a pure
   function of seed, turn and salt. `stride_core` gains no randomness.

Figures — enemy statistics, damage formula constants, level thresholds — are
provisional and live in `GAME_BIBLE/COMBAT/02_COMBAT_SLICE_01.md`.

## Alternatives considered

- **Two commands per round** (player action, then enemy reply as its own
  commit). Matches "alternating turns" literally but creates a durable
  half-round the UI must auto-resolve on relaunch and a second commit per
  round. Rejected for the slice; the presentation sequences the two halves
  from the committed events instead.
- **A step cost to start an encounter.** Rejected by owner direction: a
  player already at the encounter with zero banked steps must be able to
  fight.
- **Unlimited free re-fights.** Rejected: goblins drop ore, and a free,
  unlimited fight is a free mine. The driven-off rule costs one line of state.
- **A step-counted cooldown per enemy.** Step-clocked and honest, but a new
  counter to persist and explain; the travel rule gets the same effect from
  state that already exists.
- **Persistent player HP between fights.** Would need a step-clocked
  recovery rule and a "rest" surface; deferred. Every encounter starts at
  full HP and food matters inside the fight.

## Consequences

- `StateVersion.current` = 4; `v4_baseline.save` frozen; v1–v3 fixtures
  unchanged.
- `GatherResource` and `TravelTo` are refused while an encounter is active.
- The Adventure tab renders the encounter when one is active; there is no
  navigation state to persist.
- Dungeons, when designed, reuse `EncounterState` and the resolver rather than
  inventing a second fight.

## Follow-up

- Balance is revisited after the owner's device play; figures move to content
  if a second character archetype ever exists.
- `JOURNAL/OPEN_QUESTIONS.md` records the open questions the slice raises
  (persistent HP / rest, a guard action, enemy variants per region).
