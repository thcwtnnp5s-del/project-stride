#!/usr/bin/env bash
# check-supervisor.sh
#
# Cancels a real supervised run and proves nothing survived it.
#
# ## The incident this exists for
#
# A cancelled 20-round batch was believed dead and was not. The wrapper shell
# was killed; its descendants were not. Two batches kept running for forty
# minutes, spawning five guard children each, creating fresh temp roots while a
# cleanup was being reported — and racing an `rm` that was trying to remove the
# previous ones. The visible evidence was two directories that would not delete
# and two more appearing with new names seconds later.
#
# Killing a shell does not kill what it started. The children are reparented and
# keep going, `wait` in the dead parent never runs, so no EXIT trap fires and no
# temp root is released.
#
# ## Why this is a real cancellation and not a mock
#
# Every part of the failure lives in the gap between "the wrapper is gone" and
# "its descendants are gone". A test that called `sup_teardown` directly would
# skip precisely that gap. So this launches a genuine wrapper, lets it build a
# genuine process tree TWO levels deep, signals it the way a user cancelling a
# run does, and then asks the operating system what is left.
#
# ## What is asserted
#
#   * the wrapper launched and reached a known-ready state
#   * it had multiple descendants, at more than one level
#   * it created run-owned temporary roots
#   * cancelling it terminated every descendant
#   * the run WAITED for them rather than assuming
#   * only run-owned roots were removed
#   * an unrelated marked root was left alone
#   * no child PID and no process group of the run survives
#   * no repository file changed
#
# ## No process-name killing
#
# Nothing here — and nothing in `supervise.sh` — selects processes by name.
# `pkill -f sleep` would pass this test and would also kill a colleague's
# unrelated work, and on a CI box sharing a checkout that is the same class of
# damage as the incident. Processes are identified by PARENTAGE (a PPID walk
# from the wrapper) and by PROCESS GROUP, both of which are facts about who
# started what.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/selftest.sh
. "$SCRIPT_DIR/lib/selftest.sh"
# shellcheck source=lib/supervise.sh
. "$SCRIPT_DIR/lib/supervise.sh"

failures=0
checked=0
fail() { echo "  FAILED  $1" >&2; failures=$((failures + 1)); }
ok()   { echo "  ok      $1"; }
assert() { checked=$((checked + 1)); if [ "$1" = "0" ]; then ok "$2"; else fail "$2${3:+ -- $3}"; fi; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/stride-supcheck-XXXXXXXX")"

# An unrelated root, marked as belonging to SOMEONE ELSE'S run. The incident
# involved a cleanup racing a concurrent batch's directories; a teardown that
# globbed `stride-guard-*` would delete this, and that is the isolation property
# the whole temp-root design exists to provide.
FOREIGN_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/stride-guard-XXXXXXXX")"
printf 'sup-somebody-elses-run-99999\n' > "$FOREIGN_ROOT/.stride-supervisor-run"
printf 'do not delete me\n' > "$FOREIGN_ROOT/evidence.txt"

cleanup_all() {
  rm -rf "$WORK" "$FOREIGN_ROOT" 2>/dev/null || true
}
trap cleanup_all EXIT

TREE_BEFORE="$(st_tree_snapshot)"

# ---------------------------------------------------------------------------
# The worker: a process that itself starts a process.
#
# One level would not reproduce the incident. The batch's children were guard
# runs, and the guards started their own children; it was the SECOND level that
# outlived everything and kept creating roots.
# ---------------------------------------------------------------------------
cat > "$WORK/worker.sh" <<'WORKER'
work="$1"
# A grandchild of the wrapper. Recorded so the assertions can name it rather
# than search for it.
bash -c 'while : ; do sleep 1; done' &
grandchild=$!
printf '%s %s\n' "$$" "$grandchild" >> "$work/pids"
while : ; do sleep 1; done
WORKER

# ---------------------------------------------------------------------------
# The wrapper: a real supervised run.
# ---------------------------------------------------------------------------
cat > "$WORK/wrapper.sh" <<'WRAPPER'
set -uo pipefail
scripts="$1"; work="$2"
. "$scripts/lib/supervise.sh"

sup_begin

# Run-owned temporary roots, marked as this run's.
for i in 1 2 3; do
  r="$(mktemp -d "${TMPDIR:-/tmp}/stride-guard-XXXXXXXX")"
  sup_track_root "$r"
  printf '%s\n' "$r" >> "$work/roots"
done

for i in 1 2 3; do
  sup_spawn bash "$work/worker.sh" "$work" >> "$work/children"
done

printf 'ready\n' > "$work/ready"
sup_wait_all
WRAPPER

: > "$WORK/pids"; : > "$WORK/roots"; : > "$WORK/children"

# ---------------------------------------------------------------------------
# Process inspection. By parentage and process group only.
# ---------------------------------------------------------------------------
ps_snapshot() { ps 2>/dev/null; }

pgid_of() { ps_snapshot | awk -v p="$1" '$1==p {print $3; exit}'; }

# Every descendant of a PID, to any depth, from one snapshot.
descendants_of() {
  local snap frontier="$1" next found="" p c
  snap="$(ps_snapshot)"
  while [ -n "$frontier" ]; do
    next=""
    for p in $frontier; do
      for c in $(printf '%s\n' "$snap" | awk -v pp="$p" '$2==pp {print $1}'); do
        case " $found " in *" $c "*) ;; *) found="$found $c"; next="$next $c" ;; esac
      done
    done
    frontier="$next"
  done
  printf '%s' "$found"
}

alive() { kill -0 "$1" 2>/dev/null; }

count_alive() {
  local n=0 p
  for p in $1; do alive "$p" && n=$((n + 1)); done
  echo "$n"
}

echo "supervisor: launching a real run"

# The wrapper gets its OWN process group, so cancelling it cannot reach this
# script's group.
set -m
bash "$WORK/wrapper.sh" "$SCRIPT_DIR" "$WORK" > "$WORK/wrapper.log" 2>&1 &
WRAPPER_PID=$!
set +m
WRAPPER_PGID="$(pgid_of "$WRAPPER_PID")"

# Wait for the run to be fully built. A cancellation that arrives before the
# descendants exist would pass this test by proving nothing.
i=0
while [ $i -lt 60 ] && [ ! -f "$WORK/ready" ]; do sleep 0.5; i=$((i + 1)); done
i=0
while [ $i -lt 60 ] && [ "$(grep -c . "$WORK/pids")" -lt 3 ]; do sleep 0.5; i=$((i + 1)); done
sleep 1

assert "$([ -f "$WORK/ready" ] && echo 0 || echo 1)" \
  "the supervised run reached its ready state"

TRACKED_ROOTS="$(cat "$WORK/roots" 2>/dev/null)"
ROOT_COUNT="$(printf '%s\n' "$TRACKED_ROOTS" | grep -c .)"
assert "$([ "$ROOT_COUNT" -eq 3 ] && echo 0 || echo 1)" \
  "the run created 3 run-owned temporary roots" "created $ROOT_COUNT"

# The descendant set, captured BEFORE cancellation. Cancelling first and then
# looking would mean searching for processes that are already gone, which
# succeeds trivially.
DESCENDANTS="$(descendants_of "$WRAPPER_PID")"
DESC_COUNT="$(printf '%s\n' $DESCENDANTS | grep -c .)"
WORKER_PIDS="$(awk '{print $1}' "$WORK/pids")"
GRANDCHILD_PIDS="$(awk '{print $2}' "$WORK/pids")"

assert "$([ "$DESC_COUNT" -ge 6 ] && echo 0 || echo 1)" \
  "the run has a descendant tree more than one level deep" "$DESC_COUNT descendant(s)"
assert "$([ "$(count_alive "$GRANDCHILD_PIDS")" -eq 3 ] && echo 0 || echo 1)" \
  "3 grandchildren are running before cancellation"

echo "  wrapper pid=$WRAPPER_PID pgid=$WRAPPER_PGID descendants=$DESC_COUNT roots=$ROOT_COUNT"

# ---------------------------------------------------------------------------
# Cancel, the way a user cancelling a run does.
# ---------------------------------------------------------------------------
echo "supervisor: cancelling"
kill -TERM "$WRAPPER_PID" 2>/dev/null

# WAIT for the descendants to go, rather than assuming they have. The incident
# was reported as a completed cleanup while two batches were still running.
i=0
while [ $i -lt 60 ]; do
  [ "$(count_alive "$DESCENDANTS $WRAPPER_PID")" -eq 0 ] && break
  sleep 0.5
  i=$((i + 1))
done
WAITED="$(echo "scale=1; $i / 2" | bc 2>/dev/null || echo "$((i / 2))")"

echo ""
echo "supervisor: after cancellation"

SURVIVORS="$(count_alive "$DESCENDANTS $WRAPPER_PID")"
assert "$([ "$SURVIVORS" -eq 0 ] && echo 0 || echo 1)" \
  "every descendant and the wrapper are gone (waited ${WAITED}s)" "$SURVIVORS survivor(s)"

assert "$([ "$(count_alive "$GRANDCHILD_PIDS")" -eq 0 ] && echo 0 || echo 1)" \
  "no grandchild survived -- the second level is what outlived the incident"
assert "$([ "$(count_alive "$WORKER_PIDS")" -eq 0 ] && echo 0 || echo 1)" \
  "no worker survived"

# No process group of the run survives either. A single reparented process in
# the run's group would keep spawning, which is what produced fresh roots during
# the cleanup.
if [ -n "$WRAPPER_PGID" ]; then
  GROUP_SURVIVORS="$(ps_snapshot | awk -v g="$WRAPPER_PGID" '$3==g {print $1}' | grep -c .)"
else
  GROUP_SURVIVORS=0
fi
assert "$([ "$GROUP_SURVIVORS" -eq 0 ] && echo 0 || echo 1)" \
  "no process in the run's process group survives" "$GROUP_SURVIVORS in pgid $WRAPPER_PGID"

# ---------------------------------------------------------------------------
# Roots
# ---------------------------------------------------------------------------
left=0
for r in $TRACKED_ROOTS; do [ -d "$r" ] && left=$((left + 1)); done
assert "$([ "$left" -eq 0 ] && echo 0 || echo 1)" \
  "every run-owned temporary root was released" "$left left behind"

assert "$([ -d "$FOREIGN_ROOT" ] && [ -f "$FOREIGN_ROOT/evidence.txt" ] && echo 0 || echo 1)" \
  "an unrelated marked root was NOT removed" "$FOREIGN_ROOT"

assert "$([ "$(cat "$FOREIGN_ROOT/.stride-supervisor-run" 2>/dev/null)" = "sup-somebody-elses-run-99999" ] && echo 0 || echo 1)" \
  "the unrelated root's ownership marker is untouched"

# ---------------------------------------------------------------------------
# The repository
# ---------------------------------------------------------------------------
checked=$((checked + 1))
if st_assert_tree_unchanged "$TREE_BEFORE" >/dev/null 2>&1; then
  ok "no repository file changed"
else
  fail "the supervised run modified the repository"
  st_assert_tree_unchanged "$TREE_BEFORE" 2>&1 | head -10 | sed 's/^/            | /' >&2
fi

echo ""
echo "  wrapper log:"
sed 's/^/    | /' "$WORK/wrapper.log" 2>/dev/null | head -10

echo ""
if [ "$failures" -gt 0 ]; then
  echo "supervisor: FAILED -- $failures of $checked assertion(s)" >&2
  exit 1
fi
echo "supervisor: OK -- $checked assertion(s); a cancelled run left no process and no root of its own"
