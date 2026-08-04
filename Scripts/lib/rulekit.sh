# The production-rule contract every guard rule obeys.
#
# ## The three exit codes
#
#   0  policy satisfied
#   1  a NAMED policy violation
#   2  infrastructure: a parser failure, a missing input, a bad invocation, a
#      missing dependency
#
# 1 and 2 are separated because conflating them is how this repository's guards
# have failed, twice, in the same session:
#
#   * `xmlq_parses` asked for a plist-only mode to learn whether a document was
#     readable, so every well-formed Android manifest came back exit 2 — and
#     the caller reported it as "not well-formed XML"
#   * three `check-android-target.sh` checks called an xmlq mode that has never
#     existed; every call exited 2 into `|| true`, so the checks were dead, and
#     their self-test read as green because the guard was already failing for
#     an unrelated reason
#
# In both cases a guard was rejecting everything, and "rejects everything" and
# "works" are indistinguishable to a self-test that only asks whether the exit
# code was nonzero. So causality counts a rejection ONLY on exit 1 with the
# expected diagnostic ID. Exit 2 always invalidates a case.
#
# ## Stable diagnostic IDs
#
#   STRIDE_GUARD[<guard>.<rule>]   a policy violation
#   STRIDE_INFRA[<guard>.<what>]   an infrastructure failure
#
# The registry matches the ID, never the prose. Prose is for the human reading
# the failure and is expected to be rewritten; an ID is a contract. Matching
# prose would mean improving a message could silently stop a case from proving
# anything, which is the same class of defect as everything above.

RULE_VIOLATIONS=0
RULE_INFRA=0

rule_begin() { RULE_VIOLATIONS=0; RULE_INFRA=0; }

# guard_fail <guard.rule> <message...>
guard_fail() {
  local id="$1"; shift
  echo "STRIDE_GUARD[$id] $*" >&2
  RULE_VIOLATIONS=$((RULE_VIOLATIONS + 1))
}

# guard_infra <guard.what> <message...>
guard_infra() {
  local id="$1"; shift
  echo "STRIDE_INFRA[$id] $*" >&2
  RULE_INFRA=$((RULE_INFRA + 1))
}

# rule_end — the contract's return value.
#
# Infrastructure outranks violation deliberately. A rule that could not read its
# input has not observed a violation; it has failed to look. Reporting that as a
# violation is precisely the "malformed file reads as a clean file" inversion.
rule_end() {
  [ "$RULE_INFRA" -gt 0 ] && return 2
  [ "$RULE_VIOLATIONS" -gt 0 ] && return 1
  return 0
}

# rule_run <fn> — run one named rule under the contract, returning its code.
#
# ## Why this is fail-closed rather than trusting the caller
#
# The first version was three lines: `rule_begin; "$1"; rule_end`. If `$1` named
# nothing, bash printed `command not found`, set no counters, and `rule_end`
# returned 0 — so an UNDEFINED RULE REPORTED SUCCESS. Everything downstream
# reads a 0 from here as "this rule looked at the tree and the tree is clean".
#
# That is the same inversion as every other defect this file was written about:
# a check that never ran is indistinguishable from a check that passed. A typo
# in a rule name, a rule deleted from a guard while the registry still cites it,
# or a rule invoked before the guard finished sourcing would each have been
# silently green.
#
# The registry DOES validate rule names against each guard's inventory. That is
# not enough and is not relied on here. Registry validation only covers names
# that appear in a `reg_case`; it says nothing about a rule invoked directly by
# the causality runner, by the falsification suite, or by a future caller that
# has no registry at all. A primitive whose safety depends on a different file
# choosing to call a validator first is not a safe primitive. So the check is
# HERE, where the invocation happens.
#
# `declare -F` and not `command -v`: a production rule is a shell FUNCTION, so
# `rule_run ls` must fail closed too. `command -v` would find `ls` on the PATH,
# run it, and hand back its exit code as if it were a policy verdict.
#
# ## The two infrastructure outcomes
#
#   STRIDE_INFRA[rulekit.unknown_rule]          no such rule function
#   STRIDE_INFRA[rulekit.invalid_rule_result]   the rule returned outside 0|1|2
#
# The second exists because the contract is a THREE-VALUED one. A rule whose
# body ends on an unguarded `grep` returns whatever that grep returned; a rule
# that runs a missing binary returns 127. Converting those to 2 keeps "policy
# satisfied" reachable only by a rule that deliberately reported it, and keeps
# the value this function returns inside the set every caller switches on.
#
# The VALUE returned for a well-behaved rule is still `rule_end`'s — that is,
# derived from what the rule REPORTED via `guard_fail` and `guard_infra`, not
# from where its last command happened to land. The rule's own status is
# inspected only to reject a code outside the contract, which is a validity
# check on the rule and not a second way to declare a verdict.
rule_run() {
  local fn="${1-}" rrc rc

  if [ -z "$fn" ] || ! declare -F "$fn" >/dev/null 2>&1; then
    echo "STRIDE_INFRA[rulekit.unknown_rule] no production rule named '${fn:-<empty>}'" >&2
    return 2
  fi

  rule_begin
  "$fn"; rrc=$?
  rule_end; rc=$?

  case "$rrc" in
    0|1|2) ;;
    *)
      echo "STRIDE_INFRA[rulekit.invalid_rule_result] rule '$fn' returned $rrc, which is not 0, 1 or 2" >&2
      return 2 ;;
  esac

  return "$rc"
}
