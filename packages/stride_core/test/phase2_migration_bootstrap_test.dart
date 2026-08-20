// The Phase 2 cutover as it actually runs: through `BootstrapCoordinator`, over
// a real repository, from a real v1 snapshot on a device.
//
// ## Why this exists beside `economy_epoch_cutover_test.dart`
//
// That file proves the *arithmetic* — what the epoch does to a ledger. This one
// proves the *transaction*: that the migration commits, that a second launch
// reads the migrated save and does not run again, that a device which cannot
// write refuses instead of playing a migration it did not persist, and that the
// refusal leaves the old save untouched so a later launch can still do it.
//
// The distinction matters because the dangerous failure is not a wrong sum. It
// is a migration that appears to work, is not durable, and runs a second time
// against totals that have moved — which is a permanently wrong balance and is
// silent.
//
// ## Since `DECISIONS/0018`: the whole path waits for the first sync
//
// A v1 save's path is v1→v2→v3, and the v2→v3 step declares
// `afterFirstReconcile`. When any step on the path does, the coordinator
// commits **nothing** at bootstrap and hands the whole path back as
// `pendingMigration`; the session completes it after its first sync, in one
// commit. So the v1→v2 cutover no longer lands at bootstrap on this build —
// it lands with v2→v3, together, after the sync — and the tests below drive
// that completion the way the session does (`migration_support.dart`). The
// properties they pin are the same ones: exactly once, durable, retry-safe,
// and the old save untouched until the commit lands.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'bootstrap_test.dart'
    show MemoryIdentityStore, boot, deviceWithSnapshot, liveIdentity;
import 'migration_support.dart';
import 'save_support.dart';

/// A v1 state shaped like the owner's device at Phase 1 closure.
///
/// The real figures, not round ones: 459,223 granted, 180 spent on the
/// acceptance gathers, 459,043 banked.
GameState phase1Save() => GameState(
  stateVersion: 1,
  profileId: BalanceProfile.productionId,
  contentPackVersion: 1,
  player: const PlayerState.initial(),
  inventory: Inventory.empty(),
  equipment: Equipment.empty(),
  skills: SkillProgress.empty(),
  world: WorldState(
    currentLocation: saveRegistry.startLocation.id,
    unlockedLocations: <ContentId>{saveRegistry.startLocation.id},
  ),
  steps: StepLedger.initial().copyWith(
    totalObserved: 459223,
    totalGranted: 459223,
    totalSpent: 180,
    checkpoint: SyncCheckpoint(
      cursor: SyncCursor.ofString('phase-1-closure'),
      syncCount: 12,
    ),
    sourceState: SourceState.available,
  ),
  eventSequence: 0,
);

void main() {
  group('the cutover, through the real startup path', () {
    test(
      'a v1 save is handed back pending, and migrates after the first sync',
      () async {
        final MemoryIdentityStore identity = MemoryIdentityStore(liveIdentity);
        final FaultingDevice device = deviceWithSnapshot(
          phase1Save(),
          originSaltFingerprint: liveIdentity.saltFingerprint,
        );
        final SaveRepository repo = newRepo(device).repo;
        final ({
          BootstrapOutcome outcome,
          FaultingDevice device,
          MemoryIdentityStore identity,
          int mintCalls,
        })
        run = await boot(device: device, identity: identity, repository: repo);

        expect(
          run.outcome,
          isA<BootstrapExistingGame>(),
          reason: '${run.outcome}',
        );
        final BootstrapExistingGame ready =
            run.outcome as BootstrapExistingGame;

        // Nothing committed yet: the save is loaded as it is, at v1, and the
        // whole path is owed.
        expect(ready.migration, isNull);
        expect(ready.pendingMigration, isNotNull);
        expect(ready.pendingMigration!.fromStateVersion, 1);
        expect(ready.pendingMigration!.steps, hasLength(6));
        expect(ready.engine.state.stateVersion, 1);
        expect(ready.engine.state.steps.banked, 459043);

        final DeferredMigrationRun done = await completeAfterFirstSync(
          ready,
          repo,
          saltFingerprint: liveIdentity.saltFingerprint,
        );

        // The player is playable, at zero.
        expect(done.engine.state.steps.banked, 0);
        expect(done.engine.state.stateVersion, StateVersion.current.value);

        // And the launch says what it did, rather than doing it silently.
        final StateMigrationReport report = done.report!;
        expect(report.fromStateVersion, 1);
        expect(report.toStateVersion, StateVersion.current.value);
        expect(report.stepsApplied, hasLength(6));
        expect(report.retiredSteps, 459043);
        expect(report.previouslyRetiredSteps, 0);
        expect(report.newlyRetiredSteps, 459043);
        expect(report.bankedAfter, 0);
        expect(done.engine.state.steps.epoch.establishedAtStateVersion, 3);

        // History intact.
        expect(done.engine.state.steps.totalGranted, 459223);
        expect(done.engine.state.steps.totalSpent, 180);
        expect(done.engine.state.steps.checkpoint.syncCount, 12);
        expect(
          done.engine.state.steps.checkpoint.cursor,
          SyncCursor.ofString('phase-1-closure'),
          reason: 'the health cursor must survive the cutover verbatim',
        );

        // The commit that must not be optional.
        expect(
          run.identity.writes,
          isEmpty,
          reason: 'a resumed game writes no identity, migration or not',
        );
      },
    );

    test(
      'the migration is durable, and the next launch does not rerun',
      () async {
        // The whole point. Two launches over one device, the second reading what
        // the first wrote.
        final FaultingDevice device = deviceWithSnapshot(
          phase1Save(),
          originSaltFingerprint: liveIdentity.saltFingerprint,
        );
        final MemoryIdentityStore identity = MemoryIdentityStore(liveIdentity);
        final SaveRepository repo = newRepo(device).repo;

        final BootstrapExistingGame first =
            (await boot(
                  device: device,
                  identity: identity,
                  repository: repo,
                )).outcome
                as BootstrapExistingGame;
        final DeferredMigrationRun done = await completeAfterFirstSync(
          first,
          repo,
          saltFingerprint: liveIdentity.saltFingerprint,
        );
        expect(done.report, isNotNull);

        // A launch is a fresh process reading the same medium.
        final BootstrapOutcome second = (await boot(
          device: device.reboot(),
          identity: identity,
        )).outcome;

        final BootstrapExistingGame again = second as BootstrapExistingGame;
        expect(
          again.migration,
          isNull,
          reason: 'the second launch must not migrate anything',
        );
        expect(again.pendingMigration, isNull);
        expect(again.engine.state.stateVersion, StateVersion.current.value);
        expect(again.engine.state.steps.banked, 0);
        expect(again.engine.state.steps.totalGranted, 459223);
      },
    );

    test('a player who walks after the cutover keeps those steps', () async {
      // The failure this guards is the worst one available: a migration that
      // runs twice re-bases on totals that have moved, and takes the walk with
      // it. Here the player banks 5,000 between launches.
      final FaultingDevice device = deviceWithSnapshot(
        phase1Save(),
        originSaltFingerprint: liveIdentity.saltFingerprint,
      );
      final MemoryIdentityStore identity = MemoryIdentityStore(liveIdentity);
      final SaveRepository repo = newRepo(device).repo;

      final BootstrapExistingGame first =
          (await boot(
                device: device,
                identity: identity,
                repository: repo,
              )).outcome
              as BootstrapExistingGame;
      final DeferredMigrationRun done = await completeAfterFirstSync(
        first,
        repo,
        saltFingerprint: liveIdentity.saltFingerprint,
      );

      final EngineResult walked = done.engine.execute(
        const GrantSyntheticSteps(steps: 5000, reason: 'a real walk'),
      );
      expect(walked.isAccepted, isTrue);
      expect(done.engine.state.steps.banked, 5000);

      final CommitOutcome committed = await repo.commit(
        after: done.engine.state,
        events: walked.events,
        saveId: liveIdentity.saveId,
        // The head after the migration's commit, not the load's.
        expectation: done.head,
        originSaltFingerprint: liveIdentity.saltFingerprint,
      );
      expect(
        committed,
        isA<CommitDurable>(),
        reason:
            'if this is a conflict, the head after the deferred commit is '
            'wrong and every session that migrates loses its first action',
      );

      final BootstrapExistingGame relaunched =
          (await boot(device: device.reboot(), identity: identity)).outcome
              as BootstrapExistingGame;

      expect(relaunched.migration, isNull);
      expect(relaunched.pendingMigration, isNull);
      expect(
        relaunched.engine.state.steps.banked,
        5000,
        reason: 'the walk survived the relaunch and was not re-based away',
      );
      expect(relaunched.engine.state.steps.totalGranted, 464223);
    });

    test(
      'a new game is created at the current version and never migrates',
      () async {
        final ({
          BootstrapOutcome outcome,
          FaultingDevice device,
          MemoryIdentityStore identity,
          int mintCalls,
        })
        run = await boot();

        expect(run.outcome, isA<BootstrapNewGame>(), reason: '${run.outcome}');
        final BootstrapNewGame fresh = run.outcome as BootstrapNewGame;
        expect(fresh.engine.state.stateVersion, StateVersion.current.value);
        expect(fresh.engine.state.steps.epoch, const EconomyEpoch.origin());
        expect(fresh.engine.state.steps.banked, 0);
      },
    );
  });

  group('a migration that cannot be persisted is refused, not played', () {
    test('the deferred commit refuses, and the old save is untouched', () async {
      final FaultingDevice device = deviceWithSnapshot(
        phase1Save(),
        originSaltFingerprint: liveIdentity.saltFingerprint,
      );
      final String before = device.image();
      final SaveRepository repo = newRepo(device).repo;

      // Bootstrap writes nothing for a deferred path, so the fault is planned
      // for the migration's own commit. Journal-first, so refusing the append
      // is the earliest and cleanest way to make it undurable.
      device.plan(<Fault>[
        const Fault(
          op: 'append',
          path: 'journal',
          effect: FaultEffect.failBefore,
        ),
      ]);

      final BootstrapOutcome outcome = (await boot(
        device: device,
        identity: MemoryIdentityStore(liveIdentity),
        repository: repo,
      )).outcome;
      expect(outcome, isA<BootstrapExistingGame>(), reason: '$outcome');
      expect(device.image(), before, reason: 'bootstrap commits nothing');

      final DeferredMigrationRun run = await completeAfterFirstSync(
        outcome as BootstrapExistingGame,
        repo,
        saltFingerprint: liveIdentity.saltFingerprint,
      );
      expect(run.migrationCommit, isA<CommitRefused>());
      expect(run.report, isNull);
      expect(
        run.engine.state.stateVersion,
        1,
        reason: 'the engine handed back is still the unmigrated one',
      );
      expect(
        device.image(),
        before,
        reason:
            'a refused migration must leave the old save exactly as it was, so '
            'a later launch that can write still performs it',
      );
    });

    test('and a later launch that can write performs it identically', () async {
      // Crash/retry safety, stated as the property that matters: the retry
      // produces the same answer as the attempt that failed.
      final FaultingDevice device = deviceWithSnapshot(
        phase1Save(),
        originSaltFingerprint: liveIdentity.saltFingerprint,
      );
      final MemoryIdentityStore identity = MemoryIdentityStore(liveIdentity);
      final SaveRepository repo = newRepo(device).repo;

      device.plan(<Fault>[
        const Fault(
          op: 'append',
          path: 'journal',
          effect: FaultEffect.failBefore,
        ),
      ]);
      final DeferredMigrationRun refused = await completeAfterFirstSync(
        (await boot(
              device: device,
              identity: identity,
              repository: repo,
            )).outcome
            as BootstrapExistingGame,
        repo,
        saltFingerprint: liveIdentity.saltFingerprint,
      );
      expect(refused.migrationCommit, isA<CommitRefused>());

      device.plan(const <Fault>[]);
      final FaultingDevice rebooted = device.reboot();
      final SaveRepository repo2 = newRepo(rebooted).repo;
      final BootstrapOutcome retried = (await boot(
        device: rebooted,
        identity: identity,
        repository: repo2,
      )).outcome;
      final BootstrapExistingGame ready = retried as BootstrapExistingGame;
      expect(ready.pendingMigration, isNotNull);

      final DeferredMigrationRun done = await completeAfterFirstSync(
        ready,
        repo2,
        saltFingerprint: liveIdentity.saltFingerprint,
      );
      expect(done.migrationCommit, isA<CommitDurable>());
      expect(done.report!.retiredSteps, 459043);
      expect(done.engine.state.steps.banked, 0);
      expect(done.engine.state.steps.totalGranted, 459223);
    });
  });
}
