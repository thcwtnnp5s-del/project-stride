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
# Run `--self-test` to falsify it. It injects ten violations, at least one per check,
# and asserts the guard rejects each. That runs in verify.sh and in CI, so the
# guard is continuously proven able to fail.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

failures=0
fail() {
  echo "origin-privacy: FAIL -- $1" >&2
  failures=$((failures + 1))
}

# ---------------------------------------------------------------------------
# The raw field name that used to exist on the wire.
#
# Under the owner's ruling, keying happens natively and no raw identifier
# crosses Pigeon at all — so the allow-list for this symbol in Dart is now
# EMPTY. The check has not become vacuous, it has become absolute: naming a raw
# source identifier anywhere in production Dart means the boundary has been
# reopened.
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
# device name to travel in. Check H asserts that the pigeon input still declares
# them that way, because the cheapest possible regression here is someone
# "simplifying" a byte array back into a String.
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
# is exempted BY NAME below and check G is the compensating control: nothing may
# put one of these values on a diagnostic sink. An unreachable leak is a
# guarded leak; a pattern-matched exemption would be neither.
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

# Pigeon's generated `toString`. See PLATFORM_VALUE_TYPES above; check G is what
# makes this exemption safe rather than merely convenient.
SINK_EXEMPT="packages/stride_health/lib/src/messages.g.dart"

# The core's own list of forbidden imports names 'package:stride_health/'. The
# core declaring a package off-limits is the rule, not a violation of it.
CORE_BOUNDARY_EXEMPT="packages/stride_core/lib/src/core_info.dart"

# ---------------------------------------------------------------------------
# File sets. Production source ONLY.
#
# Tests are excluded deliberately, and this is the same reasoning
# check-single-writer.sh uses: a test constructs a raw platform identifier on
# purpose -- `PlatformStepObservation(sourceIdentifier: "Rob's iPhone")` is how
# test/origin_privacy_test.dart proves a display name cannot survive the
# boundary. Scanning tests would make this guard unmaintainable and therefore
# disabled.
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

echo "origin-privacy: scanning production source only"

dart_count=0
native_count=0

# ---------------------------------------------------------------------------
# Check A -- the raw identifier is named only at approved sites
# ---------------------------------------------------------------------------
while IFS= read -r file; do
  [ -n "$file" ] || continue
  dart_count=$((dart_count + 1))
  stripped="$(strip_comments < "$file")"

  hits="$(printf '%s\n' "$stripped" | grep -nE "(^|[^A-Za-z0-9_])${RAW_SYMBOL}\b" || true)"
  [ -n "$hits" ] || continue

  if listed_in "${file}|sourceIdentifier" "$APPROVED"; then continue; fi

  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "$file:${hit%%:*} names the raw platform source identifier.
      A raw identifier exists only between the Pigeon boundary and
      OriginGateway, and only inside that one call. If this is deliberate, add
      '${file}|sourceIdentifier' to APPROVED in this script and record why --
      but the answer is almost always to take a StepOriginKey instead."
  done <<< "$hits"
done < <(production_dart)

# ---------------------------------------------------------------------------
# Check B -- no display-name shape on the health or save data path
# ---------------------------------------------------------------------------
for dir in $DART_DATA_PATH_DIRS; do
  [ -d "$dir" ] || continue
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    [ "$file" = "$DISPLAY_NAME_EXEMPT" ] && continue
    hits="$(strip_comments < "$file" | grep -nE "$DART_DISPLAY_NAME" || true)"
    [ -n "$hits" ] || continue
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      fail "$file:${hit%%:*} uses a device or source display-name shape on the
      data path. A player may have called their phone anything at all, and the
      owner's ruling forbids persisting device names, source display names, or
      HKSource.name. Pseudonymize at the boundary instead."
    done <<< "$hits"
  done < <(find "$dir" -name '*.dart' -not -path '*/build/*' 2>/dev/null | sort)
done

# ---------------------------------------------------------------------------
# Check C -- no native display-name API
# ---------------------------------------------------------------------------
while IFS= read -r file; do
  [ -n "$file" ] || continue
  native_count=$((native_count + 1))
  hits="$(strip_comments < "$file" | grep -nE "$NATIVE_DISPLAY_NAME" || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "$file:${hit%%:*} reads a platform display name.
      Send HKSource.bundleIdentifier on iOS and
      metadata.dataOrigin.packageName on Android. A display name hashed into an
      origin key is worse than useless: it looks correct."
  done <<< "$hits"
done < <(native_sources)

# ---------------------------------------------------------------------------
# Check D -- the raw identifier never reaches a diagnostic
#
# Applies to EVERY production file, including the three approved ones. Approval
# is permission to convert a raw value, never permission to print one. The scan
# is per-line and therefore bounded by construction -- it cannot walk past the
# thing it is checking.
# ---------------------------------------------------------------------------
while IFS= read -r file; do
  [ -n "$file" ] || continue
  [ "$file" = "$SINK_EXEMPT" ] && continue
  hits="$(strip_comments < "$file" \
    | grep -nE "(^|[^A-Za-z0-9_])${RAW_SYMBOL}\b" \
    | grep -E "$DART_SINK" || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "$file:${hit%%:*} puts the raw source identifier on a diagnostic
      surface -- a log, an interpolated string, or an exception message. Every
      one of those is a place a device name ends up readable. Report the
      StepOriginKey, or report nothing."
  done <<< "$hits"
done < <(production_dart)

while IFS= read -r file; do
  [ -n "$file" ] || continue
  hits="$(strip_comments < "$file" \
    | grep -nE "(^|[^A-Za-z0-9_])${RAW_SYMBOL}\b" \
    | grep -E "$NATIVE_SINK" || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "$file:${hit%%:*} logs a raw source identifier natively. Device logs
      are readable, exportable, and outlive the app."
  done <<< "$hits"
done < <(native_sources)

# ---------------------------------------------------------------------------
# Check E -- stride_core knows nothing about the platform boundary
#
# Separate from check A rather than folded into it, so it is falsified
# independently: the core's ignorance of platform types is the property the
# whole port design rests on, and it should not depend on an allow-list staying
# short somewhere else.
# ---------------------------------------------------------------------------
CORE_FORBIDDEN="${RAW_SYMBOL}|messages\.g\.dart|package:stride_health|HealthHostApi|PlatformStepObservation|PlatformSyncPage"
while IFS= read -r file; do
  [ -n "$file" ] || continue
  [ "$file" = "$CORE_BOUNDARY_EXEMPT" ] && continue
  hits="$(strip_comments < "$file" | grep -nE "$CORE_FORBIDDEN" || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "$file:${hit%%:*} reaches the platform boundary from inside
      stride_core. The core consumes a SyncResponse and holds no opinion about
      where it came from -- that is what keeps it pure, testable in
      milliseconds, and free of any raw identifier."
  done <<< "$hits"
done < <(find packages/stride_core/lib -name '*.dart' 2>/dev/null | sort)

# ---------------------------------------------------------------------------
# Check F -- no native durable store, so no natively cached cursor
# ---------------------------------------------------------------------------
while IFS= read -r file; do
  [ -n "$file" ] || continue
  hits="$(strip_comments < "$file" | grep -nE "$NATIVE_PERSISTENCE" || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "$file:${hit%%:*} opens a durable native store.
      The cursor commit order is inviolable: the adapter returns a candidate
      cursor and forgets it; reconciliation produces grants; the ledger and
      snapshot commit; only THEN is the cursor durable. A natively cached
      cursor claims progress the ledger never recorded, and makes an
      interrupted sync unrecoverable. See DECISIONS/0012 and 0013."
  done <<< "$hits"
done < <(native_sources)

# ---------------------------------------------------------------------------
# Check G -- no platform boundary VALUE reaches a diagnostic
#
# The compensating control for the exemption above, and the check this guard
# earned on its first run. `PlatformStepObservation.toString()` interpolates the
# raw identifier, so `print(page)` leaks a device identity without the word
# `sourceIdentifier` appearing anywhere near the call. Check D cannot see that;
# this can.
#
# Per-line, so it is bounded by construction.
# ---------------------------------------------------------------------------
while IFS= read -r file; do
  [ -n "$file" ] || continue
  [ "$file" = "$SINK_EXEMPT" ] && continue
  hits="$(strip_comments < "$file" \
    | grep -nE "$PLATFORM_VALUE_TYPES" \
    | grep -E "$DART_SINK" || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "$file:${hit%%:*} puts a platform boundary value on a diagnostic
      surface. Pigeon's generated toString() interpolates sourceIdentifier, so
      printing one of these types leaks a device identity even though this line
      never names the field. Convert through OriginGateway first and report the
      StepOriginKey."
  done <<< "$hits"
done < <(production_dart)

# ---------------------------------------------------------------------------
# Check H -- the origin fields on the wire are still opaque bytes
#
# The cheapest possible regression: someone "simplifies" a Uint8List back into a
# String because a String is easier to log. That single edit reopens the channel
# a device name travels in, and every other check here would still pass.
#
# Anchored to the field name, on its own declaration line, in one named file.
# ---------------------------------------------------------------------------
if [ ! -f "$PIGEON_INPUT" ]; then
  fail "$PIGEON_INPUT is missing; the platform contract cannot be checked."
else
  pigeon_stripped="$(strip_comments < "$PIGEON_INPUT")"
  for field in $OPAQUE_ORIGIN_FIELDS; do
    decl="$(printf '%s\n' "$pigeon_stripped" \
      | grep -nE "^[[:space:]]*final[[:space:]].*[[:space:]]${field};[[:space:]]*$" || true)"
    if [ -z "$decl" ]; then
      fail "$PIGEON_INPUT no longer declares a field named '$field'.
      The origin must cross the boundary as opaque bytes. If it was renamed,
      update OPAQUE_ORIGIN_FIELDS in this script deliberately."
      continue
    fi
    if ! printf '%s\n' "$decl" | grep -qE 'Uint8List'; then
      fail "$PIGEON_INPUT declares '$field' as something other than Uint8List.
      An origin crosses the boundary as eight opaque bytes so that a bundle
      identifier or a device name has no field to travel in. A String here
      reopens exactly that channel, and every other check in this script would
      still pass."
    fi
  done
fi

# ---------------------------------------------------------------------------
# Check I -- native never mints or stores a second identity
#
# The plugin consumes the app's device-bound salt through installOriginKeying.
# It must not generate one, and must not read one out of the Keychain itself.
# ---------------------------------------------------------------------------
while IFS= read -r file; do
  [ -n "$file" ] || continue
  hits="$(strip_comments < "$file" | grep -nE "$NATIVE_IDENTITY_MINTING" || true)"
  [ -n "$hits" ] || continue
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    fail "$file:${hit%%:*} mints or looks up an identity natively.
      This plugin is a CONSUMER of the app's device-bound identity, never a
      second custodian of one. A second identity re-keys every origin, and a
      re-keyed origin looks exactly like a new device: its recent buckets look
      ungranted and the whole retention window is granted a second time.
      Nothing detects that. IdentityVault owns the lifecycle; the salt arrives
      through installOriginKeying and lives in memory only."
  done <<< "$hits"
done < <(native_sources)

# ---------------------------------------------------------------------------
# An empty scan must never pass silently.
# ---------------------------------------------------------------------------
if [ "$dart_count" -eq 0 ]; then
  echo "origin-privacy: error -- no production Dart sources found" >&2
  failures=$((failures + 1))
fi
if [ "$native_count" -eq 0 ]; then
  echo "origin-privacy: error -- no native sources found" >&2
  failures=$((failures + 1))
fi

# ---------------------------------------------------------------------------
# Self-test: prove the guard can fail
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--self-test" ]; then
  if [ "$failures" -ne 0 ]; then
    echo "origin-privacy: refusing to self-test while the real tree is failing" >&2
    exit 1
  fi

  CORE_PROBE="packages/stride_core/lib/src/__origin_probe.dart"
  APP_PROBE="lib/__origin_probe.dart"
  HEALTH_PROBE="packages/stride_health/lib/src/__origin_probe.dart"
  SWIFT_PROBE="packages/stride_health/ios/stride_health/Sources/stride_health/__OriginProbe.swift"
  KOTLIN_PROBE="packages/stride_health/android/src/main/kotlin/com/projectstride/stride_health/__OriginProbe.kt"
  PIGEON_BACKUP="$(mktemp)"

  cp "$PIGEON_INPUT" "$PIGEON_BACKUP"
  cleanup() {
    rm -f "$CORE_PROBE" "$APP_PROBE" "$HEALTH_PROBE" "$SWIFT_PROBE" "$KOTLIN_PROBE"
    # Restored unconditionally. The pigeon input is a real production file and
    # the self-test edits it, so an interrupted run must not leave it damaged.
    [ -f "$PIGEON_BACKUP" ] && cp "$PIGEON_BACKUP" "$PIGEON_INPUT"
    rm -f "$PIGEON_BACKUP"
  }
  trap cleanup EXIT

  selftest_failures=0
  expect_reject() {
    if bash "$0" >/dev/null 2>&1; then
      echo "origin-privacy SELF-TEST FAILED: the guard accepted $1" >&2
      selftest_failures=$((selftest_failures + 1))
    else
      echo "  rejected as expected: $1"
    fi
    rm -f "$CORE_PROBE" "$APP_PROBE" "$HEALTH_PROBE" "$SWIFT_PROBE" "$KOTLIN_PROBE"
    cp "$PIGEON_BACKUP" "$PIGEON_INPUT"
  }

  # A -- the core reads the raw field. The exact thing the ruling forbids.
  cat > "$CORE_PROBE" <<'PROBE'
class OriginProbe {
  String pick(dynamic observation) => observation.sourceIdentifier as String;
}
PROBE
  expect_reject "stride_core reading the raw source identifier"

  # A -- an ordinary app file reads it. Proven separately from the core case,
  # so the allow-list is shown to bind everywhere and not only in one package.
  cat > "$APP_PROBE" <<'PROBE'
class OriginProbe {
  String pick(dynamic page) => page.observations.first.sourceIdentifier as String;
}
PROBE
  expect_reject "an app file reading the raw source identifier"

  # A (plural) -- the completeness scope's raw source list is the same value in
  # a different shape, and an allow-list that missed it would be decorative.
  cat > "$HEALTH_PROBE" <<'PROBE'
class OriginProbe {
  List<String> pick(dynamic scope) => scope.sourceIdentifiers as List<String>;
}
PROBE
  expect_reject "a second health file reading the raw source list"

  # B -- a display-name shape on the data path.
  cat > "$HEALTH_PROBE" <<'PROBE'
class OriginProbe {
  String deviceName = 'unset';
}
PROBE
  expect_reject "a device display name on the health data path"

  # C -- native reads HKSource.name, the obvious wrong implementation.
  cat > "$SWIFT_PROBE" <<'PROBE'
import Foundation

struct OriginProbe {
  func label(_ source: HKSource) -> String {
    return source.name
  }
}
PROBE
  expect_reject "Swift reading HKSource.name"

  # D -- native logs the raw identifier. This is where raw identifiers actually
  # live now, so this is where the sink check earns its place: device logs are
  # readable, exportable, and outlive the app.
  cat > "$SWIFT_PROBE" <<'PROBE'
import Foundation

struct OriginProbe {
  func trace(_ sourceIdentifier: String) {
    NSLog("read from %@", sourceIdentifier)
  }
}
PROBE
  expect_reject "Swift logging a raw source identifier"

  # H -- the wire field is "simplified" back into a String. One edit, every
  # other check still green, and the channel a device name travels in is open
  # again.
  sed -i 's/^  final Uint8List originKey;$/  final String originKey;/' "$PIGEON_INPUT"
  expect_reject "the origin field changed from opaque bytes to a String"

  # I -- native mints its own identity instead of consuming the app's.
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
  expect_reject "Swift minting a second device identity"

  # G -- a platform VALUE reaches a diagnostic, without the field ever being
  # named. This is the leak the guard found in Pigeon's generated toString, and
  # the reason check G exists at all.
  cat > "$HEALTH_PROBE" <<'PROBE'
import 'messages.g.dart';

void probeLeak(PlatformSyncPage page) => throw StateError('page was $page');
PROBE
  expect_reject "a platform boundary value printed without naming the field"

  # F -- native caches the cursor in a durable store.
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
  expect_reject "Kotlin caching the cursor in a durable native store"

  cleanup
  trap - EXIT

  # And the real tree must still pass once the probes are gone, or the
  # self-test has left damage behind.
  if ! bash "$0" >/dev/null 2>&1; then
    echo "origin-privacy SELF-TEST FAILED: the tree does not pass after cleanup" >&2
    exit 1
  fi

  if [ "$selftest_failures" -ne 0 ]; then
    echo "origin-privacy: SELF-TEST FAILED -- the guard cannot detect $selftest_failures of 10 injected violations" >&2
    exit 1
  fi
  echo "origin-privacy: self-test OK -- all 10 injected violations were rejected"
fi

if [ "$failures" -gt 0 ]; then
  echo "" >&2
  echo "A raw platform source identifier is a device name in disguise. It exists" >&2
  echo "between the Pigeon boundary and OriginGateway and nowhere else." >&2
  echo "See packages/stride_health/lib/src/origin_gateway.dart," >&2
  echo "GAME_BIBLE/HEALTH_INTEGRATION/01_APPLE_HEALTH_DESIGN.md, DECISIONS/0012." >&2
  exit 1
fi

approved_count="$(printf '%s\n' "$APPROVED" | grep -c '|' || true)"
echo "origin-privacy: OK"
echo "  dart production files scanned : $dart_count"
echo "  native sources scanned        : $native_count"
echo "  approved raw-identifier sites : $approved_count"
echo "  native durable stores         : 0 (cursor is never native state)"
