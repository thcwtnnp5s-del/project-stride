# REGIONAL_CONTENT_PACK_01 — Integration manifest

```
STATUS: proposal manifest · NOT CANON · nothing listed here is integrated
Machine-readable per-family records: out/<family>/manifest.json (written by tools/package.js).
Readiness is this pack's verdict after blind Visual QA; the integrator re-judges on the then-current HEAD.
```

**Re-read the current repository HEAD before integrating anything.** This pack was produced against
`dc8f6f6` while the World & Reward Depth 01 session was changing schemas, rarity, content
definitions, the atlas layout and asset packaging concurrently. Ids below are proposals and must be
checked against whatever `enemies.json` / `items.json` / `atlas_layout.json` / `Scripts/art/package-art.js`
look like on the day.

Readiness vocabulary: **READY** (accepted by blind QA at ×2, packaged, has everything a packaging line
needs) · **READY WITH NOTE** (accepted, a recorded caveat the integrator should read) · **CONCEPT-ONLY**
(art exists but is not fit to ship, or no art) · **WITHHELD** (packaged with `status: withheld`, must not
be drawn).

Dependencies are stated against the HEAD `dc8f6f6` shapes: the combat stage reads `<id>_f<i>.png` on
one canvas per figure with an `anchor` row; icons are 48×48 in the 84-px cell; atlas props are
transparent cutouts placed by native pixel coordinates; the location vignette slot is 384×176.

## A. Enemy stage sets (`out/enemies/`)

| Proposed id | Files | Canvas | Anchor | Tracks (frames · fps · loop) | Intended use | Depends on | Readiness |
|---|---|---|---|---|---|---|---|
| `enemy.bristleback_boar` | `boar_idle_f0..6`, `boar_attack_f0..8`, `boar_defeat_f0..6` | 56×56 | 43 | idle 7·6·pingpong / attack 9·10·once / defeat 7·8·once | Whispering Woods second fight, on `backdrop_forest` | enemies.json entry, drops, `item.boar_tusk`; fx_impact for the hit | → §H |
| `enemy.oakback_bear` | `bear_idle_f0..6`, `bear_attack_f0..8`, `bear_defeat_f0..6` | 76×76 | 61 | idle 7·5·pingpong / attack 9·8·once / defeat 7·6·once | Woods heavy fight, `backdrop_forest` | the stage must accept a 76 canvas (guardian is 96, so it does); `item.bear_pelt` | → §H |
| `enemy.frosthorn_ram` | `ram_idle_f0..6`, `ram_attack_f0..8`, `ram_defeat_f0..6`, (`ram_hit_f0..3` withheld) | 56×56 | 42 | idle 7·6 / attack 9·10 / defeat 7·8 | Frostmere second fight, `backdrop_frostmere` | `item.ram_horn` | → §H |
| `enemy.adit_bat` | `bat_idle_f0..6`, `bat_attack_f0..8`, (`bat_defeat` withheld) | 40×40 | 38 | idle 7·6 / attack 9·10 | Mine light fight, `backdrop_mine` | stage tolerates a missing defeat | → §H |
| `enemy.scree_crawler` | `crawler_idle_f0..6`, `crawler_attack_f0..8`, (`crawler_defeat` withheld) | 48×48 | 40 | idle 7·6 / attack 9·10 | Mine armoured fight, `backdrop_mine` | `item.granite_chitin`; missing defeat | → §H |
| `enemy.hollow_weaver` | `weaver_idle_f0..6`, `weaver_attack_f0..8`, (`weaver_defeat` withheld) | 48×48 | 42 | idle 7·6 / attack 9·10 | Hollow flurry fight, `backdrop_hollow` | `item.gloom_silk`; missing defeat | → §H |
| `enemy.mire_salamander` | `salamander_idle_f0..6`, `salamander_attack_f0..8`, `salamander_defeat_f0..6` | 56×56 | 50 | idle 7·6 / attack 9·10 / defeat 7·8 | Hollow normal fight, `backdrop_hollow` | none new (drops `hollow_root`) | → §H |
| `enemy.great_elk` | — | — | — | — | Frostmere perilous encounter | — | **CONCEPT-ONLY** (no art) |

## B. Material icons (`out/materials/`)

| Proposed id | File | Dims | Suggested rarity | Source | Use | Readiness |
|---|---|---|---|---|---|---|
| `item.boar_tusk` | `icon_boar_tusk_48.png` | 48×48 | Rare | Bristleback Boar | Bronze Longsword pommel | → §H |
| `item.bear_pelt` | `icon_bear_pelt_48.png` | 48×48 | Rare | Oakback Bear | Bearhide Coat | → §H |
| `item.granite_chitin` | `icon_granite_chitin_48.png` (c3; c2 kept in candidates) | 48×48 | Rare | Scree Crawler | Reinforced Bronze Pickaxe | → §H |
| `item.gloom_silk` | `icon_gloom_silk_48.png` | 48×48 | Rare | Hollow Weaver | Bronze Longsword grip | → §H |
| `item.ram_horn` | `icon_ram_horn_48.png` | 48×48 | Rare | Frosthorn Ram | Hornbound Bronze Axe | → §H |

## C. Gear icons (`out/gear/`)

| Proposed id | File | Dims | Slot | Suggested rarity | Readiness |
|---|---|---|---|---|---|
| `item.bronze_longsword` | `icon_bronze_longsword_48.png` | 48×48 | weapon | Epic | → §H |
| `item.bearhide_coat` | `icon_bearhide_coat_48.png` | 48×48 | armor | Epic | → §H |
| `item.reinforced_bronze_pickaxe` | `icon_reinforced_bronze_pickaxe_48.png` | 48×48 | tool/pickaxe t2 | Epic | → §H |
| `item.hornbound_bronze_axe` | `icon_hornbound_bronze_axe_48.png` | 48×48 | tool/axe t2 | Epic | → §H |

## D. World props and landmarks (`out/world/`)

| id | File | Dims | Class | Intended placement (proposal) | Readiness |
|---|---|---|---|---|---|
| prop_plank_bridge | `prop_plank_bridge.png` | 64×40 | visual geography | on the Meadowrun between Haven's Rest and the Woods (the Old Ford site) | → §H |
| prop_waystone | `prop_waystone.png` | 32×32 | visual geography | route junctions | → §H |
| prop_ruin_corner | `prop_ruin_corner.png` | 48×40 | visual geography | Hollow approaches | → §H |
| prop_mine_headframe | `prop_mine_headframe.png` | 48×56 | visual geography | Stonefall worked ground | → §H |
| prop_ore_cart_rails | `prop_ore_cart_rails.png` | 48×32 | visual geography | Stonefall | → §H |
| prop_elder_oak | `prop_elder_oak.png` | 64×64 | visual geography / minor landmark | Woods interior | → §H |
| prop_alpine_hut | `prop_alpine_hut.png` | 48×40 | visual geography | Rimeward Pass | → §H |
| prop_cold_camp | `prop_cold_camp.png` | 48×32 | visual geography | roadside, Woods–Mine track | → §H |
| prop_ruined_tower | `prop_ruined_tower.png` | 40×64 | possible future location (`future` landmark) | east moor (withheld tile) | → §H |
| prop_hamlet_cluster | `prop_hamlet_cluster.png` | 96×64 | possible future location (`future` landmark) | south lowlands | → §H |
| prop_charcoal_clamp | `prop_charcoal_clamp.png` | 48×40 | visual geography | Woods edge | → §H |
| prop_deer_group | `prop_deer_group.png` | 40×32 | visual geography (fauna silhouette) | meadow | → §H |

## E. Location vignette variants (`out/vignettes/`)

| id | File | Dims | Location | Readiness |
|---|---|---|---|---|
| vignette_havens_rest_ford | `vignette_havens_rest_ford.png` | 384×176 | Haven's Rest | → §H |
| vignette_whispering_woods_ring | `vignette_whispering_woods_ring.png` | 384×176 | Whispering Woods | → §H |
| vignette_stonefall_spoil | `vignette_stonefall_spoil.png` | 384×176 | Stonefall Mine | → §H |
| vignette_hollow_mere | `vignette_hollow_mere.png` | 384×176 | Forgotten Hollow | → §H |
| vignette_frostmere_pass | `vignette_frostmere_pass.png` | 384×176 | Frostmere | → §H |

## F. Ambient fauna (`out/fauna/`)

| id | Files | Dims | Biome | Readiness |
|---|---|---|---|---|
| fauna_butterfly_24 / _16 / _loop | `fauna_butterfly_24.png`, `fauna_butterfly_16.png`, `fauna_butterfly_loop_f0..4` | 24 / 16 / 24 | Haven's Rest | → §H |
| fauna_songbird_32 / _16 / _loop | `fauna_songbird_32.png`, `_16.png`, `_loop_f0..6` | 32 / 16 / 32 | Woods | → §H |
| fauna_bat_32 / _16 / _loop | `fauna_bat_32.png`, `_16.png`, `_loop_f0..4` | 32 / 16 / 32 | Mine | → §H |
| fauna_crow_32 / _16 / _loop | `fauna_crow_32.png`, `_16.png`, `_loop_f0..6` | 32 / 16 / 32 | Hollow | → §H |
| fauna_ptarmigan_32 / _16 | `fauna_ptarmigan_32.png`, `_16.png` | 32 / 16 | Frostmere | → §H |
| fauna_hare_32 / _16 / _loop | `fauna_hare_32.png`, `_16.png`, `_loop_f0..6` | 32 / 16 / 32 | Haven's Rest / Woods edge | → §H |

## G. Content proposals with no art (by design)

`enemy.great_elk` (concept), `location.lower_gallery` and `location.old_ford` (proposals, §6 of
`CONTENT_PROPOSALS.md`), every recipe and every stat figure.

## H. QA verdicts and final readiness

Blind passes: `qa/QA_PASS_A.md` (enemies + ctx), `qa/QA_PASS_B.md` (icons + fauna), `qa/QA_PASS_C.md` (props + vignettes), `qa/QA_PASS_D.md` (re-rolls). Reviewer set-verdicts were FAIL / FAIL / FAIL (each naming the failing members and saying the rest holds); the per-asset readiness below is drawn from their per-code findings. **Nothing a reviewer called unidentifiable or a wrong object is READY.**

| Asset | Blind read (pass · code) | Readiness |
|---|---|---|
| boar_idle / boar_attack / boar_defeat | A kdkn / sjsk / sbjc — boar; charge reads clearly; collapse clear (rest-vs-dead note) | **READY** |
| bear_idle / bear_attack2 / bear_defeat | A blsn · D cwcp (rear-up / roar / swipe, clear) · A nzdq | **READY** (bear_attack r1 WITHHELD) |
| ram_idle / ram_attack / ram_defeat | A hrfz / wwlr (charge, clear) / pkrg; ctx twqp pale-on-pale, readable | **READY WITH NOTE** (ram_hit WITHHELD) |
| salamander_idle / salamander_attack / salamander_defeat | A crpp (minor jitter) / mnsv (bite, clear) / nfqv (rest-vs-dead) | **READY WITH NOTE** |
| crawler_idle / crawler_attack | A grnq ("rock with legs" risk, face unreadable) / kkfp (bite, clear) | **READY WITH NOTE** — recommend a face/eye correction round; crawler_defeat WITHHELD |
| weaver_idle | A sjcg (spider/bug, near-still; dark on dark) | **CONCEPT-ONLY** — weaver_attack r1+r2 WITHHELD (A gjkl, D dlmp), weaver_defeat WITHHELD |
| bat_* | A plqf / gkbp (gargoyle / small dragon), nlhr (owl-like frontal head) | **CONCEPT-ONLY** — rebuild as a PixelLab character |
| icon_boar_tusk_48 | B xmfl — claw / tusk / horn, sure | **READY** |
| icon_bear_pelt_48 | B tswg — bear pelt / hide rug, fairly sure; low value range | **READY WITH NOTE** |
| icon_ram_horn_48 | B pscv · D fqxn — coiled horn first, shell/grub alternative (two reviewers) | **READY WITH NOTE** (owner call on the grub read) |
| icon_gloom_silk_48 (c3) | D qbhr — spool of thread, sure (c2 REJECTED: B wkwz) | **READY** |
| icon_granite_chitin_48 | B qplh (pauldrons/shells), thkf (seashell); c4 barrel | **CONCEPT-ONLY / WITHHELD** — four rounds, rethink the noun |
| icon_bronze_longsword_48 | B srrf — sword, sure | **READY WITH NOTE** (kin of the shipped bronze_sword — coherence call) |
| icon_bearhide_coat_48 | B ftff · D nxql — garment (cloak / robe); "sack" alternative at ×1 | **READY WITH NOTE** |
| icon_hornbound_bronze_axe_48 | B vvrd — hatchet / axe, sure | **READY** |
| icon_reinforced_bronze_pickaxe_48 | B rdzq (polearm), D qrcw (hammer) | **WITHHELD** — three rounds; a future round should start from the shipped bronze_pickaxe via PixelLab edit, not a fresh noun |
| prop_plank_bridge | C fgck — sure (dark water note) | **READY WITH NOTE** (must sit on a river) |
| prop_waystone | C jfrz — sure (purple outline outlier) | **READY WITH NOTE** |
| prop_ruin_corner | C dbjc — boulders + dead tree, not a ruin | **READY WITH NOTE** (scenery either way) |
| prop_mine_headframe | C szbm — sure | **READY** |
| prop_ore_cart_rails (c2) | D gzqw — mine cart, fairly sure; lower band muddled (c1 REJECTED: C bnzd) | **READY WITH NOTE** |
| prop_elder_oak | C hwkg — sure (bubbly foliage; square plate) | **READY WITH NOTE** |
| prop_alpine_hut | C thmm — sure (grey-on-grey) | **READY WITH NOTE** |
| prop_cold_camp | C sndm — tent / shelter, fairly sure | **READY WITH NOTE** |
| prop_ruined_tower | C xpvc — sure (intact, not ruined; ivy streak) | **READY WITH NOTE** |
| prop_hamlet_cluster | C fgwr — sure (brighter outlier) | **READY WITH NOTE** |
| prop_charcoal_clamp | C hwcq — reads as a usable cook/smelt station | **WITHHELD** (implied interaction, L-17) |
| prop_deer_group | C lrcw — unidentifiable | **REJECTED** |
| 5 vignettes | C cmzs / rwxs / tgxj / ddsr / gjpp — all sure, clear depth; gjpp a brighter hand; tgxj black corners | **READY WITH NOTE** (set-coherence of the Haven's Rest variant) |
| fauna 24/32 stills + 5 loops | B — all read (bird, hare, bat, crow, butterfly, white fowl); loops subtle | **READY** (ptarmigan_32 WITH NOTE: species unreadable) |
| fauna 16 stills | B — butterfly, songbird, hare, crow read; ptarmigan_16 hen/blob; bat_16 moth | **READY WITH NOTE**; bat_16 **WITHHELD** |

Reviewer C's cross-cutting note — the dark-ground prop family is low-contrast at ×2 on the staging grey — applies to every prop: **judge again in place on the atlas base before shipping.**

Counts: packaged 67 records; **accepted 53, withheld 14**; of the accepted, 23 are READY without caveat and 30 READY WITH NOTE; CONCEPT-ONLY: bat family, weaver, chitin icon, Great Elk; REJECTED: deer group (and every unpackaged candidate listed in the READMEs).
