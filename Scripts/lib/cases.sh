# The case inventory — the SOLE record of what every guard's self-test injects.
#
# Two things live here and nowhere else:
#
#   * the mutation layer: one function per case, performing exactly one
#     operation against `$CASE_ROOT`
#   * the inventory itself: one `reg_case` per case
#
# A guard holds neither. `Scripts/lib/registry.sh` refuses to run a guard's
# self-test if the guard still carries mutation machinery of its own, because a
# second mutation source is the drift this file exists to remove.
#
# Traceability for every case ID below is `Scripts/CASE_MAP.md`, which records
# the historical case each one was extracted from.
#
# Loading this file must be free of side effects: the guards source it, and
# `check-source-safety.sh` asserts that sourcing a guard produces no output,
# installs no trap, creates no file and changes no directory. Defining functions
# and setting registry variables is all that happens here.
#
# Requires `registry.sh` to be sourced first.

# ---------------------------------------------------------------------------
# GUARD AND RULE INVENTORIES
#
# `reg_selftest` asserts each list matches the rule list the guard actually
# runs, so "unknown production rule ID" cannot be defeated by the two drifting
# apart.
# ---------------------------------------------------------------------------
reg_guard android "
rule_preflight
rule_min_sdk_pinned
rule_manifest_parses
rule_no_override_library
rule_manifest_min_sdk
rule_no_background_entry
"

reg_guard ios "
rule_preflight
rule_deployment_target
rule_swift_package_platform
rule_podspec_platform
rule_podspec_license_file
rule_device_family
rule_entitlements_wired
rule_plist_present
rule_plist_parses
rule_orientation_portrait
rule_no_ipad_orientation
rule_health_share_string
rule_no_health_write_string
rule_no_background_modes
rule_entitlements_present
rule_entitlements_parses
rule_healthkit_entitlement_true
rule_no_background_delivery
rule_no_duplicate_entitlement_keys
"

reg_guard single-writer "
rule_preflight
rule_approved_construction_sites
rule_no_dart_background_entry
rule_native_scan_coverage
rule_no_native_background_entry
rule_no_persistence_owner
"

reg_guard origin-privacy "
rule_preflight
rule_dart_scan_coverage
rule_native_scan_coverage
rule_pigeon_input_present
rule_raw_identifier_sites
rule_no_dart_display_name
rule_no_native_display_name
rule_no_dart_raw_sink
rule_no_native_raw_sink
rule_core_boundary_isolation
rule_no_native_durable_store
rule_no_platform_value_sink
rule_pigeon_origin_opaque
rule_no_native_identity_minting
"

reg_guard step-model "
rule_preflight
rule_dart_scan_coverage
rule_native_scan_coverage
rule_signature_scan_coverage
rule_pigeon_input_present
rule_no_retired_dart_model
rule_no_retired_native_model
rule_no_flat_contract_field
rule_observation_class_present
rule_ingest_command_present
rule_single_ingest_entry_point
rule_settling_construction_sites
rule_signature_allowed_files
rule_no_signature_capture
"

# ---------------------------------------------------------------------------
# GUARD LOCATORS
#
# Which script implements each guard, and which of that guard's OWN variables
# hold the paths its isolated root needs.
#
# A guard's `--self-test` never needed this: it passes `"$0"` and its own path
# list straight to `reg_selftest`. The causality runner does, because it starts
# from the registry and has no guard to ask — it must be able to build a root
# for a guard nothing invoked it from.
#
# The path VARIABLE NAMES are recorded, never the paths. `reg_guard_paths`
# sources the guard and expands them there, so the lists still live in exactly
# one place. Writing the paths here instead would drift the first time a guard
# began inspecting a new file: the guard would read a path the runner never
# copied, the isolated root would fail its clean baseline, and that reads as
# "the guard rejects a correct tree" rather than as a stale list.
# ---------------------------------------------------------------------------
reg_guard_impl android        check-android-target.sh GRADLE_FILES MANIFESTS
reg_guard_impl ios            check-ios-target.sh     GUARD_PATHS
reg_guard_impl single-writer  check-single-writer.sh  SINGLE_WRITER_SELFTEST_PATHS
reg_guard_impl origin-privacy check-origin-privacy.sh ORIGIN_PRIVACY_SELFTEST_PATHS
reg_guard_impl step-model     check-step-model.sh     STEP_MODEL_SELFTEST_PATHS

# ===========================================================================
# THE MUTATION LAYER
#
# Every function below performs ONE operation and nothing else. No function
# reverts anything: restoration is generic, driven by the declared changed-path
# set, and verified by fingerprinting the whole isolated root. A hand-written
# revert is another thing that can be subtly wrong, and a subtly wrong revert is
# indistinguishable from the next case passing on leftovers.
# ===========================================================================

# --- Android ---------------------------------------------------------------
A_PLUGIN_GRADLE="packages/stride_health/android/build.gradle.kts"
A_EXAMPLE_GRADLE="packages/stride_health/example/android/app/build.gradle.kts"
A_PLUGIN_MANIFEST="packages/stride_health/android/src/main/AndroidManifest.xml"

mut_android_min_sdk_24() {
  sed -i "s/minSdk = 26/minSdk = 24/" "$CASE_ROOT/$A_PLUGIN_GRADLE"
}

mut_android_min_sdk_25() {
  sed -i "s/minSdk = 26/minSdk = 25/" "$CASE_ROOT/$A_EXAMPLE_GRADLE"
}

mut_android_min_sdk_inherited() {
  sed -i "s/minSdk = 26/minSdk = flutter.minSdkVersion/" "$CASE_ROOT/$A_EXAMPLE_GRADLE"
}

mut_android_override_library() {
  sed -i \
    -e 's|<manifest |<manifest xmlns:tools="http://schemas.android.com/tools" |' \
    -e 's|</manifest>|  <uses-sdk tools:overrideLibrary="androidx.health.connect.client" />\n</manifest>|' \
    "$CASE_ROOT/$A_PLUGIN_MANIFEST"
}

mut_android_manifest_min_sdk() {
  sed -i 's|</manifest>|  <uses-sdk android:minSdkVersion="24" />\n</manifest>|' \
    "$CASE_ROOT/$A_PLUGIN_MANIFEST"
}

mut_android_background_service() {
  sed -i 's|</manifest>|  <service android:name=".SyncService" />\n</manifest>|' \
    "$CASE_ROOT/$A_PLUGIN_MANIFEST"
}

# The acceptance case. An override named ONLY inside a comment must not be
# rejected -- that is the false positive which failed a correct tree twice, and
# it is why the manifest is parsed rather than grepped.
mut_android_comment_false_positive() {
  sed -i 's|</manifest>|  <!-- never add tools:overrideLibrary here -->\n</manifest>|' \
    "$CASE_ROOT/$A_PLUGIN_MANIFEST"
}

# --- iOS -------------------------------------------------------------------
I_PLIST_REL="ios/Runner/Info.plist"
I_ENT_REL="ios/Runner/Runner.entitlements"
I_PROJ_REL="ios/Runner.xcodeproj/project.pbxproj"
I_EX_REL="packages/stride_health/example/ios/Runner.xcodeproj/project.pbxproj"

mut_ios_deploy_target_app() {
  sed -i "s/IPHONEOS_DEPLOYMENT_TARGET = 17.0;/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/" \
    "$CASE_ROOT/$I_PROJ_REL"
}

mut_ios_deploy_target_example() {
  sed -i "s/IPHONEOS_DEPLOYMENT_TARGET = 17.0;/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/" \
    "$CASE_ROOT/$I_EX_REL"
}

mut_ios_device_family_ipad() {
  sed -i 's/TARGETED_DEVICE_FAMILY = "1";/TARGETED_DEVICE_FAMILY = "1,2";/' \
    "$CASE_ROOT/$I_PROJ_REL"
}

mut_ios_entitlements_unwired() {
  sed -i 's|CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;||' "$CASE_ROOT/$I_PROJ_REL"
}

mut_ios_orientation_landscape() {
  sed -i 's|<string>UIInterfaceOrientationPortrait</string>|<string>UIInterfaceOrientationPortrait</string><string>UIInterfaceOrientationLandscapeLeft</string>|' \
    "$CASE_ROOT/$I_PLIST_REL"
}

# Type, not presence: an empty share string still terminates the app at the
# authorization call.
mut_ios_share_string_empty() {
  perl -0pi -e 's|(<key>NSHealthShareUsageDescription</key>\s*<string>)[^<]*(</string>)|$1$2|s' \
    "$CASE_ROOT/$I_PLIST_REL"
}

mut_ios_share_string_blank() {
  perl -0pi -e 's|(<key>NSHealthShareUsageDescription</key>\s*<string>)[^<]*(</string>)|$1   $2|s' \
    "$CASE_ROOT/$I_PLIST_REL"
}

mut_ios_share_string_renamed() {
  perl -0pi -e 's|<key>NSHealthShareUsageDescription</key>|<key>NSHealthShareUsageDescriptionX</key>|s' \
    "$CASE_ROOT/$I_PLIST_REL"
}

mut_ios_health_write_string() {
  perl -0pi -e 's|(<dict>)|$1\n  <key>NSHealthUpdateUsageDescription</key><string>writes</string>|s' \
    "$CASE_ROOT/$I_PLIST_REL"
}

mut_ios_background_modes() {
  perl -0pi -e 's|(<dict>)|$1\n  <key>UIBackgroundModes</key><array><string>fetch</string></array>|s' \
    "$CASE_ROOT/$I_PLIST_REL"
}

mut_ios_background_delivery() {
  perl -0pi -e 's|(<dict>)|$1\n  <key>com.apple.developer.healthkit.background-delivery</key><true/>|s' \
    "$CASE_ROOT/$I_ENT_REL"
}

mut_ios_healthkit_string_true() {
  perl -0pi -e 's|<key>com.apple.developer.healthkit</key>\s*<true/>|<key>com.apple.developer.healthkit</key><string>true</string>|s' \
    "$CASE_ROOT/$I_ENT_REL"
}

mut_ios_entitlement_dupe_key() {
  perl -0pi -e 's|(<dict>)|$1\n  <key>com.apple.developer.healthkit</key><true/>|s' \
    "$CASE_ROOT/$I_ENT_REL"
}

# The four malformed-document cases. Each is a POLICY rejection at exit 1 by the
# relevant `_parses` rule, and each is permitted to be one ONLY because xmlq
# names its cause as `invalid_document`. A missing file, a misspelled mode, a
# missing Node or a parser crash is `STRIDE_INFRA[ios.xmlq.<reason>]` at exit 2,
# which the registry's `reject` class refuses outright.
mut_ios_plist_malformed() {
  printf '<?xml version="1.0"?>\n<plist version="1.0">\n<dict>\n  <key>oops\n</dict>\n</plist>\n' \
    > "$CASE_ROOT/$I_PLIST_REL"
}

mut_ios_entitlements_malformed() {
  printf '<?xml version="1.0"?>\n<plist version="1.0"><dict><key>a</key>\n' \
    > "$CASE_ROOT/$I_ENT_REL"
}

mut_ios_entitlements_foreign_doctype() {
  printf '<?xml version="1.0"?>\n<!DOCTYPE plist PUBLIC "-//Evil//DTD//EN" "http://evil.invalid/x.dtd">\n<plist version="1.0"><dict><key>com.apple.developer.healthkit</key><true/></dict></plist>\n' \
    > "$CASE_ROOT/$I_ENT_REL"
}

mut_ios_entitlements_internal_subset() {
  printf '<?xml version="1.0"?>\n<!DOCTYPE plist [ <!ENTITY x "y"> ]>\n<plist version="1.0"><dict><key>com.apple.developer.healthkit</key><true/></dict></plist>\n' \
    > "$CASE_ROOT/$I_ENT_REL"
}

# The layering case, in the other direction. A DELETED entitlements file is the
# cheapest way to reach the same code path with something that is NOT a document
# problem. Without it, "malformed files are rejected" would be
# indistinguishable from "anything xmlq cannot answer is rejected".
mut_ios_entitlements_absent() {
  rm -f "$CASE_ROOT/$I_ENT_REL"
}

# --- single-writer ---------------------------------------------------------
SW_DART_PROBE="lib/runtime/__single_writer_probe.dart"
SW_SWIFT_PROBE="packages/stride_health/ios/stride_health/Sources/stride_health/__BackgroundProbe.swift"
SW_KOTLIN_PROBE="packages/stride_health/android/src/main/kotlin/com/projectstride/stride_health/__BackgroundProbe.kt"
SW_IOS_SOURCES="packages/stride_health/ios/stride_health/Sources"
SW_ANDROID_MAIN="packages/stride_health/android/src/main"

# A background isolate that constructs a repository -- the exact shape the rule
# names, and the shape a Health Connect worker would take. It trips two rules at
# once; it is owned by the construction rule, and sw_dart_background_entry
# exists so the background rule is proven independently.
mut_sw_background_isolate_repo() {
  cat > "$CASE_ROOT/$SW_DART_PROBE" <<'PROBE'
import 'dart:isolate';
import 'package:stride_core/stride_core.dart';
import 'package:stride_storage/stride_storage.dart';

@pragma('vm:entry-point')
Future<void> backgroundSync(List<Object> args) async {
  final StorageLayout layout = StorageLayout(args[0] as dynamic);
  final SaveRepository repo = SaveRepository(
    snapshots: FileSnapshotStore(layout),
    journal: FileLedgerJournal(layout),
    lock: FileTransactionLock(layout.transactionLock),
  );
  await repo.compact();
}

void start() => Isolate.spawn(backgroundSync, <Object>[]);
PROBE
}

# A plain unauthorized construction with no background marker at all, so the
# construction rule is proven independently of the background rule.
mut_sw_unapproved_construction() {
  cat > "$CASE_ROOT/$SW_DART_PROBE" <<'PROBE'
import 'package:stride_core/stride_core.dart';
import 'package:stride_storage/stride_storage.dart';

SaveRepository buildAnother(StorageLayout layout) => SaveRepository(
  snapshots: FileSnapshotStore(layout),
  journal: FileLedgerJournal(layout),
  lock: FileTransactionLock(layout.transactionLock),
);
PROBE
}

# A background entry point that touches no persistence type, proving the
# background rule does not depend on the construction rule having fired.
mut_sw_dart_background_entry() {
  cat > "$CASE_ROOT/$SW_DART_PROBE" <<'PROBE'
import 'dart:isolate';

@pragma('vm:entry-point')
void harmlessWorker() {}

void start() => Isolate.spawn((_) {}, null);
PROBE
}

# The same rule in Swift. This is the S-01B shape exactly: an observer query
# asking iOS to wake the app, which the Dart markers cannot see.
mut_sw_native_background_swift() {
  cat > "$CASE_ROOT/$SW_SWIFT_PROBE" <<'PROBE'
import HealthKit

final class BackgroundProbe {
  func arm(store: HKHealthStore, type: HKSampleType) {
    store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
  }
}
PROBE
}

# And in Kotlin -- a WorkManager worker, the Android half of S-01B.
mut_sw_native_background_kotlin() {
  cat > "$CASE_ROOT/$SW_KOTLIN_PROBE" <<'PROBE'
package com.projectstride.stride_health

import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager

internal class BackgroundProbe {
    fun schedule(wm: WorkManager, req: OneTimeWorkRequest) { wm.enqueue(req) }
}
PROBE
}

# The layering case. The Swift and Kotlin cases prove the native rule fires when
# a background entry point is present; they cannot prove the scan happened at
# all, because a copy missing those directories produces no findings and looks
# identical to a clean tree. This is what separates them, and it is why an empty
# native scan is INFRASTRUCTURE rather than a clean pass.
mut_sw_empty_native_scan() {
  rm -rf "$CASE_ROOT/$SW_IOS_SOURCES" "$CASE_ROOT/$SW_ANDROID_MAIN"
}

# --- origin-privacy --------------------------------------------------------
OP_CORE_PROBE="packages/stride_core/lib/src/__origin_probe.dart"
OP_APP_PROBE="lib/__origin_probe.dart"
OP_HEALTH_PROBE="packages/stride_health/lib/src/__origin_probe.dart"
OP_SWIFT_PROBE="packages/stride_health/ios/stride_health/Sources/stride_health/__OriginProbe.swift"
OP_KOTLIN_PROBE="packages/stride_health/android/src/main/kotlin/com/projectstride/stride_health/__OriginProbe.kt"
OP_PIGEON="packages/stride_health/pigeons/health_api.dart"
OP_IOS_SOURCES="packages/stride_health/ios/stride_health/Sources"
OP_ANDROID_MAIN="packages/stride_health/android/src/main"

# The core reads the raw field -- the exact thing the ruling forbids. It trips
# the core-isolation rule too, and is owned by the rule that names the raw
# identifier. That over-determination is why op_core_boundary_isolation exists
# with a probe naming no raw identifier at all.
mut_op_core_reads_raw() {
  cat > "$CASE_ROOT/$OP_CORE_PROBE" <<'PROBE'
class OriginProbe {
  String pick(dynamic observation) => observation.sourceIdentifier as String;
}
PROBE
}

# An ordinary app file reads it, proven separately from the core case, so the
# allow-list is shown to bind everywhere and not only in one package.
mut_op_app_reads_raw() {
  cat > "$CASE_ROOT/$OP_APP_PROBE" <<'PROBE'
class OriginProbe {
  String pick(dynamic page) => page.observations.first.sourceIdentifier as String;
}
PROBE
}

# The completeness scope's raw source LIST is the same value in a different
# shape, and an allow-list that missed it would be decorative.
mut_op_health_reads_raw_list() {
  cat > "$CASE_ROOT/$OP_HEALTH_PROBE" <<'PROBE'
class OriginProbe {
  List<String> pick(dynamic scope) => scope.sourceIdentifiers as List<String>;
}
PROBE
}

mut_op_dart_display_name() {
  cat > "$CASE_ROOT/$OP_HEALTH_PROBE" <<'PROBE'
class OriginProbe {
  String deviceName = 'unset';
}
PROBE
}

mut_op_swift_display_name() {
  cat > "$CASE_ROOT/$OP_SWIFT_PROBE" <<'PROBE'
import Foundation

struct OriginProbe {
  func label(_ source: HKSource) -> String {
    return source.name
  }
}
PROBE
}

# Raw identifiers actually live natively, so this is where the sink check earns
# its place: device logs are readable, exportable and outlive the app.
mut_op_swift_logs_raw() {
  cat > "$CASE_ROOT/$OP_SWIFT_PROBE" <<'PROBE'
import Foundation

struct OriginProbe {
  func trace(_ sourceIdentifier: String) {
    NSLog("read from %@", sourceIdentifier)
  }
}
PROBE
}

# The wire field is "simplified" back into a String. One edit, every other check
# still green, and the channel a device name travels in is open again.
mut_op_pigeon_origin_string() {
  sed -i 's/^  final Uint8List originKey;$/  final String originKey;/' \
    "$CASE_ROOT/$OP_PIGEON"
}

mut_op_swift_mints_identity() {
  cat > "$CASE_ROOT/$OP_SWIFT_PROBE" <<'PROBE'
import Foundation

struct OriginProbe {
  func mint() -> Data {
    var bytes = [UInt8](repeating: 0, count: 16)
    _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    return Data(bytes)
  }
}
PROBE
}

# A platform VALUE reaches a diagnostic without the field ever being named. This
# is the leak the guard found in Pigeon's generated toString, and the reason
# rule_no_platform_value_sink exists at all.
mut_op_platform_value_sink() {
  cat > "$CASE_ROOT/$OP_HEALTH_PROBE" <<'PROBE'
import 'messages.g.dart';

void probeLeak(PlatformSyncPage page) => throw StateError('page was $page');
PROBE
}

mut_op_kotlin_durable_store() {
  cat > "$CASE_ROOT/$OP_KOTLIN_PROBE" <<'PROBE'
package com.projectstride.stride_health

import android.content.Context

class OriginProbe(private val context: Context) {
    fun remember(cursor: ByteArray) {
        val prefs = context.getSharedPreferences("stride", Context.MODE_PRIVATE)
        prefs.edit().putString("cursor", cursor.toString()).apply()
    }
}
PROBE
}

# A Dart health-boundary surface puts the raw native identifier on a diagnostic
# sink. The value does not have to be persisted to escape; it only has to be
# logged, and a device log is readable, exportable and outlives the app.
#
# `named_rule` attribution, and NOT sole -- that is a property of the production
# rules rather than of the probe. `rule_no_dart_raw_sink` greps the SAME
# raw-symbol pattern as `rule_raw_identifier_sites` and then narrows it with
# DART_SINK, so its hit set is a strict SUBSET: with APPROVED empty, every line
# the sink rule can fire on trips the site rule too, and no probe can separate
# them at the guard level. Narrowing the site rule to make this case look
# isolated would weaken a production rule to flatter a test. The separation is
# proved where it is real -- with the rule invoked alone.
mut_op_dart_raw_sink() {
  cat > "$CASE_ROOT/$OP_HEALTH_PROBE" <<'PROBE'
import 'dart:developer' as developer;

class OriginProbe {
  void trace(dynamic observation) {
    developer.log('sync page from ${observation.sourceIdentifier}');
  }
}
PROBE
}

# stride_core acquires a platform dependency WITHOUT naming the raw identifier.
# That restriction is the entire point: op_core_reads_raw names sourceIdentifier
# inside the core, so rule_raw_identifier_sites fires on it first and the core
# rule was never independently falsified. This probe imports the health package
# and declares the Pigeon host API type -- the core acquiring an opinion about
# where its data came from, which is the regression the rule exists to stop.
mut_op_core_boundary_isolation() {
  cat > "$CASE_ROOT/$OP_CORE_PROBE" <<'PROBE'
import 'package:stride_health/stride_health.dart';

abstract class CoreBoundaryProbe {
  HealthHostApi get api;
}
PROBE
}

# The two layering cases, in the other direction. In a privacy guard the
# dangerous failure is not a false rejection -- it is a clean-looking run that
# read nothing.
#
# The Swift and Kotlin cases prove the native rules fire when a violation is
# present. They cannot prove the native scan happened at all: a copy without
# those directories produces no findings and looks exactly like a clean tree.
mut_op_empty_native_scan() {
  rm -rf "$CASE_ROOT/$OP_IOS_SOURCES" "$CASE_ROOT/$OP_ANDROID_MAIN"
}

# And a MISSING platform contract must be infrastructure rather than a
# rejection. If it were a rejection, op_pigeon_origin_string could be satisfied
# by deleting the file instead of by changing the type -- which is what the
# `forbid` on this case makes a behaviour rather than a comment.
mut_op_missing_pigeon_input() {
  rm -f "$CASE_ROOT/$OP_PIGEON"
}

# --- step-model ------------------------------------------------------------
SM_APP_PROBE="lib/__step_model_probe.dart"
SM_HEALTH_PROBE="packages/stride_health/lib/src/__step_model_probe.dart"
SM_CORE_PROBE="packages/stride_core/lib/src/__step_model_probe.dart"
SM_TEST_PROBE="packages/stride_core/test/__step_model_probe_test.dart"
SM_SWIFT_PROBE="packages/stride_health/ios/stride_health/Sources/stride_health/__StepModelProbe.swift"
SM_PIGEON="packages/stride_health/pigeons/health_api.dart"
SM_COMMANDS="packages/stride_core/lib/src/engine/commands.dart"
SM_PRIVACY="packages/stride_core/test/save_privacy_test.dart"
SM_IOS_SOURCES="packages/stride_health/ios/stride_health/Sources"
SM_ANDROID_MAIN="packages/stride_health/android/src/main"

# The retired step model, in both halves. Two cases rather than one, so neither
# symbol is proven only by the other having already fired.
mut_sm_step_fetch_result() {
  cat > "$CASE_ROOT/$SM_APP_PROBE" <<'PROBE'
class StepFetchResult {
  StepFetchResult(this.newStepCount);
  final int newStepCount;
}
PROBE
}

mut_sm_fetch_new_steps() {
  cat > "$CASE_ROOT/$SM_HEALTH_PROBE" <<'PROBE'
abstract interface class LegacySource {
  Future<int> fetchNewSteps();
}
PROBE
}

# A flat unscoped step field on the platform contract. This is the one that
# would look most reasonable in review -- "just a total, for the summary
# screen" -- and it is the whole defect.
mut_sm_flat_contract_field() {
  cat >> "$CASE_ROOT/$SM_PIGEON" <<'PROBE'

class PlatformStepTotal {
  PlatformStepTotal({required this.newSteps});
  final int newSteps;
}
PROBE
}

# The same field in native, where the Dart contract check cannot see it.
mut_sm_flat_native_field() {
  cat > "$CASE_ROOT/$SM_SWIFT_PROBE" <<'PROBE'
import Foundation

struct StepModelProbe {
  var newSteps: Int64 = 0
}
PROBE
}

mut_sm_second_ingest_entry() {
  cat > "$CASE_ROOT/$SM_CORE_PROBE" <<'PROBE'
class LegacyIngest {
  int ingestSteps(int count) => count;
}
PROBE
}

# A settling completeness constructed away from the anchored site, which is how
# a partial page comes to advance a settled watermark. Both symbols separately:
# the rule loops over SETTLING_SYMBOLS, and one case would leave the other
# symbol's iteration unproven.
mut_sm_settling_complete_through() {
  cat > "$CASE_ROOT/$SM_HEALTH_PROBE" <<'PROBE'
import 'package:stride_core/stride_core.dart';

SyncCompleteness settleAnyway(CompletenessScope scope) =>
    CompleteThrough(throughMillis: 0, scope: scope);
PROBE
}

mut_sm_settling_recovery_complete_through() {
  cat > "$CASE_ROOT/$SM_HEALTH_PROBE" <<'PROBE'
import 'package:stride_core/stride_core.dart';

SyncCompleteness settleAnyway(CompletenessScope scope) =>
    RecoveryCompleteThrough(throughMillis: 0, scope: scope);
PROBE
}

# A whole-ledger comparison built on StepLedger.signature, in a file that is not
# allow-listed -- the A.2 defect exactly: a test claiming two ledgers are
# identical using a summary that cannot see the durable cursor or the per-origin
# watermarks.
#
# The receivers are called `a` and `b` DELIBERATELY, and that is this case's
# second job. The first version of the rule matched `.signature` only on
# receivers whose names looked ledger-ish, and this exact probe walked straight
# through it. The rule now matches every `.signature`; this case is what keeps
# the receiver-name trick under permanent test, so a future "let's reduce false
# positives by naming the receivers we care about" cannot land quietly.
mut_sm_signature_test_equality() {
  cat > "$CASE_ROOT/$SM_TEST_PROBE" <<'PROBE'
import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

void main() {
  test('the ledger is unchanged', () {
    final StepLedger a = StepLedger.empty();
    final StepLedger b = StepLedger.empty();
    expect(a.signature, b.signature);
  });
}
PROBE
}

# The same misuse in PRODUCTION, where it would be a save-integrity decision
# rather than a weak test -- which is what GameState.signature was doing in
# SaveRepository before A.1.
mut_sm_signature_production_integrity() {
  cat > "$CASE_ROOT/$SM_CORE_PROBE" <<'PROBE'
import '../steps/step_ledger.dart';

bool ledgersAgree(StepLedger a, StepLedger b) => a.signature == b.signature;
PROBE
}

# CAPTURE inside an ALLOW-LISTED file. The allow-list exists for tests whose
# subject is the diagnostic itself; those assert on it in place. Holding the
# value is how a summary becomes evidence, and it must be rejected even where
# the symbol is permitted -- otherwise the allow-list is a blanket exemption
# rather than a scoped one. Injected into save_privacy_test.dart, which IS
# allow-listed, so rule_signature_allowed_files skips it and only
# rule_no_signature_capture can fire.
mut_sm_signature_capture_variable() {
  cat >> "$CASE_ROOT/$SM_PRIVACY" <<'PROBE'

// injected by the self-test
String capturedLedgerEvidence(StepLedger ledger) {
  final String before = ledger.signature;
  return before;
}
PROBE
}

# The same capture in its OTHER syntactic form. SIGNATURE_CAPTURE is an
# alternation of two shapes, and the case above exercises exactly one of them:
# an edit that broke the `.add(` branch would have left it green and the
# collection form unguarded. The list is built empty and appended to, so the `=`
# branch cannot fire and the case proves the branch it is named for.
mut_sm_signature_capture_collection() {
  cat >> "$CASE_ROOT/$SM_PRIVACY" <<'PROBE'

// injected by the self-test
List<String> collectedLedgerEvidence(StepLedger ledger) {
  final List<String> seen = <String>[];
  seen.add(ledger.signature);
  return seen;
}
PROBE
}

# The per-origin observation class is renamed away. rule_no_flat_contract_field
# is an ABSENCE check, so a contract carrying no step shape at all satisfies it
# perfectly; this is the rule that makes "no flat field" mean something.
#
# A PREFIX rename, not a suffix: the check is a fixed-string search for
# `class PlatformStepObservation`, which `class PlatformStepObservationV2` would
# still satisfy. The probe has to actually remove the declaration.
mut_sm_observation_class_renamed() {
  sed -i 's/^class PlatformStepObservation {$/class PlatformObservationRecord {/' \
    "$CASE_ROOT/$SM_PIGEON"
}

# The one ingestion command is renamed away -- the same shape of gap:
# rule_single_ingest_entry_point proves no SECOND way into the engine exists,
# which is vacuously true of a codebase with no way in at all.
mut_sm_ingest_command_renamed() {
  sed -i 's/^final class ReconcileStepSync extends/final class ReconcileStepDelivery extends/' \
    "$CASE_ROOT/$SM_COMMANDS"
}

# The two layering cases. Every content rule in this guard is an ABSENCE check,
# and a tree the guard cannot read produces absence too.
mut_sm_empty_native_scan() {
  rm -rf "$CASE_ROOT/$SM_IOS_SOURCES" "$CASE_ROOT/$SM_ANDROID_MAIN"
}

mut_sm_missing_pigeon_input() {
  rm -f "$CASE_ROOT/$SM_PIGEON"
}

# The two invocation cases. Invalid invocation is infrastructure, not a finding.
# A guard that reported a misspelled flag as a policy violation would let a typo
# in CI read as a repository defect -- and, worse, would let a rejection case be
# satisfied by one. That is the check-android-target.sh defect exactly.
#
# `form=invocation`: these touch no file, so they declare no changed-path set
# and the registry rejects them if they carry one.
inv_sm_bad_project_root() {
  bash "$CASE_SCRIPT" --project-root "$CASE_ROOT/does-not-exist"
}

inv_sm_unknown_argument() {
  bash "$CASE_SCRIPT" --not-a-real-flag
}

# ===========================================================================
# THE INVENTORY
#
# Diagnostics are matched on the stable ID and never on prose. Prose is for the
# human reading the failure and is expected to be rewritten; matching it would
# mean improving a message could silently stop a case proving anything.
# ===========================================================================

# --- Android: 6 reject, 1 accept -------------------------------------------
reg_case id=android_min_sdk_24 guard=android rule=rule_min_sdk_pinned \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[android\.min_sdk_pinned\]' \
  files="$A_PLUGIN_GRADLE" apply=mut_android_min_sdk_24

reg_case id=android_min_sdk_25 guard=android rule=rule_min_sdk_pinned \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[android\.min_sdk_pinned\]' \
  files="$A_EXAMPLE_GRADLE" apply=mut_android_min_sdk_25

reg_case id=android_min_sdk_inherited guard=android rule=rule_min_sdk_pinned \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[android\.min_sdk_pinned\]' \
  files="$A_EXAMPLE_GRADLE" apply=mut_android_min_sdk_inherited

reg_case id=android_override_library guard=android rule=rule_no_override_library \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[android\.no_override_library\]' \
  files="$A_PLUGIN_MANIFEST" apply=mut_android_override_library

reg_case id=android_manifest_min_sdk guard=android rule=rule_manifest_min_sdk \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[android\.manifest_min_sdk\]' \
  files="$A_PLUGIN_MANIFEST" apply=mut_android_manifest_min_sdk

reg_case id=android_background_service guard=android rule=rule_no_background_entry \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[android\.no_background_entry\]' \
  files="$A_PLUGIN_MANIFEST" apply=mut_android_background_service

reg_case id=android_comment_false_positive guard=android rule=rule_no_override_library \
  expect=accept form=mutation attribution=complete_guard \
  files="$A_PLUGIN_MANIFEST" apply=mut_android_comment_false_positive

# --- iOS: 17 reject, 1 layering --------------------------------------------
reg_case id=ios_deploy_target_app guard=ios rule=rule_deployment_target \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.deployment_target\]' \
  files="$I_PROJ_REL" apply=mut_ios_deploy_target_app

reg_case id=ios_deploy_target_example guard=ios rule=rule_deployment_target \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.deployment_target\]' \
  files="$I_EX_REL" apply=mut_ios_deploy_target_example

reg_case id=ios_device_family_ipad guard=ios rule=rule_device_family \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.device_family\]' \
  files="$I_PROJ_REL" apply=mut_ios_device_family_ipad

reg_case id=ios_entitlements_unwired guard=ios rule=rule_entitlements_wired \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.entitlements_wired\]' \
  files="$I_PROJ_REL" apply=mut_ios_entitlements_unwired

reg_case id=ios_orientation_landscape guard=ios rule=rule_orientation_portrait \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.orientation_portrait\]' \
  files="$I_PLIST_REL" apply=mut_ios_orientation_landscape

reg_case id=ios_share_string_empty guard=ios rule=rule_health_share_string \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.health_share_string\]' \
  files="$I_PLIST_REL" apply=mut_ios_share_string_empty

reg_case id=ios_share_string_blank guard=ios rule=rule_health_share_string \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.health_share_string\]' \
  files="$I_PLIST_REL" apply=mut_ios_share_string_blank

reg_case id=ios_share_string_renamed guard=ios rule=rule_health_share_string \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.health_share_string\]' \
  files="$I_PLIST_REL" apply=mut_ios_share_string_renamed

reg_case id=ios_health_write_string guard=ios rule=rule_no_health_write_string \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.no_health_write_string\]' \
  files="$I_PLIST_REL" apply=mut_ios_health_write_string

reg_case id=ios_background_modes guard=ios rule=rule_no_background_modes \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.no_background_modes\]' \
  files="$I_PLIST_REL" apply=mut_ios_background_modes

reg_case id=ios_background_delivery guard=ios rule=rule_no_background_delivery \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.no_background_delivery\]' \
  files="$I_ENT_REL" apply=mut_ios_background_delivery

reg_case id=ios_healthkit_string_true guard=ios rule=rule_healthkit_entitlement_true \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.healthkit_entitlement_true\]' \
  files="$I_ENT_REL" apply=mut_ios_healthkit_string_true

reg_case id=ios_entitlement_dupe_key guard=ios rule=rule_no_duplicate_entitlement_keys \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.no_duplicate_entitlement_keys\]' \
  files="$I_ENT_REL" apply=mut_ios_entitlement_dupe_key

reg_case id=ios_plist_malformed guard=ios rule=rule_plist_parses \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.plist_parses\]' \
  files="$I_PLIST_REL" apply=mut_ios_plist_malformed

reg_case id=ios_entitlements_malformed guard=ios rule=rule_entitlements_parses \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.entitlements_parses\]' \
  files="$I_ENT_REL" apply=mut_ios_entitlements_malformed

reg_case id=ios_entitlements_foreign_doctype guard=ios rule=rule_entitlements_parses \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.entitlements_parses\]' \
  files="$I_ENT_REL" apply=mut_ios_entitlements_foreign_doctype

reg_case id=ios_entitlements_internal_subset guard=ios rule=rule_entitlements_parses \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.entitlements_parses\]' \
  files="$I_ENT_REL" apply=mut_ios_entitlements_internal_subset

# The iOS layering case. A DELETED tracked file is ABSENCE -- `ios.
# entitlements_present`, at exit 1 -- and must NEVER be reported as
# `ios.entitlements_parses`, which is the rule reserved for a file that was read
# and is not a valid document. The `forbid` field is what makes that a
# behaviour rather than a comment.
#
# NOTE ON ITS CLASS: this is `reject`, not `infra`, because that is what the
# production rules do and what a developer sees -- an absent entitlements file
# is a policy violation the guard states by name, and it never reaches xmlq at
# all. Classifying it `infra` would require exit 2, which would mean weakening
# `rule_entitlements_present` to flatter the registry.
reg_case id=ios_entitlements_absent guard=ios rule=rule_entitlements_present \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[ios\.entitlements_present\]' \
  forbid='STRIDE_GUARD\[ios\.entitlements_parses\]' \
  files="$I_ENT_REL" apply=mut_ios_entitlements_absent

# --- single-writer: 5 reject, 1 infra --------------------------------------
reg_case id=sw_background_isolate_repo guard=single-writer rule=rule_approved_construction_sites \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[single-writer\.approved_construction_sites\]' \
  files="$SW_DART_PROBE" apply=mut_sw_background_isolate_repo

reg_case id=sw_unapproved_construction guard=single-writer rule=rule_approved_construction_sites \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[single-writer\.approved_construction_sites\]' \
  files="$SW_DART_PROBE" apply=mut_sw_unapproved_construction

reg_case id=sw_dart_background_entry guard=single-writer rule=rule_no_dart_background_entry \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[single-writer\.no_dart_background_entry\]' \
  files="$SW_DART_PROBE" apply=mut_sw_dart_background_entry

reg_case id=sw_native_background_swift guard=single-writer rule=rule_no_native_background_entry \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[single-writer\.no_native_background_entry\]' \
  files="$SW_SWIFT_PROBE" apply=mut_sw_native_background_swift

reg_case id=sw_native_background_kotlin guard=single-writer rule=rule_no_native_background_entry \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[single-writer\.no_native_background_entry\]' \
  files="$SW_KOTLIN_PROBE" apply=mut_sw_native_background_kotlin

reg_case id=sw_empty_native_scan guard=single-writer rule=rule_native_scan_coverage \
  expect=infra form=mutation attribution=complete_guard \
  diag='STRIDE_INFRA\[single-writer\.no_native_sources\]' \
  files="$SW_IOS_SOURCES $SW_ANDROID_MAIN" apply=mut_sw_empty_native_scan

# --- origin-privacy: 12 reject, 2 infra ------------------------------------
#
# `op_core_boundary_isolation` carries the `sole` obligation the embedded
# self-test asserted by hand: the complete guard must name THAT rule and no
# other. Expressed here as a `forbid` over every other diagnostic this guard can
# emit, which makes it a registry-enforced property rather than a bespoke branch
# in one guard's self-test. Any rule added to origin-privacy must be added here
# too, or the case stops being the sole-attribution proof it is filed as.
OP_NOT_CORE_BOUNDARY='STRIDE_(GUARD|INFRA)\[origin-privacy\.(root_missing|no_dart_sources|no_native_sources|pigeon_input_missing|raw_identifier_sites|no_dart_display_name|no_native_display_name|no_dart_raw_sink|no_native_raw_sink|no_native_durable_store|no_platform_value_sink|pigeon_origin_opaque|no_native_identity_minting|usage)\]'

reg_case id=op_core_reads_raw guard=origin-privacy rule=rule_raw_identifier_sites \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[origin-privacy\.raw_identifier_sites\]' \
  files="$OP_CORE_PROBE" apply=mut_op_core_reads_raw

reg_case id=op_app_reads_raw guard=origin-privacy rule=rule_raw_identifier_sites \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[origin-privacy\.raw_identifier_sites\]' \
  files="$OP_APP_PROBE" apply=mut_op_app_reads_raw

reg_case id=op_health_reads_raw_list guard=origin-privacy rule=rule_raw_identifier_sites \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[origin-privacy\.raw_identifier_sites\]' \
  files="$OP_HEALTH_PROBE" apply=mut_op_health_reads_raw_list

reg_case id=op_dart_display_name guard=origin-privacy rule=rule_no_dart_display_name \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[origin-privacy\.no_dart_display_name\]' \
  files="$OP_HEALTH_PROBE" apply=mut_op_dart_display_name

reg_case id=op_swift_display_name guard=origin-privacy rule=rule_no_native_display_name \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[origin-privacy\.no_native_display_name\]' \
  files="$OP_SWIFT_PROBE" apply=mut_op_swift_display_name

reg_case id=op_swift_logs_raw guard=origin-privacy rule=rule_no_native_raw_sink \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[origin-privacy\.no_native_raw_sink\]' \
  files="$OP_SWIFT_PROBE" apply=mut_op_swift_logs_raw

reg_case id=op_pigeon_origin_string guard=origin-privacy rule=rule_pigeon_origin_opaque \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[origin-privacy\.pigeon_origin_opaque\]' \
  files="$OP_PIGEON" apply=mut_op_pigeon_origin_string

reg_case id=op_swift_mints_identity guard=origin-privacy rule=rule_no_native_identity_minting \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[origin-privacy\.no_native_identity_minting\]' \
  files="$OP_SWIFT_PROBE" apply=mut_op_swift_mints_identity

reg_case id=op_platform_value_sink guard=origin-privacy rule=rule_no_platform_value_sink \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[origin-privacy\.no_platform_value_sink\]' \
  files="$OP_HEALTH_PROBE" apply=mut_op_platform_value_sink

reg_case id=op_kotlin_durable_store guard=origin-privacy rule=rule_no_native_durable_store \
  expect=reject form=mutation attribution=complete_guard \
  diag='STRIDE_GUARD\[origin-privacy\.no_native_durable_store\]' \
  files="$OP_KOTLIN_PROBE" apply=mut_op_kotlin_durable_store

# The two structurally over-determined cases. `named_rule` additionally invokes
# the rule ALONE against the same mutated root: with one rule running, a
# mutation only some OTHER rule can see returns 0, so an unrelated rule cannot
# satisfy the attribution.
reg_case id=op_dart_raw_sink guard=origin-privacy rule=rule_no_dart_raw_sink \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[origin-privacy\.no_dart_raw_sink\]' \
  files="$OP_HEALTH_PROBE" apply=mut_op_dart_raw_sink

reg_case id=op_core_boundary_isolation guard=origin-privacy rule=rule_core_boundary_isolation \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[origin-privacy\.core_boundary_isolation\]' \
  forbid="$OP_NOT_CORE_BOUNDARY" \
  files="$OP_CORE_PROBE" apply=mut_op_core_boundary_isolation

# The layering pair. Neither may ever be satisfied as a privacy rejection: a
# missing platform source and a missing Pigeon input are things the guard could
# not look at, not things it looked at and rejected.
reg_case id=op_empty_native_scan guard=origin-privacy rule=rule_native_scan_coverage \
  expect=infra form=mutation attribution=complete_guard \
  diag='STRIDE_INFRA\[origin-privacy\.no_native_sources\]' \
  files="$OP_IOS_SOURCES $OP_ANDROID_MAIN" apply=mut_op_empty_native_scan

reg_case id=op_missing_pigeon_input guard=origin-privacy rule=rule_pigeon_input_present \
  expect=infra form=mutation attribution=complete_guard \
  diag='STRIDE_INFRA\[origin-privacy\.pigeon_input_missing\]' \
  forbid='STRIDE_GUARD\[origin-privacy\.pigeon_origin_opaque\]' \
  files="$OP_PIGEON" apply=mut_op_missing_pigeon_input

# --- step-model: 13 reject, 4 infra -----------------------------------------
#
# ## Why every rejection case here is `named_rule`
#
# This is the only guard whose embedded self-test already asserted the rule
# ALONE for every case, not just for the over-determined ones. Migrating those
# to `complete_guard` would drop an assertion that currently holds, which is a
# silent weakening of exactly the kind this migration exists to prevent. So all
# thirteen keep it. `named_rule` does not replace the complete-guard assertion —
# the runner makes both — it adds the isolation proof on top.
#
# ## Why every rejection case here also carries `forbid`
#
# The embedded self-test additionally required that the complete guard name NO
# OTHER rule, with over-determination declared per case rather than silently
# tolerated. None of the thirteen turned out to be over-determined, so none
# declares a second rule, and that property is preserved here as a `forbid` over
# every step-model diagnostic except the case's own. A rule added to this guard
# must be added to SM_DIAGS below, or these cases quietly stop making the
# sole-attribution claim they are filed under.
SM_DIAGS="root_missing usage no_dart_sources no_native_sources no_signature_sources pigeon_input_missing no_retired_dart_model no_retired_native_model no_flat_contract_field observation_class_present ingest_command_present single_ingest_entry_point settling_construction_sites signature_allowed_files no_signature_capture"

# Sets SM_FORBID to a regex matching every step-model diagnostic EXCEPT the one
# named. A plain assignment rather than a command substitution: cases.sh is
# sourced by every guard on every run, including once per guard invocation
# inside a self-test, and a subshell per case per source adds up to nothing
# useful.
sm_forbid_others() {
  local keep="$1" d alt=""
  for d in $SM_DIAGS; do
    [ "$d" = "$keep" ] && continue
    alt="$alt|$d"
  done
  SM_FORBID='STRIDE_(GUARD|INFRA)\[step-model\.('"${alt#|}"')\]'
}

sm_forbid_others no_retired_dart_model;      SM_NOT_RETIRED_DART="$SM_FORBID"
sm_forbid_others no_retired_native_model;    SM_NOT_RETIRED_NATIVE="$SM_FORBID"
sm_forbid_others no_flat_contract_field;     SM_NOT_FLAT_FIELD="$SM_FORBID"
sm_forbid_others single_ingest_entry_point;  SM_NOT_SINGLE_INGEST="$SM_FORBID"
sm_forbid_others settling_construction_sites; SM_NOT_SETTLING="$SM_FORBID"
sm_forbid_others signature_allowed_files;    SM_NOT_SIG_ALLOWED="$SM_FORBID"
sm_forbid_others no_signature_capture;       SM_NOT_SIG_CAPTURE="$SM_FORBID"
sm_forbid_others observation_class_present;  SM_NOT_OBSERVATION="$SM_FORBID"
sm_forbid_others ingest_command_present;     SM_NOT_INGEST_CMD="$SM_FORBID"

# Any STRIDE_GUARD diagnostic at all. An infrastructure case that also emitted a
# policy violation would be the two classes collapsing back into each other.
SM_NO_POLICY='STRIDE_GUARD\[step-model\.'

# ---- the ten historical cases, preserved ----------------------------------
reg_case id=sm_step_fetch_result guard=step-model rule=rule_no_retired_dart_model \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[step-model\.no_retired_dart_model\]' \
  forbid="$SM_NOT_RETIRED_DART" \
  files="$SM_APP_PROBE" apply=mut_sm_step_fetch_result

reg_case id=sm_fetch_new_steps guard=step-model rule=rule_no_retired_dart_model \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[step-model\.no_retired_dart_model\]' \
  forbid="$SM_NOT_RETIRED_DART" \
  files="$SM_HEALTH_PROBE" apply=mut_sm_fetch_new_steps

reg_case id=sm_flat_contract_field guard=step-model rule=rule_no_flat_contract_field \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[step-model\.no_flat_contract_field\]' \
  forbid="$SM_NOT_FLAT_FIELD" \
  files="$SM_PIGEON" apply=mut_sm_flat_contract_field

reg_case id=sm_flat_native_field guard=step-model rule=rule_no_retired_native_model \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[step-model\.no_retired_native_model\]' \
  forbid="$SM_NOT_RETIRED_NATIVE" \
  files="$SM_SWIFT_PROBE" apply=mut_sm_flat_native_field

reg_case id=sm_second_ingest_entry guard=step-model rule=rule_single_ingest_entry_point \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[step-model\.single_ingest_entry_point\]' \
  forbid="$SM_NOT_SINGLE_INGEST" \
  files="$SM_CORE_PROBE" apply=mut_sm_second_ingest_entry

reg_case id=sm_settling_complete_through guard=step-model rule=rule_settling_construction_sites \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[step-model\.settling_construction_sites\]' \
  forbid="$SM_NOT_SETTLING" \
  files="$SM_HEALTH_PROBE" apply=mut_sm_settling_complete_through

reg_case id=sm_settling_recovery_complete_through guard=step-model rule=rule_settling_construction_sites \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[step-model\.settling_construction_sites\]' \
  forbid="$SM_NOT_SETTLING" \
  files="$SM_HEALTH_PROBE" apply=mut_sm_settling_recovery_complete_through

reg_case id=sm_signature_test_equality guard=step-model rule=rule_signature_allowed_files \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[step-model\.signature_allowed_files\]' \
  forbid="$SM_NOT_SIG_ALLOWED" \
  files="$SM_TEST_PROBE" apply=mut_sm_signature_test_equality

reg_case id=sm_signature_production_integrity guard=step-model rule=rule_signature_allowed_files \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[step-model\.signature_allowed_files\]' \
  forbid="$SM_NOT_SIG_ALLOWED" \
  files="$SM_CORE_PROBE" apply=mut_sm_signature_production_integrity

reg_case id=sm_signature_capture_variable guard=step-model rule=rule_no_signature_capture \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[step-model\.no_signature_capture\]' \
  forbid="$SM_NOT_SIG_CAPTURE" \
  files="$SM_PRIVACY" apply=mut_sm_signature_capture_variable

# ---- the three added by the uncased-rule audit ----------------------------
reg_case id=sm_signature_capture_collection guard=step-model rule=rule_no_signature_capture \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[step-model\.no_signature_capture\]' \
  forbid="$SM_NOT_SIG_CAPTURE" \
  files="$SM_PRIVACY" apply=mut_sm_signature_capture_collection

reg_case id=sm_observation_class_renamed guard=step-model rule=rule_observation_class_present \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[step-model\.observation_class_present\]' \
  forbid="$SM_NOT_OBSERVATION" \
  files="$SM_PIGEON" apply=mut_sm_observation_class_renamed

reg_case id=sm_ingest_command_renamed guard=step-model rule=rule_ingest_command_present \
  expect=reject form=mutation attribution=named_rule \
  diag='STRIDE_GUARD\[step-model\.ingest_command_present\]' \
  forbid="$SM_NOT_INGEST_CMD" \
  files="$SM_COMMANDS" apply=mut_sm_ingest_command_renamed

# ---- four infrastructure cases, which no rejection case may be satisfied by -
reg_case id=sm_empty_native_scan guard=step-model rule=rule_native_scan_coverage \
  expect=infra form=mutation attribution=complete_guard \
  diag='STRIDE_INFRA\[step-model\.no_native_sources\]' \
  forbid="$SM_NO_POLICY" \
  files="$SM_IOS_SOURCES $SM_ANDROID_MAIN" apply=mut_sm_empty_native_scan

# Never no_flat_contract_field and never observation_class_present: without this
# case, sm_flat_contract_field and sm_observation_class_renamed could both be
# satisfied by DELETING the contract rather than by changing it.
reg_case id=sm_missing_pigeon_input guard=step-model rule=rule_pigeon_input_present \
  expect=infra form=mutation attribution=complete_guard \
  diag='STRIDE_INFRA\[step-model\.pigeon_input_missing\]' \
  forbid='STRIDE_GUARD\[step-model\.(no_flat_contract_field|observation_class_present)\]' \
  files="$SM_PIGEON" apply=mut_sm_missing_pigeon_input

reg_case id=sm_bad_project_root guard=step-model rule=rule_preflight \
  expect=infra form=invocation attribution=complete_guard \
  diag='STRIDE_INFRA\[step-model\.root_missing\]' \
  forbid="$SM_NO_POLICY" invoke=inv_sm_bad_project_root

# Filed under rule_preflight, the guard's entry-level infrastructure rule.
# `usage` is emitted by argument parsing before any rule runs, which is the
# point of the case: a call the guard does not understand must never be counted
# as a finding.
reg_case id=sm_unknown_argument guard=step-model rule=rule_preflight \
  expect=infra form=invocation attribution=complete_guard \
  diag='STRIDE_INFRA\[step-model\.usage\]' \
  forbid="$SM_NO_POLICY" invoke=inv_sm_unknown_argument
