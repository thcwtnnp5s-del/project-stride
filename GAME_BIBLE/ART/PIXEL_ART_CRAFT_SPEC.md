# Pixel Art Craft Spec

**Status: EXPLORATION — WORKING CRAFT SPEC.**

Not a production-art lock. Nothing here chooses an art direction, a palette, a
sprite size, or a camera. It records **how to execute pixel art well at pixel
level**, learned by doing it and getting it wrong first.

---

## 0. What this document owns, and what it does not

**One canonical home per concept** (`RULES.md` G-7). This document and
`ART_DIRECTION.md` are deliberately not about the same thing:

| Document | Owns |
|---|---|
| `GAME_BIBLE/ART/ART_DIRECTION.md` | **What Project Stride should look like.** Direction, candidates, and the list of properties that must stay UNRESOLVED. **Still EXPLORATION. Unchanged by this document.** |
| **This document** | **How to draw it competently once you sit down to draw.** Craft, cluster grammar, failure modes, review procedure |

A rule here never decides a direction question. Where this document names a
value — a sprite height, a palette size, a grid — that value is **provisional**
and does not become the project's value by appearing here (`RULES.md` G-3;
`ART_DIRECTION.md` — *UNRESOLVED*).

**Provenance.** Every rule below was paid for. Rules cite the failure that
produced them, because a rule with no failure behind it is a preference.

| Source | Paid for |
|---|---|
| `exploration/CODE_RENDER_01/` — the Traveler / Meadow Herb / gather-card proof and its five recorded passes (Pass 1–3, Owner Refinement 01–02) | §2–§6 — character, cluster, node and UI craft |
| `exploration/HAVENS_REST_BASE_01/` — the first full-world scene and its three recorded passes | **§5A — environment craft**, CR-39, and the CR-14/CR-18 escalations |
| **`VISUAL_STUDIO_BASELINE_AUDIT_01`** — the first multi-agent specialist and blind-QA audit of the Traveler, Haven's Rest and the UI | **§8 — the standard output set**, CR-42, CR-43, CR-44, CR-45 |

**How to use it.** Read §1 and §7 before drawing. Work through §2–§6 — including
**§5A** when the subject is environment — while drawing. Run §7 and §8 before
calling an asset done. It is a checklist, not a theory.

---

## 1. The core principle

> **PIXEL ART IS THE CONSTRUCTION METHOD, NOT A FILTER.**
>
> **THE SAME STYLE, DRAWN BETTER.**

Every improvement across five passes came from **moving or re-valuing existing
pixels**. Not one came from more resolution, more detail, more colours, or more
rendering. The Owner Refinement 02 head was fixed with six pixels; the entire
lateral-readability problem was fixed with **one**.

**CR-1 — Quality comes from placement, never from quantity.**
When an asset is not working, the first question is *which pixels are in the
wrong place*, never *what could I add*.
*Prevents:* resolution creep, detail creep, palette creep, and the slow drift
into premium-pixel rendering that `VISUAL_SAMPLE_GENERATION_01.md` §14.3 already
rejects.

**CR-2 — Do not improve successful work.**
An asset that reads is finished. The gather card was right at Pass 2 and was
frozen for three subsequent passes.
*Prevents:* a working asset getting worse because another iteration was
available.

**CR-41 — A technically correct pixel change is not a successful visual change
unless the intended improvement is perceptible at target viewing scale.**

**Source intent gets no credit.** Not a variable named `PACK`, not a comment
saying `SWORD`, not an author's change list, not a pixel count, not a passing
assertion. The rendered image is the entire evidence base, because it is the only
thing a player receives.

Two working consequences:

- **Judge at the scale the player meets the asset.** ×8 is the working view and
  never the verdict view — it flatters everything. A read that holds at ×8 and
  fails at ×2 has failed. §8 step 2a is where this is enforced.
- **The author of a change may not be its only judge.** An author reads its own
  intent back out of the image and cannot help doing so. Independent perceptual
  review is canonical in
  `STUDIO_OPERATIONS/AGENT_ORCHESTRATION.md` — *Visual Studio*.

*Prevents:* the failure recorded in `MISTAKES.md` M-04 — three consecutive
Traveler passes whose corrections were defensible in source, reported as fixes,
and invisible to the owner.

*This rule outranks every other rule in this document.* A change that satisfies
CR-3 through CR-40 and cannot be seen has still failed.

**CR-42 — Comments and identifiers describe intent. The pixels determine whether
that intent exists.**

CR-41 says source intent earns no credit at review. CR-42 is the authoring-side
consequence: **a label creates an obligation on the pixels, not a property of
them.** Naming a cluster `SCABBARD` does not make it leather; it commits you to
drawing something that reads as leather, and until you do, the name is a claim
the image does not support.

The failure mode is specific and it is not carelessness — it is a label and a
material ramp drifting apart while each stays individually defensible:

- A cluster commented `scabbard` whose legend characters resolve to the **metal**
  ramp is **a bare blade**, and a reader who has the source is told "scabbard"
  before looking. Use material and value logic appropriate to leather, wood, or
  cloth — unless the design explicitly specifies a metal sheath.
- A map named `PACK` whose rendered silhouette reads as a pauldron, a crate, or a
  shield is not a pack, and renaming it changes nothing.
- Smoke drawn in the sky's own palette index **is not present in the image**, no
  matter how complete the plume is in source (see CR-44).

Two working consequences:

- **When a label and a render disagree, the label is the defect.** Fix the pixels
  or withdraw the claim. Never leave both standing.
- **Semantic labels in source are review contamination** (`MISTAKES.md` M-04).
  They are legitimate authoring aids and they are why blind staging exists — the
  critic must meet the render, never the vocabulary.

*Prevents:* the Traveler hip object, commented `scabbard` through three passes,
authored in `IDX.metal`, and independently read as a hatchet, an axe head, an
adze, a trowel, and a mug by four separate blind readers.

---

## 2. Character craft

### 2.1 Three-quarter orientation

**CR-3 — A sprite has one near side and one far side, and every part must agree.**
Decide which side is near **before drawing anything**, then hold it in the head,
shoulders, arms, hips, legs, feet, pack, and every piece of equipment.

For the canonical Traveler the chain is: the figure turns toward the viewer's
right, therefore the **character's left hip and its sword are NEAR (viewer-right)**
and the **back rotates away on the FAR side (viewer-left)**, which is why the pack
peeks there.

*Prevents:* the Pass 1–3 failure — a frontal figure with three-quarter equipment
attached afterwards. It read as a mannequin because the parts disagreed.

**CR-4 — Depth is bought with tiny differences, and you do not need all of them.**
Any two or three of: shoulder height, shoulder width, value, overlap, limb
length, foot landing row, head silhouette.

In OR01 the whole turn was carried by three: the **far shoulder existing one row
before the near one**, the legs using different trouser steps, and the **far foot
planting one row above the forward near foot**.

*Prevents:* over-drawing the rotation, which at 32 px turns into distortion.

**CR-5 — Near reads lighter or larger; far reads darker or smaller.**
Where depth separation and the baked light direction disagree, **depth wins** if
the asset would otherwise be unreadable. Say so when you make that call.

### 2.2 Pose and gesture

**CR-6 — Low resolution does not excuse mechanical symmetry.**
Even a calm idle contains deliberate asymmetry. One pixel can carry gesture.

Sufficient on its own, in rough order of value: a shoulder offset · a near/far
leg distinction · unequal foot landing rows · a small head turn · differing arm
termination rows.

*Prevents:* mirrored legs, identical boots, parallel arms, the centred
mannequin — symmetry that exists only because it was easier to code.

**CR-7 — One diagonal outperforms any amount of texture.**
The single highest-value change in the whole proof was OR01's **pack strap: five
pixels running diagonally across the chest**. It broke the slab, implied the
turn, and made the figure look like someone carrying something — all at once.

*Prevents:* reaching for surface detail when the real problem is that nothing
crosses the form.

### 2.3 Torso and clothing

**CR-8 — Clothing implies a body underneath. Fix silhouette before interior.**
The order is: **shoulder taper → waist → belt pinch → subtle lower flare.**
Exhaust that before adding a single interior pixel.

*Prevents:* the rectangular torso slab, uninterrupted colour masses, perfectly
vertical garment sides.

**CR-9 — Interior clusters are expensive. Spend at most one, and make it describe form.**
A fold, hem shadow, or collar notch earns its place only by communicating
shape. OR02 spent exactly one — a **two-pixel off-centre fold**.

*Never* add cloth texture to make a garment feel finished. Restraint is the
identity, not a budget compromise.

### 2.4 Head and face

**CR-10 — Charm at this scale comes from silhouette, not from features.**
In priority order: head silhouette · hair silhouette · eye placement · jaw and
chin shape · neck relationship · orientation. **Two eye pixels are enough when
they are placed well.**

OR02 fixed a bland head with six pixels: crown shifted back, hair carried down
the far side, jaw receded, chin pointed toward the turn.

**CR-11 — A turned head needs a back of skull, and the far eye is compressed.**
Carry the hair mass down the **far** side and let the far eye sit tight against
the hairline. This is the cheapest and strongest three-quarter cue available.

*Prevents:* the symmetrical cap-like hair of Passes 1–3, where the head read as
a flat disc with a face on it.

**CR-12 — Watch the opposite failure: a face swallowed entirely by hair.**
CR-11 taken too far leaves no readable face plane. Both are failures; the target
is a head that has a front *and* a back.

Never add features because empty pixels remain. No portrait detailing. No
anime or chibi conventions unless explicitly chosen later — they are not chosen.

### 2.5 Arms and hands

**CR-13 — An arm must read as shoulder → arm → hand, and value alone can do it.**
Literal anatomy is not required and does not fit. **Three values down one
column** — shaded upper arm, lit forearm, skin hand — implies articulation with
zero extra width. That is what OR02 used.

*Prevents:* the Pass 2 failure where full-height light and dark columns read as
**suspenders**, and the Pass 1 failure where ink-coloured separation columns read
as **slots punched through the torso**. Separate a limb with *shading*, never
with a hole.

**CR-14 — Hands must terminate the limb, and must not vanish into the garment.**
Check the hand's value against whatever it sits on. A hand the same value as the
sleeve is not a hand.

### 2.6 Equipment attachment

**CR-15 — Equipment must look worn or carried, not pasted beside the sprite.**
- **Pack** — readable body silhouette, an understandable overlap *behind* the
  torso, a strap when the attachment would otherwise be unexplained, and a
  flap or seam only when it helps the read.
- **Sword** — the grip originates at the **belt line**, the guard belongs to the
  **hip**, the blade hangs from that attachment. Proportionate and practical; a
  short plain sword is not a heroic weapon.

**CR-16 — Break accidental tangencies. This is worth more than it sounds.**
Where two objects of similar value touch, they merge into one unreadable mass.
**A single outline pixel between them fixes it.**

In OR02, hand and crossguard shared a row and read as one confusing shape. **One
pixel of outline at x16 turned an ambiguous lateral mass into four immediately
readable objects: body, arm, pack, sword.** It is the single best pixel spent in
the entire proof.

Watch specifically for: hand + guard · pack + arm · sword + torso · boot +
trouser.

**CR-17 — A value break separates adjacent similar masses.**
The Pass 3 boots stopped merging into the trousers the moment a **light cuff row**
was introduced at the boot top.

---

## 3. Cluster grammar

**CR-18 — Clusters are connected and purposeful. An isolated pixel needs a reason.**
*Prevents:* the herb defect — a **one-pixel-wide outlying blade** that read as
specks at review scale and had to be removed.

**CR-19 — Organic forms use deliberate irregularity, never mirrored geometry.**
A symmetrical fan reads as procedural output. Vary tip heights, let one element
break the canopy line, offset the centre.
*Prevents:* the Pass 2 herb, which was technically correct and read as a
generated diagram.

**CR-20 — Silhouette pixels are worth more than interior pixels.**
Spend on the outline before spending on the inside. If an asset is not reading,
the silhouette is the first suspect.

**CR-21 — One excellent pixel beats four explanatory ones.**
If a cluster needs several pixels to say what it is, the shape underneath is
probably wrong.

**CR-22 — Diagonals should form readable stair-step rhythms.**
Even, deliberate steps. Not ragged, not perfectly regular where a form is
organic.

**CR-23 — Interior value clusters describe form. They never describe texture.**

---

## 4. Value and palette

Direction A's rendering floor is canonical in
`DIRECTION_A_IDENTITY_VISUAL_SAMPLES_01.md` §3 and §7 and is not restated here.
Craft consequences only:

**CR-24 — Structured three-step ramps. No glow ramp, no specular ramp, no
cinematic highlight ramp.** A palette that cannot express glow cannot leak it.

**CR-25 — Reserve the highest-saturation, highest-contrast band for interactables.**
If terrain or foliage borrows that band, the gameplay-important object stops
winning the frame.

**CR-26 — Value is a depth tool as well as a lighting tool** (see CR-5).

**CR-44 — An element must not be drawn in the palette index of the region it is
drawn against, where that makes the intended form disappear.**

This is **not** a demand for high contrast everywhere. Quiet, close-valued work is
the identity, and CR-24's restraint stands. The requirement is narrower and
absolute: **the form you intended must survive into the image.** An element that
cannot be distinguished from its own background has not been drawn — it has been
described in source.

Watch for it wherever an element crosses from one region into another, because a
value that separates cleanly over one region can vanish over the next:

- smoke drawn in the sky's own index
- a cloud edge equal to the sky
- a distant structure equal to the treeline
- a path equal to the meadow it crosses

The most dangerous case is the **partial** one, because it does not look like a
palette error — it looks like a drawing error. A plume drawn in the sky's index
that crosses from sky to grass renders **only over the grass**, and reads as a
line that starts nowhere and stops for no reason.

*Prevents:* the Haven's Rest chimney plume, authored complete in source at
palette index 51 — the lower sky band's own index — so that more than half its
length was literally unrenderable, and every blind reader's first call on the
surviving fragment was *a rendering glitch* or *a dead pixel column*.

**CR-45 — Adjacent materials that must communicate different objects, or
different depth planes, must not collapse into one mass at ×2.**

Judge it at the verdict view, on the render (CR-41). **The render decides** — this
rule deliberately names no luminance threshold, because a number would be obeyed
where it is cheap and would not describe what a viewer sees. Reduce the frame to
greyscale if you need a check: a boundary that must carry meaning and disappears
under that test is the finding.

Two failure classes, and the second is the one that gets missed:

- **Within the asset** — skin against tunic, boot against trouser, pack against
  arm. Each of these is already a named case (CR-14, CR-16, CR-17).
- **Between the asset and the world it stands in.** A character's equipment is
  reviewed against its own tunic and shipped against grass and dirt. Solving
  "the pack is too bright to be a pack" by darkening it can walk it directly into
  the ground ramp, where it stops being a shield and starts being nothing.

Where separation is required, **the isolated view cannot certify it.** Both the
isolated ×2 and the true in-context view must show it holding (§8).

*Prevents:* the Haven's Rest roof and palisade authored as separate ramps for the
stated purpose of unmerging the settlement, and set two-and-a-half luminance
steps apart, so the settlement went on reading as one mass; the main path and the
meadow three steps apart, so the frame's largest compositional line vanishes in
greyscale; and the Traveler's pack darkened away from the tunic to within five
steps of grass and two of dirt.

**The current 49-entry proof palette is PROVISIONAL and is explicitly NOT
canonized.** Palette remains UNRESOLVED in `ART_DIRECTION.md`.

---

## 5. Resource node craft

What made the Meadow Herb work, in the order it mattered:

**CR-27 — Silhouette first.** The node is recognised as a shape before it is
recognised as a plant.

**CR-28 — One dominant read, one clear footprint.** A single root or contact
point anchors it to the ground and stops it floating.

**CR-29 — Distinct from ordinary terrain by palette and silhouette alone.**
**No glow, ever.** Separation is achieved by being one step up in saturation and
contrast, not by emitting light.

**CR-30 — Deliberate but restrained asymmetry** (CR-19), and **limited detail**.
The working herb uses six palette entries.

*Avoid:* botanical illustration · mirrored procedural fans · detached blade
pixels · decorative specks.

---

## 5A. Environment craft

**Numbered 5A so §6–§11 keep their existing numbers.** These rules were paid for
by `exploration/HAVENS_REST_BASE_01/`, the first time the pixel language had to
carry a whole world screen rather than three isolated assets. Every one of them
is a defect that an isolated sprite review structurally could not have found.

**CR-35 — A ground feature never receives a lit top edge.**
A path or a road is a surface **in** the ground, not a strip laid **on** it.
Build it from body value plus a restrained edge treatment — at most one dark
edge on the far side. The moment the near edge is lightened, the band acquires a
top face and becomes geometry.

*Prevents:* the Base Scene Pass 1 failure — both roads were drawn with a light
first row and a dark last row, and read unmistakably as **timber rails**, a
fence, a platform, a raised strip. Nothing else in that pass was as wrong, and
nothing else was as cheap to fix.

**CR-36 — A roof needs enough wall mass beneath it to read as architecture.**
The building band under the eave must sit **just inside** the eave line. A
narrow stem under a wide overhang is a mushroom, not a house, no matter how
well the roof itself is constructed.

*Prevents:* Base Scene Passes 1 and 2, where three correctly built roofs read
first as **tents** (pitch too steep, no wall at all) and then as **toadstools**
(wall present but inset far too much). The roofs were never the problem.

**CR-37 — CR-18 applies at environment scale, and it is stricter there.**
Grass fringes, scrub, terrain overlays and field variation must be **purposeful
clumps on a continuous base**. Never build a terrain accent from disconnected
one-pixel elements, and never place scatter procedurally.

At sprite scale an isolated pixel is a defect. Across a whole frame it is a
**field of them**, and quiet terrain becomes procedural noise — the one thing
the rendering floor most needs the ground not to do.

*Prevents:* the Base Scene Pass 1 grass fringe, authored as single-pixel blades,
which read as a dotted line of specks; and the field variation, authored as
two-row dashes, which read as smudges rather than as ground.

**CR-38 — A directional object must visibly encode direction.**
Level, symmetric arms collapse into generic symbol geometry. A small vertical
offset, a stepped silhouette, or a tapered tip is enough — and costs a handful
of pixels.

*Prevents:* the Base Scene signpost, whose two arms were horizontal and equal
through Passes 1 and 2 and read as a **plus sign** on a pole. One row of step
per arm turned it back into a signpost.

**CR-43 — Every visible end of a route must have a readable reason.**

A road, path or track is a claim that places connect. Both of its visible ends
have to answer *why does it stop here* from the image alone.

**Permitted terminations** — each is a reason a viewer can see:

- it leaves the frame
- it passes through a gate, door, or other aperture
- it is occluded by something in front of it
- it meets another route at a junction
- it arrives at a visible destination

**Forbidden** — each reads as an unfinished map rather than as a world:

- beginning in arbitrary open terrain
- terminating against a solid wall with **no aperture** — worse than a floating
  end, because it is legible enough to be recognisably wrong, and it implies a
  door that was never drawn
- stopping for no readable reason at all

Occlusion has to actually occlude. A route end tucked *near* scrub is not
occluded by it — check the rows, not the intention.

**This is a visual rule and it is not the route inventory.** How many routes a
scene has, and where they go, is world and gameplay canon. CR-43 governs only
whether the ends of the routes that exist are drawn so a viewer can read them; it
never authorises adding, removing, or re-planning a route to solve a composition.

*Prevents:* the Haven's Rest road network — a right-hand road ending bluntly in
open grass five pixels clear of the settlement with nothing occluding it, a
left-hand road running into unbroken palisade where no gate exists, and three
routes sharing **zero junctions** — which blind readers named *unfinished
terrain*, *missing map chunks*, and *roads whose destination failed to load*.

---

## 6. UI craft

The gather card succeeded on its first attempt and needed only a spacing fix.
Geometry is this pipeline's strongest domain — lean on that.

**CR-31 — Chunky geometric construction, disciplined bitmap typography, clear
hierarchy, generous spacing, restrained framing.**
Give text a real margin from the frame; the only card defect ever found was a
bottom row crammed against its border.

**CR-32 — A UI icon should echo its world asset's silhouette family.**
The card's herb icon is built from the node's own shape language, which is why
interface and world read as one product.

**CR-33 — Construction lines, not shines.** A bevel or engraved seam describes
how the panel is made. It is not a highlight.

**CR-34 — Judge UI at native scale first.** Typography either works at native
resolution or it does not; an upscale flatters it.

**CR-39 — A UI element sized for its own canvas is not sized for the frame.**
An interface asset judged alone will be judged against its own border. Judged in
the world screen it is judged against the frame width, and against the space its
strings actually need. Re-fit it in context; that is an integration adjustment,
not a redesign, and it does not reopen the visual language.

*Prevents:* the Base Scene gather card, correct at 36 × 24 in isolation and
visibly undersized against a 128-wide world frame — where the right-aligned
`+10 XP` had no room for its own space and silently rendered `+10XP`, so a
**permitted string stopped being the string that was permitted**.

**CR-40 — Evaluate icon silhouette for semantic register, not only for
recognisability.**
Small icon geometry can import a visual register the art direction forbids, with
no palette entry and no effect involved at all. Ask what family the shape
belongs to, not just what it depicts.

*Prevents:* the Base Scene world tab, drawn as a four-point compass star. It was
perfectly recognisable, used only two flat UI values, and read as a **sparkle** —
importing exactly the magical language the rendering floor excludes, from a
palette with no glow ramp in it.

---

## 7. Red flags

Practical, not exhaustive. If you can say yes to any of these, stop and fix it
before continuing.

- [ ] The torso reads as a **slab**
- [ ] An arm reads as a **vertical bar**
- [ ] The character looks **mirrored** — identical legs, identical boots, parallel arms
- [ ] Equipment appears **pasted on or floating** beside the sprite
- [ ] A **hand merges into a weapon**, or a boot into a trouser
- [ ] The **pack reads as a shield or a blob**
- [ ] Near and far **contradict each other** between body parts
- [ ] The face is **all hair**, with no readable face plane
- [ ] An **organic object looks procedurally mirrored**
- [ ] There are **isolated one-pixel specks** with no reason
- [ ] Detail was added to solve what is actually a **silhouette problem**
- [ ] A **separation was drawn as a hole** (ink) instead of as shading
- [ ] A **successful simple asset got worse** because it was polished
- [ ] The fix under consideration is **more resolution, more colours, or more detail**
- [ ] A **path or road has a lit edge** and reads as a rail, fence, or platform
- [ ] A **roof sits on a narrow stem** and the building reads as a mushroom
- [ ] A **terrain accent is built from disconnected single pixels**
- [ ] A **directional object's arms are level and equal**, so it reads as a plus
- [ ] An **icon's shape family belongs to a register the direction forbids**
- [ ] A **UI element was sized against its own border** rather than the frame
- [ ] A **cluster's comment or variable name claims a material its ramp contradicts**
- [ ] An element is **drawn in the palette index of what it sits against**, and disappears
- [ ] A **route ends in open terrain, or against a blank wall with no aperture**
- [ ] Two masses that must read as **different objects merge at ×2**
- [ ] An asset was separated **against its own palette** but never against **the world it stands in**
- [ ] The review set has **no ×2**, or its "context" view is an **enlarged crop**

---

## 8. The standard visual output set, and the review procedure

### 8.1 The standard output set

**Every meaningful visual asset or scene produces all of the applicable views
below, in the same pass that authors it.** A pass that produces fewer has not
finished, and its output is not reviewable.

| # | View | Purpose | Required for |
|---|---|---|---|
| 1 | **NATIVE** | verifies actual pixel construction | everything |
| 2 | **×2 PLAY-SCALE PROXY** | **THE VERDICT VIEW** | everything |
| 3 | **×8 INSPECTION** | cluster craft microscope | everything |
| 4 | **TRUE IN-CONTEXT** | the asset in its real scene relationship | everything that lives in a scene |
| 5 | **SILHOUETTE-ONLY** | body and equipment shape, stripped of interior | major character / sprite design and rebuild work |

**NATIVE** — the construction itself. Typography and cluster economy are decided
here and nowhere else (CR-34).

**×2 PLAY-SCALE PROXY** — the closest available approximation of the asset in a
hand. **Nearest-neighbour only**; any smoothing invalidates it. It is the first
view a reviewer opens and the view a verdict is given at. Semantic and
readability judgements are made here.

**×8 INSPECTION** — the microscope. Genuinely useful for tangencies, specks and
cluster mistakes. **Never sufficient for graduation, and never the verdict view**
— it flatters everything. Half the Traveler's defects survived ×8 and were fatal
at play scale (CR-41, `MISTAKES.md` M-04).

**TRUE IN-CONTEXT** — the asset composited into its actual scene at the actual
scale relationship, then viewed at native and ×2. **An ×8 scene crop is not a
context view.** A crop enlarged eight times tests nothing about legibility
against environment noise, which is the only thing a context view is for. This
is also the only view that can certify CR-45's asset-against-world separation.

**SILHOUETTE-ONLY** — every non-transparent pixel collapsed to a single ink
value, at ×2. It answers one question no other view can: *is this a person
carrying something?* It is the cheapest predictor of the context failure, and it
is required for major character design and rebuild work. **Not required for UI,
and not for every environment object.**

### 8.2 The review procedure

Lightweight and mandatory in this order. **Not a verification framework**
(`RULES.md` G-1, `MISTAKES.md` M-01) — a fixed set of looks, no tooling to build.

**1. ×2 play-scale proxy. — THE VERDICT VIEW, AND THE FIRST ONE OPENED.**
If the read fails here, nothing below rescues it.

**2. Native scale.** Does the pixel construction actually work?

**3. Silhouette**, where the subject is a character. If the solid shape does not
read as a person carrying what it is meant to carry, the interior cannot fix it
(CR-20).

**4. ×8 inspection.** Working iteration only. Record which findings are visible
*only* here — those are findings about the source, not about the image.

**5. Actual game context, at native and ×2. — THE CRITICAL ONE.**
An isolated sprite is **not** the final judge of hand readability, silhouette
separation, palette relationship, equipment clarity, or charm. An asset that
survives alone can fail in a scene, and an asset that looks unfinished alone can
be perfect in one.

> **Avoid endless isolated-sprite polishing.** When the remaining weaknesses are
> context-dependent, the next step is the context, not another pass.

*Paid for by:* `VISUAL_STUDIO_BASELINE_AUDIT_01`, which found that no ×2 render
existed anywhere in the repository — `TRAVELER_REFINE_03/out/` held fifteen ×8
files, three natives and no ×2 — so all three Traveler refinement passes were
reviewed exclusively at the scale that flatters everything, and the only
available character context views were ×8 crops.

---

## 9. Working positive references

**Working references, not final art. None of their pixel maps is canonical.**

| Asset | Status | Demonstrates |
|---|---|---|
| **OR02 Traveler** — `exploration/CODE_RENDER_01/out/player_x8.png` | **WORKING CHARACTER REFERENCE — NOT FINAL CHARACTER ART** | Target pixel economy · current rough proportion family · three-quarter principles · equipment attachment · the current degree of rendering restraint |
| **Meadow Herb** — `out/herb_x8.png` | Working positive **node** reference | §5 in practice |
| **Gather card** — `out/gather_card_x8.png` | Working positive **UI craft** reference | §6 in practice. **Not the permanent game UI** |
| **Haven's Rest base scene** — `exploration/HAVENS_REST_BASE_01/out/havens_rest_base_x8.png` | **WORKING FULL-SCENE REFERENCE — NOT FINAL WORLD ART** | §5A in practice · that the language holds together as a whole world screen · the depth stack · quiet terrain at frame scale · character, NPC, node and UI coexisting |

**The base scene's buildings, trees, path, HUD dimensions, NPC sprite and
61-entry extended palette are NOT canonical**, and the weaknesses its owner
review recorded — weak architecture, an empty lower-left field, a long
right-hand road pull — were deliberately left in place as evidence rather than
polished away after the experiment concluded.

Historical baselines are preserved beside them (`pass3_*`, `or01_*`) and are the
evidence for the failure modes cited throughout this document. Do not delete
them.

---

## 10. Current provisional scale

**Recorded for experimentation only. None of these is an art-direction value.**

| | Provisional value |
|---|---|
| Traveler height | ~32 px |
| Tile / grid vocabulary | 16 px |
| Full-scene candidate | 128 × 192 native |
| Review render | ×8 nearest-neighbour → 1024 × 1536 |
| Proof palette | 49 entries, sixteen three-step ramps |
| Full-scene extended palette | 61 entries — the proof palette plus `sky`, `roof`, `canopy`, `rust` |
| Full-scene HUD strips | 13 rows top and bottom, six icon-only tabs |

These make experiments renderable. They do not become final by appearing here.

---

## 11. What stays unresolved

Unchanged by this document, and listed so their absence reads as deliberate:

- **Palette** — no colours, ramps, or count are chosen
- **Sprite dimensions** — no character, tile, or icon size is chosen
- **Camera angle**, **animation frame counts**, **rendering treatment**,
  **character proportions**, **final UI visual language** — all open
- **The production art direction itself** — `ART_DIRECTION.md` remains
  **EXPLORATION**; Direction A is a strong owner preference, not a lock
- **The implementation host** — Node versus Dart for the render tooling
- **Whether the code-driven route becomes the production pipeline** — the route
  is PROMISING / CONTINUE, and has not been chosen

---

## Related

- `GAME_BIBLE/ART/ART_DIRECTION.md` — the visual direction itself (EXPLORATION)
- `GAME_BIBLE/ART/DIRECTION_A_IDENTITY_VISUAL_SAMPLES_01.md` — the Direction A
  rendering floor and the controlled-scene constraints
- `GAME_BIBLE/ART/templates/EIGHT_DIRECTION_CHARACTER.md` — the eight-view
  production template; **CR-3's near/far discipline is what makes true
  non-mirrored diagonals possible**
- `GAME_BIBLE/ART/exploration/CODE_RENDER_01/` — the proof, its tooling, and the
  historical baselines every rule here cites
- `GAME_BIBLE/ART/exploration/HAVENS_REST_BASE_01/` — the first full-world scene,
  which §5A, CR-39 and CR-40 were paid for by. **Exploration proof, not
  production world art**
