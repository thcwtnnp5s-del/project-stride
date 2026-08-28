# WORLD ATLAS REMASTER 01

**Branch:** `world-atlas-remaster-01` (from `fable-v2-experiment` @ `3aabfae`)
**Status:** built, awaiting the owner's physical-device acceptance
**Round record (canonical for art decisions):**
`GAME_BIBLE/ART/exploration/WORLD_ATLAS_REMASTER_01/README.md` (Design
Thesis + production log) and `PROTECTION_PLAN.md` (coordinate protection
table).

## What this milestone is

A regional-recomposition remaster of the world atlas. Not a seam-repair
pass: the audited failure history (M-12/M-14/M-15) established that
edge-local fixes cannot repair regional incoherence, so this round
re-authored coherent geographic regions whole — protected landmarks
mechanically excluded — and fixed flat-water defects deterministically.
The atlas ships on top of the full Fable V2 experimental build so the
owner can evaluate the remastered world with the richer game.

An audit finding that framed the round: **the previously shipped composite
had never been device-reviewed** — the last atlas the owner saw
(`6c1cb88`) still contained the M-15 interior damage; everything since was
desk-reviewed only. The phone-scale audit of the current file was
therefore the honest baseline, and it found six P0 defects (visible
tile/paste rectangles), all resolved here.

## What changed

**Deterministic (0 generations):**
- The east-bay waterline at x=636 (the ocean-conform rect's own western
  edge in flat water) dissolved into a ~76 px hash-dithered shoaling ramp;
  the far-NE corner joined the global conform
  (`WORLD_ATLAS_REMASTER_01/tools/water_join.js`; `ocean_unify.js` gained
  an optional `extraRects` parameter, default byte-identical).
- Eleven pre-existing red artifact pixels on the NW nunatak row removed by
  a scoped despeckle (flotsam-fill pattern).

**Five regional recompositions** (inpaint over wide crops of the live
composite, frozen margins, custom masks; every roll's seed, job id and
verdict in the round record):
- **R1 NE Pack-Ice Corridor** — the two-dialect ice seam at x≈755, the
  truncated black wedge, mint tint and pale-sheet junctions became one
  shelf→floes→brash→open-sea gradient. 40 gens, first roll.
- **R2 West Verge** — the forest wall's worst stretch (y 576–808) became a
  wandering forest edge; the half-ghost peak completed as a finished
  outlier. 20 gens, first roll.
- **R3 + R3b SW Sketchlands** — the unpainted line-art corner became
  painted foothills/plain/coast; a surviving checker-dither column was
  corrected (R3b), with a deliberate, recorded 220 px re-authorization of
  the south_strand_w golden's west sliver. 45 gens.
- **R4 SE surf cut** — the x=512 straight land/sea edge became one
  continuous shoreline arc. 20 gens, first roll.
- **R5 NW ice rectangle** — roll 1 REJECTED (deleted the nunatak row,
  invented a lake, red flecks; preserved in `rejected/`); roll 2, narrowed
  to the straight edge below the row, accepted. 40 gens total.
- **R3c SW top-edge correction** — the independent ATLAS-H review found
  R3's own mask top shipped as a straight tone step at y=848 (a repair's
  own perimeter, never shipped per the owner's loop directive); corrected
  and accepted. 20 gens.

**Pipeline (Scripts/art/package-art.js):**
- A **regional layer**: tracked `regions_manifest.json` with an
  accepted/withheld status gate (anything else throws), masked
  dither-select blits (selection, never averaging — A-2), regions placed
  after all legacy repair layers and before the ocean conform. The A-4
  protected-interior machinery is untouched; region pixels clip against
  the rim band like any repair. (The audit's pre-snapshot alternative was
  considered and rejected: it would redefine the approved interior — an
  owner-level A-4 change no planned region needed. Recorded per G-3.)
- A **landmark-registry guard**: 15 protected features outside the master
  core (volcano east cliff, watchtowers' flanks, caravan road, stag/flock
  overlay grounds, south strand, island clusters, Frostmere's rim-band
  north wall…) held byte-wise against committed golden crops
  (`landmark_registry.json` + `goldens/`); any drift fails packaging and
  `--check`. Deliberate re-authoring = re-extracting the golden in the
  same commit.

## Budget

PixelLab: 205 generations at open → **25** at close (180 spent; ledger in
the round record). The 25-generation reserve stands exactly intact for one
owner-confirmed device defect. Remaining P1/P2 residuals (listed in the
round record; headed by ATLAS-H's F2 panel-edge remnant, the D7 floe
corner and the pre-existing green confetti over the ice cliff) are
deferred to the 2026-09-16 reset.

## Verification

- `package-art.js --check` clean — 843 files, atlas byte-reproducible from
  tracked sources (regions, masks, manifest, registry, goldens included).
- `flutter analyze` clean; atlas layout + scene tests green;
  **World goldens unchanged and passing** — every region lies outside the
  default viewport.
- Full app suite: **802/802 green** (matches v2.29's count).
- Independent ATLAS-H art-director review: **"Yes — install"** — its own
  per-pixel diff found 0 px of landmark drift (Frostmere 0/20,618,
  caravan road 0/10,240, settlements 0), no P0 findings; its one
  ship-gating-adjacent finding (F1, R3's own straight top edge) was
  corrected as R3c and re-verified before commit. Full verdict in the
  round record.

## Interaction safety

No location hit target, route polyline, label anchor or overlay layout
changed. Regions were chosen so no in-place overlay rect was repainted
(the registry guard proves the constrained ones); travelling-sprite
corridors (caravan road, ship/nessie water) byte-held or terrain-type
preserved. Zero save-format impact; health untouched; audio untouched;
gameplay untouched.

## Device acceptance checklist (owner, iPhone 15 Pro Max)

1. World tab opens on Haven's Rest exactly as before (default view is
   untouched master interior).
2. Pan north: the ice reads as ONE frozen system — shelf breaking into
   floes into open sea; no vertical seam at the old x≈755, no truncated
   black shape, no mint-green ice.
3. Pan east from Frostmere to the volcano: watchtowers present; the
   NE coast belongs to the geography.
4. East bay (Tern Isles / lighthouse): NO straight vertical waterline;
   the bay shoals bright→deep gradually.
5. Pan west of Whispering Woods: the forest edge wanders into the meadow
   (no straight wall below the caravan road's latitude); a finished snowy
   outlier peak stands at the forest edge.
6. SW corner: painted foothills and coast — no pencil-sketch hills, no
   checker column where old met new.
7. South coast below Amberfield: the shoreline sweeps continuously — no
   vertical land/sea cut at the old x=512, no checker patch.
8. NW icefield: no pasted crackle rectangle; nunatak row intact, no red
   flecks at max zoom.
9. Frostmere/Glasslake basin, all five settlements, roads, rivers, delta,
   strand, islands: unchanged.
10. Ambient overlays (volcano smoke, ripples, rustles, caravan, stag,
    flock…) still sit seamlessly on the painting — no popped rectangles.
11. Whole-world pan: count how many places still read as "pasted tiles" —
    the target is none at play zoom; report any that remain.
