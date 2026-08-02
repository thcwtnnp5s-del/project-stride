#!/usr/bin/env bash
#
# The step ledger must never be copied off the device by the platform.
#
# An automatic backup restored onto a second device replays a monotonic step
# ledger against a health source the original already consumed from, producing
# exactly the double-count the whole reconciliation design exists to prevent —
# silently, and weeks after the fact.
#
# The exclusions are domain-wide rather than a filename allowlist, which is the
# right shape: `save_slot_a`, `save_slot_b`, and `journal` are covered by
# construction, and an allowlist would have silently missed them when F-05
# renamed the artifacts. But nothing in Dart can assert any of this, so a
# manifest edit — or a library manifest merged in by a future plugin — would
# change it with no test failing. That is what this guard is for.
#
# Flagged by the F-05 Privacy Auditor as the one privacy control with no
# in-code enforcement.

set -euo pipefail

MANIFEST="android/app/src/main/AndroidManifest.xml"
RULES="android/app/src/main/res/xml/data_extraction_rules.xml"
failures=0

fail() {
  echo "backup exclusions: FAIL — $1" >&2
  failures=$((failures + 1))
}

for file in "$MANIFEST" "$RULES"; do
  if [ ! -f "$file" ]; then
    fail "$file is missing"
  fi
done

if [ "$failures" -gt 0 ]; then
  exit 1
fi

# The manifest must switch backup off outright, not merely point at the rules.
grep -q 'android:allowBackup="false"' "$MANIFEST" ||
  fail "$MANIFEST does not set allowBackup=\"false\""

grep -q 'android:fullBackupContent="false"' "$MANIFEST" ||
  fail "$MANIFEST does not set fullBackupContent=\"false\""

grep -q 'android:dataExtractionRules="@xml/data_extraction_rules"' "$MANIFEST" ||
  fail "$MANIFEST does not reference @xml/data_extraction_rules"

# Both transports, every domain. device-transfer is the one people forget:
# it is how a save reaches a *new phone* rather than a cloud.
for transport in cloud-backup device-transfer; do
  section=$(awk "/<${transport}>/,/<\/${transport}>/" "$RULES")
  if [ -z "$section" ]; then
    fail "$RULES has no <$transport> section"
    continue
  fi
  for domain in root file database sharedpref external; do
    echo "$section" | grep -q "exclude domain=\"$domain\"" ||
      fail "$RULES does not exclude domain \"$domain\" under <$transport>"
  done
done

if [ "$failures" -gt 0 ]; then
  echo "" >&2
  echo "A restored backup would replay the step ledger against a source the" >&2
  echo "original device already consumed from. See DECISIONS/0012 and" >&2
  echo "TECHNICAL/STEP_LEDGER_PRIVACY.md §5." >&2
  exit 1
fi

echo "backup exclusions: OK (2 transports x 5 domains, allowBackup off)"
