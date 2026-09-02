# EPO03 — PROD-WORLD-LANDMARKS report

Team `landmarks` · brief `wave1/DIR-03_fantasy_landmarks.md` · cap **300**,
spent **159** (sum of the tool's own cost lines — `E/ledger/LANDMARKS.md`;
never a balance delta, M-17). Branch `fable5-executive-production-overhaul-03`.

## What shipped

**All three landmarks stopped being props.** The fairy castle (31×39), the
storm house (25×21) and the ice tower (48×80) were sprites standing ON the map
— an icon, a blob and a pedestal. Each is now **painted into the terrain** at
its own anchor, which is also why each survives overview zoom, where props are
hidden. All three prop rows are **deleted** from
`assets/content/v1/atlas/atlas_layout.json` (`props` 6 → 3); LANDMARKS owns
`props` and `landmarks`, and `landmarks` was not touched — every coordinate in
the gazetteer stands.

| id | atlas | job / seed | verdict | what the terrain became |
|---|---|---|---|---|
| **L3 `ice_bastion`** | 420–540 × 116–236 (crop 380,72 200×192, salt 120) | `817cd7de` / 1203 | ACCEPT (r3) | An organic ice mound with blue south faces, seracs and crevasses, drifts banked north; a crystal spire with a dark gate on the summit; a pale pillared causeway climbing from the south-west. Nothing lit under the Frozen Shelf marker (445,176); `frostmere_north_wall` untouched. |
| **L2 `storm_pocket`** | 170–266 × 856–952 (crop 130,816 176×176, salt 121) | `de827074` / 1301 | ACCEPT (r1) | A gloom hollow in the heath: a 34 px black-gabled house with three amber windows, blasted leaning trees (one split and charred), a wet track with puddles. `south_strand_w` re-extracted in the same commit (D0033). |
| **L1 `fairy_glade`** | 296–416 × 392–496 (crop 256,352 208×192, salt 122, `coreAuthor`) | `9db93810` / 1402 | ACCEPT (r2) | A glade in the oak canopy: a moss-green pool ringed all round in gold flower-light, a pale root bridge arching across it, a castle grown from three living birch trunks with amber windows at (335,452), paths winding out to a ragged canopy fringe. |

Guards on each: `package-art.js --check` green (1,971 files),
`check-art-palette` green (2,034 PNGs — no teal collision, no semi-transparent
pixel), `atlas-qa` **0 repeated sprite pairs** on all three, the A-4 drift walk
and the fifteen goldens green, and
`flutter test test/atlas_layout_test.dart test/atlas_scene_test.dart` green
after every layout edit (56 tests).

**Four overlays**, packaged through LANDMARKS' own block in
`Scripts/art/package-art.js` (header "EPO03 LANDMARKS", manifest
`E/out/landmarks/manifest.json`, 42 frames under `assets/art/v1/env/`):

| overlay | canvas · frames · cadence | how it was made |
|---|---|---|
| `overlay_fae_court` | 112×80 · 16 f · 220 ms · loops 3 · gap 14 s | Seven 9×8 px winged silhouettes on ellipses round the castle, three-frame glow trails, a gathering pulse at f10–15 (`tools/fairy-arcs.js`, 0 gens) over PixelLab's own 4-frame wingbeat. |
| `overlay_storm_rain` | 96×96 · 8 f · 120 ms · loops 6 · gap 9 s · opacity 0.55 | Churning wisps from the animate pass over the accepted still scrolled 3,6 px per frame with wrap (`tools/rain-assemble.js`, 0 gens). |
| `overlay_storm_strike` | 80×96 · 8 f · 100 ms · loops 1 · gap 11 s | Fork plus a 30 px dithered ground flash on the roof, afterglow, second fork, fade, four empty (`tools/strike-assemble.js`, 0 gens). |
| `overlay_ice_beacon_sweep` | 96×96 · 10 f · 260 ms · loops 2 · gap 9 s | Four `edit_image_pixen` passes over the shipped L3 crop, diff-keyed and mass-filtered (`tools/beacon-key.js`, 0 gens) — every overlay pixel is one the model added over terrain that already ships. |

Placement is **requested, not placed**: `overlays` belongs to PROD-WORLD-LIFE,
which had not reported. `MILESTONES/evidence/EPO03/wave2/REQUESTS_LIFE.md`
carries the four rows as exact JSON, the three rows they supersede, the paint
order (rain before strike, so the flash lands on top), and why the beacon takes
a new path. Evidence that the coordinates are right, composited onto the
shipped atlas before the rows exist:
`E/review/landmarks/PLACEMENT_f0_*.png` and `PLACEMENT_f4_*.png`.

## What was rejected, and why

| roll | cost | why |
|---|---:|---|
| L3 r1 `283d63dd` | 20 | An isometric stepped **ziggurat** with stairs, sitting on the snow — the pedestal failure again. "Three stepped terraces" is a countable unit and became a pyramid, exactly the trap DIR-02 names. Intent changed, not the seed. |
| L3 r2 `372c4ad9` | 20 | Held as a candidate: organic and plinth-free, but the causeway barely read and the spire was small. Beaten by r3, which made the causeway a road to a gate. |
| L2 r2 `1e07df6f` | 20 | Asking for a field-wide tonal shift ("the whole of this ground under a storm shadow") returned a **hard-edged dark rectangle** filling the mask exactly. r1 stands. `E/rejected/atlas/L2_r2.txt` |
| L1 r1 `9e21366e` | 20 | Castle, glade and bridge all landed — but **no pool**: the bridge crossed a dry ravine and no flower-lights existed. Two of four named features missing. |
| rain still A `0a74bbe1`, strike A `e7bd86f8` | 2 | Three cartoon cumulus clouds; a zigzag bolt glyph. |
| fairy stills ×3 `9d1d5ef4` `ba335260` `60377176` | 3 | pixen fills the 24² canvas: 15–18 px wasps and moths against a 30 px castle. Replaced by a 96×64 swarm roll to cut 9×8 px fairies from — the move that made the fae court possible. |
| sparkle B `09edcc61` | 1 | Saturated violet four-point stars; too busy for snow glitter. |
| beacon left `bb97072f` | 0 | Infra: `[500] Out of CUDA memory`, no image. Re-submitted as `397015a4`. |

Two in-flight corrections worth naming, both found by **looking at the render
rather than at the numbers**: the animate pass had emptied the rain out of six
of its eight frames (the accepted still is scrolled instead), and the rain's
wisp band read as a drawn rectangle over the heath at phone FOV until its
edges were hash-frayed with the same dither-SELECT the atlas masks use.

## What the phone will show that it could not before

At 197×426 opening zoom (`E/review/atlas/L*_after_fov.png`,
`E/review/landmarks/PLACEMENT_f*_L*_fov_x2.png`):

- **Frostmere north** — an ice bastion with a road to its gate and a beacon
  that sweeps left-centre-right over the causeway, instead of an oval plinth on
  blank snow.
- **The south-west shore** — a black-gabled house in a gloom hollow, rain
  sheeting across it at 0.55, and a fork with a 30 px ground flash on the roof
  every ~11.8 s, instead of a 25×21 blob under a 6 %-duty bolt.
- **The core wood, one pan west of Haven's Rest** — a glade with a
  flower-ringed pool, a root bridge and a birch castle, with seven fairies
  arcing in to gather at it, instead of a white speck and five toned discs.
- All three survive overview zoom, because they are terrain now.

## What did not close

1. **The four overlay rows are not in `atlas_layout.json`.** PROD-WORLD-LIFE
   owns `overlays` and had not reported; the request is filed with exact JSON.
   Until it lands, the sprites are packaged and unplaced, and
   `worldlife-composite.js` cannot show them — which is why the family's own
   `landmark-overlay-preview.js` renders the placement evidence instead.
2. **L1 was painted before PROD-WORLD-WEST's core-face region (WA).** WEST
   registered nothing all session (`manifest_west.json` is still `[]`; WA
   176,260 160×280 is still `pending`), and DIR-03 sequences L1 after it. L1's
   authored rect stops at x 296 and WA's stops there too, so no authored ground
   is contested — but **WEST must cut WA's crop from the composite that now
   contains L1 and freeze the ±40 px east margin.** That is the shared-edge
   rule; it needs saying out loud because the order was inverted.
3. **SOUTH's S3 landed after L2** and brought the shoreline to within ~15 px of
   the storm house, so the gloom pocket's west side is smaller than DIR-03's
   "NE–SW darkness fading out at the edge". Measured on the shipped composite:
   the heath 60 px east is 33.5 L\* brighter and 60 px west 24.0 L\* brighter
   than the ground at the house — the ≥25 L\* bar is met east and missed by 1.0
   west. It reads as a destination; a bridge region over 130–220 × 860–950
   would restore the pocket if the producer wants it.
4. **`overlay_ice_beacon_sweep` takes a new path**, so the old 48×80 beacon,
   `overlay_storm_lightning` and `overlay_fairy_motes` stay packaged and
   unreferenced once LIFE swaps the rows. Retiring those three emitters is a
   closeout edit for the producer — doing it here would have failed
   `atlas_layout_test` hours before the team that owns the rows could act.
5. **`ambient/traveler_plate_bronzepick_mine_f0–f7` reported `stale:`** during
   one of this family's builds — PROD-EQUIPMENT's files, mid-edit, in a
   concurrent build. Not touched by this team, and green on the last four
   builds.

No Q- raised; no save, health, economy or session call site touched; no
verification framework added. Physical iPhone remains the final authority (A-3).
