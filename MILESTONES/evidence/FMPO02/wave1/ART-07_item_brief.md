# ART-07 — Item & Recipe Icon Brief (FMPO02 Wave 1)

STATUS: PROPOSED, not approved. Evidence: direct pixel inspection of all 58
`item.*` icons (48×48, hashed — no two are byte-identical today; GOV-03's
"byte-copy" note describes an earlier state), `assets/content/v1/recipes.json`
(39 entries), `items.json` (58 entries), `craft_screen.dart` line 593/1362
(`PixelIcons.itemFor(recipe.outputItem)` — the craft row **always** shows the
output item's icon; there is no recipe-specific icon path today).

**Finding that changes the brief's scope:** "Herb Broth vs Forager Broth" and
"Expedition Stew vs Expedition Pot" are not two items each — `recipe.forage_broth`
and `recipe.herb_broth_pair` both set `outputItem: item.herb_broth`;
`recipe.expedition_pot` sets `outputItem: item.expedition_stew`. Showing the same
icon on those recipe rows is **correct**, not a collision — they produce the
identical item. No new art is owed there.

## 1. Item verdict table (58 items)

| Item | Verdict | Reason |
|---|---|---|
| copper_ore | KEEP | orange-brown nodules in grey matrix vs tin's white facets — already separated (not hue-only) |
| tin_ore | KEEP | flat silver-grey crystalline, distinct silhouette from copper's rounded nodules |
| oak_log | KEEP | dark bark + tight rings vs pine's pale wood |
| pine_log | KEEP | see above |
| oak_plank | KEEP | reddish-brown grain vs pine's cream grain |
| pine_plank | KEEP | see above |
| oak_handle | KEEP | dowel shape reads distinct from both logs |
| meadow_herb | KEEP | leaf bundle |
| duskcap | KEEP | mushroom cluster |
| rime_blossom | KEEP | single blue flower |
| hollow_root | KEEP | gnarled claw-shaped root; watch list below |
| gloom_silk | KEEP | wrapped cocoon/thread bundle |
| herb_broth | KEEP | wooden bowl, pale green liquid |
| hearty_stew | RE-AUTHOR | currently a bowl+spoon, too close to herb_broth's vessel; owner's own vessel language (§2) puts this tier in an iron pot |
| expedition_stew | KEEP | already the hanging-cauldron register; top of the vessel progression |
| traveler_ration | KEEP (verify) | reads as a cloth bundle today, correctly; GOV-03 recorded an earlier byte-copy state — recheck provenance, no art change needed if current file matches this brief |
| duskcap_skewer | KEEP | mushrooms on a stick |
| frostbloom_tea | KEEP | cup + steam |
| training_sword | KEEP | plain steel blade |
| bronze_sword | KEEP | bronze blade, distinct hue from steel |
| bronze_longsword | KEEP | longer blade, cross-guard, bone pommel |
| fanghilt_sword | KEEP | white fang cross-guard is a strong enough tell against bronze_sword |
| training_axe | KEEP | steel head |
| bronze_axe | KEEP | bronze head |
| hornbound_bronze_axe | KEEP | visible horn wrap on the haft |
| goblin_toothed_axe | RE-AUTHOR | reads as a round toothed disc/fan, not an axe — silhouette fails to name itself |
| training_pickaxe | KEEP | steel head |
| bronze_pickaxe | KEEP | bronze head |
| reinforced_pickaxe | KEEP | riveted grey head |
| tinbraced_pickaxe | RE-AUTHOR | near-identical grey head/silhouette to reinforced_pickaxe — no tin-brace tell |
| hornpoint_pickaxe | KEEP | curved bone point is unmistakable |
| traveler_tunic | KEEP | simple brown vest |
| bronze_chestplate | KEEP | bronze rigid plate |
| scalewarmed_chestplate | KEEP | deep red scale texture reads at 48px, distinct from bronze |
| wolfhide_jerkin | KEEP | brown open-front fur vest |
| frostlined_jerkin | KEEP | white fur trim |
| tuskbound_jerkin | KEEP | green hooded jacket, unmistakable against the other jerkins |
| bearhide_coat | KEEP (anchor) | dark brown hooded coat — kept as the unmoved reference the other two coats are re-authored against |
| clawguard_coat | RE-AUTHOR | near-identical brown hooded silhouette+palette to bearhide_coat |
| frostwarden_coat | RE-AUTHOR | same collision as clawguard_coat, and its warm-brown tone contradicts its own frostGuard 3 stat and lynx/ram-wool ingredients |
| waywarden_tunic | KEEP | pale robe, unmistakable |
| bronze_ingot | KEEP as item art; see §3 for its reclaim-recipe overload | reads correctly as an ingot in isolation |
| wolf_pelt | KEEP | grey-brown spread pelt |
| lynx_pelt | RE-AUTHOR | same spread-pelt silhouette as wolf_pelt, separated only by a cooler grey hue — D-5 pattern the style spec explicitly forbids |
| bear_pelt | KEEP | dark brown, clearly heavier pelt |
| boar_hide | KEEP | leaf-shaped bristly hide, distinct shape |
| ram_wool | KEEP | fluffy cotton-ball cluster, distinct shape |
| boar_tusk | KEEP | single curved tusk |
| great_tusk | KEEP | tusk with visible leather/wood banding |
| ram_horn | KEEP | tan spiral horn |
| pristine_horn | RE-AUTHOR | same spiral-horn silhouette as ram_horn, separated only by tone — needs an ivory sheen/glint tell to earn its "rare" tier |
| pristine_wolf_fang | KEEP | single tooth shape, distinct from the horns |
| scrap_metal | KEEP | angular shard cluster |
| heat_scale | RE-AUTHOR | rendered pale blue — reads as ice, not heat, and drifts toward the L-16 reserved teal family; needs a warm red/orange re-author |
| ember_core | KEEP | glowing orange core matches its name |
| frost_claw | RE-AUTHOR | rendered warm brown — reads as a beast claw, not frost; contradicts its own frostGuard stat, needs a pale blue-white re-author |
| goblin_toolhead | KEEP | mossy salvaged-metal lump, adequate for a crafting component |
| hollow_sigil | KEEP | stone tablet with rune, quest-distinct |
| unknown.png | KEEP | deliberate blank slab, code-drawn by design |

**Not yet items — flag, do not author speculatively (`RULES.md` G-3):** the
brief asks that Oak/Pine/**Frostpine/Heartwood** logs and planks not collapse.
`items.json` has no `frostpine_log`/`heartwood_log`/matching planks — only the
gather-node vignettes (`frostpine_stand`, `oldgrowth_frostpine`, `heartwood_oak`)
exist. Whether these become real craftable materials is a Systems Designer
decision, not an art one. **UNRESOLVED — recorded to
`JOURNAL/OPEN_QUESTIONS.md`.** §2 below gives the wood-family language now so
authoring won't collide *when* they land.

## 2. Family design language

- **Ores**: copper = warm orange-brown rounded nodules studding a grey matrix; tin = flat silver-grey crystalline facets with a cool blue-white glint. Never emissive (D-2).
- **Logs/planks**: separate by bark colour + end-grain ring colour + one small species tell (a leaf pinned to the bark). Oak = dark red-brown bark, tight rings. Pine = pale tan bark, wide rings. **Reserved for when authored:** Frostpine = grey-blue bark, frost-rimed rings, needle sprig. Heartwood = deep amber-red bark, dense dark rings, oak-leaf sprig oversized to read "old growth."
- **Herbs/materials**: silhouette-first — bundle (herb), cap cluster (mushroom), single bloom (flower), gnarled claw (root), wrapped cocoon (silk). Never rely on hue alone between two of these.
- **Foods, by vessel** (the owner's own spec, now enforced): broth = wooden bowl; hearty stew = iron pot (mid tier); expedition stew = hanging cauldron (top tier); ration = cloth bundle; skewer = stick; tea = cup + steam. Vessel escalates with tier so rarity reads before the player parses colour.
- **Weapons**: blade metal (steel/bronze/gold-bronze) + one hilt tell per named variant (bone fang, cross-guard size). Never change blade silhouette alone.
- **Tools (axes/picks)**: head material + one bound-on material tell (horn wrap, tin bands, bone point) placed at the same head location every time so the eye learns where to look.
- **Armor**: category first (rigid chestplate / open jerkin / full hooded coat) — already well separated. Within a category, one material tell each: scale texture, fur trim colour, claw-guard shoulder pieces, banding. **A coat family needs three genuinely different tells, not one tell repeated in three colours.**
- **Pelts/horns**: pattern, not just hue — a spot pattern, ear shape, or banding that survives a greyscale check. If it disappears in greyscale, it's a D-5 violation.

## 3. Reclaim recipes — the process-vs-output decision

**Recommend: a recipe-level "salvage" icon, not the output item's icon.**
`stride_session.dart` already treats reclaim recipes as conceptually distinct
(both-ends-equipment crafts are carved out of the lineage graph "because
reclaims surface through the bench's trade lines instead") — the art should
match that existing model, not fight it.

**Art**: a plain wooden crate, lid ajar, with a pale (≈35% opacity, flat single
tone, no internal detail) ghost silhouette of the *specific* reclaimed item
stamped on the lid — axe silhouette for `reclaim_bronze_axe`, pick for
`reclaim_bronze_pickaxe`, chestplate for `reclaim_bronze_chestplate`. Reads as
"salvage this" at a glance, independent from `item.bronze_ingot`'s own icon
(which stays a plain ingot everywhere it is the literal output, e.g. the bronze
recipes' ingredient row).

**Implementation is not this brief's job**: it needs a small
`PixelIcons.recipeIconFor(recipe)` path in `craft_screen.dart` that special-cases
reclaim-class recipes ahead of the `itemFor(outputItem)` fallback — flagged to
Technical Director.

## 4. Prompt structures (append §7.2's style clause verbatim to every one)

- **Ore**: "`<metal>` ore laid flat, seen from directly above: an irregular grey stone matrix with `<N>` `<shape>` `<colour>` mineral inclusions breaking the surface, no two inclusions the same size —"
- **Log/plank**: "a cut `<species>` `<log|plank>`, laid flat, end-grain facing the viewer on one visible cut end: `<bark colour>` bark, `<ring colour>` growth rings, `<one species leaf>` resting against the wood —"
- **Food vessel**: "`<dish name>` presented in a `<wooden bowl|iron pot|hanging cauldron|cloth bundle>`, seen from above at a slight tilt so the vessel rim and the contents both read, contents `<colour, chunky/smooth>` —"
- **Weapon**: "a `<metal>` `<weapon>`, standing upright at a slight diagonal: one straight `<hilt material>` grip, a `<guard shape>` cross-guard, a `<blade length>` blade tapering to a point, `<one hilt tell: fang/bone/plain>` —"
- **Tool head**: "a `<metal>` `<axe|pick>` head socketed to one long straight wooden haft passing visibly through the head's centre, `<bound-on tell: horn wrap/tin bands/bone point>` fixed at the head-to-haft joint —"
- **Armor**: "a `<garment class>` standing upright, front-on: `<primary material>` construction, `<one distinguishing tell>` at the shoulder/collar, `<hem shape>` —"
- **Reclaim crate**: "a plain wooden crate seen from above, lid open at an angle, a faint pale `<item silhouette>` stamped flat on the inside of the lid, no colour in the stamp beyond a single light tone —"

## 5. Generation estimate

Evidence-based, not the full 58 — per `RULES.md` G-1/M-01, a blind full-catalog
reroll is disproportionate when 47 of 58 items already pass, and PROOF_03 §11
warns a full reroll can break what already works.

| Tier | Items | Candidates | Gens |
|---|---|---|---|
| RE-AUTHOR (confirmed collision/palette defect) | hearty_stew, goblin_toothed_axe, tinbraced_pickaxe, clawguard_coat, frostwarden_coat, lynx_pelt, pristine_horn, heat_scale, frost_claw (9) | 4 | 36 |
| NEW (reclaim salvage crates, §3) | 3 | 4 | 12 |
| Verify-only (borderline, 1 confirmatory candidate) | scalewarmed_chestplate, bronze_longsword, fanghilt_sword, wolf_pelt, hollow_root, ram_horn (recheck after pristine_horn edit), reinforced_pickaxe (recheck after tinbraced edit), bearhide_coat (recheck after the other two coats move) | 2 | 16 |
| **Total (recommended)** | | | **≈64** |

This is well under the ~350 a full-catalog sweep would cost. If the owner wants
a defensive margin beyond the 12 flagged items regardless, the remaining 46 KEEP
items at 1 confirmatory candidate each would add ~46 gens (≈110 total) — offered
as an option, not the recommendation.

## 6. QA rule — pairwise perceptual-collision gate

Extend the existing guard family (`Scripts/art/check-art-palette.js` pattern) with
`check-item-distinctness.js`, run over every same-family pair named in §1/§2:

1. Crop each icon to its opaque bounding box, centre on the alpha centroid.
2. **Silhouette IoU** on the binary alpha mask, aligned. **Flag if IoU > 0.55.**
3. **Colour-histogram distance**: 16 bins/channel, normalized histogram
   intersection over the opaque pixels only. **Flag if intersection > 0.6**
   (i.e., colour alone is doing more separating work than shape).
4. **Greyscale check**: desaturate both crops; re-run IoU. If greyscale IoU is
   within 0.05 of colour IoU while colour intersection is high, the pair is
   separated by hue alone — the exact D-5 failure mode. **Auto-fail.**
5. A pair failing both 2 and 3 is a collision regardless of item names; a pair
   failing only 4 still requires a pattern/shape tell, not a bigger colour gap.
6. Run after every RE-AUTHOR/NEW candidate lands, against every same-family
   sibling — not just the edited item (PROOF_03 §11's "re-review the entire
   family" narrowed to *the affected family*, not all 58).
