# FMPO02 Wave 3 — adversarial council context

You did not build this. Judge what is on screen, not what the reports claim.

Branch fable5-mega-production-overhaul-02 @ 9e555d3 (from 4d9a81f). Read
MILESTONES/evidence/FMPO02/wave1/BRIEF_CONTEXT.md first (the owner's device verdict
on 4d9a81f, the ten failures) and MILESTONES/FABLE5_MEGA_PRODUCTION_OVERHAUL_02.md.

## Evidence to LOOK at (Read the PNGs) — all rendered from HEAD at 393x852
GAME_BIBLE/ART/exploration/FMPO02/review/device/  (41 screens: adventure, character,
  inventory, skills, v3_craft_overview/ready/sourcing/chain/prover/locked,
  v2_world, v2_world_arrived, v3_world_hollow_inspector, gfcp_mining_result,
  gfcp_woodcut_result, gfcp_levelup_with_result, v2_gather_result, v2_travel_card...)
GAME_BIBLE/ART/exploration/FMPO02/review/device/combat/  (wolf slash, turn 2, guardian idle/heavy/struck, gear_* stages)
GAME_BIBLE/ART/exploration/FMPO02/review/device/stage/   (gather stages: haven meadow, copper, tin, oak)
GAME_BIBLE/ART/exploration/FMPO02/review/device/board/   (goal board + reward layer)
assets/art/v1/world/atlas_base.png (the whole atlas, 1024²) and
GAME_BIBLE/ART/exploration/FMPO02/review/worldlife/ATLAS_PLACEMENT_FINAL_x1.png (with overlays composited)
GAME_BIBLE/ART/exploration/FMPO02/review/atlas/*_before_*.png vs *_after_*.png (per region)
GAME_BIBLE/ART/exploration/FMPO02/review/equip/*.png (equipment strips: combat, tools, brace)
GAME_BIBLE/ART/exploration/FMPO02/review/items_old_new_x3.png, habitat_plates_x2.png,
GAME_BIBLE/ART/exploration/FMPO02/review/worldlife/*.png (dragons, landmarks, creatures)
GAME_BIBLE/ART/exploration/VAWO01/review/device/pair_*.png (the BEFORE screens at 4d9a81f, right-hand halves)

## What the round claims (verify, do not trust)
UI: frame only on the hero picture (heroPlate) and modals; every other panel is a material
surface (10 tiles); bands under headers; button plates; nav welt on leather; header shelf.
Craft: station strip, hero folio, 2-col tiles, locked ledger, bottom sheet.
Inventory: equipment case (figure x2 + slot plates), pack at 5/3 columns.
Character: folio + dressing chips + ruled ledger + spines. Skills: spines + next unlock.
Adventure: full-bleed stage, journal entries with node sketches, cork goal plates.
Equipment: 3 armoured bodies x {unarmed, steel, bronze} combat sets (5 tracks incl. brace),
bronze tool loops on all 4 bodies, forage/idle/walk per body — equipment_projection_test.
Combat: 384x256 stage, framed gauges, 2x2 command grid on leather (219 dp), narration strip.
Encounter: band sized to the creature, habitat plate per region (salamander: cave).
Enemies: hit tracks for boar/bear/salamander/crawler, crawler defeat, 4 elite states.
Items: 9 re-authored + 3 salvage crates. Gather: 4 backdrops + 3 subject plates.
Atlas: 9 regions + 2 bridges repainted (west, north, SW slab, south coast); core + 15 goldens byte-held.
World life: 40 overlays, 6 props: red fire dragon + breath, blue storm dragon + breath, fairy
castle + motes, storm house + lightning, ice tower + beacon, deer/bear/yeti/wolves/wagon/crows...
Rewards: rare-drop mark, signature/masterwork seals, marks placed. Audio: no files (no key).
PixelLab: 9,762 → 8,297 (≈1,465 spent) against a 2,000–3,000 target.

## Rules that bind your verdict
Reserved teal only for steps; bronze not gold; no coins/timers/locks; integer scale; text never raster;
one framed element per screen; no new persisted state; Health untouched; the iPhone is the final authority.

## Output
≤70 lines to MILESTONES/evidence/FMPO02/wave3/<YOUR-ID>.md: numbered findings, each with
SEVERITY (blocker / should-fix / note), the exact file or screen, and the concrete fix. Then a
one-line verdict. Do not edit any file except your report.
