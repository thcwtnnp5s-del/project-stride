# Art Direction

**Status: LOCKED — production art direction chosen.**
*Owner Direction Round 01 (2026-08-14), confirmed and extended at the UI Baseline
Closeout (2026-08-16), **amended 2026-08-31 by owner ruling —
`DECISIONS/0029_UI_ART_DIRECTION_AMENDMENT.md`** (see L-18).*

> The production art direction is **MODERNIZED POLISHED PIXEL MOBILE RPG**,
> implemented as **native high-DPI mobile UI, with pixel art as both framed
> content and — since `DECISIONS/0029` — the interface's own material**
> (panels, frames, surfaces, ornaments; never text, never a whole screen),
> with character presentation split across **portrait + simplified world/activity
> sprite + item/equipment icons**.

**A locked document is one that changes by decision, not one that never
changes.** The 2026-08-31 amendment went through the owner, is recorded in an
ADR, and replaced the superseded sentence in place with its previous text
preserved. Read L-18 before acting on anything in this file about chrome.

**A/B/C is closed.** Directions A, B and C were three treatments of a
single-canvas pixel screen. That premise was retired when the UI moved to native
widgets with real anti-aliased type, so the comparison no longer has a subject.
The A1/A2/A3 round and **L-11** are retired with it — not resolved,
**superseded**. The candidate descriptions below are kept as historical record.

**The locked direction does not lock any asset.** No character, environment,
icon, or palette is approved by this status. Several things remain explicitly
open — see *UNRESOLVED* below, which is shorter than it was but is not empty.

An agent reading this file for a value it does not contain must **stop and ask**
rather than infer one. See `RULES.md` G-3.

---

## Current design intent

Settled enough to constrain the exploration:

- **2D-first**
- **Pixel-art leaning**
- **Not restricted to literal 8-bit limitations** — historical hardware
  constraints are not a design goal
- **Mobile readability is critical** — the phone is the only target, and a
  sprite that reads on a desktop monitor may not read in a hand
- **Strong silhouettes** — readable at small size, in motion, and against busy
  backgrounds
- **MMO-inspired world and progression feel**
- **Modern polish is allowed** — lighting, effects, and finish are not capped by
  the pixel-art idiom
- **AI-assisted asset production is acceptable**
- **Consistency and a style guide outrank one-off visual novelty** — a
  beautiful asset that does not match the set is a defect

---

## Candidate directions

Three deliberately distinct treatments. **None is preferred, and none is
eliminated.**

### A — Classic Pixel MMO Lite

The traditional pixel MMO register: readable, familiar, economical to produce,
and honest about being a sprite game.

### B — Modern Premium Pixel Fantasy

Pixel foundations with contemporary finish — richer lighting, more animation
weight, higher effective detail while keeping the pixel identity.

### C — Stylized 2D Fantasy

Illustrative rather than pixel-based. Shapes, linework, and colour do the work
that pixel density does in A and B.

---

## Exploration rule

> **For major visual systems, compare 2–3 deliberately distinct treatments
> before locking a production direction.**

"Deliberately distinct" is the operative phrase: three variations on one idea
compare nothing. The candidates must be far enough apart that choosing between
them is a real decision.

Comparisons must hold **subject and composition constant** so the comparison is
about art direction rather than about which image happened to be better staged.
The canonical comparison scene for the first exploration is defined in
`PROJECT_STATE.md` under *Project Stride Visual Exploration 01*.

---

## Locked — Owner Direction Round 01

**Date:** 2026-08-14 · **Ruled by:** owner, on the evidence of
`VISUAL_STUDIO_BASELINE_AUDIT_01`

Each lock below closes a question that was previously UNRESOLVED. Changing one
requires the owner, not a specialist and not an implementation convenience
(`RULES.md` G-3, `STUDIO_OPERATIONS/CHANGE_MANAGEMENT.md`).

### Character

**L-1 — The Traveler reads as a masculine-presenting ordinary capable traveller.**
Practical, grounded, capable, approachable, road-worn enough to belong in the
world, and visually interesting enough to carry being on screen constantly.

**Excluded, explicitly:** heroic power pose · bulky fighter silhouette ·
exaggerated or chibi proportions · premium or fantasy ornament · an armoured
appearance while wearing starter clothing · MMO raid-character visual language.

**L-2 — Figure family is approximately 1 : 4.5 head-to-body.**
The exact pixel construction stays an implementation question. **The character
must not be widened or enlarged to make current equipment fit** — that is an
allocation problem, not a proportion problem. The existing head family is the
strongest part of the work so far.

**L-3 — SUPERSEDED (2026-08-16). The character canvas is not set.**
The single-asset premise this lock belonged to is retired: character presentation
is now split across portrait, world sprite and item icons, and those are three
different canvases. **No replacement figure is recorded**, because the portrait
workstream is paused with no approved canvas
(`GAME_BIBLE/ART/exploration/CHARACTER_PORTRAIT_CLOSEOUT.md`).
`CHARACTER_READ_SPEC_01.md` remains frozen as historical evidence and governs
nothing. The original text is preserved below for its reasoning.

> **L-3 (original) — The character canvas is 24 × 34 for the next attempt.**
> The audit's measured **26 columns needed against 24 available** is evidence that
> the *current arrangement* is over budget, not that the canvas must grow. The
> designer solves silhouette allocation first. In particular: **equipment must not
> consume the same chest-height horizontal band as both arms** — the shared defect
> behind every failed read in the audit.
>
> The canvas may be reopened **explicitly** if an approved READ SPEC demonstrates
> that the locked equipment inventory physically cannot read inside 24 × 34.

**L-4 — Starter equipment is locked: a small canvas backpack, and a Training
Sword sheathed at the character's LEFT hip. Hands empty.**

Under the established near/far chain (`PIXEL_ART_CRAFT_SPEC.md` CR-3) the figure
turns toward the viewer's right, so **the character's left hip is the NEAR side
and renders on the viewer's right**. Every blind report in the audit described
the hip object as being on the viewer's right, so its *position* has been correct
throughout — the failure is semantic, not placement.

Neither item may be removed or substituted because current sprites fail to
communicate it. **The design solves the semantics.** A blind viewer must answer,
with no source explanation:

| Question | Required answer |
|---|---|
| What is on the back? | a small travel backpack |
| What is at the hip? | a sheathed sword |
| What is in the hands? | nothing |

**The read contract that implements L-1 … L-5 is
`GAME_BIBLE/ART/CHARACTER_READ_SPEC_01.md` — FROZEN 2026-08-14.** It owns the
character read requirements, the approved gesture (a *settled asymmetric hang*),
the design architecture (*separate loads by height, not by side*; *occlusion over
adjacency*), and the pass/fail gate. It is not duplicated here (`RULES.md` G-7).

**L-5 — No trademark visual signature is locked, deliberately.**
Recognisability must be earned through proportion, gesture, clothing shape,
equipment relationship and restrained colour placement **before** any decorative
mark is considered. No scarf, emblem, feather, or ornament may be added merely to
make the character memorable. See `JOURNAL/OPEN_QUESTIONS.md` Q-02.

### Environment

**L-6 — The Haven's Rest palisade reads at approximately 1.5× visible standing
person height.** A visual target with reasonable low-resolution tolerance, not an
architectural measurement. The required read is a **defensive settlement wall** —
not a garden fence, and not a fortress curtain wall. A standing NPC must visibly
fit beneath it with clear headroom. *(The audit measured the current wall at 82%
of the NPC beside it.)*

**L-7 — Haven's Rest must visibly imply continuation behind and beyond the gate.**
The viewer must understand that **the gate leads somewhere**. Method is the
Environment Pixel Artist's design: ground continuing inward, partial structure
depth, overlapping architecture, openings already compatible with the scene
inventory, or glimpsed settlement space.

**Interiority is spatial. It is not authorisation to invent content** — no new
props, NPCs, merchants, quests, shops, or gameplay objects.

**L-8 — Three meaningful ground and depth planes: FAR, MID, NEAR.**
Not six nearly indistinguishable bands, and not necessarily three flat horizontal
stripes. Expressible through value, clustering, overlap, terrain density, or
controlled palette relationship — **provided they clearly read at ×2** (CR-45).

This is **shared world grammar**. No identity treatment may own basic depth
readability. *(The audit found two planes reading where six were authored.)*

**L-9 — The settlement perimeter reads as angled / cornered, not as one long
frontal wall.** The wall must communicate that it **encloses space** rather than
acting as a stage backdrop. The provisional **three-quarter top-down /
isometric-lite** camera family is preserved; this is not a conversion to strict
isometric.

**L-10 — The roof ramp may be re-valued as part of Haven's Rest Base 02.**
The audit measured roof-mid against palisade at roughly **Δ2.5 luminance**, so the
two masses collapse despite the roof ramp existing specifically to separate them.

This authorises **correcting that ramp relationship only.** It is not
authorisation to redesign the palette, introduce premium lighting, add palette
steps, or add atmosphere for richness. **CR-45 decides:** the render determines
whether roof and palisade are perceptually distinct at ×2.

### Comparison

**L-11 — RETIRED (2026-08-16), not resolved.**
The A/B/C comparison was three treatments of a single-canvas pixel screen. That
premise was retired when the UI moved to native widgets with real anti-aliased
type, so the round this lock schedules **no longer has a subject**. The evidence
stays preserved as historical exploration. Original text below.

> **L-11 (original) — The A1 / A2 / A3 round must be re-run on the corrected
> shared base.**
> The current round is **not ranked and no winner is selected**, because its
> substrate carries shared failures in architecture, road topology, depth, smoke,
> background, character and UI semantics — so it compares identities against a
> foundation that is itself failing. Preserve the current round as historical
> exploration evidence.

### UI

**L-12 — SUPERSEDED FOR UI (2026-08-16). Retained for the world.**
The interface is native Flutter at device resolution, so **no UI pixel grid
exists** and a UI-density ratio no longer describes it. The world figure keeps a
pixel canvas. Review enlargement stays nearest-neighbour.

> **L-12 (original) — 2× UI density is the working presentation direction.**
> World **128 × 192**; UI and composite working grid **256 × 384**. Coarse UI is
> not an equal candidate and is not reopened. Final device-resolution
> implementation is a separate question.

**L-13 — `90` on the gather card must read unambiguously as the action's cost**,
in the game's existing step-derived energy language.

Only the semantic clarity of `90` is reopened — **not** the card's information
architecture, which still communicates the existing action (Meadow Herb, yield
×2, cost 90, +10 XP). The designer may use the already-established energy visual
language. **No new currency, coins, timers, cooldowns, durability, or additional
resource may be invented.** Everything else in the card stays presumptively
frozen unless Visual QA finds an objective blocker after the correction.

**L-14 — `1,240` is a thousands-separated integer and must not read as `1.240`**
at native or ×2. **Number formatting must not be changed to avoid fixing the
glyph.** The minimum bitmap-comma change is permitted; **Visual QA decides**
whether the result reads as a comma. A correctness fix, not a UI-direction
exercise.

**L-15 — No UI icon may imply a semantic the game does not have.**
Project Stride does not use wall-clock progression (`RULES.md` P-4), so **an icon
that reads as a timer or hourglass is objectively unacceptable** regardless of
identity treatment — which makes the current A2 crafting icon a defect, not a
preference. The energy icon must read as energy in the established language, and
crafting must read as crafting. **An icon may not change referent across identity
treatments.** A craft and semantics requirement, not an A1/A2/A3 comparison
input.

---

## Locked — UI Baseline Closeout (2026-08-16)

**L-16 — Teal `#58d6c0` is reserved system-wide for walking, steps, and
banked-step quantity.**
No character, environment, item, or interface element may use it as an identity
accent or for any other meaning. It is deliberately not gold: a gold numeral
beside a glyph reads as currency, and Stride has none (`RULES.md` P-6).

**L-17 — Inventory is icon-first for scanning; icon + label + count is the
complete semantic unit.**
The player's eye sorts the grid by silhouette, shape, major colour and category
before reading names; the label removes remaining ambiguity. An icon is **not**
required to be blind-nameable at grid size — mere vagueness is acceptable.

An icon that confidently implies the **wrong object**, or any system Stride does
not have — currency, rarity, a timer, capacity, a lock — **is a defect regardless
of craft quality**. This extends **L-15** from "no wrong semantic" to "wrong
semantic is a blocker, vagueness is not", which is the distinction that governs
icon acceptance.

**L-18 — Every pixel asset is displayed at an exact integer multiple of its
native size, with nearest-neighbour filtering and no sub-pixel positioning, in a
container that layout cannot compress.**
**Interface chrome may be authored pixel art. Text, layout, measurement, state
and interaction are never raster.**

The container clause is load-bearing and was earned: a container one pixel
narrower than its pixel content silently rescales a sprite with no visible cause,
which cost three wrong diagnoses before it was measured.

**Amended 2026-08-31 by owner ruling — `DECISIONS/0029`.** This rule previously
ended: *"Interface chrome — type, panels, borders, radii, tracks — is ordinary
high-DPI native rendering. The interface is not pixelated; the content is."*
That sentence settled a **typography** question — the single-canvas pixel screen
retired at the UI Baseline Closeout, where a bitmap font fought real
anti-aliased type — and was then read as a permanent ban on interface
*material*. The owner has ruled the wider reading superseded: PixelLab may
author panel and frame art, headers, material surfaces, borders, dividers,
reward and combat frames, craft, inventory and board treatments, and restrained
backplates.

The first paragraph is untouched and now governs **more** assets, not fewer.
The boundary that replaces the old sentence:

- A raster asset may occupy only a panel's **outer edge** (corners at 1:1,
  edges **tiled** — never stretched, so `centerSlice` is out), a panel's
  **interior as a low-variation tiled surface**, or a **discrete ornament**
  Flutter positions.
- It may never carry a word, a number, a state, or a boundary Flutter must
  measure. **Text is never pixelated.** Whole screens are never raster.
- One chassis family app-wide. Screens differ by band, surface and picture —
  never by eleven different borders.
- **The enforcing test:** with every frame asset removed, the app must still
  lay out, read, navigate and pass its accessibility assertions. Art may change
  how Stride feels; it may never change what Stride does.

**L-15, L-16 and L-17 are unchanged and bind interface art too:** an icon may
not change referent, a wrong semantic is a blocker, and `#58D6C0` remains
walking's alone. A frame that reads as a slot, a lock, a coin or a capacity
meter is refused on semantics however well it is drawn.

**L-19 — Bronze content reads as bronze, not as gold bullion.**
Bronze uses a bronze / reddish-copper family, not a bright worked-gold family. A
banded gold trapezoid is the universal bullion glyph and asserts a currency
Stride does not have. Owner ruling, 2026-08-16. Not a Phase 1 blocker.

---

## UNRESOLVED — do not decide silently

None of the following has been chosen. They are listed so their absence reads
as **deliberate** rather than as an oversight to be helpfully filled in:

- **Palette** — no colours, ramps, or restrictions are set. **L-10 authorises one
  corrective re-value of the roof ramp and nothing else**; the palette as a whole
  is untouched and remains open
- **Animation frame counts** — no frame budget per action is set
- **Exact rendering treatment** — outlining, dithering, shading model, and
  lighting approach are all open
- **The character's recognisable signature** — deliberately deferred until
  proportion, gesture and clothing have been given the chance to earn it
  (**L-5**, `JOURNAL/OPEN_QUESTIONS.md` Q-02)
- **Character portrait styling, proportions, and canvas** — the workstream is
  **paused**, not solved. `CHARACTER_PORTRAIT_CLOSEOUT.md` §6 lists what a future
  restart must **not** inherit; canonizing any of the current geometry would hand
  a restart exactly that. The portrait in use is a **temporary placeholder**
- **The Hollow Sigil** — its four wrong reads (lock, slot, empty cell, coin) have
  been cleared structurally, and **no positive read is established**. This is a
  **content** question, not a craft one: nothing in the repository describes what
  a Hollow Sigil is beyond a tier-1 quest item from Forgotten Hollow, and an icon
  cannot depict an undescribed object. Owner ruling D-3 (a literal open
  negative-space centre) conflicts with clearing the "slot" read and is **not
  resolved**
- **The full inventory icon set** — icon *policy* is locked (**L-17**); the set
  itself is not approved. Four icons still produce confident wrong nouns at play
  scale, and the set is incoherent in ramp depth and icon mass
- **Environment and Haven's Rest** — untouched by this update and still governed
  by **L-6** to **L-10**. The travel map is not started

**The production art direction itself is no longer on this list** — see the
status block. **L-11** is retired with the A/B/C premise.

A candidate direction may *propose* values for these during exploration. A
proposal inside a comparison is not a decision, and does not become one by being
the only one written down.

### Closed by Owner Direction Round 01

Formerly on the list above, now ruled. Recorded so a future session does not
reopen them as if they were still absent:

| Was unresolved | Now |
|---|---|
| Sprite dimensions | **Reopened by the presentation split.** L-3 and L-12's UI figure are superseded; world keeps **128 × 192**. Portrait, icon and tile canvases are unstated |
| Camera angle | **Three-quarter top-down / isometric-lite**, preserved as a family; not strict isometric (**L-9**) |
| Exact character proportions | **≈ 1 : 4.5** head-to-body (**L-2**); exact pixel construction still an implementation question |
| Final UI visual language | **Reopened and re-closed by `DECISIONS/0029` (owner ruling, 2026-08-31): authored pixel chrome IS permitted** — panels, frames, surfaces, ornaments; never text, never a whole screen. Otherwise closed at the direction level: pixel content, teal = walking (**L-16**), icon policy (**L-17**), scale discipline (**L-18**). The *token values* — palette, exact type scale, spacing — are proposed in `exploration/WALKSCAPE_PIVOT_01/UI_SYSTEM_PROPOSED_01.md` and are **not** canonized here |

### Closed by the UI Baseline Closeout (2026-08-16)

| Was open | Now |
|---|---|
| The production art direction (A/B/C) | **Chosen** — modernized polished pixel mobile RPG, native high-DPI UI + pixel content. A/B/C and **L-11** superseded, not resolved |
| Whether the UI is authored on a pixel grid | **Partly, since `DECISIONS/0029`.** Layout, text and interaction stay native widgets at device resolution (**L-12** superseded for UI); a panel's frame, surface and ornaments may be authored pixel art on the integer-scale grid (**L-18** as amended) |
| Character presentation as one asset | **No.** Split into portrait / world sprite / item icons (**L-3** superseded) |
| What teal means | **Walking and steps, system-wide, exclusively** (**L-16**) |
| Whether inventory icons must be blind-nameable | **No** — but a wrong read is a blocker (**L-17**) |

---

## Related

- `GAME_BIBLE/ART/templates/EIGHT_DIRECTION_CHARACTER.md` — the reusable
  character-view production template
- `GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md` — UX structure and navigation
- `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md` — the subjects the first
  comparison depicts
- `PROJECT_STATE.md` — Visual Exploration 01 scope and canonical scene
