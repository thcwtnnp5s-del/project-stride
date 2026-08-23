# PLAYABLE_EXPERIENCE_REFINEMENT_01

**Status:** 🚧 Implementation complete — accounting blocker resolved (not reproduced;
mechanism identified and instrumented), presentation refinement delivered; awaiting the owner's device test.
**End HEAD:** see the closing commit. **Commits:** `979482d` (accounting) · `a4c7ae9` (presentation) · `157ceef` (art) · the docs commit. **Push status:** not pushed — owner review first.
**Branch:** `playable-phase-2-multiregion`
**Start HEAD:** `a1ff92b`
**Owner brief:** delivered 2026-08-22, verbatim in the session that opened
this milestone. This record is the repo-canonical distillation
(`RULES.md` G-5).

## What this milestone is

A refinement milestone. The owner has now played the physical-device build
for meaningful time and ruled the game **functionally strong enough to
refine rather than expand**. No new feature systems: no profession, dungeon,
skill tree, shop, currency, enemy-roster expansion, continent, multiplayer or
monetisation. The current activities, UI, animations, rewards, combat,
crafting, jobs and progression are to feel cohesive, intentional and
satisfying on a phone.

The architecture of `PRESENTATION_WORLD_REWARD_FEEL_01` is preserved whole:
one shared location/work stage, compact activity and encounter rows, the
Goal Board behind one button, the craft categories / compact rows / one
detail panel / timed queue / forge and cookfire loops, the large pannable
atlas with future landmarks.

## §0 — The accounting blocker

### The observation

About 3,000 banked → defeat away from Haven → retreat to Haven's Rest → the
app fully closed → reopened → the bank reads about 6,000. Treated as a
blocker against H-1/H-2/H-3 (four distinct concepts; granted is monotonic;
a cursor is durable only after commit) until proven otherwise.

### What was traced

The whole real data path, before any test was written:

- **Defeat / retreat reducer** (`event_reducer.dart` `EncounterLost`,
  `EncounterRetreated`): `clearEncounter`, `world.movingTo`, HP restore.
  `GameState.steps` is carried by `copyWith` untouched.
- **The defeat commit** (`stride_session.dart` `_combatRound` → `_commit`):
  every command commits `after: active.state` — the **current** full state,
  ledger included — as one journal record plus a snapshot to the stale slot.
  No path writes an older accounting snapshot.
- **Save load** (`save_repository.dart` `_load`): newest verified generation
  wins; equal generations that differ refuse; the journal tail past the
  snapshot's `lastAppliedTransaction` is replayed through the same reducer.
  A replayed `StepsGranted` is applied exactly once because the snapshot it
  lands on is the one written *before* it.
- **The sync** (`_syncSteps`): the cursor is read from the ledger on every
  page; `StepCheckpointAuthorized` is the last event of a reconcile; a
  committed page is what moves it (H-3).
- **The reconciler** (`reconciliation.dart` `_apply`): per
  `(origin, bucket)` slice, `newlyGranted += max(0, observed −
  alreadyGranted)`. A restated slice with the same figure is a zero delta.
  A settled slice (behind its origin's watermark) grants nothing and counts
  as `lateDiscarded`.
- **The native adapter** (`HealthKitStepStore.swift`): an anchored query
  *discovers* affected buckets; an `HKStatisticsCollectionQuery` with
  `.cumulativeSum, .separateBySource` *restates* them as absolute per-source
  totals. Width is clamped to ≥ 1 h on both the discovery and the recovery
  path, anchored at the Unix epoch, so bucket keys cannot drift between
  syncs. Recovery offers no replacement anchor until it commits.
- **State v8 migration**: `clearsStaleTrackedContract` only; no ledger
  field read or written. It is not deferred past the first sync.
- **Startup sync** (`SessionController.startupSync`): once, guarded, after
  the save is rendered from disk; manual sync is the same call.

### Regression coverage — `test/step_regrant_after_defeat_test.dart`

Eleven cases over the **real** `StrideSession`, the real repository and file
layout in a temp directory, with `MockStepSource` serving the *same* Health
samples again and again. A "restart" is a brand-new `StrideSession.start`
over the same root.

| Case | Sequence | Result |
|---|---|---|
| A | same samples → restart → same samples | **0** granted |
| A′ | same hour through the *recovery* (cursor-invalidated) path | **0** |
| B | same samples → defeat → save → restart → same samples | **0**; location Haven; HP restored; nothing lost |
| C | same samples → defeat → manual sync before restart | **0**; restart after it **0** |
| D | defeat → 4 relaunches, startup + manual sync each | **0** every time; `totalGranted` constant |
| E | then the same hour grows by 500 and a new hour brings 700 | **500** then **700**, exactly once; replay and a third launch **0**; cursor forward-only (`c3`) |
| — | adapter reads | only on explicit sync: 0 reads across defeat, projections and relaunch until `syncSteps` (H-5) |
| — | economy epoch | identical across defeat and relaunch; `totalSpent` = the travel debit alone |
| — | equipment | the worn tunic and the bagged sword survive defeat and relaunch |
| — | characterisation | two origins for the same hour → **both credited** (3,000 + 3,000 = 6,000), stable on replay |
| — | instrument | the source count persists with the ledger and survives relaunch; the banner carries the sync's own count |

All pass. Existing suites `startup_sync_test`, `sync_reward_test`,
`combat_session_test` pass alongside.

### Verdict: NOT reproduced at the accounting boundary

The Dart ledger, the defeat path, the save protocol and the reconciler
cannot re-grant identical samples under any of the sequences the owner
described. No accounting or persistence code was changed.

### How the physical bank can increase by ≈ the same amount

**A second HealthKit step source.** The ledger keys credit by
`(origin, bucket)`, deliberately (H-1: per-origin watermarks are what keep
an offline watch's backlog grantable). The native restatement uses
`.separateBySource` and sums **each source's own total**. HealthKit's
merged "Steps" figure — what the Health app shows — de-duplicates the
overlap between an iPhone and an Apple Watch (or any app that writes step
samples: a tracker, a running app). The per-source sum does not. A walk
recorded by two sources is therefore banked by both, by arithmetic, not by
fault.

Why it looks like "relaunch re-grants today's steps": an Apple Watch
delivers its samples to the phone lazily, in batches, often minutes to hours
later. The startup sync after a relaunch is exactly when the anchored query
first sees those samples, under a second origin, for hours the phone's own
sensor had already been credited for. A bank that reads ≈3,000 and then
≈6,000 — close, not identical — is the signature of two sensors counting
the same walk. The defeat is coincidental; any relaunch (or manual sync)
after the watch synced would show the same.

The characterisation case reproduces exactly this shape through the real
session, and the bank is stable afterwards (a third replay grants nothing),
which matches "it happened once, not on every relaunch".

### Instrumentation (shipped, H-7 compliant — counts, never identities)

- `StrideSession.ledgerOriginCount` — distinct origins in the persisted
  granted slices; survives relaunch.
- Character screen, *What walking has built*: `Total walked` reads
  `steps earned · 2 sources` when more than one source has been credited.
- Adventure sync line: `+3,000 steps banked · 2 step sources` when the
  sync read from more than one.
- The held `+N STEPS BANKED` banner: `Counted from 2 step sources` beneath
  the figure, from the banner's own copy of the count.

### What is deliberately not done

De-duplicating across sources is a **design decision**, not a fix: the
per-origin keying is what the H-1 multi-device safety argument rests on, and
replacing it with HealthKit's merged total trades that safety (a watch
backlog arriving after a bucket is settled would be lost) for de-duplicated
totals. It is recorded as **Q-08** in `JOURNAL/OPEN_QUESTIONS.md` with the
options and a recommendation, for the owner (`RULES.md` G-3, G-4).

### Device acceptance for §0

1. Character tab → *What walking has built* → does `Total walked` read
   `· 2 sources`? If yes, the mechanism is confirmed.
2. Settings › Health › Data Sources & Access (or the Steps data sources
   list) — is there a Watch or a second app writing Steps?
3. If `1 source` and the bank still doubled, send the Character tab figures
   (`Total walked`) before and after one relaunch; that rules this out and
   the native anchored path becomes the suspect.

## §1–§46 — Presentation refinement

### The one reward language (§29, §31, §32) — `lib/ui/components/reward_beat.dart`

Every gameplay result now fits one of three tiers, rendered by one
component:

| Tier | Treatment | Used for |
|---|---|---|
| **MINOR** | a quiet block: eyebrow · title · one or two fact lines | a single gather, a finished gather queue, a component or meal craft, ordinary combat XP and materials |
| **MEDIUM** | a framed beat in its own accent (rarity ink or skill/step accent), heading weight | a level-up (`LevelUpCard`), finished equipment, a knowledge stage (Seen → Studied → Known), a contract handed in |
| **MAJOR** | the same frame, card-title weight, a 2 px rule | a project completed, a significant discovery, a signature item (the board's existing major panel keeps its place; no new major event was added) |

`LevelUpCard` is the universal level-up — LEVEL, WHAT UNLOCKED, WHY IT
MATTERS — placed by gathering, crafting and combat alike, never appended to
whichever surface triggered it. `StaggeredReveal` is the one choreography:
beats resolve top to bottom on a single clock (260 ms a beat, 110 ms
stagger), reduced motion arrives finished, nothing loops or waits to be
opened (`RULES.md` P-6).

**Transient by contract.** A beat is built from the command's report and
clears when its owner clears it: MINOR on the existing result timers
(5–6 s), MEDIUM held until acknowledged (`CraftController.dismissSummary`,
`ActivityController.dismissSummary`, the combat `Continue`) or displaced by
the next command. No surface can accumulate old result text.

### Adventure (§5, §8, §20, §21, §22)

- **Scene titles removed.** The card-title overlay (`COPPER SEAM`, `MEADOW
  PATCH`) is gone from both stage modes; the place is the header eyebrow
  and the activity is the selected row. The painting breathes.
- **Locked selection is intentional.** A selected activity whose
  prerequisites fail composes the scene (the player asked to look at the
  seam) but never plays the working loop, sits the resource back under a
  shadow, and states the one gating fact on the stage
  (`Needs a pickaxe` / `Requires Mining 3`). Projected from
  `gatherEligibilityOf`, the same rule the disabled control reads.
- **Encounter rows**: the open row's border takes the step accent's dim
  form; otherwise unchanged. The one-expanded-row architecture stands.
- **HP in the step band**: one consistent rule — shown wherever a fight is
  possible or whenever below full; hidden only at full health in a safe
  place. It stays a fact in the band, after the step figures and in the same
  role, so it is subordinate to Banked Steps.
- Vertical rhythm: no change to spacing tokens; the stage's removed caption
  is the only geometry change.

### Gathering (§6, §7, §9, §10, §14)

- **Backdrops (PixelLab).** Six `create_image_pixen` generations at
  384 × 176; two accepted, four rejected with reasons
  (`GAME_BIBLE/ART/exploration/PLAYABLE_EXPERIENCE_REFINEMENT_01/out/stage/README.md`).
  Stonefall now has a natural slate face with copper streaks, timber props
  and lintel, a lantern, rails low at one side, scattered stones and a
  receding shaft mouth; the Woods clearing has open ground where the oak
  stands, a log stack, trunks in the middle distance and the deeper wood in
  haze. Meadow Patch is preserved. `package-art.js` reads them from the new
  source directory.
- **Contact, reviewed in context** (`test/stage_evidence_test.dart`, the
  env-gated harness that renders the real stage at phone width and writes
  every loop frame): the pick head lands on the seam with chips at the
  contact point, figure and seam share one ground line, no foot slide, no
  prop jump across the wrap, prop scale consistent across Copper, Tin and
  Hardened. No frame repair was needed for mining or woodcutting.
- **Craft loops**: the smith and cook sources both end tool-low and begin
  tool-raised, so a hard wrap popped the tool. Both now play ping-pong
  through the same frames (frame-order authoring, `RULES.md` A-2; the same
  treatment foraging already had). The cook bowl/implement separation and
  the prop-perspective note remain cosmetic (see Remaining).
- **Queue completion**: `GATHERING COMPLETE · N repetitions completed ·
  Item ×N · +XP` as a MINOR beat, the away-line folded in as a fact, the
  `LevelUpCard` beneath it when the queue crossed a level (the controller
  now reads `skillLevelBefore/After` and `unlockedNames` from every
  reconcile report), and held for a tap only then. A single gather is the
  same beat with the eyebrow `GATHERED`.

### Crafting (§12, §13)

- **Completion is a beat, not a log line.** MINOR: `CRAFTED · Oak Plank ×1 ·
  +12 Smithing XP`, on the 6 s timer. Equipment: MEDIUM in the item's rarity
  ink — name, `Attack 3 → 7`, the XP, Equip right there. A level-up is the
  `LevelUpCard` beneath either. MEDIUM and level-ups are held until OK, then
  the clean recipe detail returns. Components are never as loud as gear.

### Combat (§16–§19)

- **Choreography**: the stage still plays the fall and the settle first
  (unchanged, `combat_presentation_order_test`); the panel then resolves
  VICTORY · *falls* → EXPERIENCE → REWARDS → knowledge → level-up → bounty
  progress → Continue on one clock, well under a second, skippable by
  Continue at any point.
- **Hierarchy**: XP and ordinary drops on the quiet ground; a rare row is
  loud only through its rarity frame; a knowledge stage is a MEDIUM beat
  (`FOREST WOLF / STUDIED / NEWLY UNDERSTOOD: Wolf Pelt, Meadow Herb /
  SIGNATURE: ???`; `KNOWN` reveals the signature name); the character level
  is the universal card (`TRAVELER LEVEL 2 · +2 Max HP`); bounty progress is
  one small line. `WonBeat` now carries the knowledge crossing (from the
  event's own `victoriesAfter` against the enemy's thresholds), the
  knowledge XP, the drop names by class, and bounty progress — all from the
  committed event and content, nothing re-derived from a state diff.
- **Defeat**: `Driven back / Retreated to Haven's Rest / Nothing was lost.`
  plus `Rested and recovered at Haven's Rest.` when the safe arrival healed
  (`LostBeat.healed`, from the event's `restoredHp`). Quieter heading than a
  win; never punitive, never death.

### Goal Board (§24–§27)

- **Rows**: the type is a restrained chip — a 6 px mark and the word, in the
  type's ink (ORDER: step accent dimmed; BOUNTY: the Rare blue the
  encounter rows use; CONTRACT: the quest category ink). No card themes.
- **Expanded state**: unchanged architecture — one open job, brief,
  requirements, reward, actions.
- **Project density**: the tile is title + STAGE chip, the material rows
  with bars, the consequence line, Contribute / Track; the lore is one
  `About this project ▸` line that opens on request.
- **Contribution feel**: the `held / required` figure pulses once when it
  changes (keyed on the progress, so a rebuild plays nothing) while the bar
  eases beneath it. Stage and project completion keep their held panels.

### Not changed, deliberately

Inventory (§30) — no layout bug was found in the suites or goldens; not
touched. The atlas (§35) — untouched. Colour (§37) — no new hue; the three
type inks are existing palette entries. No mechanic, content, economy,
Health or persistence change anywhere in §1–§46.

## Verification

- **Accounting**: `test/step_regrant_after_defeat_test.dart` (11 cases,
  above) plus `startup_sync_test`, `sync_reward_test`, `combat_session_test`.
- **Presentation**: `rarity_ui_test` (level-up beat), `combat_ui_test`,
  `combat_presentation_order_test`, `combat_stage_test`, `goal_board_test`,
  `craft_flow_test`, `gather_queue_ui_test`, `gather_prerequisite_gate_test`,
  `phase1_ui_test`, `fold_clearance_test`, `ui_responsive_test`,
  `encounter_card_test`; goldens regenerated and reviewed
  (`phase1_adventure`, `phase1_adventure_large`, `combat_victory`);
  `stage_evidence_test` as the in-context stage harness.
- **Full suites**: app **613**, `stride_core` **684**, `stride_health` **143**, all passing. `stride_storage` **103 of 108**: the five cross-process lock probes (`concurrency_test` 6, `linux_lock_semantics_test` 2–3, `closure_probes_test` S2) fail on this Windows machine today, alone and outside the sandbox alike — each spawns a second `flutter_tester` process as the lock holder, and that child dies with `Could not prepare isolate / Could not create root isolate / Could not launch engine`, so the probe never sees a held lock. A toolchain fault in launching a second engine, not a lock-semantics result. The package is byte-identical to the start HEAD (`git diff a1ff92b HEAD -- packages/stride_storage` is empty), so this is an environment finding, recorded under Remaining, not a regression of this milestone.
- `flutter analyze lib test` clean; `package-art.js --check` clean.

## Remaining

**BLOCKER** — none. The §0 observation is explained and instrumented;
confirmation needs the owner's device (Character tab source count).

**GAMEPLAY / DESIGN**
- Q-08: the two-source de-duplication policy (owner decision).

**VERIFICATION**
- `stride_storage`'s five cross-process lock probes cannot run on this
  machine today: the spawned holder `flutter_tester` fails to create its
  root isolate (see Verification). Untouched package; run on the Mac or CI
  — and check the local Flutter engine artifacts — before anything is
  concluded about the locks themselves.

**COSMETIC**
- The cook loop's bowl/implement relationship and the forge prop's slight
  perspective difference from the Traveler: visible on enlarged frames,
  not at device scale; a PixelLab frame pass when the craft stage is next
  touched.
- The `About this project ▸` affordance is a text toggle; a chevron glyph
  from the nav set would be tidier.

## Device acceptance — one thing at a time

1. Character tab → *Total walked*: does it say `· 2 sources`?
2. Select Hardened Copper without a pickaxe: shadowed seam, the gate on the
   picture, no work loop.
3. Run a Tin queue of 10 to the end: one `GATHERING COMPLETE` beat, then it
   clears.
4. Craft a Bronze Sword: the rarity-framed reveal with the stat delta and
   Equip, held until OK.
5. Beat the wolf for the third time: `FOREST WOLF / STUDIED` beneath the
   rewards.
6. Lose a fight: `Driven back / Retreated to … / Nothing was lost.`
7. Goal Board: the three chip inks; open the Mill — short tile, `About`
   opens the lore.
