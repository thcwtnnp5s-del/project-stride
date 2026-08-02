#!/usr/bin/env bash
# check-core-purity.sh
#
# Fails if stride_core imports Flutter, a plugin, dart:ui, or dart:io.
#
# The same rule is enforced by packages/stride_core/test/core_purity_test.dart.
# This script exists so the check also runs in pre-commit hooks and CI, where a
# full test run may be slower than the moment deserves. Both read the same
# forbidden list from lib/src/core_info.dart, so the rule and its guards cannot
# drift apart.
#
# Runs anywhere bash and grep exist, including Windows via Git Bash.
#
# See DECISIONS/0010_CROSS_PLATFORM_STACK.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE_LIB="$REPO_ROOT/packages/stride_core/lib"
CORE_INFO="$CORE_LIB/src/core_info.dart"
CORE_PUBSPEC="$REPO_ROOT/packages/stride_core/pubspec.yaml"

if [ ! -d "$CORE_LIB" ]; then
  echo "error: stride_core sources not found at $CORE_LIB" >&2
  exit 1
fi

file_count=$(find "$CORE_LIB" -name '*.dart' | wc -l | tr -d ' ')
if [ "$file_count" -eq 0 ]; then
  # An empty scan must not pass silently.
  echo "error: no Dart sources found in $CORE_LIB" >&2
  exit 1
fi

# Read the forbidden list from the source of truth rather than duplicating it.
FORBIDDEN=$(grep -oE "'[^']+'," "$CORE_INFO" | tr -d "'," || true)
if [ -z "$FORBIDDEN" ]; then
  echo "error: could not read forbiddenImports from $CORE_INFO" >&2
  exit 1
fi

violations=0
for module in $FORBIDDEN; do
  # Matches real import/export directives, not the name in a comment or string.
  if matches=$(grep -rnE "^[[:space:]]*(import|export)[[:space:]]+['\"]${module}" \
        --include='*.dart' "$CORE_LIB" 2>/dev/null); then
    echo "$matches" >&2
    violations=1
  fi
done

# The rule is structural as well as tested: the package must not even declare a
# Flutter dependency.
if grep -qE '^[[:space:]]+flutter:' "$CORE_PUBSPEC"; then
  echo "error: stride_core/pubspec.yaml declares a Flutter dependency" >&2
  violations=1
fi

if [ "$violations" -ne 0 ]; then
  cat >&2 <<'EOF'

error: stride_core must stay pure.

Define a port in packages/stride_core/lib/src/ports/ and implement it in the
app or in stride_health. Do not relax this rule -- it is what keeps the
simulation testable in milliseconds on Windows with no emulator, and what makes
a future port re-implement a specified system rather than reverse-engineer one.

See DECISIONS/0010_CROSS_PLATFORM_STACK.md.
EOF
  exit 1
fi

module_count=$(echo "$FORBIDDEN" | wc -w | tr -d ' ')
echo "core purity: OK ($file_count Dart files, $module_count forbidden imports checked)"
