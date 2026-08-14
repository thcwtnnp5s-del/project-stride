# Haven's Rest Base Scene 01 — first full-world test of the working pixel language

**Status: EXPLORATION — nothing here is a decision.**

**EXPLORATION-SUPPORT ARTIFACT ONLY.** Not part of the app build, not referenced
by any Flutter, Dart, Kotlin, Swift, or CI target, and not shipping art.

---

## The one question this answers

> **Does the current code-driven pixel language succeed as an actual mobile RPG
> world screen — a world the character inhabits, rather than three good sprites
> on a contact sheet?**

`CODE_RENDER_01` proved three isolated assets. `PIXEL_ART_CRAFT_SPEC.md` §8 says
the third and critical review is **actual game context at target scale**, and
that when the remaining weaknesses are context-dependent the next step is the
context, not another isolated pass. This is that context.

## What this is not

- Not A1 Frontier Hearth, A2 Waymarked, or A3 Wild Trails
- Not Round 1 identity comparison
- Not Living Activity Presentation
- Not a production art lock
- Not a second renderer, and not production tooling

**Shared / neutral Direction A only.** Identity treatment is deliberately
withheld so that base composition, environment scale, character/world scale,
palette relationships, terrain readability and UI readability are debugged
*before* anything identity-shaped is layered on top of them.

## Why a sibling directory rather than another CODE_RENDER_01 target

`CODE_RENDER_01` is **preserved historical proof evidence** and its README
states in as many words that it contains no Haven's Rest scene. Adding the scene
there would have made the proof artifact and the world-scene experiment the same
directory, and a later reader could no longer tell which output answered which
question.

The reuse is therefore by `require`, not by copy:

| Reused unchanged from `CODE_RENDER_01` | How |
|---|---|
| `surface.js` — indexed raster, blit, nearest-neighbour scale, PNG encoder | imported |
| `palette.js` — the 49-entry proof palette and its indices | imported, copied, never mutated |
| `sprites.js` — the OR02 Traveler, the Meadow Herb, the gather card, the 3×5 font | imported and blitted as-is |
| `verify.js` | left alone; it still passes against the untouched proof |

Nothing in `CODE_RENDER_01/` was edited. Its render and its verifier both still
produce identical output.

## Files

| File | Role |
|---|---|
| `palette_ext.js` | The 49-entry proof palette **plus four appended ramps**, with the reason each was unavoidable |
| `font_ext.js` | The proof's 3×5 font **plus** the glyphs `"Haven's Rest"` and `"1,240"` need |
| `scene_sprites.js` | New artwork: the resident NPC, two trees of one species, the six tab icons, the boot glyph |
| `scene.js` | The 128 × 192 composition — terrain, settlement, props, figures, HUD |
| `render.js` | Writes `out/havens_rest_base.png` and the ×8 review render |

There is deliberately **no verifier here** (`RULES.md` G-1, `MISTAKES.md` M-01).
`CODE_RENDER_01/verify.js` already covers the technical risk — indexed output,
palette-only colours, no blending, exact nearest-neighbour, determinism — and
that risk did not change by drawing a larger picture. The risk under test here
is aesthetic, and the owner decides it.

## Running it

From the repository root:

```
node GAME_BIBLE/ART/exploration/HAVENS_REST_BASE_01/render.js
```

Requires Node only. No packages, no network, no image model.

## Provisional values — none of these is chosen

**PROVISIONAL FOR HAVEN'S REST BASE SCENE 01 ONLY.** A value used to make an
experiment renderable has not been chosen (`RULES.md` G-3; `ART_DIRECTION.md` —
*UNRESOLVED*):

- the **128 × 192** native frame and the ×8 review render
- the 13-row HUD strips and the six-tab bar's icon language
- the 20 px NPC height and the 32 px Traveler height in one frame
- every terrain, architecture, and prop treatment in `scene.js`
- **the four appended palette ramps and the 61-entry total**

## Palette change, recorded

49 → **61** entries. Four ramps appended, three steps each, no glow ramp, no
specular ramp, no cinematic highlight ramp. Each is recorded in `palette_ext.js`
with the reason the existing palette could not express it:

| Ramp | Why the proof palette could not carry it |
|---|---|
| `sky` | There is no sky in the proof. No existing entry is a pale cool atmospheric value; `stone` is a rock counterweight, not air. |
| `roof` | `timber` is already the palisade, gate, signpost and firewood. Roofing in `timber` makes the buildings and the wall one material and the settlement reads as a single mass. |
| `canopy` | `grass` **is** the meadow field. Tree foliage drawn in `grass` disappears into the ground the tree stands on. |
| `rust` | The resident's single muted rust/umber accent. Drawn in `leather` — belts and boots — an accent reads as more equipment rather than as clothing. |

Deliberately **not** added, and solved by reuse instead: the distant treeline
(`stone` mid — depth carried by value and saturation loss), the smoke plume
(`sky` light), and both roads and the path (`dirt`).

## Composition source

Translated from
`GAME_BIBLE/ART/exploration/VISUAL_SAMPLE_01/composition_blockout.png`, which is
1024 × 1536 — exactly ×8 of this frame — so blockout pixel ÷ 8 is this scene's
coordinate. That file is **read as reference only and was not altered.**

## Scene inventory

One player character · one resident · one Meadow Herb node · one gate · one
palisade · three roofs · one smoke plume · two trees · one signpost · three
firewood logs · two path stones · one main path · two roads leaving the frame ·
low scrub along the palisade · a thin grass fringe at bottom-left only.

No extra props, no extra people, no decorative filler.

Five text strings only: `Haven's Rest` · `1,240` · `×2` · `90` · `+10 XP`
— the last rendered `+10XP` by the frozen gather card, which was reused verbatim
rather than re-authored (CR-2).

## Related

- `GAME_BIBLE/ART/PIXEL_ART_CRAFT_SPEC.md` — the working execution standard
- `GAME_BIBLE/ART/ART_DIRECTION.md` — **EXPLORATION**, unmodified
- `GAME_BIBLE/ART/exploration/CODE_RENDER_01/` — the proof, preserved
- `GAME_BIBLE/ART/DIRECTION_A_IDENTITY_VISUAL_SAMPLES_01.md` — the rendering
  floor and the controlled-scene constraints this scene holds to
