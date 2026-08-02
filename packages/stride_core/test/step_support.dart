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
const StepOrigin phone = StepOrigin('phone');
const StepOrigin watch = StepOrigin('watch');

/// One hour, in milliseconds. Buckets are arbitrary intervals; the reconciler
/// never asks what day one falls on.
const int hour = 60 * 60 * 1000;

/// A fixed origin instant. A constant, not a clock read — the core forbids
/// reading one and the tests must not need one either.
const int t0 = 1750000000000;

/// An observation for hour [index] after [t0].
StepObservation obs(StepOrigin origin, int index, int steps) => StepObservation(
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

IncrementalSync incremental(
  List<StepObservation> observations, {
  String? next,
}) => IncrementalSync(
  observations: observations,
  nextCursor: next == null ? null : cursor(next),
);

CursorInvalidatedSync rescan(
  List<StepObservation> observations, {
  required int fromIndex,
  required int toIndex,
  bool truncated = false,
  String? next,
}) => CursorInvalidatedSync(
  window: RescanWindow(
    startMillis: t0 + fromIndex * hour,
    endMillis: t0 + toIndex * hour,
    truncated: truncated,
  ),
  observations: observations,
  nextCursor: next == null ? null : cursor(next),
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

/// Applies every event *except* the trailing checkpoint authorization.
///
/// Models a process that died after committing the ledger but before the
/// cursor could be persisted — scenario 10.
GameState commitWithoutCheckpoint(GameState from, List<GameEvent> events) {
  final List<GameEvent> upToCheckpoint = events
      .where((GameEvent e) => e is! StepCheckpointAuthorized)
      .toList();
  return const EventReducer().applyAll(from, upToCheckpoint);
}
