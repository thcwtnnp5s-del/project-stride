/// A scriptable [StepSyncSource] for tests and development.
///
/// This replaces `MockStepProvider`, which scripted `StepFetchResult` — the flat
/// model nothing consumed. Rewritten rather than deleted, because the thing it
/// was for is still needed and is still the right idea: the highest-severity
/// system in the project must be testable exhaustively on Windows, with no
/// device, no emulator, no health service, and no wall clock, in under a second.
///
/// Every awkward real-world case is expressible here: duplicate batches,
/// out-of-order slices, deletions, corrections that exceed what was granted,
/// multi-origin backlogs, paginated backfills, week-long absences, transport
/// errors, and an invalidated cursor. The difference from the old mock is that
/// the cases that *matter* — per-origin attribution, mid-page completeness,
/// partial delivery — are now expressible at all.
library;

import 'dart:typed_data';

import 'package:stride_core/stride_core.dart';

import 'step_sync_source.dart';

/// A [StepSyncSource] that returns a scripted sequence of answers.
final class MockStepSource implements StepSyncSource {
  MockStepSource({
    List<SyncFetch> script = const <SyncFetch>[],
    this.authorization = HealthAuthorization.granted,
    this.available = true,
  }) : _script = List<SyncFetch>.of(script);

  final List<SyncFetch> _script;

  /// What [requestAuthorization] reports. Mutable so a test can model a
  /// player who denies the sheet and later allows Steps in Settings.
  HealthAuthorization authorization;

  /// How many times the caller asked for authorization, and the order of
  /// asks and reads (`authorize` / `fetch`), so a test can assert that a fresh
  /// session asks *before* its first read.
  int authorizationRequests = 0;
  final List<String> calls = <String>[];

  /// What [availability] reports. False models Android without Health Connect
  /// installed — a normal state the game must remain fully playable through.
  final bool available;

  /// Requests the caller made, in order.
  ///
  /// Lets a test assert the caller passed a cursor only after committing the
  /// previous batch, and that it resumed a partial read with the continuation
  /// rather than the cursor. Persisting a cursor early is what makes an
  /// interrupted sync unrecoverable.
  final List<SyncRequest> requestsSeen = <SyncRequest>[];

  int _index = 0;

  /// How many reads have been served.
  int get fetchCount => _index;

  /// Whether the script has been exhausted.
  bool get isExhausted => _index >= _script.length;

  /// Appends an answer to the script after construction.
  void enqueue(SyncFetch fetch) => _script.add(fetch);

  @override
  Future<HealthAvailability> availability() async => available
      ? const HealthAvailability(available: true)
      : const HealthAvailability.unavailable(
          ProviderUnavailableReason.serviceUnavailable,
        );

  @override
  Future<HealthAuthorization> requestAuthorization() async {
    authorizationRequests++;
    calls.add('authorize');
    return authorization;
  }

  @override
  Future<SyncFetch> fetchSteps(SyncRequest request) async {
    requestsSeen.add(request);
    calls.add('fetch');

    if (isExhausted) {
      // An exhausted script yields "nothing new" rather than throwing. A test
      // that fetches more often than it scripted is usually asserting
      // idempotence, and that should read as a no-op, not as an error.
      return SyncFetch(const NoChangeSync());
    }

    return _script[_index++];
  }

  // -- Convenience constructors for common scenario shapes ------------------

  /// One origin restating one bucket. The ordinary case.
  ///
  /// [completeThroughMillis] asserts the read is drained through that instant
  /// for this one origin. Left null it is [PartialDelivery], which is the safe
  /// default and the correct value for any page the adapter has not drained.
  static SyncFetch observed(
    String originKey, {
    required int startMillis,
    required int endMillis,
    required int steps,
    String cursor = 'c',
    int? completeThroughMillis,
    int queryGeneration = 1,
  }) {
    final StepOriginKey origin = StepOriginKey(originKey);
    return SyncFetch(
      IncrementalSync(
        observations: <StepObservation>[
          StepObservation.of(
            origin: origin,
            startMillis: startMillis,
            endMillis: endMillis,
            steps: steps,
          ),
        ],
        nextCursor: SyncCursor.ofString(cursor),
        completeness: completeThroughMillis == null
            ? const PartialDelivery()
            : CompleteThrough(
                throughMillis: completeThroughMillis,
                scope: CompletenessScope(
                  dataType: HealthDataType.steps,
                  origins: SomeOrigins(<StepOriginKey>{origin}),
                  intervalStartMillis: startMillis,
                  intervalEndMillis: endMillis,
                  queryGeneration: queryGeneration,
                ),
              ),
      ),
    );
  }

  /// A deletion or a correction to nothing: the source now says this slice is
  /// empty.
  ///
  /// Note there is no separate "deleted steps" figure. A deletion is an
  /// absolute restatement of zero, which is why replay, correction, deletion,
  /// and overlap are one code path in the core rather than four.
  static SyncFetch deleted(
    String originKey, {
    required int startMillis,
    required int endMillis,
    String cursor = 'c',
  }) => observed(
    originKey,
    startMillis: startMillis,
    endMillis: endMillis,
    steps: 0,
    cursor: cursor,
  );

  /// One page of a paginated read that is **not** the last.
  ///
  /// Completeness is [PartialDelivery] and cannot be anything else — this is
  /// the shape that destroyed 55,200 steps when the core inferred completeness
  /// from the newest bucket it had been handed.
  static SyncFetch partialPage(
    String originKey, {
    required int startMillis,
    required int endMillis,
    required int steps,
    String continuation = 'next',
  }) => SyncFetch(
    IncrementalSync(
      observations: <StepObservation>[
        StepObservation.of(
          origin: StepOriginKey(originKey),
          startMillis: startMillis,
          endMillis: endMillis,
          steps: steps,
        ),
      ],
    ),
    isFinalPage: false,
    continuation: Uint8List.fromList(continuation.codeUnits),
  );

  /// An invalidated cursor carrying a bounded authoritative rescan.
  ///
  /// This is scenario 13. Health Connect can expire a changes token; HealthKit
  /// does not. The observations are the authoritative contents of the window,
  /// per origin and per bucket — never a delta, and no replacement cursor is
  /// offered until recovery has been committed to the ledger.
  static SyncFetch invalidated({
    required int windowStartMillis,
    required int windowEndMillis,
    required List<StepObservation> observations,
    bool truncated = false,
  }) => SyncFetch(
    CursorInvalidatedSync(
      window: RescanWindow(
        startMillis: windowStartMillis,
        endMillis: windowEndMillis,
        truncated: truncated,
      ),
      observations: observations,
    ),
  );

  /// The provider could not answer.
  static SyncFetch unavailable(ProviderUnavailableReason reason) =>
      SyncFetch(ProviderUnavailableSync(reason));
}
