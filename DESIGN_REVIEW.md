# Design Review — Architecture Plan and Milestone 01 Task Breakdown

**Subject:** `ARCHITECTURE_IMPLEMENTATION_PLAN.md` v1.0 and `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md` v1.0
**Date:** 2026-08-01
**Reviewers:** Technical Director, Creative Director, QA Director
**Critic review:** separate — `CRITIC_REPORT.md`

## Outcome

> **Approved with changes.**

Both documents are sound in structure and faithful to the approved decisions. Eleven findings require changes before Phase 1 begins. Nine are documentation or task-plan corrections that Studio Stride can apply directly; two need owner input.

None of the findings challenge the approved stack, progression clock, combat model, or scope freeze.

---

## Technical Director review

### Summary

The architecture is appropriately conservative. The pure-core boundary, the ledger-before-snapshot ordering, and the decision to write reconciliation tests before reconciliation are the three choices that matter most, and all three are correct. Findings below are about places where the plan quietly made a *design* decision inside a *technical* document.

### Findings

**TD-1 — `consumeSteps` is too permissive an API.** `GameEngine.consumeSteps(_:)` exposed publicly allows spending steps with no activity attached, which no legitimate caller should ever do. It invites a future bug where steps leak out of the ledger with no corresponding progress.

*Required change:* make step consumption internal to activity progression. The public surface becomes `apply(_ intent:)` and `ingest(steps:)` only. Add an invariant test: `stepsConsumed` never increases without a matching activity-progress event.

**TD-2 — The `discrepancyDebt` cap of 20,000 is invented.** It appears in the architecture plan with no derivation. It is probably the right order of magnitude, but a number nobody chose is a number nobody will revisit.

*Required change:* move the cap into content as a tunable, mark it provisional, and derive it in `GAME_BIBLE/BALANCE/` once the owner's daily step count is known (roughly three days of walking is the intended shape).

**TD-3 — Audio memory budget of 30 MB is likewise unsourced.** Same problem, lower stakes.

*Required change:* mark provisional in `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §8.4 and confirm against real assets in A-05.

**TD-4 — Nothing defines a "safe destination."** Task C-02 requires defeat to return the player to "the most recent safe destination," but no task, schema, or content file defines which locations are safe.

*Required change:* add `isSafe` to the location schema in F-02, and state the Milestone 01 assignment in content (Haven's Rest safe; Whispering Woods, Stonefall Mine, and Forgotten Hollow not).

### Risks

Erosion of the pure-core boundary under deadline pressure remains the standing technical risk (A-05 in the architecture plan). The automated import check is the whole mitigation, so F-01's acceptance criterion demonstrating a deliberate violation failing the build is not ceremony — it is the proof the guard works.

### Recommendation

Approve with TD-1 through TD-4 applied.

---

## Creative Director review

### Summary

The plans hold the vision. The return summary is correctly identified as the hardest screen; onboarding is correctly treated as a real feature rather than a formality; the anti-feature audit in P-03 is exactly the right instinct. Two findings concern design decisions that were made in the wrong document, by the wrong role.

### Findings

**CD-1 — "One activity at a time" is a design decision made inside an architecture document.** `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §3.1 states it and justifies it on implementation grounds ("adding it now would multiply the allocation rules"). The reasoning is sound and I agree with the conclusion — but this is the Lead Game Designer's call, not the Technical Director's, and `PROJECT_KERNEL/11_AI_OPERATING_INSTRUCTIONS.md` forbids silent design changes during implementation planning.

It also has a real player consequence nobody has stated: **while travelling, the player cannot gather.** Every walk is a choice between going somewhere and getting something. That is arguably excellent — it is a meaningful decision, which is pillar one — but it should be chosen deliberately.

*Required change:* record it as a decision (`0006_SINGLE_ACTIVITY`), owned by the Lead Game Designer, with the travel-versus-gather tension named as the intended design rather than a side effect.

**CD-2 — "Crafting is instant and costs no steps" is the same problem.** It appears only as acceptance criterion A-03.2. It is a significant statement about what walking is for, and it contradicts nothing in the Kernel — `02_WALKING_INTEGRATION.md` never lists crafting as a step sink — but it deserves a sentence of design intent rather than a line in a task table.

*Required change:* state it in `GAME_BIBLE/SYSTEMS/04_CRAFTING_SYSTEM_FRAMEWORK.md` with its reasoning: the steps were already spent gathering, and charging twice would make crafting feel like a toll.

### Risks

The vertical slice can be functionally complete and still fail its real test — whether the owner wants to keep playing. V-06 is honest about this. No mitigation exists beyond building the thing well, and that is the correct posture.

Gap G-04 (no visual identity) remains the largest unaddressed creative risk. P-01 closes it, but P-01's own acceptance criterion — a sourcing plan achievable without an artist — is the hard part and has no proposed answer yet.

### Recommendation

Approve with CD-1 and CD-2 applied.

---

## QA Director review

### Summary

Acceptance criteria are, with three exceptions, genuinely checkable — which is the improvement I most wanted over the milestone's original narrative success test. The state-diff assertion in C-02 and the seeded preparation-gate simulations in C-04 are the strongest criteria in the plan. My findings concern one real logical inconsistency, one scheduling error, and two criteria that cannot be verified as written.

### Findings

**QA-1 — Overflow handling is inconsistent between terminating and repeating activities.** *(Highest severity in this review.)*

Task S-03 acceptance criterion 2 says excess steps beyond an activity's completion "remain banked, never auto-spilled." Task A-01 describes gathering as consuming steps per resource yielded.

These conflict. Travel **terminates** — you arrive, and further steps should bank. Gathering **repeats** — you chop the next tree, and further steps should keep being consumed until the player's allocation runs out. As written, criterion S-03.2 would stop gathering after a single log and bank 79,000 steps, which is plainly wrong and would have been discovered late.

*Required change:* distinguish the two in the content schema — `activityKind: terminating | repeating` — and split the acceptance criterion. Terminating activities bank the remainder. Repeating activities consume until the allocation is exhausted, then bank zero. The player's allocation, not the activity, is the boundary.

**QA-2 — V-02 puts a fourteen-day serial dependency at the end of the milestone.** Real-data step validation cannot be compressed; it takes fourteen days of actual walking. Scheduling it in Phase 6 adds two weeks to the milestone's tail during which nothing else can complete.

*Required change:* start the fourteen-day real-data log as soon as S-02 lands, running in parallel through Phases 3–5. V-02 then *reviews* an already-collected log rather than starting the clock. This is free schedule recovery and I consider it the most valuable change in this review.

**QA-3 — ">90% coverage of `StrideCore`" is a metric, not a criterion.** Coverage percentages are gameable and say nothing about whether the right things are tested.

*Required change:* replace with named required suites: the twelve reconciliation scenarios, save round-trip and crash replay, XP curve boundaries, the fresh-start-to-Bronze path, combat determinism, and the preparation-gate simulations. Coverage may be reported; it is not a gate.

**QA-4 — "The full core loop is completable with VoiceOver" (P-06.3) is ambitious and unbudgeted.** I support the goal and do not want it weakened, but it is a substantial amount of work attached to a single acceptance line in a shared task.

*Required change:* split accessibility out of P-06 into its own task with its own estimate, so it is either resourced properly or consciously reduced — not silently dropped at the end when the milestone is running long.

**QA-5 — No task owns authoring the starter content itself.** Schemas land in F-02, nodes in A-01, recipes in A-03, locations in S-04, enemies in C-04. Nobody owns the item list, the material tiers, or the connective tissue between them, so gaps will only appear when the validator fires.

*Required change:* add a content-authoring task in Phase 3 owned by the Systems Designer, delivering `items.json` complete for the Milestone 01 set.

### Risks

Balance validation (V-04) depends on real walking data that depends on the owner's actual behavior over weeks. If the owner's step pattern is unusual — very high or very low — the first-pass numbers will be wrong in ways no simulation predicts. This is inherent to the genre and is why every number lives in content.

### Recommendation

Approve with QA-1 through QA-5 applied. QA-1 and QA-2 should be applied before Phase 1 starts; the rest before their respective phases.

---

## Consolidated required changes

| ID | Change | Applied by | Blocks |
|---|---|---|---|
| TD-1 | Make step consumption internal; add leak invariant test | Studio | F-03 |
| TD-2 | Move `discrepancyDebt` cap to content, mark provisional | Studio | S-02 |
| TD-3 | Mark audio memory budget provisional | Studio | A-05 |
| TD-4 | Add `isSafe` to location schema and content | Studio | F-02 |
| CD-1 | Record single-activity as a design decision | Lead Game Designer | S-03 |
| CD-2 | State crafting's step-free intent in the Game Bible | Studio | A-03 |
| QA-1 | Split terminating vs. repeating activity overflow | Studio | S-03 |
| QA-2 | Start the fourteen-day log at S-02, not V-02 | Studio | S-02 |
| QA-3 | Replace coverage target with named required suites | Studio | F-01 |
| QA-4 | Split accessibility into its own task | Studio | P-06 |
| QA-5 | Add a content-authoring task | Studio | A-01 |

## Owner input still required

| Item | Blocks |
|---|---|
| Typical daily step count | S-06, and the TD-2 derivation |
| Audio budget and licence preference | A-05 |
| Xcode version and target device set | F-01 |
| TestFlight vs. App Store distribution | S-07 |

## Follow-up

Studio Stride applies the nine documentation-level changes immediately and records CD-1 as a decision. The plans then stand ready for owner approval; no further design review is required before Phase 1.
