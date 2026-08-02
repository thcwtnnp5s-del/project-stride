# Design Review — Flutter Architecture and Revised Task Breakdown

**Subject:** `ARCHITECTURE_IMPLEMENTATION_PLAN.md` v2.0, `MILESTONE_01_TASK_BREAKDOWN_FLUTTER_PROPOSED.md` v2.0-proposed, `TECHNICAL/PROJECT_STRUCTURE.md`, `.github/workflows/ci.yml`
**Date:** 2026-08-01
**Reviewers:** Creative Director, Technical Director, Critic Agent, QA Director

## Outcome

> **Approved with changes.**

Nine findings. All are applied to the finalized breakdown below. None challenges the Flutter decision, the scope freeze, or any design decision.

The review's main observation: this is a **stack change, not a design change**, and the documents correctly treat it that way. Seven of eleven decisions were untouched. The risk in a migration like this is that a language change quietly becomes a design change, and the reviewers went looking for that specifically.

---

## Creative Director review

### Summary

The player-facing design is entirely unaffected, which is the correct outcome and worth stating: no pillar moved, no promise changed, no anti-feature crept in. My findings concern two places where a platform reality touches the player experience.

### Findings

**CD-F-1 — Android's back gesture is a player-experience decision, not a technical detail.** Task P-02 acquires criterion 7 requiring correct back-button behavior including the combat modal. That is right, but it is stated as a technical constraint.

The player-facing question is: *what does pressing back during a fight mean?* The combat modal is dismissible only by resolving or retreating (`DECISIONS/0004`). A back gesture is therefore either ignored — which feels broken on Android, where back is a reflex — or it is a **retreat**, which has real consequences.

*Required change:* back during an encounter prompts "Retreat from this fight?" rather than doing nothing or silently retreating. Add to P-04, not just P-02. On Android, a swallowed back gesture reads as a bug.

**CD-F-2 — Flutter renders its own widgets, so "feels native" is now a choice we make.** Under SwiftUI the app would have inherited iOS conventions for free. Under Flutter, the app looks like whatever P-01 decides on both platforms.

For Stride this is arguably an advantage — `GAME_BIBLE/UI_UX` asks for "a living adventure journal," which is a game aesthetic rather than a platform one. But it must be *chosen*.

*Required change:* P-01 states explicitly whether the visual identity is platform-adaptive or a single game aesthetic on both. My recommendation is a single aesthetic, with platform conventions honored only for navigation reflexes — back gesture, scroll physics, share sheets.

### Recommendation

Approve with CD-F-1 and CD-F-2 applied.

---

## Technical Director review

### Summary

The architecture translated cleanly because it was written around ports. The Pigeon boundary and the opaque anchor are the two details that make one ledger serve two genuinely different sync primitives, and both are correct.

### Findings

**TD-F-1 — `anchorInvalidated` needs a test scenario, not just a field.** `PROJECT_STRUCTURE.md` correctly identifies that Health Connect tokens can expire with no iOS equivalent, and argues the ledger handles it by design. That argument is sound but untested.

An expired token means the adapter cannot know what changed since last time. The reconciliation engine must not double-count on resync and must not claw back.

*Required change:* add a **thirteenth reconciliation scenario** to F-04 — *token invalidated mid-sequence; resync must neither double-count nor lose granted progress.* Twelve scenarios were sized for one platform; the second platform brings its own failure mode and deserves its own test.

**TD-F-2 — The CI Pigeon check will produce false failures.** The `app-android` job regenerates Pigeon output and fails if `git diff` is non-empty. Generated files routinely differ in header comments or version strings between tool versions, so this will fail on a Pigeon upgrade for reasons unrelated to a stale contract.

*Required change:* pin the Pigeon version in `pubspec.yaml` and compare only the generated files, not the whole tree. As written, `git diff --quiet` also catches unrelated working-tree changes.

**TD-F-3 — The iOS job references `packages/stride_health/example/ios`, which the structure document does not define.** Flutter plugin packages conventionally carry an `example/` app, and adapter tests need one to host them. It is implied but never specified.

*Required change:* add `packages/stride_health/example/` to `PROJECT_STRUCTURE.md` explicitly, or point the iOS test step elsewhere. A CI job referencing a path that no document defines is a migration failure waiting to happen.

**TD-F-4 — Android minimum SDK is deferred to F-01 with no decision criteria.** The architecture says "set at F-01 against Health Connect's floor," which is a placeholder rather than a decision.

*Required change:* F-01 must state the chosen `minSdkVersion` **and the player consequence** — which Android versions are excluded, and whether Health Connect requires a separate app install on the supported range. This is a distribution question, not just a build setting.

### Recommendation

Approve with TD-F-1 through TD-F-4 applied. TD-F-1 is the important one.

---

## QA Director review

### Summary

The testing story is transformed: the reconciliation suite now runs on the developer's machine in under a second, where previously it could not run at all. That single change does more for quality than anything else in this migration.

Two findings, one of which I consider the most important in this review.

### Findings

**QA-F-1 — "The twelve scenarios against both real adapters" has no home.** The architecture plan requires it (§6.6, §9.1) and the breakdown implies it in S-01b criterion 3. But running the scenarios against *real* adapters needs a device or emulator, real health data seeded into HealthKit and Health Connect, and — for iOS — a Mac. That is a substantial piece of work with no task, no owner, and no acceptance criteria.

It is also the mitigation for risk X-06, platform drift in step counting, which is the highest-severity risk the second platform introduces.

*Required change:* add **task V-02b — cross-adapter equivalence**, owned by the QA Director, dependent on S-01b, delivering the scenario suite executed against both real adapters with identical assertions. Without its own task this will be assumed done by whoever ships last, which is how a double-count reaches a player.

**QA-F-2 — The audio spike's acceptance criteria are not measurable.** The owner expanded A-04b to cover buses, crossfades, layered cues, ducking, interruption and resume, volume controls, and "latency and memory on a modest Android device." Good list — but "latency" and "memory" without numbers cannot pass or fail, and "a modest Android device" is undefined.

*Required change:* name a target device class and give numbers. Proposed: cue-trigger-to-audible **under 100 ms**, audio memory **within the 30 MB budget**, no dropouts during a crossfade, on a device roughly equivalent to a mid-range phone three or four years old. These are provisional and may move, but a spike whose result cannot be stated as pass or fail is a spike that always passes.

### Recommendation

Approve with QA-F-1 and QA-F-2 applied. QA-F-1 blocks nothing now but must exist before S-01b.

---

## Critic Agent review

### Summary

Scope held. No feature crept in under cover of the migration, which is the specific thing I was looking for — a stack change is the easiest possible moment to smuggle in "while we're rewriting anyway."

The prohibition on third-party health plugins is now mechanically enforced in CI rather than merely written down, which is the difference between a rule and a hope.

### Findings

**CR-F-1 — The migration is the moment the scope freeze is most vulnerable.** Nothing has crept in yet. But `DECISIONS/0004` froze scope against a Swift implementation, and every task is about to be re-created in Dart. Each re-creation is an opportunity to add "just one more thing" with the justification that it is new code anyway.

*Recommendation:* the migration plan must state that it is a **translation, not a redesign**, and that any behavioral change discovered during migration requires a decision record rather than a judgement call. Add it to `MIGRATION_EXECUTION_PLAN.md` as an explicit constraint.

**CR-F-2 — Do not mechanically port unverified Swift.** The owner already said this, and I want it enforced rather than remembered. The Swift F-01 scaffold **was never compiled.** Translating never-compiled Swift into Dart would carry unknown errors across a language boundary while wearing the appearance of a port.

*Recommendation:* the migration plan treats the Swift scaffold as **reference only, and specifically as reference for the enforcement patterns** — a core that cannot import the UI framework, a guard reading one shared list, a verification script honest about what it did not run. Not as a source to translate line by line. The `CorePurityTests` *approach* carries over; its code does not.

### What I checked and found clean

- No anti-features. No streaks, expiry, decay, energy gating on access, currency, or merchants.
- Deferred vocabulary still absent, and now guarded by a build-failing test from F-02.
- No Kernel violation. Steps gate rate, never access, on both platforms.
- No premature online infrastructure. §13 still resists it, and now notes honestly that two client implementations make a trustworthy leaderboard harder still.
- Scope frozen at four locations, five skills, three enemies, six tabs plus one modal.
- The `allowBackup=false` catch is the kind of platform-specific detail that usually gets discovered by a player whose progress doubled. Finding it in a plan rather than a bug report is the system working.

### Recommendation

**Approve.** CR-F-1 and CR-F-2 belong in the migration plan, not the task breakdown.

---

## Consolidated required changes

| ID | Change | Applied to |
|---|---|---|
| CD-F-1 | Back gesture during an encounter prompts to retreat | P-04 |
| CD-F-2 | P-01 states the platform-adaptive-versus-single-aesthetic choice | P-01 |
| TD-F-1 | **Thirteenth scenario: anchor/token invalidation** | F-04, S-02 |
| TD-F-2 | Pin Pigeon; compare generated files only | `ci.yml` |
| TD-F-3 | Define `packages/stride_health/example/` | `PROJECT_STRUCTURE.md` |
| TD-F-4 | F-01 states `minSdkVersion` and its player consequence | F-01 |
| QA-F-1 | **New task V-02b — cross-adapter equivalence** | Phase 6 |
| QA-F-2 | Numeric targets and a named device class for the audio spike | A-04b |
| CR-F-1 | Migration is translation, not redesign | Migration plan |
| CR-F-2 | Swift scaffold is reference for patterns, not a source to port | Migration plan |

All ten are applied. The finalized breakdown is `MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md` v2.0.

## Follow-up

No further design review is required before migration. The plans are presented for owner approval per next-action 7.
