# Fable 5 Mega Production Overhaul 02 — the record

```
STATUS: IN PRODUCTION · branch fable5-mega-production-overhaul-02
From visual-audio-world-overhaul-01 @ 4d9a81f · Opened 2026-09-02
Authority: DECISIONS/0029 (interface art), 0030 (budget + audio), 0031 (density per plane)
PixelLab live balance at open: 9,762 remaining (238 used of 10,000; Tier 3, resets 2026-10-01)
Evidence: MILESTONES/evidence/FMPO02/wave0 (six guardians) · wave1 (fourteen briefs) · wave2 (production reports)
Workspace: GAME_BIBLE/ART/exploration/FMPO02/
```

**What this document is.** The record of the second production offensive: the
owner's physical-iPhone verdict on 4d9a81f, the doctrine chosen in answer, what
was produced, what shipped, what was rejected and why, and the exact device
checklist that decides acceptance. It is written as the work lands, not after.

## 1. The verdict this answers

The owner installed 4d9a81f and ruled. Improved: typography, the leather
chassis, grounded gather scenes, some item icons, combat weapon states, the
Inventory figure, the Frost Lynx, save persistence. Not good enough, in the
owner's order:

1. **World** — the atlas master was untouched; the seam defects stand.
2. **UI** — "large leather frame containing ordinary rounded dark cards",
   repeated on every tab.
3. **Craft** — a long database list of identical rectangles.
4. **Equipment** — Inventory shows the Bronze Chestplate; Adventure, gathering
   and combat show the white shirt and green vest.
5. **Items** — perceptual duplicates (one crate for three reclaims, broths that
   are one broth).
6. **Encounter** — a small wolf in a huge blank rectangle.
7. **Gathering** — good architecture, some scenes still staged.
8. **Combat** — the command frame outweighs the fight.
9. **World life** — fairy castle, storm house, ice tower, red and blue dragons,
   more life: not delivered.
10. **Audio** — nothing new landed.

## 2. The doctrine — scene over frame

`MILESTONES/evidence/FMPO02/wave1/ART-01_executive_doctrine.md`, binding on
every family: *Stride is a place you look into, not a form with a leather
border.* Every screen gets one authored picture about that screen; the
interface sits beneath it; **subtracting chrome is delivered work.** Three
failure modes with a rule each: frame inflation (one framed element per
screen), style drift (an anchor sheet every call cites), volume without
composition (no family spends past 40 % before a device-scale render passes
the squint test).

The mechanical cause of the repetition (`ART-02`): `DECISIONS/0029` named three
identity axes — band, surface, picture — and VAWO01 built only the frame.
`PanelSkin.surfacePath` was declared and read by nothing.

## 3. What landed (running)

| Commit | What |
|---|---|
| 3184f68 | Foundation: workspace, six guardian reports, fetch/crop/serve tools |
| 9405317 | Fourteen director briefs, ten atlas crops, production rules, gitignore exception |
| 15be0da | UI architecture: `PanelSkins` inverted (chassis on `heroPlate`/`modalFrame` only), `PanelSurface`/`SurfaceTile`/`PanelSurfaces`, `PixelFrame` interior tile + `SurfaceFill`, rhythm tokens 24/16/8, region deeps 8–13 L*, nav plate |

_(This table grows with every commit; see the closeout in §9 when it exists.)_

## 4. Facts proven before spending

- A `create_character_state` on the canonical Traveler carries a held tool
  (Bronze Plate + bronze pickaxe, 80×64); `animate_character` v3, west, keeps
  the breastplate and the pickaxe in all eight frames of a mining swing
  (`GAME_BIBLE/ART/exploration/FMPO02/review/probe_plate_pick_mine_w_x3.png`).
  The precomposed-state architecture is therefore the production method.
- v3 returns a square canvas (104² for an 80×64 source). The raised pickaxe
  reaches one row above a 64-row window and the strike dips below the feet:
  `tools/equip-prep.js` anchors on the **modal** foot row and reports clipped
  pixels per frame rather than refusing.
- A pixen still of the red dragon animates into a clean nine-frame wingbeat
  with `animate_image`; a pixen still of the fairy castle glade reads at 96×80.
- Pixen cannot produce a ≤6 L* surface tile from a prompt alone (three probes
  rejected: weave, speckle, dither checkerboard). Surfaces are generated with a
  forced ramp and remapped deterministically.
- **Audio cannot be produced this session.** The only provider ever used is
  Stability AI; `STABILITY_API_KEY` is unset and no key exists anywhere on the
  machine (GOV-06). The non-file work lands; the queue waits on one variable.

## 5. Budget ledger

See `GAME_BIBLE/ART/exploration/FMPO02/GENERATION_LEDGER.md` and
`ledger/<FAMILY>.md`. Closeout totals in §9.

## 6. Known gaps, named

- The three south atlas regions cross the `south_strand_w/e` landmark goldens.
  Re-extracting a golden is an owner authorization; the south is authored
  *around* the strand until the owner rules (`UNRESOLVED`, see
  `JOURNAL/OPEN_QUESTIONS.md`).
- Q-13 (lime-band identity) stays open; region S2 encodes ART-03's recommended
  default (seaward machair) without deciding it.
- Frostpine / Heartwood are gather nodes, not items; no icon is authored for an
  item that does not exist (ART-07).

## 7. Device acceptance checklist

_(Filled at closeout.)_

## 8. Reviewer verdicts

_(Filled after the adversarial council.)_

## 9. Closeout

_(Filled at closeout.)_
