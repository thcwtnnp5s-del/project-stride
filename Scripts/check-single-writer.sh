#!/usr/bin/env bash
# check-single-writer.sh
#
# Enforces the binding architecture rule from DECISIONS/0013:
#
#   "No background isolate, callback, worker, or platform entry point may
#    instantiate SaveRepository, construct filesystem persistence stores, or
#    access the save directory directly."
#
# ## Why this is a script and not a comment
#
# Project Stride now runs an explicitly SINGLE-WRITER-ISOLATE persistence model.
# Its three layers are a path-keyed in-isolate mutex, an OS advisory lock across
# processes, and compare-and-swap. None of them serializes two ISOLATES: on
# POSIX `fcntl` ownership is the process, so the OS lock grants a second isolate
# the lock outright, and a Dart static is copied per isolate so the mutex cannot
# see across one. A persistence-owner isolate was prototyped and removed
# (DECISIONS/0013) rather than left as dead code pretending to be a protection
# layer.
#
# So the guarantee is not "concurrent isolates are handled". It is "there is
# exactly one writer isolate", and THIS SCRIPT is the thing that makes that
# true. Enforcement is the whole mechanism, not a reminder about one.
#
# ## Why it is not a count
#
# Two earlier guards in this repository were defeated by a closure critic, both
# for the same reason: they counted occurrences instead of anchoring them.
# One matched `\.eraseAll\s*\(` and so could not see a bare self-call; the other
# counted call sites and was satisfied by a no-op decoy while the real site was
# deleted. This script therefore enumerates APPROVED (file, symbol) pairs and
# rejects everything else. There is nothing to inflate.
#
# Run `--self-test` to falsify it: it injects a background construction and a
# plain unauthorized construction and asserts the guard rejects each. That runs
# in verify.sh and in CI, so the guard is continuously proven able to fail.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

failures=0
fail() {
  echo "single-writer: FAIL -- $1" >&2
  failures=$((failures + 1))
}

# ---------------------------------------------------------------------------
# The persistence types. Constructing any of these reaches the save directory.
# ---------------------------------------------------------------------------
SYMBOLS="SaveRepository FileSnapshotStore FileLedgerJournal FileIdentityStore FileTransactionLock StorageLayout"

# ---------------------------------------------------------------------------
# APPROVED PRODUCTION CONSTRUCTION SITES — the allow-list.
#
# `path|Symbol`. Anything not on this list is a violation. Adding a line here is
# a deliberate architectural act and should be reviewed as one: every entry is a
# place that touches the save directory, and the single-writer guarantee is only
# as good as this list is short.
# ---------------------------------------------------------------------------
APPROVED="
lib/runtime/runtime_bootstrap.dart|StorageLayout
lib/runtime/runtime_bootstrap.dart|SaveRepository
lib/runtime/runtime_bootstrap.dart|FileSnapshotStore
lib/runtime/runtime_bootstrap.dart|FileLedgerJournal
lib/runtime/runtime_bootstrap.dart|FileTransactionLock
lib/runtime/identity_vault.dart|FileIdentityStore
"

# Files that DECLARE these types. A constructor declaration is not a
# construction, and excluding the declaring file for its own type is the only
# way to tell them apart textually. Each pair is named explicitly so a new type
# cannot become exempt by accident.
DECLARING="
packages/stride_core/lib/src/save/save_repository.dart|SaveRepository
packages/stride_storage/lib/src/file_storage.dart|StorageLayout
packages/stride_storage/lib/src/file_storage.dart|FileSnapshotStore
packages/stride_storage/lib/src/file_storage.dart|FileLedgerJournal
packages/stride_storage/lib/src/file_storage.dart|FileIdentityStore
packages/stride_storage/lib/src/file_lock.dart|FileTransactionLock
"

# The reusable conformance suite. It lives under lib/ because it must be
# importable by another package's tests, but it is test infrastructure and never
# runs in an app. Named here rather than pattern-matched, so a second file
# cannot claim the same exemption by being called something similar.
CONFORMANCE="
packages/stride_storage/lib/src/conformance.dart|SaveRepository
"

# ---------------------------------------------------------------------------
# Background entry points. None exists today, and none may be added without
# S-01 first designing and validating a real persistence coordinator.
# ---------------------------------------------------------------------------
BACKGROUND_MARKERS='Isolate\.spawn|Isolate\.run|vm:entry-point|IsolateNameServer|BackgroundIsolateBinaryMessenger|[Ww]orkmanager|registerBackgroundCallback|setForegroundNotification'

production_files() {
  # Production source ONLY. Tests are excluded deliberately: a test may and does
  # construct repositories directly, which is exactly why scanning them would
  # make this guard meaningless.
  find lib packages/*/lib -name '*.dart' -not -path '*/build/*' 2>/dev/null | sort
}

listed_in() {
  printf '%s\n' "$2" | grep -qxF "$1"
}

# Strips // comments and /// doc comments so prose about these types is not a
# violation. Keeps line numbers.
strip_comments() {
  sed 's://.*$::'
}

echo "single-writer: scanning production source only"

# ---------------------------------------------------------------------------
# Check A — every construction is at an approved site
# ---------------------------------------------------------------------------
while IFS= read -r file; do
  [ -n "$file" ] || continue
  stripped="$(strip_comments < "$file")"

  for sym in $SYMBOLS; do
    # A construction or a constructor declaration: the symbol followed by `(`.
    hits="$(printf '%s\n' "$stripped" | grep -nE "(^|[^A-Za-z0-9_])${sym}\s*\(" || true)"
    [ -n "$hits" ] || continue

    key="${file}|${sym}"
    if listed_in "$key" "$APPROVED"; then continue; fi
    if listed_in "$key" "$DECLARING"; then continue; fi
    if listed_in "$key" "$CONFORMANCE"; then continue; fi

    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail "$file:${hit%%:*} constructs $sym outside the approved sites.
      The save directory has exactly one writer. If this is deliberate, add
      '$key' to APPROVED in this script and record why in DECISIONS/0013.
      If this is a background isolate, callback, worker, or platform entry
      point, it is prohibited outright until S-01 builds the coordinator."
    done <<< "$hits"
  done
done < <(production_files)

# ---------------------------------------------------------------------------
# Check B — no background entry point exists in production source
# ---------------------------------------------------------------------------
# A background isolate that does not touch persistence would be harmless in
# principle. It is still rejected, because the single-writer guarantee is an
# argument about the whole program, and re-validating it is precisely the work
# S-01 is required to do before any background writer is enabled.
while IFS= read -r file; do
  [ -n "$file" ] || continue
  hits="$(strip_comments < "$file" | grep -nE "$BACKGROUND_MARKERS" || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "$file:${hit%%:*} introduces a background execution entry point.
      No background isolate, callback, worker, or platform entry point may
      exist while the persistence model is single-writer-isolate. S-01 must
      design and validate the real persistence coordinator first.
      See DECISIONS/0013 and TECHNICAL/PERSISTENCE_CONCURRENCY.md."
  done <<< "$hits"
done < <(production_files)

# ---------------------------------------------------------------------------
# Check C — the removed prototype has not come back
# ---------------------------------------------------------------------------
if [ -f packages/stride_storage/lib/src/persistence_owner.dart ]; then
  fail "packages/stride_storage/lib/src/persistence_owner.dart is back in the
      production tree. It was removed at DECISIONS/0013 because dead code
      described as a protection layer is worse than no layer. It is preserved
      in git history; restore it only as part of S-01's real coordinator."
fi

# ---------------------------------------------------------------------------
# Self-test: prove the guard can fail
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  if [ "$failures" -ne 0 ]; then
    echo "single-writer: refusing to self-test while the real tree is failing" >&2
    exit 1
  fi

  probe="lib/runtime/__single_writer_probe.dart"
  cleanup() { rm -f "$probe"; }
  trap cleanup EXIT

  selftest_failures=0
  expect_reject() {
    if bash "$0" >/dev/null 2>&1; then
      echo "single-writer SELF-TEST FAILED: the guard accepted $1" >&2
      selftest_failures=$((selftest_failures + 1))
    else
      echo "  rejected as expected: $1"
    fi
  }

  # 1. A background isolate that constructs a repository -- the exact shape the
  #    rule names, and the shape a Health Connect worker would take.
  cat > "$probe" <<'PROBE'
import 'dart:isolate';
import 'package:stride_core/stride_core.dart';
import 'package:stride_storage/stride_storage.dart';

@pragma('vm:entry-point')
Future<void> backgroundSync(List<Object> args) async {
  final StorageLayout layout = StorageLayout(args[0] as dynamic);
  final SaveRepository repo = SaveRepository(
    snapshots: FileSnapshotStore(layout),
    journal: FileLedgerJournal(layout),
    lock: FileTransactionLock(layout.transactionLock),
  );
  await repo.compact();
}

void start() => Isolate.spawn(backgroundSync, <Object>[]);
PROBE
  expect_reject "a background isolate constructing SaveRepository"

  # 2. A plain unauthorized construction with no background marker at all, so
  #    check A is proven independently of check B.
  cat > "$probe" <<'PROBE'
import 'package:stride_core/stride_core.dart';
import 'package:stride_storage/stride_storage.dart';

SaveRepository buildAnother(StorageLayout layout) => SaveRepository(
  snapshots: FileSnapshotStore(layout),
  journal: FileLedgerJournal(layout),
  lock: FileTransactionLock(layout.transactionLock),
);
PROBE
  expect_reject "a second repository construction outside the approved sites"

  # 3. A background entry point that touches no persistence type, proving
  #    check B does not depend on check A having already fired.
  cat > "$probe" <<'PROBE'
import 'dart:isolate';

@pragma('vm:entry-point')
void harmlessWorker() {}

void start() => Isolate.spawn((_) {}, null);
PROBE
  expect_reject "a background entry point that touches no persistence type"

  cleanup
  trap - EXIT

  # And the real tree must still pass once the probes are gone, or the
  # self-test has left damage behind.
  if ! bash "$0" >/dev/null 2>&1; then
    echo "single-writer SELF-TEST FAILED: the tree does not pass after cleanup" >&2
    exit 1
  fi

  if [ "$selftest_failures" -ne 0 ]; then
    echo "single-writer: SELF-TEST FAILED -- the guard cannot detect $selftest_failures of 3 injected violations" >&2
    exit 1
  fi
  echo "single-writer: self-test OK -- all 3 injected violations were rejected"
fi

if [ "$failures" -gt 0 ]; then
  echo "" >&2
  echo "The persistence model is single-writer-isolate. Nothing serializes two" >&2
  echo "isolates: on POSIX the OS lock is per-process, and a Dart static is" >&2
  echo "per-isolate. See DECISIONS/0013 and TECHNICAL/PERSISTENCE_CONCURRENCY.md." >&2
  exit 1
fi

approved_count="$(printf '%s\n' "$APPROVED" | grep -c '|' || true)"
echo "single-writer: OK"
echo "  approved construction sites : $approved_count, in 2 files"
echo "  background entry points     : 0 (prohibited until S-01)"
echo "  owner prototype in tree     : no (removed, DECISIONS/0013)"
