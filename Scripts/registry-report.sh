#!/usr/bin/env bash
# registry-report.sh
#
# Validates the shared case registry and prints its totals.
#
# Every number here is DERIVED from `Scripts/lib/cases.sh` by counting. None of
# them is written down anywhere, which is the point: the iOS guard was reported
# as having 6 cases when it has 17, and nothing in the repository could have
# caught that, because the only place the count existed was a string in an
# `echo`. A count that is computed cannot disagree with the thing it counts.
#
# This validates the registry as a whole. Each guard revalidates it — and
# additionally asserts its own rule inventory matches — when its `--self-test`
# runs, so a guard cannot be run against a registry this script would reject.
#
# Usage:
#   registry-report.sh            # validate and report
#   registry-report.sh --ids      # also list every case ID, per guard

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/rulekit.sh
. "$SCRIPT_DIR/lib/rulekit.sh"
# shellcheck source=lib/selftest.sh
. "$SCRIPT_DIR/lib/selftest.sh"
# shellcheck source=lib/registry.sh
. "$SCRIPT_DIR/lib/registry.sh"
# shellcheck source=lib/cases.sh
. "$SCRIPT_DIR/lib/cases.sh"

SHOW_IDS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ids) SHOW_IDS=1; shift ;;
    *) echo "STRIDE_INFRA[registry.usage] unknown option: $1" >&2; exit 2 ;;
  esac
done

if ! reg_validate; then
  echo "registry-report: FAILED -- the registry does not validate" >&2
  exit 1
fi

reg_summary

if [ "$SHOW_IDS" -eq 1 ]; then
  for g in $REG_GUARDS; do
    echo ""
    echo "$g:"
    for id in $(reg_ids_for_guard "$g"); do
      printf '  %-34s %-7s %-10s %-14s %s\n' \
        "$id" "$(reg_get "$id" expect)" "$(reg_get "$id" form)" \
        "$(reg_get "$id" attribution)" "$(reg_get "$id" rule)"
    done
  done
fi

echo ""
echo "registry-report: OK"
