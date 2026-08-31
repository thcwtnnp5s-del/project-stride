# 0028 — Fable Depth Offensive 01: Veteran Hunts and content scope

```
STATUS: EXPERIMENTAL — accepted only on branch `fable-depth-offensive-01`.
This decision authorizes the offensive's scope so the content-count
freeze (0004/0017/0021/0023/0027) moves by ADR and never silently. It
becomes canon only if the owner accepts the branch after playing it; if
the branch is struck, this decision and every count it moves revert with
it.
```

**Date:** 2026-08-30 · **Context:**
`MILESTONES/FABLE_DEPTH_OFFENSIVE_01_THESIS.md` (the owner's depth brief:
a large autonomous gameplay/content expansion, zero PixelLab generations,
zero audio, health/economy untouchable, no FOMO, crafting free).

## What this decision authorizes

1. **Four veteran enemies (the enemy count moves 9 → 13).** Named elite
   stat-variants of already-drawn species, each at its species' home
   region, each *hidden until the base creature is Seen and locked until
   it is Known* (the new `requiresKnownEnemy` content field): **Old Grey**
   (Whispering Woods, forest_wolf art), **Foreman of the Broken Gallery**
   (Stonefall Mine, cave_goblin art), **Rimeclaw Matriarch** (Frostmere,
   frost_lynx art), **The Guardian Awakened** (Forgotten Hollow,
   hollow_guardian art). Zero new art: each maps to its species' existing
   combat set in `CombatAssets.enemyFor` (the shipped hold-hit-pose
   precedent covers withheld frames). One deterministic bounty contract
   each, rewarding guaranteed ordinary materials and one-time character
   XP. The optional elite signature roll designed by DEPTH-G ships
   **disabled**; enabling it is the owner's Q-12-adjacent call.
   The four elite ids are frozen here so content, art mapping and the pin
   test cannot drift: `enemy.old_grey`, `enemy.gallery_foreman`,
   `enemy.rimeclaw_matriarch`, `enemy.guardian_awakened`. Their hunt
   contracts are authored `class: regional` **with** `bountyEnemy` — the
   only loader-legal shape in which a bounty's character XP is one-time
   (regionals are non-repeatable) and therefore countable by the §5 band
   test; a repeatable elite bounty would be a design change and returns
   to the owner.
2. **Two additive content fields**, both cross-reference-validated:
   `requiresProject` on `ProjectDefinition` (the contract-side twin
   already ships) and `requiresKnownEnemy` on `EnemyDefinition` (engine
   is the authority per E-2; the session projection mirrors the reason).
3. **The content pack of the thesis §11**: three rank-2 projects
   (Granary, Lower Gallery Works, Hollow Undercroft), ~19 contracts,
   ~10 recipes (incl. the reclaim trio and the repriced cooking
   conservation ladder, Cooking ceiling 9 → 10, Smithing 7 → 10),
   3 new equipment items (Waywarden's Tunic, Tin-Braced Pickaxe,
   Frostwarden Coat — each consuming its icon donor per A-2 byte-copy
   honesty), 5 nodes (gallery_tin_lode, collapsed_span,
   undercroft_silkfall, deep_hollow_thicket, warded_grove — plates
   byte-copied from the nodes they deepen), and
   `wildernessYieldPercent: 10` on the existing fanghilt_sword.
4. **The L-1 safety validator**: content loading fails if any recipe
   ingredient, contract requirement, or project stage consumes an item
   named in any location's `entryRequirements` (the Hollow re-lock trap,
   found twice in Wave 1).
5. **The one-time character-XP band test**: the pack's summed one-time
   character XP (regionals, project stages/completions, knownXp) must
   land in **2,900–3,200** so character level 10 is reachable by
   accomplishment, not repeat-kill grind (D0023 §7's spirit made
   arithmetic).
6. **The Bestiary pushed route** (presentation only, pure projection over
   v9 state) and the derived upgrade-lineage projection (computed from
   recipes' equipment-consuming edges, never authored).

## What it deliberately does not authorize

No sixth skill, no sixth location, no new species or creature nouns, no
iron tier (0027-era deferral stands), no signature-drop sinks or
requirements (Q-12 stays the owner's; the Trophy Commission design is in
the owner's decision packet, not shipped), no weakness/resistance system,
no buff/provision state, no state-version bump (v9 stays), no bank cap,
no combat energy, no road encounters (Q-11), no atlas work, no PixelLab
generation, no audio generation, no change to travel pacing, buttons, or
ambient scenes (device-PASSED areas).

## Invariant check

P-4/P-5: nothing expires, no timers; hunts and projects wait forever.
P-7: elites change nothing on defeat but HP and pride. P-9: gates are
availability information; nothing is reserved. P-10: every required
material has a deterministic source; elite bounties count deterministic
post-acceptance victories; the Frostwarden/Tin-Braced recipes are the
deterministic peers that make the signature Masterworks pure trophies.
Rarity stays mechanically inert; no Legendary ships. H-*: no health or
ledger code in scope. State stays **v9**; content stays schema 1; the
accepted build refuses (fail-closed, nothing deleted) any save that has
acquired new-pack items — the standing content one-way property, recorded
in the device checklist.
