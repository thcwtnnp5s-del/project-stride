#!/usr/bin/env bash
# check-android-target.sh
#
# Android target policy. Split out of check-ios-target.sh, which had grown an
# Android section and stopped being about iOS.
#
# ## The rule
#
# Project Stride's minimum is **API 26**, everywhere and explicitly.
#
#   24-25  unsupported. The app does not install.
#   26-27  installs; Health Connect reports unavailable. No permission is
#          requested and nothing crashes.
#   28+    normal availability checking.
#
# This was `minSdk = 24` plus `tools:overrideLibrary` on the Health Connect
# client — a manifest asserting, on the project's behalf, that the SDK supports
# Android 7. It does not. An override does not add support; it moves the
# failure from a build here to a phone belonging to someone who cannot report
# it usefully.
#
# ## Structured files are parsed, not grepped
#
# The manifest is read through `Scripts/lib/xmlq.js`, a real XML reader.
# Three guard defects in this repository were the same mistake — matching
# structured files with `grep` and removing comments with `sed`. Two of them
# matched the file's OWN PROSE about the thing being forbidden and failed a
# correct tree. A comment is a lexical construct; removing it correctly is
# parsing.
#
# Gradle files are not XML and stay a carefully anchored text check.
#
# Usage:
#   check-android-target.sh [--project-root <path>]
#   check-android-target.sh --self-test

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/selftest.sh
. "$SCRIPT_DIR/lib/selftest.sh"

PROJECT_ROOT="$REPO_ROOT"
SELF_TEST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --project-root) PROJECT_ROOT="$2"; shift 2 ;;
    --self-test) SELF_TEST=1; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

XMLQ="$SCRIPT_DIR/lib/xmlq.js"
REQUIRED_MIN_SDK="26"

failures=0
fail() { echo "android-target: FAIL -- $1" >&2; failures=$((failures + 1)); }

cd "$PROJECT_ROOT"

# The paths this guard inspects. Also the copy list for --self-test.
GRADLE_FILES="
android/app/build.gradle.kts
packages/stride_health/android/build.gradle.kts
packages/stride_health/example/android/app/build.gradle.kts
"
MANIFESTS="
packages/stride_health/android/src/main/AndroidManifest.xml
android/app/src/main/AndroidManifest.xml
packages/stride_health/example/android/app/src/main/AndroidManifest.xml
"

# ---------------------------------------------------------------------------
# NAMED PRODUCTION RULES
#
# Each rule is a function, so the causality runner can exercise ONE of them
# against a mutated copy without paying for a full guard run — and, critically,
# exercises the SAME function the complete guard calls. There is no test-only
# variant of any rule: `run_all_rules` is the complete guard, and it is nothing
# but calls to these.
# ---------------------------------------------------------------------------

# rule_min_sdk_pinned — minSdk is 26, explicitly, in every gradle file
rule_min_sdk_pinned() {
declared=0
for f in $GRADLE_FILES; do
  [ -f "$f" ] || continue
  hits="$(grep -nE '^[[:space:]]*minSdk[[:space:]]*=' "$f" || true)"
  [ -n "$hits" ] || continue
  declared=$((declared + 1))
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    value="$(printf '%s' "$line" | sed -E 's/.*minSdk[[:space:]]*=[[:space:]]*//; s/[^A-Za-z0-9_.].*$//')"
    case "$value" in
      "$REQUIRED_MIN_SDK") ;;
      flutter.minSdkVersion)
        fail "$f inherits minSdk from flutter.minSdkVersion (24). Pin it to
      $REQUIRED_MIN_SDK, or a Flutter SDK bump silently lowers the floor back
      under the Health Connect client's own minimum.
      $line" ;;
      *)
        fail "$f declares minSdk $value, not $REQUIRED_MIN_SDK:
      $line" ;;
    esac
  done <<< "$hits"
done

if [ "$declared" -eq 0 ]; then
  fail "no build.gradle.kts declares a minSdk at all. The floor would then be
      whatever Flutter's default is, which is 24."
fi
}

# rule_manifest_parses — every manifest is readable XML
rule_manifest_parses() {
for f in $MANIFESTS; do
  [ -f "$f" ] || continue

  # `parses`, not `keys`. `keys` is a PLIST mode: handed an Android manifest it
  # answered "not a plist" with exit 2, indistinguishable from "malformed", and
  # this line reported all three well-formed manifests as unreadable XML. The
  # tri-state contract says exit 2 is never absence; it does not say every
  # exit 2 has the same cause, and asking a schema-specific question to learn a
  # schema-independent fact is how that got confused.
  #
  # Deliberately `if !`, which here is correct rather than the collapse the
  # helpers warn about: `parses` only exits 0 when there is a document element,
  # so 1 and 2 are both "cannot be read" and both must fail closed.
  if ! node "$XMLQ" "$f" parses >/dev/null 2>&1; then
    fail "$f is not well-formed XML"
  fi
done
}

# rule_no_override_library — no manifest claims support the SDK does not have
rule_no_override_library() {
for f in $MANIFESTS; do
  [ -f "$f" ] || continue
  # A real attribute lookup. `grep` matched this file's own comment saying the
  # override is deliberately absent, and failed a correct manifest twice.
  override="$(node "$XMLQ" "$f" attr-ns android-tools overrideLibrary 2>/dev/null || true)"
  if [ -n "$override" ]; then
    fail "$f sets tools:overrideLibrary:
      $override
      Project Stride does not claim support the Health Connect SDK does not
      have. See DECISIONS/0014."
  fi
done
}

# rule_manifest_min_sdk — a uses-sdk minSdkVersion overrides Gradle silently
rule_manifest_min_sdk() {
for f in $MANIFESTS; do
  [ -f "$f" ] || continue
  usessdk="$(node "$XMLQ" "$f" attr-ns android minSdkVersion uses-sdk 2>/dev/null || true)"
  if [ -n "$usessdk" ]; then
    got="$(printf '%s' "$usessdk" | awk -F'\t' '{print $3}')"
    [ "$got" = "$REQUIRED_MIN_SDK" ] || \
      fail "$f declares android:minSdkVersion=$got in the manifest, not $REQUIRED_MIN_SDK"
  fi
done
}

# rule_no_background_entry — S-01A is foreground only
rule_no_background_entry() {
for f in $MANIFESTS; do
  [ -f "$f" ] || continue
  for el in service receiver; do
    found="$(node "$XMLQ" "$f" attr-ns android name "$el" 2>/dev/null || true)"
    if [ -n "$found" ]; then
      fail "$f declares a <$el>:
      $found
      S-01A is foreground only. Background delivery is S-01B and is blocked on
      a real persistence coordinator. See DECISIONS/0013 and 0014."
    fi
  done
done
}

# The complete guard. Nothing but calls to the named rules above — which is
# what makes "the causality runner exercises the same implementation" true by
# construction rather than by inspection.
ANDROID_RULES="rule_min_sdk_pinned rule_manifest_parses rule_no_override_library rule_manifest_min_sdk rule_no_background_entry"

run_all_rules() {
  local r
  for r in $ANDROID_RULES; do "$r"; done
}

# Sourced by the causality runner: define the rules, run nothing.
if [ "${GUARD_SOURCE_ONLY:-0}" = "1" ]; then
  return 0 2>/dev/null || true
fi

run_all_rules

# ---------------------------------------------------------------------------
# Self-test — isolated, never the live tree
# ---------------------------------------------------------------------------
if [ "$SELF_TEST" -eq 1 ]; then
  if [ "$failures" -ne 0 ]; then
    echo "android-target: refusing to self-test while the real tree is failing" >&2
    exit 1
  fi

  TREE_BEFORE="$(st_tree_snapshot)"
  ISO="$(st_make_root)"
  trap 'rm -rf "$ISO"' EXIT
  # shellcheck disable=SC2086
  st_copy "$ISO" $GRADLE_FILES $MANIFESTS

  st_failures=0
  expect_reject() {
    if bash "$0" --project-root "$ISO" >/dev/null 2>&1; then
      echo "android-target SELF-TEST FAILED: accepted $1" >&2
      st_failures=$((st_failures + 1))
    else
      echo "  rejected as expected: $1"
    fi
  }

  PLUGIN_GRADLE="$ISO/packages/stride_health/android/build.gradle.kts"
  EXAMPLE_GRADLE="$ISO/packages/stride_health/example/android/app/build.gradle.kts"
  PLUGIN_MANIFEST="$ISO/packages/stride_health/android/src/main/AndroidManifest.xml"

  cp "$PLUGIN_GRADLE" "$ISO/g.bak"
  sed -i "s/minSdk = 26/minSdk = 24/" "$PLUGIN_GRADLE"
  expect_reject "plugin minSdk lowered to 24"
  cp "$ISO/g.bak" "$PLUGIN_GRADLE"

  cp "$EXAMPLE_GRADLE" "$ISO/e.bak"
  sed -i "s/minSdk = 26/minSdk = 25/" "$EXAMPLE_GRADLE"
  expect_reject "example app minSdk lowered to 25"
  cp "$ISO/e.bak" "$EXAMPLE_GRADLE"

  sed -i "s/minSdk = 26/minSdk = flutter.minSdkVersion/" "$EXAMPLE_GRADLE"
  expect_reject "example app minSdk inherited from flutter.minSdkVersion"
  cp "$ISO/e.bak" "$EXAMPLE_GRADLE"

  cp "$PLUGIN_MANIFEST" "$ISO/m.bak"
  sed -i 's|<manifest |<manifest xmlns:tools="http://schemas.android.com/tools" |; s|</manifest>|  <uses-sdk tools:overrideLibrary="androidx.health.connect.client" />\n</manifest>|' "$PLUGIN_MANIFEST"
  expect_reject "tools:overrideLibrary reintroduced"
  cp "$ISO/m.bak" "$PLUGIN_MANIFEST"

  sed -i 's|</manifest>|  <uses-sdk android:minSdkVersion="24" />\n</manifest>|' "$PLUGIN_MANIFEST"
  expect_reject "a manifest uses-sdk lowering the floor to 24"
  cp "$ISO/m.bak" "$PLUGIN_MANIFEST"

  sed -i 's|</manifest>|  <service android:name=".SyncService" />\n</manifest>|' "$PLUGIN_MANIFEST"
  expect_reject "a background <service> declared"
  cp "$ISO/m.bak" "$PLUGIN_MANIFEST"

  # An override hidden inside a comment must NOT be rejected — that is the
  # false positive that failed a correct tree twice.
  sed -i 's|</manifest>|  <!-- never add tools:overrideLibrary here -->\n</manifest>|' "$PLUGIN_MANIFEST"
  if bash "$0" --project-root "$ISO" >/dev/null 2>&1; then
    echo "  accepted as expected: the forbidden attribute named only in a comment"
  else
    echo "android-target SELF-TEST FAILED: rejected a tree whose only mention is a comment" >&2
    st_failures=$((st_failures + 1))
  fi
  cp "$ISO/m.bak" "$PLUGIN_MANIFEST"

  rm -rf "$ISO"
  trap - EXIT

  st_assert_tree_unchanged "$TREE_BEFORE" || exit 1

  if [ "$st_failures" -ne 0 ]; then
    echo "android-target: SELF-TEST FAILED -- $st_failures case(s) wrong" >&2
    exit 1
  fi
  echo "android-target: self-test OK -- 6 injected violations rejected, 1 false positive refused"
fi

if [ "$failures" -gt 0 ]; then
  echo "" >&2
  echo "Project Stride's Android minimum is API $REQUIRED_MIN_SDK. See DECISIONS/0014." >&2
  exit 1
fi

echo "android-target: OK"
echo "  minSdk            : $REQUIRED_MIN_SDK, pinned in $declared gradle file(s)"
echo "  overrideLibrary   : absent (parsed, not grepped)"
echo "  background entry  : none (S-01A is foreground only)"
