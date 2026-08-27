# FABLE V2 EXPERIMENT 01 — Autonomous Game-Director Pass

```
STATUS: EXPERIMENTAL — branch `fable-v2-experiment`, never auto-merged.
Nothing in this document amends canon. Where an experiment touches a
canonical concept, the canonical document is cited and left unchanged;
graduation happens only after the owner plays the build and rules.
```

**Started:** 2026-08-27, from `5ffba67` (playable-phase-2-multiregion tip,
in sync with origin). **Owner brief:** one serious sprint of creative
ownership — make the game more fun to play, connect the systems, and put the
already-paid-for PixelLab art to work. Production atlas image frozen; health,
economy, persistence and anti-FOMO invariants untouchable.

---

## 1. Design thesis

Nine audit passes (product loop, travel/world, skills/gathering,
items/crafting, combat/encounters, goals/boards, mobile UX, game feel,
architecture) and a full PixelLab asset inventory converge on one sentence:

> **Stride's systems are sound and honest, but the game hides its own
> reasons.** The engine already computes why a destination matters, what a
> skill level buys, what an item is for, and what a fight will do next — and
> almost none of it reaches the player. Meanwhile roughly half of an entire
> accepted art pack (REGIONAL_CONTENT_PACK_01) sits unintegrated, and that
> pack happens to contain exactly the content the progression audit says is
> missing: the second weapon beat, the armoured fight, the reasons to
> revisit.

### What is weakest (found, not assumed)

1. **The World screen answers "what is there", never "why go".** Board
   state, contract readiness, tracked goals, gather eligibility — all
   already projected by `StrideSession`, none surfaced on the map.
2. **Progression is invisible or false.** Skill unlock lines omit
   contract/project/tool gates (and are therefore wrong); bonus-yield
   levels look dead; the gather button can enable for a node the engine
   then refuses (`unlockedByProject` ignored by eligibility).
3. **The reward ceiling is a dead row.** All six signature drops and the
   boss's 100%-drop Hollow Sigil have no surface, no use, no acknowledgment.
4. **One weapon upgrade exists in the whole game** (Training → Bronze
   Sword), against enemies hitting 9–11.
5. **Travel — the loop walking most directly buys — is the only loop that
   never uses the reward layer.** Discovery rents half a sentence;
   the banked-step figure teleports; the biggest spend in the game is
   confirmed by sub-touch-target utility buttons.
6. **The content arc ends at a cliff** with rumors pointing at paint,
   no post-project follow-ons, and a project-less enemy region (Woods).

### What is strong and stays

The step-sync opportunity banner; the three-slot goal tracker with live
projections; community projects and cross-region contract webs; the
anti-pressure discipline (nothing expires, defeat is retreat); the reward
layer grammar; the honest travel confirmation; the audio layer.

### What V2 fundamentally improves

Six improvements, chosen because they reinforce each other — the content
gives the map something to say, the map gives the walk a reason, the
combat slice gives the new enemy a decision, the item detail gives the new
materials a story:

- **V2-A · World 2.0 — the command center.** Board summaries,
  "you carry something wanted here", gather-eligibility verdicts,
  tracked-Journey marker and state, affordability in the folded strip,
  development state, location vignettes in the inspector, cheapest-route
  correctness (Dijkstra), a primary Set-out button, and tab-state
  preservation so the map camera survives a bag check.
- **V2-B · Progression made visible and truthful.** Unlock lines that name
  their real gates, the next few unlocks (not one), bonus-yield milestones
  surfaced, and the eligibility bugs fixed.
- **V2-C · The Verge content pack (data-driven).** The RCP01-designed gear
  tier integrated: Bronze Longsword, Bearhide Coat, Hornbound Bronze Axe,
  Gloom Silk; the Scree Crawler as Stonefall's armoured second fight; three
  mid-ladder nodes (Deep Tin Seam, Silkstrand Thicket, Old-Growth
  Frostpine); the Hollow Sigil turn-in; a Woods project (Ranger
  Watchtower); post-project follow-on orders; the healing inversion fixed.
- **V2-D · Items with purpose.** Material/consumable detail (used-in,
  gathered-at, healing), trophy presentation for signatures and the Sigil,
  "makes possible" on material recipes, equip stat deltas.
- **V2-E · Combat: one decision (Brace) + knowledge that matters.**
  Q-06's own named candidate, delivered for device evaluation: Brace halves
  the telegraphed hit; knowledge tiers gate a truthful intent line; each
  enemy gets an authored tell line. No engine rebuild, no schema change.
- **V2-F · Game feel.** Discovery beat on first visits, arrival beat,
  banked-steps count-up, ready-to-deliver lines at the moment they become
  true, fault strings translated to sentences, the new-player empty-state
  nudge.

### What is explicitly NOT built

Bank caps, combat energy, road encounters, dungeons, pet gameplay, D20 /
roll-spread changes (Q-09 is owner-pending), a bestiary screen (deferred —
trophy labeling covers the near need), new regions, background health sync,
new PixelLab generation (zero spend), any atlas-image edit, atlas prop
placement (the accepted props were palette-conformed against a retired
base; re-checking them is atlas-adjacent work this sprint freezes), and the
failed/withheld assets (Weaver, Adit Bat, second character, tavern).

## 2. Rules and mistakes governing this pass

RULES: P-1..P-10 (esp. P-4/P-5 no wall-clock/FOMO, P-7 defeat costs no
possessions, P-9 tracking never escrows, P-10 no load-bearing RNG),
H-1..H-7 (health/ledger untouched), E-1 (core purity), E-2 (UI reads
projections only), E-5 (content is data), E-6 (walk the loop), G-1
(proportional verification), G-3 (unresolved stays unresolved), G-4 (never
weaken a guard), G-8 (explicit staging), A-1/A-2 (PixelLab authors, code
only transforms), A-3/A-4 (atlas frozen and protected).

MISTAKES applied: M-01 (no verification campaign), M-06/M-07/M-11 (play
the loop, look at evidence renders), M-08 (explicit paths), M-12/M-14/M-15
(no atlas work at all), M-13 (blind staging — not needed this pass; no new
generation).

## 3. Save and schema position

**State stays v9.** Brace resolves inside one command (no EncounterState
field); knowledge, contracts, projects, rumors and tracked goals are
already generic over content ids, so the new content rides the existing
`progress` structures. Content files stay schemaVersion 1 (additive
entries). No migration, no fixture change, existing saves load unchanged.

## 4. Asset integration ledger

See `GAME_BIBLE/ART/PIXELLAB_ASSET_INVENTORY.md` (written this pass) for
the full audit. Integrated here: RCP01 gear/material icons (longsword,
bearhide coat, hornbound axe, gloom silk), the Scree Crawler idle+attack
sets, the five accepted vignette variants (World inspector), node scenery
derivations for the three new nodes (A-2 copies of shipped scenery).
Deliberately deferred with reasons: atlas props, fauna pack, walk cycle
(see inventory). Zero new generations.

## 5. Implementation record

(Filled in as commits land; final report in the closing section.)
