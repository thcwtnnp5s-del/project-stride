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
  packages/stride_health/lib/stride_health.dart
  packages/stride_health/lib/src/mock_step_provider.dart
  packages/stride_health/lib/src/origin_pseudonymizer.dart
  packages/stride_health/lib/src/platform_step_provider.dart
  packages/stride_health/test
  packages/stride_health/pigeons
  packages/stride_health/example/lib
  packages/stride_health/example/integration_test
)

step "Core purity"
./Scripts/check-core-purity.sh

step "Dependency policy"
./Scripts/check-dependency-policy.sh

if ! command -v dart >/dev/null 2>&1; then
  missing_toolchain "dart" || exit 0
fi

step "Format (hand-written Dart only)"
dart format --output=none --set-exit-if-changed "${FORMAT_PATHS[@]}"

step "stride_core: analyze and test (no Flutter, no emulator)"
(cd packages/stride_core && dart pub get >/dev/null && dart analyze --fatal-infos && dart test)

if ! command -v flutter >/dev/null 2>&1; then
  missing_toolchain "flutter" || exit 0
fi

step "Workspace analyze"
flutter analyze --fatal-infos

step "Flutter tests"
flutter test

step "stride_health tests"
(cd packages/stride_health && flutter test)

echo
echo "All checks passed."
echo "Not covered here: Android build (needs the Android SDK and a JDK) and"
echo "iOS compilation (needs macOS -- see the CI ios job)."
