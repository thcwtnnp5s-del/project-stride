# Visual Exploration 01

**Status: EXPLORATION — nothing here is a decision.**

Three deliberately distinct visual directions for Project Stride, described
against one fixed canonical scene so the comparison is about art direction
rather than about staging.

**No art has been generated.** This document is the written creative brief that
will drive generation in a later, separately scoped task.

**No winner is named.** Selection and any hybridization belong to the owner.

---

## How to read this document

Every numeric or stylistic value proposed below is marked **PROVISIONAL**. A
value used to make a direction describable has not been chosen and does not
become the project's value by being the only one written down (`RULES.md` G-3,
`ART_DIRECTION.md` — *UNRESOLVED*).

The following remain unresolved throughout, by rule:

palette · sprite dimensions · animation frame counts · rendering treatment ·
character proportions · final UI visual language · exact camera pitch,
projection type, and tile geometry · the world-navigation model

Each direction proposes its own values for these **independently**. The three
sets are not variations of one another and must not be averaged.

**Two exceptions, ruled by the owner and recorded below.** The **camera family**
and the **canonical scene composition** are deliberately held *identical* across
all three directions, because a comparison in which the camera also varies is
not a comparison of art direction. See *Owner rulings* immediately below.

### Sources this exploration is bound by

| Source | Constrains |
|---|---|
| `PROJECT_KERNEL/03_DESIGN_PILLARS.md` | Sensory satisfaction, mobile first, wonder, expandable foundation |
| `PROJECT_KERNEL/06_ANTI_FEATURES.md` | No engagement-bait presentation, no restrictive energy framing |
| `GAME_BIBLE/ART/ART_DIRECTION.md` | Design intent, the three candidates, what stays unresolved |
| `GAME_BIBLE/ART/templates/EIGHT_DIRECTION_CHARACTER.md` | Eight views, outward facing, no mirroring, one identity |
| `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md` | Haven's Rest, Traveler gear, granted starting equipment |
| `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md` | Six tabs, one-handed use, calm presentation, no spreadsheet overload |
| `GAME_BIBLE/COMBAT/01_COMBAT_PHILOSOPHY.md` | Turn-based, 6–12 turns, readable decisions, no death |
| `GAME_BIBLE/SYSTEMS/02_WALKING_INTEGRATION.md` | Steps gate rate, never access; nothing decays |
| `GAME_BIBLE/WORLD/02_EXPLORATION_AND_TRAVEL.md` | Travel needs a destination, communicates progress, is not a loading bar |
| `PROJECT_KERNEL/13_INSPIRATION.md` | WalkScape — movement-driven progression, mobile-first immersion; do not copy UI |
| `assets/content/v1/*.json` | The literal subjects — see below |

### What the content data actually says

Taken from the shipping content files so the scene is not invented:

| Subject | Fact | Source |
|---|---|---|
| Haven's Rest | `location.havens_rest`, safe, the start, two roads out (Whispering Woods 1200, Stonefall Mine 1600) | `locations.json` |
| Meadow Patch | `resource_node.meadow_patch`, Foraging, level 1, **requires no tool**, 90 steps, yields 2, 10 XP | `resource_nodes.json` |
| Gatherable resource | Meadow Herb, material, tier 0 | `items.json` |
| Traveler gear | Training Sword, Training Axe, Training Pickaxe, Traveler Tunic — all tier 0, **granted, not crafted** | `items.json`, Starter Content Bible |
| First earned tier | Bronze, tier 1 | `items.json` |

**The Meadow Patch needing no tool matters visually.** The first gather in the
game is done with the player's hands. Every direction below treats that as the
scene's emotional centre rather than as a detail.

---

## Owner rulings

Four rulings made by the owner on 2026-08-13 during review of this exploration.
**None is an ADR** — the owner directed that they live in this document for now.

R-1 and R-2 close questions the first draft raised. R-3 fixes how the remaining
open questions are handled. R-4 bounds what R-1 does and does not grant.

### R-1 — Project Stride has a real player-facing world view

**Ruling.** Project Stride **does** have a genuine in-game scene / world view.
The six navigation tabs are **support and navigation surfaces, not the entirety
of the game experience.**

The player visibly exists in the world and sees:

- their character
- the environment and location
- resource nodes
- NPCs
- gathering feedback
- combat encounters
- world-state feedback

**Therefore the canonical Haven's Rest comparison scene is a real in-game
scene** — not a menu illustration, not a decorative backdrop, and not a
loading-screen card. Every asset described in this document exists to be looked
at during play.

**What this ruling does not do.** It does not redesign navigation, define the
world view's structure, specify how it relates to the six tabs, or authorize any
implementation. Those remain open and belong to a later, separately scoped task.

**Documentation note.** `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md` and
`MILESTONES/MILESTONE_01_FIRST_ADVENTURE.md` currently describe six tabs and one
combat modal and **do not mention a world view**. That gap is now known rather
than accidental. Reconciling those canonical documents with this ruling is real
work under `RULES.md` G-6 and G-7, and it is **deliberately not done here** —
this is a design exploration, and amending a milestone definition is not within
its scope. Flagged for the owner.

### R-2 — One provisional camera family, shared by all three directions

**Ruling.** Visual Exploration 01 uses the **same** provisional camera across
Directions A, B, and C, so the comparison isolates art direction rather than
camera or composition.

> **PROVISIONAL CAMERA — three-quarter top-down / isometric-lite mobile RPG
> perspective.**

Intent:

- the player character is clearly visible
- enough vertical visibility to read equipment and silhouette
- enough top-down visibility to read terrain, resources, enemies, and movement
- portrait-mobile friendly
- readable at small scale
- **not** a strict mathematical isometric requirement
- **not** side-on
- **not** directly overhead

**Still UNRESOLVED:** exact pitch and yaw, tile geometry, projection type, and
sprite dimensions.

**This camera applies only to Visual Exploration 01.** It does not become a
production standard by being used here (`RULES.md` G-3).

**Enforcement across the three directions.** Each direction renders the *same
spatial composition* under the *same camera*:

- **B may not become more cinematic by changing the camera.** Its parallax is a
  depth-separation technique applied within the shared perspective, not a
  different viewpoint, and it may not tilt, push in, or lower the horizon.
- **C may not become side-on or presentation-oriented.** Its flat graphic
  treatment is a rendering choice, not a projection change; the ground plane
  recedes exactly as it does in A and B.
- **A does not get a flatter or more overhead camera** because its resolution is
  lower.

If a direction's description below would look better under a different camera,
that is information about the direction — it is not permission to move the
camera.

### R-3 — Non-blocking questions stay unresolved, and stay identical across A/B/C

U-3 (Traveler gear composition), U-4 (the Haven's Rest NPC), and U-5 (visible
stowed tools) **remain unresolved and are not being decided.**

When visual generation begins, all three directions must use the **same
provisional answers** to these questions, so that an unresolved subject cannot
contaminate the comparison. A difference between the three images must be a
difference of art direction and nothing else.

### R-4 — World presence does not mean joystick or free-roam locomotion

**Ruling.** R-1 grants the player *visual presence inside real game locations* —
Haven's Rest, gathering sites, combat areas, dungeons, and other world spaces.
It does **not** change the core interaction model into joystick-driven or
continuous virtual walking.

Project Stride stays aligned with a WalkScape-like philosophy: **real-world
walking is the movement and progression input.** The world view exists to
support immersion and interaction, not to replace real-world walking with
simulated walking.

| | |
|---|---|
| World view | **Yes** |
| Player visual presence | **Yes** |
| Real-world steps drive progression and travel | **Yes** |
| Joystick-driven world exploration | **No, by default** |

Consequently:

- The player does **not** normally move their avatar around the world with a
  virtual joystick.
- Travel and location selection may be node-, destination-, menu-, or
  step/progression-driven.
- Gathering, NPC interaction, combat entry, and other activities may occur
  within visually represented locations.
- Active combat may have its own direct interaction model; that does not imply
  free-roam locomotion for the game overall.
- **Joystick controls, WASD-style movement, continuous pathfinding, and
  free-roam exploration are not assumed requirements** and must not be inferred
  from anything in this document.

**This is a design constraint, not an implementation specification.** The exact
world-navigation model remains **UNRESOLVED** and will be designed later, in its
own scoped task. Nothing here redesigns travel, navigation, world-map structure,
or combat controls.

#### What R-4 means for the art in this document

Three things below could be misread as depending on free-roam movement. They do
not, and the readings are corrected here once rather than hedged in twenty
places:

**Walk cycles.** All three directions budget a walk animation across eight
directions. That budget is driven by the owner's eight-direction character
standard (`templates/EIGHT_DIRECTION_CHARACTER.md`) and by the need to depict a
character in motion — travelling, approaching a node, repositioning in combat,
or simply being animate in a location. **It is not evidence of, or a request
for, player-driven locomotion.** How and when a walk cycle plays is a
world-navigation question, and that question is unresolved.

**Parallax and depth layers.** B's four-to-five parallax planes and C's layered
planes are **depth-separation techniques**, not a free-roaming camera. They read
as depth under a fixed view and can be driven by state change, transition, or
subtle drift. Parallax here implies nothing about whether the player steers
anything.

**Eight-direction sheets.** Eight facings are required by an existing owner
standard and are useful regardless of navigation model — a character that turns
to face a node, an NPC, or an enemy needs them. Their presence is not an
argument for analogue movement.

---

## What this exploration is actually testing

Stated explicitly, so a reader comparing three images knows which differences
are the signal and which would be noise.

**A, B, and C are being compared on:**

- character rendering language
- environment rendering language
- lighting and depth philosophy
- UI visual language
- animation philosophy
- production scalability
- AI-assisted consistency

**A, B, and C are *not* being compared on:**

- gameplay systems
- camera family
- scene composition
- content quantity
- different NPCs
- different equipment
- different time of day

Everything in the second list is **held constant by design**. A direction that
varies one of them has broken the experiment rather than won it
(`ART_DIRECTION.md` — *Exploration rule*).

### And it is not choosing a movement model

This comparison evaluates how Project Stride **looks and feels while the player
occupies a location**. It is not choosing:

- a joystick movement model
- free-roam traversal
- WASD-style controls
- continuous overworld pathfinding
- a virtual walking substitute for real-world steps

**The shared canonical scene should be understood as a visually represented
location and state — not as proof that the player manually walks around it**
(R-4). Real-world walking remains the movement input, and the world-navigation
model is unresolved.

---

## The canonical scene — fixed for all three

Identical subject, composition, **and camera** in every direction. A direction
that changes any of these is not comparable and does not count as one of the
three.

**This is a real in-game scene** (R-1) — a visually represented location and
state, **not** a depiction of the player steering an avatar around it (R-4) —
viewed under the **shared provisional three-quarter top-down / isometric-lite
camera** (R-2). The ground plane recedes into the frame; the character is seen
from slightly above and in front, high enough to read the terrain and the node
positions around them and low enough to read their full standing silhouette and
equipment. Identical in all three directions.

**Portrait phone frame.** The player character stands at the meadow edge just
outside Haven's Rest, three-quarter-facing the viewer, having half-turned toward
a Meadow Patch to their lower-right. One NPC stands near the settlement gate
behind and to the left. The settlement occupies the upper-left background; the
two roads leave frame upper-right and upper-left. The Meadow Patch is the
brightest, most legible object in the lower third — the thing the thumb would
reach for. Basic HUD overlays top and bottom.

| Element | Fixed content |
|---|---|
| Player character | Full body, three-quarter front-right facing, mid-stride-settled idle |
| Traveler gear | Traveler Tunic worn; Training Sword at hip; Training Axe and Pickaxe stowed on the pack |
| NPC | One standing figure at the gate, non-hostile, idle, clearly a person and not a prop |
| Haven's Rest | Timber palisade gate, two or three roofs behind it, one smoke plume |
| Meadow Patch | A distinct tuft of tall grass and herb stems, lower-right, visually separable from ground grass |
| Ground | Meadow grass with a worn dirt path running from gate to frame-bottom |
| Foliage | Two trees flanking the settlement, low scrub along the palisade |
| Depth | Foreground (patch + character), midground (gate + NPC), background (roofs, treeline, sky) |
| Camera | Shared provisional three-quarter top-down / isometric-lite (R-2) |
| HUD | Top: location name, banked walking energy, sync freshness. Bottom: six-tab bar. Contextual: one gather affordance on the Meadow Patch reading its 90 cost and its 2× yield |

Also held constant across all three: **one NPC of the same description, the same
Traveler gear composition, the same stowed-tool treatment, and the same time of
day** (R-3). None of those is decided — they are simply not allowed to differ
between the images.

---

# Direction A — Classic Pixel MMO Lite

## A.1 Design thesis

Stride looks like a place you could keep for ten years.

Direction A is unhurried and honest. It reads as a sprite game and does not
apologise for it: clean shapes, a restrained earthy palette, everything legible
at arm's length in one glance. The charm is in construction rather than in
effect — a tunic that is obviously cloth, a gate that is obviously timber, a
herb tuft that is obviously worth walking to.

Emotionally it is the register of a well-kept journal illustration: warm,
plain, familiar, and calm enough that opening the app after four days away
feels like returning rather than catching up. Nothing on screen is competing
for attention. Wonder here comes from noticing something small, not from being
shown something loud.

It is not nostalgia cosplay. It is not restricted to 8-bit hardware limits, it
is not tied to any existing MMO's look, and it uses modern conveniences —
sub-pixel-free but colour-generous ramps, soft ambient tinting, clean
anti-alias-free scaling — to be a *cleaner* version of the register than the
games that established it.

## A.2 Canonical scene in Direction A

**Camera.** The shared provisional three-quarter top-down / isometric-lite view
(R-2), unchanged. A expresses it with a fixed tile grid whose cells read as
receding ground rather than as a flat plan, and with actors standing upright on
that ground. No pitch, projection, or composition differs from B or C.

**Player character.** Compact and sturdy. Roughly a 1:4.5 head-to-body ratio
(**PROVISIONAL**) so the head carries identity while the body still reads as an
adult adventurer. Standing idle with weight settled on the back foot, half
turned toward the patch. The silhouette is a clear trapezoid: shoulders wider
than hips, a defined gap between arm and torso, boots planted apart. Two-frame
breathing idle.

**Traveler gear.** Reads by shape, not by texture. The Traveler Tunic is a
belted sand-brown wrap with a visible collar notch and a slightly darker skirt
below the belt — three flat values plus a highlight. The Training Sword hangs
at the left hip as a plain crossguard-and-grip silhouette, deliberately short
and unremarkable so Bronze later feels like an event. The Training Axe and
Pickaxe ride on the pack behind the shoulder, heads visible above the
silhouette line: two small distinct hard shapes that tell you at a glance that
this character is equipped to work.

**NPC.** A settlement figure by the gate in a longer robe, taller and narrower
in silhouette than the player, with a single strong accent colour (a
deep-green mantle) that appears nowhere else in the scene. That accent is the
whole method: NPCs are recognisable because the world palette does not use
their colour. Idle with a slow two-frame lean.

**Meadow Patch.** A raised tuft roughly one and a half tiles wide, built from
taller grass blades than the ground layer, with three pale herb stems rising
above it and one small cream flower head. It is darker at its base and lighter
at its tips, so it separates from the ground even though it is the same family
of greens. A soft one-pixel warm rim on the sunward side lifts it forward.

**Ground and environment.** Tile-based meadow: two grass tile variants and one
tuft overlay, deliberately few, with variation coming from overlay scatter
rather than from tile count. The dirt path is a three-tile-wide worn strip with
irregular edges and a couple of embedded stones, running from gate to
frame-bottom. Ground is unfussy on purpose — a busy ground layer is the single
fastest way to lose a character silhouette on a phone.

**Architecture.** Haven's Rest is timber-and-thatch, built from a small kit:
one palisade post, one gate frame, one wall span, two roof pitches, one chimney.
Roofs are a muted clay-brown, walls a weathered grey-timber, and no building is
more than three storeys of tile. One thin smoke plume, two-frame loop, from the
roof behind the gate.

**Foliage.** Trees are clustered-blob canopies with three value steps and a
visible trunk — not individual leaves. Two flank the settlement; low scrub runs
along the palisade base to hide the tile seam between grass and structure.

**Atmosphere and lighting.** A single fixed light direction (upper-left,
**PROVISIONAL**) baked into every asset. No dynamic lighting. Time of day is
expressed by a full-screen colour-grade overlay swapping the world between
three moods — morning, day, dusk — which costs one overlay rather than three
tile sets.

**Depth treatment.** Three flat planes with no parallax. Depth comes from value
and saturation: background loses contrast and gains a slight cool tint,
foreground keeps full saturation. A soft elliptical contact shadow under every
standing object is what actually sells the ground plane.

**HUD.** Solid opaque panels with a two-pixel bevelled border, seated flush to
the top and bottom edges. Top strip: location name in a pixel display face,
a banked-energy figure with a small boot glyph, and a "synced" dot. Bottom:
six pixel-icon tabs with labels, large targets, the active one raised. The
gather affordance is a small framed plate anchored above the Meadow Patch
showing the herb icon, `×2`, and `90`.

**Interaction feedback.** Tapping the patch snaps a one-pixel bright outline
around it and pushes the plate up four pixels. Confirmation flashes the tuft
white for two frames. Everything is discrete; nothing eases.

## A.3 Character language

**Proportions (PROVISIONAL).** 1:4.5 head-to-body. Roughly 32 px tall on a
16 px tile grid, authored at 1× and displayed at an integer scale.

**Silhouette philosophy.** Read the character as a black shape at 50% size — if
you cannot tell facing, weapon presence, and body attitude, the pose fails.
Limbs are kept clear of the torso outline. Headgear and pack items break the
outline deliberately, because outline-breaking is the cheapest legible way to
show equipment.

**Facial detail.** Two eye pixels, an optional single mouth pixel, no nose.
Expression is carried by head tilt and body posture rather than by face. This
is a deliberate scalability choice: faces at this size cost enormous consistency
effort and return very little on a phone.

**Equipment readability.** Equipment reads by **silhouette first, colour
second, detail never**. A weapon must be identifiable from its outline alone.

**Layering.** A strict paint order — body → legs → torso armour → arms →
weapon → pack → head → headgear — with each equipment piece authored as a
separate transparent layer registered to the same body skeleton per direction.
Composition happens at build time, not by hand.

**Eight-direction turnaround.** Fully compatible with the existing template.
Eight views drawn independently, no mirroring, centre cell empty. At this
resolution the four diagonals are genuinely distinct constructions rather than
skews: the pack shifts across the silhouette, the sword swaps sides, and the
tunic collar notch rotates. Low resolution is an *advantage* here — there is
less surface on which drift can occur, and a diagonal is defined by a dozen
decisive pixels rather than by a rendered form.

**Gear tiers.** Tier is carried by three stacked signals, in order: silhouette
mass (Traveler is soft and narrow, Bronze is broader with hard shoulder
shapes), a dedicated hue family per tier (Traveler earth-neutral, Bronze warm
metal), and a single detail accent added at each tier. No effects, no glow, no
particles on gear.

## A.4 World language

**Terrain.** Tile-based with a small vocabulary — grass, dirt, stone, water —
and transitions handled by a shared auto-tile edge set rather than by
hand-drawn corners. Variation lives in scattered overlays.

**Props.** A shared kit — crates, barrels, fences, signposts, stones, carts —
authored once in a neutral palette and recoloured per region.

**Vegetation.** Canopies as clustered value blobs. Three tree silhouettes
(broad, tall, scrubby) recoloured and recombined rather than redrawn.

**Buildings.** Modular: posts, wall spans, two roof pitches, doors, windows,
chimneys. Any settlement is an arrangement of the kit. This is the single
biggest scalability lever in Direction A.

**Resource nodes.** Every node is a raised, higher-contrast tuft/mass that
breaks the ground plane, with a per-skill shape family: soft fan for Foraging,
vertical trunk for Woodcutting, angular facet for Mining. A player learns three
shapes and can read every node in the game.

**Layering.** Ground → ground overlay → props/nodes → actors → structures →
foreground occluders → colour grade. Fixed and shallow.

**Regional distinction without a new pipeline.** Palette swap of the shared kit,
a different overlay scatter set, one or two region-exclusive silhouettes, and a
different grade overlay. Stonefall Mine is the same tile grammar in cold greys
with angular overlays; Whispering Woods is the same grammar in deep greens with
dense canopy occluders. **Regions change vocabulary, never grammar.**

## A.5 Combat readiness

Turn-based combat (6–12 turns) is the easiest case this style could be asked to
serve, because nothing needs to be readable at speed.

- **Player attacks.** A three-to-four-frame lunge-and-return per facing, plus a
  separate weapon-arc overlay sprite. The arc is where the tier reads: Training
  is a thin pale sweep, Bronze a thicker warm one.
- **Enemies.** Forest Wolf, Cave Goblin, and Hollow Guardian all work as strong
  silhouettes — quadruped low mass, small hunched biped, large slow mass.
  Silhouette-first design makes enemy class instantly legible.
- **Damage feedback.** Two-frame white flash, a short positional shove, and a
  rising pixel number. Cheap, unambiguous, and it never obscures the actor.
- **Telegraphs.** Because combat is turn-based, telegraphs can be *stated*
  rather than animated: a coloured ground marker under the target and a small
  intent icon above the enemy's head, both held until the player acts. This is
  a strength — the style does not need motion to communicate danger.
- **Abilities.** A shared overlay library — impact burst, slash arc, guard
  ring, heal motes — recoloured per ability. New abilities cost a recolour and
  a timing, not a new animation.
- **Hit reactions.** One two-frame flinch per actor, reused for every damage
  source.
- **Status effects.** A small icon strip beneath the actor plus a subtle
  palette tint on the sprite (poison green, burn amber). No looping particles.
- **Boss readability.** Bosses read by mass and by having a silhouette element
  no ordinary enemy owns. Hollow Guardian occupies noticeably more frame than
  anything before it, which in a turn-based fight is the whole job.

**Risk:** restraint can read as flat during combat, which is the one moment the
game asks the player to lean in.

## A.6 Gathering readiness

The Meadow Patch is the first satisfying thing in the game and gets the most
craft.

- **Anticipation.** The patch idles with a slow two-frame sway, out of phase
  with the surrounding grass, so it is already alive before it is touched.
  On tap, the sway stops and the patch compresses one pixel — a held breath.
- **Animation.** Foraging is hands-only. Three to four frames: reach, close,
  pull-and-rise. Woodcutting and Mining reuse a shared tool-swing skeleton with
  a different tool overlay.
- **Resource response.** The patch springs back two pixels past rest and
  settles, then loses its herb stems, then regrows them after a short delay.
  The node visibly changing state is what makes the gather feel *done*.
- **Particles/VFX.** Three or four drifting seed motes on a short arc. That is
  the entire budget, and it is enough.
- **Sound-trigger opportunities.** Four clean hooks — grasp, separate, node
  settle, item confirm — matching the initiation / material response / reward
  confirmation structure in `GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md`. Design of
  the sound itself is out of scope here.
- **Reward feedback.** The herb icon rises from the patch, arcs to the
  Inventory tab, and the tab pips once. The energy figure ticks down 90 by
  counting rather than by jumping, so the cost is felt.

## A.7 UI direction

Structure is governed by `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md` and is not
being redesigned. This is visual language only.

- **Energy.** Banked walking energy as a numeral with a small boot glyph and a
  thin horizontal fill. Presented as a **stock the player owns**, never as a
  draining meter — Stride's energy is banked opportunity, and a depleting bar
  would misrepresent it as the restrictive energy system that
  `06_ANTI_FEATURES.md` forbids.
- **Health.** Segmented pips rather than a continuous bar; combat-screen only.
  Countable segments suit turn-based decisions.
- **Skill progress.** One row per skill: pixel icon, level plate, chunky
  segmented fill. Segments so progress reads without arithmetic.
- **Inventory.** Bevelled square slot grid, item icons in the same pixel
  language as the world, stack counts bottom-right.
- **Equipment.** Paper-doll silhouette with slot plates arranged around it, so
  a change is seen on the character rather than read in a list.
- **Gathering interaction.** The anchored plate described above: icon, yield,
  cost. Never a modal.
- **Combat abilities.** A row of large square ability plates along the bottom
  third, thumb-reachable, each with a pixel icon and a cost.

**Typography (PROVISIONAL).** One bitmap display face for headings and one
clean modern sans for body text and numbers. Full-bitmap body text is a
legibility and localisation liability on a phone.

## A.8 Animation philosophy

**Animate:** the Meadow Patch idle sway and gather response; the character
walk cycle and gather; combat lunge, flinch, and the shared overlay library;
one two-frame ambient loop per settlement (smoke, a banner); NPC idle lean.

**Keep static:** buildings, terrain, props, trees beyond an occasional
canopy shimmer, inventory icons, gear on the paper doll, HUD chrome.

**Budget (PROVISIONAL):** idle 2 frames · walk 4 frames × 8 directions ·
gather 4 frames × 8 directions · attack 4 frames × 8 directions · flinch
2 frames. Everything else is a reusable overlay.

This is the lowest animation workload of the three by a wide margin, and it is
the direction most likely to still be affordable after twenty regions.

## A.9 AI-assisted production fit

**Best fit of the three.**

- **Claude Code workflow.** Strong. Small palettes, integer grids, and layered
  composition mean much of the work is deterministic assembly from specs and
  can be scripted and verified.
- **Structured specifications.** Very strong. A tunic can be fully specified as
  a shape description plus an exact five-colour ramp, and compliance can be
  checked programmatically.
- **AI image generation.** Good, with the standard caveat that generators
  produce *pixel-styled* images rather than true pixel art. Direction A's low
  target resolution makes the downsample-and-quantise cleanup step tractable —
  quantising to a fixed 48-colour palette forces every generated asset back
  into the same look. **That palette lock is the main consistency mechanism.**
- **Sprite sheets.** Excellent. Fixed cell sizes, fixed registration, machine-
  verifiable layout.
- **Deterministic cleanup.** The strongest of the three. Palette quantisation,
  outline enforcement, and alpha cleanup are all rule-based and automatable.
- **Reusable templates.** The building and prop kits mean most new content is
  recombination rather than generation.
- **Eight-direction standard.** Works well. Diagonals need hand correction
  because generators drift on asymmetric equipment placement, but at 32 px a
  correction is a few dozen pixels, not a repaint.

**Consistency problems, stated plainly.** Generators do not hold a palette,
will not hold a light direction across a set, and will silently mirror
asymmetric gear to the wrong side — the exact failure the eight-direction
template exists to forbid. All three are catchable by automated post-checks in
this direction, which is why it scores best.

## A.10 Mobile production risk

| Axis | Rating | Note |
|---|---|---|
| Readability | **LOW** | Designed for a hand; silhouette-first throughout |
| Performance | **LOW** | Small textures, no shaders, flat layers |
| Asset-generation difficulty | **LOW** | Small kits, quantisable, verifiable |
| Animation difficulty | **LOW** | Smallest frame budget of the three |
| Consistency risk | **LOW** | Palette lock and grid enforcement are automatable |
| Long-term scalability | **LOW** | Recombination beats authoring |

**Principal risk is not production — it is distinctiveness.** See the matrix.

## A.11 Signature moment

**The first herb.**

The player taps the Meadow Patch with no tool equipped and nothing in their
hands. The character kneels, the patch compresses one pixel and holds, and for
a beat the whole screen is still — the sway stops, the smoke plume pauses at
the top of its loop. Then the tuft springs back past rest, three seed motes lift
into the upper-left light, and a single Meadow Herb arcs to the Inventory tab.
The energy figure counts down 90 while the character stands.

Two things you did with your own hands: you walked, and you picked it.

---

# Direction B — Modern Premium Pixel Fantasy

## B.1 Design thesis

Stride looks like the walk was worth it.

Direction B keeps pixel construction as the foundation and spends its budget on
**light**. The world is the same fantasy, rendered with atmosphere: warm sun
raking across the meadow, cool shadow pooling under the palisade, dust and
pollen catching in the air between them. Materials read as materials — cloth
absorbs, metal catches, wet stone reflects.

The intended feeling is arrival. The player has been walking in the real world;
opening the app should feel like stepping out into somewhere with weather. It
is the register of a premium indie release: unhurried, atmospheric, and
confident enough to let a quiet meadow carry a screen.

It must still read immediately as a 2D pixel game, and it must be producible at
scale. The discipline that makes that possible is that **the richness is in the
lighting and compositing layers, not in the sprites**. Sprites stay economical
and reusable; the atmosphere is applied to them at runtime.

## B.2 Canonical scene in Direction B

**Camera.** The shared provisional three-quarter top-down / isometric-lite view
(R-2), unchanged — **identical pitch, framing, and subject placement to A and
C**. B's parallax planes are a depth-*separation* technique applied within that
fixed perspective, not a different viewpoint: the camera does not tilt, push in,
lower the horizon, or become cinematic. If B looks more atmospheric than A, that
must be attributable to light and material, never to the camera.

**Player character.** Taller and more articulate than A — roughly 1:6
head-to-body (**PROVISIONAL**), around 64 px tall on a 32 px tile grid. The
idle is a settled contrapposto with weight on one hip and the head turned
further toward the patch than the shoulders, which alone makes the figure read
as looking rather than facing. Cloth at the hem and the pack strap carries a
slow secondary drift.

**Traveler gear.** Materially specific. The Traveler Tunic is layered — an
undershirt at the collar and cuffs, a heavier over-tunic, a leather belt with a
visible buckle, a travel cloak folded and strapped across the pack. Cloth uses
a five-step ramp with a warm bounce colour on the shadow side. The Training
Sword's blade holds a one-pixel specular line that shifts with the light
overlay, so it *glints* — the first metal the player owns actually behaves like
metal. Axe and pickaxe heads sit on the pack, catching the same specular pass.

**NPC.** Fuller-figured with a distinct posture language: shoulders back,
hands clasped, weight even — settled where the player is transient. Wears a
region-identifying green mantle with visible weave texture in its ramp. A soft
warm rim light from the settlement side separates them from the palisade
behind. Four-to-six-frame idle with an occasional look-off.

**Meadow Patch.** The scene's hero object and the most lit thing in frame. A
dense cluster of tall grass and three herb stems with pale cream flower heads,
lit from behind so the blades are half translucent at their tips and dark at
their bases — the one place in the scene where subsurface warmth is faked, and
it is unmistakable. Blades sway on a two-speed loop. A faint warm haze sits in
the air just above it.

**Ground and environment.** Grass built from a tile base plus three overlay
densities plus scattered individual blade sprites at the silhouette edges, so
the ground has a soft top rather than a hard tile line. The dirt path is worn,
slightly sunken, with a darker damp centre and small stones catching the
specular pass. Every standing object gets a directional soft shadow, not an
ellipse.

**Architecture.** Timber-and-thatch as in A, but with material depth: thatch
has visible strand direction and a lit crown, timber has grain and a lighter
weathered top edge, the palisade posts vary in height and lean so the gate does
not read as stamped. Warm interior light spills from one window. The smoke
plume is a soft eight-frame loop that dissipates and catches the sun.

**Foliage.** Trees have a lit crown, a mid mass, and a deep core shadow, plus
a few silhouette leaves breaking the canopy edge. Canopies drift on a slow
loop, and the shadows they cast onto the ground drift with them.

**Atmosphere.** Air is a visible element. A soft light shaft comes through the
open gate, drifting motes are visible where it crosses shade, and a very low
ground haze sits at the treeline. Colour separates depth: warm foreground, cool
distance.

**Lighting.** A single directional key (upper-left, **PROVISIONAL**) baked into
sprites, plus a **runtime light layer** — an additive warm pass, a multiplied
cool shadow pass, and a time-of-day grade. Because it is a layer and not a
sprite property, dawn, overcast, and dusk are three parameter sets rather than
three asset sets. **This is the direction's central production decision.**

**Depth treatment.** Four to five parallax planes — foreground grass fringe,
actor plane, settlement, treeline, sky — with a gentle distance desaturation
and a slight blur on the furthest plane only. Parallax is subtle; this is not a
side-scroller.

**HUD.** Semi-translucent dark glass panels with a soft inner glow and rounded
corners, floating clear of the screen edges. Top: location name in a light
serif-adjacent face, banked energy as a numeral with a thin luminous arc, a
sync indicator. Bottom: six tabs as soft-glass plates, the active one lit from
beneath. The gather affordance floats above the patch as a rounded card with a
lit herb icon, `×2`, and `90`.

**Interaction feedback.** Tapping the patch blooms a soft warm ring outward
from the touch point and lifts the card with a short ease. Confirmation is a
brief warm flash, not white — the light is always the language.

## B.3 Character language

**Proportions (PROVISIONAL).** 1:6 head-to-body, ~64 px tall, 32 px tile grid.

**Silhouette philosophy.** More expressive than A, and consequently more
fragile. Silhouettes are designed with deliberate negative space — a gap under
a raised arm, a cloak edge that flares away from the leg — because at this
detail level a solid mass loses readability faster than a small one does. The
rim-light pass is not decoration; it is the mechanism that keeps the figure off
the background.

**Facial detail.** Eyes, brow, mouth, and hair shape are present but minimal —
enough for direction of gaze and a broad mood, not enough for performance.
Faces are the highest AI-consistency risk in this direction and are kept
deliberately understated for that reason.

**Equipment readability.** Silhouette first, then **material**. Tier is legible
partly through how a piece responds to light: cloth stays matte, bronze takes a
warm broad highlight, later steel takes a tight cool one.

**Layering.** Deeper than A — body → underlayer → legs → torso → cloak-back →
arms → weapon → pack → head → hair → headgear → rim-light pass. The rim pass is
generated per assembled frame rather than authored per part, which keeps the
part count manageable.

**Eight-direction turnaround.** Compatible with the template, and the most
expensive of the three to hold. Eight independently drawn views, no mirroring.
The additional cost is that at 64 px, cloth folds, hair parting, buckle
placement, and specular position must all remain consistent through rotation —
far more surface for drift than A. Mitigation: build each direction from the
same registered part library rather than generating each view whole, and
generate the rim pass procedurally so it cannot disagree with itself.

**Gear tiers.** Four signals: silhouette mass, hue family, material response
under the light pass, and one added detail element per tier. Higher tiers may
earn a *restrained* emissive accent — a faint glow on an enchanted piece — but
this is a ceiling to be defended, not a starting point.

## B.4 World language

**Terrain.** Tiles plus edge-breaking overlay sprites, so no tile boundary is
ever the visible silhouette. Costs more overlays; buys a world that does not
look gridded.

**Props.** The same shared kit approach as A, authored with fuller ramps and a
separate specular mask so props respond to the light layer.

**Vegetation.** Three-mass canopies with silhouette-breaking edge leaves and a
slow drift. A small number of hero trees per region, hand-finished, placed at
composition anchors.

**Buildings.** Modular kit with material-specific ramps, plus one hand-finished
landmark per settlement — Haven's Rest's gate is that landmark. Kit for volume,
landmark for identity.

**Resource nodes.** Same per-skill shape families as A, plus a node-specific
light behaviour: Foraging nodes catch backlight, Mining nodes catch a hard
specular facet, Woodcutting nodes hold a deep core shadow. **A player learns to
recognise nodes by how they catch light**, which makes a location readable at a
glance. This is about *spotting* a node in a presented location, not about
travelling to one — how a node is reached is a world-navigation question and is
unresolved (R-4).

**Layering.** Sky → far parallax → mid parallax → ground → ground overlay →
props/nodes → actors → foreground fringe → light pass → grade. Deeper and more
ordering-sensitive than A.

**Regional distinction without a new pipeline.** The light layer does most of
the work: Stonefall Mine is the same kit under a cold low-key parameter set
with hard point lights and heavy haze; Whispering Woods is dappled green
high-contrast with drifting canopy shadows. **Regions are re-lit before they are
re-drawn**, which is the direction's strongest scalability argument and the
reason the runtime light layer must exist from day one rather than be added
later.

## B.5 Combat readiness

The strongest combat presentation of the three.

- **Player attacks.** Six-to-eight-frame swings with smear frames and a lit
  weapon trail. The trail is a generated ribbon following the weapon's
  registration point, not hand-drawn — one system serving every weapon.
- **Enemies.** Rich silhouettes with material identity — wolf fur catches rim
  light, goblin gear catches specular, Hollow Guardian's stone core glows from
  within. Enemies feel like they belong to the same lit world as the player.
- **Damage feedback.** Layered: a short flash, a directional shove, an impact
  burst at the contact point, and a rising number with weight. Layering means
  small hits and large hits genuinely feel different, which matters over a
  6–12-turn fight.
- **Telegraphs.** Lit ground decals under the threatened area, pulsing on the
  light layer, plus an intent icon. Because the light layer already exists, a
  telegraph is a parameter rather than an asset.
- **Abilities.** A shared VFX system — impact, arc, ring, motes, beam — driven
  by particles and additive sprites with per-ability colour and timing. New
  abilities are configuration.
- **Hit reactions.** Two or three flinch variants by damage magnitude, plus a
  brief desaturation of the struck actor.
- **Status effects.** Icon strip, plus a persistent low-cost particle and a
  tint on the light layer. Poison genuinely looks like poison here.
- **Boss readability.** Excellent. Bosses get mass, a distinct light signature,
  and the right to alter the scene's grade during their turn. Hollow Guardian
  can *dim the room*, which is a boss moment no other direction gets cheaply.

**Risk:** VFX richness is where the animation budget quietly escapes. The
system-driven approach is the control, and it must be built as a system.

## B.6 Gathering readiness

- **Anticipation.** The patch is already the best-lit object on screen before
  it is touched. On tap, the world dims very slightly except the patch and the
  character — a half-second of focus, done entirely on the light layer.
- **Animation.** Six-to-eight-frame hands-only gather: reach, grip, tension,
  separation, rise. The tension frame — the moment the stem resists — is the
  frame that makes it feel physical, and it is worth the cost.
- **Resource response.** The patch bends toward the hand, releases, recoils,
  and settles over several frames; disturbed blades keep moving after the
  character has stopped. Follow-through is the whole trick.
- **Particles/VFX.** Pollen and seed motes lift and **catch the light shaft**,
  drifting for a second after the action. A soft warm bloom at the break point.
- **Sound-trigger opportunities.** Six hooks — approach, grip, tension,
  separation, node settle, reward — enough for a genuinely material-specific
  soundscape, which the audio identity document explicitly wants. Sound design
  itself is out of scope.
- **Reward feedback.** The herb lifts, catches the light once as it rotates,
  arcs to Inventory, and the tab plate lights from beneath. The energy arc
  depletes smoothly and the numeral counts.

## B.7 UI direction

- **Energy.** A numeral with a thin luminous arc. Framed as a **reservoir the
  player filled**, filling toward full rather than draining toward empty — same
  anti-features constraint as A, expressed in light.
- **Health.** A continuous bar with a lit leading edge and a delayed grey chase
  bar showing damage just taken. Combat-screen only.
- **Skill progress.** Per-skill row with an icon, level, and a glowing fill;
  level-up blooms the row.
- **Inventory.** Rounded slot tiles on soft glass, item icons rendered with the
  same light treatment as the world, rarity carried by a subtle slot glow.
- **Equipment.** A lit paper doll on a dark ground, the character rendered as
  they appear in the world, with the light responding as pieces change.
- **Gathering interaction.** The floating lit card.
- **Combat abilities.** Large rounded plates along the bottom, lit when
  affordable and flat when not — affordability read as a light state rather
  than as a grey-out.

**Typography (PROVISIONAL).** A modern humanist sans throughout, with a light
serif display face for location names. No bitmap type — it would fight the
finish.

## B.8 Animation philosophy

**Animate:** everything in A, plus the ambient layer — canopy drift, grass
response, smoke, light-shaft motes, water. Character animation gains
follow-through and secondary motion on cloth and pack.

**Keep static:** buildings, terrain bases, props, HUD chrome, inventory icons.
The ambient life comes from the light and particle layers, **not from animating
the world**, and that distinction is what keeps this direction affordable.

**Budget (PROVISIONAL):** idle 4 frames · walk 6–8 frames × 8 directions ·
gather 8 frames × 8 directions · attack 6–8 frames × 8 directions · 3 flinch
frames. Roughly double A. Ambient motion is procedural — shader-driven grass
sway and particle systems, not frames.

**The honest warning:** this budget is affordable for a starter region and
becomes the project's dominant cost by the third. The mitigation is to keep the
part-library and procedural-ambient discipline absolute from the first asset.

## B.9 AI-assisted production fit

**Workable, and the most demanding of the three.**

- **Claude Code workflow.** Good for assembly, layer ordering, atlas packing,
  and the light-layer parameter sets, all of which are code. Less able to help
  with the finish itself.
- **Structured specifications.** Necessary and harder to write. A spec must
  pin light direction, ramp count, specular behaviour, and material response —
  and a generator will still drift on all four.
- **AI image generation.** This is where the risk concentrates. Generators are
  *good* at producing single beautiful lit pixel-art images and *bad* at
  producing forty of them that agree about where the sun is. Expect
  significantly more manual correction per asset than A.
- **Sprite sheets.** Fine mechanically; the cost is per-frame finishing.
- **Deterministic cleanup.** Partially automatable — palette quantisation and
  registration checks work; verifying that a highlight sits on the correct side
  of a fold does not.
- **Reusable templates.** Strong where used (part library, kit buildings, light
  parameter sets) and the discipline must be enforced, because this is the
  direction where a one-off beautiful asset is most tempting and most damaging.
  `ART_DIRECTION.md` already states the rule: an asset that does not match the
  set is a defect.
- **Eight-direction standard.** Highest cost and highest drift risk of the
  three. Strongly recommend part-library composition over whole-view generation.

**Consistency problems, stated plainly.** Light direction drift, ramp drift,
detail-density drift between assets made in different sessions, and faces that
are subtly a different person in each view. Only the first two are cheaply
automatable.

## B.10 Mobile production risk

| Axis | Rating | Note |
|---|---|---|
| Readability | **LOW–MEDIUM** | Excellent when lit correctly; low-contrast scenes are the failure mode |
| Performance | **MEDIUM** | Parallax, particles, shader passes, larger atlases — fine on a modern phone, needs a budget |
| Asset-generation difficulty | **HIGH** | Finish quality per asset is the cost driver |
| Animation difficulty | **MEDIUM–HIGH** | Roughly double A, before VFX |
| Consistency risk | **HIGH** | Lighting and detail-density drift are hard to automate away |
| Long-term content scalability | **MEDIUM** | Excellent for re-lighting regions; poor for adding many new actors |

## B.11 Signature moment

**The light through the gate.**

The player stands at the meadow edge. A shaft of late-afternoon sun comes
through the open gate of Haven's Rest and lies across the path between the
character and the Meadow Patch — the only fully lit ground in frame, and it
happens to point exactly where the player is about to reach.

They tap the patch. The world dims a half-stop, the character kneels into the
shaft, and when the herb separates, the pollen it releases rises into that beam
and lights up — a hundred drifting motes visible only because the light is
there, settling slowly after the character has already stood.

The game told you where to look using nothing but where the sun was.

---

# Direction C — Stylized 2D Fantasy

## C.1 Design thesis

Stride looks like an illustration you are standing inside.

Direction C leaves pixel construction behind and asks whether Stride is better
served by **shape**. Forms are smooth, confident, and simplified: bold tapered
outlines, flat cel-shaded fills with a single hard shadow break, and a
disciplined palette that treats colour as a naming system rather than as
description. Meadow green is *one* green. The path is *one* brown. A tree is a
few decisive shapes with a strong outline, not a texture.

It is a storybook register — closer to a modern animated production's *rendering
language* than to a sprite sheet — and its advantage on a phone is that it never
fights the screen. Big shapes read at any size, and a character built from four
clear masses is legible in a hand at a glance. **The register is illustrative;
the staging is not.** C uses the same in-perspective camera and the same
canonical composition as A and B (R-2), and is explicitly not a title card, a
key-art plate, or a presentation composition.

The character work is where it earns its place. An illustrated figure can carry
expression that neither pixel direction can: a genuine posture, a readable
glance, a tilt of the head that tells you the character noticed the herb. If
Stride wants the player to feel that this is *their* character, this is the
direction that argues for it hardest.

It must not become a 3D game and must not become an expensive animation
pipeline. The discipline that prevents both is **construction over rendering**:
assets are built from a reusable shape library at vector authoring stage and
exported flat, and animation is deliberately limited and pose-based rather than
frame-by-frame.

## C.2 Canonical scene in Direction C

**Camera.** The shared provisional three-quarter top-down / isometric-lite view
(R-2), unchanged — **identical pitch, framing, and subject placement to A and
B**. C's flat cel treatment is a *rendering* choice, not a projection change:
the ground plane recedes exactly as it does in A and B, the character is seen
from slightly above and in front, and the view is **not** side-on and **not** a
presentation or title-card composition. C's terrain is painted rather than
tiled, but it is painted *in perspective*.

**Player character.** Stylized and slightly heroic-chunky — roughly 1:5
head-to-body (**PROVISIONAL**), with large hands and boots and a smaller waist,
so the character reads as capable rather than cute. Authored as vector art and
exported at a phone-appropriate raster size (**PROVISIONAL**), not
pixel-gridded. The idle is a strong, held, illustrated pose: weight on the back
foot, torso open to the viewer, head clearly turned down-right toward the
patch. Outline is a tapered dark-brown line, heavier at the silhouette and
lighter inside — never pure black.

**Traveler gear.** Reads as **big shapes with a colour identity**. The Traveler
Tunic is one warm sand mass with a single hard shadow break under the chest and
inside the sleeve, a rust-red belt, and a collar cut with one decisive curve.
The Training Sword is a bold simple wedge in muted grey with a wrapped grip —
short, plain, and shaped so that Bronze can be recognisably the *same wedge,
grown*. The axe and pickaxe on the pack are two unmistakable graphic
silhouettes: a quarter-disc and a T. Gear is identified by shape and hue, and
never by detail density.

**NPC.** Visibly a different *kind* of shape from the player: rounder mass,
lower centre of gravity, a long soft mantle that reads as one continuous curve
against the player's angular forms. Deep-green mantle, warm skin, an open and
settled posture with hands clasped. Facial expression is genuinely readable at
phone size — a small smile and eyes directed at the player. Idle is a two-pose
cross-blend, not a frame cycle.

**Meadow Patch.** The clearest object in the scene, and unmistakably a *thing
you can touch*. Built from seven or eight bold tapered blade shapes fanning
from one root point, with three herb stems rising above and one cream flower
head as the focal accent. It uses a green one step brighter and one step more
saturated than any ground green — separation by palette rule, not by lighting.
It sits on a soft flat drop shadow that anchors it to the ground.

**Ground and environment.** Not tiled. The meadow is a painted flat field of
one base green with a few large soft value shapes for undulation and scattered
graphic grass tufts near the silhouette edges. The path is a single confident
tapering brown shape with a slightly darker edge, drawn as a stroke rather than
assembled from tiles. Ground detail is deliberately sparse — the ground's job
is to be quiet so the character and the node are loud.

**Architecture.** Haven's Rest is built from simplified geometry with character:
roofs are single bold trapezoids with a slight sag in the ridge line, the
palisade is a rhythm of rounded posts of varying height, and the gate is one
strong arch shape. Buildings lean very slightly, which does more for warmth
than any amount of texture. Two flat values per surface — lit and shadow — and
nothing more.

**Foliage.** Trees are three or four overlapping rounded canopy masses with one
hard shadow break, a bold tapered trunk, and a handful of silhouette notches so
the outline is not a plain oval. Instantly recognisable, endlessly recolourable.

**Atmosphere.** Carried entirely by colour and by large soft shapes: a warm
gradient sky, a soft distant hill band in a desaturated blue-green, and a
gentle vignette. No haze, no particles in the ambient state. The mood is
graphic clarity rather than air.

**Lighting.** Not simulated. Each asset is authored with a **fixed lit side and
a single hard shadow break** (upper-left, **PROVISIONAL**), and that is the
entire lighting model. Time of day is a palette set plus a soft overlay tint —
three moods, three parameter sets, zero new assets. Cheapest lighting model of
the three, and the least capable.

**Depth treatment.** Layered flat planes with clear scale and value separation:
foreground grass fringe at full saturation, actors, settlement, and a
desaturated distant band. Slight parallax at most. Depth is carried by *scale
and value* here rather than by rendering — but the spatial arrangement itself is
the shared canonical composition (R-2) and is not C's to restage.

**HUD.** Clean and graphic: flat rounded panels in an off-white or deep ink
tone, thick friendly outlines matching the world's line weight, bold geometric
icons. Top: location name in a rounded display face, banked energy as a numeral
with a bold boot icon and a chunky rounded fill, a sync dot. Bottom: six tabs
as bold outlined icons with labels, the active one filled solid. The gather
affordance is a rounded speech-bubble-shaped card anchored to the patch with
the herb icon, `×2`, and `90`.

**Interaction feedback.** Tapping the patch pops it in scale — up 6% and back —
and the card springs with a slight overshoot. Confirmation is a single
expanding outline ring. Motion is snappy and elastic; this is the only
direction where easing curves are part of the visual identity.

## C.3 Character language

**Proportions (PROVISIONAL).** 1:5 head-to-body, authored as vector, exported
at a fixed on-screen height (**PROVISIONAL**). Large hands, large boots, small
waist, defined shoulder line.

**Silhouette philosophy.** The strictest of the three, and necessarily so: with
no pixel grid and no lighting to help, **the outline is the entire read**. Every
character is designed as a small number of large masses with clear negative
space between them. A shape-language rule separates classes of being — the
player and NPCs are built from soft-cornered forms, enemies from angular ones.

**Facial detail.** The highest of the three, and the direction's most
distinctive asset. Eyes with pupils and a brow line, a mouth shape, a defined
hairstyle silhouette. Expression is a real communication channel — an NPC can
look worried, and the player can look at what they are about to pick.

**Equipment readability.** Shape and hue, with detail deliberately suppressed.
An equipment piece is a memorable graphic mark. This is the most *iconic*
equipment language of the three and the least *material* one — bronze and steel
must be distinguished by hue and shape, because there is no specular pass to
separate them.

**Layering.** Vector-part composition — body → legs → tunic → arms → weapon →
pack → head → hair → headgear — with outlines authored per part and merged so
the silhouette carries one continuous heavy line while interior lines stay
light. **Getting the merged outline right is the direction's hardest technical
detail** and is where a naive implementation looks like stickers on a page.

**Eight-direction turnaround.** Compatible with the template and the **highest
consistency risk of the three**. Eight independently drawn views, no mirroring —
and a smooth illustrated form has no grid to snap back to, so any drift in line
weight, proportion, or face reads immediately as "a different character".

The mitigation is decisive: **build the eight views by construction, not by
generation.** Author one vector part library, define the eight views as
part-transform sets, and render them deterministically. Vector construction is
in fact the *most* reproducible of the three approaches — but only if the
pipeline is construction-based. Generated whole views in this style will not
hold identity across eight cells, and that should be treated as established
rather than as something to test expensively.

**Gear tiers.** Three signals: silhouette growth (the same shape, larger and
more articulated), a per-tier hue family, and one added graphic element per
tier — a shoulder plate, a trim line, a pauldron notch. Deliberately simple,
because that simplicity is what keeps twenty tiers drawable.

## C.4 World language

**Terrain.** Painted flat fields with soft value shapes, not tiles. Regions are
composed rather than assembled, which is more expressive per screen and less
automatable per screen.

**Props.** A bold shape library — crate, barrel, fence, post, stone, cart —
each a memorable graphic mark, recoloured freely.

**Vegetation.** Three canopy silhouettes and three trunk shapes, recombined and
recoloured. Extremely cheap to extend.

**Buildings.** A geometric kit — roof trapezoids, wall blocks, arch, post,
chimney — with deliberate small irregularities baked in so a settlement never
looks stamped.

**Resource nodes.** The strongest node language of the three. Every node is a
bold graphic mark with a per-skill shape family (fan for Foraging, vertical
cluster for Woodcutting, faceted wedge for Mining) and a slightly elevated
saturation. Nodes are impossible to miss on a phone, which is a direct benefit
in a game where *spotting and selecting a node* is a frequent interaction —
however the player eventually comes to be standing in front of one (U-6).

**Layering.** Sky → distant band → settlement → actors → ground → ground
detail → foreground fringe → tint. Shallow and simple.

**Regional distinction without a new pipeline.** Palette sets do nearly all of
it, and in this direction palette is unusually powerful because colour is
already carrying meaning rather than description. Stonefall Mine is the same
shape library in cold blue-greys with angular substitutions; Whispering Woods
is deep green with denser canopy overlap and a lower value key. Add one or two
region-exclusive silhouettes for identity. **Cheapest region-creation cost of
the three.**

## C.5 Combat readiness

Strong, in a different register from B — graphic impact rather than simulated
force.

- **Player attacks.** Pose-to-pose: wind-up, a hard smear shape, and a held
  impact pose. Three to five poses per attack, not a smooth cycle. The smear is
  a drawn graphic shape, which is both cheap and stylistically native.
- **Enemies.** Excellent. Angular shape language separates them from the player
  instantly, and simplified forms mean an enemy can be *large* without becoming
  expensive. Forest Wolf reads as three sharp masses; Hollow Guardian can fill
  a third of the screen for the cost of a few big shapes.
- **Damage feedback.** Graphic and immediate: a solid-colour hit flash on the
  actor, a bold impact star, a snappy squash-and-stretch, and a heavy rising
  number in the UI face. Impact reads as punchy rather than as physical.
- **Telegraphs.** The clearest of the three. A bold flat ground shape in a
  saturated warning colour under the threatened area, plus a large intent icon.
  Nothing competes with it, because the world is graphically quiet.
- **Abilities.** A shape-based VFX library — burst, arc, ring, spiral, shard —
  recoloured and rescaled per ability. Very cheap to extend and stylistically
  consistent by construction.
- **Hit reactions.** Squash-and-stretch plus a single flinch pose. Elastic
  motion carries a surprising amount of impact with almost no assets.
- **Status effects.** Bold icons plus a flat colour overlay on the actor.
  Extremely readable, somewhat blunt.
- **Boss readability.** Very good on scale and silhouette; weaker on menace.
  A boss can be enormous and unmistakable, but the style cannot easily make it
  feel *heavy* — that job falls almost entirely to animation timing and audio.

**Risk:** the style's graphic clarity can make combat read as light or cartoon-
adjacent, which may under-serve the "proof of preparation" weight the combat
philosophy asks the Hollow Guardian to carry.

## C.6 Gathering readiness

- **Anticipation.** The patch is the brightest, most saturated mark in the
  lower third and idles with a slow elastic sway. On tap it compresses
  noticeably — squash is the anticipation, and it is unmistakable at phone
  size.
- **Animation.** Pose-based: reach pose, grip pose, a stretched pull pose, a
  release pose. Four poses with strong easing between them read as a complete
  action without a frame cycle.
- **Resource response.** The patch stretches toward the hand, snaps back with
  a clear elastic overshoot, and wobbles to rest. Overshoot is the payoff and
  it costs nothing but a curve.
- **Particles/VFX.** Bold graphic motes and one expanding outline ring, plus
  two or three simple leaf shapes tumbling with rotation. Shapes, not sparkles.
- **Sound-trigger opportunities.** Five hooks — grasp, stretch, snap, node
  settle, reward. The snap in particular is a strong, obvious audio anchor. Sound
  design itself is out of scope.
- **Reward feedback.** The Meadow Herb pops out at an exaggerated scale, scales
  down as it arcs to the Inventory tab, and the tab bounces. The energy numeral
  counts down and its fill shortens with a spring. Reward feedback is the most
  immediately *fun* of the three.

## C.7 UI direction

The most naturally mobile-native UI language of the three, because the world
and the interface already share a shape vocabulary.

- **Energy.** Bold boot icon, large numeral, chunky rounded fill that reads as
  a **stock owned**, not a meter draining — same anti-features constraint, third
  expression.
- **Health.** Chunky rounded segments with a bold outline. Combat-screen only.
- **Skill progress.** Per-skill row with a bold icon, a large level numeral,
  and a thick rounded fill. Level-up pops the row with a spring.
- **Inventory.** Rounded outlined slots, bold flat item icons, large stack
  numerals. Reads perfectly at a glance and one-handed.
- **Equipment.** A full illustrated character portrait with slot chips arranged
  around it — the direction where the paper doll is genuinely a portrait the
  player might want to look at.
- **Gathering interaction.** The anchored rounded card.
- **Combat abilities.** Large rounded outlined buttons along the bottom;
  unaffordable abilities desaturate rather than grey out.

**Typography (PROVISIONAL).** A rounded geometric sans throughout, heavier
weights for numerals. Type is part of the identity here in a way it is not in A.

## C.8 Animation philosophy

**Animate:** the character (pose-based walk, gather, attack, idle), the Meadow
Patch response, UI springs and transitions, one ambient loop per settlement.
The elastic timing *is* the animation identity — most of the perceived quality
comes from easing curves, not from frame count.

**Keep static:** buildings, terrain, props, trees (aside from a slow canopy
tilt), inventory icons, HUD chrome.

**Budget (PROVISIONAL):** idle 2 poses cross-blended · walk 5–6 poses ×
8 directions · gather 4 poses × 8 directions · attack 4–5 poses × 8 directions ·
1 flinch pose. Comparable to A in asset count, with more of the effort in
timing than in drawing.

**The explicit guard.** Do not adopt skeletal or bone-based rigging with deep
hierarchies, mesh deformation, or inverse kinematics. Cutout transforms with
easing are permitted; anything requiring an animation-software pipeline and
per-character rigging is exactly the expensive pipeline this direction is
required not to become.

## C.9 AI-assisted production fit

**The most conditional of the three. The pipeline choice decides the outcome.**

- **Claude Code workflow.** Potentially the strongest, and for an unexpected
  reason: **flat vector shapes are code.** SVG paths, transforms, and palette
  tokens are text, generatable, diffable, reviewable, and deterministically
  renderable. Eight directions become eight transform sets. A tier variant
  becomes a palette token swap. This is the only direction where assets can be
  version-controlled as source rather than as binaries.
- **Structured specifications.** Excellent. "Four masses, this line weight,
  this palette token, this shadow break" is a specification a machine can both
  follow and verify.
- **AI image generation.** **The weakest of the three, and dangerously so.**
  Generators produce lovely single illustrations and cannot hold line weight,
  proportion, or facial identity across a set. Whole-view generation in this
  style will not survive an eight-direction sheet. Generation's honest role here
  is *concept and reference* — establishing the look — with production coming
  from constructed vector parts.
- **Sprite sheets.** Straightforward once assets are constructed; rendering a
  sheet from a part library is a build step.
- **Deterministic cleanup.** Not applicable in the pixel sense, and largely
  unnecessary — construction sidesteps the problem instead of cleaning up after
  it. Line-weight and palette-token compliance are directly checkable.
- **Reusable templates.** The best of the three. A part library plus palette
  tokens is close to a true content pipeline.
- **Eight-direction standard.** Highest risk under generation, **lowest risk
  under construction**. The template's no-mirroring rule is satisfied naturally
  by defining eight independent transform sets with correctly-sided asymmetric
  parts.

**Consistency problems, stated plainly.** Under a generation-led pipeline: line
weight drift, proportion drift, facial-identity drift, and shading-break
inconsistency — all highly visible and none cheaply automatable. Under a
construction-led pipeline these largely vanish, and are replaced by a different
cost: **more human art direction up front** to author the library, and a hard
ceiling on organic detail. The owner should read C's rating as *bimodal*, not
average.

## C.10 Mobile production risk

Two ratings where the pipeline choice changes the answer.

| Axis | Rating | Note |
|---|---|---|
| Readability | **LOW** | Best of the three at small size; bold shapes never fight the screen |
| Performance | **LOW** | Flat fills, few layers, no shader passes |
| Asset-generation difficulty | **HIGH** (generation-led) / **MEDIUM** (construction-led) | The pipeline decides it |
| Animation difficulty | **LOW–MEDIUM** | Pose-based; cost is in timing craft, not frames |
| Consistency risk | **HIGH** (generation-led) / **LOW** (construction-led) | The single most pipeline-dependent figure in this document |
| Long-term content scalability | **LOW** risk | Cheapest region creation and cheapest variant creation of the three |

## C.11 Signature moment

**The look.**

Before the player taps anything, the character is already looking at the Meadow
Patch — head clearly turned down-right, shoulders still square to the viewer,
one hand slightly open at their side. The NPC by the gate is looking at the
player. Nothing has happened yet and the scene already has attention in it.

The tap: the character's pose snaps to a reach, the patch squashes, the herb
pulls free with a hard elastic snap, and the patch wobbles to rest a beat after
the character has already stood back up. The Meadow Herb pops out at twice its
size and shrinks as it flies to the Inventory tab, which bounces.

Nothing was rendered. Everything was *drawn* — and the character noticed the
herb before you did.

---

# Comparison matrix

Independent assessments, made after all three were developed. **No winner is
named.** Ratings are judgements about each direction as described above, not
about the styles in general.

| Axis | A — Classic Pixel MMO Lite | B — Modern Premium Pixel | C — Stylized 2D Fantasy |
|---|---|---|---|
| **Mobile readability** | High — silhouette-first, built for a hand | Medium–High — excellent when lit well; low-contrast scenes are the failure mode | **Highest** — bold shapes never fight the screen |
| **Visual personality** | Low–Medium — the register is familiar by design | High — atmosphere is a strong identity | **Highest** — the most immediately "a specific game" |
| **MMO feeling** | **Highest** — the register the reference points established | High — premium MMO-adjacent | Medium — reads adventure/storybook more than MMO |
| **Nostalgia** | **Highest** | High | Low |
| **Modern polish** | Low–Medium — deliberately restrained | **Highest** | High, in a different register |
| **Character customization potential** | Medium — layers compose easily, expression is limited | High — layers plus material response | **Highest** — real faces, real posture, strongest identity |
| **Equipment readability** | High — silhouette-driven | **Highest** — silhouette plus material response | High — iconic but not material |
| **Environmental richness** | Low–Medium | **Highest** | Medium — graphic rather than rich |
| **Combat readability** | High — turn-based suits stated telegraphs | **Highest** — layered feedback, lit telegraphs | High — clearest telegraphs, least weight |
| **AI-production suitability** | **Highest** — quantisable, verifiable, automatable | Low–Medium — finish quality resists automation | Bimodal: **Highest** constructed / Lowest generated |
| **Animation workload** | **Lowest** | **Highest** | Low–Medium |
| **Long-term scalability** | High — recombination beats authoring | Medium — great at re-lighting, costly per new actor | **Highest** — cheapest regions and variants |
| **Risk of looking generic** | **Highest** — the honest weakness of a familiar register | Medium — atmosphere differentiates, but the register is crowded | **Lowest** |
| **Risk of inconsistent AI assets** | **Lowest** — palette lock catches most drift | **Highest** — lighting and detail drift resist automation | Bimodal: **Lowest** constructed / **Highest** generated |

## Three observations the matrix makes visible

1. **A and B trade personality against production cost almost exactly.** A is
   cheapest and most reproducible and carries the highest risk of looking like
   something the player has already seen. B is the most distinctive-looking and
   the most expensive to keep consistent. Neither is a compromise of the other.

2. **C's ratings are not a single answer.** Under a construction-led vector
   pipeline it is among the best on consistency and scalability; under a
   generation-led pipeline it is the worst on both. This is a **pipeline
   decision presented as a style decision**, and it should be evaluated as one.

3. **All three satisfy the stated design intent.** 2D-first, strong silhouettes,
   mobile-first, modern polish permitted, AI-assisted production plausible.
   C stretches "pixel-art leaning" the furthest, which is what it was asked to
   test.

---

# Hybrid opportunities

Identified only after all three were complete. **These are observations, not a
fourth direction, and no hybrid is being proposed for adoption.** Five maximum,
as scoped.

**H-1 — Character proportions and silhouette discipline from A + lighting
philosophy from B.**
A's compact figure and outline-first construction are the cheapest way to keep
a character readable on a phone. B's runtime light layer is independent of
sprite resolution and would apply to A's sprites unchanged. Plausibly the
highest value-per-cost combination in this document: most of B's atmosphere at
close to A's asset cost. Would need testing — a light pass on a low-resolution
sprite can muddy exactly the silhouette that A depends on.

**H-2 — C's construction-led asset pipeline applied to A or B's visual output.**
The genuinely transferable idea in C is not its look; it is authoring assets as
constructed sources rather than generated images. A part library with palette
tokens, rendered deterministically to sprite sheets, would address the
eight-direction consistency risk in every direction. This is a **process**
hybrid and is compatible with all three visual outcomes.

**H-3 — C's UI and interaction language over A or B's world.**
C's bold, high-contrast, spring-timed interface is the most mobile-native of
the three and does not depend on the world being illustrated. A pixel world with
a clean graphic HUD is a well-established and legitimate pairing. Risk: the UI
and world can read as belonging to two different products if line weight and
palette are not deliberately reconciled.

**H-4 — B's node lighting behaviour + C's node shape language.**
C's bold per-skill node silhouettes make nodes findable; B's per-material light
response makes them feel *worth* finding. Combined, resource nodes would be the
most distinctive object class in the game — appropriate, since spotting and
selecting a node is a frequent player interaction regardless of which
world-navigation model is eventually chosen (U-6).

**H-5 — A's animation budget as the ceiling for whichever direction wins.**
A's frame budget and its animate/static split are a discipline rather than a
style. Applied to B, it forces the ambient-motion-is-procedural rule to be
absolute. Applied to C, it reinforces pose-based over rigged animation. This is
the cheapest available insurance against the workload risk this document names
three times.

---

# Provisional values reference

**Every value in this table is PROVISIONAL.** No row is a project standard, and
no row may be cited as a decision — including the shared camera row, which is
provisional for this exploration only (R-2). Except where a row is explicitly
marked **shared**, values belong to their own direction and must not be averaged
or combined across columns.
See `RULES.md` G-3 and `ART_DIRECTION.md` — *UNRESOLVED*.

| Parameter | A — Classic Pixel MMO Lite | B — Modern Premium Pixel | C — Stylized 2D Fantasy |
|---|---|---|---|
| **Camera family** | **Shared — three-quarter top-down / isometric-lite (R-2)** | **Shared — identical** | **Shared — identical** |
| Depth technique *within* that camera | Three flat planes, no parallax | 4–5 parallax planes, distance desaturation, far-plane blur | Layered flat planes, scale and value separation, slight parallax at most |
| Character height | ~32 px | ~64 px | Vector; fixed on-screen height |
| Tile / grid | 16 px | 32 px | None — painted fields |
| Head-to-body ratio | ~1:4.5 | ~1:6 | ~1:5 |
| Palette size | ~48 master colours | ~96 plus runtime light layers | ~32 tokens plus per-region sets |
| Outline | 1 px selective dark tint | Selective, with rim-light pass | Tapered dark-brown, weight-varied |
| Shading | 3-step ramps, no dithering | 5-step ramps, specular, runtime light | Flat fill, one hard shadow break |
| Light direction | Upper-left, baked | Upper-left, baked plus runtime layer | Upper-left, baked |
| Time of day | Grade overlay, 3 moods | Light-layer parameter sets | Palette set plus tint overlay |
| Idle | 2 frames | 4 frames | 2 poses, cross-blended |
| Walk | 4 frames × 8 dir | 6–8 frames × 8 dir | 5–6 poses × 8 dir |
| Gather | 4 frames × 8 dir | 8 frames × 8 dir | 4 poses × 8 dir |
| Attack | 4 frames × 8 dir | 6–8 frames × 8 dir | 4–5 poses × 8 dir |
| Ambient motion | Hand-authored 2-frame loops | Procedural — shader sway, particles | Easing curves only |
| Typography | Bitmap display + modern sans body | Humanist sans + light serif display | Rounded geometric sans throughout |
| HUD surface | Opaque bevelled panels | Translucent soft glass | Flat rounded outlined panels |

---

# Unresolved questions

Recorded here because they were encountered during this exploration.
Per `RULES.md` G-3 the open ones are **not answered** in this document and none
has been silently decided.

## Closed — nothing now blocks visual generation

**U-1 — Does Project Stride render a scene at all? → CLOSED by R-1.**
It does. The world view is real, the tabs are support surfaces, and the
canonical scene is an in-game scene rather than a menu illustration. Raised
because `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md` and
`MILESTONES/MILESTONE_01_FIRST_ADVENTURE.md` describe six tabs and one combat
modal and mention no world view. **Those documents still say that**, and
reconciling them is flagged in R-1 as separate work.

**U-2 — What camera? → CLOSED by R-2.**
One shared provisional camera family across all three directions:
three-quarter top-down / isometric-lite. Exact pitch, projection type, tile
geometry, and sprite dimensions remain UNRESOLVED, and none of them is needed to
produce a comparison image. The eight-direction template's `{{CAMERA_ANGLE}}`
parameter is satisfied for exploration purposes by R-2 and **remains UNRESOLVED
for production**.

## Open — deliberately unresolved, and held identical across A/B/C

Per R-3, these are not decided. When generation begins, all three directions
use the **same** provisional answer to each, so an open question cannot
masquerade as a difference in art direction.

**U-3 — How many visible pieces is the "Traveler armor set"?**
The Starter Content Bible says *Traveler armor set*; `items.json` contains
exactly one armour entry, `item.traveler_tunic`. One item and a "set" are
different pictures. All three directions above depict the tunic plus belt and
pack, which is an assumption made for the scene and nothing more.

**U-4 — Who is the Haven's Rest NPC?**
No named NPC exists in any document or content file. The canonical scene
requires one. The NPC described in all three directions is a generic settlement
figure, deliberately unnamed, and is not a proposal for a character.

**U-5 — Is the pack visible on the player character?**
The Training Axe and Pickaxe must go somewhere in a scene where the player
carries three tools and a sword. All three directions place them on a back pack
because it is the strongest silhouette solution; whether the player character
visibly carries stowed tools is a design question, not an art one.

**U-6 — What is the world-navigation model?**
Raised and left open by R-4. The world view is real and the player is visually
present in it; **how the player moves between and within locations is not
decided.** Node-, destination-, menu-, and step/progression-driven models are all
open. Joystick, WASD-style, continuous pathfinding, and free-roam models are
**excluded by default** under R-4 and would need an explicit owner reversal.
Nothing in this document depends on the answer, and no direction is advantaged
or disadvantaged by it.

## The full unresolved list, restated

Everything still open after R-1 through R-4, in one place:

| Unresolved | Where |
|---|---|
| Exact world-navigation model | U-6, R-4 |
| Exact camera pitch, yaw, projection type, tile geometry | R-2 |
| Traveler starter gear visual composition | U-3 |
| Haven's Rest NPC identity and design | U-4 |
| Stowed-tool visibility | U-5 |
| Final palette | `ART_DIRECTION.md` |
| Final sprite dimensions | `ART_DIRECTION.md` |
| Animation frame counts | `ART_DIRECTION.md` |
| Exact rendering treatment | `ART_DIRECTION.md` |
| Exact character proportions | `ART_DIRECTION.md` |
| Final UI visual language | `ART_DIRECTION.md` |

Every provisional value proposed in this document sits *inside* one of these
rows and does not resolve it.

---

# Scope statement

**What this task did.** Read the governance and design documents, developed
three visual directions against one fixed canonical scene and one shared camera,
compared them, identified hybrid opportunities, and recorded the owner's rulings
R-1 through R-4.

**What this task did not do, deliberately.**

- No gameplay system, HealthKit code, persistence, platform adapter, CI
  configuration, or architecture was touched.
- No art was generated.
- `ART_DIRECTION.md` was not modified and still reads **EXPLORATION**. No
  winner is chosen.
- No ADR was created. R-1 through R-4 live here, by owner direction.
- Travel, navigation, world-map structure, and combat controls were not
  redesigned. The world view was not implemented or specified beyond R-1's
  statement that it exists and R-4's statement of what it does not imply.
- **No movement model was chosen.** Joystick, WASD-style, continuous
  pathfinding, and free-roam traversal are excluded by default (R-4); the actual
  world-navigation model is open (U-6).
- No canonical UX, milestone, or vision document was amended. The clarification
  R-1 implies for `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md` and
  `MILESTONES/MILESTONE_01_FIRST_ADVENTURE.md` is flagged, not made.
- U-3, U-4, and U-5 remain unresolved.
- No provisional value here — including the shared camera — has been promoted to
  a project standard.
- No fourth hybrid direction was created.

**What happens next is the owner's call.** The available next steps are:
generate the three comparison images under R-1/R-2/R-3; or select or hybridize a
direction first; or reject all three and re-scope the exploration.
