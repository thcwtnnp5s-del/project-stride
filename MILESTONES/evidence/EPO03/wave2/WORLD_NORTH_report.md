# EPO03 — PROD-WORLD-NORTH report

Team `north`. Territory 0–600 × 0–300 (DIR-01). Salts 40–59. Cap **100
generations**; **45 spent**, both regions accepted on their first roll, no
re-rolls, no rejected rolls.

Ledger: `GAME_BIBLE/ART/exploration/EPO03/ledger/WORLD_NORTH.md` (call the round
dir `E/`). Regions `E/src/atlas/regions_north.json`; manifest
`E/out/atlas/manifest_north.json`; evidence `E/review/atlas/NA_*`, `NB_*`,
`NORTH_*`.

This team resumed a run that a session-limit outage killed after it had opened
the ledger, written the two region specs and published a first NA crop
(`464ed5d`). Everything cut before the outage was discarded: both crops were
re-cut from the current `assets/art/v1/world/atlas_base.png`, which by then
carried thirteen accepted regions and the three landmarks, and fresh BEFORE
evidence was taken (`1eb9c2b`).

---

## NA — the NW snowline (RECOMPOSE)

**BEFORE problem.** Three defects, all named in `PRODUCER_ATLAS_READ_01` #4 and
DIR-01's "the log's unfixed ruler line":

- a **dead-straight horizontal snow/meadow boundary** at atlas y≈267 running
  from the canvas edge to x≈171 — the ruler line;
- a **vertical patch seam** at atlas x≈171, y 258–300, the left wall of an old
  repair rectangle, with a hard value step in the snow across it;
- an **olive-brown dead-zone smear** at atlas 170–214 × 220–270 where the
  canopy should meet the snow: a low-contrast blob with no crown structure,
  in neither the canopy's hand nor the snow's.

Evidence: `E/review/atlas/NA_before_full.png`, `NA_before_x2.png`,
`NA_before_fov.png`, `NA_before_fov_x2.png`, `NA_crop_x3.png`.

**Intent.** Author altitude, not a boundary: drifts pooling in hollows and
reaching down in tongues between grey rock knolls, stony ground and brown
bracken under the last drifts, a boulder moraine at the snow's foot, firs
thinning upward into pale rime-flagged singles, the meltwater beck running
south, and the palette cooling green → grey-green → blue-white as the ground
rises. DIR-02 spine verbatim; the transition sentence swapped in.

**Geometry.** Crop atlas (0,176) 316×164; rect crop (−24,40)–(276,124) = atlas
0–276 × 216–300; ramps left 0 (canvas edge), right 32, top 32, bottom 32;
inpaint crop (0,40) 276×84. `coreAuthor: true` for the A-4 rim strip 256–276
(D0033). `reauthorizes: []` — nearest golden is `roadjoin_corridor_west` at
y=480, far outside. Frozen margins ≥40 px on all three free sides.

**Job.** `inpaint_image` `6672f5c4-4545-4efb-8abe-5c5e3a49bbb2`, seed 40,
**~25 generations**. Roll 1.

**Verdict: ACCEPT.** All three defects closed. `atlas-verify`: changed bbox
crop (0,40)–(275,123), inside the rect; changed-inside-mask 17,845;
changed-outside-mask 4,941 (blocked at packaging, not shipped); 13,551 px
dither-selected from the generation. `atlas-qa`: repeated 10×10 sprite pairs
**0**, orphan flecks **475** (peer range this round 214–609, and they are the
master's own sastrugi ticks and rime dots).

Evidence: `E/review/atlas/NA_r1_x3.png`, `NA_preview_full.png`,
`NA_preview_x2.png`, `NA_preview_fov_x2.png`, `NA_after_full.png`,
`NA_after_x2.png`, `NA_after_fov_x2.png`. Commit `1015673`.

---

## NB — the core canopy/snow treeline (RETOUCH)

**BEFORE problem.** Cut from the composite NA had just shipped into:

- a **honeycomb cell-net** drawn in the snow at atlas 278–356 × 227–252 — thin
  dark polygon outlines, the generator's tell DIR-02 failure mode 2 names;
- **gridded outlier conifers**: a row of byte-similar firs at near-equal
  spacing and identical size at y≈231–250, and a second at y≈255–270;
- the canopy meeting the snow on **one continuous unbroken front** with no
  fingers and no snow reaching down into it.

Evidence: `E/review/atlas/NB_before_*`, `NB_crop_x4.png`.

**The rect had to move, and this is the one methodological finding worth
carrying.** The spec written before the outage put the rect at atlas 256–400 ×
226–300 with a 32 px top ramp. Every one of the three defects lies at
y 227–270 — that is, **inside the top ramp**, where `atlas-mask.js` grades by
agreement and only half-commits. The honeycomb is thin dark strokes on pale
snow; its 5×5 dissimilarity lands between `AGREE_LO` 12 and `AGREE_HI` 45, so
a ramp anchored at 226 would have dithered the net rather than removed it, and
shipped half of it. The answer was not a wider ramp (G-4 forbids widening a
guard to make a mask pass) but **a different rect**.

To raise the rect top above the net without re-authoring N2's crag — a DIR-01
KEEP — the crag's actual extent was measured rather than eyeballed: a row scan
for dark low-saturation pixels puts its dense rock at **x ≥ 353, y 204–220
only**, gone by y=224. So the rect was raised to y0=192 (full mask authority
from y=224, above the net at 227) and narrowed to x1=376, which clips roughly
27×16 px of the crag's western skirt at 0.4–0.9 alpha; the prompt names the
crag as kept, and agreement grading holds the base where the two disagree. The
shipped crag is unchanged.

x1=376 also keeps the `frostmere_north_wall` golden (400–560 × 256–276)
outside its 20 px keepout, so **it was not declared in `reauthorizes` and stays
byte-exact** — no golden re-extraction was needed by this team.

**Geometry.** Crop atlas (208,148) 216×188; rect crop (48,44)–(168,148) = atlas
256–376 × 192–296; ramps 32 on all four sides; inpaint crop (48,44) 120×104.
`coreAuthor: true` — the rect lies in the A-4 rim and the hard core.
`reauthorizes: []`. Margins: left 48, top 44, right 48, bottom 40.

**Job.** `inpaint_image` `ed63f7d1-106b-42e1-add7-475a3b0786e5`, seed 41,
**~20 generations**. Roll 1.

**Verdict: ACCEPT.** The net is gone; the outliers are now firs of unequal size
at broken spacings, including one tall lone spire at the crest; the canopy edge
climbs in a spur with snow bays reaching down between the fingers.
`atlas-verify`: changed bbox crop (48,44)–(167,147), inside the rect;
changed-outside-mask 2,573 (blocked); mask `{authorized 4451, feathered 5400,
blocked 2640}` — the blocked count is the golden ramp toward
`frostmere_north_wall`, i.e. the guard doing its job, not a declaration error.
`atlas-qa`: repeated 10×10 sprite pairs **0**, orphan flecks **325**.

Evidence: `E/review/atlas/NB_r1_x4.png` (before/after pair),
`NB_preview_x2.png`, `NB_preview_fov_x2.png`, `NB_after_*`. Commit `c49500d`.

### Measuring a *drawn* repeat, per PROD-WORLD-EAST

`atlas-qa`'s repeated-pair count only sees byte-identical 10×10 blocks and read
**0 before and 0 after** — it cannot see the gridded firs at all. Both numbers,
as EAST asked:

| measure, rect 256–376 × 192–296 | before | after |
|---|---|---|
| `atlas-qa` byte-identical 10×10 pairs within 40 px | 0 | 0 |
| near-duplicate 10×10 pairs, all blocks (tol 10/channel) | 0.8 % (9,646) | 8.6 % (119,553) |
| near-duplicate 10×10 pairs, **sprite-bearing blocks only** (≥12 px below L 90) | **34** | **20** |

The middle row is a trap and is reported so the next team does not fall into
it: replacing gridded firs and a cell-net with open snowfield *raises*
whole-image near-duplicates, because flat sastrugi snow is legitimately
self-similar. Restricting the measure to blocks that actually contain a drawn
thing — at least twelve pixels of outline-dark — is what tracks the defect, and
it falls by 41 %.

---

## Territory total

| region | job | seed | cost line | verdict |
|---|---|---|---|---|
| NA | `6672f5c4-4545-4efb-8abe-5c5e3a49bbb2` | 40 | ~25 generations | ACCEPT |
| NB | `ed63f7d1-106b-42e1-add7-475a3b0786e5` | 41 | ~20 generations | ACCEPT |
| | | | **~45 generations** | 2 accepted / 0 rejected |

Cap 100, **55 unspent**. The figure is the sum of the tool's own cost lines; no
`get_balance` call was made and no balance delta is quoted (M-17).

`package-art.js --check` green, 2,302 files, after each accept. Build lock
taken and released around both packaging runs (`atlas-lock.js acquire north` …
`release north`). Committed with explicit paths only (G-8), pushed after each
accept — NA at `1015673`, NB at `c49500d`.

## Identity anchors — verified on the shipped composite

| anchor | atlas | pixel | reads |
|---|---|---|---|
| The Taiga / Longwood | (316,296) | `#55854b` | forest ✓ |
| Frozen Shelf | (445,176) | `#d9f1f7` | snow ✓ |
| The White Reach | (600,60) | `#e4f6fe` | snow ✓ |
| Glasslake | (461,334) | `#acd4e7` | ice ✓ |
| Frostmere | (498,311) | `#acd4e7` | snow ✓ |
| Worldspine | (157,333) | `#686266` | rock ✓ |
| snowdrift prop | (330,150) | `#ddeff6` | snow ✓ |
| stormdrake prop | (350,190) | — | 2 px above the NB rect, untouched ✓ |

No road route crosses either rect.

## What the phone will show

At 197×426 ×2, the north-west now reads as one continuous descent rather than a
stack of bands: high snowfield with sastrugi at the top, then snow tongues
reaching down between grey rock knolls, a boulder moraine and rust-coloured
bracken at the snow's foot, the meltwater beck winding south, and meadow with
broadleaf copses below. **You cannot point at a line where the snow ends.** The
old ruler line and the patch seam are not visible at any zoom.

East of that, the wood climbs into the snow as a spur with a tall lone spire at
its crest, snow bays reaching down between the fir fingers, and the outliers
above thinning and paling with no two the same size. The cell-net that used to
sit in the snow above the treeline is gone.

Proofs: `E/review/atlas/NORTH_fov_198_253_x2.png` (the snowline at phone FOV),
`NB_after_fov_x2.png` (the treeline at phone FOV), `NORTH_join_x5.png` (the
NA/NB join at atlas 256–276 ×5 — the 20 px rect overlap, not two ramps meeting
on the x=256 lattice; continuous, no seam, no value step).

## What did not close, named

1. **The ice-tower foundation, atlas 412–540 × 96–224, was not touched by this
   team.** DIR-01 listed it as NORTH's hand-over; PROD-WORLD-LANDMARKS' **L3
   ice bastion landed there first, at 420–540 × 116–236**, and its manifest
   blits *after* north's in `package-art.js`
   (`north/NA, north/NB, south/…, west/…, east/…, landmarks/L3, L2, L1`). Both
   north crops were placed to exclude it entirely — NB's crop stops at x=424
   and its rect at x=376. Nothing here is owed.
2. **`frostmere_north_wall` (400–560 × 256–276) was deliberately not
   re-authored.** The NB rect stops at x=376 so the golden stays byte-exact and
   the declaration is empty. The consequence: the ≈24 px strip at atlas
   376–400 × 256–276, where the golden's keepout zeroes the mask, still carries
   the *old* treeline hand. It is narrow, it abuts the wall, and it did not
   read as a defect at phone FOV — but it is the one place in the territory
   where the retouch stops short of the wall. Closing it means declaring the
   golden and re-extracting it in the same commit; that is a rect the owner
   should authorise, not a producer.
3. **The grey-green bracken band at atlas 216–256 × 246–270** (NA's cooling
   step) is more desaturated than the master's usual sward. It reads correctly
   as stony ground under drifts and was accepted, but it is the coolest,
   flattest patch in the territory and is the first thing to look at if the
   owner's device pass calls the snowline washed out.
4. **Orphan flecks are up** in the NA window (475). Judged acceptable — the
   count is dominated by the master's own sastrugi ticks and by the rime dots
   the transition asks for by name, and the peer range this round is 214–609.
   No de-fleck pass was run, so this is a stated judgement, not a measurement
   that it is harmless.
5. **Nothing here has been on a device.** Both verdicts are desk reads of the
   shipped composite at phone FOV ×2. The iPhone is the final authority.
