# S-01A — iOS Readiness, Installation, and the Blocker

Branch `s01a-foreground-health-harness`. Owner priority: validate on iPhone before
finishing Android device work. Android is preserved and paused, not reverted.

---

## The blocker, stated first

**Route C. There is no iPhone installation path from this machine, and no amount
of further code changes creates one.**

The owner has a Windows PC and an iPhone. No Mac, no macOS environment, no paid
Apple Developer Program membership.

Three facts, each independently sufficient:

1. **Flutter cannot build an iOS app on Windows.** `flutter build ios` requires
   Xcode, which is macOS-only. This is Apple's restriction, not Flutter's.
2. **The macOS CI job builds `--no-codesign`.** An unsigned `.app` cannot be
   installed on any iPhone. The job proves the code compiles; it deliberately
   produces nothing installable, and `.github/workflows/ci.yml` says so in its
   own header comment.
3. **Every install route terminates in a Mac.** Direct Xcode install needs one on
   the desk. TestFlight needs one to produce the archive — or a macOS CI runner
   holding the owner's signing certificate and provisioning profile as
   repository secrets, which is signing infrastructure nobody has asked for and
   which needs a paid membership anyway.

**A paid Apple Developer membership alone would not unblock this.** It removes
the 7-day provisioning limit and opens TestFlight; it does not produce a build.
The Mac is the binding constraint, and it is the only one.

### What is *not* the blocker

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

## Route A — direct Xcode install (available the day a Mac is)

Shortest legitimate route. **Works with a free Apple Account; no paid membership
needed.** The app is provisioned for 7 days and re-running from Xcode renews it.

Requirements: macOS current enough for Xcode 15+, Xcode with iOS 17 SDK, a
Lightning/USB-C cable, the iPhone, and any Apple ID.

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

## Route B — TestFlight (needs a Mac *and* a paid membership)

Only worth doing if the owner wants to install without the Mac connected, or to
share with friends.

1. Enrol in the Apple Developer Program ($99/year).
2. In App Store Connect, register the bundle identifier and create the app
   record. **No marketing material, no screenshots, no App Store review** —
   TestFlight internal testing needs none of it.
3. On the Mac: `flutter build ipa --release`.
4. Open `build/ios/archive/Runner.xcarchive` in Xcode → Distribute App → App
   Store Connect → Upload.
5. Wait for processing (usually minutes), then add yourself as an internal
   tester.
6. On the iPhone: install **TestFlight** from the App Store, accept the
   invitation, install Stride.

Builds expire after 90 days.

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
| 7 | Tap **Gather Meadow Herb — 90 energy** | — |
| 8 | Read the energy | Exactly 90 lower. |
| 9 | Read Held | `2× Meadow Herb`. |
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
| A signed iPhone installation path exists | ❌ **blocked on Mac access** |
| The physical iPhone vertical slice passes | ❌ blocked on the above |

The iOS compile job builds `--no-codesign` by design. It proves the code builds;
it deliberately produces nothing installable.

**Not merged to master.** Two of the four closure conditions are unmet, and
neither is a code problem.
