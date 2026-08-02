/// The Pigeon-backed implementation of [SecureIdentityStore].
///
/// Translates the platform boundary into the port's neutral types and does
/// nothing else — no policy, no ordering, no fallback. Every decision about
/// *when* to read, create, or refuse lives in the app's identity vault and in
/// `stride_core`'s bootstrap coordinator, where it runs under `dart test` with
/// no device.
library;

import 'dart:io' show Platform;

import 'messages.g.dart';
import 'secure_identity_store.dart';

/// The iOS Keychain, behind the typed port.
final class KeychainIdentityStore implements SecureIdentityStore {
  KeychainIdentityStore({SecureStoreHostApi? api, bool? supported})
    : _api = api ?? SecureStoreHostApi(),
      // `Platform.isIOS` rather than a compile-time constant, so a test can
      // construct a supported store on Windows with a fake api.
      _supported = supported ?? Platform.isIOS;

  final SecureStoreHostApi _api;
  final bool _supported;

  @override
  bool get isSupported => _supported;

  @override
  Future<SecureReadResult> read() async {
    final PlatformSecureReadResult result = await _api.readIdentity();
    return switch (result.status) {
      PlatformSecureReadStatus.found => SecureReadResult.found(
        SecureIdentity(
          saveId: result.record!.saveId,
          salt: result.record!.salt,
        ),
      ),
      PlatformSecureReadStatus.absent => const SecureReadResult.absent(),
      // Mapped to a distinct outcome, never to absence. A locked-device read
      // that looked like "no identity" is how a replacement key gets minted
      // over a live save.
      PlatformSecureReadStatus.unavailable => SecureReadResult.unavailable(
        result.osStatus == null ? null : 'OSStatus ${result.osStatus}',
      ),
    };
  }

  @override
  Future<SecureWriteOutcome> create(SecureIdentity identity) async {
    final PlatformSecureWriteStatus status = await _api.createIdentity(
      PlatformIdentityRecord(saveId: identity.saveId, salt: identity.salt),
    );
    return switch (status) {
      PlatformSecureWriteStatus.created => SecureWriteOutcome.created,
      PlatformSecureWriteStatus.alreadyExists =>
        SecureWriteOutcome.alreadyExists,
      PlatformSecureWriteStatus.failed => SecureWriteOutcome.failed,
    };
  }

  @override
  Future<bool> delete() => _api.deleteIdentity();

  @override
  Future<BackupExclusionReport> applyBackupExclusions({
    required String directoryPath,
    required List<String> filePaths,
  }) async {
    final PlatformBackupExclusionReport report = await _api
        .applyBackupExclusions(directoryPath, filePaths);
    return BackupExclusionReport(
      excluded: report.excluded,
      missing: report.missing,
      failed: report.failed,
    );
  }

  @override
  Future<BackupExclusionReport> reapplyBackupExclusions(
    List<String> paths,
  ) async {
    final PlatformBackupExclusionReport report = await _api
        .reapplyBackupExclusions(paths);
    return BackupExclusionReport(
      excluded: report.excluded,
      missing: report.missing,
      failed: report.failed,
    );
  }

  @override
  Future<SecureStoreDiagnostics> readDiagnostics(List<String> paths) async {
    final PlatformSecureStoreDiagnostics d = await _api.readDiagnostics(paths);
    return SecureStoreDiagnostics(
      keychainAccessibility: d.keychainAccessibility,
      excludedPaths: d.excludedPaths,
      notExcludedPaths: d.notExcludedPaths,
      missingPaths: d.missingPaths,
    );
  }
}

/// The accessibility class the iOS implementation must configure.
///
/// Duplicated here as a string so a Dart test can assert against it without a
/// Mac, and so the simulator test and this constant fail together if either
/// side drifts. `cku` is the raw Keychain value for
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
///
/// **`ThisDeviceOnly` is the whole control.** Apple documents items with a
/// `ThisDeviceOnly` accessibility as excluded from encrypted backups and as not
/// restored to a different device, so a restored phone should find the save
/// present and the identity missing — which is the refusal.
///
/// **That is a documented behaviour this design relies on, not a verified
/// one.** What the tests prove is that the attribute on the stored item is
/// exactly this constant. Whether Apple's backup implementation then omits the
/// item cannot be observed from any API, any simulator, or any CI runner; it
/// needs two physical iPhones, an iCloud account, and a real backup and
/// restore. Do not quote the green suite as evidence of the restore behaviour.
///
/// **`AfterFirstUnlock`, not `WhenUnlocked`.** Cold-launch backfill and any
/// best-effort background wake have to read this after the first unlock since
/// boot. `WhenUnlocked` would make a pocketed-phone read fail, and a store
/// that cannot answer is only safe because the port has an `unavailable`
/// outcome — relying on that every background wake would be building on the
/// error path.
const String kExpectedKeychainAccessibility = 'cku';
