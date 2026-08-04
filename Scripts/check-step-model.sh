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
# ## What it proves
#
#   1. `StepFetchResult` and `fetchNewSteps` are not used
#   2. no flat, unscoped step field exists in native source
#   3. no flat, unscoped step field exists on the platform CONTRACT, and the
#      per-origin observation class the contract needs still exists
#   4. only `ReconcileStepSync` / `SyncResponse` reaches the engine, and that
#      command still exists to be the one way in
#   5. a partial page cannot advance a settled completeness watermark --
#      `CompleteThrough` and `RecoveryCompleteThrough` are constructed at ONE
#      anchored site, which returns `PartialDelivery` before reaching either of
#      them unless the page declares itself final
#   6. `StepLedger.signature` is a DIAGNOSTIC and is never used as evidence:
#      not for equality, not for an unchanged-ledger claim, not for replay
#      determinism, not for save integrity, not as a cursor or watermark
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
# ## Named rules, and the two exit codes that are not the same
#
# Every check is a named production rule taking an explicit project root and
# returning under the guard contract:
#
#   0  policy satisfied
#   1  a NAMED policy violation, reported as STRIDE_GUARD[step-model.<rule>]
#   2  infrastructure, reported as STRIDE_INFRA[step-model.<reason>]
#
# Exit 2 can never satisfy a rejection case. A guard that rejects everything --
# because a copied tree is incomplete, because a required file is missing,
# because an argument was misspelled -- rejects every injection too, and reads
# exactly like a working one to a test that only asks whether the exit code was
# nonzero. That is not hypothetical: three checks in `check-android-target.sh`
# were dead from the day they were written while their self-test read green.
#
# Before this conversion, every one of this guard's ten cases asserted only
# `if bash "$0" ... ; then FAIL`. Ten cases, each proving that SOMETHING went
# wrong. See `Scripts/CASE_MAP.md` for what each now proves instead.
#
# Usage:
#   check-step-model.sh [--project-root <path>]
#   check-step-model.sh --self-test

# NOTE ON SOURCING: everything above `guard_main` must be free of side effects.
# No traps, no `cd`, no shell-option changes, no file creation, and no rule
# execution. `Scripts/check-source-safety.sh` proves that for every converted
# guard, and the self-test below DEPENDS on it: each case invokes one named rule
# by sourcing this file.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/rulekit.sh
. "$SCRIPT_DIR/lib/rulekit.sh"
# shellcheck source=lib/selftest.sh
. "$SCRIPT_DIR/lib/selftest.sh"
# shellcheck source=lib/registry.sh
. "$SCRIPT_DIR/lib/registry.sh"
# shellcheck source=lib/cases.sh
. "$SCRIPT_DIR/lib/cases.sh"

GUARD_ID="step-model"

# Every rule resolves its paths against this. Set by guard_main, or directly by
# a runner sourcing this file. The old version `cd`'d into it at load time,
# which meant sourcing this script moved the caller's shell and then ran every
# check.
PROJECT_ROOT="${PROJECT_ROOT:-$REPO_ROOT}"

fail_in() { guard_fail "$GUARD_ID.$1" "$2"; }

# Reported and MATCHED relative to the project root. Every allow-list below is
# written as a repository-relative path, so a lookup has to be too -- otherwise
# the same file would be approved in the live tree and unapproved in a temporary
# copy, which is the trick the whole isolation design depends on not happening.
rel() { printf '%s' "${1#"$PROJECT_ROOT"/}"; }

# ---------------------------------------------------------------------------
# 1. The retired types and methods. These must appear NOWHERE.
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
# 2. A flat unscoped platform API must not exist in the CONTRACT.
#
# Checked against the pigeon input specifically, because that file is where a
# flat field would be introduced and where it would look most reasonable. An
# integer step count on the platform boundary is only ever legitimate as part of
# a per-origin, per-bucket observation -- which is `PlatformStepObservation`,
# and which `rule_observation_class_present` requires to still exist.
# ---------------------------------------------------------------------------
PIGEON_INPUT="packages/stride_health/pigeons/health_api.dart"
FLAT_STEP_FIELDS='newSteps|deletedSteps|totalSteps|stepDelta|stepCount'

# The one field on the contract that may carry a step figure, and the class it
# must live in. Named rather than pattern-matched.
OBSERVATION_CLASS='class PlatformStepObservation'

# ---------------------------------------------------------------------------
# 3. Only ReconcileStepSync reaches the engine.
#
# The command the app dispatches. Anything else that claimed to deliver steps
# into the simulation would be a second entry point, which is the two-model
# defect regardless of what its payload looked like.
# ---------------------------------------------------------------------------
INGEST_COMMAND='ReconcileStepSync'
INGEST_COMMAND_DIR="packages/stride_core/lib"
ENGINE_INGEST_SYMBOLS='ingestSteps|applySteps|addSteps|creditSteps|grantSteps|submitSteps'

# ---------------------------------------------------------------------------
# 4. Settling completeness is constructed at ONE site.
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
# 5. `StepLedger.signature` is a DIAGNOSTIC, and may not be used as evidence.
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
# A narrow second layer rejects CAPTURE inside allow-listed files, because a
# diagnostic-format test never needs to hold the value: it asserts on it in
# place. Capture is what turns a summary into evidence, and it is textually
# unambiguous. Outside the allow-list the first layer has already rejected the
# file, so the second layer scans exactly where the first one stops.
# ---------------------------------------------------------------------------
# ANY `.signature` access, not one on a receiver whose NAME looks like a
# ledger. The first version of this rule matched `(steps|ledger|before|...)`
# and its own self-test walked straight through it: `expect(a.signature,
# b.signature)` was invisible because the receivers were called `a` and `b`.
# Guessing the type from the variable name is precisely the heuristic this
# file's header says defeats guards, and it defeated this one inside an hour.
# `sm_signature_test_equality` keeps that receiver-name trick permanently under
# test: its probe still calls them `a` and `b`.
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

# Capture shapes. Rejected inside allow-listed files too.
#
# `final String x = ledger.signature` and `list.add(ledger.signature)` are how
# a value becomes something to compare against later, which is exactly the
# evidential use the rule forbids. A list LITERAL of diagnostic surfaces is not
# capture and is deliberately not matched.
#
# TWO syntactic forms, and both are cased separately --
# `sm_signature_capture_variable` and `sm_signature_capture_collection`. One
# case covering one branch of an alternation proves the other branch nothing:
# an edit that broke `.add(` would have left the old single case green.
SIGNATURE_CAPTURE="=[[:space:]]*[A-Za-z_][A-Za-z0-9_.]*\.signature|\.add\([A-Za-z_][A-Za-z0-9_.]*\.signature"

# ---------------------------------------------------------------------------
# File sets. Production source ONLY, except where rule 5 says otherwise.
#
# Tests are excluded, for the same reason check-single-writer.sh excludes them:
# a test constructs these values directly and must be able to. Scanning tests
# would make the guard unmaintainable and therefore disabled.
#
# The MOCK is deliberately in scope. It lives under lib/, it is the harness the
# reconciliation scenarios run against, and it is exactly where a second model
# would be rebuilt "just for testing" and then depended on.
#
# Every set is resolved against PROJECT_ROOT rather than the caller's working
# directory. A source-safe guard does not cd, and a cwd-relative `find` in a
# guard that does not cd silently scans nothing -- which here would read as
# "the retired model appears nowhere".
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# MEMOIZED per process, and that is not an optimization detail -- it is what
# keeps "every rule enumerates its own file set" affordable.
#
# Six rules read the production set and two read the signature scan, which is an
# awk pass over 115 files. Recomputing those per rule tripled the guard's
# runtime, and the self-test runs the guard thirty-odd times.
#
# The cache is per PROCESS and it is safe precisely because of that. Every
# self-test case runs `bash "$0"` or a fresh `bash -c` that sources this file,
# so each one starts with an empty cache and re-reads the mutated tree. A rule
# invoked alone therefore still behaves exactly as it does inside the complete
# guard, which is the property the whole isolation design rests on. Nothing here
# caches ACROSS a mutation.
# ---------------------------------------------------------------------------
_PRODUCTION_DART=""
_PRODUCTION_DART_READY=0
production_dart() {
  if [ "$_PRODUCTION_DART_READY" -eq 0 ]; then
    _PRODUCTION_DART="$(find "$PROJECT_ROOT/lib" \
      "$PROJECT_ROOT"/packages/*/lib \
      "$PROJECT_ROOT"/packages/*/example/lib \
      "$PROJECT_ROOT"/packages/*/example/integration_test \
      "$PROJECT_ROOT"/packages/*/pigeons \
      -name '*.dart' -not -path '*/build/*' 2>/dev/null | sort)"
    _PRODUCTION_DART_READY=1
  fi
  printf '%s\n' "$_PRODUCTION_DART"
}

# Production AND tests. Only rule 5 uses this: the evidential misuse of a
# diagnostic lives in tests by definition, so a production-only scan would
# check the one place the defect cannot occur.
_ALL_DART=""
_ALL_DART_READY=0
all_dart() {
  if [ "$_ALL_DART_READY" -eq 0 ]; then
    _ALL_DART="$(find "$PROJECT_ROOT/lib" "$PROJECT_ROOT/test" "$PROJECT_ROOT/integration_test" \
      "$PROJECT_ROOT"/packages/*/lib "$PROJECT_ROOT"/packages/*/test \
      "$PROJECT_ROOT"/packages/*/example/lib \
      "$PROJECT_ROOT"/packages/*/example/integration_test \
      "$PROJECT_ROOT"/packages/*/pigeons \
      -name '*.dart' -not -path '*/build/*' -not -path '*/.dart_tool/*' \
      2>/dev/null | sort)"
    _ALL_DART_READY=1
  fi
  printf '%s\n' "$_ALL_DART"
}

native_sources() {
  local d dirs=""
  for d in packages/stride_health/android/src/main \
           packages/stride_health/ios/stride_health/Sources; do
    [ -d "$PROJECT_ROOT/$d" ] && dirs="$dirs $PROJECT_ROOT/$d"
  done
  [ -n "$dirs" ] || return 0
  # shellcheck disable=SC2086
  find $dirs \( -name '*.kt' -o -name '*.swift' \) 2>/dev/null | sort
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

# ONE awk pass over every file, not a `sed` per file. The per-file form used
# elsewhere in this script spawns a process for each of 115 files and repeats
# that for each guard run a self-test performs; measured, it added minutes. The
# comment-blanking is character-for-character what `strip_comments` does --
# `sub(/\/\/.*$/, "")` -- so the semantics are unchanged and only the process
# count differs.
#
# Emits `<abs-path>:<line-no>:<blanked-line>`.
_SIGNATURE_SCAN=""
_SIGNATURE_SCAN_READY=0
signature_scan() {
  if [ "$_SIGNATURE_SCAN_READY" -eq 0 ]; then
    _SIGNATURE_SCAN="$(all_dart | tr '\n' '\0' \
      | xargs -0 awk '{ line = $0; sub(/\/\/.*$/, "", line); print FILENAME ":" FNR ":" line }' \
        2>/dev/null || true)"
    _SIGNATURE_SCAN_READY=1
  fi
  printf '%s\n' "$_SIGNATURE_SCAN"
}

# ---------------------------------------------------------------------------
# NAMED PRODUCTION RULES
#
# Each rule is a function taking the project root through PROJECT_ROOT, so a
# runner -- and this file's own self-test -- can exercise ONE of them against a
# mutated copy without paying for a full guard run, and, critically, exercise
# the SAME function the complete guard calls. There is no test-only variant of
# any rule: `run_all_rules` is the complete guard, and it is nothing but calls
# to these, in order.
#
# Every rule enumerates its own file set. That costs a second `find`, and buys
# the property the self-test depends on: a rule invoked alone behaves exactly as
# it does inside the complete guard.
# ---------------------------------------------------------------------------

# rule_preflight — the guard can actually do its job.
rule_preflight() {
  [ -d "$PROJECT_ROOT" ] || \
    guard_infra "$GUARD_ID.root_missing" "project root $PROJECT_ROOT does not exist"
}

# rule_dart_scan_coverage — an empty Dart scan is not a clean Dart scan.
#
# INFRASTRUCTURE. "The retired model appears in no production Dart file" and
# "no production Dart file was read" are indistinguishable in the output of a
# check that only counts findings.
rule_dart_scan_coverage() {
  local n
  n="$(production_dart | grep -c . )"
  DART_SCANNED="${n:-0}"
  [ "$DART_SCANNED" -gt 0 ] || \
    guard_infra "$GUARD_ID.no_dart_sources" "no production Dart sources found under $PROJECT_ROOT.
      An empty scan is not a clean scan: nothing has been observed about the
      Dart side of the ingestion model."
}

# rule_native_scan_coverage — and an empty native scan is not a clean one.
#
# The flat `newSteps` field this guard exists to keep dead lives natively as
# readily as it lives in Dart, and `sm_flat_native_field` is the case that
# proves the native half fires. That case can only mean something if a copy
# WITHOUT the native directories is infrastructure rather than a pass.
rule_native_scan_coverage() {
  local n
  n="$(native_sources | grep -c . )"
  NATIVE_SCANNED="${n:-0}"
  [ "$NATIVE_SCANNED" -gt 0 ] || \
    guard_infra "$GUARD_ID.no_native_sources" "no native sources found under $PROJECT_ROOT.
      An empty native scan has skipped the half of the boundary where a flat
      step field is written in Swift and Kotlin."
}

# rule_signature_scan_coverage — the signature scan read something.
#
# Separate from the production scan because it reads a DIFFERENT set: tests as
# well as production. Every use rule 5 exists to prevent was in a test, so a
# coverage claim about production says nothing about it.
rule_signature_scan_coverage() {
  local n
  n="$(all_dart | grep -c . )"
  SIGNATURE_SCANNED="${n:-0}"
  [ "$SIGNATURE_SCANNED" -gt 0 ] || \
    guard_infra "$GUARD_ID.no_signature_sources" "no Dart sources found for the signature scan under $PROJECT_ROOT.
      Rule 5 scans tests as well as production, because that is where the
      evidential misuse of a diagnostic actually occurs."
}

# rule_pigeon_input_present — the platform contract can be read at all.
#
# INFRASTRUCTURE, not a violation. A guard that cannot read the contract has
# not observed a wire field, and reporting that as a policy violation would let
# a deleted file stand in for the mutations `rule_no_flat_contract_field` and
# `rule_observation_class_present` exist to catch.
rule_pigeon_input_present() {
  [ -f "$PROJECT_ROOT/$PIGEON_INPUT" ] || \
    guard_infra "$GUARD_ID.pigeon_input_missing" "$PIGEON_INPUT is missing; the platform contract cannot be checked."
}

# rule_no_retired_dart_model — the retired Dart model is gone and stays gone.
rule_no_retired_dart_model() {
  local file hits hit relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    hits="$(strip_comments < "$file" | grep -nE "(^|[^A-Za-z0-9_])(${RETIRED_DART})" || true)"
    [ -n "$hits" ] || continue
    relpath="$(rel "$file")"
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail_in no_retired_dart_model "$relpath:${hit%%:*} uses the retired flat step-ingestion model.
      \`StepFetchResult\`, \`StepProvider.fetchNewSteps\`, and their cursor and
      rescan types were removed at S-01A. They cannot express per-origin
      attribution, scoped completeness, or partial pages, so an adapter written
      against them cannot satisfy the reconciler. Use StepSyncSource, which
      produces the SyncResponse the core actually consumes.
      See DECISIONS/0014."
    done <<< "$hits"
  done <<< "$(production_dart)"
}

# rule_no_retired_native_model — including the flat wire fields, in native.
rule_no_retired_native_model() {
  local file hits hit relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    hits="$(strip_comments < "$file" | grep -nE "(^|[^A-Za-z0-9_])(${RETIRED_NATIVE})" || true)"
    [ -n "$hits" ] || continue
    relpath="$(rel "$file")"
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail_in no_retired_native_model "$relpath:${hit%%:*} uses the retired flat platform result.
      A flat \`newSteps\` cannot say WHICH source produced it, cannot
      distinguish page one from page nine, and cannot restate a bucket -- so a
      correction is unrepresentable and a deletion is indistinguishable from
      data that never existed. Send PlatformStepObservation instead: absolute,
      per origin, per bucket. See DECISIONS/0014."
    done <<< "$hits"
  done <<< "$(native_sources)"
}

# rule_no_flat_contract_field — no flat unscoped step figure on the contract.
rule_no_flat_contract_field() {
  local p="$PROJECT_ROOT/$PIGEON_INPUT" contract hits hit
  # Absence is rule_pigeon_input_present's statement to make, and it makes it as
  # infrastructure.
  [ -f "$p" ] || return 0
  contract="$(strip_comments < "$p")"
  hits="$(printf '%s\n' "$contract" | grep -nE "(^|[^A-Za-z0-9_])(${FLAT_STEP_FIELDS})" || true)"
  [ -n "$hits" ] || return 0
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail_in no_flat_contract_field "$PIGEON_INPUT:${hit%%:*} declares a flat, unscoped step figure.
      A step count on this boundary is only ever legitimate inside a per-origin,
      per-bucket observation. A bare total is the model S-01A removed."
  done <<< "$hits"
}

# rule_observation_class_present — and the per-origin class still exists.
#
# A POLICY rule, not infrastructure, and the distinction is the whole content
# of it: the file is present and readable, and what it says is wrong. Absence
# of a flat field is only meaningful while the per-origin one exists, so a
# contract that has been emptied of both passes `rule_no_flat_contract_field`
# vacuously. This is what stops that from reading as a clean result.
rule_observation_class_present() {
  local p="$PROJECT_ROOT/$PIGEON_INPUT"
  [ -f "$p" ] || return 0
  strip_comments < "$p" | grep -qF "$OBSERVATION_CLASS" || \
    fail_in observation_class_present "$PIGEON_INPUT no longer declares PlatformStepObservation.
      Absence of a flat field is only meaningful while the per-origin one
      exists. A contract with neither is not safe, it is empty -- every
      remaining contract check would pass on it while no step data crosses the
      boundary in a shape the reconciler can use."
}

# rule_ingest_command_present — the one entry point still exists to be the one.
#
# Same shape as the rule above, and the same reason it is policy rather than
# infrastructure: `rule_single_ingest_entry_point` proves no SECOND way in
# exists, which is vacuously true of a codebase with no way in at all.
rule_ingest_command_present() {
  [ -d "$PROJECT_ROOT/$INGEST_COMMAND_DIR" ] || return 0
  grep -rqF "class $INGEST_COMMAND" "$PROJECT_ROOT/$INGEST_COMMAND_DIR" 2>/dev/null || \
    fail_in ingest_command_present "$INGEST_COMMAND_DIR no longer declares the $INGEST_COMMAND command.
      It is the only way steps enter the simulation. If it was renamed, update
      INGEST_COMMAND in this script deliberately -- a missing entry point makes
      every other ingestion check here vacuous."
}

# rule_single_ingest_entry_point — and no second way in.
rule_single_ingest_entry_point() {
  local file hits hit relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    hits="$(strip_comments < "$file" | grep -nE "(^|[^A-Za-z0-9_])(${ENGINE_INGEST_SYMBOLS})" || true)"
    [ -n "$hits" ] || continue
    relpath="$(rel "$file")"
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail_in single_ingest_entry_point "$relpath:${hit%%:*} looks like a second way to deliver steps into the
      simulation. There is exactly one: dispatch $INGEST_COMMAND(SyncResponse)
      to GameEngine. A second entry point is the two-model defect again,
      whatever its payload looks like. See DECISIONS/0014."
    done <<< "$hits"
  done <<< "$(production_dart)"
}

# rule_settling_construction_sites — settling completeness at one anchored site.
rule_settling_construction_sites() {
  local file stripped sym hits hit key relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    stripped="$(strip_comments < "$file")"
    relpath="$(rel "$file")"

    for sym in $SETTLING_SYMBOLS; do
      hits="$(printf '%s\n' "$stripped" | grep -nE "(^|[^A-Za-z0-9_])${sym}\s*\(" || true)"
      [ -n "$hits" ] || continue

      key="${relpath}|${sym}"
      if listed_in "$key" "$SETTLING_APPROVED"; then continue; fi
      if listed_in "$key" "$SETTLING_DECLARING"; then continue; fi
      if listed_in "$key" "$SETTLING_TEST_HARNESS"; then continue; fi

      while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        fail_in settling_construction_sites "$relpath:${hit%%:*} constructs $sym outside the approved site.
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
  done <<< "$(production_dart)"
}

# rule_signature_allowed_files — .signature only in named files.
#
# Scans TESTS as well as production, which every other rule here deliberately
# does not. That is the point: every use this rule exists to prevent was in a
# test, asserting a whole-ledger property on a summary that could not see the
# cursor or the watermarks.
rule_signature_allowed_files() {
  local scan file relpath hits hit
  scan="$(signature_scan)"
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    relpath="$(rel "$file")"
    listed_in "$relpath" "$SIGNATURE_APPROVED" && continue

    hits="$(printf '%s\n' "$scan" | grep -F "$file:" | grep -E "$LEDGER_SIGNATURE" || true)"
    [ -n "$hits" ] || continue

    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      hit="${hit#"$file":}"
      fail_in signature_allowed_files "$relpath:${hit%%:*} uses StepLedger.signature outside the approved files.
      It is a DIAGNOSTIC summary, not evidence. It omits checkpoint.cursor and
      checkpoint.originWatermarks, and reduces granted slices to a count -- so
      it cannot support an equality, unchanged-ledger, replay-determinism,
      save-integrity, cursor or watermark claim, and five tests were making
      exactly those claims on it before S-01A A.2.
      Use canonicalDurableStepLedger(ledger) for a ledger-scoped claim, or
      canonicalDurableGameState(state) for a whole-state one. Both encode what
      a save file actually carries, so neither can quietly narrow.
      If this really is a diagnostic-format or privacy/redaction test, add
      '$relpath' to SIGNATURE_APPROVED and say in the test why the summary
      itself is the subject."
    done <<< "$hits"
  done <<< "$(all_dart)"
}

# rule_no_signature_capture — and never held, even where it is permitted.
#
# Scans exactly the allow-listed files: outside them
# `rule_signature_allowed_files` has already rejected every occurrence, so this
# rule covers precisely the gap that one leaves. An approved file may assert on
# the diagnostic in place; holding the value is how a summary becomes something
# to compare against later, which is the evidential use the pair exists to stop.
rule_no_signature_capture() {
  local scan file relpath hits hit
  scan="$(signature_scan)"
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    relpath="$(rel "$file")"
    listed_in "$relpath" "$SIGNATURE_APPROVED" || continue

    hits="$(printf '%s\n' "$scan" | grep -F "$file:" | grep -E "$SIGNATURE_CAPTURE" || true)"
    [ -n "$hits" ] || continue

    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      hit="${hit#"$file":}"
      fail_in no_signature_capture "$relpath:${hit%%:*} CAPTURES StepLedger.signature into a variable or a
      collection. An approved file may assert on the diagnostic in place; it
      may not hold the value, because holding it is how a summary becomes
      something to compare against -- and comparing against it is the whole
      failure this rule exists for. Use canonicalDurableStepLedger."
    done <<< "$hits"
  done <<< "$(all_dart)"
}

# The complete guard. Nothing but calls to the named rules above, in order.
#
# Coverage first: a run that has read nothing should say so before it reports
# that it found nothing.
STEP_MODEL_RULES="
rule_preflight
rule_dart_scan_coverage
rule_native_scan_coverage
rule_signature_scan_coverage
rule_pigeon_input_present
rule_no_retired_dart_model
rule_no_retired_native_model
rule_no_flat_contract_field
rule_observation_class_present
rule_ingest_command_present
rule_single_ingest_entry_point
rule_settling_construction_sites
rule_signature_allowed_files
rule_no_signature_capture
"

run_all_rules() {
  local r
  for r in $STEP_MODEL_RULES; do "$r"; done
}

guard_main() {
  PROJECT_ROOT="$REPO_ROOT"
  SELF_TEST=0
  DART_SCANNED=0
  NATIVE_SCANNED=0
  SIGNATURE_SCANNED=0
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
    echo "step-model: INFRASTRUCTURE failure -- the guard could not look." >&2
    return 2
  fi

  if [ "$SELF_TEST" -eq 1 ]; then
    run_self_test || return $?
  fi

  if [ "$failures" -gt 0 ]; then
    echo "" >&2
    echo "There is one step-ingestion model: ReconcileStepSync(SyncResponse)." >&2
    echo "The flat StepProvider/StepFetchResult path was removed at S-01A, not" >&2
    echo "deprecated. Code that reads as a live layer and is reachable by nothing" >&2
    echo "has cost this project twice already -- see DECISIONS/0013 and 0014." >&2
    return 1
  fi

  local settling_count signature_approved
  settling_count="$(printf '%s\n' "$SETTLING_APPROVED" | grep -c '|' || true)"
  signature_approved="$(printf '%s\n' "$SIGNATURE_APPROVED" | grep -c '\.dart' || true)"
  echo "step-model: OK"
  echo "  dart production files scanned : $DART_SCANNED"
  echo "  native sources scanned        : $NATIVE_SCANNED"
  echo "  retired-model references      : 0"
  echo "  flat platform step fields     : 0"
  echo "  engine ingestion entry points : 1 ($INGEST_COMMAND)"
  echo "  settling-completeness sites   : $settling_count, in 1 file"
  echo "  dart files scanned for .signature : $SIGNATURE_SCANNED"
  echo "  StepLedger.signature files        : $signature_approved approved, 0 elsewhere"
}

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Self-test — registry-driven, isolated, never the live tree
#
# This guard holds no case inventory of its own. All seventeen cases — their
# probes, their declared changed-path sets, their expected exit codes and their
# expected diagnostics — live in `Scripts/lib/cases.sh`, and the runner in
# `Scripts/lib/registry.sh` refuses to run if any mutation machinery comes back
# here. A second inventory is a second source of truth, and the count it carries
# is the thing that drifted: the old summary said "10 injected violations" while
# the loop counted a different set.
#
# The runner asserts, per case:
#
#   * the COMPLETE guard produces the case's expected outcome. For the thirteen
#     rejection cases that is exit 1 with the case's own STRIDE_GUARD
#     diagnostic. A nonzero exit is NOT evidence — before the named-rule
#     conversion every case here asserted only `if bash "$0" ...; then FAIL`,
#     which is ten cases each proving that SOMETHING went wrong. Exit 2 fails a
#     rejection case outright, and so does a STRIDE_INFRA line anywhere in the
#     output
#   * the complete guard names NO OTHER rule. Carried by each case's `forbid`,
#     which covers every step-model diagnostic except its own. A case another
#     rule fires on first is over-determined and proves nothing about the rule
#     it is filed under; none of the thirteen is, and the `forbid` is what keeps
#     that true rather than recording that it once was
#   * the NAMED RULE, invoked ALONE against the same mutated root, exits 1 with
#     its own diagnostic. Every rejection case here carries
#     `attribution: named_rule` — this guard's embedded self-test asserted the
#     rule alone for all thirteen, and migrating any of them to complete-guard
#     attribution would drop an assertion that currently holds. It is possible
#     only because sourcing this guard is inert, which is what
#     `Scripts/check-source-safety.sh` exists to prove
#   * for the four infrastructure cases, exit 2 with the exact STRIDE_INFRA
#     diagnostic and no policy diagnostic at all. Every content rule in this
#     guard is an ABSENCE check, and a tree the guard cannot read produces
#     absence too: missing Dart sources, missing native sources, a missing
#     Pigeon input, an invalid invocation and a missing project root are things
#     the guard could not look at, never things it looked at and rejected. Two
#     are layering cases and two are `form=invocation`, which touch no file
#   * the probe changed exactly the paths it declared, and no others
#   * the isolated root's fingerprint — existence, bytes, type, mode and symlink
#     target of every path — is identical after restoration, so no case can pass
#     on the previous case's leftovers
#
# Counts are DERIVED from the registry and printed by the runner. There is no
# number written down in this file to disagree with them.
# ---------------------------------------------------------------------------
STEP_MODEL_SELFTEST_PATHS="
lib
test
integration_test
packages/stride_core/lib
packages/stride_core/test
packages/stride_health/lib
packages/stride_health/test
packages/stride_health/pigeons
packages/stride_health/example/lib
packages/stride_health/example/integration_test
packages/stride_health/android/src/main
packages/stride_health/ios/stride_health/Sources
packages/stride_storage/lib
packages/stride_storage/test
packages/stride_secure_store/lib
packages/stride_secure_store/test
"

run_self_test() {
  if [ "$failures" -ne 0 ]; then
    echo "step-model: refusing to self-test while the real tree is failing" >&2
    return 1
  fi

  # The Pigeon input by content, named individually. The registry runner already
  # asserts the whole live tree is unchanged; this says WHICH file and WHY. Three
  # cases rewrite a COPY of it, and CI diff-checks the generated bindings against
  # a regeneration, so a damaged input would surface as an unrelated failure in
  # another job.
  local live_pigeon rc=0
  live_pigeon="$(st_file_digest "$PROJECT_ROOT/$PIGEON_INPUT")"

  # shellcheck disable=SC2086
  reg_selftest "$GUARD_ID" "$0" "$STEP_MODEL_RULES" -- $STEP_MODEL_SELFTEST_PATHS || rc=$?

  if [ "$live_pigeon" != "$(st_file_digest "$PROJECT_ROOT/$PIGEON_INPUT")" ]; then
    echo "step-model SELF-TEST FAILED: the LIVE Pigeon input was modified." >&2
    return 1
  fi
  echo "  pigeon input: byte-identical"

  return $rc
}

# Source-safe entry. Sourcing defines the rules and does nothing else: no traps,
# no cd, no shell-option changes, no files, no rule execution. Proven for every
# converted guard by Scripts/check-source-safety.sh, and depended on by this
# file's own self-test, which invokes one named rule per case.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  guard_main "$@"
  exit $?
fi
