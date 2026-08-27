# REGIONAL_CONTENT_PACK_01 — Art Direction Brief

```
STATUS: WORKING BRIEF for one parallel content-production pass · NOT CANON
Isolated support workstream, run concurrently with the World & Reward Depth 01 session.
Nothing in this directory is integrated. Where this brief and GAME_BIBLE/ART/ART_DIRECTION.md,
PIXELLAB_PROOF_02/PIXELLAB_STYLE_SPEC_01.md or TRANSFORMATION_01/ART_DIRECTION_BRIEF.md disagree, those win.
```

**Date:** 2026-08-19 · **Based on HEAD:** `dc8f6f6` (branch `playable-phase-2-multiregion`) ·
**Budget:** ≤ 130 PixelLab generations (365 remained on the shared account at start).

## 0. Rules that outrank taste

1. Art must not imply a system the game does not have (no coins, chests, locks, timers, rarity
   glyphs, capacity, speech bubbles, quest marks, HUD). Rarity is **recorded in the manifest**,
   never drawn into an icon.
2. PixelLab authors; Claude crops, keys, scales, remaps, assembles (`RULES.md` A-1 / A-2).
3. Verdict scale is **×2** on a 390-pt-wide phone; ×8 is inspection only (M-05).
4. The author never writes a QA verdict (M-04). Accepted assets get a blind Visual QA line from a
   neutral staging (`../NEUTRAL_STAGING_CHECKLIST.md`).
5. Stage explicit paths; never `git add -A` (G-8). Nothing is committed from this pack unless the
   owner asks.
6. Staged production: **static read → mobile-scale QA → animate only the strongest** (owner brief §6).

## 1. Shared visual language (inherited unchanged)

| Property | Value |
|---|---|
| Stage enemies | `side` camera, **west** facing, single dark (brown-black) outline, flat matte, few steps, no glow, no emissive eyes, no blood; threat carried by posture and teeth/horns. Canvas per figure family as PE01 (§ below). |
| Icons | `create_image_pixen` 48×48, `no_background`, `high top-down`, `single color outline`, the §7.2 style clause appended verbatim (see §3). |
| World props / landmarks | `low top-down`, transparent, 32–96 px, Traveler palette via `style_image_url` (atlas base C language: muted olive/khaki/grey). |
| Vignettes | 384×176 opaque, `low top-down`, one landmark each, lower band calm. |
| Key light | upper-left, everywhere. |
| Palette | warm earthy limited (olive, sage, ochre, rust, cream, warm brown, neutral grey); cold accents only for Frostmere and water. **Teal `#58d6c0` never.** |
| Alpha | zero semi-transparent pixels after packaging (quantise at 128). |

### Stage sizes (native, before ×2) — matching the shipped set

| Figure | Character size → canvas | On-screen read |
|---|---|---|
| Wolf / lynx (shipped) | 40 → 56 | waist height on the Traveler |
| Boar, ram | 40 → 56 | waist / chest height — stocky, not tall |
| Bear | 52–56 → 72–80 | shoulder height to taller than the Traveler when reared; the Woods' heavy fight |
| Bat, crawler, weaver, salamander | 40–48 transparent sprite (pixen) → 56 canvas | small, low, wide |
| Backdrops | none new — the four shipped backdrops are reused per region |

## 2. Regional identity the enemies must obey

| Region | Ecology (from `GAME_BIBLE/WORLD/03`) | Palette lean | Candidates |
|---|---|---|---|
| Whispering Woods | wet upland broadleaf, oak, duskcap, closed canopy | olive, moss, brown | **Bristleback Boar**, **Oakback Bear** |
| Stonefall Mine | granite contact zone, timbered adits, spoil heaps | grey, tan, iron | **Adit Bat**, **Scree Crawler** (stone-shelled beetle) |
| Forgotten Hollow | sunken vale, standing water, mossed ruin, older than the frontier | desaturated grey-green, wet black | **Mire Salamander**, **Hollow Weaver** (great spider) |
| Frostmere | alpine basin, frozen tarn, treeline | pale blue-grey, white, dark conifer | **Frosthorn Ram** (+ concept-only Great Elk) |

No undead, no demons, no slimes, no generic bestiary; every creature is something that would
*live* in that terrain.

## 3. Style clause for icons (append verbatim)

> — pixel art game item icon, single dark outline all the way around the object, flat matte
> shading in a few clear steps, light from the upper left, warm earthy limited palette, no glow,
> no emissive light, no bright white specular, no cast shadow, no ground, no text, object centred
> and filling most of the frame

## 4. Method per family

- **Enemies (quadruped):** `create_character` standard, `side`, 4 directions, size per §1;
  one to two description rolls; judge at ×2 beside the shipped Traveler and wolf on the region's
  shipped backdrop. Animate only passing candidates: `animate_character` v3, `west`,
  `keep_first_frame=true` (idle · attack · defeat; hit reactions are known-hard on quadrupeds —
  one attempt at most, `fx_impact` + UI recoil is the shipped fallback).
- **Enemies (non-template bodies):** `create_image_pixen` transparent side view at 48–56 px,
  then `animate_image` for idle/attack/defeat on the chosen frame.
- **Icons:** pixen 48×48 per §3; one to two rolls; despeckle <8 px components; single component.
- **Props / landmarks / fauna:** pixen transparent `low top-down` 32–96; fauna loops via
  `animate_image` 4–6 frames.
- **Vignettes:** pixen 384×176 opaque, `low top-down`, palette-remapped toward the shipped
  location vignette only if it drifts.

## 5. Deliverable layout

```
REGIONAL_CONTENT_PACK_01/
  ART_DIRECTION_BRIEF.md            this file
  REGIONAL_CONTENT_PACK_01_HANDOFF.md   the handoff (root of the pack)
  CONTENT_PROPOSALS.md              enemies, materials, gear, chains, locations (design proposals)
  <family>/README.md                round record: prompts, ids, spend, AUTHOR ASSESSMENT, QA VERDICT
  <family>/candidates/              every candidate (raw PixelLab output)
  out/<family>/                     accepted + withheld assets at native size, one manifest.json
  qa/                               ×1 / ×2 / ×8 sheets, context plates, blind staging set
  tools/                            fetch / package / stage scripts (node, Scripts/art/png.js)
  INTEGRATION_MANIFEST.md           every accepted asset: id, files, dims, anim meta, use, deps, readiness
```
