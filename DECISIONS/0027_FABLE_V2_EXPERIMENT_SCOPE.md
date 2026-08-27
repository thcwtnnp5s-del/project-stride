# 0027 — Fable V2 Experiment: content and combat scope

```
STATUS: EXPERIMENTAL — accepted only on branch `fable-v2-experiment`.
This decision authorizes the experiment's scope so the content-count
freeze (0004/0017/0021/0023) moves by ADR and never silently. It becomes
canon only if the owner accepts the experiment after playing it; if the
experiment is struck, this decision and every count it moves revert
with it.
```

**Date:** 2026-08-27 · **Context:** `MILESTONES/FABLE_V2_EXPERIMENT_01.md`
(the owner's autonomous game-director brief: substantial creative ownership
for one sprint, maximal reuse of existing PixelLab assets, atlas image
frozen, health/economy untouched).

## What this decision authorizes

1. **A ninth enemy: the Scree Crawler** (Stonefall Mine, armoured `steady`,
   34/6/6, from REGIONAL_CONTENT_PACK_01's READY art — idle + attack
   accepted by blind QA; its defeat animation is withheld, and the stage
   already tolerates a missing defeat by the Hollow Guardian precedent).
   The production content count moves 8 → 9.
2. **The Verge gear tier** (from RCP01 `CONTENT_PROPOSALS.md`, adapted):
   Bronze Longsword (Epic weapon, power 12, Smithing 6 — bronze + a boar
   tusk + gloom silk, so the one weapon step inside the bronze age asks for
   the Mine, the Woods and the Hollow), Bearhide Coat (Epic armor, power 9,
   tier 2), Hornbound Bronze Axe (Epic tier-2 tool), and Gloom Silk (Rare
   material). Adaptations from the proposal: gloom silk is **gathered**
   (Silkstrand Thicket, Foraging 6, Forgotten Hollow) because the Hollow
   Weaver's attack art failed QA and stays withheld; granite chitin and the
   RCP pickaxe are dropped (icon withheld / superseded by the shipped
   Reinforced Pickaxe).
3. **Three mid-ladder gathering nodes** filling dead skill levels with
   existing yields: Deep Tin Seam (Mining 4, tier-1 pickaxe — the Bronze
   Pickaxe's first reason to exist), Old-Growth Frostpine (Woodcutting 7,
   tier-2 axe — the Hornbound Axe's job), Silkstrand Thicket (above).
   Node scenery derives from the shipped seam/stand/thicket art (A-2).
4. **Board and project content:** the Ranger Watchtower (Whispering Woods'
   first community project; Unwatched → Watched), The Scholar's Interest
   (a Haven regional that gives the Hollow Sigil its meaning —
   `requiresOwned`, never consumed — and reveals a new rumor), Bear Watch
   (deterministic bear-pelt backstop, the lynx-pelt precedent), Feed the
   Forge and Deep Ore Order (Stonefall deck 5–6, the latter post-Lift),
   Teas for the Expedition (Frostmere deck 4, post-Shelter), Watch
   Provisions (Woods deck 5, post-Watchtower), a Cooking-4 efficiency
   recipe (Herb Broth pair), the Hearty Stew healing inversion fix
   (30 → 48), and a guaranteed ram horn added to the Highland Survey
   bounty (the deterministic backstop for the Hornbound Axe, P-10).
5. **The Brace combat action** — Q-06's own named candidate ("halve the
   next hit, deal none"), implemented inline in one command with **no
   state-shape change**, delivered so the owner's device play can answer
   Q-06 with evidence. Q-09 (roll spread / D20) is untouched and stays the
   owner's.

## What it deliberately does not authorize

No sixth skill, no sixth location, no boss content, no bank cap, no combat
energy, no signature-drop sinks (their trophy status is D0023 §5's and
stays an open question), no atlas-image work, no new PixelLab generation.

## Invariant check

P-4/P-5: everything rotates on completion, nothing expires, no timers.
P-7: Brace changes damage taken, never possessions. P-9: unchanged.
P-10: every craft ingredient from combat has a deterministic bounty
backstop; the Sigil contract shows the item without consuming it and the
Sigil itself is a 100% deterministic drop. H-*: no health or ledger code
in scope. State stays **v9**; content stays schema 1.
