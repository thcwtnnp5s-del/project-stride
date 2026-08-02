import Flutter
import XCTest

@testable import stride_health

/// Swift unit tests for the HealthKit adapter.
///
/// **These require no HealthKit access.** Every reading is fabricated and
/// injected through `HealthKitStepSource`. That is not a compromise: an
/// interactive authorization prompt cannot be answered on a CI runner, so tests
/// needing one could never run here at all.
///
/// What this suite proves: the mapping rules, the typed-boundary conversions,
/// and that failures are reported rather than trapped.
///
/// What it does not prove: anything about real HealthKit. Anchored queries,
/// deletions, `wasUserEntered` filtering, locked-device behavior, and
/// background delivery need a physical iPhone — tasks S-01b and V-02b.
final class HealthKitAdapterTests: XCTestCase {

  // MARK: - Fakes

  private struct FakeSource: HealthKitStepSource {
    var available: Bool = true
    var authorization: PlatformAuthorization = .granted
    var reading: RawStepReading = RawStepReading()
    var authorizationError: Error?
    var readError: Error?

    var isAvailable: Bool { available }

    func requestAuthorization() throws -> PlatformAuthorization {
      if let authorizationError { throw authorizationError }
      return authorization
    }

    func read(cursor: Data?, watermarkMillis: Int64?) throws -> RawStepReading {
      if let readError { throw readError }
      return reading
    }
  }

  /// Records what the source was handed, so boundary conversions can be
  /// asserted in both directions.
  private final class RecordingSource: HealthKitStepSource {
    var receivedCursor: Data?
    var receivedWatermark: Int64?
    var reading: RawStepReading

    init(reading: RawStepReading = RawStepReading()) {
      self.reading = reading
    }

    var isAvailable: Bool { true }
    func requestAuthorization() throws -> PlatformAuthorization { .granted }

    func read(cursor: Data?, watermarkMillis: Int64?) throws -> RawStepReading {
      receivedCursor = cursor
      receivedWatermark = watermarkMillis
      return reading
    }
  }

  private func fetch(
    _ adapter: HealthKitAdapter,
    cursor: FlutterStandardTypedData? = nil,
    watermark: Int64? = nil
  ) -> Result<PlatformFetchResult, Error> {
    var captured: Result<PlatformFetchResult, Error>!
    adapter.fetchNewSteps(cursor: cursor, watermarkMillis: watermark) { captured = $0 }
    return captured
  }

  // MARK: - 1. Unavailable service maps to the normalized unavailable status

  func testUnavailableServiceReportsUnavailable() throws {
    let adapter = HealthKitAdapter(
      source: FakeSource(available: false, authorization: .unavailable)
    )

    XCTAssertFalse(try adapter.isAvailable())

    var authorization: PlatformAuthorization?
    adapter.requestAuthorization { authorization = try? $0.get() }

    // Absence is a normal state the game must stay fully playable through
    // (DECISIONS/0008), not an error.
    XCTAssertEqual(authorization, .unavailable)
  }

  // MARK: - 2. Authorization-state mapping matches the Pigeon/Dart contract

  func testAuthorizationStatesMapOneToOne() {
    for expected in PlatformAuthorization.allCases {
      let adapter = HealthKitAdapter(source: FakeSource(authorization: expected))

      var actual: PlatformAuthorization?
      adapter.requestAuthorization { actual = try? $0.get() }

      XCTAssertEqual(
        actual, expected,
        "PlatformAuthorization.\(expected) must survive the boundary unchanged"
      )
    }

    // Guards against a case being added to the contract without a mapping.
    XCTAssertEqual(PlatformAuthorization.allCases.count, 3)
  }

  // MARK: - 3. A normal valid response does not require a rescan

  func testValidResponseCarriesNoRescan() throws {
    let adapter = HealthKitAdapter(
      source: FakeSource(
        reading: RawStepReading(
          newSteps: 4200,
          deletedSteps: 0,
          anchor: Data([0x01, 0x02])
        )
      )
    )

    let result = try fetch(adapter).get()

    XCTAssertEqual(result.status, .valid)
    XCTAssertEqual(result.newSteps, 4200)
    // A rescan on a healthy fetch would invite reconciliation to treat an
    // absolute window total as a delta.
    XCTAssertNil(result.rescan)
  }

  func testInvalidatedResponseCarriesRescanAndZeroDelta() throws {
    let rescan = PlatformRescan(
      windowStartMillis: 1_753_000_000_000,
      windowEndMillis: 1_754_000_000_000,
      windowTotal: 42_000,
      truncated: false
    )
    let adapter = HealthKitAdapter(
      source: FakeSource(
        reading: RawStepReading(newSteps: 999, invalidated: true, rescan: rescan)
      )
    )

    let result = try fetch(adapter).get()

    XCTAssertEqual(result.status, .invalidated)
    XCTAssertEqual(result.rescan?.windowTotal, 42_000)
    // Even though the source reported 999, the delta stream is broken and the
    // figure is meaningless. Passing it through is the double-count that
    // scenario 13 exists to prevent.
    XCTAssertEqual(result.newSteps, 0)
  }

  // MARK: - 4. An unavailable response offers no cursor to persist

  func testUnavailableResponseOffersNoCursor() throws {
    let adapter = HealthKitAdapter(source: FakeSource(available: false))

    let result = try fetch(adapter).get()

    // Persisting a cursor the adapter cannot stand behind would make the next
    // sync claim progress the ledger never recorded.
    XCTAssertNil(result.cursor)
  }

  func testInvalidatedResponseOffersNoCursor() throws {
    let adapter = HealthKitAdapter(
      source: FakeSource(
        reading: RawStepReading(anchor: Data([0xFF]), invalidated: true)
      )
    )

    let result = try fetch(adapter).get()

    // No replacement cursor until recovery has been committed to the ledger.
    // Persisting early is what makes an interrupted recovery unrecoverable.
    XCTAssertNil(result.cursor)
  }

  // MARK: - 5. Cursor bytes pass through the typed Pigeon boundary

  func testOutboundCursorBytesSurviveTheBoundary() throws {
    let bytes = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x7F])
    let adapter = HealthKitAdapter(
      source: FakeSource(reading: RawStepReading(anchor: bytes))
    )

    let result = try fetch(adapter).get()

    XCTAssertEqual(
      result.cursor?.data, bytes,
      "The cursor is opaque; every byte must survive intact or resync breaks"
    )
  }

  func testInboundCursorAndWatermarkReachTheSource() throws {
    let bytes = Data([0x01, 0x00, 0xAB])
    let source = RecordingSource()
    let adapter = HealthKitAdapter(source: source)

    _ = try fetch(
      adapter,
      cursor: FlutterStandardTypedData(bytes: bytes),
      watermark: 1_753_500_000_000
    ).get()

    XCTAssertEqual(source.receivedCursor, bytes)
    XCTAssertEqual(source.receivedWatermark, 1_753_500_000_000)
  }

  func testEmptyCursorIsPreservedRatherThanCoercedToNil() throws {
    let source = RecordingSource()
    let adapter = HealthKitAdapter(source: source)

    _ = try fetch(adapter, cursor: FlutterStandardTypedData(bytes: Data())).get()

    // An empty cursor and a missing cursor mean different things: one is a
    // cursor the platform produced, the other is "never synced".
    XCTAssertEqual(source.receivedCursor, Data())
    XCTAssertNotNil(source.receivedCursor)
  }

  // MARK: - 6. Native errors become the typed error result and do not crash

  func testReadFailureBecomesTypedFailure() {
    let adapter = HealthKitAdapter(
      source: FakeSource(readError: StrideHealthError.readFailed("store offline"))
    )

    let result = fetch(adapter)

    guard case .failure(let error) = result else {
      return XCTFail("A failing read must surface as .failure, not .success")
    }
    guard case StrideHealthError.readFailed(let message) = error else {
      return XCTFail("Expected the approved typed error, got \(error)")
    }
    XCTAssertEqual(message, "store offline")
  }

  func testAuthorizationFailureBecomesTypedFailure() {
    let adapter = HealthKitAdapter(
      source: FakeSource(authorizationError: StrideHealthError.unavailable)
    )

    var result: Result<PlatformAuthorization, Error>?
    adapter.requestAuthorization { result = $0 }

    guard case .failure(let error)? = result else {
      return XCTFail("A failing authorization must surface as .failure")
    }
    XCTAssertTrue(error is StrideHealthError)
  }

  func testAFailingSourceDoesNotTrap() {
    // Reaching the end of this test is the assertion: a thrown error must be
    // reported across the boundary, never allowed to take the app down. A
    // health read that goes wrong is a normal outcome the game survives.
    let adapter = HealthKitAdapter(
      source: FakeSource(readError: StrideHealthError.readFailed("boom"))
    )

    for _ in 0..<10 {
      _ = fetch(adapter)
    }

    XCTAssertTrue(true, "Ten consecutive failures without a trap")
  }
}
