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
# ## Named rules, and the two exit-code layers
#
# Every check is a named production rule returning under the guard contract:
#
#   0  policy satisfied
#   1  a NAMED policy violation, reported as STRIDE_GUARD[ios.<rule>]
#   2  infrastructure, reported as STRIDE_INFRA[ios.<what>]
#
# Underneath it, xmlq keeps its own three-valued process contract, and its
# exit 2 carries a reason. Only `STRIDE_XMLQ[invalid_document]` may be
# translated into a policy rejection — the `ios.plist_parses` and
# `ios.entitlements_parses` rules. A missing file, a misspelled mode, a missing
# Node or a parser crash is `STRIDE_INFRA[ios.xmlq.<reason>]` and guard exit 2,
# which no mutation case can be satisfied by. Three checks in this repository
# were dead for their entire existence because a nonzero exit was taken as
# evidence; it is not.
#
# Usage:
#   check-ios-target.sh [--project-root <path>]
#   check-ios-target.sh --self-test

# NOTE ON SOURCING: everything above `guard_main` must be free of side effects.
# No traps, no `cd`, no shell-option changes, no file creation, no rule
# execution. `Scripts/check-source-safety.sh` proves that for every guard.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/rulekit.sh
. "$SCRIPT_DIR/lib/rulekit.sh"
# shellcheck source=lib/selftest.sh
. "$SCRIPT_DIR/lib/selftest.sh"
# shellcheck source=lib/xmlq.sh
. "$SCRIPT_DIR/lib/xmlq.sh"
# shellcheck source=lib/registry.sh
. "$SCRIPT_DIR/lib/registry.sh"
# shellcheck source=lib/cases.sh
. "$SCRIPT_DIR/lib/cases.sh"

GUARD_ID="ios"
REQUIRED_IOS="17.0"

# Every rule resolves its paths against this. Set by guard_main, or directly by
# the causality runner — which is why it is a plain variable and why no rule
# calls `cd`. The old version did `cd "$PROJECT_ROOT"` at load time, which made
# sourcing this file move the caller's shell.
PROJECT_ROOT="${PROJECT_ROOT:-$REPO_ROOT}"

PLIST_REL="ios/Runner/Info.plist"
ENTITLEMENTS_REL="ios/Runner/Runner.entitlements"
APP_PBXPROJ_REL="ios/Runner.xcodeproj/project.pbxproj"

SWIFT_PACKAGES="
packages/stride_health/ios/stride_health/Package.swift
packages/stride_secure_store/ios/stride_secure_store/Package.swift
"
PODSPECS="
packages/stride_health/ios/stride_health.podspec
packages/stride_secure_store/ios/stride_secure_store.podspec
"

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

# `fail_in` is this guard's local spelling of a policy violation; it carries the
# stable ID the registry matches.
fail_in() { guard_fail "$GUARD_ID.$1" "$2"; }

# Paths are reported relative to the project root, so a message reads the same
# whether the guard is looking at the live tree or at a temporary copy.
rel() { printf '%s' "${1#"$PROJECT_ROOT"/}"; }

# The two document-validity rule IDs, and the infra prefix. Passed to the xmlq
# layer, which decides between them by REASON and never by exit code alone.
PLIST_PARSES_ID="$GUARD_ID.plist_parses"
ENT_PARSES_ID="$GUARD_ID.entitlements_parses"
XMLQ_INFRA_PREFIX="$GUARD_ID.xmlq"

plist_path()  { printf '%s' "$PROJECT_ROOT/$PLIST_REL"; }
ent_path()    { printf '%s' "$PROJECT_ROOT/$ENTITLEMENTS_REL"; }

# ---------------------------------------------------------------------------
# NAMED PRODUCTION RULES
#
# Each rule is a function, so the causality runner can exercise ONE of them
# against a mutated copy without paying for a full guard run — and, critically,
# exercises the SAME function the complete guard calls. There is no test-only
# variant of any rule: `run_all_rules` is the complete guard, and it is nothing
# but calls to these.
# ---------------------------------------------------------------------------

# rule_preflight — the guard can actually do its job.
#
# EXIT 2 territory, and deliberately separate from every rule below. A
# malformed plist is a policy violation because the guard looked and the tree is
# wrong; a missing `node` is infrastructure because the guard could not look at
# all. Collapsing those is the inversion that made three checks in this
# repository dead for their entire existence.
rule_preflight() {
  [ -d "$PROJECT_ROOT" ] || \
    guard_infra "$GUARD_ID.root_missing" "project root $PROJECT_ROOT does not exist"
  command -v node >/dev/null 2>&1 || \
    guard_infra "$GUARD_ID.node_missing" "node is not on PATH; the plist and entitlements cannot be parsed"
  [ -f "$XMLQ_JS" ] || \
    guard_infra "$GUARD_ID.xmlq_missing" "$XMLQ_JS is missing"
}

# rule_deployment_target — EVERY Xcode project, not just the app's.
#
# This checked only `ios/Runner.xcodeproj` and passed while CI failed: the two
# plugin EXAMPLE apps were left at 13.0, and a plugin declaring iOS 17 cannot be
# consumed by a host declaring 13.0. Those example apps are what the macOS job
# builds in order to compile the Swift.
rule_deployment_target() {
  local proj wrong scanned=0
  while IFS= read -r proj; do
    [ -n "$proj" ] || continue
    scanned=$((scanned + 1))
    wrong="$(grep -n 'IPHONEOS_DEPLOYMENT_TARGET' "$proj" | grep -v "= ${REQUIRED_IOS};" || true)"
    [ -z "$wrong" ] || fail_in deployment_target "$(rel "$proj") has IPHONEOS_DEPLOYMENT_TARGET != $REQUIRED_IOS (DECISIONS/0009):
      $wrong"
  done <<< "$(find "$PROJECT_ROOT" -name project.pbxproj -not -path '*/build/*' -not -path '*/ephemeral/*' 2>/dev/null | sort)"

  # An empty scan is not a clean scan. If no Xcode project was found at all,
  # this rule has observed nothing and must not report success — which is
  # infrastructure, not a policy statement about a tree it never read.
  [ "$scanned" -gt 0 ] || \
    guard_infra "$GUARD_ID.no_pbxproj" "no project.pbxproj was found under $PROJECT_ROOT; nothing was inspected"
  PBXPROJ_SCANNED="$scanned"
}

# rule_swift_package_platform — each SPM package declares the same floor
rule_swift_package_platform() {
  local f
  for f in $SWIFT_PACKAGES; do
    f="$PROJECT_ROOT/$f"
    [ -f "$f" ] || continue
    grep -q "\.iOS(\"${REQUIRED_IOS}\")" "$f" || \
      fail_in swift_package_platform "$(rel "$f") does not declare .iOS(\"$REQUIRED_IOS\")"
  done
}

# rule_podspec_platform — and so does each podspec
rule_podspec_platform() {
  local f
  for f in $PODSPECS; do
    f="$PROJECT_ROOT/$f"
    [ -f "$f" ] || continue
    grep -q "s.platform = :ios, '${REQUIRED_IOS}'" "$f" || \
      fail_in podspec_platform "$(rel "$f") does not declare s.platform = :ios, '$REQUIRED_IOS'"
  done
}

# rule_podspec_license_file — a :file license reference must resolve.
#
# A podspec whose license is a :file reference breaks when that file is removed
# — which happened when the placeholder LICENSE stubs were deleted for the
# public-repository remediation. SPM hides it until a CocoaPods fallback, i.e. a
# first device build on an unfamiliar Mac.
rule_podspec_license_file() {
  local f ref target
  for f in $PODSPECS; do
    f="$PROJECT_ROOT/$f"
    [ -f "$f" ] || continue
    ref="$(grep -oE "s\.license[^=]*=[^\n]*:file *=> *'([^']+)'" "$f" | grep -oE "'[^']+'" | tr -d "'" || true)"
    [ -n "$ref" ] || continue
    target="$(cd "$(dirname "$f")" && cd "$(dirname "$ref")" 2>/dev/null && pwd)/$(basename "$ref")"
    [ -f "$target" ] || \
      fail_in podspec_license_file "$(rel "$f") references a license file that does not exist: $ref"
  done
}

# rule_device_family — iPhone only
rule_device_family() {
  local proj="$PROJECT_ROOT/$APP_PBXPROJ_REL" wrong
  [ -f "$proj" ] || return 0
  wrong="$(grep -n 'TARGETED_DEVICE_FAMILY' "$proj" | grep -v '= "1";' || true)"
  [ -z "$wrong" ] || fail_in device_family "$(rel "$proj") is not iPhone-only (DECISIONS/0009):
      $wrong"
}

# rule_entitlements_wired — an entitlements file the build never applies is
# decoration. Every check in `rule_no_background_delivery` rests on this.
rule_entitlements_wired() {
  local proj="$PROJECT_ROOT/$APP_PBXPROJ_REL"
  [ -f "$proj" ] || return 0
  grep -q 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;' "$proj" || \
    fail_in entitlements_wired "$(rel "$proj") does not set CODE_SIGN_ENTITLEMENTS; the entitlements
      file would never be applied to the built app"
}

# rule_plist_present — the file exists at all
rule_plist_present() {
  [ -f "$(plist_path)" ] || fail_in plist_present "$PLIST_REL does not exist"
}

# rule_plist_parses — Info.plist is a valid document.
#
# One of the two rules permitted to be reached by an xmlq exit 2, and only for
# the `invalid_document` reason. A malformed plist is a POLICY violation: the
# guard read the file and the file is wrong. A missing Node is not.
rule_plist_parses() {
  local p; p="$(plist_path)"
  [ -f "$p" ] || return 0   # absence is rule_plist_present's statement to make
  xmlq_rule_parses "$PLIST_PARSES_ID" "$XMLQ_INFRA_PREFIX" "$p"
}

# rule_orientation_portrait — portrait, and portrait only.
#
# Read as ARRAY VALUES. An earlier version swept for elements named `string` and
# counted matches in the element NAMES, so it reported zero landscape entries
# whatever the file contained — a check that could not fail. This guard's own
# self-test caught it.
rule_orientation_portrait() {
  local p banned; p="$(plist_path)"
  [ -f "$p" ] || return 0

  xmlq_call "$p" array-strings UISupportedInterfaceOrientations
  case "$XMLQ_STATUS" in
    0) ;;
    1) fail_in orientation_portrait "$PLIST_REL has no usable UISupportedInterfaceOrientations array"
       return 0 ;;
    *) xmlq_translate_failure "$PLIST_PARSES_ID" "$XMLQ_INFRA_PREFIX" \
         "$PLIST_REL orientations could not be read"
       return 0 ;;
  esac

  banned="$(printf '%s\n' "$XMLQ_OUT" | grep -E 'Landscape|UpsideDown' || true)"
  [ -z "$banned" ] || fail_in orientation_portrait "$PLIST_REL declares non-portrait orientation(s); DECISIONS/0009 is portrait-only:
      $banned"
  printf '%s\n' "$XMLQ_OUT" | grep -q 'UIInterfaceOrientationPortrait' || \
    fail_in orientation_portrait "$PLIST_REL does not declare UIInterfaceOrientationPortrait"
}

# rule_no_ipad_orientation — no ~ipad block on a phone-only target
rule_no_ipad_orientation() {
  local p; p="$(plist_path)"
  [ -f "$p" ] || return 0
  xmlq_rule_require_no_match "$GUARD_ID.no_ipad_orientation" "$PLIST_PARSES_ID" "$XMLQ_INFRA_PREFIX" \
    "$PLIST_REL declares UISupportedInterfaceOrientations~ipad on a phone-only target" \
    "$p" has-key 'UISupportedInterfaceOrientations~ipad'
}

# rule_health_share_string — a usable purpose string.
#
# Not a soft failure: a missing share string makes iOS raise
# NSInvalidArgumentException and terminate at the authorization call. Required
# to be a top-level, non-empty-after-trimming <string>.
rule_health_share_string() {
  local p; p="$(plist_path)"
  [ -f "$p" ] || return 0
  xmlq_rule_require_match "$GUARD_ID.health_share_string" "$PLIST_PARSES_ID" "$XMLQ_INFRA_PREFIX" \
    "$PLIST_REL has no usable NSHealthShareUsageDescription" \
    "$p" require-string NSHealthShareUsageDescription
}

# rule_no_health_write_string — Stride reads steps and never writes
rule_no_health_write_string() {
  local p; p="$(plist_path)"
  [ -f "$p" ] || return 0
  xmlq_rule_require_no_match "$GUARD_ID.no_health_write_string" "$PLIST_PARSES_ID" "$XMLQ_INFRA_PREFIX" \
    "$PLIST_REL declares NSHealthUpdateUsageDescription, but Stride never writes health data" \
    "$p" has-key NSHealthUpdateUsageDescription
}

# rule_no_background_modes — S-01A is foreground only
rule_no_background_modes() {
  local p; p="$(plist_path)"
  [ -f "$p" ] || return 0
  xmlq_rule_require_no_match "$GUARD_ID.no_background_modes" "$PLIST_PARSES_ID" "$XMLQ_INFRA_PREFIX" \
    "$PLIST_REL declares UIBackgroundModes; S-01A is foreground only" \
    "$p" has-key UIBackgroundModes
}

# rule_entitlements_present — HealthKit cannot be signed in without it
rule_entitlements_present() {
  [ -f "$(ent_path)" ] || \
    fail_in entitlements_present "$ENTITLEMENTS_REL does not exist -- HealthKit cannot be signed in"
}

# rule_entitlements_parses — Runner.entitlements is a valid document.
#
# The second rule an xmlq `invalid_document` may become, and the one that covers
# the doctype policy: a non-Apple doctype and an internal subset are rejected
# lexically, before any query runs.
rule_entitlements_parses() {
  local e; e="$(ent_path)"
  [ -f "$e" ] || return 0
  xmlq_rule_parses "$ENT_PARSES_ID" "$XMLQ_INFRA_PREFIX" "$e"
}

# rule_healthkit_entitlement_true — <true/>, not <string>true</string>.
# A string is not a granted entitlement.
rule_healthkit_entitlement_true() {
  local e; e="$(ent_path)"
  [ -f "$e" ] || return 0
  xmlq_rule_require_match "$GUARD_ID.healthkit_entitlement_true" "$ENT_PARSES_ID" "$XMLQ_INFRA_PREFIX" \
    "$ENTITLEMENTS_REL does not grant com.apple.developer.healthkit as a boolean true" \
    "$e" require-true com.apple.developer.healthkit
}

# rule_no_background_delivery — THE IMPORTANT ONE.
rule_no_background_delivery() {
  local e; e="$(ent_path)"
  [ -f "$e" ] || return 0
  xmlq_rule_require_no_match "$GUARD_ID.no_background_delivery" "$ENT_PARSES_ID" "$XMLQ_INFRA_PREFIX" \
    "$ENTITLEMENTS_REL grants healthkit.background-delivery. S-01A is FOREGROUND ONLY;
      background delivery is S-01B and is blocked on a real persistence
      coordinator. See DECISIONS/0013 and DECISIONS/0014." \
    "$e" has-key com.apple.developer.healthkit.background-delivery
}

# rule_no_duplicate_entitlement_keys — which of two values applies is a parser
# detail, not a decision anyone made.
rule_no_duplicate_entitlement_keys() {
  local e; e="$(ent_path)"
  [ -f "$e" ] || return 0
  xmlq_call "$e" dupe-keys
  case "$XMLQ_STATUS" in
    0 | 1) ;;
    *) xmlq_translate_failure "$ENT_PARSES_ID" "$XMLQ_INFRA_PREFIX" \
         "$ENTITLEMENTS_REL duplicate-key scan could not be read"
       return 0 ;;
  esac
  [ -z "$XMLQ_OUT" ] || fail_in no_duplicate_entitlement_keys "$ENTITLEMENTS_REL declares duplicate keys:
      $XMLQ_OUT"
}

# The complete guard. Nothing but calls to the named rules above — which is what
# makes "the causality runner exercises the same implementation" true by
# construction rather than by inspection.
#
# Order matters only for readability: every rule is independent, and a rule
# whose input is missing returns 0 and leaves that statement to the `_present`
# rule that owns it.
IOS_RULES="
rule_preflight
rule_deployment_target
rule_swift_package_platform
rule_podspec_platform
rule_podspec_license_file
rule_device_family
rule_entitlements_wired
rule_plist_present
rule_plist_parses
rule_orientation_portrait
rule_no_ipad_orientation
rule_health_share_string
rule_no_health_write_string
rule_no_background_modes
rule_entitlements_present
rule_entitlements_parses
rule_healthkit_entitlement_true
rule_no_background_delivery
rule_no_duplicate_entitlement_keys
"

run_all_rules() {
  local r
  for r in $IOS_RULES; do "$r"; done
}

guard_main() {
  PROJECT_ROOT="$REPO_ROOT"
  SELF_TEST=0
  PBXPROJ_SCANNED=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --project-root)
        [ $# -ge 2 ] || { echo "STRIDE_INFRA[$GUARD_ID.usage] --project-root needs a path" >&2; return 2; }
        PROJECT_ROOT="$(cd "$2" 2>/dev/null && pwd)" || {
          echo "STRIDE_INFRA[$GUARD_ID.root_missing] no such project root: $2" >&2; return 2; }
        shift 2 ;;
      --self-test) SELF_TEST=1; shift ;;
      *) echo "STRIDE_INFRA[$GUARD_ID.usage] unknown option: $1" >&2; return 2 ;;
    esac
  done

  rule_begin
  run_all_rules
  local code=0
  rule_end || code=$?
  failures="$RULE_VIOLATIONS"

  guard_body "$code"
}

guard_body() {
  local code="$1"
  if [ "$code" -eq 2 ]; then
    echo "" >&2
    echo "ios-target: INFRASTRUCTURE failure -- the guard could not look." >&2
    return 2
  fi

  if [ "$SELF_TEST" -eq 1 ]; then
    run_self_test || return $?
  fi

  if [ "$failures" -gt 0 ]; then
    echo "" >&2
    echo "DECISIONS/0009 fixes portrait-only, phone-only, iOS 17." >&2
    echo "DECISIONS/0014 fixes S-01A as FOREGROUND ONLY." >&2
    return 1
  fi

  echo "ios-target: OK"
  echo "  deployment target : $REQUIRED_IOS across $PBXPROJ_SCANNED pbxproj, plus Package.swift and podspecs"
  echo "  device family     : iPhone only"
  echo "  orientation       : portrait only"
  echo "  healthkit         : entitlement is boolean true; usage string non-empty"
  echo "                      background-delivery ABSENT; no write string"
  echo "  plist/entitlements: PARSED (doctype allowlisted, types checked)"
}

# ---------------------------------------------------------------------------
# Self-test — registry-driven, isolated, never the live tree
#
# This guard holds no case inventory of its own. All eighteen cases — their
# mutations, their expected exit codes and their expected diagnostics — live in
# `Scripts/lib/cases.sh`, and the runner in `Scripts/lib/registry.sh` refuses to
# run if any of that machinery comes back here. A second inventory is exactly
# how this guard came to be reported as having 6 cases when it has 17.
#
# The runner asserts, per case:
#
#   * the COMPLETE guard produces the case's expected outcome — exit 1 with its
#     own STRIDE_GUARD diagnostic for a `reject`, exit 0 with none for an
#     `accept`, exit 2 with its own STRIDE_INFRA diagnostic for an `infra`.
#     Exit 2 fails a reject case, which is what keeps a missing Node, a wrong
#     path or a misspelled xmlq mode from satisfying a mutation
#   * the mutation changed exactly the paths it declared, and no others
#   * the isolated root's fingerprint — existence, bytes, type, mode and symlink
#     target of every path — is identical after restoration
#
# Counts are DERIVED from the registry and printed by the runner. There is no
# number written down in this file to disagree with them.
# ---------------------------------------------------------------------------
run_self_test() {
  if [ "$failures" -ne 0 ]; then
    echo "ios-target: refusing to self-test while the real tree is failing" >&2
    return 1
  fi
  # shellcheck disable=SC2086
  reg_selftest "$GUARD_ID" "$0" "$IOS_RULES" -- $GUARD_PATHS
}

# Source-safe entry. Sourcing defines the rules and does nothing else: no traps,
# no cd, no shell-option changes, no files, no rule execution. Proven for every
# guard by Scripts/check-source-safety.sh.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  guard_main "$@"
  exit $?
fi
