// Builders for the save suite.

import 'package:stride_core/stride_core.dart';

import 'step_support.dart';
import 'support/faulting_store.dart';

export 'support/faulting_store.dart';

/// A fixed lineage id. The core cannot mint one — no clock, no randomness — so
/// the app supplies it and tests supply a constant.
const String testSaveId = 'save-0001';

/// A repository over a fresh device.
({SaveRepository repo, FaultingDevice device}) newRepo([
  FaultingDevice? existing,
]) {
  final FaultingDevice device = existing ?? FaultingDevice();
  return (
    repo: SaveRepository(
      snapshots: FaultingSnapshotStore(device),
      journal: FaultingJournal(device),
    ),
    device: device,
  );
}

/// Commits [events] against [after], asserting nothing about the outcome.
Future<CommitOutcome> commit(
  SaveRepository repo, {
  required GameState after,
  required List<GameEvent> events,
  required int generation,
  required int lastTransaction,
}) => repo.commit(
  after: after,
  events: events,
  saveId: testSaveId,
  expectation: CommitExpectation(
    expectedSnapshotGeneration: generation,
    expectedLastAppliedTransaction: lastTransaction,
  ),
);

/// Runs a command through the engine and commits the resulting batch.
///
/// Returns the commit outcome and the state that was committed.
Future<({CommitOutcome outcome, GameState state})> apply(
  SaveRepository repo,
  GameEngine engine,
  GameCommand command, {
  required int generation,
  required int lastTransaction,
}) async {
  final EngineResult result = engine.execute(command);
  final CommitOutcome outcome = await commit(
    repo,
    after: engine.state,
    events: result.events,
    generation: generation,
    lastTransaction: lastTransaction,
  );
  return (outcome: outcome, state: engine.state);
}

/// The registry every save test loads against.
ContentRegistry get saveRegistry => stepRegistry;
