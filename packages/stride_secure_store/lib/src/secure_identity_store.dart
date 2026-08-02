/// The typed platform port for device-bound identity storage.
///
/// Platform-neutral types, deliberately: nothing outside this file touches a
/// Pigeon-generated class, so a fake is a fifty-line class rather than a mock
/// of a generated codec, and every ordering rule in the app can be exercised
/// under `flutter test` on Windows.
///
/// ## The rule this port makes structural
///
/// There is a [create] and there is a [delete]. **There is no update.**
///
/// The ruling says: never overwrite an existing key because a read failed. A
/// caller cannot obey that rule by remembering it — the moment a read fails and
/// the obvious repair is "write a fresh one", remembering is exactly what stops
/// happening. So the interface does not offer the operation. [create] is
/// `SecItemAdd`, and an existing item comes back as
/// [SecureWriteOutcome.alreadyExists], not as a silent replacement.
library;

import 'package:flutter/foundation.dart';

/// Whether a read found a record, proved there was none, or could not tell.
///
/// Three cases, not two, and the third is the entire point. On iOS a read
/// before the first unlock since boot returns `errSecInteractionNotAllowed`.
/// Folding that into "absent" would tell the bootstrap that a device with a
/// live save is a new installation.
enum SecureReadOutcome { found, absent, unavailable }

/// Whether a create landed.
enum SecureWriteOutcome { created, alreadyExists, failed }

/// The identity as stored on the device: the save lineage id and the raw
/// pseudonymization salt.
///
/// The salt is here and nowhere else in Dart except [OriginPseudonymizer]'s
/// constructor. It never enters `stride_core`, never enters a save envelope,
/// and never reaches a diagnostic — only its fingerprint does.
@immutable
final class SecureIdentity {
  const SecureIdentity({required this.saveId, required this.salt});

  final String saveId;
  final Uint8List salt;

  @override
  bool operator ==(Object other) =>
      other is SecureIdentity &&
      other.saveId == saveId &&
      _sameBytes(other.salt, salt);

  @override
  int get hashCode => Object.hash(saveId, Object.hashAll(salt));

  /// Never prints the salt. This type reaches log lines by accident sooner or
  /// later, and a `toString` that dumps key material is how it gets there.
  @override
  String toString() => 'SecureIdentity(saveId: <redacted>, salt: <redacted>)';
}

bool _sameBytes(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// What a read produced.
@immutable
final class SecureReadResult {
  const SecureReadResult({
    required this.outcome,
    this.identity,
    this.diagnostic,
  });

  const SecureReadResult.found(SecureIdentity identity)
    : this(outcome: SecureReadOutcome.found, identity: identity);

  const SecureReadResult.absent() : this(outcome: SecureReadOutcome.absent);

  const SecureReadResult.unavailable([String? diagnostic])
    : this(outcome: SecureReadOutcome.unavailable, diagnostic: diagnostic);

  final SecureReadOutcome outcome;

  /// Non-null exactly when [outcome] is [SecureReadOutcome.found].
  final SecureIdentity? identity;

  /// A short technical note for a log line — an `OSStatus`, a platform error
  /// code. Never player-facing, never a decision input.
  final String? diagnostic;
}

/// What applying the backup exclusion actually achieved.
@immutable
final class BackupExclusionReport {
  const BackupExclusionReport({
    required this.excluded,
    required this.missing,
    required this.failed,
  });

  const BackupExclusionReport.notApplicable()
    : excluded = const <String>[],
      missing = const <String>[],
      failed = const <String>[];

  /// Paths verified to carry the exclusion, by reading the attribute back.
  final List<String> excluded;

  /// Paths that do not exist yet. `StorageLayout` names every file it *may*
  /// create; the journal sidecar normally does not exist, and that is healthy.
  final List<String> missing;

  /// Paths that exist and could not be excluded, as `path\treason`.
  ///
  /// The only entry in this class that means something is wrong: a file here
  /// is a file that would travel in an iCloud restore.
  final List<String> failed;

  bool get isClean => failed.isEmpty;
}

/// Read-back of what is actually configured on the device.
@immutable
final class SecureStoreDiagnostics {
  const SecureStoreDiagnostics({
    this.keychainAccessibility,
    this.excludedPaths = const <String>[],
    this.notExcludedPaths = const <String>[],
    this.missingPaths = const <String>[],
  });

  /// The raw `kSecAttrAccessible` value on the stored item, or null when there
  /// is no item.
  ///
  /// Raw, not an enum: the assertion worth making is "exactly the constant we
  /// asked for", and an enum folds an unexpected value into a known case.
  final String? keychainAccessibility;

  final List<String> excludedPaths;
  final List<String> notExcludedPaths;
  final List<String> missingPaths;
}

/// Device-bound secure storage for the reconciliation identity.
///
/// "Device-bound" is the requirement, not "encrypted". The threat is not an
/// attacker with the phone — they have already won, and the salt is protected
/// local metadata rather than a secret. The threat is an *honest* iCloud
/// restore onto a second device, which is precisely the case an encrypted
/// backup carries faithfully.
abstract interface class SecureIdentityStore {
  /// Whether this platform has a device-bound store at all.
  ///
  /// False off iOS. The caller then keeps app-private file storage, which is
  /// the owner's ruling for Android.
  bool get isSupported;

  Future<SecureReadResult> read();

  /// Add-only. Never replaces.
  Future<SecureWriteOutcome> create(SecureIdentity identity);

  /// Full reset only, from an explicit player action.
  Future<bool> delete();

  /// Applies the platform's backup exclusion to the save directory and every
  /// file the layout declares, and verifies it by reading back.
  ///
  /// Call on every launch. The attribute lives on the filesystem node, so a
  /// recreated directory silently loses it.
  Future<BackupExclusionReport> applyBackupExclusions({
    required String directoryPath,
    required List<String> filePaths,
  });

  Future<SecureStoreDiagnostics> readDiagnostics(List<String> paths);
}

/// The store on a platform that has none.
///
/// Reports [SecureReadOutcome.absent] rather than
/// [SecureReadOutcome.unavailable], and that distinction is load-bearing: this
/// is not a store that failed, it is a platform that never had one, and the
/// caller must fall through to file storage rather than refuse to start.
final class UnsupportedSecureIdentityStore implements SecureIdentityStore {
  const UnsupportedSecureIdentityStore();

  @override
  bool get isSupported => false;

  @override
  Future<SecureReadResult> read() async => const SecureReadResult.absent();

  @override
  Future<SecureWriteOutcome> create(SecureIdentity identity) async =>
      SecureWriteOutcome.failed;

  @override
  Future<bool> delete() async => false;

  @override
  Future<BackupExclusionReport> applyBackupExclusions({
    required String directoryPath,
    required List<String> filePaths,
  }) async => const BackupExclusionReport.notApplicable();

  @override
  Future<SecureStoreDiagnostics> readDiagnostics(List<String> paths) async =>
      const SecureStoreDiagnostics();
}
