# Mobile Architecture Direction

This document defines principles, not the final stack.

## Requirements

- iOS-first
- HealthKit integration
- Offline-first core gameplay
- Reliable local save
- Background and delayed step reconciliation
- Data-driven content
- Modular systems
- Testable state transitions
- Future cloud and leaderboard compatibility without current dependency

## Technical review required

Claude Code must recommend and compare viable mobile stacks before implementation, including tradeoffs for:

- Native iOS
- Cross-platform framework
- Game engine approach

The choice must be documented in `ARCHITECTURE_IMPLEMENTATION_PLAN.md` and approved by the owner.
