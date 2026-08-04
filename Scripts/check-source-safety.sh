#!/usr/bin/env bash
# check-source-safety.sh
#
# Proves that SOURCING a converted guard defines its rules and does nothing
# else.
#
# ## Why this has to be checked rather than intended
#
# The registry-driven self-test and the causality runner both work by sourcing a
# guard and calling ONE named rule against a mutated copy. That only works if
# sourcing is inert. Every guard in this repository used to be the opposite: the
# old `check-ios-target.sh` ran `set -uo pipefail`, parsed `$@`, `cd`'d into the
# project root and executed every check at load time. Sourcing it moved the
# caller's shell, applied shell options to the caller, and ran the whole guard —
# so a runner that sourced it would have had its own working directory changed
# out from under it before it called anything, and any rule it then invoked
# would have been measuring the runner's environment, not the tree.
#
# Both failure modes here are silent. A `cd` at load time does not error; it
# makes every later relative path resolve somewhere else. A `trap ... EXIT`
# installed at load time does not error; it fires when the RUNNER exits, and
# deletes a directory the runner still wanted. Neither shows up in a guard's own
# self-test, because a guard is never sourced by itself.
#
# ## What is asserted, per guard
#
#   * sourcing produces NO output      — no rule executed
#   * sourcing does not exit           — a DONE marker is reached afterwards
#   * the working directory is unchanged
#   * `$-`, `set -o` and `shopt` are unchanged
#   * no trap is installed, on any signal
#   * no temp root is created
#   * the guard's rules and `guard_main` are defined afterwards — so "nothing
#     happened" is not being satisfied by the file failing to load
#
# Guards that have not been converted yet are listed as PENDING. They are named
# explicitly, so a new guard cannot avoid this check by simply not appearing.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Converted to the named-rule contract. These must be source-safe.
SOURCE_SAFE_GUARDS="
check-android-target.sh
check-ios-target.sh
check-origin-privacy.sh
check-single-writer.sh
check-step-model.sh
"

# Not yet converted. Sourcing these still executes them, which is the defect
# the conversion removes; they are listed so the set of guards is complete and
# a conversion cannot be forgotten silently.
PENDING_GUARDS="
check-backup-exclusions.sh
check-core-purity.sh
check-dependency-policy.sh
"

# Guards' own test harnesses are not guards and are never sourced by a runner.
NOT_GUARDS="
check-causality-framework.sh
check-guard-parsers.sh
check-rulekit.sh
check-source-safety.sh
check-supervisor.sh
"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/stride-srcsafe-XXXXXXXX")"
trap 'rm -rf "$WORK"' EXIT

failures=0
checked=0

fail() { echo "  FAILED  $1" >&2; failures=$((failures + 1)); }
ok()   { echo "  ok      $1"; }

# The probe. Runs in its OWN bash so that anything the guard does to the shell
# is observed rather than inflicted on this script.
#
# `.` is called directly and NOT inside a command substitution: a subshell would
# hide exactly the effects being measured — a `cd` or a `trap` inside `$( )`
# never reaches the caller, so the probe would report every guard as clean.
PROBE="$WORK/probe.sh"
cat > "$PROBE" <<'PROBE_EOF'
guard="$1"; outfile="$2"

before_pwd="$PWD"
before_dash="$-"
before_seto="$(set -o)"
before_shopt="$(shopt -p)"
before_traps="$(trap -p)"
before_roots="$(ls -d "${TMPDIR:-/tmp}"/stride-guard-* 2>/dev/null | sort | tr '\n' ' ')"

# shellcheck disable=SC1090
. "$guard" > "$outfile" 2>&1
rc=$?

echo "RC=$rc"
[ "$PWD" = "$before_pwd" ] && echo "PWD=same" || echo "PWD=CHANGED:$before_pwd->$PWD"
[ "$-" = "$before_dash" ] && echo "DASH=same" || echo "DASH=CHANGED:$before_dash->$-"
[ "$(set -o)" = "$before_seto" ] && echo "SETO=same" || echo "SETO=CHANGED"
[ "$(shopt -p)" = "$before_shopt" ] && echo "SHOPT=same" || echo "SHOPT=CHANGED"
[ "$(trap -p)" = "$before_traps" ] && echo "TRAPS=same" || echo "TRAPS=INSTALLED:$(trap -p | tr '\n' ';')"
after_roots="$(ls -d "${TMPDIR:-/tmp}"/stride-guard-* 2>/dev/null | sort | tr '\n' ' ')"
[ "$after_roots" = "$before_roots" ] && echo "ROOTS=same" || echo "ROOTS=CREATED"

# Proves the file actually loaded. "Nothing happened" is trivially satisfiable
# by a file that failed to parse.
type -t guard_main >/dev/null 2>&1 && echo "GUARD_MAIN=defined" || echo "GUARD_MAIN=missing"
type -t run_all_rules >/dev/null 2>&1 && echo "RUN_ALL=defined" || echo "RUN_ALL=missing"
echo "RULES=$(declare -F | awk '{print $3}' | grep -c '^rule_')"

# Reached only if sourcing did not exit.
echo "DONE"
PROBE_EOF

check_guard() {
  local name="$1" path="$SCRIPT_DIR/$1"
  local report="$WORK/report.txt" sourced_out="$WORK/sourced.txt"
  checked=$((checked + 1))

  if [ ! -f "$path" ]; then
    fail "$name: not found"
    return
  fi

  # A fresh, minimal environment each time. `cd "$WORK"` first, so a `cd` inside
  # the guard is visible as a change away from a directory the guard has no
  # reason to know about.
  ( cd "$WORK" && bash "$PROBE" "$path" "$sourced_out" ) > "$report" 2>&1

  local bad=0
  grep -q '^DONE$'            "$report" || { fail "$name: sourcing EXITED the shell"; bad=1; }
  grep -q '^RC=0$'            "$report" || { fail "$name: sourcing returned $(grep '^RC=' "$report" | head -1)"; bad=1; }
  grep -q '^PWD=same$'        "$report" || { fail "$name: sourcing changed the working directory -- $(grep '^PWD=' "$report")"; bad=1; }
  grep -q '^DASH=same$'       "$report" || { fail "$name: sourcing changed shell options -- $(grep '^DASH=' "$report")"; bad=1; }
  grep -q '^SETO=same$'       "$report" || { fail "$name: sourcing changed 'set -o' options"; bad=1; }
  grep -q '^SHOPT=same$'      "$report" || { fail "$name: sourcing changed shopt options"; bad=1; }
  grep -q '^TRAPS=same$'      "$report" || { fail "$name: sourcing installed a trap -- $(grep '^TRAPS=' "$report")"; bad=1; }
  grep -q '^ROOTS=same$'      "$report" || { fail "$name: sourcing created a temp root"; bad=1; }
  grep -q '^GUARD_MAIN=defined$' "$report" || { fail "$name: guard_main is not defined after sourcing"; bad=1; }
  grep -q '^RUN_ALL=defined$'    "$report" || { fail "$name: run_all_rules is not defined after sourcing"; bad=1; }

  local rules
  rules="$(sed -n 's/^RULES=//p' "$report" | head -1)"
  if [ -z "$rules" ] || [ "$rules" -lt 2 ]; then
    fail "$name: only ${rules:-0} rule_* function(s) defined after sourcing"
    bad=1
  fi

  if [ -s "$sourced_out" ]; then
    fail "$name: sourcing produced output -- a rule ran at load time:"
    head -5 "$sourced_out" | sed 's/^/            | /' >&2
    bad=1
  fi

  [ "$bad" -eq 0 ] && ok "$name: inert when sourced, $rules rules defined"
}

echo "source-safety: converted guards"
for g in $SOURCE_SAFE_GUARDS; do check_guard "$g"; done

echo ""
echo "source-safety: not yet converted (sourcing these still executes them)"
for g in $PENDING_GUARDS; do
  if [ -f "$SCRIPT_DIR/$g" ]; then
    echo "  PENDING $g"
  else
    fail "$g is listed as pending but does not exist"
  fi
done

# Completeness: every check-*.sh is either converted, pending, or explicitly not
# a guard. A file in none of the three lists is unclassified, and an
# unclassified guard is one nobody decided about.
echo ""
for f in "$SCRIPT_DIR"/check-*.sh; do
  b="$(basename "$f")"
  # The lists are newline-separated; word-splitting them here makes the
  # membership test a space-delimited match rather than a line-delimited one.
  # shellcheck disable=SC2086
  case " $(echo $SOURCE_SAFE_GUARDS $PENDING_GUARDS $NOT_GUARDS) " in
    *" $b "*) ;;
    *) fail "$b is not classified -- add it to SOURCE_SAFE_GUARDS or PENDING_GUARDS" ;;
  esac
done

echo ""
if [ "$failures" -gt 0 ]; then
  echo "source-safety: FAILED -- $failures problem(s) across $checked converted guard(s)" >&2
  exit 1
fi
echo "source-safety: OK -- $checked converted guard(s) are inert when sourced"
