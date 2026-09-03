# EPO03 — PROD-UI-ADVENTURE report

Team `adventure`. Branch `fable5-executive-production-overhaul-03`.
**Cap 60 generations. Requested 0, accepted 0, rejected 0. Family total: 0.**

## What shipped

**The tab is a bound field journal.** `DIR-05`'s Adventure row asks for one
thing — *it is a book* — and the screen is now one: a full-bleed picture tipped
into a leaf, a binding down the left, and everything else written on the page
under ruled lines. **No card survives on this screen or on the Goal Board it
opens.**

Dart, all in files this team owns:

| File | What changed |
|---|---|
| `lib/ui/screens/adventure/adventure_screen.dart` | `PageGround(journalLeaf)` under the whole tab; new `_Spread` (the binding plus the page's margins); the walking band becomes `_WalkingLedger` — the facts, then the leaf's own `KitTile.ruleJournal`, then the affordance sentence; new `_SyncStamp` (the sync control as a `KitFrame.btnPlateV2` plate); the opportunity banner loses its `SectionCard` and its wash for `KitMark.ruleOrnateA` above and a plain rule below |
| `lib/ui/screens/adventure/activity_panel.dart` | the kit is a **ledger**: no card, no clip, a `KitRule` heading, `KitTile.ruleJournal` between entries, and a ruled **cost margin** down the right. Locked sites are **pencil sketches with a margin note** (`_NodeSketch._pencil`, `_CostMargin`) |
| `lib/ui/screens/adventure/goal_summary_card.dart` | goals are **slips pinned to cork**: `_CorkBoard` (the shipped `cork` grain) carrying `KitFrame.slipPinned` plates with a brass pin, under a `KitRule` |
| `lib/ui/screens/adventure/goal_board_screen.dart` | the pushed board is one `PageGround(cork)` page; the no-board case is a sentence on it, not a slip card |
| `lib/ui/screens/adventure/board_card.dart`, `goal_tracker_card.dart` | both outer `SectionCard`s deleted; the tracker and the location board are sections on that page under `KitRule` |
| `lib/ui/screens/adventure/location_stage.dart` (frame only) | the leaf's ruled line runs across the picture's foot, so the full-bleed stage reads as tipped **into** the journal |

**No asset was authored, changed or packaged.** `package-art.js` was never run
and the build lock was never taken. Ledger and the argument for the zero:
`GAME_BIBLE/ART/exploration/EPO03/ledger/UI_ADVENTURE.md`.

## What the phone shows that it could not before

- **A bound page.** A 32 dp binding at the left, the picture bleeding across
  the top with the page's rule under its foot, and four sections written on one
  leaf where there were four dark rounded rectangles.
- **A ledger, not a list.** Every gather site says the same three things in the
  same order and its price stands in a ruled right-hand margin, so the costs
  line up down the page and can be compared without reading.
- **A pencilled site instead of a dimmed one.** `Duskcap Grove` and
  `Heartwood Oak` at the Woods are graphite drawings beside `Oak Stand`'s green
  one, with `Requires Foraging 3 — you are 1` written in the margin at full
  reading contrast. Opacity 0.55 said *switched off*; a pencil says *drawn, not
  inked yet*, which is what a place you cannot work yet is.
- **A stamped sync, not a button.** The one control on the screen that is not
  the game action no longer looks like the game action.
- **A crowned moment.** A granting sync opens with the ornate rule over
  `+2,600 STEPS BANKED` in teal and closes with a plain rule — the moment reads
  as an entry in the book rather than as a warm box.

## Renders, read at phone scale

`GAME_BIBLE/ART/exploration/EPO03/review/device/adventure/` (393 × 852, DPR 1):
`v2_adventure_fresh.png` (Haven, one locked site), `v2_adventure_woods.png`
(three sites, two pencilled), `v2_adventure_sync_banner.png` (the opportunity
notice), `adventure.png`, `v2_gather_result.png`.

**Three verdicts came out of the first read and are already fixed** — this is
the round's own instruction (measure, then decide) applied to a screen rather
than to a roll:

1. **The spine painted one tile across the page's head** instead of running
   down it. `EdgeStrip` ignores the axis its `KitStrip` declares
   (`KitTile.edgeSpine` is the product's first vertical strip). Adventure was
   also handing it an unbounded width, which threw on every layout and failed
   every test that mounts the shell — UI-INVENTORY caught that and filed it
   (`6a11782`). The width is now declared, so the assertion is gone for
   everyone, and the binding is drawn in the kit's own fallback register until
   NAV lands the axis. **Seconded in `REQUESTS_NAV.md`, 2026-09-03.**
2. **The cost margin at 88 dp left 121 dp for a name** and clipped the facts
   line at "×2 Meadow Herb ·". Margin 72, entry padding 8, and the body stops
   8 dp short of the column rule instead of running under it.
3. **The banner's `OK` was full-bleed** and outranked the gather control.

An intermediate attempt to buy that width by shrinking the sketch to 84 dp
made every sketch vanish — a `PixelAsset` in a box smaller than its sprite
asserts, correctly — and is recorded in the source so nobody re-derives it.

## Tests

- `test/gather_prerequisite_gate_test.dart` — **5/5 pass.** Its locked-entry
  assertion asserted `Opacity(0.55)` on three sketches. `DIR-05` replaced
  "locked = dim" with "a pencil remap plus a margin note", so the assertion
  moved with the rule its owner moved: no 0.55 dim anywhere, three
  `ColorFiltered` sketches, and `Requires Foraging 3 — you are 1` still found
  exactly once. Nothing was weakened — the test asserts more than it did.
- `flutter analyze lib/ui/screens/adventure/` — **clean.**
- `test/gather_queue_ui_test.dart` **6/6**, `test/goal_board_test.dart`
  **all pass**, `test/phase1_ui_test.dart` **27/27**,
  `test/screen_evidence_test.dart` **10/10** — green on the final run.

  Worth recording, because it cost this session three diagnoses: for roughly
  an hour none of these four could compile or lay out, and **none of the
  faults were in Adventure**. The shared tree carried another team's
  in-flight Inventory rebuild (a `LayoutBuilder` under an `IntrinsicHeight`,
  and before that a constructor mid-rename), and two runs died outright on
  `flutter test` failing to copy assets while a concurrent `package-art.js`
  rewrote them. The way through was to attribute every collected exception to
  a file before believing any of them: at the point where zero traced to an
  Adventure file, the screen was finished and the tree was not. It settled on
  its own and the runs are green.

- **Goldens will legitimately change**: `test/goldens/` for every Adventure and
  Goal Board case. Not regenerated here — the producer regenerates after
  inspection, and `--update-goldens` was not run.

## Requests filed

`MILESTONES/evidence/EPO03/wave2/REQUESTS_NAV.md`, 2026-09-03 —
`EdgeStrip` should take its strip's axis so a vertical tile runs down rather
than across. Seconding UI-INVENTORY's block, with Adventure's mitigation
recorded. **Not blocking**; the call site does not change when it lands.

## What did not close

- **The binding is a tone, not the authored tile.** It reserves
  `KitTiles.thicknessFor(KitTile.edgeSpine)` and paints the kit's fallback
  register. One widget swaps back the day `EdgeStrip` takes the axis; nothing
  reflows.
- **`KitFrame.slipPinned` has not landed**, so the goal slips are the kit's
  square fallback plus this team's pin. That is finished work by the contract's
  own doctrine, not a hole — but the slips will look like paper only when NAV
  or a later round authors the row.
- **No Q- raised.** Nothing here needed a design decision that had not been
  made: `DIR-05` names every shape and the kit contract names every material.
