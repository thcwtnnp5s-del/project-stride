# iOS device install — a Release build that runs unplugged

**Status:** canonical for how a build reaches the owner's iPhone.
**Written:** 2026-08-17 (Transformation Build 01, workstream I).
**Supersedes** the install paragraphs in `S01A_IOS_READINESS.md` (Route A) and
`MILESTONES/PLAYABLE_PHASE_2_ACCEPTANCE.md` (§Install) wherever they disagree
with this document. Those two remain the historical record of what was run.

---

## 0. The problem this solves

The phone currently refuses to open Stride from the Home Screen:

> debug-mode Flutter applications can only be launched from Flutter tooling

That is a **Flutter debug build**. Debug builds run Dart under a JIT VM, and
since iOS 14 the OS will only launch one while Flutter tooling (or Xcode) is
attached. It is not a signing failure and not a profile expiry.

**How a debug build got installed despite the instructions saying "profile".**
Both earlier documents said `flutter build ios --profile` and then *open the
workspace in Xcode and press Run*. Xcode's Run button builds the **scheme's Run
configuration**, and `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
has `LaunchAction buildConfiguration = "Debug"` (Flutter's default). The
profile build that `flutter build` produced was never the one Xcode installed;
Xcode rebuilt Debug and installed that. Any route that ends in "press Run in
Xcode" installs a debug build unless the scheme is edited first.

The fix is a route that never touches the Run button: build **Release** with
Flutter, install that bundle. `Scripts/ios/build-release-device.sh` does exactly
that and refuses to install a bundle that is still JIT.

| Build mode | Dart execution | Launches from the Home Screen? | Use |
|---|---|---|---|
| Debug | JIT (kernel_blob.bin) | **No** — refused by iOS 14+ | hot reload while attached |
| Profile | AOT, VM service kept on | Yes | performance tracing |
| **Release** | AOT, no VM service | **Yes** | what the owner installs; what a player would run |

---

## 1. Inspection report — what the project actually configures

Read from the repository on 2026-08-17. Nothing here was changed by this
workstream except the two `.xcconfig` includes and `.gitignore` noted in §2.

| Fact | Value | Where |
|---|---|---|
| Bundle identifier | `com.projectstride.stride` (Debug, Profile, Release); tests `…stride.RunnerTests` | `ios/Runner.xcodeproj/project.pbxproj` |
| Display name | `Stride` | `ios/Runner/Info.plist` |
| Deployment target | `17.0` in every configuration | `project.pbxproj`; enforced by `Scripts/check-ios-target.sh` (DECISIONS/0009) |
| Device family / orientation | iPhone only, portrait only | same |
| Signing style | Automatic. Runner sets no `CODE_SIGN_STYLE` (Xcode's default *is* Automatic); `CODE_SIGN_IDENTITY[sdk=iphoneos*] = "iPhone Developer"` | `project.pbxproj` |
| `DEVELOPMENT_TEAM` | **absent** from the committed project, deliberately, and a test asserts it stays absent | `test/s01a_ios_readiness_test.dart` |
| Provisioning profile specifier | absent (automatic) | — |
| Entitlements | `com.apple.developer.healthkit = true`, `…healthkit.access = []`; **`…healthkit.background-delivery` absent** and guarded | `ios/Runner/Runner.entitlements`, `Scripts/check-ios-target.sh` |
| Entitlements wired | `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` in Debug, Profile and Release | `project.pbxproj` |
| Usage strings | `NSHealthShareUsageDescription` present, non-empty; no `NSHealthUpdateUsageDescription` | `Info.plist` |
| Background modes | no `UIBackgroundModes` key | `Info.plist` |
| Xcconfig | `Debug.xcconfig` / `Release.xcconfig` include Flutter's `Generated.xcconfig`; the Profile configuration uses `Release.xcconfig` | `ios/Flutter/` |
| Dependency manager | no `ios/Podfile` is tracked; plugins resolve through Swift Package Manager (`FLUTTER_FRAMEWORK_SWIFT_PACKAGE_PATH` in `Generated.xcconfig`). If a `Podfile` appears on the Mac, Flutter generated it and CocoaPods is then required | `ios/`, CI |
| Xcode scheme Run configuration | **Debug** — see §0 | `Runner.xcscheme` |
| Where the save lives | Application Support inside the app container (`getApplicationSupportDirectory`), backup-excluded; the identity is in the Keychain | `lib/runtime/runtime_bootstrap.dart`, `stride_secure_store` |
| CI's iOS job | `flutter build ios --no-codesign --debug` on `macos-latest`, Flutter pinned **3.44.8** — compile evidence only, not installable | `.github/workflows/ci.yml` |
| Flutter version last used on the Mac | 3.47.0 (compiled cleanly, recorded as a run variable, not the CI evidence) | `PROJECT_STATE.md`, MISTAKES M-02 |

### 1.1 How Xcode picks the team, and where the team must live

With `CODE_SIGN_STYLE` Automatic and no `DEVELOPMENT_TEAM` in the project,
xcodebuild needs a team from *somewhere* or it stops with "Signing for
'Runner' requires a development team". There are three places it can come
from, and this project uses them in this order:

1. **`ios/Flutter/Local.xcconfig` (untracked, per machine) — the preferred
   home.** `Debug.xcconfig` and `Release.xcconfig` now carry
   `#include? "Local.xcconfig"` (an *optional* include, the same construct
   Flutter's own template uses for CocoaPods). Because the Profile
   configuration is based on `Release.xcconfig`, one file covers all three
   configurations. `.gitignore` names the file; `Local.xcconfig.example` is
   the tracked template. Xcode's Signing & Capabilities pane shows the
   resolved team, and `flutter build`/`flutter run` see it too, because it is
   an ordinary build setting. `flutter clean` does not delete it.
2. **`STRIDE_IOS_TEAM=<TEAMID>` in the environment for one run.** The script
   forwards it as `FLUTTER_XCODE_DEVELOPMENT_TEAM`; Flutter passes any
   `FLUTTER_XCODE_*` variable to xcodebuild as a build setting. Useful on a
   borrowed Mac; nothing persists.
3. **Flutter's own fallback.** When the project has no team, `flutter build
   ios` looks in the login keychain for "Apple Development" identities and
   uses that certificate's team (prompting if there is more than one). This
   is why the earlier device runs worked without editing anything: once the
   owner had signed in to Xcode ▸ Settings ▸ Accounts and Xcode had minted a
   Personal Team certificate, Flutter found it. It works, but it depends on
   keychain state nobody wrote down, which is why 1 is preferred.

What is **not** the answer: picking the team in Xcode's Signing pane. That
works, but Xcode writes `DEVELOPMENT_TEAM = XXXXXXXXXX;` into
`project.pbxproj` on the Mac — a dirty tracked file that will conflict with the
next `git pull`, and one careless stage away from publishing the team id. The
script warns when it sees this. If it happens: `git checkout --
ios/Runner.xcodeproj/project.pbxproj` and move the id into `Local.xcconfig`.

### 1.2 What a free Personal Team gives you, and what it does not

All from Apple's published limits for accounts without the paid Developer
Program, plus what this project has already proven on hardware
(`S01A_PHYSICAL_VALIDATION.md`).

| | Free Personal Team | Paid programme |
|---|---|---|
| Sign & install to your own devices from Xcode | yes | yes |
| **HealthKit capability** | **yes** — proven for this app on the owner's iPhone (`S01A_PHYSICAL_VALIDATION.md`); the entitlement is signed into the profile | yes |
| Background delivery entitlement | not requested and must stay absent (RULES H-5, DECISIONS/0014) — unrelated to the account tier | — |
| Provisioning profile validity | **7 days**; the app stops opening after that until reinstalled | 1 year |
| App IDs | at most **10 new App IDs per 7 days**; at most **3 apps signed by the free team installed on a device at once** | effectively unlimited |
| Device registration | done by Xcode automatically when the phone is first used as a destination (or by xcodebuild's automatic-provisioning flags) | same, plus manual |
| Ad-hoc `.ipa` for someone else's phone | **no** | yes (100 devices) |
| TestFlight | **no** | yes |
| App Store | no | yes |

**Honest statement:** with the free team, the *only* way a build reaches the
phone is a Mac, a cable (or same-network wireless after the first cable
pairing), and Xcode's tooling, and it has to be repeated at least every 7
days. Nothing in this document, and no script, changes that. DECISIONS/0011's
TestFlight route waits on the paid membership.

**Phone-side requirements**, all one-time per phone:

- **Developer Mode** (iOS 16+): Settings ▸ Privacy & Security ▸ Developer
  Mode ▸ on ▸ restart. The switch appears only after the phone has been
  connected to a Mac running Xcode once.
- **Trust the developer** after the first install: Settings ▸ General ▸ VPN &
  Device Management ▸ *your Apple ID* ▸ Trust. Until then the icon opens to
  "Untrusted Developer".
- **Trust This Computer** on the cable prompt.

### 1.3 Data persistence across reinstalls — what to expect

- **Reinstall of the same bundle id, signed by the same team** (which is what
  every 7-day renewal is): iOS performs an in-place upgrade. The app
  container — Documents and Library/Application Support, i.e. **the save** —
  is preserved. The Keychain identity is preserved. HealthKit authorisation is
  keyed to the bundle id and normally persists, so the Health sheet usually
  does not reappear; if it does, allow Steps again — nothing was lost.
- **Deleting the app from the phone** destroys the container, so the save is
  gone. Keychain items may or may not survive an uninstall; Apple documents
  nothing, and the project relies on nothing (`identity_vault_orphan_test`
  covers a save without its identity). Do not delete the app to "refresh" it.
- **Same bundle id, different team**: iOS refuses to install over the existing
  app, because the application identifier (team prefix + bundle id) changed.
  Delete first — and accept the save loss — or keep using the same Apple ID.
- A save written by the earlier debug/profile install is the same save the
  release build opens; build mode does not change the container or the format.

---

## 2. Files this workstream added or changed

| Path | What |
|---|---|
| `TECHNICAL/IOS_DEVICE_INSTALL.md` | this document |
| `Scripts/ios/build-release-device.sh` | preconditions → record `flutter --version` (and warn against the CI pin) → signing source → optional `flutter clean` → `flutter pub get` → **`flutter build ios --release` (codesigned)** → verify AOT + entitlements → hand off to install |
| `Scripts/ios/install-device.sh` | `flutter install --release` by default; `--devicectl` uses `xcrun devicectl device install app` + `process launch`; `--run` uses `flutter run --release` as the always-works fallback. Prints the phone-side taps |
| `ios/Flutter/Debug.xcconfig`, `ios/Flutter/Release.xcconfig` | `+ #include? "Local.xcconfig"` |
| `ios/Flutter/Local.xcconfig.example` | tracked template with the placeholder `ABCDE12345` |
| `.gitignore` | `+ ios/Flutter/Local.xcconfig` (last lines of the file) |
| `test/s01a_ios_readiness_test.dart` | new group *the device install workflow*: xcconfig includes and no literal team; the ignore line and example; scripts exist, are strict bash, build signed (never `--no-codesign`); scripts are `100755` in git once tracked (skips with a message until staged) |

Nothing in Dart application code, entitlements, `Info.plist` or the pbxproj
was touched. No team id, UDID or certificate is in any file.

Both scripts run on macOS only and say so on any other OS. Neither writes
anything under the repository except Flutter's normal `build/` output.

---

## 3. OWNER: NEXT MAC SESSION — one page

Do these in order. Total time about 15 minutes, most of it the build.

**Before the Mac (once):** on the Windows machine, make sure the branch is
pushed. On the Mac, if `ios/Runner.xcodeproj/project.pbxproj` shows as
modified in `git status`, run `git checkout -- ios/Runner.xcodeproj/project.pbxproj`
— that is Xcode's team edit from last time; the team now goes in a local file.

1. **Update the Mac clone**
   ```bash
   cd ~/ProjectStride            # wherever the clone is
   git fetch origin
   git checkout playable-phase-2-multiregion   # or the branch you were told
   git pull --ff-only
   ```
2. **Tell the build your team, once per Mac**
   ```bash
   cp ios/Flutter/Local.xcconfig.example ios/Flutter/Local.xcconfig
   ```
   Open `ios/Flutter/Local.xcconfig` in any editor and replace `ABCDE12345`
   with your ten-character Team ID (Xcode ▸ Settings ▸ Accounts ▸ your Apple
   ID ▸ the Personal Team row shows it). The file is ignored by git.
   *If you would rather not:* skip this step; the script will fall back to the
   certificate Xcode already made, or you can `export STRIDE_IOS_TEAM=<id>` for
   the session.
3. **Plug the phone in with a data cable and unlock it.** Answer *Trust This
   Computer* if asked. Keep it unlocked while the script runs.
4. **Run the script**
   ```bash
   bash Scripts/ios/build-release-device.sh
   ```
   Add `--clean` if the last build was on a different branch or Flutter
   version. It records `flutter --version` at the top of its output — keep
   that line with any device result you write down.
   The script builds Release, checks the bundle is AOT and carries HealthKit
   (and not background delivery), then installs.
   - If Flutter says several devices, `export STRIDE_IOS_DEVICE="<name or udid
     from the list>"` and rerun.
   - If it fails on signing, it prints the one-time Xcode steps (sign in,
     select the team, Run once with the phone attached, quit Xcode, then
     revert the pbxproj and rerun). This is the *only* time the Run button is
     acceptable, and it is only to register the device and mint the profile.
5. **On the phone, when told:** if Developer Mode is not on, turn it on
   (Settings ▸ Privacy & Security ▸ Developer Mode; the phone restarts) and
   rerun step 4. After the install, if tapping the icon says *Untrusted
   Developer*: Settings ▸ General ▸ VPN & Device Management ▸ your Apple ID ▸
   Trust.
6. **Unplug the cable.** Tap **Stride** on the Home Screen. It must open on
   its own. If it shows the "launched from Flutter tooling" message, the wrong
   bundle went on — run `bash Scripts/ios/install-device.sh --run`, press `q`
   when it is up, and try again.
7. **First launch of a fresh install:** the Health sheet appears — allow
   Steps. On a reinstall over the existing app it usually does not; your
   banked steps and location are still there (§1.3).

**"Expires in 7 days" means:** on day 8 the icon is still there but tapping it
does nothing or says the app is no longer available. Nothing is lost. Plug in,
run step 4 again; the reinstall renews the profile for another 7 days and
keeps the save. Renewing before day 7 is fine and identical.

**Re-signing on a different Mac:** steps 1–4 on that Mac with the *same* Apple
ID. A different Apple ID means a different team, and iOS will not install over
the existing app (§1.3).

**Flutter version on the Mac.** The Mac has had 3.47.0; CI pins 3.44.8. The
script prints both and does not stop. A device run on 3.47 is a valid device
run for the acceptance sheet — record the version with the result — but it is
not evidence for the pinned toolchain, and it is not the deliberate 3.47
evaluation that RULES G-2 / MISTAKES M-02 reserve for its own branch.

---

## 4. Constraints, restated

- No `--no-codesign` in the owner path; that flag is CI's compile-only build.
- No team id, UDID, certificate or profile in the repository. `Local.xcconfig`
  is ignored; the scripts take the team and device from the environment.
- Entitlements semantics unchanged; background delivery stays absent and both
  the guard and the release script refuse a bundle that carries it.
- Ad-hoc and TestFlight distribution do not exist for this project until the
  paid Developer Program is joined (DECISIONS/0011).
- `flutter install --release` installs the bundle that `flutter build ios
  --release` produced; it does not rebuild. `flutter run --release` builds,
  installs and launches, and the app remains after `q`.
