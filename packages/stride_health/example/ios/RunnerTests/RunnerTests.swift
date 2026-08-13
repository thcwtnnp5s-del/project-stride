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
/// What it does not prove: anything about real HealthKit. `HealthKitStepStore`
/// is not exercised by a single assertion in this file or any other, because
/// there is nothing on a runner for it to read. Anchored-query drain behaviour,
/// deletion reporting, `wasUserEntered` filtering, the statistics engine's
/// per-source arithmetic, and locked-device behaviour all need a physical
/// iPhone — evidence category 6 in `DECISIONS/0014`, and simulator evidence is
/// never to be described as physical-device validation.
final class HealthKitAdapterTests: XCTestCase {

  // MARK: - Fakes

  private struct FakeSource: HealthKitStepSource {
    var available: Bool = true
    var authorization: PlatformAuthorizationState = .granted
    var reading: RawStepReading = RawStepReading()
    var authorizationError: Error?
    var readError: Error?

    var isAvailable: Bool { available }

    // The completion fires synchronously, which is what lets every test below
    // stay straight-line. The real source answers on a HealthKit queue; that
    // difference is exactly what a fake cannot exercise, and is listed among
    // the unverified properties in HealthKitStepStore.swift.
    func requestAuthorization(
      completion: @escaping (Result<PlatformAuthorizationState, Error>) -> Void
    ) {
      if let authorizationError {
        completion(.failure(authorizationError))
        return
      }
      completion(.success(authorization))
    }

    func read(
      request: PlatformSyncRequest,
      salt: Data,
      completion: @escaping (Result<RawStepReading, Error>) -> Void
    ) {
      if let readError {
        completion(.failure(readError))
        return
      }
      completion(.success(reading))
    }
  }

  /// Records what the source was handed, so boundary conversions can be
  /// asserted in both directions.
  private final class RecordingSource: HealthKitStepSource {
    var receivedRequest: PlatformSyncRequest?
    var reading: RawStepReading

    init(reading: RawStepReading = RawStepReading()) {
      self.reading = reading
    }

    var isAvailable: Bool { true }

    func requestAuthorization(
      completion: @escaping (Result<PlatformAuthorizationState, Error>) -> Void
    ) {
      completion(.success(PlatformAuthorizationState.granted))
    }

    func read(
      request: PlatformSyncRequest,
      salt: Data,
      completion: @escaping (Result<RawStepReading, Error>) -> Void
    ) {
      receivedRequest = request
      completion(.success(reading))
    }
  }

  private func request(
    cursor: FlutterStandardTypedData? = nil,
    continuation: FlutterStandardTypedData? = nil,
    rescanFloorMillis: Int64? = nil
  ) -> PlatformSyncRequest {
    PlatformSyncRequest(
      dataType: .steps,
      bucketWidthMillis: 3_600_000,
      maxRescanWindowMillis: 2_592_000_000,
      includeManualEntries: false,
      cursor: cursor,
      continuation: continuation,
      rescanFloorMillis: rescanFloorMillis
    )
  }

  /// The device identity, as the app installs it at bootstrap.
  ///
  /// Every adapter under test is keyed through this. An unkeyed adapter refuses
  /// to read at all, which is asserted separately below.
  private func keyed(_ source: HealthKitStepSource) -> HealthKitAdapter {
    let adapter = HealthKitAdapter(source: source)
    var outcome: PlatformOriginKeyingOutcome?
    adapter.installOriginKeying(
      salt: FlutterStandardTypedData(bytes: Data([1, 2, 3, 4, 5, 6, 7, 8])),
      algorithmVersion: OriginKeying.algorithmVersion
    ) { outcome = try? $0.get().outcome }
    XCTAssertEqual(outcome, .installed)
    return adapter
  }

  private func fetch(
    _ adapter: HealthKitAdapter,
    _ request: PlatformSyncRequest? = nil
  ) -> Result<PlatformSyncPage, Error> {
    var captured: Result<PlatformSyncPage, Error>!
    adapter.fetchSteps(request: request ?? self.request()) { captured = $0 }
    return captured
  }

  /// An already-keyed origin, as the adapter would have produced it.
  private func originKey(_ identifier: String) -> Data {
    OriginKeying.key(salt: Data([1, 2, 3, 4, 5, 6, 7, 8]), identifier: identifier)
  }

  private func slice(
    _ identifier: String = "com.apple.health",
    start: Int64 = 1_753_401_600_000,
    end: Int64 = 1_753_405_200_000,
    steps: Int64 = 4200
  ) -> RawStepSlice {
    RawStepSlice(
      originKey: originKey(identifier),
      startMillis: start,
      endMillis: end,
      steps: steps
    )
  }

  // MARK: - 1. Absence is a normal state, not an error

  func testUnavailableServiceReportsUnavailable() {
    let adapter = keyed(
      FakeSource(available: false, authorization: .unavailable)
    )

    var availability: PlatformAvailabilityResult?
    adapter.availability { availability = try? $0.get() }

    // Absence is a normal state the game must stay fully playable through
    // (DECISIONS/0008), not an error.
    XCTAssertEqual(availability?.available, false)
    XCTAssertEqual(availability?.reason, .serviceMissing)

    var authorization: PlatformAuthorizationResult?
    adapter.requestAuthorization { authorization = try? $0.get() }
    XCTAssertEqual(authorization?.state, .unavailable)
  }

  func testUnavailableServiceAssertsNoCompletenessAndOffersNoCursor() throws {
    let adapter = keyed(FakeSource(available: false))

    let page = try fetch(adapter).get()

    XCTAssertEqual(page.status, .unavailable)
    XCTAssertEqual(page.unavailableReason, .serviceMissing)
    // Persisting a cursor the adapter cannot stand behind would make the next
    // sync claim progress the ledger never recorded.
    XCTAssertNil(page.nextCursor)
    // And a completeness assertion made on a read that never happened would
    // settle buckets that are about to receive real data.
    XCTAssertEqual(page.completeness.kind, .partial)
  }

  // MARK: - 2. Authorization-state mapping matches the Pigeon/Dart contract

  func testAuthorizationStatesMapOneToOne() {
    for expected in PlatformAuthorizationState.allCases {
      let adapter = HealthKitAdapter(source: FakeSource(authorization: expected))

      var actual: PlatformAuthorizationState?
      adapter.requestAuthorization { actual = try? $0.get().state }

      XCTAssertEqual(
        actual, expected,
        "PlatformAuthorizationState.\(expected) must survive the boundary unchanged"
      )
    }

    // Guards against a case being added to the contract without a mapping.
    XCTAssertEqual(PlatformAuthorizationState.allCases.count, 3)
  }

  // MARK: - 3. Observations carry origin and bucket, absolutely

  func testSlicesBecomeOriginAttributedObservations() throws {
    let adapter = keyed(
      FakeSource(
        reading: RawStepReading(
          slices: [
            slice("com.apple.health", steps: 4200),
            slice("com.apple.health.watch", steps: 900),
          ],
          anchor: Data([0x01, 0x02]),
          isFinalPage: true
        )
      )
    )

    let page = try fetch(adapter).get()

    XCTAssertEqual(page.status, .incremental)
    XCTAssertEqual(page.observations.count, 2)
    // Per-origin attribution is the whole reason this contract exists. A flat
    // total cannot tell "the phone is settled through Tuesday" from "the watch
    // has been offline for a week", and that ambiguity discarded a returning
    // player's backlog once already.
    XCTAssertEqual(page.observations[0].originKey.data, originKey("com.apple.health"))
    XCTAssertEqual(
      page.observations[1].originKey.data, originKey("com.apple.health.watch"))
    XCTAssertNotEqual(
      page.observations[0].originKey.data, page.observations[1].originKey.data,
      "two sources on one device must not collide")
    XCTAssertEqual(page.observations[0].steps, 4200)
    XCTAssertNil(page.rescan)

    // And the key is a key, not a name. Eight bytes, and nothing recognisable.
    for observation in page.observations {
      XCTAssertEqual(observation.originKey.data.count, 8)
      XCTAssertNil(
        String(data: observation.originKey.data, encoding: .utf8)
          .flatMap { $0.contains("apple") ? $0 : nil },
        "an origin key must not contain the identifier it came from")
    }
  }

  // MARK: - 3a. Origin keying: the identity is the app's, and it fails closed

  func testReadingWithoutTheDeviceIdentityIsRefused() throws {
    // Fail-closed. Observations keyed under no salt would re-key every origin,
    // and a re-keyed origin looks exactly like a new device: its recent buckets
    // look ungranted and the whole retention window is granted a second time.
    // Nothing detects that.
    let adapter = HealthKitAdapter(
      source: FakeSource(reading: RawStepReading(slices: [slice()], isFinalPage: true))
    )

    let page = try fetch(adapter).get()

    XCTAssertEqual(page.status, .unavailable)
    XCTAssertEqual(page.unavailableReason, .originKeyingUnconfigured)
    XCTAssertTrue(page.observations.isEmpty)
  }

  func testAMismatchedAlgorithmVersionIsRefusedRatherThanAbsorbed() {
    // A silent fallback produces keys nothing else on the device agrees with,
    // which is indistinguishable from a new device.
    let adapter = HealthKitAdapter(source: FakeSource())

    var outcome: PlatformOriginKeyingOutcome?
    adapter.installOriginKeying(
      salt: FlutterStandardTypedData(bytes: Data([1, 2, 3])),
      algorithmVersion: 9999
    ) { outcome = try? $0.get().outcome }

    XCTAssertEqual(outcome, .unsupportedAlgorithm)
  }

  func testAnEmptySaltIsRefused() {
    // An empty salt makes every origin key a bare unkeyed digest of a bundle
    // identifier, reversible by anyone holding a list of bundle identifiers.
    let adapter = HealthKitAdapter(source: FakeSource())

    var outcome: PlatformOriginKeyingOutcome?
    adapter.installOriginKeying(
      salt: FlutterStandardTypedData(bytes: Data()),
      algorithmVersion: OriginKeying.algorithmVersion
    ) { outcome = try? $0.get().outcome }

    XCTAssertEqual(outcome, .rejected)
  }

  func testForgettingTheIdentityReturnsTheAdapterToFailClosed() throws {
    // The salt is held for the lifetime of the engine attachment and dropped on
    // detach. That is what makes "in memory only" true rather than intended.
    let adapter = keyed(FakeSource())
    adapter.forgetOriginKeying()

    XCTAssertEqual(try fetch(adapter).get().unavailableReason, .originKeyingUnconfigured)
  }

  // The cross-platform key vectors are asserted in `OriginKeyVectorTests`,
  // which READS `packages/stride_health/test_fixtures/origin_key_vectors.json`
  // rather than transcribing it.
  //
  // They used to be transcribed here, as a Swift array of expected bytes. That
  // is a second copy of a canonical value, and a second copy is a chance to
  // drift — a drift that re-keys every origin, makes every device look new, and
  // grants the whole retention window a second time, silently. The fixture is
  // the one copy; three languages read it.

  func testTheEmptyIdentifierIsZeroBytesNotEightZeroBytes() {
    // Zero bytes is the wire's "no source reported". Eight zero bytes would be
    // an ordinary key the hash could produce, and conflating the two would make
    // "no source" collide with a real one.
    XCTAssertEqual(
      OriginKeying.key(salt: Data([1, 2, 3]), identifier: ""), Data())
  }

  func testADeletionIsAnAbsoluteZeroRatherThanASeparateFigure() throws {
    // There is deliberately no `deletedSteps` on this contract. A deletion is a
    // restatement of zero, which is why replay, correction, deletion, and
    // overlap are one code path in the core rather than four.
    let adapter = keyed(
      FakeSource(
        reading: RawStepReading(slices: [slice(steps: 0)], isFinalPage: true)
      )
    )

    let page = try fetch(adapter).get()

    XCTAssertEqual(page.observations.count, 1)
    XCTAssertEqual(page.observations[0].steps, 0)
  }

  func testAnEmptyReadingIsNoChangeRatherThanAnEmptyIncremental() throws {
    let adapter = keyed(
      FakeSource(reading: RawStepReading(isFinalPage: true))
    )

    XCTAssertEqual(try fetch(adapter).get().status, .noChange)
  }

  // MARK: - 4. Completeness is never asserted on a non-final page

  func testCompletenessIsSuppressedOnANonFinalPage() throws {
    // The 55,200-step defect in contract form: page one of nine must not look
    // like page nine of nine. The mapping refuses to forward the assertion at
    // all, and the Dart bridge downgrades it a second time if a future adapter
    // sends one anyway.
    let adapter = keyed(
      FakeSource(
        reading: RawStepReading(
          slices: [slice()],
          isFinalPage: false,
          continuation: Data([0xAB]),
          completeThroughMillis: 1_753_405_200_000
        )
      )
    )

    let page = try fetch(adapter).get()

    XCTAssertFalse(page.pagination.isFinalPage)
    XCTAssertEqual(page.completeness.kind, .partial)
    XCTAssertEqual(page.pagination.continuation?.data, Data([0xAB]))
  }

  func testCompletenessSurvivesOnAFinalPageWithItsScope() throws {
    let adapter = keyed(
      FakeSource(
        reading: RawStepReading(
          slices: [slice()],
          isFinalPage: true,
          completeThroughMillis: 1_753_405_200_000,
          scopeIsAllOrigins: false,
          scopedOriginKeys: [Data([0x41, 0x09, 0x1b, 0x75, 0x22, 0x09, 0xa5, 0x34])],
          intervalStartMillis: 1_753_401_600_000,
          intervalEndMillis: 1_753_405_200_000,
          queryGeneration: 7
        )
      )
    )

    let page = try fetch(adapter).get()

    XCTAssertEqual(page.completeness.kind, .completeThrough)
    XCTAssertEqual(page.completeness.throughMillis, 1_753_405_200_000)
    XCTAssertEqual(page.completeness.scope.kind, .someOrigins)
    XCTAssertEqual(
      page.completeness.scope.originKeys.map { $0.data },
      [Data([0x41, 0x09, 0x1b, 0x75, 0x22, 0x09, 0xa5, 0x34])])
    // An assertion made under an anchor that has since been invalidated is
    // stale; the generation is what lets the core notice.
    XCTAssertEqual(page.completeness.queryGeneration, 7)
  }

  func testAFinalPageOffersNoContinuation() throws {
    let adapter = keyed(
      FakeSource(
        reading: RawStepReading(isFinalPage: true, continuation: Data([0xFF]))
      )
    )

    // A continuation on a drained read would send the caller round again.
    XCTAssertNil(try fetch(adapter).get().pagination.continuation)
  }

  // MARK: - 4b. A candidate cursor is offered only on the final page

  /// The first physical-iPhone sync drained in eight pages and reported seven
  /// `cursorOfferedWhenProhibited` faults — one per non-final page.
  ///
  /// Nothing durable moved: the Dart bridge refused all seven and only the
  /// eighth cursor reached `StepCheckpointAuthorized`. The defect was that the
  /// adapter OFFERED at all. `HKAnchoredObjectQuery` hands back one updated
  /// anchor per page and it was assigned to both the continuation and the
  /// candidate cursor; as a continuation it is correct mid-read, as a cursor it
  /// claims the whole read is done.
  ///
  /// Every earlier test that supplied an anchor also declared its page final,
  /// which is why the suite was green through eight real pages of the defect.
  /// This one is explicitly mid-read.
  func testNonFinalPagesOfferNoCandidateCursor() throws {
    let anchor = Data([0xDE, 0xAD, 0xBE, 0xEF])
    let adapter = keyed(
      FakeSource(
        reading: RawStepReading(
          slices: [slice()],
          anchor: anchor,
          isFinalPage: false,
          continuation: anchor
        )
      )
    )

    let page = try fetch(adapter).get()

    XCTAssertNil(
      page.nextCursor,
      "a non-final page must offer no candidate cursor: pages remain outstanding")
    // The same bytes are still legal as in-flight read state. The point is that
    // the two fields mean different things, not that the anchor is unusable.
    XCTAssertEqual(page.pagination.continuation?.data, anchor)
    XCTAssertFalse(page.pagination.isFinalPage)
  }

  /// The eight-page shape from the device, asserted page by page.
  ///
  /// Seven non-final pages then a drained one — exactly the delivery that
  /// produced seven faults. The candidate must appear on the last page and
  /// nowhere else, or the fix has only moved the problem.
  func testAnEightPageDeliveryOffersTheCandidateOnlyOnTheFinalPage() throws {
    let anchors: [Data] = (0..<8).map { Data([0xA0, UInt8($0)]) }
    var offeredOn: [Int] = []

    for index in 0..<8 {
      let isFinal = index == 7
      let adapter = keyed(
        FakeSource(
          reading: RawStepReading(
            slices: [slice()],
            anchor: anchors[index],
            isFinalPage: isFinal,
            continuation: isFinal ? nil : anchors[index],
            completeThroughMillis: isFinal ? Int64(1_753_405_200_000) : nil,
            scopedOriginKeys: [originKey("com.apple.health")],
            intervalStartMillis: 1_753_401_600_000,
            intervalEndMillis: 1_753_405_200_000,
            pageIndex: Int64(index)
          )
        )
      )

      let page = try fetch(adapter).get()
      if page.nextCursor != nil { offeredOn.append(index) }

      if isFinal {
        XCTAssertEqual(page.nextCursor?.data, anchors[index])
        XCTAssertNil(page.pagination.continuation)
        XCTAssertEqual(page.completeness.kind, .completeThrough)
      } else {
        XCTAssertNil(page.nextCursor)
        XCTAssertEqual(page.pagination.continuation?.data, anchors[index])
        // Unchanged by this fix, and asserted here so a future change cannot
        // trade one non-final leak for the other.
        XCTAssertEqual(page.completeness.kind, .partial)
      }
    }

    XCTAssertEqual(
      offeredOn, [7],
      "exactly one candidate cursor per eight-page read, on the drained page")
  }

  /// A quiet mid-read page is the same rule.
  ///
  /// `noChange` is the one kind `authorizeCursor` lets through on a final page
  /// regardless of completeness, which makes it the kind where a non-final leak
  /// would be least visible.
  func testANonFinalNoChangePageOffersNoCandidateCursor() throws {
    let adapter = keyed(
      FakeSource(
        reading: RawStepReading(
          anchor: Data([0x01, 0x02]),
          isFinalPage: false,
          continuation: Data([0x01, 0x02])
        )
      )
    )

    let page = try fetch(adapter).get()

    XCTAssertEqual(page.status, .noChange)
    XCTAssertNil(page.nextCursor)
  }

  // MARK: - 5. Recovery: invalidated cursors carry a window and no anchor

  func testInvalidatedResponseCarriesRescanAndAuthoritativeObservations() throws {
    let rescan = PlatformRescanWindow(
      startMillis: 1_753_000_000_000,
      endMillis: 1_754_000_000_000,
      truncated: false
    )
    let adapter = keyed(
      FakeSource(
        reading: RawStepReading(
          slices: [slice(steps: 42_000)],
          anchor: Data([0xFF]),
          invalidated: true,
          rescan: rescan,
          isFinalPage: true,
          completeThroughMillis: 1_754_000_000_000
        )
      )
    )

    let page = try fetch(adapter).get()

    XCTAssertEqual(page.status, .cursorInvalidated)
    XCTAssertEqual(page.rescan?.endMillis, 1_754_000_000_000)
    XCTAssertEqual(page.observations[0].steps, 42_000)
    // A recovery's authority stops at the window it could actually reach, which
    // is a different claim from ordinary completeness.
    XCTAssertEqual(page.completeness.kind, .recoveryCompleteThrough)
    // No replacement anchor until recovery has been committed to the ledger.
    // Persisting early is what makes an interrupted recovery unrecoverable.
    XCTAssertNil(page.nextCursor)
  }

  func testATruncatedRescanIsFlagged() throws {
    let adapter = keyed(
      FakeSource(
        reading: RawStepReading(
          invalidated: true,
          rescan: PlatformRescanWindow(
            startMillis: 1_751_400_000_000,
            endMillis: 1_754_000_000_000,
            truncated: true
          ),
          isFinalPage: true
        )
      )
    )

    // Steps in the unreachable gap are recorded and never granted: they cannot
    // be distinguished from steps already counted, and inventing progress is
    // worse than missing it. The Dart bridge forces partial completeness here.
    XCTAssertEqual(try fetch(adapter).get().rescan?.truncated, true)
  }

  // MARK: - 6. Cursor bytes pass through the typed Pigeon boundary

  func testOutboundCursorBytesSurviveTheBoundary() throws {
    let bytes = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x7F])
    let adapter = keyed(
      FakeSource(
        reading: RawStepReading(slices: [slice()], anchor: bytes, isFinalPage: true)
      )
    )

    XCTAssertEqual(
      try fetch(adapter).get().nextCursor?.data, bytes,
      "The cursor is opaque; every byte must survive intact or resync breaks"
    )
  }

  func testInboundRequestReachesTheSourceIntact() throws {
    let source = RecordingSource(reading: RawStepReading(isFinalPage: true))
    let adapter = keyed(source)

    _ = try fetch(
      adapter,
      request(
        cursor: FlutterStandardTypedData(bytes: Data([0x01, 0x00, 0xAB])),
        continuation: FlutterStandardTypedData(bytes: Data([0x02])),
        rescanFloorMillis: 1_753_500_000_000
      )
    ).get()

    let received = try XCTUnwrap(source.receivedRequest)
    XCTAssertEqual(received.cursor?.data, Data([0x01, 0x00, 0xAB]))
    // A continuation and a cursor are different things: one is in-flight read
    // state that is never persisted, the other is durable position that is
    // persisted only after the ledger commits.
    XCTAssertEqual(received.continuation?.data, Data([0x02]))
    XCTAssertEqual(received.rescanFloorMillis, 1_753_500_000_000)
    XCTAssertEqual(received.bucketWidthMillis, 3_600_000)
    XCTAssertFalse(received.includeManualEntries)
  }

  func testEmptyCursorIsPreservedRatherThanCoercedToNil() throws {
    let source = RecordingSource(reading: RawStepReading(isFinalPage: true))
    let adapter = keyed(source)

    _ = try fetch(
      adapter,
      request(cursor: FlutterStandardTypedData(bytes: Data()))
    ).get()

    // An empty cursor and a missing cursor mean different things: one is a
    // cursor the platform produced, the other is "never synced".
    XCTAssertEqual(source.receivedRequest?.cursor?.data, Data())
    XCTAssertNotNil(source.receivedRequest?.cursor)
  }

  // MARK: - 7. Native errors become the typed error result and do not crash

  func testReadFailureBecomesTypedFailure() {
    let adapter = keyed(
      FakeSource(readError: StrideHealthError.readFailed("store offline"))
    )

    guard case .failure(let error) = fetch(adapter) else {
      return XCTFail("A failing read must surface as .failure, not .success")
    }
    guard case StrideHealthError.readFailed(let message) = error else {
      return XCTFail("Expected the approved typed error, got \(error)")
    }
    XCTAssertEqual(message, "store offline")
  }

  func testAuthorizationFailureBecomesTypedFailure() {
    let adapter = keyed(
      FakeSource(authorizationError: StrideHealthError.unavailable)
    )

    var result: Result<PlatformAuthorizationResult, Error>?
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
    let adapter = keyed(
      FakeSource(readError: StrideHealthError.readFailed("boom"))
    )

    for _ in 0..<10 {
      _ = fetch(adapter)
    }

    XCTAssertTrue(true, "Ten consecutive failures without a trap")
  }
}
