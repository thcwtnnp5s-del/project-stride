/// An in-memory [SecureIdentityStore] with explicit faults.
///
/// **Shipped in `lib/`, not in `test/`, and deliberately.** The rules this port
/// exists to enforce are ordering rules in the *app* — mint only after the save
/// has been looked for, never write after a failed read — and they can only be
/// tested from the app's package. A fake that lived in this package's `test/`
/// directory would not be importable there, and the alternative is a second
/// hand-written fake that drifts from this one.
///
/// It is never selected at runtime: nothing constructs it except a test.
library;

import 'dart:typed_data';

import 'secure_identity_store.dart';

/// Records every call, in order, so a test can assert *sequence* and not just
/// final state.
///
/// Sequence is the whole subject here. "The key was created" and "the key was
/// created before the save was looked for" are the same final state and
/// different bugs.
final class FakeSecureIdentityStore implements SecureIdentityStore {
  FakeSecureIdentityStore({SecureIdentity? initial, this.isSupported = true})
    : _stored = initial;

  SecureIdentity? _stored;

  @override
  final bool isSupported;

  /// Faults, set explicitly rather than simulated by a missing record — the
  /// distinction between "absent" and "could not tell" is exactly what must be
  /// testable.
  bool readIsUnavailable = false;
  bool createFails = false;

  /// `read`, `create`, `delete`, `applyBackupExclusions`,
  /// `reapplyBackupExclusions`, `readDiagnostics`.
  final List<String> calls = <String>[];

  /// Every identity handed to [create], including ones that were refused.
  final List<SecureIdentity> creates = <SecureIdentity>[];

  int deletes = 0;

  /// What [applyBackupExclusions] will report.
  BackupExclusionReport plannedExclusionReport = const BackupExclusionReport(
    excluded: <String>[],
    missing: <String>[],
    failed: <String>[],
  );

  /// The paths [applyBackupExclusions] was last asked to cover, directory
  /// first. A test asserts against `StorageLayout.allFiles` so a sixth file
  /// added later is caught the day it is added.
  final List<String> lastExclusionPaths = <String>[];

  /// Every [reapplyBackupExclusions] call, in order, one entry per call.
  ///
  /// A list of lists rather than a flattened set, because the assertion that
  /// matters is *per operation*: "the journal was re-excluded after the
  /// compaction that renamed a new node over it" is a different claim from
  /// "the journal appears somewhere in the paths we have ever re-excluded".
  final List<List<String>> reapplications = <List<String>>[];

  /// What [reapplyBackupExclusions] will report. Defaults to reporting every
  /// path excluded.
  BackupExclusionReport? plannedReapplicationReport;

  SecureIdentity? get stored => _stored;

  @override
  Future<SecureReadResult> read() async {
    calls.add('read');
    if (readIsUnavailable) {
      return const SecureReadResult.unavailable('fake: cannot answer');
    }
    final SecureIdentity? current = _stored;
    return current == null
        ? const SecureReadResult.absent()
        : SecureReadResult.found(current);
  }

  @override
  Future<SecureWriteOutcome> create(SecureIdentity identity) async {
    calls.add('create');
    creates.add(identity);
    if (createFails) return SecureWriteOutcome.failed;
    // Add-only, like the real one. A fake that allowed an overwrite would let
    // the very defect this port prevents pass its own test suite.
    if (_stored != null) return SecureWriteOutcome.alreadyExists;
    _stored = identity;
    return SecureWriteOutcome.created;
  }

  @override
  Future<bool> delete() async {
    calls.add('delete');
    deletes++;
    final bool had = _stored != null;
    _stored = null;
    return had;
  }

  @override
  Future<BackupExclusionReport> applyBackupExclusions({
    required String directoryPath,
    required List<String> filePaths,
  }) async {
    calls.add('applyBackupExclusions');
    lastExclusionPaths
      ..clear()
      ..add(directoryPath)
      ..addAll(filePaths);
    return plannedExclusionReport;
  }

  @override
  Future<BackupExclusionReport> reapplyBackupExclusions(
    List<String> paths,
  ) async {
    calls.add('reapplyBackupExclusions');
    reapplications.add(List<String>.of(paths));
    return plannedReapplicationReport ??
        BackupExclusionReport(
          excluded: List<String>.of(paths),
          missing: const <String>[],
          failed: const <String>[],
        );
  }

  @override
  Future<SecureStoreDiagnostics> readDiagnostics(List<String> paths) async {
    calls.add('readDiagnostics');
    return SecureStoreDiagnostics(
      keychainAccessibility: _stored == null ? null : 'cku',
      excludedPaths: paths,
    );
  }
}

/// Sixteen bytes that are not all the same, so a truncation or a fill shows up.
Uint8List fakeSalt([int seed = 1]) => Uint8List.fromList(
  List<int>.generate(16, (int i) => (i * 31 + seed) & 0xFF),
);
