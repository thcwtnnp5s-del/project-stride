# ART-03 — World Atlas regional recomposition brief (FMPO02)

Balance queried live: **9,762 generations**, reset 2026-10-01. All coords are 1024² atlas px (world px = atlas × 6).
Baseline looked at: `assets/art/v1/world/atlas_base.png`, `VAWO01/review/atlas_life_review.png`, plus own crops of N/W/S/Frostmere.

## 0. What I actually see (the honest read)

- **North (y 0–256, ~25% of the canvas):** one enormous cracked-plate field. It reads as dried mud or shattered safety glass, not snow. No drifts, no wind, no relief, no habitation, no scale cue. This is the single largest incoherent surface and it is **entirely outside the frozen core** — fully writable.
- **West (x 0–256, y 260–860, ~15%):** flat olive sward, confetti boulders, two snow-capped cones pasted on lowland grass, one road wandering through nothing. Dead acreage. The "forest wall" at x≈250–268 reads as a wall *because the west side has no structure to compete with it* — the eye has nothing else to land on.
- **South (y 748–1024):** three stacked latitude bands (sward / pale sand / bright lime) with the sand band running through the *interior*, not the coast; a near-black forest slab on the brightest lime at (120–290, 850–960); logs and driftwood stranded inland.
- **Frostmere/Glasslake basin (403–550 × 282–362):** actually good — pale frozen lake, glacier lobes, dark conifers west. It is inside the hard-frozen core and is preserved by construction, not by care.
- **Center hero region, volcano cape, east archipelago:** good. Do not touch.

## 1. Golden rects that must not be overlapped (x0–x1 × y0–y1)

frostmere_north_wall 400–560 × 256–276 · east_watchtower_flank 744–752 × 273–323 · volcano_east_cliff 752–824 × 260–470 · roadjoin_corridor_west 216–276 × 480–558 · west_caravan_road 128–256 × 495–575 · caravan_corridor 199–245 × 506–532 · stag_box 156–184 × 493–515 · flock_south 456–520 × 748–775 · south_strand_w 128–528 × 810–870 · south_strand_e 512–800 × 810–870 · wanderers_isles_w 785–865 × 490–537 · wanderers_isles_e 920–1005 × 503–537 · cinder_skerries 920–1000 × 175–250 · far_isles 940–995 × 205–285 · ne_iceberg 974–991 × 210–225.

Frozen core: masks may write the rim **256–276 / 748–768** only; never deeper. Basin, all five locations, Amberfield and every route vertex sit inside the hard-frozen (276,276)–(748,748) and are untouched by every region below.

## 2. Region list, priority order

Each row is one full pass of the mandated loop (BEFORE → intent → generate → composite → guards → full-atlas + 197×426 phone-FOV + ×4 perimeter → ACCEPT/REWORK/REJECT) before the next starts. No batching.

| # | Region | Mask rect | Crop | Defects | Geographic intent |
|---|---|---|---|---|---|
| 1 | **W1 West Verge (forest face + taper)** | 176–276 × 276–478 | (128,228) 196×298 | D-01 N, D-17 fringe | Canopy face breaks into bays, promontories, stepping-stone groves and lone oaks over 60–80 px; a beck runs out of the trees into the meadow. |
| 2 | **W2 West Foothill Meadows** | 8–180 × 258–500 | (0,210) 228×338 | D-18, D-24, dead zone | Rolling foothill meadows terracing up to the Worldspine: hedged pasture, bracken tussocks, copses of 3–7 trees, a beck with a stone ford, sheep-crop paler on the ridges. The two lowland snow-cones become rock knolls. |
| 3 | **W3 West Downs (south)** | 8–200 × 596–806 | (0,556) 248×290 | D-24, dead zone | Same meadow language stepping south into scrub, gorse, hollow-ways and a drystone-walled sheepfold; grades into the SW woods. |
| 4 | **N1 Snow Country West** | 0–252 × 0–250 | (0,0) 300×298 | hex-ice, D-22 | Wind-drifted snowfield: sastrugi combed NW→SE, drift shadows behind ridges, rock nunataks, a frozen tarn, pale rime conifers on the south margin. Zero cell-cracks. |
| 5 | **N2 Frostmere Approach** | 240–520 × 0–252 | (196,0) 372×300 | hex-ice, D-07, D-08, D-22 | Snow uplands north of Glasslake: glacier tongues feeding the basin, a crevasse field (not a hex net), a rocky crag at (455–490, 200–248) as the **Ice-Mage Tower site**, the ghost mountains re-cut as crisp peaks. |
| 6 | **N3 North Shelf & Floe Join** | 504–772 × 0–256 | (460,0) 356×304 | D-11, D-16, D-26, mint remnant | One climatic sequence: fast ice → shelf edge → large plates (≥12 px) → brash → open cold sea. Carve ≥6 px above frostmere_north_wall and ≥20 px off volcano_east_cliff/watchtower. |
| 7 | **S1 SW Gloaming (slab)** | 96–300 × 838–986 | (48,790) 300×282 | D-12, D-02 W | The black slab becomes storm-shadowed old-growth on a rising knoll — value stepped in three plies, glades, a rutted track in, a **Storm House** clearing at (196–232, 890–918). |
| 8 | **S2 South Coastal Plain** | 300–560 × 770–1024 | (256,726) 348×346 | D-02, D-04, layer-cake | Kill the latitude stripe: dune ridges and tidal creeks run *across* latitude; the lime becomes seaward machair grading landward into sward through hedgerow and gorse; sand only where sea reaches it. |
| 9 | **S3 Delta Apron** | 372–676 × 740–808 | (332,700) 384×160 | D-09, D-19, D-25 | Braids converge east to the trunk and reach the sea; rust speckle becomes clumped reed margins and silt bars; marsh→silt interleaves in fingers. |
| 10 | **S4 SE Terrace & Spit** | 628–786 × 806–880 | (588,762) 238×162 | D-05 residue, D-15, D-20 | Dune system with a real spit toe; dissolve the pale slab's straight left edge at x≈683 and the y=836 terrace line. |
| 11 | **E1 Floe Density (gated)** | 772–1010 × 30–200 | (740,0) 300×248 | D-11/D-16 remainder | Only if N3's review says the east half still speckles. |

**Rows 8 and 10 cross `south_strand_w`/`south_strand_e`; row 7's top rows touch strand_w.** Those goldens must be **deliberately re-extracted in the same commit** (R3b pattern) — that is an owner authorization, not mine. Flagging as blocking, with `JOURNAL/OPEN_QUESTIONS.md` Q-13 (lime identity) still open. **UNRESOLVED — my recommended default if the owner does not rule:** lime stays but stops being a latitude band; it becomes seaward machair, which S2's prompt already encodes.

## 3. Method (identical for every region)

- **Primary: `inpaint_image`** over a crop of the **live shipped composite**, frozen margins, crop ≥ 44 px larger than the mask on every free side, every side ≤ 512 px. Near-perfect first-roll record (WACUI 12/12, WAR01 4/4, WAR01-R 6/7). One recorded seed per region (701…711).
- **Fallback (region fights the mask, or a whole surface needs re-texturing rather than re-drawing — N1 and W2 are the likely users): `create_image_pixflux` img2img**, ≤400 px per side, init image = the region crop pushed to `raw.githubusercontent.com` first. `init_image_strength` **0.55–0.62** where existing shapes must survive (ice/water outlines, coastline), **0.32–0.40** where composition is being replaced (W2/W3 dead acreage). Forced palette via a `reduce_colors` 48-swatch image built from the master.
- **Landmark props only: `create_image_pro`** with the palette crop as a labelled reference URL — 4 candidates at ≤170 px. Not used for terrain.
- **Prompt template (verbatim spine, region sentence swapped in):** `<geographic sentence>. Same pixel-art hand as the surrounding map: crisp one-pixel dark outlines, flat cel shading, no gradients, no painterly smudge, no anti-aliasing. Palette limited to the attached crop. No new towers, buildings, roads, rivers, text, borders or frames. No straight edges, no rectangles, no repeated identical sprites, no hex or honeycomb cell pattern.`
- **Palette anchoring:** every call carries the region's own 64×64 edge crops (N/S/E/W of the mask) from the master, committed and pushed, as the palette/reference image. Never a stylistic description of colour — always the actual pixels.
- **Boundary authoring (this is the whole game — M-12/M-14 died here):** each region ships as a `package-art.js` manifest region blitted post-snapshot, with a committed **graded grayscale mask** from `tools/prep_<id>.js`. Alpha ramps 0→255 over **24 px on free edges, 32 px where the boundary crosses a texture change** (canopy/meadow, snow/rock, sand/sward), and the ramp midline is **hash-jittered ±10 px** so no straight lattice line exists anywhere. Composite by **hash dither-select, never averaging** (A-2): every output pixel is one of the two approved images' own pixels. Alpha forced to 0 within 20 px of any golden and deeper than the A-4 rim. Mask edges are placed to land in uniform terrain, never on a feature.
- **Never generate flat water** (0/4 historical acceptance) — water stays deterministic conform.

## 4. Frostmere: hex-ice → snow country

The Glasslake basin (403–550 × 282–362) is inside the hard-frozen core; **its identity is preserved mechanically and nothing in this plan touches it**. The problem is entirely the writable band above it (y < 256), and the fix is a texture-language swap, not a geography change:

1. **Delete the cell language.** The crack net is one continuous polygon tessellation across 1024 × 200 px — the strongest "tile" signal on the map. N1/N2/N3 prompts explicitly forbid hex/honeycomb/cell patterns and replace it with *snow*: wind-combed sastrugi in a single NW→SE direction, drift shadows on the lee of every ridge and rock, cornices, blue-shadowed hollows, sun-crust glitter.
2. **Keep ice only where ice belongs.** Ice reads at three latitudes, not one: fast ice against the shore (N1 south margin), the shelf edge with a calving line (N3), then plates/brash/open sea (N3 east). Plates ≥ 12 px so shape survives minification at the ×2 opening zoom.
3. **Glasslake stays the only frozen *lake*.** Its rim band 256–276 is authored from the north side to marry the new snowfield — glacier tongues descending into the cirque, moraine stripes, a meltwater blue seam at the lake's north lip.
4. **Pale conifers.** A rime-frosted conifer belt on the snow's south and west margins (existing dark firs at 250–300 × 230–260 are the palette anchor; the new ones are paler, sparser, wind-flagged, thinning to singles northward) — this is what makes the north *country* instead of *surface*.
5. **Ice-Mage Tower site.** N2 authors a bare rock crag with a wind-scoured approach at (455–490, 200–248); the tower itself is a runtime prop (§6), so it costs the master nothing and trips no guard.
6. **Scale cues:** two yeti tracks-in-snow motifs and a wrecked sledge, hand-placed as stamps from the region's own generation — the north currently has no object that tells you how big it is.

## 5. Canvas expansion — **NO**

Decision: **do not expand.** Reasons, in order:
- **The complaint is emptiness, not size.** ~40 % of the current canvas (north band, west plain, south bands) reads as dead or incoherent. Adding acreage before that is fixed guarantees "no empty acreage" is violated on day one.
- **Memory:** 1024² RGBA decodes to exactly **4 MiB**; 1024×1280 → 5 MiB, 1280² → 6.25 MiB, against a **48 MiB** `imageCache` ceiling holding ~20 MiB of decoded art today. Affordable (+1 to +2.25 MiB) — so memory is *not* the reason to refuse, and I want that on the record so nobody re-litigates it as a budget question.
- **Viewport:** at the opening zoom (2/6) the phone sees **197 × 426 atlas px** — the world is already 5.2 screens wide by 2.4 tall. 1280 makes it 6.5 wide; more panning to reach the same five locations, for land with no destinations on it.
- **Risk:** new canvas is new *tiles*, which is precisely the M-12 failure (independently generated tiles never became one painting). Every region below instead re-authors *inside* an existing painting with frozen margins — the method with the near-perfect record.
- **Coordinate blast radius:** growing north or west shifts every location anchor, route vertex, overlay and prop in `atlas_layout.json`. Only a south/east append avoids it, and south/east is where the goldens and the open sea already are.

**Conditional reopen:** if, after regions 1–8 are ACCEPTED on device, the owner still wants more world, the cheapest honest expansion is a **+256 px south strip (1024×1280)** carrying the Sunward Strand's archipelago and a harbour hamlet — a real destination, not filler. Not this round.

## 6. Landmark and habitat placement (runtime props/overlays — zero master pixels, zero A-4 exposure)

Props and overlays composite at runtime over `atlas_base.png`, so none of this trips the core or landmark guards. Each prop sprite carries its own ground (a glade ring, a snow apron, a clearing) inside its transparent bounds.

| Feature | Kind | Atlas rect (native) | World anchor (×6) | Notes |
|---|---|---|---|---|
| **Fairy Castle** | prop, 64×80 | 303–367 × 392–472 | (2010,2832) anchor (32,79) | Whispering Woods glade NNW of the marker (383,509); clear of all three WW routes and of Haven's Rest. Pale spires + a painted glade ring; ambient fairy-mote overlay 32×32 beside it. |
| **Storm House** | prop, 56×64 | 190–246 × 858–922 | (1140,5148) anchor (28,63) | The SW Gloaming knoll authored by region S1 — the map's darkest pocket, and it turns a P0 defect into a destination. Pairs with the storm drake and a lightning-flicker overlay. |
| **Ice-Mage Tower** | prop, 48×80 | 452–500 × 172–252 | (2712,1032) anchor (24,79) | The N2 crag; reads against snow, north of and above the Glasslake, clear of frostmere_north_wall (y≥256). |
| Red dragon | overlay (exists) | perch at 736–760 × 296–320 | (4416,1836) | Keep; add a second cliff-perch idle on volcano_east_cliff's north shoulder. |
| Blue storm dragon | overlay | Frostmere circuit 380–500 × 190–230 | spawn (2280,1140), travel (+30,+6) | Owner asked for Frostmere/storm — **move the primary drake north**; keep a second storm-coast play near the Storm House at (4992,4128). |
| Caravans | overlays ×3 | west road (128–256 × 495–575, existing); HR↔Stonefall at 500–540 × 500–512; HR↔WW at 400–430 × 512–522 | — | On roads only; travel along the route heading, 45–60 s intervals. |
| Deer / stag | overlays ×3 | W1 taper 200–260 × 300–470; SW fringe 250–300 × 840–880; Longwood edge 430–460 × 600–640 | — | Woods **edges**, never interiors — that is where they read. |
| Bears | overlays ×2 | Longwood interior 320–360 × 640–690; Gloaming 150–190 × 900–940 | — | Deep woods, long intervals (>30 s). |
| Yetis | overlays ×3 | 300–340 × 130–170; 600–640 × 160–200; existing 490,324 | — | New snow country; one crossing a drift, one at the wrecked sledge. |
| Settlement life | overlays | Haven's Rest 440–475 × 505–540; Amberfield; W2 sheepfold 60–90 × 400–430 | — | Chimney smoke, lantern flicker, a cart on the yard track. Nothing may obscure a marker or a route. |

## 7. Generation budget (~600 of 9,762) and acceptance

| Item | Gens |
|---|---|
| Regions 1–3 (west), two-roll capacity | 3 × 40 + 40 = 160 |
| Regions 4–6 (north/Frostmere), two-roll capacity | 3 × 40 + 40 = 160 |
| Regions 7–8 (SW Gloaming, South plain) | 2 × 40 + 40 = 120 |
| Regions 9–10 (delta apron, SE terrace) | 2 × 25 = 50 |
| Region 11 (gated) | 25 |
| 3 landmark props (`create_image_pro` 1 primary + `pixen` candidates/edits) | 45 |
| Creature/ambient frame sets (`animate_image`, 1–3 each) | 25 |
| Correction reserve (untouchable below) | 25 |
| **Total** | **~610** |

Hard stops: a region fails twice → restore the composite, record, defer (M-12). Any guard throw → stop, do not weaken the guard (G-4). Reserve is never spent on a new region.

**Acceptance criteria, applied per region before the next one opens:**
1. `package-art.js --check` green: A-4 core drift 0, all 15 landmark goldens byte-held (or a deliberate re-extraction whose git diff is in the same commit and named in the log).
2. Mask containment: no changed pixel outside the declared mask; the full-atlas diff vs the previous accepted composite is entirely inside the region rect.
3. **Blind phone-FOV read** at 197 × 426 atlas px, before/after pair, over the region *and* over each of its four perimeters: no rectangle, no straight boundary, no repair footprint, no dither column.
4. **×4 max-zoom perimeter strips** on all four sides: one drawing hand, one detail scale, one palette — no dialect step.
5. Geographic read stated in one sentence by a viewer who was not told the intent, and it matches the intent line in §2.
6. No new straight edge, no repeated identical sprite pair within 40 px, no orphan flecks (despeckle deterministically before review, not after).
7. Marker, route polyline and label ground unobscured and unmoved; no location hit target changed.
8. Recorded in `WORLD_ATLAS_REMASTER_01/README.md` production log with BEFORE/AFTER crops, seed, job id, billed generations, and an explicit ACCEPT / REWORK / REJECT — then, and only then, the next region.

The physical iPhone remains the final authority; every desk verdict above is staging for the owner's device checklist.
