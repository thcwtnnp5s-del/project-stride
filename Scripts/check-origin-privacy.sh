#!/usr/bin/env bash
# check-origin-privacy.sh
#
# Enforces the origin-privacy rule from GAME_BIBLE/HEALTH_INTEGRATION and
# DECISIONS/0012:
#
#   "Never persist: raw HealthKit or Health Connect records, sub-bucket exact
#    timestamps, device names, source display names, workout categories,
#    location, heart data, or original native payloads."
#
#   "No raw platform identifier crosses into stride_core."
#
# ## Why this is a script and not a comment
#
# Origin keying happens in Swift and Kotlin, before the value crosses Pigeon
# (owner ruling). A raw platform identifier never reaches Dart, and the wire
# carries eight opaque bytes rather than a String — so there is no field a
# bundle identifier or a device name can travel in.
#
# The type system carries part of the weight: `StepOriginKey` accepts sixteen
# lowercase hex characters or the reserved literal `unknown`, so "Rob's iPhone"
# is not a representable value. What no type can carry is the rest of it:
#
#   * that native reads `bundleIdentifier` and not `HKSource.name`
#   * that the raw value never reaches a device log
#   * that the wire field stays `Uint8List` and is not "simplified" to a String
#   * that native consumes the app's identity rather than minting a second one
#   * that neither the cursor nor the salt is written to a durable native store
#
# Every one of those is a property of source text across three languages, which
# is exactly the kind of property a script can hold and a review cannot.
#
# ## Why it is not a count
#
# Three earlier guards in this repository were defeated. Two counted occurrences
# instead of anchoring them: one matched `\.eraseAll\s*\(` and could not see a
# bare self-call, the other counted call sites and was satisfied by a no-op
# decoy while the real site was deleted. A third scanned unbounded and walked
# past the method it was checking.
#
# So: this script enumerates APPROVED (file, symbol) pairs and rejects
# everything else. There is nothing to inflate. Every scan is line-anchored or
# file-anchored; nothing here reads "until it finds" anything.
#
# ## Named rules, and the two exit codes that are not the same
#
# Every check is a named production rule returning under the guard contract:
#
#   0  policy satisfied
#   1  a NAMED policy violation, reported as STRIDE_GUARD[origin-privacy.<rule>]
#   2  infrastructure, reported as STRIDE_INFRA[origin-privacy.<reason>]
#
# The separation is load-bearing in a privacy guard more than anywhere else,
# because both failure modes here produce a clean-looking run. "No file names a
# raw identifier" and "no file was read" are the same output from a check that
# only counts findings, and one of them is a guard that looked at nothing. An
# empty Dart scan, an empty native scan, and a missing Pigeon contract are
# therefore infrastructure: the guard has not observed the boundary, so it must
# not certify it.
#
# A rejection is valid only at exit 1 with its own diagnostic. A nonzero exit is
# not evidence — a guard that rejects everything rejects injections too, which
# is how three checks in this repository stayed dead while their self-test read
# green.
#
# Usage:
#   check-origin-privacy.sh [--project-root <path>]
#   check-origin-privacy.sh --self-test

# NOTE ON SOURCING: everything above `guard_main` must be free of side effects.
# No traps, no `cd`, no shell-option changes, no file creation, no rule
# execution, and nothing that touches the generated bindings.
# `Scripts/check-source-safety.sh` proves that for every converted guard.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/rulekit.sh
. "$SCRIPT_DIR/lib/rulekit.sh"
# shellcheck source=lib/selftest.sh
. "$SCRIPT_DIR/lib/selftest.sh"

GUARD_ID="origin-privacy"

# Every rule resolves its paths against this. Set by guard_main, or directly by
# the causality runner — which is why it is a plain variable and why no rule
# calls `cd`. The old version `cd`'d at load time, so sourcing this file moved
# the caller's shell and then ran every check.
PROJECT_ROOT="${PROJECT_ROOT:-$REPO_ROOT}"

fail_in() { guard_fail "$GUARD_ID.$1" "$2"; }

# Reported and MATCHED relative to the project root. The exemptions below are
# written as repository-relative paths, so a lookup has to be too -- otherwise
# the same file would be exempt in the live tree and non-exempt in a temporary
# copy, which is the trick the whole isolation design depends on not happening.
rel() { printf '%s' "${1#"$PROJECT_ROOT"/}"; }

# ---------------------------------------------------------------------------
# The raw field name that used to exist on the wire.
#
# Under the owner's ruling, keying happens natively and no raw identifier
# crosses Pigeon at all — so the allow-list for this symbol in Dart is now
# EMPTY. The check has not become vacuous, it has become absolute: naming a raw
# source identifier anywhere in production Dart means the boundary has been
# reopened.
#
# `production_dart` includes the GENERATED bindings, deliberately: a regenerated
# `messages.g.dart` that reintroduces a raw-identifier field is exactly the
# regression this must catch, and it is one Pigeon input edit away.
# ---------------------------------------------------------------------------
RAW_SYMBOL='sourceIdentifiers?'

# ---------------------------------------------------------------------------
# APPROVED SITES — the allow-list, deliberately empty.
#
# `path|symbol`. It stays empty. If a raw identifier ever needs to reach Dart
# again, that is a reversal of an owner ruling and belongs in DECISIONS before
# it belongs here.
# ---------------------------------------------------------------------------
APPROVED=""

# ---------------------------------------------------------------------------
# The wire types that must stay opaque bytes.
#
# `PlatformStepObservation.originKey` and `PlatformOriginScope.originKeys` are
# `Uint8List` on purpose: there is no String field for a bundle identifier or a
# device name to travel in. `rule_pigeon_origin_opaque` asserts that the pigeon
# input still declares them that way, because the cheapest possible regression
# here is someone "simplifying" a byte array back into a String.
# ---------------------------------------------------------------------------
PIGEON_INPUT="packages/stride_health/pigeons/health_api.dart"
OPAQUE_ORIGIN_FIELDS="originKey originKeys"

# ---------------------------------------------------------------------------
# Native identity minting. This plugin CONSUMES the app's device-bound identity
# and must never create or cache a second one.
#
# A second identity re-keys every origin. Re-keyed origins have no
# `grantedSlices`, so their recent buckets look ungranted and the whole
# retention window is granted a second time — the double-grant
# `LoadRefusal.originKeyReset` exists to prevent, and it is undetectable once it
# happens.
# ---------------------------------------------------------------------------
NATIVE_IDENTITY_MINTING='SecRandomCopyBytes|arc4random|UUID\(\)|NSUUID|randomUUID|SecureRandom|Random\(\)|kSecClass'

# ---------------------------------------------------------------------------
# Display-name shapes that must never appear anywhere on the health or save
# data path, with NO allow-list at all.
#
# `displayName` is deliberately absent: it is a content concept in this project
# (item names, region names) and banning it would train people to disable the
# guard. The names here are health-source shapes and nothing else.
# ---------------------------------------------------------------------------
DART_DISPLAY_NAME='deviceName|sourceName|sourceDisplayName|hkSourceName|productType|localIdentifier|deviceModel|deviceManufacturer'

# Scoped to the data path, not the whole app. A future settings screen may
# legitimately hold a device label the player typed; a save writer may not.
DART_DATA_PATH_DIRS="packages/stride_core/lib packages/stride_storage/lib packages/stride_health/lib"

# ---------------------------------------------------------------------------
# Native display-name APIs. Anchored to the API, not to the word.
#
# `HKSource.name` is a device name a player may have called anything at all,
# and it is the obvious implementation of the field it would fill. Health
# Connect's `Device.model` / `.manufacturer` are the same mistake in Kotlin.
# ---------------------------------------------------------------------------
NATIVE_DISPLAY_NAME='HKDevice|HKSource\.name|source\.name|sourceRevision\.source\.name|sourceRevision\.productType|Build\.MODEL|Build\.MANUFACTURER|device\??\.model|device\??\.manufacturer|\.localIdentifier|\.deviceName|UIDevice'

# ---------------------------------------------------------------------------
# Durable native stores. The cursor commit order is inviolable: the adapter
# returns a candidate cursor and forgets it; the ledger and snapshot commit;
# only then is the cursor durable. A cursor cached natively would claim progress
# the ledger never recorded, and an interrupted sync would be unrecoverable.
#
# `NSKeyedArchiver` is deliberately NOT here: archiving an `HKQueryAnchor` into
# `Data` is how the opaque cursor is produced in the first place. Serializing is
# fine; STORING is the violation.
# ---------------------------------------------------------------------------
# The same list also protects the KEYING SALT, which is now handed to native
# through `installOriginKeying` and must live in memory only, for the lifetime
# of the engine attachment. A salt written to a durable store would outlive the
# identity that owns it and survive an app-data clear the save did not.
NATIVE_PERSISTENCE='UserDefaults|NSUserDefaults|SharedPreferences|getSharedPreferences|preferencesDataStore|androidx\.datastore|openFileOutput|FileManager\.default\.createFile|SecItemAdd|SecItemCopyMatching'

# ---------------------------------------------------------------------------
# Diagnostic sinks. A line that names the raw symbol AND any of these is a leak,
# whichever file it is in — including an approved one.
# ---------------------------------------------------------------------------
DART_SINK='print\(|debugPrint\(|developer\.log\(|log\(|stderr|stdout|throw |Exception\(|Error\(|\$'
NATIVE_SINK='print\(|NSLog|os_log|Logger|println\(|Log\.[dveiw]\('

# ---------------------------------------------------------------------------
# The platform boundary value types.
#
# These exist because of a real leak this guard found on its first run:
# Pigeon generates a `toString()` for every class, and
# `PlatformStepObservation.toString()` interpolates `sourceIdentifier`. So a
# single `print(page)` anywhere, or a `PlatformException` that includes the
# argument, would put a device identifier into a log -- without the word
# `sourceIdentifier` appearing at that call site at all.
#
# The generated file cannot be edited: CI diff-checks it against a regeneration,
# and Pigeon offers no way to suppress `toString`. So the generated `toString`
# is exempted BY NAME below and `rule_no_platform_value_sink` is the
# compensating control: nothing may put one of these values on a diagnostic
# sink. An unreachable leak is a guarded leak; a pattern-matched exemption would
# be neither.
# ---------------------------------------------------------------------------
PLATFORM_VALUE_TYPES='PlatformStepObservation|PlatformOriginScope|PlatformCompleteness|PlatformSyncPage|PlatformSyncRequest|PlatformTimeBucket'

# ---------------------------------------------------------------------------
# NAMED EXEMPTIONS. Each is one file and one check, with its reason.
#
# Named, never pattern-matched: a pattern would let a second file claim the same
# exemption by being called something similar, which is precisely how an earlier
# guard in this repository was defeated.
# ---------------------------------------------------------------------------

# The reusable save-conformance suite lists forbidden strings -- 'deviceName',
# 'HKSource', 'iPhone' -- in order to assert that NONE of them appears in a
# written save. It is the privacy assertion, not a breach of it. It lives under
# lib/ only because another package's tests must import it.
DISPLAY_NAME_EXEMPT="packages/stride_storage/lib/src/conformance.dart"

# Pigeon's generated `toString`. See PLATFORM_VALUE_TYPES above;
# `rule_no_platform_value_sink` is what makes this exemption safe rather than
# merely convenient.
SINK_EXEMPT="packages/stride_health/lib/src/messages.g.dart"

# The core's own list of forbidden imports names 'package:stride_health/'. The
# core declaring a package off-limits is the rule, not a violation of it.
CORE_BOUNDARY_EXEMPT="packages/stride_core/lib/src/core_info.dart"

# stride_core knows nothing about the platform boundary.
CORE_FORBIDDEN="${RAW_SYMBOL}|messages\.g\.dart|package:stride_health|HealthHostApi|PlatformStepObservation|PlatformSyncPage"

# ---------------------------------------------------------------------------
# File sets. Production source ONLY.
#
# Tests are excluded deliberately, and this is the same reasoning
# check-single-writer.sh uses: a test constructs a raw platform identifier on
# purpose -- `PlatformStepObservation(sourceIdentifier: "Rob's iPhone")` is how
# test/origin_privacy_test.dart proves a display name cannot survive the
# boundary. Scanning tests would make this guard unmaintainable and therefore
# disabled.
#
# Both sets are resolved against PROJECT_ROOT rather than the caller's working
# directory. A source-safe guard does not cd, and a cwd-relative `find` in a
# guard that does not cd silently scans nothing -- which in a privacy guard
# would read as "no raw identifier found anywhere".
# ---------------------------------------------------------------------------
production_dart() {
  find "$PROJECT_ROOT/lib" \
    "$PROJECT_ROOT"/packages/*/lib \
    "$PROJECT_ROOT"/packages/*/example/lib \
    "$PROJECT_ROOT"/packages/*/example/integration_test \
    "$PROJECT_ROOT"/packages/*/pigeons \
    -name '*.dart' -not -path '*/build/*' 2>/dev/null | sort
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
# numbers. Both forms are needed: this file's own subject matter is discussed at
# length in Dart `///` docs and in Kotlin/Swift `/** */` docs, and prose about a
# forbidden API is not a use of it.
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

# ---------------------------------------------------------------------------
# NAMED PRODUCTION RULES
#
# Each rule is a function, so the causality runner can exercise ONE of them
# against a mutated copy without paying for a full guard run — and, critically,
# exercises the SAME function the complete guard calls. There is no test-only
# variant of any rule: `run_all_rules` is the complete guard, and it is nothing
# but calls to these, in order.
#
# Every rule enumerates its own file set. That costs a second `find`, and buys
# the property the runner depends on: a rule invoked alone behaves exactly as it
# does inside the complete guard.
# ---------------------------------------------------------------------------

# rule_preflight — the guard can actually do its job.
rule_preflight() {
  [ -d "$PROJECT_ROOT" ] || \
    guard_infra "$GUARD_ID.root_missing" "project root $PROJECT_ROOT does not exist"
}

# rule_dart_scan_coverage — an empty Dart scan is not a clean Dart scan.
#
# INFRASTRUCTURE. "No production Dart file names a raw identifier" and "no
# production Dart file was read" are indistinguishable in the output of a check
# that only counts findings, and certifying the second as privacy-clean is the
# worst failure this guard could have.
rule_dart_scan_coverage() {
  local n
  n="$(production_dart | grep -c . )"
  DART_SCANNED="${n:-0}"
  [ "$DART_SCANNED" -gt 0 ] || \
    guard_infra "$GUARD_ID.no_dart_sources" "no production Dart sources found under $PROJECT_ROOT.
      An empty scan is not a clean scan: nothing has been observed about the
      Dart side of the boundary."
}

# rule_native_scan_coverage — and an empty native scan is not a clean one.
#
# Raw identifiers LIVE natively under the owner's ruling -- Swift and Kotlin are
# where keying happens and where the only raw values exist at all. A native scan
# that read nothing has skipped the half of the boundary that actually holds the
# secret.
rule_native_scan_coverage() {
  local n
  n="$(native_sources | grep -c . )"
  NATIVE_SCANNED="${n:-0}"
  [ "$NATIVE_SCANNED" -gt 0 ] || \
    guard_infra "$GUARD_ID.no_native_sources" "no native sources found under $PROJECT_ROOT.
      Origin keying happens in Swift and Kotlin, so an empty native scan has
      skipped the half of the boundary where raw identifiers actually exist."
}

# rule_raw_identifier_sites — the raw identifier is named only at approved sites
rule_raw_identifier_sites() {
  local file stripped hits hit relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    relpath="$(rel "$file")"
    stripped="$(strip_comments < "$file")"

    hits="$(printf '%s\n' "$stripped" | grep -nE "(^|[^A-Za-z0-9_])${RAW_SYMBOL}\b" || true)"
    [ -n "$hits" ] || continue

    if listed_in "${relpath}|sourceIdentifier" "$APPROVED"; then continue; fi

    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail_in raw_identifier_sites "$relpath:${hit%%:*} names the raw platform source identifier.
      A raw identifier exists only between the Pigeon boundary and
      OriginGateway, and only inside that one call. If this is deliberate, add
      '${relpath}|sourceIdentifier' to APPROVED in this script and record why --
      but the answer is almost always to take a StepOriginKey instead."
    done <<< "$hits"
  done <<< "$(production_dart)"
}

# rule_no_dart_display_name — no display-name shape on the health or save path
rule_no_dart_display_name() {
  local dir file hits hit relpath
  for dir in $DART_DATA_PATH_DIRS; do
    [ -d "$PROJECT_ROOT/$dir" ] || continue
    while IFS= read -r file; do
      [ -n "$file" ] || continue
      relpath="$(rel "$file")"
      [ "$relpath" = "$DISPLAY_NAME_EXEMPT" ] && continue
      hits="$(strip_comments < "$file" | grep -nE "$DART_DISPLAY_NAME" || true)"
      [ -n "$hits" ] || continue
      while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        fail_in no_dart_display_name "$relpath:${hit%%:*} uses a device or source display-name shape on the
      data path. A player may have called their phone anything at all, and the
      owner's ruling forbids persisting device names, source display names, or
      HKSource.name. Pseudonymize at the boundary instead."
      done <<< "$hits"
    done <<< "$(find "$PROJECT_ROOT/$dir" -name '*.dart' -not -path '*/build/*' 2>/dev/null | sort)"
  done
}

# rule_no_native_display_name — no native display-name API
rule_no_native_display_name() {
  local file hits hit relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    hits="$(strip_comments < "$file" | grep -nE "$NATIVE_DISPLAY_NAME" || true)"
    [ -n "$hits" ] || continue
    relpath="$(rel "$file")"
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail_in no_native_display_name "$relpath:${hit%%:*} reads a platform display name.
      Send HKSource.bundleIdentifier on iOS and
      metadata.dataOrigin.packageName on Android. A display name hashed into an
      origin key is worse than useless: it looks correct."
    done <<< "$hits"
  done <<< "$(native_sources)"
}

# rule_no_dart_raw_sink — the raw identifier never reaches a Dart diagnostic.
#
# Applies to EVERY production file, including any approved one. Approval is
# permission to convert a raw value, never permission to print one. The scan is
# per-line and therefore bounded by construction -- it cannot walk past the
# thing it is checking.
rule_no_dart_raw_sink() {
  local file hits hit relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    relpath="$(rel "$file")"
    [ "$relpath" = "$SINK_EXEMPT" ] && continue
    hits="$(strip_comments < "$file" \
      | grep -nE "(^|[^A-Za-z0-9_])${RAW_SYMBOL}\b" \
      | grep -E "$DART_SINK" || true)"
    [ -n "$hits" ] || continue
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail_in no_dart_raw_sink "$relpath:${hit%%:*} puts the raw source identifier on a diagnostic
      surface -- a log, an interpolated string, or an exception message. Every
      one of those is a place a device name ends up readable. Report the
      StepOriginKey, or report nothing."
    done <<< "$hits"
  done <<< "$(production_dart)"
}

# rule_no_native_raw_sink — and never reaches a native one.
#
# This is where raw identifiers actually live now, so this is where the sink
# check earns its place: device logs are readable, exportable, and outlive the
# app.
rule_no_native_raw_sink() {
  local file hits hit relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    hits="$(strip_comments < "$file" \
      | grep -nE "(^|[^A-Za-z0-9_])${RAW_SYMBOL}\b" \
      | grep -E "$NATIVE_SINK" || true)"
    [ -n "$hits" ] || continue
    relpath="$(rel "$file")"
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail_in no_native_raw_sink "$relpath:${hit%%:*} logs a raw source identifier natively. Device logs
      are readable, exportable, and outlive the app."
    done <<< "$hits"
  done <<< "$(native_sources)"
}

# rule_core_boundary_isolation — stride_core knows nothing about the boundary.
#
# A separate rule rather than part of `rule_raw_identifier_sites`, so it is
# falsified independently: the core's ignorance of platform types is the
# property the whole port design rests on, and it should not depend on an
# allow-list staying short somewhere else.
rule_core_boundary_isolation() {
  local file hits hit relpath
  [ -d "$PROJECT_ROOT/packages/stride_core/lib" ] || return 0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    relpath="$(rel "$file")"
    [ "$relpath" = "$CORE_BOUNDARY_EXEMPT" ] && continue
    hits="$(strip_comments < "$file" | grep -nE "$CORE_FORBIDDEN" || true)"
    [ -n "$hits" ] || continue
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail_in core_boundary_isolation "$relpath:${hit%%:*} reaches the platform boundary from inside
      stride_core. The core consumes a SyncResponse and holds no opinion about
      where it came from -- that is what keeps it pure, testable in
      milliseconds, and free of any raw identifier."
    done <<< "$hits"
  done <<< "$(find "$PROJECT_ROOT/packages/stride_core/lib" -name '*.dart' 2>/dev/null | sort)"
}

# rule_no_native_durable_store — no natively cached cursor, and no stored salt
rule_no_native_durable_store() {
  local file hits hit relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    hits="$(strip_comments < "$file" | grep -nE "$NATIVE_PERSISTENCE" || true)"
    [ -n "$hits" ] || continue
    relpath="$(rel "$file")"
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail_in no_native_durable_store "$relpath:${hit%%:*} opens a durable native store.
      The cursor commit order is inviolable: the adapter returns a candidate
      cursor and forgets it; reconciliation produces grants; the ledger and
      snapshot commit; only THEN is the cursor durable. A natively cached
      cursor claims progress the ledger never recorded, and makes an
      interrupted sync unrecoverable. See DECISIONS/0012 and 0013."
    done <<< "$hits"
  done <<< "$(native_sources)"
}

# rule_no_platform_value_sink — no platform boundary VALUE reaches a diagnostic.
#
# The compensating control for the generated-toString exemption, and the check
# this guard earned on its first run. `PlatformStepObservation.toString()`
# interpolates the raw identifier, so `print(page)` leaks a device identity
# without the word `sourceIdentifier` appearing anywhere near the call.
# `rule_no_dart_raw_sink` cannot see that; this can.
#
# Per-line, so it is bounded by construction.
rule_no_platform_value_sink() {
  local file hits hit relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    relpath="$(rel "$file")"
    [ "$relpath" = "$SINK_EXEMPT" ] && continue
    hits="$(strip_comments < "$file" \
      | grep -nE "$PLATFORM_VALUE_TYPES" \
      | grep -E "$DART_SINK" || true)"
    [ -n "$hits" ] || continue
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail_in no_platform_value_sink "$relpath:${hit%%:*} puts a platform boundary value on a diagnostic
      surface. Pigeon's generated toString() interpolates sourceIdentifier, so
      printing one of these types leaks a device identity even though this line
      never names the field. Convert through OriginGateway first and report the
      StepOriginKey."
    done <<< "$hits"
  done <<< "$(production_dart)"
}

# rule_pigeon_input_present — the platform contract can be read at all.
#
# INFRASTRUCTURE, not a violation. The original message said it exactly: "the
# platform contract cannot be checked". A guard that cannot read the contract
# has not observed a wire type, and reporting that as a policy violation would
# let a deleted or unreachable file stand in for the mutation
# `rule_pigeon_origin_opaque` exists to catch.
rule_pigeon_input_present() {
  [ -f "$PROJECT_ROOT/$PIGEON_INPUT" ] || \
    guard_infra "$GUARD_ID.pigeon_input_missing" "$PIGEON_INPUT is missing; the platform contract cannot be checked."
}

# rule_pigeon_origin_opaque — the origin fields on the wire are still bytes.
#
# The cheapest possible regression: someone "simplifies" a Uint8List back into a
# String because a String is easier to log. That single edit reopens the channel
# a device name travels in, and every other check here would still pass.
#
# Anchored to the field name, on its own declaration line, in one named file.
rule_pigeon_origin_opaque() {
  local p="$PROJECT_ROOT/$PIGEON_INPUT" pigeon_stripped field decl
  # Absence is rule_pigeon_input_present's statement to make, and it makes it as
  # infrastructure.
  [ -f "$p" ] || return 0
  pigeon_stripped="$(strip_comments < "$p")"
  for field in $OPAQUE_ORIGIN_FIELDS; do
    decl="$(printf '%s\n' "$pigeon_stripped" \
      | grep -nE "^[[:space:]]*final[[:space:]].*[[:space:]]${field};[[:space:]]*$" || true)"
    if [ -z "$decl" ]; then
      fail_in pigeon_origin_opaque "$PIGEON_INPUT no longer declares a field named '$field'.
      The origin must cross the boundary as opaque bytes. If it was renamed,
      update OPAQUE_ORIGIN_FIELDS in this script deliberately."
      continue
    fi
    if ! printf '%s\n' "$decl" | grep -qE 'Uint8List'; then
      fail_in pigeon_origin_opaque "$PIGEON_INPUT declares '$field' as something other than Uint8List.
      An origin crosses the boundary as eight opaque bytes so that a bundle
      identifier or a device name has no field to travel in. A String here
      reopens exactly that channel, and every other check in this script would
      still pass."
    fi
  done
}

# rule_no_native_identity_minting — native never mints or stores a second
# identity. The plugin consumes the app's device-bound salt through
# installOriginKeying. It must not generate one, and must not read one out of
# the Keychain itself.
rule_no_native_identity_minting() {
  local file hits hit relpath
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    hits="$(strip_comments < "$file" | grep -nE "$NATIVE_IDENTITY_MINTING" || true)"
    [ -n "$hits" ] || continue
    relpath="$(rel "$file")"
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail_in no_native_identity_minting "$relpath:${hit%%:*} mints or looks up an identity natively.
      This plugin is a CONSUMER of the app's device-bound identity, never a
      second custodian of one. A second identity re-keys every origin, and a
      re-keyed origin looks exactly like a new device: its recent buckets look
      ungranted and the whole retention window is granted a second time.
      Nothing detects that. IdentityVault owns the lifecycle; the salt arrives
      through installOriginKeying and lives in memory only."
    done <<< "$hits"
  done <<< "$(native_sources)"
}

# The complete guard. Nothing but calls to the named rules above, in order.
#
# Coverage first: a run that has read nothing should say so before it reports
# that it found nothing.
ORIGIN_PRIVACY_RULES="
rule_preflight
rule_dart_scan_coverage
rule_native_scan_coverage
rule_pigeon_input_present
rule_raw_identifier_sites
rule_no_dart_display_name
rule_no_native_display_name
rule_no_dart_raw_sink
rule_no_native_raw_sink
rule_core_boundary_isolation
rule_no_native_durable_store
rule_no_platform_value_sink
rule_pigeon_origin_opaque
rule_no_native_identity_minting
"

run_all_rules() {
  local r
  for r in $ORIGIN_PRIVACY_RULES; do "$r"; done
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
    echo "origin-privacy: INFRASTRUCTURE failure -- the guard could not look." >&2
    return 2
  fi

  if [ "$SELF_TEST" -eq 1 ]; then
    run_self_test || return $?
  fi

  if [ "$failures" -gt 0 ]; then
    echo "" >&2
    echo "A raw platform source identifier is a device name in disguise. It exists" >&2
    echo "between the Pigeon boundary and OriginGateway and nowhere else." >&2
    echo "See packages/stride_health/lib/src/origin_gateway.dart," >&2
    echo "GAME_BIBLE/HEALTH_INTEGRATION/01_APPLE_HEALTH_DESIGN.md, DECISIONS/0012." >&2
    return 1
  fi

  local approved_count
  approved_count="$(printf '%s\n' "$APPROVED" | grep -c '|' || true)"
  echo "origin-privacy: OK"
  echo "  dart production files scanned : $DART_SCANNED"
  echo "  native sources scanned        : $NATIVE_SCANNED"
  echo "  approved raw-identifier sites : $approved_count"
  echo "  native durable stores         : 0 (cursor is never native state)"
}

# ---------------------------------------------------------------------------
# Self-test — isolated, never the live tree
#
# Twelve cases, each with a stable case ID and the diagnostic its own rule must
# emit. Recorded in `Scripts/CASE_MAP.md`, which is what the shared registry
# will consume.
#
# Ten of them assert against the COMPLETE guard. The last two assert against the
# complete guard AND against their own rule invoked ALONE -- see
# `expect_reject_isolated` for why that distinction is the whole point of those
# two cases.
#
# ISOLATED. Every probe lands in a throwaway copy created by `mktemp -d` -- a
# root unique to this run -- and the guard is re-run against it via
# `--project-root`. This used to mutate the LIVE tree: five probe files and an
# edit to the real pigeon input, so two concurrent runs destroyed each other's
# fixtures and left the platform contract damaged if interrupted.
#
# A nonzero exit is NOT evidence, so each case asserts:
#
#   * exit 1 -- a POLICY rejection. Exit 2 is infrastructure and fails the case,
#     which is what stops an incomplete copy, a missing directory or a deleted
#     contract file from standing in for a detection
#   * the diagnostic is that case's own rule, not merely some rule
#   * restoration is exact: every probe gone, and the pigeon input byte-identical
# ---------------------------------------------------------------------------
run_self_test() {
  if [ "$failures" -ne 0 ]; then
    echo "origin-privacy: refusing to self-test while the real tree is failing" >&2
    return 1
  fi

  local TREE_BEFORE ISO st_failures=0 st_ok=0 st_layering=0
  local LIVE_PIGEON_SHA LIVE_GENERATED_SHA
  TREE_BEFORE="$(st_tree_snapshot)"

  # The generated bindings are checked BY CONTENT, separately from the tree
  # snapshot. This self-test edits a copy of the Pigeon input, and the one
  # mistake that would be catastrophic and quiet is editing the real one -- CI
  # diff-checks `messages.g.dart` against a regeneration, so a damaged input
  # surfaces as an unrelated failure in another job. Two named files, hashed.
  LIVE_PIGEON_SHA="$(st_file_digest "$PROJECT_ROOT/$PIGEON_INPUT")"
  LIVE_GENERATED_SHA="$(st_file_digest "$PROJECT_ROOT/packages/stride_health/lib/src/messages.g.dart")"

  ISO="$(st_make_root)"
  trap 'rm -rf "$ISO"' EXIT

  # Copied from PROJECT_ROOT explicitly, not from the caller's cwd: this guard
  # no longer cd's anywhere, so a cwd-relative copy would silently produce an
  # empty tree -- and an empty tree passes every content check in this file.
  st_copy_from "$PROJECT_ROOT" "$ISO" \
    lib packages/stride_core/lib packages/stride_health/lib \
    packages/stride_storage/lib packages/stride_secure_store/lib \
    packages/stride_health/example/lib \
    packages/stride_health/pigeons \
    packages/stride_health/android/src/main \
    packages/stride_health/ios/stride_health/Sources

  local CORE_PROBE="$ISO/packages/stride_core/lib/src/__origin_probe.dart"
  local APP_PROBE="$ISO/lib/__origin_probe.dart"
  local HEALTH_PROBE="$ISO/packages/stride_health/lib/src/__origin_probe.dart"
  local SWIFT_PROBE="$ISO/packages/stride_health/ios/stride_health/Sources/stride_health/__OriginProbe.swift"
  local KOTLIN_PROBE="$ISO/packages/stride_health/android/src/main/kotlin/com/projectstride/stride_health/__OriginProbe.kt"
  local ISO_PIGEON="$ISO/$PIGEON_INPUT"

  # The backup lives INSIDE the isolated root, so the run owns exactly one
  # temporary directory and cleanup cannot leave a stray file behind.
  local BAK="$ISO/.backup"
  mkdir -p "$BAK"
  cp "$ISO_PIGEON" "$BAK/pigeon"

  # The copy must pass before injection, or a rejection proves only that the
  # copy was incomplete.
  if ! bash "$0" --project-root "$ISO" >/dev/null 2>&1; then
    echo "origin-privacy SELF-TEST FAILED: the isolated copy does not pass clean" >&2
    bash "$0" --project-root "$ISO" >&2
    rm -rf "$ISO"; trap - EXIT
    return 1
  fi

  restore_all() {
    rm -f "$CORE_PROBE" "$APP_PROBE" "$HEALTH_PROBE" "$SWIFT_PROBE" "$KOTLIN_PROBE"
    cp "$BAK/pigeon" "$ISO_PIGEON"
    [ ! -e "$CORE_PROBE" ] && [ ! -e "$APP_PROBE" ] && [ ! -e "$HEALTH_PROBE" ] &&
      [ ! -e "$SWIFT_PROBE" ] && [ ! -e "$KOTLIN_PROBE" ] &&
      cmp -s "$BAK/pigeon" "$ISO_PIGEON"
  }

  # expect_reject <case-id> <expected-diagnostic-regex> <label>
  expect_reject() {
    local id="$1" want="$2" label="$3" out rc
    out="$(bash "$0" --project-root "$ISO" 2>&1)"; rc=$?

    if [ "$rc" -eq 0 ]; then
      echo "origin-privacy SELF-TEST FAILED [$id]: the guard ACCEPTED $label" >&2
      st_failures=$((st_failures + 1))
    elif [ "$rc" -ne 1 ]; then
      echo "origin-privacy SELF-TEST FAILED [$id]: $label was rejected with exit $rc (INFRASTRUCTURE), not a policy violation" >&2
      printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
      st_failures=$((st_failures + 1))
    elif ! printf '%s\n' "$out" | grep -qE "$want"; then
      echo "origin-privacy SELF-TEST FAILED [$id]: $label was rejected, but NOT by its own rule." >&2
      echo "    expected a diagnostic matching: $want" >&2
      printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
      st_failures=$((st_failures + 1))
    else
      st_ok=$((st_ok + 1))
      echo "  rejected as expected [$id]: $label"
    fi

    if ! restore_all; then
      echo "origin-privacy SELF-TEST FAILED [$id]: restoration was not exact" >&2
      st_failures=$((st_failures + 1))
    fi
  }

  # expect_reject_isolated <case-id> <rule-fn> <expected-diagnostic> <label> [sole]
  #
  # Stronger than `expect_reject`, and the reason it exists: a case satisfied by
  # the COMPLETE guard proves only that SOME rule rejected the mutation. If
  # another rule fires on the same line, the case is OVER-DETERMINED and proves
  # nothing about the rule it is named for. `op_core_reads_raw` is exactly that
  # -- it is owned by `rule_raw_identifier_sites` and happens to trip
  # `rule_core_boundary_isolation` too, which is why that rule sat uncased.
  #
  # So this asserts twice:
  #
  #   (a) the complete guard exits 1 with the diagnostic -- a POLICY rejection,
  #       end to end, exactly as a developer would see it
  #   (b) the NAMED RULE, invoked ALONE against the same mutated root, exits 1
  #       with its own diagnostic
  #
  # (b) is the isolation proof, and it is airtight in a way (a) cannot be: with
  # one rule running, a mutation only some OTHER rule can see returns 0 here.
  # Over-determination at the guard level stops mattering, because nothing else
  # was given the chance to fire.
  #
  # (b) is only possible because this guard is source-safe -- sourcing it
  # defines the rules and does nothing else. `Scripts/check-source-safety.sh`
  # is what proves that, and this is the first thing to actually depend on it.
  #
  # `sole` additionally demands that the COMPLETE guard names no other rule.
  # Passed only where the mutation genuinely trips one rule; it is not passed
  # where a rule is a strict refinement of another by construction.
  expect_reject_isolated() {
    local id="$1" fn="$2" want="$3" label="$4" sole="${5:-}" out rc others ok=1

    # (a) the complete guard.
    out="$(bash "$0" --project-root "$ISO" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
      echo "origin-privacy SELF-TEST FAILED [$id]: the complete guard ACCEPTED $label" >&2
      ok=0
    elif [ "$rc" -ne 1 ]; then
      echo "origin-privacy SELF-TEST FAILED [$id]: $label was rejected with exit $rc (INFRASTRUCTURE), not a policy violation" >&2
      printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
      ok=0
    elif ! printf '%s\n' "$out" | grep -qE "$want"; then
      echo "origin-privacy SELF-TEST FAILED [$id]: the complete guard rejected $label, but NOT by its own rule." >&2
      echo "    expected a diagnostic matching: $want" >&2
      printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
      ok=0
    elif [ "$sole" = "sole" ]; then
      others="$(printf '%s\n' "$out" \
        | grep -oE 'STRIDE_(GUARD|INFRA)\[origin-privacy\.[a-z_]+\]' \
        | sort -u | grep -vE "$want" || true)"
      if [ -n "$others" ]; then
        echo "origin-privacy SELF-TEST FAILED [$id]: $label is OVER-DETERMINED -- the complete guard also emitted:" >&2
        printf '%s\n' "$others" | sed 's/^/    | /' >&2
        ok=0
      fi
    fi

    # (b) the rule alone. Sourcing is inert, so this runs exactly the function
    #     the complete guard runs -- there is no test-only variant of any rule.
    out="$(PROJECT_ROOT="$ISO" bash -c '. "$1" >/dev/null 2>&1 || exit 2; rule_run "$2"' _ "$0" "$fn" 2>&1)"; rc=$?
    if [ "$rc" -eq 0 ]; then
      echo "origin-privacy SELF-TEST FAILED [$id]: $fn alone ACCEPTED $label -- the mutation is only visible to some OTHER rule, so this case does not prove $fn" >&2
      ok=0
    elif [ "$rc" -ne 1 ]; then
      echo "origin-privacy SELF-TEST FAILED [$id]: $fn alone exited $rc (INFRASTRUCTURE), not a policy violation" >&2
      printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
      ok=0
    elif ! printf '%s\n' "$out" | grep -qE "$want"; then
      echo "origin-privacy SELF-TEST FAILED [$id]: $fn alone rejected $label without emitting $want" >&2
      printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
      ok=0
    else
      others="$(printf '%s\n' "$out" \
        | grep -oE 'STRIDE_(GUARD|INFRA)\[origin-privacy\.[a-z_]+\]' \
        | sort -u | grep -vE "$want" || true)"
      if [ -n "$others" ]; then
        echo "origin-privacy SELF-TEST FAILED [$id]: $fn alone emitted a diagnostic that is not its own:" >&2
        printf '%s\n' "$others" | sed 's/^/    | /' >&2
        ok=0
      fi
    fi

    if [ "$ok" -eq 1 ]; then
      st_ok=$((st_ok + 1))
      echo "  rejected as expected [$id]: $label -- and by $fn ALONE"
    else
      st_failures=$((st_failures + 1))
    fi

    if ! restore_all; then
      echo "origin-privacy SELF-TEST FAILED [$id]: restoration was not exact" >&2
      st_failures=$((st_failures + 1))
    fi
  }

  local D='STRIDE_GUARD\[origin-privacy\.'

  # 1 -- the core reads the raw field. The exact thing the ruling forbids.
  #      It trips the core-isolation rule too, and is owned by the rule that
  #      names the raw identifier; case 1 of that pair is what the original
  #      inventory called "A".
  cat > "$CORE_PROBE" <<'PROBE'
class OriginProbe {
  String pick(dynamic observation) => observation.sourceIdentifier as String;
}
PROBE
  expect_reject op_core_reads_raw "${D}raw_identifier_sites\]" \
    "stride_core reading the raw source identifier"

  # 2 -- an ordinary app file reads it. Proven separately from the core case,
  #      so the allow-list is shown to bind everywhere and not only in one
  #      package.
  cat > "$APP_PROBE" <<'PROBE'
class OriginProbe {
  String pick(dynamic page) => page.observations.first.sourceIdentifier as String;
}
PROBE
  expect_reject op_app_reads_raw "${D}raw_identifier_sites\]" \
    "an app file reading the raw source identifier"

  # 3 -- the completeness scope's raw source LIST is the same value in a
  #      different shape, and an allow-list that missed it would be decorative.
  cat > "$HEALTH_PROBE" <<'PROBE'
class OriginProbe {
  List<String> pick(dynamic scope) => scope.sourceIdentifiers as List<String>;
}
PROBE
  expect_reject op_health_reads_raw_list "${D}raw_identifier_sites\]" \
    "a second health file reading the raw source list"

  # 4 -- a display-name shape on the data path.
  cat > "$HEALTH_PROBE" <<'PROBE'
class OriginProbe {
  String deviceName = 'unset';
}
PROBE
  expect_reject op_dart_display_name "${D}no_dart_display_name\]" \
    "a device display name on the health data path"

  # 5 -- native reads HKSource.name, the obvious wrong implementation.
  cat > "$SWIFT_PROBE" <<'PROBE'
import Foundation

struct OriginProbe {
  func label(_ source: HKSource) -> String {
    return source.name
  }
}
PROBE
  expect_reject op_swift_display_name "${D}no_native_display_name\]" \
    "Swift reading HKSource.name"

  # 6 -- native logs the raw identifier. This is where raw identifiers actually
  #      live now, so this is where the sink check earns its place.
  cat > "$SWIFT_PROBE" <<'PROBE'
import Foundation

struct OriginProbe {
  func trace(_ sourceIdentifier: String) {
    NSLog("read from %@", sourceIdentifier)
  }
}
PROBE
  expect_reject op_swift_logs_raw "${D}no_native_raw_sink\]" \
    "Swift logging a raw source identifier"

  # 7 -- the wire field is "simplified" back into a String. One edit, every
  #      other check still green, and the channel a device name travels in is
  #      open again.
  sed -i 's/^  final Uint8List originKey;$/  final String originKey;/' "$ISO_PIGEON"
  expect_reject op_pigeon_origin_string "${D}pigeon_origin_opaque\]" \
    "the origin field changed from opaque bytes to a String"

  # 8 -- native mints its own identity instead of consuming the app's.
  cat > "$SWIFT_PROBE" <<'PROBE'
import Foundation

struct OriginProbe {
  func mint() -> Data {
    var bytes = [UInt8](repeating: 0, count: 16)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    return Data(bytes)
  }
}
PROBE
  expect_reject op_swift_mints_identity "${D}no_native_identity_minting\]" \
    "Swift minting a second device identity"

  # 9 -- a platform VALUE reaches a diagnostic, without the field ever being
  #      named. This is the leak the guard found in Pigeon's generated
  #      toString, and the reason the platform-value rule exists at all.
  cat > "$HEALTH_PROBE" <<'PROBE'
import 'messages.g.dart';

void probeLeak(PlatformSyncPage page) => throw StateError('page was $page');
PROBE
  expect_reject op_platform_value_sink "${D}no_platform_value_sink\]" \
    "a platform boundary value printed without naming the field"

  # 10 -- native caches the cursor in a durable store.
  cat > "$KOTLIN_PROBE" <<'PROBE'
package com.projectstride.stride_health

import android.content.Context

class OriginProbe(private val context: Context) {
    fun remember(cursor: ByteArray) {
        val prefs = context.getSharedPreferences("stride", Context.MODE_PRIVATE)
        prefs.edit().putString("cursor", cursor.toString()).apply()
    }
}
PROBE
  expect_reject op_kotlin_durable_store "${D}no_native_durable_store\]" \
    "Kotlin caching the cursor in a durable native store"

  # ------------------------------------------------------------------
  # 11 and 12 -- the two rules that were enforced but uncased.
  #
  # Both use `expect_reject_isolated`, which additionally runs the rule ALONE.
  # That is not belt-and-braces; it is the only thing that makes either case
  # evidence. The complete guard emitting the right diagnostic somewhere in its
  # output does not establish that THIS rule found THIS mutation.
  # ------------------------------------------------------------------

  # 11 -- a Dart health-boundary surface puts the raw native identifier on a
  #       diagnostic sink. This is the leak the rule is named for: the value
  #       does not have to be persisted to escape, it only has to be logged, and
  #       a device log is readable, exportable and outlives the app.
  #
  #       NOT marked `sole`, deliberately, and this is a property of the
  #       production rules rather than of the probe: `rule_no_dart_raw_sink`
  #       greps the SAME raw-symbol pattern as `rule_raw_identifier_sites` and
  #       then narrows it with DART_SINK, so its hit set is a strict SUBSET.
  #       With APPROVED empty, every line the sink rule can fire on trips the
  #       site rule too, and no probe can separate them. Narrowing the site rule
  #       to make this case look isolated would weaken a production rule to
  #       flatter a test. So the separation is proved where it is real -- at the
  #       rule level, in (b).
  cat > "$HEALTH_PROBE" <<'PROBE'
import 'dart:developer' as developer;

class OriginProbe {
  void trace(dynamic observation) {
    developer.log('sync page from ${observation.sourceIdentifier}');
  }
}
PROBE
  expect_reject_isolated op_dart_raw_sink rule_no_dart_raw_sink \
    "${D}no_dart_raw_sink\]" \
    "a Dart health surface logging the raw native identifier"

  # 12 -- stride_core acquires a platform dependency, WITHOUT naming the raw
  #       identifier. That restriction is the entire point: the existing
  #       `op_core_reads_raw` probe names `sourceIdentifier` inside the core, so
  #       `rule_raw_identifier_sites` fires on it first and the core rule was
  #       never independently falsified.
  #
  #       This probe names no raw identifier at all. It imports the health
  #       package and declares the Pigeon host API type -- the core acquiring an
  #       opinion about where its data came from, which is the regression the
  #       rule actually exists to stop. Marked `sole`: the complete guard must
  #       name this rule and no other.
  cat > "$CORE_PROBE" <<'PROBE'
import 'package:stride_health/stride_health.dart';

abstract class CoreBoundaryProbe {
  HealthHostApi get api;
}
PROBE
  expect_reject_isolated op_core_boundary_isolation rule_core_boundary_isolation \
    "${D}core_boundary_isolation\]" \
    "stride_core taking a dependency on the platform boundary" \
    sole

  # ------------------------------------------------------------------
  # The other direction. Two layering cases, because in a privacy guard the
  # dangerous failure is not a false rejection -- it is a clean-looking run that
  # read nothing.
  #
  # Cases 5, 6, 8 and 10 prove the native rules fire when a violation is
  # present. They cannot prove the native scan happened at all: a copy without
  # the Swift and Kotlin directories produces no findings and looks exactly like
  # a clean tree. Nor can any case prove that a MISSING platform contract is
  # infrastructure rather than a rejection -- and if it were a rejection, case 7
  # could be satisfied by deleting the file instead of by changing the type.
  # ------------------------------------------------------------------
  local SAVED="$ISO/.moved"
  mkdir -p "$SAVED"
  mv "$ISO/packages/stride_health/ios/stride_health/Sources" "$SAVED/ios-Sources"
  mv "$ISO/packages/stride_health/android/src/main" "$SAVED/android-main"

  local out rc
  out="$(bash "$0" --project-root "$ISO" 2>&1)"; rc=$?
  if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -qE 'STRIDE_INFRA\[origin-privacy\.no_native_sources\]'; then
    echo "  layering held [op_empty_native_scan]: no native sources is INFRASTRUCTURE (exit 2), not a clean privacy result"
    st_layering=$((st_layering + 1))
  else
    echo "origin-privacy SELF-TEST FAILED [op_empty_native_scan]: an empty native scan reported exit $rc" >&2
    printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
    st_failures=$((st_failures + 1))
  fi

  mv "$SAVED/ios-Sources" "$ISO/packages/stride_health/ios/stride_health/Sources"
  mv "$SAVED/android-main" "$ISO/packages/stride_health/android/src/main"

  mv "$ISO_PIGEON" "$SAVED/pigeon-input"
  out="$(bash "$0" --project-root "$ISO" 2>&1)"; rc=$?
  if [ "$rc" -eq 2 ] && printf '%s\n' "$out" | grep -qE 'STRIDE_INFRA\[origin-privacy\.pigeon_input_missing\]' &&
     ! printf '%s\n' "$out" | grep -qE "${D}pigeon_origin_opaque\]"; then
    echo "  layering held [op_missing_pigeon_input]: a DELETED platform contract is INFRASTRUCTURE, never pigeon_origin_opaque"
    st_layering=$((st_layering + 1))
  else
    echo "origin-privacy SELF-TEST FAILED [op_missing_pigeon_input]: a deleted contract reported exit $rc" >&2
    printf '%s\n' "$out" | head -8 | sed 's/^/    | /' >&2
    st_failures=$((st_failures + 1))
  fi
  mv "$SAVED/pigeon-input" "$ISO_PIGEON"
  rmdir "$SAVED" 2>/dev/null || true

  if ! restore_all; then
    echo "origin-privacy SELF-TEST FAILED: restoration after the layering cases was not exact" >&2
    st_failures=$((st_failures + 1))
  fi

  # The copy must pass again once every probe is gone, or a rejection above was
  # damage rather than detection.
  if ! bash "$0" --project-root "$ISO" >/dev/null 2>&1; then
    echo "origin-privacy SELF-TEST FAILED: the isolated copy does not pass after cleanup" >&2
    bash "$0" --project-root "$ISO" >&2
    st_failures=$((st_failures + 1))
  fi

  rm -rf "$ISO"
  trap - EXIT

  # The live tree must be byte-for-byte what it was. Asserted, not assumed.
  st_assert_tree_unchanged "$TREE_BEFORE" || return 1

  # And the two generated-binding files by content, named individually. The
  # tree snapshot would catch this too; this says which file and why.
  if [ "$LIVE_PIGEON_SHA" != "$(st_file_digest "$PROJECT_ROOT/$PIGEON_INPUT")" ]; then
    echo "SELF-TEST FAILED: the LIVE Pigeon input was modified. CI diff-checks the" >&2
    echo "generated bindings against a regeneration, so this would surface as an" >&2
    echo "unrelated failure in another job." >&2
    return 1
  fi
  if [ "$LIVE_GENERATED_SHA" != "$(st_file_digest "$PROJECT_ROOT/packages/stride_health/lib/src/messages.g.dart")" ]; then
    echo "SELF-TEST FAILED: the LIVE generated bindings were modified." >&2
    return 1
  fi
  echo "  pigeon input and generated bindings: byte-identical"

  if [ "$st_failures" -ne 0 ]; then
    echo "origin-privacy: SELF-TEST FAILED -- $st_failures case(s) wrong" >&2
    return 1
  fi
  # Asserted, not narrated: the count used to be a string in an echo, which is
  # a second source of truth and drifts the moment a case is added.
  if [ "$st_ok" -ne 12 ] || [ "$st_layering" -ne 2 ]; then
    echo "origin-privacy: SELF-TEST FAILED -- proved $st_ok rejection case(s) and $st_layering layering case(s), expected 12 and 2" >&2
    return 1
  fi
  echo "origin-privacy: self-test OK -- $st_ok injected violations rejected by their own rules at exit 1, $st_layering layering cases"
  return 0
}

# Source-safe entry. Sourcing defines the rules and does nothing else: no traps,
# no cd, no shell-option changes, no files, no rule execution, and nothing that
# touches the generated bindings. Proven for every converted guard by
# Scripts/check-source-safety.sh.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  guard_main "$@"
  exit $?
fi
