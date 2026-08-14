# Visual Sample Generation 01

**Status: EXPLORATION — nothing here is a decision.**

This document turns `VISUAL_EXPLORATION_01.md` from written creative direction
into **ready-to-run generation specifications** for three comparable visual
samples of one canonical Project Stride scene.

**No sample images have been generated.** Claude Code has no image-generation
capability in this environment — see *§9*. What this document produces is a
deterministic composition control image, three exact paste-ready prompts, and
the shared constraints that make them comparable.

**No winner is named, and no hybrid is proposed.** Selection and hybridization
belong to the owner, after the owner has seen A, B, and C independently.

**Owner review, round 1 — accepted with revisions.** The setup was approved with
a revised U-4, a revised U-5, a ruling on F-1, a ruling on the generation route,
and a Direction C pipeline flag. All are incorporated below and marked where
they changed.

**Owner review, round 2 — the samples have been seen. → §14 and §15.**
**Direction A is the owner's preferred direction**, and Direction B's rendering
complexity must not bleed into it. A new desired visual behaviour — *Living
Activity Presentation* — is recorded in §15. Sections 1–13 describe the
experiment as it was run and are **left unedited** so the record of what was
compared stays accurate.

---

## 0. How to read this document

Every value below that is not drawn directly from `assets/content/v1/*.json` is
**PROVISIONAL FOR VISUAL SAMPLE GENERATION 01 ONLY**. A value used to make a
sample renderable has not been chosen and does not become the project's value by
being the only one written down (`RULES.md` G-3; `ART_DIRECTION.md` —
*UNRESOLVED*).

Nothing here promotes a value into `ART_DIRECTION.md`, `UI_UX/`, `CONTENT/`, or
any ADR. `ART_DIRECTION.md` still reads **EXPLORATION**.

---

## 1. Source references

| Source | What it constrains here |
|---|---|
| `CLAUDE.md` | Stay in scope; do not infer unresolved design decisions |
| `RULES.md` G-3, G-6, G-7 | Unresolved stays visibly unresolved; one canonical home per concept |
| `MISTAKES.md` M-01 | Verification and effort proportional to the risk |
| `PROJECT_KERNEL/03_DESIGN_PILLARS.md` | Sensory satisfaction, mobile first, wonder, expandable foundation |
| `PROJECT_KERNEL/06_ANTI_FEATURES.md` | No engagement-bait presentation; energy is never a restrictive draining meter |
| `PROJECT_KERNEL/13_INSPIRATION.md` | WalkScape-adjacent structure; do not copy any existing game's UI |
| `GAME_BIBLE/ART/ART_DIRECTION.md` | The three candidates; what must stay unresolved |
| `GAME_BIBLE/ART/VISUAL_EXPLORATION_01.md` | Rulings R-1…R-4, the canonical scene, the three theses, U-3/U-4/U-5 |
| `GAME_BIBLE/ART/templates/EIGHT_DIRECTION_CHARACTER.md` | The character must be designed so eight true views are later possible |
| `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md` | Haven's Rest, granted Traveler gear, no merchants in M01 |
| `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md` | Six tabs, one-handed use, calm presentation, no spreadsheet overload |
| `GAME_BIBLE/WORLD/01_WORLD_STRUCTURE.md`, `02_EXPLORATION_AND_TRAVEL.md` | Regional identity; travel needs a destination |
| `GAME_BIBLE/VISION/01_CORE_GAME_LOOP.md` | Plan → Walk → Discover → Progress → Adventure |
| `assets/content/v1/locations.json` | `location.havens_rest`, safe, start, two roads out |
| `assets/content/v1/resource_nodes.json` | `resource_node.meadow_patch` — Foraging, level 1, **tool `none`**, 90 steps, yields 2, 10 XP |
| `assets/content/v1/items.json` | Meadow Herb; Training Sword / Axe / Pickaxe; Traveler Tunic — all tier 0 |

### Rulings this task inherits and does not reopen

- **R-1** — Project Stride has a real player-facing world view. The canonical
  scene is an in-game scene, not a menu illustration.
- **R-2** — One shared provisional camera family across A/B/C.
- **R-3** — U-3, U-4, U-5 stay unresolved and must be answered *identically*
  across A/B/C.
- **R-4** — World presence does **not** mean joystick, WASD, free-roam
  traversal, continuous pathfinding, or player-steered locomotion. Real-world
  walking remains the movement and progression input.

---

## 2. Shared comparison constraints

The experiment is only valid if exactly one variable changes.

**Held identical across A, B, and C — verbatim, not approximately:**

- the composition control image (§5.4) fed to all three generations
- camera family, pitch, framing, and subject placement (R-2)
- the composition blueprint in §5, to the stated proportional positions
- the U-3 / U-4 / U-5 answers in §4
- the HUD regions, HUD content, and game-state values in §6
- time of day and light direction
- interaction state (node noticed, not yet tapped)
- the prop inventory — the same props, the same count, nothing added
- aspect ratio and output size

**Permitted to change — this is the entire signal:**

- rendering language (pixel construction, material, line, fill)
- lighting and atmosphere philosophy
- character rendering language and proportion
- environment rendering language
- UI *visual* language (never UI structure)
- implied animation philosophy

A sample that changes anything in the first list has broken the experiment
rather than won it.

### Each direction is a serious candidate

None of the three may be weakened to sharpen the contrast:

- **A must not be made sparse or crude** to exaggerate its restraint. A is
  *intentionally restrained*, which is not the same as *underdrawn*. It gets
  full craft within its own economy.
- **B must not acquire extra props, a more dramatic camera, or a more flattering
  time of day.** B wins or loses on rendering treatment, light, material, and
  atmosphere alone.
- **C must not become presentation art, key art, a character illustration, or a
  side-on view.** C is a real in-game view rendered illustratively.

### Three constraints that override the exploration document

`VISUAL_EXPLORATION_01.md` described some shared subjects differently per
direction, which R-3 forbids at generation time. Resolved here, once:

| Conflict | In the exploration | Resolved for generation |
|---|---|---|
| **NPC design** | A: "taller and narrower", deep-green mantle; C: "rounder mass, lower centre of gravity" | **Neutral average adult, simple settlement clothing** — see §4, U-4. **Revised by the owner** specifically so the NPC cannot bias one direction. |
| **Time of day** | B's signature moment assumes late afternoon; A and C do not | **Mid-morning** (§6). Late afternoon was rejected because a golden-hour sky is a gift to B's thesis and a tax on A's and C's — the light must not pre-decide the comparison. |
| **Tab labels** | A and C describe icon **plus** label tabs | **Icons only, no tab text**, in all three. Owner-confirmed: generated text quality must not become a comparison variable. If comprehension later demands labels, use the minimum set and keep them identical across all three. |

These are resolutions for this experiment. None resolves the underlying
unresolved question.

---

## 3. What the samples must and must not communicate

**Must read as true:**

- the player currently **occupies** Haven's Rest
- the character visibly **exists in** the location, at ground level, in scale
- the **Meadow Patch is an interactable, gatherable element** — the brightest,
  most reachable object in the lower third
- **NPCs and environmental content exist** in the world around the player
- this is **part of the game**, not a splash screen or key art

**Must not be implied, per R-4:**

- no virtual joystick, D-pad, thumbstick ring, or movement pad
- no directional arrows, movement chevrons, or WASD-style affordance
- no path-following dotted line, waypoint trail, or "tap to move here" marker
- no minimap with a steerable player blip
- nothing suggesting an avatar is walked around to substitute for real steps

The scene is a **visually represented location and state**. How the player comes
to be standing there is unresolved (U-6) and no sample may answer it.

---

## 4. Provisional U-3 / U-4 / U-5 answers

> **PROVISIONAL FOR VISUAL SAMPLE GENERATION 01 ONLY.**
> Chosen once, held identical across A/B/C, and **not** promoted into
> `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md` or any other canonical
> document. U-3, U-4, and U-5 remain **UNRESOLVED** after this task, and **no
> additional canonical armour or equipment item is created by any of them.**

### U-3 — Starter Traveler gear visual composition

*Owner-approved substantially as first proposed.*

**One armour piece, plus non-armour carriage.**

| Element | Provisional depiction |
|---|---|
| **Traveler Tunic** (the only armour item in `items.json`) | Knee-length belted tunic in warm oat/sand, plain collar notch, three-quarter sleeves |
| Trousers | Slate/brown, plain |
| Belt | Simple narrow leather belt, one plain buckle |
| Boots | Low wrapped travel boots, muted brown |
| Traveler pack | One small canvas pack, high on the back, visible |
| **Training Sword** | **Visible, hanging at the left hip** |
| **Not present** | No helmet, no gloves, no pauldrons, no cloak, no cape, no shield, no armour plate, no jewellery, no glow |

**Why these values.** `items.json` contains exactly one armour entry and the
Starter Content Bible calls it a *set* — the mismatch is precisely what U-3
records. Depicting one tunic plus belt, trousers, boots, and pack keeps the
picture honest about the data while still yielding a full-body figure that reads
at phone size. Belt, trousers, boots, and pack are **carriage, not armour**, and
depicting them here does not create an item.

### U-4 — Haven's Rest NPC identity and design

> **REVISED by the owner at review round 1.** The first proposal gave the NPC a
> tall narrow silhouette and a deep-green floor-length mantle. Both were
> withdrawn: a dramatic costume and a strong signature colour reward the
> directions that render costume and colour most richly, which is bias. The
> replacement is deliberately plain.

**One unnamed Haven's Rest adult resident. Not a character proposal.**

| Attribute | Provisional depiction |
|---|---|
| Identity | Unnamed, untitled adult resident. No nameplate, no role label, no quest marker, no `!`/`?` icon |
| Proportions | **Average, neutral adult build.** Not tall and narrow, not exaggerated, not stylised beyond each direction's own language |
| Posture | **Relaxed neutral stance**, standing still, arms at rest, facing generally toward the player |
| Clothing | **Simple settlement clothing** — plain tunic and trousers in a neutral charcoal/brown base, with **one muted rust/umber outer garment or accent** |
| Carrying | **Nothing.** No weapon, no tool, no basket, no goods, no stall, no apron, no profession signalling of any kind |
| Face | Present and calm; no strong expression |
| Prominence | **Easy to locate, never the visual focus.** The Meadow Patch remains the brightest and most legible object in frame |
| Explicitly avoided | Deep green as a defining colour · an unusually tall or narrow silhouette · a floor-length or dramatic mantle · elaborate costume design · merchant presentation |

**Why these values.** The scene requires a person and the project has no named
NPC. A plain, unarmed, unlabelled resident satisfies "a person, not a prop"
without proposing a character *and* without handing any direction a costume to
show off with.

### U-5 — Visible stowed tool

> **REVISED by the owner at review round 1.** The first proposal put the Training
> Axe and Training Pickaxe heads on the pack, breaking the silhouette. Withdrawn:
> Visual Sample Generation 01 tests art direction, not maximum equipment-layering
> complexity, and three directions rendering three stowed tools differently adds
> noise where the experiment needs none.

**Stowed gathering tools are NOT externally visible in this scene.**

| Element | Provisional depiction |
|---|---|
| Training Sword | **Visible**, hanging at the **left** hip, as equipped combat gear. Short, plain crossguard-and-grip |
| Traveler pack | **Visible**, small, high on the back |
| Training Axe | **Owned, not depicted.** Not visually attached to the player |
| Training Pickaxe | **Owned, not depicted.** Not visually attached to the player |
| **Hands** | **Empty. Nothing held, nothing equipped in hand.** |

**Why these values.** The Meadow Patch requires `"requiredToolKind": "none"` —
the first gather in the game is done with bare hands, and the exploration treats
that as the scene's emotional centre. Empty hands say *this one you do
yourself*; a visible sword still says *this character is equipped*; and the pack
is where an unseen axe and pickaxe plausibly live.

**This does not decide the production rule for displaying equipped or stowed
tools.** The axe and pickaxe remain granted, owned game items per the Starter
Content Bible. Whether the player character ever visibly carries them is
**UNRESOLVED**, and this sample must not be cited as having answered it.

---

## 5. Shared composition blueprint

One blueprint, applied identically to A, B, and C, and rendered once as the
deterministic control image in §5.4.

Positions are **proportional**, on a normalized frame: `x` 0.00 (left) → 1.00
(right), `y` 0.00 (top) → 1.00 (bottom). Heights are given as a fraction of
frame height. These are staging proportions, not production coordinates — no
tile geometry, pitch, or pixel dimension is being decided.

### 5.1 Frame

- **Portrait, 2:3.** Generation size **1024 × 1536**. A phone-proportional crop
  large enough to inspect character, NPC, node, and HUD at once.
  **The resolution is PROVISIONAL FOR THIS EXPERIMENT ONLY** and is not a sprite,
  canvas, or render-target decision.
- **No phone hardware bezel, no device mockup, no hands holding a device.**
  The HUD is drawn into the frame directly.
- No border, no frame, no title card, no logo, no watermark, no signature.

### 5.2 Depth planes

| Plane | Band | Contents |
|---|---|---|
| Sky | y 0.09 – 0.21 | Open sky down to a soft treeline horizon |
| Background | y 0.18 – 0.42 | Haven's Rest, roofs, smoke, flanking trees, distant treeline |
| Midground | y 0.42 – 0.62 | Gate, NPC, palisade scrub, upper path, signpost |
| Foreground | y 0.62 – 0.92 | Player, lower path, Meadow Patch, path stones, grass fringe |

The ground plane **recedes into the frame** under the shared camera. Actors
stand upright on it. Not overhead, not side-on, not strict mathematical
isometric.

### 5.3 Element placement

| Element | Position (x, y) | Scale / notes |
|---|---|---|
| **Player character** | feet at **(0.42, 0.72)** | ≈ **0.17** of frame height. Standing on grass at the left edge of the path. Three-quarter **front-right** facing; head turned further down-right than the shoulders, toward the patch. Weight settled on the back foot. Idle — not walking, not kneeling, not mid-action |
| **Meadow Patch** | centre **(0.66, 0.80)** | ≈ 0.14 wide × 0.10 tall. Foreground plane, lower-right. **Clear of the player's silhouette — no overlap.** Clear of the bottom HUD band. The most legible, highest-contrast, most saturated object in frame |
| **Meadow Herb** | **(0.67, 0.765)** | Three pale herb stems rising above the tuft, one cream flower head as the focal accent. The herb is *on* the node, ungathered |
| **Gather affordance card** | anchored above the patch, centred **(0.68, 0.705)** | Small contextual card. Content in §6. Never a modal, never centre-screen |
| **NPC** | feet at **(0.36, 0.46)** | ≈ **0.10** of frame height (midground scale). Standing just inside the open gate, **behind and to the player's left**. Facing generally toward the player |
| **Haven's Rest gate** | arch centre **(0.30, 0.38)** | Open timber gate in a palisade wall. The gate opening faces down-right, toward the camera |
| **Settlement mass** | x 0.05 – 0.50, y 0.18 – 0.42 | Palisade wall plus **two or three roofs** behind it. Nothing above three storeys |
| **Smoke plume** | rises from **(0.20, 0.25)** | One thin plume from one roof. Exactly one |
| **Main pathway** | gate **(0.30, 0.44)** → **(0.45, 0.62)** → exits frame bottom at **(0.58, 0.92)** | Worn dirt, widening toward the viewer. Runs *past* the player, not under them |
| **Road out — east** | exits frame right edge at **(1.00, 0.26)** | Narrow, unlabelled. Reads as "somewhere else exists" |
| **Road out — west** | exits frame left edge at **(0.00, 0.30)** | Narrow, unlabelled |
| **Tree — left** | **(0.10, 0.30)** | Flanking the settlement |
| **Tree — right** | **(0.52, 0.28)** | Flanking the settlement |
| **Palisade scrub** | along y ≈ 0.40 – 0.43 | Low scrub hiding the seam where ground meets structure |
| **Signpost** | **(0.52, 0.55)** | Beside the path. Two plain carved direction arms. **No text on it** |
| **Firewood stack** | **(0.20, 0.52)** | Three logs, low |
| **Path stones** | **(0.50, 0.72)** and **(0.55, 0.83)** | Two only |
| **Grass fringe** | y 0.88 – 0.92, **left third only** | A thin foreground grass band. Kept off the right side so it never competes with the Meadow Patch |

**The prop inventory above is exhaustive.** No barrels, crates, carts, fences,
wells, banners, lanterns, flowers beyond the node, birds, butterflies, clouds
beyond a plain sky, or additional figures. Every direction gets the same world
to render and no direction gets extra furniture.

### The one thing the composition must accomplish

A player's thumb, coming up from the bottom-right of a phone, lands on the
Meadow Patch. That is why the node sits at (0.66, 0.80) and why the character is
looking at it before anything has happened.

### 5.4 Composition blockout — the control image

**Path:** `GAME_BIBLE/ART/exploration/VISUAL_SAMPLE_01/composition_blockout.png`
**Dimensions:** 1024 × 1536, 24-bit PNG, grayscale values only.

**This is a CONTROL INPUT, not an art sample.** It carries no art-direction
information of any kind and must never be presented, evaluated, or archived as
one of the three comparison images.

Generated deterministically from the §5.3 coordinates by a PowerShell
`System.Drawing` script — flat filled masses only, no randomness, no seed, byte-
reproducible from the same coordinates.

**No text is drawn into the image.** Labels were deliberately excluded because
burnt-in text contaminates structural conditioning and can be transcribed into
the generated output. The legend lives here instead.

#### Legend — grayscale value to element

| Value | Element |
|---|---|
| 235 | Sky |
| 215 | Smoke plume |
| 205 | Open gate void |
| 200 | Meadow ground plane |
| 185 | Foreground grass fringe (bottom-left third) |
| 175 | Scrub along palisade base |
| 170 | Distant treeline band |
| 165 | Main path, and the two roads leaving frame |
| 140 | Path stones |
| 130 | Tree canopies · active tab plate |
| 120 / 125 / 115 | Settlement roofs |
| 110 | Firewood stack |
| 100 | Palisade wall |
| 95 | Signpost |
| 90 | Tree trunks · HUD widget regions · inactive tab plates |
| 85 | Palisade posts, gate frame and lintel |
| 70 | NPC |
| 60 | Meadow Patch tuft and blades |
| 55 | Traveler pack · Training Sword |
| 45 | Gather interaction-card region |
| 40 | Player character |
| 25 | Meadow Herb stems and flower head |
| 20 | HUD top strip and bottom tab bar |

#### What the blockout deliberately does not encode

- **No head-to-body ratio.** The two figures are generic humanoid masses. A, B,
  and C each supply their own proportions (1:4.5, 1:6, 1:5) in their own prompt
  blocks, and the blockout must not override them.
- **No outline style, line weight, texture, pixel grid, dithering, or shading
  model.**
- **No lighting.** Grayscale values encode *element identity and separation*,
  not illumination, and no mass is a shadow.
- **No clothing detail, facial detail, or costume.**
- **No VFX, atmosphere, or decorative rendering.**
- **No typography.** HUD masses mark *regions*; the text content is specified in
  §6 and supplied by each prompt.

Facing is encoded structurally rather than with arrows: each figure's head mass
is offset toward its facing direction, and the player's sword mass sits on the
viewer-right side, denoting the character's left hip under a three-quarter
front-right view.

---

## 6. Shared HUD and game state

> **PROVISIONAL FOR VISUAL SAMPLE GENERATION 01 ONLY.** These numbers are a
> plausible representative state chosen to make the HUD renderable. They are not
> balance values, not product decisions, and not derived from task S-06.

### HUD regions — identical in all three

| Region | Band | Content |
|---|---|---|
| **Top strip** | y 0.00 – 0.09 | Location name (left) · banked walking energy with a boot glyph (centre-right) · sync dot (far right) |
| **Playfield** | y 0.09 – 0.92 | The scene. No chrome |
| **Contextual card** | anchored at (0.68, 0.705) | The gather affordance on the Meadow Patch |
| **Bottom tab bar** | y 0.92 – 1.00 | Six tab icons, evenly spaced, large targets |

### Values

| Field | Value | Note |
|---|---|---|
| Location name | **Haven's Rest** | From `locations.json` |
| Banked walking energy | **1,240** | A comfortable owned stock — about thirteen gathers' worth. Deliberately not near-empty; scarcity framing would read as the restrictive energy system `06_ANTI_FEATURES.md` forbids |
| Energy presentation | **A stock the player owns**, with a boot glyph and a *partial fill toward full* | Never a draining meter, never a countdown, never a refill timer, never a "+" purchase affordance |
| Sync freshness | **One small filled dot** meaning synced | No timestamp text, no source name, no device name (`RULES.md` H-7) |
| Gather card | herb icon · **×2** · **90** · **+10 XP** | All four from `resource_nodes.json`. The XP figure is carried on the card so progression is legible without inventing a new HUD region |
| Interaction state | **Node noticed, not yet tapped.** Card at rest, no press state, no progress bar, no particles, no gather animation | Identical in all three |
| Six tabs, left to right | **Adventure · Character · Skills · Inventory · Craft · World** | From `UI_UX/01_MOBILE_EXPERIENCE.md`. Icons only, no labels (§2) |
| Active tab | **Adventure** (leftmost) | Shown active in each direction's own visual language |
| Health | **Absent from the world HUD** | **Owner ruling, F-1.** See below |

### F-1 — health stays off the world HUD

**Ruled by the owner at review round 1.** World-screen health is **not** added
for this comparison. The canonical Haven's Rest HUD stays intentionally
restrained.

**This does not change combat-screen health requirements.** All three UI
sections of `VISUAL_EXPLORATION_01.md` place health on the combat screen, and
that is untouched. The world HUD simply is not the place to prove it.

### Text discipline

The **only** legible text anywhere in the image is: `Haven's Rest`, `1,240`,
`×2`, `90`, `+10 XP`. Everything else is textless — no tab labels, no signpost
lettering, no banners, no UI captions, no watermark.

Owner-confirmed rationale: image generators produce garbled text, and unequal
text failures across three images would be read as an art-direction difference
when they are nothing of the kind. **Generated text quality must not become a
major comparison variable.**

### Forbidden HUD elements — all three

No virtual joystick or thumbstick · no D-pad · no movement arrows or chevrons ·
no WASD affordance · no waypoint trail or dotted path line · no "tap to move"
marker · no minimap with a steerable blip · no daily-login banner · no streak
counter · no timer or countdown · no premium currency · no shop, gem, or "+"
purchase icon · no ad slot · no chat window · no player list.

---

## 7. The three final generation prompts

Each prompt is **self-contained and paste-ready**. Each is built as:

```
[COMPOSITION REFERENCE]  ← the same control image for all three (§5.4)
[SHARED SCENE BLOCK]     ← identical text in all three
[DIRECTION BLOCK]        ← the only part that differs
[SHARED NEGATIVE BLOCK]  ← identical text in all three
```

Run all three at **1024 × 1536**, in the **same tool and model version**, with
the **same seed**, and with `composition_blockout.png` supplied as the structural
reference for every one of them.

---

### 7.0 SHARED SCENE BLOCK — identical text in A, B, and C

> Follow the supplied reference image for composition, layout, and the position
> and scale of every element. Keep the placement of the character, the other
> figure, the settlement, the path, the plant, and the interface bars exactly as
> the reference places them.
>
> A single vertical portrait game screenshot of a mobile fantasy RPG, viewed from
> a three-quarter top-down / isometric-lite perspective — seen from slightly
> above and in front, the ground plane receding into the frame. Not directly
> overhead, not side-on, not strict mathematical isometric. Mid-morning, clear
> warm daylight from the upper left, roughly forty degrees elevation.
>
> Setting: the grassy edge of a small frontier settlement called Haven's Rest. In
> the upper-left background, a timber palisade wall with an open timber gate, two
> or three roofs behind it, and one thin smoke plume rising from a single roof.
> Two narrow dirt roads leave the frame, one at the right edge and one at the
> left edge, unlabelled. One tree stands to the left of the settlement and one to
> its right. Low scrub runs along the base of the palisade.
>
> A worn dirt path runs from the gate down and to the right, widening toward the
> viewer, and leaves the bottom of the frame. Beside the path stands a plain
> wooden signpost with two carved direction arms and no writing on it. A small
> stack of three firewood logs sits near the palisade. Two stones are embedded in
> the path. A thin fringe of grass blades runs along the bottom-left edge of the
> frame only.
>
> In the centre-lower area of the frame stands one player character, seen full
> body at about one sixth of the frame height, standing on the grass at the left
> edge of the path. They face three-quarters toward the viewer and to their
> right, with the head turned further down-right than the shoulders, looking at a
> plant on the ground to their lower-right. Weight settled on the back foot,
> standing still — an idle pose, not walking, not kneeling, not mid-action.
>
> The character wears a knee-length belted tunic in warm oat-sand over darker
> slate-brown trousers, a simple narrow leather belt with a plain buckle, and low
> wrapped travel boots. A small canvas travel pack sits high on their back. A
> short plain sword with a simple crossguard hangs at their LEFT hip, which under
> this three-quarter view appears on the viewer's right side of the figure. Their
> hands are empty and hold nothing. No axe and no pickaxe are visible anywhere on
> the character. No helmet, no gloves, no shoulder armour, no cloak, no cape, no
> shield.
>
> In the lower-right foreground sits a distinct gatherable plant node: a raised
> tuft of tall grass blades fanning from a single root point, clearly separate
> from the surrounding ground grass, with three pale herb stems rising above it
> and one cream-coloured flower head. It is the brightest, highest-contrast, most
> saturated object in the frame. It does not overlap the character.
>
> Behind and to the character's left, just inside the open gate, stands one other
> person: an ordinary adult resident of the settlement with average, neutral
> adult proportions and a relaxed neutral standing posture, arms at rest, facing
> generally toward the player character, calm expression. They wear simple plain
> settlement clothing — a plain tunic and trousers in neutral charcoal and brown,
> with one muted rust-umber outer garment as their only accent. They are unarmed
> and carry nothing at all: no weapon, no tool, no basket, no bag, no goods, no
> market stall, no apron, and nothing that signals a trade or profession. They
> are easy to notice but are not the focus of the image; the gatherable plant
> remains the most eye-catching object.
>
> Overlaid game interface: a slim strip across the very top of the frame showing
> the text "Haven's Rest" on the left, a small boot icon with the number "1,240"
> toward the right, and one small filled dot at the far right. A slim bar across
> the very bottom of the frame showing six evenly spaced interface icons with no
> text under them, the leftmost one shown as the active tab. Floating just above
> the gatherable plant, a small contextual card showing a small herb icon and the
> text "×2", "90", and "+10 XP".
>
> These five short strings are the ONLY text anywhere in the image: "Haven's
> Rest", "1,240", "×2", "90", "+10 XP".

---

### 7.1 DIRECTION A — Classic Pixel MMO Lite

**Thesis being tested:** a place you could keep for ten years. Charming,
readable, expandable, and *intentionally* restrained rather than cheap. Classic
MMO spirit without copying any existing game. **Restraint is a craft choice
here, not an absence of craft** — A is to be rendered as carefully as B and C.

**Append the following DIRECTION BLOCK to §7.0, then append §7.4.**

> Art direction: classic pixel art, in the register of a traditional 2D pixel
> MMO — familiar, grounded, honest about being a sprite game, and deliberately
> restrained but carefully crafted. Low-resolution pixel construction with
> visible, deliberate pixels and hard pixel edges throughout; crisp
> nearest-neighbour scaling, no anti-aliasing, no blur, no soft gradients, no
> sub-pixel smoothing. Every element is built on the same consistent pixel grid
> at the same pixel density — the character, the world, and the interface are all
> made of the same size of pixel.
>
> Restrained earthy palette of roughly forty to fifty colours total: muted grass
> greens, weathered grey-brown timber, muted clay-brown roofs, warm oat and sand
> cloth, dusty path browns. Flat three-step colour ramps with no dithering.
> Selective one-pixel dark outlines on characters and important objects; terrain
> and background are unoutlined. Every element is finished and deliberate — clean
> and economical, never sketchy, unfinished, or crude.
>
> A single fixed light direction from the upper left, baked flatly into every
> element. No dynamic lighting, no bloom, no rim light, no specular highlights,
> no atmospheric haze, no light shafts, no particles. Depth is carried purely by
> value and saturation — the background loses contrast and takes a slight cool
> tint, the foreground keeps full saturation. A soft elliptical contact shadow
> sits under each standing object; there are no cast directional shadows.
>
> The character is compact and sturdy, roughly a 1:4.5 head-to-body ratio, with a
> clear trapezoid silhouette — shoulders wider than hips, a visible gap between
> arm and torso, boots planted apart. The face is minimal: two eye pixels, no
> nose, expression carried by head tilt and posture rather than by features.
> Equipment reads by silhouette first and colour second — the sword is
> identifiable from its outline alone.
>
> Terrain is tile-based with a deliberately small vocabulary — two grass variants
> and a worn dirt path — with variation coming from a few scattered tuft overlays
> rather than from many tiles. The ground layer is quiet on purpose, so the
> character silhouette never gets lost in it. Buildings are built from a small
> modular kit of posts, wall spans, and two roof pitches. Trees are clustered
> value-blob canopies of three value steps with a visible trunk, not individual
> leaves.
>
> The gatherable plant is a raised tuft, darker at its base and lighter at its
> tips, with a soft one-pixel warm rim on the sunward side lifting it forward off
> the ground.
>
> Interface: solid opaque panels with a two-pixel bevelled border, seated flush
> against the top and bottom edges of the frame. Pixel bitmap display type for
> the location name, chunky pixel icons for the six tabs, the active tab raised.
> The gather card is a small framed opaque plate with a bevelled border.
>
> Charming, calm, warm, and legible at arm's length in one glance. Nothing on
> screen competes for attention.

---

### 7.2 DIRECTION B — Modern Premium Pixel Fantasy

**Thesis being tested:** the walk was worth it. Premium indie polish, atmosphere
and material, arriving somewhere with weather — winning or losing on **rendering
treatment, light, material, atmosphere, and detail, never on staging.** B gets
no extra props, no camera move, and no more flattering hour than A and C.

**Append the following DIRECTION BLOCK to §7.0, then append §7.4.**

> Art direction: modern premium pixel art — an unmistakably pixel-constructed 2D
> game rendered with contemporary lighting and material craft, in the register of
> a high-end indie release. Higher-resolution pixel construction than a
> retro-console game, but still clearly built from visible deliberate pixels on a
> consistent grid, with hard pixel edges and no vector or painterly smoothing.
> The pixel foundation must remain obvious.
>
> Richer palette, roughly ninety to a hundred colours, with five-step colour ramps
> and a warm bounce colour on shadow sides. Selective outlining plus a warm
> rim-light pass separating figures from the background.
>
> The richness lives in the light, not in clutter. A single warm directional key
> from the upper left in clear mid-morning daylight, plus an atmospheric pass: a
> soft shaft of light coming through the open gate and lying across the dirt
> path, cool shadow pooling under the palisade wall, fine drifting dust and
> pollen motes visible where the light crosses shade, and a very low ground haze
> at the distant treeline. Warm foreground, cool desaturated distance. Every
> standing object casts a soft directional shadow, not an ellipse. Warm interior
> light spills from one settlement window.
>
> Materials read as materials. Cloth is matte and absorbs light, with visible
> weave in the tunic ramp. The sword blade holds a fine specular line and
> genuinely glints. Thatch has visible strand direction and a lit crown; timber
> has grain and a lighter weathered top edge; palisade posts vary in height and
> lean so the gate does not look stamped. The path is slightly sunken with a
> darker damp centre, and the embedded stones catch highlights.
>
> The character is taller and more articulate, roughly a 1:6 head-to-body ratio,
> in a settled contrapposto with weight on one hip. Facial detail is present but
> deliberately understated — eyes, brow, a mouth, a hair shape, enough for gaze
> direction and broad mood, no more. Cloth at the hem and the pack strap reads as
> having weight.
>
> The gatherable plant is the most lit object in the frame and the scene's hero
> object: a dense cluster of tall blades lit from behind so the tips are half
> translucent and warm while the bases stay dark, with a faint warm haze sitting
> in the air just above it. It is unmistakably the thing worth reaching for.
>
> Depth is separated into distinct planes — foreground grass fringe, actor plane,
> settlement, treeline, sky — with gentle distance desaturation and a slight blur
> on the furthest plane only. This is depth separation within a fixed viewpoint,
> not a cinematic camera, and the framing must not change.
>
> Interface: semi-translucent dark glass panels with a soft inner glow and rounded
> corners, floating clear of the screen edges rather than seated against them. A
> clean modern sans for numerals and a light serif-adjacent face for the location
> name. The six tabs are soft-glass plates, the active one lit from beneath. The
> gather card is a rounded floating card with a softly lit herb icon.
>
> Atmospheric, unhurried, and confident — but controlled. Avoid visual noise,
> avoid heavy bloom, avoid lens flare, avoid over-saturation, and keep the
> character silhouette clean against the background at all times.

---

### 7.3 DIRECTION C — Stylized 2D Fantasy

**Thesis being tested:** an illustration you are standing inside. Clean graphic
shapes, distinctive personality, and a plausible mobile production direction —
**not** a title card, **not** a character illustration, **not** side-on, **not**
secretly 3D.

**Append the following DIRECTION BLOCK to §7.0, then append §7.4.**

> Art direction: clean stylized 2D vector illustration — hand-drawn flat cel
> shading in the register of a modern animated production, and explicitly NOT
> pixel art. No pixels, no pixel grid, no dithering, no visible raster
> construction anywhere. Smooth confident curves and crisp clean edges throughout.
>
> Bold tapered outlines in a dark warm brown — never pure black — heavier around
> each silhouette and lighter for interior lines. Flat colour fills with exactly
> one hard shadow break per surface: a lit side and a shadow side, and nothing in
> between. No gradients, no soft shading, no texture, no rendering, no painterly
> brushwork, no airbrush, no specular highlights, no glow.
>
> A disciplined palette of roughly thirty flat colours in which colour is a naming
> system rather than a description: the meadow is one green, the path is one
> brown, the roofs are one clay. Lighting is not simulated — each element is
> simply authored with a fixed lit side toward the upper left, consistent with
> clear mid-morning daylight. Atmosphere is carried by large soft colour shapes: a
> warm gradient sky and a desaturated blue-green distant hill band. No haze, no
> particles, no light shafts.
>
> Terrain is painted rather than tiled: a flat field of one base green with a few
> large soft value shapes for gentle undulation and scattered graphic grass tufts
> near the silhouette edges. The path is a single confident tapering brown shape
> with a slightly darker edge, drawn as one stroke rather than assembled from
> tiles. The ground is deliberately sparse and quiet so the character and the
> plant node are loud.
>
> The character is stylized and slightly heroic-chunky, roughly a 1:5
> head-to-body ratio, with large hands, large boots, a smaller waist, and a
> defined shoulder line — capable rather than cute. Built from a small number of
> large clear masses with real negative space between them. The face is genuinely
> readable: eyes with pupils, a brow line, a mouth shape, a defined hairstyle
> silhouette. Equipment reads as big shapes with a colour identity — the tunic is
> one warm sand mass with a single hard shadow break, and the sword is a bold
> simple wedge.
>
> Buildings are simplified geometry with character: roofs are single bold
> trapezoids with a slight sag in the ridge, the palisade is a rhythm of rounded
> posts of varying height, the gate is one strong arch shape, and everything
> leans very slightly. Two flat values per surface and nothing more. Trees are
> three or four overlapping rounded canopy masses with one hard shadow break, a
> bold tapered trunk, and a few silhouette notches so the outline is not a plain
> oval.
>
> The gatherable plant is the clearest graphic mark in the image: seven or eight
> bold tapered blade shapes fanning from one root point, in a green one step
> brighter and one step more saturated than any other green in the frame, sitting
> on a soft flat drop shadow that anchors it to the ground.
>
> Interface: flat rounded panels in a deep ink tone with thick friendly outlines
> matching the world's line weight, and bold geometric icons. A rounded geometric
> sans throughout, heavier weights for numerals. The six tabs are bold outlined
> icons, the active one filled solid. The gather card is a rounded card with a
> thick outline.
>
> The rendering language is illustrative; the staging is not. This is a real
> in-game view under the same receding ground plane and the same framing as the
> reference image — it is not a title card, not key art, not a poster, not a
> character illustration or portrait, not a side-on platformer view, and not a 3D
> render.

---

### 7.4 SHARED NEGATIVE BLOCK — identical text in A, B, and C

> Do not include: any virtual joystick, thumbstick, D-pad, movement pad, or
> directional arrows; any WASD-style control affordance; any waypoint trail,
> dotted movement line, or tap-to-move marker; any minimap. No daily-login
> banner, streak counter, timer, countdown, energy-refill prompt, premium
> currency, gem icon, shop or plus-sign purchase button, advertisement, chat
> window, or player list. No health bar or mana bar. No quest marker, exclamation
> mark, or question mark over any character.
>
> No axe, pickaxe, hammer, or any tool visible on the player character or
> anywhere in the scene. Nothing in either figure's hands.
>
> No additional people beyond the two described. No merchant, no market stall, no
> wares, no apron, no profession clothing, no floor-length mantle or robe, no
> hood, no elaborate costume, and no signage with writing. No barrels, crates,
> carts, fences, wells, banners, lanterns, birds, or butterflies. No additional
> flowers beyond the one plant node. No horses or mounts.
>
> No phone hardware, device bezel, mockup frame, or hands holding a device. No
> image border or frame. No logo, title, watermark, signature, or caption. No
> text anywhere other than the five specified strings. No garbled or invented
> lettering.
>
> Not photorealistic. Not a 3D render. Not side-on, not a platformer view, not
> directly overhead, not a top-down floor plan. Not key art, not a poster, not a
> title card, not a character sheet, not a character portrait, not a splash
> screen. No lens flare, no heavy bloom, no depth-of-field blur on the character,
> no motion blur, no chromatic aberration, no film grain.
>
> Do not change the camera, the framing, the placement of any element, the time
> of day, the light direction, the character's pose, the character's equipment,
> the other figure's design, or the interface layout.

---

## 8. Character consistency requirement

The full eight-direction sheet is **not** produced by this task. But the
character in the canonical scene must be designed so that it *could* become one
later, per `templates/EIGHT_DIRECTION_CHARACTER.md`.

Enforced by the shared scene block, and stated here so it is auditable:

| Template principle | How the sample honours it |
|---|---|
| **Full body in every view** | The scene shows the whole figure, feet included, unobstructed |
| **True rotations, no mirroring** | The one asymmetric element is **explicitly sided**: the Training Sword hangs at the character's **LEFT** hip. A later diagonal view must move it correctly rather than flip it |
| **One individual across views** | Identity is carried by silhouette mass, palette, and gear placement — never by a front-only detail such as a chest emblem or a facial expression |
| **Consistent proportions** | One head-to-body ratio per direction, stated in each direction block |
| **Not designed for a single view** | The three-quarter front-right pose is one of the eight cells, not a bespoke hero pose. Nothing about the design depends on being seen from the front |

**Effect of the revised U-5.** Removing the visible axe and pickaxe leaves the
sword as the sole sided element, which *reduces* eight-direction drift risk
rather than increasing it — one asymmetry to hold instead of three. If stowed
tools later become visible in production, the no-mirroring constraint applies to
each of them independently.

**Explicitly not produced here:** the 3×3 sheet, per-view resolution, palette,
camera angle, proportions, and rendering treatment — all still UNRESOLVED in
`ART_DIRECTION.md`.

---

## 9. Generation route

### Ruled by the owner at review round 1

**Lightweight structural conditioning.** One deterministic grayscale composition
blockout is produced by Claude Code and supplied as a reference image to all
three generations, so composition is held constant by construction rather than
by hoping three prompts land the same way.

**Explicitly out of scope for this task:** installing or configuring SDXL, Flux,
ControlNet, ComfyUI, Automatic1111, or any other local image-generation stack.
None was installed and none is required by anything in this document.

### Division of responsibility

| Owned by Claude Code | Owned by the image-generation environment |
|---|---|
| The canonical comparison scene | Final text-to-image execution |
| Composition and the control image | Model and sampler choice |
| Visual specifications | Reference-conditioning strength |
| The three generation prompts | Re-rolls until §10's validity check passes |
| Evaluation criteria | — |

The final execution **may occur in a separate image-generation environment**, so
long as that environment accepts the composition control image as a reference.

### Claude Code cannot render the samples itself

**Verified against the actual tool surface, not assumed.** This session has file,
search, shell, browser-automation, scheduling, and document-publishing tools, and
**no text-to-image model or connected image-generation MCP server.**

Two things this environment *can* draw are deliberately **not** offered as
samples: hand-authored SVG and HTML/CSS mockups. Either would be Claude drawing
the picture rather than a visual direction being tested. **No sample image files
exist, none is fabricated, and no empty placeholder files were created.**

The blockout is the one image this task produces, and it is a control input
(§5.4), not a sample.

### What the owner must supply

Any text-to-image service that accepts **a reference image plus a long prompt**
at a fixed portrait aspect ratio. The prompts in §7 run 400–600 words; a service
that silently truncates or rewrites long prompts will drop the shared scene
block and the comparison will fail quietly rather than loudly.

Conditioning strength is a judgement call for whoever runs it: strong enough to
hold placement, weak enough that the blockout's flat masses do not leak into the
rendering as blocky geometry. If the output starts looking like the blockout,
the conditioning is too strong.

### Direction C pipeline flag

> **Recorded explicitly, per owner instruction.**

For this one comparison image, **Direction C may be rendered by the same
image-generation workflow as A and B.**

**One generated image does not establish whether Direction C would ultimately
use a generation-led or a construction-led production pipeline.**
`VISUAL_EXPLORATION_01.md` §C.9 and §C.10 record that C's consistency and
scalability ratings are **bimodal** — among the best under a construction-led
vector pipeline, the worst under a generation-led one. A single successful
generated image is evidence about the *look*, and no evidence at all about the
*pipeline*.

The pipeline question stays **UNRESOLVED** and must be decided on its own terms,
not inferred from how well or badly this one image comes out.

---

## 10. Evaluation rubric

Sixteen axes, scored **1–5** with a short comment each. **No total is computed
and no winner is calculated.**

> **Owner reaction matters more than any score.** The numbers exist to make the
> reaction articulable, not to replace it. If the scores and the gut disagree,
> the gut is the evidence and the rubric is the noise.

### Experiment-validity check — run this before scoring anything

| Check | A | B | C |
|---|:--:|:--:|:--:|
| Camera and framing match the control image | | | |
| All element positions match §5.3 | | | |
| U-3 / U-4 / U-5 depiction identical to the other two | | | |
| No axe or pickaxe visible on the character | | | |
| NPC is plain and not the visual focus | | | |
| HUD regions, values, and interaction state identical | | | |
| Time of day and light direction identical | | | |
| No prohibited movement affordance present (§3) | | | |
| Blockout geometry has not leaked into the rendering | | | |

**Any "no" invalidates that sample. Re-roll it rather than score it** — a sample
that changed the subject is not comparable and does not count as one of the
three.

### The sixteen axes

| # | Axis | What to look for | A | B | C |
|---|---|---|:--:|:--:|:--:|
| 1 | **Immediate appeal** | First two seconds, before analysis | | | |
| 2 | **"Feels like Project Stride"** | Calm, warm, unhurried; a journal you return to, not a game demanding attention | | | |
| 3 | **Player-character appeal** | Would you want this to be *your* character for a year? | | | |
| 4 | **Equipment readability** | Can you see the tunic, the belt, the pack, the sword — and would Bronze read as an upgrade? | | | |
| 5 | **World atmosphere** | Does Haven's Rest feel like a place that exists when you are not looking? | | | |
| 6 | **Meadow Patch / resource readability** | Is the node instantly the thing your thumb wants? | | | |
| 7 | **NPC readability** | Clearly a person, clearly approachable, clearly not the subject | | | |
| 8 | **Mobile readability** | View at actual phone size. Does anything collapse? | | | |
| 9 | **MMO feeling** | Long-haul world with progression, not a one-sitting indie | | | |
| 10 | **WalkScape-compatible location feeling** | Does it read as *occupying* a place rather than *steering* through one? | | | |
| 11 | **Combat potential** | Could a wolf, a goblin, and the Hollow Guardian live here and feel dangerous? | | | |
| 12 | **Gathering potential** | Does the node look satisfying to pull with bare hands? | | | |
| 13 | **UI fit** | Do the HUD and the world look like one product? | | | |
| 14 | **Uniqueness** | Have you seen this exact look before? | | | |
| 15 | **Production scalability** | Twenty regions, forty enemies, twenty gear tiers — still affordable? | | | |
| 16 | **AI consistency risk** | Could hundreds of assets be held on-model in this language? | | | |

**Note on axis 16 for Direction C.** Score the *look's* consistency risk under a
generation-led pipeline. Do not let a good or bad result here be read as a
verdict on C's construction-led option — see the pipeline flag in §9.

### Owner reaction — the part that decides

Free-text, and deliberately unstructured:

1. Which one did you want to keep looking at?
2. Which one made you want to tap the herb?
3. Which one would you be embarrassed to show someone in a year?
4. Which single element from any sample do you not want to lose?
5. Did any sample make Project Stride feel like a **different game**? Which, and how?

---

## 11. Open flags for the owner

**F-1 — Health on the world HUD. → RULED.** Health stays off the canonical
Haven's Rest HUD; the world sample HUD stays restrained. Combat-screen health
requirements are unchanged. See §6.

**F-2 — Tab labels. → RULED.** Icon-led tabs are acceptable for generation, and
generated text quality must not become a major comparison variable. If labels
later prove necessary for comprehension, use the minimum shared set, identical
across all three. See §6.

**F-3 — NPC design. → SUPERSEDED by the owner's U-4 revision.** The
tall-and-narrow / deep-green-mantle proposal is withdrawn. The NPC is now
deliberately plain (§4). U-4 remains UNRESOLVED.

**F-4 — R-1's documentation gap is still open, and this task did not close it.**
`GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md` and
`MILESTONES/MILESTONE_01_FIRST_ADVENTURE.md` still describe six tabs and one
combat modal and **do not mention a world view**. R-1 flagged reconciling them as
real work under `RULES.md` G-6 and G-7. It remains unscoped. Amending a milestone
definition is not within a sample-generation task.

**F-5 — The blockout generator script is not in the repository.** The control
image was produced by a deterministic PowerShell `System.Drawing` script run from
a scratch directory, because the approved file list for this task is the PNG
alone. The image is reproducible from the §5.3 coordinates and the §5.4 legend.
If the owner wants byte-level reproducibility committed, the script can be added
at `GAME_BIBLE/ART/exploration/VISUAL_SAMPLE_01/build_blockout.ps1` on request.

---

## 12. Hybridization — deliberately empty

**Direction D is not created here, and no hybrid is proposed.**

`VISUAL_EXPLORATION_01.md` already records five hybrid observations (H-1…H-5)
made from the written directions. They are **not** re-derived, re-ranked, or
acted on here.

Once the owner has seen A, B, and C **independently**, hybrid observations from
the images go in a new section below this line — and not before. Merging the
directions before the owner has reacted to them separately would destroy the only
thing this experiment produces.

### Post-viewing hybrid observations

*(To be filled in after owner review. Intentionally blank.)*

---

## 13. Exploratory-status declaration

**Every visual value in this document is exploratory.**

Nothing here is a production art decision, a UI decision, a content decision, a
camera decision, a gameplay decision, or a navigation decision. Specifically, and
for the avoidance of any future citation:

- `GAME_BIBLE/ART/ART_DIRECTION.md` remains **EXPLORATION**. No direction is
  chosen, eliminated, or ranked.
- Palette, sprite dimensions, camera pitch and projection, animation frame
  counts, rendering treatment, character proportions, and final UI visual
  language all remain **UNRESOLVED**.
- **The 1024 × 1536 frame is PROVISIONAL FOR THIS EXPERIMENT ONLY** and is not a
  sprite, canvas, or render-target decision.
- **U-3, U-4, U-5 remain UNRESOLVED.** The answers in §4 are labelled
  *PROVISIONAL FOR VISUAL SAMPLE GENERATION 01 ONLY* and are not proposals. **No
  additional canonical armour or equipment item was created.**
- **U-5 in particular does not decide the production rule for displaying
  equipped or stowed tools.** The Training Axe and Training Pickaxe remain
  granted, owned items; they are simply not depicted here.
- **U-6 — the world-navigation model — remains UNRESOLVED.** Joystick,
  WASD-style, continuous pathfinding, and free-roam traversal remain excluded by
  default (R-4). Nothing in this document requests, implies, or depends on any of
  them.
- **Direction C's production pipeline remains UNRESOLVED** (§9). One generated
  image is not evidence about it.
- The HUD values in §6 are representative state for a picture. They are not
  balance numbers and do not anticipate task S-06.
- No canonical game requirement was updated by this task, and none should be
  updated on the strength of it.

### What this task did not do

- No gameplay architecture, HealthKit code, persistence, native adapter, CI
  configuration, or other unrelated system was touched.
- No joystick or free-roam movement system was designed.
- No production art direction was locked.
- **No A/B/C sample image was generated**, no image output was fabricated, and no
  empty placeholder image files were created.
- No local image-generation stack was installed or configured.
- No exploration image was placed in `assets/`, the Flutter shipping bundle.
- No ADR was created.
- No fourth or hybrid direction was created.

*(Sections 14 and 15 were added after owner review round 2. The declarations
above still hold: §14 records a preference, not a lock, and §15 records a
desired behaviour, not a system.)*

---

## 14. Owner feedback — review round 2

**Recorded after the owner reviewed the A/B/C samples.** This section is a
record of owner direction. It is not an ADR, and it does not amend
`ART_DIRECTION.md`.

### 14.1 The six recorded points

**1. Direction A is the current preferred direction.**
The owner strongly prefers **A — Classic Pixel MMO Lite**. For the next visual
iteration, **A is the primary reference anchor.**

**2. A remains exploratory, and is not permanently locked.**
This is a **strong owner preference**, not a production-art lock.
`ART_DIRECTION.md` stays in **EXPLORATION** status, and palette, sprite
dimensions, camera, animation frame counts, rendering treatment, character
proportions, and final UI visual language all remain **UNRESOLVED**. The
preference must meaningfully constrain the next exploration without being cited
as a decision.

**3. Direction B's rendering complexity must not silently bleed into A.**
The owner explicitly dislikes the visual drift that occurs when A begins
absorbing Direction B's treatment. **"Polish A" does not mean "make A more like
B."** A must not become a midpoint between A and B.

**4. Future A iterations improve distinctiveness through design language, not
through richer rendering.**
Originality is to come from shape language, architecture, UI identity, character
silhouette, equipment silhouette, resource-node readability, environmental
motifs, regional palette discipline, icon language, animation personality, and
subtle ambient motion — **not** from heavier lighting or rendering complexity.
**A should become better at being A.**

**5. Living Activity Presentation is a desired future visual behaviour.**
A represented location may remain visually alive while the character performs an
activity, including a passive one. Specified in §15.

**6. Living Activity Presentation does not imply joystick or free-roam
movement.**
It is **living activity presentation**, not free-roam world simulation. R-4
stands unchanged: real-world walking remains the movement and progression input,
and the world-navigation model (U-6) remains **UNRESOLVED**.

### 14.2 What the owner likes about A — preserve these

- obvious, intentional pixel-art identity
- old-school MMO spirit
- restrained rendering
- clean mobile readability
- grounded fantasy
- economical environmental detail
- quiet terrain beneath important gameplay elements
- strong character and object silhouettes
- visually understandable at a glance
- world feels inhabited without feeling cinematic
- practical long-term asset scalability
- feels compatible with WalkScape-like gameplay rather than a joystick-driven
  adventure game
- charming rather than spectacular
- cohesive rather than highly rendered

### 14.3 What must not drift into A

**Do not pull these Direction B characteristics into the next A iteration unless
the owner explicitly requests them:**

- richer atmospheric lighting systems
- dramatic light shafts
- pronounced warm/cool light separation
- heavy environmental depth treatment
- premium material rendering
- cloth weave / material-detail emphasis
- sword glint / specular treatment as a major visual feature
- haze as a major depth cue
- floating pollen / dust as a constant atmospheric layer
- richer multi-plane cinematic atmosphere
- dynamic-looking cast shadows as a major style feature
- visually dense foliage / detail
- high-detail premium-indie presentation
- making the world prettier by increasing rendering complexity

**This list is a constraint on the next iteration, not a criticism of B.**
Direction B is not eliminated; its treatment is simply not what A is for.

### 14.4 The next iteration's question

> **How do we make Classic Pixel MMO Lite feel uniquely Project Stride without
> losing its restraint?**

### 14.5 Design principle to preserve during exploration

> **Real-world walking creates opportunity.
> The game world shows your character living out the activity.**

**Not final marketing copy.** Recorded as a design concept to preserve while
exploring, and it should be tested rather than defended.

### 14.6 Consequence for the hybrid section

§12 stays deliberately empty. **The A-preference is not a licence to begin
hybridizing**, and H-1 in `VISUAL_EXPLORATION_01.md` — A's proportions plus B's
lighting philosophy — is now specifically contrary to point 3 above. It remains
recorded there as an observation and is **not** to be actioned without an
explicit owner reversal.

---

## 15. Living Activity Presentation

**Status: DESIRED VISUAL BEHAVIOUR — not a specification, not a system, and not
scheduled.** Recorded so the intent survives; the design belongs to its own
scoped task.

### 15.1 The concept

A represented location can function as a **living activity scene** while the
player's current action continues. The player does not steer the character
around it; the character is shown *living out* the activity the player chose.

The player should be able to leave the screen open and enjoy watching a calm,
small-scale activity loop.

| | |
|---|---|
| Living activity presentation | **Yes** |
| Free-roam world simulation | **No** |
| Joystick / WASD / pathfinding locomotion | **No** — R-4 unchanged |
| Real-world walking as the progression input | **Yes** — unchanged |

### 15.2 Activity loop sketches — presentation intent only

Recorded as the owner described them. These are *presentation* sketches, not
mechanics, and not a request to build any of them.

| Activity | Ambient loop | Occasional event |
|---|---|---|
| **Fishing** | Subtle water movement, visible line, gently moving bobber | A bite, a brief catch animation, a small splash/ripple, then back to the calm loop |
| **Woodcutting** | Economical repeated axe swing, slight tree reaction, occasional leaf movement | Small wood-chip response, brief resource/reward reaction |
| **Mining** | Rhythmic pickaxe action | Small dust/chip response, restrained spark or ore glint where appropriate, short success moment, return to loop |
| **Cooking** | Fire flicker, subtle smoke, simple stirring/turning/tending motion | Occasional completion response |
| **Skinning / processing** | Restrained, non-graphic working animation, clear task loop | Reward/completion feedback |
| **Foraging / gathering** | Reach, bend, pick interaction; the plant responds visibly | Small collection feedback, return to idle/activity loop |

**Scope note, recorded so it cannot be misread later.** Milestone 01 has
**exactly five skills** — Woodcutting, Mining, Foraging, Smithing, Cooking
(`DECISIONS/0004`, `assets/content/v1/skills.json`). **Fishing and
skinning/processing do not exist in Project Stride.** Sketching their
presentation here does **not** add them to the game, to Milestone 01, or to any
roadmap. They are recorded because the *presentation pattern* is what the owner
is describing, and it should hold for whatever skills eventually exist.

### 15.3 Qualities to aim for, and to avoid

**Aim for:** ambient · readable · satisfying · low animation burden · repeatable
for long sessions · pleasant to watch without demanding attention.

**Avoid:** constant flashy VFX · overly busy movement · animation that becomes
exhausting when repeated · cinematic sequences for ordinary actions · requiring
dozens of unique frames per skill · making passive activity look like an action
game.

### 15.4 Animation philosophy for living activity scenes

**Deliberately unresolved, and to stay that way:**

- **Loop length** — UNRESOLVED
- **Exact frame counts** — UNRESOLVED
- **Implementation technology** — UNRESOLVED
- **How and when a loop starts, pauses, or ends** — UNRESOLVED
- **Which skills get bespoke loops versus a shared skeleton** — UNRESOLVED

**The focus, which is resolved enough to steer by:**

- **Low-cost ambient movement plus occasional reward events.** The base state is
  a short, cheap, repeating loop. Interest comes from the *occasional* event
  punctuating it, not from making the loop itself elaborate.
- **The loop must stay pleasant to watch repeatedly.** A loop is seen hundreds of
  times; an animation that is charming once and grating on the fortieth viewing
  has failed regardless of how good it looked in a sample.
- **Restraint is the identity, not a budget compromise.** This follows directly
  from §14 — ambient life must come from *motion personality*, not from richer
  rendering, lighting, or particle density.
- **Consistent with Direction A's animation economy.** `VISUAL_EXPLORATION_01.md`
  §A.8 already argues for the smallest frame budget of the three and a shared
  overlay library; living activity presentation should be built to fit inside
  that discipline rather than to escape it.

### 15.5 Three constraints this must respect — flagged, not resolved

Named here because the concept sits close to three existing project laws, and a
later task must design *around* them rather than discover them:

**LAP-1 — Ambient motion may be time-based. Progression may not.**
(`RULES.md` P-4, `DECISIONS/0001`)

> **AMBIENT MOTION MAY BE TIME-BASED.
> PROGRESSION MAY NOT BE.**

**Cosmetic ambient motion may continue on ordinary animation time** while the
screen is open, and does **not** require newly earned steps to exist: water
ripples, bobber drift and bobbing, idle breathing, slight stance shifts, fire
flicker, smoke drift, foliage movement, cloth and hair secondary motion, calm
tool-ready motion, and other non-progress ambient loops.

**Durable gameplay results may never be caused by elapsed viewing time or
animation time.** That includes fish earned, ore produced, wood gathered, herbs
gathered, food completed, XP awarded, loot awarded, resource depletion, skill
advancement, action completion, and any other durable gameplay result.

**The presentation layer may DISPLAY a progression event. It may not CREATE
one.** Reward and completion moments shown by the scene are *visualizations of
already-authorized underlying game state*.

Applied to the §15.2 sketches: a bobber drifting and dipping is ambient motion
and may run on animation time. A **catch that yields a fish**, a chip that
yields ore, or a pick that yields a herb is a progression event, and the scene
may only play it because the underlying state already authorized it.

Two consequences, stated in both directions so neither is over-read:

- A player who leaves the activity scene open for ten minutes must receive **no
  progress advantage** over a player who closes the app and returns later with
  the same underlying step-funded state.
- The absence of new progression must **not** require the world to become
  visually frozen. A loop with no newly authorized progression may still produce
  cosmetic motion; it simply produces no gameplay reward and no state mutation.

**Not designed here:** the scheduler, the event queue, the animation controller,
and the offline replay model are all out of scope for this task and remain
UNRESOLVED.

**LAP-2 — Watching must never be rewarded (`PROJECT_KERNEL/06_ANTI_FEATURES.md`,
`RULES.md` P-5).**
"Leave the screen open" must remain a **pleasure, not an incentive.** The moment
watching yields anything a non-watching player does not get, it becomes a
session-length engagement mechanic — precisely what the anti-features list
forbids. A player who checks in for thirty seconds must lose nothing.

**LAP-3 — One activity at a time (`DECISIONS/0006`).**
The scene shows **the** current activity. This is compatible — arguably
reinforcing, since a single visible loop makes the exclusivity legible rather
than buried in a menu — but a "living location" must not become an argument for
showing several activities progressing at once.

**None of these is a blocker.** They are the shape the eventual design has to
fit, and naming them now is cheaper than discovering them during implementation.

### 15.6 What this section does not do

- It does **not** design the animation system.
- It does **not** decide sprite frame counts, loop lengths, or technology.
- It does **not** add fishing, skinning, or any skill to any milestone.
- It does **not** modify gameplay code, or request that any be modified.
- It does **not** change travel, navigation, or the world-navigation model
  (U-6 remains UNRESOLVED).
- It does **not** select the final art direction.
