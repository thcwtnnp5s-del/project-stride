/// Where the reconciliation identity actually lives, per platform.
///
/// ===========================================================================
/// The failure this file exists to close
/// ===========================================================================
///
/// F-06 stored the pseudonymization salt in a file beside the save, under the
/// same backup exclusions. On Android that is sufficient and remains what we
/// do: the app-private directory is excluded from cloud backup and device
/// transfer declaratively, `allowBackup` is false, and
/// `Scripts/check-backup-exclusions.sh` enforces it.
///
/// On iOS it was not sufficient, and the way it failed is the sharpest kind of
/// bug — a control defeated by the exact transport it was built to detect:
///
///   1. Application Support is in iCloud backup by default. There is no
///      Info.plist key or build setting that changes that.
///   2. So the save slots, the ledger journal, **and the identity file** all
///      travelled together in a restore.
///   3. On the restored second device the salt fingerprint therefore still
///      matched the fingerprint recorded in the restored snapshot envelope.
///   4. `SaveRepository._checkSalt` passed. `LoadRefusal.originKeyReset` never
///      fired. The bootstrap resumed, cleanly, reporting success.
///   5. The ledger then replayed against a HealthKit source the *original*
///      device had already consumed from.
///
/// The fail-closed check could not fire, because the evidence and the thing it
/// was meant to prove were in the same suitcase.
///
/// ===========================================================================
/// The two controls, and which does what
/// ===========================================================================
///
/// **Keychain, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.** This is
/// the control that restores the refusal. `ThisDeviceOnly` items are not in an
/// encrypted backup and are not restored onto a different device, so a restored
/// phone finds progress with no key — `originIdentityMissing`, and the game
/// blocks with a recoverable message instead of double-granting in silence.
///
/// **`NSURLIsExcludedFromBackupKey` on the directory and every declared file.**
/// This is the control that stops the ledger travelling at all. It is the
/// weaker of the two — a user can restore a device, and this is a request to
/// Apple's backup machinery rather than a property of the data — which is why
/// it is the second layer rather than the first. Re-applied on every launch,
/// because the attribute lives on the filesystem node and a recreated
/// directory silently loses it.
///
/// ===========================================================================
/// There is deliberately no file-to-Keychain migration on iOS
/// ===========================================================================
///
/// It would be a two-line change and it would reopen the hole exactly. An
/// iCloud restore carries the *file*; a migration step would read that file on
/// the second device and write it into that device's Keychain, at which point
/// the fingerprints match again and the refusal is gone. The whole value of the
/// Keychain here is that it does not travel, and importing something that did
/// travel throws that away.
///
/// This costs nothing today: no iOS build has ever been distributed
/// (DECISIONS/0011 — APK and Play internal first, TestFlight later), so there
/// is no installed base holding a file-based identity. If that ever changes,
/// the answer is still not a migration: it is one build that blocks with
/// `originIdentityMissing` and offers the health reconnect, which keeps earned
/// progress.
library;

import 'dart:convert';
import 'dart:io' show File;
import 'dart:math';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:stride_secure_store/stride_secure_store.dart';
import 'package:stride_storage/stride_storage.dart';

/// Thrown when the identity store cannot answer.
///
/// **Not absence.** The bootstrap turns this into
/// `BootstrapBlockReason.storageUnavailable` and stops, which is the whole
/// point: a Keychain read before the first unlock since boot returns
/// `errSecInteractionNotAllowed`, and a store that reported that as "no
/// identity" would send startup down the path that mints a replacement key
/// over a live save.
final class IdentityStoreUnavailable implements Exception {
  const IdentityStoreUnavailable(this.detail);

  /// A short technical note for a log line. Never player-facing.
  final String detail;

  @override
  String toString() => 'IdentityStoreUnavailable($detail)';
}

/// Thrown when a create finds an item already present.
///
/// Reached only when a read said "absent" and the create then said "exists",
/// which means something changed underneath us. The safe response is to stop:
/// there is no update path, and inventing one is the rule this whole design
/// refuses.
final class IdentityAlreadyExists implements Exception {
  const IdentityAlreadyExists();

  @override
  String toString() => 'IdentityAlreadyExists()';
}

/// The platform-specific place the identity is kept.
abstract interface class _Backend {
  Future<SecureIdentity?> read();
  Future<void> create(SecureIdentity identity);
  Future<void> erase();
  String get description;
}

/// iOS. The Keychain, through the typed platform port.
final class _KeychainBackend implements _Backend {
  const _KeychainBackend(this._store);

  final SecureIdentityStore _store;

  @override
  String get description => 'keychain';

  @override
  Future<SecureIdentity?> read() async {
    final SecureReadResult result = await _store.read();
    return switch (result.outcome) {
      SecureReadOutcome.found => result.identity,
      SecureReadOutcome.absent => null,
      SecureReadOutcome.unavailable => throw IdentityStoreUnavailable(
        result.diagnostic ?? 'the keychain could not answer',
      ),
    };
  }

  @override
  Future<void> create(SecureIdentity identity) async {
    final SecureWriteOutcome outcome = await _store.create(identity);
    switch (outcome) {
      case SecureWriteOutcome.created:
        return;
      case SecureWriteOutcome.alreadyExists:
        throw const IdentityAlreadyExists();
      case SecureWriteOutcome.failed:
        throw const IdentityStoreUnavailable('the keychain refused the write');
    }
  }

  @override
  Future<void> erase() => _store.delete();
}

/// Android and everything else. App-private file storage, which is the owner's
/// ruling: `allowBackup=false`, domain-wide data-extraction excludes for both
/// cloud backup and device transfer, and a directory that is removed with the
/// app's data.
final class _FileBackend implements _Backend {
  const _FileBackend(this._store);

  final FileIdentityStore _store;

  @override
  String get description => 'app-private file';

  @override
  Future<SecureIdentity?> read() async {
    final StoredIdentity? stored;
    try {
      stored = await _store.readStored();
    } on StorageException catch (e) {
      // A corrupt or unreadable file is a fault, never absence — the same
      // distinction the Keychain path makes, for the same reason.
      throw IdentityStoreUnavailable('$e');
    }
    if (stored == null) return null;
    return SecureIdentity(saveId: stored.saveId, salt: stored.salt);
  }

  @override
  Future<void> create(SecureIdentity identity) async {
    // Add-only, matched to the Keychain contract so both platforms refuse an
    // overwrite in the same way rather than one of them quietly allowing it.
    if (await _store.readStored() != null) throw const IdentityAlreadyExists();
    await _store.writeStored(
      StoredIdentity(saveId: identity.saveId, salt: identity.salt),
    );
  }

  @override
  Future<void> erase() => _store.erase();
}

/// The identity, resolved for this launch.
///
/// Implements the core's [ReconciliationIdentityStore], so `BootstrapCoordinator`
/// keeps every ordering decision and this class keeps none of them.
final class IdentityVault implements ReconciliationIdentityStore {
  // Positional for the private fields: a named parameter cannot begin with an
  // underscore, so an initializing formal is not expressible here.
  IdentityVault._(
    this._backend,
    this._entropy,
    this._resolved,
    this._fault, {
    required this.backupExclusion,
    required this.storageDescription,
  }) : _wasPresentAtOpen = _resolved != null;

  final _Backend _backend;
  final Random _entropy;

  /// What applying the backup exclusion achieved this launch.
  ///
  /// Reported rather than enforced. A file attribute that did not stick is bad
  /// and must be visible, but it is the *second* layer: the Keychain identity
  /// still refuses a restored ledger, and refusing to start the game over a
  /// failed `setResourceValues` would be a worse trade than saying so.
  final BackupExclusionReport backupExclusion;

  /// Which backend answered, for a diagnostic line.
  final String storageDescription;

  SecureIdentity? _resolved;
  final bool _wasPresentAtOpen;

  /// The read fault, held rather than thrown from [open].
  ///
  /// It is re-thrown from [read], which is the port method the coordinator
  /// calls — so the failure becomes
  /// `BootstrapBlockReason.storageUnavailable` and a player-legible refusal,
  /// instead of an exception escaping `bootstrapStride` as a crash. A crash and
  /// a refusal are both "the game did not open", but only one of them is a
  /// state the app can present and recover from.
  final IdentityStoreUnavailable? _fault;

  /// Opens the vault: applies backup exclusions, then reads.
  ///
  /// Exclusions first. They are idempotent and cheap, they must run whatever
  /// else happens, and running them before the read means a launch that then
  /// blocks on a missing identity has still protected the files it found.
  ///
  /// **This does not write anything.** A read that faults is captured and
  /// re-thrown from [read]; nothing here mints, and nothing here repairs.
  static Future<IdentityVault> open({
    required StorageLayout layout,
    SecureIdentityStore? secureStore,
    Random? entropy,
  }) async {
    final SecureIdentityStore secure = secureStore ?? KeychainIdentityStore();

    final _Backend backend = secure.isSupported
        ? _KeychainBackend(secure)
        : _FileBackend(FileIdentityStore(layout));

    // Applied on every launch, to the directory *and* to every file the layout
    // declares — read out of `StorageLayout.allFiles` rather than from a list
    // someone remembered, so a sixth file added later is covered the day it is
    // added rather than the day someone notices.
    //
    // Skipped where there is no platform implementation. On Android the
    // exclusion is declarative and already stronger: `allowBackup=false` plus
    // domain-wide excludes for both cloud-backup and device-transfer, checked
    // by Scripts/check-backup-exclusions.sh. Calling through to a plugin that
    // is not registered there would raise MissingPluginException on every
    // launch, for no gain.
    final BackupExclusionReport exclusion = secure.isSupported
        ? await secure.applyBackupExclusions(
            directoryPath: layout.root.path,
            filePaths: layout.allFiles.map((File f) => f.path).toList(),
          )
        : const BackupExclusionReport.notApplicable();

    SecureIdentity? existing;
    IdentityStoreUnavailable? fault;
    try {
      existing = await backend.read();
    } on IdentityStoreUnavailable catch (e) {
      // Captured, not swallowed and not thrown here. Thrown from `read`, so the
      // coordinator refuses in the same typed way it refuses everything else.
      fault = e;
    }

    return IdentityVault._(
      backend,
      entropy ?? Random.secure(),
      existing,
      fault,
      backupExclusion: exclusion,
      storageDescription: backend.description,
    );
  }

  /// Mints a candidate identity **in memory only**.
  ///
  /// Passed to `BootstrapCoordinator.run` as `mintIdentity`, and the
  /// coordinator calls it only after the save has been looked for and found
  /// absent. Nothing is durable until [write] runs.
  ///
  /// A candidate rather than a durable write, because an earlier version of the
  /// app wrote the identity before calling the coordinator — which meant the
  /// coordinator never saw `stored == null`, and the "a save survived but its
  /// identity did not" refusal was unreachable from the app.
  ReconciliationIdentity mintCandidate() {
    if (_fault != null) {
      // Unreachable through the coordinator, which refuses at `read`. Asserted
      // anyway: minting after a failed read is the one thing the ruling names
      // outright, and "the caller would never" is how it happens.
      throw StateError('refusing to mint an identity after a failed read');
    }
    final SecureIdentity candidate = SecureIdentity(
      saveId: base64Url.encode(
        List<int>.generate(12, (_) => _entropy.nextInt(256)),
      ),
      // Never derived from a device identifier, which would make it a device
      // identifier.
      salt: Uint8List.fromList(
        List<int>.generate(16, (_) => _entropy.nextInt(256)),
      ),
    );
    _resolved = candidate;
    return _public(candidate);
  }

  /// The salt for this launch's `OriginPseudonymizer`, or null if none resolved.
  ///
  /// The raw salt goes from here to that constructor and nowhere else. It never
  /// enters `stride_core`, never enters a save envelope, never reaches a
  /// diagnostic — only the fingerprint does.
  Uint8List? get salt => _resolved?.salt;

  static ReconciliationIdentity _public(SecureIdentity identity) =>
      ReconciliationIdentity(
        saveId: identity.saveId,
        saltFingerprint: OriginSaltPolicy.fingerprint(identity.salt),
      );

  /// The stored identity, or null if there is none.
  ///
  /// Throws [IdentityStoreUnavailable] when the store could not answer.
  /// **Absence and inability are different answers**, and the whole design
  /// rests on the caller being able to tell them apart: the coordinator turns
  /// null into "new installation" and the throw into a refusal.
  @override
  Future<ReconciliationIdentity?> read() async {
    final IdentityStoreUnavailable? fault = _fault;
    if (fault != null) throw fault;
    return _wasPresentAtOpen ? _public(_resolved!) : null;
  }

  /// Persists the candidate.
  ///
  /// Called by the coordinator on the new-game path only, and only after the
  /// save has been looked for. The [identity] argument is checked against the
  /// candidate rather than trusted: the salt is not representable in a
  /// `ReconciliationIdentity` — it carries a fingerprint — so writing "what we
  /// were given" is not even possible here, and a mismatch would mean the
  /// coordinator and this class disagree about which lineage is being started.
  @override
  Future<void> write(ReconciliationIdentity identity) async {
    if (_fault != null) {
      // The rule, made structural. A store that could not be read cannot be
      // written, whatever the caller believes it knows.
      throw const IdentityStoreUnavailable(
        'refusing to write after a failed read',
      );
    }
    final SecureIdentity? candidate = _resolved;
    if (candidate == null || _public(candidate) != identity) {
      throw StateError(
        'the identity vault was asked to write an identity it did not mint',
      );
    }
    if (_wasPresentAtOpen) {
      // The coordinator does not do this, but the port allows it, and an
      // adapter that silently replaced a live key on being asked would undo
      // the entire control.
      throw const IdentityAlreadyExists();
    }
    await _backend.create(candidate);
  }

  /// Full reset only, from an explicit player action. Never from a failed read.
  @override
  Future<void> erase() async {
    await _backend.erase();
    _resolved = null;
  }
}
