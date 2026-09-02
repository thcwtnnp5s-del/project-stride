# EPO03 — PROD-WORLD-SOUTH report

Territory: atlas **0–860 × 700–1024**. Cap **440 generations**. Branch
`fable5-executive-production-overhaul-03`. Ledger:
`GAME_BIBLE/ART/exploration/EPO03/ledger/WORLD_SOUTH.md` — per-region detail,
every measurement and every rejected roll's reason live there; this report does
not repeat them.

## What shipped

| Region | Atlas rect | Job | Seed | Cost | Goldens re-extracted |
|---|---|---|---|---:|---|
| **S1** delta shore, Sunward strand, spit | 392–820 × 740–1024 | `7922d150-b123-4b7e-a389-8ba753f09d66` | 6011 | 40 | `flock_south`, `south_strand_w`, `south_strand_e` |
| **S2** the interior sand stripe, the SW wood edge | 172–440 × 740–1024 | `24eb1233-afd0-4d8a-9ecf-63cd3b9c5242` | 6002 | 40 | `south_strand_w` |
| **S3** the SW corner | 0–256 × 700–1024 | `33079c45-666a-4e34-94d7-974224da0719` | 6013 | 40 | `south_strand_w` |
| **SA1** the Sunward Strand anchor | 484–556 × 840–890 | `b62a9726-829a-413d-881d-af0239f38883` | 6004 | 20 | `south_strand_w`, `south_strand_e` |

Assets: `GAME_BIBLE/ART/exploration/EPO03/out/atlas/{S1,S2,S3,SA1}.png` and their
`*_mask.png`; `out/atlas/manifest_south.json` (four accepted entries, salts
60–63); `src/atlas/regions_south.json`; `src/atlas/{S1,S2,S3,SA1}_crop.png`;
`assets/art/v1/world/atlas_base.png`; the re-extracted goldens under
`GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/goldens/`. Review renders:
`EPO03/review/atlas/S{1,2,3}_*`, `SA1_*`, plus the territory-wide `S0_*` set
(five phone FOVs, the whole territory before and after, the storm-knoll
handover, the `black_gable` and `flock_south` anchors).

One tool was added, inside my own round directory:
`EPO03/tools/conform-region-water.js` (see below). **No Dart file, no shared kit
file, no `package-art.js` edit, no `atlas_layout.json` edit, no registry rect
edited.**

## What was rejected, and why

| Roll | Cost | Why |
|---|---:|---|
| S1 roll 1 (`3fec50bc…`, seed 6001) | 40 | A genuinely good coast, but the tidal flats ran too far south and drowned the beach at the Sunward Strand marker (511,860) — an identity anchor under D0033 §3, not a preference. Sheets: `rejected/atlas/S1_r1.png`, `S1_r1_sunward_x4.png`, verdict file `S1_r1.txt`. |
| S3 roll 1 (`aec776d8…`, seed 6003) | 40 | The shore was right, but the generation **cleared the SW wood** and left roughly 120 × 90 atlas px of empty sward with a formless brown stain — a dead zone, and the wood DIR-01 says hosts the storm pocket. Sheets: `rejected/atlas/S3_r1.png`, `S3_r1_deadzone_x3.png`, verdict file `S3_r1.txt`. |

Both were answered by **changing the intent, never the seed**, as the loop
requires. No region needed a third roll.

## Cost

| | |
|---|---:|
| Cap | **440** |
| Jobs requested | **6**, all `inpaint_image` |
| Accepted | **4** — S1 40 · S2 40 · S3 40 · SA1 20 = **140** |
| Rejected | **2** — S1 r1 40 · S3 r1 40 = **80** |
| **Territory total (sum of the tool's own cost lines)** | **220** of 440 |

Never a balance delta (M-17). The cap was deliberately not spent out: after SA1
every defect DIR-01 named for this territory had a verdict, and further rolls
would have risked accepted terrain for no named defect. Two pieces of real work
cost nothing — the S3 water conform and the SA1 mask-geometry fix were both
deterministic.

## What the phone will show that it could not before

The **south layer cake is gone.** It was the round's P0: a ruler-straight
latitude stripe of sand at y 810–870 running 650 px across the map, with the
delta dying on it and sand lying in the middle of dry land.

- **Measured.** Sand-family coverage in the old belt **172–440 × 810–870 fell
  from 31.9 % to 2.3 %.** No sea reaches that ground, so no beach remains on it;
  east of it the belt is now an actual shore.
- **Read at 197×426 phone FOV ×2**, at five viewpoints across the territory
  (`S1_r2_fov_sunward_x2.png`, `S3_r2_fov160_x2.png`, `S0_fov_spit_x2.png`,
  `S0_fov_wood_x2.png`, `S0_fov_west_x2.png`): marsh wetting into grey silt in
  fingers; braided channels converging into one trunk that reaches the sea past
  silt bars; a broad sand beach with dune ridges set at an angle and
  gorse-dotted machair behind it, running diagonally, narrowing and swinging; a
  creek cutting the beach at a small rock headland; a one-pixel surf line and a
  ragged shoal band following the sand; the wooded headland's rim continuing as
  a spit that hooks south; and in the west a coast that swings out into a rocky
  headland with boulders standing in the water, then back into a bay.
- **The DIR-01 SOUTH criteria** at FOV (511,860) and (160,900) are met: the
  shore changes direction more than twice in view; sand width varies well over
  2:1; there is a creek mouth; the delta channels run into the flats; no band
  spans the width; the west shoreline is not vertical; the lime slab and the
  blue-blob orchard are both gone.
- **The SW corner's sea joins the map's one sea.** It measured `#4eb9a5` /
  `#2c9da3` (82 %) before — a turquoise panel that has never been inside the
  global ocean conform's rectangles, which start at x=300. It now measures
  **`#3e98a6` 100 %**, against the east sea's `#3e98a6` 99 %.
- `atlas-qa.js`: **0 repeated 10×10 sprite pairs** in all three regions. Orphan
  flecks fell or held on every rect measured against its own BEFORE (S1
  77.2 → 62.2 per 10k px; S2 identical at 82.6 — the metric is dominated by the
  sea's authored white ticks, not by the regions).

## The water conform — why a tool rather than a third roll

S3's roll came back with its own invented sea (`#438383` and hundreds of
neighbours) — the DIR-02 failure mode "a mask reaching open sea forces the model
to invent water", which PixelLab has never once got right on this map (FMPO02:
0/4). The global conform in `package-art.js` cannot repair it, because
`ocean_unify`'s rectangles start at x=300 and the south-western wedge has never
been inside them.

`EPO03/tools/conform-region-water.js` remaps the region's **open-water interior**
with `ocean_unify`'s own algorithm and its own target swatch: measure the
region's deep-water distribution, map mean/std onto the target's, snap each
mapped value to the target's own palette. Every output pixel is a colour the
accepted sea is already made of — A-2, a palette remap of an approved asset;
nothing averaged, nothing invented. It runs on my region PNG only.

What it got wrong first and now guards against: `isDeep` alone also matches the
blue-green outline pixels inside dark foliage, and the first run turned the SW
wood cyan. A pixel is conformed only when at least 80 % of its 9×9 neighbourhood
is also deep.

## Identity anchors

| Anchor | State |
|---|---|
| **Sunward Strand** (511,860) | **Closed by SA1.** Sand-family coverage in the 20×20 marker box went 2.3 % (master) → 2.8 % (after S1) → **49.5 %** (after SA1); in the wider 40² box 28.2 % → 12.3 % → **53.5 %**. The marker stands on the strand. |
| `black_gable` prop (786,786) | Wood kept under it, with its sand rim: `review/atlas/S0_gable_after_x4.png`. |
| `flock_south` golden (456,748) | Still marsh with reeds and a channel; the flock's ground reads: `review/atlas/S1_flock_ba_x6.png`. |
| Marshlight (508,708), Sunken Rows (406,711), Reedmouth (606,686), Wolfwood (334,686) | All at y < 740, inside the frozen top margins of S1/S2. Untouched. |
| `south_strand_w` / `south_strand_e` | Deliberately re-authored under D0033 and re-extracted in the same commit as each region that overwrote them. **No registry rect was edited, emptied or deleted.** |

## Storm-knoll handover (168–264 × 816–952)

**Delivered, and already consumed.** S2 and S3 painted the pocket as plain open
heath and dune ground with no hill, building or landmark, exactly as the brief
asked. PROD-WORLD-LANDMARKS has since shipped **L2 (170–266 × 856–952)** into
it, and the storm house now stands in a dark pocket with bent trees on that
ground — the handover worked with no bridge needed. Evidence:
`review/atlas/S0_stormknoll_after_x4.png`. **Nothing is outstanding for
LANDMARKS from me.** The straight runs now measurable at x=217/219/233 (18–21 px
over y 870–905) are the storm house's own walls and its cloud-pocket edge,
inside L2's rect — LANDMARKS', not mine.

## What did not close — named, not softened

1. **The y=700 edge with PROD-WORLD-WEST is un-reconciled.** DIR-01's
   shared-edge rule has SOUTH (FULL) paint y=700 × 0–320 *after* WEST. WEST's
   manifest was still empty when S3 was authored (their pending WC covers
   0–200 × 600–700), so S3's top ramp is seated against master terrain WEST may
   still replace. If WC lands, a bridge region centred on y=700 × 0–200 is the
   fix, and there is budget for it under the cap.
2. **A ×6-only tonal step** where S3's heath met S2's sward at x≈244 measured
   17 px. It is no longer measurable on the shipped composite — L2 covers that
   ground — but it is recorded because the mechanism (agreement grading
   committing a contour wherever two regions genuinely differ) will recur at
   every region join.
3. **A `--check` red flag that was not mine, now clear.**
   For part of the session `--check` threw ENOENT on
   `EPO03/out/equip/ls/traveler_coat_longsword_brace_f0.png` — PROD-EQUIPMENT's
   source, mid-flight — and once reported eight of their ambient frames stale.
   Both cleared as they landed. **Final state: `--check` green, 1,971 files up
   to date**, protected-interior drift 0, all 15 goldens held,
   `check-art-palette.js` and `check-tile-seam.js` green.
4. **The desk verdict is not the device verdict.** Every judgement here was made
   on harness renders at 197×426 ×2, not on the owner's iPhone (A-3).

## Requests filed / open questions raised

None. No shared file needed changing, and no design decision was inferred (G-3).
