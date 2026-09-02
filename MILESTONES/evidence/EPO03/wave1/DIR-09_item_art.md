# DIR-09 — Item Art (EPO03 Wave 1)

Evidence: nine ×2 sheets (48 dp = Inventory tile, Craft tray, reward row) in
`GAME_BIBLE/ART/exploration/EPO03/review/items/`, all 62 files read by eye on
`#1e1e1e`. The FMPO02 metric ran as triage only (48/84 pairs flag, including
`meadow_herb`/`duskcap`); its `png.js` require path is broken in place. Zero
generations spent.

## TOP FAILURES (ranked by co-visibility)

| # | Collision | Why, at 48 dp | Differentiator to author |
|---|---|---|---|
| 1 | `wolfhide_jerkin` / `tuskbound_jerkin` / `frostlined_jerkin` / `bearhide_coat` | four identical brown vests; tells ≤6 px | wolfhide = shaggy **grey** fur; tuskbound = tan, **two big white tusks across the chest**; frostlined = **blue-grey wool**, white collar *and* hem; bearhide = **near-black, hem below the vest line** |
| 2 | `boar_tusk` / `great_tusk` / `pristine_wolf_fang`; `ram_horn` / `pristine_horn` | five ivory curves; the fang reads as a tusk, the horn is a 12%-fill sliver | great_tusk = **bound pair**; fang = **tooth on a cord loop**; pristine_horn = ridged spiral **corner to corner**, brass ferrule; anchors stay |
| 3 | `hearty_stew` vs `expedition_stew` | two dark iron pots, dark-on-dark | hearty = **wooden bowl heaped orange-brown, ladle standing, steam**; expedition = cauldron, lit contents, steam, light rim. Broth keeps the green bowl (tea owns the cup) |
| 4 | `reclaim_axe` / `_pickaxe` / `_chestplate` | three identical crates (IoU 0.90–0.93); stamp illegible | **bronze head protrudes from the open lid** — the outline must change |
| 5 | `bronze_longsword` vs `training_sword` | the epic is the thinnest icon in the game (12% fill), shorter than the uncommon sword | corner-to-corner bright bronze blade, two-hand grip, wide guard |
| 6 | `bronze_pickaxe` vs `reinforced_pickaxe`; `hornpoint_pickaxe` | two bronze heads; hornpoint 17% fill, dark on dark | reinforced = **grey steel strap and rivets** on the head; hornpoint = big pale bone point filling the frame |
| 7 | `clawguard_coat`, `frostwarden_coat` | both render a *person* (clawguard has a face, red emissive eyes) | garment only, no head: hide coat with pale shoulder claw plates; blue-white long coat, standing collar |
| 8 | `tin_ore` vs `scrap_metal` | two grey angular masses | tin = grey rock, **one silver-white vein** |
| 9 | `oak_handle` vs `pine_plank` | two pale-tan sticks | oak red-brown, **leather-wrapped grip end** |
| 10 | `frost_claw`, `hornbound_bronze_axe` | cyan shard near the reserved teal; axe head reads as a mallet | curved talon, dark root, blue-white; cut a clear bit and beard |

## WHAT TO REPLACE

**Regenerate (13)** — `create_image_pixen` 48², `no_background`, §7.2 clause
verbatim, ART-07 §4 structure; 1 gen per roll, expect 3–6: `wolfhide_jerkin`, `tuskbound_jerkin`, `frostlined_jerkin`,
`bearhide_coat`, `clawguard_coat`, `frostwarden_coat`, `hearty_stew`,
`bronze_longsword`, `pristine_horn`, `pristine_wolf_fang`, `great_tusk`,
`reinforced_pickaxe`, `hornpoint_pickaxe`.

**Edit (8)** — `edit_image_pixen` (1) first, `edit_image` (≈20) only after
two pixen failures: `expedition_stew`, `tin_ore`, `oak_handle`, `frost_claw`,
`hornbound_bronze_axe`, `reclaim_axe`, `reclaim_pickaxe`, `reclaim_chestplate`.

## WHAT TO KEEP (41)

Every other file. WATCH, not worth a roll: the four pelts, `oak_plank`
(D-1), `scalewarmed_chestplate` (pink knit), `goblin_toolhead` (small).
`boar_tusk`, `ram_horn` are anchors. Project items:
`projects.json` outputs no items; nothing to author (G-3).

## PRODUCTION FAMILY

| Asset | Canvas | Frames | Count | Tool | Reference |
|---|---|---|---|---|---|
| Icon, regenerate | 48×48 | 1 | 13 | `create_image_pixen` | §7.2 clause; sibling anchor |
| Icon, edit | 48×48 | 1 | 8 | `edit_image_pixen` → `edit_image` | the shipped file |

**Family language, binding.** Food: warm palette, steam on every hot dish,
vessel escalates bowl → bowl-with-ladle → cauldron, bundle for rations. Ores: grey rock, one coloured vein, never
emissive. Logs: bark and ring colour, a sprig as species tell. Herbs: leaf /
cap / bloom / root / spool silhouettes. Armour: silhouette by class (tunic,
plate, jerkin, longer-hemmed coat), one colour mass each, garment only.
Weapons and tools: the tell at the head-to-haft joint; epic is never the
smallest. Drops: pattern and prop, never tone. Masterwork/signature: no seal
pixels in the icon — `seal_masterwork` (brass crossed-tools plate) and
`seal_signature` (leather claw patch) overlay tile and reward card; the icon
carries one brass fitting at the joint in the seal's brass.

## PIXELLAB BUDGET

Cap **200** (GOV-04 units): 13 × 6 pixen rolls = 78; 8 × 3
`edit_image_pixen` = 24; `edit_image` fallback ≤4 × 20 = 80; anchor re-roll
if a sibling cannot clear it, ≤18. Expected ≈110.

## TEST

`item_icon_distinctness_test.dart`: byte identity and the copper/tin
assertion stay verdicts. Add named-pair ceilings (unaligned 48² alpha IoU, as
copper/tin computes) where the fix *is* a silhouette change: jerkins
pairwise and vs `bearhide_coat` < 0.80 (today 0.85–0.88); `hearty_stew` vs
`herb_broth` < 0.80 (0.896); reclaim trio < 0.85 (0.90–0.93);
`bronze_longsword`, `pristine_horn` fill ≥ 20% (12%). No global threshold:
distinct pairs measure 0.85–0.90 (`ram_wool`/`ember_core` 0.90). The metric
is triage; the ×2 sheet read is the verdict (M-04, M-14).

## PHONE-SCALE SUCCESS CRITERIA

1. Armour pocket: four vests, four colours, two hem lengths, nameable
   unlabelled.
2. Materials pocket: pair / cord / spiral / tusk / coil read at arm's length.
3. Cooking list: bowl-with-ladle and cauldron never confused; hot dishes
   steam.
4. Three reclaim rows show three different bronze heads.
5. Longsword is the largest blade; no icon under 20% fill.
6. No armour shows a face; nothing reads emissive or teal.
7. All 62 files 48×48, binary alpha, palette guard green.
