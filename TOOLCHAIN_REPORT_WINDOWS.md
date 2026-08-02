# Windows Toolchain Report

**Machine:** Dell, Windows 11 25H2 (10.0.26200.8894)
**Date:** 2026-08-01
**Task:** M-1
**Status:** ✅ **Complete. The full Android chain is operational.**

> **Revised.** An earlier version of this report recorded the JDK install as failed and Android as blocked. The first Temurin attempt had in fact succeeded — it ran long and its result arrived after the report was written; a second attempt then failed only as redundant. Once Java was confirmed present the remaining chain installed normally. **There is no outstanding Android blocker.**

---

## Summary

| Component | State |
|---|---|
| Flutter stable | ✅ 3.44.8 |
| Dart | ✅ 3.12.2 |
| Java toolchain | ✅ Temurin 17.0.20+8 |
| Android SDK | ✅ platform-36, build-tools 36.1.0, NDK 28.2, CMake 3.22.1 |
| adb | ✅ 1.0.41 (37.0.1) |
| Android emulator | ✅ 37.1.11, AVD `stride_pixel` (API 36) |
| Android licences | ✅ all accepted |
| Editor tooling | ➖ optional, see below |
| Xcode | ➖ **iOS-only, expected absent on Windows** |

**Verified working:** the entire Dart simulation, the entire Flutter UI, all tests, both enforcement guards, **the Android APK build**, and **the app running on an emulator**.

`flutter doctor` reports no Android issues.

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
Android Debug Bridge version 1.0.41
Version 37.0.1-15733141
Installed as C:\Users\jwspa\dev\android-sdk\platform-tools\adb.exe
Running on Windows 10.0.26200
```

### `java -version`

```text
openjdk version "17.0.20" 2026-07-21
OpenJDK Runtime Environment Temurin-17.0.20+8 (build 17.0.20+8)
```

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

[√] Windows Version (Windows 11 or higher, 25H2, 2009) [575ms]

[√] Android toolchain - develop for Android devices (Android SDK version 36.1.0) [1,382ms]
    • Android SDK at C:\Users\jwspa\dev\android-sdk
    • Emulator version 37.1.11.0 (build_id 15917651) (CL:N/A)
    • Platform android-36, build-tools 36.1.0
    • ANDROID_HOME = C:/Users/jwspa/dev/android-sdk
    • Java binary at: C:/Program Files/Eclipse Adoptium/jdk-17.0.20.8-hotspot\bin\java
      This JDK is specified by the JAVA_HOME environment variable.
      To manually set the JDK path, use: `flutter config --jdk-dir="path/to/jdk"`.
    • Java version OpenJDK Runtime Environment Temurin-17.0.20+8 (build 17.0.20+8)
    • All Android licenses accepted.

[√] Chrome - develop for the web [9ms]
    • Chrome at C:\Program Files\Google\Chrome\Application\chrome.exe

[X] Visual Studio - develop Windows apps [8ms]
    X Visual Studio not installed; this is necessary to develop Windows apps.
      Download at https://visualstudio.microsoft.com/downloads/.
      Please install the "Desktop development with C++" workload, including all of its default components

[√] Connected device (4 available) [325ms]
    • sdk gphone64 x86 64 (mobile) • emulator-5554 • android-x64    • Android 16 (API 36) (emulator)
```

The only remaining `[X]` is Visual Studio, which is for Windows *desktop* builds and is permanently irrelevant to a mobile-only project.

### Android build and run — verified

```text
flutter build apk --debug
√ Built build\app\outputs\flutter-apk\app-debug.apk

flutter build apk --debug        (packages/stride_health/example)
√ Built build\app\outputs\flutter-apk\app-debug.apk

adb install -r … → Success
adb shell am start -n com.projectstride.stride/.MainActivity
topResumedActivity=ActivityRecord{… com.projectstride.stride/.MainActivity}
logcat: no FATAL, no AndroidRuntime, no E/flutter
```

Screenshot: `MILESTONES/evidence/m2_android_emulator.png` — portrait, rendering the live `stride_core` version string, which is what proves the app target actually links the package.

**This means the Kotlin adapter, the Pigeon-generated Kotlin, the plugin registration, `minSdk 26`, and `allowBackup=false` all compile and run.**

---

## Issue classification

### Android-blocking

**None.** The chain that was previously blocked — JDK, SDK packages, adb, emulator, licences — is complete and verified.

*Historical note, kept because it cost real time:* `Microsoft.OpenJDK.17` failed with `InternetOpenUrl() failed. 0x80072f78`, and `EclipseAdoptium.Temurin.17` appeared to stall. The Temurin install had actually succeeded; it simply ran past the observation window. **The lesson is procedural — confirm a long install by checking for the artifact, not by watching its exit.** A `java -version` check would have saved a wrong entry in the first version of this report.

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
| JDK 17 | `C:\Program Files\Eclipse Adoptium\jdk-17.0.20.8-hotspot` |
| Android SDK root | `C:\Users\jwspa\dev\android-sdk` |
| Android cmdline-tools | `…\android-sdk\cmdline-tools\latest` |
| AVD | `stride_pixel` — Pixel 7, API 36, google_apis, x86_64 |
| GitHub CLI | `C:\Program Files\GitHub CLI` (2.97.0) |

User environment variables set: `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT`, and `Path` additions for `flutter\bin`, `android-sdk\platform-tools`, and `android-sdk\cmdline-tools\latest\bin`.

`flutter config --android-sdk` points at the SDK root.

> **New terminals pick these up automatically. Already-open terminals will not** — restart them, or the paths will look missing.

---

## Daily use

**Open a fresh terminal** — already-open ones predate the environment variables and will look broken.

From the repository root:

```bash
flutter emulators --launch stride_pixel
```

```bash
flutter run
```

Full local verification, no emulator needed:

```bash
./Scripts/verify.sh
```

### Rebuilding this setup elsewhere

```bash
git clone --depth 1 -b stable https://github.com/flutter/flutter.git C:\Users\<you>\dev\flutter
winget install --id EclipseAdoptium.Temurin.17.JDK --accept-package-agreements --accept-source-agreements
sdkmanager --sdk_root=%ANDROID_HOME% "platform-tools" "platforms;android-36" "build-tools;36.1.0" "emulator" "system-images;android-36;google_apis;x86_64"
flutter doctor --android-licenses
avdmanager create avd -n stride_pixel -k "system-images;android-36;google_apis;x86_64" -d pixel_7
```

Set `JAVA_HOME`, `ANDROID_HOME`, and `ANDROID_SDK_ROOT`, then confirm with `flutter doctor -v`.

*Note: `sdkmanager` aborts silently on the licence prompt when its stdin is not a terminal. Accept licences first, or pass `--sdk_root` and rerun after accepting.*

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
