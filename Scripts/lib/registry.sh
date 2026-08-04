# The shared case registry: schema, validation, and the generic case runner.
#
# ## Why there is exactly one of these
#
# Each guard used to carry its own inventory of injections inside its
# `--self-test`. That is a second source of truth, and it drifted immediately:
# the iOS guard was reported as having 6 cases when it has 17, and an
# instruction was written against the wrong number. Nothing in the repository
# could have caught that, because the only place the count existed was a string
# in an `echo`.
#
# So a guard's `--self-test` is now `reg_selftest`, and it consumes THIS
# registry. Every total is DERIVED from registry contents rather than written
# down anywhere. A count that is computed cannot disagree with the thing it
# counts.
#
# ## What a case is
#
# A case is one reversible operation on a copied tree, together with the exact
# outcome the guard is required to produce. Fields:
#
#   id           stable, unique, never renumbered -- it appears in reports
#   guard        which guard owns it
#   rule         the NAMED production rule it exercises
#   expect       reject | accept | infra
#   form         mutation | invocation
#   attribution  complete_guard | named_rule
#   diag         extended regex the diagnostic must match. Not "it failed" --
#                WHY it failed, matched on the stable ID and never the prose
#   forbid       extended regex the diagnostic must NOT match (optional)
#   files        for a mutation: the exact set of isolated-root-relative paths
#                the operation is expected to change. Verified, not trusted
#   apply        for a mutation: a function performing exactly one operation
#   invoke       for an invocation: a function running the guard some other way
#
# ### The three expectation classes
#
#   reject   guard exit 1 and an exact STRIDE_GUARD diagnostic. A policy
#            rejection: the guard looked, and the tree is wrong
#   accept   guard exit 0 and NO violation diagnostic
#   infra    guard exit 2 and an exact STRIDE_INFRA diagnostic
#
# `reject` refuses exit 2 and refuses any STRIDE_INFRA line in the output. That
# is the whole point: a guard that rejects everything -- because a parser mode
# is misspelled, because Node is missing, because the copied tree is incomplete
# -- rejects every injection too, and reads exactly like a working one to a test
# that only asks whether the exit code was nonzero. Three checks in
# `check-android-target.sh` were dead for their entire existence that way.
#
# ### The two case forms
#
#   mutation    modifies a declared isolated-root path set
#   invocation  exercises argument handling, a missing root, or inspection
#               coverage without touching a file
#
# ### Attribution
#
#   complete_guard  the COMPLETE guard must reject with the case's diagnostic.
#                   This is the default and what a developer actually sees
#   named_rule      additionally invokes the named production rule ALONE
#                   against the same mutated root. Reserved for structurally
#                   over-determined cases, where some other rule of the same
#                   guard fires first and exact attribution through the complete
#                   guard is impossible. It is NOT for cases where complete-
#                   guard attribution is merely inconvenient
#
# ## Restoration
#
# There is deliberately no `revert` field. Restoration is generic: the declared
# paths are backed up with `cp -a` before `apply` and put back from those bytes
# afterwards -- preserving existence, exact bytes, file type, mode and symlink
# target -- and then the WHOLE isolated root is fingerprinted and compared
# against its fingerprint from before the case ran. A hand-written revert is
# another thing that can be subtly wrong, and "subtly wrong revert" is
# indistinguishable from "the next case passed on the previous case's
# leftovers".
#
# Requires `rulekit.sh` and `selftest.sh` to be sourced first.

# ---------------------------------------------------------------------------
# Storage
#
# Loading this file and the case inventory must be free of side effects -- the
# guards source both at load time and `check-source-safety.sh` asserts that
# sourcing a guard produces no output at all. So a malformed declaration is
# RECORDED here and reported by `reg_validate`, never echoed at load time.
# ---------------------------------------------------------------------------
REG_IDS=""
REG_GUARDS=""
REG_LOAD_ERRORS=""

REG_FIELDS="id guard rule expect form attribution diag forbid files apply invoke"

reg_load_error() { REG_LOAD_ERRORS="${REG_LOAD_ERRORS}registry: $1
"; }

# reg_guard <guard-id> <rule-list>
#
# Declares a guard and the complete inventory of its named production rules.
# `reg_selftest` asserts this matches the guard's OWN rule list, so the two
# cannot drift apart in the direction that would make "unknown production rule
# ID" unenforceable.
reg_guard() {
  local guard="$1" rules
  # Normalised to single spaces. The lists are written one rule per line for
  # readability, and a newline-separated list makes the membership test below a
  # line-delimited match rather than the space-delimited one it looks like.
  # shellcheck disable=SC2086
  rules=" $(printf '%s ' $2) "
  REG_GUARDS="$REG_GUARDS $guard"
  eval "REG_RULES_$(reg_slug "$guard")=\$rules"
}

# Guard IDs contain `-`, which is not legal in a shell variable name.
reg_slug() { printf '%s' "$1" | tr -c 'A-Za-z0-9' '_'; }

# reg_guard_impl <guard-id> <script-basename> <paths-var-name>...
#
# Where a guard LIVES, and which of its own variables hold the paths its
# isolated root needs. A guard's `--self-test` already knows both, because it
# passes `"$0"` and its own path list to `reg_selftest`. The causality runner
# has no guard to ask: it iterates the registry and must build a root for a
# guard it was never invoked by.
#
# ## Why this is a locator and not a copy of the path list
#
# The obvious shortcut is to write the paths down here. That would be a second
# source of truth for exactly the thing this registry exists to have one of, and
# it would drift the first time a guard started checking a new file: the guard
# would inspect a path the runner never copied, the isolated root would fail its
# clean baseline, and the failure would read as "the guard rejects a correct
# tree".
#
# So what is recorded is the NAME of the guard's own variable. `reg_guard_paths`
# resolves it by SOURCING the guard — which is inert, and is the property
# `check-source-safety.sh` exists to keep true — and expanding it there. The
# list therefore still lives in exactly one place: the guard.
#
# Several names are allowed because a guard may hold more than one list; the
# Android guard's self-test root is `$GRADLE_FILES $MANIFESTS`.
reg_guard_impl() {
  local guard="$1" script="$2"; shift 2
  local slug; slug="$(reg_slug "$guard")"
  eval "REG_SCRIPT_$slug=\$script"
  eval "REG_PATHVARS_$slug=\$*"
}

reg_guard_script()   { eval "printf '%s' \"\${REG_SCRIPT_$(reg_slug "$1")-}\""; }
reg_guard_pathvars() { eval "printf '%s' \"\${REG_PATHVARS_$(reg_slug "$1")-}\""; }

# reg_guard_paths <scripts-dir> <guard-id>
#
# The guard's isolated-root path list, one per line, DERIVED by sourcing the
# guard rather than restated here.
#
# `bash -c '...' _ ...` gives the new shell a `$0` of `_`, which can never equal
# the sourced path, so the guard's `[[ "${BASH_SOURCE[0]}" == "$0" ]]` entry is
# false and sourcing is inert. Sourcing from a plain subshell of a process that
# is already running the same guard makes both sides of that test equal and runs
# `guard_main` on whatever positional parameters are in scope — the defect that
# made every early `named_rule` case fail with `usage: unknown argument`.
reg_guard_paths() {
  local dir="$1" guard="$2" script vars
  script="$(reg_guard_script "$guard")"
  vars="$(reg_guard_pathvars "$guard")"
  [ -n "$script" ] || return 1
  bash -c '
    set -uo pipefail
    . "$1" >/dev/null 2>&1 || exit 2
    for v in $2; do
      eval "printf '"'"'%s\n'"'"' \${$v-}"
    done
  ' _ "$dir/$script" "$vars" | tr -s ' \t' '\n' | grep -v '^$'
}

reg_rules_for_guard() { eval "printf '%s' \"\${REG_RULES_$(reg_slug "$1")-}\""; }

reg_known_guard() {
  case " $REG_GUARDS " in *" $1 "*) return 0 ;; esac
  return 1
}

# reg_case id=... guard=... rule=... expect=... form=... attribution=... \
#          [diag=...] [forbid=...] [files=...] [apply=...] [invoke=...]
#
# Keyword arguments rather than positional ones, so a case declaration reads as
# what it asserts and so an invocation case CARRYING mutation fields is
# detectable rather than silently ignored.
reg_case() {
  local id="" arg k v keys=""

  for arg in "$@"; do
    case "$arg" in id=*) id="${arg#id=}" ;; esac
  done
  if [ -z "$id" ]; then
    reg_load_error "a case was declared without an id"
    return 0
  fi

  REG_IDS="$REG_IDS $id"
  for arg in "$@"; do
    k="${arg%%=*}"
    v="${arg#*=}"
    case " $REG_FIELDS " in
      *" $k "*) ;;
      *) reg_load_error "$id declares unknown field '$k'"; continue ;;
    esac
    eval "REG_${id}_${k}=\$v"
    keys="$keys $k"
  done
  eval "REG_${id}_keys=\$keys"
}

reg_get() { eval "printf '%s' \"\${REG_${1}_${2}-}\""; }

# Whether a field was DECLARED, as distinct from declared empty. The difference
# is what makes "an invocation case carrying mutation fields" a real check.
reg_declared() {
  local keys; keys="$(reg_get "$1" keys)"
  case " $keys " in *" $2 "*) return 0 ;; esac
  return 1
}

reg_ids_for_guard() {
  local want="$1" id
  for id in $REG_IDS; do
    [ "$(reg_get "$id" guard)" = "$want" ] && printf '%s\n' "$id"
  done
  return 0
}

reg_count()           { printf '%s\n' $REG_IDS | grep -c . ; }
reg_count_for_guard() { reg_ids_for_guard "$1" | grep -c . ; }

# reg_count_expect <expect> [guard]
reg_count_expect() {
  local want="$1" guard="${2:-}" id n=0
  for id in $REG_IDS; do
    [ "$(reg_get "$id" expect)" = "$want" ] || continue
    [ -z "$guard" ] || [ "$(reg_get "$id" guard)" = "$guard" ] || continue
    n=$((n + 1))
  done
  echo "$n"
}

# reg_count_form <form> [guard]
reg_count_form() {
  local want="$1" guard="${2:-}" id n=0
  for id in $REG_IDS; do
    [ "$(reg_get "$id" form)" = "$want" ] || continue
    [ -z "$guard" ] || [ "$(reg_get "$id" guard)" = "$guard" ] || continue
    n=$((n + 1))
  done
  echo "$n"
}

# ---------------------------------------------------------------------------
# Validation. Every one of these has a specific failure it is preventing.
# ---------------------------------------------------------------------------
#
# reg_validate [sourced-guard-id]
#
# The optional argument names the guard whose rules are DEFINED in this shell.
# `named_rule` attribution is only meaningful if the rule can actually be
# invoked alone, and that can only be established for a guard that is loaded.
reg_validate() {
  local sourced="${1:-}" bad=0 seen="" id

  if [ -n "$REG_LOAD_ERRORS" ]; then
    printf '%s' "$REG_LOAD_ERRORS" >&2
    bad=$(( bad + $(printf '%s' "$REG_LOAD_ERRORS" | grep -c .) ))
  fi

  # Every declared guard must say where it lives and which of its variables
  # hold its isolated-root paths. Without both, the causality runner cannot
  # build a root for that guard at all — and the failure mode of "cannot build
  # a root" is a guard that is silently never exercised, which is the shape of
  # every defect this registry was written about.
  local g
  for g in $REG_GUARDS; do
    [ -n "$(reg_guard_script "$g")" ] || {
      echo "registry: guard '$g' declares no implementing script (reg_guard_impl)" >&2
      bad=$((bad + 1)); }
    [ -n "$(reg_guard_pathvars "$g")" ] || {
      echo "registry: guard '$g' declares no isolated-root path variables (reg_guard_impl)" >&2
      bad=$((bad + 1)); }
  done

  for id in $REG_IDS; do
    # Duplicate IDs: two cases reporting under one name means one of them is
    # invisible in every report, including a failure report.
    case " $seen " in
      *" $id "*) echo "registry: DUPLICATE case id '$id'" >&2; bad=$((bad + 1)) ;;
    esac
    seen="$seen $id"

    local guard rule expect form attribution diag forbid files apply invoke
    guard="$(reg_get "$id" guard)"
    rule="$(reg_get "$id" rule)"
    expect="$(reg_get "$id" expect)"
    form="$(reg_get "$id" form)"
    attribution="$(reg_get "$id" attribution)"
    diag="$(reg_get "$id" diag)"
    forbid="$(reg_get "$id" forbid)"
    files="$(reg_get "$id" files)"
    apply="$(reg_get "$id" apply)"
    invoke="$(reg_get "$id" invoke)"

    if ! reg_known_guard "$guard"; then
      echo "registry: $id names unknown guard '$guard'" >&2; bad=$((bad + 1))
    else
      # An unknown rule ID means the case cites something that does not exist,
      # so nothing keeps the case pointed at the code it claims to cover.
      case " $(reg_rules_for_guard "$guard") " in
        *" $rule "*) ;;
        *) echo "registry: $id names unknown production rule '$rule' for guard '$guard'" >&2
           bad=$((bad + 1)) ;;
      esac
    fi

    case "$expect" in
      reject)
        # A reject case with no expected diagnostic proves only that something
        # went wrong -- which is what a missing parser mode, an incomplete copy
        # and a bootstrap failure all look like.
        case "$diag" in
          *STRIDE_GUARD*) ;;
          *) echo "registry: reject case $id has no STRIDE_GUARD diagnostic" >&2; bad=$((bad + 1)) ;;
        esac ;;
      accept)
        # An accept case carrying a rejection diagnostic is a contradiction: it
        # says "this must pass" and "this is the error it must give".
        case "$diag" in
          "") ;;
          *) echo "registry: accept case $id declares a violation diagnostic" >&2; bad=$((bad + 1)) ;;
        esac ;;
      infra)
        # Infrastructure is the outcome a rejection case must never be
        # satisfied by, so it has to be stated as its own thing.
        case "$diag" in
          *STRIDE_INFRA*) ;;
          *) echo "registry: infra case $id has no STRIDE_INFRA diagnostic" >&2; bad=$((bad + 1)) ;;
        esac ;;
      *)
        echo "registry: $id has invalid expectation '$expect' (reject|accept|infra)" >&2
        bad=$((bad + 1)) ;;
    esac

    case "$form" in
      mutation)
        # The operation must live in the registry. A mutation defined inside a
        # guard is a second inventory again.
        if [ -z "$apply" ]; then
          echo "registry: mutation case $id declares no apply function" >&2; bad=$((bad + 1))
        elif ! command -v "$apply" >/dev/null 2>&1; then
          echo "registry: $id apply function '$apply' is not defined" >&2; bad=$((bad + 1))
        fi
        # A missing changed-file declaration means restoration cannot be
        # verified, and an unverified restoration is how one case passes on the
        # previous case's leftovers.
        [ -n "$files" ] || {
          echo "registry: mutation case $id declares no changed-file set" >&2; bad=$((bad + 1)); } ;;
      invocation)
        if [ -z "$invoke" ]; then
          echo "registry: invocation case $id declares no invoke function" >&2; bad=$((bad + 1))
        elif ! command -v "$invoke" >/dev/null 2>&1; then
          echo "registry: $id invoke function '$invoke' is not defined" >&2; bad=$((bad + 1))
        fi
        # Mutation fields on an invocation case mean the case is not the shape
        # it says it is, and the runner would silently ignore them.
        reg_declared "$id" apply && {
          echo "registry: invocation case $id carries a mutation field 'apply'" >&2; bad=$((bad + 1)); }
        reg_declared "$id" files && {
          echo "registry: invocation case $id carries a mutation field 'files'" >&2; bad=$((bad + 1)); } ;;
      *)
        echo "registry: $id has invalid case form '$form' (mutation|invocation)" >&2
        bad=$((bad + 1)) ;;
    esac

    case "$attribution" in
      complete_guard) ;;
      named_rule)
        # named_rule claims the rule is invoked ALONE. If the rule cannot be
        # sourced, that claim is unbacked and the case would quietly degrade to
        # a complete-guard assertion.
        if [ -n "$sourced" ] && [ "$guard" = "$sourced" ] && ! command -v "$rule" >/dev/null 2>&1; then
          echo "registry: $id claims named_rule attribution but rule '$rule' cannot be sourced" >&2
          bad=$((bad + 1))
        fi ;;
      "") echo "registry: $id declares no attribution" >&2; bad=$((bad + 1)) ;;
      *)  echo "registry: $id has invalid attribution '$attribution'" >&2; bad=$((bad + 1)) ;;
    esac

    [ -z "$forbid" ] || [ "$expect" != accept ] || {
      echo "registry: accept case $id declares a forbidden diagnostic" >&2; bad=$((bad + 1)); }
  done

  if [ "$bad" -ne 0 ]; then
    echo "registry: INVALID -- $bad problem(s)" >&2
    return 1
  fi
  return 0
}

# reg_assert_rules_match <guard-id> <live-rule-list>
#
# The guard passes the rule list it actually runs. If it disagrees with the
# inventory the registry validates against, "unknown production rule ID" stops
# meaning anything -- a rule could be added to the guard and never be citable,
# or removed from the guard while cases still name it.
reg_assert_rules_match() {
  local guard="$1" live="$2" registered
  registered="$(reg_rules_for_guard "$guard")"
  local a b
  a="$(printf '%s\n' $registered | LC_ALL=C sort)"
  b="$(printf '%s\n' $live       | LC_ALL=C sort)"
  [ "$a" = "$b" ] && return 0
  echo "registry: the rule inventory for '$guard' disagrees with the guard itself" >&2
  diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") | sed 's/^/    | /' >&2
  return 1
}

# reg_assert_no_embedded_inventory <guard-script>
#
# A migrated guard must hold NO mutation machinery of its own. Each marker below
# is a thing the shared layer now owns; finding one in a guard means a second
# mutation source survived the migration, which is the exact condition the
# registry exists to remove.
REG_EMBEDDED_MARKERS='sed -i |perl -0?pi|st_make_root|st_copy_from|expect_reject|mktemp -d|rm -rf "\$ISO|restore_all'

reg_assert_no_embedded_inventory() {
  local script="$1" hits
  hits="$(grep -nE "$REG_EMBEDDED_MARKERS" "$script" || true)"
  [ -z "$hits" ] && return 0
  echo "registry: $(basename "$script") still carries an embedded mutation inventory:" >&2
  printf '%s\n' "$hits" | head -10 | sed 's/^/    | /' >&2
  return 1
}

# ---------------------------------------------------------------------------
# Fingerprinting an isolated root
#
# One line per path: relative path, type, mode, symlink target, content hash.
# That is exactly the set of properties restoration is required to preserve --
# existence, exact bytes, file type, mode, and symlink target -- so comparing
# two fingerprints IS the restoration assertion, rather than a proxy for it.
#
# Hashes come from ONE `sha256sum` invocation rather than one per file: the
# single-writer root holds seventy-odd files and is fingerprinted twice per
# case, and a process per file per fingerprint is a self-test nobody runs.
# ---------------------------------------------------------------------------
reg_fingerprint() {
  local root="$1"
  if [ ! -d "$root" ]; then printf 'ABSENT-ROOT\n'; return 0; fi
  (
    cd "$root" || return 0
    {
      find . -mindepth 1 -type f -print0 2>/dev/null | xargs -0 -r sha256sum 2>/dev/null
      printf -- '--REG-FP-MARK--\n'
      find . -mindepth 1 -printf '%p\t%y\t%m\t%l\n' 2>/dev/null
    } | awk -v mark='--REG-FP-MARK--' '
        !seen && $0 == mark { seen = 1; next }
        # sha256sum prints 64 hex, two separator characters, then the path --
        # which is why this is substr and not a field split: a path may contain
        # spaces, and the Windows development checkout lives under one.
        !seen { H[substr($0, 67)] = substr($0, 1, 64); next }
        {
          split($0, f, "\t")
          printf "%s\t%s\t%s\t%s\t%s\n", f[1], f[2], f[3], f[4], (f[1] in H ? H[f[1]] : "-")
        }
      ' | LC_ALL=C sort
  )
}

reg_re_escape() { printf '%s' "$1" | sed 's/[][\\.*^$(){}?+|]/\\&/g'; }

# reg_assert_changed_set <id> <declared-files> <fp-before> <fp-after>
#
# Both directions. An UNDECLARED change means the case did more than it says,
# and the extra damage is what the next case would pass on. A declared path that
# did NOT change means the case did less than it says -- a `sed` that matched
# nothing still exits 0, and a rejection afterwards would be attributed to a
# mutation that never happened.
reg_assert_changed_set() {
  local id="$1" files="$2" fp0="$3" fp1="$4" bad=0 changed p d covered

  changed="$(LC_ALL=C sort "$fp0" "$fp1" | uniq -u | cut -f1 | LC_ALL=C sort -u)"

  if [ -z "$changed" ]; then
    echo "  CASE FAIL [$id]: the mutation changed nothing in the isolated root" >&2
    return 1
  fi

  while IFS= read -r p; do
    [ -n "$p" ] || continue
    covered=0
    for d in $files; do
      case "$p" in "./$d" | "./$d"/*) covered=1; break ;; esac
    done
    [ "$covered" -eq 1 ] || {
      echo "  CASE FAIL [$id]: changed an undeclared path: $p" >&2; bad=1; }
  done <<< "$changed"

  for d in $files; do
    printf '%s\n' "$changed" | grep -qE "^\./$(reg_re_escape "$d")(/|\$)" || {
      echo "  CASE FAIL [$id]: declared changed path did not change: $d" >&2; bad=1; }
  done

  return $bad
}

# ---------------------------------------------------------------------------
# Generic backup and restoration
#
# `cp -a` carries mode, symlinks and timestamps; the manifest carries EXISTENCE,
# which `cp` cannot. A case whose operation creates a file must leave the root
# without that file afterwards, and "restore from a backup that was never taken"
# would otherwise be a silent no-op.
# ---------------------------------------------------------------------------
reg_backup() {
  local iso="$1" store="$2" files="$3" n=0 f
  rm -rf "$store"; mkdir -p "$store" || return 1
  : > "$store/manifest"
  for f in $files; do
    n=$((n + 1))
    if [ -e "$iso/$f" ] || [ -L "$iso/$f" ]; then
      cp -a "$iso/$f" "$store/$n" || return 1
      printf 'P\t%s\t%s\n' "$n" "$f" >> "$store/manifest"
    else
      printf 'A\t%s\t%s\n' "$n" "$f" >> "$store/manifest"
    fi
  done
  return 0
}

reg_restore() {
  local iso="$1" store="$2" state n f
  # $'\t' rather than "$(printf '\t')": command substitution strips the trailing
  # tab, which would leave IFS empty and every manifest line unsplit.
  while IFS=$'\t' read -r state n f; do
    [ -n "$f" ] || continue
    rm -rf "$iso/$f"
    [ "$state" = "P" ] || continue
    mkdir -p "$(dirname "$iso/$f")"
    cp -a "$store/$n" "$iso/$f" || return 1
  done < "$store/manifest"
  return 0
}

# ---------------------------------------------------------------------------
# Running one case
# ---------------------------------------------------------------------------
#
# `CASE_ROOT` and `CASE_SCRIPT` are the operation's whole interface. An apply or
# invoke function knows the isolated root and nothing about the guard's
# internals, which is what lets the same function be reused by a causality
# runner later without the guard being involved at all.
CASE_ROOT=""
CASE_SCRIPT=""

reg_run_case() {
  local id="$1" script="$2" iso="$3" bak="$4"
  local guard rule expect form attribution diag forbid files apply invoke
  guard="$(reg_get "$id" guard)"
  rule="$(reg_get "$id" rule)"
  expect="$(reg_get "$id" expect)"
  form="$(reg_get "$id" form)"
  attribution="$(reg_get "$id" attribution)"
  diag="$(reg_get "$id" diag)"
  forbid="$(reg_get "$id" forbid)"
  files="$(reg_get "$id" files)"
  apply="$(reg_get "$id" apply)"
  invoke="$(reg_get "$id" invoke)"

  local bad=0 out rc
  local fp0="$bak/$id.fp0" fp1="$bak/$id.fp1" fp2="$bak/$id.fp2"
  local store="$bak/$id.store"

  CASE_ROOT="$iso"
  CASE_SCRIPT="$script"

  reg_fingerprint "$iso" > "$fp0"

  if [ "$form" = mutation ]; then
    if ! reg_backup "$iso" "$store" "$files"; then
      echo "  CASE FAIL [$id]: could not back up the declared path set" >&2
      return 1
    fi
    if ! "$apply"; then
      echo "  CASE FAIL [$id]: the apply function failed" >&2
      reg_restore "$iso" "$store"
      return 1
    fi
    reg_fingerprint "$iso" > "$fp1"
    reg_assert_changed_set "$id" "$files" "$fp0" "$fp1" || bad=1

    out="$(bash "$script" --project-root "$iso" 2>&1)"; rc=$?
  else
    out="$("$invoke" 2>&1)"; rc=$?
  fi

  case "$expect" in
    reject)
      if [ "$rc" -eq 0 ]; then
        echo "  CASE FAIL [$id]: the guard ACCEPTED it" >&2
        bad=1
      elif [ "$rc" -ne 1 ]; then
        # Exit 2 means the guard could not look. A case satisfied by that would
        # be satisfied equally by deleting Node.
        echo "  CASE FAIL [$id]: rejected with exit $rc (INFRASTRUCTURE), not a policy violation" >&2
        printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
        bad=1
      elif ! printf '%s\n' "$out" | grep -qE "$diag"; then
        echo "  CASE FAIL [$id]: rejected, but NOT by its own rule." >&2
        echo "    expected a diagnostic matching: $diag" >&2
        printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
        bad=1
      elif printf '%s\n' "$out" | grep -qE 'STRIDE_INFRA\['; then
        # Belt and braces on top of the exit code: no reject case may be
        # satisfied by an xmlq infrastructure failure, and an infra line in the
        # output means one occurred whatever the exit code says.
        echo "  CASE FAIL [$id]: the rejection carried an infrastructure diagnostic" >&2
        printf '%s\n' "$out" | grep -E 'STRIDE_INFRA\[' | head -4 | sed 's/^/    | /' >&2
        bad=1
      fi ;;
    accept)
      if [ "$rc" -ne 0 ]; then
        echo "  CASE FAIL [$id]: the guard REJECTED it (exit $rc)" >&2
        printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
        bad=1
      elif printf '%s\n' "$out" | grep -qE 'STRIDE_GUARD\['; then
        echo "  CASE FAIL [$id]: accepted, but emitted a violation diagnostic" >&2
        printf '%s\n' "$out" | grep -E 'STRIDE_GUARD\[' | head -4 | sed 's/^/    | /' >&2
        bad=1
      fi ;;
    infra)
      if [ "$rc" -ne 2 ]; then
        echo "  CASE FAIL [$id]: expected an INFRASTRUCTURE failure (exit 2), got exit $rc" >&2
        printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
        bad=1
      elif ! printf '%s\n' "$out" | grep -qE "$diag"; then
        echo "  CASE FAIL [$id]: exited 2 without its own infrastructure diagnostic." >&2
        echo "    expected a diagnostic matching: $diag" >&2
        printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
        bad=1
      fi ;;
  esac

  if [ -n "$forbid" ] && printf '%s\n' "$out" | grep -qE "$forbid"; then
    echo "  CASE FAIL [$id]: the outcome carried a forbidden diagnostic matching: $forbid" >&2
    printf '%s\n' "$out" | grep -E "$forbid" | head -4 | sed 's/^/    | /' >&2
    bad=1
  fi

  # Attribution. `complete_guard` is already asserted above -- that IS the
  # complete guard's outcome. `named_rule` adds the isolation proof: with one
  # rule running, a mutation only some OTHER rule can see returns 0, so the case
  # fails rather than passing on someone else's detection.
  if [ "$attribution" = named_rule ]; then
    local rout rrc
    rout="$(reg_invoke_named_rule "$script" "$rule" "$iso" 2>&1)"; rrc=$?
    if [ "$rrc" -ne 1 ]; then
      echo "  CASE FAIL [$id]: $rule invoked alone exited $rrc, not 1" >&2
      printf '%s\n' "$rout" | head -8 | sed 's/^/    | /' >&2
      bad=1
    elif ! printf '%s\n' "$rout" | grep -qE "$diag"; then
      echo "  CASE FAIL [$id]: $rule invoked alone did not emit its own diagnostic" >&2
      printf '%s\n' "$rout" | head -8 | sed 's/^/    | /' >&2
      bad=1
    fi
  fi

  if [ "$form" = mutation ]; then
    if ! reg_restore "$iso" "$store"; then
      echo "  CASE FAIL [$id]: restoration failed" >&2
      return 1
    fi
    reg_fingerprint "$iso" > "$fp2"
    if ! cmp -s "$fp0" "$fp2"; then
      echo "  CASE FAIL [$id]: the isolated root did not restore byte-for-byte" >&2
      diff "$fp0" "$fp2" | head -12 | sed 's/^/    | /' >&2
      bad=1
    fi
  fi

  if [ "$bad" -ne 0 ]; then return 1; fi
  printf '  case ok [%s] %s: %s / %s\n' "$id" "$expect" "$rule" "$attribution"
  return 0
}

# reg_invoke_named_rule <guard-script> <rule> <iso-root>
#
# Sources the guard and runs ONE rule. Possible only because sourcing a guard is
# inert -- `check-source-safety.sh` is what makes this sound, and is the reason
# it exists.
#
# ## Why this is a fresh `bash -c` and not a subshell
#
# A guard's source-safe entry is `[[ "${BASH_SOURCE[0]}" == "$0" ]]`. Sourcing
# it from a subshell of a process that is ALREADY running that same guard makes
# both sides of that test the same string, so the guard does not source
# inertly -- it runs `guard_main "$@"` on whatever positional parameters happen
# to be in scope. Every `named_rule` case then failed identically, with
# `STRIDE_INFRA[<guard>.usage] unknown argument`, and the case read as "the rule
# alone exited 2" rather than as a defect in this function.
#
# `bash -c '...' _ ...` gives the new shell `$0` of `_`, which can never equal
# the sourced path, so the entry guard is false and sourcing is inert. The rule
# then runs as the only thing in that process. Sourcing output is discarded so
# that what is captured is the RULE's diagnostic and nothing else.
#
# This path had no coverage until origin-privacy brought the first `named_rule`
# cases to the registry: the three guards migrated before it are all
# `complete_guard`.
reg_invoke_named_rule() {
  PROJECT_ROOT="$3" bash -c '
    set -uo pipefail
    . "$1" >/dev/null 2>&1 || exit 2
    rule_run "$2"
  ' _ "$1" "$2"
}

# ---------------------------------------------------------------------------
# The whole self-test for one guard
#
#   reg_selftest <guard-id> <guard-script> <live-rule-list> -- <copy-path>...
# ---------------------------------------------------------------------------
reg_selftest() {
  local guard="$1" script="$2" live_rules="$3"; shift 3
  [ "${1:-}" = "--" ] && shift

  reg_validate "$guard" || return 1
  reg_assert_rules_match "$guard" "$live_rules" || return 1
  reg_assert_no_embedded_inventory "$script" || return 1

  local total
  total="$(reg_count_for_guard "$guard")"
  if [ "${total:-0}" -eq 0 ]; then
    echo "$guard: SELF-TEST FAILED -- the registry holds no cases for this guard" >&2
    return 1
  fi

  local TREE_BEFORE ISO BAK ok=0 fails=0 id
  TREE_BEFORE="$(st_tree_snapshot)"
  ISO="$(st_make_root)"
  # The backup store lives OUTSIDE the isolated root. Inside it, every backup
  # would appear in the root's own fingerprint and in the guard's scan -- the
  # previous iOS self-test kept `.backup` under the copy for exactly that reason
  # and got away with it only because the guard reads a fixed path list.
  BAK="$(mktemp -d "${TMPDIR:-/tmp}/stride-guard-bak-XXXXXXXX")"
  trap 'rm -rf "$ISO" "$BAK"' EXIT
  st_copy_from "$PROJECT_ROOT" "$ISO" "$@"

  # The copy must pass before anything is injected, or a rejection below could
  # be the copy being incomplete rather than the operation being detected.
  if ! bash "$script" --project-root "$ISO" >/dev/null 2>&1; then
    echo "$guard SELF-TEST FAILED: the isolated copy does not pass clean" >&2
    bash "$script" --project-root "$ISO" >&2
    rm -rf "$ISO" "$BAK"; trap - EXIT
    return 1
  fi

  for id in $(reg_ids_for_guard "$guard"); do
    if reg_run_case "$id" "$script" "$ISO" "$BAK"; then
      ok=$((ok + 1))
    else
      fails=$((fails + 1))
    fi
  done

  # And it must pass again once every case has been restored, or a rejection
  # above was damage rather than detection.
  if ! bash "$script" --project-root "$ISO" >/dev/null 2>&1; then
    echo "$guard SELF-TEST FAILED: the isolated copy does not pass after restoration" >&2
    bash "$script" --project-root "$ISO" >&2
    fails=$((fails + 1))
  fi

  rm -rf "$ISO" "$BAK"
  trap - EXIT

  # The live tree must be byte-for-byte what it was. Asserted, not assumed.
  st_assert_tree_unchanged "$TREE_BEFORE" || return 1

  if [ "$fails" -ne 0 ] || [ "$ok" -ne "$total" ]; then
    echo "$guard: SELF-TEST FAILED -- $ok of $total registry case(s) held, $fails wrong" >&2
    return 1
  fi

  # Derived, never narrated. The count used to be a string in an `echo`, which
  # is a second source of truth that cannot disagree with itself out loud.
  printf '%s: self-test OK -- %s registry case(s): %s reject, %s accept, %s infra (%s mutation, %s invocation)\n' \
    "$guard" "$total" \
    "$(reg_count_expect reject "$guard")" \
    "$(reg_count_expect accept "$guard")" \
    "$(reg_count_expect infra  "$guard")" \
    "$(reg_count_form mutation "$guard")" \
    "$(reg_count_form invocation "$guard")"
  return 0
}

# reg_summary — the whole registry, derived.
reg_summary() {
  local g
  echo "registry: $(reg_count) case(s) across $(printf '%s\n' $REG_GUARDS | grep -c .) guard(s)"
  for g in $REG_GUARDS; do
    printf '  %-16s %2s total : %2s reject, %2s accept, %2s infra\n' \
      "$g" "$(reg_count_for_guard "$g")" \
      "$(reg_count_expect reject "$g")" \
      "$(reg_count_expect accept "$g")" \
      "$(reg_count_expect infra "$g")"
  done
  printf '  %-16s %2s total : %2s reject, %2s accept, %2s infra\n' \
    "ALL" "$(reg_count)" \
    "$(reg_count_expect reject)" "$(reg_count_expect accept)" "$(reg_count_expect infra)"
}
