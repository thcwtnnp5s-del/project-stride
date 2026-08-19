# WORLD_REWARD_DEPTH_01 — item icons (workstream G, part 3 — lead addendum)

```
STATUS: round record · the four new material and armour icons · NOT CANON
Author: PixelLab ambient/combat correction agent (workstream G), 2026-08-19.
Added mid-round by a lead addendum. Nothing here is committed, staged, or written to
assets/, lib/, Scripts/ — the lead integrates.
QA VERDICT is written by an independent Visual QA agent (MISTAKES.md M-04).
```

Four icons for the new content in `MILESTONES/WORLD_REWARD_DEPTH_01.md` §5:
`item.wolf_pelt` (common), `item.lynx_pelt` (rare), `item.wolfhide_jerkin` (rare armour),
`item.frostlined_jerkin` (epic armour).

**Where this lives.** The addendum said "package to `out/items/`" and "record in the ambient README
or a small `items/README.md`". This directory is
`GAME_BIBLE/ART/exploration/WORLD_REWARD_DEPTH_01/items/`, a sibling of `ambient/` and `combat/`,
with the output in `out/`. Say the word if it should sit under one of the other two instead — it is
four PNGs and three text files, and nothing outside this folder references it.

## 1. Spend

| Target | Tool | Calls | Gens |
|---|---|---|---|
| round 1: wolf_pelt c1, lynx_pelt c1, wolfhide_jerkin c1, frostlined_jerkin c1 | `create_image_pixen` 48 × 48, `no_background`, `high top-down`, `single color outline` | 4 | 4 |
| round 2: wolf_pelt c2, lynx_pelt c2 | same | 2 | 2 |
| **items subtotal** | | **6** | **6** |

Workstream total: ambient 9 + combat 14 + items 6 = **29 of 70**.

## 2. Method

Exactly the shipped icon method (`TRANSFORMATION_01/items/README.md`,
`PLAYABLE_EXPANSION_01/ambient/README.md` §1): `create_image_pixen` at **48 × 48**,
`no_background`, `view="high top-down"`, `outline="single color outline"`, with the
`PIXELLAB_STYLE_SPEC_01.md` **§7.2 style clause appended verbatim and unchanged**:

> — pixel art game item icon, single dark outline all the way around the object, flat matte
> shading in a few clear steps, light from the upper left, warm earthy limited palette, no glow,
> no emissive light, no bright white specular, no cast shadow, no ground, no text, object centred
> and filling most of the frame

Post-processing is `package.js` only: alpha quantise at 128 and a despeckle pass that clears
4-connected components under 8 px. **0 semi-transparent pixels and 0 despeckled pixels on all four
files; every icon is a single connected component.** No inpaint, no edit, nothing hand-drawn.

The two jerkins were prompted as garments seen from the front "as if worn on an unseen body", which
is the presentation the shipped `traveler_tunic` and `bronze_chestplate` already use
(`qa/_shipped_ref_x4.png`); the two pelts as hides laid out flat, which nothing shipped resembles.

## 3. Candidates and prompts (verbatim, style clause elided as `<§7.2>`)

### `icon_wolf_pelt_48`

- c1 (`15c78bfb-c5d1-47f7-ac5b-0faa5c14e27d`, seed 5101): "a single wolf pelt laid out flat, fur
  side up: a roughly diamond-shaped hide of shaggy grey-brown wolf fur with a paler cream underbelly
  stripe down the middle, four short leg flaps at the corners, a bushy tail hanging from the bottom
  edge, roughly cut edges — <§7.2>"
  → good pelt shape, but the "underbelly stripe" came out as a **bright orange-cream blaze down the
  centre that reads as a flame**, against the clause's no-glow / no-emissive rule. **Rejected.**
- **c2** (`e26ea81f-5e68-4f8b-867b-89503dca1b25`, seed 5102): "a single wolf pelt laid out flat with
  the fur facing up: a broad shaggy hide of grey-brown wolf fur in even matte tones with darker
  guard hairs along the spine, the wolf's flat empty head at the top with two small pointed ears,
  four short leg flaps at the sides, a thick bushy tail hanging from the bottom, roughly cut edges
  — <§7.2>"
  → a matte grey-brown hide with the wolf's flat head at the top, four leg flaps and a bushy tail.
  Reads as a pelt and as a *wolf's* pelt. **Chosen.**

### `icon_lynx_pelt_48`

- **c1** (`fe7f7020-4c7b-47d0-a78b-3949582b6004`, seed 5201): "a single lynx pelt laid out flat, fur
  side up: a roughly diamond-shaped hide of pale frost-grey short fur dappled with faint darker grey
  rosette spots, a cream underbelly stripe down the middle, four short leg flaps at the corners, a
  very short stubby bobbed tail at the bottom edge, two tufted ear pieces at the top edge, roughly
  cut edges — <§7.2>"
  → a pale grey diamond hide with faint rosettes, four leg flaps and a small flat head. Distinctly
  paler and smoother than the wolf pelt. **Chosen.** My doubt: the little head could read as a
  mouse or a bear rug rather than a lynx.
- c2 (`2c287b19-cf9f-4592-b823-5512b5d1464a`, seed 5202) — same prompt with "clear darker slate-grey
  spots" and "two tall tufted ears" → it drew a **whole spread-out tabby cat with a long tail**, not
  a cut pelt. **Rejected.**

### `icon_wolfhide_jerkin_48`

- **c1** (`458fc8c0-6704-4089-87ec-6f1a6ba9cfce`, seed 5301), one roll: "a sleeveless leather jerkin
  seen from the front as if worn on an unseen body: dark brown boiled-leather body panels laced up
  the centre with a cord, a thick shaggy grey-brown wolf fur collar around the shoulders, bare
  armholes with no sleeves, a plain leather belt at the waist — <§7.2>"
  → dark brown laced leather with a shaggy brown-grey fur collar and a belt. **Chosen.**

### `icon_frostlined_jerkin_48`

- **c1** (`8d289237-d00b-4f1d-8b2a-c7060e36ae77`, seed 5401), one roll: "a sleeveless leather jerkin
  seen from the front as if worn on an unseen body: dark brown leather body panels laced up the
  centre, trimmed all the way round with thick pale frost-grey fur — a full pale fur collar over
  both shoulders, a broad band of the same pale fur along the bottom hem, and pale fur edging around
  each bare armhole, a leather belt at the waist — <§7.2>"
  → the same garment family with a full pale fur collar **and** a pale fur hem band. The hem is what
  separates it from the wolfhide jerkin at ×1, where the collar alone would not. **Chosen.**
  My doubt: the pale fur is bright enough to brush the clause's "no bright white specular", and
  the collar is bulbous enough to read as a cloud or a life ring in isolation.

## 4. Delivered

`out/`, all 48 × 48 RGBA, 0 semi-alpha, 0 despeckled pixels, one connected component each:

| file | opaque bounds | colours | note |
|---|---|---|---|
| `icon_wolf_pelt_48.png` | 0,0..46,47 | 21 | fills the frame edge to edge |
| `icon_lynx_pelt_48.png` | 0,0..47,46 | 42 | fills the frame edge to edge |
| `icon_wolfhide_jerkin_48.png` | 3,1..44,46 | 26 | |
| `icon_frostlined_jerkin_48.png` | 5,1..43,45 | 46 | |

Colour counts of 42 and 46 are pixen's anti-aliasing, the same caveat PE01 recorded for
`skill_foraging` (46 colours in a 24-px icon). **No code-side colour reduction was applied** — that
would be authoring; if a tighter palette is wanted it has to come from PixelLab (`RULES.md` A-2).

`out/manifest.json` carries the same rows with `status` `"withheld"` until QA reports.

QA material: `qa/items_sheet_x{1,2,8}.png`, `qa/_pelts_x6.png` (both pelt rounds side by side),
`qa/_jerkins_vs_shipped_x4.png` (the two new garments beside `traveler_tunic` and
`bronze_chestplate`), `qa/_shipped_ref_x4.png` (the family this had to join).

## 5. Neutral staging

Blind set: **`n5c8/`** (31 files, opaque shuffled codes, no text). Key: `tools/BLIND_KEY.txt`,
outside the staged folder. Per code `_a` ×1, `_b` ×2, `_c` ×8, plus `grid_a`/`grid_b` (four
garments, two new and two shipped, interleaved) and `row_a`/`row_b` (the two new pelts beside a
shipped log). Distractors: shipped `traveler_tunic`, `bronze_chestplate`, `oak_log`, and the two
rejected candidates.

STAGING CHECK: A1 ✓ · A2 ✓ · A3 ✓ · A4 shuffled by fixed permutation ✓ · A5 (`grid`/`row` name the
presentation, not the content — presentation collision is itself what those two plates test) ✓ ·
A6 ×1 / ×2 / ×8 present; "in context" for an item icon is the grid ✓ · B1 no baked text ✓ ·
B2 plain plates ✓ · B3 no labelled sheet inside `n5c8/` ✓ · D1 key outside ✓ · D4 the usual
`git status` limit. **STAGING CHECK: PASS**

## 6. AUTHOR ASSESSMENT

What I believe holds at ×2:

- **The two pelts do not collide with each other**: one is a shaggy brown hide with a wolf's head
  and a bushy tail, the other a smooth pale grey hide with rosettes and no tail to speak of. They
  differ in hue, value and texture, not just hue — which is the failure mode PE01's QA found between
  `oak_log` and `pine_log`.
- **The two jerkins are separable at ×1** because of the hem band, not just the collar colour, and
  neither collides with `traveler_tunic` (cream, sleeved, no fur) or `bronze_chestplate` (metal
  plate).
- The set sits in the shipped icon family: same 48 canvas, same clause, same light direction, same
  matte steps.

What I doubt: the lynx pelt's little head (mouse? bear rug?); the frostlined jerkin's pale fur
brightness against the clause's no-specular line; and whether a *pelt* is a shape players read at
all at ×1 in a list — neither pelt has a precedent in the shipped set to lean on.

## 7. QA VERDICT (independent Visual QA)

_(to be filled by an independent Visual QA agent working from `n5c8/`; the author does not
self-certify — `MISTAKES.md` M-04)_

**QA VERDICT:** (blind, independent, 2026-08-19; reviewer read no README/key; the set was staged with the CURRENT shipped art as distractors)

Per candidate (blind codes → key in tools/BLIND_KEY.txt):
- **ka = NEW icon_wolf_pelt** — "brown pelt with head, four paws, tail, spread flat; reads as a wolf pelt / rug." **PASS.** Strongest pelt.
- **ns = NEW icon_lynx_pelt** — "grey spotted flat hide with a cat face; the striped corner objects read like rolled bandages, not paws; some will say stingray / kite." **PASS-WITH-NOTE** (MINOR B).
- **ho = lynx_pelt c2 (rejected by author)** — "a live flattened cat / plush." **FAIL** (BLOCKER as a material) — not packaged.
- **ba = wolf_pelt c1 (rejected by author)** — "bright centre stripe reads as flame / glow." **FAIL** (MAJOR B) — not packaged.
- **pe = NEW icon_wolfhide_jerkin** — "fur-collared leather vest." **PASS.**
- **zd = NEW icon_frostlined_jerkin** — "winter fur-trimmed vest; trim slightly icy/blue." **PASS-WITH-NOTE** (C). Reviewer prefers pe; both pass and read as distinct garments in the row.
- Shipped distractors: fm traveler_tunic PASS, ru bronze_chestplate PASS-WITH-NOTE ("gold saturation reads as tier"), vi oak_log PASS.

Set verdict as written: **FAIL** (ho blocker, ba fails; ka, pe, zd, fm, ru, vi pass; ns pass-with-note).

### Lead's disposition (2026-08-19)
All four NEW icons accepted and promoted (ka, ns with its note, pe, zd); the two failing candidates were already rejected by the author and are not packaged.
