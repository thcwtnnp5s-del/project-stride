# Open Questions

Nothing in this folder is approved. These are questions worth answering later, recorded so they are not rediscovered expensively.

---

## Q-01 — What does Stride offer a player who cannot walk this week?

**Raised by:** Critic Agent, `CRITIC_REPORT.md` CR-1
**Date:** 2026-08-01
**Target:** Milestone 02, after the vertical slice has been played

### The question

Progression is step-clocked (`DECISIONS/0001`). No steps, no progress. That is the right decision and should not be reopened.

But consider a sick week, an injury, a desk-bound deadline. A player opens Stride on day four of the flu with zero banked steps. Every screen still opens, every affordable craft still works — "steps gate rate, never access" holds — but if the inventory is empty and every activity needs steps, the honest experience is an app with nothing for you today.

That is not FOMO and it is not punishment. It is, however, an uncomfortable fit with `04_PLAYER_PROMISE.md`: *"return to a world that feels welcoming rather than demanding."* Sometimes life means not walking, and a game whose only input is walking has no answer for that yet.

### What is explicitly *not* being proposed

Time-based accrual. It would gut decision 0001 and make the walk optional. Any answer to this question must leave the step clock intact.

### Candidate directions

- A crafting backlog the player can always work through
- Lore, journal, and world reading with no step cost
- Retrying already-unlocked encounters
- Planning and preparation tools that are satisfying in themselves

Notably, **all four already exist in the vertical slice.** That suggests the answer may not be a new system at all, but a balance goal: make sure the player always has something banked to build, read, or fight. If so, this is a tuning question for `GAME_BIBLE/BALANCE/`, not a design one.

### Why it is deferred

Answering it now would be designing for a problem nobody has felt. Ship the slice, play it through a real low-step week, and then decide.

---

## Q-02 — What makes the Traveler recognisable?

**Raised by:** owner, Visual Owner Direction Round 01
**Date:** 2026-08-14
**Target:** after a character attempt built against an approved READ SPEC has been reviewed

### The question

`VISUAL_STUDIO_BASELINE_AUDIT_01` found the Traveler's only memorable features were a chest strap and a hair mass, and concluded that a main character needs a silhouette a stranger could recognise at ×2. The obvious response is to give it a signature — a scarf, an emblem, a distinctive hat.

**That response is deliberately withheld.** `ART_DIRECTION.md` L-5 requires recognisability to be attempted first through proportion, gesture, clothing shape, equipment relationship and restrained colour placement. A decorative mark added to a figure that does not yet read as a person carrying a pack would disguise the failure rather than fix it.

### What is explicitly *not* being proposed

Adding an ornament to make the character memorable. If the figure needs one, that conclusion has to arrive **after** the silhouette work has been given a fair attempt and found insufficient — not instead of it.

### Why it is deferred

There is no evidence yet about how much identity the locked proportions and equipment can carry on their own, because no attempt has been made against an approved read spec. Deciding now would spend the character's one distinctive feature before knowing whether it is needed.

---

## Q-03 — Can the locked equipment read inside a 24 × 34 canvas?

**Raised by:** Character Pixel Artist, `VISUAL_STUDIO_BASELINE_AUDIT_01` Audit B
**Date:** 2026-08-14
**Target:** the first READ SPEC review

### The question

The audit measured a minimum honest column budget of **26 columns** for the current equipment inventory with arms capable of satisfying CR-13, against **24 available** — the sprite is already flush to the canvas edge, with two free columns on the near side and none on the far side.

`ART_DIRECTION.md` L-3 holds the canvas at 24 × 34 anyway, on the reasoning that the shortfall is evidence of a bad *arrangement* rather than a small canvas: equipment currently occupies the same chest-height band as both arms, and moving the load off that band frees roughly four far-side columns.

### The condition for reopening

**L-3 may be reopened explicitly** if an approved READ SPEC demonstrates that the locked inventory — small canvas backpack, sheathed Training Sword, empty hands — physically cannot read inside 24 × 34 once the allocation problem has actually been solved.

That is a specific, falsifiable bar. It is not met by an attempt that keeps the current arrangement and reports being short of room.

### Why it is deferred

Widening the canvas is the cheapest available response and the one `PIXEL_ART_CRAFT_SPEC.md` CR-1 and §7 most directly warn against. The allocation fix has never been tried; until it has, there is no evidence about what 24 columns can hold.
