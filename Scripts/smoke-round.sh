#!/usr/bin/env bash
# smoke-round.sh
#
# ONE round: all five registry-driven self-tests, concurrently, under the
# supervisor, with the evidence recorded rather than assumed.
#
# ## What a round is for
#
# Each guard's `--self-test` already proves its own cases. Running the five
# together proves the thing none of them can prove alone: that they do not
# interfere. Guards used to inject their violations into the LIVE working tree
# and restore afterwards, and three separate agents hit the consequence within
# one session — run two self-tests at once and they clobber each other, leaving
# probe files behind and failing runs for reasons that had nothing to do with
# the tree. CI would have hit it the moment two jobs shared a checkout.
#
# So a round is deliberately concurrent. Sequential rounds would pass whether or
# not the isolation works.
#
# ## Why it is supervised
#
# A cancelled batch was believed dead and was not: the wrapper was killed, its
# descendants were reparented and kept running for forty minutes, spawning
# guard children and creating fresh temp roots while a cleanup was being
# reported. Anything that starts five concurrent guard runs must be able to
# stop five concurrent guard runs, and `Scripts/lib/supervise.sh` is that.
# `Scripts/check-supervisor.sh` proves the stopping works by cancelling a real
# run; this uses it for a round that is allowed to finish.
#
# ## What is recorded
#
#   * each guard's result
#   * the child PID and process-group inventory
#   * every unique temporary root observed while the round ran
#   * duration, per guard and overall
#   * a repository fingerprint before and after
#   * a leftover-root check
#   * a surviving-process check
#
# The temp roots are SAMPLED during the run rather than asked for afterwards.
# By the time a round finishes every root has been released, so a check made at
# the end can only confirm that nothing is left — it cannot show that five
# distinct roots ever existed, which is the isolation claim itself.
#
# Usage:
#   ./Scripts/smoke-round.sh            # one round
#   ./Scripts/smoke-round.sh --out DIR  # where the evidence goes

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/selftest.sh
. "$SCRIPT_DIR/lib/selftest.sh"
# shellcheck source=lib/supervise.sh
. "$SCRIPT_DIR/lib/supervise.sh"

OUT_DIR="$REPO_ROOT/build/smoke"
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT_DIR="${2:-}"; shift 2 ;;
    *) echo "STRIDE_INFRA[smoke.usage] unknown option: $1" >&2; exit 2 ;;
  esac
done

if ! mkdir -p "$OUT_DIR" 2>/dev/null || [ ! -w "$OUT_DIR" ]; then
  echo "STRIDE_INFRA[smoke.output_unwritable] cannot write evidence to: $OUT_DIR" >&2
  exit 2
fi

# The five guards whose self-tests are registry-driven. Named explicitly, so a
# sixth cannot join the registry and quietly stay out of the round.
ROUND_GUARDS="
check-android-target.sh
check-ios-target.sh
check-origin-privacy.sh
check-single-writer.sh
check-step-model.sh
"

# ---------------------------------------------------------------------------
# Repository fingerprint
#
# Every tracked file's working-tree CONTENT, not just the file list. A self-test
# that edited a file and restored it imperfectly leaves the same `git status`
# and different bytes, and the whole point of a round is to catch exactly that.
# ---------------------------------------------------------------------------
repo_fingerprint() {
  ( cd "$REPO_ROOT" && git ls-files -z 2>/dev/null | xargs -0 sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1 )
}

failures=0
fail() { echo "  FAILED  $1" >&2; failures=$((failures + 1)); }
ok()   { echo "  ok      $1"; }

EVIDENCE="$OUT_DIR/round.txt"
: > "$EVIDENCE"
record() { printf '%s\n' "$1" | tee -a "$EVIDENCE"; }

TREE_BEFORE="$(st_tree_snapshot)"
FP_BEFORE="$(repo_fingerprint)"

record "smoke round: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
record "  repository fingerprint BEFORE: $FP_BEFORE"

# `sup_begin` is called plainly: not piped, not captured.
#
# Both `sup_begin | tee` and `x="$(sup_begin)"` run it in a SUBSHELL, and the
# EXIT trap it installs then fires the instant that subshell ends -- tearing the
# run down before a single guard has been launched, and leaving `SUP_ACTIVE`,
# `SUP_RUN_ID` and `SUP_CHILDREN` set on a shell that no longer exists. The
# first version of this file did exactly that, and the evidence it produced was
# `teardown on EXIT -- survivors=0` printed before the first guard started.
sup_begin
record "  supervisor run: $SUP_RUN_ID (pid $$, pgid $(sup_pgid $$))"

ROUND_START="$(date +%s)"

# ---------------------------------------------------------------------------
# Launch, concurrently
# ---------------------------------------------------------------------------
# The redirection lives INSIDE this function rather than on the `sup_spawn`
# call. `sup_spawn` runs `"$@" &` and then echoes the child's PID on stdout, so
# a redirect written on the call site captures that PID into the guard's log
# instead of into the variable, and the round loses the inventory it exists to
# record.
run_guard_logged() {
  bash "$SCRIPT_DIR/$1" --self-test > "$OUT_DIR/$1.log" 2>&1
}

CHILD_PIDS=""
for g in $ROUND_GUARDS; do
  # `SUP_LAST_PID`, not `pid="$(sup_spawn ...)"`. Command substitution is a
  # subshell, so the supervisor would record the child on a shell that exits
  # immediately -- leaving teardown with nothing to signal and `sup_verify`
  # reporting `survivors=0` because its list is empty.
  sup_spawn run_guard_logged "$g" >/dev/null
  pid="$SUP_LAST_PID"
  CHILD_PIDS="$CHILD_PIDS $pid"
  record "  launched $g  pid=$pid pgid=$(sup_pgid "$pid")"
done

# ---------------------------------------------------------------------------
# Sample the temp roots while the round runs.
#
# A sampler, not a single look: roots are created and released continuously, and
# the union over the run is what shows that five concurrent guards each worked
# somewhere of their own.
# ---------------------------------------------------------------------------
ROOTS_SEEN="$OUT_DIR/roots-observed.txt"
: > "$ROOTS_SEEN"

sample_roots() {
  ls -d "${TMPDIR:-/tmp}"/stride-guard-* 2>/dev/null >> "$ROOTS_SEEN" || true
}

alive_any() {
  local p
  for p in $CHILD_PIDS; do kill -0 "$p" 2>/dev/null && return 0; done
  return 1
}

count_words() { printf '%s\n' $1 | grep -c . 2>/dev/null || true; }

PEAK_PROCS=0
while alive_any; do
  sample_roots
  n="$(count_words "$(sup_descendants $CHILD_PIDS)")"
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  [ "$n" -gt "$PEAK_PROCS" ] && PEAK_PROCS="$n"
  sleep 1
done
sample_roots

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
record ""
record "  guard results:"
round_failures=0
for g in $ROUND_GUARDS; do
  line="$(grep -E 'self-test OK|SELF-TEST FAILED|CASE FAIL' "$OUT_DIR/$g.log" 2>/dev/null | head -1)"
  if grep -q 'self-test OK' "$OUT_DIR/$g.log" 2>/dev/null; then
    record "    PASS  $g -- $line"
  else
    record "    FAIL  $g -- ${line:-no self-test verdict in the log}"
    round_failures=$((round_failures + 1))
  fi
done

# `sup_wait_all` collects the exit statuses. It runs after the sampler so the
# round's own reaping cannot race the sampling loop.
sup_wait_all; WAIT_RC=$?

ROUND_END="$(date +%s)"
DURATION=$((ROUND_END - ROUND_START))

UNIQUE_ROOTS="$(LC_ALL=C sort -u "$ROOTS_SEEN" | grep -c . || echo 0)"
LEFTOVER=0
while IFS= read -r r; do
  [ -n "$r" ] || continue
  [ -d "$r" ] && { record "    LEFTOVER root: $r"; LEFTOVER=$((LEFTOVER + 1)); }
done < <(LC_ALL=C sort -u "$ROOTS_SEEN")

SURVIVORS=0
for p in $CHILD_PIDS $(sup_descendants $CHILD_PIDS); do
  kill -0 "$p" 2>/dev/null && { record "    SURVIVOR pid $p"; SURVIVORS=$((SURVIVORS + 1)); }
done

FP_AFTER="$(repo_fingerprint)"

record ""
record "  duration:                 ${DURATION}s"
record "  child PIDs:              $CHILD_PIDS"
record "  peak descendant count:    $PEAK_PROCS"
record "  unique temp roots seen:   $UNIQUE_ROOTS"
record "  leftover roots:           $LEFTOVER"
record "  surviving processes:      $SURVIVORS"
record "  repository fingerprint AFTER:  $FP_AFTER"

echo ""
echo "smoke round: assertions"

[ "$round_failures" -eq 0 ] && ok "all five self-tests passed concurrently" \
  || fail "$round_failures of 5 self-tests failed"

[ "$WAIT_RC" -eq 0 ] && ok "every child exited 0" \
  || fail "at least one child exited nonzero"

# Five concurrent guards must have worked in at least five distinct roots. One
# shared root would be the pre-isolation behaviour that made concurrent runs
# clobber each other.
[ "$UNIQUE_ROOTS" -ge 5 ] && ok "$UNIQUE_ROOTS distinct temporary roots were in use" \
  || fail "only $UNIQUE_ROOTS distinct temporary root(s) observed -- the guards may be sharing one"

[ "$LEFTOVER" -eq 0 ] && ok "no temporary root outlived the round" \
  || fail "$LEFTOVER temporary root(s) left behind"

[ "$SURVIVORS" -eq 0 ] && ok "no child process or descendant survived" \
  || fail "$SURVIVORS process(es) survived the round"

[ "$FP_BEFORE" = "$FP_AFTER" ] && ok "the repository is byte-for-byte unchanged" \
  || fail "the repository fingerprint changed: $FP_BEFORE -> $FP_AFTER"

if st_assert_tree_unchanged "$TREE_BEFORE" >/dev/null 2>&1; then
  ok "the working tree is unchanged"
else
  fail "the working tree was modified by the round"
  st_assert_tree_unchanged "$TREE_BEFORE" 2>&1 | head -10 | sed 's/^/            | /' >&2
fi

echo ""
echo "  evidence: $EVIDENCE"
if [ "$failures" -gt 0 ]; then
  echo "smoke-round: FAILED -- $failures assertion(s)" >&2
  exit 1
fi
echo "smoke-round: OK -- five concurrent self-tests in ${DURATION}s, nothing left behind"
