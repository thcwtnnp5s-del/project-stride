# REGIONAL_CONTENT_PACK_01 — Content proposals

```
STATUS: DESIGN PROPOSALS · NOT CANON · NOT IMPLEMENTED
Written by the parallel support workstream while World & Reward Depth 01 ran concurrently.
Every figure below is a placeholder for the owner to ratify or strike; nothing is in any content
file, schema, enum, or save. Rarity words use the owner's vocabulary (Uncommon gray · Common green ·
Rare blue · Epic purple · Legendary orange) and are recorded here and in the manifest only.
Ids are PROPOSED and follow the existing `enemy.` / `item.` / `recipe.` / `location.` convention.
```

**Based on HEAD `dc8f6f6`.** The primary session may have changed `enemies.json`, `items.json`,
`recipes.json`, rarity, `encountersPerVisit`, `LocationKind`, or the atlas since — re-read before
integrating anything here (see the handoff).

The governing question (`CLAUDE.md`): *does this make the player's real-world movement feel more
meaningful without creating pressure or busywork?* Every proposal below answers it the same way —
it gives a **walked-to region one more reason to be walked to again**, and nothing here is timed,
decays, or punishes absence (`RULES.md` P-4, P-5).

---

## 1. Enemy candidates

Seven candidates across the four dangerous regions; one concept-only. All are animals or arthropods
that would live in the terrain `GAME_BIBLE/WORLD/03` describes. No undead, no demons, no slimes.
Figures are in the shipped `COMBAT/02` §5 idiom (health · attack · defence · behaviour · xp · per
visit) and are **provisional placeholders**, scaled against the shipped wolf 20/4/0, goblin 32/8/3,
lynx 30/9/2, guardian 60/11/4. Art status is in §8 / `INTEGRATION_MANIFEST.md`.

| Proposed id | Name | Region | Role in the region's ladder | Behaviour | hp / atk / def · xp · per visit | Drops (proposal) |
|---|---|---|---|---|---|---|
| `enemy.bristleback_boar` | Bristleback Boar | Whispering Woods | the **second** Woods fight — above the wolf, needs bronze or the Wolfhide Jerkin to be comfortable | `steady` (one goring charge a turn; hits harder than the wolf, fewer times) | 28 / 7 / 2 · 50 · 2 | `item.boar_tusk` ×1 @40 %, `item.duskcap` ×1 @50 % |
| `enemy.oakback_bear` | Oakback Bear | Whispering Woods | the Woods' **heavy** fight; a "mini-elite" above goblin weight, below the guardian | `guarded` (heavy swipe every third turn, telegraphed) | 48 / 10 / 3 · 110 · **1** | `item.bear_pelt` ×1 @60 %, `item.oak_log` ×2 @50 % |
| `enemy.adit_bat` | Adit Bat | Stonefall Mine | a **light** Mine fight for a player not yet ready for the goblin; flurry, low hp | `flurry` (two light bites) | 18 / 5 / 0 · 35 · 2 | `item.copper_ore` ×1 @60 % — **no new material**: it exists for combat variety, not loot |
| `enemy.scree_crawler` | Scree Crawler | Stonefall Mine | the Mine's **armoured** fight — high defence tests the player's attack number directly | `steady` | 34 / 6 / **6** · 70 · 2 | `item.granite_chitin` ×1 @45 %, `item.tin_ore` ×1 @35 % |
| `enemy.mire_salamander` | Mire Salamander | Forgotten Hollow | a **normal** Hollow fight (the Hollow has only its boss); drops the Hollow's forage so a fighter below Foraging 10 still leaves with root | `steady` | 36 / 9 / 3 · 90 · 2 | `item.hollow_root` ×1 @70 % — **no new material** |
| `enemy.hollow_weaver` | Hollow Weaver | Forgotten Hollow | the Hollow's **flurry** fight and the silk source | `flurry` | 30 / 8 / 2 · 85 · 2 | `item.gloom_silk` ×1 @45 %, `item.duskcap` ×1 @40 % |
| `enemy.frosthorn_ram` | Frosthorn Ram | Frostmere | Frostmere's **second** fight beside the lynx; steady, heavy, the horn source | `steady` | 36 / 10 / 3 · 95 · 2 | `item.ram_horn` ×1 @40 %, `item.rime_blossom` ×1 @40 % |
| *(concept only)* `enemy.great_elk` | Great Elk of the Tarn | Frostmere | a possible Frostmere **perilous** encounter (boss tier, `1` per visit) so the alpine basin, like the Hollow, has a fight that asks for everything | `guarded` | ~70 / 12 / 4 · 180 · 1 | *undecided — deliberately no material until a use exists* |

Design notes:

- **Two fights per region is a ladder, not a roster.** Each pair gives the region one fight the
  player can take early and one they return for — the same shape the Woods already has with the
  wolf (first fight) and nothing above it.
- **Not every enemy drops a new material.** The bat and the salamander drop existing items so the
  material set stays small (`§2`). The salamander is the most deliberate: `hollow_root` gates
  Hearty Stew behind Foraging 10, and a fighter who has the Bronze Sword but not Foraging 10 can
  still earn some — two routes to one ingredient, both walked.
- **`encountersPerVisit`** follows `DECISIONS/0021`: normal 2, heavy/boss 1. No new recurrence
  policy.
- **Behaviours reuse the three that exist** (`steady` / `flurry` / `guarded`). Nothing here needs a
  fourth.
- **Boss-ness.** Only the Great Elk is proposed as `isBoss`; the Oakback Bear is a heavy normal
  (per-visit 1 but not a boss), which is the "smaller number, no framework" case 0021 names.

## 2. Material candidates (combat-specific)

Five, all Rare, all from one enemy, all with exactly one consumer in §3. Nothing is vendor trash:
if its recipe is struck, strike the material too.

| Proposed id | Display name | Source | Suggested rarity | Tier | What it is for | Icon |
|---|---|---|---|---|---|---|
| `item.boar_tusk` | Boar Tusk | Bristleback Boar, Woods | Rare | 1 | the pommel of the Bronze Longsword (§3) | `icon_boar_tusk_48` |
| `item.bear_pelt` | Bear Pelt | Oakback Bear, Woods | Rare | 1 | the body of the Bearhide Coat (§3) | `icon_bear_pelt_48` |
| `item.granite_chitin` | Granite Chitin | Scree Crawler, Mine | Rare | 1 | the plating on the Reinforced Bronze Pickaxe (§3) | `icon_granite_chitin_48` |
| `item.gloom_silk` | Gloom Silk | Hollow Weaver, Hollow | Rare | 1 | the grip wrap of the Bronze Longsword (§3) | `icon_gloom_silk_48` |
| `item.ram_horn` | Ram Horn | Frosthorn Ram, Frostmere | Rare | 1 | the binding ring of the Hornbound Bronze Axe (§3) | `icon_ram_horn_48` |

Rarity rationale, matching the shipped table's "tier of effort": each is a 35–60 % drop from a
fight that needs bronze, the same bracket as the shipped Frost Lynx Pelt (Rare). None is Epic —
Epic is for the made thing, not the part.

## 3. Equipment / crafting candidates

Four items — one weapon step, one armour step, two tool upgrades. No 20-tier ladder. Stats are
placeholders positioned against the shipped power numbers (bronze sword 9 · bronze chestplate 7 ·
frost-lined jerkin 6 · bronze tools power 4 tier 1).

| Proposed id | Name | Slot / kind | Proposed recipe (skill L) | Power · tier | Suggested rarity | Progression role | Icon |
|---|---|---|---|---|---|---|---|
| `item.bronze_longsword` | Bronze Longsword | weapon | Smithing 6: 4 × bronze_ingot + 1 × boar_tusk + 1 × gloom_silk | 12 · 1 | Epic | the one weapon step inside the bronze age; needs Woods **and** Hollow **and** Mine — the weapon that asks for the whole Verge | `icon_bronze_longsword_48` |
| `item.bearhide_coat` | Bearhide Coat | armor | Smithing 6: 3 × bear_pelt + 2 × bronze_ingot + 1 × oak_handle | 9 · 2 | Epic | the armour step above the Bronze Chestplate; hide over bronze plates; a reason to go back to the Woods at level 5+ | `icon_bearhide_coat_48` |
| `item.reinforced_bronze_pickaxe` | Reinforced Bronze Pickaxe | tool, pickaxe | Smithing 5: 1 × bronze_pickaxe + 2 × granite_chitin | 6 · **2** | Epic | the **tier-2 pickaxe** — nothing in the current world needs it, which is the point: it is the key to the iron seam in §6 (Deeper Stonefall). Fight the thing that lives in the deep rock to open the deep rock. | `icon_reinforced_bronze_pickaxe_48` |
| `item.hornbound_bronze_axe` | Hornbound Bronze Axe | tool, axe | Smithing 5: 1 × bronze_axe + 2 × ram_horn | 6 · **2** | Epic | the **tier-2 axe**, symmetric with the pickaxe; a future hard timber (ironwood in the Hollow, or a tier-2 frostpine node) would ask for it | `icon_hornbound_bronze_axe_48` |

Explicitly **not** proposed: a fifth slot, affixes, sockets, item levels, durability, set bonuses,
random rolls (`DECISIONS/0021` §4). Two tool upgrades with no current consumer is a
**deliberate hook**, labelled as one — strike them if §6 is struck.

## 4. Regional content graph

```
WHISPERING WOODS
  Forest Wolf ─────► Wolf Pelt ──► Wolfhide Jerkin ──► Frost-lined Jerkin (shipped)
  Bristleback Boar ► Boar Tusk ──┐
  Oakback Bear ────► Bear Pelt ──┼──► Bearhide Coat ....... armour step → safer Hollow/Frostmere fights
                                 │
FORGOTTEN HOLLOW                 │
  Hollow Weaver ───► Gloom Silk ─┴──► Bronze Longsword ..... weapon step → Great Elk / future iron-age fights
  Mire Salamander ─► hollow_root (existing) ─► Hearty Stew (shipped)  ... a fighter's route to the Hollow's forage
  Hollow Guardian ─► Hollow Sigil (shipped, still UNRESOLVED what it is)

STONEFALL MINE
  Cave Goblin ─────► ore (shipped)
  Adit Bat ────────► copper ore (existing)               ... light fight, no new item
  Scree Crawler ───► Granite Chitin ─► Reinforced Bronze Pickaxe (tier 2) ─► [Deeper Stonefall: iron seam] ─► iron age

FROSTMERE
  Frost Lynx ──────► Lynx Pelt (shipped) ─► Frost-lined Jerkin
  Frosthorn Ram ───► Ram Horn ─► Hornbound Bronze Axe (tier 2) ─► [a tier-2 timber node, future]
  Great Elk (concept) ─► — (no material until a use exists)
```

Reading the graph: every new material has exactly one consumer; the two Epic pieces of gear each
need **two regions' fights** (Longsword: Woods + Hollow; Coat: Woods ×2 + Mine ore), so the "reason
to revisit" is built in; the tool upgrades point at §6 rather than at nothing.

## 5. World / environment asset intent

Every environmental asset is classified so nobody reads interaction into a picture:

| Class | Meaning | Examples in this pack |
|---|---|---|
| **visual geography** | paints the world; never tappable; no label, or a `landmark` minor label at most | plank bridge, waystone, ruined corner, charcoal clamp, ore cart on rails, cold camp, deer group, elder oak, alpine hut |
| **possible future location** | a named `landmark` (tier `future`) that a later milestone *might* open; non-interactive now | ruined watchtower (east moor, withheld east tile), the hamlet cluster (south tile's farms) |
| **proposed interactive location** | §6 only, and none of them is drawn into the atlas by this pack | Deeper Stonefall, the Old Ford |

## 6. Future location candidates (high-value only)

Two. Both fill a gap the content graph shows; neither is built.

### 6.1 Deeper Stonefall — the Lower Gallery (`location.lower_gallery`, proposed)

- **Where:** *down*, not across — reached from Stonefall Mine (a new connection, ~400 steps: a
  descent, short but not free). `GAME_BIBLE/WORLD/03` §8 already names "Deeper Stonefall — iron
  and the metal tier above bronze. Depth, not distance."
- **Why go:** the **iron seam** (`resource_node.iron_seam`, Mining ~8, pickaxe **tier 2**) — the
  first metal above bronze, and the only place the Reinforced Bronze Pickaxe has a job.
- **Supports:** the whole iron age the Systems docs imply (iron ingot → iron sword/axe/pickaxe),
  which is not designed here; and a home for the Scree Crawler at higher density if the Mine's
  upper level keeps the goblin and the bat.
- **Class:** **eventual playable location** — `worksite` kind by the derived rule (a node needs a
  pickaxe), `isSafe: false`.
- **Gate:** the tool (tier-2 pickaxe), not an item gate — "letting them stand in front of a seam
  they cannot dig tells them exactly what to go and do" (WORLD/03 §4 logic).
- **Not a dungeon.** One location, two nodes, one enemy. No rooms.

### 6.2 The Old Ford (`location.old_ford`, proposed)

- **Where:** on the Meadowrun between Haven's Rest and Whispering Woods — a waypoint on the
  existing 600-step edge (Haven 250 → Ford 350 → Woods), so the route's total cost is unchanged.
- **Why go:** the first **safe** place outside the hub — a `haven`-kind rest point (fits the
  derived kind: no node needs a pickaxe, no boss; would need `isSafe: true`), which gives the
  Q-06 persistent-HP question somewhere to land if the owner opens it, and gives a defeated
  player in the Woods a nearer retreat than Haven's Rest.
- **Supports:** the plank bridge / waystone / cold camp props as its vignette; the hare and
  butterfly fauna; the hamlet cluster is *not* here (no second settlement — WORLD/03 §7).
- **Class:** **future locked destination** first (a named landmark with a `future` tier label),
  **eventual playable location** if Q-06 opens. Until then it is a picture.
- **Caution:** this splits an existing edge, which touches the route graph the primary session
  owns. Propose, do not draw.

Rejected on purpose: a sixth environmental identity (Dust Reach, estuary) — widening, not
deepening; any "arena"; any location whose only content is a fight.

## 7. Ambient fauna (visual ambience only)

| Sprite | Biome | Where it could live | Scale made |
|---|---|---|---|
| meadow butterfly | Haven's Rest | stage overlay drifting across the ambient scene; atlas overlay over the meadow | 24 (concept), 16 (stage) |
| woodland songbird on a twig | Whispering Woods | a perched beat in the ambient stage far plane | 32 (concept), 16 (stage) |
| bat in flight | Stonefall Mine | a looping flit near the adit on the atlas or the mine vignette | 32, 16 |
| crow on a mossy stump | Forgotten Hollow | a still beat in the Hollow vignette; one head-turn | 32, 16 |
| ptarmigan on snow | Frostmere | a still beat on the snowfield | 32, 16 |
| brown hare | Haven's Rest / Woods edge | a sit-and-twitch beat at the meadow's edge | 32, 16 |

Rules: no pet system, no hunting, no XP, no resource, no tap target, nothing above a head. Density:
**one** fauna beat per scene at most — absence is the default.

## 8. Readiness summary (after blind QA — the per-asset record is `INTEGRATION_MANIFEST.md` §H)

| Family | Ready for integration | Concept-only / withheld |
|---|---|---|
| Enemies | Boar, Bear (with attack2), Ram, Salamander (full sets); Crawler (idle + attack) | Weaver (idle only reads), Adit Bat (identity), Great Elk (no art) |
| Materials | Boar Tusk, Bear Pelt, Gloom Silk (c3), Ram Horn (note) | Granite Chitin (icon withheld after four rounds — the material stands as a proposal) |
| Gear | Bronze Longsword, Bearhide Coat (note), Hornbound Bronze Axe | Reinforced Bronze Pickaxe (icon withheld after three rounds) |
| World props | bridge, waystone, ruin corner (note), headframe, ore cart c2 (note), elder oak, alpine hut, cold camp, tower, hamlet | charcoal clamp (implied station), deer group (rejected) |
| Vignettes | all five (set-coherence note on Haven's Ford) | — |
| Fauna | all concept stills and loops; 16-px butterfly, songbird, hare, crow, ptarmigan (note) | bat_16 |
