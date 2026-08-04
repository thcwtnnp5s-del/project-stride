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
# The descendant set as it stood at the moment teardown began. Recorded so that
# "nothing survived" is checked against what was actually there, not against
# whatever happens to be running once the signals have landed.
SUP_DESCENDANTS=""

# Marker written into each temp root, so ownership is a fact on disk rather
# than an inference from a name. A run only ever deletes roots carrying its own
# marker.
SUP_RUN_ID=""

sup_begin() {
  SUP_RUN_ID="sup-$$-$(date +%s)"
  SUP_ACTIVE=1
  SUP_CHILDREN=""
  SUP_ROOTS=""
  trap 'sup_teardown INT;  exit 130' INT
  trap 'sup_teardown TERM; exit 143' TERM
  trap 'sup_teardown EXIT' EXIT
  echo "supervisor: run $SUP_RUN_ID begins (pid $$, pgid $(sup_pgid $$))"
}

# sup_pgid <pid> — the process group of a PID, or empty.
#
# Two implementations because there are two `ps` here. The original was
# `ps -o pgid= -p "$1"`, which is correct on a POSIX `ps` and which the `ps`
# shipped with Git Bash — the platform this repository is developed on —
# rejects outright with `unknown option -- o`. It returned EMPTY on every call.
#
# That is not a cosmetic reporting bug. `sup_teardown` is built on signalling
# process GROUPS, and an empty pgid makes `kill -TERM -""` a no-op that reports
# success, so teardown would have degraded to signalling the direct children
# only — leaving exactly the grandchildren that outlived the original incident.
# MSYS `ps` with no arguments prints PID, PPID and PGID columns, so it is tried
# first and the POSIX form is the fallback.
sup_pgid() {
  local g
  g="$(ps 2>/dev/null | awk -v p="$1" '$1 == p { print $3; exit }')"
  [ -n "$g" ] || g="$(ps -o pgid= -p "$1" 2>/dev/null | tr -d ' ')"
  printf '%s' "$g"
}

# sup_descendants <pid>... — every descendant, to any depth, from one snapshot.
#
# By PARENTAGE. Not by name: `pkill -f` would also kill a colleague's unrelated
# work, and on a CI box sharing a checkout that is the same damage the incident
# caused. Who started what is a fact; a command line is a coincidence.
#
# One `ps` snapshot for the whole walk, so the tree cannot shift underneath it
# and produce a set that was never simultaneously real.
sup_descendants() {
  local snap frontier="$*" next found="" p c
  snap="$(ps 2>/dev/null)"
  while [ -n "$frontier" ]; do
    next=""
    for p in $frontier; do
      for c in $(printf '%s\n' "$snap" | awk -v pp="$p" '$2 == pp { print $1 }'); do
        case " $found " in
          *" $c "*) ;;
          *) found="$found $c"; next="$next $c" ;;
        esac
      done
    done
    frontier="$next"
  done
  printf '%s' "$found"
}

# sup_spawn <cmd...> — start a child in the background and record it.
#
# ## Why job control is switched on around the spawn
#
# In a non-interactive shell, a background job INHERITS the shell's process
# group. `sup_begin` claimed the run had "its own process group, so signalling
# the group cannot reach the caller's shell" — that was never true, and it is
# false in the dangerous direction: signalling the group would have reached the
# supervisor and whatever launched it.
#
# `set -m` makes each background job a process-group LEADER, so its pgid equals
# its pid and its whole subtree — children, grandchildren, anything they start —
# lands in a group that belongs to this child alone. Teardown can then signal
# that group without touching anything else, which is the property that makes
# terminating a tree possible at all.
#
# The option is restored afterwards, because leaving job control on changes how
# the caller's own shell reports and reaps jobs.
# ## Why the PID comes back in a variable and not on stdout
#
# The first version only echoed it. The obvious way to use that is
# `pid="$(sup_spawn ...)"` — and command substitution runs `sup_spawn` in a
# SUBSHELL, so `SUP_CHILDREN` is appended to a copy of the shell that exits
# immediately. The caller gets a correct PID and the supervisor records
# nothing, so teardown has no children to signal and `sup_verify` reports
# `survivors=0` because it is looking at an empty list.
#
# That is the incident's own failure mode reproduced by the tool built to
# prevent it: a cleanup that reports success while the processes are still
# running. `SUP_LAST_PID` lets a caller take the PID without a subshell. The
# echo is kept for callers that redirect rather than capture.
SUP_LAST_PID=""

sup_spawn() {
  local had_m=0
  case "$-" in *m*) had_m=1 ;; esac
  set -m
  "$@" &
  local pid=$!
  [ "$had_m" = "1" ] || set +m
  SUP_CHILDREN="$SUP_CHILDREN $pid"
  SUP_LAST_PID="$pid"
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

  # The descendant set is captured BEFORE any signal, and is what teardown
  # verifies against afterwards. Looking only after signalling would mean
  # searching for processes that are already gone, which succeeds trivially and
  # is how a cleanup gets reported as complete while two batches keep running.
  SUP_DESCENDANTS="$(sup_descendants $SUP_CHILDREN)"

  # TERM the GROUP first, so each guard's own EXIT trap can release its temp
  # root. That is why this escalates rather than going straight to KILL: a
  # KILLed guard leaves its directory behind and the run then has to delete
  # something it did not observe being finished with.
  #
  # The group, not the leader. Killing a shell does not kill what it started —
  # the children are reparented and keep going, `wait` in the dead parent never
  # runs, no EXIT trap fires, and no temp root is released. That is the whole
  # incident. `sup_spawn` put each child in a group of its own precisely so
  # `-$pgid` can reach the subtree without reaching this shell.
  local pg
  for p in $SUP_CHILDREN; do
    pg="$(sup_pgid "$p")"
    [ -n "$pg" ] && [ "$pg" != "$(sup_pgid $$)" ] && kill -TERM -"$pg" 2>/dev/null
    kill -TERM "$p" 2>/dev/null || true
  done
  # Anything the group signal did not reach, by parentage.
  for p in $SUP_DESCENDANTS; do
    kill -TERM "$p" 2>/dev/null || true
  done

  # WAIT, rather than assume. The incident was reported as a completed cleanup.
  local i=0
  while [ $i -lt 20 ]; do
    local alive=0
    for p in $SUP_CHILDREN $SUP_DESCENDANTS; do
      kill -0 "$p" 2>/dev/null && alive=1
    done
    [ "$alive" = "0" ] && break
    sleep 0.5
    i=$((i + 1))
  done

  # Escalate to KILL, again by group and then by PID, and include anything that
  # appeared since the first snapshot: a surviving descendant may have started
  # something after the TERM.
  for p in $SUP_CHILDREN; do
    pg="$(sup_pgid "$p")"
    [ -n "$pg" ] && [ "$pg" != "$(sup_pgid $$)" ] && kill -KILL -"$pg" 2>/dev/null
  done
  for p in $SUP_DESCENDANTS $(sup_descendants $SUP_CHILDREN) $SUP_CHILDREN; do
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
  # Children AND the descendants recorded at teardown. Checking only the direct
  # children is what let two batches keep running while a cleanup was reported
  # as complete: the processes that survived were never in that list.
  for p in $SUP_CHILDREN $SUP_DESCENDANTS; do
    kill -0 "$p" 2>/dev/null && { echo "supervisor: SURVIVOR pid $p" >&2; survivors=$((survivors + 1)); }
  done
  for root in $SUP_ROOTS; do
    [ -d "$root" ] && { echo "supervisor: LEFTOVER root $root" >&2; leftover=$((leftover + 1)); }
  done
  echo "supervisor: teardown on $reason -- survivors=$survivors leftover-roots=$leftover"
  [ "$survivors" -eq 0 ] && [ "$leftover" -eq 0 ]
}
