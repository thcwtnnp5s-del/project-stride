#!/usr/bin/env bash
# check-dependency-policy.sh
#
# Risk X-01. The moment the platform channel becomes tedious, a third-party
# health plugin will look like a shortcut that saves an afternoon. It would
# place the project's highest-severity system -- never double-count, never lose
# legitimate steps -- behind a third party's interpretation of anchored queries
# and change tokens.
#
# The entire Flutter fidelity case rests on not taking that shortcut, so the
# prohibition is mechanical rather than remembered.
#
# See DECISIONS/0010_CROSS_PLATFORM_STACK.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Known health aggregation packages. Deliberately blunt: any package that would
# own reconciliation, cursors, deletion handling, or ledger semantics.
PROHIBITED='health|health_kit|flutter_health_fit|fit_kit|fitkit|google_fit|flutter_blue_health|healthkit_reporter'

violations=0

pubspecs=$(find . -name pubspec.yaml -not -path '*/build/*' -not -path '*/.dart_tool/*')
if [ -z "$pubspecs" ]; then
  echo "error: no pubspec.yaml found -- refusing to pass vacuously" >&2
  exit 1
fi

for f in $pubspecs; do
  if matches=$(grep -nE "^[[:space:]]+(${PROHIBITED}):" "$f" 2>/dev/null); then
    echo "error: prohibited health package in $f" >&2
    echo "$matches" >&2
    violations=1
  fi
done

# stride_core must declare no Flutter dependency -- the purity rule made
# structural, not merely tested.
if grep -qE '^[[:space:]]+flutter:' packages/stride_core/pubspec.yaml; then
  echo "error: stride_core must not depend on Flutter" >&2
  violations=1
fi

if [ "$violations" -ne 0 ]; then
  cat >&2 <<'EOF'

error: dependency policy violation.

Health integration is first-party, in packages/stride_health. No third-party
package may be the source of truth for change tokens or anchors, reconciliation,
deletion handling, double-count prevention, or ledger semantics.

Utility packages remain allowed after normal dependency review, provided they do
not own health-data correctness.
EOF
  exit 1
fi

count=$(echo "$pubspecs" | wc -l | tr -d ' ')
echo "dependency policy: OK ($count pubspec files checked)"
