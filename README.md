# Project Stride — Claude Code Handoff

This repository is the pre-production and operating package for **Project Stride**, a mobile-first solo RPG where real-world movement powers exploration, skilling, crafting, travel, and PvE combat.

## What this repository is

This is not yet the game source code. It is the project operating system Claude Code should read before implementation.

It contains:

- Project identity and non-negotiables
- Game design foundations
- AI agent definitions
- Studio workflows and commands
- Milestone 01 vertical-slice scope
- Starter content, mobile UX, audio, and health-integration direction

## Where to open Claude Code

Open Claude Code at the repository root:

```text
ProjectStride/
```

Do not open it from `GAME_BIBLE/`, `AGENTS/`, or another subfolder.

## First prompt to Claude Code

```text
Read CLAUDE.md and PROJECT_STATE.md, then review the full repository.

Initialize yourself as the Studio Stride development team.

Do not write production code yet.

Run the studio initialization process, identify gaps or contradictions, produce STUDIO_INITIALIZATION_REPORT.md, and recommend the exact next step for Milestone 01.
```

Then use:

```text
/studio-init
/spawn-agents
/design-review
```

After design and architecture reviews are approved:

```text
/execute-phase
/critic-loop
/qa-check
```

## License

**None is granted.** Project Stride is **source-available, not open source**:
the repository is publicly viewable, and copyright is reserved in full by
Rob Hathaway.

There is no MIT, Apache, Creative Commons, or other open-source licence here.
Reuse, modification, redistribution, and commercial use of the code,
documentation, Game Bible, lore, content, art, and audio are **not** permitted.

See [COPYRIGHT.md](COPYRIGHT.md) for the full notice.

## Recommended handoff order

1. Give Claude Code the entire repository.
2. Have it audit and normalize the documentation.
3. Have it create:
   - `ARCHITECTURE_IMPLEMENTATION_PLAN.md`
   - `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md`
4. Review those outputs before allowing implementation.
