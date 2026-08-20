# Decision: Exploration & Progression Loop 01 — goals, contracts, projects, persistent HP, enemy knowledge, discovery (state v7)

**Status:** Approved (owner workstream brief, EXPLORATION & PROGRESSION LOOP 01,
2026-08-20)
**Date:** 2026-08-20
**Owner:** Project owner; implemented by Studio Stride

## Context

The device-accepted build (`28e6f01`) has walking, travel, gathering with
background queues, crafting, repeatable combat, rarity, and a continent atlas —
as parallel systems. The owner's brief for this workstream asks for the
connective tissue: the player should regularly understand what another
1,000–3,000 real-world steps could accomplish, and those accomplishments should
feed exploration, equipment, professions, combat, settlement development and
the wider world.

## Decision

### 1. Three tracked objective slots — informative, never escrow

`GameState` gains a goal tracker with exactly three slots: **Journey** (one
destination), **Pursuit** (one item), **Contract** (one contract or project
stage). Each slot holds at most one `ContentId`; nothing expires; the player
may change or clear a slot at any time; switching alters no economy figure.

**A Journey never reserves steps.** The tracker restates the current banked
balance against the route cost; spending elsewhere simply changes the
shortfall. No goal system may reserve, escrow, or auto-spend steps.

### 2. One contract architecture, location-specific fiction

A new content kind, `contracts`, with two classes:

- **Local Needs** — small repeatable authored orders. Each location holds an
  authored deck (~4–6); **2–3 are visible at a time**; completing one rotates
  the next deck entry into its slot, and the deck cycles — rotation is caused
  by player completion, never by time. No resets, timers, expiry, or
  procedural generation.
- **Regional Contracts** — one-time authored objectives. May require
  materials, crafted items, or combat victories (bounties); may unlock
  recipes, reveal rumors, and grant XP.

Contract completion is **one command, one event, one commit**: eligibility
validated, exact items removed, exact rewards granted, completion recorded —
exactly once, reload-safe. A malformed or insufficient delivery is refused
with zero mutation.

**Bounty semantics** (`§79` of the brief): only qualifying victories **after
the contract is accepted** count. Acceptance is explicit player state;
progress is recorded on the `EncounterWon` event at victory time, so replay
reproduces it and a relaunch cannot double-count.

Boards carry location fiction, not a shared "wooden board": Haven's Rest
NOTICE BOARD · Whispering Woods RANGER REQUESTS · Stonefall MINE LEDGER ·
Frostmere EXPEDITION LEDGER. Same backend semantics everywhere.

### 3. Community Projects — staged, permanent, atomic

A new content kind, `projects`: large staged investments (the Mill, the Lift,
the Shelter). Rules, all load-bearing:

- partial contributions allowed, in one atomic command that removes the
  donated materials immediately and permanently — no withdrawal, no regress;
- stage completion exactly once; project completion exactly once; permanent
  effects exactly once;
- no wall-clock construction, no passive generation, no timed collection;
- the reward is **world change and capability**, never passive income.

Permanent effects are **declared on the content they affect**, answered by the
completed-projects set in state: `RecipeDefinition.unlockedByProject` /
`retiredByProject` (the Mill's plank improvement is two recipes, one retired
and one unlocked), `ResourceNodeDefinition.unlockedByProject` (the Lift's
deeper seam), `LocationDefinition.safeAfterProject` (Frostmere becomes a free
full-heal safe location after the Shelter). Settlement **development states**
are named and derived from completed projects — never a reputation XP bar.

### 4. Persistent HP and safe rest

- HP persists between encounters (`PlayerState.hp`); no automatic full heal
  after ordinary combat.
- Food heals outside combat via a new player-facing command; never above max;
  mid-combat eating stays as it was.
- **Safe locations restore full HP instantly and freely** on arrival — no
  timer, no fee, no step cost. Initially Haven's Rest; Frostmere after the
  Shelter completes.
- Defeat semantics unchanged (`DECISIONS/0020`, P-7): retreat to the nearest
  safe location — which now also computes project-derived safety — and heal
  there; nothing is lost.
- Healed amounts are carried **on the events** (`restoredHp` on arrivals,
  `healed` on food), so the reducer stays total and replay stays exact.

### 5. Enemy knowledge — compact, then stop

Lifetime victories per enemy are recorded in state. Three tiers, authored per
enemy with defaults: **Seen** (first encounter), **Studied** (~3 victories —
fuller loot information, a line of ecology), **Known** (~5–7 — bestiary
complete, signature-drop existence revealed, an optional small one-time
Character XP award carried on the crossing `EncounterWon` event). Then it
stops. No level-100 mastery, no kill-100 tasks.

### 6. The anti-grind RNG rule — canonized

> When critical or strongly encouraged progression requires a random enemy
> material, Stride normally provides a deterministic guarantee or alternate
> path within a reasonable number of relevant encounters.

Combat contracts ("Wolf Problem", "Predator Control", …) carry guaranteed
material rewards and are the standard backstop. Signature rare drops
(~5–15%) are optional excitement and must not gate the normal first arc.

### 7. Character level is resilience

- **+2 max HP per character level** (was +4), base 40.
- **No automatic attack or defence per level** (the `(level−1)÷2` attack
  bonus is removed). Equipment is the combat-power source.
- Character XP curve (cumulative): 0 · 100 · 250 · 475 · 775 · 1150 · 1600 ·
  2150, extended to 2850 (L9) and 3650 (L10) at the existing cap.
- Character XP comes from adventure accomplishments — combat, first
  discovery, one-time contracts, project stages/completions — never from
  ordinary gathering repetitions.

### 8. Discovery and rumors

Three knowledge states: **visual-only** (painted geography, no marker),
**rumored** (a new content kind, `rumors`: an approximate marker and a hint,
revealed by contracts/projects/discoveries), **discovered** (the existing
unlocked set). The world stays visible; mystery is incomplete knowledge, not
fog. Rumors carry no timer and no obligation.

### 9. Deterministic yield bonuses

Small profession/equipment yield chances (node-authored skill bonuses,
Wolfhide's Wilderness Ready, the Reinforced Pickaxe's mining bonus) roll from
a pure hash of the event sequence, the completion index and the node id — the
combat resolver's discipline applied to gathering. The rolled quantity is
recorded on the event; replay reproduces it after any retune.

### 10. State version 7

`PlayerState.hp` plus one new `progress` block (enemy victories, contract
state, local-need slots, project contributions, completed sets, revealed
rumors, tracked goals) enter the save. `StateMigrations` v6→v7,
`rebasesEconomy: false`; v1–v6 fixtures byte-untouched; `v7_baseline.save`
frozen. A v6 save decodes with full HP at the (new) max for its level — what
a v6 save meant, where every fight began full — and empty progress.

## What this decision does NOT license

No dungeons, talents, coins, shops, durability, quality tiers, procedural
quests, daily/weekly systems, timed events, NPC dialogue framework, buff/
debuff framework, or combat redesign (brief §91). No new wall-clock
progression: `DECISIONS/0022` remains P-4's only exception. No background
health work; no change to step accounting, cursors, watermarks, or epochs.

## Consequences

- `RULES.md` gains pointers for: goals never escrow; project effects exactly
  once; the anti-grind rule.
- `StateVersion.current` = 7; `v7_baseline.save` frozen.
- The reachability validator's target set gains the new progression items so
  a content edit cannot orphan the loop.
- Combat pacing shifts slightly (no level attack bonus); enemy tables are
  retuned only where the brief's owner targets say so.
