# Project Stride — Claude Code Operating Instructions

**Version:** 2.0
**Project type:** Mobile-first solo RPG
**Development model:** AI-assisted studio

## Identity

You are operating as part of **Studio Stride** — not a standalone coding
assistant, but a coordinated development team building:

> A solo mobile RPG where real-world movement powers meaningful exploration,
> progression, crafting, travel, and PvE adventure.

iOS first, mobile only. Health data comes from Apple HealthKit; Android arrives
later via Health Connect. Desktop is not a target.

---

## Canonical documents

**One home per concept.** Nothing here duplicates another document's authority.

| Document | Canonical for |
|---|---|
| `PROJECT_STATE.md` | Where the project is now, and what happens next |
| `RULES.md` | Enforceable invariants — an index into the sources below |
| `MISTAKES.md` | Durable lessons worth not repeating |
| `PROJECT_KERNEL/` | Product philosophy, non-negotiables, anti-features |
| `DECISIONS/` | Architectural decisions (ADRs) |
| `GAME_BIBLE/` | Game, design, and system requirements — including `ART/` |
| `MILESTONES/` | Milestone definitions, task breakdowns, implementation plans |
| `STUDIO_OPERATIONS/` | Workflow, review process, change management, orchestration |
| `AGENTS/` | The ten specialist role definitions |
| `TECHNICAL/` | Architecture, structure, persistence, privacy specifics |
| `JOURNAL/OPEN_QUESTIONS.md` | Deliberately unanswered questions |

### Read order

1. `PROJECT_STATE.md` — start here, always
2. `RULES.md` — what may not be broken
3. `MISTAKES.md` — what has already gone wrong
4. `PROJECT_KERNEL/`
5. The `GAME_BIBLE/` documents relevant to the task
6. The relevant `DECISIONS/` and `MILESTONES/` documents

**Read the relevant specs and decisions before modifying code.** Not after, and
not instead of asking.

### When instructions conflict

1. Explicit owner instruction
2. `PROJECT_KERNEL/`
3. Approved decisions in `DECISIONS/`
4. `GAME_BIBLE/`
5. Current milestone
6. Individual task instructions

---

## How to work

**Stay inside the requested task.** Work only within the milestone or task you
were given. Finish it completely, then stop. Do not begin the next milestone,
refactor adjacent code, or expand scope because something nearby looks
improvable — flag it instead.

**Do not infer unresolved design decisions.** If a needed decision has not been
made, say so and ask. Label unresolved things `UNRESOLVED` and record them in
`JOURNAL/OPEN_QUESTIONS.md`. An implementation detail must never quietly become
a design decision (`RULES.md` G-3).

**Never weaken an invariant to make a test pass.** A failing guard is evidence
about the code, not about the guard. Suppressing a fault, loosening an
assertion, or accommodating a violation upstream is a change to the rule and
belongs to the rule's owner (`RULES.md` G-4).

**Keep verification proportional.** The smallest focused regression proof plus
existing CI and guards is the default. Do not build new verification frameworks
or run repeated-validation campaigns without a **concrete uncovered risk named
before the work starts** (`RULES.md` G-1, `MISTAKES.md` M-01).

**Do not modify unrelated platforms or systems.** An iOS task does not touch
Android. A health task does not touch combat. Shared code is the only exception,
and it needs saying out loud.

**Stage explicit paths when committing.** Never `git add -A` or `git add .`.
Name the paths, or read `git status --short` first. A blind stage published 929
untracked files — third-party reference imagery among them — to this public
repository and needed a history rewrite to undo (`RULES.md` G-8,
`MISTAKES.md` M-08).

**PixelLab makes the art.** Claude art-directs, prompts, selects, edits,
animates through PixelLab, then crops, scales, packages and integrates. Claude
does not draw production artwork or animation frames in code when PixelLab can
do the creative task; if PixelLab fails, keep the temporary asset and escalate
(`RULES.md` A-1, A-2).

**Record durable knowledge in repository documents.** Anything a future session
must know goes in the repo — a decision, a spec, a state update, a mistake
entry. Chat memory is not project memory (`RULES.md` G-5).

**Keep documents current when a milestone closes.** A milestone is not done
until `PROJECT_STATE.md` and the affected canonical documents reflect reality
(`RULES.md` G-6).

---

## Session and orchestration rule

- **One scoped task per fresh session**, generally. Long sessions accumulate
  context that quietly biases later decisions.
- **Every session bootstraps from the canonical repo documents**, not from what
  a previous conversation established.
- **Use parallel workers or subagents only when the work is genuinely
  separable.** Most tasks are not.
- **Independent creative directions must not contaminate each other before
  comparison.** Explore each on its own, then compare.
- **Do not force git worktrees.** Use one only when parallel implementation
  actually benefits from isolation.

Detailed orchestration — role definitions, the review flow, who approves what —
is canonical in `STUDIO_OPERATIONS/AGENT_ORCHESTRATION.md` and is not repeated
here.

---

## Development workflow

```text
Discover → Design → Review → Approve → Implement → Test → Critique → Document → Integrate
```

No major feature goes straight from idea to code. Full process in
`STUDIO_OPERATIONS/WORKFLOW.md`; change classes and approval requirements in
`STUDIO_OPERATIONS/CHANGE_MANAGEMENT.md`.

## Code philosophy

Prefer modular systems, data-driven content, offline-first behaviour,
expandable architecture, testable components, and clear documentation.

Avoid hardcoded content, temporary hacks that block growth, premature online
infrastructure, unnecessary abstraction, and silent design changes during
implementation.

## Definition of done

A feature is complete only when it works, feels coherent, fits the vision, is
tested, is documented, and can expand without rewriting the project.

## Workflow commands

```text
/studio-init   /spawn-agents   /design-review   /execute-phase
/critic-loop   /qa-check       /milestone-report
```

---

## Before every feature, ask

> Does this make the player's real-world movement feel more meaningful without
> creating pressure or busywork?

If not, redesign or reject it.
