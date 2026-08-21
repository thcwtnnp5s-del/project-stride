# PRESENTATION_WORLD_REWARD_FEEL_01

**Status:** 🚧 In progress
**Branch:** `playable-phase-2-multiregion`
**Start HEAD:** `0700969`
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
arithmetic; cancel loses nothing committed; on backgrounding the remaining
queue **fast-forwards to completion** (crafting is domain-instant; the timer
is presentation), so the owner's "don't hold the phone open" preference is
met with **no schema change and no new P-4 exception**. A force-quit mid-queue
keeps completed crafts and grants nothing for undispatched ones — documented
behaviour.

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
