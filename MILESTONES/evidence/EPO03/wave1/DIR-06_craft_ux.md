# DIR-06 — Craft UX: the workshop and the recipe book

Read: BRIEF_CONTEXT §2; FMPO02 GOV-05 §5 (EPO03's not landed); `craft_screen.dart`, `station_strip.dart`; nine device captures. Zero generations.

**Locks.** Step cost untouched. Both call sites move verbatim — `CraftScope.read(context).start(recipe, count)`, `SessionScope.read(context).trackGoalPursuit(recipe.outputItem)`. No new recipes, economy or save change.

## TOP FAILURES

1. **The locked half is a ledger.** `_GateLine` prints "2 more at Smithing 2 / 1 more at Smithing 3…" grey on grey (`v3_craft_locked`): 22 locked recipes read as debt, not a road.
2. **Card-in-card-in-card.** A card round the strip, the folio, every tile band, and the sheet.
3. **The station is a picture in a box.** Selection is a brass border; nothing physically changes.
4. **Category and quantity share one text chip** (`_Chip`).
5. **Readiness has three grammars** — "1 more Herb", "2 materials short", "Needs Smithing 6 — you are 1".

## WHAT TO REPLACE

**1. Ground and rhythm.** One material: `grain_bench_oak` full-bleed. No `SectionCard` except the folio. Rhythm: station rail 96 dp → bench band 48 (existing) → category rail 44 → folio → unlocked tiles on one leaf → recipe book. Groups part by 1-px rules and 16-dp air, never borders.

**2. Station rail.** Three plates on a shared shelf. Unselected: `rail_plate_recessed` nine-patch, prop under `lockedScrim`, muted label. Selected: `rail_plate_raised` (lighter lip, shadow beneath), full-colour prop, and its bottom edge dissolves into the bench band — the band is the chosen station's counter. Census one line: "23 · 1 ready".

**3. Category rail.** Icon-led tabs on the band's lower edge: five 24² glyphs ×2 with `microLabel` beneath; selected = brass underline pin, no filled chip. "1 craftable · 10 known" sits at the rail's right end.

**4. Folio.** Keep `heroPlate`/`journalLeaf`, output 96 dp, name, `RarityBadge`, "Cooking 1 · +12 XP". Tray: `tray_well` nine-patch (oilcloth, stitched rim) with 56-dp slots; satisfied = full colour, count `textPrimary`; short = dimmed with a "−2" cartouche. Quantity: `_QuantityStepper` — brass `stepper_plate`, − / count / + / MAX, long-press repeats; replaces ×1/×5/×10. **One readiness grammar** (`_ReadinessLine`): `Ready ×N` (moss) · `Short by 2 Copper Ore` / `Short by 3 materials` (muted) · `Opens at Cooking 5` — book header only, never per row.

**5. Action and completion.** `StrideButton.ready` "Craft ×N" stays; the stepper presses in on commit (existing haptic + `AudioEvents.commit`). Live panel, bar and pulse unchanged. On the last repetition a `stamp_made` impression presses onto the output well (200 ms, reduce-motion aware) as the `ActivityResultCard` rises.

**6. Recipe book.** Per station-skill, **level bands of three** (1–3, 4–6, 7–9, 10), only bands above the player shown. Each band is a chapter:
- **Tier header** — `tier_header` (folded page edge with ribbon), skill glyph, "COOKING · LEVELS 4–6" in `cardTitle`, gate line "Opens at Cooking 4" right — once per chapter.
- **Sealed pages** — two-column leaves on `page_sealed` nine-patch with a `dogear`; output as an **ink silhouette** (`ColorFilter` over the 48² icon, zero art); `seal_<skill>` wax seal at 64 dp with the level in bitmap type; name in rarity ink at 70 %. Tap opens the sheet as now.
- **Next unlock** — the first chapter above the player is lit: full-value header, lifted dog-ears, warm seals, "N levels away". Later chapters recede: darker pages, cold seals, header 70 %.
- Contract-gated recipes: last chapter "Unwritten pages", `taught` seal.

**7. Pursuit.** "Track as Pursuit" becomes a `ribbon_pursuit` bookmark on the folio's top-right (and the sheet). Tap = the verbatim call; after a `GoalReport` the ribbon drops 4 dp and reads "Tracked" until the subject changes.

**9. Dart.** *Deleted:* `_CategoryChips`, `_Chip`, `_QueueChips`, `_LockedLedger`, `_GateLine`, `_locked()`. *New:* `_CategoryRail`, `_QuantityStepper`, `_ReadinessLine`, `_RecipeBook`, `_TierHeader`, `_SealedPage`, `_PursuitRibbon`, `_MadeStamp`; `StationStrip` re-skinned in place. *Consolidated:* `_HeroFolio` and `_RecipeDetail` share one `_RecipeFolioBody` hosting each call site once; fallback if the producer objects — skin both hosts, move nothing.

## WHAT TO KEEP

Station props, bench bands, grains, `chassis_64`, `btn_plate`, the `heroPlate` folio, `_TileFolio` with the moss rule, `_ActiveCraftPanel`, chain jump, `StrideSheet`, `ActivityResultHost`, `RewardRaise`, the readiness-band model.

## PRODUCTION FAMILY

| Asset | Canvas | Kind | Count | Tool | Unit / rolls |
|---|---|---|---|---|---|
| `rail_plate_raised/recessed` | 64² c16 b8 | nine-patch | 2 | pixen | 1 × ~4 |
| `cat_<all,materials,food,gear,tools>` | 24² | icon | 5 | pixen | 1 × ~4 |
| `tier_header` ×4 bands | 384×56 | picture ×1 | 4 | pixen | 1 × ~6 |
| `seal_<smithing,cooking,woodwork>` | 32² | icon ×2 | 3 | pixen | 1 × ~5 |
| `page_sealed` / `dogear` | 96² c24 b8 / 24² | nine-patch / icon | 2 | pixen | 1 × ~4 / ~3 |
| `tray_well` | 64² c16 b8 | nine-patch | 1 | pixen | 1 × ~4 |
| `stepper_plate` / `−` `+` | 32² c8 b4 / 16² | nine-patch / icons | 3 | pixen | 1 × ~4 / ~2 |
| `stamp_made` | 48² | icon | 1 | pixen | 1 × ~4 |
| `ribbon_pursuit` | 24×40 | icon | 1 | pixen | 1 × ~3 |
| `binding_gutter` | 24×64 p64 | vertical tile | 1 | pixen | 1 × ~4 |

23 assets. Style source: the bench bands and `grain_journal_leaf` by raw SHA URL; `ui-package.js` guards throughout.

## PIXELLAB BUDGET

Planned **97** rolls (all `create_image_pixen` at 1, GOV-04). Cap **112**. No pro, no edits.

## PHONE-SCALE SUCCESS CRITERIA

1. Top of tab to first recipe: one framed rectangle at most.
2. Selected station reads raised and continuous with the band at 393 wide, brass borders off.
3. No row reads "N more at Skill L"; "Opens at" once per chapter.
4. Silhouette, seal and level legible at 48 dp; the next chapter brighter than the one after.
5. Five category glyphs distinguishable at 24 dp unlabelled.
6. Stepper − / + hit 44 dp; count ≤ `craftableCount`.
7. Craft goldens regenerated after diff inspection; each call site greps once.

**UNRESOLVED:** chapter names beyond level ranges (Apprentice/Journeyman) are a systems call (G-3); ships with ranges only.
