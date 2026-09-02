# DIR-12 — Encounter / Bestiary Director (EPO03 Wave 1)

Looked at (0 generations): every idle f0 at ×2 (`EPO03/review/enemies/roster_idle_f0_x2.png`),
the five shipped plates at ×1/×2 (`habitat_plates_shipped_x{1,2}.png`), and each creature
seated on its plate by `_EnemyStage`'s own arithmetic (`stage_composite_x2.png`, the
phone's dp scale). No device render of an encounter card exists; `v3_adventure.png`
shows only the `encounterGround` band. Direction: **field guide / habitat dossier**.

## TOP FAILURES

1. **Stonefall creatures stand at the foot of a wall.** `cave_shadow` (Q-23) is a
   face-on cobble wall; `rocky_ledge` is masonry courses with a 6-row scree strip
   under the goblin — the same defect, milder. The salamander floats.
2. **Frostmere feet are on gravel, not snow.** The drift ends at row ~70; every
   creature stands on the grey band below it, outside the habitat it is meant to be in.
3. **The Hollow has no floor.** Roots fill the plate edge to edge over black; the
   Guardian hangs in front of a root wall, and at 146 dp in a 152 band it has no
   headroom — the boss reads *cramped*, not *large*.
4. **Nothing is in front of any creature.** All five plates are pure backdrops, so no
   card has depth; the creature is a cut-out on a picture.
5. **Props on a stage** survive: the timber log (rocky), the lantern on a post (cave).
6. Species: the ram's horn curl is thin at 76 dp (its bold re-horn `ram2_idle` is
   packaged and wired to nothing); the salamander says "heat" only in its tell line.

## WHAT TO REPLACE

**Rule change (owner-authorised, producer to record):** the ART-08 gate "contact and
material, never a scene; no midground, nothing above the headroom line" is superseded.
A plate is a **habitat window**: floor in the lower ~40% that the creature *stands on*
(ground line rows 68–72 of 76), a midground that names the region, an atmosphere band
at the top (mist, cave dark, snow light) — still **no open sky, no ruler-straight
horizon, no props**. Plates stay regional and reusable, so the owner's cost objection
to "a battle background per card" still holds.

**Plates:** `rocky_ledge` RE-ROLL (scree floor in shallow top-down, wall only as the
top third, no log). `cave_shadow` REPLACE (basalt flagstone floor, wall as a top band,
ember rim from a *floor fissure* behind the creature, no lantern; approach B if pixen
fails twice: `inpaint_image` the lower two thirds of the accepted wall). `snowbank`
RE-ROLL (snow surface to the bottom row, keep the rime treeline). `hollow_rootbed`
REPLACE with a **boss chamber at 192×96** (loam floor, roots rising behind, fungus
bio-light) plus an `edit_image_pixen` darkened/rune-lit variant for the Awakened.
`forest_floor` KEEP. No Haven plate: no roster entry lives there.

**Foreground overlays** (new, one per plate, transparent, drawn *above* the creature):
grass tufts + leaf litter + a root end (woods); rubble + a scree lip (ledge); rock
rubble below and a stalactite fringe above (cave); a drift lip with wind-spray (snow);
root loops + a fungus cluster (hollow, shared by both bosses).

**Dossier layout (`EncounterCard`):** the band becomes a framed plate — plate, creature,
foreground, then a **plate frame** nine-patch; a **name-plate strip** under it carrying
`o.name`, "Roams here / Guards this place" and a habitat caption ("Whispering Woods ·
forest floor"); the tier as a **stamp** (UNSEEN/SEEN/STUDIED/KNOWN); HP/ATK/DEF as one
ruled threat line; drops unchanged; page material `PanelSurface.journalLeaf` (already
registered for "the field guide (Encounters)"). **Boss presence:** `isBoss` → 192-dp
band, the darker chamber plate, the heavier boss frame and boss name-plate.

**Bestiary (`bestiary_screen.dart`) as a field guide:** each `_BestiaryRow` gains a
96×76-dp **vignette** — the plate cropped at ×1, the idle f0 at ×1, the overlay at ×1:
one shared `HabitatVignette` widget, zero generations. Unseen entries draw the creature
as an ink silhouette (`ColorFiltered`) — "not yet sighted". Region cards move from
`slate` to `journalLeaf` with the tier stamp; still static, still no meter (P-5).

**Dart (COMBAT owns both files):** `HabitatPlate` gets per-plate `nativeHeight` and
`foreground` slug; `_EnemyStage.heightFor(plated)` returns `plate.displayHeight`, not
the 152 constant; the `Stack` becomes plate → `_EnemyIdle` → foreground `PixelScene`
(missing PNG paints nothing, E-5); `EncounterHabitat.byEnemy` adds
`enemy.guardian_awakened → hollowChamberAwakened`, `byPlace` hollow → `hollowChamber`;
`combat_assets.dart` `ram` points at `ram2_idle`. Tests: `encounter_card_test.dart`
asserts boss band 192 / common 152 and foreground-above-creature order. `startEncounter`
call site untouched.

## WHAT TO KEEP

Every sprite's silhouette (roster below): thirteen distinct species at 76 dp; the
lynx/wolf split holds, the four elites read as "same species, changed". ×2 for every
creature (roster size order; card and fight the same size of thing). `forest_floor`.
The 6-second bounded idle. Row/expanded-card structure.

## Roster

| Enemy | Sprite | Plate today → verdict |
|---|---|---|
| Forest Wolf | KEEP | forest_floor: stands on dirt, tree behind, no depth → KEEP + overlay |
| Old Grey (veteran) | KEEP (pale coat, scar) | as wolf |
| Wild Boar | KEEP | as wolf |
| Oakback Bear | KEEP | as wolf; bear fills the band well |
| Cave Goblin | KEEP | rocky_ledge: at the foot of a wall, log prop → RE-ROLL |
| Foreman (veteran) | KEEP (helmet) | as goblin |
| Scree Crawler | KEEP | as goblin |
| Salamander | EDIT: ember stripe along the back (f0 pixen edit, re-animate idle/attack/hit) | cave_shadow: floats on a wall (Q-23) → REPLACE |
| Frost Lynx | KEEP | snowbank: feet on gravel below the drift → RE-ROLL |
| Rimeclaw Matriarch (veteran) | KEEP | as lynx |
| Mountain Ram | SWAP to `ram2_idle` (0 gens) | as lynx |
| Hollow Guardian (boss) | KEEP | hollow_rootbed: no floor, no headroom → REPLACE, 192×96 chamber |
| Guardian, Awakened (boss) | KEEP (rune glow) | chamber, darkened variant |

## PRODUCTION FAMILY

| Asset | Canvas | Count | Tool | Unit | Style source |
|---|---|---|---|---|---|
| rocky_ledge, cave_shadow, snowbank plates | 192×76 | 3 (≈19 rolls) | `create_image_pixen` | 1 | shipped forest_floor + snowbank palette; `FMPO02/ledger/ENEMIES.md` rejects |
| hollow_chamber (boss) | 192×96 | 1 (≈6 rolls) | pixen | 1 | hollow_rootbed roots + fungi |
| hollow_chamber_awakened | 192×96 | 1 (≈3 rolls) | `edit_image_pixen` | 1 | guardian_awakened rune amber |
| foreground overlays | 192×28 bottom (×5), 192×20 cave top (×1) | 6 (≈18 rolls) | pixen, `no_background` | 1 | each plate |
| name-plate strip common / boss | 384×32 | 2 (≈6 rolls) | pixen | 1 | journalLeaf + slate inks |
| plate frame common / boss (nine-patch) | 48² | 2 (≈6 rolls) | pixen | 1 | existing panel edges |
| tier stamps sheet | 96×24 | 1 (≈3 rolls) | pixen | 1 | `RewardArt.markKnowledge` |
| salamander ember pass | 56², idle 8f / attack 8f / hit 6f | 1 edit + 3 tracks (≈10) | pixen edit + `animate_image` | 1 each | lynx method |
| Q-23 reserve: cave floor inpaint | 192×76 | ≤2 | `inpaint_image` | 20 | accepted wall b16a55cb |

## PIXELLAB BUDGET

Planned **71** + 15 re-roll buffer = **86**; Q-23 inpaint reserve 40. **Cap 130.**
Sprite re-rolls 0; 1 sprite edit; 1 zero-cost swap; 5 plate generations; 6 overlays.

## PHONE-SCALE SUCCESS CRITERIA

1. Every creature's feet touch a visible floor plane; none stands at the base of a
   wall or on a band outside its habitat (Stonefall ×3, Frostmere ×3, Hollow ×2 today).
2. At least one foreground element overlaps every creature's feet — it is *in* the scene.
3. No log, lantern-post, cut block or plank on any plate.
4. The Guardian's band is visibly taller and darker than a wolf's, with a heavier
   frame and headroom above the head; the Awakened's chamber is distinguishably lit.
5. Ram horns and salamander heat read at arm's length; wolf/lynx/boar/ram remain four
   species at a glance.
6. Bestiary rows show a vignette each; unseen creatures are silhouettes; no percentages.
7. The salamander card on device closes Q-23, or the answer is recorded as still open.
