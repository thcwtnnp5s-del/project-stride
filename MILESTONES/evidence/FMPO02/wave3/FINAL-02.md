# FINAL-02 — adversarial art council, FMPO02 wave 3

Reviewed: COUNCIL_CONTEXT.md, wave1 BRIEF_CONTEXT.md, FABLE5_MEGA_PRODUCTION_OVERHAUL_02.md,
review/device (incl. combat/), review/equip, review/items, review/worldlife, review/atlas,
habitat_plates_x2.png, items_old_new_x3.png, reward/final_incontext_x4.png.

1. **BLOCKER** — `review/device/combat/combat_guardian_idle.png` and
   `combat_guardian_heavy.png`: a yellow-and-black diagonal hazard/caution-tape band runs
   across the full width of the bottom of the screen, clipping the HP numerals underneath it.
   This reads as a debug/placeholder overlay, not game art — nothing in any brief calls for
   hazard stripes, and no other combat screen (`combat_wolf_slash.png`, `gear_*_idle.png`)
   has it. Fix: find what draws this band for the Guardian boss encounter specifically and
   remove it before this evidence is presented as acceptance-ready.

2. **BLOCKER** — Bronze reads gold, not bronze, project-wide. `review/equip/plate_bronze_idle_x3.png`,
   `coat_bronze_idle_x3.png`, and every "bronze" row in `review/equip/brace_all_x2.png` (rows
   3 and 9) render the bronze sword as a bright glowing orange-yellow blade; compare
   `plate_steel_idle_x3.png` where the steel blade is correctly grey. Same drift in
   `review/items/bronze_longsword_sheet.png` (4 of 5 candidates are saturated gold) and in
   the shipped icon set `review/items_old_new_x3.png` row 4, columns 3, 6 and 7 (chestplate
   and two longswords, all gold). The only correct bronze reference in the whole set is the
   Bronze Ingot icon seen in `v3_craft_sourcing.png`/`v3_craft_chain.png` (muted copper-brown).
   This is the explicit rule in COUNCIL_CONTEXT ("bronze not gold") and it is violated on the
   weapon the player actually equips. Fix: remap the bronze weapon/armor ramp to the Ingot's
   copper-brown values and re-render the affected equip and item sheets.

3. **SHOULD-FIX** — World life reads as a different hand pasted onto the atlas. In
   `review/worldlife/ATLAS_PLACEMENT_FINAL_x1.png`, compare the fairy castle
   (`castle_probe_x3.png`) and ice tower (`tower_beacon_x3.png`) against the surrounding
   terrain: both use hard black cel-shaded outlines and the tower is drawn in a vertical
   front-elevation perspective, while every habitat/terrain plate around them (see
   `habitat_plates_x2.png`, `atlas/W1_after_full.png`) is outline-free, painterly, and
   top-down. The dragons themselves (`red_probe_x3.png`) actually match the painterly
   treatment fine at native res — it's the two architectural props that clash. Fix: repaint
   castle and tower with the same soft/no-outline top-down treatment as the terrain, or
   accept the perspective break and reduce their outline weight to match.

4. **SHOULD-FIX** — `review/worldlife/_d_house_choice.png`: both storm-house candidates sit
   on a visibly hard-edged diamond/rhombus tile boundary dropped on top of the organic tree
   canopy — the sprite's bounding box reads as a sticker seam against the surrounding
   foliage. Fix: feather/matte the prop's edge into the canopy texture before compositing,
   the way the dragons and volcano already blend.

5. **SHOULD-FIX** — `habitat_plates_x2.png`: plate 2 (rocky ruins, cobblestone wall) is
   drawn with crisp black cel outlines around every stone; plates 1, 3, 4 and 5 (root canopy,
   cave, snow forest, root burrow) use soft painterly shading with no hard outline. Five
   plates meant to read as one habitat family currently split into two rendering styles.
   Fix: re-run plate 2 through the same no-outline pass as the other four.

6. **SHOULD-FIX** — `review/equip/tool_heads_all_x8.png`: the "same" bronze pick/axe head
   is a different color per body — bodies 1, 4 and the axe (5) are a saturated orange-red,
   body 2 a desaturated salmon, body 3 (coat) a pale pink-grey. This is the same underlying
   bronze-drift as finding 2 but visible as batch-to-batch inconsistency on one asset rather
   than a single wrong hue. Fix: same ramp remap, applied uniformly across all four bodies
   in one pass rather than per-body regeneration.

7. **NOTE** — `review/device/skills.png` and `v3_skills.png`: roughly the bottom 55% of the
   screen is flat black dead space below the five skill rows — no band, picture, or "next
   unlock" surfaces at the list level (the brief's "spines + next unlock" is only delivered
   one level down, in `v3_skill_mining_detail.png`). `v3_world_hollow_inspector.png` has the
   same pattern below its Travel/Set-as-Journey buttons. Worth a pass to either fill or
   collapse this space — not a doctrine violation, but it reads unfinished next to every
   other tab.

8. **NOTE** — Integer scale/density: nothing in the sampled device set showed visible
   softening or non-integer blur on hero pictures (`adventure.png`, `inventory.png`,
   `gfcp_mining_result.png`) or on the combat stage — no blocker found here, but this was a
   visual squint-test only, not a pixel-grid measurement, so it isn't a clearance.

**Verdict:** NOT READY — the caution-tape artifact on the boss encounter and the systemic
bronze-reads-gold violation on the player's own weapon are both blockers; fix those two before
the next device pass, then re-check the world-life/habitat outline drift.
