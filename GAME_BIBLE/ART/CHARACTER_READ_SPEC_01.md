# Character Read Spec 01 — the base Traveler

**STATUS: FROZEN**
**OWNER APPROVED**
**DATE: 2026-08-14**
**PURPOSE: the pass/fail visual read contract for the next base Traveler attempt**

---

## 0. What this document is

**This is a target, not evidence.** It states what the next Traveler must *read
as*. It does not certify that any asset has met that target, and no Traveler has
graduated. There is deliberately no `TRAVELER_BASE.md`; a base-character asset
contract becomes valid only after a Traveler visually graduates.

**Frozen means frozen.** It was frozen before the Character Pixel Artist started,
which is the whole point — an implementer who watches its own spec being
finalised has already seen the expected answers. Changing it requires the owner
(`STUDIO_OPERATIONS/CHANGE_MANAGEMENT.md`), not an implementation convenience.

**Ownership.** This document owns the character read contract and nothing else
(`RULES.md` G-7). Visual direction locks live in `ART_DIRECTION.md`; craft rules
in `PIXEL_ART_CRAFT_SPEC.md`; content and equipment in
`GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md`. Those are referenced here, not
copied.

**Provenance.** Authored by the Character Visual Designer across a two-phase
task: a blind image-first diagnosis, frozen before any semantics were revealed,
then the spec. In the blind phase it named the intended backpack **0 times out of
4** and the intended sword **once out of 4 with low confidence** — reproducing
`VISUAL_STUDIO_BASELINE_AUDIT_01` with a fresh agent and different labels. That
is the problem this contract exists to solve.

### Expected answers are withheld from Visual QA

The right-hand column below is **not shown to the critic** during the blind
phase. QA answers from the render, then answers are compared. A critic that has
seen the expected answer is measuring its own memory
(`STUDIO_OPERATIONS/AGENT_ORCHESTRATION.md` — *The READ SPEC*).

---

## 1. The owner locks this contract implements

Canonical in `ART_DIRECTION.md` L-1 … L-5. Restated here in brief because the
artist works from this document; **`ART_DIRECTION.md` remains the source.**

- **L-1 — Identity.** Masculine-presenting ordinary capable Traveler: practical,
  grounded, capable, approachable, road-worn, interesting enough to be the
  persistent player character. Excluded: heroic power pose, bulky fighter
  silhouette, chibi or exaggerated proportions, premium fantasy ornament,
  armoured appearance in starter clothing, MMO raid-character language.
- **L-2 — Proportion.** Approximately **1 : 4.5** head-to-body. The character must
  **not** be widened or enlarged to make equipment fit.
- **L-3 — Canvas.** **24 × 34.** Not to be widened. See §7.
- **L-4 — Equipment.** A small canvas backpack; a Training Sword sheathed at the
  **character's left hip**, which renders on the **viewer's right** under the
  established turn (`PIXEL_ART_CRAFT_SPEC.md` CR-3); **hands empty.** Neither item
  may be removed or substituted because it is hard to draw.
- **L-5 — Signature.** No decorative trademark detail. Recognition must be earned
  first through silhouette, proportion, gesture, clothing shape, equipment
  relationship and restrained colour placement. See `JOURNAL/OPEN_QUESTIONS.md`
  Q-02.

**Clothing canon, unchanged and not to be extended:** oat/sand tunic family,
slate/brown trousers, belt, wrapped boots, small canvas pack, Training Sword.
Tunic length, sleeve extent, hem shape, belt position and value placement are the
artist's within that. No new garments.

**Palette and rendering treatment remain UNRESOLVED.** This document states
required separation *outcomes*, never colours or methods.

---

## 2. The design architecture

### Separate loads by HEIGHT, not by SIDE

The diagnosed failure was a three-object allocation problem solved
**horizontally**, in one row band, which ran out of columns — the audit's measured
26-against-24. **Columns are scarce only at chest height. Rows are not scarce
anywhere.**

| Register | Occupant | Its silhouette job |
|---|---|---|
| **Above / behind the far shoulder** | the **backpack**, cresting behind the far shoulder | breaks the shoulder line on one side |
| **Chest / waist** | **both arms, with priority** | the torso / gap / arm rhythm that proves this is a body |
| **Near hip / thigh** | the **sheathed Training Sword** | a hanging taper below the belt |

Peak column demand never co-occurs. At the shoulder rows the arms have not
reached their outer extent and the sword does not exist; at the chest rows the
pack is behind the torso and the sword does not exist; at the hip rows the pack
has ended and the far arm has narrowed toward the wrist.

**The widest horizontal cross-section must occur at the shoulders, and the shape
must narrow through chest and waist.** A human silhouette widens at the top and
narrows in the middle. Cargo at the middle inverts that, and the inversion is
what produced the crossbar.

### Occlusion over adjacency

> **An object partly hidden behind the body is read as being behind the body. An
> object entirely visible beside the body is read as being beside the body.**

The failed pack was *fully visible* — every edge drawn — and that completeness is
precisely why it could not be a pack. **A pack that shows all four of its edges is
a crate; a pack that shows two of them is on someone's back.**

The same logic governs the sword: the belt must visibly pass over the point where
the scabbard attaches. An object whose attachment is visible is worn; an object
drawn complete against a torso is a sticker.

**Neither principle converts to pixel coordinates.** They are allocation and
semantics; construction is the artist's.

---

## 3. The approved gesture — settled asymmetric hang

**Desired read: a person who has been walking and has stopped.** Not posing, not
waiting, not on guard.

- Weight primarily on the **near** leg; far leg trailing slightly back
- **Both arms hang free and unraised**
- **Both hands visible and empty**
- Near arm slightly forward and clearly separated from the torso
- Far arm slightly back and quieter
- A small natural head turn supporting the three-quarter direction

**The prior hand-at-belt gesture is rejected as the default base gesture.** It
consumes one hand-and-arm terminus and crowds the same hip register the sword
needs — buying charm and paying for it with the two hardest reads in this
contract.

**Hard requirement: the near hand and the sword hilt must not share the figure's
outer contour.** That tangency is what produced *hatchet*, *mug* and *trowel*.
Separation by rows or by contour step is preferred over separation by overlap,
because overlap-based separation inverts under rotation (§8).

**This is not a dramatic pose.** Do not escalate it into one.

---

## 4. Equipment and material semantics

### Backpack

- **Soft travel gear**, not armour and not rigid plate
- Belongs **behind and on the back**, cresting slightly above the **far** shoulder
- **May be — and should be — partially occluded.** It must never present a closed
  outline of itself
- Visible mass **smaller than the head**; not the brightest thing in the figure
- The **strap must visibly originate over a shoulder** before crossing the chest.
  This is what converts a mass behind the body into a mass worn by the body
- **If it fails to read, the first correction lever is the strap and crest
  relationship — never brightness, never enlargement.** Enlarging it rebuilds the
  plank

Every prior misread — shield, pauldron, plank, crate, shelf, bedroll, suitcase,
bundle — shares one grammar: straight lines, level edges, right angles, closed
outlines, regular banding. The corrections are the inverse of that grammar.

### Training Sword

- Reads as **one sheathed sword**, a single coherent object
- **Fittings may read as metal.** The **scabbard body must not** — a long light
  edge down the object converts a sheath into a naked blade, which is the failure
  `PIXEL_ART_CRAFT_SPEC.md` CR-42 was paid for. Metal appears only in the fittings
- **Belongs physically to the belt and hip**, with a visible attachment
- **Elongation is preferred over lateral bulk.** Length is the cheapest and
  strongest sword cue and it costs rows, which this canvas has
- **Not held.** Hands empty
- Short, plain, unremarkable. **Do not solve it by making it large** — that
  produces the bulky-fighter silhouette L-1 excludes

Prior misreads — axe, hatchet, hammer, adze, trowel, mug, canteen, generic grey
object — came from the widest part being at the top, from insufficient length, and
from a uniform value with no internal event.

### Arms and hands

- **Both arms traceable** from shoulder to hand
- **Both hands locatable**, and **hands empty**
- **Neither arm may depend on equipment to define its boundary.** If a contour
  does duty as both the edge of an arm and the edge of the pack, the arm has not
  been drawn — the equipment has, and the viewer will read the equipment
- Articulation through **value, not through a hole**. A separation drawn as a gap
  punched through the torso reads as a slot (CR-13)
- **Skin value must be present below the head in the image.** Its complete
  absence is the most objective single defect in the failed family

### Material separation — all gated at ×2, and CR-45 applies

**Within the figure:** skin vs tunic · tunic vs pack · strap vs both tunic and
pack along its entire run · **scabbard vs trousers** *(highest internal risk —
darkening it away from the tunic walks it into the trousers, and lightening it
away from the trousers walks it into the tunic)* · sword fittings vs scabbard
body · hand vs sleeve, trouser and scabbard · boot vs trouser · belt vs tunic ·
near leg vs far leg · hair vs face.

**Against the world — the class that gets missed:** the figure's outer contour
must stay continuous against **grass, earth path and a dark trunk simultaneously**
in the true in-context view; pack against grass and foliage; scabbard against the
trunk and against path shadow; boots and trousers against the path. The figure
must **win its own frame** — it is the persistent player character and does not
compete with terrain on equal terms.

**An asset separated against its own palette and never against the world it
stands in is the CR-45 failure.** The isolated view cannot certify this.

---

## 5. How to read the labels

| Label | Meaning |
|---|---|
| **[LB]** | **LOAD-BEARING — the pass/fail gate.** If these fail, the rest is not worth scoring |
| **[ADV]** | Advisory / diagnostic. Useful signal; does not decide the outcome |
| **[×2]** | Judged at the ×2 play-scale proxy — **the verdict view** |
| **[CTX]** | Judged in the **true** in-context view at ×2. An enlarged crop is not a context view |
| **[SIL]** | Judged silhouette-only, interior stripped, at ×2 |
| **[DEF]** | Deferred — the evidence required does not exist yet |
| **[GUARD]** | Guard item. **Expected answer is *no*.** A *yes* is a finding against the work |

**Everything not marked [LB], [DEF] or [GUARD] is [ADV].**

### Counts

| | |
|---|---|
| **Total items** | **102** |
| **Load-bearing [LB]** | **28** |
| Deferred [DEF] | 4 — P1, P4, R3, R4 |
| Guard [GUARD] | 2 — T5, T6 |
| Advisory [ADV] | 68 |

Of the 28 load-bearing: **17 gated at ×2 only**, **6 at [CTX]** (one of which,
O2, is also gated at ×2), **5 at [SIL]**.

> **A note on these numbers.** The Character Visual Designer reported "76 items,
> 24 load-bearing". An independent recount at freeze found **102 and 28**. The
> items themselves were sound; only the summary arithmetic was wrong. The gate was
> **not trimmed to 24** — reducing a gate to match a miscount would weaken it for
> an arithmetic reason, which is the shape of `RULES.md` G-4. All 28 stand.

---

## 6. THE GATE — the 28 load-bearing items

**This is the pass/fail contract.** Visual QA scores these. Everything in §9 is
advisory unless listed here.

| # | ID | Question | Expected | Gate |
|---|---|---|---|---|
| 1 | **A1** | What kind of person is this? | an ordinary traveller — see §6.1 | [×2] |
| 2 | **C1** | With all colour removed, does the black shape read as a person? | yes | [SIL] |
| 3 | **C2** | Does the shape have a horizontal bar or crossbeam across the chest? | **no** | [SIL] |
| 4 | **C3** | Does the shape appear to be carrying something? | yes | [SIL] |
| 5 | **D2** | Is the figure holding anything in either hand? | **no** | [×2] |
| 6 | **G1** | How many arms can you find? | two | [×2] |
| 7 | **G2** | Can you follow each arm from shoulder to hand? | yes, both | [×2] |
| 8 | **G4** | Could either arm be mistaken for the edge of a bag, board or panel? | **no** | [×2] |
| 9 | **H1** | How many hands can you find? | two | [×2] |
| 10 | **H2** | Are both hands still findable at play scale in the scene? | yes | [CTX] |
| 11 | **K1** | What object is visible on the figure's back? | a small travel backpack | [×2] |
| 12 | **K2** | Is that object behind the figure, or beside it? | behind | [×2] |
| 13 | **K3** | Could it be a shield, crate, board, suitcase or shoulder plate? | **no, none of those** | [×2] |
| 14 | **K5** | Is a strap visible, and does it pass over a shoulder? | yes, over the nearer shoulder and across the chest | [×2] |
| 15 | **K9** | At play scale in the scene, can you still tell there is something on the back? | yes | [CTX] |
| 16 | **L1** | What is hanging at the figure's viewer-right hip? | a sheathed sword | [×2] |
| 17 | **L2** | Is the blade exposed, or covered? | covered — it is in a scabbard | [×2] |
| 18 | **L3** | Could it be an axe, hatchet, hammer, trowel, mug or canteen? | **no, none of those** | [×2] |
| 19 | **L4** | What is the object attached to? | the belt — it hangs from it | [×2] |
| 20 | **L9** | At play scale in the scene, can you still tell there is a sword at the hip? | yes | [CTX] |
| 21 | **M1** | Which side of the figure is nearer to you? | the viewer's right | [×2] |
| 22 | **M4** | Does anything about the figure contradict which way it is turned? | **no** | [×2] |
| 23 | **N1** | Which way is the torso facing? | toward the viewer, angled to the viewer's right | [×2] |
| 24 | **O2** | Can you tell the scabbard from the trousers? | yes | [×2] [CTX] |
| 25 | **S1** | At play scale in the scene, does this read as a person before any detail? | yes | [CTX] |
| 26 | **S2** | At play scale, does the figure keep a continuous readable outline against grass, path and tree? | yes | [CTX] |
| 27 | **T1** | In the solid shape alone, is this a person? | yes | [SIL] |
| 28 | **T2** | In the solid shape alone, is this person carrying something? | yes | [SIL] |

### 6.1 — A1 interpretation boundary

The semantic distinction is **general traveller / adventurer** versus **specific
profession, combat archetype, or social role.** Do not overfit exact vocabulary.

**ACCEPT** — traveller · adventurer · wanderer · wayfarer · ordinary fantasy
traveller · practical road-going character · and any wording that clearly
communicates *an ordinary person equipped for travel or adventure* without
implying a specialised combat, magic, or profession identity.

**REJECT** — any answer whose **primary** identity is: knight · soldier · guard ·
warrior · armoured fighter · mage · wizard · rogue · assassin · merchant · farmer
· blacksmith · miner · lumberjack · priest · noble · hero · champion.

**"Villager" or "peasant" alone is NOT sufficient** — it loses the
capable-traveller / adventure read that L-1 requires.

---

## 7. Canvas — 24 × 34, and the only way it reopens

**Verdict: (A) — 24 × 34 should be sufficient with better mass allocation.**
Owner-accepted. `JOURNAL/OPEN_QUESTIONS.md` Q-03 is **closed for this attempt.**

The audit's 26-against-24 measured **one row** in an arrangement where the pack,
both arms and the torso all demanded width in the same band. That is a real
constraint on that arrangement, not on the canvas. §2 removes the collision.

**Q-03 reopens only if one of these three is demonstrated in an actual compliant
render — argued, not asserted — while holding L-1, L-2 and L-4:**

1. At the widest chest row, torso plus both arms plus the near-side background
   notch cannot be accommodated without either **widening the figure** (forbidden
   by L-2) or **eliminating the notch** (which reinstates the diagnosed failure).
2. At the hip rows, the near hand and the scabbard **cannot be separated by any
   means** — rows, contour, or overlap — without one leaving the canvas or merging
   with the leg.
3. The scabbard **cannot achieve enough length** to escape the mug / canteen read
   while remaining below the belt and above the boot.

> **"More pixels would be easier" is not a reopening condition.**

**Most likely pressure point: condition 3.** The hip register is where this is
genuinely tight, and it is the one to watch.

**Do not widen the canvas now.**

---

## 8. Eight-direction obligations

The other seven views are **not** designed here. These are the obligations this
base read incurs, recorded so the eight-direction pass does not meet them as
surprises. Template: `GAME_BIBLE/ART/templates/EIGHT_DIRECTION_CHARACTER.md`.

- **Pack on the back rotates coherently** through all eight cells. A pack held
  laterally at chest height has no coherent rotational behaviour at all — the
  failed placement was not merely wrong here, it was unbuildable across the set.
  This is an independent argument for §2.
- **Sword side is fixed by canon** (character's left hip), so it is substantially
  or entirely **occluded by the body in one side view**. That is physically
  correct. **It must not be solved by mirroring** — the template forbids mirroring
  precisely because it flips asymmetric equipment to the wrong side. Whether a
  sliver of scabbard tip stays visible is a cross-direction cohesion decision to
  be taken **once for the whole sheet**, not improvised per view.
- **Overlap-based hand/hilt separation inverts** in the opposite diagonal, where
  the hip becomes nearer than the hand. Row-based or contour-based separation is
  more portable (§3).
- **The near/far arm distinction and the trailing leg must be re-derived per
  view, never flipped.** A flip silently reverses the character's handedness and
  the sword's hip.
- **The asymmetric hem's lower side is a property of the garment** and stays
  consistent across all eight views, or it becomes eight different garments.
- **The head is not a fixed stamp.** The hair mass carried down the far side must
  change sides per view, and the head turn differs per view.

---

## 9. The full read spec

**Advisory unless the item appears in §6.** Reproduced from the Character Visual
Designer's proposal; semantic content unaltered, labels normalised to §5.

### A — Character identity
| ID | Question | Expected | Labels |
|---|---|---|---|
| A1 | What kind of person is this? | an ordinary traveller — not a knight, soldier, mage or hero. See §6.1 | [LB] [×2] |
| A2 | Does this person look equipped for a journey on foot? | yes | [ADV] [×2] |
| A3 | Does this figure look armoured? | no | [ADV] [×2] |
| A4 | Does the figure look wealthy, noble, ceremonial or ornamented? | no | [ADV] [×2] |
| A5 | Does the figure read as an adult, masculine-presenting? | yes | [ADV] [×2] |
| A6 | Do the proportions look exaggerated — oversized head, tiny body, heroic musculature? | no | [ADV] [×2] |

### B — Body and proportions
| ID | Question | Expected | Labels |
|---|---|---|---|
| B1 | Roughly how many head-heights tall is the figure? | about four and a half | **[ADV] — STRUCTURAL COMPLIANCE.** See §9.1 |
| B2 | Does the figure look broad, bulky or heavily built? | no — ordinary build | [ADV] [×2] |
| B3 | Is the figure wider at the chest than at the shoulders? | no | [ADV] [×2] [SIL] |

### C — Silhouette
| ID | Question | Expected | Labels |
|---|---|---|---|
| C1 | With all colour removed, does the black shape read as a person? | yes | [LB] [SIL] |
| C2 | Does the shape have a horizontal bar or crossbeam across the chest? | no | [LB] [SIL] |
| C3 | Does the shape appear to be carrying something? | yes | [LB] [SIL] |
| C4 | Is the shape left-right symmetric? | no | [ADV] [SIL] |
| C5 | Is there a gap of background between the torso and at least one arm? | yes | [ADV] [SIL] |
| C6 | Does anything break the shoulder line on one side only? | yes, the viewer's left | [ADV] [SIL] |
| C7 | Are there isolated single-pixel holes or specks in the shape? | no | [ADV] [SIL] |
| C8 | Where is the widest part of the shape? | at the shoulders, not the chest or waist | [ADV] [SIL] |

### D — Gesture
| ID | Question | Expected | Labels |
|---|---|---|---|
| D1 | Is the figure standing still, or moving? | standing still, at rest | [ADV] [×2] |
| D2 | Is the figure holding anything in either hand? | no | [LB] [×2] |
| D3 | Are the two arms in an identical mirrored pose? | no | [ADV] [×2] |
| D4 | Is the figure posed heroically or aggressively? | no — calm and settled | [ADV] [×2] |
| D5 | Does the figure look planted and balanced on the ground? | yes | [ADV] [×2] |

### E — Head and neck
| ID | Question | Expected | Labels |
|---|---|---|---|
| E1 | Which way is the head facing? | slightly toward the viewer's right | [ADV] [×2] |
| E2 | Is a face visible, or is the head all hair? | a face is visible | [ADV] [×2] |
| E3 | Is the figure wearing a hat, hood or helmet? | no | [ADV] [×2] |
| E4 | Is there a visible neck between head and shoulders? | yes | [ADV] [×2] |

### F — Shoulders
| ID | Question | Expected | Labels |
|---|---|---|---|
| F1 | Can you locate both shoulders? | yes | [ADV] [×2] |
| F2 | Are both shoulders at the same height? | no — one sits slightly higher | [ADV] [×2] |
| F3 | Does either shoulder look plated, padded or armoured? | no | [ADV] [×2] |

### G — Arms
| ID | Question | Expected | Labels |
|---|---|---|---|
| G1 | How many arms can you find? | two | [LB] [×2] |
| G2 | Can you follow each arm from shoulder to hand? | yes, both | [LB] [×2] |
| G3 | Does either arm read as a plain vertical strip, bar or strap? | no | [ADV] [×2] |
| G4 | Could either arm be mistaken for the edge of a bag, board or panel? | no | [LB] [×2] |
| G5 | Can you tell where sleeve ends and forearm begins? | yes, on at least the nearer arm | [ADV] [×2] |
| G6 | Is one arm clearly nearer to you than the other? | yes | [ADV] [×2] |

### H — Hands
| ID | Question | Expected | Labels |
|---|---|---|---|
| H1 | How many hands can you find? | two | [LB] [×2] |
| H2 | Are both hands still findable at play scale in the scene? | yes | [LB] [CTX] |
| H3 | Does either hand disappear into clothing, the sword, or the other hand? | no | [ADV] [×2] |
| H4 | Are the hands relaxed and open, or clenched/gripping? | relaxed and open | [ADV] [×2] |

### I — Torso and tunic
| ID | Question | Expected | Labels |
|---|---|---|---|
| I1 | What is the figure wearing on its upper body? | a plain tunic or short coat, belted | [ADV] [×2] |
| I2 | Does the torso read as a flat rectangular slab? | no | [ADV] [×2] |
| I3 | Is a belt visible at the waist? | yes | [ADV] [×2] |
| I4 | Is the clothing decorated — emblem, trim, pattern, badge? | no | [ADV] [×2] |
| I5 | Does the garment read as cloth, or as metal/plate/leather armour? | cloth | [ADV] [×2] |

### J — Legs and stance
| ID | Question | Expected | Labels |
|---|---|---|---|
| J1 | How many legs can you find? | two | [ADV] [×2] |
| J2 | Are the two legs identical? | no | [ADV] [×2] |
| J3 | Is the figure wearing boots, and can you tell where boot ends and trouser begins? | yes to both | [ADV] [×2] |
| J4 | Do both feet meet the ground at the same level? | no — slightly offset | [ADV] [×2] |

### K — Backpack
| ID | Question | Expected | Labels |
|---|---|---|---|
| K1 | What object is visible on the figure's back? | a small travel backpack | [LB] [×2] |
| K2 | Is that object behind the figure, or beside it? | behind | [LB] [×2] |
| K3 | Could that object be a shield, a crate, a board, a suitcase or a shoulder plate? | no, none of those | [LB] [×2] |
| K4 | Does the pack look soft and fabric, or hard and rigid? | soft, fabric | [ADV] [×2] |
| K5 | Is a strap visible, and does it pass over a shoulder? | yes, over the nearer shoulder and across the chest | [LB] [×2] |
| K6 | Does the pack look worn by the figure, or attached next to it? | worn | [ADV] [×2] |
| K7 | Is the pack bigger than the figure's head? | no | [ADV] [×2] |
| K8 | Is the pack the brightest or most eye-catching thing in the image? | no | [ADV] [×2] |
| K9 | At play scale in the scene, can you still tell there is something on the back? | yes | [LB] [CTX] |

### L — Training Sword
| ID | Question | Expected | Labels |
|---|---|---|---|
| L1 | What is hanging at the figure's viewer-right hip? | a sheathed sword | [LB] [×2] |
| L2 | Is the blade exposed, or covered? | covered — it is in a scabbard | [LB] [×2] |
| L3 | Could that object be an axe, hatchet, hammer, trowel, mug or canteen? | no, none of those | [LB] [×2] |
| L4 | What is the object attached to? | the belt — it hangs from it | [LB] [×2] |
| L5 | Can you see a handle or grip at the top of it? | yes | [ADV] [×2] |
| L6 | Does it read as one object, or several objects near each other? | one | [ADV] [×2] |
| L7 | Is it long and tapering, or short and blocky? | long and tapering | [ADV] [×2] |
| L8 | Is the sword large, ornate or impressive? | no — small and plain | [ADV] [×2] |
| L9 | At play scale in the scene, can you still tell there is a sword at the hip? | yes | [LB] [CTX] |
| L10 | In the silhouette, does something hang from the hip toward the knee? | yes | [ADV] [SIL] |

### M — Near / far read
| ID | Question | Expected | Labels |
|---|---|---|---|
| M1 | Which side of the figure is nearer to you? | the viewer's right | [LB] [×2] |
| M2 | Is the pack on the nearer side or the further side? | the further side | [ADV] [×2] |
| M3 | Is the sword on the nearer side or the further side? | the nearer side | [ADV] [×2] |
| M4 | Does anything about the figure contradict which way it is turned? | no | [LB] [×2] |

### N — Three-quarter orientation
| ID | Question | Expected | Labels |
|---|---|---|---|
| N1 | Which way is the torso facing? | toward the viewer, angled to the viewer's right | [LB] [×2] |
| N2 | Is the figure flat-on, facing straight forward? | no | [ADV] [×2] |
| N3 | Do the head, shoulders, hips and feet all agree on the direction? | yes | [ADV] [×2] |

### O — Material read
| ID | Question | Expected | Labels |
|---|---|---|---|
| O1 | Can you tell the tunic and the pack apart as two different things? | yes | [ADV] [×2] [CTX] |
| O2 | Can you tell the scabbard from the trousers? | yes | [LB] [×2] [CTX] |
| O3 | Is anything on the figure metallic other than small sword fittings? | no | [ADV] [×2] |
| O4 | Do skin, cloth and leather read as different materials? | yes | [ADV] [×2] |

### P — Main-character quality
| ID | Question | Expected | Labels |
|---|---|---|---|
| P1 | Could you pick this figure out of a line-up of five similar villagers? | yes | **[DEF]** — needs a line-up that does not exist |
| P2 | Does the figure hold your attention, or read as generic filler? | holds attention | [ADV] [×2] |
| P3 | Does the figure wear a decorative trademark accessory — scarf, feather, emblem, mark? | no | [ADV] [×2] |
| P4 | If you saw this figure in a different scene, would you recognise it as the same person? | yes | **[DEF]** — needs a second scene that does not exist |

### Q — Future equipment extensibility
| ID | Question | Expected | Labels |
|---|---|---|---|
| Q1 | Are the shoulders and upper arms free of attached equipment? | yes | [ADV] [×2] |
| Q2 | Is the chest free of attached objects other than the strap? | yes | [ADV] [×2] |
| Q3 | Is there visible free space on the belt other than where the sword hangs? | yes | [ADV] [×2] |
| Q4 | Are both hands free and unoccupied? | yes | [ADV] [×2] |
| Q5 | Does any piece of equipment cross or cover a shoulder or elbow joint? | no | [ADV] [×2] |

### R — Eight-direction compatibility
| ID | Question | Expected | Labels |
|---|---|---|---|
| R1 | Does the pack read as sitting centrally on the back, seen offset because the figure is turned? | yes | [ADV] [×2] |
| R2 | Does the sword hang from the hip, rather than across the back or chest? | from the hip | [ADV] [×2] |
| R3 | Is the figure the same individual in every view — same build, clothing, equipment and hem? | yes | **[DEF]** — needs a second view |
| R4 | Is any view a mirrored copy of another, with equipment on the wrong side? | no | **[DEF]** — needs a second view |

### S — Target-scale readability, in context
| ID | Question | Expected | Labels |
|---|---|---|---|
| S1 | At play scale in the scene, does this read as a person before you read any detail? | yes | [LB] [CTX] |
| S2 | At play scale, does the figure keep a continuous, readable outline against grass, path and tree? | yes | [LB] [CTX] |
| S3 | At play scale, does any part of the figure disappear into the ground or into a tree? | no | [ADV] [CTX] |
| S4 | At play scale, is the figure the first thing your eye resolves in the frame? | yes | [ADV] [CTX] |
| S5 | At play scale, does the figure look wide/bulky through the chest? | no | [ADV] [CTX] |

### T — Silhouette-only readability
| ID | Question | Expected | Labels |
|---|---|---|---|
| T1 | In the solid shape alone, is this a person? | yes | [LB] [SIL] |
| T2 | In the solid shape alone, is this person carrying something? | yes | [LB] [SIL] |
| T3 | In the solid shape alone, how many limbs can you separate from the body outline? | at least one arm on the nearer side, plus two legs | [ADV] [SIL] |
| T4 | In the solid shape alone, can you tell which end is the head? | yes | [ADV] [SIL] |
| T5 | In the solid shape alone, can you tell **what** is being carried on the back? | **no — expected** | **[GUARD]** [SIL] |
| T6 | In the solid shape alone, can you tell the hip object is a sword? | **no — expected** | **[GUARD]** [SIL] |

### 9.1 — Notes on reclassified items

**B1 — advisory, structural compliance.** B1 tests conformance with the locked
≈ 1 : 4.5 figure family. That is better verified structurally, source-side, than
by asking a blind viewer to estimate head-height ratios on a 34-pixel figure.
**Not part of the Visual QA pass/fail gate.**

**P1 and P4 — deferred.** Their required evidence does not exist: P1 needs a
comparable line-up, P4 needs a second scene. **Do not fabricate those assets
solely to make these runnable during `CHARACTER_REBUILD_01`.** They become valid
when the project naturally has the comparison material. **They do not block the
rebuild.**

**T5 and T6 — guard items, expected answer *no*.** They exist to stop the
silhouette test demanding semantic information a silhouette cannot realistically
carry at 24 × 34, and to stop the artist enlarging or over-describing equipment so
that every object becomes identifiable in pure silhouette. **A *no* here is the
correct result and must not be recorded as a failure.** An artist who makes T5
answer *yes* has almost certainly rebuilt the plank.

**What silhouette genuinely cannot carry at this size**, and must not be failed
for: that the back load is specifically a *backpack* rather than a bedroll or
satchel; that the hip object is specifically a *sword* rather than a long tool;
any facial, material or garment identification.

---

## 10. Target-scale rules

Canonical in `PIXEL_ART_CRAFT_SPEC.md` §8. The attempt is not reviewable without
the full standard output set: **native · ×2 play-scale proxy · ×8 inspection ·
true in-context · silhouette-only.**

- **×2 is the verdict view.** Judgement happens here.
- **×8 is inspection only** and is never sufficient for graduation.
- **True in-context means the real scene relationship at native and ×2.** An ×8
  crop is not a context view.
- **Silhouette-only is required** for this work.
- **A pass arriving without a ×2 is returned unreviewed.**

`GAME_BIBLE/ART/exploration/CODE_RENDER_01/review_set.js` emits the set.

---

## 11. Visual QA blind-question order

Ask with **no vocabulary, no source, no labels and no expected answers supplied.**

**At ×2, isolated — first and unprompted:**
1. Describe what you see. What kind of person is this?
2. Is the figure holding anything?
3. What is on the figure's back? *(open — offer no options)*
4. What is at the figure's viewer-right hip? *(open — offer no options)*
5. How many arms can you find, and can you follow each from shoulder to hand?
6. How many hands can you find, and where are they?
7. What is the figure wearing?
8. Which way is the torso facing?
9. Which side of the figure is nearer to you?
10. Does the figure look balanced and planted?
11. Could the object on the back be a shield, crate, board, suitcase or shoulder plate?
12. Could the object at the hip be an axe, hammer, trowel, mug or canteen?
13. Is the blade exposed or covered?
14. What is the hip object attached to?
15. Does the equipment look worn, or attached beside the figure?
16. Does the figure look armoured?
17. Is anything about the figure ornamented or decorative?

**Silhouette-only, ×2:**
18. Is this a person?
19. Is this person carrying something?
20. Is there a horizontal bar across the chest?
21. How many limbs can you separate from the body?
22. Which end is the head?
23. Does anything hang from the hip?
24. *(Guard)* Can you tell **what** is on the back, or **what** hangs at the hip?
    *Expected: no. A yes is a finding against the work, not for it.*

**True in-context, ×2 — the critical gate:**
25. Before any detail, does this read as a person?
26. Can you still tell there is something on the back?
27. Can you still tell there is a sword at the hip?
28. Are both hands still findable?
29. Does the figure keep a clear outline against grass, the path, and the tree?
30. Does any part of the figure disappear into the background?
31. Is the figure the first thing your eye lands on?

**Deferred, when the evidence exists:**
32. Shown alongside four other villagers, can you identify this figure again?
33. Shown again later in a different scene, do you recognise it as the same person?

### The ordering rule — not optional

**Questions 3 and 4 must be asked before 11 and 12, and never reversed.**
Offering the option list first destroys the only measurement that matters. QA must
not be given the words *pack*, *sword*, *strap*, *scabbard* or *traveller* before
the subject has answered 1–4 unprompted.

---

## 12. What the Character Pixel Artist must NOT infer

**None of the following is decided by this document, and none becomes decided by
appearing in it.**

- **Any pixel coordinate, width, height, count, or row number.** None appears
  here, deliberately. Allocation is the designer's; construction is the artist's.
- **Palette, hex values, ramp counts, ramp steps.** UNRESOLVED in
  `ART_DIRECTION.md`. Only separation *outcomes* are specified.
- **Rendering treatment** — outlining, selective outlining, dithering, shading
  model, light direction. All UNRESOLVED.
- **Exact tunic length, sleeve extent, hem contour, or which side the hem is
  lower.** Only *that the hem is uneven, and consistent across views*, is required.
- **Number of pack straps**, and whether a flap, seam, tie or interior cluster is
  visible at all.
- **Whether the far arm gets a background notch.** Required on the **near** arm
  only; the far arm may be carried by value.
- **The scabbard's exact angle, and how far down the leg its tip reaches**, beyond
  "conspicuously long, below the belt, above the boot."
- **The method of hand/hilt separation.** Rows or contour are *preferred* for
  rotation-portability (§8); not mandated.
- **The head's pixel construction.** The existing head family is the strongest
  work in the project and should be carried forward **as a family** — but it is
  **not frozen pixel-for-pixel**, and it has never been tested for main-character
  distinctiveness because all four diagnostic figures shared it. **Do not treat
  the head as solved.**
- **Animation, frame counts, idle motion.** Out of scope.
- **The other seven directions.** §8 states obligations; it does not design them.
- **That the four diagnostic figures are templates.** They are evidence. Their
  body silhouette is explicitly **not** frozen and must not be used as a starting
  point. The question is *"what should a successful 24 × 34 Traveler read like"*,
  never *"how do I fix R03C"*.

### The known tension, recorded rather than hidden

**L-5 (no signature) and category P (memorability) pull against each other**, and
L-4's empty hands removes the other cheap memorability device. L-5 is **held**:
this attempt earns recognition from proportion, gesture, hem asymmetry, pack
relationship and stance alone.

If the figure passes every structural and semantic requirement and still fails the
main-character bar, **the thing to revisit is Q-02 — never L-2's proportion or
L-3's canvas.** Buying memorability from size or proportion walks straight into
L-1's excluded bulky-fighter silhouette.

---

## 13. Highest-risk items

1. **K1 / K9 — the backpack.** Scored 0 / 4 in blind review. This design makes it
   *less* visible in order to make it *related*, and that is a deliberate bet. The
   failure mode to watch is under-visibility, and **the wrong fix is enlargement.**
2. **L1 / L3 / O2 — the sword, and scabbard against trousers.** Four simultaneous
   separations for one narrow shape: not metal, not trousers, not tunic, not the
   tree behind it.
3. **G2 / H1 — two traceable arms and two locatable hands.** Never once met.
   There is currently no skin value below the head anywhere in the figure family.
4. **S2 — continuous outline against grass, path and trunk at once, in context.**
   Failed before and went uncaught because the isolated view certified it.
5. **P2 — memorability under L-5.** Partly deferred (P1, P4), and the hardest lock.

---

## Related

- `GAME_BIBLE/ART/ART_DIRECTION.md` — owner locks L-1 … L-15; still EXPLORATION
- `GAME_BIBLE/ART/PIXEL_ART_CRAFT_SPEC.md` — craft rules, CR-41 … CR-45, §8
- `GAME_BIBLE/ART/templates/EIGHT_DIRECTION_CHARACTER.md` — the eight-view template
- `GAME_BIBLE/CONTENT/01_STARTER_CONTENT_BIBLE.md` — equipment and visible loadout
- `STUDIO_OPERATIONS/AGENT_ORCHESTRATION.md` — Visual Studio flow and staging
- `JOURNAL/OPEN_QUESTIONS.md` — Q-02 signature, Q-03 canvas
- `MISTAKES.md` M-04, M-05 — why this contract exists
