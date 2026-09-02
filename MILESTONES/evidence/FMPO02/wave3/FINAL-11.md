# FINAL-11 — did the PixelLab spend produce value?

Read: council context, `GENERATION_LEDGER.md`, all nine `ledger/*.md`, all nine `wave2/*_report.md`, milestone §5/§6, and the shipped tree at HEAD (`abc0305`). Counts are from the files and the Dart tables, not the reports.

1. **BLOCKER — the spend does not reconcile, and the un-reconciled family is Equipment.** Milestone §5's table sums **2,238** against its stated **1,596**; `GENERATION_LEDGER.md`'s closing row itemises **2,076** against its stated **1,465**. Eight families summed per job and said so; Equipment alone used the shared-account delta (9,551→8,642 = 909) as its own spend — the exact error its own ledger warns the others against. By subtraction Equipment's true total is ≈**508** (wave 2 ≈377), i.e. **≈44 gens per 80×64 `create_character_state`, not ~120**. *Fix:* correct `ledger/EQUIPMENT.md`, `wave2/EQUIPMENT_report.md` and milestone §5 by subtraction, and strike the "price an 80×64 state at ~120" rule before it misprices the next round.

2. **should-fix — the round's largest scoping cut was made on that phantom.** The steel tool column was cancelled at the 709 checkpoint as unaffordable (~720 gens), then closed at closeout for **~120 gens of text-edit recolours** on the accepted bronze strips (`abc0305`), plus 60 gens of edits that fixed the three loops the same lead had called "not shippable as they stand". *Fix:* add to `wave2/PRODUCTION_RULES.md` — a tier variant is an edit on an accepted strip, never a new state; and after two failures in one mode, change tool, not seed.

3. **note — the brief is one commit stale.** It pins `9e555d3`, ≈1,465, 41 renders; HEAD is `abc0305`, ≈1,596, 44 renders, with the steel column, three armoured busts and the tool gaps closed. Judge at HEAD.

## Value per generation

4. **note — best value, by a wide margin.** Enemies **43** gens → 5 habitat plates (all five live: `EncounterHabitat.enabled` holds every slug), 4 hit tracks, a crawler defeat, 4 elites × 2 tracks — and all four elite ids exist in `enemies.json`/`contracts.json`, so none of it is unreachable. Rewards **21** gens → 4 assets, all wired (`RewardArt` → `activity_result.dart`, `combat_screen.dart`, `craft_screen.dart`), and two briefed assets resolved with **zero** generations. World life **60** gens → 40 overlays + 6 props, all in `atlas_layout.json`. Three families, **124 gens (8% of spend)**, carry most of the round's newly visible content.

5. **should-fix — worst value: Gather, 180 gens for 7 files.** 33 pixflux rolls and 8 img2img rolls repeated the *identical* defect (dressed stone + a lit doorway) before `create_image_pro` cleared all three mine backdrops on the first roll at 40 each. ≈41 gens of thrash against a wall one tool change broke instantly. Fold into finding 2's rule.

6. **note — Terrain is 475 gens (30% of the round) into one file.** 160 are rejects; N3 alone burned 120 across three rolls to keep one. The nine regions are real value and the guards held, but this is the least verifiable line generation-for-generation, and N3 above y 90 still carries the old crack net.

7. **should-fix — UI's dead weight.** 95 gens → 25 files in `assets/ui/v1`, but **five of eleven surface tiles are registered and painted nowhere**: `PanelSurface.slate`, `.steel`, `.benchOak`, `.chartVellum`, `.planLinen` have zero use sites outside `lib/ui/components/panel_skin.dart`. A further ≈28 gens went to lines that shipped nothing (modal_128 ×13, strap_corner, corner_mark, tab_index, tack, nav_plate, banked_cartouche). *Fix:* give the five tiles their briefed panels this round or delete the rows — a registry entry nothing paints is the next integrator's trap.

## Packaged but unwired — checked in code, not in the reports

8. **note — the honest ones.** `narration_strip.png` is packaged and refused on a measured 2.90:1 against `textPrimary`, with the figure held by a guard test (`combat_assets.dart`, `combat_screen.dart`) — correct call, 1 gen. `ram2_idle` ships as a candidate and `Scripts/art/package-art.js:3136` says so in its own words. Both are cheap and both are recorded; leave them.

9. **should-fix — the ones the record gets wrong.** `band_combat_kit` sits in `BandPlates.authored` with **no `StrideBand.combatKit` use site anywhere** — the one band of ten that never reaches a screen. `bg_workbench`, the 11 nav glyph candidates and the rule caps never entered `assets/` at all (they are `out/ui/` only), so milestone §5 crediting "workbench" among UI's *accepted assets* overstates the delivery. *Fix:* wire `combatKit` to the combat command block or drop the row; correct §5's UI row to "10 tiles, 10 bands, 2 plates, welt, shelf" and move workbench/glyphs/caps to §6.

10. **note — stale comment.** `lib/ui/icons/encounter_habitat.dart` still carries "[enabled] is **empty** … why nothing renders yet" directly above a set that enables all five plates. Delete the paragraph; it sends the next reader hunting a switch that is already on.

## Accepted families that should improve before closeout

11. **should-fix.** (a) `habitat_cave_shadow` — its own producer says it reads as a wall, not a floor, after three same-tool rerolls (Q-23); one `create_image_pro` roll (~40) is the untried lever. (b) `grain_chart_vellum` ships knowingly **without grain** (99.4% one ink) — hue only. (c) Equipment's four UNRESOLVED items were never revisited: coat-hood drift across the coat class, `coat_steel/attack`'s non-cut, `plate_pick`'s over-saturated bronze against the new four, and its 69-row union box still flagged DEFECT. (d) `nav_world_hi` has no legal variant, so the nav family is short by one.

## The shortfall: ≈1,596 of a 2,000–3,000 target

12. **should-fix — roughly 70% discipline, 30% missed opportunity, and the missed part is one habit.** The discipline is real and measurable: Rewards spent 0 on two assets by reasoning them away; Items cancelled 12 planned generations after a free pixel inspection showed three premises stale; Terrain deferred S3/S4 without a roll because it measured the keepouts first. That is judgement, not thrift. **But the shortfall is not saved money** — the cycle resets 2026-10-01, so ~8,166 generations expire in 29 days and carry nothing forward. Every batch "recorded and left after two failures" was left *on the same tool*, and this round proved twice (Gather's `pro` switch, the closure's text-edit recolours) that the tool change is what breaks those walls. Specifically affordable and not done: the modal/frame/tab/ornament family retried on `pro` or `pixen` (~120 — the only family that produced literally nothing); `cave_shadow` on `pro` (~40); `chart_vellum` and `cork` re-authored on a tool that can hold grain (~40); `nav_world_hi` (~10); the four Equipment UNRESOLVED edits (~130). ≈**340 generations** would have landed near 1,950 and closed every named craft gap in §6 except the owner-blocked ones. The round underspent by stopping one lever short, not by restraint.

**Verdict: PASS with conditions — the spend bought real, mostly-wired value at excellent ratios in Enemies, Rewards and World life, but the ledger is wrong by ~640 generations in one family, that wrong number drove the round's biggest cut, and the shortfall is a habit (two failures → stop) rather than a budget. Fix findings 1, 2, 7 and 9 before closeout.**
