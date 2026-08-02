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

## Flutter, with first-party health adapters
**Status:** ✅ **LOCKED — the active architecture decision.** See `DECISIONS/0010_CROSS_PLATFORM_STACK.md`  
Flutter for the shared app; a pure Dart `stride_core` for rules and simulation; a repository-owned `stride_health` package with Swift/HealthKit and Kotlin/Health Connect adapters behind a Pigeon-typed boundary. **No third-party health plugin may own reconciliation, anchors, deletion handling, or ledger semantics.** Android first for interactive development on Windows; iOS kept compiling continuously in CI. Supersedes `DECISIONS/0002` (native Swift + SwiftUI).

The architectural principle is unchanged from `0002`: a pure simulation core with no dependency on any UI or platform framework, with every platform capability behind a port.

## Staged private distribution
**Status:** Locked — see `DECISIONS/0011_DISTRIBUTION_CHANNELS.md`  
Android: local APK → signed APK or GitHub release artifacts → Play internal testing. iOS: TestFlight once Mac access exists. No public store launch on either platform.

## Turn-based, retreat-not-death combat
**Status:** Locked — see `DECISIONS/0003_COMBAT_MODEL.md`  
Reviewed and confirmed on 2026-08-01, replacing the earlier provisional status. Encounters run 6–12 turns with no real-time pressure. Defeat retreats the player and consumes used consumables; it never removes equipment, inventory, or any earned progression. Milestone 01 grows combat power through character level and equipment only.

## One activity at a time
**Status:** Locked for Milestone 01 — see `DECISIONS/0006_SINGLE_ACTIVITY.md`  
Steps apply to a single selected activity. While travelling, the player cannot gather. The choice is the point.

## Earned opportunity never expires
**Status:** Locked — see `DECISIONS/0008_STEPLESS_WEEK.md`  
Steps govern the rate at which new opportunities are created; previously earned opportunities remain available indefinitely. Nothing decays, spoils, or expires — ever.

## Milestone 01 validates the loop in one to two weeks
**Status:** Locked — see `DECISIONS/0007_PROGRESSION_PACING.md`  
The vertical slice must expose the complete loop within roughly one to two weeks of ordinary movement. Maxing all five skills is not a completion condition. Pacing figures are testable hypotheses, not constants.

## Platform, orientation, and distribution
**Status:** Locked — see `DECISIONS/0009_PLATFORM_AND_DISTRIBUTION.md`  
iPhone only, portrait only, iOS 17+, current stable Xcode. TestFlight for the owner and friends; no App Store launch preparation.

## Audio sourcing
**Status:** Locked — see `DECISIONS/0005_AUDIO_SOURCING.md`  
Lean prototype budget: generated or CC0/royalty-free assets, full provenance recorded, referenced by replaceable asset ID. Never extract assets from the inspiration games.

## Milestone 01 scope is frozen
**Status:** Locked — see `DECISIONS/0004_MILESTONE_01_SCOPE.md`  
Four locations, five skills, three enemies, six tabs plus a combat modal, no currency, no merchants. Additions require a new decision record.
