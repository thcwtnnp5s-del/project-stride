/// Storage for the reconciliation identity: the save lineage id and the origin
/// pseudonymization salt.
///
/// Separate from the save itself, and deliberately so. The salt is what turns a
/// platform's source identifiers into `StepOriginKey`s, so it has to be
/// readable *before* a save can be interpreted — and if it were inside the save
/// it could not be used to validate that save.
///
/// **Losing it is a double-grant, not a lost grant.** Every origin re-keys, so
/// recent buckets look ungranted and the live retention window would be granted
/// a second time. `totalGranted` is origin-independent, so no credit is lost.
/// Nothing downstream detects it, which is why a mismatch fails closed.
///
/// Covered by the same backup exclusions as the save. It must never be derived
/// from a device identifier, which would make it a device identifier.
library;

import 'package:meta/meta.dart';

/// The identity a save was written under.
@immutable
final class ReconciliationIdentity {
  const ReconciliationIdentity({
    required this.saveId,
    required this.saltFingerprint,
  });

  /// Opaque lineage identifier, minted by the app at new-game time.
  ///
  /// The core cannot generate one — no clock, no randomness — so it only ever
  /// compares.
  final String saveId;

  /// Non-reversing fingerprint of the pseudonymization salt.
  ///
  /// A fingerprint rather than the salt: this reaches the save envelope, and
  /// the salt itself would let any reader re-derive every origin mapping.
  final String saltFingerprint;

  @override
  bool operator ==(Object other) =>
      other is ReconciliationIdentity &&
      other.saveId == saveId &&
      other.saltFingerprint == saltFingerprint;

  @override
  int get hashCode => Object.hash(saveId, saltFingerprint);
}

/// Reads and writes the reconciliation identity.
///
/// The salt itself never crosses this boundary into `stride_core`; only its
/// fingerprint does. The adapter holds the salt and hands it to the
/// pseudonymizer.
abstract interface class ReconciliationIdentityStore {
  /// The stored identity, or null if none has been written.
  ///
  /// Never throws for absence. Absence means "new installation", which is a
  /// legitimate state; an I/O fault is not, and may throw.
  Future<ReconciliationIdentity?> read();

  /// Writes [identity] durably.
  ///
  /// Must return only once the bytes are durable. An identity that is lost
  /// after a save has been written under it fails that save closed on the next
  /// launch, which is recoverable but visible to the player.
  Future<void> write(ReconciliationIdentity identity);

  /// Removes the identity. Full reset only.
  Future<void> erase();
}
