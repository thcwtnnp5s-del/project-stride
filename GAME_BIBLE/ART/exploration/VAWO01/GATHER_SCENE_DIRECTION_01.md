# Gather Scene Direction 01 — VAWO01

```
STATUS: ART DIRECTION, PROPOSED · NOT CANON UNTIL THE OWNER RULES §3
Director: DIR-C, Gathering Scene Art Director
Date: 2026-09-01 · Branch presentation-combat-evolution-01 @ 6d41bce
Builds on: MILESTONES/evidence/VAWO01/wave0/FOUNDATION_H_GATHER.md (the audit)
Governed by: GAME_BIBLE/ART/ART_DIRECTION.md (wins on any conflict, RULES.md G-7)
             PIXELLAB_PROOF_02/PIXELLAB_STYLE_SPEC_01.md §4, §7, §9
```

The audit established the facts. This document makes the calls the audit
deliberately did not make. It is direction, not options: where a choice existed
it has been made and defended, and where a choice belongs to the owner it is
named as such and **blocks generation** (§3).

**One thing must happen before any plate is generated:** the owner ratifies the
density ruling in §3 as an amendment to **L-18**. Twenty-eight plates authored
at the wrong native size are twenty-eight wasted plates.

**Budget is not a constraint this cycle.** `get_balance`, 2026-09-01:
**9,982 generations remaining** of 10,000 (Tier 3, resets 2026-10-01). The
audit's economising toward a 9-plate minimum was correct discipline against a
budget that no longer binds. What binds now is **set coherence and review
capacity**, and this direction is sized against those instead.

---

## 1. The scene composition spec

### 1.1 The frame, in exact pixels

Everything below is measured from the shipped layout, not proposed. Derived in
the audit §1 and re-verified here against `location_stage.dart:120–263`,
`ambient_stage.dart:96–230` and `sprite_footprints.dart:46`.

| Quantity | Value | Source |
|---|---|---|
| Band height | **176 dp** | `LocationStage.height` |
| Backdrop plate | **384 × 176 native, drawn ×1**, horizontally centre-clipped | `PixelScene.vignette` |
| Stage box | `Positioned(bottom: 6, height: 140)` → band rows **30 … 170** | `location_stage.dart:238` |
| Figure box | 64 + 4 bleed rows at ×2 = 136 dp, bottom-anchored → stage y 4 | `AmbientStageLayout.groupHeight` |
| **Ground line** | stage y 132 → **band row 162** | `groupTop + (gather.bottom + 1) × 2`, `gather.bottom = 63` |
| Contact-shadow bleed | 8 dp below the ground line → band rows **162 … 170** | `ContactShadowSpec.bleed × 2` |
| Traveler feet centre | 0.6 × width, clamped | `travelerCentre` |
| Subject base | its lowest opaque row **on band row 162** | `propRect` |
| Subject side | **west** of the figure, `propGap` 8 dp | `worksEast()` returns false for every shipped loop |

**The ground line is row 162 of 176. That number is the spec.** Every plate in
the family draws its working floor so that a figure standing at row 162 is
standing on it, and every subject is authored so its lowest opaque row is the
row that meets it.

### 1.2 The five layers, back to front

This implements **L-8** (FAR / MID / NEAR) inside the band. The three planes are
the backdrop's own job; the subject and the figure are a fourth and fifth thing
in front of them, not a fourth and fifth plane.

| # | Layer | Band rows | Authored where | Density | Varies by |
|---|---|---|---|---|---|
| 1 | **SKY / FAR** | 0 – 52 | backdrop plate | ×1 | region × skill |
| 2 | **MID — the region's mass** | 52 – 110 | backdrop plate | ×1 | region × skill |
| 3 | **NEAR GROUND — the working floor** | 110 – 176 | backdrop plate | ×1 | region × skill |
| 4 | **SUBJECT — the work face** | base on row 162 | 48 × 48 subject plate | **×2** | resource family |
| 5 | **THE TRAVELER** | feet on row 162 | 64 × 64 sprite | **×2** | skill (the loop) |

Plus, per strike: a 3–4 frame regional debris burst at the contact point, on the
existing `onActivityBeat` hook (GH-08). Not authored into any plate.

**The junction between plane 2 and plane 3 — the working floor's back edge —
sits at band row 110 ± 8.** That gives 52 rows of floor between the mid plane's
base and the figure's feet, which is what reads as standing *in* a place rather
than *against* a picture of one. The accepted `bg_woodcutting` already places
its clearing junction at approximately row 106; this codifies what the best
incumbent already does.

### 1.3 The keep-clear zone — a hard authoring constraint

The subject and the figure occupy a fixed band of the plate at every supported
screen width. Computed for 393 dp and 440 dp, allowing for the plate's centring
offset (4.5 dp and 28 dp respectively):

| Element | Plate columns @ 393 dp | Plate columns @ 440 dp |
|---|---|---|
| Subject (96 dp wide) | 127.5 – 223.5 | 132 – 228 |
| Figure box (128 dp) | 169.5 – 297.5 | 174 – 302 |

> **KEEP CLEAR: plate columns 120 – 310, band rows 100 – 176.**
> Nothing the plate needs the player to read may be authored there. It will be
> covered by the subject, the figure, or both, at every screen size.

The plate's incident — the adit mouth, the cairn, the sluice, the ward stakes —
goes in **columns 0 – 118** or **columns 312 – 384**. Columns 0 – 118 is the
better half: it is fully clear at both widths and it sits on the side the tool
swings toward, so the eye travels subject → incident naturally.

**Corollary the audit's §10.1 got wrong:** there is no near-foreground occluder
*in front of the figure*. The backdrop is the backmost layer; anything painted
into it below row 162 renders **behind** the Traveler however low it sits.
"Cheap depth at the frame's bottom edge" would be a ×1 element visually in front
of a ×2 figure — the exact defect §3 rules out. **Near-foreground framing is
permitted only at the plate's left and right margins**, outside the keep-clear
zone, where nothing occludes it and nothing it occludes.

### 1.4 What is authored per what

| Layer | Varies by | Why |
|---|---|---|
| Backdrop (planes 1–3) | **region × skill**, and **region × project** where a project unlocks the node | The place and the kind of work decide the setting. A player who built the Stonefall Lift should see the Stonefall Lift. |
| Subject | **resource family**, plus a depth variant for the three ungated deeper nodes | The owner's brief: reusable compositions with an interchangeable resource object. |
| Traveler loop, strike frame, debris kind | **skill** | Already correct. |
| Closing one-shot | **skill** | Currently shared — GH-07, a code fix. |
| Contact shadow, ground band, scale, placement | **nothing — code** | Derived, so it cannot drift. |

---

## 2. The grounding rule

The audit's diagnosis is exact and I adopt it verbatim: *the object is not
floating in coordinates, it is floating in light.* `propRect` already puts the
subject's lowest opaque row on the ground line. What is missing is a shading
layer and an authoring discipline. Both, below.

### 2.1 The rule

> **G-1. Every element placed on a backdrop is grounded by a code-composited
> contact shadow derived from its own measured footprint. No shadow, no base, no
> soil pad and no ground line is ever authored into a subject plate.**

Composited, not authored, for the reason already proven in this repository:
asking PixelLab to `inpaint_image` a shadow onto a floor produced "a distinct
patch — hard-edged, flatter plank treatment, different value", because
inpainting re-renders the whole masked band (`grounded_sprite.dart:28–35`). And
because a multiply shadow takes the ground's own hue with it, one composited
shadow is correct on snow, on peat and on flagstone; a painted grey ellipse is
correct on none of them.

### 2.2 The shape, exactly

Subjects use **`ContactShadowSpec` unchanged** — the same constants as the
Traveler, not a second set. One tuned constant is the whole point of the widget,
and 0.45 was already proven imperceptible at play scale.

| Property | Value | Note |
|---|---|---|
| Form | horizontal ellipse, **multiply** (`background × (1 − strength)`) | never a painted grey |
| Strength | **0.72** | identical to the figure's |
| Width | the subject's **measured contact span** + `spread` 3 native px each side | measured, never passed by a caller |
| Height | `squash` 0.30 × width, **clamped to 9 native px** | so no subject's shadow is ever deeper than the man's; an unclamped 48-px-wide bed would smear a 14-px shadow and read as a cast shadow, implying a light source the scene does not have |
| Inset | 1 native px above the lowest opaque row | under it, not behind it |
| Bleed | 4 native px reserved below | already in the stage's 8 dp of room under the ground line |

The clamp is the only addition, and it is required by the fact that subjects are
wide where figures are narrow. Everything else is reused.

### 2.3 How it generalises to all 22 nodes

The mechanism is a measurement, so it generalises without a table:

1. `Scripts/art/measure-ambient-extents.js` is extended to emit, per subject
   plate, a `SpriteFootprint` — the **union of the opaque columns in the lowest
   three rows** — alongside the `SpriteBounds` it already emits.
2. `StageScenery` gains that footprint and a `scale` field.
3. `ambient_stage.dart:336 _prop` stops building a bare `PixelAsset` and builds
   the same footprint-derived shadow painter `GroundedSprite` uses.

A subject that has no footprint cannot be routed, and the guard (§6.4) refuses
the build. That is what makes the rule cover all 22 nodes and the three craft
stations rather than the ten that happen to be wired today.

### 2.4 The authoring half of the rule

The shadow beds the object. It does not rescue a plate that was drawn as a
catalogue photograph. Three authoring constraints, all of which the incumbent
plates violate:

- **No closed keyline.** `node/hollow_thicket.png` carries **1,642 pixels of
  pure `#000000`** — an item-icon keyline, and the single loudest cut-out tell
  in the set. Subjects are outlined in a **deep desaturated brown, never
  `#000000`**, consistent with the character convention (STYLE_SPEC §4).
- **The base is open.** The mass **reaches the bottom edge of its own frame**
  and the outline does not close underneath it. A subject that terminates in a
  drawn bottom edge has authored its own ground plane, and two ground planes in
  one frame is what the eye reads as pasted even when the pixels touch.
- **One connected mass at the base.** A subject whose lowest rows are two
  separated islands gets one ellipse spanning the gap, which darkens empty
  floor. Authored as one mass, the derived shadow is always correct.

**QA gate:** cut the finished subject out and drop it on a flat UI surface. **If
it looks like a good inventory icon, it is a bad scene subject.** Re-roll — a
`create_image_pixen` roll is 1 generation and there are 9,982 of them. If three
rolls fail on the base outline, the fallback is a deterministic packaging step
that erases the lowest two outline rows; it is a fallback, not the plan.

---

## 3. The density ruling — GH-05

**This is the decision that blocks generation. It is proposed here and requires
owner ratification as an amendment to L-18.**

### 3.1 The ruling

> **L-18a (proposed). Density is a property of a PLANE, not of a frame.**
>
> Within one composition, **every element that shares a ground line with the
> figure, overlaps it, or is crossed by its tool arc, is drawn at the figure's
> density — ×2.** The single backdrop plate behind them stays **×1**.
>
> **No asset authored at ×1 may ever be drawn in front of the figure.**

Applied: **subjects are authored at 48 × 48 native and drawn at ×2.** On-screen
size is 96 dp — **byte-for-byte the same footprint they occupy today.** Backdrop
plates stay 384 × 176 at ×1 and are unchanged in size, packaging, framing and
device acceptance.

### 3.2 The defence

**What the player actually perceives.** A density mismatch is only legible where
two densities meet at an edge. The subject and the figure share a ground line,
overlap horizontally by 40–55 dp at every screen width, and the tool arc crosses
the subject's near face — the two densities collide at the exact point the eye
is looking, twice a second, for 48 s to 3 minutes. The backdrop touches nothing
and is never crossed. Its finer staircase reads as *further away*, which is
detail perspective and a legitimate depth cue that pixel art has always used:
a painted flat behind, built set pieces in front. **The current arrangement is
that cue inverted** — the near thing is finer than the man standing on top of
it — which is why "mismatched" is the word the owner reached for.

**What L-18 requires.** L-18 demands an exact integer multiple *per asset*, with
nearest-neighbour and an uncompressible container. ×1 and ×2 both satisfy it,
which is precisely why the audit found no rule governing this. L-18 is silent,
so this needs an **amendment, not an interpretation** (`RULES.md` G-3). L-18a
above is that amendment, written to extend the rule rather than weaken it: it
adds a constraint L-18 did not have.

**What is cheapest to author.** The alternative ruling — one density everywhere,
×2 — means a 192 × 88 native backdrop family. That is not four plates. It is
every work backdrop (6), every craft station (3), **and every location vignette
in the product** (10 packaged plates across five regions), all of which have
been through owner device acceptance, several of them more than once. Re-authoring
the accepted world to fix a P1 is disproportionate (`RULES.md` G-1) and it puts
ten accepted paintings back at risk to solve a problem in front of them.
The near-plane ruling re-authors **six subject plates and three craft stations,
none of which the owner has ever praised**, and the five genuinely new subjects
are then born at the right size instead of being re-made later.

**48 is also the proven canvas.** STYLE_SPEC §2.1 settled 48 × 48 as the pixen
canvas with a documented method and a six-generation probe behind it. 96 × 96
was never a specified family size — it arrived as the node-vignette canvas from
Transformation Build 01, which is exactly the provenance that produced the
floating-icon defect. Moving subjects to 48 puts them back on the family's own
grid.

**One further argument the audit could not see.** `ContactShadowSpec` is
expressed in **native pixels** — `spread: 3`, `inset: 1`, `bleed: 4`. Those
constants only mean the same thing in dp on two canvases if the two canvases
share a scale. Grounding subjects at ×1 while the figure is at ×2 would need a
second, divergent shadow spec. **The density ruling is what lets §2 reuse one
constant.**

**What happens to the six shipped backdrops.** Nothing, on account of density.
They keep their native size and their packaging. Three of them are re-authored
in §6 for a completely independent reason — set coherence and regional
match — and the density ruling neither causes nor prevents that.

**What changes in code.** `StageScenery` gains `scale`; `propRect` multiplies
`native` by it. The composition test's expectations scale by exactly 2, which is
arithmetic, not re-measurement. `AmbientStageLayout.propGap`, `groundLine`,
`feetCentre` and every screen-width case are untouched.

### 3.3 What this does not license

It does not license a ×2 backdrop, a ×3 anything, or a per-screen scale. It does
not reopen the world sprite's 128 × 192. And it does not authorise touching the
location vignette family, which is out of this direction's scope entirely.

---

## 4. Regional visual vocabulary

Region names as they exist in `assets/content/v1/locations.json`: **Haven's
Rest, Whispering Woods, Stonefall Mine, Frostmere, Forgotten Hollow.** Ecology
from `GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md` §4.

### 4.0 The palette anchor — the single strongest lever

> **Every work backdrop is generated with `style_image_url` set to that
> region's accepted location vignette and `style_copy: ["color_palette"]`, with
> no palette words in the prompt.**

Not the Traveler sprite. The region's own arrival painting. This is the lever
PROOF_03 proved (§3.2) pointed at the right reference, and it closes **GH-14**
structurally: the painting the player arrives to and the backdrop they work in
will be the same place in the same colours, because one was generated from the
other. It also lets Frostmere and the Hollow leave the warm family without a
single palette word in the prompt — the anchor carries the temperature.

`style_copy` takes only the palette. The camera is unaffected: the location
vignettes are `low top-down` dioramas, the work backdrops are the shallower
eye-level stage camera. That difference is intended and must be preserved.

### 4.1 Measured baselines the new set must respect

Colour counts and mean luminance, measured this session on the packaged plates:

| Plate | Colours | Mean luminance | Floor band (rows 150–175) |
|---|---:|---:|---:|
| `location/frostmere` | 45 | 174 | — |
| `location/stonefall_mine` | 30 | 105 | — |
| `location/havens_rest` | 40 | 69 | — |
| `location/whispering_woods` | 36 | 55 | — |
| `location/forgotten_hollow` | 45 | 40 | — |
| `work/bg_foraging` | 35 | **123** | 89 |
| `work/bg_woodcutting` | **66** | 73 | 80 |
| `work/bg_mining` | 40 | 48 | **47** |

Three findings drive §6:

1. **The location family is coherent** — 30–45 colours, a clean 40→174
   luminance ladder across five regions. It is a set.
2. **The three work backdrops are not a set.** 35 / 66 / 40 colours; `bg_woodcutting`
   is a 66-colour outlier carrying teal-family light shafts (`#7aadaa`,
   `#4d8282`, `#a9cabf`) that nothing else in the product has. Authoring four new
   plates against these three produces a seven-plate incoherence, not a set.
3. **`bg_foraging` is 54 luminance points brighter than Haven's Rest's own
   arrival painting** (123 vs 69), and `bg_mining` is 57 points darker than
   Stonefall's (48 vs 105). The cut on selecting an activity is currently a
   change of *weather*, not of framing.

**Two measurable acceptance floors for the new family:**

- **Colour count 28 – 48** per plate. Outside that band, re-roll.
- **Floor band (rows 150–175) mean luminance ≥ 55.** Below it, the 0.72 multiply
  contact shadow produces less than a 40-point drop and the grounding fix
  silently stops working — on the darkest regions, which are the ones that most
  need it. `bg_mining` fails this today at 47.

### 4.2 The five regions

#### Haven's Rest — *cultivated*

| | |
|---|---|
| **Ground** | Cropped, grazed meadow turf over pale river loam; a trodden tan path; a low turf step where the ground has been worked flat |
| **Vegetation** | Mown grass, a kept hedgerow line, cow parsley and yarrow heads standing above the sward, one willow at the water |
| **Light** | Open sky, mid-morning, high and even. The brightest *sky* of the five; the widest visible sky band |
| **Weather** | Clear and still; one thin cloud band in the far plane |
| **Props** | Split-rail fence, a leaning gate, a drystone field wall, the mill's timber sluice, a hay stook, a coil of rope on a post |
| **Palette** | Cream `#beba8d`, olive `#7d7b43`, warm ochre `#a59859`, brown loam. Anchored to `location/havens_rest` (mean 69) — **warmer and darker than the incumbent `bg_foraging`** |
| **The tell** | *Someone maintains this.* Every edge is a kept edge: a cut hedge, a set post, a mown line. Nothing in Haven's Rest is wild. |

#### Whispering Woods — *old growth*

| | |
|---|---|
| **Ground** | Deep leaf litter over dark wet loam, exposed root buttresses breaking the surface, moss on the north faces |
| **Vegetation** | Heavy oak boles with **vertically fissured** bark, hazel understorey, ferns, bramble, ivy climbing two trunks |
| **Light** | Closed canopy. Shafts through gaps — **re-valued to a warm pale cream-green**, never the incumbent's teal. Low ambient, high local contrast |
| **Weather** | Still and damp; faint ground mist pooled in the far plane only |
| **Props** | A ranger's blaze cut into a bole, a bole on trestles, a cord of split oak, ward stakes and a rope line (the watchtower's work) |
| **Palette** | Moss green, dark olive, warm brown bark, black-green shadow. Anchored to `location/whispering_woods` (mean 55, 36 colours) |
| **The tell** | *This forest is older than the road.* Trunk diameter carries it: boles wider than the Traveler, cropped by the frame top, receding in at least three overlapping depths. |

#### Stonefall Mine — *cold worked stone*

| | |
|---|---|
| **Ground** | Crushed grey spoil, rail sleepers bedded in it, wet flagged floor near the face, standing puddles that take the lantern |
| **Vegetation** | Almost none. A bracket of grass and a rag of moss at the adit mouth, and nothing beyond it |
| **Light** | No sky in the workings. One warm lantern, or one cold shaft of daylight from the adit, never both in the same plate. Low key, cold neutral |
| **Weather** | Rock dust hanging in the light; no sky, no wind |
| **Props** | Timbered adit frames and a lintel, sawn props, a mine cart on rail, a spoil heap, a pick-scarred wall, a lantern on a hook, the lift headframe |
| **Palette** | Neutral grey `#8b8a8a`, iron, tan spoil, warm timber brown, one bone-white highlight. **The lantern is the region's only warm accent** and it must not be repeated |
| **The tell** | *Every surface here was cut by someone.* Straight tool marks, coursed timber, a floor that is level because it was made level. Natural rock only above the working height. Floor band must clear luminance 55 — the incumbent does not. |

#### Frostmere — *snow and pale light*

| | |
|---|---|
| **Ground** | Packed snow over grey scree, wind-crust ridges, dark rock breaking through where the wind has scoured it, blue-shadowed hollows |
| **Vegetation** | Frostpine — dark blue-green, spare, **upswept and narrow**. Cushion plants in rock crevices. No understorey at all |
| **Light** | High, flat, overcast alpine light. Snow is the value ceiling. **The only region whose shadow family is cool** — blue-grey, never black |
| **Weather** | Thin blowing snow, a low haze softening the far plane, the frozen tarn's flat white plate |
| **Props** | A stone windbreak, a cairn, a lashed pole marker, a snow-drifted stump, the tarn's edge |
| **Palette** | `#d3e5f0`, `#95afc7`, cold slate `#263e45`, dark conifer, warm rock brown `#8a7360`. Anchored to `location/frostmere` (mean 174 — the brightest plate in the product) |
| **The tell** | *Nothing here shelters you.* Wind direction is visible and consistent: drift shapes, snow banked on one side of every mass, needles combed one way. |
| **Hazard** | This is the palette nearest the reserved walking teal `#58d6c0`. Hold the cold end at **slate-blue**, never at cyan-green. Every plate runs `Scripts/art/check-art-palette.js` before acceptance. |

#### Forgotten Hollow — *dark roots and strange flora*

| | |
|---|---|
| **Ground** | Black wet peat, standing water skinned with duckweed, mossed fallen masonry half-sunk in it, pale roots breaking the surface |
| **Vegetation** | Strange: pale silk strands slung between boles, bone-coloured root balls out of the peat, lichen beards, no flowers anywhere |
| **Light** | The lowest key in the world. Light falls from directly above through the fold's mouth, so the upper-left key is a **narrow pale wash on top surfaces only**; everything else drops to near-black |
| **Weather** | Still, wet, a low mist skin lying on the water |
| **Props** | A half-sunk lintel, a mossed step, a leaning ward stake, the field camp's canvas and brazier, the undercroft's vault ribs |
| **Palette** | Desaturated grey-green `#2e3030`, wet black `#1c1a21`, `#2b3b44`, bone-pale root, one sickly cream for the silk. **No saturated hue anywhere.** Anchored to `location/forgotten_hollow` (mean 40) |
| **The tell** | *Older than the frontier.* Worked stone that predates Haven's Rest, being taken back by roots. Masonry is always **losing**. |
| **Hazard** | "Dark and strange" collapsing into black soup. L-8 still binds: FAR, MID and NEAR must read as three distinct values in the darkest region in the game. Compress the range; never collapse it. Floor band ≥ 55 is non-negotiable here. |

---

## 5. Per-skill subject language

The universal silhouette rule, before the three specific ones:

> **A subject is a WORKING FACE, not an object. It continues past its own frame
> on at least one edge, it terminates into the floor rather than onto it, and it
> is at or below the Traveler's chest — 96 dp against his 128.**

An object has air all the way around it. A face does not. That single
distinction is the difference between an inventory icon and scene furniture, and
it is testable at a glance.

### 5.1 Mining — a seam, not a floating rock

**Silhouette rule: the mass is flush to the canvas's left edge and its bottom
edge, and its top is a broken diagonal — never a dome.**

The incumbent `prop_copper_seam` is a closed boulder with air on all four sides
and a hard black keyline. It is a rock a man could pick up. A seam is a **face
of the region's own rock, cut into**, that continues out of frame.

On the 48 × 48 canvas:

- Opaque from **x = 0** (flush left) to x ≈ 40; from y ≈ 8 down to **y = 47**
  (flush bottom).
- The pick lands at roughly chest height: band row ~120, which is 42 dp above
  the ground line — **native rows 22 – 32.** That is where the worked scar, the
  fresh pale broken rock, and the mineral show sits. Nowhere else.
- Below row 32, **loose spoil and broken rubble banked against the base.** This
  is what gives the subject a wide, honest contact span for §2's derived shadow
  and it is what a real worked face looks like.
- The host rock is **the region's rock**, taken from the backdrop's palette. It
  is a continuation of the wall behind it.

**Mineral rule — the veins, and how the four faces differ:**

| Face | Host rock | Mineral | Vein geometry |
|---|---|---|---|
| Copper | mid grey granite | dull green-blue malachite staining plus **dull red-brown** metal | a branching net across the face |
| Tin | darker grey-brown | near-black cassiterite, dull, low-value | **one straight lode** running corner to corner |
| Hardened copper | dense blue-grey, barely scarred | the same malachite-and-metal | **fewer, thicker** veins; the face resists the pick |
| Ruin / scrap | not natural rock at all | rusted strap iron, bent rail, a broken timber prop | **coursed drystone masonry, collapsed** — an arch that has fallen in |

Two things this forbids, both observed in the shipped set:

- **`#fc8342` is banned.** The incumbent copper prop carries 152 pixels of it —
  a saturated fire orange that reads as heat, not mineral (STYLE_SPEC D-2:
  "ore vs magma judged a coin-flip").
- **Copper and tin must not be one silhouette in two tints** (D-5). They are
  separated by **vein geometry and host value**, and they must be tellable with
  the colour removed.

### 5.2 Woodcutting — the cut, not the tree

**Silhouette rule: no standing tree is ever a subject. Standing trees live in
the backdrop's mid plane, where they can be as tall as they like and be cropped
by the plate. The subject is the cut, and its base is LONG and HORIZONTAL.**

This closes **GH-06** for all five woodcutting nodes at a stroke: a "Frostpine
Stand" of three mature pines shorter than the man felling it is not a scale bug,
it is the wrong subject. It also honours a blind-QA finding already on record —
a tree drawn tall enough to swallow the axe read as "a man pointing at a tree".

The best incumbent plate already does this: `prop_oak_stand` is **a stump with a
fresh notch and a felled log beside it**. That is the language. It is confirmed,
not replaced.

A horizontal base is also what an axe-swing composition physically needs, and
what a whole tree can never provide.

**Oak vs frostpine — the difference must survive desaturation:**

| | Oak | Frostpine |
|---|---|---|
| **Mass** | squat and **wide** — base wider than the mass is tall | a **narrow** vertical wedge on a shorter base |
| **Bark** | deeply fissured grey-brown in **vertical ribbons**; a wide flaring root collar | smooth **horizontal plates** in red-brown scales; no flare |
| **Cut face** | pale cream-ochre disc, visible rings, slightly oval | pale and resinous with a **dark pitch centre**, clean and round |
| **Debris** | split billets with straight riven faces, chips of pale wood | a dark spray of **needles** at the base, clean sawn ends |
| **Snow** | none | a band **on the log's upper surface only** — never coating the whole mass |

The previous frostpine attempt was rejected as reading "an ice column / frozen
waterfall". The two fixes are exactly the two rows above: **bark plates must run
horizontal**, and **needles must be visible as a dark spray at the base.** Snow
that coats the mass is what turned it into ice.

### 5.3 Foraging — a bed, not an arrangement

**Silhouette rule: a bed has no top edge you can draw around. The upper contour
is ragged — individual stems and leaf tips breaking it so no single closed
outline can enclose the mass — and the bed runs off BOTH the left and right
canvas edges. Height at most 40 % of the figure (≈ 50 dp, native row 22 and
below).**

A plant bed that stops before the frame does is a potted arrangement.

**And there is no container.** No basket, no bundle, no tied sheaf, no sack, no
pot. A container is inventory language, and it is precisely what makes
`prop_meadow_patch` — one of the better shipped props — still read as an icon.
The wicker basket goes.

| Bed | The read | Construction |
|---|---|---|
| **Meadow herb** (Haven) | open and airy | grass-blade bed, pale cream umbels held above it on thin stems, a few seed heads gone over |
| **Duskcap** (Woods) | the litter is the bed, the caps are the read | leaf litter and a mossed fallen branch with brown-capped fungus clustered on and beside it |
| **Rime blossom** (Frostmere) | a cushion in a crevice | a tight low mound of blue-grey foliage in a rock crevice with small white five-point flowers; **the snow belongs to the backdrop** — the subject carries only the crust inside its own crevice |
| **Gloom silk** (Hollow) | strands under tension across a gap | pale strands slung **horizontally between two dark stems**, sagging under their own weight, a low tangle beneath. Described as *sagging horizontal threads between two anchors* — "wound" and "tied" phrasing is a known pixen failure that returns spirals |
| **Hollow root** (Hollow) | below the ground, opened | bone-pale roots breaking **up** out of black peat, one already levered clear, wet soil crumbs at the base |

Silk and root are the pair that must never be confused: **silk spans above the
ground, root breaks up out of it.** That is the read that has to carry the
Forgotten Hollow's two resources apart, and today it is carried by nothing at
all — all five Hollow nodes are one image.

---

## 6. The exact plate list

### 6.1 The verdict on the audit's count of 9

**Revised upward. 18 plates in the shippable round; 28 in total.** Four reasons,
in order of weight:

1. **The audit's arithmetic is wrong on the headline outcome.** It claims 4
   backdrops + 5 subjects takes the product "from 12 distinct scenes to up to
   22". Enumerated against the real node table, 7 backdrops × 11 subject
   families yields **11 distinct (backdrop, subject) pairs across 22 nodes —
   one FEWER than today's 12.** Eleven nodes would still be pixel-identical to
   another node. Today's 12 is inflated by *accidental* variety: the six icon
   fallbacks happen to differ from the six props. Replacing them with a correct,
   reusable family makes every scene right and makes the count go down. GH-04,
   a P0, would be left open by the audit's own plan.
2. **The density ruling (§3) forces six re-authors.** The product cannot ship
   five subjects at 48 × 48 alongside six at 96 × 96 — that is the same defect
   with a node-dependent shape. The six existing props must be re-authored at
   48; a 2:1 nearest downscale destroys a one-pixel outline and is not an option.
3. **Set coherence forces three replacement candidates.** Measured in §4.1: the
   three shipped work backdrops are 35 / 66 / 40 colours with mean luminance
   123 / 73 / 48, one of them carrying teal-family light shafts nothing else
   has, and two of them 54 and 57 luminance points away from their own region's
   arrival painting. Authoring four new plates against that produces a
   seven-plate incoherence. *Consistency outranks one-off novelty*
   (`ART_DIRECTION.md`) — the seven are authored as one round, one prompt
   skeleton, one value structure, and **an incumbent that wins its side-by-side
   stays.** Three candidate rolls at 1 generation each is a trivial price for a
   set that is actually a set.
4. **The audit's optional "+7 tier treatment" is spent better elsewhere.** A
   richer vein is a consolation prize. **Ten of the twenty-two nodes are
   unlocked by a built project** — the Stonefall Lift, the Lower Gallery Works,
   the Hollow Undercroft, the Frostmere Shelter, the Mill, the Ranger
   Watchtower, the Hollow Field Camp — and the player has **never seen any of
   them.** Making the *backdrop* the tier variable shows the player the thing
   they paid steps to build, standing in the world, every time they work that
   node. That answers the Kernel question directly, where a deeper-looking rock
   does not.

### 6.2 Backdrops — 14 plates

All **384 × 176 native, opaque, drawn ×1**. Method: `create_image_pixen`,
`low top-down`, `style_image_url` = the region's accepted location vignette,
`style_copy: ["color_palette"]`, no palette words in the prompt. Ground line at
row 162; mid/near junction at row 110 ± 8; keep-clear columns 120–310 below row
100; colour count 28–48; floor band mean luminance ≥ 55.

**Base — region × skill (7):**

| ID | Plate | Status | Serves | Material description |
|---|---|---|---|---|
| B1 | `bg_haven_foraging` | **REPLACE** `bg_foraging` | meadow_patch | Kept river-meadow bank below a hedgerow, split-rail fence at the left margin, mown sward and pale loam floor, open morning sky |
| B2 | `bg_woods_woodcutting` | **REPLACE** `bg_woodcutting` | oak_stand, heartwood_oak | Open earthen clearing among heavy oak boles, cream-green light shafts (no teal), leaf-litter floor, deeper wood in warm haze |
| B3 | `bg_woods_foraging` | **NEW** | duskcap_grove | Shaded forest floor under closed canopy, mossed fallen branches, fern bank at the left margin, deep leaf litter |
| B4 | `bg_stonefall_mining` | **REPLACE** `bg_mining` | copper_seam, tin_seam, deep_tin_seam | Timbered adit with a lintel, natural granite face, rail and sleepers in the floor, one lantern at the left margin, floor re-valued to clear luminance 55 |
| B5 | `bg_frostmere_woodcutting` | **NEW** | frostpine_stand, oldgrowth_frostpine | Treeline shelf in packed snow, dark upswept frostpines receding, scoured rock breaking through, flat overcast alpine light |
| B6 | `bg_frostmere_foraging` | **NEW** | rimefrost_hollow | Wind-scoured scree slope above the frozen tarn, snow crust and blue-shadowed hollows, no trees, the tarn's white plate in the far band |
| B7 | `bg_hollow_foraging` | **NEW** | silkstrand_thicket, hollow_thicket | Sunken vale floor, black peat and standing water, mossed fallen masonry, roots across the fold, a narrow pale wash from directly above |

**Project-built variants (7)** — routed by node where the node's unlocking
project has been completed; falls back to the base plate otherwise:

| ID | Plate | Project | Serves | Material description |
|---|---|---|---|---|
| B8 | `bg_haven_mill_garden` | `havens_rest_mill` | mill_garden | Walled kitchen garden below the mill's timber sluice, running water at the left margin, worked beds in dark tilled loam |
| B9 | `bg_woods_warded_grove` | `ranger_watchtower` | warded_grove | Blazed oaks and lashed ward stakes on a rope line, the watchtower's leg cropped at the left margin, cleared litter floor |
| B10 | `bg_stonefall_lift` | `stonefall_lift` | old_workings, hardened_copper_seam | Lift-head chamber — headframe, cage and winding drum at the left margin, cut stone, spoil banked at the wall |
| B11 | `bg_stonefall_gallery` | `lower_gallery_works` | gallery_tin_lode, collapsed_span | Timbered lower gallery receding into dark, plank walkway and rail, props at close intervals, one lantern deep in |
| B12 | `bg_frostmere_shelter` | `frostmere_shelter` | sheltered_frost_meadow | The lee of a crag behind a built stone windbreak, less drift, exposed cushion turf, the wind visible outside the shelter and stilled inside |
| B13 | `bg_hollow_field_camp` | `hollow_field_camp` | veiled_silkstrand | Cleared and drained camp ground, taut canvas and a low brazier at the left margin, cut back roots, the vale pressing in beyond |
| B14 | `bg_hollow_undercroft` | `hollow_undercroft` | undercroft_silkfall, deep_hollow_thicket | Sunken masonry vault, ribs and a fallen lintel, standing water on the flags, roots through the vault above |

### 6.3 Subjects — 14 plates

All **48 × 48 native, transparent, drawn ×2** (96 dp on screen — unchanged).
Method: `create_image_pixen`, `no_background`, shallow three-quarter to match
the stage camera (**not** the icons' `high top-down`), scene-subject style
clause (§6.5). Zero semi-transparent pixels. Base flush to the frame bottom.

**Resource families (11):**

| ID | Plate | Status | Serves | Material description |
|---|---|---|---|---|
| S1 | `prop_meadow_bed` | RE-AUTHOR at 48 | meadow_patch, mill_garden | Grass-blade bed with pale cream umbels above it, running off both edges — **no basket** |
| S2 | `prop_duskcap_bed` | RE-AUTHOR at 48 | duskcap_grove | Leaf litter and a mossed fallen branch with brown-capped fungus clustered on and beside it |
| S3 | `prop_rime_cushion` | **NEW** | rimefrost_hollow, sheltered_frost_meadow | Tight blue-grey cushion plant in a rock crevice, small white five-point flowers, crust only inside the crevice |
| S4 | `prop_gloom_silk` | **NEW** | silkstrand_thicket, veiled_silkstrand, undercroft_silkfall | Pale strands sagging horizontally between two dark stems, low tangle beneath |
| S5 | `prop_hollow_root` | **NEW** | hollow_thicket, deep_hollow_thicket | Bone-pale roots breaking up out of black peat, one levered clear, wet soil crumbs |
| S6 | `prop_oak_cut` | RE-AUTHOR at 48 | oak_stand, warded_grove | Notched oak stump with a felled bole beside it, vertically fissured bark, cream-ochre cut face |
| S7 | `prop_frostpine_cut` | **NEW** | frostpine_stand | Felled frostpine bole, horizontally plated red-brown bark, resinous pale cut face with a dark pitch centre, needle spray at the base, snow band on the upper surface only |
| S8 | `prop_copper_face` | RE-AUTHOR at 48 | copper_seam | Granite face flush to the left and bottom edges, branching malachite-and-dull-metal net at rows 22–32, spoil banked at the base — **no `#fc8342`** |
| S9 | `prop_tin_face` | RE-AUTHOR at 48 | tin_seam, gallery_tin_lode | Darker grey-brown face, one straight near-black cassiterite lode corner to corner, spoil at the base |
| S10 | `prop_hardened_copper_face` | RE-AUTHOR at 48 | hardened_copper_seam | Dense blue-grey face, few thick veins, barely scarred, little spoil |
| S11 | `prop_ruin_face` | **NEW** | old_workings, collapsed_span | Collapsed coursed drystone arch with rusted strap iron, bent rail and a broken timber prop — worked stone, not natural rock. Closes GH-10 |

**Depth variants (3)** — the three deeper nodes that no project backdrop
differentiates, because they are unlocked by *level*, not by a project:

| ID | Plate | Serves | Material description |
|---|---|---|---|
| S12 | `prop_heartwood_oak_cut` | heartwood_oak | A far heavier oak: the bole's diameter fills the canvas width, the cut face shows dense close rings and a dark heartwood core |
| S13 | `prop_deep_tin_lode` | deep_tin_seam | The tin face driven deeper — a fresh square-cut heading rather than a weathered outcrop, two lodes converging, more spoil |
| S14 | `prop_oldgrowth_frostpine_cut` | oldgrowth_frostpine | An old-growth bole: thicker plates, deeper pitch staining, a second sawn round already off the end |

### 6.4 The routing this produces — 22 distinct scenes, zero duplicates

| # | Node | Backdrop | Subject |
|---|---|---|---|
| 1 | meadow_patch | B1 | S1 |
| 2 | mill_garden | B8 | S1 |
| 3 | oak_stand | B2 | S6 |
| 4 | heartwood_oak | B2 | S12 |
| 5 | warded_grove | B9 | S6 |
| 6 | duskcap_grove | B3 | S2 |
| 7 | copper_seam | B4 | S8 |
| 8 | old_workings | B10 | S11 |
| 9 | tin_seam | B4 | S9 |
| 10 | deep_tin_seam | B4 | S13 |
| 11 | hardened_copper_seam | B10 | S10 |
| 12 | gallery_tin_lode | B11 | S9 |
| 13 | collapsed_span | B11 | S11 |
| 14 | rimefrost_hollow | B6 | S3 |
| 15 | sheltered_frost_meadow | B12 | S3 |
| 16 | frostpine_stand | B5 | S7 |
| 17 | oldgrowth_frostpine | B5 | S14 |
| 18 | silkstrand_thicket | B7 | S4 |
| 19 | hollow_thicket | B7 | S5 |
| 20 | veiled_silkstrand | B13 | S4 |
| 21 | undercroft_silkfall | B14 | S4 |
| 22 | deep_hollow_thicket | B14 | S5 |

All 22 pairs distinct. Forgotten Hollow goes from **one** picture to **five**.
Frostmere from two to four. Stonefall from five to seven.

**The guard goes in before the art** (GH-12, and the audit's own ordering).
`test/node_art_resolution_test.dart` is extended to assert: every node resolves
a `_workProps` entry; every subject carries a measured footprint; and **no two
nodes resolve the same (backdrop, subject) pair.** With that guard green, the
12-node gap cannot silently regrow the way it grew from 3 to 12 across four
content packs.

### 6.5 Rounds

| Round | Plates | Contents | Closes |
|---|---:|---|---|
| **1** | **18** | B1–B7, S1–S11 | GH-01, GH-02, GH-03, GH-05, GH-06, GH-10, GH-14. Residual: 11 same-region same-resource nodes still share a scene |
| **2** | **10** | B8–B14, S12–S14 | GH-04 fully — 22/22 distinct — and turns every completed project into something the player can see |
| follow-on | 3 | craft stations at 48 × 48 | The density ruling binds the craft stage too; without this the two stages diverge |

Round 1 is the shippable unit and goes to device before Round 2 begins. Round 2
is authorised by this direction but sequenced after acceptance, per the repo's
staged-production rule.

### 6.6 The two style clauses

The icon clause (STYLE_SPEC §7.2) **must not be used for a scene subject** — its
"single dark outline all the way around the object" is the cut-out tell itself.
Two clauses, appended verbatim:

**Scene subject:**

> — pixel art scene element for a side-on game stage, flat matte shading in a few
> clear steps, light from the upper left, single dark outline in a deep
> desaturated brown, never pure black, no glow, no emissive light, no bright
> white specular, no cast shadow, no ground pad, no soil patch, no grass tuft
> under the object, no container, no basket, no pot, no text, the mass reaching
> the bottom edge of the frame and open along its base

**Backdrop:**

> — pixel art game background band, three depth planes far, middle and near
> reading as clearly distinct values, flat matte shading in a few clear steps,
> light from the upper left, no glow, no bloom, no lens flare, no figures, no
> people, no creatures, no text, no labels, no border frame, no darkening at the
> edges, no user interface, the lower third an open floor with nothing standing
> on it, the middle of the frame kept plain

Prompt shape is STYLE_SPEC §7 unchanged: *noun phrase, presentation clause,
construction clause, style clause.* The construction clause is the load-bearing
part; enumerate the parts and how they attach.

---

## 7. What must not happen

Specific to this work. Each is a way the new scenes could be as bad as the old
ones in a different way.

**7.1 The subject becomes a bigger icon.** A closed keyline, a self-contained
base, an authored ground pad, or any container reproduces the exact defect at a
new canvas size. **Test: cut the subject out and drop it on a flat UI surface.
If it makes a good inventory icon, it is a bad scene subject.**

**7.2 The backdrop becomes a second painting competing with the subject.**
Fourteen plates authored for their own beauty will put incident at plate columns
120–310 below row 100 — exactly under the prop and the figure. The keep-clear
zone is a constraint on the *composition*, not a note. A gorgeous plate that
loses its subject is a defect.

**7.3 Region becomes a filter.** Frostmere as the Woods plate with white on top;
the Hollow as the Woods plate with the lights off. **Test: desaturate all seven
base plates. If the five regions are not tellable in greyscale, the regional
identity is hue and the work has failed.** Regions differ in *structure* — what
masses stand in the mid plane — before they differ in colour.

**7.4 The Hollow eats its own light.** L-8 still binds in the darkest region in
the game. Below the floor-band luminance floor of 55, the 0.72 multiply contact
shadow has nothing left to darken and **the grounding fix silently stops
working on the region that most needs it** — while still passing every existing
test. This is the failure mode that would look fixed and not be.

**7.5 Emissive mineral.** STYLE_SPEC D-2, already in the shipped set: 152 pixels
of `#fc8342` on the copper prop reading as heat. Ore is dull. If a reviewer
hesitates between ore and fire, re-roll.

**7.6 Teal creep.** Frostmere's cold end and the Woods' light shafts both drift
toward `#58d6c0`'s family, and the incumbent `bg_woodcutting` is already there
(`#7aadaa`, `#4d8282`, `#a9cabf`). L-16 is absolute and **nothing in the
generation pipeline enforces it** (STYLE_SPEC §4.1 says so plainly). Every plate
runs `Scripts/art/check-art-palette.js` before acceptance, and if that script
does not check hue-family proximity to the reserved teal, it must before the
first plate is accepted.

**7.7 Two densities re-introduced by the near foreground.** No ×1 element in
front of the figure, ever. This is why §1.3 deletes the audit's proposed
near-foreground occluder and permits edge framing only.

**7.8 An authored shadow.** Already tried, already rejected: an inpainted shadow
returned "a distinct patch — hard-edged, flatter plank treatment, different
value". The shadow is code, derived from a measurement, or it is not there.

**7.9 A whole tree as a subject.** GH-06, and a blind reviewer's honest first
read already on record: "a man pointing at a tree". Standing trees are backdrop.

**7.10 The Traveler disappearing into Frostmere or the Hollow.** He is the style
anchor and he must stay legible against the two extreme plates. A plate cold
enough or dark enough to swallow him is a **plate** failure: hold a warm mid
value in the floor band under the figure so his rust accent separates. Fix the
backdrop, never the character.

**7.11 Generating before the ruling lands.** §3 must be an owner-ratified L-18
amendment first. Twenty-eight plates at the wrong native size is twenty-eight
wasted plates, and the budget being large is not a reason to waste it.

**7.12 Scope creep dressed as art.** This direction authorises **no new
mechanic**. No node depletion state, no weather system, no time of day, no
lighting engine, no wind simulation. GH-08's debris is 3–4 frames on the
existing `onActivityBeat` hook — not a particle system. Art must not introduce
mechanics (STYLE_SPEC, the rule that outranks everything else there).

**7.13 Self-certification, and the wrong QA artefact.** The author never writes
the verdict (M-04). More specifically: **every previous round judged props in
isolation, which is how twelve inventory icons reached the stage.** The verdict
artefact for this work is a **composited stage plate** — backdrop, subject,
contact shadow and the Traveler at his real strike frame, assembled at the exact
layout numbers in §1.1, screenshotted at device scale — reviewed blind from a
neutral staging. A subject that passes alone and fails in the frame has failed.

**7.14 Shipping Round 1 and Round 2 as one batch.** Eighteen plates is already
at the edge of what one review can hold. Round 1 goes to device and is accepted
before Round 2 begins.

---

## 8. Open, and not to be decided silently

| Ref | Question | Owner |
|---|---|---|
| **Q — density** | §3's L-18a amendment. **Blocks all generation.** | Owner ruling, then `DECISIONS/` |
| **Q — project backdrops** | B8–B14 route by *completed project*. That is a new routing key (`node → project → backdrop`) and a small state read on the stage. Confirm it is wanted before Round 2. | Owner / Technical Director |
| **Q — GH-09 gutters** | The plate family stays 384 wide; the ≈28 dp gutters at 440 dp are a packaging fix (edge extension in `package-art.js`), not an authoring one. Not resolved here. | Separate fix |
| **Q — craft parity** | The density ruling binds the craft stage. Three station plates at 48 × 48, sequenced after Round 1. | Follow-on |

Nothing else in `ART_DIRECTION.md`'s UNRESOLVED list is touched by this
document, and no value it does not contain has been inferred (`RULES.md` G-3).
