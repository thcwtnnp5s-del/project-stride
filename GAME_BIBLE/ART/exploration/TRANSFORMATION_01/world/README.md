# TRANSFORMATION_01 — stream C: world atlas art (round record)

```
STATUS: ROUND RECORD · NOT CANON · NOTHING COMMITTED · NOTHING IN assets/
Governing brief: ../ART_DIRECTION_BRIEF.md
```

**Date:** 2026-08-17 · **Budget:** ≤ 260 generations · **Deliverables:**
`../out/world/`, `../out/env/`, `../out/world/PACKAGING.md`.

## 1. Spend

The account is shared with streams A/B/D running concurrently, so
`get_balance` deltas cannot be attributed. Account moved 1119 → 799 across this
session (all streams). **This stream, by quoted cost:**

| Calls | Tool | Quoted | Count | Sub-total |
|---|---|---:|---:|---:|
| Base geography | `create_image_pro` 384×640, 384×640, 384×688 | 40 | 3 | 120 |
| Landmarks / overlays / statics | `create_image_pixen` | 1 | 17 | 17 |
| Loop animations | `animate_image` (≤64² × 8f = 1) | 1 | 4 | 4 |
| Landmarks / props / overlays | `create_map_object` | *not quoted by tool* | 25 | ? |
| Cloud shape-shift | `animate_object` v3 | *not quoted* | 1 | ? |
| Rejected canvas probe 432×768 | `create_image_pro` | refused before billing | 1 | 0 |

**Known: 141.** If a map object bills like a pixen call (1) the total is ~167;
if it bills 5 the total is ~272. Recorded honestly as **141 + 26 unquoted
calls; ≤ 272 worst case.** Recommend measuring `create_map_object` cost in a
quiet account window before the next round.

## 2. Base geography — three candidates, one accepted

All: `no_background=false`, `style_image_url` = Traveler `south.png`,
`style_copy=["color_palette"]`, no colour words in the prompt, "terrain as
texture and massed shape, not square tiles", "no people/animals/figures/text/
labels/compass/border/frame/grid", roads enumerated by endpoint.

| Cand | Job | Size / seed | Verdict |
|---|---|---|---|
| A | `a0a73543-61e7-40b8-b94c-2645558e7fb7` | 384×640, seed 11 | Strong. Warm greens. **Defect:** the river runs straight through the palisade wall; hamlet is small and its buildings coarse. Kept as candidate. |
| B | `2ceb2660-742c-4543-a037-c811347e4cee` | 384×640, seed 23 | Meadow rendered ochre-yellow (reads as steppe/desert, not "warm greens"); Frostmere drifted to top-centre. Rejected. |
| **C** | `47861224-b8e9-4e2f-b487-6de11532b894` | **384×688**, seed 31 | **Accepted.** All five places where the brief puts them; roads connect exactly the five listed edges; a bridge at the hamlet; adit + rails + cart legible; pass drawn from mine to tarn; hollow has arch, dead trees, standing water, mist; hedgerow → oak fringe → forest and meadow → heath → scree transitions present. Palette is the most muted of the three (olive/khaki/grey), sitting closest to the Traveler. |

Measured on C: 384×688, 0 white-border rows/cols, 0 non-opaque px, 0 teal px.

**API finding:** for the 9:16 portrait ratio the tool caps at **384×688**;
432×768 is refused ("max 384x688"). 512×512 remains the square max. 384×688
was accepted and generated in the same time as 384×640.

Prompt for C is stored verbatim in the job record; shape:
> Illustrated overview map … filling the whole canvas edge to edge … terrain
> drawn as painted texture and massed shapes, not square tiles. North at top is
> cold and high; south … warm and low; west wild, east worked. Top-right: alpine
> basin, frozen tarn, snowfields, frost pines, ridge with scree. Right middle:
> foothills of scree and sparse pine, timbered mine adit, spoil heap, short rail
> line; a winding pass track climbs from the mine through a notch north-east to
> the tarn. Bottom-left: rolling meadow, small river, tiny palisaded hamlet of
> three or four lodges with one thin chimney smoke thread. Centre-left: dense
> broadleaf oak forest with one dirt track into its shade. Top-left: dark sunken
> vale, bare dead trees, standing water, mist, small mossed stone ruin arch.
> Roads: hamlet→forest; hamlet→(along river)→mine; forest edge→mine; faint
> overgrown footpath forest→vale; pass mine→tarn. Transitions … Flat matte
> pixel-art shading, light upper-left. No people, animals, figures, text,
> labels, compass, border, frame, grid.

Known residuals on C (not fixed; small, and the Tier-1 crop→inpaint pattern
was held back to protect budget): the forest track's vanishing point is drawn
as a dark canopy gap that a viewer might read as a cave (the Whispering Woods
landmark object covers it at the proposed anchor); the south-west road runs off
the frame (intended — future country, not a destination).

## 3. Landmark objects — the route that worked, and the one that did not

**`create_image_pixen` (1 gen) always returned an isometric diorama slab** —
a diamond or disc of ground under the object — across eleven attempts and four
prompt phrasings ("isolated object", "NO ground tile / NO platform / NO slab",
"building asset cutout for placing onto existing terrain", "top-down map
landmark sprite"). The drawings were good (see `candidates/landmarks/*_px*.png`)
but a slab on an atlas reads as a game piece. All rejected.

**`create_map_object` (basic mode, low top-down, single colour outline, basic
shading, "only the structures, no ground") returned clean slab-free cutouts.**
Its palette is its own (saturated), so every accepted object was
**palette-conformed** to the accepted base — each opaque pixel remapped to the
nearest colour in the base's most-used regional palette (`tools/conform.js`,
region rect per biome). This changes colours only; alpha and shape are
untouched (`RULES.md` A-2). Raw and conformed files are both in
`candidates/landmarks/`.

| Landmark | Accepted object | Rejected |
|---|---|---|
| Haven's Rest | `a43aa897-…` (`havens_rest_mo2`): palisade ring, open gate with worn path, thatched lodge, stone well | `4fd821c4` style-match crop (ring only), `57c6bea4` (chimney but no gate), `7e37b536` (tower), `7a655960` (grass disc), pixen ×5 |
| Whispering Woods | `b7abaeec-…` (`whispering_mo`): three-oak stand | `018f9c45` (single tree + mound), pixen ×3 |
| Forgotten Hollow | `e602e41d-…` (`hollow_mo`): mossed arch, dead trees, dark pool | pixen ×1 (slab) |
| Stonefall Mine | `28d6ecbf-…` (`stonefall_mo`): scree mound, timbered adit, rails, ore cart, pine | pixen ×3 |
| Frostmere | `c605aaa6-…` (`frostmere_mo2`): frozen tarn with rim, snow shore, pines, scree | `a6e7d0fa` (no rim), pixen ×1 |

**Deviations from the brief, stated:** the Haven's Rest object has **no forge
chimney** (five rolls; the ones with a chimney lost the gate, and the gate is
the L-7 lesson). The forge is signalled by the base's own smoke thread and by
the `overlay_forge_smoke` loop anchored on the lodge. The Whispering Woods
object has **no track of its own**; the base track leads into it at the anchor.

Props (all `create_map_object`, conformed): lone oak, boulder cluster, pine
clump, hedgerow, cairn, dead tree, snowdrift. Hedgerow runs edge to edge
(bounds 0..47) — acceptable for a strip that is meant to be laid end to end.

## 4. Ambient overlays

Proven first on one asset, then fanned out. What worked: **static from
`create_map_object` (lineless, flat) or pixen → `animate_image` with
`last_frame_url = first_frame_url`** to pin a seamless loop at 1 generation.
`animate_object` v3 on the cloud (`bb14b35e-…`) drifted the shape and did not
loop — rejected; the cloud ships static, drift is code.

| Overlay | Static source | Loop | Result |
|---|---|---|---|
| cloud wisp | map object `bb6738b0` | `665a4354` (4f) — **rejected**: frames 1–3 grew a stray droplet under the cloud | ships **static** |
| cloud shadow | map object `a5d0881d` | none | static; solid dark shape → compositor opacity ~0.22 |
| forest mist | map object `d0d4181c` | `a63ad2cf` 6f, loops (f0 = f6) | accepted; ~0.5 opacity |
| snow flurry | pixen `6ca783ed` | `61793cb0` 8f (frames 1–8; index 0 came back empty) | accepted |
| forge smoke | pixen `4548da21` | `e549f707` 6f, loops | accepted (tiny fleck in f2) |
| water shimmer | pixen `e715568b`, `9a345327`; map object `f0364979`, `8dba22df` | — | **FAILED**: pixen painted whole water scenes; map object returned nothing / a single yellow star. Not delivered — escalate or drop |
| first mist / smoke tries | pixen `4f8518e3` (scene), map object `5e4338eb` (2 blobs), pixen `1242a0b2` (outlined), map object `f60ca980` (thread) | | rejected |

Overlays are keyed (alpha 0/255) — "atmospheric, never opaque blobs" is met by
a compositor opacity multiplier per `PACKAGING.md`, the same way §10b Rule A
grounds sprites. Frame rates in `PACKAGING.md`.

## 5. QA sheets (`qa/`)

`sheet_objects_x1/x2/x8.png` (17 accepted objects on a checker; ×2 is the
verdict rung), `sheet_*_frames_*.png` (loops), `atlas_base_x2.png`,
`sheet_base_candidates_x1.png` (A/B/C side by side), and
`mock_atlas_x2.png` — a **review composite** of landmarks, props and two
overlays at the `PACKAGING.md` coordinates. Not a shipped asset. Filenames in
`qa/` are semantic; the lead must re-stage under opaque codes per
`NEUTRAL_STAGING_CHECKLIST.md` before spawning Visual QA.

## 6. AUTHOR ASSESSMENT

- The base is the strongest region image this project has produced: one world,
  five places where the geography says they are, five routes and no others,
  no figures, no text, edge to edge, in the Traveler's palette. I would ship
  it. Its risks are legibility of the small baked-in landmarks at ×2 on a
  phone (the overlay objects exist for that) and the muted palette reading
  "grey" rather than "warm" — A is warmer if the owner prefers warmth over
  the river-through-wall defect.
- The landmark objects are coherent as a set after conform; the Haven's Rest
  object is the weakest (no forge, gate reads as a gap with a path). The
  Frostmere object is arguably redundant over the base tarn.
- Overlays: mist and snow are quiet and right; smoke is fine; the clouds
  depend entirely on the compositor multiplier — drawn opaque they will fail.
- Water shimmer is not delivered.

QA VERDICT:

## QA VERDICT (independent Visual QA, 2026-08-17)

Blind read is contaminated: the task prompt named all five landmarks and the
geography, and qa/ filenames are semantic; treat landmark identifications as
confirmations. Verdicts at x2:

- Base C (atlas_base_x2): PASS — five regions distinct, geography plausible,
  roads connect, no grid/joystick/free-roam cue, no coin/market/signage, no
  figures, no text. Notes: forest track end reads as a hole/cave; small stray
  speck at the hollow's lower edge.
- Landmark objects (sheet_objects_x2): PASS individually — hamlet, oak stand,
  ivy arch, adit with rails, rimmed tarn all read at x2 without labels.
- mock_atlas_x2 / in-app composite: FAIL (MAJOR A/B) — hamlet object sits
  inside the base's own palisade ring; two concentric fences and base lodges
  show; visible in test/goldens/phase1_world.png. Frostmere object over the
  base lake reads pond-in-a-lake (MINOR). Arch mound and oak stand fine.
- Overlays: mist PASS-WITH-NOTE, snow PASS, smoke PASS, cloud/cloud-shadow
  PASS-WITH-NOTE — all judged on frame sheets; no x2 evidence of the
  at-opacity composite was provided; at full opacity the white cloud reads as
  a snowdrift on the meadow. Water shimmer: not delivered.

QA VERDICT (base): PASS
QA VERDICT (landmark composite as built): FAIL — double palisade at Haven's Rest.
QA VERDICT (overlays): PASS-WITH-NOTE, contingent on the opacity multiplier.

### Lead's disposition (2026-08-17)
- Haven's Rest and Frostmere ship with `landmark: null` in `atlas_layout.json`;
  the base's own hamlet and tarn are the tap targets. The two landmark PNGs
  stay packaged for a future base that lacks them.
- Overlay opacity is a layout field (`opacity`) applied by `AtlasOverlayLayer`
  (0.22 cloud shadow, 0.35–0.4 wisps, 0.4–0.5 mist, 0.7 smoke). Device pass
  to confirm.
