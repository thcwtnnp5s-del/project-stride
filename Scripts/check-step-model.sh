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
# shellcheck source=lib/selftest.sh
. "$REPO_ROOT/Scripts/lib/selftest.sh"

# `--project-root <path>` points every check at a throwaway copy instead of the
# live tree. The self-test uses it so two concurrent runs cannot clobber each
# other's probe files — which happened, repeatedly, when the self-test mutated
# the working tree in place.
PROJECT_ROOT="$REPO_ROOT"
SELF_TEST=0
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) SELF_TEST=1; shift ;;
    --project-root)
      [ $# -ge 2 ] || { echo "step-model: --project-root needs a path" >&2; exit 2; }
      PROJECT_ROOT="$(cd "$2" && pwd)" || exit 2
      shift 2
      ;;
    *) echo "step-model: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
cd "$PROJECT_ROOT"

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
# 6. `StepLedger.signature` is a DIAGNOSTIC, and may not be used as evidence.
#
# S-01A removed `GameState.signature` outright, because `SaveRepository` was
# using it to decide whether two save slots at one snapshot generation had
# diverged — and it omitted `checkpoint.cursor`, `checkpoint.originWatermarks`,
# and the contents of granted slices. Slots differing in exactly those fields
# compared equal, the fail-closed refusal did not fire, and an arbitrary slot
# was chosen; pick the further cursor and the next sync resumes past steps the
# chosen ledger never granted.
#
# `StepLedger.signature` survives with the SAME incompleteness. It is kept
# because it is honest about its scope and decides nothing: it is a legible
# line in a failure message, and the subject of the privacy tests that assert
# what it does and does not name.
#
# The closure audit then found five places using it as whole-ledger evidence —
# equality, unchanged-ledger, replay determinism. One of them reconstructed a
# `SyncCheckpoint` while dropping `originWatermarks` entirely, an omission
# nothing could catch because the summary could not see that field either. Two
# blind spots over one field, in an assertion whose whole job was "nothing else
# moved".
#
# The replacement for every one of those uses is `canonicalDurableStepLedger`.
#
# ## Why this is a file allow-list and not a shape check
#
# The obvious rule — "reject `.signature` compared against a captured value" —
# needs to parse multi-line `expect(` calls and decide which right-hand sides
# are matchers. That is a heuristic, and heuristics are how three guards in
# this repository were defeated. So the primary control is the shape this file
# already uses everywhere else: an allow-list of NAMED files, which cannot be
# satisfied by adding an occurrence.
#
# A narrow second layer rejects CAPTURE anywhere, including inside allow-listed
# files, because a diagnostic-format test never needs to hold the value: it
# asserts on it in place. Capture is what turns a summary into evidence, and it
# is textually unambiguous.
# ---------------------------------------------------------------------------
# ANY `.signature` access, not one on a receiver whose NAME looks like a
# ledger. The first version of this rule matched `(steps|ledger|before|...)`
# and its own self-test walked straight through it: `expect(a.signature,
# b.signature)` was invisible because the receivers were called `a` and `b`.
# Guessing the type from the variable name is precisely the heuristic this
# file's header says defeats guards, and it defeated this one inside an hour.
#
# Matching every `.signature` means the two OTHER types that legitimately have
# one -- ContentRegistry, and StepLedger's own declaration -- are handled the
# way everything else here is handled: by naming their files.
LEDGER_SIGNATURE='\.signature\b'

# The implementation, its one diagnostic embed, and the tests whose SUBJECT is
# the diagnostic itself. Named files, never a pattern.
#
#   step_ledger.dart   -- declares it, and uses it in its own toString
#   game_state.dart    -- embeds it in GameState.toString, the debug line
#   save_privacy_test  -- asserts it does not name an origin or a bucket, and
#                         does reduce slice detail to a cardinality
#   adapter_to_ledger  -- asserts it does not carry the durable cursor
#
# The last two are a DIFFERENT type. `ContentRegistry.signature` fingerprints
# loaded content for the determinism tests; it has nothing to do with the step
# ledger and no save decision reads it. They are listed here because this rule
# matches every `.signature` on purpose -- see above -- so the only way to say
# "that one is a different thing" is to name its file, which is also the only
# way that cannot be widened by accident.
SIGNATURE_APPROVED="
packages/stride_core/lib/src/steps/step_ledger.dart
packages/stride_core/lib/src/engine/game_state.dart
packages/stride_core/test/save_privacy_test.dart
packages/stride_health/test/adapter_to_ledger_test.dart
packages/stride_core/lib/src/content/content_registry.dart
packages/stride_core/test/production_content_test.dart
"

# Capture shapes. Rejected everywhere, allow-listed file or not.
#
# `final String x = ledger.signature` and `list.add(ledger.signature)` are how
# a value becomes something to compare against later, which is exactly the
# evidential use the rule forbids. A list LITERAL of diagnostic surfaces is not
# capture and is deliberately not matched.
SIGNATURE_CAPTURE="=[[:space:]]*[A-Za-z_][A-Za-z0-9_.]*\.signature|\.add\([A-Za-z_][A-Za-z0-9_.]*\.signature"

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

# Production AND tests. Only rule 6 uses this: the evidential misuse of a
# diagnostic lives in tests by definition, so a production-only scan would
# check the one place the defect cannot occur.
all_dart() {
  find lib test integration_test packages/*/lib packages/*/test \
    packages/*/example/lib packages/*/example/integration_test \
    packages/*/pigeons \
    -name '*.dart' -not -path '*/build/*' -not -path '*/.dart_tool/*' \
    2>/dev/null | sort
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
# 6. StepLedger.signature: allow-listed files only, and never captured.
#
# Scans TESTS as well as production, which the checks above deliberately do
# not. That is the point: every use this rule exists to prevent was in a test,
# asserting a whole-ledger property on a summary that could not see the cursor
# or the watermarks.
# ---------------------------------------------------------------------------
#
# ONE awk pass over every file, not a `sed` per file. The per-file form this
# script uses elsewhere spawns a process for each of 115 files and repeats that
# for each of the twelve guard runs a self-test performs; measured, it added
# minutes. The comment-blanking is character-for-character what `strip_comments`
# does -- `sub(/\/\/.*$/, "")` -- so the semantics are unchanged and only the
# process count differs.
signature_files=0
signature_scan="$(all_dart | tr '\n' '\0' | xargs -0 awk '{ line = $0; sub(/\/\/.*$/, "", line); print FILENAME ":" FNR ":" line }' 2>/dev/null || true)"
while IFS= read -r file; do
  [ -n "$file" ] || continue
  signature_files=$((signature_files + 1))

  hits="$(printf '%s\n' "$signature_scan" | grep -F "$file:" | grep -E "$LEDGER_SIGNATURE" | sed "s|^$file:||" || true)"
  [ -n "$hits" ] || continue

  if ! listed_in "$file" "$SIGNATURE_APPROVED"; then
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail "$file:${hit%%:*} uses StepLedger.signature outside the approved files.
      It is a DIAGNOSTIC summary, not evidence. It omits checkpoint.cursor and
      checkpoint.originWatermarks, and reduces granted slices to a count -- so
      it cannot support an equality, unchanged-ledger, replay-determinism,
      save-integrity, cursor or watermark claim, and five tests were making
      exactly those claims on it before S-01A A.2.
      Use canonicalDurableStepLedger(ledger) for a ledger-scoped claim, or
      canonicalDurableGameState(state) for a whole-state one. Both encode what
      a save file actually carries, so neither can quietly narrow.
      If this really is a diagnostic-format or privacy/redaction test, add
      '$file' to SIGNATURE_APPROVED and say in the test why the summary itself
      is the subject."
    done <<< "$hits"
    continue
  fi

  # Even here: assert on it in place, never hold it.
  captures="$(printf '%s\n' "$signature_scan" | grep -F "$file:" | grep -E "$SIGNATURE_CAPTURE" | sed "s|^$file:||" || true)"
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "$file:${hit%%:*} CAPTURES StepLedger.signature into a variable or a
      collection. An approved file may assert on the diagnostic in place; it
      may not hold the value, because holding it is how a summary becomes
      something to compare against -- and comparing against it is the whole
      failure this rule exists for. Use canonicalDurableStepLedger."
  done <<< "$captures"
done < <(all_dart)

# ---------------------------------------------------------------------------
# An empty scan must never pass silently.
# ---------------------------------------------------------------------------
if [ "$signature_files" -eq 0 ]; then
  echo "step-model: error -- no Dart sources found for the signature scan" >&2
  failures=$((failures + 1))
fi
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
if [ "$SELF_TEST" -eq 1 ]; then
  if [ "$failures" -ne 0 ]; then
    echo "step-model: refusing to self-test while the real tree is failing" >&2
    exit 1
  fi

  # ISOLATED. Every probe is written into a throwaway copy, and the guard is
  # re-run against that copy via --project-root. The live tree is never
  # written to, so two self-tests running at once cannot clobber each other's
  # probes -- which is what happened when this mutated the working tree in
  # place, repeatedly, and produced failures that had nothing to do with the
  # code under test.
  TREE_BEFORE="$(st_tree_snapshot)"
  ISO_ROOT="$(st_make_root)"
  st_copy "$ISO_ROOT" \
    lib test integration_test \
    packages/stride_core/lib packages/stride_core/test \
    packages/stride_health/lib packages/stride_health/test \
    packages/stride_health/pigeons \
    packages/stride_health/example/lib \
    packages/stride_health/example/integration_test \
    packages/stride_health/android/src/main \
    packages/stride_health/ios/stride_health/Sources \
    packages/stride_storage/lib packages/stride_storage/test \
    packages/stride_secure_store/lib packages/stride_secure_store/test

  APP_PROBE="$ISO_ROOT/lib/__step_model_probe.dart"
  HEALTH_PROBE="$ISO_ROOT/packages/stride_health/lib/src/__step_model_probe.dart"
  CORE_PROBE="$ISO_ROOT/packages/stride_core/lib/src/__step_model_probe.dart"
  TEST_PROBE="$ISO_ROOT/packages/stride_core/test/__step_model_probe_test.dart"
  SWIFT_PROBE="$ISO_ROOT/packages/stride_health/ios/stride_health/Sources/stride_health/__StepModelProbe.swift"
  ISO_PIGEON="$ISO_ROOT/$PIGEON_INPUT"
  PIGEON_BACKUP="$(mktemp)"

  cp "$ISO_PIGEON" "$PIGEON_BACKUP"
  cleanup() {
    rm -rf "$ISO_ROOT"
    rm -f "$PIGEON_BACKUP"
  }
  trap cleanup EXIT

  # The isolated copy must PASS before anything is injected, or a rejection
  # below would prove nothing -- it could be the copy being incomplete rather
  # than the probe being detected.
  if ! bash "$0" --project-root "$ISO_ROOT" >/dev/null 2>&1; then
    echo "step-model SELF-TEST FAILED: the isolated copy does not pass clean" >&2
    bash "$0" --project-root "$ISO_ROOT" >&2
    exit 1
  fi

  selftest_failures=0
  expect_reject() {
    if bash "$0" --project-root "$ISO_ROOT" >/dev/null 2>&1; then
      echo "step-model SELF-TEST FAILED: the guard accepted $1" >&2
      selftest_failures=$((selftest_failures + 1))
    else
      echo "  rejected as expected: $1"
    fi
    rm -f "$APP_PROBE" "$HEALTH_PROBE" "$CORE_PROBE" "$TEST_PROBE" "$SWIFT_PROBE"
    cp "$PIGEON_BACKUP" "$ISO_PIGEON"
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
  cat >> "$ISO_PIGEON" <<'PROBE'

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

  # 6a. A whole-ledger comparison built on StepLedger.signature, in a file that
  #     is not allow-listed. This is the A.2 defect exactly: a test claiming
  #     two ledgers are identical using a summary that cannot see the durable
  #     cursor or the per-origin watermarks.
  cat > "$TEST_PROBE" <<'PROBE'
import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

void main() {
  test('the ledger is unchanged', () {
    final StepLedger a = StepLedger.empty();
    final StepLedger b = StepLedger.empty();
    expect(a.signature, b.signature);
  });
}
PROBE
  expect_reject "a whole-ledger equality comparison on StepLedger.signature"

  # 6b. The same misuse in PRODUCTION, where it would be a save-integrity
  #     decision rather than a weak test -- which is what GameState.signature
  #     was doing in SaveRepository before A.1.
  cat > "$CORE_PROBE" <<'PROBE'
import '../steps/step_ledger.dart';

bool ledgersAgree(StepLedger a, StepLedger b) => a.signature == b.signature;
PROBE
  expect_reject "a production integrity comparison on StepLedger.signature"

  # 6c. CAPTURE inside an ALLOW-LISTED file. The allow-list exists for tests
  #     whose subject is the diagnostic itself; those assert on it in place.
  #     Holding the value is how a summary becomes evidence, and it must be
  #     rejected even where the symbol is permitted -- otherwise the allow-list
  #     is a blanket exemption rather than a scoped one.
  cp "$ISO_ROOT/packages/stride_core/test/save_privacy_test.dart" "$PIGEON_BACKUP.privacy"
  cat >> "$ISO_ROOT/packages/stride_core/test/save_privacy_test.dart" <<'PROBE'

// injected by the self-test
String capturedLedgerEvidence(StepLedger ledger) {
  final String before = ledger.signature;
  return before;
}
PROBE
  if bash "$0" --project-root "$ISO_ROOT" >/dev/null 2>&1; then
    echo "step-model SELF-TEST FAILED: the guard accepted capture in an allow-listed file" >&2
    selftest_failures=$((selftest_failures + 1))
  else
    echo "  rejected as expected: StepLedger.signature captured in an allow-listed file"
  fi
  cp "$PIGEON_BACKUP.privacy" "$ISO_ROOT/packages/stride_core/test/save_privacy_test.dart"
  rm -f "$PIGEON_BACKUP.privacy"

  # The isolated copy must pass again once every probe is gone, or a rejection
  # above was the copy being damaged rather than the probe being seen.
  if ! bash "$0" --project-root "$ISO_ROOT" >/dev/null 2>&1; then
    echo "step-model SELF-TEST FAILED: the isolated copy does not pass after cleanup" >&2
    exit 1
  fi

  cleanup
  trap - EXIT

  # And the LIVE tree must be byte-for-byte what it was. This is the property
  # the isolation exists for, and it is asserted rather than assumed.
  st_assert_tree_unchanged "$TREE_BEFORE" || exit 1

  if [ "$selftest_failures" -ne 0 ]; then
    echo "step-model: SELF-TEST FAILED -- the guard cannot detect $selftest_failures of 10 injected violations" >&2
    exit 1
  fi
  echo "step-model: self-test OK -- all 10 injected violations were rejected"
  echo "step-model: the live working tree was not modified"
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
signature_approved="$(printf '%s\n' "$SIGNATURE_APPROVED" | grep -c '\.dart' || true)"
echo "  dart files scanned for .signature : $signature_files"
echo "  StepLedger.signature files        : $signature_approved approved, 0 elsewhere"
