# Combat Philosophy

Combat is the active expression of preparation.

Walking prepares the hero. Combat tests the hero.

Combat must reward:

- Equipment choices
- Consumable preparation
- Skill development
- Tactical decisions
- Knowledge of enemies

## Locked model

Reviewed and approved on 2026-08-01. See `DECISIONS/0003_COMBAT_MODEL.md`.
The first implemented slice — three enemies, Attack · Eat · Retreat, a seeded
resolver, character XP — is specified in `02_COMBAT_SLICE_01.md` and recorded
in `DECISIONS/0020_COMBAT_SLICE_01.md` (2026-08-19).

- Solo PvE
- Mobile-friendly, one-handed, interruptible
- **Turn-based.** No real-time pressure; the player may take as long as they like on any turn
- **6–12 turns** for an ordinary encounter
- Short encounters with readable decisions
- Memorable bosses rather than health sponges
- Deterministic resolution from a seeded state, so balance is testable

## Defeat

Defeat retreats the player to their most recent safe destination, keeps already-used consumables consumed, resets the encounter, and may require travel or preparation before retrying.

Defeat **never** removes equipment, inventory, skill XP, character XP, or any previous progression. There is no death, no item loss, and no progress rollback in Project Stride.

Because the player can always retry, difficulty must come from requiring the right preparation — not from attrition or from punishing failure.

## Combat progression

Milestone 01 grows combat power through **character level and equipment only**. Dedicated combat skills and weapon mastery are deferred to Milestone 02, so that the first mini-boss is gated on preparation rather than grinding.

Avoid auto-battle-only gameplay and combat disconnected from the rest of the game.
