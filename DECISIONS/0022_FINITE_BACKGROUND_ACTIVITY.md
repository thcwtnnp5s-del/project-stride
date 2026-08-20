# Decision: A finite, player-initiated activity queue progresses across background and relaunch

**Status:** Approved (owner ruling, Activity Feel & Presentation 01 device
acceptance, 2026-08-20)
**Date:** 2026-08-20
**Owner:** Project owner; implemented by Studio Stride

## Context

Activity Feel & Presentation 01 shipped timed, queueable gathering whose
presentation clock **paused** whenever Stride was not resumed — the strict
reading of the no-wall-clock rule (`RULES.md` P-4). On the phone the owner
found that reading wrong for this feature: a player who explicitly starts
*Oak Stand ×10* should not have to keep the phone awake for two minutes to
collect what they already committed to. Backgrounding or locking, returning
later, and finding the finite queue advanced by elapsed real time is the
intended behaviour.

## Decision

1. **The exception, exactly.** A *finite, player-initiated activity queue* —
   started by an explicit command naming a node and a repetition count —
   advances by elapsed wall-clock time whether or not the app is running.
   This is the **only** wall-clock progression in Project Stride.
2. **What it does not license.** No passive world progression, no infinite
   jobs, no automatic or background health sync, no background HealthKit
   delivery, no time-based enemy respawns or combat, no energy recharge, no
   streaks, no decay, no daily systems, no unbounded idle progression. P-4
   stays the law for everything else; this decision is P-4's one named
   exception, and a second exception needs its own decision.
3. **Walking remains the engine.** Every completed repetition still spends
   banked steps and grants resources/XP through the unchanged authoritative
   gather semantics; time paces the conversion of steps the player already
   walked, it never substitutes for them. A queue that runs out of banked
   steps stops.
4. **No process-keep-alive.** No iOS background modes, audio/location
   keep-alives, or background delivery. The app may be suspended or killed
   at any time; correctness comes from **durable state plus reconciliation
   on resume/relaunch**, never from the process staying alive.
5. **Durable queue in the save, state version 6.** `GameState.activityQueue`
   holds node, requested count, completed count, authored duration, and the
   wall-clock anchor of the current repetition. `StateMigrations` v5→v6,
   `rebasesEconomy: false`; a v5 save decodes with no queue; frozen fixture
   `v6_baseline.save`; v1–v5 fixtures untouched.
6. **Exactly-once by commit, not by clock.** Reconciliation is a command:
   it computes how many whole repetitions the elapsed time completed
   (clamped to the requested count, elapsed clamped to ≥ 0 against backward
   clocks), resolves each through the same validation and effects as a
   manual gather, advances the anchor by exactly the completions it
   committed, and persists atomically. A second reconciliation after the
   commit finds nothing left to complete. If a repetition cannot legally
   complete (steps, skill, tool, location), the queue stops there with the
   reason, keeping every prior completion.
7. **Stop is the cancellation mechanism.** Stop first reconciles elapsed
   time, then commits all fully-elapsed repetitions, discards the partial
   one and the remainder, and clears the queue. Process death cancels
   nothing; relaunch reconciles and continues.
8. **The wall clock lives in one seam.** The activity subsystem owns the
   single injectable wall-time source (`stride_core` stays pure — commands
   carry timestamps in, like the health path). No scattered `DateTime.now`;
   existing time guards stay as strict as they are, with only this seam
   exempted by name.

## Alternatives considered

- **Keep the foreground-only pause.** Rejected by the owner on hardware:
  it makes the queue a chore and misreads why the no-wall-clock rule exists
  (protecting walking as the input, not punishing the phone being locked).
- **iOS background execution to keep the timers real.** Rejected: fragile,
  battery-hostile, against §4 of the correction brief, and unnecessary —
  a durable anchor plus arithmetic is strictly more reliable than a
  suspended process.
- **Timestamped completion schedule ("finishes at 8:04pm") with local
  notifications.** Rejected: notification/FOMO surface this game refuses,
  and nothing about the queue needs the future — only the past.

## Consequences

- `RULES.md` P-4 gains a pointer to this decision as its one exception.
- `StateVersion.current` = 6; `v6_baseline.save` frozen.
- The activity presentation clock (progress bars) reads the same anchor,
  so what the bar shows and what reconciliation computes cannot disagree.
- Q-01 (what does a stepless week offer) is helped incidentally: a banked
  queue finishes on its own, but nothing new accrues — the cap is the
  requested count the player chose.
