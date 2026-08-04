#!/usr/bin/env bash
# check-ios-target.sh
#
# iOS target shape, and the foreground read-only HealthKit configuration.
#
# Android policy lives in `check-android-target.sh`. This file grew one and
# stopped being about iOS.
#
# ## What it enforces
#
# DECISIONS/0009 fixed portrait-only, phone-only, iOS 17. The shipped Xcode
# project disagreed with all three for the whole of F-01 through F-06, and 0009
# itself claimed a "build-time check" that did not exist. A decision record
# enforced by nothing is a preference.
#
# DECISIONS/0014 fixes S-01A as FOREGROUND ONLY, so the background-delivery
# entitlement is checked for ABSENCE. That key alone would let iOS wake the app
# into a second execution context the single-writer persistence model does not
# cover, with no Dart changing.
#
# ## Structured files are PARSED
#
# `Info.plist` and `Runner.entitlements` go through `Scripts/lib/xmlq.js`.
# Three guard defects here were the same mistake — grep plus `sed`
# comment-stripping — and two of them matched the file's OWN PROSE about the
# forbidden thing and failed a correct tree.
#
# Presence is not the property either. `NSHealthShareUsageDescription` present
# as an empty string still terminates the app at the authorization call, and
# `com.apple.developer.healthkit` present as `<string>true</string>` is a
# string, not a granted entitlement. Both are type-checked.
#
# `project.pbxproj` is not XML and stays a carefully anchored text check.
#
# Usage:
#   check-ios-target.sh [--project-root <path>]
#   check-ios-target.sh --self-test

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/selftest.sh
. "$SCRIPT_DIR/lib/selftest.sh"
# shellcheck source=lib/xmlq.sh
. "$SCRIPT_DIR/lib/xmlq.sh"

PROJECT_ROOT="$REPO_ROOT"
SELF_TEST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --self-test) SELF_TEST=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

failures=0
fail() { echo "ios-target: FAIL -- $1" >&2; failures=$((failures + 1)); }

cd "$PROJECT_ROOT" || { echo "ios-target: no such project root: $PROJECT_ROOT" >&2; exit 2; }

REQUIRED_IOS="17.0"
PLIST="ios/Runner/Info.plist"
ENTITLEMENTS="ios/Runner/Runner.entitlements"

# Everything this guard reads. Also the copy list for --self-test.
GUARD_PATHS="
ios/Runner/Info.plist
ios/Runner/Runner.entitlements
ios/Runner.xcodeproj/project.pbxproj
packages/stride_health/example/ios/Runner.xcodeproj/project.pbxproj
packages/stride_secure_store/example/ios/Runner.xcodeproj/project.pbxproj
packages/stride_health/ios/stride_health/Package.swift
packages/stride_secure_store/ios/stride_secure_store/Package.swift
packages/stride_health/ios/stride_health.podspec
packages/stride_secure_store/ios/stride_secure_store.podspec
"

# ---------------------------------------------------------------------------
# 1. Deployment target — EVERY Xcode project, not just the app's
# ---------------------------------------------------------------------------
# This checked only `ios/Runner.xcodeproj` and passed while CI failed: the two
# plugin EXAMPLE apps were left at 13.0, and a plugin declaring iOS 17 cannot be
# consumed by a host declaring 13.0. Those example apps are what the macOS job
# builds in order to compile the Swift.
for proj in $(find . -name project.pbxproj -not -path './build/*' -not -path '*/ephemeral/*' 2>/dev/null | sort); do
  wrong="$(grep -n 'IPHONEOS_DEPLOYMENT_TARGET' "$proj" | grep -v "= ${REQUIRED_IOS};" || true)"
  [ -z "$wrong" ] || fail "$proj has IPHONEOS_DEPLOYMENT_TARGET != $REQUIRED_IOS (DECISIONS/0009):
$wrong"
done

for f in packages/stride_health/ios/stride_health/Package.swift \
         packages/stride_secure_store/ios/stride_secure_store/Package.swift; do
  [ -f "$f" ] || continue
  grep -q "\.iOS(\"${REQUIRED_IOS}\")" "$f" || fail "$f does not declare .iOS(\"$REQUIRED_IOS\")"
done

for f in packages/stride_health/ios/stride_health.podspec \
         packages/stride_secure_store/ios/stride_secure_store.podspec; do
  [ -f "$f" ] || continue
  grep -q "s.platform = :ios, '${REQUIRED_IOS}'" "$f" \
    || fail "$f does not declare s.platform = :ios, '$REQUIRED_IOS'"
  # A podspec whose license is a :file reference breaks when that file is
  # removed -- which happened when the placeholder LICENSE stubs were deleted
  # for the public-repository remediation. SPM hides it until a CocoaPods
  # fallback, i.e. a first device build on an unfamiliar Mac.
  ref="$(grep -oE "s\.license[^=]*=[^\n]*:file *=> *'([^']+)'" "$f" | grep -oE "'[^']+'" | tr -d "'" || true)"
  if [ -n "$ref" ]; then
    target="$(cd "$(dirname "$f")" && cd "$(dirname "$ref")" 2>/dev/null && pwd)/$(basename "$ref")"
    [ -f "$target" ] || fail "$f references a license file that does not exist: $ref"
  fi
done

# ---------------------------------------------------------------------------
# 2. Device family — iPhone only
# ---------------------------------------------------------------------------
APP_PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"
if [ -f "$APP_PBXPROJ" ]; then
  wrong="$(grep -n 'TARGETED_DEVICE_FAMILY' "$APP_PBXPROJ" | grep -v '= "1";' || true)"
  [ -z "$wrong" ] || fail "$APP_PBXPROJ is not iPhone-only (DECISIONS/0009):
$wrong"

  grep -q 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;' "$APP_PBXPROJ" \
    || fail "$APP_PBXPROJ does not set CODE_SIGN_ENTITLEMENTS; the entitlements file would never be applied"
fi

# ---------------------------------------------------------------------------
# 3. Info.plist — parsed, and type-checked
# ---------------------------------------------------------------------------
if [ -f "$PLIST" ]; then
  # Orientation. Portrait only, and no ~ipad block on a phone-only target.
  #
  # Read as ARRAY VALUES. An earlier version swept for elements named `string`
  # and counted matches in the element NAMES, so it reported zero landscape
  # entries whatever the file contained — a check that could not fail. This
  # guard's own self-test caught it.
  orientations="$(node "$XMLQ_JS" "$PLIST" array-strings UISupportedInterfaceOrientations 2>/dev/null)"
  rc=$?
  if [ "$rc" -eq 2 ]; then
    fail "$PLIST could not be read; failing closed"
  elif [ "$rc" -ne 0 ]; then
    fail "$PLIST has no usable UISupportedInterfaceOrientations array"
  else
    banned="$(printf '%s\n' "$orientations" | grep -E 'Landscape|UpsideDown' || true)"
    [ -z "$banned" ] || fail "$PLIST declares non-portrait orientation(s); DECISIONS/0009 is portrait-only:
$banned"
    printf '%s\n' "$orientations" | grep -q 'UIInterfaceOrientationPortrait' \
      || fail "$PLIST does not declare UIInterfaceOrientationPortrait"
  fi

  xmlq_require_no_match fail \
    "$PLIST declares UISupportedInterfaceOrientations~ipad on a phone-only target" \
    "$PLIST" has-key 'UISupportedInterfaceOrientations~ipad'

  # A missing share string is not a soft failure: iOS raises
  # NSInvalidArgumentException and terminates at the authorization call.
  # Required to be a top-level, non-empty-after-trimming <string>.
  xmlq_require_match fail \
    "$PLIST has no usable NSHealthShareUsageDescription" \
    "$PLIST" require-string NSHealthShareUsageDescription

  # Stride reads steps and never writes.
  xmlq_require_no_match fail \
    "$PLIST declares NSHealthUpdateUsageDescription, but Stride never writes health data" \
    "$PLIST" has-key NSHealthUpdateUsageDescription

  xmlq_require_no_match fail \
    "$PLIST declares UIBackgroundModes; S-01A is foreground only" \
    "$PLIST" has-key UIBackgroundModes
else
  fail "$PLIST does not exist"
fi

# ---------------------------------------------------------------------------
# 4. Entitlements — parsed, and type-checked
# ---------------------------------------------------------------------------
if [ -f "$ENTITLEMENTS" ]; then
  # <true/>, not <string>true</string>. A string is not a granted entitlement.
  xmlq_require_match fail \
    "$ENTITLEMENTS does not grant com.apple.developer.healthkit as a boolean true" \
    "$ENTITLEMENTS" require-true com.apple.developer.healthkit

  # THE IMPORTANT ONE.
  xmlq_require_no_match fail \
    "$ENTITLEMENTS grants healthkit.background-delivery. S-01A is FOREGROUND ONLY;
      background delivery is S-01B and is blocked on a real persistence
      coordinator. See DECISIONS/0013 and DECISIONS/0014." \
    "$ENTITLEMENTS" has-key com.apple.developer.healthkit.background-delivery

  dupes="$(node "$XMLQ_JS" "$ENTITLEMENTS" dupe-keys 2>/dev/null)"
  rc=$?
  [ "$rc" -ne 2 ] || fail "$ENTITLEMENTS could not be read; failing closed"
  [ -z "$dupes" ] || fail "$ENTITLEMENTS declares duplicate keys:
$dupes"
else
  fail "$ENTITLEMENTS does not exist -- HealthKit cannot be signed in"
fi

# ---------------------------------------------------------------------------
# Self-test — isolated, never the live tree
# ---------------------------------------------------------------------------
if [ "$SELF_TEST" -eq 1 ]; then
  if [ "$failures" -ne 0 ]; then
    echo "ios-target: refusing to self-test while the real tree is failing" >&2
    exit 1
  fi

  TREE_BEFORE="$(st_tree_snapshot)"
  ISO="$(st_make_root)"
  trap 'rm -rf "$ISO"' EXIT
  # shellcheck disable=SC2086
  st_copy "$ISO" $GUARD_PATHS

  st_failures=0
  expect_reject() {
    if bash "$0" --project-root "$ISO" >/dev/null 2>&1; then
      echo "ios-target SELF-TEST FAILED: accepted $1" >&2
      st_failures=$((st_failures + 1))
    else
      echo "  rejected as expected: $1"
    fi
  }

  I_PLIST="$ISO/ios/Runner/Info.plist"
  I_ENT="$ISO/ios/Runner/Runner.entitlements"
  I_PROJ="$ISO/ios/Runner.xcodeproj/project.pbxproj"
  I_EX="$ISO/packages/stride_health/example/ios/Runner.xcodeproj/project.pbxproj"
  cp "$I_PLIST" "$ISO/plist.bak"; cp "$I_ENT" "$ISO/ent.bak"
  cp "$I_PROJ" "$ISO/proj.bak"; cp "$I_EX" "$ISO/ex.bak"
  restore() {
    cp "$ISO/plist.bak" "$I_PLIST"; cp "$ISO/ent.bak" "$I_ENT"
    cp "$ISO/proj.bak" "$I_PROJ"; cp "$ISO/ex.bak" "$I_EX"
  }

  sed -i "s/IPHONEOS_DEPLOYMENT_TARGET = 17.0;/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/" "$I_PROJ"
  expect_reject "deployment target reverted in the app"; restore

  sed -i "s/IPHONEOS_DEPLOYMENT_TARGET = 17.0;/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/" "$I_EX"
  expect_reject "an example app left at 13.0"; restore

  sed -i 's/TARGETED_DEVICE_FAMILY = "1";/TARGETED_DEVICE_FAMILY = "1,2";/' "$I_PROJ"
  expect_reject "iPad added to the device family"; restore

  sed -i 's|CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;||' "$I_PROJ"
  expect_reject "entitlements file unreferenced by the build"; restore

  sed -i 's|<string>UIInterfaceOrientationPortrait</string>|<string>UIInterfaceOrientationPortrait</string><string>UIInterfaceOrientationLandscapeLeft</string>|' "$I_PLIST"
  expect_reject "landscape orientation added"; restore

  # Type, not presence: an empty string still terminates the app.
  perl -0pi -e 's|(<key>NSHealthShareUsageDescription</key>\s*<string>)[^<]*(</string>)|$1$2|s' "$I_PLIST"
  expect_reject "NSHealthShareUsageDescription emptied"; restore

  perl -0pi -e 's|(<key>NSHealthShareUsageDescription</key>\s*<string>)[^<]*(</string>)|$1   $2|s' "$I_PLIST"
  expect_reject "NSHealthShareUsageDescription whitespace-only"; restore

  perl -0pi -e 's|<key>NSHealthShareUsageDescription</key>|<key>NSHealthShareUsageDescriptionX</key>|s' "$I_PLIST"
  expect_reject "the key renamed to a near-miss (X suffix)"; restore

  perl -0pi -e 's|(<dict>)|$1\n  <key>NSHealthUpdateUsageDescription</key><string>writes</string>|s' "$I_PLIST"
  expect_reject "NSHealthUpdateUsageDescription added (app does not write)"; restore

  perl -0pi -e 's|(<dict>)|$1\n  <key>UIBackgroundModes</key><array><string>fetch</string></array>|s' "$I_PLIST"
  expect_reject "UIBackgroundModes declared"; restore

  perl -0pi -e 's|(<dict>)|$1\n  <key>com.apple.developer.healthkit.background-delivery</key><true/>|s' "$I_ENT"
  expect_reject "healthkit.background-delivery entitlement added"; restore

  perl -0pi -e 's|<key>com.apple.developer.healthkit</key>\s*<true/>|<key>com.apple.developer.healthkit</key><string>true</string>|s' "$I_ENT"
  expect_reject "the entitlement given as the STRING \"true\""; restore

  perl -0pi -e 's|(<dict>)|$1\n  <key>com.apple.developer.healthkit</key><true/>|s' "$I_ENT"
  expect_reject "a duplicated security-sensitive entitlement key"; restore

  # Malformed input must FAIL the guard, never read as absence.
  printf '<?xml version="1.0"?>\n<plist version="1.0">\n<dict>\n  <key>oops\n</dict>\n</plist>\n' > "$I_PLIST"
  expect_reject "a MALFORMED Info.plist (must fail closed, not read as absent)"; restore

  printf '<?xml version="1.0"?>\n<plist version="1.0"><dict><key>a</key>\n' > "$I_ENT"
  expect_reject "a MALFORMED Runner.entitlements"; restore

  printf '<?xml version="1.0"?>\n<!DOCTYPE plist PUBLIC "-//Evil//DTD//EN" "http://evil.invalid/x.dtd">\n<plist version="1.0"><dict><key>com.apple.developer.healthkit</key><true/></dict></plist>\n' > "$I_ENT"
  expect_reject "an entitlements file with a NON-Apple doctype"; restore

  printf '<?xml version="1.0"?>\n<!DOCTYPE plist [ <!ENTITY x "y"> ]>\n<plist version="1.0"><dict><key>com.apple.developer.healthkit</key><true/></dict></plist>\n' > "$I_ENT"
  expect_reject "an entitlements file with an internal subset"; restore

  rm -rf "$ISO"
  trap - EXIT

  st_assert_tree_unchanged "$TREE_BEFORE" || exit 1

  if [ "$st_failures" -ne 0 ]; then
    echo "ios-target: SELF-TEST FAILED -- $st_failures injected violation(s) not detected" >&2
    exit 1
  fi
  echo "ios-target: self-test OK -- 17 injected violations rejected"
fi

if [ "$failures" -gt 0 ]; then
  echo "" >&2
  echo "DECISIONS/0009 fixes portrait-only, phone-only, iOS 17." >&2
  echo "DECISIONS/0014 fixes S-01A as FOREGROUND ONLY." >&2
  exit 1
fi

echo "ios-target: OK"
echo "  deployment target : $REQUIRED_IOS across every pbxproj, Package.swift, podspec"
echo "  device family     : iPhone only"
echo "  orientation       : portrait only"
echo "  healthkit         : entitlement is boolean true; usage string non-empty"
echo "                      background-delivery ABSENT; no write string"
echo "  plist/entitlements: PARSED (doctype allowlisted, types checked)"
