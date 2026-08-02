#!/usr/bin/env bash
# check-core-purity.sh
#
# Fails if StrideCore imports any platform framework.
#
# The same rule is enforced by CorePurityTests. This script exists so the check
# also runs in pre-commit hooks and CI, where a full `swift test` may be slower
# than the moment deserves.
#
# See DECISIONS/0002_TECHNOLOGY_STACK.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCES="$REPO_ROOT/StrideCore/Sources/StrideCore"

FORBIDDEN=(
  SwiftUI UIKit AppKit HealthKit AVFoundation AVFAudio
  CoreHaptics CoreLocation CoreMotion WidgetKit Combine
)

if [ ! -d "$SOURCES" ]; then
  echo "error: StrideCore sources not found at $SOURCES" >&2
  exit 1
fi

# An empty scan must not pass silently.
file_count=$(find "$SOURCES" -name '*.swift' | wc -l | tr -d ' ')
if [ "$file_count" -eq 0 ]; then
  echo "error: no Swift sources found in $SOURCES" >&2
  exit 1
fi

violations=0
for module in "${FORBIDDEN[@]}"; do
  # Matches real import statements only, not the name in a comment or string.
  if matches=$(grep -rnE "^[[:space:]]*(@testable[[:space:]]+)?import[[:space:]]+${module}\b" \
        --include='*.swift' "$SOURCES" 2>/dev/null); then
    echo "$matches" >&2
    violations=1
  fi
done

if [ "$violations" -ne 0 ]; then
  cat >&2 <<'EOF'

error: StrideCore must not import platform frameworks.

Move the platform work into the app target behind a protocol defined in
StrideCore. Do not relax this rule — it is what keeps the simulation testable
without a simulator and portable to any future platform.

See DECISIONS/0002_TECHNOLOGY_STACK.md.
EOF
  exit 1
fi

echo "core purity: OK ($file_count source files, ${#FORBIDDEN[@]} forbidden modules checked)"
