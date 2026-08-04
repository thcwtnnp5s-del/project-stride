#!/usr/bin/env bash
# check-causality-framework.sh
#
# Falsifies the causality framework.
#
# ## Why a passing causality run is not evidence that the framework works
#
# `causality-run.sh` reports that 62 cases each caused their intended outcome.
# A framework that accepted everything would report exactly the same thing. So
# would one whose diagnostic matching was broken, one whose changed-path check
# never fired, one whose restoration check compared a fingerprint against
# itself, and one that credited a case for a rejection some unrelated rule
# produced.
#
# That is not a hypothetical class of defect in this repository. Three checks in
# `check-android-target.sh` called an xmlq mode that has never existed; every
# call exited 2 into `|| true`, so the checks were dead from the day they were
# written, and their self-test read GREEN because the guard was already failing
# for an unrelated reason. Six cases, all passing, all proving nothing.
#
# So this suite deliberately constructs BROKEN cases and requires the framework
# to refuse each one. It exits 0 only because every broken scenario was
# detected — and it exits nonzero if any of them is accepted.
#
# ## The controls
#
# "Detects every broken scenario" is satisfied perfectly by a framework that
# rejects everything, which is the same defect wearing the opposite sign. So the
# suite also runs two CORRECT cases — one `complete_guard`, one `named_rule` —
# and requires them to PASS. Both directions, or neither means anything.
#
# ## Why a synthetic guard
#
# The broken cases are declared against `lib/fixtures/fixture-guard.sh`, not
# against a real guard. Breaking a real case would mean mutating the single
# source of truth the whole design rests on; adding permanently-broken cases to
# `cases.sh` would put them in every derived total, indistinguishable from real
# coverage. The fixture obeys the same contract — three exit codes, stable
# diagnostic IDs, `--project-root`, a source-safe entry — so what is proved
# about it holds for the guards it stands in for.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/rulekit.sh
. "$SCRIPT_DIR/lib/rulekit.sh"
# shellcheck source=lib/selftest.sh
. "$SCRIPT_DIR/lib/selftest.sh"
# shellcheck source=lib/registry.sh
. "$SCRIPT_DIR/lib/registry.sh"
# shellcheck source=lib/causality.sh
. "$SCRIPT_DIR/lib/causality.sh"
#
# `cases.sh` is deliberately NOT sourced. The real registry plays no part here:
# the only cases in scope are the ones below, so nothing this suite does can be
# satisfied — or broken — by real coverage.

failures=0
checked=0
fail() { echo "  FAILED  $1" >&2; failures=$((failures + 1)); }
ok()   { echo "  ok      $1"; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/stride-falsify-XXXXXXXX")"
# The fixture guard runs where it LIVES, not from a copy. It sources
# `../rulekit.sh` the way a real guard sources its own, and a guard detached
# from that is a guard whose diagnostics silently do nothing -- which is the
# state this file was first written in, and which both controls caught.
FIXDIR="$SCRIPT_DIR/lib/fixtures"
PROOT_CLEAN="$WORK/project-clean"
PROOT_DIRTY="$WORK/project-dirty"
JSONL="$WORK/records.jsonl"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$PROOT_CLEAN" "$PROOT_DIRTY"

# A root the fixture guard passes.
printf 'ok\n' > "$PROOT_CLEAN/alpha.txt"
printf 'ok\n' > "$PROOT_CLEAN/beta.txt"
printf 'ok\n' > "$PROOT_CLEAN/gamma.txt"

# A root it does NOT pass, for the failing-baseline scenario.
printf 'BAD\n' > "$PROOT_DIRTY/alpha.txt"
printf 'ok\n'  > "$PROOT_DIRTY/beta.txt"
printf 'ok\n'  > "$PROOT_DIRTY/gamma.txt"

: > "$JSONL"

# ---------------------------------------------------------------------------
# The mutation layer for the fixture
# ---------------------------------------------------------------------------
mut_alpha_bad()     { printf 'BAD\n' > "$CASE_ROOT/alpha.txt"; }
mut_beta_bad()      { printf 'BAD\n' > "$CASE_ROOT/beta.txt"; }
mut_alpha_removed() { rm -f "$CASE_ROOT/alpha.txt"; }
mut_gamma_benign()  { printf 'harmless\n' > "$CASE_ROOT/gamma.txt"; }
mut_nothing()       { :; }   # exits 0 having changed nothing -- like a `sed` that matched no line
mut_alpha_and_gamma() {
  printf 'BAD\n' > "$CASE_ROOT/alpha.txt"
  printf 'stray\n' > "$CASE_ROOT/gamma.txt"
}

# ---------------------------------------------------------------------------
# The fixture registry
#
# Every declaration below is a VALID registry entry — correct fields, correct
# expectation class, a diagnostic of the right kind. `reg_validate` accepts them
# all, and that is asserted before anything is run. What is wrong with them is
# CAUSAL, and no schema check can see it. Only running the case can.
# ---------------------------------------------------------------------------
reg_guard fixture "rule_preflight rule_alpha rule_beta"
reg_guard_impl fixture fixture-guard.sh FIXTURE_PATHS

D_ALPHA='STRIDE_GUARD\[fixture\.alpha\]'
D_BETA='STRIDE_GUARD\[fixture\.beta\]'
D_NO_INPUT='STRIDE_INFRA\[fixture\.no_input\]'

# --- the two controls: correct cases, which must PASS ----------------------
reg_case id=fx_control guard=fixture rule=rule_alpha \
  expect=reject form=mutation attribution=complete_guard \
  diag="$D_ALPHA" files="alpha.txt" apply=mut_alpha_bad

reg_case id=fx_control_named guard=fixture rule=rule_alpha \
  expect=reject form=mutation attribution=named_rule \
  diag="$D_ALPHA" forbid="$D_BETA" files="alpha.txt" apply=mut_alpha_bad

# --- 1. the expected diagnostic is wrong -----------------------------------
# The guard DOES reject, at exit 1, for a real reason. It just is not this one.
reg_case id=fx_wrong_diag guard=fixture rule=rule_alpha \
  expect=reject form=mutation attribution=complete_guard \
  diag="$D_BETA" files="alpha.txt" apply=mut_alpha_bad

# --- 2. an unrelated guard failure cannot satisfy a case -------------------
# beta.txt is mutated; rule_beta fires. The case claims rule_alpha. A framework
# that only asked "did the guard fail?" would credit this.
reg_case id=fx_unrelated guard=fixture rule=rule_alpha \
  expect=reject form=mutation attribution=complete_guard \
  diag="$D_ALPHA" files="beta.txt" apply=mut_beta_bad

# The same thing through named-rule attribution: rule_alpha invoked ALONE
# against a root where only beta.txt is wrong returns 0.
reg_case id=fx_unrelated_named guard=fixture rule=rule_alpha \
  expect=reject form=mutation attribution=named_rule \
  diag="$D_ALPHA" files="beta.txt" apply=mut_beta_bad

# --- 3. a no-op mutation -----------------------------------------------------
# A `sed` that matched nothing still exits 0. A rejection afterwards would be
# credited to a mutation that never happened.
reg_case id=fx_noop guard=fixture rule=rule_alpha \
  expect=reject form=mutation attribution=complete_guard \
  diag="$D_ALPHA" files="alpha.txt" apply=mut_nothing

# --- 4. failed restoration ----------------------------------------------------
# A correct case. `reg_restore` is sabotaged for this one run, below.
reg_case id=fx_restore guard=fixture rule=rule_alpha \
  expect=reject form=mutation attribution=complete_guard \
  diag="$D_ALPHA" files="alpha.txt" apply=mut_alpha_bad

# --- 5. already-failing baseline ---------------------------------------------
# The same correct case, run against a root the guard already rejects. Every
# outcome after that is unattributable.
reg_case id=fx_baseline guard=fixture rule=rule_alpha \
  expect=reject form=mutation attribution=complete_guard \
  diag="$D_ALPHA" files="alpha.txt" apply=mut_alpha_bad

# --- 6. an undeclared changed path ------------------------------------------
# Declares alpha.txt, also writes gamma.txt. The excess is what the next case
# would have passed on.
reg_case id=fx_undeclared guard=fixture rule=rule_alpha \
  expect=reject form=mutation attribution=complete_guard \
  diag="$D_ALPHA" files="alpha.txt" apply=mut_alpha_and_gamma

# --- 8. an infrastructure exit cannot satisfy a reject case ------------------
# alpha.txt is deleted, so the guard exits 2: it could not look. A reject case
# satisfied by that would be satisfied equally by deleting Node.
reg_case id=fx_infra_as_reject guard=fixture rule=rule_alpha \
  expect=reject form=mutation attribution=complete_guard \
  diag="$D_ALPHA" files="alpha.txt" apply=mut_alpha_removed

# --- 9. a policy exit cannot satisfy an infra case ---------------------------
reg_case id=fx_policy_as_infra guard=fixture rule=rule_alpha \
  expect=infra form=mutation attribution=complete_guard \
  diag="$D_NO_INPUT" files="alpha.txt" apply=mut_alpha_bad

# --- and: a guard that ACCEPTS cannot satisfy a reject case ------------------
reg_case id=fx_accepted guard=fixture rule=rule_alpha \
  expect=reject form=mutation attribution=complete_guard \
  diag="$D_ALPHA" files="gamma.txt" apply=mut_gamma_benign

# ---------------------------------------------------------------------------
# The registry must ACCEPT all of the above.
#
# This is the assertion that makes the rest of the suite mean what it claims.
# If the schema rejected these declarations, the runner would never see them and
# "the framework detected it" would be a statement about `reg_validate`, not
# about causality.
# ---------------------------------------------------------------------------
echo "falsification: the broken cases are well-formed registry entries"
checked=$((checked + 1))
if reg_validate 2>/dev/null; then
  ok "reg_validate accepts every case below -- what is wrong with them is causal"
else
  fail "the fixture registry does not validate; the scenarios below prove nothing"
  reg_validate 2>&1 | sed 's/^/            | /' >&2
fi

# ---------------------------------------------------------------------------
# Running one fixture case
# ---------------------------------------------------------------------------
run_case() {   # run_case <id> <project-root>
  caus_run_case "$1" "$FIXDIR" "$2" "$WORK" "$JSONL" >/dev/null 2>&1
}

verdict_of() { grep "\"case\":\"$1\"" "$JSONL" | tail -1 | grep -oE '"verdict":"[a-z]+"' | tail -1; }

# must_pass <label> <case-id> [root]
must_pass() {
  local label="$1" id="$2" root="${3:-$PROOT_CLEAN}"
  checked=$((checked + 1))
  if run_case "$id" "$root"; then
    ok "$label"
  else
    fail "$label -- a CORRECT case was refused; the suite below proves nothing"
    caus_run_case "$id" "$FIXDIR" "$root" "$WORK" "$JSONL" 2>&1 | head -12 | sed 's/^/            | /' >&2
  fi
}

# must_be_refused <label> <case-id> [root] [expected-verdict]
must_be_refused() {
  local label="$1" id="$2" root="${3:-$PROOT_CLEAN}" want="${4:-fail}"
  checked=$((checked + 1))
  if run_case "$id" "$root"; then
    fail "$label -- the framework ACCEPTED a broken case"
    return
  fi
  local v; v="$(verdict_of "$id")"
  if [ "$v" != "\"verdict\":\"$want\"" ]; then
    fail "$label -- refused, but recorded $v rather than \"verdict\":\"$want\""
    return
  fi
  ok "$label"
}

echo ""
echo "falsification: controls -- a CORRECT case must still pass"
must_pass "a correct complete_guard case passes"          fx_control
must_pass "a correct named_rule case passes"              fx_control_named

echo ""
echo "falsification: the five required scenarios"
must_be_refused "1. a wrong expected diagnostic is rejected"            fx_wrong_diag
must_be_refused "2. an unrelated guard failure cannot satisfy a case"   fx_unrelated
must_be_refused "2b. an unrelated rule cannot satisfy named attribution" fx_unrelated_named
must_be_refused "3. a no-op mutation is rejected"                       fx_noop

# 4. Restoration. `reg_restore` is replaced with a no-op for exactly one case,
# so the mutation survives and the root cannot fingerprint back. This is
# targeted deliberately: sabotaging the mutation instead would be caught by the
# changed-path check first, and the suite would be reporting scenario 6 twice.
checked=$((checked + 1))
eval "$(declare -f reg_restore | sed '1s/^reg_restore/reg_restore_real/')"
reg_restore() { return 0; }   # "restores" nothing, and claims success
if run_case fx_restore "$PROOT_CLEAN"; then
  fail "4. failed restoration is detected -- an unrestored root was ACCEPTED"
else
  v="$(verdict_of fx_restore)"
  if [ "$v" = '"verdict":"fail"' ]; then
    ok "4. failed restoration is detected"
  else
    fail "4. failed restoration -- refused, but recorded $v"
  fi
fi
eval "$(declare -f reg_restore_real | sed '1s/^reg_restore_real/reg_restore/')"

# The sabotage must be gone: the same case must pass again. Otherwise scenario 4
# could be passing because the suite broke the framework permanently.
checked=$((checked + 1))
if run_case fx_restore "$PROOT_CLEAN"; then
  ok "4b. restoration works again once the sabotage is removed"
else
  fail "4b. the restoration sabotage was not undone"
fi

# 5. A root the guard already rejects. Recorded as `invalid`, not `fail`: the
# case did not produce a wrong outcome, it produced no attributable outcome at
# all, and the two are worth telling apart in the records.
must_be_refused "5. an already-failing baseline invalidates the case" \
  fx_baseline "$PROOT_DIRTY" invalid

echo ""
echo "falsification: the four additional proofs"
must_be_refused "an undeclared changed path is rejected"          fx_undeclared
must_be_refused "an infrastructure exit cannot satisfy a reject case" fx_infra_as_reject
must_be_refused "a policy exit cannot satisfy an infra case"      fx_policy_as_infra
must_be_refused "a guard that ACCEPTS cannot satisfy a reject case" fx_accepted

# An undefined rule. Asserted at the primitive, where the safety has to live:
# `rule_run` used to return 0 for a name that existed nowhere, so a misspelled
# or deleted rule read as a clean tree everywhere at once.
echo ""
echo "falsification: rulekit refuses an undefined rule"
checked=$((checked + 1))
out="$(bash -c '
  set -uo pipefail
  . "$1"
  rule_run rule_this_does_not_exist
' _ "$SCRIPT_DIR/lib/rulekit.sh" 2>&1)"; rc=$?
if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -q 'STRIDE_INFRA\[rulekit\.unknown_rule\]'; then
  ok "an undefined rule is exit 2, STRIDE_INFRA[rulekit.unknown_rule]"
else
  fail "an undefined rule returned $rc: $out"
fi

# And at the registry: a case citing a rule the guard does not have is refused
# before it can run. Both layers, because either alone is a single point of
# failure for the same mistake.
checked=$((checked + 1))
out="$(bash -c '
  set -uo pipefail
  cd "$1"
  . lib/rulekit.sh; . lib/selftest.sh; . lib/registry.sh
  reg_guard fixture "rule_preflight rule_alpha rule_beta"
  reg_guard_impl fixture fixture-guard.sh FIXTURE_PATHS
  reg_case id=fx_bogus guard=fixture rule=rule_not_a_real_rule \
    expect=reject form=mutation attribution=complete_guard \
    diag="STRIDE_GUARD\[fixture\.alpha\]" files="alpha.txt" apply=mut_nothing
  reg_validate
' _ "$SCRIPT_DIR" 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q 'unknown production rule'; then
  ok "the registry refuses a case naming a rule the guard does not have"
else
  fail "the registry accepted a case citing an undefined rule (exit $rc)"
fi

echo ""
if [ "$failures" -gt 0 ]; then
  echo "causality-framework: FAILED -- $failures of $checked assertion(s)" >&2
  exit 1
fi
echo "causality-framework: OK -- $checked assertion(s); every broken scenario was detected and both controls passed"
