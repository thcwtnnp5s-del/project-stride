#!/usr/bin/env bash
#
# The step ledger must never be copied off the device by the platform, and must
# never sit anywhere a file manager or another app can browse.
#
# An automatic backup restored onto a second device replays a monotonic step
# ledger against a health source the original already consumed from, producing
# exactly the double-count the whole reconciliation design exists to prevent --
# silently, and weeks after the fact.
#
# ---------------------------------------------------------------------------
# What changed in F-06, and why
# ---------------------------------------------------------------------------
#
# Before F-06 nothing wrote files, so this guard could only check that the
# Android rules were domain-wide. F-06 introduced `StorageLayout`, which names
# five real files. The owner's requirement is that backup rules must cover the
# actual filenames.
#
# The Android rules are domain-wide rather than a filename allowlist, and that
# is the right shape: the five files are covered *by construction*. But "by
# construction" is a claim about the rules' shape, and a shape can be changed.
# Two edits would break it while leaving the old assertions green:
#
#   1. Adding an <include> element. Android's data-extraction rules invert on
#      the presence of an include: with no <include>, everything is backed up
#      except the <exclude>s; with one, only the included subtree is considered.
#      An include added "just for settings" re-opens the domain.
#   2. Narrowing an <exclude> with a path= attribute. <exclude domain="file"
#      path="cache"/> is still an exclude for domain "file", so the old grep
#      passed, but it covers nothing this app actually writes.
#
# So this guard now reads the filenames out of `StorageLayout` -- the source of
# truth, not a list someone remembered -- and asserts coverage against the
# actual rule shape. If the rules ever become an allowlist, every filename must
# be named explicitly or this fails.
#
# ---------------------------------------------------------------------------
# iOS: honest status
# ---------------------------------------------------------------------------
#
# **iOS backup exclusion is NOT configured. It is not configurable here.**
#
# There is no Info.plist key and no build setting that excludes a file from
# iCloud or iTunes backup. The only mechanism is NSURLIsExcludedFromBackupKey,
# set per-URL at runtime from native code (or from Dart through a plugin that
# does not exist in this repo). Nothing in ios/Runner sets it, and nothing in
# stride_storage can: that package is pure dart:io by design.
#
# Application Support on iOS *is* backed up by default. iOS default file
# protection is NSFileProtectionCompleteUntilFirstUserAuthentication -- the
# files are encrypted at rest but readable whenever the device has been
# unlocked once since boot, which is effectively always.
#
# The platforms are therefore asymmetric, and the asymmetry is real:
#
#   Android : backup excluded, declaratively, and enforced by this script.
#   iOS     : NOT excluded. Needs native code that has not been written.
#
# What this guard *can* check on iOS is the second half of the requirement --
# that the app container is not browsable. It asserts the Runner does not
# enable file sharing or in-place document opening, which is what would expose
# the save directory in the Files app.
#
# Flagged by the F-05 Privacy Auditor as the one privacy control with no
# in-code enforcement; extended by the F-06 Platform Security audit.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

MANIFEST="android/app/src/main/AndroidManifest.xml"
RULES="android/app/src/main/res/xml/data_extraction_rules.xml"
LAYOUT="packages/stride_storage/lib/src/file_storage.dart"
BOOTSTRAP="lib/runtime/runtime_bootstrap.dart"
IOS_PLIST="ios/Runner/Info.plist"

failures=0

fail() {
  echo "storage privacy: FAIL -- $1" >&2
  failures=$((failures + 1))
}

for file in "$MANIFEST" "$RULES" "$LAYOUT" "$BOOTSTRAP" "$IOS_PLIST"; do
  if [ ! -f "$file" ]; then
    fail "$file is missing"
  fi
done

if [ "$failures" -gt 0 ]; then
  exit 1
fi

# ===========================================================================
# 1. The actual filenames, read from StorageLayout
# ===========================================================================
#
# Extracted rather than hardcoded. A duplicated list goes stale the first time
# a file is renamed, and then asserts coverage of filenames that no longer
# exist -- which is worse than no assertion, because it looks like one.

DIR_NAME=$(grep -oE "directoryName = '[^']+'" "$LAYOUT" | sed -E "s/.*'(.*)'/\1/")
if [ -z "$DIR_NAME" ]; then
  fail "could not read StorageLayout.directoryName from $LAYOUT"
  exit 1
fi

case "$DIR_NAME" in
  *'$'*)
    fail "StorageLayout.directoryName is interpolated, not a literal. A path component derived from a device name, a health source, or any user-supplied string is itself a privacy artifact."
    ;;
esac

FILE_NAMES=$(grep -F 'root.path}/' "$LAYOUT" | sed -E "s|.*root\.path\}/([^']+)'.*|\1|" | sort -u)

FILE_COUNT=$(printf '%s\n' "$FILE_NAMES" | grep -c . || true)
if [ "$FILE_COUNT" -lt 5 ]; then
  # A parse that silently finds nothing would pass every check below.
  fail "found only $FILE_COUNT filenames in $LAYOUT; expected at least 5. The extraction is broken, or the layout changed shape."
  exit 1
fi

# Every filename must be a literal, not built from anything.
for name in $FILE_NAMES; do
  case "$name" in
    *'$'*)
      fail "storage filename '$name' is interpolated. Path components must never derive from a device name, a health source, or user input."
      ;;
  esac
done

# Every `File get x` must appear in `allFiles`, or the audit surface silently
# under-reports the layout. That is the failure mode that would make every
# assertion below vacuous for a newly added sixth file.
ALLFILES=$(awk '/List<File> get allFiles/,/\];/' "$LAYOUT")
if [ -z "$ALLFILES" ]; then
  fail "$LAYOUT has no allFiles list to audit against"
else
  GETTERS=$(grep -oE 'File get [a-zA-Z_]+' "$LAYOUT" | awk '{print $3}' | sort -u)
  for getter in $GETTERS; do
    if ! printf '%s\n' "$ALLFILES" | grep -qE "^[[:space:]]*${getter},[[:space:]]*$"; then
      fail "StorageLayout.$getter is not listed in allFiles, so a platform audit cannot see it"
    fi
  done
fi

# ===========================================================================
# 2. Android -- the manifest
# ===========================================================================

grep -q 'android:allowBackup="false"' "$MANIFEST" ||
  fail "$MANIFEST does not set allowBackup=\"false\""

grep -q 'android:fullBackupContent="false"' "$MANIFEST" ||
  fail "$MANIFEST does not set fullBackupContent=\"false\""

grep -q 'android:dataExtractionRules="@xml/data_extraction_rules"' "$MANIFEST" ||
  fail "$MANIFEST does not reference @xml/data_extraction_rules"

# ===========================================================================
# 3. Android -- the rules must cover the real filenames
# ===========================================================================
#
# Both transports, every domain. device-transfer is the one people forget: it
# is how a save reaches a *new phone* rather than a cloud.

for transport in cloud-backup device-transfer; do
  section=$(awk "/<${transport}>/,/<\/${transport}>/" "$RULES")
  if [ -z "$section" ]; then
    fail "$RULES has no <$transport> section"
    continue
  fi

  # 3a. Every domain excluded, and excluded *unscoped*.
  #
  # <exclude domain="file" path="cache"/> is still an exclude for domain
  # "file" and satisfies a naive grep, while covering nothing this app writes.
  # Only an exclude with no path attribute covers the whole domain.
  for domain in root file database sharedpref external; do
    if ! printf '%s\n' "$section" | grep -q "exclude domain=\"$domain\""; then
      fail "$RULES does not exclude domain \"$domain\" under <$transport>"
      continue
    fi
    if ! printf '%s\n' "$section" | grep -qE "<exclude[[:space:]]+domain=\"$domain\"[[:space:]]*/>"; then
      fail "$RULES narrows domain \"$domain\" under <$transport> with a path attribute. A scoped exclude does not cover ${DIR_NAME}/, so the save slots, the ledger journal, and the reconciliation identity would be backed up."
    fi
  done

  # 3b. Coverage by construction only holds while there is no <include>.
  #
  # Android inverts on the presence of an include: with none, everything is
  # backed up except the excludes; with one, the include list governs. If an
  # allowlist ever appears, every real filename must be named explicitly.
  if printf '%s\n' "$section" | grep -q '<include'; then
    echo "note: $RULES uses an <include> allowlist under <$transport>." >&2
    echo "note: domain-wide coverage no longer holds by construction, so each" >&2
    echo "note: file is now checked by name." >&2
    for name in $FILE_NAMES; do
      if ! printf '%s\n' "$section" | grep -qE "<exclude[^>]*path=\"${DIR_NAME}/${name}\""; then
        fail "$RULES <$transport> is an allowlist and does not explicitly exclude ${DIR_NAME}/${name}"
      fi
    done
  fi
done

# ===========================================================================
# 4. Layout audit -- private location, no derived path components
# ===========================================================================

grep -q 'getApplicationSupportDirectory' "$BOOTSTRAP" ||
  fail "$BOOTSTRAP does not open storage under application support"

# Documents is user-visible on iOS whenever file sharing is on, and is the
# wrong home for a step ledger. External storage on Android is readable by
# anything with the right permission and survives an app uninstall.
for banned in getApplicationDocumentsDirectory getExternalStorageDirectory getExternalStorageDirectories getExternalCacheDirectories getDownloadsDirectory; do
  if grep -q "$banned" "$BOOTSTRAP"; then
    fail "$BOOTSTRAP uses $banned. The step ledger belongs in application support only -- see TECHNICAL/STEP_LEDGER_PRIVACY.md section 5."
  fi
done

# The layout itself must not read the platform for a path component.
for banned in 'Platform\.' 'Directory\.systemTemp' 'Directory\.current' 'environment\[' 'localeName'; do
  if grep -qE "$banned" "$LAYOUT"; then
    fail "$LAYOUT reads the platform to build a path ($banned). Every path component must be a literal."
  fi
done

# ===========================================================================
# 5. iOS -- what is checkable, and an honest statement of what is not
# ===========================================================================
#
# There is no declarative iOS backup exclusion. What *is* checkable is that the
# container stays unbrowsable: these two keys are what put an app's container
# into the Files app.

for key in UIFileSharingEnabled LSSupportsOpeningDocumentsInPlace; do
  if grep -q "$key" "$IOS_PLIST"; then
    fail "$IOS_PLIST sets $key. That exposes the app container in the Files app, where the save slots and the ledger journal would be browsable and copyable."
  fi
done

# If a file-protection class is ever declared, it must be a real one -- a typo
# silently downgrades to the default rather than failing the build.
if grep -q 'NSFileProtection' "$IOS_PLIST"; then
  if ! grep -qE 'NSFileProtection(CompleteUnlessOpen|CompleteUntilFirstUserAuthentication|Complete|None)' "$IOS_PLIST"; then
    fail "$IOS_PLIST declares an unrecognised NSFileProtection value"
  fi
fi

# ===========================================================================

if [ "$failures" -gt 0 ]; then
  echo "" >&2
  echo "A restored backup would replay the step ledger against a source the" >&2
  echo "original device already consumed from. See DECISIONS/0012 and" >&2
  echo "TECHNICAL/STEP_LEDGER_PRIVACY.md section 5." >&2
  exit 1
fi

echo "storage privacy: OK"
echo "  android : allowBackup off; 2 transports x 5 domains excluded unscoped"
echo "  files   : $FILE_COUNT filenames read from StorageLayout, under ${DIR_NAME}/"
for name in $FILE_NAMES; do
  echo "            - ${DIR_NAME}/${name}"
done
echo "  layout  : application support only; every path component a literal"
echo "  ios     : NOT excluded from backup. No such control exists without"
echo "            native NSURLIsExcludedFromBackupKey code, which is unwritten."
echo "            Container is not browsable (no file-sharing keys)."
