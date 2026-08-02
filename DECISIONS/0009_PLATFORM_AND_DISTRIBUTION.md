# Decision: Platform Targets and Distribution

**Status:** Approved
**Date:** 2026-08-01
**Owner:** Project owner
**Closes:** The open platform items in `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §4.6 and §14

## Decision

### Toolchain

- **Current stable Xcode** installed on the development machine
- **Swift 6**, strict concurrency
- **Minimum deployment target: iOS 17**

### Device and orientation

- **iPhone only** for Milestone 01
- **Portrait only.** No landscape support required
- **No iPad-specific work.** The app is not designed, tested, or reviewed for iPad in this milestone
- **Adaptive SwiftUI layouts** — portrait-only is an orientation constraint, not permission to hardcode a screen size

### Test matrix

| Target | Purpose |
|---|---|
| One small iPhone simulator | Smallest supported layout; the cramped case |
| One contemporary standard-size iPhone simulator | The everyday case |
| The owner's physical iPhone | Added when the model is provided — the only place HealthKit, Core Haptics, and real battery behavior can be validated at all |

Simulator testing cannot validate HealthKit, haptics, or battery. Any acceptance criterion touching those requires the physical device.

### Distribution

- **Local developer builds** during implementation
- **TestFlight** for owner and friend testing
- **No App Store launch preparation.** No store listing, no screenshots, no marketing copy, no monetization, no ASO work

## Reasoning

- Portrait-only iPhone matches the product: a game checked one-handed in short sessions (`GAME_BIBLE/UI_UX/01_MOBILE_EXPERIENCE.md`). Landscape and iPad would be work spent on postures the game is not for.
- Two simulators plus one real device is the smallest matrix that catches layout failures at both extremes while keeping the real-hardware path honest.
- TestFlight-only removes a large class of work — store presence, marketing, monetization — that `PROJECT_KERNEL/00_PROJECT.md` already says is not a priority.

## Consequences

- **TestFlight still requires App Review**, and any app requesting HealthKit access still requires a privacy policy and an accurate App Privacy declaration. Task S-07 remains necessary; only the store listing work is removed.
- Portrait-only is enforced in the app target's `Info.plist` (`UISupportedInterfaceOrientations` = portrait only) and verified by a build-time check.
- No iPad idiom means no split-view, no multi-column navigation, no size-class branching in Milestone 01.
- Adding iPad or landscape later is a real piece of work, not a checkbox. That is an accepted trade.

## Open item

**iOS development requires macOS.** The repository currently lives on a Windows machine, where no Swift toolchain, no Xcode, and no simulator exist. All F-01 source and configuration can be authored here, but **building, running, and verifying require a Mac.** The owner needs to confirm the development machine before F-01's build-verification criterion can pass.

## Follow-up

- `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §5, §10, §11 updated.
- Task F-01 acceptance criteria updated with the orientation constraint and the test matrix.
- Task S-07 scoped to privacy policy and App Privacy declaration only.
