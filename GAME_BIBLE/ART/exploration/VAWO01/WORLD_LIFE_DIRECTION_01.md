# World Life Direction 01 — VAWO01

**Role:** DIR-J · Fantasy Worldbuilding / World Atlas Life Director
**Date:** 2026-09-01 · **Branch:** `presentation-combat-evolution-01`
**Inputs (read, not re-derived):** `MILESTONES/evidence/VAWO01/wave0/FOUNDATION_F_ATLAS.md`,
`MILESTONES/evidence/VAWO01/wave0/FOUNDATION_K_PERFORMANCE.md`,
`GAME_BIBLE/ART/ART_DIRECTION.md`, `assets/content/v1/atlas/atlas_layout.json`,
`assets/art/v1/world/atlas_base.png` (read as an image for this pass).

This document makes calls. It does not present options.

---

## 0 · IP safety — the absolute constraint, stated first

**Nothing authored under this direction may reproduce, imitate, or approximate a
copyrighted franchise design.** The owner's brief uses shorthand ("Elsa's
tower"); the shorthand names an *energy*, never a source.

Three specific exclusions, each with the original replacement named in §5:

| Shorthand | What is FORBIDDEN | What is authored instead |
|---|---|---|
| "snow-queen tower" | Disney *Frozen* ice palace: four-fold snowflake plan, transparent blue crystal architecture, spiral crystal stair, cantilevered snowflake balcony, ice-blue/lavender-with-magenta palette, any blue-gowned figure | **Rimespire** — a dark Nordic *stave* tower **built and then frozen over**. Accretion, not crystal architecture (§5.1) |
| "fairy castle" | Disney castle silhouette (clustered slender conical-roof turrets on a rock, pastel blue/pink); Tinker Bell / Pixie Hollow imagery; winged-girl fairies; leaf dresses | **Lanterngard** — a low, wide, *grown* ring of standing stones colonised by trained blackthorn, roofed in bark and thatch, hung with lanterns. Horizontal and organic — the opposite of the turret cluster (§5.2) |
| "dark house / lightning" | Recognisable haunted houses: the *Psycho* Bates mansard tower, the Addams Family house, the Amityville quarter-round eyebrow windows | **The Black Gable** — one tarred-board Hebridean croft on a bare knoll under a permanent shelf of weather (§5.3) |

The dragons are original by construction: three deliberately different animals,
not three palettes of one animal (§4).

**A second, non-obvious constraint carries the same weight.** `ART_DIRECTION.md`
**L-16** reserves teal `#58D6C0` system-wide for walking and steps. A large
glowing teal-green feature on the world map muddies that meaning even if the hex
differs by a few points. **Ruling: no asset authored under this direction uses
the teal-green family at all.** The aurora is violet, rose and gold — no green.
The storm drake's arc is a white core in a violet-blue halo, not cyan. The
Rimespire crown light is a cold pale gold, not ice-cyan.

---

## 1 · The ecology map

### 1.1 The world as painted (read from `atlas_base.png` this pass)

All coordinates are **1024² atlas pixels**. World px = atlas px × 6.

| Region | Atlas extent | What is painted there | Life it owes |
|---|---|---|---|
| Polar shelf / pack ice | x 0–1024 × y 0–260 | Cracked pack ice, teal melt pools, floes; NW snow peaks at (40–130, 60–200) | **Nothing. It is the deadest quadrant of the map.** |
| NE open ocean | x 850–1024 × y 0–200 | Empty deep teal, ice edge around x 830–880 | Nothing |
| Ice/ocean margin | x 780–880 × y 60–200 | Ragged floe edge meeting sea | Nothing |
| Volcano massif | x 590–820 × y 270–460 | Black basalt, lava veins, two watchtowers | Eruption overlay only |
| Frostmere / Glasslake | x 380–570 × y 258–400 | Glacial cirque, frozen lake | yeti2, 3 snow flurries |
| Longwood / north taiga | x 250–420 × y 230–340 | Conifers scattering onto ice | skydragon corridor |
| Great forest | x 250–430 × y 330–780 | Dense closed canopy | bear2, fire3, 2 tree rustles, 3 forest mists |
| Western plains / moor | x 0–260 × y 300–700 | Pale olive plain, sparse trees, tan road from the west edge at y≈530 | stag, caravan |
| Settled belt | x 420–600 × y 460–670 | Haven's Rest, Stonefall adit, Forgotten Hollow, stone circle, Amberfield town + gold fields | 2 smoke columns |
| Delta / marsh | x 480–700 × y 600–800 | Braided river, reeds, silt | ripple_delta, flock |
| East bay / isles | x 620–870 × y 470–620 | Tern Isles, Wanderer's Isles, Saltreach Light | ripple_coast, nessie, whale, ship |
| SE cape | x 700–830 × y 700–830 | Wooded headland, beach toe | **Nothing** |
| South strand | x 100–800 × y 800–870 | Sand | Nothing |
| SW deep forest | x 100–400 × y 850–1010 | Dark canopy on lime ground | Nothing |

**Where the world is dead:** the entire north (25 % of the atlas), the whole
eastern and far-western outer ring, the SE cape, and the south below the strand.
**Where the world is already busy:** x 276–706 — every one of the 19 always-on
overlays sits in that 430 px-wide band.

That single fact governs every placement below.

### 1.2 Ecological assignment

| Family | Belongs where | Why |
|---|---|---|
| Wolves | Great forest south edge, **Wolfwood** (334,686) | The landmark is literally named for them and has no art. Pack behaviour exists nowhere on the map |
| Deer | Whispering Woods glade | A stag already reads at (156,493). Lowest novelty of the mammal asks — **reserve**, not in the ten |
| Bear | Great forest | `bear2` already there. Second bear = same silhouette, different tree — **rejected** |
| Fairies | Western moor (their court) **and** Deepwood Shrine (304,556) | The court is where they live; the shrine is the evidence that they get out. Splitting them makes the fae a *world phenomenon*, not one building |
| Yeti / ram / lynx | Frostmere basin, Worldspine ridge | `yeti2` already runs continuously. Ram and lynx are real ecology depth — **reserve** |
| Crows / eerie fauna | **Forgotten Hollow** (561,551) | The only playable settlement with no life at all. Corvids do double duty: eerie fauna + settlement life |
| Caravans | The **painted** western valley road, x 0–130 × y 495–580 | The existing caravan rides the same road 130 px east. Two wagons on one road reads as a trade route |
| Dragons | Mountains and the sea beyond them | Red = the volcano's owner. Blue = the storm over the SE cape. Green already owns the north forest |
| Settlement life | Smoke, a passing wagon, birds over a roof | **Never a walking humanoid** — see §6 |
| Magical features | The three landmarks, the aurora, the fae motes | The map today contains **zero** magic. This is its largest absence |

### 1.3 Placement verification against LIST A (protected)

Every placement below was checked against the A-4 hard core (x,y ∈ [276,747]),
the 20 px rim band, all 15 registry goldens, every existing overlay box, and the
B1–B11 queued-repaint zones.

| # | Asset | Atlas box | A-4 core | Golden | Existing overlay box | Queued repair zone |
|---|---|---|---|---|---|---|
| 1 | `overlay_redwyrm` | 736–820 × 306–346 → 792–876 × 280–320 | air over core edge — **no ground** | flies over `volcano_east_cliff`; air sprite, freezes nothing | volcano box 668–732 — clear | — |
| 2 | `overlay_stormdrake` | 832–924 × 688–714 → 787–879 × 702–728 | outside | clear of `wanderers_isles_e`, flotsam rect (886–910, 622–662) | ship 765–805 × 645–680 — clear | — |
| 3 | `overlay_aurora` | 700–796 × 28–76, drifts x, wraps | outside | none in y < 175 | none | passes over B5; **air sprite, freezes nothing** |
| 4 | `landmark_rimespire` | 794–854 × 60–156 | outside (x > 747) | clear of `cinder_skerries`, `ne_iceberg` | none | sits over D-11 / D-16 — **carries its own base, so it does not freeze that ground** |
| 5 | `overlay_rimespire_aura` | 800–848 × 44–100 | outside | clear | none | as above |
| 6 | `landmark_lanterngard` | 34–98 × 352–424 | outside (x < 276) | clear of `west_caravan_road` (y ≥ 495) | stag 156–184 — clear | below B11 (y ≥ 352) |
| 7 | `overlay_fae_court` | 38–94 × 340–388 | outside | clear | none | touches B11's lower edge — air sprite |
| 8 | `overlay_fae_motes` | 284–324 × 536–576 | **inside core — air sprite, no ground crop** | clear | mist#1 436–484, rustle_a 596–644, fire3 624–676 — all clear | — |
| 9 | `overlay_wolfpack` | 302–350 × 698–746 | **inside core — in-place scene (see §1.4)** | clear | rustle_b starts x 352 — 2 px clear; mist#3 296–392 × 676–724 **overlaps, deliberately** | — |
| 10 | `overlay_crows` | 536–576 × 506–538 | inside core — air sprite | clear | smoke#2 557–573 × 490–504 — clear | — |
| 11 | `overlay_oxcart` | 96–120 × 528–550 → 74–98 × 532–554 | outside | ring-2 valley road is FC/SOFT, not a golden; alpha sprite freezes nothing | caravan 199–245 — 100 px clear | — |
| 12 | `landmark_black_gable` | 760–812 × 730–786 | outside (x > 747) | clear of `south_strand_e` (y < 810), flotsam (748–796, 844–906) | ship, whale — clear | covers D-20 (740–775 × 720–765); own base, no freeze |
| 13 | `overlay_stormhouse` | 758–814 × 712–784 | outside | clear | none | as above |

**Marker and label clearance checked:** Forgotten Hollow marker circle
549–573 × 539–563 — crows clear it by 1 px above. Haven's Rest 444–468 × 509–533
and Stonefall 554–578 × 484–508 — nothing new enters either. The Wolfwood label
anchor (334,686) sits 12 px above the wolf box, not on it.

### 1.4 The grounding rule this pass establishes

An **in-place scene** (a 64² crop of the master edited by PixelLab and
composited back through a content box — the `bear2` / `yeti2` / `fire3`
technique) makes the atlas pixels under its box permanently un-repaintable: the
overlay's frame 0 *is* the old painting, and repainting the ground makes the
sprite pop a rectangle of it. The retired `fire2` is the recorded proof.

> **Ruling J-1.** A grounded in-place scene may be anchored **only inside the
> A-4 hard-frozen core** (x,y ∈ [276,747], which is already permanently frozen,
> so the technique costs no new future freedom) **or in the far outer ring**
> (B12 ocean and polar ice, which is queued for nothing).
> **It may never be anchored in B1–B11.** Every one of those zones is scheduled
> for an authored repaint, and an in-place scene there would freeze the exact
> pixels the repair needs.

Only one of the ten is a grounded in-place scene: the wolf pack, in the core.

> **Ruling J-2.** Every other new asset **carries its own base with alpha** — an
> islet, a rime apron, a rock knoll, a hedge line — or is genuinely airborne.
> Nothing crops the master. Consequence: **the three landmarks freeze no atlas
> pixels at all**, which is why they can stand on top of known defect zones
> (D-11, D-16, D-20) without entangling the repair plan.

---

## 2 · THE TEN — the ranking, and where the line falls

Sixteen families were asked for. There are roughly ten slots (30 declared today,
40 the hard ceiling, R-9). Ranked by **new information per slot**: what does the
map say after this overlay that it could not say before?

| Rank | Family | Slot | Why it earns the slot |
|---:|---|---|---|
| 1 | **Red fire-drake** | yes | Explicit ask; the mechanism is *proven* (`overlay_skydragon`, 28 frames, travelling); the volcano is the map's most striking feature and nothing lives on it |
| 2 | **Rimespire + its aura** | yes (1 static + 1 overlay) | Explicit ask; the north is 25 % of the atlas and contains three snow flurries. One landmark changes the whole quadrant's meaning |
| 3 | **The Black Gable + its storm** | yes (1 static + 1 overlay) | Explicit ask; the map contains **no dread anywhere**. The SE cape is empty and dramatic |
| 4 | **Lanterngard + its fae court** | yes (1 static + 1 overlay) | Explicit ask; the map contains **no magic anywhere**. Merging "fairy castle" and "fairies" into one overlay is what frees the slot at rank 9 |
| 5 | **Blue storm drake** | yes | Explicit ask; a genuinely third silhouette (§4.2); pairs with the Black Gable so the storm has an owner |
| 6 | **Aurora band** | yes | The "subtle atmospheric event" ask, answered at world scale by **one** very-low-opacity drifting sprite. Best value per slot in the whole list |
| 7 | **Wolf pack** | yes | New *behaviour* (a pack, not a lone animal), new silhouette, and it gives an already-named landmark its reason |
| 8 | **Crows over Forgotten Hollow** | yes | Eerie fauna **and** life at the one settlement that has none. Two owner asks, one slot |
| 9 | **Fae motes, Deepwood Shrine** | yes | Proves the fae are a property of the world rather than a decoration on one building. Also the only new thing that glows near the opening view |
| 10 | **Ox-cart, western valley road** | yes | The caravan ask; and with the existing wagon 130 px east it reads as a **trade route**, not a repeated sprite |
| — | **— the line —** | | |
| 11 | Doe and fawn, Whispering Woods | no | The deer ask. Rejected because a stag already reads at (156,493): a second cervid is a *location* change, not an *information* change. **First reserve** |
| 12 | `overlay_forge_smoke` at Amberfield | no | Already packaged (3 frames, unplaced) — costs **zero generations**. Rejected anyway: slots are the scarce resource, not generations, and a third smoke column says nothing the first two did not. **Second reserve** |
| 13 | Second bear | no | Same silhouette, different tree. The map cannot tell the player anything new with it |
| 14 | Second yeti | no | Same silhouette, same biome, and `yeti2` already runs **continuously** — the yeti is the one creature that is always on screen |
| 15 | Rams / lynx, Worldspine and Frostmere | no | Real ecological depth and worth a future round; loses to every magical feature above because the map's absence is magic, not mammals |
| 16 | More birds | no | Three drifting bird overlays already exist and are the least-noticed things on the map. A fourth is invisible |
| — | A walking humanoid figure at a settlement | **REFUSED** | Not ranked. See §6 — this is an R-4 violation, not a low-value idea |

**Landmark vs creature, decided.** A landmark is a fixed vignette; a wandering
creature reads as more alive per slot. That would argue against the three
landmarks — except that a landmark here costs **less than one slot**: its body is
a *static* named-landmark PNG (no ticker, no `Opacity`, hidden below overview
zoom, outside the 40-overlay budget), and only its magic is an overlay. So each
landmark buys a permanent addition to the world's geography for the same slot a
creature costs, and buys it in the quadrants where there is nothing to be alive
*near*. In the busy central band the creature wins; in the empty outer ring the
landmark wins. That is exactly how the ten are distributed.

---

## 3 · Visual hierarchy — the answer to "constant noisy animation everywhere"

### 3.1 A correction the implementer must carry

FOUNDATION-K's R-9 gives "≤ 12 in frame at any zoom" and derives ~11 from
`30 declared × 38 % of world area`. **That is an area-proportion estimate, not a
count of what is drawn.** Measured from the shipped layout by duty cycle:

- **19 of the 30 shipped overlays are continuous** — always drawn, no interval:
  3 snow flurries, 4 forest mists, 3 birds, 2 smoke, 2 ripples, 2 cloud shadows,
  1 cloud wisp, 1 fire, 1 yeti.
- All 19 sit inside **x 276–706** — narrower than one survey-floor viewport.
- The 11 intermittent overlays contribute ≈ **2.1** expected simultaneous.
- **Worst-case drawn today ≈ 21**, not 11.

So the shipped map already exceeds R-9's stated in-frame figure, and the figure
needs re-deriving from duty cycles by whoever owns the budget. It does **not**
block this direction, because of how the ten are built:

| | Continuous (always drawn) | Expected simultaneous added |
|---|---:|---:|
| Shipped | 19 | ≈ 21.1 total |
| This direction adds | **1** (the aurora, opacity 0.22) | **+2.9 world-wide; +0.93 inside the busy central band** |

Nine of the ten are intermittent. The one continuous addition lives at y < 76,
above every existing overlay, at a fifth of full opacity.

> **Ruling J-3.** No new **continuous** overlay may be declared inside
> x 276–706. That band is full. New life there is intermittent or it is not
> added.

### 3.2 The four tiers, with cadence numbers

**Tier 0 — STATIC. No ticker, no slot, no cost.** The three landmark bodies and
the scatter-prop channel. This is the tier that makes the world feel *built*
rather than *animated*, and it is free. It is also where the answer to "life at
settlements" mostly lives (§7).

**Tier 1 — CONTINUOUS. Never stops.** Weather and water only; never a creature,
never a light. Opacity ceiling **0.40** (the existing forest-mist precedent).
One addition: `overlay_aurora`, 8 frames × 900 ms = 7.2 s loop, drift
(−16, 0) world px/s (≈ 6 min 24 s per world lap), **opacity 0.22**.

**Tier 2 — PERIODIC. 15–30 % duty, 20–45 s cycles.** Creatures and magic doing
their ordinary business. Six of the ten.

**Tier 3 — RARE EVENT. ≤ 16 % duty, 60–90 s cycles.** The two new dragons. Long
enough that a player who sees one has *found* something.

| Overlay | Tier | Active | `playLoops` | `intervalMillis` | Cycle | Duty |
|---|---|---:|---:|---:|---:|---:|
| `overlay_aurora` | 1 | 7.2 s loop | — | none | ∞ | **1.000** |
| `overlay_rimespire_aura` | 2 | 10 × 320 = 3.2 s | 1 | 17,000 | 20.2 s | 0.158 |
| `overlay_crows` | 2 | 10 × 260 = 2.6 s | 3 → 7.8 s | 21,000 | 28.8 s | 0.271 |
| `overlay_fae_court` | 2 | 12 × 300 = 3.6 s | 2 → 7.2 s | 19,000 | 26.2 s | 0.275 |
| `overlay_fae_motes` | 2 | 10 × 320 = 3.2 s | 2 → 6.4 s | 23,000 | 29.4 s | 0.218 |
| `overlay_stormhouse` | 2 | 14 × 260 = 3.64 s | 2 → 7.28 s | 24,000 | 31.3 s | 0.233 |
| `overlay_wolfpack` | 2 | 16 × 300 = 4.8 s | 2 → 9.6 s | 31,000 | 40.6 s | 0.236 |
| `overlay_oxcart` | 2 | 6 × 500 = 3.0 s | 4 → 12.0 s | 47,000 | 59.0 s | 0.203 |
| `overlay_stormdrake` | 3 | 24 × 380 = 9.12 s | 1 | 67,000 | 76.1 s | 0.120 |
| `overlay_redwyrm` | 3 | 28 × 400 = 11.2 s | 1 | 61,000 | 72.2 s | 0.155 |

**Why those interval numbers and not round ones.** 17 / 19 / 21 / 23 / 24 / 31 /
47 / 61 / 67 seconds share no small common factors with each other or with the
shipped intervals (9, 13, 14, 20, 23, 26, 30, 34, 40, 45, 52). Two events in the
same viewport therefore drift apart instead of locking into a beat. A map where
three things start moving together every 30 seconds reads as a carousel; a map
where they never quite coincide reads as weather.

> **Ruling J-4 — the ten-second rule.** From any fixed camera position, at most
> one *new* motion should begin per ~10 s of dwell. Verified per-viewport by
> summing `1 / cycle` for the Tier 2–3 overlays in frame. Central band:
> 1/28.8 + 1/29.4 + 1/40.6 ≈ 0.093 starts/s → one new motion every **10.8 s**,
> against a continuous bed of 19. East band: 1/20.2 + 1/31.3 + 1/76.1 + 1/72.2 ≈
> 0.090 → one every **11.1 s**. Both pass.

### 3.3 What is deliberately NOT animated

The three landmark bodies. The scatter props. Every road, wall, roof and field.
The atlas itself. **Stillness is the majority state and is doing work** — a
lightning strike is only an event because the house beneath it never moves.

---

## 4 · Per-asset direction — the ten

Reference scale throughout: `overlay_skydragon` is **68 × 31**, 28 frames,
travelling (−30, −5) world px/s on a 40 s gap. That is the quality bar and the
size reference. `x`/`y` in the layout are the **top-left of the box in world
pixels** (atlas px × 6); a landmark's coordinate is where its **bottom-centre
anchor stands**.

### 4.1 `overlay_redwyrm` — the red fire-drake

- **What it is.** The volcano's owner, climbing east out of the crater and over
  the sea, breathing once mid-crossing.
- **Native size:** **84 × 40** (skydragon 68 × 31 — 1.59× the pixel area, and
  the difference must be *visible* when both are read against the same sky).
- **Frames:** 28 · **frameMillis:** 400 · `playLoops: 1`
- **Motion:** `travel (+30, −13)` world px/s · `intervalMillis: 61000`
- **Placement:** atlas (736, 306) → **world (4416, 1836)**. Sweeps
  736–820 × 306–346 → 792–876 × 280–320.
- **Silhouette / material.** A **heavy wedge**, not a serpent: short thick neck,
  broad barrel chest, forward-swept wings with visible finger-bones, a heavy
  horned skull, a short tail ending in a club. Body is **cooled basalt —
  near-black**, with molten red-orange running in cracks along the spine and
  shoulders and the wing membranes lit **from behind** so they glow orange. It
  reads *red* without being a flat red silhouette, and it belongs to the black
  massif it launches from.
- **The breath.** A wide forward **cone** of orange-white with a dark smoke tail,
  baked into the same sprite (R-7: an `Opacity` wraps exactly one image, always —
  a two-part creature costs 2.73 MB of offscreen per frame). Present on roughly
  frames 11–18 so it reads as an *event inside the crossing*, not a constant jet.
  The cone must read as a **shape** at 1:1, never as a gradient.
- **Distinctness from the green:** green is a bat-wing X; red is a heavy wedge
  with a fire cone. Different mass, different colour logic, different behaviour.

### 4.2 `overlay_stormdrake` — the blue storm drake

- **What it is.** Not a blue dragon. A **sky-eel**: it does not flap, it
  undulates. It comes in off the sea toward the Black Gable and turns away.
- **Native size:** **92 × 26** — the longest and thinnest thing on the map.
- **Frames:** 24 · **frameMillis:** 380 · `playLoops: 1`
- **Motion:** `travel (−30, +9)` world px/s · `intervalMillis: 67000`
- **Placement:** atlas (832, 688) → **world (4992, 4128)**. Sweeps
  832–924 × 688–714 → 787–879 × 702–728, ending over the cape's airspace.
- **Silhouette / material.** Ribbon-bodied, **no large membrane wings** — a pair
  of short delta fins at the shoulder and a long trailing tail with a forked tip.
  Body **deep indigo to slate**, pale storm-grey underside, a row of small pale
  dorsal spines catching light. It is closer to a long than a wyvern.
- **The breath.** Not a cone and not a stream: a **branching arc** that leaps
  from the jaws and forks, ~2 px wide, **white core in a violet-blue halo**,
  present on only **3 of the 24 frames**. A discharge, not a flamethrower.
- **Colour constraint:** the arc must be violet-leaning (white core, indigo
  halo). **It may not use the teal-green family** (L-16).
- **Distinctness:** green = X, red = wedge, blue = horizontal ribbon. Three
  unmistakable shapes at 1:1. Not a recolour by construction — different
  anatomy, different locomotion, different breath geometry.

### 4.3 `overlay_aurora` — the polar band

- **What it is.** The one continuous addition. Violet, rose and gold curtains
  drifting west along the polar shelf, wrapping the world.
- **Native size:** **96 × 48** (matches the existing widest sprite class —
  `forest_mist`, `cloud_shadow` — so packaging is proven at this canvas)
- **Frames:** 8 · **frameMillis:** 900 · continuous, no interval
- **Motion:** `drift (−16, 0)` world px/s (world lap ≈ 6 min 24 s) ·
  **`opacity: 0.22`**
- **Placement:** atlas (700, 28) → **world (4200, 168)**
- **Material.** Vertical curtains with soft feathered tops and a bright lower
  hem; the animation is a slow lateral *shear* of the curtain, not a pulse — no
  frame is much brighter than any other. Ramp: pale gold hem → rose → violet →
  transparent. **No green.**

### 4.4 `landmark_rimespire` (static) + `overlay_rimespire_aura`

- **Body — static named-landmark art, tier `future`.** Native **60 × 96**,
  anchor (30, 96), standing at atlas **(824, 156)** → world **(4944, 936)**.
  Occupies 794–854 × 60–156. Costs no overlay slot and no ticker.
- **Aura overlay.** Native **48 × 56**, 10 frames × 320 ms, `intervalMillis:
  17000`, at atlas (800, 44) → world (4800, 264). Occupies 800–848 × 44–100 —
  wreathing the spire's upper third.
- **Motion read.** Not a glow-pulse. A **snow-devil**: rime lifted off the
  crown and spun once around the spire, with the crown window's cold pale-gold
  light flickering behind it. Magic as *weather*, not as sparkle.
- Full architecture and IP boundary in §5.1.

### 4.5 `landmark_lanterngard` (static) + `overlay_fae_court`

- **Body — static, tier `future`.** Native **64 × 72**, anchor (32, 72),
  standing at atlas **(66, 424)** → world **(396, 2544)**. Occupies
  34–98 × 352–424.
- **Court overlay.** Native **56 × 48**, 12 frames × 300 ms, `playLoops: 2`,
  `intervalMillis: 19000`, at atlas (38, 340) → world (228, 2040). Occupies
  38–94 × 340–388 — rising *through* the crown of the castle's trained branches.
- **Motion read.** Motes of warm amber light lifting out of the canopy, drifting
  apart, and going out one at a time. **No drift vector** — the motion is inside
  the frames, so the swarm stays with its home.
- Architecture and IP boundary in §5.2.

### 4.6 `overlay_fae_motes` — Deepwood Shrine

- **What it is.** The same phenomenon, 220 px inland, smaller and rarer. The
  evidence that Lanterngard is not a decoration.
- **Native size:** **40 × 40** · 10 frames × 320 ms · `playLoops: 2` ·
  `intervalMillis: 23000`
- **Placement:** atlas (284, 536) → **world (1704, 3216)**, centred on the
  Deepwood Shrine landmark anchor (304, 556).
- **Material.** Six to nine motes, amber-gold, **each one pixel of core with a
  one-pixel halo** — never a star-burst, never a lens flare. They rise, hold, and
  wink out. An **air sprite** with full alpha: it crops no ground and freezes
  nothing, which is what makes it legal inside the A-4 core.

### 4.7 `overlay_wolfpack` — Wolfwood

- **What it is.** The only grounded **in-place scene** in the ten, and the only
  new pack behaviour on the map.
- **Native size:** **48 × 48** · 16 frames × 300 ms · `playLoops: 2` ·
  `intervalMillis: 31000`
- **Placement:** atlas (302, 698) → **world (1812, 4188)**. Occupies
  302–350 × 698–746 — fully inside the A-4 core (y max 746 < 747), never
  straddling the rim band.
- **Technique.** The `bear2` precedent exactly: crop the master, PixelLab
  `edit_image` a small glade at the forest's south edge, `animate_image`, and
  composite each frame back through a fixed content box (rings 0–1 pure source,
  2–3 blend 2:1, 4–5 blend 1:2). **Frame 0 is the untouched crop**, so the rest
  state *is* the painting.
- **Read.** Three wolves at the treeline: one standing head-low in profile, one
  crossing behind it, one lying. Grey-brown with a pale throat; the standing
  wolf's silhouette must survive at 1:1 against dark canopy — separate it by
  **value**, not by outline. It is at the forest edge, on visible ground, not
  buried in closed canopy.
- **Deliberate overlap:** `forest_mist` #3 (296–392 × 676–724, opacity 0.4)
  passes over the box. Wolves seen through mist is the intended composition.

### 4.8 `overlay_crows` — Forgotten Hollow

- **Native size:** **40 × 32** · 10 frames × 260 ms · `playLoops: 3` ·
  `intervalMillis: 21000`
- **Placement:** atlas (536, 506) → **world (3216, 3036)**. Occupies
  536–576 × 506–538 — clearing the Hollow's marker circle (549–573 × 539–563) by
  1 px and the Stonefall smoke column entirely.
- **Read.** Five to seven **black** corvids circling in a loose gyre above the
  Hollow's roofs — larger, slower and more ragged than the three existing pale
  drifting bird flocks, which is the whole point. Wings are broad-fingered and
  the flight path is a lopsided oval, not a V. Pure air sprite, no ground.

### 4.9 `overlay_oxcart` — the western valley road

- **Native size:** **24 × 22** · 6 frames × 500 ms · `playLoops: 4` (12.0 s
  active) · `travel (−11, +2)` world px/s · `intervalMillis: 47000`
- **Placement:** atlas (96, 528) → **world (576, 3168)**. Travels
  96–120 × 528–550 → 74–98 × 532–554, along the tan road painted from the west
  edge at y ≈ 530.
- **Read.** An **ox-drawn cart with a canvas tilt** — deliberately a different
  silhouette from the existing single-frame caravan wagon 130 px east, because
  D-21 and D-23 are on the defect register precisely for reading as copy-paste.
  The six frames carry the ox's head bob and the tilt's sway; the wheels do not
  need to turn at 24 px.
- **Why here and not on the Haven's Rest → Stonefall road.** That was the first
  choice — a wagon between the two places the player actually walks, inside the
  opening view. **Rejected:** there is no painted road on that ground. A vehicle
  crossing open meadow reads as free traversal, which is an **R-4** violation
  (§6). A vehicle may travel only on a road the base art actually paints. The
  western valley road is painted, and a second wagon on it turns one sprite into
  a **trade route**.

### 4.10 `landmark_black_gable` (static) + `overlay_stormhouse`

- **Body — static, tier `future`.** Native **52 × 56**, anchor (26, 56),
  standing at atlas **(786, 786)** → world **(4716, 4716)**. Occupies
  760–812 × 730–786, on the SE cape's wooded headland. A **static low shelf of
  cloud is baked into the body art**, so the house is under weather even when the
  storm overlay is in its gap.
- **Storm overlay.** Native **56 × 72**, 14 frames × 260 ms, `playLoops: 2`,
  `intervalMillis: 24000`, at atlas (758, 712) → world (4548, 4272). Occupies
  758–814 × 712–784 — the sky above the house *and* the roof it strikes.
- **Motion read.** Churn for most of the loop; **one** strike on two frames,
  reaching the ridge line. The flash is a shape (a forked line plus a two-frame
  brightening of the roof and the wet rock), never a full-box white flash — a
  white flash at world scale is a screen artefact, not weather.
- Architecture and IP boundary in §5.3.

### 4.11 Cost, measured

| | Value |
|---|---:|
| New overlay frames | **138 PNGs** |
| New static landmark bodies | **3 PNGs** |
| Total new files | **141** → shipped PNG count 871 → **1,012** |
| New decoded texture | **1,491,072 B** overlays + **53,120 B** landmarks = **1.47 MiB** |
| Against B-1 (+24 MiB) | **6.1 % of the budget** |
| Estimated on-disk PNG (at the measured 10.75 : 1) | **≈ 143 KB** against B-5's +2.5 MB |
| World-tab first-build precache after this pass | 211 → **349 entries**, 1.58 → **3.00 MiB** (plus the 4.00 MiB atlas) |

Three dependencies the implementer must carry, none of them optional:

1. **R-3 fires.** 871 + 141 = **1,012 files crosses Flutter's default
   1,000-entry image cache cap.** `imageCache.maximumSize = 2000` and
   `maximumSizeBytes = 48 << 20` must land in the same commit as the first new
   asset, or the map thrashes.
2. **R-10 fires.** Three of the ten are `travel`-kind (`redwyrm`, `stormdrake`,
   `oxcart`), joining four shipped ones. A muted `Ticker` accumulates elapsed
   time, so a travelling creature reappears mid-flight after a tab dwell. The
   `activity_result.dart:264–290` `TickerMode.valuesOf` freeze must be adopted in
   `AtlasOverlayLayer`. **This is the one Dart change this direction requires**;
   everything else is `package-art.js` emits plus layout JSON.
3. **The world goldens move.** `test/goldens/phase1_world.png` covers the default
   viewport centred on Haven's Rest. `overlay_crows` (536,506),
   `overlay_wolfpack` (302,698) and part of `overlay_fae_motes` fall inside it,
   and intermittent overlays are visible at t = 0. The goldens must be
   regenerated **and visually reviewed**, not blind-accepted.

**Generation budget.** Rough order: ten overlays × (one base image + one
animation, plus rejects) plus three static bodies ≈ **450–550 generations**,
which places the whole of this work **after the 2026-09-16 reset**. It cannot
start against the 25-generation reserve. Call `get_balance` before planning any
call and never trust a remembered figure. **Sequence one creature end-to-end
first** — the red fire-drake, because `skydragon` is its proven template — and
take it to the physical iPhone before authoring the other nine (M-12, the
owner's single-defect loop).

---

## 5 · The three landmarks, designed

### 5.1 Rimespire — the ice-mage tower

**Position.** Atlas (824, 156), on the outer polar shelf where the pack ice
gives out to open sea. It stands almost due **north of the volcano** on the same
eastern flank: the map gains a **fire/ice axis** down its eastern edge, which is
the compositional reason for this coordinate rather than a prettier one further
west.

**Architecture.** A **stave tower**, not an ice palace. A dark spruce-timber
core — vertical staves, a shingled skirt roof at a third height, a small
projecting gallery — that has stood long enough for **rime to accrete over it**:
wind-driven ice built up in lobes and fins on the windward face, so the west side
is a smooth bone-white ridge and the east side still shows black timber. The
crown is not a spire; it is a **hooked, wind-carved cap** that leans downwind,
with one small window under it. The base sits on a low rime apron, cracked, with
two or three lifted plates of shelf ice around it. The whole silhouette leans.

**Palette.** Spruce-black and tarred brown for the built structure; **bone-white
and pale warm grey** for the accreted rime (not blue-white); a single **cold pale
gold** light in the crown window. Deliberately **no cyan, no ice-blue crystal,
no violet** — the aurora above supplies all the colour this quadrant needs, and
the tower must not compete with it.

**Light behaviour.** The crown light is steady, dim, and always on — it is the
static body, so it never blinks. All movement belongs to the aura overlay.

**Animation.** `overlay_rimespire_aura` (§4.4): rime lifted off the crown and
spun once around the spire every ~20 s. Weather, not sparkle.

**Explicitly NOT doing, to stay clear of the referenced IP:** no four-fold
snowflake plan; no transparent blue crystal architecture; no crystal spiral
stair; no cantilevered snowflake balcony; no ice-blue/lavender palette with a
magenta accent; no figure, gown, cape, or braid; no radial star motif anywhere on
the structure. The design's whole idea — **a wooden building that ice has taken
over** — is the opposite of *architecture made of magic ice*, and that is
deliberate.

### 5.2 Lanterngard — the fairy castle

**Position.** Atlas (66, 424), on the western moor beyond Wayfarer's Pass. The
far-west lane holds three overlays in total today; this puts the map's only
concentration of magic where there is room for it, and where a westward pan is
already rewarded by the caravan road.

**Architecture.** Not a castle of towers. A **ring of nine standing stones**,
weathered and leaning, that a **blackthorn** has grown through and around — the
thorn trained (or grown itself) into arches between the stones, with low roofs of
**woven bark and thatch** slung between. Two or three round doorways under the
arches. The tallest point is barely twice the tallest stone. The whole silhouette
is **wide, low and horizontal**, spreading rather than rising, with a broken
outline of thorn twigs against the sky. Around the base: cropped moor grass, a
ring of paler ground where nothing grows, and one flat threshold stone.

**Palette.** Lichen-grey stone, near-black bark, deep moss-green thorn, straw
thatch. The only saturated colour is **warm amber** — lanterns hung in the
branches, three or four of them, small.

**Light behaviour.** The lanterns are baked into the static body and are steady.
They are the reason the eye finds the building at all against the pale moor.

**Animation.** `overlay_fae_court` (§4.5): amber motes lifting out of the crown
of the thorn every ~26 s, drifting apart, going out one at a time.

**Fairies, specified.** At world scale a fairy is **two or three pixels**. They
are therefore authored as **motes of light with a hint of insect wing** — never
humanoid figures, never faces, never dresses. This is both a legibility decision
and the IP boundary.

**Explicitly NOT doing:** no clustered slender turrets with conical roofs; no
castle-on-a-crag silhouette; no pastel blue-and-pink palette; no gold-trimmed
pennants; no winged girl in a green leaf dress; no glitter trail; no
heart/star/sparkle vocabulary of any kind. The reference points are a Neolithic
stone ring and a hedge-laid thorn, both public-domain folk architecture, and the
silhouette is deliberately built so that it could not be mistaken for a
fairy-tale castle at any zoom.

### 5.3 The Black Gable — the storm house

**Position.** Atlas (786, 786), on the SE cape's wooded headland, past Saltreach
Light and the delta. The last land before the eastern sea, and empty today.

**Architecture.** One **croft-longhouse**, tall and narrow, of **tarred black
board** on a low stone plinth, standing on a **bare rock knoll** the sprite
carries with it. One steep gable end faces the viewer. A single crooked stone
chimney, cold. A low broken drystone wall running off the knoll and stopping.
Three wind-bent thorn trees, all leaning the same way, on the seaward side. **One
lit window, low, on the ground floor** — the only warm thing in the composition,
and small enough to read as a lamp rather than an invitation.

**Palette.** Tar-black boards with a grey weathered grain; slate-grey stone;
bruise-purple and gunmetal for the cloud shelf baked into the body; one **dull
orange** window. The headland's own greens are the only saturation, and they are
darkened under the shelf.

**Light behaviour.** The window is steady and dim. The strike is the event, and
the strike belongs to the overlay. **No flicker on the window, ever** — a
flickering window plus a strike gives a viewer two competing signals.

**Animation.** `overlay_stormhouse` (§4.10): churn for most of the loop, one
forked strike on two frames every ~31 s, with a two-frame brightening of the roof
and the wet rock. Never a full-box white flash.

**Explicitly NOT doing:** no Second Empire mansard tower and no hillside stair
(*Psycho*); no towered Victorian mansion with a cupola and iron cresting (Addams
Family); no quarter-round "eyebrow" attic windows (Amityville); no skulls, no
graveyard, no ghost, no jack-o'-lantern, no bats. The vocabulary is **Hebridean /
Icelandic vernacular** — a working croft in bad weather — which is both original
and far more unsettling at 52 px than a haunted-mansion pastiche would be.

---

## 6 · What this must not become

Six failure modes, each with the specific rule that prevents it.

**1 · Clutter — a carnival instead of a world.**
The whole map must still read as *land* first. Prevention: only **one** new
always-on element (the aurora, at opacity 0.22); ruling **J-3** closes the busy
central band to new continuous motion; ruling **J-4** caps new-motion starts at
one per ~11 s per viewport; and Tier 0 — the three static bodies and the props —
is where most of the added content lives. **If a reviewer's eye cannot rest
anywhere on the screen for three seconds, this has failed** regardless of what
the budget table says.

**2 · Animation that fights navigation.**
No new overlay may occlude a location marker, its ring, its label, a kind glyph,
or a route dot **at any zoom**. Every box in §1.3 was checked against the five
marker circles; the tightest clearance is 1 px (crows above the Forgotten Hollow
ring) and must be re-verified on device at the opening zoom before acceptance.
The three landmarks are `future` tier — quieter than a place, suffixed so they
cannot be read as somewhere with a panel behind them — and they carry **no
marker ring and no kind glyph**, because a thing that looks tappable and is not
is worse than a thing that is not there.

**3 · Creatures that read as stickers.**
Every new asset carries its own grounding (ruling **J-2**): an islet, a rime
apron, a rock knoll, a shelf of cloud — or it is genuinely airborne, in which
case it must never overlap a horizon line in a way that makes it ambiguous. No
hard alpha rectangle may ever sit on painted terrain. **A-3 applies in full: no
new element ships until a blind read at iPhone-viewport scale confirms it belongs
to the ground it stands on.** The retired part-2 bear (mascot-sized), the floated
yeti and the slug-like water dragon are the recorded precedent for exactly this
failure, and all three were caught on device, not in review.

**4 · Anything implying free-roam movement (R-4).**
This is the hardest line and the easiest to cross by accident:

- **No humanoid figure moves anywhere on the atlas.** Not at a settlement, not on
  a road, not in a field. This is why "life at settlements" is answered with
  smoke, birds, a wagon and lit windows and **not** with villagers — a small
  walking person on a map is a character the player will try to steer. The
  request for movement at settlements is **refused in that form**, not
  deprioritised.
- **A vehicle may travel only on a road the base art actually paints.** This is
  why the second caravan is on the western valley road and not on the
  Haven's Rest → Stonefall route (§4.9).
- **No creature may travel along a route polyline in the direction of the
  player's current journey.** A creature moving the player's way at the moment
  the player travels reads as an avatar.
- No footprints, no dotted trail behind anything, no arrow, no waypoint, no
  leading or following, nothing that reads as being steered.

**5 · Implying a system Stride does not have (L-15 / L-17).**
The storm must not read as weather the player has to shelter from. The dragons
must not read as threats that can reach the player — they cross the *sky*, they
never descend to a road or a settlement, and their corridors are deliberately
routed over water and basalt. The fae motes must not read as collectibles. None
of the three landmarks may look like a destination: no ring, no glyph, no panel,
no rumour hook. And nothing new is tappable — the overlay layer is
`IgnorePointer` and named landmarks have no hit target, which must stay true.

**6 · Freezing ground the repair plan needs.**
Ruling **J-1**: no in-place scene outside the A-4 core or the far outer ring.
Nine of the ten crop no ground at all. The one that does (the wolf pack) sits
entirely inside the already-permanently-frozen core, so it costs the atlas
repair plan **nothing**. The three landmark bodies stand over D-11, D-16 and
D-20 without entangling any of them, because each carries its own base. The
retired `fire2` — whose content box was cut through by a later road, so its
always-visible frame 0 would have painted pre-corridor forest over the road — is
the standing warning, and this direction is built so that it cannot recur.

---

## 7 · Two free channels this direction deliberately uses

Neither costs an overlay slot, a ticker, or a frame of animation.

**7.1 · The scatter-prop channel.** `props: []` in the layout is fully
implemented in the parser, the layer and the test, with **seven approved prop
PNGs already shipped** (`prop_boulders`, `cairn`, `dead_tree`, `hedgerow`,
`lone_oak`, `pine_clump`, `snowdrift`) and entirely unused. Props are static,
untappable, and correctly hide below overview zoom. Recommended first placements,
all outside the ten and all zero-generation:

- **`hedgerow` along the D-13 farm/forest join, x 370–420 × y 590–675.** D-13 is
  a P2 defect — gold fields butting dark canopy with zero transition — that is
  **fully A-4-frozen and owner-only to repaint**. A line of hedgerow props laid
  along the join softens it **with zero atlas pixels changed and zero
  generations spent.** This is the single best free win available anywhere in the
  world-map plan and it should be tried before any authored repaint of that seam.
- `cairn` ×2–3 along Wayfarer's Pass; `snowdrift` ×3 on the north shelf;
  `dead_tree` ×2 on the Black Gable's knoll; `lone_oak` ×2 in Amberfield's
  fields; `pine_clump` at the Longwood's ragged treeline.

Props add elements to the world `Stack` and entries to the image cache, so keep
the first placement to **≤ 12 props** and measure before adding more.

**7.2 · `overlay_forge_smoke`.** Three frames, packaged, approved, and present in
no layout entry. It is free to place and it is the **second reserve** (§2) if a
slot is ever returned. It is not in the ten because a third smoke column adds no
information the first two did not.

---

## 8 · Reserve register — the ecology this round does not build

Placed now so a future round inherits a map rather than a wish list.

| Family | Placement (atlas) | Note |
|---|---|---|
| Doe and fawn | in-place scene, ~(394, 470) 40 × 40, inside core | First reserve |
| `overlay_forge_smoke` | (466, 592), Amberfield hearth | Second reserve, zero generations |
| Rams | (130, 320) 40 × 32, Worldspine ridge | Outside core, outside B1 |
| Lynx | (540, 380) 32 × 32, Frostmere basin edge | In core, in-place scene legal |
| Bear and cubs | SW forest — **blocked**: B2 is queued for the S1 repaint (J-1) | Re-place after S1 lands |
| Second yeti | Frozen Shelf, (445, 176) | Outer ring, legal, low value |
| Seals / walrus on the floes | (600–700, 100–160) | Would give the north a second reason to exist |

---

## 9 · Open questions this direction does not decide

Recorded rather than inferred (`RULES.md` G-3):

- **Q-J1.** R-9's "≤ 12 overlays in frame" is already exceeded by the shipped map
  under a duty-cycle count (§3.1, ≈ 21 drawn). The budget's owner must re-derive
  the number. This direction is designed to be safe under either reading, but the
  figure should not stay wrong in the record.
- **Q-J2.** Whether the three new named landmarks appear in the World tab's
  landmark enumeration, or exist as art and labels only. This direction assumes
  **`future` tier, label + art, no panel** — but that touches what the World
  screen enumerates and belongs to whoever owns that surface.
- **Q-J3.** Whether the Black Gable, Lanterngard and Rimespire acquire lore
  entries. They are scenery until someone with the world-writing brief says
  otherwise; naming them is not the same as describing them.
