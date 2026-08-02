// The same conformance suite, against the in-memory FaultingDevice.
//
// The suite itself lives in packages/stride_storage/lib/src/conformance.dart
// and is imported, not copied. That is the entire point: the in-memory device
// is what makes the crash matrix testable in milliseconds, and the filesystem
// adapters are what actually run on a phone. If those two ever disagreed about
// slot selection, replay, or a refusal, the fast suite would stop being
// evidence about the slow one — and the fast suite is the one everybody runs.
//
// stride_storage is a *dev* dependency here. It carries `dart:io`, so this
// import must never migrate into lib/; core purity is enforced over lib/ by
// core_purity_test.dart and Scripts/check-core-purity.sh.

import 'dart:convert';
import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';
import 'package:stride_storage/conformance.dart';

import 'content_test_support.dart';
import 'support/faulting_store.dart';

/// The reconciliation identity over a [FaultingDevice].
///
/// Deliberately byte-compatible with `FileIdentityStore`: the same JSON shape,
/// the same base64 salt, the same preference for deriving a fingerprint from a
/// salt where one exists. A memory double that stored a Dart object instead of
/// bytes would pass the privacy scan for free, and would make the equivalence
/// transcript compare two different things.
final class MemoryIdentityStore implements ReconciliationIdentityStore {
  MemoryIdentityStore(this.device);

  static const String path = 'reconciliation_identity';

  final FaultingDevice device;

  Map<String, Object?> _readJson() {
    final Uint8List? bytes = device.read(path);
    if (bytes == null || bytes.isEmpty) return const <String, Object?>{};
    return jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
  }

  void _writeJson(Map<String, Object?> json) =>
      device.write(path, Uint8List.fromList(utf8.encode(jsonEncode(json))));

  /// The app-facing write: lineage id and the salt itself.
  Future<void> writeStored({
    required String saveId,
    required Uint8List salt,
  }) async => _writeJson(<String, Object?>{
    'saveId': saveId,
    'salt': base64Encode(salt),
  });

  @override
  Future<ReconciliationIdentity?> read() async {
    final Map<String, Object?> json = _readJson();
    if (json.isEmpty) return null;

    // Prefer the salt where there is one: a fingerprint derived from the salt
    // cannot drift from it, whereas a separately stored one can.
    final Object? salt = json['salt'];
    if (salt is String) {
      return ReconciliationIdentity(
        saveId: json['saveId']! as String,
        saltFingerprint: OriginSaltPolicy.fingerprint(base64Decode(salt)),
      );
    }
    return ReconciliationIdentity(
      saveId: json['saveId']! as String,
      saltFingerprint: json['saltFingerprint']! as String,
    );
  }

  /// The core-facing write, carrying forward any salt already present.
  ///
  /// Dropping it would silently re-key every origin on the next launch, which
  /// is exactly the double-grant the fail-closed salt check exists to prevent.
  @override
  Future<void> write(ReconciliationIdentity identity) async {
    final Object? salt = _readJson()['salt'];
    _writeJson(<String, Object?>{
      'saveId': identity.saveId,
      'saltFingerprint': identity.saltFingerprint,
      if (salt is String) 'salt': salt,
    });
  }

  @override
  Future<void> erase() async => device.erase(path);
}

PersistenceFixture openMemoryFixture() {
  final FaultingDevice device = FaultingDevice();
  final MemoryIdentityStore identity = MemoryIdentityStore(device);

  return PersistenceFixture(
    snapshots: FaultingSnapshotStore(device),
    journal: FaultingJournal(device),
    identity: identity,
    readArtifacts: () async {
      // The device's durable image, read directly rather than through the
      // ports, so this fixture answers the same question the filesystem one
      // does: what is actually on the medium.
      final Map<String, Uint8List> found = <String, Uint8List>{};
      void take(String role, String path) {
        final Uint8List? bytes = device.committedBytes(path);
        if (bytes != null) found[role] = bytes;
      }

      take(ArtifactRole.slotA, SnapshotSlot.a.fileName);
      take(ArtifactRole.slotB, SnapshotSlot.b.fileName);
      take(ArtifactRole.journal, FaultingJournal.path);
      take(ArtifactRole.sidecar, FaultingJournal.sidecar);
      take(ArtifactRole.identity, MemoryIdentityStore.path);
      return found;
    },
    seedIdentity: (String saveId, Uint8List salt) =>
        identity.writeStored(saveId: saveId, salt: salt),
    teardown: () {},
  );
}

void main() {
  final ContentRegistry registry = loadProduction(
    productionSource,
  ).requireRegistry;

  runPersistenceConformance(
    name: 'in-memory',
    registry: registry,
    open: openMemoryFixture,
  );
}
