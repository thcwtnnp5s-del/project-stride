# Open Questions

Nothing in this folder is approved. These are questions worth answering later, recorded so they are not rediscovered expensively.

## Two kinds of entry live here

**Q-entries** are genuinely open questions — nobody knows the answer, and the entry records why it is deferred rather than guessed.

**OD-entries are owner direction.** The *direction* is settled and is not open for an agent to relitigate; only the **design and implementation are deferred**, and they are deferred because the owner has not authorised the work. Treat an OD-entry as a standing requirement waiting for its milestone, not as an invitation to debate.

An OD-entry is not canon. When one is implemented it graduates into the canonical home named in its entry — `GAME_BIBLE/`, a `DECISIONS/` ADR, or both — and the entry is closed with a pointer. Recording it here rather than in `GAME_BIBLE/` is deliberate: a requirement written into canon before it has been designed becomes a constraint on its own design.

> **`OD-` not `D-`.** `D-01` is already taken by a *defect* — the banked-steps
> header clip, in `MILESTONES/PLAYABLE_DEMO_PHASE_1_DEVICE_RESULT.md` §5. Two
> registers, two prefixes, no collision.

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

### Answered for the next attempt — verdict (A)

**2026-08-14.** The Character Visual Designer judged **(A) — 24 × 34 should be sufficient with better mass allocation**, and the owner accepted it. `CHARACTER_READ_SPEC_01.md` is frozen on that basis and **the canvas is not widened.**

The reasoning: 26-against-24 measured **one row**, in an arrangement where the pack, both arms and the torso all demanded width in the same band. The approved architecture separates the loads by height rather than by side — pack above and behind the far shoulder, both arms owning the chest register, sword at the near hip — so no single row is asked to hold all three.

### The three reopening conditions

**Q-03 reopens only if one of these is demonstrated in an actual compliant render — shown, not argued — while holding L-1, L-2 and L-4:**

1. At the widest chest row, torso plus both arms plus the near-side background notch cannot be accommodated without either **widening the figure** (forbidden by L-2) or **eliminating the notch** (which reinstates the diagnosed failure).
2. At the hip rows, the near hand and the scabbard **cannot be separated by any means** — rows, contour, or overlap — without one of them leaving the canvas or merging with the leg.
3. The scabbard **cannot achieve enough length** to escape the mug/canteen read while remaining below the belt and above the boot.

> **"More pixels would be easier" is not a reopening condition.**

Canvas size may be reopened only where the locked requirements are shown to be **mutually incompatible in a compliant render**.

**The most likely pressure point is condition 3** — the hip register is where this is genuinely tight, and it is the one to watch.

### Why the bar is set this high

Widening the canvas is the cheapest available response and the one `PIXEL_ART_CRAFT_SPEC.md` CR-1 and §7 most directly warn against. The allocation fix had never been tried; until an attempt is made against the frozen spec, there is no evidence about what 24 columns can hold.

---

## OD-01 — The step-economy cutover

**Raised by:** owner, immediately after Playable Demo Phase 1 closure
**Date:** 2026-08-16
**Status:** OWNER DIRECTION — recorded, **not authorised for implementation**
**Graduates to:** a `DECISIONS/` ADR, and `GAME_BIBLE/SYSTEMS/` once designed

### The direction

The large historical banked balance is **validation history, not the intended
long-term player economy**. At Phase 1 closure it stood at 459,043 banked from
459,223 granted — roughly 5,100 gathers' worth, accumulated by a device
integration proving it could count, not by a player choosing to walk.

Before significant progression is built on top of it, there is to be a
**deliberate one-time cutover** so the playable game begins from zero banked
steps at a defined point in time.

### Required long-term behaviour

- Historical steps before the cutover **do not become spendable game currency**.
- Banked steps **start from zero** at the cutover.
- Only steps **observed after the cutover** are granted.
- Manual **Sync Steps remains valid**.
- Eventually, **foreground startup should automatically reconcile** new steps.
- **No background-sync work is implied.** S-01B stays out of scope.
- **No loss of the no-double-count guarantees.**

### Why this is not a small change, and must not be done casually

Recorded now so whoever picks it up does not discover it late:

- **`RULES.md` H-2 says granted is monotonic and there is no clawback.** A
  cutover that reduces `totalGranted` contradicts it. So the cutover is almost
  certainly **not** a subtraction — it is more likely a new epoch, a reset
  cursor, or a fresh ledger, leaving the historical figures intact and simply no
  longer spendable. Which of those it is, is exactly the design question.
- **The cursor is the mechanism that prevents double-counting** (`H-3`). Any
  reset that discards or rewinds it risks re-granting history — the precise
  failure the last two device runs proved absent. A cutover that reintroduces it
  would be a severe regression in the one guarantee the architecture exists for.
- **`P-5` says nothing decays and earned opportunity never expires.** Retiring
  banked steps needs to be squared with that, or the rule needs amending by its
  owner. It is a Kernel-adjacent question, not an implementation detail.
- The **save format** (`DECISIONS/0012`) has no concept of an epoch today.

### What it is not

Not authorisation to implement. Not a licence to weaken H-2, H-3 or P-5 to make
a reset convenient — an invariant that is inconvenient is still an invariant
(`G-4`), and changing one belongs to its owner.

### The obvious first question when this opens

Is the cutover a **save migration** (rewrite the ledger once, at a version
boundary) or a **runtime epoch** (keep the ledger, move a "spendable from" mark)?
The second preserves H-2 by construction and is the one to cost first.

---

## OD-02 — Regional ecology: the world as a geographic and economic system

**Raised by:** owner, immediately after Playable Demo Phase 1 closure
**Date:** 2026-08-16
**Status:** OWNER DIRECTION — recorded, **not authorised for implementation**
**Graduates to:** `GAME_BIBLE/WORLD/`, extending `01_WORLD_STRUCTURE.md`

### The direction

Future world design expands beyond the current region into a **coherent
geographic world** of multiple meaningful biomes — potentially grassland and
temperate, snow / ice / alpine, dry / sandy / arid, mountain ranges, forests, and
rivers, lakes and coast where geographically appropriate.

**Resources and professions are to be geographically grounded**, not distributed
for gameplay convenience:

- ore availability tied to geology and mountain regions
- wood species tied to forest and biome
- fishing species tied to local waters
- hunting tied to regional fauna
- herbs and foraging tied to climate
- cooking ingredients tied to local resources
- towns and settlements shaped by what the surrounding land produces

> The World Map is to be designed as **a coherent geographic and economic system,
> not a collection of themed zones.**

That sentence is the whole requirement. A themed-zone world can be assembled
piecemeal; a geographic one cannot, because where things are has to follow from
the terrain, and the terrain has to be decided first.

### Scope of the eventual workstream

A later dedicated world-design workstream — which **may** use a specialised
design agent — would cover region layout, biome transitions, mountain and water
geography, towns and settlements, travel relationships, regional resources,
profession and resource gates, and deliberate space for future expansion.

### Explicitly NOT authorised now

**Do not generate or canonise the expanded world map.** The current region map
(`assets/art/v1/world/region_map.png`) stands as Phase 1's presentation and is
not to be replaced or extended on the strength of this entry.

### Two dependencies worth naming before the workstream opens

- **There is no travel activity at any layer.** `EnterLocation` exists but takes
  no step cost, and the command that spends banked steps to cross a route is
  unwritten. A geography whose whole point is that places are *far apart* needs
  that system to exist, or the map is describing distances nothing can traverse
  — which is exactly the honesty problem the Phase 1 World screen had to solve
  with a sentence.
- **Geographic grounding is a content-schema question before it is an art
  question.** `locations.json` has `resourceNodes` and `connections` but no
  concept of biome, climate or terrain. Deciding what a region *is* in data
  should precede drawing one.
