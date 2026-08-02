import Flutter
import Foundation

/// Approved typed errors crossing the platform boundary.
///
/// Pigeon turns a `.failure` into a `PlatformException` on the Dart side. The
/// adapter must never trap: a health read that goes wrong is a normal outcome
/// the game has to survive, not a reason to take the app down.
enum StrideHealthError: Error {
  /// The platform's health service is absent or unusable.
  case unavailable
  /// The underlying store failed. Carries the message for logging only —
  /// reconciliation reacts to the failure, never to the text.
  case readFailed(String)
}

/// A raw reading, before it is mapped onto the Pigeon contract.
///
/// This type is the injectable seam. It lets every mapping rule below be tested
/// with fabricated data on a CI runner, with no HealthKit, no entitlement, and
/// no authorization prompt — which cannot be answered on a runner anyway.
struct RawStepReading {
  var newSteps: Int64 = 0
  var deletedSteps: Int64 = 0
  var anchor: Data?
  var invalidated: Bool = false
  var rescan: PlatformRescan?
}

/// Where readings come from. The production implementation talks to HealthKit;
/// tests substitute a fake.
protocol HealthKitStepSource {
  var isAvailable: Bool { get }
  func requestAuthorization() throws -> PlatformAuthorization
  func read(cursor: Data?, watermarkMillis: Int64?) throws -> RawStepReading
}

/// The real source. **M-2/M-6 scope: a shell.**
///
/// It reports the service as unavailable, which is deliberate rather than a
/// placeholder throw: it exercises the same graceful-degradation path the game
/// must handle when authorization is denied or HealthKit is absent, so the app
/// stays fully playable against it.
///
/// Task **S-01b** replaces this with `HKAnchoredObjectQuery` over `stepCount`:
/// archived anchor as the opaque cursor, `deletedObjects` handling, the
/// `HKMetadataKeyWasUserEntered` filter on by default, read-only authorization,
/// and opportunistic background delivery.
///
/// The locked-device constraint governs that work: HealthKit data is encrypted
/// at rest and unreadable while the device is locked, so a background wake on a
/// locked phone cannot read steps. Foreground cold-launch backfill is the
/// source of truth.
struct HealthKitStepStore: HealthKitStepSource {
  var isAvailable: Bool { false }

  func requestAuthorization() throws -> PlatformAuthorization {
    .unavailable
  }

  func read(cursor: Data?, watermarkMillis: Int64?) throws -> RawStepReading {
    RawStepReading()
  }
}

/// Maps a `HealthKitStepSource` onto the Pigeon contract.
///
/// Contains no reconciliation logic. It converts and reports; ledger arithmetic
/// lives in `stride_core`, where it is tested without a device.
final class HealthKitAdapter: HealthHostApi {

  private let source: HealthKitStepSource

  init(source: HealthKitStepSource = HealthKitStepStore()) {
    self.source = source
  }

  func isAvailable() throws -> Bool {
    source.isAvailable
  }

  func requestAuthorization(
    completion: @escaping (Result<PlatformAuthorization, Error>) -> Void
  ) {
    do {
      completion(.success(try source.requestAuthorization()))
    } catch {
      // Reported, never thrown past the boundary.
      completion(.failure(error))
    }
  }

  func fetchNewSteps(
    cursor: FlutterStandardTypedData?,
    watermarkMillis: Int64?,
    completion: @escaping (Result<PlatformFetchResult, Error>) -> Void
  ) {
    do {
      let reading = try source.read(
        cursor: cursor?.data,
        watermarkMillis: watermarkMillis
      )
      completion(.success(Self.map(reading)))
    } catch {
      completion(.failure(error))
    }
  }

  /// The mapping rules, isolated so they can be asserted directly.
  static func map(_ reading: RawStepReading) -> PlatformFetchResult {
    if reading.invalidated {
      // The delta stream is broken. `newSteps` must be zero here: treating a
      // rescan total as a delta is precisely the double-count scenario 13
      // exists to prevent. No replacement cursor is offered until recovery has
      // been committed to the ledger.
      return PlatformFetchResult(
        status: .invalidated,
        newSteps: 0,
        deletedSteps: reading.deletedSteps,
        cursor: nil,
        rescan: reading.rescan
      )
    }

    // A healthy incremental fetch never carries a rescan. Attaching one would
    // invite reconciliation to apply an absolute window total as a delta.
    return PlatformFetchResult(
      status: .valid,
      newSteps: reading.newSteps,
      deletedSteps: reading.deletedSteps,
      cursor: reading.anchor.map { FlutterStandardTypedData(bytes: $0) },
      rescan: nil
    )
  }
}
