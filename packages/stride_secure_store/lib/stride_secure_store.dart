/// Project Stride device-bound secure storage.
///
/// The iOS Keychain identity and `NSURLIsExcludedFromBackupKey`, behind one
/// Pigeon-typed boundary and one platform-neutral port.
///
/// See `pigeons/secure_store_api.dart` for why this exists: an iCloud restore
/// carries the save, the ledger, and the salt together, so the salt fingerprint
/// still matches on the second device and the fail-closed origin check never
/// fires. Apple documents `ThisDeviceOnly` Keychain items as not travelling,
/// which should restore it — a documented behaviour this design depends on and
/// that nothing in this repository verifies. See
/// `BACKUP_EXCLUSION_CONTRACT.md` for what is proven, by what, and what is not
/// provable without two physical iPhones.
library;

export 'src/fake_secure_identity_store.dart';
export 'src/keychain_identity_store.dart'
    show KeychainIdentityStore, kExpectedKeychainAccessibility;
export 'src/secure_identity_store.dart';
