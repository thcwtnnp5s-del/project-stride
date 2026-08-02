import Flutter
import UIKit

/// Project Stride — device-bound secure storage.
///
/// Registration and the Pigeon boundary only. The Keychain work is in
/// `KeychainIdentityStore`, the backup attribute is in `BackupExclusion`, and
/// the mapping between them and the contract is in `SecureStoreAdapter`.
///
/// See `pigeons/secure_store_api.dart` for why any of this exists: an iCloud
/// restore carries the save, the ledger and the salt together, so the salt
/// fingerprint still matches on the second device and the fail-closed origin
/// check never fires.
public class StrideSecureStorePlugin: NSObject, FlutterPlugin {

  /// Held for the life of the process, exactly as `StrideHealthPlugin` holds
  /// its adapter. Pigeon reaches the api through a handler closure, and an
  /// adapter that is deallocated turns every later call into a channel error.
  private static var adapter: SecureStoreAdapter?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let created = SecureStoreAdapter()
    adapter = created
    SecureStoreHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: created)
  }
}
