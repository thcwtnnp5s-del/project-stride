# Fable Depth Offensive 01 — Thesis

**Branch:** `fable-depth-offensive-01` (from `game-feel-character-presentation-01` @ `a32e206`)
**Status:** Thesis frozen; implementation follows this document.
**Method:** Wave 0 (6 foundation agents) → Wave 1 (20 designers incl. the Ruthless
Editor) → Wave 2 (5-director Synthesis Council) → this synthesis by main Fable.
Full agent record: milestone document §agents (written at close).

---

## 1. Current game-depth diagnosis

The game's systems are healthy and its content is thin at the top. Every loop the
engine supports — gather→craft→project→unlock, combat→drop→reforge, board→deliver→
rotate — works and is device-proven, but content stops in the bottom half of every
ladder, and the systems that shipped most recently (Brace, telegraphs, frostGuard,
the heal ladder above skewer, knowledge tiers) have nothing that *requires* them.
Endgame combat is trivial not because the resolver is shallow but because nothing
opposes a finished loadout.

## 2. Strongest systems (build on)

- Community projects (Lift is the exemplar: project→nodes→contracts→rumor).
- The contract fabric (decks, bounties, regionals; requiresOwned show-don't-consume).
- Craft planner + skill roadmap: pure content-truth projections that automatically
  surface anything we add.
- The Masterwork consume-reforge mechanism (ordinary crafting + auto-unequip guard).
- Knowledge tiers (Seen/Studied/Known) — shipped, paid XP, revealed odds.

## 3. Shallowest systems

- Cooking: demand inverted (economy wants only L1 broth; both top foods orphaned).
- Armor/equipment choice above bronze: three passives, few real swap decisions.
- Character level: half its XP is repeat-kill grind; +2 HP is never felt.
- Combat opposition: seven of nine enemies deal floor damage to a finished loadout.

## 4. Dead content found

traveler_ration (0 consumers), expedition_stew (0), traveler_tunic (no upgrade
path), hollow_sigil (one show, then inert), scree_crawler (no signature, no study
motive), all four rumors (dead-end IOUs), the Watchtower (1 unlock).

## 5. Dead skill levels

Content caps: Foraging 10 / Mining 8 / Cooking 9 / WC 7 / Smithing 7 on 20-level
curves (82–94% of every curve empty). Interior dead levels: For 2,5,9; WC 2,3,6;
Min 2,6,7; Cook 2,5,8.

## 6. Dead / thin materials

tin_ore (1 consumer), boar_tusk (1), wolf_pelt / lynx_pelt / ram_horn / hollow_root
(2 each); no surplus-equipment sink anywhere.

## 7. Weak regions

Forgotten Hollow (5 contracts, no regional, 1 enemy, smallest board); Frostmere
(3,000-step spur, cost > per-visit density); Woods outgrown by WC 4–7.

## 8. Weak long-term goals

After the last regional: repeats and rumor-pointers. The best remaining pursuit
(frost_claw for Clawguard) is ~51,500 *expected* steps of RNG with no mercy —
P-10 in spirit if not in letter. The optimal forager never leaves Haven
(Mill Garden 0.150 XP/step at zero travel).

## 9. Art / audio constraints

Zero PixelLab generations (balance is exactly 25 = the untouchable atlas reserve).
Zero audio. Iron tier off the table (recorded Iteration 03 deferral). All new art
is A-2 derivation: byte-copy icons honest only when the new thing CONSUMES its
donor; node plates byte-copy the node each depth-variant deepens; elite enemies
reuse full existing combat sets. Every copy gets a donor row in
`Scripts/art/package-art.js` and provenance comments.

## 10. Architecture constraints

Content is JSON (`assets/content/v1/`); the loader enforces consumers, reachability
and cross-refs. Health/step accounting untouchable. Crafting costs zero steps.
No wall-clock, no FOMO, no decay. Combat model locked (no miss, no d20). Rarity
mechanically inert; no Legendary ships. Knowledge stops at Known. Enemy count is
the only touched pin (9, test-asserted, moves only by ADR). Every completion feeds
`ActivityResult`. UI reads `StrideSession` projections only. Save stays **v9** —
this workstream adds **no durable state** (the provision slot died for exactly
this reason). Content additions are still one-way for the accepted build
(`unknownContent` fail-closed refusal once a new item is acquired) — recorded here
and in the device checklist, not discovered by the owner.

## 11. The selected improvements (twelve)

Selection principle (Council-D): **the winners gate on things the owner's save has
already done** — completed projects and Known enemies — so the midgame test passes
at install, while fresh saves meet the same content later, in order.

1. **Rails** — ADR 0028 (Veteran Hunts scope: enemy pin 9→13, elite signature
   roll OFF, revert clause, one-way save note); content field `requiresProject`
   on ProjectDefinition (the contract side already ships); content field
   `requiresKnownEnemy` on EnemyDefinition (engine authority + projection mirror;
   hidden until base Seen, shown-locked until Known); validator L-1 extended (no
   recipe, contract requirement, or project stage may consume a location-entry
   item); one-time character-XP band test (2,900–3,200); DEPTH-P's rate tables
   adopted as binding.
2. **Veteran Hunts** — four named elites at their home regions, Known-gated:
   Old Grey (Woods wolf), Foreman of the Broken Gallery (Mine goblin), Rimeclaw
   Matriarch (Frostmere lynx), The Guardian Awakened (Hollow boss). Four
   deterministic bounty contracts. Tuned so Brace, frostGuard and the heal ladder
   load-bear for the first time (Foreman is brace-or-lose). Elite per-kill XP ≤150;
   bounty charXp 40/50/60/90; compressed study tiers (1/2), knownXp 40–60.
3. **Bronze Lineage** — fanghilt_sword gains `wildernessYieldPercent: 10` (the
   hunter's blade vs the longsword's raw power); **Waywarden's Tunic** (S8,
   consumes traveler_tunic + boar goods — the tunic debt retired); **Tin-Braced
   Pickaxe** (S9, consumes reinforced_pickaxe + tin ×3 — deterministic peer of
   the Hornpoint masterwork); **Frostwarden Coat** (S10, Epic, consumes
   frostlined_jerkin + pelts/wool — the deterministic road past the frost_claw
   stall; the claw stays a trophy shortcut). Smithing ceiling 7→10.
4. **Derived upgrade lineage** — `upgradesTo`/`upgradesFrom` computed from
   recipes' equipment-consuming edges (never authored), surfaced in item purpose
   ("UPGRADES INTO"), the bench, and the craft planner.
5. **Cooking, zero-state** — four conservation-batch recipes (L2/5/8/10, repriced
   to the 0.12 XP hard cap: 30/48/120-XP band per Council-C), ceiling 9→10; four
   contracts: trail_rations (Frostmere need), deep_larder (Hollow need — the
   standing expedition_stew customer), the_far_survey (Frostmere regional),
   rangers_field_kit (Woods, gated on the Watchtower). Both food orphans end at
   2–3 consumers each, with a repeatable one.
6. **Haven's Rest Granary** (rank-2 project, after the Mill) — the standing food
   sink: two repeatable board needs consuming rations/skewers/stews/tea, priced
   35–55 skill XP. Bill ~10k steps.
7. **Lower Gallery Works** (rank-2, after the Lift) — pays the lower_gallery
   rumor: gallery_tin_lode (Min 6) + collapsed_span (Min 7) at 0.137/0.131
   (deliberate parity with hardened copper — variety at equal rate), "Tin for the
   Works" repeatable (tin ×3 + scrap ×1). Mining 5→8 stops being one loop; tin
   sourcing doubles. Bill ~13.4k steps.
8. **Hollow Undercroft chain** (after the Field Camp) — pays hollow_depths:
   barrow_rubbings (re-shows the hollow_sigil) → project.hollow_undercroft →
   undercroft_silkfall (For 9, silk ×2) + deep_hollow_thicket (For 10, **52 XP =
   0.173**) + one repeatable Hollow foraging need — together the destination rate
   ≥0.20, which is what actually beats Mill Garden's zero-travel 0.150 (Council-C
   arithmetic; no nerf to the Mill) → first_descent regional (consumes
   expedition_stew; points at the Guardian Awakened).
9. **Reclaim trio** (Smithing 8) — reclaim bronze_axe / bronze_pickaxe /
   bronze_chestplate into ingots at XP-lossy rates (20–35 XP, outputs ≤ half the
   bill): the game's first surplus-equipment sink.
10. **Warded Grove** (WC 6, Woods, gated on the Watchtower) — restored by
    Council-A and Council-D independently: the wave's heaviest new bill is planks
    (~33 plank-equivalents) and Woodcutting otherwise received nothing; fills the
    WC 6 dead level, gives the Watchtower a second dependent.
11. **Provisioner's Charter** (three sequenced Haven regionals, trimmed to 155
    charXp) — the only content expressing the cross-region circuit; Council-C's
    XP allocation depends on it.
12. **The information pack** — roadmap end-cap ("the road runs out here…") +
    closure census; the bench "Trades away:" line; project lineage line; and the
    **Bestiary** pushed route from Adventure (region-grouped, reuses encounter-card
    projections, Dijkstra distance line, Unseen withheld; completion fact "Field
    Guide — complete edition" — a fact, never a meter).

Authoring rule adopted throughout (Council-B): every chain finale's completion
text names exactly one rumor or frontier, so the map never ends in silence —
eastern_city and the Five-Hearth Blade are the named horizons.

## 12. Why each was selected

Each answers a named hole from §§3–8 with the cheapest honest mechanism the
constraint set allows, and every one is buildable at zero generations, zero new
durable state, and at most one ADR. (Per-item rationale inline above.)

## 13. How they interconnect

Known knowledge (2) is planned from the Bestiary (12), gates the elites whose
fights demand the food (5) and armor (3) the new projects (6–8) and boards demand
in turn; projects unlock the nodes (7, 8, 10) that pay the profession ladders the
roadmap (12) now honestly ends; surplus gear from all of it exits through the
reclaims (9); the Charter (11) walks the whole circuit. Every pillar demands from
and supplies at least two others (DEPTH-S invariant, verified at integration).

## 14. Rejected proposals (with owners)

- Slash/crush/pierce + weakness/resistance (DEPTH-G's own rejection: all four
  weapons are swords — a type chart over a mono-class arsenal creates zero
  decisions; deferred with named preconditions).
- Provisions/buff slot (D0023 refuses the seed; negative value in trivial combat;
  forced the only v10). With it: DEPTH-J's L8 milestone.
- Character milestone capabilities (second pursuit slot etc.) — needed the v10;
  the XP rebalance ships without them.
- heavyGuard/gloomGuard armor fields (would collapse the Foreman's brace lesson
  in the same wave; donor collision; Rimeclaw already makes armor choice real).
- The Marked (8 elites), F's elites — one elite system, four fights (ADR scope).
- Five competing traveler_tunic successors — Waywarden's Tunic won.
- Four competing endgame sinks — Granary won; Caravan Yard, Garrison, Waymeet cut.
- Five-Hearth Blade — deferred to Wave 2 repaired (longsword donor), the named
  craft crown; this wave's capstones are Frostwarden + Guardian Awakened.
- Trophy Commissions (Known-gated signature guarantees) — **into the owner's
  Q-12 decision packet** as the recommended shape; not shipped ahead of the ruling.
- unlockedByContract on nodes (M's spec archived for Wave 2), silkshears third
  toolKind, requiresCharacterLevel, road-cost project field (High Pass Road —
  Council question recorded, not shipped), the Hearth rest surface (reopens the
  device-PASSED ambient area), mill_garden nerf (out-rated arithmetically
  instead), elite 20% signature roll (owner flag, default OFF), iron tier
  (standing deferral), tenth-enemy nouns, new gathered materials.

## 15. Deliberately deferred

Everything in §14 marked deferred/archived, plus: Foraging 11–12 and Mining 9–12
final sites (A's designs held for Wave 2 so this wave's proofs stay dense),
eastern_city, WC 8–10, T3 tools, Frostmere's rank-2 (Council-C's recorded debt).

## 16. Expected effect

- **Early player:** unchanged opening; new content arrives as gates open in
  order (Watchtower → grove + field kit; first Known → first hunt visible).
- **Owner-like midgame (the test):** at install — Granary and Lower Gallery on
  their boards (Mill and Lift are built), Old Grey likely already unlocked (wolf
  Known), Smithing 8–10 ladder on the roadmap, both stall roads (tin pickaxe,
  Frostwarden) visible in the planner, the Bestiary to plan hunts from home.
  First 20 minutes: new goals on three screens. First walk: a hunt or a project
  stage. First week: a rank-2 project, two elites, one lineage piece.
- **Advanced player:** four fights that finally push back, three ladders worth
  finishing (S10 / F10 / C10), a circuit worth walking, and honest horizons.

## 17. Save impact

None. State stays v9; no migration; no new events. Content-only one-way property
for the accepted build recorded in §10 and the device checklist.

## 18. Implementation order

Council-D's order, Council-E's costs: (0) rails + validators + ADR draft →
(1) Veteran Hunts → (2) Bronze Lineage + reclaims + fanghilt → (3) cooking pack →
(4) Granary → (5) Lower Gallery → (6) Undercroft chain → (7) grove + Charter →
(8) lineage projection + roadmap end-cap + trades-away →
(9) Bestiary route → (10) integration: XP re-sum to 3,165, P-table retune pass,
donor rows + `--check`, goldens, the five play-proofs, docs. The closeout tail is
a first-class work item and is never shed; if anything sheds it is (in order)
the Charter, the project-lineage line, the Bestiary.
