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
# iOS: what changed, and what is still not proven
# ---------------------------------------------------------------------------
#
# There is still no Info.plist key and no build setting that excludes a file
# from iCloud or iTunes backup. The only mechanism is
# NSURLIsExcludedFromBackupKey, set per-URL at runtime from native code.
#
# That code now exists, in packages/stride_secure_store. Two controls, from the
# owner's F-06 closure ruling:
#
#   1. The reconciliation identity moved into the Keychain with
#      kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly. ThisDeviceOnly items
#      are not in an encrypted backup and are not restored to a different
#      device, so a restored phone finds progress with no key and blocks with
#      originIdentityMissing.
#   2. NSURLIsExcludedFromBackupKey is applied, on every launch, to the
#      project_stride directory AND to every file StorageLayout declares.
#
# Why both. Before this, the identity file travelled in the same backup as the
# save, so on the restored device the salt fingerprint still matched, the load
# succeeded, and LoadRefusal.originKeyReset never fired. The fail-closed check
# was defeated by the exact transport it was designed to detect. Control 1
# restores the refusal; control 2 stops the ledger travelling at all.
#
# **What this guard checks is that the code is wired, not that Apple honours
# it.** No CI runner and no simulator can perform an iCloud backup and restore
# onto a second device. That the attribute is set, and that the accessibility
# constant is the one we asked for, is asserted by
# packages/stride_secure_store/example/ios/RunnerTests. Everything downstream
# of Apple's backup implementation is documented behaviour this design relies
# on and has not verified.
#
# Application Support on iOS is still backed up by default; iOS default file
# protection is still NSFileProtectionCompleteUntilFirstUserAuthentication.
# Neither of those changed. What changed is that the identity is no longer in
# that directory, and the directory now asks not to be backed up.
#
# Flagged by the F-05 Privacy Auditor as the one privacy control with no
# in-code enforcement; extended by the F-06 Platform Security audit; closed on
# the iOS side by the F-06 Apple Security pass.

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
# 5. iOS -- the container must stay unbrowsable
# ===========================================================================
#
# These two keys are what put an app's container into the Files app.

for key in UIFileSharingEnabled LSSupportsOpeningDocumentsInPlace; do
  if grep -q "$key" "$IOS_PLIST"; then
    fail "$IOS_PLIST sets $key. That exposes the app container in the Files app, where the save slots and the ledger journal would be browsable and copyable."
  fi
done

# ===========================================================================
# 6. iOS -- the Keychain identity and the backup exclusion must be wired
# ===========================================================================
#
# Checked here rather than only in Swift, because the Swift is compiled and
# tested on the macOS CI job alone. A branch that deleted this plugin, or
# relaxed the accessibility class, would otherwise reach review with three
# green Linux jobs.

KEYCHAIN="packages/stride_secure_store/ios/stride_secure_store/Sources/stride_secure_store/KeychainIdentityStore.swift"
EXCLUSION="packages/stride_secure_store/ios/stride_secure_store/Sources/stride_secure_store/BackupExclusion.swift"
VAULT="lib/runtime/identity_vault.dart"
SWIFT_TESTS="packages/stride_secure_store/example/ios/RunnerTests/RunnerTests.swift"

for file in "$KEYCHAIN" "$EXCLUSION" "$VAULT" "$SWIFT_TESTS"; do
  if [ ! -f "$file" ]; then
    fail "$file is missing. The iOS device-bound identity is the control that makes an iCloud restore fail closed; without it a restored device replays the ledger against a health source the first device already consumed from."
  fi
done

if [ "$failures" -eq 0 ]; then
  # 6a. The accessibility class. ThisDeviceOnly is the entire control: it is
  # what keeps the item out of an encrypted backup and off a restored device.
  grep -q 'kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly' "$KEYCHAIN" ||
    fail "$KEYCHAIN does not use kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly. Any accessibility class without the ThisDeviceOnly suffix is restored onto a second device, which re-opens the double-grant this exists to close."

  # A ThisDeviceOnly-less constant anywhere in the file is almost certainly a
  # relaxation. `kSecAttrAccessibleAfterFirstUnlock` is a prefix of the correct
  # constant, so it is matched with a trailing word boundary.
  if grep -qE 'kSecAttrAccessible(WhenUnlocked|AfterFirstUnlock|Always)([^A-Za-z]|$)' "$KEYCHAIN"; then
    fail "$KEYCHAIN references an accessibility class without the ThisDeviceOnly suffix. Those items ARE restored to a different device."
  fi

  # 6b. Add-only. There is no update path, and its absence is what enforces
  # "never overwrite an existing key because a read failed".
  if grep -qE 'SecItemUpdate[[:space:]]*[(]' "$KEYCHAIN"; then
    fail "$KEYCHAIN calls SecItemUpdate. The identity store is add-only by design: an existing item is either the live one or evidence of a crash between minting and the first commit, and replacing it orphans a save."
  fi
  grep -q 'SecItemAdd' "$KEYCHAIN" ||
    fail "$KEYCHAIN does not call SecItemAdd"

  # 6c. iCloud Keychain sync would be a second way for the identity to reach
  # another device.
  grep -q 'kSecAttrSynchronizable' "$KEYCHAIN" ||
    fail "$KEYCHAIN does not set kSecAttrSynchronizable. An identity that syncs through iCloud Keychain defeats the control just as thoroughly as a backup does."

  # 6d. The exclusion itself, and its read-back. "The setter did not throw" and
  # "the attribute is set" are different claims.
  grep -q 'isExcludedFromBackup' "$EXCLUSION" ||
    fail "$EXCLUSION does not set NSURLIsExcludedFromBackupKey"

  # 6e. The exclusion must be re-applied on every launch. The attribute lives
  # on the filesystem node, so a directory recreated by a restore, a reinstall,
  # or ensureExists after a wipe loses it with nothing reporting so.
  grep -q 'applyBackupExclusions' "$VAULT" ||
    fail "$VAULT does not apply backup exclusions at startup. The attribute is lost whenever the directory is recreated, so a one-shot application is correct until the first restore and silently wrong forever after."

  # 6f. The exclusion must cover the *declared* files, read out of the layout
  # rather than from a list someone remembered.
  grep -q 'layout.allFiles' "$VAULT" ||
    fail "$VAULT does not pass StorageLayout.allFiles to the backup exclusion. A hardcoded list goes stale the first time a file is added, and then asserts coverage of filenames that no longer matter."

  # 6g. The Swift test list of filenames is a duplicate of StorageLayout,
  # because StorageLayout is Dart and unreachable from Swift. Checked, so the
  # duplicate cannot drift.
  for name in $FILE_NAMES; do
    if ! grep -q "\"$name\"" "$SWIFT_TESTS"; then
      fail "$SWIFT_TESTS does not name '$name'. Its declaredFiles list duplicates StorageLayout because Swift cannot read Dart; a drifted duplicate means the simulator suite proves coverage of a layout the app no longer has."
    fi
  done

  # 6h. The salt must not also be left in a file on iOS. A file copy travels in
  # a backup and re-opens the exact hole the Keychain closes.
  grep -q 'no file-to-Keychain migration' "$VAULT" ||
    fail "$VAULT no longer documents why there is no file-to-Keychain migration. A migration would read the identity file that DID travel in the restore and write it into the new device's Keychain, at which point the fingerprints match again and the refusal is gone."

  # 6i. The per-write re-application entry point.
  #
  # NSURLIsExcludedFromBackupKey is a resource value on the filesystem NODE. A
  # rename over the top, an atomic write, or a replace leaves the path naming a
  # different node, which carries none of the old node's attributes.
  # FileLedgerJournal.replaceLines renames a sidecar over the journal on every
  # compaction, so a launch-only application is correct until the first
  # compaction and silently wrong after it. Demonstrated on a real APFS volume
  # by testARenameOverTheTopDropsTheExclusion in the simulator suite.
  PORT="packages/stride_secure_store/lib/src/secure_identity_store.dart"
  CONTRACT="packages/stride_secure_store/BACKUP_EXCLUSION_CONTRACT.md"

  grep -q 'reapplyBackupExclusions' "$PORT" ||
    fail "$PORT no longer exposes reapplyBackupExclusions. Without a per-write entry point the exclusion is applied once at launch, and the journal loses it on the first compaction."

  grep -q 'reapplyBackupExclusions' "$EXCLUSION" ||
    grep -q 'apply(paths:' "$EXCLUSION" ||
    fail "$EXCLUSION has no path-list entry point for the per-write re-application."

  [ -f "$CONTRACT" ] ||
    fail "$CONTRACT is missing. It is the only place the required call sites in stride_storage and lib/runtime are written down."
fi

# ===========================================================================
# 7. The per-write call sites
# ===========================================================================
#
# The launch sweep alone is not the control. NSURLIsExcludedFromBackupKey
# belongs to the filesystem *node*, not the path, so it is lost whenever the
# path comes to name a different node. The snapshot slots, the journal and the
# lock file are all created after the sweep has run, and replaceLines renames a
# sidecar over the journal on every compaction -- which discards an exclusion
# the journal previously had. That last one is a regression, not a gap.
#
# These were notes while the call sites were unwired. They are failures now.
# Contract: packages/stride_secure_store/BACKUP_EXCLUSION_CONTRACT.md

STORAGE="packages/stride_storage/lib/src/file_storage.dart"
LOCKSRC="packages/stride_storage/lib/src/file_lock.dart"
RUNTIME="lib/runtime/runtime_bootstrap.dart"

if [ -f "$STORAGE" ]; then
  if ! grep -q 'typedef ReapplyBackupExclusion' "$STORAGE"; then
    fail "$STORAGE does not declare ReapplyBackupExclusion"
  fi
  # Each required site is checked WHERE IT MUST BE, not counted.
  #
  # This was a count -- `grep -c ... -lt 6`. A closure critic deleted the real
  # snapshot-slot call site, added `reapplyExclusion?.call(<String>[])` inside
  # erase() as a decoy, and this script printed OK and exited 0 while the save
  # slots went unexcluded. All 105 storage tests stayed green too. A count
  # cannot tell a call site from a decoy, so each one is now anchored to the
  # write it must follow.
  #
  # `after_in`: within the function body starting at $2, is there a call to
  # reapplyExclusion after a line matching $3?
  after_in() {
    awk -v fn="$2" -v anchor="$3" '
      index($0, fn) { infn=1 }
      infn && $0 ~ anchor { armed=1; next }
      armed && /reapplyExclusion\?\.call/ { found=1; exit }
      # Bounded to the method body, or the scan finds an unrelated call site
      # further down the file and reports a missing one as present.
      armed && /^  \}/ { exit }
      armed && /^  [A-Za-z@]/ { exit }
      END { exit !found }
    ' "$1"
  }

  # Snapshot slots. Created by their first write, after the launch sweep has
  # already looked for them and correctly reported them missing.
  if ! after_in "$STORAGE" 'Future<void> write(SnapshotSlot slot' 'await writeVerified'; then
    fail "$STORAGE does not re-apply the exclusion after a snapshot slot write"
  fi

  # The journal, created by its first append.
  if ! after_in "$STORAGE" 'Future<void> appendLine' 'append read-back'; then
    fail "$STORAGE does not re-apply the exclusion after a journal append"
  fi

  # The compaction swap, BOTH halves.
  #
  # Before the rename: a death between write and rename leaves the sidecar on
  # disk, and the launch sweep reported it missing because it did not exist.
  if ! awk '/await writeVerified\(layout\.journalSidecar/{armed=1; next} armed && /reapplyExclusion\?\.call/{found=1; exit} armed && /journalSidecar\.rename/{exit} END{exit !found}' "$STORAGE"; then
    fail "$STORAGE does not re-apply the exclusion to the sidecar BEFORE the compaction rename"
  fi
  # After the rename: the journal path now names the sidecar's node, carrying
  # the sidecar's attributes. This is the regression case -- the journal LOSES
  # an exclusion it had -- and it is the easiest to drop in a refactor, because
  # the code reads perfectly well without it.
  #
  # Bounded to the method body. Unbounded, this scan walked off the end of
  # replaceLines and found the identity-write call site hundreds of lines
  # later, so deleting the post-rename call still passed -- the same
  # "a scan that cannot fail" defect this section exists to prevent, in the
  # check itself. `^  }` is the method's closing brace at two-space indent.
  if ! awk '
      /journalSidecar\.rename/ { seen=1; next }
      seen && /reapplyExclusion\?\.call/ { found=1; exit }
      seen && /^  \}/ { exit }
      END { exit !found }
    ' "$STORAGE"; then
    fail "$STORAGE does not re-apply the exclusion AFTER the compaction rename"
  fi

  # Both identity writes.
  if ! after_in "$STORAGE" 'Future<void> writeStored' 'await writeVerified'; then
    fail "$STORAGE does not re-apply the exclusion after writeStored"
  fi
  if ! after_in "$STORAGE" 'Future<void> write(ReconciliationIdentity' 'await writeVerified'; then
    fail "$STORAGE does not re-apply the exclusion after the core-facing identity write"
  fi

  # A call with an empty path list excludes nothing. It exists only to satisfy
  # a scan, which is precisely how the count was defeated.
  if grep -qE 'reapplyExclusion\?\.call\(\s*<String>\[\s*\]\s*\)' "$STORAGE"; then
    fail "$STORAGE calls reapplyExclusion with an empty path list, which excludes nothing"
  fi
fi

if [ -f "$LOCKSRC" ] && ! grep -q 'reapplyExclusion?\.call' "$LOCKSRC"; then
  fail "$LOCKSRC does not re-apply the exclusion after creating the lock file"
fi

# A hook that is declared and never injected is worse than none: the guards
# above would pass and the control would still be a launch sweep only.
if [ -f "$RUNTIME" ]; then
  injected=$(grep -c 'reapplyExclusion: hook()' "$RUNTIME" || true)
  if [ "$injected" -lt 3 ]; then
    fail "$RUNTIME injects the exclusion hook into only $injected of 3 sites (snapshots, journal, lock)"
  fi
fi

# The identity store is constructed inside the vault, not the bootstrap, so it
# is injected separately. Null on iOS -- the identity lives in the Keychain, not
# in this file -- but wired regardless, so the next platform is not a special
# case.
VAULT="lib/runtime/identity_vault.dart"
if [ -f "$VAULT" ] && ! grep -q 'reapplyExclusion:' "$VAULT"; then
  fail "$VAULT does not inject the exclusion hook into FileIdentityStore"
fi

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
echo "  ios     : identity in the Keychain, AfterFirstUnlockThisDeviceOnly,"
echo "            add-only, not synchronizable."
echo "            NSURLIsExcludedFromBackupKey applied to the directory and"
echo "            every declared file at launch, AND re-applied per write:"
echo "            snapshot writes, journal appends, both halves of the"
echo "            compaction swap, identity writes, and lock creation."
echo "            Container is not browsable (no file-sharing keys)."
echo "            NOT PROVEN HERE: that Apple honours either control. That"
echo "            needs two physical iPhones, an iCloud account, and a real"
echo "            backup and restore."
