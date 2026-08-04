# Shared self-test isolation for the build guards.
#
# ## Why
#
# Every guard's `--self-test` used to inject its violations into the LIVE
# working tree and restore afterwards. Three separate agents hit the
# consequence within one session: run two self-tests at once and they clobber
# each other, leaving probe files behind and failing runs for reasons that had
# nothing to do with the tree. CI would have hit it the moment two jobs shared
# a checkout.
#
# So a self-test now builds a throwaway copy of only the files it inspects,
# mutates that, and passes `--project-root <copy>` to the guard. The live tree
# is never written to. Concurrent runs cannot interact, because each gets its
# own directory under `mktemp -d`.
#
# ## Contract for a guard using this
#
#   * accept `--project-root <path>` and resolve every path it checks against
#     it, defaulting to the repository root
#   * declare the paths its self-test needs via `st_copy`
#   * never write to the live tree in any mode
#
# `st_cleanup` is installed on EXIT, so an interrupted self-test does not leave
# a temp directory behind either.

# Creates an isolated project root and echoes its path.
st_make_root() {
  local root
  root="$(mktemp -d "${TMPDIR:-/tmp}/stride-guard-XXXXXXXX")"
  echo "$root"
}

# st_copy_from <src-root> <dest-root> <relative-path>...
#
# Copies paths into the isolated root, keeping their relative layout so the
# guard's own path arithmetic is unchanged.
#
# The SOURCE ROOT is explicit. `st_copy` resolved relative paths against the
# caller's working directory, which was invisible only because every guard used
# to `cd "$PROJECT_ROOT"` at load time. A source-safe guard does not cd, so the
# same call from any other directory would have copied nothing at all — and the
# self-test's first act is to check the copy passes clean, so the failure would
# have read as "the guard rejects a correct tree".
st_copy_from() {
  local src="$1" root="$2"; shift 2
  local p
  for p in "$@"; do
    [ -e "$src/$p" ] || continue
    mkdir -p "$root/$(dirname "$p")"
    cp -R "$src/$p" "$root/$(dirname "$p")/"
  done
}

# st_copy <root> <path>... — the cwd-relative form. Kept for callers that have
# not been converted; new code should pass its root explicitly.
st_copy() {
  local root="$1"; shift
  st_copy_from "$PWD" "$root" "$@"
}

# Snapshots the live tree's state, for comparison after a self-test.
#
# A SNAPSHOT, not an emptiness check. The first version asserted `git status
# --porcelain` was empty afterwards, which fails whenever the tree has
# legitimate uncommitted work in progress — which is exactly when a developer
# runs verify.sh. The claim worth making is "the self-test changed nothing",
# and that is a comparison.
st_tree_snapshot() {
  {
    git status --porcelain 2>/dev/null || true
    # Content too, not just the file list: a self-test that edited a file and
    # restored it imperfectly leaves the same status line and different bytes.
    git diff 2>/dev/null | git hash-object --stdin 2>/dev/null || true
  }
}

# st_file_digest <path> — content hash of ONE named file, or ABSENT.
#
# The tree snapshot above already covers "nothing changed", but it says so about
# the whole tree at once. For a file whose damage would surface somewhere else
# entirely -- a Pigeon input, whose generated output CI diff-checks against a
# regeneration in a different job -- a per-file assertion is worth having: it
# names which file and why, instead of reporting an unrelated diff.
st_file_digest() {
  [ -f "$1" ] || { printf 'ABSENT'; return 0; }
  git hash-object "$1" 2>/dev/null || sha256sum "$1" 2>/dev/null | cut -d' ' -f1
}

# st_assert_tree_unchanged <snapshot>
st_assert_tree_unchanged() {
  local before="$1" after
  after="$(st_tree_snapshot)"
  if [ "$before" != "$after" ]; then
    echo "SELF-TEST FAILED: the live working tree was modified by the self-test." >&2
    echo "--- before ---" >&2; printf '%s\n' "$before" >&2
    echo "--- after ----" >&2; printf '%s\n' "$after" >&2
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Mutation CAUSALITY
# ---------------------------------------------------------------------------
#
# A nonzero exit is not evidence. A guard that rejects everything — because a
# parser mode does not exist, because a copied tree is incomplete, because the
# Node dependency is missing — rejects every injection too, and its self-test
# reads exactly like a working one.
#
# That is not hypothetical. Three checks in `check-android-target.sh` called an
# xmlq mode named `attr` that has never existed; every call exited 2 into
# `|| true`, so the checks were dead from the day they were written. Their
# self-test was green because the guard was ALREADY failing on an unrelated
# parse bug, so each injection was "rejected" for a reason that had nothing to
# do with the check under test. Six cases, all passing, all proving nothing.
#
# So each injection must show its own rule firing:
#
#   1. the unmodified temporary tree passes
#   2. exactly one mutation is applied
#   3. the guard fails
#   4. the diagnostic matches THAT RULE
#   5. the failure is not infrastructure — missing input, an unrelated
#      malformed file, a missing parser mode, a bootstrap failure, or a
#      different rule of the same guard
#   6. the mutation is removed and the tree passes again
#
# Steps 1 and 6 are per-injection, not once per run: a mutation that failed to
# revert would otherwise make every later injection pass on the leftovers.

ST_CAUSAL_FAILS=0
ST_CAUSAL_OK=0

# Rejections that are about the harness rather than the rule. A guard failing
# with one of these has not demonstrated anything about the code under test.
ST_INFRA_PATTERNS='No such file or directory|is missing;|unknown mode|is not installed|npm ci|no production Dart sources found|no native sources found|no Dart sources found for|does not pass clean|aapt2 not found|command not found'

# st_causal_clean <label> <cmd...> — step 1 and step 6.
st_causal_clean() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then return 0; fi
  echo "  CAUSALITY FAIL: the temporary tree does not pass $label" >&2
  "$@" 2>&1 | head -15 >&2
  ST_CAUSAL_FAILS=$((ST_CAUSAL_FAILS + 1))
  return 1
}

# st_causal_reject <label> <expect-regex> <cmd...> — steps 3, 4 and 5.
#
# `ST_INFRA_ALLOW` may be set by the caller to a regex naming an infrastructure
# pattern that is the LEGITIMATE diagnostic for this particular injection — a
# guard whose rule genuinely is "this file must parse" has to be able to say so.
st_causal_reject() {
  local label="$1" want="$2"; shift 2
  local out rc
  out="$("$@" 2>&1)"; rc=$?

  if [ "$rc" -eq 0 ]; then
    echo "  CAUSALITY FAIL: the guard ACCEPTED $label" >&2
    ST_CAUSAL_FAILS=$((ST_CAUSAL_FAILS + 1)); return 1
  fi

  if ! printf '%s\n' "$out" | grep -qE "$want"; then
    echo "  CAUSALITY FAIL: $label was rejected, but NOT by its own rule." >&2
    echo "    expected a diagnostic matching: $want" >&2
    printf '%s\n' "$out" | head -12 | sed 's/^/    | /' >&2
    ST_CAUSAL_FAILS=$((ST_CAUSAL_FAILS + 1)); return 1
  fi

  local infra
  infra="$(printf '%s\n' "$out" | grep -E "$ST_INFRA_PATTERNS" || true)"
  if [ -n "${ST_INFRA_ALLOW:-}" ]; then
    infra="$(printf '%s\n' "$infra" | grep -vE "${ST_INFRA_ALLOW}" || true)"
  fi
  if [ -n "$infra" ]; then
    echo "  CAUSALITY FAIL: $label failed for an INFRASTRUCTURE reason." >&2
    printf '%s\n' "$infra" | head -6 | sed 's/^/    | /' >&2
    ST_CAUSAL_FAILS=$((ST_CAUSAL_FAILS + 1)); return 1
  fi

  ST_CAUSAL_OK=$((ST_CAUSAL_OK + 1))
  echo "  causal: $label"
  return 0
}

# st_causal_report <guard> <expected-count>
st_causal_report() {
  local guard="$1" want="$2"
  if [ "$ST_CAUSAL_FAILS" -ne 0 ]; then
    echo "$guard: CAUSALITY FAILED -- $ST_CAUSAL_FAILS of $want injections" >&2
    return 1
  fi
  if [ "$ST_CAUSAL_OK" -ne "$want" ]; then
    echo "$guard: CAUSALITY FAILED -- $ST_CAUSAL_OK injections proved, expected $want" >&2
    return 1
  fi
  echo "$guard: causality OK -- $ST_CAUSAL_OK injections, each rejected by its own named rule"
  return 0
}
