#!/usr/bin/env bash
# check-step-model.sh
#
# There is exactly ONE step-ingestion model, and this is what makes that true.
#
# ## The failure this exists to prevent
#
# `DECISIONS/0014` records what S-01A found: the codebase held two parallel
# step-ingestion models, and the platform boundary was wired to the one nothing
# used.
#
#   live  ReconcileStepSync(SyncResponse) -> GameEngine -> StepReconciler
#         per-origin StepObservation keyed by ObservationKey(origin, bucket),
#         scoped SyncCompleteness, PartialDelivery vs CompleteThrough
#
#   dead  StepProvider.fetchNewSteps -> StepFetchResult
#         flat `newSteps: int`, no origin, no completeness, no pagination
#
# The dead model was harmless while the adapters were shells. It stopped being
# harmless the moment a real adapter was written against it, because a flat
# total CANNOT express per-origin attribution, scoped completeness, or partial
# pages — so an adapter that satisfied the contract could not satisfy the core.
#
# This is the same shape as the F-06 persistence-owner finding: code that reads
# as a live layer and is reachable by nothing. That one was removed rather than
# left beside its replacement, and `Scripts/check-single-writer.sh` is what
# keeps it removed. This script is the equivalent for ingestion.
#
# ## The four things it proves
#
#   1. `StepFetchResult` is not used
#   2. `fetchNewSteps` is not used
#   3. no flat, unscoped `newSteps` platform API exists
#   4. only `ReconcileStepSync` / `SyncResponse` reaches the engine
#
# Plus one the owner's specification requires structurally rather than by
# documentation:
#
#   5. a partial page cannot advance a settled completeness watermark --
#      `CompleteThrough` and `RecoveryCompleteThrough` are constructed at ONE
#      anchored site, which returns `PartialDelivery` before reaching either of
#      them unless the page declares itself final
#
# ## Why it anchors and never counts
#
# Three guards in this repository have been defeated. Two counted occurrences
# instead of anchoring them: one matched `\.eraseAll\s*\(` and could not see a
# bare self-call, the other counted call sites and was satisfied by a no-op
# decoy while the real site was deleted. A third had an unbounded scan that
# walked past the method it was checking and matched an unrelated call two
# hundred lines later.
#
# So every check here is one of two shapes, and never a tally:
#
#   * a symbol that must appear NOWHERE in production source, with a named
#     exemption list -- absence, which cannot be inflated by adding a decoy
#   * a symbol that may appear only at enumerated (file, symbol) pairs --
#     an allow-list, which cannot be satisfied by adding an occurrence
#
# No check reads "until" anything. Every scan is per-line or per-file, bounded
# by construction.
#
# `--self-test` injects each of the five violations separately and asserts each
# is rejected. It runs in verify.sh and in CI, so the guard is continuously
# proven able to fail.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

failures=0
fail() {
  echo "step-model: FAIL -- $1" >&2
  failures=$((failures + 1))
}

# ---------------------------------------------------------------------------
# 1 & 2. The retired types and methods. These must appear NOWHERE.
#
# There is no allow-list and there must not be one: these are not types that
# have a legitimate remaining use, they are types that were deleted. A `path|
# symbol` exemption here would be a way to bring the second model back one file
# at a time, which is precisely the failure mode.
#
# `StepAnchor` and `CursorStatus` are included because they were the same era
# and the same shape -- a resurrection would arrive with them.
# ---------------------------------------------------------------------------
RETIRED_DART='StepFetchResult|StepProvider\b|StepCursor\b|StepRescan\b|StepAnchor\b|CursorStatus\b|fetchNewSteps|MockStepProvider|PlatformStepProvider'

# The same model in its platform form. `PlatformFetchResult` and
# `PlatformRescan` were the Pigeon classes; `newSteps` and `deletedSteps` were
# the flat fields that could not express a correction.
RETIRED_NATIVE='PlatformFetchResult|PlatformRescan\b|PlatformCursorStatus|fetchNewSteps|newSteps|deletedSteps'

# ---------------------------------------------------------------------------
# 3. A flat unscoped platform API must not exist in the CONTRACT.
#
# Checked against the pigeon input specifically, because that file is where a
# flat field would be introduced and where it would look most reasonable. An
# integer step count on the platform boundary is only ever legitimate as part of
# a per-origin, per-bucket observation -- which is `PlatformStepObservation`,
# and which the allow-list below names.
# ---------------------------------------------------------------------------
PIGEON_INPUT="packages/stride_health/pigeons/health_api.dart"
FLAT_STEP_FIELDS='newSteps|deletedSteps|totalSteps|stepDelta|stepCount'

# The one field on the contract that may carry a step figure, and the class it
# must live in. Named rather than pattern-matched.
OBSERVATION_CLASS='class PlatformStepObservation'

# ---------------------------------------------------------------------------
# 4. Only ReconcileStepSync reaches the engine.
#
# The command the app dispatches. Anything else that claimed to deliver steps
# into the simulation would be a second entry point, which is the two-model
# defect regardless of what its payload looked like.
# ---------------------------------------------------------------------------
INGEST_COMMAND='ReconcileStepSync'
ENGINE_INGEST_SYMBOLS='ingestSteps|applySteps|addSteps|creditSteps|grantSteps|submitSteps'

# ---------------------------------------------------------------------------
# 5. Settling completeness is constructed at ONE site.
#
# `CompleteThrough` and `RecoveryCompleteThrough` are the only two values that
# can advance a settled watermark. They are built inside
# `PlatformStepSource._completeness`, which returns `PartialDelivery` before it
# reaches either of them unless `pagination.isFinalPage` is true. Restricting
# construction to that file is what makes "a partial page may not advance a
# settled watermark" structural rather than remembered.
#
# `path|Symbol`, allow-list. The declaring file is exempted separately: a
# constructor declaration is not a construction, and naming the pair explicitly
# is the only way to tell them apart textually.
# ---------------------------------------------------------------------------
SETTLING_SYMBOLS="CompleteThrough RecoveryCompleteThrough"

SETTLING_APPROVED="
packages/stride_health/lib/src/platform_step_source.dart|CompleteThrough
packages/stride_health/lib/src/platform_step_source.dart|RecoveryCompleteThrough
"

SETTLING_DECLARING="
packages/stride_core/lib/src/steps/completeness.dart|CompleteThrough
packages/stride_core/lib/src/steps/completeness.dart|RecoveryCompleteThrough
"

# Test harnesses that must be able to SCRIPT a settled assertion, because that
# is the case under test. Both live under lib/ only because another package's
# tests import them; neither runs in an app.
#
# Named files, never a pattern -- a pattern would let a second file claim the
# same exemption by being called something similar, which is how an earlier
# guard here was defeated.
#
# Each still honours the invariant by construction, and that is the condition
# of the exemption rather than a nice property:
#
#   mock_step_source.dart  -- `observed(...)` builds a settling completeness
#       only on a final page; `partialPage(...)` cannot express one at all and
#       hard-codes PartialDelivery. There is no scriptable shape that pairs a
#       settled watermark with an outstanding page.
#   conformance.dart       -- builds a settled assertion to prove the SAVE
#       round-trips one. It never delivers a page.
SETTLING_TEST_HARNESS="
packages/stride_health/lib/src/mock_step_source.dart|CompleteThrough
packages/stride_health/lib/src/mock_step_source.dart|RecoveryCompleteThrough
packages/stride_storage/lib/src/conformance.dart|CompleteThrough
packages/stride_storage/lib/src/conformance.dart|RecoveryCompleteThrough
"

# ---------------------------------------------------------------------------
# File sets. Production source ONLY.
#
# Tests are excluded, for the same reason check-single-writer.sh excludes them:
# a test constructs these values directly and must be able to. Scanning tests
# would make the guard unmaintainable and therefore disabled.
#
# The MOCK is deliberately in scope. It lives under lib/, it is the harness the
# reconciliation scenarios run against, and it is exactly where a second model
# would be rebuilt "just for testing" and then depended on.
# ---------------------------------------------------------------------------
production_dart() {
  find lib packages/*/lib packages/*/example/lib \
    packages/*/example/integration_test packages/*/pigeons \
    -name '*.dart' -not -path '*/build/*' 2>/dev/null | sort
}

native_sources() {
  find packages/stride_health/android/src/main \
    packages/stride_health/ios/stride_health/Sources \
    \( -name '*.kt' -o -name '*.swift' \) 2>/dev/null | sort
}

listed_in() {
  printf '%s\n' "$2" | grep -qxF "$1"
}

# Blanks out `//` line comments and `/* */` block comments, keeping line
# numbers. Prose ABOUT the retired model is not a use of it -- this script's
# own subject matter is discussed at length in the doc comments of the files it
# scans, and without this every one of them would be a false positive.
strip_comments() {
  awk '
    {
      line = $0
      if (inblock) {
        if (match(line, /\*\//)) {
          line = substr(line, RSTART + 2)
          inblock = 0
        } else {
          print ""
          next
        }
      }
      while (match(line, /\/\*[^*]*\*+([^\/*][^*]*\*+)*\//)) {
        line = substr(line, 1, RSTART - 1) substr(line, RSTART + RLENGTH)
      }
      if (match(line, /\/\*/)) {
        line = substr(line, 1, RSTART - 1)
        inblock = 1
      }
      sub(/\/\/.*$/, "", line)
      print line
    }
  '
}

echo "step-model: scanning production source only"

dart_count=0
native_count=0

# ---------------------------------------------------------------------------
# Checks 1 and 2 -- the retired Dart model is gone and stays gone
# ---------------------------------------------------------------------------
while IFS= read -r file; do
  [ -n "$file" ] || continue
  dart_count=$((dart_count + 1))
  hits="$(strip_comments < "$file" | grep -nE "(^|[^A-Za-z0-9_])(${RETIRED_DART})" || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "$file:${hit%%:*} uses the retired flat step-ingestion model.
      \`StepFetchResult\`, \`StepProvider.fetchNewSteps\`, and their cursor and
      rescan types were removed at S-01A. They cannot express per-origin
      attribution, scoped completeness, or partial pages, so an adapter written
      against them cannot satisfy the reconciler. Use StepSyncSource, which
      produces the SyncResponse the core actually consumes.
      See DECISIONS/0014."
  done <<< "$hits"
done < <(production_dart)

# ---------------------------------------------------------------------------
# Checks 1 and 2, native half -- including the flat wire fields
# ---------------------------------------------------------------------------
while IFS= read -r file; do
  [ -n "$file" ] || continue
  native_count=$((native_count + 1))
  hits="$(strip_comments < "$file" | grep -nE "(^|[^A-Za-z0-9_])(${RETIRED_NATIVE})" || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "$file:${hit%%:*} uses the retired flat platform result.
      A flat \`newSteps\` cannot say WHICH source produced it, cannot
      distinguish page one from page nine, and cannot restate a bucket -- so a
      correction is unrepresentable and a deletion is indistinguishable from
      data that never existed. Send PlatformStepObservation instead: absolute,
      per origin, per bucket. See DECISIONS/0014."
  done <<< "$hits"
done < <(native_sources)

# ---------------------------------------------------------------------------
# Check 3 -- no flat unscoped step field on the contract
# ---------------------------------------------------------------------------
if [ ! -f "$PIGEON_INPUT" ]; then
  fail "$PIGEON_INPUT is missing; the platform contract cannot be checked."
else
  contract="$(strip_comments < "$PIGEON_INPUT")"

  hits="$(printf '%s\n' "$contract" | grep -nE "(^|[^A-Za-z0-9_])(${FLAT_STEP_FIELDS})" || true)"
  if [ -n "$hits" ]; then
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail "$PIGEON_INPUT:${hit%%:*} declares a flat, unscoped step figure.
      A step count on this boundary is only ever legitimate inside a per-origin,
      per-bucket observation. A bare total is the model S-01A removed."
    done <<< "$hits"
  fi

  # And the observation class must still exist, or check 3 would pass
  # vacuously on a contract that carries no step data at all.
  if ! printf '%s\n' "$contract" | grep -qF "$OBSERVATION_CLASS"; then
    fail "$PIGEON_INPUT no longer declares PlatformStepObservation.
      Absence of a flat field is only meaningful while the per-origin one
      exists. A contract with neither is not safe, it is empty."
  fi
fi

# ---------------------------------------------------------------------------
# Check 4 -- one ingestion entry point into the engine
# ---------------------------------------------------------------------------
if ! grep -rqF "class $INGEST_COMMAND" packages/stride_core/lib 2>/dev/null; then
  fail "packages/stride_core/lib no longer declares the $INGEST_COMMAND command.
      It is the only way steps enter the simulation. If it was renamed, update
      INGEST_COMMAND in this script deliberately -- a missing entry point makes
      every other check here vacuous."
fi

while IFS= read -r file; do
  [ -n "$file" ] || continue
  hits="$(strip_comments < "$file" | grep -nE "(^|[^A-Za-z0-9_])(${ENGINE_INGEST_SYMBOLS})" || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "$file:${hit%%:*} looks like a second way to deliver steps into the
      simulation. There is exactly one: dispatch $INGEST_COMMAND(SyncResponse)
      to GameEngine. A second entry point is the two-model defect again,
      whatever its payload looks like. See DECISIONS/0014."
  done <<< "$hits"
done < <(production_dart)

# ---------------------------------------------------------------------------
# Check 5 -- settling completeness is constructed at one anchored site
# ---------------------------------------------------------------------------
while IFS= read -r file; do
  [ -n "$file" ] || continue
  stripped="$(strip_comments < "$file")"

  for sym in $SETTLING_SYMBOLS; do
    hits="$(printf '%s\n' "$stripped" | grep -nE "(^|[^A-Za-z0-9_])${sym}\s*\(" || true)"
    [ -n "$hits" ] || continue

    key="${file}|${sym}"
    if listed_in "$key" "$SETTLING_APPROVED"; then continue; fi
    if listed_in "$key" "$SETTLING_DECLARING"; then continue; fi
    if listed_in "$key" "$SETTLING_TEST_HARNESS"; then continue; fi

    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail "$file:${hit%%:*} constructs $sym outside the approved site.
      These are the only two values that can advance a SETTLED completeness
      watermark, and settling a bucket a late page was about to fill buries
      those steps permanently -- that is the defect that destroyed 55,200 steps.
      They are built in PlatformStepSource._completeness, which returns
      PartialDelivery before it reaches either of them unless the page declares
      itself final. That single path is what makes 'a partial page may not
      advance a settled watermark' structural rather than remembered.
      If a second site is genuinely needed, add '$key' to SETTLING_APPROVED and
      explain in DECISIONS why the isFinalPage check is enforced there too."
    done <<< "$hits"
  done
done < <(production_dart)

# ---------------------------------------------------------------------------
# An empty scan must never pass silently.
# ---------------------------------------------------------------------------
if [ "$dart_count" -eq 0 ]; then
  echo "step-model: error -- no production Dart sources found" >&2
  failures=$((failures + 1))
fi
if [ "$native_count" -eq 0 ]; then
  echo "step-model: error -- no native sources found" >&2
  failures=$((failures + 1))
fi

# ---------------------------------------------------------------------------
# Mutation test: prove the guard can fail, one violation at a time
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  if [ "$failures" -ne 0 ]; then
    echo "step-model: refusing to self-test while the real tree is failing" >&2
    exit 1
  fi

  APP_PROBE="lib/__step_model_probe.dart"
  HEALTH_PROBE="packages/stride_health/lib/src/__step_model_probe.dart"
  CORE_PROBE="packages/stride_core/lib/src/__step_model_probe.dart"
  SWIFT_PROBE="packages/stride_health/ios/stride_health/Sources/stride_health/__StepModelProbe.swift"
  PIGEON_BACKUP="$(mktemp)"

  cp "$PIGEON_INPUT" "$PIGEON_BACKUP"
  cleanup() {
    rm -f "$APP_PROBE" "$HEALTH_PROBE" "$CORE_PROBE" "$SWIFT_PROBE"
    # Restored unconditionally. The pigeon input is a real production file and
    # the mutation test edits it, so an interrupted run must not leave it
    # damaged.
    [ -f "$PIGEON_BACKUP" ] && cp "$PIGEON_BACKUP" "$PIGEON_INPUT"
    rm -f "$PIGEON_BACKUP"
  }
  trap cleanup EXIT

  selftest_failures=0
  expect_reject() {
    if bash "$0" >/dev/null 2>&1; then
      echo "step-model SELF-TEST FAILED: the guard accepted $1" >&2
      selftest_failures=$((selftest_failures + 1))
    else
      echo "  rejected as expected: $1"
    fi
    rm -f "$APP_PROBE" "$HEALTH_PROBE" "$CORE_PROBE" "$SWIFT_PROBE"
    cp "$PIGEON_BACKUP" "$PIGEON_INPUT"
  }

  # 1. StepFetchResult comes back.
  cat > "$APP_PROBE" <<'PROBE'
class StepFetchResult {
  StepFetchResult(this.newStepCount);
  final int newStepCount;
}
PROBE
  expect_reject "StepFetchResult reintroduced in the app"

  # 2. fetchNewSteps comes back -- separately from 1, so neither check is
  #    proven only by the other having already fired.
  cat > "$HEALTH_PROBE" <<'PROBE'
abstract interface class LegacySource {
  Future<int> fetchNewSteps();
}
PROBE
  expect_reject "fetchNewSteps reintroduced in the health package"

  # 3. A flat unscoped step field appears on the platform contract. This is the
  #    one that would look most reasonable in review -- "just a total, for the
  #    summary screen" -- and it is the whole defect.
  cat >> "$PIGEON_INPUT" <<'PROBE'

class PlatformStepTotal {
  PlatformStepTotal({required this.newSteps});
  final int newSteps;
}
PROBE
  expect_reject "a flat unscoped newSteps field on the platform contract"

  # 3b. The same field in native, where the Dart contract check cannot see it.
  cat > "$SWIFT_PROBE" <<'PROBE'
import Foundation

struct StepModelProbe {
  var newSteps: Int64 = 0
}
PROBE
  expect_reject "a flat newSteps field in native source"

  # 4. A second ingestion entry point into the engine.
  cat > "$CORE_PROBE" <<'PROBE'
class LegacyIngest {
  int ingestSteps(int count) => count;
}
PROBE
  expect_reject "a second step-ingestion entry point into the engine"

  # 5. A settling completeness constructed away from the anchored site, which
  #    is how a partial page comes to advance a settled watermark.
  cat > "$HEALTH_PROBE" <<'PROBE'
import 'package:stride_core/stride_core.dart';

SyncCompleteness settleAnyway(CompletenessScope scope) =>
    CompleteThrough(throughMillis: 0, scope: scope);
PROBE
  expect_reject "CompleteThrough constructed outside the anchored site"

  cat > "$HEALTH_PROBE" <<'PROBE'
import 'package:stride_core/stride_core.dart';

SyncCompleteness settleAnyway(CompletenessScope scope) =>
    RecoveryCompleteThrough(throughMillis: 0, scope: scope);
PROBE
  expect_reject "RecoveryCompleteThrough constructed outside the anchored site"

  cleanup
  trap - EXIT

  # And the real tree must still pass once the probes are gone, or the
  # mutation test has left damage behind.
  if ! bash "$0" >/dev/null 2>&1; then
    echo "step-model SELF-TEST FAILED: the tree does not pass after cleanup" >&2
    exit 1
  fi

  if [ "$selftest_failures" -ne 0 ]; then
    echo "step-model: SELF-TEST FAILED -- the guard cannot detect $selftest_failures of 7 injected violations" >&2
    exit 1
  fi
  echo "step-model: self-test OK -- all 7 injected violations were rejected"
fi

if [ "$failures" -gt 0 ]; then
  echo "" >&2
  echo "There is one step-ingestion model: ReconcileStepSync(SyncResponse)." >&2
  echo "The flat StepProvider/StepFetchResult path was removed at S-01A, not" >&2
  echo "deprecated. Code that reads as a live layer and is reachable by nothing" >&2
  echo "has cost this project twice already -- see DECISIONS/0013 and 0014." >&2
  exit 1
fi

settling_count="$(printf '%s\n' "$SETTLING_APPROVED" | grep -c '|' || true)"
echo "step-model: OK"
echo "  dart production files scanned : $dart_count"
echo "  native sources scanned        : $native_count"
echo "  retired-model references      : 0"
echo "  flat platform step fields     : 0"
echo "  engine ingestion entry points : 1 ($INGEST_COMMAND)"
echo "  settling-completeness sites   : $settling_count, in 1 file"
