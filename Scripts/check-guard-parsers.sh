#!/usr/bin/env bash
# check-guard-parsers.sh
#
# Proves `Scripts/lib/xmlq.js` — the layer every structured-file guard now
# rests on — actually behaves as those guards assume.
#
# ## Why a guard needs its own guard
#
# The manifest and plist checks used to be `grep` plus `sed` comment-stripping.
# Three defects came out of that, two of which matched the file's OWN PROSE
# about the forbidden thing and failed a correct tree. Moving to a parser fixes
# that class — but only if the parser is right. A security decision resting on
# an untested parser has relocated the risk, not removed it.
#
# Every case here is a fabricated document in a temp directory. The live tree
# is never touched.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XMLQ="$SCRIPT_DIR/lib/xmlq.js"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/stride-parser-XXXXXXXX")"
trap 'rm -rf "$WORK"' EXIT

pass=0
failures=0

ok()   { pass=$((pass + 1)); echo "  ok      $1"; }
bad()  { failures=$((failures + 1)); echo "  FAILED  $1" >&2; }

# expect_exit <expected> <label> <file> <args...>
expect_exit() {
  local want="$1" label="$2"; shift 2
  node "$XMLQ" "$@" >/dev/null 2>&1
  local got=$?
  [ "$got" -eq "$want" ] && ok "$label" || bad "$label (exit $got, wanted $want)"
}

# expect_out <expected-substring|EMPTY> <label> <file> <args...>
expect_out() {
  local want="$1" label="$2"; shift 2
  local out
  out="$(node "$XMLQ" "$@" 2>/dev/null)"
  if [ "$want" = "EMPTY" ]; then
    [ -z "$out" ] && ok "$label" || bad "$label (got '$out', wanted empty)"
  else
    case "$out" in *"$want"*) ok "$label" ;; *) bad "$label (got '$out', wanted '$want')" ;; esac
  fi
}

echo "guard-parsers: Android manifest"

# --- the forbidden attribute, found by namespace not by prefix --------------
cat > "$WORK/m-plain.xml" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
  xmlns:tools="http://schemas.android.com/tools">
  <uses-sdk tools:overrideLibrary="androidx.health.connect.client" />
</manifest>
XML
expect_out "overrideLibrary" "tools:overrideLibrary is detected" \
  "$WORK/m-plain.xml" attr-ns android-tools overrideLibrary

# A RENAMED PREFIX. The whole reason to resolve by URI: a grep for `tools:`
# misses this entirely, and it is a one-word edit away from the real file.
cat > "$WORK/m-renamed.xml" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
  xmlns:t="http://schemas.android.com/tools">
  <uses-sdk t:overrideLibrary="androidx.health.connect.client" />
</manifest>
XML
expect_out "overrideLibrary" "a RENAMED tools prefix is still detected" \
  "$WORK/m-renamed.xml" attr-ns android-tools overrideLibrary

# A prefix that merely LOOKS right but binds elsewhere must not match.
cat > "$WORK/m-decoy.xml" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
  xmlns:tools="http://example.invalid/not-android-tools">
  <uses-sdk tools:overrideLibrary="androidx.health.connect.client" />
</manifest>
XML
expect_out "EMPTY" "a tools: prefix bound to another namespace does not match" \
  "$WORK/m-decoy.xml" attr-ns android-tools overrideLibrary

# --- comments cannot create a finding ---------------------------------------
cat > "$WORK/m-comment.xml" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <!--
    There is deliberately NO tools:overrideLibrary here, and this multi-line
    comment names it on purpose. tools:overrideLibrary
  -->
  <uses-permission android:name="android.permission.health.READ_STEPS" />
</manifest>
XML
expect_out "EMPTY" "a multi-line comment naming the attribute is not a finding" \
  "$WORK/m-comment.xml" attr-ns android-tools overrideLibrary

# --- attribute order and quoting are not semantics ---------------------------
cat > "$WORK/m-order.xml" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
  xmlns:tools="http://schemas.android.com/tools">
  <uses-sdk android:minSdkVersion='26' tools:overrideLibrary='x' />
</manifest>
XML
expect_out "overrideLibrary" "attribute reordering does not matter" \
  "$WORK/m-order.xml" attr-ns android-tools overrideLibrary
expect_out "26" "single quotes are equivalent to double" \
  "$WORK/m-order.xml" attr-ns http://schemas.android.com/apk/res/android minSdkVersion

# --- declaration, BOM, whitespace, entities ---------------------------------
printf '\xEF\xBB\xBF<?xml version="1.0" encoding="utf-8"?>\n<manifest xmlns:android="http://schemas.android.com/apk/res/android"\n  xmlns:tools="http://schemas.android.com/tools"\n>\n\n  <uses-sdk\n     tools:overrideLibrary="a&amp;b" />\n</manifest>\n' > "$WORK/m-bom.xml"
expect_out "a&b" "BOM, XML declaration, odd whitespace and entities are handled" \
  "$WORK/m-bom.xml" attr-ns android-tools overrideLibrary

# --- malformed fails CLOSED --------------------------------------------------
cat > "$WORK/m-broken.xml" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-sdk
</manifest>
XML
expect_exit 2 "malformed XML fails closed (exit 2, not silent empty)" \
  "$WORK/m-broken.xml" attr-ns android-tools overrideLibrary

cat > "$WORK/m-unclosed.xml" <<'XML'
<manifest><application></manifest>
XML
expect_exit 2 "mismatched tags fail closed" \
  "$WORK/m-unclosed.xml" attr-ns android-tools overrideLibrary

expect_exit 2 "a missing file fails closed" \
  "$WORK/does-not-exist.xml" attr-ns android-tools overrideLibrary

echo "guard-parsers: plist and entitlements"

cat > "$WORK/p-good.plist" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <!-- com.apple.developer.healthkit.background-delivery is deliberately absent -->
  <key>com.apple.developer.healthkit</key>
  <true/>
  <key>NSHealthShareUsageDescription</key>
  <string>Stride reads your step count.</string>
</dict>
</plist>
XML
expect_exit 0 "an exact top-level key is found" \
  "$WORK/p-good.plist" has-key NSHealthShareUsageDescription
expect_exit 1 "NSHealthShareUsageDescriptionX does NOT satisfy the exact key" \
  "$WORK/p-good.plist" has-key NSHealthShareUsageDescriptionX
expect_exit 1 "a comment naming background-delivery is not a key" \
  "$WORK/p-good.plist" has-key com.apple.developer.healthkit.background-delivery

# --- nested keys do not satisfy top-level requirements -----------------------
cat > "$WORK/p-nested.plist" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>SomeContainer</key>
  <dict>
    <key>NSHealthShareUsageDescription</key>
    <string>buried, and therefore not granted</string>
  </dict>
</dict>
</plist>
XML
expect_exit 1 "a NESTED key does not satisfy a required top-level key" \
  "$WORK/p-nested.plist" has-key NSHealthShareUsageDescription

# --- duplicates are rejected -------------------------------------------------
cat > "$WORK/p-dupe.plist" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>com.apple.developer.healthkit</key>
  <true/>
  <key>com.apple.developer.healthkit</key>
  <false/>
</dict>
</plist>
XML
expect_exit 1 "a DUPLICATED security-sensitive key is rejected, not taken" \
  "$WORK/p-dupe.plist" has-key com.apple.developer.healthkit
expect_out "com.apple.developer.healthkit	2" "duplicates are reported" \
  "$WORK/p-dupe.plist" dupe-keys

# --- the forbidden entitlement is found when genuinely present ---------------
cat > "$WORK/p-bg.plist" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>com.apple.developer.healthkit.background-delivery</key>
  <true/>
</dict>
</plist>
XML
expect_exit 0 "the background-delivery entitlement IS found when present" \
  "$WORK/p-bg.plist" has-key com.apple.developer.healthkit.background-delivery

# --- malformed plist structure fails closed ----------------------------------
cat > "$WORK/p-nodict.plist" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
  <array><string>no dict at all</string></array>
</plist>
XML
expect_exit 2 "a plist with no top-level dict fails closed" \
  "$WORK/p-nodict.plist" keys

cat > "$WORK/p-twodicts.plist" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
  <dict><key>a</key><string>1</string></dict>
  <dict><key>b</key><string>2</string></dict>
</plist>
XML
expect_exit 2 "a plist with two top-level dicts fails closed (ambiguous)" \
  "$WORK/p-twodicts.plist" keys

cat > "$WORK/p-notplist.xml" <<'XML'
<notaplist><dict><key>x</key><string>y</string></dict></notaplist>
XML
expect_exit 2 "a non-plist root fails closed" "$WORK/p-notplist.xml" keys

# ---------------------------------------------------------------------------
# `parses` — readability WITHOUT a schema opinion
#
# These exist because of a real defect. `xmlq_parses` and the Android guard
# both asked for `keys` to learn whether a document could be read. `keys` is a
# PLIST mode: handed an Android manifest it answers "not a plist" with exit 2,
# which is the same code as "malformed" — so all three well-formed manifests
# were reported as unreadable XML, and the guard failed the tree for a reason
# that did not exist.
#
# The tri-state contract says exit 2 is never absence. It does not say every
# exit 2 has the same cause. Asking a schema-specific question to learn a
# schema-independent fact is how that got confused, and the fixtures below pin
# the separation in both directions.
# ---------------------------------------------------------------------------
cat > "$WORK/m-plain.xml" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application android:label="x"/>
</manifest>
XML
expect_exit 0 "a well-formed NON-plist document parses" "$WORK/m-plain.xml" parses
expect_out "manifest" "parses reports the root element name" "$WORK/m-plain.xml" parses
expect_exit 2 "the same document is still NOT a plist" "$WORK/m-plain.xml" keys
expect_exit 0 "a well-formed plist also parses" "$WORK/p-bg.plist" parses
# An EXISTING but malformed file. The first version of this case pointed at a
# fixture that was never created, so it passed because a missing file also
# exits 2 -- the same over-determination these fixtures exist to catch, in a
# case written to catch it. The two causes are now separated: `m-broken.xml` is
# real and unparseable, the line below is genuinely absent.
expect_exit 2 "malformed input fails closed under parses too" \
  "$WORK/m-broken.xml" parses
expect_exit 2 "a missing file fails closed under parses" \
  "$WORK/does-not-exist.xml" parses

# ---------------------------------------------------------------------------
# `attr-ns` element narrowing
#
# The Android guard called a mode named `attr` that has never existed in
# xmlq.js. Three checks used it -- tools:overrideLibrary, a manifest uses-sdk
# floor, and background <service>/<receiver> -- and every call exited 2 into
# `|| true`, so all three were dead from the day they were written. They looked
# green only because the guard was already failing on the parse bug above:
# every injection was "rejected", for a reason that had nothing to do with the
# check under test.
#
# The narrowing argument is what those checks actually needed: "is
# minSdkVersion declared ON <uses-sdk>", not "anywhere in the document".
# ---------------------------------------------------------------------------
cat > "$WORK/m-narrow.xml" <<'XML'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-sdk android:minSdkVersion="24"/>
  <application android:minSdkVersion="99" android:label="decoy"/>
</manifest>
XML
expect_out "uses-sdk	minSdkVersion	24" "attr-ns narrowed to one element" \
  "$WORK/m-narrow.xml" attr-ns android minSdkVersion uses-sdk
expect_exit 1 "narrowing to an absent element does not match" \
  "$WORK/m-narrow.xml" attr-ns android minSdkVersion service
expect_exit 0 "without narrowing, both elements match" \
  "$WORK/m-narrow.xml" attr-ns android minSdkVersion
expect_out "application" "the decoy is visible only without narrowing" \
  "$WORK/m-narrow.xml" attr-ns android minSdkVersion

# The `android` alias must resolve to the URI, not to the prefix text.
cat > "$WORK/m-alias.xml" <<'XML'
<manifest xmlns:a="http://schemas.android.com/apk/res/android">
  <uses-sdk a:minSdkVersion="26"/>
</manifest>
XML
expect_out "uses-sdk	minSdkVersion	26" \
  "a RENAMED android prefix still resolves by URI" \
  "$WORK/m-alias.xml" attr-ns android minSdkVersion uses-sdk

cat > "$WORK/m-wrongns.xml" <<'XML'
<manifest xmlns:android="http://example.invalid/not-android">
  <uses-sdk android:minSdkVersion="24"/>
</manifest>
XML
expect_exit 1 "an android: prefix bound elsewhere does NOT match the alias" \
  "$WORK/m-wrongns.xml" attr-ns android minSdkVersion uses-sdk

echo ""
if [ "$failures" -gt 0 ]; then
  echo "guard-parsers: FAILED -- $failures of $((pass + failures)) cases" >&2
  exit 1
fi
echo "guard-parsers: OK -- $pass cases"
