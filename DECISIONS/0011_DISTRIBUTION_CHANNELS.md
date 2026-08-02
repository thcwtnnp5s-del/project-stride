# Decision: Distribution Channels

**Status:** Approved
**Date:** 2026-08-01
**Owner:** Project owner
**Amends:** `DECISIONS/0009_PLATFORM_AND_DISTRIBUTION.md` — distribution only; platform targets there stand

## Decision

Distribution proceeds in stages, each unblocking testers earlier than the next stage could.

### Android — initial development

Local debug builds, installed directly by APK. No account, no review, no store.

### Android — early private testing

Signed APK distributed privately, or as **GitHub release artifacts**. Still no store, no review, no declaration forms.

### Android — stable private beta

**Google Play internal testing**, followed by closed testing if it proves useful.

Before any Play distribution:

- Complete the **Health Connect data-types declaration** in Play Console
- Complete the **Data safety** form
- Publish the **privacy policy** required for health-data access

### iOS

**TestFlight**, once Mac access, Apple signing, and real-device validation are available.

TestFlight goes through Beta App Review for external testers and requires the same privacy policy. Internal testers (App Store Connect users, up to 100) avoid Beta App Review, and the owner-and-friends audience likely fits inside that tier.

### Not in scope

No public store launch. No store listing, screenshots, marketing copy, ASO, or monetization work, on either platform.

## Reasoning

The staging matters more than the endpoints. Direct APK gets a build into a friend's hands within days of the first playable Android version, with no account, no review queue, and no compliance paperwork. Play internal testing is worth its overhead only once builds are stable enough that automatic updates and version management are a convenience rather than ceremony.

Deferring the Play compliance work also defers it until there is something concrete to declare — the data-types declaration is easier to complete accurately once the Health Connect adapter exists.

## Consequences

- Task S-07 covers the privacy policy, the Play declarations, and both platforms' permission rationale copy.
- The privacy policy is required before **either** Play distribution or TestFlight, so it is not iOS-specific and should not wait for Mac access.
- GitHub release artifacts imply the repository has a remote. That is not yet true and is a prerequisite for both CI and this distribution path.
- Play Console requires a one-time developer registration fee; the Apple Developer Program is annual. Both are the owner's to arrange.

*(Google's requirement that newer personal developer accounts run a 12-tester closed test for 14 days applies to unlocking production access. Stride is not launching publicly, so it does not apply.)*

## Follow-up

- `ARCHITECTURE_IMPLEMENTATION_PLAN.md` §12 updated
- Tasks S-07 and S-09 updated in `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md`
