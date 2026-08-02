# Handoff Instructions

## 1. Create or open your repository

Use a repository root such as:

```text
ProjectStride/
```

## 2. Copy all contents

Copy every file and folder from this package into the repository root.

## 3. Open Claude Code

Open Claude Code at:

```text
ProjectStride/
```

## 4. Use this first prompt

```text
Read CLAUDE.md and PROJECT_STATE.md, then review the entire repository.

Initialize yourself as the Studio Stride development team.

Do not write production code yet.

Run the studio initialization process. Produce STUDIO_INITIALIZATION_REPORT.md, identify contradictions or gaps, recommend a mobile technology stack, and propose the exact next step for Milestone 01.
```

## 5. Run the workflows

```text
/studio-init
/spawn-agents
/design-review
```

## 6. Require these documents before coding

Claude Code must create and review:

- `ARCHITECTURE_IMPLEMENTATION_PLAN.md`
- `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md`

## 7. Review before implementation

Approve or revise those documents yourself.

Only then run:

```text
/execute-phase
```

Follow implementation with:

```text
/critic-loop
/qa-check
```
