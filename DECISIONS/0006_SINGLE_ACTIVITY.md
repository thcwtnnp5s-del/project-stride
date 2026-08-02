# Decision: One Activity at a Time

**Status:** Approved
**Date:** 2026-08-01
**Owner:** Lead Game Designer
**Raised by:** Creative Director review CD-1 in `DESIGN_REVIEW.md`

## Context

`ARCHITECTURE_IMPLEMENTATION_PLAN.md` §3.1 stated that Milestone 01 supports one selected activity at a time, justified on implementation grounds. That is a gameplay decision made inside a technical document, which `PROJECT_KERNEL/11_AI_OPERATING_INSTRUCTIONS.md` names as a specific failure mode. This record makes it a design decision, owned by design.

## Decision

The player has **exactly one active activity at a time**. Steps apply to that activity. Selecting a different one banks any unspent allocation and leaves the previous activity's partial progress intact.

## The consequence, stated deliberately

**While travelling, the player cannot gather.** Every walk is a choice between going somewhere and getting something.

This is the intended design, not a side effect. It is the clearest expression of design pillar one — *walking creates opportunity, and opportunity means a choice*. If steps could advance travel and three gathering skills simultaneously, walking would stop being a decision and become a faucet. The player would never plan; they would only collect.

The Milestone 01 loop wants the player to stand in Haven's Rest and think *do I go to the mine, or do I fill my pack here first?* That question only exists because the answer costs something.

## Alternatives considered

**Multiple concurrent activities with split allocation.** Rejected: it removes the choice, multiplies the allocation rules, and creates an optimization problem (what split is best?) in a game that is supposed to be calm.

**Travel in parallel with one gathering activity.** Tempting, and the most likely future relaxation. Rejected for Milestone 01: it is the special case that quietly becomes the general case, and the loop has not been validated yet.

## Consequences

- Activity selection becomes the most important interaction in the game, which is why task S-03 treats it as such.
- The five skills are strictly serial, so exhausting the vertical slice takes roughly five times as long as one skill. See `CRITIC_REPORT.md` CR-3 — the full figure must be shown to the owner at S-06.
- Revisiting this is a legitimate Milestone 02 question, informed by how the choice actually feels.

## Follow-up

- Referenced from `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §3.1 and task S-03.
- Revisit after the Milestone 01 playtest (V-06).
