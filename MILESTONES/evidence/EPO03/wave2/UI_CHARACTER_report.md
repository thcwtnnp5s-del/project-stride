# EPO03 — PROD-UI-CHARACTER report

**Cap 50. Spent 0.** Requested 0 / accepted 0 / rejected 0.

## What shipped

**The Character tab is a folio.** It was six dark rounded rectangles in a
column — portrait, figures, steps, skills, combat, audio, playtest. It is now
one `journalLeaf` page, bound at the left, with **no `SectionCard` anywhere on
it**. The old `_DressingStrip`, `_CombatBlock` and `_Rule` widgets were
deleted outright rather than restyled, which is what Craft and Skill detail
did before it.

| Leaf | What it is now |
|---|---|
| the dressing space | the bust in a `KitFrame.insetWell` window, the three worn pieces in `KitFrame.slotWell` **margin wells** at the page's outer edge, and each piece *named once* on a ruled line under them in its rank ink with its rank ribbon |
| the title | `Traveler` over `KitMark.ruleOrnateA`, with `LEVEL` and `SKILL LEVELS` as two stamped figures beneath |
| the walking figures | a **ruled vellum ledger** — `LedgerRow`s divided by `KitTile.ruleJournal`, numerals tabular and right-stamped, teal on step figures and nowhere else |
| steps and sync | the ledger's **foot**: one freshness line under the ledger's closing rule, and the Step Tracker as a `KitFrame.tabPlate` **index tab** instead of a button in a box |
| skills | **chapter lines** — the skill's plate in the margin rail, the name in its own ink, the level, a 4 dp progress rule flush to the line's foot |
| combat | ledger lines under a `KitRule`. The worn pieces are **no longer named a second time** here; that duplication was the screen answering "what am I wearing" in two places |
| sound & feel, playtest | **footnotes** — a `KitRule` title and lines on the page's ground |

**The Step Tracker joins the same book** (`step_tracker_screen.dart`): a bound
`journalLeaf` `PageGround`, sections opened by a `KitRule` rather than boxed
in four `SectionCard`s, and Day / Week as two folio **index tabs** rather than
two grey pills (`DIR-05` failure 3).

**The locks held.** `step_tracker_screen.dart`'s `syncSteps` closure and
`playtest_block.dart`'s `_go` / `resetPlaytest` call are byte-identical; the
playtest confirmation keeps its `SurfaceBlock` and its two-step shape, because
the guard on a destructive command being a raised block *is* the guard being
visible. No save, health, economy or content change. Reserved teal appears on
step figures only.

**The bust is not narrowed.** It calls
`TravelerArt.portraitFor(s.equipmentVisualState)` and falls through to the
base portrait, so PROD-EQUIPMENT's fifth body and every body after it render
without a call-site change.

Files: `character_screen.dart`, `steps_block.dart`, `audio_block.dart`,
`playtest_block.dart`, `step_tracker_screen.dart`. Commits `bd06dc2`,
`80e1d48`, `76b185b`. `flutter analyze` on all five: **clean**.

## Generations: none, and why

`0 of 50`. The kit already held the folio window, the margin wells, the ornate
rule, the journal ruling and the spine — six landed `KIT_CONTRACT` §8 rows,
none of them Character-specific. The per-row reasoning and geometry are in
`GAME_BIBLE/ART/exploration/EPO03/ledger/UI_CHARACTER.md`. Nothing on this
screen is waiting on art; the one thing it would want — the bust in more
armour classes — is `TravelerArt`'s table and PROD-EQUIPMENT's to fill.

## Tests

- `flutter analyze` on all five files: **clean** (and on `lib` as a whole,
  clean at the moment it was run).
- `flutter test test/screen_evidence_test.dart`: **9 pass, 2 fail** — both
  failures are gather/craft result text (`Foraging XP`, `Herb Broth ×1`) with
  no `screens/character` file in either stack. The Character captures are
  produced by the run.
- `flutter test test/phase1_ui_test.dart`: **1 failure**, `the gather control
  one tap spends exactly one cost` — the same gather-result regression
  (`Meadow Herb ×1` not found), again with no character file in the stack.
  For scale: at `3535ebf`, before this work, the same file failed **25** of
  its tests.
- `--update-goldens` was not run. Goldens covering the Character tab
  legitimately change and are the producer's to regenerate after inspection.

## Renders (read at phone scale, 393 × 852 @ DPR 1)

`GAME_BIBLE/ART/exploration/EPO03/review/device/character/`. Two are the
shared harness's own, and are the canonical proof:

- `character.png` — the folio at level 1, training sword and traveller tunic
- `character_playtest_confirm.png` — the destructive command's guard, unchanged

Three more cover states the shared harness does not drive:

- `character_folio_plate.png` — a played save, two occupied wells with rank
  ribbons and one empty well showing its class shadow
- `character_folio_foot.png` — the combat ledger and the two footnotes
- `character_step_tracker.png` — the tracker as a leaf of the same folio

## What the phone shows that it could not before

Zero rounded dark rectangles on the tab, above the fold or below it. A bound
page with a visible binding. A portrait that is an object in a window rather
than a picture in a card, with the gear it depicts standing in the margin
beside it. Figures on ruled lines instead of in filled blocks. A door out of
the ledger that looks like an index tab rather than a control competing with
the sync button. And the Step Tracker behind it is recognisably the same book
rather than a different app.

## What did not close

- **`EdgeStrip` has no `axis`, so `PageGround(spine: true)` is unusable.**
  `KitTile.edgeSpine` is vertical and `KitEdge` cannot pass an axis, so a
  spine positioned with three edges and no width asserts `BoxConstraints
  forces an infinite width` on every test that mounts the app. The request was
  already filed by UI-INVENTORY and seconded by UI-ADVENTURE
  (`REQUESTS_NAV.md`, 2026-09-03); this team **took Adventure's resolution
  rather than inventing a third** — `spine: false`, binding drawn at the
  registry's declared 32 dp in the kit's own fallback register. Both files
  carry the comment. The swap back is one widget and reflows nothing. **No new
  request filed** — a third identical block would not help NAV.
- **Both proof files were blocked for most of this session by other teams, and
  three failures remain that are not this screen's.** For several hours
  `inventory_screen.dart` threw `PixelAsset was given less room than its
  sprite needs` (48.0 wanted, 47.4 offered) on mount, killing every test in
  both files at the first tap after the app was up; that was proved
  pre-existing in a detached worktree at `3535ebf` (25 phase1 failures there,
  23 with this work, the sets differing only in that two baseline failures now
  *pass*). Inventory has since fixed it, and the numbers in **Tests** above are
  from after that. The three remaining failures are one gather-result
  regression showing up in three places, and no `screens/character` file
  appears in any of their stacks. `lib` also failed to compile three separate
  times during the session on `encounter_card.dart` / `bestiary_screen.dart`
  while PROD-ENEMIES was mid-edit.
- **The "in plate with the longsword" render is a substitution, named.**
  `recipe.bronze_longsword` needs `item.boar_tusk` and `item.gloom_silk`, and
  `bronze_chestplate` is the only armour in the book with no monster drop in
  it. A deterministic fixture cannot farm combat drops, so
  `character_folio_plate.png` is a played save in a **Bronze Sword and Bronze
  Pickaxe**, with the armour slot empty and showing its class shadow. Between
  it and `character_folio_tunic.png` the renders cover an occupied well, an
  empty well with its shadow, two rarity inks and two rank ribbons. What they
  do **not** show is the bust changing body, because the two loadouts a
  fixture can reach both resolve to the base portrait — that is a fixture
  limit, not a code path: the resolver call is unconditional.
- **`LedgerRow`, `RuledLedger` and `DressingChip` in
  `lib/ui/components/loadout_readout.dart`** are now used only by this screen
  (`RuledLedger` and `DressingChip` by nobody). They were left in place: the
  file is shared with PROD-UI-INVENTORY, who is mid-flight in it, and deleting
  a class out from under a concurrent team is how a working tree loses an
  afternoon. Cheap cleanup for the producer at integration.

## Requests filed, Q- raised

None. The one defect this screen met was already filed twice.
