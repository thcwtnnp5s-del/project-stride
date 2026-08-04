# Guard case map

Every mutation case a guard's `--self-test` injects, recorded **before** its
embedded inventory is replaced by the shared registry.

## Registry migration status

| guard | status | where its cases live |
|-------|--------|----------------------|
| `check-android-target.sh` | **migrated** | `Scripts/lib/cases.sh` |
| `check-ios-target.sh` | **migrated** | `Scripts/lib/cases.sh` |
| `check-single-writer.sh` | **migrated** | `Scripts/lib/cases.sh` |
| `check-origin-privacy.sh` | **migrated** | `Scripts/lib/cases.sh` |
| `check-step-model.sh` | **migrated** | `Scripts/lib/cases.sh` |

A migrated guard holds **no** case inventory and **no** mutation code. Its
`--self-test` is one call to `reg_selftest`, and `Scripts/lib/registry.sh`
refuses to run it if any mutation machinery comes back — a second mutation
source is the drift this file was written to record and the registry was
written to remove.

The registry adds three things the embedded inventories did not have:

* **a declared changed-path set per case**, asserted in both directions. An
  undeclared change means the case did more than it says, and the extra damage
  is what the next case would pass on. A declared path that did *not* change
  means the case did less than it says — a `sed` that matches nothing still
  exits 0, and the rejection afterwards would be attributed to a mutation that
  never happened.
* **generic restoration**, verified by fingerprinting the whole isolated root —
  existence, exact bytes, file type, mode and symlink target of every path —
  before the case and after restoration. There is no hand-written revert to be
  subtly wrong.
* **derived totals.** Nothing writes a count down. `Scripts/registry-report.sh`
  and every guard's self-test compute theirs by counting the registry, which is
  the specific failure this file opens by describing.

Derived totals for the migrated set: run `Scripts/registry-report.sh`. Nothing
here is the source of truth for a count — that is the whole point, and a total
written into this file would be the same second source the registry removed.
See the note under `ios_entitlements_absent` below for why the iOS layering case
counts as `reject` rather than `infra`.

### Android case-ID traceability — no rename occurred

An earlier report cited Android case IDs in an `and_*` form
(`and_min_sdk_plugin_24`, `and_min_sdk_example_25`, `and_min_sdk_inherit`,
`and_override_library`, `and_manifest_uses_sdk_24`, `and_background_service`,
`and_comment_only_override`) which do not match the registry's `android_*` IDs.
That discrepancy was checked against the history rather than assumed, because
"the IDs were renamed" and "the report invented IDs" have opposite remedies —
the first needs a former-ID mapping so old reports stay resolvable, the second
must not get one, since a mapping table would manufacture provenance for
identifiers that never existed.

The history says the report was inaccurate:

* No `and_*` identifier appears in any blob of any commit on any ref
  (`git rev-list --all | xargs git grep`, and `git log --all -S` per ID, both
  empty). They were never written down in the repository.
* Before `4d02e4f`, the Android self-test had **no** case identifiers at all.
  Each case was named only by the English sentence in its `expect_reject` call
  ("plugin minSdk lowered to 24"). The `and_*` strings were report-local labels
  coined to describe those sentences.
* The canonical `android_*` IDs were minted **once**, in this file at
  `4d02e4f`, alongside the named-rule conversion, and the registry adopted them
  verbatim at `e599a89`. The Android ID set in this file is byte-identical
  between those two commits.

So there is no former-ID-to-canonical-ID mapping to add: the `android_*` IDs
are the first and only IDs these cases have ever had. This note is the record,
so the question is not reopened from the same report a third time. The registry
IDs are not to be renamed.

## Why this file exists

Each guard used to carry its own inventory of injections inside `--self-test`,
described only by an English sentence in an `echo`. That is a second source of
truth, and it drifted immediately: the iOS guard was reported as having 6 cases
when it has 17, and an instruction was written against the wrong number.
Nothing in the repository could have caught that, because the only place the
count existed was a string.

The conversion to named production rules moves each case from "a sentence next
to a `sed`" to a triple:

| old case description | stable case ID | production rule and diagnostic |

The **case ID** never changes and never gets renumbered — it appears in
reports, and a renumbered ID silently re-points every report that cites it. The
**diagnostic ID** is what a case matches on; prose is expected to be rewritten
and matching it would let improving a message stop a case proving anything.

A case is only satisfied by **guard exit 1 with its own diagnostic**. Exit 2 is
infrastructure and invalidates the case: a guard that rejects everything —
because Node is missing, because a mode is misspelled, because the copied tree
is incomplete — rejects every injection too, and reads exactly like a working
one to a test that only asks whether the exit code was nonzero.

---

## check-ios-target.sh — 17 reject + 1 layering

Converted at Commit B. All 17 preserved. **Migrated to the shared registry**;
all 17 IDs below are unchanged, and the layering case is now a registry case in
its own right rather than a hand-written block at the end of the self-test.

| # | old case description | case ID | production rule | diagnostic |
|---|----------------------|---------|-----------------|------------|
| 1 | deployment target reverted in the app | `ios_deploy_target_app` | `rule_deployment_target` | `STRIDE_GUARD[ios.deployment_target]` |
| 2 | an example app left at 13.0 | `ios_deploy_target_example` | `rule_deployment_target` | `STRIDE_GUARD[ios.deployment_target]` |
| 3 | iPad added to the device family | `ios_device_family_ipad` | `rule_device_family` | `STRIDE_GUARD[ios.device_family]` |
| 4 | entitlements file unreferenced by the build | `ios_entitlements_unwired` | `rule_entitlements_wired` | `STRIDE_GUARD[ios.entitlements_wired]` |
| 5 | landscape orientation added | `ios_orientation_landscape` | `rule_orientation_portrait` | `STRIDE_GUARD[ios.orientation_portrait]` |
| 6 | NSHealthShareUsageDescription emptied | `ios_share_string_empty` | `rule_health_share_string` | `STRIDE_GUARD[ios.health_share_string]` |
| 7 | NSHealthShareUsageDescription whitespace-only | `ios_share_string_blank` | `rule_health_share_string` | `STRIDE_GUARD[ios.health_share_string]` |
| 8 | the key renamed to a near-miss (X suffix) | `ios_share_string_renamed` | `rule_health_share_string` | `STRIDE_GUARD[ios.health_share_string]` |
| 9 | NSHealthUpdateUsageDescription added (app does not write) | `ios_health_write_string` | `rule_no_health_write_string` | `STRIDE_GUARD[ios.no_health_write_string]` |
| 10 | UIBackgroundModes declared | `ios_background_modes` | `rule_no_background_modes` | `STRIDE_GUARD[ios.no_background_modes]` |
| 11 | healthkit.background-delivery entitlement added | `ios_background_delivery` | `rule_no_background_delivery` | `STRIDE_GUARD[ios.no_background_delivery]` |
| 12 | the entitlement given as the STRING "true" | `ios_healthkit_string_true` | `rule_healthkit_entitlement_true` | `STRIDE_GUARD[ios.healthkit_entitlement_true]` |
| 13 | a duplicated security-sensitive entitlement key | `ios_entitlement_dupe_key` | `rule_no_duplicate_entitlement_keys` | `STRIDE_GUARD[ios.no_duplicate_entitlement_keys]` |
| 14 | a MALFORMED Info.plist | `ios_plist_malformed` | `rule_plist_parses` | `STRIDE_GUARD[ios.plist_parses]` |
| 15 | a MALFORMED Runner.entitlements | `ios_entitlements_malformed` | `rule_entitlements_parses` | `STRIDE_GUARD[ios.entitlements_parses]` |
| 16 | an entitlements file with a NON-Apple doctype | `ios_entitlements_foreign_doctype` | `rule_entitlements_parses` | `STRIDE_GUARD[ios.entitlements_parses]` |
| 17 | an entitlements file with an internal subset | `ios_entitlements_internal_subset` | `rule_entitlements_parses` | `STRIDE_GUARD[ios.entitlements_parses]` |

Cases 14–17 are the reason the xmlq exit-2 layers exist. Each is a **policy**
rejection — the guard read the file and the file is wrong — and each is
permitted to be one **only** because xmlq names its cause as
`STRIDE_XMLQ[invalid_document]`. A missing file, a misspelled mode, a missing
Node, or a parser crash reports `invalid_invocation` or `internal_failure` and
becomes `STRIDE_INFRA[ios.xmlq.<reason>]` with guard exit 2, which no case can
be satisfied by. The registry enforces that structurally: a `reject` case fails
on any exit other than 1, and fails again if a `STRIDE_INFRA[` line appears in
the output at all.

### The layering case, in the other direction

| case ID | production rule | what it proves |
|---------|-----------------|----------------|
| `ios_entitlements_absent` | `rule_entitlements_present` | a DELETED `Runner.entitlements` is `STRIDE_GUARD[ios.entitlements_present]` and **never** `ios.entitlements_parses` |

Without it, "malformed files are rejected" would be indistinguishable from
"anything xmlq cannot answer is rejected", and the layering would be a comment
rather than a behaviour. In the registry it carries a `forbid` field naming
`ios.entitlements_parses`, so the second half of the claim is asserted rather
than described.

**Why it is classed `reject` and not `infra`.** The registry's `infra` class
means exit 2 with a `STRIDE_INFRA` diagnostic. An absent entitlements file is
not that: `rule_entitlements_parses` returns 0 on a file that does not exist and
leaves the statement to `rule_entitlements_present`, which names the violation
and exits 1. That is correct — absence is a policy violation the guard states by
name, and it never reaches xmlq at all. Classing the case `infra` would mean
weakening a production rule to flatter the registry, so the case is `reject`
with a forbidden diagnostic, which is exactly what it asserts. The consequence
is that the iOS subtotal is **18 reject, 0 infra**, and the migrated set's
subtotal is **29 reject, 1 accept, 1 infra** rather than 28/1/2.

Named production rules with no case yet — enforced by the complete guard,
awaiting registry cases:

| rule | diagnostic | what it holds |
|------|-----------|---------------|
| `rule_preflight` | `STRIDE_INFRA[ios.*]` | node, xmlq and the project root exist |
| `rule_swift_package_platform` | `STRIDE_GUARD[ios.swift_package_platform]` | each `Package.swift` declares `.iOS("17.0")` |
| `rule_podspec_platform` | `STRIDE_GUARD[ios.podspec_platform]` | each podspec declares `s.platform = :ios, '17.0'` |
| `rule_podspec_license_file` | `STRIDE_GUARD[ios.podspec_license_file]` | a podspec `:file` license reference resolves |
| `rule_plist_present` | `STRIDE_GUARD[ios.plist_present]` | `Info.plist` exists |
| `rule_entitlements_present` | `STRIDE_GUARD[ios.entitlements_present]` | `Runner.entitlements` exists |
| `rule_no_ipad_orientation` | `STRIDE_GUARD[ios.no_ipad_orientation]` | no `UISupportedInterfaceOrientations~ipad` |

---

## check-single-writer.sh — 5 reject + 1 infrastructure

Converted at Commit B. All 5 preserved. **Migrated to the shared registry**;
all 5 IDs below are unchanged.

| # | old case description | case ID | production rule | diagnostic |
|---|----------------------|---------|-----------------|------------|
| 1 | a background isolate constructing SaveRepository | `sw_background_isolate_repo` | `rule_approved_construction_sites` | `STRIDE_GUARD[single-writer.approved_construction_sites]` |
| 2 | a second repository construction outside the approved sites | `sw_unapproved_construction` | `rule_approved_construction_sites` | `STRIDE_GUARD[single-writer.approved_construction_sites]` |
| 3 | a background entry point that touches no persistence type | `sw_dart_background_entry` | `rule_no_dart_background_entry` | `STRIDE_GUARD[single-writer.no_dart_background_entry]` |
| 4 | Swift arming HealthKit background delivery | `sw_native_background_swift` | `rule_no_native_background_entry` | `STRIDE_GUARD[single-writer.no_native_background_entry]` |
| 5 | Kotlin scheduling a WorkManager background worker | `sw_native_background_kotlin` | `rule_no_native_background_entry` | `STRIDE_GUARD[single-writer.no_native_background_entry]` |

Case 1 trips two rules at once — it is both a construction outside the approved
sites and a background entry point. It is owned by
`rule_approved_construction_sites` and matches that diagnostic; case 3 exists
precisely so `rule_no_dart_background_entry` is proven independently, on a probe
that touches no persistence type at all.

One **infrastructure** case, in the other direction. Cases 4 and 5 prove the
native rule fires when a background entry point is present; they cannot prove
the scan happened at all, because a copy missing the Swift and Kotlin
directories produces no findings and looks identical to a clean tree.

| case ID | production rule | what it proves |
|---------|-----------------|----------------|
| `sw_empty_native_scan` | `rule_native_scan_coverage` | both native directories removed ⇒ exit **2** with `STRIDE_INFRA[single-writer.no_native_sources]`, never a clean pass and never a policy rejection |

Named production rules with no case yet:

| rule | diagnostic | what it holds |
|------|-----------|---------------|
| `rule_preflight` | `STRIDE_INFRA[single-writer.*]` | the project root exists and holds production Dart |
| `rule_no_persistence_owner` | `STRIDE_GUARD[single-writer.no_persistence_owner]` | the removed owner prototype has not returned |

`rule_native_scan_coverage` was on this list at the conversion. It is no longer:
`sw_empty_native_scan` closes it.

---

## check-origin-privacy.sh — 12 cases

Converted at Commit B with 10 cases, all preserved; none removed, merged or
weakened. Two added by the coverage follow-up (11 and 12), each closing a rule
that was enforced but uncased.

| # | old case description | case ID | production rule | diagnostic |
|---|----------------------|---------|-----------------|------------|
| 1 | stride_core reading the raw source identifier | `op_core_reads_raw` | `rule_raw_identifier_sites` | `STRIDE_GUARD[origin-privacy.raw_identifier_sites]` |
| 2 | an app file reading the raw source identifier | `op_app_reads_raw` | `rule_raw_identifier_sites` | `STRIDE_GUARD[origin-privacy.raw_identifier_sites]` |
| 3 | a second health file reading the raw source list | `op_health_reads_raw_list` | `rule_raw_identifier_sites` | `STRIDE_GUARD[origin-privacy.raw_identifier_sites]` |
| 4 | a device display name on the health data path | `op_dart_display_name` | `rule_no_dart_display_name` | `STRIDE_GUARD[origin-privacy.no_dart_display_name]` |
| 5 | Swift reading HKSource.name | `op_swift_display_name` | `rule_no_native_display_name` | `STRIDE_GUARD[origin-privacy.no_native_display_name]` |
| 6 | Swift logging a raw source identifier | `op_swift_logs_raw` | `rule_no_native_raw_sink` | `STRIDE_GUARD[origin-privacy.no_native_raw_sink]` |
| 7 | the origin field changed from opaque bytes to a String | `op_pigeon_origin_string` | `rule_pigeon_origin_opaque` | `STRIDE_GUARD[origin-privacy.pigeon_origin_opaque]` |
| 8 | Swift minting a second device identity | `op_swift_mints_identity` | `rule_no_native_identity_minting` | `STRIDE_GUARD[origin-privacy.no_native_identity_minting]` |
| 9 | a platform boundary value printed without naming the field | `op_platform_value_sink` | `rule_no_platform_value_sink` | `STRIDE_GUARD[origin-privacy.no_platform_value_sink]` |
| 10 | Kotlin caching the cursor in a durable native store | `op_kotlin_durable_store` | `rule_no_native_durable_store` | `STRIDE_GUARD[origin-privacy.no_native_durable_store]` |
| 11 | *(new)* a Dart health surface logging the raw native identifier | `op_dart_raw_sink` | `rule_no_dart_raw_sink` | `STRIDE_GUARD[origin-privacy.no_dart_raw_sink]` |
| 12 | *(new)* stride_core taking a dependency on the platform boundary | `op_core_boundary_isolation` | `rule_core_boundary_isolation` | `STRIDE_GUARD[origin-privacy.core_boundary_isolation]` |

Case 1 trips two rules at once: the probe both names the raw identifier and
does so from inside `stride_core`. It is owned by `rule_raw_identifier_sites`,
which is what the original inventory called check "A" — the same convention
used for `sw_background_isolate_repo`. That over-determination is why
`rule_core_boundary_isolation` stayed uncased through the conversion, and why
case 1 is **not** evidence for it: a rejection that another rule produces first
says nothing about the rule it is filed under.

### Cases 11 and 12 — the isolated form

Both use `expect_reject_isolated`, which asserts twice:

* the **complete guard** exits 1 with the case's diagnostic — a policy
  rejection end to end, as a developer would see it
* the **named rule, invoked alone** against the same mutated root, exits 1 with
  its own diagnostic and nothing else

The second assertion is the one that makes these cases evidence. With a single
rule running, a mutation that only some *other* rule can see returns 0, so the
case fails rather than passing on someone else's detection. Over-determination
in the complete guard stops mattering, because nothing else was given the
chance to fire. This is the first thing in the repository to actually depend on
`check-source-safety.sh`: invoking one rule requires that sourcing the guard be
inert.

Case 12 additionally passes `sole` — the complete guard must name
`core_boundary_isolation` and no other rule. Its probe deliberately names no
raw identifier: it imports `package:stride_health` and declares `HealthHostApi`,
which is the core acquiring an opinion about where its data came from. Verified:
that mutation trips exactly one rule.

Case 11 is deliberately **not** `sole`, and the reason is a property of the
production rules rather than a weakness in the probe.
`rule_no_dart_raw_sink` greps the same raw-symbol pattern as
`rule_raw_identifier_sites` and then narrows it with `DART_SINK`, so its hit set
is a strict **subset**. With `APPROVED` empty, every line the sink rule can fire
on trips the site rule too, and no probe can separate them at the guard level.
Narrowing the site rule to make the case look isolated would weaken a
production rule to flatter a test, so the separation is proved where it is
real — at the rule level. `rule_no_dart_raw_sink` invoked alone rejects the
probe, which is precisely the claim the case is named for.

Two **layering** cases, in the other direction. In a privacy guard the
dangerous failure is not a false rejection — it is a clean-looking run that read
nothing:

| case ID | what it proves |
|---------|----------------|
| `op_empty_native_scan` | the Swift and Kotlin directories removed ⇒ exit 2 with `STRIDE_INFRA[origin-privacy.no_native_sources]`, never a clean privacy result. Without it, cases 5, 6, 8 and 10 could be satisfied by a copy that simply lacks those directories. |
| `op_missing_pigeon_input` | the platform contract deleted ⇒ exit 2 with `STRIDE_INFRA[origin-privacy.pigeon_input_missing]`, never `pigeon_origin_opaque`. Without it, case 7 could be satisfied by deleting the file instead of changing the type. |

Named production rules with no case yet — enforced by the complete guard,
awaiting registry cases:

| rule | diagnostic | what it holds |
|------|-----------|---------------|
| `rule_preflight` | `STRIDE_INFRA[origin-privacy.root_missing]` | the project root exists |
| `rule_dart_scan_coverage` | `STRIDE_INFRA[origin-privacy.no_dart_sources]` | the Dart scan read something |
| `rule_native_scan_coverage` | `STRIDE_INFRA[origin-privacy.no_native_sources]` | the native scan read something (layering case above) |
| `rule_pigeon_input_present` | `STRIDE_INFRA[origin-privacy.pigeon_input_missing]` | the platform contract is readable (layering case above) |

`rule_no_dart_raw_sink` and `rule_core_boundary_isolation` were on this list at
the conversion. They are no longer: cases 11 and 12 close them. Every remaining
entry is infrastructure, and the two that can be falsified are the layering
cases above.

**Origin-privacy totals: 12 rejection cases, 2 layering cases, 0 accept cases**
— derived by the runner from the registry, not asserted against a number
written here.

### Registry migration

All fourteen cases now live in `Scripts/lib/cases.sh`. The guard's
`--self-test` is one call to `reg_selftest` and holds no mutation code; the
runner refuses to run it if any comes back. Both layering cases became
`expect=infra`, which is the class that refuses to be satisfied by a policy
rejection and vice versa, and `op_missing_pigeon_input` keeps its
`forbid` on `pigeon_origin_opaque` as a registry-enforced field.

Attribution: `op_dart_raw_sink` and `op_core_boundary_isolation` carry
`attribution: named_rule` — the two structurally over-determined cases. The
runner invokes the named rule alone against the same mutated root and requires
exit 1 with that rule's own diagnostic, which is what makes an unrelated rule
unable to satisfy the case. Verified in both directions: with the probe in
place, the owning rule alone exits 1 with its diagnostic and an unrelated rule
of the same guard exits 0. Every other origin-privacy case is
`complete_guard`.

The `sole` obligation the embedded self-test asserted by hand for
`op_core_boundary_isolation` is preserved as a `forbid` over every other
diagnostic this guard can emit. Any rule added to origin-privacy must be added
to `OP_NOT_CORE_BOUNDARY` in `cases.sh` too, or the case quietly stops being
the sole-attribution proof it is filed as.

**A registry defect this migration exposed.** `reg_invoke_named_rule` sourced
the guard from a subshell of the process already running that guard. A guard's
source-safe entry is `[[ "${BASH_SOURCE[0]}" == "$0" ]]`, and in that subshell
both sides are the same string — so sourcing was not inert: it ran
`guard_main` on whatever positional parameters were in scope, and both
`named_rule` cases failed with
`STRIDE_INFRA[origin-privacy.usage] unknown argument`. The path had never been
exercised, because the three guards migrated before origin-privacy are all
`complete_guard`. Fixed by invoking through `bash -c '...' _`, whose `$0` of
`_` can never equal the sourced path — the same construction the embedded
self-test used and the reason it worked. No production rule changed.

### Where each origin-privacy property is actually held

This guard holds the source-text properties. Two of the properties in the
same family are held elsewhere, and are recorded here so a later reader does
not assume this script covers them:

| property | held by |
|----------|---------|
| raw HealthKit / Health Connect identifiers cannot cross Pigeon | `rule_raw_identifier_sites`, `rule_pigeon_origin_opaque` |
| source or device display names cannot cross the boundary | `rule_no_dart_display_name`, `rule_no_native_display_name` |
| raw identifiers cannot enter saves or logs | `rule_no_dart_display_name` (scoped to `stride_core`/`stride_storage`/`stride_health` lib), `rule_no_dart_raw_sink`, `rule_no_native_raw_sink` |
| generated bindings cannot introduce a raw-identifier field | `rule_raw_identifier_sites` — `production_dart` deliberately includes `messages.g.dart` |
| generated `toString` cannot leak a boundary value | `rule_no_platform_value_sink` (the compensating control for the `SINK_EXEMPT` exemption) |
| all required Dart, Swift, Kotlin and Pigeon surfaces are inspected | `rule_dart_scan_coverage`, `rule_native_scan_coverage`, `rule_pigeon_input_present` — all three **infrastructure**, so an empty scan is never a privacy pass |
| `StepOriginKey` shape: sixteen lowercase hex or `unknown`, so `"My Watch"` and `"phone"` are not representable | the Dart type plus `packages/stride_health/test/origin_key_vectors.dart` and `origin_privacy_test.dart` — **not** this guard |
| the canonical durable-state contract | `check-step-model.sh` (`canonicalDurableStepLedger`) — **not** this guard |

---

## check-step-model.sh — 13 reject + 4 infrastructure

Converted at Commit B. All 10 historical cases preserved; none removed, merged
or weakened. Three added by the uncased-rule audit.

### What the conversion changed about the evidence

Before this conversion every case asserted exactly one thing:

```sh
if bash "$0" --project-root "$ISO_ROOT" >/dev/null 2>&1; then FAIL; fi
```

Ten cases, each proving that *something* went wrong. Not which rule fired, not
that it was a policy rejection rather than an infrastructure failure, and not
that the case's own rule was involved at all. That is the exact shape of the
`check-android-target.sh` defect: three checks there called an xmlq mode that
has never existed, every call exited 2 into `|| true`, and the self-test read
green because the guard was already failing for an unrelated reason.

Each case now asserts three things:

| | assertion |
|---|-----------|
| (a) | the **complete guard** exits exactly **1** — a policy rejection — and emits this case's diagnostic. Exit 2 is infrastructure and **fails** the case |
| (b) | the complete guard names **no other rule**, unless the case explicitly declares the second one. Over-determination is reviewed and written down, never silently tolerated |
| (c) | the **named rule, invoked alone** against the same mutated root, exits 1 with its own diagnostic |

(c) is the isolation proof. With one rule running, a mutation only some *other*
rule can see returns 0, so the case fails rather than passing on someone else's
detection. It is possible only because the guard is source-safe.

### The ten historical cases, preserved

| # | old case description | case ID | production rule | diagnostic |
|---|----------------------|---------|-----------------|------------|
| 1 | StepFetchResult reintroduced in the app | `sm_step_fetch_result` | `rule_no_retired_dart_model` | `STRIDE_GUARD[step-model.no_retired_dart_model]` |
| 2 | fetchNewSteps reintroduced in the health package | `sm_fetch_new_steps` | `rule_no_retired_dart_model` | `STRIDE_GUARD[step-model.no_retired_dart_model]` |
| 3 | a flat unscoped newSteps field on the platform contract | `sm_flat_contract_field` | `rule_no_flat_contract_field` | `STRIDE_GUARD[step-model.no_flat_contract_field]` |
| 4 | a flat newSteps field in native source | `sm_flat_native_field` | `rule_no_retired_native_model` | `STRIDE_GUARD[step-model.no_retired_native_model]` |
| 5 | a second step-ingestion entry point into the engine | `sm_second_ingest_entry` | `rule_single_ingest_entry_point` | `STRIDE_GUARD[step-model.single_ingest_entry_point]` |
| 6 | CompleteThrough constructed outside the anchored site | `sm_settling_complete_through` | `rule_settling_construction_sites` | `STRIDE_GUARD[step-model.settling_construction_sites]` |
| 7 | RecoveryCompleteThrough constructed outside the anchored site | `sm_settling_recovery_complete_through` | `rule_settling_construction_sites` | `STRIDE_GUARD[step-model.settling_construction_sites]` |
| 8 | a whole-ledger equality comparison on StepLedger.signature | `sm_signature_test_equality` | `rule_signature_allowed_files` | `STRIDE_GUARD[step-model.signature_allowed_files]` |
| 9 | a production integrity comparison on StepLedger.signature | `sm_signature_production_integrity` | `rule_signature_allowed_files` | `STRIDE_GUARD[step-model.signature_allowed_files]` |
| 10 | StepLedger.signature captured in an allow-listed file | `sm_signature_capture_variable` | `rule_no_signature_capture` | `STRIDE_GUARD[step-model.no_signature_capture]` |

Every one of the ten was verified to be attributable to its own rule. None
turned out to be over-determined, so none needed a declared second rule.

### The three added by the uncased-rule audit

| # | case ID | production rule | diagnostic | why it was needed |
|---|---------|-----------------|------------|-------------------|
| 11 | `sm_signature_capture_collection` | `rule_no_signature_capture` | `STRIDE_GUARD[step-model.no_signature_capture]` | `SIGNATURE_CAPTURE` is an alternation of **two** shapes and case 10 exercised only the `=` branch. An edit breaking the `.add(` branch would have left case 10 green and the collection form unguarded. The probe builds an empty list and appends, so the `=` branch cannot fire and the case proves the branch it is named for. |
| 12 | `sm_observation_class_renamed` | `rule_observation_class_present` | `STRIDE_GUARD[step-model.observation_class_present]` | `rule_no_flat_contract_field` is an ABSENCE check, so a contract carrying no step shape at all satisfies it perfectly. This rule is what makes "no flat field" mean something. A **prefix** rename, not a suffix: the check is a fixed-string search for `class PlatformStepObservation`, which `class PlatformStepObservationV2` would still satisfy. |
| 13 | `sm_ingest_command_renamed` | `rule_ingest_command_present` | `STRIDE_GUARD[step-model.ingest_command_present]` | Same shape of gap. `rule_single_ingest_entry_point` proves no *second* way into the engine exists, which is vacuously true of a codebase with no way in at all. |

### The signature rule's three named obligations

The instruction for this conversion required the signature cases to prove three
specific bypasses cannot work. Each maps to a case:

| obligation | held by |
|------------|---------|
| receiver-name tricks | `sm_signature_test_equality` — its probe calls the receivers `a` and `b` **deliberately**. The first version of the rule matched `.signature` only on receivers whose names looked ledger-ish, and this exact probe walked straight through it. The rule now matches every `.signature`; this case is what keeps a future "let's reduce false positives by naming the receivers we care about" from landing quietly. |
| capture inside allow-listed files | `sm_signature_capture_variable` and `sm_signature_capture_collection` — both inject into `save_privacy_test.dart`, which *is* allow-listed, so `rule_signature_allowed_files` skips it and only `rule_no_signature_capture` can fire. |
| equivalent syntactic forms | the same pair — one per branch of the `SIGNATURE_CAPTURE` alternation. |

### Four infrastructure cases — which no rejection case may be satisfied by

Every content rule in this guard is an **absence** check, and a tree the guard
cannot read produces absence too. Two of these are layering cases in the same
sense as origin-privacy's; two cover invalid invocation.

| case ID | proves | without it |
|---------|--------|-----------|
| `sm_empty_native_scan` | native directories removed ⇒ exit 2 with `STRIDE_INFRA[step-model.no_native_sources]` | `sm_flat_native_field` could be satisfied by a copy that simply lacks the native directories |
| `sm_missing_pigeon_input` | contract deleted ⇒ exit 2 with `STRIDE_INFRA[step-model.pigeon_input_missing]`, and **never** `no_flat_contract_field` or `observation_class_present` | cases 3 and 12 could both be satisfied by deleting the contract instead of changing it |
| `sm_bad_project_root` | a nonexistent root ⇒ exit 2 with `STRIDE_INFRA[step-model.root_missing]` | a typo in CI would read as a repository defect |
| `sm_unknown_argument` | a misspelled flag ⇒ exit 2 with `STRIDE_INFRA[step-model.usage]` | the `check-android-target.sh` defect exactly — a call the guard does not understand, counted as a finding |

### Production-rule inventory and uncased-rule audit

Fourteen named rules. Every **policy** rule has independent coverage; the four
uncovered rules are all infrastructure, and two of those are held by the
layering cases above.

| rule | kind | diagnostic | coverage |
|------|------|-----------|----------|
| `rule_preflight` | infra | `STRIDE_INFRA[step-model.root_missing]` | `sm_bad_project_root` |
| `rule_dart_scan_coverage` | infra | `STRIDE_INFRA[step-model.no_dart_sources]` | **uncased** — see below |
| `rule_native_scan_coverage` | infra | `STRIDE_INFRA[step-model.no_native_sources]` | `sm_empty_native_scan` |
| `rule_signature_scan_coverage` | infra | `STRIDE_INFRA[step-model.no_signature_sources]` | **uncased** — see below |
| `rule_pigeon_input_present` | infra | `STRIDE_INFRA[step-model.pigeon_input_missing]` | `sm_missing_pigeon_input` |
| `rule_no_retired_dart_model` | policy | `STRIDE_GUARD[step-model.no_retired_dart_model]` | cases 1, 2 |
| `rule_no_retired_native_model` | policy | `STRIDE_GUARD[step-model.no_retired_native_model]` | case 4 |
| `rule_no_flat_contract_field` | policy | `STRIDE_GUARD[step-model.no_flat_contract_field]` | case 3 |
| `rule_observation_class_present` | policy | `STRIDE_GUARD[step-model.observation_class_present]` | case 12 *(new)* |
| `rule_ingest_command_present` | policy | `STRIDE_GUARD[step-model.ingest_command_present]` | case 13 *(new)* |
| `rule_single_ingest_entry_point` | policy | `STRIDE_GUARD[step-model.single_ingest_entry_point]` | case 5 |
| `rule_settling_construction_sites` | policy | `STRIDE_GUARD[step-model.settling_construction_sites]` | cases 6, 7 |
| `rule_signature_allowed_files` | policy | `STRIDE_GUARD[step-model.signature_allowed_files]` | cases 8, 9 |
| `rule_no_signature_capture` | policy | `STRIDE_GUARD[step-model.no_signature_capture]` | cases 10, 11 *(11 new)* |

**Two explicit, justified exceptions.** `rule_dart_scan_coverage` and
`rule_signature_scan_coverage` have no case, and the reason is not that they
were forgotten. Both fire only when the Dart scan reads **zero** files, and the
self-test's isolated root is built by copying `lib` and every package's `lib`
and `test`. Emptying it enough to trip either rule would also delete the files
every other case injects into, so the probe could not be restored and the
"clean before, clean after" bracket around each case would be meaningless. The
property they hold — an empty scan is never a clean scan — is the same property
`sm_empty_native_scan` proves, on the scan that can be emptied without
destroying the fixture. These are recorded as uncased deliberately, not
silently.

**Not a rule, and deliberately so:** no accept case exists for this guard. The
comment-stripping that would need one is exercised by the live tree on every
run — this script's own subject matter is discussed at length in the doc
comments of the files it scans, and every one of them would be a false positive
without `strip_comments`. The clean run *is* the accept case.

### Registry migration

All seventeen cases now live in `Scripts/lib/cases.sh`. The guard's
`--self-test` is one call to `reg_selftest` and holds no mutation code. The two
invalid-invocation cases became `form=invocation`, which declares no
changed-path set and which the registry rejects if it carries one; the other
fifteen are `form=mutation`. Both are filed under `rule_preflight`, the guard's
entry-level infrastructure rule — `usage` is emitted by argument parsing before
any rule runs, which is the point of the case rather than a gap in it.

**Attribution: all thirteen rejection cases are `named_rule`.** That is
deliberate and is the one place this guard differs from the other four. The
registry reserves `named_rule` for structurally over-determined cases, and none
of these thirteen is over-determined — but this guard's embedded self-test
asserted assertion (c), the rule invoked alone, for *every* case, not only for
the over-determined ones. Filing them as `complete_guard` would drop an
assertion that currently holds, which is precisely the silent weakening the
migration exists to prevent. `named_rule` does not replace the complete-guard
assertion; the runner makes both.

Assertion (b) — the complete guard names no other rule — is preserved as a
`forbid` per case, covering every step-model diagnostic except that case's own.
`SM_DIAGS` in `cases.sh` is the list those are built from, and a rule added to
this guard must be added there too or the cases quietly stop making the
sole-attribution claim they are filed under. The `forbid` on
`sm_missing_pigeon_input` keeps its narrower original form: never
`no_flat_contract_field` and never `observation_class_present`.

No production rule changed. The two deliberately uncased rules
(`rule_dart_scan_coverage`, `rule_signature_scan_coverage`) remain uncased for
the reason recorded above; the registry does not require a case per rule, and
inventing one that empties the fixture would destroy the clean-before /
clean-after bracket every other case depends on.

### Where the step-model properties are actually held

| property | held by |
|----------|---------|
| one live normalized SyncResponse ingestion model | `rule_no_retired_dart_model`, `rule_ingest_command_present`, `rule_single_ingest_entry_point` |
| no resurrection of StepProvider / StepFetchResult / fetchNewSteps | `rule_no_retired_dart_model` (no allow-list, and there must not be one) |
| no flat unscoped newSteps boundary | `rule_no_flat_contract_field` (Dart contract), `rule_no_retired_native_model` (Swift and Kotlin) |
| only ReconcileStepSync / SyncResponse reaching the engine | `rule_single_ingest_entry_point` |
| completeness and cursor authority remaining in their intended layers | `rule_settling_construction_sites` — `CompleteThrough` and `RecoveryCompleteThrough` are constructed at ONE site, which returns `PartialDelivery` unless the page declares itself final |
| no native or parallel ledger authority | `rule_no_retired_native_model`, plus `check-origin-privacy.sh`'s `rule_no_native_durable_store` for the cursor — **not** this guard |
| `StepLedger.signature` not used as equality, unchanged-ledger, replay-determinism, save-integrity, cursor or watermark evidence | `rule_signature_allowed_files` (named files only) + `rule_no_signature_capture` (never held, even where permitted) |
| `StepLedger.signature` allowed only for its implementation and explicit diagnostic/privacy-format tests | the six named files in `SIGNATURE_APPROVED` |
| the `StepOriginKey` shape, and raw identifiers never crossing Pigeon | `check-origin-privacy.sh` — **not** this guard |

---

## check-android-target.sh — 6 reject + 1 accept

Converted at the previous checkpoint. **Migrated to the shared registry**; all 7
IDs below are unchanged.

The acceptance case is the one this guard cannot do without: an override named
only inside a comment must be **accepted**, which is the false positive that
failed a correct tree twice and the whole reason the manifest is parsed rather
than grepped. In the registry an `accept` case asserts exit 0 *and* that no
`STRIDE_GUARD[` line was emitted at all, so it cannot be satisfied by the guard
passing for some unrelated reason while still complaining.

| old case description | case ID | production rule | diagnostic |
|----------------------|---------|-----------------|------------|
| plugin minSdk lowered to 24 | `android_min_sdk_24` | `rule_min_sdk_pinned` | `STRIDE_GUARD[android.min_sdk_pinned]` |
| example app minSdk lowered to 25 | `android_min_sdk_25` | `rule_min_sdk_pinned` | `STRIDE_GUARD[android.min_sdk_pinned]` |
| example app minSdk inherited from flutter.minSdkVersion | `android_min_sdk_inherited` | `rule_min_sdk_pinned` | `STRIDE_GUARD[android.min_sdk_pinned]` |
| tools:overrideLibrary reintroduced | `android_override_library` | `rule_no_override_library` | `STRIDE_GUARD[android.no_override_library]` |
| a manifest uses-sdk lowering the floor to 24 | `android_manifest_min_sdk` | `rule_manifest_min_sdk` | `STRIDE_GUARD[android.manifest_min_sdk]` |
| a background `<service>` declared | `android_background_service` | `rule_no_background_entry` | `STRIDE_GUARD[android.no_background_entry]` |
| the forbidden attribute named only in a comment (**accept**) | `android_comment_false_positive` | `rule_no_override_library` | — (must pass) |
