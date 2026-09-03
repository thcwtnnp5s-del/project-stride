# EPO03 — PROD-UI-CRAFT report

Branch `fable5-executive-production-overhaul-03`. Design `wave1/DIR-06`.
Ledger `GAME_BIBLE/ART/exploration/EPO03/ledger/UI_CRAFT.md`.
Renders `GAME_BIBLE/ART/exploration/EPO03/review/device/craft/`.

The owner's verdict this answers: Craft "is improved but still not premium
enough", and its lower half "must not devolve into '1 more at Cooking 5 / 1
more at Cooking 6'. Locked content should feel like progression, not
spreadsheet rows."

## What shipped

**The page.** `craft_screen.dart` is now a `PageGround(surface: benchOak)` —
one full-bleed material, no card at the tab root. The `SectionCard` that used
to wrap the station strip is gone, so the top of the tab is a workshop rather
than a rectangle holding three rectangles.

**The station rail** (`station_strip.dart`, rebuilt). Three plinths standing
on one shared shelf (`KitTile.railShelf`), each a `KitFrame.slotWell` plate —
**recessed** when unchosen, **raised** (the kit's lit lip) when chosen, prop
under `lockedScrim` either way. Names and a one-line census engraved on the
bench beneath the shelf. Selection is now a physical state, not a brass
border; the brass border is gone.

**The category rail** (`_CategoryRail`, replacing `_CategoryChips`/`_Chip`).
Five glyph-led tabs with a written label and a 2 dp brass underline pin. No
fill, no border, no pill. `1 craftable · 10 known` sits at its right end.

**One readiness grammar** (`_readinessLine`). `Ready ×N` / `Short by 2 Copper
Ore` / `Short by 3 materials` / `Opens at Cooking 5` / `Not written yet`, used
by the folio, every tile and the book. The three old grammars are deleted.
`_craftReason` is deliberately untouched — it is the disabled *action*'s
explanation, it names every short material rather than the first, and two
other test files and one other screen read it word for word.

**The quantity stepper** (`_QuantityStepper`, replacing `_QueueChips`).
− / ×N / + / MAX on `KitFrame.btnPlateV2` plates, 44 dp hit targets, keys sink
on press, hold repeats at 140 ms, clamped to `craftableCount`. It can say ×3;
`×1/×5/×10` could not.

**The pursuit ribbon** (`_PursuitRibbon`, replacing two full-width
`StrideButton.secondary`s). A bookmark on the folio's and the sheet's top
edge; drops 4 dp and reads "Tracked" after the `GoalReport`. One primary
action per screen again.

**The made stamp** (`_MadeStamp`). A 200 ms ink impression pressed onto the
output well as each completion's `ActivityResultCard` rises; Reduce Motion
holds it still rather than removing it.

**The recipe book** (`_RecipeBook`, `_Chapter`, `_TierHeader`, `_SealedPage`,
`_WaxSeal`), replacing `_LockedLedger` and `_GateLine` — the item the owner
named. Locked recipes group by trade into level bands of three. Each band is a
chapter opening with `KitMark.ruleOrnateA`, `SMITHING · LEVELS 4–6`, and its
gate — **`Opens at Smithing 4`, once, in the header**. Every locked recipe is
a sealed page on `KitFrame.pageSealed`: the output as an **ink silhouette**
(`ColorFilter` over the icon that already ships — zero new art), a wax seal
with the required level set over it, the name in rarity ink, a dog-ear folded
off the corner. The first chapter above the player is lit; the ones behind it
recede to 62 %. Contract-gated recipes close the book as `UNWRITTEN PAGES`.
**No row states a gate**, and `craft_planner_test.dart` now asserts that
(`expect(find.textContaining('more at Smithing'), findsNothing)`).

**Assets** — 7, `assets/art/v1/ui/craft_*.png`, registered through the new
`lib/ui/screens/craft/craft_art.dart` (a `TrackArt`-shaped registry: an
unlanded row is null, the widget paints its fallback, the figure is reserved
either way) and emitted by a new `EPO03 UI-CRAFT` block in `package-art.js`:
`craft_cat_all`, `craft_cat_materials`, `craft_cat_food`, `craft_cat_gear`,
`craft_cat_tools`, `craft_seal_blank`, `craft_stamp_made`.

## Cost

**15 generations of a 112 cap.** 7 accepted, 8 rejected with written reasons
and contact sheets (`review/craft/marks_r1.png`, `marks_r2.png`). Per-roll
verdicts and the two findings worth keeping — why four good per-trade seals
were the wrong asset, and why roughly 60 of the brief's planned rolls were
never needed — are in the ledger.

## What the phone shows that it could not before

`review/device/craft/`: `v3_craft_overview.png`, `v3_craft_ready.png`,
`v3_craft_book.png` (the lit chapter), `v3_craft_book_deep.png` (the receded
chapters and the unwritten pages), `v3_craft_sourcing.png`,
`v3_craft_locked.png` (the sheet off a sealed page), `v3_craft_chain.png`,
`v3_craft_prover.png`, `craft_gear_open.png`,
`gfcp_craft_minor_beat.png` and `gfcp_batch_craft_summary.png` (the stamp on
the well under a completion).

Read at 393 × 852: the lower half is a book of wax-sealed pages whose levels
are stamped into the seals, not a column of grey sentences differing by one
numeral. Top of tab to first recipe is one framed rectangle (the folio). The
chosen station is raised and continuous with its bench band. Five category
glyphs are distinguishable at 48 dp.

## Locks

Untouched: crafting step cost, every recipe, the queue, the economy, the save.
Both session call sites move verbatim and appear exactly once each —
`CraftScope.read(context).start(recipe, count)` in `_HeroFolio` and
`_RecipeDetail`, `SessionScope.read(context).trackGoalPursuit(...)` in
`_PursuitRibbon`. No new recipes or content.

## Tests

`flutter analyze` clean on `lib/ui/screens/craft/`,
`lib/ui/components/station_strip.dart`, `test/craft_planner_test.dart`,
`test/screen_evidence_test.dart`. `flutter test craft_flow_test
craft_planner_test craft_significance_test craft_stage_evidence_test` — 34
passed. `phase1_ui_test` craft assertions pass unchanged.

`craft_planner_test.dart` was rewritten where it asserted the *deleted*
structure — the two-line plinth census, the `LOCKED` heading, and the gate
line the book replaces. It asserts more than it did: the chapter header, one
gate per chapter, four chapters, and that no row states a level. The craft
block of `screen_evidence_test.dart` walks the book instead of a ledger.

**Goldens are stale and were not regenerated** (the producer regenerates after
inspection): any golden covering the Craft tab — the station strip's census
line, the category rail, the folio's readiness line and stepper, and every
locked row — has legitimately changed.

## What did not close

- **The dog-ear and the pursuit ribbon ship painted, not drawn.** Both read
  correctly at phone scale; neither was generated. Named, not softened: two of
  `DIR-06`'s 23 planned assets are Flutter geometry.
- **The ingredient tray is `SurfaceBlock`, not a `tray_well` nine-patch.**
  No kit row exists for an oilcloth tray and I did not author one; the slots
  are `KitFrame.slotWell` plates with a `−N` shortfall cartouche, which is the
  part of §4 that carried the information.
- **`_HeroFolio` and `_RecipeDetail` were not consolidated** into one
  `_RecipeFolioBody`. `DIR-06` §9 names skinning both hosts as the sanctioned
  fallback and that is what shipped: the folio and the sheet still hold one
  `start(...)` call site each, and merging them is a refactor with its own
  device read rather than a free by-product of this one.
- **`node Scripts/art/package-art.js --check` reports one stale file**,
  `assets/art/v1/item/frostwarden_coat.png`. It is not mine — a concurrent
  producer is mid-change on its source — and my own seven files are clean
  under `--check` and under `check-art-palette.js` (2,370 PNGs ok).
- **Chapter naming is UNRESOLVED and shipped with ranges only**, recorded as
  **Q-29** in `JOURNAL/OPEN_QUESTIONS.md` (G-3). Naming crafting tiers is a
  systems and fiction call with consequences for the Skills journey and
  contract text; it costs one string here whenever it is made.

## Requests filed

None. Every shared-kit row this screen needed had already landed
(`slotWell`, `railShelf`, `pageSealed`, `ruleOrnateA`, `btnPlateV2`), which is
why the family cost 15 generations instead of the planned 97.
