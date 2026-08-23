# 0025 — The playtest reset: a player command that moves the mark and the walked baseline, and touches nothing else

**Status:** Approved — owner direction via the Playable Polish 01 brief
(2026-08-23: "a hard reset on the current 471k+ Total Walked baseline when we
reach the right point"; "preserve the forward-only HealthKit cursor /
watermark / dedupe safety; do not regrant old historical steps"; "a
controlled fresh-playtest reset path that can reset the gameplay economy too
when I choose"). The *timing* of the first reset remains the owner's.
**Date:** 2026-08-23
**Owner:** project owner
**Supersedes:** nothing
**Amends:** `DECISIONS/0012_SAVE_FORMAT.md` — state version 9;
`RULES.md` P-5 and H-2 (a third, named re-basing path)
**Relates to:** `0016`, `0018`, `0019` (the epoch mechanism, unchanged)

---

## Context

The owner's device carries a lifetime `TOTAL WALKED` above 471,000 — the
Phase 1 and Phase 2 validation bodies, retired from the spendable balance by
`0016` and `0018` but still the headline figure on the Adventure and Character
tabs, because `0016` ruled that history is reported, never hidden. Playtesting
now wants a figure that means *this playtest*, and wants the option of
starting the game itself again without reinstalling — which would erase the
ledger's dedupe history and make the Health store's retention window spendable
all over again (the exact fault `0019` closed).

Three laws bind, as they bound `0016` and `0018`: **H-2** (granted is
monotonic), **H-3/H-4** (the cursor and the per-origin watermarks are what make
a re-grant impossible), **P-5** (nothing decays; re-basing is singular and
owner-authorised). And `RULES.md` P-5 as written allows re-basing only by a
named migration table step or a new game's first authorised reconcile. A
player-initiated reset is a third path and needs its own decision. This is it.

## Decision

**`ResetPlaytest({freshStart})` — a player-facing command, confirmed on the
Character tab, that moves the economy mark to the ledger's current totals and
sets a walked baseline at the same point. With `freshStart` the game state is
also returned to the new-game shape. The step ledger's counters, granted
slices, watermarks, recovery state and cursor are not touched.**

```text
before:  totalGranted 471,250 · totalSpent 468,900 · epoch (464,946 / 464,800, v3)
         banked 2,250 · TOTAL WALKED 471,250
reset:   epoch ← (471,250 / 468,900, v9, walkedAtStart 471,250)
after:   banked 0 · TOTAL WALKED 0 · lifetime 471,250 (Character tab)
         cursor unchanged · slices unchanged · next sync reads forward
```

### One mark, two readings

`EconomyEpoch` gains `walkedAtStart` (state version 9; `0` in every earlier
save and for every mark a migration or the new-game baseline sets). `banked`
is unchanged in formula. The player-facing figure becomes
`walkedSinceBaseline = totalGranted − epoch.walkedAtStart`, so it equals the
lifetime counter until a reset has run — every existing display is unchanged
until the owner chooses — and the Character tab names the lifetime figure
beside it once one has (`0016`'s rule, kept).

### Why a command and not a migration step

A migration step runs once per save at a version boundary; the owner wants to
choose the moment, and may want to choose it again. So the reset is a
command, player-facing by classification, and deliberately **not**
exactly-once: each run is a confirmed act. It records the running state
version on the mark, so a future re-basing migration still finds a mark older
than itself and behaves as `0018` specified.

### What freshStart does and does not do

`freshStart: true` returns `player`, `inventory` (the starting loadout),
`equipment`, `skills`, `world`, `progress`, `encounter` and `activityQueue`
to the shape `GameEngine.newGame` produces, on top of the untouched ledger.
`freshStart: false` changes the epoch only, and is refused while a fight or
a queue is in progress (the fresh start discards both). Neither erases the
save, the journal or the identity: `ResetCoordinator.resetEverything` remains
the one path that does, and it is not this.

### Proven, not asserted

`packages/stride_core/test/playtest_reset_test.dart` and
`test/playtest_reset_session_test.dart` hold the owner's constraints as
assertions: counters unchanged; checkpoint, slices, watermark and recovery
unchanged; the same observations re-delivered after a reset (incrementally,
and through a rescan) grant zero; a relaunch on the reset save banks zero for
a re-delivered walk; new walking is credited exactly once and shown once; the
bag is untouched by the baseline reset and new after a fresh start; the event
survives the journal codec.

## Consequences

- **State version 9.** `steps.epoch.walkedAtStart` enters the save; the
  v8→v9 step re-bases nothing and repairs nothing; `v9_baseline.save` is the
  v8 fixture plus exactly `,"walkedAtStart":0` (18 bytes). The conformance
  transcript's slot lengths and digests moved by the same 18 and are amended.
- `TOTAL WALKED` on Adventure and Character shows `walkedSinceBaseline`;
  Character adds `lifetime N` to its unit line after a reset.
- `RULES.md` P-5 and H-2 gain this path by name. `0016`'s "history is
  reported, never hidden" stands: the lifetime figure stays on the Character
  tab, and `retiredSteps` still reads the whole retired body.
- The controls live in `lib/ui/screens/character/playtest_block.dart`:
  two secondary buttons, each opening a two-line confirmation with one filled
  control; the result rises in the reward layer.

## Rejected

| Option | Why not |
|---|---|
| Reinstall / erase the save to reset | Erases the dedupe history and the cursor; the Health store's retention window becomes spendable again (`0019`'s fault). |
| Lower `totalGranted` | H-2. The lifetime counter is the audit trail; a figure that can go down is a figure that can be made to go down. |
| Reuse `EstablishEconomyEpoch` with a new version | Its guard is "older than this step"; a player reset at the current version would be refused, and loosening the guard would let a format bump re-base by accident — the `0018` hazard. |
| Display-only baseline (no state) | A figure that resets on one phone and not on a relaunch is a lie; the baseline has to be in the save. |
| A walked baseline as a separate ledger field | The same v9 cost, and two marks that can disagree; the epoch already *is* the point the playtest began. |

## Amended — 2026-08-23, the correction pass (device review)

- **The Adventure band's `SPENT` is this epoch's.** `StrideSession.spentThisEpoch`
  (`totalSpent − epoch.spentAtStart`) replaces the lifetime counter on the
  play surface, so a fresh playtest reads `Spent 0` beside `Total walked 0`;
  the lifetime spend is named on the Character tab once a reset has moved
  the baseline. A projection — no counter, slice, watermark or cursor moved.
- **A fresh playtest wears the starter loadout.** `PlaytestReset` carries
  `equippedItems` (`ContentRegistry.startingEquipment`: sword, tunic, and
  the first tool in loadout order), journalled like every other field and
  decoded as empty from a record written before it existed. A brand-new
  install's first transcript is unchanged (see the milestone record, §A).
