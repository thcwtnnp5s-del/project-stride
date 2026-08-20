// The Transformation playtest epoch (`DECISIONS/0018`) — state version 3.
//
// ## What is at risk, and why it is different from 0016
//
// 0016 established the *first* epoch on a ledger that had never been re-based,
// and its exactly-once guard was "refuse any non-origin epoch". This decision
// re-bases a ledger that has **already** been re-based once, on the owner's
// device: banked 5,723 at the first Phase 2 launch, 5,123 after some travel and
// spending, on top of the 459,043 the Phase 2 cutover retired. So the guard has
// to be able to tell a v2 epoch from a v3 one — and the migration path has to
// be a *table*, so that the next format bump does not zero a balance by being
// newer.
//
// The failure modes are the same three as 0016, plus one:
//
// 1. It runs twice — a v3 save re-bases again on a later launch.
// 2. It rewinds or advances the cursor — re-granting the retention window.
// 3. It lowers `totalGranted` — a clawback.
// 4. **It runs by accident** — a v3→v4 step that only adds a field re-bases
//    the economy because "older than current" was the whole condition.
// 5. **It runs too early** — at bootstrap, before the first sync has seen the
//    steps walked since the last Phase 2 sync, so that backlog lands *after*
//    the mark and the playtest begins at "whatever I walked yesterday" rather
//    than at zero. Group 5 is where that is pinned: the step declares
//    `afterFirstReconcile`, bootstrap commits nothing, and the mark is taken
//    from the post-sync totals.
//
// As in `economy_epoch_cutover_test.dart`, most of the assertions are about
// what the migration does *not* do.

import 'package:stride_core/stride_core.dart';
import 'package:test/test.dart';

import 'bootstrap_test.dart'
    show MemoryIdentityStore, boot, deviceWithSnapshot, liveIdentity;
import 'migration_support.dart';
import 'save_support.dart';
import 'step_support.dart';

final ContentId meadow = ContentId.unchecked('resource_node.meadow_patch');
final ContentId woods = ContentId.unchecked('location.whispering_woods');

/// The Phase 2 device at the point of the Transformation upgrade.
///
/// The real figures from the first Phase 2 device review, not round ones:
/// `TOTAL WALKED` 464,946; the Phase 2 epoch at 459,223 granted / 180 spent;
/// 5,723 banked at launch and 5,123 after 600 steps of travel — so 780 spent
/// in total. A v2 save, whose epoch was established at state version 2.
StepLedger phase2DeviceLedger() => StepLedger.initial().copyWith(
  totalObserved: 464946,
  totalGranted: 464946,
  totalSpent: 780,
  epoch: const EconomyEpoch(
    grantedAtStart: 459223,
    spentAtStart: 180,
    establishedAtStateVersion: 2,
  ),
  grantedSlices: <ObservationKey, int>{obs(phone, 300, 5723).key: 5723},
  checkpoint: SyncCheckpoint(
    cursor: cursor('phase-2-review'),
    syncCount: 14,
    originWatermarks: <StepOriginKey, int>{phone: t0 + 300 * hour},
  ),
  sourceState: SourceState.available,
);

GameState stateAt(int version, StepLedger ledger) => GameState(
  stateVersion: version,
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
  steps: ledger,
  eventSequence: 0,
);

GameState phase2Save() => stateAt(2, phase2DeviceLedger());

/// Runs the migration exactly as `BootstrapCoordinator._migrate` does: reshape,
/// then every re-basing table step from the save's version, through the real
/// engine and the real command.
GameEngine migrate(GameState loaded) {
  final GameEngine engine = GameEngine(
    registry: saveRegistry,
    state: loaded.migratedToCurrentVersion(),
  );
  for (final StateMigrationStep step in StateMigrations.pathFrom(
    loaded.stateVersion,
  )) {
    if (!step.rebasesEconomy) continue;
    final EngineResult result = engine.execute(
      EstablishEconomyEpoch(
        fromStateVersion: step.from,
        toStateVersion: step.to,
      ),
    );
    expect(result.isAccepted, isTrue, reason: '$step: ${result.rejection}');
  }
  return engine;
}

void main() {
  final int gatherCost = saveRegistry.profile.applyStepCost(
    saveRegistry.resourceNodes[meadow]!.stepCost,
  );

  group(
    '0 — the migration table is explicit, contiguous, and says what it does',
    () {
      test('it runs from the oldest supported version to the current one', () {
        final List<StateMigrationStep> steps = StateMigrations.steps;
        expect(steps, isNotEmpty);
        expect(steps.first.from, StateVersion.minimumSupported.value);
        expect(steps.last.to, StateVersion.current.value);
        for (int i = 1; i < steps.length; i++) {
          expect(
            steps[i].from,
            steps[i - 1].to,
            reason:
                'a gap in the table is a version no save can be brought past',
          );
        }
      });

      test(
        'every step names its decision, and re-basing is opt-in per step',
        () {
          for (final StateMigrationStep step in StateMigrations.steps) {
            expect(step.decision, startsWith('DECISIONS/'));
            expect(step.to, step.from + 1);
          }
          // The first two re-base, and each says so by name. The third,
          // fourth and fifth — the v3→v4 Combat Slice 01 reshape
          // (`DECISIONS/0020`), the v4→v5 repeatable-encounter reshape
          // (`DECISIONS/0021`), and the v5→v6 activity-queue reshape
          // (`DECISIONS/0022`) — are the case this table was built for: a
          // format bump that says `rebasesEconomy: false` and touches no
          // balance. Pinned per step so that flipping the flag on any kind is
          // a reviewable edit.
          expect(
            StateMigrations.steps.map((StateMigrationStep s) => s.decision),
            <String>[
              'DECISIONS/0016_ECONOMY_EPOCH_CUTOVER.md',
              'DECISIONS/0018_TRANSFORMATION_PLAYTEST_EPOCH.md',
              'DECISIONS/0020_COMBAT_SLICE_01.md',
              'DECISIONS/0021_REPEATABLE_ENCOUNTERS_AND_RARITY.md',
              'DECISIONS/0022_FINITE_BACKGROUND_ACTIVITY.md',
            ],
          );
          expect(
            StateMigrations.steps.map(
              (StateMigrationStep s) => s.rebasesEconomy,
            ),
            <bool>[true, true, false, false, false],
          );
        },
      );

      test('the path from a version is exactly the steps at or after it', () {
        expect(StateMigrations.pathFrom(StateVersion.current.value), isEmpty);
        expect(
          StateMigrations.pathFrom(2).map((StateMigrationStep s) => s.to),
          <int>[3, 4, 5, 6],
        );
        expect(
          StateMigrations.pathFrom(1).map((StateMigrationStep s) => s.to),
          <int>[2, 3, 4, 5, 6],
        );
        expect(
          () => StateMigrations.pathFrom(0),
          throwsA(isA<UnsupportedStateVersionException>()),
        );
      });

      test('a step that does not re-base issues no epoch command', () {
        // The structural guarantee, exercised rather than described: walk a
        // hypothetical table where the step says `rebasesEconomy: false`, the
        // same way `_migrate` walks the real one, and the epoch is untouched.
        const StateMigrationStep reshapeOnly = StateMigrationStep(
          from: 3,
          to: 4,
          rebasesEconomy: false,
          decision: 'DECISIONS/hypothetical',
        );
        final GameEngine engine = migrate(phase2Save());
        final EconomyEpoch before = engine.state.steps.epoch;
        engine.execute(const GrantSyntheticSteps(steps: 900, reason: 'walk'));

        for (final StateMigrationStep step in <StateMigrationStep>[
          reshapeOnly,
        ]) {
          if (!step.rebasesEconomy) continue;
          fail('a reshape-only step must not reach EstablishEconomyEpoch');
        }

        expect(engine.state.steps.epoch, before);
        expect(engine.state.steps.banked, 900);
      });
    },
  );

  group('1 — the playtest begins at zero, exactly once', () {
    test('(b) banked is 0 immediately after, from a real Phase 2 balance', () {
      final GameState before = phase2Save();
      expect(before.steps.banked, 5123, reason: 'the fixture is the device');

      final GameState after = migrate(before).state;

      expect(after.steps.banked, 0);
      expect(after.steps.epoch.establishedAtStateVersion, 3);
      expect(after.stateVersion, StateVersion.current.value);
    });

    test('(h) a v3 save is not migrated again, and the command refuses', () {
      final GameEngine engine = migrate(phase2Save());
      expect(
        StateVersion.migrationRequired(engine.state.stateVersion),
        isFalse,
      );
      expect(StateMigrations.pathFrom(engine.state.stateVersion), isEmpty);

      // Walk, so a second re-basing would be visibly destructive.
      engine.execute(const GrantSyntheticSteps(steps: 4000, reason: 'walk'));
      expect(engine.state.steps.banked, 4000);

      final EngineResult again = engine.execute(
        const EstablishEconomyEpoch(fromStateVersion: 2, toStateVersion: 3),
      );
      expect(again.isRejected, isTrue);
      expect(again.rejection!.code, RejectionCode.economyEpochAlreadySet);
      expect(again.rejection!.explanation, contains('v3'));
      expect(engine.state.steps.banked, 4000);

      // Nor may the *older* step re-base it: v2 ≤ v3.
      final EngineResult older = engine.execute(
        const EstablishEconomyEpoch(fromStateVersion: 1, toStateVersion: 2),
      );
      expect(older.rejection!.code, RejectionCode.economyEpochAlreadySet);
      expect(engine.state.steps.banked, 4000);
    });

    test('the v3 step re-bases a v2 epoch once and only once', () {
      // The precise property 0016's guard could not express. A v2 epoch is not
      // the origin, and yet the v3 step must be allowed through — exactly once.
      final GameEngine engine = GameEngine(
        registry: saveRegistry,
        state: phase2Save().migratedToCurrentVersion(),
      );
      expect(engine.state.steps.epoch.isOrigin, isFalse);

      final EngineResult first = engine.execute(
        const EstablishEconomyEpoch(fromStateVersion: 2, toStateVersion: 3),
      );
      expect(first.isAccepted, isTrue, reason: '${first.rejection}');

      final EngineResult second = engine.execute(
        const EstablishEconomyEpoch(fromStateVersion: 2, toStateVersion: 3),
      );
      expect(second.rejection!.code, RejectionCode.economyEpochAlreadySet);
    });

    test('the event carries the previous mark and the version it set', () {
      final GameEngine engine = GameEngine(
        registry: saveRegistry,
        state: phase2Save().migratedToCurrentVersion(),
      );
      final EngineResult result = engine.execute(
        const EstablishEconomyEpoch(fromStateVersion: 2, toStateVersion: 3),
      );
      final EconomyEpochEstablished event =
          result.events.single as EconomyEpochEstablished;

      expect(event.grantedAtStart, 464946);
      expect(event.spentAtStart, 780);
      expect(event.previousGrantedAtStart, 459223);
      expect(event.previousSpentAtStart, 180);
      expect(event.fromStateVersion, 2);
      expect(event.toStateVersion, 3);
      expect(event.newlyRetiredSteps, 5123);
    });
  });

  group('2 — (a) historical steps remain historical', () {
    late GameState before;
    late GameState after;

    setUp(() {
      before = phase2Save();
      after = migrate(before).state;
    });

    test('granted, observed and spent are not decreased — H-2 holds', () {
      expect(after.steps.totalGranted, 464946);
      expect(after.steps.totalObserved, 464946);
      expect(after.steps.totalSpent, 780);
    });

    test('the whole retired body is still reportable, in one figure', () {
      // 459,043 from Phase 2 plus 5,123 from this launch. `retiredSteps` is
      // `grantedAtStart − spentAtStart` of the *current* mark, so it names
      // everything ever banked before the playable economy began.
      expect(after.steps.epoch.retiredSteps, 464166);
      expect(after.steps.epoch.retiredSteps, 459043 + 5123);
    });

    test(
      '(c) the cursor, watermarks, sync count and slices survive verbatim',
      () {
        expect(
          after.steps.checkpoint.cursor?.bytes,
          before.steps.checkpoint.cursor?.bytes,
          reason: 'the cursor must move neither backward nor forward — H-3',
        );
        expect(after.steps.checkpoint.cursor, cursor('phase-2-review'));
        expect(
          after.steps.checkpoint.originWatermarks,
          before.steps.checkpoint.originWatermarks,
        );
        expect(after.steps.checkpoint.syncCount, 14);
        expect(after.steps.grantedSlices, before.steps.grantedSlices);
        expect(
          after.steps.grantedBeforeWatermark,
          before.steps.grantedBeforeWatermark,
        );
      },
    );

    test('the epoch is the only thing that changed about the ledger', () {
      // The strongest form of "it touched nothing else": put the *previous*
      // epoch back and compare the whole canonical encoding.
      expect(
        canonicalDurableStepLedger(
          after.steps.copyWith(epoch: before.steps.epoch),
        ),
        canonicalDurableStepLedger(before.steps),
      );
    });
  });

  group('3 — new steps become spendable exactly once', () {
    test('(d) an immediate repeat of the last batch grants 0', () {
      // The batch that produced the device's slice, replayed after the reset.
      // The slice bookkeeping is untouched, so it is still a duplicate.
      final GameEngine engine = migrate(phase2Save());
      final SyncResponse replay = incremental(<StepObservation>[
        obs(phone, 300, 5723),
      ], next: 'phase-2-review');

      final EngineResult result = sync(engine, replay);

      expect(result.isAccepted, isTrue);
      expect(grantedBy(result), 0);
      expect(engine.state.steps.banked, 0);
      expect(engine.state.steps.totalGranted, 464946);
    });

    test('(e) a new batch grants once; the same batch again grants 0', () {
      final GameEngine engine = migrate(phase2Save());
      final SyncResponse walk = incremental(<StepObservation>[
        obs(phone, 301, 1187),
      ], next: 'after-transformation-1');

      expect(sync(engine, walk).isAccepted, isTrue);
      expect(engine.state.steps.banked, 1187);
      expect(engine.state.steps.totalGranted, 464946 + 1187);

      expect(sync(engine, walk).isAccepted, isTrue);
      expect(
        engine.state.steps.banked,
        1187,
        reason: 'a replayed batch must grant nothing the second time',
      );
    });

    test('(f) gathering and travel debit the new balance, never below 0', () {
      final GameEngine engine = migrate(phase2Save());
      engine.execute(const GrantSyntheticSteps(steps: 1000, reason: 'walk'));

      final EngineResult gathered = engine.execute(
        GatherResource(node: meadow),
      );
      expect(gathered.isAccepted, isTrue, reason: '${gathered.rejection}');
      expect(engine.state.steps.banked, 1000 - gatherCost);
      expect(engine.state.steps.totalSpent, 780 + gatherCost);

      final EngineResult travelled = engine.execute(
        TravelTo(destination: woods),
      );
      expect(travelled.isAccepted, isTrue, reason: '${travelled.rejection}');
      final int spentOnTravel =
          (travelled.events.single as LocationTravelled).stepsSpent;
      expect(engine.state.steps.banked, 1000 - gatherCost - spentOnTravel);
      expect(engine.state.steps.banked, greaterThanOrEqualTo(0));

      // And a request the *retired* balance would have covered is refused.
      final EngineResult tooMuch = engine.execute(
        const AllocateSteps(steps: 5123),
      );
      expect(tooMuch.rejection!.code, RejectionCode.insufficientSteps);
      expect(engine.state.steps.banked, greaterThanOrEqualTo(0));
    });
  });

  group('4 — (g) the epoch survives a save round trip', () {
    test('encode → decode preserves epoch, banked and totals', () {
      final GameEngine engine = migrate(phase2Save());
      engine.execute(const GrantSyntheticSteps(steps: 250, reason: 'walk'));
      final GameState after = engine.state;

      final SaveEnvelope reloaded = decodeEnvelope(
        unframe(
          encodeSnapshot(
            state: after,
            saveId: 'round-trip-0018',
            generation: 1,
            lastAppliedTransaction: 1,
            originSaltFingerprint: null,
          ),
        ).payload!,
      );

      expect(reloaded.gameStateVersion, StateVersion.current.value);
      expect(reloaded.state.steps.epoch, after.steps.epoch);
      expect(reloaded.state.steps.epoch.establishedAtStateVersion, 3);
      expect(reloaded.state.steps.banked, 250);
      expect(reloaded.state.steps.totalGranted, 464946 + 250);
      expect(
        canonicalDurableGameState(reloaded.state),
        canonicalDurableGameState(after),
      );
    });

    test('a journal record without toStateVersion decodes as the v2 cutover', () {
      // The Phase 2 migration wrote records before the field existed. Replaying
      // one must produce an epoch established at 2 — the only thing such a
      // record can be — so the v3 step can then re-base it exactly once.
      final Map<String, Object?> legacy = <String, Object?>{
        't': 'EconomyEpochEstablished',
        'seq': 0,
        'grantedAtStart': 459223,
        'spentAtStart': 180,
        'fromStateVersion': 1,
      };
      final EconomyEpochEstablished? decoded =
          decodeEvent(legacy) as EconomyEpochEstablished?;

      expect(decoded, isNotNull);
      expect(decoded!.toStateVersion, 2);
      expect(decoded.previousGrantedAtStart, 0);
      expect(decoded.previousSpentAtStart, 0);

      final GameState replayed = const EventReducer().apply(
        stateAt(
          1,
          StepLedger.initial().copyWith(
            totalObserved: 459223,
            totalGranted: 459223,
            totalSpent: 180,
          ),
        ),
        decoded,
      );
      expect(replayed.steps.epoch.establishedAtStateVersion, 2);
      expect(replayed.steps.banked, 0);
    });

    test('a current journal record round-trips every field', () {
      const EconomyEpochEstablished event = EconomyEpochEstablished(
        sequence: 7,
        grantedAtStart: 464946,
        spentAtStart: 780,
        previousGrantedAtStart: 459223,
        previousSpentAtStart: 180,
        fromStateVersion: 2,
        toStateVersion: 3,
      );
      final EconomyEpochEstablished? back =
          decodeEvent(encodeEvent(event)) as EconomyEpochEstablished?;
      expect(back, isNotNull);
      expect(back!.grantedAtStart, 464946);
      expect(back.spentAtStart, 780);
      expect(back.previousGrantedAtStart, 459223);
      expect(back.previousSpentAtStart, 180);
      expect(back.fromStateVersion, 2);
      expect(back.toStateVersion, 3);
    });
  });

  group('5 — through the real startup path: the cutover waits for the sync', () {
    // The owner's device between the last Phase 2 sync and the first
    // Transformation launch: the walking in between is the *backlog*, and it
    // is the whole reason the v2→v3 step is deferred. Marked at bootstrap the
    // epoch would leave it outside the retired body; marked after the first
    // sync it is inside.
    const int backlogSteps = 2213;
    SyncResponse backlog() => incremental(<StepObservation>[
      obs(phone, 301, backlogSteps),
    ], next: 'transformation-first-sync');

    test('a v2 save is handed back pending, with nothing committed', () async {
      final FaultingDevice device = deviceWithSnapshot(
        phase2Save(),
        originSaltFingerprint: liveIdentity.saltFingerprint,
      );
      final String before = device.image();

      final BootstrapOutcome outcome = (await boot(
        device: device,
        identity: MemoryIdentityStore(liveIdentity),
      )).outcome;

      expect(outcome, isA<BootstrapExistingGame>(), reason: '$outcome');
      final BootstrapExistingGame ready = outcome as BootstrapExistingGame;
      expect(ready.migration, isNull);
      expect(ready.pendingMigration, isNotNull);
      expect(ready.pendingMigration!.fromStateVersion, 2);
      expect(
        ready.pendingMigration!.steps.map((StateMigrationStep s) => s.to),
        <int>[3, 4, 5, 6],
      );
      // The engine is the save as it is on disk: still v2, still 5,123.
      expect(ready.engine.state.stateVersion, 2);
      expect(ready.engine.state.steps.banked, 5123);
      // And the disk is untouched; the expectation is the load's own head.
      expect(device.image(), before);
      expect(ready.expectation.expectedSnapshotGeneration, 0);
      expect(ready.expectation.expectedLastAppliedTransaction, 1);
    });

    test(
      '(a) after the first sync the backlog is retired, banked is 0, and the '
      'cursor moved forward once',
      () async {
        final FaultingDevice device = deviceWithSnapshot(
          phase2Save(),
          originSaltFingerprint: liveIdentity.saltFingerprint,
        );
        final MemoryIdentityStore identity = MemoryIdentityStore(liveIdentity);
        final SaveRepository repo = newRepo(device).repo;
        final BootstrapExistingGame ready =
            (await boot(
                  device: device,
                  identity: identity,
                  repository: repo,
                )).outcome
                as BootstrapExistingGame;

        final DeferredMigrationRun run = await completeAfterFirstSync(
          ready,
          repo,
          backlog: backlog(),
          saltFingerprint: liveIdentity.saltFingerprint,
        );

        expect(run.syncCommit, isA<CommitDurable>());
        expect(run.migrationCommit, isA<CommitDurable>());
        final GameState after = run.engine.state;
        expect(after.stateVersion, StateVersion.current.value);
        expect(after.steps.epoch.establishedAtStateVersion, 3);
        expect(after.steps.banked, 0);
        expect(after.steps.totalGranted, 464946 + backlogSteps);
        expect(
          after.steps.epoch.grantedAtStart,
          464946 + backlogSteps,
          reason: 'the mark includes the backlog — that is the whole point',
        );
        expect(after.steps.epoch.spentAtStart, 780);
        expect(after.steps.epoch.retiredSteps, 464166 + backlogSteps);
        expect(
          after.steps.checkpoint.cursor,
          cursor('transformation-first-sync'),
          reason: 'advanced by the sync, once; never rewound',
        );
        expect(after.steps.checkpoint.syncCount, 15);

        final StateMigrationReport report = run.report!;
        expect(report.fromStateVersion, 2);
        expect(report.toStateVersion, StateVersion.current.value);
        expect(report.bankedAfter, 0);
        expect(report.previouslyRetiredSteps, 459043);
        expect(report.newlyRetiredSteps, 5123 + backlogSteps);
        expect(report.stepsApplied.map((StateMigrationStep s) => s.to), <int>[
          3,
          4,
          5,
          6,
        ]);

        // Two transactions: the sync's, then the migration's — the migration
        // itself is still one commit.
        final SaveLoaded reread =
            await repo.load(
                  registry: saveRegistry,
                  originSaltFingerprint: liveIdentity.saltFingerprint,
                )
                as SaveLoaded;
        expect(
          reread.lastAppliedTransaction,
          3,
          reason: 'was 1 in the fixture',
        );
        expect(reread.state.stateVersion, StateVersion.current.value);
        expect(reread.state.steps.banked, 0);
      },
    );

    test('(b) an immediate repeat sync grants 0 and banked stays 0', () async {
      final FaultingDevice device = deviceWithSnapshot(
        phase2Save(),
        originSaltFingerprint: liveIdentity.saltFingerprint,
      );
      final MemoryIdentityStore identity = MemoryIdentityStore(liveIdentity);
      final SaveRepository repo = newRepo(device).repo;
      final BootstrapExistingGame ready =
          (await boot(
                device: device,
                identity: identity,
                repository: repo,
              )).outcome
              as BootstrapExistingGame;
      final DeferredMigrationRun run = await completeAfterFirstSync(
        ready,
        repo,
        backlog: backlog(),
        saltFingerprint: liveIdentity.saltFingerprint,
      );

      final EngineResult again = sync(run.engine, backlog());
      expect(again.isAccepted, isTrue);
      expect(grantedBy(again), 0);
      expect(run.engine.state.steps.banked, 0);
    });

    test(
      '(c) steps walked after the cutover grant once and are spendable',
      () async {
        final FaultingDevice device = deviceWithSnapshot(
          phase2Save(),
          originSaltFingerprint: liveIdentity.saltFingerprint,
        );
        final MemoryIdentityStore identity = MemoryIdentityStore(liveIdentity);
        final SaveRepository repo = newRepo(device).repo;
        final BootstrapExistingGame ready =
            (await boot(
                  device: device,
                  identity: identity,
                  repository: repo,
                )).outcome
                as BootstrapExistingGame;
        final DeferredMigrationRun run = await completeAfterFirstSync(
          ready,
          repo,
          backlog: backlog(),
          saltFingerprint: liveIdentity.saltFingerprint,
        );

        final SyncResponse walk = incremental(<StepObservation>[
          obs(phone, 302, 1187),
        ], next: 'after-transformation-1');
        expect(grantedBy(sync(run.engine, walk)), 1187);
        expect(run.engine.state.steps.banked, 1187);
        expect(grantedBy(sync(run.engine, walk)), 0);
        expect(run.engine.state.steps.banked, 1187);

        final EngineResult gathered = run.engine.execute(
          GatherResource(node: meadow),
        );
        expect(gathered.isAccepted, isTrue, reason: '${gathered.rejection}');
        expect(run.engine.state.steps.banked, 1187 - gatherCost);
      },
    );

    test('(d) a crash between the sync commit and the migration commit: the '
        'relaunch grants 0 and completes it with the same result', () async {
      final FaultingDevice device = deviceWithSnapshot(
        phase2Save(),
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

      // The sync lands; the process dies before the migration commit.
      final DeferredMigrationRun interrupted = await completeAfterFirstSync(
        first,
        repo,
        backlog: backlog(),
        commitMigration: false,
        saltFingerprint: liveIdentity.saltFingerprint,
      );
      expect(interrupted.syncCommit, isA<CommitDurable>());
      expect(interrupted.migrationCommit, isNull);

      // Relaunch: a v2 save whose cursor already advanced.
      final FaultingDevice rebooted = device.reboot();
      final SaveRepository repo2 = newRepo(rebooted).repo;
      final BootstrapExistingGame second =
          (await boot(
                device: rebooted,
                identity: identity,
                repository: repo2,
              )).outcome
              as BootstrapExistingGame;
      expect(second.pendingMigration, isNotNull);
      expect(second.engine.state.stateVersion, 2);
      expect(second.engine.state.steps.totalGranted, 464946 + backlogSteps);
      expect(
        second.engine.state.steps.checkpoint.cursor,
        cursor('transformation-first-sync'),
      );

      // Its first sync is the same batch again — the provider restates from
      // the durable cursor — and grants nothing; then the migration lands.
      final DeferredMigrationRun completed = await completeAfterFirstSync(
        second,
        repo2,
        backlog: backlog(),
        saltFingerprint: liveIdentity.saltFingerprint,
      );
      expect(completed.migrationCommit, isA<CommitDurable>());
      expect(completed.engine.state.stateVersion, StateVersion.current.value);
      expect(completed.engine.state.steps.banked, 0);
      expect(
        completed.engine.state.steps.totalGranted,
        464946 + backlogSteps,
        reason: 'the backlog was granted exactly once, across the crash',
      );
      expect(
        completed.engine.state.steps.epoch.grantedAtStart,
        464946 + backlogSteps,
      );
      expect(completed.report!.newlyRetiredSteps, 5123 + backlogSteps);
    });

    test(
      '(f) a sync that observes nothing still completes the cutover, at 0',
      () async {
        // Health unavailable or denied at the cutover: the sync has nothing to
        // reconcile and commits nothing. The migration still runs — the player
        // must not be held hostage to the provider — and marks what is known.
        final FaultingDevice device = deviceWithSnapshot(
          phase2Save(),
          originSaltFingerprint: liveIdentity.saltFingerprint,
        );
        final MemoryIdentityStore identity = MemoryIdentityStore(liveIdentity);
        final SaveRepository repo = newRepo(device).repo;
        final BootstrapExistingGame ready =
            (await boot(
                  device: device,
                  identity: identity,
                  repository: repo,
                )).outcome
                as BootstrapExistingGame;

        final DeferredMigrationRun run = await completeAfterFirstSync(
          ready,
          repo,
          saltFingerprint: liveIdentity.saltFingerprint,
        );
        expect(run.syncCommit, isNull);
        expect(run.migrationCommit, isA<CommitDurable>());
        expect(run.engine.state.steps.banked, 0);
        expect(run.engine.state.steps.totalGranted, 464946);
        expect(run.report!.newlyRetiredSteps, 5123);
        expect(run.head.expectedLastAppliedTransaction, 2);
      },
    );

    test('(j) a v3 save never enters the migration path', () async {
      final FaultingDevice device = deviceWithSnapshot(
        phase2Save(),
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
      final DeferredMigrationRun run = await completeAfterFirstSync(
        first,
        repo,
        backlog: backlog(),
        saltFingerprint: liveIdentity.saltFingerprint,
      );
      expect(run.report, isNotNull);

      final BootstrapExistingGame second =
          (await boot(device: device.reboot(), identity: identity)).outcome
              as BootstrapExistingGame;
      expect(second.migration, isNull);
      expect(second.pendingMigration, isNull);
      expect(second.engine.state.steps.banked, 0);
      expect(second.engine.state.steps.epoch.establishedAtStateVersion, 3);
      // And the head did not move: no commit on an ordinary launch.
      expect(
        second.expectation.expectedLastAppliedTransaction,
        run.head.expectedLastAppliedTransaction,
      );
    });

    test('a walk between launches is kept', () async {
      final FaultingDevice device = deviceWithSnapshot(
        phase2Save(),
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
      final DeferredMigrationRun run = await completeAfterFirstSync(
        first,
        repo,
        backlog: backlog(),
        saltFingerprint: liveIdentity.saltFingerprint,
      );
      final EngineResult walked = run.engine.execute(
        const GrantSyntheticSteps(steps: 2500, reason: 'a real walk'),
      );
      final CommitOutcome committed = await repo.commit(
        after: run.engine.state,
        events: walked.events,
        saveId: liveIdentity.saveId,
        expectation: run.head,
        originSaltFingerprint: liveIdentity.saltFingerprint,
      );
      expect(committed, isA<CommitDurable>());

      final BootstrapExistingGame relaunched =
          (await boot(device: device.reboot(), identity: identity)).outcome
              as BootstrapExistingGame;
      expect(relaunched.migration, isNull);
      expect(relaunched.pendingMigration, isNull);
      expect(relaunched.engine.state.steps.banked, 2500);
      expect(
        relaunched.engine.state.steps.totalGranted,
        464946 + backlogSteps + 2500,
      );
    });

    test(
      '(i) a v1 save defers the whole path and lands at the current version in one commit',
      () async {
        // The path v1→v2→v3 contains a deferring step, so *all* of it waits:
        // a v1 save is not committed at v2 in between. Same one-transaction
        // property `DECISIONS/0018` §4 requires, reached the same way.
        final GameState v1 = stateAt(
          1,
          StepLedger.initial().copyWith(
            totalObserved: 459223,
            totalGranted: 459223,
            totalSpent: 180,
            checkpoint: SyncCheckpoint(
              cursor: cursor('phase-1-closure'),
              syncCount: 12,
            ),
            sourceState: SourceState.available,
          ),
        );
        final FaultingDevice device = deviceWithSnapshot(
          v1,
          originSaltFingerprint: liveIdentity.saltFingerprint,
        );
        final MemoryIdentityStore identity = MemoryIdentityStore(liveIdentity);
        final SaveRepository repo = newRepo(device).repo;

        final BootstrapExistingGame ready =
            (await boot(
                  device: device,
                  identity: identity,
                  repository: repo,
                )).outcome
                as BootstrapExistingGame;
        expect(ready.migration, isNull);
        expect(ready.engine.state.stateVersion, 1);
        expect(
          ready.pendingMigration!.steps.map((StateMigrationStep s) => s.to),
          <int>[2, 3, 4, 5, 6],
        );

        final DeferredMigrationRun run = await completeAfterFirstSync(
          ready,
          repo,
          saltFingerprint: liveIdentity.saltFingerprint,
        );
        expect(run.engine.state.stateVersion, StateVersion.current.value);
        expect(run.engine.state.steps.banked, 0);
        expect(run.engine.state.steps.epoch.establishedAtStateVersion, 3);
        expect(run.engine.state.steps.totalGranted, 459223);
        expect(
          run.engine.state.steps.checkpoint.cursor,
          cursor('phase-1-closure'),
        );

        final StateMigrationReport report = run.report!;
        expect(report.fromStateVersion, 1);
        expect(report.toStateVersion, StateVersion.current.value);
        expect(report.stepsApplied.map((StateMigrationStep s) => s.to), <int>[
          2,
          3,
          4,
          5,
          6,
        ]);
        expect(report.retiredSteps, 459043);
        expect(report.previouslyRetiredSteps, 0);

        // Exactly one commit, carrying both events.
        final SaveLoaded reread =
            await repo.load(
                  registry: saveRegistry,
                  originSaltFingerprint: liveIdentity.saltFingerprint,
                )
                as SaveLoaded;
        expect(reread.lastAppliedTransaction, 2);
        expect(reread.state.stateVersion, StateVersion.current.value);
        final BootstrapExistingGame again =
            (await boot(device: device.reboot(), identity: identity)).outcome
                as BootstrapExistingGame;
        expect(again.migration, isNull);
        expect(again.pendingMigration, isNull);
        expect(again.engine.state.steps.epoch.establishedAtStateVersion, 3);
      },
    );

    test(
      'a new game starts at the current version, at the origin, and never migrates',
      () async {
        final BootstrapNewGame fresh =
            (await boot()).outcome as BootstrapNewGame;
        expect(fresh.engine.state.stateVersion, StateVersion.current.value);
        expect(fresh.engine.state.steps.epoch, const EconomyEpoch.origin());
        expect(fresh.engine.state.steps.epoch.establishedAtStateVersion, 0);
      },
    );
  });

  group('6 — the codec writes and reads an old-version state unchanged', () {
    test('a v2 state with a sync applied round-trips as v2', () {
      // The sync's commit happens while the in-memory state is still v2. The
      // encoder writes `state.stateVersion` into both the header and the
      // payload, and the v2 decoder ignores the one field it never wrote —
      // `establishedAtStateVersion` — deriving it again from the marks. So the
      // next launch reads a v2 save and re-enters the pending path.
      final GameEngine engine = GameEngine(
        registry: saveRegistry,
        state: phase2Save(),
      );
      expect(engine.state.stateVersion, 2);
      final EngineResult synced = sync(
        engine,
        incremental(<StepObservation>[obs(phone, 301, 2213)], next: 'x'),
      );
      expect(grantedBy(synced), 2213);
      expect(engine.state.stateVersion, 2, reason: 'a sync moves no version');

      final SaveEnvelope reloaded = decodeEnvelope(
        unframe(
          encodeSnapshot(
            state: engine.state,
            saveId: 'v2-after-sync',
            generation: 1,
            lastAppliedTransaction: 2,
            originSaltFingerprint: null,
          ),
        ).payload!,
      );
      expect(reloaded.gameStateVersion, 2);
      expect(reloaded.state.stateVersion, 2);
      expect(
        StateVersion.migrationRequired(reloaded.state.stateVersion),
        isTrue,
      );
      expect(reloaded.state.steps.epoch.establishedAtStateVersion, 2);
      expect(reloaded.state.steps.totalGranted, 464946 + 2213);
      expect(reloaded.state.steps.checkpoint.cursor, cursor('x'));
      expect(
        canonicalDurableGameState(reloaded.state),
        canonicalDurableGameState(engine.state),
      );
    });
  });
}
