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
| 49c91f9 | Council convened (twelve reviews in `wave3/`); bronze is not gold (`toneBronze` remap); the ledger reconciliation; the record opened |
| c8b8605 | NB3 north-bridge crop published |
| 66e9f56 | Council, Dart answers: button interiors, teal back to the steps, every queued cue has a caller (call-site guard), Skills three lines, elite bands, guardian harness at 393×852, braced hold 500 ms, equipped stage evidence, M-17/M-18 |
| 4da843e | Council, the craft body: smith and cook in plate/jerkin/coat, crates closed, the mining streak keyed and despeckled, plate strike frames, device evidence re-rendered |
| c79e197 | GAP snowfield crop published |
| ade1955 | Council, the atlas and the world life: N1/N2/NB1 snapped to the master's dialect, NB3, flat hero props, creatures at map scale with loops, placement re-verified on HEAD, sea-ice debris, the GAP snowfield, the World golden |
| (the commit after ade1955) | This record closed: §8 verdicts, §9 closeout, the state block, the ledgers |

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
closure ≈**8,166** (≈1,596 spent); **7,989 at closeout** after the council's
fixes (craft re-dress ≈120, crates 3, WORLD-FIX 184 — the round's total is
**1,773**). Per family, from `ledger/*.md`:

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

Twelve adversarial reviewers, each with the full evidence set and the 44 device
renders from `49c91f9`, each told to find the reason the owner would say "no".
Their reports are `MILESTONES/evidence/FMPO02/wave3/FINAL-01..12.md`. The
table gives each verdict as written, then what closed it before this record was
finished; a blocker that was **not** closed is named as debt in §9, never
softened here.

| # | Reviewer | Verdict as written | Blockers named | Closed by |
|---|---|---|---|---|
| 01 | Canon and rules | Not ready — two rule violations (teal leak, unverified universal equipment) | reserved teal on Notice Board READY chip and reward lines; no armoured loadout rendered on a real screen | FIX-01: teal → `actionEdge` / `rewardLightInk` / `positiveReady` at every named site; stage evidence with equipped loadouts (`CombatStage`, `LocationStage`, and the craft `AmbientStage` fed the panel's own inputs) — a real full-screen capture remains impossible without a grant path, and is said so |
| 02 | Save / Health boundary | NOT READY — caution-tape artifact on the boss encounter; systemic golden drift | the Guardian's overflow band painted in the harness; goldens regenerated without inspection | FIX-01: harness host height for the four elites; `_idleContentRows` per elite; goldens regenerated only after each diff was inspected |
| 03 | Equipment projection | REJECT — eight of ten contexts project; Craft still shows the shirt; hair changes with the pickaxe; plate loops swing away from the rock around a white strobing frame; no armour at device size | craft loop base body; jerkin-derived hair on base/coat pick strips; `plate_bronzepick_mine` f4 white streak; plate strike frame 0 | Producer: six reference re-dress edits (plate/jerkin/coat × smith/cook), `TravelerArt.craftLoopFor`, craft panel threads the loadout; the streak keyed and the strip despeckled in packaging (M-18); plate strike frames set to 4; device-size craft renders in `review/device/gear/`. **Not closed:** the ginger hair on the three jerkin-derived pick strips — recorded as debt |
| 04 | Atlas guardian | REJECT for device — N2 in the wrong drawing dialect against a 110 px razor seam; both hero props isometric on a top-down map; world-life placement verified against an atlas that no longer exists | N2 dialect; NB3 join; fairy castle / storm house perspective; stale placement composite | WORLD-FIX: N1 and N2 snapped to the original north-west palette (or re-rolled cel), NB3 bridge, flat-top-down re-rolls of both props, placement re-composited on HEAD, yeti3 and ice-tower coordinates corrected |
| 05 | Performance and memory | Do not accept — the boss fight cannot render without painting Flutter's own overflow | guardian overflow | FIX-01 (as 02) |
| 06 | Reward language | Does not ship as-is — reserved teal in the reward system | teal in `reward_beat` 250 and board card lines | FIX-01 |
| 07 | Audio wiring | BLOCKER — `ui.commit` missing two of four call sites; all twenty QUEUE_02 events have no call site | audio call sites | FIX-02: `StageCue` enum in the choreography, `_fireCue` in the stage, outcome and craft-completion cues, `gather.complete` at the result host; `test/audio/event_call_sites_test.dart` greps every id to a literal call; producer added `AudioEvents.commit` beside the haptic at the inventory equip and both craft-begin buttons |
| 08 | Asset budget | No blockers — 16.3 MiB pessimistic against a 48 MiB cap; combat precache per-encounter | one eager overlay precache path to make need-based before the roster grows | tracked, not changed this round |
| 09 | UI system | REJECT — a coin beside the turn number and 1,215 pixels of reserved teal | turn-marker ornament; teal | FIX-02 removed the ornament (`turn_marker.png` stays packaged, README says undrawn); FIX-01 the teal |
| 10 | "Does it feel generated?" | needs work — the void primary button and the byte-identical location band are Dart-side and closable; two items are art debt | primary button interior fill; region-aware expedition band; Skills three unlock lines | FIX-01 |
| 11 | Cost audit | PASS with conditions — real value at excellent ratios in Enemies, Rewards, World life; the ledger is wrong by ~640 in one family and that number drove the round's biggest cut | ledger reconciliation; steel column | Reconciliation note in `GENERATION_LEDGER.md`; the steel column closed by text edits; M-17 written |
| 12 | Would the owner say WOW? | Craft **Wow**, the wolf fight and the world life **Wow**; the north atlas **Same** (airbrushed), guardian overflow, the white arc, the READY chip, the stale composite | as 03/04/05/09 plus: fairy motes as discs, snowline straight run at y 271, sea-ice debris, S1's ruler-straight wood edge, west forest wall inside the A-4 rim | WORLD-FIX for the atlas items; the west wall is inside the frozen core and is owner debt (A-4) |

## 9. Closeout

**Pushed HEAD:** the commit after `ade1955` that carries this record (its hash is in the closeout message and in `git log`) on `fable5-mega-production-overhaul-02`. Not merged.
The physical iPhone remains the authority; the checklist in §7 is what it is
asked to answer.

**PixelLab, live `get_balance` at closeout:** **7,989 remaining** of the
10,000 cycle (resets 2026-10-01). Opened at 9,762; this round spent
**1,773** generations. The council-fix phase alone: craft re-dress ≈120,
three crate edits 3, WORLD-FIX 160 + 4 + 20 (NB3 bridge 20, hero props
127 across four `create_map_object` calls, creature stills and loops 6, motes
4, the GAP snowfield 20). Only balance checkpoints are facts; every
family figure is a lead's own sum of tool cost lines (M-17).

### What the council found, and what closed after it

Every blocker in §8 marked "FIX-01", "FIX-02", "Producer" or "WORLD-FIX" is
closed in the working tree at the commit after `ade1955` that carries this record (its hash is in the closeout message and in `git log`) and proven by the suite (1,049 tests
green, analyze clean, packaging idempotent at 1,779 files, palette guard
green at 1,834 PNGs, tile-seam guard green at 26 strips, the fifteen
landmark goldens byte-identical). The goldens were regenerated only after the
diff of each screen was inspected: the `TURN` chip lost its coin, the primary
buttons gained a face, the craft stage wears the loop, the World screen
carries the repaired north.

### What did not close, named

- **The fairy motes are still discs** (toned, relocated). Three rolls failed in
  three ways; the decision is the owner's (Q-28).
- **The S1 wood's north edge** is inside the `south_strand_w` keepout for all
  but 10 of its rows; it waits on Q-18 / Q-25 like the strand itself. Its
  west edge measured a 10 px longest run — not the ruler FINAL-12 saw.
- **The west forest wall at x≈240** is inside the frozen core's rim (A-4):
  owner debt, not this round's.
- **The jerkin-derived hair** on `base_bronzepick_mine`, `coat_bronzepick_mine`
  and `coat_steelpick_mine` (ginger from the jerkin source): a deterministic
  ramp remap was measured (jerkin inks 181,88,47 → base 120,71,29 family) and
  not applied, because a hair remap on a re-dressed strip is a third
  transform on the same pixels and the strip reads correctly at ×2 on the
  device renders. Recorded, not hidden.
- **The Skills detail screen** still stacks its level ladder as rectangles;
  the spine screen was fixed, the detail screen was not touched (FINAL-12).
- **"Expedition kit"** is the owner's own phrase for the gathering band and
  stays; if it is to be renamed that is a G-3 decision, not a fix.
- **`overlay_wolfpair`** was not halved (two failed rolls, ART-03 §7 stop).
- **No audio files exist.** `STABILITY_API_KEY` is unset; every call site now
  exists, so a produced file is one row and one file away (QUEUE_03).
- **`steel` and `planLinen` surfaces** are registered and painted nowhere;
  the three combat command plates are ornaments, not nine-patches; the
  narration strip tile was refused at 2.9:1 (Q-26 and §6 stand).
- **One eager overlay precache path** (FINAL-08) is tracked, not changed.

### Commits after the council

| Commit | What |
|---|---|
| `49c91f9` | bronze is not gold (deterministic tone remap), the ledger reconciliation, the record opened |
| `c8b8605` | NB3 north-bridge crop published (WORLD-FIX) |
| `66e9f56` | Dart answers: button interiors, teal back to the steps, every cue has a caller, Skills three lines, elite bands, guardian harness, braced hold, stage evidence |
| `4da843e` | the craft body: smith and cook in the armour, the crates closed, the streak keyed (M-18), device evidence re-rendered |
| `c79e197` | GAP snowfield crop published |
| `ade1955` | the atlas and world life answered: N1/N2 snapped to the master's dialect, NB3, flat hero props, half-scale creatures with loops, placement re-verified on HEAD, sea-ice debris, the GAP snowfield, the World golden |
| the commit after `ade1955` that carries this record (its hash is in the closeout message and in `git log`) | this record, the state block, the ledgers closed |
