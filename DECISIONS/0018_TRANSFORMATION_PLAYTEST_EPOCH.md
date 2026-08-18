# 0018 — The Transformation playtest begins at a second epoch, and re-basing becomes a named table step

**Status:** Approved
**Date:** 2026-08-17
**Owner:** project owner — explicit direction via the Transformation Build 01 master prompt
**Supersedes:** nothing
**References:** `DECISIONS/0016_ECONOMY_EPOCH_CUTOVER.md` (the mechanism this
extends, unchanged in principle)
**Amends:** `DECISIONS/0012_SAVE_FORMAT.md` — state version 3

---

## Context

`DECISIONS/0016` retired the Phase 1 validation balance (459,043 banked) by
recording an `EconomyEpoch` — a mark on both running totals — and measuring
`banked` from it. It shipped as state version 2 and was confirmed on device:
`TOTAL WALKED` 464,946, playable banked **5,723** at the first Phase 2 launch,
**5,123** after some travel and spending
(`MILESTONES/FRESH_CHAT_HANDOFF_2026_08_17.md` §3).

Those 5,000-odd steps are, again, real — and again they were walked to validate
an integration, not to play a game. The Transformation Build is the first build
intended to *feel like a game*, and the owner has directed that **the next
physical playtest must begin with zero spendable steps**, on these terms:

- historical health and grant accounting stays intact;
- the cursor is forward-only — not rewound, not advanced;
- old steps cannot be re-granted;
- new steps walked after the reset become spendable exactly once;
- `totalGranted` is not lowered, the ledger is not replaced, no background sync
  is added, and no invariant or guard is weakened.

0016 anticipated this and said what it would cost: *"A second epoch would need
its own decision and would have to answer this question again, less easily."*
This is that decision. `RULES.md` P-5 says the same, and this decision is
listed there.

## The constraint

The same three laws bind as in 0016 — **H-2** (granted is monotonic, no
clawback), **H-3** (the cursor prevents double-counting), **P-5** (nothing
decays, earned opportunity never expires) — and one new fact does:

> **The ledger has already been re-based once.**

0016's exactly-once defence inside the command was *"refuse any non-origin
epoch"*. That guard cannot express "re-base a v2 epoch once, then refuse a v3
one": relaxing it to "re-base whatever is there" would let a v3 save be zeroed
again the day any caller asked, and keeping it means the second cutover can
never run at all. So the mechanism has to learn **which migration set the
mark**.

And 0016's migration path was a single branch — *if the save is older than
current, establish the epoch*. That was correct for one migration and becomes
dangerous the moment a second version exists: with the branch as written, a
future v4 that only added a field would zero a balance as a side effect of a
format bump.

## Decision

**State version 3. The same `EconomyEpoch` mechanism as 0016, applied a second
time by an explicit migration-table step that names this decision; the epoch
records the state version whose step established it, and the command refuses
to re-base at or below that version.**

```text
banked = (totalGranted − epoch.grantedAtStart) − (totalSpent − epoch.spentAtStart)
```

The formula does not change. What changes:

1. **`EconomyEpoch.establishedAtStateVersion`** — `0` for the origin, `2` for
   the Phase 2 cutover, `3` for this one. Persisted in `steps.epoch` from state
   version 3. The v2 decoder maps a non-origin mark to `2` (the only re-basing
   step that existed while v2 was current) and the origin to `0`; the v3
   decoder reads the field. A journal record of `EconomyEpochEstablished`
   without the new `toStateVersion` field decodes as `2` for the same reason.

2. **`EstablishEconomyEpoch(fromStateVersion, toStateVersion)`** refuses when
   `epoch.establishedAtStateVersion >= toStateVersion`. So the v3 step re-bases
   a v2 epoch exactly once and refuses a v3 epoch; the v2 step re-bases the
   origin exactly once and refuses a v2 epoch. This is still *defence behind
   the version* — the state version remains the only durable exactly-once
   signal, and a v3 save never enters `_migrate` at all.

3. **`StateMigrations` — an explicit table**, one step per version bump, each
   declaring `rebasesEconomy` and the `DECISIONS/` document that authorised it.
   `BootstrapCoordinator._migrate` walks `pathFrom(save.version)` and issues
   `EstablishEconomyEpoch` **only** for steps that say `rebasesEconomy: true`.
   A future v3→v4 that only reshapes says `false` and touches no balance;
   re-basing can never again happen by accident of being newer.

   | Step | Re-bases | Decision |
   |---|---|---|
   | v1→v2 | yes | `0016` |
   | v2→v3 | yes | `0018` (this) |

4. **One commit for the whole path.** A v1 save walks v1→v2 and then v2→v3 in
   one launch, and both events land in a single transaction. Two commits would
   make representable a durable save at an intermediate version carrying a
   later step's epoch — after a crash between them — which is exactly the shape
   the command would then refuse forever.

5. **The retired body stays reportable, in whole and in part.**
   `EconomyEpoch.retiredSteps` is still `grantedAtStart − spentAtStart` of the
   current mark — everything ever banked before the playable economy began
   (459,043 + 5,123 on the owner's device). The event additionally carries
   `previousGrantedAtStart / previousSpentAtStart`, and
   `StateMigrationReport` reports `retiredSteps`, `previouslyRetiredSteps` and
   `newlyRetiredSteps`, so the acceptance script can compare the launch's
   figure against the balance it saw before upgrading. `TOTAL WALKED` remains
   `totalGranted`, unchanged.

6. **The v2→v3 step runs after the first foreground sync, not at bootstrap.**
   Owner-confirmed on the first device review of this build, 2026-08-17. The
   step declares `afterFirstReconcile: true` (`StateMigrationStep`), and the
   mechanism is in the next section. The property it buys: at the cutover the
   spendable balance is zero, lifetime accounting is intact, and **only
   walking after the cutover is spendable** — the steps walked between the
   owner's last Phase 2 sync and this launch (the unsynced backlog) are inside
   the retired body, not on top of it.

## Mechanism: the deferred step

### The defect it corrects

The epoch marks the ledger's *current* totals. Bootstrap runs before the first
frame; the startup foreground sync runs *after* the first frame
(`SessionController.startupSync`, `RULES.md` H-5). So a bootstrap-time v2→v3
mark was taken from totals that did not yet include the backlog, and the first
sync then granted the backlog **past** the mark — spendable. On the owner's
device that would have been a playtest beginning at "whatever I walked since
the last Phase 2 sync" rather than at zero. That is not what was directed.

### What happens instead

- `StateMigrationStep.afterFirstReconcile` — a per-step property, false by
  default; true for v2→v3, false for v1→v2 (which ran at bootstrap and whose
  saves are already durable).
- `BootstrapCoordinator._migrate`: when any step on the save's remaining path
  says so, bootstrap **commits nothing**. It returns `BootstrapExistingGame`
  with the engine at the save's on-disk version and `pendingMigration` — the
  whole path — and `expectation` is the load's own head. **The whole path is
  deferred, not the tail**: a v1 save is not committed at v2 in between, so
  the migration stays one commit (§4). It costs nothing: v1→v2 would retire the
  Phase 1 body either way and v2→v3 then finds nothing further to add.
- `StrideSession`: `migrationPending` is true; `isReady` is false, and gather,
  travel and craft refuse with `session_not_ready`; `canSync` is true and
  `syncSteps` runs. After `_syncSteps` returns — reconciled, nothing new,
  unavailable, or denied alike — the session applies the pending path to the
  **post-sync** state (`PendingStateMigration.apply`, the same routine the
  bootstrap-time path uses) and commits it once through the ordinary commit
  path, with the expectation the sync's own commit already advanced. On
  `CommitDurable` the engine is swapped, `migration` is populated
  (`bankedAfter == 0`, the backlog inside `newlyRetiredSteps`), pending clears.
- `usableEnergy` **projects zero while pending**, and `destinations` prices
  against that projection. The step is deterministic and lands within a second
  of the first frame; showing 5,123 for that second would flash a balance the
  player is about to watch vanish. This is the session's job as the projection
  layer, not a UI's — no widget knows a migration exists. It cannot mask a
  failed migration: a refused migration commit marks the session stale, and
  `reload` re-enters the pending state from disk. `totalGranted`, `totalSpent`
  and `retiredSteps` are not projected; they are history and the cutover moves
  none of them.
- The developer harness renders "migration pending" and then the report, so
  the acceptance script sees the order rather than inferring it.

### Exactly once, crash safety, idempotence

Unchanged in principle: **the state version is still the only signal.**

- The first sync's commit is written while the in-memory state is still v2.
  The codec writes `state.stateVersion` into both the header and the payload,
  and the v2 decoder derives `establishedAtStateVersion` from the marks exactly
  as it did before this build — so the next launch reads a v2 save
  (`transformation_epoch_test.dart` group 6).
- **Crash between the sync's commit and the migration's commit:** the next
  launch reads a v2 save whose cursor and totals already include the backlog,
  re-enters the pending path, its first sync grants nothing new (H-3, the
  slices), and the migration completes then with the same mark
  (`transformation_epoch_test.dart` 5(d); `deferred_epoch_session_test.dart`
  (d)).
- **Crash before the sync's commit:** nothing was written; identical to a
  fresh first launch.
- **The migration's commit is refused:** the session goes stale like every
  other refused commit — startup is not blocked. `reload` finds a v2 save and
  re-enters pending; the controller's reload follows with a sync (which grants
  only what the disk has not recorded) and completes it. A relaunch does the
  same.
- **The sync's commit is refused:** the session is stale and the migration is
  not attempted; reload re-enters pending and the sync re-fetches from the
  durable cursor.
- A v3 save never enters `_migrate` and never carries `pendingMigration`; the
  command's `establishedAtStateVersion` guard is still the defence behind the
  version.

### The accepted edge

If health **cannot be read at all** at the cutover — service absent,
permission denied, an adapter fault — the sync observes nothing, and the epoch
marks the totals as they stand, *without* the backlog. If that backlog is later
drained it will be spendable. This is an unavoidable consequence of not being
able to observe the backlog, **not a design intent**: the migration cannot wait
for a sync that succeeds, because that would hold the player unable to act
until health cooperates — which the game must never do
(`startup_sync_test.dart`, "an unavailable health source still loads the
game"). The alternative — a `PendingStateMigration` that survives launches
until a sync succeeds — is exactly the second-mechanism-beside-the-version this
decision and 0016 reject. On the owner's device health is available, so this
edge does not arise for the cutover this decision exists for.

Nothing is subtracted, deleted or rewound. `totalObserved`, `totalGranted`,
`totalSpent`, `grantedSlices`, `grantedBeforeWatermark`, the cursor, the
per-origin watermarks and the sync count pass through byte-identical — asserted
by rebuilding the migrated ledger with the *previous* epoch put back and
comparing the whole canonical encoding (`transformation_epoch_test.dart`, group
2). A replay of the last pre-reset batch grants 0; a new batch grants exactly
once; spending debits the new balance and never goes below 0 (group 3).

## How this squares with P-5

Honestly, less easily than 0016 — because "once" is now "twice", and the second
time is what a reader will point at.

The test P-5 sets is not the count. It is whether a mechanism exists that takes
back what a player earned **as a consequence of time passing or of absence**, or
that will fire again on its own. None does:

- This is a single, deliberate, **owner-authorised** re-basing of one specific
  body of Phase 2 device-validation data (5,723 banked at first launch, ~5,123
  later), at a defined point — the first "feels like a game" playtest — before
  any player has played. It is not time-triggered, not absence-triggered, and
  not recurring: it happens on the launch that migrates a v2 save to v3, and
  on no launch after that.
- It is not reachable except by adding a table step that names its own
  decision. There is no button, no flag, no debug action, no second caller.
- The retired steps stay reportable, in total and by launch.
- Nothing walked *after* the reset is ever affected — that is the whole point
  of `establishedAtStateVersion` and the refusal that reads it.

**P-5 is unamended and applies in full going forward.** A third epoch would
need a third decision, and the burden rises again: it would have to explain why
a build that "feels like a game" still needed its validation walking retired.
The expectation set here is that it will not.

## Alternatives considered

| Option | Why not |
|---|---|
| A dev-harness "reset balance" button | Accidental and unauditable. It would be a second caller for a command that zeroes a player's balance, outside any transaction the version guards, with no durable record of *which* reset happened. 0016 was explicit that this command must have exactly one caller. |
| A boolean flag or a settings entry ("re-based for Transformation") | The mechanism 0016 rejected, one version later: two records of one fact, which eventually disagree. The state version is already durable, already header/payload-checked, already what a decoder is chosen by. |
| Reuse state version 2 — re-base again without a version bump | There would then be no durable exactly-once signal at all: a v2 save on disk cannot say whether it has been re-based once or twice, and the migration would run on every launch or on none. |
| Relax the command to "re-base whatever epoch is there" | Zeroes a v3 save again the day any caller asks. `establishedAtStateVersion` is the minimum that lets the guard be precise. |
| Keep the single `_migrate` branch and just bump the version | Works for this migration and makes the *next* format bump a balance reset by default. The table is what makes re-basing opt-in per step. |
| Subtract from `totalGranted`, raise `totalSpent`, a fresh ledger, rewind the cursor | Rejected in 0016 for reasons that have not changed (H-2, H-3, conflating facts). Rejected again by owner direction. |
| Two commits for a v1 save (v1→v2, then v2→v3) | Representable crash state: a durable v2 save with a v3 epoch, refused forever. One commit makes it unrepresentable. |

## Consequences

- `StateVersion.current` = 3; `minimumSupported` stays 1. `StateCodecs` gains
  `V3StateDecoder`; the v1 and v2 decoders are frozen and untouched.
- `steps.epoch.establishedAtStateVersion` is persisted: one small integer,
  reviewed for privacy (`save_privacy_test.dart`) — a fact about the save
  format, not the player, carrying nothing health-derived.
- `EconomyEpochEstablished` gains `toStateVersion` (load-bearing) and
  `previousGrantedAtStart / previousSpentAtStart` (diagnostic). Old journal
  records without them decode as `2` / origin.
- The frozen `v1_baseline.save` and `v2_baseline.save` are **unchanged**. v2's
  round-trip test becomes decode-only, exactly as v1's did in 0016, and a new
  frozen `v3_baseline.save` — the v2 fixture put through the real v2→v3 step by
  `tool/generate_v3_baseline.dart`, run once — carries the byte-exact round
  trip forward. It is 30 bytes longer than v2: exactly
  `"establishedAtStateVersion":3,`.
- The persistence conformance transcript's two slot digests moved. Every
  behavioural line above them is byte-identical, including the journal digest;
  both slots grew by exactly the 30 bytes of
  `"establishedAtStateVersion":0,` — checked, not accepted.
- `StateMigrationReport` gains `previouslyRetiredSteps`, `newlyRetiredSteps`
  and `stepsApplied`. The developer harness renders it beside the energy
  figures on the launch that migrates.
- `RULES.md` P-5 and H-2 point here as well as at 0016. `OD-01` in
  `JOURNAL/OPEN_QUESTIONS.md` gains a note.
- `StateMigrationStep` gains `afterFirstReconcile`; `BootstrapExistingGame`
  gains `pendingMigration`; `PendingStateMigration` and
  `applyStateMigrationPath` are the one implementation of "run the table",
  shared by the bootstrap-time and deferred paths. `StrideSession` gains
  `migrationPending`, `canSync`, `migrationRefusal`; `migration` becomes a
  getter filled by the first sync. `SessionController.startupSync` gates on
  `canSync`, and its `reload` follows a re-entered pending state with a sync.
- The frozen fixtures are still unchanged, and `tool/generate_v3_baseline.dart`
  is unchanged: it applies the v2→v3 step directly to the v2 fixture with no
  sync, which is exactly what the deferred path applies after a sync that
  observed nothing, so the fixture is the same bytes.
- On this build the v1→v2 cutover no longer lands at bootstrap either: a v1
  save's whole path is deferred with v2→v3, in one commit after the first sync.
  `phase2_migration_bootstrap_test.dart` is adjusted to drive that completion.

## Follow-up

- **On device:** the first launch of a Transformation build over the Phase 2
  save should show the pending line, then — after the startup sync — report
  `v2→v3; steps=1; retired=464,166+N (previously 459,043, newly ~5,123+N);
  banked=0`, where N is whatever was walked since the last Phase 2 sync, and
  `TOTAL WALKED` should read 464,946+N. Usable energy reads 0 from the first
  frame. The second launch must report no migration and no pending state.
- A pre-existing edge, unchanged in principle and noted for the record: if a
  migration's journal append succeeds and its snapshot write does not, the
  next launch replays the epoch event over the older snapshot — the reducer
  moves the epoch, not the version — and the state is then an old-version
  save carrying a current-version epoch. It re-enters the pending path, and
  after the first sync the command refuses (`economyEpochAlreadySet`); the
  session reports `migrationRefusal`, stays unready for actions, and does not
  play. Under the bootstrap-time path the same shape blocked startup
  (`stateMigrationNotCommittable`). Either way it is a refusal, not a wrong
  balance, and it is left as it is rather than fixed here without a decision.
