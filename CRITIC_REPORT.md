# Critic Report — Foundation Decisions, Architecture, and Task Breakdown

**Subject:** `DECISIONS/0001`–`0004`, `ARCHITECTURE_IMPLEMENTATION_PLAN.md` v1.0, `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md` v1.0
**Date:** 2026-08-01
**Reviewer:** Critic Agent
**Reports to:** Creative Director and owner

## Summary

I set out to find the expensive assumption before it gets built. The plans are unusually disciplined for pre-production — the scope freeze, the test-before-feature ordering, and the refusal to build cloud infrastructure are all correct and I have no objection to any of them.

I have six findings. One is a genuine Kernel risk that nobody has named. Two are places where a good decision was made for a reason that will not survive contact with the game. Three are smaller.

**Recommendation: approve, with the six findings addressed.** Nothing here justifies delaying Phase 1.

---

## Findings

### CR-1 — Step-clocked progression makes a bad walking day into an unplayable day. **This is the Kernel risk.**

*Severity: high. Requires owner awareness, not necessarily a change.*

The approved model is clean: no steps, no progress. But consider the player promise — "play for seconds or for longer sessions," "the game waits for the player," "return to a world that feels welcoming rather than demanding."

Now consider a sick week. An injury. A desk-bound deadline. A player who opens Stride on day four of the flu has zero banked steps, and therefore *nothing to do*. Every screen opens, every crafting recipe they can afford still works — the plan is careful about that, and `02_WALKING_INTEGRATION.md`'s "steps gate rate, never access" rule is genuinely load-bearing here. But if the inventory is empty and the activities need steps, the honest experience is an app that has nothing for you today.

That is not FOMO and it is not punishment. It is, however, the exact failure mode of "the game fits your life" — because sometimes life means not walking, and a game whose only input is walking has no answer.

I want to be precise about what I am *not* saying. I am not proposing time-based accrual; that would gut decision 0001 and I would argue against it. I am flagging that the design has no answer for a genuinely stepless week beyond "come back when you've walked," and the Kernel promises something warmer than that.

**Recommended response:** none in Milestone 01 — it would be premature. Add this to `JOURNAL/` as the first open question for Milestone 02, framed as: *what does Stride offer a player who cannot walk this week?* Candidate answers that do not violate 0001 include crafting backlogs, lore and journal reading, encounter retries against already-unlocked enemies, and planning tools. Note that all of those already exist in the slice, which suggests the answer may be "make sure the player always has a crafting backlog" — a balance goal, not a new system.

The vertical slice should ship and be played before anyone designs for this.

### CR-2 — "Difficulty comes from required preparation, not attrition" is in tension with unlimited retries.

*Severity: medium.*

`DECISIONS/0003` gives infinite retries with no cost beyond consumables and the walk back. Task C-04 requires the Hollow Guardian to be unwinnable without preparation, verified across 100 seeds.

But a deterministic, seeded, turn-based fight with unlimited retries and no time pressure is a **puzzle**, not a test of preparation. A player who loses will retry with slightly different action ordering until the seed and their choices align. If the fight is genuinely unwinnable underprepared, the retries are pure friction — walk back, lose again. If it is winnable underprepared with optimal play, C-04's acceptance criterion is false.

Both outcomes are worse than intended. The gate works, but the *feeling* of the gate is either "wall" or "trick," neither of which is "I prepared and it paid off."

**Recommended response:** C-04's acceptance criterion should require the underprepared build to lose across 100 seeds **under optimal play**, not merely across 100 seeds. If a simulated optimal player can win underprepared, the gate is fake. And the retreat flow must communicate *why* the player lost — "the Guardian's armor turned your bronze blade" — so a loss teaches preparation rather than inviting reroll. Add that as an acceptance criterion on C-02.

### CR-3 — Level 20 across five skills is a much larger commitment than it appears.

*Severity: medium.*

Task S-06 targets 4–6 weeks of ordinary walking to reach level 20 in **one** skill. With one activity at a time (architecture §3.1), the five skills are strictly serial. Maxing the vertical slice is therefore 20–30 weeks of real walking.

For a vertical slice whose purpose is to *validate the loop*, that is a very long validation cycle — and V-06's acceptance criterion is whether the owner still wants to continue, which cannot be judged from the first two weeks alone.

**Recommended response:** this is probably fine and possibly the point — `09_SUCCESS_CRITERIA.md` explicitly measures whether the owner enjoys it *months later*. But S-06 should state the full-completion figure explicitly rather than leaving it as an emergent surprise, and the owner should see that number before approving the balance pass. If 20–30 weeks is too slow to learn anything, the cap or the curve moves — better to know at S-06 than at V-04.

### CR-4 — The plans made two design decisions inside technical documents.

*Severity: medium. Already caught.*

Single-activity-at-a-time and step-free crafting were both decided in the architecture plan and the task table rather than through design review. The Creative Director caught both (CD-1, CD-2) and I concur — I flag them again only because `11_AI_OPERATING_INSTRUCTIONS.md` names silent design changes as a specific failure mode, and this is the second time in one initialization cycle that gameplay was defined in a technical document. It is a pattern worth watching, not an incident.

### CR-5 — Deferred vocabulary needs an automated guard, not a promise.

*Severity: low.*

`DECISIONS/0004` defers Expedition, Profession, and Adventure Momentum, and forbids currency and merchants. Task V-05 includes a grep for these terms — at the very end of the milestone, when removing a half-built system is most expensive.

**Recommended response:** move the grep into the test suite from F-02 onward, so a forbidden concept fails the build the day it is introduced rather than four phases later.

### CR-6 — No task validates that the game is *fun to return to* before Phase 6.

*Severity: low.*

Every acceptance criterion before V-06 is functional. The first time anyone asks whether the loop feels good is after the entire milestone is built. That is the standard trap of vertical-slice development: correctness is measurable early, feel is measurable late, so feel gets discovered last.

**Recommended response:** add a lightweight owner check after S-04 — travel completing on real steps, with placeholder everything else. If arriving at Whispering Woods after a real walk does not produce a small spark, no amount of Phase 5 polish will rescue it, and it is far cheaper to learn that at task fourteen than at task thirty-four.

---

## What I checked and found clean

- **No anti-features present.** No streaks, no expiry, no decay, no energy gate on access, no premium currency, no ads, no live-service pressure. The "steps gate rate, never access" rule (C-08 in the initialization report) is the correct boundary and is now written into `02_WALKING_INTEGRATION.md`.
- **No Kernel violations** in the architecture or the task plan.
- **Scope is frozen and the freeze is enforced** by requiring a decision record for additions.
- **No premature online infrastructure.** §12 of the architecture plan resists it explicitly, and the honest note that client-authoritative step data cannot support a trustworthy leaderboard is the kind of thing usually discovered two milestones too late.
- **No overengineering.** Zero dependencies, snapshot save, no DI framework, no speculative abstraction. The `SaveStore` port is the one abstraction that earns its place, and it earns it by being the escape hatch for the save format.
- **The no-clawback rule** is the single best decision in the reconciliation design. It chooses player trust over accounting purity in the exact place where the player would otherwise watch progress vanish.

---

## Risks

The plans are strong. The residual risk is not technical — it is that a solo project with a 20–30 week content curve loses momentum somewhere in Phase 3, when the foundation is done, the novelty has worn off, and the game is still a list view with placeholder sounds. CR-6 is my main mitigation for that: put a genuinely satisfying moment in front of the owner as early as task fourteen.

## Recommendation

**Approve.** Address CR-2, CR-3, CR-5, and CR-6 in the task breakdown before Phase 1. Log CR-1 in `JOURNAL/` as the first Milestone 02 question. CR-4 needs no action beyond the decision record the Creative Director already required.

## Required follow-up

1. Studio Stride applies CR-2, CR-3, CR-5, CR-6 to `MILESTONE_01_TASK_BREAKDOWN.md`.
2. `JOURNAL/OPEN_QUESTIONS.md` created with CR-1.
3. Owner reviews CR-3's full-completion figure when S-06 produces it.
