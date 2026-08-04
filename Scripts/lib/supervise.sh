# Process-group supervision for anything that spawns guard runs.
#
# ## Why this exists
#
# A cancelled 20-round batch was believed dead and was not. The wrapper shell
# was killed; its descendants were not. Two batches kept running for forty
# minutes, spawning five guard children each, creating fresh temp roots while
# a cleanup was being reported — and racing an `rm` that was trying to remove
# the previous ones. The evidence was two directories that would not delete and
# two more appearing with new names seconds later.
#
# Killing a shell does not kill what it started. On this platform the children
# are reparented and keep going, and `wait` in the dead parent never runs, so
# no EXIT trap fires and no temp root is released.
#
# ## What a supervised run guarantees
#
#   * every child PID and process group is recorded as it is created
#   * EXIT, INT and TERM all route to the same teardown
#   * teardown signals the whole process GROUP, not the leader
#   * teardown WAITS, then escalates to KILL, then verifies
#   * only temp roots created by THIS run are removed — a concurrent run's
#     roots are never touched, which is the property the isolation work exists
#     to provide in the first place
#   * it reports, rather than assumes, that nothing survived
#
# `Scripts/check-supervisor.sh` proves all of that by cancelling a real run.

# Every child this run started, and every temp root it created.
SUP_CHILDREN=""
SUP_ROOTS=""
SUP_ACTIVE=0

# Marker written into each temp root, so ownership is a fact on disk rather
# than an inference from a name. A run only ever deletes roots carrying its own
# marker.
SUP_RUN_ID=""

sup_begin() {
  SUP_RUN_ID="sup-$$-$(date +%s)"
  SUP_ACTIVE=1
  SUP_CHILDREN=""
  SUP_ROOTS=""
  # Own process group, so signalling the group cannot reach the caller's shell.
  trap 'sup_teardown INT;  exit 130' INT
  trap 'sup_teardown TERM; exit 143' TERM
  trap 'sup_teardown EXIT' EXIT
  echo "supervisor: run $SUP_RUN_ID begins (pid $$, pgid $(sup_pgid $$))"
}

sup_pgid() {
  ps -o pgid= -p "$1" 2>/dev/null | tr -d ' ' || echo ""
}

# sup_spawn <cmd...> — start a child in the background and record it.
sup_spawn() {
  "$@" &
  local pid=$!
  SUP_CHILDREN="$SUP_CHILDREN $pid"
  echo "$pid"
}

# sup_track_root <path> — record a temp root as belonging to this run.
sup_track_root() {
  local root="$1"
  [ -d "$root" ] || return 0
  printf '%s\n' "$SUP_RUN_ID" > "$root/.stride-supervisor-run" 2>/dev/null || true
  SUP_ROOTS="$SUP_ROOTS $root"
}

# sup_wait_all — wait for every recorded child, returning nonzero if any failed.
sup_wait_all() {
  local rc=0 p
  for p in $SUP_CHILDREN; do
    wait "$p" 2>/dev/null || rc=1
  done
  return $rc
}

# sup_teardown <reason> — terminate descendants, release roots, verify.
sup_teardown() {
  [ "$SUP_ACTIVE" = "1" ] || return 0
  SUP_ACTIVE=0
  local reason="${1:-EXIT}" p

  # TERM the group first so each guard's own EXIT trap can release its temp
  # root. That is why this escalates rather than going straight to KILL: a
  # KILLed guard leaves its directory behind and the run then has to delete
  # something it did not observe being finished with.
  for p in $SUP_CHILDREN; do
    kill -TERM "$p" 2>/dev/null || true
  done
  local i=0
  while [ $i -lt 20 ]; do
    local alive=0
    for p in $SUP_CHILDREN; do
      kill -0 "$p" 2>/dev/null && alive=1
    done
    [ "$alive" = "0" ] && break
    sleep 0.5
    i=$((i + 1))
  done
  for p in $SUP_CHILDREN; do
    kill -KILL "$p" 2>/dev/null || true
  done
  for p in $SUP_CHILDREN; do
    wait "$p" 2>/dev/null || true
  done

  # ONLY this run's roots, identified by the marker rather than by the glob.
  local root
  for root in $SUP_ROOTS; do
    [ -d "$root" ] || continue
    if [ -f "$root/.stride-supervisor-run" ] &&
       [ "$(cat "$root/.stride-supervisor-run" 2>/dev/null)" = "$SUP_RUN_ID" ]; then
      rm -rf "$root" 2>/dev/null || true
    else
      echo "supervisor: refusing to remove $root -- not marked as ours" >&2
    fi
  done

  sup_verify "$reason"
}

# sup_verify <reason> — report survivors rather than assuming there are none.
sup_verify() {
  local reason="$1" survivors=0 leftover=0 p root
  for p in $SUP_CHILDREN; do
    kill -0 "$p" 2>/dev/null && { echo "supervisor: SURVIVOR pid $p" >&2; survivors=$((survivors + 1)); }
  done
  for root in $SUP_ROOTS; do
    [ -d "$root" ] && { echo "supervisor: LEFTOVER root $root" >&2; leftover=$((leftover + 1)); }
  done
  echo "supervisor: teardown on $reason -- survivors=$survivors leftover-roots=$leftover"
  [ "$survivors" -eq 0 ] && [ "$leftover" -eq 0 ]
}
