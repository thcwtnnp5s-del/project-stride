#!/usr/bin/env bash
# verify.sh
#
# The full local verification pass. Run before committing, and as the F-01
# build-verification step.
#
# Requires macOS with the current stable Xcode. The core purity check and the
# StrideCore test suite need only a Swift toolchain; the simulator builds need
# Xcode.

#
# Usage:
#   ./Scripts/verify.sh            # skips simulator builds if Xcode is absent
#   ./Scripts/verify.sh --strict   # fails if Xcode is absent — use this in CI
#
# Without --strict, a CI runner missing Xcode would report success having built
# nothing.

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

# Update these to match the installed simulator names if they differ.
SMALL_SIM="${STRIDE_SMALL_SIM:-iPhone SE (3rd generation)}"
STANDARD_SIM="${STRIDE_STANDARD_SIM:-iPhone 16}"

step() { printf '\n=== %s ===\n' "$1"; }

step "Core purity"
./Scripts/check-core-purity.sh

step "StrideCore tests (no simulator)"
if command -v swift >/dev/null 2>&1; then
  swift test --package-path StrideCore
elif [ "$STRICT" -eq 1 ]; then
  echo "error: swift not found and --strict was requested." >&2
  exit 1
else
  echo "swift not found — skipping. Requires a Swift toolchain (macOS)."
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  if [ "$STRICT" -eq 1 ]; then
    echo >&2
    echo "error: xcodebuild not found and --strict was requested." >&2
    echo "Full verification requires macOS with the current stable Xcode." >&2
    exit 1
  fi
  echo
  echo "xcodebuild not found — skipping simulator builds."
  echo "Core verification passed. Full verification requires macOS with Xcode."
  echo "Run with --strict to make this a failure."
  exit 0
fi

if [ ! -d "Stride.xcodeproj" ]; then
  step "Generating Xcode project"
  if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate
  else
    echo "error: Stride.xcodeproj missing and xcodegen not installed." >&2
    echo "Run 'brew install xcodegen', or create the project by hand per" >&2
    echo "TECHNICAL/PROJECT_SETUP.md." >&2
    exit 1
  fi
fi

for sim in "$SMALL_SIM" "$STANDARD_SIM"; do
  step "Build + test: $sim"
  xcodebuild test \
    -project Stride.xcodeproj \
    -scheme Stride \
    -destination "platform=iOS Simulator,name=$sim" \
    -quiet
done

echo
echo "All checks passed."
