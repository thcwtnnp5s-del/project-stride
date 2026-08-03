import Flutter
import Foundation
import XCTest

@testable import stride_health

/// The Swift half of the cross-platform origin-key agreement.
///
/// ===========================================================================
/// Why this reads a file instead of holding a table
/// ===========================================================================
///
/// `packages/stride_health/test_fixtures/origin_key_vectors.json` is the
/// canonical fixture. Dart, Swift and Kotlin all read THAT file at test time.
/// Nothing here transcribes an expected value, and nothing here may start to.
///
/// Three copies of a canonical value is three chances to drift, and a drift in
/// this particular value is the worst kind of silent: a re-keyed origin has no
/// `grantedSlices`, so its recent buckets look ungranted, so the whole
/// retention window is granted a second time. It looks exactly like a new
/// device. Nothing detects it, and no player-visible symptom distinguishes it
/// from a genuine new device.
///
/// If the fixture is not in the test bundle these tests FAIL rather than skip.
/// A vector suite that quietly finds no vectors is worse than no suite: it is a
/// green check mark attached to nothing, and this project has already had one
/// class of defect survive because a green run was read as verification.
///
/// ===========================================================================
/// The negative vectors, and what "eight bytes" is not
/// ===========================================================================
///
/// Eight bytes of output is NOT evidence of hashing. `My Watch` is exactly
/// eight bytes of UTF-8, and `iPhone12` is too. An adapter that shipped the
/// first eight bytes of the identifier, or a short identifier zero-padded to
/// eight, would produce a value of the right width in the right field, and the
/// wire could not tell. The negative vectors are what tells.
final class OriginKeyVectorTests: XCTestCase {

  // MARK: - The fixture

  private struct Fixture: Decodable {
    struct Vector: Decodable {
      let saltHex: String
      let identifier: String
      let expectedKeyHex: String
      let why: String
    }

    struct NegativeVector: Decodable {
      let saltHex: String
      let identifier: String
      let expectedKeyHex: String
      let why: String
      /// The identifier's own UTF-8 bytes.
      let rawUtf8Hex: String
      /// Its first eight UTF-8 bytes.
      let rawUtf8PrefixHex: String
      /// Its UTF-8 bytes zero-padded to eight.
      let rawUtf8ZeroPaddedHex: String
    }

    let algorithmVersion: Int64
    let keyLengthBytes: Int
    let coreKeyFormat: String
    let vectors: [Vector]
    let negativePrivacyVectors: [NegativeVector]
  }

  private func loadFixture() throws -> Fixture {
    let bundle = Bundle(for: OriginKeyVectorTests.self)
    let url = try XCTUnwrap(
      bundle.url(forResource: "origin_key_vectors", withExtension: "json"),
      "origin_key_vectors.json is not in the RunnerTests bundle. It is the "
        + "CANONICAL cross-platform fixture and it is wired in as a resource of "
        + "the test target. Do not fix this by transcribing the values into "
        + "Swift: that is the drift this file exists to prevent."
    )
    let data = try Data(contentsOf: url)
    let fixture = try JSONDecoder().decode(Fixture.self, from: data)

    // A suite that finds an empty fixture must fail, not pass vacuously.
    XCTAssertFalse(fixture.vectors.isEmpty, "the fixture carries no positive vectors")
    XCTAssertFalse(
      fixture.negativePrivacyVectors.isEmpty, "the fixture carries no negative vectors")
    return fixture
  }

  // MARK: - Hex helpers

  private func bytes(fromHex hex: String) -> [UInt8]? {
    if hex.isEmpty { return [] }
    if hex.count % 2 != 0 { return nil }
    var out: [UInt8] = []
    var index = hex.startIndex
    while index < hex.endIndex {
      let next = hex.index(index, offsetBy: 2)
      guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
      out.append(byte)
      index = next
    }
    return out
  }

  private func hex(_ data: Data) -> String {
    var out = ""
    for byte in data {
      out += String(format: "%02x", byte)
    }
    return out
  }

  // MARK: - 1. Every positive vector, byte for byte

  func testEveryPositiveVectorProducesExactlyTheExpectedBytes() throws {
    let fixture = try loadFixture()

    for vector in fixture.vectors {
      let salt = try XCTUnwrap(
        bytes(fromHex: vector.saltHex), "malformed saltHex in the fixture: \(vector.saltHex)")
      let expected = try XCTUnwrap(
        bytes(fromHex: vector.expectedKeyHex),
        "malformed expectedKeyHex in the fixture: \(vector.expectedKeyHex)")

      let actual = OriginKeying.key(salt: Data(salt), identifier: vector.identifier)

      XCTAssertEqual(
        Array(actual), expected,
        "vector \"\(vector.identifier)\" (\(vector.why)) must key to the shared value. "
          + "A change here re-keys every origin on every installed device, and re-grants "
          + "the retention window silently.")
    }
  }

  /// The high-byte salt is the vector that matters most, and it is worth a test
  /// of its own so a regression names itself.
  ///
  /// `Int64` with an arithmetic shift sign-extends for half of all hash values.
  /// The result is stable, self-consistent, and completely wrong — which is the
  /// hardest kind of defect to notice, because everything looks fine until a
  /// second platform disagrees.
  func testTheHighByteSaltVectorIsUnsignedThroughout() throws {
    let fixture = try loadFixture()
    let candidates = fixture.vectors.filter { $0.saltHex == "0001fe7f80ff" }
    XCTAssertFalse(
      candidates.isEmpty,
      "the high-byte salt vector has been removed from the fixture; it is the one that "
        + "catches a signed shift")

    for vector in candidates {
      let salt = try XCTUnwrap(bytes(fromHex: vector.saltHex))
      let expected = try XCTUnwrap(bytes(fromHex: vector.expectedKeyHex))
      XCTAssertEqual(
        Array(OriginKeying.key(salt: Data(salt), identifier: vector.identifier)), expected)
    }
  }

  // MARK: - 2. The algorithm version is the one this adapter implements

  func testTheAdapterImplementsTheFixtureAlgorithmVersion() throws {
    let fixture = try loadFixture()

    // A version mismatch must be a typed refusal, never a silent fallback. If
    // this ever disagrees, `installOriginKeying` starts returning
    // `unsupportedAlgorithm` on every device — a loud, recoverable failure,
    // which is the whole point of the field.
    XCTAssertEqual(
      OriginKeying.algorithmVersion, fixture.algorithmVersion,
      "Swift implements algorithm version \(OriginKeying.algorithmVersion) but the canonical "
        + "fixture is version \(fixture.algorithmVersion)")
  }

  func testAMismatchedAlgorithmVersionIsRefusedRatherThanApproximated() throws {
    let fixture = try loadFixture()
    let adapter = HealthKitAdapter(source: NullSource())

    var outcome: PlatformOriginKeyingOutcome?
    adapter.installOriginKeying(
      salt: FlutterStandardTypedData(bytes: Data([0x01, 0x02, 0x03])),
      algorithmVersion: fixture.algorithmVersion + 1
    ) { outcome = try? $0.get().outcome }

    XCTAssertEqual(outcome, PlatformOriginKeyingOutcome.unsupportedAlgorithm)
  }

  // MARK: - 3. Exactly eight bytes, or exactly zero

  func testKeyWidthIsExactlyEightBytesAndTheEmptyIdentifierIsZero() throws {
    let fixture = try loadFixture()
    XCTAssertEqual(fixture.keyLengthBytes, 8, "the fixture no longer specifies a 64-bit key")

    for vector in fixture.vectors {
      let salt = try XCTUnwrap(bytes(fromHex: vector.saltHex))
      let key = OriginKeying.key(salt: Data(salt), identifier: vector.identifier)

      if vector.identifier.isEmpty {
        // ZERO bytes, not eight zero bytes. Eight zeroes would be a legal,
        // ordinary key the hash could in principle produce, so conflating them
        // would let "no source reported" collide with a real source.
        XCTAssertEqual(
          key.count, 0,
          "the empty identifier must be zero bytes on the wire, not a key of zeroes")
      } else {
        XCTAssertEqual(
          key.count, fixture.keyLengthBytes,
          "\"\(vector.identifier)\" produced \(key.count) bytes; the wire accepts eight or none, "
            + "and any other length refuses the whole page")
      }
    }
  }

  // MARK: - 4. The core's rendering

  func testKeysRenderAsTheCoresSixteenCharacterLowercaseHex() throws {
    let fixture = try loadFixture()
    XCTAssertEqual(fixture.coreKeyFormat, "16 lowercase hexadecimal characters")

    let allowed = Set("0123456789abcdef")
    for vector in fixture.vectors where !vector.identifier.isEmpty {
      let salt = try XCTUnwrap(bytes(fromHex: vector.saltHex))
      let rendered = hex(OriginKeying.key(salt: Data(salt), identifier: vector.identifier))

      // Sixteen, never seventeen. The Dart reference once emitted a leading
      // minus sign for half of all hash values, because `int` is signed there
      // too, and `StepOriginKey` refused the result.
      XCTAssertEqual(
        rendered.count, 16,
        "\"\(vector.identifier)\" rendered \(rendered.count) characters; StepOriginKey accepts "
          + "exactly sixteen")
      XCTAssertTrue(
        rendered.allSatisfy { allowed.contains($0) },
        "\"\(vector.identifier)\" rendered \(rendered), which is not lowercase hexadecimal")
      XCTAssertEqual(
        rendered, vector.expectedKeyHex,
        "the rendered form must be the fixture's own hexadecimal, character for character")
    }
  }

  // MARK: - 5. Determinism

  func testRepeatedCallsAreStable() throws {
    let fixture = try loadFixture()

    for vector in fixture.vectors {
      let salt = try XCTUnwrap(bytes(fromHex: vector.saltHex))
      let first = OriginKeying.key(salt: Data(salt), identifier: vector.identifier)
      for _ in 0..<8 {
        // A key that varied per call would make every device look new on every
        // sync, and its whole history would be re-granted each time.
        XCTAssertEqual(
          OriginKeying.key(salt: Data(salt), identifier: vector.identifier), first,
          "\"\(vector.identifier)\" must key identically on every call")
      }
    }
  }

  // MARK: - 6. No collisions among the fixture's own inputs

  func testFixtureInputsRemainDistinct() throws {
    let fixture = try loadFixture()

    var keysByInput: [String: String] = [:]
    var inputs: [(label: String, key: String)] = []

    for vector in fixture.vectors where !vector.identifier.isEmpty {
      let salt = try XCTUnwrap(bytes(fromHex: vector.saltHex))
      let label = "\(vector.saltHex)|\(vector.identifier)"
      inputs.append(
        (label, hex(OriginKeying.key(salt: Data(salt), identifier: vector.identifier))))
    }
    for vector in fixture.negativePrivacyVectors where !vector.identifier.isEmpty {
      let salt = try XCTUnwrap(bytes(fromHex: vector.saltHex))
      let label = "\(vector.saltHex)|\(vector.identifier)"
      inputs.append(
        (label, hex(OriginKeying.key(salt: Data(salt), identifier: vector.identifier))))
    }

    for input in inputs {
      if let existing = keysByInput[input.key] {
        XCTFail(
          "\(existing) and \(input.label) collide. Two sources on one device sharing a key "
            + "means one source's settled buckets settle the other's, which is how a watch "
            + "that has been offline for a week gets its backlog discarded.")
        continue
      }
      keysByInput[input.key] = input.label
    }

    XCTAssertEqual(
      keysByInput.count, inputs.count, "the fixture's inputs must produce distinct keys")
  }

  func testTheSameSourceUnderTwoSaltsKeysDifferently() throws {
    let fixture = try loadFixture()
    let appleVectors = fixture.vectors.filter { $0.identifier == "com.apple.health" }
    XCTAssertGreaterThanOrEqual(
      appleVectors.count, 2,
      "the fixture must carry the same identifier under two salts, or nothing proves the salt "
        + "is mixed in at all and this is a bare digest")

    var seen = Set<String>()
    for vector in appleVectors {
      let salt = try XCTUnwrap(bytes(fromHex: vector.saltHex))
      seen.insert(hex(OriginKeying.key(salt: Data(salt), identifier: vector.identifier)))
    }
    XCTAssertEqual(
      seen.count, appleVectors.count,
      "an unkeyed digest of a package name is trivially reversible by anyone holding a list "
        + "of package names, which is everyone")
  }

  // MARK: - 7. Negative vectors: eight bytes is not evidence of hashing

  func testAKeyIsNeverTheIdentifierItCameFrom() throws {
    let fixture = try loadFixture()

    for vector in fixture.negativePrivacyVectors {
      let salt = try XCTUnwrap(bytes(fromHex: vector.saltHex))
      let key = OriginKeying.key(salt: Data(salt), identifier: vector.identifier)
      let rendered = hex(key)

      XCTAssertEqual(
        rendered, vector.expectedKeyHex,
        "\"\(vector.identifier)\" (\(vector.why)) must key to the shared value")

      // `My Watch` is exactly eight bytes of UTF-8. So is `iPhone12`. An
      // adapter that put the identifier itself in the field would produce
      // something of the right width, in the right field, and the wire could
      // not tell the difference.
      XCTAssertNotEqual(
        rendered, vector.rawUtf8Hex,
        "the key for \"\(vector.identifier)\" is its own UTF-8 bytes. That is not a "
          + "pseudonym, it is the device name in a byte array.")
      XCTAssertNotEqual(
        rendered, vector.rawUtf8PrefixHex,
        "the key for \"\(vector.identifier)\" is the first eight bytes of the identifier. "
          + "Truncation is not hashing.")
      XCTAssertNotEqual(
        rendered, vector.rawUtf8ZeroPaddedHex,
        "the key for \"\(vector.identifier)\" is the identifier zero-padded to eight bytes. "
          + "Padding is not hashing.")

      // And nothing recognisable survives in either direction.
      XCTAssertNil(
        String(data: key, encoding: .utf8).flatMap {
          $0 == vector.identifier ? $0 : nil
        },
        "the key for \"\(vector.identifier)\" decodes back to the identifier")
      XCTAssertFalse(
        rendered.contains(vector.rawUtf8Hex),
        "the identifier's own bytes appear inside the key for \"\(vector.identifier)\"")
    }
  }

  // MARK: - 8. Nothing raw crosses Pigeon, and nothing raw reaches a diagnostic

  func testTheObservationOnTheWireHasNoFieldARawIdentifierCouldTravelIn() {
    let observation = PlatformStepObservation(
      originKey: FlutterStandardTypedData(
        bytes: OriginKeying.key(salt: Data([0x01, 0x02, 0x03]), identifier: "Rob's iPhone")),
      bucket: PlatformTimeBucket(startMillis: 0, endMillis: 3_600_000),
      steps: 1200
    )

    // The width of the field is part of the control, but so is the absence of a
    // String. A `String` here would be an invitation, and the obvious wrong
    // value to put in one is a device name a player may have called anything.
    for child in Mirror(reflecting: observation).children {
      XCTAssertFalse(
        child.value is String,
        "PlatformStepObservation gained a String field (\(child.label ?? "unnamed")). "
          + "That reopens the channel a device name travels in.")
    }

    let scope = PlatformOriginScope(kind: .someOrigins, originKeys: [])
    for child in Mirror(reflecting: scope).children {
      XCTAssertFalse(
        child.value is String,
        "PlatformOriginScope gained a String field (\(child.label ?? "unnamed"))")
    }
  }

  func testNoOriginMaterialReachesAGeneratedDiagnostic() {
    // Diagnostics are the surface where a device identity ends up readable,
    // exportable, and outliving the app. This adapter populates none of them,
    // and the assertion is that it populates none of them — not that whatever
    // it writes happens to look harmless today.
    let identifier = "Rob's iPhone"
    let salt = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08])
    let key = OriginKeying.key(salt: salt, identifier: identifier)

    var reading = RawStepReading()
    reading.slices = [
      RawStepSlice(
        originKey: key, startMillis: 1_753_401_600_000, endMillis: 1_753_405_200_000,
        steps: 4200)
    ]
    reading.isFinalPage = true
    reading.completeThroughMillis = 1_753_405_200_000
    reading.scopedOriginKeys = [key]
    reading.intervalStartMillis = 1_753_401_600_000
    reading.intervalEndMillis = 1_753_405_200_000

    let page = HealthKitAdapter.map(reading)

    XCTAssertNil(page.diagnostic, "the adapter must not write a page diagnostic at all")

    // Pigeon generates a `description` for every value type, so a single
    // `print(page)` anywhere would render the whole page. Nothing recognisable
    // may be in it.
    let rendered = String(describing: page)
    XCTAssertFalse(rendered.contains("Rob"), "a device name reached a rendered page")
    XCTAssertFalse(rendered.contains("iPhone"), "a device name reached a rendered page")
    XCTAssertFalse(
      rendered.contains(hex(key)),
      "the origin key value reached a rendered page; a diagnostic reports that a page "
        + "happened, never who produced it")
  }

  // MARK: - A source that reads nothing

  /// Used only where a source must exist and must never be consulted.
  private struct NullSource: HealthKitStepSource {
    var isAvailable: Bool { false }

    func requestAuthorization(
      completion: @escaping (Result<PlatformAuthorizationState, Error>) -> Void
    ) {
      completion(.success(PlatformAuthorizationState.unavailable))
    }

    func read(
      request: PlatformSyncRequest,
      salt: Data,
      completion: @escaping (Result<RawStepReading, Error>) -> Void
    ) {
      completion(.success(RawStepReading()))
    }
  }
}
