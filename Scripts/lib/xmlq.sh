# Shared shell helpers for calling xmlq.js under the guard-rule contract.
#
# ## Why these exist
#
# `xmlq.js` is three-valued:
#
#   0  valid document, query matched
#   1  valid document, query did NOT match
#   2  malformed document, parser warning/error, invalid invocation, internal
#      failure
#
# Every guard needs the SAME reading of those, and the one that matters is:
# **exit 2 is never absence.** A caller writing `if ! xmlq ...; then` collapses
# 1 and 2 into "not found", so an unparseable manifest reads as "the forbidden
# attribute is not there" — which is precisely backwards, and is how a guard
# passes on a file nobody can parse.
#
# That was a live defect: xmldom throws on fatal errors instead of only calling
# `onError`, so a malformed manifest exited 1 with a stack trace.
#
# ## The second collapse: every exit 2 is not the same exit 2
#
# Failing closed on exit 2 is necessary and not sufficient. A guard that turns
# EVERY exit 2 into a policy rejection now rejects the tree when Node is
# missing, when a path is wrong, when a mode is misspelled — and a mutation
# test cannot tell those from the violation it injected. That is not
# hypothetical either: three checks in `check-android-target.sh` called a mode
# that has never existed, every call exited 2, and all three were dead for their
# entire existence while their self-test read green.
#
# So xmlq names the cause, and this layer routes it:
#
#   STRIDE_XMLQ[invalid_document]    -> a NAMED policy rejection (guard exit 1)
#   STRIDE_XMLQ[invalid_invocation]  -> STRIDE_INFRA, guard exit 2
#   STRIDE_XMLQ[internal_failure]    -> STRIDE_INFRA, guard exit 2
#   any exit outside 0/1/2           -> STRIDE_INFRA, guard exit 2
#
# The rejection a document failure is allowed to become is the guard's own
# `<guard>.<doc>_parses` rule, and nothing else. "This tracked file must be a
# valid document" is a repository policy a guard may enforce; "Node works" is
# not a property of the repository at all.
#
# Callers match the TOKEN, never the prose. Prose is expected to be rewritten.
#
# Requires `rulekit.sh` (guard_fail / guard_infra) to be sourced first.
#
# Every path is quoted, so a project root containing spaces or parentheses
# works. The Windows development checkout lives under such a path.

# Resolve xmlq.js relative to THIS file, not to the caller's cwd.
XMLQ_JS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/xmlq.js"

XMLQ_OUT=""
XMLQ_STATUS=0
XMLQ_REASON=""

# xmlq_call <file> <mode> [args...]
#
# Runs xmlq once and records everything a caller could need: stdout+stderr in
# `XMLQ_OUT`, the exit code in `XMLQ_STATUS`, and — for any non-0/1 outcome —
# the reason token in `XMLQ_REASON`.
#
# Returns xmlq's own exit code, so `case $?` still reads naturally.
xmlq_call() {
  XMLQ_OUT="$(node "$XMLQ_JS" "$@" 2>&1)"
  XMLQ_STATUS=$?
  XMLQ_REASON=""
  case "$XMLQ_STATUS" in
    0 | 1) ;;
    *)
      XMLQ_REASON="$(printf '%s\n' "$XMLQ_OUT" \
        | sed -n 's/.*STRIDE_XMLQ\[\([a-z_][a-z_]*\)\].*/\1/p' | head -1)"
      # An exit 2 carrying no token is xmlq failing in a way xmlq did not
      # anticipate — or not being xmlq at all. Unclassified is INTERNAL, never
      # document: the one outcome that may become a policy rejection has to be
      # stated explicitly by the parser, not inferred by the caller.
      [ -n "$XMLQ_REASON" ] || XMLQ_REASON="internal_failure"
      ;;
  esac
  return "$XMLQ_STATUS"
}

# xmlq_translate_failure <parses-rule-id> <infra-prefix> <what>
#
# The ONLY place an xmlq exit 2 becomes a guard outcome. One place, so the
# "document failures may be rejections, everything else may not" rule is a fact
# about the code rather than a convention each guard re-implements.
xmlq_translate_failure() {
  local parses_id="$1" infra_prefix="$2" what="$3"
  if [ "$XMLQ_REASON" = "invalid_document" ]; then
    guard_fail "$parses_id" "$what
      THE DOCUMENT WAS READ AND IS NOT VALID. This is not an absence -- the file
      is malformed, carries a rejected doctype or entity declaration, or is not
      the document shape this query requires. A malformed tracked file is a
      policy violation: the guard looked, and the tree is wrong.
      $XMLQ_OUT"
    return 1
  fi
  # invalid_invocation, internal_failure, or an exit outside the contract. The
  # guard did not look, so it has observed nothing about the tree and must not
  # claim to have.
  guard_infra "$infra_prefix.$XMLQ_REASON" "xmlq could not answer (exit $XMLQ_STATUS): $what
      $XMLQ_OUT"
  return 2
}

# xmlq_rule_require_match <violation-id> <parses-id> <infra-prefix> <what> \
#                         <file> <mode> [args...]
#
# Requires the query to MATCH. "Valid but absent or the wrong type" is the
# named violation; "could not be read" is routed by reason.
xmlq_rule_require_match() {
  local vid="$1" pid="$2" iprefix="$3" what="$4"; shift 4
  xmlq_call "$@"
  case "$XMLQ_STATUS" in
    0) return 0 ;;
    1)
      guard_fail "$vid" "$what
      (the document parsed; the required value is absent or the wrong type)
      $XMLQ_OUT"
      return 1 ;;
    *) xmlq_translate_failure "$pid" "$iprefix" "$what"; return $? ;;
  esac
}

# xmlq_rule_require_no_match <violation-id> <parses-id> <infra-prefix> <what> \
#                            <file> <mode> [args...]
#
# The forbidden-value case. A parse failure is still a failure: absence can only
# be asserted about a document that was actually read.
xmlq_rule_require_no_match() {
  local vid="$1" pid="$2" iprefix="$3" what="$4"; shift 4
  xmlq_call "$@"
  case "$XMLQ_STATUS" in
    1) return 0 ;;
    0)
      guard_fail "$vid" "$what
      $XMLQ_OUT"
      return 1 ;;
    *) xmlq_translate_failure "$pid" "$iprefix" "$what"; return $? ;;
  esac
}

# xmlq_rule_parses <parses-id> <infra-prefix> <file>
#
# "This tracked file is a readable document", asked WITHOUT a schema opinion.
#
# `parses`, not `keys`. `keys` is a plist mode: handed an Android manifest it
# answered "not a plist" with exit 2 — the same code as "malformed" — and three
# well-formed manifests were reported as unreadable XML. The helper written to
# stop callers collapsing 1 and 2 was collapsing 2 and 2. A question about
# whether a document can be read must not also ask what kind of document it is.
#
# Exit 1 here means "parsed, but there is no document element", which is not
# readable either, so only 0 is a pass.
xmlq_rule_parses() {
  local pid="$1" iprefix="$2" file="$3"
  xmlq_call "$file" parses
  case "$XMLQ_STATUS" in
    0) return 0 ;;
    1)
      guard_fail "$pid" "$file has no document element"
      return 1 ;;
    *) xmlq_translate_failure "$pid" "$iprefix" "$file could not be parsed"; return $? ;;
  esac
}
