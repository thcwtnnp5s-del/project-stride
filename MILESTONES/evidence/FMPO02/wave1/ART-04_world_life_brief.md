# ART-04 — World Life / Fantasy Landmark production brief

Inputs read: BRIEF_CONTEXT.md; GOV-04_atlas_guardian.md §5–6; VAWO01/WORLD_LIFE_DIRECTION_01.md + WORLD_ROUND_RECORD_01.md; atlas_layout.json (schema v5, 32 overlays, 3 props); atlas_life_review.png; dragon_flight_x4.png; the shipped PNGs (`overlay_redwyrm_f0`, `overlay_stormdrake_f0`, all 3 props).

## 0 · What round 1 actually shipped

11 gens shipped only `overlay_redwyrm`/`overlay_stormdrake` (72×32, 9f, well under the direction's own 84×40/92×26 spec) and three **static** props (Rimespire, Lanterngard, Black Gable) with no motion overlays. Zoomed to native res: **the storm drake is not a distinct silhouette** — the same bat-wing anatomy as the red wyrm, palette swapped to pale blue-white. Neither breathes; no fairies, lightning, aurora, ice-beacon motion, wolves, deer, oxcart or crows shipped — the owner's "not substantially fulfilled" verdict on 4d9a81f: inert landmarks, a recolor pair, not three animals.

## 1 · Slot budget (RULES.md R-9: ≤40 declared overlays, ≤12 in frame)

32 overlays exist → **8 slots left.** Two of the ten deliverables below supersede existing slots in place (no new slot); the other eight fill the remaining budget exactly — no headroom beyond this list. `overlay_deer` (H) is the one item to cut first if a device pass shows in-frame trouble.

## 2 · The ten deliverables

| # | Asset | Tier | Slot | Canvas | Frames×ms |
|---|---|---|---|---|---|
| A | Red Fire Dragon — supersedes `overlay_redwyrm` | HERO | same key | 84×40 | 20×350 |
| B | Blue Lightning Dragon — supersedes `overlay_stormdrake`, new silhouette | HERO | same key | 96×28 | 18×340 |
| C | Rimespire aura (pairs with `prop_rimespire`) | HERO/magic | new | 48×56 | 10×320 |
| D | Lanterngard fae court (pairs with `prop_lanterngard`) | HERO/magic | new | 56×48 | 12×300 |
| E | Black Gable storm (pairs with `prop_black_gable`) | HERO/magic | new | 56×72 | 14×260 |
| F | Wolf pack, Wolfwood — in-place scene | MID | new | 48×48 | 16×300 |
| G | Ox-cart, western valley road | MID | new | 24×22 | 6×500 |
| H | Doe + fawn, Whispering Woods glade — in-place scene | MID | new | 40×32 | 12×300 |
| I | Crows, Forgotten Hollow | SUBTLE | new | 40×32 | 10×260 |
| J | Aurora band, polar shelf — continuous | SUBTLE | new | 96×48 | 8×900 |

Method: A/B/C/D/E/G/I/J are `create_image_pixen` (still) → `animate_image`. F/H are grounded in-place scenes — `edit_image` on a small master crop → `animate_image`, the `bear2`/`yeti2` technique, frame 0 is the untouched crop. `animate_image` animates in place; world-crossing motion is always the overlay `travel` field, never baked displacement. Green `overlay_skydragon` (68×31, 28f) stays **untouched** — the size floor red must beat, blue must not shrink toward.

## 3 · Fire and lightning breath — one sprite, not two

R-7 (one `Opacity` per composited image) rules out a separate breath layer. Both bake into the same frame set as a short event window, as VAWO01 specified and never shipped: **Red** — frames 8–13/20, a forward fire cone, orange-white core, dark smoke tail, hard-edged, never a soft gradient. **Blue** — frames 1–3 charge up (dorsal spines brighten, no light yet — the "visible charge" ask), frames 4–6 fire a forked arc, white core in a violet-blue halo. **No teal/cyan** in the arc (L-16 reserves that for steps).

## 4 · Flight paths (persistent, recurring, distinct from each other)

Both reuse the `travel` mechanic proven by `overlay_skydragon`: linear motion for one play's active window, a quiet gap, replay from the same spawn — no closed-loop primitive exists (GOV-04 §5), so "persistent/recurring" means **short interval, frequent replays**, not a literal circuit.

**Red, around the volcano** — same spawn `x:4416 y:1836` (atlas 736,306, vetted clear of `volcano_east_cliff` and every marker, §1.3 of the direction). `travel:{x:22,y:-4}`, 20×350ms → 7.0s active, sweeping east-northeast across the caldera. `intervalMillis:22000` → 29s cycle, **duty 24%**, deliberately over VAWO01's old Tier-3 ceiling (≤16%) because the owner wants it seen more than once a minute.

**Blue, over Frostmere** — new spawn `x:2400 y:1650` (atlas 400,275, top of the cirque, above the north-wall golden band — legal, an air sprite never touches `atlas_base.png`, GOV-04 §5.4). `travel:{x:26,y:-6}`, 18×340ms → 6.1s active, sweeping west-to-east above the frozen lake, clearing `yeti2` and all three snow-flurry boxes. `intervalMillis:26000` → 32s cycle, duty 19%. With the untouched green dragon's Longwood corridor (atlas ≈250–420×230–340, immediately west), the three hero dragons now form one west-to-east band across the north — taiga, ice, volcano.

## 5 · Overlay JSON shape (representative)

```json
{ "asset": "env/overlay_redwyrm", "x": 4416, "y": 1836, "width": 84, "height": 40, "frames": 20, "frameMillis": 350, "intervalMillis": 22000, "travel": {"x": 22, "y": -4} }
{ "asset": "env/overlay_stormdrake", "x": 2400, "y": 1650, "width": 96, "height": 28, "frames": 18, "frameMillis": 340, "intervalMillis": 26000, "travel": {"x": 26, "y": -6} }
{ "asset": "env/overlay_fae_court", "x": 228, "y": 2040, "width": 56, "height": 48, "frames": 12, "frameMillis": 300, "playLoops": 2, "intervalMillis": 19000 }
```

C/D/E/F/G/H/I/J otherwise carry the coordinates and intervals already derived and marker-checked in WORLD_LIFE_DIRECTION_01 §1.3/§4: Rimespire aura world 4800,264; fae court 228,2040; storm house 4548,4272; wolf pack 1812,4188; ox-cart 576,3168 (`travel:{x:-11,y:2}`); crows 3216,3036; aurora 4200,168 (`drift:{x:-16,y:0}`, `opacity:0.22`, no interval — the one deliberate continuous exception, J-3). Deer (H, new): `x:2040 y:3120, width:40 height:32, frames:12, frameMillis:300, playLoops:2, intervalMillis:35000`.

## 6 · Two calls, stated rather than inferred

**Ice-mage tower location.** The owner names Frostmere; `prop_rimespire` sits outside the basin (396–565,258–400) on the outer ice shelf because the basin is already dense (marker, `yeti2`, 3 flurries, the north-wall golden). **Call: keep Rimespire where it shipped and give Frostmere its magic through the blue dragon's path (§4)** instead of crowding a landmark into the basin. If a literal second tower in the basin was intended, that's a distinct new prop (≈40×64, own base) — flag back before spending generations.

**Superseding the shipped dragons.** Same asset keys, no new JSON id: generate/select stills → `animate_image` to the new frame counts → overwrite `overlay_redwyrm_f0..19.png` / `overlay_stormdrake_f0..17.png` (old 9-frame sets move to `rejected/world/`) → update width/height/frames/frameMillis/travel/interval in `atlas_layout.json` (x/y also for storm drake) → `package-art.js --check` → regenerate and look at `phase1_world.png`.

## 7 · Reject list (fail on sight, redo)

Cyan/teal in any glow, arc, aura or beacon (L-16). A sprite shaped like a UI icon (rounded rect, badge, checkmark) instead of a creature or weather. A recolor-only "second animal" — new anatomy is mandatory. Humanoid fairies, faces, wings-on-a-girl, glitter/heart/star sparkle. A full-box white flash for lightning (must be a forked line + two-frame roof brighten). Wrong-density creatures — mascot-sized, floated with no ground/air logic, or a hard alpha rectangle on painted terrain (the retired `fire2` failure). A walking humanoid anywhere on the atlas (R-4). A vehicle on unpainted ground. A new continuous overlay inside atlas x276–706 beyond what already runs there (J-3). Anything occluding a marker, ring, label or route dot.

## 8 · Acceptance criteria

Red/blue dragons unmistakably different animals at 1:1, not a palette swap. Red seen in most 30–60s World dwells (duty ≥20%); blue reads clearly over Frostmere on a distinct path. Both breaths read as a shape, not a gradient smear, on a physical iPhone at native zoom. Green dragon's file/JSON stay byte-identical. Rimespire, Lanterngard and Black Gable each gain working motion — none ships silent again. Fairies read as restrained motes with a wing hint, never a UI square or a figure. Total overlays ≤40; no in-frame viewport exceeds 12 concurrent without an explicit owner accept. `package-art.js --check` and `atlas_layout_test` pass; A-4 core and all 15 landmark goldens byte-identical. Owner ACCEPT on a physical iPhone at opening zoom, ×2 and ×4 — desk verdicts are staging only.

## 9 · Generation budget (~350 gens, sequenced one asset at a time)

| Asset | Gens | Asset | Gens |
|---|---:|---|---:|
| A Red dragon | 50 | F Wolf pack | 35 |
| B Blue dragon | 50 | G Ox-cart | 23 |
| C Rimespire aura | 25 | H Deer | 23 |
| D Fae court | 25 | I Crows | 18 |
| E Storm house | 25 | J Aurora | 18 |
| | | Integration/golden review | 8 |

**Total 300, ceiling 350.** Each figure is stills + `animate_image` + a reject-roll buffer, roughly a 30/50/20 split. Sequence: A first (proven template, biggest owner complaint) → device-check → B (the silhouette fix) → C/D/E (wake the three silent landmarks) → F/G → H/I/J last, first to cut. Call `get_balance` before starting; never trust a remembered figure.
