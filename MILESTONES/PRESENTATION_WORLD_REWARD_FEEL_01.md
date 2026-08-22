# PRESENTATION_WORLD_REWARD_FEEL_01

**Status:** 🚧 Device correction round complete — awaiting the owner's second
physical-device test.
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

---

## Device correction round (2026-08-22)

The owner installed `1835a91` and returned a verdict: the progression works,
the new UI architecture is a meaningful improvement, the shared activity
concept is directionally correct, crafting feels like an activity, the atlas
is a major improvement, and the Goal Board separation was the right
architectural choice — followed by a list of presentation and correctness
faults. This section is the repo-canonical record of what was done about
them.

### Correctness

| Finding | What it was | What was done |
|---|---|---|
| Stale tracked contract survived migration (§13) | The reducer fix reached future completions and could never reach the save on the phone, where Wolf Problem was completed under the old build | **State version 8**, the migration table's first *repair* step. Clears a Contract tracker only when the contract is unaccepted **and** completed before — residue and nothing else. Runs once, as an ordinary `TrackGoal` event through the real engine. `DECISIONS/0024` |
| "+0 STEPS BANKED · Journey Ready" (§14) | Two faults in one card: the banner read `lastSync`, which the result timer nulls while the banner waits for a tap; and the highlights were "true right now" asked after the sync, so standing facts re-announced forever | The banner holds its own copy of the figure. The highlights are the **difference** between the projection before the sync and after it, so a sync celebrates only what it made true |
| Goal Board yellow underlines (§10) | Flutter's missing-Material fallback, **shipped twice**. The first fix wrapped `MaterialApp.home`, which is one route; the Goal Board is the product's first push and the Navigator builds it outside `home` | The `Material` moved to `MaterialApp.builder`, which wraps the Navigator, so no future route can acquire this by being new. The guard asserts on **resolved text decoration**, not on strings; with the old placement it reports the board's 50 underlined strings |

### Presentation

**The activity stage, §2–§6.** The architecture stays; the composition
splits in two. Nothing selected is a LOCATION — the whole painting, the
Traveler, the cat, the full idle cadence, and deliberately no resource prop,
because a place is not a job. Selecting an activity is WORK — the
profession's own tighter backdrop, the resource on the Traveler's own ground
line immediately where his tool lands, the companion scenes dropped so the
cat is not underfoot at a rock face, and the caption naming the work rather
than the place.

Families, not scenes per node (§4): one composition per profession with the
resource swapped in by node, so Copper, Tin and Hardened Copper are three
props in one mining scene and the code is identical for all nine nodes.

**Encounters, §15.** The same shape as the activity list: ~48 dp rows, one
expanded detail. Everything the ~400 dp card carried — the creature's own
idle, its knowledge tier, its known drops in rarity ink, its stats, Start
Combat — is inside the one enemy being considered.

**The Goal Board, §9/§11/§12.** Four facts a job — title, type, progress,
reward — with a state word so a row never conceals that something is
finishable, and the flavour and the buttons in the one job the player
opened. Community projects keep their full tile; what changed is that they
are no longer competing with five equally loud contracts above them.

**Craft copy, §8.** `0 craftable · 15 known`, the same shape at every count.

**The world, §16–§27.** See below; it is the one item that does not fully
pass.

### Two placement rules that came out of blind review

Both are in `AmbientStage` now, and both were found by a reviewer rather
than by taste:

- **`StageScenery.behindFigure`.** A prop tall enough to occlude the tool is
  painted before the figure. A tree trunk drawn last hid the axe completely
  and the honest read was *"a man pointing at a tree"*.
- **`AmbientAssets.worksEast`.** The working side is a property of the
  **loop**, not of the prop. Woodcutting, foraging, smithing and cooking all
  face west; the mining loop faces east and throws its chips right, so
  placing its boulder west put the ore behind the miner's back.

### The world item, stated plainly

**Delivered:** 3072 × 3072 world px, 2.25× the footprint, north/south
doubled, one painting so no join; the five places spread so the map explains
its own travel costs; fourteen future landmarks north, south, east, west and
offshore, named, quieter, suffixed and deliberately untappable; a label LOD
that keeps the far tier at survey zoom and drops the ferry crossings.

**Not delivered:** a clean §23 topology review. The gate was run on the old
painting and the new one with the same questions, so the comparison is a
measurement rather than an opinion: **both FAIL; the incumbent carries one
BLOCKER and the replacement carries none.** The incumbent's blocker is a
rectangular compositing box in open water — inpaint residue from the first
pass — and it is in the product today. Shipping the replacement is therefore
a strict improvement on every measured axis, and it is still not clean.

The shared faults are the generator's, not either painting's: sparse
drainage, a stamped forest quarter, three or four coexisting projections,
hard biome joins. The next pass is specified in the world record.

**And a tooling blocker that outranks any art note:** MCP's inline base64
ceiling measures at roughly **5.5 KB**. A 96 × 96 sprite fits; any crop of a
painted map does not. So the five corrective inpaints of the first pass were
only possible because they were small, and the coastline repair this round
needed was impossible. Until an image can be hosted, **atlas-scale
corrections must come from the web Map Workshop or a paint pass outside this
pipeline.**

### Known issues after this round

**BLOCKER:** none known.

**GAMEPLAY / DESIGN**
- The atlas does not pass its topology gate (above). Materially better,
  not clean.
- Three nodes — Frostpine Stand, Rimefrost Hollow, Hollow Thicket — have no
  authored work prop and fall back to their node vignette at the interaction
  point. Better than where they were, worse than a work face.
- Travel-leg distances are proportional to their step costs only roughly;
  the painted features are where they are and travel costs are frozen
  content this milestone does not touch.

**COSMETIC**
- The foraging backdrop's upper quarter is a flat field; it reads as
  receding haze in motion and as empty canvas in a still.
- The oak stump's cut face is drawn near-frontally and disagrees slightly
  with the ground plane its own log establishes.
- The three ore props share one boulder silhouette; the swap boundary is
  visible on close inspection.
- Craft loops keep their recorded minors: the smith posture pops on the
  wrap, the cook bowl leaves the pot in two of seven frames, and both craft
  stations are ¾-isometric against a flat side-view figure.
- No native-resolution or ×8 review pass was run this round. Tangency and
  stray-pixel inspection is **uninspected, not cleared**.

### Revised device acceptance — presentation only

1. **Adventure, idle.** Stonefall with nothing selected: the mine painting,
   the Traveler, the cat, no ore boulder anywhere. It should look like a
   place, not a job list.
2. **Adventure, working.** Tap Copper Seam. The backdrop tightens to a mine
   working with a lit floor, the seam stands at his feet, the cat is gone,
   the caption says Copper Seam. Start it: the pick comes down on the rock
   and the chips land on it.
3. **The same scene, three ores.** Copper, Tin, Hardened Copper in turn.
   Same place, three visibly different minerals.
4. **Woodcutting and foraging.** Whispering Woods: the axe lands in the
   notch; the forager crouches into the herbs with his face clear.
5. **Encounters.** Salamander and Cave Goblin are rows. Open one: the
   creature, its stats, its known drops, Start Combat. Only one opens.
6. **Goal Board.** Open it. **No yellow underlines anywhere** — title,
   headings, job text, rewards, buttons, CLOSE. Jobs are rows of four facts;
   open one for its flavour and its buttons. The project still looks like a
   project.
7. **Craft.** The census reads `N craftable · M known`. The forge and the
   cookfire still read.
8. **The stale tracker.** First launch after installing: the Contract slot
   should be **empty**, not "Wolf Problem · Forest Wolf 0 / 3".
9. **Sync with nothing new.** Press Sync twice. The second must raise **no
   reward card at all** — no "+0", no repeated Journey Ready.
10. **Sync that crosses a threshold.** Walk until a tracked journey becomes
    affordable, then sync. Journey Ready fires **once**, with the real
    banked figure.
11. **World, survey.** Pinch out. The continent should extend past the
    window in **all four directions**, and the far names — Rimewatch,
    Emberhold, Marshlight, Tern Isles — should be legible out there.
12. **World, panning.** Go far north to the ice, far south to the marsh, far
    east to the lighthouse, far west into the deep forest. Note anywhere the
    map looks broken; the record above already lists what is known.
13. **World, spacing.** Frostmere should be a long way north of Stonefall.
    Does 3,000 steps look like 3,000 steps now?
