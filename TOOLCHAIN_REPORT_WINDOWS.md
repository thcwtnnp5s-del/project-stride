# Windows Toolchain Report

**Machine:** Dell, Windows 11 25H2 (10.0.26200.8894)
**Date:** 2026-08-01
**Task:** M-1
**Status:** Flutter and Dart operational. Android build chain incomplete — one blocking item.

---

## Summary

| Component | State |
|---|---|
| Flutter stable | ✅ 3.44.8 |
| Dart | ✅ 3.12.2 |
| Android SDK command-line tools | ✅ installed, packages not yet downloaded |
| Java toolchain | ⛔ **install failed — blocking** |
| Android platform-tools / adb | ⛔ blocked on Java |
| Android emulator | ⛔ blocked on Java |
| Editor tooling | ➖ optional, see below |
| Xcode | ➖ **iOS-only, expected absent on Windows** |

**What this permits today:** the entire Dart simulation, the entire Flutter UI, all unit and widget tests, and both enforcement guards — all verified running (see `MIGRATION_COMPLETION_REPORT.md`).

**What it blocks:** building or running the Android app, and therefore the emulator check in M-2's acceptance criteria.

---

## Actual command output

### `flutter --version`

```text
Flutter 3.44.8 • channel stable • https://github.com/flutter/flutter.git
Framework • revision 058e0af2c2 (9 days ago) • 2026-07-23 10:56:21 -0700
Engine • hash 13ffd72b2f9a5ca4db2a74ea52d5353ec2e8f939 (revision 0cd610717b) (9 days ago) • 2026-07-23 16:11:34.000Z
Tools • Dart 3.12.2 • DevTools 2.57.0
```

### `dart --version`

```text
Dart SDK version: 3.12.2 (stable) (Tue Jun 9 01:11:39 2026 -0700) on "windows_x64"
```

### `adb --version`

```text
bash: adb: command not found
```

Not installed. `adb` ships in the Android SDK `platform-tools` package, which is downloaded by `sdkmanager` — and `sdkmanager` is a Java program. Blocked behind the JDK.

### `flutter doctor -v`

```text
[√] Flutter (Channel stable, 3.44.8, on Microsoft Windows [Version 10.0.26200.8894], locale en-US) [163ms]
    • Flutter version 3.44.8 on channel stable at C:\Users\jwspa\dev\flutter
    • Upstream repository https://github.com/flutter/flutter.git
    • Framework revision 058e0af2c2 (9 days ago), 2026-07-23 10:56:21 -0700
    • Engine revision 0cd610717b
    • Dart version 3.12.2
    • DevTools version 2.57.0
    • Feature flags: enable-web, enable-linux-desktop, enable-macos-desktop, enable-windows-desktop, enable-android, enable-ios, cli-animations, enable-native-assets, enable-swift-package-manager, omit-legacy-version-file, enable-lldb-debugging, enable-uiscene-migration

[√] Windows Version (Windows 11 or higher, 25H2, 2009) [520ms]

[X] Android toolchain - develop for Android devices [27ms]
    X ANDROID_HOME = C:/Users/jwspa/dev/android-sdk
      but Android SDK not found at this location.

[√] Chrome - develop for the web [11ms]
    • Chrome at C:\Program Files\Google\Chrome\Application\chrome.exe

[X] Visual Studio - develop Windows apps [10ms]
    X Visual Studio not installed; this is necessary to develop Windows apps.
      Download at https://visualstudio.microsoft.com/downloads/.
      Please install the "Desktop development with C++" workload, including all of its default components

[√] Connected device (3 available) [139ms]
    • Windows (desktop) • windows • windows-x64    • Microsoft Windows [Version 10.0.26200.8894]
    • Chrome (web)      • chrome  • web-javascript • Google Chrome 150.0.7871.187
    • Edge (web)        • edge    • web-javascript • Microsoft Edge 150.0.4078.99

[√] Network resources [471ms]
    • All expected network resources are available.

! Doctor found issues in 2 categories.
```

---

## Issue classification

### Android-blocking

**A-1 — Java toolchain not installed.**

Two winget attempts failed at the download stage, not at install:

```text
Microsoft.OpenJDK.17         → InternetOpenUrl() failed. 0x80072f78
EclipseAdoptium.Temurin.17   → download stalled past a 15-minute timeout
```

This looks like a network restriction on the JDK CDNs rather than a machine problem — Flutter's own ~1 GB download from `storage.googleapis.com` and the 136 MB Android command-line tools from `dl.google.com` both succeeded on the same connection.

Java is required by `sdkmanager` and by Gradle, so it blocks **A-2**, **A-3**, and every Android build. **This is the only genuinely blocking item.**

**A-2 — Android SDK packages not downloaded.** Command-line tools are installed at `C:\Users\jwspa\dev\android-sdk\cmdline-tools\latest`; `platform-tools` (adb), `platforms`, `build-tools`, and `emulator` are not. Blocked by A-1.

**A-3 — No Android emulator/AVD.** Blocked by A-2.

**A-4 — Android licences not accepted.** `flutter doctor --android-licenses` needs Java. Blocked by A-1.

### iOS-only — expected, not a Windows failure

**I-1 — Xcode absent.** `flutter doctor` does not even list Xcode on Windows. This is correct and expected: iOS builds run in the CI macOS job (`.github/workflows/ci.yml`), and later on a real Mac for signing, TestFlight, real HealthKit, and haptic validation. **Not a Windows-development failure.**

### Optional — not needed for this project

**O-1 — Visual Studio / Desktop C++ absent.** Only needed to build Windows *desktop* apps. `DECISIONS/0010` says mobile only, and the project has no `windows/` target. Ignore this warning permanently.

**O-2 — Chrome/Edge listed as devices.** Flutter's web support is enabled at SDK level, but the project was created with `--platforms=android,ios` and has no `web/` directory. Verified: only `android/` and `ios/` exist. Ignore.

**O-3 — No IDE plugin installed.** Claude Code plus the CLI is the working setup, and `flutter test` / `dart test` need no editor. Optional: Android Studio (also the easiest route to the emulator) or VS Code with the Dart and Flutter extensions.

---

## Installed layout

| Item | Path |
|---|---|
| Flutter SDK | `C:\Users\jwspa\dev\flutter` (git clone, `stable`, `--depth 1`) |
| Dart SDK | bundled at `flutter\bin\cache\dart-sdk` |
| Android SDK root | `C:\Users\jwspa\dev\android-sdk` |
| Android cmdline-tools | `…\android-sdk\cmdline-tools\latest` |
| GitHub CLI | `C:\Program Files\GitHub CLI` (2.97.0) |

User environment variables set: `ANDROID_HOME`, `ANDROID_SDK_ROOT`, and `Path` additions for `flutter\bin`, `android-sdk\platform-tools`, and `android-sdk\cmdline-tools\latest\bin`.

`flutter config --android-sdk` points at the SDK root.

> **New terminals pick these up automatically. Already-open terminals will not** — restart them, or the paths will look missing.

---

## To finish the Android chain

### 1. Install a JDK

Retry winget first — the failures looked transient:

```bash
winget install --id EclipseAdoptium.Temurin.17.JDK --accept-package-agreements --accept-source-agreements
```

If it fails again, download the **Temurin 17 (LTS) Windows x64 .msi** directly from `https://adoptium.net/temurin/releases/` and run the installer.

Verify:

```bash
java -version
```

### 2. Install the SDK packages

```bash
sdkmanager --sdk_root=%ANDROID_HOME% "platform-tools" "platforms;android-35" "build-tools;35.0.0" "emulator" "system-images;android-35;google_apis;x86_64"
```

### 3. Accept licences

```bash
flutter doctor --android-licenses
```

### 4. Create an emulator

```bash
avdmanager create avd -n stride_pixel -k "system-images;android-35;google_apis;x86_64" -d pixel_7
```

### 5. Confirm

```bash
flutter doctor -v
```

The Android toolchain line should turn green. Then, from the repository root:

```bash
flutter run
```

---

## What still requires macOS

Unchanged by anything here, and not a Windows deficiency:

- Compiling, signing, and archiving the iOS app
- TestFlight upload
- iOS simulator or physical iPhone testing
- Developing and debugging the Swift HealthKit adapter (S-01b)
- iOS audio, haptic, and battery validation

The CI macOS job covers compilation from day one. The rest waits for real Mac access.

## What requires a physical Android device

Per the owner's instruction, not required for M-1 or M-2, and deferred:

- Real Health Connect permission flows and step data
- Background sync behavior under Doze
- Process-kill and save-integrity testing
- Installed-APK validation
- Cross-adapter equivalence (V-02b)
