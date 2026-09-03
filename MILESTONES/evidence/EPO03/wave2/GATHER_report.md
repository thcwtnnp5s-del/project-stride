# EPO03 Wave 2 — PROD-GATHER report

```
TEAM: gather · CAP 155 · SPENT 146
BRIEF: MILESTONES/evidence/EPO03/wave1/DIR-10_gathering.md
LEDGER: GAME_BIBLE/ART/exploration/EPO03/ledger/GATHER.md
BRANCH: fable5-executive-production-overhaul-03
```

The owner's rule for this family was a restraint: *do not rebuild the working
system; keep the good architecture; fix weak scenes.* Nothing about the
gathering architecture moved. Region × skill backdrop, the 48 × 48 subject
drawn ×2, `behindFigure`, `propGap`, `propRect`, the footprint contact shadow,
the ground gradient, the fifteen backdrops, the fourteen subjects — all
untouched. `AmbientAssets`, `ambient_stage.dart`, `location_stage.dart` and
`ambient_scene.dart` were not edited. **No new node, no new subject, no new
region × skill pair, no Dart parameter.** Thirteen paintings were replaced.

## 1. The defect, named once

DIR-10 listed six failures. Underneath all six is one defect wearing several
costumes: **the plinth.** Every weak plate stood on something that does not
exist in the world — a turf oval, a moss diamond, a plank rail, a snow slab, a
blue slab, a plank floor, a flagstone circle — and a thing on a base beside a
figure standing on the ground reads as two sprites on a shelf rather than as
one place. Everything below is that one fix, twelve times.

Before/after for all seven replaced plates in one image:
`GAME_BIBLE/ART/exploration/EPO03/review/gather/_r_final_plates_x4.png` — top
row every one a closed shape on a base, bottom row every one opening into the
ground it lies in.

## 2. What shipped — thirteen assets across twelve scenes

Sources `GAME_BIBLE/ART/exploration/EPO03/out/gather/`, packaged to
`assets/art/v1/work/` through the new `epo03GatherPath` resolver.

### Backdrops (4)

| Asset | Was | Is | Sheet |
|---|---|---|---|
| `bg_haven_foraging` | a pale trampled oval in the lawn — a plinth painted into the backdrop | continuous meadow turf with a worn diagonal footpath that enters and leaves the frame, clover, flower clumps | `_r_bg_cmp_x1.png` row 1 |
| `bg_frostmere_foraging` | a round flagstone pavement centred in the scree, the most theatrical element in the whole set and exactly under the subject | frost-heaved scree: broken slate slabs shouldered out of the ice, the tarn lip kept | `_r_bg_cmp_x1.png` row 2 |
| `bg_hollow_foraging` | lime lawn, black claw-tree silhouettes — a cartoon glade | a sunken damp vale of living moss-hung alders with bark and canopy, hanging lichen, a mist band, peat floor, a root-broken log at the subject band | `_r_bg_cmp_x1.png` row 3 |
| `bg_haven_mill_garden` | a high top-down tile grid — the side-view Traveler stood *on* the bed rows | a side-on walled kitchen garden at the stage camera: mill flank and waterwheel left, fieldstone wall and willows behind, beds edge-on, a bare freshly turned bed dead centre for the figure to stand in | `_r_mill_cmp_x1.png` |

The mill garden is the one that cost real money and it is worth recording why.
Two `create_image_pixen` rolls returned a top-down grid and a greenhouse
corridor. Rather than re-seed a third time, the **intent** changed: the camera
was named in the prompt as a negative as well as a positive ("side-on, eye
level, NOT top-down, no isometric grid, no checkerboard of square plots"), and
`create_image_pro` held it on the first call with `bg_haven_foraging` as the
labelled style anchor. Same willows, same horizon height, same palette.

### Ore faces (4)

The integration rule from DIR-10: the plate carries only the working face, its
rock bleeding off its own edges so the plate has no silhouette of its own.

| Asset | Was | Is |
|---|---|---|
| `prop_copper_face` | a grey egg boulder standing on the plank floor | a wedge of warm grey-brown schist opening off the frame edges, malachite-and-orange vein, spall chips at the foot |
| `prop_tin_face` | a brown cone boulder on sand | fractured schist with iron-orange staining and a silver-grey cassiterite vein |
| `prop_deep_tin_lode` | *a brick-wall tile with an X crack on it* | a steep cool blue-grey cobble slope with a silver vein running down it, chips along the base |
| `prop_hardened_copper_face` | a crystal egg on a flat blue slab | grey rock, an orange ore band under blue crystal growth, dry spall at the foot |

Vein colour is what names the mineral at 393 dp, and the four are separable:
malachite green, silver in orange staining, cool blue-grey, blue crystal.

### Bases deleted (5)

`prop_meadow_bed` (turf oval), `prop_duskcap_bed` (moss diamond),
`prop_heartwood_oak_cut` (plank platform and rail), `prop_oldgrowth_frostpine_cut`
(hard-edged snow slab), `prop_gloom_silk` (solid dark base bar — see §3). One
`edit_image_pixen` call each, one generation each, composition otherwise
untouched. Sheets `_r_beds_cmp_x4.png`, `_r_cuts_cmp_x4.png`, `_r_boxfix_x4.png`.

## 3. The composed render is what changed three verdicts

The plate is not the deliverable; the scene is. Every plate was read at ×4 on
a contact sheet **and** rendered into the real `LocationStage` at 393 dp with
the Traveler in plate armour holding the right tool, and three assets that
passed the sheet failed the scene:

- **copper** measured and sheeted fine and was a *pink lump* against the mine
  wall — the plate's mauve had nothing to do with the rock behind it. Recoloured
  to the wall's own browns for 1 generation.
- **hardened copper** had a bright orange run at its foot that reads as a
  spill of paint or blood at stage scale. Replaced with dry chips, 1 generation.
- **`prop_gloom_silk`** — a DIR-10 **KEEP**, and the plate sheet is exactly why
  it was kept: on a sheet it is full-bleed grass. Composed against the replaced
  Hollow backdrop, its opaque 48 × 6 base band was a *black bar under a black
  rectangle*, the most visible plinth left anywhere in the family. Replaced for
  1 generation with peat clumps and moss tufts with gaps between them; the
  stems now rise out of the vale floor. `_r_stage_hollow_after_x2.png` is the
  before over the after and it is the clearest single image in this report.
  This is a deliberate step outside the verdict table, on the round's own
  stated principle that the composed scene is the verdict.

Compare `review/gather/_r_stage_mine_x2.png` (before the corrections) with
`_r_stage_mine_after_x2.png` (after). Nothing but the composed render would
have caught any of them.

Renders, all at iPhone 15 Pro logical width:
`GAME_BIBLE/ART/exploration/EPO03/review/device/gather/`. Six rows were added
to `test/stage_evidence_test.dart`'s scene list so that **every one of the
twelve repainted scenes** is rendered, not just the five the harness happened
to cover. No assertion was changed.

## 4. `depth` on `StageScenery`: not needed, not requested

DIR-10 proposed a `depth` dp offset so a behind-figure plate sits higher up the
plane than the feet row. Judged from the renders, it is not needed and it was
not implemented: once the plinths were gone, no plate reads as sharing a shelf
with the figure. In `woods_oak_f4` the stump sits in its own litter gap, in
`haven_meadow_f4` the stems grow out of the turf the boots are on, and in
`mine_deep_tin_f4` the ore is behind the swing. The shared ground line was
never the defect — the base under the plate was. `ambient_stage.dart` belongs
to PROD-UI-ADVENTURE and stays frozen; no `REQUESTS` block was filed, because
asking for the parameter would have been asking for a change the evidence does
not support.

## 5. What did not close

- **`prop_tin_face` still reads as a fin.** Its rock mass fills the upper left
  and falls away on a long straight diagonal, so at 96 dp it is a blade
  standing on the floor rather than a face in the wall. Two attempts, and the
  intent was changed rather than the seed both times: an `edit_image_pixen`
  asking for a broad low wall-hugging mass returned the same silhouette
  recoloured, and a fresh `create_image_pixen` with an explicit corner-fill
  brief returned a smaller wedge with a hard dark border along its hypotenuse
  (`rejected/gather/tin_B1_ebcad329.png`) — worse. Stopped at two.
- **The Stonefall wall is still a flat pale panel.** This is the root of the
  ore problem and it is **tier 2, unfunded**: `bg_stonefall_mining` needs a
  neutral dark fractured recess inpainted into cols 122–230 so an ore plate has
  a shadowed hollow to sit *in*. Until it has one, any ore plate is a dark
  shape in front of a light wall and will read as applied rather than exposed.
  The remaining three tier-2 items (`bg_frostmere_shelter` mud floor,
  `bg_woods_warded_grove` fairground rope) are likewise untouched.
- **`prop_deep_tin_lode` shows its plate rectangle.** Its cool blue-grey mass
  is full-bleed along the left and top edges, and against the pale Stonefall
  wall that boundary is a straight vertical and a straight horizontal — a
  visible rectangle corner (`review/gather/_r_stage_new2_x2.png` row 3). One
  `edit_image_pixen` asking for a ragged profile made it worse: it added a
  full-bleed band across the top as well, and the warm recolour took away the
  blue-grey that separates the deep lode from surface tin
  (`rejected/gather/deeptin_edit3_056dd4b2.png`). Bleeding off the frame edge
  is only invisible when the plate's colour matches what is behind it, which is
  the same tier-2 wall problem below. Not closed.
- **`prop_rime_cushion` shows a small pale dome** under its stems in
  `frostmere_rimefrost_f4`. DIR-10 marked it KEEP from the plate sheet; the
  composed render disagrees. Not fixed — flagged.
- The retouched Frostmere and Hollow backdrops and the mill garden have been
  judged on the harness render only. **The iPhone is the final authority and
  has not seen any of this.**

## 6. Guards, tests, cost

```
node Scripts/art/package-art.js && --check   2313 files up to date   (under atlas-lock `gather`)
node Scripts/art/check-art-palette.js        ok — 2370 PNGs, no teal collision, chrome under the ceiling
node Scripts/art/check-tile-seam.js          ok — 26 strips wrap cleanly
flutter test test/stage_evidence_test.dart test/gather_grounding_test.dart test/ambient_composition_test.dart
                                             All tests passed
flutter analyze                              No issues found
```

`package-art.js` gains an `EPO03 GATHER` block: `epo03GatherPath(file)` resolves
a repainted plate as a **source** ahead of `fmpo02GatherPath` and the VAWO01
original, following the correction the items team landed in `c3b68c4` — a
trailing override writes the right bytes but makes `--check` report a synced
tree as stale. One id, one emit. A guard loop asserts every file in
`E/out/gather` replaces a plate the gather block already ships, so a misspelled
filename cannot sit in the directory doing nothing (G-3).

**Cost: 146 of 155.** 13 assets shipped from 16 accepted rolls, 9 rejected with
written verdicts in `rejected/gather/VERDICTS.txt`, **0 re-rolls on a seed** —
every second attempt changed the intent, and where the second intent also failed
(the tin silhouette) the family stopped rather than spend a third. By tool:
`create_image_pro` ×2 (80), `inpaint_image` ×2 (45), `create_image_pixen` ×12
(12), `edit_image_pixen` ×9 (9). Nine generations left unspent; the honest use
for them was the tier-2 Stonefall recess, which is 20 and not funded.

No `REQUESTS` filed, no `Q-` raised, no lock crossed. Files touched outside
`E/`: `Scripts/art/package-art.js` (the `EPO03 GATHER` block only),
`test/stage_evidence_test.dart` (six rows added to the scene list),
`assets/art/v1/work/` (the thirteen packaged plates).
