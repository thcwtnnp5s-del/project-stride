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
# ## Named rules, and the two exit codes that are not the same
#
# Every check is a named production rule returning under the guard contract:
#
#   0  policy satisfied
#   1  a NAMED policy violation, reported as STRIDE_GUARD[single-writer.<rule>]
#   2  infrastructure, reported as STRIDE_INFRA[single-writer.<what>]
#
# The separation is load-bearing here. "No native source declares a background
# entry point" and "no native source was scanned" produce the same clean-looking
# result from a check that only counts findings, and one of them is a guard that
# looked at nothing. An empty scan is infrastructure: the guard has not observed
# the tree, so it must not report on it.
#
# Run `--self-test` to falsify it: five injections, each of which must be
# rejected at exit 1 BY ITS OWN diagnostic. A nonzero exit is not evidence -- a
# guard that rejects everything rejects injections too.
#
# Usage:
#   check-single-writer.sh [--project-root <path>]
#   check-single-writer.sh --self-test

# NOTE ON SOURCING: everything above `guard_main` must be free of side effects.
# No traps, no `cd`, no shell-option changes, no file creation, no rule
# execution. `Scripts/check-source-safety.sh` proves that for every guard.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/rulekit.sh
. "$SCRIPT_DIR/lib/rulekit.sh"
# shellcheck source=lib/selftest.sh
. "$SCRIPT_DIR/lib/selftest.sh"

GUARD_ID="single-writer"

# Every rule resolves its paths against this. Set by guard_main, or directly by
# the causality runner -- which is why it is a plain variable and why no rule
# calls `cd`. The old version `cd`'d at load time, so sourcing this file moved
# the caller's shell.
PROJECT_ROOT="${PROJECT_ROOT:-$REPO_ROOT}"

fail_in() { guard_fail "$GUARD_ID.$1" "$2"; }

# Reported and MATCHED relative to the project root: the allow-list below is
# written in repository-relative paths, so a lookup has to be too. Otherwise the
# same file would be approved in the live tree and unapproved in a temporary
# copy, which is the whole trick the isolation work depends on not happening.
rel() { printf '%s' "${1#"$PROJECT_ROOT"/}"; }

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

# The same rule in native source.
#
# The Dart markers above cannot see a background entry point written in Swift or
# Kotlin, and that is where the next one would be written: S-01B's whole subject
# is `HKObserverQuery` + `enableBackgroundDelivery` on iOS and a WorkManager
# worker on Android. Either would run outside the single-writer isolate, which
# is the exact configuration DECISIONS/0013 forbids until a real persistence
# coordinator exists.
#
# Anchored to the APIs, and comment-stripped before matching -- both native
# files currently carry prose saying these are deliberately absent, and a `grep`
# for the words would fail a correct tree on its own documentation. That has
# happened twice in this repository.
NATIVE_BACKGROUND='HKObserverQuery|enableBackgroundDelivery|disableBackgroundDelivery|BGTaskScheduler|BGAppRefreshTask|beginBackgroundTask|androidx\.work|WorkManager|OneTimeWorkRequest|PeriodicWorkRequest|ListenableWorker|BroadcastReceiver|JobIntentService|JobScheduler|registerReceiver'

NATIVE_DIRS="
packages/stride_health/android/src/main
packages/stride_health/ios/stride_health/Sources
"

native_files() {
  local d dirs=""
  for d in $NATIVE_DIRS; do
    [ -d "$PROJECT_ROOT/$d" ] && dirs="$dirs $PROJECT_ROOT/$d"
  done
  [ -n "$dirs" ] || return 0
  # shellcheck disable=SC2086
  find $dirs \( -name '*.kt' -o -name '*.swift' \) 2>/dev/null | sort
}

production_files() {
  # Production source ONLY. Tests are excluded deliberately: a test may and does
  # construct repositories directly, which is exactly why scanning them would
  # make this guard meaningless.
  find "$PROJECT_ROOT/lib" "$PROJECT_ROOT"/packages/*/lib \
    -name '*.dart' -not -path '*/build/*' 2>/dev/null | sort
}

listed_in() {
  printf '%s\n' "$2" | grep -qxF "$1"
}

# Strips // comments and /// doc comments so prose about these types is not a
# violation. Keeps line numbers.
strip_comments() {
  sed 's://.*$::'
}

# ---------------------------------------------------------------------------
# NAMED PRODUCTION RULES
#
# Each rule is a function, so the causality runner can exercise ONE of them
# against a mutated copy without paying for a full guard run — and, critically,
# exercises the SAME function the complete guard calls. There is no test-only
# variant of any rule: `run_all_rules` is the complete guard, and it is nothing
# but calls to these.
# ---------------------------------------------------------------------------

# rule_preflight — the guard can actually do its job.
rule_preflight() {
  [ -d "$PROJECT_ROOT" ] || \
    guard_infra "$GUARD_ID.root_missing" "project root $PROJECT_ROOT does not exist"
  local n
  n="$(production_files | grep -c . )"
  [ "${n:-0}" -gt 0 ] || \
    guard_infra "$GUARD_ID.no_dart_sources" "no production Dart sources found under $PROJECT_ROOT; an empty scan is not a clean scan"
  DART_SCANNED="${n:-0}"
}

# rule_approved_construction_sites — every construction is at an approved site
rule_approved_construction_sites() {
  local file stripped sym hits key hit relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    relpath="$(rel "$file")"
    stripped="$(strip_comments < "$file")"

    for sym in $SYMBOLS; do
      # A construction or a constructor declaration: the symbol followed by `(`.
      hits="$(printf '%s\n' "$stripped" | grep -nE "(^|[^A-Za-z0-9_])${sym}\s*\(" || true)"
      [ -n "$hits" ] || continue

      key="${relpath}|${sym}"
      if listed_in "$key" "$APPROVED"; then continue; fi
      if listed_in "$key" "$DECLARING"; then continue; fi
      if listed_in "$key" "$CONFORMANCE"; then continue; fi

      while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        fail_in approved_construction_sites "$relpath:${hit%%:*} constructs $sym outside the approved sites.
      The save directory has exactly one writer. If this is deliberate, add
      '$key' to APPROVED in this script and record why in DECISIONS/0013.
      If this is a background isolate, callback, worker, or platform entry
      point, it is prohibited outright until S-01 builds the coordinator."
      done <<< "$hits"
    done
  done <<< "$(production_files)"
}

# rule_no_dart_background_entry — no background entry point in Dart.
#
# A background isolate that does not touch persistence would be harmless in
# principle. It is still rejected, because the single-writer guarantee is an
# argument about the whole program, and re-validating it is precisely the work
# S-01 is required to do before any background writer is enabled.
rule_no_dart_background_entry() {
  local file hits hit relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    hits="$(strip_comments < "$file" | grep -nE "$BACKGROUND_MARKERS" || true)"
    [ -n "$hits" ] || continue
    relpath="$(rel "$file")"
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail_in no_dart_background_entry "$relpath:${hit%%:*} introduces a background execution entry point.
      No background isolate, callback, worker, or platform entry point may
      exist while the persistence model is single-writer-isolate. S-01 must
      design and validate the real persistence coordinator first.
      See DECISIONS/0013 and TECHNICAL/PERSISTENCE_CONCURRENCY.md."
    done <<< "$hits"
  done <<< "$(production_files)"
}

# rule_no_native_background_entry — the same rule, in Swift and Kotlin
rule_no_native_background_entry() {
  local file hits hit relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    hits="$(strip_comments < "$file" | grep -nE "$NATIVE_BACKGROUND" || true)"
    [ -n "$hits" ] || continue
    relpath="$(rel "$file")"
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail_in no_native_background_entry "$relpath:${hit%%:*} introduces a NATIVE background execution entry point.
      This is the S-01B shape: an HKObserverQuery with background delivery, or
      a WorkManager worker, running outside the single-writer isolate. The Dart
      markers cannot see it, which is exactly why it is checked here.
      See DECISIONS/0013, DECISIONS/0014, and PERSISTENCE_CONCURRENCY.md."
    done <<< "$hits"
  done <<< "$(native_files)"
}

# rule_native_scan_coverage — an empty scan is not a clean scan.
#
# INFRASTRUCTURE, not a violation, and the reclassification matters. "No native
# file declares a background entry point" and "no native file was read" are the
# same output from a check that only counts findings. Reporting the second as a
# policy violation would also mean a mutation case could be satisfied by the
# copied tree simply not containing the Swift and Kotlin directories — which is
# precisely the over-determination that left three checks in this repository
# dead while their self-test read green.
rule_native_scan_coverage() {
  local n
  n="$(native_files | grep -c . )"
  NATIVE_SCANNED="${n:-0}"
  [ "$NATIVE_SCANNED" -gt 0 ] || \
    guard_infra "$GUARD_ID.no_native_sources" "no native sources were scanned for background entry points.
      An empty scan is not a clean scan: this guard has observed nothing about
      Swift or Kotlin and must not report that they are clean."
}

# rule_no_persistence_owner — the removed prototype has not come back
rule_no_persistence_owner() {
  local p="$PROJECT_ROOT/packages/stride_storage/lib/src/persistence_owner.dart"
  [ -f "$p" ] || return 0
  fail_in no_persistence_owner "packages/stride_storage/lib/src/persistence_owner.dart is back in the
      production tree. It was removed at DECISIONS/0013 because dead code
      described as a protection layer is worse than no layer. It is preserved
      in git history; restore it only as part of S-01's real coordinator."
}

# The complete guard. Nothing but calls to the named rules above.
SINGLE_WRITER_RULES="
rule_preflight
rule_approved_construction_sites
rule_no_dart_background_entry
rule_native_scan_coverage
rule_no_native_background_entry
rule_no_persistence_owner
"

run_all_rules() {
  local r
  for r in $SINGLE_WRITER_RULES; do "$r"; done
}

guard_main() {
  PROJECT_ROOT="$REPO_ROOT"
  SELF_TEST=0
  DART_SCANNED=0
  NATIVE_SCANNED=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --project-root)
        [ $# -ge 2 ] || { echo "STRIDE_INFRA[$GUARD_ID.usage] --project-root needs a path" >&2; return 2; }
        PROJECT_ROOT="$(cd "$2" 2>/dev/null && pwd)" || {
          echo "STRIDE_INFRA[$GUARD_ID.root_missing] no such project root: $2" >&2; return 2; }
        shift 2 ;;
      --self-test) SELF_TEST=1; shift ;;
      *) echo "STRIDE_INFRA[$GUARD_ID.usage] unknown argument: $1" >&2; return 2 ;;
    esac
  done

  rule_begin
  run_all_rules
  local code=0
  rule_end || code=$?
  failures="$RULE_VIOLATIONS"

  guard_body "$code"
}

guard_body() {
  local code="$1"
  if [ "$code" -eq 2 ]; then
    echo "" >&2
    echo "single-writer: INFRASTRUCTURE failure -- the guard could not look." >&2
    return 2
  fi

  if [ "$SELF_TEST" -eq 1 ]; then
    run_self_test || return $?
  fi

  if [ "$failures" -gt 0 ]; then
    echo "" >&2
    echo "The persistence model is single-writer-isolate. Nothing serializes two" >&2
    echo "isolates: on POSIX the OS lock is per-process, and a Dart static is" >&2
    echo "per-isolate. See DECISIONS/0013 and TECHNICAL/PERSISTENCE_CONCURRENCY.md." >&2
    return 1
  fi

  local approved_count
  approved_count="$(printf '%s\n' "$APPROVED" | grep -c '|' || true)"
  echo "single-writer: OK"
  echo "  production sources scanned  : $DART_SCANNED Dart, $NATIVE_SCANNED native"
  echo "  approved construction sites : $approved_count, in 2 files"
  echo "  background entry points     : 0 (prohibited until S-01)"
  echo "  owner prototype in tree     : no (removed, DECISIONS/0013)"
}

# ---------------------------------------------------------------------------
# Self-test — isolated, never the live tree
#
# Five cases, each with a stable case ID and the diagnostic its own rule must
# emit. Recorded in `Scripts/CASE_MAP.md`, which is what the shared registry
# will consume.
#
# ISOLATED: the probe is written into a throwaway copy and the guard re-run
# against it via --project-root. This used to write into the live working tree,
# and two self-tests running at once clobbered each other's probes and produced
# failures unrelated to the code under test.
#
# A nonzero exit is NOT evidence, so each case asserts exit 1 — a POLICY
# rejection — carrying its own diagnostic, and that the probe is gone
# afterwards. Exit 2 fails the case, which is what stops an incomplete copy or
# a missing directory from standing in for a detection.
# ---------------------------------------------------------------------------
run_self_test() {
  if [ "$failures" -ne 0 ]; then
    echo "single-writer: refusing to self-test while the real tree is failing" >&2
    return 1
  fi

  local TREE_BEFORE ISO st_failures=0 st_ok=0 st_layering=0
  TREE_BEFORE="$(st_tree_snapshot)"
  ISO="$(st_make_root)"
  trap 'rm -rf "$ISO"' EXIT

  # Copied from PROJECT_ROOT explicitly, not from the caller's cwd: this guard
  # no longer cd's anywhere, so a cwd-relative copy would silently produce an
  # empty tree when run from another directory.
  # shellcheck disable=SC2086
  st_copy_from "$PROJECT_ROOT" "$ISO" lib packages/stride_core/lib packages/stride_health/lib \
    packages/stride_storage/lib packages/stride_secure_store/lib \
    packages/stride_health/android/src/main \
    packages/stride_health/ios/stride_health/Sources

  local probe="$ISO/lib/runtime/__single_writer_probe.dart"
  local swift_probe="$ISO/packages/stride_health/ios/stride_health/Sources/stride_health/__BackgroundProbe.swift"
  local kotlin_probe="$ISO/packages/stride_health/android/src/main/kotlin/com/projectstride/stride_health/__BackgroundProbe.kt"

  # The copy must pass before anything is injected, or a rejection below could
  # be the copy being incomplete rather than the probe being detected.
  if ! bash "$0" --project-root "$ISO" >/dev/null 2>&1; then
    echo "single-writer SELF-TEST FAILED: the isolated copy does not pass clean" >&2
    bash "$0" --project-root "$ISO" >&2
    rm -rf "$ISO"; trap - EXIT
    return 1
  fi

  # expect_reject <case-id> <expected-diagnostic-regex> <label> <probe-file>
  expect_reject() {
    local id="$1" want="$2" label="$3" probe_file="$4" out rc
    out="$(bash "$0" --project-root "$ISO" 2>&1)"; rc=$?

    if [ "$rc" -eq 0 ]; then
      echo "single-writer SELF-TEST FAILED [$id]: the guard ACCEPTED $label" >&2
      st_failures=$((st_failures + 1))
    elif [ "$rc" -ne 1 ]; then
      echo "single-writer SELF-TEST FAILED [$id]: $label was rejected with exit $rc (INFRASTRUCTURE), not a policy violation" >&2
      printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
      st_failures=$((st_failures + 1))
    elif ! printf '%s\n' "$out" | grep -qE "$want"; then
      echo "single-writer SELF-TEST FAILED [$id]: $label was rejected, but NOT by its own rule." >&2
      echo "    expected a diagnostic matching: $want" >&2
      printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
      st_failures=$((st_failures + 1))
    else
      st_ok=$((st_ok + 1))
      echo "  rejected as expected [$id]: $label"
    fi

    rm -f "$probe_file"
    if [ -e "$probe_file" ]; then
      echo "single-writer SELF-TEST FAILED [$id]: the probe was not removed" >&2
      st_failures=$((st_failures + 1))
    fi
  }

  local D='STRIDE_GUARD\[single-writer\.'

  # 1. A background isolate that constructs a repository -- the exact shape the
  #    rule names, and the shape a Health Connect worker would take. It trips
  #    two rules at once; it is owned by the construction rule, and case 3
  #    exists so the background rule is proven independently.
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
  expect_reject sw_background_isolate_repo "${D}approved_construction_sites\]" \
    "a background isolate constructing SaveRepository" "$probe"

  # 2. A plain unauthorized construction with no background marker at all, so
  #    the construction rule is proven independently of the background rule.
  cat > "$probe" <<'PROBE'
import 'package:stride_core/stride_core.dart';
import 'package:stride_storage/stride_storage.dart';

SaveRepository buildAnother(StorageLayout layout) => SaveRepository(
  snapshots: FileSnapshotStore(layout),
  journal: FileLedgerJournal(layout),
  lock: FileTransactionLock(layout.transactionLock),
);
PROBE
  expect_reject sw_unapproved_construction "${D}approved_construction_sites\]" \
    "a second repository construction outside the approved sites" "$probe"

  # 3. A background entry point that touches no persistence type, proving the
  #    background rule does not depend on the construction rule having fired.
  cat > "$probe" <<'PROBE'
import 'dart:isolate';

@pragma('vm:entry-point')
void harmlessWorker() {}

void start() => Isolate.spawn((_) {}, null);
PROBE
  expect_reject sw_dart_background_entry "${D}no_dart_background_entry\]" \
    "a background entry point that touches no persistence type" "$probe"

  # 4. The same rule in Swift. This is the S-01B shape exactly: an observer
  #    query asking iOS to wake the app, which the Dart markers cannot see.
  cat > "$swift_probe" <<'PROBE'
import HealthKit

final class BackgroundProbe {
  func arm(store: HKHealthStore, type: HKSampleType) {
    store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
  }
}
PROBE
  expect_reject sw_native_background_swift "${D}no_native_background_entry\]" \
    "Swift arming HealthKit background delivery" "$swift_probe"

  # 5. And in Kotlin -- a WorkManager worker, the Android half of S-01B.
  cat > "$kotlin_probe" <<'PROBE'
package com.projectstride.stride_health

import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager

internal class BackgroundProbe {
    fun schedule(wm: WorkManager, req: OneTimeWorkRequest) { wm.enqueue(req) }
}
PROBE
  expect_reject sw_native_background_kotlin "${D}no_native_background_entry\]" \
    "Kotlin scheduling a WorkManager background worker" "$kotlin_probe"

  # ------------------------------------------------------------------
  # The other direction: an EMPTY native scan must be infrastructure, not a
  # clean pass and not a policy rejection.
  #
  # Cases 4 and 5 prove the native rule fires when a background entry point is
  # present. They cannot prove the scan happened at all -- a copy missing the
  # Swift and Kotlin directories would produce no findings and look identical
  # to a clean tree. This is the case that separates them.
  # ------------------------------------------------------------------
  local saved_native="$ISO/.native-backup"
  mkdir -p "$saved_native"
  mv "$ISO/packages/stride_health/ios/stride_health/Sources" "$saved_native/ios-Sources"
  mv "$ISO/packages/stride_health/android/src/main" "$saved_native/android-main"

  local out rc
  out="$(bash "$0" --project-root "$ISO" 2>&1)"; rc=$?
  if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -qE 'STRIDE_INFRA\[single-writer\.no_native_sources\]'; then
    echo "  layering held [sw_empty_native_scan]: no native sources is INFRASTRUCTURE (exit 2), not a clean pass"
    st_layering=$((st_layering + 1))
  else
    echo "single-writer SELF-TEST FAILED [sw_empty_native_scan]: an empty native scan reported exit $rc" >&2
    printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
    st_failures=$((st_failures + 1))
  fi

  mv "$saved_native/ios-Sources" "$ISO/packages/stride_health/ios/stride_health/Sources"
  mv "$saved_native/android-main" "$ISO/packages/stride_health/android/src/main"
  rmdir "$saved_native" 2>/dev/null || true

  # The copy must pass again once every probe is gone, or a rejection above was
  # damage rather than detection.
  if ! bash "$0" --project-root "$ISO" >/dev/null 2>&1; then
    echo "single-writer SELF-TEST FAILED: the isolated copy does not pass after cleanup" >&2
    bash "$0" --project-root "$ISO" >&2
    st_failures=$((st_failures + 1))
  fi

  rm -rf "$ISO"
  trap - EXIT

  # The live tree must be byte-for-byte what it was. Asserted, not assumed.
  st_assert_tree_unchanged "$TREE_BEFORE" || return 1

  if [ "$st_failures" -ne 0 ]; then
    echo "single-writer: SELF-TEST FAILED -- $st_failures case(s) wrong" >&2
    return 1
  fi
  # Asserted, not narrated: the count used to be a string in an echo, which is
  # a second source of truth that cannot disagree with itself out loud.
  if [ "$st_ok" -ne 5 ] || [ "$st_layering" -ne 1 ]; then
    echo "single-writer: SELF-TEST FAILED -- proved $st_ok rejection case(s) and $st_layering layering case(s), expected 5 and 1" >&2
    return 1
  fi
  echo "single-writer: self-test OK -- $st_ok injected violations rejected by their own rules at exit 1, $st_layering layering case"
  return 0
}

# Source-safe entry. Sourcing defines the rules and does nothing else: no traps,
# no cd, no shell-option changes, no files, no rule execution. Proven for every
# guard by Scripts/check-source-safety.sh.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  guard_main "$@"
  exit $?
fi
