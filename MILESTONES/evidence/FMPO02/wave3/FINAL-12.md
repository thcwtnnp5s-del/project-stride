# FINAL-12 — would the owner say WOW on the iPhone?

Judged from the device renders and BEFORE pairs only. Two minutes per surface, installed over 4d9a81f.

| Surface | Verdict | The one thing on screen that decides it |
|---|---|---|
| Adventure | Somewhat better | Full-bleed stage and painted plates on Meadow Patch / Mill Garden — but the Expedition Kit band is the same grass turf at a mine and in a forest |
| Craft | **Wow** | Three station pictures (anvil, bench, cookfire) over a kitchen-shelf band; it can no longer be mistaken for a list |
| Inventory | Somewhat better | Equipment case, figure at 2x with slot plates — undercut by a material tile with a grey sliver where "Meadow Herb" used to be |
| Character | Somewhat better | The folio with dressing chips; the three panels under it are still plain dark rounded cards |
| Skills | **Same** | Five rows, then 470 px of empty black; the roadmap moved into a sheet of fourteen identical rectangles |
| World, atlas pan | Wow in the middle, Same at the rim | Haven's Rest basin, volcano and east islands are superb; the NW quadrant is now an airbrushed glacier with no outlines |
| World, dragons | **Wow** | Red dragon breathing fire off the volcano headland; blue storm dragon throwing lightning over the sea |
| World, fairy castle | **Wow** | Pastel spires among giant trees over a lily pond — though it sits on a soft-edged mint base plate that reads as a sticker |
| World, storm house | **Wow** | Lightning striking a dark roof in the south-west woods |
| World, ice tower | Wow, on bad ground | The white spire reads instantly; the glacier under it is the regressed art |
| Gather (bronze plate, mining) | Somewhat better, then breaks | Excellent mine interior — and frame 4 of the plate mining loop flashes an opaque white blob |
| Fight (bronze longsword, brace, wolf) | **Wow** | Stage 2.5x bigger, framed gauges, 2x2 command grid; the giant leather box is gone |
| Fight (boss) | **Blocked** | A yellow/black overflow band across the Hollow Guardian screen |
| Encounter list | Cannot judge | No device render exists in the whole set; the habitat plates as assets are Wow |
| Reward | Somewhat better | Wax scroll, hammer plaque and leather patch read as objects — but rare drop is a money sack |

## Findings

1. **BLOCKER** `review/device/combat/combat_guardian_{idle,heavy,struck}.png` — Flutter's RenderFlex overflow
   band (yellow/black + red/white) crosses the HP numbers on all three. *Fix:* the BOSS chip plus the taller stage pushes the gauge column past its box; constrain that row before any device build.
2. **BLOCKER** `assets/art/v1/ambient/traveler_plate_bronzepick_mine_f4.png` — ships an unkeyed opaque white
   swing-arc; jerkin and coat are clean at the same frame. *Fix:* re-key f4 from source, or drop to a 7-frame loop.
3. **BLOCKER (rule)** `review/device/board/board_open.png` — reserved step teal `#58D6C0` on the "READY" chip
   (x312,y282) and the "1 READY · STRUGGLING" line (x300,y235); neither is steps. *Fix:* use the warm ready-green already on Cookfire's "1 ready".
4. **BLOCKER (regression)** The north repaint made the atlas worse. `atlas/N1_after_fov.png` and `N2_after_fov.png`
   match shipped `assets/art/v1/world/atlas_base.png`: outlined mountains and crackled ice-floe cells with teal meltwater became soft airbrushed drifts with no outlines. The `_before_` art was on-style. *Fix:* restore N1/N2 before-state; re-attack only the grass join, single-region.
5. **SHOULD-FIX** `review/worldlife/ATLAS_PLACEMENT_FINAL_x1.png` is composited over the *pre-repaint* atlas — its
   NW corner is the outlined version, not the shipped one. The headline world-life evidence does not depict what ships. *Fix:* recomposite over HEAD and re-check placement.
6. **SHOULD-FIX** Owner failure 1 is unanswered where he named it: in the shipped atlas the west forest wall is still
   a straight vertical seam at x≈240 (tone *and* density step, y 250→570), and `S1_after_fov.png` repaints the south slab *inside* an unchanged straight-edged rectangle. *Fix:* the defect is the silhouette, not the fill.
7. **SHOULD-FIX** `lib/ui/screens/adventure/activity_panel.dart:109` hardcodes `StrideBand.adventureTrail`, so
   Haven's Rest, Stonefall Mine and Whispering Woods get a pixel-identical grass strip; `band_mining.png` and `band_foraging.png` are authored and never referenced. *Fix:* pick the band from the location's work kind.
8. **SHOULD-FIX** `review/device/inventory.png` — the Meadow Herb tile shows a 1-px grey rule where the name
   should be, then "×3", while equipment tiles keep their names. *Fix:* the material tile's name row is collapsing to zero height; restore it. An unnamed icon in the pack is worse than before.
9. **SHOULD-FIX** Identity breaks on equip: `assets/art/v1/sprite/traveler_south_jerkin.png` has ginger hair where
   every other body is brown, and `traveler_south_coat.png` loses the red scarf. *Fix:* repalette the hair, put the scarf back.
10. **SHOULD-FIX** Bronze is two metals: item blades sample `#F1B869`/`#DF9C45` (pale gold) in
    `items_old_new_x3.png`, the combat and mining sprites read hot orange. Neither is bronze. *Fix:* one bronze ramp, remapped across icon and sprite.
11. **SHOULD-FIX** Owner failure 5 survives for the crates — the three salvage crates in `items_old_new_x3.png`
    row 3 share one crate body and one scroll, differing only in tint. *Fix:* differentiate by form (open lid, strapped bundle, broken crate), not colour.
12. **SHOULD-FIX** `v3_world_hollow_inspector.png` and `world_inspector_destination.png` both carry an unlabelled
    red/white diagonal stripe clipped into the top-right corner over the tool band; `debugShowCheckedModeBanner` is false and nothing in `lib/ui/screens/world/` draws it. *Fix:* identify it before the device build.
13. **SHOULD-FIX** Skills went backwards: `skills.png` is five rows over 470 px of dead black, and
    `v3_skill_mining_detail.png` is fourteen stacked plain rectangles with no material, band or picture — the shape the owner rejected, rebuilt in a new place. *Fix:* give the sheet the craft folio treatment.
14. **NOTE** `assets/art/v1/reward/mark_rare_drop.png` is a bulging drawstring sack — the money-bag glyph,
    against the no-coins rule. *Fix:* a pinned feather or knotted cord instead.
15. **NOTE (evidence)** `v3_craft_overview.png` and `v3_craft_ready.png` are byte-identical (md5 89bddb03…), so a
    claimed state was never captured; and none of the 41 device screens shows armour projected into Adventure, gather or combat, nor any encounter list. The tracks *are* packaged. *Fix:* render both; failures 4 and 6 are otherwise unverifiable.
16. **NOTE** The world-inspector band does not tile — one sprite with a flat featureless middle (source x≈145–240).
    *Fix:* tile the 32-px cut, or centre the detail and let plain wood run.

## Verdict

Craft, the wolf fight, the dragons and the landmarks are a genuine production pass and would earn the Wow; Skills,
the atlas rim and the encounter list remain only incrementally changed, the north was actively made worse, and a
boss fight that renders an overflow band is not shippable — close 1 to 4 and this workstream is complete.
