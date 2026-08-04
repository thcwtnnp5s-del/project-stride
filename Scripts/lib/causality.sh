# The shared causality runner.
#
# ## What this is for, and how it differs from `reg_selftest`
#
# `reg_selftest` is what a DEVELOPER runs: one isolated root per guard, every
# case applied and reverted inside it, a clean pass at each end. It is fast
# enough to sit in `verify.sh`.
#
# This is the EVIDENCE run. It answers a stricter question — for every case in
# the registry, independently of every other case, did this exact operation
# cause this exact outcome? — and it pays for the answer in wall time. The
# difference that costs the time is that each case gets its OWN isolated root,
# built from the live tree and thrown away afterwards.
#
# ## Why a root per case
#
# A shared root makes case N's evidence conditional on cases 1..N-1 having
# restored perfectly. Restoration IS verified, so that conditional is not
# baseless — but it is still a conditional, and the failure it hides is the one
# this repository keeps producing: a later case passing on an earlier case's
# leftovers, which looks exactly like the later case working.
#
# A fresh root makes each case's evidence unconditional. Restoration is still
# verified afterwards, because a case that damages its root is a defect in the
# case whether or not anything downstream depends on it.
#
# ## What is proved, per case
#
#   1. the complete guard passes on a clean root before the case runs
#   2. the case's operation is applied exactly once
#   3. the operation changed EXACTLY its declared path set — no more (the case
#      did more than it says, and the excess is what leaks) and no less (a `sed`
#      that matched nothing still exits 0, and the rejection afterwards would be
#      credited to a mutation that never happened)
#   4. the required outcome occurs, in its own expectation class
#   5. for `named_rule`, the named rule ALONE produces the diagnostic
#   6. the declared paths restore to their exact bytes, existence, type, mode
#      and symlink target
#   7. the WHOLE root fingerprints back to its pre-case value
#   8. the complete guard passes on the restored root
#
# and, per guard, that the complete guard passes on a clean root before any of
# its cases and again after all of them.
#
# ## The three expectation classes, and why they cannot substitute
#
#   reject  exit EXACTLY 1, the case's STRIDE_GUARD diagnostic, and NO
#           STRIDE_INFRA line anywhere in the output
#   accept  exit EXACTLY 0, no STRIDE_GUARD line, no STRIDE_INFRA line
#   infra   exit EXACTLY 2 and the case's STRIDE_INFRA diagnostic. A policy
#           diagnostic is not a substitute
#
# `reject` refusing exit 2 is the whole point. A guard that rejects everything —
# because a parser mode is misspelled, because Node is missing, because the root
# is an incomplete copy — rejects every injection too, and is indistinguishable
# from a working guard to anything that only asks whether the exit was nonzero.
# Three checks in `check-android-target.sh` were dead for their entire existence
# that way, with a green self-test.
#
# Requires `rulekit.sh`, `selftest.sh`, `registry.sh` and `cases.sh`.

# ---------------------------------------------------------------------------
# JSON emission
#
# One record per case, written as it completes rather than accumulated: a run
# that is cancelled half way through must leave the evidence it had already
# earned, not an empty file.
# ---------------------------------------------------------------------------

# caus_json_str <value> — a JSON string body, escaped.
caus_json_str() {
  printf '%s' "$1" |
    sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\r//g' -e 's/\t/\\t/g' |
    awk 'NR>1 { printf "\\n" } { printf "%s", $0 } END { printf "" }'
}

# caus_json_arr <newline-separated-items>
caus_json_arr() {
  local items="$1" first=1 out="[" line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    [ "$first" -eq 1 ] || out="$out,"
    out="$out\"$(caus_json_str "$line")\""
    first=0
  done <<< "$items"
  printf '%s]' "$out"
}

# caus_diag_ids <text> — every stable diagnostic ID present, deduplicated.
#
# IDs, not prose. Prose is for the human reading the failure and is expected to
# be rewritten; matching prose would mean improving a message could silently
# stop a case from proving anything.
caus_diag_ids() {
  printf '%s\n' "$1" |
    grep -oE 'STRIDE_(GUARD|INFRA)\[[^]]*\]' |
    LC_ALL=C sort -u
}

# ---------------------------------------------------------------------------
# Named-rule attribution
# ---------------------------------------------------------------------------
#
# caus_invoke_named_rule <guard-script> <rule> <iso-root> <sourcing-output-file>
#
# Sources the guard and runs ONE rule, capturing what SOURCING printed
# separately from what the RULE printed.
#
# The separation is the proof that `guard_main` did not execute. A guard's
# source-safe entry is `[[ "${BASH_SOURCE[0]}" == "$0" ]]`; sourcing it from a
# plain subshell of a process already running that same guard makes both sides
# of that test the same string, so the guard runs `guard_main "$@"` on whatever
# positional parameters are in scope. Every early `named_rule` case failed
# identically with `usage: unknown argument` that way, and read as "the rule
# alone exited 2" rather than as a defect in the invocation.
#
# `bash -c '...' _ ...` gives the new shell a `$0` of `_`, which can never equal
# the sourced path, so the entry is false and sourcing is inert. If it were not
# inert, `guard_main` would receive this call's positional parameters and its
# report would land in the sourcing-output file — which is asserted empty.
caus_invoke_named_rule() {
  local script="$1" rule="$2" iso="$3" srcout="$4"
  PROJECT_ROOT="$iso" bash -c '
    set -uo pipefail
    . "$1" > "$3" 2>&1 || exit 2
    rule_run "$2"
  ' _ "$script" "$rule" "$srcout"
}

# ---------------------------------------------------------------------------
# One case
# ---------------------------------------------------------------------------
CAUS_FAIL_LINES=""

caus_note() {
  echo "    $1" >&2
  CAUS_FAIL_LINES="${CAUS_FAIL_LINES}$1
"
}

# caus_run_case <id> <scripts-dir> <project-root> <work-dir> <jsonl>
#
# Returns 0 if the case produced exactly its intended outcome, 1 otherwise.
# Emits one JSONL record either way: a failing case is evidence too, and a
# record that only appears on success makes a partial run indistinguishable
# from a clean one.
caus_run_case() {
  local id="$1" dir="$2" proot="$3" work="$4" jsonl="$5"

  local guard rule expect form attribution diag forbid files apply invoke
  guard="$(reg_get "$id" guard)"
  rule="$(reg_get "$id" rule)"
  expect="$(reg_get "$id" expect)"
  form="$(reg_get "$id" form)"
  attribution="$(reg_get "$id" attribution)"
  diag="$(reg_get "$id" diag)"
  forbid="$(reg_get "$id" forbid)"
  files="$(reg_get "$id" files)"
  apply="$(reg_get "$id" apply)"
  invoke="$(reg_get "$id" invoke)"

  local script="$dir/$(reg_guard_script "$guard")"

  CAUS_FAIL_LINES=""
  local bad=0
  local t0 t1 duration
  t0="$(date +%s%3N 2>/dev/null || echo 0)"

  # --- the case's own isolated root -------------------------------------
  local iso rootid store fp0 fp1 fp2
  iso="$(st_make_root)"
  rootid="$(basename "$iso")"
  # The backup store lives OUTSIDE the root. Inside it, every backup would
  # appear in the root's own fingerprint and in the guard's scan.
  store="$work/$id.store"
  fp0="$work/$id.fp0"; fp1="$work/$id.fp1"; fp2="$work/$id.fp2"

  # shellcheck disable=SC2046
  st_copy_from "$proot" "$iso" $(reg_guard_paths "$dir" "$guard")

  # --- 1. clean baseline -------------------------------------------------
  #
  # Before anything is touched. A rejection later could otherwise be the copy
  # being incomplete rather than the operation being detected — and an
  # already-failing baseline makes every outcome below meaningless, so this
  # invalidates the case rather than being noted and continued past.
  local baseline base_out base_rc
  base_out="$(bash "$script" --project-root "$iso" 2>&1)"; base_rc=$?
  if [ "$base_rc" -eq 0 ]; then
    baseline="pass"
  else
    baseline="FAIL(exit $base_rc)"
    caus_note "baseline: the clean isolated root does not pass (exit $base_rc)"
    printf '%s\n' "$base_out" | head -6 | sed 's/^/      | /' >&2
    bad=1
  fi

  local changed="" observed_exit="" out="" rc=0
  local restoration="n/a" final_clean="not-reached" attribution_result="n/a"

  if [ "$bad" -ne 0 ]; then
    # An invalid baseline is terminal. Running the operation now would produce
    # an outcome nobody can attribute, and reporting it as a pass or a fail
    # would both be lies.
    rm -rf "$iso"
    t1="$(date +%s%3N 2>/dev/null || echo 0)"
    duration=$((t1 - t0))
    caus_emit_record "$jsonl" "$id" "$guard" "$rule" "$expect" "$form" \
      "$attribution" "$rootid" "$baseline" "" "" "$diag" "" \
      "$restoration" "$final_clean" "$attribution_result" "$duration" "invalid"
    return 1
  fi

  reg_fingerprint "$iso" > "$fp0"

  CASE_ROOT="$iso"
  CASE_SCRIPT="$script"

  # --- 2. apply the operation, or invoke ---------------------------------
  if [ "$form" = mutation ]; then
    if ! reg_backup "$iso" "$store" "$files"; then
      caus_note "could not back up the declared path set"
      rm -rf "$iso" "$store"
      t1="$(date +%s%3N 2>/dev/null || echo 0)"
      caus_emit_record "$jsonl" "$id" "$guard" "$rule" "$expect" "$form" \
        "$attribution" "$rootid" "$baseline" "" "" "$diag" "" \
        "backup-failed" "not-reached" "$attribution_result" "$((t1 - t0))" "invalid"
      return 1
    fi

    if ! "$apply"; then
      caus_note "the apply function '$apply' failed"
      bad=1
    fi

    reg_fingerprint "$iso" > "$fp1"
    changed="$(LC_ALL=C sort "$fp0" "$fp1" | uniq -u | cut -f1 | LC_ALL=C sort -u)"

    # --- 3. exactly the declared path set -------------------------------
    # Both directions, and a no-op is its own failure: an operation that
    # changed nothing cannot have caused anything.
    reg_assert_changed_set "$id" "$files" "$fp0" "$fp1" || bad=1

    out="$(bash "$script" --project-root "$iso" 2>&1)"; rc=$?
  else
    # An invocation case touches no file. That is not taken on trust: the
    # fingerprint comparison below asserts it, so a case that quietly wrote to
    # the root would be caught rather than declared formless.
    out="$("$invoke" 2>&1)"; rc=$?
  fi
  observed_exit="$rc"

  # --- 4. the outcome, in its own class ----------------------------------
  local observed_diags
  observed_diags="$(caus_diag_ids "$out")"

  case "$expect" in
    reject)
      if [ "$rc" -eq 0 ]; then
        caus_note "the guard ACCEPTED it"; bad=1
      elif [ "$rc" -ne 1 ]; then
        # Exit 2 is "the guard could not look". A reject case satisfied by that
        # would be satisfied equally by deleting Node.
        caus_note "rejected with exit $rc (INFRASTRUCTURE), not a policy violation"
        printf '%s\n' "$out" | head -6 | sed 's/^/      | /' >&2
        bad=1
      elif ! printf '%s\n' "$out" | grep -qE "$diag"; then
        caus_note "rejected, but not by its own rule -- expected: $diag"
        printf '%s\n' "$out" | head -6 | sed 's/^/      | /' >&2
        bad=1
      elif printf '%s\n' "$out" | grep -qE 'STRIDE_INFRA\['; then
        # Belt and braces on top of the exit code: an infra line in the output
        # means an infrastructure failure occurred whatever the exit says.
        caus_note "the rejection carried an infrastructure diagnostic"
        printf '%s\n' "$out" | grep -E 'STRIDE_INFRA\[' | head -4 | sed 's/^/      | /' >&2
        bad=1
      fi ;;
    accept)
      if [ "$rc" -ne 0 ]; then
        caus_note "the guard REJECTED it (exit $rc)"
        printf '%s\n' "$out" | head -6 | sed 's/^/      | /' >&2
        bad=1
      elif printf '%s\n' "$out" | grep -qE 'STRIDE_GUARD\['; then
        caus_note "accepted, but emitted a violation diagnostic"; bad=1
      elif printf '%s\n' "$out" | grep -qE 'STRIDE_INFRA\['; then
        caus_note "accepted, but emitted an infrastructure diagnostic"; bad=1
      fi ;;
    infra)
      if [ "$rc" -ne 2 ]; then
        caus_note "expected an INFRASTRUCTURE failure (exit 2), got exit $rc"
        printf '%s\n' "$out" | head -6 | sed 's/^/      | /' >&2
        bad=1
      elif ! printf '%s\n' "$out" | grep -qE "$diag"; then
        caus_note "exited 2 without its own infrastructure diagnostic -- expected: $diag"
        printf '%s\n' "$out" | head -6 | sed 's/^/      | /' >&2
        bad=1
      fi ;;
  esac

  if [ -n "$forbid" ] && printf '%s\n' "$out" | grep -qE "$forbid"; then
    caus_note "the outcome carried a forbidden diagnostic matching: $forbid"
    printf '%s\n' "$out" | grep -E "$forbid" | head -4 | sed 's/^/      | /' >&2
    bad=1
  fi

  # --- 5. named-rule attribution -----------------------------------------
  #
  # `complete_guard` is already asserted above — that IS the complete guard's
  # outcome, and it is what a developer actually sees. `named_rule` adds the
  # isolation proof, for cases another rule of the same guard over-determines:
  # with ONE rule running, a mutation only some other rule can see returns 0, so
  # the case fails rather than passing on someone else's detection.
  if [ "$attribution" = named_rule ]; then
    local srcout="$work/$id.srcout" rout rrc rbad=0
    : > "$srcout"
    rout="$(caus_invoke_named_rule "$script" "$rule" "$iso" "$srcout" 2>&1)"; rrc=$?

    # The complete mutated guard must have rejected. Asserted above for a
    # reject case; restated here so a named_rule case cannot be satisfied by
    # the rule alone while the guard that developers run says nothing.
    if [ "$expect" = reject ] && [ "$rc" -ne 1 ]; then
      caus_note "named_rule: the COMPLETE guard did not reject (exit $rc)"; rbad=1
    fi

    if [ "$rrc" -ne 1 ]; then
      caus_note "named_rule: $rule invoked alone exited $rrc, not 1"
      printf '%s\n' "$rout" | head -6 | sed 's/^/      | /' >&2
      rbad=1
    elif ! printf '%s\n' "$rout" | grep -qE "$diag"; then
      caus_note "named_rule: $rule invoked alone did not emit its own diagnostic"
      printf '%s\n' "$rout" | head -6 | sed 's/^/      | /' >&2
      rbad=1
    fi

    # The forbidden set is every OTHER diagnostic of the same guard. Applying
    # it to the rule-alone output is what makes attribution exact: it is not
    # enough that the right diagnostic appeared, no unrelated rule may have
    # produced it.
    if [ -n "$forbid" ] && printf '%s\n' "$rout" | grep -qE "$forbid"; then
      caus_note "named_rule: $rule alone emitted a forbidden diagnostic matching: $forbid"
      printf '%s\n' "$rout" | grep -E "$forbid" | head -4 | sed 's/^/      | /' >&2
      rbad=1
    fi

    # Sourcing output must be EMPTY. If the guard's source-safe entry had been
    # true, guard_main would have run during sourcing and its report would be
    # in this file.
    if [ -s "$srcout" ]; then
      caus_note "named_rule: sourcing the guard produced output -- guard_main executed"
      head -6 "$srcout" | sed 's/^/      | /' >&2
      rbad=1
    fi

    if [ "$rbad" -eq 0 ]; then
      attribution_result="rule-alone exit 1, own diagnostic, guard_main not executed"
    else
      attribution_result="FAILED"
      bad=1
    fi
  elif [ "$attribution" = complete_guard ]; then
    attribution_result="complete guard, exit $rc"
  fi

  # --- 6/7. restoration ---------------------------------------------------
  if [ "$form" = mutation ]; then
    if ! reg_restore "$iso" "$store"; then
      caus_note "restoration failed"
      restoration="FAILED"
      bad=1
    else
      restoration="restored"
    fi
  else
    restoration="n/a (invocation)"
  fi

  # The whole root, not just the declared paths. `cp -a` carries mode,
  # symlinks and timestamps; the fingerprint carries existence, type, mode,
  # symlink target and exact bytes for EVERY path — which is the full set
  # restoration is required to preserve, so comparing fingerprints IS the
  # assertion rather than a proxy for it. An invocation case is held to the
  # same standard: it claims to touch nothing.
  reg_fingerprint "$iso" > "$fp2"
  if ! cmp -s "$fp0" "$fp2"; then
    if [ "$form" = mutation ]; then
      caus_note "the isolated root did not restore byte-for-byte"
      restoration="FAILED(fingerprint)"
    else
      caus_note "an invocation case modified the isolated root"
      restoration="FAILED(invocation wrote)"
    fi
    diff "$fp0" "$fp2" | head -10 | sed 's/^/      | /' >&2
    bad=1
  fi

  # --- 8. clean again ------------------------------------------------------
  if bash "$script" --project-root "$iso" >/dev/null 2>&1; then
    final_clean="pass"
  else
    final_clean="FAIL"
    caus_note "the restored isolated root does not pass the complete guard"
    bad=1
  fi

  rm -rf "$iso" "$store"

  t1="$(date +%s%3N 2>/dev/null || echo 0)"
  duration=$((t1 - t0))

  local verdict="pass"
  [ "$bad" -eq 0 ] || verdict="fail"

  caus_emit_record "$jsonl" "$id" "$guard" "$rule" "$expect" "$form" \
    "$attribution" "$rootid" "$baseline" "$changed" "$observed_exit" \
    "$diag" "$observed_diags" "$restoration" "$final_clean" \
    "$attribution_result" "$duration" "$verdict"

  if [ "$bad" -ne 0 ]; then
    echo "  CASE FAIL [$id] $expect/$attribution: $rule" >&2
    return 1
  fi
  printf '  case ok [%s] %s %s / %s (%sms)\n' "$id" "$expect" "$rule" "$attribution" "$duration"
  return 0
}

# caus_emit_record <jsonl> <id> <guard> <rule> <expect> <form> <attribution>
#                  <rootid> <baseline> <changed> <exit> <expected-diag>
#                  <observed-diags> <restoration> <final-clean>
#                  <attribution-result> <duration-ms> <verdict>
caus_emit_record() {
  local jsonl="$1"
  {
    printf '{'
    printf '"case":"%s",'          "$(caus_json_str "$2")"
    printf '"guard":"%s",'         "$(caus_json_str "$3")"
    printf '"rule":"%s",'          "$(caus_json_str "$4")"
    printf '"expect":"%s",'        "$(caus_json_str "$5")"
    printf '"form":"%s",'          "$(caus_json_str "$6")"
    printf '"attribution":"%s",'   "$(caus_json_str "$7")"
    printf '"root":"%s",'          "$(caus_json_str "$8")"
    printf '"baseline":"%s",'      "$(caus_json_str "$9")"
    shift 9
    printf '"changed_paths":%s,'   "$(caus_json_arr "$1")"
    printf '"observed_exit":"%s",' "$(caus_json_str "$2")"
    printf '"expected_diagnostic":"%s",' "$(caus_json_str "$3")"
    printf '"observed_diagnostics":%s,'  "$(caus_json_arr "$4")"
    printf '"restoration":"%s",'   "$(caus_json_str "$5")"
    printf '"final_clean":"%s",'   "$(caus_json_str "$6")"
    printf '"attribution_result":"%s",' "$(caus_json_str "$7")"
    printf '"duration_ms":%s,'     "${8:-0}"
    printf '"verdict":"%s"'        "$(caus_json_str "$9")"
    printf '}\n'
  } >> "$jsonl"
}

# ---------------------------------------------------------------------------
# One guard: a clean root before its cases, every case, a clean root after
# ---------------------------------------------------------------------------
#
# caus_run_guard <guard-id> <scripts-dir> <project-root> <work-dir> <jsonl>
caus_run_guard() {
  local guard="$1" dir="$2" proot="$3" work="$4" jsonl="$5"
  local script="$dir/$(reg_guard_script "$guard")"
  local fails=0 ok=0 id

  echo ""
  echo "=== $guard ($(reg_count_for_guard "$guard") case(s)) ==="

  # The complete guard on a clean root, before anything. Its own root, thrown
  # away immediately: the point is that the guard and the copy agree BEFORE any
  # case has had a chance to leave something behind.
  local pre
  pre="$(st_make_root)"
  # shellcheck disable=SC2046
  st_copy_from "$proot" "$pre" $(reg_guard_paths "$dir" "$guard")
  if bash "$script" --project-root "$pre" >/dev/null 2>&1; then
    echo "  clean guard BEFORE cases: pass ($(basename "$pre"))"
  else
    echo "  $guard: the complete guard does not pass a clean isolated root BEFORE its cases" >&2
    bash "$script" --project-root "$pre" 2>&1 | head -12 | sed 's/^/    | /' >&2
    rm -rf "$pre"
    return 1
  fi
  rm -rf "$pre"

  for id in $(reg_ids_for_guard "$guard"); do
    if caus_run_case "$id" "$dir" "$proot" "$work" "$jsonl"; then
      ok=$((ok + 1))
    else
      fails=$((fails + 1))
    fi
  done

  local post
  post="$(st_make_root)"
  # shellcheck disable=SC2046
  st_copy_from "$proot" "$post" $(reg_guard_paths "$dir" "$guard")
  if bash "$script" --project-root "$post" >/dev/null 2>&1; then
    echo "  clean guard AFTER cases:  pass ($(basename "$post"))"
  else
    echo "  $guard: the complete guard does not pass a clean isolated root AFTER its cases" >&2
    bash "$script" --project-root "$post" 2>&1 | head -12 | sed 's/^/    | /' >&2
    fails=$((fails + 1))
  fi
  rm -rf "$post"

  printf '  %s: %s of %s case(s) held\n' "$guard" "$ok" "$((ok + fails))"
  [ "$fails" -eq 0 ]
}
