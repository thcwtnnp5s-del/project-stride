# 0026 — The step tracker: a local-day projection in the session, and where the timezone policy lives

**Status:** Approved — owner direction via the physical-device polish brief
(2026-08-24: "We want a Steps dashboard / tracker UI … steps today, steps
this week, optionally a simple lifetime context, and ideally when the game
last synced. The purpose is to make Stride's step state more visible and
trustworthy.")
**Date:** 2026-08-24
**Owner:** project owner
**Supersedes:** the Phase 1 deferral recorded as **Q-UI-9** (the "walked
today" figure withheld because no one owned a local-day policy)
**Amends:** the one-wall-clock note in `DECISIONS/0022` §8 — the same seam
gains a second, read-only caller
**Relates to:** `RULES.md` E-2, H-1, H-7, P-5;
`Scripts/check-ui-boundary.sh` rule 5

---

## Context

Phase 1 deliberately shipped no "walked today" figure. `TimeBucket` is a UTC
hour-granularity span, so a daily figure needs a local-day boundary and a
fold over the granted slices — a timezone policy **and** a derivation over
ledger data, which `RULES.md` E-2 forbids a widget to invent. That refusal
was recorded as Q-UI-9 and enforced by `check-ui-boundary.sh` rule 5, which
bans `grantedSlices`, `DateTime.now` and `.toLocal(` from `lib/ui` outright.

The owner's device play has now asked for the figure by name. The question
Q-UI-9 left open — *who owns the policy?* — therefore needs an answer that
does not weaken the guard.

## Decision

**`StrideSession.stepHistory()` is the one home of the local-day policy.**
It lives in `lib/runtime` — outside the guard's `lib/ui` scope, which is not
weakened by one character — and it is a projection: presentation-only,
feeding no rule, read by the Character tab's Steps card and the Step Tracker
screen through the ordinary session boundary.

The policy, stated once:

1. **A day is the device's local calendar day at read time.** Each retained
   granted slice is attributed to the local day its bucket **starts** in;
   today's hours group by the bucket's local start hour the same way.
2. **The figures are sums of granted slices** — what the ledger actually
   credited, per origin, exactly as the bank sums them (`RULES.md` H-1). Two
   sources crediting the same hour both count here because they both count
   in the bank; the projection carries the origin **count** (never an
   identity — H-7) so the surface can say when that is happening.
3. **The window is the ledger's own retention window** (seven days of
   per-slice detail). Days older than the horizon are compacted credit:
   shown as absent, never as zero walked, with the lifetime total
   (`totalGranted`) as the context line.
4. **The clock is the existing seam.** The fold and the "last synced"
   mark read `activityWallClock` — `DECISIONS/0022` §8's one injectable
   wall-clock read — through a second read-only caller. No new
   `DateTime.now` site exists anywhere; the seam stays the single authority
   a test can substitute.
5. **"Last synced" is ephemeral.** The wall time of the last successful
   foreground read is session state, deliberately not persisted: a cold
   launch syncs on its own bootstrap path, and a save-format change for a
   presentation nicety is a bad trade. The label is honest about the gap
   ("Not synced yet this launch").

## What this deliberately is not

- **Not a health app.** No goals, streaks, rings, reminders, or any surface
  that makes a quiet day look like a fault (`RULES.md` P-5).
- **Not a second accounting.** Nothing in the engine, the ledger, or any
  rule reads these figures back. Deleting the projection would change no
  game outcome.
- **Not a platform query.** The tracker shows what the *game* credited, as
  of the last sync — which is exactly the trustworthiness the owner asked
  for, and why the sync timestamp and control sit on the same screen.

## Consequences

- `check-ui-boundary.sh` rule 5 stands unchanged; Q-UI-9 closes as
  *answered by ownership* rather than *waived*.
- A DST boundary makes a local day 23 or 25 hours long; the fold inherits
  that from the platform's local time and the figures remain "what was
  credited in that calendar day", which is the honest reading.
- The regression proof is `test/step_tracker_test.dart`: attribution,
  hour grouping, the compaction edge, and the last-synced discipline, all
  against an injected clock.
