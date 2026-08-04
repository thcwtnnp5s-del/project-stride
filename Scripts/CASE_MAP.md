# Guard case map

Every mutation case a guard's `--self-test` injects, recorded **before** its
embedded inventory is replaced by the shared registry.

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

## check-ios-target.sh — 17 cases

Converted at Commit B. All 17 preserved.

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
be satisfied by.

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

## check-single-writer.sh — 5 cases

Converted at Commit B. All 5 preserved.

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

Named production rules with no case yet:

| rule | diagnostic | what it holds |
|------|-----------|---------------|
| `rule_preflight` | `STRIDE_INFRA[single-writer.*]` | the project root exists and holds production Dart |
| `rule_native_scan_coverage` | `STRIDE_INFRA[single-writer.no_native_sources]` | the native scan saw files; an empty scan is not a clean scan |
| `rule_no_persistence_owner` | `STRIDE_GUARD[single-writer.no_persistence_owner]` | the removed owner prototype has not returned |

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

**Origin-privacy totals: 12 `expect_reject` cases, 2 layering cases, 0 accept
cases.** The self-test asserts those counts rather than narrating them.

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

## check-android-target.sh — 6 reject + 1 accept

Converted at the previous checkpoint; recorded here for completeness.

| old case description | case ID | production rule | diagnostic |
|----------------------|---------|-----------------|------------|
| plugin minSdk lowered to 24 | `android_min_sdk_24` | `rule_min_sdk_pinned` | `STRIDE_GUARD[android.min_sdk_pinned]` |
| example app minSdk lowered to 25 | `android_min_sdk_25` | `rule_min_sdk_pinned` | `STRIDE_GUARD[android.min_sdk_pinned]` |
| example app minSdk inherited from flutter.minSdkVersion | `android_min_sdk_inherited` | `rule_min_sdk_pinned` | `STRIDE_GUARD[android.min_sdk_pinned]` |
| tools:overrideLibrary reintroduced | `android_override_library` | `rule_no_override_library` | `STRIDE_GUARD[android.no_override_library]` |
| a manifest uses-sdk lowering the floor to 24 | `android_manifest_min_sdk` | `rule_manifest_min_sdk` | `STRIDE_GUARD[android.manifest_min_sdk]` |
| a background `<service>` declared | `android_background_service` | `rule_no_background_entry` | `STRIDE_GUARD[android.no_background_entry]` |
| the forbidden attribute named only in a comment (**accept**) | `android_comment_false_positive` | `rule_no_override_library` | — (must pass) |
