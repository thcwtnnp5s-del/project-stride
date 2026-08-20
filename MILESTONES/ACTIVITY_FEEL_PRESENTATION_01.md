# Activity Feel & Presentation 01 — milestone contract and record

**Opened:** 2026-08-19 · **Branch:** `playable-phase-2-multiregion` ·
**Starting HEAD:** `f917a91` (World & Reward Depth 01, device-accepted in
place; save v5 proven across the in-place update: TOTAL WALKED 431,904,
banked 15,217, spent 3,690, at Whispering Woods).
**Owner direction:** the "Activity Feel & Presentation 01" master prompt,
written from direct physical-device feedback.
**Status:** implementation complete, awaiting the owner's physical-device
test (§11). Results §10a–§13.

## 1. Objective

Make the core activities feel alive, deliberate and rewarding, and make the
world feel **substantially larger** — without touching the proven health /
economy / save / install paths:

1. **Timed, queueable gathering** — a gather takes 10–20 s of visible,
   animated work; the player queues repetitions; each completion spends and
   grants exactly once; cancel is safe; nothing completes in the background.
2. **World scale** — the atlas is re-authored at a more zoomed-out world
   scale so the five playable places read as a small part of a larger
   landmass; much farther zoom-out; seams and rogue black trees fixed by
   construction; more vibrancy and ambient world life.
3. **Combat choreography** — the presentation timeline matches the round's
   events (no HP jump before its beat, no apparent heal-back on the wolf's
   two hits); the enemy is visible on the Adventure tab before Start Combat.
4. **Presentation** — the blue step/shoe icon replaced with PixelLab art;
   the most visible ambient stiffness improved; per-completion gather
   feedback.

Not in scope: dungeons, `REGIONAL_CONTENT_PACK_01` integration (explicitly
withheld), merchants/gold/quests, background/wall-clock anything, audio
sourcing, stamina/energy/cooldowns, notifications, FOMO or monetization
mechanics of any kind.

## 2. Frozen (P0) — must not change

`packages/stride_core/lib/src/steps/`, `packages/stride_health/`, the
session's sync section, `DECISIONS/0016/0018/0019`, single-writer
persistence, atomic commits, `Scripts/ios/` install defaults (`devicectl`
in place). **This milestone plans no core or save-schema change at all**
(§4); if one becomes necessary, stop and report first. The rarity order and
colours are owner-canonical (`GAME_BIBLE/SYSTEMS/08_ITEM_RARITY.md`) and are
not revisited.

## 3. Hard constraints found at bootstrap

- **PixelLab balance: 266 generations, $0 credits.** Every art stream is
  budgeted before it starts (§9) and the master world composition takes
  priority over everything except the profession loops.
- The "random black trees" the owner saw are two real things: a painted
  dead-wood cluster in `atlas_base.png`'s north-west corner, and
  `env/prop_dead_tree` instances placed on the south tile's farmland. Both
  are resolved by the re-authored master world, not by prop patches.
- `MISTAKES.md` M-12: adjacent tiles do not join. The world therefore grows
  by **one master painting**, never by butting tiles.
- The Traveler exists in PixelLab (`Stride Traveler — PIXELLAB_PROOF_01`,
  8-dir 64 px, 55 animations), so profession loops are cheap v3 animations
  (~1 generation per south-facing loop attempt).

## 4. Architecture decisions (lead)

### 4a. Timed gathering is presentation over the existing atomic command

Each completed repetition dispatches the **existing** `GatherResource`
command — one atomic spend + grant + XP + persist, exactly-once by the
construction already proven on hardware. Consequences, all deliberate:

- **No core change, no save-schema change, no migration.** The queue is
  ephemeral foreground presentation state (like `SessionController.busy`).
- **Relaunch drops the queue; completed repetitions are already durable.**
  Nothing incomplete grants or spends; no wall-clock catch-up can exist
  because nothing is time-stamped.
- **Cancel aborts the in-progress repetition with nothing spent and nothing
  granted** (the command has not been dispatched yet); completed
  repetitions stay. This is the chosen cancel semantic (§34 of the prompt).
- **Backgrounding pauses the presentation timer** (elapsed time while not
  resumed is never counted); returning resumes where it paused.
- If banked steps run out mid-queue the next dispatch is refused by the
  engine and the queue stops with the truthful reason.
- Travel or combat while a queue runs cancels the in-progress repetition
  safely (and the engine would refuse the next gather anyway —
  `resource_node_not_here` / `encounter_in_progress`; defence in depth).
- The queue continues while the player browses other tabs (the controller
  is app-scoped, not screen-scoped); it never continues when the app is
  not resumed.

`ActivityController` (new, `lib/ui/state/`) owns the queue: node, queued
count, completed count, current-repetition progress, cumulative gains from
the returned `ActionReport`s, stop/cancel. Timing is injectable (a timer
factory + clock seam) so tests advance deterministically; the visible
progress bar is a widget-side ticker synced to the controller, gated by
`TickerMode` (domain completion and UI progress are separate clocks, §55).

### 4b. Duration model

Authored per profession, in one documented presentation table
(`ActivityDurations`): Woodcutting 12 s, Mining 14 s, Foraging 10 s,
(future: Cooking 12 s, Smithing 15 s). Presentation pacing, not domain
content — the same precedent as `CombatRules`' provisional constants; it
moves to content the day design wants per-node durations.

### 4c. World scale: one master painting at atlas scale 4

The atlas base becomes **one** 384 × 688 native painting displayed at
`scale: 4` — a 1536 × 2752 world-pixel surface, double the current width,
with **no seams by construction**. The same authored canvas now carries the
whole landmass, so settlements shrink to roughly half their current
world-relative size and geography becomes the primary map surface.

Zoom rescales around the same semantics (world px → dp): floor
`max(viewport fit, 1/scale)` = 0.25 (native ×1, the crispest reduction —
the **whole world frames on a phone**), initial 0.5 (exactly today's
reading), maximum 1 (native ×4, close inspection). The viewport reads all
three from the layout's scale; nothing hardcodes the world's size.

Labels and markers get simple threshold LOD: far zoom shows place names,
kind glyphs, the current marker and major routes; landmark labels and
props fade in near. No LOD engine — one threshold per layer.

### 4d. Combat: fix the timeline, not the domain

The domain is deterministic and stays untouched. The defect is presentation
sequencing; the fix is audited and tested at the choreography/stage level,
with a test that asserts shown HP is monotonic within a round segment
sequence (no heal-back) and never reaches the committed value before its
beat's tween window. Enemy preview reuses the committed combat idle art on
the encounter card — no new scene system.

## 5. Workstreams

| Stream | Owner | Files owned |
|---|---|---|
| A lead / integration / docs / PixelLab | this session | docs, `assets/**`, `atlas_layout.json`, `ambient_assets.dart`/`pixel_icons.dart` asset tables, packaging, goldens |
| B activity controller + UI | agent | `lib/ui/state/activity_controller.dart` (new), `lib/ui/screens/adventure/gather_node_card.dart`, `adventure_screen.dart` (wiring), `lib/ui/components/ambient_stage.dart` (activity-loop seam), their tests |
| C combat choreography + enemy preview | agent | `lib/ui/screens/combat/**`, `lib/ui/screens/adventure/encounter_card.dart`, their tests |
| D atlas scale mechanics | agent | `lib/ui/screens/world/atlas/**` (not the JSON), their tests |
| E PixelLab production (master world, profession loops, step icon, world life) | this session | exploration dir `GAME_BIBLE/ART/exploration/ACTIVITY_FEEL_01/` |

Merge order: B, C, D land in the main tree on disjoint files; A integrates
art, layout JSON, asset tables, goldens; strict verify; commit with
explicit paths.

## 6. World art brief (stream E, master painting)

One coherent landmass, portrait 384 × 688, in the accepted atlas language
(muted olive/khaki/grey base, flat matte, light upper-left, no text, no
figures, no grid) but with **stronger biome colour identity** than the
current tiles: richer forest greens, readable alpine blue-whites, warmer
farmland, distinct moor. Geography, north to south:

- **North:** an alpine ridge chain with snowfields and a frozen tarn — the
  Frostmere pass sits *in* it, small. No black dead-wood mass; the Hollow's
  menace comes from dense old-growth shadow, not silhouette trees.
- **North-west:** deep old-growth forest holding Forgotten Hollow;
  Whispering Woods at its southern fringe.
- **Centre-west:** open meadows and hedgerows; **Haven's Rest small** — a
  hamlet, not a fortress ring.
- **East:** foothills with Stonefall Mine, then open moorland, tarns, a
  ruined watchtower landmark, and a **coastline at the east edge** so the
  map reads as part of a continent.
- **South:** river lowlands crossed by tributaries; farmland belts;
  Millbridge; Ferry Crossing; the road running to a **walled Far Town at
  the south edge**.
- Roads: thin, long, continuous — Haven's Rest ↔ Woods ↔ Hollow, Haven's
  Rest ↔ Stonefall ↔ Frostmere, and the long south road.

Settlements and location marks stay small relative to terrain; five
playable places occupy a visibly small fraction of the surface. Judged
blind at phone framing before acceptance; budget ≤ 120 generations
including retries, and a failed round keeps the current two-tile world
(a smaller coherent world beats a larger broken one — but the scale goal
is the milestone, so a re-roll is preferred over surrender until budget
says stop).

## 7. Tests (focused)

Activity: queue ×1 / ×10; one completion = exactly one spend/grant/XP;
ten completions = ten commits; insufficient steps stops the queue; cancel
before completion grants nothing; cancel after a completed repetition keeps
it; background pause; relaunch has no queue and no loss; deterministic
fake-clock advance (no real waits). Combat: the wolf round's presentation
order (attack → enemy HP tween → wolf hit 1 → player HP → wolf hit 2 →
player HP → round end), no shown-HP increase mid-round, no committed value
before its beat. Preview: enemy art + name + remaining + Start Combat.
Atlas: floor/initial/max derived from layout scale; whole-world framing at
floor; LOD thresholds; hit targets at floor zoom; landmarks stay
non-interactive.

## 8. Definition of done

Prompt §68 verbatim in spirit — gathering timed/queued/animated/safe;
combat preview + correct event order + clean multi-hit; world substantially
larger with meaningful macro zoom-out, no seam defects, no black trees,
step icon replaced; ambient stiffness improved; health/steps/save/rarity/
install untouched; strict verify green; docs current.

## 9. PixelLab ledger (running)

Balance at open: **266**. Budgets: master world ≤ 120 · profession loops
≤ 30 · step icon ≤ 45 · world life/vibrancy ≤ 20 · contingency the rest.
Result: §12.

## 10. Progress log

- 2026-08-19 — bootstrap read; contract written; B, C, D fanned out; master
  world round 1 queued.
- 2026-08-19/20 — D returned (75/75), C returned (34/34, root cause found),
  master world r1 blind PASS-WITH-NOTE + cave inpaint → r2; profession loops
  r2 blind PASS-WITH-NOTE ×3; step mark shipped on blind round 3; B returned
  (531/531); lead integration: packaging, layout swap, glyphs, activity
  tables, test updates, goldens; monotonic-clock fix for the UI-boundary
  guard; strict verify; docs.

## 10a. What shipped

### Gathering (streams B + E)

- **`ActivityController`** (`lib/ui/state/`): an ephemeral foreground queue.
  Each completed repetition dispatches the **unchanged** `GatherResource`
  through `SessionController.gather` — one atomic spend + grant + XP +
  persist, exactly-once by the construction already proven on hardware. No
  core change, **no save-schema change, no migration**. Cancel aborts the
  in-progress repetition with nothing spent or granted; completed
  repetitions stay. Backgrounding pauses the presentation clock (elapsed
  non-resumed time is never counted; timing is a **monotonic Stopwatch**,
  never a wall clock — Q-UI-9 guard); relaunch simply has no queue. A busy
  session defers a completion's dispatch on a 250 ms retry — never drops,
  never double-dispatches. Travel or combat cancels the queue via one
  `onExclusiveCommand` seam (and the engine would refuse anyway — defence
  in depth). The queue survives tab browsing, never the background.
- **Durations** (`ActivityDurations`, authored presentation pacing —
  CombatRules precedent): Woodcutting 12 s · Mining 14 s · Foraging 10 s ·
  fallback 12 s.
- **Card UI**: ×1/×5/×10 presets + stepper clamped to
  `min(affordable, 20)` with the honest total ("10 × 90 = 900 steps");
  active panel with "Gathering 3 / 10", a smooth widget-side progress bar
  (TickerMode-gated; the controller never notifies per frame), seconds
  remaining, per-completion yield, cumulative gains, Stop. Refusals stop
  the queue with the truthful engine reason. No modal per completion; no
  energy bars, no speed-ups, nothing monetization-shaped.
- **Profession loops** (PixelLab, west-facing, blind PASS-WITH-NOTE each):
  woodcutting swing with arc, mining strike with rock chips, foraging
  kneel-and-pick played ping-pong. Tools held throughout (round 1's
  floating-tool failure fixed by animating from a held-tool start frame
  with the end frame pinned — the loop closes by construction). The stage
  plays the loop continuously during a queue (cat and idle cadence
  unmounted — the cat stays out of the working scene, prompt §40), aligned
  by feet-centre so starting a queue never makes the Traveler sidestep.

### World (streams D + E)

- **One master painting** (`world/atlas_master.png`, 384 × 688 native,
  layout `scale: 4` → **1536 × 2752 world px**) replaces the base + south
  tiles and all five landmark cutouts. Blind QA against the shipped world,
  staged identically: **PASS-WITH-NOTE, "CLEAR IMPROVEMENT"** — "reads as a
  continent slice"; settlements small within the landscape; no assembly
  seams (one generation cannot have a seam — M-12 applied); vibrant without
  garishness; crisp at max zoom. The r1 MAJOR (the Hollow cave read as an
  ink blot at survey zoom) was fixed by one targeted 96×96 inpaint → r2.
- **The black trees are gone by construction**: the old base tile's painted
  dead-wood cluster and the farmland `prop_dead_tree` instances are both
  retired with their surfaces (the new layout places **no** scatter props).
- **Zoom derives from the layout's scale** (stream D):
  floor = max(viewport fit, 1/scale) snapped down to the device-pixel grid,
  opening = 2/scale, max = 4/scale — shipped: **0.25 / 0.5 / 1**. At the
  floor the whole landmass frames on a phone. One-threshold **overview
  LOD** (below the opening zoom): landmark captions, landmark marker art
  and props hide; place labels, rings, kind glyphs, the current-place
  bullseye and routes stay, counter-scaled so nothing drops below its
  authored dp size; hit targets hold the 44 dp floor at 0.25.
- Five named landmarks: Millbridge, Ferry Crossing, Far Town (future tier),
  **Old Watch**, **Broken Tower** (the last two are art-stream proposals in
  the Q-07 sense). Routes re-traced along the painted roads. Overlays
  repositioned (mist over the Hollow forest, snow over the alpine north,
  clouds, and a new **bird-flock loop** over the farmland); the forge-smoke
  overlay is retired (at ×4 the plume out-scaled the hamlet).

### Combat (stream C)

- **Root cause of the device-observed heal-back**: `StrideSession`'s round
  resolves synchronously, so a frame renders between the tap and the report
  in which the live view already carries the final committed HP and the
  stage, seeing no report, synced straight to it — the replay then tweened
  *from the finals* (enemy bar dead on the strike; player bar tweening UP
  to "after hit 1" = the heal-back). Fixed in presentation only: the combat
  screen **freezes the view while a command is in flight**, so new
  committed figures reach the stage only with the report that choreographs
  them. Two adjacent defects fixed with it: the killing-blow frame no
  longer unmounts the stage (a `combatBusy` flag guards the mount
  condition), and the victory panel no longer flashes before the replay.
- Proven order for the wolf round (sampled every 100 ms by test): attack →
  enemy HP tweens only in the strike window → hit 1 → distinct player-HP
  drop → hit 2 → second distinct drop → round end; both shown-HP series
  non-increasing, ending exactly on committed figures; skip lands exactly.
- **Enemy preview**: the encounter card opens with a 120 dp stage band —
  the enemy's grounded combat idle (contact shadow, bounded 6 s visit,
  TickerMode/lifecycle/reduced-motion safe), name, behaviour, stat tiles,
  rewards, remaining-this-visit, Start Combat. An enemy without art renders
  the card exactly as before.

### Presentation

- **Step mark replaced** (OD-03 closed): a PixelLab cuffed traveler's boot,
  12 × 12, conformed to teal `#58D6C0` / muted `#B3A794` — the
  `walking_glyph.dart` pairing intact, same filenames so every surface
  updated at once. Three blind rounds; two geometry findings recorded in
  the OD-03 closure (a boot print cannot fit the slot; shaded detail
  fragments at 24 dp).
- Ambient stiffness: the highest-visibility fix — the gather screen no
  longer rests between one-shots during work — shipped as the activity
  loops themselves. The known `wipe_brow` frame-7 arm stays deferred
  (below the loop work in the owner's own priority, prompt §39).

### PixelLab ledger

| Item | Gens |
|---|---:|
| World master r1 (pro) + cave inpaint | 60 |
| Profession loops (r1 ×3 + r2 ×2) | 5 |
| Step icon (pixen ×8 + pro 64-candidate run + bold boots ×2) | 30 |
| Birds (×2 + loop) | 3 |
| **Total** | **98** |

Balance 266 → **167** (measured). Records, verdicts and rejected artifacts:
`GAME_BIBLE/ART/exploration/ACTIVITY_FEEL_01/`. Blind-staging leak recorded
as `MISTAKES.md` M-13.

## 10b. Known issues

- **BLOCKER:** none known.
- **GAMEPLAY / DESIGN:** durations (12/14/10 s) and the queue cap (20) are
  provisional pacing; Q-06 (persistent HP / rest) and the remaining Q-07
  bullets stay open; *Old Watch* / *Broken Tower* names are art-stream
  proposals awaiting the World Designer / owner.
- **COSMETIC** (all blind-QA MINOR notes, accepted): two foliage kits on
  the master read as different hands side by side (dark-outlined trees
  beside pale bushes); moor squiggle texture can read as scratches; the
  mine's rail run is long and unsupported; two small unnameable props
  (spiky object at the mine, grey blob at the ruined tower); the woodcut
  loop's recovery has a slight pop and the swing smear briefly swallows
  the axe; the mine loop keeps mild flecks; the forage read is soft
  without the node scenery beside it (the stage provides it); a boot can
  read as an equipment slot (adjacency to the step figure resolves it);
  `wipe_brow` frame-7 arm deferred.

## 11. Physical-device test script (owner)

1. **Mac:** pull the branch; `bash Scripts/ios/build-release-device.sh` —
   in place (`devicectl`); note TOTAL WALKED / banked / location before and
   after. Unplug.
2. Launch from the Home Screen: save intact (TOTAL WALKED, banked, spent,
   location, inventory, XP unchanged — no migration ran, there is none).
3. **Adventure at a gather node:** queue **×1** — the profession loop plays
   (~10–14 s), the bar fills, one completion grants once. Check the header:
   banked fell by exactly one cost; inventory +1; skill XP once.
4. Queue **×10** at Oak Stand: woodcutting swings loop, "Gathering n / 10"
   advances, cumulative gains accumulate; watch two completions.
5. **Stop mid-repetition:** completed repetitions keep their grants; the
   interrupted one spent and granted nothing.
6. Background the app mid-repetition, wait ~a minute, return: the bar
   resumes where it paused; nothing completed while away; queue another and
   force-quit mid-repetition, relaunch: no queue, nothing lost, nothing
   granted.
7. Switch tabs during a queue: it keeps working; return to Adventure and
   the progress is where it should be.
8. **Adventure at the Woods:** the wolf stands on its card, idling, before
   Start Combat.
9. Fight the wolf, watch the Attack beat: your strike lands → wolf HP
   drops → wolf's hit 1 → your HP drops → hit 2 → second drop. **No HP
   change before its animation, no heal-back.**
10. **World:** pinch all the way out — the whole landmass frames on the
    screen: alpine north, forest with the Hollow, purple moor, east coast,
    farmland south, walled Far Town. Judge §59's question 1: does the world
    feel meaningfully larger? Settlements small within it? Zoom in — the
    landmark names (Millbridge, Old Watch…) appear past the opening zoom.
11. Look for seams and black trees: there should be nothing to find.
12. The step icon beside every step figure: the teal boot, and its muted
    twin on costs/distances.
13. Force-quit and relaunch: everything intact.

Then stop — no dungeons, no REGIONAL_CONTENT_PACK_01.

## 12. Verification

`Scripts/verify.sh --strict` result recorded in §13a (first pass) and §13b
(correction pass).

## 13. Device Acceptance Correction Pass (2026-08-20)

The owner's physical-iPhone acceptance passed the milestone's core —
in-place install/save, exact per-completion step accounting, timed queueable
gathering with working animation and feedback, the combat choreography fix,
enemy preview, per-visit encounters, loot RNG (zero and multi-drop), the
Frost Lynx, rarity, and the new step boot (explicitly liked) — and returned
these corrections, worked inside this milestone:

1. **Finite queues progress across background/lock/relaunch** — owner
   ruling, canonical in `DECISIONS/0022_FINITE_BACKGROUND_ACTIVITY.md`
   (state v6, durable queue + wall-anchor reconciliation; the one named
   P-4 exception). The pause-on-background behavior shipped at `d6c4675`
   was wrong.
2. **Prerequisite gating** — an activity the player cannot legally complete
   (skill/tool) must not be startable; the 14-second guaranteed-failure
   animation the owner saw is the defect. Domain validation stays as
   defense in depth (it correctly spent nothing).
3. **Blank item art** — root cause found: WRD01 packaged `wolf_pelt`,
   `lynx_pelt`, `wolfhide_jerkin`, `frostlined_jerkin` icons but forgot
   BOTH the `pubspec.yaml` declarations and the `PixelIcons._itemIcons`
   entries, so every surface drew the deliberately blank `unknown` slab.
   Fixed; `test/item_icon_resolution_test.dart` now walks the real content
   pack and holds all three lists in agreement (every item resolves to a
   48×48 asset with real visible pixels).
4. **Defeat/retreat presentation** — a readable driven-back sequence
   (stagger → kneel → enemy holds ground → DRIVEN BACK), no death imagery;
   enemy defeat beat strengthened before Victory settles.
5. **World scale, again** — the master painting is re-authored so the
   playable region compresses into the middle of a larger continent
   (canvas and scale unchanged: the win is authored relative scale, per
   the correction brief §20/§24); full-width black label bars replaced by
   compact text-hugging capsules; more vibrancy and ambient life.

Frozen by acceptance (do not churn): rarity order/colours, the step boot,
combat HP timeline, enemy preview, activity durations, health, install.

### 13b. Correction pass — what shipped

- **Background-progressing queues (`DECISIONS/0022`, state v6).**
  `GameState.activityQueue` (node, requested, completed, durationMillis,
  anchorEpochMillis); `StartActivityQueue` / `ReconcileActivityQueue` /
  `StopActivityQueue`, each one event and one atomic commit; every queue
  completion resolves through the same `_resolveGather` validation and
  `applyGatherEffects` reducer path as a manual gather (a core test proves
  a 3-completion queue byte-identical to 3 gathers). Exactly-once: the
  event carries both the k completions and the anchor advanced by exactly
  k×duration, so a duplicate reconcile finds nothing owed and commits
  nothing. Backward clocks clamp to zero and never move the anchor. Stop
  reconciles first, keeps whole repetitions, discards the partial. The
  wall clock lives in one injectable seam (`StrideSession.activityWallClock`);
  `check-ui-boundary.sh` rule 5 carries a named 0022 exemption without any
  forbidden pattern weakening. Migration v5→v6 `rebasesEconomy: false`;
  `v6_baseline.save` frozen (v5 + the 21-byte null queue field); v1–v5
  fixtures byte-untouched. The card shows a compact "+N × item · +XP while
  away" line on return; no per-repetition popups.
- **Prerequisite gating.** `GatherEligibility` projection mirrors the
  engine's skill/tool checks; ineligible nodes disable presets, stepper
  and button with the concrete reason ("Requires Foraging 3 — you are 1")
  and an unmet `RequirementGate` state. Domain validation untouched
  (defense in depth; a forced dispatch still spends and grants zero).
- **Blank item art root cause.** WRD01 packaged the wolf_pelt / lynx_pelt /
  wolfhide_jerkin / frostlined_jerkin icons but forgot BOTH the pubspec
  declarations AND the `PixelIcons._itemIcons` entries — every surface
  drew the blank `unknown` slab. Fixed; `item_icon_resolution_test.dart`
  walks the real content pack and requires every item to resolve to a
  48×48 asset with real visible pixels.
- **Defeat/retreat presentation.** LostBeat now plays a PixelLab stagger
  (stumble → held one-knee kneel, east-facing, never a corpse), a 500 ms
  enemy-settle beat, and only then DRIVEN BACK; victory holds the enemy's
  defeat pose 700 ms before the panel. Skip-tap still lands on committed
  figures. No-loss retreat semantics untouched.
- **The continent master.** The world is re-authored again as one 384×688
  painting (scale 4 unchanged): the playable region is now a ~15% slice
  of a continent — west cordillera, forest and lakes, tundra, arid
  southern plains, island sea — with the hamlet, mine, tower, arched
  Millbridge, cave and tarn individually resolvable at max zoom (blind
  PASS-WITH-NOTE, decisive on §44's bar; round-2 candidate FAILED and is
  kept as evidence). Landmarks are now four (Broken Tower retired with
  the old moor). Chimney smoke (wisp-only crop) and a second bird flock
  join the overlays; coastal waves were generated, read as side-view
  surf, and are withheld.
- **Labels.** The fixed 184/150 dp black bars are gone: plates hug their
  text (measured width + 7 dp padding, chip corners, 0xC0 ink), the
  overlap test now asserts plate rects, and a short name's world
  footprint at the survey floor drops from ~736 to ~37 world px.

### 13c. Correction-pass verification

App suite **553** green on the merged tree (12 activity-queue controller
tests rewritten to the 0022 semantics, 5 prerequisite tests, 6 defeat
tests, icon resolution, label and landmark expectations); `stride_core`
**640** (+24 queue/codec/replay), `stride_storage` **108** (v6 fixture
and conformance transcript amended under their documented review
pattern); analyze clean. `Scripts/verify.sh --strict` on the settled
correction tree (2026-08-20): **All checks passed** — core 640, storage
108, app 553, health 143, secure_store 31; art packaging 472 files
`--check` clean; every guard and self-test green including the
0022-exempted UI-boundary rule.

## 13a. Result

`Scripts/verify.sh --strict` on the integrated tree (2026-08-20): **All
checks passed** — every guard and self-test green, `dart format` clean,
`stride_core` **613**, `stride_storage` **108**, app **531** (incl. the 12
activity queue/UI tests, combat presentation-order, encounter preview, and
the atlas scale-4 derivation/LOD suites), `stride_health` **143**,
`stride_secure_store` **31**; art packaging `--check` **457** files up to
date; 15 goldens regenerated (six screens ×2 sizes, combat stage, combat
victory) and reviewed by eye. One earlier strict run failed honestly on an
unused import left by the overlay-sweep test rewrite — the analyze gate
working, fixed and re-run in full.
