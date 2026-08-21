# PixelLab Maps & Terrain Ecosystem — Evaluation

**Milestone:** PRESENTATION_WORLD_REWARD_FEEL_01 (owner brief §28–§30, §59)
**Date:** 2026-08-21
**Scope amended mid-milestone by the owner:** evaluate the *combined MCP
production model* — Maps + top-down tilesets + style-matched map objects +
raw-image/inpaint + animated overlays — against the flattened raster master,
not "web-UI Maps vs `atlas_master.png`". Documentation inspected:
`https://api.pixellab.ai/mcp/docs`.

**Recommendation: adopt the raster master for the atlas base now; adopt the
tileset/object/inpaint tools as the production pipeline around it. Do not
adopt Map Workshop maps as the atlas foundation.** The reasoning, and what
was actually tested, is below.

---

## 1. What was actually tested

Everything in this section was executed against the live account, not read
about.

| Capability | Tool(s) | Tested how | Result |
|---|---|---|---|
| Account map inventory | `list_maps` | Listed | **0 maps.** Tool replies: *"Create one in Map Workshop (pixellab.ai/map-editor) first."* |
| Map creation | — | Searched the MCP tool surface and the docs | **No `create_map` exists.** `list_maps` / `get_map` / `view_map` / `edit_map` / `place_map_object` all operate on maps that must already exist, authored by a human in the web Map Workshop |
| Tileset generation | `create_topdown_tileset` | Generated a new water→grass Wang set, chained to an existing terrain by `upper_base_tile_id` | **Works.** 16 tiles, 32 px, ~100 s, seamless against the chained neighbour |
| Tileset chaining | `base_tile_ids` | Reused the grass base tile id across three sets (grass↔stone, dirt↔grass, water↔grass) | **Works.** One shared grass identity across all three pairs |
| Tileset export | `download_png` + `download_metadata` | Fetched sheet and JSON for all three sets | **Works, and is the load-bearing finding**: metadata gives every tile's four `corners` and an exact `bounding_box`, so slicing is deterministic |
| Headless autotiling | our own `bake.js` | Authored a 45 × 25 terrain vertex grid in code, corner-matched every cell against the three sets, blitted a 1408 × 768 PNG | **Works: 0 cells missing a tile.** Proof rendered and inspected |
| Style-matched map objects | `create_map_object` | Generated a 96 × 96 walled port city, transparent, high top-down | **Works.** Clean cutout, permanent, placeable |
| Raw image, reference-styled | `create_image_pro` with `style_image_url` | Generated the 688 × 384 continent, style-referenced to the shipped master | **Works — and is what shipped** |
| Localized inpainting | `inpaint_image` | Five corrective masks on the continent (mine, woods, town, marsh, seam) | **Works, and is the reason the base painting was salvageable** |
| Animated overlays | packaged `env/overlay_*` | Thirteen overlays placed on the new layout | Works (existing assets; no new generations needed) |

### A transport defect worth recording

`inpaint_image` and `edit_image` take inline base64. Payloads above roughly
8 KB fail, and — separately and deterministically — **the trailing `=`
padding of a base64 argument is stripped in transit**, so a correctly sized
image still fails to decode with a "truncated" error that points at the
wrong cause. The fix that works: pad the PNG file to a multiple of three
bytes before encoding, so the base64 has no `=` at all. Cost before finding
it: six failed calls. A future session should pad first and keep windows
small; the `_url` variants are the better path where a public URL exists
(the repo being public made `style_image_url` trivial for the base
generation).

---

## 2. Maps: why the dedicated feature is not the foundation

The blocker is structural, not aesthetic: **there is no programmatic map
creation.** A Stride world built on Map Workshop maps would require a human
to open a browser and author the map by hand before any agent could touch
it, and every future expansion would require the same. That contradicts the
project's whole production model, in which Claude art-directs and integrates
and PixelLab generates (`RULES.md` A-1).

Three further findings, each independently sufficient to defer:

- **No structured export is documented.** `view_map` returns *a rendered
  image*; no tilemap JSON, no terrain grid export, no collision data. So a
  map's value to the app would be a PNG — which is what we already have,
  minus the authoring control.
- **The runtime story is someone else's.** The docs' runtime surface is a
  sandbox (`sandbox_create_session`, `sandbox_deploy_worker`) deploying
  Node/TypeScript to `*.dev.pixellab.run`. Stride is a Flutter app with its
  own viewport, LOD, hit targets and state. None of that transfers.
- **Nothing in Maps is needed to get the tile grammar.** The valuable half
  of Maps — Wang terrain with correct transitions — is available *without*
  it, through `create_topdown_tileset` plus the metadata. We proved that by
  building the autotiler.

---

## 3. Tilesets: adopted, and what the bake proved

The spike built a real headless pipeline: PixelLab sheets + metadata in, a
terrain grid authored in code, one flattened PNG out. It works, and the
architecture it demonstrates is exactly the split the owner proposed —
PixelLab owns terrain art, Claude/Flutter own coordinates and compositing.

**What it is good at**, on the evidence:

- **Editable geography.** Moving a coastline is editing a vertex grid, not
  repainting a picture. The current master cannot do this at all.
- **Scale without cost.** A 10× larger world is a larger grid over the same
  three sheets (~150 KB), not a 10× larger PNG.
- **Seams cannot happen** within a terrain family — the tile grammar owns
  every transition by construction, which is the direct answer to M-12.
- **Cheap terrain vocabulary.** Each new terrain pair is one ~100 s
  generation, chainable to what exists.

**Why it is not the atlas base today**, and this is the honest half:

- **It reads as a game map, not as a world.** The bake proof is clean and
  flat: uniform grass, hard-edged blobs, no depth, no regional identity, no
  painterly light. Judged against the brief's *"the map should look exciting
  to explore"* and §35's regional vibrancy, the painting wins outright at
  survey zoom. A blind reviewer would call the bake "a level", not "a
  continent".
- **Wang sets are per-terrain-pair.** Six terrains needing mutual
  transitions is a combinatorial problem the three-pair spike did not have
  to face; the grid must also be kept legal (a cell may span only one
  authored pair — the bake repaired 18 illegal vertices to stay valid).
- **Elevation, coastline character and biome blending are not expressible.**
  The continent's glacier-to-volcano range is painted depth, not tiled
  ground.

---

## 4. What shipped, and why it is the right split

The atlas base is a **single reference-styled Pro painting, corrected by
five localized inpaints** — one image, no joins, blind-QA PASS, with all
five playable locations findable and the world reading as *"a multi-day
journey region"*. The raster architecture was **not** preserved because it
existed (the brief forbids that); it was re-chosen because at survey zoom a
painted continent is what makes a player want to walk into it, and because
`inpaint_image` removes the historical reason to fear raster masters — a
defect in a painting used to mean regenerating the painting, and now means
regenerating a rectangle.

The tileset/object/image tools are adopted **around** that base:

| Layer | Owner |
|---|---|
| Base geography, regional identity | PixelLab Pro raster + inpaint corrections |
| Landmarks, settlements, ruins, vegetation props | PixelLab map objects / raw images (style-matched, transparent) |
| Terrain families for any future tiled surface | PixelLab Wang tilesets + our bake |
| Environmental animation | PixelLab overlay sprite sets |
| Coordinates, pan, zoom, LOD, discovery, routes, hit targets, labels, state, compositing, playback | Flutter / Claude |

This is the owner's proposed architecture, with one amendment earned by
evidence: the macro terrain layer is painted rather than tiled, until a
tileset round can demonstrate a blind-PASS *continent* rather than a clean
*level*.

## 5. Activity stage — the same question, answered the same way

The brief asks whether resource nodes should become reusable style-matched
modular objects instead of bespoke illustrations. **They already are**, in
effect: the shared location stage composites one Traveler over a swapped
96 × 96 node vignette, and this milestone added the missing Hardened Copper
Seam as exactly such a swap-in. `create_map_object` with a background image
is the better generator for the *next* batch — it style-matches to a
supplied backdrop and returns a transparent cutout, which is precisely the
stage's contract. Recorded for the next art round; no re-authoring of the
nine accepted vignettes is warranted.

## 6. Migration

None required. The layout schema (v3) was unchanged: the same document
describes a 2752 × 1536 world instead of 1536 × 2752, a wide base tile, and
re-authored coordinates. No save touched, no code path changed, one test
constant and one zoom-floor property updated with their reasoning recorded.

## 7. If this is revisited

The concrete uncovered question is **"can a Wang-tiled world pass a blind
read as a continent?"** — not answered here, because the spike's remit was
architecture. A future round that wants to answer it should generate a
six-terrain chained family with `transition_size` above 0, bake a region at
survey scale, composite style-matched map objects for relief and
settlements, and put *that* in front of a blind reviewer beside the painting.
The bake harness exists and the metadata contract is understood; that round
starts at the interesting part.
