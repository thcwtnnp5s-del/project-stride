// The session's side of a deferred migration, as the core tests need it.
//
// `BootstrapCoordinator` hands a save whose path waits for the first sync back
// as `BootstrapExistingGame.pendingMigration`, and commits nothing. What the
// app's `StrideSession` then does — one foreground sync committed at the
// on-disk version, then the path applied to the post-sync state and committed
// once — is reproduced here in the same order, over the same repository and
// commands, so the core can prove the transaction without depending on the
// app. `test/deferred_epoch_session_test.dart` at the root proves the real
// session does the same.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'save_support.dart';

/// What the session-side completion did.
typedef DeferredMigrationRun = ({
  BootstrapExistingGame ready,
  GameEngine engine,
  CommitOutcome? syncCommit,
  CommitOutcome? migrationCommit,
  StateMigrationReport? report,
  CommitExpectation head,
});

/// Runs the first sync of the launch — [backlog] as the batch, or nothing —
/// against a pending-migration bootstrap, then applies and commits the pending
/// path, exactly as `StrideSession.syncSteps` does.
///
/// [commitMigration] false stops after the sync's commit, which is the crash
/// window between the two commits. A null commit outcome means that commit was
/// not attempted (no events, or deliberately stopped short).
Future<DeferredMigrationRun> completeAfterFirstSync(
  BootstrapExistingGame ready,
  SaveRepository repo, {
  SyncResponse? backlog,
  bool commitMigration = true,
  String? saltFingerprint,
}) async {
  final PendingStateMigration pending = ready.pendingMigration!;
  final GameEngine engine = ready.engine;
  int generation = ready.expectation.expectedSnapshotGeneration;
  int transaction = ready.expectation.expectedLastAppliedTransaction;

  CommitOutcome? syncCommit;
  if (backlog != null) {
    final EngineResult synced = engine.execute(
      ReconcileStepSync(response: backlog),
    );
    expect(synced.isAccepted, isTrue, reason: '${synced.rejection}');
    if (synced.events.isNotEmpty) {
      syncCommit = await commit(
        repo,
        after: engine.state,
        events: synced.events,
        generation: generation,
        lastTransaction: transaction,
        saltFingerprint: saltFingerprint,
      );
      if (syncCommit is CommitDurable) {
        generation = syncCommit.generation;
        transaction = syncCommit.transactionId;
      }
    }
  }

  CommitOutcome? migrationCommit;
  StateMigrationReport? report;
  GameEngine after = engine;
  final bool syncLanded = syncCommit == null || syncCommit is CommitDurable;
  if (commitMigration && syncLanded) {
    final StateMigrationApplication applied = pending.apply(
      registry: ready.registry,
      state: engine.state,
    );
    expect(applied, isA<StateMigrationApplied>(), reason: '$applied');
    final StateMigrationApplied migrated = applied as StateMigrationApplied;
    migrationCommit = await commit(
      repo,
      after: migrated.engine.state,
      events: migrated.events,
      generation: generation,
      lastTransaction: transaction,
      saltFingerprint: saltFingerprint,
    );
    if (migrationCommit is CommitDurable) {
      generation = migrationCommit.generation;
      transaction = migrationCommit.transactionId;
      after = migrated.engine;
      report = migrated.report;
    }
  }

  return (
    ready: ready,
    engine: after,
    syncCommit: syncCommit,
    migrationCommit: migrationCommit,
    report: report,
    head: CommitExpectation(
      expectedSnapshotGeneration: generation,
      expectedLastAppliedTransaction: transaction,
    ),
  );
}
