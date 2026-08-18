# TRANSFORMATION_01 — Art Direction Brief

```
STATUS: WORKING BRIEF for one production pass · NOT CANON
Governs every PixelLab prompt in this pass so the outputs read as ONE game.
Where this brief and GAME_BIBLE/ART/ART_DIRECTION.md or
PIXELLAB_PROOF_02/PIXELLAB_STYLE_SPEC_01.md disagree, those win.
```

**Date:** 2026-08-17 · **Pass:** Transformation Build 01 · **Budget:** ~600 of
1,119 remaining PixelLab generations across all workstreams. Report spend.

## 0. Rules that outrank taste

1. **Art must not imply a system the game does not have.** No joystick / free
   roam / walkable tile field with a character on it. No coins, prices, shops,
   merchants, market stalls, wallets. No timers, countdowns, durability, decay,
   locks, rarity tiers, capacity meters. No pet stats or feeding. No NPCs with
   speech bubbles or quest marks.
2. **PixelLab authors; Claude never draws production art.** Allowed in code:
   crop, key, nearest-neighbour scale, palette/index remap, sheet assembly,
   format conversion (`RULES.md` A-1/A-2).
3. **Verdict scale is ×2. ×8 is inspection only** (`MISTAKES.md` M-05).
4. **The author never writes the QA verdict** (M-04). Every accepted asset gets a
   separate `QA VERDICT` line written by a Visual QA agent from a neutral
   staging (`NEUTRAL_STAGING_CHECKLIST.md`).
5. **Never `git add -A`.**

## 1. The shared visual language

| Property | Value |
|---|---|
| Camera — world/vignettes/characters | `low top-down` |
| Camera — icons | `high top-down`, laid flat, catalogue photograph |
| Outline | single dark closed outline; dark brown, not pure black, on characters |
| Shading | flat matte, few clear steps; **no gradients, no glow, no bloom, no specular** |
| Key light | **upper-left**, everywhere |
| Palette | warm earthy limited: olive green, sage, ochre, rust orange, cream, warm brown, neutral grey. Cold accents (pale blue / blue-grey) only for Frostmere and water |
| Reserved colour | teal `#58d6c0` is the steps colour — must NOT appear in art |
| Contact shadow | none in the asset — the compositor grounds sprites |
| Semi-transparent pixels | zero |
| Style anchor | the Traveler: character `c82b7da5-cda0-44eb-ae4e-30d73689e115`, south sprite URL from `get_character`. Environments: `style_image_url=<traveler south>` + `style_copy=["color_palette"]`, and **no palette words in the prompt** |

### Style clause for icons (append verbatim)

> — pixel art game item icon, single dark outline all the way around the object,
> flat matte shading in a few clear steps, light from the upper left, warm earthy
> limited palette, no glow, no emissive light, no bright white specular, no cast
> shadow, no ground, no text, object centred and filling most of the frame

### Prompt shape

`<noun phrase> <presentation clause>: <construction clause> — <style clause>`
Enumerate parts and how they attach. Positive construction beats negation.

## 2. Sizes (native)

| Family | Native | Display |
|---|---|---|
| Item icon | 48×48 | ×1 in the 84 px inventory cell |
| Traveler sprite / ambient frames | 64×64 | ×2 on the Adventure stage |
| Orange cat | 32×32 or 48×48 (must sit at the Traveler's feet: cat ≈ knee height) | ×2 |
| Atlas base master | 384×640 portrait or 512×512 (tool max) | ×2 in the atlas viewport (nearest) |
| Atlas landmark objects | 48–96 px, transparent | ×2 |
| Atlas ambient overlay sprites (cloud, snow, mist, smoke, water shimmer) | 32–96 px, transparent, 4–8 loop frames | ×2, composited |
| Location vignette | 512×384 → cropped 384×176 | as today |
| Gather-node card art | 96×96 transparent | ×1 or ×2 in the gather card |

## 3. Regional identity (five places, one world)

North = cold/high, south = warm/low. West = wild, east = worked.

| Place | Terrain | Reads as | Palette lean | Landmark |
|---|---|---|---|---|
| Haven's Rest | grassland | safe: palisade hamlet, lodge, forge smoke, well, meadow, a road | warm greens, cream, ochre | timber palisade + gate |
| Whispering Woods | temperate forest | dense oak, dappled floor, duskcap ring, a track into shade | olive, moss, brown | oak stand with a path |
| Forgotten Hollow | dark forest / sunken vale | bare branches, standing water, mossed ruin, mist | desaturated grey-green, wet black | mossed ruin arch |
| Stonefall Mine | foothills | granite scree, timbered adit, rails, ore cart, sparse pine | grey, tan, iron | timbered mine mouth |
| Frostmere | alpine | frozen tarn, snowfield, frost pines, scree above treeline | pale blue-grey, white, dark conifer | frozen tarn |

Transitions must be plausible: meadow → hedgerow/oak fringe → deep forest;
meadow → rising heath → scree/foothills; foothills → snowline → alpine.
Frostmere is reached only through the mine district: draw the pass.

Content gate: no towns beyond Haven's Rest, no roads to nowhere, no signage
text, no map labels/compass/border in the art (the UI supplies those).

## 4. Traveler ambient scenes — tone

Grounded downtime of a walker resting: quiet, warm, unhurried. The orange cat
is a companion, not a mascot; it does cat things (roll, bat yarn, stretch, sit
on the pack). No hearts, sparkles, meters, speech bubbles or icons above heads.
Nothing that looks like an activity the game rewards (no gathering, no crafting
motions that could be mistaken for a Craft action).

## 5. Deliverable layout (packaging sources)

```
GAME_BIBLE/ART/exploration/TRANSFORMATION_01/
  ART_DIRECTION_BRIEF.md            this file
  <stream>/README.md                round record: prompts, IDs, spend, AUTHOR ASSESSMENT + QA VERDICT
  <stream>/candidates/              every candidate (untracked)
  out/world/    out/items/    out/ambient/    out/env/    out/nodes/
                                     ACCEPTED assets only, final names, native size
  out/<stream>/PACKAGING.md          source file → shipped path → display size, one line each
```

`Scripts/art/package-art.js` reads only from `out/`; the integration lead adds
the emit lines. Never write into `assets/` directly.

## 6. QA at play scale

Every accepted asset appears in a `qa/` sheet at native and ×2 (and ×8 for
inspection). Blind naming for icons and landmarks (opaque codes, shuffled);
set-coherence review separately. In-context ×2 for anything that sits on a
screen (grid cell, stage, atlas viewport).
