# EPO03 Wave 2 — PROD-UI-WORLD report

Team `world`. Branch `fable5-executive-production-overhaul-03`, from `f4023a5`.
Cap 60 generations, **0 spent** (`GAME_BIBLE/ART/exploration/EPO03/ledger/UI_WORLD.md`
says why, and what the screen uses instead).

The owner named this screen twice:

> The bottom World information sheet currently obscures too much map. Fix
> this. Map must remain the hero.

> Fix viewed-location vs selected-location confusion.

Both are answered, and the first is answered with a figure.

---

## 1. The three stops, measured

Rendered by the SCREEN_EVIDENCE harness at **393 × 852, DPR 1**, through the
real app shell, so the World body is the real one: 852 − a 61 dp header −
a 64 dp nav bar = **727 dp**. Written by the run itself to
`GAME_BIBLE/ART/exploration/EPO03/review/device/world/epo_world_measurements.txt`
— not typed by hand.

| Stop | Sheet dp | **Map visible dp** | **Share of body** | Share of screen | Render |
|---|---|---|---|---|---|
| **PEEK** (open) | 64.0 | **663.0** | **91.2 %** | 77.8 % | `epo_world_peek.png` |
| **PEEK** (a place selected) | 64.0 | **663.0** | **91.2 %** | 77.8 % | `epo_world_strip_offscreen.png` |
| **HALF** (the travel confirm) | 261.7 | **465.3** | **64.0 %** | 54.6 % | `epo_world_half_confirm.png` |
| **FULL** (the whole inspector) | 508.9 | **218.1** | **30.0 %** | 25.6 % | `epo_world_full_inspector.png` |
| **PEEK** (arrived) | 64.0 | **663.0** | **91.2 %** | 77.8 % | `epo_world_arrived.png` |

**What it replaced.** `_collapsed = false` and
`(727 × 0.34).clamp(220, 360)` = **247 dp**, so **480 dp of map, 66 % of the
body** — *and every marker tap re-expanded it* (`world_screen.dart:210`,
`_collapsed = false` inside `onSelect`). The one gesture a player makes to
look at the world was also the gesture that covered a third of it.

**The gain is 183 dp — 38 % more map at rest, and it never shrinks by
accident.** That matters more than it did when the round opened: the terrain
underneath is largely new. The renders show it directly — the peek frame
carries the rebuilt north face and the settlement's fields; the off-screen
frame is the ice bastion with the drake over it; the half frame has the fairy
glade lit inside its ring, all of it painted into the terrain rather than
placed as props, so it survives the overview zoom the old props did not.

### The rules that hold the figure

- **A marker tap never raises the sheet.** It updates the peek. A sheet
  already at FULL comes down to HALF — a new question at the size the player
  last chose to read at, never a jump upward.
- **A tap on the map drops the sheet to peek.** Looking at the world is the
  gesture that clears the words off it.
- **Arriving returns the screen to the map**: peek, on *here*, wherever the
  journey was dispatched from. The journey's own sentence is still on the
  sheet, one grip tap away.
- Drag snaps to the nearest stop; a fling over 300 dp/s moves exactly one.
  Grip tap: peek → half, half or full → peek.
- The 24 dp fade above the sheet is **not** counted as sheet. It is
  translucent and `IgnorePointer`, so the painting reads through it and a drag
  begun in it pans the atlas. **There is no scrim** — darkening the map to
  make a sheet legible would be the same mistake in a different currency.

### The strategic-travel lock, intact

`Set out · N steps` is the only dispatch. The peek's compact `Travel`
(≥ 88 × 44) **arms** the priced confirmation at the HALF stop and travels
nothing; `epo_world_half_confirm.png` is that state, unpressed, with the
session still at Haven's Rest. Both protected call sites are byte-identical:
`world_screen.dart` `controller.travel(option.id)` in the pre-atlas fallback,
and `atlas_selection_panel.dart:133`-region `controller.travelJourney(legs)`.
Nothing auto-travels; no step cost, economy, save or health path was touched.

---

## 2. Here / selected / journey — three words, three markers, three homes

| | Word | Marker | Lives in |
|---|---|---|---|
| **Here** | `You are here` | bullseye + pulse (shipped) | the peek's status line, and the header's place title |
| **Selected** | the place's own name + `Reached` / `Not yet reached` | ivory ring (shipped) | the sheet, at every stop |
| **Journey** | `Journey set` | gold ring (shipped) | the peek's status line when it applies, and the Journey slot at half/full |
| **Viewed** | **never named** | — | `_ContextStrip` only |

The peek's second line is one sentence carrying all three where they apply:
`Settlement · You are here`, `Wilds · Not yet reached`,
`Worksite · Reached · Journey set`. They cannot be confused because no two of
them are the same word.

**The fourth state — what the camera happens to be pointing at — was the
confusion, and it is not named anywhere.** It appears only as a 22 dp strip at
the map's top edge (`0xA0` plate), present *only* while the selected or the
here marker has been panned off the visible map, saying which way each lies:
`◂ Whispering Woods · 500` and `You are here ▾`. The carets have **four**
directions, not two — on a tall phone over a taller world most of what leaves
the window leaves through the top or the foot, and a chip pointing right at a
place lying south is worse than no chip. They are drawn by a `CustomPainter`,
not typed, so they render identically on the device and in the harness.
`epo_world_strip_offscreen.png` is the state.

---

## 3. What shipped

**Dart** (all mine, no shared file edited):

- `lib/ui/screens/world/world_screen.dart` — rewritten around
  `_SheetStop { peek, half, full }`. `_WorldInfoPanel`, `_panelFraction`,
  `_panelMinHeight`, `_panelMaxHeight`, `_panelPeekHeight`,
  `_panelHandleHeight`, `_panelFadeHeight` and `_PanelPeekRow` are gone;
  `_WorldSheet`, `_PeekRow`, `_ContextStrip`, `_StripChip`, `_CaretPainter`
  and the stop arithmetic replace them. Exports `worldSheetKey`,
  `worldSheetGripKey`, `worldContextStripKey` so a test measures the thing the
  player drags rather than whichever `ListView` is inside it.
- `lib/ui/screens/world/atlas/atlas_selection_panel.dart` —
  `AtlasSelectionPanel` and `AtlasInspector` gain `compact` (head only: name,
  kind, terrain, status, the route line, the price, the travel control, the
  Journey slot, the result line — no vignette, no Work / Gathering /
  Encounters) and `travelArmed`; `_TravelControls` gains `armed`, applied as an
  **edge** so a Cancel is not re-armed by the next rebuild.
- `travel_transition.dart`, `travel_pacing.dart`, `atlas_place_info.dart`:
  untouched — nothing in the change needed them.

**Two engineering findings worth keeping**, both recorded in the source:

1. **A `GestureDetector` wrapped around `AtlasViewport` cannot see a map
   tap.** The viewport's own scale recogniser is deeper in the tree, so it is
   first into the gesture arena and wins the sweep on any tap no marker
   claimed. The map tap is therefore recognised at the pointer (`Listener`,
   outside the arena) and **applied one microtask late** — `onSelect` runs
   during the sweep and cancels the pending drop, so a marker tap selects
   without collapsing a sheet the player deliberately raised.
2. The strip's off-screen test reads the camera through
   `GlobalKey<AtlasViewportState>` after each pointer event and only calls
   `setState` when the answer changed — a record comparison per event, no
   polling, no timer.

**Tests** — `flutter analyze` clean on every file I own.

| File | Result |
|---|---|
| `test/atlas_screen_test.dart` + `atlas_inspector_test.dart` + `atlas_scene_test.dart` | **67 pass** |
| `test/phase1_ui_test.dart` | **27 pass** |
| `test/screen_evidence_test.dart` — `EPO03: the World sheet at peek, half and full` | passes, writes the five renders and the measurements file |

New test: **`the sheet has three stops and the map stays the hero`** — asserts
64 dp at open with over 90 % map; that a marker tap leaves it at 64; that the
peek's Travel reaches HALF with `Set out` present and *the player still at
Haven's Rest*; that a grip fling reaches FULL with 30 % of map still showing;
and that a tap on open country (found, not guessed — the atlas is dense with
44 dp targets) returns it to peek.

Existing assertions were **updated, never weakened**: the World sheet opens at
peek now, so every test that reads the inspector's own words says which stop
it reads at, through a `raise(tester)` helper that is one grip tap — the
gesture a player makes. The marker-glyph sweep is scoped to the viewport,
because the peek row draws a kind glyph from the same table and it is not a
marker on the map. The arrival test measures against the sheet rather than
against whatever scrollable is inside it, which is what it meant all along.

**Assets: none.** Zero generations; the ledger argues the case rather than
softening it.

---

## 4. Requests filed

`REQUESTS_NAV.md`, 2026-09-02 — **`AtlasViewport`: publish the camera, and
accept a recentre.** Additive only: a `ValueNotifier<int> cameraRevision`, a
`Size get viewportSize`, and `void recentreOn(AtlasNode)`. Status **OPEN** at
the time of writing.

---

## 5. What did not close

1. **The strip's chips do not recentre.** DIR-15 §1 has a tap on
   `◂ Whispering Woods` bring the camera back to it. `AtlasViewport` publishes
   no way to move its camera, it is shared, and this team does not own it, so
   the chips are **locators, not controls** — they say which way, and the
   player drags. That is the half of the job that answers the owner's
   question; the other half is one merged request away and the widget is
   already shaped for it. Named here rather than softened.
2. **Four marks unauthored** — `peek_plate` + its leather tab, `sheet_grip`,
   `label_plate` / `label_plate_selected`, and a chip plate for the strip.
   Every one has a landed kit name, resolves to `null`, and reserves its
   declared geometry, so nothing reflows when they arrive. The route, for
   whoever spends next: `create_image_pro`, canvas ≤ 85 px for 16 candidates,
   an accepted grain (`assets/ui/v1/surface/grain_leather.png`) as
   `style_image_url` *and* as a labelled reference, then `frame-measure.js`
   → key any white face → `ceiling-clamp.js` → `ninepatch-proof.js`.
   Not `create_image_pixen`: 32 rolls have already proved it cannot.
3. **`_MarkerLabel(plateAsset:)`** — DIR-15 wanted the selected place's map
   label on an ember-edged plate. It lives in `atlas_layers.dart`, which
   PROD-WORLD-LIFE is actively editing this round, so it was not touched and
   no request was filed against a file already in another team's hands. The
   selected ring still distinguishes the selection on the map.
4. **The header title still comes from the shell**, not from this screen, so
   "Here changes only on arrival" is true because the header already behaved
   that way — not because this screen now enforces it.
5. **Goldens drift.** `test/phase1_golden_test.dart` fails on
   `phase1_adventure`, `phase1_inventory`, `phase1_character` and the six-screen
   sheets. The Adventure/Inventory/Character diffs are the kit and nav rebuild,
   not this screen; the World frames legitimately changed because the screen
   was rebuilt. Not regenerated here — the producer regenerates after
   inspection (`PRODUCTION_RULES.md` §8).
6. **Not mine, seen in passing.** `test/ui_responsive_test.dart` fails at text
   scale ×1.2 and ×1.4 on `SMITHING · LEVELS 1–3 / 4–6 / 7–9 / 10+` and
   `UNWRITTEN PAGES` — Craft's chapter labels (`craft_screen.dart`), from
   `04ce5c6`/`f999f5f`. `combat_golden_test.dart`, `combat_ui_test.dart`
   (UI-COMBAT), `visible_equipment_test.dart` (EQUIPMENT) and the known
   `s01a` production-scan item are likewise not this team's.
