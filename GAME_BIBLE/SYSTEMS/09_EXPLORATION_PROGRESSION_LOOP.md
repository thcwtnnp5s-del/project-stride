# The Exploration & Progression Loop

**Status:** Implemented (Exploration & Progression Loop 01)
**Decision record:** `DECISIONS/0023_EXPLORATION_PROGRESSION_LOOP.md`
**Milestone record:** `MILESTONES/EXPLORATION_PROGRESSION_LOOP_01.md`

The acceptance question this loop exists to answer, from the owner's brief:

> Does the player regularly understand what another 1,000–3,000 real-world
> steps could help them accomplish, and do those accomplishments meaningfully
> feed exploration, equipment, professions, combat, settlement development,
> and the wider world?

Everything below serves that sentence. Numbers quoted here are the shipped
owner-approved starting targets; the content pack (`assets/content/v1/`) is
authoritative for the current figures, and this document is authoritative for
the *shape* of each system.

---

## 1. Tracked goals — three slots, zero escrow

The player may track up to three goals at once, one per kind:

| Slot | What it tracks | Set from |
|---|---|---|
| **JOURNEY** | A destination on the atlas | The World screen's selection panel |
| **PURSUIT** | An item to craft | The Craft screen ("Track as Pursuit") |
| **CONTRACT** | An accepted piece of board work | A location board |

Rules that may not be weakened:

- **Tracking never reserves, escrows, or auto-spends a step.** Every figure a
  slot shows is a live projection against the current bank and bag. Clearing
  a slot changes no economy figure. (`RULES.md` P-9.)
- **Nothing tracked expires.** A goal sits until the player clears or
  completes it (`RULES.md` P-5).
- A Journey is priced by the real route (Dijkstra over the shipped roads,
  profile-scaled); a Pursuit prices the full recursive material plan with a
  consume-once working ledger; a Contract shows its remaining requirement
  lines. The engine re-validates everything on delivery — the tracker is a
  read-model, never an authority (`RULES.md` E-2).

### The step-sync motivation moment

After a granting sync, the Adventure screen holds a banner — "+2,148 STEPS
BANKED" plus the few true sentences about what that made possible (a Journey
now affordable, a Pursuit now gatherable, a contract deliverable). It is
dismissed by the player or displaced by the next command, never swept away by
a timer. This is the surface that answers the acceptance question at the
moment the player returns from a walk.

## 2. Contracts — one architecture, four fictions

One mechanism (`ContractDefinition`), surfaced through each location's own
fiction:

| Location | Board name | Visible slots |
|---|---|---|
| Haven's Rest | Notice Board | 3 |
| Whispering Woods | Ranger Requests | 2 |
| Stonefall Mine | Mine Ledger | 3 |
| Frostmere | Expedition Ledger | 2 |

Three contract classes:

- **Local needs** — repeatable orders drawn from a per-location deck (~4–7
  authored per board). The visible window **rotates on completion, never on
  time**: delivering one retires it from its slot and reveals the next deck
  entry that is not already visible, cycling. No timer touches a board.
- **Bounties** — deliverable proof of victories. **Only victories won after
  acceptance count** (no retroactive credit), and the bounty's material
  reward is a *deterministic guarantee* — the anti-grind rule below.
- **Regional contracts** — one-time, larger, and allowed to gate: on a prior
  contract, on a completed need at another location, on an owned item, or on
  a community project. Some teach recipes (`unlockedByContract`); some reveal
  rumors.

Delivery is atomic: consume, reward (items, skill XP, character XP), rotate,
and de-accept in one committed event. A refused delivery mutates nothing.

### The anti-grind rule

Repeatable RNG is never load-bearing. Anything a contract or recipe
*requires* drops dependably or is gathered; **signature drops (the ~5–15%
rares) are never an ingredient, requirement, or bounty target.** A bounty
asks for victories, which are deterministic to earn. `stride_core`'s
signature-purity test enforces this against the shipped content.

## 3. Community projects — permanent, staged, exactly-once

Three shipped projects, each a settlement's named next chapter:

| Project | Where | Development change | Also |
|---|---|---|---|
| Restore the Haven's Rest Mill | Haven's Rest | Struggling → Recovering | Oak planks 3→2 logs; oak handle pair |
| Repair the Gallery Lift | Stonefall Mine | Strained → Working | Opens the Hardened Copper Seam |
| Raise the North Shelter | Frostmere | Exposed → Outpost | Frostmere becomes safe; reveals the northern range |

Rules:

- **Contribution is atomic and partial-friendly**: the player offers any
  subset of a stage's remaining lines; the engine consumes exactly what it
  accepts in one event. A refused line refuses the whole command with the
  reason.
- **Stages complete in order; a completed project is permanent** and its
  effects apply **exactly once**, answered structurally: content declares
  `unlockedByProject` / `retiredByProject` / `safeAfterProject`, and the
  save stores only the set of completed projects. Replays cannot double an
  effect because the effect is a *predicate*, not an applied delta.
- **Development states are named words** (Struggling, Recovering, Strained,
  Working, Exposed, Outpost) — never an XP bar, never a percentage.
  A settlement is a place with a story, not a progress meter.

## 4. Character level is resilience

- Levelling grants **+2 Max HP per level and nothing else** — no automatic
  attack or defence. Power comes from equipment and preparation; toughness
  comes from experience.
- Thresholds: 0 / 100 / 250 / 475 / 775 / 1,150 / 1,600 / 2,150 / 2,850 /
  3,650 (L1–L10).
- Character XP comes from victories, contract deliveries, project stages and
  completions, and enemy-knowledge milestones.

## 5. Persistent HP, food, and safe rest

- **HP persists between encounters** and is stored in the save (v7).
- **Food heals out of combat** (and in combat, as before). Herb Broth heals
  8 for 2 herbs; healing clamps at max; eating at full is refused
  (`health_full`), and a refusal consumes nothing.
- **Safe settlements restore HP to full on arrival, free and instantly.**
  Haven's Rest is always safe; Frostmere becomes safe only after the North
  Shelter stands.
- **Defeat is retreat** (`RULES.md` P-7): the player wakes at the nearest
  safe settlement on the road home, restored, having lost nothing.

## 6. Enemy knowledge — Seen, Studied, Known, stop

Per enemy, derived from the victory count in the save:

| Tier | Reached | What it shows |
|---|---|---|
| Unseen | never fought | Name and behavior word only |
| Seen | first encounter started | Figures |
| Studied | ~3 victories | Tactics read (telegraphs named) |
| Known | ~5–7 victories | Signature drop revealed; one-time knowledge XP |

Then it **stops**. Knowledge is a finite study, not a grind ladder — there is
no tier above Known and no per-kill trickle after it. Until Known, a
signature drop's existence is concealed (the card shows an unnamed `???`
row); the roll itself is identical either way — concealment is presentation,
never odds.

## 7. Deterministic yield bonuses

Gathering rolls are seeded from durable state (`gatherSeed` + purpose salts),
so replays are exact and no roll can be fished by retrying:

- **Node bonus** — a node may declare a bonus chance unlocked at a skill
  level (e.g. Meadow Patch: +1 at Foraging 2, 10%).
- **Wilderness bonus** — the Wolfhide Jerkin's `wildernessYieldPercent`
  (10%) on woodcutting/foraging.
- **Tool bonus** — the Reinforced Pickaxe's `toolBonusYieldPercent` (15%) on
  mining.

Queue completions differentiate their rolls by completion index, so a ×10
queue is ten honest rolls, not one roll ten times.

## 8. Discovery, rumors, and the atlas

- The world atlas is a large painted continent; the playable cluster is
  deliberately a fraction of it (~10–20%). Distant regions are **visual
  only** — visible, unlabeled, unpromised.
- **Rumors** are revealed by contracts and projects (`revealRumors`) and
  appear as named future-tier landmarks on the atlas — a place the player
  has heard of, not a place they can walk to yet. No fog of war.
- **Travel confirms before it spends**: destination, route, cost, and the
  projected remaining bank, then Set out / Stay. Arrival plays a short
  atlas trace (~2.4s, reduced-motion aware) — presentation only; the commit
  happened first.
- Shipped route costs: Haven↔Woods 500 · Woods↔Stonefall 1,000 ·
  Haven↔Stonefall 1,400 · Stonefall↔Frostmere 3,000 · Woods↔Hollow 2,400.

## 9. Reward presentation hierarchy

- **Minor** (gathers, ordinary drops): inline lines and counters, no modal.
- **Medium** (equipment crafted, level-up, contract completed): a held panel
  that states *what changed* — stat before→after, new unlocks by name.
- **Major** (community project completed): the completion headline and the
  settlement's development change, held until Continue.

Nothing celebratory is a timer's job; a player who looks away must find the
result still standing.

## 10. What this loop refuses (unchanged anti-features)

No dungeons, talent trees, coins or shops, durability, procedural quests,
daily systems, NPC dialogue trees, or buff frameworks — the brief's explicit
DO-NOT-ADD list, recorded in the milestone. `PROJECT_KERNEL/06_ANTI_FEATURES.md`
still governs.
