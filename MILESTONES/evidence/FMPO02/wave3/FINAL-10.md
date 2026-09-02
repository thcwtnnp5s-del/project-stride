# FINAL-10 — the five remaining "still looks Claude-generated" tells

Judged from the rendered device PNGs at HEAD. Pixel values sampled from those renders.

## 1. Every primary action is a bronze frame around a hole — SEVERITY: blocker

`device/v3_world_hollow_inspector.png` (Travel), `device/board/board_open.png` (Deliver), `device/v2_gather_result.png` (Gather ×1), `device/gfcp_levelup_with_result.png` (Continue). Row 539 of the inspector is one flat run of `#14120f` from x=39 to x=354 — **the same value as `StrideColors.surfaceGround`, the page background 165 px below it.** The screen's most important control is a window cut through the card to the darkest colour in the app. The *secondary* under it (Set as Journey) sits on `#201c17`, so the secondary is lighter than the primary: hierarchy inverted. `v3_craft_ready.png` paints Craft moss `#3e4f32` (variant `ready`), so one widget wears two unrelated looks and the common one is the void.

Same defect, worst instance: the combat grid, `device/combat/combat_wolf_turn2.png`. Four controls, four treatments — Attack and Brace carry raster emblems sitting *behind and colliding with* their own labels, Eat is flat `#2c2620` grey, Retreat is a full-width bar. Four rectangles of one size reading as four accidents.

A human AD gives the commit action a lit face of its own and ranks the rest beneath it; the emblem goes beside the word, never under it.
FIX — Dart, this round: `data_display.dart` ~L475, the `commit` variant's third token is `StrideColors.surfaceGround`; give it a real face token. Move the combat emblem to `leading`. Demote Retreat to a text control.

## 2. One scaffolding repeated verbatim across every location — SEVERITY: blocker

The Expedition Kit band above the node list is **100.0% pixel-identical** between `device/adventure.png` (grassland settlement), `device/v2_adventure_woods.png` (deep forest) and `device/gfcp_mining_result.png` (Stonefall Mine) over rect (16,336)–(377,392) — verified by diff. A green-grass-and-split-rail-fence shelf is nailed above the ore seams inside a mine. That strip is the clearest single proof the chassis was applied rather than designed. Beneath it the same count-of-identical-cards recurs: 3 station tiles (craft), 4 equipment cards each with its own identical `Equip` (`device/v3_inventory_purpose.png`), 5 notice rows, 5 skill rows — and Skills ends at y≈398 with **~400 px, nearly half the screen, of bare leather below it**.

A human AD lets the location own its band (mine timber, forest canopy, shore) and breaks the uniform row rhythm so the one actionable row carries weight and the rest recede to ruled lines.
FIX — band-per-biome is Dart routing over 3–4 new plates (small art, next round); row differentiation and the Skills dead half are Dart, this round.

## 3. Store-app vocabulary sitting on the leather — SEVERITY: blocker

`device/v3_craft_locked.png` is a stock mobile bottom sheet: rounded top corners, centred grabber pill, scrim over the dimmed list. `v3_craft_ready.png` carries `All / Materials / Food / Gear / Tools` as Material filter chips and `×1 ×5 ×10` as pills; `v2_gather_result.png` adds a `− 1 +` stepper. `COMMON` grey and `EPIC` purple are loot-rarity badges from another genre, and that purple appears nowhere else in the palette. `board_open.png` runs `ORDER`/`CONTRACT` status pills with leading dots.

**Rule violation inside this:** row 236 of `board_open.png` is the reserved step teal `#58d6c0` on "1 READY · STRUGGLING", chip fill its dim `#2c5e57`. Source `lib/ui/screens/adventure/board_card.dart:447` — `if (c.canComplete) return ('READY', StrideColors.accentSteps);` — plus L717/726 using `accentSteps` as the `localNeed` contract accent. Teal is steps only.
FIX — Dart, this round: repaint every non-step `accentSteps` use to `positiveReady`; replace chips with the app's own marks (a stamped seal, a ruled label); replace the grabber sheet with the folio this round already authored.

## 4. Item variety is recolour-and-restamp — SEVERITY: should-fix

`review/items_old_new_x3.png`. Bottom row: five bronze blades on one silhouette, separated only by crossguard trim and length — at 48 px they are one sword five times. Row 3: three salvage crates identical but for the glyph stamped on the lid, and one cell is an **empty grey rectangle shipped in the deliverable sheet**. Row 1: three brown-chunk stews in three vessels. The owner's failure 5, restated rather than closed. The node art repeats the habit: Duskcap Grove (`device/v2_adventure_woods.png`, `device/v2_travel_card.png`) is one mushroom sprite arranged in a mechanically even ellipse no forager ever walked into. `review/habitat_plates_x2.png` — five plates, one horizon height, one lighting angle, one scatter density; plates 2 and 3 both grey rock, 1 and 5 both roots-in-soil.

A human AD re-cuts the sword family on differing blade profiles (leaf, tapered, hand-and-a-half), gives each crate a different opening, breaks the ring, and varies horizon and value key per habitat.
FIX — art. Not this round.

## 5. The atlas is a stamp field, and world life is distributed rather than placed — SEVERITY: should-fix

`review/atlas/S1_before_x2.png` vs `S1_after_x2.png`: the repaint replaced a sparse field of one round-canopy stamp with a **denser carpet of the same stamp**, and introduced a straight boundary at x≈208 between the new forest block and the grass — the exact seam class the repair existed to remove. On `review/worldlife/ATLAS_PLACEMENT_FINAL_x1.png` the 40 overlays read as an even distribution: red dragon, blue dragon, yeti, deer, bear, wolves, lighthouse, stone circle, fairy castle, storm house — each alone in its own clear patch, none clustering, none overlapping terrain, none interacting. All sit at roughly one on-screen size, so a dragon is the size of a lighthouse and larger than the settlement it would burn. Unmotivated rock specks float in open ocean near (940,195).

A human AD clusters life around cause (wolves downwind of the deer, crows over the volcano, wagons on the road), gives the dragons 2–3× a landmark's scale, and breaks the canopy with 3–4 stamp variants under a value gradient.
FIX — art. Not this round.

---

VERDICT: **needs work** — the two blockers that keep this reading as generated (the void primary button and the byte-identical location band) are both Dart-side and closable this round; 4 and 5 are art debt to schedule, not to ship as done.
