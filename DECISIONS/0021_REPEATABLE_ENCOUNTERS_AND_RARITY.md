# Decision: Repeatable encounters per visit, authored item rarity, state version 5

**Status:** Approved (owner direction, World & Reward Depth Pass master prompt,
2026-08-19)
**Date:** 2026-08-19
**Owner:** Project owner; implemented by Studio Stride

## Context

`DECISIONS/0020` made a victory drive an enemy off *at that location until
the player moves*. On the phone the owner found combat "too restrictive as
the long-term play loop" and asked for a model that allows fighting regional
enemies repeatedly, uses no wall-clock or energy timer, cannot duplicate a
reward, preserves strategic travel, and stays simple — "leaving a location
and later returning should make its normal encounters available again."

That last sentence is already the 0020 rule; what the owner felt was the
**one fight per enemy per visit**. So the change is narrow: a visit may hold
more than one fight, the count is authored per enemy, and the reset trigger
stays exactly what it was.

The same prompt asks for a canonical **rarity** attribute on items, as a
content/presentation property — not procedural gear.

## Decision

1. **Encounters per visit.** `enemies.json` gains `encountersPerVisit`
   (integer ≥ 1, default 1). `WorldState.drivenOff: Set<ContentId>` becomes
   `WorldState.visitVictories: Map<ContentId, int>` — victories over each
   enemy **during the current visit**. An enemy is available while
   `visitVictories[enemy] < encountersPerVisit`; when exhausted the engine
   refuses `StartEncounter` with the unchanged wire code `enemy_driven_off`.
   **Any location change still clears the map** (travel, retreat, defeat
   relocation) — step-clocked through travel, never wall-clock
   (`RULES.md` P-4). Reload, tab changes and relaunch change nothing because
   the map is in the save. Boss / special encounters keep `1` — a different
   recurrence policy needs no framework, only a smaller number.
2. **Rewards stay exactly-once by construction.** Unchanged from 0020: the
   reward is a field of the single `EncounterWon` event that also clears the
   encounter and increments the visit count. A second reward needs a second
   encounter, which needs the count to allow it.
3. **State version 5.** `StateMigrations` step v4→v5 with
   `rebasesEconomy: false`; the migration bumps the format and nothing else.
   A v4 `drivenOff` entry decodes as `visitVictories[enemy] = 1` (the enemy
   was beaten once this visit — true then, true now). v1–v3 decode with an
   empty map. Frozen fixture `v5_baseline.save`; v1–v4 fixtures untouched.
4. **Authored rarity.** `stride_core` gains `enum Rarity` (ascending). *As
   decided here* the order was `uncommon, common, rare, epic, legendary`;
   **amended 2026-08-23** (Playable Polish 01 correction pass, owner ruling on
   device) to `common, uncommon, rare, epic, legendary` — neutral, green,
   blue, purple, orange — with rarity meaning "how exceptional" and
   progression tier a separate axis. `GAME_BIBLE/SYSTEMS/08_ITEM_RARITY.md`
   is canonical for the current order and table. Every item in `items.json` carries a
   **required** `rarity`; the loader refuses a missing or unknown value, so
   "all items have a valid rarity" holds by construction. Rarity is
   **content and presentation metadata only**: no random rolls, affixes,
   sockets, item levels, gear score or rarity-derived stats, ever, without a
   new decision.
5. **Location kind is derived, not authored.** `haven` (safe) · `perilous`
   (a boss lives there) · `worksite` (a node needs a pickaxe) · `wilds`
   (everything else) — a pure function over content, so the atlas can draw
   Haven's Rest differently from Forgotten Hollow without a second source of
   truth in the content files.

Figures — per-visit counts, the Frost Lynx, the two pelts and two recipes,
the tier table — are content and live in `GAME_BIBLE/COMBAT/02` §2/§5 and
`GAME_BIBLE/SYSTEMS/` (rarity table), provisional like every balance figure.

## Alternatives considered

- **Unlimited fights per visit.** Rejected again: a free, unlimited goblin is
  a free mine.
- **A step-counted cooldown per enemy.** Honest, but a second counter with a
  second explanation; the visit count gets the same effect from state that
  already exists, and travel remains the strategic reset.
- **Wall-clock or daily respawn.** Forbidden (`RULES.md` P-4, P-5).
- **An authored `kind` field on locations.** A second place the same truth
  lives; derived from what the content already says.
- **Rarity as a Flutter-only colour table.** Rejected: rarity is a property
  of the item, read by inventory, victory, craft and atlas alike, and it
  must be testable without a widget.

## Consequences

- `StateVersion.current` = 5; `v5_baseline.save` frozen.
- `EncounterOption` reports `remainingThisVisit` / `encountersPerVisit`; the
  encounter card says *"2 remain this visit"* and, when spent, *"Driven off —
  returns after you travel"* exactly as before.
- Items, inventory entries, recipe outputs, encounter drop previews and
  victory rewards all carry `Rarity`; the UI has **one** rarity style table.
- Persistent HP / rest (Q-06) stays open: every encounter still starts at
  full HP, which does not harm repeatability, so nothing is smuggled in.
