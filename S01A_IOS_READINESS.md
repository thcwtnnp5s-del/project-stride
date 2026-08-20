# S-01A — iOS Readiness, Installation, and the Blocker

Branch `s01a-foreground-health-harness`. Owner priority: validate on iPhone before
finishing Android device work. Android is preserved and paused, not reverted.

---

## The route, stated first

**Route A. Direct install from Xcode on the Mac, signed with a free Apple
Account under a Personal Team. No paid membership is required and none is to be
purchased.**

### Owner hardware

| Asset | Role |
|---|---|
| Dell Windows PC | **Primary development machine.** Unchanged. All Dart, Flutter, Android and guard work continues here. |
| Mac | **Sign-and-install station only.** Used to build the iOS app and push it to the phone. Not a development machine. |
| Personal iPhone | The validation target. |
| Ordinary Apple Account | Provides the free **Personal Team** used for automatic signing. |
| Apple Developer Program | **Not held, and not needed.** |

An earlier revision of this document recorded the owner as having no Mac and
concluded that no installation path existed. That was wrong about the hardware,
and everything it concluded from it is withdrawn. There is no blocker.

### What is still true, and worth keeping

Three facts survive the correction, because they are about the tools rather than
the hardware:

1. **Flutter cannot build an iOS app on Windows.** `flutter build ios` requires
   Xcode, which is macOS-only. This is Apple's restriction, not Flutter's — and
   it is why the Mac exists in this arrangement at all. The Dell remains primary
   for everything else.
2. **The macOS CI job builds `--no-codesign`.** An unsigned `.app` cannot be
   installed on any iPhone. The job proves the code compiles; it deliberately
   produces nothing installable, and `.github/workflows/ci.yml` says so in its
   own header comment. **A green iOS CI job is not an installed app**, and the
   closure table below keeps the two apart.
3. **A paid membership would not add anything this milestone needs.** It removes
   the 7-day provisioning limit and opens TestFlight. Neither is required to put
   the app on the owner's own phone and run the validation sequence.

### What was never the blocker

Worth stating, because the natural assumption is that iOS work remains:

- The Swift HealthKit adapter is **complete** — 1,094 lines of real
  `HKHealthStore`, `HKAnchoredObjectQuery`, and `HKStatisticsCollectionQuery`.
- The Pigeon contract, the entitlements, the usage string, the plugin
  registration and the deployment target are all correct and asserted by tests.
- The vertical slice — session, engine, save, gathering, harness — is shared and
  already exercised end to end.

Nothing in this repository is waiting on an iOS code change.

---

## Implementation map

### Already complete, unchanged by this milestone

| Layer | File | State |
|---|---|---|
| HealthKit reader | `HealthKitStepStore.swift` (738 lines) | Real. Availability guard, read-only step authorization, anchored discovery query, `HKStatisticsCollectionQuery` with `.cumulativeSum` + `.separateBySource` for absolute restatement, epoch-anchored UTC buckets, bounded recovery, deletion escalation. |
| Pigeon host | `HealthKitAdapter.swift` (356 lines) | Maps readings onto the contract. Fail-closed until `installOriginKeying`. |
| Registration | `StrideHealthPlugin.swift` | Registers, publishes for detach, drops the salt on detach. |
| Origin keying | `OriginKeying` (Swift) | FNV-1a over `salt‖0x1F‖utf8(bundleIdentifier)`, asserted against the shared vectors. |
| Swift tests | `example/ios/RunnerTests/` | 34 adapter tests + 12 origin-key vector tests. Run on macOS CI. |
| Runner config | `Info.plist`, `Runner.entitlements`, `project.pbxproj` | `NSHealthShareUsageDescription` present, no update string; `healthkit` entitled, **no** background-delivery; iOS 17; `com.projectstride.stride`; entitlements wired into Debug and Release. |
| Identity | `stride_secure_store` | iOS Keychain, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Simulator-tested on CI. |
| Shared slice | `StrideSession`, `GameEngine`, `SaveRepository`, `GatherResource` | Platform-neutral. Zero iOS branches — asserted. |

### The two HealthKit design points worth knowing before validating

**Two queries, not one.** `HKAnchoredObjectQuery` answers "what changed", which
is a delta; the contract needs an absolute. So the anchored query only discovers
*which* slices moved, and `HKStatisticsCollectionQuery` then restates what each
source's total for those buckets **now is**. A correction, a re-import, a delayed
addition and a deletion all come back through the second query as one kind of
answer.

**`HKDeletedObject` carries no date and no source.** A deletion cannot be
attributed to a bucket from the deletion alone. Any page carrying a deletion
therefore escalates to an authoritative restatement of the whole bounded
retention window. Deletions are rare; a lost grant is permanent.

### Changed in this milestone

| File | Change |
|---|---|
| `lib/ui/dev_harness.dart` | The provider's name is now per-platform (`HealthKit` / `Health Connect` / `Health provider` on a test host). The **only** platform branch in the app, asserted as such. Gather button names its yield. |
| `test/s01a_ios_readiness_test.dart` | New. 21 assertions on the configuration and structural facts a compile cannot catch. |

No Swift, no entitlement, and no Android file was modified.

---

## Route A — direct Xcode install (**the approved route**)

**Works with a free Apple Account under a Personal Team; no paid membership
needed.** The app is provisioned for 7 days and re-running from Xcode renews it.

Requirements: macOS current enough for Xcode 15+, Xcode with iOS 17 SDK, a
Lightning/USB-C cable, the iPhone, and the owner's ordinary Apple Account.

The minimum that genuinely has to be installed on the Mac is only this:

| # | Software | Why it is unavoidable |
|---|---|---|
| 1 | **Xcode** (Mac App Store), launched once so it installs its platform components | The only iOS toolchain, the only signer, and the only thing that can install to a connected phone. Supplies the iOS 17 SDK this project targets. |
| 2 | **Xcode Command Line Tools** | Installed by Xcode's first launch, or `xcode-select --install`. Flutter's iOS build calls them directly. |
| 3 | **Flutter SDK** (macOS) | `flutter build`/`flutter run` drive the Xcode build and generate the plugin registrant. |
| 4 | **CocoaPods** | The iOS plugin dependencies (`stride_health`, `stride_secure_store`) are resolved through the Podfile. Without it the workspace has no pods and the build fails at link. |
| 5 | **Git** | To clone the repository. Ships with the Command Line Tools. |

Nothing else. No Homebrew requirement, no Ruby version manager, no Fastlane, no
certificates to generate by hand, no App Store Connect account, no CI signing
infrastructure. If a step below appears to demand more than this list, stop and
report it rather than installing it.

1. Install Xcode from the Mac App Store. Launch once and let it install the
   platform components.
2. Install Flutter for macOS and run `flutter doctor` until the Xcode section is
   clean.
3. Clone the repository and check out `s01a-foreground-health-harness`.
4. `flutter pub get`, then `(cd packages/stride_core && dart pub get)`.
5. `open ios/Runner.xcworkspace` — the workspace, never the `.xcodeproj`.
6. Select the **Runner** target → **Signing & Capabilities**.
   - Tick **Automatically manage signing**.
   - **Team**: add your Apple ID under Xcode → Settings → Accounts, then select
     your personal team.
   - **Bundle Identifier**: `com.projectstride.stride` is likely taken by
     someone. If Xcode reports a conflict, change it to something unique —
     `com.<yourname>.stride`. This affects nothing in the code.
   - Confirm **HealthKit** appears under Capabilities. It comes from
     `Runner.entitlements` and needs no paid account.
7. On the iPhone: **Settings → Privacy & Security → Developer Mode** → on, then
   restart the phone when prompted. (iOS 16+. The toggle only appears after the
   phone has been connected to Xcode once.)
8. Connect the phone, trust the computer, and select it as the run destination.
9. `flutter run --debug` from the repository root, or press ⌘R in Xcode.
10. First launch will refuse: **Settings → General → VPN & Device Management →
    your Apple ID → Trust**. Then reopen the app.

**The 7-day limit.** With a free account the app stops launching after a week.
Re-run from Xcode to renew. With a paid membership it is a year.

## Route B — TestFlight: **out of scope, deliberately**

Recorded so nobody re-derives it as a missing step. It needs the Apple Developer
Program ($99/year) and App Store Connect, and it buys only two things this
milestone does not need: installing without the Mac connected, and sharing with
other people.

**Not to be configured.** No TestFlight, no App Store Connect, no cloud signing
pipeline, no signing certificate in CI. The owner has ruled these out and Route A
reaches the phone without any of them.

The only thing Route B would genuinely improve is the 7-day provisioning limit
below — and re-running from Xcode renews that in under a minute.

**Signing material stays out of the repository.** No `DEVELOPMENT_TEAM`, no
`.p12`, no `.mobileprovision` — asserted by `s01a_ios_readiness_test.dart`. A
team identifier committed to a public repo is the owner's identity in public and
breaks every other machine's build.

---

## Physical iPhone validation sequence

To run once a build reaches the device. Record only redacted output.

| # | Action | Expected |
|---|---|---|
| 1 | Clean install, launch | Harness. Usable energy `0`. Cursor `absent`. |
| 2 | Tap **Check HealthKit** | `available` on any iPhone. `unavailable — serviceUnavailable` on iPad. |
| 3 | Tap **Request Permission** | The HealthKit sheet appears asking for **Steps**, read-only. Allow it. Result shows `granted`. |
| 4 | Tap **Sync Steps** | Status `reconciled`. Origins ≥ 1, buckets ≥ 1. Newly granted equals your steps **from hours that have fully completed**. |
| 5 | Write down the usable energy | — |
| 6 | Tap **Sync Steps** again | Newly granted `0`. Energy unchanged. |
| 7 | Tap **Gather Meadow Herb — 80 energy** | — |
| 8 | Read the energy | Exactly 80 lower. |
| 9 | Read Held | `1× Meadow Herb`. |
| 10 | — | Foraging experience increased by 10. |
| 11 | Force-close: swipe up from the app switcher | Process killed. |
| 12 | Relaunch from the home screen | — |
| 13 | Read everything | Energy, herbs, XP, ledger and cursor all preserved. |
| 14 | Tap **Sync Steps** | Newly granted `0`. |
| 15 | Walk several hundred more steps | — |
| 16 | Wait for that hour to end, then **Sync Steps** | Only the new steps are granted. |
| 17 | Settings → Health → Data Access & Devices → Stride → turn Steps off, return, **Sync Steps** | No grant, no loss, no corruption. Energy and inventory unchanged. |

### Why step 16 says "wait for the hour to end"

The read runs to the end of the bucket the clock is inside so recent steps
arrive promptly, but the **completeness assertion stops at the previous
boundary**. Steps from the current hour are granted; the bucket stays open. A
tester syncing twice inside one hour and seeing a small second grant is watching
the system work, not fail.

### What must never appear

On screen, in Xcode's console, or in the save: a bundle identifier, a source or
device name, a salt, origin-key bytes, or anchor contents. Origins are a
**count**; the cursor is **present** or **absent**.

---

## The first real run, and the one defect it found

Route A was executed. Free Personal Team signing succeeded, the app installed
and ran, HealthKit reported `available` and `granted`, and the first sync
reconciled: eight pages, two origins, 721 UTC buckets, 837,163 steps observed,
407,105 newly granted, eight syncs committed, cursor present, backup exclusion
clean, identity in the Keychain.

It also reported **seven `cursorOfferedWhenProhibited` faults across eight
pages** — one per non-final page.

### What it was

`HKAnchoredObjectQuery` returns one updated anchor per page.
`HealthKitStepStore` assigned that anchor to both the continuation *and* the
candidate cursor on every page, and `HealthKitAdapter.map` forwarded it as
`nextCursor` without consulting `isFinalPage` — the only one of that page's
three outbound fields that was not gated on it. As a continuation the anchor is
correct mid-read; as a candidate cursor it claims the whole read is finished.

The Kotlin adapter had the gate and a multi-page test for it. iOS was the
outlier, and every Swift test that supplied an anchor also declared its page
final, so the suite stayed green straight through eight real pages of it.

### Why the save is safe and was not reset

The offer never became durable. `authorizeCursor` refused all seven as
`prohibitedNonFinalPage`, the bridge dropped each one and raised the fault,
`StepCheckpointAuthorized` carried the unchanged cursor forward, and only page
eight's cursor reached the save. No step was skipped, none was granted twice,
and the durable state is identical to what a correct adapter would have
produced. That equivalence is asserted, not assumed:
`packages/stride_health/test/multi_page_cursor_regression_test.dart` runs both
deliveries and compares canonical durable state.

The fault channel was doing its job. The defect was that the adapter made it
fire during ordinary operation, and a fault that fires on every normal read is
one nobody will read when it matters.

### Smallest re-validation on the device

The current save is evidence and is worth keeping, so this sequence does not
reset it. Rebuild and reinstall over the existing install:

| # | Action | Expected |
|---|---|---|
| 1 | Reinstall over the existing app, launch | Energy, inventory, XP and cursor all preserved. Cursor `present`. |
| 2 | Tap **Sync Steps** | **Zero faults.** Newly granted `0`, or only steps from hours completed since the first run. |
| 3 | Walk several hundred steps, wait for the hour to end, **Sync Steps** | Only the new steps granted. Zero faults. |
| 4 | Force-close, relaunch, **Sync Steps** | Everything preserved. Newly granted `0`. Zero faults. |

Step 2 is the whole test. A multi-page delivery is not required to prove the
fix — a single drained page proves the gate did not break the legal offer, and
the eight-page case is covered by the Swift and Dart regression tests. If a
paginated read does occur, the fault count must be zero and the cursor must
still be `present` afterwards.

---

## What a physical iPhone would prove that nothing else can

Every line touching `HKHealthStore` is unverified by any suite:

- that the authorization sheet appears and what a denial actually returns
- anchored-query drain behaviour against real sample volumes
- `wasUserEntered` filtering of manually-typed steps
- deletion reporting, and whether the escalation path behaves as designed
- `HKStatisticsCollectionQuery`'s per-source arithmetic against real sources
  (iPhone pedometer, Apple Watch, third-party apps)
- that `HKQueryAnchor` survives a force-quit and a reboot
- that a `ThisDeviceOnly` Keychain item is genuinely absent after an iCloud
  restore onto a second device — which needs **two** iPhones and an iCloud
  account, and is the one control the whole save-lineage design rests on

---

## Android status

Preserved, compiling, and not expanded. The Kotlin adapter, the host manifest,
the 75 Kotlin tests and the Android APK path are untouched by this milestone. No
Android physical validation was performed and no Android-only feature was added.

## Closure

| Condition | State |
|---|---|
| Branch CI is green | ✅ run `30963109118` — Dart core, Pigeon bindings, Android, iOS compile |
| The iOS build compiles | ✅ app shell, Swift health adapter and Swift secure-store adapter all compile; the 46 Swift tests and the simulator Keychain tests pass |
| A signed iPhone installation path exists | ✅ **executed** — free Personal Team signing succeeded; the app is installed and running on the owner's iPhone |
| The physical iPhone vertical slice passes | ✅ **PASS** — two syncs with zero faults, gather, and force-close persistence, all on real HealthKit data. `S01A_PHYSICAL_VALIDATION.md` |

The iOS compile job builds `--no-codesign` by design. It proves the code builds;
it deliberately produces nothing installable — so it is evidence for the second
row and for no other.

**All four closure conditions are met, and the branch is merged to master.**
The device run found one real adapter defect, it was inert, it was fixed, and
the re-run on hardware reported zero faults. S-01A is closed.

If free Personal Team signing fails at any point, the correct response is to
record the exact Xcode provisioning or HealthKit error and review it — **not** to
conclude that a paid membership is required. HealthKit is entitled under a free
Personal Team, and the entitlement is not to be removed or weakened to make a
signing error go away.
