# ART-04 — World Life / Fantasy Landmark production brief

Role: ART-04. Inputs read: BRIEF_CONTEXT.md; GOV-04_atlas_guardian.md §5–6;
VAWO01/WORLD_LIFE_DIRECTION_01.md + WORLD_ROUND_RECORD_01.md; atlas_layout.json
(schema v5, 32 overlays, 3 props today); atlas_life_review.png; dragon_flight_x4.png;
the shipped PNGs (`overlay_redwyrm_f0`, `overlay_stormdrake_f0`, all three props).

## 0 · What round 1 actually shipped, looked at directly

Round 1 (11 gens) shipped only 5 assets: `overlay_redwyrm`, `overlay_stormdrake`
(both 72×32, 9f, well under the direction's own 84×40/92×26 spec), and three
**static** props (Rimespire, Lanterngard, Black Gable) with no motion overlays.
Zoomed to native res: **the storm drake is not a distinct silhouette** — same
bat-wing dragon anatomy as the red wyrm, palette swapped to pale blue-white.
Neither dragon breathes. No fairies, lightning, aurora, ice-beacon motion,
wolves, deer, oxcart or crows shipped. That is why the owner's verdict on
4d9a81f reads "not substantially fulfilled": the landmarks are inert and the
two dragons are a recolor pair, not three distinct animals.

## 1 · Slot budget (hard constraint, RULES.md R-9)

≤40 declared overlays, ≤12 in frame at any zoom. **32 exist today → 8 slots
left.** Two of the ten deliverables below **supersede existing slots in
place** (no new slot). Eight genuinely new overlays exactly fill the
remaining budget — there is no headroom for anything not listed here.
`overlay_deer` (item H) is the one item to cut first if a device pass shows
in-frame count trouble; everything above it is an explicit owner ask.

## 2 · The ten deliverables

| # | Asset | Tier | Channel | Canvas (native px) | Frames×ms | PixelLab method |
|---|---|---|---|---|---|---|
| A | Red Fire Dragon (supersedes `overlay_redwyrm`) | HERO | overlay, same key | 84×40 | 20×350 | `create_image_pixen` still → `animate_image` |
| B | Blue Lightning Dragon (supersedes `overlay_stormdrake`) | HERO | overlay, same key | 96×28 | 18×340 | `create_image_pixen` still (new silhouette) → `animate_image` |
| C | Rimespire aura (pairs with existing `prop_rimespire`) | HERO/magic | overlay, new | 48×56 | 10×320 | `create_image_pixen` → `animate_image` |
| D | Lanterngard fae court (pairs with `prop_lanterngard`) | HERO/magic | overlay, new | 56×48 | 12×300 | `create_image_pixen` → `animate_image` |
| E | Black Gable storm (pairs with `prop_black_gable`) | HERO/magic | overlay, new | 56×72 | 14×260 | `create_image_pixen` → `animate_image` |
| F | Wolf pack, Wolfwood | MID | overlay, new, **in-place scene** | 48×48 | 16×300 | `edit_image` (crop) → `animate_image` |
| G | Ox-cart, western valley road | MID | overlay, new | 24×22 | 6×500 | `create_image_pixen` → `animate_image` |
| H | Doe + fawn, Whispering Woods glade | MID | overlay, new, in-place scene | 40×32 | 12×300 | `edit_image` (crop) → `animate_image` |
| I | Crows, Forgotten Hollow | SUBTLE | overlay, new | 40×32 | 10×260 | `create_image_pixen` → `animate_image` |
| J | Aurora band, polar shelf | SUBTLE | overlay, new, continuous | 96×48 | 8×900 | `create_image_pixen` → `animate_image` |

Green `overlay_skydragon` (68×31, 28f) is **untouched** — no JSON edit, no
regeneration. It is the proven template and the size floor: red must read
larger, blue must read as a different animal, neither may shrink toward it.

`animate_image` animates in place; every world-crossing motion in this brief
is the overlay `travel` field, not baked walk-cycle displacement.

## 3 · Fire and lightning breath — one sprite, not two

R-7 (one `Opacity` per composited image) rules out a separate breath layer.
Both breaths are baked into the same frame set as a short *event window*
inside the loop, exactly as VAWO01 specified and never shipped:
- **Red:** frames 8–13 of 20 carry a forward fire cone, orange-white core with
  a dark smoke tail, drawn as a hard-edged shape (never a soft gradient blob).
- **Blue:** frames 1–3 are a charge-up (dorsal spines brighten, no light yet —
  this is the "visible charge" the owner asked for), frames 4–6 fire a forked
  branching arc, white core in a violet-blue halo. **No teal/cyan** anywhere
  in the arc (L-16 reserves that family for steps).

## 4 · Flight paths (persistent, recurring, distinct from each other)

Both reuse the `travel` mechanic proven by `overlay_skydragon`: linear motion
for one play's active window, a quiet gap, then replay from the same spawn —
no closed-loop primitive exists (GOV-04 §5), so "persistent/recurring" is
delivered through **short interval, frequent replays**, not a literal circuit.

**Red — around the volcano.** Same spawn as today, `x:4416 y:1836`
(atlas 736,306, already vetted clear of `volcano_east_cliff` and every marker,
WORLD_LIFE_DIRECTION_01 §1.3). `travel:{x:22,y:-4}`, 20×350ms → 7.0 s active,
sweeping east-northeast across the caldera face. `intervalMillis:22000` →
29 s cycle, **duty 24%** — deliberately over VAWO01's old Tier-3 ceiling
(≤16%) because the owner wants it seen reliably more than once a minute.

**Blue — over Frostmere.** New spawn `x:2400 y:1650` (atlas 400,275, along
the top of the Frostmere cirque, above `frostmere_north_wall`'s golden band —
legal: an air sprite compositing at runtime never touches `atlas_base.png`,
GOV-04 §5 point 4). `travel:{x:26,y:-6}`, 18×340ms → 6.1 s active, sweeping
west-to-east above the frozen lake, clearing `yeti2` and all three
snow-flurry boxes. `intervalMillis:26000` → 32 s cycle, duty 19%.

With the untouched green dragon's Longwood corridor (atlas ≈250–420×230–340,
immediately west), the three hero dragons now form one west-to-east band
across the north — taiga, ice, volcano — not two recolors and an outlier.

## 5 · Overlay JSON shape (representative entries)

```json
{ "asset": "env/overlay_redwyrm", "x": 4416, "y": 1836, "width": 84, "height": 40,
  "frames": 20, "frameMillis": 350, "intervalMillis": 22000,
  "travel": {"x": 22, "y": -4} }

{ "asset": "env/overlay_stormdrake", "x": 2400, "y": 1650, "width": 96, "height": 28,
  "frames": 18, "frameMillis": 340, "intervalMillis": 26000,
  "travel": {"x": 26, "y": -6} }

{ "asset": "env/overlay_fae_court", "x": 228, "y": 2040, "width": 56, "height": 48,
  "frames": 12, "frameMillis": 300, "playLoops": 2, "intervalMillis": 19000 }
```
C/D/E/F/G/H/I/J otherwise carry the exact coordinates, frame counts and
intervals already derived and marker-checked in WORLD_LIFE_DIRECTION_01
§1.3/§4: Rimespire aura world 4800,264; fae court 228,2040; storm house
4548,4272; wolf pack 1812,4188; ox-cart 576,3168 (`travel:{x:-11,y:2}`);
crows 3216,3036; aurora 4200,168 (`drift:{x:-16,y:0}`, `opacity:0.22`, no
interval — the one deliberate continuous exception, J-3). Deer (H) is new
this brief: `x:2040 y:3120, width:40 height:32, frames:12, frameMillis:300,
playLoops:2, intervalMillis:35000`.

## 6 · Ice-mage tower placement — a call, stated not inferred

The owner's ask names Frostmere; the shipped `prop_rimespire` sits outside
the Frostmere basin (396–565,258–400) on the outer ice shelf, because that
basin is already dense (marker, `yeti2`, 3 snow flurries, the north-wall
golden). **Call: keep Rimespire where it shipped, and give Frostmere its
"in Frostmere" magic through the blue dragon's new path (§4)** rather than
crowd a landmark into the basin. If the owner meant a literal second tower
standing in the basin, that is a distinct new prop (≈40×64, own base) — flag
back before spending generations on it.

## 7 · Superseding the shipped dragons

Same asset keys (`env/overlay_redwyrm`, `env/overlay_stormdrake`) — no new
JSON id, nothing else needs to know a creature changed. Generate/select new
stills → `animate_image` to the new frame counts → overwrite
`overlay_redwyrm_f0..19.png` / `overlay_stormdrake_f0..17.png` (old 9-frame
sets move to `rejected/world/`, never left in `env/`) → update width, height,
frames, frameMillis, travel and interval in `atlas_layout.json` (x/y changes
for storm drake only) → `package-art.js --check` → regenerate
`test/goldens/phase1_world.png` and look at it before accepting.

## 8 · Reject list (fail on sight, redo)

Cyan/teal in any glow, arc, aura or beacon (L-16). A sprite shaped like a UI
icon (rounded rect, badge, checkmark) instead of a creature or weather. A
recolor-only "second animal" — new anatomy is mandatory. Humanoid fairies,
faces, wings-on-a-girl, glitter/heart/star sparkle. A full-box white flash for
lightning (must be a forked line + two-frame roof brighten). Wrong-density
creatures — mascot-sized, floated with no ground/air logic, or a hard alpha
rectangle sitting on painted terrain (the retired `fire2` failure). A walking
humanoid anywhere on the atlas (R-4). A vehicle on unpainted ground. A new
**continuous** overlay inside atlas x276–706 beyond what already runs there
(J-3). Anything occluding a marker, ring, label or route dot at any zoom.

## 9 · Acceptance criteria

1. Red/blue dragons unmistakably different animals at 1:1 — different
   silhouette family, not a palette swap (fixes the round-1 defect).
2. Red dragon seen in most 30–60 s World dwells (duty ≥20%); blue reads
   clearly over Frostmere on a distinct path from red.
3. Both breaths read as a shape, not a gradient smear, on a physical iPhone
   at native zoom.
4. Green dragon's file and JSON entry stay byte-identical.
5. Rimespire, Lanterngard and Black Gable each gain working motion (aura /
   fae court / storm) — none ships silent again.
6. Fairies read as restrained motes with a wing hint, never a UI square or
   a figure.
7. Total declared overlays ≤40; no in-frame viewport exceeds 12 concurrent
   without an explicit owner accept.
8. `package-art.js --check` and `atlas_layout_test` pass; A-4 core and all
   15 landmark goldens byte-identical (nothing here writes `atlas_base.png`).
9. Owner ACCEPT on a physical iPhone at opening zoom, ×2 and ×4 — desk
   verdicts are staging only.

## 10 · Generation budget (~350 gens, sequenced one asset at a time)

| Asset | Gens | Asset | Gens |
|---|---:|---|---:|
| A Red dragon | 50 | F Wolf pack | 35 |
| B Blue dragon | 50 | G Ox-cart | 23 |
| C Rimespire aura | 25 | H Deer | 23 |
| D Fae court | 25 | I Crows | 18 |
| E Storm house | 25 | J Aurora | 18 |
| | | Integration/golden review | 8 |

**Total 300, ceiling 350.** Each row is stills (`create_image_pixen`/
`edit_image`) plus `animate_image` plus a reject-roll buffer, roughly
30/50/20 split. Sequence: A first — proven template, biggest owner
complaint — device-check, then B (the silhouette fix), then C/D/E (wake the
three silent landmarks), then F/G, then H/I/J last and first to cut. Call
`get_balance` before starting; never trust a remembered figure.
