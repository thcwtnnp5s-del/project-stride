# Direction A — Identity Exploration 01

**Status: EXPLORATION — nothing here is a decision.**

Three identity treatments, all firmly inside **Direction A — Classic Pixel MMO
Lite**, answering one question:

> **How do we make Classic Pixel MMO Lite feel unmistakably like Project
> Stride?**

**No art has been generated.** **No production art direction is selected.**
`GAME_BIBLE/ART/ART_DIRECTION.md` still reads **EXPLORATION** and was not
modified. No gameplay, systems, milestone, or navigation document was touched.

**No winner is named. No hybrid is proposed.** A1, A2, and A3 are three
different ways of making A feel like Project Stride, not a fourth, fifth, and
sixth candidate direction.

**Owner review — approved.** The A1/A2/A3 set is approved and **all three
proceed to the controlled visual comparison**. Two owner rulings were made at
that review and are recorded below: **RA-1** (the A2 symbol constraint, §A2.0)
and **RA-2** (the visual-test sequence, §Visual sample preparation). Neither is
an ADR.

**Not an elimination, and not a ranking.** Current owner and project-review
interest is strongest in A1 and A3. **A2 is not eliminated**, proceeds to the
same comparison on the same terms, and **must not be weakened, under-specified,
or under-produced to reflect that interest** — the same "each direction is a
serious candidate" discipline that governed A/B/C
(`VISUAL_SAMPLE_GENERATION_01.md` §2) governs A1/A2/A3.

---

## 0. How to read this document

Every value below that is not drawn from `assets/content/v1/*.json` is
**PROVISIONAL FOR THIS EXPLORATION ONLY**. A value used to make a treatment
describable has not been chosen, and does not become the project's value by
being the only one written down (`RULES.md` G-3, `ART_DIRECTION.md` —
*UNRESOLVED*).

Per owner instruction, this task deliberately **does not specify** production
pixel dimensions, frame counts, palettes, or camera geometry. Where a number
appears at all it is marked **PROVISIONAL** and exists to make a sentence
concrete rather than to propose a standard.

### What this exploration inherits and does not reopen

| Inherited | Source |
|---|---|
| R-1 — Project Stride has a real player-facing world view | `VISUAL_EXPLORATION_01.md` |
| R-2 — one shared provisional camera family for comparisons | `VISUAL_EXPLORATION_01.md` |
| R-3 — U-3 / U-4 / U-5 stay unresolved and identical across compared samples | `VISUAL_EXPLORATION_01.md` |
| R-4 — world presence is **not** joystick, WASD, pathfinding, or free-roam | `VISUAL_EXPLORATION_01.md` |
| §14 — Direction A preferred; B's rendering must not bleed in | `VISUAL_SAMPLE_GENERATION_01.md` |
| §15 — Living Activity Presentation, and LAP-1/2/3 | `VISUAL_SAMPLE_GENERATION_01.md` |
| U-6 — the world-navigation model | **UNRESOLVED** |

### The existing preferred sample is a reference, not an asset

The previously preferred Direction A sample is treated as a **qualitative owner
reference**. What it establishes and what this document preserves:

restrained pixel treatment · a readable world · grounded MMO feel · low visual
clutter · calm atmosphere · no implication of joystick movement.

What it does **not** establish: any specific palette value, tile size,
proportion, roof shape, foliage density, or HUD arrangement. Accidental details
of one generation are not canon and are not imitated here.

---

## 1. The shared floor — what all three preserve

A1, A2, and A3 differ in **identity**, not in **register**. Every one of them
holds all of the following, and a treatment that breaks one has left Direction A
rather than expressed it:

- obvious, intentional pixel-art identity
- restrained rendering — construction over effect
- grounded fantasy
- strong, readable silhouettes
- mobile-first readability, judged at phone size in a hand
- economical environmental detail
- **quiet terrain beneath gameplay-important objects**
- low animation burden
- practical long-term asset scalability
- old-school MMO spirit without copying an existing game
- WalkScape-compatible world presence (R-4)
- living activity presentation (§15)
- **no B-style rendering creep**

### The anti-drift boundary, restated as a test

Before any A-iteration asset is accepted, ask: *does this asset become better by
being rendered more, or by being designed better?* If the honest answer is
"rendered more", it is drift.

Specifically excluded from all three treatments unless the owner explicitly
reverses it:

richer atmospheric lighting systems · cinematic light shafts · strong warm/cool
lighting contrast · premium material rendering · high-detail cloth and material
treatment · heavy haze · constant particles · rich multi-plane cinematic
atmosphere · visually dense foliage · substantial rendering complexity ·
premium-indie spectacle as the route to originality.

**Distinctiveness comes from design language.** Shape, motif, silhouette,
palette discipline, icon geometry, node language, architectural grammar,
animation personality, and ambient motion character. Not from light.

### The living-activity floor, restated as a law

> **AMBIENT MOTION MAY BE TIME-BASED. PROGRESSION MAY NOT BE.**

The presentation layer may **display** an authorized gameplay event. It may not
**create** one. Watching longer never grants progress (`RULES.md` P-4, P-5;
`DECISIONS/0001`; LAP-1, LAP-2). Every ambient loop described below is cosmetic;
every "occasional event" described below is a *visualization of already-
authorized state*, and none of the three treatments may be cited as designing a
scheduler, an event queue, or an offline replay model.

---

# A1 — FRONTIER HEARTH

## A1.1 Design thesis

**Project Stride is the place you come back to, and the work you came back for.**

A1 finds identity in **settlement life, craft, and preparation for the road**.
Haven's Rest is a frontier holding: timber, canvas, rope, leather, banked
firewood, a repaired gate. Everything visible has a job. The player character is
not a chosen hero; they are a **competent traveller with good boots and a full
pack**, and the world respects that.

**Emotional tone:** calm competence. The satisfaction of a sharpened tool, a
stacked woodpile, a pot that has been used a thousand times. Warm without being
soft. Lived-in without being cluttered.

**Why it is still unmistakably Direction A:** warmth here is carried by
**palette and object choice**, never by lighting. A hearth reads warm because
the fire tile is warm and the timber around it is honest brown — not because a
light layer casts glow across the scene. The rendering stays flat, baked,
three-step, and outline-selective. A1 is A with a *subject-matter* identity, not
a *finish* identity.

**Canon fit:** `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md` already calls
Haven's Rest a **frontier settlement**. A1 is the most canon-native of the
three — it renders what the documents already say and adds nothing. (Under
RA-1, **no** treatment may add world material; A1 is simply the one that never
wanted to.)

## A1.2 Signature shape language

**Governing geometry:** *the sturdy rectangle with a working joint.* Shapes are
squared, braced, and visibly fastened. Where two things meet, the fastening is
the detail.

| Element | Shape language |
|---|---|
| **Character silhouette** | Broad-shouldered trapezoid, wide stance, pack squaring the upper back. Bulk sits at shoulders and boots — the silhouette says *carries things and walks far* |
| **Building silhouettes** | Low, wide, braced. Steep simple roof pitches, visible corner posts, an obvious lintel over every opening. Nothing taller than it is wide |
| **Signposts / markers** | A squared post with a **carved plank arm** and a visible peg or nail. Direction is shown by the arm's angle, never by a glow |
| **UI frames** | Plank-and-bracket: a flat panel with corner brackets and a visible seam, reading as **fitted timber**. Bevel is a construction line, not a shine |
| **Resource nodes** | A dense, grounded mass with a **flat base** — things that sit on the earth rather than emerge from it. Stacked, bundled, gathered |
| **Icon geometry** | Squared-off with one rounded working edge. Icons read as *tools and goods*: a bundle, a billet, a haft, a pot |
| **Equipment silhouettes** | **Function-forward.** A blade is a working blade; a pack has visible straps; a tunic has a belt that does something. Ornament is earned at high tier and stays small |

## A1.3 Character identity

- **Body proportions.** Sturdy and compact — the head carries identity, the body
  reads as a working adult. Head-to-body ratio remains **UNRESOLVED**; the
  intent is *stocky rather than heroic-tall*.
- **Head/body balance.** Head large enough to be a recognisable individual at
  phone size; shoulders wide enough that the pack does not make the figure
  top-heavy.
- **Silhouette.** Trapezoid with a visible arm-torso gap and planted boots. The
  **pack is the identifying mass** and is present at every tier.
- **Face detail.** Minimal. Eyes plus optional mouth. Expression is posture.
  This is a deliberate scalability choice and is not a budget compromise.
- **Traveler gear interpretation.** Practical layers: belted tunic, plain
  trousers, wrapped boots, canvas pack. It should look **issued and used** —
  the gear a settlement hands a newcomer because it works.
- **Backpack / weapon readability.** The pack breaks the shoulder line; the
  sword breaks the hip line. Two outline breaks, on opposite sides, at different
  heights — that is the whole read.
- **How later armour tiers stay readable.** Tier is carried by **silhouette
  mass first** (shoulder width, boot bulk, a hard shoulder shape at higher
  tiers), **hue family second**, **one added working detail third** — a strap, a
  buckle, a rivet line. Never glow, never particles.
- **Eight-direction identity.** The pack and the sword are the two sided
  elements; every diagonal must place them correctly rather than mirror them
  (`templates/EIGHT_DIRECTION_CHARACTER.md`). A1 is the easiest of the three to
  hold across eight views because its identity lives in **mass**, and mass
  survives rotation better than symbol placement does.

Frame counts, per-view resolution, and exact proportions: **UNRESOLVED**.

## A1.4 Haven's Rest identity

Same location, same content, different identity. Nothing in
`assets/content/v1/locations.json` changes.

| Element | Under A1 |
|---|---|
| **Gate** | A braced timber gate in a palisade — squared posts, a heavy lintel, an obvious cross-brace, and one repaired section using visibly newer timber. **The repair is the identity.** |
| **Roofs** | Steep, simple, thatch or shingle in muted clay; one roof carries a small stovepipe or chimney. Roof lines are the settlement's rhythm |
| **Timber / stone** | Timber dominates; stone appears as foundations, thresholds, and a hearth ring. Two materials, clearly distinguished by value, never by texture density |
| **Signpost language** | Carved plank arms on a squared post. **No text** — direction and destination read from arm angle and a small carved glyph |
| **Settlement props** | Firewood stack, a work trestle, a rope coil, a covered store — the exhaustive comparison-scene prop list still governs any sample; these are the *vocabulary*, not an instruction to add furniture |
| **Vegetation** | Sparse and useful. Low scrub at the palisade base, two flanking trees, a small tended patch near the wall. Foliage never crowds the path |
| **Path treatment** | A worn earth path with visible tread-compaction at the gate mouth. Widening toward the viewer. Quiet — the path's job is to lead the eye, not to be looked at |
| **NPC visual language** | Residents read as **occupied**: plain layered clothing, sleeves pushed back, one muted accent colour each. Never costumed |
| **Resource-node treatment** | Nodes near a settlement look *tended* — a herb patch has a trodden approach; a woodpile sits square. Nodes in the wild look untouched. Same asset family, different context |

## A1.5 UI identity

Structure is governed by `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md` and is **not
redesigned here**. Visual language only.

- **Top location/energy strip.** A fitted plank bar seated flush to the top
  edge. Location name at left; banked walking energy as a **numeral with a boot
  glyph** at right, presented as **a stock the player owns** — never a draining
  meter, never a countdown, never a refill prompt (`06_ANTI_FEATURES.md`). Sync
  freshness is one small dot.
- **Bottom navigation.** Six tabs on a matching plank bar, large targets,
  chunky pixel icons.
- **Active tab treatment.** The active tab plate is **raised and lit from the
  same baked light direction as the world** — a construction difference, not a
  glow.
- **Gather interaction card.** A small framed plate anchored above the node,
  bracketed at the corners. Icon, yield, cost, XP. Never a modal.
- **Icon family.** Tools and goods, squared with one rounded working edge.
- **Borders.** Two-step bevel reading as a timber edge.
- **Typography feel.** A sturdy bitmap display face for headings and numerals;
  a clean modern sans for body text. Full-bitmap body text remains a legibility
  and localisation liability on a phone. **PROVISIONAL.**
- **Information hierarchy.** Location → what you have → what you are doing →
  what it costs. Nothing else on the world screen.

**Not added:** health, mana, premium currency, chat, minimap, joystick.

## A1.6 Resource-node language

The node must be findable **before** the player looks for it.

- **Silhouette.** Grounded, flat-based, denser than its surroundings. Per-skill
  shape family: **bundled fan** (Foraging), **upright trunk mass**
  (Woodcutting), **angular faceted block** (Mining). Three shapes; every node in
  the game is one of them.
- **Saturation / value separation.** The node sits one step more saturated and
  one step higher in contrast than the terrain family it stands on. This is a
  **palette rule**, enforced per region, and it is the primary readability
  mechanism.
- **Outline treatment.** Selective one-pixel dark outline on nodes; terrain is
  unoutlined. Outlining only the interactable class means the outline *itself*
  becomes a signal.
- **Ground separation.** A soft contact shadow and a slightly darker base band.
  Terrain beneath a node is deliberately quiet — no overlay scatter within the
  node's footprint.
- **Icon tie-in.** The inventory icon is the node's silhouette, cropped. A
  player who has seen the icon recognises the node, and vice versa.
- **Subtle idle motion.** A slow two-state sway, **out of phase** with
  surrounding vegetation. Being out of phase is what makes it read as a separate
  object.
- **Notice / selection state.** Selection snaps a bright one-pixel outline and
  lifts the anchored card. Discrete, immediate, no easing.
- **Reward state.** The node visibly loses what was taken and later regrows it.
  **The state change is the reward feedback** — not a flash.

No glow, no bloom, no emissive VFX is used to solve readability in any of the
three treatments.

## A1.7 Living activity presentation

**Personality: workmanlike rhythm.** Everything is on a beat. The pleasure is
the pleasure of watching someone competent do a job they have done a thousand
times.

| Activity | Ambient loop personality | Occasional visible event | Stays static | Must not become |
|---|---|---|---|---|
| **Idle** | Settled weight-shift, an occasional glance toward the road | A small gear adjustment — shifting the pack strap | Terrain, buildings, props | Fidgety |
| **Mining** | Steady, heavy, slightly slower than you expect. Shoulder-led swing | A chip parts from the face; a small settled dust puff | Rock body, cave walls | Sparky, percussive-flashy |
| **Woodcutting** | Economical two-beat swing with a real recovery pause | Chip response, a brief tree recoil, a leaf or two | Trunk, canopy | A continuous chopping blur |
| **Foraging** | Bend, reach, close, rise. Unhurried | Plant releases and recoils past rest; a couple of seed motes | Ground, surrounding grass | Delicate or twee |
| **Cooking** | A two-state fire flicker, a thin drifting smoke thread, a slow stir | A lid lift, a small steam puff, a taste-and-nod | Hearth stones, pot, structure | A particle fireplace |
| **Fishing** *(presentation example only — **not a Project Stride skill**, `DECISIONS/0004`)* | Line slack shifting, bobber riding a two-state ripple | A dip, a small splash ring, a brief haul pose | Water body, bank | A minigame |

**Why it stays pleasant for long periods.** The loop has a **rest beat**. Every
A1 activity loop returns to a held pose before repeating, so the eye gets a
pause. Loops without a rest beat are the ones that grate at the fortieth
viewing.

**What must not become flashy.** The tool impact. The impact is the moment most
likely to attract VFX, and in A1 it is carried by *timing and a two-frame
material response* instead.

## A1.8 Audio / haptic identity hooks

Visual/audio alignment only. **No sounds are designed here.** The existing
framework is initiation → material response → reward confirmation
(`GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md`).

| Beat | What the visual does, so audio has something to land on |
|---|---|
| **Initiation** | The wind-up pose holds one beat longer than physics would require. That held frame **is** the audio cue's landing zone |
| **Material response** | Contact frame is a hard visual stop — the tool does not pass through, it *arrests*. Chip/dust appears on the frame after contact, not on it, so sound and visual do not fight for the same instant |
| **Reward confirmation** | The node's state change and the item's departure are separated by a beat. Two distinct visual events → two distinct audio events → optional haptic on the second only |

- **Woodcut:** wind-up hold → arrest → chip on the next frame → recoil →
  (on an authorized event) the log leaves.
- **Mining:** the swing arrests *into* the rock face rather than bouncing off
  it; dust settles downward, giving material weight a visible duration.
- **Gathering:** the pull is punctuated by the **release** — the plant springing
  back past rest is the reward beat, and it is where a haptic tick belongs.

Material identity ("copper should not sound like iron") is supported visually by
per-material **chip colour and settle speed**, which is a palette and timing
choice, not a rendering one.

## A1.9 Regional scalability

Regions change **vocabulary, never grammar**.

| Region | A1 expression, using the same kit |
|---|---|
| Forests | Timber kit, deep green palette set, denser trunk overlays, canopy occluders |
| Mountains | Same kit in cold grey-brown, stone foundations dominate, roofs steeper |
| Coast | Rope, net, and plank motifs; bleached timber palette; low horizon band |
| Swamps | Raised walkway variants of the plank kit; desaturated green-brown |
| Ruins | The same building kit **subtracted** — missing spans, collapsed roof pitches |
| Snow | Palette set plus a snow-capped overlay row on existing roof and rock silhouettes |
| Caves / mines | Timber bracing against stone — the most A1-native environment in the game |
| Settlements | Kit recombination. This is the direction's cheapest content |

**One pipeline:** a shared modular kit + per-region palette set + per-region
overlay scatter set + one or two region-exclusive silhouettes. No new pipeline
per region.

## A1.10 Combat compatibility

Turn-based, 6–12 turns, retreat-not-death (`GAME_BIBLE/COMBAT/01_COMBAT_PHILOSOPHY.md`).

- **Player attacks.** A short lunge-and-return per facing, plus a shared weapon
  arc overlay. The arc reads tier by **thickness and hue**, not by light.
- **Enemies.** Strong mass silhouettes. A1's squared shape language means
  enemies can be differentiated by being **organically irregular** against a
  built world — a useful contrast the direction gets for free.
- **Telegraphs.** Stated, not animated: a flat ground marker plus an intent
  glyph held until the player acts. Turn-based combat makes this a strength.
- **Boss silhouettes.** Bosses read by occupying more frame and owning one
  silhouette element no ordinary enemy has.
- **Equipment tiers.** Same three signals as the world: mass, hue family, one
  added working detail.
- **Damage readability.** Two-frame flash, positional shove, rising numeral.
- **Status effects.** Icon strip plus a palette tint on the sprite. No looping
  particles.

**Risk:** A1's calm competence is the least *dangerous*-feeling of the three,
and the Hollow Guardian has to carry menace with mass and timing alone.

## A1.11 AI-assisted production fit

| Axis | Risk | Note |
|---|---|---|
| Identity consistency | **LOW** | Identity lives in a kit and a palette, both machine-checkable |
| Sprite-generation repeatability | **LOW** | Squared geometry survives quantisation cleanly |
| Eight-direction compatibility | **LOW–MEDIUM** | Two sided elements (pack, sword); mass-based identity rotates well |
| Equipment layering | **LOW** | Function-forward shapes layer without interpenetration problems |
| Animation consistency | **LOW** | Held rest beats are easy to specify and easy to verify |
| Environment scalability | **LOW** | Kit recombination is the dominant cost model |
| Icon-generation consistency | **LOW–MEDIUM** | "Tools and goods" is a broad brief; needs a written icon grammar early |

**The main lever:** a locked master palette plus a written kit specification.
Both are enforceable by script, which is why A1 rates well.

## A1.12 Distinctiveness test

**What makes an A1 screenshot recognisably Project Stride with the logo removed:**

1. **Visible repair and reuse.** Newer timber patched into older timber; a
   mended palisade section; a re-hafted tool. A frontier that has been
   *maintained* is a specific, unusual thing to draw and almost nobody draws it.
2. **The plank-and-bracket UI seam.** The HUD is fitted timber with corner
   brackets and a visible joint line — a chrome language nobody else is using
   for a mobile RPG.
3. **The pack as permanent silhouette.** The player character is identifiable in
   black at 50% size by the squared pack breaking the shoulder line, at every
   gear tier, forever.
4. **Held rest beats in every work loop.** The game *breathes* between swings.
   That timing signature is recognisable in motion within two seconds.

## A1.13 Failure mode

**Most likely failure: cozy-farm drift.**

Warmth plus settlement plus craft plus gathering is one palette-step away from
cottagecore. The moment the timber goes pastel, the roofs go round, the props go
decorative, or an NPC gets an apron and a smile, A1 stops being a frontier and
becomes a farming game — which would quietly contradict
`GAME_BIBLE/COMBAT/01_COMBAT_PHILOSOPHY.md`'s expectation that this world is
also dangerous.

**Secondary failures:** prop clutter (a lived-in settlement invites furniture,
and furniture kills the quiet-terrain rule); and **brown fatigue** — a
timber-and-leather identity that never leaves the warm half of the wheel.

**The guard:** every A1 prop must answer *whose job is this?* If nobody uses it,
it does not go in.

## A1.14 Signature Haven's Rest moment

**The stack.**

Five to eight seconds. The character stands at the woodpile beside the palisade,
mid-activity. Two-beat swing: wind-up, hold, arrest, chip, recoil, rest. The
smoke thread from the roof behind drifts on its own slower loop, out of phase
with the swing, so the scene has two rhythms instead of one. The NPC at the gate
shifts weight once. Nothing else moves. The path is empty and quiet.

On the fourth swing — **because the underlying state authorized it, not because
four swings elapsed** — a split log parts from the round, the tree-round loses a
visible piece, and the log arcs to the pack. Then the loop resumes at the rest
beat.

No camera move. No dimming. No zoom. Watching a sixth swing gives you exactly
what watching a fourth gave you: the pleasure of a good rhythm, and nothing else.

---

# A2 — RUNE-WORN ADVENTURE

## A2.0 RA-1 — the owner's A2 constraint

> **Owner ruling, made at review of this document. Binding on A2 throughout,
> including in the visual sample round. Not an ADR.**

**A2 may not establish new ancient or mystical world canon in order to work.**

The direction's marks and symbols may be read **only** as:

- route marks
- wayfinding marks
- settlement marks
- craft marks
- skill and resource symbols
- **old but unexplained practical iconography**

They must remain:

- **inert**
- **non-glowing**
- **non-magical in presentation**
- **unexplained by new lore**
- **compatible with the existing world without requiring a new historical layer**

**Explicitly forbidden:** creating ancient civilizations, magical rune systems,
forgotten empires, religions, prior ages, or any other world history for the
purpose of making A2 work. `GAME_BIBLE/WORLD/` is not modified by this document
and must not be modified to support this direction.

**And the consequence, stated plainly.** If A2 cannot feel distinctive without
that lore, **that is a weakness of the direction, to be revealed by the
comparison — not a problem to be solved inside an art task.** A2 is not to be
propped up. It goes into the comparison on the strength it actually has.

**What RA-1 changes about A2 as written below.** The marks are **functional and
unexplained**, not historical. Wear and age are permitted as *material
observations* — this stone is more weathered than that timber, this mark has
been re-cut — because wear is visible fact, not lore. What is not permitted is
any statement, implication, or asset design that answers *who made them, when,
or why*. The honest register is the one everybody has actually met: **old
practical markings whose origin nobody in the settlement thinks about.**

**Name note — flagged, not actioned.** Under RA-1 the working name "Rune-Worn
Adventure" is now slightly misleading: *rune* carries a magical reading the
direction is forbidden to have, and it is exactly the word most likely to make
an image generator produce glowing fantasy. **A2 is not renamed here**, per the
naming rule in the brief. If the owner wants a replacement, *Marked Ways* or
*Waymarked* would describe the direction more accurately. **Regardless of the
document name, the generation prompt must say route, craft, and resource
markings — never "runes."**

## A2.1 Design thesis

**Project Stride is a marked world, and the marks still work.**

A2 finds identity in **a practical symbol language that has been in use longer
than anything built around it**. Route marks at the crossroads, craft marks on
the store, resource marks at known gathering sites, skill symbols in the
interface — one drawn vocabulary carrying real information, cut into stone and
timber, weathered by use.

Nobody explains them. They are simply how this world writes things down, and
they are older than the buildings. **That is deliberately as far as it goes**
(RA-1).

The player is a traveller carrying inherited, repaired, well-travelled gear
through a landscape that is legible because it has been marked.

**Emotional tone:** quiet continuity and usefulness. The feeling of a trail
marker whose maker you will never know and whose meaning is completely clear.

**Why it is still unmistakably Direction A:** the whole identity is expressed in
**carved geometry**, which is exactly what pixel art is best at — hard shapes,
flat values, decisive marks. There is no emissive layer, no particle system, and
no spell VFX anywhere. A mark reads as *cut into stone* because it is drawn a
value darker with a one-pixel lit lip, **not because it lights up**.

**Canon fit — bounded by RA-1.** A2 requires no new world history and proposes
none. It uses `GAME_BIBLE/WORLD/` and
`GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md` exactly as they stand. See
§Canon notes, CN-1.

## A2.2 Signature shape language

**Governing geometry:** *the carved mark on the weathered mass.* Forms are
simple, heavy, and slightly asymmetric from wear; the interest is the **incised
symbol**, never the surface detail.

| Element | Shape language |
|---|---|
| **Character silhouette** | Slightly narrower and more upright than A1. A travelling figure: cloak-less but wrapped, gear strapped close. The silhouette says *has walked a long way and intends to keep going* |
| **Building silhouettes** | Timber over **older stone footings** that do not match the building above them. A material observation — the stone weathered differently and has been reused — and deliberately not an explanation (RA-1) |
| **Signposts / markers** | **Waystones.** A standing stone or a squat carved marker with an incised route glyph, sometimes accompanied by a plain timber arm. This is the direction's signature object, and it is **wayfinding equipment**, not a monument |
| **UI frames** | Incised panel: a flat plate with a **carved border groove** and small corner marks. Reads as cut, not built |
| **Resource nodes** | Grounded masses **with a marked companion** — a small cut stone or notched post nearby indicating a known, named place |
| **Icon geometry** | **Sigil-led.** Icons are compact glyph-like marks: a stem-and-cross for herbs, a wedge-and-line for ore, a notched ring for wood. Strongly legible at tiny sizes |
| **Equipment silhouettes** | **Inherited and repaired.** Wrapped grips, a replaced pommel, a rivet line where a plate was re-set, a small maker's mark. Ornament is *old*, not fine |

## A2.3 Character identity

- **Body proportions.** Slightly taller and narrower than A1's build, still
  compact and grounded. Exact ratio **UNRESOLVED**.
- **Head/body balance.** Head sized for identity; the silhouette's centre of
  interest is the **torso strapping**, where inherited gear is carried.
- **Silhouette.** Upright, close-strapped, minimal outward bulk. Where A1 says
  *carries things*, A2 says *travels light and has done this before*.
- **Face detail.** Minimal, as A. Expression is posture and head tilt.
- **Traveler gear interpretation.** The same items, read as **handed down**: a
  tunic with a repaired shoulder seam, a belt with two sets of wear marks from
  previous owners, a sword with a rewrapped grip. Tier 0 looks *old*, not new —
  a genuinely distinctive reading of starter gear.
- **Backpack / weapon readability.** Pack sits lower and tighter than A1's;
  sword breaks the hip line. Both remain outline-breaking.
- **How later armour tiers stay readable.** Tier reads by **mass + hue family +
  one added carved or fitted element** — a marked pauldron edge, an incised
  band. Higher tiers may carry a **small, static, non-emissive sigil**. That
  sigil never glows, never animates, and never exceeds a few pixels. **This is
  the direction's ceiling and must be defended.**
- **Eight-direction identity.** Higher risk than A1: **a sigil placed on one
  side is a sided element**, and sigils are exactly what a generator will
  mirror. Mitigation — keep tier sigils **centred or duplicated symmetrically**
  wherever possible, and treat any asymmetric mark as requiring the same
  no-mirroring discipline as the sword.

## A2.4 Haven's Rest identity

| Element | Under A2 |
|---|---|
| **Gate** | Timber gate hung between **two old carved stone posts**, more weathered than the palisade around them, each carrying a route mark. They are gateposts doing a gatepost's job — **no significance is asserted, and none may be** (RA-1) |
| **Roofs** | Simple and low; shingle over the stone-footed structures, thatch over the rest. The mismatch reads as ordinary practical building, not as a timeline |
| **Timber / stone** | **Stone is more weathered than timber, always.** Foundations, thresholds, and markers are stone; walls and roofs are timber. A material rule, not a historical one |
| **Signpost language** | A **waystone** beside the path with two incised route glyphs, plus a plain timber arm. No text. The glyph vocabulary is the game's route language and recurs at every crossroads in the world |
| **Settlement props** | A small marked boundary stone, a repaired well head, a stack of cut timber. Marks on props are **craft and content marks** — what this is, whose it is, what goes in it. Restrained; the comparison-scene prop list still governs any sample |
| **Vegetation** | Sparse, with moss and lichen reading as **weathering** on stone only — a palette accent, not a texture pass |
| **Path treatment** | The path runs by the markers, because the markers were put where the path runs. Worn earth over an occasional exposed flag stone |
| **NPC visual language** | Plain settlement clothing with **one small worn token** — a marked belt plate, a stamped buckle. It reads as ordinary property that happens to carry a mark, not as an emblem of anything |
| **Resource-node treatment** | Nodes at known sites carry a **small cut marker stone**; unmarked nodes read as newly found. This is a strong, cheap world-state signal |

## A2.5 UI identity

- **Top location/energy strip.** An incised flat plate. Location name left;
  banked energy as a numeral with a boot glyph right, **a stock owned**, never a
  draining meter. Sync freshness one small dot.
- **Bottom navigation.** Six tabs; icons are **glyph-led marks** in the same
  cut-symbol family as the world's route marks.
- **Active tab treatment.** The active tab's glyph is **filled solid** where
  inactive glyphs are cut/outlined. A carved-versus-inlaid distinction, not a
  light state.
- **Gather interaction card.** A small incised plate with a grooved border,
  anchored above the node.
- **Icon family.** **The strongest icon language of the three.** Compact sigils,
  high legibility at small size, a consistent stroke logic across skills,
  materials, routes, and statuses.
- **Borders.** A single carved groove with a one-pixel lit lip on the light side.
- **Typography feel.** A bitmap display face with slightly angular, incised
  character for headings and numerals; clean modern sans for body text.
  **PROVISIONAL.**
- **Information hierarchy.** Unchanged. Restrained. No health, mana, currency,
  chat, minimap, or joystick.

## A2.6 Resource-node language

- **Silhouette.** The same three per-skill families as A1 — fan, trunk mass,
  faceted block — with a slightly more **symbolic, simplified** construction.
- **Saturation / value separation.** Same palette rule: nodes sit one step up in
  saturation and contrast from their terrain family.
- **Outline treatment.** Selective dark outline on interactables only.
- **Ground separation.** Contact shadow plus a quiet base band. **A2's extra
  lever:** the optional companion marker stone gives the node a second, harder
  silhouette at its base, which materially improves findability in cluttered
  regions without adding any rendering.
- **Icon tie-in.** **The tightest of the three.** The node's sigil *is* the
  inventory icon, the skill icon, and the map mark. One drawn symbol, four uses.
- **Subtle idle motion.** Two-state sway, out of phase with surrounding
  vegetation. The marker stone is static — and its stillness beside the moving
  node is itself a separation cue.
- **Notice / selection state.** Selection snaps a bright outline; the marker's
  incised glyph **inverts** (cut becomes filled) for the duration. A discrete,
  non-emissive selection language unique to this treatment.
- **Reward state.** Visible state loss and later regrowth, as A.

## A2.7 Living activity presentation

**Personality: ritual intent.** Motion is slightly more deliberate than A1's.
Each action begins with a small settling — a set of the feet, a shift of grip —
as though the character is *taking the job seriously*. Not solemn. Considered.

| Activity | Ambient loop personality | Occasional visible event | Stays static | Must not become |
|---|---|---|---|---|
| **Idle** | Upright, still, weight even; an occasional look toward the waystone or the road | A hand rests briefly on a strap or a marker | Terrain, stone, structures | Posed or heroic |
| **Mining** | Measured swings with a clear set-and-strike preparation | Chip parts; a **single** ore facet catches the baked light for two frames | Rock body | A spark shower |
| **Woodcutting** | Deliberate two-beat swing, slightly longer recovery than A1 | Chip response, brief recoil | Trunk, canopy | Ceremonial |
| **Foraging** | A small kneel, a considered reach, an unhurried rise | Plant releases, recoils, settles; two seed motes | Ground, marker stone | Precious |
| **Cooking** | Two-state fire flicker, thin smoke, slow tending | Steam puff, a lid set aside and replaced | Hearth ring, structure | A ritual fire |
| **Fishing** *(presentation example only — not a Stride skill)* | Line and bobber on a slow ripple; the character stands rather than sits | A dip, a ring, a short haul | Water, bank, marker | Mystical |

**Why it stays pleasant for long periods.** The **preparation beat**. A2's loops
front-load a small setup motion, which gives the loop an obvious start and makes
repetition read as *rhythm* rather than as a cycle catching its tail.

**What must not become flashy.** Anything carved. The instant a mark pulses, A2
becomes high fantasy and the direction is lost. **Marks are inert. Always**
(RA-1).

## A2.8 Audio / haptic identity hooks

| Beat | What the visual does |
|---|---|
| **Initiation** | The set-and-grip preparation frame is the initiation cue's landing zone — earlier and more distinct than A1's, giving audio a longer runway |
| **Material response** | Contact arrests hard; for mining, **one** facet takes a two-frame value lift on the frame after impact — a material *identity* signal for a per-material sound, achieved with a value change and no lighting system |
| **Reward confirmation** | The item's departure and the node's state change are separated by a beat; if the node carries a marker, the marker's glyph inverting is a third, optional, very quiet beat suitable for a haptic tick |

Material identity is supported visually by **which value step the chip and the
facet lift use** — copper and iron differ by ramp position, not by render.

## A2.9 Regional scalability

The **marker system is the regional connective tissue** — the same waystone kit
appears in every region, recoloured and re-carved, which gives twenty regions a
shared identity for nearly no cost.

| Region | A2 expression |
|---|---|
| Forests | Moss-worn markers, timber over old footings, green palette set |
| Mountains | Standing stones on ridgelines; the marker kit at its most natural |
| Coast | Weathered posts and tide-cut stone; bleached palette |
| Swamps | Half-sunk markers — the same asset, partially occluded. Extremely cheap identity |
| Ruins | **The direction's home ground.** Ruins are the marker language at full scale |
| Snow | Markers capped and partially buried; palette set plus overlay row |
| Caves / mines | Cut galleries with old tool marks; carved depth markers along the route |
| Settlements | Timber kit on mismatched older stone footings |

**One pipeline:** shared kit + palette sets + a **glyph library** + overlay
scatter. The glyph library is new relative to A1 and A3, and it is the thing
that must be authored well once.

## A2.10 Combat compatibility

- **Player attacks.** Short lunge-and-return plus a shared arc overlay. Tier
  reads by arc thickness and hue.
- **Enemies.** A2 gets a cheap and strong enemy hook: **marked** enemies — a
  carved band, an old fitting — reading as *belonging to the same marked world
  the player has been walking through*. **This is a visual-family device, not a
  lore device** (RA-1): it says the mark language is everywhere, and it does not
  say who marked them or why.
- **Telegraphs.** Stated: a **carved-looking flat ground mark** under the
  threatened area plus an intent glyph. The telegraph borrows the world's own
  symbol language, which is the most legible option of the three because the
  player has already learned that vocabulary from route marks.
- **Boss silhouettes.** Mass plus one owned silhouette element. The Hollow
  Guardian can carry a large static sigil as its identifying feature.
- **Equipment tiers.** Mass + hue + one added carved element.
- **Damage readability.** Two-frame flash, shove, rising numeral.
- **Status effects.** Icon strip plus palette tint. **Highest temptation to add
  magical VFX here — the answer is no.**

## A2.11 AI-assisted production fit

| Axis | Risk | Note |
|---|---|---|
| Identity consistency | **MEDIUM** | Glyph vocabulary must be authored and locked, or generators will invent runes endlessly |
| Sprite-generation repeatability | **LOW–MEDIUM** | Carved marks quantise well; invented marks are the problem |
| Eight-direction compatibility | **MEDIUM** | Asymmetric sigils are exactly what generators mirror. Prefer centred or symmetric marks |
| Equipment layering | **LOW–MEDIUM** | Inherited/repaired detail is small and layerable |
| Animation consistency | **LOW** | Preparation beats are easy to specify |
| Environment scalability | **LOW** | The marker kit is the cheapest regional identity of the three |
| Icon-generation consistency | **LOW** | **Best of the three** — a locked glyph library is directly verifiable |

**The named risk:** *mark inflation.* Ask a generator for "worn runes" and every
asset comes back covered in them — and half of them will look magical. The
control is a **finite, closed glyph library**, an explicit rule about how many
marks an object may carry, and prompt language that says **route, craft, and
resource markings** rather than *runes* (RA-1).

## A2.12 Distinctiveness test

1. **The waystone at the crossroads.** A squat carved marker with an incised
   route glyph, standing where the path forks — present in every region, in the
   same visual family, and functioning as the game's actual wayfinding language.
   That is a specific, ownable object.
2. **One symbol vocabulary across node, icon, skill, route, and telegraph.**
   The same drawn mark means the same thing in the world, in the inventory, on
   the skill row, and under an enemy's feet. Very few games commit to this, and
   it is instantly legible as a designed system. **This is A2's real
   differentiator, and it needs no lore whatsoever** — a working vocabulary is
   distinctive because it is *consistent*, not because it is *ancient*.
3. **Mismatched stone footings under timber buildings.** Ordinary practical
   construction, drawn honestly — the stone is more weathered than what stands
   on it.
4. **Starter gear that looks inherited.** Tier 0 reads as repaired and
   handed-down rather than as new-and-cheap — an unusual and memorable reading.

**The test RA-1 imposes on this list.** Items 1, 2, and 4 stand entirely without
world history; item 3 is a material observation. If the comparison shows A2 is
distinctive **only** when a viewer imagines a backstory that does not exist,
that is the weakness the comparison exists to reveal.

## A2.13 Failure mode

**Most likely failure: rune-fantasy creep.**

The pressure to make the marks *do something* is constant, and it comes from
inside — the first time a rune glows, A2 becomes generic glowing-rune fantasy,
which is one of the most crowded looks in the medium. **Neon fantasy, wizard
ornamentation, spell-effect overload, and "every object is a magical artifact"
are all one permissive decision away.**

**Secondary failures:** *glyph clutter* (readability dies when everything is
marked); and — **the failure RA-1 specifically refuses to let this document fix**
— *lore dependence*. A symbol language invites a history, and A2 is not allowed
to author one. If the marks only feel meaningful once someone invents an ancient
civilization behind them, then A2's distinctiveness was never in the art, and
**the comparison should surface that rather than hide it.**

**The guard:** a closed glyph library; an explicit **"marks are inert, always"**
rule; and a written statement of each mark's **functional** meaning — this route,
this craft, this resource, this skill — before the second one is drawn.
Functional meaning is permitted and necessary. Historical meaning is forbidden
(RA-1).

## A2.14 Signature Haven's Rest moment

**The marked patch.**

Five to eight seconds. The character kneels at a herb patch beside the path. Set
the feet, reach, close, draw, rise. Beside the patch stands a squat cut stone,
knee-high, with a single incised glyph — the mark that says *this is a known
place*. The stone does not move. The character's loop does.

The smoke thread from a roof behind drifts on its own slower loop. The NPC at
the gate is still.

Once — **because the underlying state authorized it** — the plant releases,
recoils past rest, two seed motes lift and fall, and a herb arcs away to the
pack. The stone's glyph inverts for a beat and returns — a **selection state
drawn in the world's own symbol language**, not a response from the stone.

Nothing lit up. Nothing was revealed. A mark that has always been there simply
told you, again, what this place is for.

---

# A3 — WILD TRAILS

## A3.1 Design thesis

**Project Stride is the land, and you are someone who knows how to read it.**

A3 finds identity in **terrain and route**. The world is legible as *country*:
where the ground changes, where the path goes, what grows where, and what that
tells a traveller. The player is a capable walker with practical kit and
regional knowledge.

This treatment maps most directly onto the game's actual input — **real-world
walking** — and onto `GAME_BIBLE/WORLD/02_EXPLORATION_AND_TRAVEL.md`'s
requirement that travel create anticipation rather than read as a loading bar.

**Emotional tone:** open, fresh, quietly competent. The feeling of cresting a
rise and seeing what the next region looks like.

**Why it is still unmistakably Direction A:** regional character is carried by
**palette sets and a small silhouette vocabulary**, not by foliage density or
atmosphere. A3's forests are *distinct*, not *lush*. The single greatest
discipline here is that terrain stays quiet beneath gameplay objects even when
the terrain is the identity.

**Canon fit:** aligns closely with `WORLD/01_WORLD_STRUCTURE.md` ("every region
needs a visual identity, a resource identity...") and `WORLD/02`. **Caution:**
trail-and-route motifs sit nearest to implying free-roam traversal, and R-4
forbids that reading. See §Canon notes.

## A3.2 Signature shape language

**Governing geometry:** *the flowing band across the mass.* Terrain reads as
bands and transitions; objects sit on those bands and are shaped to contrast
with them.

| Element | Shape language |
|---|---|
| **Character silhouette** | Lean, mobile, forward-leaning at rest. Kit strapped high and tight for walking. The silhouette says *covers ground* |
| **Building silhouettes** | Lower and more spread than A1's; buildings **sit into** the terrain rather than on it, with visible grade at the foundations |
| **Signposts / markers** | **Trail markers** — a low cairn, a blazed post, a notched arrow board. Route language reads as *field craft*, not as carving or carpentry |
| **UI frames** | A flat panel with a **thin double-rule border** and a small notch at one corner, reading as a field card or a route slip. The lightest chrome of the three |
| **Resource nodes** | Distinct **growth forms** — the node's shape tells you what region you are in as well as what skill it serves |
| **Icon geometry** | **Terrain and track led:** a leaf, a track, a contour, a notch, a tool head. Slightly more organic than A1's and A2's |
| **Equipment silhouettes** | **Exploration kit.** Wrapped, layered for weather, strapped for movement. Nothing hangs loose |

## A3.3 Character identity

- **Body proportions.** Lean and compact; less shoulder bulk than A1, less
  upright stiffness than A2. Exact ratio **UNRESOLVED**.
- **Head/body balance.** Head sized for identity; the strongest silhouette
  interest sits at the **shoulder-to-pack junction**.
- **Silhouette.** A slight forward lean even at rest, which reads as
  *ready to move* at any size and is the direction's cheapest identity signal.
- **Face detail.** Minimal, as A.
- **Traveler gear interpretation.** Practical travel layers with a **regional
  accent** — a wrap, a tie, a cord whose colour changes with where the player
  has been. **Note:** whether gear varies by region is a design question and is
  **UNRESOLVED**; A3 merely shows that its visual language would support it.
- **Backpack / weapon readability.** Pack high and tight; sword at the hip.
  Both outline-breaking, as A.
- **How later armour tiers stay readable.** Mass + hue family + one added
  practical element (a strap, a guard, a reinforced panel). A3's tiers read as
  **better-equipped for harder country** rather than as more powerful.
- **Eight-direction identity.** Comparable to A1. The forward lean must be
  authored per-facing rather than skewed, and the pack and sword remain the
  sided elements. Medium risk: a lean is easy for a generator to lose or to
  overstate.

## A3.4 Haven's Rest identity

| Element | Under A3 |
|---|---|
| **Gate** | A timber gate where the trail **enters** the palisade — the approach is graded and worn wider than the gate, showing traffic. The gate is a *trailhead*, and that is the identity |
| **Roofs** | Low and wide, pitched for the region's weather, sitting into the slope |
| **Timber / stone** | Timber walls; stone used where the ground demanded it — footings on the downhill side, a revetment where the path cuts through |
| **Signpost language** | A **blazed post with notched arms** and a small cairn at its foot. No text. Route information reads as trail marking |
| **Settlement props** | A boot scraper at the gate, a firewood stack, a covered store. Restrained; the comparison-scene prop list still governs any sample |
| **Vegetation** | **Regionally specific and deliberately sparse.** Two or three plant silhouettes that belong to *this* region, placed to frame rather than to fill. The palisade scrub is the region's scrub |
| **Path treatment** | **The strongest path language of the three.** Visible tread compaction, a braid where walkers avoided a wet patch, a subtle change in ground band where the path leaves the settlement. The path is a designed object |
| **NPC visual language** | Residents dressed for the region — the same plain clothing family, with regionally appropriate layers |
| **Resource-node treatment** | Nodes are **regionally characterised**: a meadow herb tuft reads differently from a woodland herb, while remaining the same per-skill silhouette family |

## A3.5 UI identity

- **Top location/energy strip.** A light flat panel with a thin double rule.
  Location name left; banked energy as a numeral with a boot glyph right,
  **a stock owned**, never draining. Sync dot far right.
- **Bottom navigation.** Six tabs; icons drawn from terrain, track, leaf, and
  tool vocabulary.
- **Active tab treatment.** The active tab sits on a **filled band** — the same
  band language the terrain uses. A structural cue borrowed from the world.
- **Gather interaction card.** A light card with a notched corner, anchored
  above the node.
- **Icon family.** Organic-leaning but geometrically disciplined; consistent
  stroke logic.
- **Borders.** Thin double rule, one notch. The least heavy chrome of the three,
  which suits a direction whose world carries more terrain information.
- **Typography feel.** A clean bitmap display face for headings and numerals,
  modern sans for body. **PROVISIONAL.**
- **Information hierarchy.** Unchanged and restrained. No health, mana,
  currency, chat, minimap, or joystick.

## A3.6 Resource-node language

**This is the treatment where node readability is hardest and matters most**,
because A3's terrain carries the most information.

- **Silhouette.** The same three per-skill families — fan, trunk mass, faceted
  block — with a **regional variant** of each. The family is constant; the
  dressing is regional.
- **Saturation / value separation.** The palette rule is **stricter here than in
  A1 or A2, by necessity**: every regional palette set must reserve a
  higher-saturation, higher-contrast band exclusively for interactables. If a
  region's foliage uses the node band, the region is mis-authored.
- **Outline treatment.** Selective dark outline on interactables only —
  and in A3 this carries more weight, because ambient vegetation is more
  varied.
- **Ground separation.** Contact shadow, a darker base band, and a **cleared
  footprint**: terrain overlay scatter is suppressed within and immediately
  around a node's footprint. This is the mechanism that keeps quiet terrain
  beneath gameplay-important objects while still letting regions be distinctive.
- **Icon tie-in.** Node silhouette cropped to icon, as A1, with the regional
  variant collapsing back to the family shape at icon size.
- **Subtle idle motion.** Two-state sway out of phase with ambient vegetation.
  In A3 the ambient vegetation also moves, so the **phase difference is doing
  real work** and must be authored deliberately.
- **Notice / selection state.** Bright one-pixel outline snap; the anchored card
  lifts.
- **Reward state.** Visible loss and later regrowth.

**Named risk, stated plainly:** A3 is the only treatment where the identity
actively competes with node readability. The palette-band reservation and the
cleared footprint are not polish — they are the load-bearing rules.

## A3.7 Living activity presentation

**Personality: ambient environmental motion.** A3's signature is that the
*place* is alive, not just the character. Motion is soft, slow, and layered
across a few cheap ambient elements — and the character's work loop sits inside
it rather than dominating it.

| Activity | Ambient loop personality | Occasional visible event | Stays static | Must not become |
|---|---|---|---|---|
| **Idle** | Weight shift, a scan across the terrain, grass moving around the feet | A look up at the sky or along the trail | Terrain bodies, structures, rock | Restless |
| **Mining** | Rhythmic swing against a still rock face; the surrounding scrub keeps moving | Chip parts, a low dust settle | Rock, cave walls | Dust-heavy |
| **Woodcutting** | Two-beat swing; the **canopy above has its own slow drift**, unrelated to the swing | Chip response, tree recoil, a leaf detaches and falls | Trunk, ground | A leaf storm |
| **Foraging** | Kneel, part the grass, reach, pick, rise. The surrounding meadow moves throughout | Plant releases and recoils; two seed motes | Ground, path | A flower-picking idyll |
| **Cooking** | Fire flicker, thin smoke bending with the same slow drift as the foliage | Steam puff, a stir, a taste | Hearth, structure | A campfire cutscene |
| **Fishing** *(presentation example only — not a Stride skill)* | Water surface two-state ripple, bobber riding it, reeds moving on the same drift | A dip, a ring, a short haul | Bank, water body | An atmospheric set piece |

**The unifying trick — and A3's real signature:** a **single shared drift phase**
drives grass, canopy, smoke, and water at slightly different rates. One cheap
authored motion parameter makes an entire location feel like it has weather
without any weather system, any particles, or any lighting.

**Why it stays pleasant for long periods.** Because the ambient layer never
resolves. The character's loop repeats; the environment simply *continues*. The
eye rests on the environment and returns to the loop, which is materially more
watchable than a loop alone.

**What must not become flashy.** The ambient layer's amplitude. A3's failure
mode is motion everywhere; the drift must stay under the threshold where the eye
tracks it.

## A3.8 Audio / haptic identity hooks

| Beat | What the visual does |
|---|---|
| **Initiation** | The character's approach and set is visible against a moving environment, giving the initiation cue a clean foreground event over a continuous ambient bed — the visual structure the audio identity's *ambient bed + action* model already assumes |
| **Material response** | Contact arrests; the **surrounding ambient motion is unaffected**, which isolates the impact and makes the material response the only new thing in frame at that instant |
| **Reward confirmation** | Node state change, then item departure, one beat apart. The ambient layer continues throughout — the reward never stops the world |

Regional audio identity ("a mine should not sound like a forest") is supported
visually by the fact that **each region already has a distinct ambient motion
signature** — canopy drift versus still cave air versus water ripple. Audio and
visuals can be regionalised from the same authored parameter.

## A3.9 Regional scalability

**A3's home strength.** Regions are the identity, and the pipeline is built for
them.

| Region | A3 expression |
|---|---|
| Forests | Dense canopy *occluders* (not dense foliage), green palette set, high ambient drift |
| Mountains | Exposed rock bands, low scrub, sparse markers, minimal drift |
| Coast | Sand and shingle bands, wind-set vegetation, high drift, wide horizon band |
| Swamps | Water-and-reed bands, standing water two-state ripple, slow drift |
| Ruins | Terrain reclaiming structure — the building kit under vegetation overlays |
| Snow | Palette set plus snow overlay row; drift near zero, which itself reads as cold |
| Caves / mines | **No drift at all.** The absence of ambient motion is the region's signature, and it costs nothing |
| Settlements | Buildings sitting into graded terrain, trail entering at the gate |

**One pipeline:** shared kit + per-region palette set (with a reserved
interactable band) + per-region vegetation silhouette set (two or three) +
per-region ambient drift parameter + trail marker kit. No new pipeline per
region, and **the drift parameter gives regional life for free**.

## A3.10 Combat compatibility

- **Player attacks.** Lunge-and-return plus shared arc overlay, as A.
- **Enemies.** Enemies read as **belonging to their region** — the strongest
  ecological coherence of the three. The Forest Wolf is a woodland silhouette;
  the Cave Goblin is a cave silhouette.
- **Telegraphs.** Stated: flat ground marker plus intent glyph. **A3 must
  suppress the ambient drift under an active telegraph's footprint**, or the
  moving terrain will compete with the danger signal. Named here so it is
  designed rather than discovered.
- **Boss silhouettes.** Mass plus one owned element. The Hollow Guardian can own
  *stillness* in a region that moves — a genuinely striking and free effect.
- **Equipment tiers.** Mass + hue + one added practical element.
- **Damage readability.** Two-frame flash, shove, rising numeral.
- **Status effects.** Icon strip plus palette tint.

**Risk:** an environment that moves during combat costs readability, and combat
is the one moment where readability is non-negotiable. The suppression rule
above is mandatory rather than optional.

## A3.11 AI-assisted production fit

| Axis | Risk | Note |
|---|---|---|
| Identity consistency | **MEDIUM** | Regional variety is exactly where generators drift; needs a per-region palette lock and a fixed silhouette set |
| Sprite-generation repeatability | **MEDIUM** | Organic forms quantise less cleanly than A1's squared geometry |
| Eight-direction compatibility | **MEDIUM** | The forward lean must be authored per view, not skewed |
| Equipment layering | **LOW–MEDIUM** | Strapped, close-fitting kit layers well |
| Animation consistency | **MEDIUM** | The shared drift phase must be a **parameter**, not per-asset authored motion, or ambient consistency collapses |
| Environment scalability | **LOW** | **Best of the three** — regions are the pipeline's native unit |
| Icon-generation consistency | **MEDIUM** | Organic icon geometry is the least machine-verifiable of the three |

**The main lever:** treat ambient drift as **one shared authored parameter**
applied at runtime to a small set of two-state assets. If drift becomes
per-asset hand animation, A3's animation workload silently doubles.

## A3.12 Distinctiveness test

1. **Trails that read as trails.** Tread compaction, a braid around a wet patch,
   a widened approach at the gate. Almost no mobile RPG draws a path as a thing
   that was made by walking — in a game whose input *is* walking, that is the
   most on-thesis visual idea in this document.
2. **One shared drift phase across grass, canopy, smoke, and water.** The whole
   location breathes together at slightly different rates. Recognisable in
   motion in under two seconds, and unlike anything achieved by lighting.
3. **Regions that are legible as country.** Ground bands, transition edges, and
   two or three region-native plant silhouettes — a place you could name from a
   thumbnail.
4. **A resource node that tells you both the skill and the region** while
   remaining one of three learned silhouette families.

## A3.13 Failure mode

**Most likely failure: green-and-brown generic wilderness.**

Nature-led identity without palette discipline converges on the most common
look in the genre. Every screen becomes a field with trees; the regions blur;
the nodes drown in the vegetation that was supposed to make the world
distinctive. This is the exact failure that the **reserved interactable palette
band** and the **cleared node footprint** exist to prevent, and both are easy to
let slide.

**Secondary failures:** *motion fatigue* — ambient drift is delightful for a
minute and exhausting for an hour if its amplitude is even slightly too high;
and **survival-game drift** — practical exploration kit plus wilderness plus
resource nodes converges on a well-worn survival aesthetic the project is not
making.

**The guard:** author the palette band reservation before the first region, cap
the drift amplitude explicitly, and require every region to be identifiable from
a 64-pixel-wide thumbnail.

## A3.14 Signature Haven's Rest moment

**The trailhead.**

Five to eight seconds. The character kneels at the Meadow Patch just outside the
gate, where the worn approach widens before the trail leaves the frame. The
meadow moves — a slow shared drift through the grass, the two flanking canopies,
and the thin smoke thread from the roof behind the palisade, all on the same
phase at slightly different rates. The NPC at the gate is still.

The character parts the grass, reaches, closes, draws, and rises. Once —
**because the underlying state authorized it** — the plant releases, recoils
past rest, two seed motes lift into the drift and travel with it, and a herb
arcs to the pack.

The meadow keeps moving. It was moving before you knelt, and it does not care
that you stood up.

---

# Comparison matrix

Judgements about these three treatments as described above. **No winner is
named.** All three sit inside Direction A; none is more or less "Direction A"
than the others by register — the *purity* row below measures how easily each
one could be pulled out of A, not how far inside it they currently sit.

| Axis | A1 — Frontier Hearth | A2 — Rune-Worn Adventure | A3 — Wild Trails |
|---|---|---|---|
| **Immediate appeal** | High — warm and familiar on first sight | Medium–High — intriguing, slower to land | High — open and fresh |
| **Project Stride distinctiveness** | Medium–High — repair/reuse and timber UI are ownable | **Highest** — one symbol language across world, UI, and combat | High — trails and shared drift are strongly on-thesis |
| **Direction A purity (resistance to drift)** | **Highest** — no mechanism invites rendering complexity | Medium — glowing runes are one permission away | Medium–High — ambient motion invites atmosphere creep |
| **Mobile readability** | **Highest** — quietest world, boldest silhouettes | High — strong marks, high-contrast glyphs | Medium–High — most competing terrain information |
| **Character customization potential** | High — layered practical gear composes well | High — inherited/repaired detail and marks vary richly | Medium–High — regional accents, less per-piece variety |
| **Equipment readability** | **Highest** — function-forward silhouettes | High — mark placement adds a second read | High |
| **World identity** | High — settlements are the strongest | High — the world reads as *legible*, marked and navigable (and, under RA-1, carries no history to lean on) | **Highest** — regions are the strongest |
| **Resource-node readability** | High | **Highest** — companion marker adds a second silhouette | Medium–High — needs strict palette-band discipline |
| **Living-activity appeal** | High — rhythm and rest beats | Medium–High — deliberate, slightly slower | **Highest** — the environment carries the watchability |
| **Gathering identity** | High — gathering as work | High — gathering at known, marked places | **Highest** — gathering as terrain knowledge |
| **Combat compatibility** | Medium–High — least dangerous-feeling | **Highest** — telegraphs reuse a learned symbol language | Medium–High — ambient motion must be suppressed under telegraphs |
| **AI-production suitability** | **Highest** — squared geometry, kit, palette lock | High — glyph library is highly verifiable | Medium–High — organic forms verify least well |
| **Animation workload** | **Lowest** | Low — one extra beat per loop | Medium — ambient layer, if disciplined as a shared parameter |
| **Long-term scalability** | High — settlement kit recombination | High — marker kit spans every region cheaply | **Highest** — regions are the native unit |
| **Risk of generic fantasy** | Medium — frontier is a used register | **Lowest** — the symbol system is unusual | High — nature-led converges fastest |
| **Risk of visual drift** | **Lowest** — drifts toward cozy-farm, which is obvious and catchable | Medium–High — drifts toward rune fantasy, which is seductive | Medium–High — drifts toward survival wilderness, which is subtle |
| **Risk of B-style creep** | **Lowest** — nothing in the identity wants light | Medium — "make the runes feel magical" is a lighting request in disguise | Medium–High — "make the world feel alive" is the most common route to atmosphere creep |

## Three observations the matrix makes visible

1. **A1 and A2 trade familiarity against distinctiveness, and the trade is
   clean.** A1 is the most immediately appealing and the safest to produce; A2
   is the most likely to be recognised as a specific game and the most likely to
   drift into a crowded look if the "marks are inert" rule ever softens (RA-1).

2. **A3's greatest strength and its greatest risk are the same feature.**
   Environmental identity makes regions distinctive and living-activity scenes
   watchable — and it is also the thing most likely to bury a resource node, tax
   a telegraph, and invite atmosphere creep. A3 is viable, but it is the
   treatment with the most load-bearing rules.

3. **Each treatment's most valuable idea is separable from its identity.** A1's
   rest beat, A2's one-symbol-vocabulary, and A3's shared drift phase are all
   techniques rather than styles. **They are not being hybridized here** —
   noted only so the owner knows the options are not all-or-nothing.

## Current interpretation — descriptive, not a ranking

> **Recorded at owner review. This is a description of where each treatment's
> strength currently sits. It is not a ranking, not a shortlist, and not a
> decision.**

| | Currently represents |
|---|---|
| **A1** | production discipline · readability · Direction A purity |
| **A2** | symbolic identity · cross-system visual vocabulary · combat readability |
| **A3** | walking-land-resource identity · living-world presentation · regional scalability |

**All three proceed to Round 1 on equal terms.** Owner and project-review
interest is currently strongest in A1 and A3; **A2 is not eliminated** and must
receive the same craft, the same specification depth, and the same production
effort in the sample round. Weakening a candidate to sharpen a contrast breaks
the experiment rather than resolving it.

---

# Visual sample preparation

**No images are generated by this task, and the visual-sample task is not
started here.**

## RA-2 — the approved visual-test sequence

> **Owner ruling, made at review of this document. Not an ADR.**

### Round 1 — static identity comparison. **A1 vs A2 vs A3.**

One image per treatment, using the **same existing Haven's Rest / Meadow Patch
composition** and the **same Direction A rendering floor**.

**Round 1 tests visual identity only:**

- shape language
- architecture
- character identity
- UI chrome
- icon language
- resource-node treatment
- environmental motifs
- overall Project Stride distinctiveness

**The optional second Foraging frame is NOT part of Round 1.** It was proposed
in the previous revision and is **withdrawn by owner ruling**. Adding an
activity pose now would introduce a second comparison variable and double the
generation workload **before it is known which identities deserve deeper
testing**. Interaction state stays *node noticed, not yet tapped*, identical in
all three, exactly as in `VISUAL_SAMPLE_GENERATION_01.md` §6.

### Round 2 — Living Activity Presentation comparison. **After Round 1 review.**

Only after the owner has reviewed Round 1:

1. the owner **selects the strongest two** identity treatments
2. a controlled Living Activity Presentation comparison runs on **those two only**
3. holding identical: **the same Foraging activity and state · the same
   character · the same location · the same resource · the same animation moment
   · the same game state**

Only then is it a comparison of how two identities handle a living activity
scene.

### Later, and only if useful

Mining, Woodcutting, and other activity readability **may** follow for the
finalist.

> **None of these later rounds is created, specified, or scoped by this
> document.** Round 2's shared answers, its animation moment, its evaluation
> rubric, and any subsequent round remain undefined until the owner has seen
> Round 1. Defining them now would be designing a comparison for evidence that
> does not exist yet.

**LAP-1 still governs whatever Round 2 eventually depicts.** A depicted gather
is a *visualization of already-authorized state*; the presentation layer may
display a progression event and may not create one, and watching never grants
progress.

## Round 1 — proposed controlled sample scene

**Reuse the existing Haven's Rest / Meadow Patch canonical scene**, unchanged,
for all three treatments.

**Why:** the composition is already specified to proportional positions, the
control blockout already exists at
`GAME_BIBLE/ART/exploration/VISUAL_SAMPLE_01/composition_blockout.png` with its
generator script beside it, the U-3/U-4/U-5 provisional answers are already
fixed, and the owner has already reacted to that exact staging under Direction
A. Changing the scene now would discard the only baseline the comparison has.

### What is held identical across A1 / A2 / A3

Everything held identical in `VISUAL_SAMPLE_GENERATION_01.md` §2, plus:

- the composition control image (§5.4), supplied to all three
- camera family, pitch, framing, subject placement (R-2)
- element positions (§5.3) and the **exhaustive prop inventory**
- U-3 / U-4 / U-5 answers (§4)
- HUD regions, HUD content, game-state values, interaction state (§6)
- time of day, light direction, text discipline (five strings only)
- **the Direction A rendering floor** — pixel construction, restrained palette,
  flat baked upper-left light, no dynamic lighting, no bloom, no rim light, no
  specular, no haze, no light shafts, no particles, contact shadows only
- the shared negative block (§7.4)

### What is permitted to vary — the entire signal

- **motif and prop language** within the fixed prop inventory (a signpost is a
  carved plank arm / a waystone / a blazed post with a cairn — same object,
  same position, different identity)
- **architectural grammar** (bracing and repair / mismatched older stone
  footings / buildings sitting into graded terrain)
- **palette family and its regional discipline**
- **UI chrome language** (plank-and-bracket / incised groove / thin double rule
  with a notch) and **icon geometry**
- **character silhouette tendency** (broad and squared / upright and
  close-strapped / lean and forward-leaning)
- **resource-node dressing**, within the same per-skill silhouette family
- **implied animation personality** (rest beat / preparation beat / ambient
  drift), insofar as a still frame can carry it

### One A2-specific generation constraint

Per RA-1, the A2 prompt block must describe **route, wayfinding, settlement,
craft, and resource markings** — carved, weathered, inert, unlit. It must **not**
use the word *runes*, and must explicitly exclude glow, emission, magical
symbols, arcane script, and mystical ornament. This is the single highest-risk
prompt in the round: "worn runes" is the phrase that turns a restrained pixel
sample into generic glowing fantasy, and it would invalidate A2's sample under
the shared Direction A rendering floor.

### What Round 1 does not test

Living Activity Presentation, animation personality in motion, activity poses,
combat, and regional variation. Those are **deliberately out of Round 1** (RA-2)
and no Round 1 result should be read as evidence about any of them.

**Whether the round runs at all, in what tool, and with what conditioning
strength remains the owner's decision** (`VISUAL_SAMPLE_GENERATION_01.md` §9 —
Claude Code has no image-generation capability in this environment).

---

# Canon notes — contradictions and overlaps

Recorded per `RULES.md` G-3 and G-7. **Nothing here is resolved by this
document.**

**CN-1 — → RULED by the owner as RA-1 (§A2.0). Closed as a risk, kept as a
constraint.**

The concern was that A2 would need new ancient/mystical world canon to work. The
ruling is that **it may not have any**. A2's marks are route, wayfinding,
settlement, craft, and skill/resource iconography — old, practical, inert,
non-glowing, non-magical, and **unexplained**. No ancient civilization, magical
rune system, forgotten empire, religion, or prior age may be created to support
this direction, and `GAME_BIBLE/WORLD/` is not modified.

**A2 has been rewritten to comply** — thesis, shape language, Haven's Rest
identity, combat hook, distinctiveness test, failure mode, and signature moment
all now stand without world history. Age appears only as material observation.

**If A2 cannot be distinctive under that constraint, the comparison should show
it.** That is the intended outcome of the test, not a defect in it.

**CN-2 — A3 sits nearest the R-4 boundary.** Trail, route, and terrain-transition
motifs are the visual vocabulary most easily misread as free-roam traversal.
A3's trails are **depicted terrain wear**, not a navigation affordance. R-4
stands: no joystick, no WASD, no pathfinding, no free-roam, no waypoint trail,
no tap-to-move marker. U-6 remains **UNRESOLVED**.

**CN-3 — F-4 remains open and was not closed here.**
`GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md` and
`MILESTONES/MILESTONE_01_FIRST_ADVENTURE.md` still describe six tabs and one
combat modal and **do not mention a world view**, which R-1 established exists.
Reconciling them is real work under `RULES.md` G-6 and G-7 and is outside an art
exploration's scope.

**CN-4 — Fishing is not a Project Stride skill.** Milestone 01 has exactly five
skills — Woodcutting, Mining, Foraging, Smithing, Cooking (`DECISIONS/0004`,
`assets/content/v1/skills.json`). Fishing appears in §A1.7 / §A2.7 / §A3.7
**solely as a presentation example**, per the owner's brief and
`VISUAL_SAMPLE_GENERATION_01.md` §15.2's existing scope note. It is not added to
the game, the milestone, or any roadmap.

**CN-5 — Regional gear accents (A3) are an unresolved design question.** §A3.3
notes that A3's visual language *would support* gear varying by region. Whether
it does is a Systems/Content question and is **UNRESOLVED**. Nothing here
proposes it.

**CN-6 — Overlap between treatments is real and deliberate.** All three share the
per-skill node silhouette families, the palette-separation rule, the outline
rule, the animate/static split, and the audio beat structure. That shared floor
is `VISUAL_EXPLORATION_01.md` §A carried forward, and its recurrence is
consistency, not duplication. **No treatment claims authority over it.**

**CN-7 — The provisional-values reference in `VISUAL_EXPLORATION_01.md` still
governs.** Where that table gives Direction A values (character height, tile
grid, head-to-body, palette size, frame budgets), those remain **PROVISIONAL**
and are **not** restated or refined here, per the owner's instruction to leave
production dimensions unspecified.

---

# Scope statement

**What this task did.** Read the governance, kernel, and design documents and
the full art record; developed three identity treatments inside Direction A;
compared them without naming a winner; proposed a controlled sample scene; and
flagged seven canon notes.

**What owner review then added.** The set was approved, all three treatments
proceed, **RA-1** (the A2 symbol constraint) was ruled and applied throughout
A2, **RA-2** (the two-round visual-test sequence) was recorded, the optional
second Foraging frame was withdrawn from Round 1, and the descriptive strengths
of the three treatments were recorded as explicitly non-ranking.

**What this task did not do, deliberately.**

- **No world history, lore, civilization, empire, religion, prior age, or
  magical system was created**, and `GAME_BIBLE/WORLD/` was not modified
  (RA-1).
- **Round 2 and any later activity-readability round were not created,
  specified, or scoped** (RA-2).

- No art was generated, and no image file was created or fabricated.
- `ART_DIRECTION.md` was **not modified** and still reads **EXPLORATION**.
  Direction A is not locked.
- No production art direction was selected.
- No fourth identity direction was created, and **no hybridization of A1/A2/A3
  was performed or proposed**.
- No production pixel dimensions, frame counts, palettes, or camera geometry
  were specified.
- No gameplay code, HealthKit code, persistence, native adapter, CI
  configuration, architecture, or navigation system was touched.
- No gameplay, systems, milestone, UX, world, or vision document was amended.
- No ADR was created.
- No scheduler, event queue, animation controller, or offline replay model was
  designed (LAP-1 remains a constraint to design around, not a design).
- No skill was added to any milestone. Fishing remains outside the game.
- U-3, U-4, U-5, and U-6 all remain **UNRESOLVED**.
