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
# ## Phases, and why every one of them is bounded
#
# Run 30767934429 was killed by the job's 45-minute timeout. That told us
# nothing: a job that dies at the global timeout names no phase, and the actual
# fault -- run 30771682608, `FATAL | Not enough space to create userdata
# partition. Available: 2124.99 MB, need 7372.80 MB` -- happened 0.2 seconds
# after the emulator launched and was then followed by ten minutes of polling a
# device that did not exist.
#
# So every phase below announces itself, records its duration, and has its own
# bound with its own failure message. A phase that hangs now fails as
# "installation exceeded 300s", not as a job that ran out of clock somewhere.
# The timing table is printed on success and on failure, and on the way out of
# an unexpected exit.
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

# Per-phase bounds. Each is generous against a healthy emulator and short
# against a broken one; the point is that the failure names the phase.
BOOT_TIMEOUT=300      # device visible to adb and sys.boot_completed=1
INSTALL_TIMEOUT=300   # adb install of a debug APK
CLEAR_TIMEOUT=120     # pm clear
LAUNCH_TIMEOUT=60     # am start returning
PHASE_TIMEOUT=90      # the app reaching a marker phase (seed, verify)
KILL_TIMEOUT=60       # force-stop, and the process actually going away
SHUTDOWN_TIMEOUT=60   # final device query

cd "$(dirname "$0")/.."

# --- phase accounting ------------------------------------------------------

PHASE_NAME=""
PHASE_START=0
PHASE_ROWS=""
RUN_START=$(date +%s)

stamp() { date -u +%H:%M:%S; }

end_phase() {
  [ -n "$PHASE_NAME" ] || return 0
  local elapsed=$(( $(date +%s) - PHASE_START ))
  printf '=== [%s] END   %-24s %4ds\n' "$(stamp)" "$PHASE_NAME" "$elapsed"
  PHASE_ROWS="${PHASE_ROWS}${PHASE_NAME}|${elapsed}|ok
"
  PHASE_NAME=""
}

phase() {
  end_phase
  PHASE_NAME="$1"
  PHASE_START=$(date +%s)
  printf '\n=== [%s] BEGIN %s\n' "$(stamp)" "$PHASE_NAME"
}

timings() {
  printf '\n--- phase timings (seconds) ---\n'
  printf '%s' "$PHASE_ROWS" |
    awk -F'|' 'NF{printf "  %-26s %5s  %s\n", $1, $2, $3}'
  if [ -n "$PHASE_NAME" ]; then
    printf '  %-26s %5s  DID NOT COMPLETE  <-- the phase at fault\n' \
      "$PHASE_NAME" "$(( $(date +%s) - PHASE_START ))"
  fi
  printf '  %-26s %5s\n' "TOTAL" "$(( $(date +%s) - RUN_START ))"
}

# Printed however the script leaves, including an unexpected `set -e` abort,
# so the phase table is never the thing that went missing.
trap timings EXIT

fail() {
  printf '\nFAILED (%s): %s\n' "${PHASE_NAME:-no phase}" "$1" >&2
  exit 1
}

# Runs a command under a wall-clock bound and reports the phase by name if it
# expires. `timeout` returns 124 on expiry, which is what distinguishes "this
# hung" from "this ran and failed".
bounded() {
  local limit="$1" what="$2"; shift 2
  local status=0
  timeout "$limit" "$@" || status=$?
  if [ "$status" -eq 124 ]; then
    fail "$what exceeded ${limit}s. It did not fail -- it never returned."
  fi
  return "$status"
}

# --- 1. emulator preparation and boot --------------------------------------

phase "emulator-and-boot"

adb start-server >/dev/null 2>&1 || true

# `adb wait-for-device` blocks forever on its own. Bounded, so a device that
# never appears is reported as a boot failure rather than as a job timeout.
if ! bounded "$BOOT_TIMEOUT" "waiting for a device" adb wait-for-device; then
  fail "no device became visible to adb within ${BOOT_TIMEOUT}s.

If this is CI, the emulator process most likely died at launch. Check the
'Launch Emulator' output for a FATAL line -- 'Not enough space to create
userdata partition' is the one that has bitten this job before, and it is
invisible from here because the symptom is simply that no device appears."
fi

if [ -z "$(adb devices | awk 'NR>1 && $2=="device"')" ]; then
  fail "no attached device. Start an emulator first:
  emulator -avd <name> -no-snapshot-save &
  adb wait-for-device"
fi

# Visible to adb is not the same as booted. An `am start` against a
# half-booted device fails in ways that look like an app defect.
booted=0
waited=0
while [ "$waited" -lt "$BOOT_TIMEOUT" ]; do
  if [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n')" = "1" ]; then
    booted=1
    break
  fi
  sleep 2
  waited=$((waited + 2))
done
[ "$booted" -eq 1 ] || fail "sys.boot_completed never became 1 within ${BOOT_TIMEOUT}s"

adb shell getprop ro.build.version.release | sed 's/^/Android /'
adb shell df /data | tail -1 | sed 's|^|guest /data: |' || true

# --- 2. build and install --------------------------------------------------

if [ "${1:-}" != "--skip-build" ]; then
  phase "build"
  flutter build apk --debug -t "$ENTRYPOINT"
fi
[ -f "$APK" ] || fail "missing $APK"

phase "installation"
bounded "$INSTALL_TIMEOUT" "installation" adb install -r -t "$APK" >/dev/null ||
  fail "adb install failed"

# A cleared installation, so launch 1 is genuinely a first launch. Without
# this, a leftover marker from an earlier run makes launch 1 behave as
# launch 2 and the whole thing passes without ever seeding anything.
phase "clear-app-data"
bounded "$CLEAR_TIMEOUT" "pm clear" adb shell pm clear "$PKG" >/dev/null ||
  fail "pm clear failed"
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
  while [ "$waited" -lt "$PHASE_TIMEOUT" ]; do
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
  fail "timed out after ${PHASE_TIMEOUT}s waiting for the app to reach phase '$want'"
}

# `pidof` exits 1 when the process is gone -- which here is the answer we are
# looking for, not an error. `pipefail` would hand that status to the
# assignment and `set -e` would abort the run at exactly the moment it
# succeeds, so the substitution absorbs it.
pid_of() {
  local out
  out="$(adb shell "pidof $PKG" 2>/dev/null || true)"
  printf '%s' "$(printf '%s' "$out" | tr -d '\r\n')"
}

# --- 3. launch 1: seed -----------------------------------------------------

phase "first-launch"
bounded "$LAUNCH_TIMEOUT" "first launch" adb shell am start -n "$ACTIVITY" >/dev/null ||
  fail "am start failed on the first launch"

phase "save-seeding"
SEEDED="$(wait_for_phase seeded)"
printf 'marker: %s\n' "$SEEDED"

PID_BEFORE="$(pid_of)"
[ -n "$PID_BEFORE" ] || fail "the app is not running after launch 1"
printf 'pid before kill: %s\n' "$PID_BEFORE"

# --- 4. the kill -----------------------------------------------------------

phase "force-stop"
bounded "$KILL_TIMEOUT" "force-stop" adb shell am force-stop "$PKG" ||
  fail "am force-stop failed"

# Polled rather than slept. A fixed sleep is either too short on a loaded
# runner -- which reports a surviving process and fails a healthy run -- or
# longer than it needs to be on every run that works.
gone=0
waited=0
while [ "$waited" -lt "$KILL_TIMEOUT" ]; do
  # An explicit `if`, not `[ ... ] && { ... }`: under `set -e` a failing
  # AND-list is itself a failing command, and this loop would abort the run at
  # the exact moment the process was still alive -- which is the normal case
  # for the first second or two.
  if [ -z "$(pid_of)" ]; then
    gone=1
    break
  fi
  sleep 1
  waited=$((waited + 1))
done
if [ "$gone" -ne 1 ]; then
  fail "the process survived force-stop for ${KILL_TIMEOUT}s (pid $(pid_of)); this run proves nothing"
fi
printf 'process gone after %ss. The evidence below is written by a different process.\n' "$waited"

# --- 5. launch 2: verify ---------------------------------------------------

phase "relaunch"
bounded "$LAUNCH_TIMEOUT" "relaunch" adb shell am start -n "$ACTIVITY" >/dev/null ||
  fail "am start failed on the relaunch"

phase "verdict-retrieval"
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

# --- 6. shutdown -----------------------------------------------------------
#
# The emulator itself is torn down by whatever started it. This phase exists so
# the timing table has a closing entry and so a device that has become
# unresponsive after the verdict is reported here rather than in the teardown
# of the step that follows.

phase "shutdown"
bounded "$SHUTDOWN_TIMEOUT" "final device query" adb shell getprop sys.boot_completed >/dev/null ||
  fail "the device stopped responding after the verdict was read"
end_phase
