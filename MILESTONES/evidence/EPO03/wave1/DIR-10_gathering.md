# DIR-10 — Gathering Presentation Director, EPO03 Wave 1

```
STATUS: DIRECTION, FOR REVIEW · 0 generations spent
Scope: keep the region×skill backdrop × 48-plate subject × figure architecture
       (DECISIONS/0031, L-18a). Fix weak scenes only.
Looked at: EPO03/review/gather/backdrops_x1.png (14 backdrops ×1),
       subjects_x4.png (14 subjects), FMPO02/review/device/stage/{haven_meadow,
       mine_copper,mine_tin,woods_oak}_f4.png, mine_hardened_locked_selected.png,
       device/gfcp_*_result.png, v2_gather_result.png.
```

## TOP FAILURES (phone-visible, ranked)

1. **Ore is a boulder on a floor, not a seam in a face.** `mine_copper_f4` /
   `mine_tin_f4`: an egg-shaped rock stands on plank/rail floor in front of a
   wall; `deep_tin_lode` is a *brick tile with an X crack*;
   `hardened_copper_face` stands on a flat blue slab. Geology fails at the
   subject, not the backdrop.
2. **Haven meadow is a stage.** `haven_meadow_f4`: a pale trampled oval in the
   lawn, and the subject's own green turf oval on top of it — a double plinth
   in a meadow that could be anywhere.
3. **Frostmere foraging has a paved circle.** `bg_frostmere_foraging` centres a
   round flagstone pavement in the scree — the most theatrical element in the
   set, exactly under the subject.
4. **Mill garden flips the camera.** `bg_haven_mill_garden` is a high top-down
   tile grid; the side-view Traveler stands *on* the bed rows.
5. **Forgotten Hollow reads as a cartoon glade.** Lime lawn, black claw-tree
   silhouettes — dead trees, no regional damp, no mist.
6. Tree-cut plates on platforms: `heartwood_oak_cut` sits on a plank/rail,
   `oldgrowth_frostpine_cut` on a hard-edged snow slab.

## WHAT TO REPLACE / RETOUCH — verdict table

Backdrops 384×176 ×1; subjects 48² drawn ×2 (96 dp). `cols` = native backdrop
columns; the subject band is cols 122–230, rows 100–176 (ART-06 §integration).

| Asset | Nodes | Verdict | Phone-visible reason |
|---|---|---|---|
| bg_haven_foraging | meadow_patch | **RETOUCH** | trampled pale oval = plinth; generic meadow |
| bg_haven_mill_garden | mill_garden | **REPLACE** | top-down tile grid under a side-view figure |
| bg_woods_woodcutting | oak_stand, heartwood_oak | KEEP | the set's best; stump sits in its own gap |
| bg_woods_foraging | duskcap_grove | KEEP | mossed log, ferns, real litter |
| bg_woods_warded_grove | warded_grove | RETOUCH (tier 2) | rope-and-hoop line reads as a fairground barrier |
| bg_stonefall_mining | copper/tin/deep_tin_seam | RETOUCH (tier 2) | two flat pale panels; no ore-bearing recess |
| bg_stonefall_lift | old_workings, hardened_copper | KEEP | bowl recess + headframe read |
| bg_stonefall_gallery | gallery_tin_lode, collapsed_span | KEEP | three depth planes, warm iron staining |
| bg_frostmere_woodcutting | frostpine, oldgrowth | KEEP | snow, spruce, boulders — regional |
| bg_frostmere_foraging | rimefrost_hollow | **RETOUCH** | round flagstone pavement in scree |
| bg_frostmere_shelter | sheltered_frost_meadow | RETOUCH (tier 2) | bare brown mud yard, no flora |
| bg_hollow_foraging | silkstrand/hollow_thicket | **REPLACE** | lime lawn, black dead claw-trees |
| bg_hollow_field_camp | veiled_silkstrand | KEEP | camp props are the built project |
| bg_hollow_undercroft | undercroft/deep_hollow | KEEP | built vault; roots give life |
| prop_meadow_bed | meadow_patch, mill_garden | **RETOUCH** | closed turf oval under the stems |
| prop_duskcap_bed | duskcap_grove | RETOUCH | moss base is a diamond islet |
| prop_rime_cushion | rimefrost, sheltered | KEEP | stems from broken rock, no dome |
| prop_gloom_silk | 3 silk nodes | KEEP | full-bleed grass, bleeds bottom edge |
| prop_hollow_root | 2 thicket nodes | KEEP | roots from peat smudge |
| prop_oak_cut | oak_stand, warded_grove | KEEP | stump + log, no base |
| prop_heartwood_oak_cut | heartwood_oak | RETOUCH | log on a plank platform |
| prop_frostpine_cut | frostpine_stand | KEEP | soft snow patch |
| prop_oldgrowth_frostpine_cut | oldgrowth_frostpine | RETOUCH | hard-edged snow slab |
| prop_copper_face | copper_seam | **REPLACE** | grey egg boulder on the floor |
| prop_tin_face | tin_seam, gallery_tin_lode | **REPLACE** | brown cone boulder on the floor |
| prop_deep_tin_lode | deep_tin_seam | **REPLACE** | brick-wall tile with an X |
| prop_hardened_copper_face | hardened_copper_seam | **REPLACE** | crystal egg on a blue slab |
| prop_ruin_face | old_workings, collapsed_span | KEEP | rubble heap fits worked stone |

**6 REPLACE · 9 RETOUCH (3 tier-2) · 13 KEEP.**

**Integration split (keeps the architecture).** Three mining nodes share one
backdrop, so mineral colour cannot live in the wall. Rule: the *backdrop*
carries a neutral dark fractured recess in cols 122–230; the *subject* carries
only the working face — fresh spall, vein, chips — with its rock bleeding off
its own left and bottom edges so the plate has no silhouette of its own. Herb
beds: the ground goes into the backdrop turf; the plate is stems and flowers,
open along its base. Tree stands stay as subjects (the swing target).

**One Dart parameter (composition, no architecture).** `propRect` puts every
subject base exactly on the figure's feet row. On a low top-down floor a thing
*behind* the figure should stand higher up the plane; sharing one line is the
"two sprites on a shelf" read. Add `depth` (dp, default 0) to `StageScenery`
and subtract it from the rect's top: −4 for every `behindFigure: true` plate
(ore faces, stumps), 0 for beds. The footprint shadow moves with the rect. Owner
of `ambient_stage.dart` per GOV-05; request via `REQUESTS_<owner>.md`.

## WHAT TO KEEP

Region×skill keying, ×2 subjects, `behindFigure`, the footprint contact shadow,
the ground gradient, `propGap` 8, the 13 KEEP assets.

## PRODUCTION FAMILY

Camera: backdrops `low top-down`; subjects `side`, no isometric tile
(GATHER_report: `view: side` is what killed the plinths). Palette anchor:
`style_image_url` = the accepted backdrop of the same region, hosted by commit
SHA (rule 4), `style_copy: ["color_palette"]`. Regional keys — Haven: hedgerow
green, chalk path, willow; Woods: deep green, amber shafts; Stonefall: grey-brown
fractured schist, iron-orange staining, lantern amber; Frostmere: blue-white
drift, slate scree, teal tarn, dark spruce; Hollow: peat black, sage moss,
bone-pale root, hanging lichen, cold mist.

| Asset | Canvas | Tool | Direction | Cost |
|---|---|---|---|---|
| bg_haven_mill_garden | 384×176 | pixen ×4, escalate `create_image_pro` ×1 (ref: bg_haven_foraging, location/havens_rest) | walled kitchen garden at the stage camera: raised beds edge-on, mill wall and wheel left, hedgerow behind, an open herb bed in cols 122–230 the plate grows from; no top-down grid | 4 + 40 |
| bg_hollow_foraging | 384×176 | `create_image_pro` ×1 (ref: bg_hollow_field_camp, bg_woods_foraging for trees) | sunken damp vale: living moss-hung alders with bark and canopy, peat floor, low mist band, lichen, a root-broken hollow in cols 122–230; no lawn, no silhouette trees | 40 |
| bg_haven_foraging | crop 192×96 | `inpaint_image` centre band | trampled oval → continuous meadow turf with a worn diagonal footpath running off-frame, clover, a turf bed in the subject band | 20 |
| bg_frostmere_foraging | crop ~200×110 | `inpaint_image` | flagstone circle → frost-heaved scree, a rime-crusted crevice in the subject band, tarn edge kept | 25 |
| prop_copper/tin/deep_tin/hardened | 48² | `create_image_pixen` ×5 each, `no_background`, `side` | wedge of dark fractured rock bleeding off left+bottom edges, exposed vein (copper green-orange / tin grey / cassiterite silver / hardened blue crystal), spall chips; no boulder, no slab, no bricks | 20 |
| prop_meadow_bed, duskcap_bed, heartwood_oak_cut, oldgrowth_frostpine_cut | 48² | `edit_image_pixen` ×1–2 | delete oval / diamond / plank / slab; base opens along the bottom edge | 6 |
| Tier 2 (only if extended): bg_stonefall_mining recess, bg_frostmere_shelter floor, bg_woods_warded_grove rope | crops | `inpaint_image` | dark recess in cols 122–230; snow-crusted turf in the wall's lee; rope → carved ward-stakes at tree bases | 20+25+25 |

## PIXELLAB BUDGET

**Cap 155** (tier 1: 40+40+4+20+25+20+6). Tier 2 adds 70 only on the owner's
word. Unit costs from GOV-04: pixen/pixflux/edit_image_pixen 1; pro 40;
inpaint 20 (≤192×128) / 25 (≤300×298).

## PHONE-SCALE SUCCESS CRITERIA

1. Every mining node: no closed boulder outline; the ore reads as part of the
   wall, with vein colour identifying copper / tin / hardened at 393 dp.
2. `meadow_patch`: no oval of any colour under the stems; the path leaves the
   frame.
3. `rimefrost_hollow`: no straight-edged paving anywhere in the stage.
4. `mill_garden`: horizon and floor plane match `bg_haven_foraging`; the
   Traveler stands beside a bed, not on it.
5. Hollow nodes: trees show bark and canopy; the region is nameable from the
   stage alone without the header.
6. With `depth` −4, `gather_grounding_test` still passes and no
   behind-figure plate's base coincides with the feet row.
7. Verdict from the iPhone contact sheet, not a metric (M-04, M-14).
