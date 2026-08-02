# Kernel Decision Log

## Mobile-first
**Status:** Locked  
The phone is the bridge between health data and gameplay.

## Solo-RPG foundation
**Status:** Locked  
The project seeks MMO-style progression without MMO infrastructure.

## Walking is core gameplay
**Status:** Locked  
All primary progression systems must meaningfully connect to real-world movement.

## No FOMO
**Status:** Locked  
Players return because they want to, not because they fear loss.

## Audio is first-class
**Status:** Locked  
Audio must be considered during system design, not added only as final polish.

## Progression is step-clocked only
**Status:** Locked — see `DECISIONS/0001_PROGRESSION_CLOCK.md`  
Activities advance only from newly earned, reconciled steps. Nothing progresses on wall-clock time alone. "Idle" means asynchronous planning, offline reconciliation, and delayed collection — not passive accrual.

## Native Swift + SwiftUI
**Status:** Locked — see `DECISIONS/0002_TECHNOLOGY_STACK.md`  
iOS 17+, SwiftUI shell over a pure-Swift `StrideCore` simulation package. The core must not depend on any platform framework.

## Turn-based, retreat-not-death combat
**Status:** Locked — see `DECISIONS/0003_COMBAT_MODEL.md`  
Reviewed and confirmed on 2026-08-01, replacing the earlier provisional status. Encounters run 6–12 turns with no real-time pressure. Defeat retreats the player and consumes used consumables; it never removes equipment, inventory, or any earned progression. Milestone 01 grows combat power through character level and equipment only.

## One activity at a time
**Status:** Locked for Milestone 01 — see `DECISIONS/0006_SINGLE_ACTIVITY.md`  
Steps apply to a single selected activity. While travelling, the player cannot gather. The choice is the point.

## Milestone 01 scope is frozen
**Status:** Locked — see `DECISIONS/0004_MILESTONE_01_SCOPE.md`  
Four locations, five skills, three enemies, six tabs plus a combat modal, no currency, no merchants. Additions require a new decision record.
