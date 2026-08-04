#!/usr/bin/env bash
# check-rulekit.sh
#
# Proves the shared production-rule primitive obeys its own contract.
#
# ## Why this file exists
#
# `rule_run` returned SUCCESS for an undefined rule name. `rule_begin; "$1";
# rule_end` — bash printed `command not found`, no counters moved, and
# `rule_end` reported 0. Every caller reads a 0 from `rule_run` as "the rule
# looked at the tree and found nothing wrong", so a misspelled rule name, a rule
# deleted from a guard while the registry still cited it, or a rule invoked
# before its guard finished sourcing all read as clean.
#
# That is the repository's recurring defect in its purest form: a check that
# never ran is indistinguishable from a check that passed. It is worth its own
# test file because `rule_run` is the single point every guard rule, every
# registry `named_rule` case and the whole causality runner passes through. A
# defect here is invisible everywhere and fatal everywhere.
#
# ## What is asserted
#
#   1. a defined rule reporting nothing            -> 0
#   2. a defined rule reporting a violation        -> 1
#   3. a defined rule reporting infrastructure     -> 2
#   4. an UNDEFINED rule                           -> 2, rulekit.unknown_rule
#   5. a rule returning outside 0|1|2              -> 2, rulekit.invalid_rule_result
#   6. sourcing a real guard still does not run guard_main
#
# 4 and 5 are the fail-closed contract. 6 is here rather than only in
# `check-source-safety.sh` because it is the precondition that makes calling one
# rule alone meaningful at all: if sourcing a guard executed it, every
# `rule_run` in the causality runner would be measuring a guard that had already
# run once.
#
# Each assertion runs `rule_run` in a SEPARATE bash process. A test that shares
# a shell with the thing it tests can be satisfied by leftover counter state
# from the assertion before it, which is the same class of defect as a case
# passing on the previous case's leftovers.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULEKIT="$SCRIPT_DIR/lib/rulekit.sh"

failures=0
checked=0

fail() { echo "  FAILED  $1" >&2; failures=$((failures + 1)); }
ok()   { echo "  ok      $1"; }

# probe <body> — run <body> in a fresh bash with rulekit sourced.
# Echoes the captured stderr+stdout; sets PROBE_RC.
PROBE_RC=0
PROBE_OUT=""
probe() {
  PROBE_OUT="$(bash -c '
    set -uo pipefail
    . "$1" || exit 99
    eval "$2"
  ' _ "$RULEKIT" "$1" 2>&1)"
  PROBE_RC=$?
}

# expect <label> <want-rc> <want-diag-regex-or-empty> <forbid-regex-or-empty> <body>
expect() {
  local label="$1" want_rc="$2" want="$3" forbid="$4" body="$5"
  checked=$((checked + 1))
  probe "$body"

  local bad=0
  if [ "$PROBE_RC" -ne "$want_rc" ]; then
    fail "$label: exited $PROBE_RC, expected $want_rc"
    printf '%s\n' "$PROBE_OUT" | head -5 | sed 's/^/            | /' >&2
    bad=1
  fi
  if [ -n "$want" ] && ! printf '%s\n' "$PROBE_OUT" | grep -qE "$want"; then
    fail "$label: no diagnostic matching: $want"
    printf '%s\n' "$PROBE_OUT" | head -5 | sed 's/^/            | /' >&2
    bad=1
  fi
  if [ -n "$forbid" ] && printf '%s\n' "$PROBE_OUT" | grep -qE "$forbid"; then
    fail "$label: emitted a forbidden diagnostic matching: $forbid"
    printf '%s\n' "$PROBE_OUT" | head -5 | sed 's/^/            | /' >&2
    bad=1
  fi
  [ "$bad" -eq 0 ] && ok "$label"
}

echo "rulekit: the three contract results"

# A rule that reports nothing is the only way to reach 0.
expect "a passing rule returns 0" 0 "" 'STRIDE_(GUARD|INFRA)\[' '
  rule_pass() { :; }
  rule_run rule_pass
'

expect "a rejecting rule returns 1" 1 'STRIDE_GUARD\[probe\.rejects\]' 'STRIDE_INFRA\[' '
  rule_reject() { guard_fail probe.rejects "a named policy violation"; }
  rule_run rule_reject
'

expect "an infrastructure rule returns 2" 2 'STRIDE_INFRA\[probe\.cannot_read\]' '' '
  rule_infra() { guard_infra probe.cannot_read "could not read its input"; }
  rule_run rule_infra
'

# Infrastructure outranks violation: a rule that could not look has not
# observed a violation, whatever else it also reported.
expect "infrastructure outranks a violation in the same rule" 2 'STRIDE_INFRA\[probe\.cannot_read\]' '' '
  rule_both() {
    guard_fail  probe.rejects     "a violation"
    guard_infra probe.cannot_read "and a parse failure"
  }
  rule_run rule_both
'

echo ""
echo "rulekit: fail-closed"

# THE defect. `rule_no_such_thing` is defined nowhere; before the fix this
# returned 0 and every caller read it as a clean tree.
expect "an undefined rule returns 2 with unknown_rule" 2 \
  'STRIDE_INFRA\[rulekit\.unknown_rule\]' 'STRIDE_GUARD\[' '
  rule_run rule_no_such_thing_exists
'

# A rule name is a FUNCTION name. `command -v` would have found this on the
# PATH, run it, and handed back its exit status as a policy verdict.
expect "a non-function name returns 2 with unknown_rule" 2 \
  'STRIDE_INFRA\[rulekit\.unknown_rule\]' '' '
  rule_run true
'

expect "an empty rule name returns 2 with unknown_rule" 2 \
  'STRIDE_INFRA\[rulekit\.unknown_rule\]' '' '
  rule_run ""
'

# A rule whose body ends on a missing binary returns 127. Reporting that as
# anything other than infrastructure would let "the tool is not installed"
# masquerade as a verdict.
expect "an invalid return code is converted to exit 2" 2 \
  'STRIDE_INFRA\[rulekit\.invalid_rule_result\]' '' '
  rule_bad_code() { return 42; }
  rule_run rule_bad_code
'

expect "a 127 from a missing binary is converted to exit 2" 2 \
  'STRIDE_INFRA\[rulekit\.invalid_rule_result\]' '' '
  rule_missing_tool() { stride_no_such_binary_anywhere >/dev/null 2>&1; }
  rule_run rule_missing_tool
'

# The conversion must not be reachable by a rule that stayed inside the
# contract: a rule ending on a legitimate `grep` miss returns 1, and that is a
# valid contract code, not an invalid one.
expect "a contract-valid raw status is not treated as invalid" 1 \
  'STRIDE_GUARD\[probe\.rejects\]' 'invalid_rule_result' '
  rule_ok_raw() { guard_fail probe.rejects "violation"; return 1; }
  rule_run rule_ok_raw
'

echo ""
echo "rulekit: source-safety precondition"

# Calling one rule alone is only meaningful if sourcing the guard did not
# already run it. This repeats one assertion of check-source-safety.sh from the
# angle that matters to rule_run specifically: the guard is sourced and ONE rule
# is then invoked, exactly as reg_invoke_named_rule does it.
for guard in check-android-target.sh check-ios-target.sh \
             check-origin-privacy.sh check-single-writer.sh check-step-model.sh; do
  checked=$((checked + 1))
  path="$SCRIPT_DIR/$guard"

  # `bash -c '...' _ ...` gives the new shell a $0 of `_`, which can never equal
  # the sourced path, so the guard's `[[ "${BASH_SOURCE[0]}" == "$0" ]]` entry is
  # false and sourcing is inert. Sourcing from a subshell of a process ALREADY
  # running that guard makes both sides equal and runs guard_main on whatever
  # positional parameters are in scope.
  out="$(bash -c '
    set -uo pipefail
    . "$1"
    echo "SOURCED-SILENTLY"
    type -t guard_main >/dev/null 2>&1 && echo "GUARD_MAIN=defined"
    rule_run rule_no_such_thing_exists
    echo "RULE_RUN_RC=$?"
  ' _ "$path" 2>&1)"

  bad=0
  printf '%s\n' "$out" | grep -q '^SOURCED-SILENTLY$'  || { fail "$guard: sourcing did not complete inertly"; bad=1; }
  printf '%s\n' "$out" | grep -q '^GUARD_MAIN=defined$' || { fail "$guard: guard_main missing after sourcing"; bad=1; }
  printf '%s\n' "$out" | grep -q '^RULE_RUN_RC=2$'      || { fail "$guard: rule_run of an undefined rule did not return 2"; bad=1; }
  printf '%s\n' "$out" | grep -q 'STRIDE_INFRA\[rulekit\.unknown_rule\]' \
    || { fail "$guard: no rulekit.unknown_rule diagnostic"; bad=1; }
  # Any guard diagnostic here means guard_main ran during sourcing.
  printf '%s\n' "$out" | grep -qE "STRIDE_GUARD\[|STRIDE_INFRA\[$(basename "$guard" .sh | sed 's/^check-//')" \
    && { fail "$guard: sourcing executed guard_main"; printf '%s\n' "$out" | head -5 | sed 's/^/            | /' >&2; bad=1; }

  [ "$bad" -eq 0 ] && ok "$guard: inert when sourced; rule_run still fails closed"
done

echo ""
if [ "$failures" -gt 0 ]; then
  echo "rulekit: FAILED -- $failures of $checked assertion(s)" >&2
  exit 1
fi
echo "rulekit: OK -- $checked assertion(s)"
