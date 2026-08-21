# PRESENTATION_WORLD_REWARD_FEEL_01

**Status:** 🚧 Implementation complete — awaiting the owner's physical-device
test.
**Branch:** `playable-phase-2-multiregion`
**Start HEAD:** `0700969`
**Commits:** `4419cc2` (bug fixes) · `e03f96b` (Adventure + Goal Board) ·
`a0f34f7` (craft feel) · `400b5d9` (world + PixelLab evaluation) · closeout
**Owner brief:** delivered 2026-08-21, verbatim in the session that opened this
milestone. This record is the repo-canonical distillation (`RULES.md` G-5).

## What this milestone is

A presentation milestone. The owner physically tested the Exploration &
Progression Loop build and ruled the mechanics **good enough to build on** and
the presentation **not good enough yet**. This workstream exists to make the
game feel exciting, premium, readable, rewarding and expansive — not to add
mechanics.

Four owner objectives:

1. A much stronger UI presentation and information hierarchy
   (WalkScape-quality sectioning as *inspiration*, never a copy).
2. A much stronger reward / completion feel across gathering, crafting,
   contracts, projects, combat rewards, travel and level-ups — through
   clarity, animation and progression, never through dark patterns
   (`RULES.md` P-5 unamended).
3. A much larger, richer world atlas — the current cluster should read as a
   small corner of a continent, with real east/west vastness.
4. Less clutter: one shared activity stage per location instead of the
   Traveler repeated inside every resource card.

## Frozen while this milestone runs

Health cursor semantics, `totalGranted`, spend accounting, economy epoch,
HealthKit sync mode, atomic save/CAS, background health delivery — all
untouched (owner brief §54). Core progression numbers untouched unless a
presentation change exposes a concrete contradiction, reported first (§53).
No new mechanics from the §52 do-not-add list.

## Device findings this milestone must fix

| ID | Finding | Root cause (established at milestone start) |
|---|---|---|
| B-1 | Completed rotating contract stays tracked as a fresh `0/x` copy (Herbal Supplies → Meadow Herb 0/5; Wolf Problem → Forest Wolf 0/3) | `_contractCompleted` in `event_reducer.dart` rotates the deck but never touches `GameState.trackedGoals`; the tracked ContentId silently re-points at the next instance of the same contract |
| B-2 | Arrival card said `Arrived at Frostmere · 3,000 steps` after a 4,400-step two-leg journey | `TravelReport.cost` is the final `LocationTravelled.stepsSpent`; the UI travels leg by leg and the arrival line never mentions the journey |
| B-3 | Hardened Copper Seam renders an empty activity stage | `resource_node.hardened_copper_seam` is absent from `PixelIcons._nodeArt` and `AmbientAssets._scenery`; no `hardened_copper_seam.png` was ever generated — a REGIONAL_CONTENT_PACK_01 packaging omission |

## Plan of record

### Phase 1 — Correctness (code + focused tests)

- **B-1:** on `ContractCompleted`, the reducer clears the Contract slot when
  the completed contract is the tracked one; likewise on `ProjectContributed`
  with `projectCompleted` for a tracked project. The board's held completion
  panel remains the completion feedback, so nothing is lost visually. No
  schema change — `trackedGoals` is already state. Core regression tests.
- **B-2:** journeys become one confirmed, multi-leg dispatch: the confirmation
  quotes the whole way's cost (`AtlasWay.totalCost`), the controller walks the
  legs as the same one-leg engine commands in sequence (each atomic,
  exactly-once, engine-authoritative), and the arrival presentation reports
  the journey total with the final leg distinguished. A mid-way refusal stops
  truthfully where the player stands.
- **B-3:** PixelLab-generate the missing node vignette in the established
  96×96 transparent node style, package it, map it, and add a regression test
  asserting **every resource node in the content pack has node art and stage
  scenery** — the class of omission, not the instance.

### Phase 2 — Adventure restructure (owner brief §4–§11)

One **location activity stage** at the top of Adventure: background, Traveler,
cat, ambient idle; selecting an activity swaps the node scenery onto the
stage and runs the profession loop (the `AmbientStage` composition already
supports exactly this — the change is structural, not a new scene engine).
Below it, a compact **activity selector**: one row per node (name, skill,
cost, yield, lock state), only the selected activity expands into queue
controls and detail. Locked nodes stay visible as compact aspirational rows.
Encounters become compact rows with the same pattern. The board card leaves
Adventure for a dedicated **Goal Board** surface (one obvious button), and
Adventure keeps only a three-line tracked-goal summary.

### Phase 3 — Goal Board (owner brief §8–§13)

A dedicated full-screen route in each location's own fiction (Notice Board /
Ranger Requests / Mine Ledger / Expedition Ledger) with compact scannable job
cards (title, type, progress, reward — flavor secondary) and the special
community-project treatment: stage progress, permanent reward preview,
contribution animation, and the major completion beat.

### Phase 4 — Crafting feel (owner brief §14–§19)

Crafting becomes a short timed activity with a queue (×1/×5/×10), **zero step
cost unchanged**, categories (Materials / Food / Gear / Tools), compact
recipe list plus one selected-recipe detail panel, a craft stage, and tiered
completion feedback (quiet line for components; a reveal for equipment).
Queue semantics: each completed repetition dispatches the ordinary
`CraftItem` command — exactly-once spend and grant by the engine's own
arithmetic; cancel loses nothing committed; the queue keeps running while the
app is backgrounded and reconciles on resume, so the owner's "don't hold the
phone open" preference is met with **no schema change and no new P-4
exception**. A force-quit mid-queue keeps completed crafts and grants nothing
for undispatched ones — documented behaviour.

> **Superseded as planned.** This paragraph originally read "on backgrounding
> the remaining queue **fast-forwards to completion**", and the first
> implementation did exactly that — making Home a Skip Queue button. The owner
> rejected it. See *Owner correction round* at the foot of this document for
> the anchor-driven semantics that shipped.

### Phase 5 — Reward hierarchy (owner brief §21–§24)

Minor / medium / major presentation tiers, answering *what did I get, why
does it matter, what changed, what can I do next*. Level-ups name their
unlocks; rare drops get an entrance and a rarity frame; enemy-knowledge
stages present as learning the ecology; travel arrival presents discovery.

### Phase 6 — World atlas (owner brief §27–§36, owner addendum 2026-08-21)

Mandatory **PixelLab evaluation** first (the account has Maps 0 / Tilesets
2 / Tiles 0). Finding at milestone start: the MCP surface can list, view and
edit maps and generate tilesets, but **map creation lives in the web Map
Workshop only**.

**Owner addendum (mid-milestone):** the spike must NOT reduce to "web-UI
Maps vs `atlas_master.png`". Evaluate the **combined MCP production model**
against the flattened-raster workflow — top-down tilesets with
chained/seamless terrain transitions, style-matched map objects
(transparent, matched to an existing map/backdrop), raw-image and
reference-based generation, image editing and localized inpainting, image
animation — with `https://api.pixellab.ai/mcp/docs` inspected as part of the
architecture decision. The candidate architecture: PixelLab owns macro
terrain/tilesets, map objects (landmarks, settlements, ruins, vegetation),
environmental animation and creative artwork; Flutter/Claude own world
coordinates, pan/zoom, LOD, discovery, routes, hit targets, labels, state,
compositing and playback. The real question: *can PixelLab's
map/tileset/object/image MCP ecosystem become a more scalable
terrain-authoring and world-production foundation for Stride?* The final
report documents which MCP capabilities were actually tested.

The same thinking applies to the shared activity stage where useful:
resource nodes, trees, station props may be better as reusable,
style-matched modular PixelLab objects swapped into one persistent scene
than as bespoke full illustrations per activity.

M-12 still governs joins: butted paintings fail blind QA; growth must be one
painting, natural-boundary growth, or tile-grammar terrain that owns its own
transitions. Target: a wide-format continent where the playable cluster
reads as ~10–20%, real E/W pan, regional colour identity, future
visual-only/rumored geography, and living overlays per region.

### Phase 7 — Verification, visual QA, docs

Focused suites on changed surfaces (§57), the §58 screenshot set, updated
canonical docs, and the §60 final report with the device acceptance script.

## PixelLab budget

2,522 generations remain this cycle (reset 2026-09-16, Tier 2 upgrade
confirmed at milestone start). Deliberate spend, full provenance per
generation in `GAME_BIBLE/ART/exploration/PRESENTATION_WORLD_REWARD_FEEL_01/`.

## Unresolved at start

- UNRESOLVED: whether audio sources exist to wire the §42 seams — OD-06
  stands; no guessing at URLs.
- UNRESOLVED: PixelLab Maps adoption — decided by the Phase 6 evaluation,
  not before it.

---

## Device acceptance script

One thing at a time. Stop at the first step that surprises you and write
down what you saw.

1. **Save persists.** Launch. The banked figure is the one you left. Force
   quit, relaunch: still there. `TOTAL WALKED` never falls.
2. **Adventure redesign.** One picture at the top with the Traveler in it —
   not a picture *and then* a card with another Traveler. Below it: a
   walking band, an ACTIVITIES list of short rows, and CURRENT GOALS with a
   Goal Board button. Nothing else.
3. **Activity stage idle.** Watch the stage with nothing selected: the
   Traveler should stretch, drink, look around, sometimes with the cat, then
   settle. No node prop is on the stage.
4. **Select Copper Seam** (travel to Stonefall first). The copper node
   appears as scenery behind the Traveler; the row expands with the queue
   controls; the projection line reads `1 × N = N steps · ×1 Copper Ore`.
5. **Select Tin Seam.** The tin prop *replaces* the copper one on the same
   stage. The Traveler does not move or reset.
6. **Locked Hardened Copper Seam.** Its row says LOCKED and names the gap.
   Select it — **its art appears on the stage** (this was the empty stage).
   The controls are dead and say why.
7. **Gathering queue.** ×5 on an affordable node, start. The Traveler works
   continuously, the bar fills, the count climbs, banked steps fall per
   completion. Lock the phone for a minute; come back: the queue has
   advanced, gains reported once, nothing double-counted.
8. **Goal Board.** Tap it. Full screen, titled in this place's fiction
   (Notice Board at Haven, Mine Ledger at Stonefall). Tracker on top, board
   below. CLOSE returns to Adventure.
9. **Completed contract clears.** Track a Local Need, complete it at the
   board. The tracker's Contract slot goes **empty** — it must NOT show the
   same contract at 0/x again.
10. **Community project.** Contribute. The material bar animates toward its
    target; the tile shows the stage ladder and an "On completion:" line
    naming the permanent change.
11. **Crafting at a station.** Craft screen: category chips, compact rows,
    one selected recipe expanding. Craft a cooked food — the Traveler
    crouches over a lit cookfire and stirs, on the same floor as the fire,
    for the whole bar; then a one-line result. Craft a metal component —
    same stage, now a forge and a hammer swing that lands on the billet.
    It should feel like *making* something, not like waiting.
12. **Crafting queue.** A recipe your bag funds several of: ×5, start. The
    count climbs; ingredients leave and outputs arrive per repetition.
    Cancel mid-run: everything completed stays, nothing half-made.
12a. **Backgrounding a queue is not a Skip button.** Start ×5 of a 4 s food.
    Immediately press Home, wait ~5 s, reopen. **Exactly one** more should
    have completed — not the whole queue. Note the count and the bag.
12b. **A long absence completes the queue and no more.** Start ×3, press
    Home, leave the phone for a few minutes, reopen. All 3 completed, the
    queue is finished, and the bag lost exactly 3 recipes' worth of
    ingredients — no extra repetition, no extra spend.
12c. **Force-quit mid-queue.** Start ×5, let one finish, then swipe the app
    away and relaunch. The completed craft is in the bag; no craft queue is
    running; nothing was consumed for the repetition that was in flight.
13. **Equipment craft.** Make a weapon or armour. The panel names it in its
    rarity, states `Attack 3 → 7`, names any level-up unlock, and offers
    **Equip** right there.
14. **Rare reward.** Fight until something uncommon drops. The victory panel
    frames it in its rarity. On the encounter card, check KNOWN DROPS — a
    signature you have not earned reads `???`.
15. **Travel.** World tab, pick **Frostmere** from Haven's Rest. It is
    offered as one journey. The confirmation says *By way of Stonefall Mine
    · 4,400 steps in all · leaves N banked*.
16. **Arrival cost wording.** After arriving: *Arrived at Frostmere ·
    4,400-step journey (final leg 3,000)*. Not "3,000 steps".
17. **Whole-world survey.** Pinch all the way out. The world is a wide
    continent; the north-south extent frames; the five places you know sit
    in one corner of it.
18. **Far west / far east pan.** Drag west: an enormous old forest, a ruin.
    Drag east and south: coast, islands, marsh, farmland, a river basin.
    This should feel like most of the world is unvisited.
19. **Environmental animation.** Watch the map: snow in the north, mist in
    the western forest, cloud shadows drifting, birds on the coast, smoke at
    the hamlet and the mine.
20. **Health sync unchanged.** Sync steps. The banked figure moves by
    exactly what was banked; two syncs in a row grant nothing the second
    time; `TOTAL WALKED` is monotonic.

## Known issues at hand-off

**BLOCKER:** none known.

**GAMEPLAY / DESIGN**
- The craft queue is **ephemeral**, unlike gathering's durable
  `GameState.activityQueue`: a force-quit *mid-queue* grants nothing and
  consumes nothing for the repetition in flight, and a relaunch starts with
  no craft queue. Deliberate, and safe because crafting costs no steps —
  reasoning in *Owner correction round* below and in `craft_controller.dart`.
  Completed repetitions are always kept.
- A craft profession with **no authored working loop** renders the progress
  bar alone. Smithing and cooking ship loops and stations; anything beyond
  those two crafts falls back until its loop is generated.

**COSMETIC**
- The Stonefall adit reads "a mine or a mountain outpost" from pixels alone;
  its runtime label disambiguates (blind QA note).
- The meadow band around Haven's Rest is one value step brighter than the
  other grass tones — reads as a biome, detectable as a treated region.
- Blind QA's incidental finding, on record for a future node round: the
  shipped **Tin Seam** vignette's first blind read was "a giant cookie".

---

## Owner correction round (2026-08-21, after the first hand-off)

The owner reviewed the hand-off report and returned two corrections. Both are
inside this milestone; neither is a new workstream.

### 1. Craft background semantics — CORRECTED, and the owner was right

**The defect.** The first implementation's `_fastForward` dispatched *every*
remaining repetition the moment the app was backgrounded, with no reference
to elapsed time. That made Home an instant **Skip Queue** button. It
contradicted `DECISIONS/0022` §6, which requires reconciliation to compute
how many whole repetitions the elapsed time completed and to commit only
those. The report's phrase "fast-forwards the remainder" described it
accurately; the behaviour itself was wrong.

**The correction.** `CraftController` now carries a wall-clock **anchor** for
the repetition in flight and mirrors the gathering queue:

- backgrounding cancels only the foreground boundary timer; the anchor stays
  and elapsed time keeps accruing against it. **Backgrounding commits
  nothing.**
- resuming reconciles: it commits only whole elapsed repetitions, clamped to
  the requested count, and advances the anchor by exactly the completions it
  commits — so a second reconcile with no further time commits nothing.
- a backward clock yields zero due repetitions and never strands the queue.
- Cancel settles per `DECISIONS/0022` §7: fully-elapsed repetitions commit,
  the partial one is discarded with the remainder.
- the partial repetition consumes and grants nothing, because nothing is
  consumed until its boundary command commits.

**Force-quit, explicitly.** The craft queue is **ephemeral**, unlike
gathering's durable `GameState.activityQueue` (v6). The difference is
deliberate and the reason is asymmetric risk: a gather completion *spends
banked steps* the player committed, so a killed process must not lose them;
crafting costs no steps, so a run that dies grants nothing and consumes
nothing for repetitions that had not committed, while every repetition that
did commit is already atomically on disk. Nothing is owed and nothing is
lost, so no schema addition is warranted (brief §56). A relaunch therefore
starts with no craft queue, by design.

**Still no second P-4 exception.** P-4 forbids time standing in for movement.
Crafting is free and instant in the domain — ten taps make ten planks at zero
step cost — so the queue's clock cannot unlock anything those taps could not
already produce. Time is a brake on presentation, never an engine of
production. `DECISIONS/0022`'s exception exists because gathering's
completions spend steps; there is no equivalent claim here.

**Proof.** `test/craft_flow_test.dart`, ten cases, including: backgrounding
commits nothing and the resume commits exactly the one elapsed repetition; an
hour away completes the requested count *and no more*; repeated
pause/resume with no elapsed time commits nothing; a backward clock commits
nothing; cancel commits the fully-elapsed repetition only; a dead process
grants nothing further and the committed craft survives a reload.
**Mutation-checked**: reverting the due-count to "everything" fails three of
them.

### 2. Craft visual shipment — SHIPPED

Bar-only crafting is gone for both craft classes the progression slice
exercises. Eight PixelLab generations: two accepted loops (smithing, cooking),
two accepted station props (forge, cookfire), four rejected candidates kept as
evidence. Full provenance, the blind-QA verdicts and the minors on record:
`GAME_BIBLE/ART/exploration/PRESENTATION_WORLD_REWARD_FEEL_01/out/craft/README.md`.

Reuse is by profession, not by recipe: one Traveler loop and one station per
craft skill, selected by the recipe's skill id, so every smithing recipe
shares one loop and every cooking recipe shares the other. Completion still
transitions into the existing tiered reveal.

**The defect this round found**, and it is the one worth carrying: the station
was first passed to `AmbientStage`'s scenery slot, which places a node
vignette far-left and raised. Correct for "this figure, at this place"; wrong
for "this figure, working on this thing" — the Traveler swung at empty air
with the anvil a screen away. Nothing in the widget tree was wrong and no
assertion about widgets could have seen it; the in-context composite showed it
immediately. The craft screen now places the station on the figure's own
ground line, immediately in front of him, from the same `AmbientStageLayout`
the figure is placed by. `test/goldens/craft_stage.png` is the regression
witness.

**Known issue superseded.** The hand-off listed "craft station art is a seam,
not a shipment" and the background fast-forward as accepted behaviours. Both
are now resolved; the fast-forward entry is withdrawn and replaced by the
anchor semantics above, and the seam entry is withdrawn — the loops ship. A
profession with no authored loop still renders the bar alone, which is now a
genuine fallback rather than the shipped state.
