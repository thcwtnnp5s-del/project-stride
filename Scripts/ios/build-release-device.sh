#!/usr/bin/env bash
# build-release-device.sh — a signed RELEASE build of Stride for the owner's
# iPhone, from the Mac, with a free Personal Team. Runs on macOS only.
#
# Why this exists: a Flutter DEBUG build is JIT and iOS 14+ refuses to launch it
# from the Home Screen ("debug-mode Flutter applications can only be launched
# from Flutter tooling"). Xcode's Run button builds the scheme's Debug
# configuration, so "flutter build ios --profile, then press Run in Xcode"
# installs a DEBUG build regardless. This script builds Release and installs
# that, so the phone can be unplugged and the app launched from the Home Screen.
#
# Full explanation, constraints (7-day profile, Developer Mode, trust prompt) and
# the owner checklist: TECHNICAL/IOS_DEVICE_INSTALL.md.
#
# Usage (from anywhere; the script finds the repository root itself):
#   bash Scripts/ios/build-release-device.sh [--clean] [--no-install] [--devicectl]
#
# Environment (all optional, none ever written to the repository):
#   STRIDE_IOS_TEAM=<10-char team id>   pass the signing team for this run only
#                                       (forwarded as FLUTTER_XCODE_DEVELOPMENT_TEAM,
#                                       which Flutter hands to xcodebuild verbatim).
#                                       Not needed when ios/Flutter/Local.xcconfig
#                                       exists — see Local.xcconfig.example.
#   STRIDE_IOS_DEVICE=<udid or name>    which phone, if more than one is attached.
#
# Exit codes: 0 built (and installed), 1 a named precondition or build failure.
#
# Idempotent: re-running rebuilds and reinstalls over the existing app; the app
# container (the save) is preserved by an in-place reinstall of the same bundle
# id signed by the same team.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_BUNDLE="$REPO_ROOT/build/ios/iphoneos/Runner.app"
LOCAL_XCCONFIG="$REPO_ROOT/ios/Flutter/Local.xcconfig"

CLEAN=0
INSTALL=1
INSTALL_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=1 ;;
    --no-install) INSTALL=0 ;;
    --devicectl) INSTALL_ARGS+=("--devicectl") ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "STRIDE_IOS[usage] unknown option: $arg" >&2; exit 1 ;;
  esac
done

say()  { printf '\n==> %s\n' "$*"; }
fail() { printf '\nSTRIDE_IOS[%s] %s\n' "$1" "$2" >&2; exit 1; }

# ---------------------------------------------------------------------------
# 1. Preconditions — macOS, Flutter, Xcode
# ---------------------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || \
  fail not_macos "iOS can only be built on macOS. This is the Mac's script; run it there."

command -v flutter >/dev/null 2>&1 || \
  fail flutter_missing "flutter is not on PATH. Add the Flutter SDK's bin/ to PATH and retry."

command -v xcodebuild >/dev/null 2>&1 || \
  fail xcode_missing "xcodebuild is not on PATH. Install Xcode from the App Store, launch it once, then: sudo xcode-select -s /Applications/Xcode.app"

command -v xcrun >/dev/null 2>&1 || fail xcrun_missing "xcrun is not available; Xcode command line tools are missing."

say "Toolchain (recorded for the run log; NOT CI evidence — CI pins Flutter, MISTAKES M-02)"
flutter --version 2>/dev/null | head -n 4
xcodebuild -version 2>/dev/null | head -n 2

PINNED="$(grep -E '^\s*FLUTTER_VERSION:' "$REPO_ROOT/.github/workflows/ci.yml" 2>/dev/null | head -n1 | sed -E 's/.*:\s*"?([0-9.]+)"?.*/\1/' || true)"
LOCAL_FLUTTER="$(flutter --version 2>/dev/null | head -n1 | awk '{print $2}')"
if [ -n "$PINNED" ] && [ "$PINNED" != "$LOCAL_FLUTTER" ]; then
  echo "    note: this Mac has Flutter $LOCAL_FLUTTER; CI pins $PINNED. Tolerated for a device build,"
  echo "          but a green device run on $LOCAL_FLUTTER is not the CI evidence (RULES G-2, MISTAKES M-02)."
fi

# ---------------------------------------------------------------------------
# 2. Signing team — where it comes from, in order of preference
# ---------------------------------------------------------------------------
say "Signing"
if grep -q 'DEVELOPMENT_TEAM = ' "$REPO_ROOT/ios/Runner.xcodeproj/project.pbxproj"; then
  echo "    WARNING: project.pbxproj contains DEVELOPMENT_TEAM. Xcode wrote it when a team was picked in"
  echo "             Signing & Capabilities. It works, but it must NOT be committed (public repo)."
  echo "             Preferred: git checkout -- ios/Runner.xcodeproj/project.pbxproj, and use Local.xcconfig."
fi
if [ -n "${STRIDE_IOS_TEAM:-}" ]; then
  export FLUTTER_XCODE_DEVELOPMENT_TEAM="$STRIDE_IOS_TEAM"
  export FLUTTER_XCODE_CODE_SIGN_STYLE="Automatic"
  echo "    team: from STRIDE_IOS_TEAM (this run only, forwarded to xcodebuild)"
elif [ -f "$LOCAL_XCCONFIG" ]; then
  echo "    team: from ios/Flutter/Local.xcconfig (untracked; included by Debug/Release.xcconfig)"
else
  echo "    team: none configured. Flutter will look for a single 'Apple Development' identity in the"
  echo "          keychain and use its team (it prompts if there are several). If that fails:"
  echo "            cp ios/Flutter/Local.xcconfig.example ios/Flutter/Local.xcconfig"
  echo "          and put your Team ID in it (Xcode ▸ Settings ▸ Accounts ▸ your Personal Team)."
fi

# ---------------------------------------------------------------------------
# 3. Build
# ---------------------------------------------------------------------------
cd "$REPO_ROOT"

if [ "$CLEAN" -eq 1 ]; then
  say "flutter clean"
  flutter clean
fi

say "flutter pub get"
flutter pub get
(cd packages/stride_core && dart pub get)

say "flutter build ios --release  (codesigned; automatic provisioning with your Personal Team)"
# No --no-codesign here, on purpose: CI's --no-codesign build is compile evidence
# and is not installable. Flutter forwards automatic-provisioning flags to
# xcodebuild, and needs your Apple ID signed in to Xcode (Settings ▸ Accounts)
# for the free Personal Team profile to be created or renewed.
if ! flutter build ios --release; then
  cat >&2 <<'EOF'

STRIDE_IOS[build_failed] flutter build ios --release failed.

  If the failure is about signing / provisioning / "no team", do this ONCE:
    1. open ios/Runner.xcworkspace
    2. Runner target ▸ Signing & Capabilities ▸ Team ▸ your Personal Team
       (Automatically manage signing ticked; HealthKit listed under Capabilities)
    3. with the iPhone plugged in and unlocked, select it as the destination and
       press Run once (this registers the device and creates the 7-day profile;
       accept the Developer Mode prompt on the phone if it appears)
    4. quit Xcode, then:  git checkout -- ios/Runner.xcodeproj/project.pbxproj
       and put the Team ID in ios/Flutter/Local.xcconfig instead (see .example)
    5. re-run this script
  If the bundle id com.projectstride.stride is reported as unavailable to your
  team, STOP and report it — the id is fixed in project.pbxproj and is not to be
  changed per machine.
EOF
  exit 1
fi

[ -d "$APP_BUNDLE" ] || fail no_bundle "build/ios/iphoneos/Runner.app was not produced."

# ---------------------------------------------------------------------------
# 4. Prove it is a Release (AOT) build with the expected entitlements
# ---------------------------------------------------------------------------
say "Verifying the bundle"
if [ -f "$APP_BUNDLE/Frameworks/App.framework/flutter_assets/kernel_blob.bin" ]; then
  fail not_aot "Runner.app contains kernel_blob.bin — that is a JIT (debug) build and will not launch from the Home Screen."
fi
echo "    AOT: yes (no kernel_blob.bin)"

if command -v codesign >/dev/null 2>&1; then
  ENT="$(codesign -d --entitlements :- "$APP_BUNDLE" 2>/dev/null || codesign -d --entitlements - "$APP_BUNDLE" 2>/dev/null || true)"
  if [ -n "$ENT" ]; then
    printf '%s' "$ENT" | grep -q 'com.apple.developer.healthkit' \
      && echo "    entitlement com.apple.developer.healthkit: present" \
      || fail no_healthkit_entitlement "the signed app has NO HealthKit entitlement; the profile was created without the capability. Re-open Xcode ▸ Signing & Capabilities and confirm HealthKit is listed, then rebuild."
    if printf '%s' "$ENT" | grep -q 'healthkit.background-delivery'; then
      fail background_delivery "the signed app grants healthkit.background-delivery. S-01A is FOREGROUND ONLY (DECISIONS/0014). Do not install this."
    fi
    echo "    entitlement healthkit.background-delivery: absent (correct)"
  else
    echo "    (could not read entitlements from the bundle; skipping the entitlement check)"
  fi
  # Team identifier is printed to THIS terminal only. It goes in no file.
  codesign -dv "$APP_BUNDLE" 2>&1 | grep -E 'TeamIdentifier|Identifier=' | sed 's/^/    /' || true
fi

PROFILE="$APP_BUNDLE/embedded.mobileprovision"
if [ -f "$PROFILE" ] && command -v security >/dev/null 2>&1; then
  EXP="$(security cms -D -i "$PROFILE" 2>/dev/null | plutil -extract ExpirationDate raw -o - - 2>/dev/null || true)"
  [ -n "$EXP" ] && echo "    provisioning profile expires: $EXP  (free Personal Team = 7 days; re-run this script to renew)"
fi

echo
echo "Built: $APP_BUNDLE"

# ---------------------------------------------------------------------------
# 5. Install
# ---------------------------------------------------------------------------
if [ "$INSTALL" -eq 1 ]; then
  exec bash "$SCRIPT_DIR/install-device.sh" "${INSTALL_ARGS[@]+"${INSTALL_ARGS[@]}"}"
else
  echo "Skipping install (--no-install). To install:  bash Scripts/ios/install-device.sh"
fi
