// The device-bound secure storage boundary — single source of truth for both
// sides.
//
// Regenerate after any change:
//   cd packages/stride_secure_store
//   dart run pigeon --input pigeons/secure_store_api.dart
//
// Generated files are committed, and CI fails when they are stale — the same
// contract-drift rule stride_health lives under.
//
// ===========================================================================
// Why this boundary exists at all
// ===========================================================================
//
// F-06 persisted the pseudonymization salt in a file beside the save, under the
// same backup exclusions. On Android that is sufficient: the app-private
// directory is excluded from cloud backup and device transfer declaratively,
// and enforced by Scripts/check-backup-exclusions.sh.
//
// On iOS it was not sufficient, and the failure is exactly the one the
// fail-closed check was designed to catch:
//
//   1. Application Support is included in iCloud backup by default, and there
//      is no Info.plist key or build setting that changes that.
//   2. So the save slots, the ledger journal, AND the identity file all travel
//      together in a restore.
//   3. On the second device the salt fingerprint therefore still matches the
//      one in the restored snapshot envelope.
//   4. `_checkSalt` passes. `LoadRefusal.originKeyReset` never fires.
//   5. The ledger resumes against a HealthKit source the original device has
//      already consumed from — the exact double-grant the whole reconciliation
//      design exists to prevent, now silent and weeks after the fact.
//
// The check is defeated by the very transport it was built to detect, because
// the evidence and the thing it was meant to prove travel in the same suitcase.
//
// The fix is defence in depth, and both halves are the owner's ruling:
//
//   * The identity moves into the Keychain with
//     `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. `ThisDeviceOnly`
//     items are NOT included in an encrypted backup and are NOT restored to a
//     different device. So on a restored device the identity is *absent* while
//     the save is present — which is the `originIdentityMissing` refusal, and
//     the refusal fires again.
//   * `NSURLIsExcludedFromBackupKey` is applied to the save directory and every
//     file `StorageLayout` declares, so the save and the ledger should not
//     migrate either. Belt as well as braces: the first control restores the
//     refusal, the second stops the ledger travelling in the first place.
//
// `AfterFirstUnlock`, not `WhenUnlocked`: cold-launch backfill and any
// best-effort background wake must be able to read the identity after the
// first unlock since boot. `WhenUnlocked` would make a background reconcile
// on a pocketed phone read as "no identity", and a store that reports absence
// when it means "locked" is precisely how a replacement key gets minted over a
// live save.
//
// ===========================================================================
// What the raw salt is, and where it may go
// ===========================================================================
//
// The salt crosses this boundary. That is the point of the boundary: it is the
// only channel by which the salt reaches Dart, and from Dart it goes only to
// `OriginPseudonymizer`. It never enters `stride_core`, never enters a save
// envelope, and never reaches a diagnostic. Only the fingerprint does.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    // The plugin uses the Swift Package Manager layout, like stride_health.
    // Generating into ios/Classes/ would produce a file that is never compiled.
    swiftOut:
        'ios/stride_secure_store/Sources/stride_secure_store/Messages.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'stride_secure_store',
  ),
)
/// Why a read returned no record.
///
/// The whole safety argument rests on this enum having more than two cases.
/// "Absent" and "I could not tell" must never collapse into one value: a
/// locked-device read that reports absence is how a replacement identity gets
/// minted over a live save.
enum PlatformSecureReadStatus {
  /// A record exists and is in the result.
  found,

  /// The keychain was readable and holds no record for this app.
  ///
  /// Only ever produced by `errSecItemNotFound`. Nothing else may map here.
  absent,

  /// The keychain could not answer. **Not absence.**
  ///
  /// Chiefly `errSecInteractionNotAllowed`, which is what a read gets before
  /// the first unlock since boot. Callers must treat this as an I/O fault and
  /// refuse, never as a new installation.
  unavailable,
}

/// Why a create failed.
enum PlatformSecureWriteStatus {
  created,

  /// An item was already there. **Never overwritten.**
  ///
  /// The platform call is `SecItemAdd` and there is deliberately no update
  /// path: an identity that already exists is either the live one or evidence
  /// of a crash between minting and the first commit, and both are cases where
  /// replacing it would orphan a save.
  alreadyExists,

  /// The keychain refused for any other reason.
  failed,
}

/// The identity as it is stored on the device.
class PlatformIdentityRecord {
  PlatformIdentityRecord({required this.saveId, required this.salt});

  /// Opaque lineage id, minted by the app at new-game time.
  final String saveId;

  /// The raw pseudonymization salt. Protected local reconciliation metadata:
  /// it reaches `OriginPseudonymizer` and nothing else.
  final Uint8List salt;
}

class PlatformSecureReadResult {
  PlatformSecureReadResult({required this.status, this.record, this.osStatus});

  final PlatformSecureReadStatus status;

  /// Non-null exactly when [status] is `found`.
  final PlatformIdentityRecord? record;

  /// The raw `OSStatus`, for a log line. Never shown to a player and never
  /// used to make a decision — the decision is [status].
  final int? osStatus;
}

/// The result of applying `NSURLIsExcludedFromBackupKey`.
///
/// Reported per path rather than as one boolean, because a partial application
/// is the interesting case: a directory that is excluded while one file inside
/// it is not is still a ledger that travels.
class PlatformBackupExclusionReport {
  PlatformBackupExclusionReport({
    required this.excluded,
    required this.missing,
    required this.failed,
  });

  /// Paths that now carry the exclusion, verified by reading the attribute
  /// back rather than by the setter returning without error.
  final List<String> excluded;

  /// Paths that do not exist yet. Not a failure: `StorageLayout` names every
  /// file it *may* create, and the journal sidecar usually does not exist.
  final List<String> missing;

  /// Paths that exist and could not be excluded. Each entry is
  /// `path\t<reason>`. This is the one condition that means the ledger would
  /// travel.
  final List<String> failed;
}

/// Read-back of what was actually configured, for tests and for a startup
/// self-check.
///
/// Exists because "we set the attribute" and "the attribute is set" are
/// different claims, and only the second one is worth anything after a
/// directory has been recreated by a restore.
class PlatformSecureStoreDiagnostics {
  PlatformSecureStoreDiagnostics({
    required this.keychainAccessibility,
    required this.excludedPaths,
    required this.notExcludedPaths,
    required this.missingPaths,
  });

  /// The `kSecAttrAccessible` value on the stored item, as its raw string
  /// (`cku` for AfterFirstUnlockThisDeviceOnly, `ak` for WhenUnlocked, and so
  /// on). Null when no item is stored.
  ///
  /// A string rather than an enum because the assertion worth making is
  /// "exactly the constant we asked for", and an enum would silently fold an
  /// unexpected value into a known case.
  final String? keychainAccessibility;

  final List<String> excludedPaths;
  final List<String> notExcludedPaths;
  final List<String> missingPaths;
}

@HostApi()
abstract class SecureStoreHostApi {
  /// Reads the stored identity.
  ///
  /// Never throws for absence — absence is a typed status. It throws only when
  /// the platform itself misbehaves in a way that has no status.
  @async
  PlatformSecureReadResult readIdentity();

  /// Creates the identity. **Add-only.**
  ///
  /// There is no update method on this interface, and that is the enforcement
  /// mechanism for "never overwrite an existing key because a read failed": a
  /// caller that has just had a read fail cannot express an overwrite.
  @async
  PlatformSecureWriteStatus createIdentity(PlatformIdentityRecord record);

  /// Removes the identity. Full reset only, and only from an explicit player
  /// action.
  @async
  bool deleteIdentity();

  /// Applies `NSURLIsExcludedFromBackupKey` to [directoryPath] and each of
  /// [filePaths], and verifies each by reading the attribute back.
  ///
  /// **Must be called on every launch.** The attribute lives on the filesystem
  /// node, not on the app: if the directory is deleted and recreated — by a
  /// restore, by a reinstall, by our own `ensureExists` after a wipe — the
  /// exclusion is gone and nothing reports it.
  @async
  PlatformBackupExclusionReport applyBackupExclusions(
    String directoryPath,
    List<String> filePaths,
  );

  /// Reads back what is actually configured. Diagnostics only.
  @async
  PlatformSecureStoreDiagnostics readDiagnostics(List<String> paths);
}
