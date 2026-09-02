# ART-08 — Enemy / Encounter Art Director brief (FMPO02 Wave 1)

Owner defect: "creature preview boxes are huge and empty; a small wolf in a
giant blank rectangle" (`_EnemyStage`, 152dp band, `encounter_card.dart:398-465`).
Looked at `enemies_stage_after_x2.png` (all 9 families at stage scale),
`ENEMY_ROUND_RECORD_01.md` (lynx re-author method), GOV-03 §6 (track table),
GOV-05 §9 (the strip + the text-only bestiary), `enemies.json` (13 ids, 4
regions). Verdict below spends where the roster is actually thin — reaction
tracks and elite identity — not on re-authoring the eight families the prior
round already exonerated at stage scale.

## 1. Per-enemy verdict

| Enemy | Verdict | What I saw |
|---|---|---|
| Forest Wolf | KEEP | Re-authored lynx already dropped wolf/lynx IoU 74.0%→51.1%. `wolf_hit` withheld, stage recoils — accepted precedent, no action. |
| **Old Grey** (elite) | **ADD DISTINGUISHING STATE** | Reuses `wolf` byte-identical (`combat_assets.dart:836`, zero gens). Its own tellLine — "scarred and patient... grey muzzle" — is a lie the art doesn't tell. Cheapest fix: `edit_image` (not pixen) across the existing idle/attack/defeat frame sets at once, so the accepted motion doesn't move — grey the muzzle, add one scar, no canvas/anchor change. |
| Wild Boar | KEEP silhouette / **ADD MISSING TRACK** | No hit track exists ("none authored", GOV-03). Dark maroon body + tusks read apart from ram in color; see collision note below for the outline risk. |
| **Oakback Bear** | **ADD MISSING TRACK** | No hit track. Biggest land animal in the game currently has no flinch — it just no-sells every non-killing blow, which reads as a bug, not toughness. |
| Cave Goblin | KEEP | Full idle/attack/hit/defeat set, already complete. |
| **Gallery Foreman** (elite) | **ADD DISTINGUISHING STATE** | Reuses `goblin` exactly. `edit_image` pass: soot-darken, thicken the drill-arm silhouette on attack/heavy-read frames only — no new canvas. |
| Salamander | **ADD MISSING TRACK** | No hit track. A mouth-attacker with no flinch of its own — `fx_bite`/`fx_impact` land on it but it holds its idle pose regardless. |
| **Scree Crawler** | **ADD MISSING TRACK ×2** | Weakest family on the roster: no hit AND `crawler_defeat` withheld ("legs curl slightly; no collapse read") — it currently has only idle+attack. Priority spend: author hit (recoil is fine as fallback if it fails again) and re-attempt defeat with the lynx method (freeform still + `animate_image`, not the character-template quadruped mode that produced the illegible collapse). |
| Frost Lynx | KEEP | VAWO01 re-author, already accepted; `lynx_hit` withheld by design (stage recoils, same precedent as wolf). |
| **Rimeclaw Matriarch** (elite) | **ADD DISTINGUISHING STATE** | Reuses `lynx` exactly. `edit_image` pass: darker/frost-tinted coat, no new canvas or footprint. |
| Mountain Ram | KEEP (low-priority optional) | `ram_hit` withheld — "template flinch is a head turn only, the known quadruped-flinch failure," already documented as a tool limit, not neglect. Worth one `create_image_pixen` + `animate_image` attempt using the lynx method (freeform still, not template mode) if budget allows; not required. |
| Hollow Guardian | KEEP | Full idle/normal(`swipe`)/heavy(`attack`)/hit set; `guardian_defeat` withheld by design (holds hit pose on victory) — accepted, matches the "defeat is retreat" convention for a boss that doesn't fall. |
| **The Guardian, Awakened** (elite) | **ADD DISTINGUISHING STATE** | Reuses `guardian` exactly, on a 96² canvas with the most legible room for a marking edit. `edit_image` pass: cracked glowing rune seams down the trunk. Same canvas/anchor — no re-measurement. |

### Silhouette collision: Boar ↔ Ram (68.8%)
The prior round found this genre of number is exactly what it was in the
wolf/lynx case first look: shape-normalized comparisons flatten every
quadruped into "body block + 4 legs + head" and over-report collisions the
stage-scale render doesn't have — boar is dark maroon/no horns/low ears, ram
is cream/curled horns/upright stance, and (see §2) they never share a habitat
plate, so a player never sees them adjacent. Verdict: **KEEP**, not a
re-author — but spend one cheap insurance edit rather than trust color alone:
`edit_image_pixen` (1 gen) on each idle frame to thicken the ram's horn curl
and raise a bristle ridge on the boar's back, both outline-level changes a
grayscale/shape comparison would register. Re-run the in-place IoU after; if
still high, that is evidence the two numbers disagree the way wolf/lynx's did
and the in-place, at-scale, in-habitat read is the one that governs.

## 2. Encounter habitat plate

**Canvas**: native **192×76**, drawn at the stage's existing ×2 — 384×152dp,
which lands the plate's height on the band's own 152dp interior exactly (no
new density plane, no `L-18a` exception). This answers the brief's own
question in favor of one ground plate over a ground-band+skyline split: a
second layer would double the generation count and a skyline reads as the
"full battle background per card" the owner explicitly ruled out. Width
covers every target phone (safe up to ~414dp before clipping) using the same
fixed-anchor-column convention the combat backdrop already uses (GOV-03 §6),
so no per-device layout branching.

**5 regional plates**, one per habitat the owner named, mapped to all 13
enemy ids by location *and*, within Stonefall, by family:

| Plate | Enemies | Pixen prompt sketch |
|---|---|---|
| `habitat_forest_floor` | forest_wolf, old_grey, wild_boar, oakback_bear | leaf litter and packed dirt, one fallen log silhouette left third, dappled shadow patch right third, muted green-brown, no sky |
| `habitat_rocky_ledge` | cave_goblin, gallery_foreman, scree_crawler | flat grey shelf rock, rubble scatter, one vertical crack, cool grey-blue shadow |
| `habitat_cave_shadow` | salamander | dark basalt floor, warm ember-orange rim glow along the back edge (no visible fire source), heavy vignette |
| `habitat_snowbank` | frost_lynx, rimeclaw_matriarch, mountain_ram | packed snow with one wind-carved ridge, pale blue-white, faint drift shadow |
| `habitat_hollow_rootbed` | hollow_guardian, guardian_awakened | dark loam with pale exposed roots crossing the ground, faint green-grey bio-light at the edges |

Each plate is a flat ground plane only — no midground props, no parallax — so
it reads as **contact and material**, not a scene: exactly the "efficient
reusable regional presentation" the owner asked for over "full battle
backgrounds per card."

**Grounding**: the plate is authored with its own ground line at row 74/76
(matching the band's existing bottom-alignment), so the creature's *existing*
per-track `footprint`/`groundOffset()` math (`sprite_footprints.dart`,
already measured per family) needs no change — the plate sits as a new
bottom layer under the same `Align(bottomCenter)` + `Transform.translate`
the creature already uses. Elites draw the same plate as their base species
(zero new mapping cost).

**Widget change** (`encounter_card.dart`, `_EnemyStage.build`): add a new
`EncounterHabitats.forEnemy(ContentId)` table (mirrors `backdropFor()`'s
shape) and paint its plate as the `Container`'s background, inside the
existing `ClipRRect`, below the current `Align`/`Transform` child — a `Stack`
with the plate `Image` first, creature second. No height/border/radius
change, so nothing downstream (card layout, golden tests' 152dp assumption)
moves.

## 3. Bestiary upgrade

`bestiary_screen.dart` is text-only today (GOV-05 §9). Add one small
**idle-in-habitat vignette** per entry, reusing art with zero new
generations: crop each enemy's habitat plate to a smaller frame (e.g.
96×48, half the encounter plate, same art) and composite the enemy's
already-decoded `idle` first frame on it at the same ×2 density and the same
bottom-alignment rule as the encounter stage — one shared `HabitatVignette`
widget parameterized by `CombatantArt` + `EncounterHabitats` entry, used by
both `_EnemyStage` and the bestiary row. This keeps "not animated... not a
completion meter" (the screen's own documented constraint) intact — a single
static frame, not a loop.

## 4. Generation estimate (~300, within the workstream's 2,000–3,000 budget)

| Line item | Gens (rough) |
|---|---:|
| 4 elite distinguishing edits (`edit_image`, multi-frame, ~10 gens each incl. re-rolls) | 40 |
| Crawler hit + re-attempt defeat (create/animate, lynx method, incl. rejects) | 25 |
| Boar / bear / salamander hit tracks (create_image_pixen still + animate_image, ~15 each incl. rejects) | 45 |
| Ram hit optional attempt (lynx method) | 15 |
| Boar/ram insurance silhouette edit (pixen, ×2 frames, incl. re-rolls) | 10 |
| 5 habitat plates (pixen, ~2–3 iterations each to avoid a "scene" reading) | 15 |
| Bestiary vignette | 0 (pure crop/composite of existing art) |
| QA re-rolls / buffer (roughly 60% on top, matching this workstream's own rejection rates in GOV-03/ENEMY_ROUND_RECORD_01) | ~150 |
| **Total** | **~300** |

## 5. QA gate

Aligned-mask IoU between every family pair, **measured in-place at stage
scale** (the ENEMY_ROUND_RECORD_01 method — shape-normalized numbers alone
are not a gate, they were shown to over-report). Threshold: **< 60%** for any
pair to pass; re-measure boar/ram after the insurance edit. Every elite gets
a blind side-by-side against its base species at card size — must be
identifiable as "the same species, something's different" within one glance,
not a new creature. Habitat plates get a "strip, not a scene" check: no plate
may include a horizon, sky, or any element above the creature's own headroom
line, or it has become the full battle background the owner ruled out.
