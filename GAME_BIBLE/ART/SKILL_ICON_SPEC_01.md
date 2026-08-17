# Skill Icon Spec 01 — the five skills as one family

**Status:** FROZEN for the OD-04 generation round, 2026-08-17
**Graduates:** `JOURNAL/OPEN_QUESTIONS.md` **OD-04**
**Governs:** `assets/ui/v1/skill_*.png`
**Subordinate to:** `GAME_BIBLE/ART/ART_DIRECTION.md`,
`GAME_BIBLE/ART/PIXEL_ART_CRAFT_SPEC.md`

---

## 0. Why this document exists before any asset does

`OD-04` is explicit: *"This is an **art workstream with a shared specification**,
not five unrelated icon generations,"* and *"Do not generate replacement assets"*
until the specification settles what makes them a family.

That instruction is a diagnosis of how the current set happened. Foraging
shipped alone to fill a gap, four more were added quickly so it would not read as
a stray decoration, and the result is *five drawings that happen to be the same
size*. Visual QA could not reliably separate the cooking pot from the smithing
anvil at icon size.

So the acceptance case is fixed **before** the round: the pot/anvil confusion is
the thing the new set has to beat.

---

## 1. Where these are seen, and at what size

| Surface | Size | Context |
|---|---|---|
| Skills screen, skill card header | 12 × 12 native, **×2** | Beside the skill name, in the skill's own hue |
| Character screen, skill rows | 12 × 12 native, **×2** | A 26 dp rail, left of the name |
| Gather card, skill chip | 12 × 12 native, **×2** | Inside a chip, beside the skill name |

**×2 is the verdict scale.** `MISTAKES.md` M-05: ×8 is inspection only, and a
pass awarded at inspection scale is not a pass. A review set without a ×2 view
is **returned unreviewed**.

**Every surface carries a text label.** That is a real constraint and it cuts
both ways: an icon does not have to *name* the skill unaided, so it may be
abstract — but it must not confidently name the **wrong** noun, because a
confident wrong read fights the label instead of supporting it.

---

## 2. The family rules — what makes these five one set

Shared, non-negotiable across all five:

| Property | Rule |
|---|---|
| **Canvas** | 12 × 12, native. Not 16, not 14. The rail and the chip are built for it. |
| **Occupancy** | The subject fills **8–10 of the 12 rows**, centred, with at least one clear row of margin top and bottom. A set where one icon is flush and another floats reads as two sets. |
| **Silhouette** | One closed, readable mass. **No detached elements** — a spark, a crumb, a floating leaf is 1–2 px at native and becomes noise at ×2. |
| **Outline** | Single dark contour, one pixel, all the way around. Never doubled, never partial. |
| **Interior** | **Two interior values and no more** — a lit face and a shadowed face. A third value inside a 10-row shape is mush. |
| **Light** | From the upper left, on every icon, without exception. |
| **Background** | Fully transparent. No plate, no disc, no frame. The surfaces supply their own containers. |
| **Perspective** | Front-on or very slightly above. **No isometric, no three-quarter.** Two icons at different angles read as two families however well drawn. |
| **Colour** | See §4 — the hue does not do the identifying. |

### The one that is easiest to get wrong

**No detached elements.** It is the rule most likely to be broken in the name of
legibility — a spark off the anvil, steam off the pot, a chip off the pick — and
each one costs a pixel of contour somewhere else. At 12 × 12 the silhouette is
almost the entire signal.

---

## 3. Semantic briefs — what each must read as

Each entry states the read to achieve, the **construction**, and the
misidentification that fails it. Construction is stated positively:
`PIXEL_ART_CRAFT_SPEC.md` §7 — enumerate the parts and how they attach; positive
construction beats forbidding the wrong answer.

### Foraging — *gathering growing things by hand*

- **Construction:** a small leafy sprig rising from a narrow base, three broad
  rounded leaves fanning from a single central stem, the lowest pair angled down
  and outward, the top leaf upright. Widest across the leaves, narrow at the
  foot.
- **Must not read as:** a tree, a whole plant in a pot, a flower, a herb bundle
  tied with string.
- **The distinguishing move:** leaf mass at the **top**, stem visible at the
  bottom. A shape that is wide at the base is a bush.

### Woodcutting — *felling timber*

- **Construction:** a felling axe seen from the side, one straight vertical
  handle running the full height slightly off-centre, and a single asymmetric
  axe head at the top — a broad curved cutting edge on one side only, the handle
  passing visibly through the head.
- **Must not read as:** a battle axe (double-bitted, symmetric), a hammer, a
  pickaxe, a generic weapon.
- **The distinguishing move:** the head is **on one side only**. Symmetry is
  what turns an axe into a weapon, and Mining owns the symmetric head.

### Mining — *breaking rock*

- **Construction:** a pickaxe seen from the side, one straight vertical handle
  slightly off-centre, and across the top a **symmetric** head — an equal spike
  reaching left and an equal spike reaching right, both tapering to a point, the
  handle passing visibly through the centre.
- **Must not read as:** a hammer (a hammer's head is a block, not two points), an
  axe, an anvil.
- **The distinguishing move:** **two points, no faces.** A flat face anywhere on
  the head makes it a hammer, and a hammer belongs to Smithing.

### Smithing — *shaping metal*

- **Construction:** an anvil seen from the side, front-on: a heavy flat top
  surface running the full width, one tapering horn projecting from the left end
  only, a narrow waist beneath the top, and a wide solid base foot. Widest at the
  top and the foot, pinched in the middle.
- **Must not read as:** a cooking pot, a hammer, a cauldron, a block.
- **The distinguishing move:** the **pinched waist and the one-sided horn**. This
  is the acceptance case — see §5. A silhouette that is round-bottomed is a pot.

### Cooking — *preparing food over heat*

- **Construction:** a cooking pot seen from the side, front-on: a rounded
  body wider at the shoulder than at the base, a distinct rim lip running across
  the top wider than the body, and one small handle loop on each side at the
  shoulder. Widest at the rim, narrowing to a small flat base.
- **Must not read as:** an anvil, a cauldron on legs, a mug, a bowl.
- **The distinguishing move:** the **round body and the wide rim**. No legs — legs
  add detached elements and push it toward a cauldron.

**Smithing and Cooking are the pair under test.** Their briefs are deliberately
opposed on the one axis a 12-row silhouette can carry: the anvil is *pinched in
the middle and flat on top*; the pot is *round in the middle and open at the
top*. If the round finds them still confusable, the fix is to push that opposition
further, not to add interior detail.

---

## 4. Colour, and why the hue may not do the work

`StrideColors.forSkill` already gives each skill a hue, and the surfaces apply
it. That makes a tempting shortcut available: five identical shapes, five
colours, done.

**It is forbidden.** Two reasons, and the second is the real one:

1. Colour is not available to every reader. A set that is only separable by hue
   fails anyone with a colour vision deficiency, and the app has no other
   affordance to fall back on.
2. It would hide the failure this round exists to fix. The pot and the anvil
   would be "distinct" in a way that vanishes the moment either appears outside
   its own coloured context.

**Acceptance is judged in greyscale first.** If two icons are confusable with the
hue removed, they have not passed, regardless of how they look in situ.

The icons are authored in the warm earthy palette the rest of the art uses. The
skill hue is applied by the **surface**, around and behind the icon, not baked
into the sprite.

---

## 5. Acceptance — how the round is judged

Generated as **one round**, all five, and compared **against each other** rather
than approved one at a time. That is `OD-04`'s instruction and it is the
procedural half of the fix: the current set exists because five icons were each
individually acceptable.

| # | Gate | Method |
|---|---|---|
| **A1** | **Blind semantic read at ×2** | The five, unlabelled, in randomised order, shown to a reviewer with no access to the prompts, the filenames, or this document. They name what they see. (`MISTAKES.md` M-04 — the perceptual law.) |
| **A2** | **The pot/anvil case** | Cooking must not be named as smithing, and smithing must not be named as cooking. **This is the acceptance case and it is pass/fail.** |
| **A3** | **Greyscale separability** | All five desaturated, at ×2. Any pair confusable here fails. |
| **A4** | **Family coherence** | Shown together: do these look authored by one hand, on one day, for one set? Judged on §2's shared properties, not on taste. |
| **A5** | **In situ** | Rendered on the Skills card header, the Character rail and the gather chip, at ×2, with their real labels — the three surfaces, not a contact sheet. |
| **A6** | **No detached pixels** | Counted, not eyeballed: every non-transparent pixel must be 4-connected to the main mass. |

**A confident wrong noun fails.** "I don't know what that is" is a weaker result
than a correct read and a **better** one than a wrong read, because the label
rescues the first and fights the second.

**The author does not write the verdict.** `AUTHOR ASSESSMENT` and `QA VERDICT`
are separate lines and the same agent may not write both (`MISTAKES.md` M-04).

---

## 6. Production route

Per `PIXELLAB_STYLE_SPEC_01.md`: icons are generated at **48 × 48 native** and
reduced, never authored at 12 × 12 directly — the model has no useful control at
twelve pixels. Once a silhouette is right, **targeted inpaint or edit, never a
full reroll**; a reroll discards the one thing that was working.

The prompt shape is `PIXEL_ART_CRAFT_SPEC.md` §7:

```
<noun phrase> <presentation clause>: <construction clause> — <style clause>
```

with the construction clause taken from §3 above and the style clause appended
verbatim from `PIXELLAB_STYLE_SPEC_01.md` §7.2.

**Reduction to 12 × 12 is where icons die.** A 48 × 48 sprite scaled by an
averaging filter becomes grey soup at 12. The reduction must preserve the
contour as a hard one-pixel line, which means nearest-neighbour with the
silhouette checked afterwards, and A6 counted on the **reduced** file rather
than on the source.

---

## 7. What is explicitly out of scope

- **A sixth icon.** Five skills are frozen (`DECISIONS/0004`, `0017`).
- **Animated or state variants.** No hover, no disabled, no earned/unearned pair.
- **A skill icon on the World or Inventory screens.** Three surfaces, listed in
  §1, and no more.
- **Redesigning `StrideColors.forSkill`.** The hues are shipped and are not this
  round's question.
