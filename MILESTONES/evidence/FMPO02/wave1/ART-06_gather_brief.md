# ART-06 — Gathering Environment Director, FMPO02 Wave 1

```
STATUS: DIRECTION, FOR REVIEW
Governed by: GATHER_SCENE_DIRECTION_01.md, DECISIONS/0031 (L-18a), GOV-03 §7
Scope: keep architecture (region×skill backdrop, grounded subject, 22/22
       uniqueness, per-skill animation) — fix residual staging only.
```

Verdicts are from looking at the shipped packaged plates
(`assets/art/v1/work/*.png`, cropped ×3–×8 with `Scripts/art/png.js`) and the
four rendered stage composites in `review/stage_after/`. **Finding up front:**
`review/stage_after/mine_copper_*` and `mine_tin_*` render the superseded
96 px `prop_copper_seam.png`/`prop_tin_seam.png` (the "egg" boulders), not
the shipped `prop_copper_face.png`/`prop_tin_face.png`. That evidence capture
is stale; code (`ambient_assets.dart:695-708`) already points at the right
files. Re-capture before the next device pass.

## Per-scene verdict — all 22 nodes

| # | Node | BD | Sub | Verdict | Reason (seen) |
|---|---|---|---|---|---|
| 1 | meadow_patch | B1 | S1 | **IMPROVE SUBJECT** | `prop_meadow_bed`: closed round hedge-dome on an authored soil-ring plinth — a potted plant. Backdrop excellent. |
| 2 | mill_garden | B8 | S1 | **IMPROVE SUBJECT** | Same defective bed; garden backdrop strong on its own. |
| 3 | oak_stand | B2 | S6 | KEEP | Stump+notch+log+woodpile in sunlit clearing — the set's best scene. |
| 4 | heartwood_oak | B2 | S12 | KEEP | Heavier-bole variant reads well in the same clearing. |
| 5 | warded_grove | B9 | S6 | KEEP | Blazed oaks/ward-stakes backdrop + oak cut is coherent. |
| 6 | duskcap_grove | B3 | S2 | KEEP | Mossed branch+fungus sits into litter; soft island base, not a hard plinth. |
| 7 | copper_seam | B4 | S8 | **IMPROVE BACKDROP** | Ore face is convincing rock; mine wall behind it is dressed ashlar with no natural rock — a boulder against a built corridor. |
| 8 | old_workings | B10 | S11 | KEEP | Collapsed drystone ruin against built lift chamber — worked stone beside worked stone. |
| 9 | tin_seam | B4 | S9 | **IMPROVE BACKDROP** | Same masonry mismatch as copper_seam. |
| 10 | deep_tin_seam | B4 | S13 | **IMPROVE BACKDROP** | Same. |
| 11 | hardened_copper_seam | B10 | S10 | **IMPROVE BACKDROP** | Lift-chamber wall, same all-dressed-stone problem. |
| 12 | gallery_tin_lode | B11 | S9 | **IMPROVE BACKDROP** | Gallery is a near-black dressed-stone tunnel; floor band under the subject reads near-zero luminance. |
| 13 | collapsed_span | B11 | S11 | KEEP | Ruin subject matches the tunnel's built stone. |
| 14 | rimefrost_hollow | B6 | S3 | **IMPROVE SUBJECT** | `prop_rime_cushion`: closed round mound on a soil-ring plinth — a pot in a beautiful scree/tarn backdrop. |
| 15 | sheltered_frost_meadow | B12 | S3 | **IMPROVE SUBJECT** | Same defective cushion; windbreak-lee backdrop fine. |
| 16 | frostpine_stand | B5 | S7 | KEEP | Felled bole + needle spray integrates into the treeline shelf. |
| 17 | oldgrowth_frostpine | B5 | S14 | KEEP | Thicker variant, same good backdrop. |
| 18 | silkstrand_thicket | B7 | S4 | **IMPROVE BACKDROP** | `bg_hollow_foraging` reads as a lit cave tunnel, not a vale floor; centre column drops near-black. |
| 19 | hollow_thicket | B7 | S5 | **BOTH** | Backdrop as above; `prop_hollow_root` is a claw-shaped root cluster on a closed dark diamond islet — a potted specimen. |
| 20 | veiled_silkstrand | B13 | S4 | KEEP | Field-camp backdrop strong; silk bed integrates. |
| 21 | undercroft_silkfall | B14 | S4 | KEEP | Vault backdrop reasonable; silk bed reads fine. |
| 22 | deep_hollow_thicket | B14 | S5 | **IMPROVE SUBJECT** | Same defective root plinth; vault backdrop fine. |

**12 KEEP · 6 IMPROVE BACKDROP · 5 IMPROVE SUBJECT · 1 BOTH.**

## Missing region×skill backdrops

**None.** All 7 base pairs and all 7 project-built variants exist; every node
resolves to a keyed plate (`_regionWorkBackdrops`/`_builtBackdrops`,
`ambient_assets.dart:522-545`). The three pre-VAWO01 profession fallbacks
(`bg_mining/woodcutting/foraging.png`) are dead code for this content graph.

## Re-author list — 4 distinct assets, ~235 gens

Only three subjects and one backdrop family (three files) need re-authoring.

### Subjects — 48×48 transparent, `create_image_pixen`, `no_background: true`

**Camera:** shallow three-quarter, matching the stage/figure camera (§6.3) —
**not** backdrops' `low top-down`, **not** icons' `high top-down`. Same
camera the Traveler is drawn in.

| Plate | Fix | Construction clause |
|---|---|---|
| `prop_meadow_bed` | Delete soil-ring plinth; ragged top, bleeds off both edges, no basket | "grass-blade bed with pale cream umbels on thin stems, spreading off both canvas edges, no basket, no pot, no soil ring, mass reaching the bottom edge, open along its base" |
| `prop_rime_cushion` | Delete closed mound+ring; crevice must cut INTO the frame edge | "tight low mound of blue-grey cushion foliage growing from a crack in broken rock, the crack open at the frame's left or right edge, small white flowers, crust only inside the crevice, no soil ring, no potted silhouette" |
| `prop_hollow_root` | Delete dark diamond islet; roots break the peat asymmetrically, off one edge | "bone-pale roots breaking up out of black wet peat, one root levered clear lying across the frame, wet soil crumbs, peat running off the canvas's left edge, no diamond base, no isometric tile" |

**Palette anchor (extends §4.0 to subjects):** `style_image_url` = the node's
own backdrop plate (not the location vignette — the subject sits in the
backdrop), `style_copy: ["color_palette"]`, no palette words in-prompt. Stops
a re-roll drifting off its backdrop's value range, the way `prop_rime_cushion`
currently sits hotter than Frostmere's scree.

**Prompt shape** (STYLE_SPEC §7): noun phrase → presentation clause →
construction clause above → scene-subject style clause verbatim (§6.6).

**Est. 3 × ~12 gens (1 + re-rolls, per the round's own 68/28 rate) ≈ 35 gens.**

### Backdrops — 384×176, `create_image_pixen`, `no_background: false`, `low top-down`

`bg_stonefall_mining/lift/gallery` all fail Stonefall's own tell ("natural
rock only above the working height") — dressed ashlar floor-to-ceiling, no
natural rock, so a natural ore face reads as a boulder against a finished
corridor. `bg_hollow_foraging` reads as a lit cave tunnel, and its centre
column falls below the ≥55 floor-luminance floor.

**Stonefall construction clause:** keep timber frames, rail, lantern, cart,
cage, drum — replace dressed-block infill **above the timber line and around
the seam** with "rough broken natural rock face, irregular craggy stone with
natural fracture planes, no two blocks alike, no brickwork, no mortar
coursing" (the phrase already proven on mining props; apply to the wall).

**Hollow construction clause:** narrow pale wash from directly above across
the centre band so rows 150–175 clear luminance 55; push the tunnel-mouth
light out of the keep-clear columns (0–118 / 312–384) so the centre reads as
open peat floor, not a lit shaft.

**Palette anchor:** `style_image_url` = `location/stonefall_mine.png` /
`location/forgotten_hollow.png`, `style_copy: ["color_palette"]`.

**Integration trick — subject column, exactly:** `AmbientStageLayout` places
the subject **west of the figure** at `feetCentre − propGap(8) −
displayExtent`. Per §1.3 this is plate **columns ≈122–230** at every screen
width (127.5–223.5 @393dp, 132–228 @440dp). **Author each backdrop with its
own natural-rock outcrop or ground recess centred in columns 122–230, rows
100–176** — a broken face the seam sits flush into, or (Hollow) a
root-broken hollow in the peat — so the subject's base disappears into a
matching recess instead of a flat wall. This is the device the accepted
`bg_woods_woodcutting`/`prop_oak_cut` pair already uses by accident (the
stump sits in the clearing's own earthen gap); author it on purpose here.

**Est. 4 × ~50 gens (backdrops run hotter historically) ≈ 200 gens.**

**Total: ~235 gens** — inside the ~250 target, a fraction of the open balance.

## What this does not touch

No new mechanic, no redesign of the composition spec, no change to the 7
KEEP subjects or the 10 unnamed backdrops, no craft-station touch (separate
follow-on, §6.5). `duskcap_grove` and the ruin nodes are KEEP-with-caveat
(soft island base; worked-stone coherence) but don't meet the bar to spend a
generation.
