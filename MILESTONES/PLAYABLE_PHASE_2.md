# Playable Phase 2 — multi-region progression vertical slice

**Branch:** `playable-phase-2-multiregion`, from `3dd892d`
**Status:** implementation complete, **awaiting physical-device acceptance**
**Acceptance script:** `MILESTONES/PLAYABLE_PHASE_2_ACCEPTANCE.md`
**Decisions:** `DECISIONS/0016` (economy epoch), `DECISIONS/0017` (Phase 2 scope)
**World canon:** `GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md`

---

## What this milestone was for

Phase 1 proved the machinery: real steps reached a real save and bought a real
gather. It was one location, one activity, four screens, and a balance of
459,043 steps accumulated by an integration proving it could count.

Phase 2 makes it a game to play for a week.

## The single most important finding

**The structural checks all passed and the loop was still broken.**

The content loader validated every reference. The reachability validator proved
the whole bronze chain obtainable. The world-graph tests proved every location
connected, every node hosted once, every crafted output used. All green.

Then a test walked the loop end to end and was refused at the forge:

```text
CraftItem was refused: "Bronze Ingot" needs Smithing 2; the player is level 1
```

**To smelt ore you first had to whittle ten oak handles.** Bronze Ingot sat at
Smithing 2 and the only level-1 Smithing recipe was Oak Handle, so a player who
walked to Stonefall, mined copper and tin, and opened Craft was told to go back
to the woods. Reachability could not see it — it ignores skill levels by design,
and the chain *is* completable, just in an order nobody would guess and no
screen explains.

The lesson generalises past this defect: **a validator that answers "is this
possible" cannot answer "would anyone find it"**. The fix was a rung off the
whole Smithing ladder; the durable part is
`phase2_loop_budget_test.dart`, which plays the loop and asserts the bill stays
between one and five days of ordinary walking.

---

## OD-01 — the step-economy cutover

`DECISIONS/0016`. The playable balance is measured from an **epoch mark on both
running totals** rather than from zero granted:

```text
banked = (totalGranted − epoch.grantedAtStart) − (totalSpent − epoch.spentAtStart)
```

Nothing is subtracted, deleted or rewound. `totalObserved`, `totalGranted`,
`totalSpent`, the granted slices, the cursor, the per-origin watermarks and the
sync count all pass through byte-identical — asserted by rebuilding the migrated
ledger with the epoch put back to the origin and comparing the whole canonical
encoding.

The two forbidden implementations were the obvious ones. Subtracting breaks
**H-2**; a fresh ledger or a rewound cursor breaks **H-3**, which is the
guarantee two device runs exist to prove absent.

**Both counters, not one.** The Phase 1 save had spent 180 steps on acceptance
gathers. Marking only granted would put `banked` at −180 and the ledger's own
invariant would reject the state. A balance is a difference of two running
totals, so the mark is a point on both axes — and that is asserted as
unrepresentable, not merely avoided.

**A new game marks the origin**, under which the arithmetic reduces exactly to
the old `granted − spent`. There is no "is an epoch in effect" branch anywhere,
because there is no special case.

**Exactly-once is the state version and nothing else.** v1 decodes with the
origin epoch — not a fallback, but what a v1 save meant — and the migration
commits a v2 state through the ordinary transaction path, inheriting the lock,
the CAS, journal-first ordering and read-back. Every step before the commit is
pure, so a crash leaves the old save and the retry recomputes it identically. A
migration that will not commit **blocks startup** rather than being played in
memory: one cutover applied twice against different totals is a permanently
wrong balance.

### On P-5

`OD-01` flagged this as Kernel-adjacent. **P-5 forbids decay, expiry, streaks
and upkeep** — recurring mechanisms that take back what a player earned because
time passed. None is present. No banked step is removed by time, by absence, or
by any rule that will fire again, and the retired steps stay reportable through
`totalGranted` and `EconomyEpoch.retiredSteps`. **P-5 is unamended.** A second
epoch would need its own decision and would have to answer this less easily.

---

## The world

`GAME_BIBLE/WORLD/03_REGIONAL_ECOLOGY_PHASE_2.md`. Five locations across four
terrains, on the western flank of a north–south range:

```text
                    FROSTMERE  (alpine, frozen tarn)
                        │ Rimeward Pass · 1,500
   FORGOTTEN        STONEFALL MINE  (foothills, granite contact zone)
    HOLLOW           │        │
      │ 1,300        │ 700    │ 800
   WHISPERING WOODS ─┘        │
      │ 600                   │
   HAVEN'S REST ──────────────┘
```

Geography does the explaining. Copper and tin sit together in the foothills
because cassiterite and copper sulphides both associate with granite intrusions
— so bronze is a **local** alloy and Stonefall is the economic engine rather than
one more stop. Oak is temperate lowland broadleaf; pine is a cold-climate
conifer, so the timber tiers are a geographic progression rather than a numeric
one, and Pine Ridge **moved** from the woods to Frostmere and became Frostpine
Stand.

**Frostmere is gated twice and neither gate is a locked door**: the most
expensive route in the world, and two nodes that refuse an unprepared arrival.
A player can always reach it and look at it. Locking it would have taught them
nothing; letting them stand in front of a tree they cannot fell tells them what
to go and do.

**Foraging is the skill that travels** — four nodes, four climates, four levels.
Levelling it is literally the act of going somewhere colder or darker.

The dry region the brief offered as optional is **recorded as an expansion exit
and not built**: the Dust Reach, in the rain shadow east of the range, which is
where geography actually puts one. Five locations across four terrains already
meets the brief's target; a fifth terrain would have widened the slice without
deepening it.

---

## What was built

| Layer | Added |
|---|---|
| Ledger | `EconomyEpoch`, epoch-relative `banked`, three new invariants |
| Commands | `TravelTo`, `CraftItem`, `EstablishEconomyEpoch` (internal); `EnterLocation` became internal |
| Events | `LocationTravelled`, `ItemCrafted`, `EconomyEpochEstablished` |
| Content schema | `Terrain` on every location, required |
| F-07 | `SkillStanding` — level, XP into level, span to next, max handling |
| Save | State version 2, `V2StateDecoder`, migration in `BootstrapCoordinator` |
| Content | Frostmere, 3 nodes, 5 items, 2 recipes, rebalanced costs and ladders |
| UI | Skills and Craft screens; travel on World; four location vignettes; startup sync |

**Every rule lives in the domain.** The Flutter layer gained two commands and
five projections and no arithmetic: `Scripts/check-ui-boundary.sh` still forbids
every command name under `lib/ui/`, and the level curve is read in exactly one
place.

## Balance — provisional

The full loop, measured rather than estimated:

| Leg | Steps |
|---|---:|
| Forage ×5 at Haven's Rest | 450 |
| → Whispering Woods | 600 |
| Chop oak ×6 | 720 |
| → Stonefall Mine | 700 |
| Mine copper ×6 | 840 |
| More copper, to reach Mining 3 | 2,240 |
| Mine tin ×6 | 960 |
| Craft ingots, handle, Bronze Axe | 0 |
| → Frostmere | 1,500 |
| **Total** | **8,010** |

About **1.1 days** at 7,000 steps a day, leaving the rest of a test week for
Frostmere's own gates. Travel costs are roughly half Phase 1's.

**None of these numbers is a balance decision.** They are chosen so a week of
walking is testable.

---

## Art

**Four location vignettes shipped.** Before them, travelling to Whispering Woods
showed the same screen as staying home minus a picture. Each crop window is
recorded with what it is for.

**OD-03 and OD-04 did not ship, and that is the round's result.** The five skill
icons were generated against a frozen specification and went to Visual QA for a
blind read. **Verdict FAIL** — at ×2 the axe and the pickaxe collapse into each
other, because both reduce to a bar over a stick and the head shape that
separates them lives in pixels the reduction cannot keep. The pot/anvil case the
spec was written for **passed**; the case nobody had written down did not.

That is `MISTAKES.md` M-05 arriving somewhere new: the set was authored and
self-reviewed at ×8, where the two are obviously different objects.

The finding is worth more than the icons: **two hafted tools cannot be told
apart at 12 × 12**, so the next round must separate them by silhouette family —
a mass rather than a stick. Full record and spec amendments in
`GAME_BIBLE/ART/exploration/SKILL_ICONS_OD04/ROUND_01_RESULT.md`.

---

## Tests

**515 `stride_core`, 174 app, 108 `stride_storage`, 12 goldens.** New:

- `economy_epoch_cutover_test.dart` — 18, covering all nine cutover requirements
- `travel_test.dart` — 19 · `craft_test.dart` — 20 · `skill_progression_test.dart` — 17
- `world_graph_test.dart` — 15 (islands, one-way routes, dead-end outputs, terrain rules)
- `phase2_loop_budget_test.dart` — the loop, walked, with the bill asserted
- `startup_sync_test.dart` — 5

Two tests carry a written note about what they **cannot** prove: `isReady` after
a `FakeAsync`-started sync is a harness artifact, and the frozen v1 fixture's
round-trip became decode-only exactly as its own regeneration policy instructed.

## Known limitations

- The region map is Phase 1's and does not show Frostmere.
- Skill icons and the step glyph remain temporary art.
- No combat. Enemies exist in content and nothing fights them.
- Crafting works anywhere rather than at a workshop.
- The 375 dp and 360 dp stacked fallback is still unseen on hardware, carried
  from UI Facelift 01.
