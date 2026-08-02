import Flutter
import Foundation

/// Maps the Keychain backend and the backup-exclusion helper onto the Pigeon
/// contract.
///
/// Contains no policy. It converts and reports; every decision about *when* to
/// read, create, or refuse lives in `stride_core`'s `BootstrapCoordinator` and
/// the app's identity vault, where it is exercised by `dart test` on a machine
/// with no Apple hardware anywhere near it.
///
/// In particular, this class has no notion of "the read failed, so write a new
/// one". It cannot: `createIdentity` is `SecItemAdd` and there is no update
/// method on the contract.
final class SecureStoreAdapter: SecureStoreHostApi {

  private let backend: SecureIdentityBackend

  init(backend: SecureIdentityBackend = KeychainIdentityStore()) {
    self.backend = backend
  }

  func readIdentity(
    completion: @escaping (Result<PlatformSecureReadResult, Error>) -> Void
  ) {
    switch backend.read() {
    case .found(let record):
      completion(
        .success(
          PlatformSecureReadResult(
            status: .found,
            record: PlatformIdentityRecord(
              saveId: record.saveId,
              salt: FlutterStandardTypedData(bytes: record.salt)
            )
          )
        )
      )

    case .absent:
      // No record, no status code. A caller that saw an OSStatus here might
      // reasonably treat absence as an error condition; absence is a normal
      // state — it is what a genuinely new installation looks like.
      completion(.success(PlatformSecureReadResult(status: .absent)))

    case .unavailable(let status):
      // The status is carried for a log line only. The decision is the enum.
      completion(
        .success(
          PlatformSecureReadResult(
            status: .unavailable,
            osStatus: Int64(status)
          )
        )
      )
    }
  }

  func createIdentity(
    record: PlatformIdentityRecord,
    completion: @escaping (Result<PlatformSecureWriteStatus, Error>) -> Void
  ) {
    switch backend.create(
      SecureIdentityRecord(saveId: record.saveId, salt: record.salt.data)
    ) {
    case .created:
      completion(.success(.created))
    case .alreadyExists:
      // Reported as a distinct status rather than as success. The caller has to
      // decide what an unexpected existing identity means, and "success" would
      // let it carry on believing it had just written its own.
      completion(.success(.alreadyExists))
    case .failed:
      completion(.success(.failed))
    }
  }

  func deleteIdentity(completion: @escaping (Result<Bool, Error>) -> Void) {
    completion(.success(backend.delete()))
  }

  func applyBackupExclusions(
    directoryPath: String,
    filePaths: [String],
    completion: @escaping (Result<PlatformBackupExclusionReport, Error>) -> Void
  ) {
    let report = BackupExclusion.apply(
      directoryPath: directoryPath,
      filePaths: filePaths
    )
    completion(
      .success(
        PlatformBackupExclusionReport(
          excluded: report.excluded,
          missing: report.missing,
          failed: report.failed
        )
      )
    )
  }

  func readDiagnostics(
    paths: [String],
    completion: @escaping (Result<PlatformSecureStoreDiagnostics, Error>) -> Void
  ) {
    let inspection = BackupExclusion.inspect(paths: paths)
    completion(
      .success(
        PlatformSecureStoreDiagnostics(
          keychainAccessibility: backend.storedAccessibility(),
          excludedPaths: inspection.excluded,
          notExcludedPaths: inspection.notExcluded,
          missingPaths: inspection.missing
        )
      )
    )
  }
}
