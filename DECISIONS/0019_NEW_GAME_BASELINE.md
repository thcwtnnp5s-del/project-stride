# 0019 — A new game begins spendable-zero: its first authorised reconcile is retired

**Status:** Approved
**Date:** 2026-08-18
**Owner:** project owner (direction: "RESOLVE Q-05 BEFORE DEVICE REINSTALL")
**Supersedes:** nothing
**Graduates:** `JOURNAL/OPEN_QUESTIONS.md` **Q-05**
**Relates to:** `DECISIONS/0016`, `DECISIONS/0018` (the epoch mechanism)

---

## Context

Transformation Build 01's first Release install landed on a fresh container:
`TOTAL WALKED 0`, no save to migrate. The 0018 cutover is a *migration* step
and cannot reach a game that has no history, so the first authorised sync of
that game would have banked the health store's whole 7-day retention window as
spendable currency — the Playable Demo Phase 1 behaviour, and not the zero
baseline the owner intended for the playtest.

The general question underneath: **what does a brand-new game owe a player
for the walking they did before installing it?**

## Decision

**A new game's first successful, authorised foreground reconcile is retired
into history.** Immediately after that sync's commit, the session issues
`EstablishNewGameBaseline`, which sets the economy epoch to the ledger's
current totals — the same mark 0016/0018 use — so `banked` is exactly zero and
`totalGranted` still carries every step observed. Only walking synced after
that point is spendable.

```text
first launch:  ask HealthKit → allow → reconcile (backlog N granted, as history)
               → EstablishNewGameBaseline: epoch = (totalGranted, totalSpent)
               → banked 0 · TOTAL WALKED N · cursor advanced
after:         repeat sync grants 0 · new steps grant once and are spendable
```

### Exactly-once is the epoch itself

The command is accepted **only while the epoch is the origin** and the event
it produces moves the mark off it, so the state alone refuses a second
baseline — no flag, no counter, no version bump. It is pure over the ledger it
is handed, which gives crash safety for free: if the process dies between the
sync's commit and the baseline's, the next launch reads a save whose cursor
already advanced, its first sync grants nothing new, and the baseline lands
over the same totals.

### Only a *successful, authorised* read counts

The baseline is set when the sync's report carries `authorization == granted`
and its status is `reconciled` or `noChange` — a real read happened. A denied
or undetermined answer, an unavailable service, a keying fault or a refused
commit leave the mark at the origin, so the baseline can never be set on the
strength of an empty answer nobody was allowed to give (the M-10 shape).
`baselinePending` is derived from the state and drives nothing but a doc line;
the game stays fully playable throughout (crafting at zero, Q-01).

### Not projected

Unlike the 0018 migration, `usableEnergy` is **not** projected to zero while
the baseline is pending: a new game holds nothing until its first read, and
the only window in which the ledger holds a pre-baseline balance — the crash
between the two commits — is closed by the very next sync, which the app runs
at startup.

## Consequences

- `TOTAL WALKED` on a fresh install shows the retired backlog after the first
  sync (history is reported, never hidden — 0016's rule), and `banked` shows 0.
- Every test harness that funded a fresh session with one sync now performs a
  baseline sync first; the figures they assert are unchanged.
- No ledger, cursor, watermark, slice or codec change. No save-format change.
- P-5 unamended: this retires nothing a player earned *in the game*, fires
  once per game, and can never fire from time or absence.

## Rejected

| Option | Why not |
|---|---|
| Accept the retention-window grant (Phase 1 behaviour) | Contradicts the owner's stated baseline for the playtest, and a new game "funded" by a week it did not exist for is the same pacing distortion 0016 retired |
| Restore the Phase 2 save from a backup | No backup exists on the device; the container is gone |
| A flag "baselineEstablished" beside the epoch | Two mechanisms recording one fact — rejected for the same reason in 0016 |
| Establish the baseline at game start (before any read) | Would leave the backlog spendable: the mark must sit *after* the first read |
