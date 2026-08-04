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

# rule_run <fn> — run one named rule under the contract, echoing its code.
rule_run() {
  rule_begin
  "$1"
  rule_end
}
