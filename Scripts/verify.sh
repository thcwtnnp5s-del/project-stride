#!/usr/bin/env bash
# verify.sh
#
# The full local verification pass. Run before committing.
#
# Everything here runs on Windows via Git Bash. Nothing in this script needs
# macOS -- iOS compilation happens in the CI macOS job.
#
# Usage:
#   ./Scripts/verify.sh            # skips steps whose toolchain is absent
#   ./Scripts/verify.sh --strict   # fails if any toolchain is absent -- use in CI
#
# Without --strict, a CI runner missing Flutter would report success having
# verified nothing.

set -euo pipefail

STRICT=0
for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=1 ;;
    *) echo "error: unknown option '$arg'" >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

step() { printf '\n=== %s ===\n' "$1"; }

missing_toolchain() {
  if [ "$STRICT" -eq 1 ]; then
    echo "error: $1 not found and --strict was requested." >&2
    exit 1
  fi
  echo "$1 not found -- skipping. Install Flutter and re-run."
  return 1
}

# Hand-written Dart only. Generated files are excluded: pigeon output is not
# dart-format clean, and formatting it would fail CI's generated-file drift
# check on the next regeneration.
#
# `stride_health/lib/src` is enumerated file by file rather than as a directory,
# because `messages.g.dart` lives beside the hand-written sources. That means a
# NEW hand-written file there is unchecked until it is added to this list —
# which has already happened once. If a third source ever lands here, move the
# generated file into its own directory and list `lib/src` wholesale instead.
FORMAT_PATHS=(
  lib
  test
  packages/stride_core/lib
  packages/stride_core/test
  packages/stride_storage/lib
  packages/stride_storage/test
  packages/stride_health/lib/stride_health.dart
  packages/stride_health/lib/src/mock_step_source.dart
  packages/stride_health/lib/src/origin_gateway.dart
  packages/stride_health/lib/src/origin_pseudonymizer.dart
  packages/stride_health/lib/src/platform_step_source.dart
  packages/stride_health/lib/src/step_sync_source.dart
  packages/stride_health/test
  packages/stride_health/tool
  packages/stride_health/pigeons
  packages/stride_health/example/lib
  packages/stride_health/example/integration_test
  # Same enumeration, same reason: messages.g.dart lives beside the
  # hand-written sources in lib/src.
  packages/stride_secure_store/lib/stride_secure_store.dart
  packages/stride_secure_store/lib/src/secure_identity_store.dart
  packages/stride_secure_store/lib/src/keychain_identity_store.dart
  packages/stride_secure_store/lib/src/fake_secure_identity_store.dart
  packages/stride_secure_store/test
  packages/stride_secure_store/pigeons
  packages/stride_secure_store/example/lib
)

# The guards parse XML and plists semantically rather than matching them with
# grep, which needs one pinned Node dependency. This checks and STOPS; it never
# installs. A verification run that silently downloads code has made a network
# fetch part of "is this repository correct?", which fails offline for a reason
# unrelated to the code and installs things nobody chose to install.
if [ ! -d Scripts/tooling/node_modules/@xmldom/xmldom ]; then
  echo "error: guard tooling is not installed." >&2
  echo "" >&2
  echo "  Run this once, deliberately:" >&2
  echo "" >&2
  echo "      bash Scripts/bootstrap-tooling.sh" >&2
  echo "" >&2
  echo "  It runs:" >&2
  echo "      npm ci --prefix Scripts/tooling --ignore-scripts --no-audit --no-fund" >&2
  exit 1
fi

step "Rulekit contract (the primitive every rule, case and runner passes through)"
# `rule_run` returned SUCCESS for an undefined rule name, so a misspelled or
# deleted rule read as a clean tree everywhere at once. It is fail-closed now,
# and this is what says so.
./Scripts/check-rulekit.sh

step "Guard parsers (XML, plist, doctype policy, no external resolution)"
./Scripts/check-guard-parsers.sh

step "Guard source-safety (a converted guard is inert when sourced)"
# The registry-driven self-test and the causality runner both work by sourcing a
# guard and calling ONE named rule. That is only sound if sourcing does nothing:
# the old iOS guard cd'd into the project root, set shell options and ran every
# check at load time, so a runner that sourced it would have had its working
# directory changed before it called anything.
./Scripts/check-source-safety.sh

step "Causality framework falsification (the framework must refuse a broken case)"
# A passing causality run is not evidence that the framework works: one that
# accepted everything would report exactly the same thing. This constructs
# deliberately broken cases -- wrong diagnostic, unrelated failure, no-op
# mutation, failed restoration, already-failing baseline, undeclared path, an
# infra exit offered for a reject case, a policy exit offered for an infra case
# -- and requires each to be refused. Two CORRECT cases must still pass, because
# "refuses every broken case" is satisfied perfectly by a framework that refuses
# everything.
./Scripts/check-causality-framework.sh

step "Process supervision (a cancelled run must leave nothing behind)"
# A cancelled batch was believed dead and was not: the wrapper was killed, its
# descendants were reparented and kept running for forty minutes, creating
# fresh temp roots while a cleanup was being reported. This cancels a real
# supervised run and asks the operating system what is left.
./Scripts/check-supervisor.sh

step "Case registry (validates, and every total is derived by counting)"
# The shared case inventory for the migrated guards. Each guard revalidates it
# when its own --self-test runs; this reports the totals in one place, derived
# rather than written down. A count that is computed cannot disagree with the
# thing it counts, which is how the iOS guard came to be described as having 6
# cases when it has 17.
./Scripts/registry-report.sh

step "Core purity"
./Scripts/check-core-purity.sh

step "Dependency policy"
./Scripts/check-dependency-policy.sh

step "Storage privacy and backup exclusions"
./Scripts/check-backup-exclusions.sh

step "iOS target shape and foreground HealthKit config (with self-test)"
# DECISIONS/0009 fixed portrait-only, phone-only, iOS 17 and claimed a
# build-time check that did not exist for six tasks. DECISIONS/0014 fixes S-01A
# as foreground only, so the background-delivery entitlement is checked for
# ABSENCE.
./Scripts/check-ios-target.sh --self-test

step "Android target policy (with self-test)"
# Split out of the iOS guard, which had grown an Android section and stopped
# being about iOS. minSdk 26 everywhere and explicitly -- DECISIONS/0014 -- plus
# no tools:overrideLibrary and no background <service>/<receiver>.
#
# This was never wired in, and three of its checks called an xmlq mode that does
# not exist. Every call exited 2 into `|| true`, so all three were dead from the
# day they were written; the self-test only looked green because the guard was
# already failing on an unrelated parse error.
#
# --self-test is registry-driven: the cases live in Scripts/lib/cases.sh and the
# counts are derived, so no number in this comment can go stale against them.
./Scripts/check-android-target.sh --self-test

step "Single-writer persistence rule (with self-test)"
# Nothing at runtime serializes two isolates -- see DECISIONS/0013. This guard
# is the guarantee. --self-test is registry-driven: every probe is rejected at
# exit 1 by its own diagnostic, and an empty native scan must be exit 2
# infrastructure rather than a clean pass. A guard that has never been falsified
# is not evidence, and a guard that rejects everything is not either.
./Scripts/check-single-writer.sh --self-test

step "One step-ingestion model (with mutation test)"
# DECISIONS/0014: the repository held two parallel ingestion models and the
# platform boundary was wired to the dead one. This guard is what keeps there
# being one. --self-test injects thirteen violations -- the ten historical
# cases plus three that close rules which were enforced but uncased -- and
# asserts each is rejected AT EXIT 1 BY ITS OWN diagnostic, by the complete
# guard AND by its named rule invoked alone. Plus four infrastructure cases:
# every content rule here is an ABSENCE check, and a tree the guard cannot read
# produces absence too.
./Scripts/check-step-model.sh --self-test

step "Origin privacy (with self-test)"
# Keying happens natively, before the value crosses Pigeon, so no raw platform
# identifier reaches Dart at all. That is a property of source text in three
# languages, which no type can hold. --self-test injects twelve violations and
# asserts each is rejected AT EXIT 1 BY ITS OWN diagnostic, plus two layering
# cases: an empty native scan and a missing platform contract must both be
# infrastructure. In a privacy guard the dangerous failure is not a false
# rejection, it is a clean-looking run that read nothing.
#
# The last two cases also run their rule ALONE against the mutated root, which
# is the only way to prove a rule another rule over-determines. See CASE_MAP.md.
./Scripts/check-origin-privacy.sh --self-test

if ! command -v dart >/dev/null 2>&1; then
  missing_toolchain "dart" || exit 0
fi

step "Format (hand-written Dart only)"
dart format --output=none --set-exit-if-changed "${FORMAT_PATHS[@]}"

step "stride_core: analyze and test (no Flutter, no emulator)"
(cd packages/stride_core && dart pub get >/dev/null && dart analyze --fatal-infos && dart test)

step "stride_storage: analyze and test (real files, no emulator)"
# The whole F-06 filesystem surface. It runs against a real temporary
# directory, so this is the only place the adapters are exercised at all --
# leaving it out meant every F-06 regression would land silently.
# -j 1 deliberately. This package measures cross-process lock contention and
# process-death timing; running its files in parallel means the suite contends
# with itself and reports races that are the harness, not the code.
(cd packages/stride_storage && dart pub get >/dev/null && dart analyze --fatal-infos && dart test -j 1)

if ! command -v flutter >/dev/null 2>&1; then
  missing_toolchain "flutter" || exit 0
fi

step "Workspace analyze"
flutter analyze --fatal-infos

step "Flutter tests"
flutter test

step "stride_health tests"
(cd packages/stride_health && flutter test)

step "stride_secure_store tests (port contract only -- no Keychain here)"
(cd packages/stride_secure_store && flutter test)

echo
echo "All checks passed."
echo "Not covered here: Android build (needs the Android SDK and a JDK) and"
echo "iOS compilation (needs macOS -- see the CI ios job)."
echo
echo "Specifically NOT verified anywhere by this script:"
echo "  - the iOS Keychain itself (macOS CI job, simulator)"
echo "  - that a ThisDeviceOnly item is omitted from an iCloud backup"
echo "  - that NSURLIsExcludedFromBackupKey is honoured by iCloud"
echo "  - a locked-device Keychain read (errSecInteractionNotAllowed)"
echo "The last three need two physical iPhones and an iCloud account."
