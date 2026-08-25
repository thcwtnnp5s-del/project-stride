# Regional Ecology — The Verge (first playable geographic slice)

**Status:** approved for Phase 2 implementation. Graduates `JOURNAL/OPEN_QUESTIONS.md`
**OD-02** from owner direction into canon, for this slice only.
**Extends:** `GAME_BIBLE/WORLD/01_WORLD_STRUCTURE.md`, which remains canonical for
the region list. Nothing here contradicts it; it adds the geography, the terrain,
and the economics the region list did not state.

This is a **game-economy geography document**, not lore. Where a sentence exists
only to be atmospheric it has been cut.

---

## 1. The governing rule

> The world is a coherent geographic and economic system, not a collection of
> themed zones. (`OD-02`)

Applied concretely, that means every resource in this document can be traced to a
physical reason it is *there* and not somewhere else, and every adjacency can be
traced to terrain. If a resource could be moved to another location without the
geography objecting, it is decoration and does not belong.

---

## 2. The physical setting

The first playable slice is **the Verge** — a frontier basin on the **western**
flank of a north–south mountain range, the **Stonefall Range**.

Three facts about that setting do all the work:

| Fact | What it determines |
|---|---|
| The range runs north–south, and weather comes off the western ocean | The west side is wet: grassland and broadleaf forest. The east side is a rain shadow. |
| The range is a granite intrusion into older country rock | Copper and tin sit in the contact zone at the **foothills**, not on the plain and not at altitude |
| Altitude rises west→east into the range, then crosses a pass | Broadleaf → conifer → treeline → alpine, in that order and no other |

Everything below follows from those three.

### Why the ores are where they are

Copper and tin are put in the same district deliberately and not arbitrarily:
cassiterite (tin) and copper sulphides both associate with granite intrusions and
their contact aureoles. Stonefall Mine sits where the granite meets the older
rock, which is exactly where a prospector would dig. Bronze is therefore a
**local** alloy — the player finds both halves of it in one district — which is
what makes Stonefall the economic engine of the slice rather than one more
gathering stop.

### Why the timber splits

Oak is a temperate lowland broadleaf; pine is a cold-climate conifer. Putting
both in one forest would be the themed-zone failure OD-02 names. So the forest
is oak, the alpine region is pine, and **the wood tiers are a geographic
progression rather than a numeric one** — the better timber is further away and
higher up because that is where that tree grows.

---

## 3. Region graph

```text
                       ┌──────────────┐
                       │  FROSTMERE   │  alpine basin, frozen tarn
                       │   alpine     │  ~1,400 m, above the treeline
                       └──────┬───────┘
                              │  Rimeward Pass
                              │  1,500 steps   ← the mountain crossing
                              │
   ┌──────────────┐    ┌──────┴───────┐
   │  FORGOTTEN   │    │  STONEFALL   │  granite contact zone
   │   HOLLOW     │    │    MINE      │  foothills, 400–700 m
   │ sunken vale  │    └───┬──────┬───┘
   └──────┬───────┘        │      │
          │ 1,300          │ 700  │ 800
          │                │      │
   ┌──────┴────────────────┴──┐   │
   │    WHISPERING WOODS      │   │
   │  temperate broadleaf     │   │
   │  wet upland, 150–400 m   │   │
   └──────────┬───────────────┘   │
              │ 600               │
   ┌──────────┴───────────────────┴──┐
   │        HAVEN'S REST             │
   │  temperate grassland, river     │
   │  frontier hub, 80 m, on the     │
   │  Meadowrun                      │
   └─────────────────────────────────┘
                    │
                    ╎ (no route yet)
              ┌─────┴──────┐
              │ THE DUST   │  future expansion exit — see §8
              │  REACH     │  rain shadow, east of the range
              └────────────┘
```

**Five locations. Four environmental identities:** temperate grassland,
temperate broadleaf forest (Whispering Woods and Forgotten Hollow share it),
mountain foothills, and alpine.

### Adjacency, and why each edge exists

| Route | Steps | Why the terrain allows it |
|---|---:|---|
| Haven's Rest ↔ Whispering Woods | 600 | The plain rises gently into the wet uplands. The shortest and easiest route in the slice. |
| Haven's Rest ↔ Stonefall Mine | 800 | The ore road, cut straight from the settlement to the diggings along the Meadowrun's north bank. |
| Whispering Woods ↔ Stonefall Mine | 700 | The forest thins into scrub as the ground steepens; the treeline meets the foothills. |
| Whispering Woods ↔ Forgotten Hollow | 1,300 | Deep into the vale, off the tracks. Long because there is no road, not because it is far. |
| Stonefall Mine ↔ Frostmere | 1,500 | **Rimeward Pass.** The only crossing of the range in the slice, and the most expensive ordinary route — a mountain crossing should be. |

There is deliberately **no** Haven's Rest → Frostmere edge. The alpine basin is
reached through the mining district or not at all, which is what makes Stonefall
a hub rather than a cul-de-sac and gives the mountain range a job in the graph.

---

## 4. The locations

### Haven's Rest — frontier hub

| | |
|---|---|
| **Terrain** | Temperate grassland, on the Meadowrun river, 80 m |
| **Purpose** | Onboarding, the starting loadout, crafting, the safe return point |
| **Natural resources** | Meadow herb — river-meadow flora, the least specialised thing in the world |
| **Skills** | Foraging (starter) |
| **Tier** | 1 — no gate of any kind |
| **Visual identity** | Open sky, low timber buildings, fenced pasture, the river |

The hub yields the one resource that needs no tool and no travel, which is what
makes it the place a player with 200 steps can still do something.

### Whispering Woods — temperate broadleaf forest

| | |
|---|---|
| **Terrain** | Wet upland broadleaf forest, 150–400 m |
| **Purpose** | The first travel decision; Woodcutting's home; the second forage climate |
| **Natural resources** | Oak (structural timber), duskcap fungus (shade and leaf litter) |
| **Skills** | Woodcutting (starter), Foraging (second rung) |
| **Tier** | 2 — reached by travel only |
| **Visual identity** | Closed canopy, dense trunks, shafts of light, leaf litter |

Fungus rather than a second herb, deliberately: the woods are dark and damp, so
what grows on the floor is not what grows in an open river meadow. The forage
skill therefore reads as *climate knowledge* rather than as a number.

### Stonefall Mine — mountain foothills

| | |
|---|---|
| **Terrain** | Granite contact zone in the foothills, 400–700 m |
| **Purpose** | Bronze — both halves of it. The economic engine of the slice. |
| **Natural resources** | Copper ore, tin ore |
| **Skills** | Mining, and by consequence Smithing |
| **Tier** | 2 — reached by travel only |
| **Visual identity** | Cut rock, spoil heaps, timbered adits, thin scrub |

### Forgotten Hollow — sunken vale (challenge zone)

| | |
|---|---|
| **Terrain** | A deep, damp, overgrown fold in the forest floor |
| **Purpose** | The first *earned* location — proof that preparation works |
| **Natural resources** | Hollow root |
| **Skills** | Foraging (top rung of the slice) |
| **Entry requirement** | **Bronze Sword** — crafted, not found |
| **Tier** | 3 |
| **Visual identity** | Sunken, close, overgrown, older than the frontier |

The only location in the slice behind an item gate, and the gate is the full
Mining → Smithing chain. That is the intended shape: the hollow is where
progression is *tested*, not where it is built.

### Frostmere — alpine basin **(new in Phase 2)**

| | |
|---|---|
| **Terrain** | Alpine basin around a frozen tarn, ~1,400 m, at and above the treeline |
| **Purpose** | The late-slice region. Proves that skill level and crafted tools open places. |
| **Natural resources** | Frostpine (cold-climate conifer), rime blossom (alpine cushion flora) |
| **Skills** | Woodcutting (top rung), Foraging (third rung) |
| **Entry requirement** | None — the gate is the **1,500-step pass**, not an item |
| **Tier** | 3 |
| **Visual identity** | Snow, frozen water, dark conifer below the treeline, bare rock and sky above it |

Frostmere is gated **twice, and neither gate is an entry requirement**:

- getting there costs the most expensive route in the world, and
- both of its nodes refuse a player who arrives unprepared — the pine needs
  Woodcutting 8 *and* a tier-1 axe, the blossom needs Foraging 5.

That is deliberate. A player can always *reach* Frostmere and look at it; what
they cannot do is harvest it early. Locking the door would have taught them
nothing; letting them stand in front of a tree they cannot fell tells them
exactly what to go and do.

---

## 5. Resource → skill → consumer map

Nothing is gathered that nothing consumes. The content loader enforces this
(`content_loader.dart`, `_validateWorld`); it is restated here because it is also
a design rule and not only a check.

| Resource | Where | Skill | Lvl | Tool | Consumed by |
|---|---|---|---:|---|---|
| Meadow Herb | Haven's Rest | Foraging | 1 | — | Herb Broth, Duskcap Skewer, Hearty Stew |
| Oak Log | Whispering Woods | Woodcutting | 1 | axe t0 | Oak Handle |
| Duskcap | Whispering Woods | Foraging | 3 | — | Duskcap Skewer, Frostbloom Tea |
| Copper Ore | Stonefall Mine | Mining | 1 | pickaxe t0 | Bronze Ingot |
| Tin Ore | Stonefall Mine | Mining | 3 | pickaxe t0 | Bronze Ingot |
| Rime Blossom | Frostmere | Foraging | 5 | — | Frostbloom Tea |
| Pine Log | Frostmere | Woodcutting | 8 | **axe t1** | Pine Plank |
| Hollow Root | Forgotten Hollow | Foraging | 10 | — | Hearty Stew |

**Foraging is the skill that travels.** Its four nodes sit in four different
climates at four different levels, so levelling Foraging is literally the act of
going somewhere colder, darker, or further. That is the clearest expression of
OD-02 in the slice, and it is why Foraging — the skill with no tool — is not the
trivial one.

---

## 6. Progression tiers

| Tier | Locations | What the player is doing |
|---:|---|---|
| 1 | Haven's Rest | Learning that steps buy actions |
| 2 | Whispering Woods, Stonefall Mine | Learning that places have different things, and that travel costs |
| 3 | Frostmere, Forgotten Hollow | Spending crafted capability to open harvests and places |

---

## 7. Settlement economics

Haven's Rest is the only settlement, and its position is economically legible: it
sits at the river on the plain, at the junction of the forest track and the ore
road. A frontier settlement exists where routes meet and water runs, and this one
does. Its trade is timber down from the woods and ore down from the foothills —
which is why the crafting happens here and the digging does not.

**No merchants, no currency.** (`DECISIONS/0004`.) The settlement is an economic
*junction*, not an economic *market*.

---

## 8. Future expansion exits

Named so the geography has somewhere to grow, and deliberately **not built**:

| Exit | Direction | What it would be |
|---|---|---|
| **The Dust Reach** | East, beyond the range | The rain shadow. Arid grassland and badlands — the geographically correct place for a dry region, because the mountains take the rain out of the westerlies before it gets there. Reached through Rimeward Pass and down the eastern scarp. |
| **The Meadowrun mouth** | West, downriver | Coast and estuary. Where fishing would belong, if fishing is ever added. |
| **Deeper Stonefall** | Down | Iron and the metal tier above bronze. Depth, not distance. |

> **Amendment (World Map Expansion Refinement 02, 2026-08-25).** The painted
> atlas the owner accepted on device across World Map Polish 03 and this
> round fixes the opposite compass: the **Worldspine mountain wall stands
> west** (now opened by a caravan pass at Wayfarer's Pass), the **open ocean
> lies east**, and the **estuary coast runs south**. The two directional
> exits above are therefore superseded as *directions* while remaining live
> as *ideas*: a dry rain-shadow region would now sit **beyond the
> Worldspine, west**, and the estuary/coast identity is already painted
> **south**. This is recorded here rather than silently diverging (G-7);
> re-founding the exit table onto the painted geography is the World
> Designer's task when any of these regions is actually built.

The dry region the Phase 2 brief offered as optional is **recorded here rather
than built**. It is the right place for it geographically, and adding a fifth
environmental identity would have widened the slice without deepening it — the
brief's own instruction was a coherent bounded vertical slice, not the whole
eventual world. This is the scope call, stated so it reads as a decision rather
than an omission.

**Fishing is not added.** A frozen tarn and a river exist, and that is precisely
the reason to be careful: the brief says not to introduce Fishing merely because
a lake exists, and nothing else in the slice needs it.

---

## 9. What is provisional

Every step cost and every skill gate in this document is **PROVISIONAL Phase 2
test balance**, chosen so the owner can produce useful feedback within days.
See `MILESTONES/PLAYABLE_PHASE_2_PLAN.md` §Balance. The geography is not
provisional; the numbers laid over it are.
