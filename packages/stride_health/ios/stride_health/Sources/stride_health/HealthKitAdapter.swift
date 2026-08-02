import Flutter
import Foundation

/// HealthKit step reader.
///
/// ## M-2 scope
///
/// A compiling shell that satisfies the Pigeon contract and reports the
/// platform as unavailable. The real implementation is task **S-01b**.
///
/// Reporting `unavailable` is deliberate rather than throwing: it exercises the
/// same graceful-degradation path the game must handle when authorization is
/// denied, so the app stays fully playable against this shell.
///
/// ## What S-01b implements
///
/// * `HKAnchoredObjectQuery` over `stepCount`, with the anchor archived and
///   returned as the opaque cursor.
/// * `deletedObjects` handling. Deletions are information the ledger absorbs,
///   never an instruction to revoke granted progress.
/// * The `HKMetadataKeyWasUserEntered` filter, on by default.
/// * Read-only authorization. No write scope is ever requested.
/// * Opportunistic background delivery.
///
/// ## The locked-device constraint
///
/// HealthKit data is encrypted at rest and **unreadable while the device is
/// locked**. A background wake on a locked phone cannot read steps. Foreground
/// cold-launch backfill is therefore the source of truth, and background
/// delivery is an optimization that may silently never fire.
///
/// ## Cursor invalidation
///
/// HealthKit anchors do not expire, so `PlatformCursorStatus.invalidated` is
/// not expected on iOS. The rescan path is still implemented here for the case
/// of a missing or unarchivable anchor, and because cross-adapter equivalence
/// (task V-02b) requires both adapters to produce identical ledger outcomes
/// from the same logical inputs.
///
/// See `StepRescan` in stride_core and reconciliation scenario 13 in F-04.
final class HealthKitAdapter: HealthHostApi {

    func isAvailable() throws -> Bool {
        // S-01b: HKHealthStore.isHealthDataAvailable()
        return false
    }

    func requestAuthorization(
        completion: @escaping (Result<PlatformAuthorization, Error>) -> Void
    ) {
        // S-01b: read-only stepCount authorization.
        completion(.success(.unavailable))
    }

    func fetchNewSteps(
        cursor: FlutterStandardTypedData?,
        watermarkMillis: Int64?,
        completion: @escaping (Result<PlatformFetchResult, Error>) -> Void
    ) {
        // S-01b: anchored query, deletion handling, manual-entry filter.
        completion(.success(
            PlatformFetchResult(
                status: .valid,
                newSteps: 0,
                deletedSteps: 0,
                cursor: nil,
                rescan: nil
            )
        ))
    }
}
