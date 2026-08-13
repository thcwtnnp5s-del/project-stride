import Foundation
import HealthKit

/// The real HealthKit reader. Foreground only.
///
/// ===========================================================================
/// What this file is, and what it deliberately is not
/// ===========================================================================
///
/// It is the one place in the plugin that talks to `HKHealthStore`. Everything
/// it produces is a `RawStepReading` — absolute totals per `(origin, bucket)`,
/// a candidate anchor, and a completeness claim it can actually stand behind.
/// `HealthKitAdapter` maps that onto the Pigeon contract and nothing here knows
/// the contract exists beyond the request type it is handed.
///
/// It is **not** a background reader. There is no `HKObserverQuery`, no
/// `enableBackgroundDelivery`, and no background mode, and that is a scope
/// decision rather than an omission: `DECISIONS/0014` puts background
/// synchronization in S-01B, behind a real persistence coordinator. HealthKit
/// data is also encrypted at rest and unreadable while the device is locked, so
/// a background wake on a pocketed phone could not read steps anyway. Foreground
/// cold-launch backfill is the source of truth.
///
/// It is **not** a custodian of state. The archived `HKQueryAnchor` is returned
/// as a candidate and forgotten. Nothing here writes to `UserDefaults`, a file,
/// or the Keychain, and `Scripts/check-origin-privacy.sh` rejects those APIs in
/// this directory. The commit order is inviolable: adapter returns data and a
/// candidate cursor, reconciliation produces grants, the ledger and snapshot
/// commit, and only then is the cursor durable.
///
/// It is **not** a ledger. It does not decide what to grant, does not subtract,
/// and does not remember what it said last time. Collapsing HealthKit's samples
/// into one absolute figure per `(origin, bucket)` is normalization; deciding
/// what that figure is worth belongs to `stride_core`.
///
/// ===========================================================================
/// The shape of a read, and why it is two queries rather than one
/// ===========================================================================
///
/// `HKAnchoredObjectQuery` answers "what changed since this anchor". That is the
/// right question for finding *which* slices moved, and the wrong question for
/// finding *what they now contain*: it hands back the samples that were added,
/// which is a delta, and the contract requires an absolute.
///
/// So the anchored query is used only to discover the affected slices. Every
/// affected bucket is then restated by an `HKStatisticsCollectionQuery` with
/// `.cumulativeSum` and `.separateBySource`, which asks HealthKit what each
/// source's total for that bucket *is now*. A correction, an overlapping
/// re-import, a delayed addition and a deletion all come back through that
/// second query as one kind of answer, which is what makes them one code path
/// in the core rather than four.
///
/// The cost is a second query per page. The alternative — summing the added
/// samples ourselves — cannot restate a bucket it did not receive a sample for,
/// which is precisely the deletion case.
///
/// ===========================================================================
/// LIMITATION: `HKDeletedObject` carries no date and no source
/// ===========================================================================
///
/// This is a real HealthKit constraint and it is recorded here rather than
/// approximated around. When an anchored query reports a deletion it gives a
/// `uuid` and metadata. It does **not** give the deleted sample's start date,
/// end date, or originating source. So a deletion cannot be attributed to a
/// bucket or to an origin from the deletion alone.
///
/// Guessing would be the wrong move in both directions: attributing it to the
/// wrong bucket restates a slice that did not change, and skipping it leaves a
/// bucket the core still believes is full.
///
/// What this adapter does instead is bounded and honest: **any page carrying a
/// deletion escalates to an authoritative restatement of the whole retention
/// window**, per origin and per bucket, using the same statistics query. The
/// window is `PlatformSyncRequest.maxRescanWindowMillis`, so the cost is
/// bounded, and it is only paid on pages that actually carry a deletion.
/// Deletions are rare; a lost grant is permanent.
///
/// ===========================================================================
/// What no CI runner can prove about this file
/// ===========================================================================
///
/// Every line below that touches `HKHealthStore` is unverified. An interactive
/// authorization prompt cannot be answered on a runner, a simulator holds no
/// real step samples, and the simulator is never locked. Anchored-query drain
/// behaviour, `wasUserEntered` filtering, deletion reporting, and the
/// statistics engine's per-source arithmetic all need a physical iPhone
/// (evidence category 6 in `DECISIONS/0014`). The tests that do run assert the
/// mapping rules and the origin keying, which are the parts that can be
/// asserted without a device.

// MARK: - Tunables

/// The constants a reviewer will want to find in one place.
enum HealthKitReadLimits {
  /// The most objects one anchored page will carry.
  ///
  /// Finite on purpose. `HKObjectQueryNoLimit` would make a first-run backfill
  /// on a long-lived device one enormous page held entirely in memory, and
  /// would remove the only signal this API gives that a read has drained.
  static let pageObjectLimit: Int = 2_000

  /// The floor the bridge already enforces, restated so this file does not
  /// depend on the caller having done it.
  ///
  /// The privacy ruling bounds retention *length*, not resolution. Minute
  /// buckets would satisfy it as written and produce a minute-by-minute record
  /// of when the player moved.
  static let minimumBucketWidthMillis: Int64 = 3_600_000

  /// Used only when the caller sends a non-positive window.
  static let fallbackRescanWindowMillis: Int64 = 7 * 24 * 60 * 60 * 1000
}

// MARK: - UTC bucketing

/// Epoch-anchored UTC bucketing. No calendar, no day boundaries, no local time.
///
/// That is what makes daylight saving, travel across timezones, and midnight
/// into non-events. `HKStatisticsCollectionQuery` is anchored at the Unix epoch
/// for the same reason, so its interval boundaries and this floor function
/// agree by construction rather than by coincidence.
enum UtcBucket {
  static func floor(_ millis: Int64, width: Int64) -> Int64 {
    guard width > 0 else { return millis }
    let remainder = millis % width
    if remainder == 0 { return millis }
    // Swift's % keeps the sign of the dividend. Pre-epoch instants are not
    // expected here, but a floor that silently rounded the wrong way for them
    // would be a bucket boundary that disagreed with HealthKit's.
    return remainder < 0 ? millis - remainder - width : millis - remainder
  }

  static func millis(from date: Date) -> Int64 {
    return Int64((date.timeIntervalSince1970 * 1000.0).rounded())
  }

  static func date(fromMillis millis: Int64) -> Date {
    return Date(timeIntervalSince1970: Double(millis) / 1000.0)
  }
}

// MARK: - The opaque cursor

/// Turns an `HKQueryAnchor` into bytes and back.
///
/// Serializing is fine; STORING is the violation, and nothing here stores.
/// `Scripts/check-origin-privacy.sh` deliberately does not ban
/// `NSKeyedArchiver` for exactly this reason — archiving the anchor is how the
/// opaque cursor is produced in the first place.
enum QueryAnchorCodec {
  static func encode(_ anchor: HKQueryAnchor) -> Data? {
    return try? NSKeyedArchiver.archivedData(
      withRootObject: anchor, requiringSecureCoding: true)
  }

  /// Nil when the bytes are not a readable anchor — which the caller must treat
  /// as an invalidated cursor, never as "start from the beginning". Starting
  /// over silently would re-deliver the whole window as though it were new.
  static func decode(_ data: Data) -> HKQueryAnchor? {
    if data.isEmpty { return nil }
    return try? NSKeyedUnarchiver.unarchivedObject(
      ofClass: HKQueryAnchor.self, from: data)
  }
}

// MARK: - The store

final class HealthKitStepStore: HealthKitStepSource {

  private let healthStore: HKHealthStore
  private let clock: () -> Date

  /// Incremented whenever a NEW anchored read is started — not when a page of
  /// an existing read is resumed. An assertion made under an anchor that has
  /// since been replaced is stale, and the core needs to be able to see that.
  ///
  /// In-memory read state for this engine attachment. It is not persisted and
  /// it is not a cursor; it is only ever compared for equality.
  private var generation: Int64 = 0

  /// Zero-based index within the current read. Diagnostic only — the bridge
  /// never does arithmetic on it — but a page number that is always zero is a
  /// page number that tells a reviewer nothing.
  private var pageIndex: Int64 = 0

  init(healthStore: HKHealthStore = HKHealthStore(), clock: @escaping () -> Date = { Date() }) {
    self.healthStore = healthStore
    self.clock = clock
  }

  var isAvailable: Bool {
    return HKHealthStore.isHealthDataAvailable()
  }

  /// The one type this adapter reads. Read-only, steps only.
  ///
  /// Nothing here asks to share, and nothing here asks for distance, workouts,
  /// or heart data. A step-completeness assertion must never be silently
  /// widened to cover data this adapter never read.
  private var stepQuantityType: HKQuantityType? {
    return HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)
  }

  // MARK: - Authorization

  /// Requests read-only step authorization.
  ///
  /// **HealthKit deliberately does not tell an app whether a READ was granted**,
  /// and this function does not pretend otherwise. `authorizationStatus(for:)`
  /// reports share permission, not read permission, and a denied read returns an
  /// empty result set rather than an error — precisely so an app cannot infer
  /// that a user has no data by watching for a refusal.
  ///
  /// So `granted` here means "the request completed", not "reads will return
  /// data". The game treats granted and denied identically, and nothing about a
  /// missing permission blocks a screen, a craft, or a fight.
  func requestAuthorization(
    completion: @escaping (Result<PlatformAuthorizationState, Error>) -> Void
  ) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(.success(PlatformAuthorizationState.unavailable))
      return
    }
    guard let quantityType = stepQuantityType else {
      completion(.success(PlatformAuthorizationState.unavailable))
      return
    }

    let readTypes: Set<HKObjectType> = [quantityType]
    healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: readTypes) {
      (completed: Bool, error: Error?) in
      if let error = error {
        let nsError = error as NSError
        if nsError.domain == HKErrorDomain
          && (nsError.code == HKError.Code.errorAuthorizationDenied.rawValue
            || nsError.code == HKError.Code.errorAuthorizationNotDetermined.rawValue)
        {
          completion(.success(PlatformAuthorizationState.denied))
          return
        }
        // The message is a fixed string. It never carries an origin
        // identifier, a device name, or a step count.
        completion(.failure(StrideHealthError.readFailed("authorization request failed")))
        return
      }
      completion(
        .success(
          completed ? PlatformAuthorizationState.granted : PlatformAuthorizationState.denied))
    }
  }

  // MARK: - Reading

  func read(
    request: PlatformSyncRequest,
    salt: Data,
    completion: @escaping (Result<RawStepReading, Error>) -> Void
  ) {
    // HealthKit answers on its own queues. The reply is hopped back to main so
    // the Pigeon completion is invoked from one predictable place.
    let finish: (Result<RawStepReading, Error>) -> Void = { result in
      DispatchQueue.main.async { completion(result) }
    }

    guard HKHealthStore.isHealthDataAvailable() else {
      finish(.failure(StrideHealthError.unavailable))
      return
    }
    guard let quantityType = stepQuantityType else {
      finish(.failure(StrideHealthError.unavailable))
      return
    }

    // Clamped up, never down. A caller cannot talk this adapter into a
    // minute-resolution read of where the player was.
    let width: Int64 =
      request.bucketWidthMillis < HealthKitReadLimits.minimumBucketWidthMillis
      ? HealthKitReadLimits.minimumBucketWidthMillis
      : request.bucketWidthMillis
    let nowMillis = UtcBucket.millis(from: clock())

    // A continuation resumes the SAME read; a cursor starts a new one. They are
    // different things and conflating them would persist a position mid-read.
    var resumeBytes: Data?
    var resuming = false
    if let continuation = request.continuation {
      resumeBytes = continuation.data
      resuming = true
    } else if let cursor = request.cursor {
      resumeBytes = cursor.data
    }

    var anchor: HKQueryAnchor?
    if let bytes = resumeBytes {
      guard let decoded = QueryAnchorCodec.decode(bytes) else {
        // Unreadable bytes are not a transient failure — nothing will make them
        // decode — and they are not "never synced" either. Treating them as a
        // first read would re-deliver the window as though it were new. The
        // only safe answer is a bounded authoritative rescan, which the core
        // reconciles against what it has already granted.
        recover(
          quantityType: quantityType, request: request, width: width,
          nowMillis: nowMillis, salt: salt, completion: finish)
        return
      }
      anchor = decoded
    }

    if resuming {
      pageIndex += 1
    } else {
      generation += 1
      pageIndex = 0
    }
    let readGeneration = generation
    let readPageIndex = pageIndex

    // A first read is bounded to the retention window. Without a bound, a
    // long-lived device would hand back years of samples the game may not act
    // on anyway — the privacy ruling caps retention at seven days.
    var floorMillis: Int64?
    if anchor == nil {
      floorMillis = UtcBucket.floor(nowMillis - rescanWindowMillis(request), width: width)
    }

    let predicate = anchoredPredicate(request: request, floorMillis: floorMillis)
    let limit = HealthKitReadLimits.pageObjectLimit

    let query = HKAnchoredObjectQuery(
      type: quantityType,
      predicate: predicate,
      anchor: anchor,
      limit: limit
    ) {
      [weak self]
      (_: HKAnchoredObjectQuery, samples: [HKSample]?, deletedObjects: [HKDeletedObject]?,
        updatedAnchor: HKQueryAnchor?, error: Error?) in

      guard let self = self else { return }

      if let error = error {
        let nsError = error as NSError
        if nsError.domain == HKErrorDomain
          && nsError.code == HKError.Code.errorInvalidArgument.rawValue
        {
          // HealthKit refused the anchor itself. Same treatment as unreadable
          // bytes: bounded authoritative rescan, never a silent restart.
          self.recover(
            quantityType: quantityType, request: request, width: width,
            nowMillis: nowMillis, salt: salt, completion: finish)
          return
        }
        finish(.failure(StrideHealthError.readFailed("anchored step read failed")))
        return
      }

      let returnedSamples = samples ?? []
      let removals = deletedObjects ?? []
      let returnedCount = returnedSamples.count + removals.count

      // The only drain signal this API offers. Equal to the limit means "there
      // may be more", and `isFinalPage` defaults to false everywhere in this
      // project because an over-cautious partial costs a little ledger growth
      // while a wrong `true` costs a grant permanently.
      let drained = returnedCount < limit

      let candidateAnchor = updatedAnchor.flatMap { QueryAnchorCodec.encode($0) }

      // Which slices moved. A sample that straddles a boundary marks every
      // bucket it overlaps, because the restating query will re-read all of
      // them and HealthKit — not this file — decides how the sample is
      // apportioned between them.
      var affectedBuckets = Set<Int64>()
      for sample in returnedSamples {
        let sampleStart = UtcBucket.millis(from: sample.startDate)
        let sampleEnd = UtcBucket.millis(from: sample.endDate)
        let lastInstant = sampleEnd > sampleStart ? sampleEnd - 1 : sampleStart
        var bucketStart = UtcBucket.floor(sampleStart, width: width)
        let finalBucketStart = UtcBucket.floor(lastInstant, width: width)
        while bucketStart <= finalBucketStart {
          affectedBuckets.insert(bucketStart)
          bucketStart += width
        }
      }

      if removals.isEmpty && affectedBuckets.isEmpty {
        // Nothing moved. A quiet page vouches for nothing, and that is
        // deliberate: it enumerated no sources, so there is no scope it could
        // honestly name. Under-settling costs ledger growth; over-settling
        // buries a bucket a late page was about to fill.
        var reading = RawStepReading()
        // Offered only on a drained page. See the note beside the same pair of
        // assignments on the restated path below.
        reading.anchor = drained ? candidateAnchor : nil
        reading.isFinalPage = drained
        reading.continuation = drained ? nil : candidateAnchor
        reading.queryGeneration = readGeneration
        reading.pageIndex = readPageIndex
        finish(.success(reading))
        return
      }

      // A deletion carries no date and no source (see the file comment), so it
      // cannot be attributed. The whole retention window is restated instead —
      // bounded, authoritative, and only on pages that actually carry one.
      let escalated = !removals.isEmpty

      let currentBucketStart = UtcBucket.floor(nowMillis, width: width)
      let escalatedStart = UtcBucket.floor(
        nowMillis - self.rescanWindowMillis(request), width: width)
      let escalatedEnd = currentBucketStart + width
      let affectedStart = affectedBuckets.min() ?? currentBucketStart
      let affectedEnd = (affectedBuckets.max() ?? affectedStart) + width

      let windowStart: Int64 = escalated ? escalatedStart : affectedStart
      let windowEnd: Int64 = escalated ? escalatedEnd : affectedEnd
      // Nil means "restate the whole window", which is what a deletion needs
      // because it cannot say which bucket it emptied.
      let keptBuckets: Set<Int64>? = escalated ? nil : affectedBuckets

      self.restate(
        quantityType: quantityType,
        request: request,
        windowStartMillis: windowStart,
        windowEndMillis: windowEnd,
        width: width,
        keptBuckets: keptBuckets,
        salt: salt
      ) { restatement in
        switch restatement {
        case .failure(let restateError):
          finish(.failure(restateError))
        case .success(let outcome):
          let vouchedEnd: Int64 = min(windowEnd, UtcBucket.floor(nowMillis, width: width))

          var reading = RawStepReading()
          reading.slices = outcome.slices
          // ONE anchor, TWO destinations, and only one of them is legal on a
          // page that has not drained.
          //
          // `HKAnchoredObjectQuery` returns a single updated anchor per page,
          // and it is the right value for both the in-flight resume token and
          // the durable cursor — but it means different things in each. As a
          // continuation it means "carry on from here", which is true mid-read.
          // As a candidate cursor it means "you have seen everything up to
          // here", which on page one of eight is false: pages two through eight
          // have not been delivered.
          //
          // It used to be assigned to both unconditionally. `authorizeCursor`
          // refused every non-final offer and the bridge dropped it, so nothing
          // durable ever moved — but each refusal correctly raised
          // `cursorOfferedWhenProhibited`, and a first real eight-page iPhone
          // sync therefore reported seven faults against an adapter that was
          // producing exactly the right data. A fault channel that fires on
          // normal operation is a fault channel nobody reads.
          //
          // Offered only when the delivery contract permits it, which is the
          // same condition `completeThroughMillis` below is already gated on.
          // The bridge's refusal is untouched and remains the authority.
          reading.anchor = drained ? candidateAnchor : nil
          reading.invalidated = false
          reading.isFinalPage = drained
          reading.continuation = drained ? nil : candidateAnchor
          reading.scopeIsAllOrigins = false
          reading.scopedOriginKeys = outcome.originKeys
          reading.intervalStartMillis = windowStart
          reading.intervalEndMillis = vouchedEnd
          // Asserted only on a drained page, and only up to a CLOSED bucket.
          // The bucket the player is walking through right now is still
          // filling; vouching for it would settle a slice that is about to be
          // restated upward.
          var asserted: Int64?
          if drained {
            asserted = vouchedEnd
          }
          reading.completeThroughMillis = asserted
          reading.queryGeneration = readGeneration
          reading.pageIndex = readPageIndex
          finish(.success(reading))
        }
      }
    }

    healthStore.execute(query)
  }

  // MARK: - Recovery

  /// A bounded authoritative re-read, for when the cursor cannot be honoured.
  ///
  /// Not a delta and not a reset. The window is re-read per origin and per
  /// bucket, and the core reconciles those absolute figures against what it has
  /// already granted for the same slices. Granting everything rescanned would
  /// double-count; resetting the ledger would erase earned progress.
  ///
  /// No replacement anchor is offered. Persisting one before recovery has
  /// committed is what makes an interrupted recovery unrecoverable — and
  /// because recovery mutates nothing until the ledger batch commits, dying
  /// part-way through simply means the next attempt recomputes the same result.
  private func recover(
    quantityType: HKQuantityType,
    request: PlatformSyncRequest,
    width: Int64,
    nowMillis: Int64,
    salt: Data,
    completion: @escaping (Result<RawStepReading, Error>) -> Void
  ) {
    let maxWindow = rescanWindowMillis(request)
    let reachableFloor = nowMillis - maxWindow

    var startMillis = reachableFloor
    var truncated = false
    if let requestedFloor = request.rescanFloorMillis {
      if requestedFloor < reachableFloor {
        // Steps in the unreachable gap are recorded and never granted: they
        // cannot be told apart from steps already counted, and inventing
        // progress is worse than missing it. The truncation is reported.
        truncated = true
        startMillis = reachableFloor
      } else {
        startMillis = requestedFloor
      }
    }

    let windowStart = UtcBucket.floor(startMillis, width: width)
    let windowEnd = UtcBucket.floor(nowMillis, width: width) + width
    let vouchedEnd = UtcBucket.floor(nowMillis, width: width)

    generation += 1
    pageIndex = 0
    let readGeneration = generation

    restate(
      quantityType: quantityType,
      request: request,
      windowStartMillis: windowStart,
      windowEndMillis: windowEnd,
      width: width,
      keptBuckets: nil,
      salt: salt
    ) { restatement in
      switch restatement {
      case .failure(let error):
        completion(.failure(error))
      case .success(let outcome):
        var reading = RawStepReading()
        reading.slices = outcome.slices
        reading.anchor = nil
        reading.invalidated = true
        reading.rescan = PlatformRescanWindow(
          startMillis: windowStart, endMillis: windowEnd, truncated: truncated)
        reading.isFinalPage = true
        reading.continuation = nil
        reading.scopeIsAllOrigins = false
        reading.scopedOriginKeys = outcome.originKeys
        reading.intervalStartMillis = windowStart
        reading.intervalEndMillis = vouchedEnd
        // A truncated rescan covered less than it was asked to, so it vouches
        // for nothing. The bridge forces this to partial as well; both are
        // deliberate, because this is the assertion that buries steps if it is
        // wrong.
        var asserted: Int64?
        if !truncated {
          asserted = vouchedEnd
        }
        reading.completeThroughMillis = asserted
        reading.queryGeneration = readGeneration
        reading.pageIndex = 0
        completion(.success(reading))
      }
    }
  }

  // MARK: - Absolute restatement

  /// What a restatement produced: the absolute slices, and the origins it can
  /// honestly vouch for.
  struct Restatement {
    var slices: [RawStepSlice]
    var originKeys: [Data]
  }

  /// Re-reads a window and reports what each source's buckets contain NOW.
  ///
  /// `.cumulativeSum` with `.separateBySource` is the whole point: HealthKit,
  /// not this file, decides what a source's total for an interval is, so
  /// overlapping and duplicated samples are collapsed the same way the platform
  /// collapses them everywhere else.
  ///
  /// ## Why every origin is emitted for every kept bucket
  ///
  /// A bucket whose samples were all deleted has no sum for that source, and
  /// therefore no entry to iterate. Emitting only what the statistics returned
  /// would silently omit exactly the slice a deletion just emptied — and an
  /// omitted bucket is indistinguishable, inside the core, from a bucket that
  /// never changed. So the origins present anywhere in the window are crossed
  /// with the kept buckets and a missing sum becomes an explicit `steps: 0`.
  /// That is what makes "a deletion is an absolute zero" true rather than
  /// intended.
  ///
  /// The size is bounded: origins in the window multiplied by buckets in it,
  /// and the window is at most `maxRescanWindowMillis` at a resolution of at
  /// least one hour.
  private func restate(
    quantityType: HKQuantityType,
    request: PlatformSyncRequest,
    windowStartMillis: Int64,
    windowEndMillis: Int64,
    width: Int64,
    keptBuckets: Set<Int64>?,
    salt: Data,
    completion: @escaping (Result<Restatement, Error>) -> Void
  ) {
    let start = UtcBucket.date(fromMillis: windowStartMillis)
    let end = UtcBucket.date(fromMillis: windowEndMillis)

    var subpredicates: [NSPredicate] = []
    // No `strictStartDate`: a sample that straddles the window edge still
    // contributes to a bucket inside it, and dropping it would understate an
    // absolute total.
    subpredicates.append(
      HKQuery.predicateForSamples(withStart: start, end: end, options: []))
    if !request.includeManualEntries {
      subpredicates.append(manualEntryExclusion())
    }
    let predicate: NSPredicate =
      subpredicates.count == 1
      ? subpredicates[0]
      : NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)

    // Anchored at the Unix epoch and expressed in whole seconds, so the
    // interval boundaries are exactly `UtcBucket.floor`'s boundaries. A
    // calendar-derived anchor would drift across a daylight-saving change and
    // silently produce buckets that do not line up with the ones already in the
    // ledger.
    var interval = DateComponents()
    interval.second = Int(width / 1000)

    let query = HKStatisticsCollectionQuery(
      quantityType: quantityType,
      quantitySamplePredicate: predicate,
      options: [.cumulativeSum, .separateBySource],
      anchorDate: Date(timeIntervalSince1970: 0),
      intervalComponents: interval
    )

    query.initialResultsHandler = {
      (_: HKStatisticsCollectionQuery, collection: HKStatisticsCollection?, error: Error?) in

      if error != nil {
        completion(.failure(StrideHealthError.readFailed("bucket restatement failed")))
        return
      }
      guard let collection = collection else {
        completion(.success(Restatement(slices: [], originKeys: [])))
        return
      }

      // Pass one: which sources wrote anything in this window at all. Order is
      // preserved so the emitted slices and the scope are in the same order on
      // every run, which makes a diff of two pages readable.
      var orderedSources: [HKSource] = []
      var seenIdentifiers = Set<String>()
      collection.enumerateStatistics(from: start, to: end) {
        (statistics: HKStatistics, _: UnsafeMutablePointer<ObjCBool>) in
        let sources = statistics.sources ?? []
        for candidate in sources {
          let identifier = candidate.bundleIdentifier
          if seenIdentifiers.contains(identifier) { continue }
          seenIdentifiers.insert(identifier)
          orderedSources.append(candidate)
        }
      }

      // The raw identifier lives inside this loop and nowhere else. It is
      // keyed immediately, is never stored in a field, never logged, and never
      // sent — and there is no field on the Pigeon contract that could carry
      // one. `bundleIdentifier`, never a display name: a player may have called
      // their phone anything at all.
      var originKeys: [Data] = []
      var keysBySourceIndex: [Data] = []
      for candidate in orderedSources {
        let key = OriginKeying.key(salt: salt, identifier: candidate.bundleIdentifier)
        keysBySourceIndex.append(key)
        originKeys.append(key)
      }

      // Pass two: the absolute figure for every (origin, bucket) this page is
      // restating.
      var slices: [RawStepSlice] = []
      collection.enumerateStatistics(from: start, to: end) {
        (statistics: HKStatistics, _: UnsafeMutablePointer<ObjCBool>) in
        let bucketStart = UtcBucket.floor(
          UtcBucket.millis(from: statistics.startDate), width: width)
        if let kept = keptBuckets, !kept.contains(bucketStart) { return }
        if bucketStart < windowStartMillis || bucketStart >= windowEndMillis { return }

        var index = 0
        while index < orderedSources.count {
          let quantity = statistics.sumQuantity(for: orderedSources[index])
          let value = quantity?.doubleValue(for: HKUnit.count()) ?? 0.0
          var steps = Int64(value.rounded())
          if steps < 0 { steps = 0 }
          slices.append(
            RawStepSlice(
              originKey: keysBySourceIndex[index],
              startMillis: bucketStart,
              endMillis: bucketStart + width,
              steps: steps
            )
          )
          index += 1
        }
      }

      completion(.success(Restatement(slices: slices, originKeys: originKeys)))
    }

    healthStore.execute(query)
  }

  // MARK: - Predicates

  /// The predicate for the anchored discovery query.
  ///
  /// Only a manual-entry filter, plus a floor on a first read. An anchored query
  /// is bounded by its anchor rather than by dates, and adding a moving date
  /// bound to a resumed read would change what the anchor means between calls.
  private func anchoredPredicate(
    request: PlatformSyncRequest,
    floorMillis: Int64?
  ) -> NSPredicate? {
    var subpredicates: [NSPredicate] = []
    if let floorMillis = floorMillis {
      subpredicates.append(
        HKQuery.predicateForSamples(
          withStart: UtcBucket.date(fromMillis: floorMillis), end: nil, options: []))
    }
    if !request.includeManualEntries {
      subpredicates.append(manualEntryExclusion())
    }
    if subpredicates.isEmpty { return nil }
    if subpredicates.count == 1 { return subpredicates[0] }
    return NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
  }

  /// Excludes samples the player typed in by hand.
  ///
  /// The default reflects real movement, and the choice belongs to the player —
  /// `PlatformSyncRequest.includeManualEntries` carries it. The same filter is
  /// applied to the restating query, or the absolute total would disagree with
  /// the discovery that produced it.
  private func manualEntryExclusion() -> NSPredicate {
    return NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
  }

  private func rescanWindowMillis(_ request: PlatformSyncRequest) -> Int64 {
    return request.maxRescanWindowMillis > 0
      ? request.maxRescanWindowMillis
      : HealthKitReadLimits.fallbackRescanWindowMillis
  }
}
