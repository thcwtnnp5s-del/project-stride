# Decision: A tracked Contract slot may only hold work the player is actually pursuing, and existing saves are repaired once

**Status:** Approved (owner device report, PRESENTATION_WORLD_REWARD_FEEL_01
correction round, 2026-08-21)
**Date:** 2026-08-21
**Owner:** Project owner; implemented by Studio Stride

## Context

`DECISIONS/0023` gave the player three tracked-objective slots, one of which
holds a Contract. Contracts at a location rotate: completing one draws the
next from the authored deck, and a *repeatable* contract can be re-offered as
a fresh instance under the same `ContentId`.

Nothing cleared the slot on completion. The tracker therefore kept pointing at
the id, the board re-offered that id as a new instance, and the tracker
re-read the new instance's untouched counters as if they were the player's own
progress. The owner's device showed **Wolf Problem — Forest Wolf defeated
0 / 3** for a contract completed and claimed days earlier.

PRESENTATION_WORLD_REWARD_FEEL_01 fixed the reducer, so no save written by
that build or later can acquire the residue. It did not — and could not —
help the save already on the phone: the completion that should have cleared
the slot happened under the old build and will never happen again.

## Decision

1. **The rule.** A Contract tracker is valid only while it names work the
   player is actually pursuing. A completed, rotated-away instance is not
   that, and the tracker is cleared at the moment of completion — which the
   reducer now does, for contracts and for completing project contributions
   alike.

2. **Existing saves are repaired exactly once**, by a migration-table step at
   **state version 8**. The step's predicate is deliberately narrow. It clears
   the slot only when *all* of these hold:
   - the tracked id is a contract, not a project;
   - the contract is **not** in `acceptedContracts`; and
   - the contract has been completed **at least once**.

3. **What each half of the predicate protects.** Acceptance protects a
   repeatable contract the player finished before and is doing again right
   now — live work, whatever its history. The completion count protects an
   *aspirational* tracker on a contract the player has lined up but not yet
   accepted, which the Goal Board explicitly allows. Neither half alone is
   safe; together they describe residue and nothing else.

4. **Repair, never a standing rule.** The predicate runs once, on the launch
   that migrates, and never again. It is not consulted on load, on
   projection, or per frame. A player who re-tracks a completed repeatable
   contract afterwards keeps that tracker forever — second-guessing the
   player every launch would be a worse bug than the one being fixed.

5. **The version is the exactly-once mechanism.** `StateVersion` is the only
   durable signal this codebase has for "a step has not yet run on this
   save", and a flag beside it would be a second mechanism recording one
   fact. v8 therefore exists despite changing no field: its geometry is v7's
   to the byte, and `V8StateDecoder` shares v7's shape rather than copying
   it.

6. **The repair is an event, not an edit.** It executes the ordinary
   `TrackGoal(slot: contract, target: null)` through the real engine, so it
   appears in the transcript and in the save on the same terms as a player's
   own untrack. `StateMigrationStep.clearsStaleTrackedContract` declares it in
   the table beside `rebasesEconomy`, for the same reason that one is
   declared: a step that edits recorded progress has to ask for it by name,
   so no future format bump can rewrite progress by being newer.

7. **No economy effect.** The step declares `rebasesEconomy: false`. No step
   figure, cursor, epoch, grant or spend moves. Tracking never escrowed
   anything (`RULES.md` P-9), so clearing a tracker returns nothing and costs
   nothing.

## Consequences

- One more entry in the migration table, and the first that is a repair
  rather than a reshape. The table's shape absorbed it without change beyond
  a declared flag, which is the argument for having built it as a table.
- `v8_baseline.save` joins the frozen fixture family, generated once from
  `v7_baseline.save` through the real step. It is the same length as its
  parent, and that equality is asserted — a repair-only bump that moved a
  length would be doing something it did not declare.
- A player mid-way through a legitimately re-accepted repeatable contract
  sees no change at migration. A player carrying the residue sees the Goal
  Board's Contract line simply empty, which is the truth: they are not
  pursuing anything until they track something.

## Alternatives considered

**Sanitise at projection time instead.** Cheaper, no version bump — and
wrong. The residue would stay in the save forever, every future reader of
`progress.tracked` would have to know the rule, and the view would be
disagreeing with the state it renders. `RULES.md` E-2 exists for this: the UI
does not get to hold a corrected copy of durable state.

**Clear any tracked contract that is not accepted.** Simpler predicate, and it
would delete the aspirational tracking the Goal Board offers. Rejected.

**Leave it; the reducer fix covers new completions.** This is what the
milestone shipped first, and the owner's device is the evidence against it:
the save that is broken is the one that exists.
