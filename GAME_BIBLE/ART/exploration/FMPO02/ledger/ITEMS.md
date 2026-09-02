# FMPO02 Wave 2 — ITEMS ledger (PROD-ITEMS)

Balance at open: **9,551 remaining / 449 used / 10,000 total** (Tier 3, shared pool — other
wave2 leads generate concurrently, so `used` deltas below are account-wide, not this
family's alone).
Balance at close: **8,642 remaining / 1,357 used / 10,000 total**.
This family's own spend: **72 generations** (64 planned per ART-07 §5's recommended
estimate + 8 extra: 2 re-tries on `hearty_stew` chasing a no-flame iron pot that never
arrived, 4 re-tries on `clawguard_coat` chasing a garment-only render that never arrived,
2 re-tries on the reclaim crates chasing a warm-wood-with-clear-lid-stamp combination).
Cap was 140; well under.

All jobs `create_image_pixen`, 48×48, `no_background=true`, `view="high top-down"`,
`outline="single color outline"`. Failed calls shown as REJECT (rate-limit, $0 billed
per the shared account's own note) are listed for traceability but not charged.

## RE-AUTHOR (9)

| job/id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| hearty_stew c1 `5b21999f` | pixen | 48x48 | 1 | **ACCEPT** | iron pot, chunky stew, two handles — clearest read, best QA score of the non-emissive candidates |
| hearty_stew c2 `37a079aa` | pixen | 48x48 | 1 | REJECT | good pot but higher colour-histogram overlap with `expedition_stew` than c1 |
| hearty_stew c3 `4758d1ee` | pixen | 48x48 | 1 | REJECT | lowest collision score but shows a lit flame under the pot — emissive, violates style clause |
| hearty_stew c4 `19961886` | pixen | 48x48 | 1 | REJECT | smaller, less legible pot read |
| hearty_stew retry1 `a547f2c6` | pixen | 48x48 | 1 | REJECT | asked explicitly for "no fire" — still rendered a flame |
| hearty_stew retry2 `ce9c023b` | pixen | 48x48 | 1 | REJECT | same defect on a second seed; stopped chasing (PRODUCTION_RULES: a batch failing twice is left, not chased) |
| goblin_toothed_axe c1 `367d407a` | pixen | 48x48 | 1 | **ACCEPT** | jagged tooth-edge, diagonal haft — reads unmistakably as an axe; PASS vs all axe siblings |
| goblin_toothed_axe c2 `ea6830ab` | pixen | 48x48 | 1 | REJECT | crescent blade reads closer to a sickle |
| goblin_toothed_axe c3 `8c681805` | pixen | 48x48 | 1 | REJECT | teeth too subtle at 48px |
| goblin_toothed_axe c4 `60d7b28f` | pixen | 48x48 | 1 | REJECT | wide flat head reads as a mallet, not an axe |
| tinbraced_pickaxe c1 `6bf35e3e` | pixen | 48x48 | 1 | **ACCEPT** | grey head, visible tin-band ring at the joint; PASS vs `reinforced_pickaxe` and `hornpoint_pickaxe` (was COLLISION on both, shipped) |
| tinbraced_pickaxe c2 `0e319dba` | pixen | 48x48 | 1 | REJECT | tin band less distinct than c1 |
| tinbraced_pickaxe c3 `aef0a5c8` | pixen | 48x48 | 1 | REJECT | head rendered maroon-tinted, off the grey-iron material language |
| tinbraced_pickaxe c4 `80c70ee7` | pixen | 48x48 | 1 | REJECT | reads too close to `hornpoint_pickaxe`'s bone-hook silhouette |
| clawguard_coat c1 `51bd55a8` | pixen | 48x48 | 1 | **ACCEPT** | cinched cape silhouette clears `bearhide_coat`'s collision (0.848/0.636 shipped → 0.690/0.419); see OPEN ISSUE below |
| clawguard_coat c2 `cf8ac948` | pixen | 48x48 | 1 | REJECT | higher shape overlap with bearhide than c1 |
| clawguard_coat c3 `f529344c` | pixen | 48x48 | 1 | REJECT | higher shape overlap with bearhide than c1 |
| clawguard_coat c4 `87ae54af` | pixen | 48x48 | 1 | REJECT | reroll attempt (empty-cloak phrasing), still a rendered face |
| clawguard_coat retry `877954a5` | pixen | 48x48 | 1 | REJECT | reroll attempt, still a rendered face |
| clawguard_coat retry `fcbece37` | pixen | 48x48 | 1 | REJECT | reroll attempt, still a rendered face |
| clawguard_coat retry `38f28838` | pixen | 48x48 | 1 | REJECT | reroll attempt ("coat" phrasing) — off-brief mask/breastplate shape |
| clawguard_coat retry `1018d448` | pixen | 48x48 | 1 | REJECT | reroll attempt, still a rendered face; stopped chasing after 4 reroll attempts |
| frostwarden_coat c1 `78a60e0d` | pixen | 48x48 | 1 | NOT NEEDED | direct pixel inspection: shipped `frostwarden_coat.png` is already pale blue-white with a standing collar (not the warm-brown ART-07 described) and only WATCHes, not COLLIDEs, against `bearhide_coat`/`clawguard_coat`. Premise stale — shipped kept. |
| frostwarden_coat c2 `55915d1b` | pixen | 48x48 | 1 | NOT NEEDED | (as above) |
| frostwarden_coat c3 `354a5e56` | pixen | 48x48 | 1 | NOT NEEDED | (as above) |
| frostwarden_coat c4 `29c6a932` | pixen | 48x48 | 1 | NOT NEEDED | (as above) |
| lynx_pelt c1 `ceadf3e3` | pixen | 48x48 | 1 | REJECT | rendered as a lynx-face portrait, not a spread pelt |
| lynx_pelt c2 `bdf2c193` | pixen | 48x48 | 1 | REJECT | good spread pelt, but squarer/blockier silhouette than the wolf/bear/boar pelt family |
| lynx_pelt c3 `d4169c3a` | pixen | 48x48 | 1 | **ACCEPT** | tawny spread pelt, spot pattern, tufted ears — matches `wolf_pelt`'s silhouette family while separating on pattern per §2 |
| lynx_pelt c4 `7c54d313` | pixen | 48x48 | 1 | REJECT | also good; c3 had marginally lower shape-IoU vs `wolf_pelt` |
| pristine_horn c1 `29751828` | pixen | 48x48 | 1 | **ACCEPT** | straight ridged spiral (unicorn/narwhal register) — PASS vs `ram_horn` (was WATCH on colour, shipped); ram_horn's coiled-loop shape stays the un-moved anchor |
| pristine_horn c2 `3ffcfbdb` | pixen | 48x48 | 1 | REJECT | tight coil reads too close to ram_horn's loop (WATCH) |
| pristine_horn c3 `d41f2ce5` | pixen | 48x48 | 1 | REJECT | rendered maroon-tinted, not ivory |
| pristine_horn c4 `b8d8bcad` | pixen | 48x48 | 1 | REJECT | coiled shape, weaker ivory read |
| heat_scale c1 `c53e33ce` | pixen | 48x48 | 1 | NOT NEEDED | direct pixel inspection: shipped `heat_scale.png` is already warm brown/orange (PASS vs `frost_claw`, colour intersection 0.213). Premise stale — shipped kept. |
| heat_scale c2 `807d5ca8` | pixen | 48x48 | 1 | NOT NEEDED | (as above) |
| heat_scale c3 `32b240e9` | pixen | 48x48 | 1 | NOT NEEDED | (as above) |
| heat_scale c4 `aea053f0` | pixen | 48x48 | 1 | NOT NEEDED | (as above) |
| frost_claw c1 `1cf2240c` | pixen | 48x48 | 1 | NOT NEEDED | direct pixel inspection: shipped `frost_claw.png` is already pale icy blue (PASS vs `heat_scale`). Premise stale — shipped kept. |
| frost_claw c2 `959a51cd` | pixen | 48x48 | 1 | NOT NEEDED | (as above) |
| frost_claw c3 `66ca2a86` | pixen | 48x48 | 1 | NOT NEEDED | (as above) |
| frost_claw c4 `61d1d358` | pixen | 48x48 | 1 | NOT NEEDED | (as above) |

## NEW — reclaim salvage crates (3)

| job/id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| reclaim_bronze_axe c1 `18ebdf82` | pixen | 48x48 | 1 | **ACCEPT** | clearest faint axe ghost-stamp on the open lid's inside face; WATCH (not COLLISION) vs `bronze_ingot` |
| reclaim_bronze_axe c2 `a47eafb2` | pixen | 48x48 | 1 | REJECT | lid shows a letter-like rune, not an axe silhouette |
| reclaim_bronze_axe c3 `0945da7e` | pixen | 48x48 | 1 | REJECT | axe icon on the front panel, not the lid interior |
| reclaim_bronze_axe c4 `0a02a2d4` | pixen | 48x48 | 1 | REJECT | lid open but no visible stamp |
| reclaim_bronze_axe retry `d73ffe62` | pixen | 48x48 | 1 | REJECT | reroll attempt, lid rendered closed |
| reclaim_bronze_pickaxe c1 `f80883aa` | pixen | 48x48 | 1 | **ACCEPT** | only candidate that stayed WATCH (not COLLISION) vs `bronze_ingot`; crossed-pickaxe cue legible |
| reclaim_bronze_pickaxe c2 `ff62d679` | pixen | 48x48 | 1 | REJECT | lid shows a rune/scroll, not a pickaxe |
| reclaim_bronze_pickaxe c3 `b0637864` | pixen | 48x48 | 1 | REJECT | lid open but empty, no stamp |
| reclaim_bronze_pickaxe c4 `c917ad8e` | pixen | 48x48 | 1 | REJECT | good warm-wood crate but COLLISION vs `bronze_ingot` (0.716/0.610) |
| reclaim_bronze_chestplate c1 `e72788ce` | pixen | 48x48 | 1 | **ACCEPT** | lowest shape-IoU vs `bronze_ingot` among the WATCH-tier candidates |
| reclaim_bronze_chestplate c2 `ae3d7aa7` | pixen | 48x48 | 1 | REJECT | ornate scroll-and-latch design reads as a treasure chest, not a plain salvage crate |
| reclaim_bronze_chestplate c3 `f9e76dd1` | pixen | 48x48 | 1 | REJECT | same ornate-lid defect |
| reclaim_bronze_chestplate c4 `05f9e6b1` | pixen | 48x48 | 1 | REJECT | good warm-wood crate but COLLISION vs `bronze_ingot` (0.724/0.638) |
| reclaim_bronze_chestplate retry `da9be625` | pixen | 48x48 | 1 | REJECT | reroll attempt, rendered as a closed drawer, no open-lid stamp |

## VERIFY (8, 2 candidates each)

| job/id | tool | canvas | cost | verdict | reason |
|---|---|---|---|---|---|
| scalewarmed_chestplate c1 `f29ed1f7` | pixen | 48x48 | 1 | **ACCEPT** | deep-red scale texture; QA showed shipped icon actually COLLIDES with `bronze_chestplate` (0.706/0.680) — reclassified VERIFY→REPLACE on evidence; c1 drops it to WATCH (0.653/0.545) |
| scalewarmed_chestplate c2 `a66937dd` | pixen | 48x48 | 1 | REJECT | brighter red — COLLISION vs `bronze_chestplate` (0.799/0.733), worse than c1 |
| bronze_longsword c1 `ddd5416c` | pixen | 48x48 | 1 | **ACCEPT** | QA showed shipped icon COLLIDES with `bronze_sword` (0.641/0.735) — reclassified VERIFY→REPLACE on evidence; c1 is PASS (0.451/0.417) |
| bronze_longsword c2 `7af279aa` | pixen | 48x48 | 1 | REJECT | shorter-reading blade, still WATCH vs `bronze_sword` |
| fanghilt_sword c1 `b9880b2e` | pixen | 48x48 | 1 | REJECT | fang guard visible but still WATCH vs both bronze swords |
| fanghilt_sword c2 `d5c464d3` | pixen | 48x48 | 1 | **ACCEPT** | QA showed shipped icon COLLIDES with both `bronze_sword` (0.720/0.714) and `bronze_longsword` (0.575/0.714) — reclassified VERIFY→REPLACE; c2 is PASS vs both |
| wolf_pelt c1 `58eea927` | pixen | 48x48 | 1 | REJECT | KEEP shipped — shipped already reads as a proper headed spread pelt; c1 is an abstract cross shape, not an improvement |
| wolf_pelt c2 `3ee727f2` | pixen | 48x48 | 1 | REJECT | rendered as a face portrait, not a spread pelt |
| hollow_root c1 `2c1b0481` | pixen | 48x48 | 1 | REJECT | KEEP shipped — shipped's forked-stick silhouette already reads distinctly from its siblings (meadow_herb/duskcap/gloom_silk), no collision to fix |
| hollow_root c2 `64eadef6` | pixen | 48x48 | 1 | REJECT | (as above) |
| ram_horn c1 `5e8062e6` | pixen | 48x48 | 1 | REJECT | KEEP shipped — must stay the un-moved coiled-loop anchor `pristine_horn` differentiates against |
| ram_horn c2 `e309e719` | pixen | 48x48 | 1 | REJECT | (as above) |
| reinforced_pickaxe c1 `8e24c609` | pixen | 48x48 | 1 | REJECT | KEEP shipped — a grey-headed replacement here would re-collide with the new grey `tinbraced_pickaxe` |
| reinforced_pickaxe c2 `a407daf8` | pixen | 48x48 | 1 | REJECT | (as above) |
| bearhide_coat c1 `ab2e5538` | pixen | 48x48 | 1 | REJECT | KEEP shipped — explicit anchor per ART-07 §1, unmoved by design; c1 is a close match to shipped, not a needed change |
| bearhide_coat c2 `d47cff5e` | pixen | 48x48 | 1 | REJECT | rendered as a bear-mascot costume with visible face/legs, off-register |

## Totals

- Requested (this family): 72 generations (64 planned + 8 chase/retry, see above)
- Accepted: 12 (6 RE-AUTHOR replacements, 3 NEW, 3 VERIFY→REPLACE)
- Rejected: 60
- Balance start: 9,551 remaining / 449 used
- Balance end: 8,642 remaining / 1,357 used (shared account pool; other wave2 families generated concurrently)

## Producer verdict (2026-09-02, `review/items_old_new_x3.png`)

All twelve accepted for packaging. Notes overriding the tool's two flagged
collisions: `hearty_stew` (grey iron pot, lidless, chunky) vs `expedition_stew`
(black lidded cauldron with ladle) are two vessels to the eye at ×1 and ×3 —
the histogram collision is the shared brown broth, which is the point of a
stew; `clawguard_coat` still renders as a hooded figure rather than a garment,
as the shipped one did, so the register debt is pre-existing and the new
silhouette (cinched dark cape, bone claw guards at the shoulders) separates it
from `bearhide_coat` and `frostwarden_coat`, which was the defect named.
`frostwarden_coat`, `heat_scale`, `frost_claw` stay as shipped (already correct).

## Council closure (FINAL-12 loot-box read, 2026-09-02)

The three reclaim crates were open-lidded and read as loot boxes. Three
`edit_image_pixen` edits (1 each) closed the lids with the tool or plate
strapped to the outside; jobs 4a1c526e (axe), 61c33456 (pickaxe), 8edf2a62
(chestplate). ACCEPT ×3; the open-lid versions are kept under
`rejected/items/*_openlid.png`.
