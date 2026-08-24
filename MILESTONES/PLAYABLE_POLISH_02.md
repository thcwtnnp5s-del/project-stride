# PLAYABLE POLISH 02 — the physical-device presentation pass

**Status:** implementation complete, awaiting the owner's device test.
**Date:** 2026-08-24. Branch `playable-phase-2-multiregion`, on top of the
audio foundation (`14fedaf`).
**Brief:** the owner's physical-device polish list — steps UI, craft
presentation, job board, combat facing, tool clarity — with an explicit
"no giant systems expansion" bound.
**Records this creates:** `DECISIONS/0026_STEP_TRACKER_PROJECTION.md`;
`GAME_BIBLE/ART/exploration/PLAYABLE_POLISH_02/README.md`.

---

## 1. The Steps dashboard and tracker (`DECISIONS/0026`)

The Character tab gains a **Steps card** — Today, This Week, the last-sync
line, and a **Step Tracker** button — and the tracker itself is a pushed
screen (the Goal Board's route pattern): a Day / Week toggle, today's
credited steps by hour, the trailing seven local days as labelled bars, the
lifetime line, and a Sync card whose one control moves the timestamp
beside it.

The load-bearing part is where the arithmetic lives. "Steps today" needs a
local-day boundary over UTC-hour buckets — the exact figure Phase 1 refused
to let a widget invent (Q-UI-9, `check-ui-boundary.sh` rule 5). The fold now
has one documented home, `StrideSession.stepHistory()` in `lib/runtime`:

- a slice counts toward the local day its bucket **starts** in;
- figures are **granted** slices, summed per origin exactly as the bank
  sums them (H-1), with the origin *count* surfaced when it exceeds one
  (H-7 — counts, never identities);
- the window is the ledger's own 7-day retention; compacted days are
  absent, never zero, and the lifetime `totalGranted` is the context line;
- the clock is the existing `activityWallClock` seam (`0022` §8) — a second
  caller, not a second read site; the guard is not weakened by a character.
- "last synced" is ephemeral session state, set only when the store was
  actually **read** (reconciled or no-change), never on a refusal.

Nothing here is a goal, streak, ring, or reminder — a quiet day renders as
a plain fact (P-5).

## 2. Craft presentation — real scenes (`PLAYABLE_POLISH_02` art round)

The craft stage grows from a 150 dp box with a 64 px station to the
location stage's own composition at 176 dp: a full **384 × 176 work
backdrop** clipped and centred (the combat stage's rule), the ground
gradient, and a **96² station prop** on the figure's ground line, painted
behind the figure so the swung tool lands visibly on the working surface
(the seam/oak-trunk blind-QA rule).

Three scenes shipped — the smithy (forge glow, tool wall), the carpenter's
workshop (bench, stacked oak, shavings), the hearth (hanging pot, herbs) —
with three stations: anvil-on-stump, low work bench, tripod cookpot.

**Which scene a recipe gets is content, not code**: `RecipeDefinition`
gains an optional `station` word (`forge` / `woodbench` / `cookfire`,
presentation-only, engine never reads it), and the five wood recipes (oak
plank ×2, oak handle ×2, pine plank) are authored `woodbench` — an oak
plank is bench work even though Smithing owns it. Unauthored recipes
default by skill (cooking → cookfire, else forge) in the presentation
table. Loop, timers, queue and commit semantics are untouched.

## 3. Job board polish

- Every job row now leads with the **pixel icon** of its first reward item
  (or the requested good where the pay is pure XP), in the same inset well
  the craft rows use; done/locked rows keep the well dimmed so the list
  holds one rail.
- The collapsed reward line is **coloured**: each item in its rarity ink, XP
  in the secondary ink, a taught recipe in the quest ink. Locked rows dim
  the whole strip.
- The open job's REWARD section is **rows, not prose**: icon, name in
  rarity ink, ×count — the same grammar the victory panel and reward layer
  speak.
- The board heading carries the standing: `N READY · N ACCEPTED ·
  <development state>`, in the step accent when something is finishable.
- Refresh timing is said honestly, once: *"New orders are posted as these
  are delivered."* There is no timed refresh in this game and nothing was
  added to imply one (P-5).
- **Faction reputation does not exist** in the current design; nothing was
  invented to look like it (the brief's "prefer real information over
  aspirational fake stats" clause, applied).

## 4. Combat facing — corrected at the art

PLAYABLE_EXPANSION_01's round log had already recorded the deviation: the
v3 combat idle "drifts toward three-quarter view". On the device that read
as the player facing left while the enemy stands east. The idle is
**re-authored through PixelLab** (A-1): v3 `animate_character` from a
custom start frame = the raw attack's f3 — the sword extended east in
strict profile — nine frames, sword visible throughout, packaged to an
80 × 64 canvas (the blade reaches past the 64-box exactly as the attack
does) with the feet on row 62. A first attempt came back swordless with a
late stub (the round-1 failure mode) and is kept rejected in the round dir.
The stage, choreography, arithmetic and every other track are untouched;
the combat golden was regenerated and reviewed — the Traveler now visibly
faces the wolf.

**Combat audio seam, noted and not built:** a future combat cue would hook
the choreography's strike segments exactly as the craft stage hooks
`activityStrikeFrame` → `AudioScope.playSkillCue` — one cue at the visible
contact, through the existing `AudioController` SFX path and cooldowns. No
asset, no code, no region-music change in this pass.

## 5. Tool and gear clarity

`gearStatsOf`'s passives now name the real things (this data already
gates gathering; the sentences read the same fields):

- `Mines: Copper Seam, Tin Seam` / `Chops: Oak Stand` — the sites this
  tool's kind and tier open, in tier order;
- `Tier 2 opens Hardened Copper Seam` — the nearest site the *next* tier
  would open, when the pack holds one — the one-line answer to "why does a
  better tool matter";
- the existing tier, yield-chance and cold-weather lines are unchanged.

And the bag can now answer without a trip to the bench: **equipment tiles
are tappable**, opening the same `GearStatsBlock` the craft detail shows —
verdict, worn piece, passives — beneath the grid. No new stats were
invented; a bonus that is not implemented is not displayed (the brief's
honesty clause).

## 6. Stability

- No health-adapter, ledger, save, queue, or reconciliation change. The
  one new persistent-looking fact ("last synced") is deliberately
  ephemeral. No schema change: the content field is optional; state stays
  v9.
- Audio: untouched. Region music, cues, cooldowns and settings are exactly
  the accepted foundation; the craft stage change moved widgets around the
  same `onActivityBeat` wiring.
- No new dependencies.

## 7. Evidence

- Suites: app **651** (+5: four tracker cases and a named-sites case),
  `stride_core` **697**, `stride_health` **143**, `stride_storage`
  **108**; analyze clean; art packaging `--check` clean; the guard set CI
  and `verify.sh` run is clean (ui-boundary, core purity, single writer,
  origin privacy, dependency policy, source safety, step-model self-test).
- **Found, not introduced:** the step-model guard's *production* scan
  (`check-step-model.sh` with no flags — which CI does not run; it runs
  `--self-test`) exits 1 with 11 `signature_allowed_files` findings in
  `stride_session.dart`. The pattern `\.signature\b`, written for
  `StepLedger.signature`, also matches the enemy-knowledge system's
  `drop.signature` (in the tree since `a4c7ae9`, 2026-08-22). Verified
  identical on a clean worktree at `14fedaf`, so it predates this pass.
  Left for the guard's owner (G-4: not weakened here); flagged as its own
  task.
- New: `test/step_tracker_test.dart` (day attribution, hour grouping, the
  compaction edge, last-synced discipline, and the card→tracker widget
  flow); `gear_stats_test.dart` extended with the named-site lines.
- Goldens regenerated and reviewed: `combat_stage` (the Traveler now faces
  the wolf, blade toward it), `craft_stage` (the hearth scene),
  `phase1_character` ×2 (the Steps card). Forge and woodbench scenes
  reviewed as in-context composites in the round dir (the layout itself is
  one code path, witnessed by the craft golden).
- Two Character-tab tests gained a scroll: the Combat card sits below the
  fold now that Steps is on the sheet — lazily-built list, not a layout
  fault (`fold_clearance_test` unchanged and green).

## 8. Deferred by name

- Combat SFX/music (seam noted above; owner ruling from AUDIO_PRESENTATION_01 stands).
- Faction reputation (no system exists; would be a design conversation).
- Tool speed bonuses (no engine seam exists; `workSpeedPercent` is a site
  property — presenting it as a tool stat would be false).
- Rimefrost Hollow / Hollow Thicket / Frostpine work props (the PWRF01 gap,
  unchanged).
- Any itemization rebalance.

## 9. Device acceptance script

1. **Steps**: Character tab → the Steps card shows Today / This Week and a
   sync line. Walk a little, Sync steps, watch Today move. Open Step
   Tracker: Week shows seven labelled days (today emphasised); Day shows
   today's hours; the Sync card's timestamp moves when you sync. Quiet
   days show empty bars and no reproach.
2. **Craft**: start a Bronze Ingot (forge scene: anvil + glow), an Oak
   Plank (workshop scene: bench), and a Herb Broth (hearth scene: cookpot).
   Each should read as a real activity scene; timers, queue and cancel
   behave exactly as before; the craft cues still sound on the strike.
3. **Board**: open the Goal Board. Rows lead with reward icons; reward
   lines are coloured by rarity; the heading counts READY/ACCEPTED; an
   open job shows reward rows with icons.
4. **Combat**: start any fight. The Traveler stands in profile facing the
   enemy, sword toward it, before the first attack.
5. **Tools**: Inventory → tap a pickaxe tile. The detail names the seams
   it works and (for the training pick) that Tier 2 opens the Hardened
   Copper Seam. The same block appears at the craft bench.
