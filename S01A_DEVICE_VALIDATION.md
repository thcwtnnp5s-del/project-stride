# S-01A — Physical Android Device Validation

Branch `s01a-foreground-health-harness`. Foreground only: there is no background
worker, no scheduled sync, and no passive monitoring anywhere in this build.
Every read happens because you press a button.

## What the automated suite already proves, and what it cannot

The Dart, Flutter and Kotlin suites cover everything in front of `StepSource` —
reconciliation, absolute restatement, cursor authorization, commit ordering,
replay, redaction, the playable action. They substitute exactly one thing: the
Health Connect platform itself.

So a green suite says the decision layer is right. It says nothing about whether
a real Pixel's Health Connect returns what the adapter expects, whether the
permission sheet actually appears, or whether a changes token survives a
reboot. **That is what this checklist is for, and nothing else in the repository
covers it.**

## Build

```bash
flutter build apk --debug
```

Output: `build/app/outputs/flutter-apk/app-debug.apk`

Debug deliberately. A release build would select the production balance profile
under `ReleaseSafety.isReleaseBuild` and, more to the point, is not what you want
to be reading logs from during a first device bring-up.

## Install

With the phone in developer mode and USB debugging on:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

To start from nothing — which step 1 of the checklist requires:

```bash
adb uninstall com.projectstride.stride
```

Uninstalling removes the app-private directory, which is where the save, the
journal and the device identity live. There is no cloud copy: `allowBackup` is
false and `data_extraction_rules.xml` excludes the directory from both cloud
backup and device transfer.

## Health Connect setup

| Android version | What you need |
|---|---|
| 14 and above (API 34+) | Health Connect is part of the platform. Nothing to install. |
| 8.0 – 13 (API 26–33) | Install **Health Connect** from the Play Store. Until you do, the app must report `unavailable` and stay fully playable. |
| 8.0 – 8.1 (API 26–27) | The app installs and runs; Health Connect reports unavailable and no SDK method is called. This is a supported state, not a failure. |
| Below 8.0 | The app does not install. `minSdk` is 26, set by the Health Connect client library's own floor. |

Step data has to come from somewhere. Either:

- walk with a phone whose step sensor writes to Health Connect (Google Fit, Fitbit,
  Samsung Health, or the platform's own tracker), or
- use Health Connect's own **Manage data** screen, or the `Health Connect Toolbox`
  test app, to insert step records.

Manual entries are **excluded by default** (`includeManualEntries: false`). If you
insert steps by hand, they will correctly not be granted. Use a source that
writes non-manual records, or the sync will honestly report zero.

## Manual validation sequence

Record what you see at each step. A discrepancy at any of them is a real finding.

| # | Action | Expected |
|---|---|---|
| 1 | `adb uninstall` then `adb install`. Open the app. | Harness screen. Usable energy `0`. Cursor `absent`. Reload `not run`. |
| 2 | Tap **Check availability** before granting anything. | `available` on a phone with Health Connect; `unavailable — serviceMissing` without it. On API 26–27, `unavailable — serviceMissing`. Nothing crashes either way. |
| 3 | Tap **Request permission**. | The Health Connect sheet appears, asking for step read access only. Grant it. Permission shows `granted`. If the sheet does not appear, the manifest rationale declarations are the first thing to check. |
| 4 | Tap **Sync steps**. | Status `reconciled`, delivery kind `incremental`, origins ≥ 1, buckets ≥ 1, newly granted equal to your real step count for the window. Usable energy rises by that amount. Cursor becomes `present`. |
| 5 | **Write down the usable energy figure.** | — |
| 6 | Tap **Sync steps** again, immediately. | Newly granted `0`. Usable energy **unchanged**. Delivery kind `noChange` or `incremental` — either is correct; the grant being zero is the property. |
| 7 | Tap **Gather — 80 energy**. | Energy drops by exactly 80. `1× Meadow Herb` appears under Held. Last event reads `−80 energy → 1× Meadow Herb`. |
| 8 | `adb shell am force-stop com.projectstride.stride` | App dies. Not a backgrounded app — a killed process. |
| 9 | Reopen from the launcher. | — |
| 10 | Read the screen. | Usable energy is the figure from step 5 minus 80. Held is still `1× Meadow Herb`. Cursor `present`. Nothing was duplicated and nothing was lost. |
| 11 | Walk a few hundred more steps, or add non-manual step records. | — |
| 12 | Tap **Sync steps**. | Newly granted equals **only the new steps**, not the running total. |
| 13 | Revoke step permission in Health Connect settings, return, tap **Sync steps**. | Status `unavailable`, reason `permissionUnavailable`, newly granted `0`. Usable energy and Held unchanged. Source state reads `permissionUnavailable`. |

### Two further checks worth doing once

| Action | Expected |
|---|---|
| Tap **Reload saved state** at any point. | `loaded — N replayed`. Every figure on screen stays identical. A reload that changes a number means the screen and the disk disagreed. |
| Reboot the phone, reopen, sync. | Either an ordinary incremental sync, or delivery kind `recovery` if Health Connect invalidated the changes token. **Recovery must not re-grant what was already granted** — newly granted should be 0 or only the genuinely new steps. |

## What must never appear

On screen, in `adb logcat`, or in the save:

- a package name (`com.google.android.apps.fitness`, etc.)
- a device label
- the contents of a sync cursor or changes token
- the keying salt or its fingerprint

Origins are shown as a **count**. The cursor is shown as **present** or
**absent**. If you see anything resembling an identifier, that is a defect and it
outranks everything else on this page.

## Known limitations

- **Manual entries are not granted.** By design (`includeManualEntries: false`),
  and the reason a hand-inserted step record produces a sync of zero.
- **The current hour is never settled.** The read runs to the end of the bucket
  the clock is in so recent steps arrive promptly, but the completeness
  assertion stops at the previous boundary. Steps from the last few minutes are
  granted; the bucket they are in stays open.
- **One-hour buckets.** `TimeBucket.minimumWidthMillis`. A finer resolution
  would be a minute-by-minute record of when the player moved, kept for a week.
- **One action.** Meadow Patch, at Haven's Rest. Travel, crafting, combat and
  the activity scheduler are not S-01A.
- **Reset requires a restart.** `Reset local save` erases the lineage; the
  running session has no identity to write under afterwards and says so.
- **No background sync.** Close the app and nothing is read until you reopen it
  and press the button. That is S-01B, and it is blocked on a real persistence
  coordinator (`DECISIONS/0013`, `DECISIONS/0014`).

## Still requires a physical device

Nothing in CI or in any suite covers these:

- that the Health Connect permission sheet actually appears
- that `getSdkStatus` reports correctly across the API 26/28/34 bands
- that `dataOrigin.packageName` is what the adapter receives
- that a changes token survives a reboot, and what happens when it does not
- that `Metadata.recordingMethod` distinguishes manual entry as expected
- the real behaviour of `aggregate().dataOrigins` as a full source enumeration
