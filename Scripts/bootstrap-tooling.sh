#!/usr/bin/env bash
# bootstrap-tooling.sh
#
# Installs the build guards' Node dependency. **A deliberate step, run by hand
# or by CI — never implicitly by a verification run.**
#
# ## Why verify.sh does not do this for you
#
# A verification script that silently downloads code has quietly made a network
# fetch part of "is this repository correct?". That is wrong in two directions:
# it fails offline for a reason unrelated to the code, and it means a run can
# install something without anyone deciding to. `Scripts/verify.sh` therefore
# checks and stops with this command in the message.
#
# ## Determinism
#
#   npm ci             exact lockfile install; fails if package.json and the
#                      lock disagree, unlike `npm install` which would rewrite
#                      the lock to make the disagreement go away
#   --ignore-scripts   no lifecycle scripts from any package
#   --no-audit         no audit request
#   --no-fund          no funding request
#
# The dependency is `@xmldom/xmldom`, pinned exactly, with zero transitive
# dependencies and an MIT licence. See DEPENDENCIES.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v npm >/dev/null 2>&1; then
  echo "error: npm is not on PATH. Node 18+ and npm are required for the" >&2
  echo "       build guards, which parse XML and plists semantically." >&2
  exit 1
fi

echo "Installing guard tooling (deterministic, no lifecycle scripts)..."
npm ci --prefix Scripts/tooling --ignore-scripts --no-audit --no-fund

echo ""
echo "Verifying..."
node Scripts/lib/no-resolution-probe.js

echo ""
echo "Guard tooling ready."
