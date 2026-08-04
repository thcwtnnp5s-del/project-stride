#!/usr/bin/env bash
# causality-run.sh
#
# The evidence run: every case in the shared registry, each in its own isolated
# root, each proved to have caused exactly its intended outcome.
#
# This is not a second inventory. It reads `Scripts/lib/cases.sh` — the same
# registry every guard's `--self-test` consumes — and every total it reports is
# DERIVED by counting the records it emitted. Nothing here is written down.
#
# Usage:
#   ./Scripts/causality-run.sh                     # every guard
#   ./Scripts/causality-run.sh --guard step-model  # one guard
#   ./Scripts/causality-run.sh --out DIR           # where the records go
#
# Output:
#   <out>/causality.jsonl   one structured record per case
#   <out>/causality-summary.txt
#
# The summary is computed from the JSONL, not from counters kept alongside it.
# A summary maintained in parallel with the records is a second source of truth
# for the same run, and would be free to disagree with the evidence it claims to
# summarise — which is the defect that produced "6 cases" for a guard with 17.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/rulekit.sh
. "$SCRIPT_DIR/lib/rulekit.sh"
# shellcheck source=lib/selftest.sh
. "$SCRIPT_DIR/lib/selftest.sh"
# shellcheck source=lib/registry.sh
. "$SCRIPT_DIR/lib/registry.sh"
# shellcheck source=lib/cases.sh
. "$SCRIPT_DIR/lib/cases.sh"
# shellcheck source=lib/causality.sh
. "$SCRIPT_DIR/lib/causality.sh"

ONLY_GUARD=""
OUT_DIR="$PROJECT_ROOT/build/causality"
PARALLEL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --guard)    ONLY_GUARD="${2:-}"; shift 2 ;;
    --out)      OUT_DIR="${2:-}";    shift 2 ;;
    --parallel) PARALLEL=1;          shift ;;
    *) echo "STRIDE_INFRA[causality.usage] unknown option: $1" >&2; exit 2 ;;
  esac
done

if ! reg_validate; then
  echo "causality-run: FAILED -- the registry does not validate" >&2
  exit 2
fi

GUARDS="$REG_GUARDS"
if [ -n "$ONLY_GUARD" ]; then
  if ! reg_known_guard "$ONLY_GUARD"; then
    echo "STRIDE_INFRA[causality.usage] unknown guard: $ONLY_GUARD" >&2
    exit 2
  fi
  GUARDS="$ONLY_GUARD"
fi

SUFFIX=""
[ -z "$ONLY_GUARD" ] || SUFFIX="-$ONLY_GUARD"

# The record file must be WRITABLE before a single case runs, and the run stops
# here if it is not.
#
# This is not defensiveness about directory permissions. The first version
# created the directory and carried on: every case ran, every case held, every
# `caus_emit_record` failed with "No such file or directory", and the final
# completeness check compared an EMPTY record count against 7 using `[ "" -ne 7 ]`
# — which errors, does not set `rc`, and let the run print
# `causality-run: OK -- of 7 case(s)`.
#
# A run that proves nothing and reports success is the exact failure this entire
# framework exists to make impossible, and it had reappeared in the framework
# itself. So: the output is proved writable first, and every count below is
# forced to a number so a missing file can never compare as equal.
if ! mkdir -p "$OUT_DIR" 2>/dev/null || [ ! -w "$OUT_DIR" ]; then
  echo "STRIDE_INFRA[causality.output_unwritable] cannot write records to: $OUT_DIR" >&2
  exit 2
fi
JSONL="$OUT_DIR/causality$SUFFIX.jsonl"
SUMMARY="$OUT_DIR/causality$SUFFIX-summary.txt"
if ! : > "$JSONL" 2>/dev/null; then
  echo "STRIDE_INFRA[causality.output_unwritable] cannot create record file: $JSONL" >&2
  exit 2
fi

# Work directory for fingerprints and backup stores. OUTSIDE every isolated
# root: a backup kept inside the root it came from appears in that root's own
# fingerprint and in the guard's scan.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/stride-causality-XXXXXXXX")"

# The live tree is never written to. Asserted, not assumed.
TREE_BEFORE="$(st_tree_snapshot)"

cleanup() {
  rm -rf "$WORK"
  # Any root this run created and did not remove. Named individually as they
  # are created would be better; this is the backstop for a run that died
  # between mktemp and its own rm.
  :
}
trap cleanup EXIT

RUN_START="$(date +%s)"

echo "causality: $(reg_count) registered case(s) across $(printf '%s\n' $REG_GUARDS | grep -c .) guard(s)"
echo "causality: records -> $JSONL"

failed_guards=0

if [ "$PARALLEL" -eq 1 ] && [ -z "$ONLY_GUARD" ]; then
  # One process per guard, then the records merged.
  #
  # Sequentially this run is a couple of hours: origin-privacy alone is ~72s per
  # case because every case re-scans three languages' worth of sources through
  # Node. Concurrently it is as long as the slowest guard.
  #
  # This is safe for the same reason concurrent self-tests are, and it is worth
  # noticing that it EXERCISES that reason rather than merely relying on it:
  # every case builds its own root under `mktemp -d`, so five guards running at
  # once cannot see each other's trees. Guards used to inject into the live
  # working tree, and three agents hit the consequence in one session.
  #
  # Each child writes its OWN record file. A shared file would interleave
  # partial lines from five appenders and produce records that parse as neither
  # one case nor the other.
  echo "causality: running $(printf '%s\n' $GUARDS | grep -c .) guard(s) concurrently"
  child_pids=""
  for g in $GUARDS; do
    bash "$SCRIPT_DIR/causality-run.sh" --guard "$g" --out "$OUT_DIR" \
      > "$OUT_DIR/causality-$g.log" 2>&1 &
    child_pids="$child_pids $!"
  done
  for p in $child_pids; do
    wait "$p" || failed_guards=$((failed_guards + 1))
  done

  # Merge. The per-guard files stay on disk beside the merged one: they are the
  # primary evidence, and a merge is a derived artefact that must not become the
  # only copy.
  : > "$JSONL"
  for g in $GUARDS; do
    [ -f "$OUT_DIR/causality-$g.jsonl" ] || continue
    cat "$OUT_DIR/causality-$g.jsonl" >> "$JSONL"
  done
  for g in $GUARDS; do
    sed 's/^/  /' "$OUT_DIR/causality-$g.log" 2>/dev/null |
      grep -E 'case ok|CASE FAIL|clean guard|of [0-9]+ case' || true
  done
else
  for g in $GUARDS; do
    caus_run_guard "$g" "$SCRIPT_DIR" "$PROJECT_ROOT" "$WORK" "$JSONL" || failed_guards=$((failed_guards + 1))
  done
fi

RUN_END="$(date +%s)"

# ---------------------------------------------------------------------------
# The derived summary
#
# Read back out of the records. Every number below is a count of lines in the
# JSONL, so a number and the evidence behind it cannot disagree.
# ---------------------------------------------------------------------------
# Always a number. `grep -c` on a missing file prints nothing and exits 2, and
# an empty string in an arithmetic comparison is an error that does not set the
# failure flag -- so a lost record file would read as a clean run.
num() { local n; n="$(cat)"; case "$n" in ''|*[!0-9]*) echo 0 ;; *) echo "$n" ;; esac; }
count()   { grep -c "$1" "$JSONL" 2>/dev/null | num; }
records() { grep -c .  "$JSONL" 2>/dev/null | num; }

{
  echo "causality summary"
  echo "  generated: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "  records:   $JSONL"
  echo "  runtime:   $((RUN_END - RUN_START))s"
  echo ""
  echo "  records emitted:    $(records)"
  echo "  registry declares:  $(reg_count)"
  echo ""
  printf '  %-16s %6s %6s %6s %6s\n' guard total pass fail invalid
  for g in $REG_GUARDS; do
    [ -z "$ONLY_GUARD" ] || [ "$g" = "$ONLY_GUARD" ] || continue
    printf '  %-16s %6s %6s %6s %6s\n' "$g" \
      "$(count "\"guard\":\"$g\"")" \
      "$(grep "\"guard\":\"$g\"" "$JSONL" | grep -c '"verdict":"pass"' | num)" \
      "$(grep "\"guard\":\"$g\"" "$JSONL" | grep -c '"verdict":"fail"' | num)" \
      "$(grep "\"guard\":\"$g\"" "$JSONL" | grep -c '"verdict":"invalid"' | num)"
  done
  echo ""
  printf '  %-16s %6s %6s %6s %6s\n' ALL \
    "$(records)" \
    "$(count '"verdict":"pass"')" \
    "$(count '"verdict":"fail"')" \
    "$(count '"verdict":"invalid"')"
  echo ""
  echo "  by expectation (from the records):"
  printf '    reject %s   accept %s   infra %s\n' \
    "$(count '"expect":"reject"')" "$(count '"expect":"accept"')" "$(count '"expect":"infra"')"
  echo "  by form:"
  printf '    mutation %s   invocation %s\n' \
    "$(count '"form":"mutation"')" "$(count '"form":"invocation"')"
  echo "  by attribution:"
  printf '    complete_guard %s   named_rule %s\n' \
    "$(count '"attribution":"complete_guard"')" "$(count '"attribution":"named_rule"')"
  echo ""
  echo "  baselines passing:        $(count '"baseline":"pass"')"
  echo "  final clean runs passing: $(count '"final_clean":"pass"')"
  echo "  restorations verified:    $(count '"restoration":"restored"')"
} > "$SUMMARY"

cat "$SUMMARY"

# ---------------------------------------------------------------------------
# Completeness. A run that silently skipped cases would otherwise report a
# clean pass over whatever subset it happened to reach.
# ---------------------------------------------------------------------------
emitted="$(records)"
if [ -n "$ONLY_GUARD" ]; then
  expected="$(reg_count_for_guard "$ONLY_GUARD")"
else
  expected="$(reg_count)"
fi

rc=0
if [ "$emitted" -ne "$expected" ]; then
  echo "causality: FAILED -- $emitted record(s) for $expected registered case(s)" >&2
  rc=1
fi
if [ "$(count '"verdict":"pass"')" -ne "$expected" ]; then
  echo "causality: FAILED -- not every case produced its intended outcome" >&2
  grep -v '"verdict":"pass"' "$JSONL" | sed 's/^/    | /' >&2
  rc=1
fi
[ "$failed_guards" -eq 0 ] || rc=1

st_assert_tree_unchanged "$TREE_BEFORE" || rc=1

# Nothing of this run's may survive it.
leftover="$(ls -d "${TMPDIR:-/tmp}"/stride-guard-* 2>/dev/null | wc -l)"
if [ "$leftover" -ne 0 ]; then
  echo "causality: WARNING -- $leftover stride-guard root(s) present after the run" >&2
  ls -d "${TMPDIR:-/tmp}"/stride-guard-* 2>/dev/null | sed 's/^/    | /' >&2
fi

echo ""
if [ "$rc" -ne 0 ]; then
  echo "causality-run: FAILED" >&2
  exit 1
fi
echo "causality-run: OK -- $emitted of $expected case(s), each caused its intended outcome"
