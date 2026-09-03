# EPO03 — PROD-UI-INVENTORY report

Team `inventory`. Cap **60 generations**. **Spent: 0.** Branch
`fable5-executive-production-overhaul-03`.

---

## What shipped

**The screen is the thing it is named after.** It was three dark rectangles on
a black page — a card holding the figure and three plates reading `TOOL` /
`Empty` in boxes, then one big card holding two grids of smaller dark cards
with an Equip button bar under each. There is now no card on the screen.

| Dart | What changed |
|---|---|
| `lib/ui/screens/inventory/inventory_screen.dart` | rebuilt. `PageGround(leather)` is the case; the pack is a second `PageGround(oilcloth)` below a `caseStrap` seam — the one screen `DIR-05`'s table gives two materials. `GridView` and its 40 lines of `mainAxisExtent` arithmetic are **deleted**; the pack is rows of pockets, each row ruled. `SectionCard`, `SurfaceBlock` and every rounded fill are gone from the file. |
| `lib/ui/components/loadout_readout.dart` | `SlotPlate` is a **well cut into the leather** (`KitFrame.slotWell`) with the worn piece seated in it; empty draws the slot's **class shadow** and no word. New `ClassShadow`; new `_StatStamp`. `DressingChip` takes the same well. |
| `lib/ui/components/gear_stats.dart` | `GearStatsBlock` loses its `surfaceBlock` fill and radius and gains a rule — it now sits on whatever page opened it (the pack's canvas, the bench's folio). New `GearStatLine.labelOf` / `figureOf` / `noteOf` split the same projection into a stamped label, numeral and comparison. |

**Kit rows consumed, all landed, all free:** `KitFrame.insetWell` (the figure's
window, inset 15), `KitFrame.slotWell` (every well in the case and every
pocket, inset 8), `KitTile.ruleChart`, `PanelSurface.leather`,
`PanelSurface.oilcloth`. The brief was right that the kit already had this —
Craft shipped on 15 of 112 and World on 0 of 60 for the same reason.

**Assets authored: none.** No `package-art.js` block, no build lock taken, no
`assets/art/v1/ui/` file. The one new mark on the screen — the class shadow —
is a deterministic recolour of a shipped item sprite (`RULES.md` A-2), so it
cannot drift from the item set and cost nothing.

### Proof

Four renders, `GAME_BIBLE/ART/exploration/EPO03/review/device/inventory/`,
each Read at 393 × 852 DPR 1:

- `inv_01_new_game.png` — three wells standing empty with their class shadows;
  `Empty` appears nowhere on the screen (asserted, not just looked at).
- `inv_02_case_worn_tool_empty.png` — a forged Bronze Sword and the tunic
  seated in their wells, `ATK 9` and `DEF 2` **stamped** beside them, the
  **tool well empty**, 262 items in the pack below.
- `inv_03_pack_ruled_rows.png` — canvas pockets ruled in rows, materials five
  across, gear three across, Equip/Unequip a small plate on the pocket.
- `inv_04_gear_open.png` — a gear pocket opened, its evaluation ruled on the
  canvas with no dark block under it.

The evidence session is **played, not granted**: it banks a long walk, travels
to Stonefall Mine, mines and smelts 78 bronze ingots, fells 113 oak at the
Whispering Woods, turns a handle and forges the sword, then forages home.

### Tests

- `test/inventory_equip_test.dart` — **10/10.** Two finders updated for the new
  tree, neither weakened: the pack scope is now the published
  `inventoryPackKey` instead of `find.byType(GridView)` (a private widget type
  is not a finder), and the three `find.text('Empty')` counts became
  `emptyWells()`, which asks the `SlotPlate`s what they are showing — a
  stronger question than the string, plus a new
  `expect(find.text(kEmptySlotWord), findsNothing)` that locks the design.
- `test/gear_stats_test.dart` — **7/7**, untouched.
- `test/screen_evidence_test.dart` — my block passes; 19 of 21 pass overall.
- `flutter analyze` on all five files — **clean.** No `--update-goldens` run.

---

## What did not close

**The "plate + longsword" render is a Bronze Sword and a Traveler Tunic, and
that is a reachability limit, not a softening.** Measured against the real
content pack: the Bronze Chestplate needs a Pine Plank from **Frostmere**,
which has **no route out of Haven's Rest** in a fresh save; the Bronze
Longsword needs a Boar Tusk (a **35 % drop**) and Gloom Silk from the
**Forgotten Hollow**, whose entry requires a Bronze Sword; the Wolfhide Jerkin
is **taught by a contract**. Each was driven and failed, in that order. The
render proves what the brief wanted it to prove — a crafted, non-starting,
uncommon weapon seated in its well beside a worn armour, an empty tool well,
and the figure drawn by whatever `TravelerArt.figureFor` returns. **Nothing in
this screen narrows the resolver**: it still passes `equipmentVisualState`
straight through at a whole ×2 with no allow-list, so the Waywarden body and
the longsword appear here the day a save reaches them. If the producer wants
that exact render, the cheapest route is a seeded save fixture, which is a
harness change and belongs to whoever owns `test/support/`.

**`DIR-05`'s "no Equip until a tap" is not implemented.** The brief asked for
the control as "a small plate on the pocket rather than a button bar under a
card", which is what shipped; hiding it until a tap is a separate disclosure
change that makes equipping two taps and moves four other tests. Flagged, not
done.

**`KitTile.pocketRule` is not what rules the pockets.** The row never landed
and its `separator` fallback vanished into the oilcloth in the first device
render. The rows use `KitTile.ruleChart` — landed, and already the pack's own
rule. Recorded in the ledger with the loud-colour proof render that showed the
geometry was right before the colour was blamed.

## REQUESTS filed

**`REQUESTS_NAV.md`, 2026-09-03 — `EdgeStrip` ignores the axis. Blocking, for
everyone.** `EdgeStrip.build` hard-codes `width: double.infinity` whatever the
axis, and `KitEdge` hands the landed path no axis at all. `KitTile.edgeSpine`
landed in `80463ee` and `adventure_screen.dart` draws it in a
`Positioned(left/top/bottom)`, so the Adventure tab throws
`BoxConstraints forces an infinite width` once per layout — and because the
shell keeps every tab alive, **any** widget test that mounts `StrideApp`
collects hundreds of them and fails on "unexpected exceptions". Confirmed on
`test/gather_queue_ui_test.dart` (3 of 3 failing) with no Adventure code in it.
Not caused by this work and not worked around; the fix is four lines in two NAV
files.

## Neighbour failures seen, not mine

For the producer's triage, all reproduced with no Inventory code in the path:
`screen_evidence_test` "Iteration 02" (`Foraging XP` missing — Skills),
"Game Feel & Character Presentation 01" (`Herb Broth ×1` missing — the reward
card), `ui_responsive_test` ×3 (`SMITHING · LEVELS 1–3` clipping — Craft's
chapter headings), `rarity_ui_test` (`unarmed` missing — the Character sheet's
combat card). The working tree was also mid-edit on `encounter_card.dart` and
`reward_beat.dart` through several run attempts.

## Q- raised

None. No unresolved design decision was inferred.
