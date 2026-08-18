# TRANSFORMATION_01 — workstream F: item icons, gather-node art, skill icons

```
STATUS: ROUND RECORD · NOT CANON · NOTHING COMMITTED · NOTHING WRITTEN TO assets/
QA VERDICT lines are blank on purpose — a Visual QA agent writes them (M-04).
```

**Date:** 2026-08-17 · **Brief:** `../ART_DIRECTION_BRIEF.md` (binding) ·
**Style:** `PIXELLAB_PROOF_02/PIXELLAB_STYLE_SPEC_01.md` §7.2 clause appended
verbatim to every icon prompt.

## 1. Spend

| Family | Tool | Calls | Generations |
|---|---|---|---|
| Item icons (9 items) | `create_image_pixen` 48×48, `no_background`, `high top-down`, `single color outline` | 26 | **26** |
| Gather nodes | `create_image_pro` 96×96, `style_image_url`=Traveler south, `style_copy=["color_palette"]` (4 candidates each) | 3 | **60** |
| Gather nodes | `create_image_pixen` 96×96 | 15 | **15** |
| Skill icons | `create_image_pixen` 24×24, `side`, `low detail` | 9 | **9** |
| **Total this workstream** | | 53 | **110** of the 120 allowed |

Balance: 1067 remaining at start, 799 at end. The 268 difference is **not** this
workstream alone — other Transformation streams were generating concurrently
(the rate-limit ceiling of 8 jobs was shared, and their jobs were visible in
`get_character`). Spend above is counted from this stream's own calls; every
job ID is listed in §3–§5 so it can be audited.

No inpaint or edit was needed: every accepted asset is an unedited generation
except for the despeckle step in §2.

## 2. What was done to the pixels after generation (and nothing else)

`tools/despeckle.js` copies each chosen candidate to its final name and clears
4-connected components smaller than 8 px to transparent. Every removed speck is
printed; the log is:

```
icon_hollow_root_48     14 px in 6 specks   (crumbs off the rootlets)
icon_bronze_pickaxe_48   2 px in 2 specks
node_meadow_patch_96     4 px in 4 specks
node_oak_stand_96        1 px
node_duskcap_grove_96    4 px in 3 specks   (a 46-px stray mushroom was kept: it is part of the ring)
node_frostpine_stand_96  1 px
everything else          0
```

No opaque pixel of any main body was changed in colour or position. This is the
alpha-key clean-up the brief allows (§0.2), recorded so it cannot be mistaken for
authoring. Raw candidates are untouched in `candidates/`.

Skill icons at 12×12 (`skill_*_12.png`) are a **nearest-neighbour 2:1
reduction** of the 24×24 originals (`tools/reduce12.js`, rule A: top-left pixel
of each 2×2). Deterministic, allowed by A-2, and offered as evidence — see §5.

Objective checks (`tools/check.js`) on every accepted file: **0 semi-transparent
pixels, 0 teal pixels**, sizes exactly 48/96/24/12.

## 3. Item icons — nine

Prompt shape for all nine: `<noun> laid flat, seen from directly above: <parts
and how they attach> — <§7.2 style clause>`. Seeds are the last field.

| Item | Accepted | Job ID (seed) | Rejected candidates and why |
|---|---|---|---|
| hollow_root | `c4` | `39e953a2-53d8-4319-aaaa-8e8bcbb7d11e` (511) | c1 `bdb4a394` stump-with-tentacles, read octopus; c2 `3acaa3ed` read as a claw; c3 `a5914027` a dead branch, acceptable second choice |
| pine_plank | `c4` | `e391dc03-da45-4541-a6d3-207833f39b70` (602) | c1 `9fa66349` a stack of three boards, isometric (D-1); c2 `169c3690` red-brown, too close to oak_handle's hue; c3 `e05f5c82` right board but under-filled the frame |
| bronze_sword | `c2` | `ceabd8b3-d0df-4e6f-87c7-18e318e40f4c` (213) | c1 `d48f09d5` correct but small with a purple grip |
| bronze_axe | `c5` | `f3d4ef25-e683-41d8-9df1-b0587aeca9a8` (614) | c1 `e2a2b79c` hammer; c2 `2f810c70` best silhouette but a green-grey steel head; c3 `b2245759` bronze, weaker bit; c4 `44b93e54` and c6 `3d85f0ff` double-bitted (would collide with the pickaxe family) |
| bronze_pickaxe | `c1` | `68a196f2-508d-43f9-b655-e0751bfb342d` (105) | c2 `2406f2f3` a cross, no shaft-through-head |
| bronze_chestplate | `c1` | `a26529f2-9b8d-40b7-b51f-e9fdc9f0af4e` (106) | — (first roll accepted) |
| herb_broth | `c2` | `4b17a391-369e-42dd-828b-1f7ce7d19f33` (117) | c1 `6362d3e4` a straight top-down disc — read as a **coin/medallion**, exactly the family the brief bans |
| hearty_stew | `c1` | `8c013e14-df4e-4473-be92-3c89128d0721` (108) | — |
| hollow_sigil | `c4` | `08046d77-3a65-4e26-954d-18f5db786507` (509) | c1 `418f4783` and c2 `d21f4d96` both read as **a leaf** (the engraved mark became leaf veins); c3 `1cce4d02` an oval wooden token with a zigzag rune — kept as the **alternate**, see below |

Prompt notes that mattered:
- The **bronze** word alone gave steel or green heads; "warm golden bronze,
  orange-brown metal like a copper penny" gave bronze every time after.
- "single-bladed / on one side only / flat square poll on the other side" still
  yields a double-bit axe about half the time. Roll and select; do not fight it
  with negation.
- A bowl seen from directly above is a disc. Broth and stew both use
  three-quarters-above so the rim and depth show; both prompts kept the icon
  camera clause otherwise.

**AUTHOR ASSESSMENT (items).** At ×2 in the 4-wide inventory sheet the nine sit
inside the shipped family: same outline weight, same flat steps, same warm
range. Bronze tools are plainly a heavier, warmer tier than the thin grey
training tools (`qa/icons_tools_training_vs_bronze_x2.png`); axe / pickaxe /
sword differ by silhouette family (lopsided wedge, symmetric two spikes,
straight blade + guard) not by hue. Broth vs stew differ at ×1 by bowl colour,
depth and the spoon (`qa/icons_bowls_x1.png`). Risks I would flag before QA
does: (1) hollow_root can read as "a dead branch/twig" as readily as "root" —
the label rescues it, and it never reads as a wrong *system*; (2) hollow_sigil
c4 is a rectangular-ish slab; the moss and chipped edge break the rectangle but
a critic could still say "tablet" or "card". It does not read as coin, lock,
slot or disabled cell to me. **Blind read in the 4-wide grid is staged for
exactly that question** (`../s7k2/grid_pa.png`, `grid_pb.png`). If it fails
there, c3 (`candidates/hollow_sigil_c3.png`) is the alternate — an irregular
oval of dark wood with a bold zigzag rune; its own risk is "cookie/medallion".
(3) bronze_axe c5's poll is slightly pointed; at ×2 it still reads axe/hatchet.

**QA VERDICT (items):** _blank — Visual QA writes this._

## 4. Gather-node art — eight, 96×96 transparent

| Node | Accepted | Tool / job (index) | Rejected and why |
|---|---|---|---|
| meadow_patch | `pro3` | pro `0d6bc75a-b707-4a57-b10c-a18e22ceacc7` (3) | pro 0–2 fine, 3 the fullest clump; pixen c1 `f6c5fd9d` put the herbs in an isometric planter box |
| oak_stand | `pro3` | pro `423e177a-b169-449c-965d-82b2c0d60f5d` (3) | pixen c1 `c9fe6865` trees on an isometric grass tile plinth (D-1) |
| duskcap_grove | `c1` | pixen `8ba8d5f5-65c8-47f3-b102-8939f00d3a16` (1003) | — accepted first roll: a mushroom ring on moss. The "under trees" part did not appear; a trunk base was prompted and not drawn |
| copper_seam | `pro2` | pro `662c2294-e4f9-415d-b236-af36bed5fe2e` (2) | pixen c1 `749ed7a7` an isometric stone cube with a lava-red vein (D-1 + D-2) |
| tin_seam | `c3` | pixen `d8b8b585-5916-4701-8736-61e25811a158` (1305) | c1 `87c2036a` a rail/wall; c2 `f5b4948b` iso cube on a tile |
| rimefrost_hollow | `c4` | pixen `7c7cf507-baf7-487e-967d-0c7763fe0c97` (1406) | c1 `5d98420c` an odd blob; c2 `2cc21ae6` flowers in a black hole; c3 `a4163469` flowers under a snow dome (read snow-globe) |
| frostpine_stand | `c3` | pixen `281e8d19-7f8d-467b-9d42-38db4fc35445` (1307) | c1 `49326cd5`, c2 `8df985dd` both iso snow tiles |
| hollow_thicket | `c1` | pixen `ea9ce511-c2a2-40d8-9e2c-b099d361887f` (1008) | — |

**Production finding worth carrying:** `create_image_pixen` with `view="low
top-down"` puts a scene on an **isometric tile plinth** almost every time (6 of
8 first rolls). Two things fixed it: (a) `create_image_pro` with the Traveler
palette anchor — every one of its 12 candidates was plinth-free and on-palette,
20 generations for four options; (b) pixen with `view="side"` and "standing
alone on a transparent background, no base, no platform, no tile" — plinth-free
on the first try, 1 generation. Pro is the better default when budget allows;
pixen-side is the cheap fallback and produced tin_seam, rimefrost_hollow and
frostpine_stand.

**AUTHOR ASSESSMENT (nodes).** All eight are distinct at ×1 in the mock card
list (`qa/nodes_card_list_x1.png`) and at ×2. Copper vs tin separate by
boulder colour and vein colour (grey rock / orange-green vein vs tan rock /
dark-grey vein with silver lumps), not by hue alone. Risks: (1) copper vein is
orange — flat, no glow, but D-2 ("reads as heat") is the thing to ask about;
(2) tin_seam boulder is round and dotted and could be called "a cookie" by an
unkind critic; (3) the pro-generated pieces are richer in detail than the
pixen ones — set coherence across the eight is decent but not one hand;
(4) duskcap_grove has no trees; if "under trees" is required, that is one more
pro roll. No figures, no text, no chrome in any of them.

**QA VERDICT (nodes):** _blank._

## 5. Skill icons — OD-04 second attempt

Silhouette families, one per skill, **no hafted tool anywhere**:
Foraging = leaf sprig · Woodcutting = sawn log round · Mining = ore lump ·
Smithing = anvil · Cooking = two-handled pot. Same construction line for all
five ("one solid connected shape — tiny pixel art game skill icon, single dark
outline all the way around, flat matte shading in two values, light from the
upper left, warm earthy limited palette, no detached pixels…").

| Skill | Accepted | Job ID (seed) | Rejected |
|---|---|---|---|
| foraging | `c2` | `113c2836-17c4-4772-a6bc-3a18fa0b8a55` (2101) | c1 `a18b0dd4` one leaf detached (2 components: 119/47 px) — A6 fail |
| woodcutting | `c1` | `d15394a0-ef00-4f20-bb56-2498fba91739` (2002) | — |
| mining | `c1` | `99f73dd3-de60-46f6-92f2-3934674d64e9` (2003) | — |
| smithing | `c1` | `46bdddf1-4245-4ebb-85ff-c80950d7bd37` (2004) | c2 `f792f14e` had a hot orange bar on it (reads "forge", adds a third value) |
| cooking | `c3` | `c42c7f71-e038-45b5-ac18-6e543c18af47` (2205) | c1 `2770cfab` a face-like marking; c2 `102886e0` lost the handles (read urn) |

**Size — record this.** PixelLab cannot go below 16 px, so the set is authored
at **24×24 native**. Today the app draws `skill_*.png` as 12×12 sprites at ×2 =
24 px on screen. A 24-native icon drawn at ×1 occupies the same 24 px but with
half-size pixels relative to the rest of the UI chrome (nav glyphs, steps glyph
are 12/14-native at ×2). That is a **UI density-grid mismatch** and the lead /
UI Pixel Designer must decide, not this stream. So both are provided:

- `skill_<id>_24.png` — the authored set, for ×1 display (24 px on screen).
- `skill_<id>_12.png` — nearest-neighbour 2:1 reductions (rule A), for the
  existing ×2 path. Staged at ×2 in `qa/skills_reduced12_A_x2.png` /`_x8.png`.
  All five stay one 4-connected mass after reduction. Rule B (outline-preserving
  darkest-of-4) thickened the contours into mush and is shown for contrast.

**AUTHOR ASSESSMENT (skills).** At play scale (`qa/skills_current_x2_over_new_x1.png`,
top row current, bottom row new): the five new silhouettes are five different
*kinds* of shape — a fan of leaves, a cylinder with a ring face, an angular
lump, a pinched-waist block with a horn, a round-bellied vessel. The pot/anvil
case (A2) separates on silhouette: round vs pinched-with-horn; in greyscale
(`qa/skills_new_grey_x1.png`) they remain separable. The current set's
Woodcutting is a whole tree and its Mining a hollow arch, and its Smithing is a
hafted hammer — the new set is more consistent as a family and none of the five
can be mistaken for another's object class. Where I am less sure: the 24-native
set at ×1 has thinner lines than the rest of the UI (density issue above), and
in the 12-px reduction the anvil's horn is 2 px and the sprig is faint. **My
honest read is that the new set beats the current one at play scale on the
criteria the OD-04 spec fixed (A2, A3, A4), and the 12-px reductions are the
weaker of the two deliveries.** Delivered as accepted-pending-QA; the lead
decides. Note the SKILL_ICON_SPEC_01 §2 canvas rule (12×12) is not met by the
24-native files — that is a spec question, recorded here, not silently changed.

**QA VERDICT (skills):** _blank._

## 6. QA sheets

`qa/` (all nearest-neighbour, no text baked in):

| File | What |
|---|---|
| `icons_coherence_24_x1.png`, `_x2.png` | 24 icons (15 shipped + 9 new, mixed) in 84-px inventory cells, 4-wide |
| `icons_new9_native.png`, `_x2.png`, `_x8.png` | the nine alone |
| `icons_tools_training_vs_bronze_x2.png` | sword/axe/pickaxe pairs |
| `icons_bowls_x1.png`, `_x2.png` | broth, stew, tea |
| `nodes_native.png`, `nodes_x2.png`, `nodes_card_list_x1.png`, `node_card_<i>_x1/x2.png` | nodes alone and in a mock gather card (blank bars, blank chip) |
| `skills_new_x1.png`, `_x4.png`, `_x8_inspection.png`, `skills_new_grey_x1/x4.png` | new set, colour and greyscale |
| `skills_current_x2_over_new_x1.png` (+`_zoom4`) | current shipped set at its display size over the new set at its display size |
| `skills_row_x1/x3.png`, `skills_chip_x1/x3.png` | mock skill rows and mock gather-card chips |
| `skills_reduced12_A/B_x2/x8.png` | 12-px reduction evidence |

**Blind staging** for the Visual QA agent is in the opaque directory
`../s7k2/` (per `NEUTRAL_STAGING_CHECKLIST.md`): 12 item plates (nine new + three
shipped distractors) as `<code>_a` native-in-cell, `_b` ×2, `_c` ×8; two
inventory grids `grid_pa` (×1) / `grid_pb` (×2) with the sigil in position 3;
eight node plates `<code>_a` ×1 / `_b` ×2; five skill plates `<code>_a` ×1 /
`_d` ×4. Codes are shuffled; **the key is `tools/BLIND_KEY.txt`**, outside the
staging directory. Nothing in `s7k2/` carries a name, a label, or UI chrome.
STAGING CHECK against A1–A6, B1–B3: A1 opaque names ✓ · A2 no ordinals (the
`_a/_b/_c` suffix is scale, which is presentation, not sequence — call it out
to the critic as "same image, three sizes") · A3 opaque dir ✓ · A4 shuffled ✓ ·
A5 ✓ · A6 native, ×2, ×8 present ✓ · B1 no text ✓ · B2 grid cells only ✓ ·
B3 no labelled sheet in the blind set ✓. D4 caveat stands: the reviewer's
`git status` will show `TRANSFORMATION_01/`, which discloses the pass but not
which asset is which.

## 7. Not done / for the lead

- Nothing written to `assets/`, no Dart, no `package-art.js`, no git.
- `out/items/PACKAGING.md` lists the intended shipped paths.
- OD-04's spec canvas (12×12) vs the 24-native reality needs a decision.
- duskcap_grove without trees; a pro roll (20) would add them if wanted.
- hollow_sigil c3 stands ready as an alternate if c4 fails the grid read.

## QA VERDICT (independent Visual QA, 2026-08-17)

Blind naming from ../s7k2/ (key opened only after all names were written):
items 12/12 identity (hollow_root read "branch" first), grid 6/8 (oak_handle
read "plank"; tin_ore read "plain grey rock"), nodes 8/8 identity (tin_seam
read "boulder with dark seam", first flash "cookie"; hollow_thicket read
"twisted roots" plus an unexplained pale heart/moth mark), skills 5/5.
Leaked: task prompt disclosed the asset categories; s7k2 itself was clean;
qa/ filenames are semantic (nodes_, skills_). Verdicts:

- icon_hearty_stew, bronze_sword, meadow_herb, bronze_chestplate,
  traveler_tunic, bronze_axe, bronze_ingot, herb_broth, bronze_pickaxe: PASS.
- icon_hollow_sigil: PASS — read "mossy stone tablet with rune"; not coin,
  not card, not leaf, not slot, in the grid.
- icon_hollow_root: PASS-WITH-NOTE — reads "branch/twig" before "root".
- icon_pine_plank: PASS-WITH-NOTE — alone reads paper/soap; in the grid the
  oak_handle neighbour rescues it. Two logs and two planks are hue-only twins.
- (shipped) icon_tin_ore: NOTE — reads plain stone; no ore cue at x2.
- node_meadow_patch, oak_stand, duskcap_grove, copper_seam, rimefrost_hollow,
  frostpine_stand: PASS. No slab/plinth, no figure, no chrome.
- node_tin_seam: PASS-WITH-NOTE (MAJOR B) — cookie read is real at x1 in the
  card list; "seam" reads, "tin/ore" does not.
- node_hollow_thicket: FAIL (MAJOR B) — pale floating mark top-left reads as
  a heart/emote over a gather node at x1 and x2; unexplained object.
- skill_smithing/cooking/woodcutting/mining _24: PASS at x1; new set more
  coherent than current.
- skill_foraging_24: PASS-WITH-NOTE (MINOR A) — low contrast at x1, near
  invisible in grey state; current sprout is brighter.
- 24-native vs 12-native density and SKILL_ICON_SPEC_01 canvas: category D,
  escalated verbatim, no opinion.

QA VERDICT (items): PASS
QA VERDICT (nodes): FAIL — hollow_thicket's floating mark; tin_seam ambiguous.
QA VERDICT (skills): PASS

### Lead's disposition (2026-08-17)
- node_hollow_thicket: corrected by one PixelLab `inpaint_image` over the mask
  (3,5)–(25,18) — see `items/README.md` addendum below the QA verdict once the
  job lands; the corrected file replaces `out/items/node_hollow_thicket_96.png`
  and re-enters QA on the device pass. If the inpaint fails, the node ships
  without art (the card reserves the slot).
- node_tin_seam: shipped as PASS-WITH-NOTE; recorded as COSMETIC.
- Skill icons: shipped at 24 native ×1 (lead decision, `PixelAsset.skill`).
  Category D escalation recorded for the owner.
- Addendum: inpaint job `f0836bad-854d-4688-96a7-369408e3a2c0` (~20 gens),
  mask (3,5) 22×13. Measured: 147 px changed inside the mask, **1 px outside**,
  0 semi-transparent; pale (>300 luma-sum) pixels in the top-left quarter
  53 → 4. Pre-inpaint file kept at `items/candidates/node_hollow_thicket_96_pre_inpaint.png`.
