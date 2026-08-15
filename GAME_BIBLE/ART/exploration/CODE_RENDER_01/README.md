# Code Render 01 — Native code-driven pixel art proof

**Status: EXPLORATION — nothing here is a decision.**

**EXPLORATION-SUPPORT ARTIFACT ONLY.** Not part of the app build, not referenced
by any Flutter, Dart, Kotlin, Swift, or CI target, and not shipping art. It sits
beside `VISUAL_SAMPLE_01/` under the same convention that directory established:
executable exploration tooling living next to its own output.

---

## The one question this answers

> **Can Claude Code author pixel art that is beautiful, charming, coherent, and
> good enough to plausibly appear in Project Stride?**

Technical pixel correctness was already established by the feasibility probe and
is not re-proved here beyond the minimal verifier. **The risk under test is
aesthetic quality**, and the owner decides whether it clears the bar.

**No art direction is selected.** `GAME_BIBLE/ART/ART_DIRECTION.md` remains
**EXPLORATION** and was not modified.

## What is being shown

Three reusable sprites, each on its own smallest sensible transparent canvas:

| Asset | Native | Why this subject |
|---|---|---|
| `player` | 24 × 34 (figure 32 px tall) | Highest aesthetic risk — character charm |
| `herb` | 20 × 19 | Core gameplay readability — the resource node |
| `gather_card` | 36 × 24 | Strongest expected code-driven domain — UI geometry |

`proof_sheet` (104 × 46) **blits those exact sprite objects**. Nothing is
redrawn for presentation.

## Provisional values — none of these is chosen

Everything below is **PROVISIONAL FOR CODE RENDER 01 ONLY** and does not become
the project's value by being written down (`RULES.md` G-3;
`ART_DIRECTION.md` — *UNRESOLVED*):

- the 49-entry palette and every colour in it
- the 32 px figure height and 1:4.5-ish proportion
- every canvas size above
- the 3 × 5 bitmap font on a 4 px advance
- the gather card's layout and neutral chrome

The card deliberately uses **common Direction A interface language only**. No
A1 / A2 / A3 identity chrome is chosen here.

## How it works

Every pixel is a **palette index** in a `Uint8Array`. There is no drawing API and
no blending stage, so anti-aliasing is not avoided by discipline — it is
unrepresentable. Output is an 8-bit indexed PNG (colour type 3), so the `PLTE`
chunk *is* the palette and an off-palette colour cannot exist in the file.

Sprites are authored as **ASCII maps** — one character per pixel, resolved
through a legend — because that is how the art is actually edited: legible,
diffable, hand-tunable, and portable to another language without redesigning the
artwork.

| File | Role |
|---|---|
| `surface.js` | Indexed raster, blit, nearest-neighbour scale, zero-dependency PNG encoder |
| `palette.js` | The provisional 49-entry palette, as named three-step ramps |
| `sprites.js` | The authored artwork — ASCII maps, the bitmap font, the card |
| `render.js` | Writes native + ×8 review PNGs into `out/` — **predates the standard output set; see below** |
| `review_set.js` | Emits the standard output set — native, ×2, ×8, context, silhouette. **Two functions over `Surface`; not a framework** |
| `verify.js` | Minimal technical check. **Not a framework, and must not become one** |

### The standard output set

`review_set.js` exists because every renderer here already shared one scaler, and
each one still chose a **single** `SCALE` constant and wrote only that view. The
result — found by `VISUAL_STUDIO_BASELINE_AUDIT_01` — was fifteen ×8 files, three
natives and **no ×2 anywhere in the repository**, so the Traveler was reviewed
only at the scale that flatters everything.

**New visual work uses `writeReviewSet`.** The set and the review order are
canonical in `GAME_BIBLE/ART/PIXEL_ART_CRAFT_SPEC.md` §8.

The existing `render.js` files in this and the other exploration directories are
**deliberately not retrofitted**. Changing them changes nothing until they are
re-run, and re-running them re-renders preserved evidence — which is its own task
with its own review, not a side effect of a tooling change (`RULES.md` G-2).

## Running it

From the repository root:

```
node GAME_BIBLE/ART/exploration/CODE_RENDER_01/render.js
node GAME_BIBLE/ART/exploration/CODE_RENDER_01/verify.js
```

Requires Node only. No packages, no account, no network, no image model.

`verify.js` checks exactly five things and stops: indexed PNG, palette-only
colours, no blended pixels, exact nearest-neighbour upscale, deterministic
re-render (`RULES.md` G-1, `MISTAKES.md` M-01).

## Implementation host is UNRESOLVED

Node was used because it was the smallest path already empirically verified.
**Node versus Dart as a permanent host is not decided here** and belongs to the
Technical Director. The sprite maps and the palette are plain data and port
without redesigning the art.

## What this does not do

No Haven's Rest scene. No A1, A2, or A3. No Round 1. No animation system. No
eight-direction sheet. No production art direction. No canonical document was
amended, no ADR was created, and nothing was placed in `assets/`.
