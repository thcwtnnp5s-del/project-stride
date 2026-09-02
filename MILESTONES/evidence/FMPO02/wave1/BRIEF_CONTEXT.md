# FMPO02 Wave 1 — shared context for every creative director

Workstream: fable5-mega-production-overhaul-02 (from visual-audio-world-overhaul-01 @ 4d9a81f).
PixelLab live balance at open: 9,762 generations. Production target for this workstream: 2,000–3,000.
Audio: NO provider key (STABILITY_API_KEY unset) — audio files cannot be produced this session.

## The owner's physical-iPhone verdict on 4d9a81f (higher authority than any report)
IMPROVED: typography; outer leather chassis; gathering scenes (grounded); some item icons; combat weapon states; Inventory equipment figure; Frost Lynx; save intact.
NOT GOOD ENOUGH:
1. WORLD — did not receive the massive overhaul requested (atlas master untouched; seams: hard west forest wall, south layer-cake, SW slab, marsh/surf joins, repair rectangles, biome cutoffs, dead zones).
2. UI — too repetitive/systematized: "large leather frame containing ordinary rounded dark cards" everywhere.
3. CRAFT — reads as a long mobile database list of repeated rectangles.
4. EQUIPMENT — not universal: Inventory shows Bronze Chestplate/Longsword/Axe, but Adventure/gathering/combat still show white shirt + green vest base look.
5. ITEMS — perceptual duplicates: reclaim recipes share one crate; broths/foods near-identical; pots/stews too close.
6. ENCOUNTER — creature preview boxes are huge and empty; a small wolf in a giant blank rectangle.
7. GATHERING — good architecture, keep it; individual scenes sometimes staged rather than natural.
8. COMBAT — battlefield attractive; giant lower command frame dominates the fight.
9. WORLD LIFE — fantasy/world-life ambitions (fairy castle, fairies, storm house, ice-mage tower, red fire dragon, blue lightning dragon, more bears/wolves/yetis/deer/caravans/birds/settlement life/ambient magic) not substantially fulfilled.
10. AUDIO — no new audio landed.

## Hard constraints (see MILESTONES/evidence/FMPO02/wave0/GOV-01..06)
- PixelLab authors production art; Claude art-directs, selects, crops/keys/scales/remaps deterministically. No code-drawn production art.
- L-18/L-18a: integer scale only; density is per plane (backdrop 384x176 @x1, subject 48x48 @x2, traveler 64x64 @x2); no pixelated text; raster chrome only as tiled edge, tiled low-variation surface, or discrete ornament; one chassis family app-wide (screens differ by band/surface/picture, not by eleven borders).
- Reserved teal #58D6C0 only for steps. Bronze reads bronze, not gold. No coins/timers/locks/durability/cooldown iconography.
- Atlas: frozen core (256..768)² byte-preserved with 20px rim, 15 landmark goldens byte-enforced. Outer ring is fair game. Repair mandate is single-region, device-evidenced, never batched.
- Save: zero new persisted state; equipment visuals project from Equipment.bySlot at read time.
- Health/step accounting untouchable.
- No FOMO, no dailies, no streaks, no slot-machine reward effects.

## Current device renders (393x852) — LOOK at these before writing
GAME_BIBLE/ART/exploration/VAWO01/review/device/pair_adventure_skills.png
GAME_BIBLE/ART/exploration/VAWO01/review/device/pair_character_inventory.png
GAME_BIBLE/ART/exploration/VAWO01/review/device/pair_combat_wolf_slash.png
GAME_BIBLE/ART/exploration/VAWO01/review/device/pair_v2_world_v3_craft_ready.png
GAME_BIBLE/ART/exploration/VAWO01/review/atlas_life_review.png (the whole atlas with overlays)
GAME_BIBLE/ART/exploration/VAWO01/review/enemies_stage_after_x2.png
GAME_BIBLE/ART/exploration/VAWO01/review/gather/ (gather stage renders)
GAME_BIBLE/ART/exploration/VAWO01/review/items/ (item icon sheets)

## PixelLab tool facts
- create_image_pixen: 1 gen, canvas 16–768 (mult of 4), area ≤512x512, transparent bg option. The workhorse for icons, props, tiles, creatures.
- create_image_pixflux: 1 gen, ≤400/side, img2img with init_image_strength (higher = keep more), forced palette via color image. Needs an https URL for init images >5KB.
- create_image_pro: 20–40 gens, returns 64 candidates ≤42px, 16 ≤85px, 4 ≤170px, 1 above. Accepts labelled reference images by URL.
- edit_image_pixen: 1 gen single-frame edit ≤256/side. edit_image: 20–40 gens, up to 16 frames consistently.
- inpaint_image: 20–40 gens, rectangle mask.
- animate_image: 1 gen for 64x64x8 frames (cost scales with pixels); animates largely IN PLACE (no travel).
- create_character_state: 20–40 gens, a variant of the canonical Traveler (character c82b7da5-cda0-44eb-ae4e-30d73689e115, 64x64, 8 dirs; existing states: Bronze Plate, Fur Jerkin, Heavy Coat, Guard Unarmed 80x64, Guard Bronze Sword 80x64). animate_character v3: ~1 gen/direction ≤96px, custom action text, east-facing used for combat.
- create_ui_asset: 20–40 gens, a nine-patch style panel 192–688px.
- Image hosting for references: only PixelLab's own result URLs and files already pushed to GitHub (raw.githubusercontent.com on this public repo) are reachable. Local crops must be committed+pushed first.
