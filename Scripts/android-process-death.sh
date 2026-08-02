#!/usr/bin/env bash
#
# Android process-death evidence.
#
# Seeds a save, has the operating system kill the app, relaunches it, and
# asserts the exact state came back. The claim it supports is narrow and
# precise:
#
#   The app's durable state survives `am force-stop`, which is the same signal
#   the platform sends when it reclaims a backgrounded app.
#
# What it does NOT prove: survival of sudden power loss. `force-stop` kills the
# process; it does not drop the page cache or lie to fsync. No emulator and no
# CI runner can demonstrate that, and this script does not pretend to.
#
# ## Why an app rather than `flutter test integration_test/`
#
# The integration_test driver runs inside the app process. Killing that process
# kills the driver, and the run reports a lost connection instead of a result.
# So the assertions live in `integration_test/process_death_app.dart`, which
# writes its verdict to disk, and this script reads the verdict written by a
# process that started *after* the previous one was killed.
#
# Usage:
#   Scripts/android-process-death.sh [--skip-build]
#
# Requires: an attached device or a booted emulator, adb on PATH, flutter.

set -euo pipefail

PKG=com.projectstride.stride
ACTIVITY="${PKG}/.MainActivity"
ENTRYPOINT=integration_test/process_death_app.dart
APK=build/app/outputs/flutter-apk/app-debug.apk
MARKER=harness_marker.json
TIMEOUT_SECONDS=90

cd "$(dirname "$0")/.."

step() { printf '\n=== %s\n' "$1"; }
fail() { printf '\nFAILED: %s\n' "$1" >&2; exit 1; }

# --- device ----------------------------------------------------------------

step "Device"
adb start-server >/dev/null 2>&1 || true
if [ -z "$(adb devices | awk 'NR>1 && $2=="device"')" ]; then
  fail "no attached device. Start an emulator first:
  emulator -avd <name> -no-snapshot-save &
  adb wait-for-device"
fi
adb wait-for-device
adb shell getprop ro.build.version.release | sed 's/^/Android /'

# --- build and install -----------------------------------------------------

if [ "${1:-}" != "--skip-build" ]; then
  step "Build (debug; run-as needs a debuggable build to read app-private files)"
  flutter build apk --debug -t "$ENTRYPOINT"
fi
[ -f "$APK" ] || fail "missing $APK"

step "Install"
adb install -r -t "$APK" >/dev/null

# A cleared installation, so launch 1 is genuinely a first launch. Without
# this, a leftover marker from an earlier run makes launch 1 behave as
# launch 2 and the whole thing passes without ever seeding anything.
step "Clear app data"
adb shell pm clear "$PKG" >/dev/null
adb logcat -c || true

# --- helpers ---------------------------------------------------------------

# App-private files are readable only through run-as, and only on a debuggable
# build. `2>/dev/null || true` because "not there yet" is the normal state
# while polling.
read_marker() {
  adb shell "run-as $PKG cat files/$MARKER" 2>/dev/null || true
}

wait_for_phase() {
  local want="$1" waited=0 body
  while [ "$waited" -lt "$TIMEOUT_SECONDS" ]; do
    body="$(read_marker)"
    case "$body" in
      *"\"phase\":\"$want\""*) printf '%s' "$body"; return 0 ;;
    esac
    sleep 2
    waited=$((waited + 2))
  done
  printf '\n--- last marker ---\n%s\n' "$(read_marker)" >&2
  printf '\n--- logcat ---\n' >&2
  adb logcat -d | grep -i -E 'STRIDE_HARNESS|flutter' | tail -40 >&2 || true
  fail "timed out after ${TIMEOUT_SECONDS}s waiting for phase '$want'"
}

pid_of() { adb shell "pidof $PKG" 2>/dev/null | tr -d '\r\n'; }

# --- launch 1: seed --------------------------------------------------------

step "Launch 1 — seed a save and commit three transactions"
adb shell am start -n "$ACTIVITY" >/dev/null
SEEDED="$(wait_for_phase seeded)"
printf 'marker: %s\n' "$SEEDED"

PID_BEFORE="$(pid_of)"
[ -n "$PID_BEFORE" ] || fail "the app is not running after launch 1"
printf 'pid before kill: %s\n' "$PID_BEFORE"

# --- the kill --------------------------------------------------------------

step "Kill — am force-stop"
adb shell am force-stop "$PKG"
sleep 2

PID_AFTER="$(pid_of)"
if [ -n "$PID_AFTER" ]; then
  fail "the process survived force-stop (pid $PID_AFTER); this run proves nothing"
fi
printf 'process gone. The evidence below is written by a different process.\n'

# --- launch 2: verify ------------------------------------------------------

step "Launch 2 — resume and verify"
adb shell am start -n "$ACTIVITY" >/dev/null
VERDICT="$(wait_for_phase verified)"
printf 'marker: %s\n' "$VERDICT"

case "$VERDICT" in
  *'"result":"PASS"'*)
    printf '\nPASS — the save survived a real process kill.\n'
    printf 'pid before: %s / after relaunch: %s\n' "$PID_BEFORE" "$(pid_of)"
    ;;
  *)
    fail "the relaunched process did not see the expected state: $VERDICT"
    ;;
esac
