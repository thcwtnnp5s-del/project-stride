#!/usr/bin/env bash
# install-device.sh — put the already-built RELEASE Runner.app on the connected
# iPhone and launch it once. Runs on macOS only. Normally invoked by
# build-release-device.sh; run it alone to reinstall the last build.
#
# Usage:
#   bash Scripts/ios/install-device.sh                  # devicectl install in place (+ launch)
#   bash Scripts/ios/install-device.sh --run            # flutter run --release (also in place)
#   bash Scripts/ios/install-device.sh --wipe-reinstall # flutter install --release: DELETES THE SAVE
#
# Environment (optional): STRIDE_IOS_DEVICE=<udid or name>
#
# SAVE PRESERVATION (TECHNICAL/IOS_DEVICE_INSTALL.md §1.4). The save lives in
# the app's data container. iOS keeps that container when an app is REPLACED in
# place (same bundle id, same team) and deletes it when the app is UNINSTALLED.
# `flutter install` always uninstalls an existing app first ("Uninstalling old
# version..." — flutter_tools/commands/install.dart, uninstall = true, no flag
# to turn it off), so it is NOT a routine-update command here. The routes below
# all install in place; the destructive one is opt-in and says so.
#
# Routes:
#   default    `xcrun devicectl device install app` — Apple's CoreDevice
#              installer (Xcode 15+, iOS 17+; this app targets 17.0). Replaces
#              the app in place, then `devicectl device process launch`. If the
#              device cannot be picked or the install fails, falls back to --run.
#   --run      `flutter run --release`: builds if needed, installs IN PLACE
#              (Flutter drives the same devicectl install, no uninstall unless
#              --uninstall-first is passed, which we never do), launches, waits.
#              Press q to quit; the app STAYS INSTALLED.
#   --wipe-reinstall
#              `flutter install --release`: uninstall + install. Only for a
#              deliberate fresh container (a reset). Asks for confirmation.
#
# What the PHONE will ask (in this order, first time only):
#   * "Trust This Computer?"                        → Trust, enter passcode
#   * Settings ▸ Privacy & Security ▸ Developer Mode → on, restart (iOS 16+;
#     the toggle appears only after the phone has been seen by Xcode once)
#   * First launch: "Untrusted Developer" → Settings ▸ General ▸ VPN & Device
#     Management ▸ your Apple ID ▸ Trust, then open the app again
#   * First launch of the app: the Health access sheet → Turn On All / Allow

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_BUNDLE="$REPO_ROOT/build/ios/iphoneos/Runner.app"
BUNDLE_ID="com.projectstride.stride"

MODE="devicectl"
for arg in "$@"; do
  case "$arg" in
    --devicectl) MODE="devicectl" ;;   # kept for build-release-device.sh --devicectl; now the default
    --run) MODE="flutter-run" ;;
    --wipe-reinstall) MODE="flutter-install" ;;
    -h|--help) sed -n '2,42p' "$0"; exit 0 ;;
    *) echo "STRIDE_IOS[usage] unknown option: $arg" >&2; exit 1 ;;
  esac
done

say()  { printf '\n==> %s\n' "$*"; }
fail() { printf '\nSTRIDE_IOS[%s] %s\n' "$1" "$2" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail not_macos "run this on the Mac."
command -v flutter >/dev/null 2>&1 || fail flutter_missing "flutter is not on PATH."
command -v xcrun >/dev/null 2>&1 || fail xcrun_missing "Xcode command line tools are missing."

cd "$REPO_ROOT"

DEVICE_ARGS=()
[ -n "${STRIDE_IOS_DEVICE:-}" ] && DEVICE_ARGS=(-d "$STRIDE_IOS_DEVICE")

cat <<'EOF'

  ON THE PHONE NOW: plug it in with a data cable, UNLOCK it, and keep it unlocked.
  If it asks "Trust This Computer?" tap Trust. If Settings ▸ Privacy & Security
  shows "Developer Mode", make sure it is ON (it restarts the phone once).

EOF

say "Attached devices (flutter devices)"
flutter devices 2>/dev/null | sed 's/^/    /' || true

after_install() {
  cat <<'EOF'

  INSTALLED. On the phone:
    1. If the icon is there but tapping it says "Untrusted Developer":
       Settings ▸ General ▸ VPN & Device Management ▸ (your Apple ID) ▸ Trust ▸ Trust.
    2. UNPLUG the cable. Tap the Stride icon on the Home Screen. It must open on
       its own — this is a Release (AOT) build; the "launched from Flutter tooling"
       refusal only applies to debug builds.
    3. First launch of a fresh install shows the Health access sheet — allow Steps.
       A reinstall over an existing install usually does not ask again.

  This install expires in 7 DAYS (free Personal Team). When the app stops
  opening, plug in and run:  bash Scripts/ios/build-release-device.sh
  Reinstalling over the top keeps the save; DELETING the app from the phone
  destroys the save (it lives in the app container). So does --wipe-reinstall.
  Check: TOTAL WALKED should still show the figure from before the update.
EOF
}

# flutter run --release: builds if needed, installs IN PLACE, launches, waits.
flutter_run_release() {
  say "flutter run --release ${DEVICE_ARGS[*]:-}   (press q when the app is up; it stays installed)"
  flutter run --release "${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"}" || true
  after_install
}

case "$MODE" in
  devicectl)
    [ -d "$APP_BUNDLE" ] || fail no_bundle "build/ios/iphoneos/Runner.app is missing. Run: bash Scripts/ios/build-release-device.sh"
    if ! xcrun devicectl --version >/dev/null 2>&1; then
      echo "    xcrun devicectl not available (needs Xcode 15+); using flutter run --release instead (also in place)."
      flutter_run_release
      exit 0
    fi
    UUID_RE='[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}'
    UDID=""
    if printf '%s' "${STRIDE_IOS_DEVICE:-}" | grep -qE "^${UUID_RE}\$"; then
      UDID="$STRIDE_IOS_DEVICE"
    else
      say "xcrun devicectl list devices"
      xcrun devicectl list devices 2>/dev/null | sed 's/^/    /' || true
      LIST="$(xcrun devicectl list devices --hide-headers 2>/dev/null | grep -i 'iphone' | grep -iv 'unavailable' || true)"
      if [ -n "${STRIDE_IOS_DEVICE:-}" ]; then
        # A device NAME was given: keep only the rows that carry it.
        LIST="$(printf '%s\n' "$LIST" | grep -iF -- "$STRIDE_IOS_DEVICE" || true)"
      fi
      COUNT="$(printf '%s\n' "$LIST" | sed '/^$/d' | wc -l | tr -d ' ')"
      if [ "$COUNT" -eq 1 ]; then
        # The identifier column is a UUID; pick the first UUID-shaped token.
        UDID="$(printf '%s\n' "$LIST" | grep -oE "$UUID_RE" | head -n1 || true)"
      fi
    fi
    if [ -z "$UDID" ]; then
      echo "    could not pick exactly one iPhone for devicectl (export STRIDE_IOS_DEVICE=<identifier> to choose)."
      echo "    Falling back to flutter run --release, which also installs in place."
      flutter_run_release
      exit 0
    fi
    say "xcrun devicectl device install app --device <device> $APP_BUNDLE   (in place; the save is kept)"
    if ! xcrun devicectl device install app --device "$UDID" "$APP_BUNDLE"; then
      echo "    devicectl install failed. Is the phone unlocked and Developer Mode on?"
      echo "    If the log says the application-identifier does not match the installed app, the build is"
      echo "    signed by a DIFFERENT TEAM than the app on the phone; iOS will not update across teams."
      echo "    Use the same Apple ID, or accept the save loss and run --wipe-reinstall."
      echo "    Falling back to flutter run --release (in place)."
      flutter_run_release
      exit 0
    fi
    say "xcrun devicectl device process launch --device <device> $BUNDLE_ID"
    xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" || \
      echo "    (launch refused — usually the 'Untrusted Developer' step below; the app is installed.)"
    after_install
    ;;

  flutter-run)
    flutter_run_release
    ;;

  flutter-install)
    [ -d "$APP_BUNDLE" ] || fail no_bundle "build/ios/iphoneos/Runner.app is missing. Run: bash Scripts/ios/build-release-device.sh"
    cat <<'EOF'

  WARNING: --wipe-reinstall runs `flutter install --release`, which UNINSTALLS the
  existing app first ("Uninstalling old version...") and therefore DELETES the
  app container: the save, both slots and the journal. Type WIPE to continue.
EOF
    printf '  > '
    read -r ANSWER </dev/tty || ANSWER=""
    [ "$ANSWER" = "WIPE" ] || fail cancelled "not confirmed; nothing installed. Routine update: bash Scripts/ios/install-device.sh"
    say "flutter install --release ${DEVICE_ARGS[*]:-}   (uninstall + install)"
    if flutter install --release "${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"}"; then
      after_install
    else
      fail install_failed "flutter install did not succeed. Try: bash Scripts/ios/install-device.sh --run"
    fi
    ;;
esac
