#!/usr/bin/env bash
#
# Print the assertion messages and recorded observations from an .xcresult.
#
# ## Why this exists
#
# The Xcode on `macos-latest` (26.6 as of run 30772473185) writes NO assertion
# text to xcodebuild's stdout. A failing run's streamed log contains only:
#
#     Failing tests:
#         KeychainEntitlementProbe.testTheTestHostCanReachTheKeychain()
#     ** TEST FAILED **
#     Test case '...testTheTestHostCanReachTheKeychain()' failed on '...'
#
# and nothing about why. That is how run 30769049772 came to report twelve
# failed Keychain tests with no diagnosis, cost a full CI cycle, and left the
# cause to be argued from first principles.
#
# Two earlier attempts at fixing it failed, and both failures are informative:
#
#   * grepping the log for `.swift:NN: error:` — that format is not produced.
#   * `print()` from the test — test-process stdout does not reach the log
#     either (run 30771670303: the probe ran, passed, and printed nowhere).
#
# The messages do exist, in the result bundle. This reads them out.
#
# ## What it prints
#
#   * every XCTest failure message, which by convention in this project always
#     carries the numeric OSStatus of the call that failed
#   * every KEYCHAIN PROBE line
#   * every OBSERVED line — platform behaviour a test recorded rather than
#     asserted, e.g. what `replaceItemAt` did to NSURLIsExcludedFromBackupKey
#
# ## Failure policy
#
# Best effort, and never fatal. This is a diagnostic: a future Xcode renaming
# the subcommand must not turn a red test suite into a red *script*, or a green
# one into a broken job. It says so plainly when it cannot read the bundle,
# which is a better outcome than a step that appears to have found nothing.

set -uo pipefail

BUNDLE="${1:-}"

if [ -z "$BUNDLE" ]; then
  echo "usage: xcresult-failures.sh <path-to-.xcresult>" >&2
  exit 2
fi

if [ ! -d "$BUNDLE" ]; then
  echo "(no result bundle at $BUNDLE)"
  exit 0
fi

# Xcode 16 replaced the old object graph with `get test-results`; the old form
# survives behind --legacy. Try the modern one, fall back, and treat total
# failure as "nothing to report" rather than as an error.
# Three sources, concatenated, because none of them is guaranteed across Xcode
# versions and this script cannot be tested anywhere but CI:
#
#   `tests`    the test hierarchy; failure messages hang off the failing node
#   `summary`  a flatter document with a documented `failureText` per failure
#   `--legacy` the pre-Xcode-16 object graph
#
# Searching the concatenation means a rename in one of them costs nothing.
json="$(
  xcrun xcresulttool get test-results tests --path "$BUNDLE" --format json 2>/dev/null
  xcrun xcresulttool get test-results summary --path "$BUNDLE" --format json 2>/dev/null
  xcrun xcresulttool get --path "$BUNDLE" --format json --legacy 2>/dev/null
)"

if [ -z "$json" ]; then
  echo "(could not read $BUNDLE with xcresulttool; the bundle is uploaded as an artifact)"
  exit 0
fi

# The messages are JSON string values, so they cannot contain a raw double
# quote and `[^"]*` is a safe terminator. No JSON parser is used deliberately:
# the shape of the document has changed twice across Xcode versions and the
# text has not.
found=0

emit() {
  local label="$1" pattern="$2" hits
  hits="$(printf '%s' "$json" | grep -oE "$pattern" | sort -u | head -40)"
  if [ -n "$hits" ]; then
    printf '%s\n' "$label"
    printf '%s\n' "$hits" | sed 's/^/  /'
    found=1
  fi
}

emit "KEYCHAIN PROBE:" 'KEYCHAIN PROBE[^"]*'
emit "OBSERVED:" 'OBSERVED[^"]*'
emit "Assertion failures:" '(XCTAssert[A-Za-z]* failed|failed -)[^"]*'

if [ "$found" -eq 0 ]; then
  echo "(no failure messages or recorded observations extracted from $BUNDLE)"
  echo "The bundle is uploaded as a CI artifact and opens in Xcode, where"
  echo "activities and attachments are visible whether or not xcresulttool"
  echo "surfaces them here."
fi
