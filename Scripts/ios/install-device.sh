#!/usr/bin/env bash
# install-device.sh — put the already-built RELEASE Runner.app on the connected
# iPhone and launch it once. Runs on macOS only. Normally invoked by
# build-release-device.sh; run it alone to reinstall the last build.
#
# Usage:
#   bash Scripts/ios/install-device.sh              # flutter install --release
#   bash Scripts/ios/install-device.sh --devicectl  # xcrun devicectl install + launch
#   bash Scripts/ios/install-device.sh --run        # flutter run --release (fallback)
#
# Environment (optional): STRIDE_IOS_DEVICE=<udid or name>
#
# Routes, most to least preferred:
#   default    `flutter install --release`  — installs build/ios/iphoneos/Runner.app
#              (it does not rebuild; it refuses if the bundle is missing). On
#              iOS 17+ with Xcode 15+ Flutter drives Apple's CoreDevice
#              (`devicectl`) underneath.
#   --devicectl calls `xcrun devicectl` directly: install the .app, then launch
#              the bundle id. Same mechanism, no Flutter in the loop; useful when
#              `flutter install` cannot pick the device.
#   --run      `flutter run --release`: builds if needed, installs, launches, and
#              waits. Press q to quit. The app STAYS INSTALLED and launches from
#              the Home Screen afterwards. The simplest thing that always works.
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

MODE="flutter-install"
for arg in "$@"; do
  case "$arg" in
    --devicectl) MODE="devicectl" ;;
    --run) MODE="flutter-run" ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
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
  destroys the save (it lives in the app container).
EOF
}

case "$MODE" in
  flutter-install)
    [ -d "$APP_BUNDLE" ] || fail no_bundle "build/ios/iphoneos/Runner.app is missing. Run: bash Scripts/ios/build-release-device.sh"
    say "flutter install --release ${DEVICE_ARGS[*]:-}"
    if flutter install --release "${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"}"; then
      after_install
    else
      cat >&2 <<'EOF'

STRIDE_IOS[install_failed] flutter install did not succeed.
  * more than one device listed?  export STRIDE_IOS_DEVICE=<udid or name> and retry
  * phone locked, or "Trust This Computer" unanswered?  fix and retry
  * try the direct route:   bash Scripts/ios/install-device.sh --devicectl
  * or the always-works one: bash Scripts/ios/install-device.sh --run
EOF
      exit 1
    fi
    ;;

  devicectl)
    [ -d "$APP_BUNDLE" ] || fail no_bundle "build/ios/iphoneos/Runner.app is missing. Run: bash Scripts/ios/build-release-device.sh"
    xcrun devicectl --version >/dev/null 2>&1 || fail devicectl_missing "xcrun devicectl needs Xcode 15+."
    UDID="${STRIDE_IOS_DEVICE:-}"
    if [ -z "$UDID" ]; then
      say "xcrun devicectl list devices"
      xcrun devicectl list devices 2>/dev/null | sed 's/^/    /' || true
      # Take the single connected iPhone if there is exactly one; otherwise ask.
      LIST="$(xcrun devicectl list devices --hide-headers 2>/dev/null | grep -i 'iphone' | grep -iv 'unavailable' || true)"
      COUNT="$(printf '%s\n' "$LIST" | sed '/^$/d' | wc -l | tr -d ' ')"
      [ "$COUNT" -eq 1 ] || fail choose_device "found $COUNT candidate iPhones. export STRIDE_IOS_DEVICE=<identifier from the list above> and retry."
      # The identifier column is a UUID; pick the first UUID-shaped token.
      UDID="$(printf '%s\n' "$LIST" | grep -oE '[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}' | head -n1)"
      [ -n "$UDID" ] || fail choose_device "could not read the device identifier; export STRIDE_IOS_DEVICE and retry."
    fi
    say "xcrun devicectl device install app --device <device> $APP_BUNDLE"
    xcrun devicectl device install app --device "$UDID" "$APP_BUNDLE" || \
      fail install_failed "devicectl install failed. Is the phone unlocked and Developer Mode on? Fallback: bash Scripts/ios/install-device.sh --run"
    say "xcrun devicectl device process launch --device <device> $BUNDLE_ID"
    xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" || \
      echo "    (launch refused — usually the 'Untrusted Developer' step below; the app is installed.)"
    after_install
    ;;

  flutter-run)
    say "flutter run --release ${DEVICE_ARGS[*]:-}   (press q when the app is up; it stays installed)"
    flutter run --release "${DEVICE_ARGS[@]+"${DEVICE_ARGS[@]}"}" || true
    after_install
    ;;
esac
