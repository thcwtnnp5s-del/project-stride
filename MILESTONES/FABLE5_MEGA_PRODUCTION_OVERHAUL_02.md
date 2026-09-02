# Fable 5 Mega Production Overhaul 02 — the record

```
STATUS: PRODUCTION LANDED · branch fable5-mega-production-overhaul-02 · awaiting device acceptance
From visual-audio-world-overhaul-01 @ 4d9a81f · Opened 2026-09-02
Authority: DECISIONS/0029 (interface art), 0030 (budget + audio), 0031 (density per plane)
PixelLab: 9,762 at open → ≈8,166 at close (≈1,596 spent; target was 2,000–3,000, see §5)
Evidence: MILESTONES/evidence/FMPO02/wave0 (six guardians) · wave1 (fourteen briefs)
          · wave2 (ten production reports) · wave3 (twelve adversarial reviews)
Workspace: GAME_BIBLE/ART/exploration/FMPO02/ (ledger/, ATLAS_REGION_LOG.md, review/, out/)
Device renders from HEAD: GAME_BIBLE/ART/exploration/FMPO02/review/device/ (44 at 393×852)
```

**What this document is.** The record of the second production offensive: the
owner's physical-iPhone verdict on 4d9a81f, the doctrine chosen in answer, what
was produced, what shipped, what was rejected and why, and the exact device
checklist that decides acceptance. **Nothing here has been seen on the iPhone.**

## 1. The verdict this answers

The owner installed 4d9a81f and ruled. Improved: typography, the leather
chassis, grounded gather scenes, some item icons, combat weapon states, the
Inventory figure, the Frost Lynx, save persistence. Not good enough, in the
owner's order: **world** (atlas untouched), **UI** ("large leather frame
containing ordinary rounded dark cards", everywhere), **Craft** (a database),
**equipment** (Inventory in bronze, Adventure in a shirt), **items**
(perceptual duplicates), **encounter** (a wolf in a blank box), **gathering**
(some scenes staged), **combat** (the command frame outweighs the fight),
**world life** (not delivered), **audio** (nothing new).

## 2. The doctrine — scene over frame

`wave1/ART-01_executive_doctrine.md`, binding on every family: *Stride is a
place you look into, not a form with a leather border.* One authored picture
per screen; the interface beneath it; **subtracting chrome is delivered
work.** Three failure modes with a rule each: frame inflation (one framed
element per screen), style drift (one anchor every call cites), volume without
composition (no family past 40 % of its cap before a device-scale render).

The mechanical cause of the repetition (`ART-02`): `DECISIONS/0029` named three
identity axes — band, surface, picture — and VAWO01 built only the frame.
`PanelSkin.surfacePath` was declared and read by nothing.

## 3. What landed, by commit

| Commit | What |
|---|---|
| 3184f68 | Foundation: workspace, six guardian reports, fetch/crop/serve tools |
| 9405317 | Fourteen director briefs, ten atlas crops, production rules, gitignore exception |
| 15be0da | UI architecture: `PanelSkins` inverted (chassis on `heroPlate`/`modalFrame` only), `PanelSurface` / `SurfaceTile` / `PanelSurfaces`, `PixelFrame` interior tile + `SurfaceFill`, rhythm 24/16/8, region deeps 8–13 L*, nav plate |
| b573855 | The milestone record opens; `equip-prep.js` anchors on the modal foot row |
| 3166588 | Four combat backdrops padded to 192×128 for outpainting |
| 4221cdb | Q-18 (south strand goldens), Q-19 (frostpine/heartwood items) recorded |
| 3f912ac | Audio, the half that needs no key: `ui.commit` cue, Queue 03, readiness test |
| c1c4f8c | Equipment resolver: two axes (body × held item), every context |
| 7bbee5f | Craft: station strip, hero folio, two-column tiles, locked ledger, bottom sheet |
| 237594e | Skills spines, Adventure journal, place-first header |
| a395bfd | Inventory equipment case + pack; Character folio + ledger |
| 3f1688a | 53 equipment strips prepared, feet on row 62 |
| bffa0c9 | Equipment everywhere; combat 2×2 grid; encounter band; atlas checkpoint W1–NB1 |
| 061d0fa | Production landed: 9 atlas regions + 2 bridges, world life (40/40 overlays, 6 props), enemies, items, gather, rewards, UI materials, combat backdrops + HUD, brace, re-dressed loops; goldens regenerated after inspection |
| 9e555d3 | Integration, the Dart half: brace stance, habitat plates on, chrome as material, rewards sealed |
| abc0305 | Closure: steel-tool loops on armoured bodies, armoured busts, next-unlock spines, the device evidence set |

2,521 files changed against 4d9a81f; `assets/art/v1` 8.6 MB, `assets/ui/v1` 255 KB.

## 4. Facts proven before spending

- A `create_character_state` on the canonical Traveler carries a held tool;
  `animate_character` v3 keeps armour and pickaxe through all eight frames.
  **An 80×64 state costs ≈120 generations, not the documented 20–40** (the
  equipment lead overspent its cap 909 vs 600 on that).
- v3 returns a square canvas (88–104²). `equip-prep.js` anchors on the
  **modal** foot row, keeps the **largest** component (flooding from the
  lowest pixel deleted a figure when a swing chip landed under the sole), and
  reports clipped pixels per frame.
- `edit_image` in reference mode re-dresses an accepted strip (garment
  swapped, pose and tool kept) for ≈20 generations; text mode swaps a tool
  head or recolours it to steel. This closed every named gap in the tool
  matrix after v3 failed twice on four of them.
- The three forage strips turned east to kneel; they are mirrored in
  packaging (A-2), recorded rather than hidden.
- The A-4 rim dithers 50/50 on every repair layer, so a region cannot change
  terrain inside it; masks block the rim (`ATLAS_REGION_LOG.md`, standing
  finding). Adjacent regions whose crops overlap under ≈60 px need a bridge
  (NB1, NB2). Shortening N3's mask so it never reached open sea was what made
  it pass on the third roll.
- Pixen cannot produce a ≤6 L* surface tile from a prompt; tiles are cut by
  a window search and remapped onto the ART-13 ramps (`tools/surface.js`),
  and the quarter-mirror fold in the brief was wrong at this pixel count.
- **Audio cannot be produced this session.** Only Stability AI has ever been
  used; `STABILITY_API_KEY` is unset and no key exists on the machine. The
  queue waits on one environment variable and zero code changes.

## 5. Budget ledger

Live `get_balance` at open **9,762**; after every lead and the producer's
closure ≈**8,166** (≈1,596 spent). Per family, from `ledger/*.md`:

| Family | Requested | Accepted assets |
|---|---:|---|
| Equipment (states, 63 tracks, brace, re-dress, steel column, busts) | ≈1,150 | 63 strips (9 combat loadouts × 5 tracks, 16 tool loops, 3 forage, 6 idles, 3 walks), 3 busts |
| Atlas terrain (9 regions + 2 bridges) | 475 | 11 regions on the master, guards green |
| Gather | 180 | 4 backdrops, 3 subject plates |
| Combat stage (backdrops + HUD) | 130 | 4 backdrops 192×128, 9 HUD assets |
| UI (surfaces, bands, buttons, welt, shelf) | 95 | 10 tiles, 10 bands, 2 plates, welt, shelf, workbench |
| Items | 72 | 9 re-authored, 3 salvage crates |
| World life | 60 | 17 overlays (2 superseding), 3 props |
| Enemies | 43 | 5 habitat plates, 4 hit tracks, crawler defeat, 4 elite sets, ram candidate |
| Rewards | 21 | rare-drop mark, 2 seals, notable-plate grain |
| Probes and rejected tiles | ≈12 | — |

**On the shortfall against 2,000–3,000.** The target was approximate and the
doctrine's third rule was *composition before volume*. Every family stopped
when its accepted assets covered the owner's named failures; the two families
that could have absorbed hundreds more — atlas regions S3/S4 (blocked by the
strand goldens, Q-18/Q-25) and a third combat backdrop tier — were blocked by
an owner decision or by no visible defect, not by thrift. FINAL-11 judges this
in §8.

## 6. Known gaps, named

- **S3 / S4 and the strand.** The south layer-cake is reduced, not removed:
  the sand band at y 810–870 is two byte-enforced landmark goldens, and
  re-extracting a golden is the owner's (Q-18, Q-25).
- **N3 above y 90 and east of x 772** keeps the old crack net — the price of
  the shorter mask that made N3 pass; E1 was never opened.
- **Q-19** frostpine/heartwood are nodes, not items; no icon authored.
- **Q-20** no craft-completion mark (ART-10 ruled against; task asked for it).
- **Q-22** HUD canvases: the dispatch sizes and ART-09 §3 disagree, and the
  three command plates are centred blobs rather than nine-patches — they ship
  as ornaments behind the label.
- **Q-23** the cave-shadow plate reads as a wall more than a floor.
- **Q-24** `marker_profession` still has no occasion; **Q-26** nav glyph
  candidates were authored and not swapped (they lose contrast to the shipped
  silhouettes).
- The narration strip tile measured 2.9:1 against text and was refused; the
  translucent fill stays. `bg_workbench` and `band_combat_kit` are packaged
  and unwired. `ram2_idle` ships as a candidate, not adopted.
- Audio: zero files; `AUDIO/AUDIO_PRODUCTION_QUEUE_03.md` names the blocker.

## 7. Physical iPhone acceptance checklist

Install over 4d9a81f with the existing save (state stays v9; no migration).

1. **World.** Pan the whole atlas: the west is hedged foothills with a beck,
   the north is drifted snow with nunataks and a glacier cirque, the
   north-east is pack ice off a shelf, the south-west slab is a wood with
   glades, the south coast runs in dune ridges. No rectangle, no straight
   forest wall, no dither column. Find the Fairy Castle (woods glade), the
   Storm House (SW knoll; lightning every ~13 s), the Ice-Mage Tower (north
   crag; beacon pulse). Wait for the red dragon over the volcano's north
   shoulder and its fire plume over the sea; the blue storm dragon over
   Frostmere and its lightning breath off the south-east cape. Deer, wolves,
   bear, yeti, wagon, crows, fishing boat. The strand band y 810–870 is
   deliberately unchanged.
2. **Adventure.** Full-bleed stage; the man wears the equipped armour; journal
   entries with node sketches; cork goal plates; place-first header with the
   descriptor eyebrow and the shelf.
3. **Craft.** Station strip (Forge / Bench / Cookfire), hero folio with the
   output at 96 dp and the tray, two-column tiles, one ledger line per locked
   level, bottom sheet on a tile, salvage crates on the three reclaim rows.
4. **Inventory.** Equipment case: the figure at 128 dp wearing the armour,
   three slot plates; materials at five columns, gear at three.
5. **Character.** The bust wears the armour; dressing chips; ruled ledger;
   spines with next unlocks.
6. **Skills.** Five spines on vellum with a progress rule and a next-unlock
   line; the detail has its trade band.
7. **Gather.** Equip the Bronze Chestplate and a Bronze Pickaxe: mine — the
   plated man swings a bronze pick and stays plated at rest. Swap to the
   Training Pickaxe: steel head. Woodcut with each axe; forage in each armour.
   Stonefall's rock is natural rock; the meadow bed has no plinth.
8. **Combat.** Wolf with the Bronze Longsword in the plate: taller stage,
   framed gauges, 2×2 command block on leather, one narration line on the
   stage. Brace: the sword comes across the body and holds. Take a hit and a
   stagger: the armour never reverts. Unarmed in the coat: fists. Bear, lynx,
   crawler (its defeat), guardian heavy.
9. **Encounters.** The wolf's band is 76 dp on a forest floor; the salamander
   stands in its cave; Frostmere on snow; the Hollow on roots.
10. **Items.** Hearty Stew vs Expedition Stew, Goblin-Toothed Axe, Tin-Braced
    Pickaxe, Clawguard vs Bearhide vs Frostwarden, Lynx vs Wolf pelt, Pristine
    vs Ram horn, the three reclaim crates — all read as different things.
11. **Rewards.** A rare drop carries its mark; a signature drop its leather
    seal; a masterwork its wood seal; a notable result sits on the plate
    grain; nothing flashes or counts up.
12. **Performance.** World tab pans at full rate with all forty overlays;
    combat and gather stages do not stutter on entry; no memory warning after
    ten minutes across every tab.
13. **Save.** Every figure and item from before the install is still there.

## 8. Reviewer verdicts

_(Filled from `wave3/FINAL-01..12.md` at closeout.)_

## 9. Closeout

_(Filled at closeout: the final balance, the concrete failures fixed after the
council, the pushed HEAD.)_
