# PROD-WORLD-TERRAIN — FMPO02 wave 2 report

Brief: `wave1/ART-03_atlas_brief.md`. Protection facts: `wave0/GOV-04_atlas_guardian.md`.
Loop: `WORLD_ATLAS_REMASTER_01/README.md` §10 — one region at a time, no batching.
Full production record with BEFORE/AFTER, job ids, seeds, masks and verdicts:
`GAME_BIBLE/ART/exploration/FMPO02/ATLAS_REGION_LOG.md`. Ledger:
`GAME_BIBLE/ART/exploration/FMPO02/ledger/TERRAIN.md`.

**Generations: 415.1 of the 450 cap, plus 40 of the coordinator’s separate 60-gen N3 authorisation (455.1 total).** `get_balance` 9,551 → 8,353; that delta
is not mine — the wave-2 producers share one account and ran concurrently. The
per-job sum in the ledger is the authoritative figure.

## Accepted — 9 regions, all guards green

| id | atlas rect | what changed |
|---|---|---|
| W1 | 176–256 × 276–460 | Canopy face breaks into copses and lone oaks; conifer confetti becomes graded oak groves (D-01 outer half, D-17) |
| W2 | 8–180 × 258–470 | Dead sward becomes hedged foothill pasture: a beck with a stone ford, copses, bracken, rock knolls (D-18, D-24) |
| W3 | 8–200 × 596–786 | Boulder confetti becomes gathered outcrops in rough gorse grazing; three copy-pasted snow-cones gone (D-24) |
| N1 | 0–252 × 0–272 | The honeycomb crack field becomes wind-drifted snow country: sastrugi, nunataks, tarns, rime conifers (D-22, D-07) |
| N2 | 240–520 × 0–236 | Glacier cirque, crevasse field, moraine, the Ice-Mage Tower crag; ghost mountains re-cut crisp (D-08, D-22) |
| NB1 | 224–296 × 0–250 | Bridge: carries one snow slope across the N1/N2 join |
| S1 | 96–300 × 886–992 | The near-black SW slab becomes a wood with readable crowns, three glades, a stepped canopy (D-12) |
| S2 | 300–560 × 886–1024 | Dune ridges and tidal creeks run *across* latitude; the lime band stops being a band (D-02, below the strand) |
| N3 | 504–772 × 90–232 | Crack net becomes pack ice thinning off the shelf: worn floes, winding leads (D-11/D-16/D-26 partial) — roll 3, coordinator-authorised |

Every region: `package-art.js` and `--check` green — **protected-interior drift
0, all 15 landmark goldens byte-held**, no guard touched. `atlas-verify.js`
confirmed 0 changed pixels outside each mask (the two exceptions are the
deliberate ramp band below N1's rect and the off-canvas padding on the southern
crops; both are blocked by the mask and by `ty >= 1024`). `atlas-qa.js`:
**0 repeated 10×10 sprite pairs within 40 px** in every region, and fleck
density 44–59 per 10k px against the *approved* core hero region's own 69.8 —
so no despeckle was warranted.

## Not done, and why

- **N3 (North Shelf)** — rolls 1–2 failed (honeycomb; then invented flat water)
  and it was deferred. The coordinator then authorised one more roll at cap 60
  with my own diagnosis applied: **shortening the mask to y 90–232 so it never
  reaches open-sea latitudes** removed the requirement to invent water, and
  roll 3 (seed 726, 40 gens) was **accepted**. The crack net still survives
  above y=90 and east of x=772 — the deliberate price of the shorter mask.
- **E1** — gated on N3's review; N3 has no accepted review, so it never opened.
- **S3 (Delta Apron)** — deferred *without spending*, on measurement: 34.5% of
  its band is `flock_south` keepout, 10.7% frozen core, 26.7% A-4 rim. The
  built mask has **0 fully-authorized pixels**. D-09/D-19/D-25 survive.
- **S4 (SE Terrace)** — deferred *without spending*: the whole mask is inside
  `south_strand_e` + keepout. Zero writable pixels.

## Two findings that changed the method, and should outlive this round

1. **The A-4 rim cannot carry a content change.** `keepRepair` dithers the
   20 px rim ~50/50 against the master on *every* repair layer; a region's mask
   cannot switch it off. Where a region changes terrain there, the composite is
   a speckled column — the M-14 artefact. Measured on W1: 1,697 generation vs
   1,946 base px. Fixed by a per-region `rimBlock` that keeps regions out of
   the rim; the guard was not touched (G-4). Cost: the inner half of D-01's
   wall and nearly all of S3 are unreachable.
2. **Ramps must be one-sided and anchored on the inpaint edge.** A symmetric
   ramp on a jittered midline can only move the join *inward*, so half the
   columns fell back to the inpaint's own hard cut — W2 roll 1 shipped a
   razor-straight horizontal at atlas y=258, ~175 px long. Ramps now anchor at
   the rect edge with alpha 0 and carry the ±60% wander in their *width*.

   Corollary: **adjacent regions need a bridge when their crops overlap by less
   than ~60 px.** N1/N2 overlap by 12; paired ramps stopped the base leaking
   but left a straight vertical at atlas 246 down the whole phone viewport.
   NB1 — an inpaint over a crop of the *composite*, carrying both neighbours in
   its frozen margins — dissolved it.

## For the integrator

- `Scripts/art/package-art.js` gained one block, `FMPO02_ATLAS_REGIONS`, placed
  after the stamp belts and before the flotsam fills and ocean conform. It reads
  **only** `GAME_BIBLE/ART/exploration/FMPO02/out/atlas/manifest.json` plus
  `<id>.png` / `<id>_mask.png` from that directory, throws on any region whose
  status is not `accepted`, and applies the existing `protDepth`/`keepRepair`
  clip unchanged. No other packaging block was touched. No Dart, no
  `atlas_layout.json`.
- New tools (all deterministic, all committed):
  `FMPO02/tools/atlas-mask.js` (the graded mask builder),
  `atlas-review.js` (full / ×2 perimeter / 197×426 FOV),
  `atlas-verify.js` (output containment — M-15's missing check),
  `atlas-qa.js` (repeated sprites + flecks), `despeckle.js`.
- Masks are rebuilt from `src/atlas/regions.json` with
  `node tools/atlas-mask.js <id>`; they are graded against the generation on
  disk, so rebuild *after* the generation is in `out/atlas/`.
- One commit was pushed mid-round (`f71aa30`) publishing `NB1_crop.png` only,
  because PixelLab must fetch the bridge crop over HTTPS.

## UNRESOLVED — needs the owner

Recorded as **`JOURNAL/OPEN_QUESTIONS.md` Q-25**. The south strand goldens
(`south_strand_w`, `south_strand_e`, y 810–870) *are* the P0 layer-cake the
world map is being rebuilt to fix. Re-authoring a landmark means re-extracting
its golden in the same commit, and ART-03 §2 says that authorization is the
owner's. It was not assumed: S1, S2 and S4 were all shaped around the goldens
instead, which is why S4 shipped nothing and S1/S2 shipped only what lies
outside them. Q-25 also carries the A-4 rim finding, which blocks the rest of
D-01 and S3 for the same class of reason.

Every verdict above is a **desk verdict**. The physical iPhone remains the
final authority.
