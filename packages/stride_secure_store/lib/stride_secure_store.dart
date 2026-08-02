/// Project Stride device-bound secure storage.
///
/// The iOS Keychain identity and `NSURLIsExcludedFromBackupKey`, behind one
/// Pigeon-typed boundary and one platform-neutral port.
///
/// See `pigeons/secure_store_api.dart` for why this exists: an iCloud restore
/// carries the save, the ledger, and the salt together, so the salt fingerprint
/// still matches on the second device and the fail-closed origin check never
/// fires. `ThisDeviceOnly` Keychain items do not travel, which restores it.
library;

export 'src/fake_secure_identity_store.dart';
export 'src/keychain_identity_store.dart'
    show KeychainIdentityStore, kExpectedKeychainAccessibility;
export 'src/secure_identity_store.dart';
