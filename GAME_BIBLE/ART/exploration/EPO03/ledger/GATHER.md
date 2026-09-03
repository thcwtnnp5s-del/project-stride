# EPO03 Wave 2 — GATHER family ledger

Team `gather`, cap **155** (tier 1). Brief: `MILESTONES/evidence/EPO03/wave1/DIR-10_gathering.md`.
Family total = the sum of the tool's own cost lines below; never a balance delta (M-17).
`ACCEPT` = shipped to `out/gather/`; `RE-ROLL` = viable alternate not selected; `REJECT` =
fails the construction or the region read. Every candidate was fetched, sheeted at
display scale (`review/gather/*.png`) and Read before its verdict.

| job/id | asked | tool | canvas | cost | verdict | reason |
|---|---|---|---|---:|---|---|
| copper_A/e7d9135f | copper face, corner-wedge phrasing (rock fills left+bottom edges, vein, chips) | pixen | 48² | 1 | ACCEPT (pending stage render) | rock cropped by the left and bottom edges, no silhouette of its own; orange+malachite vein reads copper; chips at the foot |
| copper_B/577c6c37 | copper face, "outcrop cut off by edges" phrasing | pixen | 48² | 1 | REJECT | closed boulder outline standing on the floor — the defect being replaced |
| copper_C/026381e0 | copper face, short phrasing | pixen | 48² | 1 | REJECT | closed boulder cluster, gem-like vein, standing on a base |
| mill_garden_1/164755ca | walled kitchen garden beside the mill, stage camera | pixen | 384×176 | 1 | REJECT | a kneeling figure (no-figures rule); still a high top-down bed grid; no horizon |
| mill_garden_2/6ec8d8e2 | same, "shallow stage angle" phrasing | pixen | 384×176 | 1 | REJECT | roofed timber structure, beds in a one-point perspective corridor; reads as a greenhouse, not the walled garden; the subject would sit on the cabbages |
| haven_band/ad1670f1 | bg_haven_foraging centre band 192×96: trampled pale oval → continuous turf + worn diagonal footpath off-frame | inpaint_image | 192×96 | 20 | ACCEPT | the plinth oval is gone; a worn path enters from the right and leaves the frame; clover and flower clumps read as one meadow, not a stage (`review/gather/_r_bg_cmp_x1.png` row 1) |
| frost_band/a6213006 | bg_frostmere_foraging band: flagstone circle → frost-heaved scree, rime crevice, tarn edge kept | inpaint_image | ~200×110 | 25 | ACCEPT | no straight-edged paving anywhere; broken slate slabs heaved out of ice, the tarn lip preserved (`_r_bg_cmp_x1.png` row 2) |
| hollow_pro/b4e0d242 | bg_hollow_foraging replacement: sunken damp vale, living moss-hung alders, peat floor, mist, root-broken hollow in cols 122–230 | create_image_pro | 384×176 | 40 | ACCEPT | bark and canopy on every trunk, hanging lichen, mist band, a fallen root-broken log at the subject band; the lime lawn and the black claw-tree silhouettes are gone and the region is nameable from the stage alone (`_r_bg_cmp_x1.png` row 3) |
| tin_A1/facc242f | tin face, corner-wedge phrasing (rock fills left+top edges, cassiterite vein, chips) | pixen | 48² | 1 | ACCEPT | wedge of fractured schist bleeding off the left and top edges, iron-orange staining with a silver-grey vein, spall chips at the foot; no closed outline (`_r_ores_cmp_x4.png` row 1) |
| tin_A2/935cb3ea | same intent, second phrasing | pixen | 48² | 1 | REJECT | a cobble arch with a hole through the middle — a doorway, not a face |
| deeptin_A1/abd312b0 | deep tin lode: steep blue-grey cobble slope, silver vein down the diagonal | pixen | 48² | 1 | ACCEPT | replaces the brick-tile-with-an-X; mass fills the left and bottom edges, the vein runs with the slope, chips along the base; the cool blue-grey separates it from surface tin at 393 dp (`_r_ores_cmp_x4.png` row 2) |
| deeptin_A2/d720496e | same intent, spire phrasing | pixen | 48² | 1 | REJECT | thin spire with a spiky tail — no rock mass, reads as a shard standing alone |
| hardened_A1/1588a2e8 | hardened copper face: grey wedge, orange band, blue crystal growth, spall | pixen | 48² | 1 | ACCEPT | no blue slab under it; the wedge bleeds off left and bottom, the blue crystals identify hardened against plain copper's malachite (`_r_ores_cmp_x4.png` row 3) |
| hardened_A2/7e6baf0b | same intent, wall phrasing | pixen | 48² | 1 | REJECT | opaque stone-wall background fills the frame — a backdrop tile filed as a subject; would fail the transparent-margin guard in `package-art.js` |
| meadow_bed_edit1/00f1c6fa | delete the turf oval under the stems; base opens along the bottom edge | edit_image_pixen | 48² | 1 | ACCEPT | the olive oval plinth is gone, stems and flowers unchanged, the base is open (`_r_beds_cmp_x4.png` row 1) |
| duskcap_bed_edit1/e2137ed3 | delete the moss diamond islet under the log | edit_image_pixen | 48² | 1 | ACCEPT | the diamond is gone; mossed log and duskcaps intact, bleeding off the bottom edge (`_r_beds_cmp_x4.png` row 2) |
