# Open Questions

Nothing in this folder is approved. These are questions worth answering later, recorded so they are not rediscovered expensively.

## Two kinds of entry live here

**Q-entries** are genuinely open questions — nobody knows the answer, and the entry records why it is deferred rather than guessed.

**OD-entries are owner direction.** The *direction* is settled and is not open for an agent to relitigate; only the **design and implementation are deferred**, and they are deferred because the owner has not authorised the work. Treat an OD-entry as a standing requirement waiting for its milestone, not as an invitation to debate.

An OD-entry is not canon. When one is implemented it graduates into the canonical home named in its entry — `GAME_BIBLE/`, a `DECISIONS/` ADR, or both — and the entry is closed with a pointer. Recording it here rather than in `GAME_BIBLE/` is deliberate: a requirement written into canon before it has been designed becomes a constraint on its own design.

> **`OD-` not `D-`.** `D-01` is already taken by a *defect* — the banked-steps
> header clip, in `MILESTONES/PLAYABLE_DEMO_PHASE_1_DEVICE_RESULT.md` §5. Two
> registers, two prefixes, no collision.

---

## Q-01 — What does Stride offer a player who cannot walk this week?

**Raised by:** Critic Agent, `CRITIC_REPORT.md` CR-1
**Date:** 2026-08-01
**Target:** Milestone 02, after the vertical slice has been played

### The question

Progression is step-clocked (`DECISIONS/0001`). No steps, no progress. That is the right decision and should not be reopened.

But consider a sick week, an injury, a desk-bound deadline. A player opens Stride on day four of the flu with zero banked steps. Every screen still opens, every affordable craft still works — "steps gate rate, never access" holds — but if the inventory is empty and every activity needs steps, the honest experience is an app with nothing for you today.

That is not FOMO and it is not punishment. It is, however, an uncomfortable fit with `04_PLAYER_PROMISE.md`: *"return to a world that feels welcoming rather than demanding."* Sometimes life means not walking, and a game whose only input is walking has no answer for that yet.

### What is explicitly *not* being proposed

Time-based accrual. It would gut decision 0001 and make the walk optional. Any answer to this question must leave the step clock intact.

### Candidate directions

- A crafting backlog the player can always work through
- Lore, journal, and world reading with no step cost
- Retrying already-unlocked encounters
- Planning and preparation tools that are satisfying in themselves

Notably, **all four already exist in the vertical slice.** That suggests the answer may not be a new system at all, but a balance goal: make sure the player always has something banked to build, read, or fight. If so, this is a tuning question for `GAME_BIBLE/BALANCE/`, not a design one.

### Why it is deferred

Answering it now would be designing for a problem nobody has felt. Ship the slice, play it through a real low-step week, and then decide.

---

## Q-02 — What makes the Traveler recognisable?

**Raised by:** owner, Visual Owner Direction Round 01
**Date:** 2026-08-14
**Target:** after a character attempt built against an approved READ SPEC has been reviewed

### The question

`VISUAL_STUDIO_BASELINE_AUDIT_01` found the Traveler's only memorable features were a chest strap and a hair mass, and concluded that a main character needs a silhouette a stranger could recognise at ×2. The obvious response is to give it a signature — a scarf, an emblem, a distinctive hat.

**That response is deliberately withheld.** `ART_DIRECTION.md` L-5 requires recognisability to be attempted first through proportion, gesture, clothing shape, equipment relationship and restrained colour placement. A decorative mark added to a figure that does not yet read as a person carrying a pack would disguise the failure rather than fix it.

### What is explicitly *not* being proposed

Adding an ornament to make the character memorable. If the figure needs one, that conclusion has to arrive **after** the silhouette work has been given a fair attempt and found insufficient — not instead of it.

### Why it is deferred

There is no evidence yet about how much identity the locked proportions and equipment can carry on their own, because no attempt has been made against an approved read spec. Deciding now would spend the character's one distinctive feature before knowing whether it is needed.

---

## Q-03 — Can the locked equipment read inside a 24 × 34 canvas?

**Raised by:** Character Pixel Artist, `VISUAL_STUDIO_BASELINE_AUDIT_01` Audit B
**Date:** 2026-08-14
**Target:** the first READ SPEC review

### The question

The audit measured a minimum honest column budget of **26 columns** for the current equipment inventory with arms capable of satisfying CR-13, against **24 available** — the sprite is already flush to the canvas edge, with two free columns on the near side and none on the far side.

`ART_DIRECTION.md` L-3 holds the canvas at 24 × 34 anyway, on the reasoning that the shortfall is evidence of a bad *arrangement* rather than a small canvas: equipment currently occupies the same chest-height band as both arms, and moving the load off that band frees roughly four far-side columns.

### Answered for the next attempt — verdict (A)

**2026-08-14.** The Character Visual Designer judged **(A) — 24 × 34 should be sufficient with better mass allocation**, and the owner accepted it. `CHARACTER_READ_SPEC_01.md` is frozen on that basis and **the canvas is not widened.**

The reasoning: 26-against-24 measured **one row**, in an arrangement where the pack, both arms and the torso all demanded width in the same band. The approved architecture separates the loads by height rather than by side — pack above and behind the far shoulder, both arms owning the chest register, sword at the near hip — so no single row is asked to hold all three.

### The three reopening conditions

**Q-03 reopens only if one of these is demonstrated in an actual compliant render — shown, not argued — while holding L-1, L-2 and L-4:**

1. At the widest chest row, torso plus both arms plus the near-side background notch cannot be accommodated without either **widening the figure** (forbidden by L-2) or **eliminating the notch** (which reinstates the diagnosed failure).
2. At the hip rows, the near hand and the scabbard **cannot be separated by any means** — rows, contour, or overlap — without one of them leaving the canvas or merging with the leg.
3. The scabbard **cannot achieve enough length** to escape the mug/canteen read while remaining below the belt and above the boot.

> **"More pixels would be easier" is not a reopening condition.**

Canvas size may be reopened only where the locked requirements are shown to be **mutually incompatible in a compliant render**.

**The most likely pressure point is condition 3** — the hip register is where this is genuinely tight, and it is the one to watch.

### Why the bar is set this high

Widening the canvas is the cheapest available response and the one `PIXEL_ART_CRAFT_SPEC.md` CR-1 and §7 most directly warn against. The allocation fix had never been tried; until an attempt is made against the frozen spec, there is no evidence about what 24 columns can hold.

---

## Q-04 — Does the current location get to be teal?

**Raised by:** UI Facelift 01
**Date:** 2026-08-16
**Target:** the next visual owner-direction round, or the World screen's next pass

### The question

`ART_DIRECTION.md` **L-16** reserves teal `#58d6c0` for *"walking, steps, and
banked-step quantity. Nothing else, anywhere, ever."*

The World screen's region list already colours **the player's current location**
teal (`world_screen.dart`, `_PlaceRow`). A place name is not walking, steps, or a
quantity, so on a plain reading that is a violation — and it has shipped, been
seen on a device, and been accepted.

Two readings are available and neither is obviously right:

- **L-16 means what it says**, this is drift that arrived while nobody was
  looking at the rule, and the emphasis should come from weight or a label
  instead.
- **L-16 is about quantities**, and marking "where you walked to" with the
  walking colour is the rule being applied rather than broken.

### What the facelift did about it

Nothing, deliberately. The new `YOU ARE HERE` caption under the map uses
`textPrimary` and lets its label carry the emphasis, so the pass did not spread
the pattern — and it did not remove the existing one either, because that is an
identity call and identity calls are the owner's (`RULES.md` G-3).

The consequence today is a **small inconsistency**: the same place is named twice
on one screen, in two colours. That is the honest cost of not deciding, and it
is cheap to resolve either way once the rule's intent is stated.

### Why it is deferred

Answering it means either amending a lock or changing shipped art direction, and
both belong to the owner. It costs one line of code in whichever direction it
goes.

---

## OD-01 — The step-economy cutover — ✅ **CLOSED, graduated**

**Closed:** 2026-08-17, Playable Phase 2. **Graduated to
`DECISIONS/0016_ECONOMY_EPOCH_CUTOVER.md`**, which is now canonical for this.

The entry's own guess was right and is worth recording as such: *"the second
preserves H-2 by construction and is the one to cost first."* It is a **runtime
epoch** — a mark on both running totals, from which `banked` is measured.
Nothing is subtracted, deleted or rewound; H-2 and H-3 are intact by
construction rather than by care; and the P-5 question the entry raised is
answered in the ADR rather than waved past. The historical steps remain
reportable.

Exactly-once is the state version, and the migration commits through the
ordinary transaction path. Eighteen tests cover the nine required behaviours.

**Note, 2026-08-17 (Transformation Build 01):** the second epoch 0016 said
"would need its own decision" has one — `DECISIONS/0018_TRANSFORMATION_PLAYTEST_EPOCH.md`,
state version 3, same mechanism, owner-directed, retiring the Phase 2
device-validation balance so the first playtest starts at zero. Re-basing is now
an opt-in flag on an explicit migration table step; the epoch records which
step set it. P-5 remains unamended. Not reopened here.

**The text below is the original direction, preserved unedited** so the ADR can
be read against what was actually asked for.

**Raised by:** owner, immediately after Playable Demo Phase 1 closure
**Date:** 2026-08-16
**Status:** ~~OWNER DIRECTION — recorded, **not authorised for implementation**~~
**IMPLEMENTED** — `DECISIONS/0016`

### The direction

The large historical banked balance is **validation history, not the intended
long-term player economy**. At Phase 1 closure it stood at 459,043 banked from
459,223 granted — roughly 5,100 gathers' worth, accumulated by a device
integration proving it could count, not by a player choosing to walk.

Before significant progression is built on top of it, there is to be a
**deliberate one-time cutover** so the playable game begins from zero banked
steps at a defined point in time.

### Required long-term behaviour

- Historical steps before the cutover **do not become spendable game currency**.
- Banked steps **start from zero** at the cutover.
- Only steps **observed after the cutover** are granted.
- Manual **Sync Steps remains valid**.
- Eventually, **foreground startup should automatically reconcile** new steps.
- **No background-sync work is implied.** S-01B stays out of scope.
- **No loss of the no-double-count guarantees.**

### Why this is not a small change, and must not be done casually

Recorded now so whoever picks it up does not discover it late:

- **`RULES.md` H-2 says granted is monotonic and there is no clawback.** A
  cutover that reduces `totalGranted` contradicts it. So the cutover is almost
  certainly **not** a subtraction — it is more likely a new epoch, a reset
  cursor, or a fresh ledger, leaving the historical figures intact and simply no
  longer spendable. Which of those it is, is exactly the design question.
- **The cursor is the mechanism that prevents double-counting** (`H-3`). Any
  reset that discards or rewinds it risks re-granting history — the precise
  failure the last two device runs proved absent. A cutover that reintroduces it
  would be a severe regression in the one guarantee the architecture exists for.
- **`P-5` says nothing decays and earned opportunity never expires.** Retiring
  banked steps needs to be squared with that, or the rule needs amending by its
  owner. It is a Kernel-adjacent question, not an implementation detail.
- The **save format** (`DECISIONS/0012`) has no concept of an epoch today.

### What it is not

Not authorisation to implement. Not a licence to weaken H-2, H-3 or P-5 to make
a reset convenient — an invariant that is inconvenient is still an invariant
(`G-4`), and changing one belongs to its owner.

### The obvious first question when this opens

Is the cutover a **save migration** (rewrite the ledger once, at a version
boundary) or a **runtime epoch** (keep the ledger, move a "spendable from" mark)?
The second preserves H-2 by construction and is the one to cost first.

---

## OD-03 — The step-economy mark — ✅ **CLOSED, shipped** (Activity Feel 01, 2026-08-20)

**Closed by three blind rounds**, record in
`GAME_BIBLE/ART/exploration/ACTIVITY_FEEL_01/README.md` §3 and the
provenance row in `assets/ui/v1/README.md`. The shipped mark is a **PixelLab
cuffed traveler's boot**, 12 × 12, palette-conformed (A-2) to the canonical
teal `#58D6C0` family with the muted `#B3A794` twin — the
`walking_glyph.dart` two-colour pairing preserved exactly.

Two geometry findings worth keeping, both extending this entry's own
"one connected mass" lesson:

- **A boot print cannot fit the 12 × 12 slot.** All 64 connected candidates
  of a pro run measured 8×14–10×16 — a print's natural aspect is ~1:1.7.
  A print trimmed to fit blind-read as "a padlock / keyhole". The print
  direction is closed at this slot size, not merely unattempted.
- **Shaded detail fragments at 24 dp; a bold silhouette with at most one
  interior line survives.** The retired chrome glyph, facing a real
  competitor in the final blind round, was itself misread as "the letter L /
  a Tetris piece"; the shipped boot was the only candidate read as both an
  object and drawn pixel art.

Noted residual risk (blind round 3): a boot can read as an equipment slot;
adjacency to the step figure resolves it. **The original direction below is
preserved unedited.**

### OD-03 — as raised: 🔶 One attempt, not shipped

**Round 01 ran on 2026-08-17 alongside OD-04 and did not ship.** The generation
returned two footprints side by side. It was not taken to blind QA because it
fails on inspection for the same reason OD-04 did: **two separate prints at
12 × 12 are two small masses with a gap, and the gap is the first thing to close
under reduction.** The result would be one blob.

The brief for the retry is sharper than it was: the mark must be **one connected
mass at 12 × 12** — either two prints overlapping enough to touch, or a single
print rather than a pair.

The turquoise boot glyph stays. Recorded in
`GAME_BIBLE/ART/exploration/SKILL_ICONS_OD04/ROUND_01_RESULT.md`.

**Raised by:** owner, UI Facelift 01 physical-device review
**Date:** 2026-08-17
**Status:** OWNER DIRECTION — **one round attempted, not shipped**
**Graduates to:** `GAME_BIBLE/ART/ART_DIRECTION.md`, and the asset set under
`assets/ui/v1/`

### The direction

The current **turquoise boot glyph** (`glyph_steps.png` and its muted twin) is
**temporary art and requires replacement by a canonical pixel-art
walking/steps asset.**

### Why this one matters more than its size suggests

It is the symbol of the thing the product is about. Real-world walking is the
entire input to the game, and this mark is how the interface names it. It is
also the **most repeated** piece of art in the app: the persistent header
readout on all four screens, the walking band, the cost tiles, the route
distances on the World screen.

`ART_DIRECTION.md` **L-16** already reserves teal `#58d6c0` for walking, steps
and banked quantity. The colour is canon; the shape is not.

### Required properties of the replacement

- **One mark, used consistently everywhere the step economy appears.** Not a
  glyph redrawn per surface.
- It must survive the **two-colour rule** in
  `lib/ui/components/walking_glyph.dart` — teal for steps the player owns, muted
  for steps as a unit of measure — or replace that rule deliberately. Today both
  variants are the same mark in two colours, and a replacement that breaks the
  pairing breaks the rule with it.
- **Pixel art, at an integer scale** (**L-18**). It is displayed at 12 × 12
  native, ×2.
- Read at **×2**, which is play scale and therefore verdict scale (`MISTAKES.md`
  M-05).

### Explicitly NOT authorised

**Do not improvise a vector, icon-font or SVG substitute.** A stopgap in another
medium would put a second visual language into the most-repeated mark in the
product, and the hybrid identity is specifically *native chrome + pixel
content*.

Nothing about the current glyph blocks the UI, so this is scheduled art work,
not a defect.

---

## OD-04 — The five skill icons — 🔶 **STILL OPEN.** Specified, attempted, failed QA

**Round 01 ran on 2026-08-17 and did not ship.**

- The specification exists and is frozen: `GAME_BIBLE/ART/SKILL_ICON_SPEC_01.md`.
- One round of five was generated against it and taken to independent blind QA.
- **Verdict FAIL.** Full record and spec amendments:
  `GAME_BIBLE/ART/exploration/SKILL_ICONS_OD04/ROUND_01_RESULT.md`.

**The acceptance case the spec named — pot versus anvil — passed.** The one
nobody had written down did not: **at ×2 the axe and the pickaxe read as the
same object**, because both reduce to a bar over a stick and the head shape that
separates them lives in pixels the reduction cannot keep.

The finding is worth more than the set would have been:

> **Two hafted tools cannot be told apart at 12 × 12.** The next round must
> separate Woodcutting and Mining by silhouette *family* — a mass rather than a
> stick — not by head geometry.

Three spec amendments are recorded and deliberately **not yet applied**, so the
frozen §3 still says what round 01 was judged against.

The current five icons stay. This entry stays open.

**Raised by:** owner, UI Facelift 01 physical-device review
**Date:** 2026-08-17
**Status:** OWNER DIRECTION — **specified, one round attempted and failed**

### The direction

The five current skill icons — Foraging, Woodcutting, Mining, Smithing,
Cooking — are **temporary art requiring a cohesive PixelLab replacement set.**

> This is an **art workstream with a shared specification**, not five unrelated
> icon generations.

### Why they need replacing

They were authored to close a gap, one sprite at a time. Only Foraging shipped
first — the Character screen listed five skills with four empty icon slots, and
the one that had a sprite read as a stray decoration rather than as a member of
a set — and four more were added quickly to fix that.

The consequence is visible: Visual QA could not reliably separate the cooking
pot from the smithing anvil at icon size, and the five do not share a
construction. They are five drawings that happen to be the same size.

### What the specification has to settle before any asset is generated

- **Silhouette language** — what makes these five read as one family, and as
  *skills* rather than as items.
- **Contour and interior weight** inside a 12 × 12 canvas.
- **Palette placement**, including how each icon sits against its own skill hue
  (`StrideColors.forSkill`) without the hue doing the identifying work.
- **Distinctness under blind read at ×2** — the pot/anvil failure is the
  acceptance case.
- The two surfaces they appear on: the Character screen's skill rows, and the
  gather card's skill chip. Both are ×2.

### Explicitly NOT authorised

**Do not generate replacement assets** during a UI or correction pass. The
specification comes first, and the set is generated against it in one round so
the five can be compared with each other rather than approved one at a time —
which is how the current set happened.

---

## OD-05 — The interactive, animated world atlas

**Raised by:** owner, after the Phase 2 provenance audit
**Date:** 2026-08-17
**Status:** OWNER DIRECTION — settled, **implementation deferred**
**Graduates to:** `GAME_BIBLE/WORLD/`, `GAME_BIBLE/UI_UX/`, and the asset set

### The direction

The World screen becomes a **large interactive world atlas**: a substantially
bigger illustrated map the player can **pan** around, with **zoom** where it
improves mobile usability.

The map shows the actual world geography — grassland, forest, mountain, alpine
snow and ice, dry and arid ground, rivers, lakes, coastline where appropriate,
settlements, and the routes and passes between them. **Regions and towns
correspond to real implemented locations**, and the geography reflects the
regional ecology and resources (`OD-02`,
`GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md`).

### Ambient animation, and its limits

Subtle ambient motion is wanted: slowly moving cloud layers, restrained wind,
subtle vegetation movement, water movement, and snow or weather where
appropriate.

Every one of them is bounded by the same four rules:

- remain subtle
- never cover an important destination for long
- never reduce map readability
- **never imply free-roam character control**

### The distinction that keeps this honest

> The map is interactive because the player can **inspect and select legitimate
> destinations** — not because they steer a character around it.

Travel stays domain-owned, deliberate and step-powered. `TravelTo` remains the
only way to move, and it still charges. This is the same line
`PIXELLAB_STYLE_SPEC_01.md` draws in its governing rule — art must not imply a
system the game does not have — applied to interaction rather than to
illustration.

### Division of labour

**PixelLab produces the creative map, environment and animated visual assets**
(`RULES.md` A-1).

Claude implements the viewport, pan and zoom, layer stack, compositing, map
coordinates, location hit targets, travel integration, animation playback, and
technical post-processing (`RULES.md` A-2). Claude does **not** hand-draw or
code-draw the production world artwork.

### Why it is deferred

Not authorised during the Phase 2 CI cleanup, and not to be started before the
owner's device pass. The Phase 2 map is a single static 384 × 640 banner and is
the correct scope for a milestone about whether the *game loop* works.

---

## OD-06 — Audio and environmental sound

**Raised by:** owner, after the Phase 2 provenance audit
**Date:** 2026-08-17
**Status:** OWNER DIRECTION — settled, **implementation deferred**

**Note, 2026-08-19 (Playable Expansion 01):** the repository and the working
context were searched for the owner's previously shared audio resource
references — none exist in the repo (no URLs, no manifest rows, no audio
dependency). Nothing was guessed; the audio foundation stays deferred until the
owner resends them. Combat now emits the events an audio layer would hook
(`CombatPlayerStruck`, `CombatEnemyStruck`, `EncounterWon`, …), so the first
audio pass has concrete cues waiting.
**Graduates to:** `GAME_BIBLE/AUDIO/01_AUDIO_IDENTITY.md`, and an audio layer

### The direction

Project Stride becomes a substantially richer audio experience. Scope:

- region and biome ambience
- town and interior ambience
- wind and weather
- environmental loops
- travel feedback
- UI feedback
- gathering, woodcutting, mining, smithing, cooking
- fishing, when implemented
- combat, when implemented
- regional music where appropriate

Audio should eventually reinforce **biome, profession and world identity** —
the same three axes `OD-02` grounds the geography on.

### The source the owner has already supplied

The owner previously shared GitHub audio-related resources.

> **Do not guess or invent those repositories.** They are not in this session's
> context, and a plausible-looking URL recorded here would be worse than an
> acknowledged gap — it would be acted on later as though it were the owner's.

When OD-06 opens, in this order:

1. **Recover the exact previously-shared GitHub source**, or ask the owner for
   it. Do not proceed on a guess.
2. Audit **licensing**.
3. Audit **Flutter and mobile compatibility**.
4. Audit **formats, looping behaviour and memory footprint**.
5. Decide what comes from that source versus custom-generated sound.
6. Integrate through **one coherent Project Stride audio layer**, not per-screen
   playback calls.

**ElevenLabs may remain part of the custom sound-design pipeline** where useful.

### Why it is deferred

`DECISIONS/0005_AUDIO_SOURCING.md` already governs sourcing and provenance, and
the Phase 2 brief was explicit that audio must not block the playtest. It does
not block it now.

---

## OD-02 — Regional ecology — ✅ **CLOSED for the first slice, graduated**

**Closed:** 2026-08-17, Playable Phase 2. **Graduated to
`GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md`**, which is canonical for the
first playable geographic slice — five locations across four terrains, with
resources following geology and climate rather than convenience.

**Both dependencies the entry named are discharged.** Travel exists as
`TravelTo` and spends real steps (`DECISIONS/0017`). Terrain is a required field
on every location, so what a region *is* is now decided in data before anything
is drawn — which was the entry's own stated ordering.

**Closed for the first slice only.** The wider world — arid, coastal, wetland,
the metal tier below Stonefall — remains unbuilt, and §8 of the new document
names where each of them goes and why. The map art was deliberately **not**
regenerated: the current region map still shows four locations and does not
include Frostmere.

**The text below is the original direction, preserved unedited.**

**Raised by:** owner, immediately after Playable Demo Phase 1 closure
**Date:** 2026-08-16
**Status:** ~~OWNER DIRECTION — recorded, **not authorised for implementation**~~
**IMPLEMENTED for the first slice** — `GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md`

### The direction

Future world design expands beyond the current region into a **coherent
geographic world** of multiple meaningful biomes — potentially grassland and
temperate, snow / ice / alpine, dry / sandy / arid, mountain ranges, forests, and
rivers, lakes and coast where geographically appropriate.

**Resources and professions are to be geographically grounded**, not distributed
for gameplay convenience:

- ore availability tied to geology and mountain regions
- wood species tied to forest and biome
- fishing species tied to local waters
- hunting tied to regional fauna
- herbs and foraging tied to climate
- cooking ingredients tied to local resources
- towns and settlements shaped by what the surrounding land produces

> The World Map is to be designed as **a coherent geographic and economic system,
> not a collection of themed zones.**

That sentence is the whole requirement. A themed-zone world can be assembled
piecemeal; a geographic one cannot, because where things are has to follow from
the terrain, and the terrain has to be decided first.

### Scope of the eventual workstream

A later dedicated world-design workstream — which **may** use a specialised
design agent — would cover region layout, biome transitions, mountain and water
geography, towns and settlements, travel relationships, regional resources,
profession and resource gates, and deliberate space for future expansion.

### Explicitly NOT authorised now

**Do not generate or canonise the expanded world map.** The current region map
(`assets/art/v1/world/region_map.png`) stands as Phase 1's presentation and is
not to be replaced or extended on the strength of this entry.

### Two dependencies worth naming before the workstream opens

- **There is no travel activity at any layer.** `EnterLocation` exists but takes
  no step cost, and the command that spends banked steps to cross a route is
  unwritten. A geography whose whole point is that places are *far apart* needs
  that system to exist, or the map is describing distances nothing can traverse
  — which is exactly the honesty problem the Phase 1 World screen had to solve
  with a sentence.
- **Geographic grounding is a content-schema question before it is an art
  question.** `locations.json` has `resourceNodes` and `connections` but no
  concept of biome, climate or terrain. Deciding what a region *is* in data
  should precede drawing one.


## Q-05 — RESOLVED → `DECISIONS/0019` (2026-08-18): a new game's first authorised reconcile is retired; only later walking is spendable

*(Kept as raised, for the record.)*

### Q-05 — as raised: what should the first authorised sync of a *new* game bank?

**Raised:** 2026-08-18, Transformation Build 01 device finding (`MILESTONES/
TRANSFORMATION_BUILD_01.md` §7a). The owner's Phase 2 save was not present on
the phone (fresh container, `TOTAL WALKED 0`), so the 0018 cutover had nothing
to retire and the first authorised sync will grant the HealthKit 7-day
retention window as spendable — Phase 1's accepted new-player behaviour, but
not the "zero spendable at the playtest baseline" the owner intended for
*this* install.

Options, none taken: (a) accept — a new game's first week is its walking;
(b) an owner-authorised rule that a new game's first successful reconcile is
retired into history (a third epoch shape, needs its own decision and a
P-5 answer); (c) restore the Phase 2 save from a backup if one exists.
Not an accounting defect: H-2/H-3 hold either way.


## Q-06 — Combat Slice 01: what the first fights leave deliberately open

**Raised:** 2026-08-19, Playable Expansion 01 (`DECISIONS/0020`,
`GAME_BIBLE/COMBAT/02_COMBAT_SLICE_01.md`). The slice made the smallest set of
reversible choices that produce a playable fight. Each of these is a real
design question the owner's device play should answer before it is fixed:

- **Persistent HP and rest.** Every encounter starts at full HP; food matters
  only inside a fight. A carried-over HP would need a step-clocked recovery
  rule (never wall-clock) and a place to rest. Deferred until the fights are
  played.
- **A guard / brace action.** The Guardian telegraphs its heavy strike; today
  the player's only answer is to eat. If a second tactical action earns its
  place, "brace" (halve the next hit, deal none) is the candidate.
- **The driven-off rule.** ✅ **Answered by play → `DECISIONS/0021`
  (2026-08-19).** One victory per enemy per visit felt too restrictive on the
  phone; the limiter stays travel (any move clears the visit), but the count
  is now authored per enemy (`encountersPerVisit`: normal 2, boss 1).
  Whether a step-counted return should ever replace travel remains a play
  question, not a planned change.
- **Drops that duplicate gathering.** ✅ **Answered in part (World & Reward
  Depth 01):** the wolf now also drops a Wolf Pelt and the Frost Lynx a Frost
  Lynx Pelt — combat-only materials feeding two narrow smithing recipes
  (`GAME_BIBLE/COMBAT/02` §5, `GAME_BIBLE/SYSTEMS/08_ITEM_RARITY.md`). The
  goblin still drops ore (canonical, kept).
- **Enemy variants per region.** One step taken (World & Reward Depth 01):
  the Frost Lynx gives Frostmere its first encounter. Two per region remains
  a content target for later evidence.

---

## Q-07 — World & Reward Depth 01: the small choices the milestone left open

**Raised:** 2026-08-19, World & Reward Depth 01
(`MILESTONES/WORLD_REWARD_DEPTH_01.md`). Each was implemented one way so the
build could ship, labelled here so the choice is visibly provisional
(`RULES.md` G-3):

- **Uncommon below Common.** ✅ **RESOLVED — owner ruling, 2026-08-19:** the
  order and colour mapping are intentional and canonical — Uncommon = gray →
  Common = green → Rare = blue → Epic = purple → Legendary = orange, ascending
  in exactly this order. Recorded in `GAME_BIBLE/SYSTEMS/08_ITEM_RARITY.md`
  (the canonical home); `DECISIONS/0021` §4 stands as written. Not open to
  "conventional" correction. The remaining bullets below stay open for the
  device review.
- **Location kind words.** The atlas inspector says *Settlement · Wilds ·
  Worksite · Perilous*. "Perilous" is an adjective among nouns; the words are
  one enum line each (`lib/ui/screens/world/atlas/atlas_place_info.dart`) and
  belong to the Creative Director.
- **Landmark names.** *Millbridge*, *Ferry Crossing*, *Far Town* (future tier,
  drawn as "Far Town —") are the art stream's proposals, not World Designer
  decisions; the withheld east / south-east tiles carry *Old Watch*, *The Nine
  Stones*, *Drowned Harbour* the same way.
- **The multi-leg total cost.** The inspector quotes "By way of Stonefall Mine ·
  2,300 steps in all, 800 for the first leg". The total is a figure no button
  charges; it helps a player plan a week's walking, and it could read as a sum
  to save up in one go. Whether to quote it at all is the owner's.
- **Rarity in the inventory grid is colour-only.** The tile carries a rarity
  rule and the name in rarity ink, no word — `UNCOMMON` needs 72 dp where a
  393 dp × 1.4 cell gives 69. The word appears in the Equipped summary above
  the grid and on every full-width row elsewhere. Spelling it in the grid
  costs one column at large text scales.
- **The "future" landmark treatment.** A trailing em dash ("Far Town —") over
  a caption. Untested on a device; it may read as a truncation.
