# Shared shell helpers for calling xmlq.js.
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
# Anything other than 0, 1 or 2 is an unexpected hard failure — a crash, a
# missing interpreter, an OOM — and is treated as a guard failure, not as data.
#
# Every path is quoted, so a project root containing spaces or parentheses
# works. The Windows development checkout lives under such a path.

# Resolve xmlq.js relative to THIS file, not to the caller's cwd.
XMLQ_JS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/xmlq.js"

# _xmlq_run <file> <mode> [args...] -> stdout, returns xmlq's exit code
_xmlq_run() {
  node "$XMLQ_JS" "$@"
}

# xmlq_require_match <fail-fn> <what> <file> <mode> [args...]
#
# Requires the query to MATCH. Calls <fail-fn> with a message when it does not,
# and distinguishes "valid but absent" from "could not be read".
xmlq_require_match() {
  local failfn="$1" what="$2"; shift 2
  local out status
  out="$(_xmlq_run "$@" 2>&1)"
  status=$?
  case "$status" in
    0) return 0 ;;
    1) "$failfn" "$what
      (the document parsed; the required value is absent or the wrong type)
      $out" ;;
    2) "$failfn" "$what
      THE DOCUMENT COULD NOT BE READ. This is not an absence -- the file is
      malformed, carries a rejected doctype or entity, or the parser reported a
      warning. Failing closed.
      $out" ;;
    *) "$failfn" "$what
      xmlq exited $status, which is not part of its contract (0/1/2). Treating
      as a hard failure.
      $out" ;;
  esac
  return 1
}

# xmlq_require_no_match <fail-fn> <what> <file> <mode> [args...]
#
# Requires the query NOT to match — the forbidden-value case. A parse error is
# still a failure: absence can only be asserted about a document that was read.
xmlq_require_no_match() {
  local failfn="$1" what="$2"; shift 2
  local out status
  out="$(_xmlq_run "$@" 2>&1)"
  status=$?
  case "$status" in
    1) return 0 ;;
    0) "$failfn" "$what
      $out" ;;
    2) "$failfn" "$what
      THE DOCUMENT COULD NOT BE READ, so its absence cannot be asserted. A
      malformed file is not a clean file. Failing closed.
      $out" ;;
    *) "$failfn" "$what
      xmlq exited $status, which is not part of its contract (0/1/2).
      $out" ;;
  esac
  return 1
}

# xmlq_parses <file> — 0 if the document is readable at all.
#
# Uses the `parses` mode, which has no opinion about what KIND of document it
# is. This asked for `keys` — a plist mode — and so reported every well-formed
# Android manifest as unreadable XML, because "not a plist" and "malformed"
# share exit 2. The helper written to stop callers collapsing 1 and 2 was
# collapsing 2 and 2.
#
# The distinction still has to be made by exit code, not by output: exit 1 here
# means "parsed, but there is no document element", which is not readable
# either, so only 0 is a pass.
xmlq_parses() {
  _xmlq_run "$1" parses >/dev/null 2>&1
  [ $? -eq 0 ]
}
