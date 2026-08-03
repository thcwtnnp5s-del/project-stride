#!/usr/bin/env bash
# check-ios-target.sh
#
# Build-time drift checks for the iOS target's shape, and for the foreground
# read-only HealthKit configuration.
#
# ## Why this exists
#
# DECISIONS/0009 fixed portrait-only, phone-only, iOS 17 minimum. The shipped
# Xcode project disagreed with all three for the whole of F-01 through F-06 --
# landscape orientations declared, iPad in the device family, deployment target
# 13.0 -- and 0009 itself claimed a "build-time check" that did not exist. A
# decision record enforced by nothing is a preference.
#
# The HealthKit half is stricter than a preference. S-01A is FOREGROUND ONLY:
# background delivery is S-01B and is blocked on a real persistence coordinator
# (DECISIONS/0013, DECISIONS/0014). The background-delivery entitlement is
# therefore checked for ABSENCE. Adding it would let iOS wake the app into a
# second execution context the single-writer persistence model does not cover,
# and it would do so without any Dart code changing.
#
# ## Why it anchors instead of counting
#
# Three guards in this repository have been defeated by a closure critic: two
# counted occurrences and accepted a decoy, and one used an unbounded scan that
# walked past the method it was checking and matched an unrelated site 200 lines
# later. This one asserts exact values at named keys and asserts absence
# explicitly. `--self-test` injects every violation it claims to catch and fails
# if any survives.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

failures=0
fail() { echo "ios-target: FAIL -- $1" >&2; failures=$((failures + 1)); }

PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"
PLIST="ios/Runner/Info.plist"
ENTITLEMENTS="ios/Runner/Runner.entitlements"

REQUIRED_IOS="17.0"

# ---------------------------------------------------------------------------
# 1. Deployment target — every declaration, not just the app's
# ---------------------------------------------------------------------------
# A plugin left at 13.0 silently lowers nothing, but it lets a contributor
# write pre-17 compatibility code that the app can never need, and it makes the
# minimum ambiguous. All seven declarations must agree.
if [ -f "$PBXPROJ" ]; then
  wrong="$(grep -n 'IPHONEOS_DEPLOYMENT_TARGET' "$PBXPROJ" | grep -v "= ${REQUIRED_IOS};" || true)"
  if [ -n "$wrong" ]; then
    fail "$PBXPROJ has IPHONEOS_DEPLOYMENT_TARGET != $REQUIRED_IOS (DECISIONS/0009):
$wrong"
  fi
fi

for f in packages/stride_health/ios/stride_health/Package.swift \
         packages/stride_secure_store/ios/stride_secure_store/Package.swift; do
  [ -f "$f" ] || continue
  if ! grep -q "\.iOS(\"${REQUIRED_IOS}\")" "$f"; then
    fail "$f does not declare .iOS(\"$REQUIRED_IOS\")"
  fi
done

for f in packages/stride_health/ios/stride_health.podspec \
         packages/stride_secure_store/ios/stride_secure_store.podspec; do
  [ -f "$f" ] || continue
  if ! grep -q "s.platform = :ios, '${REQUIRED_IOS}'" "$f"; then
    fail "$f does not declare s.platform = :ios, '$REQUIRED_IOS'"
  fi
done

# A podspec whose license is a :file reference breaks if that file is deleted --
# which is exactly what happened when the placeholder LICENSE stubs were removed
# for the public-repository remediation. SPM resolution hides it until a
# CocoaPods fallback, i.e. a first device build on an unfamiliar Mac.
for f in packages/stride_health/ios/stride_health.podspec \
         packages/stride_secure_store/ios/stride_secure_store.podspec; do
  [ -f "$f" ] || continue
  ref="$(grep -oE "s\.license[^=]*=[^\n]*:file *=> *'([^']+)'" "$f" | grep -oE "'[^']+'" | tr -d "'" || true)"
  if [ -n "$ref" ]; then
    target="$(cd "$(dirname "$f")" && cd "$(dirname "$ref")" 2>/dev/null && pwd)/$(basename "$ref")"
    [ -f "$target" ] || fail "$f references a license file that does not exist: $ref"
  fi
done

# ---------------------------------------------------------------------------
# 2. Device family — iPhone only
# ---------------------------------------------------------------------------
# "1" is iPhone, "2" is iPad. HealthKit's availability differs on iPad, and
# DECISIONS/0009 is phone-only. Shipping "1,2" makes the app installable
# somewhere isHealthDataAvailable() can return false.
if [ -f "$PBXPROJ" ]; then
  wrong="$(grep -n 'TARGETED_DEVICE_FAMILY' "$PBXPROJ" | grep -v '= "1";' || true)"
  if [ -n "$wrong" ]; then
    fail "$PBXPROJ targets a device family other than iPhone-only (DECISIONS/0009):
$wrong"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Orientation — portrait only
# ---------------------------------------------------------------------------
if [ -f "$PLIST" ]; then
  for banned in UIInterfaceOrientationLandscapeLeft \
                UIInterfaceOrientationLandscapeRight \
                UIInterfaceOrientationPortraitUpsideDown; do
    if grep -q "$banned" "$PLIST"; then
      fail "$PLIST declares $banned; DECISIONS/0009 is portrait-only"
    fi
  done
  grep -q 'UIInterfaceOrientationPortrait<' "$PLIST" \
    || fail "$PLIST does not declare UIInterfaceOrientationPortrait"
  # An ~ipad orientation block is dead weight on a phone-only target and is
  # where landscape creeps back in.
  if grep -q 'UISupportedInterfaceOrientations~ipad' "$PLIST"; then
    fail "$PLIST declares UISupportedInterfaceOrientations~ipad on a phone-only target"
  fi
fi

# ---------------------------------------------------------------------------
# 4. HealthKit — foreground, read-only
# ---------------------------------------------------------------------------
if [ -f "$PLIST" ]; then
  # Exact <key> elements, not substrings.
  #
  # The substring form passed a probe that renamed the key to
  # `NSHealthShareUsageDescriptionX` -- present to grep, absent to iOS, and the
  # app would have terminated on the first authorization call with the guard
  # green. Found by this script's own --self-test, which is the argument for
  # having one.
  plist_keys="$(grep -oE '<key>[^<]+</key>' "$PLIST" || true)"

  # A missing share string is not a soft failure: iOS raises
  # NSInvalidArgumentException and terminates the app at the authorization call.
  printf '%s\n' "$plist_keys" | grep -qx '<key>NSHealthShareUsageDescription</key>' \
    || fail "$PLIST is missing NSHealthShareUsageDescription -- HealthKit authorization terminates the app without it"

  # Stride reads steps and never writes. Declaring the write string would claim
  # a capability the app does not have, and App Review treats that as a defect.
  if printf '%s\n' "$plist_keys" | grep -qx '<key>NSHealthUpdateUsageDescription</key>'; then
    fail "$PLIST declares NSHealthUpdateUsageDescription, but Stride never writes health data"
  fi
fi

if [ ! -f "$ENTITLEMENTS" ]; then
  fail "$ENTITLEMENTS does not exist -- HealthKit cannot be signed in"
else
  # XML comments stripped first. The file documents the background-delivery key
  # BY NAME as deliberately absent, and a naive substring scan matched that
  # comment and failed the very configuration it was describing. A guard that
  # cannot tell a declaration from a note about a declaration is the same defect
  # class this project has already paid for three times.
  ent_keys="$(sed 's/<!--/\n<!--/g; s/-->/-->\n/g' "$ENTITLEMENTS" | grep -v '^<!--' | grep -oE '<key>[^<]+</key>' || true)"

  printf '%s\n' "$ent_keys" | grep -qx '<key>com.apple.developer.healthkit</key>' \
    || fail "$ENTITLEMENTS does not grant com.apple.developer.healthkit"

  # THE IMPORTANT ONE. Background delivery is S-01B and is blocked on a real
  # persistence coordinator. This entitlement alone would let iOS wake the app
  # into a second execution context outside the single-writer model.
  if printf '%s\n' "$ent_keys" | grep -q 'healthkit\.background-delivery'; then
    fail "$ENTITLEMENTS grants healthkit.background-delivery. S-01A is FOREGROUND ONLY;
      background delivery is S-01B and is blocked on a real persistence
      coordinator. See DECISIONS/0013 and DECISIONS/0014."
  fi
fi

# An entitlements file nothing references is decoration.
if [ -f "$PBXPROJ" ] && ! grep -q 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;' "$PBXPROJ"; then
  fail "$PBXPROJ does not set CODE_SIGN_ENTITLEMENTS; the entitlements file would never be applied"
fi

# Background modes must not appear at all while S-01A is foreground-only.
if [ -f "$PLIST" ] && grep -q 'UIBackgroundModes' "$PLIST"; then
  fail "$PLIST declares UIBackgroundModes; S-01A is foreground only"
fi

# ---------------------------------------------------------------------------
# Self-test: prove every check can fail
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  if [ "$failures" -ne 0 ]; then
    echo "ios-target: refusing to self-test while the real tree is failing" >&2
    exit 1
  fi

  tmp="$(mktemp -d)"
  cp "$PBXPROJ" "$tmp/pbxproj.bak"
  cp "$PLIST" "$tmp/plist.bak"
  cp "$ENTITLEMENTS" "$tmp/ent.bak"
  restore() {
    cp "$tmp/pbxproj.bak" "$PBXPROJ"
    cp "$tmp/plist.bak" "$PLIST"
    cp "$tmp/ent.bak" "$ENTITLEMENTS"
  }
  trap 'restore; rm -rf "$tmp"' EXIT

  st_failures=0
  expect_reject() {
    if bash "$0" >/dev/null 2>&1; then
      echo "ios-target SELF-TEST FAILED: the guard accepted $1" >&2
      st_failures=$((st_failures + 1))
    else
      echo "  rejected as expected: $1"
    fi
    restore
  }

  sed -i 's/IPHONEOS_DEPLOYMENT_TARGET = 17.0;/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/' "$PBXPROJ"
  expect_reject "deployment target reverted to 13.0"

  sed -i 's/TARGETED_DEVICE_FAMILY = "1";/TARGETED_DEVICE_FAMILY = "1,2";/' "$PBXPROJ"
  expect_reject "iPad added to the device family"

  sed -i 's|<string>UIInterfaceOrientationPortrait</string>|<string>UIInterfaceOrientationPortrait</string><string>UIInterfaceOrientationLandscapeLeft</string>|' "$PLIST"
  expect_reject "landscape orientation added"

  sed -i 's|<key>NSHealthShareUsageDescription</key>|<key>NSHealthShareUsageDescriptionX</key>|' "$PLIST"
  expect_reject "NSHealthShareUsageDescription removed"

  sed -i 's|<key>NSHealthShareUsageDescription</key>|<key>NSHealthUpdateUsageDescription</key><string>x</string><key>NSHealthShareUsageDescription</key>|' "$PLIST"
  expect_reject "NSHealthUpdateUsageDescription added (app does not write)"

  sed -i 's|<key>com.apple.developer.healthkit</key>|<key>com.apple.developer.healthkit.background-delivery</key><true/><key>com.apple.developer.healthkit</key>|' "$ENTITLEMENTS"
  expect_reject "healthkit.background-delivery entitlement added"

  sed -i 's|<key>com.apple.developer.healthkit</key>|<key>com.apple.developer.healthkitX</key>|' "$ENTITLEMENTS"
  expect_reject "HealthKit entitlement removed"

  sed -i 's|CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;||' "$PBXPROJ"
  expect_reject "entitlements file unreferenced by the build"

  restore
  trap - EXIT
  rm -rf "$tmp"

  if ! bash "$0" >/dev/null 2>&1; then
    echo "ios-target SELF-TEST FAILED: the tree does not pass after cleanup" >&2
    exit 1
  fi
  if [ "$st_failures" -ne 0 ]; then
    echo "ios-target: SELF-TEST FAILED -- $st_failures injected violations were not detected" >&2
    exit 1
  fi
  echo "ios-target: self-test OK -- all 8 injected violations were rejected"
fi

if [ "$failures" -gt 0 ]; then
  echo "" >&2
  echo "DECISIONS/0009 fixes portrait-only, phone-only, iOS 17." >&2
  echo "DECISIONS/0014 fixes S-01A as FOREGROUND ONLY." >&2
  exit 1
fi

echo "ios-target: OK"
echo "  deployment target : $REQUIRED_IOS across pbxproj, Package.swift, podspec"
echo "  device family     : iPhone only"
echo "  orientation       : portrait only"
echo "  healthkit         : read entitlement present, share usage string present"
echo "                      background-delivery ABSENT (S-01B), no write string"
