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
  /// reconciliation reacts to the failure, never to the text. **Never an origin
  /// identifier, a device name, or a step count.**
  case readFailed(String)
}

/// One source's absolute total for one bucket, before it is mapped onto the
/// Pigeon contract.
///
/// ## The origin is already keyed by the time it gets here
///
/// `originKey` is eight bytes: `OriginKeying.key(salt:identifier:)` applied to
/// `HKSource.bundleIdentifier`. The raw identifier lives inside that one call
/// and is never stored in a field, logged, or sent — there is no field on the
/// Pigeon contract that could carry one.
///
/// **Never derive it from `HKSource.name`.** That is a device name, which a
/// player may have called anything at all, and which
/// `GAME_BIBLE/HEALTH_INTEGRATION` forbids persisting. Never `HKDevice.name`,
/// `.model`, or `.localIdentifier` either. `Scripts/check-origin-privacy.sh`
/// rejects those APIs in this file.
struct RawStepSlice {
  /// Eight bytes, or empty when HealthKit reported no source at all.
  var originKey: Data
  var startMillis: Int64
  var endMillis: Int64
  /// The source's CURRENT total for this slice. Absolute, never a delta. Zero
  /// means the slice is now empty — a deletion or a correction to nothing.
  var steps: Int64
}

/// The origin-keying function, and the only place a raw identifier exists.
///
/// FNV-1a, 64-bit, over `salt || 0x1F || utf8(identifier)`, rendered
/// big-endian. Keyed rather than a bare digest: an unkeyed hash of a bundle
/// identifier is trivially reversible by anyone with a list of bundle
/// identifiers, which is everyone.
///
/// **This must agree byte for byte with `lib/src/origin_pseudonymizer.dart` and
/// with the Kotlin implementation.** A divergence is silent — a re-keyed origin
/// looks exactly like a new device, its recent buckets look ungranted, and the
/// retention window is granted a second time. Assert against
/// `packages/stride_health/test/origin_key_vectors.dart`, which exists for
/// exactly this reason.
///
/// `UInt64` throughout, deliberately. `Int64` with an arithmetic shift
/// sign-extends for half of all hash values and produces a stable,
/// self-consistent, completely wrong key.
enum OriginKeying {
  /// The scheme implemented here. Must match `originKeyingAlgorithmVersion` in
  /// `lib/src/origin_pseudonymizer.dart`.
  static let algorithmVersion: Int64 = 1

  static func key(salt: Data, identifier: String) -> Data {
    // Empty means "no source reported" and is ZERO bytes on the wire, not eight
    // zero bytes — those would be an ordinary key the hash could produce.
    guard !identifier.isEmpty else { return Data() }

    var hash: UInt64 = 0xcbf2_9ce4_8422_2325
    var message = Data(salt)
    message.append(0x1F)  // separator: salt‖id cannot collide with salt'‖id'
    message.append(contentsOf: Array(identifier.utf8))

    for byte in message {
      hash ^= UInt64(byte)
      hash = hash &* 0x0000_0100_0000_01b3
    }

    var out = Data(count: 8)
    for i in 0..<8 {
      out[i] = UInt8((hash >> UInt64(56 - i * 8)) & 0xFF)
    }
    return out
  }
}

/// A raw reading, before it is mapped onto the Pigeon contract.
///
/// This type is the injectable seam. It lets every mapping rule below be tested
/// with fabricated data on a CI runner, with no HealthKit, no entitlement, and
/// no authorization prompt — which cannot be answered on a runner anyway.
struct RawStepReading {
  var slices: [RawStepSlice] = []
  var anchor: Data?
  var invalidated: Bool = false
  var rescan: PlatformRescanWindow?

  /// True only when the anchored query has been drained. Defaults to false:
  /// an over-cautious partial costs a little ledger growth, and a wrong `true`
  /// costs a grant permanently.
  var isFinalPage: Bool = false
  var continuation: Data?

  /// Set only after full pagination for the declared scope. Nil means partial,
  /// which is the safe default and the correct value for every page but the
  /// last.
  var completeThroughMillis: Int64?
  var scopeIsAllOrigins: Bool = false
  /// Already-keyed origins, same rule as `RawStepSlice.originKey`.
  var scopedOriginKeys: [Data] = []
  var intervalStartMillis: Int64 = 0
  var intervalEndMillis: Int64 = 0

  /// Incremented whenever a new anchored query is started. An assertion made
  /// under an anchor that has since been invalidated is stale, and acting on it
  /// would settle buckets a rescan is about to restate.
  var queryGeneration: Int64 = 0

  /// Zero-based position within the current read. Diagnostic and cross-check
  /// only; the bridge never does arithmetic on it.
  var pageIndex: Int64 = 0
}

/// Where readings come from. The production implementation talks to HealthKit;
/// tests substitute a fake.
///
/// **Completion-based, not `throws`.** Every HealthKit query answers on its own
/// queue, and a synchronous protocol could only be satisfied by blocking the
/// platform thread on a semaphore while HealthKit worked. A foreground backfill
/// takes as long as it takes; freezing the interface for the duration is not a
/// trade this project makes for a tidier signature.
protocol HealthKitStepSource {
  var isAvailable: Bool { get }

  func requestAuthorization(
    completion: @escaping (Result<PlatformAuthorizationState, Error>) -> Void)

  /// [salt] is the device-bound identity, passed per call rather than stored on
  /// the source. The adapter owns its lifetime; a source that kept its own copy
  /// would be a second custodian of the app's identity.
  func read(
    request: PlatformSyncRequest,
    salt: Data,
    completion: @escaping (Result<RawStepReading, Error>) -> Void)
}

/// Maps a `HealthKitStepSource` onto the Pigeon contract.
///
/// Contains no reconciliation logic. It converts and reports; ledger arithmetic
/// lives in `stride_core`, where it is tested without a device.
final class HealthKitAdapter: HealthHostApi {

  private let source: HealthKitStepSource

  /// The device-bound keying salt, in memory only.
  ///
  /// Never written to `UserDefaults`, a file, or the Keychain. This plugin is a
  /// consumer of the app's identity, never a second custodian of one: a second
  /// identity would re-key every origin, and a re-keyed origin looks exactly
  /// like a new device — its recent buckets look ungranted and the whole
  /// retention window is granted again.
  private var originSalt: Data?

  init(source: HealthKitStepSource = HealthKitStepStore()) {
    self.source = source
  }

  func installOriginKeying(
    salt: FlutterStandardTypedData,
    algorithmVersion: Int64,
    completion: @escaping (Result<PlatformOriginKeyingResult, Error>) -> Void
  ) {
    guard algorithmVersion == OriginKeying.algorithmVersion else {
      // A typed refusal rather than a silent fallback. Keys that nothing else
      // on the device agrees with look exactly like a new device.
      completion(
        .success(
          PlatformOriginKeyingResult(outcome: .unsupportedAlgorithm, diagnostic: nil)))
      return
    }
    guard !salt.data.isEmpty else {
      completion(
        .success(PlatformOriginKeyingResult(outcome: .rejected, diagnostic: nil)))
      return
    }
    originSalt = salt.data
    completion(
      .success(PlatformOriginKeyingResult(outcome: .installed, diagnostic: nil)))
  }

  /// Drops the salt. Called when the engine detaches.
  func forgetOriginKeying() {
    originSalt = nil
  }

  func availability(
    completion: @escaping (Result<PlatformAvailabilityResult, Error>) -> Void
  ) {
    let available = source.isAvailable
    completion(
      .success(
        PlatformAvailabilityResult(
          available: available,
          reason: available ? nil : .serviceMissing,
          diagnostic: nil
        )
      )
    )
  }

  func requestAuthorization(
    completion: @escaping (Result<PlatformAuthorizationResult, Error>) -> Void
  ) {
    source.requestAuthorization { result in
      switch result {
      case .success(let state):
        completion(.success(PlatformAuthorizationResult(state: state, diagnostic: nil)))
      case .failure(let error):
        // Reported, never thrown past the boundary.
        completion(.failure(error))
      }
    }
  }

  func fetchSteps(
    request: PlatformSyncRequest,
    completion: @escaping (Result<PlatformSyncPage, Error>) -> Void
  ) {
    // Fail-closed, and checked before anything is read. Observations keyed
    // under no salt would re-key every origin and grant the retention window a
    // second time -- and nothing would detect it.
    guard let salt = originSalt else {
      completion(.success(Self.unavailablePage(.originKeyingUnconfigured)))
      return
    }
    guard source.isAvailable else {
      completion(.success(Self.unavailablePage(.serviceMissing)))
      return
    }
    source.read(request: request, salt: salt) { result in
      switch result {
      case .success(let reading):
        completion(.success(Self.map(reading)))
      case .failure(let error):
        // The adapter leaves its own state untouched and reports. A health read
        // that goes wrong is a normal outcome the game has to survive, not a
        // reason to take the app down.
        completion(.failure(error))
      }
    }
  }

  /// The answer when the service cannot be reached.
  ///
  /// No cursor, no rescan, `partial` completeness. Each is load-bearing: a
  /// cursor here would claim progress the ledger never recorded, and any
  /// completeness assertion would settle buckets on the strength of a read that
  /// never happened.
  static func unavailablePage(_ reason: PlatformUnavailableReason) -> PlatformSyncPage {
    PlatformSyncPage(
      status: .unavailable,
      observations: [],
      completeness: PlatformCompleteness(
        kind: .partial,
        dataType: .steps,
        scope: PlatformOriginScope(kind: .someOrigins, originKeys: []),
        intervalStartMillis: 0,
        intervalEndMillis: 0,
        queryGeneration: 0,
        throughMillis: 0
      ),
      pagination: PlatformPagination(pageIndex: 0, isFinalPage: true, continuation: nil),
      nextCursor: nil,
      rescan: nil,
      unavailableReason: reason,
      diagnostic: nil
    )
  }

  /// The mapping rules, isolated so they can be asserted directly.
  static func map(_ reading: RawStepReading) -> PlatformSyncPage {
    let observations = reading.slices.map { slice in
      PlatformStepObservation(
        originKey: FlutterStandardTypedData(bytes: slice.originKey),
        bucket: PlatformTimeBucket(
          startMillis: slice.startMillis,
          endMillis: slice.endMillis
        ),
        steps: slice.steps
      )
    }

    // A completeness assertion is only ever made on a drained final page. On
    // any other page it is `partial`, which settles nothing — page one of nine
    // looked exactly like page nine of nine under the old flat contract, and
    // that is how 55,200 steps were lost.
    let asserted = reading.isFinalPage ? reading.completeThroughMillis : nil
    let completeness = PlatformCompleteness(
      kind: asserted == nil
        ? .partial
        : (reading.invalidated ? .recoveryCompleteThrough : .completeThrough),
      dataType: .steps,
      scope: PlatformOriginScope(
        kind: reading.scopeIsAllOrigins ? .allOrigins : .someOrigins,
        originKeys: (reading.scopeIsAllOrigins ? [] : reading.scopedOriginKeys)
          .map { FlutterStandardTypedData(bytes: $0) }
      ),
      intervalStartMillis: reading.intervalStartMillis,
      intervalEndMillis: reading.intervalEndMillis,
      queryGeneration: reading.queryGeneration,
      throughMillis: asserted ?? 0
    )

    let pagination = PlatformPagination(
      pageIndex: reading.pageIndex,
      isFinalPage: reading.isFinalPage,
      continuation: reading.isFinalPage
        ? nil
        : reading.continuation.map { FlutterStandardTypedData(bytes: $0) }
    )

    if reading.invalidated {
      // The change stream is broken. The observations here are the
      // AUTHORITATIVE contents of the rescan window, per origin and per bucket
      // — never a delta. No replacement anchor is offered until recovery has
      // been committed to the ledger.
      return PlatformSyncPage(
        status: .cursorInvalidated,
        observations: observations,
        completeness: completeness,
        pagination: pagination,
        nextCursor: nil,
        rescan: reading.rescan,
        unavailableReason: nil,
        diagnostic: nil
      )
    }

    return PlatformSyncPage(
      status: observations.isEmpty ? .noChange : .incremental,
      observations: observations,
      completeness: completeness,
      pagination: pagination,
      // Returned and forgotten. Never written to UserDefaults: the caller makes
      // it durable only after the ledger and snapshot have committed.
      //
      // Gated on `isFinalPage`, like the completeness assertion above and the
      // continuation below. This field was the one of the three that was not,
      // and the omission was invisible for as long as every test that supplied
      // an anchor also said the page was final — which was every test, because
      // a fabricated reading has no reason to be mid-read unless a test says so.
      //
      // A candidate cursor on a non-final page means "you have seen everything
      // up to here" while pages remain outstanding. `authorizeCursor` refuses
      // it and always did; this stops it being OFFERED, which is what the
      // contract actually says an adapter may do.
      nextCursor: reading.isFinalPage
        ? reading.anchor.map { FlutterStandardTypedData(bytes: $0) }
        : nil,
      // A healthy fetch never carries a rescan. Attaching one would invite the
      // bridge to treat authoritative window content as ordinary incremental
      // data.
      rescan: nil,
      unavailableReason: nil,
      diagnostic: nil
    )
  }
}
