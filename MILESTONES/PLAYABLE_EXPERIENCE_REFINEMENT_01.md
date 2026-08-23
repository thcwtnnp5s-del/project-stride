# PLAYABLE_EXPERIENCE_REFINEMENT_01

**Status:** 🚧 In progress — accounting blocker resolved (not reproduced;
mechanism identified and instrumented), presentation refinement underway.
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

Recorded as the work lands; see the final report at the end of this
document.
