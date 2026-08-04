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
