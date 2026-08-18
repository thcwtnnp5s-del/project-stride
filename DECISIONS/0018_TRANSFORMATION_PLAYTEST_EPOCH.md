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

## Follow-up

- **On device:** the first launch of a Transformation build over the Phase 2
  save should report `v2→v3; steps=1; retired=464,166 (previously 459,043,
  newly ~5,123); banked=0`, and `TOTAL WALKED` should still read 464,946 (plus
  whatever was walked since). The second launch must report no migration.
- A pre-existing edge, unchanged by this decision and noted for the record: if
  a migration's journal append succeeds and its snapshot write does not, the
  next launch replays the epoch event over the older snapshot and then enters
  `_migrate` again, where the command refuses and startup blocks
  (`stateMigrationNotCommittable`). This was already true under 0016. It is a
  refusal, not a wrong balance, and is left as it is rather than fixed here
  without a decision.
