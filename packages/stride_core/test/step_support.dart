// Fixture builders for step reconciliation tests.
//
// Dedicated builders rather than `copyWith(eventSequence:)` — that route
// remains an F-05 concern and is deliberately not leaned on further here.

import 'package:stride_core/stride_core.dart';

import 'content_test_support.dart';

ContentRegistry get stepRegistry =>
    loadProduction(productionSource).requireRegistry;

/// A fresh engine with an empty ledger.
GameEngine newEngine() => GameEngine.newGame(registry: stepRegistry);

// Two devices, so overlap between origins is expressible.
//
// These are what a pseudonymizer actually emits. They are not readable, and
// that is the point: `StepOriginKey('phone')` no longer compiles, because a
// type that can hold "phone" can hold "Rob's iPhone" — which is a device name,
// which the privacy ruling forbids persisting.
final StepOriginKey phone = StepOriginKey('a1b2c3d4e5f60718');
final StepOriginKey watch = StepOriginKey('0f1e2d3c4b5a6978');

/// One hour, in milliseconds. Buckets are arbitrary intervals; the reconciler
/// never asks what day one falls on.
const int hour = 60 * 60 * 1000;

/// A fixed origin instant. A constant, not a clock read — the core forbids
/// reading one and the tests must not need one either.
const int t0 = 1750000000000;

/// An observation for hour [index] after [t0].
StepObservation obs(StepOriginKey origin, int index, int steps) =>
    StepObservation(
      key: ObservationKey(
        origin: origin,
        bucket: TimeBucket(
          startMillis: t0 + index * hour,
          endMillis: t0 + (index + 1) * hour,
        ),
      ),
      steps: steps,
    );

SyncCursor cursor(String name) => SyncCursor.ofString(name);

/// Builds a completeness assertion covering every origin through an hour index.
///
/// The adapter's claim: "I drained every page, for every source I can see, up
/// to here." Tests that need a narrower claim build [SomeOrigins] directly.
SyncCompleteness completeThrough(
  int index, {
  Set<StepOriginKey>? origins,
  int fromIndex = 0,
  int queryGeneration = 1,
}) => CompleteThrough(
  throughMillis: t0 + index * hour,
  scope: CompletenessScope(
    dataType: HealthDataType.steps,
    origins: origins == null ? const AllOrigins() : SomeOrigins(origins),
    intervalStartMillis: t0 + fromIndex * hour,
    intervalEndMillis: t0 + index * hour,
    queryGeneration: queryGeneration,
  ),
);

/// [completeThroughIndex] is the adapter's completeness assertion, in hour
/// indices: "I have delivered everything up to this point."
///
/// Omitting it is the safe default and means "do not compact" — which is why
/// most scenarios can ignore it entirely. Only tests that care about retention
/// need to assert completeness.
IncrementalSync incremental(
  List<StepObservation> observations, {
  String? next,
  int? completeThroughIndex,
  SyncCompleteness? completeness,
}) => IncrementalSync(
  observations: observations,
  nextCursor: next == null ? null : cursor(next),
  completeness:
      completeness ??
      (completeThroughIndex == null
          ? const PartialDelivery()
          : completeThrough(completeThroughIndex)),
);

CursorInvalidatedSync rescan(
  List<StepObservation> observations, {
  required int fromIndex,
  required int toIndex,
  bool truncated = false,
  String? next,
  int? completeThroughIndex,
}) => CursorInvalidatedSync(
  window: RescanWindow(
    startMillis: t0 + fromIndex * hour,
    endMillis: t0 + toIndex * hour,
    truncated: truncated,
  ),
  observations: observations,
  nextCursor: next == null ? null : cursor(next),
  completeness: completeThroughIndex == null
      ? const PartialDelivery()
      : completeThrough(completeThroughIndex, fromIndex: fromIndex),
);

/// Runs a sync and returns the result.
EngineResult sync(GameEngine engine, SyncResponse response) =>
    engine.execute(ReconcileStepSync(response: response));

/// The steps credited by a sync, read off the event stream rather than by
/// differencing totals — the observable outcome, not an inference.
int grantedBy(EngineResult result) => result.events
    .whereType<StepsGranted>()
    .fold<int>(0, (int sum, StepsGranted e) => sum + e.steps);

/// The cursor the engine authorized for persistence, or null if none was.
SyncCursor? authorizedCursor(EngineResult result) {
  final Iterable<StepCheckpointAuthorized> authorizations = result.events
      .whereType<StepCheckpointAuthorized>();
  return authorizations.isEmpty ? null : authorizations.last.cursor;
}

/// True when the batch authorized a checkpoint at all.
bool didAuthorizeCheckpoint(EngineResult result) =>
    result.events.whereType<StepCheckpointAuthorized>().isNotEmpty;

/// Applies every event up to, but not including, the first [T].
///
/// Truncates rather than filters. Filtering out one event type and applying
/// everything after it models no crash that can actually happen, and it would
/// quietly encode the conclusion that the checkpoint is last — which is the
/// property under test, not an assumption available to the test.
GameState commitUpTo<T extends GameEvent>(
  GameState from,
  List<GameEvent> events,
) => const EventReducer().applyAll(
  from,
  events.takeWhile((GameEvent e) => e is! T).toList(),
);

/// Applies every event before the trailing checkpoint authorization.
///
/// Models a process that died after committing the ledger but before the
/// cursor could be persisted — scenario 10.
GameState commitWithoutCheckpoint(GameState from, List<GameEvent> events) =>
    commitUpTo<StepCheckpointAuthorized>(from, events);
