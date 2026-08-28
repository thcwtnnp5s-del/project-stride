# WORLD ATLAS REMASTER 01 — Protection Plan (ATLAS-C audit, 2026-08-27)

Authoritative coordinate protection table for the remaster. All coordinates
are 1024² atlas px (world px = atlas × 6). Location hitRadius 72 world px =
12 atlas px.

Classes: **HF** = hard-frozen (byte-identical, guard-enforced) ·
**FC** = frozen-center-generated-surround (center byte-frozen; surround may
regenerate but must stay biome-continuous) · **SOFT** = prefer preserve
(terrain type/palette must survive; pixels may be re-authored).

## The existing A-4 guard (package-art.js)

`PROT = {x0:256, y0:256, x1:768, y1:768, band:20}`; snapshot taken after
master + five approved-era static patches + dither crossfade ("the 559669e
state"); restore pass reverts every repair pixel deeper than the 20 px
hash-feathered rim band; drift check throws on any non-deep-water core pixel
differing from the snapshot (deep teal is exempt for the ocean conform).
**Effective hard-frozen core today: (276,276)–(748,748), water-exempt.**

## Playable locations (all inside the master core — already guard-covered)

| Feature | Marker | Painted footprint | Class |
|---|---|---|---|
| Haven's Rest | (456,521) r12 | 413–487 × 508–552 | HF |
| Whispering Woods | (383,509) r12 | ~300–430 × 460–560 | HF |
| Stonefall Mine | (566,496) r12 | massif 513–613 × 468–523; adit 553–580 × 488–515 | HF |
| Forgotten Hollow | (561,551) r12 | 540–598 × 530–575 | HF |
| Frostmere | (498,311) r12 | on the frozen basin (below) | HF |
| Amberfield (painted town) | (481,628) | town 445–512 × 600–652; fields 380–580 × 583–700 | HF |

Rumor targets: eastern_city (716,606), lower_gallery (574,488),
northern_range (686,326) — in core.

## Frostmere / Glasslake basin (the M-15 casualty)

| Feature | Bounds | Class |
|---|---|---|
| Frozen lake (Glasslake marker (461,334)) | 403–550 × 282–362 | HF |
| Full glacial cirque | 396–565 × 258–380 | HF |
| North cirque wall in the writable rim band | 400–560 × 256–276 | HF for this round (registry) |

## Volcano and structures

| Feature | Bounds | Class |
|---|---|---|
| Volcano massif | 580–817 × 278–465 | HF (part x≥748 via registry) |
| West watchtower | 627–646 × 290–323 | HF |
| East watchtower | 727–751 × 273–323 | HF (registry for x 748–751) |
| Crater / eruption overlay box | 668–732 × 284–348 | HF |
| East cliff→coves→shallows (WAR01 `east_join` band) | 752–820 × 272–436 (visible cliff 768–824 × 300–470) | HF via registry |
| Dark speckled headland (known residual) | 756–800 × 279–310 | FC — improve only under owner review |

## Roads / routes

Route polylines (interface data, painted bank roads in-core HF): HR→WW via
(421,518); HR→SM via (506,518),(541,506); WW→SM via (436,488),(506,478),
(551,488); WW→FH via (406,556),(456,576),(521,571); SM→FM via (556,461),
(539,416),(518,366).

| Feature | Bounds | Class |
|---|---|---|
| Corridor cut (`corridor_edit`) | 256–384 × 483–558 | HF |
| Road join (`roadjoin_edit`) | 216–320 × 480–552 | HF via registry (x<256) |
| Log bridge (inside corridor patch; est. 300–325 × 488–512) | protected via corridor rect | HF |
| West caravan road across pass meadow | winding band 128–256 × 495–575 | HF road pixels; FC meadow |
| Ring-2 western valley road | 0–128 × 495–580 | FC (road centerline frozen) |
| Caravan egg corridor | 199–245 × 506–532 | HF (road surface) |
| Stag egg box | 156–184 × 493–515 | HF via registry |
| Wayfarer's Pass label ground | (187,542) | SOFT |

## Rivers, delta, coasts, islands

| Feature | Bounds | Class |
|---|---|---|
| Meadowrun channel corridor | 485–545 × 400–610 | HF (in core) |
| Millbridge | 490–510 × 546–566 | HF |
| Delta + Ferry Crossing + Reedmouth + Marshlight | 520–690 × 595–748 | HF |
| East coastline + beach + shallows | 618–700 × 470–700 | HF |
| Saltreach Light | tower 710–728 × 613–655; headland 645–738 × 608–672 | HF |
| Tern Isles | 672–752 × 505–590 | HF |
| South strand (WAR01 adoptions) | 128–528 × 810–870 and 512–800 × 810–870 | HF via registry |
| Wanderer's Isles clusters | 785–865 × 490–537; 920–1005 × 503–537 | HF island land via registry |
| Cinder Skerries | 920–1000 × 175–250 | FC |
| Far Isles | 940–995 × 205–285 | FC |
| Flotsam-cleanup rects | (886–910, 622–662), (866–906, 760–784), (748–796, 844–906) | SOFT — keep open water |

## Ambient overlay anchors

In-place scenes: frame 0 is an untouched source crop — the ground under each
box is frozen or the overlay pops a rectangle of the old painting.

| Overlay | Box | Class |
|---|---|---|
| volcano eruption | 668–732 × 284–348 | HF |
| smoke (Haven's Rest / Stonefall) | 444–460 × 506–520 / 557–573 × 490–504 | HF |
| yeti2 | 490–534 × 324–358 | HF |
| bear2 | 340–366 × 592–620 | HF |
| fire3 | 284–328 × 624–676 | HF |
| tree_rustle_a / b | 276–324 × 596–644 / 352–396 × 660–704 | HF |
| ripple_coast / ripple_delta | 676–716 × 536–584 / 620–656 × 660–708 | HF |
| flock (straddles master bottom edge) | 456–520 × 730–770 | HF (y 748–770 via registry) |
| nessie corridor | 648–706 × 576–610 | SOFT (coastal water) |
| snow flurries ×3 | 456–520 × 286–350; 521–585 × 316–380; 416–480 × 351–415 | SOFT (snow) |
| forest mist ×4 | 301–397 × 436–484; 346–442 × 586–634; 296–392 × 676–724; 496–592 × 706–754 | SOFT (forest) |
| birds ×3 | 556–580 × 436–460; 676–700 × 556–580; 436–460 × 646–670 | SOFT |
| whale / ship | 808–846 × 598–639 / 765–805 × 645–680 | SOFT (open water) |
| skydragon corridor | 282–406 × 318–360 | SOFT (biome only) |

## Frontier label grounds (terrain must keep matching the name)

Worldspine (157,333) ridge; Frozen Shelf (445,176) pack ice; White Reach
(600,60) polar ice; Sunward Strand (511,860) beach (in HF strand);
Cinder Skerries / Wanderer's Isles / Far Isles per the island table. All SOFT
unless coincident with an HF rect. Note: the island label anchors sit in open
water W/NW of their painted clusters — protect the *painted* clusters, not
the anchors.

## Enforcement chosen for this round

The A-4 rect and its guard stay untouched. Features outside the core (or in
its writable rim band) are enforced by the round's **landmark registry**:
tracked golden crops extracted from the accepted composite post-conform,
compared byte-wise after full composition — any drift fails packaging and
`--check`. Registry entries this round: Frostmere north cirque wall band,
east watchtower flank, volcano east cliff/cove band, road-join + corridor
west end, west caravan road band, caravan/stag corridors, fire3 box, flock
south sliver, both south-strand bands, Wanderer's Isles island land.

## Not confirmed from repo evidence (flagged)

Log bridge exact pixels (protected via the corridor rect); the western
standing stone (attested, not located — covered by the FC road band);
Millbridge as drawn geometry (in-core, protected regardless); island label
anchors' offset from their clusters (deliberate or drift — unresolved);
Wayfarer's Pass has no painted col structure to freeze. Layout `props` is
empty — no prop constraints exist.
