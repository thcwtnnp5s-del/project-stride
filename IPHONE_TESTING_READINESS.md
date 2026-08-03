# iPhone Testing Readiness

**Date:** 2026-08-03
**Task:** S-01A — foreground HealthKit integration and device-validation harness
**Audience:** the project owner, with a Windows machine and an iPhone
**Referenced by:** `DECISIONS/0014_S01A_PRIORITY_AND_SCOPE.md` §Follow-up

---

## What this document is

An operational checklist of everything that must be obtained, configured, or
paid for before the S-01A technical harness can be installed on a physical
iPhone and read real HealthKit step data.

## What is true today, stated plainly

**Nothing in this repository has ever run against real health data.** Not once.

| Claim | Status |
|---|---|
| The Swift adapter's mapping and error handling behave correctly | ✅ tested — simulator XCTest, fabricated readings |
| The Keychain identity and backup exclusion behave correctly | ✅ tested — 38 cases against a real *simulator* Keychain, run `30780992412` |
| The iOS branch compiles | ✅ CI macOS job, three targets, `--no-codesign` |
| HealthKit returns step data | ❌ **never executed.** No `HKHealthStore` is constructed anywhere in this repository |
| Authorization prompt appears and is answerable | ❌ never executed |
| A real device installs and runs the app | ❌ never executed |

`HealthKitStepStore` in
`packages/stride_health/ios/stride_health/Sources/stride_health/HealthKitAdapter.swift`
is still the S-01b shell. It hardcodes `isAvailable { false }`, returns
`.unavailable` from `requestAuthorization()`, and returns an empty
`RawStepReading()` from `read()`. It never imports HealthKit, never calls
`HKHealthStore.isHealthDataAvailable()`, and never queries `stepCount`.

**If you installed today's `master` on your iPhone, the app would launch, report
"unavailable", and never prompt for anything.** That is correct behaviour for
the shell and it is not a device test. Replacing that shell is what S-01A is
for; this document covers everything *around* the code that must also exist.

Evidence categories are those of `DECISIONS/0014` §Evidence categories.
**Category 5 (iOS simulator verified) is never category 6 (physical iPhone
verified).** This project has already lost a class of defect to a green run on
the wrong platform — the POSIX lock hole, `PROJECT_STATE.md`.

---

## 1. Apple account and signing prerequisites

### 1.1 What you must decide first

**Owner input required — cannot be determined from this repository:** whether
you already have an Apple ID, and whether it is already enrolled in the Apple
Developer Program. Everything below assumes you have an Apple ID (the one on
your iPhone counts) and are not yet enrolled.

### 1.2 Free Apple ID ("Personal Team") vs. the paid programme

| | Free Apple ID | Apple Developer Program |
|---|---|---|
| Cost | £0 | **$99 / £79 / €99 per year**, auto-renewing |
| Provisioning profile lifetime | **7 days** | 1 year |
| Consequence when it expires | The app **stops launching** on the device until rebuilt and reinstalled from a Mac | Nothing; it keeps running |
| App IDs you may register | ~10 per 7-day window | unlimited in practice |
| Apps installed at once via free provisioning | ~3 | limited only by the device |
| Registered devices | small, informal limit | 100 per device type per membership year, resettable only at renewal |
| **HealthKit capability** | **Unverified — see §1.3** | **Available** |
| TestFlight | **Not available** | Available |
| App Store Connect access | none | full |

### 1.3 What is established, and what is not

Three separate statements, kept separate on purpose. An earlier draft of this
document collapsed them into a flat "you need the paid programme", which
asserted more than anyone here has checked.

**Established — free Personal Team provisioning expires after seven days.**
The app stops launching on the device until it is rebuilt and reinstalled from a
Mac. `DECISIONS/0007` sets the loop-validation window at one to two weeks, so a
free profile dies on **day 7, mid-test**. Reviving it needs physical access to a
Mac with the iPhone plugged into it — and if the Mac is a rented cloud instance,
the phone is not plugged into anything, so there is no revival path at all. This
alone makes a free account a poor fit for the fourteen-day walk, independently of
anything about HealthKit.

**Established — TestFlight and friend distribution require Apple Developer
Program membership.** There is no free route to either.

**NOT established — whether a free Personal Team can sign a HealthKit build for
direct device install.** Apple's free provisioning grants a restricted capability
set, and HealthKit's presence in it is **not something anyone on this project has
verified**. It must be checked against the **actual Xcode signing team**, with
the `com.apple.developer.healthkit` entitlement enabled, once a Mac is available
— Phase B step 7 in §8 is where you would first see it, when Xcode resolves the
team and either offers or refuses the capability. Do not plan around either
answer until then.

If it turns out HealthKit *cannot* be signed on a free team, the symptom will be
an entitlement failure at the `HKHealthStore` call rather than an authorization
prompt — the same class of failure the CI Keychain probe records as
`errSecMissingEntitlement (-34018)` for an unsigned host
(`.github/workflows/ci.yml`, *Keychain entitlement probe*). That probe is the
model for how to diagnose it quickly: print the numeric status rather than
inferring from a silent failure.

**The practical recommendation stands regardless:** the seven-day expiry and the
TestFlight requirement are each sufficient reason to enrol in the paid programme
for a fourteen-day validation. The HealthKit question changes the urgency, not
the conclusion.

**Enrolment is not instant.** Individual enrolment normally completes within
24–48 hours; identity verification can extend it to a week or more. Start it
before you need it.

---

## 2. Mac or cloud-Mac requirements

This is the single largest practical obstacle. You develop on Windows
(`TOOLCHAIN_REPORT_WINDOWS.md`: Flutter 3.44.8, full Android chain, **Xcode
absent — expected**). There is no way around it: **only macOS can compile,
sign, and install an iOS application.** `flutter build ios` does not exist on
Windows.

### 2.1 The GitHub Actions macOS runner cannot install to your phone

The `ios` job in `.github/workflows/ci.yml` runs on `macos-latest` and is
genuinely useful — it caught `HealthKitAdapter.swift` missing `import Flutter`,
a break invisible to every tool on Windows (`PROJECT_STATE.md`). It cannot,
however, put a build on your iPhone. Three reasons, all structural:

1. **No USB.** The runner is an ephemeral VM in a datacentre. Your iPhone is on
   your desk. There is no physical or network path between them; iOS device
   installation requires either a cable, a paired local network session, or an
   App Store Connect distribution channel.
2. **No signing identity.** Every compile step passes `--no-codesign`, and the
   secure-store test step signs **ad-hoc** (`CODE_SIGN_IDENTITY=-`,
   `CODE_SIGNING_REQUIRED=NO`, empty `DEVELOPMENT_TEAM`, empty
   `PROVISIONING_PROFILE_SPECIFIER`). Ad-hoc signatures are valid for a
   simulator and worthless on hardware. **No step in that workflow produces an
   installable binary** — the workflow header says so, deliberately.
3. **No credentials, and it must stay that way.** The repository is public. The
   `pull_request` trigger runs fork-authored code. `PUBLIC_REPOSITORY_READINESS_REPORT.md`
   §8.3 confirms there is no `${{ secrets.* }}` interpolation anywhere and
   `permissions: contents: read` at workflow level. Putting a signing
   certificate into that workflow as-is would expose it to fork PRs.

The runner *could*, with a paid membership and secrets added under an
appropriately gated trigger, build a signed `.ipa` and upload it to TestFlight.
That is a real option and is covered in §6. It still cannot do a direct install.

### 2.2 The realistic options

| Option | Money | Time | What breaks |
|---|---|---|---|
| **Buy a used Mac mini (M1/M2)** | ~£350–600 once | ~2h setup, ~1h Xcode download (≈20 GB) | Nothing. Direct USB install, `flutter run`, Xcode device console, Instruments. This is the only option that gives you a debugger attached to a phone reading real health data |
| **Borrow a Mac for a day** | £0 | a day | You get one install. When the profile or build needs refreshing you need the Mac again. Workable for a paid-membership 1-year profile; useless on a free account |
| **MacinCloud / MacStadium / Scaleway / AWS EC2 Mac** | £25–100+/month; AWS bills a **24-hour minimum** per dedicated host allocation (~£15–25/day) | 1–3h setup | **Cannot install to your phone.** Remote desktop to a Mac in a datacentre does not reach a USB port in your house. Useful only for building and uploading to TestFlight |
| **Codemagic / Bitrise (browser-configured macOS CI)** | free tier ~500 macOS min/month, then per-minute | 2–4h to wire up | Same limitation: builds and TestFlight uploads only, no direct install. Advantage over GitHub Actions: signing-certificate management is a first-class feature with a UI, so you are not hand-rolling secret handling on a public repo |
| **Xcode Cloud** | included allowance with the $99 membership | — | Initial configuration requires Xcode, which requires a Mac. Not a no-Mac path |
| **"Hackintosh" / macOS VM on Windows** | £0 | many hours | Violates the macOS licence agreement, breaks on updates, and Apple's device-pairing and notarisation paths are the parts most likely to fail. Not recommended, and not supported by this document |

### 2.3 Recommendation

**Buy a used Mac mini, or borrow one, and pair it with the paid membership.**

For a fourteen-day walk-around test with real health data, you will want to
reinstall after a crash, read the device console when something misbehaves, and
seed or inspect the Health app. A cloud Mac gives you none of that. The
build-and-TestFlight path (§6) is a legitimate fallback if buying hardware is
not acceptable, but it converts every diagnostic question into a new build,
upload, and processing cycle of 15–45 minutes.

---

## 3. Bundle identifier and entitlements

### 3.1 Bundle identifiers as actually configured

Read from `ios/Runner.xcodeproj/project.pbxproj` and the two plugin example
projects:

| Target | Bundle identifier | File |
|---|---|---|
| Main application (Debug / Release / Profile) | `com.projectstride.stride` | `ios/Runner.xcodeproj/project.pbxproj` |
| Main application unit tests | `com.projectstride.stride.RunnerTests` | same |
| Health plugin host app | `com.projectstride.strideHealthExample` | `packages/stride_health/example/ios/Runner.xcodeproj/project.pbxproj` |
| Secure-store plugin host app | `com.projectstride.strideSecureStoreExample` | `packages/stride_secure_store/example/ios/Runner.xcodeproj/project.pbxproj` |

`ios/Runner/Info.plist` sets `CFBundleIdentifier` to
`$(PRODUCT_BUNDLE_IDENTIFIER)`, so the build setting above is authoritative.

**Owner/agent input required:** which bundle the S-01A harness ships as is not
yet settled in the tree. The health example is described in its own
`lib/main.dart` as *"Host app for stride_health platform tests. Not a demo and
not a second game."* If the harness lives there, `com.projectstride.strideHealthExample`
needs the App ID, entitlement, and usage string. If it ships inside the main
app, `com.projectstride.stride` does. **Whichever bundle you install is the one
that needs all three.** Doing both costs one extra App ID and nothing else.

`com.projectstride.*` is not a domain you demonstrably control, but Apple does
not verify reverse-DNS ownership for App IDs. It only needs to be globally
unique, and it is fine as-is.

### 3.2 The entitlements file — **it does not exist**

```
find . -name "*.entitlements"   →   no matches
grep CODE_SIGN_ENTITLEMENTS ios/Runner.xcodeproj/project.pbxproj   →   no matches
grep -i HealthKit ios/Runner.xcodeproj/project.pbxproj   →   no matches
```

There is **no entitlements file anywhere in this repository**, and no target
references one. This is expected — the compile-only CI path never needed one —
and it is a hard blocker for device HealthKit.

**What must be created:** `ios/Runner/Runner.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.healthkit</key>
	<true/>
	<key>com.apple.developer.healthkit.access</key>
	<array/>
</dict>
</plist>
```

`healthkit.access` is an empty array deliberately: it is the **clinical health
records** opt-in, and Stride reads only `stepCount`. Do not add
`health-records`.

Do **not** add `com.apple.developer.healthkit.background-delivery`.
`DECISIONS/0014` puts background HealthKit observers explicitly out of S-01A
scope. It belongs to S-01B, which is additionally blocked on a real persistence
coordinator (`DECISIONS/0013` §6).

**Where it must be wired:** `ios/Runner.xcodeproj/project.pbxproj`, in the
Runner target's `Debug`, `Release`, and `Profile` `XCBuildConfiguration`
`buildSettings` blocks:

```
CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;
```

Xcode writes this for you when you add the HealthKit capability through
**Signing & Capabilities**; that is the safer route than hand-editing the
`.pbxproj`.

If the harness ships as the plugin example, the equivalent file is
`packages/stride_health/example/ios/Runner/Runner.entitlements` with the same
`.pbxproj` wiring in that project.

### 3.3 Current signing configuration, as actually set

| Setting | Value | Where |
|---|---|---|
| `CODE_SIGN_IDENTITY[sdk=iphoneos*]` | `"iPhone Developer"` | Runner target, all three configs |
| `CODE_SIGN_STYLE` | **absent on the Runner target**; `Automatic` on RunnerTests only | `project.pbxproj` |
| `DEVELOPMENT_TEAM` | **absent everywhere** | — |
| `PROVISIONING_PROFILE_SPECIFIER` | **absent everywhere** | — |
| `IPHONEOS_DEPLOYMENT_TARGET` | **13.0** | Runner target, all three configs; both plugin `Package.swift` files; both `.podspec` files |
| `TARGETED_DEVICE_FAMILY` | **`"1,2"`** — iPhone **and iPad** | Runner target, all three configs |
| CI compile steps | `flutter build ios --no-codesign --debug` | `.github/workflows/ci.yml` |
| CI secure-store test step | ad-hoc: `CODE_SIGN_IDENTITY=-`, `CODE_SIGNING_REQUIRED=NO`, `CODE_SIGNING_ALLOWED=YES`, empty team and profile | same |
| CI health test step | `CODE_SIGNING_ALLOWED=NO` | same |

`"iPhone Developer"` is the legacy identity string; modern Xcode uses
`"Apple Development"`. It resolves in current toolchains but is worth
correcting when you first open the project in Xcode.

`DEVELOPMENT_TEAM` being absent is correct for a repository with no Apple
account attached. When you set it in Xcode it will be written into
`project.pbxproj`. **A Team ID is not a secret** — it appears in every shipped
app — so committing it is fine. The certificate and private key are a different
matter entirely; see §7.

---

## 4. HealthKit capability requirements

### 4.1 Three separate things, all required

Adding "HealthKit" in Xcode's Signing & Capabilities pane does three things at
once, and all three must land or the app fails on device:

1. Writes the entitlement into `Runner.entitlements` (§3.2).
2. Enables the HealthKit service on the **App ID** in the Apple Developer
   portal — a server-side record, not a file in this repository.
3. Causes the provisioning profile to be regenerated including that
   entitlement. A stale profile from before the capability was added will
   install and then fail at runtime.

If you configure signing manually rather than through Xcode, all three must be
done by hand and step 3 is the one people forget.

### 4.2 `HKHealthStore.isHealthDataAvailable()`

The adapter must gate on this before constructing anything. It returns `false`
on iPad prior to iPadOS 17, and on Mac (Catalyst). **`TARGETED_DEVICE_FAMILY`
is currently `"1,2"`**, which declares iPad support — contradicting
`DECISIONS/0009` ("phone only, no iPad, no tablet-specific work") and meaning a
TestFlight build would be installable on an iPad where HealthKit may not exist
at all. Set it to `"1"`.

Today's `HealthKitStepStore` never calls `isHealthDataAvailable()`. It returns a
hardcoded `false`. **The availability path is therefore untested against any
real platform response**, only against the fake source injected in the Swift
unit tests.

### 4.3 What the simulator genuinely cannot exercise

The CI job's own comment is accurate and worth repeating: *"Nothing here
requests HealthKit authorization: an interactive permission prompt cannot be
answered on a CI runner."*

Beyond that, the simulator cannot give you:

- **Real step data.** There is no pedometer. Anything in the simulator's Health
  app was typed in by hand.
- **The authorization sheet as a user sees it** — the per-type toggles, the
  "Turn On All" affordance, and the fact that iOS deliberately does not tell an
  app whether *read* access was denied (a denied read type is indistinguishable
  from "no data"). That asymmetry is a real design constraint on reconciliation
  and it is unobservable in CI.
- **Anchor / `HKAnchoredObjectQuery` behaviour over a live store**, including
  `deletedObjects` and anchor invalidation — the exact behaviours scenario 13
  of the F-04 suite exists to survive.
- **`HKMetadataKeyWasUserEntered` filtering** against genuinely user-entered
  entries.
- **Multiple sources.** A real Health store has iPhone *and* Apple Watch writing
  step counts, which is what `StepOriginKey` and the per-origin watermarks exist
  for. One origin is not a test of a per-origin model.
- **Locked-device reads.** HealthKit data is encrypted at rest and unreadable
  while the device is locked. A simulator is never locked. This is documented in
  the adapter's own comment and is unverified.
- **Battery and background behaviour**, per `DECISIONS/0009`.

---

## 5. Privacy usage strings

### 5.1 The required keys

| Key | Required for Stride? | Why |
|---|---|---|
| `NSHealthShareUsageDescription` | **Yes** | The app reads step counts |
| `NSHealthUpdateUsageDescription` | **No** | **Stride never writes health data.** `HealthKitAdapter.swift` exposes exactly three operations — `isAvailable`, `requestAuthorization`, `fetchNewSteps` — and there is no `HKHealthStore.save`, no share-type set, and nothing in the Pigeon contract that could carry a write. Adding the key would declare a capability the app does not have |
| `NSHealthClinicalHealthRecordsShareUsageDescription` | No | Clinical records are not accessed |

### 5.2 Current state — **both keys are absent**

```
grep -rn "NSHealth" --include=*.plist .   →   NONE FOUND
```

Neither `ios/Runner/Info.plist` nor
`packages/stride_health/example/ios/Runner/Info.plist` contains any `NSHealth*`
key. Neither does any other plist in the repository.

### 5.3 Why this matters more than most missing configuration

**A missing usage string is an immediate crash, not a soft failure.** When an
app calls `requestAuthorization(toShare:read:)` without
`NSHealthShareUsageDescription` present in the *main app bundle's* `Info.plist`,
iOS terminates the process with an `NSInvalidArgumentException` at the moment of
the call. There is no error result, no `catch`, no degraded path. The
adapter's careful "never trap, report through the result" discipline does not
help — the crash happens inside the framework before the completion handler
exists.

It must be in the **application** target's `Info.plist`, not the plugin's. A
string in a framework or plugin bundle is not read.

A second, later failure mode: uploading a build that links HealthKit without the
purpose string is rejected during App Store Connect processing (the
`ITMS-90683` family of errors), so it also blocks the TestFlight route in §6.

### 5.4 What to add

In `ios/Runner/Info.plist` (and the harness host's plist if that is what you
install):

```xml
<key>NSHealthShareUsageDescription</key>
<string>Stride reads your step count so your real-world walking can power travel, gathering, and adventure in the game. Your health data stays on your device and is never uploaded.</string>
```

The second sentence must remain true. It currently is — `stride_core` is offline
and pure, and `PUBLIC_REPOSITORY_READINESS_REPORT.md` §3.2 records that origin
identifiers are pseudonymised behind a salt that never enters the core. Task
S-07 owns the matching privacy policy.

### 5.5 Two related privacy items also incomplete

- **`PrivacyInfo.xcprivacy` is not bundled.** The file exists at
  `packages/stride_health/ios/stride_health/Sources/stride_health/PrivacyInfo.xcprivacy`
  (and the secure-store equivalent), but it is empty of declarations and the
  lines that would ship it are commented out in **both**
  `stride_health.podspec` (`# s.resource_bundles = …`) and
  `ios/stride_health/Package.swift` (`# .process("PrivacyInfo.xcprivacy")`).
  Irrelevant for a direct install; **required for any App Store Connect upload**,
  and therefore for TestFlight.
- **Orientation contradicts `DECISIONS/0009`.** `ios/Runner/Info.plist` lists
  `UISupportedInterfaceOrientations` as portrait **plus landscape left and
  right**, and carries a `UISupportedInterfaceOrientations~ipad` array. The
  decision says portrait only, phone only, "enforced in the app target's
  `Info.plist` … and verified by a build-time check". Neither the enforcement
  nor the check exists. Not a blocker for reading steps; it is a blocker for
  `DECISIONS/0009` being true.

---

## 6. Direct-device install versus TestFlight

### 6.1 Direct install (development provisioning)

**Requires:** a Mac you can physically plug the iPhone into, Xcode, an Apple ID
(paid, for HealthKit), the device registered in the developer portal, and the
device trusted on that Mac.

**Flow:** open `ios/Runner.xcworkspace` in Xcode, select your team, select your
iPhone as destination, Run. Or `flutter run -d <device-id>` once signing is
configured.

**Profile lifetime:** 1 year with the paid programme, 7 days free.

**Best for:** the actual S-01A validation. You get the Xcode device console
(the only place a HealthKit entitlement failure prints a legible reason), you
can attach a debugger, and reinstalling after a crash takes 90 seconds.

**Common failure modes:** *"Failed to register bundle identifier"* — the App ID
already exists under another team, pick a new one. *"Untrusted Developer"* on
the phone — Settings ▸ General ▸ VPN & Device Management ▸ trust your
certificate. Build succeeds and the app crashes instantly on launch — nine
times in ten that is §5.3.

### 6.2 TestFlight

**Requires:** paid membership, an App Store Connect app record, a bundle version
that increments on every upload, a **release**-signed archive, the privacy
manifest bundled (§5.5), and App Privacy answers completed.

**Internal vs external** (`DECISIONS/0011`): up to 100 **internal** testers who
are App Store Connect users on your team — **no Beta App Review**. External
testers require Beta App Review and a published privacy policy. Owner-and-friends
fits inside the internal tier, which is the whole reason `0011` recommends it.

**Build lifetime:** 90 days, then the build expires and testers must update.

**Best for:** getting the build onto a friend's phone, and as the only viable
distribution path if you never obtain a Mac you can plug into — a cloud Mac or a
CI runner *can* archive, sign, and upload; it just cannot install.

**Common failure modes:** upload rejected at processing for a missing purpose
string (§5.3) or a missing privacy manifest; a build that never appears because
the version/build number was reused; "missing compliance" blocking distribution
until the encryption-usage question is answered (`ITSAppUsesNonExemptEncryption`
in `Info.plist` set to `false` avoids the prompt each time — accurate here,
since Stride uses only Apple's own Keychain and filesystem protection).

### 6.3 Recommendation for a fourteen-day solo walk

**Direct install from a Mac you own or can borrow, on a paid membership.**

The paid 1-year profile means you install once and walk for two weeks without
touching a computer, which is precisely what `DECISIONS/0007` asks for. TestFlight
would also survive fourteen days, but every diagnostic question — and on a first
real HealthKit integration there will be several — costs an archive, an upload,
and a processing wait, whereas a cable costs ninety seconds.

Set TestFlight up afterwards, when the harness has told you something and you
want a friend to walk with it too.

---

## 7. Secrets and certificates needed later

### 7.1 What you will eventually hold

| Artifact | What it is | Typical file |
|---|---|---|
| Apple Development certificate + private key | Signs builds for your own devices | `.cer` + `.p12` (password-protected) |
| Apple Distribution certificate + private key | Signs TestFlight / App Store builds | `.cer` + `.p12` |
| Provisioning profiles | Bind App ID + entitlements + devices + certificate | `.mobileprovision` |
| App Store Connect API key | Lets CI upload builds without your password | **`AuthKey_XXXXXXXXXX.p8`** + Key ID + Issuer ID |
| App-specific password | Alternative upload credential | a string |
| Team ID | Public identifier | a 10-character string — **not a secret** |

### 7.2 None of it may ever be committed. The repository is public.

`PUBLIC_REPOSITORY_READINESS_REPORT.md` §3.1 records the current state, verified
across **52 commits and 629 text blobs by two independent methods**:

> Apple signing certificates / provisioning profiles: **none** — CI uses
> `--no-codesign` and ad-hoc `CODE_SIGN_IDENTITY=-`

That clean result is a property of the tree today, not a guarantee about
tomorrow. `thcwtnnp5s-del/project-stride` is now **publicly visible**
(§8, §9 of the same report). A commit is world-readable within seconds of a
push, and automated harvesters index public pushes continuously.

**A leaked signing key in a public repository is an immediate revoke-and-reissue
event, not a "remove it in the next commit" event.** `git rm` does not help: the
blob remains reachable by SHA, and the report's own §F-5 demonstrates that
unreachable commits on this very repository are still fetchable by SHA from the
remote. If a `.p12` and its password, or a `.p8` API key, ever reach the remote:

1. **Revoke** the certificate in the Apple Developer portal, and revoke the API
   key in App Store Connect ▸ Users and Access ▸ Integrations. Do this first.
2. **Reissue** the certificate and regenerate every provisioning profile that
   referenced it. All existing builds signed with the revoked identity stop
   validating.
3. Rewrite history only afterwards, and treat the key as compromised regardless.

A stolen Apple Distribution key lets a stranger sign software as you. A stolen
App Store Connect API key lets them upload builds to your app record.

### 7.3 Practical protections

- Add to `.gitignore` before you download anything:
  `*.p12`, `*.p8`, `*.cer`, `*.certSigningRequest`, `*.mobileprovision`,
  `**/ios/Runner/*.xcuserdatad`. (`.gitignore` already covers `.env`, `.env.*`,
  `local.properties`, and `Generated.xcconfig`.)
- Store the certificate in the macOS Keychain and export only when a build
  machine needs it.
- If you ever wire signing into GitHub Actions, put the base64 `.p12` and the
  `.p8` into **repository secrets**, and gate the job so it never runs on a
  fork `pull_request`. The current workflow is safe precisely because it
  references **no** secrets; adding one changes its threat model and the
  public-repo fork trigger becomes load-bearing.
- Prefer a browser-configured CI (Codemagic) or a local Mac over hand-rolling
  secret handling on a public repository. Fewer places for the key to be.

### 7.4 One latent build failure worth fixing now

Both `packages/stride_health/ios/stride_health.podspec` and
`packages/stride_secure_store/ios/stride_secure_store.podspec` declare
`s.license = { :file => '../LICENSE' }`, but the three placeholder `LICENSE`
files were **deleted** during the public-readiness remediation
(`PUBLIC_REPOSITORY_READINESS_REPORT.md` §8.2). `find . -name LICENSE` now
returns nothing.

This has not broken CI because the current builds resolve plugins through Swift
Package Manager (`ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage`
is present, and `flutter doctor` reports `enable-swift-package-manager`). It
will surface as a CocoaPods warning or error the moment anything falls back to
the pod path — which is exactly the kind of thing that happens on a first
device build on an unfamiliar Mac. Point them at `../../../COPYRIGHT.md`, or
restore per-package licence files.

The same podspecs still carry template placeholders
(`homepage = 'http://example.com'`, `author = { 'Your Company' => 'email@example.com' }`,
`summary = 'A new Flutter plugin project.'`) in `stride_health`. Cosmetic, but
they will be in a shipped build.

---

## 8. Exact remaining steps

Ordered. From "no Mac, no account" to "harness running on my iPhone reading my
own steps".

**Legend:** ⓞ one-time · ↻ recurring · ⚑ blocks everything after it

### Phase A — account (start now; it has a queue)

1. ⓞ ⚑ Confirm which Apple ID you will use. The one on your iPhone is the
   sensible choice. *(Owner input — not determinable from this repository.)*
2. ⓞ ⚑ Enrol in the **Apple Developer Program**, $99/year.
   developer.apple.com/programs. Budget 24–48 hours, occasionally a week.
   Do not plan around a free account: HealthKit will not be available and the
   7-day profile expiry kills a 14-day walk (§1.3).
3. ⓞ Enable *Keep my email address private* and *Block command line pushes that
   expose my email* on the GitHub account, if not already — the commit author
   address is already public by accepted decision
   (`PUBLIC_REPOSITORY_READINESS_REPORT.md` §8.1), but there is no reason to add
   more.

### Phase B — a Mac

4. ⓞ ⚑ Obtain macOS access. Recommended: a used Mac mini M1/M2 (~£350–600).
   Acceptable: borrow one, given the paid membership's 1-year profile.
   Insufficient on its own: any cloud Mac — it cannot reach your phone (§2.2).
5. ⓞ Install Xcode from the Mac App Store (≈20 GB, allow an hour) and run
   `xcodebuild -runFirstLaunch`. Accept the licence.
6. ⓞ Install Flutter on the Mac and run `flutter doctor` until the iOS row is
   clean. Clone `https://github.com/thcwtnnp5s-del/project-stride`.
7. ⓞ Sign in to Xcode ▸ Settings ▸ Accounts with the Apple ID from step 1.

### Phase C — repository configuration (blocked on S-01A code landing)

These are code changes. Four agents are working concurrently on the Swift,
Kotlin, Dart, and boundary code; **this document does not make them.** Confirm
each is present before you build.

8. ⓞ ⚑ **Add `NSHealthShareUsageDescription`** to `ios/Runner/Info.plist` (and
   to the harness host's plist if the harness is the plugin example).
   **Do not add `NSHealthUpdateUsageDescription`** — Stride does not write.
   Without this the app crashes the instant it asks for authorization (§5.3).
9. ⓞ ⚑ **Create `ios/Runner/Runner.entitlements`** with
   `com.apple.developer.healthkit` (§3.2), and set
   `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` in the Runner target's
   Debug, Release, and Profile configurations. Easiest and safest via Xcode ▸
   target ▸ Signing & Capabilities ▸ **+ Capability** ▸ HealthKit, which also
   performs step 11 for you.
   **Do not enable background delivery** — out of scope per `DECISIONS/0014`.
10. ⓞ Set `TARGETED_DEVICE_FAMILY = "1"` (currently `"1,2"`), and fix
    `UISupportedInterfaceOrientations` to portrait only, per `DECISIONS/0009`
    (§4.2, §5.5). Consider raising `IPHONEOS_DEPLOYMENT_TARGET` from **13.0** to
    17.0 to match the same decision — check first that nothing in the tree
    depends on the lower target.
11. ⓞ In the developer portal, register the App ID
    (`com.projectstride.stride`, or the harness bundle) and **enable the
    HealthKit service** on it.
12. ⓞ In Xcode, set the Runner target's Team. `DEVELOPMENT_TEAM` gets written
    into `project.pbxproj`; committing it is fine (§3.3).
13. ⓞ Replace `HealthKitStepStore`'s shell with the real HealthKit
    implementation. **This is S-01A's actual work and is not complete at the
    time of writing** — see the top of this document. Until it lands, the app
    will report "unavailable" on a physical device and never prompt.

### Phase D — first device install

14. ⓞ Connect the iPhone by cable. Unlock it, tap **Trust This Computer**.
15. ⓞ In Xcode, select the iPhone as destination. Xcode registers the device
    with your team automatically on first run (counts against the 100-device
    annual allowance).
16. ↻ Build and run — Xcode ▸ Run, or `flutter run -d <device-id>`. Repeat this
    per code change, and **every 7 days if you ignored step 2 and used a free
    account**.
17. ⓞ On the iPhone: Settings ▸ General ▸ VPN & Device Management ▸ trust the
    developer certificate. Required once per certificate.
18. ⓞ Launch the app and trigger the authorization request. **Expect the
    HealthKit permission sheet.** If the app instead terminates immediately,
    step 8 was missed. If the sheet never appears and the app reports
    "unavailable", either step 9/11 was missed or step 13 has not landed —
    the Xcode device console will distinguish them.
19. ⓞ Grant **read** access to Steps. Note that iOS deliberately does not tell
    the app whether read access was denied; the harness must treat "denied" and
    "no data" as indistinguishable (§4.3).

### Phase E — the actual validation

20. ↻ Walk. Return to the app. Confirm the observed step count matches the
    Health app for the same window, per origin (iPhone vs. Apple Watch if you
    wear one).
21. ↻ Repeat across the F-04 scenarios that need a real store — anchor
    invalidation, deletions, delayed additions, multiple origins, a locked
    device, and app termination while data accumulates.
22. ⓞ Record results **as evidence category 6 (physical iPhone verified)** and
    never merge them with the simulator results, per `DECISIONS/0014`.
23. ⓞ Feed the outcome into **V-02b** — cross-adapter equivalence against a
    physical Android device (`MILESTONES/MILESTONE_01_TASK_BREAKDOWN.md`).

### Phase F — TestFlight, only if and when you want friends walking

24. ⓞ Bundle the privacy manifests (§5.5) — uncomment `s.resource_bundles` in
    both podspecs and `.process("PrivacyInfo.xcprivacy")` in both
    `Package.swift` files, and fill in the declarations.
25. ⓞ Write the privacy policy and publish it (task **S-07**, gap **G-09**).
    Required for external TestFlight and for any Play distribution
    (`DECISIONS/0011`).
26. ⓞ Create the App Store Connect record; complete App Privacy answers
    declaring health data, used for app functionality, not linked to identity,
    not used for tracking. Match what the code actually does.
27. ⓞ Add testers as **internal** App Store Connect users to skip Beta App
    Review (`DECISIONS/0011`).
28. ↻ Archive, sign for distribution, upload. Increment the build number every
    time. Builds expire after 90 days.
29. ↻ If you automate this: certificates and the `.p8` API key go in repository
    secrets, **never in a commit**, and the job must not run on fork
    `pull_request` (§7).

---

## 9. Blockers, in one place

Everything below is genuinely absent from the repository right now.

| # | Blocker | File that must change | Effect if unaddressed |
|---|---|---|---|
| B-1 | `NSHealthShareUsageDescription` missing from **every** plist | `ios/Runner/Info.plist`, and/or `packages/stride_health/example/ios/Runner/Info.plist` | **Immediate crash** on `requestAuthorization`. Also blocks App Store Connect upload |
| B-2 | No entitlements file exists anywhere; no `CODE_SIGN_ENTITLEMENTS` on any target | new `ios/Runner/Runner.entitlements` + `ios/Runner.xcodeproj/project.pbxproj` | HealthKit calls fail the entitlement check; no prompt appears |
| B-3 | HealthKit not enabled on any App ID | Apple Developer portal (not a file) | Entitlement cannot be signed into the profile |
| B-4 | `HealthKitStepStore` is a shell returning `isAvailable = false` | `packages/stride_health/ios/stride_health/Sources/stride_health/HealthKitAdapter.swift` | The app reports "unavailable" on a real iPhone and reads nothing. **This is S-01A's work, in progress** |
| B-5 | No `DEVELOPMENT_TEAM`, no signing style on the Runner target | `ios/Runner.xcodeproj/project.pbxproj` | Cannot produce an installable binary. Correct today; must change on a Mac |
| B-6 | No Apple Developer Program membership | owner action | **Established:** no TestFlight, and free provisioning expires every 7 days, which breaks a 14-day walk. **Unverified:** whether HealthKit can be signed on a free Personal Team at all — check on the Mac (§1.3) |
| B-7 | No macOS access | owner action | Cannot build, sign, or install at all |
| B-8 | `TARGETED_DEVICE_FAMILY = "1,2"` includes iPad | `ios/Runner.xcodeproj/project.pbxproj` | Installable on iPad, where `isHealthDataAvailable()` may return `false`. Contradicts `DECISIONS/0009` |
| B-9 | `IPHONEOS_DEPLOYMENT_TARGET = 13.0` | `.pbxproj`, both `Package.swift`, both `.podspec` | Contradicts `DECISIONS/0009`'s iOS 17 minimum. Not a device blocker |
| B-10 | Landscape orientations declared | `ios/Runner/Info.plist` | Contradicts `DECISIONS/0009` portrait-only, which claims `Info.plist` enforcement and a build-time check; neither exists |
| B-11 | `PrivacyInfo.xcprivacy` not bundled | both `.podspec`, both `Package.swift` | Blocks App Store Connect upload; irrelevant to direct install |
| B-12 | Podspecs reference `../LICENSE`, which no longer exists | both `.podspec` | Latent CocoaPods failure on any non-SPM build path |

**B-1, B-2, B-3, B-4, B-6 and B-7 are the six that stand between you and a
single real step reading.** The rest are correctness and distribution debt.

---

## 10. What this document does not claim

- That real HealthKit reads work. **They have never been attempted.**
- That the authorization prompt appears. Never observed.
- That per-origin attribution survives a real multi-source Health store. Never
  observed.
- That the F-04 scenarios hold against a live anchored query. Verified against
  a pure-Dart simulation and a fabricated Swift source only — evidence
  categories 1 and 2, never 6.

The CI macOS job proves that the iOS branch **compiles**, and that Keychain and
backup-exclusion code behaves correctly **on a simulator**. That is the whole of
what it proves, and the workflow says so in its own comments. Everything in this
document exists because that is not enough.
