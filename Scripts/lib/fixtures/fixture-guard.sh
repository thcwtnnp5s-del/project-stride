#!/usr/bin/env bash
# fixture-guard.sh — a synthetic guard, used ONLY by check-causality-framework.sh.
#
# ## Why the falsification suite needs a guard of its own
#
# The suite has to run cases that are DELIBERATELY WRONG and prove the framework
# refuses them. Doing that with a real guard and the real registry would mean
# either editing real cases into broken shapes — mutating the single source of
# truth the whole design rests on — or adding permanently-broken cases to
# `cases.sh`, where they would be indistinguishable from real coverage and would
# be counted in every derived total.
#
# So the broken cases are declared against this guard instead. It is not part of
# the registry, it is not run by `verify.sh`, and it inspects nothing but three
# marker files in its own throwaway root.
#
# It obeys exactly the same contract as a real guard — the named-rule contract,
# the three exit codes, the stable diagnostic IDs, `--project-root`, and the
# source-safe entry — because a fixture that behaved differently from the thing
# it stands in for would prove nothing about the thing it stands in for.
#
#   exit 0  no marker present
#   exit 1  STRIDE_GUARD[fixture.alpha] / [fixture.beta]  a marker file says BAD
#   exit 2  STRIDE_INFRA[fixture.no_input]                alpha.txt is missing
#
# `rule_alpha` and `rule_beta` are INDEPENDENT: neither can see the other's
# file. That is what makes "an unrelated guard failure cannot satisfy a case" a
# real scenario rather than a rephrasing of "the diagnostic did not match".

GUARD_ID="fixture"
FIXTURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$FIXTURE_DIR"

# `${PROJECT_ROOT:-...}`, exactly as every converted guard writes it, and for a
# reason worth stating: a rule invoked ALONE has no `guard_main` to parse
# `--project-root`, so the runner passes the isolated root in the ENVIRONMENT.
# A plain `PROJECT_ROOT="$REPO_ROOT"` at load time overwrites it, and every
# named-rule invocation then measures the guard's own directory instead of the
# mutated tree — reporting `alpha.txt is missing` for a root where alpha.txt is
# present and wrong.
PROJECT_ROOT="${PROJECT_ROOT:-$REPO_ROOT}"

# The rule contract, exactly as a real guard loads it.
#
# Leaving this out is not a small omission, and it is worth recording what it
# looked like. Without rulekit, `rule_begin`, `guard_fail`, `guard_infra` and
# `rule_end` are all "command not found" — every diagnostic silently vanishes,
# `code` stays 0, and the guard prints `fixture: OK` and exits 0 no matter what
# is in the tree. A guard that cannot report anything is indistinguishable from
# a guard with nothing to report.
#
# The falsification suite's two CONTROLS are what caught it: every broken
# scenario was still "detected", because a guard that accepts everything fails
# every case put to it. That is precisely why the controls exist — "detects all
# nine broken scenarios" is satisfied perfectly by a framework, or a fixture,
# that refuses everything.
# shellcheck source=../rulekit.sh
. "$FIXTURE_DIR/../rulekit.sh"

# The isolated-root path list, resolved by `reg_guard_paths` through
# `reg_guard_impl` exactly as a real guard's is.
FIXTURE_PATHS="
alpha.txt
beta.txt
gamma.txt
"

FIXTURE_RULES="rule_preflight rule_alpha rule_beta"

# Every rule returns 0, 1 or 2 explicitly. A rule whose body ends on a `grep`
# that found nothing returns 1, and `rule_run` now converts a raw status outside
# the contract into STRIDE_INFRA[rulekit.invalid_rule_result] — so the trailing
# `return 0` here is the contract, not decoration.
rule_preflight() {
  [ -d "$PROJECT_ROOT" ] || {
    guard_infra "$GUARD_ID.root_missing" "no such project root: $PROJECT_ROOT"
    return 2
  }
  return 0
}

rule_alpha() {
  local f="$PROJECT_ROOT/alpha.txt"
  # An ABSENCE check on a file the guard cannot read produces absence too, so a
  # missing input is infrastructure and never a clean pass.
  [ -f "$f" ] || { guard_infra "$GUARD_ID.no_input" "alpha.txt is missing"; return 2; }
  if grep -q 'BAD' "$f"; then
    guard_fail "$GUARD_ID.alpha" "alpha.txt carries the forbidden marker"
    return 1
  fi
  return 0
}

rule_beta() {
  local f="$PROJECT_ROOT/beta.txt"
  [ -f "$f" ] || return 0
  if grep -q 'BAD' "$f"; then
    guard_fail "$GUARD_ID.beta" "beta.txt carries the forbidden marker"
    return 1
  fi
  return 0
}

run_all_rules() {
  local r
  for r in $FIXTURE_RULES; do "$r"; done
}

guard_main() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --project-root)
        [ $# -ge 2 ] || { echo "STRIDE_INFRA[$GUARD_ID.usage] --project-root needs a path" >&2; return 2; }
        PROJECT_ROOT="$(cd "$2" 2>/dev/null && pwd)" || {
          echo "STRIDE_INFRA[$GUARD_ID.root_missing] no such project root: $2" >&2; return 2; }
        shift 2 ;;
      *) echo "STRIDE_INFRA[$GUARD_ID.usage] unknown option: $1" >&2; return 2 ;;
    esac
  done

  rule_begin
  run_all_rules
  local code=0
  rule_end || code=$?

  if [ "$code" -eq 2 ]; then
    echo "fixture: INFRASTRUCTURE failure -- the guard could not look." >&2
    return 2
  fi
  if [ "$code" -eq 1 ]; then
    echo "fixture: policy violation." >&2
    return 1
  fi
  echo "fixture: OK"
  return 0
}

# Source-safe entry, for the same reason every real guard has one: the runner
# sources this file to invoke a single rule, and that is only sound if sourcing
# does nothing.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  guard_main "$@"
  exit $?
fi
