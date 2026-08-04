# The mutation registry: infrastructure and validation.
#
# ## Why there is exactly one of these
#
# Each guard used to carry its own inventory of injections inside its
# `--self-test`. That is a second source of truth, and it drifted immediately:
# I reported the iOS guard as having 6 injections when it has 17, and an
# instruction was written against the wrong number. Nothing in the repository
# could have caught that, because the only place the count existed was a string
# in an `echo`.
#
# So both `--self-test` and `--causality` consume THIS registry, and the totals
# are derived from it rather than written down anywhere. A count that is
# computed cannot disagree with the thing it counts.
#
# ## What a case is
#
# A case is a single, reversible edit to a copied tree, together with the exact
# reason the guard is expected to give about it. Fields:
#
#   id        stable, unique, never renumbered — it appears in reports
#   guard     which guard owns it
#   rule      the NAMED production rule function it exercises
#   expect    `reject` or `accept`
#   diag      for reject: an extended regex the guard's own diagnostic must
#             match. Not "it failed" — WHY it failed.
#   files     the exact set of files the mutation is expected to change,
#             relative to the isolated root. Verified, not trusted.
#   apply     a function that performs exactly one mutation
#
# There is deliberately no `revert` field. Restoration is generic: the declared
# files are backed up before `apply` and restored from those bytes afterwards,
# then compared with `cmp`. A hand-written revert is another thing that can be
# subtly wrong, and "subtly wrong revert" is indistinguishable from "the next
# case passed on leftovers".

REG_IDS=""

# reg_case <id> <guard> <rule> <expect> <diag-regex> <files-csv> <apply-fn>
reg_case() {
  local id="$1" guard="$2" rule="$3" expect="$4" diag="$5" files="$6" apply="$7"
  REG_IDS="$REG_IDS $id"
  eval "REG_${id}_guard=\$guard"
  eval "REG_${id}_rule=\$rule"
  eval "REG_${id}_expect=\$expect"
  eval "REG_${id}_diag=\$diag"
  eval "REG_${id}_files=\$files"
  eval "REG_${id}_apply=\$apply"
}

reg_get() { eval "printf '%s' \"\${REG_${1}_$2}\""; }

reg_ids_for_guard() {
  local want="$1" id
  for id in $REG_IDS; do
    [ "$(reg_get "$id" guard)" = "$want" ] && printf '%s\n' "$id"
  done
}

reg_count()             { printf '%s\n' $REG_IDS | grep -c . ; }
reg_count_for_guard()   { reg_ids_for_guard "$1" | grep -c . ; }
reg_count_expect()      {
  local want="$1" id n=0
  for id in $REG_IDS; do
    [ "$(reg_get "$id" expect)" = "$want" ] && n=$((n + 1))
  done
  echo "$n"
}

# ---------------------------------------------------------------------------
# Validation. Every one of these has a failure it is preventing.
# ---------------------------------------------------------------------------
reg_validate() {
  local known_guards="$1" bad=0 id seen=""

  for id in $REG_IDS; do
    # Duplicate IDs: two cases reporting under one name means one of them is
    # invisible in every report, including a failure report.
    case " $seen " in
      *" $id "*) echo "registry: DUPLICATE case id '$id'" >&2; bad=$((bad + 1)) ;;
    esac
    seen="$seen $id"

    local guard rule expect diag files apply
    guard="$(reg_get "$id" guard)"
    rule="$(reg_get "$id" rule)"
    expect="$(reg_get "$id" expect)"
    diag="$(reg_get "$id" diag)"
    files="$(reg_get "$id" files)"
    apply="$(reg_get "$id" apply)"

    case " $known_guards " in
      *" $guard "*) ;;
      *) echo "registry: $id names unknown guard '$guard'" >&2; bad=$((bad + 1)) ;;
    esac

    [ -n "$rule" ] || { echo "registry: $id declares no production rule" >&2; bad=$((bad + 1)); }

    # A missing changed-file declaration means restoration cannot be verified,
    # and an unverified restoration is how one case passes on the previous
    # case's leftovers.
    [ -n "$files" ] || { echo "registry: $id declares no changed-file set" >&2; bad=$((bad + 1)); }

    # The mutation must live in the registry. A case whose apply function is
    # defined inside a guard is a second inventory again.
    if ! command -v "$apply" >/dev/null 2>&1; then
      echo "registry: $id apply function '$apply' is not defined" >&2; bad=$((bad + 1))
    fi

    case "$expect" in
      reject)
        # A reject case with no expected diagnostic proves only that something
        # went wrong -- which is what a missing parser mode, an incomplete copy
        # and a bootstrap failure all look like.
        [ -n "$diag" ] || { echo "registry: reject case $id has no expected diagnostic" >&2; bad=$((bad + 1)); }
        ;;
      accept)
        # An accept case carrying a rejection diagnostic is a contradiction:
        # it says "this must pass" and "this is the error it must give".
        [ -z "$diag" ] || { echo "registry: accept case $id declares a rejection diagnostic" >&2; bad=$((bad + 1)); }
        ;;
      *)
        echo "registry: $id has invalid expectation '$expect' (reject|accept)" >&2; bad=$((bad + 1))
        ;;
    esac
  done

  if [ "$bad" -ne 0 ]; then
    echo "registry: INVALID -- $bad problem(s)" >&2
    return 1
  fi
  return 0
}

reg_summary() {
  local g
  echo "registry: $(reg_count) cases"
  for g in $1; do
    printf '  %-22s %s\n' "$g" "$(reg_count_for_guard "$g")"
  done
  echo "  reject : $(reg_count_expect reject)"
  echo "  accept : $(reg_count_expect accept)"
}
