# Exploration & Progression Loop 01 — item icon round

**Date:** 2026-08-20
**Method:** `create_image_pixen`, 48 × 48, `no_background`, view `high top-down`,
outline `single color outline` — the settled icon method (PixelLab style spec
§7.2, `PIXELLAB_PROOF_02/PIXELLAB_STYLE_SPEC_01.md`), one generation each.
**Budget context:** launched as 12 of the 22 generations remaining this cycle
(`MILESTONES/EXPLORATION_PROGRESSION_LOOP_01.md`, PixelLab budget note). No
`create_image_pro` and no `edit_image` in this round — a failed read is
re-rolled with pixen or withheld, never edited at 20–40× the cost.

Outputs land in `../out/items/` as `icon_<slug>_48.png`, with disposition in
`../out/items/manifest.json`. Only `status: "accepted"` entries are packaged
by `Scripts/art/package-art.js`; **a withheld icon withholds its item with it**
— the game never ships a blank slab for a first-class reward
(`MILESTONES/EXPLORATION_PROGRESSION_LOOP_01.md`, art integration rules).

## The twelve

The style clause shared by every prompt (§7.2, verbatim in each):

> pixel art game item icon, single dark outline all the way around the object,
> flat matte shading in a few clear steps, light from the upper left, warm
> earthy limited palette, no glow, no emissive light, no bright white specular,
> no cast shadow, no ground, no text, object centred and filling most of the
> frame

(The frost claw swaps "warm earthy" for "cool pale" — it is the one cold-palette
object in the round.)

| # | id | seed | job | object clause (before the style clause) |
|---|---|---|---|---|
| 1 | `oak_plank` | 9101 | `463eb982` | a single sawn oak plank lying diagonally from lower left to upper right: a long flat board of warm honey-brown oak with straight cut edges, visible straight grain lines along its length, two small darker knots, cleanly squared ends |
| 2 | `scrap_metal` | 9102 | `b42dc124` | a small pile of salvaged scrap metal: three bent strips and one broken bracket of dull grey iron stacked loosely, edges nicked and dented, one strip pierced by two empty rivet holes, patches of warm brown rust at the corners |
| 3 | `heat_scale` | 9103 | `c0fe9c12` | a single large reptile scale lying flat: a rounded teardrop-shaped scale of deep ember-orange horn with a darker charred rim, faint concentric growth ridges, the centre a warmer brighter orange fading outward |
| 4 | `ram_wool` | 9104 | `4df23596` | a bundle of shorn ram's wool: a soft rounded mass of thick pale cream wool curls tied once around its middle with a simple dark cord, a few loose curls escaping at the sides, dense and springy |
| 5 | `boar_hide` | 9105 | `b9955cb8` | a single boar hide laid out flat with the bristly fur facing up, seen from directly above: a rough broad oval hide of coarse grey-brown bristle fur with a darker stiff bristle ridge running down the spine, four short stubby leg flaps at the corners, roughly cut ragged edges, no head and no face |
| 6 | `reinforced_pickaxe` | 9106 | `91a9a3b7` | a pickaxe laid diagonally from lower left to upper right: a stout oak handle reinforced with three tight bands of dark riveted iron spaced along its length, a heavy warm golden-bronze pick head with one long pointed tip and one short flat chisel end, a thick dark iron collar where the head meets the handle |
| 7 | `pristine_wolf_fang` | 9107 | `891e50c1` | a single long wolf fang lying diagonally: a solid ivory-white canine tooth, broad and solid at the root with a clean pale band, curving smoothly to one sharp point, a subtle warm cream sheen along the outer curve, no hollow end |
| 8 | `great_tusk` | 9108 | `5dc59aae` | a massive old boar tusk trophy lying diagonally: a very thick heavy ivory tusk sweeping in a wide half-circle curve, deep age cracks and dark scratch lines across its surface, the broad root end capped with a plain dark iron band, tapering to a blunt battle-worn point |
| 9 | `goblin_toolhead` | 9109 | `3feb9927` | a crude goblin tool head with no handle: a heavy blocky head of pitted dark iron with a jagged chisel wedge on one side and a blunt hammer face on the other, bound across its middle with rough green-tinged copper wire, an empty square socket hole where a haft would fit |
| 10 | `ember_core` | 9110 | `bcd56dfe` | a rough fist-sized stone cracked open like a geode: a dark charcoal-grey stone shell with deep angular cracks splitting it, the cracks and the open centre revealing solid ember-orange mineral, small orange flecks scattered along the crack lines, heavy and volcanic |
| 11 | `frost_claw` | 9111 | `a138e410` | a single long curved predator claw lying diagonally: pale ice-blue keratin like frosted glass, broad frosted-white at the root, curving smoothly to a needle-sharp point, faint paler blue crack lines along its length, cold and translucent |
| 12 | `pristine_horn` | 9112 | `a1780349` | a flawless polished ram's horn in a tight spiral, mounted upright on a small flat dark wooden display base: smooth glossy amber-cream keratin with fine even growth rings, unblemished surface, the spiral tapering to a perfect dark tip |

All twelve jobs completed and downloaded at 48 × 48 exactly.

## Blind Visual QA

Three rounds, all by an independent Visual QA agent against neutrally named
plates (M-13 staging; the round-2 tasking accidentally carried the intent key
in the same message, recorded by QA as a staging defect — its first
impressions were still recorded before the key was compared, and round 3 was
staged fully blind again). Native 48 × 48 was the verdict view, with ×4
nearest-neighbour enlargements for craft inspection only.

### Round 1 — all twelve

- **PASS:** oak_plank ("wooden plank", certain), scrap_metal ("scrap metal"),
  ember_core ("dark volcanic orb with glowing lava cracks"), frost_claw
  ("ice-blue claw"; MINOR — pale self-edge rather than the set's dark outline).
- **PASS-WITH-NOTE:** pristine_wolf_fang (generic tooth, not a curved fang),
  boar_hide (hide read; tortoise-shell flicker), reinforced_pickaxe (tool read
  survives; MAJOR — the gold pick head's contrast collapses at native, the
  defining feature is the least legible part), great_tusk ("drinking horn";
  compatible with the name beside it), pristine_horn (horn read; plinth sells
  the trophy).
- **FAIL:** heat_scale — read as "a glowing ember or coal", the identity of
  ember_core in the same set (round-orange silhouette collision);
  ram_wool — read as "a snail shell", a confusable twin of pristine_horn, its
  own co-drop; goblin_toolhead — "I cannot tell — dark blocky mass",
  illegible at native and likely to sink into a dark tile.

### Round 2 — the three re-rolls (staged with ember_core and pristine_horn as blind confusion partners)

- **heat_scale** (seed 9203, job `f52ff8a7`) — **PASS-WITH-NOTE, accepted.**
  Flat teardrop scale; no orb collision remains ("unmistakably different"
  from ember_core). MAJOR note: the palette carries no heat language — a
  nut-brown read the printed name must rescue.
- **ram_wool** (seed 9204, job `c6f91d2f`) — **PASS-WITH-NOTE, accepted.**
  "A ball of wool or fleece" leading read; "clearly different objects at a
  glance" vs pristine_horn. MINOR: firm-looking lobe highlights, bottom wisps
  read as strays.
- **goblin_toolhead** (seed 9205, job `2f536129`) — **FAIL.** Pixen drew a
  wooden haft stub in the socket; blind read "a hammer" — a complete tool,
  contradicting the item's defining property.

### Round 3 — goblin_toolhead only

- **goblin_toolhead** (seed 9305, job `4ae9b9d5`) — **PASS, accepted.**
  Socket described as punched clean through, horizontal composition; blind
  read "chunk of pointed metal, chisel or pick head, no handle, not a
  complete tool". MINOR: bottom-third values near outline-dark; the eye hole
  is barely perceptible at native (the read survives via handle-absence).

### Disposition

**All twelve accepted.** The withheld round-1/round-2 files stay in
`../out/items/` as `*_roundN_withheld.png`, never packaged. Cost: 16 pixen
generations for 12 accepted icons (12 + 3 round-2 re-rolls + 1 round-3
re-roll), leaving 6 of the cycle's 22 for contingency.

Recorded notes worth carrying forward to any future icon repair round:
reinforced_pickaxe's head contrast at native (MAJOR), heat_scale's missing
heat palette (MAJOR), and the a/d tan-palette crowding warning — "a third tan
item would crowd this corner of the palette."
