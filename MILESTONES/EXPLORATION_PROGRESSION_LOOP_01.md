# EXPLORATION & PROGRESSION LOOP 01

**Status:** 🚧 in implementation
**Branch:** `playable-phase-2-multiregion` · start HEAD `28e6f01`
**Decision:** `DECISIONS/0023_EXPLORATION_PROGRESSION_LOOP.md`
**Owner brief:** fresh major workstream, 2026-08-20. Numeric values in the
brief are **owner-approved starting targets** (§76): changed only for concrete
contradictions, with old/new recorded here.

## Acceptance question

> Does the player regularly understand what another 1,000–3,000 real-world
> steps could help them accomplish, and do those accomplishments meaningfully
> feed exploration, equipment, professions, combat, settlement development,
> and the wider world?

## 1. Hard constraint discovered at re-anchor: the PixelLab budget

`get_balance` on 2026-08-20: **22 generations remain** (subscription resets
2026-09-16; credits $0.00). One `create_image_pixen` icon ≈ 1 generation; a
large painting via pro/pixflux ≈ 20–40+. Consequences, decided up front so no
system is silently blocked:

| Art the brief names | This milestone |
|---|---|
| Boar, Ram, Salamander (+ Bear if scope stays clean) stage sets; tusk/pelt/horn icons | **Integrate from REGIONAL_CONTENT_PACK_01** — already generated, blind-QA'd READY |
| Reinforced Pickaxe icon (withheld after 3 rounds) | **New pixen round from the shipped bronze_pickaxe icon** (the pack's own recommendation), budget permitting |
| New material icons (Oak Plank, Scrap Metal, Heat Scale, Ram Wool, Boar Hide; signature drops) | **Pixen, in priority order, ≈1 gen each**; any icon that fails its read or exhausts budget → the item and its drop/recipe are **withheld together** and recorded (no blank slabs, no code-drawn art) |
| Wider east–west world master (§57–59), Mill/Lift/Shelter visual world-states (§11–13), vibrancy/ambient pass (§63) | **Deferred to the generation reset**, with clean seams: the accepted continent master (playable cluster ≈15% of a landmass, `PROJECT_STATE.md` v2.10) already carries the scale bar; atlas work this milestone is navigation, discovery states, rumor markers and travel presentation — code over existing art (A-2), no new paintings |

This is the `RULES.md` A-1 failure path used deliberately: record, withhold,
escalate — never substitute code-drawn production art.

## 2. Scope

### Domain (stride_core, state v7)

- Persistent HP (`PlayerState.hp`), safe-rest healing on arrival, out-of-combat
  eating (`EatFood`), defeat retreat unchanged.
- Goal tracker: Journey / Pursuit / Contract slots (`TrackGoal`).
- Contracts: `contracts` content kind; local-need decks with
  completion-driven rotation; regional one-time contracts; accepted-contract
  bounty counting on `EncounterWon`; `AcceptContract` + `CompleteContract`.
- Community Projects: `projects` content kind; `ContributeToProject` with
  atomic partial contribution; stage/project completion exactly once;
  permanent effects via `unlockedByProject` / `retiredByProject` /
  `safeAfterProject` on existing content kinds; derived settlement
  development states.
- Enemy knowledge: lifetime victories; Seen/Studied/Known with authored
  thresholds; one-time Known XP on the crossing victory event.
- Rumors: `rumors` content kind + revealed set; contract/project reveals.
- Character level = resilience: +2 max HP/level, no level attack bonus, the
  §35 curve (see deviations).
- Deterministic gather yield bonuses (node skill bonuses, Wolfhide passive,
  Reinforced Pickaxe bonus) via seeded rolls recorded on events.
- Recipe gating: `unlockedByContract` (Wolfhide via Woodland Aid, Reinforced
  Pickaxe via Mine Hardware, Frost-lined via Cold-Weather Kit).
- Migration v6→v7 (`rebasesEconomy: false`), `v7_baseline.save` frozen,
  v1–v6 fixtures untouched.

### Content (assets/content/v1)

Full authored tables in §3–§5 below: retuned travel costs and gathering
targets, new items/recipes, three community projects, ~17 local needs, 7
regional contracts, new enemies (Boar, Salamander, Ram; Bear as optional
high-danger), knowledge thresholds, signature drops, rumors.

### App (lib/)

- Goal tracker panel on Adventure; per-location board (location fiction
  names); contract cards with deliver/accept/track; project screen with
  per-stage partial contribution; step-sync opportunity highlights after a
  granting sync; HP band + Eat outside combat; enemy-knowledge display on the
  encounter card (tiered loot info, signature reveal); profession level-up
  "what changed" presentation; equipment-craft stat-delta presentation;
  project-completion major presentation; travel confirmation (destination,
  route, cost, projected balance) + short atlas route animation (2–4 s, code
  over existing art); atlas rumor markers.

### Explicitly out (brief §91 + budget)

Dungeons, talents, coins/shops, durability, quality tiers, procedural
quests, daily systems, NPC dialogue, buff framework, deep combat redesign,
audio (no canonical sources exist in the repo — re-verified this session;
OD-06 unchanged), the wider world repaint, project visual world-states.

## 3. Numeric targets adopted, and every deviation

### Travel (locations.json) — old → new

| Route | Old | New (brief target) |
|---|---|---|
| Haven's Rest ↔ Whispering Woods | 600 | **500** (~500) |
| Whispering Woods ↔ Stonefall | 700 | **1000** (~1,000) |
| Haven's Rest ↔ Stonefall | 800 | **1400** (1,300–1,500) |
| Stonefall ↔ Frostmere | 1500 | **3000** (3,000–4,000; Haven→Frostmere via Stonefall = 4,400, in the 4,000–4,500 window) |
| Whispering Woods ↔ Forgotten Hollow | 1300 | **2400** (2,000–3,000) |

### Gathering (resource_nodes.json) — old → new

| Node | Old | New |
|---|---|---|
| Meadow Patch | 90 steps · ×2 · 10 xp | **80 · ×1 · 10 xp** |
| Oak Stand | 120 · ×1 · 12 | unchanged (already on target) |
| Duskcap Grove | 130 · ×2 · 18 | **130 · ×1 · 15** |
| Copper Seam | 140 · ×1 · 14 | unchanged |
| Tin Seam | 160 · ×1 · 16 | **xp 17** |
| Rimefrost Hollow | 200 · Foraging 5 · 26 xp | **240 · Foraging 4 · 22 xp** |
| Frostpine Stand | 260 · Woodcutting 8 · 30 xp | **240 · Woodcutting 5 · 22 xp** (owner: Pine participates in the first Frostmere arc) |
| Hardened Copper Seam (new) | — | Mining 5 · pickaxe tier 2 · 200 · Copper ×2 · 26 xp · unlocked by the Stonefall Lift |

Yield reductions (Meadow ×2→×1, Duskcap ×2→×1) are the brief's explicit
targets; local-need quantities are authored against the new yields.

### Food (items/recipes) — old → new

| Item | Old | New |
|---|---|---|
| Herb Broth | 3 herb → heal 12 | **2 herb → heal 8** (Cooking 1) |
| Duskcap Skewer | heal 20 | **heal 14** (2 duskcap + 1 herb, Cooking 3) |
| Northern Provision (new) | — | Rime Blossom ×1 + Meadow Herb ×2 · Cooking 5 · heal 20 (optional frost-preparation effect deferred — no buff framework) |

Frostbloom Tea and Hearty Stew keep their current figures (existing canon;
not named by the brief).

### Character XP curve — old (`CombatRules.levelThresholds`) → new

Old: 0/100/300/600/1000/1500/2100/2800/3600/4500.
New: **0/100/250/475/775/1150/1600/2150/2850/3650** (brief §35 through L8,
extended by its own deltas to the existing L10 cap).
Max HP: 40 + **2**/level (was 4/level). Level attack bonus **removed**.
An existing save's level re-derives on its next victory; XP is untouched, so
the change is monotonic or neutral for the device save (250 ≤ old 300 etc.).

### Profession XP curve (§36) — NOT adopted this milestone; deviation

The brief's §36 targets (75/200/425/750/…) are gentler than the shipped
curves (skills.json). Replacing the curves would silently re-level the
owner's physical save (levels are derived from XP), invalidate the tuned
node/recipe gates above level 8, and interact with every existing test. The
first arc's gates all sit at levels 1–5, where the shipped curves and the
brief's targets differ by under one gather-session of XP. **Kept: shipped
curves; per-node XP retuned instead (above) so early pacing lands on the
brief's intent.** Recorded as a deviation for the owner; a deliberate curve
retune can follow device evidence.

### Equipment

| Item | Decision |
|---|---|
| Bronze Sword | Kept at power 9 (Training 3 → 9; the brief's "~7 or equivalent meaningful delta" is met; current shipped value, no churn) |
| Wolfhide Jerkin | Recipe → **Wolf Pelt ×3 + Oak Plank ×2**, Smithing 2 (was pelt ×3 + handle ×1); gains **Wilderness Ready** (10% +1 yield on Woodcutting/Foraging nodes); unlocked by Woodland Aid |
| Frost-lined Jerkin | Recipe → **Wolfhide Jerkin + Frost Lynx Pelt ×2 + Ram Wool ×1 + Rime Blossom ×2**, Smithing 4; gains **Cold Weather** (incoming damage −2, min 1, in alpine-terrain fights); unlocked by Cold-Weather Kit |
| Reinforced Pickaxe (new, tier 2) | **Training Pickaxe + Bronze Ingot ×2 + Scrap Metal ×2 + Oak Handle ×1**, Smithing 3; 15% +1 Mining yield; unlocked by Replace the Mine Hardware |
| Reinforced Axe (§49) | **Not added** — Pine now needs only a tier-1 axe (Bronze Axe), so nothing requires it; deferred per the brief's own "do not add merely because it is easy" |

## 4. Authored contract & project content (summary)

Local needs decks (IDs `contract.*`): Haven's Rest ×5 (§16), Whispering
Woods ×5 incl. Wolf Problem ×3 wolves → guaranteed Wolf Pelt, Boar on the
Trail ×2 → guaranteed Boar Tusk (§18), Stonefall ×6 incl. Goblin Bounty →
Scrap Metal, Heat in the Deep → Heat Scale (§19), Frostmere ×4 incl.
Predator Control → Frost Lynx Pelt, Highland Survey → Ram Wool (§20).
Regional: Supplies for the Road, Woodland Aid (Haven's Rest, §17), Replace
the Mine Hardware (Stonefall, §19), Cold-Weather Kit (Frostmere, §20).
Combat contracts are repeatable local needs where the brief lists them under
local orders; bounty counting starts at acceptance.

Projects: **Haven's Rest Mill** (Oak Plank ×12 / Bronze Ingot ×4 / Oak Log
×6 + Herb Broth ×3 → Recovering, plank 3→2, carpenter needs, woodworking
recipe), **Stonefall Lift** (Oak Plank ×10 / Bronze Ingot ×6 / Scrap Metal
×4 + Heat Scale ×2 → hardened seam, Lower Gallery rumor, Working state),
**Frostmere Shelter** (staged wood/bronze/frost materials → Frostmere safe,
expedition contracts, northern rumor). Exact JSON is canon in
`assets/content/v1/`.

Rumors: `rumor.eastern_city` (Supplies for the Road), `rumor.lower_gallery`
(Lift), `rumor.northern_range` (Shelter).

## 5. Enemies

| Enemy | Change |
|---|---|
| Forest Wolf | identity preserved; Wolf Pelt stays Common dependable; signature **Pristine Wolf Fang** ~8% (withheld with icon if art budget fails) |
| Cave Goblin | reward identity: **Scrap Metal** Common dependable (replaces copper as primary), tin secondary; signature **Goblin Toolhead** rare |
| Frost Lynx | preserved; signature **Frost Claw** ~5–8% epic |
| Wild Boar (new, Woods) | pack READY art; Boar Hide common, Boar Tusk uncommon; signature Great Tusk rare |
| Salamander (new, Stonefall) | pack READY art (Mire Salamander set, renamed to canon "Salamander" per §28); Heat Scale dependable; signature **Ember Core** rare |
| Mountain Ram (new, Frostmere) | pack READY art (Frosthorn Ram set); **Ram Wool** + Ram Horn; signature Pristine Horn rare; high impact, less dangerous than Lynx |
| Oakback Bear (conditional) | integrated only if scope stays clean as an optional high-danger Woods encounter (1/visit); otherwise hooks preserved and deferred |
| Hollow Guardian | untouched; the Hollow stays optional |

Knowledge thresholds: normal enemies Studied 3 / Known 6; bosses 2 / 4;
Known one-time Character XP 25 (boss 40).

## 6. Verification plan

Focused suites per brief §80–87 (HP/food/rest, tracker, contracts, projects,
knowledge, deterministic drops with injected seeds, profession/equipment
effects, travel/discovery), migration v6→v7 with the frozen fixture chain,
`phase2_loop_budget_test` updated to the retuned economy, atlas goldens for
new markers, then full strict verify (format · analyze · stride_core ·
storage · app · health · secure store · guards).

## 7. Progress log

- 2026-08-20 — record created; re-anchor complete; PixelLab budget constraint
  recorded; implementation begins (domain first).
- 2026-08-20 — **domain complete.** stride_core at state v7: `PlayerState.hp`,
  `ProgressState` (victories, accepted contracts, bounty progress, contract
  completions, local slots/next, projects, completed projects, rumors,
  tracked goals), five new commands (`EatFood`, `TrackGoal`,
  `AcceptContract`, `CompleteContract`, `ContributeToProject`), new/extended
  events with pre-v7 journal compatibility, `progression.dart` (knowledge
  tiers, development states, journey Dijkstra, pursuit planner), gather seed
  + three bonus salts, level table extended to L10 with `attackBonusFor`
  removed. Migration v6→v7 `rebasesEconomy: false`; `v7_baseline.save`
  frozen (generator + decode-only v6 group + B7 round-trip); conformance
  transcript amended (+255 B — `"hp":40` and the empty progress block —
  slots 1616/1618, reviewed). 674 core tests green.
- 2026-08-20 — **content complete.** contracts.json (18 local needs, 6
  bounties, 6 regionals across the four boards), projects.json (Mill / Lift
  / Shelter), rumors.json (3), retuned locations/nodes/recipes/items/enemies;
  atlas_layout.json schema 3 with rumor spots; loader cross-validation
  extended (contract class shape rules, deck-order uniqueness,
  consumed-set over contracts and projects); production content suite green.
- 2026-08-20 — **app complete.** Session projections and reports (~20 view
  types), goal tracker card (compact when empty), location board card with
  held medium/major result panels, step-sync opportunity banner, craft
  equipment celebration with stat deltas, out-of-combat eating in Inventory,
  HP in the walking strip (shown only below full — the full-health fact was
  the wrap row that pushed the gather control under the fold), atlas travel
  confirmation + 2.4 s arrival trace + rumor landmarks. Board titles wrap
  rather than shrink (the Mill's name outran AdaptiveText's floor at 1.4× /
  320 dp). Goal tracker and board sit **below** the action cards so the
  gather control stays above the fold on ≥390 dp phones
  (`fold_clearance_test`).
- 2026-08-20 — **art complete.** Twelve pixen icons in three blind Visual QA
  rounds (round 1: 9 accepted, heat scale / ram wool / goblin toolhead
  FAILed on first reads; round 2 re-rolls: two accepted, the toolhead grew a
  haft and FAILed again; round 3: accepted). All twelve accepted — the
  withheld-icon⇒withheld-item rule was never needed. RCP01 integration:
  boar/ram/salamander idle+attack+defeat and bear idle+attack2+defeat
  packaged with measured footprints; `CombatAssets` entries with
  manifest-sourced strike frames; salamander bites (fx_bite). 16 of the
  cycle's 22 generations spent; 6 remain. Deferred to the 2026-09-16 reset,
  as recorded in §1: the world repaint, project visual states, ambient
  vibrancy, and a node vignette for the Hardened Copper Seam (the card
  reserves the slot).
- 2026-08-20 — **verification complete.** App suite 555 green after the
  retune sweep (meadow 80/×1 literals, atlas schema v3, travel confirmation
  flow, three-enemy woods, provisioned rematches under persistent HP,
  chance-rolled drop assertions, goldens regenerated and reviewed — the
  accepted-save fixture banks 455,361 so one 80-step gather still reaches
  the historical 455,281). stride_core 674, storage 108, health 143 green;
  analyze clean. S01A device checklists corrected to 80 / 1 / 10 alongside
  the s01a literal tests, as those tests demand.
- 2026-08-20 — **docs complete.** `DECISIONS/0023`,
  `GAME_BIBLE/SYSTEMS/09_EXPLORATION_PROGRESSION_LOOP.md`,
  `GAME_BIBLE/WORLD/02` implementation note, `RULES.md` P-9/P-10,
  `PROJECT_STATE.md` v2.11, OD-06 audio re-check note (sources still not
  recoverable — owner must resend). Awaiting the owner's physical-device
  acceptance pass.

## 8. Physical-device acceptance script

Install the Release build via `Scripts/ios/build-release-device.sh` (M-09:
Xcode Run installs Debug). A fresh save is best; an existing save migrates
to v7 with HP full and empty progress — both are valid starts. Walk a few
hundred real steps before sitting down to this.

1. **Launch.** The Adventure screen shows Haven's Rest, the walking strip
   (Total walked / Spent — no HP fact while healthy), the gather card
   *above* the compact "Goals — nothing tracked" card and the Notice Board.
2. **Sync steps.** The banner appears: "+N STEPS BANKED" with a few lines
   about what it made possible. It stays until you tap OK. Tap OK.
3. **Notice Board.** Three visible orders (e.g. Herbal Supplies,
   Carpenter's Request, Kitchen Stores). Accept one you can supply; its
   requirement chips show live have/need counts.
4. **Track it.** Tap Track on the accepted contract — the Goals card now
   shows it in the CONTRACT slot with remaining lines.
5. **Gather toward it.** Queue meadow gathers — **80 steps each, 1 herb, 10
   Foraging XP**. The queue runs at ~10 s a repetition and the contract
   chips tick up as herbs land.
6. **Deliver.** When the chips are green, Deliver. A held panel itemises
   consumed and rewarded lines (skill XP, character XP). The board slot
   rotates to a *new* order — completion rotated it; no timer ever does.
7. **Craft screen.** Pick something you cannot make yet (Wolfhide Jerkin —
   locked "taught by Woodland Aid"; contract-gated recipes show locked,
   project-gated ones are hidden). Tap "Track as Pursuit" on something
   craftable — the PURSUIT slot fills with a material plan and its
   remaining gather cost.
8. **World atlas.** Tap Frostmere. The panel quotes the way ("By way of
   Stonefall Mine · 4,400 steps in all, 1,400 for the first leg") and
   offers **Set as Journey**, not Travel. Set it — the JOURNEY slot shows
   the route and total, READY teal only when the bank covers it.
9. **Travel confirmation.** Select Whispering Woods (500). Tap Travel — it
   asks first: "Set out for Whispering Woods? · 500 steps · leaves N
   banked". Tap Stay: nothing spends. Tap Travel → Set out: the journey
   commits and the map plays a short spark along the road on arrival.
10. **The Woods.** Three encounter cards: Forest Wolf, Oakback Bear, Wild
    Boar — each with knowledge chips (UNSEEN at first), behavior words and
    rewards. The wolf's rewards line ends in `???` — a signature you have
    not earned knowledge of.
11. **Fight the wolf.** Win. The victory panel shows +30 XP and whatever
    actually dropped as framed rarity rows (drops are chance-rolled now —
    a pelt is likely, nothing is guaranteed except the XP).
12. **HP persists.** Back on the Adventure screen the walking strip now
    shows HP (it appears only when you are hurt). Fight the wolf again if
    you have the HP for it, or:
13. **Eat.** Inventory → the consumables group shows your HP and an Eat
    control on Herb Broth (8 HP). Eating at full is refused politely.
14. **Ranger Requests.** The Woods board holds bounties: accept Wolf
    Problem (×3). Note it counts only victories **after** acceptance.
15. **Boar and bear.** The boar (steady, 30 HP) is a fair fight; the bear
    (guarded, 55 HP, 11 attack) will likely defeat you — that is authored.
    Defeat retreats you to Haven's Rest, restored, having lost nothing.
16. **Safe-arrival heal.** Any travel into Haven's Rest fills HP free and
    instantly — the strip's HP fact disappears.
17. **Knowledge grows.** After ~3 wolf wins the wolf card reads STUDIED;
    after ~6 it reads KNOWN, the `???` becomes **Pristine Wolf Fang**, and
    a one-time +25 XP lands.
18. **Bounty delivery.** With three post-acceptance wolf wins, deliver Wolf
    Problem at the Woods board — the reward is the deterministic guarantee
    (wolf pelts), not a roll.
19. **Stonefall Mine** (1,000 from Woods). The Mine Ledger: orders,
    Goblin Bounty, Heat in the Deep, and the **Mine Hardware** contract
    that teaches the Reinforced Pickaxe. Goblins now dependably drop
    **Scrap Metal**; the salamander gapes (a bite effect) and drops Heat
    Scales.
20. **The Mill.** Back at Haven's Rest, the Notice Board's project tile:
    Restore the Haven's Rest Mill, STAGE 1/3, each stage a list of lines
    with your live counts. Contribute a partial amount — it commits
    exactly what you offered and the stage bar of *words* (contributed /
    required) advances. No XP bar anywhere on a settlement.
21. **Complete the Mill** (12 planks / 4 ingots / 6 logs + 3 broths across
    the stages — a real walking project). The completion panel is the
    major tier: the headline, "Haven's Rest — Struggling → Recovering",
    held until Continue.
22. **The Mill's effects.** Oak Plank now costs 2 logs (the 3-log recipe is
    gone), Oak Handle pairs exist, and the Carpenter's Commission order
    can appear on the board. Force-quit and relaunch: all of it holds —
    the effects are exactly-once and permanent.
23. **Rumors.** Completing Supplies for the Road (or the Lift/Shelter
    projects) adds a named future-tier landmark to the atlas — a place you
    have heard of, drawn on the map, not yet walkable.
24. **Frostmere** (3,000 from Stonefall — the Journey slot has been
    counting this down since step 8). It is *not* safe: HP does not
    restore on arrival. The Expedition Ledger holds Predator Control,
    Highland Survey, and the Cold Weather Kit (needs an owned Wolfhide
    Jerkin) which teaches the Frost-lined upgrade.
25. **The ram.** Fight the Mountain Ram — pack-art idle/charge/defeat, wool
    and horn drops. The Frost Lynx still prowls beside it.
26. **The Shelter.** Contribute toward Raise the North Shelter; completing
    it makes Frostmere safe (arrival now heals), changes it Exposed →
    Outpost, reveals the northern range rumor, and opens the Northern
    Expedition contract.
27. **Level check.** Character screen: HP current/max, level from the new
    curve (100/250/475…), attack/defence from equipment only — levelling
    up announced with "what changed" (+2 Max HP, healed to full).
28. **Kill-test the loop.** Mid-queue, mid-contract, mid-project: force
    quit at will. Nothing duplicates, nothing is lost, nothing expires.
    The game never asks you to come back — it only tells you what your
    next walk could do.

If any step disagrees with the phone in your hand, that disagreement — with
the step number — is the correction pass's input. Do not adjust the phone's
figures to the script; the script serves the phone.
